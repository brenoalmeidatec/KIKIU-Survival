extends RefCounted
## Sprite de pixel art que aponta para uma direção (projétil, lâmina, onda, queda de meteoro) SEM girar por ângulo livre: o pixel da arte tem
## de cair na grade do mundo (regra em pixel_rot.gd). A direção é uma das 16 (passos de 22,5 graus, `PixelRot.direcao16`):
##   - os múltiplos de 90 graus são transformação exata (o desenho vira linha por coluna), e é o Godot quem gira o normal map;
##   - os outros 3 sub-ângulos (22,5, 45 e 67,5) usam uma CÓPIA pré-girada da arte, gerada uma vez por textura e guardada no cache.
## A cópia sai de "upscale-rotate-downscale com Nearest" (2x2 amostras por pixel, vence a cor mais frequente): nunca inventa cor nem alfa que
## a arte não tinha, e o contorno de 1 px continua 1 px. Se a textura é um CanvasTexture (com normal map), o normal é girado junto: os pixels
## e o vetor RG, pelo mesmo ângulo. O custo é de uma vez só: `preparar` gera as 3 cópias ao carregar (nunca no meio da partida) e o desenho
## é só um índice de dicionário.
## A âncora é um ponto INTEIRO do desenho (o pivô do giro). O quadro da cópia é recortado ao tamanho que o giro precisa e a âncora acompanha.

const PixelRot := preload("res://v2/pixel_rot.gd")
const SUBS := 4
## Sinal da rotação do vetor do normal map. O verde do normal map do Godot é Y PARA CIMA e a tela é Y para baixo: girar o desenho `th` no
## sentido horário da tela gira o vetor gravado por -th. Medido numa janela real (luz embaixo à direita, normal (1,0) girado 45 graus pelo
## motor ficou claro, 0,48, igual ao normal (0,7, -0,7) sem giro; com o sinal +1 a cópia ficava escura, 0,10).
const NORMAL_SINAL := -1.0

static var _cache := {}  # id da textura -> {"tex": textura (segura o id), "var": [null, copia1, copia2, copia3]}
static var geradas := 0  # quantas cópias foram geradas neste processo (o teste e a medição leem)


## Já gerou as cópias desta textura?
static func preparada(tex: Texture2D) -> bool:
	return _cache.has(tex.get_instance_id())


## Gera (se ainda não) as 3 cópias pré-giradas de `tex`: `quadro` = tamanho de um quadro, `n` = quadros lado a lado, `ancora` = pivô inteiro.
static func preparar(tex: Texture2D, quadro: Vector2i, ancora: Vector2i, n: int = 1) -> void:
	var id := tex.get_instance_id()
	if _cache.has(id):
		return
	var copias: Array = [null]
	for sub in range(1, SUBS):
		copias.append(_gerar(tex, quadro, ancora, n, sub))
	_cache[id] = {"tex": tex, "var": copias}


## A arte do sub-ângulo `sub` (0 = a original): {"tex", "quadro" (Vector2), "ancora" (Vector2)}. Gera na hora se `preparar` não rodou.
static func variante(tex: Texture2D, quadro: Vector2i, ancora: Vector2i, n: int, sub: int) -> Dictionary:
	if sub <= 0:
		return {"tex": tex, "quadro": Vector2(quadro), "ancora": Vector2(ancora)}
	var id := tex.get_instance_id()
	if not _cache.has(id):
		preparar(tex, quadro, ancora, n)
	return (_cache[id].var as Array)[sub]


## Desenha o quadro `i` de `tex` na direção `ang` (rad), com o pivô em `pos` (arredondado). `escala` deve ser inteira (>= 1) ou o espelho
## horizontal (x negativo): ela age nos eixos do mundo depois do giro, como no código antigo.
static func desenhar(
	ci: CanvasItem, tex: Texture2D, quadro: Vector2i, ancora: Vector2i, n: int, i: int, pos: Vector2, ang: float, escala := Vector2.ONE, cor := Color.WHITE
) -> void:
	# O draw_set_transform aplica a escala nos eixos do MUNDO, depois da rotação (confirmado em janela real com o espelho): o espelho (x negativo)
	# vira o desenho já apontado para `ang`, igual ao código antigo, e a cópia escolhida é a mesma do desenho sem espelho.
	var d := PixelRot.direcao16(ang)
	var v := variante(tex, quadro, ancora, n, d.x)
	var q: Vector2 = v.quadro
	ci.draw_set_transform(pos.round(), float(d.y) * PixelRot.QUARTO, escala)
	ci.draw_texture_rect_region(v.tex, Rect2(-(v.ancora as Vector2), q), Rect2(Vector2(q.x * float(i), 0.0), q), cor)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _rgba(img: Image) -> Image:
	var c := img.duplicate() as Image
	if c.is_compressed():
		c.decompress()
	c.convert(Image.FORMAT_RGBA8)
	return c


