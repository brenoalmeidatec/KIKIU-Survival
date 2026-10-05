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

const MAX_ARMAS := Construcao.MAX_ARMAS
const MAX_PASSIVOS := Construcao.MAX_PASSIVOS

var heroi_id := "breno"
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
	camera.position = jogador.centro()


func jogadores() -> int:
	return 1


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
	var parado: bool = duelo_ativo and (duelo.estado == "contagem" or not duelo.lut_jogador.vivo)
	if not parado:
		jogador.atualizar(dt)
	if duelo_ativo:
		duelo.atualizar(dt)
	elif not pre_duelo:
		diretor.atualizar(dt)
	var t1 := Time.get_ticks_usec()
	if not duelo_ativo and not pre_duelo:
		inimigos.atualizar(dt, jogador)
	var t2 := Time.get_ticks_usec()
	if not parado:
		armas.atualizar(dt)
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
	if Input.is_action_just_pressed("voltar") and not cartas.aberto():
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
	abates += 1
	var xp_v := float(v.d.get("xp", 1))
	if v.elite:
		xp_v *= 6.0
	coleta.gema(v.pos, xp_v)
	var cor := Color(1, 0.85, 0.3) if v.elite else Color(0.55, 0.9, 0.4)
	if v.tipo in ["trojan", "trojan_gigante"]:
		cor = Color(0.65, 0.4, 0.85)
	elif v.tipo in ["ransomware"]:
		cor = Color(0.9, 0.3, 0.3)
	efeitos.explodir(v.pos, cor, 14 if v.chefe else 5, 160.0 if v.chefe else 80.0)
	var drops: Dictionary = Dados.json("fase").get("drops", {})
	if v.d.get("bau", false) or (v.elite and randf() < 0.25):
		coleta.soltar(v.pos, "bau")
	elif randf() < float(drops.get("marmita", 0.004)):
		coleta.soltar(v.pos, "marmita")
	elif randf() < float(drops.get("wifi", 0.0015)):
		coleta.soltar(v.pos, "wifi")
	if v.chefe:
		tremer(8)
		Som.tocar("soco", 0.1, 0.7)
	if v.d.get("final", false):
		if bool(Dados.json("pvp").get("ativo", true)):
			anunciar("A Tela Azul caiu...", Color(0.6, 0.8, 1))
			pre_duelo = true
			for o in inimigos.lista.duplicate():
				efeitos.explodir(o.pos, Color(0.5, 0.8, 0.4), 4, 100.0)
			inimigos.limpar()
			await get_tree().create_timer(2.0, true, false, true).timeout
			iniciar_duelo()
		else:
			_fim(true)


func chefe_final_chegou() -> void:
	hud.mensagem("Derrote a Tela Azul pra vencer!", Color(0.6, 0.75, 1))


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
		for id in armas_d:
			if id.begins_with("_") or armas_d[id].get("evolucao", false) or armas.tem(id) or _tem_evolucao_de(id):
				continue
			cand.append([6.0, _carta("arma", id, 1)])
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
	return {"tipo": tipo, "id": id, "nome": str(d.get("nome", id)), "desc": desc, "icone": str(d.get("icone", id)), "nivel": nv}


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
	_fim(false)


## Começa o duelo final (depois do chefe final, ou direto no teste).
func iniciar_duelo() -> void:
	if duelo_ativo or acabou:
		return
	if cartas.aberto():
		cartas._fechar()
	duelo.iniciar(self)


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
	var res := {"vitoria": vitoria, "tempo": diretor.tempo, "nivel": nivel, "abates": abates,
		"heroi": heroi_id, "dano": lista_dano, "apanhou": dano_recebido}
	res.merge(extra)
	await get_tree().create_timer(1.2, true, false, true).timeout
	terminou.emit(res)
