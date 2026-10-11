extends RefCounted
## Baforada de Fogo (forma de dragão, seção 9): rajada em CONE saindo da boca, mirando o vírus mais perto.
## Atributos (armas.json): alcance, largura (graus do cone), sopro (segundos de cada rajada), tique, dano (por tique),
## queimadura (dano por segundo que fica 2 s em quem pegou fogo), explosao (raio da explosão na ponta, no fim da rajada).
## Módulo de comportamento de arma (veja armas.gd e katana.gd).

const VIDA_FOGO := 0.32  # quanto vive cada labareda (pixel de fogo voando)
const QUEIMA := 2.0  # segundos queimando
## do mais quente (perto da boca) pro mais frio (fumaça): rampa "fogo" do pixel3d.py
const CORES := [Color("ffd060"), Color("f0921e"), Color("f0921e"), Color("c45a14"), Color("7a2c0c"), Color(0.15, 0.1, 0.1)]


static func boca(w) -> Vector2:
	var f = w.dono.get("forma")
	return f.boca() if f else w.dono.centro()


static func _mirar(w, de: Vector2, alcance: float, atual: Vector2) -> Vector2:
	var alvo = w.campo.mais_perto(de, alcance * 1.5)
	if alvo:
		return (alvo.pos - de).normalized()
	var mov: Vector2 = w.dono.direcao_mov() if w.dono.has_method("direcao_mov") else Vector2.ZERO
	return mov.normalized() if mov != Vector2.ZERO else atual


static func atualizar(w, a: Dictionary, _d: Dictionary, s: Dictionary, dt: float) -> void:
	a.t -= dt
	if a.t > 0:
		return
	var sopro := float(s.get("sopro", 1.1))
	a.t = maxf(0.5, float(s.recarga)) + sopro
	var alcance := float(s.get("alcance", 95)) * float(s.area)
	var b := boca(w)
	w.especiais.append(
		{
			"tipo": "baforada",
			"boca": true,
			"t": sopro,
			"tique": 0.0,
			"pos": b,
			"dir": _mirar(w, b, alcance, Vector2(w.dono.lado, 0)),
			"alcance": alcance,
			"largura": deg_to_rad(float(s.get("largura", 40))),
			"dano": float(s.dano),
			"tique_s": float(s.get("tique", 0.15)),
			"queima": float(s.get("queimadura", 0)),
			"explosao": float(s.get("explosao", 0)) * float(s.area),
			"arma": a.id,
			"fogo": [],
			"queimando": {},
			"boom": 0.0,
			"boom_pos": Vector2.ZERO
		}
	)
	Som.tocar("whoosh", 0.1, 0.55, -2)


static func passo(w, e: Dictionary, dt: float) -> bool:
	if e.t > 0:
		e.t -= dt
		e.pos = boca(w)
		e.dir = e.dir.slerp(_mirar(w, e.pos, e.alcance, e.dir), minf(1.0, dt * 6.0)).normalized()
		var forma = w.dono.get("forma")
		if forma:
			forma.olhar = e.dir if e.t > 0 else Vector2.ZERO  # a cabeça vira pra onde sopra
		# labaredas: nascem na boca e voam pro cone (o desenho É o alcance do dano)
		for i in 4:
			var ang: float = e.dir.angle() + randf_range(-0.5, 0.5) * e.largura
			e.fogo.append(
				{"pos": e.pos, "vel": Vector2.from_angle(ang) * e.alcance / VIDA_FOGO * randf_range(0.8, 1.05), "t": VIDA_FOGO, "tam": randf_range(2.0, 3.0)}
			)
		e.tique -= dt
		if e.tique <= 0:
			e.tique = e.tique_s
			var ang: float = e.dir.angle()
			for v in w.campo.no_circulo(e.pos, e.alcance):
				var dif: Vector2 = v.pos - e.pos
				if absf(angle_difference(ang, dif.angle())) <= e.largura / 2 + 0.15 or dif.length() < 12.0:
					w.campo.ferir(v, e.dano, e.dir * 25.0, e.arma)
					v.flash = 0.0  # acerto contínuo: sem o piscar branco (amontoados viravam uma nuvem branca)
					if e.queima > 0 and v.hp > 0:
						e.queimando[v.id] = {"v": v, "t": QUEIMA}
			Som.tocar("plim", 0.12, 0.35, -16)
		if e.t <= 0:
			e.boca = false
			if e.explosao > 0:
				_explodir(w, e)
	# queimadura: dano contínuo em quem pegou fogo
	for id in e.queimando.keys():
		var q: Dictionary = e.queimando[id]
		q.t -= dt
		if q.t <= 0 or q.v.hp <= 0:
			e.queimando.erase(id)
		elif int(q.t * 10.0) != int((q.t + dt) * 10.0):  # a cada 0.1 s
			w.campo.ferir(q.v, e.queima * 0.1, Vector2.ZERO, e.arma)
			q.v.flash = 0.0
	for f in e.fogo.duplicate():
		f.t -= dt
		f.pos += f.vel * dt
		f.vel *= exp(-2.5 * dt)
		if f.t <= 0:
			e.fogo.erase(f)
	e.boom = maxf(0.0, e.boom - dt)
	return e.t > 0 or not e.fogo.is_empty() or not e.queimando.is_empty() or e.boom > 0


static func _explodir(w, e: Dictionary) -> void:
	var p: Vector2 = e.pos + e.dir * e.alcance * 0.85
	e.boom = 0.3
	e.boom_pos = p
	for v in w.campo.no_circulo(p, e.explosao):
		w.campo.ferir(v, e.dano * 5.0, (v.pos - p).normalized() * 160.0, e.arma)
	for i in 14:
		e.fogo.append({"pos": p, "vel": Vector2.from_angle(TAU * i / 14.0) * e.explosao / VIDA_FOGO, "t": VIDA_FOGO, "tam": 4.0})
	Som.tocar("tremor", 0.1, 1.4, -6)
	w.arena.tremer(3.0)


static func pintar(w, e: Dictionary) -> void:
	# pixel de fogo: cor pelo tempo de vida (amarelo-branco na boca, fumaça no fim), cresce enquanto esfria
	for f in e.fogo:
		var vida: float = 1.0 - f.t / VIDA_FOGO
		var c: Color = CORES[mini(int(vida * CORES.size()), CORES.size() - 1)]
		var tam: float = floorf(f.tam * (1.0 + vida))
		w.draw_rect(Rect2(f.pos.floor() - Vector2(tam, tam) / 2.0, Vector2(tam, tam)), Color(c, 0.9 - vida * 0.6))
	for id in e.queimando:
		var q: Dictionary = e.queimando[id]
		var p: Vector2 = q.v.pos + Vector2(sin(q.t * 20.0) * 2.0, -10.0 - fmod(q.t * 30.0, 6.0))
		w.draw_rect(Rect2(p.floor(), Vector2(2, 3)), CORES[1 + int(q.t * 10.0) % 3])
	if e.boom > 0:
		var f: float = e.boom / 0.3
		w.draw_circle(e.boom_pos.floor(), e.explosao * (1.0 - f * 0.6), Color(CORES[1], 0.35 * f))
		w.draw_arc(e.boom_pos.floor(), e.explosao * (1.0 - f * 0.4), 0, TAU, 24, Color(CORES[0], f), 2.0)


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass
