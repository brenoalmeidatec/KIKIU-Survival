extends RefCounted
## Energia Dracônica (forma de dragão, seção 9): orbes de energia cobalto que saem da boca, voam até o vírus
## e EXPLODEM em área. Atributos: dano, recarga, quantidade (orbes por vez), velocidade, explosao (raio).
## Módulo de comportamento de arma (veja armas.gd e katana.gd).

const COBALTO := Color(0.25, 0.45, 1.0)
const CIANO := Color(0.55, 0.85, 1.0)
const BOOM := 0.28
const Baforada := preload("res://scripts/hordas/armas/baforada.gd")


static func atualizar(w, a: Dictionary, _d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.3, float(s.recarga))
	var b: Vector2 = Baforada.boca(w)  # sai da boca do dragão
	var alvos: Array = w.campo.n_mais_perto(b, int(s.quantidade), 340)
	if alvos.is_empty():
		a.t = 0.2
		return
	for i in alvos.size():
		var dir: Vector2 = (alvos[i].pos - b).normalized().rotated(randf_range(-0.25, 0.25))
		w.especiais.append(
			{
				"tipo": "energia_draconica",
				"pos": b,
				"vel": dir * float(s.velocidade),
				"alvo": alvos[i],
				"vida": 1.4,
				"dano": float(s.dano),
				"raio": float(s.get("explosao", 30)) * float(s.area),
				"boom": 0.0,
				"rastro": [],
				"arma": a.id
			}
		)
	Som.tocar("blip", 0.08, 0.6, -6)


static func passo(w, e: Dictionary, dt: float) -> bool:
	if e.boom > 0:
		e.boom -= dt
		return e.boom > 0
	# persegue o alvo enquanto ele existe (curva suave: parece energia guiada, não bala)
	if e.alvo and e.alvo.hp > 0:
		var quer: Vector2 = (e.alvo.pos - e.pos).normalized() * e.vel.length()
		e.vel = e.vel.lerp(quer, minf(1.0, dt * 5.0))
	e.rastro.push_front(e.pos)
	if e.rastro.size() > 6:
		e.rastro.pop_back()
	e.pos += e.vel * dt
	e.vida -= dt
	if e.vida <= 0 or not w.campo.no_circulo(e.pos, 6.0).is_empty():
		e.boom = BOOM
		for v in w.campo.no_circulo(e.pos, e.raio):
			w.campo.ferir(v, e.dano, (v.pos - e.pos).normalized() * 120.0, e.arma)
		Som.tocar("acerto", 0.05, 0.6, -6)
	return true


static func pintar(w, e: Dictionary) -> void:
	if e.boom > 0:
		var f: float = e.boom / BOOM
		w.draw_circle(e.pos.floor(), e.raio * (1.0 - f * 0.5), Color(COBALTO, 0.3 * f))
		w.draw_arc(e.pos.floor(), e.raio * (1.0 - f * 0.3), 0, TAU, 24, Color(CIANO, f), 2.0)
		w.draw_arc(e.pos.floor(), e.raio * (1.0 - f * 0.3) - 3.0, 0, TAU, 24, Color(1, 1, 1, f * 0.7), 1.0)
		return
	for i in e.rastro.size():
		var k: float = 1.0 - float(i) / e.rastro.size()
		w.draw_circle(e.rastro[i].floor(), 3.0 * k, Color(COBALTO, 0.5 * k))
	w.draw_circle(e.pos.floor(), 5.0, Color(COBALTO, 0.6))
	w.draw_circle(e.pos.floor(), 3.0, CIANO)
	w.draw_rect(Rect2(e.pos.floor() - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
