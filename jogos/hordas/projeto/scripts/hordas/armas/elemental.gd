extends RefCounted
## Poder Elemental do Mago (exclusiva do Hazaki): orbes mágicos que alternam FOGO, RAIO e GELO.
##   fogo: dano maior; com "explosao" > 0 explode em área no impacto
##   raio: pula pra "cadeia" inimigos perto (1 sem upgrade)
##   gelo: deixa o inimigo lento
## Com "combina" > 0, cada disparo solta os três elementos juntos (combinação elemental).
## Atributos: quantidade, velocidade, perfura, duracao, explosao, cadeia, combina.
## Módulo de comportamento de arma (veja armas.gd e katana.gd).

const ELEMENTOS := ["fogo", "raio", "gelo"]
const Cresc := preload("res://scripts/hordas/crescimento.gd")
const COR := {"fogo": Color(1.0, 0.5, 0.15), "raio": Color(0.6, 0.85, 1.0), "gelo": Color(0.75, 0.95, 1.0)}
const MIOLO := {"fogo": Color(1.0, 0.9, 0.4), "raio": Color(1, 1, 1), "gelo": Color(1, 1, 1)}


## Dano que diz qual elemento acertou (a morte do inimigo fica queimada, congelada ou eletrocutada: mortes.gd).
## No duelo o alvo é um lutador (sem `causa_pend`), então só marca quem tem o campo.
static func _ferir(w, e: Dictionary, v, dano: float, empurrao: Vector2) -> void:
	if v.get("causa_pend") != null:
		v.causa_pend = e.elem
	w.campo.ferir(v, dano, empurrao, e.arma)


static func atualizar(w, a: Dictionary, _d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.15, float(s.recarga))
	var c: Vector2 = w.dono.centro()
	var q := int(s.quantidade)
	var alvos: Array = w.campo.n_mais_perto(c, q, 380)
	var juntos := float(s.get("combina", 0)) > 0
	for i in q:
		var dir := Vector2(w.dono.lado, 0).rotated(randf_range(-0.3, 0.3))
		if not alvos.is_empty():
			dir = (alvos[i % alvos.size()].pos - c).normalized()
		var lista: Array = ELEMENTOS if juntos else [ELEMENTOS[int(a.get("elemento", 0)) % 3]]
		a["elemento"] = int(a.get("elemento", 0)) + 1
		for k in lista.size():
			var dd := dir.rotated((k - (lista.size() - 1) / 2.0) * 0.18)
			w.especiais.append({"tipo": "elemental", "orbe": true, "elem": lista[k], "pos": c, "vel": dd * float(s.velocidade),
				"vida": float(s.duracao), "dano": float(s.dano), "perfura": int(s.get("perfura", 1)), "acertou": [],
				"cadeia": int(s.get("cadeia", 1)), "explosao": float(s.get("explosao", 0)) > 0, "arma": a.id, "rastro": []})
	Som.tocar("plim", 0.06, 1.8, -12)


static func passo(w, e: Dictionary, dt: float) -> bool:
	if e.has("raio_vis") or e.has("boom"):
		e.t -= dt
		return e.t > 0
	e.rastro.push_front(e.pos)
	if e.rastro.size() > 4 + 2 * int(Cresc.fx(e.get("tier", 0)).imagens):   # tier alto: rastro mais longo
		e.rastro.pop_back()
	e.pos += e.vel * dt
	e.vida -= dt
	if e.vida <= 0:
		return false
	for v in w.campo.no_circulo(e.pos, 7.0 * e.get("area", 1.0)):
		if v.id in e.acertou:
			continue
		e.acertou.append(v.id)
		match e.elem:
			"fogo":
				_ferir(w, e, v, e.dano * 1.25, e.vel.normalized() * 60.0)
				if e.explosao:
					for o in w.campo.no_circulo(e.pos, 30.0 * e.get("area", 1.0)):
						if o != v:
							_ferir(w, e, o, e.dano * 0.6, (o.pos - e.pos).normalized() * 120.0)
					w.especiais.append({"tipo": "elemental", "boom": true, "pos": e.pos, "t": 0.25, "r": 30.0 * e.get("area", 1.0)})
			"raio":
				_ferir(w, e, v, e.dano, Vector2.ZERO)
				var pontos := [v.pos]
				var ja := [v.id]
				var atual: Vector2 = v.pos
				for _j in e.cadeia:
					var prox = null
					var md := 110.0 * 110.0
					for o in w.campo.no_circulo(atual, 110.0):
						var d2: float = o.pos.distance_squared_to(atual)
						if not o.id in ja and d2 < md:
							md = d2
							prox = o
					if prox == null:
						break
					ja.append(prox.id)
					_ferir(w, e, prox, e.dano * 0.7, Vector2.ZERO)
					atual = prox.pos
					pontos.append(atual)
				if pontos.size() > 1:
					w.especiais.append({"tipo": "elemental", "raio_vis": true, "pontos": pontos, "t": 0.12})
			"gelo":
				_ferir(w, e, v, e.dano, e.vel.normalized() * 30.0)
				if "lento" in v:
					v.lento = maxf(float(v.lento), 1.5)
		Cresc.fagulhas(w, e.pos, e.vel.normalized(), COR[e.elem], e.get("tier", 0), 140.0)
		e.perfura -= 1
		if e.perfura <= 0:
			return false
	return true


static func pintar(w, e: Dictionary) -> void:
	if e.has("boom"):
		var f: float = e.t / 0.25
		w.draw_circle(e.pos.floor(), float(e.get("r", 30.0)) * (1.2 - f * 0.5), Color(1.0, 0.45, 0.1, 0.3 * f))
		w.draw_arc(e.pos.floor(), float(e.get("r", 30.0)) * (1.2 - f * 0.5), 0, TAU, 20, Color(1, 0.85, 0.4, f), 2.0)
		return
	if e.has("raio_vis"):
		# raio em zigue-zague entre os inimigos (pontos intermediários tremidos)
		var pts := PackedVector2Array()
		for i in e.pontos.size() - 1:
			var a: Vector2 = e.pontos[i]
			var b: Vector2 = e.pontos[i + 1]
			for k in 4:
				var p: Vector2 = a.lerp(b, k / 4.0)
				pts.append((p + (Vector2(randf_range(-4, 4), randf_range(-4, 4)) if k > 0 else Vector2.ZERO)).floor())
		pts.append(Vector2(e.pontos[-1]).floor())
		var f: float = e.t / 0.12
		w.draw_polyline(pts, Color(COR.raio, f), 3.0)
		w.draw_polyline(pts, Color(1, 1, 1, f), 1.0)
		return
	var cor: Color = COR[e.elem]
	var t: int = e.get("tier", 0)
	var ar: float = e.get("area", 1.0)
	for i in e.rastro.size():
		var p: Vector2 = e.rastro[i]
		w.draw_rect(Rect2(p.floor() - Vector2(1, 1), Vector2(3, 3)), Color(cor, maxf(0.06, 0.5 - i * 0.08)))
	w.draw_circle(e.pos.floor(), 4.0 * maxf(0.7, ar), Cresc.cor(cor, t))
	w.draw_circle(e.pos.floor(), 2.0 * maxf(0.7, ar), MIOLO[e.elem])
	if e.elem == "gelo":   # cristal: pontinhas em cruz
		w.draw_rect(Rect2(e.pos.floor() + Vector2(-6, 0), Vector2(12, 1)), Color(cor, 0.7))
		w.draw_rect(Rect2(e.pos.floor() + Vector2(0, -6), Vector2(1, 12)), Color(cor, 0.7))


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
