extends Control
## Fundo do Códice. A animação em vídeo e a arte de reserva cobrem a janela na mesma proporção.

const EscalaUi := preload("res://v2/escala_ui.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const ARTE := preload("res://assets/titulo/codice.png")
const SHADER := preload("res://v2/titulo_codice.gdshader")
const VIDEO := preload("res://assets/titulo/codice_loop.ogv")
const TAM := Vector2(960, 540)
const LANTERNA := Vector2(735, 404)

var _fundo: TextureRect
var _mat: ShaderMaterial
var _particulas: Node2D
var _video: VideoStreamPlayer
var _tem_tela := false
var _usar_video := false
var _tempo := 0.0
var _luz_suave := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	EscalaUi.cobrir(self)
	_fundo = TextureRect.new()
	_fundo.texture = ARTE
	_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo.stretch_mode = TextureRect.STRETCH_SCALE
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_fundo.material = _mat
	add_child(_fundo)
	_particulas = Node2D.new()
	_particulas.draw.connect(_desenhar_particulas)
	add_child(_particulas)
	_video = VideoStreamPlayer.new()
	_video.stream = VIDEO
	_video.expand = true
	_video.loop = true
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.focus_mode = Control.FOCUS_NONE
	_video.hide()
	add_child(_video)
	_tem_tela = DisplayServer.get_name() != "headless"
	resized.connect(_encaixar)
	_encaixar()


func _process(delta: float) -> void:
	_luz_suave = Piscadas.ligado()
	# A arte de reserva cobre o tempo até o primeiro quadro e preserva a opção Reduzir piscadas.
	var usar_video := _tem_tela and is_visible_in_tree() and not _luz_suave
	if usar_video != _usar_video:
		_usar_video = usar_video
		if _usar_video:
			_video.play()
		else:
			_video.stop()
	var quadro_pronto := _video.is_playing() and (_video.visible or _video.stream_position > 0.0)
	if quadro_pronto != _video.visible:
		_video.visible = quadro_pronto
		_fundo.visible = not quadro_pronto
		_particulas.visible = not quadro_pronto
	if quadro_pronto:
		return
	_tempo += delta
	_mat.set_shader_parameter("instante", _tempo)
	var luz := 0.69 if _luz_suave else 0.69 + 0.08 * sin(_tempo * 3.1) + 0.04 * sin(_tempo * 5.4)
	_mat.set_shader_parameter("luz", luz)
	_particulas.queue_redraw()


func _encaixar() -> void:
	var escala := maxf(size.x / TAM.x, size.y / TAM.y)
	_fundo.size = TAM * escala
	_fundo.position = ((size - _fundo.size) * 0.5).round()
	_particulas.position = _fundo.position
	_particulas.scale = Vector2.ONE * escala
	_video.position = _fundo.position
	_video.size = _fundo.size


static func _retangulo_pixel(ponto: Vector2, tamanho: Vector2i) -> Rect2:
	return Rect2(ponto.round(), Vector2(tamanho))


func _desenhar_particulas() -> void:
	# Folhas atravessam apenas a área ilustrada. A trilha é contínua, com entrada e saída graduais.
	for i in 14:
		var fase := fposmod(_tempo * (0.062 + 0.008 * float(i % 4)) + float(i) * 0.177, 1.0)
		var ponto := Vector2(940 - 480 * fase, 14 + 102 * float(i % 5) + 65 * fase + 9 * sin(fase * 17 + i))
		var alfa := sin(PI * fase) * 0.65
		var altura := 1 if int(fase * 22 + i) % 2 == 0 else 2
		_particulas.draw_rect(_retangulo_pixel(ponto, Vector2i(3, altura)), Color(0.63, 0.29, 0.12, alfa))
	# Vaga-lumes próximos do chão, com brilho lento e fora da coluna dos botões.
	for i in 10:
		var t := _tempo * (0.53 + 0.06 * float(i % 4)) + float(i) * 2.4
		var centro := Vector2(494 + float(i) * 37, 383 + 21 * float(i % 5))
		var ponto := centro + Vector2(15 * sin(t), 11 * cos(t * 0.67))
		var alfa := 0.62 if _luz_suave else 0.39 + 0.27 * sin(t + float(i))
		_particulas.draw_rect(_retangulo_pixel(ponto - Vector2.ONE, Vector2i(4, 4)), Color(0.73, 0.82, 0.34, alfa * 0.20))
		_particulas.draw_rect(_retangulo_pixel(ponto, Vector2i(2, 2)), Color(0.87, 0.92, 0.55, alfa))
	# Insetos fazem órbitas curtas, com asas desenhadas em pixels junto à lanterna.
	for i in 5:
		var t := _tempo * (1.48 + 0.17 * float(i)) + float(i) * 1.9
		var ponto := LANTERNA + Vector2(cos(t) * (14 + 4 * i), sin(t * 1.14) * (11 + 2 * i) - 12)
		var asa := 1 if _luz_suave or int(_tempo * 8.0 + i) % 2 == 0 else 2
		_particulas.draw_rect(_retangulo_pixel(ponto - Vector2(asa, 0), Vector2i(1 + asa * 2, 1)), Color(0.78, 0.62, 0.41, 0.54))
		_particulas.draw_rect(_retangulo_pixel(ponto + Vector2(0, -1), Vector2i(1, 3)), Color(0.82, 0.65, 0.49, 0.73))
