extends Node2D
## Um rival do duelo final. Tem herói, build (armas + passivos) e vida próprios, e luta com as MESMAS
## armas do jogador (armas.gd). Aqui ele é controlado pela IA (ia_luta.gd); no jogo online, cada
## rival será uma pessoa e este nó só mostra o boneco dela.

const Visual := preload("res://scripts/hordas/visual.gd")
const Armas := preload("res://scripts/hordas/armas.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
const IA := preload("res://scripts/hordas/ia_luta.gd")
const LINHA := {"baixo": 0, "esquerda": 1, "direita": 2, "cima": 3}
const VEL_BASE := 100.0
const DASH_VEL := 3.4
const DASH_TEMPO := 0.18
const DASH_RECARGA := 1.4

var duelo: Node2D
var lut                         # duelo.Lutador deste rival
var nome := ""
var heroi_id := ""
var cor := Color.WHITE
var build: Dictionary
var stats: Dictionary
var armas: Node2D
var hp := 100.0
var hpmax := 100.0
var habilidade := 0.85
var lado := 1.0
var kb := Vector2.ZERO
var dash_t := 0.0
var dash_recarga := 0.0
var invencivel := 0.0
var spr := Sprite2D.new()
var _dir := "baixo"
var _t := randf() * 10.0
var _mov := Vector2.ZERO
var _dir_dash := Vector2.RIGHT
var _vermelho := 0.0
var _st := {}
var _pref := 120.0
var _rastro: Array = []


func configurar(d: Node2D, l, nome_: String, heroi: String, build_: Dictionary, cor_: Color, hab: float) -> void:
	duelo = d
	lut = l
	nome = nome_
	heroi_id = heroi
	build = build_
	cor = cor_
	habilidade = hab
	var h: Dictionary = Dados.json("herois").get(heroi, {})
	stats = Construcao.stats(h, build.passivos)
	hpmax = duelo.hp_pvp(float(stats.vida_max))
	hp = hpmax
	_pref = IA.alcance_preferido(build.armas)
	spr.texture = Dados.tex_personagem(str(h.get("sprite", heroi)), "andando_8")
	spr.hframes = 9
	spr.vframes = 4
	spr.centered = false
	spr.offset = Vector2(-22, -58)
	add_child(spr)
	armas = Armas.new()
	armas.dono = self
	armas.campo = duelo.campo_de(lut, Callable(self, "stat"))
	armas.statf = Callable(self, "stat")
	duelo.add_child(armas)
	for a in build.armas:
		armas.adicionar(a.id)
		armas.achar(a.id).nivel = a.nivel
		armas.achar(a.id).t = randf_range(0.2, 1.0)


func stat(k: String) -> float:
	var v := float(stats.get(k, Construcao.BASE.get(k, 0.0)))
	if k == "regen":
		v *= duelo.regen_mult
	elif k == "velocidade" and lut.lento > 0:
		v *= 0.55
	return v


func centro() -> Vector2:
	return position + Vector2(0, -22)


func curar(v: float) -> void:
	hp = minf(hpmax, hp + v)


func atualizar(dt: float) -> void:
	_t += dt
	invencivel = maxf(0.0, invencivel - dt)
	dash_recarga = maxf(0.0, dash_recarga - dt)
	_vermelho = maxf(0.0, _vermelho - dt)
	if dash_t <= 0:
		var eu := {"pos": centro(), "hp_frac": hp / hpmax, "pref": _pref, "dash_pronto": dash_recarga <= 0}
		var dec: Dictionary = IA.decidir(eu, duelo.alvos_de(lut), duelo.centro, duelo.raio, _st, habilidade, dt)
		_mov = dec.dir
		if dec.dash and dash_recarga <= 0:
			_dir_dash = _mov if _mov != Vector2.ZERO else Vector2(lado, 0)
			dash_t = DASH_TEMPO
			dash_recarga = DASH_RECARGA
			invencivel = DASH_TEMPO + 0.1
	if _mov.x != 0:
		lado = signf(_mov.x)
	if dash_t > 0:
		dash_t -= dt
		position += _dir_dash * VEL_BASE * stat("velocidade") * DASH_VEL * dt
		if int(_t * 60) % 2 == 0:
			_rastro.append({"pos": position, "frame": spr.frame, "t": 0.25})
	else:
		position += _mov * VEL_BASE * stat("velocidade") * dt
	position += kb * dt
	kb *= exp(-9.0 * dt)
	hp = minf(hpmax, hp + stat("regen") * dt)
	_animar()
	for r in _rastro.duplicate():
		r.t -= dt
		if r.t <= 0:
			_rastro.erase(r)
	armas.atualizar(dt)
	queue_redraw()


func _animar() -> void:
	if _mov != Vector2.ZERO:
		if absf(_mov.x) > absf(_mov.y) * 0.9:
			_dir = "direita" if _mov.x > 0 else "esquerda"
		else:
			_dir = "baixo" if _mov.y > 0 else "cima"
		spr.frame = LINHA[_dir] * 9 + 1 + int(_t * 12.0) % 8
	else:
		spr.frame = LINHA[_dir] * 9
	var piscar := invencivel > 0 and dash_t <= 0 and int(_t * 20) % 2 == 0
	spr.modulate = Color(1, 0.4, 0.4) if _vermelho > 0 else Color.WHITE
	spr.visible = not piscar


## Dano de outro lutador. Retorna true se este rival caiu.
func receber(dano: float, _quem: String, empurrao := Vector2.ZERO) -> bool:
	if invencivel > 0 or hp <= 0:
		return false
	hp -= dano
	invencivel = duelo.iframes
	_vermelho = 0.12
	kb += empurrao
	return hp <= 0


## Dano do anel que fecha (sem tempo de invencibilidade).
func dano_direto(dano: float, _quem: String) -> bool:
	if hp <= 0:
		return false
	hp -= dano
	_vermelho = 0.05
	return hp <= 0


func sumir() -> void:
	visible = false
	armas.queue_free()


func _draw() -> void:
	Visual.sombra_boneco(self, spr)
	for r in _rastro:
		var tex := spr.texture
		var w := tex.get_width() / 9.0
		var h := tex.get_height() / 4.0
		var f: int = r.frame
		draw_texture_rect_region(tex, Rect2(r.pos - position + spr.offset, Vector2(w, h)),
			Rect2((f % 9) * w, (f / 9) * h, w, h), Color(cor, r.t * 2.0))
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 12, Color(cor, 0.5))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var frac := clampf(hp / hpmax, 0.0, 1.0)
	draw_rect(Rect2(-16, 5, 32, 4), Color(0.1, 0.05, 0.1))
	draw_rect(Rect2(-15, 6, 30 * frac, 2), cor)
	draw_string(Dados.fonte, Vector2(-40, -66), nome, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(0, 0, 0, 0.8))
	draw_string(Dados.fonte, Vector2(-41, -67), nome, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, cor.lightened(0.4))
