extends RefCounted
## Aparência por paleta (#72, marco 2): recolore o corpo do herói sem arte nova. A textura original tem poucas cores
## (tabela de tons); cada tom é de pele, de cabelo ou de roupa, e vira a cor escolhida com o mesmo brilho relativo
## (o contorno escuro e o vermelho da faixa ficam como estão). As cores vêm de dados/aparencia.json; a ficha guarda só o
## índice de cada canal ({"pele": 4, "cabelo": 0, "roupa": 2}). Resultado em cache por (sprite, textura, paleta).

const PELE_REF := Color(0.694, 0.431, 0.322)  # o tom médio da pele do corpo original
const ROUPA_REF := Color(0.165, 0.141, 0.149)  # o tom médio da roupa
const CABELO_REF := Color(0.102, 0.086, 0.094)  # o tom médio do cabelo
const CONTORNO := [0x0D0B14, 0x0D0D10]  # contorno escuro do corpo: não muda
const PELES := [0xB16E52, 0xD29A78, 0x6D4332, 0x3E261E]
const VERMELHOS := [0x75191A, 0x3A0C0D]
static var _cache := {}


static func cores(canal: String) -> Array:
	return Dados.json("aparencia").get(canal, [])


static func canais() -> Array:
	return Dados.json("aparencia").get("canais", [])


static func cor(canal: String, i: int) -> Color:
	var l := cores(canal)
	if l.is_empty():
		return Color.WHITE
	var c: Array = l[clampi(i, 0, l.size() - 1)]
	return Color(float(c[0]), float(c[1]), float(c[2]))


## A paleta de uma raça: o que ela escolhe de início (paleta_raca, marco 6) ou, se não diz, a pele de pele_raca com cabelo e roupa originais.
static func padrao(raca: String) -> Dictionary:
	var cfg: Dictionary = Dados.json("aparencia")
	var p = cfg.get("paleta_raca", {}).get(raca)
	if p is Dictionary:
		return {"pele": int(p.get("pele", 0)), "cabelo": int(p.get("cabelo", 0)), "roupa": int(p.get("roupa", 0))}
	return {"pele": int(cfg.get("pele_raca", {}).get(raca, 0)), "cabelo": 0, "roupa": 0}


## Índices válidos (cada canal dentro da lista)? Aceita int ou float inteiro (vem de JSON e da rede).
static func valida(p) -> bool:
	if not p is Dictionary:
		return false
	for canal in canais():
		var v = p.get(canal)
		if not (v is int or (v is float and v == floorf(v))):
			return false
		if int(v) < 0 or int(v) >= cores(canal).size():
			return false
	return true


static func limpar(p: Dictionary) -> Dictionary:
	var r := {}
	for canal in canais():
		r[canal] = int(p.get(canal, 0))
	return r


static func _chave(p: Dictionary) -> String:
	return "%d.%d.%d" % [int(p.get("pele", 0)), int(p.get("cabelo", 0)), int(p.get("roupa", 0))]


## Cor nova pra um tom da textura, ou Color(0,0,0,0) (alfa 0) se o tom fica como está.
## modo: "corpo" (pele e roupa), "cabelo" (a camada inteira é cabelo) ou "rosto" (pele e cabelo).
static func _mapear(src: int, modo: String, pele: Color, cabelo: Color, roupa: Color) -> Color:
	var r := float((src >> 16) & 255) / 255.0
	var g := float((src >> 8) & 255) / 255.0
	var b := float(src & 255) / 255.0
	var tom := Color(r, g, b)
	if modo != "cabelo" and src in PELES:
		return _escalar(pele, tom, PELE_REF)
	if modo != "cabelo" and (src in CONTORNO or src in VERMELHOS):
		return Color(0, 0, 0, 0)
	if modo == "corpo":
		return _escalar(roupa, tom, ROUPA_REF)
	# cabelo (camada de cabelo, ou os tons escuros do rosto)
	return _escalar(cabelo, tom, CABELO_REF)


## A cor escolhida com o mesmo brilho que o tom tinha em relação ao tom médio, canal a canal (com a cor original dá o tom de volta).
static func _escalar(escolhida: Color, tom: Color, ref: Color) -> Color:
	return Color(minf(escolhida.r * tom.r / ref.r, 1.0), minf(escolhida.g * tom.g / ref.g, 1.0), minf(escolhida.b * tom.b / ref.b, 1.0), 1.0)


## Recolore uma imagem (pixel a pixel, só nos tons que a tabela conhece) e devolve outra.
static func recolorir(img: Image, modo: String, paleta: Dictionary) -> Image:
	var pele := cor("pele", int(paleta.get("pele", 0)))
	var cabelo := cor("cabelo", int(paleta.get("cabelo", 0)))
	var roupa := cor("roupa", int(paleta.get("roupa", 0)))
	var out := img.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	var d := out.get_data()
	var tabela := {}
	var n := d.size()
	var i := 0
	while i < n:
		if d[i + 3] > 0:
			var k: int = (d[i] << 16) | (d[i + 1] << 8) | d[i + 2]
			var novo: Color
			if tabela.has(k):
				novo = tabela[k]
			else:
				novo = _mapear(k, modo, pele, cabelo, roupa)
				tabela[k] = novo
			if novo.a > 0.0:
				d[i] = roundi(novo.r * 255.0)
				d[i + 1] = roundi(novo.g * 255.0)
				d[i + 2] = roundi(novo.b * 255.0)
		i += 4
	return Image.create_from_data(out.get_width(), out.get_height(), false, Image.FORMAT_RGBA8, d)


## A textura do herói <sprite> ("corpo", "camadas/cabelo", "rosto") com a paleta aplicada. Vazia/ inválida: a original.
static func textura(sprite: String, nome: String, paleta: Dictionary) -> Texture2D:
	var orig := Dados.tex_personagem(sprite, nome)
	if orig == null or paleta.is_empty():
		return orig
	var chave := "%s|%s|%s" % [sprite, nome, _chave(paleta)]
	if _cache.has(chave):
		return _cache[chave]
	var modo := "corpo"
	if nome.ends_with("cabelo"):
		modo = "cabelo"
	elif nome == "rosto":
		modo = "rosto"
	var t := ImageTexture.create_from_image(recolorir(orig.get_image(), modo, paleta))
	_cache[chave] = t
	return t
