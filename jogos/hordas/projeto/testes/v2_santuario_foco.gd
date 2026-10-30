extends "res://testes/isolamento_v2.gd"
## Regressão de foco do santuário: eventos passam pelo Input/viewport, sem controle físico.
const Meta := preload("res://v2/meta.gd")
const Altar := preload("res://v2/altar.tscn")
var falhas := 0
var a
var fotos := ""


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func(): get_tree().quit(99))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fotos="):
			fotos = arg.trim_prefix("--fotos=")
	Engine.set_meta("kikiu_entrada", true)
	Meta.registrar_partida({"tempo": 150, "abates": 120, "maior_combo": 25, "nivel": 8})
	a = Altar.instantiate()
	add_child(a)
	await _frames(5)
	print("JANELA %s %s" % [DisplayServer.get_name(), DisplayServer.window_get_size()])
	ok(get_viewport().gui_get_focus_owner() == a._entrar, "foco inicial em ENTRAR")
	_ver_cabecalho()
	await _foto("cabecalho.png")
	for controle in [false, true]:
		var nome := "dpad_sintetizado" if controle else "teclado"
		print("DISPOSITIVO ", nome)
		_liberar_extras(false)
		for fim in [false, true]:
			# O retorno do rodapé não pode variar conforme a posição da rolagem.
			a._conq.values()[-1 if fim else 0].selecionar.grab_focus()
			await _frames(3)
			a._entrar.grab_focus()
			await _mover(3, controle)
			ok(get_viewport().gui_get_focus_owner() == a._ajustes, "%s ENTRAR + direita chega a AJUSTES (fim=%s)" % [nome, fim])
			await _foto("rodape_%s_%s.png" % [nome, fim])
			a._ajustes.grab_focus()
			await _mover(2, controle)
			ok(get_viewport().gui_get_focus_owner() == a._entrar, "%s AJUSTES + esquerda chega a ENTRAR (fim=%s)" % [nome, fim])
			a._entrar.grab_focus()
			await _mover(2, controle)
			ok(get_viewport().gui_get_focus_owner() == a._mapa, "%s ENTRAR + esquerda chega ao MAPA" % nome)
			await _mover(3, controle)
			await _mover(3, controle)
			await _mover(3, controle)
			ok(get_viewport().gui_get_focus_owner() == a._voltar, "%s rodapé inteiro alcança VOLTAR" % nome)
			# A lista fora da tela não pode roubar o Cima da primeira linha de melhorias.
			for id in ["vida", "dano", "velocidade"]:
				var cartao: Button = a._linhas[id].selecionar
				cartao.grab_focus()
				await _mover(0, controle)
				ok(get_viewport().gui_get_focus_owner() == cartao, "%s cima da primeira linha permanece em %s" % [nome, id])
		# Da grade para a lista e de volta ao rodapé com eventos, sem grab_focus intermediário.
		a._linhas["velocidade"].selecionar.grab_focus()
		await _mover(3, controle)
		ok(get_viewport().gui_get_focus_owner() == a._conq.values()[0].selecionar, "%s direita da grade entra na primeira conquista" % nome)
		# Uma falha ao entrar não deve produzir dezenas de falhas em cascata na prova independente da lista.
		a._conq.values()[0].selecionar.grab_focus()
		await _frames(3)
		for i in range(1, a._conq.size()):
			await _mover(1, controle)
			var alvo: Control = a._conq.values()[i].selecionar
			ok(get_viewport().gui_get_focus_owner() == alvo, "%s baixo alcança conquista %s" % [nome, a._conq.keys()[i]])
			ok(a._rolagem.get_global_rect().encloses(alvo.get_global_rect()), "%s conquista %d fica inteiramente visível" % [nome, i])
		ok(a._rolagem.scroll_vertical > 0, "%s a lista realmente rolou" % nome)
		await _foto("ultima_conquista_%s.png" % nome)
		await _mover(2, controle)
		ok(get_viewport().gui_get_focus_owner() == a._linhas["treino"].selecionar, "%s esquerda da última conquista volta à grade" % nome)
		a._conq.values()[-1].selecionar.grab_focus()
		await _frames(3)
		await _mover(1, controle)
		ok(get_viewport().gui_get_focus_owner() == a._ajustes, "%s baixo da última conquista sai para AJUSTES" % nome)
		await _mover(2, controle)
		ok(get_viewport().gui_get_focus_owner() == a._entrar, "%s retorno da lista chega ao ENTRAR" % nome)
		await _mover(0, controle)
		ok(_eh_melhoria(get_viewport().gui_get_focus_owner()), "%s cima de ENTRAR volta às melhorias" % nome)
		# Máximo/bloqueada continuam selecionáveis e não travam a passagem para a linha seguinte.
		Meta.creditar(10000)
		for i in int(Meta.melhoria("vida").max):
			Meta.comprar("vida")
		a._atualizar()
		a._linhas["vida"].selecionar.grab_focus()
		await _mover(1, controle)
		ok(get_viewport().gui_get_focus_owner() == a._linhas["folego"].selecionar, "%s baixo pula compra máxima sem perder o foco" % nome)
		_liberar_extras(true)
		ok(a._modo_btn.visible and a._rastro_btn.visible, "%s fixture cobre os dois extras liberados" % nome)
		a._entrar.grab_focus()
		await _mover(0, controle)
		ok(get_viewport().gui_get_focus_owner() == a._rastro_btn, "%s ENTRAR + cima alcança RASTRO liberado" % nome)
		await _mover(0, controle)
		ok(get_viewport().gui_get_focus_owner() == a._modo_btn, "%s RASTRO + cima alcança PESADELO" % nome)
		await _mover(0, controle)
		ok(_eh_melhoria(get_viewport().gui_get_focus_owner()), "%s PESADELO + cima volta à grade" % nome)
		await _mover(1, controle)
		await _mover(1, controle)
		await _mover(1, controle)
		ok(get_viewport().gui_get_focus_owner() == a._entrar, "%s grade, PESADELO e RASTRO retornam ao rodapé" % nome)
	a.queue_free()
	await _frames(3)
	print("v2_santuario_foco falhas=%d" % falhas)
	get_tree().quit(falhas)


