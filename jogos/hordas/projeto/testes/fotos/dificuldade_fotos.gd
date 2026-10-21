extends Node
## Fotos do componente sem tocar no salão: 3 escolhas em 960x540 e 1920x1080 e uma escolha com glifos Xbox.
## Via godot_fila.ps1: res://testes/fotos/dificuldade_fotos.tscn -- --fotos=<pasta> [--janela=960x540]

const Escolha := preload("res://v2/escolha_dificuldade.gd")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const UiJanela := preload("res://v2/ui_janela.gd")
const Glifos := preload("res://v2/glifos.gd")


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.get_slice("=", 0).trim_prefix("--")] = a.get_slice("=", 1)
	var pasta := str(args.get("fotos", "user://"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	var prefixo := "foto_dificuldade_%d_" % Time.get_ticks_usec()
	Meta.caminho_save = "user://" + prefixo + "meta.cfg"
	Config.arquivo = "user://" + prefixo + "opcoes.cfg"
	Config.recarregar()
	if Config._prop_timer != null:
		Config._prop_timer.process_mode = Node.PROCESS_MODE_DISABLED  # a foto exata pode ultrapassar a área útil do monitor
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	print("dificuldade_fotos user_dir=", OS.get_user_data_dir())
	var tela := Control.new()
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tela)
	var ajuste := UiJanela.new().montar(tela, "grande")
	tela.add_child(ajuste)
	var escolha := Escolha.new()
	tela.add_child(escolha)
	Glifos.forcado = true
	Glifos.definir(Glifos.Disp.TECLADO)
	var tamanhos := [Vector2i(960, 540), Vector2i(1920, 1080)]
	if args.has("janela"):
		var partes := str(args.janela).split("x")
		tamanhos = [Vector2i(int(partes[0]), int(partes[1]))]
	for tamanho in tamanhos:
		get_window().size = tamanho
		await get_tree().process_frame
		ajuste.refazer()
		var cursor := InputEventMouseMotion.new()
		cursor.position = get_viewport().get_final_transform() * Vector2.ZERO
		cursor.global_position = cursor.position
		Input.parse_input_event(cursor)
		Input.flush_buffered_events()
		for id in ["facil", "medio", "dificil"]:
			Meta.escolher_dificuldade(id)
			escolha.abrir("Ruínas da Floresta")
			await _foto(pasta.path_join("dificuldade_%dx%d_%s.png" % [tamanho.x, tamanho.y, id]))
	Glifos.definir(Glifos.Disp.XBOX)
	await _foto(pasta.path_join("dificuldade_%dx%d_dificil_xbox.png" % [get_window().size.x, get_window().size.y]))
	tela.queue_free()
	await get_tree().process_frame
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with(prefixo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	get_tree().quit()


func _foto(caminho: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(caminho)
	print("FOTO ", caminho)
