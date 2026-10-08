extends CanvasLayer
## Escuridão compatível com GLES2, em dois jeitos para medir lado a lado (sem Light2D: no GLES2 cada luz redesenha
## a cena; e sem ler a tela, que o shader original do PC faz com hint_screen_texture):
## 1 = BUFFER: um Viewport pequeno (metade da resolução em cada eixo) limpo com a cor ambiente, onde cada luz é um
##     gradiente radial somado (blend ADD); a textura dele cobre a tela multiplicando (blend MUL). Escala com muitas luzes.
## 2 = SHADER: um retângulo de tela cheia que calcula até 8 luzes por pixel (uniforms escalares, nada de array).

const MAX_BUFFER = 24
const MAX_SHADER = 8

var modo = 1
var ambiente = Color(0.16, 0.13, 0.26)
var luzes = []          # [Vector2 tela, raio, Color] já em coordenadas de tela, preenchido pelo main a cada quadro

var _vp: Viewport
var _pintor: Node2D
var _tela_buffer: TextureRect
var _tela_shader: ColorRect
var _grad: ImageTexture
var _base = Vector2(480, 272)
var _divisor = 2           # o buffer de luz tem base / _divisor (2 = metade por eixo = 1/4 da área)


func _ready() -> void:
	layer = 5
	_grad = _gradiente(64)
	_vp = Viewport.new()
	_vp.usage = Viewport.USAGE_2D
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_v_flip = true
	_vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	add_child(_vp)
	_pintor = Node2D.new()
	var add = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_pintor.material = add
	_pintor.connect("draw", self, "_pinta")
	_vp.add_child(_pintor)

	_tela_buffer = TextureRect.new()
	_tela_buffer.expand = true
	_tela_buffer.texture = _vp.get_texture()
	var mul = CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tela_buffer.material = mul
	_tela_buffer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tela_buffer)

	_tela_shader = ColorRect.new()
	var sm = ShaderMaterial.new()
	sm.shader = load("res://escuridao.shader")
	_tela_shader.material = sm
	_tela_shader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tela_shader)
	definir_base(_base)
	definir_modo(modo)


func definir_base(base: Vector2) -> void:
	_base = base
	_vp.size = (base / float(_divisor)).floor()
	_vp.get_texture().flags = Texture.FLAG_FILTER
	_tela_buffer.rect_size = base
	_tela_shader.rect_size = base


func definir_divisor(d: int) -> void:
	if d != _divisor:
		_divisor = d
		definir_base(_base)


func definir_modo(m: int) -> void:
	modo = m
	_vp.render_target_update_mode = Viewport.UPDATE_ALWAYS if m == 1 else Viewport.UPDATE_DISABLED
	_tela_buffer.visible = m == 1
	_tela_shader.visible = m == 2


func atualizar() -> void:
	if modo == 1:
		_pintor.update()
	elif modo == 2:
		var sm: ShaderMaterial = _tela_shader.material
		sm.set_shader_param("ambiente", Vector3(ambiente.r, ambiente.g, ambiente.b))
		sm.set_shader_param("tela", _base)
		for k in MAX_SHADER:
			var v = Vector3(-9999, -9999, 1)
			var c = Color(0, 0, 0)
			if k < luzes.size():
				v = Vector3(luzes[k][0].x, luzes[k][0].y, luzes[k][1])
				c = luzes[k][2]
			sm.set_shader_param("l%d" % k, v)
			sm.set_shader_param("c%d" % k, Vector3(c.r, c.g, c.b))


func _pinta() -> void:
	var tam = _vp.size
	_pintor.draw_rect(Rect2(Vector2.ZERO, tam), ambiente)
	var esc = tam.x / _base.x
	for k in min(luzes.size(), MAX_BUFFER):
		var l: Array = luzes[k]
		var r: float = l[1] * esc
		_pintor.draw_texture_rect(_grad, Rect2(l[0] * esc - Vector2(r, r), Vector2(r, r) * 2.0), false, l[2])


func _gradiente(lado: int) -> ImageTexture:
	var img = Image.new()
	img.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.lock()
	var m = (lado - 1) * 0.5
	for y in lado:
		for x in lado:
			var d = clamp(Vector2(x - m, y - m).length() / m, 0.0, 1.0)
			var a = pow(1.0 - d, 1.6)
			img.set_pixel(x, y, Color(a, a, a, 1.0))
	img.unlock()
	var t = ImageTexture.new()
	t.create_from_image(img, Texture.FLAG_FILTER)
	return t
