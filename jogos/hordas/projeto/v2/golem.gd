extends RefCounted
## Golem de Barro (carta "golem_barro") e Colosso de Pedra (a fusão dele): o aliado de barro que anda de verdade e esmaga o chão.
## O pool de aliados é o de `v2/armas_novas.gd`; este arquivo só tem a lógica e o desenho do golem (funções estáticas sobre o item do pool).
##
## A arte é a folha 3D `assets/v2/armas/golem_barro_dir.png` (fonte_arte/blender_golem/gerar_golem.py): 16 colunas x 5 linhas.
## Colunas 0-7 = ciclo de andar (as pisadas são os quadros 2 e 6, o 2 também é o "parado"), 8-15 = ataque (o 12, `QUADRO_IMPACTO`, é a pancada).
## Linhas = frente, 3/4 frente, perfil, 3/4 costas, costas, escolhidas pela direção do movimento (como os monstros, com histerese);
## a folha olha para a direita e o lado esquerdo é o espelho.
##
## Estados do item (chaves do dicionário do pool): e = ANDANDO / ATACANDO / SURGINDO, et = tempo no estado, lin = linha da vista,
## pf = fase do passo (1 = um ciclo de andar completo, avança com a distância ANDADA: parado, o quadro não muda e o pé não escorrega),
## mov = andou neste quadro, imp = a pancada deste ataque já caiu, ip = onde a pancada cai, sumiu = o desmoronar já soltou os torrões.
## O dano cai quando a animação cruza o quadro do impacto (não quando o ataque começa), em área no ponto `ip` guardado no início do golpe.

const FOLHA := "res://assets/v2/armas/golem_barro_dir.png"
const QUADRO := Vector2(82, 104)  # tamanho de cada quadro da folha (o teste confere com o png e o .json)
const PE := Vector2(41, 83)  # ponto do quadro que fica no chão (it.p)
const COL_ANDAR := 8
const COL_ATAQUE := 8
const LINHAS := 5
const PASSO_LINHA := 45.0  # graus entre uma vista e a próxima
const HISTERESE := 8.0  # graus de folga para não piscar de vista na fronteira
const CICLO_PX := 40.0  # pixels andados por ciclo de andar (8 quadros) = 2 passos de ~20 px, a separação dos pés da arte (medida no perfil, quadro 2): o pé de apoio não escorrega
const PARADO := 2  # quadro de andar usado parado (pernas afastadas, os dois pés no chão)
const TEMPOS_ATAQUE := [0.09, 0.08, 0.08, 0.10, 0.06, 0.11, 0.10, 0.10]  # duração de cada quadro do ataque (s); soma 0,72 s, para caber no "tique" de 0,8 s da carta
const QUADRO_IMPACTO := 4  # índice (dentro do ataque) do quadro da pancada
const ALCANCE := 30.0  # distância (plano achatado) do alvo a partir da qual ele para e ataca
const RAIO_IMPACTO := 42.0  # raio da pancada no chão
const RESPIRO_MIN := 0.08  # menor pausa entre o fim de um ataque e o começo do próximo (a cadência vem do "tique" da carta: ciclo = max(tique, ataque + isto))
const EMPURRA := 45.0  # empurrão da pancada em cada monstro (o golpe antigo, de contato, empurrava 30; o monstro divide pelo peso)
const ATORDOA := 0.08  # atordoamento da pancada, em s (o golpe antigo dava 0,05)
const SURGIR_T := 0.55  # sobe do chão
const SUMIR_T := 0.6  # desmorona nos últimos segundos de vida
const ACHATA := 0.62
const COLOSSO := "colosso_de_pedra"
const ANDANDO := 0
const ATACANDO := 1
const SURGINDO := 2
const COR_BARRO := Color(0.66, 0.42, 0.27, 0.75)
const COR_TORRAO := Color(0.55, 0.33, 0.2)
const COR_PEDRA := Color(0.6, 0.57, 0.54)

