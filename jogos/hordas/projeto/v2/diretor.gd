extends RefCounted
## Diretor de ondas da v2: faz nascer monstros FORA DA TELA, numa faixa em volta do que a câmera mostra (sempre dentro da área andável do
## mapa, nunca em cima de uma árvore). Começa leve e aperta com o tempo da partida: a taxa de nascimento e o teto de monstros vivos sobem
## aos poucos, os monstros ficam mais fortes por minuto e, a cada `onda_cada` segundos, vem uma ONDA FORTE (um anel de monstros de uma vez,
## com a ponta pesada do elenco do mapa). Tudo vem de dados/v2_combate.json ("diretor"). O diretor roda no tempo do mundo (não conta durante hit-stop nem pausa).
## Ele também conta o NÍVEL do mapa (dados/v2_niveis.json): o mapa tem `total` níveis, sobe um a cada `duracao_nivel` s e, nos níveis de
## chefe, faz nascer o mini-chefe (ou o CHEFÃO, no último) e TRAVA até ele morrer. Vencer o chefão é a vitória e o fim do mapa.

const Colisao := preload("res://v2/colisao.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")

var combate
var mundo
var cfg: Dictionary
var acum := 0.0  # monstros "devidos" (taxa x tempo)
var proxima_onda := 0.0
var ondas := 0  # quantas ondas fortes já vieram
var nascidos := 0  # total nascido pelo diretor (testes)
var rng := RandomNumberGenerator.new()
var ligado := true
var mare_pendente := 0
var mare_elites := 0
var mare_t := -1.0
var mare_aviso := false
var mare_chamada_t := -1.0  # >= 0: o Q chamou uma Maré, que chega quando zerar
var mare_chamada_fator := 1.0
var mare_ultima_t := -1000.0  # tempo da partida da última Maré (normal ou chamada)
var mare_chamadas := 0  # quantas Marés o Q chamou (testes)
# Nível do mapa (dados/v2_niveis.json): `nivel` vai de 1 a `niveis_total`; `t_nivel` é o relógio do nível atual, que só anda sem chefe vivo.
var nivel := 1
var niveis_total := 30
var duracao_nivel := 20.0
# ECO-1: o relógio do diretor anda `tempo_mult` vezes mais depressa que a partida (dados/v2_niveis.json > tempo_mult). Um mapa mais curto
# com fator 1,4 passa pela mesma curva de monstros que um de 1,0: onda, taxa, teto, elenco e força por minuto. Os níveis e os chefes
# (duracao_nivel) continuam no tempo real.
var tempo_mult := 1.0
var t_nivel := 0.0
var chefes_mapa: Array = []  # [{nivel, mk (a marca do chefe, já com a vida do mapa e mini = não é o último)}], em ordem de nível


func montar(c) -> void:
	combate = c
	mundo = c.mundo
	cfg = c.cfg.diretor
	carregar_niveis(str(mundo.id_mapa))
	zerar()


## Lê os níveis do mapa `id` (ou do padrão) e monta a lista de chefes com as marcas de v2_cartas.json > chefes.marcas.
func carregar_niveis(id: String) -> void:
	var dn: Dictionary = Dados.json("v2_niveis")
	var mapas: Dictionary = dn.mapas
	var m: Dictionary = mapas.get(id, mapas[str(dn.padrao)])
	niveis_total = int(m.total)
	duracao_nivel = float(mundo.args.get("duracao_nivel", m.duracao_nivel))
	tempo_mult = float(m.get("tempo_mult", 1.0))
	var marcas := {}
	for mk in combate.cartas.cfg.chefes.marcas:
		marcas[str(mk.id)] = mk
	chefes_mapa.clear()
	for e in m.chefes:
		var mk: Dictionary = marcas[str(e.marca)].duplicate(true)
		var n := int(e.nivel)
		mk.id = "n%d" % n
		mk.vida = float(mk.vida) * float(e.get("vida", 1.0))
		mk.mini = n < niveis_total
		chefes_mapa.append({"nivel": n, "mk": mk})
	chefes_mapa.sort_custom(func(a, b): return a.nivel < b.nivel)


