extends Control
## Escolha de personagem da v2: a tela entre o título e o salão. Cada personagem tem um santuário próprio (v2/personagens.gd).
## À esquerda, os personagens salvos e, no fim, NOVO PERSONAGEM: escolhe um nome livre e o santuário começa zerado. À direita, o
## retrato grande, as almas, as melhorias e a arma inicial do herói (o foco na lista mostra o personagem). Escolher leva ao salão
## dele. ESC volta: da lista de nomes para a lista de personagens, e dela para o título. Botões do Godot: mouse, teclado e controle.

const EscalaUi := preload("res://v2/escala_ui.gd")
const UiJanela := preload("res://v2/ui_janela.gd")
const Mapas := preload("res://v2/mapas.gd")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const Herois := preload("res://v2/herois.gd")
const Entrada := preload("res://v2/entrada.gd")  # garante as ações de controle (Enter e A confirmam, ESC e B voltam)
const SALAO := "res://v2/salao.tscn"
const TITULO := "res://v2/menu_principal.tscn"
const FUNDO := preload("res://assets/titulo/fundo.png")
const MOLDURA := preload("res://v2/hud/moldura_pedra.png")
const SPRITE := "res://prototipos/cara_nova/sprites/hazaki_samurai"  # sem rosto, o retrato é o quadro parado do herói
const LARG := 960
const ALT := 540
const COL_X := 36  # coluna da lista (x 36-416)
const COL_L := 380
const FICHA_X := 440  # coluna da ficha, 24 px depois da lista, até a margem direita (x 924)
const FICHA_L := 484
const FICHA_EIXO := 682  # centro da ficha: retrato, nome e linhas
const TOPO := 100
const FUNDO_Y := 490  # os controles terminam 8 px acima do início do rodapé (498)
const PEDRA := 5  # espessura da moldura de pedra: o conteúdo da ficha fica dentro dela (y 105 a 485)
# A ficha empilha, de cima para baixo: nome (61 = linha do Jersey 56, que mede 60 a 60,8 conforme a escala da janela), retrato, linhas
# (2 de 32 px) e detalhe (até 6 de 16 px, o pior caso). Soma 377 px, dentro do miolo da pedra (380).
const NOME_Y := TOPO + PEDRA
const NOME_ALT := 61
const RETRATO_Y := NOME_Y + NOME_ALT
const RETRATO_ALT := 132  # o herói parado (32x44) sai em 3x (96x132); o rosto (52x52) segue em 2x
const INFO_Y := RETRATO_Y + RETRATO_ALT
const INFO_ALT := 70
const DETALHE_Y := INFO_Y + INFO_ALT
const DETALHE_ALT := 114
const Paleta := preload("res://v2/paleta.gd")
const COR_OURO := Color(1.0, 0.86, 0.42)
const COR_TEXTO := Color(0.92, 0.9, 0.96)
const COR_APAGADO := Color(0.55, 0.56, 0.64)
const COR_FOCO := Color(1.0, 0.97, 0.8)
const COR_AVISO := Color(1.0, 0.72, 0.56)
const Glifos := preload("res://v2/glifos.gd")

var ao_escolher := Callable()  # gancho dos testes: recebe o caminho do salão; vazio = troca a cena
var _modo := "personagens"  # ou "nomes", quando se cria um personagem
var _lista: VBoxContainer
var _retrato: TextureRect
var _nome: Label
var _info: Label
var _detalhe: Label
var _aviso: Label
var _sprite: Texture2D
var _quadro := Vector2(32, 44)


