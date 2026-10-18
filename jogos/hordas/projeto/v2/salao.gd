extends Control
## Salão do personagem da v2: a sala entre a escolha de personagem e a partida, e o lugar para onde a partida volta (morte, vitória
## ou abandono). O personagem anda na sala (setas, analógico ou clique). Perto de uma estrutura ou de um portal, Enter (ou A) usa:
## uma estrutura abre o painel das melhorias dela (ou o códice, nas conquistas); um portal escolhe o mapa e leva à partida. ESC volta
## à escolha de personagem. Estruturas e portais vêm de dados/v2_salao.json e de v2/mapas.gd. Desenhado em 960x540 com a janela em
## CANVAS_ITEMS, como o santuário. O desenho da sala é um só (não se redesenha); por quadro, só se mexem o personagem e as chamas.

const Visual := preload("res://v2/salao_visual.gd")
const Vivo := preload("res://v2/salao_vivo.gd")
const Paleta := preload("res://v2/paleta.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const UiJanela := preload("res://v2/ui_janela.gd")
const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const Personagens := preload("res://v2/personagens.gd")
const Entrada := preload("res://v2/entrada.gd")  # garante as ações de controle (Enter e A confirmam, ESC e B voltam)
const Pausa := preload("res://v2/pausa.tscn")
const Trilha := preload("res://v2/trilha.gd")
const Icones := preload("res://v2/icones_santuario.gd")
const Card := preload("res://v2/card_santuario.gd")
const ESCOLHA := "res://v2/personagens.tscn"
const FLORESTA := "res://v2/mundo.tscn"
const SPRITE := "res://prototipos/cara_nova/sprites/hazaki_samurai"  # folha (_albedo.png) e quadro (.json) do herói
const LARG := 960
const ALT := 540
const CHAO_Y := 180.0  # a parede vai do topo até aqui; os portais ficam na base dela
const ANDAR_MIN := Vector2(40, 214)
const ANDAR_MAX := Vector2(920, 505)
const VELOCIDADE := 208.0  # px/s andando (1,6x a da primeira sala: o santuário é passagem, não pede caminhada lenta)
const PASSOS_POR_S := 13.0  # quadros da animação de andar por segundo (sobe com a velocidade, senão o pé desliza)
const ALCANCE := 70.0  # px entre os pés do herói e a estrutura ou portal para ele responder
const ESCALA := 2.0
const COR_OURO := Paleta.OURO
const COR_TEXTO := Paleta.TEXTO
const COR_APAGADO := Paleta.TEXTO_APAGADO
const COR_FOCO := Paleta.FOCO
const COR_AVISO := Paleta.VALOR
const COR_ALMA := Paleta.ALMA
const CORES_MAPA := {
	"floresta": Color(0.3, 0.62, 0.36), "laboratorio": Color(0.3, 0.68, 0.78), "cidade": Color(0.85, 0.58, 0.3), "medio": Color(0.5, 0.55, 0.8)
}
const COR_TRAVADO := Color(0.22, 0.22, 0.25)
const DICA := "Setas / analógico: andar   Enter / A: usar   Clique: explorar"

var _visual := Visual.new()
var _p_rolagem: ScrollContainer

var ao_entrar := Callable()  # gancho dos testes: recebe o caminho da cena da partida; vazio = troca a cena
var pausa
var _trilha
var _estruturas: Array = []  # dados/v2_salao.json: id, nome, x, y e melhorias ou conquistas
var _alvos: Array = []  # o que se usa na sala: estruturas e portais, {tipo, id, nome, acao, pos}
var _cenario: Node2D  # o chão, a parede e o que não se mexe (desenhado uma vez)
var _chamas: Node2D  # tochas e o brilho do altar (redesenhadas por quadro, são poucas)
var _camadas: Array = []  # CanvasLayers da sala (fundo -3; cena -2 e brilho -1 do salao_vivo): o offset delas segue o bloco no centro do canvas
var _heroi: Node2D
var _sprite: Texture2D
var _quadro_w := 32
var _quadro_h := 44
var _pos := Vector2(480, 400)  # onde estão os pés do herói
var _dir := 0  # linha da folha de sprites: baixo, esquerda, direita, cima
var _quadro := 0  # coluna da folha: parado (0) ou um dos passos da animação (1 a 4)
var _tempo := 0.0
var _tempo_passo := 0.0
var _destino := Vector2.INF  # clique numa estrutura ou portal: anda até ele e usa
var _alvo_destino := {}
var _prompt: Label
var _prompt_de := ""
var _saldo_lbl: Label
var _aviso_lbl: Label
var _aviso_t := 0.0
var _nome_lbl: Label
# painel de uma estrutura (ou do códice): fica por cima da sala até ESC fechar
var _painel: Control
var _p_titulo: Label
var _p_lista: VBoxContainer
var _p_icone_estrutura: TextureRect
var _p_icone: TextureRect
var _p_nome: Label
var _p_frase: Label  # subtítulo de uma linha: o que o item faz, em linguagem de gente
var _p_card  # card_santuario.gd: as barrinhas (nível, efeito, custo; no códice, conquistas, meta e recompensa)
var _p_saldo: Label
var _p_aviso: Label
var _p_comprar: Button
var _p_itens: Array = []  # o que a estrutura aberta mostra (melhorias ou conquistas), na ordem da lista
var _p_atual := 0  # índice do item selecionado em _p_itens
var _p_codice := false


func _ready() -> void:
	Entrada.garantir()
	Personagens.iniciar()
	if Personagens.ativo() == "":
		process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().change_scene_to_file.call_deferred(ESCOLHA)  # sem personagem não há santuário: escolhe ou cria um
		return
	_ajustar_janela()
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # a sala recebe o clique em _unhandled_input (andar até um alvo), não a tela inteira
	_carregar_dados()
	_sprite = load(SPRITE + "_albedo.png") as Texture2D
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPRITE + ".json"))
	_quadro_w = int(info.quadro[0])
	_quadro_h = int(info.quadro[1])
	_montar_cenario()
	_montar_hud()
	_montar_painel()
	pausa = Pausa.instantiate().iniciar(null)
	pausa.sair_no_frontend = false
	add_child(pausa)
	pausa.fechou.connect(_devolver_foco)
	_trilha = Trilha.new()
	add_child(_trilha)
	_trilha.tocar("santuario")
	_atualizar_textos()


