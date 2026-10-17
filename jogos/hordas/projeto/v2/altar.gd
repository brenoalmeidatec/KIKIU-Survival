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
const COR_OURO := Paleta.OURO
const COR_TEXTO := Paleta.TEXTO
const COR_APAGADO := Paleta.TEXTO_APAGADO
const COR_EFEITO := Paleta.TEXTO_SECUNDARIO
const COR_FOCO := Paleta.FOCO  # texto do botão com foco ou sob o mouse (o fundo do botão é escuro)
const COR_ALMA := Paleta.ALMA
const DICA := "Setas ou analógico escolhem   Enter ou A confirma   Mouse também"
const TEMPO_AVISO := 3.0

var _saldo: Label
var _ultima: Label
var _status: Label
var _status_t := 0.0
var _linhas := {}  # id da melhoria -> {nome, efeito, botao, cadeado}
var _conq := {}  # id da conquista -> {cadeado, nome, desc, rec}
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
	_montar()
	pausa = preload("res://v2/pausa.tscn").instantiate().iniciar(null)
	pausa.sair_no_frontend = false
	add_child(pausa)
	_ajustes.pressed.connect(pausa.abrir_ajustes)
	pausa.fechou.connect(func(): _ajustes.grab_focus())
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

	add_child(_texto("SANTUÁRIO", Paleta.TITULO_GRANDE, true, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 6, LARG, 56)))
	add_child(_painel(Rect2(700, 10, 240, 46)))
	add_child(_texto("ALMAS", Paleta.NUMERO_PEQUENO, false, COR_ALMA, HORIZONTAL_ALIGNMENT_LEFT, Rect2(716, 14, 120, 12)))
	_saldo = _texto("0", Paleta.TITULO_MEDIO, true, COR_ALMA, HORIZONTAL_ALIGNMENT_RIGHT, Rect2(716, 16, 208, 38))
	add_child(_saldo)
	_ultima = _texto("", Paleta.NUMERO_PEQUENO, false, COR_TEXTO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(20, 62, 920, 14))
	add_child(_ultima)

	# Grade de cartões: o detalhe da seleção ocupa uma única faixa, sem repetir parágrafos.
	add_child(_texto("MELHORIAS", Paleta.TITULO_MEDIO, true, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(36, 86, 572, 38)))
	var i := 0
	for m in Meta.melhorias_visiveis():
		var x := 36.0 + (i % 3) * 194.0
		var y := 128.0 + floori(i / 3.0) * 86.0
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
	add_child(_painel(Rect2(36, 392, 408, 66)))
	_modo_btn = _botao_extra(Rect2(452, 392, 156, 31), "modo", "pesadelo")
	_rastro_btn = _botao_extra(Rect2(452, 427, 156, 31), "visual", "rastro_katana")
	_detalhe = _texto("", Paleta.TEXTO_TAMANHO, false, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(48, 398, 384, 54))
	_detalhe.add_theme_font_override("font", Dados.fonte_texto)
	_detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_detalhe)
	add_child(_texto("CONQUISTAS", Paleta.TITULO_MEDIO, true, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(632, 86, 292, 38)))
	i = 0
	for c in Meta.conquistas():
		var y := 128.0 + i * 108.0
		add_child(_painel(Rect2(632, y, 292, 100)))
		var selecionar := _botao_detalhe(Rect2(636, y + 2, 284, 94))
		selecionar.focus_entered.connect(_selecionar_conquista.bind(str(c.id)))
		selecionar.mouse_entered.connect(_selecionar_conquista.bind(str(c.id)))
		selecionar.pressed.connect(_selecionar_conquista.bind(str(c.id)))
		var cadeado := Cadeado.new()
		cadeado.position = Vector2(642, y + 8)
		var nome := _texto("", Paleta.TITULO_PEQUENO, true, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(664, y + 3, 250, 24))
		var desc := _texto("", Paleta.TEXTO_TAMANHO, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(642, y + 43, 272, 34))
		desc.add_theme_font_override("font", Dados.fonte_texto)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var rec := _texto("", Paleta.NUMERO_PEQUENO, false, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(642, y + 79, 272, 14))
		rec.clip_text = true
		var barra := ProgressBar.new()
		barra.position = Vector2(642, y + 29)
		barra.size = Vector2(272, 8)
		barra.show_percentage = false
		var trilho := StyleBoxFlat.new()
		trilho.bg_color = Paleta.BARRA_VAZIA
		var preenchimento := StyleBoxFlat.new()
		preenchimento.bg_color = COR_ALMA
		barra.add_theme_stylebox_override("background", trilho)
		barra.add_theme_stylebox_override("fill", preenchimento)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for no in [cadeado, nome, desc, rec, barra]:
			add_child(no)
		_conq[str(c.id)] = {"cadeado": cadeado, "nome": nome, "desc": desc, "rec": rec, "barra": barra, "selecionar": selecionar}
		i += 1

	_status = _texto("", Paleta.NUMERO_PEQUENO, false, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(20, 464, 920, 14))
	add_child(_status)
	_entrar = Button.new()
	_entrar.text = "ENTRAR NA FLORESTA"
	_entrar.position = Vector2(300, 478)
	_entrar.size = Vector2(360, 40)
	_entrar.add_theme_font_override("font", Dados.fonte_titulo)
	_entrar.add_theme_font_size_override("font_size", Paleta.TITULO_MEDIO)
	_estilo_botao(_entrar, Paleta.TITULO_MEDIO)
	_entrar.add_theme_color_override("font_color", COR_OURO)
	_entrar.pressed.connect(_entrar_floresta)
	add_child(_entrar)
	add_child(_texto("MAPA", Paleta.NUMERO_PEQUENO, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(36, 468, 120, 12)))
	_mapa = Button.new()  # à esquerda de ENTRAR: clique ou Enter passa para o mapa seguinte
	_mapa.position = Vector2(36, 482)
	_mapa.size = Vector2(248, 40)
	_estilo_botao(_mapa, Paleta.TITULO_PEQUENO)
	_mapa.add_theme_color_override("font_color", COR_OURO)
	_mapa.pressed.connect(_trocar_mapa)
	add_child(_mapa)
	_ajustes = Button.new()  # ao lado de ENTRAR: abre o mesmo submenu Ajustes da pausa (ligado no _ready)
	_ajustes.text = "AJUSTES"
	_ajustes.position = Vector2(672, 478)
	_ajustes.size = Vector2(124, 40)
	_ajustes.add_theme_font_override("font", Dados.fonte_titulo)
	_ajustes.add_theme_font_size_override("font_size", Paleta.TITULO_MEDIO)
	_estilo_botao(_ajustes, Paleta.TITULO_PEQUENO)
	_ajustes.add_theme_color_override("font_color", COR_OURO)
	add_child(_ajustes)
	_voltar = Button.new()
	_voltar.text = "VOLTAR"
	_voltar.position = Vector2(808, 478)
	_voltar.size = Vector2(116, 40)
	_estilo_botao(_voltar, Paleta.TITULO_PEQUENO)
	_voltar.pressed.connect(_voltar_menu)
	add_child(_voltar)
	add_child(_texto(DICA, Paleta.NUMERO_PEQUENO, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 528, LARG, 12)))  # 10 px abaixo dos botões (antes 4: a dica encostava na borda deles)


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
	var item := Meta.item_extra(tipo, id)
	_detalhe.text = "%s\n%s" % [item.get("nome", id), Meta.texto_item(item)]


