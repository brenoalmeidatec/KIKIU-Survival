extends SceneTree
## Gera a arte do assistente do instalador (PNG) montando uma cena com a arte REAL do jogo: o Hazaki em camadas (as
## folhas renderizadas pelo Blender), monstros das folhas inimigo_*.png, o piso e os enfeites da Floresta Sombria, brasas,
## brilho de luz e vinheta. Tudo em pixel art: cada sprite é ampliado só em escala inteira, com vizinho mais próximo.
##
## Quem chama é o gerar_arte.sh (que depois converte os PNG para BMP 24 bits com o ffmpeg):
##   godot --path ../projeto --script ../instalador/gerar_arte.gd -- <pasta_de_saida>
## Não roda em --headless (o renderizador "dummy" não desenha); abre uma janelinha por um instante e fecha sozinho.
## Saída: wizard_164x314.png, wizard_328x628.png, small_55x58.png, small_110x116.png.
##
## A cena é desenhada numa grade-base de 164x314 (ou 55x58); o tamanho 2x é a MESMA cena com todos os sprites no dobro da
## escala e a fonte no dobro do corpo, não uma ampliação do PNG pequeno: por isso os dois ficam nítidos.

const FONTE := "res://assets/fonte/PressStart2P.ttf"
const COR_TITULO := Color("8ab4ff")      # o azul do título do jogo
const COR_SUB := Color("8cff8c")         # o verde do subtítulo na tela de título
const CEU_TOPO := Color("07060f")
const CEU_BAIXO := Color("1d1736")
const NEVOA := Color("2a2147")

var _fonte: FontFile
var _tex := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var saida := args[0] if args.size() > 0 else "."
	DirAccess.make_dir_recursive_absolute(saida)
	_fonte = load(FONTE)
	_fonte.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_fonte.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_fonte.hinting = TextServer.HINTING_NONE
	_rodar(saida)


func _rodar(saida: String) -> void:
	for t in [[Vector2i(164, 314), 1, "wizard_164x314"], [Vector2i(164, 314), 2, "wizard_328x628"]]:
		await _salvar(_cena_vertical(t[0], t[1]), t[0] * t[1], saida, t[2])
	for t in [[Vector2i(55, 58), 1, "small_55x58"], [Vector2i(55, 58), 2, "small_110x116"]]:
		await _salvar(_cena_pequena(t[0], t[1]), t[0] * t[1], saida, t[2])
	quit()


func _salvar(cena: Node2D, tam: Vector2i, saida: String, nome: String) -> void:
	var vp := SubViewport.new()
	vp.size = tam
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	vp.add_child(cena)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(saida.path_join(nome + ".png"))
	print("gerado ", nome, ".png ", img.get_width(), "x", img.get_height())
	vp.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
# utilidades

func _t(caminho: String) -> Texture2D:
	if not _tex.has(caminho):
		_tex[caminho] = load("res://assets/" + caminho)
	return _tex[caminho]


## Camada de desenho: um Node2D cujo _draw chama `f(n)`. `aditivo` soma luz em vez de cobrir.
func _camada(pai: Node2D, f: Callable, aditivo := false) -> Node2D:
	var n := Node2D.new()
	if aditivo:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = m
	n.draw.connect(func(): f.call(n))
	pai.add_child(n)
	return n


func _radial(raio: int, cor: Color, expoente := 2.0) -> Texture2D:
	var img := Image.create(raio * 2, raio * 2, false, Image.FORMAT_RGBA8)
	for y in raio * 2:
		for x in raio * 2:
			var d := Vector2(x + 0.5 - raio, y + 0.5 - raio).length() / raio
			var a := pow(clampf(1.0 - d, 0.0, 1.0), expoente)
			img.set_pixel(x, y, Color(cor.r, cor.g, cor.b, a * cor.a))
	return ImageTexture.create_from_image(img)


## Brilho em escada (4 degraus por cor) em vez de degradê liso: combina com o pixel art.
func _luz(n: Node2D, centro: Vector2, raio: float, cor: Color, u: int) -> void:
	var chave := "luz_%s" % cor.to_html()
	if not _tex.has(chave):
		_tex[chave] = _radial(24, cor, 1.6)
	var tex: Texture2D = _tex[chave]
	n.draw_texture_rect(tex, Rect2(centro - Vector2(raio, raio) * u, Vector2(raio, raio) * 2.0 * u), false)


