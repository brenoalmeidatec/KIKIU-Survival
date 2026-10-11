extends RefCounted
## Truques de profundidade do pixel art ("3D disfarçado"), com UMA luz pra cena toda, vinda de cima à esquerda.
## Sombra projetada: a própria silhueta do sprite, virada pra baixo, achatada e inclinada pro lado oposto à luz.
## Sombra de contato: mancha escura bem embaixo do pé, que "gruda" o boneco no chão.
## Como vale pra qualquer sprite, continua servindo quando a arte trocar de tema.
##
## Desempenho (500 vírus na tela): as sombras são calculadas UMA vez por quadro de animação, pixel a pixel
## (degraus limpos, como pixel art desenhado), e guardadas num atlas único. Assim cada sombra é só um
## "carimbo" da mesma textura, e o Godot junta todas num lote de desenho.

const ACHATA := 0.42  # altura da sombra em relação ao sprite
const INCLINA := 0.55  # quanto a sombra deita pra direita (luz vem da esquerda)
const COR := Color(0.13, 0.1, 0.22, 0.4)  # sombra fria e transparente (combina com a paleta clara)
const COR_CONTATO := Color(0.1, 0.07, 0.16, 0.38)
const ATLAS := 1024
const MANCHA := Rect2(0, 0, 24, 8)  # a mancha de contato fica no canto do atlas

static var _atlas: Image
static var _atlas_tex: ImageTexture
static var _atlas_sujo := false
static var _assadas := {}  # Vector4i(textura, x, y, largura*2+espelho) -> região no atlas
static var _imagens := {}  # textura -> Image (pra não copiar a folha inteira a cada quadro)
static var _bytes := {}  # textura -> bytes RGBA8 da folha (ler o alfa por índice custa bem menos que get_pixel)
static var _quadro_assado := -1  # quadro do motor em que o orçamento abaixo começou
static var _us_assado := 0  # microssegundos gastos assando sombras neste quadro
static var _enviar_ligado := false
## No máximo ~2,5 ms por quadro assando sombras. Antes, cada sombra nova (cada vista x quadro x espelho de cada monstro)
## assava na hora E reenviava o atlas inteiro (1024x1024 RGBA = 4 MB) pra placa de vídeo: com a horda entrando, era o
## engasgo dos primeiros quadros de cada partida, que "estabilizava" quando tudo já estava assado. Agora o excedente
## usa a sombra calculada na hora (barata, só uma textura com transformação) e vira assada nos quadros seguintes;
## o envio do atlas é um só por quadro, logo antes de desenhar.
const ORCAMENTO_US := 2500
static var _cursor := Vector2i.ZERO  # empacotamento em prateleiras
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


## Região do atlas com a sombra assada deste quadro (Rect2 vazio = não coube: use `sombra`). Quem desenha muita sombra
## (inimigos) guarda o resultado e chama `carimbar`, sem refazer a chave de busca todo quadro.
static func sombra_regiao(tex: Texture2D, src: Rect2, espelho: bool) -> Rect2:
	return _assada(tex, src, espelho)


## Carimba uma sombra já assada (ver `sombra_regiao`). `escala` = largura na tela / largura do quadro; `fundo` = y da base do sprite.
static func carimbar(ci: CanvasItem, r: Rect2, escala: float, x: float, y: float) -> void:
	ci.draw_texture_rect_region(_atlas_tex, Rect2(x, y - escala, r.size.x * escala, r.size.y * escala), r)


## Mancha escura no pé (oclusão de contato). largura em pixels da tela.
static func contato(ci: CanvasItem, pe: Vector2, largura: float, altura := 0.0) -> void:
	_preparar()
	var a := 1.0 / (1.0 + altura / 30.0)
	var w := largura * a
	ci.draw_texture_rect_region(_atlas_tex, Rect2(pe - Vector2(w / 2, w * 0.16), Vector2(w, w * 0.32)), MANCHA, Color(1, 1, 1, a))


## Sombra completa de um boneco com Sprite2D (folha 9 colunas x 4 linhas, pé em (0, 0)).
static func sombra_boneco(ci: CanvasItem, spr: Sprite2D) -> void:
	if spr.texture == null:  # (não olha spr.visible: o boneco pisca ao apanhar, a sombra não)
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


## A folha inteira como Image RGBA8 (guardada: ler o alfa e montar atlas sem copiar a textura a cada vez). null se não deu.
static func imagem(tex: Texture2D) -> Image:
	var img: Image = _imagens.get(tex)
	if img == null:
		img = tex.get_image()
		if img == null:
			return null
		if img.is_compressed():
			img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		_imagens[tex] = img
		_bytes[tex] = img.get_data()
	return img


## A textura do atlas de sombras (a mesma pra sempre: o ImageTexture só é atualizado). Os inimigos desenham as sombras
## numa MultiMesh com ela (#127); `MANCHA` é a mancha de contato.
static func textura_sombras() -> Texture2D:
	_preparar()
	return _atlas_tex


