extends SceneTree
## Gera os cursores pixel art da v2 (seta para os menus e mira para a partida).
## Rode na raiz do projeto: godot --headless --script res://v2/gerar_cursor.gd
## Com --ampliar=PASTA também salva uma cópia 4x sem suavizar, para conferir na tela.
## Cada pixel da arte vale 2 px de imagem (o cursor sai de 22x36 e 26x26 px, que não fica minúsculo em 1080p).

const PX := 2
const PASTA := "res://assets/v2/cursor/"
## k = contorno (PAINEL), w = miolo (TEXTO). "." é transparente.
const CORES := {"k": Color("#01030b"), "w": Color("#ebe6f5")}
const SETA := [
	"k..........",
	"kk.........",
	"kwk........",
	"kwwk.......",
	"kwwwk......",
	"kwwwwk.....",
	"kwwwwwk....",
	"kwwwwwwk...",
	"kwwwwwwwk..",
	"kwwwwwwwwk.",
	"kwwwwwwwwwk",
	"kwwwwwkkkkk",
	"kwwkwwk....",
	"kwk.kwwk...",
	"kk..kwwk...",
	"k...kwwk...",
	"....kwwk...",
	".....kk....",
]
## Mira de 13x13 com o centro na célula (6, 6): a ponta do hotspot fica no meio da imagem.
const MIRA := [
	"......k......",
	".....kwk.....",
	".....kwk.....",
	".....kwk.....",
	".....kwk.....",
	"kkkkk...kkkkk",
	"wwwww.w.wwwww",
	"kkkkk...kkkkk",
	".....kwk.....",
	".....kwk.....",
	".....kwk.....",
	".....kwk.....",
	"......k......",
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var ampliar := ""
	for a in args:
		if a.begins_with("--ampliar="):
			ampliar = a.trim_prefix("--ampliar=")
	_salvar(SETA, "seta", ampliar)
	_salvar(MIRA, "mira", ampliar)
	quit()


func _salvar(grade: Array, nome: String, ampliar: String) -> void:
	var largura := 0
	for linha in grade:
		largura = maxi(largura, linha.length())
	var img := Image.create(largura * PX, grade.size() * PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in grade.size():
		var linha: String = grade[y]
		for x in linha.length():
			var letra := linha[x]
			if not CORES.has(letra):
				continue
			img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), CORES[letra])
	var destino := ProjectSettings.globalize_path(PASTA + nome + ".png")
	DirAccess.make_dir_recursive_absolute(destino.get_base_dir())
	img.save_png(destino)
	print("%s: %dx%d -> %s" % [nome, img.get_width(), img.get_height(), destino])
	if ampliar != "":
		DirAccess.make_dir_recursive_absolute(ampliar)
		var grande := img.duplicate()
		grande.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
		grande.save_png(ampliar.path_join(nome + "_4x.png"))
