extends RefCounted
## Combate e laço de jogo da v2 (leva 2). Junta o que faz o golpe PESAR: hit-stop, flash, empurrão, número de dano, tremor de câmera em
## pixel inteiro, partículas, som; a vida e a morte dos monstros; o contato que tira vida do herói; o combo de abates; os orbes de XP; e o
## controle do tempo (câmera lenta ao subir de nível, pausa da escolha e da tela de resultado).
## Os números vêm de dados/v2_combate.json (`cfg`). Quem manda no quadro é o mundo (mundo.avancar); este módulo oferece:
##   passo_tempo(dt_real) -> dt do mundo (0 no hit-stop e na pausa; fração na câmera lenta)
##   atualizar(dt_mundo)  -> contato, separação dos monstros, orbes, combo, diretor (tempo do mundo)
##   efeitos(dt_real)     -> partículas, números, cortes, luzes (continuam durante o hit-stop)
## O herói chama golpe_comecou/golpear/esquiva_comecou/heroi_apanhou/heroi_morreu; os orbes chamam coletar. A ruptura (tecla E)
## (v2/ruptura.gd) é um módulo daqui (`ruptura`): o contragolpe dela entra em golpe_comecou e golpear.

const Efeitos := preload("res://v2/efeitos.gd")
const Orbes := preload("res://v2/orbes.gd")
const Progresso := preload("res://v2/progresso.gd")
const Meta := preload("res://v2/meta.gd")
const TempoLocal := preload("res://v2/tempo_local.gd")
const Diretor := preload("res://v2/diretor.gd")
const Telas := preload("res://v2/telas.gd")
const AudioV2 := preload("res://v2/audio.gd")
const Cartas := preload("res://v2/cartas.gd")
const Armas := preload("res://v2/armas.gd")
const Avisos := preload("res://v2/avisos.gd")
const Elites := preload("res://v2/elites.gd")
const Baus := preload("res://v2/bau.gd")
const Chefes := preload("res://v2/chefe.gd")
const Ruptura := preload("res://v2/ruptura.gd")
const Escudo := preload("res://v2/escudo.gd")
const Herois := preload("res://v2/herois.gd")
const Adagas := preload("res://v2/adagas.gd")
const COR_NUM := Color(1.0, 0.96, 0.84)
const COR_CRIT := Color(1.0, 0.74, 0.2)
const COR_DANO_HEROI := Color(1.0, 0.32, 0.32)
const CEL := 26.0  # célula da grade de separação dos monstros
const PASSO_SEP := 3  # cada monstro recalcula a separação a cada 3 quadros (o resultado vale por 3)
const GRADE_N := 1024  # tamanho da tabela de hash da grade (potência de 2)
const RAIO_GRANDE := 11.0  # acima disto o monstro (elite, chefe) fica na lista dos grandes, fora da grade
const QUADRO_REF := 1.0 / 60.0  # o quadro de referência do "Combo completo" do card de status (vsync de 60 Hz)
const CONTATO_BASE := 13.0  # raio do herói (6) + do cão (7): o `contato.alcance` dos dados vale para o cão; os outros encostam pelo raio
const FUSAO_PARADA_S := 0.1  # hit-stop de uma fusão (s reais): o mundo para um instante quando as peças viram a arma nova
const FUSAO_LENTA_S := 0.6  # câmera lenta da fusão (s reais)
const FUSAO_ESCALA := 0.35  # velocidade do mundo na câmera lenta da fusão

var mundo
var cfg: Dictionary = {}
var fx
var orbes
var audio
var progresso
var diretor
var telas
var cartas  # raridade, sorteio, evolução (leva 3)
var armas  # golpes secundários automáticos e ondas da katana
var avisos  # ataques anunciados no chão
var elites
var baus
var chefes
var ruptura  # a habilidade (tecla E, v2/ruptura.gd)
var escudo  # o secundário do botão direito (v2/escudo.gd; qual secundário cada herói tem vem de dados/v2_secundario.json)
var adagas  # as adagas do Lucas (pool, v2/adagas.gd)
var heroi_id := "hazaki"  # o herói da partida (v2/herois.gd)
var fim_emitido := false  # partida_terminou já saiu
var venceu := false

# tempo: o estado de hit-stop, câmera lenta e pausa da escolha é do herói local (v2/tempo_local.gd); estas propriedades só repassam
var local := TempoLocal.new()
var parada_t: float:  # hit-stop que falta (s, relógio real)
	get:
		return local.parada_t
	set(v):
		local.parada_t = v
var lento_t: float:  # câmera lenta que falta (s, relógio real)
	get:
		return local.lento_t
	set(v):
		local.lento_t = v
var lento_escala: float:
	get:
		return local.lento_escala
	set(v):
		local.lento_escala = v
var lento_acao: String:  # o que acontece quando a câmera lenta acaba: "nivel", "morte" ou "vitoria"
	get:
		return local.lento_acao
	set(v):
		local.lento_acao = v
var pausado: bool:  # escolha de melhoria, baú ou tela de resultado aberta (para o herói local)
	get:
		return local.pausado
	set(v):
		local.pausado = v
var pausado_mundo := false  # pausa que vale para todos (resultado da partida); no solo anda junto com `pausado`
var tempo_local_separado := false  # coop e tela dividida: hit-stop, câmera lenta e escolha só valem para o herói local; o solo deixa false
var dt_mundo := 0.0  # o dt do último passo_tempo para o mundo (monstros, relógio, combate)
var dt_local := 0.0  # o dt do último passo_tempo para o herói local (animação e movimento); no solo é igual a dt_mundo
var jogo := "jogando"  # jogando, escolha, morte

# contadores e estado (testes)
var combo_t := 0.0
var acertos := 0
var criticos := 0
var mortes := 0
var hit_stops := 0
var ultimo_hit_stop := 0.0
var _plim_t := 0.0
var _plim_n := 0
var _fila: Array = []  # monstros que morreram no quadro por golpe secundário ou fogo (saem em processar_mortes)
var anuncios := 0  # quantos anúncios saíram (testes)
var ultimo_anuncio := ""
var ferimentos := 0  # golpes secundários que feriram (testes)
var dano_causado := 0.0  # soma do dano nos monstros na partida (robô de playtest, #301)
var dano_sofrido := 0.0  # soma do dano que o herói tomou
var golpes_tomados := 0
var us_armas := 0  # microssegundos gastos em armas.atualizar (medição)
var _cab := PackedInt32Array()  # grade de separação: primeira entrada de cada célula (hash)
var _prox := PackedInt32Array()  # próximo monstro na mesma célula
# Hashes vizinhos únicos por célula. Vetores reutilizados: só recalcula ao mudar de célula/alcance.
var _cache_x := PackedInt32Array()
var _cache_y := PackedInt32Array()
var _cache_alcance := PackedInt32Array()
var _cache_n := PackedInt32Array()
var _cache_hash := PackedInt32Array()  # 49 posições por ator (alcance máximo de 3 células)
var _pos := PackedVector2Array()
var _rad := PackedFloat32Array()
var _grandes: Array[int] = []
var _q := 0


func montar(m) -> void:
	mundo = m
	heroi_id = Herois.escolhido()
	cfg = Herois.cfg_para(Dados.json("v2_combate"), heroi_id)  # o herói escolhido cobre vida, velocidade, fôlego e o combo
	audio = AudioV2.new()
	m.add_child(audio)
	fx = Efeitos.new()
	fx.montar(m, m.glow, m.sv, m.atm.tex_brilho)
	orbes = Orbes.new()
	orbes.montar(self, m.glow, m.atm.tex_brilho)
	orbes.ima_vel = float(cfg.xp.ima_vel)
	orbes.ima_acel = float(cfg.xp.ima_acel)
	cartas = Cartas.new()
	cartas.montar(self)
	armas = Armas.new()
	armas.montar(self, m.glow, m.sv, m.atm.tex_brilho)
	adagas = Adagas.new()
	adagas.montar(self, m.glow, m.atm.tex_brilho)
	progresso = Progresso.new()
	progresso.montar(self)
	diretor = Diretor.new()
	diretor.montar(self)
	telas = Telas.new()
	telas.montar(self, m.ui)
	avisos = Avisos.new()
	avisos.montar(self, m.glow)
	ruptura = Ruptura.new()
	ruptura.montar(self, m.glow)
	escudo = Escudo.new()
	escudo.montar(self, m.glow)
	elites = Elites.new()
	elites.montar(self)
	baus = Baus.new()
	baus.montar(self)
	chefes = Chefes.new()
	chefes.montar(self)


## Liga o herói às regras dos dados (vida, fôlego, curva de XP). Chamado quando o herói nasce e quando a partida recomeça.
func iniciar_heroi() -> void:
	mundo.heroi.iniciar_stats(cfg)
	progresso.zerar()


# ------------------------------------------------------------------ tempo


## dt do mundo a partir do dt real: hit-stop e pausa travam o mundo; a câmera lenta o desacelera. Devolve o dt do MUNDO e deixa em
## `dt_local` o do herói local. No solo os dois são iguais (comportamento de sempre); com `tempo_local_separado` (coop, tela dividida) o
## hit-stop, a câmera lenta e a escolha só afetam `dt_local` e o mundo segue, salvo `pausado_mundo` (resultado), que para todos.
func passo_tempo(dt: float) -> float:
	var dl := _passo_local(dt)
	dt_local = dl
	if not tempo_local_separado:
		dt_mundo = dl
	else:
		dt_mundo = 0.0 if pausado_mundo else dt
	return dt_mundo


## O relógio do herói local: pausa, hit-stop e câmera lenta (a parte que antes era o corpo inteiro de passo_tempo).
func _passo_local(dt: float) -> float:
	if pausado or pausado_mundo:
		if mundo.heroi != null:
			mundo.heroi.cancelar_ruptura(false)  # escolha, baú, morte e resultado: a carga da ruptura não sobrevive (idempotente)
		return 0.0
	if parada_t > 0.0:
		parada_t -= dt
		return 0.0
	if lento_t > 0.0:
		lento_t -= dt
		if lento_t <= 0.0:
			_fim_camera_lenta()
			if pausado or pausado_mundo:
				return 0.0
		return dt * lento_escala
	return dt


func hit_stop(s: float) -> void:
	if local.parar(s):
		ultimo_hit_stop = s
	hit_stops += 1


func camera_lenta(acao: String, dur: float, escala: float) -> void:
	lento_t = dur
	lento_escala = escala
	lento_acao = acao


func _fim_camera_lenta() -> void:
	lento_t = 0.0
	lento_escala = 1.0
	match lento_acao:
		"nivel":
			progresso.abrir_escolha()
		"morte":
			jogo = "morte"
			pausado = true
			pausado_mundo = true
			fim_de_partida(false)
			telas.mostrar_resultado()
		"vitoria":
			jogo = "vitoria"
			pausado = true
			pausado_mundo = true
			fim_de_partida(true)
			telas.mostrar_resultado()
	lento_acao = ""


