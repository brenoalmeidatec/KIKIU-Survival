extends RefCounted
## Corvos Famintos (#65, arma global, invocação): chama corvos que voam até os inimigos, bicam e trocam de presa quando
## a delas morre. Vivem "duracao" segundos e vão embora. Cada um bica a cada "tique" segundos quando está colado.
## Atributos: quantidade, dano, duracao, velocidade, tique, area. Módulo de comportamento de arma (veja armas.gd).

const PERTO := 10.0   # distância em que o corvo alcança a presa


static func atualizar(w, a: Dictionary, d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	a.t = maxf(0.5, float(s.recarga))
	var c: Vector2 = w.dono.centro()
	for i in int(s.quantidade):
		var ang := TAU * i / maxf(1.0, float(s.quantidade))
		w.especiais.append({"tipo": "corvos", "pos": c + Vector2.from_angle(ang) * 14.0, "vel": Vector2.from_angle(ang) * 60.0,
			"alvo": null, "busca": 0.0, "bica": 0.0, "vida": float(s.duracao), "dano": float(s.dano), "rapidez": float(s.velocidade),
			"tique": float(s.get("tique", 0.5)), "esc": float(s.area), "arma": a.id, "fase": randf() * TAU,
			"negro": bool(d.get("evolucao", false))})


static func _viva(alvo) -> bool:
	return alvo != null and is_instance_valid(alvo) and (not ("hp" in alvo) or alvo.hp > 0)


static func passo(w, e: Dictionary, dt: float) -> bool:
	e.vida -= dt
	e.fase += dt * 18.0
	if e.vida <= 0:
		return false
	e.busca -= dt
	if not _viva(e.alvo) or e.busca <= 0:
		e.busca = 0.6   # troca de presa de vez em quando (e na hora, se a dela morreu): espalha o bando
		var perto: Array = w.campo.n_mais_perto(e.pos, 4, 320)
		e.alvo = perto[randi() % perto.size()] if not perto.is_empty() else null
	var destino: Vector2 = e.alvo.pos if _viva(e.alvo) else w.dono.centro() + Vector2(sin(e.fase * 0.1) * 30.0, -26.0)
	var falta: Vector2 = destino - e.pos
	var quer: Vector2 = falta.normalized() * e.rapidez if falta.length() > 2.0 else Vector2.ZERO
	e.vel = e.vel.lerp(quer, clampf(dt * 6.0, 0.0, 1.0))   # curva suave, como ave
	e.pos += e.vel * dt
	e.bica -= dt
	if _viva(e.alvo) and falta.length() < PERTO * e.esc and e.bica <= 0:
		e.bica = e.tique
		w.campo.ferir(e.alvo, e.dano, e.vel.normalized() * 40.0, e.arma)
	return true


static func pintar(w, e: Dictionary) -> void:
	# corvo de pixel: corpo de 3 px e duas asas que batem; a evolução tem olho de brasa
	# corpo cinza-azulado e borda de asa clara: corvo preto sumia nos chãos escuros (floresta, pântano, reino)
	var p: Vector2 = e.pos.floor()
	var asa: float = sin(e.fase) * 3.0 * e.esc
	var envergadura: float = 6.0 * e.esc
	var corpo := Color(0.22, 0.2, 0.3)
	var borda := Color(0.6, 0.3, 0.7) if e.negro else Color(0.62, 0.62, 0.75)
	for lado in [-1.0, 1.0]:
		var ponta := p + Vector2(envergadura * lado, -asa)
		w.draw_line(p, ponta, corpo, 3.0)
		w.draw_line(p + Vector2(0, -1), ponta + Vector2(0, -1), borda, 1.0)
	w.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), corpo)
	w.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 1)), Color(1.0, 0.35, 0.2) if e.negro else Color(0.95, 0.9, 0.6))


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
