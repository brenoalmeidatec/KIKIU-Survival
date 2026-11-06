extends "res://testes/isolamento_v2.gd"
# Teste das FOLHAS da teia (assets/v2/teias/, gerar por fonte_arte/teia/gerar_teia.py; dados/v2_teia.json > folhas). Confere: o tamanho do PNG bate com quadro x colunas e quadro x linhas
# do JSON; alfa só 0 ou 255 (pixel art); o último quadro de "abre" é o repouso e o primeiro de "some" é o mesmo; o último de "some" é vazio; a luminância média dos quadros da QUEIMA sobe
# uma vez até o pico e desce uma vez (WCAG 2.3.1: no máximo 3 trocas por segundo, v2/piscadas.gd) e as 4 variantes espelhadas têm a mesma luminância; o corte tem o risco brilhante e termina
# vazio; cada folha está registrada em docs/LICENCAS_ARTE.md; o próprio critério de "um pico só" reprova uma série com três picos.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_teia_folhas.tscn  (imprime "v2_teia_folhas falhas=0")

const Piscadas := preload("res://v2/piscadas.gd")

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


## A luminância média (0 a 1) de um quadro: luma x alfa sobre fundo preto.
func lum(im: Image, x0: int, y0: int, w: int, h: int) -> float:
	var s := 0.0
	for y in h:
		for x in w:
			var c := im.get_pixel(x0 + x, y0 + y)
			if c.a > 0.5:
				s += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	return s / float(w * h)


func pixels(im: Image, x0: int, y0: int, w: int, h: int) -> int:
	var n := 0
	for y in h:
		for x in w:
			if im.get_pixel(x0 + x, y0 + y).a > 0.5:
				n += 1
	return n


## Sobe (ou fica) até um pico e depois só desce (ou fica): um pico só.
static func um_pico(serie: Array, tol := 0.0005) -> bool:
	var descendo := false
	for i in range(1, serie.size()):
		var d: float = serie[i] - serie[i - 1]
		if d < -tol:
			descendo = true
		elif d > tol and descendo:
			return false
	return true


func iguais(a: Image, ax: int, ay: int, b: Image, bx: int, by: int, w: int, h: int) -> bool:
	for y in h:
		for x in w:
			if a.get_pixel(ax + x, ay + y) != b.get_pixel(bx + x, by + y):
				return false
	return true