# ------------------------------------------------------------------ o quadro do mundo


func atualizar(dt: float) -> void:
	_q += 1
	var h = mundo.heroi
	var m0 := Time.get_ticks_usec()
	processar_mortes()  # fogo e golpes do quadro anterior
	mundo._perfil("c_mortes", Time.get_ticks_usec() - m0)
	if mundo.combo > 0:
		combo_t -= dt
		if combo_t <= 0.0:
			mundo.combo = 0
	_plim_t -= dt
	if jogo == "jogando":
		var s0 := Time.get_ticks_usec()
		_separar()
		var s1 := Time.get_ticks_usec()
		_contato(h)
		mundo._perfil("c_separar", s1 - s0)
		mundo._perfil("c_contato", Time.get_ticks_usec() - s1)
		var d0 := Time.get_ticks_usec()
		diretor.atualizar(dt)
		var t0 := Time.get_ticks_usec()
		armas.atualizar(dt)
		var t1 := Time.get_ticks_usec()
		us_armas += t1 - t0
		adagas.atualizar(dt)
		elites.atualizar(dt)
		diretor.avancar_nivel(dt)
		chefes.atualizar(dt)
		var t2 := Time.get_ticks_usec()
		avisos.atualizar(dt)
		ruptura.atualizar(dt)
		baus.atualizar(dt)
		mundo._perfil("c_diretor", t0 - d0)
		mundo._perfil("c_armas", t1 - t0)
		mundo._perfil("c_elites_chefes", t2 - t1)
		mundo._perfil("c_avisos_baus", Time.get_ticks_usec() - t2)
	var o0 := Time.get_ticks_usec()
	orbes.atualizar(dt, h.pos + Vector2(0, -8), h.alcance_ima())
	mundo._perfil("c_orbes", Time.get_ticks_usec() - o0)


## Monstros colados se empurram: a horda faz uma roda em volta do herói em vez de virar uma pilha em cima dele. Uma grade espacial de
## CEL px (tabela de hash em vetores planos, sem Dictionary nem Array por célula) guarda os monstros pequenos; os grandes (elite, chefe)
## ficam numa lista à parte que todos consultam, porque o alcance deles passa de uma célula. Um terço dos monstros por quadro (o resultado
## vale por PASSO_SEP quadros). O resultado fica em `sep` (px/s) e entra no deslocamento do próprio monstro. O herói é outro caso: o corpo dele
## é sólido, e quem entra nele é empurrado para fora em `Monstro.atualizar` (`_corpo_do_heroi`).
func _separar() -> void:
	var ms: Array = mundo.monstros
	var n := ms.size()
	if n < 2:
		return
	if _cab.is_empty():
		_cab.resize(GRADE_N)
	_cab.fill(-1)
	if _pos.size() < n:
		_pos.resize(n + 64)
		_rad.resize(n + 64)
		_prox.resize(n + 64)
		_cache_x.resize(n + 64)
		_cache_y.resize(n + 64)
		_cache_alcance.resize(n + 64)
		_cache_n.resize(n + 64)
		_cache_hash.resize((n + 64) * 49)
	_grandes.clear()
	for i in n:
		var m = ms[i]
		var p: Vector2 = m.pos
		var r: float = m.raio
		_pos[i] = p
		_rad[i] = r
		if r > RAIO_GRANDE:
			_grandes.append(i)
			continue
		var h := ((int(p.x / CEL) * 73856093) ^ (int(p.y / CEL) * 19349663)) & (GRADE_N - 1)
		_prox[i] = _cab[h]
		_cab[h] = i
	var i0 := _q % PASSO_SEP
	while i0 < n:
		var m = ms[i0]
		var k := i0
		i0 += PASSO_SEP
		if m.atordoa_t > 0.0:
			m.sep = Vector2.ZERO
			continue
		var p: Vector2 = _pos[k]
		var r: float = _rad[k]
		var empurra := Vector2.ZERO
		var cx := int(p.x / CEL)
		var cy := int(p.y / CEL)
		var alcance := 1 if r <= RAIO_GRANDE else 3  # os grandes olham mais longe na grade
		var desloc := k * 49
		if _cache_alcance[k] != alcance or _cache_x[k] != cx or _cache_y[k] != cy:
			var qtd := 0
			for dx in range(-alcance, alcance + 1):
				for dy in range(-alcance, alcance + 1):
					var hash_cel := (((cx + dx) * 73856093) ^ ((cy + dy) * 19349663)) & (GRADE_N - 1)
					var repetido := false
					for q in qtd:
						if _cache_hash[desloc + q] == hash_cel:
							repetido = true
							break
					if not repetido:
						_cache_hash[desloc + qtd] = hash_cel
						qtd += 1
			_cache_n[k] = qtd
			_cache_x[k] = cx
			_cache_y[k] = cy
			_cache_alcance[k] = alcance
		for q in _cache_n[k]:
			var j: int = _cab[_cache_hash[desloc + q]]
			while j >= 0:
				if j != k:
					var d := p - _pos[j]
					var lim := (r + _rad[j]) * 1.15
					var d2 := d.length_squared()
					if d2 < lim * lim:
						if d2 < 0.01:
							d = Vector2(randf() - 0.5, randf() - 0.5)
							d2 = d.length_squared()
						var dist := sqrt(d2)
						empurra += d / dist * (lim - dist)
				j = _prox[j]
		for j in _grandes:
			if j == k:
				continue
			var d := p - _pos[j]
			var lim := (r + _rad[j]) * 1.15
			var d2 := d.length_squared()
			if d2 < lim * lim:
				if d2 < 0.01:
					d = Vector2(randf() - 0.5, randf() - 0.5)
					d2 = d.length_squared()
				var dist := sqrt(d2)
				empurra += d / dist * (lim - dist)
		m.sep = (empurra * 14.0).limit_length(46.0)


