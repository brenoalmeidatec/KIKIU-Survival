extends RefCounted
## A APARÊNCIA própria de cada chefe da v2 (v2/chefe.gd), feita em código sobre o sprite 2D do monstro: nada de arte nova nem de 3D.
## O `adorno` de cada marca (dados/v2_cartas.json > chefes > marcas > visual) escolhe o conjunto:
##   elmo  = Devourer of Flesh: capa rubra atrás do corpo, pluma e ombreiras de espinho no elmo, anel de runas vermelho no chão e brasas que sobem;
##   teia  = Devourer of Structure: teia grande no chão sob ela, coroa flutuando sobre o abdômen e esporos verdes que sobem;
##   coroa = Devourer of Land (o chefão): manto rasgado, coroa de ouro com gemas, sigilo de estrela no chão, quatro corvos girando em volta
##           (passam por trás e pela frente do corpo) e brasas e penas; na fúria a coroa brilha e os corvos giram mais rápido.
## Dois nós filhos do corpo do chefe (`atras`, desenhado antes do sprite, e `frente`, depois) e um nó do mundo (`no_voo`) com os corvos da REVOADA,
## o ataque próprio do Rei (chefe.gd chama `revoada` no disparo das faixas). Tudo é desenhado sem luz 2D (o chefe já tem a luz própria dele) e
## aparece aos poucos na entrada (ENTRADA_S). As POSIÇÕES são em "pixels do sprite" (multiplicadas pela escala do chefe, como o próprio sprite), mas o
## DETALHE é sempre de 1 px do mundo (pixel de um tamanho só, regra de 03/11): contorno de 1 px, dobras e brilhos de 1 px, a coroa e as gemas numa
## folha pequena desenhada já no tamanho final (assets/v2/chefes/coroa_*.png, gerada por fonte_arte/chefes_v2/gerar_coroas.py) e os corvos em escala 1.
## Nada gira por ângulo livre nem cresce por fator quebrado; o que era círculo vira elipse em degraus de 1 px (`_disco_px`).

const Anim := preload("res://v2/anim_golpes.gd")  # a folha dos corvos (assets/v2/armas_anim, a mesma do golpe de corvos do herói)
const PixelRot := preload("res://v2/pixel_rot.gd")  # a revoada só gira em passos de 90 graus
const COROA_REI: Texture2D = preload("res://assets/v2/chefes/coroa_rei.png")  # 57x45, já no tamanho final (1 px de arte = 1 px do mundo)
const COROA_RAINHA: Texture2D = preload("res://assets/v2/chefes/coroa_rainha.png")  # 37x28
## Onde ficam as gemas nas duas folhas (px da folha, canto de cima à esquerda): o brilho de 1 px que pisca em uma delas por vez.
const GEMAS_REI := [Vector2(6, 8), Vector2(17, 17), Vector2(28, 8), Vector2(39, 17), Vector2(50, 8)]
const GEMAS_RAINHA := [Vector2(4, 7), Vector2(11, 12), Vector2(18, 7), Vector2(25, 12), Vector2(32, 7)]
const ACHATA := 0.62  # o chão é uma elipse (igual a v2/avisos.gd)
const ENTRADA_S := 0.9  # s para o adorno aparecer por inteiro quando o chefe nasce
const VOO_S := 0.15  # s que a revoada leva para varrer a faixa: o dano sai no disparo, então os corvos têm de passar junto com ele
const CORVOS_POR_FAIXA := 6
const CORVOS_ORBITA := 4

var combate
var mundo
var chefe  # o controlador (v2/chefe.gd)
var m = null  # o monstro em campo
var adorno := ""  # elmo, teia ou coroa ("" = sem adorno)
var cor := Color.WHITE  # a cor da marca (a mesma da luz e do contorno)
var cor2 := Color.WHITE  # a cor secundária (capa, ouro, fios)
var luz_mult := 1.0  # quanto a luz do chefe é mais forte (o chefão brilha mais)
var atras: Node2D
var frente: Node2D
var no_voo: Node2D
var t := 0.0
var voos: Array = []  # os corvos da revoada em voo (testes)
var _brasa_t := 0.0
var _cab_tipo = null  # a folha (dados do sprite) de que saíram as medidas da cabeça
var _cab: Array = []  # [linha][coluna] -> Vector2(x do ápice, y do topo) em px da folha, contado do canto do quadro


