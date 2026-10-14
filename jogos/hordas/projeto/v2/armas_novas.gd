extends RefCounted
## Golpes secundários novos da v2 (leva 5): cinco tipos que `v2/armas.gd` chama pelo nome do golpe (dados/v2_cartas.json > "golpes").
##   projetil: a cada recarga, tiros no inimigo mais perto (perfura N inimigos; explosao = área no impacto).
##   nuvem:    a cada recarga, uma nuvem cai perto de um inimigo, fica `duracao` s e dá dano em tiques (lentidao opcional).
##   anel:     a cada recarga, um anel de choque sai do herói e cresce até `raio`; cada inimigo é atingido uma vez (`lento_s`, opcional: segundos de lentidão).
##   meteoro:  a cada recarga, meteoros marcam o chão (aviso) e caem em área perto de inimigos.
##   aliado:   a cada recarga, espíritos perseguem o inimigo mais perto e dão dano em tiques ao tocar.
## Tudo em um pool fixo (MAX slots, dicionários reaproveitados): nenhum nó, nenhuma alocação por quadro. O desenho usa a textura
## de brilho que o `armas.gd` já tem, em modo aditivo (camada no_brilho). O `armas.gd` guarda o pai (`pai`) para usar o dano em área
## (`_dano_area`) e a explosão (`explodir`), e o combate (`ferir`) para o dano direto.

const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x (igual ao armas.gd)
const MAX := 48
const RAIO_PROJ := 10.0
const PASTA_SPRITES := "res://assets/v2/armas/"
static var _tex_fumaca: Texture2D
static var _sprites: Dictionary = {}
static var _lidos := false

var pai  # v2/armas.gd
var itens: Array = []  # o pool: cada slot é um dicionário fixo; vida <= 0 é livre


func montar(p) -> void:
	pai = p
	carregar_sprites()
	itens.clear()
	for i in MAX:
		itens.append(
			{
				"k": "",
				"a": null,
				"sp": {},
				"vida": 0.0,
				"p": Vector2.ZERO,
				"v": Vector2.ZERO,
				"t": 0.0,
				"r": 0.0,
				"fase": 0.0,
				"pen": 0,
				"hit": [],
				"pulso": 0.0
			}
		)


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


# ------------------------------------------------------------------ sprites (assets/v2/armas/indice.json)


## Lê o índice uma vez por processo: cada arma aponta para o seu {tex, tam, tipo} (sugeridas e aproximadas). Sprite que não carrega
## fica de fora (o golpe segue com a forma antiga). Com normal map, a textura é um CanvasTexture: a luz 2D age nela.
static func carregar_sprites() -> void:
	if _lidos:
		return
	_lidos = true
	var d = JSON.parse_string(FileAccess.get_file_as_string(PASTA_SPRITES.path_join("indice.json")))
	if not (d is Dictionary):
		return
	for nome in d.get("sprites", {}):
		var s: Dictionary = d.sprites[nome]
		var tex := load(PASTA_SPRITES.path_join(str(s.arquivo))) as Texture2D
		if tex == null:
			continue
		if s.get("normal") != null:
			var ct := CanvasTexture.new()
			ct.diffuse_texture = tex
			ct.normal_texture = load(PASTA_SPRITES.path_join(str(s.normal))) as Texture2D
			tex = ct
		var entrada := {"tex": tex, "tam": Vector2(float(s.tamanho[0]), float(s.tamanho[1])), "tipo": str(s.tipo)}
		for arma in s.armas_sugeridas + s.armas_aproximadas:
			_sprites[str(arma)] = entrada


