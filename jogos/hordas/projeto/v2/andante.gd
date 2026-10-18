extends RefCounted
## Invocações que andam de verdade (aliados com folha 3D de 5 vistas, andar e ataque), no padrão do Golem (v2/golem.gd), mas sem o entulho dele:
## cada bicho é só uma FICHA aqui (folha, quadro, pé, passada por vista, tempos do ataque, alcance e golpe) e o resto é igual para todos.
## O pool é o de `v2/armas_novas.gd`; este arquivo só tem funções estáticas sobre o item do pool.
##
## A folha (fonte_arte/blender_<bicho>/gerar_<bicho>.py) tem 16 colunas x 5 linhas: colunas 0-7 = ciclo de andar (2 pisadas, quadros 2 e 6;
## o 2 também é o "parado"), 8-15 = ataque (o quadro `impacto` é o do golpe); linhas = frente, 3/4 frente, perfil, 3/4 costas, costas, pela
## direção do movimento, com histerese. A folha olha para a direita e a esquerda é o espelho. Os números da ficha são os do .json que o gerador grava
## ao lado da folha (o .json não vai na exportação; o teste v2_andante confere que o código e o .json batem).
##
## Estado no item: an = é andante, e = ANDANDO / ATACANDO / SURGINDO, et = tempo no estado, lin = vista, pf = fase do passo (anda com a
## distância ANDADA: parado não muda e o pé não escorrega), mov = andou neste quadro, imp = o golpe deste ataque já caiu, ip = onde ele cai.
## O dano cai quando a animação cruza o quadro do impacto, em área pequena à frente (`ip`, guardado no começo do golpe).
const Golem := preload("res://v2/golem.gd")

const LINHAS := 5
const COL_ANDAR := 8
const COL_ATAQUE := 8
const PARADO := 2
const RESPIRO_MIN := 0.08
const SURGIR_T := 0.45  # nasce de uma névoa (aparece de baixo para cima e acende)
const SUMIR_T := 0.5  # some nos últimos instantes (apaga e solta a névoa)
const DUR_RASTRO := 0.22  # s que o rastro do golpe fica no ar (garras, arco, fogo, pancada, névoa ou bote)
const ACHATA := 0.62
const ANDANDO := 0
const ATACANDO := 1
const SURGINDO := 2

