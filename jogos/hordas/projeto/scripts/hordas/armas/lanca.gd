extends RefCounted
## Lança (#65, arma global): estocada longa e estreita na direção do inimigo mais perto; atravessa todos na linha.
## "quantidade" = estocadas seguidas, cada uma num alvo. A evolução tem ponta de brasa.
## Atributos: alcance, largura, dano, quantidade, area. Módulo de comportamento de arma (veja armas.gd e pistolas.gd).

const DUR := 0.22   # quanto tempo a lança fica esticada (vai e volta)


static func atualizar(w, a: Dictionary, d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.25, float(s.recarga))
	var c: Vector2 = w.dono.centro()
	var q := int(s.quantidade)
	var alcance := float(s.get("alcance", 140)) * float(s.area)
	var alvos: Array = w.campo.n_mais_perto(c, q, alcance + 60.0)
	for i in q:
		var dir := Vector2(w.dono.lado, 0)
		if not alvos.is_empty():
			dir = (alvos[i % alvos.size()].pos - c).normalized()
		w.especiais.append({"tipo": "lanca", "espera": i * 0.12, "t": DUR, "dir": dir, "alcance": alcance,
			"largura": float(s.get("largura", 14)) * float(s.area), "dano": float(s.dano), "arma": a.id, "feito": false,
			"evo": bool(d.get("evolucao", false))})
	w.golpe_corpo()


static func passo(w, e: Dictionary, dt: float) -> bool:
	if e.espera > 0:
		e.espera -= dt
		return true
	e.t -= dt
	if not e.feito:
		e.feito = true
		var c: Vector2 = w.dono.centro()
		var fim: Vector2 = c + e.dir * e.alcance
		for v in w.campo.no_circulo((c + fim) / 2.0, e.alcance / 2.0 + e.largura):
			if Geometry2D.get_closest_point_to_segment(v.pos, c, fim).distance_to(v.pos) <= e.largura / 2.0 + 8.0:
				w.campo.ferir(v, e.dano, e.dir * 120.0, e.arma)
		Som.tocar("whoosh", 0.05, 1.3, -8)
	return e.t > 0


static func pintar(w, e: Dictionary) -> void:
	if e.espera > 0:
		return
	var c: Vector2 = w.dono.centro()
	var ext: float = sin((1.0 - e.t / DUR) * PI)
	var base: Vector2 = c + e.dir * 6.0
	var ponta: Vector2 = c + e.dir * e.alcance * ext
	var haste := Color(0.8, 0.5, 0.25) if e.evo else Color(0.45, 0.32, 0.2)
	var metal := Color(1.0, 0.7, 0.3) if e.evo else Color(0.85, 0.85, 0.92)
	w.draw_line(base, c + e.dir * e.alcance, Color(metal, 0.12 * ext), e.largura)   # a faixa que a estocada varre
	w.draw_line(base.floor(), ponta.floor(), Color(0.05, 0.04, 0.08, 0.7), 4.0)
	w.draw_line(base.floor(), ponta.floor(), haste, 2.0)
	var lado: Vector2 = e.dir.orthogonal() * maxf(4.0, e.largura * 0.35)
	w.draw_colored_polygon(PackedVector2Array([ponta + e.dir * 10.0, ponta + lado, ponta - lado]), metal)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
