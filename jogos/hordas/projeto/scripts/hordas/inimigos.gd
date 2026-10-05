extends Node2D
## Todos os inimigos da partida num lugar só (sem um nó por inimigo, pra caber 500 na tela).
## Cada inimigo é um objeto leve (classe V). Uma grade espacial acha quem está perto rápido.
## Também cuida dos tiros dos inimigos.

const ESCALA := 2.0        # a arte gerada é desenhada 2x
const CELULA := 48.0
const LONGE := 720.0       # mais longe que isso do jogador = reaparece do outro lado

class V:
	var id := 0
	var tipo := ""
	var d: Dictionary            # dados do inimigos.json
	var tex: Texture2D
	var tam := Vector2.ZERO      # tamanho de um quadro (sem escala)
	var pos := Vector2.ZERO
	var hp := 1.0
	var hpmax := 1.0
	var dano := 1.0
	var vel := 40.0
	var raio := 8.0
	var esc := 1.0
	var kb := Vector2.ZERO
	var flash := 0.0
	var lento := 0.0
	var elite := false
	var chefe := false
	var t_atira := 0.0
	var t_anel := 0.0
	var t_invoca := 0.0
	var t_inv := 0.0
	var estado := 0              # 0 normal, 1 se preparando pra investida, 2 investindo
	var t_estado := 0.0
	var dir_inv := Vector2.ZERO
	# comportamentos (lidos uma vez do json, pra não procurar no dicionário todo quadro)
	var distancia := 0.0
	var investida := 0.0
	var atira := 0.0
	var anel := 0.0
	var invoca: Dictionary = {}
	var pesado := false

var arena: Node
var lista: Array = []
var tiros: Array = []          # {pos, vel, dano, tex, vida}
var _grade := {}
var _prox_id := 1
var _t := 0.0
var _quadro := 0
var _ordem: Array = []


func criar(tipo: String, pos: Vector2, nivel := 1, elite := false) -> V:
	var dd: Dictionary = Dados.json("inimigos").get(tipo, {})
	if dd.is_empty():
		return null
	var fase: Dictionary = Dados.json("fase").get("dificuldade", {})
	var v := V.new()
	v.id = _prox_id
	_prox_id += 1
	v.tipo = tipo
	v.d = dd
	v.tex = Dados.tex(str(dd.get("sprite", "inimigo_bug")))
	v.tam = Vector2(v.tex.get_width() / 3.0, v.tex.get_height())
	v.pos = pos
	v.chefe = bool(dd.get("chefe", false))
	var mult_vida := 1.0 + float(fase.get("vida_por_nivel", 0.2)) * (nivel - 1)
	if v.chefe:
		mult_vida = 1.0 + 0.08 * (nivel - 1)
	v.hpmax = float(dd.get("vida", 10)) * mult_vida
	v.dano = float(dd.get("dano", 5)) * (1.0 + float(fase.get("dano_por_nivel", 0.08)) * (nivel - 1))
	v.vel = float(dd.get("velocidade", 40)) * randf_range(0.9, 1.1)
	v.raio = float(dd.get("raio", 8))
	if elite and not v.chefe:
		v.elite = true
		v.hpmax *= 6.0
		v.esc = 1.4
		v.raio *= 1.4
		v.dano *= 1.5
	v.hp = v.hpmax
	v.distancia = float(dd.get("distancia", 0.0))
	v.investida = float(dd.get("investida", 0.0))
	v.atira = float(dd.get("atira", 0.0))
	v.anel = float(dd.get("anel", 0.0))
	v.invoca = dd.get("invoca", {}) if dd.get("invoca") is Dictionary else {}
	v.pesado = bool(dd.get("pesado", false))
	v.t_atira = randf_range(0.5, float(dd.get("atira", 3.0)))
	v.t_anel = float(dd.get("anel", 0.0))
	v.t_inv = float(dd.get("investida", 0.0))
	v.t_invoca = float(dd.get("invoca", {}).get("a_cada", 0.0)) if dd.get("invoca") is Dictionary else 0.0
	lista.append(v)
	return v


func vivos() -> int:
	return lista.size()


func _remover(v: V) -> void:
	var i := lista.find(v)
	if i >= 0:
		lista[i] = lista[lista.size() - 1]
		lista.pop_back()


func limpar() -> void:
	lista.clear()
	tiros.clear()
	_ordem.clear()


