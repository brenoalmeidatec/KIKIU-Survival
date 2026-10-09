extends Node2D
## Missão do chefe (#112, item 2): o chefe da fase não cai do céu, o jogador o chama cumprindo uma missão em pontos de interesse
## do mapa. Dados em dados/missoes_chefe.json (tipo por chefe, quantidades, raios, tempos). Tipos:
##  fragmentos (coletar N e levar ao altar), pilares (ficar perto de cada um até despertar), selos (matar N elites marcados),
##  invocar (só um altar: entrar e segurar CONFIRMAR).
## Cumprida, o chefe nasce na hora perto do ponto de invocação (diretor.chamar_chefe). NUNCA trava a corrida: passou da
## duração + tolerância sem cumprir, a missão falha e o diretor chama o chefe do jeito de sempre (de fora da tela).
## Só o anfitrião (ou o jogo solo) roda a missão.
## TODO online: mandar o estado aos clientes (evento como o "objetivo" do objetivos.gd) pra eles verem os marcadores e ajudarem.

const Sorte := preload("res://scripts/hordas/sorte.gd")
const Objetivos := preload("res://scripts/hordas/objetivos.gd")

const NENHUM := 0
const ANDAMENTO := 1
const CUMPRIDO := 2
const FALHOU := 3
const LINGER := 3.0          # s que o resultado fica no HUD

var arena: Node
var id := ""                 # tipo da missão desta fase ("" = sem missão)
var est := NENHUM
var etapa := 0               # fragmentos: 0 coletando, 1 levando ao altar
var pontos: Array = []       # [{pos: Vector2, ok: bool, prog: float}] fragmentos / pilares
var altar := Vector2.ZERO
var tem_altar := false
var seg := 0.0               # invocar / entrega: quanto já segurou
var bot_segurar := false     # teste de imagem: segura sozinho sem ser robô
var ultimo := Vector2.ZERO   # último ponto tocado: de onde o chefe sai
var _ids: Array = []         # selos: ids dos elites que ainda vivem
var _selos_total := 0
var _selos_mortos := 0
var _pendente := ""
var _linger := 0.0
var _t := 0.0


# ---------- dados (funções puras: o teste usa) ----------

static func cfg() -> Dictionary:
	return Dados.json("missoes_chefe")


static func tipo_def(tid: String) -> Dictionary:
	var d = cfg().get("tipos", {}).get(tid, {})
	return d if d is Dictionary else {}


## Que missão esta fase tem pro chefe dela? "" = nenhuma. Igual em todo cliente (a semente é a mesma).
static func escolher(f: Dictionary, andar_global: int) -> String:
	if f.has("missao"):   # a fase manda: "tipo" força, false apaga
		return str(f.missao) if f.missao is String and not tipo_def(str(f.missao)).is_empty() else ""
	var c := cfg()
	var lista: Array = c.get("por_chefe", {}).get(str(f.get("chefe", "")), c.get("padrao", []))
	lista = lista.filter(func(t): return not tipo_def(str(t)).is_empty())
	if lista.is_empty():
		return ""
	return str(lista[Sorte.criar("missao_chefe", andar_global).randi() % lista.size()])


static func cor_de(tid: String) -> Color:
	var c = tipo_def(tid).get("cor", [1, 1, 1])
	return Color(float(c[0]), float(c[1]), float(c[2]))


## Pilar: carga sobe com dt se alguém está dentro; senão cai. Limitada a [0, total].
static func carregar(prog: float, dentro: bool, dt: float, total: float, decai: float) -> float:
	if dentro:
		return minf(total, prog + dt)
	return maxf(0.0, prog - decai * dt)


func _host() -> bool:
	return not arena.inimigos.espelho


func ativo() -> bool:
	return est == ANDAMENTO


