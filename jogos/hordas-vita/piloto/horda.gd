extends Node2D
## Horda orientada a dados para o Vita (v2, depois da 1ª medição no aparelho: o gargalo é GDScript na CPU,
## ~0,09 ms por inimigo de lógica e ~0,09 ms de _draw). Nenhum nó por inimigo, arrays paralelos, um único _draw.
## Proteções de desempenho:
## - perto da tela, TODO quadro só soma pos += vel*dt e a fase; direção/vista são refeitas 1 quadro em 2 e a
##   separação 1 em 4 (revezado pelo índice); a grade espacial é refeita 1 quadro em 2;
## - longe: anda 1 quadro a cada `lod_longe` (dt multiplicado), sem separação; perdido longe demais renasce no anel;
## - separação com teto de VIZ_MAX vizinhos olhados;
## - desenho só do que está na tela (+ margem), no máximo `max_desenho`, ordem por Y com baldes (sem sort_custom);
## - atlas único com a SOMBRA JÁ ASSADA em cada quadro: 1 draw_texture_rect_region por inimigo, recortes prontos;
## - dados por tipo em arrays (nada de Dictionary no laço quente);
## - projéteis e golpe usam a grade (não varrem a horda).
## Folha do jogo: `cols` colunas (quadros de andar + a última, silhueta branca do flash) x `vistas` linhas.

const CELULA = 32.0
const VIZ_MAX = 6
const MARGEM = 48.0
const ATLAS_LARG = 1024
const PAD = 4                   # px a mais embaixo de cada quadro no atlas, onde cabe a sombra
const PROJ_MAX = 64

var lod_longe = 4
var max_desenho = 400
var ordenar_y = true

var tex_atlas: ImageTexture
var src_sangue = Rect2()
var src_proj = Rect2()

# por tipo (índice = tipo)
var t_vel = []
var t_raio = []
var t_nq = []                   # quadros de andar
var t_qx = []
var t_qy = []                   # altura do quadro no atlas (já com PAD)
var t_vistas = []
var t_quadro_px = []            # quadros de andar por px andado (nq / ciclo)
var t_src = []                  # Array de Rect2: [linha * nq + coluna]

# por inimigo
var pos = []
var vel = []
var vel_esc = []                # |vel| (pra fase pela distância)
var tp = []
var fase = []                   # em quadros de andar
var sep = []
var linha = []
var vira = []
var fogos = []                  # índices dos inimigos que emitem luz (fogo-fátuo)

# projéteis
var p_pos = []
var p_vel = []
var p_vida = []

var alvo = Vector2.ZERO
var visivel = Rect2()
var quadro = 0
var grade = {}
var idx_luz = -1

# medições do último quadro
var n_perto = 0
var n_desenhados = 0
var us_logica = 0
var us_desenho = 0
var us_proj = 0
var acertos = 0


func carregar(lista: Array, arq_proj: String) -> void:
	var blocos = []             # [Image, posição no atlas]
	var celulas = []            # por tipo: [img, vistas, nq, qx, qy_sprite]
	for d in lista:
		var img: Image = load("res://sprites/" + d.arquivo).get_data()
		img.convert(Image.FORMAT_RGBA8)
		var cols = int(d.cols)
		var vistas = int(d.vistas)
		var qx = img.get_width() / cols
		var qy = img.get_height() / vistas
		celulas.append([img, vistas, cols - 1, qx, qy])
		blocos.append(Vector2((cols - 1) * qx, vistas * (qy + PAD)))
	var img_sangue = _imagem_sangue()
	var img_proj: Image = load("res://sprites/" + arq_proj).get_data()
	img_proj.convert(Image.FORMAT_RGBA8)
	blocos.append(img_sangue.get_size())
	blocos.append(img_proj.get_size())
	# prateleiras
	var x = 0
	var y = 0
	var alt = 0
	var onde = []
	for b in blocos:
		if x + b.x > ATLAS_LARG:
			x = 0
			y += alt + 2
			alt = 0
		onde.append(Vector2(x, y))
		x += b.x + 2
		alt = max(alt, b.y)
	var altura = 256
	while altura < y + alt:
		altura *= 2
	var atlas = Image.new()
	atlas.create(ATLAS_LARG, altura, false, Image.FORMAT_RGBA8)
	for i in lista.size():
		var c = celulas[i]
		var img: Image = c[0]
		var vistas = c[1]
		var nq = c[2]
		var qx = c[3]
		var qy = c[4]
		var sombra = _imagem_sombra(qx, 8)
		var srcs = []
		for l in vistas:
			for q in nq:
				var dst = onde[i] + Vector2(q * qx, l * (qy + PAD))
				atlas.blend_rect(sombra, Rect2(0, 0, qx, 8), dst + Vector2(0, qy - 6))
				atlas.blend_rect(img, Rect2(q * qx, l * qy, qx, qy), dst)
				srcs.append(Rect2(dst, Vector2(qx, qy + PAD)))
		var d: Dictionary = lista[i]
		t_vel.append(float(d.velocidade))
		t_raio.append(float(d.raio))
		t_nq.append(nq)
		t_qx.append(float(qx))
		t_qy.append(float(qy + PAD))
		t_vistas.append(vistas)
		t_quadro_px.append(nq / max(qy * 0.7, 12.0))      # um ciclo a cada ~0,7 altura do bicho
		t_src.append(srcs)
		if d.id == "fogo_fatuo":
			idx_luz = i
	var n = lista.size()
	atlas.blit_rect(img_sangue, Rect2(Vector2.ZERO, img_sangue.get_size()), onde[n])
	atlas.blit_rect(img_proj, Rect2(Vector2.ZERO, img_proj.get_size()), onde[n + 1])
	src_sangue = Rect2(onde[n], img_sangue.get_size())
	src_proj = Rect2(onde[n + 1], img_proj.get_size())
	tex_atlas = ImageTexture.new()
	tex_atlas.create_from_image(atlas, 0)


