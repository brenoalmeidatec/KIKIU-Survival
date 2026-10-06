extends RefCounted
## Arte Marcial (exclusiva do Hazaki): só os punhos e os pés, nada nas mãos. Um COMBO que se repete:
## soco, soco, chute (e, com upgrade, chute giratório e onda de impacto no fim do combo).
## Atributos: alcance (do soco), giro (>0: chute giratório 360°), onda (>0: onda de impacto que se espalha).
## Módulo de comportamento de arma (veja armas.gd e katana.gd).

const GOLPES := {
	# alcance x, arco (graus), dano x, empurrão, duração do desenho
	"soco": [1.0, 50.0, 1.0, 140.0, 0.1],
	"chute": [1.3, 120.0, 1.35, 210.0, 0.14],
	"giro": [1.45, 360.0, 1.25, 230.0, 0.2],
}
const PELE := Color(0.85, 0.63, 0.4)
const ENERGIA := Color(0.55, 0.8, 1.0)


static func atualizar(w, a: Dictionary, _d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.12, float(s.recarga))
	w.golpe_corpo()
	var seq := ["soco", "soco", "chute"]
	if float(s.get("giro", 0)) > 0:
		seq.append("giro")
	var k: int = int(a.get("combo", 0)) % seq.size()
	a["combo"] = k + 1
	var golpe: String = seq[k]
	var c: Vector2 = w.dono.centro()
	var alcance: float = float(s.get("alcance", 46)) * float(s.area)
	var alvo = w.campo.mais_perto(c, alcance * 2.2)
	var dir: Vector2 = (alvo.pos - c).normalized() if alvo else Vector2(w.dono.lado, 0)
	var g: Array = GOLPES[golpe]
	var e := {"tipo": "marcial", "golpe": golpe, "pos": c, "dir": dir, "alcance": alcance * g[0], "arco": deg_to_rad(g[1]),
		"t": g[4], "dur": g[4], "impactos": []}
	for v in w.campo.no_circulo(c, e.alcance):
		var dif: Vector2 = v.pos - c
		if g[1] >= 360.0 or absf(angle_difference(dir.angle(), dif.angle())) <= e.arco / 2 or dif.length() < 12.0:
			w.campo.ferir(v, float(s.dano) * g[2], dif.normalized() * g[3], a.id)
			if e.impactos.size() < 4:
				e.impactos.append(v.pos)
	w.especiais.append(e)
	Som.tocar("soco", 0.04, 1.6 if golpe == "soco" else 1.2, -8)
	# fim do combo com upgrade de onda: uma onda de impacto que se espalha e acerta cada um uma vez
	if k == seq.size() - 1 and float(s.get("onda", 0)) > 0:
		w.especiais.append({"tipo": "marcial", "onda": true, "pos": c, "r": 8.0, "rmax": alcance * 3.2, "t": 0.35,
			"dano": float(s.dano) * 0.8, "acertou": [], "arma": a.id})


static func passo(w, e: Dictionary, dt: float) -> bool:
	e.t -= dt
	if e.get("onda", false):
		e.r = lerpf(e.rmax, 8.0, e.t / 0.35)
		for v in w.campo.no_circulo(e.pos, e.r):
			if not v.id in e.acertou and v.pos.distance_to(e.pos) > e.r - 18.0:
				e.acertou.append(v.id)
				w.campo.ferir(v, e.dano, (v.pos - e.pos).normalized() * 180.0, e.arma)
	return e.t > 0


static func pintar(w, e: Dictionary) -> void:
	if e.get("onda", false):
		var f: float = e.t / 0.35
		w.draw_arc(e.pos.floor(), e.r, 0, TAU, 32, Color(ENERGIA, 0.8 * f), 3.0)
		w.draw_arc(e.pos.floor(), e.r - 4.0, 0, TAU, 32, Color(1, 1, 1, 0.5 * f), 1.0)
		return
	var f: float = e.t / e.dur
	var ang: float = e.dir.angle()
	match e.golpe:
		"soco":
			# punho perto do corpo (não um braço de 50 px) + linhas de velocidade atrás dele
			var ponta: Vector2 = (e.pos + e.dir * minf(24.0, e.alcance * 0.5)).floor()
			var lado: Vector2 = e.dir.orthogonal()
			for k in 3:
				var o: Vector2 = lado * (k - 1) * 3.0
				w.draw_line((ponta - e.dir * (8.0 + k * 3.0) + o).floor(), (ponta - e.dir * 4.0 + o).floor(), Color(1, 1, 1, 0.6 * f), 1.0)
			w.draw_rect(Rect2(ponta - Vector2(3, 3), Vector2(7, 7)), Color(0.05, 0.04, 0.08, f))   # contorno do punho
			w.draw_rect(Rect2(ponta - Vector2(2, 2), Vector2(5, 5)), Color(PELE, f))
			w.draw_rect(Rect2(ponta - Vector2(2, 2), Vector2(5, 1)), Color(1, 0.85, 0.65, f))       # brilho dos nós dos dedos
		"chute":
			w.draw_arc(e.pos.floor(), e.alcance * 0.85, ang - e.arco / 2, ang + e.arco / 2, 14, Color(PELE, 0.6 * f), 4.0)
			w.draw_arc(e.pos.floor(), e.alcance * 0.85 + 2.0, ang - e.arco / 2, ang + e.arco / 2, 14, Color(1, 1, 1, 0.7 * f), 1.0)
		"giro":
			w.draw_arc(e.pos.floor(), e.alcance * 0.8, ang, ang + TAU * (1.0 - f * 0.3), 28, Color(ENERGIA, 0.6 * f), 4.0)
	# estrelinha de impacto onde o golpe pegou
	for p in e.impactos:
		var q: Vector2 = p.floor()
		var tam := 2.0 + 3.0 * f
		w.draw_rect(Rect2(q - Vector2(tam, 0.5), Vector2(tam * 2 + 1, 2)), Color(1, 0.95, 0.7, f))
		w.draw_rect(Rect2(q - Vector2(0.5, tam), Vector2(2, tam * 2 + 1)), Color(1, 0.95, 0.7, f))


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
