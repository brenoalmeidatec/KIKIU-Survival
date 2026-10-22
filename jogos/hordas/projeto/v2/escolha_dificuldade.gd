extends Control
## Escolha antes de entrar no mapa. O salão monta este Control e usa visible para interromper a caminhada.
## Abrir só lê a última escolha; confirmar salva antes de emitir confirmou. Cancelar não altera o save.

signal confirmou(id: String)
signal cancelou

const Paleta := preload("res://v2/paleta.gd")
const EstiloPremium := preload("res://v2/estilo_premium.gd")
const Glifos := preload("res://v2/glifos.gd")
const Entrada := preload("res://v2/entrada.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const Meta := preload("res://v2/meta.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const BLOCO := Vector2(960, 540)
const CORES := [Paleta.BONUS, Paleta.OURO, Paleta.PERIGO]

var selecionado := 0
var _montado := false
var _confirmando := false
var _opcoes: Array = []
var _cartoes: Array[Button] = []
var _marcas: Array[Label] = []
var _mapa: Label
var _aviso: Label
var _aviso_caixa: Panel
var _erro: Label
var _entrar: Button
var _voltar: Button
var _painel: Panel


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_montar()


func abrir(nome_mapa: String) -> void:
	_montar()
	_mapa.text = "PORTAL · %s" % nome_mapa.to_upper()
	selecionado = 0
	for i in _opcoes.size():
		if str(_opcoes[i].id) == Meta.dificuldade():
			selecionado = i
	_erro.text = ""
	_confirmando = false
	_atualizar()
	show()


func _montar() -> void:
	if _montado:
		return
	_montado = true
	Entrada.garantir()
	_opcoes = Dificuldade.opcoes()
	var fundo := ColorRect.new()
	fundo.color = Paleta.alfa(Paleta.PAINEL, 0.97)
	EscalaUi.cobrir(fundo)
	add_child(fundo)
	_painel = Panel.new()
	_painel.set_anchors_preset(Control.PRESET_CENTER)
	_painel.position = -BLOCO * 0.5 + Vector2(24, 24)
	_painel.size = BLOCO - Vector2(48, 48)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_theme_stylebox_override("panel", EstiloPremium.painel())
	add_child(_painel)
	var conteudo := Control.new()
	conteudo.set_anchors_preset(Control.PRESET_CENTER)
	conteudo.position = -BLOCO * 0.5
	conteudo.size = BLOCO
	conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(conteudo)
	_mapa = _texto(conteudo, "", Rect2(48, 37, 864, 24), 16, Paleta.CABECALHO)
	_mapa.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_texto(conteudo, "ESCOLHA A DIFICULDADE", Rect2(48, 61, 864, 44), 37, Paleta.OURO, true)
	_texto(conteudo, "Escolha o ritmo da horda e a recompensa.", Rect2(48, 112, 864, 24), 16, Paleta.TEXTO_SECUNDARIO)
	var ornamento := EstiloPremium.ornamento(864)
	ornamento.position = Vector2(48, 135)
	conteudo.add_child(ornamento)
	for i in _opcoes.size():
		_montar_cartao(conteudo, i)
	_aviso_caixa = Panel.new()
	_aviso_caixa.position = Vector2(48, 356)
	_aviso_caixa.size = Vector2(864, 50)
	_aviso_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo.add_child(_aviso_caixa)
	_aviso = _texto(_aviso_caixa, "", Rect2(16, 5, 832, 40), 16, Paleta.TEXTO)
	_aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto(conteudo, "Pesadelo é um modificador independente desta escolha.", Rect2(48, 414, 864, 22), 16, Paleta.ALMA)
	_erro = _texto(conteudo, "", Rect2(48, 438, 864, 22), 16, Paleta.PERIGO)
	_voltar = _botao(conteudo, "VOLTAR", Rect2(48, 466, 168, 38), "voltar")
	_voltar.pressed.connect(_cancelar)
	_entrar = _botao(conteudo, "ENTRAR", Rect2(636, 466, 276, 38), "confirmar")
	_entrar.pressed.connect(_confirmar)
	var dica := Glifos.dica(func() -> Array: return [["navegar", "Escolher"]], HORIZONTAL_ALIGNMENT_CENTER, Paleta.TEXTO_SECUNDARIO)
	dica.position = Vector2(240, 475)
	dica.size = Vector2(372, 22)
	conteudo.add_child(dica)


func _montar_cartao(pai: Control, i: int) -> void:
	var d: Dictionary = _opcoes[i]
	var cartao := Button.new()
	cartao.position = Vector2(48 + i * 294, 150)
	cartao.size = Vector2(276, 192)
	cartao.focus_mode = Control.FOCUS_NONE
	cartao.pressed.connect(_selecionar.bind(i))
	pai.add_child(cartao)
	_cartoes.append(cartao)
	var cor: Color = CORES[i % CORES.size()]
	var linha := ColorRect.new()
	linha.color = cor
	linha.position = Vector2(1, 1)
	linha.size = Vector2(274, 3)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(linha)
	_texto(cartao, "%02d" % (i + 1), Rect2(18, 16, 48, 16), 8, Paleta.CABECALHO, false, true)
	var marca := _texto(cartao, "", Rect2(118, 14, 140, 22), 16, Paleta.OURO)
	marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_marcas.append(marca)
	_texto(cartao, str(d.nome).to_upper(), Rect2(18, 38, 240, 44), 37, cor, true)
	_texto(cartao, str(d.desc), Rect2(18, 86, 240, 44), 16, Paleta.TEXTO_SECUNDARIO, false, false, true)
	var bonus := roundi((float(d.almas_mult) - 1.0) * 100.0)
	_texto(cartao, "+%d%%" % bonus, Rect2(18, 148, 110, 24), 16, cor, false, true)
	_texto(cartao, "ALMAS E XP", Rect2(142, 148, 116, 24), 16, Paleta.TEXTO)


func _texto(pai: Control, txt: String, r: Rect2, tam: int, cor: Color, titulo := false, numero := false, quebra := false) -> Label:
	var l := Label.new()
	if quebra:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = txt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Dados.fonte if numero else (Dados.fonte_titulo if titulo else Dados.fonte_texto))
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Paleta.PRETO)
	l.add_theme_constant_override("outline_size", 2 if titulo else 0)
	l.position = r.position
	l.size = r.size  # aplica depois da fonte/quebra: o mínimo da fonte anterior não expande o retângulo
	pai.add_child(l)
	return l