## O diretor pergunta: seguro o chefe? Só enquanto a missão está rolando e a tolerância não acabou.
func segura_chefe() -> bool:
	if est != ANDAMENTO:
		return false
	var d = arena.diretor
	return d.t_fase < d.duracao() + float(cfg().get("tolerancia", 75.0))


## O HUD pergunta: algo a mostrar? (andamento, ou o resultado nos últimos LINGER segundos)
func visivel() -> bool:
	return id != "" and (est == ANDAMENTO or (est != NENHUM and _linger > 0.0))


# ---------- ciclo de vida ----------

## Andar novo (todo mundo chama). O anfitrião decide se há missão e a missão aparece 'inicio' s depois.
var _topo := Node2D.new()    # camada por cima de inimigos, poderes e baús (#123)


func _ready() -> void:
	_topo.z_index = 50
	_topo.draw.connect(_desenhar_topo)
	add_child(_topo)


func _desenhar_topo() -> void:
	if id == "" or est != ANDAMENTO:
		return
	var cor := cor_de(id)
	for p in marcas():
		Objetivos.marca_topo(_topo, p, cor, _t, 24.0 if p == altar else 20.0)


func nova_fase(f: Dictionary, andar_global: int) -> void:
	_zerar()
	_pendente = escolher(f, andar_global)   # (só o anfitrião/solo a inicia, em atualizar: o espelho do online ainda não existe aqui)


func _zerar() -> void:
	id = ""
	est = NENHUM
	etapa = 0
	pontos = []
	tem_altar = false
	seg = 0.0
	bot_segurar = false
	_ids = []
	_selos_total = 0
	_selos_mortos = 0
	_pendente = ""
	_linger = 0.0
	queue_redraw()


func atualizar(dt: float) -> void:
	_t += dt
	if _linger > 0.0:
		_linger = maxf(0.0, _linger - dt)
	if est != NENHUM:
		queue_redraw()
		_topo.queue_redraw()
	if not _host():
		return
	var df = arena.diretor
	if est == NENHUM:
		if _pendente != "" and df.t_fase >= float(cfg().get("inicio", 8.0)) and not df.final_chamado and not arena.caido:
			_iniciar(_pendente)
		return
	if est != ANDAMENTO:
		return
	if df.final_chamado:
		_resolver(FALHOU, true)   # o chefe chegou por outro caminho (tempo, teste): a missão perde o sentido
		return
	if df.t_fase >= df.duracao() + float(cfg().get("tolerancia", 75.0)):
		_resolver(FALHOU)
		return
	var d := tipo_def(id)
	var gente := _jogadores()
	match id:
		"fragmentos":
			if etapa == 0:
				for p in pontos:
					if not p.ok and _perto(gente, p.pos, float(d.get("raio", 18))):
						p.ok = true
						ultimo = p.pos
						Som.tocar("plim", 0.05, 1.2)
						arena.efeitos.explodir(p.pos, cor_de(id), 5, 50.0)
						if _feitos() >= pontos.size():
							etapa = 1
							arena.mensagem("Todos os fragmentos! Leve ao altar.", cor_de(id))
			else:
				var ad: Dictionary = d.get("altar", {})
				if _perto(gente, altar, float(ad.get("raio", 34))):
					ultimo = altar
					_concluir()
		"pilares":
			var total := float(d.get("segundos", 3.5))
			for p in pontos:
				if p.ok:
					continue
				p.prog = carregar(p.prog, _perto(gente, p.pos, float(d.get("raio", 46))), dt, total, float(d.get("decai", 0.5)))
				if p.prog >= total:
					p.ok = true
					ultimo = p.pos
					Som.tocar("plim", 0.05, 0.9)
					arena.efeitos.explodir(p.pos, cor_de(id), 8, 70.0)
			if _feitos() >= pontos.size():
				_concluir()
		"invocar":
			var dentro := _perto(gente, altar, float(d.get("raio", 34)))
			var segurando: bool = arena.bot or bot_segurar or Input.is_action_pressed("confirmar")
			var total2 := float(d.get("segurar", 1.5))
			seg = carregar(seg, dentro and segurando, dt, total2, 2.0)
			if seg >= total2:
				ultimo = altar
				_concluir()
		"selos":
			for i in _ids.duplicate():
				var v = arena.inimigos.por_id.get(i)
				if v == null or v.hp <= 0.0:
					_ids.erase(i)
					_selos_mortos += 1
			if _selos_mortos >= _selos_total:
				_concluir()


