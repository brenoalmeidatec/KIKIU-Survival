extends Node2D
## O herói: anda em 8 direções, dá dash (invencível por um instante) e leva dano.
## Usa a mesma folha de andar dos personagens da Cairu (andando_8.png: 9 colunas x 4 direções, 44x60).

const LINHA := {"baixo": 0, "esquerda": 1, "direita": 2, "cima": 3}
const VEL_BASE := 100.0
const DASH_VEL := 3.4
const DASH_TEMPO := 0.18
const DASH_RECARGA := 1.4

var arena: Node
var spr := Sprite2D.new()
var hp := 100.0
var invencivel := 0.0
var dash_t := 0.0
var dash_recarga := 0.0
var lado := 1.0                 # 1 = olhando pra direita, -1 = esquerda (o chicote usa)
var _mov := Vector2.ZERO
var _dir_dash := Vector2.RIGHT
var _t := 0.0
var _dir := "baixo"
var _rastro: Array = []          # imagens fantasmas do dash
var _vermelho := 0.0
var bot := false                 # modo demonstração (anda sozinho)
var _bot_ang := 0.0
var kb := Vector2.ZERO
var _ia := {}
var _pref := 120.0


func configurar(sprite: String) -> void:
	spr.texture = Dados.tex_personagem(sprite, "andando_8")
	spr.hframes = 9
	spr.vframes = 4
	spr.centered = false
	spr.offset = Vector2(-22, -58)
	add_child(spr)


func centro() -> Vector2:
	return position + Vector2(0, -22)


func direcao_mov() -> Vector2:
	return _mov


func vida_max() -> float:
	return arena.stat("vida_max")


func atualizar(dt: float) -> void:
	_t += dt
	_dt = dt
	invencivel = maxf(0.0, invencivel - dt)
	dash_recarga = maxf(0.0, dash_recarga - dt)
	_vermelho = maxf(0.0, _vermelho - dt)
	var entrada := _entrada()
	_mov = entrada
	if entrada.x != 0:
		lado = signf(entrada.x)
	if dash_t > 0:
		dash_t -= dt
		position += _dir_dash * VEL_BASE * arena.stat("velocidade") * DASH_VEL * dt
		if int(_t * 60) % 2 == 0:
			_rastro.append({"pos": position, "frame": spr.frame, "t": 0.25})
	else:
		position += entrada * VEL_BASE * arena.stat("velocidade") * dt
		if _quer_dash() and dash_recarga <= 0:
			_dir_dash = entrada if entrada != Vector2.ZERO else Vector2(lado, 0)
			dash_t = DASH_TEMPO
			dash_recarga = DASH_RECARGA
			invencivel = maxf(invencivel, DASH_TEMPO + 0.1)
			Som.tocar("whoosh", 0.1, 1.2)
	position += kb * dt
	kb *= exp(-9.0 * dt)
	# regeneração
	hp = minf(vida_max(), hp + arena.stat("regen") * dt)
	_animar(entrada)
	for r in _rastro.duplicate():
		r.t -= dt
		if r.t <= 0:
			_rastro.erase(r)
	queue_redraw()


var _dash_ia := false
var _dt := 0.016


## Online: com cartas ou pausa abertas o jogo não para, mas as setas são do menu.
func _no_menu() -> bool:
	return arena.eh_online and (arena.cartas.aberto() or arena.hud._pausado)


func _entrada() -> Vector2:
	if _no_menu():
		return Vector2.ZERO
	if bot and arena.duelo_ativo:
		return _bot_duelo()
	if bot:
		return _bot_dir()
	return Input.get_vector("esquerda", "direita", "cima", "baixo")


func _quer_dash() -> bool:
	if _no_menu():
		return false
	if bot and arena.duelo_ativo:
		return _dash_ia
	if bot:
		return arena.inimigos.no_circulo(centro(), 40).size() > 4
	return Input.is_action_just_pressed("dash")


## Robô no duelo: usa o mesmo cérebro dos rivais.
func _bot_duelo() -> Vector2:
	var d: Node2D = arena.duelo
	if d.estado != "luta":
		return Vector2.ZERO
	_pref = d.IA.alcance_preferido(arena.armas.lista)
	var eu := {"pos": centro(), "hp_frac": hp / maxf(1.0, vida_max()), "pref": _pref, "dash_pronto": dash_recarga <= 0}
	var dec: Dictionary = d.IA.decidir(eu, d.alvos_de(d.lut_jogador), d.centro, d.raio, _ia, 0.9, _dt)
	_dash_ia = dec.dash
	return dec.dir


