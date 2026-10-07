extends Node2D
const Perf := preload("res://scripts/hordas/perf.gd")
## Números de dano e partículas (pedacinhos quando um vírus explode).

const MAX_NUMEROS := 70
const MAX_PARTICULAS := 400
## Números de dano agrupados (HoloCure / 20MTD: um número só em vez de uma chuva deles): acertos a até RAIO_JUNTA px
## de um número nascido há menos de JANELA s SOMAM nele (o número cresce e a cor de crítico vence). Com 500 vírus e
## uma arma de área isso é a diferença entre 40 textos por segundo e 6.
const JANELA := 0.15
const RAIO_JUNTA := 28.0
const VIDA := 0.6
const VIDA_CRIT := 0.9

## ---- Golpes com peso (combate estilo Dimraeth): tudo brilha por cima (mistura aditiva) ----
const MAX_CORTES := 32
const MAX_IMPACTOS := 48
const MAX_FAISCAS := 260
const IMPACTOS_QUADRO := 6       # estrelas de impacto novas por quadro: arma de área acerta 40 de uma vez
const CORTE_ACHATA := 0.8        # câmera em 3/4: o arco do golpe deita um pouco no chão
const CORTE_SEG := 14            # pedaços da meia-lua
const IMPACTO_VIDA := 0.13
const POP := 0.07                # s do "soco" do número ao nascer ou crescer (tamanho dobra e volta, sempre inteiro)

var numeros: Array = []      # {pos, valor, txt, t, idade, cor, base, tam, crit, pop, vy}
var particulas: Array = []   # {pos, vel, t, cor, tam}
var cortes: Array = []       # {pos, ang, arco, raio, larg, cor, t, dur, lado}
var impactos: Array = []     # {pos, cor, t, raios[], tam}
var faiscas: Array = []      # {pos, vel, t, cor}
var luzes: Array = []        # halos deste quadro {pos, raio, cor}: quem ilumina chama luz() todo quadro; some depois do desenho
const MAX_LUZES := 96
static var _tex_luz: Texture2D   # um degradê radial só, pra todo halo (um draw_texture_rect por luz)
var _vis := Rect2()              # a tela em coordenadas do mundo, do último atualizar (luz fora dela nem entra)
var _brilho := Node2D.new()  # filho aditivo, desenhado ATRÁS dos números (show_behind_parent)
var _impactos_quadro := 0


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_brilho.material = m
	_brilho.show_behind_parent = true
	_brilho.draw.connect(_draw_brilho)
	add_child(_brilho)
	if _tex_luz == null:
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
		_tex_luz = t


## Halo de luz neste quadro (mistura aditiva, achatado no chão). `cor.a` = força. Chame todo quadro enquanto brilhar.
func luz(pos: Vector2, raio: float, cor: Color) -> void:
	if luzes.size() >= MAX_LUZES or (_vis.has_area() and not _vis.grow(raio).has_point(pos)):
		return
	luzes.append([pos, raio, cor])


## Meia-lua de corte: a lâmina varre de um lado ao outro do arco e o rabo vem comendo atrás (não some por igual).
## `ang` = meio do arco; `lado` = 1 varre no sentido horário, -1 no anti-horário.
func corte(pos: Vector2, ang: float, arco: float, raio: float, cor: Color, larg := -1.0, dur := 0.16, lado := 1.0) -> void:
	if cortes.size() >= MAX_CORTES:
		cortes.pop_front()
	cortes.append({"pos": pos, "ang": ang, "arco": arco, "raio": raio, "larg": raio * 0.3 if larg < 0.0 else larg,
		"cor": cor, "t": 0.0, "dur": dur, "lado": signf(lado) if lado != 0.0 else 1.0})