func _ready() -> void:
	Entrada.garantir()
	Personagens.iniciar()
	_ajustar_janela()
	_sprite = load(SPRITE + "_albedo.png") as Texture2D
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPRITE + ".json"))
	_quadro = Vector2(float(info.quadro[0]), float(info.quadro[1]))
	_montar()
	_montar_lista()


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
	var veu := ColorRect.new()
	veu.color = Color(0.02, 0.02, 0.04, 0.6)
	EscalaUi.cobrir(veu)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)
	add_child(_rotulo("PERSONAGENS", Dados.fonte_titulo, 56, COR_OURO, Rect2(0, 22, LARG, 60), HORIZONTAL_ALIGNMENT_CENTER))
	# Grade (DESIGN.md §1b): margem de 36, coluna da esquerda 36-416, a da direita 24 depois (440-924), tudo entre y 100 e y 490
	# (o rodapé de teclas começa em 498). A lista rola quando tem mais botões do que cabem; o foco puxa a rolagem.
	var rolagem := ScrollContainer.new()
	rolagem.position = Vector2(COL_X, TOPO)
	rolagem.size = Vector2(COL_L, FUNDO_Y - TOPO)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rolagem.follow_focus = true
	add_child(rolagem)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	rolagem.add_child(_lista)
	var painel := Panel.new()
	painel.position = Vector2(FICHA_X, TOPO)
	painel.size = Vector2(FICHA_L, FUNDO_Y - TOPO)
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_theme_stylebox_override("panel", _moldura())
	add_child(painel)
	_retrato = TextureRect.new()  # posição e tamanho vêm de _definir_retrato (escala inteira, centrado no eixo da ficha)
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_SCALE
	_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_retrato)
	_nome = _rotulo("", Dados.fonte_titulo, 56, COR_OURO, Rect2(FICHA_X + 16, NOME_Y, FICHA_L - 32, NOME_ALT), HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_nome)
	_info = _rotulo("", Dados.fonte_texto, 32, COR_TEXTO, Rect2(FICHA_X + 16, INFO_Y, FICHA_L - 32, INFO_ALT), HORIZONTAL_ALIGNMENT_CENTER)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.clip_text = true
	add_child(_info)
	_detalhe = _rotulo("", Dados.fonte_texto, 16, COR_TEXTO, Rect2(FICHA_X + 16, DETALHE_Y, FICHA_L - 32, DETALHE_ALT), HORIZONTAL_ALIGNMENT_CENTER)
	_detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalhe.clip_text = true
	add_child(_detalhe)
	# entre o título e a ficha (y 80 a 100): dentro da ficha, o detalhe de 6 linhas (até y 481) ocuparia o lugar do aviso
	_aviso = _rotulo("", Dados.fonte_texto, 16, COR_AVISO, Rect2(0, 80, LARG, 20), HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_aviso)
	var faixa := ColorRect.new()
	faixa.color = Color(0.01, 0.02, 0.035, 0.7)
	faixa.position = Vector2(0, ALT - 42)
	faixa.size = Vector2(LARG, 42)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faixa)
	var dica := Glifos.dica(
		func() -> Array: return [["navegar", "Escolher"], ["confirmar", "Confirmar"], ["voltar", "Voltar"]], HORIZONTAL_ALIGNMENT_CENTER, COR_APAGADO
	)
	dica.position = Vector2(0, ALT - 30)  # rodapé (DESIGN.md §1b): caixa de 22 px a 8 px da borda
	dica.size = Vector2(LARG, 22)
	add_child(dica)


