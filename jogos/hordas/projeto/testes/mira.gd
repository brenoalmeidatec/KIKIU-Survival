extends Node
# Teste automático: mira direcional (#126). Campo `mira` por arma ("auto" | "direcional"); projétil, lança, pistolas, raio e
# katana atiram pra onde o jogador aponta (analógico direito ou mouse) com assistência de 20 graus; sem entrada de mira miram no
# mais perto; órbita, aura, poça, corvos e runas continuam automáticos.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/mira.tscn  (imprime "MIRA falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Armas := preload("res://scripts/hordas/armas.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## Tempo SIMULADO: passos fixos de 1/60 s com a arena em _process manual, cada passo com um quadro de verdade.
## Com o relógio de parede o projétil andava uma distância diferente por quadro (dt real), e o ricochete
## mudava a direção conforme a carga da máquina (falhou 1 de 4 rodadas com as cenas em paralelo).
func avancar(a: Node, s: float) -> void:
	var t := 0.0
	while t < s - 0.000001:
		var d := minf(1.0 / 60.0, s - t)
		a._process(d)
		await get_tree().process_frame
		t += d


func _ready() -> void:
	for acao in [
		"cima",
		"baixo",
		"esquerda",
		"direita",
		"dash",
		"especial",
		"transformar",
		"voltar",
		"confirmar",
		"falar",
		"resortear",
		"pular",
		"banir",
		"status",
		"tela_cheia",
		"consumivel1",
		"consumivel2",
		"consumivel3",
		"consumivel_usar",
		"consumivel_trocar",
		"mira_esquerda",
		"mira_direita",
		"mira_cima",
		"mira_baixo"
	]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	_dados()
	_pura()
	await _na_arena()
	print("MIRA falhas=%d" % falhas)
	get_tree().quit()


func _dados() -> void:
	var m: Dictionary = Dados.json("mira")
	ok(str(m.get("_ajuda", "")) != "", "mira.json tem _ajuda")
	ok(is_equal_approx(float(m.get("assistencia_graus", 0)), 20.0), "assistência de 20 graus")
	var armas: Dictionary = Dados.json("armas")
	for t in ["projetil", "lanca", "pistolas", "raio", "katana"]:
		ok(str(m.tipos.get(t, "")) == "direcional", "tipo %s é direcional" % t)
	for t in ["orbita", "aura", "poca", "corvos", "runas"]:
		ok(str(m.tipos.get(t, "")) == "auto", "tipo %s continua automático" % t)
	ok(Armas.modo_mira(armas.pendrive) == "direcional", "pendrive (projétil) direcional")
	ok(Armas.modo_mira(armas.lanca) == "direcional", "lança direcional")
	ok(Armas.modo_mira(armas.desert_eagles) == "direcional", "pistolas direcionais (campo mira da arma)")
	ok(Armas.modo_mira(armas.raio) == "direcional", "raio direcional")
	ok(Armas.modo_mira(armas.katana) == "direcional", "katana direcional")
	ok(Armas.modo_mira(armas.ventoinha) == "auto", "ventoinha (órbita) automática")
	ok(Armas.modo_mira(armas.aura_hazaki) == "auto", "aura automática")
	ok(Armas.modo_mira(armas.corvos) == "auto", "corvos automáticos")
	ok(Armas.modo_mira(armas.runas) == "auto", "runas automáticas")
	ok(Armas.modo_mira({"tipo": "projetil", "mira": "auto"}) == "auto", "o campo mira da arma vale mais que o padrão do tipo")


