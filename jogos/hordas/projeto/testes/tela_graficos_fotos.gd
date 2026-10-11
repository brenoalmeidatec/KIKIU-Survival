extends Node
# Prints da aba Gráficos (#150) numa janela real (sem --headless). Só o viewport do jogo é salvo, nunca a área de trabalho.
# Usa o dublê da API (testes/graficos_api_falsa.gd), então serve antes da API entrar na main.
# Roda: godot --path jogos/hordas/projeto res://testes/tela_graficos_fotos.tscn -- --fotos=<pasta> --perfis=baixo,alto
# Salva graficos_<perfil>.png (topo e CPU) e graficos_<perfil>_gpu.png (lista rolada até a GPU).
const Falsa := preload("res://testes/graficos_api_falsa.gd")
const Tela := preload("res://cenas/tela_graficos.tscn")


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("FOTOS: precisa de janela (rode sem --headless)")
		get_tree().quit()
		return
	for acao in ["cima", "baixo", "esquerda", "direita", "confirmar", "voltar"]:   # o jogo cria as ações em main.gd (_teclas); aqui, sem o jogo
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.get_slice("=", 0).substr(2)] = a.get_slice("=", 1)
	var pasta := str(args.get("fotos", "user://"))
	for p in str(args.get("perfis", "baixo,alto")).split(","):
		var api := Falsa.new()
		api.g_aplicar_perfil(p)
		var t = Tela.instantiate()
		t.api = api
		add_child(t)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta.path_join("graficos_%s.png" % p))
		t._rolagem = t._rolagem_max
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta.path_join("graficos_%s_gpu.png" % p))
		t.queue_free()
		await get_tree().process_frame
		api.free()
		print("FOTO ok: ", p)
	get_tree().quit()
