extends CanvasLayer
## Sala da loja (#112 itens 5 e 6, antes #32 item 8): ao entrar num nó de loja, o jogador cai numa sala com um vendedor atrás do balcão.
## Anda (setas/analógico) até o balcão e aperta CONFIRMAR pra abrir a vitrine; sai andando até a porta embaixo (ou Esc fora da vitrine).
## Moeda: ouro da corrida (arena.ouro, 1 por abate; dados/mapa.json "ouro"). Itens: cartas que já existem (arma, passivo, equipamento) e cura,
## sorteadas por Sorte.criar("loja", andar): mesma semente e mesmo andar = mesma vitrine.
## CADA JOGADOR TEM A SUA LOJA: estoque, compras feitas e preço ficam em `jogadores[id]`. O preço de cada item sobe a cada compra DO PRÓPRIO
## jogador: preço = base * (1 + aumento * compras), com teto (dados/mapa.json, tipos.loja.curva). As compras valem pra corrida inteira.
## Com --bot o robô anda até o balcão, compra o que cabe e vai até a porta; no online a sala fecha sozinha em 30 s.
## TODO online: cada cliente sorteia e gasta a própria loja (hoje só o jogador local tem ouro de verdade; os outros ids existem só na estrutura).

const W := 640.0
const H := 360.0
const TRAVA := 0.35
const AUTO_ONLINE := 30.0
const LINHA := 48.0
const CHAO := Rect2(32, 112, 576, 216)  # onde o herói pode andar (pés)
const BALCAO := Rect2(250, 118, 140, 22)
const VENDEDOR := Vector2(320, 116)  # os pés do vendedor
const PORTA := Rect2(290, 322, 60, 30)  # pisar aqui sai da sala
const RAIO_BALCAO := 56.0
const INICIO := Vector2(320, 290)
const PASTA := "res://assets/cenarios/loja/"  # arte da sala: fonte_arte/modelos3d/loja.py (Blender) gera piso, parede, objetos e cenario.json
const PAREDE_H := 112

var arena: Node
var _tela := Control.new()  # a sala (piso, parede, objetos, vendedor, herói)
var _luz_mul := Control.new()  # mapa de luz (multiplica a sala: escuro com poças quentes e vinheta)
var _luz_add := Control.new()  # halos, feixe de luar e partículas (somados: BLEND ADD)
var _topo := Control.new()  # textos e vitrine (acima da luz, pra ler bem)
var _cv: Control  # onde _txt e _boneco desenham agora
var _aberto := false
var _t0 := 0
var jogadores := {}  # id -> {compras:int, ofertas:Array [{carta, base, comprado}], ouro:int (só pros que não são o local)}
var _vitrine := false  # a lista de compras está aberta
var _sel := 0
var _aviso := ""
var _t_aviso := 0.0
var _pos := INICIO  # pés do herói na sala
var _bot_fase := 0
var _cen := {}  # cenario.json da sala
var _t_piso: Texture2D
var _t_parede: Texture2D
var _t_obj: Texture2D
var _pecas := {}  # nome -> {regiao: Rect2, pe: Vector2, luzes: Array}
var _obst: Array = []  # Rect2: onde o herói não pisa (objetos da sala), além do balcão
var _luzes: Array = []  # {pos, cor, raio, pisca, forca, par, halo}
var _glow: Texture2D
var _mapa_luz: ImageTexture


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in [_tela, _luz_mul, _luz_add, _topo]:
		c.size = Vector2(W, H)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
	_tela.draw.connect(_desenhar)
	_luz_mul.draw.connect(_desenhar_mapa_luz)
	_luz_add.draw.connect(_desenhar_halos)
	_topo.draw.connect(_desenhar_topo)
	_luz_mul.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_luz_add.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_luz_mul.material = mul
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_luz_add.material = add
	_carregar_arte()


func _redesenhar() -> void:
	for c in [_tela, _luz_mul, _luz_add, _topo]:
		c.queue_redraw()


func aberto() -> bool:
	return _aberto


