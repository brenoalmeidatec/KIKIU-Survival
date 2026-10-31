extends "res://testes/isolamento_v2.gd"
# Teste da ROLETA das cartas de nível e do BAÚ melhor da v2 (#376; dados/v2_cartas.json: escolha.roleta_s = 1,2 s, bau.bonus_raridade, bau.piso_raridade).
# Roleta: ao abrir a escolha de nível as cartas descem em rolos e param uma a uma (esquerda -> direita) em no máximo 1,2 s de tempo real; depois de 0,3 s
# só o Enter, o A do controle e o clique SOBRE as cartas pulam para o fim (Espaço, E e o clique fora são esquiva, habilidade e ataque e não pulam); nada escolhe
# durante os rolos; a trava de 1 s corre junto e o limite de 8 s só começa quando TODAS pararam; ESC durante a roleta abre o "Pausar agora?" (o tempo dela
# fica parado; Não volta, Sim descarta a rodada); escolher no meio desfaz os rolos; roleta_s = 0 e roleta_ligada = false mostram as
# cartas direto. O enfeite dos rolos usa um sorteador próprio. Baú: raridade melhor que a escolha comum (estatística com semente), nunca comum, e a
# ESCOLHA com 12 s (bau.limite_s) contra os 8 s do nível: 1 ou 2 melhorias para pegar entre 3 cartas, automático (a mais rara) ao zerar o tempo.
# Os outros testes nascem com a roleta desligada (mundo.modo_teste); este liga.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_roleta.tscn  (imprime "v2_roleta falhas=0")
# GIF: godot --path jogos/hordas/projeto res://testes/v2_roleta.tscn -- --fotos=PASTA  (grava os quadros da roleta e sai)
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
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


func ate(cond: Callable, max_passos: int) -> int:
	for i in max_passos:
		if cond.call():
			return i
		w.avancar(PASSO)
	return -1 if not cond.call() else max_passos


func _mouse_teste() -> Vector2:
	return mouse_pos


