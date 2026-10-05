extends Node2D
## Palco lateral: a mesma sala vista de lado, como câmera de cinema em terceira pessoa.
## Os bonecos são os mesmos do jogo (desenho de lado), só que em dobro de tamanho.
## O fundo é capitulos/mapas/lado_<nome>.png (480x135; o chão fica em y 110 a 135).
## Se existir lado_<nome>_frente.png, ele é desenhado na frente dos bonecos (banco, mesa...).
## Na cena:  !lateral presidencia [x da câmera]   ...   !lateral fim

const Personagem := preload("res://scripts/personagem.gd")
const ESCALA := 2.0
const CHAO := 126.0           # y do pé de quem está em pé no chão (em pixels do fundo)
const LONGE := Vector2(-40000, -40000)   # onde o palco fica no mundo (longe do mapa)

var nome := ""
var tam := Vector2(480, 135)
var atores := Node2D.new()
var _fundo := Sprite2D.new()
var _frente := Sprite2D.new()


func montar(qual: String) -> bool:
	nome = qual
	position = LONGE
	scale = Vector2(ESCALA, ESCALA)
	var tex := Dados.imagem_mapa("lado_%s.png" % qual)
	if tex == null:
		return false
	tam = tex.get_size()
	_fundo.texture = tex
	_fundo.centered = false
	add_child(_fundo)
	atores.y_sort_enabled = true
	add_child(atores)
	var fr := Dados.imagem_mapa("lado_%s_frente.png" % qual)
	if fr:
		_frente.texture = fr
		_frente.centered = false
		_frente.z_index = 5
		add_child(_frente)
	return true


## Retângulo do palco no mundo (pros limites da câmera).
func area() -> Rect2:
	return Rect2(position, tam * ESCALA)


## Ponto do palco (x, y em pixels do fundo) no mundo.
func no_mundo(p: Vector2) -> Vector2:
	return position + p * ESCALA


func ator(id: String) -> Node2D:
	for n in atores.get_children():
		if n.id == id and not n.is_queued_for_deletion():
			return n
	return null


## Põe (ou muda de lugar) alguém no palco. y = 0 usa o chão.
func por(id: String, x: float, y: float, dir: String) -> Node2D:
	var n := ator(id)
	if n == null:
		n = Personagem.new()
		n.configurar(id, dir if dir in ["esquerda", "direita"] else "direita")
		atores.add_child(n)
	n.position = Vector2(x, y if y > 0.0 else CHAO)
	if dir in ["esquerda", "direita"]:
		n.dir = dir
	return n


func tirar(id: String) -> void:
	var n := ator(id)
	if n:
		var tw := create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.3)
		tw.tween_callback(n.queue_free)


## De onde alguém entra / pra onde sai: as bordas do palco.
func borda(lado: String, y: float) -> Vector2:
	return Vector2(-24.0 if lado != "direita" else tam.x + 24.0, y if y > 0.0 else CHAO)
