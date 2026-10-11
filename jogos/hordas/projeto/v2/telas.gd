extends RefCounted
## Telas simples do combate da v2 (o HUD bonito é de outro módulo): a escolha de cartas ao subir de nível (3 cartas com cor e brilho pela
## RARIDADE, mais rerrolar e banir), a roleta do baú, a tela de resultado (VOCÊ CAIU ou VITÓRIA, com as almas ganhas), os anúncios grandes
## e um texto de DEPURAÇÃO com vida, nível, XP, combo e abates (DESLIGADO por padrão agora que o HUD existe: ligue com --depur ou F1). Tudo é desenhado numa CanvasLayer dentro
## do SubViewport 960x540; o mouse não chega nos Controls de dentro dele, então o clique é lido por aqui (mundo.ap.mouse_na_tela()) e a
## escolha também aceita 1, 2, 3, setas, Enter, R (rerrolar) e B (banir a carta marcada).
## Os anúncios grandes e a barra do chefe são do HUD (v2/hud_anuncios.gd e hud.gd), que escutam os sinais do mundo.

const LARG := 960
const ALT := 540
const CARTA_L := 224.0
const CARTA_A := 214.0
const CARTA_Y := 178.0
const FOLGA := 24.0
const BTN_Y := 400.0

var combate
var mundo
var camada: CanvasLayer
var depuracao := true
var sel := 0
var mostrada_t := 0.0  # s desde que a tela de resultado abriu (ignora clique logo no começo)
var resultado_aberto := false
var escolha_aberta := false
var bau_aberto := false
var bau_pronto := false  # a roleta terminou de revelar tudo

var _fundo: ColorRect
var _escolha: Control
var _cartas: Array[Control] = []
var _estilos: Array[StyleBoxFlat] = []
var _titulo: Label
var _sub: Label
var _btn_r: Panel
var _btn_b: Panel
var _btn_r_txt: Label
var _btn_b_txt: Label
var _build: Label
var _res: Control
var _res_titulo: Label
var _res_linhas: Label
var _res_valores: Label
var _res_dica: Label
var _dep: Label
var _dep_t := 0.0
var _fonte: Font
var _fonte_t: Font
var _t_ui := 0.0
var _bau: Control
var _bau_titulo: Label
var _bau_slots: Array[Panel] = []
var _bau_estilos: Array[StyleBoxFlat] = []
var _bau_cartas: Array = []
var _bau_i := 0  # qual carta está girando
var _bau_t := 0.0
var _bau_fase := 0  # 0 = girando, 1 = pausa depois de revelar, 2 = tudo revelado
var _bau_tick := 0.0
var _bau_dica: Label