static var _tex: Texture2D
static var _lida := false


## A folha do golem (carrega uma vez; null se faltar o arquivo, e o aliado volta ao desenho antigo).
static func tex() -> Texture2D:
	if not _lida:
		_lida = true
		_tex = load(FOLHA) as Texture2D
	return _tex


static func eh_golem(id: String) -> bool:
	return id == "golem_barro" or id == COLOSSO


static func escala(id: String) -> float:
	return 1.3 if id == COLOSSO else 1.0


## A linha (0 frente, 1 3/4 frente, 2 perfil, 3 3/4 costas, 4 costas) para ir na direção `v` (tela, y para baixo), com histerese:
## perto da fronteira entre duas vistas fica na que já estava (`atual`).
static func linha_de(v: Vector2, atual: int) -> int:
	var ang := rad_to_deg(atan2(absf(v.x), v.y))  # 0 = descendo (frente), 90 = de lado, 180 = subindo (costas)
	if atual >= 0 and atual < LINHAS and absf(ang - atual * PASSO_LINHA) <= PASSO_LINHA * 0.5 + HISTERESE:
		return atual
	return clampi(roundi(ang / PASSO_LINHA), 0, LINHAS - 1)


## Duração total do ataque (s).
static func tempo_ataque() -> float:
	var s := 0.0
	for d in TEMPOS_ATAQUE:
		s += float(d)
	return s


## Instante (s desde o começo do ataque) em que a animação cruza o quadro da pancada.
static func tempo_impacto() -> float:
	var s := 0.0
	for i in QUADRO_IMPACTO:
		s += float(TEMPOS_ATAQUE[i])
	return s


## Pausa depois do ataque: o "tique" da carta (dados/v2_cartas.json, sobe e desce com os níveis) é o ciclo inteiro; nunca menos que `RESPIRO_MIN`.
static func respiro(it: Dictionary) -> float:
	return maxf(RESPIRO_MIN, float(it.a.st.tique) - tempo_ataque())


## Quadro do ataque (0 a 7) para `t` segundos desde o começo dele.
static func quadro_ataque(t: float) -> int:
	var s := 0.0
	for i in TEMPOS_ATAQUE.size():
		s += float(TEMPOS_ATAQUE[i])
		if t < s:
			return i
	return TEMPOS_ATAQUE.size() - 1


## Quadro de andar (0 a 7) para a fase do passo `pf` (1 = um ciclo).
static func quadro_andar(pf: float) -> int:
	return clampi(floori(fposmod(pf, 1.0) * COL_ANDAR), 0, COL_ANDAR - 1)


## Chaves novas do item do pool (o `montar` e o `_novo` do armas_novas usam: um slot reaproveitado nunca herda o estado de outro golem).
static func zerar(it: Dictionary) -> void:
	it.g = false
	it.e = ANDANDO
	it.et = 0.0
	it.lin = 0
	it.pf = 0.0
	it.mov = false
	it.imp = false
	it.ip = Vector2.ZERO
	it.sumiu = false


## O item acaba de nascer: sobe do chão olhando para a câmera.
static func nascer(nv, it: Dictionary) -> void:
	it.g = true
	it.e = SURGINDO
	it.et = 0.0
	it.lin = 0
	it.v = Vector2(0, 1)
	it.sumiu = false
	var esc := escala(str(it.a.id))
	var p: Vector2 = it.p
	_torroes(nv, p, 8, 40.0 * esc, esc)
	_poeira(nv, p, 6, 30.0 * esc, esc)
	nv.pai.fx.onda(p, Color(0.85, 0.65, 0.45, 0.6), 22.0 * esc, 0.3)


# ------------------------------------------------------------------ movimento e ataque


