extends Node2D
const Perf := preload("res://scripts/hordas/perf.gd")
const Legib := preload("res://scripts/hordas/legibilidade.gd")
## O que cai no chão: gemas de XP, marmita (cura), Wi-Fi (puxa todo o XP) e baú.
## O ímã do jogador puxa tudo que está perto.

const ESCALA := 2.0
const MAX_GEMAS := 450

var arena: Node
var itens: Array = []      # {pos, tipo, valor, puxando, vel}
var _t := 0.0
var _rotulos := Node2D.new()   # etiquetas de drop (#72 marco 7): por cima dos bichos
var _cand: Array = []          # itens com direito a etiqueta, juntados no desenho das gemas
var _rot: Array = []           # o que será desenhado neste quadro
var _vis := Rect2()              # a tela em coordenadas do mundo (itens fora dela não são desenhados)
var rotulos_n := 0             # quantas etiquetas foram desenhadas no último quadro (o teste lê)


func gema(pos: Vector2, valor: float) -> void:
	if valor <= 0:
		return
	if itens.size() >= MAX_GEMAS:
		# muita gema no chão: junta numa que já existe
		for it in itens:
			if it.tipo == "gema" and not it.puxando:
				it.valor += valor
				return
	itens.append({"pos": pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)), "tipo": "gema", "valor": valor, "puxando": false, "vel": 0.0})


const RAIO_BAU_OBJETIVO := 90.0   # baú não nasce a menos disso de um alvo de objetivo (#123)


## Afasta `pos` dos alvos do objetivo do andar e da missão do chefe, pra o baú não cobrir o marcador.
func _longe_do_objetivo(pos: Vector2) -> Vector2:
	if arena == null or not ("objetivo" in arena) or arena.objetivo == null or arena.missao == null:
		return pos
	var alvos: Array = []
	if arena.objetivo.ativo():
		alvos.append_array(arena.objetivo.marcas)
	if arena.missao.ativo():
		alvos.append_array(arena.missao.marcas())
	for a in alvos:
		var d: Vector2 = pos - a
		if d.length() < RAIO_BAU_OBJETIVO:
			pos = a + (d.normalized() if d.length() > 0.5 else Vector2.RIGHT) * RAIO_BAU_OBJETIVO
	return pos


func soltar(pos: Vector2, tipo: String) -> void:
	if tipo == "bau":
		pos = _longe_do_objetivo(pos)
	itens.append({"pos": pos, "tipo": tipo, "valor": 0, "puxando": false, "vel": 0.0, "t0": _t})


func puxar_tudo() -> void:
	for it in itens:
		if it.tipo == "gema":
			it.puxando = true


func limpar() -> void:
	itens.clear()


func atualizar(dt: float) -> void:
	var _pp := Perf.ini()
	atualizar_i(dt)
	Perf.fim("col_a", _pp)


func atualizar_i(dt: float) -> void:
	_t += dt
	var jog: Node2D = arena.jogador
	var alvo: Vector2 = jog.centro()
	var ima: float = 70.0 * arena.stat("ima")
	_cand.clear()
	_vis = get_canvas_transform().affine_inverse() * get_viewport_rect() if is_inside_tree() else Rect2()
	var idx := 0
	while idx < itens.size():   # sem duplicate() nem erase() (O(n) por item, com 450 gemas no chão pesava todo quadro)
		var it: Dictionary = itens[idx]
		idx += 1
		if it.tipo != "gema" or it.valor >= 20.0:
			_cand.append(it)   # só quem pode ter etiqueta (as gemas pequenas, a maioria, só pagam este teste)
		var dist: float = it.pos.distance_to(alvo)
		if not it.puxando and dist < ima and it.tipo != "bau":
			it.puxando = true
			it.vel = -140.0   # dá um pulinho pra trás antes de vir
		if it.puxando:
			it.vel += 900.0 * dt
			if it.vel < 0:
				it.pos -= (alvo - it.pos).normalized() * -it.vel * dt
			else:
				it.pos = it.pos.move_toward(alvo, it.vel * dt)
		if dist < 14:
			idx -= 1
			itens.remove_at(idx)
			_pegar(it)
	_rot = rotulos_do_quadro(alvo)
	rotulos_n = _rot.size()
	queue_redraw()
	_rotulos.queue_redraw()


func _pegar(it: Dictionary) -> void:
	match it.tipo:
		"gema":
			arena.ganhar_xp(it.valor)
			Som.tocar("blip", 0.04, randf_range(1.3, 1.6), -12)
		"marmita":
			arena.jogador.curar(float(Dados.json("fase").get("drops", {}).get("cura_marmita", 30)))
			Som.tocar("plim", 0.1, 1.2)
			_avisar("marmita")
		"wifi":
			puxar_tudo()
			Som.tocar("plim", 0.1, 1.5)
			_avisar("wifi")
		"bau":
			arena.abrir_bau()
		"fragmento":
			arena.descobertas.pegou_fragmento()