func _pura() -> void:
	var o := Vector2.ZERO
	var graus := deg_to_rad(20.0)
	# inimigo a ~6 graus da linha apontada: gruda nele
	var r := Armas.resolver_mira(o, Vector2.RIGHT, [Vector2(100, 10), Vector2(100, 100)], graus)
	ok(r.alvo == Vector2(100, 10), "gruda no inimigo a 6 graus (%s)" % str(r.alvo))
	ok(absf(r.dir.angle() - Vector2(100, 10).angle()) < 0.001, "a direção vai pro inimigo grudado")
	# o mais alinhado ganha, mesmo o mais longe
	r = Armas.resolver_mira(o, Vector2.RIGHT, [Vector2(60, 20), Vector2(200, 8)], graus)
	ok(r.alvo == Vector2(200, 8), "entre dois dentro do cone, o mais alinhado (%s)" % str(r.alvo))
	# fora dos 20 graus: segue a linha apontada
	r = Armas.resolver_mira(o, Vector2.RIGHT, [Vector2(100, 60)], graus)
	ok(r.alvo == null and r.dir.is_equal_approx(Vector2.RIGHT), "inimigo a 31 graus: não gruda, vai reto")
	r = Armas.resolver_mira(o, Vector2.RIGHT, [Vector2(100, 33)], graus)
	ok(r.alvo != null, "a 18 graus ainda gruda")
	# sem assistência (0 graus) ou sem inimigos
	r = Armas.resolver_mira(o, Vector2.RIGHT, [Vector2(100, 10)], 0.0)
	ok(r.alvo == null and r.dir.is_equal_approx(Vector2.RIGHT), "sem assistência vai reto")
	r = Armas.resolver_mira(o, Vector2.UP, [], graus)
	ok(r.alvo == null and r.dir.is_equal_approx(Vector2.UP), "sem inimigos vai pra onde aponta")
	# atrás de quem mira não conta (angle_difference dá a volta certa)
	r = Armas.resolver_mira(o, Vector2.LEFT, [Vector2(-100, -10)], graus)
	ok(r.alvo == Vector2(-100, -10), "funciona apontando pra esquerda (ângulo dá a volta em PI)")
	r = Armas.resolver_mira(o, Vector2.RIGHT, [Vector2(-100, 0)], graus)
	ok(r.alvo == null, "inimigo atrás não gruda")


