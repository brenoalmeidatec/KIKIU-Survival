extends RefCounted
## Ataques ANUNCIADOS no chão (leva 3): uma área (círculo ou faixa) que PISCA cada vez mais rápido durante `dur` s e só então causa o dano,
## para o jogador ter tempo de sair (a esquiva também vale). Quem usa: os chefes (estouro, chuva, investida) e a elite explosiva.
## Pool de MAX avisos e UMA chamada de desenho aditiva por quadro na camada glow. O chão é uma elipse (y achatado por ACHATA), igual às
## sombras e aos golpes secundários: um círculo no chão é uma elipse na tela, e o dano usa a mesma elipse.

const MAX := 24
const ACHATA := 0.62

var combate
var mundo
var no: Node2D
var tipo := PackedByteArray()  # 0 = livre, 1 = círculo, 2 = faixa
var pos := PackedVector2Array()
var dir := PackedVector2Array()  # faixa: direção no chão (já sem o achatamento)
var tam := PackedFloat32Array()  # círculo: raio; faixa: comprimento
var larg := PackedFloat32Array()
var t := PackedFloat32Array()
var dur := PackedFloat32Array()
var dano := PackedFloat32Array()
var cor := PackedColorArray()
var efeito: Array = []  # Callable ou null: roda no instante do dano
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


## O retículo laranja (anel e cruz girando) que persegue o herói durante o aviso do chefe.
func reticulo(raio: float, espera: float) -> void:
	ret_t = 0.0
	ret_dur = espera
	ret_raio = raio


func limpar() -> void:
	ret_t = 9.0
	tipo.fill(0)
	for i in MAX:
		efeito[i] = null
	no.queue_redraw()


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
	_desenhou = algum or ret


func _disparar(i: int) -> void:
	disparados += 1
	var h = mundo.heroi
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
	else:
		combate.fx.onda(p, Color(c.r, c.g, c.b, 0.6), 22.0, 0.2)
	var f = efeito[i]
	efeito[i] = null
	tipo[i] = 0
	if f != null:
		f.call()


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
			no.draw_colored_polygon(_elipse(pos[i], r * k, 24), Color(c.r, c.g, c.b, 0.22 + 0.2 * pisca))
			var borda := poly.duplicate()
			borda.append(poly[0])
			no.draw_polyline(borda, Color(c.r, c.g * 0.8, c.b * 0.8, 0.8 + 0.2 * pisca), 3.0)
		else:
			var d: Vector2 = dir[i]
			var perp := Vector2(-d.y, d.x)
			var a0 := pos[i]
			var a1 := pos[i] + _g2w(d * tam[i])
			var o := _g2w(perp * larg[i] * 0.5)
			var quad := PackedVector2Array([(a0 + o).round(), (a1 + o).round(), (a1 - o).round(), (a0 - o).round()])
			no.draw_colored_polygon(quad, Color(c.r, c.g, c.b, al))
			var fim := a0.lerp(a1, k)
			no.draw_colored_polygon(
				PackedVector2Array([(a0 + o).round(), (fim + o).round(), (fim - o).round(), (a0 - o).round()]), Color(c.r, c.g, c.b, 0.22 + 0.2 * pisca)
			)
			no.draw_polyline(
				PackedVector2Array([(a0 + o).round(), (a1 + o).round(), (a1 - o).round(), (a0 - o).round(), (a0 + o).round()]),
				Color(1.0, 0.9, 0.8, 0.5 + 0.4 * pisca),
				1.5
			)


func _g2w(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * ACHATA)
