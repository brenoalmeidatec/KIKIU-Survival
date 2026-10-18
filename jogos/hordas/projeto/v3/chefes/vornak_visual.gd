extends Node2D
## Desenho do Vornak da v3: toca as folhas de 8 direções (assets/v3/chefes/vornak_<clipe>_8dir.png) e segue o estado do chefe.
## Não decide nada de combate: recebe o chefe (v3/chefes/vornak.gd) e mostra o quadro certo. Quadro de 128 px, pé no centro de baixo.

const PASTA := "res://assets/v3/chefes/"
const DIRECOES := ["S", "SE", "L", "NE", "N", "NO", "O", "SO"]
const VETORES := [Vector2(0, 1), Vector2(0.7071, 0.7071), Vector2(1, 0), Vector2(0.7071, -0.7071),
	Vector2(0, -1), Vector2(-0.7071, -0.7071), Vector2(-1, 0), Vector2(-0.7071, 0.7071)]

var chefe
var clipe := "idle"
var direcao := 0
var quadro := 0.0
var _folhas := {}
var _clipes := {}
var quadro_tamanho := 128


func _ready() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "vornak_sprites.json"))
	if dados is Dictionary:
		quadro_tamanho = int(dados.tamanho_quadro)
		_clipes = dados.clipes


func ligar(c) -> void:
	chefe = c


## Escolhe a direção a partir do vetor de mira (ou de onde o chefe anda), pela mais próxima das 8.
func olhar_para(v: Vector2) -> void:
	if v.length() < 0.001:
		return
	var n := v.normalized()
	var melhor := 0.0
	for i in VETORES.size():
		var s := n.dot(VETORES[i])
		if i == 0 or s > melhor:
			melhor = s
			direcao = i


func _folha(nome: String) -> Texture2D:
	if not _folhas.has(nome):
		var img := Image.load_from_file(ProjectSettings.globalize_path(PASTA + "vornak_%s_8dir.png" % nome))
		_folhas[nome] = ImageTexture.create_from_image(img) if img != null else null
	return _folhas[nome]


func _process(delta: float) -> void:
	if chefe == null:
		return
	clipe = chefe.clip_atual()
	var n := int(_clipes.get(clipe, {"quadros": 1, "fps": 12}).quadros)
	var fps := float(_clipes.get(clipe, {"fps": 12}).fps)
	quadro = fmod(quadro + delta * fps, float(n))
	queue_redraw()


func _draw() -> void:
	var tex := _folha(clipe)
	if tex == null:
		return
	var q := int(quadro)
	var r := Rect2(q * quadro_tamanho, direcao * quadro_tamanho, quadro_tamanho, quadro_tamanho)
	var dest := Rect2(-quadro_tamanho / 2.0, -quadro_tamanho, quadro_tamanho, quadro_tamanho)
	draw_texture_rect_region(tex, dest, r)
