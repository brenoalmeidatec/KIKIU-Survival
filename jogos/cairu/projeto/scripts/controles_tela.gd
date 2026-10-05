extends CanvasLayer
## Opções > Controles: troca a tecla de cada ação. E na ação e depois a tecla nova
## (Esc cancela). Se a tecla já era de outra ação, as duas trocam. O controle (gamepad)
## aparece do lado, só pra consulta.

signal fechou

var _linhas: Array[Label] = []
var _sel := 0
var _esperando := false
var _aviso := Label.new()
var _itens: Array = []


func _ready() -> void:
	layer = 41
	process_mode = Node.PROCESS_MODE_ALWAYS
	_itens = Controles.EDITAVEIS.map(func(e): return e[0]) + ["_padrao", "_sair"]
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.65)
	fundo.size = Vector2(480, 270)
	add_child(fundo)
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Visual.painel())
	Visual.borda_interna(p)
	p.position = Vector2(16, 12)
	p.size = Vector2(448, 246)
	add_child(p)
	Visual.surgir(p)
	var t := Label.new()
	t.text = "Controles"
	t.add_theme_color_override("font_color", Color("ffd34e"))
	t.position = Vector2(12, 10)
	p.add_child(t)
	var cab := Label.new()
	cab.text = "teclado              controle"
	cab.add_theme_color_override("font_color", Color("6b7299"))
	cab.position = Vector2(196, 10)
	p.add_child(cab)
	for i in _itens.size():
		var l := Label.new()
		l.position = Vector2(12, 30 + i * 16)
		p.add_child(l)
		_linhas.append(l)
	_aviso.position = Vector2(12, 226)
	_aviso.add_theme_color_override("font_color", Color("6b7299"))
	p.add_child(_aviso)
	_dica()
	_atualizar()
	Jogo.som("abrir")


func _dica() -> void:
	_aviso.add_theme_color_override("font_color", Color("6b7299"))
	_aviso.text = "%s: trocar a tecla   %s: voltar" % [Controles.tecla("interagir"), Controles.tecla("voltar")]


func _atualizar() -> void:
	for i in _itens.size():
		var id: String = _itens[i]
		var s := ""
		if id == "_padrao":
			s = "Voltar as teclas de fábrica"
		elif id == "_sair":
			s = "Voltar"
		else:
			var nome: String = Controles.EDITAVEIS[i][1]
			var tec := "..." if _esperando and i == _sel else Controles.descrever(id)
			s = "%s%s%s" % [nome.rpad(21), tec.rpad(21).substr(0, 21), Controles.nome_botao(id)]
		_linhas[i].text = ("> " if i == _sel else "  ") + s
		_linhas[i].add_theme_color_override("font_color", Color("ffd34e") if i == _sel else Color("f3efe2"))
	Visual.marcar_lista(_linhas, _sel)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if _esperando:
		if not (event is InputEventKey and event.pressed and not event.echo):
			return
		_esperando = false
		var k: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if k == KEY_ESCAPE:
			Jogo.som("fechar")
			_dica()
		elif k in [KEY_F3, KEY_F5, KEY_F6, KEY_F11]:
			Jogo.som("erro")
			_aviso.add_theme_color_override("font_color", Color("ff6b6b"))
			_aviso.text = "Essa tecla é do jogo (F3/F5/F6/F11). Escolha outra."
		else:
			var acao: String = _itens[_sel]
			var perdeu := Controles.trocar(acao, k)
			Jogo.salvar_opcoes()
			Jogo.som("confirmar")
			_aviso.add_theme_color_override("font_color", Color("6fd08c"))
			_aviso.text = "Pronto!" if perdeu == "" else "Pronto! (trocou com \"%s\")" % _nome(perdeu)
		_atualizar()
		return
	if event.is_action_pressed("cima"):
		_sel = (_sel - 1 + _itens.size()) % _itens.size()
		Jogo.som("cursor")
		_atualizar()
	elif event.is_action_pressed("baixo"):
		_sel = (_sel + 1) % _itens.size()
		Jogo.som("cursor")
		_atualizar()
	elif event.is_action_pressed("voltar") or (event.is_action_pressed("interagir") and _itens[_sel] == "_sair"):
		Jogo.som("fechar")
		fechou.emit()
		queue_free()
	elif event.is_action_pressed("interagir"):
		if _itens[_sel] == "_padrao":
			Controles.restaurar()
			Jogo.salvar_opcoes()
			Jogo.som("confirmar")
			_aviso.add_theme_color_override("font_color", Color("6fd08c"))
			_aviso.text = "Teclas de fábrica de volta."
		else:
			_esperando = true
			Jogo.som("cursor")
			_aviso.add_theme_color_override("font_color", Color("ffd34e"))
			_aviso.text = "Aperte a tecla nova (Esc cancela)"
		_atualizar()


func _nome(acao: String) -> String:
	for e in Controles.EDITAVEIS:
		if e[0] == acao:
			return e[1]
	return acao
