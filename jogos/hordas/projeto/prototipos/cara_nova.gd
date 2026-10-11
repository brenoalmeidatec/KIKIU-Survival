extends Node2D
## Protótipo da cara nova (V1 + V2), cena de teste FORA do jogo: mundo de 960x540, chão e árvores da Floresta, luz escura
## com PointLight2D e sprites com ALBEDO + NORMAL (CanvasTexture). Os sprites vêm de projeto/prototipos/cara_nova/sprites/
## (gerados por gerar_cara_nova.py). Tudo é lido por res:// (PNG por load() do recurso importado, JSON por FileAccess com
## entrada no include_filter do export_presets.cfg): no exe exportado não há pasta de disco ao lado, só o pck.
##
## Uso (a partir de jogos/hordas):
##   godot --path projeto res://prototipos/cara_nova.tscn -- --fotos=PASTA --seq=1.0,2.0
##   godot --path projeto res://prototipos/cara_nova.tscn -- --medir --luzes=3 --sprites=250 --duracao=6
## Opções de arte (para iterar): --amb=1c2a24 --h_tocha=18 --e_tocha=1.9 --h_magia=24 --sem_normal --sem_vinheta --sem_olhos
##   --chao=1 (escala do chão) --nomes (rótulos) --samurai (herói de armadura vermelha)
## Sombras (silhueta do sprite projetada no chão, longe da luz): --sombra=baixa|media|alta|nenhuma (padrão media).
## Sem --fotos e sem --medir a cena fica aberta (modo livre): teclas 1/2/3 (0 desliga) trocam o modo, WASD anda com o herói,
## L faz a luz azul seguir o mouse (--azul=x,y fixa a luz azul num ponto), T leva a tocha e a aura junto com o herói. --sem_vsync solta o fps; --rotulo mostra o rótulo nas fotos.

const PASTA := "res://prototipos/cara_nova/sprites"
const LARG := 960
const ALT := 540
const HEROI_POS := Vector2(470, 292)
const NENHUMA := 0
const BAIXA := 1
const MEDIA := 2
const ALTA := 3
const NOMES_SOMBRA := ["nenhuma", "baixa", "media", "alta"]
const ACHATA := 0.7071  # câmera a 45 graus: o eixo y do chão aparece comprimido por sen(45)
const DEC_DIR := "prototipos/decalques"  # decalques de chão (círculo, trilha, raízes, folhas, musgo...)
const OBJ_DIR := "prototipos/objetos"  # arte nova do cenário (imagegen): albedo + normal, escala final a 960x540
const POS_POSTE := Vector2(250, 160)  # poste com lanterna (fonte de luz quente fraca)
const POS_TORO := Vector2(780, 215)  # lanterna de pedra (fonte de luz quente fraca)
const POS_ALTAR := Vector2(130, 445)  # altar com vela (luz) e o crânio ao lado
const CIRCULO_POS := Vector2(480, 314)  # centro do círculo ritual (decalque) e da ruína
const POS_TORII := Vector2(240, 332)  # torii na borda oeste do círculo, com a trilha passando por baixo
const POS_BRASEIRO := Vector2(322, 380)  # braseiro com fogo de verdade, do lado do torii
const POS_FOGUEIRA := Vector2(858, 470)  # fogueira acesa no canto oposto, menor
const POS_CAIXA := Vector2(86, 492)  # caixa de oferenda perto do altar
const GRAD_OFF := [0.0, 0.22, 0.55, 1.0]  # queda das luzes: forte no centro e escura de verdade longe (poças contrastadas)
const GRAD_VAL := [1.0, 0.5, 0.1, 0.0]
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
var _decal_itens := {}
var _chao_deco: Node2D
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
var _raiz: Node  # onde vai o mundo: o SubViewport de 960x540 (padrão) ou o próprio nó
var _sv: SubViewport
var _tela: TextureRect
var _particulas: Array = []  # {"p": CPUParticles2D, "base": amount}: o perfil baixo corta pela metade
var _tex_brilho: GradientTexture2D


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
	if _a.has("janela"):
		var wh := str(_a.janela).split("x")
		janela.size = Vector2i(int(wh[0]), int(wh[1]))
	elif _modo == "livre":
		# janela livre: a maior 16:9 que cabe na tela (o sharp bilinear cuida da escala fracionária, sem barras)
		var util := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var k := minf(util.size.x / float(LARG), (util.size.y - 70) / float(ALT))
		janela.size = Vector2i(int(LARG * k), int(ALT * k))
		janela.move_to_center()
	else:
		janela.size = Vector2i(1280, 720)
	_preparar_tela(janela)
	if _modo == "medir" or _a.has("sem_vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	RenderingServer.set_default_clear_color(Color(0.02, 0.03, 0.03))
	_tex_luz = _textura_luz()
	_tex_sombra = _textura_sombra()
	_tex_brilho = _textura_brilho()
	_montar()


func _preparar_tela(janela: Window) -> void:
	## Apresentação. O mundo é desenhado num SubViewport de 960x540 (filtro nearest) e mostrado numa TextureRect do tamanho da janela com
	## o shader "sharp bilinear": escala inteira em nearest + só 1 px de tela de transição nas bordas dos texels, então com escala
	## fracionária (1,33x, 1,6x, 1,87x...) todos os pixels têm o mesmo tamanho aparente e não há barras. Em escala exata (2x, 3x) é idêntico ao
	## nearest puro. --escala_pura mostra o nearest fracionário (a apresentação anterior: pixels de 1 e de 2 px); --sem_subviewport volta
	## ao content_scale_mode viewport antigo.
	if _a.has("sem_subviewport"):
		janela.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		janela.content_scale_size = Vector2i(LARG, ALT)
		_raiz = self
		return
	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_sv = SubViewport.new()
	_sv.size = Vector2i(LARG, ALT)
	_sv.disable_3d = true
	_sv.transparent_bg = false
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_sv)
	_raiz = _sv
	var camada := CanvasLayer.new()
	add_child(camada)
	_tela = TextureRect.new()
	_tela.texture = _sv.get_texture()
	_tela.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tela.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _a.has("escala_pura"):
		_tela.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		_tela.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var sh := Shader.new()
		sh.code = (
			"shader_type canvas_item;\nuniform vec2 tam = vec2(960.0, 540.0);\nuniform float escala = 1.0;\n"
			+ "void fragment(){ vec2 texel = UV * tam; vec2 piso = floor(texel); vec2 d = fract(texel) - 0.5;"
			+ " vec2 r = 0.5 - 0.5 / max(vec2(escala), vec2(1.0)); vec2 f = (d - clamp(d, -r, r)) * escala + 0.5;"
			+ " COLOR = vec4(texture(TEXTURE, (piso + f) / tam).rgb, 1.0); }\n"
		)
		var m := ShaderMaterial.new()
		m.shader = sh
		_tela.material = m
	camada.add_child(_tela)
	_tela.resized.connect(_ajusta_escala)
	_ajusta_escala.call_deferred()


