extends CanvasLayer
const Perf := preload("res://scripts/hordas/perf.gd")
## Tela da partida: barra de XP, nível, tempo, abates, armas e passivos, vida do chefe,
## seta pra tomada mais perto, mensagens e o menu de pausa.

const W := 640.0
const H := 360.0
const TelaOpcoes := preload("res://scripts/hordas/tela_opcoes.gd")
const Interface := preload("res://scripts/hordas/interface.gd")
const Criacao := preload("res://scripts/hordas/criacao.gd")
const Descobertas := preload("res://scripts/hordas/descobertas.gd")
const Conjuntos := preload("res://scripts/hordas/conjuntos.gd")
const Mochila := preload("res://scripts/hordas/mochila.gd")
const OPS_PAUSA := ["Continuar", "Opções", "Desistir da partida"]

var arena: Node
var _tela := Control.new()
var _msgs: Array = []        # {txt, cor, t}
var _anuncio := {"txt": "", "cor": Color.WHITE, "t": 0.0}
var _pausado := false
var _op_pausa := 0
var _t := 0.0
var _quadro_pausa := -1
var _opcoes: Node = null     # tela de Opções aberta pela pausa
var _mouse_ult := Vector2(-1, -1)


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


func limpar_mensagens() -> void:
	_msgs.clear()


func atualizar(dt: float) -> void:
	var _pp := Perf.ini()
	atualizar_i(dt)
	Perf.fim("hud_a", _pp)


func atualizar_i(dt: float) -> void:
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
	_mouse_ult = _tela.get_local_mouse_position()
	get_tree().paused = not arena.eh_online   # no online o jogo dos outros não para
	Som.ui("abrir")
	_tela.queue_redraw()


## Opção "Pausar ao sair da janela": trocou de janela (alt-tab) no meio da partida, pausa sozinho.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT or not Config.v("pausar_fora") or arena == null:
		return
	if not arena.bot and not arena.eh_online and not _pausado and not arena.cartas.aberto() and arena.jogador and arena.jogador.hp > 0:
		pausar()


func _pausa_rects() -> Array:
	var r := []
	for i in OPS_PAUSA.size():
		r.append(Rect2(W / 2 - 100, 170 + i * 18 - 11, 200, 15))
	return r


func _retomar() -> void:
	_pausado = false
	get_tree().paused = false
	Som.ui("voltar")
	_tela.queue_redraw()


func _pausa_confirmar() -> void:
	match OPS_PAUSA[_op_pausa]:
		"Continuar":
			_retomar()
		"Opções":
			Som.ui("confirmar")
			_opcoes = TelaOpcoes.new()
			add_child(_opcoes)
			_opcoes.fechou.connect(func():
				_opcoes = null
				_quadro_pausa = Engine.get_process_frames())   # o Esc que fechou as Opções não fecha a pausa junto
		"Desistir da partida":
			_pausado = false
			get_tree().paused = false
			arena.desistir()


func _process(_dt: float) -> void:
	var _pp := Perf.ini()
	_process_i(_dt)
	Perf.fim("hud_p", _pp)


func _process_i(_dt: float) -> void:
	if not _pausado or _opcoes or Engine.get_process_frames() == _quadro_pausa:
		return
	var n := OPS_PAUSA.size()
	var mp := _tela.get_local_mouse_position()
	if mp != _mouse_ult:   # passar o mouse por cima escolhe (só se ele se mexeu)
		_mouse_ult = mp
		var q := Interface.quem(_pausa_rects(), mp)
		if q >= 0 and q != _op_pausa:
			_op_pausa = q
			Som.ui("cursor")
			_tela.queue_redraw()
	if Input.is_action_just_pressed("cima"):
		_op_pausa = (_op_pausa - 1 + n) % n
		Som.ui("cursor")
		_tela.queue_redraw()
	elif Input.is_action_just_pressed("baixo"):
		_op_pausa = (_op_pausa + 1) % n
		Som.ui("cursor")
		_tela.queue_redraw()
	elif Input.is_action_just_pressed("voltar"):
		_retomar()
	elif Input.is_action_just_pressed("confirmar"):
		_pausa_confirmar()


