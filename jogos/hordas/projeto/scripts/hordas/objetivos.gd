extends Node2D
## Objetivo próprio por andar (#63, estilo Deep Rock Galactic: Survivor). Dados em dados/objetivos.json.
## O anfitrião (ou o jogo solo) decide e roda tudo: sorteia o tipo (Sorte.criar("objetivos", andar): igual em todo
## lugar), cria os totens/o fugitivo, conta o progresso e resolve. Os clientes só recebem o estado (evento "objetivo",
## ~4 vezes por segundo) e mostram no HUD; cada um paga a PRÓPRIA recompensa ou penalidade quando a resolução chega.
## Nunca trava a corrida: a fase termina como sempre; falhar custa ouro e solta uma horda extra, não é game over.

const Sorte := preload("res://scripts/hordas/sorte.gd")
const Regioes := preload("res://scripts/hordas/regioes.gd")

const NENHUM := 0
const ANDAMENTO := 1
const CUMPRIDO := 2
const FALHOU := 3
const ENVIO := 0.25  # s entre os estados mandados aos clientes
const MAX_MARCAS := 4  # setas do HUD por objetivo
const LINGER := 4.0  # s que o resultado fica no HUD

var arena: Node
var id := ""  # tipo do objetivo (chave de "tipos" no objetivos.json)
var est := NENHUM
var prog := 0.0  # totens destruídos / segundos de pira acesa / fugitivos mortos
var alvo := 0.0  # quanto precisa chegar
var resta := 0.0  # segundos que ainda sobram
var pos := Vector2.ZERO  # centro da pira
var marcas: Array = []  # Vector2: onde estão os totens / o fugitivo / a pira (seta do HUD)
var tarde := false  # falhou porque a fase acabou antes (sem horda de castigo)
var seq := 0  # conta os objetivos da corrida (o cliente descarta estado velho)
var _seq_limpo := 0  # cliente: estado de seq <= isso é de um andar que já passou
var _pago := -1
var _topo := Node2D.new()  # camada por cima de inimigos, poderes e baús (#123): marca de cada alvo
var _ids: Array = []  # anfitrião: ids dos inimigos do objetivo que ainda vivem
var _espera := -1.0  # anfitrião: segundos até o objetivo aparecer neste andar
var _pendente := ""
var _regiao := 0
var _t_envio := 0.0
var _linger := 0.0
var _t := 0.0

# ---------- dados (funções puras: o teste usa) ----------


static func cfg() -> Dictionary:
	return Dados.json("objetivos")


static func tipo_def(tid: String) -> Dictionary:
	var d = cfg().get("tipos", {}).get(tid, {})
	return d if d is Dictionary else {}


## Que objetivo (id do tipo) este andar tem? "" = nenhum. Igual em todo cliente (a semente é a mesma).
static func escolher(f: Dictionary, no_tipo: String, andar_global: int) -> String:
	if f.has("objetivo"):  # a fase manda: "tipo" força, false apaga
		return str(f.objetivo) if f.objetivo is String and not tipo_def(str(f.objetivo)).is_empty() else ""
	if f.get("chefe_regiao", false) or not f.has("regiao"):
		return ""
	var c := cfg()
	if not no_tipo in c.get("nos", ["fase", "elite"]):
		return ""
	var andares: Array = c.get("andares_regiao", [])
	if not int(f.get("andar_regiao", 0)) in andares.map(func(x): return int(x)):
		return ""
	var pool: Array = c.get("pool", {}).get(str(Regioes.regiao(int(f.regiao)).get("id", "")), c.get("padrao", []))
	pool = pool.filter(func(t): return not tipo_def(str(t)).is_empty())
	if pool.is_empty():
		return ""
	return str(pool[Sorte.criar("objetivos", andar_global).randi() % pool.size()])


## Ouro e XP da recompensa pesam mais nas regiões de dentro; "cura" é fração da vida máxima.
static func recompensa(tid: String, regiao: int) -> Dictionary:
	var d := tipo_def(tid)
	var r: Dictionary = d.get("recompensa", {})
	var k := 1.0 + float(cfg().get("escala_regiao", 0.0)) * regiao
	return {"ouro": int(round(float(r.get("ouro", 0)) * k)), "xp": float(r.get("xp", 0.0)) * k, "cura": float(r.get("cura", 0.0))}


static func cor_de(tid: String) -> Color:
	var c = tipo_def(tid).get("cor", [1, 1, 1])
	return Color(float(c[0]), float(c[1]), float(c[2]))


func _ready() -> void:
	_topo.z_index = 50
	_topo.draw.connect(_desenhar_topo)
	add_child(_topo)