func _ajustar_janela() -> void:
	add_child(UiJanela.new().montar(self, "grande"))  # a sala 960x540 é cena, não menu: fica sempre encaixada na janela (o tamanho da interface não a encolhe); só a borda extra de janelas fora de 16:9 é chão escuro


# ------------------------------------------------------------------ dados e alvos


func _carregar_dados() -> void:
	_estruturas = Dados.json("v2_salao").get("estruturas", [])
	_alvos.clear()
	# Apenas apresentação: agrupa estações nas laterais sem alterar regras ou limites.
	for e in _estruturas:
		_alvos.append(
			{"tipo": "estrutura", "id": str(e.id), "nome": str(e.nome), "acao": str(e.nome), "pos": Visual.posicao(str(e.id), Vector2(float(e.x), float(e.y)))}
		)
	for i in Mapas.LISTA.size():
		var m: Dictionary = Mapas.LISTA[i]
		var x: float = lerp(180.0, 780.0, float(i) / maxf(1.0, Mapas.LISTA.size() - 1.0))
		_alvos.append({"tipo": "portal", "id": str(m.id), "nome": str(m.nome), "acao": str(m.entrar), "pos": Vector2(x, CHAO_Y + 8.0)})


func _estrutura(id: String) -> Dictionary:
	for e in _estruturas:
		if str(e.id) == id:
			return e
	return {}


func _alvo_perto(ponto: Vector2, raio: float) -> Dictionary:
	var melhor := {}
	var dist := raio
	for a in _alvos:
		var d: float = ponto.distance_to(a.pos)
		if d <= dist:
			dist = d
			melhor = a
	return melhor


# ------------------------------------------------------------------ montagem da sala


func _montar_cenario() -> void:
	# A sala é uma cena de 960x540 sempre encaixada na janela: numa janela fora de 16:9 o que sobra dos lados é o chão escuro dela. O chão fica
	# numa camada ABAIXO da sala (-3): o salao_vivo desenha cenário, portais e herói nas camadas -2 e -1, e um fundo opaco na camada padrão
	# tampava a sala inteira (o "santuário vazio" do #320).
	var fundo := CanvasLayer.new()
	fundo.layer = -3
	add_child(fundo)
	var borda := ColorRect.new()
	borda.color = Color("#17191f")
	borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	EscalaUi.cobrir(borda)
	fundo.add_child(borda)
	_camadas.append(fundo)
	_cenario = Node2D.new()
	_cenario.draw.connect(_pintar_cenario)
	add_child(_cenario)
	_heroi = Node2D.new()
	_heroi.draw.connect(_pintar_heroi)
	add_child(_heroi)
	_chamas = Node2D.new()
	_chamas.draw.connect(_pintar_chamas)
	add_child(_chamas)
	_cenario.queue_redraw()
	var vivo := Vivo.new()  # luz, partículas e movimento por cima da arte (v2/salao_vivo.gd)
	add_child(vivo)
	vivo.montar(self)
	_camadas.append_array([vivo._cena, vivo._glow])
	add_to_group("ui_escala")
	ui_reencaixar(EscalaUi.canvas_atual, EscalaUi.desloc_atual)


