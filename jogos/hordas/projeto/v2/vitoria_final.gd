extends Control
## Fim de jogo da v2: vencer o chefão do ÚLTIMO mapa (as Ruínas da Floresta, dados/v2_vitoria_final.json) leva, depois do resultado da
## partida (resultado_meta.gd), a esta cena: primeiro a tela de VITÓRIA FINAL (texto de encerramento, provisório, nos dados) e depois os
## CRÉDITOS rolando, com as mesmas linhas de Ajustes > Créditos (v2/creditos.gd, rótulo e valor). Ao terminar, volta ao menu principal.
## Pular: Enter, Espaço, E, A do controle ou clique passam para a próxima etapa (vitória -> créditos -> menu); Esc, B e Start pulam
## tudo e vão direto ao menu. Os primeiros instantes ignoram a entrada (quem ainda segurava o golpe não pula sem querer).
## O registro da primeira vitória nas Ruínas já é o de qualquer mapa: a conquista vence_medio no save (Meta.mapa_vencido), gravada pelo
## combate ao vencer o chefão. Os outros mapas não passam por aqui (ver `destino`).

const Paleta := preload("res://v2/paleta.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const UiJanela := preload("res://v2/ui_janela.gd")
const Glifos := preload("res://v2/glifos.gd")
const Creditos := preload("res://v2/creditos.gd")
const Entrada := preload("res://v2/entrada.gd")
const CENA := "res://v2/vitoria_final.tscn"
const MENU := "res://v2/menu_principal.tscn"
const DADOS := "v2_vitoria_final"
const LARG := 960
const ALT := 540
const FADE := 1.2  # s para o texto da vitória aparecer
const PASSO_LINHA := 26.0  # px entre o rótulo e o valor de uma entrada de crédito
const PASSO_ENTRADA := 70.0  # px entre uma entrada de créditos e a seguinte

enum Fase { VITORIA, CREDITOS, FIM }

var fase := Fase.VITORIA
var t := 0.0  # segundos na fase atual
var ao_menu := Callable()  # gancho: os testes trocam a volta ao menu; vazio = troca a cena
var _cfg := {}
var _fundo: ColorRect
var _vitoria: Control
var _dica: Control
var _creditos: Control
var _cred_altura := 0.0
var _cred_y := 0.0
var _saindo := false


## O mapa que fecha o jogo (id, dos dados).
static func mapa_final() -> String:
	return str(Dados.json(DADOS).get("mapa", "medio"))


## Esse resultado de partida (o de mundo.resultado) é a vitória no mapa final?
static func eh_final(r: Dictionary) -> bool:
	return bool(r.get("venceu", false)) and str(r.get("mapa", "")) == mapa_final()


## A cena que vem depois do resultado: a vitória final no mapa final, senão `padrao` (o santuário).
static func destino(r: Dictionary, padrao: String) -> String:
	return CENA if eh_final(r) else padrao


func _ready() -> void:
	_cfg = Dados.json(DADOS)
	Entrada.garantir()
	add_child(UiJanela.new().montar(self))
	_montar()
	add_to_group("ui_escala")
	ui_reencaixar(EscalaUi.canvas_atual, EscalaUi.desloc_atual)
	_ir(Fase.VITORIA)


func _montar() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Paleta.PAINEL
	EscalaUi.cobrir(_fundo)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo)
	_vitoria = Control.new()
	_vitoria.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vitoria)
	_vitoria.add_child(_rotulo(str(_cfg.get("titulo", "")), Paleta.TITULO_GRANDE, true, Paleta.OURO, Rect2(0, 96, LARG, 72)))
	_vitoria.add_child(_rotulo(str(_cfg.get("subtitulo", "")), Paleta.TITULO_MEDIO, true, Paleta.TEXTO, Rect2(0, 176, LARG, 52)))
	var corpo := _rotulo(
		"\n\n".join(PackedStringArray(_cfg.get("texto", []))), Paleta.TEXTO_TAMANHO, false, Paleta.TEXTO_SECUNDARIO, Rect2(160, 270, LARG - 320, 170)
	)
	corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vitoria.add_child(corpo)
	_creditos = Control.new()
	_creditos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_creditos)
	_montar_creditos()
	_dica = Glifos.dica(_itens_dica, HORIZONTAL_ALIGNMENT_CENTER, Paleta.TEXTO_APAGADO)
	_dica.size = Vector2(LARG, 22)
	add_child(_dica)


