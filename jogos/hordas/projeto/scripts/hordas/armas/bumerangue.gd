extends RefCounted
## Machado Bumerangue (#65, arma global): arremessa machados que vão até "alcance", freiam e voltam pra mão, girando.
## Acerta cada inimigo uma vez na ida e outra na volta, atravessando todos.
## Atributos: quantidade, velocidade, alcance, dano, area. Módulo de comportamento de arma (veja armas.gd e pistolas.gd).

const ESCALA := 2.0   # a mesma do armas.gd: 1 px do sprite = 2 px de mundo


static func atualizar(w, a: Dictionary, d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.3, float(s.recarga))
	var c: Vector2 = w.dono.centro()
	var q := int(s.quantidade)
	var alvos: Array = w.campo.n_mais_perto(c, q, 380)
	for i in q:
		var leque := (i - (q - 1) / 2.0) * 0.45   # sem alvo pra cada um: abre em leque
		var dir := Vector2(w.dono.lado, 0).rotated(leque)
		if not alvos.is_empty():
			dir = (alvos[i % alvos.size()].pos - c).normalized().rotated(0.0 if i < alvos.size() else leque)
		w.especiais.append({"tipo": "bumerangue", "pos": c, "dir": dir, "vel": float(s.velocidade), "ida": true, "dist": 0.0,
			"alcance": float(s.get("alcance", 160)) * float(s.area), "dano": float(s.dano), "esc": float(s.area),
			"acertou": [], "arma": a.id, "giro": 0.0, "sprite": str(d.get("sprite", "proj_machado")), "vida": 4.0})
	Som.tocar("whoosh", 0.08, 0.9, -8)


static func passo(w, e: Dictionary, dt: float) -> bool:
	e.giro += dt * 14.0
	e.vida -= dt
	if e.vida <= 0:
		return false
	if e.ida:
		var v: float = e.vel * clampf(1.0 - e.dist / e.alcance, 0.25, 1.0)   # freia perto do fim
		e.pos += e.dir * v * dt
		e.dist += v * dt
		if e.dist >= e.alcance:
			e.ida = false
			e.acertou = []   # na volta, acerta todo mundo de novo
	else:
		var falta: Vector2 = w.dono.centro() - e.pos
		if falta.length() < 12.0:
			return false   # voltou pra mão
		e.pos += falta.normalized() * e.vel * 1.15 * dt
	for v in w.campo.no_circulo(e.pos, 10.0 * e.esc):
		if v.id in e.acertou:
			continue
		e.acertou.append(v.id)
		w.campo.ferir(v, e.dano, (v.pos - e.pos).normalized() * 90.0, e.arma)
	return true


static func pintar(w, e: Dictionary) -> void:
	var tex: Texture2D = Dados.tex(e.sprite)
	if tex == null:
		return
	var sz: Vector2 = tex.get_size() * ESCALA * e.esc
	w.draw_set_transform(e.pos.floor(), e.giro, Vector2.ONE)
	w.draw_texture_rect(tex, Rect2(-sz / 2, sz), false)
	w.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