## Sprite do golpe `id` ({tex, tam, tipo}), ou {} quando a arma não tem sprite.
static func sprite_de(id: String) -> Dictionary:
	carregar_sprites()
	return _sprites.get(id, {})


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
		it.pulso = maxf(0.0, float(it.pulso) - dt * 4.0)
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
	var saida: Vector2 = h.pos + Vector2(0, -14)  # o tiro sai do alto do herói, então a mira parte dali (senão a trajetória fica deslocada)
	var direcao: Vector2 = (alvo.pos - saida).normalized()
	var n := int(st.quantidade)
	for k in n:
		var it := _novo("projetil", a, saida, 1.6)
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
		if st.has("puxa"):  # a tempestade: cada impacto puxa os inimigos próximos para o ponto
			_puxar(m.pos, float(st.get("puxa_raio", 90.0)), float(st.puxa))
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
	var alvos := 0
	var dano_total := 0.0
	for m in pai.mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		if not pai.na_elipse(m.pos - it.p, float(it.r) + m.raio):
			continue
		var dano := _dano(st)
		if st.has("gelo_mult") and m.lento_t > 0.0:  # o furacão: quem já está lento dentro leva dano em dobro
			dano *= float(st.gelo_mult)
		var vida_antes := float(m.vida)
		var fora: Vector2 = (m.pos - it.p).normalized() if m.pos.distance_squared_to(it.p) > 0.25 else Vector2.RIGHT
		pai.combate.ferir(m, dano, fora, 30.0, 0.0, _cor_num(a.cor))
		var aplicado := maxf(0.0, vida_antes - float(m.vida))
		if float(st.get("lentidao", 0.0)) > 0.0:
			m.deixar_lento(float(st.lentidao))
		alvos += 1
		dano_total += aplicado
		if st.has("gelo_mult"):
			pai._acertou("nuvem")  # o golpe de gelo contava cada inimigo atingido
	if alvos > 0:
		if not st.has("gelo_mult"):
			pai._acertou("nuvem")  # o dano de área comum contava um evento por tique
	if dano_total > 0.0:
		# O brilho acompanha a vida realmente removida; um tique sem alvo ou sem dano não pulsa.
		it.pulso = clampf(dano_total / maxf(1.0, _dano(st) * 4.0), 0.0, 1.0)


## Puxa os monstros dentro de `raio` até `forca` px na direção de `p` (a tempestade primordial).
func _puxar(p: Vector2, raio: float, forca: float) -> void:
	for m in pai.mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var d: Vector2 = p - m.pos
		if _eli(d).length() > raio:
			continue
		m.pos = m.pos + d.normalized() * minf(forca, d.length())


## Dano do golpe; se o monstro já está lento e a arma tem `mult_lento`, o dano sobe (combo de lentidão).
func _dano_em(m, st: Dictionary) -> float:
	var d := _dano(st)
	if st.has("mult_lento") and m.lento_t > 0.0:
		d *= float(st.mult_lento)
	return d


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
		var lento := float(st.get("lento_s", 0.0))  # o gelo: segundos de lentidão no monstro atingido
		if lento > 0.0:
			m.deixar_lento(lento)
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
		it["filho"] = false


