extends RefCounted
## Duas Desert Eagles (exclusiva do Hazaki): UMA habilidade, duas mãos. Os tiros saem alternando a mão
## esquerda e a direita, cada um num alvo diferente, com clarão na boca da arma.
## Atributos: quantidade (tiros por rajada), velocidade, perfura, ricochete (quantas vezes a bala pula pro
## próximo inimigo), explosivo (>0: a bala explode no último acerto).
## Módulo de comportamento de arma (veja armas.gd e katana.gd).

const MAO := Vector2(9, 3)       # onde fica cada mão em relação ao centro do corpo
const OURO := Color(1.0, 0.85, 0.4)


static func atualizar(w, a: Dictionary, _d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.12, float(s.recarga))
	var c: Vector2 = w.dono.centro()
	var q := int(s.quantidade)
	var alvos: Array = w.campo.n_mais_perto(c, q, 420)
	for i in q:
		var mao := Vector2(MAO.x * (-1 if i % 2 == 0 else 1), MAO.y)
		var origem := c + mao
		var dir := Vector2(w.dono.lado, 0)
		if not alvos.is_empty():
			dir = (alvos[i % alvos.size()].pos - origem).normalized()
		w.especiais.append({"tipo": "pistolas", "bala": true, "espera": i * 0.05, "pos": origem, "dir": dir,
			"vel": float(s.velocidade), "vida": float(s.duracao), "dano": float(s.dano),
			"perfura": int(s.get("perfura", 1)), "ricochete": int(s.get("ricochete", 0)),
			"explosivo": float(s.get("explosivo", 0)) > 0, "acertou": [], "arma": a.id, "saiu": false})


static func passo(w, e: Dictionary, dt: float) -> bool:
	if e.has("boom"):
		e.t -= dt
		if not e.feito:
			e.feito = true
			for v in w.campo.no_circulo(e.pos, e.r):
				w.campo.ferir(v, e.dano, (v.pos - e.pos).normalized() * 160.0, e.arma)
		return e.t > 0
	if e.has("clarao"):
		e.t -= dt
		return e.t > 0
	if e.espera > 0:
		e.espera -= dt
		return true
	if not e.saiu:
		e.saiu = true
		w.especiais.append({"tipo": "pistolas", "clarao": true, "pos": e.pos + e.dir * 6.0, "dir": e.dir, "t": 0.06})
		Som.tocar("cursor", 0.05, 0.7, -9)
	e.pos += e.dir * e.vel * dt
	e.vida -= dt
	if e.vida <= 0:
		return false
	for v in w.campo.no_circulo(e.pos, 5.0):
		if v.id in e.acertou:
			continue
		e.acertou.append(v.id)
		w.campo.ferir(v, e.dano, e.dir * 70.0, e.arma)
		if e.ricochete > 0:
			# pula pro inimigo mais perto que ainda não levou essa bala
			var prox = null
			var md := 160.0 * 160.0
			for o in w.campo.no_circulo(e.pos, 160.0):
				var dd: float = o.pos.distance_squared_to(e.pos)
				if not o.id in e.acertou and dd < md:
					md = dd
					prox = o
			if prox:
				e.ricochete -= 1
				e.dir = (prox.pos - e.pos).normalized()
				e.vida = maxf(e.vida, 0.4)
				return true
		e.perfura -= 1
		if e.perfura <= 0:
			if e.explosivo:
				w.especiais.append({"tipo": "pistolas", "boom": true, "pos": e.pos, "r": 30.0, "t": 0.22,
					"dano": e.dano * 0.6, "arma": e.arma, "feito": false})
			return false
	return true


static func pintar(w, e: Dictionary) -> void:
	if e.has("boom"):
		var f: float = e.t / 0.22
		w.draw_circle(e.pos.floor(), e.r * (1.2 - f * 0.5), Color(1.0, 0.55, 0.2, 0.35 * f))
		w.draw_arc(e.pos.floor(), e.r * (1.2 - f * 0.5), 0, TAU, 20, Color(1, 0.9, 0.5, f), 2.0)
		return
	if e.has("clarao"):
		# clarão em cruz na boca da arma (pixel art: retângulos, sem degradê)
		var p: Vector2 = e.pos.floor()
		w.draw_rect(Rect2(p - Vector2(3, 1), Vector2(7, 3)), Color(OURO, 0.9))
		w.draw_rect(Rect2(p - Vector2(1, 3), Vector2(3, 7)), Color(OURO, 0.9))
		w.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color.WHITE)
		return
	if e.espera > 0:
		return
	# bala: risco curto dourado com miolo branco (rastro de 6 px)
	var cauda: Vector2 = e.pos - e.dir * 6.0
	w.draw_line(cauda.floor(), e.pos.floor(), Color(OURO, 0.9), 2.0)
	w.draw_line((e.pos - e.dir * 2.0).floor(), e.pos.floor(), Color.WHITE, 1.0)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass
