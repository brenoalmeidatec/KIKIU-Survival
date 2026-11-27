extends Control
## Tela de título da v2 no estilo Códice: navegação à esquerda e a arte viva à direita.
## Os botões aceitam teclado, controle e mouse. Jogar abre a escolha de personagem, Ajustes e Créditos reaproveitam a pausa.
## ESC e Start abrem "Sair?" com "Não" marcado, como no santuário: nunca fecham o jogo de surpresa.
## A música é a do santuário (a mesma faixa "menu"): o Som não reinicia a faixa quando o santuário começa.

const Paleta := preload("res://v2/paleta.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const UiJanela := preload("res://v2/ui_janela.gd")
const Altar := preload("res://v2/altar.gd")
const Entrada := preload("res://v2/entrada.gd")  # garante as ações de controle da v2 (o A confirma e o B volta nos menus)
const CursorKikiu := preload("res://v2/cursor_kikiu.gd")  # seta em pixel art nos menus (a mira fica com a partida)
const Pausa := preload("res://v2/pausa.tscn")
const Trilha := preload("res://v2/trilha.gd")
const Atualizador := preload("res://v2/atualizador.gd")
const TituloCodice := preload("res://v2/titulo_codice.gd")
const SHADER_LOGO := preload("res://v2/titulo_logo.gdshader")
const SHADER_VEU := preload("res://v2/menu_principal_codice.gdshader")
const ESCOLHA := "res://v2/personagens.tscn"  # JOGAR leva à escolha de personagem; dela, ao salão (v2/salao.tscn)
const LARG := 960
const ALT := 540
const COR_OURO := Color("#ddc18b")
const COR_TEXTO := Color("#f0ecd9")
const COR_APAGADO := Color("#bebfac")
const MADEIRA := Color("#141d18")
const MADEIRA_FOCO := Color("#253328")
const FILETE := Color("#52584a")
const TAM_LOGO := 3 * Paleta.TITULO_GRANDE  # 3 x 56 = 168: múltiplo da grade da Jersey 10 (ver v2/LEIA-ME.md), desenhado direto no tamanho final, sem `scale`
const TAM_BOTAO := Paleta.TITULO_MEDIO
const TAM_DICA := Paleta.TEXTO_TAMANHO  # grade da Spleen 8x16
const ESQUERDA := 58.0
const LOGO_Y := 19.0
const BOTAO_LARG := 278.0
const BOTAO_ALT := 42.0
const BOTAO_Y0 := 248.0
const BOTAO_PASSO := 50.0
const ORNAMENTO_Y := 182.0
const SUBTITULO := "Knights In Kaos, Infinite Upgrades"
const SUBTITULO_Y := 151.0
const TAM_SUBTITULO := Paleta.TITULO_PEQUENO
const LOGO_ALTURA := 206.0
const INTRO_T := 1.4  # s da entrada: a tela sai do preto, o logo desce e os botões sobem um a um
const Glifos := preload("res://v2/glifos.gd")
const CodigoSecreto := preload("res://v2/codigo_secreto.gd")  # Konami ou IDKFA: liga o "tudo liberado" (Progressao)
const Progressao := preload("res://v2/progressao.gd")

var ao_jogar := Callable()  # gancho: os testes trocam a ida ao santuário; vazio = troca a cena
var pausa  # o menu de pausa (pausa.gd) no modo do título: Ajustes, Créditos e a confirmação de Sair
var _botoes: Array[Button] = []  # Jogar, Ajustes, Créditos e Sair, de cima para baixo
var _arte: Control
var _veu: ShaderMaterial
var _dica: Control
var _versao: Label
var _ultimo: Button  # o último botão com foco: é nele que o foco volta quando um submenu fecha
var _trilha  # a faixa do santuário (trilha.gd)
var atualizador := Atualizador.new()  # consulta a Release mais nova em segundo plano (#106); os testes ajustam antes do add_child
var aviso_versao: Button  # "Versão nova disponível": só existe depois que a consulta achou uma Release mais nova
var abrir_url := Callable()  # gancho: os testes trocam a abertura da página no navegador; vazio = OS.shell_open
var _url_versao := ""
var _logo: Label
var _subtitulo: Label
var codigo  # o código secreto (codigo_secreto.gd): o último filho, para ver a entrada antes dos botões
var _selo: Label  # BETA TESTER / CÓDIGO SECRETO, no canto: só existe com o modo ligado


func _ready() -> void:
	if Altar.pede_v1_na_entrada():
		process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().change_scene_to_file.call_deferred(Altar.CENA_V1)  # --v1 e os argumentos da v1 (ver v2/altar.gd)
		return
	Entrada.garantir()
	CursorKikiu.aplicar("seta")
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
	codigo = CodigoSecreto.new()
	codigo.bloqueado = func() -> bool: return pausa.aberto
	codigo.alternado.connect(func(_ligado: bool) -> void: _atualizar_selo())
	add_child(codigo)
	_atualizar_selo()


func _ajustar_janela() -> void:
	add_child(UiJanela.new().montar(self))  # fator da interface, canvas e bloco no centro (v2/ui_janela.gd, v2/escala_ui.gd); devolve a janela ao sair


# ------------------------------------------------------------------ montagem


func _montar() -> void:
	_arte = TituloCodice.new()
	add_child(_arte)
	var veu := ColorRect.new()
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veu = ShaderMaterial.new()
	_veu.shader = SHADER_VEU
	veu.material = _veu
	EscalaUi.cobrir(veu)
	add_child(veu)
	_logo = _texto("K.I.K.I.U", TAM_LOGO, true, Color(0.93, 0.86, 0.72), HORIZONTAL_ALIGNMENT_LEFT, Rect2(ESQUERDA, LOGO_Y, 420, LOGO_ALTURA))
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_LOGO
	mat.set_shader_parameter("topo", 35.0)
	mat.set_shader_parameter("altura", 185.0)
	mat.set_shader_parameter("largura_logo", 420.0)
	mat.set_shader_parameter("periodo", 11.0)
	_logo.material = mat
	var sombra := _texto("K.I.K.I.U", TAM_LOGO, true, Color("#4d331e"), HORIZONTAL_ALIGNMENT_LEFT, Rect2(0, 4, 420, LOGO_ALTURA))
	sombra.show_behind_parent = true
	_logo.add_child(sombra)
	_logo.add_child(_faiscas())
	add_child(_logo)
	var ornamento := Control.new()
	ornamento.position = Vector2(ESQUERDA, ORNAMENTO_Y)
	ornamento.size = Vector2(BOTAO_LARG, 12)
	ornamento.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornamento.draw.connect(_desenhar_ornamento.bind(ornamento))
	add_child(ornamento)
	_subtitulo = _texto(SUBTITULO, TAM_SUBTITULO, true, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(ESQUERDA, SUBTITULO_Y, 340, 29))
	add_child(_subtitulo)
	var textos := ["JOGAR", "AJUSTES", "CRÉDITOS", "SAIR"]
	var acoes := [_jogar, _abrir_ajustes, _abrir_creditos, _sair]
	for i in textos.size():
		var b := Button.new()
		b.text = textos[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.position = Vector2(ESQUERDA, BOTAO_Y0 + i * BOTAO_PASSO)
		b.size = Vector2(BOTAO_LARG, BOTAO_ALT)
		_estilo_botao(b)
		b.pressed.connect(acoes[i])
		b.focus_entered.connect(_lembrar.bind(b))
		b.mouse_entered.connect(b.grab_focus)
		add_child(b)
		_botoes.append(b)
	var numero := str(ProjectSettings.get_setting("application/config/version", ""))
	var versao := "v%s · RC1" % numero
	_versao = _texto(versao, TAM_DICA, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(ESQUERDA, ALT - 32, 220, 22))
	_versao.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_versao)
	_dica = Glifos.dica(_itens_dica, HORIZONTAL_ALIGNMENT_RIGHT, COR_APAGADO)
	_dica.size = Vector2(LARG - 2.0 * ESQUERDA - 220.0, 22.0)
	add_child(_dica)
	add_to_group("ui_escala")
	ui_reencaixar(EscalaUi.canvas_atual, EscalaUi.desloc_atual)
	if is_inside_tree():
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
	_subtitulo.modulate.a = 0.0
	tl.tween_property(_subtitulo, "modulate:a", 1.0, 0.7).set_delay(0.7)
	for i in _botoes.size():
		var b := _botoes[i]
		var y := b.position.y
		b.modulate.a = 0.0
		b.position.y = y + 14.0
		var tb := create_tween().set_parallel(true)
		tb.tween_property(b, "modulate:a", 1.0, 0.45).set_delay(0.8 + 0.09 * i)
		tb.tween_property(b, "position:y", y, 0.5).set_delay(0.8 + 0.09 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Faíscas douradas subindo das letras do logo (aditivas, poucas).
func _faiscas() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
	p.amount = 8
	p.lifetime = 2.6
	p.preprocess = 2.6
	p.position = Vector2(177, 111)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(170, 20)
	p.direction = Vector2(0, -1)
	p.spread = 30.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector2(0, -6)
	p.scale_amount_min = 1.0  # a faísca é um quadrado de 2 px, sempre do mesmo tamanho
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


## Filete da marca: o losango começa a linha, que se dissolve em direção à arte.
func _desenhar_ornamento(c: Control) -> void:
	var y := 6.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, y), Vector2(4, y - 4), Vector2(8, y), Vector2(4, y + 4)]), COR_OURO)
	for i in 26:
		var x := 13.0 + i * 10.0
		var cor := Color(COR_OURO, 0.75 * (1.0 - i / 26.0))
		c.draw_line(Vector2(x, y), Vector2(x + 10.0, y), cor, 1.0)


