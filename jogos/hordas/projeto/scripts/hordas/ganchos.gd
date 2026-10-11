extends Node2D
## Ganchos de raça e classe (#72 marco 6): regras próprias que mudam COMO o herói joga, em vez de só somar números.
## Cada raça (racas.json > ganchos) ou classe (classes.json > ganchos) lista {tipo, nome, texto, ...parâmetros}; aqui cada
## TIPO tem um ponto de código só, e o resto do jogo chama os eventos genéricos abaixo (nunca olha a raça):
##   bonus(k)              atributos dinâmicos que a arena.stat soma (fúria, regeneração no escuro)
##   dano_recebido(d, f)   jogador.sofrer: pedra, fragil, etereo e as pilhas da fúria
##   ao_acertar(valor)     arena.registrar_dano: roubo de vida
##   reviver()             arena.morrer: vidas extras (com explosão)
##   rolamento_mult() / rolamento_cargas()   jogador.rolar e o fôlego
##   atualizar(dt)         o relógio de tudo (parado, pilhas, luz) e as auras do MUNDO
## Online: o que fica no herói (dano recebido, vida, roubo, reviver, rolamento) roda no computador de cada um. As auras mexem
## nos inimigos, que só o anfitrião simula: ele aplica a aura de TODOS os heróis em pé (a dele e a dos clientes, pela raça que
## a ficha validada diz). O efeito viaja na foto que já existe (lento = bit 16, veneno = bit 128), sem campo novo na rede.

const Perf := preload("res://scripts/hordas/perf.gd")
const TIPOS := ["aura_lento", "aura_veneno", "fragil", "pedra", "roubo_vida", "luz", "vidas", "rolamento", "furia", "etereo"]
const AURAS := ["aura_lento", "aura_veneno"]

var arena: Node
var lista: Array = []
var vidas_gastas := 0  # quantas vezes já levantou (vidas)
var pilhas := 0  # fúria: golpes recentes que o herói levou
var escuro := false  # a luz de agora é de "escuro" (luz)
var claro := false  # luz forte
var _parado := 0.0  # há quanto tempo o herói não anda
var _pilha_t := 0.0
var _soma := {}  # bônus dinâmicos já somados (recalculados todo quadro; bonus() só lê)
var _orc := 0.0  # roubo de vida: o que ainda pode curar neste segundo (teto_s)
var _acc := 0.0  # roubo de vida: fração de vida ainda não curada
var _aura_t := {}  # relógio de cada aura: "dono:tipo" -> segundos pro próximo tique

var aura_tocados := {}  # tipo -> quantos inimigos as auras tocaram até agora (teste e depuração)


## Ganchos de um herói da tabela de heróis (herois.json + criados): [] se ele não tem (heróis fixos, saves antigos).
static func de_heroi(id: String) -> Array:
	var g = Dados.json("herois").get(id, {}).get("ganchos", [])
	return g if g is Array else []


## Anfitrião online: algum cliente joga com uma raça de aura (mundo)? O nó de ganchos existe mesmo que o herói do anfitrião não tenha nenhum.
static func cliente_com_aura() -> bool:
	if not Rede.anfitriao():
		return false
	for p in Rede.jogadores:
		for g in de_heroi(str(Rede.jogadores[p].get("heroi", ""))):
			if str(g.get("tipo", "")) in AURAS:
				return true
	return false


## Por que um gancho não vale ("" = vale): tipo que não existe aqui ou parâmetro faltando. O teste confere todos os JSON.
static func erro(g) -> String:
	if not g is Dictionary:
		return "gancho não é um dicionário"
	var t := str(g.get("tipo", ""))
	if not t in TIPOS:
		return "tipo de gancho desconhecido: " + t
	if str(g.get("texto", "")) == "" or str(g.get("nome", "")) == "":
		return "gancho %s sem nome ou texto" % t
	var precisa := {
		"aura_lento": ["raio", "lento"],
		"aura_veneno": ["raio", "tique"],
		"fragil": ["mult"],
		"pedra": ["parado_s", "reducao"],
		"roubo_vida": ["pct"],
		"luz": ["limite"],
		"vidas": ["n", "frac"],
		"rolamento": ["dist"],
		"furia": ["bonus", "max", "dura"],
		"etereo": ["contato", "tiro"]
	}
	for k in precisa.get(t, []):
		if not g.has(k):
			return "gancho %s sem '%s'" % [t, k]
	return ""


func configurar(a: Node, ganchos: Array) -> void:
	arena = a
	lista = ganchos.duplicate()


func tem(tipo: String) -> bool:
	for g in lista:
		if str(g.tipo) == tipo:
			return true
	return false


func _g(tipo: String) -> Dictionary:
	for g in lista:
		if str(g.tipo) == tipo:
			return g
	return {}


