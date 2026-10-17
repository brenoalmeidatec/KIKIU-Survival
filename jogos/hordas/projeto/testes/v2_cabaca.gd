extends Node
# Teste automático da Cabaça de Pólvora (granada, tipo "granada") e da fusão Fogos de Festival (v2/armas_novas.gd, dados/v2_cartas.json):
#  - a carta existe com 5 níveis, ícone próprio de 32 e 16 px, e aparece na escolha de cartas;
#  - o arremesso vai para o maior GRUPO (5 monstros a 180 px), não para o monstro isolado mais perto (a 100 px);
#  - a cabaça voa em arco (altura > 0 no meio do caminho e 0 no fim), quica UMA vez e explode em voo + quique + pavio;
#  - os monstros no raio levam dano e a explosão solta N estilhaços ("projetil") que somem em até 0,4 s;
#  - nível 4: 2 cabaças; nível 5: o chão fica em brasa (item vivo depois da explosão); custo por quadro baixo;
#  - a evolução Fogos de Festival (cabaça 3 + bola de fogo 3): cada estilhaço estoura de novo (acertos "fogos").
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_cabaca.tscn  (imprime "v2_cabaca falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Novas := preload("res://v2/armas_novas.gd")
const PASSO := 1.0 / 60.0
const ID := "cabaca_polvora"
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


func granadas() -> Array:
	var r: Array = []
	for it in w.combate.armas.novas.itens:
		if str(it.k) == "granada" and float(it.vida) > 0.0:
			r.append(it)
	return r


func estilhacos() -> Array:
	var r: Array = []
	for it in w.combate.armas.novas.itens:
		if str(it.k) == "projetil" and float(it.vida) > 0.0 and str(it.a.get("id", "")) in [ID, "fogos_de_festival"]:
			r.append(it)
	return r


func grupo_e_isolado() -> Dictionary:
	var grupo: Array = []
	for dy in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		grupo.append(monstro_a(180.0 + absf(dy) * 0.3, dy))
	return {"grupo": grupo, "isolado": monstro_a(0.0, -100.0), "centro": w.heroi.pos + Vector2(180.0 + 4.0, 0.0)}


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

	# 0. dados, ícone e escolha de cartas
	var d: Dictionary = cs.definicao(ID)
	ok(not d.is_empty() and str(d.tipo) == "granada", "a carta %s existe e é do tipo granada" % ID)
	ok((d.niveis as Array).size() == 4 and int(d.max) == 5, "5 níveis (4 melhorias) e max 5")
	ok(str(d.nome) != "" and str(d.desc) != "" and str(d.get("curto", "")) != "", "nome, descrição e nome curto em português")
	ok(Dados.icone_carta(ID) != null and Dados.icone_carta(ID).get_size() == Vector2(32, 32), "ícone próprio de 32 px")
	ok(Dados.icone_carta(ID, "", true) != null and Dados.icone_carta(ID, "", true).get_size() == Vector2(16, 16), "ícone próprio de 16 px")
	ok(Dados.icone_carta("fogos_de_festival") != null, "a fusão Fogos de Festival tem ícone próprio")
	var saiu := 0
	for i in 200:
		cs.rng.seed = 2000 + i
		for c in cs.sortear(3, 1 + i % 10):
			if str(c.id) == ID:
				saiu += 1
	ok(saiu > 0, "a Cabaça de Pólvora aparece na escolha de cartas (%d em 200 sorteios)" % saiu)

	# 1. o arremesso vai para o grupo, em arco, quica uma vez e explode no tempo certo
	zerar()
	var cena := grupo_e_isolado()
	var grupo: Array = cena.grupo
	var isolado = cena.isolado
	pegar(ID)
	ok(armas.tem(ID), "o golpe entra pela carta")
	var q := ate(func(): return not granadas().is_empty(), 200)
	ok(q >= 0, "a cabaça é arremessada depois da recarga")
	var g: Dictionary = granadas()[0] if not granadas().is_empty() else {}
	if g.is_empty():
		print("v2_cabaca falhas=%d" % (falhas + 1))
		get_tree().quit(1)
		return
	var dest: Vector2 = g.dest
	ok(dest.distance_to(cena.centro) < 45.0, "o destino cai no grupo (a %.0f px do centro dele)" % dest.distance_to(cena.centro))
	ok(dest.distance_to(isolado.pos) > dest.distance_to(cena.centro) + 100.0, "e não no monstro isolado")
	var voo := float(armas.ativas[ID].st.voo)
	var pavio := float(armas.ativas[ID].st.pavio)
	var z_meio := 0.0
	var z_max := 0.0
	var quiques := 0
	var est_ant := int(g.est)
	var quadros := 0
	var quadros_explosao := -1
	var vidas_antes: Array = []
	for m in grupo:
		vidas_antes.append(float(m.vida))
	for i in 240:
		w.avancar(PASSO)
		if float(g.age) >= 0.0:
			quadros += 1
		var z: float = novas._altura_granada(g)
		z_max = maxf(z_max, z)
		if int(g.est) == 0 and absf(float(g.age) - voo * 0.5) < PASSO:
			z_meio = z
		if int(g.est) == 1 and est_ant == 0:
			quiques += 1
		if int(g.est) == 2:
			ok(z == 0.0, "no pavio a cabaça está no chão (z %.2f)" % z)
		if int(g.est) == 3 and quadros_explosao < 0:
			quadros_explosao = quadros
			# o anel nasce com N estilhaços; no mesmo quadro um pode já ter batido num monstro colado na explosão (giro aleatório) e morrido
			var n_est := int(armas.ativas[ID].st.estilhacos)
			ok(estilhacos().size() <= n_est and estilhacos().size() >= n_est - 2, "a explosão solta %d estilhaços (%d)" % [n_est, estilhacos().size()])
			for e in estilhacos():
				ok(float(e.vida) <= 0.36 and float(e.mult) < 1.0, "o estilhaço dura 0,35 s e leva parte do dano")
			break
		est_ant = int(g.est)
	ok(z_meio > 20.0, "no meio do voo a cabaça está alta (z %.1f)" % z_meio)
	ok(z_max < 100.0, "mas o arco é baixo (z máx %.1f)" % z_max)
	ok(quiques == 1, "a cabaça quica exatamente 1 vez (%d)" % quiques)
	var esperado := (voo + Novas.QUIQUE_T + pavio) / PASSO
	ok(
		quadros_explosao > 0 and absf(float(quadros_explosao) - esperado) <= 2.0,
		"explode em voo+quique+pavio = %.0f quadros (deu %d)" % [esperado, quadros_explosao]
	)
	var feridos := 0
	for i in grupo.size():
		if float(grupo[i].vida) < float(vidas_antes[i]):
			feridos += 1
	ok(feridos == grupo.size(), "os 5 monstros do grupo levaram dano (%d)" % feridos)
	ok(float(isolado.vida) == float(isolado.vida_max), "o isolado, fora do raio, não levou dano")
	ok(int(armas.acertos.get("granada", 0)) > 0, "a explosão registra acertos")
	var q2 := ate(func(): return estilhacos().is_empty(), 30)
	ok(q2 >= 0 and q2 <= 24, "os estilhaços somem em até 0,4 s (%d quadros)" % q2)
	ok(novas.itens.size() == Novas.MAX, "o pool continua com %d slots" % Novas.MAX)
	ok(armas.no_brilho.get_child_count() == 0 and armas.no_corpo.get_child_count() == 0, "nenhum nó novo nas camadas de desenho")

	# 2. os 5 níveis
	var st1: Dictionary = armas.ativas[ID].st
	var dano1 := float(st1.dano)
	pegar(ID)
	ok(float(armas.ativas[ID].st.dano) == dano1 + 6.0, "nível 2: +6 de dano")
	pegar(ID)
	var st3: Dictionary = armas.ativas[ID].st
	ok(float(st3.raio) == float(st1.raio) + 10.0 and int(st3.estilhacos) == int(st1.estilhacos) + 2, "nível 3: raio +10 e +2 estilhaços")
	pegar(ID)
	ok(int(armas.ativas[ID].st.quantidade) == 2, "nível 4: 2 cabaças")
	armas.ativas[ID].t = 0.0
	var q4 := ate(func(): return granadas().size() == 2, 120)
	ok(q4 >= 0, "no nível 4 saem 2 cabaças (%d)" % granadas().size())
	pegar(ID)
	var st5: Dictionary = armas.ativas[ID].st
	ok(float(st5.recarga) < float(st1.recarga) and float(st5.get("brasa_s", 0.0)) > 0.0, "nível 5: recarga menor e o chão fica em brasa")
	ok(float(armas.numeros(armas.ativas[ID]).dps) > 0.0, "o card de status tem um dano por segundo")

	# 3. o nível 5 deixa brasa: um item vivo depois da explosão (a partir daqui, com a Cabaça no máximo)
	passos(300)
	zerar()
	cena = grupo_e_isolado()
	for i in 5:
		pegar(ID)
	armas.ativas[ID].t = 0.0
	var q5 := ate(func(): return _brasa(), 400)
	ok(q5 >= 0, "no nível 5 o chão fica em brasa depois da explosão")

	# 4. custo por quadro com cabaças, estilhaços e brasa
	armas.ativas[ID].t = 0.0
	passos(60)
	var t0 := Time.get_ticks_usec()
	var n := 300
	var perto: Array = armas._perto
	for i in n:
		novas.quadro(w.heroi, PASSO, perto)
	var media := float(Time.get_ticks_usec() - t0) / float(n)
	ok(media < 1500.0, "o passo do pool custa %.0f us por quadro com cabaças ativas (limite 1500)" % media)

	# 5. a fusão: cabaça 3 + bola de fogo 3 = Fogos de Festival; cada estilhaço estoura de novo
	zerar()
	cena = grupo_e_isolado()
	for i in 3:
		pegar(ID)
		pegar("bola_fogo")
	ok(cs.evoluidas.has("fogos_de_festival"), "cabaça 3 + bola de fogo 3 evoluem para os Fogos de Festival")
	ok(armas.tem("fogos_de_festival") and not armas.tem(ID) and not armas.tem("bola_fogo"), "os Fogos entram e consomem as duas peças")
	armas.acertos.clear()
	var q6 := ate(func(): return int(armas.acertos.get("fogos", 0)) >= 8, 600)
	ok(q6 >= 0, "os estilhaços estouram de novo (estouros %d)" % int(armas.acertos.get("fogos", 0)))

	print("explosão em %d quadros (esperado %.0f); custo do passo do pool: %.0f us/quadro; acertos %s" % [quadros_explosao, esperado, media, armas.acertos])
	print("v2_cabaca falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


## Fotos (com janela e `-- --fotos=PASTA`): a cabaça no ar, o clarão da explosão com os estilhaços e os fogos coloridos.
func fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	Config.g_aplicar_perfil("alto")
	Config.temporario("pausar_fora", false)  # a janela sem foco não pode pausar a partida durante o print
	var armas = w.combate.armas
	zerar()
	grupo_aberto()
	pegar(ID)
	await _foto_quando(func(): return _g_fase(0, 0.27), 400, pasta.path_join("cabaca_no_ar.png"))
	await _foto_quando(func(): return _g_fase(3, 0.07), 400, pasta.path_join("cabaca_explosao.png"))
	await _foto_quando(func(): return _g_fase(3, 0.12), 400, pasta.path_join("cabaca_explosao_meio.png"))  # estilhaços e números abertos em leque
	await _foto_quando(func(): return _g_fase(3, 0.12), 400, pasta.path_join("cabaca_explosao_depois.png"), 31)  # a fumaça já subiu e as brasas ficaram
	zerar()
	grupo_e_isolado()
	for i in 5:
		pegar(ID)
	armas.ativas[ID].t = 0.0
	await _foto_quando(func(): return _g_fase(3, 0.8), 600, pasta.path_join("cabaca_brasa_nivel5.png"))  # o chão em brasa do nível 5
	zerar()
	grupo_aberto()
	for i in 3:
		pegar(ID)
		pegar("bola_fogo")
	await get_tree().create_timer(5.0).timeout  # o aviso da fusão sai da tela (relógio de parede)
	armas.acertos.clear()
	await _foto_quando(func(): return int(armas.acertos.get("fogos", 0)) >= 3, 600, pasta.path_join("fogos_de_festival.png"))


## Para as fotos: quatro monstros espalhados (30 a 50 px entre si) em volta do ponto de queda, para os números de dano abrirem sem empilhar.
func grupo_aberto() -> void:
	for d in [Vector2(168, -34), Vector2(200, -12), Vector2(172, 20), Vector2(204, 38)]:
		monstro_a(d.x, d.y)
	monstro_a(0.0, -100.0)


func _g_fase(est: int, idade: float) -> bool:
	for it in w.combate.armas.novas.itens:
		if str(it.k) == "granada" and float(it.vida) > 0.0 and int(it.est) == est and float(it.age) >= idade:
			return true
	return false


func _foto_quando(cond: Callable, max_passos: int, arquivo: String, extra := 0) -> void:
	var q := ate(cond, max_passos)
	passos(extra)
	await RenderingServer.frame_post_draw
	var img: Image = w.sv.get_texture().get_image()
	img.save_png(arquivo)
	print("FOTO ", arquivo, " ", img.get_size(), " depois de ", q, " quadros")


func _brasa() -> bool:
	for it in w.combate.armas.novas.itens:
		if str(it.k) == "granada" and int(it.est) == 3 and float(it.vida) > 1.0:
			return true
	return false
