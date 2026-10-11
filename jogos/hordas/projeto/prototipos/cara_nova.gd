extends Node2D
## Protótipo da cara nova (V1 + V2), cena de teste FORA do jogo: mundo de 960x540, chão e árvores da Floresta, luz escura
## com PointLight2D e sprites com ALBEDO + NORMAL (CanvasTexture). Os sprites vêm de jogos/hordas/prototipos/cara_nova/sprites/
## (gerados por gerar_cara_nova.py), lidos por caminho de fora de res:// para não duplicar nada em assets/.
##
## Uso (a partir de jogos/hordas):
##   godot --path projeto res://prototipos/cara_nova.tscn -- --fotos=PASTA --seq=1.0,2.0
##   godot --path projeto res://prototipos/cara_nova.tscn -- --medir --luzes=3 --sprites=250 --duracao=6
## Opções de arte (para iterar): --amb=1c2a24 --h_tocha=18 --e_tocha=1.9 --h_magia=24 --sem_normal --sem_vinheta --sem_olhos
##   --chao=1 (escala do chão) --nomes (rótulos) --samurai (herói de armadura vermelha)
## Sombras (silhueta do sprite projetada no chão, longe da luz): --sombra=baixa|media|alta|nenhuma (padrão media).
## Sem --fotos e sem --medir a cena fica aberta (modo livre): teclas 1/2/3 (0 desliga) trocam o modo, WASD anda com o herói,
## L faz a luz azul seguir o mouse (--azul=x,y fixa a luz azul num ponto), T leva a tocha e a aura junto com o herói. --sem_vsync solta o fps; --rotulo mostra o rótulo nas fotos.

const PASTA := "../prototipos/cara_nova/sprites"
const LARG := 960
const ALT := 540
const HEROI_POS := Vector2(470, 292)
const NENHUMA := 0
const BAIXA := 1
const MEDIA := 2
const ALTA := 3
const NOMES_SOMBRA := ["nenhuma", "baixa", "media", "alta"]
const ACHATA := 0.7071  # câmera a 45 graus: o eixo y do chão aparece comprimido por sen(45)
const MARGEM := 3  # px transparentes em volta de cada enfeite recortado: o blur da sombra não corta na borda
const SOMBRA_FADE := 140.0  # comprimento (px do sprite) em que a sombra esmaece
const ALT_LUZ := 2.2  # a altura da luz (espaço do normal map) rende ~2x na tela a 45 graus
const L_MIN := 0.08  # comprimento mínimo da sombra / altura do sprite (luz em cima: vira mancha)
const Y_MIN := 0.2  # espessura vertical mínima do eixo y da sombra (luz bem ao lado: não vira linha)
const SUAVIZA := 12.0  # vetor = lerp(alvo, 1 - exp(-12 dt))
const LUZ_REF := 1.2  # intensidade da luz a partir da qual a sombra tem força total

var _a := {}
var _t := 0.0
var _imgs := {}
var _tipos := {}
var _atores: Array = []
var _luzes: Array = []
var _fotos := ""
var _seq: Array = []
var _proximo := 0
var _modo := "foto"
var _medicao := {"inicio": -1.0, "frames": 0, "aquecer": 1.5, "duracao": 6.0}
var _tex_luz: GradientTexture2D
var _tex_sombra: GradientTexture2D
var _mundo: Node2D
var _olhos_raiz: Node2D
var _com_normal := true
var _com_olhos := true
var _sombra := MEDIA
var _sombras: Node2D
var _blobs: Node2D
var _mat_sombra: ShaderMaterial
var _arvores: Array = []  # cenário estático (árvores, pedras, arbustos...): só o transform da sombra muda
var _itens_cen := {}
var _passo := -1
var _quadros := 0
var _us_sombra := 0  # tempo de script das sombras (só para a medição)
var _heroi: Dictionary = {}
var _heroi_anda := false
var _lpos := PackedVector2Array()
var _lr := PackedFloat32Array()
var _le := PackedFloat32Array()
var _lh := PackedFloat32Array()
var _lv := PackedFloat32Array()  # peso de cada luz sobre o ator em atualização (energia x atenuação)
var _azul_mouse := false
var _tocha_leva := false
var _rotulo: Label
var _rotulo_t := 0.0
var _ms_blur := 0.0