func _cair_meteoro(it: Dictionary, dt: float) -> void:
	if float(it.t) <= 0.0:
		return  # já caiu: só o estouro sobra
	it.t = float(it.t) - dt
	if float(it.t) > 0.0:
		return
	var a: Dictionary = it.a
	var st: Dictionary = a.st
	pai.explodir(it.p, _dano(st), float(st.raio), a.cor)
	if st.has("cadeia") and not bool(it.get("filho", false)):  # o juízo: cada queda chama outro meteoro no inimigo mais perto
		var alvo = _mais_perto(it.p, 400.0, pai.mundo.monstros)
		if alvo != null:
			var f := _novo("meteoro", a, alvo.pos, float(st.aviso) + 0.3)
			if not f.is_empty():
				f.t = float(st.aviso)
				f["filho"] = true  # o filho não chama outro: a corrente tem só um elo
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
		var dano := _dano_em(alvo, st)
		if st.has("prende"):  # o eclipse: o toque prende o inimigo na sombra
			alvo.deixar_lento(float(st.prende))
		pai.combate.ferir(alvo, dano, dir, 30.0, 0.05, _cor_num(a.cor))
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
				_desenhar_projetil(ci, it, tex, cor, p, dir)
			"nuvem":
				var sp: Dictionary = it.sp
				if not sp.is_empty():
					var fade := opacidade_nuvem(float(it.vida), float(st.duracao))
					_area(ci, sp, p, float(it.r), Color(1, 1, 1, 0.035 * fade))
				_desenhar_pulso_nuvem(ci, it, st, p)
			"anel":
				var r := float(it.r)
				var fade_a := clampf(1.0 - r / float(st.raio), 0.0, 1.0)
				var sp: Dictionary = it.sp
				if not sp.is_empty():
					_area(ci, sp, p, r, Color(1, 1, 1, 0.12 * fade_a))
				ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
				ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(cor.r, cor.g, cor.b, 0.85 * fade_a), 3.0)
				ci.draw_arc(Vector2.ZERO, maxf(r - 4.0, 0.5), 0.0, TAU, 48, Color(1, 1, 1, 0.45 * fade_a), 1.5)
				_desenhar_motivo_anel(ci, str(a.get("id", "")), r, float(it.fase), fade_a, cor)
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
					_desenhar_meteoro(ci, it, tex, cor, bola, k)
				else:
					var sumindo := clampf(float(it.vida) / 0.3, 0.0, 1.0)
					ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
					ci.draw_circle(Vector2.ZERO, raio * (1.2 - 0.4 * sumindo), Color(cor.r, cor.g, cor.b, 0.35 * sumindo))
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"aliado":
				var sobe := (p + Vector2(0, -10.0 + sin(float(it.fase)) * 2.0)).round()
				var alfa := clampf(float(it.vida) / 0.5, 0.0, 1.0)
				ci.draw_texture_rect(tex, Rect2(sobe - Vector2(10, 10), Vector2(20, 20)), false, Color(cor.r, cor.g, cor.b, 0.6 * alfa))
				ci.draw_circle(sobe + Vector2(0, 2), 4.5, Color(cor.r, cor.g, cor.b, 0.35 * alfa))
				ci.draw_circle(sobe + Vector2(0, -2), 2.5, Color(1, 1, 1, 0.95 * alfa))
				if str(a.id) == "fantasma_mata" or str(a.id) == "lobo_espirito":
					ci.draw_circle(sobe + Vector2(-2, -2), 0.8, Color(0.18, 0.2, 0.35, alfa))
					ci.draw_circle(sobe + Vector2(2, -2), 0.8, Color(0.18, 0.2, 0.35, alfa))


func desenhar_corpo(ci: CanvasItem, tex: Texture2D) -> void:
	for it in itens:
		if float(it.vida) <= 0.0 or str(it.k) != "nuvem":
			continue
		_desenhar_nuvem(ci, it, it.a.st, it.a.cor, tex, (it.p as Vector2).round())


## Camada normal (`no_corpo`, a das sombras e dos corvos, que recebe a luz 2D): o sprite de projétil (virado para o voo), de meteoro
## que cai (com a ponta para baixo) e de aliado (de pé, flutuando).
func desenhar_sprites(ci: CanvasItem) -> void:
	for it in itens:
		var sp: Dictionary = it.sp
		if float(it.vida) <= 0.0 or sp.is_empty():
			continue
		var p: Vector2 = (it.p as Vector2).round()
		match str(it.k):
			"projetil":
				_sprite(ci, sp, p, (it.v as Vector2).angle())
			"meteoro":
				if float(it.t) > 0.0:
					_sprite(ci, sp, _queda(it), PI * 0.5)
			"aliado":
				var sobe := (p + Vector2(0, -10.0 + sin(float(it.fase)) * 2.0)).round()
				_sprite(ci, sp, sobe, 0.0, Color(1, 1, 1, clampf(float(it.vida) / 0.5, 0.0, 1.0)))


## O sprite centrado em `c`, girado `ang` (o projétil aponta para a direção do voo).
func _sprite(ci: CanvasItem, sp: Dictionary, c: Vector2, ang: float, cor: Color = Color.WHITE) -> void:
	var tam: Vector2 = sp.tam
	ci.draw_set_transform(c, ang, Vector2.ONE)
	ci.draw_texture_rect(sp.tex, Rect2(-(tam * 0.5).floor(), tam), false, cor)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Área com sprite (nuvem e anel): ocupa o diâmetro 2r do golpe; a altura segue a proporção do sprite.
func _area(ci: CanvasItem, sp: Dictionary, c: Vector2, r: float, cor: Color) -> void:
	var tam: Vector2 = sp.tam
	var alt := r * 2.0 * tam.y / tam.x
	ci.draw_texture_rect(sp.tex, Rect2((c - Vector2(r, alt * 0.5)).round(), Vector2(r * 2.0, alt).round()), false, cor)


