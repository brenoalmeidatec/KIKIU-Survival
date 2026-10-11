extends RefCounted
## Sombras dinâmicas da v2 (extraídas do protótipo cara_nova): a silhueta do sprite é projetada no chão, longe da luz, por CISALHAMENTO a
## partir dos pés (nunca rotação). Modos (opção "sombras" da aba Gráficos): baixa = mancha oval fixa nos pés; média = UMA sombra embaçada
## com a soma ponderada das luzes; alta = silhueta nítida das 2 luzes que mais iluminam. O sprite de sombra só existe/aparece para ator
## ATIVO (na tela, com margem): `ativar(ator, bool)`. As luzes vêm de `luzes` (luzes.gd: só as que alcançam a tela).

const Ator := preload("res://v2/ator.gd")
const NENHUMA := 0
const BAIXA := 1
const MEDIA := 2
const ALTA := 3
const NOMES := ["nenhuma", "baixa", "media", "alta"]
const ACHATA := 0.7071  # câmera a 45 graus: o eixo y do chão aparece comprimido por sen(45)
const SOMBRA_FADE := 140.0  # comprimento (px do sprite) em que a sombra esmaece
const ALT_LUZ := 2.2  # a altura da luz (espaço do normal map) rende ~2x na tela a 45 graus
const L_MIN := 0.08  # comprimento mínimo da sombra / altura do sprite (luz em cima: vira mancha)
const Y_MIN := 0.2  # espessura vertical mínima do eixo y da sombra (luz bem ao lado: não vira linha)
const SUAVIZA := 12.0  # vetor = lerp(alvo, 1 - exp(-12 dt))
const LUZ_REF := 1.2  # intensidade da luz a partir da qual a sombra tem força total
const GRAD_OFF := [0.0, 0.22, 0.55, 1.0]  # queda das luzes (a mesma da textura das PointLight2D, em luzes.gd)
const GRAD_VAL := [1.0, 0.5, 0.1, 0.0]

var modo := MEDIA
var luzes  # luzes.gd: dpos, dr, de, dh (as luzes ativas) e dn
var raiz_sombras: Node2D
var raiz_blobs: Node2D
var us_script := 0  # tempo de script (só para a medição)
var _mat: ShaderMaterial
var _tex_blob: GradientTexture2D
var _todos: Array[Ator] = []
var _lv := PackedFloat32Array()  # peso de cada luz sobre o ator em atualização (energia x atenuação)


func montar(mundo: Node2D) -> void:
	raiz_blobs = Node2D.new()
	raiz_blobs.z_index = -51
	mundo.add_child(raiz_blobs)
	raiz_sombras = Node2D.new()
	raiz_sombras.z_index = -50
	mundo.add_child(raiz_sombras)
	_mat = _material_sombra()
	_tex_blob = _textura_blob()


# ------------------------------------------------------------------ recursos


## Sombra do modo médio: só o alfa da folha (rgb preto), borrado UMA vez no carregamento (2 passes de caixa 3x3 separável, sem vazar
## entre quadros de w x h). Em tempo de execução é só uma textura a mais, sem custo de shader.
static func borrar_folha(im: Image, w: int, h: int) -> ImageTexture:
	var cp := im.duplicate() as Image
	cp.convert(Image.FORMAT_RGBA8)
	var iw := cp.get_width()
	var ih := cp.get_height()
	var dados := cp.get_data()
	var a := PackedByteArray()
	a.resize(iw * ih)
	for i in iw * ih:
		a[i] = dados[i * 4 + 3]
	for passe in 2:
		a = _caixa1d(a, iw, ih, w, h, true)
		a = _caixa1d(a, iw, ih, w, h, false)
	var saida := PackedByteArray()
	saida.resize(iw * ih * 4)
	for i in iw * ih:
		saida[i * 4 + 3] = a[i]
	return ImageTexture.create_from_image(Image.create_from_data(iw, ih, false, Image.FORMAT_RGBA8, saida))


static func _caixa1d(a: PackedByteArray, iw: int, ih: int, w: int, h: int, horiz: bool) -> PackedByteArray:
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


## preto, sem luz, esmaecendo ao longo da altura do sprite (ou seja, ao longo do comprimento da sombra)
func _material_sombra() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = (
		(
			"shader_type canvas_item;\nrender_mode unshaded;\nuniform float fade_len = %.1f;\nvarying float up;\n"
			+ "void vertex(){ up = -VERTEX.y; }\n"
			+ "void fragment(){ COLOR = vec4(0.0, 0.0, 0.0, COLOR.a * clamp(1.0 - up / fade_len, 0.12, 1.0)); }\n"
		)
		% SOMBRA_FADE
	)
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _textura_blob() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 32
	return t


# ------------------------------------------------------------------ registro e modo


func _sprite_sombra(a: Ator) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.material = _mat
	sp.light_mask = 0
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sp.offset = a.offset
	if a.regiao != Rect2():
		sp.region_enabled = true
		sp.region_rect = a.regiao
	sp.flip_h = a.espelha
	sp.texture = a.tex_b if modo == MEDIA else a.tex_n
	sp.visible = false
	raiz_sombras.add_child(sp)
	return sp


