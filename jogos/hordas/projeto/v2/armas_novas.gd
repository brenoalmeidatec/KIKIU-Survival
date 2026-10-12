extends RefCounted
## Golpes secundários novos da v2 (leva 5): cinco tipos que `v2/armas.gd` chama pelo nome do golpe (dados/v2_cartas.json > "golpes").
##   projetil: a cada recarga, tiros no inimigo mais perto (perfura N inimigos; explosao = área no impacto).
##   nuvem:    a cada recarga, uma nuvem cai perto de um inimigo, fica `duracao` s e dá dano em tiques (lentidao opcional).
##   anel:     a cada recarga, um anel de choque sai do herói e cresce até `raio`; cada inimigo é atingido uma vez.
##   meteoro:  a cada recarga, meteoros marcam o chão (aviso) e caem em área perto de inimigos.
##   aliado:   a cada recarga, espíritos perseguem o inimigo mais perto e dão dano em tiques ao tocar.
## Tudo em um pool fixo (MAX slots, dicionários reaproveitados): nenhum nó, nenhuma alocação por quadro. O desenho usa a textura
## de brilho que o `armas.gd` já tem, em modo aditivo (camada no_brilho). O `armas.gd` guarda o pai (`pai`) para usar o dano em área
## (`_dano_area`) e a explosão (`explodir`), e o combate (`ferir`) para o dano direto.

const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x (igual ao armas.gd)
const MAX := 48
const RAIO_PROJ := 10.0

var pai  # v2/armas.gd
var itens: Array = []  # o pool: cada slot é um dicionário fixo; vida <= 0 é livre


func montar(p) -> void:
	pai = p
	itens.clear()
	for i in MAX:
		itens.append({"k": "", "a": null, "vida": 0.0, "p": Vector2.ZERO, "v": Vector2.ZERO, "t": 0.0, "r": 0.0, "fase": 0.0, "pen": 0, "hit": []})


func limpar() -> void:
	for it in itens:
		it.vida = 0.0


func remover(a: Dictionary) -> void:
	for it in itens:
		if is_same(it.a, a):
			it.vida = 0.0


func tem_ativos() -> bool:
	for it in itens:
		if float(it.vida) > 0.0:
			return true
	return false


# ------------------------------------------------------------------ o timer de recarga (chamado por golpe, como as outras famílias)


## Conta a recarga do golpe `a` e, quando ela zera, dispara. Sem inimigo por perto, espera um pouco e não gasta a recarga.
func golpe(a: Dictionary, h, dt: float, vel_a: float, perto: Array) -> void:
	a.t = float(a.t) - dt
	if float(a.t) > 0.0:
		return
	if perto.is_empty():
		a.t = 0.3
		return
	var st: Dictionary = a.st
	a.t = float(st.recarga) / vel_a
	match str(a.tipo):
		"projetil":
			_disparar(a, h, perto)
		"nuvem":
			_nuvem(a, h, perto)
		"anel":
			_anel(a, h)
		"meteoro":
			_meteoros(a, h, perto)
		"aliado":
			_aliados(a, h)


# ------------------------------------------------------------------ o quadro (movimento e dano)


## Um passo de todos os itens do pool. `h` é o herói; `perto` são os monstros dentro de 340 px (lista que o armas.gd monta).
func quadro(h, dt: float, perto: Array) -> void:
	for it in itens:
		if float(it.vida) <= 0.0:
			continue
		it.vida = float(it.vida) - dt
		it.fase = float(it.fase) + dt * 6.0
		match str(it.k):
			"projetil":
				_mover_projetil(it, dt, perto)
			"nuvem":
				_tique_nuvem(it, dt)
			"anel":
				_mover_anel(it, h, dt, perto)
			"meteoro":
				_cair_meteoro(it, dt)
			"aliado":
				_mover_aliado(it, h, dt, perto)


# ------------------------------------------------------------------ tipos


func _disparar(a: Dictionary, h, perto: Array) -> void:
	var st: Dictionary = a.st
	var alvo = _mais_perto(h.pos, float(st.alcance), perto)
	if alvo == null:
		return
	var direcao: Vector2 = (alvo.pos - h.pos).normalized()
	var n := int(st.quantidade)
	for k in n:
		var it := _novo("projetil", a, h.pos + Vector2(0, -14), 1.6)
		if it.is_empty():
			return
		var ang := (float(k) - (n - 1) * 0.5) * 0.14  # tiros em leque curto
		it.v = direcao.rotated(ang) * float(st.vel)
		it.pen = int(st.get("perfura", 0.0))


