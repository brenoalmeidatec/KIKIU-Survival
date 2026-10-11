extends RefCounted
## Golpes secundários AUTOMÁTICOS da v2 (leva 3) e as ondas da katana. O golpe principal é o clique; estes vêm pelas cartas (v2/cartas.gd):
##   orbita (lâminas que giram), aura (círculo de fogo que queima e empurra), corvos (caçam e bicam), raio (cai e salta em cadeia), runa
##   (explode quando alguém pisa). Números portados de dados/armas.json da v1 e guardados em dados/v2_cartas.json ("golpes"/"evolucoes").
## Mais: o corte solta uma ONDA, a estocada solta uma LANÇA de luz, o crítico EXPLODE (modificadores da katana).
## Desempenho: tudo em pool (vetores de tamanho fixo, nenhum nó por golpe) e DUAS chamadas de desenho por quadro na camada glow (uma normal,
## para o corpo escuro dos corvos e as sombras, e uma aditiva para o brilho). O chão é uma elipse (y achatado por ACHATA), como a sombra.
## Quem fere é combate.ferir(); as mortes ficam numa fila e saem no fim do quadro (processar_mortes) para não mexer na lista de monstros
## enquanto ela é percorrida.

const Colisao := preload("res://v2/colisao.gd")
const MAX_CORVOS := 16
const MAX_RUNAS := 14
const MAX_ONDAS := 8
const MAX_RAIOS := 6
const PTS := 32
const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x
const COR_RAIO := Color(0.72, 0.86, 1.0)

var combate
var mundo
var fx
var ativas := {}  # id -> golpe secundário {id, tipo, cor, slot, nivel, bonus, st (números), t, t2, ang, pulso, pts, R, evo}
var mods := {"onda": 0.0, "fura": 0.0, "explode": 0.0, "folego": 0.0}  # valor acumulado (em %) de cada modificador da katana
var ventania := {}  # evolução da katana, ou {}
var acertos := {}  # tipo -> quantos acertos (testes)
var lancadas := 0  # ondas e lanças lançadas (testes)
var no_corpo: Node2D
var no_brilho: Node2D
var tex_brilho: Texture2D
var luz_fogo: PointLight2D
var luz_lamina: PointLight2D

var _agora := 0.0
var _perto: Array = []
var _desenha := false
var _id_proj := 0
var _fase := 0.0

# corvos
var c_pos := PackedVector2Array()
var c_vel := PackedVector2Array()
var c_z := PackedFloat32Array()
var c_vida := PackedFloat32Array()
var c_bic := PackedFloat32Array()
var c_re := PackedFloat32Array()
var c_fase := PackedFloat32Array()
var c_alvo: Array = []
var c_arma: Array = []

# runas
var r_pos := PackedVector2Array()
var r_t := PackedFloat32Array()  # idade
var r_vida := PackedFloat32Array()  # o que falta (<= 0: livre)
var r_arma: Array = []

# ondas e lanças da katana
var w_pos := PackedVector2Array()
var w_dir := PackedVector2Array()
var w_vel := PackedFloat32Array()
var w_dist := PackedFloat32Array()  # quanto ainda anda (<= 0: livre)
var w_dano := PackedFloat32Array()
var w_larg := PackedFloat32Array()
var w_tipo := PackedByteArray()  # 0 = onda, 1 = lança
var w_id := PackedInt32Array()
var w_t := PackedFloat32Array()

# raios (o desenho)
var z_pts := PackedVector2Array()
var z_n := PackedInt32Array()
var z_t := PackedFloat32Array()
var z_dur := PackedFloat32Array()
var _zi := 0


func montar(c, camada: Node, sv: Node, tex: Texture2D) -> void:
	combate = c
	mundo = c.mundo
	fx = c.fx
	tex_brilho = tex
	_texturas()
	camada.add_child(_aura_sp)
	no_corpo = Node2D.new()
	no_corpo.draw.connect(_desenhar_corpo)
	camada.add_child(no_corpo)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	no_brilho = Node2D.new()
	no_brilho.material = mat
	no_brilho.draw.connect(_desenhar_brilho)
	camada.add_child(no_brilho)
	luz_fogo = _nova_luz(sv, Color(1.0, 0.55, 0.2))
	luz_lamina = _nova_luz(sv, Color(0.7, 0.9, 1.0))
	c_pos.resize(MAX_CORVOS)
	c_vel.resize(MAX_CORVOS)
	c_z.resize(MAX_CORVOS)
	c_vida.resize(MAX_CORVOS)
	c_bic.resize(MAX_CORVOS)
	c_re.resize(MAX_CORVOS)
	c_fase.resize(MAX_CORVOS)
	c_alvo.resize(MAX_CORVOS)
	c_arma.resize(MAX_CORVOS)
	r_pos.resize(MAX_RUNAS)
	r_t.resize(MAX_RUNAS)
	r_vida.resize(MAX_RUNAS)
	r_arma.resize(MAX_RUNAS)
	w_pos.resize(MAX_ONDAS)
	w_dir.resize(MAX_ONDAS)
	w_vel.resize(MAX_ONDAS)
	w_dist.resize(MAX_ONDAS)
	w_dano.resize(MAX_ONDAS)
	w_larg.resize(MAX_ONDAS)
	w_tipo.resize(MAX_ONDAS)
	w_id.resize(MAX_ONDAS)
	w_t.resize(MAX_ONDAS)
	z_pts.resize(MAX_RAIOS * PTS)
	z_n.resize(MAX_RAIOS)
	z_t.resize(MAX_RAIOS)
	z_dur.resize(MAX_RAIOS)
	z_t.fill(9.0)
	z_dur.fill(1.0)


func _nova_luz(sv: Node, cor: Color) -> PointLight2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.45, 0.45, 0.45, 1), Color(0, 0, 0, 1)])
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 128
	tx.height = 128
	var l := PointLight2D.new()
	l.texture = tx
	l.color = cor
	l.enabled = false
	l.shadow_enabled = false
	l.height = 22.0
	sv.add_child(l)
	return l


