extends Control
## Salão do personagem da v2: a sala entre a escolha de personagem e a partida, e o lugar para onde a partida volta (morte, vitória
## ou abandono). O personagem anda na sala (setas, analógico ou clique). Perto de uma estrutura ou de um portal, Enter (ou A) usa:
## uma estrutura abre o painel das melhorias dela (ou o códice, nas conquistas); um portal escolhe o mapa e leva à partida. ESC volta
## à escolha de personagem. Estruturas e portais vêm de dados/v2_salao.json e de v2/mapas.gd. Desenhado em 960x540 com a janela em
## CANVAS_ITEMS, como o santuário. O desenho da sala é um só (não se redesenha); por quadro, só se mexem o personagem e as chamas.

const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const Personagens := preload("res://v2/personagens.gd")
const Entrada := preload("res://v2/entrada.gd")  # garante as ações de controle (Enter e A confirmam, ESC e B voltam)
const Pausa := preload("res://v2/pausa.tscn")
const Trilha := preload("res://v2/trilha.gd")
const ESCOLHA := "res://v2/personagens.tscn"
const FLORESTA := "res://v2/mundo.tscn"
const SPRITE := "res://prototipos/cara_nova/sprites/hazaki_samurai"  # folha (_albedo.png) e quadro (.json) do herói
const LARG := 960
const ALT := 540
const CHAO_Y := 180.0  # a parede vai do topo até aqui; os portais ficam na base dela
const ANDAR_MIN := Vector2(40, 214)
const ANDAR_MAX := Vector2(920, 505)
const VELOCIDADE := 130.0  # px/s andando
const ALCANCE := 70.0  # px entre os pés do herói e a estrutura ou portal para ele responder
const ESCALA := 2.0
const COR_OURO := Color(1.0, 0.86, 0.42)
const COR_TEXTO := Color(0.92, 0.9, 0.96)
const COR_APAGADO := Color(0.55, 0.56, 0.64)
const COR_FOCO := Color(1.0, 0.97, 0.8)
const COR_AVISO := Color(1.0, 0.72, 0.56)
const COR_ALMA := Color(0.8, 0.66, 1.0)
const COR_PAREDE := Color(0.14, 0.13, 0.17)
const COR_TIJOLO := Color(0.1, 0.095, 0.12)
const COR_CHAO := Color(0.2, 0.18, 0.16)
const COR_LINHA_CHAO := Color(0.16, 0.145, 0.13)
const COR_PEDRA := Color(0.36, 0.34, 0.38)
const COR_MOLDURA := Color(0.5, 0.47, 0.42)
const CORES_MAPA := {
	"floresta": Color(0.3, 0.62, 0.36), "laboratorio": Color(0.3, 0.68, 0.78), "cidade": Color(0.85, 0.58, 0.3), "medio": Color(0.5, 0.55, 0.8)
}
const COR_TRAVADO := Color(0.22, 0.22, 0.25)
const DICA := "Setas ou analógico andam   Enter ou A usa   Clique também   Esc volta"

var ao_entrar := Callable()  # gancho dos testes: recebe o caminho da cena da partida; vazio = troca a cena
var pausa
var _trilha
var _antes := {}  # modo de escala da janela antes desta tela (volta ao sair)
var _estruturas: Array = []  # dados/v2_salao.json: id, nome, x, y e melhorias ou conquistas
var _alvos: Array = []  # o que se usa na sala: estruturas e portais, {tipo, id, nome, acao, pos}
var _cenario: Node2D  # o chão, a parede e o que não se mexe (desenhado uma vez)
var _chamas: Node2D  # tochas e o brilho do altar (redesenhadas por quadro, são poucas)
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
var _p_nome: Label
var _p_nivel: Label
var _p_agora: Label
var _p_proximo: Label
var _p_custo: Label
var _p_saldo: Label
var _p_aviso: Label
var _p_detalhe: Label
var _p_comprar: Button
var _p_detalhes: Button
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
	set_anchors_preset(PRESET_FULL_RECT)
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


