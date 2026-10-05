extends Node2D
## As armas do jogador. Todas atiram sozinhas. O jeito de cada uma vem do "tipo" no armas.json:
##   projetil  atira no vírus mais perto
##   chicote   golpe reto na frente (e atrás, com mais quantidade)
##   orbita    coisas girando em volta por um tempo
##   poca      poça no chão que machuca quem pisa
##   aura      círculo em volta do jogador que machuca e empurra
## Os atributos do jogador (dano, área, quantidade...) multiplicam os da arma na hora de atirar.

const ESCALA := 2.0

var arena: Node
var lista: Array = []        # {id, nivel, t, ativo, acertos{}}
var projeteis: Array = []    # {pos, vel, dano, perfura, vida, tex, esc, acertou[], arma}
var pocas: Array = []        # {pos, raio, vida, dano, tique, t, segue, arma}
var golpes: Array = []       # desenho do chicote {pos, lado, alcance, largura, t, arma}
var _fila: Array = []        # golpes atrasados do chicote {t, arma}
var _t := 0.0


func tem(id: String) -> bool:
	return achar(id) != null


func achar(id: String):
	for a in lista:
		if a.id == id:
			return a
	return null


func adicionar(id: String) -> void:
	lista.append({"id": id, "nivel": 1, "t": 0.3, "ativo": 0.0, "acertos": {}, "tique": 0.0})


func nivel_max(id: String) -> int:
	var d := Dados.item(id)
	return 1 + d.get("niveis", []).size()


func subir(id: String) -> void:
	var a = achar(id)
	if a:
		a.nivel = mini(a.nivel + 1, nivel_max(id))


func trocar(de: String, para: String) -> void:
	var a = achar(de)
	if a:
		a.id = para
		a.nivel = 1
		a.t = 0.1
		a.ativo = 0.0


## Atributos da arma no nível atual (sem os bônus do jogador).
func atributos(id: String, nivel: int) -> Dictionary:
	var d := Dados.item(id)
	var s: Dictionary = d.get("base", {}).duplicate()
	var niveis: Array = d.get("niveis", [])
	for i in mini(nivel - 1, niveis.size()):
		for k in niveis[i]:
			s[k] = float(s.get(k, 0)) + float(niveis[i][k])
	return s


func _s(a: Dictionary) -> Dictionary:
	## Atributos finais = arma x jogador.
	var s := atributos(a.id, a.nivel)
	s["dano"] = float(s.get("dano", 1)) * arena.stat("dano")
	s["recarga"] = float(s.get("recarga", 1)) * arena.stat("recarga")
	s["area"] = float(s.get("area", 1)) * arena.stat("area")
	s["quantidade"] = int(s.get("quantidade", 1)) + int(arena.stat("quantidade"))
	s["duracao"] = float(s.get("duracao", 1)) * arena.stat("duracao")
	s["velocidade"] = float(s.get("velocidade", 200)) * arena.stat("velocidade_proj")
	return s


func atualizar(dt: float) -> void:
	_t += dt
	var jog: Node2D = arena.jogador
	for a in lista:
		var d := Dados.item(a.id)
		var s := _s(a)
		match str(d.get("tipo", "")):
			"projetil":
				a.t -= dt
				if a.t <= 0:
					a.t = maxf(0.1, s.recarga)
					_atirar(a, d, s)
			"chicote":
				a.t -= dt
				if a.t <= 0:
					a.t = maxf(0.15, s.recarga)
					for i in s.quantidade:
						_fila.append({"t": i * 0.12, "arma": a, "lado": jog.lado * (1 if i % 2 == 0 else -1)})
			"orbita":
				if a.ativo > 0:
					a.ativo -= dt
					_orbita(a, s)
					if a.ativo <= 0:
						a.t = s.recarga
				else:
					a.t -= dt
					if a.t <= 0:
						a.ativo = s.duracao
						a.acertos = {}
			"poca":
				a.t -= dt
				if a.t <= 0:
					a.t = maxf(0.3, s.recarga)
					_derramar(a, d, s)
			"aura":
				a.tique -= dt
				if a.tique <= 0:
					a.tique = maxf(0.15, float(s.get("tique", 0.5)))
					_aura(a, s)
	_chicotes(dt)
	_projeteis(dt)
	_pocas(dt)
	for g in golpes.duplicate():
		g.t -= dt
		if g.t <= 0:
			golpes.erase(g)
	queue_redraw()


# ---------- projétil ----------

