extends RefCounted
## Ícones pixel art do santuário (melhorias, conquistas e recompensas). Se existir `assets/v2/icones_santuario/<id>.png` (arte da frente
## de ícones), ele é usado; senão, o ícone é montado aqui a partir de um desenho 16x16 em texto e ampliado 2x (32x32, sem filtro).
## Quem mostra o ícone deve usar `texture_filter = NEAREST`. As texturas ficam guardadas: cada id é montado uma vez só.

const Paleta := preload("res://v2/paleta.gd")
const PASTA := "res://assets/v2/icones_santuario/"
const LADO := 16  # o desenho é 16x16; a textura sai 32x32

# Cada desenho: "o" é o contorno escuro, "a" a cor principal, "b" o brilho, "c" a sombra, "d" um detalhe; "." é transparente.
const DESENHOS := {
	"vida":
	[
		"",
		"",
		"..oooo....oooo..",
		".obbaao..oaaaao.",
		"obbaaaaooaaaaaao",
		"obaaaaaaaaaaaaco",
		"oaaaaaaaaaaaaaco",
		"oaaaaaaaaaaaacco",
		".oaaaaaaaaaacco.",
		"..oaaaaaaaacco..",
		"...oaaaaaacco...",
		"....oaaaacco....",
		".....oaacco.....",
		"......occo......",
		".......oo.......",
	],
	"dano":
	[
		"............ooo.",
		"...........obao.",
		"..........obao..",
		".........obao...",
		"........obao....",
		".......obao.....",
		"......obao......",
		".oo..obao.......",
		".odoobao........",
		"..oddao.........",
		"...odo..........",
		"..occdo.........",
		".occo.odo.......",
		"occo...oo.......",
		"oco.............",
		".o..............",
	],
	"velocidade":
	[
		"",
		"......oooo......",
		"......oaao......",
		"......oaao......",
		"......oaao......",
		"bb....oaao......",
		"......oaao......",
		".bbb..oaaoo.....",
		"......oaaaaoo...",
		"bb...oaaaaaaao..",
		".....oaaaaaaaao.",
		".bb..occcccccco.",
		".....oooooooooo.",
	],
	"folego":
	[
		"",
		"..........aaa...",
		".........a...a..",
		".............a..",
		"aaaaaaaaaaaaa...",
		"",
		"bbbbbbbbbbbbbb..",
		"..............b.",
		"............bb..",
		"",
		"aaaaaaaaaa......",
		"..........a.....",
		"......a...a.....",
		".......aaa......",
	],
	"treino":
	[
		"",
		"",
		"",
		".oo..........oo.",
		"oaao........oaao",
		"oaao........oaao",
		"oaaooooooooooaao",
		"oaabbbbbbbbbbaao",
		"oaaooooooooooaao",
		"oaao........oaao",
		"oaao........oaao",
		".oo..........oo.",
	],
	"ima":
	[
		"",
		"",
		"..oooo....oooo..",
		"..obbo....obbo..",
		"..obbo....obbo..",
		"..oooo....oooo..",
		"..oaao....oaao..",
		"..oaao....oaao..",
		"..oaao....oaao..",
		"..oaaoooooocao..",
		"..oaaaaaaaacco..",
		"...occcccccco...",
		"....oooooooo....",
	],
	"almas":
	[
		"",
		".......o........",
		"......oao.......",
		"......oaao......",
		".....oaaao......",
		".....oaabao.....",
		"....oaabbao.....",
		"...oaabbbaao....",
		"...oaabbbbao....",
		"...oaboobboao...",
		"...oabbbbbbao...",
		"...oaabbbbaao...",
		"....oaaaaaao....",
		".....oooooo.....",
	],
	"raridade":
	[
		"",
		"",
		"",
		"....oooooooo....",
		"...obbaaaaaao...",
		"..obbaaaaaaaco..",
		".oooooooooooooo.",
		"..oaaaaaaaaaco..",
		"...oaaaaaaaco...",
		"....oaaaaaco....",
		".....oaaaco.....",
		"......oaco......",
		".......oo.......",
	],
	"rolagem":
	[
		"",
		"",
		"..oooooooooooo..",
		"..obbbbbbbbbbo..",
		"..obccbbbbbbbo..",
		"..obccbbbbbbbo..",
		"..obbbbbbbbbbo..",
		"..obbbbccbbbbo..",
		"..obbbbccbbbbo..",
		"..obbbbbbbbbbo..",
		"..obbbbbbbccbo..",
		"..obbbbbbbccbo..",
		"..oaaaaaaaaaao..",
		"..oooooooooooo..",
	],
	"tempo":
	[
		"",
		"...dddddddddd...",
		"....o......o....",
		"....oaaaaaao....",
		".....oaaaao.....",
		"......oaao......",
		".......oo.......",
		".......oo.......",
		"......o..o......",
		".....o.aa.o.....",
		"....o.aaaa.o....",
		"....oaaaaaao....",
		"...dddddddddd...",
	],
	"chefe":
	[
		"",
		"",
		"",
		".o.....o......o.",
		"oao...oao....oao",
		"oaao.oaaao..oaao",
		"oaaaoaaaaaooaaao",
		"oaaaaaaaaaaaaaao",
		"oabaabaabaabaaao",
		"oaaaaaaaaaaaaaao",
		"occcccccccccccco",
		"oooooooooooooooo",
	],
	"combo":
	[
		"",
		".........oooo...",
		"........oaao....",
		".......oaao.....",
		"......oaao......",
		".....oaaoooo....",
		"....oaaaaaao....",
		"....ooooaao.....",
		".......oao......",
		"......oao.......",
		".....oao........",
		"....oao.........",
		"....oo..........",
	],
	"caveira":
	[
		"",
		"",
		"....oooooooo....",
		"...obbbbbbbbo...",
		"..obbbbbbbbbbo..",
		"..obbbbbbbbbbo..",
		"..obooobbooobo..",
		"..obooobbooobo..",
		"..obbbboobbbbo..",
		"...obbbbbbbbo...",
		"....obobobobo...",
		"....oooooooo....",
	],
	"estrela":
	[
		"",
		".......oo.......",
		"......oaao......",
		"......oaao......",
		".ooooooaaoooooo.",
		".oaaaaaabaaaaao.",
		"..oaaaaaaaaaao..",
		"...oaaaaaaaao...",
		"...oaaaooaaao...",
		"..oaaao..oaaao..",
		"..oao......oao..",
		"..oo........oo..",
	],
}

