extends RefCounted
## A APARÊNCIA própria de cada chefe da v2 (v2/chefe.gd), feita em código sobre o sprite 2D do monstro: nada de arte nova nem de 3D.
## O `adorno` de cada marca (dados/v2_cartas.json > chefes > marcas > visual) escolhe o conjunto:
##   elmo  = Devourer of Flesh: capa rubra atrás do corpo, pluma e ombreiras de espinho no elmo, anel de runas vermelho no chão e brasas que sobem;
##   teia  = Devourer of Structure: teia grande no chão sob ela, coroa flutuando sobre o abdômen e esporos verdes que sobem;
##   coroa = Devourer of Land (o chefão): manto rasgado, coroa de ouro com gemas, sigilo de estrela no chão, quatro corvos girando em volta
##           (passam por trás e pela frente do corpo) e brasas e penas; na fúria a coroa brilha e os corvos giram mais rápido.
## Dois nós filhos do corpo do chefe (`atras`, desenhado antes do sprite, e `frente`, depois) e um nó do mundo (`no_voo`) com os corvos da REVOADA,
## o ataque próprio do Rei (chefe.gd chama `revoada` no disparo das faixas). Tudo é desenhado sem luz 2D (o chefe já tem a luz própria dele) e
## aparece aos poucos na entrada (ENTRADA_S). As medidas são em "pixels do sprite" (multiplicadas pela escala do chefe, como o próprio sprite).

const Anim := preload("res://v2/anim_golpes.gd")  # a folha dos corvos (assets/v2/armas_anim, a mesma do golpe de corvos do herói)
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


func _poli(ci: CanvasItem, pts: PackedVector2Array, u: float, c: Color, contorno := true) -> void:
	var q := _s(pts, u)
	ci.draw_colored_polygon(q, c)
	if contorno:
		var f := q.duplicate()
		f.append(q[0])
		ci.draw_polyline(f, Color(0, 0, 0, c.a * 0.8), maxf(1.0, u * 0.5))


## Anel de runas girando no chão (a elipse do chão, achatada em ACHATA): `n` marcas curtas em volta.
func _anel_runas(ci: CanvasItem, u: float, raio: float, c: Color, a: float, n: int, gira: float) -> void:
	var r := raio * u
	var pulso := 0.5 + 0.18 * sin(t * 3.0)
	var anel := PackedVector2Array()
	for k in 37:
		var ang := TAU * float(k) / 36.0
		anel.append(Vector2(cos(ang) * r, sin(ang) * r * ACHATA).round())
	ci.draw_polyline(anel, Color(c.r, c.g, c.b, pulso * a), maxf(2.0, u * 0.7))
	for k in n:
		var ang := t * gira + TAU * float(k) / float(n)
		var d := Vector2(cos(ang), sin(ang) * ACHATA)
		ci.draw_line((d * r * 0.84).round(), (d * r * 1.16).round(), Color(c.r, c.g, c.b, (pulso + 0.25) * a), maxf(2.0, u * 0.8))


func _capa(ci: CanvasItem, u: float, a: float) -> void:
	var p := float(m.tipo.pe)
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


## A teia grande no chão sob a Rainha: 10 fios e 4 anéis ligando os fios.
func _teia_chao(ci: CanvasItem, u: float, raio: float, a: float) -> void:
	var r := raio * u
	var fio := Color(cor2.r, cor2.g, cor2.b, (0.4 + 0.1 * sin(t * 2.0)) * a)
	var larg := maxf(1.0, u * 0.45)
	for j in 10:
		var d := Vector2.from_angle(TAU * float(j) / 10.0 + 0.15)
		ci.draw_line(Vector2.ZERO, Vector2(d.x * r, d.y * r * ACHATA).round(), fio, larg)
	for q in 4:
		var pts := PackedVector2Array()
		for j in 11:
			var d := Vector2.from_angle(TAU * float(j) / 10.0 + 0.15)
			var rr := r * (0.25 + 0.25 * float(q)) * (1.0 - 0.05 * float(j % 2) * float(q))  # os fios afundam um pouco entre os raios
			pts.append(Vector2(d.x * rr, d.y * rr * ACHATA).round())
		ci.draw_polyline(pts, fio, larg)