func _no_duelo() -> bool:
	return arena.duelo_ativo


# ---------- eventos que o resto do jogo chama ----------


## Atributos a mais agora (a arena.stat soma). Só lê o que atualizar() calculou.
func bonus(k: String) -> float:
	return float(_soma.get(k, 0.0))


## O dano que o herói leva de verdade: pedra (parado), fragil, etereo (toque x tiro); a fúria sobe a cada golpe levado.
func dano_recebido(dano: float, fonte: String) -> float:
	if _no_duelo():
		return dano
	var m := 1.0
	var andando: bool = arena.jogador._mov != Vector2.ZERO
	for g in lista:
		match str(g.tipo):
			"pedra":
				if _parado >= float(g.parado_s):
					m *= 1.0 - float(g.reducao)
			"fragil":
				m *= float(g.mult)
			"etereo":
				if fonte == "tiro":
					m *= float(g.tiro)
				elif andando:
					m *= float(g.contato)
			"furia":
				pilhas = mini(int(g.max), pilhas + 1)
				_pilha_t = float(g.dura)
	return dano * m


## O herói acertou um inimigo com dano `valor` (golpe de arma, não o dano no tempo): rouba vida.
func ao_acertar(valor: float) -> void:
	if _no_duelo() or arena.caido:
		return
	for g in lista:
		if str(g.tipo) == "roubo_vida":
			_acc += valor * float(g.pct)


## O herói zerou a vida: levanta de novo se ainda tem vidas. Devolve true se levantou (a arena não termina a corrida).
func reviver() -> bool:
	if _no_duelo():
		return false
	for g in lista:
		if str(g.tipo) != "vidas" or vidas_gastas >= int(g.n):
			continue
		vidas_gastas += 1
		var jog: Node2D = arena.jogador
		jog.hp = maxf(1.0, jog.vida_max() * float(g.frac))
		jog.invencivel = 2.0
		var resta := int(g.n) - vidas_gastas
		arena.anunciar("%s! %s" % [str(g.nome), "Ainda sobra %d." % resta if resta > 0 else "Foi a última."], Color(1, 0.85, 0.5))
		var ex: Dictionary = g.get("explode", {})
		if not ex.is_empty():
			explodir(jog.centro(), float(ex.get("raio", 80)), float(ex.get("dano", 30)))
		return true
	return false


## Explosão em volta do ponto: fere e empurra quem está perto (vale em solo e no cliente: o golpe segue o caminho normal de ferir).
func explodir(c: Vector2, raio: float, dano: float) -> int:
	var n := 0
	for v in arena.inimigos.no_circulo(c, raio):
		var dir: Vector2 = (v.pos - c).normalized() if v.pos != c else Vector2.RIGHT
		arena.inimigos.ferir(v, dano * arena.stat("dano"), dir * 260.0)
		n += 1
	arena.efeitos.explodir(c, Color(1, 0.8, 0.4), 22, 220.0)
	arena.tremer(5.0)
	return n


## Quanto a distância do rolamento é multiplicada (1 = normal).
func rolamento_mult() -> float:
	var m := 1.0
	for g in lista:
		if str(g.tipo) == "rolamento":
			m *= float(g.dist)
	return m


func rolamento_cargas() -> float:
	var n := 0.0
	for g in lista:
		if str(g.tipo) == "rolamento":
			n += float(g.get("cargas", 0))
	return n


# ---------- o relógio ----------


func atualizar(dt: float) -> void:
	var _pp := Perf.ini()
	_atualizar_i(dt)
	Perf.fim("ganchos", _pp)


func _atualizar_i(dt: float) -> void:
	var jog: Node2D = arena.jogador
	if jog._mov == Vector2.ZERO and jog.dash_t <= 0.0:
		_parado += dt
	else:
		_parado = 0.0
	if _pilha_t > 0.0:
		_pilha_t -= dt
		if _pilha_t <= 0.0:
			pilhas = 0
	_soma.clear()
	var vmax: float = jog.vida_max()
	for g in lista:
		match str(g.tipo):
			"furia":
				if pilhas > 0:
					for k in g.bonus:
						_soma[k] = float(_soma.get(k, 0.0)) + float(g.bonus[k]) * pilhas
			"luz":
				var l := _luz_agora()
				escuro = l <= float(g.limite) or (arena.escuridao != null and arena.escuridao.ligada())
				claro = not escuro and l >= float(g.get("claro_min", 2.0))
				if escuro:
					for k in g.get("escuro", {}):
						_soma[k] = float(_soma.get(k, 0.0)) + float(g.escuro[k])
				elif claro and not arena.caido and jog.hp > 1.0:  # a luz queima, mas nunca mata
					jog.hp = maxf(1.0, jog.hp - float(g.get("claro", {}).get("dano_s", 0.0)) * dt)
			"roubo_vida":
				var teto: float = vmax * float(g.get("teto_s", 0.1))
				_orc = minf(teto, _orc + teto * dt)
				if jog.hp >= vmax:
					_acc = 0.0  # vida cheia: nada a roubar
				elif _acc >= 1.0 and not arena.caido:
					var c := minf(floorf(_acc), floorf(_orc))
					if c >= 1.0:
						_orc -= c
						_acc -= c
						jog.curar(c)
				_acc = minf(_acc, 5.0)
	_auras(dt)
	if lista.size() > 0:
		position = jog.position
		queue_redraw()