func montar(ctrl, c) -> void:
	chefe = ctrl
	combate = c
	mundo = c.mundo
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	atras = Node2D.new()
	atras.material = mat
	atras.draw.connect(_desenhar_atras)
	frente = Node2D.new()
	frente.material = mat
	frente.draw.connect(_desenhar_frente)
	no_voo = Node2D.new()
	no_voo.material = mat
	no_voo.draw.connect(_desenhar_voos)
	mundo.glow.add_child(no_voo)


## Veste o monstro `mon` com o adorno da marca `mk`.
func ligar(mon, mk: Dictionary) -> void:
	m = mon
	var v: Dictionary = mk.get("visual", {})
	adorno = str(v.get("adorno", ""))
	cor = Color(mk.cor[0], mk.cor[1], mk.cor[2])
	var c2: Array = v.get("cor2", mk.cor)
	cor2 = Color(c2[0], c2[1], c2[2])
	luz_mult = float(v.get("luz", 1.0))
	t = 0.0
	_brasa_t = 0.0
	if adorno == "":
		return
	for n in [atras, frente]:
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
	m.raiz.add_child(atras)
	m.raiz.move_child(atras, 0)  # antes do sprite: fica atrás do corpo
	m.raiz.add_child(frente)
	atras.visible = true
	frente.visible = true


func desligar() -> void:
	m = null
	adorno = ""
	voos.clear()
	atras.visible = false
	frente.visible = false
	no_voo.queue_redraw()


## Sai da partida: libera os nós (os que nunca entraram na árvore são órfãos e não se liberam sozinhos) e desfaz as referências cruzadas.
func liberar() -> void:
	for n in [atras, frente, no_voo]:
		if is_instance_valid(n):
			if n.get_parent() == null:
				n.free()
			else:
				n.queue_free()
	atras = null
	frente = null
	no_voo = null
	m = null
	chefe = null
	combate = null
	mundo = null
	voos.clear()


func atualizar(dt: float) -> void:
	t += dt
	if m != null and m.vivo and adorno != "":
		atras.queue_redraw()
		frente.queue_redraw()
		_brasas(dt)
	if not voos.is_empty():
		var i := voos.size() - 1
		while i >= 0:
			voos[i].t += dt
			if float(voos[i].t) >= VOO_S:
				voos.remove_at(i)
			i -= 1
		no_voo.queue_redraw()


## A revoada do Rei: os corvos varrem a faixa que parte de `origem` na direção `g` (no chão, normalizada) por `compr` px de chão. Só efeito: o
## dano é da faixa (v2/avisos.gd).
func revoada(origem: Vector2, g: Vector2, compr: float, larg: float) -> void:
	var perp := Vector2(-g.y, g.x)
	for k in CORVOS_POR_FAIXA:
		(
			voos
			. append(
				{
					"o": origem,
					"g": g,
					"p": perp,
					"c": compr,
					"off": randf_range(-0.4, 0.4) * larg,
					"z": randf_range(8.0, 22.0),
					"t": -randf() * 0.05,
					"ph": randf() * 10.0,
				}
			)
		)
	no_voo.queue_redraw()


func _fade() -> float:
	return clampf(t / ENTRADA_S, 0.0, 1.0)


func _viva() -> bool:
	return m != null and m.vivo and m.chefe


# ------------------------------------------------------------------ partículas


func _brasas(dt: float) -> void:
	_brasa_t -= dt
	if _brasa_t > 0.0 or t < 0.3:
		return
	var fx = combate.fx
	var u := float(m.escala)
	var alt := float(m.alt)
	var x := randf_range(-13.0, 13.0) * u
	var y := -randf_range(0.05, 0.9) * alt
	match adorno:
		"elmo":
			_brasa_t = 0.07
			fx.particula(
				m.pos + Vector2(x, y), Vector2(randf_range(-6, 6), -randf_range(16, 34)), randf_range(0.6, 1.1), 3.0, Color(1.0, 0.35, 0.15, 0.9), -10.0, true
			)
		"teia":
			_brasa_t = 0.09
			fx.particula(
				m.pos + Vector2(x * 1.4, y * 0.6),
				Vector2(randf_range(-5, 5), -randf_range(8, 20)),
				randf_range(0.9, 1.5),
				3.0,
				Color(0.6, 1.0, 0.45, 0.8),
				-4.0,
				true
			)
		"coroa":
			_brasa_t = 0.06
			fx.particula(
				m.pos + Vector2(x * 1.3, y),
				Vector2(randf_range(-8, 8), -randf_range(14, 30)),
				randf_range(0.7, 1.3),
				3.0,
				Color(1.0, 0.3, 0.75, 0.9),
				-8.0,
				true
			)
			if randf() < 0.35:  # uma pena escura cai
				fx.particula(
					m.pos + Vector2(x * 1.6, y * 0.8),
					Vector2(randf_range(-14, 14), randf_range(-6, 4)),
					randf_range(0.9, 1.4),
					3.0,
					Color(0.16, 0.08, 0.22, 0.95),
					40.0
				)