# ------------------------------------------------------------------ dados e alvos


func _carregar_dados() -> void:
	_estruturas = Dados.json("v2_salao").get("estruturas", [])
	_alvos.clear()
	for e in _estruturas:
		_alvos.append({"tipo": "estrutura", "id": str(e.id), "nome": str(e.nome), "acao": str(e.nome), "pos": Vector2(float(e.x), float(e.y))})
	for i in Mapas.LISTA.size():
		var m: Dictionary = Mapas.LISTA[i]
		var x: float = lerp(150.0, 810.0, float(i) / maxf(1.0, Mapas.LISTA.size() - 1.0))
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


func _pintar_cenario() -> void:
	_cenario.draw_rect(Rect2(0, 0, LARG, CHAO_Y), COR_PAREDE)
	for linha in 6:  # tijolos: fiadas alternadas
		var y := linha * 30.0
		_cenario.draw_line(Vector2(0, y), Vector2(LARG, y), COR_TIJOLO, 2.0)
		for col in range(-1, 33):
			var x := col * 30.0 + (15.0 if linha % 2 == 1 else 0.0)
			_cenario.draw_line(Vector2(x, y), Vector2(x, y + 30.0), COR_TIJOLO, 2.0)
	_cenario.draw_rect(Rect2(0, CHAO_Y, LARG, ALT - CHAO_Y), COR_CHAO)
	var fuga := Vector2(LARG / 2.0, CHAO_Y - 160.0)  # chão em perspectiva: as linhas se encontram atrás da parede
	for xb in range(-600, LARG + 700, 120):
		_cenario.draw_line(fuga, Vector2(xb, ALT), COR_LINHA_CHAO, 2.0)
	for k in 4:
		var y := CHAO_Y + (ALT - CHAO_Y) * pow((k + 1) / 4.0, 2.0)
		_cenario.draw_line(Vector2(0, y), Vector2(LARG, y), COR_LINHA_CHAO, 2.0)
	_cenario.draw_rect(Rect2(0, CHAO_Y - 8, LARG, 8), COR_MOLDURA)  # rodapé da parede
	for x in [0.0, LARG - 56.0]:  # colunas nas bordas
		_cenario.draw_rect(Rect2(x, 0, 56, ALT), COR_MOLDURA.darkened(0.25))
	for i in _alvos.size():
		var a: Dictionary = _alvos[i]
		if a.tipo == "portal":
			_desenhar_portal(a)
		else:
			_desenhar_estrutura(a)


func _desenhar_portal(a: Dictionary) -> void:
	var m := Mapas.buscar(str(a.id))
	var x: float = a.pos.x
	var topo := CHAO_Y - 96.0
	var fechado := Mapas.condicao(m) != ""
	var cor: Color = COR_TRAVADO if fechado else CORES_MAPA.get(str(a.id), COR_TRAVADO)
	_cenario.draw_rect(Rect2(x - 38, topo, 76, 96), COR_MOLDURA)
	_cenario.draw_circle(Vector2(x, topo), 38, COR_MOLDURA)
	_cenario.draw_rect(Rect2(x - 28, topo + 4, 56, 92), cor.darkened(0.5))
	_cenario.draw_circle(Vector2(x, topo + 4), 28, cor.darkened(0.5))
	if fechado:  # cadeado: o texto de por que está fechado aparece ao usar o portal
		_cenario.draw_rect(Rect2(x - 9, topo + 40, 18, 14), COR_APAGADO)
		_cenario.draw_rect(Rect2(x - 5, topo + 30, 10, 12), COR_APAGADO, false, 3.0)
	_cenario.draw_string(
		Dados.fonte_texto, Vector2(x - 120, CHAO_Y + 40), str(a.nome), HORIZONTAL_ALIGNMENT_CENTER, 240, 16, COR_OURO if not fechado else COR_APAGADO
	)