## Uma ficha por carta. folha = png da folha; quadro e pe = do .json; ciclo = px andados por ciclo de andar, por vista (`ciclo_linha` do .json:
## é o que o pé de apoio corre na tela, então o corpo anda isso e o pé não escorrega); tempos = s de cada quadro do ataque; impacto = índice do golpe;
## alcance = distância (plano achatado) do alvo em que ele para e ataca; frente = a que distância à frente o golpe cai; raio = raio do golpe;
## empurra, atordoa = do golpe por alvo; sombra = raio da sombra; cor_fx = cor do espírito (névoa, rastro do golpe, brilho).
## Opcionais, para quem não anda com pernas: ciclo_s = s por ciclo do "andar" contado no RELÓGIO (asa batendo, corpo ondulando, véu do fantasma),
## que roda também parado (sem ele o ciclo anda com a distância e parado mostra o quadro `PARADO`); altura = px acima do chão em que ele flutua ou voa
## (a sombra fica no chão e o corpo balança `balanco` px para cima e para baixo); rastro = o desenho do golpe no impacto: garras (padrão), arco
## (corte de espada), fogo (sopro em leque), pancada (anel e lascas no chão), nevoa (fiapos que sobem) ou bote (estalo e fagulhas).
const FICHAS := {
	"espirito_urso":
	{
		"folha": "res://assets/v2/armas/urso_espiritual_dir.png",
		"quadro": Vector2(72, 80),
		"pe": Vector2(32, 54),
		"ciclo": [32.0, 38.0, 44.0, 37.7, 30.0],
		# agacha, levanta o peito, de pé, pico (boca aberta), PATADA, patas no chão, levanta, volta: 0,72 s, cabe no tique de 0,8 s da carta
		"tempos": [0.08, 0.08, 0.08, 0.12, 0.06, 0.12, 0.09, 0.09],
		"impacto": 4,
		# a pata, no quadro da patada, cai 33 px à frente do centro do corpo (medido no modelo: `alcance_pata_px` do .json)
		"alcance": 30.0,
		"frente": 24.0,
		"raio": 26.0,
		"empurra": 70.0,
		"atordoa": 0.12,
		"sombra": 17.0,
		"cor_fx": Color(0.62, 1.0, 0.72),
		"rastro": "garras",
	},
	"esqueleto_guerreiro":
	{
		"folha": "res://assets/v2/armas/esqueleto_guerreiro_dir.png",
		"quadro": Vector2(75, 85),
		"pe": Vector2(37, 66),
		"ciclo": [30.0, 36.1, 42.0, 35.8, 30.0],
		# prepara, a espada sobe, sobe, pico atrás da cabeça, CORTE, a espada embaixo, recolhe, volta: 0,52 s, cabe no tique de 0,6 s da carta
		"tempos": [0.06, 0.06, 0.06, 0.07, 0.05, 0.09, 0.06, 0.07],
		"impacto": 4,
		# a ponta da espada, no quadro do corte, chega a 35 px à frente do centro do corpo (`alcance_pata_px` do .json); o arco cai no meio da lâmina
		"alcance": 28.0,
		"frente": 25.0,
		"raio": 19.0,
		"empurra": 40.0,
		"atordoa": 0.08,
		"sombra": 10.0,
		"cor_fx": Color(0.95, 0.93, 0.85),
		"rastro": "arco",
	},
	"espirito_raposa":
	{
		"folha": "res://assets/v2/armas/raposa_espiritual_dir.png",
		"quadro": Vector2(69, 70),
		"pe": Vector2(32, 44),
		"ciclo": [26.1, 32.8, 40.0, 34.4, 26.1],
		# agacha, se encolhe, salta, pico do salto, BOTE (patas no chão), pousa, levanta, volta: 0,42 s, cabe no tique de 0,5 s da carta
		"tempos": [0.06, 0.06, 0.05, 0.04, 0.04, 0.07, 0.05, 0.05],
		"impacto": 4,
		# o corpo vai à frente dentro do quadro (o bote está na folha): a pata da frente, no impacto, chega a 35 px à frente do centro (`alcance_pata_px` do .json)
		"alcance": 30.0,
		"frente": 27.0,
		"raio": 18.0,
		"empurra": 30.0,
		"atordoa": 0.05,
		"sombra": 9.0,
		"cor_fx": Color(1.0, 0.72, 0.3),
		"rastro": "garras",
	},
	"fantasma_mata":
	{
		"folha": "res://assets/v2/armas/fantasma_mata_dir.png",
		"quadro": Vector2(82, 80),
		"pe": Vector2(30, 63),
		# flutua: o véu ondula no relógio (ciclo_s), sem pé no chão (por isso não tem `ciclo`)
		"ciclo_s": 0.8,
		"altura": 9.0,
		"balanco": 2.0,
		# recua, abre os braços, pico, começa o bote, BOTE (capuz e garras à frente), segura, volta, assenta: 0,30 s, cabe no tique de 0,4 s da carta
		"tempos": [0.05, 0.04, 0.04, 0.04, 0.05, 0.04, 0.02, 0.02],
		"impacto": 4,
		# o capuz e as garras, no quadro do bote, chegam 49,8 px à frente do centro (`alcance_pata_px` do .json)
		"alcance": 42.0,
		"frente": 38.0,
		"raio": 24.0,
		"empurra": 40.0,
		"atordoa": 0.1,
		"sombra": 13.0,
		"cor_fx": Color(0.55, 1.0, 0.65),
		"rastro": "nevoa",
	},
	"serpente_ardente":
	{
		"folha": "res://assets/v2/armas/serpente_ardente_dir.png",
		"quadro": Vector2(85, 86),
		"pe": Vector2(27, 50),
		# rasteja: a onda do corpo roda no relógio (ciclo_s) e fica no chão (sem `altura`); parada ela continua ondulando
		"ciclo_s": 0.5,
		# se enrosca, ergue o pescoço, arma o bote, dispara, BOTE (cabeça à frente de boca aberta), estala, recolhe, assenta: 0,42 s, cabe no tique de 0,5 s
		"tempos": [0.07, 0.07, 0.06, 0.05, 0.06, 0.05, 0.03, 0.03],
		"impacto": 4,
		# a ponta da cabeça, no quadro do bote, chega 57,9 px à frente do centro (`alcance_pata_px` do .json)
		"alcance": 50.0,
		"frente": 46.0,
		"raio": 22.0,
		"empurra": 30.0,
		"atordoa": 0.08,
		"sombra": 16.0,
		"cor_fx": Color(1.0, 0.55, 0.15),
		"rastro": "bote",
	},
	"guardiao_pedra":
	{
		"folha": "res://assets/v2/armas/guardiao_pedra_dir.png",
		"quadro": Vector2(77, 93),
		"pe": Vector2(35, 72),
		"ciclo": [32.0, 39.7, 46.0, 38.6, 32.0],
		# antecipa, braços sobem, quase no alto, pico (punhos acima da cabeça), PANCADA, punhos no chão, começa a se erguer, volta: 0,98 s, cabe no tique de 1,2 s
		"tempos": [0.1, 0.1, 0.1, 0.14, 0.08, 0.18, 0.14, 0.14],
		"impacto": 4,
		# os punhos, no quadro da pancada, ficam 18 px à frente do centro do corpo (`alcance_pata_px` do .json); a área de 26 px de raio cobre em volta
		"alcance": 26.0,
		"frente": 16.0,
		"raio": 26.0,
		"empurra": 55.0,
		"atordoa": 0.25,
		"sombra": 21.0,
		"cor_fx": Color(0.78, 0.76, 0.68),
		"rastro": "pancada",
	},
	"dragao_filhote":
	{
		"folha": "res://assets/v2/armas/dragao_filhote_dir.png",
		"quadro": Vector2(47, 48),
		"pe": Vector2(23, 25),
		"ciclo": [0.0, 0.0, 0.0, 0.0, 0.0],  # voa: o ciclo é o bater de asas no relógio (ciclo_s), sem passada no chão
		"ciclo_s": 0.5,
		"altura": 20.0,
		"balanco": 3.0,
		# recua a cabeça, enche o peito, boca abrindo, pico, SOPRO, sopro acabando, fecha a boca, volta: 0,46 s, cabe no tique de 0,6 s
		"tempos": [0.05, 0.05, 0.05, 0.07, 0.05, 0.07, 0.06, 0.06],
		"impacto": 4,
		# no quadro do sopro a ponta do focinho fica 12 px à frente do centro do corpo e o leque de fogo passa dela 14 px (`alcance_pata_px` do .json = 26)
		"alcance": 22.0,
		"frente": 18.0,
		"raio": 16.0,
		"empurra": 30.0,
		"atordoa": 0.05,
		"sombra": 11.0,
		"cor_fx": Color(1.0, 0.55, 0.15),
		"rastro": "fogo",
	},
}

