extends Node2D
## Horda orientada a dados para o Vita: nenhum nó por inimigo, arrays paralelos e um único _draw.
## Proteções de desempenho (cada uma pode ser medida ligando/desligando no main.gd):
## - perto da tela: lógica completa; longe: anda 1 quadro a cada `lod_longe` (com dt multiplicado) e sem separação;
## - separação por grade espacial, recalculada 1 quadro em 3 por bicho e com teto de vizinhos olhados;
## - desenho só do que está na tela (+ margem) e no máximo `max_desenho` bichos;
## - ordem por Y com baldes (linear), sem sort_custom (que chamaria GDScript n·log n vezes por quadro);
## - atlas único (corpos + sombra + sangue): o batching do GLES2 junta retângulos seguidos da mesma textura.

const CELULA = 32.0
const VIZ_MAX = 6              # teto de vizinhos olhados na separação (multidão densa não explode o custo)
const MARGEM = 48.0
const ATLAS_LADO = 1024

var usar_atlas = true
var ordenar_y = true
var lod_longe = 4
var max_desenho = 400

var tipos = []                 # {tex, src0 (Vector2), q (Vector2), vistas, vel, raio, ritmo}
var tex_atlas: ImageTexture
var tex_sombra: ImageTexture
var tex_sangue: ImageTexture
var src_sombra = Rect2()
var src_sangue = Rect2()

var pos = []                   # Vector2
var tp = []                    # int
var fase = []                  # float
var sep = []                   # Vector2 (empurrão de separação guardado entre recálculos)
var linha = []                 # int (vista)
var vira = []                  # bool (espelha)

var alvo = Vector2.ZERO
var visivel = Rect2()
var quadro = 0

# medições do último quadro
var n_perto = 0
var n_desenhados = 0
var us_logica = 0
var us_desenho = 0


func carregar(lista: Array) -> void:
	var img_sombra = _imagem_sombra()
	var img_sangue = _imagem_sangue()
	tex_sombra = _textura(img_sombra)
	tex_sangue = _textura(img_sangue)
	var atlas = Image.new()
	atlas.create(ATLAS_LADO, ATLAS_LADO, false, Image.FORMAT_RGBA8)
	var x = 0
	var y = 0
	var alt_prateleira = 0
	var blocos = []
	for d in lista:
		var img: Image = load("res://sprites/" + d.arquivo).get_data()
		img.convert(Image.FORMAT_RGBA8)
		blocos.append(img)
	blocos.append(img_sombra)
	blocos.append(img_sangue)
	var posicoes = []
	for img in blocos:
		if x + img.get_width() > ATLAS_LADO:
			x = 0
			y += alt_prateleira + 2
			alt_prateleira = 0
		atlas.blit_rect(img, Rect2(Vector2.ZERO, img.get_size()), Vector2(x, y))
		posicoes.append(Vector2(x, y))
		x += img.get_width() + 2
		alt_prateleira = max(alt_prateleira, img.get_height())
	tex_atlas = _textura(atlas)
	for i in lista.size():
		var d: Dictionary = lista[i]
		var img: Image = blocos[i]
		var vistas = int(d.vistas)
		tipos.append({
			"tex_solta": _textura(img), "src0": posicoes[i],
			"q": Vector2(img.get_width() / 3, img.get_height() / vistas), "vistas": vistas,
			"vel": float(d.velocidade), "raio": float(d.raio), "ritmo": float(d.ritmo)})
	src_sombra = Rect2(posicoes[lista.size()], img_sombra.get_size())
	src_sangue = Rect2(posicoes[lista.size() + 1], img_sangue.get_size())


func _textura(img: Image) -> ImageTexture:
	var t = ImageTexture.new()
	t.create_from_image(img, 0)   # sem filtro, sem mipmap, sem repetição
	return t


func _imagem_sombra() -> Image:
	var img = Image.new()
	img.create(24, 8, false, Image.FORMAT_RGBA8)
	img.lock()
	for yy in 8:
		for xx in 24:
			var dx = (xx - 11.5) / 12.0
			var dy = (yy - 3.5) / 4.0
			var d = dx * dx + dy * dy
			img.set_pixel(xx, yy, Color(0, 0, 0, 0.45 * clamp(1.0 - d, 0.0, 1.0)))
	img.unlock()
	return img


func _imagem_sangue() -> Image:
	var img = Image.new()
	img.create(16, 10, false, Image.FORMAT_RGBA8)
	img.lock()
	for yy in 10:
		for xx in 16:
			var dx = (xx - 7.5) / 8.0
			var dy = (yy - 4.5) / 5.0
			var d = dx * dx + dy * dy + 0.25 * sin(xx * 1.7 + yy * 2.3)
			img.set_pixel(xx, yy, Color(0.45, 0.02, 0.04, 0.85) if d < 0.8 else Color(0, 0, 0, 0))
	img.unlock()
	return img


func definir_quantidade(n: int) -> void:
	while pos.size() < n:
		pos.append(_ponto_no_anel())
		tp.append(randi() % tipos.size())
		fase.append(randf() * 3.0)
		sep.append(Vector2.ZERO)
		linha.append(0)
		vira.append(false)
	if pos.size() > n:
		pos.resize(n)
		tp.resize(n)
		fase.resize(n)
		sep.resize(n)
		linha.resize(n)
		vira.resize(n)