## Estrela de impacto no ponto do acerto: raios finos que estouram pra fora e um clarão no meio.
func impacto(pos: Vector2, cor := Color(0.75, 0.9, 1.0), forte := false) -> void:
	if _impactos_quadro >= IMPACTOS_QUADRO or (_vis.has_area() and not _vis.grow(24.0).has_point(pos)):
		return
	_impactos_quadro += 1
	if impactos.size() >= MAX_IMPACTOS:
		impactos.pop_front()
	var raios: Array = []
	var n := 6 if forte else 4
	var a0 := randf() * TAU
	for i in n:
		raios.append(Vector2(a0 + TAU * i / n + randf_range(-0.35, 0.35), randf_range(0.6, 1.0)))   # x = ângulo, y = comprimento
	impactos.append({"pos": pos, "cor": cor, "t": 0.0, "raios": raios, "tam": 22.0 if forte else 14.0})
	faisca(pos, Vector2.ZERO, cor, 4 if forte else 2)


## Faíscas em risquinho (rastro na direção do voo). `dir` zero = pra todo lado.
func faisca(pos: Vector2, dir: Vector2, cor: Color, n := 3, forca := 170.0) -> void:
	for i in n:
		if faiscas.size() >= MAX_FAISCAS:
			faiscas.pop_front()
		var a: float = dir.angle() + randf_range(-0.7, 0.7) if dir != Vector2.ZERO else randf() * TAU
		faiscas.append({"pos": pos, "vel": Vector2.from_angle(a) * randf_range(forca * 0.4, forca), "t": randf_range(0.14, 0.28), "cor": cor})



func numero(pos: Vector2, valor: float, cor := Color.WHITE, crit := false) -> void:
	if not Config.v("numeros_dano"):   # opção "Números de dano"
		return
	# a lista está em ordem de nascimento: só os últimos (mais novos que a janela) podem receber a soma
	for i in range(numeros.size() - 1, -1, -1):
		var n: Dictionary = numeros[i]
		if n.idade >= JANELA:
			break
		if n.base == cor:   # só soma com a mesma "família" (dano causado, dano recebido...); crítico entra na soma e pinta o total
			if n.pos.distance_to(pos) <= RAIO_JUNTA:
				n.valor += valor
				n.txt = texto(n.valor, n.crit or crit)
				n.pop = POP   # cresceu: dá outro soco
				if crit and not n.crit:
					n.crit = true
					n.cor = Color(1, 0.9, 0.3)
					n.tam = 16
					n.t = VIDA_CRIT
				return
	if numeros.size() >= MAX_NUMEROS:
		numeros.pop_front()
	numeros.append({"pos": pos + Vector2(randf_range(-6, 6), -10), "valor": valor, "txt": texto(valor, crit), "idade": 0.0, "crit": crit, "base": cor,
		"t": VIDA_CRIT if crit else VIDA, "cor": Color(1, 0.9, 0.3) if crit else cor, "tam": 16 if crit else 8,
		"pop": POP, "vy": -90.0 if crit else -70.0})


static func texto(valor: float, crit: bool) -> String:
	return str(int(round(valor))) + ("!" if crit else "")


func explodir(pos: Vector2, cor: Color, n := 6, forca := 80.0) -> void:
	for i in n:
		if particulas.size() >= MAX_PARTICULAS:
			particulas.pop_front()
		particulas.append({"pos": pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(forca * 0.3, forca),
			"t": randf_range(0.25, 0.5), "cor": cor, "tam": randf_range(2, 4)})


func limpar() -> void:
	numeros.clear()
	particulas.clear()
	cortes.clear()
	impactos.clear()
	faiscas.clear()


func atualizar(dt: float) -> void:
	var _pp := Perf.ini()
	atualizar_i(dt)
	Perf.fim("efe_a", _pp)


