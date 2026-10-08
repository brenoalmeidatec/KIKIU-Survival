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
	print("LEGIB falhas=%d" % falhas)
	get_tree().quit()