## Posição do meteoro que cai: sobe 80 px no início do aviso e desce até o chão.
func _queda(it: Dictionary) -> Vector2:
	var st: Dictionary = it.a.st
	var k := 1.0 - float(it.t) / float(st.aviso)
	return ((it.p as Vector2).round() + Vector2(0, -80.0 * (1.0 - k))).round()


# ------------------------------------------------------------------ auxiliares


func _desenhar_projetil(ci: CanvasItem, it: Dictionary, tex: Texture2D, cor: Color, p: Vector2, dir: Vector2) -> void:
	var id := str(it.a.get("id", ""))
	match id:
		"bola_fogo":
			ci.draw_line((p - dir * 13.0).round(), p, Color(1.0, 0.3, 0.05, 0.55), 5.0)
			ci.draw_circle(p, 7.0, Color(1.0, 0.28, 0.04, 0.45))
			ci.draw_circle(p, 3.4, Color(1.0, 0.88, 0.35, 0.95))
			ci.draw_texture_rect(tex, Rect2(p - Vector2(7, 7), Vector2(14, 14)), false, Color(1.0, 0.52, 0.12, 0.42))
		"dardos_peconhentos":
			var cauda := (p - dir * 8.0).round()
			ci.draw_line(cauda, p, Color(0.25, 0.75, 0.14, 0.82), 3.0)
			ci.draw_circle(cauda, 2.0, Color(0.7, 1.0, 0.25, 0.72))
			ci.draw_line((p - dir * 4.0).round(), p + dir * 3.0, Color(0.88, 1.0, 0.6, 0.95), 1.5)
		"lanca_geada":
			ci.draw_line((p - dir * 12.0).round(), p + dir * 5.0, Color(0.48, 0.85, 1.0, 0.88), 3.0)
			var lado := dir.orthogonal() * 3.0
			ci.draw_line((p - lado).round(), (p + lado).round(), Color(0.9, 1.0, 1.0, 0.9), 1.5)
			ci.draw_circle(p, 3.0, Color(0.9, 1.0, 1.0, 0.78))
		"estrelas_sombra", "flechas_sombrias":
			var giro := float(it.fase) * (7.0 if id == "estrelas_sombra" else 1.5)
			for ponta in 4:
				var raio := Vector2.from_angle(giro + TAU * float(ponta) / 4.0) * (7.0 if ponta % 2 == 0 else 3.0)
				ci.draw_line((p - dir * 5.0).round(), (p + raio).round(), Color(0.76, 0.58, 1.0, 0.8), 1.5)
			ci.draw_circle(p, 2.0, Color(0.14, 0.1, 0.22, 0.95))
		_:
			ci.draw_line((p - dir * 9.0).round(), p, Color(cor.r, cor.g, cor.b, 0.45), 4.0)
			ci.draw_line((p - dir * 6.0).round(), p, Color(1, 1, 1, 0.9), 1.5)
			ci.draw_texture_rect(tex, Rect2(p - Vector2(7, 7), Vector2(14, 14)), false, Color(cor.r, cor.g, cor.b, 0.5))


func _desenhar_motivo_anel(ci: CanvasItem, id: String, r: float, fase: float, alfa: float, cor: Color) -> void:
	match id:
		"martelo_trovao":
			for n in 4:
				var ang := fase * 0.25 + TAU * float(n) / 4.0
				var fora := Vector2.from_angle(ang) * r
				var dentro := Vector2.from_angle(ang + 0.12) * (r - 9.0)
				ci.draw_line(fora, dentro, Color(0.95, 1.0, 1.0, 0.9 * alfa), 2.0)
		"anel_gelado":
			for n in 4:
				var ang := fase * 0.18 + TAU * float(n) / 4.0
				var ponta := Vector2.from_angle(ang) * r
				var base := Vector2.from_angle(ang) * (r - 7.0)
				var lado := Vector2.from_angle(ang + PI * 0.5) * 3.0
				ci.draw_line(base - lado, ponta, Color(0.92, 1.0, 1.0, 0.88 * alfa), 1.5)
				ci.draw_line(base + lado, ponta, Color(0.92, 1.0, 1.0, 0.88 * alfa), 1.5)
		"terremoto":
			for n in 3:
				var ang := float(n) * 2.1 + 0.2
				var base := Vector2.from_angle(ang) * (r - 13.0)
				var ponta := Vector2.from_angle(ang + 0.16) * (r + 2.0)
				ci.draw_line(base, ponta, Color(0.82, 0.75, 0.62, 0.7 * alfa), 1.5)


