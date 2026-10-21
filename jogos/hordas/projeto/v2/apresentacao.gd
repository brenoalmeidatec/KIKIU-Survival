extends Node
## Apresentação da v2 (extraída do protótipo cara_nova): o mundo é desenhado num SubViewport de 960x540 (filtro nearest) e mostrado numa
## TextureRect do tamanho da janela com o shader "sharp bilinear": escala inteira em nearest + só 1 px de tela de transição nas bordas
## dos texels. Com escala fracionária (1,33x, 1,6x, 1,87x...) todos os pixels têm o mesmo tamanho aparente e não há barras; em escala
## exata (2x, 3x) é idêntico ao nearest puro.
## Uso: var ap := Apresentacao.new(); add_child(ap); ap.montar(janela, escala_pura) -> SubViewport (é onde vai o mundo).
## A interface (HUD, cartas, pausa, resultado...) NÃO fica no SubViewport do mundo: tem o próprio, `ui`, transparente e do tamanho do canvas
## da UI (janela / fator, ver v2/escala_ui.gd), mostrado por cima do mundo com o mesmo sharp bilinear. Cada CanvasLayer posta em `ui` ganha
## `offset = desloc` (o bloco 960x540 no centro do canvas) e, a cada mudança de janela ou de opção, os nós do grupo "ui_escala" recebem
## `ui_reencaixar(canvas, desloc)` para reancorar o que é de borda. Como o do mundo, o `ui` não recebe a entrada da janela: o mouse da UI vem
## de mouse_ui() (coordenadas do bloco).
## Ao sair da cena, devolve à janela o modo de escala que ela tinha (o jogo v1 usa o content_scale_mode "viewport" de 640x360).