## Dá dano. Retorna true se matou.
func ferir(v: V, valor: float, empurrao := Vector2.ZERO, arma := "") -> bool:
	if v.hp <= 0:
		return false
	var crit: bool = randf() < arena.stat("critico")
	if crit:
		valor *= arena.stat("critico_mult")
	v.hp -= valor
	v.flash = 0.09
	var peso := 4.0 if v.pesado else 1.0
	if v.chefe:
		peso = 12.0
	v.kb += empurrao / peso
	arena.registrar_dano(arma, valor, v.pos, crit)
	if v.hp <= 0:
		_remover(v)
		arena.inimigo_morreu(v)
		return true
	return false


# ---------- buscas ----------

func _celula(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELULA), floori(p.y / CELULA))


func no_circulo(c: Vector2, r: float) -> Array:
	var res := []
	var a := _celula(c - Vector2(r + 40, r + 40))
	var b := _celula(c + Vector2(r + 40, r + 40))
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var cel = _grade.get(Vector2i(cx, cy))
			if cel == null:
				continue
			for v: V in cel:
				var rr: float = r + v.raio
				if v.pos.distance_squared_to(c) <= rr * rr:
					res.append(v)
	return res


func mais_perto(p: Vector2, maximo := 99999.0) -> V:
	var melhor: V = null
	var md := maximo * maximo
	for v in lista:
		var dd: float = v.pos.distance_squared_to(p)
		if dd < md:
			md = dd
			melhor = v
	return melhor


## Os n mais perto (pra armas com vários tiros).
func n_mais_perto(p: Vector2, n: int, maximo := 400.0) -> Array:
	var perto := no_circulo(p, maximo)
	perto.sort_custom(func(a, b): return a.pos.distance_squared_to(p) < b.pos.distance_squared_to(p))
	return perto.slice(0, n)


func aleatorio_na_tela(centro: Vector2) -> V:
	var na_tela := no_circulo(centro, 260)
	return na_tela.pick_random() if not na_tela.is_empty() else null


# ---------- atualização ----------

func atualizar(dt: float, jog: Node2D) -> void:
	_t += dt
	_quadro += 1
	var alvo: Vector2 = jog.centro()
	# grade
	_grade.clear()
	for v: V in lista:
		var c := _celula(v.pos)
		if _grade.has(c):
			_grade[c].append(v)
		else:
			_grade[c] = [v]

	for v: V in lista.duplicate():
		if v.hp <= 0:
			continue
		v.flash = maxf(0.0, v.flash - dt)
		v.lento = maxf(0.0, v.lento - dt)
		var para: Vector2 = alvo - v.pos
		var dist: float = para.length()
		var dir: Vector2 = para / dist if dist > 0.01 else Vector2.ZERO
		var vel: float = v.vel * (0.45 if v.lento > 0 else 1.0)
		var mov: Vector2 = dir * vel

		# quem atira mantém distância
		if v.distancia > 0:
			var dd := v.distancia
			if dist < dd * 0.8:
				mov = -dir * vel * 0.6
			elif dist < dd:
				mov = Vector2.ZERO
		# investida: para, treme e corre reto
		if v.investida > 0:
			match v.estado:
				0:
					v.t_inv -= dt
					if v.t_inv <= 0 and dist < 360:
						v.estado = 1
						v.t_estado = 0.7
						v.dir_inv = dir
				1:
					mov = Vector2.ZERO
					v.t_estado -= dt
					if v.t_estado <= 0:
						v.estado = 2
						v.t_estado = 0.6
						Som.tocar("whoosh", 0.1, 0.7)
				2:
					mov = v.dir_inv * vel * 5.0
					v.t_estado -= dt
					if v.t_estado <= 0:
						v.estado = 0
						v.t_inv = v.investida
		if v.atira > 0:
			v.t_atira -= dt
			if v.t_atira <= 0 and dist < 330:
				v.t_atira = v.atira
				_atirar(v, dir)
		if v.anel > 0:
			v.t_anel -= dt
			if v.t_anel <= 0 and dist < 400:
				v.t_anel = v.anel
				_anel(v)
		if not v.invoca.is_empty():
			v.t_invoca -= dt
			if v.t_invoca <= 0:
				var inv: Dictionary = v.invoca
				v.t_invoca = float(inv.get("a_cada", 5.0))
				for i in int(inv.get("quantos", 4)):
					var a := TAU * i / float(inv.get("quantos", 4))
					criar(str(inv.get("tipo", "bug")), v.pos + Vector2.from_angle(a) * (v.raio + 20), arena.diretor.nivel())

		# separação dos vizinhos (não empilham); cada inimigo calcula a cada 2 quadros
		var sep := Vector2.ZERO
		var c := _celula(v.pos)
		var checados := 0 if (v.id + _quadro) % 2 == 0 else 99
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var cel = _grade.get(c + Vector2i(ox, oy))
				if cel == null or checados > 20:
					continue
				for o: V in cel:
					checados += 1
					if checados > 20:
						break
					if o == v:
						continue
					var dif: Vector2 = v.pos - o.pos
					var rr: float = v.raio + o.raio
					var d2 := dif.length_squared()
					if d2 < rr * rr and d2 > 0.0001:
						var dl := sqrt(d2)
						sep += dif / dl * (rr - dl)
		if v.chefe:
			sep *= 0.1
		v.pos += (mov + v.kb) * dt + sep * minf(1.0, dt * 24.0)
		v.kb *= exp(-9.0 * dt)

		# encostou no jogador
		if dist < v.raio + 8:
			jog.sofrer(v.dano, v.tipo)
		# muito longe: volta pra perto (do lado de onde o jogador está indo)
		if dist > LONGE and not v.chefe:
			var a: float = jog.direcao_mov().angle() + randf_range(-1.0, 1.0)
			if jog.direcao_mov() == Vector2.ZERO:
				a = randf() * TAU
			v.pos = alvo + Vector2.from_angle(a) * randf_range(380, 440)

	# tiros dos inimigos
	for t in tiros.duplicate():
		t.pos += t.vel * dt
		t.vida -= dt
		if t.pos.distance_squared_to(alvo) < 100.0:
			jog.sofrer(t.dano, "tiro")
			tiros.erase(t)
		elif t.vida <= 0:
			tiros.erase(t)
	queue_redraw()