## A mensagem de quando pega um coletável (texto e cor no coletaveis.json).
func _avisar(tipo: String) -> void:
	var c: Dictionary = Dados.json("coletaveis").get(tipo, {})
	var cor: Array = c.get("cor", [1.0, 1.0, 1.0])
	arena.mensagem(str(c.get("msg", tipo)), Color(float(cor[0]), float(cor[1]), float(cor[2])))


func _textura(it: Dictionary) -> Texture2D:
	match it.tipo:
		"gema":
			if it.valor >= 20:
				return Dados.tex("gema_3")
			elif it.valor >= 4:
				return Dados.tex("gema_2")
			return Dados.tex("gema_1")
		"marmita", "wifi":   # o que aparece no chão vem do coletaveis.json (#65); o tipo interno continua o mesmo
			return Dados.tex(str(Dados.json("coletaveis").get(it.tipo, {}).get("sprite", it.tipo)))
		"bau":
			return Dados.tex("bau")
		"fragmento":
			return Dados.tex("gema_3")   # só pra passar no teste de nulo; o losango é desenhado à mão em _draw
	return null


func _draw() -> void:
	var _pp := Perf.ini()
	_draw_i()
	Perf.fim("col_d", _pp)


func _ready() -> void:
	_rotulos.z_index = 10
	_rotulos.draw.connect(_desenhar_rotulos)
	add_child(_rotulos)


## Etiquetas: só dos itens que valem (baú, comida, berrante, fragmento, gema grande), e só perto ou logo que caem.
## Devolve [item, etiqueta, opacidade] (no máximo `max`). Pura: o teste chama sem desenhar.
func rotulos_do_quadro(alvo: Vector2) -> Array:
	var r: Array = []
	var c := Legib.cfg()
	var lim := int(c.get("max", 8))
	var perto := float(c.get("perto", 110.0))
	for it in _cand:
		var e: Dictionary = Legib.etiqueta(str(it.tipo), float(it.valor))
		var idade: float = _t - float(it.get("t0", -99.0))
		var dist: float = it.pos.distance_to(alvo)
		if Legib.etiqueta_visivel(e, idade, dist):
			var fim: float = 1.0 if dist <= perto else clampf((float(c.get("nasce", 4.0)) - idade) * 2.0, 0.0, 1.0)   # a de "recém-caído" esmaece
			r.append([it, e, fim])
			if r.size() >= lim:
				break
	return r


func _desenhar_rotulos() -> void:
	var usados: Array = []   # etiquetas juntas sobem uma sobre a outra em vez de se sobrepor (poucas: no máximo `max`)
	for r in _rot:
		var p: Vector2 = r[0].pos
		var subir := 0.0
		for q: Vector2 in usados:
			if absf(q.x - p.x) < 70.0 and absf(q.y - (p.y - subir)) < 11.0:
				subir += 11.0
		usados.append(Vector2(p.x, p.y - subir))
		Legib.desenhar_etiqueta(_rotulos, p - Vector2(0, subir), r[1], _t, r[2])


func _draw_i() -> void:
	var vis := _vis.grow(40.0)
	for it in itens:
		if vis.has_area() and not vis.has_point(it.pos):
			continue   # fora da tela nem desenha (a maioria das gemas acumuladas)
		var tex := _textura(it)
		if tex == null:
			continue
		var sz := tex.get_size() * ESCALA
		var flutua := 0.0
		if it.tipo != "gema":
			flutua = sin(_t * 4.0 + it.pos.x) * 2.0
		if it.tipo == "bau":
			draw_circle(it.pos, 18 + sin(_t * 5.0) * 3, Color(1, 0.85, 0.3, 0.18))
		if it.tipo == "fragmento":   # losango cobalto que pulsa (sem PNG novo)
			var c := Vector2(it.pos.x, it.pos.y + flutua - 6.0)
			var r := 9.0 + sin(_t * 6.0) * 1.5
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)])
			draw_circle(it.pos, 20 + sin(_t * 5.0) * 3, Color(0.4, 0.6, 1.0, 0.2))
			draw_colored_polygon(pts, Color(0.45, 0.7, 1.0))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.9, 0.97, 1.0), 1.5)
			continue
		draw_texture_rect(tex, Rect2(it.pos - sz / 2 + Vector2(0, flutua), sz), false)
