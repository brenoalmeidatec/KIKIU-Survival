extends Node
# Teste automático: calor (#63). Escolha validada, contas e os efeitos de verdade numa arena.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/calor.tscn  (imprime "CALOR falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Calor := preload("res://scripts/hordas/calor.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func arena_com(calor: Dictionary) -> Node:
	var a := Arena.new()
	a.heroi_id = "nicao"
	a.bot = true
	a.calor = calor
	add_child(a)
	await esperar(0.15)
	return a


func _ready() -> void:
	# a escolha que vem de fora (arquivo velho, rede) é limpa
	var v := Calor.validar({"couro": 9, "nao_existe": 2, "garras": "x", "fome": 0, "senhores": 1.0})
	ok(v == {"couro": 3, "senhores": 1}, "validar: nível no limite, id desconhecido e lixo fora (%s)" % [v])
	ok(Calor.validar("lixo") == {}, "validar: não-dicionário vira vazio")
	ok(Calor.de_texto("couro:2, garras:1,ruim,fome:x") == {"couro": 2, "garras": 1}, "--calor= em texto")
	var e := {"couro": 2, "senhores": 1}
	ok(Calor.pontos(e) == 4, "pontos: couro 2x1 + senhores 1x2 = 4 (%d)" % Calor.pontos(e))
	var ef := Calor.efeitos(e)
	ok(is_equal_approx(ef.get("inimigo_vida", 0.0), 0.4) and is_equal_approx(ef.get("chefe_vida", 0.0), 0.35), "efeitos somados (%s)" % [ef])
	ok(Calor.maximo() >= 15, "calor máximo razoável (%d)" % Calor.maximo())

	# sem calor: nada muda
	var a0 = await arena_com({})
	var b0 = a0.inimigos.criar("bug", Vector2(500, 500))
	var vida0: float = a0.stat("vida_max")
	var xp0: float = a0.stat("xp")
	ok(a0.calor_pts == 0 and a0.resortear > 0, "sem calor: cartas normais")
	a0.queue_free()

	# com calor: inimigo mais forte, chefe mais forte, herói mais frágil, cura menor, sem cartas, mais XP
	var a1 = await arena_com({"couro": 2, "garras": 1, "senhores": 1, "fragil": 1, "feridas": 1, "destino": 1})
	var b1 = a1.inimigos.criar("bug", Vector2(500, 500))
	ok(is_equal_approx(b1.hpmax, b0.hpmax * 1.4), "Couro de Pedra 2: bug com +40%% de vida (%.1f vs %.1f)" % [b1.hpmax, b0.hpmax])
	ok(is_equal_approx(b1.dano, b0.dano * 1.2), "Garras Afiadas 1: bug bate +20%% (%.1f vs %.1f)" % [b1.dano, b0.dano])
	var chefe_tipo := ""
	for k in Dados.json("inimigos"):
		if Dados.json("inimigos")[k] is Dictionary and Dados.json("inimigos")[k].get("chefe", false):
			chefe_tipo = k
			break
	if chefe_tipo != "":
		var c1 = a1.inimigos.criar(chefe_tipo, Vector2(900, 900))
		var base_c := float(Dados.json("inimigos")[chefe_tipo].get("vida", 10))
		ok(c1.hpmax > base_c * 1.7, "Ira dos Senhores: chefe com couro + senhores (%.0f vs base %.0f)" % [c1.hpmax, base_c])
	ok(a1.stat("vida_max") < vida0, "Corpo Frágil: vida máxima menor (%.0f vs %.0f)" % [a1.stat("vida_max"), vida0])
	ok(a1.resortear == 0 and a1.pular == 0, "Destino Selado: sem sortear de novo e sem pular")
	ok(a1.stat("xp") > xp0, "recompensa: mais XP (%.2f vs %.2f)" % [a1.stat("xp"), xp0])
	a1.jogador.hp = 10.0
	a1.jogador.curar(10.0)
	ok(is_equal_approx(a1.jogador.hp, 17.0), "Feridas Abertas: cura 30%% menor (10 + 7 = %.1f)" % a1.jogador.hp)
	a1.queue_free()
	print("CALOR falhas=", falhas)
	get_tree().quit()