static var _tex := {}


static func eh_andante(id: String) -> bool:
	return FICHAS.has(id)


static func ficha(id: String) -> Dictionary:
	return FICHAS.get(id, {})


## A folha do bicho (carrega uma vez; null se faltar o arquivo, e o aliado volta ao desenho antigo).
static func tex(id: String) -> Texture2D:
	if not FICHAS.has(id):
		return null
	if not _tex.has(id):
		_tex[id] = load(str(FICHAS[id].folha)) as Texture2D
	return _tex[id]


static func linha_de(v: Vector2, atual: int) -> int:
	return Golem.linha_de(v, atual)


static func tempo_ataque(f: Dictionary) -> float:
	var s := 0.0
	for d in f.tempos:
		s += float(d)
	return s


static func tempo_impacto(f: Dictionary) -> float:
	var s := 0.0
	for i in int(f.impacto):
		s += float(f.tempos[i])
	return s


static func quadro_ataque(f: Dictionary, t: float) -> int:
	var s := 0.0
	for i in f.tempos.size():
		s += float(f.tempos[i])
		if t < s:
			return i
	return f.tempos.size() - 1


static func quadro_andar(pf: float) -> int:
	return clampi(floori(fposmod(pf, 1.0) * COL_ANDAR), 0, COL_ANDAR - 1)


