extends RefCounted
## Carrega as folhas de sprites do protótipo 2.5D (herói e monstros). Ficam FORA de res://, em jogos/hordas/prototipos/cara_nova/sprites
## (gerados por gerar_cara_nova.py), e são lidas por caminho de arquivo, como o protótipo faz: nada é duplicado em assets/.
## Cada tipo vira {tex (CanvasTexture albedo + normal), w, h (quadro), info (json), emissao (olhos, ou null), alb, blur (silhueta
## borrada da sombra média), pe (linha dos pés no quadro)}.

const Sombras := preload("res://v2/sombras.gd")
const PASTA := "res://prototipos/cara_nova/sprites"

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
