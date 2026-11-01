extends "res://testes/isolamento_v2.gd"
# Teste do LIMITE DE TEMPO da escolha de cartas da v2 e do ESC na escolha (dados/v2_cartas.json: escolha.limite_s = 8 s, limite_urgente_s = 3 s).
# Confere: o limite abre cheio e só corre depois da trava de 1 s (que continua valendo: nada escolhe nela); a barra e a contagem na legenda andam e
# ficam vermelhas nos últimos 3 s; ao zerar o sistema escolhe pela MESMA regra do botão Automático (progresso.automatico) e o HUD avisa
# "Escolhida automaticamente"; limite_s = 0 desliga. O ESC (e o Start do controle) na escolha NÃO pausa: abre
# "Pausar agora? Você perde estas cartas" com "Não" marcado; com ela aberta a trava e o limite ficam parados, as cartas não reagem; Não (ESC, B, Enter,
# N, clique) volta com o tempo que restava; Sim (só por escolha explícita: seta até Sim e Enter, A, clique; S e as outras teclas de andar NUNCA confirmam) descarta a rodada (nenhuma carta, sem reembolso, nível pendente
# consumido) e abre a pausa normal. O baú segue pausando direto. A entrada vai pela JANELA (Input.parse_input_event), a rota do jogador de verdade.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_cartas_limite.tscn  (imprime "v2_cartas_limite falhas=0")
# Fotos: godot --path jogos/hordas/projeto res://testes/v2_cartas_limite.tscn -- --fotos=PASTA  (barra do limite e confirmação; grava e sai)
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


func _toque(k: Key) -> void:  # aperta e solta pela janela
	Input.parse_input_event(_tecla(k))
	Input.parse_input_event(_tecla(k, false))


func _start() -> void:
	for p in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_START
		e.pressed = p
		Input.parse_input_event(e)


func _select() -> void:  # o Select do controle (abre/fecha o painel central da build)
	for p in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_BACK
		e.pressed = p
		Input.parse_input_event(e)


func _acao(nome: String) -> void:
	var e := InputEventAction.new()
	e.action = nome
	e.pressed = true
	Input.parse_input_event(e)


func _clique(pos: Vector2) -> void:
	mouse_pos = pos
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	Input.parse_input_event(e)
	var s := InputEventMouseButton.new()
	s.button_index = MOUSE_BUTTON_LEFT
	s.pressed = false
	s.position = pos
	Input.parse_input_event(s)


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
	w.combate.telas.espera_escolha = 0.0
	w.combate.telas.espera_bau = 0.0
	passos(3)


## Sobe de nível de verdade e espera a escolha abrir (a trava de 1 s fica valendo).
func subir_nivel() -> void:
	var h = w.heroi
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	ate(func(): return w.combate.jogo == "escolha", 120)