func _liberar_extras(liberados: bool) -> void:
	var cf := ConfigFile.new()
	ok(cf.load(Meta.caminho_save) == OK, "abre somente o save da fixture")
	for c in Meta.conquistas():
		cf.set_value("conquistas", str(c.id), liberados)
	ok(cf.save(Meta.caminho_save) == OK, "altera somente as conquistas da fixture")
	a._atualizar()


func _eh_melhoria(c: Control) -> bool:
	for linha in a._linhas.values():
		if c == linha.selecionar or c == linha.botao:
			return true
	return false


func _ver_cabecalho() -> void:
	# Métricas em janela contra as caixas DE PROJETO; nunca size/get_minimum_size (mínimo forçado).
	for no in a.get_children():
		if no is Label and (no.text == "SANTUÁRIO" or no == a._ultima):
			print(
				(
					"CABECALHO %s: linhas=%d fonte=%.1f caixa_projeto=%d"
					% [
						no.text,
						no.get_line_count(),
						no.get_theme_font("font").get_height(no.get_theme_font_size("font_size")),
						52 if no.text == "SANTUÁRIO" else 10
					]
				)
			)
	ok(a._ultima.text.begins_with("Última partida:"), "fixture cobre a linha com acento e dados de partida")


func _mover(direcao: int, controle: bool) -> void:
	for pressionado in [true, false]:
		var e: InputEvent
		if controle:
			var j := InputEventJoypadButton.new()
			j.button_index = [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT][direcao]
			j.pressed = pressionado
			e = j
		else:
			var k := InputEventKey.new()
			k.keycode = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT][direcao]
			k.physical_keycode = k.keycode
			k.pressed = pressionado
			e = k
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	await _frames(3)


func _foto(nome: String) -> void:
	if fotos == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(fotos)
	await RenderingServer.frame_post_draw
	ok(get_viewport().get_texture().get_image().save_png(fotos.path_join(nome)) == OK, "salvou foto externa " + nome)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
