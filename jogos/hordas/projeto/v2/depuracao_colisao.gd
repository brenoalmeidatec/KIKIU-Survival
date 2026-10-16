extends Node2D
## Depuração de colisão da v2 (tecla F4 no mundo, ou --colisao): desenha por cima do mundo o contorno fino de cada forma
## registrada em v2/colisao.gd (amarelo: a pegada das árvores, pedras, muros etc. como elipse, e prédios, carros etc. como retângulo) e o círculo do corpo do herói e dos
## monstros (vermelho). Desligado por padrão e só desenha quando visível. Não altera a colisão: só lê.

const Colisao := preload("res://v2/colisao.gd")
const SEGMENTOS := 28
const COR_FORMA := Color(1.0, 0.92, 0.2, 0.9)
const COR_CORPO := Color(1.0, 0.25, 0.25, 0.95)

var mundo  # o mundo.gd: herói, monstros e câmera (coordenadas do mundo = coordenadas deste nó)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if mundo == null or mundo.cam == null:
		return
	var tela: Rect2 = mundo.cam.retangulo().grow(8.0)
	for f in Colisao.formas_no_retangulo(tela):
		if f.tipo == "caixa":
			draw_rect(Rect2(f.c - Vector2(f.hx, f.hy), Vector2(f.hx, f.hy) * 2.0), COR_FORMA, false, 1.0)
		else:
			_elipse(f.c, f.rx, f.ry, COR_FORMA)
	var atores: Array = [mundo.heroi]
	atores.append_array(mundo.monstros)
	for a in atores:
		_elipse(a.pos, a.raio, a.raio * 0.5, COR_CORPO)


func _elipse(c: Vector2, rx: float, ry: float, cor: Color) -> void:
	var pontos := PackedVector2Array()
	for i in SEGMENTOS + 1:
		var t := TAU * float(i) / float(SEGMENTOS)
		pontos.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	draw_polyline(pontos, cor, 1.0)
