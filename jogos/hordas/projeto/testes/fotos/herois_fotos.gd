extends Control
## Prints dos quatro heróis do Blender (Hazaki, Matheus, Lucas, Nicão) com a MESMA regra de folha: HUD na partida, Santuário (parado e andando) e a escolha
## de personagem. Não roda no CI (fica em testes/fotos/). Usa personagens isolados (user://qa_herois_*): os saves reais não são tocados.
## Uso (janela fora da tela): godot --path jogos/hordas/projeto --position -3000,0 res://testes/fotos/herois_fotos.tscn -- --fotos=PASTA
## Grava, por herói: partida_<id>.png, salao_<id>_parado.png, salao_<id>_andando.png e escolha_<id>.png (em 960x540).
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
const Mundo = preload("res://v2/mundo.tscn")
const CASOS := [
	["hazaki", "Breno", "hazaki"],
	["matheus", "Matheus", "hazaki"],
	["lucas", "Lucas", "lucas"],
	["nicao", "Nicão", "nicao"],
]
const PASSO := 1.0 / 60.0
var pasta := "user://herois_fotos"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	Config.temporario("pausar_fora", false)  # a janela fora da tela perde o foco: a pausa abriria sobre os prints
	DirAccess.make_dir_recursive_absolute(pasta)
	var prefixo := "qa_herois_%d_" % Time.get_ticks_usec()
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	DisplayServer.window_set_size(Vector2i(960, 540))
	for c in CASOS:
		var id := Personagens.criar(str(c[1]), str(c[2]))
		Meta.caminho_save = "user://" + prefixo + "meta_%s.cfg" % c[0]
		Personagens.ativar(id)
		await _partida(str(c[0]))
		await _salao(str(c[0]))
		await _escolha(str(c[0]), id)
	print("fotos: fim")
	get_tree().quit()


func _partida(nome: String) -> void:
	var w = Mundo.instantiate()
	w.modo_teste = false
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	for i in 3:
		await get_tree().process_frame
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	for i in 90:  # a chegada do herói (o clarão de nascer) acaba antes da foto
		w.avancar(PASSO)
	w.mouse_forcado = w.heroi.centro() + Vector2(0, 100)
	for i in 12:
		w.avancar(PASSO)
	var tam = await w.ap.foto(pasta.path_join("partida_%s.png" % nome))
	print("FOTO partida_%s %s coluna=%d" % [nome, tam, w.heroi.coluna])
	remove_child(w)
	w.queue_free()
	for i in 3:
		await get_tree().process_frame


func _salao(nome: String) -> void:
	var s = load("res://v2/salao.tscn").instantiate()
	add_child(s)
	await get_tree().process_frame
	s.set_process(false)
	s.set_process_input(false)
	s.set_process_unhandled_input(false)
	await _foto_salao(s, nome + "_parado", 0, 0)
	await _foto_salao(s, nome + "_andando", 3, 2)
	remove_child(s)
	s.queue_free()
	await get_tree().process_frame


func _foto_salao(s, nome: String, quadro: int, dir: int) -> void:
	s._pos = Vector2(480, 330)
	s._dir = dir
	s._quadro = quadro
	s._heroi.position = s._pos
	s._heroi.queue_redraw()
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(pasta.path_join("salao_%s.png" % nome))
	print("FOTO salao_%s %s (folha %s)" % [nome, img.get_size(), s._sprite.resource_path.get_file()])


## A escolha de personagem sem rosto.png (pasta vazia): o retrato é o quadro parado da folha do personagem ou do herói dele.
func _escolha(nome: String, id: String) -> void:
	var t = load("res://v2/personagens.tscn").instantiate()
	add_child(t)
	for i in 6:
		await get_tree().process_frame
	t._mostrar_personagem(id)
	t._definir_retrato("", true, Personagens.folha(id))
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(pasta.path_join("escolha_%s.png" % nome))
	print("FOTO escolha_%s %s (folha %s)" % [nome, img.get_size(), (t._retrato.texture as AtlasTexture).atlas.resource_path.get_file()])
	remove_child(t)
	t.queue_free()
	await get_tree().process_frame
