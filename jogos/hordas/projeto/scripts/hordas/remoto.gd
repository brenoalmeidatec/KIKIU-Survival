extends Node2D
## Outra pessoa da partida online: só mostra o boneco (a posição vem de Rede.remotos, ~15 vezes por segundo).
## Quem controla é o computador dela; aqui é só desenho, nome, vida e o corpo caído.

const Visual := preload("res://scripts/hordas/visual.gd")
const Direcao := preload("res://scripts/hordas/direcao.gd")
const Paleta := preload("res://scripts/hordas/paleta.gd")
const LINHA := Direcao.LINHA   # tabela de linhas da folha (8 direções; folhas de 4 usam só as 4 primeiras)

var peer := 0
var nome := ""
var heroi := ""
var cor := Color(0.6, 1.0, 0.7)
var hp_frac := 1.0
var caido := false
var ajuda := false               # está segurando o botão de levantar alguém
var _rola := false               # está rolando (bit 8 do estado; #68)
const CENTRO_CORPO := Vector2(0, -29)   # o meio do corpo em relação ao pé: o giro do rolamento é em volta dele
var fora := false               # duelo: já foi eliminado
var spr := Sprite2D.new()
var _cab: Sprite2D = null        # cabelo do herói criado (camada por cima do corpo)
var _alvo := Vector2.ZERO
var _mov := Vector2.ZERO
var _dir := "baixo"
var _olhar := Direcao.new()
var _t := 0.0
var _novo := true
var _ent_t := 0.0                # chegada no começo da fase (veja visual.gd chegada_*)
var _ent_poeira := false


## Começo da fase (ou primeiro pacote): o boneco cai do alto com poeira e flash, como o herói.
func entrar() -> void:
	_ent_t = Visual.CHEGADA_TEMPO
	_ent_poeira = false


func configurar(p: int, heroi_: String, nome_: String) -> void:
	z_index = -1   # o seu boneco fica sempre por cima dos outros
	peer = p
	heroi = heroi_
	nome = nome_
	var h: Dictionary = Dados.json("herois").get(heroi, {})
	var paleta: Dictionary = h.get("paleta", {})
	if paleta.is_empty():
		spr.texture = Dados.tex_personagem(str(h.get("sprite", heroi)), "andando_8")
	else:   # herói criado (#72, marco 2): corpo e cabelo recoloridos pela paleta, em duas camadas como o herói local
		spr.texture = Paleta.textura(str(h.get("sprite", heroi)), "corpo", paleta)
	spr.hframes = maxi(1, int(spr.texture.get_width()) / 44)
	spr.vframes = Direcao.linhas_da_altura(spr.texture.get_height())
	spr.centered = false
	spr.offset = Vector2(-22, -58)
	add_child(spr)
	if not paleta.is_empty():
		var cab := Paleta.textura(str(h.get("sprite", heroi)), "camadas/cabelo", paleta)
		if cab:
			_cab = Sprite2D.new()
			_cab.texture = cab
			_cab.hframes = spr.hframes
			_cab.vframes = spr.vframes
			_cab.centered = false
			_cab.offset = spr.offset
			spr.add_child(_cab)


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
			entrar()
	# suaviza entre um pacote e outro; se pulou longe (dash, reaparecer), vai direto
	position = _alvo if position.distance_to(_alvo) > 160.0 else position.lerp(_alvo, minf(1.0, dt * 14.0))
	var andando := _mov.length() > 0.1 and not caido
	_olhar.atualizar(_mov if andando else Vector2.ZERO, dt, spr.vframes)
	_dir = _olhar.dir
	if andando:
		spr.frame = LINHA[_dir] * spr.hframes + 1 + int(_t * 12.0) % 8
	else:
		spr.frame = LINHA[_dir] * spr.hframes
	if _cab:
		_cab.frame = spr.frame
	spr.modulate = Color(0.45, 0.45, 0.5, 0.8) if caido else Color.WHITE
	spr.rotation = PI / 2 if caido else 0.0
	spr.position = Vector2(-30, -10) if caido else Vector2.ZERO
	if not d.is_empty():
		_rola = bool(d.get("rola", false))
	if _rola and not caido:   # rolamento (#68): gira em volta do meio do corpo, como o herói local
		var ang := fmod(_t * TAU / 0.3, TAU) * (-1.0 if _mov.x < 0 else 1.0)
		spr.rotation = ang
		spr.position = CENTRO_CORPO - CENTRO_CORPO.rotated(ang)
	if _ent_t > 0.0:
		_ent_t = maxf(0.0, _ent_t - dt)
		var p := 1.0 - _ent_t / Visual.CHEGADA_TEMPO
		var g := Visual.chegada_flash(p) * 2.0
		spr.position.y -= Visual.chegada_altura(p)
		spr.modulate = Color(spr.modulate.r + g, spr.modulate.g + g, spr.modulate.b + g, spr.modulate.a * clampf(p * 6.0, 0.0, 1.0))
		if not _ent_poeira and p >= Visual.CHEGADA_POUSO:
			_ent_poeira = true
			if get_parent() and get_parent().efeitos:
				get_parent().efeitos.explodir(position + Vector2(0, -2), Color(0.82, 0.78, 0.68), 8, 85.0)
	visible = not fora
	queue_redraw()


func _draw() -> void:
	if _ent_t > 0.0:
		Visual.chegada(self, 1.0 - _ent_t / Visual.CHEGADA_TEMPO, "", 0.0, cor)
	if not caido:
		Visual.sombra_boneco(self, spr)
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 12, Color(cor, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_rect(Rect2(-16, 5, 32, 4), Color(0.1, 0.05, 0.1))
	draw_rect(Rect2(-15, 6, 30 * hp_frac, 2), cor)
	var txt := nome + (" (segure E)" if caido else "")
	draw_string(Dados.fonte, Vector2(-60, -66), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color(0, 0, 0, 0.8))
	draw_string(Dados.fonte, Vector2(-61, -67), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, cor.lightened(0.3))