func vitrine_aberta() -> bool:
	return _vitrine


func _agora() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


## Id do jogador desta máquina (solo = 1).
func id_local() -> int:
	return Rede.eu() if arena and arena.eh_online else 1


static func cfg() -> Dictionary:
	return Dados.json("mapa").get("tipos", {}).get("loja", {})


# ---------- funções puras (o teste usa) ----------


## Preço de um item depois de `compras` compras do jogador: base * (1 + aumento * compras), limitado a base * teto.
static func preco_atual(base: int, compras: int) -> int:
	var c: Dictionary = cfg().get("curva", {})
	var mult := minf(1.0 + float(c.get("aumento", 0.25)) * maxi(0, compras), float(c.get("teto", 4.0)))
	return int(round(base * mult))


## A vitrine do andar: n cartas sorteadas com preço-base pelo tipo, mais uma cura.
static func montar_ofertas(cartas: Array) -> Array:
	var c0: Dictionary = cfg()
	var precos: Dictionary = c0.get("preco", {})
	var res := []
	for c in cartas.slice(0, int(c0.get("ofertas", 3))):
		if str(c.tipo) == "cura":
			continue
		var base := float(precos.get(str(c.tipo), 150))
		res.append({"carta": c, "base": int(base * (1.0 + 0.25 * maxi(0, int(c.get("nivel", 1)) - 1))), "comprado": false})
	var cura: Dictionary = Dados.json("coletaveis").get("loja_cura", {})
	res.append(
		{
			"carta":
			{  # nome, texto e ícone no coletaveis.json (#65)
				"tipo": "cura",
				"id": "vida",
				"nome": str(cura.get("nome", "Cura")),
				"desc": str(cura.get("desc", "Recupera toda a vida.")),
				"icone": str(cura.get("icone", "marmita")),
				"nivel": 0
			},
			"base": int(precos.get("cura", 90)),
			"comprado": false,
			"completa": true
		}
	)
	return res


# ---------- estado por jogador ----------


func estado(id: int) -> Dictionary:
	if not jogadores.has(id):
		jogadores[id] = {"compras": 0, "ofertas": [], "ouro": 0}
	return jogadores[id]


func compras_de(id: int) -> int:
	return int(estado(id).compras)


func preco_de(id: int, i: int) -> int:
	var of: Array = estado(id).ofertas
	return preco_atual(int(of[i].base), compras_de(id)) if i >= 0 and i < of.size() else 0


func ouro_de(id: int) -> int:
	return arena.ouro if id == id_local() else int(estado(id).ouro)


func _gastar(id: int, v: int) -> void:
	if id == id_local():
		arena.ouro -= v
	else:
		estado(id).ouro = int(estado(id).ouro) - v


## Dá a cada jogador a sua vitrine (no solo só existe o local). Online as cartas vêm da mesma semente; TODO: uma rodada de sorteio por jogador.
func _montar_para_todos(cartas: Array) -> void:
	var ids: Array = [id_local()]
	if arena.eh_online:
		for k in Rede.jogadores:
			if not int(k) in ids:
				ids.append(int(k))
	for id in ids:
		estado(id).ofertas = montar_ofertas(cartas)


func abrir(cartas: Array) -> void:
	_montar_para_todos(cartas)
	_vitrine = false
	_sel = 0
	_aviso = ""
	_pos = INICIO
	_bot_fase = 0
	_t0 = Time.get_ticks_msec()
	_aberto = true
	get_tree().paused = not arena.eh_online
	Som.tocar("plim", 0.0, 1.1, -6)
	_redesenhar()


## Sai da sala (a porta, Esc ou o robô): o fluxo do nó segue pro mapa, a próxima etapa da corrida.
func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	_vitrine = false
	get_tree().paused = false
	_redesenhar()
	if arena and not arena.acabou:
		arena._abrir_proxima.call_deferred()


