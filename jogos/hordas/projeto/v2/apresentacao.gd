extends Node
## Apresentação da v2 (extraída do protótipo cara_nova): o mundo é desenhado num SubViewport de 960x540 (filtro nearest) e mostrado numa
## TextureRect do tamanho da janela com o shader "sharp bilinear": escala inteira em nearest + só 1 px de tela de transição nas bordas
## dos texels. Com escala fracionária (1,33x, 1,6x, 1,87x...) todos os pixels têm o mesmo tamanho aparente e não há barras; em escala
## exata (2x, 3x) é idêntico ao nearest puro.
## Uso: var ap := Apresentacao.new(); add_child(ap); ap.montar(janela, escala_pura) -> SubViewport (é onde vai o mundo).
## Ao sair da cena, devolve à janela o modo de escala que ela tinha (o jogo v1 usa o content_scale_mode "viewport" de 640x360).

const PosVisual := preload("res://v2/pos_visual.gd")
const LARG := 960
const ALT := 540

var sv: SubViewport
var tela: TextureRect
var pos_visual: CanvasLayer
var _janela: Window
var _modo_antes := Window.CONTENT_SCALE_MODE_VIEWPORT
var _tam_antes := Vector2i(640, 360)
var _aspecto_antes := Window.CONTENT_SCALE_ASPECT_KEEP
var _escala_antes := Window.CONTENT_SCALE_STRETCH_FRACTIONAL


func montar(janela: Window, escala_pura := false) -> SubViewport:
	_janela = janela
	_modo_antes = janela.content_scale_mode
	_tam_antes = janela.content_scale_size
	_aspecto_antes = janela.content_scale_aspect
	_escala_antes = janela.content_scale_stretch
	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	sv = SubViewport.new()
	sv.size = Vector2i(LARG, ALT)
	sv.disable_3d = true
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(sv)
	# O passe fixa sublayer -1 na camada 3: depois de mundo/glow e antes da vinheta e da UI.
	pos_visual = PosVisual.new()
	sv.add_child(pos_visual)
	var camada := CanvasLayer.new()
	add_child(camada)
	tela = TextureRect.new()
	tela.texture = sv.get_texture()
	tela.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tela.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	if escala_pura:
		tela.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		tela.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var sh := Shader.new()
		sh.code = (
			"shader_type canvas_item;\nuniform vec2 tam = vec2(960.0, 540.0);\nuniform float escala = 1.0;\n"
			+ "void fragment(){ vec2 texel = UV * tam; vec2 piso = floor(texel); vec2 d = fract(texel) - 0.5;"
			+ " vec2 r = 0.5 - 0.5 / max(vec2(escala), vec2(1.0)); vec2 f = (d - clamp(d, -r, r)) * escala + 0.5;"
			+ " COLOR = vec4(texture(TEXTURE, (piso + f) / tam).rgb, 1.0); }\n"
		)
		var m := ShaderMaterial.new()
		m.shader = sh
		tela.material = m
	camada.add_child(tela)
	tela.resized.connect(_ajusta_escala)
	_ajusta_escala.call_deferred()
	return sv


func _ajusta_escala() -> void:
	if tela == null or tela.material == null:
		return
	(tela.material as ShaderMaterial).set_shader_parameter("escala", maxf(tela.size.x / LARG, tela.size.y / ALT))


## Posição do mouse na tela do mundo (0..960, 0..540): desfaz a escala e o corte da TextureRect.
func mouse_na_tela() -> Vector2:
	var r: Vector2 = get_viewport().get_visible_rect().size
	var k := maxf(r.x / LARG, r.y / ALT)
	return ((get_viewport().get_mouse_position() - r / 2.0) / k + Vector2(LARG, ALT) / 2.0).clamp(Vector2.ZERO, Vector2(LARG, ALT))


## Tira a foto do viewport do mundo (o que o jogador vê, sem a janela). Chamar com await.
func foto(caminho: String) -> Vector2i:
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.save_png(caminho)
	return img.get_size()


func _exit_tree() -> void:
	if _janela != null and is_instance_valid(_janela):
		_janela.content_scale_mode = _modo_antes
		_janela.content_scale_size = _tam_antes
		_janela.content_scale_aspect = _aspecto_antes
		_janela.content_scale_stretch = _escala_antes