func zerar() -> void:
	mare_pendente = 0
	mare_elites = 0
	mare_t = -1.0
	mare_aviso = false
	mare_chamada_t = -1.0
	mare_chamada_fator = 1.0
	mare_ultima_t = -1000.0
	mare_chamadas = 0
	acum = 0.0
	ondas = 0
	nascidos = 0
	proxima_onda = intervalo_onda()
	rng.seed = 7777
	nivel = 1
	t_nivel = 0.0


## Segundos de cada nível nesta partida (o Pesadelo encurta, trazendo os chefes mais cedo).
func seg_nivel() -> float:
	return maxf(duracao_nivel * mundo.fator_pesadelo("chefe_tempo_mult") * dificuldade("chefe_tempo_mult"), 0.01)


## Relógio do diretor (ECO-1): o tempo da partida vezes `tempo_mult` do mapa. As ondas fortes e a Maré contam nele, e a força por minuto
## também. As funções que recebem `t` (taxa, limite, sortear) esperam o tempo REAL da partida e aplicam o fator dentro delas.
func relogio() -> float:
	return mundo.tempo_partida * tempo_mult


## Quantos segundos REAIS faltam para a próxima onda forte. `proxima_onda` está no relógio do diretor, então a conta divide por `tempo_mult`
## (o status e a guarda da Maré chamada pelo Q medem em tempo real: `mare_chamada_t` e o atraso do herói andam em dt).
func falta_onda_real() -> float:
	return maxf(0.0, proxima_onda - relogio()) / maxf(tempo_mult, 0.0001)


## Ponto único de leitura das regras para o diretor e o relógio de elites.
func dificuldade(chave: String) -> float:
	return Dificuldade.fator(mundo, chave)


func intervalo_onda() -> float:
	return float(cfg.onda_cada) * dificuldade("onda_tempo_mult")


func intervalo_elite(base: float) -> float:
	return base * dificuldade("elite_tempo_mult")


## O chefe do nível `n` ({nivel, mk}) ou {} se o nível não tem chefe.
func chefe_do_nivel(n: int) -> Dictionary:
	for e in chefes_mapa:
		if int(e.nivel) == n:
			return e
	return {}


## O nível está travado esperando o chefe dele morrer?
func travado() -> bool:
	var e := chefe_do_nivel(nivel)
	return not e.is_empty() and (combate.chefes.vivo or not combate.chefes.feitos.has(e.mk.id))


## Avança o relógio do nível (o combate chama a cada quadro de jogo, mesmo com o diretor desligado): sobe de nível a cada seg_nivel()
## e, ao chegar num nível de chefe, faz ele nascer. Com chefe vivo o relógio para; no último nível fica parado até a vitória.
func avancar_nivel(dt: float) -> void:
	if combate.chefes.vivo:
		return  # inclui o mini-chefe de exploração das Ruínas: não avança nem substitui um chefe ainda em campo
	var e := chefe_do_nivel(nivel)
	if not e.is_empty() and not combate.chefes.feitos.has(e.mk.id):
		combate.chefes.nascer(e.mk)  # nível de chefe sem o chefe (o 1 de um mapa, ou um teste que pulou de nível)
		return
	if travado() or nivel >= niveis_total:
		return
	t_nivel += dt
	var s := seg_nivel()
	while t_nivel >= s and nivel < niveis_total:
		t_nivel -= s
		ir_para_nivel(nivel + 1)
		if travado():
			t_nivel = 0.0
			return