## Tenta comprar a oferta i da loja do jogador `id` (padrão: o local). true = comprou.
func comprar(i: int, id := -1) -> bool:
	if id < 0:
		id = id_local()
	var est: Dictionary = estado(id)
	if i < 0 or i >= est.ofertas.size():
		return false
	var o: Dictionary = est.ofertas[i]
	var preco := preco_de(id, i)
	if bool(o.comprado):
		_aviso = "Já comprado."
	elif ouro_de(id) < preco:
		_aviso = "Ouro insuficiente."
	else:
		_gastar(id, preco)
		o.comprado = true
		est.compras = int(est.compras) + 1
		if id == id_local():
			if bool(o.get("completa", false)):
				arena.jogador.curar(arena.stat("vida_max"))
				arena.mensagem("Vida cheia!", Color(0.5, 0.95, 0.6))
			else:
				arena.aplicar(o.carta)
			Som.tocar("plim", 0.05, 1.3)
		_aviso = ""
		return true
	_t_aviso = 1.2
	Som.tocar("blip", 0.0, 0.7, -4)
	return false


# ---------- andar pela sala ----------


func perto_do_balcao() -> bool:
	return _pos.distance_to(VENDEDOR + Vector2(0, 38)) <= RAIO_BALCAO


func na_porta() -> bool:
	return PORTA.has_point(_pos)


## Move o herói (pés) na direção dada, preso ao chão (menos pela porta) e fora do balcão.
func andar(dir: Vector2, dt: float) -> void:
	var novo := _pos + dir * float(cfg().get("velocidade", 120.0)) * dt
	var na_boca := novo.x > PORTA.position.x and novo.x < PORTA.end.x
	novo.x = clampf(novo.x, CHAO.position.x + 10, CHAO.end.x - 10)
	novo.y = clampf(novo.y, CHAO.position.y + 24, PORTA.end.y - 2 if na_boca else CHAO.end.y)
	if _bloqueado(novo):
		var so_x := Vector2(novo.x, _pos.y)
		var so_y := Vector2(_pos.x, novo.y)
		if not _bloqueado(so_x) and absf(novo.x - _pos.x) > 0.001:
			novo = so_x
		elif not _bloqueado(so_y) and absf(novo.y - _pos.y) > 0.001:
			novo = so_y
		else:
			novo = _pos
	_pos = novo


## O ponto cai no balcão ou num objeto da sala (barris, mesa, baú...)?
func _bloqueado(p: Vector2) -> bool:
	if BALCAO.grow(6).has_point(p):
		return true
	for o in _obst:
		if o.has_point(p):
			return true
	return false


func _process(dt: float) -> void:
	if not _aberto:
		return
	_redesenhar()
	var t := _agora()
	if arena.bot:
		_robo(dt, t)
	elif arena.eh_online and t >= AUTO_ONLINE:
		fechar()
		return
	elif not _vitrine and not Chat.digitando:
		andar(Input.get_vector("esquerda", "direita", "cima", "baixo"), dt)
	if _aberto and not _vitrine and t >= TRAVA and na_porta():
		Som.tocar("confirmar")
		fechar()


## Robô: anda até o balcão, compra o que couber (mais barato primeiro) e anda até a porta. Passou de 12 s, sai de qualquer jeito.
func _robo(dt: float, t: float) -> void:
	if t >= 12.0:
		fechar()
		return
	var id := id_local()
	match _bot_fase:
		0:
			var alvo := VENDEDOR + Vector2(0, 40)
			andar((alvo - _pos).normalized() if _pos.distance_to(alvo) > 4.0 else Vector2.ZERO, dt)
			if perto_do_balcao() and t >= 0.5:
				_vitrine = true
				_bot_fase = 1
		1:
			if t < 0.8:
				return
			var melhor := -1
			for i in estado(id).ofertas.size():
				var o: Dictionary = estado(id).ofertas[i]
				if (
					not bool(o.comprado)
					and not bool(o.get("completa", false))
					and arena.ouro >= preco_de(id, i)
					and (melhor < 0 or preco_de(id, i) < preco_de(id, melhor))
				):
					melhor = i
			if melhor >= 0:
				comprar(melhor)
				_t0 += 300  # um pouco de pausa entre compras
			elif t >= 1.2:
				_vitrine = false
				_bot_fase = 2
		2:
			andar((PORTA.get_center() - _pos).normalized(), dt)


