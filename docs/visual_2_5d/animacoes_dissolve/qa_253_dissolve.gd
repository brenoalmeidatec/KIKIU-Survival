extends SceneTree
var w
var output := ""
var check_new := false
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
		if arg == "--verificar-dissolve":
			check_new = true
	AudioServer.set_bus_mute(0, true)
	load("res://v2/meta.gd").caminho_save = "user://qa253_%s.cfg" % Time.get_ticks_usec()
	root.get_node("Config").g_perfil_temporario("medio")
	seed(253)
	w = load("res://v2/mundo.tscn").instantiate()
	w.modo_teste = true
	root.size = Vector2i(960, 540)
	root.add_child(w)
	w.set_process(false)
	await process_frame
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	var fx = w.combate.fx
	var atores := []
	for i in 3:
		var m = w.nascer_monstro("inimigo_lobo_sombrio", w.heroi.pos + Vector2(-150 + i * 150, 70))
		m.escala = 2.0
		atores.append(m)
	for m in atores:
		fx.flash(m, 0.24, Color(0.85, 0.95, 1.0), 1)
		w.monstros.erase(m)
	w.horda.atualizar(w.t, w.cam.retangulo(), w.quadros)
	var mat := fx._fl[0].material as ShaderMaterial
	if check_new:
		ok(is_equal_approx(float(mat.get_shader_parameter("dissolver")), 0.0), "morte inicia sem dissolver")
	fx.atualizar(0.06)
	await shot("morte_25")
	fx.atualizar(0.06)
	await shot("morte_50")
	if check_new:
		ok(is_equal_approx(float(mat.get_shader_parameter("dissolver")), 0.5), "morte dissolve com progresso do jogo")
		var antes = mat.get_shader_parameter("dissolver")
		await process_frame
		await process_frame
		ok(mat.get_shader_parameter("dissolver") == antes, "sem atualizar tempo de jogo dissolve fica parado")
	fx.atualizar(0.06)
	await shot("morte_75")
	if check_new:
		fx._fi = 0
		fx.flash(atores[0], 0.2, Color.WHITE, 0)
		ok(is_equal_approx(float(mat.get_shader_parameter("dissolver")), 0.0), "reuso para dano limpa dissolve")
		fx._fi = 0
		fx.flash(atores[0], 0.2, Color.WHITE, 2)
		ok(is_equal_approx(float(mat.get_shader_parameter("dissolver")), 0.0), "reuso para esquiva limpa dissolve")
	ok(fx._fl.size() == 24, "pool continua com24 slots")
	print("QA253_DISSOLVE falhas=", falhas)
	quit(0 if falhas == 0 else 1)


func shot(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var img: Image = w.sv.get_texture().get_image()
		ok(img.get_size() == Vector2i(960, 540), "viewport960x540")
		img.save_png(output.path_join(nome + ".png"))