func _ready() -> void:
	var f: Dictionary = Dados.json("v2_teia").folhas
	var imgs := {}
	for k in f:
		var e: Dictionary = f[k]
		var tex = load("res://assets/v2/teias/" + str(e.arquivo))
		ok(tex is Texture2D, "a folha %s existe e importa" % e.arquivo)
		if not (tex is Texture2D):
			continue
		var im: Image = tex.get_image()
		imgs[k] = im
		var qw := int(e.quadro[0])
		var qh := int(e.quadro[1])
		ok(
			im.get_width() == qw * int(e.colunas) and im.get_height() == qh * int(e.linhas),
			"%s: %dx%d = %d x %d quadros de %dx%d" % [e.arquivo, im.get_width(), im.get_height(), int(e.colunas), int(e.linhas), qw, qh]
		)
		ok(int(e.quadros) == int(e.colunas), "%s: uma linha por variante (quadros == colunas)" % e.arquivo)
		var alfa_ok := true
		var tem := 0
		for y in im.get_height():
			for x in im.get_width():
				var a := im.get_pixel(x, y).a
				if a > 0.0 and a < 1.0:
					alfa_ok = false
				if a > 0.0:
					tem += 1
		ok(alfa_ok, "%s: alfa só 0 ou 1 (pixel art)" % e.arquivo)
		ok(tem > 100, "%s: tem pixels desenhados" % e.arquivo)
	if imgs.size() < 7:
		print("v2_teia_folhas falhas=%d" % (falhas + 1))
		get_tree().quit()
		return
	var W := 96
	var H := 64
	var WB := 128
	var HB := 80
	# repouso: o último quadro de "abre" = o primeiro de "some", por geometria; o último de "some" é vazio
	for g in 2:
		ok(iguais(imgs.abre, 5 * W, g * H, imgs.some, 0, g * H, W, H), "geometria %d: o repouso de 'abre' é o primeiro quadro de 'some'" % g)
		ok(pixels(imgs.some, 5 * W, g * H, W, H) == 0, "geometria %d: 'some' termina vazio" % g)
		ok(
			pixels(imgs.queima, 7 * W, g * 4 * H, W, H) < 40,
			"geometria %d: a queima termina quase vazia (%d px)" % [g, pixels(imgs.queima, 7 * W, g * 4 * H, W, H)]
		)
		# corte e quebra têm quadro maior (128x80: os pedaços voam além da teia) e duram mais (9 e 8 quadros)
		ok(pixels(imgs.corte, 8 * WB, g * 2 * HB, WB, HB) < 160, "geometria %d: o corte termina quase vazio" % g)
		ok(pixels(imgs.quebra, 7 * WB, g * HB, WB, HB) < 160, "geometria %d: a quebra termina quase vazia" % g)
		# a queima começa como o repouso (fio inteiro): quase o mesmo número de pixels do repouso
		var rep := pixels(imgs.abre, 5 * W, g * H, W, H)
		var q0 := pixels(imgs.queima, 0, g * 4 * H, W, H)
		ok(absi(rep - q0) < rep / 8, "geometria %d: a queima nasce da teia inteira (%d e %d px)" % [g, q0, rep])
	# a luminância da queima: um pico só, e no máximo 3 trocas por segundo (a folha toca a 10 fps)
	for l in 8:
		var serie: Array = []
		for c in 8:
			serie.append(lum(imgs.queima, c * W, l * H, W, H))
		ok(um_pico(serie), "queima, linha %d: a luminância sobe e desce uma vez (%s)" % [l, ", ".join(serie.map(func(v): return "%.3f" % v))])
		ok(Piscadas.trocas(serie, 0.002) <= 2, "queima, linha %d: no máximo 2 trocas de luminância na animação toda" % l)
	var l0: Array = []
	var l3: Array = []
	for c in 8:
		l0.append(lum(imgs.queima, c * W, 0, W, H))
		l3.append(lum(imgs.queima, c * W, 3 * H, W, H))
	ok(absf(l0[2] - l3[2]) < 0.0005, "as variantes espelhadas têm a mesma luminância")
	ok(l0[2] > l0[0] and l0[2] > l0[7], "o pico da queima fica no meio, não nas pontas")
	# o critério reprova um pico triplo
	ok(not um_pico([0.1, 0.2, 0.1, 0.2, 0.1, 0.2, 0.1, 0.1]), "o critério reprova uma série com três picos")
	# o corte tem o risco brilhante (amarelo/branco) no quadro 1 e ele dura 3 quadros (eram 2; pedido do Alisson, 06/11)
	var riscos: Array = []
	for col in 9:
		var risco := 0
		for y in HB:
			for x in WB:
				var c: Color = (imgs.corte as Image).get_pixel(col * WB + x, y)
				if c.a > 0.5 and c.r > 0.95 and c.g > 0.6 and c.b < 0.6:
					risco += 1
		riscos.append(risco)
	ok(riscos[1] > 40, "o quadro 1 do corte tem o risco brilhante (%d px)" % riscos[1])
	ok(riscos[0] > 20 and riscos[1] > 40 and riscos[2] > 40, "o risco brilhante dura 3 quadros inteiros (%s px)" % str(riscos.slice(0, 4)))
	# registro de licença
	var caminho := ProjectSettings.globalize_path("res://").path_join("../../../docs/LICENCAS_ARTE.md").simplify_path()
	if FileAccess.file_exists(caminho):
		var txt := FileAccess.get_file_as_string(caminho)
		for e in f.values():
			ok(txt.contains(str(e.arquivo)), "docs/LICENCAS_ARTE.md registra %s" % e.arquivo)
		ok(txt.contains("fonte_arte/teia/gerar_teia.py"), "o registro cita o gerador")
	else:
		print("aviso: docs/LICENCAS_ARTE.md fora do alcance (%s): registro não conferido" % caminho)
	print("v2_teia_folhas falhas=%d" % falhas)
	get_tree().quit()
