extends Node2D
## Chão infinito (azulejos que se repetem), enfeites espalhados e os santuários (tomadas).
## Santuário (ideia do Megabonk): fique dentro do círculo até carregar e ganhe uma carta.

const ESCALA := 2.0
const BLOCO := 256.0          # tamanho da textura do chão na tela (128 px x 2)
const CEL_DECO := 150.0

var arena: Node
var _fundo := TextureRect.new()
var santuarios: Array = []    # {pos, carga, usado}
var _t := 0.0
var _deco: Texture2D
var _deco_regioes := [Rect2(0, 0, 14, 18), Rect2(15, 6, 10, 12), Rect2(26, 12, 8, 6), Rect2(35, 6, 14, 12)]


func _ready() -> void:
	z_index = -10
	_fundo.texture = Dados.tex("chao")
	_fundo.stretch_mode = TextureRect.STRETCH_TILE
	_fundo.size = Vector2(1024, 768) / ESCALA
	_fundo.scale = Vector2(ESCALA, ESCALA)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.show_behind_parent = true
	add_child(_fundo)
	_deco = Dados.tex("deco")


func criar_santuarios() -> void:
	var fase: Dictionary = Dados.json("fase")
	for i in int(fase.get("santuarios", 6)):
		var a := TAU * i / float(fase.get("santuarios", 6)) + randf_range(-0.3, 0.3)
		santuarios.append({"pos": Vector2.from_angle(a) * randf_range(350, 900), "carga": 0.0, "usado": false})


func mais_perto_livre(p: Vector2):
	var melhor = null
	var md := INF
	for s in santuarios:
		if s.usado:
			continue
		var d: float = s.pos.distance_squared_to(p)
		if d < md:
			md = d
			melhor = s
	return melhor


func atualizar(dt: float) -> void:
	_t += dt
	var cam: Vector2 = arena.camera.position
	_fundo.position = Vector2(floorf((cam.x - 512) / BLOCO) * BLOCO, floorf((cam.y - 384) / BLOCO) * BLOCO)
	var tempo := float(Dados.json("fase").get("santuario_tempo", 4.0))
	for s in santuarios:
		if s.usado:
			continue
		if s.pos.distance_to(arena.jogador.position) < 48:
			s.carga += dt / tempo
			if s.carga >= 1.0:
				s.usado = true
				arena.ganhar_carta_tomada()
		else:
			s.carga = maxf(0.0, s.carga - dt / tempo * 0.5)
	queue_redraw()


func _draw() -> void:
	var cam: Vector2 = arena.camera.position
	# enfeites: posição sorteada por célula (sempre igual no mesmo lugar)
	var a := Vector2i(floori((cam.x - 380) / CEL_DECO), floori((cam.y - 240) / CEL_DECO))
	var b := Vector2i(floori((cam.x + 380) / CEL_DECO), floori((cam.y + 240) / CEL_DECO))
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var h := hash(Vector2i(cx, cy))
			if h % 100 >= 30:
				continue
			var reg: Rect2 = _deco_regioes[(h / 100) % _deco_regioes.size()]
			var p := Vector2(cx * CEL_DECO + (h / 7) % 110, cy * CEL_DECO + (h / 13) % 110)
			draw_texture_rect_region(_deco, Rect2(p, reg.size * ESCALA), reg, Color(1, 1, 1, 0.9))
	var tex := Dados.tex("tomada")
	for s in santuarios:
		var cor := Color(0.4, 0.6, 0.7, 0.5) if s.usado else Color(1.0, 0.85, 0.3, 0.8)
		draw_set_transform(s.pos, 0, Vector2(1, 0.55))
		draw_circle(Vector2.ZERO, 48, Color(cor, 0.12))
		draw_arc(Vector2.ZERO, 48, 0, TAU, 40, cor, 2)
		if s.carga > 0 and not s.usado:
			draw_arc(Vector2.ZERO, 44, -PI / 2, -PI / 2 + TAU * s.carga, 40, Color(0.5, 1.0, 0.5), 4)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var sz := tex.get_size() * ESCALA
		var flut := 0.0 if s.usado else sin(_t * 3.0) * 2.0
		draw_texture_rect(tex, Rect2(s.pos - Vector2(sz.x / 2, sz.y) + Vector2(0, flut), sz), false, Color(0.6, 0.6, 0.6) if s.usado else Color.WHITE)
