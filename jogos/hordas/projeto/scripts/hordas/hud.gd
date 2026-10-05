extends CanvasLayer
## Tela da partida: barra de XP, nível, tempo, abates, armas e passivos, vida do chefe,
## seta pra tomada mais perto, mensagens e o menu de pausa.

const W := 640.0
const H := 360.0

var arena: Node
var _tela := Control.new()
var _msgs: Array = []        # {txt, cor, t}
var _anuncio := {"txt": "", "cor": Color.WHITE, "t": 0.0}
var _pausado := false
var _op_pausa := 0
var _t := 0.0
var _quadro_pausa := -1


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


func mensagem(txt: String, cor := Color.WHITE) -> void:
	_msgs.append({"txt": txt, "cor": cor, "t": 2.5})
	if _msgs.size() > 4:
		_msgs.pop_front()


func anunciar(txt: String, cor := Color.WHITE) -> void:
	_anuncio = {"txt": txt, "cor": cor, "t": 2.5}


func atualizar(dt: float) -> void:
	_t += dt
	for m in _msgs.duplicate():
		m.t -= dt
		if m.t <= 0:
			_msgs.erase(m)
	_anuncio.t = maxf(0.0, _anuncio.t - dt)
	_tela.queue_redraw()


func pausar() -> void:
	_pausado = true
	_op_pausa = 0
	_quadro_pausa = Engine.get_process_frames()
	get_tree().paused = true
	Som.tocar("abrir")
	_tela.queue_redraw()


func _process(_dt: float) -> void:
	if not _pausado or Engine.get_process_frames() == _quadro_pausa:
		return
	if Input.is_action_just_pressed("cima") or Input.is_action_just_pressed("baixo"):
		_op_pausa = 1 - _op_pausa
		Som.tocar("cursor")
		_tela.queue_redraw()
	elif Input.is_action_just_pressed("voltar") or (Input.is_action_just_pressed("confirmar") and _op_pausa == 0):
		_pausado = false
		get_tree().paused = false
		Som.tocar("fechar")
		_tela.queue_redraw()
	elif Input.is_action_just_pressed("confirmar") and _op_pausa == 1:
		_pausado = false
		get_tree().paused = false
		arena.morrer()


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, alinhar := HORIZONTAL_ALIGNMENT_LEFT, largura := -1.0) -> void:
	var f: Font = Dados.fonte
	_tela.draw_string(f, p + Vector2(1, 1), s, alinhar, largura, tam, Color(0, 0, 0, cor.a * 0.8))
	_tela.draw_string(f, p, s, alinhar, largura, tam, cor)