## Pula para o nível `n` (o avanço normal e os testes): se ele tem chefe, o chefe nasce agora.
func ir_para_nivel(n: int) -> void:
	nivel = clampi(n, 1, niveis_total)
	var e := chefe_do_nivel(nivel)
	if not e.is_empty() and not combate.chefes.feitos.has(e.mk.id) and not combate.chefes.vivo:
		combate.chefes.nascer(e.mk)


## O próximo nível de chefe a partir do atual (ou o total, se não houver).
func proximo_chefe() -> int:
	for e in chefes_mapa:
		if int(e.nivel) >= nivel:
			return int(e.nivel)
	return niveis_total


## Quanto do mapa já foi (0 a 1), contando a fração do nível atual: a barra do HUD.
func fracao_mapa() -> float:
	if niveis_total <= 1:
		return 1.0
	var parcial := 0.0 if travado() or nivel >= niveis_total else clampf(t_nivel / seg_nivel(), 0.0, 1.0)
	return clampf((float(nivel - 1) + parcial) / float(niveis_total - 1), 0.0, 1.0)


## Taxa de nascimento (monstros/s) no instante `t` REAL da partida: sobe em linha reta até tempo_taxa do relógio do diretor (ECO-1).
func taxa(t: float) -> float:
	return (
		lerpf(float(cfg.taxa_ini), float(cfg.taxa_fim), clampf(t * tempo_mult / float(cfg.tempo_taxa), 0.0, 1.0))
		* mundo.fator_pesadelo("densidade_mult")
		* dificuldade("densidade_mult")
		* combate.ritmo.multiplicador("densidade", mundo.heroi.nivel)
	)


## O máximo de monstros vivos de uma vez (o teto dos dados; no Pesadelo sobe com a densidade).
func teto() -> int:
	return roundi(float(cfg.teto) * mundo.fator_pesadelo("densidade_mult") * dificuldade("densidade_mult"))


func limite(t: float) -> int:
	return mini(
		teto(),
		roundi(
			(
				lerpf(float(cfg.cap_ini), float(cfg.cap_fim), clampf(t * tempo_mult / float(cfg.tempo_cap), 0.0, 1.0))
				* mundo.fator_pesadelo("densidade_mult")
				* dificuldade("densidade_mult")
				* combate.ritmo.multiplicador("densidade", mundo.heroi.nivel)
			)
		)
	)


func atualizar(dt: float) -> void:
	if not ligado:
		return
	var t: float = mundo.tempo_partida  # real: taxa, limite e elenco aplicam o fator dentro delas
	var td: float = relogio()  # do diretor: ondas e Maré
	if mare_t >= 0.0:
		mare_t -= dt
		if mare_t <= 0.0:
			_mare_pulso(mare_pendente, 1)
			mare_pendente = 0
			mare_t = -1.0
	if mare_chamada_t >= 0.0:
		mare_chamada_t -= dt
		if mare_chamada_t <= 1.2:
			_mare_avisar()
		if mare_chamada_t <= 0.0:
			mare_chamada_t = -1.0
			var fator := mare_chamada_fator
			mare_chamada_fator = 1.0
			onda_forte(fator, false)  # a chamada do Q não sobe o contador de escalada: as Marés normais seguem o relógio
			mare_aviso = false
			proxima_onda = maxf(proxima_onda, td + _mare_cfg("intervalo_min"))  # a Maré normal não vem colada na que o Q chamou
	if _mare_ativa() and falta_onda_real() <= 1.2:  # o aviso sai 1,2 s REAIS antes da Maré
		_mare_avisar()
	if td >= proxima_onda:
		onda_forte()
		proxima_onda += intervalo_onda()
		mare_aviso = false
	var folga: float = 0.4 if combate.chefes.vivo else 1.0  # com chefe em campo a horda dá uma folga
	acum += taxa(t) * dt * folga
	if acum < 1.0:
		return
	# O limite da fase (`cap`) mede quem o diretor pôs para CAÇAR o herói. Os moradores do mapa (os 20 de "nascimento", que vagam longe e só
	# perseguem de perto) não contam: contando, o cap inicial (14) ficava abaixo dos 20 moradores e nada nascia por ~45 s, a partida abria
	# vazia. O teto geral (`teto()`) continua valendo sobre todos os vivos.
	var vivos: int = mundo.monstros.size()
	var cacando := 0
	for m in mundo.monstros:
		if m.cacador:
			cacando += 1
	var cap := roundi(float(limite(t)) * (0.6 if combate.chefes.vivo else 1.0))
	while acum >= 1.0:
		acum -= 1.0
		if cacando >= cap or vivos >= teto():
			acum = minf(acum, 1.0)  # no teto não junta devedor: quando abrir vaga, nasce um por vez
			break
		var tipo := sortear(t)
		if nascer(str(tipo.sprite), null, tipo):
			vivos += 1
			cacando += 1