func _ajusta_escala() -> void:
	if _tela == null or _tela.material == null:
		return
	var m := _tela.material as ShaderMaterial
	m.set_shader_parameter("escala", maxf(_tela.size.x / LARG, _tela.size.y / ALT))


func _mouse_mundo() -> Vector2:
	## posição do mouse nas coordenadas do mundo (960x540), desfazendo a escala e o corte da TextureRect
	if _sv == null:
		return get_global_mouse_position()
	var r: Vector2 = get_viewport().get_visible_rect().size
	var k := maxf(r.x / LARG, r.y / ALT)
	return ((get_viewport().get_mouse_position() - r / 2.0) / k + Vector2(LARG, ALT) / 2.0).clamp(Vector2.ZERO, Vector2(LARG, ALT))


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
		var caminho := PASTA.path_join(nome)
		var im := _png(caminho)
		if im == null:
			push_error("sem imagem: " + caminho)
		_imgs[nome] = im
	return _imgs[nome]


## PNG por load(): no exe exportado o PNG de origem não vai para o pck (vira .ctex importado), então Image.load_from_file e
## FileAccess não o acham. load() acha o recurso importado; get_image() devolve a imagem para os cálculos (normal, blur, atlas).
func _png(caminho: String) -> Image:
	var tex := load(caminho) as Texture2D
	return tex.get_image() if tex != null else null


func _tem(nome: String) -> bool:
	return ResourceLoader.exists(PASTA.path_join(nome))


func _tipo(nome: String) -> Dictionary:
	if _tipos.has(nome):
		return _tipos[nome]
	var caminho := PASTA.path_join(nome + ".json")
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
	g.offsets = PackedFloat32Array(GRAD_OFF)
	var cores := PackedColorArray()
	for v in GRAD_VAL:
		cores.append(Color(v, v, v, 1))
	g.colors = cores
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


func _textura_brilho() -> GradientTexture2D:
	## brilho com queda suave (núcleo claro, halo que some): o corpo das magias e das chamas, no lugar do disco chapado
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.3, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.05), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
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
	for q in _particulas:
		q.p.amount = maxi(2, int(q.base / 2.0)) if m == BAIXA else q.base
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
	## mesma curva do gradiente da textura das PointLight2D (GRAD_OFF / GRAD_VAL)
	var u := d / r
	if u >= 1.0:
		return 0.0
	for i in range(1, GRAD_OFF.size()):
		if u < GRAD_OFF[i]:
			return lerpf(GRAD_VAL[i - 1], GRAD_VAL[i], (u - GRAD_OFF[i - 1]) / (GRAD_OFF[i] - GRAD_OFF[i - 1]))
	return 0.0


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
	escuro.color = Color(str(_a.get("amb", "172a30")))  # verde-azulado quase preto da arte de entrada
	_raiz.add_child(escuro)
	_mundo = Node2D.new()
	_mundo.y_sort_enabled = true
	_raiz.add_child(_mundo)
	_mat_sombra = _material_sombra()
	_blobs = Node2D.new()
	_blobs.z_index = -51
	_mundo.add_child(_blobs)
	_sombras = Node2D.new()
	_sombras.z_index = -50
	_mundo.add_child(_sombras)
	_chao()
	_chao_deco = Node2D.new()  # decalques: acima do piso (-100), abaixo das sombras (-51 e -50)
	_chao_deco.z_index = -90
	_mundo.add_child(_chao_deco)
	var heroi_tipo := "hazaki" if _a.has("basico") else "hazaki_samurai"
	var heroi: Dictionary
	if _a.has("grade"):
		heroi = _elenco_grade(heroi_tipo)
	else:
		if _a.has("cenario_antigo"):
			_cenario_antigo()
		else:
			_cenario_novo()
		heroi = _ator(heroi_tipo, HEROI_POS, 5, 0, false, true)
		for m in _lista_monstros():
			_ator(m.tipo, m.pos, m.linha, m.coluna, m.espelha, false)
	_heroi = heroi
	_criar_sombras(_atores + _arvores)
	_trocar_sombra(_sombra)
	_olhos_raiz = Node2D.new()
	var camada_olhos := CanvasLayer.new()  # fora do CanvasModulate: o brilho dos olhos não escurece junto com o resto
	camada_olhos.layer = 2
	_raiz.add_child(camada_olhos)
	camada_olhos.add_child(_olhos_raiz)
	for a in _atores:
		_criar_olho(a)
	_luzes_cena(heroi)
	if not _a.has("sem_atmosfera"):
		_atmosfera()
	if not _a.has("sem_luar"):
		_luar()
	_trocar_sombra(_sombra)
	if not _a.has("sem_vinheta"):
		_vinheta()
	if _modo == "livre" or _a.has("rotulo"):
		_montar_rotulo()


