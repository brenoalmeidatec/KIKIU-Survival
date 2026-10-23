extends Node
## Código secreto do título e do santuário: Konami (cima cima baixo baixo esquerda direita esquerda direita B A) no controle (direcional
## ou analógico esquerdo + B e A; no PlayStation são o ○ e o ✕ nas mesmas posições) ou nas setas do teclado + B + A, ou digitar IDKFA.
## Liga o modo "tudo liberado" (Progressao.beta_tester, o mesmo do `-- --beta-tester`) como opção salva em Config; repetir o código desliga.
## Só conta em sequência: passou TEMPO_MS sem tecla, recomeça. As teclas não são consumidas, exceto as duas últimas do Konami (B e A,
## depois de oito certas): senão o B abriria a saída e o A apertaria o botão com foco. Quem usa adiciona este nó POR ÚLTIMO (recebe o
## _input antes dos outros), liga `alternado` ao que precisa redesenhar e põe em `bloqueado` o que impede de valer (menu aberto etc.).

const Paleta := preload("res://v2/paleta.gd")
const Progressao := preload("res://v2/progressao.gd")

signal alternado(ligado: bool)

const TEMPO_MS := 1500  # tempo máximo entre uma tecla e a seguinte
const LIMIAR := 0.6  # o analógico conta como "apertou" acima disto e só conta de novo depois de voltar abaixo de SOLTAR
const SOLTAR := 0.3
const KONAMI := ["cima", "cima", "baixo", "baixo", "esq", "dir", "esq", "dir", "b", "a"]
const IDKFA := ["i", "d", "k", "f", "a"]
const MENSAGEM_LIGADO := "TUDO LIBERADO!"
const MENSAGEM_DESLIGADO := "Tudo liberado desligado."

var bloqueado := Callable()  # gancho: devolve true quando o código não deve valer agora
var _fila: Array = []
var _ultimo_ms := 0
var _eixos := {}  # "eixo/sinal" -> true enquanto o analógico está apertado nessa direção
var _camada: CanvasLayer
var _aviso: Label


func _input(e: InputEvent) -> void:
	if bloqueado.is_valid() and bloqueado.call():
		_fila.clear()
		return
	var token := token_de(e)
	if token != "" and registrar(token, Time.get_ticks_msec()):
		get_viewport().set_input_as_handled()


## O token (cima, baixo, esq, dir, b, a ou uma letra) de um evento, ou "" se ele não conta. Só o aperto, nunca o repetir nem o soltar.
func token_de(e: InputEvent) -> String:
	if e is InputEventKey:
		if not e.pressed or e.echo:
			return ""
		match e.keycode:
			KEY_UP:
				return "cima"
			KEY_DOWN:
				return "baixo"
			KEY_LEFT:
				return "esq"
			KEY_RIGHT:
				return "dir"
		var k: int = e.keycode if e.keycode != KEY_NONE else e.physical_keycode
		if k >= KEY_A and k <= KEY_Z:
			return char(k).to_lower()
		return ""
	if e is InputEventJoypadButton:
		if not e.pressed:
			return ""
		match e.button_index:
			JOY_BUTTON_DPAD_UP:
				return "cima"
			JOY_BUTTON_DPAD_DOWN:
				return "baixo"
			JOY_BUTTON_DPAD_LEFT:
				return "esq"
			JOY_BUTTON_DPAD_RIGHT:
				return "dir"
			JOY_BUTTON_B:
				return "b"
			JOY_BUTTON_A:
				return "a"
		return ""
	if e is InputEventJoypadMotion and (e.axis == JOY_AXIS_LEFT_X or e.axis == JOY_AXIS_LEFT_Y):
		var mag := absf(e.axis_value)
		if mag <= SOLTAR:
			_eixos.erase("%d/-" % e.axis)
			_eixos.erase("%d/+" % e.axis)
			return ""
		if mag < LIMIAR:
			return ""
		var lado := "+" if e.axis_value > 0.0 else "-"
		var chave := "%d/%s" % [e.axis, lado]
		if _eixos.has(chave):
			return ""
		_eixos[chave] = true
		if e.axis == JOY_AXIS_LEFT_X:
			return "dir" if lado == "+" else "esq"
		return "baixo" if lado == "+" else "cima"
	return ""


## Anota uma tecla (agora_ms = relógio em ms). Completando um código, alterna o modo. Devolve true se o evento deve ser consumido.
func registrar(token: String, agora_ms: int) -> bool:
	if agora_ms - _ultimo_ms > TEMPO_MS:
		_fila.clear()
	_ultimo_ms = agora_ms
	_fila.append(token)
	if _fila.size() > KONAMI.size():
		_fila = _fila.slice(_fila.size() - KONAMI.size())
	if _termina_com(KONAMI) or _termina_com(IDKFA):
		_fila.clear()
		alternar()
		return true
	return token in ["b", "a"] and _prefixo_konami() >= 9  # o B (e o A) do final do Konami não fazem o que fariam num menu


## Liga ou desliga o modo, avisa na tela, toca o som e emite `alternado`.
func alternar() -> void:
	var ligado := Progressao.alternar_codigo()
	_anunciar(MENSAGEM_LIGADO if ligado else MENSAGEM_DESLIGADO, ligado)
	alternado.emit(ligado)


func _termina_com(codigo: Array) -> bool:
	return _fila.size() >= codigo.size() and _fila.slice(_fila.size() - codigo.size()) == codigo


## Quantas teclas do começo do Konami a fila termina de cumprir (0 a 10).
func _prefixo_konami() -> int:
	for k in range(mini(_fila.size(), KONAMI.size()), 0, -1):
		if _fila.slice(_fila.size() - k) == KONAMI.slice(0, k):
			return k
	return 0


## O aviso fica numa camada na raiz da árvore (não neste nó): sobrevive à troca de cena que o santuário faz logo em seguida.
func _anunciar(texto: String, ligado: bool) -> void:
	Som.ui("abrir" if ligado else "voltar")
	if ligado:
		Som.ui("confirmar")
	if not is_inside_tree():
		return
	if is_instance_valid(_camada) and _camada.is_inside_tree():
		_camada.queue_free()  # o aviso anterior sai: só um por vez
	_camada = CanvasLayer.new()
	_camada.layer = 100
	_aviso = Label.new()
	_aviso.text = texto
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.offset_top = 72.0
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.add_theme_font_override("font", Dados.fonte_titulo)
	_aviso.add_theme_font_size_override("font_size", Paleta.TITULO_MEDIO)
	_aviso.add_theme_constant_override("outline_size", 8)
	_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_aviso.add_theme_color_override("font_color", Paleta.OURO if ligado else Paleta.TEXTO)
	_camada.add_child(_aviso)
	get_tree().root.add_child.call_deferred(_camada)  # adiado: a raiz pode estar ocupada montando os filhos
	_comecar_fade.call_deferred(_camada, _aviso)


func _comecar_fade(camada: CanvasLayer, aviso: Label) -> void:
	if not is_instance_valid(camada) or not camada.is_inside_tree():
		return
	var tween := camada.create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(aviso, "modulate:a", 0.0, 0.5)
	tween.tween_callback(camada.queue_free)


## O texto do aviso que está na tela ("" se não há). Para os testes.
func aviso_visivel() -> String:
	return _aviso.text if is_instance_valid(_aviso) and is_instance_valid(_camada) and not _camada.is_queued_for_deletion() else ""
