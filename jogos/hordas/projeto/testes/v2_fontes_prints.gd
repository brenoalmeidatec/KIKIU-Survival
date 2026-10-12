extends Node
## Prints de conferência das fontes da v2 (precisa de janela, não roda em --headless). Só o viewport do Godot; nunca a área de trabalho.
##   godot --path jogos/hordas/projeto res://testes/v2_fontes_prints.tscn -- --fotos=PASTA --prefixo=antes
## Grava PREFIXO_graficos_500.png (pausa > Ajustes > Gráficos na linha "Máximo de inimigos vivos", valor 500, com o "*" de "sem efeito"),
## PREFIXO_carta_nivel.png (a escolha do nível 20), PREFIXO_santuario.png, PREFIXO_pausa.png e PREFIXO_resultado.png.
## Usa saves temporários (meta e opções), como os outros testes da v2.
const Mundo := preload("res://v2/mundo.tscn")
const Altar := preload("res://v2/altar.tscn")
const Meta := preload("res://v2/meta.gd")
const Resultado := preload("res://v2/resultado_meta.gd")
const SAVE_TESTE := "user://teste_v2_fontes_meta.cfg"
const OPCOES_TESTE := "user://teste_v2_fontes_opcoes.cfg"


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
		print("v2_fontes_prints: ferramenta de olhar, use --fotos=PASTA (com janela). falhas=0")  # o CI roda toda cena de testes/ e pede "falhas=0"
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(pasta)
	await _mundo(pasta, prefixo)
	await _santuario(pasta, prefixo)
	for c in [SAVE_TESTE, OPCOES_TESTE]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))
	Config.arquivo = "user://opcoes.cfg"
	print("v2_fontes_prints em ", pasta)
	get_tree().quit()


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


func _achar_pausa(pai: Node) -> Node:
	for c in pai.get_children():
		if c.has_method("abrir_sair"):
			return c
	return null


func _ir_para(pausa, id: String) -> void:
	for i in 80:
		if pausa.sel < pausa._itens_atuais.size() and str(pausa._itens_atuais[pausa.sel].id) == id:
			return
		_tecla(KEY_DOWN)


func _mundo(pasta: String, prefixo: String) -> void:
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	var sv: SubViewport = mundo.sv
	var pausa = _achar_pausa(sv)
	Config.g_aplicar_perfil("alto")  # max_inimigos = 500
	_tecla(KEY_ESCAPE)
	await mundo.ap.foto(pasta.path_join(prefixo + "_pausa.png"))
	_tecla(KEY_DOWN)  # Continuar -> Ajustes
	_tecla(KEY_ENTER)
	_ir_para(pausa, "graficos")
	_tecla(KEY_ENTER)
	_ir_para(pausa, "g:op:max_inimigos")
	await mundo.ap.foto(pasta.path_join(prefixo + "_graficos_500.png"))
	_tecla(KEY_ESCAPE)
	_tecla(KEY_ESCAPE)
	_tecla(KEY_ESCAPE)  # fecha a pausa
	await get_tree().process_frame
	# carta de nível: três cartas de raridades diferentes, com a build escrita embaixo
	var c = mundo.combate
	c.limpar_partida()
	c.diretor.ligado = false
	mundo.heroi.imortal = true
	var cs = c.cartas
	for par in [["aura_fogo", 4], ["laminas", 2], ["corvos", 3], ["raio", 2], ["runa", 2]]:
		for i in int(par[1]):
			cs.aplicar(cs.montar_carta(cs.definicao(str(par[0])), 1 + (i % 3)))
	mundo.heroi.nivel = 20
	var achada := 0
	for semente in 400:
		cs.rng.seed = semente
		var tres: Array = cs.sortear(3, 20)
		var raridades := {}
		for k in tres:
			raridades[int(k.rar)] = true
		if raridades.size() == 3:
			achada = semente
			break
	cs.rng.seed = achada
	c.progresso.cartas = cs.sortear(3, 20)
	c.jogo = "escolha"
	c.pausado = true
	c.telas.mostrar_escolha(c.progresso.cartas, 20)
	mundo.set_process(true)  # a trava de 3 s da escolha anda em tempo real; espera liberar para a foto mostrar as cartas acesas
	await get_tree().create_timer(3.5).timeout
	mundo.set_process(false)
	await mundo.ap.foto(pasta.path_join(prefixo + "_carta_nivel.png"))
	# resultado com as almas
	c.telas.esconder()
	c.jogo = "jogando"
	c.pausado = false
	var res = mundo.meta_res
	if res == null:
		res = Resultado.new()
		res.montar(mundo)
		sv.add_child(res)
	res._terminar({"tempo": 412.0, "abates": 58, "nivel": 8, "maior_combo": 34, "venceu": false, "almas": 46})
	await get_tree().create_timer(2.4).timeout
	await mundo.ap.foto(pasta.path_join(prefixo + "_resultado.png"))
	res._terminou = true
	mundo.queue_free()
	await get_tree().process_frame


func _santuario(pasta: String, prefixo: String) -> void:
	Meta.creditar(300)
	Meta.comprar("vida")
	Meta.comprar("vida")
	Meta.comprar("dano")
	Meta.comprar("ima")
	Meta.comprar("folego")
	Meta.checar_ao_vivo(300.0, 50)
	Meta.creditar(120)
	Meta.comprar("treino")
	Meta.registrar_partida({"tempo": 212.0, "abates": 44, "nivel": 6, "maior_combo": 17, "venceu": false, "almas": 0})
	var a = Altar.instantiate()
	add_child(a)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join(prefixo + "_santuario.png"))
	a.queue_free()
	await get_tree().process_frame