func _chao() -> void:
	var piso := Sprite2D.new()
	var raiz := "res://"
	var esc := _num("chao", 2.0)
	var qual_piso := str(_a.get("piso", "piso_ia" if _a.has("piso_ia") else "piso"))
	var novo := raiz.path_join("prototipos/piso/%s.png" % qual_piso)
	if not _a.has("piso_antigo") and not _a.has("cenario_antigo") and ResourceLoader.exists(novo):
		# chão novo (prototipos/piso, aprovado): escala 1 (1 texel = 1 px), com piso_normal.png como normal map
		var ct := CanvasTexture.new()
		ct.diffuse_texture = ImageTexture.create_from_image(_png(novo))
		var nn := raiz.path_join("prototipos/piso/%s_normal.png" % qual_piso)
		if _com_normal and ResourceLoader.exists(nn):
			ct.normal_texture = ImageTexture.create_from_image(_png(nn))
		piso.texture = ct
		esc = 1.0
		# sob a luz laranja o musgo ia a amarelo saturado: tira um pouco do verde e dessatura o chão antes da luz
		var m := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = (
			"shader_type canvas_item;\nuniform float verde = 0.8;\nuniform float dessat = 0.3;\nuniform float ganho = 1.0;\n"
			+ "void fragment(){ vec4 c = texture(TEXTURE, UV); float l = dot(c.rgb, vec3(0.3, 0.5, 0.2));"
			+ " vec3 b = mix(c.rgb, vec3(l) * vec3(1.05, 0.95, 0.9), dessat); b.g *= verde;"
			+ " COLOR = vec4(min(b * ganho, vec3(1.0)), c.a); }\n"
		)
		m.shader = sh
		m.set_shader_parameter("verde", _num("verde_chao", 0.8))
		m.set_shader_parameter("dessat", _num("dessat_chao", 0.3))
		m.set_shader_parameter("ganho", _num("ganho_chao", 3.6))
		piso.material = m
	else:
		# chão anterior: o regerado sem sombra assada (gerar_cenario_cara_nova.py) ou, com --piso_antigo, o do jogo de hoje (sombra dos
		# tufos presa a sudeste). Clareia antes da luz e achata as manchas claras (viravam discos chapados sob a luz colorida das magias).
		var im: Image
		if _a.has("piso_antigo"):
			im = (load("res://assets/cenarios/floresta/piso.png") as Texture2D).get_image()
		else:
			im = _imagem("floresta_piso.png")
		piso.texture = ImageTexture.create_from_image(im)
		var med := im.duplicate() as Image
		med.resize(1, 1, Image.INTERPOLATE_LANCZOS)
		var c := med.get_pixel(0, 0)
		var m := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = (
			"shader_type canvas_item;\nuniform float ganho = 2.2;\nuniform float achata = 0.0;\nuniform vec3 media = vec3(0.3);\n"
			+ "void fragment(){ vec4 c = texture(TEXTURE, UV); vec3 b = mix(c.rgb, media, achata);"
			+ " COLOR = vec4(min(b * ganho * vec3(0.78, 1.0, 0.8), vec3(1.0)), c.a); }\n"
		)
		m.shader = sh
		m.set_shader_parameter("ganho", _num("ganho_chao", 2.4))
		m.set_shader_parameter("achata", _num("achata_chao", 0.6))
		m.set_shader_parameter("media", Vector3(c.r, c.g, c.b))
		piso.material = m
	piso.region_enabled = true
	piso.region_rect = Rect2(0, 0, LARG / esc + 64, ALT / esc + 64)
	piso.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	piso.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	piso.centered = false
	piso.scale = Vector2(esc, esc)
	piso.position = Vector2(0, 0)
	piso.z_index = -100
	_mundo.add_child(piso)


func _carregar_itens() -> void:
	## Atlas de objetos de cenário. Padrão: arte nova do imagegen (prototipos/objetos: albedo + normal, escala final). --cenario_antigo:
	## os enfeites regerados em Blender (sprites/floresta_enfeites_*), só albedo. Cada item é recortado UMA vez (com margem) e ganha a
	## textura nítida, a borrada para a sombra do modo médio e, quando há, a CanvasTexture com normal map.
	var raiz := "res://"
	var antigo := _a.has("cenario_antigo")
	var info: Dictionary
	var atlas: Image
	var norm: Image = null
	if antigo:
		info = JSON.parse_string(FileAccess.get_file_as_string(PASTA.path_join("floresta_enfeites.json")))
		atlas = _imagem("floresta_enfeites_albedo.png")
	else:
		info = JSON.parse_string(FileAccess.get_file_as_string(raiz.path_join(OBJ_DIR).path_join("cenario.json")))
		atlas = _png(raiz.path_join(OBJ_DIR).path_join("enfeites.png"))
		if _com_normal:
			norm = _png(raiz.path_join(OBJ_DIR).path_join("enfeites_normal.png"))
			norm.convert(Image.FORMAT_RGBA8)
	atlas.convert(Image.FORMAT_RGBA8)
	for it in info.itens:
		var r := Rect2i(int(it.regiao[0]), int(it.regiao[1]), int(it.regiao[2]), int(it.regiao[3]))
		var rec := Image.create(r.size.x + 2 * MARGEM, r.size.y + 2 * MARGEM, false, Image.FORMAT_RGBA8)
		rec.blit_rect(atlas, r, Vector2i(MARGEM, MARGEM))
		var tn := ImageTexture.create_from_image(rec)
		var desenho: Texture2D = tn
		if norm != null:
			var rn := Image.create(rec.get_width(), rec.get_height(), false, Image.FORMAT_RGBA8)
			rn.fill(Color(0.5, 0.5, 1.0, 0.0))
			rn.blit_rect(norm, r, Vector2i(MARGEM, MARGEM))
			var ct := CanvasTexture.new()
			ct.diffuse_texture = tn
			ct.normal_texture = ImageTexture.create_from_image(rn)
			desenho = ct
		_itens_cen[it.nome] = {
			"tn": tn,
			"tb": _borrar_folha(rec, rec.get_width(), rec.get_height()),
			"desenho": desenho,
			"w": r.size.x,
			"h": r.size.y,
			"pe": Vector2(float(it.pe[0]), float(it.pe[1])),
			"nome": it.nome,
			"fogo": Vector2(float(it.fogo[0]), float(it.fogo[1])) if it.has("fogo") else Vector2.ZERO,
		}


