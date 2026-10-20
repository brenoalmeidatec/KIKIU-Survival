extends Node
# Teste automático da Sentinela de Bambu (torreta, tipo "torre") e da fusão Pagode do Trovão (v2/armas_novas.gd, dados/v2_cartas.json):
#  - a carta existe com 5 níveis, ícone próprio de 32 e 16 px, e aparece na escolha de cartas;
#  - com inimigos por perto, depois da recarga existe 1 torre; ela atira virotes ("projetil") e machuca os monstros;
#  - a torre fica PARADA onde caiu: com o herói a 500 px dali ela continua atirando nos monstros perto dela;
#  - depois da duração a torre é liberada (some do pool); o pool não cresce nem cria nó; custo por quadro baixo;
#  - os 5 níveis mudam os números (dano, cadência, 2 torres no nível 4, virote que perfura no 5);
#  - a evolução Pagode do Trovão (sentinela 3 + raio 3) entra, consome as peças e o virote vira arco elétrico (acertos "raio").
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_sentinela.tscn  (imprime "v2_sentinela falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Novas := preload("res://v2/armas_novas.gd")
const Golem := preload("res://v2/golem.gd")
const Andante := preload("res://v2/andante.gd")
const PASSO := 1.0 / 60.0
const ID := "sentinela_bambu"
var falhas := 0
var w


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
	passos(3)


func monstro_a(dx: float, dy := 0.0):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, dy))
	m.vida_max = 100000.0
	m.vida = 100000.0
	m.atordoa_t = 0.0
	m.cacador = false
	m.raio_vaga = 0.0
	return m


func pegar(id: String, rar := 0) -> Dictionary:
	var cs = w.combate.cartas
	var c: Dictionary = cs.montar_carta(cs.definicao(id), rar)
	cs.aplicar(c)
	return c


func torres_vivas() -> Array:
	var r: Array = []
	for it in w.combate.armas.novas.itens:
		if str(it.k) == "torre" and float(it.vida) > 0.0:
			r.append(it)
	return r


