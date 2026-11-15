extends Control
## Tela de carregamento da partida (pedido do Alisson, 15/11). Quem a usa é o `Transicoes.ir_para_carregando` (v2/transicoes.gd):
## ela cobre a tela enquanto a cena carrega numa thread e fica por cima até a cena nova desenhar os primeiros quadros.
## Só desenho: fundo liso, o nome do destino, "CARREGANDO", uma barra dourada e uma dica. Os números ficam em dados/v2_carregando.json.
##
## - A barra só enche (cada pixel muda uma vez), então vale com "Reduzir piscadas". Os três pontos depois de "CARREGANDO" trocam a
##   cada `pontos_s` (0,5 s: no máximo 2 trocas por segundo num pixel) e ficam parados com "Reduzir piscadas", com "Reduzir
##   animações" e no perfil Baixo.
## - A janela muda de escala quando a partida entra (o salão usa CANVAS_ITEMS e a partida usa DISABLED): o bloco de 960x540 se
##   reencaixa sozinho todo quadro (`_encaixar`), em escala inteira de tela, para o texto não pular de tamanho no meio da carga.

const Paleta := preload("res://v2/paleta.gd")
const EstiloPremium := preload("res://v2/estilo_premium.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const BLOCO := Vector2(960, 540)
const BARRA := Rect2(320, 286, 320, 10)  # no bloco; a borda de 1 px fica por fora

var valor := 0.0  # o que a barra mostra (0 a 1); só sobe
var _alvo := 0.0
var _vel := 1.5
var _pontos_s := 0.5
var _t := 0.0
var _fundo := ColorRect.new()
var _bloco := Control.new()
var _titulo: Label
var _estado: Label
var _dica: Label
var _cheio := ColorRect.new()
var _ultima_dica := -1


static func cfg() -> Dictionary:
	return Dados.json("v2_carregando")


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fundo.color = Paleta.PAINEL
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo)
	_bloco.size = BLOCO
	_bloco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bloco)
	_titulo = _texto("", Rect2(48, 196, 864, 44), Paleta.TITULO_MEDIO, Paleta.OURO, Dados.fonte_titulo)
	var ornamento := EstiloPremium.ornamento(320)
	ornamento.position = Vector2(320, 246)
	_bloco.add_child(ornamento)
	_estado = _texto("   CARREGANDO   ", Rect2(48, 262, 864, 18), Paleta.TEXTO_TAMANHO, Paleta.CABECALHO, Dados.fonte_texto)
	var borda := ColorRect.new()
	borda.color = Paleta.BORDA
	borda.position = BARRA.position - Vector2.ONE
	borda.size = BARRA.size + Vector2(2, 2)
	_bloco.add_child(borda)
	var vazio := ColorRect.new()
	vazio.color = Paleta.BARRA_VAZIA
	vazio.position = BARRA.position
	vazio.size = BARRA.size
	_bloco.add_child(vazio)
	_cheio.color = Paleta.OURO
	_cheio.position = BARRA.position
	_cheio.size = Vector2(0, BARRA.size.y)
	_bloco.add_child(_cheio)
	_dica = _texto("", Rect2(48, 318, 864, 18), Paleta.TEXTO_TAMANHO, Paleta.TEXTO_SECUNDARIO, Dados.fonte_texto)
	for c in [_fundo, borda, vazio, _cheio]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_encaixar()


## Mostra a tela do zero: `titulo` é o nome do destino (o mapa), a barra volta ao vazio e uma dica nova é sorteada.
func abrir(titulo: String) -> void:
	var c := cfg()
	_vel = float(c.get("barra_vel", 1.5))
	_pontos_s = float(c.get("pontos_s", 0.5))
	_titulo.text = titulo.to_upper()
	_dica.text = _sortear_dica(c.get("dicas", []))
	valor = 0.0
	_alvo = 0.0
	_t = 0.0
	modulate.a = 1.0
	_desenhar_barra()
	_estado.text = _texto_estado()
	_encaixar()
	visible = true


## Até onde a barra deve chegar (0 a 1). Nunca volta: um alvo menor que o atual é ignorado.
func alvo(v: float) -> void:
	_alvo = maxf(_alvo, clampf(v, 0.0, 1.0))


## A barra pula para o alvo agora (antes de um trecho em que o jogo não vai desenhar: a montagem da cena).
func assentar() -> void:
	valor = _alvo
	_desenhar_barra()


## Os pontos de "CARREGANDO" ficam parados: perfil Baixo, "Reduzir piscadas" ou "Reduzir animações".
static func parado() -> bool:
	return Piscadas.ligado() or Config.g_perfil() == "baixo" or bool(Config.v("reduzir_animacoes"))


func _process(dt: float) -> void:
	if not visible:
		return
	_encaixar()
	_t += dt
	if valor < _alvo:
		valor = minf(_alvo, valor + _vel * dt)
		_desenhar_barra()
	var txt := _texto_estado()
	if _estado.text != txt:
		_estado.text = txt


func _texto_estado() -> String:
	if parado() or _pontos_s <= 0.0:
		return "   CARREGANDO   "
	var n := int(_t / _pontos_s) % 4
	return "   CARREGANDO" + ".".repeat(n) + " ".repeat(3 - n)  # 3 espaços de cada lado: a palavra fica no centro e não anda


func _desenhar_barra() -> void:
	_cheio.size.x = roundf(BARRA.size.x * valor)


## Sorteia uma dica sem repetir a anterior (quando há mais de uma). Sorteio próprio: não mexe na semente da partida.
func _sortear_dica(dicas: Array) -> String:
	if dicas.is_empty():
		return ""
	var i := int(Time.get_ticks_usec() % dicas.size())
	if i == _ultima_dica and dicas.size() > 1:
		i = (i + 1) % dicas.size()
	_ultima_dica = i
	return str(dicas[i])


## O fundo cobre a tela inteira e o bloco de 960x540 fica no centro, na maior escala INTEIRA de tela que cabe (mínimo 1).
## A conta parte dos pixels da janela, então dá o mesmo tamanho na tela com a escala do salão e com a da partida.
func _encaixar() -> void:
	if not is_inside_tree():
		return
	var visivel := get_viewport().get_visible_rect().size
	_fundo.position = Vector2.ZERO
	_fundo.size = visivel
	var janela := Vector2(get_window().size)
	if janela.x <= 0.0 or visivel.x <= 0.0:
		return
	var px_tela := maxf(1.0, floorf(minf(janela.x / BLOCO.x, janela.y / BLOCO.y)))  # px de tela por px do bloco
	var k := px_tela * visivel.x / janela.x  # o mesmo, em unidades do canvas de agora
	_bloco.scale = Vector2(k, k)
	_bloco.position = ((visivel - BLOCO * k) * 0.5).round()


func _texto(txt: String, r: Rect2, tam: int, cor: Color, fonte: Font) -> Label:
	var l := Label.new()
	l.text = txt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.position = r.position
	l.size = r.size
	_bloco.add_child(l)
	return l