## Volta ao começo da partida.
func limpar() -> void:
	ativas.clear()
	for k in mods:
		mods[k] = 0.0
	ventania = {}
	acertos.clear()
	lancadas = 0
	c_vida.fill(0.0)
	r_vida.fill(0.0)
	w_dist.fill(0.0)
	z_t.fill(9.0)
	for i in MAX_CORVOS:
		c_alvo[i] = null
		c_arma[i] = null
	for i in MAX_RUNAS:
		r_arma[i] = null
	luz_fogo.enabled = false
	luz_lamina.enabled = false
	_aura_sp.visible = false
	_desenha = false
	no_corpo.queue_redraw()
	no_brilho.queue_redraw()


# ------------------------------------------------------------------ cartas -> golpes


func _slot_livre() -> int:
	var usados := {}
	for id in ativas:
		usados[int(ativas[id].slot)] = true
	for s in 8:
		if not usados.has(s):
			return s
	return 7


func _nova(id: String, tipo: String, cor: Color) -> Dictionary:
	return {
		"id": id,
		"tipo": tipo,
		"cor": cor,
		"slot": _slot_livre(),
		"nivel": 1,
		"bonus": 0.0,
		"st": {},
		"t": 0.4,
		"t2": 0.3,
		"ang": randf() * TAU,
		"pulso": 0.0,
		"pts": PackedVector2Array(),
		"R": 40.0,
		"evo": false
	}


## Põe (ou sobe) o golpe `id` ao nível `nivel`: os números são a base mais o que cada nível até ali soma; o dano ganha o bônus da raridade.
func definir_golpe(id: String, nivel: int, bonus: float) -> void:
	var d: Dictionary = combate.cartas.definicao(id)
	if d.is_empty():
		return
	var a: Dictionary = ativas.get(id, {})
	if a.is_empty():
		a = _nova(id, str(d.tipo), Color(d.cor[0], d.cor[1], d.cor[2]))
		ativas[id] = a
	a.nivel = nivel
	a.bonus = bonus
	var st: Dictionary = (d.base as Dictionary).duplicate()
	for k in range(nivel - 1):
		var n: Dictionary = d.niveis[k]
		for chave in n:
			if chave != "texto":
				st[chave] = float(st.get(chave, 0.0)) + float(n[chave])
	st.dano = float(st.dano) * (1.0 + bonus)
	a.st = st


func adicionar_evoluida(ev: Dictionary, bonus: float) -> void:
	var a := _nova(str(ev.id), str(ev.tipo), Color(ev.cor[0], ev.cor[1], ev.cor[2]))
	a.evo = true
	a.nivel = 5
	a.bonus = bonus
	var st: Dictionary = (ev.arma as Dictionary).duplicate()
	st.dano = float(st.dano) * (1.0 + bonus)
	a.st = st
	ativas[str(ev.id)] = a


func remover(id: String) -> void:
	var a: Dictionary = ativas.get(id, {})
	if a.is_empty():
		return
	for i in MAX_CORVOS:
		if c_arma[i] == a:
			c_vida[i] = 0.0
			c_arma[i] = null
	for i in MAX_RUNAS:
		if r_arma[i] == a:
			r_vida[i] = 0.0
			r_arma[i] = null
	ativas.erase(id)


func definir_modificador(mod: String, soma: float) -> void:
	mods[mod] = soma


func definir_evolucao_katana(ev: Dictionary) -> void:
	ventania = ev
	mods["onda"] = maxf(float(mods["onda"]), 1.0)
	mods["fura"] = maxf(float(mods["fura"]), 1.0)


func tem(id: String) -> bool:
	return ativas.has(id)


# ------------------------------------------------------------------ o quadro


func atualizar(dt: float) -> void:
	var h = mundo.heroi
	if not h.vivo():
		return
	_agora = mundo.tempo_partida
	_fase += dt
	var movel := false
	if not ativas.is_empty():
		movel = true
		_juntar_perto(h.pos, 340.0)
		var vel_a: float = h.m_vel_ataque
		for id in ativas:
			var a: Dictionary = ativas[id]
			match str(a.tipo):
				"orbita":
					_orbita(a, h, dt, vel_a)
				"aura":
					_aura(a, h, dt, vel_a)
				"corvos":
					_corvos_gerar(a, h, dt, vel_a)
				"raio":
					_raio(a, h, vel_a, dt)
				"runa":
					_runas_gerar(a, h, dt, vel_a)
	elif _perto.size() > 0 or _tem_pool():
		_juntar_perto(h.pos, 340.0)
	_aura_visual(h)
	_corvos_mover(h, dt)
	_runas_mover(h, dt)
	_ondas_mover(dt)
	_raios_tempo(dt)
	_luzes(h, dt)
	combate.processar_mortes()
	var ativo := movel or _tem_pool()
	if ativo or _desenha:
		no_corpo.queue_redraw()
		no_brilho.queue_redraw()
	_desenha = ativo


func _tem_pool() -> bool:
	for i in MAX_CORVOS:
		if c_vida[i] > 0.0:
			return true
	for i in MAX_RUNAS:
		if r_vida[i] > 0.0:
			return true
	for i in MAX_ONDAS:
		if w_dist[i] > 0.0:
			return true
	for i in MAX_RAIOS:
		if z_t[i] < z_dur[i]:
			return true
	return false


func _juntar_perto(p: Vector2, r: float) -> void:
	_perto.clear()
	var r2 := r * r
	for m in mundo.monstros:
		if (m.pos - p).length_squared() < r2 and m.vivo and not m.morrendo:
			_perto.append(m)


static func na_elipse(d: Vector2, r: float) -> bool:
	var y := d.y / ACHATA
	return d.x * d.x + y * y < r * r


func _acertou(tipo: String) -> void:
	acertos[tipo] = int(acertos.get(tipo, 0)) + 1


func _cor_num(c: Color) -> Color:
	return c.lerp(Color.WHITE, 0.45)


# ------------------------------------------------------------------ lâminas