func _desenhar_meteoro(ci: CanvasItem, it: Dictionary, tex: Texture2D, cor: Color, p: Vector2, k: float) -> void:
	var id := str(it.a.get("id", ""))
	var fade := clampf(float(it.vida) / 0.3, 0.0, 1.0)
	match id:
		"meteoro_flamejante", "fogo_do_ceu", "pedras_vulcanicas":
			ci.draw_line(p + Vector2(-4, -14), p + Vector2(3, 9), Color(1.0, 0.24, 0.05, 0.72 * (0.4 + k)), 4.0)
			ci.draw_line(p + Vector2(3, -11), p + Vector2(-1, 7), Color(1.0, 0.77, 0.2, 0.86 * (0.4 + k)), 1.5)
		"cometa_gelado":
			ci.draw_line(p + Vector2(-9, -13), p + Vector2(3, 8), Color(0.44, 0.77, 1.0, 0.68 * (0.4 + k)), 4.0)
			ci.draw_line(p + Vector2(-2, -7), p + Vector2(2, 8), Color(1.0, 1.0, 1.0, 0.9 * fade), 1.5)
		_:
			ci.draw_line(p + Vector2(-7, -9), p + Vector2(5, 7), Color(cor.r, cor.g, cor.b, 0.6 * (0.4 + k)), 3.0)
	ci.draw_texture_rect(tex, Rect2(p - Vector2(9, 9), Vector2(18, 18)), false, Color(cor.r, cor.g, cor.b, 0.48 * fade))
	ci.draw_circle(p, 3.5, Color(1, 1, 1, 0.88 * fade))


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
	it.sp = sprite_de(str(a.id))
	it.p = p
	it.v = Vector2.ZERO
	it.vida = vida
	it.t = 0.0
	it.r = 0.0
	it.fase = randf() * TAU
	it.pen = 0
	(it.hit as Array).clear()
	it.pulso = 0.0
	return it


## Fumaça translúcida em camadas usa uma textura irregular criada uma vez; sem partículas nem nós por golpe.
func _desenhar_nuvem(ci: CanvasItem, it: Dictionary, st: Dictionary, cor: Color, tex: Texture2D, p: Vector2) -> void:
	var vida := float(it.vida)
	var duracao := float(st.duracao)
	var fade := opacidade_nuvem(vida, duracao)
	var fase := float(it.fase)
	var r := float(it.r)
	var id := str(it.a.get("id", ""))
	# O sprite opcional de arma entra como base discreta; os volumes e motivos continuam ativos com ou sem ele.
	var sprite = it.get("sp")
	if sprite != null and not sprite.is_empty():
		var tam: Vector2 = sprite.tam
		var altura := r * 2.0 * tam.y / tam.x
		ci.draw_texture_rect(
			sprite.tex, Rect2((p - Vector2(r, altura * 0.5)).round(), Vector2(r * 2.0, altura).round()), false, Color(cor.r, cor.g, cor.b, 0.18 * fade)
		)
	var respirar := 0.96 + 0.04 * sin(fase * 0.8)
	# Só um brilho oval suave marca o alcance; o corpo principal fica suspenso como fumaça.
	ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
	ci.draw_texture_rect(tex, Rect2(-r * respirar, -r * 0.72, r * 2.0 * respirar, r * 1.44), false, Color(cor.r, cor.g, cor.b, 0.10 * fade))
	ci.draw_arc(Vector2.ZERO, r * respirar, 0.1, TAU - 0.1, 40, Color(cor.r, cor.g, cor.b, 0.09 * fade), 1.1)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match motivo_nuvem(id):
		"espectros":
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.72, 0.9, 1.0), 6, 32.0, 1.16, 0.62)
			_desenhar_espiritos(ci, p, fase, fade, true, cor)
		"sono":
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.72, 0.54, 1.0), 6, 30.0, 1.20, 0.62)
			_desenhar_sonolenta(ci, p, fase, fade)
		"sangue":
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.72, 0.035, 0.08), 5, 38.0, 0.92, 0.58, 0.96)
			_desenhar_sangue(ci, p, fase, fade, cor)
		"bolhas":
			if id == "nuvem_espora":
				_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.7, 0.5, 0.24), 5, 22.0, 0.92, 0.50)
				_desenhar_esporos(ci, p, fase, fade)
			elif id == "chuva_acida":
				_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.72, 0.75, 0.2), 5, 27.0, 1.08, 0.56)
				_desenhar_chuva_acida(ci, p, fase, fade)
			else:
				_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.72, 0.91, 0.42), 9, 46.0, 1.65, 0.9, 0.68)
				_desenhar_bolhas(ci, p, fase, fade, cor)
		"cristais":
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.53, 0.82, 1.0), 6, 28.0, 1.12, 0.62)
			_desenhar_cristais(ci, p, fase, fade, cor)
			if id == "nevasca":
				_desenhar_neve(ci, p, fase, fade)
		"brasas":
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, Color(0.37, 0.4, 0.44), 7, 32.0, 1.35, 0.72)
			_desenhar_brasa(ci, p, fase, fade, cor)
		_:
			_desenhar_volume_nuvem(ci, tex, p, r, fase, fade, cor, 5, 24.0, 0.76, 0.28)


