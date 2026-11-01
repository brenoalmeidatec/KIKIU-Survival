extends RefCounted
## Um ator do mundo v2: herói, monstro ou objeto de cenário (parado). Guarda o nó, a posição real e o que o sistema de sombras precisa.
## `pos` é a posição real (float) nos pés; `raiz.position` recebe `pos` ARREDONDADA (o pixel art não treme com sprite em meio pixel).


## Posição e visibilidade de um ator desenhado em lote (v2/horda.gd): no lugar do nó `raiz`, para quem só lê `raiz.position` e `raiz.visible`.
class Ponto:
	extends RefCounted
	var position := Vector2.ZERO
	var visible := true


var chave := ""
var raiz  # nó nos pés (Node2D); no cenário é o próprio sprite; monstro em lote: um Ponto, sem nó
var sprite: Sprite2D  # o corpo (null no monstro em lote)
var lote := false  # monstro comum: desenhado pelo lote da horda, sem nós (v2/horda.gd)
var tipo: Dictionary = {}  # ator animado: folha de sprites (sprites.gd); vazio no cenário
var linha := 0
var coluna := 0
var espelha := false
var pos := Vector2.ZERO
var pr := Vector2.ZERO  # `pos` arredondada: onde o ator é desenhado (o mesmo que raiz.position)
var estatico := true
var raio := 7.0  # raio do corpo no chão (colisão, v2/colisao.gd)
var escala := 1.0  # tamanho do sprite (elite e chefe são maiores)
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
var b_esc := 1.0  # mancha dos pés calculada por sombras.calcular: escala e alfa
var b_alfa := 0.4


func definir_pos(p: Vector2) -> void:
	pos = p
	pr = p.round()
	raiz.position = pr


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


## Troca a folha do ator animado sem recriar nós (as duas formas do LightWolf, v2/mecha.gd): textura, pé, silhueta e as duas sombras. O quadro atual
## (linha e coluna) continua, preso aos limites da folha nova (uma folha com menos linhas ou colunas não deixa o recorte sair dela); quem anima o
## reescreve no quadro seguinte.
func trocar_tipo(t: Dictionary) -> void:
	var media: bool = sh1 != null and sh1.texture == tex_b  # a sombra está no modo médio (silhueta borrada) ou no alto (nítida)?
	tipo = t
	sprite.texture = t.tex
	sprite.offset = Vector2(-t.w / 2.0, -t.pe)
	alt = float(t.pe)
	offset = sprite.offset
	tex_n = t.alb
	tex_b = t.blur
	larg_blob = t.w * 0.75
	linha = clampi(linha, 0, maxi(int(t.alb.get_height()) / int(t.h) - 1, 0))
	coluna = clampi(coluna, 0, maxi(int(t.alb.get_width()) / int(t.w) - 1, 0))
	regiao = Rect2(coluna * t.w, linha * t.h, t.w, t.h)
	sprite.region_rect = regiao
	if sh1 != null:
		var tx: Texture2D = tex_b if media else tex_n
		for s in [sh1, sh2]:
			s.texture = tx
			s.offset = offset
			s.region_rect = regiao
	t_ult = -1.0  # a sombra se recalcula no próximo quadro


## Monstro em lote: os mesmos números de `montar_animado`, mas sem nenhum nó (quem desenha é v2/horda.gd).
func montar_lote(t: Dictionary, p: Vector2, l: int, c: int, esp: bool) -> void:
	tipo = t
	estatico = false
	lote = true
	raiz = Ponto.new()
	linha = l
	coluna = c
	espelha = esp
	regiao = Rect2(c * t.w, l * t.h, t.w, t.h)
	offset = Vector2(-t.w / 2.0, -t.pe)
	alt = float(t.pe)
	tex_n = t.alb
	tex_b = t.blur
	larg_blob = t.w * 0.75
	rmax = 1.5
	definir_pos(p)


## Troca o quadro (e o espelhamento): corpo, olhos e as duas sombras andam juntos. Em lote (sem nós) só mudam os números.
func quadro(c: int, l := -1, esp := false, trocar_esp := false) -> void:
	if l >= 0:
		linha = l
	if trocar_esp:
		espelha = esp
	coluna = c
	regiao = Rect2(c * tipo.w, linha * tipo.h, tipo.w, tipo.h)
	if sprite == null:
		return
	if trocar_esp:
		sprite.flip_h = esp
		if sh1 != null:
			sh1.flip_h = esp
			sh2.flip_h = esp
		if olho != null:
			olho.flip_h = esp
	sprite.region_rect = regiao
	if sh1 != null:
		sh1.region_rect = regiao
		sh2.region_rect = regiao
	if olho != null:
		olho.region_rect = regiao
