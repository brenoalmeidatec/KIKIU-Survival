extends Control
## QA TEMPORÁRIO (montagem 1 do Hazaki do Blender): abre o Salão da v2 e troca só a textura do herói pela folha final
## (hazaki_final_albedo.png, 50 colunas, ver hazaki/LEIA-ME.md). Não altera o jogo. Copie este arquivo e o .tscn para
## projeto/testes/ antes de rodar (o .tscn aponta para res://testes/). Uso (janela oculta, renderizando):
##   Godot --path jogos/hordas/projeto res://testes/qa_hazaki_final.tscn -- --folha=<caminho sem _albedo.png> --saida=<png> [--quadro=0] [--dir=0] [--pos=480,330]
## --quadro = coluna da folha (0 parado; 1 a 6 andar; 16 a 33 combo, golpe 3 = 28 a 33; 34 a 37 escudo, 38 a 41 dano, 42 a 49 morte); --dir = linha (0 baixo, 1 esquerda, 2 direita, 3 cima, 4 baixo_esq, 5 baixo_dir, 6 cima_esq, 7 cima_dir).
## Usa personagem isolado (user://qa_hazaki_*), sem tocar nos saves reais.
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
var folha := ""
var saida := ""
var quadro := 0
var dir := 0
var pos := Vector2(480, 330)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folha="):
			folha = a.trim_prefix("--folha=")
		elif a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
		elif a.begins_with("--quadro="):
			quadro = int(a.trim_prefix("--quadro="))
		elif a.begins_with("--dir="):
			dir = int(a.trim_prefix("--dir="))
		elif a.begins_with("--pos="):
			var xy := a.trim_prefix("--pos=").split(",")
			pos = Vector2(float(xy[0]), float(xy[1]))
	var prefixo := "qa_hazaki_%d_" % Time.get_ticks_usec()
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	Meta.caminho_save = "user://" + prefixo + "meta.cfg"
	Personagens.ativar(Personagens.criar("Hazaki"))
	DisplayServer.window_set_size(Vector2i(960, 540))
	var s = load("res://v2/salao.tscn").instantiate()
	add_child(s)
	await get_tree().process_frame
	if folha != "":
		var im := Image.load_from_file(folha + "_albedo.png")
		s._sprite = ImageTexture.create_from_image(im)
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folha + ".json"))
		s._quadro_w = int(info.quadro[0])
		s._quadro_h = int(info.quadro[1])
	s.set_process(false)
	s.set_process_input(false)
	s.set_process_unhandled_input(false)
	s._pos = pos
	s._dir = dir
	s._quadro = quadro
	s._heroi.position = pos
	s._heroi.queue_redraw()
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(saida.get_base_dir())
	img.save_png(saida)
	print("QA_HAZAKI ok ", img.get_size(), " quadro=", quadro, " dir=", dir)
	get_tree().quit()