## Cria blob + 2 sombras (todos escondidos) para cada ator da lista, agrupando por textura para o lote do renderizador não quebrar.
func registrar_lote(lista: Array) -> void:
	var ordenada := lista.duplicate()
	ordenada.sort_custom(func(x, y): return str(x.chave) < str(y.chave))
	for a: Ator in ordenada:
		var b := Sprite2D.new()
		b.texture = _tex_blob
		b.light_mask = 0
		b.visible = false
		b.position = a.raiz.position + Vector2(0, -1)
		raiz_blobs.add_child(b)
		a.blob = b
	for a: Ator in ordenada:
		a.sh1 = _sprite_sombra(a)
	for a: Ator in ordenada:
		a.sh2 = _sprite_sombra(a)
		_todos.append(a)


func definir_modo(m: int) -> void:
	modo = m
	for a in _todos:
		var tx: Texture2D = a.tex_b if m == MEDIA else a.tex_n
		a.sh1.texture = tx
		a.sh2.texture = tx
		a.sh1.visible = false
		a.sh2.visible = false
		a.sl = [-1, -1]
		a.sa = [0.0, 0.0]
		a.t_ult = -1.0
		a.blob.visible = a.ativo and m != NENHUMA
		if a.ativo and m == BAIXA:
			_blob(a, 1.0, 0.62)
	raiz_sombras.visible = m >= MEDIA


## Liga ou desliga a sombra de um ator (entrou ou saiu da tela). Desligado: nada visível e nenhuma conta por quadro.
func ativar(a: Ator, ligar: bool) -> void:
	if a.ativo == ligar:
		return
	a.ativo = ligar
	if ligar:
		a.sl = [-1, -1]
		a.sa = [0.0, 0.0]
		a.t_ult = -1.0
		a.blob.visible = modo != NENHUMA
		if modo == BAIXA:
			_blob(a, 1.0, 0.62)
	else:
		a.blob.visible = false
		a.sh1.visible = false
		a.sh2.visible = false


func _blob(a: Ator, escala: float, alfa: float) -> void:
	var k := a.larg_blob * escala / 64.0
	a.blob.scale = Vector2(k, k * 0.9)
	a.blob.modulate.a = alfa
	a.blob.position = a.raiz.position + Vector2(0, -1)


# ------------------------------------------------------------------ geometria


## mesma curva do gradiente da textura das PointLight2D (GRAD_OFF / GRAD_VAL)
func _atenua(d: float, r: float) -> float:
	var u := d / r
	if u >= 1.0:
		return 0.0
	for i in range(1, GRAD_OFF.size()):
		if u < GRAD_OFF[i]:
			return lerpf(GRAD_VAL[i - 1], GRAD_VAL[i], (u - GRAD_OFF[i - 1]) / (GRAD_OFF[i] - GRAD_OFF[i - 1]))
	return 0.0


## vetor no chão (mundo) que a sombra aponta: para longe da luz; a tela comprime o y por sen(45)
func _dir_chao(pos: Vector2, luz: Vector2) -> Vector2:
	var g := Vector2(pos.x - luz.x, (pos.y - luz.y) / ACHATA)
	return g if g.length_squared() > 0.0001 else Vector2(0, 1)


## Para onde vai a ponta da sombra, partindo dos pés, em múltiplos da altura do sprite: d * L / H, com o y achatado por sen(45).
## L = H * |v| / max(h_luz - h_obj, 8) (luz baixa e longe = sombra longa; luz em cima = mancha). h_luz fica no espaço do normal map (px),
## e na tela ele rende ~2x (ALT_LUZ), por isso a escala. Limitado por L_MIN e rmax.
func _vetor_sombra(pos: Vector2, luz: Vector2, h_luz: float, alt: float, rmax: float) -> Vector2:
	var g := _dir_chao(pos, luz)
	var dist := g.length()
	var r := clampf(dist / maxf(h_luz * ALT_LUZ - alt * 0.5, 8.0), L_MIN, rmax)
	var d := g / dist
	return Vector2(d.x, d.y * ACHATA) * r


## CISALHAMENTO a partir dos pés, nunca rotação: a base do sprite fica horizontal e presa aos pés (origem), e o topo (local y = -H)
## vai para pes + vec * H. x_axis = (1, 0) e y_axis = -vec: vec.y > 0 (sombra vindo para a câmera) espelha na vertical, que é o certo.
## A espessura vertical nunca cai abaixo de Y_MIN: sem linha.
func _posicionar(sp: Sprite2D, pos: Vector2, vec: Vector2, esc: float, alfa: float) -> void:
	var vy := vec.y
	if absf(vy) < Y_MIN:
		vy = Y_MIN if vy >= 0.0 else -Y_MIN
	sp.transform = Transform2D(Vector2(esc, 0.0), Vector2(-vec.x, -vy) * esc, pos)
	# com a luz bem ao lado a silhueta é um fio: o alfa cai um pouco e o estalo do espelho (vy muda de sinal) quase não aparece
	sp.modulate.a = alfa * lerpf(0.45, 1.0, smoothstep(0.0, 0.3, absf(vec.y)))
	sp.visible = alfa > 0.01


