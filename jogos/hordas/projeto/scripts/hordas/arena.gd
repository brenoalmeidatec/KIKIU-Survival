extends Node2D
## Uma partida: junta jogador, vírus, armas, coleta, diretor, HUD e cartas.
## Também guarda os atributos do jogador (base + herói + passivos), o XP e o nível.

signal terminou(resumo: Dictionary)

const Jogador := preload("res://scripts/hordas/jogador.gd")
const Inimigos := preload("res://scripts/hordas/inimigos.gd")
const Armas := preload("res://scripts/hordas/armas.gd")
const Coleta := preload("res://scripts/hordas/coleta.gd")
const Efeitos := preload("res://scripts/hordas/efeitos.gd")
const Chao := preload("res://scripts/hordas/chao.gd")
const Diretor := preload("res://scripts/hordas/diretor_hordas.gd")
const Hud := preload("res://scripts/hordas/hud.gd")
const Cartas := preload("res://scripts/hordas/cartas.gd")
const Duelo := preload("res://scripts/hordas/duelo.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
const Online := preload("res://scripts/hordas/online.gd")

const MAX_ARMAS := Construcao.MAX_ARMAS
const MAX_PASSIVOS := Construcao.MAX_PASSIVOS

var heroi_id := "hazaki"
var heroi: Dictionary
var bot := false

var jogador: Node2D
var inimigos: Node2D
var armas: Node2D
var coleta: Node2D
var efeitos: Node2D
var chao: Node2D
var diretor
var hud: CanvasLayer
var cartas: CanvasLayer
var camera := Camera2D.new()
var duelo: Node2D
var duelo_ativo := false
var pre_duelo := false       # o chefe final caiu e o duelo ainda não começou
var entre_fases := false     # a fase acabou: descanso, baú e escolha antes da próxima
var eh_online := false       # partida online (main.gd liga antes de abrir a arena)
var online: Node             # online.gd, só no online
var caido := false           # online: caiu na horda e espera alguém levantar

var passivos := {}          # id -> nível
var _stats := {}
var xp := 0.0
var nivel := 1
var abates := 0
var _niveis_pendentes := 0
var _cartas_tomada := 0
var dano_por_arma := {}
var dano_recebido := {}     # de quem o jogador apanhou (pra equilibrar)
var resortear := 3
var acabou := false
var _tremor := 0.0
var _chefes_vivos := []
var perfil := [0, 0, 0, 0]   # microssegundos: jogador+diretor, inimigos, armas, resto


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	heroi = Dados.json("herois").get(heroi_id, {})
	chao = Chao.new()
	chao.arena = self
	add_child(chao)
	coleta = Coleta.new()
	coleta.arena = self
	add_child(coleta)
	armas = Armas.new()
	armas.arena = self
	inimigos = Inimigos.new()
	inimigos.arena = self
	add_child(inimigos)
	jogador = Jogador.new()
	jogador.arena = self
	jogador.bot = bot
	add_child(jogador)
	add_child(armas)
	armas.dono = jogador
	armas.campo = inimigos
	armas.statf = stat
	efeitos = Efeitos.new()
	add_child(efeitos)
	duelo = Duelo.new()
	duelo.arena = self
	add_child(duelo)
	add_child(camera)
	camera.make_current()
	if eh_online:
		online = Online.new()
		online.arena = self
		add_child(online)
		inimigos.online = online
		inimigos.espelho = Rede.cliente()
	diretor = Diretor.new()
	diretor.iniciar(self)
	_recalcular()
	jogador.configurar(str(heroi.get("sprite", heroi_id)))
	jogador.hp = stat("vida_max")
	armas.adicionar(str(heroi.get("arma", "pendrive")))
	chao.criar_santuarios()
	hud = Hud.new()
	hud.arena = self
	add_child(hud)
	cartas = Cartas.new()
	cartas.arena = self
	add_child(cartas)
	Som.musica(str(Dados.json("fase").get("musica", "minijogo_tenso")))
	var f0: Dictionary = diretor.fases()[0]
	anunciar("Fase 1: %s" % f0.get("nome", ""), Color(0.7, 0.9, 1))
	camera.position = jogador.centro()


func jogadores() -> int:
	return maxi(1, Rede.jogadores.size()) if eh_online else 1


func stat(k: String) -> float:
	var v := float(_stats.get(k, Construcao.BASE.get(k, 0.0)))
	if duelo_ativo:
		# no duelo: a vida vem da regra do pvp.json, a regeneração é menor e a aura de lentidão pega
		if k == "vida_max":
			return duelo.hp_pvp(v)
		elif k == "regen":
			return v * duelo.regen_mult
		elif k == "velocidade" and duelo.lut_jogador.lento > 0:
			return v * 0.55
	return v


func _recalcular() -> void:
	var antes := stat("vida_max")
	_stats = Construcao.stats(heroi, passivos)
	if jogador and stat("vida_max") > antes:
		jogador.curar(stat("vida_max") - antes)


func _process(dt: float) -> void:
	if acabou:
		return
	dt = minf(dt, 1.0 / 30.0)
	var t0 := Time.get_ticks_usec()
	var parado: bool = caido or (duelo_ativo and (duelo.estado == "contagem" or not duelo.lut_jogador.vivo))
	if eh_online and cartas.aberto():
		jogador.invencivel = maxf(jogador.invencivel, 0.1)   # no online o jogo não pausa: escolhendo carta, não apanha
	if not parado:
		jogador.atualizar(dt)
	elif caido:
		jogador.queue_redraw()
	if duelo_ativo:
		duelo.atualizar(dt)
	elif not pre_duelo and not entre_fases:
		if inimigos.espelho:
			diretor.so_relogio(dt)   # cliente: quem cria os vírus é o anfitrião
		else:
			diretor.atualizar(dt)
	var t1 := Time.get_ticks_usec()
	if not duelo_ativo and not pre_duelo and not entre_fases:
		inimigos.atualizar(dt, jogador)
	var t2 := Time.get_ticks_usec()
	if not parado:
		armas.atualizar(dt)
	if online:
		online.atualizar(dt)
	var t3 := Time.get_ticks_usec()
	coleta.atualizar(dt)
	efeitos.atualizar(dt)
	chao.atualizar(dt)
	hud.atualizar(dt)
	var t4 := Time.get_ticks_usec()
	perfil = [t1 - t0, t2 - t1, t3 - t2, t4 - t3]
	_tremor = maxf(0.0, _tremor - dt * 20.0)
	camera.position = duelo.centro if duelo_ativo and not duelo.lut_jogador.vivo else jogador.centro()
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _tremor
	if Input.is_action_just_pressed("voltar") and not cartas.aberto() and not hud._pausado:
		hud.pausar()


# ---------- chamados pelos outros ----------

func tremer(forca: float) -> void:
	_tremor = maxf(_tremor, forca)


func mensagem(txt: String, cor := Color.WHITE) -> void:
	hud.mensagem(txt, cor)


func anunciar(txt: String, cor := Color.WHITE) -> void:
	hud.anunciar(txt, cor)


func registrar_dano(arma: String, valor: float, pos: Vector2, crit := false) -> void:
	if arma != "":
		dano_por_arma[arma] = float(dano_por_arma.get(arma, 0.0)) + valor
	efeitos.numero(pos, valor, Color.WHITE, crit)
	Som.tocar("acerto", 0.07, randf_range(0.9, 1.2), -14)


func inimigo_morreu(v) -> void:
	recompensa(v.pos, v.tipo, v.elite)
	if online:
		online.morreu(v)   # anfitrião: cada um dos outros pega a própria recompensa
	if v.d.get("final", false):
		if online:
			Rede.evento("tela_azul_caiu")
		else:
			tela_azul_caiu()
	elif v.chefe and diretor.final_chamado and v.tipo == diretor.chefe_fase:
		if online:
			Rede.evento("fase_completa")
		else:
			fase_completa()


## O que cada jogador ganha quando um vírus morre: abate, gema de XP, efeito e sorteio de drop
## (no online cada um sorteia o seu, então XP, baú e tomada são pessoais).
func recompensa(pos: Vector2, tipo: String, elite: bool) -> void:
	var d: Dictionary = Dados.json("inimigos").get(tipo, {})
	var chefe := bool(d.get("chefe", false))
	abates += 1
	var xp_v := float(d.get("xp", 1))
	if elite:
		xp_v *= 6.0
	coleta.gema(pos, xp_v)
	var cor := Color(1, 0.85, 0.3) if elite else Color(0.55, 0.9, 0.4)
	if tipo in ["trojan", "trojan_gigante"]:
		cor = Color(0.65, 0.4, 0.85)
	elif tipo in ["ransomware"]:
		cor = Color(0.9, 0.3, 0.3)
	efeitos.explodir(pos, cor, 14 if chefe else 5, 160.0 if chefe else 80.0)
	var drops: Dictionary = Dados.json("fase").get("drops", {})
	if d.get("bau", false) or (elite and randf() < 0.25):
		coleta.soltar(pos, "bau")
	elif randf() < float(drops.get("marmita", 0.004)):
		coleta.soltar(pos, "marmita")
	elif randf() < float(drops.get("wifi", 0.0015)):
		coleta.soltar(pos, "wifi")
	if chefe:
		tremer(8)
		Som.tocar("soco", 0.1, 0.7)


## O chefe final caiu: limpa a tela e, depois de 2 s, começa o duelo (no online quem decide é o anfitrião).
func tela_azul_caiu() -> void:
	if pre_duelo or duelo_ativo or acabou:
		return
	if not bool(Dados.json("pvp").get("ativo", true)):
		_fim(true)
		return
	anunciar("A Tela Azul caiu...", Color(0.6, 0.8, 1))
	pre_duelo = true
	if caido:
		levantar(1.0)
	for o in inimigos.lista.duplicate():
		efeitos.explodir(o.pos, Color(0.5, 0.8, 0.4), 4, 100.0)
	inimigos.limpar()
	await get_tree().create_timer(2.0, true, false, true).timeout
	await _esperar_cartas()
	if acabou:
		return
	if not eh_online:
		iniciar_duelo()
	elif Rede.anfitriao():
		if Rede.jogadores.size() < 2:
			iniciar_duelo()   # ficou sozinho na sala: duelo contra robôs, como no solo
		else:
			var c: Vector2 = jogador.position.snapped(Vector2(32, 32))
			Rede.evento("duelo_iniciar", {"cx": c.x, "cy": c.y, "ang": randf() * TAU, "ordem": Rede.jogadores.keys()})


## Online: todo mundo caiu ao mesmo tempo.
func fim_corrida() -> void:
	if not acabou:
		_fim(false)


func anunciar_todos(txt: String, cor := Color.WHITE) -> void:
	anunciar(txt, cor)
	if online and Rede.anfitriao():
		Rede.evento("anuncio", {"txt": txt, "cor": cor.to_html()})


func chefe_final_chegou(final := true) -> void:
	if online and Rede.anfitriao():
		Rede.evento("chefe_final", {"final": final})
	if final:
		hud.mensagem("Derrote a Tela Azul pra vencer!", Color(0.6, 0.75, 1))
	else:
		hud.mensagem("Derrote o chefe pra fechar a fase!", Color(1, 0.75, 0.6))


## Espera as escolhas de carta (nível, tomada, baú) acabarem, sem perder nenhuma.
func _esperar_cartas() -> void:
	await get_tree().process_frame
	while not acabou and (cartas.aberto() or _niveis_pendentes > 0 or _cartas_tomada > 0):
		await get_tree().process_frame


## O chefe da fase caiu: limpa a tela, junta o XP, dá um baú e uma cura, e começa a próxima fase.
## No online todo mundo faz isso ao mesmo tempo, cada um no seu computador, e avisa o anfitrião quando
## terminou as cartas; a próxima fase começa quando todos terminarem (ou depois de 60 s).
func fase_completa() -> void:
	if entre_fases or acabou:
		return
	entre_fases = true
	var n: int = diretor.fase_idx + 1
	anunciar("Fase %d completa!" % n, Color(1, 0.9, 0.4))
	Som.tocar("vitoria", 0.1, 1.0, -8)
	if caido:
		levantar(0.5)   # quem caiu volta no fim da fase
	for o in inimigos.lista.duplicate():
		efeitos.explodir(o.pos, Color(0.5, 0.8, 0.4), 4, 100.0)
	inimigos.limpar()
	coleta.puxar_tudo()
	await get_tree().create_timer(2.2, true, false, true).timeout
	await _esperar_cartas()
	if acabou:
		return
	jogador.curar(stat("vida_max") * 0.5)
	abrir_bau()
	await _esperar_cartas()
	if acabou:
		return
	if eh_online:
		anunciar("Esperando os outros...", Color(0.7, 0.9, 1))
		Rede.avisar("pronto")
	else:
		proxima_fase()


func proxima_fase() -> void:
	if not entre_fases or acabou:
		return
	diretor.proxima_fase()
	chao.nova_fase()
	var f: Dictionary = diretor.fases()[diretor.fase_idx]
	anunciar("Fase %d: %s" % [diretor.fase_idx + 1, f.get("nome", "")], Color(0.7, 0.9, 1))
	entre_fases = false


func chefes() -> Array:
	var lista: Array = inimigos.lista.filter(func(v): return v.chefe)
	lista.sort_custom(func(a, b): return a.d.get("final", false) and not b.d.get("final", false))
	return lista


# ---------- XP e nível ----------

func xp_para(n: int) -> float:
	if n < 20:
		return 5.0 + (n - 1) * 6.0
	if n < 40:
		return 119.0 + (n - 20) * 20.0
	return 519.0 + (n - 40) * 40.0


func ganhar_xp(valor: float) -> void:
	xp += valor * stat("xp")
	while xp >= xp_para(nivel):
		xp -= xp_para(nivel)
		nivel += 1
		_niveis_pendentes += 1
	if _niveis_pendentes > 0 and not cartas.aberto():
		_abrir_proxima()


func ganhar_carta_tomada() -> void:
	_cartas_tomada += 1
	if not cartas.aberto():
		_abrir_proxima()


func _abrir_proxima() -> void:
	if acabou:
		return
	if _niveis_pendentes > 0:
		_niveis_pendentes -= 1
		Som.tocar("plim")
		cartas.escolher("Subiu pro nível %d!" % nivel, sortear_cartas())
	elif _cartas_tomada > 0:
		_cartas_tomada -= 1
		Som.tocar("plim", 0.05, 1.2)
		cartas.escolher("Tomada carregada!", sortear_cartas())


## Chamado pelas cartas quando o jogador escolhe uma.
func escolheu(c: Dictionary) -> void:
	aplicar(c)
	if _niveis_pendentes > 0 or _cartas_tomada > 0:
		_abrir_proxima.call_deferred()


func aplicar(c: Dictionary) -> void:
	match str(c.tipo):
		"arma":
			if armas.tem(c.id):
				armas.subir(c.id)
			else:
				armas.adicionar(c.id)
		"passivo":
			passivos[c.id] = int(passivos.get(c.id, 0)) + 1
			_recalcular()
			armas.preaquecer()   # passivo de área muda o tamanho da poça: gera agora, com as cartas abertas
		"cura":
			jogador.curar(40)
		"evolucao":
			armas.trocar(c.de, c.id)


func pode_resortear() -> bool:
	return resortear > 0


func gastar_resortear() -> Array:
	resortear -= 1
	return sortear_cartas()


## Sorteia 3 cartas (às vezes 4, com sorte) entre: subir arma/passivo que já tem, ou pegar novos.
func sortear_cartas() -> Array:
	var cand := []   # [peso, carta]
	var armas_d: Dictionary = Dados.json("armas")
	var pas_d: Dictionary = Dados.json("passivos")
	for a in armas.lista:
		if a.nivel < armas.nivel_max(a.id):
			cand.append([10.0, _carta("arma", a.id, a.nivel + 1)])
	for id in passivos:
		if passivos[id] < int(pas_d[id].get("max", 5)):
			cand.append([8.0, _carta("passivo", id, passivos[id] + 1)])
	if armas.lista.size() < MAX_ARMAS:
		var ids: Array = armas.lista.map(func(a): return a.id)
		for id in armas_d:
			# global ou exclusiva deste herói (até o limite): nunca oferece carta impossível
			if not Construcao.arma_permitida(id, heroi_id, ids) or _tem_evolucao_de(id):
				continue
			cand.append([float(armas_d[id].get("peso_carta", 6.0)), _carta("arma", id, 1)])
	if passivos.size() < MAX_PASSIVOS:
		for id in pas_d:
			if id.begins_with("_") or passivos.has(id):
				continue
			cand.append([5.0, _carta("passivo", id, 1)])
	var n := 3
	if randf() < 0.1 + stat("sorte") * 0.35:
		n = 4
	var res := []
	while res.size() < n and not cand.is_empty():
		var total := 0.0
		for c in cand:
			total += c[0]
		var r := randf() * total
		for i in cand.size():
			r -= cand[i][0]
			if r <= 0:
				res.append(cand[i][1])
				cand.remove_at(i)
				break
	if res.is_empty():
		res.append({"tipo": "cura", "id": "vida", "nome": "Café da tarde", "desc": "Recupera 40 de vida.", "icone": "vida", "nivel": 0})
	return res


func _tem_evolucao_de(base: String) -> bool:
	for e in Dados.json("evolucoes").get("lista", []):
		if e.arma == base and armas.tem(e.vira):
			return true
	return false


func _carta(tipo: String, id: String, nv: int) -> Dictionary:
	var d := Dados.item(id)
	var desc := str(d.get("descricao", ""))
	if tipo == "arma" and nv > 1:
		desc = _texto_nivel(d.get("niveis", [])[nv - 2])
	var c := {"tipo": tipo, "id": id, "nome": str(d.get("nome", id)), "desc": desc, "icone": str(d.get("icone", id)), "nivel": nv}
	if tipo == "arma" and Construcao.exclusiva(id):
		# carta de arma exclusiva mostra quantas ele terá de quantas pode ter (ex.: EXCLUSIVA 1/2)
		var ids: Array = armas.lista.map(func(a): return a.id)
		c["exclusiva"] = "%d/%d" % [Construcao.n_exclusivas(ids, heroi_id) + (1 if nv == 1 else 0), Construcao.limite_exclusivas()]
	return c


func _texto_nivel(n: Dictionary) -> String:
	var partes := []
	for k in n:
		var v := float(n[k])
		match k:
			"dano": partes.append("+%d de dano" % v)
			"quantidade": partes.append("+%d projétil" % v)
			"recarga": partes.append("recarrega %.2fs mais rápido" % -v)
			"area": partes.append("+%d%% de área" % (v * 100))
			"perfura": partes.append("atravessa +%d" % v)
			"duracao": partes.append("+%.1fs de duração" % v)
			"tique": partes.append("acerta mais rápido")
			_: partes.append("+%s %s" % [v, k])
	return ", ".join(partes)


# ---------- baú ----------

func abrir_bau() -> void:
	Som.tocar("abrir")
	var premios := []
	for e in Dados.json("evolucoes").get("lista", []):
		var a = armas.achar(e.arma)
		if a and a.nivel >= armas.nivel_max(e.arma) and passivos.has(e.passivo):
			var d := Dados.item(e.vira)
			premios.append({"tipo": "evolucao", "id": e.vira, "de": e.arma, "nome": str(d.get("nome", e.vira)),
				"desc": "EVOLUIU! " + str(d.get("descricao", "")), "icone": str(d.get("icone", e.vira)), "nivel": 0})
			break
	if premios.is_empty():
		var n := 1
		var r := randf()
		if r < 0.1 + stat("sorte") * 0.1:
			n = 5
		elif r < 0.35 + stat("sorte") * 0.2:
			n = 3
		for i in n:
			# baú prefere subir o que você já tem
			var opcoes := sortear_cartas()
			var ja_tem := opcoes.filter(func(c): return c.nivel > 1)
			var c: Dictionary = (ja_tem if not ja_tem.is_empty() else opcoes).pick_random()
			premios.append(c)
			aplicar(c)
	else:
		aplicar(premios[0])
	cartas.mostrar_bau(premios)


# ---------- fim ----------

func morrer(quem := "") -> void:
	if acabou:
		return
	if duelo_ativo:
		duelo.jogador_caiu(quem)
		return
	if eh_online:
		_cair()
		return
	_fim(false)


## Online: caiu na horda. Vira corpo no lugar e espera alguém ficar perto (ou a fase acabar).
func _cair() -> void:
	if caido:
		return
	caido = true
	jogador.hp = 0
	jogador.spr.rotation = PI / 2
	jogador.spr.position = Vector2(-30, -10)
	jogador.spr.modulate = Color(0.45, 0.45, 0.5, 0.8)
	online.reviver_prog = 0.0
	anunciar("Você caiu!", Color(1, 0.4, 0.4))
	mensagem("Espere alguém chegar perto pra te levantar.", Color(1, 0.8, 0.6))


func levantar(frac: float) -> void:
	if not caido:
		return
	caido = false
	jogador.spr.rotation = 0.0
	jogador.spr.position = Vector2.ZERO
	jogador.spr.modulate = Color.WHITE
	jogador.hp = maxf(1.0, stat("vida_max") * frac)
	jogador.invencivel = 1.5


## Online: menu de pausa > Desistir. Sai da sala e termina a partida aqui.
func desistir() -> void:
	if eh_online:
		Rede.sair()
		_fim(false)
	else:
		morrer("desistiu")


## Começa o duelo final (depois do chefe final, ou direto no teste).
func iniciar_duelo() -> void:
	if duelo_ativo or acabou:
		return
	if cartas.aberto():
		cartas._fechar()
	duelo.iniciar(self)


## Online: o anfitrião mandou começar o duelo entre as pessoas (d = centro, ângulo e ordem dos peers).
func iniciar_duelo_online(d: Dictionary) -> void:
	if duelo_ativo or acabou:
		return
	await _esperar_cartas()   # quem ainda escolhe carta entra quando terminar
	if duelo_ativo or acabou:
		return
	if caido:
		levantar(1.0)
	duelo.iniciar_online(self, d)


## Teste: dá ao jogador uma build sorteada de nível N (--build=N).
func dar_build_teste(nv: int) -> void:
	var b: Dictionary = Construcao.gerar(heroi_id, nv, RandomNumberGenerator.new())
	armas.lista.clear()
	for a in b.armas:
		armas.adicionar(a.id)
		armas.achar(a.id).nivel = a.nivel
	passivos = b.passivos
	nivel = nv
	_recalcular()
	jogador.hp = stat("vida_max")


## Teste: build de nível N e vai direto pro duelo (--duelo=N).
func iniciar_duelo_teste(nv: int) -> void:
	dar_build_teste(nv)
	iniciar_duelo()


func fim_duelo(res: Dictionary) -> void:
	_fim(res.lugar == 1, {"duelo": res})


func _fim(vitoria: bool, extra := {}) -> void:
	acabou = true
	Som.parar_musica()
	Som.tocar("vitoria" if vitoria else "derrota")
	var lista_dano := []
	for a in dano_por_arma:
		lista_dano.append([a, dano_por_arma[a]])
	lista_dano.sort_custom(func(x, y): return x[1] > y[1])
	var res := {"vitoria": vitoria, "fase": diretor.fase_idx + 1, "fases": diretor.fases().size(), "tempo": diretor.tempo, "nivel": nivel, "abates": abates,
		"heroi": heroi_id, "dano": lista_dano, "apanhou": dano_recebido}
	res.merge(extra)
	await get_tree().create_timer(1.2, true, false, true).timeout
	terminou.emit(res)
