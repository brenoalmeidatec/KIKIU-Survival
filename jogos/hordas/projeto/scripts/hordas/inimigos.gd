extends Node2D
## Todos os inimigos da partida num lugar só (sem um nó por inimigo, pra caber 500 na tela).
## Cada inimigo é um objeto leve (classe V). Uma grade espacial acha quem está perto rápido.
## Também cuida dos tiros dos inimigos.

const Visual := preload("res://scripts/hordas/visual.gd")
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
	var atordoado := 0.0         # parado no lugar (rugido do dragão)
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
	# vida no desenho (dados/inimigos.json): tudo lido uma vez aqui
	var ppx := 2.0               # pixels da tela por pixel do sprite (2 = vírus, 1 = arte de horror)
	var ritmo := 4.0             # quadros de andar por segundo
	var balanco := 0.0           # pulinho de andar, em px da tela
	var flutua := 0.0            # px acima do chão (a sombra fica no chão)
	var aura := Color(0, 0, 0, 0)   # brilho em volta (a > 0)
	var sz := Vector2.ZERO       # tamanho na tela (tam x escala x esc), calculado uma vez
	var luz := Vector2.ZERO      # x = raio, y = intensidade: ilumina a escuridão da fase de horror

var arena: Node
var online: Node = null      # online.gd (só na partida online)
var espelho := false         # cliente online: os vírus vêm do anfitrião, aqui não roda IA
var por_id := {}             # id -> V
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
	if bool(dd.get("elite", false)) and not v.chefe:
		v.elite = true               # elite "de fábrica" (Abominação): vida e tamanho já vêm do json
	elif elite and not v.chefe:
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
	v.ppx = float(dd.get("escala", ESCALA))
	v.sz = v.tam * v.ppx * v.esc
	v.ritmo = float(dd.get("ritmo", 4.0))
	v.balanco = float(dd.get("balanco", 0.0))
	v.flutua = float(dd.get("flutua", 0.0))
	if dd.get("aura") is Array:
		v.aura = Color(dd.aura[0], dd.aura[1], dd.aura[2], 1.0)
	if dd.get("luz") is Array:
		v.luz = Vector2(dd.luz[0], dd.luz[1])
	v.t_atira = randf_range(0.5, float(dd.get("atira", 3.0)))
	v.t_anel = float(dd.get("anel", 0.0))
	v.t_inv = float(dd.get("investida", 0.0))
	v.t_invoca = float(dd.get("invoca", {}).get("a_cada", 0.0)) if dd.get("invoca") is Dictionary else 0.0
	lista.append(v)
	por_id[v.id] = v
	return v


func vivos() -> int:
	return lista.size()


func _remover(v: V) -> void:
	por_id.erase(v.id)
	var i := lista.find(v)
	if i >= 0:
		lista[i] = lista[lista.size() - 1]
		lista.pop_back()


func limpar() -> void:
	lista.clear()
	por_id.clear()
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
	arena.registrar_dano(arma, valor, v.pos, crit)
	if espelho:
		# cliente: o anfitrião aplica de verdade (e avisa se morreu); aqui só some até a confirmação
		online.acerto(v.id, valor, empurrao)
		if v.hp <= 0:
			_remover(v)
			return true
		return false
	var peso := 4.0 if v.pesado else 1.0
	if v.chefe:
		peso = 12.0
	v.kb += empurrao / peso
	if v.hp <= 0:
		_remover(v)
		arena.inimigo_morreu(v)
		return true
	return false


## Anfitrião: acerto que veio de outro computador (o dano e o crítico já foram calculados lá).
func ferir_remoto(v: V, valor: float, empurrao: Vector2) -> void:
	if v.hp <= 0:
		return
	v.hp -= valor
	v.flash = 0.09
	v.kb += empurrao / (12.0 if v.chefe else (4.0 if v.pesado else 1.0))
	if v.hp <= 0:
		_remover(v)
		arena.inimigo_morreu(v)


func remover_id(id: int) -> void:
	var v = por_id.get(id)
	if v:
		_remover(v)