## A dica de rodapé: só os botões do dispositivo em uso (teclado e mouse, ou o controle que foi tocado por último).
func _itens_dica() -> Array:
	var r: Array = [["navegar", "Escolher"], ["confirmar", "Confirmar"], ["pausa", "Sair"]]
	if not Glifos.eh_controle():
		r.insert(2, ["mouse", "também"])
	return r


## Reposiciona o eixo do espelho e mantém o rodapé na parte de baixo do canvas.
func ui_reencaixar(canvas: Vector2, desloc: Vector2) -> void:
	if _dica == null:
		return
	_veu.set_shader_parameter("canvas_largura", canvas.x)
	_veu.set_shader_parameter("margem_esquerda", desloc.x)
	var y := ALT + desloc.y - 32.0
	_versao.position.y = y
	_dica.position = Vector2(LARG - ESQUERDA - _dica.size.x, y)


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


func _caixa(fundo: Color, borda: Color, espessura: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.border_width_left = espessura
	s.anti_aliasing = false
	s.set_content_margin_all(4)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	return s


func _estilo_botao(b: Button) -> void:
	b.add_theme_font_override("font", Dados.fonte_titulo)
	b.add_theme_font_size_override("font_size", TAM_BOTAO)
	var foco := _caixa(MADEIRA_FOCO, COR_OURO, 3)
	b.add_theme_stylebox_override("normal", _caixa(MADEIRA, FILETE, 2))
	b.add_theme_stylebox_override("hover", foco)
	b.add_theme_stylebox_override("focus", foco)
	b.add_theme_stylebox_override("pressed", foco)
	b.add_theme_color_override("font_color", COR_TEXTO)
	b.add_theme_color_override("font_hover_color", COR_OURO)
	b.add_theme_color_override("font_focus_color", COR_OURO)
	b.add_theme_color_override("font_pressed_color", COR_OURO)


# ------------------------------------------------------------------ ações


func _lembrar(b: Button) -> void:
	_ultimo = b


## O selo do modo "tudo liberado" no canto de cima à esquerda: aparece e some com o modo.
func _atualizar_selo() -> void:
	var texto := Progressao.selo()
	if texto == "":
		if _selo != null:
			_selo.queue_free()
			_selo = null
		return
	if _selo == null:
		_selo = _texto(texto, TAM_DICA, false, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(ESQUERDA, 16, 300, 20))
		add_child(_selo)
	_selo.text = texto


func _devolver_foco() -> void:
	if is_instance_valid(_ultimo):
		_ultimo.grab_focus()


func _jogar() -> void:
	if ao_jogar.is_valid():
		ao_jogar.call()
	else:
		Transicoes.ir_para(self, ESCOLHA)


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
		aviso_versao.add_theme_font_size_override("font_size", TAM_SUBTITULO)
		aviso_versao.pressed.connect(_abrir_pagina_versao)
		add_child(aviso_versao)
	aviso_versao.text = "Versão nova disponível"
	aviso_versao.tooltip_text = tag


func _abrir_pagina_versao() -> void:
	if abrir_url.is_valid():
		abrir_url.call(_url_versao)
	else:
		OS.shell_open(_url_versao)