## O sigilo do Rei: dois anéis e uma estrela de cinco pontas girando devagar.
func _sigilo(ci: CanvasItem, u: float, raio: float, a: float) -> void:
	_anel_runas(ci, u, raio, cor, a, 10, -0.35)
	var r := raio * u * 0.78
	var pts := PackedVector2Array()
	for k in 6:
		var ang := t * 0.25 + TAU * float((k * 2) % 5) / 5.0 - PI * 0.5
		pts.append(Vector2(cos(ang) * r, sin(ang) * r * ACHATA).round())
	ci.draw_polyline(pts, Color(cor.r, cor.g, cor.b, (0.5 + 0.15 * sin(t * 3.0)) * a), maxf(2.0, u * 0.6))


## O manto rasgado do Rei, atrás do corpo, com a barra em dentes.
func _manto(ci: CanvasItem, u: float, a: float) -> void:
	var p := float(m.tipo.pe)
	var bal := sin(t * 1.8) * 1.4 - clampf(m.vel_v.x * 0.03, -2.0, 2.0)
	var pts := PackedVector2Array([Vector2(-11, -0.66 * p), Vector2(11, -0.66 * p)])
	for k in 7:  # da direita para a esquerda: os dentes da barra sobem e descem
		var x := 17.0 - 34.0 * float(k) / 6.0
		pts.append(Vector2(x + bal * (1.0 - float(k) / 6.0), -0.02 * p if k % 2 == 0 else -0.16 * p))
	_poli(ci, pts, u, Color(0.34, 0.05, 0.28, 0.96 * a))
	var forro := PackedVector2Array([Vector2(-7, -0.6 * p), Vector2(7, -0.6 * p), Vector2(10 + bal, -0.2 * p), Vector2(-10 + bal, -0.2 * p)])
	_poli(ci, forro, u, Color(1.0, 0.25, 0.7, 0.22 * a), false)


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
			var p := float(m.tipo.pe)
			_coroa(frente, u, 0.0, -0.9 * p + 1.5 * sin(t * 2.0), 13.0, 6.0, Color(0.85, 1.0, 0.55), Color(0.2, 1.0, 0.35), a, 5)
		"coroa":
			_corvos_orbita(frente, u, a, true)
			_coroa_rei(frente, u, a)


func _ombreiras(ci: CanvasItem, u: float, a: float) -> void:
	var p := float(m.tipo.pe)
	var ferro := Color(0.62, 0.55, 0.62, 0.95 * a)
	for lado in [-1.0, 1.0]:
		var pts := PackedVector2Array([Vector2(lado * 8, -0.66 * p), Vector2(lado * 15, -0.68 * p), Vector2(lado * 17, -0.82 * p)])
		_poli(ci, pts, u, ferro)
		var ponta := PackedVector2Array([Vector2(lado * 14, -0.69 * p), Vector2(lado * 15.5, -0.7 * p), Vector2(lado * 17, -0.82 * p)])
		_poli(ci, ponta, u, Color(cor.r, cor.g * 0.6, cor.b * 0.5, 0.9 * a), false)


## A pluma do elmo: uma curva grossa que sobe do topo da cabeça e tomba para trás, balançando.
func _pluma(ci: CanvasItem, u: float, a: float) -> void:
	var p := float(m.tipo.pe)
	var pts := PackedVector2Array()
	for k in 9:
		var f := float(k)
		var x := -f * 1.5 - sin(t * 3.2 + f * 0.6) * f * 0.3 + clampf(-m.vel_v.x * 0.02, -1.5, 1.5) * f * 0.2
		var y := -0.9 * p - 3.4 * f + 0.3 * f * f
		pts.append((Vector2(x, y) * u).round())
	ci.draw_polyline(pts, Color(0.18, 0.02, 0.03, 0.9 * a), u * 5.5)
	ci.draw_polyline(pts, Color(cor.r, cor.g * 0.55, cor.b * 0.5, a), u * 3.6)
	ci.draw_polyline(pts, Color(1.0, 0.78, 0.55, 0.85 * a), u * 1.2)


