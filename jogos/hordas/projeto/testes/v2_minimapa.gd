extends Node
# Teste do minimapa da v2 (v2/minimapa.tscn, montado pelo mundo dentro da apresentação). Converte uma posição do mundo para o minimapa
# e volta; o fundo é gerado uma vez (150x84, a mesma textura sempre) e tem o santuário dourado; a névoa começa escura e revela em volta
# do herói, de forma permanente; os monstros a até 600 px viram marcadores; as luzes fortes aparecem quando reveladas; os marcadores
# são repintados a 10 Hz; o Tab segura o mapa grande (não com o card de status, a escolha ou o baú na tela) e Jogar de novo zera a névoa.
# Os passos são fixos (1/60 s), sem relógio de parede.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_minimapa.tscn  (imprime "v2_minimapa falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var m


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)
		m.passar(PASSO)


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)  # os passos são nossos
	w.heroi.entrada_forcada = Vector2.ZERO
	m = w.ui.get_node_or_null("Minimapa")
	ok(m != null, "o mundo monta o minimapa dentro da apresentação (sv)")
	if m == null:
		print("v2_minimapa falhas=%d" % falhas)
		get_tree().quit()
		return
	m.set_process(false)
	ok(not m.grande, "começa no minimapa pequeno")

	# 1. conversão: do mundo para o minimapa e de volta
	var fundo0: ImageTexture = m.fundo
	ok(fundo0 != null and fundo0.get_size() == Vector2(150, 84), "o fundo tem 150x84 px")
	var mapa: Rect2 = w.mapa
	ok(m.mundo_para_mapa(mapa.position) == Vector2.ZERO, "o canto do mapa vira (0, 0)")
	ok(m.mundo_para_mapa(mapa.end).distance_to(Vector2(150, 84)) < 0.001, "o canto oposto vira (150, 84)")
	var erro := 0.0
	for p in [Vector2(1440, 830), Vector2(123.4, 987.6), Vector2(2800, 40), w.heroi.pos, mapa.get_center()]:
		erro = maxf(erro, m.mapa_para_mundo(m.mundo_para_mapa(p)).distance_to(p))
	ok(erro < 0.01, "mundo -> minimapa -> mundo volta ao mesmo ponto (erro %.4f px)" % erro)

	# 2. o fundo é gerado uma vez e tem o santuário (dourado) e as bordas fechadas
	passos(60)
	ok(m.fundo == fundo0, "o fundo é a mesma textura depois de 1 s (não é gerado por quadro)")
	var im: Image = m.fundo.get_image()
	var dourados := 0
	var fechados := 0
	for y in 84:
		for x in 150:
			var c := im.get_pixel(x, y)
			if c.is_equal_approx(Color("ddcc80")):
				dourados += 1
			if c.is_equal_approx(Color("101a14")):
				fechados += 1
	ok(dourados >= 10, "o santuário aparece dourado no fundo (%d px)" % dourados)
	ok(fechados > 20, "as bordas do mapa aparecem fechadas (%d px)" % fechados)

	# 3. a névoa começa escura e revela em volta do herói
	var c0: Vector2 = w.heroi.pos + Heroi.CENTRO_CORPO
	ok(m.revelado(c0), "a névoa revela no ponto do herói")
	ok(m.revelado(c0 + Vector2(150, 0)), "a névoa revela a 150 px do herói")
	ok(not m.revelado(c0 + Vector2(420, 0)), "a névoa não revela a 420 px do herói")
	ok(not m.revelado(Vector2(2600, 1300)), "longe do herói o mapa segue escuro")

	# 4. a névoa segue o herói e não volta a escurecer (permanente)
	var longe := Vector2(600, 400)
	w.heroi.definir_pos(longe - Heroi.CENTRO_CORPO)
	passos(12)
	ok(m.revelado(longe), "a névoa revela em volta do herói no novo lugar")
	ok(m.revelado(c0), "o lugar de onde o herói saiu segue revelado (permanente)")

	# 5. marcadores: monstros a até 600 px do herói (os de fora não entram)
	var centro: Vector2 = w.heroi.pos + Heroi.CENTRO_CORPO
	w.monstros[0].definir_pos(centro + Vector2(100, 0))
	w.monstros[1].definir_pos(centro + Vector2(0, -300))
	w.monstros[2].definir_pos(centro + Vector2(900, 0))
	m.passar(0.1)
	var esperados := 0
	for mo in w.monstros:
		if mo.pos.distance_to(centro) <= 600.0:
			esperados += 1
	ok(esperados >= 2, "há monstros perto para o teste (%d)" % esperados)
	ok(m.monstros_mapa.size() == esperados, "um marcador por monstro a até 600 px (%d de %d)" % [m.monstros_mapa.size(), esperados])
	ok(m.heroi_mapa.distance_to(m.mundo_para_mapa(centro)) < 0.01, "o herói está no lugar dele no minimapa")
	ok(m.mira_dir.length() > 0.99, "a seta do herói tem direção")

	# 6. luzes fortes: estão no minimapa e aparecem quando a névoa as revela
	var fogueira := Vector2.ZERO
	for a in w.cenario.objetos:
		if a.chave == "fogueira":
			fogueira = a.pos
			break
	ok(m.luzes_mapa.size() >= 3, "o minimapa tem os braseiros e as fogueiras do mapa (%d)" % m.luzes_mapa.size())
	w.heroi.definir_pos(fogueira)
	m.passar(0.1)
	ok(m.luzes_vistas.size() >= 1, "a fogueira aparece quando a névoa a revela (%d)" % m.luzes_vistas.size())

	# 7. o Tab segurado abre o mapa grande; ao soltar, volta ao pequeno
	m.ler_tecla(false)
	m.ler_tecla(true)
	ok(m.grande, "segurar o Tab abre o mapa grande")
	ok(m._quadro.size == Vector2(620, 356), "mapa grande com moldura de 620x356 (%s)" % str(m._quadro.size))
	m.ler_tecla(true)
	ok(m.grande, "continuar segurando mantém o mapa grande")
	m.ler_tecla(false)
	ok(not m.grande, "soltar o Tab volta ao minimapa pequeno")
	ok(m._quadro.size == Vector2(170, 104), "minimapa pequeno com moldura de 170x104 (%s)" % str(m._quadro.size))

	# 7b. baús: só aparecem no minimapa depois de vistos pela névoa
	var longe_bau := Vector2(2600, 1300)  # fora da névoa (ver o item 3)
	w.combate.baus.soltar(longe_bau)
	m.passar(0.1)
	ok(m.baus_mapa.is_empty(), "um baú ativo, ainda não visto, não aparece no minimapa")
	var perto_bau: Vector2 = w.heroi.pos + Heroi.CENTRO_CORPO + Vector2(40, 0)
	w.combate.baus.soltar(perto_bau)
	m.passar(0.1)
	ok(m.baus_mapa.size() == 1, "um baú já visto aparece no minimapa (%d)" % m.baus_mapa.size())

	# 7c. seta na borda: missão longe do herói ganha seta; a borda fica entre o herói e a missão
	var origem := Vector2(75, 42)
	var borda: Vector2 = m._na_borda(origem, Vector2(150, 42))  # alvo à direita, fora do mapa
	ok(borda.is_equal_approx(Vector2(149, 42)), "a seta fica na borda do lado do alvo (%s)" % str(borda))
	var meio: Vector2 = m._na_borda(origem, Vector2(80, 45))  # alvo dentro: a seta sai na borda, depois do alvo
	ok(meio.x >= 79.9 and meio.x <= 149.0, "a seta de um alvo dentro do mapa sai na borda (%s)" % str(meio))

	# 7d. mirante: revela o mapa inteiro de uma vez
	m.revelar_tudo()
	ok(m.revelado(Vector2(2600, 1300)) and m.revelado(Vector2(60, 60)), "o mirante revela o mapa todo")
	ok(m._quadro.position.x + m._quadro.size.x <= 960.0 - 8.0 + 0.01 and m._quadro.position.y == 8.0, "o pequeno fica no canto superior direito")

	# 7e. o Tab não abre o mapa grande com o card de status na tela, nem sobre a escolha de cartas ou o baú
	m.ler_tecla(false)
	w.status.alternar()  # C: o card de status fica na tela
	ok(w.status.aberto(), "o C põe o card de status na tela")
	m.ler_tecla(true)
	ok(not m.grande, "com o card de status na tela, o Tab não abre o mapa grande")
	m.ler_tecla(false)
	w.status.alternar()
	ok(not w.status.aberto(), "o C tira o card de status")
	var h = w.heroi
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)  # sobe de nível: a escolha abre quando o mundo roda
	for i in 300:
		passos(1)
		if w.combate.telas.escolha_aberta:
			break
	ok(w.combate.telas.escolha_aberta, "a escolha de cartas abre ao subir de nível")
	w.combate.telas.espera_escolha = 0.0  # a trava de 1 s (tempo real) não é o assunto aqui
	m.ler_tecla(true)
	ok(not m.grande, "sobre a escolha de cartas, o Tab não abre o mapa grande")
	m.ler_tecla(false)
	w.combate.progresso.escolher(0)
	ok(not w.combate.telas.escolha_aberta, "escolher uma carta fecha a escolha")
	w.combate.telas.mostrar_bau(w.combate.cartas.sortear(2, 3))
	ok(w.combate.telas.bau_aberto, "o baú abre")
	m.ler_tecla(true)
	ok(not m.grande, "sobre o baú, o Tab não abre o mapa grande")
	m.ler_tecla(false)
	w.combate.telas.esconder()
	m.ler_tecla(true)
	ok(m.grande, "sem card, escolha nem baú, o Tab volta a abrir o mapa grande")
	m.ler_tecla(false)

	# 7f. Jogar de novo: a névoa, os baús e as setas da partida anterior (e o mirante) não ficam no minimapa
	m.revelar_tudo()  # o mirante da partida de antes
	w.reiniciar()
	ok(not m.revelado(Vector2(2600, 1300)) and not m.revelado(Vector2(60, 60)), "Jogar de novo: a névoa volta a cobrir o mapa (o mirante não vale)")
	ok(m.baus_mapa.is_empty() and m.setas_mapa.is_empty(), "Jogar de novo: baús e setas da partida anterior saem do minimapa")
	m.passar(0.1)
	ok(m.revelado(w.heroi.pos + Heroi.CENTRO_CORPO), "depois de Jogar de novo a névoa revela em volta do herói novo")
	ok(not m.revelado(Vector2(2600, 1300)), "depois de Jogar de novo, o longe segue escuro")

	# 8. 10 Hz: em 1 s, os marcadores são repintados ~10 vezes (e não 60)
	var a0: int = m.atualizacoes
	for i in 60:
		m.passar(PASSO)
	var dif: int = m.atualizacoes - a0
	ok(dif >= 9 and dif <= 11, "os marcadores são repintados a ~10 Hz (%d em 1 s)" % dif)

	# 9. 300 quadros de verdade (o _process do mundo e do minimapa), sem erro de script
	w.heroi.definir_pos(Vector2(float(w.dados.nascimento.heroi[0]), float(w.dados.nascimento.heroi[1])))
	w.set_process(true)
	m.set_process(true)
	for i in 300:
		await get_tree().process_frame
	ok(w.quadros > 300, "o mundo rodou os quadros (%d)" % w.quadros)
	ok(m.atualizacoes > 10, "o minimapa também rodou no _process (%d atualizações)" % m.atualizacoes)
	print("v2_minimapa monstros_marcados=%d luzes=%d revelados_no_fim=%s" % [m.monstros_mapa.size(), m.luzes_mapa.size(), str(m.revelado(c0))])
	print("v2_minimapa falhas=%d" % falhas)
	get_tree().quit()