## Marcador de objetivo (#123): halo, anel escuro de contorno e anel colorido pulsante, com 4 pontas girando. Desenhado em `c`
## (camada de z_index alto), então inimigos, efeitos e baús não cobrem. O contorno escuro garante contraste em todas as regiões.
static func marca_topo(c: CanvasItem, p: Vector2, cor: Color, t: float, r := 20.0, a := 1.0) -> void:
	var pulso := 0.5 + 0.5 * sin(t * 5.0)
	var rr := r + 2.0 * pulso
	c.draw_circle(p, rr + 3.0, Color(cor, (0.10 + 0.08 * pulso) * a))
	c.draw_arc(p, rr, 0.0, TAU, 40, Color(0.04, 0.02, 0.06, 0.85 * a), 5.0)
	c.draw_arc(p, rr, 0.0, TAU, 40, Color(cor.lightened(0.25), (0.75 + 0.25 * pulso) * a), 2.5)
	for i in 4:
		var ang := t * 1.2 + i * PI / 2
		var d := Vector2.from_angle(ang)
		c.draw_line(p + d * (rr + 1.0), p + d * (rr + 7.0), Color(0.04, 0.02, 0.06, 0.85 * a), 5.0)
		c.draw_line(p + d * (rr + 1.0), p + d * (rr + 7.0), Color(1, 1, 1, 0.9 * a), 2.0)


func _desenhar_topo() -> void:
	if id == "" or est != ANDAMENTO:
		return
	var cor := cor_de(id)
	if id == "pira":
		var r := float(tipo_def(id).get("raio", 70))
		_topo.draw_arc(pos, r, 0.0, TAU, 48, Color(0.04, 0.02, 0.06, 0.6), 4.0)
		_topo.draw_arc(pos, r, 0.0, TAU, 48, Color(cor.lightened(0.2), 0.55 + 0.25 * sin(_t * 4.0)), 2.0)
	for p in marcas:
		marca_topo(_topo, p, cor, _t, 22.0)


func _host() -> bool:
	return not arena.inimigos.espelho


func ativo() -> bool:
	return est == ANDAMENTO


## O HUD pergunta: algo a mostrar? (andamento, ou o resultado nos últimos LINGER segundos)
func visivel() -> bool:
	return id != "" and (est == ANDAMENTO or (est != NENHUM and _linger > 0.0))


# ---------- ciclo de vida ----------


## Andar novo (todo mundo chama). O anfitrião decide se tem objetivo e quando ele aparece.
func nova_fase(f: Dictionary, no_tipo: String, andar_global: int) -> void:
	_zerar()
	_seq_limpo = seq
	_regiao = int(f.get("regiao", 0))
	if not _host():
		return
	var t := escolher(f, no_tipo, andar_global)
	if t != "":
		_pendente = t
		_espera = float(cfg().get("inicio", 6.0))


func _zerar() -> void:
	id = ""
	est = NENHUM
	prog = 0.0
	alvo = 0.0
	resta = 0.0
	marcas = []
	tarde = false
	_ids = []
	_espera = -1.0
	_pendente = ""
	_linger = 0.0
	queue_redraw()
	_topo.queue_redraw()


func atualizar(dt: float) -> void:
	_t += dt
	if _linger > 0.0:
		_linger = maxf(0.0, _linger - dt)
	if est != NENHUM:
		queue_redraw()
		_topo.queue_redraw()
	if not _host():
		if est == ANDAMENTO:
			resta = maxf(0.0, resta - dt)  # entre um estado e outro o relógio anda sozinho; o próximo estado acerta
		return
	if _espera >= 0.0:
		_espera -= dt
		if _espera <= 0.0:
			_espera = -1.0
			_iniciar(_pendente)
		return
	if est != ANDAMENTO:
		return
	resta -= dt
	if id == "pira":
		var dentro := false
		var r := float(tipo_def(id).get("raio", 70))
		for a in _jogadores():
			if (a as Vector2).distance_squared_to(pos) <= r * r:
				dentro = true
				break
		if dentro:
			prog = minf(alvo, prog + dt)
		else:
			prog = maxf(0.0, prog - float(tipo_def(id).get("decai", 0.5)) * dt)
	if prog >= alvo:
		_resolver(CUMPRIDO)
	elif resta <= 0.0:
		_resolver(FALHOU)
	elif arena.diretor.final_chamado:
		_resolver(FALHOU, true)  # o chefe da fase chegou: acabou o tempo de objetivo
	else:
		_t_envio -= dt
		if _t_envio <= 0.0:
			_t_envio = ENVIO
			_marcas()
			_mandar()


## Posições (mundo) de quem pode estar na pira: os jogadores em pé.
func _jogadores() -> Array:
	var res := []
	if arena.online:
		for a in arena.online.alvos():
			res.append(a[0])
	elif not arena.caido:
		res.append(arena.jogador.centro())
	return res


