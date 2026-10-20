extends Node
## Fotos de conferência dos glifos de controle e da grade dos menus da v2 (precisa de janela, não roda em --headless).
## Só o viewport do Godot, nunca a área de trabalho. Um dispositivo por execução, com o flag depois do "--":
##   godot --path jogos/hordas/projeto res://testes/v2_controle_fotos.tscn -- --fotos=PASTA --prefixo=depois_xbox --controle=xbox
## Grava PREFIXO_<tela>.png: titulo, ajustes, creditos, santuario, personagens, salao, hud, pausa, ajustes_partida, sua_build,
## cartas, bau e resultado (só quando o "para jogar de novo" está aceso: ele pisca). Sem --fotos sai com falhas=0 (o CI pede isso).
const Mundo := preload("res://v2/mundo.tscn")
const Altar := preload("res://v2/altar.tscn")
const Titulo := preload("res://v2/menu_principal.tscn")
const Personagens := preload("res://v2/personagens.tscn")
const Salao := preload("res://v2/salao.tscn")
const Meta := preload("res://v2/meta.gd")
const Resultado := preload("res://v2/resultado_meta.gd")
const SAVE_TESTE := "user://teste_v2_controle_meta.cfg"
const OPCOES_TESTE := "user://teste_v2_controle_opcoes.cfg"

var pasta := ""
var prefixo := "foto"


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	Config.arquivo = OPCOES_TESTE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--prefixo="):
			prefixo = a.trim_prefix("--prefixo=")
	if pasta == "":
		print("v2_controle_fotos: ferramenta de olhar, use --fotos=PASTA (com janela). falhas=0")
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(pasta)
	await _titulo()
	await _santuario()
	await _personagens()
	await _salao()
	await _partida()
	for c in [SAVE_TESTE, SAVE_TESTE + ".bak", SAVE_TESTE + ".tmp", OPCOES_TESTE]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))
	Config.arquivo = "user://opcoes.cfg"
	print("v2_controle_fotos em ", pasta)
	get_tree().quit()


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join("%s_%s.png" % [prefixo, nome]))


func _assentar(n := 4) -> void:
	for i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


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


func _titulo() -> void:
	var t = Titulo.instantiate()
	add_child(t)
	await _assentar()
	await _foto("titulo")
	t._abrir_ajustes()
	await _assentar()
	await _foto("ajustes")
	t.pausa.fechar()
	await _assentar()
	t._abrir_creditos()
	await _assentar()
	await _foto("creditos")
	t.pausa.fechar()
	t.queue_free()
	await get_tree().process_frame


func _santuario() -> void:
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
	await _assentar(3)
	await _foto("santuario")
	a.queue_free()
	await get_tree().process_frame


func _personagens() -> void:
	var p = Personagens.instantiate()
	add_child(p)
	await _assentar()
	await _foto("personagens")
	p.queue_free()
	await get_tree().process_frame


func _salao() -> void:
	var s = Salao.instantiate()
	add_child(s)
	await _assentar(12)
	await _foto("salao")
	s.queue_free()
	await get_tree().process_frame


func _pausa_de(pai: Node) -> Node:
	for c in pai.get_children():
		if c.has_method("abrir_sair"):
			return c
	return null


func _partida() -> void:
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	var sv: SubViewport = mundo.ui
	await mundo.ap.foto(pasta.path_join(prefixo + "_hud.png"))
	# pausa, depois Ajustes (o primeiro item do menu é Continuar; o segundo abre Ajustes)
	var pausa = _pausa_de(sv)
	_tecla(KEY_ESCAPE)
	await mundo.ap.foto(pasta.path_join(prefixo + "_pausa.png"))
	_tecla(KEY_DOWN)
	_tecla(KEY_ENTER)
	await mundo.ap.foto(pasta.path_join(prefixo + "_ajustes_partida.png"))
	pausa.fechar()
	await get_tree().process_frame
	if pausa.aberto:
		print("v2_controle_fotos: a pausa não fechou")
	# SUA BUILD: o card (C) com a build da partida
	_tecla(KEY_C)
	await _assentar()
	await mundo.ap.foto(pasta.path_join(prefixo + "_sua_build.png"))
	_tecla(KEY_C)
	await get_tree().process_frame
	# escolha de cartas: três raridades diferentes, com Rerrolar e Banir (a trava de 3 s anda em tempo real)
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
	mundo.set_process(true)
	await get_tree().create_timer(3.5).timeout
	mundo.set_process(false)
	await mundo.ap.foto(pasta.path_join(prefixo + "_cartas.png"))
	# baú: a roleta gira, as cartas aparecem uma a uma e a dica "para continuar" acende no fim
	c.telas.esconder()
	c.jogo = "jogando"
	c.pausado = false
	c.telas.mostrar_bau(c.progresso.cartas)
	mundo.set_process(true)
	await get_tree().create_timer(float(cs.cfg.bau.bau_espera_s) + 2.0).timeout
	c.telas._pular_bau()
	await get_tree().create_timer(0.3).timeout
	mundo.set_process(false)
	await mundo.ap.foto(pasta.path_join(prefixo + "_bau.png"))
	# resultado com as almas: o "para jogar de novo" pisca, então a foto espera a fase acesa
	c.telas.esconder()
	c.jogo = "jogando"
	c.pausado = false
	var res = mundo.meta_res
	if res == null:
		res = Resultado.new()
		res.montar(mundo)
		sv.add_child(res)
	res._terminar({"tempo": 412.0, "abates": 58, "nivel": 8, "maior_combo": 34, "venceu": false, "almas": 46})
	await get_tree().create_timer(0.6).timeout
	await mundo.ap.foto(pasta.path_join(prefixo + "_resultado_almas.png"))
	res._terminou = true
	res.queue_free()
	mundo.meta_res = null
	# resultado sem almas (telas.gd): a dica "para jogar de novo" pisca, então a foto espera a fase acesa
	c.telas.mostrar_resultado()
	mundo.set_process(true)
	for i in 80:
		await get_tree().create_timer(0.1).timeout
		if c.telas._res_dica.visible and c.telas.mostrada_t > 0.8:
			break
	await mundo.ap.foto(pasta.path_join(prefixo + "_resultado.png"))
	mundo.set_process(false)
	mundo.queue_free()
	await get_tree().process_frame
