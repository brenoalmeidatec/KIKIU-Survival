extends Node2D
## Vida do cenário (#32 item 2): detalhes de chão (rachaduras, manchas, poças, folhas...), partículas ambientes com teto
## baixo (poeira, cinzas, névoa, vaga-lumes, chuva fina) e bichos (ratos, morcegos, corvos) que fogem do herói.
## Tudo é desenho barato (primitivas no _draw, sem nó por partícula) e só visual: nada tem colisão nem muda o jogo.
## O que existe e onde vem de Cenario.celula() (semente da corrida); o que cada cenário tem vem de dados/cenarios.json.

const Cenario := preload("res://scripts/hordas/cenario.gd")
const MAX_PARTICULAS := 70        # teto de partículas ambientes somando todos os tipos
const DOMINIO := Vector2(704, 424)   # as partículas dão a volta nesta área (tela 640x360 + folga)
const BICHO := {   # velocidade de fuga (px/s) e quanto tempo até sumir (s)
	"rato": {"vel": 150.0, "dura": 1.8, "sobe": 0.0},
	"morcego": {"vel": 90.0, "dura": 2.4, "sobe": 80.0},
	"corvo": {"vel": 110.0, "dura": 2.4, "sobe": 55.0},
}

var arena: Node
var cen = null                    # Cenario
var _sob := Node2D.new()          # detalhes de chão e bichos: por baixo dos enfeites (o chão é show_behind_parent)
var _alto := Node2D.new()         # partículas: por cima de tudo, bem fracas
var _part: Array = []             # {tipo, q, v, par, ph, r, cor}
var _vis: Array = []              # células na tela (muda só quando a câmera passa pra outra célula)
var _a := Vector2i(1 << 30, 0)
var _b := Vector2i.ZERO
static var _tex_nevoa: ImageTexture
var _t := 0.0
var _cam := Vector2.ZERO


func _ready() -> void:
	_sob.show_behind_parent = true
	_sob.draw.connect(_desenhar_sob)
	add_child(_sob)
	_alto.z_index = 70
	_alto.draw.connect(_desenhar_alto)
	add_child(_alto)


## Cenário novo da fase: refaz as partículas dele (visual só: sorteio local, não precisa ser igual entre jogadores).
func configurar(c, a: Node) -> void:
	cen = c
	arena = a
	_part.clear()
	_vis.clear()
	_a = Vector2i(1 << 30, 0)
	if c == null:
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash("amb|" + c.nome)
	for e in c.cfg.get("particulas", []):
		var cor: Array = e.get("cor", [1, 1, 1, 0.4])
		for i in int(e.get("n", 0)):
			if _part.size() >= MAX_PARTICULAS:
				return
			_part.append(_nova(str(e.tipo), r, Color(cor[0], cor[1], cor[2], cor[3])))


static func _nova(tipo: String, r: RandomNumberGenerator, cor: Color) -> Dictionary:
	var p := {"tipo": tipo, "q": Vector2(r.randf() * DOMINIO.x, r.randf() * DOMINIO.y), "v": Vector2.ZERO, "par": r.randf_range(0.85, 1.15),
		"ph": r.randf() * TAU, "r": 1.0, "cor": cor}
	match tipo:
		"poeira":
			p.v = Vector2(r.randf_range(-3.0, 3.0), r.randf_range(-4.0, 1.0))
		"cinza":
			p.v = Vector2(r.randf_range(-3.0, 4.0), r.randf_range(10.0, 22.0))
		"nevoa":
			p.v = Vector2(r.randf_range(4.0, 9.0), r.randf_range(-1.0, 1.0))
			p.r = r.randf_range(46.0, 80.0)
			p.par = r.randf_range(0.5, 0.8)
		"vagalume":
			p.v = Vector2(r.randf_range(-4.0, 4.0), r.randf_range(-3.0, 3.0))
		"chuva":
			p.v = Vector2(-34.0, 230.0) * r.randf_range(0.9, 1.15)
			p.par = 1.0
	return p