## Cliente: aplica a foto do anfitrião. vir = [id, tipo_idx, x, y, hp_frac, flags] por vírus;
## tiros = [x, y, vx, vy, sprite_idx]. Quem não veio na foto sumiu (morreu ou ficou longe).
func aplicar_foto(vir: PackedFloat32Array, tir: PackedFloat32Array, onl: Node) -> void:
	var vistos := {}
	for i in range(0, vir.size(), 6):
		var id := int(vir[i])
		var ti := int(vir[i + 1])
		if ti < 0 or ti >= onl.tipos.size() or not is_finite(vir[i + 2]) or not is_finite(vir[i + 3]):
			continue
		var flags := int(vir[i + 5])
		var v: V = por_id.get(id)
		if v == null:
			v = criar(onl.tipos[ti], Vector2(vir[i + 2], vir[i + 3]), 1, (flags & 1) != 0)
			if v == null:
				continue
			por_id.erase(v.id)
			v.id = id
			por_id[id] = v
		v.set_meta("alvo", Vector2(vir[i + 2], vir[i + 3]))
		v.hp = clampf(vir[i + 4], 0.01, 1.0) * v.hpmax
		v.chefe = (flags & 2) != 0
		if (flags & 4) != 0:
			v.flash = maxf(v.flash, 0.05)
		v.estado = 1 if (flags & 8) != 0 else 0
		v.lento = 0.1 if (flags & 16) != 0 else 0.0
		vistos[id] = true
	for v in lista.duplicate():
		if not vistos.has(v.id):
			_remover(v)
	tiros.clear()
	for i in range(0, tir.size(), 5):
		var si := int(tir[i + 4])
		var spr: String = onl.sprites_tiro[si] if si >= 0 and si < onl.sprites_tiro.size() else "proj_email"
		tiros.append({"pos": Vector2(tir[i], tir[i + 1]), "vel": Vector2(tir[i + 2], tir[i + 3]), "dano": 0.0,
			"tex": Dados.tex(spr), "vida": 1.0, "sprite": spr})


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
	# grade
	_grade.clear()
	for v: V in lista:
		var c := _celula(v.pos)
		if _grade.has(c):
			_grade[c].append(v)
		else:
			_grade[c] = [v]
	if espelho:
		_atualizar_espelho(dt)
		return
	# quem os vírus perseguem: o jogador local ou, no online, o jogador em pé mais perto
	var alvos: Array = online.alvos() if online else [[jog.centro(), 0]]
	if alvos.is_empty():
		alvos = [[jog.centro(), -1]]   # todo mundo caído: vão pro corpo do anfitrião sem ferir
	var alvo: Vector2 = alvos[0][0]
	var dono: int = alvos[0][1]
	var local: int = Rede.eu() if online else 0

	for v: V in lista.duplicate():
		if v.hp <= 0:
			continue
		v.flash = maxf(0.0, v.flash - dt)
		v.lento = maxf(0.0, v.lento - dt)
		v.atordoado = maxf(0.0, v.atordoado - dt)
		if alvos.size() > 1:
			var md := INF
			for a in alvos:
				var d2: float = v.pos.distance_squared_to(a[0])
				if d2 < md:
					md = d2
					alvo = a[0]
					dono = a[1]
		var para: Vector2 = alvo - v.pos
		var dist: float = para.length()
		var dir: Vector2 = para / dist if dist > 0.01 else Vector2.ZERO
		var vel: float = 0.0 if v.atordoado > 0 else v.vel * (0.45 if v.lento > 0 else 1.0)
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
			_ferir_jogador(jog, dono, local, v.dano, v.tipo)
		# muito longe: volta pra perto (do lado de onde o jogador está indo)
		if dist > LONGE and not v.chefe:
			var mov_j: Vector2 = jog.direcao_mov() if dono == local else Vector2.ZERO
			var a: float = mov_j.angle() + randf_range(-1.0, 1.0)
			if mov_j == Vector2.ZERO:
				a = randf() * TAU
			v.pos = alvo + Vector2.from_angle(a) * randf_range(380, 440)

	# tiros dos inimigos
	for t in tiros.duplicate():
		t.pos += t.vel * dt
		t.vida -= dt
		var acertou := false
		for a in alvos:
			if t.pos.distance_squared_to(a[0]) < 100.0:
				_ferir_jogador(jog, a[1], local, t.dano, "tiro")
				acertou = true
				break
		if acertou or t.vida <= 0:
			tiros.erase(t)
	queue_redraw()


## Dano de vírus: no jogador daqui, ou (anfitrião online) manda pro computador de quem foi acertado.
func _ferir_jogador(jog: Node2D, quem: int, local: int, dano: float, fonte: String) -> void:
	if quem == local and quem >= 0:
		jog.sofrer(dano, fonte)
	elif quem > 0 and online:
		online.dano_remoto(quem, dano, fonte)


## Cliente online: os vírus só deslizam até a posição da última foto e os tiros seguem reto.
func _atualizar_espelho(dt: float) -> void:
	for v: V in lista:
		v.flash = maxf(0.0, v.flash - dt)
		var alvo: Vector2 = v.get_meta("alvo", v.pos)
		v.pos = alvo if v.pos.distance_squared_to(alvo) > 120.0 * 120.0 else v.pos.lerp(alvo, minf(1.0, dt * 12.0))
	for t in tiros:
		t.pos += t.vel * dt
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
	tiros.append({"pos": pos, "vel": vel, "dano": dano, "tex": Dados.tex(sprite), "vida": 5.0, "sprite": sprite})


# ---------- desenho ----------

