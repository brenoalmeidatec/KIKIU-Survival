extends Control
## Faixa de anúncio do HUD da v2: fica no centro alto da tela, abaixo do bloco de tempo e combo. Um anúncio por vez na tela; os
## outros esperam numa fila (até CAPACIDADE, depois sai o mais antigo). Sem nó novo por anúncio: a moldura e o texto são os desta
## cena, e só mudam de texto, cor e tamanho. O HUD chama `anunciar` e `avancar`.
## Entrada: escala de 1,4 (mais com a intensidade) até 1,0, com brilho; segura ~1,2 s (mais 0,1 s por intensidade); sai esmaecendo.
## A intensidade vai de 0 a 4 e é o marco de combo (SEQUÊNCIA a LENDÁRIO): cresce a escala, o tempo na tela e o tremor.

const CENTRO_X := 480.0
const LARGURA_MAX := 560.0
const ALTURA := 40.0
const TAM_FONTE := 16
const FOLGA := 40.0  # espaço do texto até a borda da moldura (somado, 20 px de cada lado)
const ENTRADA_T := 0.18
const SAIDA_T := 0.25
const SEGURA_T := 1.2
const CAPACIDADE := 5
const INTENSIDADE_MAX := 4

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
	fila.append(anuncio)
	if fila.size() > CAPACIDADE:
		fila.pop_front()


## Verdadeiro se há anúncio na tela ou esperando.
func ocupado() -> bool:
	return _ativo or not fila.is_empty()


## Um quadro: avança o anúncio da tela (e puxa o próximo da fila quando ele acaba).
func avancar(dt: float) -> void:
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


func _mostrar(anuncio: Dictionary) -> void:
	_ativo = true
	texto_ativo = str(anuncio["texto"])
	_cor = anuncio["cor"]
	_intensidade = int(anuncio["intensidade"])
	_segura = SEGURA_T + 0.1 * _intensidade
	_t = 0.0
	_texto.text = texto_ativo
	_texto.add_theme_color_override("font_color", _cor)
	var fonte: Font = _texto.get_theme_font("font")
	var largura := minf(fonte.get_string_size(texto_ativo, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_FONTE).x + FOLGA, LARGURA_MAX)
	size = Vector2(largura, ALTURA)
	pivot_offset = size * 0.5
	position = Vector2(roundf(CENTRO_X - largura * 0.5), _y)
	visible = true


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