static func mover(nv, it: Dictionary, h, dt: float, perto: Array) -> void:
	it.et = float(it.et) + dt
	it.t = float(it.t) - dt  # a recarga do golpe (o armas_novas não conta o tempo do aliado)
	it.mov = false
	if float(it.vida) <= SUMIR_T:
		_desmoronar(nv, it, dt)
		return
	match int(it.e):
		SURGINDO:
			if randf() < dt * 24.0:
				_poeira(nv, it.p, 1, 22.0 * escala(str(it.a.id)), escala(str(it.a.id)))
			if float(it.et) >= SURGIR_T:
				it.e = ANDANDO
				it.et = 0.0
		ATACANDO:
			_atacar(nv, it)
		_:
			_andar(nv, it, h, dt, perto)


static func _andar(nv, it: Dictionary, h, dt: float, perto: Array) -> void:
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	var esc := escala(str(a.id))
	var alvo = nv._mais_perto(it.p, 400.0, perto)
	var dest: Vector2
	if alvo != null:
		dest = alvo.pos
	else:
		dest = h.pos + Vector2.from_angle(float(it.fase)) * 50.0  # sem inimigo, anda em volta do herói
	var d: Vector2 = dest - it.p
	if absf(d.x) > 2.0:
		it.r = signf(d.x)
	if alvo != null and nv._eli(d).length() <= ALCANCE * esc + float(alvo.raio):
		# em alcance: para (olhando para o alvo) e ataca quando a recarga deixa
		if d.length() > 1.0:
			it.v = (it.v as Vector2).lerp(d.normalized(), clampf(dt * 12.0, 0.0, 1.0))
			it.lin = linha_de(it.v, int(it.lin))
		if float(it.t) <= 0.0:
			_iniciar_ataque(it, d, esc)
		return
	if d.length() > 1.0:
		var dir := d.normalized()
		var passo := minf(float(st.vel) * dt, d.length())
		it.p = it.p + dir * passo
		it.v = (it.v as Vector2).lerp(dir, clampf(dt * 10.0, 0.0, 1.0))  # suavizado: o quadro não pisca na virada
		it.lin = linha_de(it.v, int(it.lin))
		var antes := float(it.pf)
		it.pf = antes + passo / (CICLO_PX * esc)
		it.mov = true
		if floori((float(it.pf) - 0.25) * 2.0) != floori((antes - 0.25) * 2.0):  # cruzou o quadro 2 ou o 6: um pé bateu no chão
			_pisada(nv, it, esc)


static func _iniciar_ataque(it: Dictionary, d: Vector2, esc: float) -> void:
	var dir := d.normalized()
	it.e = ATACANDO
	it.et = 0.0
	it.imp = false
	it.v = dir  # a vista fica travada durante o golpe
	it.lin = linha_de(dir, int(it.lin))
	it.ip = (it.p as Vector2) + dir * (ALCANCE * esc * 0.75)


static func _atacar(nv, it: Dictionary) -> void:
	var et := float(it.et)
	if not bool(it.imp) and et >= tempo_impacto():
		it.imp = true
		_impacto(nv, it)
	if et >= tempo_ataque():
		it.e = ANDANDO
		it.et = 0.0
		it.t = respiro(it)


## A pancada: dano em área no ponto guardado no início do golpe, onda no chão, torrões, poeira, clarão e um tremor leve.
static func _impacto(nv, it: Dictionary) -> void:
	var pai = nv.pai
	var a: Dictionary = it.a
	var esc := escala(str(a.id))
	var p: Vector2 = it.ip
	var raio := RAIO_IMPACTO * esc
	pai._dano_area(p, raio, nv._dano(a.st), EMPURRA, ATORDOA, a.cor, "aliado")
	var fx = pai.fx
	fx.onda(p, Color(0.9, 0.65, 0.42, 0.9), raio, 0.3)
	fx.onda(p, Color(1.0, 0.8, 0.5, 0.6), raio * 0.55, 0.2)
	fx.folha("anel", p, raio * 1.15, Color(0.85, 0.6, 0.4, 0.8), 0.3)
	fx.luz_rapida(p + Vector2(0, -6), Color(1.0, 0.62, 0.3), 2.0, raio * 2.4, 0.25)
	_torroes(nv, p, 12, 90.0 * esc, esc)
	_poeira(nv, p, 9, 70.0 * esc, esc)
	pai.combate.audio.tocar("impacto", randf_range(0.55, 0.7) / sqrt(esc), -1.0, 0.1)
	if (pai.mundo.heroi.pos as Vector2).distance_to(p) < 360.0:
		pai.mundo.cam.tremer(0.9 * esc, 0.12)