func _ready() -> void:
	_a = _argumentos()
	_fotos = str(_a.get("fotos", ""))
	_seq = str(_a.get("seq", "1.0")).split(",")
	_modo = "medir" if _a.has("medir") else ("foto" if _fotos != "" else "livre")
	var qual := NOMES_SOMBRA.find(str(_a.get("sombra", "media")))
	_sombra = qual if qual >= 0 else MEDIA
	_medicao["duracao"] = float(_a.get("duracao", 6.0))
	_com_normal = not _a.has("sem_normal")
	_com_olhos = not _a.has("sem_olhos")
	var janela := get_window()
	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	janela.content_scale_size = Vector2i(LARG, ALT)
	janela.size = Vector2i(1280, 720)
	if _modo == "medir" or _a.has("sem_vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	RenderingServer.set_default_clear_color(Color(0.02, 0.03, 0.03))
	_tex_luz = _textura_luz()
	_tex_sombra = _textura_sombra()
	_montar()


func _argumentos() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var partes := a.trim_prefix("--").split("=", true, 1)
		d[partes[0]] = partes[1] if partes.size() > 1 else "1"
	return d


func _num(chave: String, padrao: float) -> float:
	return float(_a.get(chave, padrao))


# ------------------------------------------------------------------ recursos


func _imagem(nome: String) -> Image:
	if not _imgs.has(nome):
		var caminho := ProjectSettings.globalize_path("res://").path_join(PASTA).path_join(nome).simplify_path()
		var im := Image.load_from_file(caminho)
		if im == null:
			push_error("sem imagem: " + caminho)
		_imgs[nome] = im
	return _imgs[nome]


func _tem(nome: String) -> bool:
	var caminho := ProjectSettings.globalize_path("res://").path_join(PASTA).path_join(nome).simplify_path()
	return FileAccess.file_exists(caminho)


func _tipo(nome: String) -> Dictionary:
	if _tipos.has(nome):
		return _tipos[nome]
	var caminho := ProjectSettings.globalize_path("res://").path_join(PASTA).path_join(nome + ".json").simplify_path()
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	var t := CanvasTexture.new()
	var alb := ImageTexture.create_from_image(_imagem(nome + "_albedo.png"))
	t.diffuse_texture = alb
	if _com_normal:
		t.normal_texture = ImageTexture.create_from_image(_imagem(nome + "_normal.png"))
	var d := {"tex": t, "w": int(info.quadro[0]), "h": int(info.quadro[1]), "info": info, "emissao": null, "alb": alb}
	d["blur"] = _borrar_folha(_imagem(nome + "_albedo.png"), d.w, d.h)
	if _tem(nome + "_emissao.png"):
		d.emissao = ImageTexture.create_from_image(_imagem(nome + "_emissao.png"))
	d["pe"] = int(info.get("pe_y", info.quadro[1] - 2))
	_tipos[nome] = d
	return d


func _textura_luz() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.62, 0.62, 0.62, 1), Color(0.2, 0.2, 0.2, 1), Color(0, 0, 0, 1)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


func _textura_sombra() -> GradientTexture2D:
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


# ------------------------------------------------------------------ sombras


func _borrar_folha(im: Image, w: int, h: int) -> ImageTexture:
	## Sombra do modo médio: só o alfa da folha (rgb preto), borrado UMA vez no carregamento (2 passes de caixa 3x3 separável,
	## sem vazar entre quadros de w x h). Em tempo de execução é só uma textura a mais, sem custo de shader.
	var t0 := Time.get_ticks_usec()
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
	_ms_blur += (Time.get_ticks_usec() - t0) / 1000.0
	return ImageTexture.create_from_image(Image.create_from_data(iw, ih, false, Image.FORMAT_RGBA8, saida))


func _caixa1d(a: PackedByteArray, iw: int, ih: int, w: int, h: int, horiz: bool) -> PackedByteArray:
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


func _material_sombra() -> ShaderMaterial:
	## preto, sem luz, esmaecendo ao longo da altura do sprite (ou seja, ao longo do comprimento da sombra)
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


func _sprite_sombra(a: Dictionary) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.material = _mat_sombra
	sp.light_mask = 0
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sp.offset = a.offset
	if a.region != Rect2():
		sp.region_enabled = true
		sp.region_rect = a.region
	sp.flip_h = a.espelha
	sp.visible = false
	_sombras.add_child(sp)
	return sp


func _criar_sombras(lista: Array) -> void:
	## cria blob + 2 sombras direcionais por dono; agrupa por textura para o lote do renderizador não quebrar
	var ordenada := lista.duplicate()
	ordenada.sort_custom(func(x, y): return str(x.chave) < str(y.chave))
	for a in ordenada:
		var b := Sprite2D.new()
		b.texture = _tex_sombra
		b.light_mask = 0
		b.position = a.raiz.position + Vector2(0, -1)
		_blobs.add_child(b)
		a["blob"] = b
	for a in ordenada:
		a["sh1"] = _sprite_sombra(a)
	for a in ordenada:
		a["sh2"] = _sprite_sombra(a)
		a["sl"] = [-1, -1]
		a["sv"] = [Vector2.ZERO, Vector2.ZERO]
		a["sa"] = [0.0, 0.0]
		a["t_ult"] = -1.0


