extends Control
## Tela de título da v2 (a cena principal): logo K.I.K.I.U sobre a arte de título (assets/titulo/fundo.png, feito por
## fonte_arte/gerar_fundo_titulo.py) e as opções Jogar (vai ao santuário), Ajustes (o submenu da pausa: Gráficos e Áudio), Créditos
## (a tela de Créditos da pausa) e Sair (pede confirmação). Mouse, teclado e controle: os botões são do Godot e o foco segue o cursor.
## ESC e Start abrem "Sair?" com "Não" marcado, como no santuário: nunca fecham o jogo de surpresa.
## A música é a do santuário (a mesma faixa "menu"): o Som não reinicia a faixa quando o santuário começa.

const Paleta := preload("res://v2/paleta.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const UiJanela := preload("res://v2/ui_janela.gd")
const Altar := preload("res://v2/altar.gd")
const Entrada := preload("res://v2/entrada.gd")  # garante as ações de controle da v2 (o A confirma e o B volta nos menus)
const Pausa := preload("res://v2/pausa.tscn")
const Trilha := preload("res://v2/trilha.gd")
const Atualizador := preload("res://v2/atualizador.gd")
const TituloVivo := preload("res://v2/titulo_vivo.gd")  # a arte de título com lua, névoa, brasas, espíritos, corvos e relâmpago
const SHADER_LOGO := preload("res://v2/titulo_logo.gdshader")
const ESCOLHA := "res://v2/personagens.tscn"  # JOGAR leva à escolha de personagem; dela, ao salão (v2/salao.tscn)
const LARG := 960
const ALT := 540
const COR_OURO := Paleta.OURO
const COR_TEXTO := Paleta.TEXTO
const COR_APAGADO := Paleta.TEXTO_APAGADO
const COR_FOCO := Paleta.FOCO  # texto do botão com foco ou sob o mouse (o fundo do botão é escuro)
const TAM_LOGO := 2 * Paleta.TITULO_GRANDE  # 2 x 56: múltiplo da grade da Jersey 10 (ver v2/LEIA-ME.md)
const TAM_BOTAO := Paleta.TITULO_MEDIO
const TAM_DICA := Paleta.TEXTO_TAMANHO  # grade da Spleen 8x16
const LOGO_Y := 44.0
const BOTAO_LARG := 260.0
const BOTAO_ALT := 44.0
const BOTAO_Y0 := 300.0
const BOTAO_PASSO := 52.0
const ORNAMENTO_Y := 196.0  # a linha dourada entre o logo e os botões
const LOGO_ESCALA := 1.4  # o logo é desenhado na fonte do título (TAM_LOGO) e ampliado: marca de jogo, não só um texto
const INTRO_T := 1.4  # s da entrada: a tela sai do preto, o logo desce e os botões sobem um a um
const Glifos := preload("res://v2/glifos.gd")

var ao_jogar := Callable()  # gancho: os testes trocam a ida ao santuário; vazio = troca a cena
var pausa  # o menu de pausa (pausa.gd) no modo do título: Ajustes, Créditos e a confirmação de Sair
var _botoes: Array[Button] = []  # Jogar, Ajustes, Créditos e Sair, de cima para baixo
var _faixa: ColorRect  # a faixa escura de baixo
var _dica: Control
var _ultimo: Button  # o último botão com foco: é nele que o foco volta quando um submenu fecha
var _trilha  # a faixa do santuário (trilha.gd)
var atualizador := Atualizador.new()  # consulta a Release mais nova em segundo plano (#106); os testes ajustam antes do add_child
var aviso_versao: Button  # "Versão nova disponível": só existe depois que a consulta achou uma Release mais nova
var abrir_url := Callable()  # gancho: os testes trocam a abertura da página no navegador; vazio = OS.shell_open
var _url_versao := ""
var _logo: Label
var _seletor: Node2D  # os dois losangos dourados que marcam o botão com foco
var _seletor_alvo := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	if Altar.pede_v1_na_entrada():
		process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().change_scene_to_file.call_deferred(Altar.CENA_V1)  # --v1 e os argumentos da v1 (ver v2/altar.gd)
		return
	Entrada.garantir()
	_ajustar_janela()
	_montar()
	pausa = Pausa.instantiate().iniciar(null)
	add_child(pausa)
	pausa.fechou.connect(_devolver_foco)
	_trilha = Trilha.new()
	add_child(_trilha)
	_trilha.tocar("santuario")
	_botoes[0].grab_focus()
	add_child(atualizador)
	atualizador.nova_versao.connect(_mostrar_aviso_versao)
	atualizador.verificar()  # sem carimbo (build dev) ou com a opção desligada, não faz nada


func _ajustar_janela() -> void:
	add_child(UiJanela.new().montar(self))  # fator da interface, canvas e bloco no centro (v2/ui_janela.gd, v2/escala_ui.gd); devolve a janela ao sair


# ------------------------------------------------------------------ montagem


func _montar() -> void:
	add_child(TituloVivo.new())  # cobre o canvas inteiro, não só o bloco 960x540
	_logo = _texto("K.I.K.I.U", TAM_LOGO, true, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, LOGO_Y, LARG, 130))
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_LOGO
	_logo.material = mat  # ouro em degradê com um brilho que corre pelas letras (v2/titulo_logo.gdshader)
	for i in [3, 2, 1]:  # relevo: três cópias mais escuras logo abaixo, do bronze ao quase preto
		var cor: Color = [Color(0.6, 0.26, 0.06), Color(0.34, 0.12, 0.04), Color(0.13, 0.04, 0.02)][i - 1]
		var sombra := _texto("K.I.K.I.U", TAM_LOGO, true, cor, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, i * 2.0, LARG, 130))
		sombra.show_behind_parent = true
		_logo.add_child(sombra)
	_logo.add_child(_faiscas())
	_logo.pivot_offset = Vector2(LARG / 2.0, 100.0)  # o meio das letras: o logo cresce sem sair do lugar
	_logo.scale = Vector2.ONE * LOGO_ESCALA
	add_child(_logo)
	var ornamento := Control.new()
	ornamento.position = Vector2(0, ORNAMENTO_Y)
	ornamento.size = Vector2(LARG, 12)
	ornamento.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornamento.draw.connect(_desenhar_ornamento.bind(ornamento))
	add_child(ornamento)
	var textos := ["JOGAR", "AJUSTES", "CRÉDITOS", "SAIR"]
	var acoes := [_jogar, _abrir_ajustes, _abrir_creditos, _sair]
	for i in textos.size():
		var b := Button.new()
		b.text = textos[i]
		b.position = Vector2((LARG - BOTAO_LARG) / 2.0, BOTAO_Y0 + i * BOTAO_PASSO)
		b.size = Vector2(BOTAO_LARG, BOTAO_ALT)
		_estilo_botao(b)
		b.pressed.connect(acoes[i])
		b.focus_entered.connect(_lembrar.bind(b))
		b.mouse_entered.connect(b.grab_focus)
		add_child(b)
		_botoes.append(b)
	_seletor = Node2D.new()
	_seletor.draw.connect(_desenhar_seletor)
	_seletor_alvo = _botoes[0].position + _botoes[0].size / 2.0
	_seletor.position = _seletor_alvo
	add_child(_seletor)
	_faixa = ColorRect.new()  # faixa escura atrás da dica: o chão da arte é claro ali embaixo
	_faixa.color = Color(Paleta.PAINEL, 0.6)
	_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_faixa)
	_dica = Glifos.dica(_itens_dica, HORIZONTAL_ALIGNMENT_CENTER, COR_APAGADO)
	_dica.position = Vector2(0, ALT - 30)  # rodapé: caixa de 22 px a 8 px da borda (DESIGN.md §1b)
	_dica.size = Vector2(LARG, 22)
	add_child(_dica)
	add_to_group("ui_escala")
	ui_reencaixar(EscalaUi.canvas_atual, EscalaUi.desloc_atual)
	_entrada()


