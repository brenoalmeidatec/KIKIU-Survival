extends SceneTree
var w
var output := ""
var falhas := 0


func _initialize() -> void:
	call_deferred("run")


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			output = arg.trim_prefix("--saida=")
	AudioServer.set_bus_mute(0, true)
	load("res://v2/meta.gd").caminho_save = "user://qa258_%s.cfg" % Time.get_ticks_usec()
	var cfg = root.get_node("Config")
	cfg.g_perfil_temporario("alto")
	seed(258)
	w = load("res://v2/mundo.tscn").instantiate()
	w.modo_teste = true
	root.size = Vector2i(960, 540)
	root.add_child(w)
	w.set_process(false)
	await process_frame
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	var pos = w.ap.pos_visual
	ok(pos.get_parent() == w.sv, "passe dentro do SubViewport")
	ok(pos.layer == 3, "passe antes das camadas de UI")
	ok(pos._retangulo.size == Vector2(960, 540), "passe na resolucao nativa")
	ok(pos._retangulo.visible and pos._retangulo.material != null, "Alto inicia ligado")
	pos._retangulo.visible = false
	pos._retangulo.material = null
	await shot("passe_desligado")
	pos._aplicar_perfil()
	await shot("passe_alto")
	for perfil in ["baixo", "medio", "personalizado", "alto", "medio"]:
		if perfil == "personalizado":
			cfg._cfg.set_value("graficos", "perfil", "personalizado")
		else:
			cfg.g_perfil_temporario(perfil)
		cfg.graficos_mudou.emit()
		ok(pos._retangulo.visible == (perfil == "alto"), "visibilidade perfil " + perfil)
		ok((pos._retangulo.material != null) == (perfil == "alto"), "sem material/copia fora do Alto " + perfil)
	cfg.g_perfil_temporario("alto")
	cfg.graficos_mudou.emit()
	var camada := CanvasLayer.new()
	camada.layer = 3
	w.sv.add_child(camada)
	var prova := ColorRect.new()
	prova.position = Vector2(100, 480)
	prova.size = Vector2(20, 20)
	prova.color = Color("#613589")
	camada.add_child(prova)
	for indice in [w.sv.get_child_count() - 1, 0]:
		w.sv.move_child(pos, indice)
		await process_frame
		await RenderingServer.frame_post_draw
		var tela: Image = w.sv.get_texture().get_image()
		ok(tela.get_pixel(105, 485).is_equal_approx(prova.color), "camada3 fica depois do passe mesmo apos reordenar")
	camada.queue_free()
	ok(w.sv.size == Vector2i(960, 540), "viewport nao mudou")
	ok(w.ap.tela.material != null, "upscale sharp preservado")
	print("QA258_POS falhas=", falhas)
	quit(0 if falhas == 0 else 1)


func shot(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var img: Image = w.sv.get_texture().get_image()
		img.save_png(output.path_join(nome + ".png"))
