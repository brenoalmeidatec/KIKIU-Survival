extends CanvasLayer
## Modo teste (F6 no mapa): escolhe uma cena pra tocar na hora ou um mapa pra ir direto,
## sem jogar o capítulo todo. Esquerda/direita troca entre Cenas e Mapas,
## cima/baixo escolhe (segurar rola rápido), E confirma, Esc fecha.

signal escolheu(tipo: String, id: String)   # "cena" ou "mapa"; fechar = tipo ""

var cenas: Array = []   # id, ou [rótulo, id] pros destaques
var mapas: Array = []

const VISIVEIS := 14
var _aba := 0
var _sel := [0, 0]
var _linhas: Array[Label] = []
var _titulo := Label.new()
var _info := Label.new()


func _ready() -> void:
	layer = 36
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.size = Vector2(480, 270)
	add_child(fundo)
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Visual.painel())
	Visual.borda_interna(p)
	p.position = Vector2(60, 10)
	p.size = Vector2(360, 250)
	add_child(p)
	_titulo.position = Vector2(12, 10)
	p.add_child(_titulo)
	for i in VISIVEIS:
		var l := Label.new()
		l.position = Vector2(14, 30 + i * 14)
		p.add_child(l)
		_linhas.append(l)
	_info.position = Vector2(12, 230)
	_info.add_theme_color_override("font_color", Color("6b7299"))
	_info.text = "<-/->: cenas/mapas  %s: ir  %s: fechar" % [Controles.tecla("interagir"), Controles.tecla("voltar")]
	p.add_child(_info)
	_atualizar()
	Jogo.som("abrir")


func _lista() -> Array:
	return cenas if _aba == 0 else mapas


func _atualizar() -> void:
	var l := _lista()
	_titulo.text = ("MODO TESTE  [CENAS %d]  mapas" % cenas.size()) if _aba == 0 else ("MODO TESTE  cenas  [MAPAS %d]" % mapas.size())
	_titulo.add_theme_color_override("font_color", Color("ffd34e"))
	var sel: int = _sel[_aba]
	var topo := clampi(sel - VISIVEIS / 2, 0, maxi(l.size() - VISIVEIS, 0))
	for i in VISIVEIS:
		var k := topo + i
		var lb := _linhas[i]
		lb.text = (("> " if k == sel else "  ") + _rotulo(l[k])) if k < l.size() else ""
		lb.add_theme_color_override("font_color", Color("ffd34e") if k == sel else Color("f3efe2"))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction):
		return
	get_viewport().set_input_as_handled()
	var l := _lista()
	if event.is_action_pressed("cima", true) and not l.is_empty():
		_sel[_aba] = (_sel[_aba] - 1 + l.size()) % l.size()
		Jogo.som("cursor")
	elif event.is_action_pressed("baixo", true) and not l.is_empty():
		_sel[_aba] = (_sel[_aba] + 1) % l.size()
		Jogo.som("cursor")
	elif event.is_action_pressed("esquerda") or event.is_action_pressed("direita"):
		_aba = 1 - _aba
		Jogo.som("cursor")
	elif event.is_action_pressed("voltar"):
		Jogo.som("fechar")
		escolheu.emit("", "")
		queue_free()
		return
	elif event.is_action_pressed("interagir") and not l.is_empty():
		Jogo.som("confirmar")
		escolheu.emit("cena" if _aba == 0 else "mapa", _id(l[_sel[_aba]]))
		queue_free()
		return
	_atualizar()


func _rotulo(x) -> String:
	return str(x[0]) if x is Array else str(x)


func _id(x) -> String:
	return str(x[1]) if x is Array else str(x)
