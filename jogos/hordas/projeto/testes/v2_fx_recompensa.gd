extends "res://testes/isolamento_v2.gd"
# Teste do pixelfx de recompensa e chegadas (v2/fx_folha.gd chamado por bau, combate, elites e chefe): feixe do baú enquanto espera, abrir toca o
# chest-open e solta o feixe, subir de nível toca o level-up, elite e chefe tocam o portal, a invocada toca o summon-rise, a morte de elite e de
# chefe toca o soul-rise. Tudo em pool fixo (nenhum nó novo) e mudo no perfil Baixo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_fx_recompensa.tscn  (imprime "v2_fx_recompensa falhas=0")
const Anim := preload("res://v2/anim_golpes.gd")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _nos_total(raiz: Node) -> int:
	var n := 1
	for c in raiz.get_children():
		n += _nos_total(c)
	return n


func _novo():
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	return w


func _ready() -> void:
	Anim.suave = true
	var w = _novo()
	var c = w.combate
	var cf = c.fx_folha
	for id in ["chest-open", "loot-beam", "level-up", "spawn-portal", "summon-rise", "soul-rise"]:
		ok(cf.tem(id), "%s está no registro" % id)
	var nos0 := _nos_total(w)

	# 1. baú: o feixe dura enquanto ele espera; abrir solta o feixe e toca o chest-open
	var p: Vector2 = w.heroi.pos + Vector2(400, 0)
	c.baus.soltar(p)
	var b: Dictionary = c.baus.lista[0]
	ok(b.fx != 0 and cf.vivo(b.fx), "o baú que espera acende o feixe (alça %d)" % b.fx)
	for i in 120:
		c.efeitos(PASSO)
	ok(cf.vivo(b.fx) and cf.ativos == 1, "o feixe segue aceso enquanto o baú espera (loop)")
	var tocar0: int = cf.usados.tocar
	var alca: int = b.fx
	c.baus.abrir(b)
	ok(not cf.vivo(alca) and b.fx == 0, "abrir o baú solta o feixe")
	ok(cf.usados.tocar == tocar0 and cf.ativos == 0, "abrir não toca o chest-open ainda: a roleta cobre a tela")
	c.telas.esconder()
	c.pausado = false
	c.jogo = "jogando"
	c.baus.atualizar(PASSO)
	ok(cf.usados.tocar == tocar0 + 1 and cf.ativos == 1, "com o mundo de volta o chest-open toca uma vez")
	c.baus.atualizar(PASSO)
	ok(cf.usados.tocar == tocar0 + 1, "e só uma vez")
	for i in 120:
		c.efeitos(PASSO)
	ok(cf.ativos == 0, "o chest-open acabou e voltou ao pool (%d)" % cf.ativos)
	# baú reaproveitado ainda aceso: o feixe antigo não fica órfão
	c.baus.soltar(p)
	var a1: int = c.baus.lista[0].fx
	c.baus.limpar()
	ok(not cf.vivo(a1) and cf.ativos == 0, "limpar devolve o feixe")

	# 2. subida de nível: toca o level-up uma vez e ele acaba sozinho
	tocar0 = cf.usados.tocar
	c.nivel_subiu(2)
	ok(cf.usados.tocar == tocar0 + 1 and cf.ativos == 1, "subir de nível toca o level-up")
	for i in 60:
		c.efeitos(PASSO)
	ok(cf.ativos == 0, "o level-up acabou (só os primeiros quadros, sem o texto)")
	ok(_nos_total(w) == nos0, "baú e subida de nível não criaram nó no mundo (%d -> %d)" % [nos0, _nos_total(w)])

	# 3. elite: portal ao nascer, summon-rise na invocada, soul-rise ao morrer
	tocar0 = cf.usados.tocar
	var e = c.elites.nascer("", "invoca", w.heroi.pos + Vector2(120, -10))
	ok(e != null and cf.usados.tocar == tocar0 + 1, "a elite que nasce toca o spawn-portal")
	tocar0 = cf.usados.tocar
	c.elites._invocar(e)
	ok(cf.usados.tocar > tocar0, "a elite invocadora toca o summon-rise nos filhotes (+%d)" % (cf.usados.tocar - tocar0))
	tocar0 = cf.usados.tocar
	c.ferir(e, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	c.processar_mortes()
	ok(cf.usados.tocar > tocar0, "a elite que morre toca o soul-rise")
	c.jogo = "jogando"
	c.pausado = false

	# 4. chefe: portal ao chegar e alma ao cair (o intervalo mínimo entre dois portais já passou)
	for i in 40:
		c.efeitos(PASSO)
	tocar0 = cf.usados.tocar
	var ch = c.chefes
	var m = ch.nascer(ch.cfg.marcas[0], w.heroi.pos + Vector2(160, 0))
	ok(m != null and cf.usados.tocar == tocar0 + 1, "o chefe que chega toca o spawn-portal")
	m.dano = 0.0
	w.heroi.xp_proximo = 1.0e9
	tocar0 = cf.usados.tocar
	c.ferir(m, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	c.processar_mortes()
	ok(cf.usados.tocar > tocar0, "o chefe que cai toca o soul-rise")
	c.limpar_partida()
	ok(cf.ativos == 0, "limpar_partida devolve tudo")

	# 5. perfil Baixo: o feixe não acende e nada decorativo fica no ar
	Anim.suave = false
	c.baus.soltar(p)
	ok(c.baus.lista[0].fx == 0 and cf.ativos == 0, "perfil Baixo: o baú não acende o feixe")
	c.nivel_subiu(3)
	c.efeitos(PASSO)
	ok(cf.ativos == 0, "perfil Baixo: o level-up não fica no ar")
	Anim.suave = true
	c.limpar_partida()
	w.queue_free()
	await get_tree().process_frame
	print("v2_fx_recompensa falhas=", falhas)
	get_tree().quit(1 if falhas else 0)