func _orbita(a: Dictionary, h, dt: float, vel_a: float) -> void:
	var st: Dictionary = a.st
	var n := int(st.quantidade)
	var k_area: float = 1.0 + (h.m_area - 1.0) * 0.6
	var raio := float(st.raio) * k_area
	a.ang = fposmod(float(a.ang) + float(st.giro) * dt, TAU)
	var centro: Vector2 = h.pos + Vector2(0, -3)
	var pts: PackedVector2Array = a.pts
	if pts.size() != n:
		pts.resize(n)
	for i in n:
		var ang: float = float(a.ang) + TAU * float(i) / float(n)
		pts[i] = centro + Vector2(cos(ang) * raio, sin(ang) * raio * ACHATA)
	a.pts = pts
	a.R = raio
	var dano: float = float(st.dano) * h.m_dano
	var tique := float(st.tique) / vel_a
	var slot := int(a.slot)
	var perto2 := (raio + 30.0) * (raio + 30.0)
	for m in _perto:
		if (m.pos - centro).length_squared() > perto2 + m.raio * m.raio:
			continue
		if m.cd[slot] > _agora:
			continue
		for i in n:
			# a lâmina varre do meio do círculo até a ponta: acerta também o monstro colado no herói
			var lim: float = 10.0 + m.raio
			var ini: Vector2 = centro + (pts[i] - centro) * 0.3
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(m.pos, ini, pts[i])
			if q.distance_squared_to(m.pos) < lim * lim:
				var fora: Vector2 = m.pos - centro
				fora = fora.normalized() if fora.length() > 0.5 else Vector2.RIGHT
				m.cd[slot] = _agora + tique
				combate.ferir(m, dano, fora, float(st.get("empurra", 0.0)), 0.1, _cor_num(a.cor))
				if float(st.get("queima_dps", 0.0)) > 0.0:
					m.queimar(float(st.queima_dps), float(st.get("queima_t", 2.0)))
				_acertou("orbita")
				break
	if st.has("aura_raio"):  # Anel de Brasas: a aura de fogo vem junto
		_aura_tick(a, h, dt, float(st.aura_raio) * k_area, float(st.aura_dano) * h.m_dano, 0.5 / vel_a, 40.0, float(st.queima_dps), float(st.queima_t))


# ------------------------------------------------------------------ aura de fogo


func _aura(a: Dictionary, h, dt: float, vel_a: float) -> void:
	var st: Dictionary = a.st
	var k_area: float = 1.0 + (h.m_area - 1.0) * 0.6
	a.R = float(st.raio) * k_area
	_aura_tick(
		a,
		h,
		dt,
		float(a.R),
		float(st.dano) * h.m_dano,
		float(st.tique) / vel_a,
		float(st.get("empurra", 0.0)),
		float(st.get("queima_dps", 0.0)),
		float(st.get("queima_t", 2.0))
	)


func _aura_tick(a: Dictionary, h, dt: float, raio: float, dano: float, tique: float, empurra: float, queima_dps: float, queima_t: float) -> void:
	a.RA = raio
	a.pulso = maxf(0.0, float(a.pulso) - dt * 3.0)
	a.t2 = float(a.t2) - dt
	if float(a.t2) > 0.0:
		return
	a.t2 = tique
	a.pulso = 1.0
	var centro: Vector2 = h.pos
	var n := 0
	for m in _perto:
		var d: Vector2 = m.pos - centro
		if not na_elipse(d, raio + m.raio):
			continue
		var fora := d.normalized() if d.length() > 0.5 else Vector2.RIGHT
		combate.ferir(m, dano, fora, empurra, 0.08, _cor_num(a.cor))
		if queima_dps > 0.0:
			m.queimar(queima_dps, queima_t)
		n += 1
	if n > 0:
		_acertou("aura")
		combate.audio.tocar("fogo", randf_range(0.95, 1.1), -4.0, 0.15)
	# faíscas de brasa no anel (pouco: o resto do fogo é desenho)
	for i in maxi(1, roundi(3.0 * fx.fator_part)):
		var ang := randf() * TAU
		fx.particula(
			centro + Vector2(cos(ang) * raio, sin(ang) * raio * ACHATA) + Vector2(0, -2),
			Vector2(randf_range(-10, 10), randf_range(-34, -14)),
			randf_range(0.3, 0.6),
			randf_range(2.0, 4.0),
			Color(1.0, randf_range(0.35, 0.7), 0.12, 0.85),
			-30.0,
			randf() < 0.4
		)


# ------------------------------------------------------------------ corvos


func _corvos_gerar(a: Dictionary, h, dt: float, vel_a: float) -> void:
	a.t = float(a.t) - dt
	if float(a.t) > 0.0:
		return
	if _perto.is_empty():
		a.t = 0.3
		return
	var st: Dictionary = a.st
	a.t = float(st.recarga) / vel_a
	for k in int(st.quantidade):
		var i := -1
		for j in MAX_CORVOS:
			if c_vida[j] <= 0.0:
				i = j
				break
		if i < 0:
			break
		var ang := randf() * TAU
		c_pos[i] = h.pos + Vector2(cos(ang), sin(ang) * ACHATA) * 12.0
		c_vel[i] = Vector2.from_angle(ang) * 90.0
		c_z[i] = 34.0
		c_vida[i] = float(st.duracao)
		c_bic[i] = 0.25 + 0.05 * k
		c_re[i] = 0.0
		c_fase[i] = randf() * TAU
		c_alvo[i] = null
		c_arma[i] = a
		fx.particula(c_pos[i] + Vector2(0, -20), Vector2(randf_range(-20, 20), -20), 0.3, 6.0, Color(0.7, 0.4, 1.0, 0.7), 0.0, true)
	combate.audio.tocar("corvo", randf_range(0.9, 1.15), -3.0, 0.2)


