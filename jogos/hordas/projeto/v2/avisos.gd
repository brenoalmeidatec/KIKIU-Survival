extends RefCounted
## Ataques ANUNCIADOS no chão (leva 3): uma área (círculo ou faixa) que PISCA cada vez mais rápido durante `dur` s e só então causa o dano,
## para o jogador ter tempo de sair (a esquiva também vale). Quem usa: os chefes (estouro, chuva e investida, mais o leque, a teia e a revoada,
## que são cada um de uma marca, ver v2/chefe.gd) e a elite explosiva. Formas: círculo, faixa (com ou sem dano) e SETOR (o leque do Devourer of Flesh).
## Pool de MAX avisos e UMA chamada de desenho aditiva por quadro na camada glow. O chão é uma elipse (y achatado por ACHATA), igual às
## sombras e aos golpes secundários: um círculo no chão é uma elipse na tela, e o dano usa a mesma elipse.

const MAX := 24
const ACHATA := 0.62
const MIOLO_MIN := 6.0  # px: abaixo disso o miolo do aviso não vira polígono (os pontos arredondados coincidem, #127)
const Anim := preload("res://v2/anim_golpes.gd")  # as folhas dos ataques inimigos (indice_perigo.json; docs/combate_v2)
## Estilo do aviso: 0 = só o chão pisca (como antes); 1 = QUEDA, uma pedra de energia cai do céu no círculo e estoura no disparo (a chuva do
## chefe); 2 = ESTOURO, o chão racha e explode no disparo (o estouro do chefe e a elite explosiva); 3 = TEIA, fios e anéis de teia desenhados
## sobre o círculo (a teia da Devourer of Structure). O dano continua no disparo, como sempre.
const QUEDA_DE := Vector2(-34.0, -96.0)  # de onde a pedra vem, a partir do centro do círculo
const QUEDA_COMECA := 0.35  # fração do aviso em que a pedra aparece no alto

var combate
var mundo
var no: Node2D
var tipo := PackedByteArray()  # 0 = livre, 1 = círculo, 2 = faixa, 3 = setor (leque)
var pos := PackedVector2Array()
var dir := PackedVector2Array()  # faixa e setor: direção no chão (já sem o achatamento)
var tam := PackedFloat32Array()  # círculo e setor: raio; faixa: comprimento
var larg := PackedFloat32Array()  # faixa: largura; setor: abertura total (rad)
var t := PackedFloat32Array()
var dur := PackedFloat32Array()
var dano := PackedFloat32Array()
var cor := PackedColorArray()
var estilo := PackedByteArray()
var no_corpo: Node2D  # a pedra que cai (mistura normal, sem luz: a fumaça escura aparece)
var efeito: Array = []  # Callable ou null: roda no instante do dano
var dono: Array = []  # quem criou o aviso (ou null): `cancelar` tira só os avisos de um dono (o chefe que morre)
var acertou := false  # o último aviso a disparar TIROU VIDA do herói? (vale dentro do `quando` dele: a teia só prende quem perdeu vida; escudo, esquiva e invencível não contam)
var disparados := 0  # quantos já dispararam (testes)
var machucou := 0  # quantas vezes acertou o herói (testes)
var _desenhou := false
var ret_t := 9.0  # retículo do chefe sobre o herói: anel e cruz que giram durante o aviso
var ret_dur := 1.0
var ret_raio := 0.0


func montar(c, camada: Node) -> void:
	combate = c
	mundo = c.mundo
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	no = Node2D.new()
	no.material = mat
	no.draw.connect(_desenhar)
	camada.add_child(no)
	var mat_c := CanvasItemMaterial.new()
	mat_c.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	no_corpo = Node2D.new()
	no_corpo.material = mat_c
	no_corpo.draw.connect(_desenhar_quedas)
	camada.add_child(no_corpo)
	estilo.resize(MAX)
	tipo.resize(MAX)
	pos.resize(MAX)
	dir.resize(MAX)
	tam.resize(MAX)
	larg.resize(MAX)
	t.resize(MAX)
	dur.resize(MAX)
	dano.resize(MAX)
	cor.resize(MAX)
	efeito.resize(MAX)
	dono.resize(MAX)


