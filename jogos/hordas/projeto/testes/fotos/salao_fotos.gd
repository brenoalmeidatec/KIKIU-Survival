extends Node
# Fotos do salão/santuário numa janela real (sem --headless): salao_<nome>.png (sala) e salao_<nome>_estatuas.png (painel das estátuas).
# Usa personagem e meta TEMPORÁRIOS (user://foto_salao_*). Só o viewport do jogo é salvo.
# Roda: godot --path jogos/hordas/projeto res://testes/fotos/salao_fotos.tscn -- --fotos=<pasta> [--nome=x] [--almas=0] [--janela=1849x1040]
const Personagens := preload("res://v2/personagens.gd")
const Meta := preload("res://v2/meta.gd")
const Salao := preload("res://v2/salao.tscn")


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.get_slice("=", 0).substr(2)] = a.get_slice("=", 1)
	Personagens.caminho_base = "user://foto_salao_p"
	Personagens.caminho_indice = "user://foto_salao_personagens.cfg"
	Personagens.caminho_antigo = "user://foto_salao_antigo.cfg"
	Meta.caminho_save = "user://foto_salao_meta.cfg"
	for f in ["user://foto_salao_personagens.cfg", "user://foto_salao_meta.cfg", "user://foto_salao_p1.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Personagens.criar("Breno")
	Personagens.ativar("p1")
	Meta.creditar(int(args.get("almas", 0)))
	if args.has("janela"):
		var p := str(args.janela).split("x")
		get_window().size = Vector2i(int(p[0]), int(p[1]))
		await get_tree().create_timer(0.5).timeout
	if args.has("tamanho_ui"):
		Config.temporario("tamanho_ui", str(args.tamanho_ui))
	var pasta := str(args.get("fotos", "user://"))
	var nome := str(args.get("nome", "x"))
	var s = Salao.instantiate()
	add_child(s)
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join("salao_%s.png" % nome))
	s.abrir_estrutura("estatuas")
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join("salao_%s_estatuas.png" % nome))
	print("FOTO ok ", get_window().size)
	get_tree().quit()