static func _pisada(nv, it: Dictionary, esc: float) -> void:
	var p: Vector2 = it.p
	_poeira(nv, p + Vector2(randf_range(-9.0, 9.0), 2.0) * esc, 2, 26.0 * esc, esc)
	if randf() < 0.5:
		_torroes(nv, p, 1, 40.0 * esc, esc)
	if (nv.pai.mundo.heroi.pos as Vector2).distance_to(p) < 240.0:
		nv.pai.mundo.cam.tremer(0.35 * esc, 0.06)


## Últimos instantes de vida: afunda no chão soltando torrões (uma vez a rajada, depois a poeira fina).
static func _desmoronar(nv, it: Dictionary, dt: float) -> void:
	var esc := escala(str(it.a.id))
	if not bool(it.sumiu):
		it.sumiu = true
		it.e = ANDANDO
		var p: Vector2 = it.p
		_torroes(nv, p + Vector2(0, -18.0 * esc), 12, 70.0 * esc, esc)
		_poeira(nv, p, 6, 40.0 * esc, esc)
		nv.pai.fx.onda(p, Color(0.8, 0.6, 0.42, 0.5), 30.0 * esc, 0.35)
	if randf() < dt * 30.0:
		_poeira(nv, it.p, 1, 28.0 * esc, esc)


## `n` pedaços de barro e pedra que voam para cima e para fora e caem (partículas do pool de v2/efeitos.gd).
static func _torroes(nv, p: Vector2, n: int, vel: float, esc: float) -> void:
	var fx = nv.pai.fx
	n = maxi(1, roundi(n * fx.fator_part))
	for i in n:
		var ang := randf() * TAU
		var v := Vector2(cos(ang) * vel * randf_range(0.4, 1.0), sin(ang) * vel * 0.4 - randf_range(50.0, 130.0))
		var cor := COR_PEDRA if randf() < 0.25 else COR_TORRAO.lerp(Color(0.85, 0.62, 0.42), randf() * 0.6)
		fx.particula(p + Vector2(randf_range(-6.0, 6.0), randf_range(-14.0, -2.0)) * esc, v, randf_range(0.45, 0.8), 3.0 if randf() < 0.6 else 4.0, cor, 340.0)


## `n` nuvenzinhas de poeira que se abrem e sobem devagar.
static func _poeira(nv, p: Vector2, n: int, vel: float, esc: float) -> void:
	var fx = nv.pai.fx
	n = maxi(1, roundi(n * fx.fator_part))
	for i in n:
		var ang := randf() * TAU
		var v := Vector2(cos(ang) * vel * randf_range(0.3, 1.0), sin(ang) * vel * 0.3 - randf_range(4.0, 20.0))
		fx.particula(
			p + Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 1.0)) * esc, v, randf_range(0.35, 0.6), randf_range(5.0, 8.0) * esc, COR_BARRO, -12.0
		)


# ------------------------------------------------------------------ desenho


## Coluna e linha da folha do golem agora (o teste usa para conferir o ciclo andar -> atacar).
static func quadro_de(it: Dictionary) -> Vector2i:
	var col: int
	if int(it.e) == ATACANDO:
		col = COL_ANDAR + quadro_ataque(float(it.et))
	elif bool(it.mov):
		col = quadro_andar(float(it.pf))
	else:
		col = PARADO
	return Vector2i(col, int(it.lin))


