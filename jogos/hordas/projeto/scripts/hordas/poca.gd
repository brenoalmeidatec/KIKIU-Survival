extends RefCounted
## Poça de líquido em pixel art (café derramado e afins), gerada por código e guardada em cache por tamanho.
## Forma irregular de líquido (borda ondulada + gotinhas), achatada em perspectiva, rampa de tons,
## contorno escuro e brilho de reflexo do lado da luz (cima/esquerda, a mesma luz das sombras do jogo).
## Cada tamanho vira UMA textura: no jogo é só um carimbo por quadro.

const ACHATA := 0.6  # perspectiva do chão
const CAFE := ["170b06", "2e170b", "4a2814", "6b3c1f", "94603a", "d9b48a"]  # escuro -> reflexo

static var _cache := {}


## Textura da poça de raio r (em pixels de tela), arredondado de 4 em 4 pra reaproveitar o cache.
## variante (0 a 2) muda o desenho da borda, pra poças vizinhas não ficarem iguais.
static func textura(r: float, variante: int, rampa: Array = CAFE) -> ImageTexture:
	var rr := maxi(6, int(round(r / 4.0)) * 4)
	var chave := "%d|%d|%s" % [rr, variante, rampa[3]]
	if _cache.has(chave):
		return _cache[chave]
	var cores: Array = rampa.map(func(h): return Color(h))
	var w := rr * 2 + 8
	var h := int(rr * 2 * ACHATA) + 8
	var c := Vector2(w / 2.0, h / 2.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = rr * 31 + variante * 977
	var f1 := rng.randf_range(0, TAU)
	var f2 := rng.randf_range(0, TAU)
	# gotinhas em volta da borda
	var gotas := []
	for i in 3 + variante:
		var a := rng.randf_range(0, TAU)
		gotas.append([c + Vector2(cos(a) * rr * rng.randf_range(1.05, 1.2), sin(a) * rr * ACHATA * rng.randf_range(1.05, 1.2)), rng.randf_range(1.5, 3.0)])
	var dentro := func(x: float, y: float) -> float:
		# distância normalizada até a borda ondulada (<1 = dentro)
		var d := Vector2(x - c.x, (y - c.y) / ACHATA)
		var ang := d.angle()
		var borda := rr * (1.0 + 0.1 * sin(3.0 * ang + f1) + 0.06 * sin(5.0 * ang + f2))
		var n := d.length() / borda
		for g in gotas:
			if Vector2(x, y).distance_to(g[0]) < g[1]:
				n = minf(n, 0.95)
		return n
	for y in h:
		for x in w:
			var n: float = dentro.call(x + 0.5, y + 0.5)
			if n >= 1.0:
				continue
			# líquido parado é PLANO: borda rasa mais clara (a "crema" do café), centro fundo mais escuro.
			# (sombrear um lado claro e o outro escuro faz parecer um monte de terra.) O volume vem do reflexo.
			var k := 2
			if n > 0.88:
				k = 3
			elif n < 0.42:
				k = 1
			img.set_pixel(x, y, cores[k])
	# contorno escuro de 1 px (por dentro da borda)
	var base := img.duplicate()
	for y in h:
		for x in w:
			if base.get_pixel(x, y).a == 0.0:
				continue
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + v
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or base.get_pixelv(q).a == 0.0:
					img.set_pixel(x, y, cores[0])
					break
	# reflexo: um traço curvo de 1 px em cima/esquerda (luz batendo no líquido) e dois pontinhos
	for i in rr:
		var a := lerpf(PI * 1.05, PI * 1.45, float(i) / rr)
		var p := c + Vector2(cos(a) * rr * 0.62, sin(a) * rr * 0.62 * ACHATA)
		var pi := Vector2i(int(p.x), int(p.y))
		if pi.x >= 0 and pi.y >= 0 and pi.x < w and pi.y < h and img.get_pixelv(pi).a > 0.0:
			img.set_pixelv(pi, cores[4])
	for p in [c + Vector2(-rr * 0.35, -rr * 0.3 * ACHATA), c + Vector2(-rr * 0.2, -rr * 0.42 * ACHATA)]:
		var pi := Vector2i(int(p.x), int(p.y))
		if img.get_pixelv(pi).a > 0.0:
			img.set_pixelv(pi, cores[5])
	var t := ImageTexture.create_from_image(img)
	_cache[chave] = t
	return t
