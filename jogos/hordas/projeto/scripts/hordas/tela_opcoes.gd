extends CanvasLayer
## Tela de Opções (abre pelo título e pela pausa). Lista os itens do Config.ITENS por grupo.
## Cima/baixo escolhem, esquerda/direita (ou Enter) mudam o valor, Esc volta. Muda e salva na hora.
## Mouse: passar por cima escolhe, clique esquerdo avança o valor, clique direito volta, clique em "Voltar" fecha.
## Uso: var t := TelaOpcoes.new(); add_child(t); t.fechou.connect(...). Ela mesma se apaga ao fechar.

signal fechou

const W := 640.0
const H := 360.0
const Interface := preload("res://scripts/hordas/interface.gd")

var _tela := Control.new()
var _sel := 0
var _quadro := 0
var _mouse_ult := Vector2(-1, -1)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_quadro = Engine.get_process_frames()   # a tecla que abriu a tela não conta aqui
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


func _n() -> int:
	return Config.ITENS.size() + 1   # + "Voltar"


## Posição (y da linha de base) de cada item e do "Voltar", mais os cabeçalhos de grupo. Desenho e mouse usam esta conta.
func _layout() -> Dictionary:
	var ys := []
	var grupos := []   # {y, nome}
	var y := 58.0
	var grupo := ""
	for it in Config.ITENS:
		if it.grupo != grupo:
			grupo = it.grupo
			y += 6.0
			grupos.append({"y": y, "nome": grupo})
			y += 14.0
		ys.append(y)
		y += 14.0
	return {"ys": ys, "grupos": grupos, "voltar": y + 10.0}


func _rects() -> Array:
	var l := _layout()
	var r := []
	for y in l.ys:
		r.append(Rect2(146, y - 10, 348, 13))
	r.append(Rect2(250, l.voltar - 10, 140, 13))
	return r


func _sair() -> void:
	Som.ui("voltar")
	fechou.emit()
	queue_free()


func _process(_dt: float) -> void:
	_tela.queue_redraw()
	if Engine.get_process_frames() == _quadro:
		return
	var mp := _tela.get_local_mouse_position()
	if mp != _mouse_ult:   # passar o mouse por cima escolhe (só se ele se mexeu, pra não brigar com o teclado)
		_mouse_ult = mp
		var q := Interface.quem(_rects(), mp)
		if q >= 0 and q != _sel:
			_sel = q
			Som.ui("cursor")
	var voltar := _sel == _n() - 1
	if Input.is_action_just_pressed("cima"):
		_sel = (_sel - 1 + _n()) % _n()
		Som.ui("cursor")
	elif Input.is_action_just_pressed("baixo"):
		_sel = (_sel + 1) % _n()
		Som.ui("cursor")
	elif Input.is_action_just_pressed("voltar") or (voltar and Input.is_action_just_pressed("confirmar")):
		_sair()
	elif not voltar and (Input.is_action_just_pressed("direita") or Input.is_action_just_pressed("confirmar")):
		Config.girar(Config.ITENS[_sel].chave, 1)
		Som.ui("cursor")
	elif not voltar and Input.is_action_just_pressed("esquerda"):
		Config.girar(Config.ITENS[_sel].chave, -1)
		Som.ui("cursor")


func _input(e: InputEvent) -> void:
	if Engine.get_process_frames() == _quadro or not (e is InputEventMouseButton and e.pressed):
		return
	var q := Interface.quem(_rects(), _tela.get_local_mouse_position())
	if q < 0:
		return
	get_viewport().set_input_as_handled()
	_sel = q
	if q == _n() - 1:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_sair()
	elif e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT:
		Config.girar(Config.ITENS[q].chave, 1 if e.button_index == MOUSE_BUTTON_LEFT else -1)
		Som.ui("cursor")


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := W, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	_tela.draw_string(Dados.fonte, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, 0.8))
	_tela.draw_string(Dados.fonte, p, s, alinhar, larg, tam, cor)


func _desenhar() -> void:
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.035, 0.07, 0.97))
	_txt(Vector2(0, 36), "Opções", 16, Color.WHITE)
	var l := _layout()
	for g in l.grupos:
		_txt(Vector2(150, g.y), str(g.nome).to_upper(), 8, Color(1, 0.85, 0.3), 340, HORIZONTAL_ALIGNMENT_LEFT)
	for i in Config.ITENS.size():
		var it: Dictionary = Config.ITENS[i]
		_linha(i, l.ys[i], str(it.nome), Config.rotulo(it.chave))
	var sel_v := _sel == _n() - 1
	if sel_v:
		_tela.draw_rect(Rect2(250, l.voltar - 10, 140, 13), Color(0.3, 0.35, 0.6, 0.35))
	_txt(Vector2(0, l.voltar), "> Voltar <" if sel_v else "Voltar", 8, Color(1, 0.9, 0.4) if sel_v else Color(0.8, 0.8, 0.8))
	_txt(Vector2(0, 340), "Cima/baixo: escolher   Esq/dir: mudar   Esc: voltar   Mouse: clique", 8, Color(0.5, 0.5, 0.6))


func _linha(i: int, y: float, nome: String, valor: String) -> void:
	var sel := i == _sel
	if sel:
		_tela.draw_rect(Rect2(146, y - 10, 348, 13), Color(0.3, 0.35, 0.6, 0.35))
	var cor := Color(1, 0.9, 0.4) if sel else Color(0.8, 0.8, 0.8)
	_txt(Vector2(158, y), nome, 8, cor, 330, HORIZONTAL_ALIGNMENT_LEFT)
	_txt(Vector2(158, y), ("< %s >" % valor) if sel else valor, 8, Color.WHITE if sel else Color(0.6, 0.85, 1), 324, HORIZONTAL_ALIGNMENT_RIGHT)