func _rotulo(txt: String, fonte: Font, tam: int, cor: Color, r: Rect2, alin: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = alin
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3 if tam >= 37 else 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _estilo_botao(b: Button) -> void:
	b.add_theme_font_override("font", Dados.fonte_titulo)
	b.add_theme_font_size_override("font_size", 37)
	b.add_theme_color_override("font_color", COR_TEXTO)
	b.add_theme_color_override("font_hover_color", COR_FOCO)
	b.add_theme_color_override("font_focus_color", COR_FOCO)
	b.mouse_entered.connect(b.grab_focus)
	b.add_theme_stylebox_override("focus", _foco())


## Foco: borda ouro de 2 px por DENTRO da caixa do botão, como o do salão. O tema padrão desenha a borda 2 px para fora, e a
## rolagem da lista cortava essa parte (topo e laterais do primeiro botão, base do último).
func _foco() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_border_width_all(2)
	s.border_color = Paleta.OURO
	return s


## A lista da esquerda: os personagens (modo "personagens") ou os nomes livres (modo "nomes").
func _montar_lista() -> void:
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	_aviso.text = ""
	if _modo == "nomes":
		for n in Personagens.nomes_livres():
			_novo_botao(str(n.nome), _criar.bind(n), _mostrar_nome.bind(n))
		_novo_botao("VOLTAR", _voltar_lista, _mostrar_texto.bind("Volta à lista de personagens."))
	else:
		for id in Personagens.lista():
			_novo_botao(Personagens.nome(id), _escolher.bind(id), _mostrar_personagem.bind(id))
		if not Personagens.nomes_livres().is_empty():
			_novo_botao("NOVO PERSONAGEM", _abrir_nomes, _mostrar_texto.bind("Cria um personagem com um dos nomes livres."))
	if _lista.get_child_count() > 0:
		_lista.get_child(0).grab_focus()
	else:
		_mostrar_texto()


func _novo_botao(txt: String, acao: Callable, ao_focar: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 42)
	_estilo_botao(b)
	b.pressed.connect(acao)
	b.focus_entered.connect(ao_focar)
	_lista.add_child(b)


# ------------------------------------------------------------------ o que aparece à direita


func _mostrar_personagem(id: String) -> void:
	var r := Personagens.resumo(id)
	_nome.text = str(r.nome)
	_definir_retrato(_pasta_do_nome(str(r.nome)))
	_info.text = "Almas: %d\nHerói: %s" % [int(r.almas), _heroi_e_arma(Personagens.heroi(id))]
	var linhas := []
	var efeitos := []
	var niveis := Personagens.niveis(id)
	for m in Meta.melhorias_visiveis():
		var n := int(niveis.get(str(m.id), 0))
		if n > 0:
			efeitos.append("- " + Meta.texto_efeito(m, n))
	linhas.append("Melhorias: nenhuma ainda" if efeitos.is_empty() else "Melhorias:")
	linhas.append_array(efeitos.slice(0, 4))
	if str(r.mapa) != "":
		linhas.append("Último mapa: %s" % Mapas.buscar(str(r.mapa)).nome)
	_detalhe.text = "\n".join(PackedStringArray(linhas))


func _mostrar_nome(n: Dictionary) -> void:
	_nome.text = str(n.nome)
	_definir_retrato(str(n.pasta))
	_info.text = "Herói: %s" % _heroi_e_arma(Personagens.heroi_do_nome(str(n.nome)))
	_detalhe.text = "Santuário novo: sem almas e sem melhorias."


## Sem personagem na ficha: a ficha fica vazia; só o texto de ajuda do botão com o foco aparece.
func _mostrar_texto(txt := "") -> void:
	_nome.text = ""
	_info.text = ""
	_detalhe.text = txt
	_definir_retrato("", false)


func _heroi_e_arma(heroi_id: String) -> String:
	return "%s (%s)" % [str(Herois.heroi(heroi_id).nome), Personagens.arma_inicial(heroi_id)]


func _pasta_do_nome(nome_txt: String) -> String:
	for n in Dados.json("v2_salao").get("nomes", []):
		if str(n.nome) == nome_txt:
			return str(n.pasta)
	return ""


## O retrato: o rosto do personagem (assets/personagens/<pasta>/rosto.png) quando existe; senão o quadro parado do herói. O
## rosto.png é uma TIRA de quadros quadrados (altura x altura, 27 quadros): o retrato é só o primeiro, nunca a tira inteira.
## A escala é inteira (pixel art nítida) e a imagem fica centrada no eixo da ficha, dentro da caixa RETRATO_ALT.
func _definir_retrato(pasta: String, visivel := true) -> void:
	var tex: Texture2D = null
	var rosto := "res://assets/personagens/%s/rosto.png" % pasta
	if pasta != "" and ResourceLoader.exists(rosto):
		var tira := load(rosto) as Texture2D
		if tira != null:
			tex = _quadro_de(tira, Rect2(0, 0, tira.get_height(), tira.get_height()))
	elif _sprite != null:
		tex = _quadro_de(_sprite, Rect2(0, 0, _quadro.x, _quadro.y))
	_retrato.visible = visivel and tex != null
	_retrato.texture = tex
	if tex == null:
		return
	var esc := maxi(1, int(floor(float(RETRATO_ALT) / tex.get_height())))
	_retrato.size = tex.get_size() * esc
	_retrato.position = Vector2(FICHA_EIXO - _retrato.size.x / 2.0, RETRATO_Y + (RETRATO_ALT - _retrato.size.y) / 2.0)


func _quadro_de(atlas: Texture2D, regiao: Rect2) -> AtlasTexture:
	var quadro := AtlasTexture.new()
	quadro.atlas = atlas
	quadro.region = regiao
	return quadro


## Moldura 9-patch de pedra do HUD (20x20, margem de 5 px), como a do santuário.
func _moldura() -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = MOLDURA
	s.texture_margin_left = 5
	s.texture_margin_top = 5
	s.texture_margin_right = 5
	s.texture_margin_bottom = 5
	s.modulate_color = Paleta.MOLDURA_ESCURA
	return s


# ------------------------------------------------------------------ ações


func _escolher(id: String) -> void:
	if not Personagens.ativar(id):
		_aviso.text = "Não foi possível abrir este personagem."
		return
	_ir_ao_salao()


func _criar(n: Dictionary) -> void:
	var id := Personagens.criar(str(n.nome), Personagens.heroi_do_nome(str(n.nome)))
	if id == "" or not Personagens.ativar(id):
		_aviso.text = "Não foi possível gravar o personagem. Tente de novo."
		return
	_ir_ao_salao()


func _abrir_nomes() -> void:
	_modo = "nomes"
	_montar_lista()


func _voltar_lista() -> void:
	_modo = "personagens"
	_montar_lista()


func _ir_ao_salao() -> void:
	if ao_escolher.is_valid():
		ao_escolher.call(SALAO)
	else:
		get_tree().change_scene_to_file.call_deferred(SALAO)


func _unhandled_input(e: InputEvent) -> void:
	if not e.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _modo == "nomes":
		_voltar_lista()
	else:
		get_tree().change_scene_to_file.call_deferred(TITULO)