func _contato(h) -> void:
	if not h.vulneravel():
		return
	var folga := float(cfg.contato.alcance) - CONTATO_BASE  # o alcance de antes, para o cão, vira "encostou no corpo + folga"
	var hp: Vector2 = h.pos
	for m in mundo.monstros:
		if m.recarga > 0.0 or m.atordoa_t > 0.0:
			continue
		var lim: float = h.raio + m.raio + folga  # encostou no corpo do herói (o monstro grande encosta de mais longe)
		var dx: float = m.pos.x - hp.x
		if absf(dx) > lim:
			continue
		var dy: float = m.pos.y - hp.y
		if dx * dx + dy * dy > lim * lim:
			continue
		if h.levar_dano(m.dano, m.pos, m):
			m.recarga = float(cfg.contato.recarga)
			return  # um golpe por vez: o resto espera a invencibilidade passar


## Efeitos visuais no relógio de parede (continuam andando no hit-stop).
func efeitos(dt: float) -> void:
	fx.atualizar(dt)
	ruptura.efeitos(dt)
	escudo.efeitos(dt)
	telas.atualizar(dt)


# ------------------------------------------------------------------ golpe


## Os números do golpe da katana COMO O JOGO OS USA (golpe_comecou e golpear leem daqui; o card de status, status.gd, também).
## Dano MÉDIO de um passo do combo, com o bônus de dano do herói (cada acerto varia +-`golpe.variacao` e arredonda); alcance e arco com a área.
func dano_do_passo(passo: Dictionary) -> float:
	return float(passo.dano) * mundo.heroi.m_dano


func alcance_do_passo(passo: Dictionary) -> float:
	return float(passo.alcance) * mundo.heroi.m_area


## O arco com a área do herói, até 360 graus: a pancada do Nicão é em volta toda, e sem o teto 360 com a área vira 396 e o cosseno do acerto inverte.
func arco_do_passo(passo: Dictionary) -> float:
	return minf(float(passo.arco) * (1.0 + (mundo.heroi.m_area - 1.0) * 0.5), 360.0)


## Chance de crítico da katana (0 a 1): a base dos dados mais o bônus das cartas.
func chance_critico() -> float:
	return float(cfg.golpe.critico.chance) + mundo.heroi.m_critico


## Até onde o passo alcança de verdade: o alcance com a área MAIS o avanço (lunge) que o herói faz antes do acerto (a estocada de 74 px
## acerta a 100 px). É o que o card de status mostra.
func alcance_efetivo_do_passo(passo: Dictionary) -> float:
	return alcance_do_passo(passo) + float(passo.get("avanco", 0.0))  # sem avanço no passo (as adagas): 0, como o lunge do heroi.gd


## Hit-stop (s) de um acerto do passo: o do crítico se `crit`, senão o do passo. `golpear` e o card de status usam esta.
func hit_stop_do_acerto(passo: Dictionary, crit: bool) -> float:
	if str(passo.get("tipo", "melee")) == "adagas":  # as adagas não param o tempo no acerto (v2/adagas.gd não chama o hit-stop)
		return 0.0
	return float(cfg.golpe.critico.hit_stop) if crit else float(passo.hit_stop)


## Quanto dura um combo inteiro com o clique segurado num alvo ao alcance, em s, nos quadros de `dt` (o jogo anda em quadros inteiros, então
## cada fase arredonda para cima: o passo, o hit-stop do acerto, a pausa do fim do combo; cada passo ainda gasta o quadro em que começa).
## O padrão é o quadro de 60 Hz (`QUADRO_REF`), com o qual o "Combo completo" do card de status bate com o que o jogador vê (1,30 s com a
## velocidade base, onde só a soma dos passos daria 0,88 s). O hit-stop é o médio (com a chance de crítico) e supõe que todo passo acerta; sem
## mortes no meio (cada abate soma `morte.hit_stop`). O teste v2_status mede o ciclo de verdade em vários `dt` e compara.
func ciclo_do_combo(dt := QUADRO_REF) -> float:
	var pc := clampf(chance_critico(), 0.0, 1.0)
	var quadros := float(_quadros(float(cfg.golpe.pausa_fim_combo), dt))
	for i in cfg.golpe.passos.size():
		var p: Dictionary = cfg.golpe.passos[i]
		quadros += 1.0 + float(_quadros(mundo.heroi.duracao_do_passo(i), dt))
		quadros += lerpf(float(_quadros(hit_stop_do_acerto(p, false), dt)), float(_quadros(hit_stop_do_acerto(p, true), dt)), pc)
	return quadros * dt


## Quantos quadros de `dt` o jogo gasta para vencer `s` segundos (um quadro inteiro por vez, para cima).
static func _quadros(s: float, dt: float) -> int:
	return ceili(s / dt - 0.0001)


## Os passos do combo com o nome `nome` ("corte", "estocada"): o modificador solta onda nos cortes e lança na estocada, pelo NOME do passo.
func passos_de(nome: String) -> Array:
	var r: Array = []
	for p in cfg.golpe.passos:
		if str(p.nome) == nome:
			r.append(p)
	return r


