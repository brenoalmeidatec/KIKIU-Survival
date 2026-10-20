extends Node
## Teste do FIM DE JOGO da v2 (v2/vitoria_final.gd). Fluxo real, sem modo_teste: vencer o chefão das RUÍNAS (o mapa final) -> resultado
## -> CONTINUAR -> tela de VITÓRIA FINAL -> créditos -> menu principal; vencer o chefão de outro mapa vai ao santuário e NÃO mostra a
## vitória final; pular (Enter/A passam de etapa, Esc/Start/B pulam tudo, entrada cedo demais é ignorada) e a rolagem até o fim.
## Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_vitoria_final.tscn  (imprime "v2_vitoria_final falhas=0")
## Fotos (com janela): ... res://testes/v2_vitoria_final.tscn -- --fotos=PASTA   (vitoria_final.png e creditos.png)
const Mundo := preload("res://v2/mundo.tscn")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const VitoriaFinal := preload("res://v2/vitoria_final.gd")
const Creditos := preload("res://v2/creditos.gd")
const SAVE_REAL := "user://v2_progresso.cfg"
var falhas := 0
var caminho := ""


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	var real_antes := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	var antigo := Meta.caminho_save
	var prefixo := "user://teste_v2_vitoria_final_%s_" % Time.get_ticks_usec()
	Personagens.caminho_base = prefixo + "personagem_"
	Personagens.caminho_indice = prefixo + "personagens.cfg"
	Personagens.caminho_antigo = prefixo + "antigo.cfg"
	var personagem := Personagens.criar("Breno")
	Personagens.ativar(personagem)
	caminho = "user://teste_v2_vitoria_final_%s.cfg" % Time.get_ticks_usec()
	Meta.caminho_save = caminho
	reparent(get_tree().root)  # a troca de cena não pode levar o teste junto
	get_tree().current_scene = null
	_dados()
	if pasta != "":
		await _fotos(pasta)
	else:
		await _fluxo_final()
		await _fluxo_outro_mapa("floresta")
		await _fluxo_outro_mapa("cidade")
		await _cena_pular()
		await _cena_rolagem()
	Meta.caminho_save = antigo
	for arquivo in [Personagens.caminho_indice, Personagens.caminho_do_save(personagem)]:
		if FileAccess.file_exists(arquivo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(arquivo))
	for sufixo in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(caminho + sufixo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho + sufixo))
	var real_depois := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	ok(real_antes == real_depois, "progresso real preservado")
	print("v2_vitoria_final falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)


# ------------------------------------------------------------------ dados e regras puras


func _dados() -> void:
	var d: Dictionary = Dados.json("v2_vitoria_final")
	ok(VitoriaFinal.mapa_final() == "medio", "o mapa final é as Ruínas (medio)")
	ok(Dados.json("v2_niveis").mapas.has(VitoriaFinal.mapa_final()), "o mapa final existe em v2_niveis")
	for chave in ["titulo", "subtitulo", "creditos_titulo", "agradecimento"]:
		ok(str(d.get(chave, "")) != "", "texto %s nos dados" % chave)
	ok(d.get("texto", []) is Array and d.texto.size() > 0, "o texto de encerramento é uma lista de parágrafos")
	# o mapa final é o último da cadeia: nenhum outro mapa depende de vencê-lo
	var depende := false
	var mapas: Dictionary = Dados.json("v2_progressao").mapas
	for id in mapas:
		for c in mapas[id]:
			if str(c.get("conquista", "")) == "vence_" + VitoriaFinal.mapa_final():
				depende = true
	ok(not depende, "nenhum mapa abre ao vencer o mapa final")
	ok(VitoriaFinal.eh_final({"venceu": true, "mapa": "medio"}), "vitória nas Ruínas é o final")
	ok(not VitoriaFinal.eh_final({"venceu": false, "mapa": "medio"}), "morrer nas Ruínas não é o final")
	ok(not VitoriaFinal.eh_final({"venceu": true, "mapa": "cidade"}), "vencer outro mapa não é o final")
	ok(not VitoriaFinal.eh_final({}), "resultado vazio não é o final")
	ok(VitoriaFinal.destino({"venceu": true, "mapa": "medio"}, "x") == VitoriaFinal.CENA, "destino da vitória final")
	ok(VitoriaFinal.destino({"venceu": true, "mapa": "floresta"}, "x") == "x", "destino dos outros mapas é o padrão")
	ok(ResourceLoader.exists(VitoriaFinal.CENA) and ResourceLoader.exists(VitoriaFinal.MENU), "as cenas existem")


# ------------------------------------------------------------------ fluxo real com a partida


## Põe uma partida de verdade no mapa, mata o chefão e devolve o mundo já com o resultado aberto.
func _partida_ate_resultado(mapa: String):
	Meta.caminho_save = caminho
	var tree := get_tree()
	var w = Mundo.instantiate()
	w.id_mapa = mapa
	tree.root.add_child(w)
	tree.current_scene = w
	w.set_process(false)
	w.combate.audio.mudo = true
	w.combate.diretor.ligado = false
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.imortal = true
	await tree.process_frame
	var dir = w.combate.diretor
	dir.ir_para_nivel(dir.niveis_total)  # o chefão do último nível do mapa
	w.avancar(1.0 / 60.0)
	ok(w.combate.chefes.vivo and not bool(w.combate.chefes.marca.mini), "%s: o chefão está em campo" % mapa)
	w.combate.ferir(w.combate.chefes.atual, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	w.combate.processar_mortes()
	for i in 400:
		if w.meta_res.aberto:
			break
		w.avancar(1.0 / 60.0)
	ok(w.combate.jogo == "vitoria" and w.meta_res.aberto, "%s: a vitória abre o resultado" % mapa)
	ok(Meta.mapa_vencido(mapa), "%s: o mapa fica vencido no save" % mapa)
	return w


func _continuar(w) -> void:
	var res = w.meta_res
	res.set_process(false)
	res._process(0.9)
	_tecla(KEY_ENTER)
	ok(res._saindo, "CONTINUAR no resultado aceitou a entrada")
	await get_tree().process_frame
	await get_tree().process_frame


func _fluxo_final() -> void:
	var tree := get_tree()
	ok(not Meta.mapa_vencido("medio"), "as Ruínas começam sem vitória no save")
	var w = await _partida_ate_resultado("medio")
	await _continuar(w)
	var cena = tree.current_scene
	ok(cena != null and cena.scene_file_path == VitoriaFinal.CENA, "vencer as Ruínas leva à vitória final, não ao santuário")
	if cena == null or cena.scene_file_path != VitoriaFinal.CENA:
		return
	ok(Meta.mapa_vencido("medio"), "a primeira vitória nas Ruínas ficou no save")
	ok(cena.fase == VitoriaFinal.Fase.VITORIA, "começa na tela de vitória final")
	var textos := _textos(cena)
	ok(textos.has(str(Dados.json("v2_vitoria_final").titulo)), "a tela mostra o título dos dados")
	cena.set_process(false)
	_tecla(KEY_ENTER)
	ok(cena.fase == VitoriaFinal.Fase.VITORIA, "entrada logo no começo é ignorada")
	cena._process(1.0)
	_tecla(KEY_ENTER)
	ok(cena.fase == VitoriaFinal.Fase.CREDITOS, "Enter passa da vitória aos créditos")
	cena._process(1.0)
	ok(cena._creditos.visible and not cena._vitoria.visible, "os créditos aparecem no lugar da vitória")
	# deixa a rolagem terminar sozinha (o tempo anda aqui, em passos grandes)
	for i in 400:
		if cena.fase == VitoriaFinal.Fase.FIM:
			break
		cena._process(0.5)
	ok(cena.fase == VitoriaFinal.Fase.FIM, "os créditos terminam rolando")
	await tree.process_frame
	await tree.process_frame
	ok(tree.current_scene != null and tree.current_scene.scene_file_path == VitoriaFinal.MENU, "no fim volta ao menu principal")
	if tree.current_scene != null:
		tree.current_scene.queue_free()
	await tree.process_frame
	# a segunda vitória nas Ruínas também mostra o fim (o jogador pode rever os créditos)
	var w2 = await _partida_ate_resultado("medio")
	await _continuar(w2)
	ok(tree.current_scene != null and tree.current_scene.scene_file_path == VitoriaFinal.CENA, "vencer as Ruínas de novo mostra o fim de novo")
	if tree.current_scene != null:
		tree.current_scene.queue_free()
	await tree.process_frame


func _fluxo_outro_mapa(mapa: String) -> void:
	var tree := get_tree()
	var w = await _partida_ate_resultado(mapa)
	await _continuar(w)
	var cena = tree.current_scene
	ok(cena != null and cena.scene_file_path == "res://v2/salao.tscn", "%s: a vitória normal volta ao santuário" % mapa)
	ok(cena == null or cena.scene_file_path != VitoriaFinal.CENA, "%s: NÃO mostra a vitória final" % mapa)
	if cena != null:
		cena.queue_free()
	await tree.process_frame


# ------------------------------------------------------------------ a cena sozinha


func _cena() -> Control:
	var c: Control = load(VitoriaFinal.CENA).instantiate()
	c.ao_menu = func() -> void: c.set_meta("foi_ao_menu", int(c.get_meta("foi_ao_menu", 0)) + 1)
	get_tree().root.add_child(c)
	c.set_process(false)
	return c


func _cena_pular() -> void:
	var tree := get_tree()
	# Enter: vitória -> créditos -> menu
	var c := _cena()
	c._process(1.0)
	_tecla(KEY_ENTER)
	ok(c.fase == VitoriaFinal.Fase.CREDITOS, "Enter: vitória -> créditos")
	c._process(1.0)
	_tecla(KEY_KP_ENTER)
	ok(c.fase == VitoriaFinal.Fase.FIM and int(c.get_meta("foi_ao_menu", 0)) == 1, "Enter nos créditos: vai ao menu (uma vez)")
	_tecla(KEY_ENTER)
	ok(int(c.get_meta("foi_ao_menu", 0)) == 1, "depois de sair, mais entrada não repete a saída")
	c.queue_free()
	await tree.process_frame
	# A do controle
	c = _cena()
	c._process(1.0)
	_pad(JOY_BUTTON_A)
	ok(c.fase == VitoriaFinal.Fase.CREDITOS, "A do controle passa a vitória")
	c._process(1.0)
	_pad(JOY_BUTTON_A)
	ok(c.fase == VitoriaFinal.Fase.FIM, "A do controle pula os créditos")
	c.queue_free()
	await tree.process_frame
	# Esc pula tudo, da vitória
	c = _cena()
	c._process(1.0)
	_tecla(KEY_ESCAPE)
	ok(c.fase == VitoriaFinal.Fase.FIM and int(c.get_meta("foi_ao_menu", 0)) == 1, "Esc na vitória pula tudo e vai ao menu")
	c.queue_free()
	await tree.process_frame
	# Start e B pulam tudo, dos créditos
	for botao in [JOY_BUTTON_START, JOY_BUTTON_B]:
		c = _cena()
		c._process(1.0)
		_tecla(KEY_ENTER)
		c._process(1.0)
		_pad(botao)
		ok(c.fase == VitoriaFinal.Fase.FIM, "botão %d do controle pula os créditos" % botao)
		c.queue_free()
		await tree.process_frame
	# clique
	c = _cena()
	c._process(1.0)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(480, 270)
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	ok(c.fase == VitoriaFinal.Fase.CREDITOS, "clique passa a vitória")
	c.queue_free()
	await tree.process_frame
	# uma tecla qualquer não pula
	c = _cena()
	c._process(1.0)
	_tecla(KEY_W)
	ok(c.fase == VitoriaFinal.Fase.VITORIA, "tecla qualquer não pula")
	c.queue_free()
	await tree.process_frame


func _cena_rolagem() -> void:
	var tree := get_tree()
	var c := _cena()
	c._process(1.0)
	c.proxima()
	var y0: float = c._creditos.position.y
	c._process(1.0)
	ok(c._creditos.position.y < y0, "os créditos sobem")
	# as linhas de Ajustes > Créditos estão todas na rolagem (rótulo e valor), sem lista duplicada
	var textos := _textos(c)
	for l in Creditos.LINHAS:
		ok(textos.has(str(l.rotulo)) and textos.has(str(l.valor)), "créditos mostram '%s' / '%s'" % [l.rotulo, l.valor])
	ok(textos.has(str(Dados.json("v2_vitoria_final").agradecimento)), "o agradecimento fecha os créditos")
	ok(int(c.get_meta("foi_ao_menu", 0)) == 0, "ainda não saiu")
	c.queue_free()
	await tree.process_frame


# ------------------------------------------------------------------ fotos


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	var c := _cena()
	c.set_process(true)
	for i in 120:
		await get_tree().process_frame
	await _foto(pasta, "vitoria_final.png")
	c.set_process(false)
	c.proxima()
	c._cred_y = 60.0  # o meio da rolagem
	c._posicionar_creditos()
	for i in 4:
		await get_tree().process_frame
	await _foto(pasta, "creditos.png")
	c.queue_free()
	await get_tree().process_frame


func _foto(pasta: String, nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(pasta.path_join(nome))


# ------------------------------------------------------------------ utilidades


func _textos(raiz: Node) -> Array:
	var r: Array = []
	for n in raiz.find_children("*", "Label", true, false):
		r.append(n.text)
	return r


func _tecla(k: Key) -> void:
	for pressionado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionado
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _pad(botao: JoyButton) -> void:
	for pressionado in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = botao
		e.pressed = pressionado
		Input.parse_input_event(e)
		Input.flush_buffered_events()