## O retículo laranja (anel e cruz girando) que persegue o herói durante o aviso do chefe.
func reticulo(raio: float, espera: float) -> void:
	ret_t = 0.0
	ret_dur = espera
	ret_raio = raio


func limpar() -> void:
	ret_t = 9.0
	tipo.fill(0)
	estilo.fill(0)
	for i in MAX:
		efeito[i] = null
		dono[i] = null
	no.queue_redraw()
	no_corpo.queue_redraw()


## Marca `quem` como dono do aviso `i` e devolve `i`.
func de(i: int, quem) -> int:
	dono[i] = quem
	return i


## Tira de cena, sem disparar nem dar dano, os avisos de `quem` (e os `quando` deles): o chefe que morre não deixa ataque pendente.
func cancelar(quem) -> void:
	for i in MAX:
		if tipo[i] != 0 and dono[i] == quem:
			tipo[i] = 0
			estilo[i] = 0
			efeito[i] = null
			dono[i] = null
	no.queue_redraw()
	no_corpo.queue_redraw()


## Dá ao aviso `i` o estilo de queda (1) ou de estouro (2), com a folha de perigo correspondente.
func com_estilo(i: int, e: int) -> void:
	estilo[i] = e


func ativos() -> int:
	var n := 0
	for i in MAX:
		if tipo[i] != 0:
			n += 1
	return n


func _livre() -> int:
	for i in MAX:
		if tipo[i] == 0:
			return i
	return 0  # cheio: reaproveita o primeiro (nunca acontece com os números atuais)


## Um círculo no chão (raio em px) que dispara em `espera` s e tira `dano_` do herói se ele estiver dentro. `quando` roda no disparo.
func circulo(p: Vector2, raio: float, espera: float, dano_: float, c: Color, quando = null) -> int:
	var i := _livre()
	tipo[i] = 1
	estilo[i] = 0
	pos[i] = p
	tam[i] = raio
	t[i] = 0.0
	dur[i] = espera
	dano[i] = dano_
	cor[i] = c
	efeito[i] = quando
	return i


## Uma faixa no chão: de `p` na direção `d` (coordenadas do mundo) por `compr` px de chão e `largura` de largura. Só avisa (dano_ pode ser 0).
func faixa(p: Vector2, d: Vector2, compr: float, largura: float, espera: float, dano_: float, c: Color, quando = null) -> int:
	var i := _livre()
	tipo[i] = 2
	estilo[i] = 0
	pos[i] = p
	dir[i] = Vector2(d.x, d.y / ACHATA).normalized()
	tam[i] = compr
	larg[i] = largura
	t[i] = 0.0
	dur[i] = espera
	dano[i] = dano_
	cor[i] = c
	efeito[i] = quando
	return i


## Um LEQUE no chão: o setor de círculo de raio `raio` (px de chão) e abertura total `abertura` (graus) a partir de `p`, voltado para `d` (mundo).
## Dispara em `espera` s e tira `dano_` de quem estiver dentro dele. `quando` roda no disparo.
func setor(p: Vector2, d: Vector2, raio: float, abertura: float, espera: float, dano_: float, c: Color, quando = null) -> int:
	var i := _livre()
	tipo[i] = 3
	estilo[i] = 0
	pos[i] = p
	dir[i] = Vector2(d.x, d.y / ACHATA).normalized()
	tam[i] = raio
	larg[i] = deg_to_rad(abertura)
	t[i] = 0.0
	dur[i] = espera
	dano[i] = dano_
	cor[i] = c
	efeito[i] = quando
	return i