## O "tique" da carta é o ciclo inteiro do golpe; nunca menos que `RESPIRO_MIN` de pausa.
static func respiro(it: Dictionary, f: Dictionary) -> float:
	return maxf(RESPIRO_MIN, float(it.a.st.tique) - tempo_ataque(f))


## Chaves do item do pool (um slot reaproveitado nunca herda o estado de outro bicho). As de estado são as mesmas do golem (Golem.zerar).
static func zerar(it: Dictionary) -> void:
	it.an = false


static func nascer(nv, it: Dictionary) -> void:
	var f := ficha(str(it.a.id))
	it.an = true
	it.e = SURGINDO
	it.et = 0.0
	it.lin = 0
	it.pf = 0.0
	it.v = Vector2(0, 1)
	it.sumiu = false
	nv.pai.fx.onda(it.p, Color(f.cor_fx, 0.55), 26.0, 0.4)


# ------------------------------------------------------------------ movimento e ataque


static func mover(nv, it: Dictionary, h, dt: float, perto: Array) -> void:
	var f := ficha(str(it.a.id))
	it.et = float(it.et) + dt
	if f.has("ciclo_s") and int(it.e) != ATACANDO:
		it.pf = float(it.pf) + dt / float(f.ciclo_s)
	it.t = float(it.t) - dt  # a recarga do golpe (o armas_novas não conta o tempo do aliado)
	it.mov = false
	if float(it.vida) <= SUMIR_T:
		if not bool(it.sumiu):
			it.sumiu = true
			it.e = ANDANDO
			nv.pai.fx.onda(it.p, Color(f.cor_fx, 0.45), 30.0, 0.45)
		return
	match int(it.e):
		SURGINDO:
			if float(it.et) >= SURGIR_T:
				it.e = ANDANDO
				it.et = 0.0
		ATACANDO:
			_atacar(nv, it, f)
		_:
			_andar(nv, it, f, h, dt, perto)


static func _andar(nv, it: Dictionary, f: Dictionary, h, dt: float, perto: Array) -> void:
	var st: Dictionary = it.a.st
	var alvo = nv._mais_perto(it.p, 400.0, perto)
	var dest: Vector2
	if alvo != null:
		dest = alvo.pos
	else:
		dest = h.pos + Vector2.from_angle(float(it.fase)) * 50.0  # sem inimigo, anda em volta do herói
	var d: Vector2 = dest - it.p
	if absf(d.x) > 2.0:
		it.r = signf(d.x)
	if alvo != null and nv._eli(d).length() <= float(f.alcance) + float(alvo.raio):
		if d.length() > 1.0:  # em alcance: para, vira para o alvo e ataca quando a recarga deixa
			it.v = (it.v as Vector2).lerp(d.normalized(), clampf(dt * 12.0, 0.0, 1.0))
			it.lin = linha_de(it.v, int(it.lin))
		if float(it.t) <= 0.0:
			var dir := d.normalized()
			it.e = ATACANDO
			it.et = 0.0
			it.imp = false
			it.v = dir  # a vista fica travada durante o golpe
			it.lin = linha_de(dir, int(it.lin))
			it.ip = (it.p as Vector2) + dir * float(f.frente)
		return
	if d.length() > 1.0:
		var dir := d.normalized()
		var passo := minf(float(st.vel) * dt, d.length())
		it.p = it.p + dir * passo
		it.v = (it.v as Vector2).lerp(dir, clampf(dt * 10.0, 0.0, 1.0))  # suavizado: o quadro não pisca na virada
		it.lin = linha_de(it.v, int(it.lin))
		if not f.has("ciclo_s"):
			it.pf = float(it.pf) + passo / float(f.ciclo[int(it.lin)])
		it.mov = true


