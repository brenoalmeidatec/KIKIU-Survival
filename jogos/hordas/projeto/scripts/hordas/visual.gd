extends RefCounted
## Truques de profundidade do pixel art ("3D disfarçado"), com UMA luz pra cena toda, vinda de cima à esquerda.
## Sombra projetada: a própria silhueta do sprite, virada pra baixo, achatada e inclinada pro lado oposto à luz.
## Sombra de contato: mancha escura bem embaixo do pé, que "gruda" o boneco no chão.
## Como vale pra qualquer sprite, continua servindo quando a arte trocar de tema.
##
## Desempenho (500 vírus na tela): as sombras são calculadas UMA vez por quadro de animação, pixel a pixel
## (degraus limpos, como pixel art desenhado), e guardadas num atlas único. Assim cada sombra é só um
## "carimbo" da mesma textura, e o Godot junta todas num lote de desenho.

const ACHATA := 0.42                          # altura da sombra em relação ao sprite
const INCLINA := 0.55                         # quanto a sombra deita pra direita (luz vem da esquerda)
const COR := Color(0.13, 0.1, 0.22, 0.4)      # sombra fria e transparente (combina com a paleta clara)
const COR_CONTATO := Color(0.1, 0.07, 0.16, 0.38)
const ATLAS := 1024
const MANCHA := Rect2(0, 0, 24, 8)            # a mancha de contato fica no canto do atlas

static var _atlas: Image
static var _atlas_tex: ImageTexture
static var _atlas_sujo := false
static var _assadas := {}                     # Vector4i(textura, x, y, largura*2+espelho) -> região no atlas
static var _imagens := {}                     # textura -> Image (pra não copiar a folha inteira a cada quadro)
static var _cursor := Vector2i.ZERO           # empacotamento em prateleiras
static var _prateleira := 0


## Sombra de um sprite cujos pés estão em "pe". rect = onde o sprite seria desenhado com os pés em (0, 0)
## (largura negativa = espelhado); src = recorte do quadro na textura. altura = quanto o objeto está acima
## do chão (a sombra fica no chão e encolhe; nesse caso é calculada na hora, porque muda todo quadro).
static func sombra(ci: CanvasItem, tex: Texture2D, rect: Rect2, src: Rect2, pe: Vector2, altura := 0.0) -> void:
	if tex == null:
		return
	if altura == 0.0:
		var r := _assada(tex, src, rect.size.x < 0)
		if r.size.x > 0:
			var s := absf(rect.size.x) / src.size.x
			var esq := minf(rect.position.x, rect.position.x + rect.size.x)
			var fundo := rect.position.y + rect.size.y
			ci.draw_texture_rect_region(_atlas_tex, Rect2(pe.x + esq, pe.y + fundo - s, r.size.x * s, r.size.y * s), r)
			return
	var k := ACHATA / (1.0 + altura / 40.0)
	ci.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-INCLINA * k / ACHATA, -k), pe))
	ci.draw_texture_rect_region(tex, rect, src, COR)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Mancha escura no pé (oclusão de contato). largura em pixels da tela.
static func contato(ci: CanvasItem, pe: Vector2, largura: float, altura := 0.0) -> void:
	_preparar()
	var a := 1.0 / (1.0 + altura / 30.0)
	var w := largura * a
	ci.draw_texture_rect_region(_atlas_tex, Rect2(pe - Vector2(w / 2, w * 0.16), Vector2(w, w * 0.32)), MANCHA, Color(1, 1, 1, a))


## Sombra completa de um boneco com Sprite2D (folha 9 colunas x 4 linhas, pé em (0, 0)).
static func sombra_boneco(ci: CanvasItem, spr: Sprite2D) -> void:
	if spr.texture == null:   # (não olha spr.visible: o boneco pisca ao apanhar, a sombra não)
		return
	var w := spr.texture.get_width() / float(spr.hframes)
	var h := spr.texture.get_height() / float(spr.vframes)
	var f := spr.frame
	var src := Rect2((f % spr.hframes) * w, (f / spr.hframes) * h, w, h)
	contato(ci, Vector2(0, 1), 26.0)
	sombra(ci, spr.texture, Rect2(spr.offset, Vector2(w, h)), src, Vector2(0, 1))


## Cria o atlas (com a mancha de contato: elipse 24x8, borda clara e miolo escuro, sem degradê liso)
## e manda pra placa de vídeo o que mudou desde a última vez.
static func _preparar() -> void:
	if _atlas == null:
		_atlas = Image.create(ATLAS, ATLAS, false, Image.FORMAT_RGBA8)
		for y in 8:
			for x in 24:
				var d := Vector2((x + 0.5 - 12.0) / 12.0, (y + 0.5 - 4.0) / 4.0).length()
				if d <= 0.6:
					_atlas.set_pixel(x, y, COR_CONTATO)
				elif d <= 1.0:
					_atlas.set_pixel(x, y, Color(COR_CONTATO, COR_CONTATO.a * 0.55))
		_atlas_tex = ImageTexture.create_from_image(_atlas)
		_cursor = Vector2i(25, 0)
		_prateleira = 8
	if _atlas_sujo:
		_atlas_tex.update(_atlas)
		_atlas_sujo = false


## A sombra de um quadro, calculada uma vez: cada pixel opaco do sprite vai pra linha "altura x ACHATA"
## abaixo do pé, deslocado "altura x INCLINA" pra direita. A linha de baixo do sprite vira a linha 0.
static func _assada(tex: Texture2D, src: Rect2, espelho: bool) -> Rect2:
	var chave := Vector4i(tex.get_rid().get_id(), int(src.position.x), int(src.position.y), int(src.size.x) * 2 + (1 if espelho else 0))
	var pronta = _assadas.get(chave)
	if pronta != null:
		return pronta
	_preparar()
	_assadas[chave] = Rect2()
	var img: Image = _imagens.get(tex)
	if img == null:
		img = tex.get_image()
		if img == null:
			return Rect2()
		if img.is_compressed():
			img.decompress()
		_imagens[tex] = img
	var w := int(src.size.x)
	var h := int(src.size.y)
	var tam := Vector2i(w + int(ceil(h * INCLINA)) + 1, int(ceil(h * ACHATA)) + 1)
	if _cursor.x + tam.x > ATLAS:
		_cursor = Vector2i(0, _cursor.y + _prateleira + 1)
		_prateleira = 0
	if _cursor.y + tam.y > ATLAS:
		return Rect2()   # atlas cheio: sombra() cai no jeito calculado na hora
	var o := _cursor
	for y in h:
		var alt := h - 1 - y
		var dy := int(alt * ACHATA)
		var dx := int(round(alt * INCLINA))
		for x in w:
			var sx := int(src.position.x) + (w - 1 - x if espelho else x)
			if img.get_pixel(sx, int(src.position.y) + y).a > 0.5:
				_atlas.set_pixel(o.x + x + dx, o.y + dy, COR)
	_cursor.x += tam.x + 1
	_prateleira = maxi(_prateleira, tam.y)
	_atlas_sujo = true
	_atlas_tex.update(_atlas)
	_atlas_sujo = false
	_assadas[chave] = Rect2(o, tam)
	return _assadas[chave]
