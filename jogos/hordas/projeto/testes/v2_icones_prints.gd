extends Node
## Prints dos ícones próprios das cartas da v2 (arte do PR #272), em 960x540: a escolha de cartas, o SUA BUILD no HUD (tecla C)
## e o SUA BUILD ao lado do menu de pausa. Precisa de janela (não roda em --headless); só o viewport do Godot.
##   godot --path jogos/hordas/projeto res://testes/v2_icones_prints.tscn -- --fotos=PASTA --prefixo=depois
## Grava PREFIXO_escolha.png, PREFIXO_sua_build_hud.png e PREFIXO_sua_build_pausa.png. Sem --fotos só responde falhas=0 (o CI roda toda cena).
const Mundo := preload("res://v2/mundo.tscn")
const Meta := preload("res://v2/meta.gd")
const SAVE_TESTE := "user://teste_v2_icones_meta.cfg"
const OPCOES_TESTE := "user://teste_v2_icones_opcoes.cfg"
# a build da foto: golpes e modificadores da katana, com níveis e raridades diferentes
const BUILD := [
	["laminas", 2], ["aura_fogo", 2], ["corvos", 2], ["raio", 1], ["runa", 1], ["flechas_sombrias", 1], ["onda", 1], ["fura", 1], ["explode", 1], ["folego", 1]
]


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	Config.arquivo = OPCOES_TESTE
	var pasta := ""
	var prefixo := "foto"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--prefixo="):
			prefixo = a.trim_prefix("--prefixo=")
	if pasta == "":
		print("v2_icones_prints: ferramenta de olhar, use --fotos=PASTA (com janela). falhas=0")
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(pasta)
	get_window().size = Vector2i(960, 540)  # a tela de jogo é 960x540: a foto sai 1 para 1, sem reamostrar
	await get_tree().process_frame
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	var c = mundo.combate
	c.limpar_partida()
	c.diretor.ligado = false
	mundo.heroi.imortal = true
	var cs = c.cartas
	for par in BUILD:
		for i in int(par[1]):
			cs.aplicar(cs.montar_carta(cs.definicao(str(par[0])), 1 + (i % 3)))
	# a escolha: a primeira semente com três raridades diferentes (a mesma regra da carta de nível do teste de fontes)
	var achada := 0
	for semente in 400:
		cs.rng.seed = semente
		var raridades := {}
		for k in cs.sortear(3, 20):
			raridades[int(k.rar)] = true
		if raridades.size() == 3:
			achada = semente
			break
	cs.rng.seed = achada
	c.progresso.cartas = cs.sortear(3, 20)
	c.jogo = "escolha"
	c.pausado = true
	c.telas.mostrar_escolha(c.progresso.cartas, 20)
	mundo.set_process(true)  # a trava da escolha anda em tempo real; espera ela soltar para a foto mostrar as cartas acesas
	await get_tree().create_timer(3.5).timeout
	mundo.set_process(false)
	await _foto(pasta.path_join(prefixo + "_escolha.png"))
	c.telas.esconder()
	c.jogo = "jogando"
	c.pausado = false
	mundo.status.alternar()  # tecla C: o SUA BUILD no HUD
	await get_tree().process_frame
	await _foto(pasta.path_join(prefixo + "_sua_build_hud.png"))
	mundo.status.alternar()
	await get_tree().process_frame
	_tecla(KEY_ESCAPE)  # a pausa mostra o SUA BUILD ao lado do menu
	await get_tree().process_frame
	await _foto(pasta.path_join(prefixo + "_sua_build_pausa.png"))
	_tecla(KEY_ESCAPE)
	for arq in [SAVE_TESTE, SAVE_TESTE + ".bak", SAVE_TESTE + ".tmp", OPCOES_TESTE]:
		if FileAccess.file_exists(arq):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(arq))
	Config.arquivo = "user://opcoes.cfg"
	print("v2_icones_prints em ", pasta)
	get_tree().quit()


## Foto da janela inteira: a escolha e o card da pausa ficam fora do viewport do mundo (`mundo.ap.foto` só pega o `sv`).
func _foto(caminho: String) -> Vector2i:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(caminho)
	print("foto ", caminho.get_file(), " ", img.get_width(), "x", img.get_height())
	return img.get_size()


func _enviar(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _tecla(k: Key) -> void:
	for pressionado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionado
		_enviar(e)
