extends Control
## Fundo vivo da tela de título (v2/menu_principal.gd): a arte assets/titulo/fundo.png com a câmera andando devagar e reagindo ao
## mouse, e por cima dela o que dá vida à cena. O shader (v2/titulo_fundo.gdshader) faz a lua, as nuvens, a névoa, a água e o clarão;
## aqui ficam as brasas do santuário em chamas, os espíritos do pântano, as folhas vermelhas caindo, as lanternas tremendo, os olhos
## que piscam na mata, os corvos que cruzam o céu e o relâmpago. Pensado para o PC fraco: um shader de uma passada e menos de 70
## partículas de CPU. As posições são em pixels da arte (960x540); o nó `_efeitos` acompanha o zoom e a deriva do shader.

const EscalaUi := preload("res://v2/escala_ui.gd")
const Piscadas := preload("res://v2/piscadas.gd")  # "Reduzir piscadas": as lanternas ficam com alfa parado
const ARTE := preload("res://assets/titulo/fundo.png")
const SHADER := preload("res://v2/titulo_fundo.gdshader")
const TAM_ARTE := Vector2(960, 540)
const LANTERNAS := [Vector2(38, 264), Vector2(110, 329), Vector2(131, 296), Vector2(242, 318), Vector2(292, 330)]
const OLHOS := [[Vector2(467, 262), Vector2(474, 262)], [Vector2(880, 281), Vector2(888, 281)]]
const COR_CORVO := Color(0.02, 0.02, 0.05)
const COR_RAIO := Color(0.86, 0.9, 1.0)

var _fundo: TextureRect
var _mat: ShaderMaterial
var _efeitos: Node2D
var _lanternas: Array[Sprite2D] = []
var _olhos: Array[Node2D] = []
var _olho_t: Array[float] = []
var _corvos: Node2D
var _raio: Line2D
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _paralaxe := Vector2.ZERO
var _proximo_raio := 7.0
var _raio_t := -1.0  # s desde o começo do relâmpago; < 0 = sem relâmpago
var _proximo_corvo := 3.0
var _tam_antes := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	EscalaUi.cobrir(self)
	_rng.randomize()
	_fundo = TextureRect.new()
	_fundo.texture = ARTE
	_fundo.stretch_mode = TextureRect.STRETCH_SCALE
	_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("ruido", _ruido())
	_fundo.material = _mat
	add_child(_fundo)
	_efeitos = Node2D.new()
	add_child(_efeitos)
	for p in LANTERNAS:
		var s := _brilho(p, Color(1.0, 0.55, 0.2), 30)
		_lanternas.append(s)
	for par in OLHOS:
		var no := Node2D.new()
		_efeitos.add_child(no)
		for p in par:
			_brilho(p, Color(1.0, 0.12, 0.08), 7).reparent(no)
		_olhos.append(no)
		_olho_t.append(_rng.randf_range(1.0, 5.0))
	_efeitos.add_child(_brasas())
	_efeitos.add_child(_espiritos())
	_efeitos.add_child(_folhas())
	_corvos = Node2D.new()
	_efeitos.add_child(_corvos)
	_raio = Line2D.new()
	_raio.width = 2.0
	_raio.default_color = COR_RAIO
	_raio.material = _aditivo()
	_raio.visible = false
	var halo := Line2D.new()  # o halo azulado em volta do raio
	halo.width = 7.0
	halo.default_color = Color(0.45, 0.55, 1.0, 0.3)
	halo.material = _aditivo()
	halo.show_behind_parent = true
	_raio.add_child(halo)
	_efeitos.add_child(_raio)
	_encaixar()


func _process(dt: float) -> void:
	_t += dt
	if size != _tam_antes:
		_encaixar()
	var mouse := get_local_mouse_position() / maxf(size.x, 1.0) - Vector2(0.5, 0.5)
	_paralaxe = _paralaxe.lerp(-mouse * 0.01, clampf(dt * 2.0, 0.0, 1.0))
	var deriva := Vector2(0.006 * sin(_t * 0.031), 0.003 * sin(_t * 0.043)) + _paralaxe
	var zoom := 1.035 + 0.01 * sin(_t * 0.05)
	_mat.set_shader_parameter("zoom", zoom)
	_mat.set_shader_parameter("deriva", deriva)
	var k := _fundo.size.x / TAM_ARTE.x
	_efeitos.scale = Vector2.ONE * k * zoom
	_efeitos.position = _fundo.position + _fundo.size * (Vector2(0.5, 0.5) - (Vector2(0.5, 0.5) + deriva) * zoom)
	_animar_lanternas()
	_animar_olhos(dt)
	_animar_corvos(dt)
	_animar_raio(dt)


