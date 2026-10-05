class_name Animacao
## Motor de animação do JOGO.
##
## As animações ficam em capitulos/animacoes.json (dá pra editar sem mexer no código).
## Cada uma é uma lista de passos que mexem no corpo do personagem (inclinar, esticar,
## pular, cair, ser empurrado...) e disparam som, tremor, partículas e balões.
## Quando a folha de quadros desenhados (assets/personagens/<id>/acoes.png) existir,
## a versão "arte" da animação é usada no lugar da "passos" (a provisória).
##
## No roteiro:  !anim lucas cair     !anim nicao soco lucas     !briga lucas nicao 2 nicao
##              !porta abrir laboratorio

static var _defs: Dictionary = {}


static func defs() -> Dictionary:
	if _defs.is_empty():
		var d = Dados.ler_json("animacoes.json")
		_defs = d if d is Dictionary else {}
	return _defs


static func limpar() -> void:
	_defs = {}


## Como é a folha acoes.png: tamanho do quadro, colunas, âncora (pé) e as linhas,
## cada uma uma ação: {"linha": 2, "quadros": 8, "fps": 10, "repete": false, "vista": "lado"}.
static func folha() -> Dictionary:
	return defs().get("folha_acoes", {})


## Dados de uma linha da folha ("cair") ou {} se não existir.
static func linha(nome: String) -> Dictionary:
	var l = folha().get("linhas", {}).get(nome.get_slice(":", 0))
	return l if l is Dictionary else {}


static func existe(nome: String) -> bool:
	return defs().get("animacoes", {}).has(Roteiro.sem_acento(nome.to_lower()))


## Escolhe os passos certos pra esse personagem: "arte" se ele tiver todos os quadros
## desenhados, senão "passos" (a versão provisória, só mexendo no sprite de andar).
static func resolver(pers: Node2D, nome: String) -> Dictionary:
	var todas: Dictionary = defs().get("animacoes", {})
	var a = todas.get(Roteiro.sem_acento(nome.to_lower()))
	if not a is Dictionary:
		push_warning("Animação desconhecida: " + nome)
		return {}
	var passos: Array = a.get("passos", [])
	var arte = a.get("arte")
	if arte is Array and not arte.is_empty():
		var ok := true
		for k in arte:
			if k is Dictionary and k.has("quadro") and not str(k.quadro).begins_with("andar"):
				var l := linha(str(k.quadro))
				if l.is_empty() or Dados.textura(pers.id, str(l.get("folha", "acoes"))) == null:
					ok = false
		if ok:
			passos = arte
	return {"passos": passos, "manter": bool(a.get("manter", false))}


## Começa a animação sem esperar ela acabar (pra esperar, use pers.anim()).
static func tocar(pers: Node2D, nome: String, mundo: Node = null, alvo: Node2D = null) -> void:
	if pers and pers.has_method("anim"):
		pers.anim(nome, mundo, alvo)


# ======================================================== partículas de impacto

## Estouro rápido de partículas num ponto: poeira, estrelas, brilhos, suor, pancada.
static func estouro(tipo: String, pai: Node, pos: Vector2) -> void:
	if pai == null:
		return
	var c := CPUParticles2D.new()
	c.position = pos
	c.one_shot = true
	c.explosiveness = 1.0
	c.z_index = 45
	c.local_coords = false
	match tipo:
		"poeira":
			c.amount = 14
			c.lifetime = 0.6
			c.direction = Vector2(0, -1)
			c.spread = 90
			c.initial_velocity_min = 15
			c.initial_velocity_max = 40
			c.gravity = Vector2(0, 30)
			c.damping_min = 30
			c.damping_max = 50
			c.scale_amount_min = 1.0
			c.scale_amount_max = 3.0
			c.color_ramp = _rampa([Color(0.95, 0.92, 0.85, 0.8), Color(0.9, 0.88, 0.8, 0)])
		"estrelas":
			c.amount = 7
			c.lifetime = 0.7
			c.direction = Vector2(0, -1)
			c.spread = 70
			c.initial_velocity_min = 30
			c.initial_velocity_max = 60
			c.gravity = Vector2(0, 90)
			c.scale_amount_min = 2.0
			c.scale_amount_max = 3.0
			c.color_ramp = _rampa([Color(1, 0.9, 0.3, 1), Color(1, 0.7, 0.2, 0)])
		"brilhos":
			c.amount = 12
			c.lifetime = 0.8
			c.spread = 180
			c.initial_velocity_min = 10
			c.initial_velocity_max = 30
			c.gravity = Vector2(0, -10)
			c.color_ramp = _rampa([Color(1, 1, 0.8, 1), Color(1, 0.85, 0.4, 0)])
			c.scale_amount_min = 1.0
			c.scale_amount_max = 2.0
		"suor":
			c.amount = 5
			c.lifetime = 0.5
			c.direction = Vector2(0, -1)
			c.spread = 50
			c.initial_velocity_min = 20
			c.initial_velocity_max = 35
			c.gravity = Vector2(0, 120)
			c.scale_amount_min = 1.0
			c.scale_amount_max = 2.0
			c.color = Color(0.5, 0.75, 1, 0.9)
			c.position += Vector2(0, -50)
		_:  # "pancada"
			c.amount = 8
			c.lifetime = 0.25
			c.spread = 180
			c.initial_velocity_min = 40
			c.initial_velocity_max = 70
			c.gravity = Vector2.ZERO
			c.scale_amount_min = 1.0
			c.scale_amount_max = 2.0
			c.color = Color(1, 1, 1, 1)
			c.position += Vector2(0, -34)
	pai.add_child(c)
	c.emitting = true
	pai.get_tree().create_timer(c.lifetime + 0.3).timeout.connect(c.queue_free)