func _trocar_sombra(m: int) -> void:
	_sombra = m
	for a in _atores + _arvores:
		var tx: Texture2D = a.tex_b if m == MEDIA else a.tex_n
		a.sh1.texture = tx
		a.sh2.texture = tx
		a.sh1.visible = false
		a.sh2.visible = false
		a.sl = [-1, -1]
		a.sa = [0.0, 0.0]
		a.t_ult = -1.0
		a.blob.visible = m != NENHUMA
	_sombras.visible = m >= MEDIA
	if m == BAIXA:
		for a in _atores + _arvores:
			_blob(a, 1.0, 0.62)


func _blob(a: Dictionary, escala: float, alfa: float) -> void:
	var b: Sprite2D = a.blob
	var k: float = a.larg_blob * escala / 64.0
	b.scale = Vector2(k, k * 0.9)
	b.modulate.a = alfa
	b.position = a.raiz.position + Vector2(0, -1)


func _atenua(d: float, r: float) -> float:
	## mesma curva do gradiente da textura das PointLight2D: 1 no centro, 0,62 a 30%, 0,2 a 65%, 0 na borda
	var u := d / r
	if u >= 1.0:
		return 0.0
	if u < 0.3:
		return lerpf(1.0, 0.62, u / 0.3)
	if u < 0.65:
		return lerpf(0.62, 0.2, (u - 0.3) / 0.35)
	return lerpf(0.2, 0.0, (u - 0.65) / 0.35)


func _dir_chao(pos: Vector2, luz: Vector2) -> Vector2:
	## vetor no chão (mundo) que a sombra aponta: para longe da luz; a tela comprime o y por sen(45)
	var g := Vector2(pos.x - luz.x, (pos.y - luz.y) / ACHATA)
	return g if g.length_squared() > 0.0001 else Vector2(0, 1)


func _vetor_sombra(pos: Vector2, luz: Vector2, h_luz: float, alt: float, rmax: float) -> Vector2:
	## Para onde vai a ponta da sombra, partindo dos pés, em múltiplos da altura do sprite: d * L / H, com o y achatado por sen(45).
	## L = H * |v| / max(h_luz - h_obj, 8) (luz baixa e longe = sombra longa; luz em cima = mancha). h_luz fica no espaço do normal map
	## (px), e na tela ele rende ~2x (ALT_LUZ), por isso a escala. Limitado por L_MIN e rmax.
	var g := _dir_chao(pos, luz)
	var dist := g.length()
	var r := clampf(dist / maxf(h_luz * ALT_LUZ - alt * 0.5, 8.0), L_MIN, rmax)
	var d := g / dist
	return Vector2(d.x, d.y * ACHATA) * r


func _posicionar(sp: Sprite2D, pos: Vector2, vec: Vector2, esc: float, alfa: float) -> void:
	## CISALHAMENTO a partir dos pés, nunca rotação: a base do sprite fica horizontal e presa aos pés (origem), e o topo (local y = -H)
	## vai para pes + vec * H. x_axis = (1, 0) e y_axis = -vec: vec.y > 0 (sombra vindo para a câmera) espelha na vertical, que é o certo.
	## Sem escala negativa (o espelho dos monstros é o flip_h do sprite). A espessura vertical nunca cai abaixo de Y_MIN: sem linha.
	var vy := vec.y
	if absf(vy) < Y_MIN:
		vy = Y_MIN if vy >= 0.0 else -Y_MIN
	sp.transform = Transform2D(Vector2(esc, 0.0), Vector2(-vec.x, -vy) * esc, pos)
	# com a luz bem ao lado a silhueta é um fio (billboard de perfil): o alfa cai um pouco e o estalo do espelho (vy muda de sinal) quase não aparece
	sp.modulate.a = alfa * lerpf(0.45, 1.0, smoothstep(0.0, 0.3, absf(vec.y)))
	sp.visible = alfa > 0.01


func _atualizar_luzes_dados() -> void:
	var n := _luzes.size()
	_lpos.resize(n)
	_lr.resize(n)
	_le.resize(n)
	_lh.resize(n)
	_lv.resize(n)
	for i in n:
		var l: Dictionary = _luzes[i]
		var luz: PointLight2D = l.luz
		_lpos[i] = luz.position
		_lr[i] = l.def.r
		_le[i] = luz.energy
		_lh[i] = luz.height


func _suaviza_slot(a: Dictionary, slot: int, alvo_vec: Vector2, alvo_alfa: float, k: float) -> void:
	## vetor e alfa andam até o alvo com 1 - exp(-12 dt): o tremor da tocha mexe no máximo no alfa, e uma troca de luz vira deslize
	a.sv[slot] = alvo_vec if k >= 1.0 else a.sv[slot].lerp(alvo_vec, k)
	a.sa[slot] = lerpf(a.sa[slot], alvo_alfa, k)


