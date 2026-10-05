extends CanvasLayer
## Close do rosto: um quadro de história em quadrinhos que entra no canto da tela com o
## rosto pixelado do personagem (o mesmo do diálogo) fazendo uma expressão.
## Na cena:  !rosto joao chorando [segundos] [esquerda|direita]   (& no fim = não espera)
## Expressões: normal, fala, rindo, chorando, dor, susto, pensando, cismado.

const W := 96
const H := 128
const EXPRESSOES := {
	"normal": [0], "fala": [0, 1, 2, 1, 3, 1], "rindo": [10, 4, 10, 2], "chorando": [9, 9, 2, 9, 3],
	"dor": [9, 2, 9, 3], "susto": [2, 3], "pensando": [11], "cismado": [12],
}
const FPS := {"fala": 9.0, "rindo": 6.0, "chorando": 4.0, "dor": 3.0, "susto": 10.0}

var quem := ""
var expr := "normal"
var lado := "direita"
var _quadro := Control.new()
var _rosto := Sprite2D.new()
var _efeitos := Node2D.new()
var _t := 0.0
var _lagrimas: Array = []     # [x, y, velocidade]
var _gotas: Array = []


func _ready() -> void:
	layer = 15
	var tex := _textura()
	var px := 480.0 - W - 22.0 if lado == "direita" else 22.0
	_quadro.position = Vector2(px, 34)
	_quadro.size = Vector2(W + 8, H + 22)
	add_child(_quadro)
	var borda := Panel.new()
	borda.add_theme_stylebox_override("panel", Visual.painel())
	borda.size = _quadro.size
	_quadro.add_child(borda)
	var clip := Control.new()
	clip.position = Vector2(4, 4)
	clip.size = Vector2(W, H)
	clip.clip_contents = true
	_quadro.add_child(clip)
	_rosto.texture = tex
	_rosto.centered = false
	_rosto.region_enabled = true
	_rosto.region_rect = Rect2(0, 0, W, H)
	clip.add_child(_rosto)
	_efeitos.draw.connect(_desenhar_efeitos)
	clip.add_child(_efeitos)
	var nome := Label.new()
	nome.text = Dados.nome(quem).to_upper()
	nome.add_theme_color_override("font_color", Color("ffd34e"))
	nome.position = Vector2(6, H + 6)
	_quadro.add_child(nome)
	# entra deslizando do lado, com um "tchan"
	var fora := 520.0 if lado == "direita" else -W - 40.0
	_quadro.position.x = fora
	var tw := create_tween()
	tw.tween_property(_quadro, "position:x", px, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Jogo.som("whoosh", -4.0)
	if expr in ["chorando", "dor", "susto"]:
		Jogo.som("tremor", -12.0)


func _textura() -> Texture2D:
	var t := Dados.textura(quem, "rosto_gemini")
	if t == null:
		return Dados.textura(quem, "rosto_hd")
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	var n := img.get_width() / 144
	img.resize(n * W, H, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_t += delta
	var ciclo: Array = EXPRESSOES.get(expr, [0])
	var q: int = ciclo[int(_t * FPS.get(expr, 1.0)) % ciclo.size()]
	if _rosto.texture and (q + 1) * W > _rosto.texture.get_width():
		q = 0
	_rosto.region_rect = Rect2(q * W, 0, W, H)
	# chorando / dor / susto: o rosto treme
	var trem: float = {"chorando": 1.0, "dor": 0.7, "susto": 1.5}.get(expr, 0.0)
	_rosto.position = Vector2(round(randf_range(-trem, trem)), round(sin(_t * 18.0) * trem * 0.6)) if trem > 0.0 and Visual.ligado() else Vector2.ZERO
	if expr == "chorando":
		if randf() < delta * 7.0:
			var olho := 0.36 if randf() < 0.5 else 0.64
			_lagrimas.append([W * olho + randf_range(-2, 2), H * 0.36, randf_range(22, 40)])
	if expr == "dor" and randf() < delta * 2.0:
		_gotas.append([W * randf_range(0.2, 0.8), H * 0.15, randf_range(10, 18)])
	for l in _lagrimas + _gotas:
		l[1] += l[2] * delta
	_lagrimas = _lagrimas.filter(func(l): return l[1] < H)
	_gotas = _gotas.filter(func(l): return l[1] < H * 0.5)
	_efeitos.queue_redraw()


func _desenhar_efeitos() -> void:
	for l in _lagrimas:
		_efeitos.draw_rect(Rect2(round(l[0]), round(l[1]), 2, 3), Color("8fd3ff"))
		_efeitos.draw_rect(Rect2(round(l[0]), round(l[1]), 1, 1), Color.WHITE)
	for g in _gotas:
		_efeitos.draw_rect(Rect2(round(g[0]), round(g[1]), 2, 3), Color("c8ecff"))


func sair() -> void:
	var fora := 520.0 if lado == "direita" else -W - 40.0
	var tw := create_tween()
	tw.tween_property(_quadro, "position:x", fora, 0.15).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()