## Esc/Start abre a pausa. Só chega aqui o Esc que ninguém consumiu: o que fecha o chat, a loja, o mapa ou o resultado não abre a pausa junto.
func _unhandled_input(e: InputEvent) -> void:
	if arena and e.is_action_pressed("voltar") and not e.is_echo() and not _pausado and not arena.acabou and not arena.cartas.aberto():
		get_viewport().set_input_as_handled()
		pausar()


func _input(e: InputEvent) -> void:
	if not _pausado or _opcoes or Engine.get_process_frames() == _quadro_pausa or not Interface.clique(e):
		return
	var q := Interface.quem(_pausa_rects(), _tela.get_local_mouse_position())
	if q >= 0:
		_op_pausa = q
		get_viewport().set_input_as_handled()
		_pausa_confirmar()


## esc = true: o texto obedece à opção "Texto do HUD" (Grande = 1,5x). Só os textos com espaço sobrando usam (fase, abates, avisos).
func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, alinhar := HORIZONTAL_ALIGNMENT_LEFT, largura := -1.0, esc := false) -> void:
	if esc:
		tam = Interface.tam_hud(tam)
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
		# barra de XP com o nível dentro, alinhado à direita na mesma coluna do "Abates"
		_tela.draw_rect(Rect2(0, 0, W, 11), Color(0.05, 0.05, 0.1, 0.85))
		_tela.draw_rect(Rect2(1, 1, (W - 2) * clampf(frac, 0, 1), 9), Color(0.3, 0.6, 1.0))
		_tela.draw_rect(Rect2(1, 1, (W - 2) * clampf(frac, 0, 1), 1), Color(0.6, 0.85, 1.0))   # brilho em cima
		_txt(Vector2(W - 120, 10), "NV %d" % arena.nivel, 8, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 112)
		# tempo
		var df = arena.diretor
		var fa: Dictionary = df.fases()[df.fase_idx]
		var resta := maxf(0.0, float(fa.get("duracao", 0)) - df.t_fase)
		var cor_t: Color = Interface.cor("alerta") if df.enxame_final else Color.WHITE
		var rotulo_fase := "FASE %d/%d  %s" % [df.fase_idx + 1, df.fases().size(), str(fa.get("nome", "")).to_upper()]
		if fa.has("regiao"):   # regiões (#64): "FLORESTA SOMBRIA 2/5  TRILHA TORTA"
			rotulo_fase = "%s %d/%d  %s" % [str(fa.regiao_nome).to_upper(), int(fa.andar_regiao) + 1, int(Dados.json("regioes").get("fases_por_regiao", 5)), str(fa.get("nome", "")).to_upper()]
		_txt(Vector2(0, 21), rotulo_fase, 8, Color(0.7, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER, W, true)
		if df.saida_leve:
			_txt(Vector2(0, 42), "PORTAL ABERTO", 12, Color(0.75, 0.65, 1), HORIZONTAL_ALIGNMENT_CENTER, W)
		elif df.pror_ativa():   # prorrogação (#112): o cronômetro sobe e a cada degrau fica mais difícil e paga mais ouro
			var pt: float = df.pror_t()
			_txt(Vector2(0, 42), "+%02d:%02d" % [int(pt) / 60, int(pt) % 60], 16, Interface.cor("alerta"), HORIZONTAL_ALIGNMENT_CENTER, W)
			_txt(Vector2(0, 54), "PRORROGAÇÃO  nível %d  ouro x%.2f" % [df.pror_degrau(), df.mult_ouro()], 8, Color(1, 0.75, 0.35), HORIZONTAL_ALIGNMENT_CENTER, W, true)
		elif df.final_chamado:
			_txt(Vector2(0, 42), "CHEFE!", 16, Interface.cor("alerta"), HORIZONTAL_ALIGNMENT_CENTER, W)
			var jr: float = df.janela_resta()
			if jr > 0.0 and not df.enxame_final:
				_txt(Vector2(0, 54), "derrote em %02d:%02d" % [int(jr) / 60, int(jr) % 60], 8, Color(1, 0.75, 0.6), HORIZONTAL_ALIGNMENT_CENTER, W, true)
		else:
			_txt(Vector2(0, 42), "%02d:%02d" % [int(resta) / 60, int(resta) % 60], 16, cor_t, HORIZONTAL_ALIGNMENT_CENTER, W)
		var abates := "Abates %d" % arena.abates
		_txt(Vector2(0, 24), abates, 8, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, W - 8, true)
		# ouro (mapa, #32) na mesma linha, à esquerda dos abates: embaixo ficam os fragmentos/energia do dragão
		var larg_ab: float = Dados.fonte.get_string_size(abates, HORIZONTAL_ALIGNMENT_LEFT, -1, Interface.tam_hud(8)).x
		_txt(Vector2(0, 24), "Ouro %d" % arena.ouro, 8, Color(1, 0.85, 0.35), HORIZONTAL_ALIGNMENT_RIGHT, W - 8 - larg_ab - 12, true)
		_energia_forma()
		_dicas_santuario()
		_objetivo()
		_missao()
	_icones_build()
	if not arena.duelo_ativo:
		_conjuntos()
	_especial()
	_provisoes()
	if not arena.duelo_ativo:
		# vida do chefe
		var chefes: Array = arena.chefes()
		if not chefes.is_empty():
			var c = chefes[0]
			var fr: float = c.hp / c.hpmax
			_tela.draw_rect(Rect2(170, H - 22, 300, 10), Color(0.05, 0.02, 0.05, 0.9))
			_tela.draw_rect(Rect2(171, H - 21, 298 * fr, 8), Interface.cor("vida_chefe"))
			_txt(Vector2(0, H - 26), str(c.d.get("nome", "")), 8, Color(1, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
			# seta na borda apontando o chefe que está fora da tela (Death Must Die / 20MTD): vermelha, com a distância em metros (px/10)
			for k in mini(chefes.size(), 2):
				_seta_chefe(chefes[k])
		# seta pra tomada
		var s = arena.chao.mais_perto_livre(arena.jogador.position)
		if s:
			var b = _borda(s.pos, 24.0)
			if b != null:
				var pulso := 0.6 + 0.4 * sin(_t * 5)
				_seta(b, 9.0, 6.0, Color(1, 0.85, 0.3, pulso))
				_tela.draw_texture_rect(Dados.tex(str(Descobertas.cfg().get("santuarios", {}).get("sprite", "tomada"))), Rect2(b.p - b.dir * 18 - Vector2(8, 9), Vector2(16, 18)), false, Color(1, 1, 1, pulso))
	# mensagens
	var y := H - 50.0
	for i in range(_msgs.size() - 1, -1, -1):
		var m: Dictionary = _msgs[i]
		_txt(Vector2(0, y), m.txt, 8, Color(m.cor, clampf(m.t * 2, 0, 1)), HORIZONTAL_ALIGNMENT_CENTER, W, true)
		y -= Interface.tam_hud(8) + 4
	if _anuncio.t > 0:
		var a := clampf(_anuncio.t, 0, 1)
		var esc := 16
		_txt(Vector2(0, 110), _anuncio.txt, esc, Color(_anuncio.cor, a), HORIZONTAL_ALIGNMENT_CENTER, W)
	if Config.v("mostrar_fps"):
		_txt(Vector2(4, H - 4), "%d FPS" % Engine.get_frames_per_second(), 8, Color(0.6, 1, 0.6))
	if _pausado:
		_tela.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
		_txt(Vector2(0, 130), "PAUSADO", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, W)
		for i in OPS_PAUSA.size():
			var sel := i == _op_pausa
			var rotulo: String = OPS_PAUSA[i]
			if rotulo == "Desistir da partida" and Criacao.eh_criado(arena.heroi_id):
				rotulo = "Desistir (o herói morre de vez)"   # herói criado: desistir conta como morrer
			_txt(Vector2(0, 170 + i * 18), ("> " if sel else "") + rotulo, 8, Color(1, 0.9, 0.4) if sel else Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
		_txt(Vector2(0, 250), "WASD/setas: andar   Espaço/Shift: dash   Esc/Start: pausa   Mouse: clicar", 8, Color(0.7, 0.7, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
		_txt(Vector2(0, H - 14), Dados.texto_versao(), 8, Color(0.72, 0.74, 0.86, 0.85), HORIZONTAL_ALIGNMENT_CENTER, W)


## Ponto na borda da tela na direção de `pos` (mundo), a `margem` px da beirada; null se `pos` está visível.
## Devolve {p, dir, rel}. As setas da tomada, dos santuários, dos rivais do duelo e do chefe usam esta conta.
func _borda(pos: Vector2, margem: float, folga := 10.0):
	var rel: Vector2 = pos - arena.camera.position
	if absf(rel.x) <= W / 2 - folga and absf(rel.y) <= H / 2 - folga:
		return null
	var dir := rel.normalized()
	var p := Vector2(W / 2, H / 2) + dir * minf((W / 2 - margem) / maxf(absf(dir.x), 0.01), (H / 2 - margem) / maxf(absf(dir.y), 0.01))
	return {"p": p, "dir": dir, "rel": rel}


func _seta(b: Dictionary, ponta: float, lado: float, cor: Color) -> void:
	var p: Vector2 = b.p
	var d: Vector2 = b.dir
	_tela.draw_colored_polygon(PackedVector2Array([p + d * ponta, p + d.orthogonal() * lado - d * (ponta * 0.45), p - d.orthogonal() * lado - d * (ponta * 0.45)]), cor)


func _seta_chefe(c) -> void:
	var b = _borda(c.pos, 22.0)
	if b == null:
		return
	var cor: Color = Interface.cor("alerta")
	var pulso := 0.7 + 0.3 * sin(_t * 8)
	_seta(b, 12.0, 8.0, Color(cor, pulso))
	_seta(b, 7.0, 4.0, Color(0.1, 0.0, 0.0, 0.8))   # miolo escuro: a seta vira um contorno e se destaca de qualquer fundo
	var metros := int(b.rel.length() / 10.0)
	_txt(b.p - b.dir * 24.0 - Vector2(20, -3), "%dm" % metros, 8, Color(cor, pulso), HORIZONTAL_ALIGNMENT_CENTER, 40)


## Energia da transformação (dragão do Hazaki), embaixo do "Abates": enchendo, pronta (pisca "Q") ou o tempo que
## resta transformado. Só aparece depois de desbloqueada.
## Especial do herói (especial.gd) no canto de baixo à direita: o rosto dele num quadro, a recarga escurecendo
## o rosto como um relógio e os segundos; pronto, o quadro pisca em dourado. Em cima, o nome e a tecla.
func _especial() -> void:
	var e = arena.especial
	if e == null or not e.tem():
		return
	var lado := 30.0
	var r := Rect2(W - lado - 10.0, H - lado - 12.0, lado, lado)
	var pronto: bool = e.pronto()
	var borda := Color(0.35, 0.38, 0.5)
	if pronto:
		borda = Color(1, 0.85, 0.35).lerp(Color(1, 1, 0.8), 0.5 + 0.5 * sin(_t * 6.0))
	_tela.draw_rect(r.grow(2.0), borda)
	_tela.draw_rect(r, Color(0.06, 0.06, 0.1))
	var rosto := Dados.tex_personagem(str(arena.heroi.get("sprite", arena.heroi_id)), "rosto")
	if rosto:
		_tela.draw_texture_rect(rosto, r, false, Color.WHITE if pronto else Color(0.55, 0.55, 0.6))
	if not pronto:
		# relógio: a parte que falta da recarga fica escura, girando no sentido horário a partir do topo
		var falta: float = clampf(e.recarga / e.recarga_total(), 0.0, 1.0)
		var c := r.get_center()
		var pts := PackedVector2Array([c])
		var passos := 24
		for i in passos + 1:
			var a := -PI / 2 + TAU * (1.0 - falta) + TAU * falta * i / passos
			var dir := Vector2.from_angle(a)
			# até a borda do quadro (não um círculo): o raio para onde a reta encosta no lado do quadrado
			var ate := (lado * 0.5) / maxf(absf(dir.x), absf(dir.y))
			pts.append(c + dir * ate)
		if falta > 0.01:
			_tela.draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
		_txt(Vector2(r.position.x, r.position.y + 19), str(ceili(e.recarga)), 8, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, lado)
	var pad := not Input.get_connected_joypads().is_empty()
	_txt(Vector2(W - 214, r.position.y - 5), ("Y" if pad else "E") + ": " + str(e.d.get("nome", "")), 8,
		Color(1, 0.9, 0.5) if pronto else Color(0.65, 0.68, 0.78), HORIZONTAL_ALIGNMENT_RIGHT, 206)


## Consumíveis da mochila (#72) no canto de baixo à esquerda: um quadro por item com o ícone, a tecla e quantos restam; a poção
## ativa mostra uma barrinha com o tempo; a comida e o amuleto aparecem pequenos em cima. No controle, L3 usa o escolhido e R3 troca.
func _provisoes() -> void:
	var p = arena.provisoes
	if p == null:
		return
	var lado := 24.0
	var y := H - lado - 12.0
	var pad := not Input.get_connected_joypads().is_empty()
	for i in p.slots.size():
		var id := str(p.slots[i])
		var n := int(p.restantes.get(id, 0))
		var r := Rect2(8.0 + i * (lado + 8.0), y, lado, lado)
		var escolhido: bool = pad and i == p.sel
		_tela.draw_rect(r.grow(2.0), Color(1, 0.85, 0.35) if escolhido else (Color(0.4, 0.45, 0.6) if n > 0 else Color(0.2, 0.2, 0.26)))
		_tela.draw_rect(r, Color(0.06, 0.06, 0.1))
		Mochila.desenhar_icone(_tela, id, r.grow(-2.0), n <= 0)
		_txt(Vector2(r.position.x + 1, r.position.y + lado + 9), "%s" % ("L3" if escolhido else str(i + 1)), 8, Color(0.8, 0.82, 0.9) if n > 0 else Color(0.4, 0.4, 0.45))
		_txt(Vector2(r.position.x, r.position.y + 9), "x%d" % n, 8, Color(1, 1, 1) if n > 0 else Color(0.5, 0.5, 0.55), HORIZONTAL_ALIGNMENT_RIGHT, lado - 1.0)
	var x := 8.0
	var y2 := y - 20.0
	for b in p.buffs:
		var d: Dictionary = Mochila.item(str(b.id))
		Mochila.desenhar_icone(_tela, str(b.id), Rect2(x, y2, 14.0, 14.0))
		_tela.draw_rect(Rect2(x, y2 + 15.0, 14.0, 2.0), Color(0, 0, 0, 0.7))
		_tela.draw_rect(Rect2(x, y2 + 15.0, 14.0 * clampf(b.t / b.tmax, 0.0, 1.0), 2.0), Color(float(d.cor[0]), float(d.cor[1]), float(d.cor[2])))
		x += 18.0
	for id in p.comidas_ativas():
		Mochila.desenhar_icone(_tela, str(id), Rect2(x, y2, 14.0, 14.0))
		x += 18.0
	if p.amuleto != "":
		Mochila.desenhar_icone(_tela, p.amuleto, Rect2(x, y2, 14.0, 14.0), p.fenix_gasta)


func _energia_forma() -> void:
	var h = arena.habilidades
	if h != null and h.tem() and not h.desbloqueada and str(h.d().get("desbloqueio", {}).get("tipo", "")) == "fragmentos":
		_fragmentos(h)
		return
	if h == null or not h.tem() or not h.desbloqueada:
		return
	var cor := Color(0.25, 0.45, 1.0)
	var x := W - 112.0
	var y := 31.0
	var ic := Dados.icone(str(h.d().get("icone", "")))
	if ic:
		_tela.draw_texture_rect(ic, Rect2(x - 20, y - 3, 16, 16), false)
	var frac: float = h.energia / h.energia_max()
	_tela.draw_rect(Rect2(x, y, 104, 7), Color(0.05, 0.05, 0.1, 0.85))
	_tela.draw_rect(Rect2(x + 1, y + 1, 102 * clampf(frac, 0, 1), 5), cor)
	_tela.draw_rect(Rect2(x + 1, y + 1, 102 * clampf(frac, 0, 1), 1), Color(0.55, 0.85, 1.0))
	var txt := "ENERGIA %d%%" % roundi(frac * 100.0)
	var cor_t := Color(0.6, 0.7, 0.9)
	if h.ativa:
		txt = "DRAGÃO  %ds" % ceili(h.restante())
		cor_t = Color(0.55, 0.85, 1.0)
	elif h.pronta():
		txt = "Q: DRAGÃO!"
		cor_t = Color(1, 0.9, 0.4) if int(_t * 4) % 2 == 0 else Color(0.55, 0.85, 1.0)
	_txt(Vector2(x, y + 17), txt, 8, cor_t, HORIZONTAL_ALIGNMENT_RIGHT, 104)


## Fragmentos da transformação (#21): um losango por fragmento, cheio quando já achou. Some quando a forma desperta.
func _fragmentos(h) -> void:
	var total: int = arena.descobertas.precisa(h.atual)
	var tem: int = arena.descobertas.tem_fragmentos(h.atual)
	var x := W - 112.0
	var y := 31.0
	var ic := Dados.icone(str(h.d().get("icone", "")))
	if ic:
		_tela.draw_texture_rect(ic, Rect2(x - 20, y - 3, 16, 16), false, Color(1, 1, 1, 1.0 if tem > 0 else 0.45))
	for i in total:
		var c := Vector2(x + 8 + i * 22, y + 4)
		var pts := PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0)])
		if i < tem:
			_tela.draw_colored_polygon(pts, Color(0.45, 0.7, 1.0))
		else:
			pts.append(pts[0])
			_tela.draw_polyline(pts, Color(0.4, 0.45, 0.6, 0.8), 1.0)
	_txt(Vector2(x - 12, y + 21), "FRAGMENTOS %d/%d" % [tem, total], 8, Color(0.6, 0.75, 1.0) if tem > 0 else Color(0.55, 0.58, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, 116)


## Indicação sutil (seção 21): uma setinha fraca na borda da tela apontando santuário especial que ainda não foi usado.
func _dicas_santuario() -> void:
	for s in arena.chao.santuarios:
		if s.usado or s.tipo == "tomada":
			continue
		var b = _borda(s.pos, 18.0, 14.0)
		if b == null:
			continue
		var cor: Color = arena.chao.COR_TIPO.get(s.tipo, Color.WHITE)
		_seta(b, 8.0, 5.0, Color(cor, 0.3 + 0.2 * sin(_t * 3.0)))


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
	x = 6.0
	for slot in arena.equipamentos:   # equipamentos vestidos (sem número de nível)
		var eid: String = arena.equipamentos[slot]
		_icone(Vector2(x, 53), str(Dados.item(eid).get("icone", eid)), 0, false)
		x += 20
	x = 6.0
	var defs: Dictionary = Dados.json("dadivas").get("lista", {}).merged(Dados.json("dadivas").get("duplas", {}))
	for dd in arena.descobertas.dadivas:   # dádivas dos santuários: moldura na cor da raridade (dupla: cor própria)
		var cfg_d: Dictionary = Dados.json("dadivas").get("_config", {})
		var cor: Array = cfg_d.get("dupla", {}).get("cor", [1, 1, 1]) if dd.raridade == "dupla" else cfg_d.get("raridades", {}).get(dd.raridade, {}).get("cor", [1, 1, 1])
		_tela.draw_rect(Rect2(x - 1, 72, 18, 18), Color(Interface.cor_raridade(str(dd.raridade), Color(cor[0], cor[1], cor[2])), 0.9))
		var t := Dados.icone(str(defs.get(dd.id, {}).get("icone", "")))
		if t:
			_tela.draw_texture(t, Vector2(x, 73))
		x += 20


## Etiquetas da build e quanto falta pro próximo degrau do conjunto (#63), embaixo dos ícones à esquerda: ligado = cor da
## etiqueta, ainda não = apagado. Na pausa, mostra também o que cada degrau ligado dá.
func _conjuntos() -> void:
	var lin: Array = arena.conj_resumo
	if lin.is_empty():
		return
	var tam: int = Interface.tam_hud(8)
	var passo := float(tam) + 3.0
	var y := 98.0
	for i in mini(lin.size(), 7):
		var l: Dictionary = lin[i]
		var lig: bool = int(l.ativo) > 0
		var cor: Color = l.cor if lig else Color(l.cor, 0.5).lerp(Color(0.6, 0.6, 0.65, 0.6), 0.5)
		_tela.draw_rect(Rect2(6, y - tam + 1, 5, 5), cor)
		_txt(Vector2(14, y), "%s %s" % [str(l.nome), Conjuntos.progresso_txt(l)], tam, cor)
		if _pausado and lig:
			_txt(Vector2(150, y), str(l.texto), tam, Color(0.85, 0.9, 1.0))
		y += passo


## Objetivo do andar (#63): nome, barra de progresso, tempo que sobra, e setas pros alvos. Fica embaixo do relógio.
func _objetivo() -> void:
	var ob = arena.objetivo
	if ob == null or not ob.visivel():
		return
	var d: Dictionary = ob.tipo_def(ob.id)
	var cor: Color = ob.cor_de(ob.id)
	var fim: bool = ob.est >= ob.CUMPRIDO
	var tit := str(d.get("nome", ""))
	var det := ""
	match str(ob.id):
		"pira":
			det = "%d/%d s" % [int(ob.prog), int(ob.alvo)]
		_:
			det = "%d/%d" % [int(ob.prog), int(ob.alvo)]
	if ob.est == ob.CUMPRIDO:
		cor = Color(0.5, 1.0, 0.6)
		det = "CUMPRIDO"
	elif ob.est == ob.FALHOU:
		cor = Color(1.0, 0.45, 0.4)
		det = "FALHOU"
	else:
		det += "   %02d:%02d" % [int(ob.resta) / 60, int(ob.resta) % 60]
	var pulso := 0.8 + 0.2 * sin(_t * 5.0) if not fim else 1.0
	_txt(Vector2(0, 68), tit, 8, Color(cor, pulso), HORIZONTAL_ALIGNMENT_CENTER, W, true)
	var bw := 150.0
	var bx := (W - bw) * 0.5
	var fr: float = clampf(ob.prog / maxf(ob.alvo, 0.01), 0.0, 1.0)
	_tela.draw_rect(Rect2(bx - 1, 80, bw + 2, 8), Color(0.05, 0.03, 0.08, 0.85))
	_tela.draw_rect(Rect2(bx, 81, bw * fr, 6), Color(cor, 0.9))
	_txt(Vector2(0, 98), det, 8, Color(0.92, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER, W, true)
	if ob.est == ob.ANDAMENTO:
		for p in ob.marcas:
			var b = _borda(p, 22.0)
			if b == null:
				continue
			var pl := 0.65 + 0.35 * sin(_t * 6.0)
			_seta(b, 11.0, 7.0, Color(cor, pl))
			_seta(b, 6.0, 3.5, Color(0.08, 0.04, 0.1, 0.8))
			_txt(b.p - b.dir * 24.0 - Vector2(20, -3), "%dm" % int(b.rel.length() / 10.0), 8, Color(cor, pl), HORIZONTAL_ALIGNMENT_CENTER, 40)


## Missão do chefe (#112): nome, barra, texto curto ("Fragmentos 2/4", "Leve ao altar") e setas pros pontos de interesse. Abaixo do objetivo.
func _missao() -> void:
	var ms = arena.missao
	if ms == null or not ms.visivel():
		return
	var cor: Color = ms.cor_de(ms.id)
	if ms.est == ms.CUMPRIDO:
		cor = Color(0.5, 1.0, 0.6)
	elif ms.est == ms.FALHOU:
		cor = Color(1.0, 0.45, 0.4)
	var tx: Array = ms.texto()
	var pulso := 0.8 + 0.2 * sin(_t * 5.0) if ms.est == ms.ANDAMENTO else 1.0
	var y0 := 112.0 if arena.objetivo.visivel() else 68.0
	_txt(Vector2(0, y0), str(tx[0]), 8, Color(cor, pulso), HORIZONTAL_ALIGNMENT_CENTER, W, true)
	var bw := 120.0
	var bx := (W - bw) * 0.5
	_tela.draw_rect(Rect2(bx - 1, y0 + 12, bw + 2, 8), Color(0.05, 0.03, 0.08, 0.85))
	_tela.draw_rect(Rect2(bx, y0 + 13, bw * float(tx[2]), 6), Color(cor, 0.9))
	_txt(Vector2(0, y0 + 30), str(tx[1]), 8, Color(0.92, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER, W, true)
	if ms.est == ms.ANDAMENTO:
		for p in ms.marcas():
			var b = _borda(p, 22.0)
			if b == null:
				continue
			var pl := 0.65 + 0.35 * sin(_t * 6.0)
			_seta(b, 11.0, 7.0, Color(cor, pl))
			_seta(b, 6.0, 3.5, Color(0.08, 0.04, 0.1, 0.8))
			_txt(b.p - b.dir * 24.0 - Vector2(20, -3), "%dm" % int(b.rel.length() / 10.0), 8, Color(cor, pl), HORIZONTAL_ALIGNMENT_CENTER, 40)


func _duelo_hud() -> void:
	var d: Node2D = arena.duelo
	# vida do duelo (no lugar da barra de XP)
	var hpmax: float = arena.stat("vida_max")
	var fr := clampf(arena.jogador.hp / hpmax, 0.0, 1.0)
	_tela.draw_rect(Rect2(0, 0, W, 11), Color(0.05, 0.05, 0.1, 0.85))
	_tela.draw_rect(Rect2(1, 1, (W - 2) * fr, 9), Interface.cor("vida_duelo"))
	_tela.draw_rect(Rect2(1, 1, (W - 2) * fr, 1), Color(1, 0.6, 0.6))   # brilho em cima, igual à barra de XP
	_txt(Vector2(6, 10), "%d / %d" % [ceili(arena.jogador.hp), int(hpmax)], 8, Color.WHITE)
	var vivos: int = d.vivos().size()
	# placa escura atrás do bloco de cima: o texto do HUD não se mistura com nome e número de quem passa embaixo
	_tela.draw_rect(Rect2(W / 2 - 120, 13, 240, 50), Color(0.03, 0.02, 0.06, 0.55))
	_tela.draw_rect(Rect2(W / 2 - 120, 13, 240, 50), Color(1, 0.5, 0.45, 0.25), false, 1.0)
	_txt(Vector2(0, 21), "DUELO FINAL", 8, Color(1, 0.5, 0.45), HORIZONTAL_ALIGNMENT_CENTER, W)
	_txt(Vector2(0, 42), "Vivos: %d" % vivos, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, W)
	var f: float = d.fracao_anel()
	if d.estado == "luta":
		var txt := "O anel está fechando" if f > 0.0 and f < 1.0 else ("Anel no tamanho final!" if f >= 1.0 else "O anel começa a fechar em %ds" % maxi(1, ceili(float(d.cfg.get("arena", {}).get("inicio_encolher", 12)) - d.t_luta)))
		_txt(Vector2(0, 58), txt, 8, Color(1, 0.7, 0.6, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
	# fora do anel: aviso piscando
	if d.estado == "luta" and arena.jogador.centro().distance_to(d.centro) > d.raio and d.lut_jogador.vivo:
		if int(_t * 6) % 2 == 0:
			_txt(Vector2(0, 90), "VOLTE PRO ANEL!", 16, Color(1, 0.3, 0.3), HORIZONTAL_ALIGNMENT_CENTER, W)
	# setas pros rivais que estão fora da tela
	for l in d.vivos():
		if l.jogador:
			continue
		var cor: Color = l.cor
		var b = _borda(l.pos, 26.0, 14.0)
		if b != null:
			_seta(b, 10.0, 6.0, cor)
			var hf: float = d._hp_frac(l)
			_tela.draw_rect(Rect2(b.p - b.dir * 14 - Vector2(10, 2), Vector2(20, 4)), Color(0, 0, 0, 0.7))
			_tela.draw_rect(Rect2(b.p - b.dir * 14 - Vector2(9, 1), Vector2(18 * hf, 2)), cor)
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
	_txt(p + Vector2(10, 19), str(nv) if not evo and nv > 0 else "", 8, Color(1, 1, 0.6))