func _draw() -> void:
	var jx: float = arena.jogador.position.x if arena and arena.jogador else 0.0
	# ordenar por altura (quem está mais embaixo fica na frente) custa caro: refaz a cada 4 quadros
	if _quadro % 4 == 0 or _ordem.size() < lista.size() / 2:
		_ordem = lista.duplicate()
		_ordem.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	# 1ª passada: sombras (todas antes dos sprites, pra nenhuma sombra cair por cima de outro vírus)
	for v: V in _ordem:
		if v.hp <= 0:
			continue
		var s: Vector2 = v.sz
		var pe: Vector2 = v.pos + Vector2(0, s.y * 0.4)
		var quadro := int(_t * v.ritmo + v.id) % 2
		var src := Rect2(v.tam.x * quadro, 0, v.tam.x, v.tam.y)
		var rs := Rect2(s.x / 2, -s.y, -s.x, s.y) if v.pos.x > jx else Rect2(-s.x / 2, -s.y, s.x, s.y)
		Visual.contato(self, pe, s.x * 0.75)
		Visual.sombra(self, v.tex, rs, src, pe)
	for v: V in _ordem:
		if v.hp <= 0:
			continue
		var s: Vector2 = v.sz
		var vira: bool = v.pos.x > jx
		var quadro := 2 if v.flash > 0 else (int(_t * v.ritmo + v.id) % 2)
		var cor := Color.WHITE
		if v.aura.a > 0.0:
			draw_circle(v.pos, s.x * 0.5, Color(v.aura.r, v.aura.g, v.aura.b, 0.16 + 0.08 * sin(_t * 5.0 + v.id)))
		elif v.elite:
			draw_circle(v.pos, s.x * 0.55, Color(1.0, 0.85, 0.3, 0.25 + 0.15 * sin(_t * 8.0)))
		elif v.atordoado > 0:
			cor = Color(1.0, 0.95, 0.6)   # atordoado: amarelado, piscando de leve
		elif v.lento > 0:
			cor = Color(0.6, 0.85, 1.0)
		# Rect2 de largura negativa vira o sprite, mas o Godot desenha a partir da posição pra DIREITA (não normaliza):
		# por isso a posição é a borda esquerda nos dois casos (antes o bicho à direita do herói saía deslocado 1 largura).
		var r: Rect2
		if v.estado == 0 and v.flash <= 0.0 and v.balanco <= 0.0 and v.flutua <= 0.0:
			r = Rect2(v.pos.x - s.x * 0.5, v.pos.y - s.y * 0.6, -s.x if vira else s.x, s.y)   # caminho rápido (vírus)
		else:
			var fase_a: float = (_t * v.ritmo + v.id) * PI     # o pulinho acompanha a troca de quadro
			var sx := 1.0
			var sy := 1.0
			var jit := 0.0
			var lift := 0.0
			if v.estado == 1:
				# telegrafa a investida: agacha, treme e avermelha; nos últimos 35% pisca branco
				var u := clampf(1.0 - v.t_estado / 0.7, 0.0, 1.0)
				sx = 1.0 + 0.18 * u
				sy = 1.0 - 0.24 * u
				jit = sin(_t * 90.0 + v.id) * 1.5 * u
				cor = Color(1.0, 1.0 - 0.55 * u, 1.0 - 0.6 * u)
				if u > 0.65 and int(_t * 20.0) % 2 == 0:
					quadro = 2
			elif v.estado == 2:
				sx = 1.22      # em disparada: esticado no sentido da corrida
				sy = 0.86
			else:
				var sn := sin(fase_a)
				if v.balanco > 0.0:
					lift = absf(sn) * v.balanco
				var respira := 1.0 - 2.0 * sn * sn      # = cos(2 x fase), sem outra chamada trigonométrica
				sx = 1.0 + 0.045 * respira
				sy = 1.0 - 0.045 * respira
			if v.flutua > 0.0:
				lift += v.flutua * (1.0 + 0.25 * sin(_t * 3.0 + v.id))
			if v.flash > 0.0:
				var k := v.flash / 0.09      # squash ao levar dano: achata e alarga, voltando em ~0,1 s
				sx *= 1.0 + 0.3 * k
				sy *= 1.0 - 0.24 * k
			var w := roundf(s.x * sx)
			var h := roundf(s.y * sy)
			r = Rect2(roundf(v.pos.x + jit) - roundf(w * 0.5), roundf(v.pos.y + s.y * 0.4 - lift) - h, -w if vira else w, h)
		draw_texture_rect_region(v.tex, r, Rect2(v.tam.x * quadro, 0, v.tam.x, v.tam.y), cor)
	for t in tiros:
		var tx: Texture2D = t.tex
		var sz := tx.get_size() * ESCALA
		draw_set_transform(t.pos, t.vel.angle(), Vector2.ONE)
		draw_texture_rect(tx, Rect2(-sz / 2, sz), false)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