func _caixa(fundo: Color, borda: Color, largura: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura)
	s.anti_aliasing = false
	return s


func _botao(pai: Control, txt: String, r: Rect2, acao: String) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Dados.fonte_titulo)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Paleta.FOCO)
	EstiloPremium.estilo_botao(b, 10.0)
	var glifo := Glifos.glifo(acao, HORIZONTAL_ALIGNMENT_RIGHT)
	glifo.position = Vector2(0, 11)
	glifo.size = Vector2(r.size.x - 12, 16)
	b.add_child(glifo)
	pai.add_child(b)
	return b


func _atualizar() -> void:
	for i in _cartoes.size():
		var cor: Color = CORES[i % CORES.size()]
		var ativo := i == selecionado
		_cartoes[i].add_theme_stylebox_override(
			"normal", _caixa(Paleta.CARTAO_SELECIONADO if ativo else Paleta.PAINEL, cor if ativo else Paleta.BORDA, 2 if ativo else 1)
		)
		_cartoes[i].add_theme_stylebox_override("hover", _caixa(Paleta.CARTAO_SELECIONADO, cor, 2))
		_cartoes[i].add_theme_stylebox_override("pressed", _caixa(Paleta.PAINEL, cor, 2))
		_marcas[i].text = "ESCOLHIDA" if ativo else ""
	var d: Dictionary = _opcoes[selecionado]
	var cor: Color = CORES[selecionado % CORES.size()]
	_aviso_caixa.add_theme_stylebox_override("panel", _caixa(Paleta.PAINEL, Paleta.alfa(cor, 0.55), 1))
	if float(d.golpe_custo) <= 0.0:
		_aviso.text = "Ataque principal livre de fôlego.\nSem espera para voltar a atacar."
	else:
		var segundos := String.num(float(d.golpe_calor), 1).trim_suffix(".0").replace(".", ",")
		_aviso.text = "O ataque principal gasta fôlego.\nAo zerar, precisa esfriar por %s s antes de atacar outra vez." % segundos


func _selecionar(i: int) -> void:
	selecionado = posmod(i, _opcoes.size())
	_erro.text = ""
	_atualizar()


func _confirmar() -> void:
	if not visible or _confirmando:
		return
	_confirmando = true
	var id := str(_opcoes[selecionado].id)
	if not Meta.escolher_dificuldade(id):
		_erro.text = "Não foi possível salvar a dificuldade. Tente novamente."
		_confirmando = false
		return
	hide()
	_confirmando = false
	confirmou.emit(id)


func _cancelar() -> void:
	if not visible:
		return
	hide()
	cancelou.emit()


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("ui_cancel"):
		_cancelar()
	elif e.is_action_pressed("ui_left") or e.is_action_pressed("ui_up"):
		_selecionar(selecionado - 1)
	elif e.is_action_pressed("ui_right") or e.is_action_pressed("ui_down"):
		_selecionar(selecionado + 1)
	elif e.is_action_pressed("ui_accept"):
		_confirmar()
	else:
		return
	get_viewport().set_input_as_handled()
