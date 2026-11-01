extends RefCounted
## Clima por mapa (portado do pixelfx, MIT: weather/fireflies, falling-leaves, fog, rain e scifi/glitch; ninguém roda o JS nem usa as folhas gigantes
## de weather). Tudo em ESPAÇO DE TELA, com quantidade fixa de partículas calculadas por fórmula (sem estado por partícula e sem nó por partícula):
##  - vagalumes: pontos que vagam, acendem e apagam no ritmo de cada um (alguns piscam duas vezes), com rastro e halo;
##  - folhas: balançam como pêndulo ao cair, viram de lado (mostram o verso claro) e pegam a rajada de vento;
##  - nevoa: dois bancos de névoa baixa a partir de uma textura de ruído pontilhado (gerada uma vez), deslizando em sentidos opostos;
##  - chuva: gotas finas inclinadas (duas profundidades, cada gota cai e renasce noutro x) e a respingada das gotas próximas;
##  - glitch: raras rajadas de 0,2 a 0,4 s (faixas deslocadas em vermelho e ciano, blocos e pixels mortos) com linhas de varredura, e uma barra fraca
##    que rola devagar. Segue a opção "Tremor e clarões" (0% não liga).
## Os efeitos de cada mapa estão em dados/v2_clima.json (um bloco por id de mapa; sem bloco, sem clima).
## Camada: um CanvasLayer 1 dentro do SubViewport do mundo, ACIMA do mundo e ABAIXO do brilho (camada 2, onde ficam os projéteis e as magias), então
## nada daqui cobre um projétil; o alfa de cada efeito tem um teto (ALFA_TETO) para não apagar o inimigo. Dois nós de desenho (normal e aditivo),
## cada um desenha tudo numa chamada por quadro. Perfil: o mundo manda `definir_fator` (Baixo 0 = desligado e invisível; Médio 0,5 = metade da
## quantidade; Alto 1).

const LARG := 960.0
const ALT := 540.0
const MAX_VAGA := 24
const MAX_FOLHA := 16
const MAX_CHUVA := 140
const CICLO := 12.0  # segundos de um ciclo dos vagalumes (como no pixelfx: ciclos inteiros)
const INCLINACAO := 0.2  # a chuva cai para a esquerda: x anda 0,2 px por px de queda
const TEXTURA_W := 320
const TEXTURA_H := 56
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
# teto do alfa de cada efeito (o que o JSON pedir passa por aqui): névoa e glitch cobrem área, então são os mais baixos
const ALFA_TETO := {"vagalumes": 1.0, "folhas": 0.8, "nevoa": 0.3, "chuva": 0.45, "glitch": 0.4}

var fator := 1.0  # 0 desliga tudo (perfil Baixo), 0,5 metade, 1 inteiro
var ativo := false  # fator > 0 e o mapa tem algum efeito
var id_mapa := ""
var camada: CanvasLayer
var cfg := {}  # o bloco do mapa em dados/v2_clima.json
var tempo := 0.0
var rajadas := 0  # quantas rajadas de glitch começaram (testes)
var em_rajada := false
var desenhado := {"vagalumes": 0, "folhas": 0, "nevoa": 0, "chuva": 0, "respingos": 0, "glitch": 0}  # primitivas do último quadro (testes)
var quadros_desenhados := 0

