extends Control
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
const Mapas = preload("res://v2/mapas.gd")
var falhas := 0
var pasta := ""
var variante := "depois"
var s
var chamadas := []
var reais := {}
var prefixo := ""


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prints="):
			pasta = arg.trim_prefix("--prints=")
		if arg.begins_with("--variante="):
			variante = arg.trim_prefix("--variante=")
	prefixo = "qa_visual_%d_" % Time.get_ticks_usec()
	var d := DirAccess.open("user://")
	for arquivo in d.get_files():
		if arquivo.begins_with("v2_"):
			reais[arquivo] = FileAccess.get_md5("user://" + arquivo)
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	Meta.caminho_save = "user://" + prefixo + "meta.cfg"
	var id := Personagens.criar("Matheus")
	ok(Personagens.ativar(id), "slot isolado ativo")
	DisplayServer.window_set_size(Vector2i(960, 540))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if variante == "antes":
		s = load("res://v2/salao.tscn").instantiate()
		s.set_script(load(pasta.path_join("salao_antes.gd")))
	else:
		s = load("res://v2/salao.tscn").instantiate()
	add_child(s)
	s.ao_entrar = func(cena): chamadas.append(cena)
	await get_tree().process_frame
	await get_tree().process_frame
	await foto("01_salao")
	ok(s._nome_lbl.text == "Matheus", "nome completo preservado")
	ok(s._alvos.size() == 3 + Mapas.LISTA.size(), "todas estruturas e portais")
	for a in s._alvos:
		var ponto: Vector2 = a.pos.clamp(s.ANDAR_MIN, s.ANDAR_MAX)
		ok(ponto.distance_to(a.pos) <= s.ALCANCE * 0.8, "alvo alcançavel " + str(a.id))
		s._pos = ponto
		s._atualizar_prompt()
		ok(s._prompt.visible and s._prompt_de == str(a.id), "prompt proximidade " + str(a.id))
		await foto("prompt_" + str(a.id))
		var evento := InputEventJoypadButton.new()
		evento.button_index = JOY_BUTTON_A
		evento.pressed = true
		s._unhandled_input(evento)
		if a.tipo == "estrutura":
			ok(s._painel.visible, "A abre " + str(a.id))
			await get_tree().process_frame
			await foto("painel_" + str(a.id))
			for i in s._p_itens.size():
				s._mostrar_item(i)
				s._p_detalhe.visible = true
				await get_tree().process_frame
				await foto("item_" + str(a.id) + "_%02d" % i)
			s._fechar_painel()
		else:
			ok(chamadas.size() > 0 and Mapas.escolhido() == str(a.id), "A usa portal " + str(a.id))
	# Clique passa pelo handler da sala; simula deslocamento acelerado sem trocar cenas.
	for a in s._alvos:
		s._pos = Vector2(480, 480)
		var mouse := InputEventMouseButton.new()
		mouse.position = a.pos
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		s._unhandled_input(mouse)
		ok(s._destino == a.pos, "clique seleciona alvo " + str(a.id))
		for quadro in 300:
			if s._destino == Vector2.INF:
				break
			s._process(1.0 / 60.0)
		ok(s._destino == Vector2.INF, "clique chega e usa " + str(a.id))
		if s._painel.visible:
			s._fechar_painel()
	ok(Mapas.condicao({"requer": "combo_50"}).begins_with("Fechado"), "condicao bloqueada preservada")
	ok(Mapas.condicao({}) == "", "portais sem requisito abertos")
	Meta.creditar(300)
	s._atualizar_textos()
	ok(s.comprar_item("dano") and Meta.nivel("dano") == 1, "compra no save isolado")
	s._pos = Vector2(480, 400)
	s._destino = Vector2.INF
	await foto("02_salao_almas")
	await bench("parado", false)
	await bench("andando", true)
	for arquivo in reais:
		ok(FileAccess.get_md5("user://" + arquivo) == reais[arquivo], "save real intacto " + arquivo)
	for arquivo in d.get_files():
		if arquivo.begins_with(prefixo):
			d.remove(arquivo)
	s.queue_free()
	s = null
	await get_tree().process_frame
	await get_tree().process_frame
	print("v2_salao_visual variante=%s falhas=%d" % [variante, falhas])
	get_tree().quit(1 if falhas else 0)


func foto(nome: String) -> void:
	if pasta.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join(variante + "_" + nome + ".png"))


func bench(nome: String, andando: bool) -> void:
	var inicio := Time.get_ticks_usec()
	var n := 0
	if andando:
		Input.action_press("direita")
	while Time.get_ticks_usec() - inicio < 3000000:
		await get_tree().process_frame
		n += 1
	if andando:
		Input.action_release("direita")
	var segundos := float(Time.get_ticks_usec() - inicio) / 1000000.0
	print(
		(
			"bench_%s_%s fps=%.2f frames=%d segundos=%.3f draw_calls=%d objetos=%d renderer=%s"
			% [
				variante,
				nome,
				n / segundos,
				n,
				segundos,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				RenderingServer.get_video_adapter_name()
			]
		)
	)
