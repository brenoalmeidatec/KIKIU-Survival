extends RefCounted
## Katana Samurai (exclusiva do Hazaki): corte em ARCO, rápido, na direção do inimigo mais perto.
## Atributos (armas.json): alcance, arco (graus), quantidade (cortes por ataque: frente, trás, lados),
## corte_energia (>0: cada corte solta uma lua de energia que voa e atravessa).
## Módulo de comportamento de arma (veja armas.gd): atualizar() dispara; cada efeito tem "tipo" e o armas.gd
## chama passo() (false = acabou) e pintar() do módulo desse tipo; fundo() desenha o que fica sempre na tela.

const Cresc := preload("res://scripts/hordas/crescimento.gd")  # tier da arma: traço grosso, 2º arco, faíscas, tremor
const DUR := 0.14  # quanto tempo o rastro do corte fica na tela
const COR := Color(0.85, 0.9, 1.0)
const BRILHO := Color(1, 1, 1)
const COR_CORTE := Color(0.45, 0.7, 1.0)  # azul-aço: no aditivo vira branco no fio e azul na borda


static func atualizar(w, a: Dictionary, d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.2, float(s.recarga))
	var c: Vector2 = w.dono.centro()
	var alcance: float = float(s.get("alcance", 70)) * float(s.area)
	var mira: Array = w.mirar(c, 1, alcance * 1.6, d)  # direcional (#126): corta pra onde o jogador aponta
	var dir: Vector2
	if not mira.is_empty():
		dir = mira[0]
	else:
		var alvo = w.campo.mais_perto(c, alcance * 1.6)
		dir = (alvo.pos - c).normalized() if alvo else Vector2(w.dono.lado, 0)
	w.golpe_corpo(dir)
	a["vira"] = -float(a.get("vira", -1.0))  # golpes alternam o sentido: ida e volta, como no Dimraeth
	var q := int(s.quantidade)
	for i in q:
		w.especiais.append(
			{
				"tipo": "katana",
				"corte": true,
				"espera": i * 0.07,
				"lado": float(a.vira) * (1.0 if i % 2 == 0 else -1.0),
				"dir": dir.rotated(TAU * i / q),
				"alcance": alcance,
				"arco": deg_to_rad(float(s.get("arco", 110))),
				"dano": float(s.dano),
				"energia": float(s.get("corte_energia", 0)) > 0,
				"t": DUR,
				"feito": false,
				"pos": c,
				"arma": a.id
			}
		)


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
		var n := 0
		for v in w.campo.no_circulo(e.pos, e.alcance):
			var dif: Vector2 = v.pos - e.pos
			if absf(angle_difference(ang, dif.angle())) <= e.arco / 2 or dif.length() < 14.0:
				w.campo.ferir(v, e.dano, e.dir * 130.0, e.arma)
				n += 1
		Som.tocar("whoosh", 0.05, 1.9, -7)
		var ef = w.fx()
		var t: int = e.get("tier", 0)
		if ef:  # a meia-lua sai um pouco à frente do corpo e passa do alcance (o golpe parece maior que o herói)
			var cc: Color = Cresc.cor(COR_CORTE, t)
			ef.corte(e.pos + e.dir * 6.0, ang, e.arco * 1.15, e.alcance * 0.9, cc, e.alcance * 0.27 * Cresc.grossura(t), DUR + 0.04, e.lado)
			if Cresc.fx(t).arco_extra and Cresc.fator() >= 0.5:  # tier máximo/evoluída: segundo arco, mais fino e mais longe, logo atrás do primeiro
				ef.corte(e.pos + e.dir * 6.0, ang, e.arco * 1.3, e.alcance * 1.12, cc, e.alcance * 0.12, DUR + 0.08, e.lado)
			Cresc.fagulhas(w, e.pos + e.dir * e.alcance * 0.75, e.dir, COR_CORTE, t, 200.0)
		if n > 0:
			Cresc.acerto(w, 1.0, t)
		if e.energia:
			w.especiais.append(
				{
					"tipo": "katana",
					"lua": true,
					"pos": e.pos + e.dir * 10.0,
					"vel": e.dir * 380.0,
					"vida": 0.55,
					"dano": e.dano * 0.7,
					"acertou": [],
					"arma": e.arma
				}
			)
	e.t -= dt
	return e.t > 0


## Lua de energia (corte à distância): voa reto e atravessa todo mundo no caminho uma vez.
static func _lua(w, e: Dictionary, dt: float) -> bool:
	e.pos += e.vel * dt
	e.vida -= dt
	for v in w.campo.no_circulo(e.pos, 16.0 * e.get("area", 1.0)):
		if not v.id in e.acertou:
			e.acertou.append(v.id)
			w.campo.ferir(v, e.dano, e.vel.normalized() * 80.0, e.arma)
	return e.vida > 0


static func pintar(w, e: Dictionary) -> void:
	if e.get("lua", false):
		var a: float = e.vel.angle()
		var alfa: float = clampf(e.vida / 0.2, 0.0, 1.0)
		var t: int = e.get("tier", 0)
		var r: float = 12.0 * float(e.get("area", 1.0))
		for k in range(int(round(float(Cresc.fx(t).imagens) * Cresc.fator())), 0, -1):  # luas fantasma atrás da lua de energia
			w.draw_arc((e.pos - e.vel.normalized() * 9.0 * k).floor(), r, a - 1.2, a + 1.2, 10, Color(0.55, 0.8, 1.0, alfa * 0.3 / k), 3.0)
		w.draw_arc(e.pos.floor(), r, a - 1.2, a + 1.2, 10, Color(Cresc.cor(Color(0.55, 0.8, 1.0), t), alfa * 0.8), 4.0 * Cresc.grossura(t))
		w.draw_arc(e.pos.floor(), r, a - 1.0, a + 1.0, 10, Color(BRILHO, alfa), 1.0)
		return
	# o corte em si é a meia-lua do efeitos.gd (aditiva, com brilho); aqui só a lua de energia acima


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