## Os créditos numa coluna só: o título, uma entrada por linha de Creditos.LINHAS (rótulo em ouro, valor embaixo) e o agradecimento.
func _montar_creditos() -> void:
	var y := 0.0
	_creditos.add_child(_rotulo(str(_cfg.get("creditos_titulo", "")), Paleta.TITULO_GRANDE, true, Paleta.OURO, Rect2(0, y, LARG, 72)))
	y += 120.0
	for l in Creditos.LINHAS:
		_creditos.add_child(_rotulo(str(l.rotulo), Paleta.TITULO_PEQUENO, true, Paleta.OURO, Rect2(0, y, LARG, 28)))
		_creditos.add_child(_rotulo(str(l.valor), Paleta.TEXTO_TAMANHO, false, Paleta.TEXTO, Rect2(0, y + PASSO_LINHA, LARG, 24)))
		y += PASSO_ENTRADA
	y += 50.0
	_creditos.add_child(_rotulo(str(_cfg.get("agradecimento", "")), Paleta.TITULO_MEDIO, true, Paleta.TEXTO, Rect2(0, y, LARG, 52)))
	_cred_altura = y + 52.0


func _rotulo(txt: String, tam: int, titulo: bool, cor: Color, r: Rect2) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Dados.fonte_titulo if titulo else Dados.fonte_texto)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(Paleta.PRETO, 0.9))
	l.add_theme_constant_override("outline_size", 4 if titulo else 0)
	l.add_theme_constant_override("line_spacing", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _itens_dica() -> Array:
	return [["confirmar", "Continuar"], ["voltar", "Pular tudo"]]


## A dica fica na borda de baixo do canvas, como no título. Chamado também quando a janela ou a opção mudam.
func ui_reencaixar(_canvas: Vector2, desloc: Vector2) -> void:
	if _dica != null:
		_dica.position = Vector2(0.0, ALT + desloc.y - 30.0)
	_posicionar_creditos()


func _ir(f: Fase) -> void:
	fase = f
	t = 0.0
	_vitoria.visible = f == Fase.VITORIA
	_creditos.visible = f == Fase.CREDITOS
	_vitoria.modulate.a = 0.0
	if f == Fase.CREDITOS:
		_cred_y = ALT + EscalaUi.desloc_atual.y  # começa logo abaixo da borda de baixo do canvas
		_posicionar_creditos()
	if f == Fase.FIM:
		_sair()


func _posicionar_creditos() -> void:
	if _creditos != null:
		_creditos.position = Vector2(0.0, _cred_y)


func _process(dt: float) -> void:
	t += dt
	match fase:
		Fase.VITORIA:
			_vitoria.modulate.a = clampf(t / FADE, 0.0, 1.0)
		Fase.CREDITOS:
			_cred_y -= float(_cfg.get("velocidade", 36.0)) * dt
			_posicionar_creditos()
			if _cred_y + _cred_altura < -EscalaUi.desloc_atual.y:
				_ir(Fase.FIM)  # o último crédito saiu pelo alto do canvas


## Vitória -> créditos -> menu. Chamado pela entrada (e pelos testes).
func proxima() -> void:
	if fase == Fase.VITORIA:
		_ir(Fase.CREDITOS)
	elif fase == Fase.CREDITOS:
		_ir(Fase.FIM)


## Pula tudo e vai ao menu.
func pular() -> void:
	if fase != Fase.FIM:
		_ir(Fase.FIM)


func _input(e: InputEvent) -> void:
	if fase == Fase.FIM or t < float(_cfg.get("tempo_aceita", 0.6)):
		return
	var proximo := false
	var tudo := false
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		proximo = true
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE:
			tudo = true
		elif e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
			proximo = true
	elif e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_START or e.button_index == JOY_BUTTON_B:
			tudo = true
		elif e.button_index == JOY_BUTTON_A:
			proximo = true
	if tudo:
		pular()
	elif proximo:
		proxima()
	else:
		return
	get_viewport().set_input_as_handled()


func _sair() -> void:
	if _saindo:
		return
	_saindo = true
	if ao_menu.is_valid():
		ao_menu.call()
	else:
		get_tree().change_scene_to_file.call_deferred(MENU)
