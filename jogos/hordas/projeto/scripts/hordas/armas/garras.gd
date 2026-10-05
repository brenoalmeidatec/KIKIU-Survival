extends RefCounted
## Garras (forma de dragão, seção 9): as patas rasgam os vírus perto do corpo. Cada ataque acerta em volta da
## cabeça e de cada par de patas da corrente (quantidade = quantos pontos do corpo atacam), com 3 riscos dourados.
## Atributos: dano, recarga, raio, quantidade. Módulo de comportamento de arma (veja armas.gd e katana.gd).

const DUR := 0.16
const OURO := Color("eccb7a")
const PECAS_PATAS := [1, 5, 0, 3]   # índices em dragao.pecas(): patas da frente, de trás, cabeça, meio do corpo


static func _pontos(w, n: int) -> Array:
	var f = w.dono.get("forma")
	if f == null:
		return [w.dono.centro()]
	var pc: Array = f.pecas()
	var res := []
	for i in PECAS_PATAS:
		if res.size() >= n:
			break
		if i < pc.size():
			res.append(pc[i].chao - Vector2(0, pc[i].alt * 0.5))
	return res


static func atualizar(w, a: Dictionary, _d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.25, float(s.recarga))
	var raio := float(s.get("raio", 30)) * float(s.area)
	var acertou := false
	for p in _pontos(w, int(s.quantidade)):
		var alvos: Array = w.campo.no_circulo(p, raio)
		if alvos.is_empty():
			continue
		acertou = true
		for v in alvos:
			w.campo.ferir(v, float(s.dano), (v.pos - p).normalized() * 90.0, a.id)
		w.especiais.append({"tipo": "garras", "pos": p, "ang": (alvos[0].pos - p).angle() + PI / 2, "r": raio, "t": DUR})
	if acertou:
		Som.tocar("soco", 0.06, 0.7, -6)


static func passo(_w, e: Dictionary, dt: float) -> bool:
	e.t -= dt
	return e.t > 0


static func pintar(w, e: Dictionary) -> void:
	var f: float = e.t / DUR
	var d := Vector2.from_angle(e.ang)
	var n := d.orthogonal()
	for k in 3:
		var c: Vector2 = e.pos + n * (k - 1) * 5.0
		var a: Vector2 = c - d * e.r * 0.7 * (1.2 - f)
		var b: Vector2 = c + d * e.r * 0.7
		w.draw_line(a.floor(), b.floor(), Color(OURO, f), 2.0)
		w.draw_line(a.floor(), b.floor(), Color(1, 1, 1, f), 1.0)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