func _tecla(k: Key, apertado := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = apertado
	return e


func _toque(k: Key) -> void:
	Input.parse_input_event(_tecla(k))
	Input.parse_input_event(_tecla(k, false))


func _acao(nome: String) -> void:
	var e := InputEventAction.new()
	e.action = nome
	e.pressed = true
	Input.parse_input_event(e)


func _botao_joy(b: JoyButton) -> void:
	for p in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = p
		Input.parse_input_event(e)


func _clique(pos: Vector2) -> void:
	mouse_pos = pos
	for p in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = p
		e.position = pos
		Input.parse_input_event(e)


func zerar() -> void:
	if w.pausa.aberto:
		w.pausa.fechar()
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.combate.cartas.rng.seed = 12345
	w.combate.telas.mouse_fn = Callable(self, "_mouse_teste")
	w.combate.telas.roleta_ligada = true
	w.combate.telas.espera_escolha = 0.0
	w.combate.telas.espera_bau = 0.0
	passos(3)


## Sobe de nível de verdade e espera a escolha abrir.
func subir_nivel() -> void:
	var h = w.heroi
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	ate(func(): return w.combate.jogo == "escolha", 120)


## Solta um baú em cima do herói e espera abrir. `picks` = quantas melhorias o sorteio dá (1 ou 2); `forcar` = o número fixado no mapa (0 = sorteia).
func abrir_bau(picks: int, forcar := 0) -> void:
	var pesos: Array = [0, 0, 0]
	pesos[picks - 1] = 1
	w.combate.cartas.cfg.bau.n_pesos = pesos
	w.combate.baus.soltar(w.heroi.pos + Vector2(8, 0), 1.0, forcar)
	ate(func(): return w.combate.jogo != "jogando", 120)


func lim() -> float:
	return w.combate.telas.limite_t


func _run() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	Input.use_accumulated_input = false
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
		get_tree().quit()
		return
	_testes()
	print("v2_roleta falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _testes() -> void:
	var c = w.combate
	var t = c.telas
	var cs = c.cartas
	var limite := float(cs.cfg.escolha.limite_s)
	var roleta_s := float(cs.cfg.escolha.roleta_s)
	ok(roleta_s > 0.0 and roleta_s <= 1.2, "a roleta vem dos dados e dura no máximo 1,2 s (%.2f)" % roleta_s)
	ok(limite == 8.0, "o limite de 8 s das cartas de nível continua (%.1f)" % limite)
	zerar()
	ok(t.roleta_ligada, "o teste liga a roleta (os outros nascem desligados)")

	# 1. BAÚ: raridade melhor que a escolha comum, nunca comum, e a trava e a quantidade de antes
	var bau: Dictionary = cs.cfg.bau
	ok(
		float(bau.bonus_raridade) >= 4.0 and int(bau.piso_raridade) == 1,
		"o baú tem bônus de raridade alto e piso raro (%s, %s)" % [bau.bonus_raridade, bau.piso_raridade]
	)
	ok(float(bau.bau_espera_s) == 1.0 and bau.n_pesos.size() == 3, "a trava do baú (1 s) e as 1 a 3 melhorias não mudaram")
	for nivel in [1, 5, 10, 20]:
		cs.rng.seed = 777
		var soma_comum := 0
		var soma_bau := 0
		var epico_comum := 0
		var epico_bau := 0
		var comum_no_bau := 0
		for i in 3000:
			var rc: int = cs.sortear(1, nivel)[0].rar
			var rb: int = cs.sortear(1, nivel, float(bau.bonus_raridade), int(bau.piso_raridade))[0].rar
			soma_comum += rc
			soma_bau += rb
			epico_comum += 1 if rc >= 2 else 0
			epico_bau += 1 if rb >= 2 else 0
			comum_no_bau += 1 if rb == 0 else 0
		ok(soma_bau > soma_comum * 1.4, "nível %d: a raridade média do baú é bem maior que a da escolha (%d contra %d)" % [nivel, soma_bau, soma_comum])
		ok(epico_bau > epico_comum * 1.2, "nível %d: o baú dá mais épicas e lendárias (%d contra %d)" % [nivel, epico_bau, epico_comum])
		ok(comum_no_bau == 0, "nível %d: o baú nunca dá comum" % nivel)
	# o baú de verdade (abrir): todas as cartas raras ou melhores
	var raras := 0
	var total := 0
	for k in 12:
		zerar()
		c.baus.soltar(w.heroi.pos + Vector2(8, 0), 1.0, 3)
		ate(func(): return c.jogo == "bau", 120)
		ok(c.jogo == "bau" and c.baus.ultimas.size() == 3, "o baú forçado abre com 3 melhorias")
		for carta in c.baus.ultimas:
			total += 1
			raras += 1 if int(carta.rar) >= 1 else 0
		c.baus.fechar()
	ok(total == 36 and raras == total, "as 36 cartas de 12 baús abertos são raras ou melhores (%d de %d)" % [raras, total])

	# 2. a roleta abre: cartas escondidas, rolos girando, nada escolhe, o limite parado
	zerar()
	subir_nivel()
	ok(c.jogo == "escolha" and t.escolha_aberta and t.roleta_ativa, "o nível abre a escolha com a roleta girando")
	ok(c.progresso.cartas.size() == 3, "três cartas (%d)" % c.progresso.cartas.size())
	for i in 3:
		ok(t._rolos[i].visible and not t._cartas[i].visible, "rolo %d aparece e a carta de verdade espera" % i)
	ok(lim() == limite, "o limite abre cheio (%.2f)" % lim())
	var esc0: int = c.progresso.escolhidas
	for k in [KEY_2, KEY_Q, KEY_LEFT]:
		_toque(k)
	ok(c.progresso.escolhidas == esc0 and c.jogo == "escolha" and t.roleta_ativa, "teclas de escolha e automático não fazem nada na roleta")

	# 3. termina em até 1,2 s, esquerda -> direita, o limite parado até o fim
	zerar()
	subir_nivel()
	var quadro_parou := [-1, -1, -1]
	var lim_correu := false
	var fim := -1
	for q in 90:
		if lim() < limite and t.roleta_ativa:
			lim_correu = true
		for i in 3:
			if t._rolo_feito[i] and quadro_parou[i] < 0:
				quadro_parou[i] = q
		if not t.roleta_ativa and fim < 0:
			fim = q
		w.avancar(PASSO)
	ok(fim >= 0 and fim <= int(round(roleta_s * 60.0)) + 1, "a roleta termina em até %.1f s (%d quadros)" % [roleta_s, fim])
	ok(fim >= int(roleta_s * 60.0) - 3, "e usa o tempo todo, sem acabar antes sozinha (%d quadros)" % fim)
	ok(
		quadro_parou[0] > 0 and quadro_parou[0] < quadro_parou[1] and quadro_parou[1] < quadro_parou[2],
		"os rolos param um a um, esquerda -> direita (%s)" % str(quadro_parou)
	)
	ok(quadro_parou[2] >= fim - 1 and quadro_parou[2] <= fim + 1, "o último para quando a roleta acaba")
	ok(not lim_correu, "o limite não correu durante a roleta")
	for i in 3:
		ok(not t._rolos[i].visible and t._cartas[i].visible, "rolo %d some e a carta de verdade fica" % i)
	ok(t._rolo_seq[0].back() == c.progresso.cartas[0], "o rolo para na carta de verdade")
	for i in 3:
		var alvo: float = t._rolo_k[i] * t.CARTA_A
		var dist: float = t._rolo_distancia(i, t._rolo_parada[i])
		ok(absf(dist - alvo) < 0.01, "o rolo %d chega alinhado numa carta inteira, sem salto (%.2f de %.2f)" % [i, dist, alvo])
		var antes: float = t._rolo_distancia(i, t._rolo_parada[i] - 0.016)
		ok(antes < alvo and antes > alvo - 40.0, "e freia: o último quadro anda pouco (%.1f)" % (alvo - antes))

	# 4. o limite de 8 s só começa depois que todos pararam (sem pular)
	zerar()
	subir_nivel()
	var gasto: int = ate(func(): return c.jogo != "escolha", 60 * 11)
	ok(gasto >= 60 * 9.2 - 4 and gasto <= 60 * 9.2 + 6, "sem pular, a escolha sai sozinha em 1,2 + 8 s (%d quadros)" % gasto)
	ok(c.jogo == "jogando", "e o jogo volta")
	zerar()
	subir_nivel()
	ate(func(): return not t.roleta_ativa, 120)
	ok(lim() >= limite - 0.05, "no quadro em que a roleta acaba o limite está cheio (%.2f)" % lim())
	passos(60)
	ok(absf(lim() - (limite - 1.0)) < 0.1, "1 s depois da roleta faltam %.1f s (%.2f)" % [limite - 1.0, lim()])
	t._automatico()

	# 5. pular: só o clique SOBRE as cartas, o Enter e o botão A do controle, e só depois de 0,3 s
	ok(t.ROLETA_PULO_MIN == 0.3, "o pulo vale a partir de 0,3 s de roleta")
	for modo in ["clique", "enter", "joy_a", "kp_enter"]:
		zerar()
		subir_nivel()
		passos(20)  # 0,33 s
		ok(t.roleta_ativa and t.roleta_t >= 0.3 and t.espera_escolha > 0.5, "(%s) a roleta ainda gira com a trava correndo" % modo)
		esc0 = c.progresso.escolhidas
		match modo:
			"clique":
				_clique(Vector2(480, 300))
			"enter":
				_toque(KEY_ENTER)
			"kp_enter":
				_toque(KEY_KP_ENTER)
			"joy_a":
				_botao_joy(JOY_BUTTON_A)
		ok(not t.roleta_ativa, "(%s) pula a roleta" % modo)
		ok(c.progresso.escolhidas == esc0 and c.jogo == "escolha", "(%s) pular não escolhe carta" % modo)
		for i in 3:
			ok(not t._rolos[i].visible and t._cartas[i].visible, "(%s) as 3 cartas aparecem" % modo)
		ok(lim() == limite, "(%s) o limite segue cheio logo depois de pular (%.2f)" % [modo, lim()])
		ok(t.espera_escolha > 0.4, "(%s) a trava de 1 s continua valendo (%.2f)" % [modo, t.espera_escolha])
		_toque(KEY_1)
		ok(c.progresso.escolhidas == esc0, "(%s) na trava a tecla 1 ainda não escolhe" % modo)
		passos(5)
		ok(lim() == limite, "(%s) o limite não corre na trava" % modo)
		ate(func(): return t.espera_escolha <= 0.0, 120)
		passos(60)
		ok(lim() < limite - 0.9 and lim() > limite - 1.3, "(%s) vencida a trava o limite corre (%.2f)" % [modo, lim()])
		_toque(KEY_2)
		ok(c.progresso.escolhidas == esc0 + 1 and c.jogo == "jogando", "(%s) e a carta 2 escolhe" % modo)

	# 5b. o que NÃO pula: Espaço (esquiva), E (habilidade), o clique fora das cartas (ataque), a ação ui_accept solta e qualquer pulo antes de 0,3 s
	for modo in ["espaco", "e", "ui_accept", "clique_fora", "enter_cedo", "clique_cedo", "joy_a_cedo"]:
		zerar()
		subir_nivel()
		passos(8 if modo.ends_with("_cedo") else 20)
		esc0 = c.progresso.escolhidas
		match modo:
			"espaco":
				_toque(KEY_SPACE)
			"e":
				_toque(KEY_E)
			"ui_accept":
				_acao("ui_accept")
			"clique_fora":
				_clique(Vector2(30, 30))
			"enter_cedo":
				_toque(KEY_ENTER)
			"clique_cedo":
				_clique(Vector2(480, 300))
			"joy_a_cedo":
				_botao_joy(JOY_BUTTON_A)
		ok(t.roleta_ativa and c.jogo == "escolha", "(%s) não pula a roleta" % modo)
		ok(c.progresso.escolhidas == esc0, "(%s) e não escolhe nada" % modo)
		passos(3)
		ok(t.roleta_ativa, "(%s) a roleta segue girando" % modo)
		if modo == "enter_cedo":
			passos(14)
			ok(t.roleta_t >= 0.3, "(enter_cedo) já passou de 0,3 s")
			_toque(KEY_ENTER)
			ok(not t.roleta_ativa, "(enter_cedo) o mesmo Enter, depois de 0,3 s, pula")

	# 6. depois da trava, pular ainda acende as cartas e libera na hora
	zerar()
	subir_nivel()
	passos(70)  # a trava (1 s) venceu, a roleta (1,2 s) ainda gira
	ok(t.roleta_ativa and t.espera_escolha == 0.0, "aos 1,17 s a trava venceu e a roleta ainda gira")
	ok(lim() == limite, "e o limite ainda está parado")
	_toque(KEY_ENTER)
	ok(not t.roleta_ativa and t._acender > 0.0, "pular acende as cartas")
	passos(30)
	ok(lim() < limite, "e o limite passa a correr")
	_toque(KEY_ENTER)
	ok(c.jogo == "jogando", "Enter depois da roleta e da trava escolhe a carta marcada")

	# 7. ESC durante a roleta: o "Pausar agora?" abre, não pausa, e o tempo da roleta fica parado
	zerar()
	subir_nivel()
	passos(20)
	var rt: float = t.roleta_t
	var trava0: float = t.espera_escolha
	_toque(KEY_ESCAPE)
	ok(t.conf_aberta and t._conf.visible, "ESC na roleta abre 'Pausar agora?'")
	ok(not w.pausa.aberto and not get_tree().paused, "e NÃO abre a pausa")
	ok(t.roleta_ativa and t.conf_sel == 1, "a roleta segue ali e 'Não' vem marcado")
	passos(60 * 3)
	ok(t.roleta_t == rt and t.roleta_ativa, "com a confirmação aberta a roleta fica parada (%.3f contra %.3f)" % [t.roleta_t, rt])
	ok(t.espera_escolha == trava0 and lim() == limite, "e a trava e o limite também")
	_toque(KEY_ENTER)  # com a confirmação aberta Enter aciona "Não", não pula a roleta
	ok(not t.conf_aberta and t.roleta_ativa, "Enter na confirmação (Não marcado) só fecha; a roleta não é pulada")
	_toque(KEY_ESCAPE)
	_toque(KEY_ESCAPE)
	ok(not t.conf_aberta and t.roleta_ativa, "ESC, ESC = abre e volta")
	passos(5)
	ok(t.roleta_t > rt, "o tempo da roleta volta a correr")
	var fim_t: int = ate(func(): return not t.roleta_ativa, 120)
	ok(fim_t >= 0 and t.roleta_t >= roleta_s - 0.02, "a roleta termina depois do ESC cancelado (%d quadros, %.2f s)" % [fim_t, t.roleta_t])
	# Sim descarta a rodada com a roleta no meio
	zerar()
	subir_nivel()
	passos(15)
	var pend: int = c.progresso.pendentes
	esc0 = c.progresso.escolhidas
	_toque(KEY_ESCAPE)
	ok(t.conf_aberta, "ESC de novo na roleta abre a confirmação")
	_toque(KEY_LEFT)
	_toque(KEY_ENTER)
	ok(w.pausa.aberto and c.jogo == "jogando" and not t.escolha_aberta, "Sim descarta a rodada e abre a pausa")
	ok(c.progresso.escolhidas == esc0 and c.progresso.pendentes == pend - 1, "nenhuma carta escolhida e o nível pendente consumido")
	ok(not t.roleta_ativa, "a roleta acabou junto")
	for i in 3:
		ok(not t._rolos[i].visible, "nenhum rolo fica na tela (%d)" % i)
	# a escolha seguinte rola do começo
	zerar()
	subir_nivel()
	ok(t.roleta_ativa and t.roleta_t < 0.05, "a próxima escolha rola do começo")
	var visiveis := 0
	for i in 3:
		visiveis += 1 if t._cartas[i].visible else 0
	ok(visiveis == 0, "com as cartas ainda escondidas (%d visíveis)" % visiveis)

	# 8. pausa aberta (menu) também para a roleta
	zerar()
	subir_nivel()
	passos(10)
	rt = t.roleta_t
	w.pausa.pausar()
	passos(60)
	ok(t.roleta_t == rt, "com a pausa aberta a roleta não anda")
	w.pausa.fechar()
	passos(5)
	ok(t.roleta_t > rt, "e volta a andar quando a pausa fecha")

	# 9. escolher no meio (Automático por código) desfaz os rolos e esconde a tela
	zerar()
	subir_nivel()
	passos(10)
	t._automatico()
	ok(not t.roleta_ativa and c.jogo == "jogando" and not t.escolha_aberta, "escolher fecha a escolha e a roleta")
	for i in 3:
		ok(not t._rolos[i].visible and t._cartas[i].visible, "rolo %d escondido e carta de volta" % i)

	# 11. desligar: reduzir animação (roleta_ligada = false) e roleta_s = 0
	zerar()
	t.roleta_ligada = false
	subir_nivel()
	ok(not t.roleta_ativa and t._cartas[0].visible and t._cartas[1].visible and t._cartas[2].visible, "sem roleta as cartas aparecem direto")
	ok(absf(t.espera_escolha - 1.0) < 0.05, "e a trava de 1 s é a de antes (%.2f)" % t.espera_escolha)
	t._automatico()
	zerar()
	cs.cfg.escolha["roleta_s"] = 0.0
	subir_nivel()
	ok(not t.roleta_ativa and t._cartas[2].visible, "roleta_s = 0 desliga a roleta")
	t._automatico()
	cs.cfg.escolha["roleta_s"] = roleta_s
	ok(not t.animacao_reduzida(), "a opção de reduzir animações vem desligada")
	if not Config.item(t.OPCAO_REDUZIR).is_empty():  # o #377 cria a opção "reduzir_animacoes": com ela ligada a roleta não roda
		zerar()
		Config.temporario(t.OPCAO_REDUZIR, true)
		ok(t.animacao_reduzida(), "com a opção ligada animacao_reduzida() vale")
		subir_nivel()
		ok(not t.roleta_ativa and t._cartas[0].visible and t._cartas[2].visible, "e a roleta não roda")
		t._automatico()
		Config.temporario(t.OPCAO_REDUZIR, false)

	# 12. com duas cartas só dois rolos giram, e a roleta também fecha em até 1,2 s
	zerar()
	var duas: Array = cs.sortear(2, 3)
	c.progresso.cartas = duas
	c.jogo = "escolha"
	c.pausado = true
	t.mostrar_escolha(duas, 3)
	ok(t.roleta_ativa and not t._rolos[2].visible and t._rolo_feito[2], "com duas cartas só dois rolos giram")
	var q2: int = ate(func(): return not t.roleta_ativa, 120)
	ok(q2 >= 0 and q2 <= 73, "e a roleta de duas cartas também fecha em até 1,2 s (%d)" % q2)
	t.esconder()
	c.pausado = false
	c.jogo = "jogando"

	# 13. BAÚ COM ESCOLHA: 12 s (contra os 8 s do nível), 1 ou 2 melhorias para PEGAR entre 3 cartas raras, automático no fim
	var pesos0: Array = bau.n_pesos.duplicate()
	var lim_bau := float(bau.limite_s)
	ok(lim_bau == 12.0 and lim_bau > limite, "o baú dá mais tempo para escolher que o nível: %.0f s contra %.0f s" % [lim_bau, limite])
	# 13a. uma melhoria (n_pesos [1, 0, 0]): a escolha abre na tela do nível, com a roleta, 12 s
	zerar()
	abrir_bau(1)
	ok(c.jogo == "escolha" and t.escolha_aberta and not t.bau_aberto, "o baú de 1 melhoria abre a escolha (não a roleta de revelação): %s" % c.jogo)
	ok(c.progresso.bau_picks == 1 and t._escolha_do_bau() and t._titulo.text == "BAÚ!", "é a escolha do baú (%d a pegar)" % c.progresso.bau_picks)
	var cand: Array = c.progresso.cartas.duplicate()
	ok(cand.size() == 3, "com 3 cartas (%d)" % cand.size())
	var todas_raras := true
	for carta in cand:
		todas_raras = todas_raras and int(carta.rar) >= int(bau.piso_raridade)
	ok(todas_raras, "todas raras ou melhores (o piso do baú)")
	ok(t.roleta_ativa, "a roleta das cartas gira também no baú")
	ok(lim() == lim_bau and t._limite_total == lim_bau, "o limite abre com os 12 s do baú (%.2f)" % lim())
	ok(t._btn_a.visible, "o Automático aparece no baú")
	var nivel0: int = c.progresso.pendentes
	ok(c.baus.ultimas.is_empty(), "nenhuma carta foi aplicada antes de escolher")
	var gasto_bau: int = ate(func(): return c.jogo != "escolha", 60 * 15)
	ok(gasto_bau >= 60 * 13.2 - 4 and gasto_bau <= 60 * 13.2 + 6, "sem mexer, o baú escolhe sozinho em 1,2 + 12 s (%d quadros)" % gasto_bau)
	var melhor: Dictionary = cand[0]
	for carta in cand:
		if int(carta.rar) > int(melhor.rar):
			melhor = carta
	ok(c.baus.ultimas.size() == 1 and c.baus.ultimas[0].id == melhor.id, "e pega a mais rara (%s)" % str(c.baus.ultimas.map(func(x): return x.id)))
	ok(c.jogo == "jogando" and not c.pausado and c.progresso.bau_picks == 0 and not t.escolha_aberta, "o jogo volta")
	ok(c.progresso.pendentes == nivel0, "sem mexer nos níveis pendentes")
	# 13b. escolher à mão: pular a roleta, esperar a trava e apertar 3
	zerar()
	abrir_bau(1)
	cand = c.progresso.cartas.duplicate()
	passos(20)
	_toque(KEY_ENTER)
	ate(func(): return t.espera_escolha <= 0.0, 120)
	passos(2)
	_toque(KEY_3)
	ok(c.jogo == "jogando" and c.baus.ultimas.size() == 1 and c.baus.ultimas[0].id == cand[2].id, "a tecla 3 pega a terceira carta do baú")
	# 13c. duas melhorias: pega uma, as outras duas ficam na tela sem roleta e o limite recomeça com 12 s
	zerar()
	abrir_bau(2)
	cand = c.progresso.cartas.duplicate()
	ok(c.progresso.bau_picks == 2 and cand.size() == 3, "o baú de 2 melhorias abre com 3 cartas e 2 a pegar")
	ok(t._texto_escolha() == "Escolha uma carta (faltam 2)", "a legenda diz quantas faltam (%s)" % t._texto_escolha())
	passos(20)
	_toque(KEY_ENTER)
	ate(func(): return t.espera_escolha <= 0.0, 120)
	passos(60 * 3)
	ok(lim() < lim_bau - 2.5, "o limite do baú correu (%.2f)" % lim())
	_toque(KEY_1)
	ok(c.jogo == "escolha" and c.progresso.bau_picks == 1 and c.progresso.cartas.size() == 2, "pegou a primeira: sobram 2 cartas para 1 escolha")
	ok(c.baus.ultimas.size() == 1 and c.baus.ultimas[0].id == cand[0].id, "a primeira pega é a carta 1")
	ok(not t.roleta_ativa and t._titulo.text == "BAÚ!", "a segunda escolha não rola e segue sendo a do baú")
	ok(lim() == lim_bau, "o limite recomeça cheio (%.2f)" % lim())
	ok(not c.progresso.cartas.has(cand[0]), "a carta pega sai da tela")
	ate(func(): return t.espera_escolha <= 0.0, 120)
	passos(2)
	_toque(KEY_2)
	ok(
		c.jogo == "jogando" and c.baus.ultimas.size() == 2 and c.baus.ultimas[0].id != c.baus.ultimas[1].id,
		"a segunda pega fecha o baú com 2 cartas diferentes"
	)
	# 13d. o tempo acaba na primeira de duas: a mais rara das 3 e depois a mais rara das 2; o jogo volta
	zerar()
	abrir_bau(2)
	var antes_auto: int = ate(func(): return c.progresso.bau_picks == 1, 60 * 15)
	ok(antes_auto >= 60 * 13.2 - 4, "a primeira escolha automática só no fim dos 12 s (%d quadros)" % antes_auto)
	ok(c.jogo == "escolha" and c.progresso.cartas.size() == 2, "e a segunda fica esperando")
	ate(func(): return c.jogo != "escolha", 60 * 15)
	ok(c.jogo == "jogando" and c.baus.ultimas.size() == 2, "a segunda também sai sozinha")
	# 13e. Automático (botão) no baú também fica com a mais rara; "Pausar agora? Sim" perde o baú sem gastar nível
	zerar()
	abrir_bau(1)
	cand = c.progresso.cartas.duplicate()
	melhor = cand[0]
	for carta in cand:
		if int(carta.rar) > int(melhor.rar):
			melhor = carta
	passos(20)
	_toque(KEY_ENTER)
	ate(func(): return t.espera_escolha <= 0.0, 120)
	passos(2)
	t._automatico()
	ok(c.baus.ultimas.size() == 1 and c.baus.ultimas[0].id == melhor.id, "o botão Automático do baú pega a mais rara")
	zerar()
	abrir_bau(1)
	nivel0 = c.progresso.pendentes
	passos(15)
	_toque(KEY_ESCAPE)
	ok(t.conf_aberta, "ESC no baú abre o 'Pausar agora?'")
	_toque(KEY_LEFT)
	_toque(KEY_ENTER)
	ok(w.pausa.aberto and c.jogo == "jogando" and c.progresso.bau_picks == 0 and c.baus.ultimas.is_empty(), "Sim perde as cartas do baú")
	ok(c.progresso.pendentes == nivel0, "e não gasta nenhum nível pendente")
	# 13f. o que não tem escolha segue de graça com a roleta de revelação: número fixado no mapa (forcar)
	zerar()
	abrir_bau(1, 1)
	ok(c.jogo == "bau" and t.bau_aberto and c.baus.ultimas.size() == 1, "baú com número fixado (forcar) dá de graça com a roleta de revelação")
	c.baus.fechar()
	bau.n_pesos = pesos0
	zerar()
	subir_nivel()
	ok(c.progresso.bau_picks == 0 and t._btn_a.visible and t._titulo.text.begins_with("NÍVEL"), "a escolha de nível segue com o Automático")
	ok(t._limite_total == limite, "e com os 8 s")
	t._automatico()

	# 14. o enfeite dos rolos usa o sorteador PRÓPRIO: o randi() global (semeado pelo playtest) não anda
	zerar()
	var c3: Array = cs.sortear(3, 3)
	c.progresso.cartas = c3
	c.jogo = "escolha"
	c.pausado = true
	seed(4242)
	var sem_roleta: int = randi()
	seed(4242)
	t._rng_roleta.seed = 99
	t.mostrar_escolha(c3, 3)
	var ids_a: Array = []
	for i in 3:
		ids_a.append(t._rolo_seq[i].map(func(x): return "%s:%d" % [x.id, x.rar]))
	var com_roleta: int = randi()
	ok(sem_roleta == com_roleta, "montar os rolos não gasta nenhum sorteio do randi() global (%d e %d)" % [sem_roleta, com_roleta])
	t.esconder()
	t._rng_roleta.seed = 99
	t.mostrar_escolha(c3, 3)
	var ids_b: Array = []
	for i in 3:
		ids_b.append(t._rolo_seq[i].map(func(x): return "%s:%d" % [x.id, x.rar]))
	ok(ids_a == ids_b, "e os mesmos rolos saem da mesma semente da roleta")
	t.esconder()
	t._rng_roleta.seed = 100
	t.mostrar_escolha(c3, 3)
	var ids_c: Array = []
	for i in 3:
		ids_c.append(t._rolo_seq[i].map(func(x): return "%s:%d" % [x.id, x.rar]))
	ok(ids_a != ids_c, "e outra semente muda os rolos")
	ok(t._faces_roleta.size() == cs.disponiveis().size(), "a lista de faces tem as cartas disponíveis, montada uma vez (%d)" % t._faces_roleta.size())
	t.esconder()
	c.pausado = false
	c.jogo = "jogando"
	passos(60)
	ok(t._fila_icones.is_empty(), "os ícones das cartas foram carregados aos poucos enquanto se jogava")


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	zerar()
	var t = w.combate.telas
	mouse_pos = Vector2(900, 60)
	subir_nivel()
	var quadro := 0
	while true:
		await w.ap.foto(pasta.path_join("roleta_%02d.png" % quadro))
		quadro += 1
		if not t.roleta_ativa or quadro > 80:
			break
		passos(2)  # 1/30 s por quadro do GIF
	passos(45)
	var tam = await w.ap.foto(pasta.path_join("roleta_%02d.png" % quadro))
	print("FOTOS roleta %d quadros %s" % [quadro + 1, tam])
	# o baú com escolha de 12 s: logo depois de abrir (rolos) e com as cartas e a barra de tempo já correndo
	var pesos0: Array = w.combate.cartas.cfg.bau.n_pesos.duplicate()
	zerar()
	abrir_bau(1)
	passos(18)
	await w.ap.foto(pasta.path_join("bau_escolha_rolos.png"))
	passos(150)  # roleta (1,2 s) e trava (1 s) já passaram; a barra dos 12 s está gastando
	await w.ap.foto(pasta.path_join("bau_escolha.png"))
	print("FOTOS bau limite %.1f de %.1f s" % [t.limite_t, t._limite_total])
	w.combate.cartas.cfg.bau.n_pesos = pesos0


func _ready() -> void:
	_run()