func _item_cenario(nome: String) -> Dictionary:
	if _itens_cen.is_empty():
		_carregar_itens()
	return _itens_cen[nome]


func _objeto(nome: String, pos: Vector2, esc := 1.0, cor := Color(-1, 0, 0), z := 0) -> void:
	## um objeto de cenário (escala 1 = escala final do jogo) + o dono da sombra dinâmica dele. Quanto mais alto o objeto, menor o
	## comprimento máximo da sombra (a árvore de 150 px não deita 200 px de sombra no chão).
	var it := _item_cenario(nome)
	var s := Sprite2D.new()
	s.texture = it.desenho
	s.centered = false
	s.offset = Vector2(-it.pe.x - MARGEM, -it.pe.y - MARGEM)
	s.scale = Vector2(esc, esc)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	s.z_index = z
	var g := _num("obj", 1.7)  # a arte nova é bem escura: levanta antes da luz (o ambiente escuro faz o resto)
	s.modulate = Color(g, g, g) if cor.r < 0.0 else cor
	_mundo.add_child(s)
	var h := float(it.h) * esc
	var rmax := 0.5 if h > 100.0 else (0.9 if h > 50.0 else 1.6)
	var largura := float(it.w) * esc * (0.35 if h > 100.0 else 0.6)
	_arvores.append(
		{
			"raiz": s,
			"alt": h,
			"esc": esc,
			"rmax": rmax,
			"offset": s.offset,
			"region": Rect2(),
			"espelha": false,
			"tex_n": it.tn,
			"tex_b": it.tb,
			"larg_blob": largura,
			"chave": it.nome
		}
	)


func _cenario_novo() -> void:
	## Composição parecida com a arte de entrada: círculo de ruína perto do centro (colunas, pilar, obelisco, lápides, muros), árvores
	## grandes enquadrando as bordas, vegetação agrupada em volta, altar e crânio num canto, lanternas à direita e no fundo.
	_decalques_cena()
	# árvores nas bordas (enquadram a cena; a y-sort deixa as de baixo na frente de quem passa)
	for p in [
		["arvore", Vector2(82, 190)],
		["arvore", Vector2(884, 178)],
		["arvore", Vector2(470, 78)],
		["arvore_pantano", Vector2(62, 536)],
		["arvore_pantano", Vector2(906, 538)],
		["arvore_morta", Vector2(330, 92)],
		["arvore_morta", Vector2(655, 98)],
		["arvore_morta", Vector2(24, 352)],
		["arvore_morta", Vector2(940, 360)]
	]:
		_objeto(p[0], p[1])
	# círculo de ruína em volta do herói
	for p in [
		["obelisco", Vector2(482, 212)],
		["coluna", Vector2(392, 226)],
		["pilar", Vector2(578, 232)],
		["lapide", Vector2(334, 252)],
		["lapide", Vector2(630, 258)],
		["muro", Vector2(318, 268)],
		["muro", Vector2(704, 296)],
		["runa", Vector2(447, 236)],
		["coluna", Vector2(352, 352)],
		["pedestal", Vector2(610, 384)],
		["lapide", Vector2(652, 338)],
		["coluna", Vector2(628, 352)],
		["pilar", Vector2(412, 402)],
		["coluna", Vector2(540, 408)],
		["lapide", Vector2(480, 418)]
	]:
		_objeto(p[0], p[1])
	# lanternas (também são fontes de luz) e o altar com o crânio no canto
	_objeto("poste_lanterna", POS_POSTE)
	_objeto("toro", POS_TORO)
	_objeto("altar", POS_ALTAR)
	_objeto("caixa_oferenda", POS_CAIXA)
	_objeto("torii", POS_TORII)
	_objeto("braseiro", POS_BRASEIRO)
	_objeto("fogueira", POS_FOGUEIRA)
	_objeto("torii_quebrado", Vector2(860, 300))
	_objeto("cranio", POS_ALTAR + Vector2(58, 18))
	# vegetação e pedras agrupadas em volta
	for p in [
		["arbusto", Vector2(142, 214)],
		["arbusto", Vector2(160, 524)],
		["arbusto", Vector2(826, 206)],
		["arbusto", Vector2(852, 520)],
		["arbusto", Vector2(372, 118)],
		["arbusto", Vector2(618, 128)],
		["arbusto", Vector2(206, 292)],
		["arbusto", Vector2(752, 468)],
		["juncos", Vector2(190, 262)],
		["juncos", Vector2(206, 276)],
		["juncos", Vector2(742, 432)],
		["juncos", Vector2(764, 446)],
		["juncos", Vector2(790, 330)],
		["raizes", Vector2(58, 206)],
		["raizes", Vector2(924, 206)],
		["raizes", Vector2(118, 498)],
		["raizes", Vector2(884, 504)],
		["cogumelos", Vector2(170, 312)],
		["cogumelos", Vector2(808, 300)],
		["cogumelos", Vector2(560, 486)],
		["cogumelos", Vector2(304, 456)],
		["toco", Vector2(222, 424)],
		["tronco", Vector2(262, 446)],
		["pedra", Vector2(120, 336)],
		["rocha", Vector2(862, 410)],
		["pedras", Vector2(566, 156)],
		["pedras", Vector2(404, 468)],
		["pedra", Vector2(700, 476)],
		["rocha", Vector2(268, 206)],
		["pedras", Vector2(770, 190)],
		["toco", Vector2(700, 150)],
		["tronco", Vector2(380, 520)]
	]:
		_objeto(p[0], p[1])


