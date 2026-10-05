extends CanvasLayer
## Janela por cima do jogo com um título e um texto que rola (diário, histórico).
## Fecha com Esc, E ou a mesma tecla que abriu.

signal fechou

var titulo := ""
var texto := ""          # aceita [color=#ffd34e]...[/color]
var tecla := ""          # ação que também fecha (ex.: "diario")
var no_fim := false      # começar rolado até o fim (histórico)

var _rt := RichTextLabel.new()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.size = Vector2(480, 270)
	add_child(fundo)
	var p := Panel.new()
	var e := Visual.painel()
	p.add_theme_stylebox_override("panel", e)
	Visual.borda_interna(p)
	p.position = Vector2(24, 14)
	p.size = Vector2(432, 242)
	add_child(p)
	Visual.surgir(p)
	var t := Label.new()
	t.text = titulo
	t.add_theme_color_override("font_color", Color("ffd34e"))
	t.position = Vector2(12, 10)
	p.add_child(t)
	_rt.bbcode_enabled = true
	_rt.text = texto
	_rt.position = Vector2(12, 30)
	_rt.size = Vector2(408, 186)
	_rt.add_theme_constant_override("line_separation", 5)
	_rt.add_theme_color_override("default_color", Color("f3efe2"))
	_rt.scroll_following = no_fim
	p.add_child(_rt)
	var dica := Label.new()
	dica.text = "setas: rolar   %s/%s: fechar" % [Controles.tecla("voltar"), Controles.tecla("interagir")]
	dica.add_theme_color_override("font_color", Color("6b7299"))
	dica.position = Vector2(12, 224)
	p.add_child(dica)
	Jogo.som("abrir")


func _unhandled_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	var barra := _rt.get_v_scroll_bar()
	if event.is_action_pressed("cima", true):
		barra.value -= 15
	elif event.is_action_pressed("baixo", true):
		barra.value += 15
	elif event.is_action_pressed("voltar") or event.is_action_pressed("interagir") or (tecla != "" and event.is_action_pressed(tecla)):
		Jogo.som("fechar")
		fechou.emit()
		queue_free()
