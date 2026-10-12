extends CanvasLayer
## Menu de pausa da v2 (camada 14, acima de tudo). Na partida, ESC ou Start pausam o mundo (get_tree().paused) e abrem o menu;
## ESC, Start, B ou "Continuar" fecham. Pausa: Continuar, Ajustes, Voltar ao santuário (com confirmação: a partida conta como
## abandonada, pelo caminho da morte, combate.abandonar -> partida_terminou com venceu = false) e Sair do jogo (com confirmação).
## Ajustes: Gráficos (o menu completo da aba, em ajustes_graficos.gd, dirigido pelo dados/graficos.json e pelo Config) e Áudio
## (Música e Efeitos, as chaves musica e efeitos da v1). ESC dentro de Ajustes volta um nível, sem fechar a pausa de uma vez.
## Sair é o ÚNICO caminho que fecha o jogo; ao_sair é o gancho que os testes trocam.
## No santuário (altar.gd, sem mundo) o ESC abre só "Sair?", e abrir_ajustes() abre Ajustes (o botão do santuário).
## Perder o foco da janela pausa a partida (opção pausar_fora da v1; não vale em headless). Criada pelo mundo.gd (uma linha no
## _ready) e pelo altar.gd. Os botões são desenhados e testados por retângulo: o SubViewport da partida não entrega mouse aos Controls.
## ENTRADA: a janela entrega teclado, controle e mouse só à viewport RAIZ; o SubViewport da partida (onde o menu mora, para ficar na
## grade de pixels) não recebe nada, então o _input do menu NÃO roda lá. Na partida quem o alimenta é a Antena (filha do mundo, em
## PROCESS_MODE_ALWAYS): ela vem antes do mundo e das telas na ordem do _input e continua ouvindo com a árvore pausada. No santuário
## o menu mora na raiz e usa o próprio _input. Nos dois casos a regra é a de entrada(). Abre em "jogando" e também sobre a escolha de
## cartas e o baú (que voltam intactos ao fechar); não abre na câmera lenta da morte e da vitória nem no resultado.
## Fontes (regra de v2/LEIA-ME.md): título e botões na Jersey 10 (Dados.fonte_titulo), valores, apoio e ajuda na Pixelify Sans
## (Dados.fonte_texto), e o contador de fps na Press Start 2P (Dados.fonte, HUD). Cada uso escolhe a sua em _rotulo.

const AjustesGraficos := preload("res://v2/ajustes_graficos.gd")
const Creditos := preload("res://v2/creditos.gd")
const MOLDURA := preload("res://v2/hud/moldura_pedra.png")
const TAM_TITULO := 56  # grade da Jersey 10 (56, 37, 19; ver v2/LEIA-ME.md)
const TAM_BOTAO := 19  # botões e linhas (Jersey 10 na grade de 19)
const TAM_SUB := 14  # linha de apoio do título
const TAM_VALOR := 14  # valor à direita (Pixelify Sans)
const TAM_AJUDA := 12  # ajuda da linha escolhida (rodapé dos gráficos)
const TAM_DICA := 14
const LARG := 960.0
const ALT := 540.0
const PAINEL := Rect2(290, 55, 380, 430)
const LINHA0 := 118.0  # primeira linha, a partir do topo do painel
const LINHA_H := 36.0
const LINHA_ALT := 32.0  # altura da faixa de cada linha
const VISIVEIS := 5  # linhas visíveis de uma vez; a lista rola com a seleção
const AJUDA_Y := LINHA0 + VISIVEIS * LINHA_H + 8.0  # rodapé com a ajuda da linha escolhida
const AJUDA_H := 96.0
const DICA_Y := 406.0  # PAINEL.size.y - 24
const COR_OURO := Color(1.0, 0.86, 0.42)
const COR_TEXTO := Color(0.92, 0.9, 0.96)
const COR_CAB := Color(0.62, 0.6, 0.72)  # cabeçalho de seção (não é selecionável)
const COR_FUNDO := Color(0.004, 0.012, 0.043, 0.72)  # #01030b a 0,7 (hud_menus.md, seção 4)
const DICA := "Setas escolhem   Enter confirma   Esc volta"
const CREDITO_MUSICA := "Música: Kevin MacLeod (incompetech.com)\nLicença Creative Commons Atribuição 4.0 (CC BY 4.0)"  # atribuição pedida pelo autor; lista completa em docs/LICENCAS_AUDIO.md
const STEPPERS := ["musica", "efeitos"]  # linhas de volume: a esquerda e a direita também valem

