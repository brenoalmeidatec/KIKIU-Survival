extends Node2D
## Especial do herói (#63): um golpe com a cara de cada amigo (docs/HISTORIA_GRUPO_AMIGOS.md), na tecla E (Y no
## controle), com recarga. Dados em dados/especiais.json (um por herói). O efeito é um módulo de arma
## (scripts/hordas/especiais/<tipo>.gd, registrado em armas.MODULOS): ativar() cria o efeito em armas.especiais e o
## armas.gd cuida de passo/pintar como faz com qualquer arma. Aqui ficam a recarga, a tecla, o grito em cima da
## cabeça e o bônus de atributo temporário (arena.stat soma bonus()).

const GRITO_T := 1.6
const Armas := preload("res://scripts/hordas/armas.gd")

var arena: Node
var d := {}                  # o especial deste herói (vazio = não tem)
var recarga := 0.0           # segundos até poder usar de novo
var usos := 0
var _bonus_t := 0.0          # bônus de atributo ainda valendo
var _grito_t := 0.0
var _t := 0.0
var _avisou := false


func configurar(a: Node) -> void:
	arena = a
	z_index = 3
	var tudo: Dictionary = Dados.json("especiais")
	var e = tudo.get(str(arena.heroi.get("especial", arena.heroi_id)), {})   # herói criado (#72): o especial vem da classe
	d = e if e is Dictionary else {}
	recarga = 4.0   # não sai logo no primeiro segundo


func tem() -> bool:
	return not d.is_empty() and armas_modulo() != null


func armas_modulo():
	return Armas.MODULOS.get(str(d.get("tipo", "")))


func pronto() -> bool:
	return tem() and recarga <= 0.0


func recarga_total() -> float:
	return maxf(3.0, float(d.get("recarga", 30)) * arena.stat("recarga"))


## Atributos a mais por alguns segundos depois de usar (ex.: crítico do "Sou Gostoso!").
func bonus(k: String) -> float:
	if _bonus_t <= 0.0:
		return 0.0
	return float(d.get("bonus", {}).get(k, 0.0))


## Dano do especial: o do JSON, vezes o atributo dano, crescendo com o nível.
func dano() -> float:
	return float(d.get("dano", 0)) * arena.stat("dano") * (1.0 + float(d.get("escala_nivel", 0.0)) * (arena.nivel - 1))


func atualizar(dt: float) -> void:
	if not tem():
		return
	_t += dt
	recarga = maxf(0.0, recarga - dt)
	_bonus_t = maxf(0.0, _bonus_t - dt)
	_grito_t = maxf(0.0, _grito_t - dt)
	if pronto() and not _avisou and not arena.bot:
		_avisou = true
		arena.mensagem("E: %s (especial do herói)" % str(d.get("nome", "")), Color(1, 0.85, 0.4))
	if pronto() and _quer():
		usar()
	queue_redraw()


func _quer() -> bool:
	var jog: Node2D = arena.jogador
	if jog.hp <= 0 or arena.caido or arena.acabou:
		return false
	if arena.bot:
		return arena.armas.campo.no_circulo(jog.centro(), 120.0).size() >= 6
	if arena.cartas.aberto() or arena.hud._pausado or Chat.digitando:
		return false
	return Input.is_action_just_pressed("especial")


func usar() -> void:
	var m = armas_modulo()
	if m == null:
		return
	m.ativar(arena.armas, d, self)
	recarga = recarga_total()
	usos += 1
	_bonus_t = float(d.get("duracao_bonus", 0.0))
	_grito_t = GRITO_T
	Som.tocar("tremor", 0.2, 1.4, -6)


func _draw() -> void:
	if not tem():
		return
	var jog: Node2D = arena.jogador
	var c: Vector2 = jog.position
	# bônus valendo: um brilho dourado no chão, pulsando (o "sou gostoso" fica brilhando)
	if _bonus_t > 0.0:
		var a := clampf(_bonus_t, 0.0, 1.0)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, 20.0 + 2.0 * sin(_t * 8.0), 0, TAU, 24, Color(1, 0.82, 0.35, 0.55 * a), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 4:
			var fase := fmod(_t * 1.3 + i * 0.25, 1.0)
			var p := c + Vector2(sin(i * 2.1 + _t * 2.0) * 12.0, -8.0 - fase * 44.0)
			draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(1, 0.9, 0.5, (1.0 - fase) * a))
	# o grito, subindo e sumindo em cima da cabeça
	if _grito_t > 0.0:
		var f := _grito_t / GRITO_T
		var txt := str(d.get("frase", ""))
		var fonte: Font = Dados.fonte
		var larg := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var p := (c + Vector2(-larg / 2.0, -80.0 - (1.0 - f) * 14.0)).floor()   # acima do nome do herói
		var cor := Color(1, 0.9, 0.45, clampf(f * 3.0, 0.0, 1.0))
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(fonte, p + o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.05, 0.03, 0.02, cor.a))
		draw_string(fonte, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, cor)