func atualizar(dt: float) -> void:
	_t += dt
	if cen == null or arena == null:
		return
	_cam = arena.camera.position
	var jp: Vector2 = arena.jogador.position
	var a := Vector2i(floori((_cam.x - 380.0) / Cenario.CEL), floori((_cam.y - 260.0) / Cenario.CEL))
	var b := Vector2i(floori((_cam.x + 380.0) / Cenario.CEL), floori((_cam.y + 260.0) / Cenario.CEL))
	var fuga := float(cen.cfg.get("vida", {}).get("fuga", 70.0))
	var sujo := a != _a or b != _b   # só redesenha o chão quando entra célula nova ou tem bicho se mexendo (polígonos custam)
	if sujo:
		_a = a
		_b = b
		_vis.clear()
	var parados := 0
	var fugindo := 0
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var c: Dictionary = cen.celula(cx, cy)
			if sujo:
				_vis.append(c)
			for bi in c.bichos:
				var antes: int = bi.estado
				_mexer(bi, jp, fuga, dt)
				if bi.estado == 1:
					fugindo += 1
				elif bi.estado == 0:
					parados += 1
				if bi.estado != antes:
					sujo = true
	if sujo or fugindo > 0 or (parados > 0 and Engine.get_process_frames() % 4 == 0):
		_sob.queue_redraw()
	_alto.queue_redraw()


## O bicho fica parado até o herói chegar perto; aí foge pra longe dele (e voa, se tiver asa) e some.
func _mexer(b: Dictionary, jp: Vector2, fuga: float, dt: float) -> void:
	if b.estado == 2:
		return
	var cfg: Dictionary = BICHO[b.tipo]
	if b.estado == 0:
		var d: Vector2 = b.pos - jp
		if d.length_squared() < fuga * fuga:
			b.estado = 1
			b.t = 0.0
			b.dir = d.normalized() if d.length() > 1.0 else Vector2.from_angle(b.ph)
			b.lado = 1.0 if b.dir.x >= 0.0 else -1.0
		return
	b.t += dt
	var arranque := 0.12 if b.tipo != "corvo" else 0.35   # corvo dá uma olhada antes de voar
	if b.t > arranque:
		b.pos += b.dir * float(cfg.vel) * dt
		b.alt += float(cfg.sobe) * dt
	if b.t > float(cfg.dura):
		b.estado = 2


# ---------------------------------------------------------------- desenho: chão e bichos

func _desenhar_sob() -> void:
	if cen == null:
		return
	for c in _vis:
		for d in c.detalhes:
			_detalhe(d)
	for c in _vis:
		for b in c.bichos:
			if b.estado != 2:
				_bicho(b)


func _detalhe(d: Dictionary) -> void:
	var cor: Color = d.cor
	var p: Vector2 = d.pos
	var pts: PackedVector2Array = d.pts
	match d.tipo:
		"rachadura":
			_sob.draw_polyline(_mover(pts, p + Vector2(1, 1)), Color(1, 1, 1, cor.a * 0.12), 1.0)   # beiral claro embaixo
			_sob.draw_polyline(_mover(pts, p), cor, 1.0)
		"cabo":
			_sob.draw_polyline(_mover(pts, p), cor, 2.0)
			_sob.draw_rect(Rect2(p + pts[pts.size() - 1] - Vector2(2, 1.5), Vector2(4, 3)), Color(cor.r * 2.0, cor.g * 2.0, cor.b * 2.0, cor.a))
		"mancha":
			_sob.draw_colored_polygon(_mover(pts, p), cor)
			_sob.draw_colored_polygon(_mover(_escala(pts, 0.55), p), Color(cor.r * 0.6, cor.g * 0.6, cor.b * 0.6, cor.a * 0.8))
		"poca":
			var f := _mover(pts, p)
			_sob.draw_colored_polygon(f, cor)
			f.append(f[0])
			_sob.draw_polyline(f, Color(0.75, 0.85, 1.0, 0.16), 1.0)
			_sob.draw_line(p + Vector2(-4, -1), p + Vector2(1, -1.5), Color(0.9, 0.95, 1.0, 0.2), 1.0)   # reflexo
		"folha":
			for i in pts.size():
				var q: Vector2 = p + pts[i]
				var tom := 0.75 + 0.25 * float((d.k >> i) & 1)
				_sob.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -2), q + Vector2(2, 0), q + Vector2(0, 2), q + Vector2(-2, 0)]),
					Color(cor.r * tom, cor.g * tom, cor.b * tom, cor.a))
		"papel":
			var u: Vector2 = pts[0]
			var w: Vector2 = pts[1]
			_sob.draw_colored_polygon(PackedVector2Array([p - u - w, p + u - w, p + u + w, p - u + w]), cor)
			_sob.draw_line(p - u * 0.5, p + u * 0.6, Color(0, 0, 0, cor.a * 0.5), 1.0)


