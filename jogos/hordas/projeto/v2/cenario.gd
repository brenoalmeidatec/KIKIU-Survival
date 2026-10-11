extends RefCounted
## Carregador de cenário da v2: lê dados/v2_floresta.json e monta chão, decalques, objetos (com normal map e sombra dinâmica) e as luzes dos
## objetos. A arte fica onde sempre esteve (prototipos/objetos, prototipos/decalques, prototipos/piso): nada é movido. O mapa é maior que
## a tela, então decalques e objetos ficam em blocos de CHUNK px: bloco fora da tela (com margem) fica `visible = false` e não gasta nada;
## só os blocos que entram ou saem da margem mexem em nós, e só quando o retângulo da câmera troca de bloco.

const Ator := preload("res://v2/ator.gd")
const Sombras := preload("res://v2/sombras.gd")
const OBJ_DIR := "prototipos/objetos"  # atlas dos objetos: albedo + normal, escala final a 960x540
const DEC_DIR := "prototipos/decalques"  # decalques de chão: albedo + normal
const PISO_DIR := "prototipos/piso"
const MARGEM := 3  # px transparentes em volta de cada objeto recortado: o blur da sombra não corta na borda
const CHUNK := 160  # lado do bloco, em px do mundo
const MARGEM_BLOCO := 200.0  # margem (px) em volta da tela em que os blocos ficam visíveis (decalque grande tem até ~190 px de meia largura)

var tam := Vector2(2880, 1620)
var com_normal := true
var ganho_obj := 1.7  # a arte nova é bem escura: levanta antes da luz (o ambiente escuro faz o resto)
var ganho_dec := 1.4
var objetos: Array[Ator] = []
var ativos: Array[Ator] = []  # objetos dos blocos visíveis agora
var n_decalques := 0
var ms_carga := 0.0
var nascimento: Dictionary = {}
var _mundo: Node2D
var _chao_deco: Node2D
var _luzes
var _sombras
var _itens := {}
var _dec_itens := {}
var _blocos := {}  # Vector2i -> {"dec": Node2D, "obj": Array[Ator], "vis": bool}
var _faixa := Rect2i(1, 1, -1, -1)  # blocos visíveis (x0, y0, x1, y1 em pos/size), vazio no início


## dados = dados/v2_floresta.json já lido. `mundo` é o nó com y-sort onde ficam os objetos; `luzes` e `sombras` são os módulos.
func carregar(dados: Dictionary, mundo: Node2D, luzes, sombras, normal := true) -> void:
	var t0 := Time.get_ticks_usec()
	_mundo = mundo
	_luzes = luzes
	_sombras = sombras
	com_normal = normal
	var m: Dictionary = dados.get("mapa", {})
	tam = Vector2(float(m.get("tam", [2880, 1620])[0]), float(m.get("tam", [2880, 1620])[1]))
	nascimento = dados.get("nascimento", {})
	ganho_obj = float(m.get("ganho_objetos", ganho_obj))
	ganho_dec = float(m.get("ganho_decalques", ganho_dec))
	_chao(m.get("chao", {}))
	_chao_deco = Node2D.new()  # decalques: acima do piso (-100), abaixo das sombras (-51 e -50)
	_chao_deco.z_index = -90
	_mundo.add_child(_chao_deco)
	_carregar_decalques()
	_carregar_itens()
	for d in dados.get("decalques", []):
		_decalque(str(d[0]), Vector2(float(d[1]), float(d[2])), d.size() > 3 and int(d[3]) == 1)
	var luz_obj: Dictionary = dados.get("luz_objetos", {})
	for o in dados.get("objetos", []):
		_objeto(str(o[0]), Vector2(float(o[1]), float(o[2])), luz_obj)
	for l in dados.get("luzes", []):
		var p := Vector2(float(l.pos[0]), float(l.pos[1]))
		var orbe = p + Vector2(float(l.orbe[0]), float(l.orbe[1])) if l.has("orbe") else null
		_luzes.criar(str(l.tipo), p, orbe, float(l.get("fogo", 0.0)))
	ms_carga = (Time.get_ticks_usec() - t0) / 1000.0


# ------------------------------------------------------------------ chão