func _desenhar_pulso_nuvem(ci: CanvasItem, it: Dictionary, st: Dictionary, p: Vector2) -> void:
	var pulso := clampf(float(it.pulso), 0.0, 1.0)
	if pulso <= 0.0:
		return
	var fade := opacidade_nuvem(float(it.vida), float(st.duracao))
	var r := float(it.r)
	var raio_pulso := r * (0.55 + (1.0 - pulso) * 0.28)
	ci.draw_set_transform(p, 0.0, Vector2(1, ACHATA))
	ci.draw_arc(Vector2.ZERO, raio_pulso, 0.0, TAU, 32, Color(1.0, 0.98, 0.9, 0.62 * pulso * fade), 1.5 + pulso)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func motivo_nuvem(id: String) -> String:
	match id:
		"nevoa_espectral":
			return "espectros"
		"fumaca_sonolenta":
			return "sono"
		"cortina_sangue":
			return "sangue"
		"nuvem_veneno", "chuva_acida", "nuvem_espora":
			return "bolhas"
		"nevoeiro_gelado", "nevasca":
			return "cristais"
		"cinzas_vulcanicas":
			return "brasas"
	return "fumaca"


static func opacidade_nuvem(vida: float, duracao: float) -> float:
	var entrada := clampf((duracao - vida) / 0.32, 0.0, 1.0)
	var saida := clampf(vida / 0.65, 0.0, 1.0)
	return entrada * saida


func _desenhar_espiritos(ci: CanvasItem, p: Vector2, fase: float, fade: float, espectral: bool, cor: Color) -> void:
	# Três espectros desencontrados deixam o centro legível e criam altura sobre o chão.
	for n in 3:
		var ang := fase * 0.55 + TAU * float(n) / 3.0
		var centro := (p + Vector2(cos(ang) * 15.0, -17.0 - sin(fase * 1.3 + n * 1.8) * 4.0 + sin(ang) * 5.0)).round()
		var escala := 0.72 if n != 1 else 1.0
		var a := (0.48 if espectral else 0.29) * fade
		ci.draw_circle(centro + Vector2(0, 5), 7.0 * escala, Color(cor.r * 0.55, cor.g * 0.72, cor.b, a * 0.4))
		ci.draw_circle(centro + Vector2(0, -1), 6.0 * escala, Color(cor.r, cor.g, cor.b, a))
		ci.draw_arc(centro + Vector2(0, -1), 6.0 * escala, PI, TAU, 12, Color(1, 1, 1, a * 0.7), 1.0)
		ci.draw_circle(centro + Vector2(-2, -1), 0.9 * escala, Color(0.22, 0.35, 0.48, a))
		ci.draw_circle(centro + Vector2(2, -1), 0.9 * escala, Color(0.22, 0.35, 0.48, a))
		ci.draw_line(centro + Vector2(-2, 3), centro + Vector2(2, 3), Color(1, 1, 1, a * 0.55), 1.0)
		ci.draw_line(centro + Vector2(-3, 7), centro + Vector2(-5, 10), Color(cor.r, cor.g, cor.b, a * 0.55), 1.0)
		ci.draw_line(centro + Vector2(3, 7), centro + Vector2(5, 10), Color(cor.r, cor.g, cor.b, a * 0.55), 1.0)


