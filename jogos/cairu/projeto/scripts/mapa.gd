extends Node2D
## Um mapa carregado de capitulos/mapas/<id>.json.
##
## O fundo pode ser uma imagem ("fundo": {"imagem": "x.png"}) ou um desenho
## feito em código ("fundo": {"desenho": "sala_cairu"}). As colisões vêm de
## retângulos ("colisoes") e/ou de uma imagem-máscara ("mascara") do mesmo
## tamanho do mapa: branco ou transparente = chão, qualquer outra cor = parede.

var id := ""
var dados: Dictionary = {}
var tam := Vector2(640, 400)
var limites := Rect2()
var solidos: Array[Rect2] = []
var pontos: Array = []   # [{rect, dados}]
var portas: Array = []   # [{rect, para, chegada}]
var _mascara: Image
var _mascara_tex: Texture2D
var _fonte: Font
var _desenho := ""
var debug := false
var _luzes := Camada.new()     # luz e sombra no chão (por cima do fundo, embaixo das pessoas)
var _depuracao := Camada.new() # paredes/portas/pontos do modo de teste


class Camada extends Node2D:
	var desenhar: Callable

	func _draw() -> void:
		if desenhar.is_valid():
			desenhar.call(self)


## Folha de porta que abre de verdade: recorta a porta do próprio fundo do mapa
## e "gira" ela pra dentro, mostrando o vão escuro atrás.
class Folha extends Node2D:
	var tex: Texture2D
	var regiao := Rect2()
	var abertura := 0.0:
		set(v):
			abertura = v
			queue_redraw()

	func _draw() -> void:
		if abertura <= 0.001:
			return
		var r := regiao
		draw_rect(r, Color("0d1026"))
		draw_rect(Rect2(r.position.x, r.end.y - 8, r.size.x, 8), Color("1b2046"))
		draw_rect(Rect2(r.position.x + r.size.x * 0.35, r.position.y + 6, r.size.x * 0.5, r.size.y - 14), Color(1, 0.9, 0.6, 0.06 * abertura))
		var w: float = r.size.x * (1.0 - 0.8 * abertura)
		var luz: float = 1.0 - 0.4 * abertura
		draw_texture_rect_region(tex, Rect2(r.position, Vector2(w, r.size.y)), r, Color(luz, luz, luz))
		draw_rect(Rect2(r.position.x + w - 1, r.position.y, 1, r.size.y), Color(0, 0, 0, 0.45))


static var _brilho: GradientTexture2D


func carregar(id_mapa: String, d: Dictionary) -> void:
	id = id_mapa
	dados = d
	_fonte = load("res://assets/fonte/PressStart2P.ttf")
	z_index = -10
	var t: Array = d.get("tamanho", [640, 400])
	tam = Vector2(t[0], t[1])
	var a: Array = d.get("area_andavel", [0, 0, tam.x, tam.y])
	limites = _ret(a)
	for c in d.get("colisoes", []):
		solidos.append(_ret(c))
	for p in d.get("pontos", []):
		pontos.append({"rect": _ret([p.x, p.y, p.w, p.h]), "dados": p})
	for p in d.get("portas", []):
		portas.append({"rect": _ret([p.x, p.y, p.w, p.h]), "para": p.get("para", ""), "chegada": p.get("chegada", {})})

	var fundo: Dictionary = d.get("fundo", {})
	if fundo.has("imagem"):
		var tex := Dados.imagem_mapa(fundo.imagem)
		if tex:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			add_child(s)
			if not d.has("tamanho"):
				tam = tex.get_size()
			_criar_folhas(tex, d.get("portas", []))
	_desenho = fundo.get("desenho", "")
	if not _brilho:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_brilho = GradientTexture2D.new()
		_brilho.gradient = g
		_brilho.fill = GradientTexture2D.FILL_RADIAL
		_brilho.fill_from = Vector2(0.5, 0.5)
		_brilho.fill_to = Vector2(1.0, 0.5)
		_brilho.width = 64
		_brilho.height = 64
	_luzes.desenhar = _desenhar_luzes
	add_child(_luzes)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var aditivas := Camada.new()
	aditivas.material = mat
	aditivas.desenhar = _desenhar_luzes.bind(true)
	add_child(aditivas)
	# luzes de verdade (iluminam também quem passa) e partículas no ar
	var efeitos := Visual.ligado()
	for l in d.get("luzes", []):
		var rr := Rect2(l.get("x", 0), l.get("y", 0), l.get("w", 64), l.get("h", 64))
		match l.get("tipo", "luz"):
			"luz":
				add_child(Visual.luz(rr, Color(l.get("cor", "#fff3c0")), l.get("forca", 0.2)))
			"faixa":
				if efeitos:
					add_child(Visual.particulas({"tipo": "poeira", "x": rr.position.x, "y": rr.position.y,
						"w": rr.size.x + l.get("inclinacao", 30.0), "h": rr.size.y, "quantidade": 10}))
	if efeitos:
		for pt in d.get("particulas", []):
			add_child(Visual.particulas(pt))
	_depuracao.desenhar = _desenhar_debug
	_depuracao.z_index = 100
	add_child(_depuracao)
	if d.has("mascara"):
		var m := Dados.imagem_mapa(d.mascara)
		if m:
			_mascara_tex = m
			_mascara = m.get_image()
			if _mascara.is_compressed():
				_mascara.decompress()