var mundo  # a partida (mundo.gd); null no santuário (altar.gd)
var mouse_fn := Callable()  # mouse em 960x540 (o Apresentacao da partida); vazio = mouse da janela (santuário)
var ao_sair := Callable()  # "Sim" em Sair do jogo; vazio = get_tree().quit()
var aberto := false
var tela := "menu"
var _arvore_antes := false  # get_tree().paused de quando o menu abriu: fechar devolve exatamente isso
var _apertos := {}  # botões do mouse apertados COM o menu aberto: só a soltura de um aperto visto aciona uma linha
var sel := 0
var _topo := 0  # primeira linha visível da lista
var _origem := "menu"  # para onde "Não" de uma confirmação volta; "" = fecha (santuário, sem menu por trás)
var _itens_atuais: Array = []
var _graficos := AjustesGraficos.new()
var _raiz: Control
var _titulo: Label
var _sub: Label
var _dica: Label
var _ajuda: Label
var _linhas: Array = []  # uma por linha visível: {linha, marca, rotulo, valor}
var _fps: Label
var _fps_t := 0.0


## Liga o menu à partida (m = mundo.gd) ou ao santuário (null). Chamado antes de entrar na árvore.
func iniciar(m) -> Node:
	mundo = m
	if mundo != null:
		mouse_fn = Callable(mundo.ap, "mouse_na_tela")
		mundo.add_child(Antena.new(self))
	return self


## Leva à pausa da partida a entrada que a janela manda à raiz. É filha do mundo (depois dele na árvore, então recebe ANTES dele e
## das telas) e roda com a árvore pausada, quando o próprio mundo não recebe nada. O que o menu usa, ela tira do caminho do mundo.
class Antena:
	extends Node
	var menu

	func _init(m) -> void:
		menu = m
		name = "AntenaPausa"
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(e: InputEvent) -> void:
		if is_instance_valid(menu) and menu.entrada(e):
			get_viewport().set_input_as_handled()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # com a árvore pausada, o menu continua recebendo entrada e desenhando
	set_process_input(mundo == null)  # na partida a entrada vem da Antena (o SubViewport não recebe a janela)
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
	_sub = _rotulo(
		Dados.fonte_texto, TAM_SUB, COR_TEXTO, Vector2(PAINEL.position.x + 12, PAINEL.position.y + 88), PAINEL.size.x - 24, HORIZONTAL_ALIGNMENT_CENTER
	)
	_raiz.add_child(_sub)
	for i in VISIVEIS:
		var w := PAINEL.size.x - 48
		var linha := Control.new()
		linha.position = Vector2(PAINEL.position.x + 24, PAINEL.position.y + LINHA0 + i * LINHA_H)
		linha.size = Vector2(w, LINHA_ALT)
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
	_ajuda = _rotulo(
		Dados.fonte_texto, TAM_AJUDA, COR_TEXTO, Vector2(PAINEL.position.x + 22, PAINEL.position.y + AJUDA_Y), PAINEL.size.x - 44, HORIZONTAL_ALIGNMENT_LEFT
	)
	_ajuda.size.y = AJUDA_H
	_ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_raiz.add_child(_ajuda)
	_dica = _rotulo(
		Dados.fonte_texto, TAM_DICA, COR_TEXTO, Vector2(PAINEL.position.x + 8, PAINEL.position.y + DICA_Y), PAINEL.size.x - 16, HORIZONTAL_ALIGNMENT_CENTER
	)
	_raiz.add_child(_dica)
	_fps = _rotulo(Dados.fonte, 8, Color(1, 1, 1, 0.92), Vector2(6, ALT - 16), 200.0, HORIZONTAL_ALIGNMENT_LEFT)  # HUD: Press Start 2P
	_fps.visible = false
	add_child(_fps)  # fora de _raiz: o contador de fps aparece também com o menu fechado


## Um rótulo do menu. A fonte entra por parâmetro e cada uso escolhe a sua.
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


## Abre o menu sobre a partida e para o mundo. Vale com o jogo rolando e sobre a escolha de cartas e o baú; não na câmera lenta da
## morte e da vitória nem no resultado. Devolve true se abriu.
func pausar() -> bool:
	if mundo == null or aberto or not _pode_pausar():
		return false
	_arvore_antes = get_tree().paused
	_apertos.clear()
	aberto = true
	_raiz.visible = true
	_ir("menu")
	get_tree().paused = true
	return true


## Fecha o menu e devolve a árvore ao estado de antes de abrir (no santuário não há pausa para tirar).
func fechar() -> void:
	if not aberto:
		return
	aberto = false
	_raiz.visible = false
	_apertos.clear()
	if mundo != null:
		get_tree().paused = _arvore_antes


