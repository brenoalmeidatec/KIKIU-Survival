extends Node
# Teste da ROLETA das cartas de nível e do BAÚ melhor da v2 (#376; dados/v2_cartas.json: escolha.roleta_s = 1,2 s, bau.bonus_raridade, bau.piso_raridade).
# Roleta: ao abrir a escolha de nível as cartas descem em rolos e param uma a uma (esquerda -> direita) em no máximo 1,2 s de tempo real; clique, Enter,
# Espaço e A (ui_accept) pulam para o fim; nada escolhe durante os rolos; a trava de 1 s corre junto e o limite de 8 s só começa quando TODAS pararam;
# ESC durante a roleta abre o "Pausar agora?" (o tempo dela fica parado; Não volta, Sim descarta a rodada); rerrolar não rola; escolher no meio desfaz
# os rolos; roleta_s = 0 e roleta_ligada = false mostram as cartas direto. Baú: raridade melhor que a escolha comum (estatística com semente) e nunca comum.
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
			var rb: int = cs.sortear(1, nivel, float(bau.bonus_raridade), [], int(bau.piso_raridade))[0].rar
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
	for k in [KEY_2, KEY_R, KEY_Q, KEY_B, KEY_LEFT]:
		_toque(k)
	ok(c.progresso.escolhidas == esc0 and c.jogo == "escolha" and t.roleta_ativa, "teclas de escolha, rerrolar, automático e banir não fazem nada na roleta")

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

	# 5. pular: clique, Enter, Espaço, E, A (ui_accept), botão A do controle
	for modo in ["clique", "enter", "espaco", "ui_accept", "joy_a", "e"]:
		zerar()
		subir_nivel()
		passos(12)  # 0,2 s
		ok(t.roleta_ativa and t.espera_escolha > 0.5, "(%s) a roleta ainda gira com a trava correndo" % modo)
		esc0 = c.progresso.escolhidas
		match modo:
			"clique":
				_clique(Vector2(480, 300))
			"enter":
				_toque(KEY_ENTER)
			"espaco":
				_toque(KEY_SPACE)
			"ui_accept":
				_acao("ui_accept")
			"joy_a":
				_botao_joy(JOY_BUTTON_A)
			"e":
				_toque(KEY_E)
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

	# 10. rerrolar e banir não rolam
	zerar()
	subir_nivel()
	_toque(KEY_ENTER)
	ate(func(): return t.espera_escolha <= 0.0, 120)
	passos(2)
	ok(c.progresso.rerrolar(), "rerrolar depois da roleta")
	ok(not t.roleta_ativa and t._cartas[0].visible and t._cartas[2].visible, "rerrolar mostra as cartas direto, sem roleta")
	ate(func(): return t.espera_escolha <= 0.0, 120)
	passos(2)
	ok(c.progresso.banir(0), "banir")
	ok(not t.roleta_ativa, "banir também não rola")
	t._automatico()

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
	ok(t.REDUZIR_ANIMACAO == false, "a constante REDUZIR_ANIMACAO existe e vem desligada")

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


func _ready() -> void:
	_run()