func _mover_projetil(it: Dictionary, dt: float, perto: Array) -> void:
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	it.p = it.p + it.v * dt
	var p: Vector2 = it.p
	for m in perto:
		if not m.vivo or m.morrendo or (it.hit as Array).has(m):
			continue
		if _eli(m.pos - p).length() > RAIO_PROJ + float(m.raio):
			continue
		(it.hit as Array).append(m)
		var dir: Vector2 = (it.v as Vector2).normalized()
		var dano := _dano(st)
		pai.combate.ferir(m, dano, dir, 40.0, 0.1, _cor_num(a.cor))
		pai._acertou("projetil")
		var ex := float(st.get("explosao", 0.0))
		if ex > 0.0:
			pai.explodir(m.pos, dano, ex, a.cor, m)
		if int(it.pen) <= 0:
			it.vida = 0.0
			return
		it.pen = int(it.pen) - 1


func _nuvem(a: Dictionary, h, perto: Array) -> void:
	var st: Dictionary = a.st
	var alvo = _mais_perto(h.pos, float(st.alcance) * 1.6, perto)
	if alvo == null:
		return
	var it := _novo("nuvem", a, alvo.pos, float(st.duracao))
	if it.is_empty():
		return
	it.r = float(st.raio)
	it.t = 0.05  # o primeiro tique já vem logo


func _tique_nuvem(it: Dictionary, dt: float) -> void:
	it.t = float(it.t) - dt
	if float(it.t) > 0.0:
		return
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	it.t = float(st.tique)
	pai._dano_area(it.p, float(it.r), _dano(st), 30.0, 0.0, a.cor, "nuvem", float(st.get("lentidao", 0.0)))


func _anel(a: Dictionary, h) -> void:
	var st: Dictionary = a.st
	var it := _novo("anel", a, h.pos, float(st.raio) / float(st.vel) + 0.05)
	if it.is_empty():
		return
	it.r = 0.0


func _mover_anel(it: Dictionary, h, dt: float, perto: Array) -> void:
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	it.r = float(it.r) + float(st.vel) * dt
	it.p = h.pos  # o anel sai do herói e anda com ele
	var c: Vector2 = it.p
	var r := float(it.r)
	for m in perto:
		if not m.vivo or m.morrendo or (it.hit as Array).has(m):
			continue
		if absf(_eli(m.pos - c).length() - r) > 14.0 + float(m.raio):
			continue
		(it.hit as Array).append(m)
		var dir: Vector2 = (m.pos - c).normalized()
		pai.combate.ferir(m, _dano(st), dir, float(st.get("empurra", 0.0)), 0.15, _cor_num(a.cor))
		pai._acertou("anel")
	if r >= float(st.raio):
		it.vida = 0.0


func _meteoros(a: Dictionary, h, perto: Array) -> void:
	var st: Dictionary = a.st
	for k in int(st.quantidade):
		var alvo = perto[randi() % perto.size()]
		var it := _novo("meteoro", a, alvo.pos, float(st.aviso) + 0.3)
		if it.is_empty():
			return
		it.t = float(st.aviso)  # o aviso no chão antes da queda


func _cair_meteoro(it: Dictionary, dt: float) -> void:
	if float(it.t) <= 0.0:
		return  # já caiu: só o estouro sobra
	it.t = float(it.t) - dt
	if float(it.t) > 0.0:
		return
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	pai.explodir(it.p, _dano(st), float(st.raio), a.cor)
	it.vida = 0.3  # o estouro fica um pouco


func _aliados(a: Dictionary, h) -> void:
	var st: Dictionary = a.st
	for k in int(st.quantidade):
		var deslocado: Vector2 = h.pos + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0))
		var it := _novo("aliado", a, deslocado, float(st.duracao))
		if it.is_empty():
			return
		it.t = 0.0


func _mover_aliado(it: Dictionary, h, dt: float, perto: Array) -> void:
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	it.t = float(it.t) - dt
	var alvo = _mais_perto(it.p, 400.0, perto)
	var dest: Vector2
	if alvo != null:
		dest = alvo.pos
	else:
		dest = h.pos + Vector2.from_angle(float(it.fase)) * 50.0  # sem inimigo, gira em volta do herói
	var d: Vector2 = dest - it.p
	if d.length() > 1.0:
		it.p = it.p + d.normalized() * minf(float(st.vel) * dt, d.length())
	if alvo != null and float(it.t) <= 0.0 and _eli(alvo.pos - it.p).length() < 12.0 + float(alvo.raio):
		it.t = float(st.tique)
		var dir: Vector2 = (alvo.pos - it.p).normalized()
		pai.combate.ferir(alvo, _dano(st), dir, 30.0, 0.05, _cor_num(a.cor))
		pai._acertou("aliado")


# ------------------------------------------------------------------ desenho (camada aditiva no_brilho)


