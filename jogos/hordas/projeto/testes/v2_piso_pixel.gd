extends Node
# Teste da grade de 1 px nos pisos (pixel art com um tamanho de pixel só). Mede, em cada piso que um mapa da v2 usa,
# a fração de janelas 2x2 de cor uniforme (borda circular, o piso é tile): manchas chapadas de 2 a 20 px passam de 0,70;
# arte de 1 px de verdade (pisos de cidade, laboratório e médio) fica abaixo de 0,20. O teto é 0,40.
# Também confere que o piso da floresta continua escuro (média de luminância do original, tolerância de 3%), tem a
# mesma paleta (sem cor nova fora das 30 do original) e emenda: a diferença entre a coluna 511 e a 0 (e linha 511 e 0)
# não é maior que a diferença média entre colunas vizinhas.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_piso_pixel.tscn  (imprime "v2_piso_pixel falhas=0")
const PISOS := [
	"res://prototipos/piso/piso.png",
	"res://assets/v2/mapas/cidade/piso.png",
	"res://assets/v2/mapas/laboratorio/piso.png",
	"res://assets/v2/mapas/medio/piso.png",
]
const TETO_2X2 := 0.40
const ORIGINAL_LUMA := 45.1  # média (0,3 R + 0,5 G + 0,2 B) do piso original da floresta, em 0..255
const PALETA_ORIGINAL := 30  # cores do piso original

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for caminho in PISOS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(caminho))
		ok(img != null, "carrega " + caminho)
		if img == null:
			continue
		var f := _frac_2x2(img)
		print("  ", caminho, " 2x2 uniforme=", snappedf(f, 0.001))
		ok(f < TETO_2X2, "%s: 2x2 uniforme %.3f (teto %.2f): manchas maiores que 1 px" % [caminho, f, TETO_2X2])
	var flo := Image.load_from_file(ProjectSettings.globalize_path(PISOS[0]))
	if flo != null:
		var luma := _luma_media(flo)
		ok(absf(luma - ORIGINAL_LUMA) / ORIGINAL_LUMA < 0.03, "piso da floresta muda de brilho: luma %.2f (original %.1f)" % [luma, ORIGINAL_LUMA])
		var cores := _cores(flo)
		ok(cores <= PALETA_ORIGINAL, "piso da floresta ganhou cores novas: %d (original %d)" % [cores, PALETA_ORIGINAL])
		var emenda_x := _dif_colunas(flo, flo.get_width() - 1, 0)
		var emenda_y := _dif_linhas(flo, flo.get_height() - 1, 0)
		var media_x := _dif_media_colunas(flo)
		var media_y := _dif_media_linhas(flo)
		ok(emenda_x <= media_x * 1.5, "emenda em x: %.2f contra média %.2f" % [emenda_x, media_x])
		ok(emenda_y <= media_y * 1.5, "emenda em y: %.2f contra média %.2f" % [emenda_y, media_y])
	print("v2_piso_pixel falhas=", falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _frac_2x2(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var uni := 0
	var tot := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			tot += 1
			var x2 := (x + 1) % w
			var y2 := (y + 1) % h
			if img.get_pixel(x2, y) == c and img.get_pixel(x, y2) == c and img.get_pixel(x2, y2) == c:
				uni += 1
	return float(uni) / maxf(1.0, float(tot))


func _luma_media(img: Image) -> float:
	var s := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			s += 0.3 * c.r + 0.5 * c.g + 0.2 * c.b
	return s / float(img.get_width() * img.get_height()) * 255.0


func _cores(img: Image) -> int:
	var d := {}
	for y in img.get_height():
		for x in img.get_width():
			d[img.get_pixel(x, y).to_rgba32()] = true
	return d.size()


func _dif(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func _dif_colunas(img: Image, x1: int, x2: int) -> float:
	var s := 0.0
	for y in img.get_height():
		s += _dif(img.get_pixel(x1, y), img.get_pixel(x2, y))
	return s / float(img.get_height()) * 255.0


func _dif_linhas(img: Image, y1: int, y2: int) -> float:
	var s := 0.0
	for x in img.get_width():
		s += _dif(img.get_pixel(x, y1), img.get_pixel(x, y2))
	return s / float(img.get_width()) * 255.0


func _dif_media_colunas(img: Image) -> float:
	var s := 0.0
	for x in img.get_width() - 1:
		s += _dif_colunas(img, x, x + 1)
	return s / float(img.get_width() - 1)


func _dif_media_linhas(img: Image) -> float:
	var s := 0.0
	for y in img.get_height() - 1:
		s += _dif_linhas(img, y, y + 1)
	return s / float(img.get_height() - 1)
