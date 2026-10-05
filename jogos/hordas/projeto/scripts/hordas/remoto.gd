extends Node2D
## Outra pessoa da partida online: só mostra o boneco (a posição vem de Rede.remotos, ~15 vezes por segundo).
## Quem controla é o computador dela; aqui é só desenho, nome, vida e o corpo caído.

const LINHA := {"baixo": 0, "esquerda": 1, "direita": 2, "cima": 3}

var peer := 0
var nome := ""
var heroi := ""
var cor := Color(0.6, 1.0, 0.7)
var hp_frac := 1.0
var caido := false
var ajuda := false               # está segurando o botão de levantar alguém
var fora := false               # duelo: já foi eliminado
var spr := Sprite2D.new()
var _alvo := Vector2.ZERO
var _mov := Vector2.ZERO
var _dir := "baixo"
var _t := 0.0
var _novo := true


func configurar(p: int, heroi_: String, nome_: String) -> void:
	z_index = -1   # o seu boneco fica sempre por cima dos outros
	peer = p
	heroi = heroi_
	nome = nome_
	var h: Dictionary = Dados.json("herois").get(heroi, {})
	spr.texture = Dados.tex_personagem(str(h.get("sprite", heroi)), "andando_8")
	spr.hframes = 9
	spr.vframes = 4
	spr.centered = false
	spr.offset = Vector2(-22, -58)
	add_child(spr)


func centro() -> Vector2:
	return position + Vector2(0, -22)


func atualizar(dt: float, d: Dictionary) -> void:
	_t += dt
	if not d.is_empty():
		_alvo = Vector2(d.x, d.y)
		_mov = Vector2(d.mx, d.my)
		hp_frac = d.hp
		ajuda = d.ajuda
		caido = d.caido
		if _novo:
			position = _alvo
			_novo = false
	# suaviza entre um pacote e outro; se pulou longe (dash, reaparecer), vai direto
	position = _alvo if position.distance_to(_alvo) > 160.0 else position.lerp(_alvo, minf(1.0, dt * 14.0))
	if _mov.length() > 0.1 and not caido:
		if absf(_mov.x) > absf(_mov.y) * 0.9:
			_dir = "direita" if _mov.x > 0 else "esquerda"
		else:
			_dir = "baixo" if _mov.y > 0 else "cima"
		spr.frame = LINHA[_dir] * 9 + 1 + int(_t * 12.0) % 8
	else:
		spr.frame = LINHA[_dir] * 9
	spr.modulate = Color(0.45, 0.45, 0.5, 0.8) if caido else Color.WHITE
	spr.rotation = PI / 2 if caido else 0.0
	spr.position = Vector2(-30, -10) if caido else Vector2.ZERO
	visible = not fora
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 12, Color(cor, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_rect(Rect2(-16, 5, 32, 4), Color(0.1, 0.05, 0.1))
	draw_rect(Rect2(-15, 6, 30 * hp_frac, 2), cor)
	var txt := nome + (" (segure E)" if caido else "")
	draw_string(Dados.fonte, Vector2(-60, -66), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color(0, 0, 0, 0.8))
	draw_string(Dados.fonte, Vector2(-61, -67), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, cor.lightened(0.3))