func _input(e: InputEvent) -> void:
	if Chat.digitando:  # o teclado é do chat (chat.gd)
		return
	if not _aberto or _agora() < TRAVA or not e.is_pressed() or e.is_echo():
		return
	var ofertas: Array = estado(id_local()).ofertas
	var n := ofertas.size() + 1  # + "Voltar"
	if not _vitrine:
		if e.is_action_pressed("confirmar") and perto_do_balcao():
			_vitrine = true
			_sel = 0
			Som.tocar("confirmar")
		elif e.is_action_pressed("voltar"):
			fechar()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("cima") or e.is_action_pressed("esquerda"):
		_sel = (_sel - 1 + n) % n
		Som.tocar("cursor")
	elif e.is_action_pressed("baixo") or e.is_action_pressed("direita"):
		_sel = (_sel + 1) % n
		Som.tocar("cursor")
	elif e.is_action_pressed("confirmar"):
		if _sel >= ofertas.size():
			Som.tocar("confirmar")
			_vitrine = false
		else:
			comprar(_sel)
	elif e.is_action_pressed("voltar"):
		_vitrine = false
	else:
		return
	get_viewport().set_input_as_handled()


# ---------- desenho ----------


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := -1.0, alinhar := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f: Font = Dados.fonte
	_cv.draw_string(f, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, cor.a * 0.8))
	_cv.draw_string(f, p, s, alinhar, larg, tam, cor)


## Um boneco de 44x60 (primeira linha da folha, de frente) com os pés em `pe`.
func _boneco(tex: Texture2D, pe: Vector2, cor := Color.WHITE) -> void:
	_cv.draw_circle(pe + Vector2(0, -2), 9.0, Color(0, 0, 0, 0.3))
	if tex:
		_cv.draw_texture_rect_region(tex, Rect2(pe + Vector2(-22, -58), Vector2(44, 60)), Rect2(0, 0, 44, 60), cor)
	else:
		_cv.draw_rect(Rect2(pe + Vector2(-8, -40), Vector2(16, 40)), cor)


## Lê o cenario.json e as imagens da sala (gerados por fonte_arte/modelos3d/loja.py) e monta obstáculos e luzes.
func _carregar_arte() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "cenario.json"))
	if not d is Dictionary:
		push_error("loja: cenario.json ausente ou com erro em " + PASTA)
		return
	_cen = d
	_t_piso = load(PASTA + str(d.piso))
	_t_parede = load(PASTA + str(d.parede))
	_t_obj = load(PASTA + str(d.objetos))
	for nome in d.pecas:
		var p: Dictionary = d.pecas[nome]
		var rg: Array = p.regiao
		_pecas[nome] = {"regiao": Rect2(rg[0], rg[1], rg[2], rg[3]), "pe": Vector2(p.pe[0], p.pe[1]), "luzes": p.luzes}
	_obst.clear()
	_luzes.clear()
	for it in d.layout:
		var pos := Vector2(it.x, it.y)
		if it.has("obst"):
			_obst.append(Rect2(pos.x - it.obst[0] * 0.5, pos.y - it.obst[1], it.obst[0], it.obst[1]))
		for l in _pecas[str(it.peca)].luzes:
			_luzes.append(_nova_luz(pos + Vector2(l.fonte[0], l.fonte[1]), l, false))
	for l in d.luzes_fixas:
		_luzes.append(_nova_luz(Vector2(l.x, l.y), l, bool(l.get("par", false))))
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_glow = gt


