extends Control
## Santuário da v2: a tela antes da floresta e a CENA PRINCIPAL do jogo (run/main_scene). Com `--v1` (ou um argumento só da v1,
## veja ARGS_V1) abre o menu da v1 (main.tscn), que resolve o resto (--cena, --prototipo, --bot...). Compra melhorias permanentes com as almas (v2/meta.gd),
## mostra as conquistas com cadeado, o resumo da última partida e ENTRAR NA FLORESTA (v2/mundo.tscn). Desenhado em 960x540 com a
## janela em CANVAS_ITEMS, sem SubViewport: botões, foco e controle funcionam direto. Cada compra relê o save (Meta.estado()).
## Visual: a arte de entrada escurecida, molduras de pedra do HUD (v2/hud/moldura_pedra.png). Títulos na Jersey 10 (Dados.fonte_titulo) e a lista densa na Press Start 2P (Dados.fonte), que tem a grade de 8 px que as 10 linhas pedem.

const Meta := preload("res://v2/meta.gd")
const Trilha := preload("res://v2/trilha.gd")
const MOLDURA := preload("res://v2/hud/moldura_pedra.png")
const FUNDO := preload("res://assets/icone/entrada.png")
const FLORESTA := "res://v2/mundo.tscn"
const CENA_V1 := "res://main.tscn"
## Argumentos que levam à v1 (main.gd os trata): --v1, os de troca de cena e os de teste da v1 (README de jogos/hordas, testes/online_*.sh).
const ARGS_V1 := ["v1", "cena", "prototipo", "bot", "online", "sair", "print_tela"]
const LARG := 960
const ALT := 540
const COR_OURO := Color(1.0, 0.86, 0.42)
const COR_TEXTO := Color(0.92, 0.9, 0.96)
const COR_APAGADO := Color(0.55, 0.56, 0.64)
const COR_EFEITO := Color(0.74, 0.76, 0.84)
const COR_FOCO := Color(1.0, 0.97, 0.8)  # texto do botão com foco ou sob o mouse (o fundo do botão é escuro)
const COR_ALMA := Color(0.8, 0.66, 1.0)
const DICA := "Setas ou analógico escolhem   Enter ou A confirma   Mouse também"
const LINHA_Y0 := 128.0  # primeira linha de melhoria
const LINHA_H := 36.0
const CONQ_Y0 := 128.0  # primeira conquista
const CONQ_H := 92.0
const TEMPO_AVISO := 3.0

var _antes := {}  # modo de escala da janela antes desta tela (volta ao sair)
var _saldo: Label
var _ultima: Label
var _status: Label
var _status_t := 0.0
var _linhas := {}  # id da melhoria -> {nome, efeito, botao, cadeado}
var _conq := {}  # id da conquista -> {cadeado, nome, desc, rec}
var _entrar: Button
var _ajustes: Button
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
		var cor := Color(1.0, 0.86, 0.42) if aberto else Color(0.55, 0.56, 0.64)
		draw_rect(Rect2(3, 1, 8, 8), cor, false, 2.0)
		draw_rect(Rect2(1, 7, 12, 9), cor)
		draw_rect(Rect2(6, 10, 2, 3), Color(0.08, 0.08, 0.1))


func _ready() -> void:
	if _abrir_v1():
		return
	_ajustar_janela()
	set_anchors_preset(PRESET_FULL_RECT)
	_montar()
	var pausa = preload("res://v2/pausa.tscn").instantiate().iniciar(null)  # ESC aqui abre só "Sair?"; o botão Ajustes abre o submenu (pausa.gd)
	add_child(pausa)
	_ajustes.pressed.connect(pausa.abrir_ajustes)
	trilha = Trilha.new()
	add_child(trilha)
	trilha.tocar("santuario")
	_atualizar()
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