## Luz do ambiente (0 = breu, 1 = dia claro): é o valor da cor do ambiente do chão, a mesma que a luz do herói usa.
func _luz_agora() -> float:
	var chao = arena.chao
	return float(chao._ambiente.color.v) if chao != null and "_ambiente" in chao and chao._ambiente != null else 1.0


# ---------- auras (mundo: só o anfitrião ou o solo) ----------


## Chamada todo quadro; cada aura de cada herói em pé tem o próprio relógio (o 'tique' do JSON), então o custo real
## é um no_circulo por aura por tique, nunca uma varredura dos 500 inimigos por quadro.
func _auras(dt: float) -> void:
	var ino = arena.inimigos
	if ino == null or ino.espelho or arena.duelo_ativo or arena.entre_fases or arena.pre_duelo:
		return
	if not arena.caido:
		_aplicar_auras(lista, arena.jogador.centro(), 0, dt)
	if arena.eh_online and arena.online != null and arena.online.anfitriao():
		for p in Rede.remotos:  # os clientes: a raça sai da ficha que o anfitrião já validou
			var d: Dictionary = Rede.remotos[p]
			if bool(d.get("caido", false)):
				continue
			var gs := de_heroi(str(Rede.jogadores.get(p, {}).get("heroi", "")))
			if not gs.is_empty():
				_aplicar_auras(gs, Vector2(float(d.x), float(d.y) - 22.0), int(p), dt)


func _aplicar_auras(gs: Array, c: Vector2, dono: int, dt: float) -> void:
	var ino = arena.inimigos
	for g in gs:
		var t := str(g.get("tipo", ""))
		if not t in AURAS:
			continue
		var chave := "%d:%s" % [dono, t]
		var resta := float(_aura_t.get(chave, 0.0)) - dt
		if resta > 0.0:
			_aura_t[chave] = resta
			continue
		_aura_t[chave] = float(g.get("tique", 0.25))
		var r := float(g.raio)
		var n := 0
		for v in ino.no_circulo(c, r):
			if v.hp <= 0.0 or c.distance_squared_to(v.pos) > r * r:
				continue
			if t == "aura_lento":
				v.lento = maxf(v.lento, float(g.lento))
			else:
				ino.aplicar_elemento(v, "veneno", float(g.get("acumulos", 1)), "gancho")
			n += 1
		aura_tocados[t] = int(aura_tocados.get(t, 0)) + n


# ---------- desenho (só o do herói local) ----------


func _draw() -> void:
	if lista.is_empty():
		return
	var cen := Vector2(0, -22)
	var t := Time.get_ticks_msec() / 1000.0
	for g in lista:
		match str(g.tipo):
			"aura_lento":
				draw_arc(cen, float(g.raio), 0.0, TAU, 40, Color(0.7, 0.9, 0.6, 0.16 + 0.05 * sin(t * 2.0)), 1.0)
			"aura_veneno":
				draw_arc(cen, float(g.raio), 0.0, TAU, 40, Color(0.55, 0.92, 0.38, 0.2 + 0.06 * sin(t * 3.0)), 1.0)
			"pedra":
				if _parado >= float(g.parado_s):
					draw_arc(cen, 20.0, 0.0, TAU, 20, Color(0.75, 0.78, 0.85, 0.7), 2.0)
					draw_arc(cen, 16.0, 0.0, TAU, 16, Color(0.5, 0.52, 0.6, 0.45), 1.0)
			"furia":
				for i in pilhas:
					var a := t * 3.0 + i * TAU / maxf(1.0, float(g.max))
					draw_circle(cen + Vector2.from_angle(a) * 22.0, 2.0, Color(1.0, 0.45, 0.15, 0.9))
			"luz":
				if escuro:
					draw_arc(cen, 18.0, 0.0, TAU, 20, Color(0.7, 0.3, 0.9, 0.35 + 0.1 * sin(t * 4.0)), 1.0)
				elif claro:
					draw_arc(cen, 18.0, 0.0, TAU, 20, Color(1.0, 0.9, 0.4, 0.5), 1.0)