func _atualizar_sombra(a: Dictionary) -> void:
	var pos: Vector2 = a.raiz.position
	var centro := pos + Vector2(0, -a.alt * 0.35)
	var esc: float = a.esc
	var rmax: float = a.rmax
	var alt: float = a.alt
	var n := _lpos.size()
	var dt: float = _t - a.t_ult if a.t_ult >= 0.0 else 1.0
	a.t_ult = _t
	var k := 1.0 - exp(-SUAVIZA * dt)
	for i in n:
		_lv[i] = _le[i] * _atenua(centro.distance_to(_lpos[i]), _lr[i])
	if _sombra == MEDIA:
		# uma sombra só: soma ponderada dos vetores de TODAS as luzes (peso = energia x atenuação). Ninguém "assume" de repente:
		# a direção gira junto com os pesos, e luzes opostas se anulam (sombra curta = mancha)
		var soma := Vector2.ZERO
		var soma_w := 0.0
		var vmax := 0.0
		for i in n:
			var v := _lv[i]
			if v < 0.02:
				continue
			soma += _vetor_sombra(pos, _lpos[i], _lh[i], alt, rmax) * v
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
		var ativas := []
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
				vec = _vetor_sombra(pos, _lpos[li], _lh[li], alt, rmax)
				alfa = 0.7 * fator * clampf(_lv[li] / LUZ_REF, 0.0, 1.0) * smoothstep(0.06, 0.25, vec.length())
			if li >= 0 and a.sa[s] < 0.01:
				a.sv[s] = vec  # slot que estava apagado nasce já no lugar certo (nada de deslizar de longe)
			_suaviza_slot(a, s, vec, alfa, k)
			_posicionar(a.sh1 if s == 0 else a.sh2, pos, a.sv[s], esc, a.sa[s])
		_blob(a, lerpf(1.0, 0.45, clampf(v1 / LUZ_REF, 0.0, 1.0)), lerpf(0.4, 0.85, clampf(v1 / LUZ_REF, 0.0, 1.0)))


# ------------------------------------------------------------------ cena


func _montar() -> void:
	var escuro := CanvasModulate.new()
	escuro.color = Color(str(_a.get("amb", "1c2a24")))
	add_child(escuro)
	_mundo = Node2D.new()
	_mundo.y_sort_enabled = true
	add_child(_mundo)
	_mat_sombra = _material_sombra()
	_blobs = Node2D.new()
	_blobs.z_index = -51
	_mundo.add_child(_blobs)
	_sombras = Node2D.new()
	_sombras.z_index = -50
	_mundo.add_child(_sombras)
	_chao()
	var heroi_tipo := "hazaki" if _a.has("basico") else "hazaki_samurai"
	var heroi: Dictionary
	if _a.has("grade"):
		heroi = _elenco_grade(heroi_tipo)
	else:
		_enfeites()
		heroi = _ator(heroi_tipo, HEROI_POS, 5, 0, false, true)
		for m in _lista_monstros():
			_ator(m.tipo, m.pos, m.linha, m.coluna, m.espelha, false)
		_primeiro_plano()
	_heroi = heroi
	_criar_sombras(_atores + _arvores)
	_trocar_sombra(_sombra)
	_olhos_raiz = Node2D.new()
	var camada_olhos := CanvasLayer.new()  # fora do CanvasModulate: o brilho dos olhos não escurece junto com o resto
	camada_olhos.layer = 2
	add_child(camada_olhos)
	camada_olhos.add_child(_olhos_raiz)
	for a in _atores:
		_criar_olho(a)
	_luzes_cena(heroi)
	if not _a.has("sem_vinheta"):
		_vinheta()
	if _modo == "livre" or _a.has("rotulo"):
		_montar_rotulo()


func _chao() -> void:
	var piso := Sprite2D.new()
	# piso SEM sombra assada (gerar_cenario_cara_nova.py); --piso_antigo usa o do jogo de hoje, com a sombra dos tufos presa a sudeste
	if _a.has("piso_antigo"):
		piso.texture = load("res://assets/cenarios/floresta/piso.png") as Texture2D
	else:
		piso.texture = ImageTexture.create_from_image(_imagem("floresta_piso.png"))
	var esc := _num("chao", 2.0)
	piso.region_enabled = true
	piso.region_rect = Rect2(0, 0, LARG / esc + 64, ALT / esc + 64)
	piso.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	piso.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	piso.centered = false
	piso.scale = Vector2(esc, esc)
	piso.position = Vector2(0, 0)
	piso.z_index = -100
	# o chão da Floresta é quase preto (o toon já escurecia): clareia antes da luz para a poça de luz aparecer
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float ganho = 2.2;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); COLOR = vec4(min(c.rgb * ganho * vec3(0.78, 1.0, 0.8), vec3(1.0)), c.a); }\n"
	m.shader = sh
	m.set_shader_parameter("ganho", _num("ganho_chao", 2.4))
	piso.material = m
	_mundo.add_child(piso)