func _feitos() -> int:
	var n := 0
	for p in pontos:
		if p.ok:
			n += 1
	return n


static func _perto(gente: Array, pos: Vector2, raio: float) -> bool:
	for g in gente:
		if (g as Vector2).distance_squared_to(pos) <= raio * raio:
			return true
	return false


## Posições (mundo) de quem pode tocar nos pontos: os jogadores em pé.
func _jogadores() -> Array:
	var res := []
	if arena.online:
		for a in arena.online.alvos():
			res.append(a[0])
	elif not arena.caido:
		res.append(arena.jogador.centro())
	return res


## Anfitrião: a missão aparece, em volta de quem está jogando.
func _iniciar(tid: String) -> void:
	var d := tipo_def(tid)
	if d.is_empty():
		return
	id = tid
	est = ANDAMENTO
	etapa = 0
	pontos = []
	_ids = []
	seg = 0.0
	_linger = 0.0
	var c: Vector2 = arena.diretor._referencia()[0]
	var rng := Sorte.criar("missao_chefe_pos", arena.diretor.fase_idx)
	var dist: Array = d.get("distancia", [200, 320])
	var n := int(d.get("quantos", 1))
	var a0 := rng.randf() * TAU
	match tid:
		"fragmentos", "pilares":
			for i in n:
				var p := c + Vector2.from_angle(a0 + TAU * i / n + rng.randf_range(-0.3, 0.3)) * rng.randf_range(float(dist[0]), float(dist[1]))
				pontos.append({"pos": p, "ok": false, "prog": 0.0})
			if tid == "fragmentos":
				var ad: Dictionary = d.get("altar", {})
				var ar: Array = ad.get("distancia", [160, 260])
				altar = c + Vector2.from_angle(a0 + PI / n + 0.5) * rng.randf_range(float(ar[0]), float(ar[1]))
				tem_altar = true
		"invocar":
			altar = c + Vector2.from_angle(a0) * rng.randf_range(float(dist[0]), float(dist[1]))
			tem_altar = true
		"selos":
			var tabela: Array = arena.diretor._disponiveis()
			for i in n:
				var tipo := str(d.get("inimigo", ""))
				if tipo == "" and not tabela.is_empty():
					tipo = arena.diretor._sortear(tabela)
				var p2 := c + Vector2.from_angle(a0 + TAU * i / n + rng.randf_range(-0.3, 0.3)) * rng.randf_range(float(dist[0]), float(dist[1]))
				var v = arena.inimigos.criar(tipo, p2, arena.diretor.nivel(), true)
				if v:
					_ids.append(v.id)
			_selos_total = _ids.size()
			_selos_mortos = 0
			ultimo = c
			if _selos_total == 0:
				id = ""
				est = NENHUM
				return
	ultimo = c
	arena.anunciar(str(d.get("nome", "")), cor_de(tid))
	arena.mensagem(str(d.get("dica", "")), Color(0.9, 0.9, 1.0))


## Cumpriu: o chefe nasce perto do ponto de invocação.
func _concluir() -> void:
	if est != ANDAMENTO:
		return
	est = CUMPRIDO
	_linger = LINGER
	var onde := ultimo
	if id == "selos":
		onde = arena.jogador.centro() + Vector2.from_angle(randf() * TAU) * 220.0   # sem ponto fixo: fora do alcance do braço, perto do grupo
	else:
		onde = ultimo + Vector2.from_angle(randf() * TAU) * 130.0
	Som.tocar("vitoria", 0.1, 1.3, -10)
	arena.anunciar("MISSÃO CUMPRIDA!", Color(0.5, 1.0, 0.6))
	arena.diretor.chamar_chefe(onde)
	queue_redraw()


