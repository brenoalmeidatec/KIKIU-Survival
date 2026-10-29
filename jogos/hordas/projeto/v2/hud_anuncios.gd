extends Control
## Faixa de anúncio do HUD da v2: fica no centro alto da tela, abaixo do bloco de tempo e combo. Um anúncio por vez na tela; os
## outros esperam numa fila (até CAPACIDADE, depois sai o mais antigo). Sem nó novo por anúncio: a moldura e o texto são os desta
## cena, e só mudam de texto, cor e tamanho. O HUD chama `anunciar` e `avancar`.
## Entrada: escala de 1,4 (mais com a intensidade) até 1,0, com brilho; segura ~1,2 s (mais 0,1 s por intensidade); sai esmaecendo.
## A intensidade vai de 0 a 4 e é o marco de combo (SEQUÊNCIA a LENDÁRIO): cresce a escala, o tempo na tela e o tremor.
## Visual premium (#152): uma faixa de cinema desenhada em `_draw` (escura, some nas pontas, com filetes e losangos na cor do
## anúncio) no lugar da caixa; o NinePatch `Moldura` fica escondido.

const CENTRO_X := 480.0
const LARGURA_MAX := 640.0
const ALTURA := 44.0
const TAM_FONTE := 22
## Texto que não cabe numa linha em TAM_FONTE: primeiro encolhe a fonte (até TAM_UMA_LINHA) para ainda caber numa linha; se nem assim,
## a faixa fica na largura máxima e quebra em linhas (a fonte desce até TAM_MIN, que aceita quantas linhas precisar). Nada é cortado.
const TAM_UMA_LINHA := 16
const TAM_MIN := 14
const LINHAS_PREFERIDAS := 2
const PASSO_FONTE := 2
const MARGEM_V := 18.0  # altura da faixa além das linhas de texto (ALTURA = 1 linha de TAM_FONTE + isto, mais ou menos)
const FOLGA := 96.0  # espaço do texto até a ponta da faixa (somado): cabe o losango de cada lado
const PONTA := 80.0  # quanto a faixa se estende além da caixa, sumindo
const ENTRADA_T := 0.18
const SAIDA_T := 0.25
const SEGURA_T := 1.2
const CAPACIDADE := 5
const INTENSIDADE_MAX := 4
## Anúncios que furam a fila: entram na hora, por cima do que está na tela (o ULTIMATE PRONTA não pode esperar atrás de NÍVEL, ONDA ou ELITE,
## porque o jogador precisa saber já que o Q está pronto). O que estava na tela volta à frente da fila, se ainda não deu tempo de ler.
const PRIORITARIOS := ["ULTIMATE PRONTA"]
const LIDO_T := 0.6  # s de anúncio na tela a partir dos quais ele conta como lido (não volta à fila se for interrompido)

## Anúncios esperando: cada um é {texto, cor, intensidade}.
var fila: Array = []
## O texto na tela agora ("" quando não há anúncio). Público para os testes.
var texto_ativo := ""

var _ativo := false
var _t := 0.0
var _segura := SEGURA_T
var _cor := Color.WHITE
var _intensidade := 0
var _y := 0.0
var _y0 := 0.0

@onready var _moldura: NinePatchRect = $Moldura
@onready var _texto: Label = $Texto


func _ready() -> void:
	_y = position.y
	_y0 = _y
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_moldura.visible = false  # a faixa é desenhada em _draw
	_texto.add_theme_font_size_override("font_size", TAM_FONTE)
	_texto.clip_text = false
	_texto.set_anchors_preset(Control.PRESET_TOP_LEFT, true)  # largura e posição do texto são calculadas em _mostrar


## O HUD gruda a faixa no topo do canvas: dy é o quanto subir (ou descer) em relação ao .tscn.
func ancorar(dy: float) -> void:
	_y = _y0 + dy
	position.y = _y


## Põe um anúncio na fila, ou na tela se ela estiver livre.
func anunciar(texto: String, cor: Color = Color.WHITE, intensidade: int = 0) -> void:
	var anuncio := {"texto": texto, "cor": cor, "intensidade": clampi(intensidade, 0, INTENSIDADE_MAX)}
	if not _ativo:
		_mostrar(anuncio)
		return
	if PRIORITARIOS.has(texto) and not PRIORITARIOS.has(texto_ativo):
		if _t < ENTRADA_T + LIDO_T:
			fila.push_front({"texto": texto_ativo, "cor": _cor, "intensidade": _intensidade})
			if fila.size() > CAPACIDADE:
				fila.pop_back()
		_mostrar(anuncio)
		return
	fila.append(anuncio)
	if fila.size() > CAPACIDADE:
		fila.pop_front()


## Verdadeiro se há anúncio na tela ou esperando.
func ocupado() -> bool:
	return _ativo or not fila.is_empty()


## Um quadro: avança o anúncio da tela (e puxa o próximo da fila quando ele acaba).
func avancar(dt: float) -> void:
	if _hud_escondido():
		return  # o HUD está escondido (escolha de carta, baú): o anúncio espera parado e aparece inteiro quando ele voltar
	if not _ativo:
		if fila.is_empty():
			return
		_mostrar(fila.pop_front())
	_t += dt
	if _t >= ENTRADA_T + _segura + SAIDA_T:
		_ativo = false
		texto_ativo = ""
		visible = false
		return
	_quadro()


## Algum pai (o HUD é uma CanvasLayer, que is_visible_in_tree não olha) está escondido.
func _hud_escondido() -> bool:
	var n := get_parent()
	while n != null:
		if (n is CanvasItem or n is CanvasLayer) and not n.visible:
			return true
		n = n.get_parent()
	return false


