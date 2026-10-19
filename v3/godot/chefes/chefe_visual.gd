extends Node2D
## Desenho de chefe da v3: toca as folhas de 8 direções (assets/chefes/<prefixo>_<clipe>_8dir.png) e segue o estado do chefe.
## Não decide nada de combate: recebe o chefe (chefe_base.gd e filhos) e mostra o quadro certo.
## Cada clipe tem o seu tamanho de quadro ("tamanho" no json, 192 ou 288 px, mesma escala de pixel); o pé fica na âncora
## (0,5; 0,744) do quadro, igual em todos, então o jogo alinha pelo pé.

const PASTA := "res://assets/chefes/"
const ANCORA := Vector2(0.5, 0.744)
const VETORES := [Vector2(0, 1), Vector2(0.7071, 0.7071), Vector2(1, 0), Vector2(0.7071, -0.7071),
	Vector2(0, -1), Vector2(-0.7071, -0.7071), Vector2(-1, 0), Vector2(-0.7071, 0.7071)]

var prefixo := "vornak"
var chefe
var clipe := "idle"
var direcao := 0
var quadro := 0.0
var _folhas := {}
var _clipes := {}
var tamanho_padrao := 192


func _ready() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string(PASTA + prefixo + "_sprites.json"))
	if dados is Dictionary:
		tamanho_padrao = int(dados.get("tamanho_quadro", 192))
		_clipes = dados.clipes


func ligar(c) -> void:
	chefe = c


## Escolhe a direção a partir do vetor de mira (ou de onde o chefe anda), pela mais próxima das 8.
func olhar_para(v: Vector2) -> void:
	if v.length() < 0.001:
		return
	var n := v.normalized()
	var melhor := -2.0
	for i in VETORES.size():
		var s := n.dot(VETORES[i])
		if s > melhor:
			melhor = s
			direcao = i


func _info(nome: String) -> Dictionary:
	return _clipes.get(nome, {"quadros": 1, "fps": 12, "tamanho": tamanho_padrao})


func _tamanho(nome: String) -> int:
	return int(_info(nome).get("tamanho", tamanho_padrao))


func _folha(nome: String) -> Texture2D:
	if not _folhas.has(nome):
		var img := Image.load_from_file(ProjectSettings.globalize_path(PASTA + "%s_%s_8dir.png" % [prefixo, nome]))
		_folhas[nome] = ImageTexture.create_from_image(img) if img != null else null
	return _folhas[nome]


func _process(delta: float) -> void:
	if chefe == null:
		return
	clipe = chefe.clip_atual()
	var info := _info(clipe)
	quadro = fmod(quadro + delta * float(info.get("fps", 12.0)), float(info.quadros))
	queue_redraw()


func _draw() -> void:
	var tex := _folha(clipe)
	if tex == null:
		return
	var t := _tamanho(clipe)
	var q := int(quadro)
	var r := Rect2(q * t, direcao * t, t, t)
	var dest := Rect2(-t * ANCORA.x, -t * ANCORA.y, t, t)
	draw_texture_rect_region(tex, dest, r)
