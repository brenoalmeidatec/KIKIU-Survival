extends RefCounted
## Runas Explosivas (#65, arma global): risca runas no chão em volta do herói; armam em 0,4 s e explodem quando um
## inimigo pisa, machucando e empurrando em volta. Somem depois de "duracao" s. "lentidao" (evolução): a explosão deixa
## os inimigos lentos. Atributos: quantidade, dano, duracao, raio (gatilho), explosao (raio do estouro), area.
## Módulo de comportamento de arma (veja armas.gd e pistolas.gd).

const ARMA := 0.4    # tempo até a runa armar
const BOOM := 0.25   # duração do estouro na tela


static func atualizar(w, a: Dictionary, d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.4, float(s.recarga))
	var c: Vector2 = w.dono.centro()
	for i in int(s.quantidade):
		var p: Vector2 = c + Vector2.from_angle(randf() * TAU) * randf_range(36.0, 120.0)
		w.especiais.append({"tipo": "runas", "pos": p, "vida": float(s.duracao), "arma_t": ARMA, "boom": -1.0,
			"gatilho": float(s.get("raio", 16)) * float(s.area), "explosao": float(s.get("explosao", 42)) * float(s.area),
			"dano": float(s.dano), "lento": float(s.get("lentidao", 0.0)), "arma": a.id, "giro": randf() * TAU,
			"cor": Color(1.0, 0.55, 0.9) if bool(d.get("evolucao", false)) else Color(0.95, 0.75, 0.35)})
	Som.tocar("queda", 0.1, 1.6, -14)


static func passo(w, e: Dictionary, dt: float) -> bool:
	if e.boom >= 0:   # estourando
		e.boom -= dt
		return e.boom > 0
	e.vida -= dt
	if e.vida <= 0:
		return false
	if e.arma_t > 0:
		e.arma_t -= dt
		return true
	if not w.campo.no_circulo(e.pos, e.gatilho).is_empty():
		e.boom = BOOM
		for v in w.campo.no_circulo(e.pos, e.explosao):
			if e.lento > 0:
				v.lento = e.lento
			w.campo.ferir(v, e.dano, (v.pos - e.pos).normalized() * 200.0, e.arma)
		Som.tocar("soco", 0.06, 0.7, -8)
	return true


static func pintar(w, e: Dictionary) -> void:
	var p: Vector2 = e.pos.floor()
	if e.boom >= 0:
		var f: float = e.boom / BOOM
		w.draw_circle(p, e.explosao * (1.15 - 0.5 * f), Color(e.cor, 0.3 * f))
		w.draw_arc(p, e.explosao * (1.15 - 0.5 * f), 0, TAU, 24, Color(e.cor.lightened(0.4), f), 2.0)
		return
	# runa no chão: círculo achatado (perspectiva) com um traço em X; pisca devagar quando armada
	var armada: bool = e.arma_t <= 0
	var a: float = (0.55 + 0.3 * sin(e.vida * 6.0)) if armada else 0.3
	var r: float = e.gatilho
	w.draw_set_transform(p, 0, Vector2(1, 0.55))
	w.draw_arc(Vector2.ZERO, r, 0, TAU, 18, Color(e.cor, a), 1.5)
	var k := Vector2.from_angle(e.giro) * r * 0.6
	w.draw_line(-k, k, Color(e.cor, a), 1.5)
	w.draw_line(-k.orthogonal(), k.orthogonal(), Color(e.cor, a), 1.5)
	w.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