static func _atacar(nv, it: Dictionary, f: Dictionary) -> void:
	var et := float(it.et)
	if not bool(it.imp) and et >= tempo_impacto(f):
		it.imp = true
		_impacto(nv, it, f)
	if et >= tempo_ataque(f):
		it.e = ANDANDO
		it.et = 0.0
		it.t = respiro(it, f)


static func _impacto(nv, it: Dictionary, f: Dictionary) -> void:
	var pai = nv.pai
	var a: Dictionary = it.a
	var p: Vector2 = it.ip
	var raio := float(f.raio)
	pai._dano_area(p, raio, nv._dano(a.st), float(f.empurra), float(f.atordoa), a.cor, "aliado")
	pai.fx.onda(p, Color(f.cor_fx, 0.7), raio, 0.22)
	pai.fx.faiscas(p, it.v, 6, f.cor_fx, 130.0)
	pai.fx.luz_rapida(p + Vector2(0, -6), f.cor_fx, 1.4, raio * 2.2, 0.2)
	pai.combate.audio.tocar("impacto", randf_range(0.8, 0.95), -3.0, 0.1)
	if (pai.mundo.heroi.pos as Vector2).distance_to(p) < 300.0:
		pai.mundo.cam.tremer(0.8, 0.1)


# ------------------------------------------------------------------ desenho


## Coluna e linha da folha agora (o teste usa para conferir o ciclo andar -> atacar).
static func quadro_de(it: Dictionary) -> Vector2i:
	var col: int
	var f := ficha(str(it.a.id))
	if int(it.e) == ATACANDO:
		col = COL_ANDAR + quadro_ataque(f, float(it.et))
	elif bool(it.mov) or f.has("ciclo_s"):
		col = quadro_andar(float(it.pf))
	else:
		col = PARADO
	return Vector2i(col, int(it.lin))


## Quantos px acima do chão o corpo está agora (quem flutua ou voa balança devagar; quem anda fica no chão).
static func altura(it: Dictionary, f: Dictionary) -> float:
	if not f.has("altura"):
		return 0.0
	return roundf(float(f.altura) + sin(float(it.fase) * 1.3) * float(f.get("balanco", 2.0)))


## Quanto do bicho está "aceso" (0 a 1): sobe da névoa ao nascer e apaga no fim da vida.
static func presenca(it: Dictionary) -> float:
	if int(it.e) == SURGINDO:
		return clampf(float(it.et) / SURGIR_T, 0.0, 1.0)
	return clampf(float(it.vida) / SUMIR_T, 0.0, 1.0)


## Camada normal (a que recebe a luz): sombra e o quadro certo da folha, espelhado para olhar para onde vai. Surgindo, aparece de baixo
## para cima (a fatia de cima ainda é névoa); no fim, fica transparente.
static func desenhar(ci: CanvasItem, it: Dictionary, p: Vector2) -> void:
	var id := str(it.a.id)
	var t := tex(id)
	if t == null:
		return
	var f := ficha(id)
	var quadro: Vector2 = f.quadro
	var pe: Vector2 = f.pe
	var k := presenca(it)
	var lado := -1.0 if float(it.r) < 0.0 else 1.0
	ci.draw_set_transform(p, 0.0, Vector2(1.0, ACHATA))
	ci.draw_circle(Vector2.ZERO, float(f.sombra) * (0.5 + 0.5 * k), Color(0.0, 0.0, 0.0, 0.3 * k))
	ci.draw_set_transform(p - Vector2(0.0, altura(it, f)), 0.0, Vector2(lado, 1.0))
	var q := quadro_de(it)
	var origem := Vector2(q.x * quadro.x, q.y * quadro.y)
	var corte := 0.0
	var alfa := k
	if int(it.e) == SURGINDO:
		var ease := 1.0 - (1.0 - k) * (1.0 - k)
		corte = (1.0 - ease) * quadro.y  # o topo ainda não apareceu
		alfa = 0.35 + 0.65 * k
	var r_tela := Rect2(Vector2(-pe.x, -pe.y + corte), Vector2(quadro.x, quadro.y - corte))
	var r_folha := Rect2(origem + Vector2(0, corte), Vector2(quadro.x, quadro.y - corte))
	ci.draw_texture_rect_region(t, r_tela, r_folha, Color(1, 1, 1, alfa))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Camada aditiva: o halo do espírito, a névoa de nascer e sumir, e o rastro das garras no golpe.