# ------------------------------------------------------------------ o que fica atrás do corpo


func _desenhar_atras() -> void:
	if not _viva():
		return
	var u := float(m.escala)
	var a := _fade()
	match adorno:
		"elmo":
			_anel_runas(atras, u, 24.0, cor, a, 8, 0.6)
			_capa(atras, u, a)
		"teia":
			_teia_chao(atras, u, 38.0, a)
		"coroa":
			_sigilo(atras, u, 33.0, a)
			_manto(atras, u, a)
			_corvos_orbita(atras, u, a, false)


## Pontos em px de sprite -> px de tela (o corpo é a partir dos pés).
func _s(pts: PackedVector2Array, u: float) -> PackedVector2Array:
	var r := PackedVector2Array()
	for p in pts:
		r.append((p * u).round())
	return r


## Polígono cheio com contorno de 1 px: a POSIÇÃO cresce com o chefe (u), o traço não (pixel de um tamanho só).
func _poli(ci: CanvasItem, pts: PackedVector2Array, u: float, c: Color, contorno := true) -> void:
	var q := _s(pts, u)
	ci.draw_colored_polygon(q, c)
	if contorno:
		var f := q.duplicate()
		f.append(q[0])
		ci.draw_polyline(f, Color(0, 0, 0, c.a * 0.8), 1.0)


## Linha de 1 px entre dois pontos em px de sprite (dobras, brilhos e barras).
func _lin(ci: CanvasItem, a: Vector2, b: Vector2, u: float, c: Color) -> void:
	ci.draw_line((a * u).round(), (b * u).round(), c, 1.0)


## Elipse cheia em degraus de 1 px (uma linha de 1 px por vez): no lugar do círculo liso e da escala fracionária do achatar. `centro` em px de tela.
func _disco_px(ci: CanvasItem, centro: Vector2, rx: float, ry: float, c: Color) -> void:
	var cx := roundf(centro.x)
	var cy := roundf(centro.y)
	var n := maxi(int(roundf(ry)), 1)
	for j in range(-n, n + 1):
		var meia := int(roundf(rx * sqrt(maxf(1.0 - float(j * j) / float(n * n), 0.0))))
		ci.draw_rect(Rect2(cx - float(meia), cy + float(j), float(meia * 2 + 1), 1.0), c)


## Anel de runas girando no chão (a elipse do chão, achatada em ACHATA): `n` marcas curtas em volta, tudo em traço de 1 px.
func _anel_runas(ci: CanvasItem, u: float, raio: float, c: Color, a: float, n: int, gira: float) -> void:
	var r := raio * u
	var pulso := 0.5 + 0.18 * sin(t * 3.0)
	var anel := PackedVector2Array()
	for k in 37:
		var ang := TAU * float(k) / 36.0
		anel.append(Vector2(cos(ang) * r, sin(ang) * r * ACHATA).round())
	ci.draw_polyline(anel, Color(c.r, c.g, c.b, (pulso + 0.2) * a), 1.0)
	for k in n:
		var ang := t * gira + TAU * float(k) / float(n)
		var d := Vector2(cos(ang), sin(ang) * ACHATA)
		ci.draw_line((d * r * 0.84).round(), (d * r * 1.16).round(), Color(c.r, c.g, c.b, (pulso + 0.35) * a), 1.0)


