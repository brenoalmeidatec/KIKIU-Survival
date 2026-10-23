extends RefCounted
## A HABILIDADE (tecla E ou LB do controle) de cada herói da v2, no padrão Overwatch: botão direito = secundário (o escudo, v2/escudo.gd), E = habilidade
## (esta, uma por herói), Q = ultimate (v2/especial.gd, enche por dano e abates). A E tem recarga por TEMPO, curta (8 a 14 s), e começa pronta.
##
## Qual E cada herói tem é DADO (dados/v2_habilidade.json > padrao e herois > chave do herói), igual ao secundário e ao Q. Os três de hoje:
##  - RUPTURA (Hazaki): a ruptura de sempre (v2/ruptura.gd: segurar carrega, soltar racha o chão em 360 graus e abre o contragolpe da katana). Não é
##    disparada por este módulo: ele só diz "a E dele é a ruptura" (hab_id = "ruptura") e o herói segue o caminho antigo (rup_*).
##  - INVESTIDA DE ESCUDO (Nicão): investe para a frente com o escudo erguido, INVULNERÁVEL, empurrando e atordoando tudo o que está na faixa, e fecha com
##    uma pancada curta onde para. O Q dele (Terremoto) é a pancada gigante parado; a E é a entrada em movimento.
##  - SALTO DAS ADAGAS (Lucas): salta para TRÁS (contra a mira), INVULNERÁVEL, soltando um leque de adagas para a frente na decolagem e outro menor ao
##    pousar. O Q dele (Tempestade) é o círculo parado; a E é o recuo que abre distância já atirando.
## Id desconhecido deixa a tecla E sem efeito.
##
## O herói (v2/heroi.gd) cuida da entrada (`habilidade()`), do estado (Estado.HABILIDADE), da recarga (hab_recarga, por tempo) e dos campos que o HUD
## lê (hab_*); este módulo cuida do disparo (movimento, dano, controle, adagas), do visual (só efeitos que já existem em v2/efeitos.gd) e do som.
## Dono: o combate (`combate.habilidade`). Números em dados/v2_habilidade.json (veja o `_ajuda` de lá): nada de jogo fica fixo aqui. As cartas da E
## (Punho de terra: dano, Pulso ligeiro: recarga, Estrondo: atordoa; v2_ruptura.json > cartas) valem para QUALQUER E e ficam em `combate.ruptura.somas`;
## Contragolpe e Eco do chão só fazem efeito na ruptura (e só saem para quem tem a ruptura).
##
## API: montar(c), limpar(), id_de(chave), bloco_de(chave), e_ruptura(chave), armar(h) [põe os campos hab_* e a E pronta], recarga_de(b) [com as cartas],
## iniciar(h) -> bool, quadro(h, dt, v) -> deslocamento [chamado pelo herói em Estado.HABILIDADE], cancelar(h), fim_de_partida(), pronta(h), negou(h).

const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x (a mesma da ruptura, do escudo e dos avisos)
const COR_NUM := Color(1.0, 0.96, 0.84)
const COR_CRIT := Color(1.0, 0.74, 0.2)

var combate
var mundo
var comum: Dictionary = {}  # dados/v2_habilidade.json > comum
var padrao := "ruptura"
var herois: Dictionary = {}  # chave do herói -> id da E (os testes mexem aqui)
var blocos: Dictionary = {}  # id -> bloco de números
var disparos := 0  # testes: quantas E saíram (sem contar a ruptura)
var ultimo: Dictionary = {}  # a última E (testes): id, n (monstros atingidos no total), mortes

var _id := ""  # a E em andamento ("" = nenhuma)
var _c: Dictionary = {}  # o bloco dela
var _t := 0.0  # s desde o disparo (tempo do mundo)
var _fase := 0
var _dir := Vector2.RIGHT  # a direção do movimento, travada no disparo
var _mira := Vector2.RIGHT  # a direção da mira no disparo (as adagas do Lucas saem para ela)
var _andou := 0.0  # px já andados
var _rastro_t := 0.0
var _ja: Dictionary = {}  # instance_id -> true: quem esta E já feriu (a faixa não repete)
var _n := 0
var _mortes := 0
var _numeros := 0
var _escala := 1.0  # a área do herói (cartas) nos raios desta E


func montar(c) -> void:
	combate = c
	mundo = c.mundo
	var d: Dictionary = Dados.json("v2_habilidade")
	comum = d.comum
	padrao = str(d.get("padrao", "ruptura"))
	herois = d.get("herois", {})
	for k in d:
		if d[k] is Dictionary and k != "comum" and k != "herois":
			blocos[k] = d[k]


