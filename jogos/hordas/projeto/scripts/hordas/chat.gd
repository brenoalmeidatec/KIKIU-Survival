extends CanvasLayer
## Chat de texto do online (#13): no lobby e na partida. T abre, Enter manda, Esc fecha.
## As mensagens passam pelo anfitrião (Rede.chat_*), que limpa o texto, limita o tamanho e segura quem manda rápido demais.
## Enquanto digita, as teclas do teclado saem do mapa de ações (InputMap) e voltam ao fechar: senão digitar "e" seria
## "confirmar", espaço seria dash e WASD andaria (o Godot registra a ação antes de qualquer _input poder impedir).

const MAX_TXT := 80
const MOSTRAR := 6            # linhas visíveis
const VIDA := 9.0             # segundos que uma mensagem fica na tela (fechado)
const W := 640.0
const H := 360.0

var digitando := false
var mensagens: Array = []     # {quem, txt, cor, t}
var _txt := ""
var _tela := Control.new()
var _guardadas := {}          # ação -> [InputEventKey] tiradas enquanto digita
var _t := 0.0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


## Só dá pra conversar online, fora das telas que já têm campo de texto.
func disponivel() -> bool:
	return Rede.online()


func receber(quem: String, txt: String, sistema := false) -> void:
	mensagens.append({"quem": quem, "txt": txt, "cor": Color(1, 0.85, 0.45) if sistema else Color.WHITE, "t": VIDA, "sistema": sistema})
	if mensagens.size() > 40:
		mensagens.pop_front()
	if not sistema:
		Som.ui("cursor")


func limpar() -> void:
	mensagens.clear()
	fechar()


func abrir() -> void:
	if digitando or not disponivel():
		return
	digitando = true
	_txt = ""
	_suspender_teclas()


func fechar() -> void:
	if not digitando:
		return
	digitando = false
	_devolver_teclas()


func _suspender_teclas() -> void:
	_guardadas.clear()
	for acao in InputMap.get_actions():
		if str(acao).begins_with("ui_"):
			continue
		var teclas := InputMap.action_get_events(acao).filter(func(e): return e is InputEventKey)
		if teclas.is_empty():
			continue
		_guardadas[acao] = teclas
		for e in teclas:
			InputMap.action_erase_event(acao, e)
		Input.action_release(acao)


func _devolver_teclas() -> void:
	for acao in _guardadas:
		for e in _guardadas[acao]:
			InputMap.action_add_event(acao, e)
	_guardadas.clear()


func _input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed:
		return
	var k: InputEventKey = e
	if not digitando:
		if k.physical_keycode == KEY_T and not k.echo and disponivel() and not _outro_campo_aberto():
			abrir()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if k.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		var t := limpar_texto(_txt)
		if t != "":
			Rede.chat_enviar(t)
		fechar()
	elif k.keycode == KEY_ESCAPE:
		fechar()
	elif k.keycode == KEY_BACKSPACE:
		_txt = _txt.left(-1)
	elif k.keycode == KEY_V and k.ctrl_pressed:
		_txt = limpar_texto(_txt + DisplayServer.clipboard_get()).left(MAX_TXT)
	elif k.unicode >= 32 and _txt.length() < MAX_TXT:
		_txt += char(k.unicode)


## O main.gd tem campos de texto próprios (endereço, apelido, endereço público): lá o T é letra, não chat.
func _outro_campo_aberto() -> bool:
	var m = get_tree().current_scene
	return m != null and "_estado" in m and str(m._estado) in ["endereco", "apelido", "publico"]


## Só o que a fonte desenha (ASCII e acentos do português), sem quebra de linha, até MAX_TXT.
static func limpar_texto(s: String) -> String:
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		if (c >= 32 and c < 127) or "áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ".contains(ch):
			out += ch
	return out.strip_edges().left(MAX_TXT)


func _process(dt: float) -> void:
	_t += dt
	if not disponivel():
		if digitando:
			fechar()
		if not mensagens.is_empty():
			mensagens.clear()
	for m in mensagens:
		m.t -= dt
	_tela.queue_redraw()


func _desenhar() -> void:
	if not disponivel():
		return
	var f: Font = Dados.fonte
	var y := H - 48.0 if digitando else H - 26.0
	var lobby := _no_lobby()
	var n := 4 if lobby else MOSTRAR   # no lobby os cartões dos jogadores ocupam o meio da tela
	var vis := mensagens.slice(maxi(0, mensagens.size() - n))
	vis.reverse()
	for m in vis:
		var a := 1.0 if digitando else clampf(m.t, 0.0, 1.0)
		if a <= 0.0:
			continue
		var linha := ("%s: %s" % [m.quem, m.txt]) if not m.sistema else str(m.txt)
		var larg := f.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_tela.draw_rect(Rect2(6, y - 9, minf(larg + 6, W - 12), 12), Color(0, 0, 0, 0.5 * a))
		_tela.draw_string(f, Vector2(9, y), linha, HORIZONTAL_ALIGNMENT_LEFT, W - 18, 8, Color(m.cor, a))
		y -= 13.0
	if digitando:
		var r := Rect2(6, H - 42, W - 12, 16)
		_tela.draw_rect(r, Color(0.04, 0.04, 0.08, 0.92))
		_tela.draw_rect(r, Color(1, 0.85, 0.3), false, 1.0)
		var cursor := "_" if int(_t * 2) % 2 == 0 else " "
		_tela.draw_string(f, r.position + Vector2(4, 12), "Dizer: " + _txt + cursor, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 8, Color.WHITE)
	elif not lobby and (mensagens.is_empty() or mensagens[-1].t <= 0.0):
		# na partida, uma dica discreta (no lobby a dica já está na linha de baixo)
		_tela.draw_string(f, Vector2(9, H - 26), "T: conversar", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.57, 0.65, 0.7))


func _no_lobby() -> bool:
	var m = get_tree().current_scene
	return m != null and "_estado" in m and str(m._estado) in ["sala", "apelido", "publico"]