## Mancha redonda e macia (alfa que cai do centro pra borda): uma textura só pra todas as névoas, 1 desenho cada.
static func _textura_nevoa() -> ImageTexture:
	if _tex_nevoa == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := clampf(Vector2(x - 15.5, y - 15.5).length() / 16.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, pow(1.0 - d, 1.6)))
		_tex_nevoa = ImageTexture.create_from_image(img)
	return _tex_nevoa


static func _mover(pts: PackedVector2Array, p: Vector2) -> PackedVector2Array:
	var r := PackedVector2Array()
	for q in pts:
		r.append(q + p)
	return r


static func _escala(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var r := PackedVector2Array()
	for q in pts:
		r.append(q * k)
	return r


## Bichos: pixel art desenhada com retângulos, escuros e pequenos (não competem com herói e vírus).
func _bicho(b: Dictionary) -> void:
	var fuga: bool = b.estado == 1
	var a := 1.0 if not fuga else clampf((float(BICHO[b.tipo].dura) - b.t) * 3.0, 0.0, 1.0)
	var p: Vector2 = b.pos
	var l: float = b.lado
	var tic: float = _t * 14.0 + b.ph
	_sob.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(0, -1.5), p + Vector2(4, 0), p + Vector2(0, 1.5)]), Color(0, 0, 0, 0.22 * a))
	match b.tipo:
		"rato":
			var cor := Color(0.3, 0.26, 0.27, a)
			var pe := 0.0 if not fuga else sin(tic * 1.6)
			_sob.draw_rect(Rect2(p + Vector2(-3, -3.5), Vector2(6, 3)), cor)
			_sob.draw_rect(Rect2(p + Vector2(3.0 * l - (0.0 if l > 0 else 2.0), -3), Vector2(2, 2)), cor)   # cabeça
			_sob.draw_rect(Rect2(p + Vector2(2.0 * l - 0.5, -4.5), Vector2(1, 1)), Color(0.42, 0.26, 0.3, a))   # orelha
			_sob.draw_line(p + Vector2(-3 * l, -2.5), p + Vector2(-7 * l, -2.5 + sin(_t * 5.0 + b.ph) * 1.5 + pe), Color(0.34, 0.24, 0.26, a), 1.0)   # rabo
			if fuga:
				_sob.draw_rect(Rect2(p + Vector2(-2 + pe * 1.5, -0.5), Vector2(1, 1)), cor)
				_sob.draw_rect(Rect2(p + Vector2(1 - pe * 1.5, -0.5), Vector2(1, 1)), cor)
		"morcego":
			var cor := Color(0.15, 0.11, 0.2, a)
			if not fuga:   # dormindo: asas dobradas
				_sob.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -1), p + Vector2(0, -6), p + Vector2(3, -1)]), cor)
			else:
				var q := p + Vector2(0, -3.0 - b.alt)
				var bat := sin(tic * 2.2) * 3.5
				_sob.draw_rect(Rect2(q + Vector2(-1.5, -1.5), Vector2(3, 3)), cor)
				for s in [-1.0, 1.0]:
					_sob.draw_colored_polygon(PackedVector2Array([q + Vector2(s * 1.5, -1), q + Vector2(s * 8.0, -3.5 + bat), q + Vector2(s * 6.0, 1.0), q + Vector2(s * 3.0, 0.5)]), cor)
		"corvo":
			var cor := Color(0.07, 0.07, 0.11, a)
			if not fuga or b.t < 0.35:   # parado, bicando o chão
				var bico := absf(sin(_t * 2.0 + b.ph)) * 1.5 if not fuga else 0.0
				_sob.draw_rect(Rect2(p + Vector2(-3, -6), Vector2(6, 4)), cor)
				_sob.draw_rect(Rect2(p + Vector2(2.0 * l - 1.0 + (1.0 if l > 0 else -1.0), -7 + bico), Vector2(2, 2)), cor)
				_sob.draw_rect(Rect2(p + Vector2(4.0 * l - (0.0 if l > 0 else 1.0), -6 + bico), Vector2(2, 1)), Color(0.4, 0.3, 0.16, a))
				_sob.draw_line(p + Vector2(-1, -2), p + Vector2(-1, 0), cor, 1.0)
				_sob.draw_line(p + Vector2(1, -2), p + Vector2(1, 0), cor, 1.0)
			else:
				var q := p + Vector2(0, -5.0 - b.alt)
				var bat := sin(tic * 1.6) * 5.0
				_sob.draw_rect(Rect2(q + Vector2(-3, -1.5), Vector2(6, 3)), cor)
				_sob.draw_rect(Rect2(q + Vector2(3.0 * l - (0.0 if l > 0 else 2.0), -2.5), Vector2(2, 2)), cor)
				for s in [-1.0, 1.0]:
					_sob.draw_colored_polygon(PackedVector2Array([q + Vector2(s * 1.0, -1), q + Vector2(s * 4.0, -6.0 + bat), q + Vector2(s * 8.0, -3.0 + bat), q + Vector2(s * 4.0, 1.5)]), cor)