# Cores de cada desenho: a principal, o brilho, a sombra e o detalhe (só da paleta, com alfa ou mistura quando preciso).
const CORES := {
	"vida": [Paleta.VIDA, Paleta.VIDA_PISCA, Color("#6e1219"), Paleta.VIDA],
	"dano": [Paleta.MOLDURA_ESCURA, Paleta.BRANCO, Paleta.RUPTURA_BORDA, Paleta.OURO],
	"velocidade": [Paleta.SECAO_KATANA, Paleta.TEXTO, Paleta.RUPTURA_BORDA, Paleta.OURO],
	"folego": [Paleta.DICA, Paleta.FOLEGO, Paleta.FOLEGO, Paleta.FOLEGO],
	"treino": [Paleta.MOLDURA_ESCURA, Paleta.SECAO_KATANA, Paleta.MOLDURA_APAGADA, Paleta.OURO],
	"ima": [Paleta.PERIGO, Paleta.MOLDURA, Color("#8a2a26"), Paleta.OURO],
	"almas": [Paleta.ANUNCIO_ELITE, Paleta.ALMA, Paleta.ANUNCIO_ELITE, Paleta.ALMA],
	"raridade": [Paleta.RARIDADES[2], Paleta.FUSAO, Color("#6a2a9a"), Paleta.OURO],
	"rolagem": [Paleta.MOLDURA_ESCURA, Paleta.TEXTO, Paleta.PERIGO, Paleta.OURO],
	"tempo": [Paleta.VALOR, Paleta.TEXTO, Paleta.VALOR, Paleta.OURO],
	"chefe": [Paleta.OURO, Paleta.PERIGO, Paleta.RECARGA_BORDA, Paleta.OURO],
	"combo": [Paleta.OURO, Paleta.FOCO, Paleta.CARGA_LARANJA, Paleta.OURO],
	"caveira": [Paleta.MOLDURA, Paleta.TEXTO, Paleta.MOLDURA_ESCURA, Paleta.PERIGO],
	"estrela": [Paleta.OURO, Paleta.FOCO, Paleta.RECARGA_BORDA, Paleta.OURO],
}

# Ids de conquistas, modos e visuais que reaproveitam um desenho.
const APELIDOS := {
	"sobreviva_5min": "tempo",
	"derrota_chefe": "chefe",
	"combo_50": "combo",
	"pesadelo": "caveira",
	"rastro_katana": "dano",
}

static var _memo := {}


## A textura do ícone de `id` (melhoria, conquista ou recompensa). Sempre devolve uma textura: id desconhecido vira a estrela.
static func textura(id: String) -> Texture2D:
	if _memo.has(id):
		return _memo[id]
	var t: Texture2D = null
	var caminho := PASTA + id + ".png"
	if ResourceLoader.exists(caminho):  # a arte de verdade (não FileAccess: no jogo exportado o PNG vira .ctex)
		t = load(caminho) as Texture2D
	if t == null:
		t = _montar(APELIDOS.get(id, id))
	_memo[id] = t
	return t


## True se o ícone de `id` vem de um PNG da pasta de ícones (false = desenhado aqui).
static func tem_arte(id: String) -> bool:
	return ResourceLoader.exists(PASTA + id + ".png")


static func _montar(nome: String) -> Texture2D:
	if not DESENHOS.has(nome):
		nome = "estrela"
	var cores: Array = CORES.get(nome, CORES.estrela)
	var mapa := {"o": Paleta.BARRA_BORDA, "a": cores[0], "b": cores[1], "c": cores[2], "d": cores[3]}
	var img := Image.create(LADO, LADO, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var linhas: Array = DESENHOS[nome]
	var y0 := (LADO - linhas.size()) / 2  # centraliza na vertical quem tem menos de 16 linhas
	for y in linhas.size():
		var linha: String = linhas[y]
		for x in mini(linha.length(), LADO):
			var ch := linha[x]
			if mapa.has(ch):
				img.set_pixel(x, y0 + y, mapa[ch])
	img.resize(LADO * 2, LADO * 2, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)
