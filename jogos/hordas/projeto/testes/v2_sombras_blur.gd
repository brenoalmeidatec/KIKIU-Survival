extends Node
## Compara byte a byte o blur otimizado com o algoritmo anterior em células e folhas pequenas.

const Sombras := preload("res://v2/sombras.gd")
var falhas := 0


func _referencia_caixa(a: PackedByteArray, iw: int, ih: int, w: int, h: int, horiz: bool) -> PackedByteArray:
	var o := PackedByteArray()
	o.resize(iw * ih)
	for y in ih:
		var y0 := (y / h) * h
		var y1 := mini(y0 + h, ih) - 1
		for x in iw:
			var soma := 0
			var n := 0
			if horiz:
				var x0 := (x / w) * w
				var x1 := mini(x0 + w, iw) - 1
				for k in range(maxi(x - 1, x0), mini(x + 1, x1) + 1):
					soma += a[y * iw + k]
					n += 1
			else:
				for k in range(maxi(y - 1, y0), mini(y + 1, y1) + 1):
					soma += a[k * iw + x]
					n += 1
			o[y * iw + x] = soma / n
	return o


func _referencia(im: Image, w: int, h: int) -> PackedByteArray:
	var cp := im.duplicate() as Image
	cp.convert(Image.FORMAT_RGBA8)
	var iw := cp.get_width()
	var ih := cp.get_height()
	var dados := cp.get_data()
	var alfa := PackedByteArray()
	alfa.resize(iw * ih)
	for i in iw * ih:
		alfa[i] = dados[i * 4 + 3]
	for passe in 2:
		alfa = _referencia_caixa(alfa, iw, ih, w, h, true)
		alfa = _referencia_caixa(alfa, iw, ih, w, h, false)
	var saida := PackedByteArray()
	saida.resize(iw * ih * 4)
	for i in iw * ih:
		saida[i * 4 + 3] = alfa[i]
	return saida


func _comparar(im: Image, w: int, h: int, nome: String) -> void:
	var esperado := _referencia(im, w, h)
	var textura := Sombras.borrar_folha(im, w, h)
	var imagem := textura.get_image()
	if imagem == null or imagem.get_data() != esperado:
		falhas += 1
		print("FALHOU: blur byte a byte ", nome)


func _ready() -> void:
	var inicio := Time.get_ticks_msec()
	var vazio := Image.create(19, 13, false, Image.FORMAT_RGBA8)
	vazio.fill(Color(1, 0.2, 0.7, 0))  # RGB transparente não cria sombra
	_comparar(vazio, 7, 5, "vazio e quadros parciais")
	var bordas := Image.create(19, 13, false, Image.FORMAT_RGBA8)
	bordas.fill(Color.TRANSPARENT)
	for p in [Vector2i(0, 0), Vector2i(6, 0), Vector2i(0, 4), Vector2i(6, 4), Vector2i(7, 0), Vector2i(13, 9), Vector2i(18, 12)]:
		bordas.set_pixelv(p, Color(0.3, 0.7, 0.9, 0.5))
	bordas.set_pixel(3, 2, Color(0.6, 0.1, 0.8, 1.0))
	_comparar(bordas, 7, 5, "bordas, cantos, alfa parcial e células parciais")
	var alfa_minimo := Image.create(15, 15, false, Image.FORMAT_RGBA8)
	alfa_minimo.fill(Color.TRANSPARENT)
	for y in range(4, 11):
		for x in range(4, 11):
			alfa_minimo.set_pixel(x, y, Color(1, 1, 1, 1.0 / 255.0))
	_comparar(alfa_minimo, 15, 15, "alfa mínimo 1/255")
	if Sombras.borrar_folha(alfa_minimo, 15, 15).get_image().get_pixel(7, 7).a <= 0.0:
		falhas += 1
		print("FALHOU: alfa mínimo no centro foi descartado")
	var separadas := Image.create(10, 5, false, Image.FORMAT_RGBA8)
	separadas.fill(Color.TRANSPARENT)
	separadas.set_pixel(4, 2, Color.WHITE)
	_comparar(separadas, 5, 5, "sem vazamento entre quadros")
	var sombra := Sombras.borrar_folha(separadas, 5, 5).get_image()
	if sombra.get_region(Rect2i(5, 0, 5, 5)).get_used_rect().has_area():
		falhas += 1
		print("FALHOU: alfa vazou para o quadro vizinho")
	var esparsa := Image.create(128, 64, false, Image.FORMAT_RGBA8)
	esparsa.fill(Color.TRANSPARENT)
	esparsa.set_pixel(32, 32, Color.WHITE)
	_comparar(esparsa, 64, 64, "recorte pequeno no interior de célula grande")
	esparsa.set_pixel(62, 2, Color(1, 1, 1, 0.7))
	esparsa.set_pixel(64, 63, Color(1, 1, 1, 0.3))
	_comparar(esparsa, 64, 64, "halo próximo a limites reais da célula")
	var rng := RandomNumberGenerator.new()
	rng.seed = 583587
	for caso in 35:
		var largura := rng.randi_range(1, 20)
		var altura := rng.randi_range(1, 18)
		var quadro_w := rng.randi_range(1, 9)
		var quadro_h := rng.randi_range(1, 8)
		var amostra := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
		amostra.fill(Color.TRANSPARENT)
		for _ponto in rng.randi_range(1, 20):
			var x := rng.randi_range(0, largura - 1)
			var y := rng.randi_range(0, altura - 1)
			amostra.set_pixel(x, y, Color(0.2, 0.8, 0.5, float(rng.randi_range(1, 255)) / 255.0))
		_comparar(amostra, quadro_w, quadro_h, "aleatório determinístico %d" % caso)
		var dados := amostra.get_data()
		var alfa := PackedByteArray()
		alfa.resize(largura * altura)
		for i in largura * altura:
			alfa[i] = dados[i * 4 + 3]
		for horizontal in [true, false]:
			var esperado := _referencia_caixa(alfa, largura, altura, quadro_w, quadro_h, horizontal)
			var obtido := Sombras._caixa1d(alfa, largura, altura, quadro_w, quadro_h, horizontal)
			if obtido != esperado:
				falhas += 1
				print("FALHOU: caixa 1D direta caso %d horizontal=%s" % [caso, horizontal])
	var rgb := Image.create(9, 8, false, Image.FORMAT_RGB8)
	rgb.fill(Color(0.3, 0.4, 0.8))
	_comparar(rgb, 4, 3, "entrada RGB sem canal alfa")
	for forma in [Vector4i(1, 1, 1, 1), Vector4i(1, 7, 1, 3), Vector4i(7, 1, 3, 1), Vector4i(10, 7, 3, 2)]:
		var fonte := PackedByteArray()
		fonte.resize(forma.x * forma.y)
		for i in fonte.size():
			fonte[i] = (i * 47 + 83) % 256
		for horizontal in [true, false]:
			var ref := _referencia_caixa(fonte, forma.x, forma.y, forma.z, forma.w, horizontal)
			var caixa := Sombras._caixa1d(fonte, forma.x, forma.y, forma.z, forma.w, horizontal)
			if caixa != ref:
				falhas += 1
				print("FALHOU: caixa 1D dimensões %s horizontal=%s" % [forma, horizontal])
	print("v2_sombras_blur falhas=%d duracao_ms=%d" % [falhas, Time.get_ticks_msec() - inicio])
	get_tree().quit(1 if falhas else 0)