const PosVisual := preload("res://v2/pos_visual.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const LARG := 960
const ALT := 540

var sv: SubViewport
var tela: TextureRect
var pos_visual: CanvasLayer
var ui: SubViewport  # a interface: canvas da UI em px de UI
var tela_ui: TextureRect
var fator := 1.0  # px de janela por px de UI
var canvas := EscalaUi.BLOCO  # tamanho do ui em px de UI
var desloc := Vector2.ZERO  # onde o bloco 960x540 começa no canvas
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
	_filtro(tela, escala_pura, false)
	camada.add_child(tela)
	ui = SubViewport.new()
	ui.name = "Ui"
	ui.size = Vector2i(EscalaUi.BLOCO)
	ui.disable_3d = true
	ui.transparent_bg = true
	ui.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ui.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(ui)
	ui.child_entered_tree.connect(_ui_entrou)
	tela_ui = TextureRect.new()
	tela_ui.texture = ui.get_texture()
	tela_ui.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tela_ui.stretch_mode = TextureRect.STRETCH_SCALE
	tela_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filtro(tela_ui, escala_pura, true)
	camada.add_child(tela_ui)
	janela.size_changed.connect(recalcular)
	Config.tamanho_ui_mudou.connect(recalcular)
	recalcular()
	tela.resized.connect(_ajusta_escala)
	_ajusta_escala.call_deferred()
	return sv


## O filtro da TextureRect: nearest puro (escala_pura) ou o sharp bilinear. O da interface mistura com o mundo por cima: o ui é desenhado em
## transparente, então a cor sai pré-multiplicada e o shader usa blend_premul_alpha.
func _filtro(t: TextureRect, escala_pura: bool, com_alfa: bool) -> void:
	if escala_pura:
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if com_alfa:
			var pre := CanvasItemMaterial.new()
			pre.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
			t.material = pre
		return
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sh := Shader.new()
	sh.code = (
		"shader_type canvas_item;\n"
		+ ("render_mode blend_premul_alpha;\n" if com_alfa else "")
		+ "uniform vec2 tam = vec2(960.0, 540.0);\nuniform float escala = 1.0;\n"
		+ "void fragment(){ vec2 texel = UV * tam; vec2 piso = floor(texel); vec2 d = fract(texel) - 0.5;"
		+ " vec2 r = 0.5 - 0.5 / max(vec2(escala), vec2(1.0)); vec2 f = (d - clamp(d, -r, r)) * escala + 0.5;"
		+ (" COLOR = texture(TEXTURE, (piso + f) / tam); }\n" if com_alfa else " COLOR = vec4(texture(TEXTURE, (piso + f) / tam).rgb, 1.0); }\n")
	)
	var m := ShaderMaterial.new()
	m.shader = sh
	t.material = m


## Refaz fator, canvas e deslocamento (janela redimensionada ou opção "tamanho_ui" trocada) e avisa as telas.
func recalcular() -> void:
	if ui == null or _janela == null:
		return
	fator = EscalaUi.atualizar(_janela)
	canvas = EscalaUi.canvas_atual
	desloc = EscalaUi.desloc_atual
	var t := Vector2i(canvas)
	if ui.size != t:
		ui.size = t
	tela_ui.position = Vector2.ZERO
	tela_ui.size = Vector2(t) * fator
	if tela_ui.material != null:
		(tela_ui.material as ShaderMaterial).set_shader_parameter("tam", Vector2(t))
		(tela_ui.material as ShaderMaterial).set_shader_parameter("escala", fator)
	for c in ui.get_children():
		if c is CanvasLayer:
			c.offset = desloc
	if is_inside_tree():
		for c in get_tree().get_nodes_in_group("ui_cobrir"):
			EscalaUi.cobrir(c)
		Transicoes.reencaixar_ui(canvas, desloc)


## Toda CanvasLayer que entra no `ui` já nasce no lugar do bloco.
func _ui_entrou(no: Node) -> void:
	if no is CanvasLayer:
		(no as CanvasLayer).offset = desloc


## O retângulo do canvas inteiro em coordenadas do bloco (para fundos que cobrem a tela toda).
func cobertura() -> Rect2:
	return EscalaUi.cobertura(canvas, desloc)


func _ajusta_escala() -> void:
	if tela == null or tela.material == null:
		return
	(tela.material as ShaderMaterial).set_shader_parameter("escala", maxf(tela.size.x / LARG, tela.size.y / ALT))


## Posição do mouse na tela do mundo (0..960, 0..540): desfaz a escala e o corte da TextureRect.
func mouse_na_tela() -> Vector2:
	var r: Vector2 = get_viewport().get_visible_rect().size
	var k := maxf(r.x / LARG, r.y / ALT)
	return ((get_viewport().get_mouse_position() - r / 2.0) / k + Vector2(LARG, ALT) / 2.0).clamp(Vector2.ZERO, Vector2(LARG, ALT))


## Posição do mouse na interface, em coordenadas do bloco 960x540 (o bloco fica no centro do canvas do ui; fora dele dá negativo ou
## maior que 960x540). É o que pausa, cartas, resultado e card da build usam no lugar de mouse_na_tela() (que é do mundo).
func mouse_ui() -> Vector2:
	return pos_ui(get_viewport().get_mouse_position())


## Converte uma posição da janela (px) para o bloco da UI.
func pos_ui(pos_janela: Vector2) -> Vector2:
	return pos_janela / maxf(fator, 0.001) - desloc


## Tira a foto do que o jogador vê. Janela de verdade: a janela inteira (mundo e interface, no tamanho da janela). Headless não desenha a
## janela: sai só o viewport do mundo. Chamar com await.
func foto(caminho: String) -> Vector2i:
	await RenderingServer.frame_post_draw
	var img: Image = null
	if DisplayServer.get_name() != "headless":
		img = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		img = sv.get_texture().get_image()
	img.save_png(caminho)
	return img.get_size()


func _exit_tree() -> void:
	if _janela != null and is_instance_valid(_janela) and _janela.size_changed.is_connected(recalcular):
		_janela.size_changed.disconnect(recalcular)
	if Config.tamanho_ui_mudou.is_connected(recalcular):
		Config.tamanho_ui_mudou.disconnect(recalcular)
	EscalaUi.fator_atual = 1.0
	EscalaUi.canvas_atual = EscalaUi.BLOCO
	EscalaUi.desloc_atual = Vector2.ZERO
	if _janela != null and is_instance_valid(_janela):
		_janela.content_scale_mode = _modo_antes
		_janela.content_scale_size = _tam_antes
		_janela.content_scale_aspect = _aspecto_antes
		_janela.content_scale_stretch = _escala_antes