func golpe_comecou(h, passo: Dictionary, dir: Vector2, dur: float) -> void:
	var cor := _cor(passo.cor)
	if h.contragolpe_t > 0.0:  # a janela do contragolpe (depois da ruptura): o corte sai alaranjado
		cor = cor.lerp(Color(1.0, 0.55, 0.2), 0.6)
	var tom := float(passo.get("tom", 1.0))  # tom e vol opcionais do passo: o Nicão é grave, o Lucas agudo
	if str(passo.get("tipo", "melee")) == "adagas" or passo.nome == "pancada":  # sem corte desenhado: as adagas e o chão aparecem no acerto
		audio.tocar(str(passo.som), randf_range(0.96, 1.06) * tom, float(passo.get("vol", -2.0)), 0.02)
		return
	var alc: float = alcance_do_passo(passo)
	var arco: float = arco_do_passo(passo)
	var vis := minf(dur * 0.95, float(passo.acerto_em) * dur / (0.5 if passo.nome == "estocada" else 0.42))
	fx.corte(h.pos + h.ORIGEM_GOLPE, dir.angle(), alc, arco, float(passo.lado), str(passo.nome), cor, vis)
	audio.tocar(str(passo.som), randf_range(0.96, 1.06) * tom, float(passo.get("vol", -2.0 if passo.nome != "estocada" else 0.0)), 0.02)


## O dano do golpe, no quadro "acerto_em": tudo o que está no arco apanha. Devolve quantos acertou.
func golpear(h, origem: Vector2, dir: Vector2, passo: Dictionary, _idx: int) -> int:
	if str(passo.get("tipo", "melee")) == "adagas":  # o Lucas: as adagas saem (v2/adagas.gd) e acertam por conta própria
		adagas.lancar(h, origem, dir, passo)
		return 0
	var alc: float = alcance_do_passo(passo)
	var arco: float = arco_do_passo(passo)
	var pancada: bool = passo.nome == "pancada"  # o Nicão no chão: em volta, empurrão para fora
	var forca: float = 1.0 + float(armas.mods.muralha) / 100.0  # modificador do Nicão: empurra e atordoa mais
	if pancada:
		_estouro_chao(h, alc, passo)
	var cos_meio := cos(deg_to_rad(arco * 0.5))
	var parada := 0.0
	var tremor := 0.0
	var n := 0
	var morreram: Array = []
	var cor := _cor(passo.cor)
	var k_contra: float = ruptura.fator_contragolpe(h)  # janela do contragolpe: só o golpe direto da katana ganha (ondas e golpes secundários, não)
	for m in mundo.monstros:
		if m.morrendo:
			continue
		var rel: Vector2 = m.pos + Vector2(0, -6) - origem
		var dist := rel.length()
		if dist > alc + m.raio:
			continue
		if dist > m.raio + 9.0 and rel.dot(dir) < dist * cos_meio:
			continue
		n += 1
		acertos += 1
		var crit: bool = randf() < chance_critico()
		var d: float = dano_do_passo(passo) * k_contra * (1.0 + randf_range(-float(cfg.golpe.variacao), float(cfg.golpe.variacao)))
		if crit:
			d *= float(cfg.golpe.critico.mult)
			criticos += 1
		var dano := maxi(1, roundi(d))
		var longe: Vector2 = rel.normalized() if dist > 0.5 else dir
		var rumo: Vector2 = longe if pancada else (dir * 0.55 + longe * 0.45).normalized()
		var emp: Vector2 = rumo * float(passo.empurrao) * (1.25 if crit else 1.0) * forca
		var morreu: bool = m.apanhar(dano, emp, float(passo.atordoa) * (1.3 if crit else 1.0) * (1.0 + (forca - 1.0) * 0.5))
		var ponto: Vector2 = m.pos + Vector2(0, -8)
		if crit and float(armas.mods.explode) > 0.0:  # crítico explosivo
			var raio_e: float = float(cartas.definicao("explode").raio) * (1.0 + (h.m_area - 1.0) * 0.6)
			armas.explodir(m.pos, float(dano) * float(armas.mods.explode) / 100.0, raio_e, COR_CRIT, m)
		fx.numero(m.pos + Vector2(0, -float(m.alt) * 0.85), str(dano), COR_CRIT if crit else COR_NUM, crit)
		fx.flash(m, 0.1)
		fx.folha("estrela", ponto, 15.0 if crit else 11.0, cor, 0.14)  # camada 1: a centelha de 2 quadros em todo acerto
		if crit or pancada or passo.nome == "estocada":  # camada 2: a marca branca sustentada só no golpe forte
			fx.flash(m, 0.45, Color.WHITE, 3)
		fx.faiscas(ponto - longe * float(m.raio) * 0.5, dir, 10 if crit else 6, cor, 200.0 if crit else 160.0)
		audio.tocar("critico" if crit else "impacto", randf_range(0.92, 1.1), 0.0, 0.03)
		parada = maxf(parada, hit_stop_do_acerto(passo, crit))
		tremor = maxf(tremor, float(cfg.golpe.critico.tremor) if crit else float(passo.tremor))
		if morreu:
			morreram.append(m)
	for m in morreram:
		matar(m)
		parada = maxf(parada, float(cfg.morte.hit_stop))
		tremor = maxf(tremor, float(cfg.morte.tremor))
	# modificadores da katana: o corte solta uma onda, a estocada solta uma lança de luz
	if passo.nome == "corte" and float(armas.mods.onda) > 0.0:
		armas.lancar_onda(origem, dir, armas.dano_da_onda(dano_do_passo(passo)))
	elif passo.nome == "estocada" and float(armas.mods.fura) > 0.0:
		armas.lancar_lanca(origem, dir, armas.dano_da_lanca(dano_do_passo(passo)))
	if pancada and float(armas.mods.abalo) > 0.0:  # modificador do Nicão: a pancada solta uma onda de choque para a frente
		armas.lancar_onda(origem, dir, dano_do_passo(passo) * float(armas.mods.abalo) / 100.0)
	processar_mortes()
	if n > 0:
		hit_stop(parada)
		if tremor > 0.0:
			mundo.cam.tremer(tremor, 0.17)
	elif pancada:
		mundo.cam.tremer(float(passo.tremor) * 0.5, 0.15)  # o chão treme mesmo sem acertar ninguém
	return n