## Uma coroa de `n` pontas: base (px de sprite) em y, centro em x; ouro com uma gema na ponta de cada espinho.
func _coroa(ci: CanvasItem, u: float, x: float, y: float, larg: float, alto: float, ouro: Color, gema: Color, a: float, n: int) -> void:
	var faixa := PackedVector2Array(
		[Vector2(x - larg * 0.5, y), Vector2(x + larg * 0.5, y), Vector2(x + larg * 0.5, y - 3.0), Vector2(x - larg * 0.5, y - 3.0)]
	)
	_poli(ci, faixa, u, Color(ouro.r, ouro.g, ouro.b, a))
	var w := larg / float(n - 1)
	for k in n:
		var cx := x - larg * 0.5 + larg * float(k) / float(n - 1)
		var h := alto * (1.0 if k % 2 == 0 else 0.62)
		var tri := PackedVector2Array([Vector2(cx - w * 0.5, y - 3.0), Vector2(cx + w * 0.5, y - 3.0), Vector2(cx, y - 3.0 - h)])
		_poli(ci, tri, u, Color(ouro.r, ouro.g, ouro.b, a))
		ci.draw_rect(Rect2(Vector2(cx - 1.0, y - 4.2 - h) * u, Vector2(2.0, 2.0) * u).abs(), Color(gema.r, gema.g, gema.b, a))


## A coroa do Rei: grande, de ouro e gemas magenta; na fúria um clarão pulsa atrás dela.
func _coroa_rei(ci: CanvasItem, u: float, a: float) -> void:
	var p := float(m.tipo.pe)
	var y := -p + 4.0
	if chefe._fase2:
		var r := (13.0 + 2.5 * sin(t * 9.0)) * u
		ci.draw_circle(Vector2(0.0, y - 5.0) * u, r, Color(1.0, 0.3, 0.7, 0.28 * a))
	_coroa(ci, u, 0.0, y, 15.0, 9.0, Color(1.0, 0.82, 0.3), Color(1.0, 0.2, 0.65), a, 5)


## Os corvos que giram em volta do Rei: `na_frente` desenha os da metade de perto da câmera (depois do corpo) e senão os de trás.
func _corvos_orbita(ci: CanvasItem, u: float, a: float, na_frente: bool) -> void:
	var f: Dictionary = Anim.de("corvos").get("voo", {})
	if f.is_empty():
		return
	var p := float(m.tipo.pe)
	var vel := (1.3 + 1.1 * float(m.carga)) * (1.5 if chefe._fase2 else 1.0)
	for k in CORVOS_ORBITA:
		var fase := t * vel + TAU * float(k) / float(CORVOS_ORBITA)
		if (sin(fase) >= 0.0) != na_frente:
			continue
		var pos := Vector2(cos(fase) * 25.0, sin(fase) * 9.0 - 0.58 * p + sin(t * 2.0 + float(k)) * 3.0) * u
		var lado := 1.0 if -sin(fase) >= 0.0 else -1.0  # vai para a direita quando o x cresce
		var esc := 2.0 * (0.8 + 0.2 * sin(fase))  # os de trás são um pouco menores
		var sombra := Color(0.75, 0.55, 1.0, a)
		Anim.desenhar(ci, f, Anim.quadro_em(f, t + float(k) * 0.13), pos.round(), 0.0, Vector2(lado * esc, esc), sombra)


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
		no_voo.draw_set_transform(solo, 0.0, Vector2(1.0, ACHATA))
		no_voo.draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.3))
		no_voo.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var cc := Color(cor.r, cor.g, cor.b, 0.22)
		no_voo.draw_circle(c, 11.0, cc)
		var esq := dir_tela.x < 0.0
		var ang := (-dir_tela).angle() if esq else dir_tela.angle()
		Anim.desenhar(no_voo, f, Anim.quadro_em(f, float(v.t) + float(v.ph)), c, ang, Vector2(-1.4 if esq else 1.4, 1.4))
