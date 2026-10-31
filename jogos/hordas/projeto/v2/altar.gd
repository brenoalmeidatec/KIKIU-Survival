extends Control
## Santuário da v2: a tela de preparação entre o título e a partida. Com `--v1` (ou um argumento só da v1,
## veja ARGS_V1) abre o menu da v1 (main.tscn), que resolve o resto (--cena, --prototipo, --bot...). Compra melhorias permanentes com as almas (v2/meta.gd),
## mostra as conquistas com cadeado, o resumo da última partida e ENTRAR NA FLORESTA (v2/mundo.tscn). Desenhado em 960x540 com a
## janela em CANVAS_ITEMS, sem SubViewport: botões, foco e controle funcionam direto. Cada compra relê o save (Meta.estado()).
## Visual: cartões em grade, níveis em marcadores e detalhe compartilhado por foco/mouse. Conquistas mostram a última partida,
## sem fingir progresso acumulado. ESC e VOLTAR retornam ao título; Ajustes fecha devolvendo foco ao botão.

const Paleta := preload("res://v2/paleta.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const UiJanela := preload("res://v2/ui_janela.gd")
const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const Trilha := preload("res://v2/trilha.gd")
const MOLDURA := preload("res://v2/hud/moldura_pedra.png")
const FUNDO := preload("res://assets/titulo/fundo.png")
const FLORESTA := "res://v2/mundo.tscn"
const CENA_V1 := "res://main.tscn"
## Argumentos que levam à v1 (main.gd os trata): --v1, os de troca de cena e os de teste da v1 (README de jogos/hordas, testes/online_*.sh).
const ARGS_V1 := ["v1", "cena", "prototipo", "bot", "online", "sair", "print_tela"]
const LARG := 960
const ALT := 540
const LINHA_DETALHE := 17  # altura de cada linha do detalhe: fonte de 16 px (Spleen 8x16, medida em janela) + 1 px de entrelinha
const COR_OURO := Paleta.OURO
const COR_TEXTO := Paleta.TEXTO
const COR_APAGADO := Paleta.TEXTO_APAGADO
const COR_EFEITO := Paleta.TEXTO_SECUNDARIO
const COR_FOCO := Paleta.FOCO  # texto do botão com foco ou sob o mouse (o fundo do botão é escuro)
const COR_ALMA := Paleta.ALMA
const Glifos := preload("res://v2/glifos.gd")
const TEMPO_AVISO := 3.0
const X_CONQ := 632  # coluna CONQUISTAS: x 632 a 924 (a borda direita é a da caixa ALMAS e a do VOLTAR)
const LARG_CONQ := 292
const PASSO_CONQ := 108  # altura do item (100) mais 8 de vão

var _saldo: Label
var _ultima: Label
var _status: Label
var _status_t := 0.0
var _linhas := {}  # id da melhoria -> {nome, efeito, botao, cadeado}
var _conq := {}  # id da conquista -> {cadeado, nome, desc, rec}
var _rolagem: ScrollContainer  # a lista de conquistas, limitada a y 106-446
var _entrar: Button
var _mapa: Button  # escolhe o mapa da próxima partida (Mapas.LISTA); o texto de ENTRAR acompanha
var _mapa_id := Mapas.PADRAO
var _ajustes: Button
var _voltar: Button
var _detalhe: Label
var _modo_btn: Button  # liga e desliga o modo Pesadelo (só aparece com a conquista cumprida)
var _rastro_btn: Button  # liga e desliga o Rastro de katana (idem)
var _selecionada := "vida"
var pausa
var trilha  # música de fundo do santuário (trilha.gd)


class Cadeado:
	extends Control
	## Cadeado de pixel (fechado e cinza, ou aberto e dourado): desenhado com retângulos, sem textura.
	var aberto := false

	func _init() -> void:
		custom_minimum_size = Vector2(14, 16)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cor := Paleta.OURO if aberto else Paleta.TEXTO_APAGADO
		draw_rect(Rect2(3, 1, 8, 8), cor, false, 2.0)
		draw_rect(Rect2(1, 7, 12, 9), cor)
		draw_rect(Rect2(6, 10, 2, 3), Paleta.CARTAO)


func _ready() -> void:
	if _abrir_v1():
		return
	_ajustar_janela()
	Glifos.instalar()  # escuta o último dispositivo (a dica do rodapé troca entre teclado, Xbox e PlayStation)
	_montar()
	pausa = preload("res://v2/pausa.tscn").instantiate().iniciar(null)
	pausa.sair_no_frontend = false
	add_child(pausa)
	_ajustes.pressed.connect(pausa.abrir_ajustes)
	pausa.fechou.connect(func(): _ajustes.grab_focus())
	pausa.apagou_tudo.connect(func(): Transicoes.ir_para(self, "res://v2/personagens.tscn", true))  # sem save não há santuário
	trilha = Trilha.new()
	add_child(trilha)
	trilha.tocar("santuario")
	_atualizar()
	_atualizar_mapa()
	_entrar.grab_focus()


## Lê os argumentos (antes e depois do "--") como main.gd: "--chave=valor" ou "--chave".
static func ler_args(lista: PackedStringArray) -> Dictionary:
	var args := {}
	for a in lista:
		if a.begins_with("--"):
			var p: PackedStringArray = a.substr(2).split("=", true, 1)
			args[p[0]] = p[1] if p.size() > 1 else true
	return args


## Se os argumentos pedem a v1. Só vale na primeira vez que o santuário abre no processo: a v1 pode mandar de volta pra cá
## (--v2, --cena=res://v2/altar.tscn) e isso não pode virar laço.
static func pede_v1(args: Dictionary, primeira_vez: bool) -> bool:
	if not primeira_vez:
		return false
	for k in ARGS_V1:
		if args.has(k):
			return true
	return false


## Primeira tela do processo (o título, ou o santuário aberto direto): se os argumentos forem da v1, manda para ela. Marca a
## entrada, para as telas seguintes (o santuário, depois do título) saberem que já não são a primeira.
static func pede_v1_na_entrada() -> bool:
	var primeira := not Engine.has_meta("kikiu_entrada")
	Engine.set_meta("kikiu_entrada", true)
	return pede_v1(ler_args(OS.get_cmdline_user_args() + OS.get_cmdline_args()), primeira)


func _abrir_v1() -> bool:
	if not pede_v1_na_entrada():
		return false
	process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().change_scene_to_file.call_deferred(CENA_V1)
	return true


func _ajustar_janela() -> void:
	add_child(UiJanela.new().montar(self))  # fator da interface, canvas e bloco no centro (v2/ui_janela.gd, v2/escala_ui.gd); devolve a janela ao sair


func _process(dt: float) -> void:
	if _status_t > 0.0:
		_status_t -= dt
		if _status_t <= 0.0:
			_status.text = ""


# ------------------------------------------------------------------ montagem


func _montar() -> void:
	var fundo := TextureRect.new()
	fundo.texture = FUNDO
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	EscalaUi.cobrir(fundo)  # a arte cobre o canvas inteiro, não só o bloco 960x540
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var veu := ColorRect.new()
	veu.color = Color(Paleta.PAINEL, 0.8)
	EscalaUi.cobrir(veu)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)

	add_child(_texto("SANTUÁRIO", Paleta.TITULO_GRANDE, true, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 6, LARG, 52)))
	add_child(_painel(Rect2(684, 10, 240, 46)))  # a borda direita (924) é a da coluna CONQUISTAS e a do VOLTAR
	add_child(_texto("ALMAS", Paleta.NUMERO_PEQUENO, false, COR_ALMA, HORIZONTAL_ALIGNMENT_LEFT, Rect2(700, 14, 120, 12)))
	_saldo = _texto("0", Paleta.TITULO_MEDIO, true, COR_ALMA, HORIZONTAL_ALIGNMENT_RIGHT, Rect2(700, 16, 208, 38))
	add_child(_saldo)
	_ultima = _texto("", Paleta.NUMERO_PEQUENO, false, COR_TEXTO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(20, 58, 920, 10))  # y 58-68: acaba onde os títulos MELHORIAS/CONQUISTAS (y 68) começam
	add_child(_ultima)

	# Grade de cartões: o detalhe da seleção ocupa uma única faixa, sem repetir parágrafos.
	add_child(_texto("MELHORIAS", Paleta.TITULO_MEDIO, true, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(36, 68, 572, 38)))
	var i := 0
	for m in Meta.melhorias_visiveis():
		var x := 36.0 + (i % 3) * 194.0
		var y := 106.0 + floori(i / 3.0) * 82.0  # cartões de 78 px, 4 px de folga: a grade acaba em y 348
		add_child(_painel(Rect2(x, y, 184, 78)))
		var selecionar := _botao_detalhe(Rect2(x + 4, y + 2, 176, 42))
		selecionar.focus_entered.connect(_selecionar.bind(str(m.id)))
		selecionar.mouse_entered.connect(_selecionar.bind(str(m.id)))
		selecionar.pressed.connect(_selecionar.bind(str(m.id)))
		var nome := _texto("", Paleta.TITULO_PEQUENO, true, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(x + 8, y + 4, 168, 22))
		var efeito := _texto("", Paleta.NUMERO_PEQUENO, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_RIGHT, Rect2(x + 92, y + 29, 82, 12))
		var progresso := Marcadores.new()
		progresso.position = Vector2(x + 8, y + 30)
		var cadeado := Cadeado.new()
		cadeado.position = Vector2(x + 158, y + 53)
		var botao := Button.new()
		botao.position = Vector2(x + 8, y + 48)
		botao.size = Vector2(142, 24)
		_estilo_botao(botao, Paleta.NUMERO_PEQUENO)
		botao.pressed.connect(_comprar.bind(str(m.id)))
		botao.focus_entered.connect(_selecionar.bind(str(m.id)))
		botao.mouse_entered.connect(_selecionar.bind(str(m.id)))
		for no in [nome, efeito, progresso, cadeado, botao]:
			add_child(no)
		_linhas[str(m.id)] = {"nome": nome, "efeito": efeito, "botao": botao, "cadeado": cadeado, "progresso": progresso, "selecionar": selecionar}
		i += 1
	add_child(_painel(Rect2(36, 354, 408, 90)))  # 6 px abaixo da grade e 2 px acima do rótulo MAPA (y 446); cabe 5 linhas de 17 px (o pior detalhe)
	_modo_btn = _botao_extra(Rect2(452, 354, 156, 28), "modo", "pesadelo")
	_rastro_btn = _botao_extra(Rect2(452, 416, 156, 28), "visual", "rastro_katana")
	_detalhe = _texto("", Paleta.TEXTO_TAMANHO, false, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(48, 356, 384, 85))
	_detalhe.add_theme_font_override("font", Dados.fonte_texto)
	_detalhe.add_theme_constant_override("line_spacing", LINHA_DETALHE - 16)  # linhas de 17 px (16 da fonte + 1): 5 linhas = 85 px
	_detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_detalhe)
	add_child(_texto("CONQUISTAS", Paleta.TITULO_MEDIO, true, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(X_CONQ, 68, LARG_CONQ, 38)))
	# A lista tem ~26 conquistas: rola dentro da área livre (y 106 a 446, acima do MAPA/status e dos botões). Roda do mouse, barra,
	# e o foco (teclado/controle) rola sozinho até o item (follow_focus). Os itens usam coordenadas locais do `conteudo`.
	_rolagem = ScrollContainer.new()
	_rolagem.position = Vector2(X_CONQ, 106)
	_rolagem.size = Vector2(LARG_CONQ, 340)
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem.follow_focus = true
	_rolagem.add_theme_constant_override("scrollbar_h_separation", 0)
	var barra_rolagem := _rolagem.get_v_scroll_bar()
	barra_rolagem.custom_minimum_size.x = 8
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(COR_OURO, 0.7)
	barra_rolagem.add_theme_stylebox_override("grabber", grabber)
	barra_rolagem.add_theme_stylebox_override("grabber_highlight", grabber)
	barra_rolagem.add_theme_stylebox_override("grabber_pressed", grabber)
	var trilho_rolagem := StyleBoxFlat.new()
	trilho_rolagem.bg_color = Color(Paleta.BARRA_VAZIA, 0.6)
	barra_rolagem.add_theme_stylebox_override("scroll", trilho_rolagem)
	add_child(_rolagem)
	var conteudo := Control.new()
	conteudo.custom_minimum_size = Vector2(LARG_CONQ - 12, Meta.conquistas().size() * PASSO_CONQ - 8)
	_rolagem.add_child(conteudo)
	i = 0
	for c in Meta.conquistas():
		var y := float(i * PASSO_CONQ)
		conteudo.add_child(_painel(Rect2(0, y, LARG_CONQ - 12, 100)))
		var selecionar := _botao_detalhe(Rect2(4, y + 2, LARG_CONQ - 20, 94), conteudo)
		selecionar.focus_entered.connect(_selecionar_conquista.bind(str(c.id)))
		selecionar.mouse_entered.connect(_selecionar_conquista.bind(str(c.id)))
		selecionar.pressed.connect(_selecionar_conquista.bind(str(c.id)))
		var cadeado := Cadeado.new()
		cadeado.position = Vector2(10, y + 8)
		var nome := _texto("", Paleta.TITULO_PEQUENO, true, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(32, y + 3, 238, 24))
		var desc := _texto("", Paleta.TEXTO_TAMANHO, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(10, y + 43, 260, 34))
		desc.add_theme_font_override("font", Dados.fonte_texto)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var rec := _texto("", Paleta.NUMERO_PEQUENO, false, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(10, y + 79, 260, 14))
		rec.clip_text = true
		var barra := ProgressBar.new()
		barra.position = Vector2(10, y + 29)
		barra.size = Vector2(260, 8)
		barra.show_percentage = false
		var trilho := StyleBoxFlat.new()
		trilho.bg_color = Paleta.BARRA_VAZIA
		var preenchimento := StyleBoxFlat.new()
		preenchimento.bg_color = COR_ALMA
		barra.add_theme_stylebox_override("background", trilho)
		barra.add_theme_stylebox_override("fill", preenchimento)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for no in [cadeado, nome, desc, rec, barra]:
			conteudo.add_child(no)
		_conq[str(c.id)] = {"cadeado": cadeado, "nome": nome, "desc": desc, "rec": rec, "barra": barra, "selecionar": selecionar}
		i += 1

	_status = _texto("", Paleta.NUMERO_PEQUENO, false, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(296, 446, 324, 12))
	add_child(_status)
	_entrar = Button.new()
	_entrar.text = "ENTRAR NA FLORESTA"
	_entrar.position = Vector2(296, 458)
	_entrar.size = Vector2(324, 40)  # termina em 620: a coluna CONQUISTAS começa em 632
	_entrar.add_theme_font_override("font", Dados.fonte_titulo)
	_entrar.add_theme_font_size_override("font_size", Paleta.TITULO_MEDIO)
	_estilo_botao(_entrar, Paleta.TITULO_MEDIO)
	_entrar.add_theme_color_override("font_color", COR_OURO)
	_entrar.pressed.connect(_entrar_floresta)
	add_child(_entrar)
	add_child(_texto("MAPA", Paleta.NUMERO_PEQUENO, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(36, 446, 120, 12)))
	_mapa = Button.new()  # à esquerda de ENTRAR: clique ou Enter passa para o mapa seguinte
	_mapa.position = Vector2(36, 458)
	_mapa.size = Vector2(248, 40)
	_estilo_botao(_mapa, Paleta.TITULO_PEQUENO)
	_mapa.add_theme_color_override("font_color", COR_OURO)
	_mapa.pressed.connect(_trocar_mapa)
	add_child(_mapa)
	_ajustes = Button.new()  # ao lado de ENTRAR: abre o mesmo submenu Ajustes da pausa (ligado no _ready)
	_ajustes.text = "AJUSTES"
	_ajustes.position = Vector2(672, 458)
	_ajustes.size = Vector2(124, 40)
	_ajustes.add_theme_font_override("font", Dados.fonte_titulo)
	_ajustes.add_theme_font_size_override("font_size", Paleta.TITULO_MEDIO)
	_estilo_botao(_ajustes, Paleta.TITULO_PEQUENO)
	_ajustes.add_theme_color_override("font_color", COR_OURO)
	add_child(_ajustes)
	_voltar = Button.new()
	_voltar.text = "VOLTAR"
	_voltar.position = Vector2(808, 458)
	_voltar.size = Vector2(116, 40)
	_estilo_botao(_voltar, Paleta.TITULO_PEQUENO)
	_voltar.pressed.connect(_voltar_menu)
	add_child(_voltar)
	var dica := Glifos.dica(_itens_dica, HORIZONTAL_ALIGNMENT_CENTER, COR_APAGADO)
	dica.position = Vector2(0, 510)  # rodapé (DESIGN.md §1b): caixa de 22 px, glifo centrado em 513-529; os botões terminam em 498; o MAPA e o status ficam em 446-458
	dica.size = Vector2(LARG, 22)
	add_child(dica)