## Chamado pela UiJanela quando a janela ou a opção mudam: as camadas da sala acompanham o bloco (a Control do salão já fica nele).
func ui_reencaixar(_canvas: Vector2, desloc: Vector2) -> void:
	for c in _camadas:
		if is_instance_valid(c):
			c.offset = desloc


func _pintar_cenario() -> void:
	_visual.fundo(_cenario)
	for a in _alvos:
		if a.tipo == "portal":
			_desenhar_portal(a)
		else:
			_desenhar_estrutura(a)


func _desenhar_portal(a: Dictionary) -> void:
	var fechado := Mapas.condicao(Mapas.buscar(str(a.id))) != ""
	_visual.portal(_cenario, a, fechado, COR_TRAVADO if fechado else CORES_MAPA.get(str(a.id), COR_TRAVADO))


func _desenhar_estrutura(a: Dictionary) -> void:
	_visual.estrutura(_cenario, a)


func _pintar_chamas() -> void:
	_visual.chamas(_chamas, _tempo)


func _pintar_heroi() -> void:
	_heroi.draw_circle(Vector2(0, -1), 14.0, Color(0, 0, 0, 0.3))  # sombra dos pés
	if _sprite == null:
		return
	var w := _quadro_w * ESCALA
	var h := _quadro_h * ESCALA
	_heroi.draw_texture_rect_region(_sprite, Rect2(-w / 2.0, -h + 6.0, w, h), Rect2(_quadro * _quadro_w, _dir * _quadro_h, _quadro_w, _quadro_h))


func _montar_hud() -> void:
	var topo := ColorRect.new()
	topo.color = Paleta.alfa(Paleta.PAINEL, 0.88)
	topo.size = Vector2(LARG, 58)
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(topo)
	add_child(_rotulo("SANTUÁRIO", Dados.fonte_titulo, 37, COR_OURO, Rect2(24, 3, 230, 44), HORIZONTAL_ALIGNMENT_LEFT))
	_nome_lbl = _rotulo(Personagens.nome(Personagens.ativo()), Dados.fonte_texto, 16, COR_TEXTO, Rect2(258, 19, 330, 24), HORIZONTAL_ALIGNMENT_LEFT)
	_saldo_lbl = _rotulo("", Dados.fonte_titulo, 37, COR_ALMA, Rect2(610, 3, 326, 44), HORIZONTAL_ALIGNMENT_RIGHT)
	_prompt = _rotulo("", Dados.fonte_texto, 16, COR_FOCO, Rect2(0, 0, 440, 26), HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.add_theme_stylebox_override("normal", _caixa(Paleta.PAINEL, Paleta.BORDA))
	_prompt.visible = false
	_aviso_lbl = _rotulo("", Dados.fonte_texto, 16, COR_AVISO, Rect2(40, 455, 880, 40), HORIZONTAL_ALIGNMENT_CENTER)
	_aviso_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var faixa := ColorRect.new()
	faixa.color = Paleta.alfa(Paleta.PAINEL, 0.88)
	faixa.position = Vector2(0, 505)
	faixa.size = Vector2(LARG, 35)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faixa)
	for l in [
		_nome_lbl, _saldo_lbl, _prompt, _aviso_lbl, _rotulo(DICA, Dados.fonte_texto, 16, COR_APAGADO, Rect2(20, 511, 650, 24), HORIZONTAL_ALIGNMENT_LEFT)
	]:
		add_child(l)
	var ajustes := Button.new()
	ajustes.text = "AJUSTES"
	ajustes.position = Vector2(682, 507)
	ajustes.size = Vector2(120, 30)
	_estilo_botao(ajustes, 16)
	ajustes.pressed.connect(func(): pausa.abrir_ajustes())
	add_child(ajustes)
	var voltar := Button.new()
	voltar.text = "VOLTAR Esc/B"
	voltar.position = Vector2(810, 507)
	voltar.size = Vector2(136, 30)
	_estilo_botao(voltar, 16)
	voltar.pressed.connect(func(): get_tree().change_scene_to_file.call_deferred(ESCOLHA))
	add_child(voltar)