func _rng(semente: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = semente
	return r


## Desenha um quadro de folha (colunas x linhas) com o pé do boneco em `pe`, escala inteira `s`.
func _quadro(n: Node2D, tex: Texture2D, cols: int, linhas: int, col: int, lin: int, pe: Vector2, s: int, cor := Color.WHITE, pe_rel := Vector2(0.5, 0.97)) -> void:
	var fw := tex.get_width() / cols
	var fh := tex.get_height() / linhas
	var dest := Rect2(pe - Vector2(fw * pe_rel.x, fh * pe_rel.y) * s, Vector2(fw, fh) * s)
	dest.position = dest.position.round()
	n.draw_texture_rect_region(tex, dest, Rect2(col * fw, lin * fh, fw, fh), cor)


func _texto(n: Node2D, s: String, centro_x: float, y: float, tam: int, cor: Color, u: int) -> void:
	var larg := _fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam * u).x
	var p := Vector2(roundf(centro_x - larg / 2.0), y + _fonte.get_ascent(tam * u))
	# contorno escuro de 1 px-base em volta e sombra, pra ler sobre qualquer fundo
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
		n.draw_string(_fonte, p + d * u, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam * u, Color(0.02, 0.01, 0.06))
	n.draw_string(_fonte, p + Vector2(0, 2) * u, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam * u, Color(0.02, 0.01, 0.06))
	n.draw_string(_fonte, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam * u, cor)


# ---------------------------------------------------------------------------------------------------------------------
# a vertical (painel esquerdo das telas de boas-vindas e fim)

