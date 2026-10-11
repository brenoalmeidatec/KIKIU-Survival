extends RefCounted
## Raio (#65, arma global): cai do céu em inimigos sorteados na tela e machuca numa área pequena em volta.
## "cadeia" (evolução): o raio pula pra até N inimigos perto, com 70% do dano a cada pulo.
## Atributos: quantidade, dano, raio, cadeia, area. Módulo de comportamento de arma (veja armas.gd e pistolas.gd).

const VIDA := 0.18  # quanto tempo o risco do raio fica na tela
const Cresc := preload("res://scripts/hordas/crescimento.gd")
const COR := Color(0.6, 0.85, 1.0)


static func atualizar(w, a: Dictionary, d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.2, float(s.recarga))
	var c: Vector2 = w.dono.centro()
	var corr: Dictionary = s.get("comp", {}).get("corrente_raio", {})  # fusão Chuva de Estrelas: o raio salta em corrente
	var caiu := false
	# direcional (#126): o primeiro raio cai onde o jogador aponta (no inimigo mais alinhado, ou 130 px à frente); os outros seguem sorteados
	var mira: Dictionary = w.mirar_alvo(c, 300.0, d)
	for i in int(s.quantidade):
		var r := float(s.get("raio", 18)) * float(s.area)
		if i == 0 and not mira.is_empty():
			var onde: Vector2 = mira.alvo if mira.alvo != null else c + mira.dir * 130.0
			_cair(
				w,
				onde,
				float(s.dano),
				r,
				int(s.get("cadeia", 0)) + int(corr.get("saltos", 0)),
				a.id,
				[],
				onde + Vector2(randf_range(-30, 30), -360),
				float(corr.get("alcance", 110.0)),
				float(corr.get("dano_mult", 0.7))
			)
			caiu = true
			continue
		var alvo = w.campo.aleatorio_na_tela(c)
		if alvo == null:
			break
		_cair(
			w,
			alvo.pos,
			float(s.dano),
			r,
			int(s.get("cadeia", 0)) + int(corr.get("saltos", 0)),
			a.id,
			[alvo.id],
			alvo.pos + Vector2(randf_range(-30, 30), -360),
			float(corr.get("alcance", 110.0)),
			float(corr.get("dano_mult", 0.7))
		)
		caiu = true
	if caiu:
		Som.tocar("tremor", 0.1, 1.9, -12)


## Machuca em volta de p e desenha o risco de "de" até p; com cadeia, pula pro vizinho mais perto que ainda não levou.
static func _cair(w, p: Vector2, dano: float, r: float, cadeia: int, arma: String, ja: Array, de: Vector2, alc := 110.0, mult := 0.7) -> void:
	for v in w.campo.no_circulo(p, r):
		w.campo.ferir(v, dano, Vector2.ZERO, arma)
	w.especiais.append({"tipo": "raio", "pos": p, "de": de, "t": VIDA, "r": r, "semente": randf() * 100.0})
	if cadeia <= 0:
		return
	var prox = null
	var md := alc * alc
	for o in w.campo.no_circulo(p, alc):
		var dd: float = o.pos.distance_squared_to(p)
		if not o.id in ja and dd < md:
			md = dd
			prox = o
	if prox:
		ja.append(prox.id)
		_cair(w, prox.pos, dano * mult, r * 0.85, cadeia - 1, arma, ja, p, alc, mult)


static func passo(w, e: Dictionary, dt: float) -> bool:
	if not e.get("fez", false):  # no instante da queda: faíscas e um tremorzinho, mais fortes a cada tier
		e["fez"] = true
		var t: int = e.get("tier", 0)
		Cresc.fagulhas(w, e.pos, Vector2.ZERO, COR, t, 190.0)
		if t >= 3:
			Cresc.acerto(w, 0.35, t)
	e.t -= dt
	return e.t > 0


static func pintar(w, e: Dictionary) -> void:
	var f: float = e.t / VIDA
	var pts := PackedVector2Array()
	var n := 7
	for k in n + 1:
		var q: Vector2 = e.de.lerp(e.pos, k / float(n))
		if k > 0 and k < n:  # zigue-zague fixo por raio (a semente), sem sortear a cada quadro
			q += Vector2(sin(e.semente + k * 7.3) * 7.0, cos(e.semente * 1.7 + k * 3.1) * 4.0)
		pts.append(q.floor())
	var t: int = e.get("tier", 0)
	var g := Cresc.grossura(t)
	w.draw_polyline(pts, Color(Cresc.cor(Color(0.55, 0.8, 1.0), t), 0.55 * f), 4.0 * g)
	w.draw_polyline(pts, Color(1, 1, 1, f), 1.5 * (1.0 + 0.4 * floorf(t / 2.0)))
	w.draw_circle(e.pos.floor(), e.r * (1.3 - 0.3 * f), Color(0.6, 0.85, 1.0, 0.25 * f))
	if Cresc.fx(t).arco_extra and Cresc.fator() >= 0.5:  # tier alto: segundo traço trêmulo ao lado e anel de choque
		var pts2 := PackedVector2Array()
		for p in pts:
			pts2.append(p + Vector2(3.0, 0.0))
		w.draw_polyline(pts2, Color(1, 1, 1, 0.45 * f), 1.0)
		Cresc.anel(w, e.pos, e.r * (1.3 - 0.3 * f), COR, t, f, 0.8)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