func _desenhar_bolhas(ci: CanvasItem, p: Vector2, fase: float, fade: float, cor: Color) -> void:
	for n in 4:
		var q := (p + Vector2(sin(fase * 0.7 + n * 2.1) * (15.0 + n * 2.0), -8.0 - fposmod(fase * 4.0 + n * 7.0, 35.0))).round()
		var raio := 1.8 + float(n % 2) * 0.8
		ci.draw_circle(q, raio + 1.0, Color(cor.r, cor.g, cor.b, 0.2 * fade))
		ci.draw_arc(q, raio, 0.0, TAU, 8, Color(0.9, 1.0, 0.72, 0.68 * fade), 1.0)


func _desenhar_volume_nuvem(
	ci: CanvasItem,
	tex: Texture2D,
	p: Vector2,
	r: float,
	fase: float,
	fade: float,
	cor: Color,
	quantidade: int,
	altura: float,
	largura: float,
	alfa: float,
	aspecto: float = 0.64
) -> void:
	for n in quantidade:
		var u := float(n) / float(maxi(1, quantidade - 1))
		var oscilacao := sin(fase * (0.52 + float(n % 3) * 0.08) + float(n) * 1.9)
		var x := (u - 0.5) * r * 1.16 + oscilacao * r * 0.09
		var faixa := float(n % 3)
		var y := -6.0 - faixa * (altura / 3.0) - oscilacao * 3.5
		var escala := 0.78 + faixa * 0.1 + 0.05 * sin(fase * 0.7 + float(n))
		var w := r * largura * escala * (0.86 + 0.14 * sin(float(n) * 2.37))
		var h := maxf(12.0, w * aspecto * (0.86 + 0.16 * cos(float(n) * 1.73)))
		var centro := (p + Vector2(x, y)).round()
		var camada := Color(cor.r, cor.g, cor.b, alfa * fade * (0.86 + 0.14 * sin(fase + float(n))))
		var area := Rect2(centro - Vector2(w, h) * 0.5, Vector2(w, h))
		# Sombra fria nas dobras dá volume e separa o vapor do piso iluminado.
		ci.draw_texture_rect(
			_textura_fumaca(), Rect2(area.position + Vector2(2.0, 4.0), area.size), false, Color(cor.r * 0.20, cor.g * 0.28, cor.b * 0.20, alfa * fade * 0.52)
		)
		ci.draw_texture_rect(_textura_fumaca(), area, false, camada)


static func _textura_fumaca() -> Texture2D:
	if _tex_fumaca != null:
		return _tex_fumaca
	var imagem := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	for y in 40:
		for x in 64:
			var nx := (float(x) + 0.5) / 32.0 - 1.0
			var ny := (float(y) + 0.5) / 20.0 - 1.0
			var dist := sqrt(nx * nx * 0.72 + ny * ny * 1.55)
			var borda := 0.72 + 0.12 * sin(float(x) * 0.31 + float(y) * 0.17) + 0.08 * sin(float(x) * 0.13 - float(y) * 0.39)
			var alfa := (1.0 - smoothstep(0.28, borda, dist)) * (0.72 + 0.28 * sin(float(x) * 0.21 + float(y) * 0.27))
			imagem.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alfa, 0.0, 1.0)))
	_tex_fumaca = ImageTexture.create_from_image(imagem)
	return _tex_fumaca


func _desenhar_sonolenta(ci: CanvasItem, p: Vector2, fase: float, fade: float) -> void:
	for n in 2:
		var x := roundf(cos(fase * 0.35 + float(n) * PI) * 15.0 + float(n) * 4.0)
		var y := roundf(-15.0 - fposmod(fase * 2.2 + float(n) * 12.0, 23.0))
		var origem := p + Vector2(x, y)
		var al := 0.62 * fade
		ci.draw_line(origem, origem + Vector2(4, 0), Color(0.93, 0.84, 1.0, al), 1.4)
		ci.draw_line(origem + Vector2(4, 0), origem + Vector2(1, 3), Color(0.93, 0.84, 1.0, al), 1.4)
		ci.draw_line(origem + Vector2(1, 3), origem + Vector2(5, 3), Color(0.93, 0.84, 1.0, al), 1.4)


