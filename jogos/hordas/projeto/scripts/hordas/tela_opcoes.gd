extends CanvasLayer
## Tela de Opções (abre pelo título e pela pausa). Lista os itens do Config.ITENS por grupo.
## Cima/baixo escolhem, esquerda/direita (ou Enter) mudam o valor, Esc volta. Muda e salva na hora.
## Uso: var t := TelaOpcoes.new(); add_child(t); t.fechou.connect(...). Ela mesma se apaga ao fechar.

signal fechou

const W := 640.0
const H := 360.0

var _tela := Control.new()
var _sel := 0
var _quadro := 0


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


func _process(_dt: float) -> void:
	_tela.queue_redraw()
	if Engine.get_process_frames() == _quadro:
		return
	var voltar := _sel == _n() - 1
	if Input.is_action_just_pressed("cima"):
		_sel = (_sel - 1 + _n()) % _n()
		Som.tocar("cursor")
	elif Input.is_action_just_pressed("baixo"):
		_sel = (_sel + 1) % _n()
		Som.tocar("cursor")
	elif Input.is_action_just_pressed("voltar") or (voltar and Input.is_action_just_pressed("confirmar")):
		Som.tocar("fechar")
		fechou.emit()
		queue_free()
	elif not voltar and (Input.is_action_just_pressed("direita") or Input.is_action_just_pressed("confirmar")):
		Config.girar(Config.ITENS[_sel].chave, 1)
		Som.tocar("cursor")
	elif not voltar and Input.is_action_just_pressed("esquerda"):
		Config.girar(Config.ITENS[_sel].chave, -1)
		Som.tocar("cursor")


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := W, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	_tela.draw_string(Dados.fonte, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, 0.8))
	_tela.draw_string(Dados.fonte, p, s, alinhar, larg, tam, cor)


func _desenhar() -> void:
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.035, 0.07, 0.97))
	_txt(Vector2(0, 40), "Opções", 16, Color.WHITE)
	var y := 66.0
	var grupo := ""
	for i in Config.ITENS.size():
		var it: Dictionary = Config.ITENS[i]
		if it.grupo != grupo:
			grupo = it.grupo
			y += 8.0
			_txt(Vector2(150, y), grupo.to_upper(), 8, Color(1, 0.85, 0.3), 340, HORIZONTAL_ALIGNMENT_LEFT)
			y += 16.0
		_linha(i, y, str(it.nome), Config.rotulo(it.chave))
		y += 15.0
	y += 12.0
	var sel_v := _sel == _n() - 1
	_txt(Vector2(0, y), "> Voltar <" if sel_v else "Voltar", 8, Color(1, 0.9, 0.4) if sel_v else Color(0.8, 0.8, 0.8))
	_txt(Vector2(0, 340), "Cima/baixo: escolher   Esquerda/direita: mudar   Esc: voltar", 8, Color(0.5, 0.5, 0.6))


func _linha(i: int, y: float, nome: String, valor: String) -> void:
	var sel := i == _sel
	if sel:
		_tela.draw_rect(Rect2(146, y - 10, 348, 13), Color(0.3, 0.35, 0.6, 0.35))
	var cor := Color(1, 0.9, 0.4) if sel else Color(0.8, 0.8, 0.8)
	_txt(Vector2(158, y), nome, 8, cor, 330, HORIZONTAL_ALIGNMENT_LEFT)
	_txt(Vector2(158, y), ("< %s >" % valor) if sel else valor, 8, Color.WHITE if sel else Color(0.6, 0.85, 1), 324, HORIZONTAL_ALIGNMENT_RIGHT)