## Ponto fora da tela, num anel em volta do alvo (onde a horda nasce e renasce).
func _ponto_no_anel() -> Vector2:
	var meia = visivel.size.length() * 0.5
	var r = meia + 20.0 + randf() * 220.0
	return alvo + Vector2(r, 0).rotated(randf() * TAU)


func atualizar(dt: float) -> void:
	var t0 = OS.get_ticks_usec()
	quadro += 1
	var perto = visivel.grow(MARGEM)
	var longe2 = pow(visivel.size.length() * 1.6, 2)
	var n = pos.size()
	var grade = {}
	for i in n:
		var p: Vector2 = pos[i]
		if perto.has_point(p):
			var c = int(floor(p.x / CELULA)) + int(floor(p.y / CELULA)) * 4096
			if grade.has(c):
				grade[c].append(i)
			else:
				grade[c] = [i]
	n_perto = 0
	for i in n:
		var p: Vector2 = pos[i]
		var t: Dictionary = tipos[tp[i]]
		if perto.has_point(p):
			n_perto += 1
			var d = alvo - p
			var dist = d.length()
			var dir = d / dist if dist > 1.0 else Vector2.ZERO
			if (i + quadro) % 3 == 0:
				sep[i] = _separacao(i, p, grade, t.raio)
			var v: Vector2 = dir * t.vel + sep[i] * 90.0
			pos[i] = p + v * dt
			fase[i] += dt
			if (i + quadro) % 4 == 0 and t.vistas > 1:
				var ang = rad2deg(atan2(abs(v.x), v.y))     # 0 = de frente (descendo), 180 = de costas
				linha[i] = int(clamp(round(ang / 45.0), 0, 4))
				vira[i] = v.x < 0.0
		elif (i + quadro) % lod_longe == 0:
			var d = alvo - p
			if d.length_squared() > longe2:
				pos[i] = _ponto_no_anel()                   # perdido longe demais: renasce no anel
			else:
				pos[i] = p + d.normalized() * t.vel * dt * lod_longe
			fase[i] += dt * lod_longe
	us_logica = OS.get_ticks_usec() - t0


func _separacao(i: int, p: Vector2, grade: Dictionary, raio: float) -> Vector2:
	var cx = int(floor(p.x / CELULA))
	var cy = int(floor(p.y / CELULA))
	var empurra = Vector2.ZERO
	var olhados = 0
	var lim = raio * 1.6
	var lim2 = lim * lim
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var c = cx + ox + (cy + oy) * 4096
			if not grade.has(c):
				continue
			for j in grade[c]:
				if j == i:
					continue
				var dif: Vector2 = p - pos[j]
				var d2 = dif.length_squared()
				if d2 < lim2 and d2 > 0.01:
					var d = sqrt(d2)
					empurra += dif / d * (1.0 - d / lim)
				olhados += 1
				if olhados >= VIZ_MAX:
					return empurra
	return empurra


## Mata quem está a menos de `raio` do ponto e renasce no anel. Devolve as posições das mortes (pro sangue).
func golpe(centro: Vector2, raio: float) -> Array:
	var mortes = []
	var r2 = raio * raio
	for i in pos.size():
		var p: Vector2 = pos[i]
		if p.distance_squared_to(centro) < r2:
			mortes.append(p)
			pos[i] = _ponto_no_anel()
			sep[i] = Vector2.ZERO
	return mortes


func _draw() -> void:
	var t0 = OS.get_ticks_usec()
	var vis = visivel.grow(32.0)
	var baldes = []
	var nb = 1
	if ordenar_y:
		nb = int(vis.size.y / 4.0) + 1
	baldes.resize(nb)
	for b in nb:
		baldes[b] = []
	var cont = 0
	for i in pos.size():
		var p: Vector2 = pos[i]
		if vis.has_point(p):
			if cont >= max_desenho:
				break
			cont += 1
			var b = 0
			if ordenar_y:
				b = int(clamp((p.y - vis.position.y) / 4.0, 0, nb - 1))
			baldes[b].append(i)
	n_desenhados = cont
	var tex_s: Texture = tex_atlas if usar_atlas else tex_sombra
	var src_s = src_sombra if usar_atlas else Rect2(Vector2.ZERO, src_sombra.size)
	# 1) todas as sombras (um lote só)
	for bl in baldes:
		for i in bl:
			var p: Vector2 = pos[i]
			var q: Vector2 = tipos[tp[i]].q
			draw_texture_rect_region(tex_s, Rect2(p.x - q.x * 0.4, p.y - 3.0, q.x * 0.8, 6.0), src_s)
	# 2) corpos, de cima pra baixo
	for bl in baldes:
		for i in bl:
			var p: Vector2 = pos[i]
			var t: Dictionary = tipos[tp[i]]
			var q: Vector2 = t.q
			var col = int(fase[i] * t.ritmo) % 2     # a folha tem 3 colunas: 2 de andar + a silhueta branca do flash de dano
			var src = Rect2(Vector2(col * q.x, linha[i] * q.y), q)
			var tex: Texture = t.tex_solta
			if usar_atlas:
				src.position += t.src0
				tex = tex_atlas
			var dst = Rect2(p.x - q.x * 0.5, p.y - q.y + 2.0, q.x, q.y)
			if vira[i]:
				dst.position.x += q.x
				dst.size.x = -q.x
			draw_texture_rect_region(tex, dst, src)
	us_desenho = OS.get_ticks_usec() - t0