func montar(c, sv: Node) -> void:
	combate = c
	mundo = c.mundo
	_fonte = Dados.fonte
	_fonte_t = Dados.fonte_titulo
	camada = CanvasLayer.new()
	camada.layer = 5
	sv.add_child(camada)
	_fundo = ColorRect.new()
	_fundo.color = Color(0.02, 0.02, 0.05, 0.62)
	_fundo.size = Vector2(LARG, ALT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.visible = false
	camada.add_child(_fundo)
	_montar_escolha()
	_montar_bau()
	_montar_resultado()
	_dep = _rotulo("", 8, false, Color(0.9, 1.0, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	_dep.position = Vector2(6, 30)
	_dep.size = Vector2(500, 40)
	camada.add_child(_dep)
	depuracao = mundo.args.has("depur")  # o HUD (hud.gd) é o painel de verdade; este texto é só para depurar (--depur ou F1)
	_dep.visible = depuracao


func _rotulo(texto: String, tam: int, titulo: bool, cor: Color, alin: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", _fonte_t if titulo else _fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 4 if titulo else 3)
	l.horizontal_alignment = alin
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _estilo(sel_: bool, cor: Color = Color(0.36, 0.34, 0.45), rar := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.13, 0.12, 0.17, 0.97) if sel_ else Color(0.07, 0.065, 0.1, 0.96)
	s.bg_color = s.bg_color.lerp(cor, 0.1 + 0.05 * rar)
	s.border_color = cor.lerp(Color.WHITE, 0.45) if sel_ else cor
	s.set_border_width_all(2 + (1 if rar >= 2 else 0) + (1 if sel_ else 0))
	s.set_corner_radius_all(0)
	if rar > 0:  # o brilho em volta: mais forte quanto mais rara
		s.shadow_color = Color(cor.r, cor.g, cor.b, 0.18 + 0.12 * rar)
		s.shadow_size = 4 + 3 * rar
	return s


func _montar_escolha() -> void:
	_escolha = Control.new()
	_escolha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escolha.visible = false
	camada.add_child(_escolha)
	_titulo = _rotulo("", 48, true, Color(1.0, 0.86, 0.42), HORIZONTAL_ALIGNMENT_CENTER)
	_titulo.position = Vector2(0, 100)
	_titulo.size = Vector2(LARG, 60)
	_escolha.add_child(_titulo)
	_sub = _rotulo("Escolha uma carta", 8, false, Color(0.85, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	_sub.position = Vector2(0, 156)
	_sub.size = Vector2(LARG, 12)
	_escolha.add_child(_sub)
	var x0 := (LARG - (3.0 * CARTA_L + 2.0 * FOLGA)) * 0.5
	for i in 3:
		var p := Panel.new()
		p.position = Vector2(x0 + i * (CARTA_L + FOLGA), CARTA_Y)
		p.size = Vector2(CARTA_L, CARTA_A)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := _estilo(false)
		p.add_theme_stylebox_override("panel", st)
		_estilos.append(st)
		var tecla := _rotulo("[%d]" % (i + 1), 8, false, Color(0.7, 0.7, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
		tecla.position = Vector2(10, 8)
		tecla.size = Vector2(60, 12)
		p.add_child(tecla)
		var rar := _rotulo("", 8, false, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		rar.name = "rar"
		rar.position = Vector2(CARTA_L - 130, 8)
		rar.size = Vector2(120, 12)
		p.add_child(rar)
		var faixa := ColorRect.new()
		faixa.name = "faixa"
		faixa.position = Vector2(8, 24)
		faixa.size = Vector2(CARTA_L - 16, 3)
		faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(faixa)
		var nome := _rotulo("", 24, true, Color(1.0, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		nome.name = "nome"
		nome.position = Vector2(8, 34)
		nome.size = Vector2(CARTA_L - 16, 56)
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(nome)
		var desc := _rotulo("", 8, false, Color(0.88, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		desc.name = "desc"
		desc.position = Vector2(12, 98)
		desc.size = Vector2(CARTA_L - 24, 52)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(desc)
		var extra := _rotulo("", 8, false, Color(0.6, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		extra.name = "extra"
		extra.position = Vector2(12, 152)
		extra.size = Vector2(CARTA_L - 24, 52)
		extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(extra)
		_escolha.add_child(p)
		_cartas.append(p)
	# rerrolar e banir
	_btn_r = _botao(Vector2(LARG * 0.5 - 214, BTN_Y), "r")
	_btn_b = _botao(Vector2(LARG * 0.5 + 14, BTN_Y), "b")
	_btn_r_txt = _btn_r.get_node("t")
	_btn_b_txt = _btn_b.get_node("t")
	_build = _rotulo("", 8, false, Color(0.75, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	_build.position = Vector2(60, 440)
	_build.size = Vector2(LARG - 120, 40)
	_build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_escolha.add_child(_build)


func _botao(pos: Vector2, _id: String) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(200, 26)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _estilo(false, Color(0.5, 0.5, 0.62)))
	var t := _rotulo("", 8, false, Color(0.9, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	t.name = "t"
	t.position = Vector2(4, 8)
	t.size = Vector2(192, 12)
	p.add_child(t)
	_escolha.add_child(p)
	return p


func _montar_bau() -> void:
	_bau = Control.new()
	_bau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bau.visible = false
	camada.add_child(_bau)
	_bau_titulo = _rotulo("BAÚ!", 48, true, Color(1.0, 0.86, 0.42), HORIZONTAL_ALIGNMENT_CENTER)
	_bau_titulo.position = Vector2(0, 104)
	_bau_titulo.size = Vector2(LARG, 60)
	_bau.add_child(_bau_titulo)
	for i in 3:
		var p := Panel.new()
		p.size = Vector2(CARTA_L, 150.0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := _estilo(false)
		p.add_theme_stylebox_override("panel", st)
		_bau_estilos.append(st)
		var nome := _rotulo("", 24, true, Color(1.0, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		nome.name = "nome"
		nome.position = Vector2(8, 22)
		nome.size = Vector2(CARTA_L - 16, 56)
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(nome)
		var rar := _rotulo("", 8, false, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		rar.name = "rar"
		rar.position = Vector2(8, 8)
		rar.size = Vector2(CARTA_L - 16, 12)
		p.add_child(rar)
		var desc := _rotulo("", 8, false, Color(0.88, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		desc.name = "desc"
		desc.position = Vector2(12, 84)
		desc.size = Vector2(CARTA_L - 24, 60)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(desc)
		_bau.add_child(p)
		_bau_slots.append(p)
	_bau_dica = _rotulo("ENTER ou clique para continuar", 8, false, Color(1.0, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	_bau_dica.position = Vector2(0, 380)
	_bau_dica.size = Vector2(LARG, 12)
	_bau.add_child(_bau_dica)


func _montar_resultado() -> void:
	_res = Control.new()
	_res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res.visible = false
	camada.add_child(_res)
	_res_titulo = _rotulo("VOCÊ CAIU", 60, true, Color(1.0, 0.38, 0.32), HORIZONTAL_ALIGNMENT_CENTER)
	_res_titulo.position = Vector2(0, 80)
	_res_titulo.size = Vector2(LARG, 72)
	_res.add_child(_res_titulo)
	_res_linhas = _rotulo("Tempo\nAbates\nMaior combo\nNível\nAlmas ganhas", 16, false, Color(0.8, 0.82, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	_res_linhas.position = Vector2(300, 186)
	_res_linhas.size = Vector2(240, 190)
	_res_linhas.add_theme_constant_override("line_spacing", 12)
	_res.add_child(_res_linhas)
	_res_valores = _rotulo("", 16, false, Color(1.0, 0.95, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
	_res_valores.position = Vector2(540, 186)
	_res_valores.size = Vector2(120, 190)
	_res_valores.add_theme_constant_override("line_spacing", 12)
	_res.add_child(_res_valores)
	_res_dica = _rotulo("ENTER ou clique para jogar de novo", 8, false, Color(1.0, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	_res_dica.position = Vector2(0, 410)
	_res_dica.size = Vector2(LARG, 12)
	_res.add_child(_res_dica)


# ------------------------------------------------------------------ mostrar


## Mostra a escolha. `refresh` = é o mesmo menu com cartas novas (rerrolar ou banir): mantém a marcação.
func mostrar_escolha(cartas: Array, nivel: int, refresh := false) -> void:
	escolha_aberta = true
	if not refresh:
		sel = 0
	_fundo.visible = true
	_escolha.visible = true
	_titulo.text = "NÍVEL %d" % nivel
	var maxn := cartas.size()
	sel = clampi(sel, 0, maxi(maxn - 1, 0))
	for i in 3:
		var p := _cartas[i]
		p.visible = i < maxn
		if i >= maxn:
			continue
		var c: Dictionary = cartas[i]
		var cor: Color = c.get("cor", Color(0.8, 0.82, 0.86))
		(p.get_node("nome") as Label).text = str(c.nome)
		(p.get_node("nome") as Label).add_theme_color_override("font_color", cor.lerp(Color.WHITE, 0.55))
		(p.get_node("desc") as Label).text = str(c.desc)
		(p.get_node("extra") as Label).text = str(c.get("extra", ""))
		var rl := p.get_node("rar") as Label
		rl.text = str(c.get("rar_nome", "")).to_upper()
		rl.add_theme_color_override("font_color", cor.lerp(Color.WHITE, 0.3))
		(p.get_node("faixa") as ColorRect).color = Color(cor.r, cor.g, cor.b, 0.9)
		var rar := int(c.get("rar", 0))
		_estilos[i].shadow_size = 0 if rar == 0 else 4 + 3 * rar
	_marcar()
	_atualizar_botoes()
	_texto_build()
	combate.audio.tocar("carta", 1.0 + 0.12 * float(_rar_max(cartas)), 0.0, 0.0)


func _rar_max(cartas: Array) -> int:
	var m := 0
	for c in cartas:
		m = maxi(m, int(c.get("rar", 0)))
	return m


func _marcar() -> void:
	var cartas: Array = combate.progresso.cartas
	for i in 3:
		var c: Dictionary = cartas[i] if i < cartas.size() else {}
		var cor: Color = c.get("cor", Color(0.36, 0.34, 0.45))
		var rar := int(c.get("rar", 0))
		var novo := _estilo(i == sel, cor, rar)
		_estilos[i].bg_color = novo.bg_color
		_estilos[i].border_color = novo.border_color
		_estilos[i].shadow_color = novo.shadow_color
		_estilos[i].shadow_size = novo.shadow_size
		_estilos[i].set_border_width_all(2 + (1 if rar >= 2 else 0) + (1 if i == sel else 0))
		_cartas[i].position.y = CARTA_Y - (8.0 if i == sel else 0.0)


func _atualizar_botoes() -> void:
	var cs = combate.cartas
	var pr: bool = cs.pode_rerrolar()
	var pb: bool = cs.pode_banir()
	_btn_r_txt.text = "[R] Rerrolar (%d)" % cs.rerrolares_restantes() if cs.rerrolar_na_tela < cs.rerrolar_por_tela() else "[R] Rerrolar (já usou)"
	_btn_b_txt.text = "[B] Banir a marcada (%d)" % cs.banimentos_restantes()
	_btn_r.modulate = Color.WHITE if pr else Color(1, 1, 1, 0.4)
	_btn_b.modulate = Color.WHITE if pb else Color(1, 1, 1, 0.4)


func _texto_build() -> void:
	var partes: Array = []
	for r in combate.cartas.resumo():
		partes.append("%s %s" % [r.nome, ("nv %d" % r.nivel) if int(r.nivel) > 0 else "(evoluído)"])
	_build.text = "Sua build: " + ", ".join(partes) if not partes.is_empty() else "Sua build: só a katana (os golpes automáticos vêm pelas cartas)"


func mostrar_resultado() -> void:
	resultado_aberto = true
	mostrada_t = 0.0
	var venceu: bool = combate.venceu
	if mundo.get("meta_res") != null:
		return  # o resultado com as almas (resultado_meta.gd, por cima) mostra tudo; aqui fica só o estado (resultado_aberto)
	_fundo.visible = true
	_fundo.color = Color(0.05, 0.04, 0.0, 0.7) if venceu else Color(0.05, 0.0, 0.0, 0.72)
	_res_titulo.text = "VITÓRIA" if venceu else "VOCÊ CAIU"
	_res_titulo.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35) if venceu else Color(1.0, 0.38, 0.32))
	_res.visible = true
	var h = mundo.heroi
	var seg := int(mundo.tempo_partida)
	_res_valores.text = "%02d:%02d\n%d\nx%d\n%d\n%d" % [floori(seg / 60.0), seg % 60, mundo.abates, mundo.maior_combo, h.nivel, mundo.almas_partida]
	combate.audio.tocar("carta", 0.7, 0.0, 0.0)


func esconder() -> void:
	escolha_aberta = false
	resultado_aberto = false
	bau_aberto = false
	_escolha.visible = false
	_bau.visible = false
	_res.visible = false
	_fundo.visible = false
	_fundo.color = Color(0.02, 0.02, 0.05, 0.62)


func ligar_depuracao(v: bool) -> void:
	depuracao = v
	_dep.visible = v


# ------------------------------------------------------------------ baú


## A roleta do baú: as cartas já foram aplicadas; aqui só aparecem, uma a uma, depois de girar.
func mostrar_bau(cartas: Array) -> void:
	bau_aberto = true
	bau_pronto = false
	_bau_cartas = cartas
	_bau_i = 0
	_bau_t = 0.0
	_bau_fase = 0
	_fundo.visible = true
	_fundo.color = Color(0.04, 0.03, 0.0, 0.7)
	_bau.visible = true
	_bau_dica.visible = false
	var n := cartas.size()
	var x0 := (LARG - (n * CARTA_L + (n - 1) * FOLGA)) * 0.5
	for i in 3:
		var p := _bau_slots[i]
		p.visible = i < n
		if i >= n:
			continue
		p.position = Vector2(x0 + i * (CARTA_L + FOLGA), 200.0)
		_limpar_slot(i)
	combate.audio.tocar("bau", 1.0, 0.0, 0.0)


func _limpar_slot(i: int) -> void:
	var p := _bau_slots[i]
	(p.get_node("nome") as Label).text = "?"
	(p.get_node("rar") as Label).text = ""
	(p.get_node("desc") as Label).text = ""
	p.modulate = Color(1, 1, 1, 0.9)
	var novo := _estilo(false)
	_bau_estilos[i].bg_color = novo.bg_color
	_bau_estilos[i].border_color = novo.border_color
	_bau_estilos[i].shadow_size = 0


func _girar_slot(i: int) -> void:
	# um sorteio qualquer de nome e raridade, só para parecer uma roleta (não muda nada do jogo)
	var cs = combate.cartas
	var todas: Array = cs.disponiveis()
	var d: Dictionary = todas[randi() % todas.size()] if not todas.is_empty() else {"nome": "?"}
	var r: int = randi() % cs.rar.size()
	var cor := Color(cs.rar[r].cor[0], cs.rar[r].cor[1], cs.rar[r].cor[2])
	var p := _bau_slots[i]
	(p.get_node("nome") as Label).text = str(d.nome)
	(p.get_node("nome") as Label).add_theme_color_override("font_color", cor.lerp(Color.WHITE, 0.4))
	var novo := _estilo(false, cor, r)
	_bau_estilos[i].bg_color = novo.bg_color
	_bau_estilos[i].border_color = novo.border_color
	_bau_estilos[i].shadow_color = novo.shadow_color
	_bau_estilos[i].shadow_size = novo.shadow_size


func _revelar_slot(i: int) -> void:
	var c: Dictionary = _bau_cartas[i]
	var cor: Color = c.get("cor", Color(0.8, 0.82, 0.86))
	var rar := int(c.get("rar", 0))
	var p := _bau_slots[i]
	(p.get_node("nome") as Label).text = str(c.nome)
	(p.get_node("nome") as Label).add_theme_color_override("font_color", cor.lerp(Color.WHITE, 0.55))
	var rl := p.get_node("rar") as Label
	rl.text = str(c.get("rar_nome", "")).to_upper()
	rl.add_theme_color_override("font_color", cor.lerp(Color.WHITE, 0.3))
	(p.get_node("desc") as Label).text = "%s\n%s" % [str(c.desc), str(c.get("extra", ""))]
	var novo := _estilo(true, cor, rar)
	_bau_estilos[i].bg_color = novo.bg_color
	_bau_estilos[i].border_color = novo.border_color
	_bau_estilos[i].shadow_color = novo.shadow_color
	_bau_estilos[i].shadow_size = novo.shadow_size
	p.modulate = Color(1.8, 1.8, 1.8, 1.0)  # o clarão da revelação (vai baixando em atualizar)
	combate.fx.onda(mundo.heroi.pos, Color(cor.r, cor.g, cor.b, 0.9), 40.0 + 20.0 * rar, 0.35)
	combate.audio.tocar("nivel" if rar >= 3 else "escolher", 1.0 + 0.05 * rar, 0.0, 0.0)


func _atualizar_bau(dt: float) -> void:
	for i in 3:
		if _bau_slots[i].visible and _bau_slots[i].modulate.r > 1.0:
			var m := _bau_slots[i].modulate
			_bau_slots[i].modulate = Color(maxf(1.0, m.r - dt * 3.0), maxf(1.0, m.g - dt * 3.0), maxf(1.0, m.b - dt * 3.0), 1.0)
	if _bau_fase == 2:
		return
	var rol: Dictionary = combate.cartas.cfg.bau.roleta
	var giro := float(rol.giro) * (1.0 if _bau_i == 0 else 0.65)
	_bau_t += dt
	if _bau_fase == 0:
		_bau_tick -= dt
		if _bau_tick <= 0.0:
			_bau_tick = 0.06 + 0.12 * (_bau_t / giro) * (_bau_t / giro)  # a roleta desacelera
			_girar_slot(_bau_i)
			combate.audio.tocar("carta", 0.8 + 0.5 * (_bau_t / giro), -8.0, 0.0)
		if _bau_t >= giro:
			_revelar_slot(_bau_i)
			_bau_fase = 1
			_bau_t = 0.0
	elif _bau_fase == 1:
		if _bau_t >= float(rol.pausa):
			_bau_i += 1
			_bau_t = 0.0
			if _bau_i >= _bau_cartas.size():
				_bau_fase = 2
				bau_pronto = true
				_bau_dica.visible = true
			else:
				_bau_fase = 0
				_bau_tick = 0.0


## Pula a roleta: revela o que falta de uma vez.
func _pular_bau() -> void:
	while _bau_fase != 2:
		if _bau_fase == 0:
			_revelar_slot(_bau_i)
		_bau_i += 1
		if _bau_i >= _bau_cartas.size():
			_bau_fase = 2
			bau_pronto = true
			_bau_dica.visible = true
		else:
			_bau_fase = 0
			_bau_t = 0.0


# ------------------------------------------------------------------ quadro e entrada


func atualizar(dt: float) -> void:
	_t_ui += dt
	if resultado_aberto:
		mostrada_t += dt
		_res_dica.visible = int(mostrada_t * 2.0) % 2 == 0 or mostrada_t < 0.6
	if escolha_aberta:
		_pulsar_cartas()
	if bau_aberto:
		_atualizar_bau(dt)
	if depuracao:
		_dep_t -= dt
		if _dep_t <= 0.0:
			_dep_t = 0.1
			var h = mundo.heroi
			_dep.text = (
				"VIDA %d/%d   NV %d   XP %d/%d   FOLEGO %.1f\nCOMBO x%d   ABATES %d   VIVOS %d   %02d:%02d   [F1 esconde]"
				% [
					roundi(h.vida),
					roundi(h.vida_max),
					h.nivel,
					roundi(h.xp),
					roundi(h.xp_proximo),
					h.folego,
					mundo.combo,
					mundo.abates,
					mundo.monstros.size(),
					floori(mundo.tempo_partida / 60.0),
					int(mundo.tempo_partida) % 60
				]
			)


## O brilho das cartas raras respira (épico e lendário mais forte).
func _pulsar_cartas() -> void:
	var cartas: Array = combate.progresso.cartas
	for i in mini(3, cartas.size()):
		var rar := int(cartas[i].get("rar", 0))
		if rar > 0:
			var base := 4 + 3 * rar
			_estilos[i].shadow_size = base + roundi((2.0 + 2.0 * rar) * (0.5 + 0.5 * sin(_t_ui * (3.0 + rar) + float(i))))


## Entrada das telas. Devolve true se o evento foi usado (escolha de carta, baú, jogar de novo, F1).
func entrada(e: InputEvent) -> bool:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F1:
		ligar_depuracao(not depuracao)
		return true
	if escolha_aberta:
		return _entrada_escolha(e)
	if bau_aberto:
		return _entrada_bau(e)
	if resultado_aberto:
		return _entrada_resultado(e)
	return false


func _carta_sob_mouse() -> int:
	var m: Vector2 = mundo.ap.mouse_na_tela()
	for i in 3:
		if _cartas[i].visible and Rect2(_cartas[i].position, _cartas[i].size).grow(6.0).has_point(m):
			return i
	return -1


func _botao_sob_mouse() -> String:
	var m: Vector2 = mundo.ap.mouse_na_tela()
	if Rect2(_btn_r.position, _btn_r.size).has_point(m):
		return "r"
	if Rect2(_btn_b.position, _btn_b.size).has_point(m):
		return "b"
	return ""


func _entrada_escolha(e: InputEvent) -> bool:
	var n: int = combate.progresso.cartas.size()
	if e is InputEventMouseMotion:
		var i := _carta_sob_mouse()
		if i >= 0 and i != sel:
			sel = i
			_marcar()
			combate.audio.tocar("carta", 1.2, -6.0, 0.03)
		return true
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var b := _botao_sob_mouse()
		if b == "r":
			_rerrolar()
			return true
		if b == "b":
			_banir()
			return true
		var i := _carta_sob_mouse()
		if i >= 0:
			combate.progresso.escolher(i)
		return true
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1, KEY_2, KEY_3:
				var i: int = e.keycode - KEY_1
				if i < n:
					combate.progresso.escolher(i)
			KEY_LEFT, KEY_A:
				_mover(-1, n)
			KEY_RIGHT, KEY_D:
				_mover(1, n)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
				combate.progresso.escolher(sel)
			KEY_R:
				_rerrolar()
			KEY_B, KEY_X:
				_banir()
		return true
	if e.is_action_pressed("ui_left"):
		_mover(-1, n)
		return true
	if e.is_action_pressed("ui_right"):
		_mover(1, n)
		return true
	if e.is_action_pressed("ui_accept"):
		combate.progresso.escolher(sel)
		return true
	return false


func _rerrolar() -> void:
	if not combate.progresso.rerrolar():
		combate.audio.tocar("dano_heroi", 1.4, -10.0, 0.1)


func _banir() -> void:
	if not combate.progresso.banir(sel):
		combate.audio.tocar("dano_heroi", 1.4, -10.0, 0.1)
	else:
		combate.audio.tocar("morte", 1.2, -4.0, 0.0)


func _mover(d: int, n: int) -> void:
	if n <= 0:
		return
	sel = posmod(sel + d, n)
	_marcar()
	combate.audio.tocar("carta", 1.2, -6.0, 0.03)


func _entrada_bau(e: InputEvent) -> bool:
	var vai := false
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
		vai = true
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		vai = true
	elif e.is_action_pressed("ui_accept"):
		vai = true
	if vai:
		if bau_pronto:
			combate.baus.fechar()
		else:
			_pular_bau()
		return true
	return e is InputEventKey or e is InputEventMouseButton


func _entrada_resultado(e: InputEvent) -> bool:
	if mostrada_t < 0.6:
		return false
	var vai := false
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		vai = true
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		vai = true
	elif e.is_action_pressed("ui_accept"):
		vai = true
	if vai:
		mundo.reiniciar()
	return vai