func _chao(c: Dictionary) -> void:
	var raiz := ProjectSettings.globalize_path("res://")
	var piso := Sprite2D.new()
	var nome := str(c.get("piso", "piso"))
	var ct := CanvasTexture.new()
	ct.diffuse_texture = ImageTexture.create_from_image(Image.load_from_file(raiz.path_join(PISO_DIR).path_join(nome + ".png")))
	var nn := raiz.path_join(PISO_DIR).path_join(nome + "_normal.png")
	if com_normal and FileAccess.file_exists(nn):
		ct.normal_texture = ImageTexture.create_from_image(Image.load_from_file(nn))
	piso.texture = ct
	# sob a luz laranja o musgo ia a amarelo saturado: tira um pouco do verde e dessatura o chão antes da luz
	var sh := Shader.new()
	sh.code = (
		"shader_type canvas_item;\nuniform float verde = 0.8;\nuniform float dessat = 0.3;\nuniform float ganho = 1.0;\n"
		+ "void fragment(){ vec4 c = texture(TEXTURE, UV); float l = dot(c.rgb, vec3(0.3, 0.5, 0.2));"
		+ " vec3 b = mix(c.rgb, vec3(l) * vec3(1.05, 0.95, 0.9), dessat); b.g *= verde;"
		+ " COLOR = vec4(min(b * ganho, vec3(1.0)), c.a); }\n"
	)
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("verde", float(c.get("verde", 0.8)))
	mat.set_shader_parameter("dessat", float(c.get("dessat", 0.3)))
	mat.set_shader_parameter("ganho", float(c.get("ganho", 3.6)))
	piso.material = mat
	piso.region_enabled = true
	piso.region_rect = Rect2(Vector2.ZERO, tam)
	piso.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	piso.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	piso.centered = false
	piso.z_index = -100
	_mundo.add_child(piso)


# ------------------------------------------------------------------ decalques


func _carregar_decalques() -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join(DEC_DIR)
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("decalques.json")))
	var atlas := Image.load_from_file(dir.path_join("decalques.png"))
	atlas.convert(Image.FORMAT_RGBA8)
	var norm: Image = null
	if com_normal and FileAccess.file_exists(dir.path_join("decalques_normal.png")):
		norm = Image.load_from_file(dir.path_join("decalques_normal.png"))
		norm.convert(Image.FORMAT_RGBA8)
	for it in info.itens:
		var r := Rect2i(int(it.regiao[0]), int(it.regiao[1]), int(it.regiao[2]), int(it.regiao[3]))
		var ct := CanvasTexture.new()
		ct.diffuse_texture = ImageTexture.create_from_image(atlas.get_region(r))
		if norm != null:
			ct.normal_texture = ImageTexture.create_from_image(norm.get_region(r))
		_dec_itens[it.nome] = {"tex": ct, "centro": Vector2(float(it.centro[0]), float(it.centro[1]))}


func _bloco(p: Vector2) -> Dictionary:
	var k := Vector2i(clampi(int(p.x / CHUNK), 0, int(tam.x / CHUNK)), clampi(int(p.y / CHUNK), 0, int(tam.y / CHUNK)))
	if not _blocos.has(k):
		var n := Node2D.new()
		n.visible = false
		_chao_deco.add_child(n)
		_blocos[k] = {"dec": n, "obj": [] as Array[Ator], "vis": false}
	return _blocos[k]


## Um decalque no chão, com o centro do item em pos. Fica no bloco de chão (acima do piso, abaixo das sombras) e recebe luz com normal.
func _decalque(nome: String, pos: Vector2, espelha := false) -> void:
	if not _dec_itens.has(nome):
		push_warning("v2: decalque desconhecido: " + nome)
		return
	var it: Dictionary = _dec_itens[nome]
	var s := Sprite2D.new()
	s.texture = it.tex
	s.centered = false
	s.offset = -it.centro
	s.flip_h = espelha
	s.position = pos
	s.modulate = Color(ganho_dec, ganho_dec, ganho_dec)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bloco(pos).dec.add_child(s)
	n_decalques += 1


# ------------------------------------------------------------------ objetos