func atualizar_i(dt: float) -> void:
	for n in numeros.duplicate():
		n.t -= dt
		n.idade += dt
		n.pop = maxf(0.0, n.pop - dt)
		n.pos.y += n.vy * dt   # sobe rápido e freia (antes subia sempre a 24 px/s)
		n.vy *= exp(-7.0 * dt)
		if n.t <= 0:
			numeros.erase(n)
	for p in particulas.duplicate():
		p.t -= dt
		p.pos += p.vel * dt
		p.vel *= exp(-5 * dt)
		if p.t <= 0:
			particulas.erase(p)
	_impactos_quadro = 0
	if is_inside_tree():
		_vis = get_canvas_transform().affine_inverse() * get_viewport_rect()
	for i in range(cortes.size() - 1, -1, -1):
		cortes[i].t += dt
		if cortes[i].t >= cortes[i].dur:
			cortes.remove_at(i)
	for i in range(impactos.size() - 1, -1, -1):
		impactos[i].t += dt
		if impactos[i].t >= IMPACTO_VIDA:
			impactos.remove_at(i)
	for i in range(faiscas.size() - 1, -1, -1):
		var f: Dictionary = faiscas[i]
		f.t -= dt
		f.pos += f.vel * dt
		f.vel *= exp(-9.0 * dt)
		if f.t <= 0.0:
			faiscas.remove_at(i)
	queue_redraw()
	_brilho.queue_redraw()


func _draw() -> void:
	var _pp := Perf.ini()
	_draw_i()
	Perf.fim("efe_d", _pp)


func _draw_i() -> void:
	for p in particulas:
		draw_rect(Rect2(p.pos, Vector2(p.tam, p.tam)), Color(p.cor, clampf(p.t * 3, 0, 1)))
	var f: Font = Dados.fonte
	for n in numeros:
		var a := clampf(n.t * 3.0, 0.0, 1.0)
		var tam: int = tamanho_numero(n.tam, n.pop)
		var c: Color = Color(1, 1, 1, a) if n.pop > POP * 0.5 else Color(n.cor, a)   # o soco nasce branco e já pega a cor
		var p: Vector2 = n.pos.round()
		var sombra := Color(0.08, 0.02, 0.0, a)
		for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:   # contorno escuro
			draw_string(f, p + o, n.txt, HORIZONTAL_ALIGNMENT_CENTER, -1, tam, sombra)
		draw_string(f, p, n.txt, HORIZONTAL_ALIGNMENT_CENTER, -1, tam, c)


## Tamanho do número durante o soco: dobra e volta, sempre múltiplo de 8 (a fonte é pixel de 8: tamanho quebrado treme).
static func tamanho_numero(base: int, pop: float) -> int:
	if pop <= 0.0:
		return base
	return base * 2 if pop > POP * 0.5 else ((base * 3) >> 1 if base >= 16 else base)