## A capa do Cavaleiro Rubro, atrás do corpo: o pano, duas dobras de 1 px e a barra mais clara.
func _capa(ci: CanvasItem, u: float, a: float) -> void:
	var p: float = m.pe_logico()
	var bal := sin(t * 2.2) * 1.6 - clampf(m.vel_v.x * 0.04, -2.5, 2.5)
	var pts := PackedVector2Array(
		[
			Vector2(-8, -0.72 * p),
			Vector2(8, -0.72 * p),
			Vector2(12 + bal, -0.34 * p),
			Vector2(11 + bal * 1.5, -0.12 * p),
			Vector2(5 + bal, -0.2 * p),
			Vector2(-3 + bal * 1.2, -0.1 * p),
			Vector2(-11 + bal * 1.5, -0.16 * p),
			Vector2(-12 + bal, -0.36 * p),
		]
	)
	_poli(ci, pts, u, Color(cor2.r, cor2.g, cor2.b, 0.96 * a))
	var fio := PackedVector2Array([Vector2(-6, -0.7 * p), Vector2(6, -0.7 * p), Vector2(9 + bal, -0.36 * p), Vector2(-9 + bal, -0.36 * p)])
	_poli(ci, fio, u, Color(cor2.r * 1.5, cor2.g * 1.5, cor2.b * 1.5, 0.35 * a), false)
	var dobra := Color(0, 0, 0, 0.4 * a)  # as dobras do pano: 1 px, sem crescer com o chefe
	_lin(ci, Vector2(-3, -0.7 * p), Vector2(-4.5 + bal * 1.1, -0.17 * p), u, dobra)
	_lin(ci, Vector2(3, -0.7 * p), Vector2(4 + bal * 1.1, -0.2 * p), u, dobra)
	var barra := Color(cor.r, cor.g * 0.7, cor.b * 0.6, 0.85 * a)  # a barra da capa
	_lin(ci, Vector2(-11 + bal * 1.5, -0.16 * p), Vector2(-3 + bal * 1.2, -0.1 * p), u, barra)
	_lin(ci, Vector2(-3 + bal * 1.2, -0.1 * p), Vector2(5 + bal, -0.2 * p), u, barra)
	_lin(ci, Vector2(5 + bal, -0.2 * p), Vector2(11 + bal * 1.5, -0.12 * p), u, barra)


## A teia grande no chão sob a Rainha: 10 fios e 4 anéis ligando os fios (fio de 1 px).
func _teia_chao(ci: CanvasItem, u: float, raio: float, a: float) -> void:
	var r := raio * u
	var fio := Color(cor2.r, cor2.g, cor2.b, (0.55 + 0.1 * sin(t * 2.0)) * a)
	for j in 10:
		var d := Vector2.from_angle(TAU * float(j) / 10.0 + 0.15)
		ci.draw_line(Vector2.ZERO, Vector2(d.x * r, d.y * r * ACHATA).round(), fio, 1.0)
	for q in 4:
		var pts := PackedVector2Array()
		for j in 11:
			var d := Vector2.from_angle(TAU * float(j) / 10.0 + 0.15)
			var rr := r * (0.25 + 0.25 * float(q)) * (1.0 - 0.05 * float(j % 2) * float(q))  # os fios afundam um pouco entre os raios
			pts.append(Vector2(d.x * rr, d.y * rr * ACHATA).round())
		ci.draw_polyline(pts, fio, 1.0)


## O sigilo do Rei: dois anéis e uma estrela de cinco pontas girando devagar (traço de 1 px).
func _sigilo(ci: CanvasItem, u: float, raio: float, a: float) -> void:
	_anel_runas(ci, u, raio, cor, a, 10, -0.35)
	var r := raio * u * 0.78
	var pts := PackedVector2Array()
	for k in 6:
		var ang := t * 0.25 + TAU * float((k * 2) % 5) / 5.0 - PI * 0.5
		pts.append(Vector2(cos(ang) * r, sin(ang) * r * ACHATA).round())
	ci.draw_polyline(pts, Color(cor.r, cor.g, cor.b, (0.7 + 0.15 * sin(t * 3.0)) * a), 1.0)


