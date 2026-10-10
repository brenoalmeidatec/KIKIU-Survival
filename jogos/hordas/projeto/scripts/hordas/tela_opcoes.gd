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
var _captando := ""      # ação que espera a nova tecla/botão (remapeamento, #126); "" = não está captando
var _quadro_cap := -1    # quadro em que a captura terminou: a mesma tecla não vale como comando da tela
var _mouse_ult := Vector2(-1, -1)
var _rolagem := 0.0
var _fim_lista := 0.0
const FORA := -1000.0
const JANELA_TOPO := 50.0   # primeira linha de baixo do título
const JANELA_BASE := 322.0
const VOLTAR_Y := 336.0


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
## A lista rola quando não cabe (são mais de 20 itens): `_rolagem` sobe o que passou do topo; o que fica fora da janela
## visível vai para y = FORA e não é desenhado nem clicável. "Voltar" fica sempre no pé da tela.
func _layout() -> Dictionary:
	var ys := []
	var grupos := []   # {y, nome}
	var y := 50.0
	var grupo := ""
	for it in Config.ITENS:
		if it.grupo != grupo:
			grupo = it.grupo
			y += 4.0
			grupos.append({"y": y - _rolagem, "nome": grupo})
			y += 12.0
		ys.append(y)
		y += 12.0   # 12 px por linha: com os itens de acessibilidade e de voz, 14 passava da tela
	_fim_lista = y
	for i in ys.size():
		ys[i] -= _rolagem
	for g in grupos:
		if g.y < JANELA_TOPO or g.y > JANELA_BASE:
			g.y = FORA
	for i in ys.size():
		if ys[i] < JANELA_TOPO or ys[i] > JANELA_BASE:
			ys[i] = FORA
	return {"ys": ys, "grupos": grupos, "voltar": VOLTAR_Y}


## Rola a lista o mínimo para o item escolhido aparecer inteiro (e o cabeçalho do grupo, se for o 1º dele).
func _seguir_selecao() -> void:
	if _sel >= Config.ITENS.size():
		return
	var y := 50.0
	var grupo := ""
	var y_sel := 0.0
	var y_topo := 0.0
	for i in Config.ITENS.size():
		var it: Dictionary = Config.ITENS[i]
		if it.grupo != grupo:
			grupo = it.grupo
			y += 4.0
			y_topo = y
			y += 12.0
		if i == _sel:
			y_sel = y
			break
		y += 12.0
	var primeiro: bool = _sel == 0 or Config.ITENS[_sel - 1].grupo != Config.ITENS[_sel].grupo
	var topo := y_topo if primeiro else y_sel
	if topo - _rolagem < JANELA_TOPO:
		_rolagem = maxf(0.0, topo - JANELA_TOPO)
	elif y_sel - _rolagem > JANELA_BASE:
		_rolagem = y_sel - JANELA_BASE


func _rects() -> Array:
	var l := _layout()
	var r := []
	for y in l.ys:
		r.append(Rect2(146, y - 9, 348, 12))
	r.append(Rect2(250, l.voltar - 10, 140, 13))
	return r


func _sair() -> void:
	Som.ui("voltar")
	fechou.emit()
	queue_free()


func _process(_dt: float) -> void:
	_seguir_selecao()
	_tela.queue_redraw()
	if Engine.get_process_frames() == _quadro or _captando != "" or Engine.get_process_frames() == _quadro_cap:
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
	elif not voltar and Config.ITENS[_sel].has("acao"):   # linha de remapeamento: Enter/direita pede a nova tecla ou botão
		if Input.is_action_just_pressed("confirmar") or Input.is_action_just_pressed("direita"):
			_captar(str(Config.ITENS[_sel].acao))
	elif not voltar and (Input.is_action_just_pressed("direita") or Input.is_action_just_pressed("confirmar")):
		Config.girar(Config.ITENS[_sel].chave, 1)
		Som.ui("cursor")
	elif not voltar and Input.is_action_just_pressed("esquerda"):
		Config.girar(Config.ITENS[_sel].chave, -1)
		Som.ui("cursor")


