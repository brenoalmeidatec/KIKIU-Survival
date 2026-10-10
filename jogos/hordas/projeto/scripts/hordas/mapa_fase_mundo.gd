extends Node2D
## Mapa fechado da fase no mundo (#128, parte 2): desenha a grade de mapa_fase.gd, diz se um ponto é parede (o herói
## não atravessa; quem usa é a arena) e mostra o minimapa com a névoa. Cores são provisórias: a arte de verdade entra
## depois. Os inimigos ainda não respeitam o relevo (inimigos.gd fica para depois dos Marcos 2 e 3).

const MapaFase := preload("res://scripts/hordas/mapa_fase.gd")

const TILE := 32.0
const RAIO_PES := 8.0          # tamanho da caixa de colisão do herói (px, em volta dos pés)
const PES := Vector2(0, -6)    # os pés ficam um pouco acima da posição do herói
const RAIO_NEBLINA := 10       # tiles que o herói revela em volta de si no minimapa (#128)
const MINI := Vector2(96, 64)  # tamanho do minimapa na tela (#128)
const CORES := {
	".": Color(0.24, 0.21, 0.17), "#": Color(0.11, 0.1, 0.12), "~": Color(0.1, 0.22, 0.38), "=": Color(0.5, 0.37, 0.22),
	"o": Color(0.42, 0.42, 0.48), "j": Color(0.95, 0.55, 0.2), "s": Color(0.62, 0.6, 0.45), "p": Color(0.45, 0.85, 0.2),
	"l": Color(0.33, 0.28, 0.14), "e": Color(0.68, 0.88, 1.0),
	"v": Color(0.18, 0.32, 0.14), "c": Color(0.72, 0.7, 0.6), "x": Color(0.8, 0.6, 0.3), "k": Color(0.6, 0.84, 1.0), "f": Color(0.9, 0.3, 0.1),
}

var w := 0
var h := 0
var grade := PackedStringArray()
var origem := Vector2.ZERO     # canto de cima-esquerda do mapa, no mundo (o começo do herói cai em (0, 0))
var visto := PackedByteArray() # névoa do minimapa: 1 = o herói já passou perto
var _mini_tela: Control
var _pos_mini := Vector2.ZERO  # onde o herói está, para o ponto do minimapa


func _ready() -> void:
	z_index = -9   # por cima do chão, embaixo de inimigos e herói
	var camada := CanvasLayer.new()
	camada.layer = 4
	add_child(camada)
	_mini_tela = Control.new()
	_mini_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_tela.size = MINI
	_mini_tela.anchor_left = 1.0
	_mini_tela.anchor_top = 1.0
	_mini_tela.anchor_right = 1.0
	_mini_tela.anchor_bottom = 1.0
	_mini_tela.offset_left = -MINI.x - 6
	_mini_tela.offset_top = -MINI.y - 16
	_mini_tela.offset_right = -6
	_mini_tela.offset_bottom = -16
	_mini_tela.draw.connect(_desenhar_mini)
	camada.add_child(_mini_tela)


## Monta o mapa de uma fase: `mapa` é o dicionário de MapaFase.gerar.
func configurar(mapa: Dictionary) -> void:
	w = int(mapa.largura)
	h = int(mapa.altura)
	grade = mapa.linhas
	var inicio: Vector2i = mapa.inicio
	origem = -(Vector2(inicio) + Vector2(0.5, 0.5)) * TILE
	visto = PackedByteArray()
	visto.resize(w * h)
	visto.fill(0)
	queue_redraw()


func tile_de(p: Vector2) -> Vector2i:
	var t := (p - origem) / TILE
	return Vector2i(floori(t.x), floori(t.y))


## Parede (ou fora do mapa) no ponto do mundo.
func parede_em(p: Vector2) -> bool:
	var t := tile_de(p)
	if t.x < 0 or t.y < 0 or t.x >= w or t.y >= h:
		return true
	return not MapaFase.passavel(grade[t.y][t.x])


## Ponto livre mais perto de `p`: o portal (e o que mais nasce no chão) não fica dentro de parede. Sem tile livre por perto, devolve `p`.
func ponto_livre_perto(p: Vector2) -> Vector2:
	if not parede_em(p):
		return p
	var c := tile_de(p)
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := c + Vector2i(dx, dy)
				if t.x >= 0 and t.y >= 0 and t.x < w and t.y < h and MapaFase.passavel(grade[t.y][t.x]):
					return origem + (Vector2(t) + Vector2(0.5, 0.5)) * TILE
	return p


## Caixa de colisão do herói (4 cantos em volta dos pés) bate em alguma parede?
func bate_heroi(pos: Vector2) -> bool:
	var pe := pos + PES
	for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		if parede_em(pe + d * RAIO_PES):
			return true
	return false


## O herói andou para dentro de uma parede: volta para onde estava, escorregando se só um eixo bate.
func prender(j: Node2D, antes: Vector2) -> void:
	if not bate_heroi(j.position):
		return
	var so_x := Vector2(j.position.x, antes.y)
	if not bate_heroi(so_x):
		j.position = so_x
		return
	var so_y := Vector2(antes.x, j.position.y)
	if not bate_heroi(so_y):
		j.position = so_y
		return
	j.position = antes


## Névoa: o que está até RAIO_NEBLINA tiles do herói fica visto (no minimapa).
func atualizar(pos_heroi: Vector2) -> void:
	var t := tile_de(pos_heroi)
	if t.x >= 0 and t.y >= 0 and t.x < w and t.y < h:
		MapaFase.revelar(visto, w, h, t, RAIO_NEBLINA)
	_mini_tela.queue_redraw()


func _draw() -> void:
	if w == 0:
		return
	var vis: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()   # só o que cai na tela
	var a := tile_de(vis.position)
	var b := tile_de(vis.end)
	for y in range(maxi(0, a.y), mini(h, b.y + 1)):
		for x in range(maxi(0, a.x), mini(w, b.x + 1)):
			var ch: String = grade[y][x]
			draw_rect(Rect2(origem + Vector2(x, y) * TILE, Vector2(TILE, TILE)), _cor(ch))


func _cor(ch: String) -> Color:
	return CORES.get(ch, Color(0.3, 0.25, 0.35))   # letra desconhecida (tema de portão novo) vira uma cor neutra


## Minimapa: só o que foi visto aparece; o herói é um ponto (desenhado com a posição dele em `_pos_mini`).

func _desenhar_mini() -> void:
	if w == 0:
		return
	var s := minf(MINI.x / w, MINI.y / h)
	var ox := (MINI.x - w * s) * 0.5
	var oy := (MINI.y - h * s) * 0.5
	_mini_tela.draw_rect(Rect2(Vector2.ZERO, MINI), Color(0.02, 0.02, 0.04, 0.7))
	for y in h:
		for x in w:
			if visto[y * w + x] == 0:
				continue
			var cor := _cor(grade[y][x])
			cor.a = 0.7
			_mini_tela.draw_rect(Rect2(Vector2(ox + x * s, oy + y * s), Vector2(s, s)), cor)
	var t := tile_de(_pos_mini)
	if t.x >= 0 and t.y >= 0 and t.x < w and t.y < h:
		_mini_tela.draw_circle(Vector2(ox + (t.x + 0.5) * s, oy + (t.y + 0.5) * s), 2.0, Color(1, 0.95, 0.4))


## Posição do herói para o minimapa e a névoa (chamado pela arena a cada quadro).
func marcar_heroi(pos: Vector2) -> void:
	_pos_mini = pos
	atualizar(pos)