func _item_cenario(nome: String) -> Dictionary:
	## enfeite do atlas albedo SEM sombra assada (gerar_cenario_cara_nova.py): textura nítida e borrada recortadas uma vez só
	if _itens_cen.is_empty():
		var info: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join(PASTA).path_join("floresta_enfeites.json"))
		)
		var atlas := _imagem("floresta_enfeites_albedo.png")
		for it in info.itens:
			var r := Rect2i(int(it.regiao[0]), int(it.regiao[1]), int(it.regiao[2]), int(it.regiao[3]))
			var rec := Image.create(r.size.x + 2 * MARGEM, r.size.y + 2 * MARGEM, false, Image.FORMAT_RGBA8)
			rec.blit_rect(atlas, r, Vector2i(MARGEM, MARGEM))
			_itens_cen[it.nome] = {
				"tn": ImageTexture.create_from_image(rec),
				"tb": _borrar_folha(rec, rec.get_width(), rec.get_height()),
				"w": r.size.x,
				"h": r.size.y,
				"pe": Vector2(float(it.pe[0]), float(it.pe[1])),
				"nome": it.nome,
			}
	return _itens_cen[nome]


func _sprite_cenario(it: Dictionary, pos: Vector2, esc: float, cor: Color, z: int, rmax: float, larg_blob: float) -> void:
	## o objeto (nítido, só o albedo) + o dono da sombra dinâmica dele
	var s := Sprite2D.new()
	s.texture = it.tn
	s.centered = false
	s.offset = Vector2(-it.pe.x - MARGEM, -it.pe.y - MARGEM)
	s.scale = Vector2(esc, esc)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	s.z_index = z
	s.modulate = cor
	_mundo.add_child(s)
	_arvores.append(
		{
			"raiz": s,
			"alt": it.h * esc,
			"esc": esc,
			"rmax": rmax,
			"offset": s.offset,
			"region": Rect2(),
			"espelha": false,
			"tex_n": it.tn,
			"tex_b": it.tb,
			"larg_blob": larg_blob * esc,
			"chave": it.nome
		}
	)


func _enfeites() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# arbustos, pedras, troncos e cogumelos espalhados pelo mundo de 960x540; cada um joga sombra dinâmica, como os bichos
	var chaves := ["arbusto", "pedra", "toco", "tronco", "cogumelos", "cranio"]
	for i in 22:
		var it := _item_cenario(chaves[rng.randi() % chaves.size()])
		var pos := Vector2(rng.randf_range(30, LARG - 30), rng.randf_range(70, ALT - 20))
		_sprite_cenario(it, pos, 1.0, Color(1.15, 1.15, 1.15), 0, 1.6, it.w * 0.6)


func _primeiro_plano() -> void:
	## árvores nas bordas (primeiro plano), grandes e escuras, cobrindo os cantos como na referência
	var pontos := [
		[Vector2(95, 120), 3.0, "arvore"],
		[Vector2(30, 520), 3.0, "arvore"],
		[Vector2(900, 100), 3.0, "arvore"],
		[Vector2(950, 530), 3.0, "arvore"],
		[Vector2(360, 40), 2.0, "arvore"],
		[Vector2(610, 34), 2.0, "arvore_morta"],
		[Vector2(430, 560), 2.0, "arvore_morta"],
	]
	var g := float(_a.get("arv", 1.5))
	for p in pontos:
		var it := _item_cenario(p[2])
		_sprite_cenario(it, p[0], p[1], Color(g * 0.8, g, g * 0.85), 50, 0.8, it.w * 0.4)


func _elenco_grade(heroi_tipo: String) -> Dictionary:
	## Teste da sombra (--grade=x,y põe a luz única nesse ponto): o herói, um cão espelhado, um lobo, e pedra, arbusto, toco e árvore.
	## Serve para a grade 3x3 de direções da luz e para conferir (em imagem) que a ponta da sombra fica do lado oposto ao da luz.
	var heroi := _ator(heroi_tipo, Vector2(380, 300), 5, 0, false, true)
	_ator("inimigo_cao_ossos", Vector2(470, 300), 1, 0, true, false)
	_ator("inimigo_lobo_sombrio", Vector2(560, 300), 1, 0, false, false)
	for x in [["pedra", Vector2(410, 370)], ["arbusto", Vector2(490, 370)], ["toco", Vector2(560, 370)], ["tronco", Vector2(640, 330)]]:
		_sprite_cenario(_item_cenario(x[0]), x[1], 1.0, Color(1.15, 1.15, 1.15), 0, 1.6, _item_cenario(x[0]).w * 0.6)
	_sprite_cenario(_item_cenario("arvore"), Vector2(300, 330), 1.4, Color(1.2, 1.2, 1.2), 0, 0.8, _item_cenario("arvore").w * 0.4)
	return heroi