func _corvos_mover(h, dt: float) -> void:
	for i in MAX_CORVOS:
		if c_vida[i] <= 0.0:
			continue
		var a = c_arma[i]
		if a == null:
			c_vida[i] = 0.0
			continue
		var st: Dictionary = a.st
		c_vida[i] -= dt
		c_fase[i] += dt * 17.0
		var alvo = c_alvo[i]
		c_re[i] -= dt
		if alvo == null or not alvo.vivo or alvo.morrendo or c_re[i] <= 0.0:
			c_re[i] = 0.3
			alvo = null
			var melhor := 1e12
			var alc := float(st.alcance)
			for m in _perto:
				if (m.pos - h.pos).length_squared() > alc * alc:
					continue
				var s: float = m.pos.distance_squared_to(c_pos[i]) + float((i * 37) % 23) * 40.0
				if s < melhor:
					melhor = s
					alvo = m
			c_alvo[i] = alvo
		var dest: Vector2
		if alvo != null:
			dest = alvo.pos
		else:
			dest = h.pos + Vector2(cos(_fase * 1.6 + float(i)), sin(_fase * 1.6 + float(i)) * ACHATA) * 44.0
		var d := dest - c_pos[i]
		var dist := d.length()
		var rapido := float(st.velocidade)
		var alvo_vel := d / maxf(dist, 0.01) * rapido
		if alvo != null and dist < 12.0:
			alvo_vel *= 0.25
		c_vel[i] = c_vel[i].lerp(alvo_vel, 1.0 - exp(-7.0 * dt))
		c_pos[i] += c_vel[i] * dt
		var z_alvo := 9.0 if (alvo != null and dist < 22.0) else 30.0
		c_z[i] = lerpf(c_z[i], z_alvo, 1.0 - exp(-8.0 * dt))
		if alvo != null:
			c_bic[i] -= dt
			if c_bic[i] <= 0.0 and dist < 16.0 + alvo.raio:
				c_bic[i] = float(st.tique)
				c_z[i] += 6.0
				var dano: float = float(st.dano) * h.m_dano
				var fora: Vector2 = (alvo.pos - h.pos).normalized()
				combate.ferir(alvo, dano, fora, 20.0, 0.12, _cor_num(a.cor))
				_acertou("corvos")
				fx.faiscas(alvo.pos + Vector2(0, -8), fora, 3, Color(0.8, 0.5, 1.0), 110.0)
				if float(st.get("eletrico", 0.0)) > 0.0:
					_arco_eletrico(alvo, dano * float(st.eletrico), h)
		if c_vida[i] <= 0.0:
			fx.particula(c_pos[i] + Vector2(0, -c_z[i]), Vector2(0, -16), 0.3, 7.0, Color(0.6, 0.35, 1.0, 0.6), 0.0, true)
			c_arma[i] = null
			c_alvo[i] = null


## Corvo elétrico: a bicada solta um raio no vizinho mais perto (até 64 px).
func _arco_eletrico(de, dano: float, h) -> void:
	var melhor = null
	var md := 64.0 * 64.0
	for m in _perto:
		if m == de:
			continue
		var d2: float = m.pos.distance_squared_to(de.pos)
		if d2 < md:
			md = d2
			melhor = m
	if melhor == null:
		return
	combate.ferir(melhor, dano, (melhor.pos - de.pos).normalized(), 30.0, 0.1, COR_RAIO)
	_acertou("raio")
	_raio_visual([de.pos + Vector2(0, -10), melhor.pos + Vector2(0, -10)])


# ------------------------------------------------------------------ raio em cadeia


func _raio(a: Dictionary, h, vel_a: float, dt: float) -> void:
	a.t = float(a.t) - dt
	if float(a.t) > 0.0:
		return
	var st: Dictionary = a.st
	var alc2 := float(st.alcance) * float(st.alcance)
	var cand: Array = []
	for m in _perto:
		if (m.pos - h.pos).length_squared() < alc2:
			cand.append(m)
	if cand.is_empty():
		a.t = 0.25
		return
	a.t = float(st.recarga) / vel_a
	var usados: Array = []
	for k in int(st.quantidade):
		var alvo = null
		var melhor := 1e12
		for m in cand:
			if usados.has(m) or not m.vivo or m.morrendo:
				continue
			var d2: float = m.pos.distance_squared_to(h.pos) + randf() * 900.0
			if d2 < melhor:
				melhor = d2
				alvo = m
		if alvo == null:
			break
		usados.append(alvo)
		_cair_raio(a, h, alvo)


func _cair_raio(a: Dictionary, h, alvo) -> void:
	var st: Dictionary = a.st
	var dano: float = float(st.dano) * h.m_dano
	var pontos: Array = [alvo.pos + Vector2(randf_range(-26, 26), -280), alvo.pos + Vector2(0, -8)]
	var atual = alvo
	var tocados: Array = [alvo]
	combate.ferir(alvo, dano, Vector2.ZERO, 0.0, 0.2, COR_RAIO)
	_acertou("raio")
	var raio_c := float(st.raio)
	for j in int(st.cadeia):
		var prox = null
		var md := raio_c * raio_c
		for m in _perto:
			if tocados.has(m) or not m.vivo or m.morrendo:
				continue
			var d2: float = m.pos.distance_squared_to(atual.pos)
			if d2 < md:
				md = d2
				prox = m
		if prox == null:
			break
		tocados.append(prox)
		dano *= 0.85
		combate.ferir(prox, dano, (prox.pos - atual.pos).normalized(), 40.0, 0.15, COR_RAIO)
		pontos.append(prox.pos + Vector2(0, -8))
		atual = prox
		_acertou("raio")
	_raio_visual(pontos)
	fx.luz_rapida(alvo.pos + Vector2(0, -10), COR_RAIO, 2.2, 150.0, 0.22)
	fx.onda(alvo.pos, Color(0.7, 0.85, 1.0, 0.9), 26.0, 0.2)
	combate.audio.tocar("raio", randf_range(0.92, 1.1), -1.0, 0.08)
	mundo.cam.tremer(1.0, 0.1)