## A pancada no chão do Nicão: duas ondas de poeira, estouro de pedrinhas, luz e o baque grave.
func _estouro_chao(h, alc: float, passo: Dictionary) -> void:
	var cor := _cor(passo.cor)
	var p: Vector2 = h.pos + Vector2(0, -2)
	fx.onda(p, Color(cor.r, cor.g, cor.b, 0.9), alc, 0.3)
	fx.onda(p, Color(1, 1, 1, 0.6), alc * 0.6, 0.2)
	fx.estouro(p, Color(0.75, 0.68, 0.55), 12)
	fx.luz_rapida(p + Vector2(0, -6), cor, 1.8, alc * 2.6, 0.3)
	audio.tocar("impacto", 0.5, 2.0, 0.05)


# ------------------------------------------------------------------ morte, orbes e combo


func matar(m) -> void:
	if not m.vivo:
		return
	mortes += 1
	var c: Vector2 = m.pos + Vector2(0, -8)
	m.esconder()
	m.morrendo = false
	m.queima_t = 0.0
	mundo.sombras.ativar(m, false)
	var grande: bool = m.elite or m.chefe
	fx.flash(m, 0.24, Color(1, 1, 1), 1)
	fx.estouro(c, Color(0.9, 0.9, 0.85), int(cfg.morte.particulas) * (3 if grande else 1))
	audio.tocar("morte", randf_range(0.9, 1.12) * (0.7 if grande else 1.0), -1.0, 0.03)
	mundo.abates += 1
	mundo.combo += 1
	combo_t = float(cfg.combo_abates.janela)
	mundo.maior_combo = maxi(mundo.maior_combo, mundo.combo)
	var mult := minf(1.0 + float(mundo.combo - 1) * float(cfg.combo_abates.xp_por_abate), float(cfg.combo_abates.xp_max))
	for i in m.n_orbes:
		orbes.soltar(m.pos, m.xp * mult)
	if float(armas.mods.folego) > 0.0:  # modificador da katana: matar recupera fôlego
		mundo.heroi.ganhar_folego(float(armas.mods.folego) / 100.0)
	if m.elite:
		elites.ao_morrer(m)
	if m.chefe:
		mundo.cam.tremer(4.0, 0.4)
		fx.onda(m.pos, Color(1.0, 0.9, 0.7, 0.9), 120.0, 0.6)
		hit_stop(0.25)
	mundo.devolver_monstro(m)
	if m.chefe:
		chefes.ao_morrer(m)
		m.chefe = false


## Golpe de fonte secundária (aura, lâminas, corvos, raio, runa, ondas, fogo): tira vida, empurra e mostra o número. A morte NÃO é
## processada na hora (fica na fila, saindo em processar_mortes) para não mexer em mundo.monstros enquanto alguém percorre a lista.
## Devolve true se a vida zerou. `numero` = mostra o número de dano.
func ferir(m, dano: float, dir: Vector2, empurrao: float, atordoa: float, cor: Color, numero := true, critico := false) -> bool:
	if not m.vivo or m.morrendo:
		return false
	var dn := maxi(1, roundi(dano))
	var morreu: bool = m.apanhar(dn, dir * empurrao, atordoa)
	ferimentos += 1
	dano_causado += dn
	if numero:
		fx.numero(m.pos + Vector2(0, -float(m.alt) * 0.8), str(dn), cor, critico)
		fx.flash(m, 0.08)
	if morreu:
		m.morrendo = true
		_fila.append(m)
	return morreu


## Mata quem morreu por golpe secundário ou fogo desde a última vez.
func processar_mortes() -> void:
	var guarda := 0
	while not _fila.is_empty() and guarda < 400:
		guarda += 1
		var m = _fila.pop_back()
		if m.vivo:
			matar(m)


## Um orbe chegou ao herói: XP, e o "plim" sobe de tom a cada orbe seguido.
func coletar(valor: float, _de: Vector2) -> void:
	if _plim_t > 0.0:
		_plim_n += 1
	else:
		_plim_n = 0
	_plim_t = float(cfg.xp.plim_janela)
	var tom := minf(1.0 + float(_plim_n) * float(cfg.xp.plim_passo), float(cfg.xp.plim_max))
	audio.tocar("orbe", tom, -4.0, 0.0)
	var h = mundo.heroi
	mundo.xp_coletado += valor
	fx.particula(h.pos + Vector2(randf_range(-4, 4), -18), Vector2(randf_range(-10, 10), -30), 0.28, 9.0, Color(0.5, 0.95, 1.0, 0.7), -10.0, true)
	progresso.ganhar_xp(valor)


# ------------------------------------------------------------------ herói


