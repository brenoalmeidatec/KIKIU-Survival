extends Node
# Teste automático: fim do auto-battle (#161). O golpe principal (a arma inicial do herói, `disparo: clique`) só sai com o botão
# de ataque (clique esquerdo do mouse / gatilho direito), na direção do cursor; segurar repete no ritmo da recarga e clicar não fura
# a recarga. Armas de carta (`disparo: auto`) continuam atirando sozinhas. Clique em menu, carta ou pausa não vira golpe.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/ataque_clique.tscn  (imprime "ataque_clique falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Armas := preload("res://scripts/hordas/armas.gd")
var falhas := 0
## Vírus de teste: o diretor sorteia outros a qualquer hora e puxariam a mira assistida; todo passo manda pra longe quem não for alvo.
var alvos: Array = []


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## Tempo simulado (passos de 1/60 s com a arena em _process manual), como em mira.gd.
func avancar(a: Node, s: float) -> void:
	var t := 0.0
	while t < s - 0.000001:
		var d := minf(1.0 / 60.0, s - t)
		a._process(d)
		for v in a.inimigos.lista:
			if not v in alvos:
				v.pos = a.jogador.centro() + Vector2(3000, 3000)
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
		"mira_baixo",
		"atacar"
	]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	var clique := InputEventMouseButton.new()  # o mesmo mapeamento do main.gd (_teclas)
	clique.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("atacar", clique)
	var gatilho := InputEventJoypadMotion.new()
	gatilho.axis = JOY_AXIS_TRIGGER_RIGHT
	gatilho.axis_value = 1.0
	InputMap.action_add_event("atacar", gatilho)
	get_window().size = Vector2i(640, 360)  # janela do tamanho do viewport: as coordenadas do mouse do teste valem 1:1 (headless abre 64x64)
	_dados()
	await _na_arena()
	print("ataque_clique falhas=%d" % falhas)
	get_tree().quit()


func _dados() -> void:
	var armas: Dictionary = Dados.json("armas")
	ok(str(armas.get("_ajuda", "")).contains("disparo"), "armas.json documenta o campo disparo no _ajuda")
	for h in Dados.json("herois").get("lista", []):
		var arma := str(Dados.json("herois")[h].arma)
		ok(Armas.disparo_de(arma, true) == "clique", "a arma inicial de %s vale clique" % h)
		ok(Armas.disparo_de(arma, false) == "auto", "a mesma arma vinda de carta de %s vale auto" % h)
	for id in ["baforada", "garras_dragao"]:
		ok(Armas.disparo_de(id) == "clique", "%s (golpe da forma de dragão) vale clique" % id)
	for id in ["energia_draconica", "rugido", "ventoinha", "corvos", "runas"]:
		ok(Armas.disparo_de(id) == "auto", "%s continua automática" % id)
	for ev in InputMap.action_get_events("atacar"):
		ok(ev is InputEventMouseButton or ev is InputEventJoypadMotion, "ação atacar só tem mouse e gatilho")


## Aperta/solta o botão esquerdo do mouse com o cursor em `pos` (coordenadas da janela), pelo caminho de verdade da entrada.
func _mouse(pos: Vector2, apertado: bool) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = apertado
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if apertado else 0
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _tiros(a: Node, arma: String) -> int:
	var n := 0
	for t in a.armas.projeteis:
		if str(t.get("arma", "")) == arma:
			n += 1
	return n


func _primeiro_tiro(a: Node, arma: String):
	for t in a.armas.projeteis:
		if str(t.get("arma", "")) == arma:
			return t
	return null


