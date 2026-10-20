extends Node
# Fotos da lista de conquistas na PAUSA da partida (#373), numa janela real (sem --headless): conquistas_<nome>_menu.png (a pausa com o
# atalho "Conquistas"), _lista.png (a lista, parada na primeira) e _fim.png (rolada até a última). Usa meta TEMPORÁRIA
# (user://foto_conq_*) com um recorde de 3 min e combo 33, e a partida em andamento com 4 min e combo 20 (a lista mostra o maior).
# Roda: godot --path jogos/hordas/projeto res://testes/fotos/conquistas_fotos.tscn -- --fotos=<pasta> [--nome=x] [--janela=1920x1080]
const Meta := preload("res://v2/meta.gd")
const Mundo := preload("res://v2/mundo.tscn")


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.get_slice("=", 0).substr(2)] = a.get_slice("=", 1)
	Meta.caminho_save = "user://foto_conq_meta.cfg"
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("foto_conq_"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	Meta.registrar_partida({"tempo": 180.0, "maior_combo": 33})
	Meta.registrar_partida({"tempo": 100.0, "venceu": true, "mapa": "floresta", "mapa_vencido_agora": false})
	if args.has("janela"):
		var p := str(args.janela).split("x")
		get_window().size = Vector2i(int(p[0]), int(p[1]))
		await get_tree().create_timer(0.5).timeout
	var pasta := str(args.get("fotos", "user://"))
	var nome := str(args.get("nome", "x"))
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	mundo.tempo_partida = 240.0
	mundo.maior_combo = 20
	var pausa = null
	for c in mundo.ui.get_children():
		if c.has_method("abrir_sair"):
			pausa = c
	pausa.pausar()
	await get_tree().create_timer(0.5).timeout
	await _foto(pasta, "conquistas_%s_menu.png" % nome)
	pausa._executar("conquistas", 0)
	await get_tree().create_timer(0.5).timeout
	await _foto(pasta, "conquistas_%s_lista.png" % nome)
	pausa.sel = 6
	pausa._desenhar()
	await get_tree().create_timer(0.5).timeout
	await _foto(pasta, "conquistas_%s_fim.png" % nome)
	print("FOTO ok ", get_window().size)
	get_tree().quit()


func _foto(pasta: String, arquivo: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join(arquivo))
