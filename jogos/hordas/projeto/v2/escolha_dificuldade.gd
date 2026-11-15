extends Control
## Escolha antes de entrar no mapa. O salão monta este Control e usa visible para interromper a caminhada.
## Abrir só lê a última escolha; confirmar salva antes de emitir confirmou. Cancelar não altera o save.
## Tela enxuta (pedido do Alisson, 15/11): cada cartão tem só o nome, duas linhas curtas (`desc` do v2_dificuldade.json), o bônus
## e o recorde quando existe. O cartão escolhido é o de borda colorida e fundo claro; não há selo, número nem caixa de explicação.

signal confirmou(id: String)
signal cancelou

const Paleta := preload("res://v2/paleta.gd")
const EstiloPremium := preload("res://v2/estilo_premium.gd")
const Glifos := preload("res://v2/glifos.gd")
const Entrada := preload("res://v2/entrada.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const Meta := preload("res://v2/meta.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const Herois := preload("res://v2/herois.gd")
const BLOCO := Vector2(960, 540)
const CORES := [Paleta.BONUS, Paleta.OURO, Paleta.PERIGO]
const CARTAO_Y := 166.0
const CARTAO_ALT := 204.0

var selecionado := 0
var _montado := false
var _confirmando := false
var _opcoes: Array = []
var _cartoes: Array[Button] = []
var _recordes: Array[Label] = []  # o recorde do herói escolhido neste mapa, em cada dificuldade (Meta.recorde_hmd)
var _mapa: Label
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


## `id_mapa` (opcional) mostra em cada cartão o recorde do herói escolhido naquele mapa e dificuldade.
func abrir(nome_mapa: String, id_mapa := "") -> void:
	_montar()
	_mapa.text = "PORTAL · %s" % nome_mapa.to_upper()
	for i in _opcoes.size():
		var rec := Meta.recorde_hmd(Herois.escolhido(), id_mapa, str(_opcoes[i].id)) if id_mapa != "" else {}
		_recordes[i].text = texto_recorde(rec) if bool(rec.get("tem", false)) else ""  # sem recorde, a linha fica vazia
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
	_mapa = _texto(conteudo, "", Rect2(48, 44, 864, 24), 16, Paleta.CABECALHO)
	_mapa.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_texto(conteudo, "ESCOLHA A DIFICULDADE", Rect2(48, 68, 864, 44), 37, Paleta.OURO, true)
	var ornamento := EstiloPremium.ornamento(864)
	ornamento.position = Vector2(48, 122)
	conteudo.add_child(ornamento)
	for i in _opcoes.size():
		_montar_cartao(conteudo, i)
	_erro = _texto(conteudo, "", Rect2(48, 400, 864, 22), 16, Paleta.PERIGO)
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
	cartao.position = Vector2(48 + i * 294, CARTAO_Y)
	cartao.size = Vector2(276, CARTAO_ALT)
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
	_texto(cartao, str(d.nome).to_upper(), Rect2(18, 22, 240, 44), 37, cor, true)
	_texto(cartao, str(d.desc), Rect2(18, 78, 240, 40), 16, Paleta.TEXTO_SECUNDARIO, false, false, true)
	var bonus_almas := roundi((float(d.almas_mult) - 1.0) * 100.0)
	var bonus_xp := roundi((float(d.xp_mult) - 1.0) * 100.0)
	if bonus_almas == 0 and bonus_xp == 0:  # o Fácil: dois "+0%" seriam só ruído
		_texto(cartao, "Sem bônus", Rect2(18, 136, 240, 24), 16, Paleta.TEXTO_APAGADO)
	else:
		_texto(cartao, "ALMAS +%d%%" % bonus_almas, Rect2(18, 136, 124, 24), 16, cor)
		_texto(cartao, "XP +%d%%" % bonus_xp, Rect2(150, 136, 108, 24), 16, Paleta.TEXTO)
	var rec := _texto(cartao, "", Rect2(18, 166, 240, 22), 16, Paleta.TEXTO_SECUNDARIO)
	rec.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_recordes.append(rec)


## "RECORDE 12:34 · 850 ABATES", "RECORDE 15:00 · VENCEU" ou "SEM RECORDE" (o melhor do herói no mapa e na dificuldade).
static func texto_recorde(r: Dictionary) -> String:
	if not bool(r.get("tem", false)):
		return "SEM RECORDE"
	var seg := int(float(r.tempo))
	var fim := "VENCEU" if bool(r.venceu) else "%d ABATES" % int(r.abates)
	return "RECORDE %02d:%02d · %s" % [floori(seg / 60.0), seg % 60, fim]


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
		# hover mais fraco que o escolhido (fundo de cartão e borda de 1 px): sem o selo ESCOLHIDA, é o fundo claro que diz qual vale
		_cartoes[i].add_theme_stylebox_override("hover", _caixa(Paleta.CARTAO_SELECIONADO, cor, 2) if ativo else _caixa(Paleta.CARTAO, cor, 1))
		_cartoes[i].add_theme_stylebox_override("pressed", _caixa(Paleta.PAINEL, cor, 2))


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
