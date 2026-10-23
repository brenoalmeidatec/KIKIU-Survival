extends Control
## Prints do Nicão (folha do Blender) no Salão da v2, em 960x540. Não roda no CI (fica em testes/fotos/). O Salão (v2/salao.gd) desenha a folha do herói
## do personagem ativo (Herois.sprite); aqui o ativo joga o Nicão. Usa um personagem isolado (user://qa_nicao_*), sem tocar nos saves reais.
## Uso (janela oculta): godot --path jogos/hordas/projeto res://testes/fotos/nicao_salao_fotos.tscn -- --fotos=PASTA
## Grava salao_parado.png (coluna 0, de frente), salao_andando.png (andar3, direita) e salao_andando_baixo.png (andar1, de frente).
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
var pasta := "user://nicao_salao"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	Config.temporario("pausar_fora", false)  # a janela fora da tela perde o foco: a pausa abriria sobre os prints
	DirAccess.make_dir_recursive_absolute(pasta)
	var prefixo := "qa_nicao_%d_" % Time.get_ticks_usec()
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	Meta.caminho_save = "user://" + prefixo + "meta.cfg"
	Personagens.ativar(Personagens.criar("Nicão", "nicao"))
	DisplayServer.window_set_size(Vector2i(960, 540))
	var s = load("res://v2/salao.tscn").instantiate()
	add_child(s)
	await get_tree().process_frame
	s.set_process(false)
	s.set_process_input(false)
	s.set_process_unhandled_input(false)
	await _foto(s, "salao_parado", 0, 0)
	await _foto(s, "salao_andando", 4, 2)
	await _foto(s, "salao_andando_baixo", 1, 0)
	print("fotos: fim")
	get_tree().quit()


func _foto(s, nome: String, quadro: int, dir: int) -> void:
	s._pos = Vector2(480, 330)
	s._dir = dir
	s._quadro = quadro
	s._heroi.position = s._pos
	s._heroi.queue_redraw()
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var caminho := pasta.path_join(nome + ".png")
	img.save_png(caminho)
	print("FOTO %s %s" % [caminho, img.get_size()])
