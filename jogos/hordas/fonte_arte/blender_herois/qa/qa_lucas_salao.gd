extends Control
## QA TEMPORÁRIO (Lucas do Blender): abre o Salão da v2 com um personagem Lucas (o Salão agora mostra a folha do herói do personagem) e fotografa o herói
## parado e andando, em várias direções. Não altera o jogo. Fica em fonte_arte/blender_herois/qa/: copie este arquivo e o .tscn para projeto/testes/ antes de rodar.
## Uso (janela oculta, renderizando):
##   Godot --path jogos/hordas/projeto res://testes/qa_lucas_salao.tscn -- --saida=<png> [--quadro=0] [--dir=0] [--pos=480,330]
## --quadro = coluna da folha (0 parado; 1 a 6 andar); --dir = linha (0 baixo, 1 esquerda, 2 direita, 3 cima, 4 baixo_esq, 5 baixo_dir, 6 cima_esq, 7 cima_dir).
## Usa personagem isolado (user://qa_lucas_*), sem tocar nos saves reais.
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
var saida := ""
var quadro := 0
var dir := 0
var pos := Vector2(480, 330)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
		elif a.begins_with("--quadro="):
			quadro = int(a.trim_prefix("--quadro="))
		elif a.begins_with("--dir="):
			dir = int(a.trim_prefix("--dir="))
		elif a.begins_with("--pos="):
			var xy := a.trim_prefix("--pos=").split(",")
			pos = Vector2(float(xy[0]), float(xy[1]))
	var prefixo := "qa_lucas_%d_" % Time.get_ticks_usec()
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	Meta.caminho_save = "user://" + prefixo + "meta.cfg"
	Personagens.ativar(Personagens.criar("Lucas", "lucas"))
	DisplayServer.window_set_size(Vector2i(960, 540))
	var s = load("res://v2/salao.tscn").instantiate()
	add_child(s)
	await get_tree().process_frame
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
	get_tree().quit()
