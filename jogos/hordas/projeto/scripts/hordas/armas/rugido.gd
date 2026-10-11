extends RefCounted
## Rugido do Dragão (forma de dragão, seção 9): o dragão ruge (boca aberta) e solta uma ONDA de energia que se
## espalha pelo chão: machuca, empurra e atordoa os vírus mais fracos (chefe e elite só ficam lentos).
## Atributos: dano, recarga, raio, empurra, atordoa (segundos). Módulo de comportamento de arma (veja armas.gd).

const DUR := 0.5
const COBALTO := Color(0.25, 0.45, 1.0)
const CIANO := Color(0.55, 0.85, 1.0)


static func atualizar(w, a: Dictionary, _d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	var c: Vector2 = w.dono.position
	# só ruge com gente por perto (não desperdiça no vazio)
	if w.campo.no_circulo(c, float(s.get("raio", 110)) * float(s.area) * 0.8).size() < 3:
		a.t = 0.3
		return
	a.t = maxf(1.5, float(s.recarga))
	w.especiais.append(
		{
			"tipo": "rugido",
			"boca": true,
			"pos": c,
			"t": DUR,
			"r": 0.0,
			"rmax": float(s.get("raio", 110)) * float(s.area),
			"dano": float(s.dano),
			"empurra": float(s.get("empurra", 260)),
			"atordoa": float(s.get("atordoa", 1.2)),
			"acertou": [],
			"arma": a.id
		}
	)
	Som.tocar("tremor", 0.2, 0.45, 0)
	w.arena.tremer(5.0)


static func passo(w, e: Dictionary, dt: float) -> bool:
	e.t -= dt
	e.boca = e.t > DUR * 0.4
	e.r = e.rmax * (1.0 - e.t / DUR)
	for v in w.campo.no_circulo(e.pos, e.r):
		if v.id in e.acertou:
			continue
		e.acertou.append(v.id)
		w.campo.ferir(v, e.dano, (v.pos - e.pos).normalized() * e.empurra, e.arma)
		if v.chefe or v.elite:
			v.lento = maxf(v.lento, e.atordoa)
		else:
			v.atordoado = maxf(v.atordoado, e.atordoa)
	return e.t > 0


static func pintar(w, e: Dictionary) -> void:
	var f: float = e.t / DUR
	# onda no chão (elipse em perspectiva, como o anel da aura), com um eco por dentro
	w.draw_set_transform(e.pos.floor(), 0.0, Vector2(1.0, 0.5))
	w.draw_arc(Vector2.ZERO, e.r, 0, TAU, 40, Color(CIANO, f), 3.0)
	w.draw_arc(Vector2.ZERO, e.r - 4.0, 0, TAU, 40, Color(1, 1, 1, f * 0.7), 1.0)
	w.draw_arc(Vector2.ZERO, e.r * 0.7, 0, TAU, 32, Color(COBALTO, f * 0.6), 2.0)
	w.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
