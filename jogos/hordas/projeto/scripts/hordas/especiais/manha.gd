extends RefCounted
## "Na Manha" (especial do Nicão, #63): "tranquilo, tranquilo", ele fica de boa na manha dele. No jogo: ninguém
## encosta nele por uns segundos (invencível), ele se cura, e uma bolha calma em volta deixa lento (e machuca de
## leve) quem chega perto. Módulo de efeito no padrão das armas; ativar() é chamado pelo especial.gd.

const CALMO := Color(0.45, 0.85, 0.75)
const FOLHA := Color(0.55, 0.8, 0.45)


static func ativar(w, d: Dictionary, esp) -> void:
	var jog = w.dono
	var dur := float(d.get("duracao", 4.0))
	jog.invencivel = maxf(jog.invencivel, dur)
	jog.curar(jog.vida_max() * float(d.get("cura", 0.35)))
	w.especiais.append(
		{
			"tipo": "manha",
			"pos": jog.position,
			"t": dur,
			"dur": dur,
			"r": float(d.get("raio", 125)),
			"lento": float(d.get("lento", 1.5)),
			"dano": esp.dano(),
			"tique": 0.0,
			"arma": str(d.get("nome", "especial"))
		}
	)


static func passo(w, e: Dictionary, dt: float) -> bool:
	e.t -= dt
	e.pos = w.dono.position
	e.tique -= dt
	if e.tique <= 0.0:
		e.tique = 0.5
		var c: Vector2 = w.dono.centro()
		for v in w.campo.no_circulo(c, e.r):
			if "lento" in v:
				v.lento = maxf(float(v.lento), e.lento)
			w.campo.ferir(v, e.dano, (v.pos - c).normalized() * 60.0, e.arma)
	return e.t > 0


static func pintar(w, e: Dictionary) -> void:
	var f: float = clampf(e.t / 0.4, 0.0, 1.0) * clampf((e.dur - e.t) / 0.25, 0.0, 1.0)  # entra e sai suave
	var c: Vector2 = (e.pos as Vector2).floor() + Vector2(0, -2)
	var tempo: float = e.dur - e.t
	# bolha calma no chão (elipse) e ondinhas lentas saindo dela
	w.draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
	w.draw_circle(Vector2.ZERO, e.r, Color(CALMO, 0.10 * f))
	w.draw_arc(Vector2.ZERO, e.r, 0, TAU, 40, Color(CALMO, 0.55 * f), 2.0)
	for k in 2:
		var o := fmod(tempo * 0.5 + k * 0.5, 1.0)
		w.draw_arc(Vector2.ZERO, e.r * o, 0, TAU, 32, Color(CALMO, 0.35 * f * (1.0 - o)), 1.0)
	w.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# folhinhas caindo devagar em volta (o clima "de boa")
	for i in 7:
		var fase := fmod(tempo * 0.35 + i * 0.143, 1.0)
		var x: float = sin(i * 2.4) * e.r * 0.8 + sin(tempo * 2.0 + i) * 6.0
		var p := c + Vector2(x, -50.0 + fase * 60.0)
		w.draw_rect(Rect2(p.floor(), Vector2(2, 1)), Color(FOLHA, f * (1.0 - fase)))
		w.draw_rect(Rect2(p.floor() + Vector2(1, 1), Vector2(1, 1)), Color(FOLHA, f * (1.0 - fase)))
	# "z z" de quem está tranquilo
	for i in 2:
		var fase := fmod(tempo * 0.6 + i * 0.5, 1.0)
		var p := c + Vector2(10.0 + i * 4.0, -34.0 - fase * 16.0)
		var a := f * (1.0 - fase)
		w.draw_line(p, p + Vector2(4, 0), Color(1, 1, 1, a), 1.0)
		w.draw_line(p + Vector2(4, 0), p + Vector2(0, 4), Color(1, 1, 1, a), 1.0)
		w.draw_line(p + Vector2(0, 4), p + Vector2(4, 4), Color(1, 1, 1, a), 1.0)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
