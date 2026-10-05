extends RefCounted
## Katana Samurai (exclusiva do Hazaki): corte em ARCO, rápido, na direção do inimigo mais perto.
## Atributos (armas.json): alcance, arco (graus), quantidade (cortes por ataque: frente, trás, lados),
## corte_energia (>0: cada corte solta uma lua de energia que voa e atravessa).
## Módulo de comportamento de arma (veja armas.gd): atualizar() dispara; cada efeito tem "tipo" e o armas.gd
## chama passo() (false = acabou) e pintar() do módulo desse tipo; fundo() desenha o que fica sempre na tela.

const DUR := 0.14          # quanto tempo o rastro do corte fica na tela
const COR := Color(0.85, 0.9, 1.0)
const BRILHO := Color(1, 1, 1)


static func atualizar(w, a: Dictionary, _d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.2, float(s.recarga))
	var c: Vector2 = w.dono.centro()
	var alcance: float = float(s.get("alcance", 70)) * float(s.area)
	var alvo = w.campo.mais_perto(c, alcance * 1.6)
	var dir: Vector2 = (alvo.pos - c).normalized() if alvo else Vector2(w.dono.lado, 0)
	var q := int(s.quantidade)
	for i in q:
		w.especiais.append({"tipo": "katana", "corte": true, "espera": i * 0.07,
			"dir": dir.rotated(TAU * i / q), "alcance": alcance, "arco": deg_to_rad(float(s.get("arco", 110))),
			"dano": float(s.dano), "energia": float(s.get("corte_energia", 0)) > 0, "t": DUR, "feito": false,
			"pos": c, "arma": a.id})


static func passo(w, e: Dictionary, dt: float) -> bool:
	if e.get("lua", false):
		return _lua(w, e, dt)
	if e.espera > 0:
		e.espera -= dt
		return true
	if not e.feito:
		e.feito = true
		e.pos = w.dono.centro()
		var ang: float = e.dir.angle()
		for v in w.campo.no_circulo(e.pos, e.alcance):
			var dif: Vector2 = v.pos - e.pos
			if absf(angle_difference(ang, dif.angle())) <= e.arco / 2 or dif.length() < 14.0:
				w.campo.ferir(v, e.dano, e.dir * 130.0, e.arma)
		Som.tocar("whoosh", 0.05, 1.9, -7)
		if e.energia:
			w.especiais.append({"tipo": "katana", "lua": true, "pos": e.pos + e.dir * 10.0, "vel": e.dir * 380.0, "vida": 0.55,
				"dano": e.dano * 0.7, "acertou": [], "arma": e.arma})
	e.t -= dt
	return e.t > 0


## Lua de energia (corte à distância): voa reto e atravessa todo mundo no caminho uma vez.
static func _lua(w, e: Dictionary, dt: float) -> bool:
	e.pos += e.vel * dt
	e.vida -= dt
	for v in w.campo.no_circulo(e.pos, 16.0):
		if not v.id in e.acertou:
			e.acertou.append(v.id)
			w.campo.ferir(v, e.dano, e.vel.normalized() * 80.0, e.arma)
	return e.vida > 0


static func pintar(w, e: Dictionary) -> void:
	if e.get("lua", false):
		var a: float = e.vel.angle()
		var alfa: float = clampf(e.vida / 0.2, 0.0, 1.0)
		w.draw_arc(e.pos.floor(), 12.0, a - 1.2, a + 1.2, 10, Color(0.55, 0.8, 1.0, alfa * 0.8), 4.0)
		w.draw_arc(e.pos.floor(), 12.0, a - 1.0, a + 1.0, 10, Color(BRILHO, alfa), 1.0)
		return
	if not e.feito:
		return
	var f: float = e.t / DUR                     # 1 no começo do corte, 0 no fim
	var ang: float = e.dir.angle()
	var r: float = e.alcance * 0.8
	# "swoosh" cheio, da mão até a ponta da lâmina: camadas mais fortes pra fora, fio branco na borda
	for k in 4:
		var rk: float = lerpf(r * 0.4, r, k / 3.0)
		w.draw_arc(e.pos.floor(), rk, ang - e.arco / 2, ang + e.arco / 2, 16, Color(COR, (0.15 + 0.15 * k) * f), r * 0.2)
	w.draw_arc(e.pos.floor(), r + r * 0.1, ang - e.arco / 2 * f, ang + e.arco / 2, 16, Color(BRILHO, 0.9 * f), 1.0)
	var ponta: Vector2 = e.pos + Vector2.from_angle(ang + e.arco / 2) * r
	w.draw_rect(Rect2(ponta.floor() - Vector2(1, 1), Vector2(3, 3)), Color(BRILHO, f))


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
