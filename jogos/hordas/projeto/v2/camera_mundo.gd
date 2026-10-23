extends Camera2D
## Câmera da v2: segue o herói com suavização exponencial, presa nos limites do mapa e com a posição ARREDONDADA em pixel inteiro
## (o pixel art não treme quando a câmera anda). A conta da posição fica em `pos` (float); `position` recebe o valor inteiro.

const LARG := 960
const ALT := 540

var limites := Rect2(0, 0, 2880, 1620)  # o mapa, em px do mundo
var suavidade := 6.0  # pos = lerp(alvo, 1 - exp(-suavidade * dt)); maior = mais colada no herói
var pos := Vector2(480, 270)  # centro da câmera, antes de arredondar
var tremor_amp := 0.0  # px do tremor de câmera (golpe forte, crítico, morte): sempre deslocamento em pixel INTEIRO
var tremor_dur := 0.16
var tremor_t := 0.0
var deslocamento := Vector2.ZERO  # o tremor deste quadro (inteiro)
var soco := 0.0  # o "soco" de zoom do impacto (0,04 = 4% mais perto), que volta sozinho em ~0,2 s
var _rng := RandomNumberGenerator.new()  # o sorteio do tremor: fora do randf() global, de que o jogo e os testes (seed) dependem


func _ready() -> void:
	ignore_rotation = true
	position_smoothing_enabled = false  # a suavização é nossa (a do Camera2D não arredonda)
	make_current()


## Centro da câmera dentro do mapa: a tela nunca mostra nada fora de `limites`.
func prender(c: Vector2) -> Vector2:
	var meio := Vector2(LARG, ALT) / 2.0
	var a := limites.position + meio
	var b := limites.end - meio
	return Vector2(clampf(c.x, a.x, maxf(a.x, b.x)), clampf(c.y, a.y, maxf(a.y, b.y)))


## Põe a câmera direto no alvo (início da fase, teleporte).
func cravar(alvo: Vector2) -> void:
	pos = prender(alvo)
	position = pos.round()


func seguir(alvo: Vector2, dt: float) -> void:
	pos = prender(pos.lerp(alvo, 1.0 - exp(-suavidade * dt)))
	deslocamento = Vector2.ZERO
	if tremor_t > 0.0:
		tremor_t -= dt
		var a := roundi(tremor_amp * clampf(tremor_t / tremor_dur, 0.0, 1.0))
		if a > 0:
			deslocamento = Vector2(_rng.randi_range(-a, a), _rng.randi_range(-a, a))
	position = pos.round() + deslocamento
	if soco > 0.0005:
		soco *= exp(-14.0 * dt)
		zoom = Vector2.ONE * (1.0 + soco)
	elif soco > 0.0:
		soco = 0.0
		zoom = Vector2.ONE


## Tremor de câmera: `amp` px no começo, caindo até zero em `dur` s. Um tremor mais fraco não atropela um mais forte em andamento.
## A opção "Tremor e clarões" (tremor_clarao, 0 a 100%) da aba Gráficos escala `amp`; em 0% a câmera não treme.
func tremer(amp: float, dur := 0.16) -> void:
	var forca = Config.g("tremor_clarao")
	if forca != null:
		amp *= clampf(float(forca) / 100.0, 0.0, 1.0)
	if amp <= 0.0:
		return
	if amp >= tremor_amp * clampf(tremor_t / tremor_dur, 0.0, 1.0):
		tremor_amp = amp
		tremor_dur = maxf(dur, 0.01)
		tremor_t = dur


## Soco de zoom do impacto: a câmera chega `forca` mais perto (0,03 = 3%) num instante e volta com ease-out. Só desenho; a mira e o
## recorte da tela (`retangulo`) seguem no tamanho normal. Escala com a opção "Tremor e clarões" como o tremor; em 0% não soca.
func socar(forca: float) -> void:
	var f = Config.g("tremor_clarao")
	if f != null:
		forca *= clampf(float(f) / 100.0, 0.0, 1.0)
	soco = clampf(maxf(soco, forca), 0.0, 0.08)


## O centro da câmera sem o tremor (a mira do mouse usa este).
func centro_base() -> Vector2:
	return pos.round()


## O que a câmera mostra agora (mundo), com uma margem em volta.
func retangulo(margem := 0.0) -> Rect2:
	return Rect2(position - Vector2(LARG, ALT) / 2.0, Vector2(LARG, ALT)).grow(margem)