func _captar(acao: String) -> void:
	_captando = acao
	Som.ui("abrir")


## Espera a próxima tecla ou botão do controle: Esc cancela; qualquer outra coisa vira a nova tecla da ação.
func _captura(e: InputEvent) -> void:
	if not e.is_pressed() or e is InputEventMouseMotion:
		return
	if not (e is InputEventKey or e is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	_quadro_cap = Engine.get_process_frames()
	if e is InputEventKey and e.echo:
		return
	var acao := _captando
	_captando = ""
	if e is InputEventKey and (e.physical_keycode == KEY_ESCAPE or e.keycode == KEY_ESCAPE):
		Som.ui("voltar")
	elif Config.remapear(acao, e):
		Som.ui("confirmar")
	else:
		Som.ui("erro")


func _input(e: InputEvent) -> void:
	if _captando != "":
		_captura(e)
		return
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
	elif Config.ITENS[q].has("acao"):
		if e.button_index == MOUSE_BUTTON_LEFT:
			_captar(str(Config.ITENS[q].acao))
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
		if g.y != FORA:
			_txt(Vector2(150, g.y), tr(str(g.nome)).to_upper(), 8, Color(1, 0.85, 0.3), 340, HORIZONTAL_ALIGNMENT_LEFT)
	for i in Config.ITENS.size():
		var it: Dictionary = Config.ITENS[i]
		if l.ys[i] != FORA:
			_linha(i, l.ys[i], tr(str(it.nome)), Config.rotulo(it.chave))
	var cor_seta := Color(1, 0.85, 0.3, 0.8)
	if _rolagem > 0.5:   # tem mais opções acima/abaixo: triângulo na margem
		_tela.draw_colored_polygon(PackedVector2Array([Vector2(500, 48), Vector2(506, 56), Vector2(494, 56)]), cor_seta)
	if _fim_lista - _rolagem > JANELA_BASE + 8.0:
		_tela.draw_colored_polygon(PackedVector2Array([Vector2(494, 318), Vector2(506, 318), Vector2(500, 326)]), cor_seta)
	var sel_v := _sel == _n() - 1
	if sel_v:
		_tela.draw_rect(Rect2(250, l.voltar - 10, 140, 13), Color(0.3, 0.35, 0.6, 0.35))
	_txt(Vector2(0, l.voltar), "> Voltar <" if sel_v else "Voltar", 8, Color(1, 0.9, 0.4) if sel_v else Color(0.8, 0.8, 0.8))
	_txt(Vector2(0, 350), "Cima/baixo: escolher   Esq/dir: mudar   Enter: trocar tecla   Esc: voltar", 8, Color(0.5, 0.5, 0.6))
	_txt(Vector2(0, 14), Dados.texto_versao(), 8, Color(0.72, 0.74, 0.86, 0.85), W - 6, HORIZONTAL_ALIGNMENT_RIGHT)


func _linha(i: int, y: float, nome: String, valor: String) -> void:
	var sel := i == _sel
	if sel:
		_tela.draw_rect(Rect2(146, y - 9, 348, 12), Color(0.3, 0.35, 0.6, 0.35))
	var cor := Color(1, 0.9, 0.4) if sel else Color(0.8, 0.8, 0.8)
	_txt(Vector2(158, y), nome, 8, cor, 330, HORIZONTAL_ALIGNMENT_LEFT)
	if _captando != "" and Config.ITENS[i].get("acao", "") == _captando:
		_txt(Vector2(158, y), "Aperte a nova tecla ou botão (Esc cancela)", 8, Color(1, 0.85, 0.3), 324, HORIZONTAL_ALIGNMENT_RIGHT)
		return
	_txt(Vector2(158, y), ("< %s >" % valor) if sel and not Config.ITENS[i].has("acao") else valor, 8, Color.WHITE if sel else Color(0.6, 0.85, 1), 324, HORIZONTAL_ALIGNMENT_RIGHT)
