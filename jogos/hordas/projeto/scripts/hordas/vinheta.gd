extends CanvasLayer
## Vinheta (estilo Dimraeth): as bordas da tela escurecem e o olho vai pro meio, onde está o herói.
## Entre o mundo e o HUD (acima da escuridão do horror, layer 1; abaixo do HUD, layer 5). Opções > Gráfico > "Vinheta".

const FORCA := 0.55  # opacidade do preto nos cantos

var _rect := TextureRect.new()


func _ready() -> void:
	layer = 2
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.12), Color(0, 0, 0, FORCA)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 0.5)  # passa um pouco da borda: o meio da tela fica limpo
	t.width = 128
	t.height = 128
	_rect.texture = t
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func _process(_dt: float) -> void:
	visible = bool(Config.g("vinheta"))