## Camada normal (`no_corpo`, a que recebe a luz): sombra no chão e o quadro certo da folha, espelhado para olhar para onde vai.
## Surgindo e desmoronando mostram só uma fatia que sobe (ou afunda) pelo chão.
static func desenhar(ci: CanvasItem, it: Dictionary, p: Vector2) -> void:
	var t := tex()
	if t == null:
		return
	var id := str(it.a.id)
	var esc := escala(id)
	var lado := -1.0 if float(it.r) < 0.0 else 1.0
	var k := 1.0
	if int(it.e) == SURGINDO:
		k = clampf(float(it.et) / SURGIR_T, 0.0, 1.0)
	elif float(it.vida) < SUMIR_T:
		k = clampf(float(it.vida) / SUMIR_T, 0.0, 1.0)
	ci.draw_set_transform(p, 0.0, Vector2(esc, esc * ACHATA))
	ci.draw_circle(Vector2.ZERO, 22.0 * (0.4 + 0.6 * k), Color(0.0, 0.0, 0.0, 0.3 * k))
	var q := quadro_de(it)
	var hv := QUADRO.y
	var topo := -PE.y
	if k < 1.0:
		var ease := 1.0 - (1.0 - k) * (1.0 - k)
		var fundo := (QUADRO.y - PE.y) * pow(ease, 3.0)  # quanto da fatia passa da linha do chão (só no fim, para o pé aparecer inteiro)
		hv = ease * PE.y + fundo
		topo = fundo - hv
	ci.draw_set_transform(p, 0.0, Vector2(lado * esc, esc))
	var origem := Vector2(q.x * QUADRO.x, q.y * QUADRO.y)
	var cor := Color(0.8, 0.82, 0.95) if id == COLOSSO else Color.WHITE
	ci.draw_texture_rect_region(t, Rect2(Vector2(-PE.x, topo), Vector2(QUADRO.x, hv)), Rect2(origem, Vector2(QUADRO.x, hv)), cor)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Camada aditiva (`no_brilho`): o brasa do peito, o aviso no chão de onde a pancada vai cair e o clarão depois dela.
static func desenhar_brilho(ci: CanvasItem, it: Dictionary, p: Vector2, glow: Texture2D) -> void:
	var esc := escala(str(it.a.id))
	if float(it.vida) < SUMIR_T or int(it.e) == SURGINDO:
		return
	if int(it.lin) < 3:  # de costas o peito não aparece
		var pulso := 0.5 + 0.5 * sin(float(it.fase) * 0.7)
		var c := p + Vector2(0, -30.0 * esc)
		ci.draw_texture_rect(glow, Rect2(c - Vector2(15, 12) * esc, Vector2(30, 24) * esc), false, Color(1.0, 0.55, 0.2, 0.08 + 0.07 * pulso))
	if int(it.e) != ATACANDO:
		return
	var et := float(it.et)
	var ti := tempo_impacto()
	var ip: Vector2 = (it.ip as Vector2).round()
	var raio := RAIO_IMPACTO * esc
	ci.draw_set_transform(ip, 0.0, Vector2(1, ACHATA))
	if et < ti:  # a pancada vai cair aqui: o aro fecha e acende
		var k := clampf(et / ti, 0.0, 1.0)
		ci.draw_arc(Vector2.ZERO, raio * (1.25 - 0.25 * k), 0.0, TAU, 40, Color(1.0, 0.55, 0.25, 0.12 + 0.45 * k), 1.0 + 1.5 * k)
		ci.draw_circle(Vector2.ZERO, raio * 0.8, Color(1.0, 0.5, 0.2, 0.06 * k))
	elif et < ti + 0.14:  # clarão do impacto
		var f := 1.0 - (et - ti) / 0.14
		ci.draw_circle(Vector2.ZERO, raio * (1.0 - 0.3 * f), Color(1.0, 0.75, 0.4, 0.35 * f))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