func atualizar(dt: float) -> void:
	var algum := false
	for i in MAX:
		if tipo[i] == 0:
			continue
		algum = true
		t[i] += dt
		if t[i] >= dur[i]:
			_disparar(i)
	var ret := ret_t < ret_dur
	if ret:
		ret_t += dt
	if algum or ret or _desenhou:
		no.queue_redraw()
		no_corpo.queue_redraw()
	_desenhou = algum or ret


func _disparar(i: int) -> void:
	disparados += 1
	var h = mundo.heroi
	var vida_antes: float = h.vida
	var p: Vector2 = pos[i]
	var c: Color = cor[i]
	if tipo[i] == 1:
		var r := tam[i]
		if dano[i] > 0.0 and h.vivo() and _na_elipse(h.pos - p, r + h.raio):
			if h.levar_dano(dano[i], p):
				machucou += 1
		combate.fx.onda(p, Color(c.r, c.g, c.b, 0.95), r, 0.3)
		combate.fx.folha("cristal", p, r * 1.1, c, 0.3)  # o golpe do chefe sai com o estouro de cristal
		combate.fx.estouro(p + Vector2(0, -4), c, 10)
		combate.fx.luz_rapida(p + Vector2(0, -6), c, 1.8, r * 2.6, 0.3)
		combate.audio.tocar("runa", randf_range(0.75, 0.9), -2.0, 0.05)
		mundo.cam.tremer(1.5, 0.12)
		_estouro_folha(i, p, r)
	elif tipo[i] == 3:
		_disparar_setor(i, p, c)
	else:
		if dano[i] > 0.0 and h.vivo() and na_faixa(i, h.pos, h.raio * 0.5):  # a revoada de corvos: a faixa também machuca
			if h.levar_dano(dano[i], p):
				machucou += 1
		combate.fx.onda(p, Color(c.r, c.g, c.b, 0.6), 22.0, 0.2)
	acertou = h.vida < vida_antes
	var f = efeito[i]
	efeito[i] = null
	dono[i] = null
	tipo[i] = 0
	if f != null:
		f.call()


## O golpe do leque: o corte da katana inimiga varre o setor, centelhas na borda e o dano em quem ficou dentro.
func _disparar_setor(i: int, p: Vector2, c: Color) -> void:
	var h = mundo.heroi
	if dano[i] > 0.0 and h.vivo() and na_setor(i, h.pos, h.raio):
		if h.levar_dano(dano[i], p):
			machucou += 1
	var ang := _g2w(dir[i]).angle()
	var r := tam[i]
	combate.fx.corte(p + Vector2(0, -10), ang, r * 0.9, rad_to_deg(larg[i]), 1.0, "corte", c, 0.3)
	combate.fx.onda(p, Color(c.r, c.g, c.b, 0.6), 26.0, 0.2)
	for k in 5:
		var a := (float(k) / 4.0 - 0.5) * larg[i]
		var u: Vector2 = dir[i].rotated(a)
		combate.fx.faiscas(p + _g2w(u * r), _g2w(u), 4, c.lerp(Color.WHITE, 0.4), 130.0)
	combate.audio.tocar("runa", randf_range(1.0, 1.15), -3.0, 0.05)
	mundo.cam.tremer(1.8, 0.14)


static func _na_elipse(d: Vector2, r: float) -> bool:
	var y := d.y / ACHATA
	return d.x * d.x + y * y < r * r


## O herói está dentro da faixa `i`? (usado pelo chefe na investida)
func na_faixa(i: int, ponto: Vector2, folga := 0.0) -> bool:
	var rel := ponto - pos[i]
	var g := Vector2(rel.x, rel.y / ACHATA)
	var ao_longo := g.dot(dir[i])
	var lado := absf(g.cross(dir[i]))
	return ao_longo > -folga and ao_longo < tam[i] + folga and lado < larg[i] * 0.5 + folga


