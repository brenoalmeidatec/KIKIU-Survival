extends RefCounted
## Raio (#65, arma global): cai do céu em inimigos sorteados na tela e machuca numa área pequena em volta.
## "cadeia" (evolução): o raio pula pra até N inimigos perto, com 70% do dano a cada pulo.
## Atributos: quantidade, dano, raio, cadeia, area. Módulo de comportamento de arma (veja armas.gd e pistolas.gd).

const VIDA := 0.18   # quanto tempo o risco do raio fica na tela


static func atualizar(w, a: Dictionary, _d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.2, float(s.recarga))
	var c: Vector2 = w.dono.centro()
	var caiu := false
	for i in int(s.quantidade):
		var alvo = w.campo.aleatorio_na_tela(c)
		if alvo == null:
			break
		var r := float(s.get("raio", 18)) * float(s.area)
		_cair(w, alvo.pos, float(s.dano), r, int(s.get("cadeia", 0)), a.id, [alvo.id], alvo.pos + Vector2(randf_range(-30, 30), -360))
		caiu = true
	if caiu:
		Som.tocar("tremor", 0.1, 1.9, -12)


## Machuca em volta de p e desenha o risco de "de" até p; com cadeia, pula pro vizinho mais perto que ainda não levou.
static func _cair(w, p: Vector2, dano: float, r: float, cadeia: int, arma: String, ja: Array, de: Vector2) -> void:
	for v in w.campo.no_circulo(p, r):
		w.campo.ferir(v, dano, Vector2.ZERO, arma)
	w.especiais.append({"tipo": "raio", "pos": p, "de": de, "t": VIDA, "r": r, "semente": randf() * 100.0})
	if cadeia <= 0:
		return
	var prox = null
	var md := 110.0 * 110.0
	for o in w.campo.no_circulo(p, 110.0):
		var dd: float = o.pos.distance_squared_to(p)
		if not o.id in ja and dd < md:
			md = dd
			prox = o
	if prox:
		ja.append(prox.id)
		_cair(w, prox.pos, dano * 0.7, r * 0.85, cadeia - 1, arma, ja, p)


static func passo(_w, e: Dictionary, dt: float) -> bool:
	e.t -= dt
	return e.t > 0


static func pintar(w, e: Dictionary) -> void:
	var f: float = e.t / VIDA
	var pts := PackedVector2Array()
	var n := 7
	for k in n + 1:
		var q: Vector2 = e.de.lerp(e.pos, k / float(n))
		if k > 0 and k < n:   # zigue-zague fixo por raio (a semente), sem sortear a cada quadro
			q += Vector2(sin(e.semente + k * 7.3) * 7.0, cos(e.semente * 1.7 + k * 3.1) * 4.0)
		pts.append(q.floor())
	w.draw_polyline(pts, Color(0.55, 0.8, 1.0, 0.55 * f), 4.0)
	w.draw_polyline(pts, Color(1, 1, 1, f), 1.5)
	w.draw_circle(e.pos.floor(), e.r * (1.3 - 0.3 * f), Color(0.6, 0.85, 1.0, 0.25 * f))


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