func _montar_painel() -> void:
	_painel = Control.new()
	_painel.set_anchors_preset(PRESET_FULL_RECT)
	_painel.visible = false
	add_child(_painel)
	var veu := ColorRect.new()
	veu.color = Paleta.alfa(Paleta.PAINEL, 0.66)
	EscalaUi.cobrir(veu)  # o véu cobre o canvas inteiro
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(veu)
	var cartao := Panel.new()
	cartao.position = Vector2(36, 26)
	cartao.size = Vector2(888, 488)
	cartao.add_theme_stylebox_override("panel", _caixa(Paleta.CARTAO, Paleta.BORDA))
	cartao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(cartao)
	_p_icone_estrutura = _caixa_icone(Rect2(56, 36, 48, 48))  # o ícone da estrutura (assets/v2/icones_santuario): 24 px a 2x
	_painel.add_child(_p_icone_estrutura)
	_p_titulo = _rotulo("", Dados.fonte_titulo, 37, COR_OURO, Rect2(112, 38, 330, 46), HORIZONTAL_ALIGNMENT_LEFT)
	_painel.add_child(_p_titulo)
	var fechar := Button.new()
	fechar.text = "VOLTAR Esc/B"
	fechar.position = Vector2(742, 42)
	fechar.size = Vector2(158, 34)
	_estilo_botao(fechar, 16)
	fechar.pressed.connect(_fechar_painel)
	_painel.add_child(fechar)
	_p_rolagem = ScrollContainer.new()
	_p_rolagem.position = Vector2(60, 100)
	_p_rolagem.size = Vector2(322, 360)
	_p_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_p_rolagem.follow_focus = true
	_painel.add_child(_p_rolagem)
	_p_lista = VBoxContainer.new()
	_p_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p_lista.add_theme_constant_override("separation", 8)
	_p_rolagem.add_child(_p_lista)
	# Direita: ícone e título do item, uma frase amigável de uma linha e o card de barrinhas. Sem bloco de texto solto nem DETALHES.
	var x := 410.0
	_p_icone = _caixa_icone(Rect2(x, 95, 48, 48))  # 24 px a 2x, igual ao cabeçalho; centrado no título
	_painel.add_child(_p_icone)
	_p_nome = _rotulo("", Dados.fonte_titulo, Paleta.TITULO_MEDIO, COR_OURO, Rect2(x + 58, 96, 428, 46), HORIZONTAL_ALIGNMENT_LEFT)
	_p_nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_p_frase = _rotulo("", Dados.fonte_texto, Paleta.TEXTO_TAMANHO, Paleta.TEXTO_SECUNDARIO, Rect2(x, 148, 486, 24), HORIZONTAL_ALIGNMENT_LEFT)
	_p_frase.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # uma linha só, sempre
	_p_card = Card.new()
	_p_card.position = Vector2(x, 178)
	_p_card.size = Vector2(486, 244)
	# O saldo fica no cabeçalho do próprio painel, ao lado do VOLTAR: o "ALMAS" da barra de cima da sala fica tapado com o painel aberto.
	_p_saldo = _rotulo("", Dados.fonte_titulo, 37, COR_ALMA, Rect2(450, 38, 274, 46), HORIZONTAL_ALIGNMENT_RIGHT)
	_p_aviso = _rotulo("", Dados.fonte_texto, 16, COR_AVISO, Rect2(x, 428, 486, 24), HORIZONTAL_ALIGNMENT_LEFT)
	_p_aviso.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for l in [_p_nome, _p_frase, _p_card, _p_saldo, _p_aviso]:
		_painel.add_child(l)
	_p_comprar = Button.new()
	_p_comprar.text = "COMPRAR"
	_p_comprar.position = Vector2(x, 460)
	_p_comprar.size = Vector2(486, 38)
	_estilo_botao(_p_comprar, 19)
	# Desligado tem de parecer desligado: sem fundo, borda e texto bem apagados (o estilo padrão de desligado tinha fundo escuro e lia como ativo).
	_p_comprar.add_theme_stylebox_override("disabled", _caixa(Color(0, 0, 0, 0), Paleta.alfa(Paleta.TEXTO_APAGADO, 0.3)))
	_p_comprar.add_theme_color_override("font_disabled_color", Paleta.alfa(COR_APAGADO, 0.5))
	_p_comprar.pressed.connect(_comprar_atual)
	_painel.add_child(_p_comprar)
	_painel.add_child(_rotulo("Selecione para consultar", Dados.fonte_texto, 16, COR_APAGADO, Rect2(60, 474, 322, 24), HORIZONTAL_ALIGNMENT_LEFT))


