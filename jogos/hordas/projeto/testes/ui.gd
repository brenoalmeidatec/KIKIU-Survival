extends Node
# Teste automático da UI/UX (#7): pular/banir gastam cargas e o banido não volta; números de dano agrupam e somam certo;
# DPS por arma; comparação "antes > depois" das cartas; opções de acessibilidade salvam e voltam.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/ui.tscn  (imprime "UI falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Efeitos := preload("res://scripts/hordas/efeitos.gd")
const Interface := preload("res://scripts/hordas/interface.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func nova() -> Node:
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = true
	add_child(a)
	await esperar(0.2)
	a.xp = -1.0e12   # sem subir de nível: o robô escolheria carta e mudaria a build no meio do teste
	return a


func _ready() -> void:
	await _cartas()
	_numeros()
	await _dps()
	_comparacao()
	_opcoes()
	_mouse()
	await _mouse_cartas()
	print("UI falhas=", falhas)
	get_tree().quit()


func _cartas() -> void:
	var a := await nova()
	ok(a.resortear == 3 and a.pular == 2 and a.banir == 2, "cargas vêm de dados/corrida.json (%d/%d/%d)" % [a.resortear, a.pular, a.banir])
	# pular: gasta carga, devolve 1 sortear de novo, e para quando acaba
	ok(a.gastar_pular() and a.pular == 1 and a.resortear == 4, "pular 1: carga e devolve sortear (%d/%d)" % [a.pular, a.resortear])
	ok(a.gastar_pular() and a.pular == 0 and a.resortear == 5, "pular 2")
	ok(not a.gastar_pular() and a.pular == 0 and a.resortear == 5, "pular sem carga não gasta nada")
	# banir: só arma/passivo/equipamento; sem carga, erro; o banido nunca mais aparece
	var mesa: Array = a.sortear_cartas()
	var evo := {"tipo": "evolucao", "id": "x"}
	ok(a.gastar_banir(evo, mesa).has("erro") and a.banir == 2, "evolução não se bane e não gasta carga")
	var alvo: Dictionary = mesa[0]
	var r: Dictionary = a.gastar_banir(alvo, mesa)
	ok(a.banir == 1 and a.banidos.has(str(alvo.id)), "banir 1 gasta carga e registra (%d)" % a.banir)
	ok(r.is_empty() or (str(r.id) != str(alvo.id) and not a.banidos.has(str(r.id))), "carta de reposição não é a banida")
	var voltou := 0
	for i in 80:
		for c in a.sortear_cartas():
			if str(c.id) == str(alvo.id):
				voltou += 1
	ok(voltou == 0, "banida nunca volta ao sorteio (voltou %d vezes em 80 sorteios)" % voltou)
	var alvo2: Dictionary = {}
	for c in a.sortear_cartas():
		if a.carta_banivel(c):
			alvo2 = c
			break
	ok(not a.gastar_banir(alvo2, []).has("erro") and a.banir == 0, "banir 2 gasta a última carga")
	ok(a.gastar_banir(alvo2, []).has("erro") and a.banir == 0, "banir sem carga dá erro e não gasta")
	for i in 80:
		for c in a.sortear_cartas():
			ok(not a.banidos.has(str(c.id)), "nenhuma carta banida no sorteio (%s)" % c.id)
	# toda carta nova traz o antes > depois e o nível máximo
	var com: Array = a.sortear_cartas().filter(func(c): return c.has("cmp") and c.has("max"))
	ok(com.size() >= 3, "cartas trazem cmp e max")
	a.queue_free()
	await esperar(0.1)


func _numeros() -> void:
	var ef := Efeitos.new()
	Config.definir("numeros_dano", true)
	ef.numero(Vector2(0, 0), 10.0)
	ef.numero(Vector2(5, 3), 7.0)
	ef.numero(Vector2(-8, 0), 5.0)
	ok(ef.numeros.size() == 1 and is_equal_approx(ef.numeros[0].valor, 22.0) and ef.numeros[0].txt == "22", "3 acertos juntos viram 1 número de 22 (%d números, txt %s)" % [ef.numeros.size(), ef.numeros[0].txt])
	ef.numero(Vector2(200, 0), 4.0)
	ok(ef.numeros.size() == 2, "acerto longe não soma")
	ef.numero(Vector2(3, 0), 6.0, Color.WHITE, true)
	ok(ef.numeros.size() == 2 and ef.numeros[0].txt == "28!" and ef.numeros[0].tam == 16, "crítico se soma ao grupo e vira crítico (%s)" % ef.numeros[0].txt)
	ef.numero(Vector2(0, 0), 3.0, Color(1, 0.6, 0.55))
	ok(ef.numeros.size() == 3, "cor diferente (dano recebido) não soma com o de dano")
	ef.atualizar(0.2)   # a janela de 0,15 s fechou
	ef.numero(Vector2(0, 0), 10.0)
	ok(ef.numeros.size() == 4, "depois da janela nasce número novo (%d)" % ef.numeros.size())
	ef.limpar()
	var t0 := Time.get_ticks_usec()
	for i in 2000:   # 500 vírus apanhando 4x: o agrupamento mantém a lista curta e rápida
		ef.numero(Vector2(randf() * 300, randf() * 200), 3.0)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	ok(ef.numeros.size() <= Efeitos.MAX_NUMEROS and ms < 150.0, "2000 acertos: %d números, %.1f ms" % [ef.numeros.size(), ms])
	ef.free()


func _dps() -> void:
	# conta pura
	var t := Interface.tabela_armas({"pendrive": 600.0, "katana": 900.0}, {"pendrive": 3}, {"pendrive": 30.0, "katana": 0.2}, 100.0)
	ok(t.size() == 2 and t[0].id == "katana" and t[1].id == "pendrive", "ordena por dano")
	ok(is_equal_approx(t[1].dps, 20.0) and t[1].nivel == 3, "pendrive: 600 em 30 s = 20 de DPS, nível 3 (%s)" % t[1].dps)
	ok(is_equal_approx(t[0].dps, 900.0) and t[0].nivel == 1, "tempo mínimo de 1 s evita DPS absurdo (%s)" % t[0].dps)
	ok(t[0].top_dano and t[0].top_dps and not t[1].top_dano and not t[1].top_dps, "marca a melhor de dano e de DPS")
	var t2 := Interface.tabela_armas({"pendrive": 50.0}, {}, {}, 10.0)
	ok(is_equal_approx(t2[0].dps, 5.0), "sem tempo registrado usa o da corrida")
	ok(Interface.tabela_armas({}, {}, {}, 10.0).is_empty(), "sem dano nem armas: tabela vazia")
	ok(Interface.texto_dano(52000.0) == "52.0k" and Interface.texto_dano(999.0) == "999" and Interface.texto_tempo(642.0) == "10:42", "formatos")
	# na arena: o tempo e o dano por arma entram no resumo da corrida
	var a := await nova()
	var id := str(a.armas.lista[0].id)
	a.registrar_dano(id, 100.0, Vector2.ZERO)
	await esperar(1.0)
	var tm := float(a.tempo_arma.get(id, 0.0))
	ok(tm > 0.7 and tm < 1.6, "tempo com a arma conta (%.2f s)" % tm)
	var guarda := []   # lambda copia variáveis locais: o array é o jeito de devolver o resumo
	a.terminou.connect(func(r): guarda.append(r))
	a._fim(false)
	await esperar(1.5)
	var res: Dictionary = guarda[0] if not guarda.is_empty() else {}
	ok(res.has("armas") and not res.armas.is_empty(), "o resumo da corrida traz a tabela de armas")
	if res.has("armas") and not res.armas.is_empty():
		var l: Dictionary = res.armas[0]
		ok(l.id == id and is_equal_approx(l.dano, 100.0) and l.dps > 50.0 and l.dps < 150.0 and l.tempo > 0.7, "linha da arma: dano 100, DPS coerente (%s)" % l)
	a.queue_free()
	await esperar(0.1)


func _comparacao() -> void:
	var c := Interface.comparacao("arma", "pendrive", 2)
	ok(c.size() >= 1, "pendrive nível 2 tem antes > depois")
	var base: Dictionary = Dados.item("pendrive").base
	var delta: Dictionary = Dados.item("pendrive").niveis[0]
	for k in delta:
		var linha := c.filter(func(l): return l.rot == Interface._rot(str(k)))
		ok(linha.size() == 1 and linha[0].antes == Interface._num(float(base.get(k, 0))) and linha[0].depois == Interface._num(float(base.get(k, 0)) + float(delta[k])), "pendrive nv2 %s: antes/depois batem com o JSON" % k)
	var p := Interface.comparacao("passivo", "energetico", 2)
	ok(p.size() == 1 and p[0].antes == "+10%" and p[0].depois == "+20%" and p[0].bom, "energético nv2: +10%% > +20%% (%s)" % [p])
	var o := Interface.comparacao("passivo", "overclock", 1)
	ok(o.size() == 1 and o[0].antes == "" and o[0].depois == "-8%" and o[0].bom, "overclock: recarga menor é bom (%s)" % [o])
	var e := Interface.comparacao("equipamento", "cabeca_guerreiro", 1)
	ok(e.size() == 1 and e[0].depois == "+25", "equipamento mostra o bônus (%s)" % [e])
	ok(Interface.comparacao("evolucao", "x", 1).is_empty() and Interface.comparacao("arma", "inexistente", 2).is_empty(), "evolução e id desconhecido: sem linhas, sem erro")
	ok(Interface.comparacao("arma", "pendrive", 99).is_empty(), "nível além do máximo: sem linhas")


func _opcoes() -> void:
	var antes := {"texto_hud": Config.v("texto_hud"), "daltonico": Config.v("daltonico")}
	ok(Config.item("texto_hud").padrao == "normal" and Config.item("daltonico").padrao == false, "padrões das opções novas")
	Config.definir("texto_hud", "grande")
	Config.definir("daltonico", true)
	var cfg := ConfigFile.new()
	cfg.load(Config.ARQUIVO)
	ok(str(cfg.get_value("opcoes", "texto_hud", "")) == "grande" and bool(cfg.get_value("opcoes", "daltonico", false)), "opções novas salvas no arquivo")
	ok(Config.rotulo("texto_hud") == "Grande" and Config.rotulo("daltonico") == "Paleta segura", "rótulos")
	ok(Interface.tam_hud(8) == 12 and Interface.tam_hud(16) == 16, "texto grande: 8 vira 12, títulos ficam")
	ok(Interface.cor("arma") != Interface.PADRAO.arma and Interface.cor("arma") == Interface.SEGURA.arma, "daltônico troca a paleta")
	Config.girar("texto_hud", 1)
	ok(Config.v("texto_hud") == "normal", "girar volta pro normal")
	Config.definir("daltonico", false)
	ok(Interface.cor("arma") == Interface.PADRAO.arma and Interface.tam_hud(8) == 8, "voltou ao padrão")
	for k in antes:
		Config.definir(k, antes[k])


func _mouse() -> void:
	var rs := [Rect2(0, 0, 10, 10), Rect2(20, 0, 10, 10)]
	ok(Interface.quem(rs, Vector2(25, 5)) == 1 and Interface.quem(rs, Vector2(15, 5)) == -1 and Interface.quem(rs, Vector2(1, 1)) == 0, "hit-test do mouse")


## Mouse de verdade nas cartas: mover escolhe, clique pega, clique em "Pular" fecha sem pegar. (Eventos injetados no Input.)
func _mouse_cartas() -> void:
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = false
	add_child(a)
	await esperar(0.2)
	a.xp = -1.0e12
	var mesa: Array = a.sortear_cartas()
	var ct = a.cartas
	ct.escolher("Teste", mesa.duplicate())
	await esperar(0.7)
	ok(ct.aberto() and get_tree().paused, "cartas abertas e jogo pausado")
	var mov := InputEventMouseMotion.new()
	var alvo: Rect2 = ct._rect_carta(1)
	mov.position = _na_janela(alvo.get_center())
	mov.global_position = mov.position
	Input.parse_input_event(mov)
	await esperar(0.1)
	ok(ct._sel == 1, "passar o mouse na carta 2 escolhe ela (sel=%d)" % ct._sel)
	# clique no botão Pular: fecha sem pegar nada e gasta a carga
	var btns: Array = ct._botoes()
	var rp: Rect2 = ct._rect_botao(1, btns.size())
	var mv2 := InputEventMouseMotion.new()
	mv2.position = _na_janela(rp.get_center())
	mv2.global_position = mv2.position
	Input.parse_input_event(mv2)
	await esperar(0.1)
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	clique.position = _na_janela(rp.get_center())
	clique.global_position = clique.position
	Input.parse_input_event(clique)
	await esperar(0.1)
	ok(not ct.aberto() and a.pular == 1 and a.resortear == 4, "clicar em Pular fecha as cartas e gasta a carga (pular=%d)" % a.pular)
	var armas_antes: int = a.armas.lista.size()
	ct.escolher("Teste 2", mesa.duplicate())
	await esperar(0.7)
	var m3 := InputEventMouseMotion.new()
	m3.position = _na_janela(ct._rect_carta(0).get_center())
	m3.global_position = m3.position
	Input.parse_input_event(m3)
	await esperar(0.1)
	var c3 := InputEventMouseButton.new()
	c3.button_index = MOUSE_BUTTON_LEFT
	c3.pressed = true
	c3.position = m3.position
	c3.global_position = m3.position
	Input.parse_input_event(c3)
	await esperar(0.1)
	ok(not ct.aberto(), "clicar numa carta pega e fecha")
	ok(a.armas.lista.size() >= armas_antes and not get_tree().paused, "jogo despausa")
	a.queue_free()
	await esperar(0.1)


## O Input leva o evento do espaço da JANELA para o do jogo (640x360) desfazendo a escala; aqui vai o caminho inverso,
## senão o teste só acerta quando a janela (no headless fica 64x64) tem escala exata de 1x.
func _na_janela(p: Vector2) -> Vector2:
	return get_window().get_final_transform() * p