## A dica de rodapé: só os botões do dispositivo em uso.
func _itens_dica() -> Array:
	var r: Array = [["navegar", "Escolher"], ["confirmar", "Confirmar"], ["voltar", "Voltar"]]
	if not Glifos.eh_controle():
		r.insert(2, ["mouse", "também"])
	return r


## Botão de liga/desliga de um modo ou visual liberado por conquista (some enquanto a conquista não foi cumprida).
func _botao_extra(r: Rect2, tipo: String, id: String) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	_estilo_botao(b, Paleta.NUMERO_PEQUENO)
	b.pressed.connect(_alternar_extra.bind(tipo, id))
	b.focus_entered.connect(_detalhar_extra.bind(tipo, id))
	b.mouse_entered.connect(_detalhar_extra.bind(tipo, id))
	b.visible = false
	add_child(b)
	return b


func _alternar_extra(tipo: String, id: String) -> void:
	if not Meta.ligar(tipo, id, not Meta.ligado(tipo, id)):
		_avisar("Não foi possível salvar")
	_atualizar_extras()
	_detalhar_extra(tipo, id)


func _detalhar_extra(tipo: String, id: String) -> void:
	_detalhe.text = _texto_extra(Meta.item_extra(tipo, id), id, false)


## O texto de um modo ou visual: o nome, a frase do Breno (dados/v2_meta.json, quando tem) e o que ele faz.
## A frase só entra no tooltip: o detalhe (caixa de 384x85 px, 5 linhas) já está cheio com o efeito do Pesadelo.
func _texto_extra(item: Dictionary, id: String, com_frase: bool) -> String:
	var partes: Array[String] = [str(item.get("nome", id))]
	if com_frase and str(item.get("frase", "")) != "":
		partes.append(str(item.frase))
	partes.append(Meta.texto_item(item))
	return "\n".join(PackedStringArray(partes))