static func desenhar_brilho(ci: CanvasItem, it: Dictionary, p: Vector2, glow: Texture2D) -> void:
	var f := ficha(str(it.a.id))
	var cor: Color = f.cor_fx
	var k := presenca(it)
	var alto := float(f.quadro.y) * 0.35 + altura(it, f)
	var pulso := 0.5 + 0.5 * sin(float(it.fase) * 0.9)
	var halo := float(f.sombra) * 2.4
	ci.draw_texture_rect(glow, Rect2(p + Vector2(-halo, -alto - halo * 0.7), Vector2(halo * 2.0, halo * 1.4)), false, Color(cor, (0.07 + 0.04 * pulso) * k))
	if k < 1.0:  # névoa: um bafo claro no chão enquanto nasce ou some
		var n := 1.0 - k
		ci.draw_set_transform(p, 0.0, Vector2(1.0, ACHATA))
		ci.draw_circle(Vector2.ZERO, float(f.sombra) * (1.0 + 0.6 * n), Color(cor, 0.22 * n))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if int(it.e) != ATACANDO:
		return
	var et := float(it.et)
	var ti := tempo_impacto(f)
	if et < ti or et > ti + DUR_RASTRO:
		return
	var g := (et - ti) / DUR_RASTRO  # 0 = o golpe acabou de cair, 1 = o rastro sumiu
	var ip: Vector2 = (it.ip as Vector2).round()
	var dir: Vector2 = it.v
	var corpo: Vector2 = p - Vector2(0.0, altura(it, f) + float(f.quadro.y) * 0.2)
	match str(f.get("rastro", "garras")):
		"arco":
			_rastro_arco(ci, corpo, dir, float(f.frente) + 4.0, cor, g)
		"fogo":
			_rastro_fogo(ci, corpo, ip, dir, float(f.raio), g)
		"pancada":
			_rastro_pancada(ci, ip, float(f.raio), cor, g)
		"nevoa":
			_rastro_nevoa(ci, ip, float(f.raio), cor, g, float(it.fase))
		"bote":
			_rastro_bote(ci, ip, dir, float(f.raio), cor, g)
		_:
			_rastro_garras(ci, ip, dir, float(f.raio), cor, g)


## Três garras: riscos curvos que cruzam o ponto do golpe, de cima para baixo (urso, raposa).
static func _rastro_garras(ci: CanvasItem, ip: Vector2, dir: Vector2, raio: float, cor: Color, g: float) -> void:
	var perp := Vector2(-dir.y, dir.x)
	for r in 3:
		var o := perp * (r - 1) * 7.0
		var pts := PackedVector2Array()
		for s in 6:
			var u := float(s) / 5.0 - 0.5
			pts.append(ip + o + Vector2(0, -12.0) + dir * u * raio * 1.2 + Vector2(0, u * 18.0) - perp * absf(u) * 4.0)
		ci.draw_polyline(pts, Color(cor, 0.9 * (1.0 - g)), 2.0 * (1.0 - g) + 1.0)