func _lista_monstros() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := int(_a.get("sprites", 20)) if _modo == "medir" else int(_num("monstros", 25))
	var tipos := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_espantalho", "inimigo_lobo_sombrio", "inimigo_cavaleiro_oco"]
	var pesos := [4, 4, 3, 3, 1]
	var lista: Array = []
	for i in n:
		var tipo := _sorteia(rng, tipos, pesos)
		var pos := Vector2.ZERO
		if _modo == "medir" and n > 30:
			var cols := int(ceil(sqrt(n * float(LARG) / ALT)))
			var linhas := int(ceil(float(n) / cols))
			pos = Vector2((i % cols + 0.5) * LARG / cols, 50 + (i / cols + 0.5) * (ALT - 60) / linhas)
		else:
			var ang := rng.randf() * TAU
			var raio := rng.randf_range(70.0, 250.0)
			pos = HEROI_POS + Vector2(cos(ang) * raio * 1.45, sin(ang) * raio * 0.8)
			pos.x = clampf(pos.x, 40, LARG - 40)
			pos.y = clampf(pos.y, 80, ALT - 24)
		var dx := HEROI_POS.x - pos.x
		var dy := HEROI_POS.y - pos.y
		var linha := 0 if absf(dx) < absf(dy) * 0.5 else 1
		lista.append({"tipo": tipo, "pos": pos, "linha": linha, "coluna": rng.randi() % 4, "espelha": dx < 0.0})
	return lista


func _sorteia(rng: RandomNumberGenerator, itens: Array, pesos: Array) -> String:
	var total := 0
	for p in pesos:
		total += p
	var r := rng.randi() % total
	for i in itens.size():
		r -= pesos[i]
		if r < 0:
			return itens[i]
	return itens[0]


func _ator(nome: String, pos: Vector2, linha: int, coluna: int, espelha: bool, heroi: bool) -> Dictionary:
	var t := _tipo(nome)
	var raiz := Node2D.new()
	raiz.position = pos
	_mundo.add_child(raiz)
	var s := Sprite2D.new()
	s.texture = t.tex
	s.region_enabled = true
	s.region_rect = Rect2(coluna * t.w, linha * t.h, t.w, t.h)
	s.centered = false
	s.offset = Vector2(-t.w / 2.0, -t.pe)
	s.flip_h = espelha
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	raiz.add_child(s)
	var a := {
		"raiz": raiz,
		"sprite": s,
		"tipo": t,
		"linha": linha,
		"coluna": coluna,
		"espelha": espelha,
		"heroi": heroi,
		"olho": null,
		"alt": float(t.pe),
		"esc": 1.0,
		"rmax": 1.5,
		"offset": s.offset,
		"region": s.region_rect,
		"tex_n": t.alb,
		"tex_b": t.blur,
		"larg_blob": t.w * 0.75,
		"chave": nome
	}
	_atores.append(a)
	return a


func _criar_olho(a: Dictionary) -> void:
	var t: Dictionary = a.tipo
	if not _com_olhos or t.emissao == null:
		return
	var o := Sprite2D.new()
	o.texture = t.emissao
	o.region_enabled = true
	o.centered = false
	o.offset = Vector2(-t.w / 2.0, -t.pe)
	o.flip_h = a.espelha
	o.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	o.material = mat
	_olhos_raiz.add_child(o)
	a.olho = o
	_sync_olho(a)


func _sync_olho(a: Dictionary) -> void:
	var o: Sprite2D = a.olho
	if o == null:
		return
	var t: Dictionary = a.tipo
	o.position = a.raiz.position
	o.region_rect = Rect2(a.coluna * t.w, a.linha * t.h, t.w, t.h)


func _luz(cor: Color, energia: float, escala: float, altura: float, pos: Vector2, pai: Node = null) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _tex_luz
	l.color = cor
	l.energy = energia
	l.texture_scale = escala
	l.height = altura
	l.position = pos
	(pai if pai != null else self).add_child(l)
	return l


