extends Control
## Seleção de herói do santuário (v2/altar.gd): uma tela por cima do santuário com os heróis lado a lado (sprite parado, nome, título,
## descrição e três números), aberta pelo botão HERÓI. Um cartão por herói; mouse (clique), teclado (setas e Enter) e controle (direcional e A)
## escolhem, ESC ou B voltam sem mudar. A escolha vai para o save da v2 (Herois.escolher -> Meta, seção [heroi]) e o sinal `escolhido(id)`
## avisa o santuário. Moldura de pedra do HUD; títulos na Jersey 10, texto na Pixelify Sans (como o resto do santuário).
## O santuário adiciona este nó DEPOIS do menu de pausa: assim o `_input` dele roda antes e o ESC fecha esta tela em vez de abrir o "Sair?".

signal escolhido(id: String)

const Herois := preload("res://v2/herois.gd")
const Sprites := preload("res://v2/sprites.gd")
const MOLDURA := preload("res://v2/hud/moldura_pedra.png")
const COR_OURO := Color(1.0, 0.86, 0.42)
const COR_TEXTO := Color(0.92, 0.9, 0.96)
const COR_APAGADO := Color(0.62, 0.63, 0.72)
const CARTAO := Vector2(280, 370)
const CARTAO_Y := 82.0
const ESCALA := 3  # o sprite parado, em pixels de tela por pixel de arte (inteiro: nada de borrar)
const ALTURA_SPRITE := 160.0
const TOPO_SPRITE := 4.0  # onde o sprite começa no cartão: a descrição (4 linhas) tem de caber acima dos números

var aberta := false
var cartoes := {}  # id -> o Button do cartão
var _voltar: Button
var _base: Dictionary  # o v2_combate.json (os números do cartão saem do cfg de cada herói)
var _marcas := {}  # id -> o Label "ESCOLHIDO"
var _sprites := Sprites.new()


func montar() -> void:
	_base = Dados.json("v2_combate")
	set_anchors_preset(PRESET_FULL_RECT)
	size = Vector2(960, 540)  # o tamanho da tela já agora: com 0x0 (o santuário ainda sem layout) o véu não cobria nada e o de trás aparecia aceso
	mouse_filter = Control.MOUSE_FILTER_STOP  # o santuário de trás não recebe clique nenhum
	visible = false
	var veu := ColorRect.new()
	veu.color = Color(0.0, 0.01, 0.02, 0.9)
	veu.set_anchors_preset(PRESET_FULL_RECT)
	veu.size = size
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)
	add_child(_rotulo("ESCOLHA O HERÓI", 56, true, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 8, 960, 56)))
	var lista := Herois.lista()
	var x0 := (960.0 - (CARTAO.x * lista.size() + 24.0 * (lista.size() - 1))) / 2.0
	var i := 0
	for h in lista:
		var c := _montar_cartao(h)
		c.position = Vector2(x0 + i * (CARTAO.x + 24.0), CARTAO_Y)
		add_child(c)
		cartoes[str(h.id)] = c
		i += 1
	_voltar = Button.new()
	_voltar.text = "VOLTAR"
	_estilo_botao(_voltar)
	_voltar.position = Vector2(380, 460)  # logo abaixo dos cartões (acabam em 452) e acima da dica
	_voltar.size = Vector2(200, 40)
	_voltar.pressed.connect(fechar)
	add_child(_voltar)
	add_child(_rotulo("Setas ou direcional escolhem   Enter ou A confirma   ESC ou B volta", 14, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 530, 960, 14)))
	_vizinhos(lista)


func _montar_cartao(h: Dictionary) -> Button:
	var b := Button.new()
	b.size = CARTAO
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _moldura(Color(0.8, 0.82, 0.9)))
	b.add_theme_stylebox_override("hover", _moldura(Color(1.0, 0.95, 0.75)))
	b.add_theme_stylebox_override("focus", _moldura(COR_OURO))
	b.add_theme_stylebox_override("pressed", _moldura(Color(0.65, 0.65, 0.75)))
	b.pressed.connect(_pegar.bind(str(h.id)))
	var id := str(h.id)
	b.add_child(_sprite_do(id))
	var y := TOPO_SPRITE + ALTURA_SPRITE
	b.add_child(_rotulo(str(h.nome).to_upper(), 37, true, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, y, CARTAO.x, 36)))
	b.add_child(_rotulo(str(h.titulo), 14, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, y + 36, CARTAO.x, 16)))
	var desc := _rotulo(str(h.desc), 14, false, COR_TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(14, y + 56, CARTAO.x - 28, 68), true)
	b.add_child(desc)
	var nums := Herois.numeros(id, _base)
	for k in nums.size():
		var par: Array = nums[k]
		var yy := CARTAO.y - 22.0 - 20.0 * (nums.size() - k)
		b.add_child(_rotulo(str(par[0]), 14, false, COR_APAGADO, HORIZONTAL_ALIGNMENT_LEFT, Rect2(18, yy, 140, 16)))
		b.add_child(_rotulo(str(par[1]), 14, false, COR_TEXTO, HORIZONTAL_ALIGNMENT_RIGHT, Rect2(CARTAO.x - 118, yy, 100, 16)))
	var marca := _rotulo("ESCOLHIDO", 14, false, COR_OURO, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, CARTAO.y - 22, CARTAO.x, 16))
	marca.visible = false
	b.add_child(marca)
	_marcas[id] = marca
	return b


