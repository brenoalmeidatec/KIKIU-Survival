extends RefCounted
## Cursor da v2 em pixel art: seta nos menus e mira (retícula) na partida. Troca só o cursor da janela; o mouse
## continua o mesmo (a mira do mundo segue mouse_na_tela()). A arte fica em assets/v2/cursor/ e é gerada por v2/gerar_cursor.gd.
## Se a arte faltar, volta ao cursor do sistema.

const PASTA := "res://assets/v2/cursor/"
## Ponta da seta = canto de cima à esquerda da imagem (célula 0, 0 em 2 px).
const PONTA_SETA := Vector2(0, 0)
## Centro da mira: célula (6, 6) em 2 px, ou seja, o pixel 13 de uma imagem de 26x26.
const PONTA_MIRA := Vector2(13, 13)

static var _modo := ""
static var _textura := {}


## modo: "seta" (menus) ou "mira" (partida). Chamar de novo com o mesmo modo não faz nada.
static func aplicar(modo: String) -> void:
	if modo == _modo:
		return
	_modo = modo
	var tex: Texture2D = _carregar(modo)
	if tex == null:
		Input.set_custom_mouse_cursor(null)
		return
	var ponta := PONTA_MIRA if modo == "mira" else PONTA_SETA
	# A seta vale para o ponteiro padrão e para o de botão (o jogo tem botões em todo menu).
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, ponta)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_POINTING_HAND, ponta)


static func _carregar(modo: String) -> Texture2D:
	if _textura.has(modo):
		return _textura[modo]
	var img := Image.load_from_file(PASTA + modo + ".png")
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null else null
	_textura[modo] = tex
	return tex