## Acha a folha de cada porta de parede no desenho do fundo (ou usa "folha": [x,y,w,h]).
## "folha": false desliga. Portas na borda de baixo ou dos lados não têm folha.
func _criar_folhas(tex: Texture2D, defs: Array) -> void:
	var img: Image = null
	for i in portas.size():
		var dp: Dictionary = defs[i]
		var pr: Rect2 = portas[i].rect
		var reg := Rect2()
		if dp.get("folha") is Array:
			reg = _ret(dp.folha)
		elif dp.get("folha", true) == false:
			continue
		else:
			if pr.size.y > pr.size.x or pr.position.y > tam.y * 0.5:
				continue
			if img == null:
				img = tex.get_image()
				if img.is_compressed():
					img.decompress()
			var cx := int(pr.get_center().x)
			var y0 := int(pr.position.y) - 1
			var base := img.get_pixel(cx, y0).get_luminance() * 0.8
			var topo := y0
			while topo > 0 and img.get_pixel(cx, topo - 1).get_luminance() >= base:
				topo -= 1
			var fundo := y0
			while fundo < img.get_height() - 1 and img.get_pixel(cx, fundo + 1).get_luminance() >= base:
				fundo += 1
			var meio := (topo + fundo) / 2
			var esq := cx
			while esq > 0 and img.get_pixel(esq - 1, meio).get_luminance() >= base:
				esq -= 1
			var dir := cx
			while dir < img.get_width() - 1 and img.get_pixel(dir + 1, meio).get_luminance() >= base:
				dir += 1
			if fundo - topo < 20 or fundo - topo > 140 or dir - esq < 12:
				continue
			reg = Rect2(esq, topo, dir - esq + 1, fundo - topo + 1)
		var f := Folha.new()
		f.tex = tex
		f.regiao = reg
		add_child(f)
		portas[i]["folha"] = f


func porta_para(destino: String) -> Dictionary:
	for p in portas:
		if p.para == destino:
			return p
	return {}


func porta_perto(pos: Vector2, raio := 9999.0) -> Dictionary:
	var melhor := {}
	var menor := raio
	for p in portas:
		var dd: float = p.rect.get_center().distance_to(pos)
		if dd < menor:
			menor = dd
			melhor = p
	return melhor