## O ponto está dentro do setor `i`? (o corpo de `folga` px conta: encostar na borda machuca)
func na_setor(i: int, ponto: Vector2, folga := 0.0) -> bool:
	var rel := ponto - pos[i]
	var g := Vector2(rel.x, rel.y / ACHATA)
	var d := g.length()
	if d > tam[i] + folga:
		return false
	if d <= folga:
		return true  # em cima de quem bate
	return absf(dir[i].angle_to(g)) <= larg[i] * 0.5 + asin(minf(folga / d, 1.0))


func _elipse(p: Vector2, r: float, n: int) -> PackedVector2Array:
	var v := PackedVector2Array()
	v.resize(n)
	for k in n:
		var a := TAU * float(k) / float(n)
		v[k] = (p + Vector2(cos(a) * r, sin(a) * r * ACHATA)).round()
	return v


func _desenhar() -> void:
	if ret_t < ret_dur and mundo.heroi != null:
		var k := ret_t / ret_dur
		var c := Color(1.0, 0.55, 0.15, 0.55 + 0.4 * k)
		var r := ret_raio * (1.25 - 0.25 * k)  # fecha sobre o herói
		var anel: PackedVector2Array = _elipse(mundo.heroi.pos, r, 28)
		anel.append(anel[0])
		no.draw_polyline(anel, c, 2.0)
		var a := ret_t * 3.0
		for j in 4:
			var u := Vector2.from_angle(a + j * PI * 0.5)
			var q: Vector2 = mundo.heroi.pos
			no.draw_line((q + _g2w(u * r * 0.55)).round(), (q + _g2w(u * r * 1.1)).round(), c, 2.0)
	for i in MAX:
		if tipo[i] == 0:
			continue
		var k := t[i] / dur[i]
		var c: Color = cor[i]
		var pisca := 0.5 + 0.5 * sin(t[i] * (9.0 + 30.0 * k))
		var al := 0.26 + 0.4 * pisca * (0.4 + 0.6 * k)
		if tipo[i] == 1:
			var r := tam[i]
			var poly := _elipse(pos[i], r, 28)
			no.draw_colored_polygon(poly, Color(c.r, c.g, c.b, al))
			# o miolo vai enchendo até o raio todo: quando enche, dispara
			if r * k >= MIOLO_MIN:
				no.draw_colored_polygon(_elipse(pos[i], r * k, 24), Color(c.r, c.g, c.b, 0.22 + 0.2 * pisca))
			var borda := poly.duplicate()
			borda.append(poly[0])
			no.draw_polyline(borda, Color(c.r, c.g * 0.8, c.b * 0.8, 0.8 + 0.2 * pisca), 3.0)
			if estilo[i] == 3:
				_desenhar_teia(pos[i], r, c, 0.55 + 0.35 * pisca)
		elif tipo[i] == 3:
			var leque := _fatia(pos[i], dir[i], tam[i], larg[i])
			no.draw_colored_polygon(leque, Color(c.r, c.g, c.b, al))
			if tam[i] * k >= MIOLO_MIN:
				no.draw_colored_polygon(_fatia(pos[i], dir[i], tam[i] * k, larg[i]), Color(c.r, c.g, c.b, 0.22 + 0.2 * pisca))
			leque.append(leque[0])
			no.draw_polyline(leque, Color(1.0, 0.9, 0.8, 0.5 + 0.4 * pisca), 2.0)
		else:
			var d: Vector2 = dir[i]
			var perp := Vector2(-d.y, d.x)
			var a0 := pos[i]
			var a1 := pos[i] + _g2w(d * tam[i])
			var o := _g2w(perp * larg[i] * 0.5)
			var quad := PackedVector2Array([(a0 + o).round(), (a1 + o).round(), (a1 - o).round(), (a0 - o).round()])
			no.draw_colored_polygon(quad, Color(c.r, c.g, c.b, al))
			var fim := a0.lerp(a1, k)
			if a0.distance_to(fim) >= MIOLO_MIN:
				no.draw_colored_polygon(
					PackedVector2Array([(a0 + o).round(), (fim + o).round(), (fim - o).round(), (a0 - o).round()]), Color(c.r, c.g, c.b, 0.22 + 0.2 * pisca)
				)
			no.draw_polyline(
				PackedVector2Array([(a0 + o).round(), (a1 + o).round(), (a1 - o).round(), (a0 - o).round(), (a0 + o).round()]),
				Color(1.0, 0.9, 0.8, 0.5 + 0.4 * pisca),
				1.5
			)