## Partida nova: nada em andamento e a E do herói pronta.
func limpar() -> void:
	_id = ""
	_c = {}
	_t = 0.0
	_fase = 0
	_ja.clear()
	_numeros = 0
	disparos = 0
	ultimo = {}
	if mundo != null and mundo.heroi != null:
		armar(mundo.heroi)


## O id da E do herói `chave` (dados > herois, senão o padrão); "" se o id não tem bloco.
func id_de(chave: String) -> String:
	var id := str(herois.get(chave, padrao))
	return id if blocos.has(id) else ""


## O bloco de números da E do herói `chave` (vazio se não tem).
func bloco_de(chave: String) -> Dictionary:
	var id := id_de(chave)
	return blocos[id] if id != "" else {}


## A E do herói `chave` é a ruptura (o caminho antigo, rup_*)?
func e_ruptura(chave: String) -> bool:
	return id_de(chave) == "ruptura"


## Põe no herói o que o HUD lê (id, nome, rótulo, ícone, cor) e a E pronta. Chamado quando o herói nasce e quando a partida recomeça.
func armar(h) -> void:
	var id := id_de(str(h.chave))
	var b := bloco_de(str(h.chave))
	h.hab_id = id
	h.hab_invul = false
	h.hab_t = 0.0
	h.hab_nega_t = 0.0
	h.hab_recarga = 0.0
	h.hab_recarga_max = 1.0
	if b.is_empty():
		h.hab_nome = ""
		h.hab_rotulo = ""
		h.hab_icone = ""
		return
	h.hab_nome = str(b.nome)
	h.hab_rotulo = str(b.rotulo)
	h.hab_icone = str(b.icone)
	h.hab_cor = _cor(b.cor)
	if id != "ruptura":
		h.hab_recarga_max = recarga_de(b)


## A recarga da E `b` com as cartas (Pulso ligeiro): encurta até `recarga_cartas_max` (o mesmo teto da ruptura), nunca abaixo do piso.
func recarga_de(b: Dictionary) -> float:
	var teto := float(combate.ruptura.cfg.recarga_cartas_max)
	var r := float(b.recarga) * (1.0 - minf(float(combate.ruptura.somas.recarga) / 100.0, teto))
	return maxf(r, float(comum.piso))


func _bonus_dano() -> float:
	return 1.0 + float(combate.ruptura.somas.dano) / 100.0


func _bonus_atordoa(a: float) -> float:
	return a * (1.0 + float(combate.ruptura.somas.atordoa) / 100.0)


## O herói apertou E e pode: começa a E. Devolve false se o id é a ruptura ou desconhecido. O herói já cancelou o resto e entrou no estado.
func iniciar(h) -> bool:
	var id := id_de(str(h.chave))
	if id == "" or id == "ruptura":
		return false
	_id = id
	_c = blocos[id]
	_t = 0.0
	_fase = 0
	_ja.clear()
	_n = 0
	_numeros = 0
	_mortes = 0
	_andou = 0.0
	_rastro_t = 0.0
	_escala = 1.0 + (float(h.m_area) - 1.0) * float(comum.area_k)
	var d: Vector2 = h.mira_mundo - h.centro()
	_mira = d.normalized() if d.length() > 4.0 else h.dir_olhar
	if _mira.length_squared() < 0.01:
		_mira = Vector2.RIGHT
	h.dir_olhar = _mira
	_dir = _mira
	if id == "salto_adagas":
		_dir = -_mira  # o Lucas salta para trás, de frente para a mira
	h.hab_t = 0.0
	h.hab_dur = float(_c.dur)
	h.hab_invul = true
	h.hab_anim_passo = int(_c.anim.passo)
	h.hab_anim_ciclos = float(_c.anim.ciclos)
	h.hab_anim_antes = str(_c.anim.get("antes", ""))
	h.hab_anim_antes_ate = float(_c.anim.get("antes_ate", 0.0))
	h.hab_anim_quadros = _c.anim.get("quadros", [])
	h.hab_recarga_max = recarga_de(_c)
	h.hab_recarga = h.hab_recarga_max
	disparos += 1
	var cor := _cor(_c.cor)
	var c = combate
	c.fx.onda(h.pos, Color(cor.r, cor.g, cor.b, 0.9), 34.0, 0.2)
	c.fx.luz_rapida(h.pos + Vector2(0, -10), cor, 1.6, 100.0, 0.3)
	c.audio.tocar("esquiva", 1.2 if id == "salto_adagas" else 0.8, 0.0, 0.0)
	match id:
		"investida_escudo":
			c.audio.tocar("ruptura_carga", 0.9, -3.0, 0.0)
		"salto_adagas":
			_leque(h, _c.saida)
	return true