func _draw_brilho() -> void:
	var b := _brilho
	for l in luzes:   # halos primeiro: ficam por baixo dos golpes
		var r: float = l[1]
		b.draw_texture_rect(_tex_luz, Rect2(l[0] - Vector2(r, r * 0.7), Vector2(r * 2.0, r * 1.4)), false, l[2])
	luzes.clear()
	for im in impactos:   # o acerto acende o chão um instante
		var ui: float = im.t / IMPACTO_VIDA
		var ri: float = im.tam * 2.2
		b.draw_texture_rect(_tex_luz, Rect2(im.pos - Vector2(ri, ri * 0.7), Vector2(ri * 2.0, ri * 1.4)), false, Color(im.cor, 0.35 * (1.0 - ui)))
	for c in cortes:
		_pintar_corte(b, c)
		var uc: float = c.t / c.dur   # a cabeça da lâmina acende o chão por onde passa
		var cab := 1.0 - pow(1.0 - minf(1.0, uc / 0.45), 3.0)
		var hp: Vector2 = c.pos + Vector2.from_angle(c.ang - c.lado * c.arco * 0.5 + c.lado * c.arco * cab) * float(c.raio) * Vector2(0.8, CORTE_ACHATA * 0.8)
		var rc: float = c.raio * 0.9
		b.draw_texture_rect(_tex_luz, Rect2(hp - Vector2(rc, rc * 0.7), Vector2(rc * 2.0, rc * 1.4)), false, Color(c.cor, 0.3 * (1.0 - uc)))
	for im in impactos:
		var u: float = im.t / IMPACTO_VIDA
		var cresce := 1.0 - pow(1.0 - minf(1.0, u / 0.35), 3.0)   # estoura rápido
		var some := 1.0 - u
		var p: Vector2 = im.pos
		b.draw_circle(p, im.tam * 0.18 * (1.0 - u), Color(1, 1, 1, 0.8 * some))   # clarão pequeno: o grosso são os raios
		for r: Vector2 in im.raios:
			var d := Vector2.from_angle(r.x)
			var ponta: Vector2 = p + d * float(im.tam) * r.y * cresce
			var lado := d.orthogonal() * 1.6 * some
			b.draw_primitive(PackedVector2Array([p + lado, ponta, p - lado]),
				PackedColorArray([Color(1, 1, 1, some), Color(im.cor, 0.0), Color(1, 1, 1, some)]), PackedVector2Array())
	for f in faiscas:
		var a: float = clampf(f.t * 6.0, 0.0, 1.0)
		b.draw_line(f.pos, f.pos - f.vel * 0.035, Color(f.cor, a), 1.0)


## A meia-lua: cabeça varre o arco nos primeiros 45% da vida e o rabo come atrás; mais grossa perto da cabeça,
## com degradê da cor (fora) pro transparente (dentro) e um fio branco na borda de fora.
static func _pintar_corte(ci: CanvasItem, c: Dictionary) -> void:
	var u: float = c.t / c.dur
	var cabeca := 1.0 - pow(1.0 - minf(1.0, u / 0.45), 3.0)
	var rabo := pow(clampf((u - 0.2) / 0.8, 0.0, 1.0), 2.0)
	if cabeca - rabo < 0.02:
		return
	var some := 1.0 - smoothstep(0.75, 1.0, u)
	var a0: float = c.ang - c.lado * c.arco * 0.5
	var R: float = c.raio
	ci.draw_set_transform(c.pos, 0.0, Vector2(1.0, CORTE_ACHATA))
	var fora := PackedVector2Array()
	var meio := PackedVector2Array()
	var dentro := PackedVector2Array()
	var fio := PackedVector2Array()
	for i in CORTE_SEG + 1:
		var k := float(i) / CORTE_SEG                         # 0 = rabo, 1 = cabeça
		var s := lerpf(rabo, cabeca, k)
		var d := Vector2.from_angle(a0 + c.lado * c.arco * s)
		var w: float = c.larg * sin(PI * pow(k, 0.55))        # afina nas duas pontas, mais cheia perto da cabeça
		fora.append(d * R)
		fio.append(d * (R - maxf(1.0, w * 0.14)))
		meio.append(d * (R - w * 0.4))
		dentro.append(d * (R - w))
	# degradê de fora pra dentro: fio branco fino na borda, cor forte logo atrás, e some rápido pro centro
	var cc: Color = c.cor
	var forte := Color(cc, 0.95 * some)
	var fraca := Color(cc, 0.3 * some)
	var nada := Color(cc, 0.0)
	var branco := Color(1, 1, 1, some)
	for i in CORTE_SEG:
		ci.draw_primitive(PackedVector2Array([fora[i], fora[i + 1], meio[i + 1], meio[i]]),
			PackedColorArray([forte, forte, fraca, fraca]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([meio[i], meio[i + 1], dentro[i + 1], dentro[i]]),
			PackedColorArray([fraca, fraca, nada, nada]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([fora[i], fora[i + 1], fio[i + 1], fio[i]]),
			PackedColorArray([branco, branco, branco, branco]), PackedVector2Array())
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