## O tipo do elenco do mapa (v2/elenco.gd) sorteado para o instante `t` da partida: {sprite, nome, tinta, ...}.
func sortear(t: float) -> Dictionary:
	return mundo.elenco.sortear(t * tempo_mult, rng)


## Nasce um monstro fora da tela. `tipo` (opcional) é a variação do elenco do mapa. Devolve false se não achou lugar (a taxa tenta de novo no próximo).
func nascer(nome: String, forcar: Variant = null, tipo := {}) -> bool:
	var p: Variant = forcar if forcar != null else ponto_fora_da_tela()
	if p == null:
		return false
	var minutos: float = relogio() / 60.0
	var kv := 1.0 + float(cfg.vida_por_min) * minutos
	var kd := 1.0 + float(cfg.dano_por_min) * minutos
	var m = mundo.nascer_monstro(nome, p, true, kv, kd, tipo)
	if m == null:
		return false
	nascidos += 1
	return true


## Um ponto na faixa de margem_min a margem_max px além da borda da tela, dentro da área andável e livre de colisão. null se não achou.
func ponto_fora_da_tela() -> Variant:
	var tela: Rect2 = mundo.cam.retangulo()
	var lim: Rect2 = mundo.limite_andavel
	for i in 14:
		var m := rng.randf_range(float(cfg.margem_min), float(cfg.margem_max))
		var r := tela.grow(m)
		# ponto sorteado no perímetro do retângulo ampliado, com sorteio proporcional ao tamanho de cada lado
		var per := 2.0 * (r.size.x + r.size.y)
		var s := rng.randf() * per
		var p: Vector2
		if s < r.size.x:
			p = Vector2(r.position.x + s, r.position.y)
		elif s < r.size.x + r.size.y:
			p = Vector2(r.end.x, r.position.y + (s - r.size.x))
		elif s < 2.0 * r.size.x + r.size.y:
			p = Vector2(r.end.x - (s - r.size.x - r.size.y), r.end.y)
		else:
			p = Vector2(r.position.x, r.end.y - (s - 2.0 * r.size.x - r.size.y))
		if not lim.has_point(p):
			continue  # essa parte do anel cai fora do mapa: tenta outra
		if tela.has_point(p) or not Colisao.livre(p, 7.0):
			continue
		return p
	return null


## Onda forte: um anel de monstros de uma vez em volta da tela, com a ponta pesada do elenco do mapa (o cavaleiro, no padrão).
## `fator` < 1 faz uma onda mais curta (a Maré chamada pelo Q logo depois de outra). `conta` = false (a chamada do Q): usa o tamanho da onda
## em que a partida está, mas NÃO avança `ondas`, para o Q não escalar as Marés seguintes.
func onda_forte(fator := 1.0, conta := true) -> void:
	if conta:
		ondas += 1
	var idx := maxi(ondas, 1)
	var n := int(cfg.onda_base) + int(cfg.onda_mais) * (idx - 1)
	var t: float = mundo.tempo_partida
	mare_ultima_t = relogio()
	var elite := roundi(float(cfg.onda_elite) * idx * fator)
	var folga: int = teto() - mundo.monstros.size()
	n = mini(roundi(float(n) * mundo.fator_pesadelo("densidade_mult") * dificuldade("densidade_mult") * fator) + elite, maxi(folga, 0))
	if _mare_ativa():
		mare_elites = elite
		var primeiro := ceili(float(n) * 0.5)
		_mare_pulso(primeiro, -1)
		mare_pendente = n - primeiro
		mare_t = 1.0 if mare_pendente > 0 else -1.0
		combate.onda_forte(idx)
		return
	for i in n:
		var tipo: Dictionary = mundo.elenco.pesado if i < elite else sortear(t)
		nascer(str(tipo.sprite), null, tipo)
	combate.onda_forte(idx)


