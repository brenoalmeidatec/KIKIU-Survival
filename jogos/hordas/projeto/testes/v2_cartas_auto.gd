extends "res://testes/isolamento_v2.gd"
# Teste da escolha AUTOMÁTICA das cartas da v2 (cartas.escolha_automatica, progresso.automatico, o botão do meio e as teclas Q / Y do controle).
# Confere: completa uma fusão a que falta uma peça; sobe um golpe que o herói já tem; cobre o que falta (golpe golpe_novo); a raridade sai rebaixada
# (nunca passa de rara e sai mais comum que no sorteio normal); aplica a carta de verdade e fecha a escolha; o botão,
# o Q e o Y do controle chamam o automático; a trava descarta; o botão fica no meio da tela (e não há Rerrolar nem Banir).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_cartas_auto.tscn  (imprime "v2_cartas_auto falhas=0")
# Fotos: godot --path jogos/hordas/projeto res://testes/v2_cartas_auto.tscn -- --fotos=PASTA  (grava a tela de escolha e sai)
const Mundo := preload("res://v2/mundo.tscn")
const Mapas := preload("res://v2/mapas.gd")
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
	w.id_mapa = str(Mapas.LISTA[Mapas.LISTA.size() - 1].id)  # CAR-5: o último mapa dá a cota de 5/5 (a Floresta não deixa nenhum bônus passar do nível 4)
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

	# 1. fusão: a peça A já no nível pedido; a mão traz a B (um degrau abaixo) e um stat golpe_novo: o automático fecha a fusão
	dar(a, int(ev.pecas[0].nivel))
	dar(b, int(ev.pecas[1].nivel) - 1)
	var mao1: Array = [cs.montar_carta(cs.definicao(b), 0), cs.montar_carta(cs.definicao("dano"), 0)]
	var c: Dictionary = cs.escolha_automatica(mao1)
	ok(str(c.get("id", "")) == b, "completa a fusão: a carta é a peça que falta (%s, esperava %s)" % [c.get("id", ""), b])

	# 2. a raridade vem rebaixada: nunca passa de rara, e cai um degrau a partir da carta da mão
	zerar()
	var mao2: Array = [cs.montar_carta(cs.definicao("dano"), 3), cs.montar_carta(cs.definicao("vida"), 3)]
	var maior := 0
	var caiu := true
	for i in 30:
		var c2: Dictionary = cs.escolha_automatica(mao2)
		maior = maxi(maior, int(c2.get("rar", 0)))
		caiu = caiu and int(c2.get("rar", 0)) == 1
	ok(maior <= 1 and caiu, "o automático cai para rara (1) e nunca passa disso (maior %d)" % maior)
	ok(int(cs.escolha_automatica([cs.montar_carta(cs.definicao("dano"), 0)]).get("rar", -1)) == 0, "comum não cai abaixo de comum")

	# 3. com 3 golpes na mão, sobe um que já tem (a novidade de stat fica atrás)
	zerar()
	var tem: Array = []
	for d in cs.cfg.golpes:
		if tem.size() < 3 and cs.fusao_de(str(d.id)) == "" and (d.get("herois", [w.combate.heroi_id]) as Array).has(w.combate.heroi_id):
			tem.append(str(d.id))
	ok(tem.size() == 3, "existem 3 golpes sem fusão para o teste")
	var mao3: Array = []
	for id in tem:
		dar(str(id), 1)
		mao3.append(cs.montar_carta(cs.definicao(str(id)), 0))
	mao3.append(cs.montar_carta(cs.definicao("dano"), 0))
	var ups := 0
	for i in 30:
		if tem.has(str(cs.escolha_automatica(mao3).get("id", ""))):
			ups += 1
	ok(ups >= 27, "com 3 golpes na mão, o automático sobe um que já tem (%d de 30)" % ups)

	# 4. sem golpe nenhum, a novidade de golpe ganha de stat golpe_novo
	zerar()
	var gol := ""
	for d in cs.cfg.golpes:
		if gol == "" and cs._disponivel(d) and (d.get("herois", [w.combate.heroi_id]) as Array).has(w.combate.heroi_id):
			gol = str(d.id)
	var mao4: Array = [cs.montar_carta(cs.definicao(gol), 0), cs.montar_carta(cs.definicao("dano"), 0), cs.montar_carta(cs.definicao("vida"), 0)]
	var golpes := 0
	for i in 20:
		if str(cs._cat.get(str(cs.escolha_automatica(mao4).get("id", "")), "")) == "golpe":
			golpes += 1
	ok(golpes >= 15, "sem golpe nenhum, o automático traz golpe golpe_novo (%d de 20)" % golpes)

	# 4b. CAR-3: lâminas nv 4, aura nv 1 e corvos nv 2 na mão: escolhe a aura em 27 de 30; a lâmina nv 4 não vai ao nível 5
	zerar()
	dar("laminas", 4)
	dar("aura_fogo", 1)
	dar("corvos", 2)
	var mao4b: Array = [cs.montar_carta(cs.definicao("laminas"), 0), cs.montar_carta(cs.definicao("aura_fogo"), 0), cs.montar_carta(cs.definicao("corvos"), 0)]
	var aura := 0
	for i in 30:
		if str(cs.escolha_automatica(mao4b).get("id", "")) == "aura_fogo":
			aura += 1
	ok(aura >= 27, "lâminas nv 4, aura nv 1, corvos nv 2: escolhe a aura em %d de 30" % aura)
	ok(cs.escolha_automatica([cs.montar_carta(cs.definicao("laminas"), 0)]).is_empty(), "lâminas nv 4 sozinha na mão: nada (não vai ao nível 5)")

	# 4c. CAR-3: fusão que fecha ainda vence (aura nv 2 fecha o Anel de Brasas com lâminas nv 3; corvos nv 1 não fecha nada)
	zerar()
	dar("laminas", 3)
	dar("aura_fogo", 2)
	dar("corvos", 1)
	var mao4c: Array = [cs.montar_carta(cs.definicao("aura_fogo"), 0), cs.montar_carta(cs.definicao("corvos"), 0)]
	var fecha := 0
	for i in 30:
		if str(cs.escolha_automatica(mao4c).get("id", "")) == "aura_fogo":
			fecha += 1
	ok(fecha == 30, "a fusão que fecha vence o nível baixo (aura fecha: %d de 30)" % fecha)

	# 4d. novidade de golpe só com menos de 3 golpes ativos: com 3 golpes ativos, o golpe golpe_novo da mão fica de fora
	zerar()
	var ativos: Array = []
	for d in cs.cfg.golpes:
		if ativos.size() < 3 and cs.fusao_de(str(d.id)) == "" and (d.get("herois", [w.combate.heroi_id]) as Array).has(w.combate.heroi_id):
			ativos.append(str(d.id))
	for id in ativos:
		dar(id, 2)
	var golpe_novo := ""
	for d in cs.cfg.golpes:
		if golpe_novo == "" and not ativos.has(str(d.id)) and cs._disponivel(d) and (d.get("herois", [w.combate.heroi_id]) as Array).has(w.combate.heroi_id):
			golpe_novo = str(d.id)
	var mao4d: Array = [cs.montar_carta(cs.definicao(golpe_novo), 0), cs.montar_carta(cs.definicao("dano"), 0)]
	var nov_fora := true
	for i in 30:
		if str(cs.escolha_automatica(mao4d).get("id", "")) == golpe_novo:
			nov_fora = false
	ok(nov_fora, "com 3 golpes ativos, o golpe golpe_novo da mão não é escolhido sozinho")

	# 4e. novidade de golpe não entra com um golpe ativo abaixo do nível 2 (lá o nível 1 sobe antes)
	zerar()
	dar(ativos[0], 1)
	var nov_1 := true
	for i in 30:
		if str(cs.escolha_automatica([cs.montar_carta(cs.definicao(golpe_novo), 0), cs.montar_carta(cs.definicao("dano"), 0)]).get("id", "")) == golpe_novo:
			nov_1 = false
	ok(nov_1, "golpe ativo no nível 1: a novidade de golpe fica de fora do automático")

	# 4f. a cura da mão (sem definição) nunca é escolhida
	zerar()
	var cura := {"id": "cura", "rar": 0, "cat": "stat", "stat": "cura"}
	ok(str(cs.escolha_automatica([cura, cs.montar_carta(cs.definicao("dano"), 0)]).get("id", "")) == "dano", "a cura da mão fica de fora do automático")

	# 5. na tela: aplica a carta e fecha a escolha
	zerar()
	subir_nivel()
	ok(w.combate.jogo == "escolha", "o nível abre a escolha")
	var t = w.combate.telas
	var esc0: int = w.combate.progresso.escolhidas
	w._input(_tecla(KEY_Q))
	ok(w.combate.jogo == "jogando" and w.combate.progresso.escolhidas == esc0 + 1, "Q escolhe sozinho e fecha a escolha")

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
	w._input(y)
	ok(w.combate.jogo == "escolha", "na trava o Y do controle também não escolhe")
	t.espera_escolha = 0.0
	w.combate.progresso.escolher(0)

	# 8. o botão fica no meio da tela, e Rerrolar e Banir não existem mais
	var cx: float = t._btn_a.position.x + t._btn_a.size.x * 0.5
	ok(absf(cx - 480.0) < 0.5, "o botão Automático está no centro da tela (%.1f)" % cx)
	ok(t._btn_a.position.x >= 0.0 and t._btn_a.position.x + t._btn_a.size.x <= 960.0, "o botão cabe na tela")
	ok(t.get("_btn_r") == null and t.get("_btn_b") == null, "não há botão de Rerrolar nem de Banir")
	# O texto deve continuar dentro do botão, depois da coluna reservada ao glifo.
	for d in 3:
		Glifos.definir(d)
		for botao in [t._btn_a]:
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

	# 9. sem carta disponível na mão, o automático devolve vazio
	zerar()
	var mao9: Array = [cs.montar_carta(cs.definicao("dano"), 0)]
	for id in cs._def:
		cs.estado[id] = {"n": 0, "usada": true}
	ok(cs.escolha_automatica(mao9).is_empty(), "sem carta disponível o automático devolve vazio")

	# 10. CAR-1: todo bônus tem nível máximo 5; o valor x 5 bate (até 5%) com o total que o máximo antigo dava; os stats guardam a soma aplicada
	zerar()
	var total_antigo := {
		"dano": 120.0,
		"vel_ataque": 72.0,
		"area": 72.0,
		"vel_mov": 48.0,
		"vida": 160.0,
		"ima": 175.0,
		"critico": 40.0,
		"onda": 160.0,
		"fura": 180.0,
		"explode": 150.0,
		"folego": 48.0,
		"abalo": 180.0,
		"muralha": 100.0,
		"chuva": 60.0,
		"mira": 60.0,
		"sifao": 60.0,
		"ampla": 50.0,
		"cabo": 75.0,
		"rb_dano": 90.0,
		"rb_recarga": 24.0,
		"rb_estrondo": 60.0,
		"rb_contra": 24.0,
		"rb_eco": 50.0
	}
	var n_bonus := 0
	for id in cs._def:
		var d: Dictionary = cs._def[id]
		ok(int(d.max) == 5, "%s tem nível máximo 5 (tem %d)" % [id, int(d.max)])
		if cs._cat[id] == "golpe":
			continue
		n_bonus += 1
		ok(total_antigo.has(id), "%s está na tabela dos totais antigos" % id)
		if total_antigo.has(id):
			var novo := float(d.valor) * 5.0
			ok(
				absf(novo - float(total_antigo[id])) <= float(total_antigo[id]) * 0.05,
				"%s: valor x 5 = %.0f perto do total antigo %.0f" % [id, novo, total_antigo[id]]
			)
	ok(n_bonus == total_antigo.size(), "a tabela cobre todos os stats, modificadores e cartas da ruptura (%d de %d)" % [n_bonus, total_antigo.size()])
	ok(cs.cfg.evolucoes.size() == 27, "as 27 fusões seguem nos dados")
	for ev2 in cs.cfg.evolucoes:
		for p in ev2.pecas:
			ok(int(p.nivel) >= 1 and int(p.nivel) <= 5, "fusão %s: peça %s pede nível %d (de 1 a 5)" % [ev2.id, p.id, int(p.nivel)])
	var h = w.heroi
	var dano0: float = h.m_dano
	var vida0: float = h.vida_max
	for k in 5:
		ok(cs._disponivel(cs.definicao("dano")), "dano ainda sai antes do nível %d" % (k + 1))
		cs.aplicar(cs.montar_carta(cs.definicao("dano"), 0))
		cs.aplicar(cs.montar_carta(cs.definicao("vida"), 0))
	ok(cs.nivel_de("dano") == 5 and not cs._disponivel(cs.definicao("dano")), "o dano para de sair no nível 5")
	# o 5/5 é o ÁPICE (CAR-5): a soma das 5 cartas vezes 1,5 (a soma guardada é a aplicada, a troca no Difícil desfaz por ela)
	ok(is_equal_approx(float(cs.estado.dano.soma), 120.0 * 1.5), "o stat guarda a soma aplicada (dano: %.1f)" % float(cs.estado.dano.soma))
	ok(is_equal_approx(h.m_dano - dano0, 1.2 * 1.5), "5 cartas de dano somam +120%% x 1,5 do ÁPICE (%.2f)" % (h.m_dano - dano0))
	ok(
		is_equal_approx(float(cs.estado.vida.soma), 160.0 * 1.5) and is_equal_approx(h.vida_max - vida0, 160.0 * 1.5),
		"5 cartas de vida somam +160 x 1,5 do ÁPICE (%.0f)" % (h.vida_max - vida0)
	)
	cs.aplicar(cs.montar_carta(cs.definicao("critico"), 3))
	ok(
		is_equal_approx(float(cs.estado.critico.soma), 8.0 * 3.2),
		"a soma guarda o valor com a raridade (crítico lendário: %.1f)" % float(cs.estado.critico.soma)
	)


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