## A sombra de um quadro, calculada uma vez: cada pixel opaco do sprite vai pra linha "altura x ACHATA"
## abaixo do pé, deslocado "altura x INCLINA" pra direita. A linha de baixo do sprite vira a linha 0.
static func _assada(tex: Texture2D, src: Rect2, espelho: bool) -> Rect2:
	var chave := Vector4i(tex.get_rid().get_id(), int(src.position.x), int(src.position.y), int(src.size.x) * 2 + (1 if espelho else 0))
	var pronta = _assadas.get(chave)
	if pronta != null:
		return pronta
	var quadro := Engine.get_process_frames()
	if quadro != _quadro_assado:
		_quadro_assado = quadro
		_us_assado = 0
	if _us_assado > ORCAMENTO_US:
		return Rect2()  # sem orçamento neste quadro: não registra, tenta de novo no próximo
	var t0 := Time.get_ticks_usec()
	_preparar()
	_assadas[chave] = Rect2()
	var img: Image = imagem(tex)
	if img == null:
		return Rect2()
	var dados: PackedByteArray = _bytes[tex]
	var larg_img := img.get_width()
	var w := int(src.size.x)
	var h := int(src.size.y)
	var tam := Vector2i(w + int(ceil(h * INCLINA)) + 1, int(ceil(h * ACHATA)) + 1)
	if _cursor.x + tam.x > ATLAS:
		_cursor = Vector2i(0, _cursor.y + _prateleira + 1)
		_prateleira = 0
	if _cursor.y + tam.y > ATLAS:
		return Rect2()  # atlas cheio: sombra() cai no jeito calculado na hora
	var o := _cursor
	for y in h:
		var alt := h - 1 - y
		var dy := int(alt * ACHATA)
		var dx := int(round(alt * INCLINA))
		for x in w:
			var sx := int(src.position.x) + (w - 1 - x if espelho else x)
			if dados[((int(src.position.y) + y) * larg_img + sx) * 4 + 3] >= 128:  # alfa > 0,5
				_atlas.set_pixel(o.x + x + dx, o.y + dy, COR)
	_cursor.x += tam.x + 1
	_prateleira = maxi(_prateleira, tam.y)
	_atlas_sujo = true  # o envio pra placa é um só por quadro (_enviar)
	if not _enviar_ligado:
		_enviar_ligado = true
		RenderingServer.frame_pre_draw.connect(_enviar)
	_assadas[chave] = Rect2(o, tam)
	_us_assado += Time.get_ticks_usec() - t0
	return _assadas[chave]


## Manda o atlas pra placa de vídeo, uma vez por quadro, antes de desenhar (se alguma sombra nova foi assada).
static func _enviar() -> void:
	if _atlas_sujo and _atlas_tex:
		_atlas_tex.update(_atlas)
		_atlas_sujo = false


# ---------- chegada do personagem no começo da fase (#32 item 6) ----------
const CHEGADA_TEMPO := 0.6  # segundos de queda + pouso
const CHEGADA_POUSO := 0.65  # em que ponto (0..1) da chegada ele encosta no chão
const CHEGADA_ALTURA := 110.0  # px de onde ele cai (a abertura de fase cai de mais alto)


## Altura (px acima do chão) do personagem no ponto p (0..1) da chegada: cai acelerando, pousa e quica de leve.
static func chegada_altura(p: float, alt := CHEGADA_ALTURA) -> float:
	if p >= 1.0:
		return 0.0
	if p < CHEGADA_POUSO:
		var q := 1.0 - p / CHEGADA_POUSO
		return alt * q * q
	return 5.0 * sin((p - CHEGADA_POUSO) / (1.0 - CHEGADA_POUSO) * PI)


## Brilho branco que o corpo ganha ao pousar (0..1).
static func chegada_flash(p: float) -> float:
	return maxf(0.0, 1.0 - absf(p - CHEGADA_POUSO) / 0.22) if p < 1.0 else 0.0


## Desenha (em coordenadas do boneco, pés em 0,0): coluna de luz na queda, anel do pouso e o nome em cima.
## p = progresso da chegada (1 = acabou); nome_a = opacidade do nome (0..1).
static func chegada(no: CanvasItem, p: float, nome: String, nome_a: float, cor: Color, alt := CHEGADA_ALTURA) -> void:
	if p < CHEGADA_POUSO:
		var q := p / CHEGADA_POUSO
		no.draw_rect(Rect2(-9, -alt - 100.0, 18, alt + 100.0), Color(cor.r, cor.g, cor.b, 0.10 + 0.25 * q))
		no.draw_rect(Rect2(-3, -alt - 100.0, 6, alt + 100.0), Color(1, 1, 1, 0.25 + 0.4 * q))
	elif p < 1.0:
		var k := (p - CHEGADA_POUSO) / (1.0 - CHEGADA_POUSO)
		no.draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.45))
		no.draw_arc(Vector2.ZERO, 8.0 + 34.0 * k, 0, TAU, 28, Color(1, 1, 1, 0.8 * (1.0 - k)), 2.0)
		no.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if nome_a > 0.0 and nome != "":
		var f: Font = Dados.fonte
		no.draw_string(f, Vector2(-59, -65), nome, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color(0, 0, 0, 0.85 * nome_a))
		no.draw_string(f, Vector2(-60, -66), nome, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, Color(cor.lightened(0.5), nome_a))