## Santuário (sem mundo): o ESC abre direto a confirmação de sair.
func abrir_sair() -> void:
	if aberto:
		return
	aberto = true
	_raiz.visible = true
	_ir("confirmar_sair", "")


## Santuário: o botão Ajustes abre o mesmo submenu (sem pausa, porque não há partida).
func abrir_ajustes() -> void:
	if aberto:
		return
	aberto = true
	_raiz.visible = true
	_ir("ajustes", "")


## Só olha em que passo do jogo a partida está (combate.jogo), nunca um flag solto: "jogando", ou a escolha de cartas e o baú, que
## o menu cobre e devolve como estavam. Morrendo, vencendo e os resultados têm o fluxo deles.
func _pode_pausar() -> bool:
	var c = mundo.combate
	return c != null and (c.jogo == "jogando" or c.jogo == "escolha" or c.jogo == "bau")


func _ir(nova: String, origem := "menu") -> void:
	tela = nova
	_origem = origem
	sel = 1 if nova.begins_with("confirmar") else 0  # confirmação começa em "Não"
	_topo = 0
	_desenhar()


## ESC (ou B, ou Start): volta um nível. Na pausa, fecha; em Ajustes, volta à pausa (no santuário, fecha);
## em Gráficos e Áudio, volta a Ajustes; nas confirmações, é "Não".
func _voltar_tela() -> void:
	match tela:
		"menu":
			fechar()
		"ajustes":
			if mundo != null:
				_ir("menu")
			else:
				fechar()
		"graficos", "audio", "creditos":
			_ir("ajustes")
		_:
			_executar("nao", 0)


# ------------------------------------------------------------------ entrada


## Só o santuário usa (o menu mora na raiz); na partida o _input do menu fica desligado e a Antena chama entrada().
func _input(e: InputEvent) -> void:
	if entrada(e):
		get_viewport().set_input_as_handled()


## Um evento de entrada. Devolve true se o menu o usou: então quem chamou o tira do caminho (o mundo e as telas não o veem).
## Fechado, só ESC e Start importam, e só contam se o menu abriu. Aberto, o menu come tudo (o mundo está parado; no santuário, os
## botões de trás não recebem).
func entrada(e: InputEvent) -> bool:
	if not aberto:
		if not _pede_menu(e):
			return false
		if mundo == null:
			abrir_sair()
			return true
		return pausar()
	if e is InputEventMouseMotion:
		var i := _linha_sob_mouse()
		if i >= 0 and i != sel:
			sel = i
			_som_cursor()
			_desenhar()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
		_mover(-1)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_mover(1)
	elif e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
		_apertos[e.button_index] = true
	elif e is InputEventMouseButton and not e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
		# o clique age ao SOLTAR: quem fecha a pausa com o mouse não manda o golpe do herói (o golpe é no aperto, em heroi.gd).
		# Só vale a soltura de um aperto visto COM o menu aberto: quem abriu o menu com o botão segurado (o golpe repetido, o clique da
		# carta) solta com o cursor em cima de uma linha, e isso não pode apertar a linha.
		if _apertos.erase(e.button_index):
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
	return true


## ESC (tecla) ou Start do controle: os dois pausam e, com o menu aberto, voltam como o ui_cancel (B).
func _pede_menu(e: InputEvent) -> bool:
	if e is InputEventKey:
		return e.pressed and not e.echo and e.keycode == KEY_ESCAPE
	if e is InputEventJoypadButton:
		return e.pressed and e.button_index == JOY_BUTTON_START
	return false


## Próxima linha selecionável na direção d (cabeçalho de seção não recebe a seleção).
func _mover(d: int) -> void:
	var n := _itens_atuais.size()
	if n == 0:
		return
	for k in n:
		sel = posmod(sel + d, n)
		if str(_itens_atuais[sel].id) != "":
			break
	_som_cursor()
	_desenhar()


## Aciona a linha selecionada. Linha que muda valor recebe o passo (+1 ou -1); as outras só com confirmar.
func _acao_sel(passo: int, confirmar: bool) -> void:
	if _itens_atuais.is_empty():
		return
	var id := str(_itens_atuais[sel].id)
	if id == "":
		return
	if _eh_stepper(id):
		_executar(id, passo)
	elif confirmar:
		_som_ok()
		_executar(id, 0)


func _eh_stepper(id: String) -> bool:
	return id in STEPPERS or id == "g:perfil" or id.begins_with("g:op:")