var _normal: Node2D
var _aditivo: Node2D
var _rng := RandomNumberGenerator.new()
var _tex_halo: Texture2D
var _tex_nevoa: Texture2D
var _tex_linhas: Texture2D
# vagalumes (vetores fixos de MAX_VAGA)
var _vg_n := 0
var _vg_ef := 0
var _vg_cor := Color(0.84, 1.0, 0.35)
var _vg_alfa := 0.9
var _vg := PackedFloat32Array()  # 12 floats por vagalume: cx, cy, ax, ay, w1, w2, p1, p2, periodo, fase, dois, prof
# folhas
var _fl_n := 0
var _fl_ef := 0
var _fl_cores := PackedColorArray()
var _fl_alfa := 0.6
var _fl_vel := 1.0
var _fl := PackedFloat32Array()  # 8 floats por folha: dur, fase, w, ph, amp, tam, forma, cor
var _fl_pts := PackedVector2Array()
# névoa
var _nv_on := false
var _nv_cor := Color(0.62, 0.7, 0.76)
var _nv_alfa := 0.15
var _nv_vel := 12.0
# chuva
var _ch_n := 0
var _ch_ef := 0
var _ch_cor := Color(0.72, 0.82, 1.0)
var _ch_alfa := 0.3
var _ch_vel := 1.0
var _ch := PackedFloat32Array()  # 5 floats por gota: vel, comprimento, fim (y onde acaba), fase, perto
var _ch_longe := PackedVector2Array()
var _ch_perto := PackedVector2Array()
# glitch
var _gl_on := false
var _gl_alfa := 0.12
var _gl_linhas := 0.05
var _gl_dur := 0.3
var _gl_min := 9.0
var _gl_max := 18.0
var _gl_prox := 0.0
var _gl_ini := 0.0
var _gl_dura := 0.3
var _gl_forca := 0.0


## `pai`: o SubViewport do mundo (o clima entra como CanvasLayer 1). `tex_brilho`: opcional, o halo redondo do jogo (sem ele gera um).
func montar(pai: Node, id: String, tex_brilho: Texture2D = null) -> void:
	id_mapa = id
	var tudo: Dictionary = Dados.json("v2_clima")
	cfg = tudo.get("mapas", {}).get(id, tudo.get("padrao", {}))
	_rng.seed = 20261031
	camada = CanvasLayer.new()
	camada.layer = 1
	_normal = Node2D.new()
	_normal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_normal.draw.connect(_desenhar_normal)
	camada.add_child(_normal)
	_aditivo = Node2D.new()
	_aditivo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_aditivo.material = mat
	_aditivo.draw.connect(_desenhar_aditivo)
	camada.add_child(_aditivo)
	pai.add_child(camada)
	_ler()
	_tex_halo = tex_brilho if tex_brilho != null else _gerar_halo()
	if _nv_on:
		_tex_nevoa = _gerar_nevoa()
	if _gl_on:
		_tex_linhas = _gerar_linhas()
	_gl_prox = _rng.randf_range(_gl_min * 0.5, _gl_min)
	definir_fator(fator)


## 0 = desligado (perfil Baixo), 0,5 = Médio, 1 = Alto. Muda a quantidade na hora, sem criar nada.
func definir_fator(f: float) -> void:
	fator = clampf(f, 0.0, 1.0)
	_vg_ef = mini(ceili(float(_vg_n) * fator), MAX_VAGA)
	_fl_ef = mini(ceili(float(_fl_n) * fator), MAX_FOLHA)
	_ch_ef = mini(ceili(float(_ch_n) * fator), MAX_CHUVA)
	_ch_longe.resize(_ch_ef * 2)
	_ch_perto.resize(_ch_ef * 2)
	ativo = fator > 0.0 and (_vg_ef > 0 or _fl_ef > 0 or _ch_ef > 0 or _nv_on or _gl_on)
	if camada != null:
		camada.visible = ativo
	if not ativo:
		em_rajada = false
		_gl_forca = 0.0


## Quantos itens de cada efeito estão ligados agora (testes).
func contagem() -> Dictionary:
	return {"vagalumes": _vg_ef, "folhas": _fl_ef, "chuva": _ch_ef, "nevoa": 1 if _nv_on and ativo else 0, "glitch": 1 if _gl_on and ativo else 0}


## Começa uma rajada de glitch já (testes e fotos); respeita "Tremor e clarões". true se começou.
func disparar_rajada() -> bool:
	if not ativo or not _gl_on or _clarao() <= 0.0:
		return false
	_iniciar_rajada()
	return true


func atualizar(dt: float) -> void:
	if not ativo:
		return
	tempo += dt
	if _gl_on:
		_passo_glitch()
	_normal.queue_redraw()
	_aditivo.queue_redraw()


# ------------------------------------------------------------------ dados