## Entrada da tela: sai do preto, o logo desce e acende, e os botões sobem um a um. Só aparência: o foco e os cliques valem desde já.
func _entrada() -> void:
	var preto := ColorRect.new()
	preto.color = Color.BLACK
	preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	EscalaUi.cobrir(preto)
	add_child(preto)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(preto, "modulate:a", 0.0, INTRO_T).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(preto.queue_free)
	_logo.modulate.a = 0.0
	_logo.position.y = LOGO_Y - 12.0
	var tl := create_tween().set_parallel(true)
	tl.tween_property(_logo, "modulate:a", 1.0, 0.9).set_delay(0.35)
	tl.tween_property(_logo, "position:y", LOGO_Y, 1.0).set_delay(0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in _botoes.size():
		var b := _botoes[i]
		var y := b.position.y
		b.modulate.a = 0.0
		b.position.y = y + 14.0
		var tb := create_tween().set_parallel(true)
		tb.tween_property(b, "modulate:a", 1.0, 0.45).set_delay(0.8 + 0.09 * i)
		tb.tween_property(b, "position:y", y, 0.5).set_delay(0.8 + 0.09 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(dt: float) -> void:
	_t += dt
	if _seletor != null:
		var foco := get_viewport().gui_get_focus_owner() as Button
		if foco != null and _botoes.has(foco):
			_seletor_alvo = foco.position + foco.size / 2.0
		_seletor.position = _seletor.position.lerp(_seletor_alvo, clampf(dt * 14.0, 0.0, 1.0))
		_seletor.queue_redraw()


## Faíscas douradas subindo das letras do logo (aditivas, poucas).
func _faiscas() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	p.amount = 14
	p.lifetime = 2.6
	p.preprocess = 2.6
	p.position = Vector2(LARG / 2.0, 98)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(120, 22)
	p.direction = Vector2(0, -1)
	p.spread = 30.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector2(0, -4)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 0.95, 0.7, 0), Color(1, 0.9, 0.55, 1), Color(1, 0.6, 0.2, 0.7), Color(1, 0.4, 0.1, 0)])
	p.color_ramp = g
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	p.show_behind_parent = true
	return p