## O sprite parado do herói (de frente), recortado no que tem desenho e com os pés alinhados embaixo da área do sprite.
func _sprite_do(id: String) -> TextureRect:
	var t: Dictionary = _sprites.tipo(Herois.sprite(id))
	var q := Rect2i(0, 0, int(t.w), int(t.h))  # linha 0 (de frente), coluna 0 (parado)
	var usado := (t.alb as ImageTexture).get_image().get_region(q).get_used_rect()
	var at := AtlasTexture.new()
	at.atlas = t.alb
	at.region = Rect2(usado.position, usado.size)
	var r := TextureRect.new()
	r.texture = at
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2(usado.size) * ESCALA
	r.position = Vector2((CARTAO.x - r.size.x) / 2.0, TOPO_SPRITE + ALTURA_SPRITE - r.size.y)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A navegação fica DENTRO desta tela (os botões do santuário de trás continuam na árvore, e a busca de foco por geometria os acharia).
func _vizinhos(lista: Array) -> void:
	var ids: Array = []
	for h in lista:
		ids.append(str(h.id))
	for k in ids.size():
		var c: Button = cartoes[ids[k]]
		var esq: Button = cartoes[ids[maxi(k - 1, 0)]]
		var dir: Button = cartoes[ids[mini(k + 1, ids.size() - 1)]]
		c.focus_neighbor_left = c.get_path_to(esq)
		c.focus_neighbor_right = c.get_path_to(dir)
		c.focus_neighbor_top = c.get_path_to(c)
		c.focus_neighbor_bottom = c.get_path_to(_voltar)
		c.focus_next = c.get_path_to(dir)
		c.focus_previous = c.get_path_to(esq)
	var meio: Button = cartoes[ids[ids.size() / 2]]
	_voltar.focus_neighbor_top = _voltar.get_path_to(meio)
	_voltar.focus_neighbor_bottom = _voltar.get_path_to(_voltar)
	_voltar.focus_neighbor_left = _voltar.get_path_to(_voltar)
	_voltar.focus_neighbor_right = _voltar.get_path_to(_voltar)


# ------------------------------------------------------------------ abrir, escolher, fechar


func abrir() -> void:
	if aberta:
		return
	aberta = true
	visible = true
	_marcar()
	(cartoes[Herois.escolhido()] as Button).grab_focus()


func fechar() -> void:
	if not aberta:
		return
	aberta = false
	visible = false


## Escolhe o herói `id`: grava no save, fecha e avisa o santuário.
func _pegar(id: String) -> void:
	if Herois.escolher(id):
		escolhido.emit(id)
	fechar()


func _marcar() -> void:
	var atual := Herois.escolhido()
	for id in cartoes:
		(_marcas[id] as Label).visible = id == atual


func _input(e: InputEvent) -> void:
	if not aberta:
		return
	var sair := e.is_action_pressed("ui_cancel")
	if e is InputEventKey:
		sair = sair or (e.pressed and not e.echo and e.keycode == KEY_ESCAPE)
	elif e is InputEventJoypadButton:
		sair = sair or (e.pressed and e.button_index == JOY_BUTTON_START)
	if sair:
		fechar()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ visual


func _rotulo(txt: String, tam: int, titulo: bool, cor: Color, alin: HorizontalAlignment, r: Rect2, quebra := false) -> Label:
	var l := Label.new()
	if quebra:  # a quebra vem ANTES do texto e do tamanho: depois, a largura do rótulo fica a do texto inteiro (uma linha só)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = txt
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = alin
	l.add_theme_font_override("font", Dados.fonte_titulo if titulo else Dados.fonte_texto)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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
	b.add_theme_font_size_override("font_size", 37)
	b.add_theme_stylebox_override("normal", _moldura(Color(0.8, 0.82, 0.9)))
	b.add_theme_stylebox_override("hover", _moldura(COR_OURO))
	b.add_theme_stylebox_override("focus", _moldura(COR_OURO))
	b.add_theme_stylebox_override("pressed", _moldura(Color(0.6, 0.6, 0.7)))
	b.add_theme_color_override("font_color", COR_OURO)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.8))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.97, 0.8))
