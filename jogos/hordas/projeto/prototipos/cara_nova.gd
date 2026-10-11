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

const PASTA := "../prototipos/cara_nova/sprites"
const LARG := 960
const ALT := 540
const HEROI_POS := Vector2(470, 292)

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


func _ready() -> void:
	_a = _argumentos()
	_fotos = str(_a.get("fotos", ""))
	_seq = str(_a.get("seq", "1.0")).split(",")
	_modo = "medir" if _a.has("medir") else "foto"
	_medicao["duracao"] = float(_a.get("duracao", 6.0))
	_com_normal = not _a.has("sem_normal")
	_com_olhos = not _a.has("sem_olhos")
	var janela := get_window()
	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	janela.content_scale_size = Vector2i(LARG, ALT)
	janela.size = Vector2i(1280, 720)
	if _modo == "medir":
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
	t.diffuse_texture = ImageTexture.create_from_image(_imagem(nome + "_albedo.png"))
	if _com_normal:
		t.normal_texture = ImageTexture.create_from_image(_imagem(nome + "_normal.png"))
	var d := {"tex": t, "w": int(info.quadro[0]), "h": int(info.quadro[1]), "info": info, "emissao": null}
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


# ------------------------------------------------------------------ cena

func _montar() -> void:
	var escuro := CanvasModulate.new()
	escuro.color = Color(str(_a.get("amb", "1c2a24")))
	add_child(escuro)
	_mundo = Node2D.new()
	_mundo.y_sort_enabled = true
	add_child(_mundo)
	_chao()
	_enfeites()
	var heroi_tipo := "hazaki_samurai" if _a.has("samurai") else "hazaki"
	var heroi := _ator(heroi_tipo, HEROI_POS, 5, 0, false, true)
	var lista := _lista_monstros()
	for m in lista:
		_ator(m.tipo, m.pos, m.linha, m.coluna, m.espelha, false)
	_primeiro_plano()
	_olhos_raiz = Node2D.new()
	var camada_olhos := CanvasLayer.new()   # fora do CanvasModulate: o brilho dos olhos não escurece junto com o resto
	camada_olhos.layer = 2
	add_child(camada_olhos)
	camada_olhos.add_child(_olhos_raiz)
	for a in _atores:
		_criar_olho(a)
	_luzes_cena(heroi)
	if not _a.has("sem_vinheta"):
		_vinheta()
	if _a.has("nomes"):
		pass


func _chao() -> void:
	var piso := Sprite2D.new()
	piso.texture = load("res://assets/cenarios/floresta/piso.png") as Texture2D
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
	sh.code = "shader_type canvas_item;\nuniform float ganho = 2.2;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); COLOR = vec4(min(c.rgb * ganho, vec3(1.0)), c.a); }\n"
	m.shader = sh
	m.set_shader_parameter("ganho", _num("ganho_chao", 2.4))
	piso.material = m
	_mundo.add_child(piso)


func _enfeites() -> void:
	var tex := load("res://assets/cenarios/floresta/enfeites.png") as Texture2D
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# (nome da região, x, y de pé) no mundo de 960x540: arbustos, pedras, troncos e cogumelos espalhados
	var regioes := {"arbusto": Rect2(157, 0, 26, 25), "pedra": Rect2(184, 0, 31, 20), "toco": Rect2(90, 0, 22, 24),
		"tronco": Rect2(113, 0, 43, 21), "cogumelos": Rect2(216, 0, 15, 14), "cranio": Rect2(350, 0, 24, 20)}
	var chaves := regioes.keys()
	for i in 22:
		var r: Rect2 = regioes[chaves[rng.randi() % chaves.size()]]
		var s := Sprite2D.new()
		s.texture = tex
		s.region_enabled = true
		s.region_rect = r
		s.centered = false
		s.offset = Vector2(-r.size.x / 2.0, -r.size.y)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(rng.randf_range(30, LARG - 30), rng.randf_range(70, ALT - 20))
		s.modulate = Color(1.15, 1.15, 1.15)
		_mundo.add_child(s)