func desenhar(ci: CanvasItem, tex: Texture2D) -> void:
	for it in itens:
		if float(it.vida) <= 0.0:
			continue
		var a: Dictionary = it.a
		var st: Dictionary = a.st
		var cor: Color = a.cor
		var p: Vector2 = (it.p as Vector2).round()
		match str(it.k):
			"projetil":
				var dir: Vector2 = (it.v as Vector2).normalized()
				ci.draw_line((p - dir * 9.0).round(), p, Color(cor.r, cor.g, cor.b, 0.45), 4.0)
				ci.draw_line((p - dir * 6.0).round(), p, Color(1, 1, 1, 0.9), 1.5)
				ci.draw_texture_rect(tex, Rect2(p - Vector2(7, 7), Vector2(14, 14)), false, Color(cor.r, cor.g, cor.b, 0.5))
			"nuvem":
				var fade := clampf(float(it.vida) / 0.6, 0.0, 1.0) * clampf((float(st.duracao) - float(it.vida)) / 0.3, 0.0, 1.0)
				var pulso := 0.85 + 0.15 * sin(float(it.fase))
				ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
				ci.draw_circle(Vector2.ZERO, float(it.r) * pulso, Color(cor.r, cor.g, cor.b, 0.22 * fade))
				ci.draw_circle(Vector2.ZERO, float(it.r) * 0.55 * pulso, Color(cor.r, cor.g, cor.b, 0.3 * fade))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"anel":
				var r := float(it.r)
				var fade_a := clampf(1.0 - r / float(st.raio), 0.0, 1.0)
				ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
				ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(cor.r, cor.g, cor.b, 0.85 * fade_a), 3.0)
				ci.draw_arc(Vector2.ZERO, maxf(r - 4.0, 0.5), 0.0, TAU, 48, Color(1, 1, 1, 0.45 * fade_a), 1.5)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"meteoro":
				var raio := float(st.raio)
				if float(it.t) > 0.0:
					var k := 1.0 - float(it.t) / float(st.aviso)
					var pisca := 0.5 + 0.5 * sin(float(it.fase) * 2.0)
					ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
					ci.draw_arc(Vector2.ZERO, raio * (1.0 - 0.4 * k), 0.0, TAU, 32, Color(cor.r, cor.g, cor.b, 0.5 + 0.4 * pisca), 2.0)
					ci.draw_circle(Vector2.ZERO, raio * 0.35 * k, Color(cor.r, cor.g, cor.b, 0.25 * k))
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					var bola: Vector2 = (p + Vector2(0, -80.0 * (1.0 - k))).round()
					ci.draw_texture_rect(tex, Rect2(bola - Vector2(9, 9), Vector2(18, 18)), false, Color(cor.r, cor.g, cor.b, 0.7))
					ci.draw_circle(bola, 4.0, Color(1, 1, 1, 0.9))
				else:
					var sumindo := clampf(float(it.vida) / 0.3, 0.0, 1.0)
					ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
					ci.draw_circle(Vector2.ZERO, raio * (1.2 - 0.4 * sumindo), Color(cor.r, cor.g, cor.b, 0.35 * sumindo))
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"aliado":
				var sobe := (p + Vector2(0, -10.0 + sin(float(it.fase)) * 2.0)).round()
				var alfa := clampf(float(it.vida) / 0.5, 0.0, 1.0)
				ci.draw_texture_rect(tex, Rect2(sobe - Vector2(10, 10), Vector2(20, 20)), false, Color(cor.r, cor.g, cor.b, 0.6 * alfa))
				ci.draw_circle(sobe, 2.5, Color(1, 1, 1, 0.95 * alfa))


# ------------------------------------------------------------------ auxiliares


func _novo(k: String, a: Dictionary, p: Vector2, vida: float) -> Dictionary:
	var it := {}
	for x in itens:
		if float(x.vida) <= 0.0:
			it = x
			break
	if it.is_empty():
		return it
	it.k = k
	it.a = a
	it.p = p
	it.v = Vector2.ZERO
	it.vida = vida
	it.t = 0.0
	it.r = 0.0
	it.fase = randf() * TAU
	it.pen = 0
	(it.hit as Array).clear()
	return it


## Dano do golpe com o multiplicador de dano do herói (o mesmo que os corvos usam).
func _dano(st: Dictionary) -> float:
	return float(st.dano) * float(pai.mundo.heroi.m_dano)


func _cor_num(c: Color) -> Color:
	return c.lerp(Color.WHITE, 0.45)


## Vetor no plano achatado (y dividido por ACHATA), para medir distância como o resto da v2 faz.
static func _eli(d: Vector2) -> Vector2:
	return Vector2(d.x, d.y / ACHATA)


## O monstro mais perto de `p` dentro de `alc` px (no plano achatado), ignorando os que estão morrendo.
func _mais_perto(p: Vector2, alc: float, perto: Array):
	var melhor = null
	var md := alc * alc
	for m in perto:
		if not m.vivo or m.morrendo:
			continue
		var d2 := _eli(m.pos - p).length_squared()
		if d2 < md:
			md = d2
			melhor = m
	return melhor