static func _nova_luz(pos: Vector2, l: Dictionary, par: bool) -> Dictionary:
	var c: Array = l.cor
	return {
		"pos": pos,
		"cor": Color(c[0], c[1], c[2]),
		"raio": float(l.raio),
		"pisca": float(l.get("pisca", 0.0)),
		"forca": float(l.get("forca", 1.0)),
		"par": par,
		"halo": bool(l.get("halo", true))
	}


## Mapa de luz: ambiente escuro e frio + a poça de cada luz + vinheta. Fica numa imagem pequena (barato) esticada com filtro suave.
func _montar_mapa_luz() -> void:
	var gw := 128
	var gh := 72
	var passo := W / gw
	var amb: Array = _cen.ambiente
	var img := Image.create(gw, gh, false, Image.FORMAT_RGB8)
	for y in gh:
		for x in gw:
			var p := Vector2((x + 0.5) * passo, (y + 0.5) * passo)
			var r := amb[0] as float
			var g := amb[1] as float
			var b := amb[2] as float
			for l in _luzes:
				var dv: Vector2 = p - l.pos
				if not l.par:
					dv.y *= 1.3
				var k := clampf(1.0 - dv.length() / l.raio, 0.0, 1.0)
				if k <= 0.0:
					continue
				k = k * k * (3.0 - 2.0 * k) * l.forca
				r += l.cor.r * k
				g += l.cor.g * k
				b += l.cor.b * k
			var vig := 1.0 - smoothstep(0.55, 1.15, Vector2((p.x - W * 0.5) / (W * 0.6), (p.y - H * 0.5) / (H * 0.62)).length()) * 0.5
			img.set_pixel(x, y, Color(minf(r, 1.0) * vig, minf(g, 1.0) * vig, minf(b, 1.0) * vig))
	_mapa_luz = ImageTexture.create_from_image(img)


func _peca_em(it: Dictionary) -> void:
	var p: Dictionary = _pecas[str(it.peca)]
	_tela.draw_texture_rect_region(_t_obj, Rect2(Vector2(it.x, it.y) - p.pe, p.regiao.size), p.regiao)


func _desenhar_sala() -> void:
	_cv = _tela
	if _t_piso == null:
		_tela.draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.08, 0.07))
		return
	_tela.draw_texture_rect(_t_piso, Rect2(0, PAREDE_H, W, H - PAREDE_H), true)
	_tela.draw_texture(_t_parede, Vector2.ZERO)
	for i in 7:  # sombra da parede no chão
		_tela.draw_rect(Rect2(0, PAREDE_H + i * 2, W, 2), Color(0, 0, 0, 0.4 - i * 0.055))
	for it in _cen.layout:  # tapete e porta: no chão, antes de tudo
		if str(it.camada) == "chao":
			_peca_em(it)
	var fila := []  # [y do pé, tipo, dados]: tudo em ordem de profundidade (quem está mais embaixo na tela vem na frente)
	for it in _cen.layout:
		if str(it.camada) == "obj":
			if it.has("sombra"):
				_tela.draw_set_transform(Vector2(it.x, it.y - 2), 0.0, Vector2(1.0, float(it.sombra[1]) / float(it.sombra[0])))
				_tela.draw_circle(Vector2.ZERO, float(it.sombra[0]), Color(0, 0, 0, 0.38))
				_tela.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			fila.append([float(it.y), 0, it])
	fila.append([VENDEDOR.y, 1, null])
	fila.append([_pos.y, 2, null])
	fila.sort_custom(func(a, b): return a[0] < b[0])
	for e in fila:
		match int(e[1]):
			0:
				_peca_em(e[2])
			1:
				_boneco(Dados.tex_personagem(str(cfg().get("vendedor", "fabio")), "andando_8"), VENDEDOR)
			2:
				_boneco(arena.jogador.spr.texture if arena.jogador else null, _pos)


func _desenhar_mapa_luz() -> void:
	if not _aberto or _t_piso == null:
		return
	if _mapa_luz == null:
		_montar_mapa_luz()
	_luz_mul.draw_texture_rect(_mapa_luz, Rect2(0, 0, W, H), false)


