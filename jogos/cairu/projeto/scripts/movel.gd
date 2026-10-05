extends Node2D
## Móvel desenhado em código; a posição é o "pé" do objeto (para ordenar na frente/atrás).

var tipo := "carteira"
var tam_solido := Vector2.ZERO   # para objetos de imagem: largura x altura da base que bloqueia
var balanco := 0.0               # "balanco": árvore/planta balança no vento (graus de inclinação)
var _t := randf() * 10.0
var _tremer := 0.0
var _x0 := 0.0
var _tam_img := Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
	var sk := 0.0
	if balanco != 0.0 and Visual.ligado():
		sk = deg_to_rad(balanco) * (sin(_t * 1.3) * 0.7 + sin(_t * 2.9) * 0.3)
	skew = sk
	if _tremer > 0.0:
		_tremer -= delta
		var k := 1.0 if int(_tremer * 40.0) % 2 == 0 else -1.0
		position.x = _x0 + (k if _tremer > 0.0 else 0.0)


## Treme um pouquinho (quando o jogador interage com ele).
func tremer(tempo := 0.25) -> void:
	if _tremer <= 0.0:
		_x0 = position.x
	_tremer = tempo


## Retângulo que o desenho ocupa no mapa (pra saber em quem o jogador mexeu).
func area() -> Rect2:
	if tipo == "imagem":
		return Rect2(position.x - _tam_img.x / 2, position.y - _tam_img.y, _tam_img.x, _tam_img.y)
	return Rect2(position.x - 16, position.y - 36, 32, 36)


## Objeto feito de imagem (ex.: "arvore.png"): o pé da imagem fica na posição.
func usar_imagem(tex: Texture2D) -> void:
	tipo = "imagem"
	_tam_img = tex.get_size()
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	add_child(s)


func solido() -> Rect2:
	match tipo:
		"imagem": return Rect2(position.x - tam_solido.x / 2, position.y - tam_solido.y, tam_solido.x, tam_solido.y)
		"mesa_prof": return Rect2(position.x - 32, position.y - 12, 64, 12)
		"planta": return Rect2(position.x - 7, position.y - 6, 14, 6)
		"lixeira": return Rect2(position.x - 5, position.y - 5, 10, 5)
		_: return Rect2(position.x - 14, position.y - 8, 28, 8)


func _draw() -> void:
	match tipo:
		"carteira":
			draw_rect(Rect2(-11, -36, 22, 14), Color("1f3fbf"))      # encosto azul
			draw_rect(Rect2(-11, -36, 22, 2), Color("4b6cf0"))
			draw_rect(Rect2(-10, -22, 2, 22), Color("444a5e"))       # pernas
			draw_rect(Rect2(8, -22, 2, 22), Color("444a5e"))
			draw_rect(Rect2(-14, -22, 28, 8), Color("b9824a"))       # prancheta
			draw_rect(Rect2(-14, -22, 28, 1), Color("dba76c"))
			draw_rect(Rect2(-14, -15, 28, 1), Color("7a522c"))
			draw_rect(Rect2(-13, 0, 26, 1), Color(0, 0, 0, 0.18))    # sombra
		"mesa_prof":
			draw_rect(Rect2(-32, -28, 64, 4), Color("a06a38"))
			draw_rect(Rect2(-32, -28, 64, 1), Color("cf9256"))
			draw_rect(Rect2(-30, -24, 60, 24), Color("7e4f27"))
			draw_rect(Rect2(-28, -22, 56, 1), Color("94602f"))
			draw_rect(Rect2(-12, -38, 16, 10), Color("2b2f3a"))      # notebook
			draw_rect(Rect2(-11, -37, 14, 8), Color("6fc3ff"))
			draw_rect(Rect2(10, -32, 10, 4), Color("f3efe2"))        # papéis
			draw_rect(Rect2(-32, 0, 64, 1), Color(0, 0, 0, 0.2))
		"planta":
			draw_rect(Rect2(-6, -10, 12, 10), Color("b5562f"))
			draw_rect(Rect2(-7, -11, 14, 2), Color("d06b3e"))
			for f in [[-9, -24, 6, 14], [-3, -30, 6, 20], [3, -26, 6, 16], [-6, -18, 12, 8]]:
				draw_rect(Rect2(f[0], f[1], f[2], f[3]), Color("2f8a3a"))
			draw_rect(Rect2(-2, -28, 2, 10), Color("49b555"))
		"lixeira":
			draw_rect(Rect2(-5, -12, 10, 12), Color("3d7a4a"))
			draw_rect(Rect2(-6, -13, 12, 2), Color("58a067"))