## O manto rasgado do Rei, atrás do corpo: a barra em dentes com um debrum de ouro de 1 px e duas dobras.
func _manto(ci: CanvasItem, u: float, a: float) -> void:
	var p: float = m.pe_logico()
	var bal := sin(t * 1.8) * 1.4 - clampf(m.vel_v.x * 0.03, -2.0, 2.0)
	var pts := PackedVector2Array([Vector2(-11, -0.66 * p), Vector2(11, -0.66 * p)])
	for k in 7:  # da direita para a esquerda: os dentes da barra sobem e descem
		var x := 17.0 - 34.0 * float(k) / 6.0
		pts.append(Vector2(x + bal * (1.0 - float(k) / 6.0), -0.02 * p if k % 2 == 0 else -0.16 * p))
	_poli(ci, pts, u, Color(0.34, 0.05, 0.28, 0.96 * a))
	var forro := PackedVector2Array([Vector2(-7, -0.6 * p), Vector2(7, -0.6 * p), Vector2(10 + bal, -0.2 * p), Vector2(-10 + bal, -0.2 * p)])
	_poli(ci, forro, u, Color(1.0, 0.25, 0.7, 0.22 * a), false)
	var dobra := Color(0.12, 0.0, 0.1, 0.55 * a)
	_lin(ci, Vector2(-4, -0.62 * p), Vector2(-6 + bal * 0.8, -0.12 * p), u, dobra)
	_lin(ci, Vector2(4, -0.62 * p), Vector2(6 + bal * 0.8, -0.12 * p), u, dobra)
	var debrum := Color(cor2.r, cor2.g, cor2.b, 0.9 * a)  # o ouro da barra, 1 px, segue os dentes
	for k in range(2, pts.size() - 1):
		ci.draw_line((pts[k] * u).round(), (pts[k + 1] * u).round(), debrum, 1.0)


# ------------------------------------------------------------------ o que fica na frente do corpo


func _desenhar_frente() -> void:
	if not _viva():
		return
	var u := float(m.escala)
	var a := _fade()
	match adorno:
		"elmo":
			_ombreiras(frente, u, a)
			_pluma(frente, u, a)
		"teia":
			_coroa_rainha(frente, a)
		"coroa":
			_corvos_orbita(frente, u, a, true)
			_coroa_rei(frente, a)


func _ombreiras(ci: CanvasItem, u: float, a: float) -> void:
	var p: float = m.pe_logico()
	var ferro := Color(0.62, 0.55, 0.62, 0.95 * a)
	for lado in [-1.0, 1.0]:
		var pts := PackedVector2Array([Vector2(lado * 8, -0.66 * p), Vector2(lado * 15, -0.68 * p), Vector2(lado * 17, -0.82 * p)])
		_poli(ci, pts, u, ferro)
		var ponta := PackedVector2Array([Vector2(lado * 14, -0.69 * p), Vector2(lado * 15.5, -0.7 * p), Vector2(lado * 17, -0.82 * p)])
		_poli(ci, ponta, u, Color(cor.r, cor.g * 0.6, cor.b * 0.5, 0.9 * a), false)
		_lin(ci, Vector2(lado * 9, -0.675 * p), Vector2(lado * 15.5, -0.77 * p), u, Color(0.92, 0.86, 0.92, 0.8 * a))  # o brilho do ferro, 1 px


## A pluma do elmo, sobre a cabeça: um penacho cheio que sobe e tomba para trás, balançando; contorno escuro, miolo na cor da marca e brilho, tudo de 1 px.
func _pluma(ci: CanvasItem, u: float, a: float) -> void:
	var base := _cabeca() + Vector2(0, 2)
	var c := PackedVector2Array()
	for k in 9:
		var f := float(k)
		var x := -f * 1.5 - sin(t * 3.2 + f * 0.6) * f * 0.3 + clampf(-m.vel_v.x * 0.02, -1.5, 1.5) * f * 0.2
		var y := -3.4 * f + 0.3 * f * f
		c.append((base + Vector2(x, y) * u).round())
	var esq := PackedVector2Array()
	var dir := PackedVector2Array()
	for k in c.size():
		var tg := c[mini(k + 1, c.size() - 1)] - c[maxi(k - 1, 0)]
		var nrm := Vector2(-tg.y, tg.x).normalized() if tg.length() > 0.01 else Vector2.RIGHT
		var meia := (2.6 - 2.1 * float(k) / 8.0) * u
		esq.append((c[k] + nrm * meia).round())
		dir.append((c[k] - nrm * meia).round())
	var miolo := Color(cor.r, cor.g * 0.55, cor.b * 0.5, a)
	for k in c.size() - 1:  # cada trecho são dois triângulos (os degenerados, na ponta fina, ficam de fora: o desenho recusa área zero)
		for tri in [[esq[k], esq[k + 1], dir[k]], [esq[k + 1], dir[k + 1], dir[k]]]:
			if absf((tri[1] - tri[0]).cross(tri[2] - tri[0])) >= 1.0:
				ci.draw_colored_polygon(PackedVector2Array(tri), miolo)
	var borda := PackedVector2Array(esq)
	for k in range(dir.size() - 1, -1, -1):
		borda.append(dir[k])
	borda.append(esq[0])
	ci.draw_polyline(borda, Color(0.18, 0.02, 0.03, 0.9 * a), 1.0)
	var luz := PackedVector2Array()
	for k in range(1, c.size() - 1):
		luz.append(((c[k] * 3.0 + esq[k]) * 0.25).round())
	if luz.size() >= 2:
		ci.draw_polyline(luz, Color(1.0, 0.78, 0.55, 0.85 * a), 1.0)