func _abrir_v1() -> bool:
	var primeira := not Engine.has_meta("kikiu_entrada")
	Engine.set_meta("kikiu_entrada", true)
	if not pede_v1(ler_args(OS.get_cmdline_user_args() + OS.get_cmdline_args()), primeira):
		return false
	process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().change_scene_to_file.call_deferred(CENA_V1)
	return true


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
	fundo.set_anchors_preset(PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var veu := ColorRect.new()
	veu.color = Color(0.01, 0.02, 0.035, 0.8)
	veu.set_anchors_preset(PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)

	add_child(_texto("SANTUÁRIO", 56, true, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 6, LARG, 56)))
	add_child(_painel(Rect2(700, 10, 240, 46)))
	add_child(_texto("ALMAS", 8, false, COR_ALMA, HORIZONTAL_ALIGNMENT_LEFT, Rect2(716, 14, 120, 12)))
	_saldo = _texto("0", 37, true, COR_ALMA, HORIZONTAL_ALIGNMENT_RIGHT, Rect2(716, 16, 208, 38))
	add_child(_saldo)
	_ultima = _texto("", 8, false, COR_TEXTO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(20, 62, 920, 14))
	add_child(_ultima)

	# coluna da esquerda: as melhorias compradas com almas
	add_child(_painel(Rect2(36, 88, 572, 374)))
	add_child(_texto("MELHORIAS", 37, true, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(52, 90, 300, 38)))
	var i := 0
	for m in Meta.melhorias_visiveis():
		var y := LINHA_Y0 + i * LINHA_H
		var nome := _texto("", 8, false, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(52, y + 3, 380, 12))
		var efeito := _texto("", 8, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(52, y + 18, 380, 12))
		var cadeado := Cadeado.new()
		cadeado.position = Vector2(428, y + 9)
		var botao := Button.new()
		botao.position = Vector2(464, y + 4)
		botao.size = Vector2(128, 26)
		_estilo_botao(botao, 8)
		botao.pressed.connect(_comprar.bind(str(m.id)))
		add_child(nome)
		add_child(efeito)
		add_child(cadeado)
		add_child(botao)
		_linhas[str(m.id)] = {"nome": nome, "efeito": efeito, "botao": botao, "cadeado": cadeado}
		i += 1

	# coluna da direita: conquistas com cadeado (e o que cada uma libera)
	add_child(_painel(Rect2(624, 88, 300, 374)))
	add_child(_texto("CONQUISTAS", 37, true, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(640, 90, 280, 38)))
	i = 0
	for c in Meta.conquistas():
		var y := CONQ_Y0 + i * CONQ_H
		var cadeado := Cadeado.new()
		cadeado.position = Vector2(640, y + 2)
		var nome := _texto("", 8, false, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(664, y, 252, 12))
		var desc := _texto("", 8, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(664, y + 14, 252, 30))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var rec := _texto("", 8, false, COR_OURO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(664, y + 50, 252, 30))
		rec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for no in [cadeado, nome, desc, rec]:
			add_child(no)
		_conq[str(c.id)] = {"cadeado": cadeado, "nome": nome, "desc": desc, "rec": rec}
		i += 1

	_status = _texto("", 8, false, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(20, 464, 920, 14))
	add_child(_status)
	_entrar = Button.new()
	_entrar.text = "ENTRAR NA FLORESTA"
	_entrar.position = Vector2(300, 478)
	_entrar.size = Vector2(360, 40)
	_entrar.add_theme_font_override("font", Dados.fonte_titulo)
	_entrar.add_theme_font_size_override("font_size", 37)
	_estilo_botao(_entrar, 37)
	_entrar.add_theme_color_override("font_color", COR_OURO)
	_entrar.pressed.connect(_entrar_floresta)
	add_child(_entrar)
	_ajustes = Button.new()  # ao lado de ENTRAR: abre o mesmo submenu Ajustes da pausa (ligado no _ready)
	_ajustes.text = "AJUSTES"
	_ajustes.position = Vector2(672, 478)
	_ajustes.size = Vector2(168, 40)
	_ajustes.add_theme_font_override("font", Dados.fonte_titulo)
	_ajustes.add_theme_font_size_override("font_size", 37)
	_estilo_botao(_ajustes, 37)
	_ajustes.add_theme_color_override("font_color", COR_OURO)
	add_child(_ajustes)
	add_child(_texto(DICA, 8, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 528, LARG, 12)))  # 10 px abaixo dos botões (antes 4: a dica encostava na borda deles)


func _texto(txt: String, tam: int, titulo: bool, cor: Color, alin: HorizontalAlignment, r: Rect2) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = alin
	l.add_theme_font_override("font", Dados.fonte_titulo if titulo else Dados.fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _painel(r: Rect2) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _moldura(Color(0.82, 0.85, 0.95)))
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
	b.add_theme_font_override("font", Dados.fonte_titulo if tam >= 24 else Dados.fonte)
	b.add_theme_font_size_override("font_size", tam)
	b.add_theme_stylebox_override("normal", _moldura(Color(0.8, 0.82, 0.9)))
	b.add_theme_stylebox_override("hover", _moldura(COR_OURO))
	b.add_theme_stylebox_override("focus", _moldura(COR_OURO))
	b.add_theme_stylebox_override("pressed", _moldura(Color(0.6, 0.6, 0.7)))
	b.add_theme_stylebox_override("disabled", _moldura(Color(0.42, 0.42, 0.5, 0.75)))
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
	for m in Meta.melhorias_visiveis():
		var linha: Dictionary = _linhas[str(m.id)]
		var n: int = e.niveis[str(m.id)]
		var nome: Label = linha.nome
		var efeito: Label = linha.efeito
		var botao: Button = linha.botao
		var cadeado: Cadeado = linha.cadeado
		nome.text = "%s   %d/%d" % [m.nome, n, int(m.max)]
		var bloqueada := not _liberada(m, e)
		nome.add_theme_color_override("font_color", COR_APAGADO if bloqueada else COR_TEXTO)
		efeito.add_theme_color_override("font_color", COR_EFEITO)
		cadeado.visible = bloqueada
		if bloqueada:
			efeito.text = "Libera ao cumprir: %s" % _nome_conquista(str(m.requer))
			botao.text = "BLOQUEADA"
			botao.disabled = true
		elif n >= int(m.max):
			efeito.text = "%s   nível máximo" % Meta.texto_efeito(m, n)
			botao.text = "MÁXIMO"
			botao.disabled = true
		else:
			var agora := ("Agora: " + Meta.texto_efeito(m, n)) if n > 0 else "Ainda sem efeito"
			efeito.text = "%s   %s" % [agora, Meta.texto_proximo(m, n)]
			botao.text = "COMPRAR %d" % Meta.custo_do_nivel(m, n)
			botao.disabled = false
	for c in Meta.conquistas():
		var v: Dictionary = _conq[str(c.id)]
		var feita: bool = e.conquistas[str(c.id)]
		var cadeado: Cadeado = v.cadeado
		cadeado.aberto = feita
		cadeado.queue_redraw()
		(v.nome as Label).text = str(c.nome)
		(v.nome as Label).add_theme_color_override("font_color", COR_OURO if feita else COR_TEXTO)
		(v.desc as Label).text = str(c.desc)
		var libera := _texto_recompensa(c.recompensa)
		var texto := ("Libera: " + libera) if libera != "" else ""
		(v.rec as Label).text = ("Cumprida. " + texto).strip_edges() if feita else texto


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
		return "Primeira vez aqui: entre na floresta e volte com almas."
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


func _entrar_floresta() -> void:
	get_tree().change_scene_to_file(FLORESTA)