func esquiva_comecou(h) -> void:
	audio.tocar("esquiva", randf_range(0.95, 1.05), -1.0, 0.05)
	var p: Vector2 = h.pos
	for i in maxi(2, roundi(6 * fx.fator_part)):
		fx.particula(
			p + Vector2(randf_range(-4, 4), -1),
			-h.esq_dir * randf_range(20, 70) + Vector2(randf_range(-20, 20), randf_range(-24, -6)),
			randf_range(0.2, 0.4),
			2.0,
			Color(0.7, 0.75, 0.7, 0.8),
			40.0
		)


## Poeirinha nos pés de quem corre (partículas do pool de efeitos).
func poeira(h) -> void:
	var n := maxi(1, roundi(2.0 * fx.fator_part))
	for i in n:
		fx.particula(
			h.pos + Vector2(randf_range(-3, 3), -1),
			-h.vel.normalized() * randf_range(8, 26) + Vector2(randf_range(-8, 8), randf_range(-16, -4)),
			randf_range(0.22, 0.4),
			2.0 if randf() < 0.7 else 3.0,
			Color(0.62, 0.64, 0.58, 0.5),
			28.0
		)


func cansou(h) -> void:
	ofego(h)


## Ofego sutil de quem está sem fôlego: um sopro baixinho e duas partículas claras perto da cabeça.
func ofego(h) -> void:
	audio.tocar("ofego", randf_range(0.95, 1.05), -7.0, 0.5)
	for i in 2:
		fx.particula(
			h.pos + Vector2(randf_range(-3, 3), -34), Vector2(randf_range(-10, 10), randf_range(-14, -6)), 0.5, 5.0, Color(0.85, 0.9, 0.95, 0.35), -6.0, true
		)


func rastro_esquiva(h) -> void:
	fx.flash(h, 0.2, Color(0.55, 0.85, 1.0), 2)


func heroi_apanhou(valor: float) -> void:
	var h = mundo.heroi
	dano_sofrido += valor
	golpes_tomados += 1
	fx.numero(h.pos + Vector2(0, -44), str(roundi(valor)), COR_DANO_HEROI, false)
	fx.flash(h, 0.14, Color(1.0, 0.3, 0.3), 0, 0.9)
	fx.faiscas(h.pos + Vector2(0, -16), h.emp.normalized(), 8, Color(1.0, 0.3, 0.25), 150.0)
	audio.tocar("dano_heroi", randf_range(0.95, 1.05), 0.0, 0.05)
	hit_stop(0.06)


func heroi_morreu() -> void:
	var h = mundo.heroi
	audio.tocar("derrota", 1.0, 0.0, 0.0)
	fx.onda(h.pos + Vector2(0, -10), Color(1.0, 0.4, 0.35, 0.9), 60.0, 0.5)
	mundo.cam.tremer(3.0, 0.3)
	hit_stop(0.18)
	jogo = "morrendo"
	camera_lenta("morte", maxf(1.3, h.duracao_morte() + 0.25), 0.25)  # a queda do herói e o dissolve cabem antes da tela de resultado


func nivel_subiu(nivel: int) -> void:
	var h = mundo.heroi
	audio.tocar("nivel", 1.0, 0.0, 0.0)
	fx.onda(h.pos + Vector2(0, -12), Color(0.6, 0.95, 1.0, 0.95), 110.0, 0.45)
	fx.onda(h.pos + Vector2(0, -12), Color(1.0, 0.95, 0.7, 0.8), 70.0, 0.3)
	fx.luz_rapida(h.pos + Vector2(0, -12), Color(0.6, 0.95, 1.0), 1.8, 190.0, 0.5)
	fx.flash(h, 0.3, Color(0.7, 1.0, 1.0), 0, 0.8)
	orbes.atrair_todos(h.pos, 700.0)
	mundo.nivel_subiu.emit(nivel)


# ------------------------------------------------------------------ anúncios, elites, chefes e vitória (leva 3)


## Anúncio de texto livre: emite o sinal `anuncio(texto, cor)` do mundo, que o HUD (v2/hud_anuncios.gd) desenha. ONDA FORTE, ELITE e EVOLUÇÃO
## têm sinal próprio (o HUD escreve o texto sozinho), e o nível e os marcos de combo ele anuncia por conta dele: não repita aqui.
func anunciar(texto: String, cor: Color, _sub := "", _dur := 2.0) -> void:
	anuncios += 1
	ultimo_anuncio = texto
	mundo.anuncio.emit(texto, cor)


func onda_forte(numero: int) -> void:
	mundo.onda_forte.emit(numero)
	audio.tocar("onda", 1.0, 0.0, 0.0)


func elite_apareceu(nome: String, m, cor: Color) -> void:
	mundo.elite_apareceu.emit(nome)
	audio.tocar("elite", 1.0, 0.0, 0.1)
	fx.onda(m.pos, Color(cor.r, cor.g, cor.b, 0.9), 70.0, 0.5)


func chefe_apareceu(m, mk: Dictionary) -> void:
	var a: Dictionary = cartas.cfg.anuncios.minichefe if bool(mk.mini) else cartas.cfg.anuncios.chefe
	var cor := Color(mk.cor[0], mk.cor[1], mk.cor[2])
	mundo.chefe_apareceu.emit(str(mk.nome), float(mk.vida))
	anunciar(str(a.texto).replace("{nome}", str(mk.nome)), cor)
	audio.tocar("chefe", 0.7, 0.0, 0.3)
	fx.onda(m.pos, Color(cor.r, cor.g, cor.b, 0.9), 110.0, 0.7)
	mundo.cam.tremer(3.0, 0.4)


