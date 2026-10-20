extends Node
## Navegação real do frontend e legibilidade do santuário em 960x540. Save/opções isolados.
const Meta := preload("res://v2/meta.gd")
const Altar := preload("res://v2/altar.tscn")
const SAVE := "user://teste_v2_santuario.cfg"
const OPCOES := "user://teste_v2_santuario_opcoes.cfg"
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Meta.caminho_save = SAVE
	Config.arquivo = OPCOES
	_limpar()
	# Driver persistente: change_scene troca a cena de verdade, sem destruir o teste.
	get_tree().current_scene = null
	Engine.set_meta("kikiu_entrada", true)
	for acao in ["escape", "start", "cancelar", "botao", "mouse"]:
		get_tree().change_scene_to_packed(Altar)
		await _frames(3)
		var a = get_tree().current_scene
		ok(a.scene_file_path == "res://v2/altar.tscn", "abre santuário real")
		a._ajustes.pressed.emit()
		ok(a.pausa.aberto and a.pausa.tela == "ajustes", "Ajustes abre no santuário")
		_tecla(KEY_ENTER)  # Gráficos
		ok(a.pausa.tela == "graficos", "Ajustes entra em Gráficos")
		_tecla(KEY_ESCAPE)
		ok(a.pausa.tela == "ajustes", "ESC em Gráficos volta um nível")
		_tecla(KEY_ESCAPE)
		await _frames(1)
		ok(not a.pausa.aberto and get_tree().current_scene == a, "ESC em Ajustes permanece no santuário")
		ok(get_viewport().gui_get_focus_owner() == a._ajustes, "Ajustes devolve foco")
		_ver_visual(a)
		if acao == "escape":
			_tecla(KEY_ESCAPE)
		elif acao in ["start", "cancelar"]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = JOY_BUTTON_START if acao == "start" else JOY_BUTTON_B
			ev.pressed = true
			Input.parse_input_event(ev)
			Input.flush_buffered_events()
		elif acao == "mouse":
			for pressionado in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.position = get_viewport().get_final_transform() * a._voltar.get_global_rect().get_center()
				ev.global_position = ev.position
				ev.pressed = pressionado
				Input.parse_input_event(ev)
				Input.flush_buffered_events()
		else:
			a._voltar.grab_focus()
			_tecla(KEY_ENTER)
		await _frames(3)
		ok(get_tree().current_scene.scene_file_path == "res://v2/menu_principal.tscn", "%s volta ao título" % acao)
	# O título continua pedindo Sair por ESC; o processo permanece vivo.
	_tecla(KEY_ESCAPE)
	await _frames(1)
	var titulo = get_tree().current_scene
	ok(titulo.pausa.aberto and titulo.pausa.tela == "confirmar_sair", "ESC só pede Sair no título")
	_tecla(KEY_ESCAPE)
	ok(not titulo.pausa.aberto, "ESC cancela Sair no título")
	_limpar()
	print("v2_santuario falhas=%d" % falhas)
	get_tree().quit(falhas)


func _ver_visual(a) -> void:
	for nome in ["FLORESTA", "LABORATÓRIO", "RUÍNAS DA FLORESTA", "CIDADE"]:
		var largura: float = (
			a._mapa.get_theme_font("font").get_string_size("< %s >" % nome, HORIZONTAL_ALIGNMENT_LEFT, -1, a._mapa.get_theme_font_size("font_size")).x
		)
		ok(largura + 8 <= a._mapa.size.x, "nome completo %s cabe no botão" % nome)
	ok(a._mapa.position.x + a._mapa.size.x <= a._entrar.position.x, "MAPA não invade ENTRAR")
	for id in a._linhas:
		var linha: Dictionary = a._linhas[id]
		var selecionar: Button = linha.selecionar
		ok(not selecionar.disabled and selecionar.focus_mode == Control.FOCUS_ALL, "cartão %s sempre selecionável" % id)
		selecionar.grab_focus()
		ok(a._detalhe.text.begins_with(str(Meta.melhoria(id).nome)), "foco mostra detalhe de %s" % id)
		for chave in ["nome", "efeito"]:
			var l: Label = linha[chave]
			var largura: float = l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
			ok(largura <= l.size.x, "texto %s/%s cabe no cartão" % [id, chave])
		for chave in ["nome", "efeito", "botao", "cadeado", "progresso", "selecionar"]:
			var c: Control = linha[chave]
			ok(c.position.x >= 36 and c.position.x + c.size.x <= 608, "cartão %s/%s cabe na coluna" % [id, chave])
		ok(a._detalhe.get_minimum_size().y <= a._detalhe.size.y, "detalhe %s cabe" % id)
	a._linhas["treino"].selecionar.grab_focus()
	ok(a._detalhe.text.contains("Sobreviva 5 minutos"), "bloqueado explica requisito ao teclado")
	for id in a._conq:
		a._conq[id].selecionar.grab_focus()
		ok(a._detalhe.text.contains(str(Meta.conquistas().filter(func(c): return str(c.id) == id)[0].desc)), "conquista %s tem detalhe por foco" % id)
		ok(a._detalhe.get_minimum_size().y <= a._detalhe.size.y, "detalhe conquista %s cabe" % id)
	a._conq["combo_50"].selecionar.grab_focus()  # a última do laço é uma conquista de progresso (vence_medio), sem recompensa
	ok(
		a._detalhe.text.contains("Libera: Rastro de katana") and not a._detalhe.text.contains("sem efeito"),
		"a recompensa do rastro aparece no detalhe, sem aviso de efeito pendente"
	)
	ok(a._conq["sobreviva_5min"].barra.value == 0, "sem partida a barra começa vazia")
	Meta.registrar_partida({"tempo": 150, "maior_combo": 25})
	a._atualizar()
	ok(a._conq["sobreviva_5min"].barra.value == 50 and a._conq["combo_50"].barra.value == 50, "barras medem última partida")
	Meta.creditar(10000)
	for i in int(Meta.melhoria("vida").max):
		Meta.comprar("vida")
	a._atualizar()
	var vida: Dictionary = a._linhas["vida"]
	ok(vida.botao.disabled and not vida.selecionar.disabled, "máximo ainda permite selecionar detalhe")
	vida.selecionar.grab_focus()
	ok(a._detalhe.text.contains("nível máximo"), "máximo explica estado por foco")
	ok(vida.progresso.nivel == vida.progresso.maximo, "nível máximo preenche todos marcadores")
	ok(a._detalhe.get_minimum_size().y <= a._detalhe.size.y, "detalhe máximo cabe")
	_limpar()


func _tecla(tecla: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = tecla
	ev.physical_keycode = tecla
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	ev = InputEventKey.new()
	ev.keycode = tecla
	ev.physical_keycode = tecla
	ev.pressed = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _limpar() -> void:
	for caminho in [SAVE, SAVE + ".bak", SAVE + ".tmp", OPCOES, OPCOES + ".bak", OPCOES + ".tmp"]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
