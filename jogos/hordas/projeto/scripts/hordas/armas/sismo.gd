extends RefCounted
## Martelo Sísmico (#65, arma global): bate o martelo no chão e solta uma onda de choque que cresce em volta do herói,
## machucando cada inimigo uma vez quando passa e empurrando forte. "ondas" (evolução): mais de uma onda seguida, e
## "lentidao" deixa os atingidos lentos. Atributos: dano, raio, empurra, ondas, lentidao, area.
## Módulo de comportamento de arma (veja armas.gd e pistolas.gd).

const CRESCE := 0.35   # tempo da onda ir do herói até o raio


static func atualizar(w, a: Dictionary, _d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.5, float(s.recarga))
	for k in int(s.get("ondas", 1)):
		w.especiais.append({"tipo": "sismo", "espera": k * 0.28, "t": 0.0, "raio": float(s.get("raio", 85)) * float(s.area),
			"dano": float(s.dano), "empurra": float(s.get("empurra", 260)), "lento": float(s.get("lentidao", 0.0)),
			"acertou": [], "arma": a.id, "centro": Vector2.ZERO, "saiu": false})
	w.golpe_corpo()


static func passo(w, e: Dictionary, dt: float) -> bool:
	if e.espera > 0:
		e.espera -= dt
		return true
	if not e.saiu:   # a onda nasce onde o herói está quando o martelo bate
		e.saiu = true
		e.centro = w.dono.centro()
		Som.tocar("tremor", 0.1, 0.8, -6)
	e.t += dt
	var f: float = e.t / CRESCE
	if f >= 1.0:
		return false
	var r: float = 10.0 + (e.raio - 10.0) * f
	for v in w.campo.no_circulo(e.centro, r):
		if v.id in e.acertou:
			continue
		e.acertou.append(v.id)
		if e.lento > 0:
			v.lento = e.lento
		w.campo.ferir(v, e.dano, (v.pos - e.centro).normalized() * e.empurra, e.arma)
	return true


static func pintar(w, e: Dictionary) -> void:
	if e.espera > 0 or not e.saiu:
		return
	var f: float = e.t / CRESCE
	var r: float = 10.0 + (e.raio - 10.0) * f
	var p: Vector2 = e.centro.floor()
	w.draw_set_transform(p, 0, Vector2(1, 0.6))   # anel achatado: a onda corre pelo chão
	w.draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(0.75, 0.62, 0.45, 0.85 * (1.0 - f)), 3.0)
	w.draw_arc(Vector2.ZERO, r * 0.85, 0, TAU, 32, Color(0.45, 0.36, 0.26, 0.6 * (1.0 - f)), 2.0)
	w.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