func _imagem_sombra(larg: int, alt: int) -> Image:
	var img = Image.new()
	img.create(larg, alt, false, Image.FORMAT_RGBA8)
	img.lock()
	var rx = larg * 0.4
	var cx = (larg - 1) * 0.5
	var cy = (alt - 1) * 0.5
	for yy in alt:
		for xx in larg:
			var dx = (xx - cx) / rx
			var dy = (yy - cy) / (alt * 0.4)
			img.set_pixel(xx, yy, Color(0, 0, 0, 0.45 * clamp(1.0 - dx * dx - dy * dy, 0.0, 1.0)))
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
		var t = randi() % t_vel.size()
		pos.append(_ponto_no_anel())
		vel.append(Vector2.ZERO)
		vel_esc.append(0.0)
		tp.append(t)
		fase.append(randf() * 6.0)
		sep.append(Vector2.ZERO)
		linha.append(0)
		vira.append(false)
	if pos.size() > n:
		for a in [pos, vel, vel_esc, tp, fase, sep, linha, vira]:
			a.resize(n)
	fogos.clear()
	for i in tp.size():
		if tp[i] == idx_luz:
			fogos.append(i)
	grade.clear()


## Ponto fora da tela, num anel em volta do alvo (onde a horda nasce e renasce).
func _ponto_no_anel() -> Vector2:
	var meia = visivel.size.length() * 0.5
	var r = meia + 20.0 + randf() * 220.0
	return alvo + Vector2(r, 0).rotated(randf() * TAU)


func _montar_grade(perto: Rect2) -> void:
	grade = {}
	for i in pos.size():
		var p: Vector2 = pos[i]
		if perto.has_point(p):
			var c = int(floor(p.x / CELULA)) + int(floor(p.y / CELULA)) * 4096
			if grade.has(c):
				grade[c].append(i)
			else:
				grade[c] = [i]


func atualizar(dt: float) -> void:
	var t0 = OS.get_ticks_usec()
	quadro += 1
	var perto = visivel.grow(MARGEM)
	var longe2 = pow(visivel.size.length() * 1.6, 2)
	if quadro % 2 == 0 or grade.empty():
		_montar_grade(perto)
	n_perto = 0
	for i in pos.size():
		var p: Vector2 = pos[i]
		if perto.has_point(p):
			n_perto += 1
			var k = (i + quadro) % 4
			if k == 0:
				sep[i] = _separacao(i, p, t_raio[tp[i]])
			if k == 0 or k == 2:
				var t = tp[i]
				var d = alvo - p
				var dist = d.length()
				var v = sep[i] * 90.0
				if dist > 1.0:
					v += d * (t_vel[t] / dist)
				vel[i] = v
				vel_esc[i] = v.length()
				if t_vistas[t] > 1:
					linha[i] = int(clamp(round(rad2deg(atan2(abs(v.x), v.y)) / 45.0), 0, 4))   # 0 frente .. 4 costas
					vira[i] = v.x < 0.0
			pos[i] = p + vel[i] * dt
			fase[i] += vel_esc[i] * dt * t_quadro_px[tp[i]]
		elif (i + quadro) % lod_longe == 0:
			var d = alvo - p
			if d.length_squared() > longe2:
				pos[i] = _ponto_no_anel()
			else:
				pos[i] = p + d.normalized() * t_vel[tp[i]] * dt * lod_longe
	us_logica = OS.get_ticks_usec() - t0


