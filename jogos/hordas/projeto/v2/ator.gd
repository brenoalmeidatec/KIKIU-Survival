extends RefCounted
## Um ator do mundo v2: herói, monstro ou objeto de cenário (parado). Guarda o nó, a posição real e o que o sistema de sombras precisa.
## `pos` é a posição real (float) nos pés; `raiz.position` recebe `pos` ARREDONDADA (o pixel art não treme com sprite em meio pixel).

var chave := ""
var raiz: Node2D  # nó nos pés; no cenário é o próprio sprite
var sprite: Sprite2D  # o corpo
var tipo: Dictionary = {}  # ator animado: folha de sprites (sprites.gd); vazio no cenário
var linha := 0
var coluna := 0
var espelha := false
var pos := Vector2.ZERO
var estatico := true
var raio := 7.0  # raio do corpo no chão (colisão, v2/colisao.gd)
var ativo := false  # na tela (com margem): só ele tem sombra e gasta conta por quadro
var olho: Sprite2D = null  # brilho dos olhos (monstros), na camada sem escurecimento

# sombra (sombras.gd): altura do sprite, escala, comprimento máximo da sombra e o necessário para espelhar o sprite na silhueta
var alt := 40.0
var esc := 1.0
var rmax := 1.5
var offset := Vector2.ZERO
var regiao := Rect2()
var tex_n: Texture2D = null  # silhueta nítida (alta)
var tex_b: Texture2D = null  # silhueta borrada (média)
var larg_blob := 24.0
var blob: Sprite2D = null
var sh1: Sprite2D = null
var sh2: Sprite2D = null
var sl: Array[int] = [-1, -1]  # luz que cada sombra segue (alta)
var sv: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # vetor suavizado de cada sombra
var sa: Array[float] = [0.0, 0.0]  # alfa suavizado de cada sombra
var t_ult := -1.0


func definir_pos(p: Vector2) -> void:
	pos = p
	raiz.position = p.round()


## Folha de sprites animada: o corpo é filho da raiz, com o recorte da linha e coluna.
func montar_animado(pai: Node, t: Dictionary, p: Vector2, l: int, c: int, esp: bool) -> void:
	tipo = t
	estatico = false
	raiz = Node2D.new()
	pai.add_child(raiz)
	sprite = Sprite2D.new()
	sprite.texture = t.tex
	sprite.region_enabled = true
	sprite.centered = false
	sprite.offset = Vector2(-t.w / 2.0, -t.pe)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	raiz.add_child(sprite)
	linha = l
	coluna = c
	espelha = esp
	sprite.flip_h = esp
	sprite.region_rect = Rect2(c * t.w, l * t.h, t.w, t.h)
	alt = float(t.pe)
	offset = sprite.offset
	regiao = sprite.region_rect
	tex_n = t.alb
	tex_b = t.blur
	larg_blob = t.w * 0.75
	rmax = 1.5
	definir_pos(p)


## Troca o quadro (e o espelhamento): corpo, olhos e as duas sombras andam juntos.
func quadro(c: int, l := -1, esp := false, trocar_esp := false) -> void:
	if l >= 0:
		linha = l
	if trocar_esp:
		espelha = esp
		sprite.flip_h = esp
		if sh1 != null:
			sh1.flip_h = esp
			sh2.flip_h = esp
		if olho != null:
			olho.flip_h = esp
	coluna = c
	var r := Rect2(c * tipo.w, linha * tipo.h, tipo.w, tipo.h)
	sprite.region_rect = r
	regiao = r
	if sh1 != null:
		sh1.region_rect = r
		sh2.region_rect = r
	if olho != null:
		olho.region_rect = r