## Atlas de objetos de cenário (prototipos/objetos). Cada item é recortado UMA vez (com margem) e ganha a textura nítida, a borrada para a
## sombra do modo médio e a CanvasTexture com normal map. O campo "colisao" do cenario.json (outro agente) é ignorado aqui.
func _carregar_itens() -> void:
	var raiz := ProjectSettings.globalize_path("res://")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(raiz.path_join(OBJ_DIR).path_join("cenario.json")))
	var atlas := Image.load_from_file(raiz.path_join(OBJ_DIR).path_join(str(info.get("enfeites", "enfeites.png"))))
	atlas.convert(Image.FORMAT_RGBA8)
	var norm: Image = null
	if com_normal:
		norm = Image.load_from_file(raiz.path_join(OBJ_DIR).path_join(str(info.get("enfeites_normal", "enfeites_normal.png"))))
		norm.convert(Image.FORMAT_RGBA8)
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
		_itens[it.nome] = {
			"tn": tn,
			"tb": Sombras.borrar_folha(rec, rec.get_width(), rec.get_height()),
			"desenho": desenho,
			"w": r.size.x,
			"h": r.size.y,
			"pe": Vector2(float(it.pe[0]), float(it.pe[1])),
			"fogo": Vector2(float(it.fogo[0]), float(it.fogo[1])) if it.has("fogo") else Vector2.ZERO,
		}


## Um objeto de cenário (escala 1 = escala final do jogo) + o dono da sombra dinâmica dele. Quanto mais alto o objeto, menor o comprimento
## máximo da sombra (a árvore de 150 px não deita 200 px de sombra no chão). Se há luz para o objeto (luz_objetos), cria a luz.
func _objeto(nome: String, pos: Vector2, luz_obj: Dictionary) -> void:
	if not _itens.has(nome):
		push_warning("v2: objeto desconhecido: " + nome)
		return
	var it: Dictionary = _itens[nome]
	var s := Sprite2D.new()
	s.texture = it.desenho
	s.centered = false
	s.offset = Vector2(-it.pe.x - MARGEM, -it.pe.y - MARGEM)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	s.modulate = Color(ganho_obj, ganho_obj, ganho_obj)
	s.visible = false
	_mundo.add_child(s)
	var a := Ator.new()
	a.chave = nome
	a.raiz = s
	a.sprite = s
	a.pos = pos
	a.alt = float(it.h)
	a.rmax = 0.5 if a.alt > 100.0 else (0.9 if a.alt > 50.0 else 1.6)
	a.offset = s.offset
	a.tex_n = it.tn
	a.tex_b = it.tb
	a.larg_blob = float(it.w) * (0.35 if a.alt > 100.0 else 0.6)
	objetos.append(a)
	_bloco(pos).obj.append(a)
	if luz_obj.has(nome):
		var lo: Dictionary = luz_obj[nome]
		var luz_pos: Vector2 = pos + Vector2(float(lo.luz[0]), float(lo.luz[1]))
		var orbe: Vector2
		if str(lo.orbe) == "fogo":
			orbe = pos + it.fogo - it.pe
		else:
			orbe = pos + Vector2(float(lo.orbe[0]), float(lo.orbe[1]))
		_luzes.criar(str(lo.tipo), luz_pos, orbe, float(lo.get("fogo", 0.0)))


# ------------------------------------------------------------------ visibilidade por bloco


## Liga os blocos que entraram na margem da tela e desliga os que saíram. Só faz trabalho quando o retângulo da câmera troca de bloco.
func atualizar_blocos(rect: Rect2) -> bool:
	var r := rect.grow(MARGEM_BLOCO)
	var x0 := clampi(int(floor(r.position.x / CHUNK)), 0, int(tam.x / CHUNK))
	var y0 := clampi(int(floor(r.position.y / CHUNK)), 0, int(tam.y / CHUNK))
	var x1 := clampi(int(floor(r.end.x / CHUNK)), 0, int(tam.x / CHUNK))
	var y1 := clampi(int(floor(r.end.y / CHUNK)), 0, int(tam.y / CHUNK))
	var nova := Rect2i(x0, y0, x1 - x0, y1 - y0)
	if nova == _faixa:
		return false
	_faixa = nova
	ativos.clear()
	for k: Vector2i in _blocos:
		var dentro := k.x >= x0 and k.x <= x1 and k.y >= y0 and k.y <= y1
		var b: Dictionary = _blocos[k]
		if dentro:
			ativos.append_array(b.obj)
		if dentro == b.vis:
			continue
		b.vis = dentro
		b.dec.visible = dentro
		for a: Ator in b.obj:
			a.raiz.visible = dentro
			if not dentro:
				_sombras.ativar(a, false)
	return true


func n_blocos_visiveis() -> int:
	var n := 0
	for k in _blocos:
		if _blocos[k].vis:
			n += 1
	return n


func n_blocos() -> int:
	return _blocos.size()