func _desenhar_esporos(ci: CanvasItem, p: Vector2, fase: float, fade: float) -> void:
	for n in 6:
		var ang := fase * 0.2 + TAU * float(n) / 6.0
		var q := (p + Vector2(cos(ang) * (10.0 + float(n % 3) * 7.0), -8.0 + sin(ang * 1.5) * 12.0)).round()
		ci.draw_circle(q, 1.5, Color(0.95, 0.78, 0.35, 0.62 * fade))
		ci.draw_line(q, q + Vector2(0.0, 3.0), Color(0.92, 0.66, 0.24, 0.42 * fade), 1.0)


func _desenhar_chuva_acida(ci: CanvasItem, p: Vector2, fase: float, fade: float) -> void:
	for n in 5:
		var x := sin(float(n) * 3.1 + fase * 0.18) * 29.0
		var y := -34.0 + fposmod(fase * 18.0 + float(n) * 13.0, 34.0)
		var q := (p + Vector2(x, y)).round()
		ci.draw_line(q + Vector2(-1, -4), q + Vector2(1, 3), Color(0.85, 0.95, 0.3, 0.75 * fade), 2.0)
		ci.draw_circle(q + Vector2(1, 3), 1.6, Color(0.94, 1.0, 0.42, 0.6 * fade))


func _desenhar_neve(ci: CanvasItem, p: Vector2, fase: float, fade: float) -> void:
	for n in 5:
		var x := cos(fase * 0.12 + float(n) * 1.8) * (9.0 + float(n) * 4.0)
		var y := -25.0 + fposmod(fase * 3.4 + float(n) * 9.0, 27.0)
		var q := (p + Vector2(x, y)).round()
		ci.draw_line(q + Vector2(-2, 0), q + Vector2(2, 0), Color(1, 1, 1, 0.65 * fade), 1.0)
		ci.draw_line(q + Vector2(0, -2), q + Vector2(0, 2), Color(1, 1, 1, 0.65 * fade), 1.0)


func _desenhar_cristais(ci: CanvasItem, p: Vector2, fase: float, fade: float, cor: Color) -> void:
	for n in 4:
		var ang := fase * 0.25 + TAU * float(n) / 4.0
		var q := (p + Vector2(cos(ang) * 23.0, -8.0 + sin(ang) * 11.0)).round()
		var eixo := Vector2.from_angle(ang + PI * 0.25) * 3.5
		var transversal := eixo.rotated(PI * 0.5) * 0.7
		ci.draw_line(q - eixo, q + eixo, Color(cor.r, cor.g, cor.b, 0.82 * fade), 1.5)
		ci.draw_line(q - transversal, q + transversal, Color(1.0, 1.0, 1.0, 0.7 * fade), 1.0)


func _desenhar_brasa(ci: CanvasItem, p: Vector2, fase: float, fade: float, cor: Color) -> void:
	for n in 5:
		var q := (p + Vector2(cos(fase * 0.4 + n * 1.7) * (8.0 + n * 3.0), -3.0 - fposmod(fase * 5.0 + n * 4.0, 19.0))).round()
		var quente := Color(1.0, 0.4 + 0.07 * float(n), 0.12, fade * (0.55 + 0.25 * sin(fase + n)))
		ci.draw_circle(q, 1.6, quente)
		ci.draw_line(q, q + Vector2(1, -3), Color(1.0, 0.65, 0.25, quente.a * 0.45), 1.0)


func _desenhar_sangue(ci: CanvasItem, p: Vector2, fase: float, fade: float, cor: Color) -> void:
	for n in 4:
		var ang := fase * 0.32 + TAU * float(n) / 4.0
		var q := (p + Vector2(cos(ang) * (7.0 + n * 3.0), -8.0 - sin(fase + n) * 4.0)).round()
		var gota := Vector2(1.2, 3.4)
		ci.draw_line(q - gota, q + gota, Color(cor.r, cor.g * 0.5, cor.b * 0.5, 0.65 * fade), 2.0)
		ci.draw_circle(q - gota, 1.3, Color(cor.r, cor.g * 0.45, cor.b * 0.45, 0.62 * fade))


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