func vida_perdida(ms: Array) -> float:
	var s := 0.0
	for m in ms:
		s += float(m.vida_max) - float(m.vida)
	return s


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var cs = w.combate.cartas
	var armas = w.combate.armas
	var novas = armas.novas
	for a in OS.get_cmdline_user_args():  # só as fotos (com janela): sem o resto do teste, para o HUD não cobrir o mundo
		if a.begins_with("--fotos="):
			await fotos(a.trim_prefix("--fotos="))
			get_tree().quit()
			return
		if a.begins_with("--fotos_aliados="):
			await fotos_aliados(a.trim_prefix("--fotos_aliados="))
			get_tree().quit()
			return

	# 0. dados, ícone e escolha de cartas
	var d: Dictionary = cs.definicao(ID)
	ok(not d.is_empty() and str(d.tipo) == "torre", "a carta %s existe e é do tipo torre" % ID)
	ok((d.niveis as Array).size() == 4 and int(d.max) == 5, "5 níveis (4 melhorias) e max 5")
	ok(str(d.nome) != "" and str(d.desc) != "" and str(d.get("curto", "")) != "", "nome, descrição e nome curto em português")
	ok(Dados.icone_carta(ID) != null and Dados.icone_carta(ID).get_size() == Vector2(32, 32), "ícone próprio de 32 px")
	ok(Dados.icone_carta(ID, "", true) != null and Dados.icone_carta(ID, "", true).get_size() == Vector2(16, 16), "ícone próprio de 16 px")
	ok(not cs.definicao("pagode_do_trovao").is_empty() or _evolucao("pagode_do_trovao"), "a fusão Pagode do Trovão está nos dados")
	ok(Dados.icone_carta("pagode_do_trovao") != null, "a fusão tem ícone próprio")
	var saiu := 0
	for i in 200:
		cs.rng.seed = 1000 + i
		for c in cs.sortear(3, 1 + i % 10):
			if str(c.id) == ID:
				saiu += 1
	ok(saiu > 0, "a Sentinela de Bambu aparece na escolha de cartas (%d em 200 sorteios)" % saiu)
	var carta: Dictionary = cs.montar_carta(d, 0)
	ok(str(carta.get("id", "")) == ID and str(carta.get("nome", "")) != "", "a carta monta com nome")

	# 0. brinde temporário: toda invocação e torre das cartas dura de 30 a 60 s (nada fica indefinidamente) e tem recarga depois que some
	var dj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/v2_cartas.json"))
	var temporarios := 0
	var lista: Array = (dj.golpes as Array) + (dj.evolucoes as Array)
	for g in lista:
		if str(g.get("tipo", "")) not in ["aliado", "torre"]:
			continue
		var b: Dictionary = g.get("base", g.get("arma", {}))
		temporarios += 1
		ok(float(b.duracao) >= 30.0 and float(b.duracao) <= 60.0, "%s: duração de 30 a 60 s (%s)" % [g.id, b.duracao])
		ok(float(b.recarga) >= 15.0, "%s: recarga de 15 s ou mais, contada depois que a leva some (%s)" % [g.id, b.recarga])
	ok(temporarios >= 16, "todas as invocações e torres foram conferidas (%d)" % temporarios)
	ok(
		Golem.topo({"a": {"id": "golem_barro"}}) > 0.0 and Golem.topo({"a": {"id": "colosso_de_pedra"}}) > Golem.topo({"a": {"id": "golem_barro"}}),
		"o colosso é mais alto que o golem: a barrinha sobe junto"
	)
	ok(
		Andante.raio_marca({"a": {"id": "?"}, "k": "?"}) >= 10.0,
		"o anel de amigo tem raio mínimo mesmo sem ficha (%s)" % Andante.raio_marca({"a": {"id": "?"}})
	)

	# 1. a torre cai depois da recarga, atira e machuca
	zerar()
	var ms: Array = [monstro_a(150, -30), monstro_a(150, 0), monstro_a(150, 30)]
	pegar(ID)
	ok(armas.tem(ID), "o golpe entra pela carta")
	ok(torres_vivas().is_empty(), "antes da recarga não há torre")
	var q := ate(func(): return torres_vivas().size() == 1, 200)
	ok(q >= 0, "depois da recarga existe exatamente 1 torre (%d torres)" % torres_vivas().size())
	var torre: Dictionary = torres_vivas()[0] if not torres_vivas().is_empty() else {}
	var pos0: Vector2 = torre.p if not torre.is_empty() else Vector2.ZERO
	ok(
		(torre.p as Vector2).distance_to(w.heroi.pos) > 20.0,
		"a torre cai atrás do herói, não em cima dele (%.0f px)" % (torre.p as Vector2).distance_to(w.heroi.pos)
	)
	passos(180)
	ok(int(armas.acertos.get("projetil", 0)) > 0, "em 3 s os virotes acertaram (acertos %d)" % int(armas.acertos.get("projetil", 0)))
	ok(vida_perdida(ms) > 0.0, "os monstros perderam vida (%.0f)" % vida_perdida(ms))
	ok(int(torre.est) == 1, "a torre armou (fase %d)" % int(torre.est))
	ok(float(armas.ativas[ID].get("ate", 0.0)) - float(armas.novas._relogio) > 20.0, "a recarga fica parada enquanto a torre está de pé")

	# 2. a torre não anda com o herói e continua atirando mesmo com ele longe
	var acertos_antes := int(armas.acertos.get("projetil", 0))
	var vida_antes := vida_perdida(ms)
	w.heroi.pos += Vector2(500, 0)
	passos(90)
	ok((torre.p as Vector2).is_equal_approx(pos0), "a torre fica parada quando o herói anda 500 px")
	ok(
		int(armas.acertos.get("projetil", 0)) > acertos_antes and vida_perdida(ms) > vida_antes,
		"a torre continua acertando com o herói a 500 px (acertos %d -> %d)" % [acertos_antes, int(armas.acertos.get("projetil", 0))]
	)

	# 3. depois da duração a torre é liberada; o pool e a camada de desenho não crescem
	w.heroi.pos -= Vector2(500, 0)
	var q2 := ate(func(): return torres_vivas().is_empty(), 2400)
	ok(q2 >= 0, "depois da duração a torre sai do pool (ainda vivas: %d)" % torres_vivas().size())
	ok(novas.itens.size() == Novas.MAX, "o pool continua com %d slots" % Novas.MAX)
	ok(armas.no_brilho.get_child_count() == 0 and armas.no_corpo.get_child_count() == 0, "nenhum nó novo nas camadas de desenho")

	# 4. os 5 níveis
	var st1: Dictionary = armas.ativas[ID].st
	var dano1 := float(st1.dano)
	ok(int(st1.quantidade) == 1 and float(st1.tique) > 0.5, "nível 1: 1 torre, cadência 0,55 s")
	pegar(ID)
	var st2: Dictionary = armas.ativas[ID].st
	ok(float(st2.dano) == dano1 + 3.0, "nível 2: +3 de dano (%.0f -> %.0f)" % [dano1, float(st2.dano)])
	pegar(ID)
	var st3: Dictionary = armas.ativas[ID].st
	ok(float(st3.tique) < float(st2.tique) and float(st3.duracao) > float(st2.duracao), "nível 3: atira mais rápido e dura mais")
	pegar(ID)
	ok(int(armas.ativas[ID].st.quantidade) == 2, "nível 4: 2 torres")
	armas.ativas[ID].t = 0.0
	armas.ativas[ID].ate = 0.0
	var q4 := ate(func(): return torres_vivas().size() == 2, 120)
	ok(q4 >= 0, "no nível 4 caem 2 torres (%d)" % torres_vivas().size())
	pegar(ID)
	var st5: Dictionary = armas.ativas[ID].st
	ok(int(st5.perfura) == 1 and float(st5.alcance) > float(st1.alcance), "nível 5: o virote perfura e o alcance sobe")
	ok(not armas.numeros(armas.ativas[ID]).is_empty() and float(armas.numeros(armas.ativas[ID]).dps) > 0.0, "o card de status tem um dano por segundo")

	# 5. custo por quadro: o passo do pool com 2 torres e virotes no ar
	armas.ativas[ID].t = 0.0
	passos(40)
	var t0 := Time.get_ticks_usec()
	var n := 300
	var perto: Array = armas._perto
	for i in n:
		novas.quadro(w.heroi, PASSO, perto)
	var media := float(Time.get_ticks_usec() - t0) / float(n)
	ok(media < 1500.0, "o passo do pool custa %.0f us por quadro com torres ativas (limite 1500)" % media)

	# 6. a fusão: sentinela 3 + raio 3 = Pagode do Trovão (virote em arco elétrico)
	zerar()
	ms = [monstro_a(150, -30), monstro_a(150, 0), monstro_a(150, 30)]
	for i in 3:
		pegar(ID)
		pegar("raio")
	ok(cs.evoluidas.has("pagode_do_trovao"), "sentinela 3 + raio 3 evoluem para o Pagode do Trovão")
	ok(armas.tem("pagode_do_trovao") and not armas.tem(ID) and not armas.tem("raio"), "o Pagode entra e consome as duas peças")
	armas.acertos.clear()
	var q6 := ate(func(): return int(armas.acertos.get("raio", 0)) > 0, 600)
	ok(
		q6 >= 0,
		"o virote do Pagode solta arco elétrico (acertos raio %d, projétil %d)" % [int(armas.acertos.get("raio", 0)), int(armas.acertos.get("projetil", 0))]
	)
	var viu_torre := false
	for it in novas.itens:
		if str(it.k) == "torre" and float(it.vida) > 0.0 and str(it.a.id) == "pagode_do_trovao":
			viu_torre = true
	ok(viu_torre, "a torre do Pagode está de pé")

	print("custo do passo do pool com torres: %.0f us/quadro; acertos %s" % [media, armas.acertos])
	print("v2_sentinela falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


## Fotos (com janela e `-- --fotos=PASTA`): a torre atirando e o Pagode do Trovão com o arco elétrico saltando entre os monstros.
func fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	Config.g_aplicar_perfil("alto")
	Config.temporario("pausar_fora", false)  # a janela sem foco não pode pausar a partida durante o print
	var armas = w.combate.armas
	zerar()
	monstro_a(140, -50)
	monstro_a(150, -10)
	monstro_a(165, 28)
	monstro_a(190, 60)
	monstro_a(120, 40)
	for i in 3:
		pegar(ID)
	await _foto_quando(func(): return _torre_aux() > 0.75 and int(armas.acertos.get("projetil", 0)) > 2, 900, pasta.path_join("v2_sentinela_atirando.png"))  # o clarão da boca
	zerar()  # os alvos ficam parados (atordoados) a ~210 px da torre, para o virote voar por um bom pedaço antes de acertar
	for dy in [-24.0, 6.0, 34.0]:
		monstro_a(172.0, dy).atordoa_t = 60.0
	for i in 3:
		pegar(ID)
	await _foto_quando(func(): return _bolt_no_ar() and _torre_aux() < 0.55, 900, pasta.path_join("v2_sentinela_virote.png"), 3)  # o virote com o rastro
	zerar()  # a torre recém-pousada: a poeira, as lascas e a onda (a arma só dispara com algum monstro por perto)
	monstro_a(250.0, 0.0).atordoa_t = 60.0
	pegar(ID)
	await _foto_quando(func(): return _torre_pousou(), 900, pasta.path_join("v2_sentinela_pouso.png"), 5)
	zerar()  # os monstros em fila, parados e a 45 px um do outro: o arco do Pagode salta de um para o outro (cadeia 2 = 3 monstros)
	monstro_a(150, -50).atordoa_t = 60.0
	monstro_a(175, -12).atordoa_t = 60.0
	monstro_a(200, 26).atordoa_t = 60.0
	monstro_a(228, 62).atordoa_t = 60.0
	for i in 3:
		pegar(ID)
		pegar("raio")
	await get_tree().create_timer(5.0).timeout  # o aviso da fusão sai da tela (relógio de parede)
	passos(30)
	var antes := int(armas.acertos.get("raio", 0))
	await _foto_quando(func(): return int(armas.acertos.get("raio", 0)) > antes, 900, pasta.path_join("v2_pagode_trovao.png"), 1)


## Foto (com janela) da marca de amigo: anel verde no chão e barrinha verde de tempo sobre a cabeça, em aliado andante, golem e torre.
func fotos_aliados(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	Config.g_aplicar_perfil("alto")
	Config.temporario("pausar_fora", false)
	zerar()
	monstro_a(260, -60).atordoa_t = 60.0
	for id in ["lobo_espirito", "golem_barro", "espirito_urso", ID]:
		pegar(id)
	passos(150)
	await _foto_quando(func(): return true, 1, pasta.path_join("v2_aliados_marca.png"), 0)
	passos(1500)  # ~25 s: a barrinha já está pela metade e o lobo (35 s) perto de sumir
	await _foto_quando(func(): return true, 1, pasta.path_join("v2_aliados_marca_meio.png"), 0)


func _torre_pousou() -> bool:
	for it in torres_vivas():
		if int(it.est) == 1 and float(it.age) < 0.3:
			return true
	return false


func _torre_aux() -> float:
	var m := 0.0
	for it in torres_vivas():
		m = maxf(m, float(it.aux))
	return m


func _bolt_no_ar() -> bool:
	for it in w.combate.armas.novas.itens:
		if str(it.k) == "projetil" and float(it.vida) > 0.0 and float(it.vida) < 0.9:
			return true
	return false


func _foto_quando(cond: Callable, max_passos: int, arquivo: String, extra := 0) -> void:
	var q := ate(cond, max_passos)
	passos(extra)
	await RenderingServer.frame_post_draw
	var img: Image = w.sv.get_texture().get_image()
	img.save_png(arquivo)
	print("FOTO ", arquivo, " ", img.get_size(), " depois de ", q, " quadros")


func _evolucao(id: String) -> bool:
	for ev in w.combate.cartas.cfg.evolucoes:
		if str(ev.id) == id:
			return true
	return false