# ------------------------------------------------------------------ cabeça e coroas


## Mede, em cada quadro da folha atual do chefe, onde fica o ápice da cabeça (ou do chapéu): o topo do que é opaco e o x médio das 3 primeiras linhas.
func _medir_cabecas(tp: Dictionary) -> void:
	_cab_tipo = tp
	_cab = []
	var im: Image = (tp.alb as Texture2D).get_image()
	var w := int(tp.w)
	var h := int(tp.h)
	if im == null or im.is_empty():  # sem imagem na memória (renderizador de teste): o ápice vira o meio do topo do quadro
		_cab = [[Vector2(float(w) * 0.5, 0.0)]]
		return
	for l in maxi(im.get_height() / h, 1):
		var linha_q: Array = []
		for c in maxi(im.get_width() / w, 1):
			var v := Vector2(float(w) * 0.5, 0.0)
			var r := im.get_region(Rect2i(c * w, l * h, w, h)).get_used_rect()
			if r.has_area():
				var soma := 0.0
				var n := 0
				for yy in range(r.position.y, mini(r.position.y + 3, r.end.y)):
					for xx in range(r.position.x, r.end.x):
						if im.get_pixel(c * w + xx, l * h + yy).a > 0.3:
							soma += float(xx)
							n += 1
				v = Vector2(soma / float(n) + 0.5 if n > 0 else float(r.position.x + r.end.x) * 0.5, float(r.position.y))
			linha_q.append(v)
		_cab.append(linha_q)


## O ápice da cabeça no quadro que o monstro desenha agora, em px de tela a partir dos pés (já com o tremor e o afundar do sprite).
func _cabeca() -> Vector2:
	var tp: Dictionary = m.tipo
	if _cab_tipo == null or not is_same(_cab_tipo, tp):
		_medir_cabecas(tp)
	var fr: Array = _cab[clampi(int(m.linha), 0, _cab.size() - 1)]
	var v: Vector2 = fr[clampi(int(m.coluna), 0, fr.size() - 1)]
	var e := float(m.esc)
	var x := (v.x - float(tp.w) * 0.5) * e * (-1.0 if m.espelha else 1.0)
	var y := (v.y - float(tp.pe)) * e
	return (Vector2(x, y) + m.sprite.position).round()


## Uma folha de coroa com a base no meio de `base` (px de tela) e um brilho de 1 px que passa pelas gemas, uma de cada vez.
func _folha_coroa(ci: CanvasItem, tex: Texture2D, gemas: Array, base: Vector2, a: float) -> void:
	var canto := (base - Vector2(floorf(tex.get_width() * 0.5), float(tex.get_height()))).round()
	ci.draw_texture(tex, canto, Color(1, 1, 1, a))
	var ciclo := t * 1.1
	var k := int(ciclo) % gemas.size()
	if fmod(ciclo, 1.0) < 0.22:  # o brilho: uma cruz de 1 px com o centro claro, só em uma gema por vez
		var g: Vector2 = canto + (gemas[k] as Vector2)
		var br := Color(1.0, 1.0, 1.0, 0.9 * a)
		var d := 3.0 if tex == COROA_REI else 2.0
		ci.draw_rect(Rect2(g, Vector2.ONE), br)
		for o in [Vector2(d, 0), Vector2(-d, 0), Vector2(0, d), Vector2(0, -d)]:
			ci.draw_rect(Rect2(g + o, Vector2.ONE), Color(br.r, br.g, br.b, br.a * 0.7))