func _carregar_decalques() -> void:
	## Decalques de chão (prototipos/decalques: albedo + normal + json com regiao e centro de cada item). Cada um vira uma CanvasTexture.
	var dir := "res://".path_join(DEC_DIR)
	if not FileAccess.file_exists(dir.path_join("decalques.json")):
		return
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("decalques.json")))
	var atlas := _png(dir.path_join("decalques.png"))
	atlas.convert(Image.FORMAT_RGBA8)
	var norm: Image = null
	if _com_normal and ResourceLoader.exists(dir.path_join("decalques_normal.png")):
		norm = _png(dir.path_join("decalques_normal.png"))
		norm.convert(Image.FORMAT_RGBA8)
	for it in info.itens:
		var r := Rect2i(int(it.regiao[0]), int(it.regiao[1]), int(it.regiao[2]), int(it.regiao[3]))
		var ct := CanvasTexture.new()
		ct.diffuse_texture = ImageTexture.create_from_image(atlas.get_region(r))
		if norm != null:
			ct.normal_texture = ImageTexture.create_from_image(norm.get_region(r))
		_decal_itens[it.nome] = {"tex": ct, "w": r.size.x, "h": r.size.y, "centro": Vector2(float(it.centro[0]), float(it.centro[1]))}


func _decalque(nome: String, pos: Vector2, cor := Color.WHITE) -> Sprite2D:
	## um decalque no chão, com o centro do item em pos. Fica na camada de chão (acima do piso, abaixo das sombras) e recebe luz com normal.
	if not _decal_itens.has(nome):
		return null
	var it: Dictionary = _decal_itens[nome]
	var s := Sprite2D.new()
	s.texture = it.tex
	s.centered = false
	s.offset = -it.centro
	s.position = pos
	s.modulate = cor
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chao_deco.add_child(s)
	return s


func _grupo(nomes: Array, centro: Vector2, n: int, raio: Vector2, rng: RandomNumberGenerator, cor := Color.WHITE) -> void:
	## n decalques sorteados de nomes, espalhados numa elipse em volta de centro (manchas naturais)
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf())
		var p := centro + Vector2(cos(a) * raio.x * d, sin(a) * raio.y * d)
		_decalque(nomes[rng.randi() % nomes.size()], p, cor)


func _decalques_cena() -> void:
	## Decalques de chão: círculo ritual sob o círculo de ruína, trilha de lajes (reta, diagonal e curva) saindo dele, raízes na base das
	## árvores grandes, poças perto dos juncos e grupos naturais de folhas, musgo, pedrinhas, galhos e grama. Tudo na camada de chão.
	if _decal_itens.is_empty():
		_carregar_decalques()
	if _decal_itens.is_empty():
		return
	var g := _num("dec", 1.4)  # a arte é escura: levanta antes da luz
	var cor := Color(g, g, g)
	_decalque("circulo", CIRCULO_POS, cor)
	# trilha oeste: sai do círculo, passa por baixo do torii e vai até a borda; trilha sudoeste em diagonal; trilha leste curva
	for p in [
		["trilha_reta", Vector2(205, 338)], ["trilha_reta", Vector2(40, 342)], ["trilha_diagonal", Vector2(392, 478)], ["trilha_curva", Vector2(742, 392)]
	]:
		_decalque(p[0], p[1], cor)
	# raízes na base das árvores grandes
	for p in [
		["raiz_no", Vector2(82, 194)],
		["raiz_estrela", Vector2(884, 184)],
		["raiz_forquilha", Vector2(470, 86)],
		["raiz_longa", Vector2(78, 528)],
		["raiz_no", Vector2(902, 530)],
		["raiz_forquilha", Vector2(330, 98)],
		["raiz_longa", Vector2(655, 104)],
		["raiz_estrela", Vector2(32, 360)],
		["raiz_forquilha", Vector2(940, 366)]
	]:
		_decalque(p[0], p[1], cor)
	# poças perto dos juncos
	for p in [Vector2(176, 282), Vector2(758, 458), Vector2(804, 344)]:
		_decalque("poca", p, cor)
	# grupos naturais (sorteio fixo): folhas, musgo, pedrinhas, galhos e grama em manchas
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for c in [
		Vector2(150, 250),
		Vector2(230, 420),
		Vector2(360, 140),
		Vector2(620, 150),
		Vector2(790, 240),
		Vector2(840, 420),
		Vector2(700, 480),
		Vector2(420, 500),
		Vector2(110, 420),
		Vector2(560, 490),
		Vector2(300, 470),
		Vector2(760, 130),
		Vector2(180, 130),
		Vector2(520, 130)
	]:
		_grupo(["folhas_1", "folhas_2", "folhas_3"], c, 3, Vector2(46, 22), rng, cor)
		_grupo(["musgo_1", "musgo_2", "musgo_3"], c + Vector2(rng.randf_range(-30, 30), rng.randf_range(-14, 14)), 2, Vector2(50, 24), rng, cor)
		_grupo(["pedrinhas_1", "pedrinhas_2", "grama"], c, 3, Vector2(54, 26), rng, cor)
		_grupo(["galho_1", "galho_2"], c, 1, Vector2(60, 24), rng, cor)