## Linha dourada com um losango no meio e outros dois nas pontas, entre o logo e os botões.
func _desenhar_ornamento(c: Control) -> void:
	var meio := LARG / 2.0
	var y := 6.0
	for lado in [-1.0, 1.0]:
		for i in 18:
			var x0: float = meio + lado * (14.0 + i * 10.0)
			var cor := Color(COR_OURO, 0.85 * (1.0 - i / 18.0))
			c.draw_line(Vector2(x0, y), Vector2(x0 + lado * 10.0, y), cor, 1.0)
		_losango(c, Vector2(meio + lado * 200.0, y), 2.0, Color(COR_OURO, 0.4))
	_losango(c, Vector2(meio, y), 5.0, COR_OURO)
	_losango(c, Vector2(meio, y), 2.0, Color(0.15, 0.08, 0.02))


func _losango(c: CanvasItem, p: Vector2, r: float, cor: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), cor)


## Os dois losangos dourados dos lados do botão com foco, balançando para dentro e para fora.
func _desenhar_seletor() -> void:
	var meia := BOTAO_LARG / 2.0 + 18.0 + 2.0 * sin(_t * 5.0)
	var brilho := Color(COR_OURO, 0.35)
	for lado in [-1.0, 1.0]:
		var p := Vector2(lado * meia, 0.0)
		_losango(_seletor, p, 8.0, brilho)
		_losango(_seletor, p, 5.0, COR_OURO)
		_losango(_seletor, p, 2.0, COR_FOCO)
		_seletor.draw_line(p + Vector2(lado * 8.0, 0), p + Vector2(lado * 20.0, 0), Color(COR_OURO, 0.5), 1.0)


## A dica de rodapé: só os botões do dispositivo em uso (teclado e mouse, ou o controle que foi tocado por último).
func _itens_dica() -> Array:
	var r: Array = [["navegar", "Escolher"], ["confirmar", "Confirmar"], ["pausa", "Sair"]]
	if not Glifos.eh_controle():
		r.insert(2, ["mouse", "também"])
	return r