func _cena_vertical(base: Vector2i, u: int) -> Node2D:
	var raiz := Node2D.new()
	raiz.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var W := base.x
	var H := base.y
	var horizonte := 128   # y-base onde o chão começa

	# 1) céu em faixas (degradê com degraus, sem filtro) + lua + estrelas
	_camada(raiz, func(n: Node2D):
		var faixas := 26
		for i in faixas:
			var t := float(i) / (faixas - 1)
			var c := CEU_TOPO.lerp(CEU_BAIXO, pow(t, 1.4))
			n.draw_rect(Rect2(0, i * horizonte * u / faixas, W * u, ceil(float(horizonte * u) / faixas) + 1), c)
		var r := _rng(11)
		for i in 38:
			var p := Vector2(r.randi_range(0, W - 1), r.randi_range(0, horizonte - 30))
			var br := r.randf_range(0.25, 0.8)
			n.draw_rect(Rect2(p * u, Vector2(u, u)), Color(0.75, 0.8, 1.0, br))
		# lua grande e pálida, parte escondida pelo título
		var lc := Vector2(82, 100) * u
		var rl := 26 * u
		for y in range(-rl, rl + 1, u):
			for x in range(-rl, rl + 1, u):
				var d := Vector2(x, y).length()
				if d <= rl:
					var sombra := 0.0
					var d2 := (Vector2(x, y) - Vector2(-7, -5) * u).length()
					if d2 > rl * 0.78:
						sombra = 0.25
					var c := Color("c9d2ee").lerp(Color("5b5f86"), sombra + (d / rl) * 0.25)
					n.draw_rect(Rect2(lc + Vector2(x, y), Vector2(u, u)), c)
		# crateras
		for cr in [[Vector2(-6, 4), 5], [Vector2(8, -8), 4], [Vector2(4, 12), 3], [Vector2(-12, -10), 3]]:
			var cc: Vector2 = lc + cr[0] * u
			var rr: int = cr[1] * u
			for y in range(-rr, rr + 1, u):
				for x in range(-rr, rr + 1, u):
					if Vector2(x, y).length() <= rr:
						n.draw_rect(Rect2(cc + Vector2(x, y), Vector2(u, u)), Color(0.45, 0.48, 0.68, 0.55))
	)

	# 2) silhuetas de árvores no horizonte (as árvores reais da Floresta Sombria, escurecidas)
	var enf := _t("cenarios/floresta/enfeites.png")
	_camada(raiz, func(n: Node2D):
		var arv := Rect2(0, 0, 61, 76)
		var morta := Rect2(62, 0, 27, 49)
		# [região, pé dentro da região, x-base do pé, escala, brilho]
		for t in [[arv, Vector2(31, 64), 2, 1, 0.55], [morta, Vector2(10, 45), 40, 1, 0.5], [arv, Vector2(31, 64), 124, 1, 0.5], [arv, Vector2(31, 64), 156, 1, 0.6], [morta, Vector2(10, 45), 100, 1, 0.45]]:
			var reg: Rect2 = t[0]
			var pe: Vector2 = t[1]
			var b: float = t[4]
			var cor := Color(0.32 * b * 2, 0.34 * b * 2, 0.55 * b * 2)
			var tam: Vector2 = reg.size * float(t[3] * u)
			var topo: Vector2 = Vector2(t[2], horizonte + 6) * u - pe * float(t[3] * u)
			n.draw_texture_rect_region(enf, Rect2(topo.round(), tam), reg, cor)
	)

	# 3) chão: o piso real da floresta ladrilhado, escurecido e com neblina subindo do horizonte
	var piso := _t("cenarios/floresta/piso.png")
	_camada(raiz, func(n: Node2D):
		var tam := 256 * u
		var y0 := horizonte * u
		var cor := Color(0.55, 0.52, 0.68)
		for ty in range(y0, H * u, tam):
			for tx in range(0, W * u, tam):
				n.draw_texture_rect(piso, Rect2(tx, ty, tam, tam), true, cor)
		# neblina: faixas da cor do céu se dissolvendo no chão
		for i in 18:
			var t := float(i) / 17.0
			n.draw_rect(Rect2(0, y0 + i * 3 * u, W * u, 3 * u), Color(NEVOA.r, NEVOA.g, NEVOA.b, 0.85 * pow(1.0 - t, 1.7)))
	)

	# 4) luzes quentes e frias (aditivas)
	_camada(raiz, func(n: Node2D):
		_luz(n, Vector2(82, 250), 92, Color(1.0, 0.58, 0.22, 0.6), u)     # a luz do herói (tocha)
		_luz(n, Vector2(82, 120), 90, Color(0.35, 0.35, 0.8, 0.22), u)    # brilho da lua no meio
		_luz(n, Vector2(22, 196), 34, Color(0.3, 1.0, 0.6, 0.30), u)      # cogumelos fosforescentes
		_luz(n, Vector2(146, 176), 30, Color(0.7, 0.3, 1.0, 0.25), u)     # fogo-fátuo roxo
	, true)

	# 5) monstros ao fundo: silhuetas escuras com os olhos vermelhos acesos; os mais próximos ficam mais claros
	var mons := [
		# folha, cols, x-base, y-base (pé), escala, vista (linha), brilho
		["inimigo_cavaleiro_oco", 7, 30, 140, 1, 0, 0.30],
		["inimigo_cultista", 7, 66, 136, 1, 0, 0.30],
		["inimigo_espectro", 7, 102, 138, 1, 0, 0.32],
		["inimigo_cultista", 7, 138, 142, 1, 0, 0.30],
		["inimigo_lobo_sombrio", 7, 22, 180, 1, 1, 0.42],
		["inimigo_espectro", 7, 60, 170, 1, 0, 0.45],
		["inimigo_cao_ossos", 7, 116, 180, 1, 2, 0.42],
		["inimigo_cavaleiro_oco", 7, 148, 190, 1, 0, 0.55],
		["inimigo_cultista", 7, 26, 222, 1, 0, 0.7],
		["inimigo_lobo_sombrio", 7, 140, 240, 1, 2, 0.6],
	]
	var fon := _camada(raiz, func(n: Node2D):
		for m in mons:
			var tex := _t("gerado/" + m[0] + ".png")
			var b: float = m[6]
			var cor := Color(0.25 + 0.75 * b, 0.22 + 0.7 * b, 0.4 + 0.6 * b)
			cor = cor.lerp(NEVOA, 0.35 * (1.0 - b))
			_quadro(n, tex, m[1], 5, 0, m[5], Vector2(m[2], m[3]) * u, m[4] * u, cor)
	)

	# 6) o herói: Hazaki em camadas (corpo + botas + armadura + braçadeiras + elmo com chifres + katana), 4x
	var hero_pe := Vector2(82, 292)
	_camada(raiz, func(n: Node2D):
		# sombra no chão
		n.draw_set_transform(hero_pe * u + Vector2(0, -2 * u), 0.0, Vector2(1.0, 0.28))
		n.draw_circle(Vector2.ZERO, 44 * u, Color(0, 0, 0, 0.55))
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var camadas := ["corpo", "camadas/botas", "camadas/armadura_samurai", "camadas/bracadeiras", "camadas/mascara", "camadas/cabeca_guerreiro", "camadas/katana_mao"]
		for c in camadas:
			_quadro(n, _t("personagens/hazaki/" + c + ".png"), 23, 8, 13, 0, hero_pe * u, 2 * u, Color.WHITE, Vector2(0.5, 0.97))
	)

	# 7) brasas subindo (pixels laranja de vários tamanhos)
	_camada(raiz, func(n: Node2D):
		_luz(n, Vector2(82, 262), 56, Color(1.0, 0.6, 0.25, 0.22), u)   # a luz da tocha também bate no herói
		var r := _rng(77)
		for i in 46:
			var p := Vector2(r.randf_range(0, W), r.randf_range(110, H))
			var t := (p.y - 110.0) / (H - 110.0)
			var tam := 1 if r.randf() < 0.75 else 2
			var c := Color("ffb347").lerp(Color("ff4a1c"), r.randf())
			c.a = clampf(0.35 + 0.65 * t + r.randf_range(-0.1, 0.1), 0.2, 1.0)
			n.draw_rect(Rect2((p).round() * u, Vector2(tam, tam) * u), c)
	, true)

	# 8) vinheta + título + subtítulo
	_camada(raiz, func(n: Node2D):
		# vinheta = preto nas bordas: desenha o inverso com 4 faixas e cantos
		for i in 14:
			var t := float(i) / 13.0
			var a := 0.5 * pow(1.0 - t, 2.2)
			var e := i * 3 * u
			n.draw_rect(Rect2(0, e, W * u, 3 * u), Color(0, 0, 0, a))
			n.draw_rect(Rect2(0, H * u - e - 3 * u, W * u, 3 * u), Color(0, 0, 0, a * 1.15))
			n.draw_rect(Rect2(e, 0, 3 * u, H * u), Color(0, 0, 0, a * 0.8))
			n.draw_rect(Rect2(W * u - e - 3 * u, 0, 3 * u, H * u), Color(0, 0, 0, a * 0.8))
		_texto(n, "K.I.K.I.U", W / 2.0 * u, 16 * u, 16, COR_TITULO, u)
		_texto(n, "Knights In Kaos,", W / 2.0 * u, 44 * u, 8, COR_SUB, u)
		_texto(n, "Infinite Upgrades", W / 2.0 * u, 56 * u, 8, COR_SUB, u)
	)
	return raiz


