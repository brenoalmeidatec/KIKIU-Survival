extends Node2D
## Outra pessoa da partida online: só mostra o boneco (a posição vem de Rede.remotos, ~15 vezes por segundo).
## Quem controla é o computador dela; aqui é só desenho, nome, vida e o corpo caído.

const Visual := preload("res://scripts/hordas/visual.gd")
const Direcao := preload("res://scripts/hordas/direcao.gd")
const Paleta := preload("res://scripts/hordas/paleta.gd")
const Anim := preload("res://scripts/hordas/animacao_heroi.gd")
const LINHA := Direcao.LINHA  # tabela de linhas da folha (8 direções; folhas de 4 usam só as 4 primeiras)

var peer := 0
var nome := ""
var heroi := ""
var cor := Color(0.6, 1.0, 0.7)
var hp_frac := 1.0
var caido := false
var ajuda := false  # está segurando o botão de levantar alguém
var _rola := false  # está rolando (bit 8 do estado; #68)
const CENTRO_CORPO := Vector2(0, -29)  # o meio do corpo em relação ao pé: o giro do rolamento é em volta dele
var fora := false  # duelo: já foi eliminado
var spr := Sprite2D.new()
var _cab: Sprite2D = null  # cabelo do herói criado (camada por cima do corpo)
var _alvo := Vector2.ZERO
var _mov := Vector2.ZERO
var _dir := "baixo"
var _olhar := Direcao.new()
var _t := 0.0
var _novo := true
var _ent_t := 0.0  # chegada no começo da fase (veja visual.gd chegada_*)
var _ent_poeira := false
var _corpo := Anim.new()  # respiração, balanço do passo e inclinação (animacao_heroi.gd)
var _pos_ant := Vector2.ZERO
var _vel := Vector2.ZERO  # velocidade real medida na posição suavizada (px/s)
var _lado := 1.0  # pra que lado olhava por último (movimento em x)
var _dano_pose_t := 0.0
var _dano_dir := Vector2.LEFT
var _rola_t := 0.0
var _cai_t := 0.0


## Começo da fase (ou primeiro pacote): o boneco cai do alto com poeira e flash, como o herói.
func entrar() -> void:
	_ent_t = Visual.CHEGADA_TEMPO
	_ent_poeira = false


func configurar(p: int, heroi_: String, nome_: String) -> void:
	z_index = -1  # o seu boneco fica sempre por cima dos outros
	peer = p
	heroi = heroi_
	nome = nome_
	_corpo.fase = Anim.fase_de(heroi_ + "|" + str(p))  # cada pessoa respira com a defasagem dela
	var h: Dictionary = Dados.json("herois").get(heroi, {})
	var paleta: Dictionary = h.get("paleta", {})
	if paleta.is_empty():
		spr.texture = Dados.tex_personagem(str(h.get("sprite", heroi)), "andando_8")
	else:  # herói criado (#72, marco 2): corpo e cabelo recoloridos pela paleta, em duas camadas como o herói local
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
	var hp_ant := hp_frac
	if not d.is_empty():
		_alvo = Vector2(d.x, d.y)
		_mov = Vector2(d.mx, d.my)
		hp_frac = d.hp
		ajuda = d.ajuda
		caido = d.caido
		if _novo:
			position = _alvo
			_pos_ant = position
			hp_ant = hp_frac
			_novo = false
			entrar()
	# suaviza entre um pacote e outro; se pulou longe (dash, reaparecer), vai direto
	position = _alvo if position.distance_to(_alvo) > 160.0 else position.lerp(_alvo, minf(1.0, dt * 14.0))
	var andando := _mov.length() > 0.1 and not caido
	if not d.is_empty():
		var rola_novo := bool(d.get("rola", false))
		if rola_novo and not _rola:
			_rola_t = 0.0  # começou a rolar: a volta parte do zero
		_rola = rola_novo
	# o que não vem na rede sai da posição: velocidade real (pra o passo casar com o chão) e a vida que caiu (pra o recuo)
	if not d.is_empty():
		_lado = -1.0 if float(d.get("lado", 1.0)) < 0.0 else 1.0  # o "lado" que já vai na rede (bit 4 do estado)
	var v_real := (position - _pos_ant) / maxf(dt, 0.0001) if position.distance_to(_pos_ant) < 60.0 else Vector2.ZERO
	_pos_ant = position
	_vel = _vel.lerp(v_real, 1.0 - exp(-12.0 * dt))
	if hp_frac < hp_ant - 0.002 and not caido:
		_dano_pose_t = float(Anim.sec("dano").tempo)
		_dano_dir = Vector2(-_lado, 0.0)
	_dano_pose_t = maxf(0.0, _dano_pose_t - dt)
	_rola_t += dt
	_cai_t = _cai_t + dt if caido else 0.0
	_olhar.atualizar(_mov if andando else Vector2.ZERO, dt, spr.vframes)
	_dir = _olhar.dir
	_corpo.atualizar(dt, _vel, andando, not _rola and not caido and _ent_t <= 0.0, spr.hframes >= 23)
	if andando:
		spr.frame = LINHA[_dir] * spr.hframes + Anim.quadro_andar(_corpo.ciclo)
	else:
		spr.frame = LINHA[_dir] * spr.hframes
	if _cab:
		_cab.frame = spr.frame
	spr.modulate = Color.WHITE
	spr.rotation = 0.0
	spr.position = Vector2.ZERO
	spr.skew = 0.0
	spr.scale = Vector2.ONE
	if caido:  # tropeça, cai e fica deitado (a mesma queda do herói local)
		var mc := Anim.sec("morte")
		var pm := Anim.pose_morte(_cai_t / maxf(float(mc.tempo), 0.05), -_lado, mc)
		spr.rotation = pm.rot
		spr.position = pm.pos
		spr.modulate = Color.WHITE.lerp(Color(0.45, 0.45, 0.5, float(mc.alpha)), float(pm.mix))
	elif _rola:  # rolamento (#68): gira em volta do meio do corpo, como o herói local
		var total := maxf(0.05, float(Dados.json("movimento").get("rolamento", {}).get("tempo", 0.3)))
		var ang := fmod(_rola_t / total, 1.0) * TAU * (-1.0 if _mov.x < 0 else 1.0)
		spr.rotation = ang
		spr.position = CENTRO_CORPO - CENTRO_CORPO.rotated(ang)
	else:  # respiração, balanço do passo, inclinação e recuo ao apanhar (derivados de posição e vida: o formato da rede não muda)
		var pos := _corpo.desloc()
		var sk := _corpo.inclina()
		var esc := Vector2.ONE + _corpo.escala()
		if _dano_pose_t > 0.0:
			var dc := Anim.sec("dano")
			var pd := Anim.pose_dano(1.0 - _dano_pose_t / float(dc.tempo), dc)
			pos += (Vector2(_dano_dir.x, _dano_dir.y * 0.6) * pd.x).round()
			sk += _dano_dir.x * float(dc.inclina) * pd.z
			esc *= Vector2(1.0 + pd.y, 1.0 - pd.y)
		spr.position = pos
		spr.skew = sk
		spr.scale = esc
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