func _desenhar_estrutura(a: Dictionary) -> void:
	var x: float = a.pos.x
	var y: float = a.pos.y
	var cor := COR_ALMA if str(a.id) == "altar" else (Color(0.55, 0.4, 0.26) if str(a.id) == "codice" else COR_PEDRA)
	_cenario.draw_rect(Rect2(x - 36, y - 8, 72, 24), COR_MOLDURA.darkened(0.2))
	_cenario.draw_rect(Rect2(x - 30, y - 46, 60, 40), cor.darkened(0.15))
	_cenario.draw_rect(Rect2(x - 30, y - 46, 60, 6), cor)
	_cenario.draw_string(Dados.fonte_texto, Vector2(x - 110, y - 56), str(a.nome), HORIZONTAL_ALIGNMENT_CENTER, 220, 16, COR_OURO)


func _pintar_chamas() -> void:
	for i in 2:  # tochas nas paredes laterais
		var x := 90.0 if i == 0 else LARG - 90.0
		var r := 9.0 + 2.5 * sin(_tempo * 9.0 + i * 2.0)
		_chamas.draw_circle(Vector2(x, CHAO_Y - 120), r * 2.4, Color(1.0, 0.6, 0.2, 0.12))
		_chamas.draw_circle(Vector2(x, CHAO_Y - 120), r * 0.7, Color(1.0, 0.85, 0.4, 0.95))
	var altar: Dictionary = _estrutura("altar")
	if not altar.is_empty():  # brilho do altar: um anel que pulsa
		var r2 := 36.0 + 3.0 * sin(_tempo * 3.0)
		_chamas.draw_circle(Vector2(altar.x, altar.y - 52), r2, Color(0.8, 0.66, 1.0, 0.16))


func _pintar_heroi() -> void:
	_heroi.draw_circle(Vector2(0, -1), 14.0, Color(0, 0, 0, 0.3))  # sombra dos pés
	if _sprite == null:
		return
	var w := _quadro_w * ESCALA
	var h := _quadro_h * ESCALA
	_heroi.draw_texture_rect_region(_sprite, Rect2(-w / 2.0, -h + 6.0, w, h), Rect2(_quadro * _quadro_w, _dir * _quadro_h, _quadro_w, _quadro_h))


func _montar_hud() -> void:
	_nome_lbl = _rotulo(Personagens.nome(Personagens.ativo()), Dados.fonte_titulo, 37, COR_OURO, Rect2(24, 12, 420, 44), HORIZONTAL_ALIGNMENT_LEFT)
	_saldo_lbl = _rotulo("", Dados.fonte_titulo, 37, COR_ALMA, Rect2(LARG - 444, 12, 420, 44), HORIZONTAL_ALIGNMENT_RIGHT)
	_prompt = _rotulo("", Dados.fonte_texto, 16, COR_FOCO, Rect2(0, 0, 320, 22), HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.visible = false
	_aviso_lbl = _rotulo("", Dados.fonte_texto, 16, COR_AVISO, Rect2(0, ALT - 78, LARG, 22), HORIZONTAL_ALIGNMENT_CENTER)
	var faixa := ColorRect.new()
	faixa.color = Color(0.01, 0.02, 0.035, 0.7)
	faixa.position = Vector2(0, ALT - 42)
	faixa.size = Vector2(LARG, 42)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faixa)
	for l in [
		_nome_lbl,
		_saldo_lbl,
		_prompt,
		_aviso_lbl,
		_rotulo(DICA, Dados.fonte_texto, 16, COR_APAGADO, Rect2(0, ALT - 30, LARG - 200, 22), HORIZONTAL_ALIGNMENT_LEFT)
	]:
		add_child(l)
	var ajustes := Button.new()
	ajustes.text = "AJUSTES"
	ajustes.position = Vector2(LARG - 184, ALT - 38)
	ajustes.size = Vector2(164, 34)
	_estilo_botao(ajustes, 16)
	ajustes.pressed.connect(func(): pausa.abrir_ajustes())
	add_child(ajustes)


