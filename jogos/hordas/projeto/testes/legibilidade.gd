extends Node
# Teste automático: legibilidade (#72 marco 7). Barra de vida só em elite/chefe, etiqueta de drop (aparece e some pelas
# condições, respeita o texto Grande e o modo daltônico), marca de área (aviso do inimigo x área aliada) e custo zero
# para inimigo comum.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/legibilidade.tscn  (imprime "LEGIB falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Legib := preload("res://scripts/hordas/legibilidade.gd")
const Interface := preload("res://scripts/hordas/interface.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	# --- dados e regras puras
	var c := Legib.cfg()
	ok(float(c.get("perto", 0)) > 0 and float(c.get("nasce", 0)) > 0 and int(c.get("max", 0)) > 0, "legibilidade no coletaveis.json")
	ok(Legib.tem_barra(true, false) and Legib.tem_barra(false, true) and not Legib.tem_barra(false, false), "barra só pra elite e chefe")
	ok(Legib.nome_curto("Bug") == "Bug" and Legib.nome_curto("Sanguessuga Gigante").length() <= 14, "nome curto cabe (%s)" % Legib.nome_curto("Sanguessuga Gigante"))
	ok(Legib.nome_curto("Tela Azul da Morte do Mundo Inteiro").length() <= 14, "nome longo é cortado")
	ok(Legib.mostra_nome(10.0, 9.0) and not Legib.mostra_nome(10.0, 5.0), "o nome aparece logo depois do golpe e some")
	for tipo in ["bau", "marmita", "wifi", "fragmento"]:
		var e := Legib.etiqueta(tipo)
		ok(not e.is_empty(), "etiqueta de " + tipo)
		ok(str(e.get("nome", "")) != "" and e.has("forma") and Interface.cor(str(e.get("cor", ""))) != Color.WHITE, "etiqueta de %s tem nome, forma e cor" % tipo)
	ok(Legib.etiqueta("gema", 5.0).is_empty() and not Legib.etiqueta("gema", 30.0).is_empty(), "só a gema grande ganha etiqueta")
	ok(Legib.etiqueta("coisa_que_nao_existe").is_empty(), "item sem etiqueta não ganha")
	var perto := float(c.perto)
	var eb := Legib.etiqueta("bau")
	ok(Legib.etiqueta_visivel(eb, 0.5, 300.0), "baú recém-caído aparece mesmo longe (a tela)")
	ok(not Legib.etiqueta_visivel(eb, 30.0, 300.0), "baú velho e longe: some")
	ok(Legib.etiqueta_visivel(eb, 30.0, perto - 5.0), "baú velho mas perto: aparece")
	ok(not Legib.etiqueta_visivel(eb, 1.0, 900.0), "baú recém-caído fora da tela: não")
	var eg := Legib.etiqueta("gema", 30.0)
	ok(not Legib.etiqueta_visivel(eg, 0.5, 300.0) and Legib.etiqueta_visivel(eg, 0.5, perto - 5.0), "gema grande só perto")
	# cores: perigo x aliada, e o modo daltônico troca as duas
	ok(Legib.cor_perigo() != Legib.cor_aliada(), "o aviso do inimigo e a área aliada têm cores diferentes")
	ok(Legib.cor_perigo().r > 0.9 and Legib.cor_perigo().g < 0.4 and Legib.cor_perigo().b < 0.4, "perigo = o vermelho do aviso do #82")
	ok(Legib.cor_aliada().b > Legib.cor_aliada().r, "área aliada é azulada")
	var cn := Interface.cor(str(eb.cor))
	Config.temporario("daltonico", true)
	ok(Legib.cor_perigo() != Color(1.0, 0.25, 0.2) and Legib.cor_perigo() != Legib.cor_aliada(), "daltônico: perigo laranja e ainda diferente da aliada")
	ok(cn != Interface.cor(str(eb.cor)), "daltônico: a etiqueta troca de cor")
	Config.temporario("daltonico", false)
	ok(Legib.tam_texto() == 8, "texto normal = 8")
	Config.temporario("texto_hud", "grande")
	ok(Legib.tam_texto() == 16, "texto Grande = 16")
	Config.temporario("texto_hud", "normal")
	# a forma é diferente por tipo (quem não distingue cor distingue a forma)
	var formas := {}
	for tipo in ["bau", "marmita", "wifi", "fragmento"]:
		formas[str(Legib.etiqueta(tipo).forma)] = true
	ok(formas.size() == 4, "4 tipos, 4 formas")

	# --- dentro da partida
	var a = Arena.new()
	a.heroi_id = "hazaki"
	a.bot = true
	a.semente = 5
	add_child(a)
	await get_tree().create_timer(0.3, true, false, true).timeout
	a.set_process(false)
	a.jogador.invencivel = 999.0
	var ino = a.inimigos
	ino.limpar()
	a.armas.lista.clear()
	a.coleta.limpar()
	var base: Vector2 = a.jogador.position
	# 120 inimigos comuns na tela: nenhuma barra
	for i in 120:
		var v = ino.criar("bug", base + Vector2(-200 + (i % 20) * 20, -80 + int(i / 20) * 20))
		v.vel = 0.0
		v.t_nasc = 0.0
	ok(ino.lista.size() >= 100, "os comuns existem (%d)" % ino.lista.size())
	ok(ino.lista.filter(func(v): return Legib.tem_barra(v.elite, v.chefe)).is_empty(), "120 comuns: nenhuma barra")
	# um elite e um chefe: duas barras
	var el = ino.criar("bug", base + Vector2(60, 40), 1, true)
	el.vel = 0.0
	el.t_nasc = 0.0
	ok(el.elite, "criou o elite")
	var ch = ino.criar("bug", base + Vector2(-60, 60))
	ch.chefe = true
	ch.vel = 0.0
	ch.t_nasc = 0.0
	ok(ino.lista.filter(func(v): return Legib.tem_barra(v.elite, v.chefe)).size() == 2, "elite + chefe = 2 barras")
	ok(ino.lista.filter(func(v): return not v.elite and not v.chefe and v.t_golpe > -50.0).is_empty(), "comum não ganha relógio de golpe")
	# golpe: guarda o relógio do nome
	ino.ferir(el, 1.0)
	ok(Legib.mostra_nome(ino._t, el.t_golpe), "elite atingido mostra o nome")
	ino.limpar()

	# custo: 400 comuns no quadro, nenhuma barra, nenhuma etiqueta
	for i in 400:
		var v = ino.criar("bug", base + Vector2(-300 + (i % 40) * 15, -100 + int(i / 40) * 18))
		v.vel = 0.0
		v.t_nasc = 0.0
	for i in 300:
		a.coleta.gema(base + Vector2(-250 + (i % 30) * 14, 100 + int(i / 30) * 8), 1.0)
	var t0 := Time.get_ticks_usec()
	for _i in 100:
		a.coleta.atualizar(0.016)
	var us := Time.get_ticks_usec() - t0
	ok(ino.lista.filter(func(v): return Legib.tem_barra(v.elite, v.chefe)).is_empty() and a.coleta.rotulos_n == 0 and a.coleta._cand.is_empty(), "400 comuns e 300 gemas pequenas: zero barras, zero etiquetas, zero candidatos")
	print("LEGIB info: 100 atualizações da coleta com 300 gemas = %d us (%.1f us cada)" % [us, us / 100.0])
	ino.limpar()
	a.coleta.limpar()

	# etiquetas de verdade: baú perto aparece; o baú longe e velho some; teto por quadro
	a.coleta.soltar(base + Vector2(40, 0), "bau")
	a.coleta.atualizar(0.016)
	ok(a.coleta.rotulos_n == 1, "baú perto: 1 etiqueta (%d)" % a.coleta.rotulos_n)
	a.coleta.limpar()
	a.coleta.soltar(base + Vector2(300, 0), "bau")
	a.coleta.atualizar(0.016)
	ok(a.coleta.rotulos_n == 1, "baú recém-caído, longe: aparece (%d)" % a.coleta.rotulos_n)
	a.coleta._t += 10.0
	a.coleta.atualizar(0.016)
	ok(a.coleta.rotulos_n == 0, "10 s depois, longe: some (%d)" % a.coleta.rotulos_n)
	a.coleta.limpar()
	for i in 20:
		a.coleta.soltar(base + Vector2(i * 4, 30), "marmita")
	a.coleta.atualizar(0.016)
	ok(a.coleta.rotulos_n == int(c.max), "teto de etiquetas por quadro (%d)" % a.coleta.rotulos_n)
	a.coleta.limpar()
	a.coleta.soltar(base + Vector2(10, 10), "fragmento")
	a.coleta.gema(base + Vector2(0, 20), 30.0)
	a.coleta.gema(base + Vector2(0, 30), 1.0)
	a.coleta.atualizar(0.016)
	ok(a.coleta.rotulos_n == 2, "fragmento e gema grande: 2 etiquetas, a gema de 1 não (%d)" % a.coleta.rotulos_n)
	a.coleta.limpar()

	# --- objetivos acima da horda (#123, #125): camadas, opacidade, seta e distância mínima do baú
	var ob = a.objetivo
	ob._zerar()
	ob._iniciar("pira")
	ob.pos = base + Vector2(200, 0)
	ob._marcas()
	ok(ob._topo.z_index >= 50 and a.saida.z_index >= 50 and a.missao._topo.z_index >= 50, "objetivo, missão e portal numa camada alta (z>=50)")
	ok(a.saida.z_index > a.coleta.z_index and a.saida.z_index > a.armas.z_index, "o portal fica acima de coleta e armas")
	var alvos: Array = Legib.alvos(a)
	ok(alvos.size() >= 1 and alvos.has(ob.pos), "os alvos incluem o objetivo (%d)" % alvos.size())
	a.saida.abrir(base + Vector2(-300, 50))
	ok(Legib.alvos(a).has(a.saida.pos), "o portal aberto também é alvo")
	ok(Legib.alfa_sobre(ob.pos + Vector2(10, 0), alvos) == 0.4, "em cima do alvo: 40% de opacidade")
	ok(Legib.alfa_sobre(ob.pos + Vector2(150, 0), alvos) == 1.0, "longe do alvo: opacidade cheia")
	# o shader dos efeitos liga só enquanto existe alvo
	a.camada_objetivos._process(0.016)
	ok(a.armas.material != null and a.armas._chao_pocas.material != null and a.armas._atras.material != null, "com alvo: efeitos de arma usam o material de 40%")
	ok(a.armas.material.get_shader_parameter("alfa") == 0.4 and int(a.armas.material.get_shader_parameter("n")) >= 2, "o material conhece os alvos e os 40%")
	a.saida.fechar()
	ob._zerar()
	a.camada_objetivos._process(0.016)
	ok(a.armas.material == null, "sem alvo: sem material (custo zero)")
	# baú nunca nasce a menos de 96 px de um alvo
	ob._iniciar("pira")
	ob.pos = base + Vector2(200, 0)
	ob._marcas()
	a.coleta.limpar()
	for dx in [0.0, 5.0, -30.0, 60.0, 95.0]:
		a.coleta.soltar(ob.pos + Vector2(dx, 3), "bau")
	a.coleta.soltar(ob.pos, "bau")
	var min_d := 9999.0
	for it in a.coleta.itens:
		min_d = minf(min_d, it.pos.distance_to(ob.pos))
	ok(Legib.BAU_MIN == 96.0 and min_d >= 96.0 - 0.01, "baú nasce a no mínimo 96 px do objetivo (menor: %.1f)" % min_d)
	ok(Legib.longe_dos_alvos(Vector2(500, 500), [Vector2(0, 0)]) == Vector2(500, 500), "baú já longe não se mexe")
	var dois := Legib.longe_dos_alvos(Vector2(10, 100), [Vector2(0, 0), Vector2(0, 200)])
	ok(dois.distance_to(Vector2(0, 0)) >= 95.9 and dois.distance_to(Vector2(0, 200)) >= 95.9, "entre dois alvos: longe dos dois")
	ob._zerar()
	a.coleta.limpar()
	# seta na borda com a distância (a tela é 640x360)
	var tela := Vector2(640, 360)
	ok(Legib.seta_borda(Vector2(100, 50), tela).is_empty(), "alvo dentro da tela: sem seta")
	var s := Legib.seta_borda(Vector2(1000, 0), tela)
	ok(not s.is_empty() and absf(s.p.x - (320 + (320 - 22))) < 1.0 and s.metros == 100, "alvo à direita: seta na borda direita, 100 m (%s)" % str(s))
	var s2 := Legib.seta_borda(Vector2(0, -500), tela)
	ok(not s2.is_empty() and s2.p.y < 40.0 and s2.metros == 50, "alvo em cima: seta na borda de cima, 50 m")
	var s3 := Legib.seta_borda(Vector2(-900, 600), tela)
	ok(s3.p.x >= 0.0 and s3.p.x <= 640.0 and s3.p.y >= 0.0 and s3.p.y <= 360.0, "seta diagonal fica dentro da tela")
	print("LEGIB falhas=%d" % falhas)
	get_tree().quit()