## Índice (na lista inteira) da linha visível sob o mouse; -1 se não há linha ali (ou é cabeçalho).
func _linha_sob_mouse() -> int:
	var m := _mouse()
	for i in _linhas.size():
		var idx := _topo + i
		if idx >= _itens_atuais.size():
			break
		var r := Rect2(PAINEL.position.x + 24, PAINEL.position.y + LINHA0 + i * LINHA_H, PAINEL.size.x - 48, LINHA_ALT)
		if r.has_point(m):
			return idx if str(_itens_atuais[idx].id) != "" else -1
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
		"ajustes":
			_ir("ajustes")
		"graficos":
			_ir("graficos")
		"audio":
			_ir("audio")
		"creditos":
			_ir("creditos")
		"voltar":
			_voltar_tela()
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
		"musica", "efeitos":
			_volume(id, passo)
		_:
			if id.begins_with("g:"):
				_graficos.agir(id.substr(2), passo)
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


func _volume(chave: String, passo: int) -> void:
	var v := clampf(float(Config.v(chave)) + 0.1 * passo, 0.0, 1.0)
	Config.definir(chave, snappedf(v, 0.1))  # grava em opcoes.cfg e aplica o volume (Som) na hora, como a v1


func _pct(v: Variant) -> String:
	return "%d%%" % roundi(float(v) * 100.0)


# ------------------------------------------------------------------ desenho


func _itens() -> Array:
	match tela:
		"menu":
			var r := [_it("continuar", "Continuar"), _it("ajustes", "Ajustes")]
			if mundo != null:
				r.append(_it("santuario", "Voltar ao santuário"))
			r.append(_it("sair", "Sair do jogo"))
			return r
		"ajustes":
			return [_it("graficos", "Gráficos"), _it("audio", "Áudio"), _it("creditos", "Créditos"), _it("voltar", "Voltar")]
		"creditos":
			return Creditos.itens() + [_it("voltar", "Voltar")]
		"graficos":
			return _graficos.itens()
		"audio":
			return [_it("musica", "Música", _pct(Config.v("musica"))), _it("efeitos", "Efeitos", _pct(Config.v("efeitos"))), _it("voltar", "Voltar")]
		"confirmar_santuario":
			return [_it("ok_santuario", "Sim"), _it("nao", "Não")]
		"confirmar_sair":
			return [_it("ok_sair", "Sim"), _it("nao", "Não")]
	return []


func _it(id: String, rotulo: String, valor := "") -> Dictionary:
	return {"id": id, "rotulo": rotulo, "valor": valor, "ajuda": ""}


func _titulo_tela() -> String:
	match tela:
		"ajustes":
			return "AJUSTES"
		"graficos":
			return "GRÁFICOS"
		"audio":
			return "ÁUDIO"
		"creditos":
			return "CRÉDITOS"
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
	if tela == "graficos":
		return _graficos.mensagem
	return ""


## Redesenha o menu (é barato: são poucas linhas). Chamado a cada mudança de tela, seleção, rolagem ou valor.
func _desenhar() -> void:
	_itens_atuais = _itens()
	var n := _itens_atuais.size()
	sel = clampi(sel, 0, maxi(n - 1, 0))
	if sel < _topo:
		_topo = sel
	elif sel >= _topo + VISIVEIS:
		_topo = sel - VISIVEIS + 1
	_topo = clampi(_topo, 0, maxi(n - VISIVEIS, 0))
	_titulo.text = _titulo_tela()
	_sub.text = _sub_tela()
	_dica.text = DICA
	_ajuda.text = _texto_ajuda()
	for i in _linhas.size():
		var l: Dictionary = _linhas[i]
		var idx := _topo + i
		var mostra: bool = idx < n
		l["linha"].visible = mostra
		if not mostra:
			continue
		var it: Dictionary = _itens_atuais[idx]
		var cab: bool = bool(it.get("cab", false))
		var on: bool = idx == sel and not cab
		l["marca"].visible = on
		l["rotulo"].text = str(it.rotulo)
		l["valor"].text = str(it.get("valor", ""))
		var cor := COR_CAB if cab else (COR_OURO if on else COR_TEXTO)
		l["rotulo"].add_theme_color_override("font_color", cor)
		l["valor"].add_theme_color_override("font_color", cor)


## Rodapé: a ajuda da linha escolhida em Gráficos (o json traz a ajuda de cada opção) e em Créditos (o aviso de cada licença) e, na aba Áudio, o crédito das músicas (CC BY exige).
func _texto_ajuda() -> String:
	if tela == "audio":
		return CREDITO_MUSICA
	if (tela != "graficos" and tela != "creditos") or sel >= _itens_atuais.size():
		return ""
	return str(_itens_atuais[sel].get("ajuda", ""))


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
