extends Node
# Teste automático da v2 (primeira leva): o mundo de v2/mundo.tscn. Carrega o mapa de dados/v2_floresta.json, faz o herói andar 2 s para a
# direita e confere que a câmera seguiu e ficou nos limites (e com posição inteira), que a luz fora da tela está desligada, que só ator na
# tela tem sombra, que o herói olha para o mouse e para onde anda, que o monstro persegue, que o modo de sombra e as partículas leem a aba
# Gráficos, e roda 300 quadros de verdade sem SCRIPT ERROR. O mundo anda em passos fixos de 1/60 s (nada de relógio de parede).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_mundo.tscn  (imprime "v2_mundo falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Sombras := preload("res://v2/sombras.gd")
const Heroi := preload("res://v2/heroi.gd")
const Luzes := preload("res://v2/luzes.gd")
const Colisao := preload("res://v2/colisao.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)  # os passos são nossos
	w.heroi.entrada_forcada = Vector2.ZERO  # nenhuma tecla da máquina entra no teste
	w.heroi.imortal = true  # monstro encostando empurra o herói (combate): aqui o assunto é mapa, câmera e movimento

	# 1. o mapa carregou: dados, objetos, decalques, luzes, monstros e o herói no nascimento
	ok(str(w.dados.get("_ajuda", "")) != "", "v2_floresta.json tem _ajuda")
	ok(w.mapa.size == Vector2(2880, 1620), "o mapa é 2880x1620 (3x3 telas), deu %s" % str(w.mapa.size))
	ok(w.cenario.objetos.size() >= 300, "objetos do mapa: %d" % w.cenario.objetos.size())
	ok(w.cenario.n_decalques >= 300, "decalques do mapa: %d" % w.cenario.n_decalques)
	ok(w.luzes.lista.size() >= 15, "luzes do mapa: %d" % w.luzes.lista.size())
	ok(w.monstros.size() == 20, "20 monstros (deu %d)" % w.monstros.size())
	var nasc: Array = w.dados.nascimento.heroi
	ok(w.heroi.pos == Vector2(float(nasc[0]), float(nasc[1])), "o herói nasce no ponto do json")
	var nomes := {}
	for a in w.cenario.objetos:
		nomes[a.chave] = true
	for n in ["torii", "braseiro", "arvore", "coluna", "obelisco", "poste_lanterna"]:
		ok(nomes.has(n), "o mapa tem %s" % n)
	var cam_inicio: Vector2 = w.cam.position
	ok(cam_inicio == cam_inicio.round(), "a câmera começa em pixel inteiro")
	passos(30)

	# 2. o herói anda 2 s para a direita: a câmera segue, fica nos limites e em pixel inteiro
	var x0: float = w.heroi.pos.x
	var cx0: float = w.cam.position.x
	w.heroi.entrada_forcada = Vector2(1, 0)
	var inteira := true
	for i in 120:
		w.avancar(PASSO)
		inteira = inteira and w.cam.position == w.cam.position.round()
	var dx: float = w.heroi.pos.x - x0
	ok(dx > 190.0 and dx < 210.0, "o herói andou ~200 px em 2 s (deu %.1f)" % dx)
	ok(w.cam.position.x - cx0 > 150.0, "a câmera seguiu o herói (andou %.1f)" % (w.cam.position.x - cx0))
	ok(absf(w.heroi.pos.x - w.cam.position.x) < 60.0, "a câmera ficou perto do herói (%.1f)" % absf(w.heroi.pos.x - w.cam.position.x))
	ok(inteira, "a câmera esteve sempre em pixel inteiro")
	ok(
		w.heroi.coluna >= 1 and w.heroi.coluna < int(w.heroi.tipo.info.colunas.size()) and w.heroi.linha == 2,
		"andando para a direita: quadro de andar, linha direita (col %d, linha %d)" % [w.heroi.coluna, w.heroi.linha]
	)
	w.heroi.entrada_forcada = Vector2.ZERO
	passos(10)
	ok(w.heroi.coluna == 0, "parado: quadro parado")
	var r: Rect2 = w.cam.retangulo()
	ok(w.mapa.encloses(r), "a tela está dentro do mapa: %s" % str(r))

	# 3. os cantos: a câmera presa nos limites (480..2400 x 270..1350), sempre inteira
	w.heroi.definir_pos(Vector2(30, 30))
	passos(150)
	ok(w.cam.position == Vector2(480, 270), "canto superior esquerdo: câmera em %s" % str(w.cam.position))
	w.heroi.definir_pos(Vector2(2850, 1590))
	passos(150)
	ok(w.cam.position == Vector2(2400, 1350), "canto inferior direito: câmera em %s" % str(w.cam.position))
	w.heroi.definir_pos(Vector2(2850, 30))
	passos(150)
	ok(w.cam.position == Vector2(2400, 270), "canto superior direito: câmera em %s" % str(w.cam.position))
	w.heroi.entrada_forcada = Vector2(1, -1)
	passos(60)
	ok(w.heroi.pos.x <= 2880.0 - 24.0 + 0.01 and w.heroi.pos.y >= 24.0 - 0.01, "o herói não sai do mapa (%s)" % str(w.heroi.pos))
	w.heroi.entrada_forcada = Vector2.ZERO

	# 4. luz fora da tela desligada, na tela ligada (no santuário, no meio do mapa)
	w.heroi.definir_pos(Vector2(float(nasc[0]), float(nasc[1])))
	w.cam.cravar(w.heroi.pos + Heroi.CENTRO_CORPO)
	passos(5)
	var tela: Rect2 = w.cam.retangulo().grow(Luzes.MARGEM_LUZ)
	var ligadas := 0
	var desligadas := 0
	var erros_luz := 0
	for e in w.luzes.lista:
		var d := Vector2(e.pos.x - clampf(e.pos.x, tela.position.x, tela.end.x), e.pos.y - clampf(e.pos.y, tela.position.y, tela.end.y)).length()
		if d > e.raio + 1.0:
			desligadas += 1
			if e.luz.enabled or (e.orbe != null and e.orbe.visible):
				erros_luz += 1
			for q in e.particulas:
				if q.process_mode != Node.PROCESS_MODE_DISABLED:
					erros_luz += 1
		elif d < e.raio - 1.0:
			ligadas += 1
			if not e.luz.enabled:
				erros_luz += 1
	ok(erros_luz == 0, "luz fora da tela desligada e dentro ligada (%d erros)" % erros_luz)
	ok(desligadas >= 10, "no santuário há luzes fora da tela (%d)" % desligadas)
	ok(ligadas >= 5, "no santuário há luzes na tela (%d)" % ligadas)
	ok(w.luzes.dn == w.luzes.ligadas(), "as luzes das sombras são as ligadas (%d de %d)" % [w.luzes.dn, w.luzes.ligadas()])

	# 5. sombra só para ator na tela (com margem) e blocos do cenário fora da tela escondidos
	w.sombras.definir_modo(Sombras.ALTA)
	passos(10)
	var margem: Rect2 = w.cam.retangulo().grow(w.MARGEM_SOMBRA)
	var sombra_fora := 0
	var na_tela := 0
	var objeto_longe_visivel := 0
	var longe: Rect2 = w.cam.retangulo().grow(360.0)
	for a in w.cenario.objetos:
		var dentro := margem.has_point(a.pos)
		if dentro:
			na_tela += 1
		if not dentro and (a.ativo or a.blob.visible or a.sh1.visible or a.sh2.visible):
			sombra_fora += 1
		if not longe.has_point(a.pos) and a.raiz.visible:
			objeto_longe_visivel += 1
	ok(sombra_fora == 0, "nenhum objeto fora da margem tem sombra (%d)" % sombra_fora)
	ok(na_tela >= 20, "objetos na tela: %d" % na_tela)
	ok(objeto_longe_visivel == 0, "objeto longe da tela fica escondido (%d visíveis)" % objeto_longe_visivel)
	ok(
		w.cenario.n_blocos_visiveis() < w.cenario.n_blocos(),
		"só parte dos blocos fica visível (%d de %d)" % [w.cenario.n_blocos_visiveis(), w.cenario.n_blocos()]
	)
	ok(w.heroi.ativo and w.heroi.sh1 != null, "o herói tem sombra")
	for modo in [Sombras.BAIXA, Sombras.MEDIA, Sombras.ALTA]:
		w.sombras.definir_modo(modo)
		passos(6)
		var vis_sombra := 0
		var vis_blob := 0
		for a in w.cenario.objetos:
			if a.ativo:
				vis_blob += 1 if a.blob.visible else 0
				vis_sombra += 1 if (a.sh1.visible or a.sh2.visible) else 0
		ok(vis_blob > 10, "modo %s: manchas nos pés (%d)" % [Sombras.NOMES[modo], vis_blob])
		if modo == Sombras.BAIXA:
			ok(vis_sombra == 0, "baixa: sem sombra projetada (%d)" % vis_sombra)
		else:
			ok(vis_sombra > 10, "%s: sombra projetada (%d)" % [Sombras.NOMES[modo], vis_sombra])

	# 6. o modo de sombra e as partículas vêm da aba Gráficos (Config.g)
	Config.g_perfil_temporario("baixo")
	w._ler_graficos()
	ok(w.sombras.modo == Sombras.BAIXA, "perfil baixo: sombras baixa (modo %d)" % w.sombras.modo)
	ok(
		is_equal_approx(w.atm.fator_efe, 0.3) and is_equal_approx(w.atm.fator_amb, 0.25),
		"perfil baixo: partículas poucas (%.2f, %.2f)" % [w.atm.fator_efe, w.atm.fator_amb]
	)
	Config.g_perfil_temporario("medio")
	w._ler_graficos()
	ok(w.sombras.modo == Sombras.MEDIA and is_equal_approx(w.atm.fator_amb, 0.5), "perfil médio: sombras média e partículas médias")
	Config.g_perfil_temporario("alto")
	w._ler_graficos()
	ok(w.sombras.modo == Sombras.ALTA and is_equal_approx(w.atm.fator_efe, 1.0), "perfil alto: sombras alta e partículas muitas")
	Config.g_temporario("particulas_sim", "nenhuma")
	w._ler_graficos()
	ok(w.atm.fator_amb == 0.0 and w.atm.fator_efe == 0.0, "partículas nenhuma: fator 0")
	Config.g_perfil_temporario("alto")
	w._ler_graficos()

	# 7. o herói olha para o mouse (8 direções) quando o mouse mexe, e para onde anda quando a direção de andar muda
	var centro: Vector2 = w.heroi.pos + Heroi.CENTRO_CORPO
	w.heroi.fonte = Heroi.Fonte.MOUSE
	for par in [
		[Vector2(100, 0), 2],
		[Vector2(0, -100), 3],
		[Vector2(-100, 0), 1],
		[Vector2(0, 100), 0],
		[Vector2(70, 70), 5],
		[Vector2(-70, 70), 4],
		[Vector2(70, -70), 7],
		[Vector2(-70, -70), 6]
	]:
		w.mouse_forcado = centro + par[0]
		passos(2)
		ok(w.heroi.linha == par[1], "mouse em %s: linha %d (deu %d)" % [str(par[0]), par[1], w.heroi.linha])
	w.heroi.entrada_forcada = Vector2(0, 1)  # começa a andar para baixo com o mouse parado à esquerda-cima: passa a olhar para onde anda
	passos(4)
	ok(w.heroi.fonte == Heroi.Fonte.ANDA and w.heroi.linha == 0, "andando para baixo: olha para baixo (linha %d)" % w.heroi.linha)
	w.heroi.fonte = Heroi.Fonte.MOUSE  # o mouse mexeu
	w.mouse_forcado = w.heroi.pos + Heroi.CENTRO_CORPO + Vector2(100, 0)
	passos(2)
	ok(w.heroi.linha == 2, "o mouse mexeu andando: olha para o mouse (linha %d)" % w.heroi.linha)
	w.heroi.entrada_forcada = Vector2.ZERO
	w.mouse_forcado = null
	ok(Heroi.linha_de(Vector2(1, 0)) == 2 and Heroi.linha_de(Vector2(-1, 0)) == 1 and Heroi.linha_de(Vector2(0, -1)) == 3, "linha_de: direita, esquerda e cima")

	# 8. monstros: vagam sozinhos e perseguem o herói quando ele chega perto
	w.heroi.definir_pos(Vector2(float(nasc[0]), float(nasc[1])))
	var inicio := {}
	for m in w.monstros:
		inicio[m] = m.pos
	passos(300)
	var moveram := 0
	var perseguiu := 0
	for m in w.monstros:
		if m.pos.distance_to(inicio[m]) > 1.0:
			moveram += 1
		if m.persegue:
			perseguiu += 1
	ok(moveram >= 10, "os monstros vagam sozinhos (%d de 20 se mexeram)" % moveram)
	ok(perseguiu == 0, "nenhum monstro persegue de longe (%d)" % perseguiu)
	var m0 = w.monstros[0]
	w.heroi.definir_pos(m0.pos + Vector2(110, 0))
	var d0: float = m0.pos.distance_to(w.heroi.pos)
	passos(150)
	ok(m0.persegue, "o monstro perto do herói persegue")
	ok(m0.pos.distance_to(w.heroi.pos) < d0 - 50.0, "o monstro chegou perto (de %.0f para %.0f)" % [d0, m0.pos.distance_to(w.heroi.pos)])
	w.heroi.definir_pos(m0.pos + Vector2(600, 0))
	passos(30)
	ok(not m0.persegue, "o monstro desiste quando o herói foge")

	# 9. Em um trecho comprovadamente livre, mover soma o deslocamento e prende o ator na área andável.
	# O caso anterior deixava o herói encostado numa forma depois da perseguição: a correção de colisão muda o deslocamento ali.
	var trecho_livre := false
	for y in range(ceili(w.limite_andavel.position.y) + 32, floori(w.limite_andavel.end.y) - 32, 64):
		for x in range(ceili(w.limite_andavel.position.x) + 32, floori(w.limite_andavel.end.x) - 32, 64):
			var ponto := Vector2(x, y)
			var livre := true
			for passo in range(11):
				if not Colisao.livre(ponto + Vector2(10, 5) * (float(passo) / 10.0), w.heroi.raio):
					livre = false
					break
			if livre:
				w.heroi.definir_pos(ponto)
				trecho_livre = true
				break
		if trecho_livre:
			break
	ok(trecho_livre, "há um trecho livre para testar o deslocamento sem colisão")
	var a_mover: Vector2 = w.heroi.pos
	var feito: Vector2 = w.mover(w.heroi, Vector2(10, 5))
	ok(
		feito == Vector2(10, 5) and w.heroi.pos == a_mover + Vector2(10, 5),
		"mover soma o deslocamento: início=%s feito=%s final=%s esperado=%s" % [a_mover, feito, w.heroi.pos, a_mover + Vector2(10, 5)]
	)
	# O limite é testado independentemente de obstáculos entre dois extremos distantes.
	w.heroi.definir_pos(Vector2(w.limite_andavel.position.x - 500.0, w.heroi.pos.y))
	feito = w.mover(w.heroi, Vector2.ZERO)
	ok(w.heroi.pos.x == w.limite_andavel.position.x and feito.x == 500.0, "mover corrige a posição fora da área andável (x = %.1f)" % w.heroi.pos.x)

	# 9b. a colisão (v2/colisao.gd) liga em mover: o herói não atravessa um objeto isolado e fica fora das formas
	var alvo = null
	var inicio_c := Vector2.ZERO
	for a in w.cenario.objetos:
		if not (a.chave in ["muro", "tronco", "toco", "rocha", "coluna", "altar", "pedestal", "obelisco"]):
			continue
		var sozinho := true
		for b in w.cenario.objetos:
			if b != a and a.pos.distance_to(b.pos) < 100.0:
				sozinho = false
				break
		var formas: Array = w.cenario._itens[a.chave].colisao
		if formas.is_empty():
			continue
		var f: Dictionary = formas[0]
		inicio_c = a.pos + Vector2(float(f.centro[0]) - float(f.raio[0]) - 50.0, float(f.centro[1]))  # na altura do centro da forma, 50 px antes dela
		if sozinho and w.limite_andavel.has_point(inicio_c):
			alvo = a
			break
	ok(alvo != null, "há um objeto de cenário isolado para o teste de colisão")
	if alvo != null:
		w.heroi.definir_pos(inicio_c)
		w.heroi.entrada_forcada = Vector2(1, 0)
		passos(120)
		w.heroi.entrada_forcada = Vector2.ZERO
		ok(Colisao.livre(w.heroi.pos, w.heroi.raio), "o herói não fica dentro de %s" % alvo.chave)
		ok(w.heroi.pos.x < alvo.pos.x, "o herói não atravessou %s (x %.1f contra %.1f)" % [alvo.chave, w.heroi.pos.x, alvo.pos.x])
		ok(w.heroi.pos.x > inicio_c.x + 20.0, "o herói andou até %s (x %.1f)" % [alvo.chave, w.heroi.pos.x])
	w.heroi.definir_pos(Vector2(200, 1000))
	w.heroi.entrada_forcada = Vector2(-1, 0)
	passos(240)
	w.heroi.entrada_forcada = Vector2.ZERO
	ok(w.heroi.pos.x >= w.limite_andavel.position.x - 0.01, "a borda de árvores fecha o mapa: o herói para em x=%.1f" % w.heroi.pos.x)

	# 10. o gancho do golpe principal existe (a ação atacar está no InputMap), sem fazer nada ainda
	ok(InputMap.has_action("atacar"), "a ação atacar existe")
	w.heroi.atacar()

	# 11. 300 quadros de verdade (o _process do mundo), sem erro de script
	w.heroi.definir_pos(Vector2(float(nasc[0]), float(nasc[1])))
	w.set_process(true)
	for i in 300:
		await get_tree().process_frame
	ok(w.quadros > 300, "o mundo rodou os quadros (%d)" % w.quadros)
	w.sombras.definir_modo(Sombras.MEDIA)
	for i in 30:
		await get_tree().process_frame
	print(
		(
			"v2_mundo objetos=%d decalques=%d luzes=%d (ligadas na tela %d) monstros=%d quadros=%d"
			% [w.cenario.objetos.size(), w.cenario.n_decalques, w.luzes.lista.size(), ligadas, w.monstros.size(), w.quadros]
		)
	)
	print("v2_mundo falhas=%d" % falhas)
	get_tree().quit()