## Abre (1) ou fecha (0) a folha da porta com som. Sem folha, não faz nada.
func mexer_porta(p: Dictionary, abrir: bool, tempo := 0.28) -> void:
	var f = p.get("folha")
	if not f is Folha or not is_instance_valid(f):
		return
	var alvo := 1.0 if abrir else 0.0
	if is_equal_approx(f.abertura, alvo):
		return
	if abrir:
		Jogo.som("porta_abrir", 0.0, 0.05)
	var tw := create_tween()
	tw.tween_property(f, "abertura", alvo, tempo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if abrir else Tween.EASE_IN)
	await tw.finished
	if not abrir:
		Jogo.som("porta_fechar", 0.0, 0.05)


func _ret(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2], a[3])


## O retângulo do pé encosta em parede?
func bloqueia(pe: Rect2) -> bool:
	if not limites.encloses(pe):
		return true
	for s in solidos:
		if pe.intersects(s):
			return true
	if _mascara:
		for p in [pe.position, pe.position + Vector2(pe.size.x, 0), pe.end, pe.position + Vector2(0, pe.size.y), pe.get_center()]:
			var x := int(p.x)
			var y := int(p.y)
			if x >= 0 and y >= 0 and x < _mascara.get_width() and y < _mascara.get_height():
				var c := _mascara.get_pixel(x, y)
				if c.a > 0.5 and c.get_luminance() < 0.9:
					return true
	return false


func ponto_em(r: Rect2) -> Dictionary:
	for p in pontos:
		if r.intersects(p.rect):
			return p
	return {}


## Porta à frente de quem anda na direção "v". Só entra se estiver indo
## na direção da porta (andar de lado encostado na parede não conta).
func porta_em(pos: Vector2, v: Vector2) -> Dictionary:
	for p in portas:
		if not p.rect.grow(4).has_point(pos + v * 6):
			continue
		var c: Vector2 = p.rect.get_center()
		var indo := false
		if c.y <= limites.position.y + 8:
			indo = v.y < 0
		elif c.y >= limites.end.y - 8:
			indo = v.y > 0
		elif c.x <= limites.position.x + 8:
			indo = v.x < 0
		elif c.x >= limites.end.x - 8:
			indo = v.x > 0
		else:
			indo = true
		if indo:
			return p
	return {}


func mostrar_debug(v: bool) -> void:
	debug = v
	_depuracao.queue_redraw()


func _draw() -> void:
	match _desenho:
		"sala_cairu": _sala_cairu()
		"corredor_cairu": _corredor_cairu()


func _desenhar_debug(c: Node2D) -> void:
	if not debug:
		return
	if _mascara_tex:
		c.draw_texture(_mascara_tex, Vector2.ZERO, Color(1, 1, 1, 0.45))
	c.draw_rect(limites, Color(0, 1, 0, 0.8), false, 1.0)
	for s in solidos:
		c.draw_rect(s, Color(1, 0, 0, 0.35))
	for p in pontos:
		c.draw_rect(p.rect, Color(1, 0.85, 0, 0.45))
	for p in portas:
		c.draw_rect(p.rect, Color(0, 0.6, 1, 0.45))


## "luzes": [{"x", "y", "w", "h", "cor": "#fff3c0", "forca": 0.2, "tipo": "luz" | "sombra" | "faixa"}]
## luz = brilho redondo e suave; sombra = mancha escura (embaixo de árvore, móvel);
## faixa = luz de janela entrando (retângulo inclinado e suave).
func _desenhar_luzes(c: Node2D, aditiva := false) -> void:
	for l in dados.get("luzes", []):
		var tipo: String = l.get("tipo", "luz")
		if (tipo != "sombra") != aditiva or tipo == "luz":
			continue
		var r := Rect2(l.get("x", 0), l.get("y", 0), l.get("w", 64), l.get("h", 64))
		var forca: float = l.get("forca", 0.2)
		var cor := Color(l.get("cor", "#000000" if tipo == "sombra" else "#fff3c0"))
		if tipo == "faixa":
			var inc: float = l.get("inclinacao", 30.0)
			var pts := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0),
				r.end + Vector2(inc, 0), Vector2(r.position.x + inc, r.end.y)])
			var cores := PackedColorArray([Color(cor, forca), Color(cor, forca), Color(cor, 0), Color(cor, 0)])
			c.draw_polygon(pts, cores)
		else:
			c.draw_texture_rect(_brilho, r, false, Color(cor, forca))