func _primeiro_plano() -> void:
	## árvores nas bordas (primeiro plano), grandes e escuras, cobrindo os cantos como na referência
	var tex := load("res://assets/cenarios/floresta/enfeites.png") as Texture2D
	var arv := Rect2(0, 0, 61, 76)
	var morta := Rect2(62, 0, 27, 49)
	var pontos := [
		[Vector2(70, 150), 4.0, arv], [Vector2(-10, 470), 4.0, arv], [Vector2(880, 120), 3.0, arv],
		[Vector2(960, 420), 4.0, arv], [Vector2(330, 56), 2.0, arv], [Vector2(640, 40), 2.0, morta],
		[Vector2(560, 570), 3.0, arv], [Vector2(190, 575), 2.0, morta],
	]
	for p in pontos:
		var s := Sprite2D.new()
		s.texture = tex
		s.region_enabled = true
		s.region_rect = p[2]
		s.centered = false
		s.offset = Vector2(-p[2].size.x / 2.0, -p[2].size.y)
		s.scale = Vector2(p[1], p[1])
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = p[0]
		s.z_index = 50
		s.modulate = Color(float(_a.get("arv", 1.5)) * 0.8, float(_a.get("arv", 1.5)), float(_a.get("arv", 1.5)) * 0.85)
		_mundo.add_child(s)


func _lista_monstros() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := int(_a.get("sprites", 20)) if _modo == "medir" else int(_num("monstros", 22))
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
	var sombra := Sprite2D.new()
	sombra.texture = _tex_sombra
	sombra.scale = Vector2(t.w / 24.0, t.w / 24.0 * 0.8)
	sombra.light_mask = 0
	sombra.z_index = -1
	sombra.position = Vector2(0, -1)
	raiz.add_child(sombra)
	var s := Sprite2D.new()
	s.texture = t.tex
	s.region_enabled = true
	s.region_rect = Rect2(coluna * t.w, linha * t.h, t.w, t.h)
	s.centered = false
	s.offset = Vector2(-t.w / 2.0, -t.pe)
	s.flip_h = espelha
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	raiz.add_child(s)
	var a := {"raiz": raiz, "sprite": s, "tipo": t, "linha": linha, "coluna": coluna, "espelha": espelha, "heroi": heroi, "olho": null}
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
	var ht := _num("h_tocha", 22.0)
	var hm := _num("h_magia", 26.0)
	var hl := _num("h_lanterna", 26.0)
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
	for i in mini(n, defs.size()):
		var d: Dictionary = defs[i]
		var l := _luz(d.cor, d.e, d.r / 128.0, d.h, d.pos)
		_luzes.append({"luz": l, "def": d})


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

func _process(delta: float) -> void:
	_t += delta
	var passo := int(_t / 0.16)
	for a in _atores:
		var anda: bool = a.heroi or _modo == "medir" or true
		if anda:
			var t: Dictionary = a.tipo
			var cols := int(t.info.colunas.size())
			var c: int = (passo + int(a.raiz.position.x)) % cols if not a.heroi else (passo % cols)
			if a.heroi and c == 0 and cols > 1:
				c = 1
			a.coluna = c
			a.sprite.region_rect = Rect2(c * t.w, a.linha * t.h, t.w, t.h)
			_sync_olho(a)
	for l in _luzes:
		var d: Dictionary = l.def
		var luz: PointLight2D = l.luz
		if d.nome == "tocha":
			luz.energy = d.e + 0.12 * sin(_t * 13.0) + 0.07 * sin(_t * 29.0 + 1.3)
		elif d.nome == "magia_azul":
			luz.position = d.pos + Vector2(cos(_t * 0.9) * 60.0, sin(_t * 0.9) * 30.0)
	if _modo == "medir":
		_medir()
	elif _proximo < _seq.size() and _t >= float(_seq[_proximo]):
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
		print("MEDIDA luzes=%d sprites=%d normal=%d fps=%.1f frames=%d seg=%.2f" % [_luzes.size(), _atores.size(), 1 if _com_normal else 0, frames / dec, frames, dec])
		get_tree().quit()


func _salvar_tela(n: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var caminho := _fotos.path_join("%s_%d.png" % [str(_a.get("nome", "cara_nova")), n])
	img.save_png(caminho)
	print("FOTO ", caminho, " ", img.get_size(), " t=%.2f" % _t)
	if n >= _seq.size():
		get_tree().quit()
