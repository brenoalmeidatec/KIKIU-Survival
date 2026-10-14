extends Control
## Tela de título da v2 (a cena principal): logo K.I.K.I.U sobre a arte de título (assets/titulo/fundo.png, feito por
## fonte_arte/gerar_fundo_titulo.py) e as opções Jogar (vai ao santuário), Ajustes (o submenu da pausa: Gráficos e Áudio), Créditos
## (a tela de Créditos da pausa) e Sair (pede confirmação). Mouse, teclado e controle: os botões são do Godot e o foco segue o cursor.
## ESC e Start abrem "Sair?" com "Não" marcado, como no santuário: nunca fecham o jogo de surpresa.
## A música é a do santuário (a mesma faixa "menu"): o Som não reinicia a faixa quando o santuário começa.

const Paleta := preload("res://v2/paleta.gd")
const Altar := preload("res://v2/altar.gd")
const Entrada := preload("res://v2/entrada.gd")  # garante as ações de controle da v2 (o A confirma e o B volta nos menus)
const Pausa := preload("res://v2/pausa.tscn")
const Trilha := preload("res://v2/trilha.gd")
const FUNDO := preload("res://assets/titulo/fundo.png")
const MOLDURA := preload("res://v2/hud/moldura_pedra.png")
const SANTUARIO := "res://v2/altar.tscn"
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
const DICA := "Setas ou analógico escolhem   Enter ou A confirma   Mouse também   Esc pergunta se quer sair"

var ao_jogar := Callable()  # gancho: os testes trocam a ida ao santuário; vazio = troca a cena
var pausa  # o menu de pausa (pausa.gd) no modo do título: Ajustes, Créditos e a confirmação de Sair
var _botoes: Array[Button] = []  # Jogar, Ajustes, Créditos e Sair, de cima para baixo
var _ultimo: Button  # o último botão com foco: é nele que o foco volta quando um submenu fecha
var _antes := {}  # modo de escala da janela antes desta tela (volta ao sair)
var _trilha  # a faixa do santuário (trilha.gd)


func _ready() -> void:
	if Altar.pede_v1_na_entrada():
		process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().change_scene_to_file.call_deferred(Altar.CENA_V1)  # --v1 e os argumentos da v1 (ver v2/altar.gd)
		return
	Entrada.garantir()
	_ajustar_janela()
	set_anchors_preset(PRESET_FULL_RECT)
	_montar()
	pausa = Pausa.instantiate().iniciar(null)
	add_child(pausa)
	pausa.fechou.connect(_devolver_foco)
	_trilha = Trilha.new()
	add_child(_trilha)
	_trilha.tocar("santuario")
	_botoes[0].grab_focus()


func _exit_tree() -> void:
	var w := get_window()
	if w != null and _antes.has("modo"):
		w.content_scale_mode = _antes.modo
		w.content_scale_size = _antes.tam
		w.content_scale_aspect = _antes.aspecto
		w.content_scale_stretch = _antes.escala


func _ajustar_janela() -> void:
	var w := get_window()
	_antes = {"modo": w.content_scale_mode, "tam": w.content_scale_size, "aspecto": w.content_scale_aspect, "escala": w.content_scale_stretch}
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_size = Vector2i(LARG, ALT)
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


# ------------------------------------------------------------------ montagem


func _montar() -> void:
	var fundo := TextureRect.new()
	fundo.texture = FUNDO
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.set_anchors_preset(PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	add_child(_texto("K.I.K.I.U", TAM_LOGO, true, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, LOGO_Y, LARG, 130)))
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
	var faixa := ColorRect.new()  # faixa escura atrás da dica: o chão da arte é claro ali embaixo
	faixa.color = Color(Paleta.PAINEL, 0.6)
	faixa.position = Vector2(0, ALT - 46)
	faixa.size = Vector2(LARG, 46)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faixa)
	add_child(_texto(DICA, TAM_DICA, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, ALT - 26, LARG, 20)))


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


## Moldura 9-patch de pedra do HUD (20x20, margem de 5 px), tingida pela cor (a mesma do santuário).
func _moldura(cor: Color) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = MOLDURA
	s.texture_margin_left = 5
	s.texture_margin_top = 5
	s.texture_margin_right = 5
	s.texture_margin_bottom = 5
	s.set_content_margin_all(4)
	s.modulate_color = cor
	return s


func _estilo_botao(b: Button) -> void:
	b.add_theme_font_override("font", Dados.fonte_titulo)
	b.add_theme_font_size_override("font_size", TAM_BOTAO)
	b.add_theme_stylebox_override("normal", _moldura(Paleta.MOLDURA))
	b.add_theme_stylebox_override("hover", _moldura(COR_OURO))
	b.add_theme_stylebox_override("focus", _moldura(COR_OURO))
	b.add_theme_stylebox_override("pressed", _moldura(Paleta.MOLDURA_ESCURA))
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
		get_tree().change_scene_to_file(SANTUARIO)


func _abrir_ajustes() -> void:
	pausa.abrir_ajustes()


func _abrir_creditos() -> void:
	pausa.abrir_creditos()


func _sair() -> void:
	pausa.abrir_sair()  # "Sair do jogo?" com "Não" marcado; o "Sim" chama o gancho ao_sair da pausa (quit por padrão)
