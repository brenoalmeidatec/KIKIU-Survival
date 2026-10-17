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
const FUNDO := preload("res://assets/titulo/fundo.png")
const MOLDURA := preload("res://v2/hud/moldura_pedra.png")
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
const DICA := "Setas ou analógico escolhem   Enter ou A confirma   Mouse também   Esc pergunta se quer sair"

var ao_jogar := Callable()  # gancho: os testes trocam a ida ao santuário; vazio = troca a cena
var pausa  # o menu de pausa (pausa.gd) no modo do título: Ajustes, Créditos e a confirmação de Sair
var _botoes: Array[Button] = []  # Jogar, Ajustes, Créditos e Sair, de cima para baixo
var _faixa: ColorRect  # a faixa escura de baixo
var _dica: Label
var _ultimo: Button  # o último botão com foco: é nele que o foco volta quando um submenu fecha
var _trilha  # a faixa do santuário (trilha.gd)
var atualizador := Atualizador.new()  # consulta a Release mais nova em segundo plano (#106); os testes ajustam antes do add_child
var aviso_versao: Button  # "Versão nova disponível": só existe depois que a consulta achou uma Release mais nova
var abrir_url := Callable()  # gancho: os testes trocam a abertura da página no navegador; vazio = OS.shell_open
var _url_versao := ""


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
	var fundo := TextureRect.new()
	fundo.texture = FUNDO
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	EscalaUi.cobrir(fundo)  # a arte cobre o canvas inteiro, não só o bloco 960x540
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
	_faixa = ColorRect.new()  # faixa escura atrás da dica: o chão da arte é claro ali embaixo
	_faixa.color = Color(Paleta.PAINEL, 0.6)
	_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_faixa)
	_dica = _texto(DICA, TAM_DICA, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, ALT - 26, LARG, 20))
	add_child(_dica)
	add_to_group("ui_escala")
	ui_reencaixar(EscalaUi.canvas_atual, EscalaUi.desloc_atual)


## A faixa e a dica ficam na borda de baixo do canvas (não do bloco 960x540), de ponta a ponta. Chamado também quando a janela ou a opção mudam.
func ui_reencaixar(canvas: Vector2, desloc: Vector2) -> void:
	if _faixa == null:
		return
	_faixa.position = Vector2(-desloc.x, ALT + desloc.y - 46.0)
	_faixa.size = Vector2(canvas.x, 46.0)
	_dica.position = Vector2(0.0, ALT + desloc.y - 26.0)


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
