extends Node2D
## Protótipo de luz 2.5D (cena de teste, fora do jogo). Duas metades iguais, mesmas luzes:
## esquerda = sprites sem normal map (como é hoje); direita = com normal map gerado por
## jogos/hordas/prototipos/luz/gerar_normais.py. Imagens lidas de fora de res:// de propósito
## (ficam em jogos/hordas/prototipos/luz/, sem duplicar nada dentro de assets/).
##
## Uso (a partir de jogos/hordas):
##   godot --path projeto res://prototipos/luz.tscn -- --fotos=PASTA --seq=0.8,1.6,2.4,3.2
##   godot --path projeto res://prototipos/luz.tscn -- --medir=3 --sprites=300   (fps, sem V-Sync)

const PASTA := "../prototipos/luz"
const ESCALA := 2.0
const META := 320.0
const RECORTE_HEROI := Rect2(0, 0, 44, 60)     # Hazaki: linha 0 (baixo), coluna 0 (parado)
const RECORTE_CAO := Rect2(0, 0, 50, 45)       # cão de ossos: linha 0 (frente), coluna 0 (andando 1)

var _t := 0.0
var _modo := "lado"
var _fotos := ""
var _seq: Array = []
var _proximo := 0
var _luzes := 3
var _extras := 0
var _tex_luz: GradientTexture2D
var _imgs := {}
var _lados: Array = []
var _medicao := {"inicio": -1.0, "frames": 0, "aquecer": 1.0, "duracao": 6.0}


func _ready() -> void:
	var args := _argumentos()
	_fotos = str(args.get("fotos", ""))
	_seq = str(args.get("seq", "0.8,1.6,2.4,3.2")).split(",")
	_modo = "medir" if args.has("medir") else "lado"
	_luzes = int(args.get("medir", 3))
	_extras = int(args.get("sprites", 0))
	_medicao["duracao"] = float(args.get("duracao", 6.0))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_tex_luz = _textura_luz()
	if args.has("domo"):
		_montar_domo(str(args["domo"]))
	else:
		_montar()


func _argumentos() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var partes := a.trim_prefix("--").split("=", true, 1)
		d[partes[0]] = partes[1] if partes.size() > 1 else "1"
	return d


func _imagem(nome: String) -> Image:
	if not _imgs.has(nome):
		var caminho := ProjectSettings.globalize_path("res://").path_join(PASTA).path_join(nome).simplify_path()
		_imgs[nome] = Image.load_from_file(caminho)
		if _imgs[nome] == null:
			push_error("sem imagem: " + caminho)
	return _imgs[nome]


func _textura(difusa: String, normal: String) -> CanvasTexture:
	var t := CanvasTexture.new()
	t.diffuse_texture = ImageTexture.create_from_image(_imagem(difusa))
	if normal != "":
		t.normal_texture = ImageTexture.create_from_image(_imagem(normal))
	return t


func _textura_luz() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(0, 0, 0, 1))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