## Corte de espada: um arco em volta do corpo, na direção do golpe, que afina e apaga (esqueleto).
static func _rastro_arco(ci: CanvasItem, corpo: Vector2, dir: Vector2, raio: float, cor: Color, g: float) -> void:
	var a := dir.angle()
	var abre := 1.1 + 0.4 * g
	ci.draw_set_transform(corpo, 0.0, Vector2(1.0, 0.8))
	ci.draw_arc(Vector2.ZERO, raio, a - abre, a + abre, 18, Color(cor, 0.85 * (1.0 - g)), 3.0 * (1.0 - g) + 1.0)
	ci.draw_arc(Vector2.ZERO, raio - 4.0, a - abre * 0.8, a + abre * 0.8, 14, Color(1, 1, 1, 0.6 * (1.0 - g)), 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Sopro de fogo em leque: bolas de fogo que saem da boca e se abrem, de amarelo a vermelho (dragão).
static func _rastro_fogo(ci: CanvasItem, corpo: Vector2, ip: Vector2, dir: Vector2, raio: float, g: float) -> void:
	var boca := corpo + dir * 6.0
	var longe := (ip - boca).length() + raio
	for k in 7:
		var ang := dir.angle() + (k - 3) * 0.16
		var d := longe * (0.35 + 0.65 * g) * (0.75 + 0.25 * absf(sin(k * 1.7)))
		var c := Color(1.0, 0.9, 0.4).lerp(Color(1.0, 0.25, 0.05), g)
		c.a = 0.75 * (1.0 - g)
		ci.draw_circle(boca + Vector2.from_angle(ang) * d, 3.0 + 4.0 * g, c)
	ci.draw_circle(boca, 4.0 * (1.0 - g), Color(1.0, 0.95, 0.6, 0.8 * (1.0 - g)))


## Pancada no chão: anel achatado que abre e lascas de pedra que pulam e caem (guardião).
static func _rastro_pancada(ci: CanvasItem, ip: Vector2, raio: float, cor: Color, g: float) -> void:
	ci.draw_set_transform(ip, 0.0, Vector2(1.0, ACHATA))
	ci.draw_arc(Vector2.ZERO, raio * (0.5 + 0.7 * g), 0.0, TAU, 32, Color(cor, 0.7 * (1.0 - g)), 2.0 * (1.0 - g) + 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 6:
		var d := Vector2.from_angle(k * TAU / 6.0 + 0.4) * raio * 0.9 * g
		var pos := ip + Vector2(d.x, d.y * ACHATA) - Vector2(0, sin(g * PI) * 10.0)
		ci.draw_rect(Rect2(pos.round(), Vector2(2, 2)), Color(cor, 0.8 * (1.0 - g)))


## Névoa que assombra: fiapos redondos que sobem e se espalham do ponto do golpe (fantasma).
static func _rastro_nevoa(ci: CanvasItem, ip: Vector2, raio: float, cor: Color, g: float, fase: float) -> void:
	for k in 5:
		var ang := fase + k * TAU / 5.0
		var pos := ip + Vector2(cos(ang), sin(ang) * ACHATA) * raio * 0.7 * g - Vector2(0, 8.0 + 10.0 * g)
		ci.draw_circle(pos, 3.0 + 5.0 * g, Color(cor, 0.45 * (1.0 - g)))


## Bote: um estalo de brasa onde a boca fecha e fagulhas em leque para a frente (serpente).
static func _rastro_bote(ci: CanvasItem, ip: Vector2, dir: Vector2, raio: float, cor: Color, g: float) -> void:
	var c := ip - Vector2(0, 6.0)
	ci.draw_circle(c, raio * 0.45 * (1.0 - g), Color(1.0, 0.9, 0.5, 0.7 * (1.0 - g)))
	for k in 6:
		var ang := dir.angle() + (k - 2.5) * 0.35
		var a := c + Vector2.from_angle(ang) * raio * 0.3 * g
		var b := c + Vector2.from_angle(ang) * raio * (0.4 + 0.6 * g)
		ci.draw_line(a, b, Color(cor, 0.85 * (1.0 - g)), 1.0)
