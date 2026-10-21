extends Node
# Fotos do salão/santuário numa janela real (sem --headless): salao_<nome>.png (sala), salao_<nome>_<estrutura>.png (painéis das
# ESTÁTUAS, do ALTAR e do CÓDICE) e salao_<nome>_item_<id>.png (card de um item das ESTÁTUAS, pedido em --itens). Com --compras=1,
# compra dois níveis de vida e cumpre a conquista de tempo antes, para as barras terem o que mostrar. Com --max=1, compra a vida
# até o último nível (card NO MÁXIMO). Sem --compras, o treino fica BLOQUEADA (falta a conquista).
# Usa personagem e meta TEMPORÁRIOS (user://foto_salao_*). Só o viewport do jogo é salvo.
# Roda: godot --path jogos/hordas/projeto res://testes/fotos/salao_fotos.tscn -- --fotos=<pasta> [--nome=x] [--almas=0] [--compras=1]
# [--max=1] [--itens=treino,vida] [--janela=1920x1080] [--codice_fim=1] (o Códice rolado até o fim: salao_<nome>_codice_fim.png)
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
	for f in DirAccess.get_files_at("user://"):  # zera os saves temporários de uma foto anterior
		if f.begins_with("foto_salao_"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	Personagens.ativar(Personagens.criar("Breno"))
	Meta.creditar(int(args.get("almas", 0)))
	if str(args.get("compras", "0")) == "1":
		Meta.comprar("vida")
		Meta.comprar("vida")
		Meta.registrar_partida({"tempo": 320.0})  # cumpre "Sobreviva 5 minutos" (libera o Treino de guerreiro)
	if args.has("partida"):  # --partida=tempo,combo: uma partida que não cumpre as conquistas, para o Códice mostrar progresso (3/5 min)
		var pt := str(args.partida).split(",")
		Meta.registrar_partida({"tempo": float(pt[0]), "maior_combo": int(pt[1])})
	if args.has("venceu"):  # --venceu=floresta: vence o chefe do mapa (a conquista Vença a ... fica cumprida)
		Meta.registrar_partida({"tempo": 100.0, "venceu": true, "mapa": str(args.venceu), "mapa_vencido_agora": false})
	if args.has("max"):  # a vida no último nível: o card mostra NO MÁXIMO
		Meta.creditar(100000)
		for _i in int(Meta.melhoria("vida").max):
			Meta.comprar("vida")
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
	for id in ["estatuas", "altar", "codice"]:
		s.abrir_estrutura(id)
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta.path_join("salao_%s_%s.png" % [nome, id]))
		s._fechar_painel()
	if args.has("codice_fim"):  # o Códice rolado até o fim: a última linha (Vença as Ruínas, "o fim da jornada") e a Pesadelo
		s.abrir_estrutura("codice")
		await get_tree().create_timer(0.8).timeout
		s._p_rolagem.scroll_vertical = int(s._p_rolagem.get_v_scroll_bar().max_value)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta.path_join("salao_%s_codice_fim.png" % nome))
		s._fechar_painel()
	# Um card por foto: treino (BLOQUEADA sem a conquista) e o que vier em --itens (ex.: vida, NO MÁXIMO com --max=1).
	for item in str(args.get("itens", "")).split(",", false):
		s.abrir_estrutura("estatuas")
		for i in s._p_itens.size():
			if str(s._p_itens[i].id) == item:
				s._mostrar_item(i)
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta.path_join("salao_%s_item_%s.png" % [nome, item]))
		s._fechar_painel()
	print("FOTO ok ", get_window().size)
	get_tree().quit()
