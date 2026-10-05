extends Node2D
## Números de dano e partículas (pedacinhos quando um vírus explode).

const MAX_NUMEROS := 70
const MAX_PARTICULAS := 400

var numeros: Array = []      # {pos, txt, t, cor}
var particulas: Array = []   # {pos, vel, t, cor, tam}


func numero(pos: Vector2, valor: float, cor := Color.WHITE) -> void:
	if numeros.size() >= MAX_NUMEROS:
		numeros.pop_front()
	numeros.append({"pos": pos + Vector2(randf_range(-6, 6), -10), "txt": str(int(round(valor))), "t": 0.6, "cor": cor})


func explodir(pos: Vector2, cor: Color, n := 6, forca := 80.0) -> void:
	for i in n:
		if particulas.size() >= MAX_PARTICULAS:
			particulas.pop_front()
		particulas.append({"pos": pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(forca * 0.3, forca),
			"t": randf_range(0.25, 0.5), "cor": cor, "tam": randf_range(2, 4)})


func limpar() -> void:
	numeros.clear()
	particulas.clear()


func atualizar(dt: float) -> void:
	for n in numeros.duplicate():
		n.t -= dt
		n.pos.y -= 24 * dt
		if n.t <= 0:
			numeros.erase(n)
	for p in particulas.duplicate():
		p.t -= dt
		p.pos += p.vel * dt
		p.vel *= exp(-5 * dt)
		if p.t <= 0:
			particulas.erase(p)
	queue_redraw()


func _draw() -> void:
	for p in particulas:
		draw_rect(Rect2(p.pos, Vector2(p.tam, p.tam)), Color(p.cor, clampf(p.t * 3, 0, 1)))
	var f: Font = Dados.fonte
	for n in numeros:
		var a := clampf(n.t * 3.0, 0.0, 1.0)
		draw_string(f, n.pos + Vector2(1, 1), n.txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0, 0, 0, a))
		draw_string(f, n.pos, n.txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(n.cor, a))