## ULT-C: a Maré vale em todo mapa e para todo herói que tem Q (o bloco `mare` dele, em v2_especial.json). O mapa só a desliga com
## `mare: false` no próprio v2_<mapa>.json (válvula de segurança). Sem Q, nada de Maré.
func _mare_ativa() -> bool:
	return bool(mundo.dados.get("mare", true)) and not _mare_do(str(combate.heroi_id)).is_empty()


## O bloco de Maré do herói `chave` (formacao, atraso, cone_graus, abate_carga); {} se o herói não tem Q.
func _mare_do(chave: String) -> Dictionary:
	return combate.especial.mare_de(chave)


func _mare_cfg(chave: String) -> float:
	return float(cfg.mare[chave])


## O aviso da Maré (texto e som), uma vez por onda, tanto da normal quanto da chamada pelo Q.
func _mare_avisar() -> void:
	if mare_aviso:
		return
	mare_aviso = true
	combate.anunciar("MARÉ DE SANGUE!", Color(1.0, 0.25, 0.2))
	combate.audio.tocar("onda", 0.8, -2.0, 0.0)
	if OS.get_cmdline_user_args().has("--diag-audio"):  # medição do atalho de teste: vozes ocupadas na hora do aviso
		print("[mare] aviso: descartados=%d roubados=%d" % [combate.audio.descartados, combate.audio.roubados])


## O Q do herói acabou de limpar a tela (ULT-C, no instante `limpa_em`): chama uma Maré daqui a `atraso` s (do bloco mare dele). Só onde a Maré
## vale, sem outra pendente, respeitando o intervalo mínimo e sem chamar se a normal já está para chegar. Vem mais curta se a última foi há pouco,
## ou sempre curta quando o bloco pede (`curta`, o LightWolf: o Lobo sai da explosão com 31% da vida). Devolve se chamou.
## A Maré é a do herói DA PARTIDA (`combate.heroi_id`), como `_mare_ativa` e `_mare_pulso`: o LightWolf chama a dele também quando o Q é apertado na forma Lobo
## (a chave do herói, que muda com a forma, não escolhe Maré nenhuma). O argumento `_h` só existe para quem chama com o herói na mão.
func mare_chamar(_h = null) -> bool:
	if not ligado or not _mare_ativa() or mare_chamada_t >= 0.0 or mare_t >= 0.0:
		return false
	var mare := _mare_do(str(combate.heroi_id))
	var atraso := float(mare.get("atraso", 3.0))
	var t: float = relogio()
	var desde := t - mare_ultima_t
	if desde < _mare_cfg("intervalo_min") or falta_onda_real() <= atraso:  # tempo real dos dois lados (o Q chama em dt)
		return false
	mare_chamada_t = atraso
	mare_chamada_fator = 1.0 if desde >= _mare_cfg("q_cheia_apos") else _mare_cfg("q_curta")
	if bool(mare.get("curta", false)):
		mare_chamada_fator = minf(mare_chamada_fator, _mare_cfg("q_curta"))
	mare_chamadas += 1
	return true