## vetor e alfa andam até o alvo com 1 - exp(-12 dt): o tremor da tocha mexe no máximo no alfa, e uma troca de luz vira deslize
func _suaviza_slot(a: Ator, slot: int, alvo_vec: Vector2, alvo_alfa: float, k: float) -> void:
	a.sv[slot] = alvo_vec if k >= 1.0 else a.sv[slot].lerp(alvo_vec, k)
	a.sa[slot] = lerpf(a.sa[slot], alvo_alfa, k)


## Atualiza a sombra de UM ator ativo (t = tempo do mundo). Quem chama escolhe a frequência (parado: a cada 2 quadros; móvel: todo quadro).
func atualizar(a: Ator, t: float) -> void:
	if modo == BAIXA:
		_blob(a, 1.0, 0.62)
		return
	if modo < MEDIA:
		return
	var t0 := Time.get_ticks_usec()
	var pos := a.raiz.position
	var centro := pos + Vector2(0, -a.alt * 0.35)
	var esc := a.esc
	var rmax := a.rmax
	var alt := a.alt
	var n: int = luzes.dn
	var dt := t - a.t_ult if a.t_ult >= 0.0 else 1.0
	a.t_ult = t
	var k := 1.0 - exp(-SUAVIZA * dt)
	_lv.resize(n)
	for i in n:
		_lv[i] = luzes.de[i] * _atenua(centro.distance_to(luzes.dpos[i]), luzes.dr[i])
	if modo == MEDIA:
		# uma sombra só: soma ponderada dos vetores de TODAS as luzes (peso = energia x atenuação). Ninguém "assume" de repente:
		# a direção gira junto com os pesos, e luzes opostas se anulam (sombra curta = mancha)
		var soma := Vector2.ZERO
		var soma_w := 0.0
		var vmax := 0.0
		for i in n:
			var v := _lv[i]
			if v < 0.02:
				continue
			soma += _vetor_sombra(pos, luzes.dpos[i], luzes.dh[i], alt, rmax) * v
			soma_w += v
			vmax = maxf(vmax, v)
		var forca := clampf(vmax / LUZ_REF, 0.0, 1.0)
		var vec := soma / soma_w if soma_w > 0.0 else Vector2.ZERO
		var alfa := 0.6 * forca * smoothstep(0.06, 0.25, vec.length())
		_suaviza_slot(a, 0, vec, alfa, k)
		_posicionar(a.sh1, pos, a.sv[0], esc, a.sa[0])
		_blob(a, lerpf(1.0, 0.7, forca), lerpf(0.4, 0.28, forca))
	else:
		# alto: as 2 luzes que mais iluminam, cada uma com sua sombra e alfa proporcional ao peso. Cada sombra (slot) segue a SUA luz
		# enquanto ela estiver entre as 2 maiores; a luz nova só ocupa o slot que ficou livre, e a troca é um deslize
		var i1 := -1
		var i2 := -1
		var v1 := 0.0
		var v2 := 0.0
		for i in n:
			var v := _lv[i]
			if v > v1:
				i2 = i1
				v2 = v1
				i1 = i
				v1 = v
			elif v > v2:
				i2 = i
				v2 = v
		var ativas: Array[int] = []
		if i1 >= 0 and v1 > 0.02:
			ativas.append(i1)
		if i2 >= 0 and v2 > 0.1:
			ativas.append(i2)
		for s in 2:
			if a.sl[s] != -1 and not ativas.has(a.sl[s]):
				a.sl[s] = -1
		for i in ativas:
			if not a.sl.has(i):
				a.sl[a.sl.find(-1)] = i
		var fator := 0.7 if ativas.size() > 1 else 1.0
		for s in 2:
			var li: int = a.sl[s]
			var vec: Vector2 = a.sv[s]
			var alfa := 0.0
			if li >= 0:
				vec = _vetor_sombra(pos, luzes.dpos[li], luzes.dh[li], alt, rmax)
				alfa = 0.7 * fator * clampf(_lv[li] / LUZ_REF, 0.0, 1.0) * smoothstep(0.06, 0.25, vec.length())
			if li >= 0 and a.sa[s] < 0.01:
				a.sv[s] = vec  # slot que estava apagado nasce já no lugar certo (nada de deslizar de longe)
			_suaviza_slot(a, s, vec, alfa, k)
			_posicionar(a.sh1 if s == 0 else a.sh2, pos, a.sv[s], esc, a.sa[s])
		_blob(a, lerpf(1.0, 0.45, clampf(v1 / LUZ_REF, 0.0, 1.0)), lerpf(0.4, 0.85, clampf(v1 / LUZ_REF, 0.0, 1.0)))
	us_script += Time.get_ticks_usec() - t0
