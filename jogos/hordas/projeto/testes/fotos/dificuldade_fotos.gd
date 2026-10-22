extends Node
## Fotos do componente sem tocar no salão: 3 escolhas em 960x540 e 1920x1080 e uma escolha com glifos Xbox.
## Via godot_fila.ps1: res://testes/fotos/dificuldade_fotos.tscn -- --fotos=<pasta> [--janela=960x540]

const Escolha := preload("res://v2/escolha_dificuldade.gd")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const Glifos := preload("res://v2/glifos.gd")

var _viewport: SubViewport


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.get_slice("=", 0).trim_prefix("--")] = a.get_slice("=", 1)
	var pasta := str(args.get("fotos", "user://"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	var pasta_save := "user://foto_dificuldade_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta_save))
	Meta.caminho_save = pasta_save.path_join("meta.cfg")
	Config.arquivo = pasta_save.path_join("opcoes.cfg")
	Config.recarregar()
	Personagens.caminho_indice = pasta_save.path_join("indice.cfg")
	Personagens.caminho_base = pasta_save.path_join("p")
	Personagens.caminho_antigo = pasta_save.path_join("antigo.cfg")
	print("dificuldade_fotos user_dir=", OS.get_user_data_dir())
	# O viewport próprio garante os pixels solicitados mesmo quando o monitor não comporta uma janela 1920x1080.
	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var tela := Control.new()
	tela.size = Vector2(960, 540)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(tela)
	var escolha := Escolha.new()
	tela.add_child(escolha)
	Glifos.forcado = true
	Glifos.definir(Glifos.Disp.TECLADO)
	var tamanhos := [Vector2i(960, 540), Vector2i(1920, 1080)]
	if args.has("janela"):
		var partes := str(args.janela).split("x")
		tamanhos = [Vector2i(int(partes[0]), int(partes[1]))]
	for tamanho in tamanhos:
		_viewport.size = tamanho
		_viewport.canvas_transform = Transform2D.IDENTITY.scaled(Vector2(tamanho) / Vector2(960, 540))
		for id in ["facil", "medio", "dificil"]:
			Meta.escolher_dificuldade(id)
			escolha.abrir("Ruínas da Floresta")
			await _foto(pasta.path_join("dificuldade_%dx%d_%s.png" % [tamanho.x, tamanho.y, id]))
	Glifos.definir(Glifos.Disp.XBOX)
	await _foto(pasta.path_join("dificuldade_%dx%d_dificil_xbox.png" % [_viewport.size.x, _viewport.size.y]))
	tela.queue_free()
	await get_tree().process_frame
	for f in DirAccess.get_files_at(pasta_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta_save.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta_save))
	get_tree().quit()


func _foto(caminho: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(caminho)
	print("FOTO ", caminho)