## Guarda um raio para desenhar: uma linha torta passando pelos pontos (cada trecho com ~4 dentes).
func _raio_visual(pontos: Array) -> void:
	var i := _zi
	_zi = (_zi + 1) % MAX_RAIOS
	var n := 0
	var base := i * PTS
	z_pts[base] = pontos[0]
	n = 1
	for k in range(1, pontos.size()):
		var p0: Vector2 = pontos[k - 1]
		var p1: Vector2 = pontos[k]
		var seg := clampi(int(p0.distance_to(p1) / 26.0), 2, 8)
		var perp := (p1 - p0).orthogonal().normalized()
		for s in range(1, seg + 1):
			if n >= PTS:
				break
			var q := p0.lerp(p1, float(s) / float(seg))
			if s < seg:
				q += perp * randf_range(-7.0, 7.0)
			z_pts[base + n] = q
			n += 1
	z_n[i] = n
	z_t[i] = 0.0
	z_dur[i] = 0.2


func _raios_tempo(dt: float) -> void:
	for i in MAX_RAIOS:
		if z_t[i] < z_dur[i]:
			z_t[i] += dt


# ------------------------------------------------------------------ runas


func _runas_gerar(a: Dictionary, h, dt: float, vel_a: float) -> void:
	a.t = float(a.t) - dt
	if float(a.t) > 0.0:
		return
	var st: Dictionary = a.st
	a.t = float(st.recarga) / vel_a
	for k in int(st.quantidade):
		var i := -1
		for j in MAX_RUNAS:
			if r_vida[j] <= 0.0:
				i = j
				break
		if i < 0:
			break
		var p := _ponto_runa(h)
		r_pos[i] = p
		r_t[i] = 0.0
		r_vida[i] = float(st.duracao)
		r_arma[i] = a
		combate.audio.tocar("runa_poe", randf_range(0.95, 1.1), -6.0, 0.1)


func _ponto_runa(h) -> Vector2:
	for tentativa in 5:
		var p: Vector2
		if not _perto.is_empty() and randf() < 0.65:
			var m = _perto[randi() % _perto.size()]
			p = m.pos + Vector2(randf_range(-16, 16), randf_range(-10, 10))
		else:
			var ang := randf() * TAU
			p = h.pos + Vector2(cos(ang), sin(ang) * ACHATA) * randf_range(46.0, 120.0)
		if mundo.limite_andavel.has_point(p) and Colisao.livre(p, 4.0):
			return p
	return h.pos + Vector2(randf_range(-40, 40), randf_range(10, 40))


func _runas_mover(h, dt: float) -> void:
	for i in MAX_RUNAS:
		if r_vida[i] <= 0.0:
			continue
		var a = r_arma[i]
		if a == null:
			r_vida[i] = 0.0
			continue
		r_t[i] += dt
		r_vida[i] -= dt
		if r_t[i] < 0.5:
			continue
		var st: Dictionary = a.st
		var gatilho := float(st.raio)
		for m in _perto:
			if na_elipse(m.pos - r_pos[i], gatilho + m.raio):
				_explodir_runa(i, a, h)
				break


func _explodir_runa(i: int, a: Dictionary, h) -> void:
	var st: Dictionary = a.st
	var p: Vector2 = r_pos[i]
	r_vida[i] = 0.0
	r_arma[i] = null
	var k_area: float = 1.0 + (h.m_area - 1.0) * 0.6
	var raio := float(st.explosao) * k_area
	var dano: float = float(st.dano) * h.m_dano
	_dano_area(p, raio, dano, 160.0, 0.3, a.cor, "runa", float(st.get("lentidao", 0.0)))
	fx.estouro(p + Vector2(0, -4), a.cor, 12)
	fx.onda(p, Color(a.cor.r, a.cor.g, a.cor.b, 0.9), raio, 0.3)
	fx.luz_rapida(p + Vector2(0, -6), a.cor, 2.0, raio * 2.6, 0.3)
	combate.audio.tocar("runa", randf_range(0.9, 1.1), -1.0, 0.05)
	mundo.cam.tremer(1.5, 0.12)


## Dano em área (círculo no chão = elipse na tela) para todos perto de `p`. Devolve quantos acertou.
func _dano_area(p: Vector2, raio: float, dano: float, empurra: float, atordoa: float, cor: Color, tipo: String, lentidao := 0.0, ignorar = null) -> int:
	var n := 0
	for m in mundo.monstros:
		if m == ignorar or not m.vivo or m.morrendo:
			continue
		var d: Vector2 = m.pos - p
		if not na_elipse(d, raio + m.raio):
			continue
		var fora := d.normalized() if d.length() > 0.5 else Vector2.RIGHT
		combate.ferir(m, dano, fora, empurra, atordoa, _cor_num(cor))
		if lentidao > 0.0:
			m.deixar_lento(lentidao)
		n += 1
	if n > 0:
		_acertou(tipo)
	return n


## Explosão em área sem dono (o crítico explosivo da katana).
func explodir(p: Vector2, dano: float, raio: float, cor: Color, ignorar = null) -> void:
	_dano_area(p, raio, dano, 120.0, 0.2, cor, "explode", 0.0, ignorar)
	fx.estouro(p + Vector2(0, -6), cor, 8)
	fx.onda(p, Color(cor.r, cor.g, cor.b, 0.9), raio, 0.25)
	fx.luz_rapida(p + Vector2(0, -8), cor, 1.8, raio * 3.0, 0.25)
	combate.audio.tocar("runa", randf_range(1.1, 1.3), -3.0, 0.05)


# ------------------------------------------------------------------ onda e lança da katana


func _livre_onda() -> int:
	for i in MAX_ONDAS:
		if w_dist[i] <= 0.0:
			return i
	return 0


## O corte solta uma onda (dano já calculado). Com a Ventania, ela fica maior e mais forte.
func lancar_onda(origem: Vector2, dir: Vector2, dano: float) -> void:
	var cd: Dictionary = combate.cartas.definicao("onda")
	var larg := 34.0
	if not ventania.is_empty():
		dano *= float(ventania.mult_onda)
		larg *= float(ventania.larg_onda)
	_nova_onda(origem + dir * 14.0, dir, 0, float(cd.get("vel", 250.0)), float(cd.get("alcance", 150.0)), dano, larg)