func _luzes_cena(heroi: Dictionary) -> void:
	var ht := _num("h_tocha", 45.0)
	var hm := _num("h_magia", 60.0)
	var hl := _num("h_lanterna", 60.0)
	var et := _num("e_tocha", 2.5)
	var em := _num("e_magia", 2.3)
	# ordem importa para a medição (1 = só a tocha, 3 = + lanterna + magia roxa, 6 = todas)
	var defs := [
		{"nome": "tocha", "cor": Color(1.0, 0.62, 0.26), "e": et, "r": 200.0, "h": ht, "pos": HEROI_POS + Vector2(-38, -32)},
		{"nome": "lanterna_a", "cor": Color(1.0, 0.72, 0.3), "e": 2.0, "r": 210.0, "h": hl, "pos": Vector2(230, 130)},
		{"nome": "magia_roxa", "cor": Color(0.78, 0.25, 1.0), "e": em, "r": 230.0, "h": hm, "pos": Vector2(735, 250)},
		{"nome": "magia_azul", "cor": Color(0.25, 0.65, 1.0), "e": em, "r": 170.0, "h": hm, "pos": Vector2(590, 380)},
		{"nome": "lanterna_b", "cor": Color(1.0, 0.7, 0.28), "e": 1.9, "r": 190.0, "h": hl, "pos": Vector2(170, 400)},
		{"nome": "aura_heroi", "cor": Color(0.45, 0.72, 1.0), "e": 1.2, "r": 110.0, "h": hm, "pos": HEROI_POS + Vector2(30, -8)},
	]
	var n := int(_a.get("luzes", 6))
	if _a.has("grade"):
		var xy := str(_a.grade).split(",")
		defs[0].pos = Vector2(float(xy[0]), float(xy[1]))
		defs[0].e = 3.0
		defs[0].r = 700.0
		n = 1
	for i in mini(n, defs.size()):
		var d: Dictionary = defs[i]
		var l := _luz(d.cor, d.e, d.r / 128.0, d.h, d.pos)
		# o corpo da luz (lanterna, orbe da magia) brilha sozinho: sprite aditivo na camada sem CanvasModulate
		var orbe := Sprite2D.new()
		orbe.texture = _tex_luz
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		orbe.material = mat
		var tam := 0.1 if str(d.nome).begins_with("magia") else 0.07
		orbe.scale = Vector2(tam, tam)
		orbe.modulate = d.cor.lerp(Color.WHITE, 0.4)
		orbe.position = d.pos
		if d.nome != "tocha" and d.nome != "aura_heroi":
			_olhos_raiz.add_child(orbe)
		else:
			orbe.queue_free()
			orbe = null
		_luzes.append({"luz": l, "def": d, "orbe": orbe})


func _vinheta() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 3
	add_child(camada)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.78)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.85)
	t.width = 192
	t.height = 108
	var r := TextureRect.new()
	r.texture = t
	r.size = Vector2(LARG, ALT)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(r)


# ------------------------------------------------------------------ laço


func _montar_rotulo() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 4
	add_child(camada)
	_rotulo = Label.new()
	_rotulo.position = Vector2(6, 4)
	_rotulo.add_theme_font_size_override("font_size", 12)
	_rotulo.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_rotulo.add_theme_constant_override("outline_size", 4)
	camada.add_child(_rotulo)
	_texto_rotulo()


func _texto_rotulo() -> void:
	if _rotulo == null:
		return
	var l1 := "sombra: %s   %d fps   %d sprites" % [str(NOMES_SOMBRA[_sombra]).to_upper(), Engine.get_frames_per_second(), _atores.size()]
	if _modo == "livre":
		var l2 := (
			"\n1 baixa  2 media  3 alta  0 sem sombra   WASD anda   L luz azul no mouse%s   T tocha junto%s"
			% [" (ligado)" if _azul_mouse else "", " (ligado)" if _tocha_leva else ""]
		)
		l1 += l2
	_rotulo.text = l1


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_0, KEY_KP_0:
			_trocar_sombra(NENHUMA)
		KEY_1, KEY_KP_1:
			_trocar_sombra(BAIXA)
		KEY_2, KEY_KP_2:
			_trocar_sombra(MEDIA)
		KEY_3, KEY_KP_3:
			_trocar_sombra(ALTA)
		KEY_L:
			_azul_mouse = not _azul_mouse
		KEY_T:
			_tocha_leva = not _tocha_leva
	_texto_rotulo()


func _quadro(a: Dictionary, c: int) -> void:
	## põe o quadro c (e o espelhamento) no corpo, nos olhos e nas duas sombras: a sombra segue a animação
	var t: Dictionary = a.tipo
	a.coluna = c
	var r := Rect2(c * t.w, a.linha * t.h, t.w, t.h)
	a.sprite.region_rect = r
	a.sh1.region_rect = r
	a.sh2.region_rect = r
	_sync_olho(a)