func _cenario_antigo() -> void:
	## --cenario_antigo: os enfeites regerados (sprites/floresta_enfeites_*) como estavam antes: 22 sorteados + 7 árvores ampliadas
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var chaves := ["arbusto", "pedra", "toco", "tronco", "cogumelos", "cranio"]
	for i in 22:
		var nome: String = chaves[rng.randi() % chaves.size()]
		_objeto(nome, Vector2(rng.randf_range(30, LARG - 30), rng.randf_range(70, ALT - 20)), 1.0, Color(1.15, 1.15, 1.15))
	var g := float(_a.get("arv", 1.5))
	for p in [
		["arvore", Vector2(95, 120), 3.0],
		["arvore", Vector2(30, 520), 3.0],
		["arvore", Vector2(900, 100), 3.0],
		["arvore", Vector2(950, 530), 3.0],
		["arvore", Vector2(360, 40), 2.0],
		["arvore_morta", Vector2(610, 34), 2.0],
		["arvore_morta", Vector2(430, 560), 2.0]
	]:
		_objeto(p[0], p[1], p[2], Color(g * 0.8, g, g * 0.85), 50)


func _elenco_grade(heroi_tipo: String) -> Dictionary:
	## Teste da sombra (--grade=x,y põe a luz única nesse ponto): o herói, um cão espelhado, um lobo, e pedra, arbusto, toco e árvore.
	## Serve para a grade 3x3 de direções da luz e para conferir (em imagem) que a ponta da sombra fica do lado oposto ao da luz.
	var heroi := _ator(heroi_tipo, Vector2(380, 300), 5, 0, false, true)
	_ator("inimigo_cao_ossos", Vector2(470, 300), 1, 0, true, false)
	_ator("inimigo_lobo_sombrio", Vector2(560, 300), 1, 0, false, false)
	for x in [["pedra", Vector2(410, 370)], ["arbusto", Vector2(490, 370)], ["toco", Vector2(560, 370)], ["tronco", Vector2(640, 330)]]:
		_objeto(x[0], x[1])
	_objeto("arvore", Vector2(300, 330))
	_objeto("coluna", Vector2(600, 270))
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
		if Rect2(165, 165, 150, 180).has_point(pos):  # nada de bicho em cima do torii e do braseiro: empurra para dentro do círculo
			pos.x += 170.0
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
	(pai if pai != null else _raiz).add_child(l)
	return l


func _luzes_cena(heroi: Dictionary) -> void:
	var ht := _num("h_tocha", 45.0)
	var hm := _num("h_magia", 60.0)
	var hl := _num("h_lanterna", 60.0)
	var et := _num("e_tocha", 1.9)
	var em := _num("e_magia", 2.3)
	var novo := not _a.has("cenario_antigo")
	# ordem importa para a medição (1 = só a tocha, 3 = + lanterna + magia roxa, 6 = as do protótipo antigo, 7 = + vela do altar).
	# "orbe" = onde o corpo brilhante aparece (a lanterna pendurada, a janela do toro); "pos" = o ponto no chão que a luz ilumina.
	var defs := [
		{"nome": "tocha", "cor": Color(1.0, 0.62, 0.26), "e": et, "r": 290.0, "h": ht, "pos": HEROI_POS + Vector2(-38, -32)},
		{"nome": "lanterna_a", "cor": Color(1.0, 0.72, 0.3), "e": 2.0, "r": 210.0, "h": hl, "pos": Vector2(230, 130)},
		{"nome": "magia_roxa", "cor": Color(0.7, 0.12, 1.0), "e": em * 1.15, "r": 230.0, "h": hm, "pos": Vector2(735, 250)},
		{"nome": "magia_azul", "cor": Color(0.25, 0.65, 1.0), "e": em, "r": 170.0, "h": hm, "pos": Vector2(590, 380)},
		{"nome": "lanterna_b", "cor": Color(1.0, 0.7, 0.28), "e": 1.9, "r": 190.0, "h": hl, "pos": Vector2(170, 400)},
		{"nome": "aura_heroi", "cor": Color(0.45, 0.72, 1.0), "e": 0.7, "r": 120.0, "h": hm, "pos": HEROI_POS + Vector2(30, -8)},
		{"nome": "altar_vela", "cor": Color(1.0, 0.68, 0.32), "e": 1.1, "r": 105.0, "h": 35.0, "pos": POS_ALTAR + Vector2(15, -4)},
	]
	if novo:
		# as lanternas do cenário novo são luz quente FRACA e pequena (a luz some rápido), cada uma no seu objeto
		defs[1].merge({"e": 1.3, "r": 125.0, "h": 40.0, "pos": POS_POSTE + Vector2(23, 2), "orbe": POS_POSTE + Vector2(23, -40)}, true)
		defs[4].merge({"e": 1.2, "r": 125.0, "h": 35.0, "pos": POS_TORO + Vector2(0, -4), "orbe": POS_TORO + Vector2(0, -30)}, true)
		defs[6]["orbe"] = POS_ALTAR + Vector2(15, -27)
		# braseiro (a luz mais forte depois da tocha do herói) e fogueira: a chama fica no ponto "fogo" do item, relativo ao pé
		var fb: Dictionary = _item_cenario("braseiro")
		var ff: Dictionary = _item_cenario("fogueira")
		var chama_b: Vector2 = POS_BRASEIRO + fb.fogo - fb.pe
		var chama_f: Vector2 = POS_FOGUEIRA + ff.fogo - ff.pe
		defs.append(
			{
				"nome": "braseiro",
				"cor": Color(1.0, 0.55, 0.2),
				"e": 2.5,
				"r": 250.0,
				"h": 45.0,
				"pos": POS_BRASEIRO + Vector2(0, -6),
				"orbe": chama_b,
				"fesc": 1.0,
				"tremor": 0.1
			}
		)
		defs.append(
			{
				"nome": "fogueira",
				"cor": Color(1.0, 0.58, 0.22),
				"e": 1.4,
				"r": 170.0,
				"h": 32.0,
				"pos": POS_FOGUEIRA + Vector2(0, -6),
				"orbe": chama_f,
				"fesc": 0.7,
				"tremor": 0.1
			}
		)
	else:
		defs.remove_at(6)
	var n := int(_a.get("luzes", defs.size()))
	if _a.has("grade"):
		var xy := str(_a.grade).split(",")
		defs[0].pos = Vector2(float(xy[0]), float(xy[1]))
		defs[0].e = 3.0
		defs[0].r = 700.0
		n = 1
	for i in mini(n, defs.size()):
		var d: Dictionary = defs[i]
		var l := _luz(d.cor, d.e, d.r / 128.0, d.h, d.pos)
		var nome := str(d.nome)
		# o corpo da luz brilha sozinho: brilho aditivo de queda suave na camada sem CanvasModulate (não é mais um disco chapado)
		var orbe: Sprite2D = null
		var part: CPUParticles2D = null
		if nome != "tocha" and nome != "aura_heroi":
			orbe = Sprite2D.new()
			orbe.texture = _tex_brilho
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			orbe.material = mat
			var tam := 0.55 if nome.begins_with("magia") else 0.2
			orbe.scale = Vector2(tam, tam)
			orbe.modulate = d.cor.lerp(Color.WHITE, 0.25)
			orbe.position = d.get("orbe", d.pos)
			_olhos_raiz.add_child(orbe)
			if d.has("fesc"):
				_fogo(orbe.position, d.fesc)
			if nome.begins_with("magia"):
				part = _faiscas(d.cor)
				part.position = orbe.position
		_luzes.append({"luz": l, "def": d, "orbe": orbe, "part": part, "fase": float(i) * 1.7})


