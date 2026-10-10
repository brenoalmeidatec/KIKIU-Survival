extends RefCounted
## Lança (#65, arma global): estocada longa e estreita na direção do inimigo mais perto; atravessa todos na linha.
## "quantidade" = estocadas seguidas, cada uma num alvo. A evolução tem ponta de brasa.
## Atributos: alcance, largura, dano, quantidade, area. Módulo de comportamento de arma (veja armas.gd e pistolas.gd).

const DUR := 0.22   # quanto tempo a lança fica esticada (vai e volta)
const Cresc := preload("res://scripts/hordas/crescimento.gd")


static func atualizar(w, a: Dictionary, d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.25, float(s.recarga))
	var c: Vector2 = w.dono.centro()
	var q := int(s.quantidade)
	var alcance := float(s.get("alcance", 140)) * float(s.area)
	var alvos: Array = w.campo.n_mais_perto(c, q, alcance + 60.0)
	var rm: Dictionary = s.get("comp", {}).get("lanca_ramos", {})   # fusão Lança Sanguessuga: pontas laterais e roubo de vida
	for i in q:
		var dir := Vector2(w.dono.lado, 0)
		if not alvos.is_empty():
			dir = (alvos[i % alvos.size()].pos - c).normalized()
		var dirs := [[dir, 1.0, 1.0]]
		for r in int(rm.get("ramos", 0)):
			var ang := float(rm.get("angulo", 0.5)) * (1.0 if r % 2 == 0 else -1.0) * (1 + r / 2)
			dirs.append([dir.rotated(ang), float(rm.get("alcance_mult", 0.75)), float(rm.get("dano_mult", 0.6))])
		for dd in dirs:
			w.especiais.append({"tipo": "lanca", "espera": i * 0.12, "t": DUR, "dir": dd[0], "alcance": alcance * dd[1],
				"largura": float(s.get("largura", 14)) * float(s.area), "dano": float(s.dano) * dd[2], "arma": a.id, "feito": false,
				"evo": bool(d.get("evolucao", false)), "cura": int(rm.get("cura", 0)), "cura_max": int(rm.get("cura_max", 0))})
	w.golpe_corpo((alvos[0].pos - c).normalized() if not alvos.is_empty() else Vector2(w.dono.lado, 0))


static func passo(w, e: Dictionary, dt: float) -> bool:
	if e.espera > 0:
		e.espera -= dt
		return true
	e.t -= dt
	if not e.feito:
		e.feito = true
		var c: Vector2 = w.dono.centro()
		var fim: Vector2 = c + e.dir * e.alcance
		var n := 0
		for v in w.campo.no_circulo((c + fim) / 2.0, e.alcance / 2.0 + e.largura):
			if Geometry2D.get_closest_point_to_segment(v.pos, c, fim).distance_to(v.pos) <= e.largura / 2.0 + 8.0:
				w.campo.ferir(v, e.dano, e.dir * 120.0, e.arma)
				n += 1
		Som.tocar("whoosh", 0.05, 1.3, -8)
		if e.cura > 0 and n > 0:
			w.dono.curar(float(e.cura * mini(n, e.cura_max)))
		var ef = w.fx()
		if ef:   # faíscas saindo da ponta na direção da estocada
			ef.faisca(fim, e.dir, Color(1.0, 0.75, 0.4) if e.evo else Color(0.8, 0.9, 1.0), 3, 220.0)
			Cresc.fagulhas(w, fim, e.dir, Color(1.0, 0.75, 0.4) if e.evo else Color(0.8, 0.9, 1.0), e.get("tier", 0), 230.0)
		if n > 0:
			Cresc.acerto(w, 0.8, e.get("tier", 0))
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
	var t: int = e.get("tier", 0)
	var g := Cresc.grossura(t)
	metal = Cresc.cor(metal, t)
	w.draw_line(base, c + e.dir * e.alcance, Color(metal, 0.12 * ext * g), e.largura)   # a faixa que a estocada varre
	if t >= 2:   # imagem fantasma da lança, um pouco atrás na estocada, e luz na ponta
		for k in range(int(round(float(Cresc.fx(t).imagens) * Cresc.fator())), 0, -1):
			var pk: Vector2 = c + e.dir * e.alcance * ext * (1.0 - 0.12 * k)
			w.draw_line(base.floor(), pk.floor(), Color(metal, 0.3 / k), 2.0 * g)
		Cresc.halo(w, ponta, 16.0 + e.largura, metal, t)
	w.draw_line(base.floor(), ponta.floor(), Color(0.05, 0.04, 0.08, 0.7), 4.0 * g)
	w.draw_line(base.floor(), ponta.floor(), haste, 2.0 * g)
	var lado: Vector2 = e.dir.orthogonal() * maxf(4.0, e.largura * 0.35)
	w.draw_colored_polygon(PackedVector2Array([ponta + e.dir * 10.0 * g, ponta + lado, ponta - lado]), metal)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