func _linha_heroi(v: Vector2) -> int:
	## linhas da folha do herói: baixo, esquerda, direita, cima, baixo_esq, baixo_dir, cima_esq, cima_dir
	if v.x == 0.0:
		return 0 if v.y > 0.0 else 3
	if v.y == 0.0:
		return 1 if v.x < 0.0 else 2
	if v.y > 0.0:
		return 4 if v.x < 0.0 else 5
	return 6 if v.x < 0.0 else 7


func _heroi_livre(delta: float, passo: int) -> void:
	var v := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	var h := _heroi
	var t: Dictionary = h.tipo
	_heroi_anda = v != Vector2.ZERO
	if _heroi_anda:
		h.raiz.position += v.normalized() * 95.0 * delta
		h.raiz.position = h.raiz.position.clamp(Vector2(18, 70), Vector2(LARG - 18, ALT - 6))
		h.linha = _linha_heroi(v)
	var cols := int(t.info.colunas.size())
	_quadro(h, 1 + passo % (cols - 1) if _heroi_anda else 0)


func _process(delta: float) -> void:
	_t += delta
	var passo := int(_t / 0.16)
	var troca := passo != _passo
	_passo = passo
	if troca:
		for a in _atores:
			if a.heroi:
				continue
			var cols := int(a.tipo.info.colunas.size())
			_quadro(a, (passo + int(a.raiz.position.x)) % cols)
	if _modo == "livre":
		_heroi_livre(delta, passo)
	elif troca:
		var h := _heroi
		_quadro(h, 1 + passo % (int(h.tipo.info.colunas.size()) - 1))
	for l in _luzes:
		var d: Dictionary = l.def
		var luz: PointLight2D = l.luz
		if d.nome == "tocha":
			luz.energy = d.e + (0.0 if _a.has("grade") else 0.12 * sin(_t * 13.0) + 0.07 * sin(_t * 29.0 + 1.3))
		if _tocha_leva and (d.nome == "tocha" or d.nome == "aura_heroi"):
			luz.position = _heroi.raiz.position + (d.pos - HEROI_POS)
		elif d.nome == "magia_azul":
			if _azul_mouse:
				luz.position = get_global_mouse_position().clamp(Vector2.ZERO, Vector2(LARG, ALT))
			elif _a.has("azul"):
				var xy := str(_a.azul).split(",")
				luz.position = Vector2(float(xy[0]), float(xy[1]))
			else:
				luz.position = d.pos + Vector2(cos(_t * 0.9) * 60.0, sin(_t * 0.9) * 30.0)
			if l.orbe != null:
				l.orbe.position = luz.position
	var t_sombra := Time.get_ticks_usec()
	if _sombra >= MEDIA:
		_atualizar_luzes_dados()
		_quadros += 1
		var n_atores := _atores.size()
		for i in n_atores:
			# médio e alto: metade dos atores por quadro (a sombra anda a 30 Hz, imperceptível e metade do custo); o herói sempre
			if (i + _quadros) % 2 == 1 and not _atores[i].heroi:
				continue
			_atualizar_sombra(_atores[i])
		for a in _arvores:
			_atualizar_sombra(a)
	_us_sombra += Time.get_ticks_usec() - t_sombra
	if _rotulo != null:
		_rotulo_t += delta
		if _rotulo_t > 0.3:
			_rotulo_t = 0.0
			_texto_rotulo()
	if _modo == "medir":
		_medir()
	elif _modo == "foto" and _proximo < _seq.size() and _t >= float(_seq[_proximo]):
		_proximo += 1
		_salvar_tela(_proximo)


func _medir() -> void:
	if _t < _medicao["aquecer"]:
		return
	if _medicao["inicio"] < 0.0:
		_medicao["inicio"] = _t
		return
	_medicao["frames"] = int(_medicao["frames"]) + 1
	var dec: float = _t - float(_medicao["inicio"])
	if dec >= float(_medicao["duracao"]):
		var frames: int = int(_medicao["frames"])
		print(
			(
				"MEDIDA sombra=%s luzes=%d sprites=%d normal=%d fps=%.1f frames=%d seg=%.2f"
				% [NOMES_SOMBRA[_sombra], _luzes.size(), _atores.size(), 1 if _com_normal else 0, frames / dec, frames, dec]
			)
		)
		print("SCRIPT_SOMBRA ms/quadro=%.3f blur_carga_ms=%.0f" % [_us_sombra / 1000.0 / float(Engine.get_process_frames()), _ms_blur])
		get_tree().quit()


func _salvar_tela(n: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var caminho := _fotos.path_join("%s_%d.png" % [str(_a.get("nome", "cara_nova")), n])
	img.save_png(caminho)
	print("FOTO ", caminho, " ", img.get_size(), " t=%.2f" % _t)
	if n >= _seq.size():
		get_tree().quit()
