extends CanvasLayer
## Menu de pausa da v2 (camada 14, acima de tudo). Na partida, ESC ou Start pausam o mundo (get_tree().paused) e abrem o menu;
## ESC, Start, B ou "Continuar" fecham. Opções: Continuar; Gráficos (Sombras, Partículas e Mostrar FPS, lidos e gravados pelo Config:
## g_definir e definir; a v2 reage ao graficos_mudou); Volume (Música e Efeitos, as mesmas chaves da v1); Voltar ao santuário (com
## confirmação: a partida conta como abandonada, pelo caminho da morte, combate.abandonar -> partida_terminou com venceu = false);
## e Sair do jogo (com confirmação). Sair é o ÚNICO caminho que fecha o jogo; ao_sair é o gancho que os testes trocam.
## No santuário (altar.gd, sem mundo) o ESC só abre a confirmação de sair. Perder o foco da janela pausa a partida (opção
## pausar_fora da v1; não vale em headless). Criada pelo mundo.gd (uma linha no _ready) e pelo altar.gd.
## Fontes (regra de v2/LEIA-ME.md): título e botões na Jersey 10 (Dados.fonte_titulo), valores e apoio na Pixelify Sans
## (Dados.fonte_texto), e o contador de fps na Press Start 2P (Dados.fonte, HUD). Cada uso escolhe a sua em _rotulo.
## Os botões são desenhados e testados por retângulo: o SubViewport da partida não entrega mouse aos Controls (ver resultado_meta.gd).

const MOLDURA := preload("res://v2/hud/moldura_pedra.png")
const TAM_TITULO := 56  # grade da Jersey 10 (56, 37, 19; ver v2/LEIA-ME.md)
const TAM_BOTAO := 19  # botões do menu (Jersey 10 na grade de 19; 37 estourava a largura do painel)
const TAM_VALOR := 14  # Pixelify Sans: valor à direita (com 19 encostava no nome da linha)
const TAM_DICA := 14
const LARG := 960.0
const ALT := 540.0
const PAINEL := Rect2(290, 70, 380, 400)
const LINHA0 := 118.0  # primeira linha, a partir do topo do painel
const LINHA_H := 50.0
const LINHA_ALT := 44.0  # altura da faixa de cada linha
const LINHAS_MAX := 5
const COR_OURO := Color(1.0, 0.86, 0.42)
const COR_TEXTO := Color(0.92, 0.9, 0.96)
const COR_FUNDO := Color(0.004, 0.012, 0.043, 0.72)  # #01030b a 0,7 (hud_menus.md, seção 4)
const DICA := "Setas escolhem   Enter confirma   Esc volta"
const STEPPERS := ["sombras", "particulas", "fps", "musica", "efeitos"]  # linhas que mudam de valor (esquerda e direita também valem)

var mundo  # a partida (mundo.gd); null no santuário
var mouse_fn := Callable()  # mouse em 960x540 (o Apresentacao da partida); vazio = mouse da janela (santuário)
var ao_sair := Callable()  # "Sim" em Sair do jogo; vazio = get_tree().quit()
var aberto := false
var tela := "menu"
var sel := 0
var _origem := "menu"  # para onde "Não" de uma confirmação volta; "" = fecha (santuário, sem menu por trás)
var _itens_atuais: Array = []
var _raiz: Control
var _titulo: Label
var _sub: Label
var _dica: Label
var _linhas: Array = []  # uma por linha possível: {linha, marca, rotulo, valor}
var _fps: Label
var _fps_t := 0.0


## Liga o menu à partida (m = mundo.gd) ou ao santuário (null). Chamado antes de entrar na árvore.
func iniciar(m) -> Node:
	mundo = m
	if mundo != null:
		mouse_fn = Callable(mundo.ap, "mouse_na_tela")
	return self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # com a árvore pausada, o menu continua recebendo entrada e desenhando
	layer = 14
	_montar()
	_desenhar()