func _na_arena() -> void:
	var a := Arena.new()
	a.heroi_id = "lucas"  # arma inicial: pendrive (projétil), fácil de enxergar
	add_child(a)
	a.set_process(false)
	await avancar(a, 1.6)
	a.bot = false
	var j = a.jogador
	j.bot = false
	j.invencivel = 9999.0
	a.diretor.xp_mult = 0.0
	if a.cartas.aberto():
		a.cartas._fechar()
	a.inimigos.limpar()
	var p = a.armas.achar("pendrive")
	ok(p != null and p.disparo == "clique", "a arma inicial do herói nasce com disparo clique")
	# um vírus parado e quase imortal embaixo: o "mais perto", que NÃO é pra onde vamos apontar
	var perto = a.inimigos.criar("carnical", j.centro() + Vector2(0, 90), 1)
	perto.atordoado = 999.0
	perto.hp = 1.0e9
	alvos = [perto]
	var recarga: float = float(a.armas._s(p).recarga)

	# ---- 1) sem entrada, a arma inicial não dispara ----
	var vistos := 0
	p.t = 0.0
	for i in 12:
		perto.pos = j.centro() + Vector2(0, 90)
		await avancar(a, 0.25)
		vistos += _tiros(a, "pendrive")
	ok(vistos == 0, "sem entrada de ataque a arma inicial não atira em 3 s (viu %d tiros)" % vistos)
	ok(not j.atacando, "sem botão apertado: atacando é falso")
	ok(p.t <= 0.0001, "a arma inicial espera pronta (recarga zerada), não fica atirando atrasada")

	# ---- 2) com entrada, dispara na direção do cursor (e só enquanto aperta) ----
	var cursor := Vector2(520, 180)  # à direita do herói (no meio da tela); o vírus mais perto está embaixo
	_mouse(cursor, true)
	await avancar(a, 1.0 / 60.0)
	ok(j.atacando, "botão esquerdo apertado em jogo: atacando")
	await avancar(a, 2.0 / 60.0)
	var tiro = _primeiro_tiro(a, "pendrive")
	ok(tiro != null, "com o botão apertado a arma inicial atira")
	var esperado: Vector2 = (j.get_global_mouse_position() - j.centro()).normalized()
	ok(
		tiro != null and tiro.vel.normalized().dot(esperado) > 0.97 and tiro.vel.normalized().dot(Vector2.DOWN) < 0.5,
		"o tiro vai pro cursor (%s), não pro mais perto" % (str(tiro.vel.normalized()) if tiro else "nenhum")
	)
	# segurar repete no ritmo da recarga
	a.armas.projeteis.clear()
	var disparos := 0
	var antes := 0
	var t_seg := 0.0
	while t_seg < 3.0:
		await avancar(a, 1.0 / 60.0)
		t_seg += 1.0 / 60.0
		var agora := _tiros(a, "pendrive")
		if agora > antes:
			disparos += agora - antes
		antes = agora
	var esperados := 3.0 / maxf(0.1, recarga)
	ok(
		disparos >= int(esperados) - 1 and disparos <= int(esperados) + 1,
		"segurar repete no ritmo da recarga: %d tiros em 3 s (esperado ~%.1f)" % [disparos, esperados]
	)
	# soltou: para
	_mouse(cursor, false)
	await avancar(a, 2.0 / 60.0)
	ok(not j.atacando, "soltou o botão: atacando falso")
	a.armas.projeteis.clear()
	await avancar(a, recarga + 0.3)
	ok(_tiros(a, "pendrive") == 0, "soltou o botão: a arma para")

	# ---- clicar não fura a recarga ----
	p.t = 0.0
	_mouse(cursor, true)
	await avancar(a, 3.0 / 60.0)
	_mouse(cursor, false)
	a.armas.projeteis.clear()
	var antes_t: float = p.t
	ok(antes_t > recarga * 0.8, "depois do golpe a arma está em recarga (%.2f)" % antes_t)
	for i in 4:  # cliques rápidos dentro da recarga
		_mouse(cursor, true)
		await avancar(a, 3.0 / 60.0)
		_mouse(cursor, false)
		await avancar(a, 3.0 / 60.0)
	ok(_tiros(a, "pendrive") == 0, "cliques rápidos não furam a recarga (%d tiros)" % _tiros(a, "pendrive"))
	ok(p.t < antes_t, "a recarga andou mesmo sem o botão apertado")

	# ---- 3) arma de carta (auto) continua atirando sozinha ----
	a.armas.adicionar("lanca")
	var lanca = a.armas.achar("lanca")
	ok(lanca.disparo == "auto", "arma vinda de carta nasce automática")
	a.armas.especiais.clear()
	a.armas.projeteis.clear()
	lanca.t = 0.0
	p.t = 0.0
	var lancas := 0
	for i in 120:  # 2 s, olhando quadro a quadro (a estocada dura poucos quadros)
		perto.pos = j.centro() + Vector2(0, 90)
		await avancar(a, 1.0 / 60.0)
		for e in a.armas.especiais:
			if str(e.get("tipo", "")) == "lanca":
				lancas += 1
				break
	ok(lancas > 0, "a arma automática da carta atira sem entrada nenhuma")
	ok(_tiros(a, "pendrive") == 0, "...enquanto a inicial segue quieta esperando o clique")
	a.armas.lista.erase(lanca)

	# ---- Mira assistida continua valendo pro golpe de clique ----
	var guardado = Config.v("mira_assistida")
	Config.temporario("mira_assistida", true)
	perto.pos = j.centro() + Vector2(140, -30)  # ~12 graus acima da linha do cursor (direita)
	p.t = 0.0
	j.mira_forcada = Vector2.RIGHT
	j.atacar_forcado = true
	await avancar(a, 3.0 / 60.0)
	var t2 = _primeiro_tiro(a, "pendrive")
	var graus_alvo := rad_to_deg((perto.pos - j.centro()).angle())
	ok(t2 != null and absf(rad_to_deg(t2.vel.angle()) - graus_alvo) < 3.0, "mira assistida gruda no vírus perto da linha do cursor")
	Config.temporario("mira_assistida", guardado)
	j.atacar_forcado = false
	j.mira_forcada = Vector2.ZERO
	a.armas.projeteis.clear()
	await avancar(a, 2.0 / 60.0)

	# ---- cliques que NÃO viram golpe: tela de cartas (inclusive o que a fecha) e pausa ----
	p.t = 0.0
	a.armas.projeteis.clear()
	a.cartas.escolher("Teste", a.sortear_cartas())
	ok(not a.entrada_livre(), "com a tela de cartas aberta a entrada de jogo não está livre")
	await esperar(0.6)  # o tempo de trava das cartas é de tempo real
	var carta: Rect2 = a.cartas._rect_carta(0)
	var onde := carta.get_center()
	_mouse(onde, true)  # este clique escolhe a carta e fecha a tela
	await avancar(a, 3.0 / 60.0)
	ok(not a.cartas.aberto(), "o clique escolheu a carta e fechou a tela")
	ok(not j.atacando, "o clique que fecha a tela de cartas não vira golpe, nem segurando o botão")
	await avancar(a, 0.3)
	ok(_tiros(a, "pendrive") == 0 and not j.atacando, "segurar o botão depois de fechar as cartas continua sem golpe")
	_mouse(onde, false)
	await avancar(a, 2.0 / 60.0)
	_mouse(cursor, true)  # um clique novo, já em jogo, ataca
	await avancar(a, 3.0 / 60.0)
	ok(j.atacando, "apertar de novo em jogo ataca")
	_mouse(cursor, false)
	await avancar(a, 2.0 / 60.0)

	a.hud.pausar()
	ok(not a.entrada_livre(), "com a pausa aberta a entrada de jogo não está livre")
	a.armas.projeteis.clear()
	p.t = 0.0
	_mouse(Vector2(20, 20), true)  # clique no vazio do menu de pausa
	await avancar(a, 3.0 / 60.0)
	_mouse(Vector2(20, 20), false)
	a.hud._retomar()
	await avancar(a, 0.3)
	ok(not j.atacando and _tiros(a, "pendrive") == 0, "clique na pausa não vira golpe")

	# ---- chicote (golpe horizontal) de clique bate no lado do cursor, não no lado em que o herói olha ----
	a.armas.lista.clear()
	a.armas.adicionar("cabo_rede", true)
	var cabo = a.armas.achar("cabo_rede")
	j.lado = 1.0
	var mouse_guardado = Config.v("mira_mouse")
	Config.temporario("mira_mouse", false)  # o mouse (parado onde o teste clicou por último) não entra na conta
	j.mira_forcada = Vector2.LEFT
	await avancar(a, 2.0 / 60.0)
	ok(a.armas._lado_golpe(cabo) == -1.0, "chicote de clique: o lado do golpe é o do cursor (esquerda), mesmo olhando pra direita")
	j.mira_forcada = Vector2.ZERO
	await avancar(a, 2.0 / 60.0)
	ok(a.armas._lado_golpe(cabo) == 1.0, "sem mira o chicote bate no lado em que o herói olha")
	cabo.disparo = "auto"
	j.mira_forcada = Vector2.LEFT
	await avancar(a, 2.0 / 60.0)
	ok(a.armas._lado_golpe(cabo) == 1.0, "chicote automático (de carta) ignora o cursor")
	Config.temporario("mira_mouse", mouse_guardado)

	# ---- o robô segura o clique sozinho (as rodadas do --bot continuam atacando) ----
	a.armas.lista.clear()
	a.armas.adicionar("pendrive", true)
	j.mira_forcada = Vector2.ZERO
	j.bot = true
	a.armas.projeteis.clear()
	var do_robo := 0
	for i in 30:
		perto.pos = j.centro() + Vector2(0, 90)
		await avancar(a, 1.0 / 60.0)
		do_robo = maxi(do_robo, _tiros(a, "pendrive"))
	ok(j.atacando and do_robo > 0, "o robô segura o clique e a arma inicial atira (atacando %s, tiros %d)" % [j.atacando, do_robo])
	j.bot = false

	a.queue_free()
	await esperar(0.1)
