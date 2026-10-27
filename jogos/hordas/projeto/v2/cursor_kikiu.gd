extends RefCounted
## Cursor da v2 em pixel art. Nos menus é sempre a seta; na partida é a mira (ou a seta, se o jogador escolher).
## A cor vem das Opções (Config "cursor_cor"), e a forma da partida, de "cursor_forma". Não usa arquivo de imagem: a arte é
## a grade abaixo, desenhada em runtime com a cor escolhida. Sem imagem válida, volta ao cursor do sistema.
## Pixel 2x: a seta sai em 22x36 px e a mira em 26x26 px, para não ficar minúscula em 1080p.

const PX := 2
## Ponta da seta = canto de cima à esquerda (pixel 0, 0). Centro da mira = célula (6, 6), pixel 13 da imagem 26x26.
const PONTA_SETA := Vector2(0, 0)
const PONTA_MIRA := Vector2(13, 13)
## Cores: k = contorno (PAINEL), o = cor escolhida (o miolo e o destaque), "." = transparente.
const CONTORNO := Color("#01030b")
const CORES := {
	"ouro": Color("#ffdb6b"),
	"branco": Color("#ebe6f5"),
	"ciano": Color("#80f2ff"),
	"alma": Color("#cca8ff"),
}
const ROTULOS_COR := {"ouro": "Ouro", "branco": "Branco", "ciano": "Ciano", "alma": "Roxo"}
const FORMAS := ["mira", "seta"]
const ROTULOS_FORMA := {"mira": "Mira", "seta": "Seta"}

const SETA := [
	"k..........",
	"kk.........",
	"kok........",
	"kook.......",
	"koook......",
	"kooook.....",
	"koooook....",
	"kooooook...",
	"koooooook..",
	"kooooooook.",
	"koooooooook",
	"kooooookkkk",
	"kookook....",
	"kok.kook...",
	"kk..kook...",
	"k...kook...",
	"....kook...",
	".....kk....",
]
## Mira de 13x13: braços de 1 px com contorno, centro vazio para não tapar o alvo.
const MIRA := [
	"......k......",
	".....kok.....",
	".....kok.....",
	".....kok.....",
	".....kok.....",
	"kkkkk...kkkkk",
	"ooooo.o.ooooo",
	"kkkkk...kkkkk",
	".....kok.....",
	".....kok.....",
	".....kok.....",
	".....kok.....",
	"......k......",
]

static var _pedido := ""  # o que a tela pediu: "seta" (menus) ou "mira" (partida)
static var _aplicado := ""
static var _cache := {}


## modo: "seta" (menus) ou "mira" (partida). Trocar só a cor ou a forma usa refrescar().
static func aplicar(modo: String) -> void:
	_pedido = modo
	_aplicar_agora()


## Refaz o cursor com as Opções atuais (cor e forma), sem trocar de tela. Chamar depois de mudar a cor ou a forma.
static func refrescar() -> void:
	_aplicado = ""
	_aplicar_agora()


static func _aplicar_agora() -> void:
	var forma := _forma_efetiva()
	if forma == _aplicado:
		return
	_aplicado = forma
	var tex := _textura(forma)
	if tex == null:
		Input.set_custom_mouse_cursor(null)
		return
	var ponta := PONTA_MIRA if forma == "mira" else PONTA_SETA
	# A seta vale para o ponteiro padrão e para o de botão (o jogo tem botões em todo menu).
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, ponta)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_POINTING_HAND, ponta)


## "seta" nos menus; na partida, a forma escolhida (mira por padrão).
static func _forma_efetiva() -> String:
	if _pedido == "seta":
		return "seta"
	return "seta" if _opcao("cursor_forma", "mira") == "seta" else "mira"


static func cor_atual() -> String:
	var cor := _opcao("cursor_cor", "ouro")
	return cor if CORES.has(cor) else "ouro"


static func _opcao(chave: String, padrao: String) -> String:
	# O autoload Config pelo nó da árvore: assim o script também compila fora do jogo (o teste em --script).
	var raiz = Engine.get_main_loop() as SceneTree
	var cfg = raiz.root.get_node_or_null("Config") if raiz != null else null
	if cfg == null:
		return padrao
	var v = cfg.v(chave)
	return str(v) if v != null and str(v) != "" else padrao


static func _textura(forma: String) -> Texture2D:
	var chave := "%s/%s" % [forma, cor_atual()]
	if not _cache.has(chave):
		var grade: Array = SETA if forma == "seta" else MIRA
		_cache[chave] = ImageTexture.create_from_image(montar(grade, CORES[cor_atual()]))
	return _cache[chave]


## Monta a imagem de uma grade: cada letra vira um bloco de PX por PX. Público para o teste e as fotos.
static func montar(grade: Array, cor: Color) -> Image:
	var largura := 0
	for linha in grade:
		largura = maxi(largura, linha.length())
	var img := Image.create(largura * PX, grade.size() * PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pinta := {"k": CONTORNO, "o": cor}
	for y in grade.size():
		var linha: String = grade[y]
		for x in linha.length():
			var letra := linha[x]
			if pinta.has(letra):
				img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), pinta[letra])
	return img