func _mostrar(anuncio: Dictionary) -> void:
	_ativo = true
	texto_ativo = str(anuncio["texto"])
	_cor = anuncio["cor"]
	_intensidade = int(anuncio["intensidade"])
	_segura = SEGURA_T + 0.1 * _intensidade
	_t = 0.0
	_texto.text = texto_ativo
	_texto.add_theme_color_override("font_color", _cor)
	var largura := _encaixar(texto_ativo)
	pivot_offset = size * 0.5
	position = Vector2(roundf(CENTRO_X - largura * 0.5), _y)
	visible = true
	queue_redraw()


## Escolhe tamanho de fonte e número de linhas para o texto caber inteiro na faixa, põe o Label no lugar, dá o tamanho da faixa e
## devolve a largura dela. Uma linha só quando cabe (fonte cheia, ou encolhida até TAM_UMA_LINHA); senão, largura máxima e quebra de linha.
func _encaixar(texto: String) -> float:
	var fonte: Font = _texto.get_theme_font("font")
	var util := LARGURA_MAX - FOLGA
	var tam := TAM_FONTE
	var linhas := 1
	var largura_texto := 0.0
	var coube := false
	while tam >= TAM_UMA_LINHA:
		largura_texto = fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		if largura_texto <= util:
			coube = true
			break
		tam -= PASSO_FONTE
	if coube:
		_texto.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		largura_texto = util
		_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tam = TAM_FONTE
		while true:
			linhas = _contar_linhas(fonte, texto, tam, util)
			if linhas <= LINHAS_PREFERIDAS or tam <= TAM_MIN:
				break
			tam -= PASSO_FONTE
	_texto.add_theme_font_size_override("font_size", tam)
	# O Label não serve para medir aqui: o size dele é forçado ao mínimo do momento (ainda da quebra e da fonte anteriores), então
	# as linhas e a altura saem da própria fonte, com a mesma quebra do Label (WORD_SMART) e a entrelinha do tema.
	var altura_texto := linhas * fonte.get_height(tam) + (linhas - 1) * _texto.get_theme_constant("line_spacing")
	var altura := maxf(ALTURA, altura_texto + MARGEM_V)
	var largura := minf(ceilf(largura_texto) + FOLGA, LARGURA_MAX)
	size = Vector2(largura, altura)
	_texto.position = Vector2(FOLGA * 0.5, 0.0)
	_texto.size = Vector2(largura - FOLGA, altura)
	return largura


## Quantas linhas o texto ocupa na largura dada, com a quebra do Label em WORD_SMART (palavra comprida demais quebra no meio).
func _contar_linhas(fonte: Font, texto: String, tam: int, largura: float) -> int:
	var quebra := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_TRIM_EDGE_SPACES
	var medida := fonte.get_multiline_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, largura, tam, -1, quebra)
	return maxi(1, roundi(medida.y / fonte.get_height(tam)))


## A faixa: escura no meio e sumindo nas pontas, com um filete em cima e outro embaixo na cor do anúncio e um losango de cada lado
## do texto.
func _draw() -> void:
	if not _ativo:
		return
	var w := size.x
	var h := size.y
	var escuro := Color(0.01, 0.012, 0.03, 0.86)
	_degrade(Rect2(-PONTA, 4, PONTA, h - 8), Color(escuro, 0.0), escuro)
	draw_rect(Rect2(0, 4, w, h - 8), escuro)
	_degrade(Rect2(w, 4, PONTA, h - 8), escuro, Color(escuro, 0.0))
	var cor := Color(_cor, 0.95)
	for y in [3.0, h - 4.0]:
		_degrade(Rect2(-PONTA, y, PONTA, 1), Color(cor, 0.0), cor)
		draw_rect(Rect2(0, y, w, 1), cor)
		_degrade(Rect2(w, y, PONTA, 1), cor, Color(cor, 0.0))
	for x in [18.0, w - 18.0]:
		_losango(Vector2(x, h / 2.0), 6.0, cor)
		_losango(Vector2(x, h / 2.0), 2.0, Color(0.05, 0.03, 0.02))


func _degrade(r: Rect2, c0: Color, c1: Color) -> void:
	var pts := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)])
	draw_polygon(pts, PackedColorArray([c0, c1, c1, c0]))


func _losango(p: Vector2, r: float, cor: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), cor)


func _quadro() -> void:
	var p := clampf(_t / ENTRADA_T, 0.0, 1.0)
	var pousa := 1.0 - (1.0 - p) * (1.0 - p)  # sai rápido e assenta devagar
	var escala_inicial := 1.4 + 0.15 * _intensidade
	var escala := roundf(lerpf(escala_inicial, 1.0, pousa) * 20.0) / 20.0  # degraus de 0,05, sem escala suave
	scale = Vector2.ONE * escala
	var saida := clampf((_t - ENTRADA_T - _segura) / SAIDA_T, 0.0, 1.0)
	var brilho := 1.0 + 0.8 * (1.0 - p)  # no começo o anúncio acende e assenta na cor do tipo
	modulate = Color(brilho, brilho, brilho, 1.0 - saida)
	_moldura.modulate = _cor
	var tremor := 0.0
	if _intensidade >= 2:
		tremor = sin(_t * 60.0) * 3.0 * (1.0 - p)  # os marcos altos tremem ao entrar
	position.x = roundf(CENTRO_X - size.x * 0.5 + tremor)