func _desenhar() -> void:
	if arena == null or arena.jogador == null:
		return
	if arena.duelo_ativo:
		_duelo_hud()
	else:
		# XP
		var frac: float = arena.xp / arena.xp_para(arena.nivel)
		_tela.draw_rect(Rect2(0, 0, W, 9), Color(0.05, 0.05, 0.1, 0.85))
		_tela.draw_rect(Rect2(1, 1, (W - 2) * clampf(frac, 0, 1), 7), Color(0.3, 0.6, 1.0))
		_txt(Vector2(W - 70, 8), "NV %d" % arena.nivel, 8, Color.WHITE)
		# tempo
		var tempo: float = arena.diretor.tempo
		var cor_t := Color(1, 0.4, 0.4) if arena.diretor.enxame_final else Color.WHITE
		_txt(Vector2(0, 30), "%02d:%02d" % [int(tempo) / 60, int(tempo) % 60], 16, cor_t, HORIZONTAL_ALIGNMENT_CENTER, W)
		_txt(Vector2(W - 120, 24), "Abates %d" % arena.abates, 8, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 112)
	_icones_build()
	if not arena.duelo_ativo:
		# vida do chefe
		var chefes: Array = arena.chefes()
		if not chefes.is_empty():
			var c = chefes[0]
			var fr: float = c.hp / c.hpmax
			_tela.draw_rect(Rect2(170, H - 22, 300, 10), Color(0.05, 0.02, 0.05, 0.9))
			_tela.draw_rect(Rect2(171, H - 21, 298 * fr, 8), Color(0.85, 0.15, 0.25))
			_txt(Vector2(0, H - 26), str(c.d.get("nome", "")), 8, Color(1, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
		# seta pra tomada
		var s = arena.chao.mais_perto_livre(arena.jogador.position)
		if s:
			var rel: Vector2 = s.pos - arena.camera.position
			if absf(rel.x) > W / 2 - 10 or absf(rel.y) > H / 2 - 10:
				var dir := rel.normalized()
				var borda := Vector2(W / 2, H / 2) + dir * minf((W / 2 - 24) / maxf(absf(dir.x), 0.01), (H / 2 - 24) / maxf(absf(dir.y), 0.01))
				var pulso := 0.6 + 0.4 * sin(_t * 5)
				var pts := PackedVector2Array([borda + dir * 9, borda + dir.orthogonal() * 6 - dir * 4, borda - dir.orthogonal() * 6 - dir * 4])
				_tela.draw_colored_polygon(pts, Color(1, 0.85, 0.3, pulso))
				_tela.draw_texture_rect(Dados.tex("tomada"), Rect2(borda - dir * 18 - Vector2(8, 9), Vector2(16, 18)), false, Color(1, 1, 1, pulso))
	# mensagens
	var y := H - 50.0
	for i in range(_msgs.size() - 1, -1, -1):
		var m: Dictionary = _msgs[i]
		_txt(Vector2(0, y), m.txt, 8, Color(m.cor, clampf(m.t * 2, 0, 1)), HORIZONTAL_ALIGNMENT_CENTER, W)
		y -= 12
	if _anuncio.t > 0:
		var a := clampf(_anuncio.t, 0, 1)
		var esc := 16
		_txt(Vector2(0, 110), _anuncio.txt, esc, Color(_anuncio.cor, a), HORIZONTAL_ALIGNMENT_CENTER, W)
	if _pausado:
		_tela.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
		_txt(Vector2(0, 130), "PAUSADO", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, W)
		var ops := ["Continuar", "Desistir da partida"]
		for i in 2:
			var sel := i == _op_pausa
			_txt(Vector2(0, 170 + i * 18), ("> " if sel else "") + ops[i], 8, Color(1, 0.9, 0.4) if sel else Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
		_txt(Vector2(0, 240), "WASD/setas: andar   Espaço/Shift: dash   Esc: pausa", 8, Color(0.7, 0.7, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)


func _icones_build() -> void:
	var x := 6.0
	for a in arena.armas.lista:
		var d := Dados.item(a.id)
		_icone(Vector2(x, 13), str(d.get("icone", a.id)), a.nivel, d.get("evolucao", false))
		x += 20
	x = 6.0
	for id in arena.passivos:
		_icone(Vector2(x, 33), str(Dados.item(id).get("icone", id)), arena.passivos[id], false)
		x += 20


func _duelo_hud() -> void:
	var d: Node2D = arena.duelo
	# vida do duelo (no lugar da barra de XP)
	var hpmax: float = arena.stat("vida_max")
	var fr := clampf(arena.jogador.hp / hpmax, 0.0, 1.0)
	_tela.draw_rect(Rect2(0, 0, W, 9), Color(0.05, 0.05, 0.1, 0.85))
	_tela.draw_rect(Rect2(1, 1, (W - 2) * fr, 7), Color(0.9, 0.25, 0.3))
	_txt(Vector2(6, 8), "%d / %d" % [ceili(arena.jogador.hp), int(hpmax)], 8, Color.WHITE)
	var vivos: int = d.vivos().size()
	_txt(Vector2(0, 21), "DUELO FINAL", 8, Color(1, 0.5, 0.45), HORIZONTAL_ALIGNMENT_CENTER, W)
	_txt(Vector2(0, 42), "Vivos: %d" % vivos, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, W)
	var f: float = d.fracao_anel()
	if d.estado == "luta":
		var txt := "O anel está fechando" if f > 0.0 and f < 1.0 else ("Anel no tamanho final!" if f >= 1.0 else "O anel começa a fechar em %ds" % maxi(1, ceili(float(d.cfg.get("arena", {}).get("inicio_encolher", 12)) - d.t_luta)))
		_txt(Vector2(0, 58), txt, 8, Color(1, 0.7, 0.6, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
	# fora do anel: aviso piscando
	if d.estado == "luta" and arena.jogador.position.distance_to(d.centro) > d.raio and d.lut_jogador.vivo:
		if int(_t * 6) % 2 == 0:
			_txt(Vector2(0, 90), "VOLTE PRO ANEL!", 16, Color(1, 0.3, 0.3), HORIZONTAL_ALIGNMENT_CENTER, W)
	# setas pros rivais que estão fora da tela
	for l in d.vivos():
		if l.jogador:
			continue
		var rel: Vector2 = l.pos - arena.camera.position
		var cor: Color = l.cor
		if absf(rel.x) > W / 2 - 14 or absf(rel.y) > H / 2 - 14:
			var dir := rel.normalized()
			var borda := Vector2(W / 2, H / 2) + dir * minf((W / 2 - 26) / maxf(absf(dir.x), 0.01), (H / 2 - 26) / maxf(absf(dir.y), 0.01))
			var pts := PackedVector2Array([borda + dir * 10, borda + dir.orthogonal() * 6 - dir * 4, borda - dir.orthogonal() * 6 - dir * 4])
			_tela.draw_colored_polygon(pts, cor)
			var hf: float = d._hp_frac(l)
			_tela.draw_rect(Rect2(borda - dir * 14 - Vector2(10, 2), Vector2(20, 4)), Color(0, 0, 0, 0.7))
			_tela.draw_rect(Rect2(borda - dir * 14 - Vector2(9, 1), Vector2(18 * hf, 2)), cor)
	# lista de lutadores (canto direito)
	var y := 24.0
	for l in d.lutadores:
		var hf2: float = d._hp_frac(l) if l.vivo else 0.0
		var c: Color = l.cor if l.vivo else Color(0.45, 0.45, 0.5)
		_txt(Vector2(W - 112, y + 8), l.nome.left(8), 8, c, HORIZONTAL_ALIGNMENT_LEFT, 64)
		_tela.draw_rect(Rect2(W - 46, y, 40, 5), Color(0, 0, 0, 0.7))
		_tela.draw_rect(Rect2(W - 45, y + 1, 38 * hf2, 3), c)
		y += 12


func _icone(p: Vector2, icone: String, nv: int, evo: bool) -> void:
	_tela.draw_rect(Rect2(p - Vector2(1, 1), Vector2(18, 18)), Color(1, 0.8, 0.3, 0.9) if evo else Color(0, 0, 0, 0.55))
	var t := Dados.icone(icone)
	if t:
		_tela.draw_texture(t, p)
	_txt(p + Vector2(10, 19), str(nv) if not evo else "", 8, Color(1, 1, 0.6))