## A arte cobre o retângulo inteiro sem distorcer (o que sobra fica fora da tela).
func _encaixar() -> void:
	_tam_antes = size
	var k := maxf(size.x / TAM_ARTE.x, size.y / TAM_ARTE.y)
	_fundo.size = TAM_ARTE * k
	_fundo.position = (size - _fundo.size) / 2.0


# ------------------------------------------------------------------ peças


## Ruído sem emenda para o shader (nuvens, névoa e água): gerado uma vez, 256 px.
func _ruido() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	return tex


func _aditivo() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## Mancha de luz redonda e pixelada (aditiva), para lanternas e olhos.
func _brilho(pos: Vector2, cor: Color, lado: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _textura_mancha(lado)
	s.position = pos
	s.modulate = cor
	s.material = _aditivo()
	_efeitos.add_child(s)
	return s


func _textura_mancha(lado: int) -> ImageTexture:
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var c := (lado - 1) / 2.0
	for y in lado:
		for x in lado:
			var d := Vector2(x - c, y - c).length() / (c + 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = floorf(a * a * 5.0 + 0.5) / 5.0  # em degraus: luz de pixel art
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _textura_pixel(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _rampa(cores: Array, pontos: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(pontos)
	g.colors = PackedColorArray(cores)
	return g


## Brasas subindo do santuário em chamas (esquerda).
func _brasas() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 4.5
	p.preprocess = 4.5
	p.texture = _textura_pixel(2, 2)
	p.position = Vector2(170, 330)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(170, 110)
	p.direction = Vector2(0.2, -1.0)
	p.spread = 22.0
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 30.0
	p.gravity = Vector2(6, -8)
	p.tangential_accel_min = -6.0
	p.tangential_accel_max = 6.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var cores := [Color(1, 0.9, 0.5, 0), Color(1, 0.85, 0.4, 1), Color(1, 0.38, 0.08, 0.85), Color(0.6, 0.1, 0.05, 0)]
	p.color_ramp = _rampa(cores, [0.0, 0.1, 0.6, 1.0])
	p.material = _aditivo()
	return p


## Espíritos azulados vagando sobre o pântano (direita).
func _espiritos() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 14
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.texture = _textura_mancha(11)
	p.position = Vector2(780, 385)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(170, 70)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector2(0, -2)
	p.tangential_accel_min = -5.0
	p.tangential_accel_max = 5.0
	var cores := [Color(0.5, 0.95, 1, 0), Color(0.55, 0.95, 1, 0.9), Color(0.4, 0.7, 1, 0.6), Color(0.3, 0.5, 1, 0)]
	p.color_ramp = _rampa(cores, [0.0, 0.25, 0.7, 1.0])
	p.material = _aditivo()
	return p


## Folhas vermelhas caindo de cima, levadas pelo vento.
func _folhas() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 16
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.texture = _textura_pixel(3, 2)
	p.position = Vector2(420, -12)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(540, 4)
	p.direction = Vector2(0.45, 1.0)
	p.spread = 18.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector2(5, 5)
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.color_initial_ramp = _rampa([Color(0.55, 0.08, 0.06), Color(0.9, 0.32, 0.1)], [0.0, 1.0])
	p.color_ramp = _rampa([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.08, 0.85, 1.0])
	return p


# ------------------------------------------------------------------ animação


func _animar_lanternas() -> void:
	for i in _lanternas.size():
		var f := 0.42 + 0.1 * sin(_t * 7.3 + i * 1.7) + 0.06 * sin(_t * 13.1 + i * 4.1)
		_lanternas[i].modulate.a = Piscadas.valor(f, 0.42)  # tremeluz até 2,1 Hz; com a opção, o centro


## Olhos que brilham na mata e piscam de vez em quando.
func _animar_olhos(dt: float) -> void:
	for i in _olhos.size():
		_olho_t[i] -= dt
		var aberto := _olho_t[i] > 0.0 or _olho_t[i] < -0.14
		if _olho_t[i] < -0.14:
			_olho_t[i] = _rng.randf_range(2.0, 6.0)
		_olhos[i].modulate.a = (0.75 + 0.25 * sin(_t * 1.3 + i)) if aberto else 0.0


## Corvos cruzando o céu da direita para a esquerda, em bando de 1 a 3, batendo as asas.
func _animar_corvos(dt: float) -> void:
	_proximo_corvo -= dt
	if _proximo_corvo <= 0.0:
		_proximo_corvo = _rng.randf_range(8.0, 15.0)
		var y := _rng.randf_range(30.0, 130.0)
		var vel := _rng.randf_range(38.0, 58.0)
		for j in _rng.randi_range(1, 3):
			var c := Node2D.new()
			c.position = Vector2(TAM_ARTE.x + 20.0 + j * 14.0, y + j * 7.0)
			c.set_meta("vel", vel)
			c.set_meta("fase", _rng.randf() * TAU)
			c.draw.connect(_desenhar_corvo.bind(c))
			_corvos.add_child(c)
	for c in _corvos.get_children():
		c.position.x -= float(c.get_meta("vel")) * dt
		c.position.y += sin(_t * 2.0 + float(c.get_meta("fase"))) * 6.0 * dt
		c.queue_redraw()
		if c.position.x < -30.0:
			c.queue_free()


func _desenhar_corvo(c: Node2D) -> void:
	var cima := fmod(_t * 7.0 + float(c.get_meta("fase")), 2.0) < 1.0
	var a := -4.0 if cima else 3.0
	var asa := PackedVector2Array([Vector2(-9, a), Vector2(-5, a * 0.3), Vector2(-2, 0), Vector2(0, 1)])
	var outra := PackedVector2Array([Vector2(9, a), Vector2(5, a * 0.3), Vector2(2, 0), Vector2(0, 1)])
	c.draw_polyline(asa, COR_CORVO, 2.0)
	c.draw_polyline(outra, COR_CORVO, 2.0)
	c.draw_rect(Rect2(-2, -1, 5, 3), COR_CORVO)
	c.draw_rect(Rect2(-4, 0, 2, 1), COR_CORVO)  # o bico, para a esquerda (o corvo voa para lá)


## Relâmpago ao longe: o céu pisca duas vezes e um raio risca o fundo.
func _animar_raio(dt: float) -> void:
	_proximo_raio -= dt
	if _proximo_raio <= 0.0 and _raio_t < 0.0:
		_proximo_raio = _rng.randf_range(12.0, 24.0)
		_raio_t = 0.0
		_raio.points = _caminho_raio()
		(_raio.get_child(0) as Line2D).points = _raio.points
	if _raio_t < 0.0:
		return
	_raio_t += dt
	var k := _clarao(_raio_t)
	_mat.set_shader_parameter("clarao", k)
	_raio.visible = _raio_t < 0.3
	_raio.modulate.a = clampf(k * 1.4, 0.0, 1.0)
	if _raio_t > 0.5:
		_raio_t = -1.0
		_raio.visible = false
		_mat.set_shader_parameter("clarao", 0.0)


## O brilho do relâmpago no tempo `t`: sobe, cai, pisca de novo e some.
func _clarao(t: float) -> float:
	if t < 0.03:
		return t / 0.03
	if t < 0.09:
		return lerpf(1.0, 0.2, (t - 0.03) / 0.06)
	if t < 0.13:
		return lerpf(0.2, 0.75, (t - 0.09) / 0.04)
	return maxf(0.0, lerpf(0.75, 0.0, (t - 0.13) / 0.32))


func _caminho_raio() -> PackedVector2Array:
	var p := Vector2(_rng.randf_range(360.0, 700.0), 0.0)
	var r := PackedVector2Array([p])
	var fim := _rng.randf_range(110.0, 170.0)
	while p.y < fim:
		p += Vector2(_rng.randf_range(-7.0, 7.0), _rng.randf_range(6.0, 12.0))
		r.append(p.round())
	return r