## O herói em Estado.HABILIDADE (um quadro, tempo do mundo): devolve o deslocamento do quadro e encerra no fim da `dur`.
func quadro(h, dt: float, _v: Vector2) -> Vector2:
	if _id == "":
		_encerrar(h)
		return Vector2.ZERO
	var c = combate
	if c.jogo != "jogando" or c.pausado:
		return Vector2.ZERO
	_t += dt
	h.hab_t = _t
	var dur := float(_c.dur)
	var cor := _cor(_c.cor)
	# o movimento: arranca rápido e desacelera no fim (a distância total é sempre a dos dados, em qualquer passo de tempo)
	var f0 := clampf((_t - dt) / dur, 0.0, 1.0)
	var f1 := clampf(_t / dur, 0.0, 1.0)
	var passo := (_curva(f1) - _curva(f0)) * float(_c.distancia)
	var desl := _dir * passo
	_andou += passo
	if _id == "investida_escudo":
		_faixa(h)
	_rastro_t -= dt
	if _rastro_t <= 0.0 and passo > 0.0:
		_rastro_t = 0.035
		c.fx.flash(h, 0.22, cor, 2)
		for i in maxi(1, roundi(2.0 * c.fx.fator_part)):
			c.fx.particula(h.pos + Vector2(randf_range(-4, 4), randf_range(-14, -2)), -_dir * randf_range(30, 90), randf_range(0.2, 0.35), 2.0, cor, 0.0, true)
	if _t >= dur:
		_fim(h)
		_encerrar(h)
	return desl


## A fração do caminho andada em f (0 a 1): sobe rápido e termina devagar (ease-out), de 0 a 1.
func _curva(f: float) -> float:
	return 1.0 - (1.0 - f) * (1.0 - f)


## A faixa do escudo na frente do herói: quem entra nela leva o golpe, uma vez só, e é empurrado para a frente.
func _faixa(h) -> void:
	var c = combate
	var largura := float(_c.largura) * _escala
	var cor := _cor(_c.cor)
	var chance: float = c.chance_critico()
	var variacao := float(c.cfg.golpe.variacao)
	var feitos := 0
	for m in mundo.monstros:
		if not m.vivo or m.morrendo or _ja.has(m.get_instance_id()):
			continue
		var rel: Vector2 = m.pos - h.pos
		var along := rel.dot(_dir)
		if along < -16.0 or along > float(_c.alcance):
			continue
		if absf(rel.cross(_dir)) > largura + float(m.raio):
			continue
		_ja[m.get_instance_id()] = true
		_n += 1
		feitos += 1
		var lado := Vector2(-_dir.y, _dir.x) * (1.0 if rel.cross(_dir) < 0.0 else -1.0)
		var fora := (_dir * 0.8 + lado * 0.2).normalized()
		var crit := randf() < chance
		var d: float = float(_c.dano) * float(h.m_dano) * _bonus_dano() * (1.0 + randf_range(-variacao, variacao))
		if crit:
			d *= float(c.cfg.golpe.critico.mult)
		var dn := maxi(1, roundi(d))
		c.fonte_dano = "habilidade"
		if c.ferir(m, d, fora, float(_c.empurrao), _bonus_atordoa(float(_c.atordoa)), COR_NUM, false):
			_mortes += 1
		var ponto: Vector2 = m.pos + Vector2(0, -8)
		if _numeros < int(comum.numeros_max) or crit:
			_numeros += 1
			c.fx.numero(m.pos + Vector2(0, -float(m.alt) * 0.85), str(dn), COR_CRIT if crit else COR_NUM, crit)
			c.fx.flash(m, 0.1)
			c.fx.folha("estrela", ponto, 15.0 if crit else 11.0, cor, 0.14)
			c.fx.faiscas(ponto, fora, 6, cor, 170.0)
		c.audio.tocar("critico" if crit else "impacto", randf_range(0.85, 1.0), -3.0, 0.05)
	if feitos > 0:
		c.processar_mortes()


## Um leque de adagas na direção da mira (as adagas do Lucas, v2/adagas.gd: o dano de cada uma já leva o bônus de dano do herói e as cartas da E).
func _leque(h, p: Dictionary) -> void:
	var cor := _cor(_c.cor)
	var passo := {
		"n": int(p.n),
		"leque": float(p.leque),
		"dano": float(p.dano) * _bonus_dano(),
		"vel": float(p.vel),
		"alcance": float(p.alcance),
		"perfura": int(p.perfura),
		"empurrao": float(p.empurrao),
		"atordoa": _bonus_atordoa(float(p.atordoa)),
		"cor": [cor.r, cor.g, cor.b],
	}
	combate.fonte_dano = "habilidade"
	combate.adagas.lancar(h, h.pos + h.ORIGEM_GOLPE, _mira, passo)
	combate.audio.tocar("corte2", randf_range(1.2, 1.5), -4.0, 0.04)