static func _rampa(cores: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray(cores)
	return g


# ======================================================== nuvem de briga

## A clássica nuvem de poeira de desenho animado: os dois somem dentro dela, aparecem
## punhos, pés, estrelas e onomatopeias, e no fim ela se desfaz.
class Briga extends Node2D:
	var cores: Array = [Color("1a2050"), Color("f3c79a")]   # farda e pele, pros braços
	var _t := 0.0
	var _proximo := 0.0
	var _bolas: Array = []      # [centro, raio, fase]
	var _membros: Array = []    # [pos, dir, vida, tipo]
	var _textos: Array = []     # Labels POW/PAF

	func _ready() -> void:
		for i in 9:
			var a := TAU * i / 9.0
			_bolas.append([Vector2(cos(a) * 16, sin(a) * 10 - 22), randf_range(9, 13), randf() * TAU])
		_bolas.append([Vector2(0, -22), 16.0, 0.0])

	func _process(delta: float) -> void:
		_t += delta
		position.x += sin(_t * 9.0) * 0.6
		_proximo -= delta
		if _proximo <= 0.0:
			_proximo = randf_range(0.08, 0.2)
			var a := randf() * TAU
			_membros.append([Vector2(cos(a) * 18, sin(a) * 12 - 22), Vector2(cos(a), sin(a)), 0.18, randi() % 3])
			if randf() < 0.55:
				Jogo.som("soco", -3.0, 0.2)
			if randf() < 0.3:
				_onomatopeia()
		for m in _membros:
			m[2] -= delta
		_membros = _membros.filter(func(m): return m[2] > 0.0)
		queue_redraw()

	func _onomatopeia() -> void:
		var l := Label.new()
		l.text = ["POW!", "PAF!", "TUM!", "SOC!", "AI!", "PLAW!"].pick_random()
		l.add_theme_color_override("font_color", Color("ffd34e"))
		l.add_theme_color_override("font_outline_color", Color("1a2050"))
		l.add_theme_constant_override("outline_size", 4)
		l.position = Vector2(randf_range(-40, 20), randf_range(-60, -30))
		l.z_index = 5
		add_child(l)
		l.scale = Vector2(0.4, 0.4)
		var tw := l.create_tween()
		tw.tween_property(l, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.25)
		tw.tween_property(l, "modulate:a", 0.0, 0.15)
		tw.tween_callback(l.queue_free)

	func _draw() -> void:
		draw_set_transform(Vector2(0, -1), 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, 30, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2.ZERO)
		# contorno, depois o miolo da nuvem
		for b in _bolas:
			var c: Vector2 = b[0] + Vector2(sin(_t * 14 + b[2]), cos(_t * 11 + b[2])) * 2.0
			draw_circle(c, b[1] + 2, Color("1a2050"))
		for b in _bolas:
			var c: Vector2 = b[0] + Vector2(sin(_t * 14 + b[2]), cos(_t * 11 + b[2])) * 2.0
			draw_circle(c, b[1], Color("cfc6b4"))
			draw_circle(c + Vector2(-2, -3), b[1] * 0.55, Color("e2dccd"))
		# braços e pernas saindo da nuvem
		for m in _membros:
			var p: Vector2 = m[0]
			var d: Vector2 = m[1]
			var fim: Vector2 = p + d * 12
			draw_line(p, fim, Color("1a2050"), 5)
			draw_line(p, fim, cores[0] if m[3] != 1 else Color("23285e"), 3)
			if m[3] == 0:
				draw_circle(fim, 4, Color("1a2050"))
				draw_circle(fim, 3, cores[1])
			else:
				draw_rect(Rect2(fim - Vector2(3, 2), Vector2(6, 4)), Color("1a2050"))
		# estrelinhas girando
		for i in 3:
			var a := _t * 6.0 + i * TAU / 3.0
			var c := Vector2(cos(a) * 26, sin(a) * 8 - 46)
			_estrela(c, 3.0, Color("ffd34e"))

	func _estrela(c: Vector2, r: float, cor: Color) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var rr := r if k % 2 == 0 else r * 0.45
			pts.append(c + Vector2.from_angle(-PI / 2 + k * TAU / 10) * rr)
		draw_colored_polygon(pts, cor)
