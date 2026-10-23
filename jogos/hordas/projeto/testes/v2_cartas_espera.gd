extends "res://testes/isolamento_v2.gd"
# Teste da TRAVA das cartas e do baú da v2 (tempo real, dados/v2_cartas.json: escolha.espera_s, escolha.rerrolar_espera_s, bau.bau_espera_s).
# Nada escolhe nos primeiros 1,0 s depois de a escolha abrir (clique, 1/2/3, Enter, Espaço, E, direcional, ui_accept, R, B, botões);
# depois escolhe. Rerrolar e banir travam 0,8 s; nível pendente trava 1 s de novo; o baú trava 1 s; a contagem congela com a pausa
# aberta; câmera lenta e hit-stop não mudam o tempo da trava; um clique segurado desde antes não escolhe; ESC passa pela trava; a
# contagem e a barra aparecem, e as cartas acendem ao liberar. O ESC e o Start entram pela JANELA (Input.parse_input_event, a rota do
# teclado de verdade; a pausa mora no SubViewport e só recebe pelo mundo._input) e abrem a pausa na partida, na escolha e no baú, com a
# trava congelada (na escolha o ESC pede confirmação em vez de pausar: v2_cartas_limite); o clique que escolhe a carta não vira golpe do herói (o botão segue apertado no Input).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_cartas_espera.tscn  (imprime "v2_cartas_espera falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const CARTA_Y := 146.0
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


func ate(cond: Callable, max_passos: int) -> int:
	for i in max_passos:
		if cond.call():
			return i
		w.avancar(PASSO)
	return -1 if not cond.call() else max_passos


func _mouse_teste() -> Vector2:
	return mouse_pos


func _clique(pos: Vector2, apertado := true) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = apertado
	e.position = pos
	return e


