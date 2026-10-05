extends CanvasLayer
## Menu de pausa (Esc no mapa). O jogo fica parado enquanto ele está aberto.

signal escolheu(acao: String)   # continuar, salvar, diario, historico, opcoes, menu, sair

const ITENS := [["Continuar", "continuar"], ["Salvar", "salvar"], ["Diário", "diario"],
	["Histórico de falas", "historico"], ["Opções", "opcoes"], ["Menu principal", "menu"], ["Sair do jogo", "sair"]]

var aviso := ""
var _linhas: Array[Label] = []
var _sel := 0
var _aviso := Label.new()
var _ocupado := false


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.size = Vector2(480, 270)
	add_child(fundo)
	var p := Panel.new()
	var e := Visual.painel()
	p.add_theme_stylebox_override("panel", e)
	Visual.borda_interna(p)
	p.position = Vector2(140, 34)
	p.size = Vector2(200, 202)
	add_child(p)
	Visual.surgir(p)
	var t := Label.new()
	t.text = "PAUSA"
	t.add_theme_color_override("font_color", Color("ffd34e"))
	t.add_theme_font_size_override("font_size", 16)
	t.position = Vector2(62, 12)
	p.add_child(t)
	for i in ITENS.size():
		var l := Label.new()
		l.position = Vector2(18, 42 + i * 19)
		p.add_child(l)
		_linhas.append(l)
	_aviso.add_theme_color_override("font_color", Color("6fd08c"))
	_aviso.position = Vector2(140, 242)
	add_child(_aviso)
	_atualizar()
	Jogo.som("abrir")


func mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_aviso, "modulate:a", 0.0, 0.5)


## Enquanto uma janela (opções, diário) está aberta por cima, a pausa não lê teclas.
func ocupar(sim: bool) -> void:
	_ocupado = sim
	visible = not sim


func _atualizar() -> void:
	for i in _linhas.size():
		_linhas[i].text = ("> " if i == _sel else "  ") + ITENS[i][0]
		_linhas[i].add_theme_color_override("font_color", Color("ffd34e") if i == _sel else Color("f3efe2"))
	Visual.marcar_lista(_linhas, _sel)


func _unhandled_input(event: InputEvent) -> void:
	if _ocupado or not (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("cima"):
		_sel = (_sel - 1 + ITENS.size()) % ITENS.size()
		Jogo.som("cursor")
		_atualizar()
	elif event.is_action_pressed("baixo"):
		_sel = (_sel + 1) % ITENS.size()
		Jogo.som("cursor")
		_atualizar()
	elif event.is_action_pressed("voltar"):
		escolheu.emit("continuar")
	elif event.is_action_pressed("interagir"):
		Jogo.som("confirmar")
		escolheu.emit(ITENS[_sel][1])