func _montar() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.visible = false
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fundo)
	var painel := Panel.new()
	painel.position = PAINEL.position
	painel.size = PAINEL.size
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caixa := StyleBoxTexture.new()
	caixa.texture = MOLDURA
	caixa.texture_margin_left = 5
	caixa.texture_margin_top = 5
	caixa.texture_margin_right = 5
	caixa.texture_margin_bottom = 5
	painel.add_theme_stylebox_override("panel", caixa)
	_raiz.add_child(painel)
	_titulo = _rotulo(Dados.fonte_titulo, TAM_TITULO, COR_OURO, Vector2(PAINEL.position.x, PAINEL.position.y + 18), PAINEL.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_raiz.add_child(_titulo)
	_sub = _rotulo(Dados.fonte_texto, TAM_DICA, COR_TEXTO, Vector2(PAINEL.position.x + 12, PAINEL.position.y + 88), PAINEL.size.x - 24, HORIZONTAL_ALIGNMENT_CENTER)
	_raiz.add_child(_sub)
	_dica = _rotulo(Dados.fonte_texto, TAM_DICA, COR_TEXTO, Vector2(PAINEL.position.x + 8, PAINEL.position.y + PAINEL.size.y - 26), PAINEL.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
	_raiz.add_child(_dica)
	for i in LINHAS_MAX:
		var w := PAINEL.size.x - 48
		var h := LINHA_ALT
		var linha := Control.new()
		linha.position = Vector2(PAINEL.position.x + 24, PAINEL.position.y + LINHA0 + i * LINHA_H)
		linha.size = Vector2(w, h)
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var est := StyleBoxFlat.new()
		est.bg_color = Color(COR_OURO.r, COR_OURO.g, COR_OURO.b, 0.14)
		est.border_color = COR_OURO
		est.set_border_width_all(2)
		est.set_corner_radius_all(0)
		var marca := Panel.new()
		marca.set_anchors_preset(Control.PRESET_FULL_RECT)
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marca.add_theme_stylebox_override("panel", est)
		linha.add_child(marca)
		var rot := _rotulo(Dados.fonte_titulo, TAM_BOTAO, COR_TEXTO, Vector2(12, 6), w - 24, HORIZONTAL_ALIGNMENT_LEFT)
		linha.add_child(rot)
		var val := _rotulo(Dados.fonte_texto, TAM_VALOR, COR_TEXTO, Vector2(12, 8), w - 24, HORIZONTAL_ALIGNMENT_RIGHT)
		linha.add_child(val)
		_raiz.add_child(linha)
		_linhas.append({"linha": linha, "marca": marca, "rotulo": rot, "valor": val})
	_fps = _rotulo(Dados.fonte, 8, Color(1, 1, 1, 0.92), Vector2(6, ALT - 16), 200.0, HORIZONTAL_ALIGNMENT_LEFT)  # HUD: Press Start 2P
	_fps.visible = false
	add_child(_fps)  # fora de _raiz: o contador de fps aparece também com o menu fechado


## Um rótulo do menu. A fonte entra por parâmetro (Dados.fonte_titulo, fonte_texto ou fonte) e cada uso escolhe a sua.
func _rotulo(fonte: Font, tam: int, cor: Color, pos: Vector2, ancho: float, alin: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(ancho, tam + 12)
	l.horizontal_alignment = alin
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 3)
	return l


# ------------------------------------------------------------------ abrir e fechar


## Abre o menu sobre a partida e para o mundo. Só com o jogo rolando (não na escolha, no baú, na morte, na vitória nem no resultado).
func pausar() -> void:
	if mundo == null or aberto or not _pode_pausar():
		return
	aberto = true
	_raiz.visible = true
	_ir("menu")
	get_tree().paused = true


## Fecha o menu e despausa a partida (no santuário não há pausa para tirar).
func fechar() -> void:
	if not aberto:
		return
	aberto = false
	_raiz.visible = false
	if mundo != null:
		get_tree().paused = false


## Santuário (sem mundo): o ESC abre direto a confirmação de sair.
func abrir_sair() -> void:
	if aberto:
		return
	aberto = true
	_raiz.visible = true
	_ir("confirmar_sair", "")


func _pode_pausar() -> bool:
	var c = mundo.combate
	return c != null and c.jogo == "jogando" and not c.pausado


func _ir(nova: String, origem := "menu") -> void:
	tela = nova
	_origem = origem
	sel = 1 if nova.begins_with("confirmar") else 0  # confirmação começa em "Não"
	_desenhar()


func _voltar_tela() -> void:
	if tela == "menu":
		fechar()
	elif tela == "graficos" or tela == "volume":
		_ir("menu")
	else:
		_executar("nao", 0)


# ------------------------------------------------------------------ entrada


func _input(e: InputEvent) -> void:
	if not aberto:
		if _pede_menu(e):
			get_viewport().set_input_as_handled()
			if mundo == null:
				abrir_sair()
			else:
				pausar()
		return
	get_viewport().set_input_as_handled()  # aberto: o menu come a entrada (o mundo já está parado; no santuário, os botões de trás não recebem)
	if e is InputEventMouseMotion:
		var i := _linha_sob_mouse()
		if i >= 0 and i != sel:
			sel = i
			_som_cursor()
			_desenhar()
	elif e is InputEventMouseButton and not e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
		# o clique age ao SOLTAR: quem fecha a pausa com o mouse não manda o golpe do herói (o golpe é no aperto, em heroi.gd)
		var j := _linha_sob_mouse()
		if j >= 0:
			sel = j
			_acao_sel(1 if e.button_index == MOUSE_BUTTON_LEFT else -1, e.button_index == MOUSE_BUTTON_LEFT)
	elif e is InputEventJoypadMotion:
		pass  # o analógico não navega (cada quadro com o analógico acima do limite contaria como um aperto); o direcional do controle navega
	elif _pede_menu(e) or e.is_action_pressed("ui_cancel"):
		_voltar_tela()
	elif e.is_action_pressed("ui_up"):
		_mover(-1)
	elif e.is_action_pressed("ui_down"):
		_mover(1)
	elif e.is_action_pressed("ui_left"):
		_acao_sel(-1, false)
	elif e.is_action_pressed("ui_right"):
		_acao_sel(1, false)
	elif e.is_action_pressed("ui_accept"):
		_acao_sel(1, true)


## ESC (tecla) ou Start do controle: os dois pausam e, com o menu aberto, voltam como o ui_cancel (B).
func _pede_menu(e: InputEvent) -> bool:
	if e is InputEventKey:
		return e.pressed and not e.echo and e.keycode == KEY_ESCAPE
	if e is InputEventJoypadButton:
		return e.pressed and e.button_index == JOY_BUTTON_START
	return false


func _mover(d: int) -> void:
	if _itens_atuais.is_empty():
		return
	sel = posmod(sel + d, _itens_atuais.size())
	_som_cursor()
	_desenhar()


## Aciona a linha selecionada. Linha que muda valor (STEPPERS) recebe o passo (+1 ou -1); as outras só com confirmar.
func _acao_sel(passo: int, confirmar: bool) -> void:
	if _itens_atuais.is_empty():
		return
	var id: String = _itens_atuais[sel].id
	if id in STEPPERS:
		_executar(id, passo)
	elif confirmar:
		_som_ok()
		_executar(id, 0)


func _linha_sob_mouse() -> int:
	var m := _mouse()
	for i in _itens_atuais.size():
		var r := Rect2(PAINEL.position.x + 24, PAINEL.position.y + LINHA0 + i * LINHA_H, PAINEL.size.x - 48, LINHA_ALT)
		if r.has_point(m):
			return i
	return -1


func _mouse() -> Vector2:
	if mouse_fn.is_valid():
		return mouse_fn.call()
	return get_viewport().get_mouse_position()


# ------------------------------------------------------------------ ações


func _executar(id: String, passo: int) -> void:
	match id:
		"continuar":
			fechar()
		"graficos":
			_ir("graficos")
		"volume":
			_ir("volume")
		"voltar":
			_ir("menu")
		"santuario":
			_ir("confirmar_santuario")
		"sair":
			_ir("confirmar_sair")
		"nao":
			if _origem == "":
				fechar()
			else:
				_ir(_origem)
		"ok_santuario":
			_voltar_santuario()
		"ok_sair":
			_sair()
		"sombras":
			_girar_opcao("sombras", passo)
		"particulas":
			_girar_opcao("particulas_sim", passo)
		"fps":
			Config.definir("mostrar_fps", not bool(Config.v("mostrar_fps")))
		"musica":
			_volume("musica", passo)
		"efeitos":
			_volume("efeitos", passo)
	_desenhar()


## Volta ao santuário: tira a pausa ANTES (o resultado, resultado_meta.gd, anima com a árvore rodando) e manda a partida
## para o fim como abandonada (combate.abandonar: mesmo caminho da morte, venceu = false, almas creditadas).
func _voltar_santuario() -> void:
	fechar()
	if mundo != null and mundo.combate != null:
		mundo.combate.abandonar()


func _sair() -> void:
	if ao_sair.is_valid():
		ao_sair.call()
	else:
		get_tree().quit()


func _girar_opcao(chave: String, passo: int) -> void:
	var o: Dictionary = Config.g_opcao(chave)
	var valores: Array = o.get("valores", [])
	if valores.is_empty():
		return
	var i := maxi(valores.find(Config.g(chave)), 0)
	Config.g_definir(chave, valores[posmod(i + passo, valores.size())])


func _volume(chave: String, passo: int) -> void:
	var v := clampf(float(Config.v(chave)) + 0.1 * passo, 0.0, 1.0)
	Config.definir(chave, snappedf(v, 0.1))  # grava em opcoes.cfg e aplica o volume (Som) na hora, como a v1


func _rotulo_opcao(chave: String) -> String:
	var o: Dictionary = Config.g_opcao(chave)
	var i: int = o.get("valores", []).find(Config.g(chave))
	var rotulos: Array = o.get("rotulos", [])
	if i >= 0 and i < rotulos.size():
		return str(rotulos[i])
	return str(Config.g(chave))


func _pct(v: Variant) -> String:
	return "%d%%" % roundi(float(v) * 100.0)


# ------------------------------------------------------------------ desenho


func _itens() -> Array:
	match tela:
		"menu":
			var r := [_it("continuar", "Continuar"), _it("graficos", "Gráficos"), _it("volume", "Volume")]
			if mundo != null:
				r.append(_it("santuario", "Voltar ao santuário"))
			r.append(_it("sair", "Sair do jogo"))
			return r
		"graficos":
			return [
				_it("sombras", "Sombras", _rotulo_opcao("sombras")),
				_it("particulas", "Partículas", _rotulo_opcao("particulas_sim")),
				_it("fps", "Mostrar FPS", "Sim" if bool(Config.v("mostrar_fps")) else "Não"),
				_it("voltar", "Voltar"),
			]
		"volume":
			return [_it("musica", "Música", _pct(Config.v("musica"))), _it("efeitos", "Efeitos", _pct(Config.v("efeitos"))), _it("voltar", "Voltar")]
		"confirmar_santuario":
			return [_it("ok_santuario", "Sim"), _it("nao", "Não")]
		"confirmar_sair":
			return [_it("ok_sair", "Sim"), _it("nao", "Não")]
	return []


func _it(id: String, rotulo: String, valor := "") -> Dictionary:
	return {"id": id, "rotulo": rotulo, "valor": valor}


func _titulo_tela() -> String:
	match tela:
		"graficos":
			return "GRÁFICOS"
		"volume":
			return "VOLUME"
		"confirmar_santuario":
			return "VOLTAR?"
		"confirmar_sair":
			return "SAIR?"
	return "PAUSADO"


func _sub_tela() -> String:
	if tela == "confirmar_santuario":
		return "A partida conta como abandonada."
	if tela == "confirmar_sair":
		return "Fecha o jogo de vez."
	return ""


## Redesenha o menu inteiro (é barato: são poucas linhas). Chamado a cada mudança de tela, seleção ou valor.
func _desenhar() -> void:
	_itens_atuais = _itens()
	sel = clampi(sel, 0, maxi(_itens_atuais.size() - 1, 0))
	_titulo.text = _titulo_tela()
	_sub.text = _sub_tela()
	_dica.text = DICA
	for i in _linhas.size():
		var l: Dictionary = _linhas[i]
		var mostra: bool = i < _itens_atuais.size()
		l["linha"].visible = mostra
		if not mostra:
			continue
		var on: bool = i == sel
		var it: Dictionary = _itens_atuais[i]
		l["marca"].visible = on
		l["rotulo"].text = str(it.rotulo)
		l["valor"].text = str(it.valor)
		var cor := COR_OURO if on else COR_TEXTO
		l["rotulo"].add_theme_color_override("font_color", cor)
		l["valor"].add_theme_color_override("font_color", cor)


func _process(dt: float) -> void:
	_fps_t -= dt
	if _fps_t > 0.0:
		return
	_fps_t = 0.25  # quatro vezes por segundo basta para um contador
	var mostrar := bool(Config.v("mostrar_fps"))
	_fps.visible = mostrar
	if mostrar:
		_fps.text = "%d fps" % Engine.get_frames_per_second()


func _notification(what: int) -> void:
	# a v1 pausa ao sair da janela (opção pausar_fora). Headless não tem janela, então não conta (como em hud.gd da v1).
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT or mundo == null or not bool(Config.v("pausar_fora")):
		return
	if DisplayServer.get_name() == "headless":
		return
	pausar()


# ------------------------------------------------------------------ sons (o áudio do combate roda com a pausa; o Som global não)


func _som_cursor() -> void:
	if mundo != null and mundo.combate != null:
		mundo.combate.audio.tocar("carta", 1.2, -6.0, 0.03)
	else:
		Som.ui("cursor")


func _som_ok() -> void:
	if mundo != null and mundo.combate != null:
		mundo.combate.audio.tocar("escolher", 1.0, 0.0, 0.0)
	else:
		Som.ui("confirmar")