## Prefere um lado por pulso; preserva corredor quando a geometria permite. Respeita teto e colisão. A formação é a do herói (ULT-C):
## pinça (dois lados, o Nicão), cone (o Hazaki, pela direção em que está virado) ou anel (volta inteira, o Luke).
func _mare_pulso(n: int, lado: int) -> void:
	var m := _mare_do(str(combate.heroi_id))
	for i in n:
		if mundo.monstros.size() >= teto():
			break
		var p = _ponto_da_mare(m, lado)
		if p == null:
			continue
		var tipo: Dictionary = mundo.elenco.pesado if mare_elites > 0 else sortear(mundo.tempo_partida)
		if nascer(str(tipo.sprite), p, tipo):
			mundo.monstros.back().mare = true
			if mare_elites > 0:
				mare_elites -= 1


## O ponto de nascimento da Maré conforme a formação do herói (bloco mare): cone, anel ou, por padrão, pinça (dois lados).
func _ponto_da_mare(m: Dictionary, lado: int) -> Variant:
	match str(m.get("formacao", "pinca")):
		"cone":
			# De costas para a parede (o herói encostado na borda do mapa, virado para fora) o leque não tem chão: a Maré vem em anel, não some.
			var pc: Variant = _ponto_cone(float(m.get("cone_graus", 70.0)))
			return pc if pc != null else ponto_fora_da_tela()
		"anel":
			return ponto_fora_da_tela()
	return _ponto_mare(lado)


## Formação em cone (ULT-C, Hazaki): a Maré nasce fora da tela no leque de `graus` centrado na direção em que o herói está virado agora.
## Do centro da tela, um raio sorteado no leque cruza a borda da tela ampliada pela margem; o ponto precisa ser andável e livre.
func _ponto_cone(graus: float) -> Variant:
	var tela: Rect2 = mundo.cam.retangulo()
	var olhar: Vector2 = mundo.heroi.dir_olhar
	if olhar.length_squared() < 0.01:
		olhar = Vector2.RIGHT
	var meio := deg_to_rad(graus) * 0.5
	for i in 30:
		var margem := rng.randf_range(float(cfg.margem_min), float(cfg.margem_max))
		var ang := olhar.angle() + rng.randf_range(-meio, meio)
		var p := ponto_na_borda(tela.get_center(), Vector2.from_angle(ang), tela.grow(margem))
		if mundo.limite_andavel.has_point(p) and not tela.has_point(p) and Colisao.livre(p, 7.0):
			return p
	return null


## Onde o raio que sai de `origem` (dentro de `rect`) na direção `dir` cruza a borda de `rect`. Função pura, testável.
static func ponto_na_borda(origem: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var t := INF
	if dir.x > 0.0:
		t = minf(t, (rect.end.x - origem.x) / dir.x)
	elif dir.x < 0.0:
		t = minf(t, (rect.position.x - origem.x) / dir.x)
	if dir.y > 0.0:
		t = minf(t, (rect.end.y - origem.y) / dir.y)
	elif dir.y < 0.0:
		t = minf(t, (rect.position.y - origem.y) / dir.y)
	return origem + dir * t


func _ponto_mare(lado: int) -> Variant:
	var tela: Rect2 = mundo.cam.retangulo()
	# Em borda de mapa, procura o setor de cima/baixo e por último o lateral oposto.
	for setor in [lado, lado * 2, -lado]:
		for i in 30:
			var margem := rng.randf_range(float(cfg.margem_min), float(cfg.margem_max))
			var p: Vector2
			if absi(setor) == 1:
				var x := tela.position.x - margem if setor < 0 else tela.end.x + margem
				p = Vector2(x, rng.randf_range(tela.position.y, tela.end.y))
			else:
				var y := tela.position.y - margem if setor < 0 else tela.end.y + margem
				p = Vector2(rng.randf_range(tela.position.x, tela.end.x), y)
			if mundo.limite_andavel.has_point(p) and not tela.has_point(p) and Colisao.livre(p, 7.0):
				return p
	return null