func _atirar(v: V, dir: Vector2) -> void:
	var tiro: Dictionary = v.d.get("tiro", {})
	_novo_tiro(v.pos, dir * float(tiro.get("velocidade", 100)), float(tiro.get("dano", 6)), str(tiro.get("sprite", "proj_email")))


func _anel(v: V) -> void:
	var tiro: Dictionary = v.d.get("tiro", {})
	var n := int(tiro.get("quantos", 10))
	var giro := randf() * TAU
	for i in n:
		var dir := Vector2.from_angle(giro + TAU * i / n)
		_novo_tiro(v.pos, dir * float(tiro.get("velocidade", 90)), float(tiro.get("dano", 8)), str(tiro.get("sprite", "proj_email")))
	Som.tocar("tremor", 0.3, 1.3, -6)


func _novo_tiro(pos: Vector2, vel: Vector2, dano: float, sprite: String) -> void:
	if tiros.size() > 300:
		return
	tiros.append({"pos": pos, "vel": vel, "dano": dano, "tex": Dados.tex(sprite), "vida": 5.0})


# ---------- desenho ----------

func _draw() -> void:
	var jx: float = arena.jogador.position.x if arena and arena.jogador else 0.0
	# ordenar por altura (quem está mais embaixo fica na frente) custa caro: refaz a cada 4 quadros
	if _quadro % 4 == 0 or _ordem.size() < lista.size() / 2:
		_ordem = lista.duplicate()
		_ordem.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for v: V in _ordem:
		if v.hp <= 0:
			continue
		var s: Vector2 = v.tam * ESCALA * v.esc
		var quadro := 2 if v.flash > 0 else (int(_t * 4.0 + v.id) % 2)
		if v.estado == 1:
			quadro = 2 if int(_t * 20) % 2 == 0 else 0
		var base: Vector2 = v.pos - Vector2(s.x / 2, s.y * 0.6)
		draw_rect(Rect2(v.pos.x - s.x * 0.35, v.pos.y + s.y * 0.32, s.x * 0.7, 3), Color(0, 0, 0, 0.25))
		var vira: bool = v.pos.x > jx
		var r := Rect2(base, s)
		if vira:
			r = Rect2(base + Vector2(s.x, 0), Vector2(-s.x, s.y))
		var cor := Color.WHITE
		if v.elite:
			draw_circle(v.pos, s.x * 0.55, Color(1.0, 0.85, 0.3, 0.25 + 0.15 * sin(_t * 8.0)))
		elif v.lento > 0:
			cor = Color(0.6, 0.85, 1.0)
		draw_texture_rect_region(v.tex, r, Rect2(v.tam.x * quadro, 0, v.tam.x, v.tam.y), cor)
	for t in tiros:
		var tx: Texture2D = t.tex
		var sz := tx.get_size() * ESCALA
		draw_set_transform(t.pos, t.vel.angle(), Vector2.ONE)
		draw_texture_rect(tx, Rect2(-sz / 2, sz), false)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