func _referencia() -> Vector2:
	return arena.diretor._referencia()[0]


## Anfitrião: o objetivo aparece.
func _iniciar(tid: String) -> void:
	var d := tipo_def(tid)
	if d.is_empty():
		return
	seq += 1
	id = tid
	est = ANDAMENTO
	prog = 0.0
	tarde = false
	resta = float(d.get("tempo", 60))
	_linger = 0.0
	_ids = []
	var c := _referencia()
	var rng := Sorte.criar("objetivos_pos", seq)
	var dist: Array = d.get("distancia", [240, 320])
	if tid == "pira":
		alvo = float(d.get("segundos", 20))
		pos = c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(float(dist[0]), float(dist[1]))
	else:
		var n := int(d.get("quantos", 1))
		alvo = float(n)
		var a0 := rng.randf() * TAU
		for i in n:
			var p := c + Vector2.from_angle(a0 + TAU * i / n + rng.randf_range(-0.3, 0.3)) * rng.randf_range(float(dist[0]), float(dist[1]))
			var v = arena.inimigos.criar(str(d.get("inimigo", "")), p, arena.diretor.nivel())
			if v:
				_ids.append(v.id)
	_marcas()
	arena.anunciar(str(d.get("nome", "")), cor_de(tid))
	arena.mensagem(str(d.get("dica", "")), Color(0.9, 0.9, 1.0))
	_mandar()


## Anfitrião: um inimigo morreu (chamado por arena.inimigo_morreu).
func abate(v) -> void:
	if est != ANDAMENTO or not _host() or not v.id in _ids:
		return
	_ids.erase(v.id)
	prog += 1.0
	if prog >= alvo:
		_resolver(CUMPRIDO)
	else:
		_marcas()
		_mandar()


## Anfitrião: onde estão os alvos (setas do HUD).
func _marcas() -> void:
	marcas = []
	if id == "pira":
		marcas.append(pos)
		return
	for i in _ids:
		var v = arena.inimigos.por_id.get(i)
		if v and v.hp > 0.0 and marcas.size() < MAX_MARCAS:
			marcas.append(v.pos)


## Anfitrião: cumpriu ou falhou. Quem sobrou do objetivo some, o estado final vai pros clientes e o anfitrião também paga.
func _resolver(resultado: int, soft := false) -> void:
	if est != ANDAMENTO:
		return
	est = resultado
	tarde = soft
	_linger = LINGER
	for i in _ids:
		var v = arena.inimigos.por_id.get(i)
		if v and resultado == FALHOU:
			arena.efeitos.explodir(v.pos, cor_de(id), 6, 70.0)  # o totem racha / o fugitivo escapa
		arena.inimigos.remover_id(i)
	_ids = []
	marcas = []
	if resultado == FALHOU and not soft:
		_castigo()
	_mandar()
	_pagar()


## Anfitrião: a horda de castigo nasce em volta (os clientes só veem os bichos, que chegam pela foto).
func _castigo() -> void:
	var f: Dictionary = tipo_def(id).get("falha", {})
	var n := int(f.get("anel", 0))
	if n <= 0:
		return
	var tabela: Array = arena.diretor._disponiveis()
	if tabela.is_empty():
		return
	var c := _referencia()
	for k in n:
		arena.inimigos.criar(arena.diretor._sortear(tabela), c + Vector2.from_angle(TAU * k / n) * 230.0, arena.diretor.nivel())


## Cada jogador paga a PRÓPRIA recompensa (ou penalidade) uma vez por objetivo.
func _pagar() -> void:
	if _pago == seq or est < CUMPRIDO:
		return
	_pago = seq
	var d := tipo_def(id)
	var nome := str(d.get("nome", ""))
	if est == CUMPRIDO:
		var r := recompensa(id, _regiao)
		arena.ouro += int(r.ouro)
		arena.fase_stat.objetivo = {"nome": nome, "est": est, "ouro": int(r.ouro), "xp": int(r.xp)}
		arena.ganhar_xp(float(r.xp))
		if float(r.cura) > 0.0 and arena.jogador and not arena.caido:
			arena.jogador.curar(arena.stat("vida_max") * float(r.cura))
		arena.anunciar("OBJETIVO CUMPRIDO!", Color(0.5, 1.0, 0.6))
		arena.mensagem("%s: +%d ouro, +%d XP" % [nome, int(r.ouro), int(r.xp)], Color(0.7, 1.0, 0.7))
		Som.tocar("vitoria", 0.1, 1.3, -10)
	else:
		var perde := int(round(arena.ouro * float(d.get("falha", {}).get("ouro_perde", 0.0))))
		arena.ouro = maxi(0, arena.ouro - perde)
		arena.fase_stat.objetivo = {"nome": nome, "est": est, "ouro": -perde, "xp": 0}
		arena.anunciar("OBJETIVO FALHOU", Color(1.0, 0.45, 0.4))
		arena.mensagem("%s: -%d ouro%s" % [nome, perde, "" if tarde else " e uma horda vem aí"], Color(1.0, 0.7, 0.6))
		Som.tocar("derrota", 0.1, 1.2, -14)


