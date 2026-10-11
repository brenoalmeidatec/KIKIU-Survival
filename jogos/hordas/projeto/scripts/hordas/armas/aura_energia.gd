extends RefCounted
## Aura (exclusiva do Hazaki): energia liberada em volta do corpo. Identidade própria (não copia nenhuma obra):
## chamas de energia azul-cobalto subindo pelo corpo, faíscas douradas, anel no chão e um PULSO que se espalha.
## Quanto maior o nível, mais chamas, mais altas e, no alto, uma camada dourada por fora.
## Atributos: raio, dano, tique (dano contínuo), empurra, pulso (segundos entre ondas).
## Módulo de comportamento de arma (veja armas.gd e katana.gd).

const COBALTO := Color(0.25, 0.45, 1.0)
const CIANO := Color(0.55, 0.85, 1.0)
const OURO := Color(1.0, 0.82, 0.35)
const Cresc := preload("res://scripts/hordas/crescimento.gd")


static func atualizar(w, a: Dictionary, _d: Dictionary, s: Dictionary, dt: float) -> void:
	var c: Vector2 = w.dono.centro()
	var r: float = float(s.get("raio", 56)) * float(s.area)
	a.tique -= dt
	if a.tique <= 0:
		a.tique = maxf(0.15, float(s.get("tique", 0.5)))
		for v in w.campo.no_circulo(c, r):
			w.campo.ferir(v, float(s.dano), (v.pos - c).normalized() * float(s.get("empurra", 50)) * 0.4, a.id)
	a["pulso_t"] = float(a.get("pulso_t", 1.0)) - dt
	if a.pulso_t <= 0:
		a.pulso_t = maxf(0.8, float(s.get("pulso", 3.0)))
		w.especiais.append(
			{
				"tipo": "aura_energia",
				"pos": c,
				"r": r * 0.6,
				"rmax": r * 1.8,
				"t": 0.45,
				"dano": float(s.dano) * 2.5,
				"empurra": float(s.get("empurra", 50)) * 2.0,
				"acertou": [],
				"arma": a.id
			}
		)
		Som.tocar("tremor", 0.1, 1.8, -12)


## O pulso: um anel que se espalha, acerta e empurra cada um uma vez.
static func passo(w, e: Dictionary, dt: float) -> bool:
	e.t -= dt
	e.r = lerpf(e.rmax, e.rmax * 0.33, e.t / 0.45)
	for v in w.campo.no_circulo(e.pos, e.r):
		if not v.id in e.acertou and v.pos.distance_to(e.pos) > e.r - 20.0:
			e.acertou.append(v.id)
			w.campo.ferir(v, e.dano, (v.pos - e.pos).normalized() * e.empurra, e.arma)
	return e.t > 0


static func pintar(w, e: Dictionary) -> void:
	var f: float = e.t / 0.45
	w.draw_arc(e.pos.floor(), e.r, 0, TAU, 40, Color(Cresc.cor(CIANO, e.get("tier", 0)), 0.75 * f), 3.0 * Cresc.grossura(e.get("tier", 0)))
	w.draw_arc(e.pos.floor(), e.r - 3.0, 0, TAU, 40, Color(1, 1, 1, 0.6 * f), 1.0)
	w.draw_arc(e.pos.floor(), e.r + 3.0, 0, TAU, 40, Color(OURO, 0.4 * f), 1.0)


## Atrás do personagem (a energia sai DE TRÁS do corpo e não esconde o equipamento): anel no chão e chamas.
static func atras(w, ci: CanvasItem, a: Dictionary, s: Dictionary) -> void:
	var t: float = w._t
	var pe: Vector2 = w.dono.position
	var r: float = float(s.get("raio", 56)) * float(s.area)
	var nv: int = int(a.nivel)
	# anel de energia no chão (elipse em perspectiva) mostrando o alcance
	ci.draw_set_transform(pe, 0, Vector2(1, 0.45))
	ci.draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(COBALTO, 0.25 + 0.1 * sin(t * 5.0)), 2.0)
	ci.draw_circle(Vector2.ZERO, 16.0, Color(CIANO, 0.18))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_chamas(w, ci, a, false)


## Anel de chamas (cones) em volta do corpo, em perspectiva: o herói fica DENTRO do anel. A metade de trás (y menor
## que o pé) vai no nó de trás e a da frente por cima do boneco, mais transparente pra não esconder o herói.
const ALFA_TRAS := 0.62
const ALFA_FRENTE := 0.42
const RAIO_ANEL := Vector2(24.0, 7.0)


static func _chamas(w, ci, a: Dictionary, frente: bool) -> void:
	var t: float = w._t
	var pe: Vector2 = w.dono.position
	var nv: int = int(a.nivel)
	var k: float = ALFA_FRENTE if frente else ALFA_TRAS
	var ar: float = Cresc.mult(str(a.get("id", "aura_hazaki")), int(a.get("nivel", 1)), "area")  # a chama cresce com a curva de crescimento da arma
	var n := 6 + nv * 2
	for i in n:
		var ang := TAU * i / n + t * 1.5
		var sn := sin(ang)
		if (sn >= 0.0) != frente:  # sin>0 = lado do olhador (pé pra baixo na tela)
			continue
		var base := pe + Vector2(cos(ang) * RAIO_ANEL.x * maxf(ar, 0.9), sn * RAIO_ANEL.y * maxf(ar, 0.9) - 2.0)  # o anel nunca fica mais estreito que o herói
		var alt := (34.0 + nv * 5.0) * ar * (0.6 + 0.4 * absf(sin(t * 9.0 + i * 1.7)))
		if frente:
			alt *= 0.8
		var topo := base + Vector2(sin(t * 6.0 + i) * 3.0, -alt)
		var larg := (3.0 + nv * 0.5) * ar
		if nv >= 4:  # no alto, uma camada dourada por fora
			ci.draw_colored_polygon(
				PackedVector2Array([base + Vector2(-larg - 1.5, 0), base + Vector2(larg + 1.5, 0), topo + Vector2(0, -4)]), Color(OURO, 0.4 * k / 0.6)
			)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-larg, 0), base + Vector2(larg, 0), topo]), Color(COBALTO, k))
		ci.draw_colored_polygon(
			PackedVector2Array([base + Vector2(-larg * 0.4, 0), base + Vector2(larg * 0.4, 0), base.lerp(topo, 0.6)]), Color(CIANO, k * 1.2)
		)


## Na frente do personagem: a metade da frente do anel de chamas (transparente) e as faíscas douradas subindo.
static func fundo(w, a: Dictionary, _s: Dictionary) -> void:
	_chamas(w, w, a, true)
	var t: float = w._t
	var c: Vector2 = w.dono.centro()
	var nv: int = int(a.nivel)
	Cresc.brasas(w, c, 26.0 * Cresc.mult(str(a.get("id", "aura_hazaki")), nv, "area"), OURO, Cresc.tier(str(a.get("id", "aura_hazaki")), nv), t)
	for i in 3 + nv:
		var fase := fmod(t * 0.9 + i * 0.37, 1.0)
		var px := c + Vector2(sin(i * 2.7 + t) * 14.0, 18.0 - fase * 46.0)
		w.draw_rect(Rect2(px.floor(), Vector2(1, 2)), Color(OURO, 1.0 - fase))