## A estocada solta uma lança de luz que atravessa. Com a Ventania, saem três em leque.
func lancar_lanca(origem: Vector2, dir: Vector2, dano: float) -> void:
	var cd: Dictionary = combate.cartas.definicao("fura")
	var angulos: Array = [0.0]
	if not ventania.is_empty():
		angulos = [-0.3, 0.0, 0.3]
	for ang in angulos:
		_nova_onda(origem + dir * 20.0, dir.rotated(float(ang)), 1, float(cd.get("vel", 380.0)), float(cd.get("alcance", 190.0)), dano, 12.0)


func _nova_onda(p: Vector2, dir: Vector2, tipo: int, vel: float, alcance: float, dano: float, larg: float) -> void:
	var i := _livre_onda()
	_id_proj += 1
	w_pos[i] = p
	w_dir[i] = dir
	w_vel[i] = vel
	w_dist[i] = alcance
	w_dano[i] = dano
	w_larg[i] = larg
	w_tipo[i] = tipo
	w_id[i] = _id_proj
	w_t[i] = 0.0
	lancadas += 1


func _ondas_mover(dt: float) -> void:
	for i in MAX_ONDAS:
		if w_dist[i] <= 0.0:
			continue
		var passo := w_vel[i] * dt
		w_pos[i] += w_dir[i] * passo
		w_dist[i] -= passo
		w_t[i] += dt
		var dir: Vector2 = w_dir[i]
		var meia := w_larg[i] * 0.5
		var id := w_id[i]
		for m in _perto:
			if m.ultimo_proj == id:
				continue
			var rel: Vector2 = m.pos + Vector2(0, -6) - w_pos[i]
			if absf(rel.dot(dir)) > 12.0 + m.raio:
				continue
			if absf(rel.cross(dir)) > meia + m.raio:
				continue
			m.ultimo_proj = id
			combate.ferir(m, w_dano[i], dir, 90.0, 0.15, Color(0.85, 1.0, 0.95))
			_acertou("lanca" if w_tipo[i] == 1 else "onda")
			fx.faiscas(m.pos + Vector2(0, -8), dir, 4, Color(0.8, 1.0, 0.95), 130.0)


# ------------------------------------------------------------------ luz


func _luzes(h, dt: float) -> void:
	var fogo := false
	var fogo_r := 0.0
	var lamina_p := Vector2.ZERO
	var lamina := false
	for id in ativas:
		var a: Dictionary = ativas[id]
		if str(a.tipo) == "aura" or (str(a.tipo) == "orbita" and a.st.has("aura_raio")):
			fogo = true
			fogo_r = maxf(fogo_r, float(a.get("RA", a.R)))
		if str(a.tipo) == "orbita":
			var pts: PackedVector2Array = a.pts
			if pts.size() > 0:
				lamina = true
				lamina_p = pts[0] + Vector2(0, -10)
	luz_fogo.enabled = fogo
	if fogo:
		luz_fogo.position = (h.pos + Vector2(0, -6)).round()
		luz_fogo.texture_scale = fogo_r * 2.4 / 128.0
		luz_fogo.energy = 0.75 + 0.2 * sin(_fase * 17.0) + 0.1 * sin(_fase * 31.0)
	luz_lamina.enabled = lamina
	if lamina:
		luz_lamina.position = lamina_p.round()
		luz_lamina.texture_scale = 70.0 / 128.0
		luz_lamina.energy = 0.9


# ------------------------------------------------------------------ desenho
## Tudo o que dura (lâminas, corvos, runas, aura) é desenhado com TEXTURAS PRONTAS (geradas uma vez na abertura) e um shader para a aura:
## nada de polígono triangulado por quadro, que custava ~35% do fps com a build cheia. O que dura pouco (raio, onda, lança) usa linhas.

const SHADER_AURA := """
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform vec4 cor : source_color = vec4(1.0, 0.5, 0.15, 1.0);
uniform float t = 0.0;
uniform float pulso = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float f = 0.5 + 0.5 * sin(a * 11.0 + t * 7.0);
	float g = 0.5 + 0.5 * sin(a * 23.0 - t * 11.0 + sin(t * 3.0) * 2.0);
	float h = 0.05 + 0.12 * (f * 0.6 + g * 0.4) + 0.04 * pulso;
	float anel = 0.8;
	float fino = smoothstep(0.035 + 0.02 * pulso, 0.0, abs(r - anel));
	float chama = smoothstep(anel + h, anel, r) * smoothstep(anel - 0.16, anel, r);
	float chao = smoothstep(1.0, 0.2, r) * (0.16 + 0.12 * pulso);
	float k = clamp(fino * 0.9 + chama * 0.75 + chao, 0.0, 1.0);
	k *= 1.0 - smoothstep(0.93, 1.0, r);
	vec3 c = mix(cor.rgb, vec3(1.0, 0.9, 0.45), clamp(chama * 0.7 + fino * 0.5, 0.0, 1.0));
	COLOR = vec4(c * k * 1.5, k);
}
"""

var us_desenho := 0
var _tex_lamina: Texture2D
var _tex_corvo: Texture2D  # 3 quadros de 22x18: asa para cima, no meio e para baixo
var _tex_anel: Texture2D  # anel da runa (64x64)
var _tex_glifo: Texture2D  # triângulo da runa (64x64)
var _aura_sp: Sprite2D


func _texturas() -> void:
	_tex_lamina = _img_lamina()
	_tex_corvo = _img_corvo()
	_tex_anel = _img_anel()
	_tex_glifo = _img_glifo()
	var im := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	_aura_sp = Sprite2D.new()
	_aura_sp.texture = ImageTexture.create_from_image(im)
	var sh := Shader.new()
	sh.code = SHADER_AURA
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_aura_sp.material = mat
	_aura_sp.visible = false


func _img_lamina() -> Texture2D:
	var im := Image.create(26, 11, false, Image.FORMAT_RGBA8)
	for x in 26:
		var meia := 4.6 * (float(x) / 9.0 if x < 9 else float(25 - x) / 16.0)
		for y in 11:
			var dy := absf(float(y) - 5.0)
			if dy <= meia:
				im.set_pixel(x, y, Color(1, 1, 1, 1) if dy <= meia - 1.4 else Color(0.8, 0.95, 1.0, 0.85))
	return ImageTexture.create_from_image(im)