# ---------------------------------------------------------------- desenho: partículas

func _desenhar_alto() -> void:
	if cen == null or _part.is_empty() or arena == null:
		return
	var origem := _cam - DOMINIO * 0.5
	for p in _part:
		var q: Vector2 = p.q + p.v * _t
		var x := fposmod(q.x - _cam.x * p.par + DOMINIO.x * 0.5, DOMINIO.x)
		var y := fposmod(q.y - _cam.y * p.par + DOMINIO.y * 0.5, DOMINIO.y)
		var pos := origem + Vector2(x, y)
		var cor: Color = p.cor
		match p.tipo:
			"poeira":
				pos += Vector2(sin(_t * 0.7 + p.ph) * 3.0, cos(_t * 0.5 + p.ph) * 2.0)
				_alto.draw_rect(Rect2(pos, Vector2.ONE), Color(cor, cor.a * (0.45 + 0.55 * sin(_t * 1.3 + p.ph) * sin(_t * 1.3 + p.ph))))
			"cinza":
				pos.x += sin(_t * 1.2 + p.ph) * 5.0
				var g := 1.0 + float(int(p.ph * 3.0) % 2)
				_alto.draw_rect(Rect2(pos, Vector2(g, g)), Color(cor, cor.a * (0.6 + 0.4 * sin(_t * 3.0 + p.ph))))
			"nevoa":
				_alto.draw_texture_rect(_textura_nevoa(), Rect2(pos - Vector2(p.r, p.r), Vector2(p.r, p.r) * 2.0), false, Color(cor, cor.a * 3.0))
			"vagalume":
				pos += Vector2(sin(_t * 0.9 + p.ph) * 14.0, cos(_t * 0.7 + p.ph * 2.0) * 9.0)
				var luz := clampf(0.5 + 0.7 * sin(_t * 2.1 + p.ph), 0.0, 1.0)
				_alto.draw_circle(pos, 3.0, Color(cor, 0.12 * luz))
				_alto.draw_rect(Rect2(pos - Vector2(0.5, 0.5), Vector2(1.5, 1.5)), Color(cor, cor.a * luz))
			"chuva":
				_alto.draw_line(pos, pos + Vector2(-1.2, 5.0), cor, 1.0)
