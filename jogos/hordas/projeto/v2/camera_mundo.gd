extends Camera2D
## Câmera da v2: segue o herói com suavização exponencial, presa nos limites do mapa e com a posição ARREDONDADA em pixel inteiro
## (o pixel art não treme quando a câmera anda). A conta da posição fica em `pos` (float); `position` recebe o valor inteiro.

const LARG := 960
const ALT := 540

var limites := Rect2(0, 0, 2880, 1620)  # o mapa, em px do mundo
var suavidade := 6.0  # pos = lerp(alvo, 1 - exp(-suavidade * dt)); maior = mais colada no herói
var pos := Vector2(480, 270)  # centro da câmera, antes de arredondar


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
	position = pos.round()


## O que a câmera mostra agora (mundo), com uma margem em volta.
func retangulo(margem := 0.0) -> Rect2:
	return Rect2(position - Vector2(LARG, ALT) / 2.0, Vector2(LARG, ALT)).grow(margem)