func _ler() -> void:
	var v: Dictionary = cfg.get("vagalumes", {})
	_vg_n = clampi(int(v.get("n", 0)), 0, MAX_VAGA)
	_vg_cor = _cor(v.get("cor", null), _vg_cor)
	_vg_alfa = clampf(float(v.get("alfa", _vg_alfa)), 0.0, ALFA_TETO.vagalumes)
	_semear_vagalumes()
	var f: Dictionary = cfg.get("folhas", {})
	_fl_n = clampi(int(f.get("n", 0)), 0, MAX_FOLHA)
	_fl_alfa = clampf(float(f.get("alfa", _fl_alfa)), 0.0, ALFA_TETO.folhas)
	_fl_vel = clampf(float(f.get("vel", 1.0)), 0.3, 3.0)
	for c in f.get("cores", ["#c8621e", "#f0982e", "#b8302a"]):
		_fl_cores.append(_cor(c, Color(0.78, 0.38, 0.12)))
	_fl_pts.resize(8)
	_semear_folhas()
	var n: Dictionary = cfg.get("nevoa", {})
	_nv_on = not n.is_empty() and float(n.get("alfa", 0.15)) > 0.0
	_nv_cor = _cor(n.get("cor", null), _nv_cor)
	_nv_alfa = clampf(float(n.get("alfa", _nv_alfa)), 0.0, ALFA_TETO.nevoa)
	_nv_vel = float(n.get("vel", _nv_vel))
	var c: Dictionary = cfg.get("chuva", {})
	_ch_n = clampi(int(c.get("n", 0)), 0, MAX_CHUVA)
	_ch_cor = _cor(c.get("cor", null), _ch_cor)
	_ch_alfa = clampf(float(c.get("alfa", _ch_alfa)), 0.0, ALFA_TETO.chuva)
	_ch_vel = clampf(float(c.get("vel", 1.0)), 0.4, 2.5)
	_semear_chuva()
	var g: Dictionary = cfg.get("glitch", {})
	_gl_on = not g.is_empty()
	_gl_alfa = clampf(float(g.get("alfa", _gl_alfa)), 0.0, ALFA_TETO.glitch)
	_gl_linhas = clampf(float(g.get("linhas", _gl_linhas)), 0.0, ALFA_TETO.glitch)
	_gl_dur = clampf(float(g.get("dur", _gl_dur)), 0.1, 0.6)
	var inter: Array = g.get("intervalo", [9.0, 18.0])
	_gl_min = maxf(float(inter[0]), 2.0)
	_gl_max = maxf(float(inter[1]), _gl_min)


static func _cor(v: Variant, padrao: Color) -> Color:
	if v is String:
		return Color(str(v))
	if v is Array and v.size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]), float(v[3]) if v.size() > 3 else 1.0)
	return padrao


## Hash em [0, 1): o mesmo (a, b, c) dá sempre o mesmo número, então o desenho é uma fórmula do tempo (nada de estado por partícula).
static func _r(a: int, b: int, c: int) -> float:
	return fposmod(sin(float(a) * 12.9898 + float(b) * 78.233 + float(c) * 37.719) * 43758.5453, 1.0)


static func _suave(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _clarao() -> float:
	var f = Config.g("tremor_clarao")
	return 1.0 if f == null else clampf(float(f) / 100.0, 0.0, 1.0)


func _semear_vagalumes() -> void:
	_vg.resize(MAX_VAGA * 12)
	for i in MAX_VAGA:
		var prof := 0 if i % 3 == 0 else (1 if i % 3 == 1 else 2)  # 0 longe, 1 meio, 2 perto
		var k := [0.5, 0.8, 1.0][prof] as float
		var o := i * 12
		_vg[o] = 40.0 + _r(i, 1, 1) * (LARG - 80.0)
		_vg[o + 1] = 70.0 + _r(i, 2, 1) * (ALT - 150.0)
		_vg[o + 2] = (22.0 + _r(i, 3, 1) * 40.0) * k
		_vg[o + 3] = (12.0 + _r(i, 4, 1) * 24.0) * k
		_vg[o + 4] = TAU * (1.0 + floorf(_r(i, 5, 1) * 2.0)) / CICLO
		_vg[o + 5] = TAU * (1.0 + floorf(_r(i, 6, 1) * 3.0)) / CICLO
		_vg[o + 6] = _r(i, 7, 1) * TAU
		_vg[o + 7] = _r(i, 8, 1) * TAU
		_vg[o + 8] = CICLO / (3.0 + floorf(_r(i, 9, 1) * 4.0))
		_vg[o + 9] = _r(i, 10, 1)
		_vg[o + 10] = 1.0 if _r(i, 11, 1) < 0.35 else 0.0
		_vg[o + 11] = float(prof)


func _semear_folhas() -> void:
	_fl.resize(MAX_FOLHA * 8)
	for i in MAX_FOLHA:
		var o := i * 8
		_fl[o] = 9.0 + _r(i, 21, 2) * 6.0  # segundos para cruzar a tela
		_fl[o + 1] = _r(i, 22, 2)
		_fl[o + 2] = 1.7 + _r(i, 23, 2) * 1.2  # velocidade do balanço
		_fl[o + 3] = _r(i, 24, 2) * TAU
		_fl[o + 4] = (14.0 if i % 3 == 0 else 8.0) + _r(i, 25, 2) * 10.0
		_fl[o + 5] = (5.8 if i % 3 == 0 else 4.2) + _r(i, 26, 2) * 1.6
		_fl[o + 6] = 0.0 if _r(i, 27, 2) < 0.65 else 1.0  # 0 faia (oval), 1 salgueiro (fina)
		_fl[o + 7] = floorf(_r(i, 28, 2) * 3.0)


func _semear_chuva() -> void:
	_ch.resize(MAX_CHUVA * 5)
	for i in MAX_CHUVA:
		var o := i * 5
		var perto := i % 5 < 2
		_ch[o] = (440.0 + _r(i, 31, 3) * 120.0) if perto else (270.0 + _r(i, 31, 3) * 60.0)
		_ch[o + 1] = 9.0 if perto else 4.0
		_ch[o + 2] = ALT * (0.5 + _r(i, 32, 3) * 0.5) if perto else ALT * (0.3 + _r(i, 32, 3) * 0.7)
		_ch[o + 3] = _r(i, 33, 3)
		_ch[o + 4] = 1.0 if perto else 0.0


# ------------------------------------------------------------------ texturas (geradas uma vez na montagem)


func _gerar_halo() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## Ruído de valor com 3 oitavas, emendado nas laterais (a textura anda em círculo), perfil vertical (fino em cima, some embaixo), limiares
## de 3 tons com pontilhado Bayer e uma crista clara onde o banco começa. Tons em cinza e alfa; a cor e a força vêm do modulate no desenho.
func _gerar_nevoa() -> Texture2D:
	var cw := PackedInt32Array([10, 20, 40])
	var ch := PackedInt32Array([3, 6, 12])
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var reticulas: Array[PackedFloat32Array] = []
	for o in 3:
		var a := PackedFloat32Array()
		a.resize(cw[o] * (ch[o] + 1))
		for k in a.size():
			a[k] = rng.randf()
		reticulas.append(a)
	var campo := PackedFloat32Array()
	campo.resize(TEXTURA_W * TEXTURA_H)
	for y in TEXTURA_H:
		var v := float(y) / float(TEXTURA_H - 1)
		var perfil := _suave(0.0, 0.45, v) * (1.0 - _suave(0.65, 1.0, v))
		for x in TEXTURA_W:
			var n := 0.0
			var amp := 0.5
			var soma := 0.0
			for o in 3:
				var gx := float(x) / float(TEXTURA_W) * float(cw[o])
				var gy := v * float(ch[o])
				var ix := int(gx)
				var iy := mini(int(gy), ch[o] - 1)
				var fx := _suave(0.0, 1.0, gx - float(ix))
				var fy := _suave(0.0, 1.0, gy - float(iy))
				var a: PackedFloat32Array = reticulas[o]
				var i0 := iy * cw[o]
				var i1 := (iy + 1) * cw[o]
				var x0 := ix % cw[o]
				var x1 := (ix + 1) % cw[o]
				n += lerpf(lerpf(a[i0 + x0], a[i0 + x1], fx), lerpf(a[i1 + x0], a[i1 + x1], fx), fy) * amp
				soma += amp
				amp *= 0.5
			n /= soma
			var nn := clampf((n - 0.5) * 2.6 + 0.5, 0.0, 1.0) - 0.5
			campo[y * TEXTURA_W + x] = 0.0 if perfil <= 0.01 else (perfil * 0.72 + nn * 0.95) * (0.6 + 0.5 * perfil)
	var limiar := [0.3, 0.5, 0.7]
	var tons := [0.72, 0.86, 1.0]
	var alfas := [0.45, 0.7, 0.95]
	var im := Image.create(TEXTURA_W, TEXTURA_H, false, Image.FORMAT_RGBA8)
	for y in TEXTURA_H:
		for x in TEXTURA_W:
			var f: float = campo[y * TEXTURA_W + x]
			var th := float(BAYER[(y % 4) * 4 + (x % 4)]) / 16.0 * 0.06
			var banda := -1
			if f > (limiar[2] as float) + th:
				banda = 2
			elif f > (limiar[1] as float) + th:
				banda = 1
			elif f > (limiar[0] as float) + th:
				banda = 0
			if banda < 0:
				im.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var cima: float = campo[(y - 1) * TEXTURA_W + x] if y > 0 else 0.0
			if banda >= 1 and cima < (limiar[banda] as float):
				im.set_pixel(x, y, Color(1, 1, 1, 1))  # a crista iluminada, 1 px, onde o banco encontra névoa mais fina
			else:
				var g := tons[banda] as float
				im.set_pixel(x, y, Color(g, g, g, alfas[banda] as float))
	return ImageTexture.create_from_image(im)


## Uma linha escura a cada 3 px (1x3), ladrilhada na tela inteira durante a rajada.
func _gerar_linhas() -> Texture2D:
	var im := Image.create(1, 3, false, Image.FORMAT_RGBA8)
	im.set_pixel(0, 0, Color(0, 0, 0, 1))
	im.set_pixel(0, 1, Color(0, 0, 0, 0))
	im.set_pixel(0, 2, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(im)


# ------------------------------------------------------------------ glitch (estado)


func _passo_glitch() -> void:
	if em_rajada:
		if tempo - _gl_ini >= _gl_dura:
			em_rajada = false
			_gl_forca = 0.0
	elif tempo >= _gl_prox:
		if _clarao() > 0.0:
			_iniciar_rajada()
		else:
			_gl_prox = tempo + _rng.randf_range(_gl_min, _gl_max)  # "Tremor e clarões" em 0%: adia sem acender


func _iniciar_rajada() -> void:
	em_rajada = true
	_gl_ini = tempo
	_gl_dura = _gl_dur * _rng.randf_range(0.7, 1.3)
	_gl_forca = _rng.randf_range(0.5, 1.0)
	rajadas += 1
	_gl_prox = tempo + _gl_dura + _rng.randf_range(_gl_min, _gl_max)


# ------------------------------------------------------------------ desenho


func _desenhar_normal() -> void:
	quadros_desenhados += 1
	desenhado.nevoa = 0
	desenhado.chuva = 0
	desenhado.respingos = 0
	desenhado.folhas = 0
	desenhado.glitch = 0
	if not ativo:
		return
	if _nv_on:
		_desenhar_nevoa(_normal)
	if _ch_ef > 0:
		_desenhar_chuva(_normal)
	if _fl_ef > 0:
		_desenhar_folhas(_normal)
	if _gl_on and em_rajada:
		_desenhar_linhas(_normal)


func _desenhar_aditivo() -> void:
	desenhado.vagalumes = 0
	if not ativo:
		return
	if _vg_ef > 0:
		_desenhar_vagalumes(_aditivo)
	if _gl_on:
		_desenhar_glitch(_aditivo)


func _desenhar_nevoa(no: Node2D) -> void:
	for b in 2:
		var larg := LARG if b == 0 else 640.0
		var alt := 168.0 if b == 0 else 112.0
		var y := ALT - (175.0 if b == 0 else 118.0)
		var vel := _nv_vel * (1.0 if b == 0 else -0.7)
		var x := -fposmod(tempo * vel + float(b) * 300.0, larg)
		var cor := Color(_nv_cor, _nv_alfa * (1.0 if b == 0 else 0.75))
		while x < LARG:
			no.draw_texture_rect(_tex_nevoa, Rect2(roundf(x), y, larg, alt), false, cor)
			desenhado.nevoa += 1
			x += larg


func _desenhar_chuva(no: Node2D) -> void:
	var hip := sqrt(INCLINACAO * INCLINACAO + 1.0)
	var ux := INCLINACAO / hip
	var uy := 1.0 / hip
	var il := 0
	var ip := 0
	for i in _ch_ef:
		var o := i * 5
		var vel: float = _ch[o] * _ch_vel
		var comp: float = _ch[o + 1]
		var fim: float = _ch[o + 2]
		var ciclo := (fim + comp) / (vel * 0.85)
		var q := tempo / ciclo + _ch[o + 3]
		var k := int(floorf(q))
		var u := q - float(k)
		var perto: bool = _ch[o + 4] > 0.5
		var xe := _r(i, k, 2) * (LARG + 120.0) - 20.0
		var cabeca := Vector2(-10.0, -10.0)
		var cauda := cabeca
		if u < 0.85:
			var y := -comp + (fim + comp) * (u / 0.85)
			cabeca = Vector2(roundf(xe + (fim - y) * INCLINACAO), roundf(y))
			cauda = cabeca + Vector2(ux, -uy) * comp
		elif perto:
			# a respingada: três pontinhos que se afastam do chão onde a gota caiu
			var ph := (u - 0.85) / 0.15
			var a := _ch_alfa * (1.0 - ph)
			var w := 1.0 + floorf(ph * 3.0)
			var rx := roundf(xe)
			var ry := roundf(fim)
			var c := Color(_ch_cor, a)
			no.draw_rect(Rect2(rx - w - 1.0, ry, 1, 1), c)
			no.draw_rect(Rect2(rx + w, ry, 1, 1), c)
			no.draw_rect(Rect2(rx, ry - 1.0, 1, 1), c)
			desenhado.respingos += 3
		if perto:
			_ch_perto[ip] = cauda
			_ch_perto[ip + 1] = cabeca
			ip += 2
		else:
			_ch_longe[il] = cauda
			_ch_longe[il + 1] = cabeca
			il += 2
	if il > 0:
		no.draw_multiline(_ch_longe.slice(0, il) if il < _ch_longe.size() else _ch_longe, Color(_ch_cor, _ch_alfa * 0.55), 1.0)
	if ip > 0:
		no.draw_multiline(_ch_perto.slice(0, ip) if ip < _ch_perto.size() else _ch_perto, Color(_ch_cor, _ch_alfa), 1.0)
	desenhado.chuva = (il + ip) / 2


## O pêndulo do pixelfx: a queda acelera no fundo de cada arco (∫|cos|), a inclinação segue o balanço, o giro achata a folha (o verso, claro,
## aparece depois de ficar de lado) e a rajada de vento empurra todas.
func _desenhar_folhas(no: Node2D) -> void:
	for i in _fl_ef:
		var o := i * 8
		var dur: float = _fl[o] / _fl_vel
		var q := tempo / dur + _fl[o + 1]
		var k := int(floorf(q))
		var a := (q - float(k)) * dur
		var w: float = _fl[o + 2]
		var ph: float = _fl[o + 3]
		var amp: float = _fl[o + 4]
		var tam: float = _fl[o + 5]
		var x0 := _r(i, k, 5) * (LARG + 100.0) - 60.0
		var total := _caida(w * dur + ph, ph, w, dur)
		var y := -20.0 + (ALT + 40.0) * _caida(w * a + ph, ph, w, a) / total
		var nasc := tempo - a
		var x := x0 + 7.0 * a + sin(w * a + ph) * amp + (_vento(tempo) - _vento(nasc)) * 0.7
		var inclina := cos(w * a + ph) * 0.75
		var rapido := 5.0 if _r(i, k, 11) < 0.3 else 1.2
		var vira := cos(_r(i, k, 10) * TAU + a * rapido)
		_folha(no, Vector2(roundf(x), roundf(y)), tam, inclina, vira, _fl[o + 6] > 0.5, _fl_cores[int(_fl[o + 7]) % _fl_cores.size()])
		desenhado.folhas += 1


static func _vento(t: float) -> float:
	return 16.0 * sin(TAU * t / 10.0 - 1.2) + 5.0 * sin(TAU * 3.0 * t / 10.0)


## ∫|cos| a partir do instante 0 do pêndulo, escalado: quanto a folha já desceu na idade `a` (a queda acelera no fundo de cada arco).
static func _caida(th: float, ph: float, w: float, a: float) -> float:
	return 0.45 * a + 0.9 * (_hc(th) - _hc(ph)) / w


static func _hc(th: float) -> float:
	var k := floorf((th + PI / 2.0) / PI)
	return 2.0 * k + 1.0 + sin(th - k * PI)


func _folha(no: Node2D, c: Vector2, tam: float, ang: float, vira: float, fina: bool, cor: Color) -> void:
	var verso := vira < -0.25
	var fs := 0.35 + 0.65 * absf(vira)
	var largura := tam * (0.45 if fina else 0.9) * fs
	var cs := cos(ang)
	var sn := sin(ang)
	var cor_f := cor.lerp(Color("c8b49c"), 0.4) if verso else cor
	cor_f.a = _fl_alfa
	# oval pontuda: us em -1, -0,5, 0, 0,5, 1 (a largura some nas pontas)
	var us := [-1.0, -0.5, 0.0, 0.5, 1.0, 0.5, 0.0, -0.5]
	var vs := [0.0, 1.0, 1.0, 1.0, 0.0, -1.0, -1.0, -1.0]
	for j in 8:
		var u: float = us[j]
		var v: float = vs[j] * sqrt(maxf(0.0, 1.0 - u * u)) * largura
		var lx := u * tam
		_fl_pts[j] = c + Vector2(lx * cs - v * sn, lx * sn + v * cs)
	no.draw_colored_polygon(_fl_pts, cor_f)


func _desenhar_vagalumes(no: Node2D) -> void:
	for i in _vg_ef:
		var o := i * 12
		var prof := int(_vg[o + 11])
		var u := tempo / _vg[o + 8] + _vg[o + 9]
		var brilho := _pulso(u)
		if _vg[o + 10] > 0.5:
			brilho = maxf(brilho, _pulso(u - 0.22) * 0.8)
		if brilho < 0.05:
			continue
		var p := _pos_vagalume(o, tempo)
		var cor := Color(_vg_cor, _vg_alfa)
		var claro := Color(_vg_cor.lerp(Color.WHITE, 0.6), _vg_alfa)
		if prof > 0 and brilho > 0.3:
			for j in 1 if prof == 1 else 4:  # rastro de luz onde acabou de estar
				var tr := _pos_vagalume(o, tempo - float(j) * 0.06)
				no.draw_rect(Rect2(roundf(tr.x), roundf(tr.y), 1, 1), Color(_vg_cor, (brilho - 0.3) * (1.0 - float(j) / 5.0) * _vg_alfa))
		var raio := [6.0, 11.0, 24.0][prof] as float
		no.draw_texture_rect(_tex_halo, Rect2(roundf(p.x) - raio, roundf(p.y) - raio, raio * 2.0, raio * 2.0), false, Color(_vg_cor, 0.5 * brilho * _vg_alfa))
		var lado := 1.0 if prof == 0 else 2.0
		no.draw_rect(Rect2(roundf(p.x), roundf(p.y), lado, lado), claro if brilho > 0.5 else cor)
		if prof == 2 and brilho > 0.7:
			var b := (brilho - 0.7) * 3.0
			var c := Color(_vg_cor, b * _vg_alfa)
			no.draw_rect(Rect2(roundf(p.x) - 2.0, roundf(p.y), 1, 2), c)
			no.draw_rect(Rect2(roundf(p.x) + 3.0, roundf(p.y), 1, 2), c)
			no.draw_rect(Rect2(roundf(p.x), roundf(p.y) - 2.0, 2, 1), c)
			no.draw_rect(Rect2(roundf(p.x), roundf(p.y) + 3.0, 2, 1), c)
		desenhado.vagalumes += 1


func _pos_vagalume(o: int, t: float) -> Vector2:
	var ax: float = _vg[o + 2]
	var ay: float = _vg[o + 3]
	return Vector2(
		_vg[o] + ax * sin(_vg[o + 4] * t + _vg[o + 6]) + 0.35 * ax * sin(_vg[o + 5] * t * 2.3 + _vg[o + 7]),
		_vg[o + 1] + ay * sin(_vg[o + 5] * t + _vg[o + 7]) + 0.35 * ay * sin(_vg[o + 4] * t * 1.7 + _vg[o + 6])
	)


## O ritmo do pixelfx: sobe rápido, segura, apaga devagar, escuro.
static func _pulso(v: float) -> float:
	v = fposmod(v, 1.0)
	if v < 0.06:
		return v / 0.06
	if v < 0.14:
		return 1.0
	if v < 0.4:
		return 1.0 - (v - 0.14) / 0.26
	return 0.0


## Linhas de varredura: só durante a rajada, com a força dela.
func _desenhar_linhas(no: Node2D) -> void:
	var cl := _clarao()
	if cl <= 0.0:
		return
	var env := sin(clampf((tempo - _gl_ini) / _gl_dura, 0.0, 1.0) * PI)
	no.draw_texture_rect(_tex_linhas, Rect2(0, 0, LARG, ALT), true, Color(1, 1, 1, _gl_linhas * _gl_forca * env * cl))
	desenhado.glitch += 1


func _desenhar_glitch(no: Node2D) -> void:
	var cl := _clarao()
	if cl <= 0.0:
		return
	var cian := Color(0.18, 0.95, 1.0)
	var rosa := Color(1.0, 0.18, 0.39)
	# a barra fraca que rola devagar pelo sinal
	var by := -20.0 + (ALT + 40.0) * fposmod(tempo / 7.0, 1.0)
	no.draw_rect(Rect2(0, roundf(by), LARG, 10), Color(cian, _gl_alfa * 0.3 * cl))
	desenhado.glitch += 1
	if not em_rajada:
		return
	var f := int((tempo - _gl_ini) * 30.0)  # os quadros da rajada são a 30 fps: o glitch "estala" em vez de deslizar
	var s := rajadas * 7
	var k := _gl_forca
	var al := _gl_alfa * k * cl
	var rasgos := mini(1 + int(_r(f, 3, s) * 4.0 * k), 5)
	for i in rasgos:
		var y := floorf(_r(f, 4, s + i) * ALT)
		var h := 2.0 + floorf(_r(f, 5, s + i) * 8.0)
		var x0 := floorf(_r(f, 6, s + i) * LARG * 0.5)
		var w := minf(LARG - x0, 200.0 + _r(f, 7, s + i) * 600.0)
		var dx := (1.0 + floorf(_r(f, 8, s + i) * 3.0 * k)) * (-1.0 if _r(f, 9, s + i) < 0.5 else 1.0)
		no.draw_rect(Rect2(x0 - dx, y, w, h), Color(rosa, al))
		no.draw_rect(Rect2(x0 + dx, y, w, h), Color(cian, al))
		desenhado.glitch += 2
	var cores := [Color.WHITE, rosa, cian]
	var blocos := mini(2 + int(_r(f, 20, s) * 5.0 * k), 7)
	for i in blocos:
		var bw := 4.0 + floorf(_r(f, 21, s + i) * 20.0)
		var bh := 2.0 + floorf(_r(f, 22, s + i) * 4.0)
		var bx := floorf(_r(f, 23, s + i) * (LARG - bw))
		var by2 := floorf(_r(f, 24, s + i) * (ALT - bh))
		no.draw_rect(Rect2(bx, by2, bw, bh), Color(cores[int(_r(f, 25, s + i) * 3.0) % 3] as Color, minf(al * 2.5, ALFA_TETO.glitch)))
		desenhado.glitch += 1
	# pixels mortos: nascem na rajada, derivam de lado e piscam até sumir
	for i in 8:
		var idade := float(f)
		var px := _r(s, i, 2) * LARG + idade * (1.0 + _r(s, i, 5) * 2.0) * (-1.0 if _r(s, i, 4) < 0.5 else 1.0)
		var py := _r(s, i, 3) * ALT - idade * 0.5
		if (f + i) % 3 != 0:
			no.draw_rect(Rect2(roundf(px), roundf(py), 2, 2), Color(cores[i % 3] as Color, minf(al * 3.0, ALFA_TETO.glitch)))
			desenhado.glitch += 1