## Demonstração: foge dos vírus por perto, vai pegar XP e as tomadas, e anda em círculo quando está calmo.
func _bot_dir() -> Vector2:
	_bot_ang += 0.4 * _dt
	var c := centro()
	var fuga := Vector2.ZERO
	for v in arena.inimigos.no_circulo(c, 110):
		var dif: Vector2 = c - v.pos
		fuga += dif.normalized() * (110.0 - dif.length()) / 110.0 * (3.0 if v.chefe else 1.0)
	for t in arena.inimigos.tiros:
		if t.pos.distance_to(c) < 60:
			fuga += (c - t.pos).normalized()
	var quer := Vector2.from_angle(_bot_ang) * 0.4
	var melhor = null
	var md := 200.0 * 200.0
	for it in arena.coleta.itens:
		var d: float = it.pos.distance_squared_to(c)
		if d < md:
			md = d
			melhor = it
	if melhor:
		quer = (melhor.pos - c).normalized()
	else:
		var s = arena.chao.mais_perto_livre(position)
		if s and s.pos.distance_to(position) < 700:
			quer = (s.pos - position).normalized()
	# chefe da fase em campo: o robô vai atrás dele (com a build na mão) em vez de só fugir
	var ch: Array = arena.chefes()
	if not ch.is_empty() and not melhor and ch[0].pos.distance_to(c) > 70.0:
		quer = (ch[0].pos - c).normalized()
	# online: amigo caído por perto, o robô vai levantar
	if arena.online:
		for a in arena.online.avatares.values():
			if a.visible and a.caido and a.position.distance_to(position) < 400.0:
				quer = (a.position - position).normalized() if a.position.distance_to(position) > 20.0 else Vector2.ZERO
				fuga *= 0.3
				break
	var d := quer + fuga * 2.0
	return d.normalized() if d.length() > 0.1 else Vector2.ZERO


func _animar(entrada: Vector2) -> void:
	if entrada != Vector2.ZERO:
		if absf(entrada.x) > absf(entrada.y) * 0.9:
			_dir = "direita" if entrada.x > 0 else "esquerda"
		else:
			_dir = "baixo" if entrada.y > 0 else "cima"
		spr.frame = LINHA[_dir] * 9 + 1 + int(_t * 12.0) % 8
	else:
		spr.frame = LINHA[_dir] * 9
	# pisca quando está invencível depois de apanhar
	var piscar := invencivel > 0 and dash_t <= 0 and int(_t * 20) % 2 == 0
	spr.modulate = Color(1, 0.4, 0.4) if _vermelho > 0 else Color.WHITE
	spr.visible = not piscar


## Dano de vírus (fonte = tipo) ou de outro lutador no duelo. Retorna true se caiu.
func sofrer(dano: float, fonte := "", iframes := 0.5, empurrao := Vector2.ZERO) -> bool:
	if invencivel > 0 or hp <= 0:
		return false
	hp -= dano
	arena.dano_recebido[fonte] = float(arena.dano_recebido.get(fonte, 0.0)) + dano
	invencivel = iframes
	_vermelho = 0.15
	kb += empurrao
	Som.tocar("erro", 0.15, 1.0, -4)
	arena.tremer(3.0)
	if hp <= 0:
		hp = 0
		arena.morrer(fonte)
		return true
	return false


## Interface igual à dos rivais: o duelo chama isso quando uma arma de outro lutador acerta.
func receber(dano: float, quem: String, empurrao := Vector2.ZERO) -> bool:
	return sofrer(dano, "rival:" + quem, arena.duelo.iframes, empurrao)


## Dano do anel (sem invencibilidade).
func dano_direto(dano: float, fonte: String) -> bool:
	if hp <= 0:
		return false
	hp -= dano
	_vermelho = 0.05
	if hp <= 0:
		hp = 0
		arena.morrer(fonte)
		return true
	return false


func curar(valor: float) -> void:
	hp = minf(vida_max(), hp + valor)


func _draw() -> void:
	for r in _rastro:
		var tex := spr.texture
		var w := tex.get_width() / 9.0
		var h := tex.get_height() / 4.0
		var f: int = r.frame
		draw_texture_rect_region(tex, Rect2(r.pos - position + spr.offset, Vector2(w, h)),
			Rect2((f % 9) * w, (f / 9) * h, w, h), Color(0.5, 0.8, 1.0, r.t * 2.0))
	# sombra, barra de vida e recarga do dash embaixo do pé
	draw_set_transform(Vector2(0, 0), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if arena.caido and arena.online:
		# caído: anel mostrando quanto falta pra levantar
		draw_arc(Vector2(0, -10), 18, 0, TAU, 32, Color(0, 0, 0, 0.4), 3)
		draw_arc(Vector2(0, -10), 18, -PI / 2, -PI / 2 + TAU * arena.online.reviver_prog, 32, Color(0.5, 1, 0.6), 3)
		return
	var frac := hp / maxf(1.0, vida_max())
	draw_rect(Rect2(-14, 5, 28, 4), Color(0.1, 0.05, 0.1))
	draw_rect(Rect2(-13, 6, 26 * frac, 2), Color(0.9, 0.2, 0.25))
	if dash_recarga > 0:
		draw_rect(Rect2(-13, 10, 26 * (1.0 - dash_recarga / DASH_RECARGA), 1), Color(0.5, 0.8, 1.0))
