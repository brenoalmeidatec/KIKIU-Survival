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
	var q2 := ate(func(): return torres_vivas().is_empty(), 700)
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


func _evolucao(id: String) -> bool:
	for ev in w.combate.cartas.cfg.evolucoes:
		if str(ev.id) == id:
			return true
	return false
