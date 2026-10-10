extends RefCounted
## Atlas das folhas dos inimigos (#127): as folhas dos tipos que aparecem na fase viram UMA textura só, pra a horda inteira
## ser desenhada por um MultiMeshInstance2D (uma chamada de desenho) sem perder a ordem por altura entre tipos diferentes.
## Cada folha entra na primeira vez que o tipo nasce (prateleiras, de cima pra baixo). A arena é recriada a cada fase, então
## o atlas é "por região": só tem as folhas que a região usa. Se um dia faltar lugar (4096 de altura), ele é refeito do zero
## (`geracao` muda e cada bicho pede o deslocamento de novo).

const Visual := preload("res://scripts/hordas/visual.gd")
const LARG := 2048
const ALT_INI := 1024
const ALT_MAX := 4096

var textura: ImageTexture
var geracao := 0
var _img: Image
var _pos := {}          # Texture2D -> Vector2 (canto da folha no atlas, em pixels)
var _x := 0
var _y := 0
var _prat := 0
var _sujo := false


func _init() -> void:
	_novo(ALT_INI)


func _novo(alt: int) -> void:
	_img = Image.create_empty(LARG, alt, false, Image.FORMAT_RGBA8)
	textura = ImageTexture.create_from_image(_img)
	_sujo = false


## Canto (em pixels) da folha `t` dentro do atlas; põe a folha lá na primeira vez.
func deslocamento(t: Texture2D) -> Vector2:
	var p = _pos.get(t)
	if p != null:
		return p
	var im: Image = Visual.imagem(t)
	var w := im.get_width()
	var h := im.get_height()
	if _x + w > LARG:
		_x = 0
		_y += _prat
		_prat = 0
	while _y + h > _img.get_height():
		if _img.get_height() >= ALT_MAX:
			_refazer()
			return deslocamento(t)
		_crescer()
	_img.blit_rect(im, Rect2i(0, 0, w, h), Vector2i(_x, _y))
	var o := Vector2(_x, _y)
	_pos[t] = o
	_x += w
	_prat = maxi(_prat, h)
	_sujo = true
	return o


func _crescer() -> void:
	var nova := Image.create_empty(LARG, mini(_img.get_height() * 2, ALT_MAX), false, Image.FORMAT_RGBA8)
	nova.blit_rect(_img, Rect2i(0, 0, LARG, _img.get_height()), Vector2i.ZERO)
	_img = nova
	textura = ImageTexture.create_from_image(_img)   # textura nova: quem usa o atlas confere `textura` todo quadro
	_sujo = false


func _refazer() -> void:
	_pos.clear()
	_x = 0
	_y = 0
	_prat = 0
	geracao += 1
	_novo(ALT_INI)


## Manda pra placa de vídeo o que entrou desde o último envio (chamar uma vez por quadro, antes de desenhar).
func enviar() -> void:
	if _sujo:
		textura.update(_img)
		_sujo = false