func _caixa_icone(r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.position = r.position
	t.size = r.size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art: sem borrão
	t.material = Card.sem_luz()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


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


func _estilo_botao(b: Button, tam: int) -> void:
	b.add_theme_font_override("font", Dados.fonte_titulo if tam >= 19 else Dados.fonte_texto)
	b.add_theme_font_size_override("font_size", tam)
	b.add_theme_color_override("font_color", COR_TEXTO)
	b.add_theme_color_override("font_hover_color", COR_FOCO)
	b.add_theme_color_override("font_focus_color", COR_FOCO)
	b.add_theme_color_override("font_disabled_color", COR_APAGADO)
	b.add_theme_stylebox_override("normal", _caixa(Paleta.CARTAO, Paleta.BORDA))
	b.add_theme_stylebox_override("hover", _caixa(Paleta.CARTAO_SELECIONADO, Paleta.OURO))
	b.add_theme_stylebox_override("focus", _caixa(Color(0, 0, 0, 0), Paleta.OURO))
	b.add_theme_stylebox_override("pressed", _caixa(Paleta.PAINEL, Paleta.OURO))
	b.add_theme_stylebox_override("disabled", _caixa(Paleta.PAINEL, Paleta.TEXTO_APAGADO))
	b.mouse_entered.connect(_focar_sob_mouse.bind(b))


func _focar_sob_mouse(b: Button) -> void:
	if b.focus_mode != Control.FOCUS_NONE:  # o COMPRAR desligado não pega foco
		b.grab_focus()


func _caixa(fundo: Color, borda: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.border_color = borda
	estilo.set_border_width_all(1)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 4
	estilo.content_margin_bottom = 4
	return estilo


# ------------------------------------------------------------------ quadro


func _process(dt: float) -> void:
	_tempo += dt
	_chamas.queue_redraw()
	if _aviso_t > 0.0:
		_aviso_t -= dt
		if _aviso_t <= 0.0:
			_aviso_lbl.text = ""
	if _painel.visible or pausa.aberto:
		return
	var anda := Input.get_vector("esquerda", "direita", "cima", "baixo")
	if anda != Vector2.ZERO:
		_destino = Vector2.INF
	elif _destino != Vector2.INF:
		if _pos.distance_to(_destino) <= ALCANCE * 0.8:  # chegou no alvo clicado: usa
			var alvo := _alvo_destino
			_destino = Vector2.INF
			_alvo_destino = {}
			_usar(alvo)
			return
		anda = _pos.direction_to(_destino)
	var andando := anda != Vector2.ZERO
	if andando:
		_pos = (_pos + anda.limit_length(1.0) * VELOCIDADE * dt).clamp(ANDAR_MIN, ANDAR_MAX)
		_dir = _linha_de(anda)
		_tempo_passo += dt
		_quadro = 1 + int(_tempo_passo * PASSOS_POR_S) % 4
	else:
		_tempo_passo = 0.0
		_quadro = 0
	_heroi.position = _pos
	_heroi.queue_redraw()
	_atualizar_prompt()


func _linha_de(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return 2 if v.x > 0.0 else 1
	return 0 if v.y > 0.0 else 3


func _atualizar_prompt() -> void:
	var perto := _alvo_perto(_pos, ALCANCE)
	_prompt.visible = not perto.is_empty()
	if perto.is_empty():
		_prompt_de = ""
		return
	if _prompt_de != str(perto.id):
		_prompt_de = str(perto.id)
		_prompt.text = "Enter ou A: %s" % perto.acao
	_prompt.position = Vector2(clampf(perto.pos.x - 220.0, 12.0, LARG - 452.0), clampf(perto.pos.y - 132.0, 62.0, 467.0))


func _unhandled_input(e: InputEvent) -> void:
	if pausa.aberto:
		return
	if _painel.visible:
		if e.is_action_pressed("ui_cancel"):
			_fechar_painel()
			get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("ui_accept"):
		var perto := _alvo_perto(_pos, ALCANCE)
		if not perto.is_empty():
			_usar(perto)
			get_viewport().set_input_as_handled()
	elif e.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file.call_deferred(ESCOLHA)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var clicado := _alvo_perto(e.position - EscalaUi.desloc_atual, 56.0)  # a sala fica no bloco, no centro do canvas
		if not clicado.is_empty():
			_destino = clicado.pos
			_alvo_destino = clicado
			get_viewport().set_input_as_handled()


func _usar(a: Dictionary) -> void:
	if a.is_empty():
		return
	if a.tipo == "portal":
		usar_portal(str(a.id))
	else:
		abrir_estrutura(str(a.id))


## Usa um portal: se estiver aberto, grava o mapa escolhido no save do personagem e leva à partida. Devolve true se foi.
func usar_portal(id: String) -> bool:
	var m := Mapas.buscar(id)
	var fechado := Mapas.condicao(m)
	if fechado != "":
		_avisar(fechado)
		return false
	if not Mapas.escolher(id):
		_avisar("Não foi possível gravar a escolha de mapa.")
		return false
	if ao_entrar.is_valid():
		ao_entrar.call(FLORESTA)
	else:
		get_tree().change_scene_to_file.call_deferred(FLORESTA)
	return true


func _avisar(txt: String) -> void:
	_aviso_lbl.text = txt
	_aviso_t = 3.0
	_p_aviso.text = txt


# ------------------------------------------------------------------ painel das estruturas


## Abre o painel de uma estrutura: as melhorias dela (com comprar), ou as conquistas no códice (só leitura).
func abrir_estrutura(id: String) -> void:
	var e := _estrutura(id)
	if e.is_empty():
		return
	_p_codice = bool(e.get("conquistas", false))
	_p_titulo.text = str(e.nome)
	_p_icone_estrutura.texture = Icones.textura(id)
	_p_itens = _itens_da(e)
	_montar_lista()
	_p_atual = 0
	_p_aviso.text = ""
	_painel.visible = true
	_mostrar_item(0)
	if _p_lista.get_child_count() > 0:
		_p_lista.get_child(0).grab_focus()


func _itens_da(e: Dictionary) -> Array:
	var itens := []
	if bool(e.get("conquistas", false)):
		itens.append_array(Meta.conquistas())
	else:
		for id in e.get("melhorias", []):
			var m := Meta.melhoria(str(id))
			if not m.is_empty() and not Meta.oculto(m):
				itens.append(m)
	return itens


func _montar_lista() -> void:
	for filho in _p_lista.get_children():
		filho.queue_free()
		_p_lista.remove_child(filho)
	for i in _p_itens.size():
		var it: Dictionary = _p_itens[i]
		var b := Button.new()
		b.text = _texto_da_lista(it)
		b.icon = Icones.textura(str(it.id))
		b.add_theme_constant_override("icon_max_width", 32)
		b.add_theme_constant_override("h_separation", 10)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.material = Card.sem_luz()  # o ícone na cor da paleta, sem a luz da sala por cima
		b.custom_minimum_size = Vector2(300, 64)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT  # texto encostado no ícone, não solto no meio do botão
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.clip_text = false
		_estilo_botao(b, 16)
		b.focus_entered.connect(_mostrar_item.bind(i))
		b.pressed.connect(_mostrar_item.bind(i))
		_p_lista.add_child(b)


func _texto_da_lista(it: Dictionary) -> String:
	if _p_codice:
		return "%s\n%s" % [it.nome, "cumprida" if Meta.estado().conquistas.get(str(it.id), false) else "falta"]
	return "%s\n%d/%d" % [it.nome, Meta.nivel(str(it.id)), int(it.max)]


func _mostrar_item(i: int) -> void:
	if _p_itens.is_empty():
		return
	_p_atual = i
	var it: Dictionary = _p_itens[i]
	_p_saldo.text = "ALMAS %d" % Meta.saldo()
	_p_comprar.visible = not _p_codice
	_p_icone.texture = Icones.textura(str(it.id))
	_p_nome.text = str(it.nome)
	# Nome comprido não quebra em duas linhas: desce para o tamanho de texto grande (o card de baixo não se mexe).
	var fonte: Font = _p_nome.get_theme_font("font")
	var cabe := fonte.get_string_size(_p_nome.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Paleta.TITULO_MEDIO).x <= _p_nome.size.x
	_p_nome.add_theme_font_size_override("font_size", Paleta.TITULO_MEDIO if cabe else Paleta.TEXTO_GRANDE)
	if _p_codice:
		_mostrar_conquista(it)
	else:
		_mostrar_melhoria(it)


func _mostrar_melhoria(m: Dictionary) -> void:
	var id := str(m.id)
	var n := Meta.nivel(id)
	var mx := int(m.max)
	var saldo := Meta.saldo()
	var liberada := _liberada(m)
	var custo := Meta.custo_do_nivel(m, n) if n < mx else 0
	_p_frase.text = str(m.get("frase", Meta.texto_efeito(m, mx)))
	var linhas := [
		{"rotulo": "NÍVEL", "valor": "%d / %d" % [n, mx], "tipo": "segmentos", "n": n, "max": mx, "cor": Paleta.OURO, "nota": ""},
		{
			"rotulo": "EFEITO",
			"valor": _valor_efeito(m, n),
			"cor_valor": Paleta.FOCO if n < mx else Paleta.OURO,
			"tipo": "barra",
			"frac": float(n) / maxf(1.0, mx),
			"fantasma": float(mini(n + 1, mx)) / maxf(1.0, mx),
			"cor": Paleta.BONUS,
			"nota": Meta.texto_efeito(m, n) if n > 0 else "Ainda sem efeito: compre o primeiro nível.",
		},
	]
	if n >= mx:
		linhas.append(
			{"rotulo": "CUSTO", "valor": "COMPLETO", "cor_valor": Paleta.OURO, "tipo": "barra", "frac": 1.0, "cor": Paleta.OURO, "nota": "Tudo comprado aqui."}
		)
	elif not liberada:
		var req := str(m.requer)
		(
			linhas
			. append(
				{
					"rotulo": "BLOQUEADA",
					"valor": "%d almas" % custo,
					"cor_valor": COR_APAGADO,
					"tipo": "barra",
					"frac": 0.0,
					"cor": COR_APAGADO,
					"nota": "Falta a conquista: %s" % _nome_conquista(req),
					"cor_nota": COR_AVISO,
					"icone": Icones.textura(req),
				}
			)
		)
	else:
		var falta := custo - saldo
		(
			linhas
			. append(
				{
					"rotulo": "CUSTO",
					"valor": "%d almas" % custo,
					"cor_valor": COR_ALMA,
					"tipo": "barra",
					"frac": float(saldo) / maxf(1.0, custo),
					"cor": COR_ALMA,
					"nota": "Você tem %d. Faltam %d." % [saldo, falta] if falta > 0 else "Você tem %d. Dá para comprar!" % saldo,
					"cor_nota": Paleta.TEXTO_SECUNDARIO if falta > 0 else Paleta.BONUS,
				}
			)
		)
	_p_card.mostrar(linhas)
	_p_comprar.disabled = n >= mx or not liberada or saldo < custo
	_p_comprar.text = "NO MÁXIMO" if n >= mx else ("BLOQUEADA" if not liberada else ("SEM ALMAS" if saldo < custo else "COMPRAR"))
	_p_comprar.focus_mode = Control.FOCUS_NONE if _p_comprar.disabled else Control.FOCUS_ALL  # o foco dourado por cima fazia o desligado parecer clicável
	if _p_comprar.disabled and _p_comprar.has_focus() and _p_atual < _p_lista.get_child_count():
		_p_lista.get_child(_p_atual).grab_focus()


## "+20 → +30": o valor de agora e o do próximo nível (só o de agora no máximo). Unidade "%" nos percentuais.
func _valor_efeito(m: Dictionary, n: int) -> String:
	var partes := str(m.desc).split("{v}")
	var antes := partes[0]
	var unidade := (partes[1] if partes.size() > 1 else "").split(" ")[0]
	var agora := "%s%s%s" % [antes, Meta._numero(m, float(m.valor) * n), unidade]
	if n >= int(m.max):
		return agora
	var seta := " → " if Dados.fonte_texto.has_char(0x2192) else " > "
	return agora + seta + "%s%s%s" % [antes, Meta._numero(m, float(m.valor) * (n + 1)), unidade]


## O que a conquista pede, curto, para o card do códice.
func _meta_da_conquista(c: Dictionary) -> String:
	match str(c.get("condicao", "")):
		"tempo":
			return "Sobreviver %d min numa partida" % roundi(float(c.get("limite", 0)) / 60.0)
		"combo":
			return "Fazer um combo de %d" % int(c.get("limite", 0))
		"venceu":
			return "Vencer o duelo contra o chefe"
	return ""


func _mostrar_conquista(c: Dictionary) -> void:
	var cumpridas: Dictionary = Meta.estado().conquistas
	var feita := bool(cumpridas.get(str(c.id), false))
	var feitas := 0
	for k in cumpridas:
		if cumpridas[k]:
			feitas += 1
	_p_frase.text = str(c.get("frase", c.desc))
	var item := Meta.item_da_recompensa(c.recompensa)
	var linhas := [
		{
			"rotulo": "CÓDICE",
			"valor": "%d / %d" % [feitas, cumpridas.size()],
			"tipo": "segmentos",
			"n": feitas,
			"max": cumpridas.size(),
			"cor": Paleta.OURO,
			"nota": "",
		},
		{
			"rotulo": "META",
			"valor": "CUMPRIDA" if feita else "FALTA",
			"cor_valor": Paleta.BONUS if feita else COR_APAGADO,
			"tipo": "barra",
			"frac": 1.0 if feita else 0.0,
			"cor": Paleta.BONUS,
			"nota": _meta_da_conquista(c),
			"cor_nota": COR_TEXTO,
		},
		{
			"rotulo": "RECOMPENSA",
			"valor": "LIBERADA" if feita else "TRANCADA",
			"cor_valor": Paleta.BONUS if feita else COR_APAGADO,
			"tipo": "",
			"nota": str(item.nome) if not item.is_empty() else "",
			"cor_nota": COR_OURO if feita else COR_TEXTO,
			"icone": Icones.textura(str(c.recompensa.get("id", ""))),
		},
	]
	_p_card.mostrar(linhas)
	_p_aviso.text = ""


func _liberada(m: Dictionary) -> bool:
	var req := str(m.get("requer", ""))
	return req == "" or bool(Meta.estado().conquistas.get(req, false))


func _nome_conquista(id: String) -> String:
	for c in Meta.conquistas():
		if str(c.id) == id:
			return str(c.nome)
	return id


## Compra a melhoria `id` com as almas do personagem ativo. Devolve true se comprou. Atualiza o saldo na tela.
func comprar_item(id: String) -> bool:
	var ok := Meta.comprar(id)
	_atualizar_textos()
	if _painel.visible and _p_itens.size() > 0:
		_mostrar_item(_p_atual)
	return ok


func _comprar_atual() -> void:
	if _p_itens.is_empty():
		return
	var m: Dictionary = _p_itens[_p_atual]
	if comprar_item(str(m.id)):
		_p_aviso.text = "Comprado: %s" % m.nome
	else:
		_p_aviso.text = _motivo_recusa(m)
	_montar_lista_niveis()


func _motivo_recusa(m: Dictionary) -> String:
	var id := str(m.id)
	if Meta.erro_save:
		return "Não foi possível gravar o save."
	if Meta.nivel(id) >= int(m.max):
		return "Já está no nível máximo."
	if not _liberada(m):
		return "Falta a conquista: %s" % _nome_conquista(str(m.requer))
	return "Faltam %d almas." % (Meta.custo_do_nivel(m, Meta.nivel(id)) - Meta.saldo())


func _montar_lista_niveis() -> void:
	for i in _p_lista.get_child_count():
		var b: Button = _p_lista.get_child(i)
		b.text = _texto_da_lista(_p_itens[i])


func _fechar_painel() -> void:
	_painel.visible = false
	_p_aviso.text = ""


## Quando os Ajustes fecham (abertos da sala), o foco volta ao painel, se ele estiver aberto.
func _devolver_foco() -> void:
	if _painel.visible and _p_lista.get_child_count() > 0:
		_p_lista.get_child(_p_atual).grab_focus()


func _atualizar_textos() -> void:
	_saldo_lbl.text = "ALMAS %d" % Meta.saldo()


## Quantas almas o personagem ativo tem (o que a tela de saldo mostra).
func saldo() -> int:
	return Meta.saldo()


## Os alvos da sala (estruturas e portais): id, tipo e nome. Para testes e para o bench.
func alvos() -> Array:
	return _alvos.map(func(a): return {"tipo": a.tipo, "id": a.id, "nome": a.nome})