## A faixa e a dica ficam na borda de baixo do canvas (não do bloco 960x540), de ponta a ponta. Chamado também quando a janela ou a opção mudam.
func ui_reencaixar(canvas: Vector2, desloc: Vector2) -> void:
	if _faixa == null:
		return
	_faixa.position = Vector2(-desloc.x, ALT + desloc.y - 46.0)
	_faixa.size = Vector2(canvas.x, 46.0)
	_dica.position = Vector2(0.0, ALT + desloc.y - 30.0)


func _texto(txt: String, tam: int, titulo: bool, cor: Color, alin: HorizontalAlignment, r: Rect2) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = alin
	l.add_theme_font_override("font", Dados.fonte_titulo if titulo else Dados.fonte_texto)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(Paleta.PRETO, 0.9))
	l.add_theme_constant_override("outline_size", 4 if titulo else 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Caixa do botão: painel escuro translúcido com borda dourada fina; com foco, a borda engrossa e brilha (sombra dourada).
func _caixa(fundo: Color, borda: Color, espessura: int, brilho: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(espessura)
	s.shadow_color = Color(COR_OURO, brilho)
	s.shadow_size = 8 if brilho > 0.0 else 0
	s.anti_aliasing = false
	s.set_content_margin_all(4)
	return s


func _estilo_botao(b: Button) -> void:
	b.add_theme_font_override("font", Dados.fonte_titulo)
	b.add_theme_font_size_override("font_size", TAM_BOTAO)
	var foco := _caixa(Color(0.11, 0.08, 0.03, 0.88), COR_OURO, 2, 0.28)
	b.add_theme_stylebox_override("normal", _caixa(Color(0.02, 0.025, 0.05, 0.74), Color(0.78, 0.62, 0.36, 0.5), 1, 0.0))
	b.add_theme_stylebox_override("hover", foco)
	b.add_theme_stylebox_override("focus", foco)
	b.add_theme_stylebox_override("pressed", _caixa(Color(0.05, 0.04, 0.02, 0.92), Color(0.85, 0.62, 0.3), 2, 0.0))
	b.add_theme_color_override("font_color", COR_TEXTO)
	b.add_theme_color_override("font_hover_color", COR_FOCO)
	b.add_theme_color_override("font_focus_color", COR_FOCO)
	b.add_theme_color_override("font_pressed_color", COR_TEXTO)


# ------------------------------------------------------------------ ações


func _lembrar(b: Button) -> void:
	_ultimo = b


func _devolver_foco() -> void:
	if is_instance_valid(_ultimo):
		_ultimo.grab_focus()


func _jogar() -> void:
	if ao_jogar.is_valid():
		ao_jogar.call()
	else:
		get_tree().change_scene_to_file(ESCOLHA)


func _abrir_ajustes() -> void:
	pausa.abrir_ajustes()


func _abrir_creditos() -> void:
	pausa.abrir_creditos()


func _sair() -> void:
	pausa.abrir_sair()  # "Sair do jogo?" com "Não" marcado; o "Sim" chama o gancho ao_sair da pausa (quit por padrão)


## Aviso discreto no canto: só aparece se a Release mais nova for posterior à build (atualizador.gd). Abre a página; não baixa nada.
func _mostrar_aviso_versao(tag: String, url: String) -> void:
	_url_versao = url
	if aviso_versao == null:
		aviso_versao = Button.new()
		aviso_versao.size = Vector2(250, 30)
		aviso_versao.position = Vector2(LARG - 262, 12)
		_estilo_botao(aviso_versao)
		aviso_versao.add_theme_font_size_override("font_size", TAM_DICA)
		aviso_versao.pressed.connect(_abrir_pagina_versao)
		add_child(aviso_versao)
	aviso_versao.text = "Versão nova disponível"
	aviso_versao.tooltip_text = tag


func _abrir_pagina_versao() -> void:
	if abrir_url.is_valid():
		abrir_url.call(_url_versao)
	else:
		OS.shell_open(_url_versao)
