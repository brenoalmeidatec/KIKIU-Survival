extends Control
## Escolha de personagem da v2: a tela entre o título e o salão. Cada personagem tem um santuário próprio (v2/personagens.gd).
## À esquerda, os personagens salvos e, no fim, NOVO PERSONAGEM: escolhe um nome livre e o santuário começa zerado. À direita, o
## retrato grande, as almas, as melhorias e a arma inicial do herói (o foco na lista mostra o personagem). Escolher leva ao salão
## dele. ESC volta: da lista de nomes para a lista de personagens, e dela para o título. Botões do Godot: mouse, teclado e controle.

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
const COR_OURO := Color(1.0, 0.86, 0.42)
const COR_TEXTO := Color(0.92, 0.9, 0.96)
const COR_APAGADO := Color(0.55, 0.56, 0.64)
const COR_FOCO := Color(1.0, 0.97, 0.8)
const COR_AVISO := Color(1.0, 0.72, 0.56)
const DICA := "Setas ou analógico escolhem   Enter ou A confirma   Esc volta"

var ao_escolher := Callable()  # gancho dos testes: recebe o caminho do salão; vazio = troca a cena
var _modo := "personagens"  # ou "nomes", quando se cria um personagem
var _lista: VBoxContainer
var _retrato: TextureRect
var _nome: Label
var _info: Label
var _aviso: Label
var _sprite: Texture2D
var _quadro := Vector2(32, 44)
var _antes := {}


func _ready() -> void:
	Entrada.garantir()
	Personagens.iniciar()
	_ajustar_janela()
	set_anchors_preset(PRESET_FULL_RECT)
	_sprite = load(SPRITE + "_albedo.png") as Texture2D
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPRITE + ".json"))
	_quadro = Vector2(float(info.quadro[0]), float(info.quadro[1]))
	_montar()
	_montar_lista()


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
	var veu := ColorRect.new()
	veu.color = Color(0.02, 0.02, 0.04, 0.6)
	veu.set_anchors_preset(PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)
	add_child(_rotulo("PERSONAGENS", Dados.fonte_titulo, 56, COR_OURO, Rect2(0, 22, LARG, 60), HORIZONTAL_ALIGNMENT_CENTER))
	_lista = VBoxContainer.new()
	_lista.position = Vector2(40, 110)
	_lista.size = Vector2(380, 380)
	_lista.add_theme_constant_override("separation", 10)
	add_child(_lista)
	_retrato = TextureRect.new()
	_retrato.position = Vector2(470, 110)
	_retrato.size = Vector2(200, 200)
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_retrato)
	_nome = _rotulo("", Dados.fonte_titulo, 56, COR_OURO, Rect2(690, 110, 240, 60), HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_nome)
	_info = _rotulo("", Dados.fonte_texto, 32, COR_TEXTO, Rect2(470, 330, 460, 170), HORIZONTAL_ALIGNMENT_LEFT)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	_aviso = _rotulo("", Dados.fonte_texto, 16, COR_AVISO, Rect2(40, ALT - 78, LARG - 80, 22), HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_aviso)
	var faixa := ColorRect.new()
	faixa.color = Color(0.01, 0.02, 0.035, 0.7)
	faixa.position = Vector2(0, ALT - 42)
	faixa.size = Vector2(LARG, 42)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faixa)
	add_child(_rotulo(DICA, Dados.fonte_texto, 16, COR_APAGADO, Rect2(0, ALT - 30, LARG, 22), HORIZONTAL_ALIGNMENT_CENTER))


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


## A lista da esquerda: os personagens (modo "personagens") ou os nomes livres (modo "nomes").
func _montar_lista() -> void:
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	_aviso.text = ""
	if _modo == "nomes":
		for n in Personagens.nomes_livres():
			_novo_botao(str(n.nome), _criar.bind(n), _mostrar_nome.bind(n))
		_novo_botao("VOLTAR", _voltar_lista, _mostrar_vazio)
	else:
		for id in Personagens.lista():
			_novo_botao(Personagens.nome(id), _escolher.bind(id), _mostrar_personagem.bind(id))
		if not Personagens.nomes_livres().is_empty():
			_novo_botao("NOVO PERSONAGEM", _abrir_nomes, _mostrar_vazio)
	if _lista.get_child_count() > 0:
		_lista.get_child(0).grab_focus()
	else:
		_mostrar_vazio()


func _novo_botao(txt: String, acao: Callable, ao_focar: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(380, 56)
	_estilo_botao(b)
	b.pressed.connect(acao)
	b.focus_entered.connect(ao_focar)
	_lista.add_child(b)


# ------------------------------------------------------------------ o que aparece à direita


func _mostrar_personagem(id: String) -> void:
	var r := Personagens.resumo(id)
	_nome.text = str(r.nome)
	_definir_retrato(_pasta_do_nome(str(r.nome)), str(r.nome))
	var linhas := ["Almas: %d" % int(r.almas), "Herói: %s" % _heroi_e_arma(Personagens.heroi(id))]
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
	_info.text = "\n".join(PackedStringArray(linhas))


func _mostrar_nome(n: Dictionary) -> void:
	_nome.text = str(n.nome)
	_definir_retrato(str(n.pasta), str(n.nome))
	_info.text = "Santuário novo: sem almas e sem melhorias.\nHerói: %s." % _heroi_e_arma(Personagens.heroi_do_nome(str(n.nome)))


func _mostrar_vazio() -> void:
	_nome.text = ""
	_info.text = ""
	_definir_retrato("")


func _heroi_e_arma(heroi_id: String) -> String:
	return "%s (%s)" % [str(Herois.heroi(heroi_id).nome), Personagens.arma_inicial(heroi_id)]


func _pasta_do_nome(nome_txt: String) -> String:
	for n in Dados.json("v2_salao").get("nomes", []):
		if str(n.nome) == nome_txt:
			return str(n.pasta)
	return ""


## O retrato: o rosto do personagem (assets/personagens/<pasta>/rosto.png) quando existe; senão o quadro parado do herói.
func _definir_retrato(pasta: String, nome_txt := "") -> void:
	var rosto := "res://assets/personagens/%s/rosto.png" % pasta
	if pasta != "" and ResourceLoader.exists(rosto):
		_retrato.texture = load(rosto) as Texture2D
		return
	var folha := _sprite
	var tam := _quadro
	var propria := Personagens.sprite_do_nome(nome_txt)  # folha própria do personagem (dados/v2_salao.json "sprite")
	if propria != "":
		folha = load(Personagens.PASTA_SPRITES + propria + "_albedo.png") as Texture2D
		var info = JSON.parse_string(FileAccess.get_file_as_string(Personagens.PASTA_SPRITES + propria + ".json"))
		tam = Vector2(float(info.quadro[0]), float(info.quadro[1]))
	if folha == null:
		_retrato.texture = null
		return
	var quadro := AtlasTexture.new()
	quadro.atlas = folha
	quadro.region = Rect2(0, 0, tam.x, tam.y)
	_retrato.texture = quadro


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