## Onde a base da coroa da Rainha pousa: no eixo do corpo (x = 0 do pivô, como sempre foi) e na altura do topo do desenho. O topo da aranha de 3/4 e de perfil
## é a ponta de uma perna, até 36 px fora do corpo, então o x da cabeça medida não serve aqui.
func _base_coroa_rainha() -> Vector2:
	var sobe := 4.0 + roundf(1.5 * sin(t * 2.0))
	return Vector2(0.0, _cabeca().y - sobe)


## A coroa da Rainha: flutua um pouco acima do topo do corpo, subindo e descendo em passos de 1 px.
func _coroa_rainha(ci: CanvasItem, a: float) -> void:
	_folha_coroa(ci, COROA_RAINHA, GEMAS_RAINHA, _base_coroa_rainha(), a)


## A coroa do Rei: de ouro e gemas magenta, sobre o ápice do chapéu; na fúria um clarão em dois degraus pulsa atrás dela.
func _coroa_rei(ci: CanvasItem, a: float) -> void:
	var base := _cabeca() - Vector2(0, 2)
	if chefe._fase2:
		var r := 44.0 + roundf(3.0 * sin(t * 9.0))
		var centro := base - Vector2(0, float(COROA_REI.get_height()) * 0.45)
		_disco_px(ci, centro, r, r, Color(1.0, 0.3, 0.7, 0.14 * a))
		_disco_px(ci, centro, r * 0.68, r * 0.68, Color(1.0, 0.3, 0.7, 0.14 * a))
	_folha_coroa(ci, COROA_REI, GEMAS_REI, base, a)


## Os corvos que giram em volta do Rei: `na_frente` desenha os da metade de perto da câmera (depois do corpo) e senão os de trás.
## Escala 1 sempre (a mesma do golpe de corvos do herói): a profundidade é a cor mais escura dos de trás, não um tamanho quebrado.
func _corvos_orbita(ci: CanvasItem, u: float, a: float, na_frente: bool) -> void:
	var f: Dictionary = Anim.de("corvos").get("voo", {})
	if f.is_empty():
		return
	var p: float = m.pe_logico()
	var vel := (1.3 + 1.1 * float(m.carga)) * (1.5 if chefe._fase2 else 1.0)
	for k in CORVOS_ORBITA:
		var fase := t * vel + TAU * float(k) / float(CORVOS_ORBITA)
		if (sin(fase) >= 0.0) != na_frente:
			continue
		var pos := Vector2(cos(fase) * 25.0, sin(fase) * 9.0 - 0.58 * p + sin(t * 2.0 + float(k)) * 3.0) * u
		var lado := 1.0 if -sin(fase) >= 0.0 else -1.0  # vai para a direita quando o x cresce
		var tom := Color(0.75, 0.55, 1.0, a) if na_frente else Color(0.5, 0.36, 0.72, a)
		Anim.desenhar(ci, f, Anim.quadro_em(f, t + float(k) * 0.13), pos.round(), 0.0, Vector2(lado, 1.0), tom)


# ------------------------------------------------------------------ a revoada (mundo)


func _desenhar_voos() -> void:
	if voos.is_empty():
		return
	var f: Dictionary = Anim.de("corvos").get("voo", {})
	if f.is_empty():
		return
	for v in voos:
		var k := float(v.t) / VOO_S
		if k < 0.0:
			continue
		var g: Vector2 = v.g
		var p: Vector2 = v.p
		var s := lerpf(-30.0, float(v.c) + 50.0, k)
		var solo: Vector2 = (v.o as Vector2) + Vector2(g.x * s + p.x * float(v.off), (g.y * s + p.y * float(v.off)) * ACHATA)
		var dir_tela := Vector2(g.x, g.y * ACHATA)
		var z: float = float(v.z) + sin(float(v.t) * 30.0 + float(v.ph)) * 2.0
		var c := (solo + Vector2(0, -z)).round()
		_disco_px(no_voo, solo, 6.0, 4.0, Color(0, 0, 0, 0.3))  # a sombra no chão, elipse em degraus de 1 px
		_disco_px(no_voo, c, 11.0, 11.0, Color(cor.r, cor.g, cor.b, 0.22))
		var esq := dir_tela.x < 0.0
		var ang := PixelRot.quarto((-dir_tela).angle() if esq else dir_tela.angle())  # só 0 ou 90 graus: a folha não gira por ângulo livre
		Anim.desenhar(no_voo, f, Anim.quadro_em(f, float(v.t) + float(v.ph)), c, ang, Vector2(-1.0 if esq else 1.0, 1.0))