## O fim do movimento (um quadro depois do último passo, onde o herói parou de verdade): a pancada do escudo ou o pouso com o segundo leque.
func _fim(h) -> void:
	var c = combate
	var cor := _cor(_c.cor)
	match _id:
		"investida_escudo":
			var f: Dictionary = _c.final
			var raio := float(f.raio) * _escala
			_numeros = 0
			_pulso(h, h.pos, raio, float(f.dano), float(f.empurrao), _bonus_atordoa(float(f.atordoa)), cor)
			c.fx.onda(h.pos, Color(cor.r, cor.g, cor.b, 0.9), raio, 0.25)
			c.fx.onda(h.pos, Color(1, 1, 1, 0.6), raio * 0.6, 0.18)
			c.fx.estouro(h.pos + Vector2(0, -4), Color(0.75, 0.68, 0.55), 10)
			c.fx.luz_rapida(h.pos + Vector2(0, -8), cor, 2.0, 2.4 * raio, 0.3)
			c.audio.tocar("impacto", 0.6, 1.0, 0.0)
			mundo.cam.tremer(float(f.tremor), 0.2)
			if _n > 0:
				c.hit_stop(float(f.hit_stop))
		"salto_adagas":
			_leque(h, _c.pouso)
			c.fx.onda(h.pos, Color(cor.r, cor.g, cor.b, 0.8), 40.0, 0.22)
			c.fx.estouro(h.pos + Vector2(0, -4), cor, 6)
			c.audio.tocar("impacto", 0.9, -4.0, 0.0)


## Fere tudo dentro da elipse do chão de `raio` em volta de `centro` (elite e chefe entram; o herói nunca é ferido). Devolve quantos acertou.
func _pulso(h, centro: Vector2, raio: float, dano_b: float, emp: float, atordoa: float, cor: Color) -> int:
	var c = combate
	var chance: float = c.chance_critico()
	var variacao := float(c.cfg.golpe.variacao)
	var n := 0
	for m in mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var rel: Vector2 = m.pos - centro
		if not _na_elipse(rel, raio + m.raio):
			continue
		var dist := rel.length()
		var fora: Vector2 = rel / dist if dist > 0.5 else _dir
		var crit := randf() < chance
		var d: float = dano_b * float(h.m_dano) * _bonus_dano() * (1.0 + randf_range(-variacao, variacao))
		if crit:
			d *= float(c.cfg.golpe.critico.mult)
		var dn := maxi(1, roundi(d))
		c.fonte_dano = "habilidade"
		if c.ferir(m, d, fora, emp, atordoa, COR_NUM, false):
			_mortes += 1
		n += 1
		_n += 1
		if _numeros < int(comum.numeros_max) or crit:
			_numeros += 1
			c.fx.numero(m.pos + Vector2(0, -float(m.alt) * 0.85), str(dn), COR_CRIT if crit else COR_NUM, crit)
			c.fx.flash(m, 0.1)
			c.fx.faiscas(m.pos + Vector2(0, -8), fora, 5, cor, 160.0)
	c.processar_mortes()
	return n


## Um ponto relativo (rel) está dentro da elipse do chão de raio r (x inteiro, y a 62%)?
func _na_elipse(rel: Vector2, r: float) -> bool:
	return Vector2(rel.x, rel.y / ACHATA).length_squared() <= r * r


## A partida acabou (vitória ou derrota) com a E no ar: desfaz o estado e a invulnerabilidade.
func fim_de_partida() -> void:
	if mundo != null and mundo.heroi != null:
		cancelar(mundo.heroi)


## Desfaz a E em andamento sem mais efeito (a recarga já foi armada no disparo). Idempotente.
func cancelar(h) -> void:
	if _id == "":
		return
	_encerrar(h)


func _encerrar(h) -> void:
	ultimo = {"id": _id, "n": _n, "mortes": _mortes}
	_id = ""
	h.hab_invul = false
	h.hab_t = 0.0
	if h.estado == h.Estado.HABILIDADE:
		h.estado = h.Estado.LIVRE
	h.pausa_t = maxf(h.pausa_t, 0.1)  # só impede o golpe um instante, não impede andar


## A recarga zerou: um anel nos pés e um tique, uma vez.
func pronta(h) -> void:
	var cor: Color = h.hab_cor
	combate.fx.onda(h.pos, Color(cor.r, cor.g, cor.b, 0.8), 26.0, 0.25)
	combate.audio.tocar("ruptura_pronta", 1.4, -6.0, 0.0)


## Apertou na recarga: o som grave (o slot do HUD treme pelo hab_nega_t do herói).
func negou(_h) -> void:
	combate.audio.tocar("ruptura_cancela", 0.7, -4.0, 0.0)


func _cor(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))