func _montar_painel() -> void:
	_painel = Control.new()
	_painel.set_anchors_preset(PRESET_FULL_RECT)
	_painel.visible = false
	add_child(_painel)
	var veu := ColorRect.new()
	veu.color = Color(0.02, 0.02, 0.04, 0.9)
	veu.set_anchors_preset(PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(veu)
	_p_titulo = _rotulo("", Dados.fonte_titulo, 56, COR_OURO, Rect2(0, 22, LARG, 60), HORIZONTAL_ALIGNMENT_CENTER)
	_painel.add_child(_p_titulo)
	_p_lista = VBoxContainer.new()
	_p_lista.position = Vector2(40, 110)
	_p_lista.size = Vector2(340, 330)
	_p_lista.add_theme_constant_override("separation", 10)
	_painel.add_child(_p_lista)
	var x := 420.0
	_p_nome = _rotulo("", Dados.fonte_titulo, 37, COR_OURO, Rect2(x, 110, 500, 44), HORIZONTAL_ALIGNMENT_LEFT)
	_p_nivel = _rotulo("", Dados.fonte_texto, 32, COR_TEXTO, Rect2(x, 160, 500, 36), HORIZONTAL_ALIGNMENT_LEFT)
	_p_agora = _rotulo("", Dados.fonte_texto, 32, COR_TEXTO, Rect2(x, 200, 500, 36), HORIZONTAL_ALIGNMENT_LEFT)
	_p_proximo = _rotulo("", Dados.fonte_texto, 32, COR_FOCO, Rect2(x, 240, 500, 36), HORIZONTAL_ALIGNMENT_LEFT)
	_p_custo = _rotulo("", Dados.fonte_texto, 32, COR_ALMA, Rect2(x, 280, 500, 36), HORIZONTAL_ALIGNMENT_LEFT)
	_p_saldo = _rotulo("", Dados.fonte_texto, 32, COR_ALMA, Rect2(x, 320, 500, 36), HORIZONTAL_ALIGNMENT_LEFT)
	_p_aviso = _rotulo("", Dados.fonte_texto, 16, COR_AVISO, Rect2(x, 364, 500, 22), HORIZONTAL_ALIGNMENT_LEFT)
	_p_detalhe = _rotulo("", Dados.fonte_texto, 16, COR_APAGADO, Rect2(x, 392, 500, 44), HORIZONTAL_ALIGNMENT_LEFT)
	_p_detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_p_detalhe.visible = false
	for l in [_p_nome, _p_nivel, _p_agora, _p_proximo, _p_custo, _p_saldo, _p_aviso, _p_detalhe]:
		_painel.add_child(l)
	_p_comprar = Button.new()
	_p_comprar.text = "COMPRAR"
	_p_comprar.position = Vector2(x, 450)
	_p_comprar.size = Vector2(220, 48)
	_estilo_botao(_p_comprar, 37)
	_p_comprar.pressed.connect(_comprar_atual)
	_painel.add_child(_p_comprar)
	_p_detalhes = Button.new()
	_p_detalhes.text = "DETALHES"
	_p_detalhes.position = Vector2(x + 240, 450)
	_p_detalhes.size = Vector2(220, 48)
	_estilo_botao(_p_detalhes, 37)
	_p_detalhes.pressed.connect(func(): _p_detalhe.visible = not _p_detalhe.visible)
	_painel.add_child(_p_detalhes)
	_painel.add_child(_rotulo("Esc fecha", Dados.fonte_texto, 16, COR_APAGADO, Rect2(0, ALT - 30, LARG, 22), HORIZONTAL_ALIGNMENT_CENTER))


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
	b.add_theme_font_override("font", Dados.fonte_titulo if tam >= 37 else Dados.fonte_texto)
	b.add_theme_font_size_override("font_size", tam)
	b.add_theme_color_override("font_color", COR_TEXTO)
	b.add_theme_color_override("font_hover_color", COR_FOCO)
	b.add_theme_color_override("font_focus_color", COR_FOCO)
	b.add_theme_color_override("font_disabled_color", COR_APAGADO)
	b.mouse_entered.connect(b.grab_focus)


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
		_quadro = 1 + int(_tempo_passo * 8.0) % 4
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
	_prompt.position = Vector2(_pos.x - 160, _pos.y - 150)


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
		var clicado := _alvo_perto(e.position, 56.0)
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
	_p_itens = _itens_da(e)
	_montar_lista()
	_p_atual = 0
	_p_detalhe.visible = false
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
	var cumpridas: Dictionary = Meta.estado().conquistas
	for i in _p_itens.size():
		var it: Dictionary = _p_itens[i]
		var b := Button.new()
		b.text = (
			("%s  %s" % [it.nome, "cumprida" if cumpridas.get(str(it.id), false) else "falta"])
			if _p_codice
			else ("%s  %d/%d" % [it.nome, Meta.nivel(str(it.id)), int(it.max)])
		)
		b.custom_minimum_size = Vector2(340, 52)
		b.clip_text = true
		_estilo_botao(b, 16)
		b.focus_entered.connect(_mostrar_item.bind(i))
		b.pressed.connect(_mostrar_item.bind(i))
		_p_lista.add_child(b)


func _mostrar_item(i: int) -> void:
	if _p_itens.is_empty():
		return
	_p_atual = i
	var it: Dictionary = _p_itens[i]
	_p_saldo.text = "Suas almas: %d" % Meta.saldo()
	_p_comprar.visible = not _p_codice
	_p_custo.visible = not _p_codice
	if _p_codice:
		_mostrar_conquista(it)
	else:
		_mostrar_melhoria(it)


func _mostrar_melhoria(m: Dictionary) -> void:
	var id := str(m.id)
	var n := Meta.nivel(id)
	var mx := int(m.max)
	_p_nome.text = str(m.nome)
	_p_nivel.text = "Nível %d de %d" % [n, mx]
	_p_agora.text = "Agora: %s" % (Meta.texto_efeito(m, n) if n > 0 else "sem efeito ainda")
	_p_proximo.text = "Nível máximo" if n >= mx else Meta.texto_proximo(m, n)
	var custo := Meta.custo_do_nivel(m, n) if n < mx else 0
	_p_custo.text = "Custo: %d almas" % custo if n < mx else ""
	_p_detalhe.text = "No nível máximo: %s." % Meta.texto_efeito(m, mx)
	_p_comprar.disabled = n >= mx or not _liberada(m) or Meta.saldo() < custo
	if not _liberada(m):
		_p_aviso.text = "Falta a conquista: %s" % _nome_conquista(str(m.requer))
	elif n < mx and Meta.saldo() < custo:
		_p_aviso.text = "Faltam %d almas." % (custo - Meta.saldo())
	else:
		_p_aviso.text = ""


func _mostrar_conquista(c: Dictionary) -> void:
	var feita := bool(Meta.estado().conquistas.get(str(c.id), false))
	_p_nome.text = str(c.nome)
	_p_nivel.text = "Cumprida" if feita else "Ainda não cumprida"
	_p_agora.text = str(c.desc)
	var item := Meta.item_da_recompensa(c.recompensa)
	_p_proximo.text = "Libera: %s" % str(item.nome) if not item.is_empty() else ""
	_p_detalhe.text = ""
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
		var it: Dictionary = _p_itens[i]
		var b: Button = _p_lista.get_child(i)
		b.text = "%s  %d/%d" % [it.nome, Meta.nivel(str(it.id)), int(it.max)]


func _fechar_painel() -> void:
	_painel.visible = false
	_p_aviso.text = ""
	_p_detalhe.visible = false


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