## O contorno do setor (leque) como polígono na tela: o vértice em `p` e o arco de raio `r`.
func _fatia(p: Vector2, d: Vector2, r: float, abertura: float) -> PackedVector2Array:
	var v := PackedVector2Array([p.round()])
	var n := 14
	for k in n + 1:
		var a := (float(k) / float(n) - 0.5) * abertura
		v.append((p + _g2w(d.rotated(a) * r)).round())
	return v


## Fios e anéis de teia sobre o círculo da teia (estilo 3): 8 fios do centro à borda e 3 anéis (octógonos) ligando os fios.
func _desenhar_teia(p: Vector2, r: float, c: Color, al: float) -> void:
	var cor_fio := Color(0.9, 1.0, 0.9, al)
	for j in 8:
		var u := Vector2.from_angle(TAU * float(j) / 8.0 + 0.2)
		no.draw_line(p.round(), (p + _g2w(u * r)).round(), cor_fio, 1.5)
	for q in 3:
		var pts := PackedVector2Array()
		for j in 9:
			pts.append((p + _g2w(Vector2.from_angle(TAU * float(j) / 8.0 + 0.2) * r * (0.3 + 0.25 * float(q)))).round())
		no.draw_polyline(pts, Color(c.r, c.g, c.b, al), 1.5)


func _g2w(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * ACHATA)


## No disparo: a folha do impacto da pedra (queda) ou do chão que explode (estouro), do tamanho da área real. Só efeito.
func _estouro_folha(i: int, p: Vector2, r: float) -> void:
	var id := "perigo_chuva" if estilo[i] == 1 else ("perigo_estouro" if estilo[i] == 2 else "")
	if id == "" or combate.armas == null:
		return
	var f: Dictionary = Anim.de(id).get("impacto", {})
	if f.is_empty():
		return
	var esc := r * 2.0 / (f.quadro as Vector2).x
	combate.armas.novas.tocar_fx(f, p, maxf(1.0, roundf(esc)) if estilo[i] == 1 else esc)


## A pedra que cai em cada círculo de queda: aparece no alto na fração QUEDA_COMECA do aviso e desce acelerando em diagonal, com sombra
## que cresce e uma cópia de rastro; chega ao chão no instante do dano.
func _desenhar_quedas() -> void:
	var f: Dictionary = Anim.de("perigo_chuva").get("queda", {})
	if f.is_empty():
		return
	for i in MAX:
		if tipo[i] != 1 or estilo[i] != 1:
			continue
		var k := t[i] / dur[i]
		if k < QUEDA_COMECA:
			continue
		var u := (k - QUEDA_COMECA) / (1.0 - QUEDA_COMECA)
		var e := u * u
		var p: Vector2 = pos[i]
		no_corpo.draw_set_transform(p, 0.0, Vector2(1.0, ACHATA))
		no_corpo.draw_circle(Vector2.ZERO, 3.0 + 7.0 * e, Color(0, 0, 0, 0.15 + 0.3 * e))
		no_corpo.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var ang := (-QUEDA_DE).angle()
		var q := Anim.quadro_em(f, t[i] + float(i) * 0.1)
		var e_r := maxf(e - 0.1 * (0.35 + e), 0.0)
		Anim.desenhar(no_corpo, f, (q + int(f.n) - 1) % int(f.n), p + QUEDA_DE * (1.0 - e_r), ang, Vector2(0.85, 0.85), Color(1, 1, 1, 0.4))
		Anim.desenhar(no_corpo, f, q, p + QUEDA_DE * (1.0 - e), ang)
