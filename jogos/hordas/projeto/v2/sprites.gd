extends RefCounted
## Carrega as folhas de sprites do protótipo 2.5D (herói e monstros). Ficam FORA de res://, em jogos/hordas/prototipos/cara_nova/sprites
## (gerados por gerar_cara_nova.py), e são lidas por caminho de arquivo, como o protótipo faz: nada é duplicado em assets/.
## Cada tipo vira {tex (CanvasTexture albedo + normal), w, h (quadro), info (json), emissao (olhos, ou null), alb, blur (silhueta
## borrada da sombra média), pe (linha dos pés no quadro)}.

const Sombras := preload("res://v2/sombras.gd")
const PASTA := "res://prototipos/cara_nova/sprites"
const PAD_ATLAS := 2

var com_normal := true
var ms_blur := 0.0
var _imgs := {}
var _tipos := {}


func _caminho(nome: String) -> String:
	return PASTA.path_join(nome)


## PNG por load(): no exe exportado o PNG de origem não vai para o pck (vira .ctex importado); get_image() devolve a imagem para os cálculos.
static func png(caminho: String) -> Image:
	var tex := load(caminho) as Texture2D
	return tex.get_image() if tex != null else null


func _imagem(nome: String) -> Image:
	if not _imgs.has(nome):
		var im := png(_caminho(nome))
		if im == null:
			push_error("sem imagem: " + _caminho(nome))
		_imgs[nome] = im
	return _imgs[nome]


func tipo(nome: String) -> Dictionary:
	if _tipos.has(nome):
		return _tipos[nome]
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_caminho(nome + ".json")))
	var t := CanvasTexture.new()
	var alb := ImageTexture.create_from_image(_imagem(nome + "_albedo.png"))
	t.diffuse_texture = alb
	if com_normal:
		t.normal_texture = ImageTexture.create_from_image(_imagem(nome + "_normal.png"))
	var d := {"tex": t, "w": int(info.quadro[0]), "h": int(info.quadro[1]), "info": info, "emissao": null, "alb": alb}
	var t0 := Time.get_ticks_usec()
	d["blur"] = Sombras.borrar_folha(_imagem(nome + "_albedo.png"), d.w, d.h)
	ms_blur += (Time.get_ticks_usec() - t0) / 1000.0
	if ResourceLoader.exists(_caminho(nome + "_emissao.png")):
		d.emissao = ImageTexture.create_from_image(_imagem(nome + "_emissao.png"))
	d["pe"] = int(info.get("pe_y", info.quadro[1] - 2))
	_tipos[nome] = d
	return d


## As folhas dos monstros empilhadas num atlas só (para o lote da horda, v2/horda.gd: uma textura, uma chamada de desenho). Devolve
## {tex (CanvasTexture albedo + normal), alb, blur (silhueta borrada da sombra média), emissao, tam, origem: {nome: Vector2}}; cada tipo
## também ganha `atlas_o` (o canto da folha dele no atlas). Entre as folhas ficam PAD_ATLAS px transparentes (o filtro linear da sombra não vaza).
func atlas(nomes: Array) -> Dictionary:
	var largura := 1
	var altura := 0
	for nome in nomes:
		var im := _imagem(nome + "_albedo.png")
		largura = maxi(largura, im.get_width())
		altura += im.get_height() + PAD_ATLAS
	var alb := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	var nor := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	nor.fill(Color(0.5, 0.5, 1.0, 1.0))  # normal "reto": o fundo e o espaço entre folhas
	var emi := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	var bor := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	var origem := {}
	var y := 0
	for nome in nomes:
		var t := tipo(nome)  # carrega a folha (e o blur)
		var a := _imagem(nome + "_albedo.png").duplicate() as Image
		a.convert(Image.FORMAT_RGBA8)
		var r := Rect2i(0, 0, a.get_width(), a.get_height())
		alb.blit_rect(a, r, Vector2i(0, y))
		var n := _imagem(nome + "_normal.png").duplicate() as Image
		n.convert(Image.FORMAT_RGBA8)
		nor.blit_rect(n, r, Vector2i(0, y))
		if ResourceLoader.exists(_caminho(nome + "_emissao.png")):
			var e := _imagem(nome + "_emissao.png").duplicate() as Image
			e.convert(Image.FORMAT_RGBA8)
			emi.blit_rect(e, r, Vector2i(0, y))
		var b := (t.blur as ImageTexture).get_image()
		b.convert(Image.FORMAT_RGBA8)
		bor.blit_rect(b, r, Vector2i(0, y))
		origem[nome] = Vector2(0, y)
		t["atlas_o"] = Vector2(0, y)
		y += a.get_height() + PAD_ATLAS
	var ct := CanvasTexture.new()
	var alb_t := ImageTexture.create_from_image(alb)
	ct.diffuse_texture = alb_t
	if com_normal:
		ct.normal_texture = ImageTexture.create_from_image(nor)
	return {
		"tex": ct,
		"alb": alb_t,
		"blur": ImageTexture.create_from_image(bor),
		"emissao": ImageTexture.create_from_image(emi),
		"tam": Vector2(largura, altura),
		"origem": origem
	}