## Halos quentes que tremulam, o feixe do luar e as partículas (brasa, fumaça, poeira). Tudo somado à sala (ADD).
func _desenhar_halos() -> void:
	if not _aberto or _t_piso == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var lua: Array = _cen.luar.janela
	var feixe := PackedVector2Array([Vector2(lua[0], lua[1] + 22), Vector2(lua[2], lua[1] + 22), Vector2(590, 200), Vector2(450, 200)])
	var a_f := 0.075 + 0.012 * sin(t * 0.7)
	_luz_add.draw_polygon(feixe, PackedColorArray([Color(0.5, 0.65, 1, a_f), Color(0.5, 0.65, 1, a_f), Color(0.5, 0.65, 1, 0.0), Color(0.5, 0.65, 1, 0.0)]))
	for i in _luzes.size():
		var l: Dictionary = _luzes[i]
		if not l.halo:
			continue
		var f: float = 1.0 + l.pisca * (0.6 * sin(t * 11.0 + i * 1.7) + 0.4 * sin(t * 23.0 + i * 4.1) + 0.3 * sin(t * 5.3 + i))
		var r: float = l.raio * 0.62 * (1.0 + (f - 1.0) * 0.5)
		var alt := 1.0 if l.par else 0.72
		var col: Color = l.cor
		col.a = minf(0.55 * l.forca * f, 0.8)
		_luz_add.draw_texture_rect(_glow, Rect2(l.pos - Vector2(r, r * alt), Vector2(r * 2.0, r * 2.0 * alt)), false, col)
		var r2 := r * 0.28
		col.a = minf(0.7 * l.forca * f, 0.9)
		_luz_add.draw_texture_rect(_glow, Rect2(l.pos - Vector2(r2, r2), Vector2(r2 * 2.0, r2 * 2.0)), false, col)
	for e in _cen.emissores:
		var n := int(e.get("n", 1))
		match str(e.tipo):
			"brasa":
				for i in n:
					var ph := fmod(t * (0.3 + 0.05 * (i % 3)) + i * 0.618, 1.0)
					var p := Vector2(float(e.x) + sin(t * 1.4 + i * 2.1) * 8.0 * ph + float((i * 7) % 13 - 6), float(e.y) - ph * 58.0)
					_luz_add.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(1.0, 0.55, 0.2, (1.0 - ph) * 0.9))
			"fumaca":
				for i in n:
					var ph := fmod(t * 0.16 + float(i) / n, 1.0)
					var p := Vector2(float(e.x) + sin(t * 0.9 + i * 1.9) * 5.0 + ph * 12.0, float(e.y) - ph * 50.0)
					var r := 7.0 + ph * 12.0
					_luz_add.draw_texture_rect(_glow, Rect2(p - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, Color(0.45, 0.75, 0.5, 0.2 * (1.0 - ph)))
			"poeira":
				for i in n:
					var x := fposmod(i * 131.7 + t * (3.0 + (i % 4)), W)
					var y := 30.0 + fposmod(i * 73.1 - t * (2.0 + (i % 3)) + sin(t * 0.5 + i) * 6.0, 300.0)
					_luz_add.draw_rect(Rect2(floorf(x), floorf(y), 1, 1), Color(1.0, 0.88, 0.7, 0.22 + 0.2 * sin(t * 1.5 + i)))


func _placa(r: Rect2) -> void:
	_cv.draw_rect(r, Color(0.04, 0.03, 0.05, 0.78))
	_cv.draw_rect(r, Color(0.78, 0.6, 0.27, 0.8), false, 1.0)


func _desenhar() -> void:
	if not _aberto:
		return
	_desenhar_sala()


func _desenhar_topo() -> void:
	if not _aberto:
		return
	_cv = _topo
	_t_aviso = maxf(0.0, _t_aviso - 0.016)
	if _vitrine:
		_desenhar_vitrine()
		return
	_txt(Vector2(PORTA.position.x - 20, 322), "SAIR", 8, Color(1, 0.9, 0.6), PORTA.size.x + 40, HORIZONTAL_ALIGNMENT_CENTER)
	_placa(Rect2(W * 0.5 - 34, 5, 68, 22))
	_txt(Vector2(0, 23), "LOJA", 16, Color(1, 0.85, 0.35), W, HORIZONTAL_ALIGNMENT_CENTER)
	_placa(Rect2(6, 6, 82, 16))
	_txt(Vector2(12, 18), "OURO %d" % arena.ouro, 8, Color(1, 0.85, 0.35))
	if perto_do_balcao():
		_placa(Rect2(W * 0.5 - 90, 162, 180, 14))
		_txt(Vector2(0, 172), "CONFIRMAR: ver a vitrine", 8, Color(1, 1, 1), W, HORIZONTAL_ALIGNMENT_CENTER)
	_placa(Rect2(W * 0.5 - 160, 341, 320, 14))
	_txt(Vector2(0, 352), "Setas: andar   Porta: sair   Esc: sair", 8, Color(0.8, 0.84, 0.95), W, HORIZONTAL_ALIGNMENT_CENTER)


func _desenhar_vitrine() -> void:
	var id := id_local()
	var ofertas: Array = estado(id).ofertas
	_cv.draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.03, 0.04, 0.9))
	_txt(Vector2(0, 40), "LOJA", 16, Color(1, 0.85, 0.35), W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 62), "OURO %d" % arena.ouro, 8, Color(1, 0.85, 0.35), W, HORIZONTAL_ALIGNMENT_CENTER)
	var px := 60.0
	var pw := W - 2 * px
	var y := 78.0
	var pulso := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)
	for i in ofertas.size() + 1:
		var sel := i == _sel
		_cv.draw_rect(Rect2(px - 2, y - 2, pw + 4, LINHA - 2), Color(1, 0.9, 0.65, 0.5 + 0.4 * pulso) if sel else Color(0.45, 0.34, 0.2))
		_cv.draw_rect(Rect2(px, y, pw, LINHA - 6), Color(0.2, 0.14, 0.1) if sel else Color(0.12, 0.09, 0.08))
		if i >= ofertas.size():
			_txt(Vector2(px, y + 24), "Voltar à sala", 8, Color(0.85, 0.9, 1), pw, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var o: Dictionary = ofertas[i]
			var c: Dictionary = o.carta
			var comprado := bool(o.comprado)
			var preco := preco_de(id, i)
			var pode: bool = arena.ouro >= preco
			var a := 0.4 if comprado else 1.0
			var ic := Dados.icone(str(c.get("icone", "")))
			if ic:
				_cv.draw_texture(ic, Vector2(px + 8, y + 4), Color(1, 1, 1, a))
			var nome := str(c.get("nome", ""))
			if int(c.get("nivel", 0)) > 0:
				nome += "  NV %d" % int(c.nivel)
			_txt(Vector2(px + 44, y + 13), nome, 8, Color(1, 1, 1, a), pw - 150)
			_cv.draw_multiline_string(
				Dados.fonte, Vector2(px + 44, y + 25), str(c.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, pw - 150, 8, 2, Color(0.7, 0.74, 0.85, a)
			)
			var ptxt := "COMPRADO" if comprado else "%d" % preco
			var cp := Color(0.5, 0.9, 0.5) if comprado else (Color(1, 0.85, 0.35) if pode else Color(0.9, 0.35, 0.35))
			_txt(Vector2(px + pw - 100, y + 24), ptxt, 8, cp, 92, HORIZONTAL_ALIGNMENT_RIGHT)
		y += LINHA
	if _t_aviso > 0.0 and _aviso != "":
		_txt(Vector2(0, 326), _aviso, 8, Color(1, 0.5, 0.5), W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(
		Vector2(0, 346),
		"Setas: escolher   Enter: comprar   Esc: voltar   Compras: %d" % compras_de(id),
		8,
		Color(0.6, 0.65, 0.8),
		W,
		HORIZONTAL_ALIGNMENT_CENTER
	)
