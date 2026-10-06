extends Node2D
const Perf := preload("res://scripts/hordas/perf.gd")
## Números de dano e partículas (pedacinhos quando um vírus explode).

const MAX_NUMEROS := 70
const MAX_PARTICULAS := 400
## Números de dano agrupados (HoloCure / 20MTD: um número só em vez de uma chuva deles): acertos a até RAIO_JUNTA px
## de um número nascido há menos de JANELA s SOMAM nele (o número cresce e a cor de crítico vence). Com 500 vírus e
## uma arma de área isso é a diferença entre 40 textos por segundo e 6.
const JANELA := 0.15
const RAIO_JUNTA := 28.0
const VIDA := 0.6
const VIDA_CRIT := 0.9

var numeros: Array = []      # {pos, valor, txt, t, idade, cor, base, tam, crit}
var particulas: Array = []   # {pos, vel, t, cor, tam}


func numero(pos: Vector2, valor: float, cor := Color.WHITE, crit := false) -> void:
	if not Config.v("numeros_dano"):   # opção "Números de dano"
		return
	# a lista está em ordem de nascimento: só os últimos (mais novos que a janela) podem receber a soma
	for i in range(numeros.size() - 1, -1, -1):
		var n: Dictionary = numeros[i]
		if n.idade >= JANELA:
			break
		if n.base == cor:   # só soma com a mesma "família" (dano causado, dano recebido...); crítico entra na soma e pinta o total
			if n.pos.distance_to(pos) <= RAIO_JUNTA:
				n.valor += valor
				n.txt = texto(n.valor, n.crit or crit)
				if crit and not n.crit:
					n.crit = true
					n.cor = Color(1, 0.9, 0.3)
					n.tam = 16
					n.t = VIDA_CRIT
				return
	if numeros.size() >= MAX_NUMEROS:
		numeros.pop_front()
	numeros.append({"pos": pos + Vector2(randf_range(-6, 6), -10), "valor": valor, "txt": texto(valor, crit), "idade": 0.0, "crit": crit, "base": cor,
		"t": VIDA_CRIT if crit else VIDA, "cor": Color(1, 0.9, 0.3) if crit else cor, "tam": 16 if crit else 8})


static func texto(valor: float, crit: bool) -> String:
	return str(int(round(valor))) + ("!" if crit else "")


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
	var _pp := Perf.ini()
	atualizar_i(dt)
	Perf.fim("efe_a", _pp)


func atualizar_i(dt: float) -> void:
	for n in numeros.duplicate():
		n.t -= dt
		n.idade += dt
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
	var _pp := Perf.ini()
	_draw_i()
	Perf.fim("efe_d", _pp)


func _draw_i() -> void:
	for p in particulas:
		draw_rect(Rect2(p.pos, Vector2(p.tam, p.tam)), Color(p.cor, clampf(p.t * 3, 0, 1)))
	var f: Font = Dados.fonte
	for n in numeros:
		var a := clampf(n.t * 3.0, 0.0, 1.0)
		draw_string(f, n.pos + Vector2(1, 1), n.txt, HORIZONTAL_ALIGNMENT_CENTER, -1, n.tam, Color(0, 0, 0, a))
		draw_string(f, n.pos, n.txt, HORIZONTAL_ALIGNMENT_CENTER, -1, n.tam, Color(n.cor, a))