func _tecla(k: Key, eco := false, apertado := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = apertado
	e.echo = eco
	return e


func _acao(nome: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = nome
	e.pressed = true
	return e


func _start(apertado := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_START
	e.pressed = apertado
	return e


func _movimento(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	return e


## Centro da carta i na tela 960x540 (a escolha põe as três cartas em x = 76, 352, 628; 256x288 px).
func _centro_carta(i: int) -> Vector2:
	return Vector2(204.0 + 276.0 * i, 290.0)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.correr_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	w.combate.cartas.rng.seed = 12345
	w.combate.telas.mouse_fn = Callable(self, "_mouse_teste")
	w.combate.telas.espera_escolha = 0.0
	w.combate.telas.espera_bau = 0.0
	passos(3)


## Sobe de nível de verdade (câmera lenta de 0,4 s e depois a escolha). Espera a escolha abrir.
func subir_nivel() -> void:
	var h = w.heroi
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	ate(func(): return w.combate.jogo == "escolha", 120)


func trava() -> float:
	return w.combate.telas.espera_escolha


func ids_cartas() -> Array:
	var r: Array = []
	for c in w.combate.progresso.cartas:
		r.append(c.id)
	return r


## Estado que só muda se alguma carta, botão ou tecla tiver agido.
func estado() -> Array:
	var cs = w.combate.cartas
	return [w.combate.progresso.escolhidas, cs.rerrolar_usados, cs.banimentos_restantes(), w.combate.jogo, w.combate.telas.sel, ids_cartas()]


## Manda uma rajada de clique, tecla e ação em tudo que escolhe, mais os botões de rerrolar e banir.
func rajada() -> void:
	mouse_pos = _centro_carta(1)
	w._input(_clique(mouse_pos))
	w._input(_clique(mouse_pos, false))
	for k in [KEY_1, KEY_2, KEY_3, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E, KEY_LEFT, KEY_RIGHT, KEY_R, KEY_B, KEY_X, KEY_Q]:
		w._input(_tecla(k))
		w._input(_tecla(k, false, false))
	w._input(_acao("ui_accept"))
	w._input(_acao("ui_left"))
	w._input(_acao("ui_right"))
	var t = w.combate.telas
	mouse_pos = t._btn_r.position + t._btn_r.size * 0.5
	w._input(_clique(mouse_pos))
	mouse_pos = t._btn_b.position + t._btn_b.size * 0.5
	w._input(_clique(mouse_pos))
	mouse_pos = t._btn_a.position + t._btn_a.size * 0.5
	w._input(_clique(mouse_pos))
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	w._input(y)


func _run() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true

	# 1. a escolha abre com a trava de 1 s, a contagem e as cartas apagadas
	zerar()
	subir_nivel()
	var t = w.combate.telas
	var h = w.heroi
	ok(w.combate.jogo == "escolha", "o nível abre a escolha")
	ok(absf(trava() - 1.0) < 0.05, "a trava começa em 1 s (%.3f)" % trava())
	ok(t._sub.text == "Escolha em 1", "a legenda mostra a contagem 'Escolha em 1' (%s)" % t._sub.text)
	ok(t._cartas[0].modulate.r < 0.5, "as cartas aparecem apagadas na trava")
	ok(t._cartas[0].position.y == CARTA_Y, "sem seleção (sem realce) na trava")
	ok((t._cartas[0].get_node("espera") as ColorRect).visible, "a barra de espera aparece em cada carta")

	# 2. nada escolhe antes de 1,0 s: clique, teclas, Enter, Espaço, E, direcional, ui_accept, R, B, botões
	var antes := estado()
	passos(6)  # 0,1 s
	rajada()
	ok(estado() == antes, "na trava (0,1 s) nenhuma carta, botão ou tecla escolhe, rerrola ou bane")
	ok(t._pulso > 0.0, "o clique descartado pulsa a contagem")
	var hover: int = t.sel
	w._input(_movimento(_centro_carta(2)))
	ok(t.sel == hover, "o mouse passa sobre uma carta na trava sem trocar a seleção")
	ok(not t.entrada(_tecla(KEY_ESCAPE)), "ESC passa pela escolha (é da pausa), não é consumido")
	passos(24)  # 0,5 s de trava
	ok(t._sub.text == "Escolha em 1", "aos 0,5 s a contagem marca 'Escolha em 1' (%s)" % t._sub.text)
	ok(absf((t._cartas[0].get_node("espera") as ColorRect).size.x - 232.0 * (1.0 - trava())) < 0.1, "a barra acompanha a fração real da espera")
	antes = estado()
	rajada()
	ok(estado() == antes, "aos 0,5 s ainda nada escolhe (trava de 1 s)")
	passos(18)  # 0,8 s
	rajada()
	ok(estado() == antes, "aos 0,8 s ainda nada escolhe")
	ok(trava() > 0.0, "a trava ainda corre aos 0,8 s")

	# 3. depois da trava: as cartas acendem e a tecla 2 escolhe
	var esc0: int = w.combate.progresso.escolhidas
	ate(func(): return trava() <= 0.0, 60)
	ok(trava() <= 0.0 and t._sub.text.begins_with("Escolha uma carta"), "a trava acaba e a legenda volta ao normal (%s)" % t._sub.text)
	passos(1)
	ok(t._cartas[1].modulate.r > 1.2, "as cartas acendem ao liberar (%.2f)" % t._cartas[1].modulate.r)
	ok(t._cartas[0].position.y == CARTA_Y - 8.0, "a carta marcada aparece depois da trava")
	passos(30)
	ok(absf(t._cartas[0].modulate.r - 1.0) < 0.01, "o brilho se apaga em 0,35 s")
	var carta_2: Dictionary = w.combate.progresso.cartas[1]
	w._input(_tecla(KEY_2))
	ok(w.combate.progresso.escolhidas == esc0 + 1 and w.combate.jogo == "jogando", "depois da trava, a tecla 2 escolhe a carta %s" % carta_2.id)

	# 4. um clique segurado desde antes da liberação não escolhe nada; só um aperto novo vale
	zerar()
	mouse_pos = _centro_carta(0)
	var h2 = w.heroi
	h2.xp = h2.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	w._input(_clique(mouse_pos))  # aperto ANTES de a escolha abrir (ainda na câmera lenta: vai para o herói)
	ate(func(): return w.combate.jogo == "escolha", 120)
	esc0 = w.combate.progresso.escolhidas
	ate(func(): return trava() <= 0.0, 200)  # o botão continua apertado; a trava acaba
	ok(w.combate.progresso.escolhidas == esc0 and w.combate.jogo == "escolha", "clique segurado desde antes da liberação não escolhe")
	w._input(_clique(mouse_pos, false))
	ok(w.combate.jogo == "escolha", "soltar o botão não escolhe")
	w._input(_clique(mouse_pos))
	ok(w.combate.progresso.escolhidas == esc0 + 1 and w.combate.jogo == "jogando", "um aperto novo, depois da liberação, escolhe")

	# 5. rerrolar trava 0,8 s; a tecla 1 não escolhe antes
	zerar()
	subir_nivel()
	ate(func(): return trava() <= 0.0, 200)
	esc0 = w.combate.progresso.escolhidas
	var rer0: int = w.combate.cartas.rerrolar_usados
	w._input(_tecla(KEY_R))
	ok(w.combate.cartas.rerrolar_usados == rer0 + 1, "R rerrola depois da trava")
	ok(absf(trava() - 0.8) < 0.05, "rerrolar trava de novo por 0,8 s (%.3f)" % trava())
	passos(30)
	w._input(_tecla(KEY_1))
	ok(w.combate.progresso.escolhidas == esc0 and w.combate.jogo == "escolha", "aos 0,5 s depois de rerrolar a tecla 1 ainda não vale")
	ate(func(): return trava() <= 0.0, 60)
	w._input(_tecla(KEY_1))
	ok(w.combate.progresso.escolhidas == esc0 + 1, "depois da trava de rerrolar, a tecla 1 escolhe")

	# 6. banir trava 0,8 s
	zerar()
	subir_nivel()
	ate(func(): return trava() <= 0.0, 200)
	esc0 = w.combate.progresso.escolhidas
	var ban0: int = w.combate.cartas.banimentos_restantes()
	w._input(_tecla(KEY_B))
	ok(w.combate.cartas.banimentos_restantes() == ban0 - 1, "B bane depois da trava")
	ok(absf(trava() - 0.8) < 0.05, "banir trava por 0,8 s (%.3f)" % trava())
	w._input(_tecla(KEY_ENTER))
	ok(w.combate.progresso.escolhidas == esc0, "Enter logo depois de banir não escolhe")
	ate(func(): return trava() <= 0.0, 60)
	w._input(_tecla(KEY_ENTER))
	ok(w.combate.progresso.escolhidas == esc0 + 1, "depois da trava de banir, Enter escolhe")

	# 7. nível pendente: a próxima escolha trava de novo o segundo completo
	zerar()
	subir_nivel()
	h = w.heroi
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)  # um segundo nível enquanto a escolha está aberta: fica pendente
	ate(func(): return trava() <= 0.0, 200)
	esc0 = w.combate.progresso.escolhidas
	w._input(_tecla(KEY_1))
	ok(w.combate.progresso.escolhidas == esc0 + 1, "a primeira escolha do par vale depois da trava")
	ate(func(): return w.combate.jogo == "escolha", 120)
	ok(absf(trava() - 1.0) < 0.05, "o nível pendente abre outra escolha com a trava de 1 s (%.3f)" % trava())
	passos(30)
	w._input(_tecla(KEY_2))
	ok(w.combate.progresso.escolhidas == esc0 + 1, "a segunda escolha não vale aos 0,5 s")

	# 8. a contagem é de tempo real: câmera lenta e hit-stop não mudam nada
	ate(func(): return trava() <= 0.0, 200)
	zerar()
	subir_nivel()
	var lento_antes := trava()
	w.combate.lento_t = 10.0
	w.combate.lento_escala = 0.1
	w.combate.parada_t = 10.0
	passos(30)
	ok(absf((lento_antes - trava()) - 0.5) < 0.03, "câmera lenta e hit-stop não mudam o tempo da trava (andou %.3f)" % (lento_antes - trava()))
	w.combate.lento_t = 0.0
	w.combate.lento_escala = 1.0
	w.combate.parada_t = 0.0

	# 9. o menu de pausa congela a trava
	ate(func(): return trava() <= 0.0, 200)
	zerar()
	subir_nivel()
	passos(15)
	var com_pausa := trava()
	w.pausa.aberto = true
	passos(120)
	ok(trava() == com_pausa, "com o menu de pausa aberto a contagem congela")
	w.pausa.aberto = false
	passos(60)
	ok(trava() < com_pausa, "fechada a pausa, a contagem volta")
	ate(func(): return trava() <= 0.0, 200)

	# 10. o baú trava 1 s: o clique e o Enter antes disso são descartados
	zerar()
	w.combate.jogo = "bau"
	w.combate.pausado = true
	w.combate.telas.mostrar_bau(w.combate.cartas.sortear(2, 3))
	ok(absf(w.combate.telas.espera_bau - 1.0) < 0.001, "o baú trava por 1 s")
	w._input(_tecla(KEY_ENTER))
	w._input(_clique(Vector2(480, 270)))
	passos(30)  # 0,5 s
	w._input(_tecla(KEY_ENTER))
	ok(w.combate.telas.bau_aberto and not w.combate.telas.bau_pronto, "Enter e clique na trava do baú não pulam a roleta")
	passos(31)  # Pouco mais de 1 s no total
	ok(w.combate.telas.bau_pronto, "a roleta revela todas as recompensas automaticamente em 1 s")
	w._input(_tecla(KEY_ENTER))
	ok(w.combate.jogo == "jogando" and not w.combate.telas.bau_aberto, "Enter fecha o baú depois de 1 s")

	# Uma, duas ou três recompensas têm a mesma duração total, sem acumular o giro por carta.
	for quantidade in [1, 2, 3]:
		zerar()
		w.combate.jogo = "bau"
		w.combate.pausado = true
		t.mostrar_bau(w.combate.cartas.sortear(quantidade, 3))
		t._atualizar_bau(0.99)
		ok(not t.bau_pronto and t.espera_bau > 0.0, "%d recompensas ainda aguardam antes de 1 s" % quantidade)
		t._atualizar_bau(0.02)
		ok(t.bau_pronto and t.espera_bau == 0.0 and t._bau_i == quantidade, "%d recompensas ficam todas visíveis em 1 s" % quantidade)
		for i in quantidade:
			ok((t._bau_slots[i].get_node("nome") as Label).text != "?", "recompensa %d foi revelada" % i)

	# 11. o ESC e o Start da JANELA chegam ao menu de pausa. A pausa mora no SubViewport, que não recebe a entrada da janela: o evento
	# entra por Input.parse_input_event (a rota do teclado de verdade) e o mundo._input o entrega. Antes, nada chegava e o ESC "não funcionava".
	Input.use_accumulated_input = false  # a entrada vai ao mundo na hora, sem esperar o quadro
	zerar()
	ok(w.combate.jogo == "jogando" and not w.pausa.aberto, "partida rolando, pausa fechada")
	Input.parse_input_event(_tecla(KEY_ESCAPE))
	Input.parse_input_event(_tecla(KEY_ESCAPE, false, false))
	ok(w.pausa.aberto and get_tree().paused, "ESC da janela abre o menu de pausa na partida")
	Input.parse_input_event(_tecla(KEY_ESCAPE))
	Input.parse_input_event(_tecla(KEY_ESCAPE, false, false))
	ok(not w.pausa.aberto and not get_tree().paused, "ESC da janela de novo fecha o menu")
	Input.parse_input_event(_start())
	ok(w.pausa.aberto, "Start do controle abre o menu de pausa na partida")
	Input.parse_input_event(_start())
	ok(not w.pausa.aberto and not get_tree().paused, "Start de novo fecha")

	# 12. ESC na escolha de carta NÃO abre a pausa: pede "Pausar agora?" e a trava congela enquanto a confirmação está aberta (a árvore segue
	# andando); nada escolhe; o segundo ESC é "Não" e a trava volta a andar. A pausa de verdade abre por outro caminho (perder o foco) e congela a trava.
	zerar()
	subir_nivel()
	passos(30)
	var t_antes := trava()
	var escolhidas0: int = w.combate.progresso.escolhidas
	Input.parse_input_event(_tecla(KEY_ESCAPE))
	Input.parse_input_event(_tecla(KEY_ESCAPE, false, false))
	ok(not w.pausa.aberto and not get_tree().paused, "ESC na escolha NÃO abre a pausa")
	ok(w.combate.telas.conf_aberta, "ESC na escolha abre a confirmação")
	ok(w.combate.jogo == "escolha" and w.combate.telas.escolha_aberta, "e a escolha continua aberta por baixo")
	passos(120)
	ok(trava() == t_antes, "com a confirmação aberta a trava não anda (%.3f contra %.3f)" % [trava(), t_antes])
	for k in [KEY_1, KEY_2, KEY_3, KEY_R, KEY_B]:  # a confirmação come a entrada: nada chega às cartas
		Input.parse_input_event(_tecla(k))
		Input.parse_input_event(_tecla(k, false, false))
	ok(w.combate.progresso.escolhidas == escolhidas0 and w.combate.jogo == "escolha", "com a confirmação aberta as teclas não escolhem carta")
	Input.parse_input_event(_tecla(KEY_ESCAPE))
	Input.parse_input_event(_tecla(KEY_ESCAPE, false, false))
	ok(not w.combate.telas.conf_aberta and not w.pausa.aberto and w.combate.jogo == "escolha", "ESC de novo é 'Não': a escolha segue")
	passos(30)
	ok(trava() < t_antes, "fechada a confirmação, a trava volta a andar")
	w.pausa.pausar()  # perder o foco da janela
	var t_pausa := trava()
	passos(60)
	ok(w.pausa.aberto and trava() == t_pausa, "com a pausa aberta (foco) a trava segue parada")
	w.pausa.fechar()
	ate(func(): return trava() <= 0.0, 200)
	w._input(_tecla(KEY_2))
	ok(w.combate.progresso.escolhidas == escolhidas0 + 1 and w.combate.jogo == "jogando", "depois da trava a carta é escolhida normalmente")

	# 13. ESC no baú abre a pausa e a trava do baú congela; Voltar ao santuário na escolha encerra a partida sem deixar a tela da escolha
	zerar()
	w.combate.jogo = "bau"
	w.combate.pausado = true
	w.combate.telas.mostrar_bau(w.combate.cartas.sortear(2, 3))
	passos(15)
	var bau_antes: float = w.combate.telas.espera_bau
	Input.parse_input_event(_tecla(KEY_ESCAPE))
	Input.parse_input_event(_tecla(KEY_ESCAPE, false, false))
	ok(w.pausa.aberto and w.combate.telas.bau_aberto, "ESC no baú abre a pausa e o baú segue aberto")
	passos(90)
	ok(w.combate.telas.espera_bau == bau_antes, "com a pausa aberta a trava do baú não anda")
	Input.parse_input_event(_tecla(KEY_ESCAPE))
	Input.parse_input_event(_tecla(KEY_ESCAPE, false, false))
	ok(not w.pausa.aberto and not get_tree().paused and w.combate.jogo == "bau", "ESC de novo volta ao baú")
	zerar()
	subir_nivel()
	w.pausa.pausar()
	w.pausa._executar("santuario", 0)
	w.pausa._executar("ok_santuario", 0)
	ok(w.combate.jogo == "abandono" and not get_tree().paused, "Voltar ao santuário a partir da escolha abandona a partida")
	ok(not w.combate.telas.escolha_aberta and w.combate.telas.resultado_aberto, "a escolha some e o resultado abre")
	w.combate.jogo = "morte"  # na morte e no resultado o ESC não abre a pausa
	Input.parse_input_event(_tecla(KEY_ESCAPE))
	Input.parse_input_event(_tecla(KEY_ESCAPE, false, false))
	ok(not w.pausa.aberto and not get_tree().paused, "na morte o ESC não abre a pausa")

	# 14. o clique que escolhe a carta não vira golpe: o botão continua apertado e o herói lê o botão de atacar por polling (Input).
	# (zerar() desliga o polling com entrada_forcada; aqui o herói lê o Input de verdade.)
	zerar()
	w.heroi.entrada_forcada = null
	subir_nivel()
	ate(func(): return trava() <= 0.0, 200)
	passos(40)
	var golpes0: int = w.heroi.golpes
	esc0 = w.combate.progresso.escolhidas
	mouse_pos = _centro_carta(1)
	Input.parse_input_event(_clique(mouse_pos))  # o aperto escolhe a carta e o botão fica apertado no Input
	ok(w.combate.progresso.escolhidas == esc0 + 1 and w.combate.jogo == "jogando", "o clique na carta 2 escolhe")
	ok(Input.is_action_pressed("atacar"), "o botão de atacar segue apertado no Input (a condição do defeito)")
	passos(20)
	ok(w.heroi.golpes == golpes0, "o clique que escolheu a carta não vira golpe enquanto o botão está apertado (%d golpes)" % (w.heroi.golpes - golpes0))
	Input.parse_input_event(_clique(mouse_pos, false))  # soltou
	passos(5)
	Input.parse_input_event(_clique(mouse_pos))  # aperto novo: golpeia
	passos(5)
	ok(w.heroi.golpes > golpes0, "depois de soltar, um aperto novo golpeia normalmente")
	Input.parse_input_event(_clique(mouse_pos, false))
	Input.use_accumulated_input = true

	# 5. o analógico esquerdo não navega a escolha (cada quadro com ele acima do limite seria um aperto); o direcional do controle navega
	zerar()
	subir_nivel()
	ate(func(): return trava() <= 0.0, 200)
	var tt = w.combate.telas
	var n_cartas: int = w.combate.progresso.cartas.size()
	var mudou := 0
	for i in 10:
		var sel_antes: int = tt.sel
		var analogico := InputEventJoypadMotion.new()
		analogico.axis = JOY_AXIS_LEFT_X
		analogico.axis_value = 1.0
		tt.entrada(analogico)
		if tt.sel != sel_antes:
			mudou += 1
	ok(mudou == 0 and tt.escolha_aberta, "o analógico esquerdo, empurrado por 10 quadros, não move a seleção (%d moveram)" % mudou)
	var sel0: int = tt.sel
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_RIGHT
	pad.pressed = true
	tt.entrada(pad)
	ok(tt.sel == posmod(sel0 + 1, n_cartas), "o direcional do controle (D-pad) move a seleção uma carta (%d -> %d)" % [sel0, tt.sel])
	zerar()

	print("v2_cartas_espera falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _ready() -> void:
	_run()