## A fase acabou (o chefe caiu) com o objetivo em andamento: falha sem castigo extra. Só o anfitrião resolve.
func encerrar() -> void:
	if est == ANDAMENTO and _host():
		_resolver(FALHOU, true)
	_espera = -1.0


# ---------- rede ----------


## O estado inteiro do objetivo, pequeno, pro cliente (e pro teste comparar os dois lados).
func snapshot() -> Dictionary:
	var m := []
	for p in marcas:
		m.append(roundi((p as Vector2).x))
		m.append(roundi((p as Vector2).y))
	return {
		"seq": seq,
		"id": id,
		"est": est,
		"prog": snappedf(prog, 0.01),
		"alvo": snappedf(alvo, 0.01),
		"resta": snappedf(resta, 0.1),
		"x": roundi(pos.x),
		"y": roundi(pos.y),
		"m": m,
		"tarde": tarde
	}


func _mandar() -> void:
	if arena.online and _host():
		Rede.evento("objetivo", snapshot())


## Cliente: chegou o estado do anfitrião (já veio de fora da rede: tudo é conferido).
func aplicar(d: Dictionary) -> void:
	if _host():
		return
	var s := int(d.get("seq", 0))
	var tid := str(d.get("id", ""))
	var e := int(d.get("est", 0))
	if s <= _seq_limpo or s < seq or tipo_def(tid).is_empty() or e < NENHUM or e > FALHOU:
		return
	if s == seq and e < est:
		return  # o estado só anda pra frente: um pacote velho que chega atrasado não desfaz o que já se viu
	var novo := s > seq
	seq = s
	id = tid
	est = e
	prog = _num(d.get("prog", 0.0))
	alvo = _num(d.get("alvo", 0.0))
	resta = _num(d.get("resta", 0.0))
	pos = Vector2(_num(d.get("x", 0.0)), _num(d.get("y", 0.0)))
	tarde = bool(d.get("tarde", false))
	marcas = []
	var m = d.get("m", [])
	if m is Array:
		for i in range(0, mini(m.size() - 1, MAX_MARCAS * 2), 2):
			marcas.append(Vector2(_num(m[i]), _num(m[i + 1])))
	if novo and e == ANDAMENTO:
		var dd := tipo_def(id)
		arena.anunciar(str(dd.get("nome", "")), cor_de(id))
		arena.mensagem(str(dd.get("dica", "")), Color(0.9, 0.9, 1.0))
	if e >= CUMPRIDO:
		_linger = LINGER
		_pagar()
	queue_redraw()
	_topo.queue_redraw()


static func _num(v) -> float:
	var f := float(v) if (v is float or v is int) else 0.0
	return f if is_finite(f) else 0.0


# ---------- desenho (no mundo, embaixo dos inimigos: só a pira tem o que desenhar) ----------


func _draw() -> void:
	if id != "pira" or est == NENHUM:
		return
	var r := float(tipo_def(id).get("raio", 70))
	var cor := cor_de(id)
	var frac := clampf(prog / maxf(alvo, 0.01), 0.0, 1.0)
	var pulso := 0.5 + 0.5 * sin(_t * 4.0)
	var apagada := est == FALHOU
	var a := 0.35 if apagada else 1.0
	draw_circle(pos, r, Color(cor, (0.07 + 0.05 * frac + 0.03 * pulso) * a))
	draw_arc(pos, r, 0.0, TAU, 48, Color(cor, (0.35 + 0.2 * pulso) * a), 1.5)
	if frac > 0.0:
		draw_arc(pos, r - 3.0, -PI / 2, -PI / 2 + TAU * frac, 48, Color(1.0, 0.9, 0.5, a), 3.0)
	# a pira: lenha em cruz e uma chama que cresce com o progresso
	draw_line(pos + Vector2(-9, 4), pos + Vector2(9, -2), Color(0.35, 0.22, 0.12), 3.0)
	draw_line(pos + Vector2(9, 4), pos + Vector2(-9, -2), Color(0.3, 0.19, 0.1), 3.0)
	if not apagada:
		var h := 6.0 + 16.0 * frac + 2.0 * pulso
		var base := pos + Vector2(0, 1)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-7, 0), base + Vector2(0, -h), base + Vector2(7, 0)]), Color(1.0, 0.45, 0.1, 0.55 + 0.4 * frac))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-4, 0), base + Vector2(0, -h * 0.65), base + Vector2(4, 0)]), Color(1.0, 0.85, 0.3, 0.8))