func _resolver(resultado: int, soft := false) -> void:
	if est != ANDAMENTO:
		return
	est = resultado
	_linger = LINGER
	for i in _ids:
		arena.inimigos.remover_id(i)   # o elite com selo some quando a missão falha
	_ids = []
	if not soft:
		arena.mensagem("O chefe perdeu a paciência e vem sozinho!", Color(1.0, 0.7, 0.6))
	queue_redraw()


## A fase acabou: limpa (só o anfitrião mexe nos inimigos).
func encerrar() -> void:
	if est == ANDAMENTO and _host():
		_resolver(FALHOU, true)
	_pendente = ""


# ---------- HUD / robô ----------

## Posições dos pontos de interesse que ainda importam (setas do HUD e alvo do robô).
func marcas() -> Array:
	var res := []
	if est != ANDAMENTO:
		return res
	match id:
		"fragmentos":
			if etapa == 0:
				for p in pontos:
					if not p.ok:
						res.append(p.pos)
			else:
				res.append(altar)
		"pilares":
			for p in pontos:
				if not p.ok:
					res.append(p.pos)
		"invocar":
			res.append(altar)
		"selos":
			for i in _ids:
				var v = arena.inimigos.por_id.get(i)
				if v and v.hp > 0.0:
					res.append(v.pos)
	return res


## [título, detalhe, fração 0..1] pro HUD.
func texto() -> Array:
	var d := tipo_def(id)
	var tit := str(d.get("nome", ""))
	if est == CUMPRIDO:
		return [tit, "CUMPRIDA", 1.0]
	if est == FALHOU:
		return [tit, "FALHOU", 0.0]
	var det := ""
	var fr := 0.0
	var fmt := str(d.get("texto", "%d/%d"))
	match id:
		"fragmentos":
			det = str(d.get("texto_entrega", "")) if etapa == 1 else fmt % [_feitos(), pontos.size()]
			fr = float(_feitos()) / maxf(1.0, pontos.size())
		"pilares":
			det = fmt % [_feitos(), pontos.size()]
			fr = float(_feitos()) / maxf(1.0, pontos.size())
		"selos":
			det = fmt % [_selos_mortos, _selos_total]
			fr = float(_selos_mortos) / maxf(1.0, _selos_total)
		"invocar":
			det = str(d.get("texto_entrega", ""))
			fr = seg / maxf(0.1, float(d.get("segurar", 1.5)))
	return [tit, det, clampf(fr, 0.0, 1.0)]


## Pro robô (--bot): pra onde ir. null = sem alvo.
func alvo_bot(de: Vector2):
	var m := marcas()
	if m.is_empty():
		return null
	var melhor: Vector2 = m[0]
	for p in m:
		if (p as Vector2).distance_squared_to(de) < melhor.distance_squared_to(de):
			melhor = p
	return melhor


# ---------- desenho (no mundo) ----------