func _img_corvo() -> Texture2D:
	var im := Image.create(66, 18, false, Image.FORMAT_RGBA8)
	var corpo := Color(0.13, 0.08, 0.21)
	var asa := Color(0.22, 0.13, 0.33)
	for f in 3:
		var ox := f * 22
		var cima: float = [8.0, 3.0, -3.0][f]
		for y in 18:
			for x in 22:
				var dx := (float(x) - 9.0) / 7.0
				var dy := (float(y) - 10.0) / 3.6
				if dx * dx + dy * dy <= 1.0:
					im.set_pixel(ox + x, y, corpo)
				var hx := float(x) - 16.5
				var hy := float(y) - 8.5
				if hx * hx + hy * hy <= 7.0:
					im.set_pixel(ox + x, y, corpo)
				if x >= 2 and x <= 5 and y >= 9 and y <= 11:
					im.set_pixel(ox + x, y, corpo)  # cauda
				if x >= 19 and x <= 21 and y >= 8 and y <= 9:
					im.set_pixel(ox + x, y, Color(0.95, 0.6, 0.2))  # bico
				if x == 17 and y == 7:
					im.set_pixel(ox + x, y, Color(1.0, 0.25, 0.2))  # olho
		# asa: triângulo com a base no corpo e a ponta para cima ou para baixo
		var ay := 8.0 - cima
		for y in 18:
			for x in 22:
				var px := float(x)
				var py := float(y)
				if _no_triangulo(Vector2(px, py), Vector2(7, 9), Vector2(14, 9), Vector2(5, ay)):
					im.set_pixel(ox + x, y, asa)
	return ImageTexture.create_from_image(im)