func _atirar(a: Dictionary, d: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = arena.jogador
	var origem: Vector2 = jog.centro()
	var alvos: Array = arena.inimigos.n_mais_perto(origem, s.quantidade, 380)
	for i in s.quantidade:
		var dir: Vector2
		if alvos.is_empty():
			dir = Vector2(jog.lado, 0).rotated(randf_range(-0.3, 0.3))
		else:
			var alvo = alvos[i % alvos.size()]
			dir = (alvo.pos - origem).normalized()
			if i >= alvos.size():
				dir = dir.rotated(randf_range(-0.25, 0.25))
		projeteis.append({"pos": origem, "vel": dir * s.velocidade, "dano": s.dano, "perfura": int(s.get("perfura", 1)),
			"vida": s.duracao, "tex": Dados.tex(str(d.get("sprite", "proj_pendrive"))), "esc": s.area,
			"acertou": [], "arma": a.id})
	Som.tocar("cursor", 0.08, 1.4, -10)


func _projeteis(dt: float) -> void:
	for p in projeteis.duplicate():
		p.pos += p.vel * dt
		p.vida -= dt
		if p.vida <= 0:
			projeteis.erase(p)
			continue
		for v in arena.inimigos.no_circulo(p.pos, 6.0 * p.esc):
			if v.id in p.acertou:
				continue
			p.acertou.append(v.id)
			arena.inimigos.ferir(v, p.dano, p.vel.normalized() * 60.0, p.arma)
			p.perfura -= 1
			if p.perfura <= 0:
				projeteis.erase(p)
				break


# ---------- chicote ----------

func _chicotes(dt: float) -> void:
	for f in _fila.duplicate():
		f.t -= dt
		if f.t > 0:
			continue
		_fila.erase(f)
		if not f.arma in lista:
			continue
		var a: Dictionary = f.arma
		var s := _s(a)
		var jog: Node2D = arena.jogador
		var alcance: float = float(s.get("alcance", 100)) * s.area
		var larg: float = float(s.get("largura", 30)) * s.area
		var c: Vector2 = jog.centro() + Vector2(f.lado * (alcance / 2 + 6), 0)
		var curou := 0
		for v in arena.inimigos.no_circulo(c, alcance / 2):
			if absf(v.pos.y - c.y) <= larg / 2 + v.raio:
				arena.inimigos.ferir(v, s.dano, Vector2(f.lado * 120, 0), a.id)
				if s.has("rouba_vida") and curou < 5:
					jog.curar(float(s.rouba_vida))
					curou += 1
		golpes.append({"pos": jog.centro(), "lado": f.lado, "alcance": alcance, "largura": larg, "t": 0.16, "arma": a.id})
		Som.tocar("whoosh", 0.05, 1.6, -8)


# ---------- órbita ----------

func _orbita(a: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = arena.jogador
	var r: float = float(s.get("raio", 60)) * s.area
	for i in s.quantidade:
		var p: Vector2 = jog.centro() + Vector2.from_angle(_t * float(s.get("giro", 3)) + TAU * i / s.quantidade) * r
		for v in arena.inimigos.no_circulo(p, 9.0 * s.area):
			var prox: float = a.acertos.get(v.id, 0.0)
			if _t >= prox:
				a.acertos[v.id] = _t + 0.5
				arena.inimigos.ferir(v, s.dano, (v.pos - jog.centro()).normalized() * 90.0, a.id)
	if a.acertos.size() > 600:
		a.acertos = {}


# ---------- poça ----------

func _derramar(a: Dictionary, d: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = arena.jogador
	for i in s.quantidade:
		var alvo = arena.inimigos.aleatorio_na_tela(jog.centro())
		var p: Vector2 = alvo.pos if alvo else jog.centro() + Vector2.from_angle(randf() * TAU) * randf_range(40, 140)
		pocas.append({"pos": p, "raio": float(s.get("raio", 40)) * s.area, "vida": s.duracao, "total": s.duracao,
			"dano": s.dano, "tique": float(s.get("tique", 0.4)), "t": 0.0, "segue": bool(d.get("base", {}).get("segue", false)),
			"arma": a.id})
	Som.tocar("queda", 0.2, 1.5, -10)


func _pocas(dt: float) -> void:
	for p in pocas.duplicate():
		p.vida -= dt
		p.t -= dt
		if p.segue:
			p.pos = p.pos.move_toward(arena.jogador.centro(), 40.0 * dt)
		if p.t <= 0:
			p.t = p.tique
			for v in arena.inimigos.no_circulo(p.pos, p.raio * 0.85):
				arena.inimigos.ferir(v, p.dano, Vector2.ZERO, p.arma)
		if p.vida <= 0:
			pocas.erase(p)


# ---------- aura ----------

func _aura(a: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = arena.jogador
	var r: float = float(s.get("raio", 50)) * s.area
	for v in arena.inimigos.no_circulo(jog.centro(), r):
		if s.has("lentidao"):
			v.lento = 0.8
		arena.inimigos.ferir(v, s.dano, (v.pos - jog.centro()).normalized() * float(s.get("empurra", 40)), a.id)


# ---------- desenho ----------

func _draw() -> void:
	var jog: Node2D = arena.jogador
	for p in pocas:
		var alfa: float = clampf(p.vida / 0.4, 0.0, 1.0) * 0.55
		var cresce: float = clampf((p.total - p.vida) / 0.15, 0.3, 1.0)
		var cor := Color(0.45, 0.25, 0.1, alfa) if p.arma == "cafe" else Color(0.75, 0.2, 0.25, alfa)
		draw_set_transform(p.pos, 0, Vector2(1, 0.6))
		draw_circle(Vector2.ZERO, p.raio * cresce, cor)
		draw_arc(Vector2.ZERO, p.raio * cresce, 0, TAU, 24, Color(0.3, 0.15, 0.05, alfa), 2)
		for i in 3:
			var ang := _t * 1.5 + i * 2.1
			draw_circle(Vector2.from_angle(ang) * p.raio * 0.5 + Vector2(0, -fmod(_t * 30 + i * 10, 30)), 2, Color(1, 1, 1, alfa * 0.6))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for a in lista:
		var d := Dados.item(a.id)
		var tipo := str(d.get("tipo", ""))
		if tipo == "aura":
			var s := _s(a)
			var r: float = float(s.get("raio", 50)) * s.area
			var pulso := 0.5 + 0.5 * sin(_t * 4.0)
			var cor := Color(0.3, 0.75, 1.0) if a.id == "wifi" else Color(0.5, 1.0, 0.6)
			draw_circle(jog.centro(), r, Color(cor, 0.08 + 0.04 * pulso))
			for k in 3:
				var rr := fmod(_t * 40.0 + k * r / 3.0, r)
				draw_arc(jog.centro(), rr, 0, TAU, 32, Color(cor, 0.35 * (1.0 - rr / r)), 1.5)
		elif tipo == "orbita" and a.ativo > 0:
			var s := _s(a)
			var tex := Dados.tex(str(d.get("sprite", "proj_ventoinha")))
			var r: float = float(s.get("raio", 60)) * s.area
			var sz: Vector2 = tex.get_size() * ESCALA * s.area * 0.8
			for i in s.quantidade:
				var p: Vector2 = jog.centro() + Vector2.from_angle(_t * float(s.get("giro", 3)) + TAU * i / s.quantidade) * r
				draw_set_transform(p, _t * 12.0, Vector2.ONE)
				draw_texture_rect(tex, Rect2(-sz / 2, sz), false)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for g in golpes:
		var alfa: float = g.t / 0.16
		var x0: float = g.pos.x + g.lado * 8
		var pts := PackedVector2Array()
		for i in 13:
			var f := i / 12.0
			pts.append(Vector2(x0 + g.lado * g.alcance * f, g.pos.y + sin(f * 9.0 + _t * 30.0) * g.largura * 0.25 * (1.0 - absf(f - 0.5))))
		if g.arma == "fibra_optica":
			for k in 3:
				var cores := [Color(1, 0.3, 0.8), Color(0.4, 0.9, 1), Color(1, 0.95, 0.4)]
				var desl := PackedVector2Array()
				for p in pts:
					desl.append(p + Vector2(0, (k - 1) * 3))
				draw_polyline(desl, Color(cores[k], alfa), 2)
		else:
			draw_polyline(pts, Color(0.95, 0.8, 0.25, alfa), 3)
			draw_polyline(pts, Color(1, 1, 0.8, alfa), 1)
		draw_rect(Rect2(Vector2(minf(x0, x0 + g.lado * g.alcance), g.pos.y - g.largura / 2), Vector2(g.alcance, g.largura)), Color(1, 1, 0.7, alfa * 0.12))
	for p in projeteis:
		var tex: Texture2D = p.tex
		var sz: Vector2 = tex.get_size() * ESCALA * p.esc
		draw_set_transform(p.pos, p.vel.angle(), Vector2.ONE)
		draw_texture_rect(tex, Rect2(-sz / 2, sz), false)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