func _draw() -> void:
	if id == "" or est == NENHUM:
		return
	var cor := cor_de(id)
	var d := tipo_def(id)
	var apagada := est == FALHOU
	var a := 0.3 if apagada else 1.0
	var pulso := 0.5 + 0.5 * sin(_t * 3.0)
	match id:
		"fragmentos":
			for p in pontos:
				if p.ok:
					continue
				var q: Vector2 = p.pos + Vector2(0, -3.0 * sin(_t * 2.5 + p.pos.x))
				draw_circle(q, 13.0 + 2.0 * pulso, Color(cor, 0.16 * a))
				draw_colored_polygon(PackedVector2Array([q + Vector2(0, -8), q + Vector2(5, 0), q + Vector2(0, 8), q + Vector2(-5, 0)]), Color(cor, a))
				draw_colored_polygon(PackedVector2Array([q + Vector2(0, -4), q + Vector2(2, 0), q + Vector2(0, 4), q + Vector2(-2, 0)]), Color(1, 1, 1, 0.9 * a))
			_altar(cor, a, pulso, str(d.get("altar", {}).get("nome", "ALTAR")), float(d.get("altar", {}).get("raio", 34)), etapa == 1)
		"pilares":
			var total := float(d.get("segundos", 3.5))
			var r := float(d.get("raio", 46))
			for p in pontos:
				var fr := 1.0 if p.ok else clampf(p.prog / total, 0.0, 1.0)
				draw_circle(p.pos, r, Color(cor, (0.05 + 0.05 * fr) * a))
				draw_arc(p.pos, r, 0.0, TAU, 40, Color(cor, (0.25 + 0.2 * pulso * (1.0 - fr)) * a), 1.0)
				var base: Vector2 = p.pos
				draw_colored_polygon(PackedVector2Array([base + Vector2(-6, 4), base + Vector2(-4, -22), base + Vector2(4, -22), base + Vector2(6, 4)]), Color(0.3, 0.27, 0.3, a))
				var luz := Color(cor, (0.25 + 0.75 * fr) * a)
				draw_colored_polygon(PackedVector2Array([base + Vector2(-3, -6), base + Vector2(-2, -20), base + Vector2(2, -20), base + Vector2(3, -6)]), luz)
				draw_circle(base + Vector2(0, -26), 3.0 + 3.0 * fr, Color(cor, (0.4 + 0.6 * fr) * a))
				if fr > 0.0 and not p.ok:
					draw_arc(base, r - 3.0, -PI / 2, -PI / 2 + TAU * fr, 40, Color(1.0, 0.9, 0.5, a), 3.0)
		"invocar":
			_altar(cor, a, pulso, "INVOCAR", float(d.get("raio", 34)), true)
			if seg > 0.0:
				draw_arc(altar, 36.0, -PI / 2, -PI / 2 + TAU * clampf(seg / float(d.get("segurar", 1.5)), 0.0, 1.0), 40, Color(1, 0.9, 0.4), 3.0)
		"selos":
			for i in _ids:
				var v = arena.inimigos.por_id.get(i)
				if v and v.hp > 0.0:
					var rot := _t * 1.5
					draw_arc(v.pos, 16.0, rot, rot + TAU * 0.8, 20, Color(cor, 0.9), 1.5)
					draw_arc(v.pos, 20.0, -rot, -rot + TAU * 0.6, 20, Color(cor, 0.5), 1.0)


func _altar(cor: Color, a: float, pulso: float, nome: String, raio: float, ativo_: bool) -> void:
	var p := altar
	var k := 1.0 if ativo_ else 0.45
	draw_circle(p, raio * 1.5, Color(cor, 0.1 * a * k))
	draw_circle(p, raio, Color(0.1, 0.07, 0.14, 0.9 * a))
	draw_arc(p, raio, 0.0, TAU, 40, Color(cor, (0.5 + 0.3 * pulso) * a * k), 1.5)
	for i in 3:
		var ang := _t * (0.6 + i * 0.3) * (1.0 if i % 2 == 0 else -1.0) + i * 2.1
		draw_arc(p, raio * (0.8 - i * 0.2), ang, ang + PI, 16, Color(cor, 0.8 * a * k), 1.5)
	draw_rect(Rect2(p + Vector2(-5, -10), Vector2(10, 12)), Color(0.35, 0.3, 0.38, a))
	draw_rect(Rect2(p + Vector2(-7, -13), Vector2(14, 4)), Color(0.5, 0.45, 0.52, a))
	draw_string(Dados.fonte, p + Vector2(-60, -raio - 8.0), nome, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color(cor, 0.95 * a * k))