# ---------- desenhos em código (enquanto não tem imagem do mapa) ----------

func _chao(y0: int, cor1: Color, cor2: Color) -> void:
	for y in range(y0, int(tam.y), 16):
		for x in range(0, int(tam.x), 16):
			draw_rect(Rect2(x, y, 16, 16), cor1 if ((x + y) / 16) % 2 == 0 else cor2)


func _parede_cairu(altura: int) -> void:
	for y in range(0, altura, 48):
		for x in range(0, int(tam.x), 80):
			var azul := ((x / 80) + (y / 48)) % 2 == 0
			draw_rect(Rect2(x, y, 80, min(48, altura - y)), Color("2a2fa8") if azul else Color("f1f3fb"))
			if y + 28 < altura:
				draw_string(_fonte, Vector2(x + 20, y + 28), "Cairu", HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
					Color.WHITE if azul else Color("2a2fa8"))
	draw_rect(Rect2(0, altura - 6, tam.x, 6), Color("1b1f5e"))
	draw_rect(Rect2(0, altura, tam.x, 2), Color(0, 0, 0, 0.15))


func _porta(x: int, y: int) -> void:
	draw_rect(Rect2(x, y, 48, 62), Color("5a3a1e"))
	draw_rect(Rect2(x + 4, y + 4, 40, 58), Color("8a5a30"))
	draw_rect(Rect2(x + 8, y + 10, 32, 18), Color("a8d8ff"))
	draw_rect(Rect2(x + 34, y + 34, 4, 4), Color("ffd34e"))


func _bordas() -> void:
	draw_rect(Rect2(0, 0, 4, tam.y), Color("11152c"))
	draw_rect(Rect2(tam.x - 4, 0, 4, tam.y), Color("11152c"))
	draw_rect(Rect2(0, tam.y - 4, tam.x, 4), Color("11152c"))


func _sala_cairu() -> void:
	_chao(96, Color("e6e9f5"), Color("c9cfe6"))
	_parede_cairu(96)
	draw_rect(Rect2(196, 14, 248, 66), Color("8a90a8"))
	draw_rect(Rect2(200, 18, 240, 58), Color("fbfbf7"))
	draw_string(_fonte, Vector2(212, 36), "AULA DE HOJE:", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("2a2fa8"))
	draw_line(Vector2(212, 46), Vector2(330, 46), Color("d03a3a"))
	draw_line(Vector2(212, 56), Vector2(380, 56), Color("3a8a4a"))
	draw_line(Vector2(212, 64), Vector2(300, 64), Color("3a8a4a"))
	draw_rect(Rect2(196, 80, 248, 4), Color("6b7088"))
	draw_circle(Vector2(120, 34), 11, Color("2b2f3a"))
	draw_circle(Vector2(120, 34), 9, Color.WHITE)
	draw_line(Vector2(120, 34), Vector2(120, 27), Color("2b2f3a"), 2)
	draw_line(Vector2(120, 34), Vector2(125, 34), Color("d03a3a"))
	_porta(556, 30)
	_bordas()


func _corredor_cairu() -> void:
	_chao(96, Color("efe6d2"), Color("dccfb4"))
	_parede_cairu(96)
	_porta(296, 30)
	_porta(456, 30)
	# janelas
	for x in [60, 160, 380, 540]:
		draw_rect(Rect2(x, 20, 60, 44), Color("6b7088"))
		draw_rect(Rect2(x + 3, 23, 54, 38), Color("a8d8ff"))
		draw_rect(Rect2(x + 29, 23, 2, 38), Color("6b7088"))
	# bebedouro
	draw_rect(Rect2(584, 70, 22, 30), Color("c0c4d0"))
	draw_rect(Rect2(588, 74, 14, 6), Color("8a90a8"))
	_bordas()