static func _no_triangulo(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
	var d2 := (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
	var d3 := (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)
	var neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (neg and pos)


func _img_anel() -> Texture2D:
	var im := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var r := Vector2(float(x) - 31.5, float(y) - 31.5).length()
			if absf(r - 29.5) <= 1.2:
				im.set_pixel(x, y, Color(1, 1, 1, 0.95))
			elif absf(r - 19.0) <= 0.8:
				im.set_pixel(x, y, Color(1, 1, 1, 0.6))
	return ImageTexture.create_from_image(im)


func _img_glifo() -> Texture2D:
	var im := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var pts: Array = []
	for k in 3:
		pts.append(Vector2(31.5, 31.5) + Vector2.from_angle(-PI / 2.0 + TAU * float(k) / 3.0) * 19.0)
	for k in 3:
		var p0: Vector2 = pts[k]
		var p1: Vector2 = pts[(k + 1) % 3]
		for s in 40:
			var q := p0.lerp(p1, float(s) / 39.0)
			im.set_pixel(clampi(roundi(q.x), 0, 63), clampi(roundi(q.y), 0, 63), Color(1, 1, 1, 0.9))
	for y in range(30, 34):
		for x in range(30, 34):
			im.set_pixel(x, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(im)


func _eliptico(centro: Vector2, raio: float, n: int, rot := 0.0) -> PackedVector2Array:
	var v := PackedVector2Array()
	v.resize(n + 1)
	for i in n + 1:
		var a := TAU * float(i) / float(n) + rot
		v[i] = (centro + Vector2(cos(a) * raio, sin(a) * raio * ACHATA)).round()
	return v


## A aura de fogo (e o anel do Anel de Brasas): UM sprite com shader, na elipse do chão em volta do herói.
func _aura_visual(h) -> void:
	var raio := 0.0
	var cor := Color.WHITE
	var pulso := 0.0
	for id in ativas:
		var a: Dictionary = ativas[id]
		if str(a.tipo) == "aura" or (str(a.tipo) == "orbita" and a.st.has("aura_raio")):
			raio = maxf(raio, float(a.get("RA", a.R)))
			cor = a.cor
			pulso = maxf(pulso, float(a.pulso))
	_aura_sp.visible = raio > 0.0
	if raio <= 0.0:
		return
	_aura_sp.position = (h.pos + Vector2(0, -1)).round()
	_aura_sp.scale = Vector2(raio * 2.3 / 4.0, raio * 2.3 * ACHATA / 4.0)
	var mat := _aura_sp.material as ShaderMaterial
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("t", _fase)
	mat.set_shader_parameter("pulso", pulso)


func _desenhar_corpo() -> void:
	var t0 := Time.get_ticks_usec()
	_desenhar_corpo_i()
	us_desenho += Time.get_ticks_usec() - t0


func _desenhar_corpo_i() -> void:
	for id in ativas:
		var a: Dictionary = ativas[id]
		if str(a.tipo) != "orbita":
			continue
		for p in a.pts as PackedVector2Array:  # sombra de cada lâmina no chão
			no_corpo.draw_texture_rect(tex_brilho, Rect2(p + Vector2(-7, -1), Vector2(14, 6)), false, Color(0, 0, 0, 0.45))
	for i in MAX_CORVOS:
		if c_vida[i] <= 0.0:
			continue
		var p: Vector2 = c_pos[i]
		no_corpo.draw_texture_rect(tex_brilho, Rect2(p + Vector2(-8, -2), Vector2(16, 7)), false, Color(0, 0, 0, 0.45))
		var c := (p + Vector2(0, -c_z[i])).round()
		var lado := 1.0 if c_vel[i].x >= 0.0 else -1.0
		var quadro: int = [0, 1, 2, 1][int(c_fase[i] / 1.57) & 3]
		var r := Rect2(c + Vector2(-16.5 * lado, -13.5), Vector2(33.0 * lado, 27.0))
		no_corpo.draw_texture_rect_region(_tex_corvo, r, Rect2(quadro * 22, 0, 22, 18))


func _desenhar_brilho() -> void:
	var t0 := Time.get_ticks_usec()
	_desenhar_brilho_i()
	us_desenho += Time.get_ticks_usec() - t0


func _desenhar_brilho_i() -> void:
	for id in ativas:
		var a: Dictionary = ativas[id]
		if str(a.tipo) == "orbita":
			_desenhar_laminas(a)
	for i in MAX_CORVOS:  # um brilho roxo em volta (e azul se for elétrico)
		if c_vida[i] <= 0.0:
			continue
		var c := (c_pos[i] + Vector2(0, -c_z[i])).round()
		var cor := Color(0.6, 0.35, 1.0, 0.3)
		if c_arma[i] != null and (c_arma[i] as Dictionary).st.has("eletrico"):
			cor = Color(0.6, 0.8, 1.0, 0.4)
		no_brilho.draw_texture_rect(tex_brilho, Rect2(c - Vector2(15, 15), Vector2(30, 30)), false, cor)
	for i in MAX_RUNAS:
		if r_vida[i] > 0.0:
			_desenhar_runa(i)
	for i in MAX_RAIOS:
		if z_t[i] >= z_dur[i]:
			continue
		var k := 1.0 - z_t[i] / z_dur[i]
		var pts := PackedVector2Array()
		var base := i * PTS
		for j in z_n[i]:
			pts.append(z_pts[base + j].round())
		no_brilho.draw_polyline(pts, Color(0.5, 0.7, 1.0, 0.35 * k), 7.0)
		no_brilho.draw_polyline(pts, Color(0.75, 0.88, 1.0, 0.9 * k), 3.0)
		no_brilho.draw_polyline(pts, Color(1, 1, 1, k), 1.0)
	for i in MAX_ONDAS:
		if w_dist[i] <= 0.0:
			continue
		var p: Vector2 = w_pos[i]
		var dir: Vector2 = w_dir[i]
		var fade := clampf(w_dist[i] / 40.0, 0.0, 1.0)
		if w_tipo[i] == 0:
			var r := w_larg[i] * 0.5
			var ang := dir.angle()
			for q in 3:
				var recuo := float(q) * 6.0
				var arco := PackedVector2Array()
				for s in 11:
					var aa := ang + lerpf(-1.1, 1.1, float(s) / 10.0)
					arco.append((p - dir * recuo + Vector2.from_angle(aa) * r * (1.0 - 0.25 * absf(lerpf(-1.0, 1.0, float(s) / 10.0)))).round())
				no_brilho.draw_polyline(arco, Color(0.75, 1.0, 0.95, (0.95 - 0.3 * q) * fade), 3.0 - q)
			no_brilho.draw_texture_rect(tex_brilho, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(0.5, 1.0, 0.9, 0.18 * fade))
		else:
			no_brilho.draw_line((p - dir * 30.0).round(), p.round(), Color(0.6, 0.95, 1.0, 0.35 * fade), 7.0)
			no_brilho.draw_line((p - dir * 22.0).round(), (p + dir * 8.0).round(), Color(1, 1, 1, 0.95 * fade), 2.0)
			no_brilho.draw_texture_rect(tex_brilho, Rect2(p - Vector2(12, 12), Vector2(24, 24)), false, Color(0.6, 1.0, 0.95, 0.4 * fade))


func _desenhar_laminas(a: Dictionary) -> void:
	var pts: PackedVector2Array = a.pts
	var n := pts.size()
	var cor: Color = a.cor
	var evo: bool = a.evo
	var R := float(a.R)
	var tinta := cor.lerp(Color.WHITE, 0.35)
	for i in n:
		var ang := float(a.ang) + TAU * float(i) / float(n)
		var p := (pts[i] + Vector2(0, -14)).round()
		var tang := Vector2(-sin(ang) * R, cos(ang) * R * ACHATA).normalized()
		for q in 2:  # rastro: duas luzinhas atrás no círculo
			var aa := ang - float(q + 1) * 0.2
			var pp := p + Vector2(cos(aa) - cos(ang), (sin(aa) - sin(ang)) * ACHATA) * R
			no_brilho.draw_texture_rect(tex_brilho, Rect2(pp.round() - Vector2(8, 8), Vector2(16, 16)), false, Color(cor.r, cor.g, cor.b, 0.26 - 0.09 * q))
		no_brilho.draw_texture_rect(tex_brilho, Rect2(p - Vector2(17, 17), Vector2(34, 34)), false, Color(cor.r, cor.g, cor.b, 0.55 if evo else 0.42))
		no_brilho.draw_set_transform(p, tang.angle(), Vector2(1.15, 1.15))
		no_brilho.draw_texture(_tex_lamina, Vector2(-13, -5.5), tinta)
		no_brilho.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_runa(i: int) -> void:
	var a: Dictionary = r_arma[i]
	var p: Vector2 = r_pos[i]
	var cor: Color = a.cor
	var idade := r_t[i]
	var armada := idade >= 0.5
	var raio := float(a.st.explosao) * 0.42
	var surge := clampf(idade / 0.3, 0.0, 1.0)
	var fade := clampf(r_vida[i] / 0.8, 0.0, 1.0)
	var pulso := 0.7 + 0.3 * sin(_fase * 6.0 + float(i))
	var al := surge * fade * (pulso if armada else 0.5)
	no_brilho.draw_texture_rect(
		tex_brilho, Rect2(p - Vector2(raio, raio * ACHATA) * 1.5, Vector2(raio, raio * ACHATA) * 3.0), false, Color(cor.r, cor.g, cor.b, 0.22 * al)
	)
	var esc := raio * surge / 29.5
	var rot := _fase * 1.3
	# a runa está no chão: roda no plano e depois achata o y (matriz: gira, depois ACHATA)
	no_brilho.draw_set_transform_matrix(Transform2D(Vector2(cos(rot), sin(rot) * ACHATA) * esc, Vector2(-sin(rot), cos(rot) * ACHATA) * esc, p.round()))
	no_brilho.draw_texture(_tex_glifo, Vector2(-31.5, -31.5), Color(1, 1, 1, 0.6 * al))
	no_brilho.draw_set_transform_matrix(Transform2D(Vector2(esc, 0), Vector2(0, esc * ACHATA), p.round()))
	no_brilho.draw_texture(_tex_anel, Vector2(-31.5, -31.5), Color(cor.r, cor.g, cor.b, 0.9 * al))
	no_brilho.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