func liberar() -> void:  # acaba a trava de 1 s (o limite parte cheio)
	var t = w.combate.telas
	ate(func(): return t.espera_escolha <= 0.0, 120)
	passos(2)


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
	print("v2_cartas_limite falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _testes() -> void:
	var c = w.combate
	var t = c.telas
	var cs = c.cartas
	var limite := float(cs.cfg.escolha.limite_s)
	ok(limite == 8.0, "o limite vem dos dados e vale 8 s (%.1f)" % limite)

	# 1. a escolha abre com o limite cheio, parado durante a trava de 1 s, e a trava continua valendo
	zerar()
	t.espera_escolha = 0.0
	subir_nivel()
	ok(c.jogo == "escolha" and t.escolha_aberta, "o nível abre a escolha")
	ok(absf(t.espera_escolha - 1.0) < 0.05, "a trava de 1 s continua (%.3f)" % t.espera_escolha)
	ok(lim() == limite, "o limite abre cheio (%.2f)" % lim())
	ok(t._limite_fundo.visible, "a barra do limite aparece")
	passos(30)
	ok(lim() == limite, "o limite não corre durante a trava")
	var esc0: int = c.progresso.escolhidas
	_toque(KEY_1)
	ok(c.progresso.escolhidas == esc0 and c.jogo == "escolha", "na trava a tecla 1 continua não escolhendo")

	# 2. depois da trava o limite corre em tempo real, com a barra e a contagem
	liberar()
	var l0 := lim()
	ok(l0 <= limite and l0 > limite - 0.2, "ao liberar, o limite parte do cheio (%.2f)" % l0)
	passos(60)  # 1 s
	ok(absf(lim() - (l0 - 1.0)) < 0.03, "1 s depois faltam %.2f s (%.2f)" % [l0 - 1.0, lim()])
	ok(t._sub.text == "Escolha uma carta  ·  automático em %d s" % ceili(lim()), "a legenda marca a contagem (%s)" % t._sub.text)
	passos(1)
	ok(absf(t._limite_barra.size.x - t._limite_fundo.size.x * lim() / limite) < 0.5, "a barra acompanha a fração que resta")
	ok(t._limite_barra.color == Color("#ffdb6b"), "barra de ouro enquanto sobra tempo")
	passos(60 * 4)  # chega a ~3 s
	ok(lim() < 3.0 and t._limite_barra.color == Color("#ff544d"), "nos últimos 3 s a barra fica vermelha (%.2f)" % lim())
	ok(c.jogo == "escolha", "ainda aberta com %.2f s" % lim())

	# 3. ao zerar, o sistema escolhe pela MESMA regra do Automático e avisa
	zerar()
	subir_nivel()
	liberar()
	cs.rng.seed = 4242
	var esperada: Dictionary = cs.escolha_automatica(c.progresso.cartas)
	ok(not esperada.is_empty(), "o automático tem uma carta")
	var id: String = esperada.id
	var nv_antes: int = cs.nivel_de(id)
	var anuncios0: int = c.anuncios
	cs.rng.seed = 4242
	esc0 = c.progresso.escolhidas
	var gasto: int = ate(func(): return c.jogo != "escolha", 60 * 9)
	ok(gasto > 60 * 6, "a escolha dura ~8 s e depois fecha sozinha (passos %d)" % gasto)
	ok(c.jogo == "jogando" and not t.escolha_aberta and not c.pausado, "o jogo volta a rodar")
	ok(c.progresso.escolhidas == esc0 + 1, "uma carta foi escolhida")
	ok(cs.nivel_de(id) == nv_antes + 1, "a carta é a do botão Automático (%s: %d -> %d)" % [id, nv_antes, cs.nivel_de(id)])
	ok(
		c.anuncios == anuncios0 + 1 and c.ultimo_anuncio == "Escolhida automaticamente: %s" % c.progresso.ultima_nome and c.progresso.ultima_nome != "",
		"o HUD avisa qual carta foi escolhida (%s)" % c.ultimo_anuncio
	)
	ok(c.progresso.ultima_nome == str(esperada.nome), "e é o nome da carta do Automático (%s)" % c.progresso.ultima_nome)
	ok(not t._limite_fundo.visible, "a barra some com a escolha")

	# 4. o botão Automático e a escolha à mão NÃO mostram o aviso
	zerar()
	subir_nivel()
	liberar()
	var ant: int = c.anuncios
	t._automatico()
	ok(c.jogo == "jogando" and c.anuncios == ant, "escolher à mão (Automático) não avisa")

	# 6. limite_s = 0 desliga o limite
	cs.cfg.escolha["limite_s"] = 0.0
	zerar()
	subir_nivel()
	liberar()
	ok(not t._limite_fundo.visible, "sem limite não há barra")
	passos(60 * 12)
	ok(c.jogo == "escolha", "sem limite a escolha espera o jogador para sempre")
	t._automatico()
	cs.cfg.escolha["limite_s"] = limite

	# 7. ESC na escolha: confirmação, não pausa; "Não" marcado; tempo parado; cartas quietas
	zerar()
	subir_nivel()
	liberar()
	passos(60 * 2)
	var resto := lim()
	var cartas_ids: Array = []
	for k in c.progresso.cartas:
		cartas_ids.append(k.id)
	esc0 = c.progresso.escolhidas
	_toque(KEY_ESCAPE)
	ok(t.conf_aberta and t._conf.visible, "ESC na escolha abre 'Pausar agora?'")
	ok(not w.pausa.aberto and not get_tree().paused, "e NÃO abre a pausa")
	ok(t.conf_sel == 1, "'Não' vem marcado")
	passos(60 * 5)
	ok(lim() == resto, "com a confirmação aberta o limite fica parado (%.3f contra %.3f)" % [lim(), resto])
	for k in [KEY_1, KEY_2, KEY_3, KEY_R, KEY_B, KEY_Q, KEY_X]:
		_toque(k)
	ok(t.conf_aberta and c.progresso.escolhidas == esc0 and c.jogo == "escolha", "nada escolheu com a confirmação aberta")
	_clique(Vector2(120, 300))  # um clique numa carta, fora dos botões da confirmação
	ok(t.conf_aberta and c.progresso.escolhidas == esc0, "o clique numa carta não escolhe")
	_acao("ui_accept")  # o A do controle com 'Não' marcado só fecha: nada escolhe
	ok(not t.conf_aberta and c.progresso.escolhidas == esc0 and c.jogo == "escolha", "o A / Enter com 'Não' marcado fecha a confirmação sem escolher")
	ok(lim() == resto, "voltou com o tempo que restava (%.3f)" % lim())
	var ids2: Array = []
	for k in c.progresso.cartas:
		ids2.append(k.id)
	ok(ids2 == cartas_ids, "as mesmas cartas")
	passos(60)
	ok(lim() < resto - 0.9, "e o tempo volta a correr (%.2f)" % lim())

	# 8. ESC de novo / B / N / Start / clique em Não = Não
	_toque(KEY_ESCAPE)
	_toque(KEY_ESCAPE)
	ok(not t.conf_aberta and not w.pausa.aberto, "ESC, ESC = abre e volta")
	_start()
	ok(t.conf_aberta and not w.pausa.aberto, "Start do controle também pede confirmação (não pausa)")
	_start()
	ok(not t.conf_aberta, "Start de novo = Não")
	_toque(KEY_ESCAPE)
	_acao("ui_cancel")  # B
	ok(not t.conf_aberta, "B = Não")
	_toque(KEY_ESCAPE)
	_toque(KEY_N)
	ok(not t.conf_aberta, "N = Não")
	_toque(KEY_ESCAPE)
	_clique(t._conf_btns[1].position + t._conf_btns[1].size * 0.5)
	ok(not t.conf_aberta and c.jogo == "escolha", "clique em Não = Não")
	_toque(KEY_ESCAPE)
	_toque(KEY_LEFT)
	ok(t.conf_sel == 0, "a seta troca para Sim")
	_toque(KEY_RIGHT)
	ok(t.conf_sel == 1, "e volta para Não")
	_acao("ui_left")
	ok(t.conf_sel == 0, "o direcional do controle troca para Sim")
	_toque(KEY_ESCAPE)
	ok(not t.conf_aberta and c.jogo == "escolha", "ESC com Sim marcado ainda é Não")

	# 9. Sim: perde a rodada (nenhuma carta), consome o nível e abre a pausa normal
	zerar()
	subir_nivel()
	liberar()
	esc0 = c.progresso.escolhidas
	var pend: int = c.progresso.pendentes
	var habil: Array = cs.resumo()
	_toque(KEY_ESCAPE)
	_toque(KEY_LEFT)
	_toque(KEY_ENTER)
	ok(not t.conf_aberta and not t.escolha_aberta, "Sim fecha a confirmação e a escolha")
	ok(w.pausa.aberto and get_tree().paused and w.pausa.tela == "menu", "e abre a pausa normal")
	ok(c.progresso.escolhidas == esc0 and cs.resumo() == habil, "nenhuma carta foi escolhida nem aplicada")
	ok(c.progresso.pendentes == pend - 1 and c.progresso.cartas.is_empty(), "o nível pendente foi consumido (a rodada se perdeu)")
	ok(c.jogo == "jogando" and not c.pausado, "o combate está em 'jogando' sob a pausa")
	_toque(KEY_ESCAPE)
	ok(not w.pausa.aberto and not get_tree().paused and c.jogo == "jogando", "ESC na pausa fecha e o jogo segue sem as cartas")
	passos(60 * 10)
	ok(c.jogo == "jogando" and not t.escolha_aberta, "e a escolha não reabre sozinha")

	# 10. Sim por Enter (com a seta), por clique e pelo A depois do direcional; ESC logo na trava também vale
	for modo in ["enter", "clique", "a"]:
		zerar()
		subir_nivel()
		_toque(KEY_ESCAPE)
		ok(t.conf_aberta and t.espera_escolha > 0.0, "(%s) ESC na trava abre a confirmação" % modo)
		var trava0: float = t.espera_escolha
		passos(30)
		ok(t.espera_escolha == trava0, "(%s) e a trava fica parada" % modo)
		match modo:
			"enter":
				_toque(KEY_LEFT)
				_toque(KEY_ENTER)
			"clique":
				_clique(t._conf_btns[0].position + t._conf_btns[0].size * 0.5)
			"a":
				_acao("ui_left")
				_acao("ui_accept")
		ok(w.pausa.aberto and not t.escolha_aberta and c.progresso.escolhidas == 0, "(%s) Sim perde a rodada e abre a pausa" % modo)
		w.pausa.fechar()

	# 11. vários níveis pendentes: Sim perde UMA rodada; a próxima abre depois
	zerar()
	c.progresso.pendentes = 2
	c.progresso.abrir_escolha()
	liberar()
	_toque(KEY_ESCAPE)
	_toque(KEY_LEFT)
	_toque(KEY_ENTER)
	ok(c.progresso.pendentes == 1 and c.lento_acao == "nivel", "com 2 níveis, Sim perde um e arma o seguinte")
	w.pausa.fechar()
	ate(func(): return c.jogo == "escolha", 120)
	ok(c.jogo == "escolha" and t.escolha_aberta and lim() == limite, "a rodada seguinte abre com o limite cheio")
	t._automatico()

	# 13. o painel central da build (C / Select) sobre as cartas PARA o limite (e a trava) e ele volta ao fechar
	zerar()
	subir_nivel()
	liberar()
	passos(60 * 2)
	var resto_c := lim()
	_toque(KEY_C)
	ok(w.status.central_aberto() and c.jogo == "escolha", "C na escolha abre o painel central")
	passos(60 * 9)
	ok(c.jogo == "escolha" and t.escolha_aberta and c.progresso.escolhidas == 0, "com o painel aberto 9 s a escolha NÃO fecha sozinha")
	ok(lim() == resto_c, "e o limite ficou parado (%.3f contra %.3f)" % [lim(), resto_c])
	_toque(KEY_C)
	ok(not w.status.central_aberto(), "C de novo fecha o painel")
	passos(60)
	ok(lim() < resto_c - 0.9 and lim() > resto_c - 1.2, "ao fechar o tempo volta a correr de onde parou (%.2f)" % lim())
	zerar()  # o Select do controle faz o mesmo, e na trava também
	subir_nivel()
	var trava_s: float = t.espera_escolha
	ok(trava_s > 0.0, "(Select) a trava está rodando")
	_select()
	ok(w.status.central_aberto(), "(Select) abre o painel central")
	passos(60)
	ok(t.espera_escolha == trava_s, "(Select) o painel também para a trava")
	_select()
	liberar()
	passos(60)
	var resto_s := lim()
	_select()
	passos(60 * 9)
	ok(c.jogo == "escolha" and lim() == resto_s, "(Select) com o painel aberto 9 s o limite fica parado")
	_select()
	t._automatico()

	# 14. a tecla S (andar para baixo no WASD) e as outras teclas de movimento NUNCA confirmam o Sim
	zerar()
	subir_nivel()
	liberar()
	esc0 = c.progresso.escolhidas
	_toque(KEY_ESCAPE)
	for k in [KEY_S, KEY_W, KEY_SHIFT, KEY_UP, KEY_DOWN]:
		_toque(k)
	ok(t.conf_aberta and not w.pausa.aberto and t.conf_sel == 1, "ESC e depois S, W, Shift, cima e baixo: a confirmação segue aberta em Não")
	ok(c.progresso.escolhidas == esc0 and c.jogo == "escolha" and c.progresso.cartas.size() > 0, "e a rodada de cartas não se perdeu")
	_toque(KEY_ESCAPE)
	ok(not t.conf_aberta and not w.pausa.aberto and c.jogo == "escolha", "ESC fecha a confirmação (Não) e as cartas seguem")
	t._automatico()

	# 15. com a confirmação aberta C e Select não fazem nada (nem painel por cima, nem tempo correndo escondido)
	zerar()
	subir_nivel()
	liberar()
	passos(60)
	var resto_k := lim()
	_toque(KEY_ESCAPE)
	_toque(KEY_C)
	ok(t.conf_aberta and not w.status.central_aberto(), "C com a confirmação aberta não abre o painel central")
	_select()
	ok(t.conf_aberta and not w.status.central_aberto(), "e o Select do controle também não")
	passos(60 * 9)
	ok(c.jogo == "escolha" and lim() == resto_k, "e o tempo segue parado (%.3f)" % lim())
	_toque(KEY_ESCAPE)
	ok(not t.conf_aberta and not w.status.central_aberto() and c.jogo == "escolha", "ESC volta às cartas, sem painel por cima")
	passos(60)
	ok(lim() < resto_k - 0.9, "e o limite volta a correr, à vista (%.2f)" % lim())
	t._automatico()

	# 12. o baú segue pausando direto no ESC (nada de confirmação: as cartas dele já foram dadas)
	zerar()
	c.jogo = "bau"
	c.pausado = true
	t.mostrar_bau(cs.sortear(2, 3))
	_toque(KEY_ESCAPE)
	ok(w.pausa.aberto and not t.conf_aberta, "ESC no baú abre a pausa direto")
	zerar()


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	zerar()
	var t = w.combate.telas
	mouse_pos = Vector2(900, 60)
	subir_nivel()
	t.espera_escolha = 0.0
	t._liberar_cartas()
	passos(60 * 4)  # sobram ~4 s: barra de ouro na metade
	var tam = await w.ap.foto(pasta.path_join("cartas_limite.png"))
	print("FOTO cartas_limite %s limite=%.2f" % [tam, t.limite_t])
	passos(60 * 2)  # ~2 s: barra vermelha
	tam = await w.ap.foto(pasta.path_join("cartas_limite_urgente.png"))
	print("FOTO cartas_limite_urgente %s limite=%.2f" % [tam, t.limite_t])
	t._abrir_conf()
	passos(2)
	tam = await w.ap.foto(pasta.path_join("cartas_confirma_pausa.png"))
	print("FOTO cartas_confirma_pausa %s" % tam)


func _ready() -> void:
	_run()
