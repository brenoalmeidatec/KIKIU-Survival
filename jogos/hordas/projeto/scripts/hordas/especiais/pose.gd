extends RefCounted
## "Sou Gostoso!" (especial do Hazaki, #63): quando o Breno perde a discussão, ele grita que é gostoso, bem alto.
## No jogo: uma onda de pura vaidade sai dele, machuca, empurra e deixa atordoados os que estão perto (chefe e elite
## só ficam lentos); depois disso ele crita mais e bate mais forte por uns segundos (bônus em especial.gd).
## Módulo de efeito no padrão das armas (armas.gd chama passo/pintar); ativar() é chamado pelo especial.gd.

const DUR := 0.6
const OURO := Color("eccb7a")
const BRANCO := Color(1, 0.97, 0.88)


static func ativar(w, d: Dictionary, esp) -> void:
	var c: Vector2 = w.dono.centro()
	var r := float(d.get("raio", 130))
	for v in w.campo.no_circulo(c, r):
		w.campo.ferir(v, esp.dano(), (v.pos - c).normalized() * float(d.get("empurra", 300)), str(d.get("nome", "especial")))
		var forte: bool = ("chefe" in v and v.chefe) or ("elite" in v and v.elite)
		if not forte and "atordoado" in v:
			v.atordoado = maxf(v.atordoado, float(d.get("atordoa", 2.0)))
		elif "lento" in v:
			v.lento = maxf(float(v.lento), float(d.get("atordoa", 2.0)))
	w.especiais.append({"tipo": "pose", "pos": c, "r": r, "t": DUR})
	w.arena.tremer(4.0)


static func passo(w, e: Dictionary, dt: float) -> bool:
	e.t -= dt
	e.pos = w.dono.centro()
	return e.t > 0


static func pintar(w, e: Dictionary) -> void:
	var f: float = e.t / DUR  # 1 no começo, 0 no fim
	var p: Vector2 = e.pos.floor()
	var r: float = e.r * (1.0 - f * 0.85)
	# raios de luz saindo dele (o "brilho" de quem se acha)
	for i in 12:
		var a := TAU * i / 12.0 + (1.0 - f) * 0.6
		var de := p + Vector2.from_angle(a) * 10.0
		var ate := p + Vector2.from_angle(a) * (r * (0.55 + 0.25 * float(i % 2)))
		w.draw_line(de, ate, Color(OURO, 0.55 * f), 1.0)
	# anel dourado que se espalha, com um fio branco por dentro
	w.draw_arc(p, r, 0, TAU, 40, Color(OURO, 0.9 * f), 3.0)
	w.draw_arc(p, r - 3.0, 0, TAU, 40, Color(BRANCO, 0.7 * f), 1.0)
	# estrelinhas de 4 pontas no anel
	for i in 8:
		var a := TAU * i / 8.0 + (1.0 - f) * 1.5
		var s := p + Vector2.from_angle(a) * r
		var t := 2.0 + 3.0 * f
		w.draw_colored_polygon(
			PackedVector2Array([s + Vector2(0, -t), s + Vector2(t * 0.35, 0), s + Vector2(0, t), s + Vector2(-t * 0.35, 0)]), Color(BRANCO, f)
		)
		w.draw_colored_polygon(
			PackedVector2Array([s + Vector2(-t, 0), s + Vector2(0, t * 0.35), s + Vector2(t, 0), s + Vector2(0, -t * 0.35)]), Color(BRANCO, f)
		)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