func _separacao(i: int, p: Vector2, raio: float) -> Vector2:
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


func _matar(i: int, mortes: Array) -> void:
	mortes.append(pos[i])
	pos[i] = _ponto_no_anel()
	sep[i] = Vector2.ZERO


## Mata quem está a menos de `raio` do ponto (pela grade). Devolve as posições das mortes (pro sangue).
func golpe(centro: Vector2, raio: float) -> Array:
	var mortes = []
	var r2 = raio * raio
	var alc = int(ceil(raio / CELULA))
	var cx = int(floor(centro.x / CELULA))
	var cy = int(floor(centro.y / CELULA))
	for oy in range(-alc, alc + 1):
		for ox in range(-alc, alc + 1):
			var c = cx + ox + (cy + oy) * 4096
			if grade.has(c):
				for i in grade[c]:
					var p: Vector2 = pos[i]
					if p.distance_squared_to(centro) < r2:
						_matar(i, mortes)
	return mortes


func disparar(origem: Vector2, v: Vector2, vida: float) -> void:
	if p_pos.size() >= PROJ_MAX:
		return
	p_pos.append(origem)
	p_vel.append(v)
	p_vida.append(vida)


## Move os projéteis e acerta pela grade (só a célula onde o projétil está). Devolve as mortes (hoje nenhuma).
func atualizar_proj(dt: float) -> Array:
	var t0 = OS.get_ticks_usec()
	var mortes = []
	var k = p_pos.size() - 1
	while k >= 0:
		var p: Vector2 = p_pos[k] + p_vel[k] * dt
		p_vida[k] -= dt
		var morreu = p_vida[k] <= 0.0
		if not morreu:
			var c = int(floor(p.x / CELULA)) + int(floor(p.y / CELULA)) * 4096
			if grade.has(c):
				for i in grade[c]:
					var r = t_raio[tp[i]] + 4.0
					if p.distance_squared_to(pos[i] - Vector2(0, 10)) < r * r:
						acertos += 1     # acerta e some, sem matar (inimigo com vida): a densidade na tela fica comparável à 1ª medição
						morreu = true
						break
		if morreu:
			p_pos.remove(k)
			p_vel.remove(k)
			p_vida.remove(k)
		else:
			p_pos[k] = p
		k -= 1
	us_proj = OS.get_ticks_usec() - t0
	return mortes


func _draw() -> void:
	var t0 = OS.get_ticks_usec()
	var vis = visivel.grow(32.0)
	var nb = int(vis.size.y / 4.0) + 1 if ordenar_y else 1
	var baldes = []
	baldes.resize(nb)
	for b in nb:
		baldes[b] = []
	var cont = 0
	var y0 = vis.position.y
	for i in pos.size():
		var p: Vector2 = pos[i]
		if vis.has_point(p):
			if cont >= max_desenho:
				break
			cont += 1
			if ordenar_y:
				baldes[int(clamp((p.y - y0) * 0.25, 0, nb - 1))].append(i)
			else:
				baldes[0].append(i)
	n_desenhados = cont
	var atlas = tex_atlas
	for bl in baldes:
		for i in bl:
			var p: Vector2 = pos[i]
			var t = tp[i]
			var nq = t_nq[t]
			var src: Rect2 = t_src[t][linha[i] * nq + int(fase[i]) % nq]
			var qx = t_qx[t]
			var qy = t_qy[t]
			if vira[i]:
				draw_texture_rect_region(atlas, Rect2(p.x + qx * 0.5, p.y - qy + 6.0, -qx, qy), src)
			else:
				draw_texture_rect_region(atlas, Rect2(p.x - qx * 0.5, p.y - qy + 6.0, qx, qy), src)
	var ps = src_proj.size
	for k in p_pos.size():
		draw_texture_rect_region(atlas, Rect2(p_pos[k] - ps * 0.5 - Vector2(0, 10), ps), src_proj)
	us_desenho = OS.get_ticks_usec() - t0