## Mostra os botões dos extras liberados, com o estado (LIGADO ou DESLIGADO).
func _atualizar_extras() -> void:
	for par in [[_modo_btn, "modo", "pesadelo", "PESADELO"], [_rastro_btn, "visual", "rastro_katana", "RASTRO"]]:
		var b: Button = par[0]
		b.visible = Meta.liberado(par[1], par[2])
		b.text = "%s: %s" % [par[3], "LIGADO" if Meta.ligado(par[1], par[2]) else "DESLIGADO"]
		b.tooltip_text = _texto_extra(Meta.item_extra(par[1], par[2]), par[2], true)
		b.add_theme_color_override("font_color", COR_OURO if Meta.ligado(par[1], par[2]) else COR_TEXTO)


func _texto(txt: String, tam: int, titulo: bool, cor: Color, alin: HorizontalAlignment, r: Rect2) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = alin
	l.add_theme_font_override("font", Dados.fonte_titulo if titulo else Dados.fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(Paleta.PRETO, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _painel(r: Rect2) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _moldura(Paleta.MOLDURA))
	return p


## Moldura 9-patch de pedra do HUD (20x20, margem de 5 px), tingida pela cor.
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


func _estilo_botao(b: Button, tam: int) -> void:
	b.add_theme_font_override("font", Dados.fonte_titulo if tam >= 19 else Dados.fonte)
	b.add_theme_font_size_override("font_size", tam)
	b.add_theme_stylebox_override("normal", _moldura(Paleta.MOLDURA))
	b.add_theme_stylebox_override("hover", _moldura(COR_OURO))
	b.add_theme_stylebox_override("focus", _moldura(COR_OURO))
	b.add_theme_stylebox_override("pressed", _moldura(Paleta.MOLDURA_ESCURA))
	b.add_theme_stylebox_override("disabled", _moldura(Color(Paleta.MOLDURA_APAGADA, 0.75)))
	b.add_theme_color_override("font_color", COR_TEXTO)
	b.add_theme_color_override("font_hover_color", COR_FOCO)
	b.add_theme_color_override("font_focus_color", COR_FOCO)
	b.add_theme_color_override("font_pressed_color", COR_TEXTO)
	b.add_theme_color_override("font_disabled_color", COR_APAGADO)


# ------------------------------------------------------------------ estado da tela


func _atualizar() -> void:
	var e := Meta.estado()
	_saldo.text = str(e.almas)
	_ultima.text = _texto_ultima(e.ultima)
	_atualizar_extras()
	for m in Meta.melhorias_visiveis():
		var linha: Dictionary = _linhas[str(m.id)]
		var n: int = e.niveis[str(m.id)]
		var nome: Label = linha.nome
		var efeito: Label = linha.efeito
		var botao: Button = linha.botao
		var cadeado: Cadeado = linha.cadeado
		nome.text = str(m.nome)
		(linha.progresso as Marcadores).nivel = n
		(linha.progresso as Marcadores).maximo = int(m.max)
		(linha.progresso as Marcadores).queue_redraw()
		var bloqueada := not _liberada(m, e)
		nome.add_theme_color_override("font_color", COR_APAGADO if bloqueada else COR_TEXTO)
		efeito.add_theme_color_override("font_color", COR_EFEITO)
		cadeado.visible = bloqueada
		if bloqueada:
			botao.text = "BLOQUEADA"
			botao.disabled = true
		elif n >= int(m.max):
			botao.text = "MÁXIMO"
			botao.disabled = true
		else:
			botao.text = "COMPRAR %d" % Meta.custo_do_nivel(m, n)
			botao.disabled = false
		efeito.text = "%d/%d" % [n, int(m.max)]
		botao.tooltip_text = "%s\n%s" % [m.nome, _detalhe_melhoria(m, e)]
		(linha.selecionar as Button).tooltip_text = botao.tooltip_text
	if _linhas.has(_selecionada):
		_selecionar(_selecionada)
	else:
		_selecionar_conquista(_selecionada)
	for c in Meta.conquistas():
		var v: Dictionary = _conq[str(c.id)]
		var feita: bool = e.conquistas[str(c.id)]
		var cadeado: Cadeado = v.cadeado
		cadeado.aberto = feita
		cadeado.queue_redraw()
		(v.nome as Label).text = str(c.nome)
		(v.nome as Label).add_theme_color_override("font_color", COR_OURO if feita else COR_TEXTO)
		var valor := 0.0
		var limite := float(c.get("limite", 1))
		match str(c.condicao):
			"tempo":
				valor = float(e.ultima.get("tempo", 0))
			"combo":
				valor = float(e.ultima.get("maior_combo", 0))
		(v.barra as ProgressBar).value = 100.0 if feita else minf(100.0, valor / limite * 100.0)
		var apoio := "Cumprida" if feita else "Última: %d/%d" % [int(valor), int(limite)]
		if str(c.condicao) == "tempo" and not feita:
			apoio = "Última: %d/%d s" % [int(valor), int(limite)]
		if str(c.condicao) == "venceu" and not feita:
			apoio = str(c.desc)  # o texto da própria conquista: cada mapa tem o seu chefe
		(v.desc as Label).text = apoio
		(v.nome as Label).tooltip_text = str(c.desc)
		(v.nome as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var libera := _texto_recompensa(c.recompensa)
		var texto := ("Libera: " + libera) if libera != "" else ""
		(v.rec as Label).tooltip_text = texto
		(v.rec as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(v.rec as Label).text = texto
	_ligar_foco()


## O índice do último cartão da coluna `coluna` (0 a 2) numa grade de 3 colunas com `total` cartões (a última linha pode ter menos de 3).
func _fim_da_coluna(total: int, coluna: int) -> int:
	var ultimo := coluna + 3 * floori((total - 1 - coluna) / 3.0)
	return clampi(ultimo, 0, maxi(total - 1, 0))


## A busca geométrica do Godot pode preferir uma conquista fora da área rolada ao botão vizinho.
## Fixamos a grade e o rodapé; follow_focus continua responsável por trazer as conquistas para a tela.
func _ligar_foco() -> void:
	var ids: Array = _linhas.keys()
	var conquistas: Array = _conq.values()
	var primeira: Button = conquistas[0].selecionar
	for i in ids.size():
		var cartao: Button = _linhas[ids[i]].selecionar
		var compra: Button = _linhas[ids[i]].botao
		var fim: Button = _mapa if i % 3 == 0 else _entrar
		if i % 3 == 2 and _modo_btn.visible:
			fim = _modo_btn
		var abaixo: Button = _linhas[ids[i + 3]].selecionar if i + 3 < ids.size() else fim
		cartao.focus_neighbor_top = cartao.get_path_to(cartao if i < 3 else _compra_ou_cartao(ids[i - 3]))
		cartao.focus_neighbor_bottom = cartao.get_path_to(abaixo if compra.disabled else compra)
		compra.focus_neighbor_top = compra.get_path_to(cartao)
		compra.focus_neighbor_bottom = compra.get_path_to(abaixo)
		for par in [[cartao, false], [compra, true]]:
			var b: Button = par[0]
			var esquerda: Button = b if i % 3 == 0 else (_compra_ou_cartao(ids[i - 1]) if par[1] else _linhas[ids[i - 1]].selecionar)
			var direita: Button = (
				primeira if i % 3 == 2 or i + 1 >= ids.size() else (_compra_ou_cartao(ids[i + 1]) if par[1] else _linhas[ids[i + 1]].selecionar)
			)
			b.focus_neighbor_left = b.get_path_to(esquerda)
			b.focus_neighbor_right = b.get_path_to(direita)
	for i in conquistas.size():
		var b: Button = conquistas[i].selecionar
		b.focus_neighbor_top = b.get_path_to(b if i == 0 else conquistas[i - 1].selecionar)
		b.focus_neighbor_bottom = b.get_path_to(_ajustes if i + 1 == conquistas.size() else conquistas[i + 1].selecionar)
		b.focus_neighbor_left = b.get_path_to(_linhas[ids[mini(mini(i, 2) * 3 + 2, ids.size() - 1)]].selecionar)
		b.focus_neighbor_right = b.get_path_to(b)
	var rodape: Array[Button] = [_mapa, _entrar, _ajustes, _voltar]
	for i in rodape.size():
		var b := rodape[i]
		b.focus_neighbor_left = b.get_path_to(rodape[maxi(0, i - 1)])
		b.focus_neighbor_right = b.get_path_to(rodape[mini(rodape.size() - 1, i + 1)])
		b.focus_neighbor_bottom = b.get_path_to(b)
	_mapa.focus_neighbor_top = _mapa.get_path_to(_compra_ou_cartao(ids[_fim_da_coluna(ids.size(), 0)]))
	_entrar.focus_neighbor_top = _entrar.get_path_to(
		_rastro_btn if _rastro_btn.visible else (_modo_btn if _modo_btn.visible else _compra_ou_cartao(ids[_fim_da_coluna(ids.size(), 1)]))
	)
	_modo_btn.focus_neighbor_top = _modo_btn.get_path_to(_compra_ou_cartao(ids[_fim_da_coluna(ids.size(), 2)]))
	_modo_btn.focus_neighbor_bottom = _modo_btn.get_path_to(_rastro_btn if _rastro_btn.visible else _entrar)
	_rastro_btn.focus_neighbor_top = _rastro_btn.get_path_to(_modo_btn if _modo_btn.visible else _compra_ou_cartao(ids[_fim_da_coluna(ids.size(), 2)]))
	_rastro_btn.focus_neighbor_bottom = _rastro_btn.get_path_to(_entrar)


func _compra_ou_cartao(id: String) -> Button:
	return _linhas[id].selecionar if _linhas[id].botao.disabled else _linhas[id].botao


func _liberada(m: Dictionary, e: Dictionary) -> bool:
	var req := str(m.get("requer", ""))
	return req == "" or bool(e.conquistas.get(req, false))


func _nome_conquista(id: String) -> String:
	for c in Meta.conquistas():
		if str(c.id) == id:
			return str(c.nome)
	return id


## O que a conquista libera, em texto. Modo e visual só ficam marcados no save: com `efeito` "pendente" saem com "(sem efeito ainda)".
## Item com `oculta_ate_ter_efeito` (dados/v2_meta.json) não aparece: devolve "" e a conquista segue na lista, sem a recompensa.
func _texto_recompensa(r: Dictionary) -> String:
	var item := Meta.item_da_recompensa(r)
	if Meta.oculto(item):
		return ""
	var nome := str(item.get("nome", r.get("id", "")))
	if str(r.tipo) == "modo":
		nome = "modo " + nome
	if str(item.get("efeito", "")) == "pendente":
		nome += " (sem efeito ainda)"
	return nome


func _texto_ultima(u: Dictionary) -> String:
	if u.is_empty():
		return "Escolha um mapa e volte com almas."
	var seg := int(float(u.get("tempo", 0.0)))
	return (
		"Última partida:  %02d:%02d   %d abates   combo x%d   nível %d   +%d almas"
		% [
			floori(seg / 60.0),
			seg % 60,
			int(u.get("abates", 0)),
			int(u.get("maior_combo", 0)),
			int(u.get("nivel", 1)),
			int(u.get("ganhas", 0)),
		]
	)


# ------------------------------------------------------------------ ações


func _comprar(id: String) -> void:
	var m := Meta.melhoria(id)
	var n := Meta.nivel(id)
	if Meta.comprar(id):
		_avisar("%s: nível %d" % [m.nome, n + 1])
	elif Meta.erro_save:
		_avisar("Não foi possível salvar")
	else:
		_avisar(_motivo(m))
	_atualizar()
	var botao: Button = _linhas[id].botao
	if botao.disabled:
		_entrar.grab_focus()  # não some o foco quando a melhoria chega ao máximo
	else:
		botao.grab_focus()


func _motivo(m: Dictionary) -> String:
	var e := Meta.estado()
	if not _liberada(m, e):
		return 'Bloqueada: cumpra "%s" antes' % _nome_conquista(str(m.requer))
	var n: int = e.niveis[str(m.id)]
	if n >= int(m.max):
		return "Nível máximo"
	return "Faltam %d almas" % (Meta.custo_do_nivel(m, n) - int(e.almas))


func _avisar(texto: String) -> void:
	_status.text = texto
	_status_t = TEMPO_AVISO


func _atualizar_mapa() -> void:
	_mapa_id = Mapas.escolhido()
	var m: Dictionary = Mapas.buscar(_mapa_id)
	_mapa.text = "< %s >" % m.nome
	# O mínimo do Button cresce com o texto; a Jersey 19 mantém todos os nomes completos na mesma largura.
	_mapa.add_theme_font_size_override("font_size", Paleta.TITULO_PEQUENO)
	_mapa.size = Vector2(248, 40)
	_mapa.tooltip_text = str(m.nome)
	_entrar.text = str(m.entrar)


func _trocar_mapa() -> void:
	var seguinte := Mapas.proximo(_mapa_id)
	if seguinte == _mapa_id:  # só este mapa está aberto: o seguinte da lista mostra o que falta para abrir
		var trancado: Dictionary = Mapas.LISTA[posmod(Mapas.ids().find(_mapa_id) + 1, Mapas.LISTA.size())]
		_avisar(Mapas.condicao(trancado) if Mapas.condicao(trancado) != "" else "Só há este mapa")
		return
	if not Mapas.escolher(seguinte):
		_avisar("Não foi possível salvar")
		return
	_atualizar_mapa()


func _entrar_floresta() -> void:
	Transicoes.ir_para(self, FLORESTA)


class Marcadores:
	extends Control
	var nivel := 0
	var maximo := 5

	func _init() -> void:
		size = Vector2(80, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in maximo:
			draw_rect(Rect2(i * 15, 0, 11, 8), COR_ALMA if i < nivel else Paleta.BARRA_VAZIA)


func _detalhe_melhoria(m: Dictionary, e: Dictionary) -> String:
	var n := int(e.niveis[str(m.id)])
	if not _liberada(m, e):
		return "Libera: " + _nome_conquista(str(m.requer))
	if n >= int(m.max):
		return Meta.texto_efeito(m, n) + " — nível máximo"
	return (Meta.texto_efeito(m, n) if n > 0 else "Ainda não comprada") + "\n" + Meta.texto_proximo(m, n)


func _selecionar(id: String) -> void:
	_selecionada = id
	_detalhe.text = str(Meta.melhoria(id).nome) + "\n" + _detalhe_melhoria(Meta.melhoria(id), Meta.estado())


func _unhandled_input(e: InputEvent) -> void:
	if pausa != null and not pausa.aberto and (pausa._pede_menu(e) or e.is_action_pressed("ui_cancel")):
		if e is InputEventKey and e.echo:
			return
		get_viewport().set_input_as_handled()
		_voltar_menu()


func _voltar_menu() -> void:
	Transicoes.ir_para(self, "res://v2/menu_principal.tscn", true)


func _botao_detalhe(r: Rect2, pai: Node = null) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	for estado in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
	var foco := StyleBoxFlat.new()
	foco.bg_color = Color(Paleta.PRETO, 0.0)
	foco.set_border_width_all(1)
	foco.border_color = COR_OURO
	b.add_theme_stylebox_override("focus", foco)
	(pai if pai != null else self).add_child(b)
	return b


func _selecionar_conquista(id: String) -> void:
	_selecionada = id
	for c in Meta.conquistas():
		if str(c.id) == id:
			_detalhe.text = str(c.desc)
			var recompensa := _texto_recompensa(c.recompensa)
			if recompensa != "":
				_detalhe.text += "\nLibera: " + recompensa