func _fogo(pos: Vector2, esc: float) -> void:
	## fogo de verdade: chama (laranja para amarelo, de baixo para cima), brasas subindo e um pouco de fumaça escura. CPUParticles2D baratas
	## na camada sem CanvasModulate; no perfil baixo as três caem pela metade (via _particulas).
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var chama := CPUParticles2D.new()
	chama.amount = 36
	chama.lifetime = 0.7
	chama.preprocess = 0.7
	chama.local_coords = false
	chama.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	chama.emission_sphere_radius = 4.0 * esc
	chama.direction = Vector2(0, -1)
	chama.spread = 12.0
	chama.gravity = Vector2(0, -18)
	chama.initial_velocity_min = 16.0 * esc
	chama.initial_velocity_max = 30.0 * esc
	chama.scale_amount_min = 0.08 * esc
	chama.scale_amount_max = 0.17 * esc
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.5, 0.8, 1.0])
	g.colors = PackedColorArray(
		[Color(1, 0.95, 0.6, 0.0), Color(1, 0.85, 0.35, 1.0), Color(1, 0.5, 0.1, 0.85), Color(0.8, 0.15, 0.05, 0.45), Color(0.3, 0.05, 0.02, 0.0)]
	)
	chama.color_ramp = g
	chama.texture = _tex_brilho
	chama.material = add
	chama.position = pos
	_olhos_raiz.add_child(chama)
	_particulas.append({"p": chama, "base": 36})
	var brasas := CPUParticles2D.new()
	brasas.amount = 10
	brasas.lifetime = 2.2
	brasas.preprocess = 2.2
	brasas.local_coords = false
	brasas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	brasas.emission_sphere_radius = 4.0 * esc
	brasas.direction = Vector2(0, -1)
	brasas.spread = 35.0
	brasas.gravity = Vector2(0, -6)
	brasas.initial_velocity_min = 22.0
	brasas.initial_velocity_max = 50.0
	brasas.scale_amount_min = 0.012
	brasas.scale_amount_max = 0.026
	brasas.color = Color(1.0, 0.6, 0.2)
	brasas.color_ramp = _rampa_alfa([0.0, 0.15, 0.7, 1.0], [0.0, 1.0, 0.7, 0.0])
	brasas.texture = _tex_brilho
	brasas.material = add
	brasas.position = pos
	_olhos_raiz.add_child(brasas)
	_particulas.append({"p": brasas, "base": 10})
	var fumaca := CPUParticles2D.new()
	fumaca.amount = 8
	fumaca.lifetime = 2.6
	fumaca.preprocess = 2.6
	fumaca.local_coords = false
	fumaca.direction = Vector2(0.2, -1)
	fumaca.spread = 15.0
	fumaca.gravity = Vector2(0, -3)
	fumaca.initial_velocity_min = 8.0
	fumaca.initial_velocity_max = 16.0
	fumaca.scale_amount_min = 0.1 * esc
	fumaca.scale_amount_max = 0.2 * esc
	fumaca.color = Color(0.07, 0.07, 0.08)
	fumaca.color_ramp = _rampa_alfa([0.0, 0.25, 1.0], [0.0, 0.4, 0.0])
	fumaca.texture = _tex_brilho
	fumaca.position = pos + Vector2(0, -8 * esc)
	_olhos_raiz.add_child(fumaca)
	_particulas.append({"p": fumaca, "base": 8})


func _faiscas(cor: Color) -> CPUParticles2D:
	## poucas partículas subindo do corpo da magia
	var p := CPUParticles2D.new()
	p.amount = 10
	p.lifetime = 1.6
	p.preprocess = 1.6
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 7.0
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.color = cor.lerp(Color.WHITE, 0.3)
	p.color_ramp = _rampa_alfa([0.0, 0.2, 1.0], [0.0, 1.0, 0.0])
	p.texture = _tex_brilho
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.05
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	_olhos_raiz.add_child(p)
	_particulas.append({"p": p, "base": 10})
	return p