func _sprite(pai: Node, tex: Texture2D, recorte: Rect2, pos: Vector2, mascara: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = recorte
	s.position = pos
	s.scale = Vector2(ESCALA, ESCALA)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.light_mask = mascara
	pai.add_child(s)
	return s


func _luz(pai: Node, cor: Color, energia: float, escala: float, altura: float, mascara: int, pos: Vector2) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _tex_luz
	l.color = cor
	l.energy = energia
	l.texture_scale = escala
	l.height = altura
	l.range_item_cull_mask = mascara
	l.position = pos
	pai.add_child(l)
	return l


func _montar() -> void:
	var escuro := CanvasModulate.new()
	escuro.color = Color(0.3, 0.32, 0.42)     # ambiente de noite na floresta: tudo escuro, luz cria o resto
	add_child(escuro)
	var piso_tex := load("res://assets/cenarios/floresta/piso.png") as Texture2D
	var base_heroi := _textura("base/andando_8.png", "")
	var heroi_tex := _textura("base/andando_8.png", "normais/normal_andando_8.png")
	var cao_base := _textura("base/inimigo_cao_ossos.png", "")
	var cao_tex := _textura("base/inimigo_cao_ossos.png", "normais/normal_inimigo_cao_ossos.png")
	for i in 2:
		var x0 := META * i
		var mascara := 1 << i
		var com_normal := i == 1
		var grupo := Node2D.new()
		grupo.name = "Lado" + str(i)
		add_child(grupo)
		var piso := Sprite2D.new()
		piso.texture = piso_tex
		piso.region_enabled = true
		piso.region_rect = Rect2(0, 0, META / ESCALA, 360.0 / ESCALA)
		piso.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		piso.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		piso.position = Vector2(x0 + META / 2.0, 180)
		piso.scale = Vector2(ESCALA, ESCALA)
		piso.light_mask = mascara
		grupo.add_child(piso)
		var heroi := _sprite(grupo, heroi_tex if com_normal else base_heroi, RECORTE_HEROI, Vector2(x0 + 160, 200), mascara)
		var tocha := _luz(heroi, Color(1.0, 0.62, 0.28), 1.5, 0.5, 10.0, mascara, Vector2(12, -22))
		var lua := _luz(grupo, Color(0.55, 0.72, 1.0), 0.8, 1.6, 40.0, mascara, Vector2(x0 + 60, 30))
		var magia := _luz(grupo, Color(0.72, 0.35, 1.0), 1.0, 0.7, 12.0, mascara, Vector2(x0 + 160, 180))
		var caes: Array = []
		var posicoes := [[Vector2(x0 + 70, 150), RECORTE_CAO, false], [Vector2(x0 + 250, 110), Rect2(0, 90, 50, 45), true], [Vector2(x0 + 120, 290), Rect2(0, 45, 50, 45), false]]
		for p in posicoes:
			var c := _sprite(grupo, cao_tex if com_normal else cao_base, p[1], p[0], mascara)
			c.flip_h = p[2]
			caes.append(c)
		_lados.append({"x0": x0, "tocha": tocha, "lua": lua, "magia": magia, "grupo": grupo, "mascara": mascara, "cao_tex": cao_tex, "cao_base": cao_base, "com_normal": com_normal, "heroi": heroi})
	if _modo == "medir":
		_preparar_medicao()


## Teste de convenção (não é parte do protótipo): um domo de normal conhecida, luz no canto superior direito.
## Se o topo-direita acender, a convenção de Y do Godot bate com a dos sprites gerados.
func _montar_domo(pasta_domo: String) -> void:
	var escuro := CanvasModulate.new()
	escuro.color = Color(0.12, 0.12, 0.12)
	add_child(escuro)
	var dif := Image.load_from_file(pasta_domo.path_join("dome_dif.png"))
	var nor := Image.load_from_file(pasta_domo.path_join("dome_norm.png"))
	# folha 128x64 com o domo na metade direita: testa se o recorte (region_rect) mantém a normal alinhada
	var folha_d := Image.create_empty(128, 64, false, Image.FORMAT_RGBA8)
	folha_d.blit_rect(dif, Rect2i(0, 0, 64, 64), Vector2i(64, 0))
	var folha_n := Image.create_empty(128, 64, false, Image.FORMAT_RGBA8)
	folha_n.blit_rect(nor, Rect2i(0, 0, 64, 64), Vector2i(64, 0))
	var t := CanvasTexture.new()
	t.diffuse_texture = ImageTexture.create_from_image(folha_d)
	if not OS.get_cmdline_user_args().has("--plano"):
		t.normal_texture = ImageTexture.create_from_image(folha_n)
	var s := _sprite(self, t, Rect2(64, 0, 64, 64), Vector2(160, 180), 1)
	s.scale = Vector2(4, 4)
	_luz(self, Color(1, 1, 1), 2.0, 1.5, 20.0, 1, Vector2(160 + 40, 180 - 40))


func _preparar_medicao() -> void:
	_lados[0]["grupo"].visible = false   # só a metade com normal conta: 1 ou 3 luzes na cena inteira
	var lado: Dictionary = _lados[1]
	if _luzes < 3:
		lado["lua"].enabled = false
		lado["magia"].enabled = false
	if _extras > 0:
		var cols := int(ceil(sqrt(_extras * META / 360.0)))
		var linhas := int(ceil(float(_extras) / cols))
		for k in _extras:
			var cx := META * 1 + (META / cols) * (k % cols) + (META / cols) / 2.0
			var cy := 360.0 / linhas * (k / cols) + 360.0 / linhas / 2.0
			_sprite(lado["grupo"], lado["cao_tex"], RECORTE_CAO, Vector2(cx, cy), lado["mascara"])


func _process(delta: float) -> void:
	_t += delta
	for lado in _lados:
		var x0: float = lado["x0"]
		var tocha: PointLight2D = lado["tocha"]
		tocha.energy = 1.05 + 0.08 * sin(_t * 13.0) + 0.05 * sin(_t * 29.0 + 1.3)
		tocha.texture_scale = 0.5 + 0.02 * sin(_t * 17.0)
		var ang := _t * 0.9
		var magia: PointLight2D = lado["magia"]
		magia.position = Vector2(x0 + 160 + cos(ang) * 105.0, 180 + sin(ang) * 60.0)
	if _modo == "medir":
		_medir(delta)
	elif _proximo < _seq.size() and _t >= float(_seq[_proximo]):
		_proximo += 1
		_salvar_tela(_proximo)


func _medir(_delta: float) -> void:
	if _t < _medicao["aquecer"]:
		return
	if _medicao["inicio"] < 0.0:
		_medicao["inicio"] = _t
		return
	_medicao["frames"] = int(_medicao["frames"]) + 1
	var dec: float = _t - float(_medicao["inicio"])
	if dec >= float(_medicao["duracao"]):
		var frames: int = int(_medicao["frames"])
		var fps: float = frames / dec
		print("MEDIDA luzes=%d sprites_extras=%d normal=1 fps=%.1f frames=%d seg=%.2f" % [_luzes, _extras, fps, frames, dec])
		get_tree().quit()


func _salvar_tela(n: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(_fotos.path_join("luz_lado_%d.png" % n))
	print("FOTO ", _fotos.path_join("luz_lado_%d.png" % n), " t=%.2f" % _t)
	if n >= _seq.size():
		get_tree().quit()
