extends Control
## QA TEMPORÁRIO (estudo do herói do Blender): abre o Salão da v2 e troca a textura do herói por uma folha externa, só no print.
## Não altera o jogo. Precisa do Salão (v2/salao.gd, vem da main). Uso (janela oculta, renderizando):
##   Godot --path jogos/hordas/projeto res://testes/qa_heroi_estilo.tscn -- --folha=<caminho sem _albedo.png> --saida=<png> [--dir=0] [--pos=480,300]
## Sem --folha usa a folha atual do jogo. Usa personagem isolado (user://qa_heroi_*), sem tocar nos saves reais.
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
var folha := ""
var saida := ""
var dir := 0
var pos := Vector2(480, 330)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folha="):
			folha = a.trim_prefix("--folha=")
		elif a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
		elif a.begins_with("--dir="):
			dir = int(a.trim_prefix("--dir="))
		elif a.begins_with("--pos="):
			var xy := a.trim_prefix("--pos=").split(",")
			pos = Vector2(float(xy[0]), float(xy[1]))
	var prefixo := "qa_heroi_%d_" % Time.get_ticks_usec()
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
	s._quadro = 0
	s._heroi.position = pos
	s._heroi.queue_redraw()
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(saida.get_base_dir())
	img.save_png(saida)
	print("QA_HEROI ok ", img.get_size())
	get_tree().quit()