func _na_arena() -> void:
	var a := Arena.new()
	a.heroi_id = "hazaki"
	add_child(a)
	a.set_process(false)  # tempo simulado: quem anda o jogo é avancar() (passos fixos de 1/60 s), não o relógio de parede
	await avancar(a, 1.6)
	a.bot = false
	var j = a.jogador
	j.bot = false
	j.invencivel = 9999.0
	a.diretor.xp_mult = 0.0
	if a.cartas.aberto():
		a.cartas._fechar()
	a.inimigos.limpar()
	a.armas.lista.clear()
	a.armas.adicionar("pendrive")
	var p = a.armas.achar("pendrive")
	# ---- analógico direito: entra no mira_dir ----
	ok(j.mira_dir == Vector2.ZERO, "sem entrada de mira: ZERO")
	Input.action_press("mira_direita", 1.0)
	Input.action_press("mira_cima", 1.0)
	await avancar(a, 3 / 60.0)
	ok(j.mira_dir.is_equal_approx(Vector2(1, -1).normalized()), "analógico direito pra cima e direita (%s)" % str(j.mira_dir))
	Input.action_release("mira_direita")
	Input.action_release("mira_cima")
	await avancar(a, 3 / 60.0)
	ok(j.mira_dir == Vector2.ZERO, "soltou o analógico: volta a ZERO")
	# ---- sem entrada de mira: projétil vai no mais perto ----
	var perto = a.inimigos.criar("carnical", j.centro() + Vector2(0, 120), 1)  # embaixo
	perto.atordoado = 20.0
	var longe = a.inimigos.criar("carnical", j.centro() + Vector2(140, 0), 1)  # à direita (mais longe)
	longe.atordoado = 20.0
	longe.pos = j.centro() + Vector2(140, 0)  # o tiro anterior pode ter empurrado o vírus: volta pro lugar
	perto.pos = j.centro() + Vector2(0, 120)
	longe.hp = 100000.0
	longe.kb = Vector2.ZERO
	perto.kb = Vector2.ZERO
	for v in a.inimigos.lista:  # os que o diretor sortear não podem atrapalhar a conta: vão pra longe
		if v != longe and v != perto:
			v.pos = j.centro() + Vector2(3000, 3000)
	await avancar(a, 2 / 60.0)
	a.armas.projeteis.clear()
	p.t = 0.0
	await avancar(a, 2 / 60.0)
	var tiro = _primeiro_tiro(a, "pendrive")
	ok(tiro != null and tiro.vel.normalized().dot(Vector2.DOWN) > 0.95, "sem mira: o projétil vai no mais perto (embaixo)")
	# ---- com mira pra direita: vai pra direita, mesmo o mais perto estando embaixo ----
	j.mira_forcada = Vector2.RIGHT
	longe.pos = j.centro() + Vector2(140, 0)  # o tiro anterior pode ter empurrado o vírus: volta pro lugar
	perto.pos = j.centro() + Vector2(0, 120)
	longe.hp = 100000.0
	longe.kb = Vector2.ZERO
	perto.kb = Vector2.ZERO
	for v in a.inimigos.lista:  # os que o diretor sortear não podem atrapalhar a conta: vão pra longe
		if v != longe and v != perto:
			v.pos = j.centro() + Vector2(3000, 3000)
	await avancar(a, 2 / 60.0)
	a.armas.projeteis.clear()
	p.t = 0.0
	await avancar(a, 2 / 60.0)
	tiro = _primeiro_tiro(a, "pendrive")
	ok(
		tiro != null and tiro.vel.normalized().dot(Vector2.RIGHT) > 0.99,
		"com mira à direita o projétil vai à direita (%s)" % (str(tiro.vel.normalized()) if tiro else "nenhum")
	)
	# ---- com assistência: mira 12 graus acima do inimigo da direita -> gruda nele ----
	j.mira_forcada = Vector2.RIGHT.rotated(deg_to_rad(-12.0))
	longe.pos = j.centro() + Vector2(140, 0)  # o tiro anterior pode ter empurrado o vírus: volta pro lugar
	perto.pos = j.centro() + Vector2(0, 120)
	longe.hp = 100000.0
	longe.kb = Vector2.ZERO
	perto.kb = Vector2.ZERO
	for v in a.inimigos.lista:  # os que o diretor sortear não podem atrapalhar a conta: vão pra longe
		if v != longe and v != perto:
			v.pos = j.centro() + Vector2(3000, 3000)
	await avancar(a, 2 / 60.0)
	a.armas.projeteis.clear()
	p.t = 0.0
	await avancar(a, 2 / 60.0)
	tiro = _primeiro_tiro(a, "pendrive")
	ok(
		tiro != null and absf(tiro.vel.normalized().angle()) < deg_to_rad(2.0),
		"assistência: 12 graus fora, o tiro gruda no inimigo (%.1f graus)" % (rad_to_deg(tiro.vel.angle()) if tiro else 99.0)
	)
	# ---- assistência desligada na opção: vai exatamente onde aponta ----
	var guardado = Config.v("mira_assistida")
	Config.temporario("mira_assistida", false)
	longe.pos = j.centro() + Vector2(140, 0)  # o tiro anterior pode ter empurrado o vírus: volta pro lugar
	perto.pos = j.centro() + Vector2(0, 120)
	longe.hp = 100000.0
	longe.kb = Vector2.ZERO
	perto.kb = Vector2.ZERO
	for v in a.inimigos.lista:  # os que o diretor sortear não podem atrapalhar a conta: vão pra longe
		if v != longe and v != perto:
			v.pos = j.centro() + Vector2(3000, 3000)
	await avancar(a, 2 / 60.0)
	a.armas.projeteis.clear()
	p.t = 0.0
	await avancar(a, 2 / 60.0)
	tiro = _primeiro_tiro(a, "pendrive")
	ok(
		tiro != null and absf(rad_to_deg(tiro.vel.angle()) + 12.0) < 1.0,
		"sem assistência o tiro vai nos -12 graus (%.1f)" % (rad_to_deg(tiro.vel.angle()) if tiro else 99.0)
	)
	Config.temporario("mira_assistida", guardado)
	# ---- lança e katana: golpes direcionais ----
	a.armas.lista.clear()
	a.armas.adicionar("lanca")
	var l = a.armas.achar("lanca")
	j.mira_forcada = Vector2.UP
	a.armas.especiais.clear()
	l.t = 0.0
	await avancar(a, 2 / 60.0)
	var esp = _primeiro_esp(a, "lanca")
	ok(esp != null and esp.dir.dot(Vector2.UP) > 0.99, "lança estoca pra onde o jogador aponta (cima)")
	j.mira_forcada = Vector2.ZERO
	a.armas.especiais.clear()
	l.t = 0.0
	await avancar(a, 2 / 60.0)
	esp = _primeiro_esp(a, "lanca")
	ok(esp != null and esp.dir.dot(Vector2.DOWN) > 0.95, "lança sem mira: o mais perto (embaixo)")
	a.armas.lista.clear()
	a.armas.adicionar("katana")
	var k = a.armas.achar("katana")
	j.mira_forcada = Vector2.LEFT
	a.armas.especiais.clear()
	k.t = 0.0
	await avancar(a, 2 / 60.0)
	esp = _primeiro_esp(a, "katana")
	ok(esp != null and esp.dir.dot(Vector2.LEFT) > 0.99, "katana corta pra onde o jogador aponta (esquerda)")
	a.armas.lista.clear()
	a.armas.adicionar("desert_eagles")
	var pi = a.armas.achar("desert_eagles")
	j.mira_forcada = Vector2.LEFT
	a.armas.especiais.clear()
	pi.t = 0.0
	await avancar(a, 2 / 60.0)
	esp = _primeiro_esp(a, "pistolas")
	ok(esp != null and esp.dir.dot(Vector2.LEFT) > 0.95, "pistolas atiram pra onde o jogador aponta (esquerda)")
	# ---- raio: o primeiro raio cai onde se aponta ----
	a.inimigos.limpar()
	var alvo_raio = a.inimigos.criar("carnical", j.centro() + Vector2(150, -30), 1)
	alvo_raio.atordoado = 20.0
	alvo_raio.hp = 100000.0
	a.armas.lista.clear()
	a.armas.adicionar("raio")
	var rr = a.armas.achar("raio")
	j.mira_forcada = Vector2.RIGHT.rotated(deg_to_rad(-9.0))
	a.armas.especiais.clear()
	rr.t = 0.0
	var hp0: float = alvo_raio.hp
	await avancar(a, 2 / 60.0)
	ok(alvo_raio.hp < hp0, "o raio cai no inimigo mais alinhado com a mira (hp %.0f -> %.0f)" % [hp0, alvo_raio.hp])
	# ---- armas automáticas ignoram a mira ----
	a.armas.lista.clear()
	a.armas.adicionar("ventoinha")
	j.mira_forcada = Vector2.UP
	await avancar(a, 3 / 60.0)
	ok(
		Armas.modo_mira(Dados.item("ventoinha")) == "auto" and a.armas.mirar(j.centro(), 1, 100.0, Dados.item("ventoinha")).is_empty(),
		"arma automática não usa a mira"
	)
	# ---- rival do duelo (dono sem mira_dir): cai no mais perto ----
	ok(a.armas.mirar(j.centro(), 1, 100.0, Dados.item("pendrive")).size() == 1, "jogador mirando: a arma direcional dá a direção")
	j.mira_forcada = Vector2.ZERO
	await avancar(a, 2 / 60.0)
	ok(a.armas.mirar(j.centro(), 1, 100.0, Dados.item("pendrive")).is_empty(), "sem mira: a arma direcional não decide (usa o mais perto)")
	a.queue_free()
	await esperar(0.1)


func _primeiro_tiro(a: Node, arma: String):
	for t in a.armas.projeteis:
		if str(t.get("arma", "")) == arma:
			return t
	return null


func _primeiro_esp(a: Node, tipo: String):
	for e in a.armas.especiais:
		if str(e.get("tipo", "")) == tipo and (e.get("corte", true)) and not e.get("lua", false) and not e.get("clarao", false) and not e.has("boom"):
			return e
	return null