func _rampa_alfa(offs: Array, alfas: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	var cs := PackedColorArray()
	for a in alfas:
		cs.append(Color(1, 1, 1, a))
	g.colors = cs
	return g


func _luar() -> void:
	## Luar: contraluz azulado fraco, de cima, que pega o topo e as bordas dos objetos pelo normal map (o cenário das bordas não vira
	## silhueta preta). DirectionalLight2D SEM sombra própria e fora de _luzes: não entra na conta das sombras das tochas (a sombra do luar
	## seria uma direção fixa, o problema da sombra parada).
	var l := DirectionalLight2D.new()
	l.color = Color(0.42, 0.58, 1.0)
	l.energy = _num("luar", 0.32)
	l.height = _num("h_luar", 0.2)
	l.rotation = deg_to_rad(_num("ang_luar", 90.0))
	l.shadow_enabled = false
	_raiz.add_child(l)


func _atmosfera() -> void:
	## vaga-lumes (pontos aditivos que piscam e vagam) e folhas vermelhas caindo devagar; CPUParticles2D baratas. O perfil "baixa" corta pela metade.
	var f := CPUParticles2D.new()
	f.amount = 34
	f.lifetime = 7.0
	f.preprocess = 7.0
	f.local_coords = false
	f.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	f.emission_rect_extents = Vector2(LARG / 2.0, ALT / 2.0)
	f.position = Vector2(LARG / 2.0, ALT / 2.0)
	f.direction = Vector2(0, -1)
	f.spread = 180.0
	f.gravity = Vector2(0, -2)
	f.initial_velocity_min = 3.0
	f.initial_velocity_max = 11.0
	f.tangential_accel_min = -6.0
	f.tangential_accel_max = 6.0
	f.damping_min = 0.5
	f.damping_max = 1.5
	f.color = Color(0.78, 1.0, 0.42)
	f.color_ramp = _rampa_alfa([0.0, 0.12, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0], [0.0, 1.0, 0.25, 1.0, 0.3, 1.0, 0.6, 0.0])
	f.texture = _tex_brilho
	f.scale_amount_min = 0.03
	f.scale_amount_max = 0.07
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	f.material = mat
	_olhos_raiz.add_child(f)
	_particulas.append({"p": f, "base": 34})
	var fo := CPUParticles2D.new()
	fo.amount = 30
	fo.lifetime = 22.0
	fo.preprocess = 22.0
	fo.local_coords = false
	fo.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fo.emission_rect_extents = Vector2(LARG / 2.0 + 40.0, 4.0)
	fo.position = Vector2(LARG / 2.0, -10.0)
	fo.direction = Vector2(0.25, 1.0)
	fo.spread = 14.0
	fo.gravity = Vector2.ZERO
	fo.initial_velocity_min = 16.0
	fo.initial_velocity_max = 28.0
	fo.angular_velocity_min = -90.0
	fo.angular_velocity_max = 90.0
	fo.tangential_accel_min = -4.0
	fo.tangential_accel_max = 4.0
	fo.color = Color(0.85, 0.1, 0.07, 0.95)
	var im := Image.create(4, 3, false, Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	fo.texture = ImageTexture.create_from_image(im)
	fo.scale_amount_min = 0.8
	fo.scale_amount_max = 1.4
	_olhos_raiz.add_child(fo)
	_particulas.append({"p": fo, "base": 30})


func _vinheta() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 3
	_raiz.add_child(camada)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.62)])
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
	_raiz.add_child(camada)
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
		elif str(d.nome).begins_with("lanterna") or d.nome in ["altar_vela", "braseiro", "fogueira"]:
			# tremor leve de lanterna e vela (muda pouco a energia: no máximo o alfa da sombra balança)
			luz.energy = d.e * (1.0 + d.get("tremor", 0.06) * sin(_t * 9.0 + l.fase) + 0.6 * d.get("tremor", 0.06) * sin(_t * 23.0 + 2.0 * l.fase))
		if _tocha_leva and (d.nome == "tocha" or d.nome == "aura_heroi"):
			luz.position = _heroi.raiz.position + (d.pos - HEROI_POS)
		elif d.nome == "magia_azul":
			if _azul_mouse:
				luz.position = _mouse_mundo()
			elif _a.has("azul"):
				var xy := str(_a.azul).split(",")
				luz.position = Vector2(float(xy[0]), float(xy[1]))
			else:
				luz.position = d.pos + Vector2(cos(_t * 0.9) * 60.0, sin(_t * 0.9) * 30.0)
			if l.orbe != null:
				l.orbe.position = luz.position
			if l.part != null:
				l.part.position = luz.position
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
		for i in _arvores.size():
			if (i + _quadros) % 2 == 0:  # cenário parado: só a luz muda, metade por quadro
				_atualizar_sombra(_arvores[i])
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
	var vp: Viewport = _sv if _sv != null else get_viewport()
	var img := vp.get_texture().get_image()
	var caminho := _fotos.path_join("%s_%d.png" % [str(_a.get("nome", "cara_nova")), n])
	img.save_png(caminho)
	print("FOTO ", caminho, " ", img.get_size(), " t=%.2f" % _t)
	if _sv != null and _a.has("janela"):  # o que a janela mostra de verdade (escala, shader e corte), para comparar apresentações
		var tela := get_viewport().get_texture().get_image()
		tela.save_png(_fotos.path_join("%s_janela_%d.png" % [str(_a.get("nome", "cara_nova")), n]))
		print("JANELA ", tela.get_size())
	if n >= _seq.size():
		get_tree().quit()