## Mostra os botões dos extras liberados, com o estado (LIGADO ou DESLIGADO).
func _atualizar_extras() -> void:
	for par in [[_modo_btn, "modo", "pesadelo", "PESADELO"], [_rastro_btn, "visual", "rastro_katana", "RASTRO"]]:
		var b: Button = par[0]
		b.visible = Meta.liberado(par[1], par[2])
		b.text = "%s: %s" % [par[3], "LIGADO" if Meta.ligado(par[1], par[2]) else "DESLIGADO"]
		var item := Meta.item_extra(par[1], par[2])
		b.tooltip_text = "%s\n%s" % [item.get("nome", par[2]), Meta.texto_item(item)]
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
			apoio = "Vença o chefe da floresta"
		(v.desc as Label).text = apoio
		(v.nome as Label).tooltip_text = str(c.desc)
		(v.nome as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var libera := _texto_recompensa(c.recompensa)
		var texto := ("Libera: " + libera) if libera != "" else ""
		(v.rec as Label).tooltip_text = texto
		(v.rec as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(v.rec as Label).text = texto


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
	var nome := str(item.get("nome", r.id))
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
	if not Mapas.escolher(Mapas.proximo(_mapa_id)):
		_avisar("Não foi possível salvar")
		return
	_atualizar_mapa()


func _entrar_floresta() -> void:
	get_tree().change_scene_to_file(FLORESTA)


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
	get_tree().change_scene_to_file("res://v2/menu_principal.tscn")


func _botao_detalhe(r: Rect2) -> Button:
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
	add_child(b)
	return b


func _selecionar_conquista(id: String) -> void:
	_selecionada = id
	for c in Meta.conquistas():
		if str(c.id) == id:
			_detalhe.text = str(c.desc)
			var recompensa := _texto_recompensa(c.recompensa)
			if recompensa != "":
				_detalhe.text += "\nLibera: " + recompensa
