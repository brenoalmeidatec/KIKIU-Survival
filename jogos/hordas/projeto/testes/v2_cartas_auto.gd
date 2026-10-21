extends "res://testes/isolamento_v2.gd"
# Teste da escolha AUTOMÁTICA das cartas da v2 (cartas.escolha_automatica, progresso.automatico, o botão do meio e as teclas Q / Y do controle).
# Confere: completa uma fusão a que falta uma peça; sobe um golpe que o herói já tem; cobre o que falta (golpe novo); a raridade sai rebaixada
# (nunca passa de rara e sai mais comum que no sorteio normal); aplica a carta de verdade e fecha a escolha sem gastar rerrolar nem banir; o botão,
# o Q e o Y do controle chamam o automático; a trava descarta; o botão fica no meio da tela entre Rerrolar e Banir.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_cartas_auto.tscn  (imprime "v2_cartas_auto falhas=0")
# Fotos: godot --path jogos/hordas/projeto res://testes/v2_cartas_auto.tscn -- --fotos=PASTA  (grava a tela de escolha e sai)
const Mundo := preload("res://v2/mundo.tscn")
const Glifos := preload("res://v2/glifos.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var mouse_pos := Vector2(480, 270)


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _mouse_teste() -> Vector2:
	return mouse_pos


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.combate.cartas.rng.seed = 777
	w.combate.telas.mouse_fn = Callable(self, "_mouse_teste")
	w.combate.telas.espera_escolha = 0.0
	passos(3)


func subir_nivel() -> void:
	var h = w.heroi
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	for i in 120:
		if w.combate.jogo == "escolha":
			break
		w.avancar(PASSO)
	w.combate.telas.espera_escolha = 0.0
	passos(1)


func dar(id: String, n: int) -> void:
	var cs = w.combate.cartas
	for k in n:
		cs.aplicar(cs.montar_carta(cs.definicao(id), 0))


func _tecla(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	return e


func _clique(pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	return e


func _run() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
		get_tree().quit()
		return
	_testes()
	print("v2_cartas_auto falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _testes() -> void:
	zerar()
	var cs = w.combate.cartas
	var ev: Dictionary = cs.cfg.evolucoes[0]
	var a: String = ev.pecas[0].id
	var b: String = ev.pecas[1].id

	# 1. fusão: a peça A já no nível pedido, o automático traz a B
	dar(a, int(ev.pecas[0].nivel))
	dar(b, int(ev.pecas[1].nivel) - 1)
	var c: Dictionary = cs.escolha_automatica(5)
	ok(str(c.get("id", "")) == b, "completa a fusão: a carta é a peça que falta (%s, esperava %s)" % [c.get("id", ""), b])

	# 2. a raridade vem rebaixada: nunca épica nem lendária
	var soma_auto := 0
	var soma_normal := 0
	var maior := 0
	for i in 400:
		var r: int = int(cs.escolha_automatica(15).rar)
		soma_auto += r
		maior = maxi(maior, r)
		soma_normal += cs.sortear_raridade(15)
	ok(maior <= 1, "o automático nunca passa de rara (maior raridade %d)" % maior)
	ok(soma_auto < soma_normal, "a raridade média do automático é menor que a do sorteio normal (%d contra %d)" % [soma_auto, soma_normal])

	# 3. sobe um golpe que já tem (com 3 golpes na mão, o alvo de "cobrir o que falta" já foi cumprido; sem fusão no meio)
	zerar()
	var tem: Array = []
	for d in cs.cfg.golpes:
		if tem.size() < 3 and cs.fusao_de(str(d.id)) == "" and (d.get("herois", [w.combate.heroi_id]) as Array).has(w.combate.heroi_id):
			tem.append(str(d.id))
	ok(tem.size() == 3, "existem 3 golpes sem fusão para o teste")
	for id in tem:
		dar(str(id), 1)
	var ups := 0
	for i in 30:
		if tem.has(str(cs.escolha_automatica(3).id)):
			ups += 1
	ok(ups >= 27, "com 3 golpes, o automático sobe um que já tem (%d de 30)" % ups)

	# 4. cobre o que falta: sem golpe nenhum, traz golpe novo
	zerar()
	var golpes := 0
	for i in 20:
		if str(cs._cat.get(str(cs.escolha_automatica(1).id), "")) == "golpe":
			golpes += 1
	ok(golpes >= 15, "sem golpe nenhum, o automático traz golpe novo (%d de 20)" % golpes)

	# 5. na tela: aplica a carta, fecha a escolha e não gasta rerrolar nem banir
	zerar()
	subir_nivel()
	ok(w.combate.jogo == "escolha", "o nível abre a escolha")
	var t = w.combate.telas
	var esc0: int = w.combate.progresso.escolhidas
	var rr0: int = cs.rerrolar_usados
	w._input(_tecla(KEY_Q))
	ok(w.combate.jogo == "jogando" and w.combate.progresso.escolhidas == esc0 + 1, "Q escolhe sozinho e fecha a escolha")
	ok(cs.rerrolar_usados == rr0 and cs.banimentos_restantes() == int(cs.cfg.escolha.banir_total), "o automático não gasta rerrolar nem banir")

	# 6. botão do meio com o mouse, e Y do controle
	zerar()
	subir_nivel()
	mouse_pos = t._btn_a.position + t._btn_a.size * 0.5
	w._input(_clique(mouse_pos))
	ok(w.combate.jogo == "jogando", "clicar no botão Automático escolhe sozinho")
	zerar()
	subir_nivel()
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	w._input(y)
	ok(w.combate.jogo == "jogando", "o botão Y do controle escolhe sozinho")

	# 7. a trava descarta o automático
	zerar()
	subir_nivel()
	t.espera_escolha = 0.5
	w._input(_tecla(KEY_Q))
	ok(w.combate.jogo == "escolha", "na trava o automático é descartado")
	var banimentos_trava: int = cs.banimentos_restantes()
	w._input(y)
	var lb := InputEventJoypadButton.new()
	lb.button_index = JOY_BUTTON_LEFT_SHOULDER
	lb.pressed = true
	w._input(lb)
	ok(w.combate.jogo == "escolha" and cs.banimentos_restantes() == banimentos_trava, "na trava Y e LB não escolhem nem banem")
	t.espera_escolha = 0.0
	w.combate.progresso.escolher(0)

	# 8. o botão fica no meio da tela, entre Rerrolar e Banir, sem encostar neles
	var cx: float = t._btn_a.position.x + t._btn_a.size.x * 0.5
	ok(absf(cx - 480.0) < 0.5, "o botão Automático está no centro da tela (%.1f)" % cx)
	ok(
		t._btn_r.position.x + t._btn_r.size.x < t._btn_a.position.x and t._btn_a.position.x + t._btn_a.size.x < t._btn_b.position.x,
		"Rerrolar, Automático e Banir não se sobrepõem"
	)
	ok(t._btn_b.position.x + t._btn_b.size.x <= 960.0 and t._btn_r.position.x >= 0.0, "os três botões cabem na tela")
	# Os glifos de LB/L1 são mais largos: o texto deve continuar dentro do botão, depois da coluna reservada ao glifo.
	for d in 3:
		Glifos.definir(d)
		for botao in [t._btn_r, t._btn_a, t._btn_b]:
			var texto: Label = botao.get_node("t")
			var glifo: Control = botao.get_node("glifo")
			var largura := texto.get_theme_font("font").get_string_size(texto.text, HORIZONTAL_ALIGNMENT_LEFT, -1, texto.get_theme_font_size("font_size")).x
			ok(largura <= texto.size.x, "texto '%s' cabe no botão no dispositivo %d" % [texto.text, d])
			ok(
				glifo.get_minimum_size().x <= glifo.size.x and glifo.position.x + glifo.size.x < texto.position.x,
				"glifo e texto não se sobrepõem no dispositivo %d" % d
			)
			ok(texto.position.x + texto.size.x <= botao.size.x, "a coluna de texto termina dentro do botão")
	Glifos.definir(Glifos.Disp.TECLADO)

	# 9. sem carta nenhuma disponível, o automático devolve vazio
	zerar()
	for id in cs._def:
		cs.banidas[id] = true
	ok(cs.escolha_automatica(3).is_empty(), "sem carta disponível o automático devolve vazio")


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	zerar()
	var cs = w.combate.cartas
	var ev: Dictionary = cs.cfg.evolucoes[0]
	dar(str(ev.pecas[0].id), int(ev.pecas[0].nivel))
	subir_nivel()
	var t = w.combate.telas  # a trava corre em tempo real: libera à mão para a foto sair com as cartas e os botões acesos
	t._liberar_cartas()
	t._marcar()
	t._atualizar_botoes()
	passos(3)
	var tam = await w.ap.foto(pasta.path_join("cartas_auto.png"))
	print("FOTO cartas_auto %s" % tam)


func _ready() -> void:
	_run()