# ---------------------------------------------------------------------------------------------------------------------
# a pequena (canto das outras telas): o escudo do ícone numa moldura de noite

func _cena_pequena(base: Vector2i, u: int) -> Node2D:
	var raiz := Node2D.new()
	raiz.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var W := base.x
	var H := base.y
	var piso := _t("cenarios/floresta/piso.png")
	var escudo := _t("icone/kikiu_48.png")
	_camada(raiz, func(n: Node2D):
		n.draw_rect(Rect2(0, 0, W * u, H * u), Color("0b0916"))
		n.draw_texture_rect_region(piso, Rect2(0, 0, W * u, H * u), Rect2(40, 90, W, H), Color(0.55, 0.52, 0.68))
	)
	_camada(raiz, func(n: Node2D):
		_luz(n, Vector2(W / 2.0, H / 2.0 + 2), 34, Color(0.35, 0.5, 1.0, 0.55), u)
	, true)
	_camada(raiz, func(n: Node2D):
		n.draw_texture_rect(escudo, Rect2(Vector2((W - 48) / 2.0, (H - 48) / 2.0 + 1) * u, Vector2(48, 48) * u), false)
		var r := _rng(3)
		for i in 7:
			var p := Vector2(r.randi_range(2, W - 3), r.randi_range(2, H - 3))
			n.draw_rect(Rect2(p * u, Vector2(u, u)), Color("ffb347", 0.9))
		# vinheta e moldura fina
		for i in 6:
			n.draw_rect(Rect2(i * u, i * u, (W - 2 * i) * u, (H - 2 * i) * u), Color(0, 0, 0, 0.09 * (6 - i)), false, u)
		n.draw_rect(Rect2(0, 0, W * u, H * u), Color("3a3560"), false, u)
	)
	return raiz