static func _gerar(tex: Texture2D, quadro: Vector2i, ancora: Vector2i, n: int, sub: int) -> Dictionary:
	geradas += 1
	var difusa := tex
	var normal: Texture2D = null
	if tex is CanvasTexture:
		difusa = (tex as CanvasTexture).diffuse_texture
		normal = (tex as CanvasTexture).normal_texture
	var im := _rgba(difusa.get_image())
	var src: PackedInt32Array = im.get_data().to_int32_array()
	var largura := im.get_width()
	var imn: Image = null
	var srcn := PackedInt32Array()
	if normal != null:
		imn = _rgba(normal.get_image())
		srcn = imn.get_data().to_int32_array()
	var th := float(sub) * PI / 8.0
	var c := cos(th)
	var s := sin(th)
	var fw := quadro.x
	var fh := quadro.y
	# o retângulo girado em volta da âncora: o quadro novo é a caixa dele, em pixels inteiros
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	for canto in [Vector2(0, 0), Vector2(fw, 0), Vector2(0, fh), Vector2(fw, fh)]:
		var p: Vector2 = canto - Vector2(ancora)
		var rx := p.x * c - p.y * s
		var ry := p.x * s + p.y * c
		minx = minf(minx, rx)
		maxx = maxf(maxx, rx)
		miny = minf(miny, ry)
		maxy = maxf(maxy, ry)
	var x0 := floori(minx + 0.0001)
	var y0 := floori(miny + 0.0001)
	var wd := ceili(maxx - 0.0001) - x0
	var hd := ceili(maxy - 0.0001) - y0
	# para cada pixel novo, onde caem as 4 amostras (2x2) no quadro de origem (-1 = fora)
	var amostras_x := PackedInt32Array()
	var amostras_y := PackedInt32Array()
	amostras_x.resize(wd * hd * 4)
	amostras_y.resize(wd * hd * 4)
	var m := 0
	for j in hd:
		for ii in wd:
			for q in 4:
				var px := float(x0 + ii) + 0.5 + (0.25 if q % 2 == 1 else -0.25)
				var py := float(y0 + j) + 0.5 + (0.25 if q >= 2 else -0.25)
				var sx := floori(float(ancora.x) + px * c + py * s)
				var sy := floori(float(ancora.y) - px * s + py * c)
				if sx < 0 or sy < 0 or sx >= fw or sy >= fh:
					sx = -1
					sy = -1
				amostras_x[m] = sx
				amostras_y[m] = sy
				m += 1
	var saida := PackedInt32Array()
	saida.resize(wd * n * hd)
	var saida_n := PackedInt32Array()
	if imn != null:
		saida_n.resize(wd * n * hd)
	var cor_a := [0, 0, 0, 0]
	var idx_a := [0, 0, 0, 0]
	for f in n:
		var base_x := f * fw
		for j in hd:
			for ii in wd:
				var k := (j * wd + ii) * 4
				var nc := 0
				for q in 4:
					var sxq := amostras_x[k + q]
					if sxq < 0:
						continue
					var idx := amostras_y[k + q] * largura + base_x + sxq
					var col := src[idx]
					if (col >> 24) & 255 == 0:
						continue
					cor_a[nc] = col
					idx_a[nc] = idx
					nc += 1
				if nc < 2:
					continue  # menos de metade do pixel coberto: vazio
				var melhor := 0
				var melhor_n := 0
				for a in nc:
					var cnt := 0
					for b in nc:
						if cor_a[b] == cor_a[a]:
							cnt += 1
					if cnt > melhor_n:
						melhor_n = cnt
						melhor = a
				var o := j * (wd * n) + f * wd + ii
				saida[o] = cor_a[melhor]
				if imn != null:
					saida_n[o] = _girar_normal(srcn[idx_a[melhor]], c, s)
	var nova := Image.create_from_data(wd * n, hd, false, Image.FORMAT_RGBA8, saida.to_byte_array())
	var res: Texture2D = ImageTexture.create_from_image(nova)
	if imn != null:
		var novan := Image.create_from_data(wd * n, hd, false, Image.FORMAT_RGBA8, saida_n.to_byte_array())
		var ct := CanvasTexture.new()
		ct.diffuse_texture = res
		ct.normal_texture = ImageTexture.create_from_image(novan)
		res = ct
	return {"tex": res, "quadro": Vector2(wd, hd), "ancora": Vector2(-x0, -y0)}


## O pixel do normal map (RGBA empacotado) com o vetor RG girado pelo mesmo ângulo que os pixels. Z e alfa ficam.
static func _girar_normal(col: int, c: float, s: float) -> int:
	var r := col & 255
	var g := (col >> 8) & 255
	var b := (col >> 16) & 255
	var a := (col >> 24) & 255
	if a == 0:
		return col
	var nx := float(r) / 255.0 * 2.0 - 1.0
	var ny := float(g) / 255.0 * 2.0 - 1.0
	var ss := s * NORMAL_SINAL
	var rx := nx * c - ny * ss
	var ry := nx * ss + ny * c
	r = clampi(roundi((rx * 0.5 + 0.5) * 255.0), 0, 255)
	g = clampi(roundi((ry * 0.5 + 0.5) * 255.0), 0, 255)
	var v := r | (g << 8) | (b << 16) | (a << 24)
	return v - 0x100000000 if v >= 0x80000000 else v