## Uma evolução aconteceu (cartas.gd chama): efeitos e aviso grande.
func evolucao_feita(ev: Dictionary) -> void:
	var h = mundo.heroi
	var cor := Color(ev.cor[0], ev.cor[1], ev.cor[2])
	mundo.evolucao.emit(str(ev.nome), str(ev.get("desc", "")))
	audio.tocar("evolucao", 1.0, 0.0, 0.0)
	hit_stop(FUSAO_PARADA_S)  # um instante parado e a câmera lenta: a fusão precisa ser lida, não passar voando
	camera_lenta("fusao", FUSAO_LENTA_S, FUSAO_ESCALA)
	fx.onda(h.pos + Vector2(0, -12), Color(cor.r, cor.g, cor.b, 0.95), 130.0, 0.6)
	fx.onda(h.pos + Vector2(0, -12), Color(1, 1, 1, 0.8), 80.0, 0.4)
	fx.luz_rapida(h.pos + Vector2(0, -12), cor, 2.4, 240.0, 0.7)
	fx.flash(h, 0.4, cor, 0, 0.9)
	fx.estouro(h.pos + Vector2(0, -16), cor, 20)
	mundo.cam.tremer(3.0, 0.3)


## Venceu o chefe: os monstros que sobraram estouram, câmera lenta e a tela de VITÓRIA.
func vitoria() -> void:
	if jogo == "vencendo" or jogo == "vitoria" or jogo == "morrendo" or jogo == "morte":
		return
	jogo = "vencendo"
	var a: Dictionary = cartas.cfg.anuncios.vitoria
	anunciar(str(a.texto), _cor(a.cor), "", 3.0)
	audio.tocar("vitoria", 1.0, 0.0, 0.0)
	for m in mundo.monstros.duplicate():
		matar(m)
	mundo.cam.tremer(5.0, 0.6)
	camera_lenta("vitoria", 1.8, 0.25)


## Emite partida_terminou(resultado) uma vez por partida (a meta-progressão lê isto).
func fim_de_partida(ganhou: bool) -> void:
	if fim_emitido:
		return
	fim_emitido = true
	venceu = ganhou
	var r := {
		"tempo": mundo.tempo_partida,
		"abates": mundo.abates,
		"nivel": mundo.heroi.nivel,
		"maior_combo": mundo.maior_combo,
		"venceu": ganhou,
		"almas": mundo.almas_partida,
		"mapa": str(mundo.id_mapa),
		"nivel_mapa": diretor.nivel,
		"niveis_mapa": diretor.niveis_total
	}
	if ganhou:
		Meta.marcar_mapa_vencido(str(mundo.id_mapa))  # o chefão do último nível foi vencido: o mapa fica vencido no save
	mundo.resultado = r
	mundo.partida_terminou.emit(r)


## Voltar ao santuário pelo menu de pausa (pausa.gd): a partida acaba como derrota, pelo mesmo caminho da morte
## (fim_de_partida credita as almas e mostra o resultado). Chamado com a árvore já despausada. Vale também com a escolha de cartas ou
## o baú abertos por trás do menu (o menu abre sobre eles): eles saem e o resultado entra.
func abandonar() -> void:
	if jogo != "jogando" and jogo != "escolha" and jogo != "bau":
		return
	telas.esconder()
	jogo = "abandono"
	pausado = true
	pausado_mundo = true
	fim_de_partida(false)
	telas.mostrar_resultado()


# ------------------------------------------------------------------ partida


## Zera a partida: monstros de volta ao pool, orbes e efeitos limpos, contadores e estado.
func limpar_partida() -> void:
	for m in mundo.monstros.duplicate():
		m.esconder()
		m.morrendo = false
		m.elite = false
		m.chefe = false
		mundo.sombras.ativar(m, false)
		mundo.devolver_monstro(m)
	_fila.clear()
	orbes.limpar()
	armas.limpar()
	adagas.limpar()
	avisos.limpar()
	ruptura.limpar()
	escudo.limpar()
	baus.limpar()
	elites.zerar()
	chefes.zerar()
	fx.limpar()
	parada_t = 0.0
	lento_t = 0.0
	lento_escala = 1.0
	lento_acao = ""
	pausado = false
	pausado_mundo = false
	jogo = "jogando"
	combo_t = 0.0
	_plim_t = 0.0
	_plim_n = 0
	acertos = 0
	criticos = 0
	mortes = 0
	ferimentos = 0
	dano_causado = 0.0
	dano_sofrido = 0.0
	golpes_tomados = 0
	fim_emitido = false
	venceu = false
	mundo.xp_coletado = 0.0
	mundo.resultado = {}
	progresso.zerar()
	diretor.zerar()
	telas.esconder()


## Desfaz as referências cruzadas entre os módulos (RefCounted que se apontam não são liberados sozinhos). O mundo chama ao sair da cena.
func liberar() -> void:
	for m in [orbes, progresso, diretor, telas, fx, cartas, armas, adagas, avisos, ruptura, escudo, elites, baus, chefes]:
		if m == null:
			continue
		for campo in ["combate", "mundo"]:
			if campo in m:
				m.set(campo, null)
	orbes = null
	progresso = null
	diretor = null
	telas = null
	fx = null
	cartas = null
	armas = null
	adagas = null
	avisos = null
	ruptura = null
	escudo = null
	elites = null
	baus = null
	chefes = null
	mundo = null


func _cor(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))
