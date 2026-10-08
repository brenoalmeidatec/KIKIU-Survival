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
const CHAO := Rect2(32, 112, 576, 216)       # onde o herói pode andar (pés)
const BALCAO := Rect2(250, 118, 140, 22)
const VENDEDOR := Vector2(320, 116)          # os pés do vendedor
const PORTA := Rect2(290, 322, 60, 30)       # pisar aqui sai da sala
const RAIO_BALCAO := 56.0
const INICIO := Vector2(320, 290)

var arena: Node
var _tela := Control.new()
var _aberto := false
var _t0 := 0
var jogadores := {}         # id -> {compras:int, ofertas:Array [{carta, base, comprado}], ouro:int (só pros que não são o local)}
var _vitrine := false       # a lista de compras está aberta
var _sel := 0
var _aviso := ""
var _t_aviso := 0.0
var _pos := INICIO          # pés do herói na sala
var _bot_fase := 0


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


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
	var cura: Dictionary = Dados.json("coletaveis").get("loja_cura", {})   # nome, texto e ícone no coletaveis.json (#65)
	res.append({"carta": {"tipo": "cura", "id": "vida", "nome": str(cura.get("nome", "Cura")), "desc": str(cura.get("desc", "Recupera toda a vida.")),
		"icone": str(cura.get("icone", "marmita")), "nivel": 0},
		"base": int(precos.get("cura", 90)), "comprado": false, "completa": true})
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
	_tela.queue_redraw()


## Sai da sala (a porta, Esc ou o robô): o fluxo do nó segue pro mapa, a próxima etapa da corrida.
func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	_vitrine = false
	get_tree().paused = false
	_tela.queue_redraw()
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
	if BALCAO.grow(6).has_point(novo):
		novo = _pos
	_pos = novo


func _process(dt: float) -> void:
	if not _aberto:
		return
	_tela.queue_redraw()
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
				if not bool(o.comprado) and not bool(o.get("completa", false)) and arena.ouro >= preco_de(id, i) and (melhor < 0 or preco_de(id, i) < preco_de(id, melhor)):
					melhor = i
			if melhor >= 0:
				comprar(melhor)
				_t0 += 300   # um pouco de pausa entre compras
			elif t >= 1.2:
				_vitrine = false
				_bot_fase = 2
		2:
			andar((PORTA.get_center() - _pos).normalized(), dt)


func _input(e: InputEvent) -> void:
	if Chat.digitando:   # o teclado é do chat (chat.gd)
		return
	if not _aberto or _agora() < TRAVA or not e.is_pressed() or e.is_echo():
		return
	var ofertas: Array = estado(id_local()).ofertas
	var n := ofertas.size() + 1   # + "Voltar"
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
	_tela.draw_string(f, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, cor.a * 0.8))
	_tela.draw_string(f, p, s, alinhar, larg, tam, cor)


## Um boneco de 44x60 (primeira linha da folha, de frente) com os pés em `pe`.
func _boneco(tex: Texture2D, pe: Vector2, cor := Color.WHITE) -> void:
	_tela.draw_circle(pe + Vector2(0, -2), 9.0, Color(0, 0, 0, 0.3))
	if tex:
		_tela.draw_texture_rect_region(tex, Rect2(pe + Vector2(-22, -58), Vector2(44, 60)), Rect2(0, 0, 44, 60), cor)
	else:
		_tela.draw_rect(Rect2(pe + Vector2(-8, -40), Vector2(16, 40)), cor)


func _desenhar_sala() -> void:
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.04, 0.08))
	_tela.draw_rect(Rect2(0, 0, W, 112), Color(0.22, 0.15, 0.12))            # parede
	for x in range(0, int(W), 32):
		_tela.draw_rect(Rect2(x, 0, 2, 108), Color(0.17, 0.11, 0.09))
	_tela.draw_rect(Rect2(0, 104, W, 8), Color(0.35, 0.22, 0.14))            # rodapé
	for yy in range(112, int(H), 24):                                        # piso xadrez
		for xx in range(0, int(W), 32):
			var par := ((xx / 32) + (yy / 24)) % 2 == 0
			_tela.draw_rect(Rect2(xx, yy, 32, 24), Color(0.30, 0.25, 0.22) if par else Color(0.26, 0.21, 0.19))
	_tela.draw_rect(Rect2(PORTA.position.x - 4, 322, PORTA.size.x + 8, 38), Color(0.04, 0.03, 0.06))   # porta embaixo
	_tela.draw_rect(Rect2(PORTA.position.x, 326, PORTA.size.x, 34), Color(0.5, 0.35, 0.2))
	_txt(Vector2(PORTA.position.x - 20, 338), "SAIR", 8, Color(1, 0.95, 0.8), PORTA.size.x + 40, HORIZONTAL_ALIGNMENT_CENTER)
	for i in 5:                                                              # prateleiras com mercadoria
		var sx := 70.0 + i * 120.0
		if absf(sx - 320.0) < 80.0:
			continue
		_tela.draw_rect(Rect2(sx, 60, 60, 6), Color(0.45, 0.3, 0.18))
		for k in 3:
			_tela.draw_rect(Rect2(sx + 6 + k * 18, 46, 12, 14), Color.from_hsv(fmod(0.1 + i * 0.17 + k * 0.23, 1.0), 0.6, 0.9))
	var vend := str(cfg().get("vendedor", "fabio"))
	_boneco(Dados.tex_personagem(vend, "andando_8"), VENDEDOR)
	_tela.draw_rect(BALCAO, Color(0.45, 0.3, 0.18))                          # balcão por cima dos pés do vendedor
	_tela.draw_rect(Rect2(BALCAO.position.x, BALCAO.position.y, BALCAO.size.x, 5), Color(0.62, 0.43, 0.26))
	_txt(Vector2(BALCAO.position.x, BALCAO.position.y + 15), "LOJA", 8, Color(1, 0.85, 0.35), BALCAO.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_boneco(arena.jogador.spr.texture if arena.jogador else null, _pos)
	_txt(Vector2(0, 24), "LOJA", 16, Color(1, 0.85, 0.35), W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(8, 16), "OURO %d" % arena.ouro, 8, Color(1, 0.85, 0.35))
	if perto_do_balcao():
		_txt(Vector2(0, 172), "CONFIRMAR: ver a vitrine", 8, Color(1, 1, 1), W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 352), "Setas: andar   Porta: sair   Esc: sair", 8, Color(0.6, 0.65, 0.8), W, HORIZONTAL_ALIGNMENT_CENTER)


func _desenhar() -> void:
	if not _aberto:
		return
	_t_aviso = maxf(0.0, _t_aviso - 0.016)
	_desenhar_sala()
	if not _vitrine:
		return
	var id := id_local()
	var ofertas: Array = estado(id).ofertas
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.03, 0.08, 0.92))
	_txt(Vector2(0, 40), "LOJA", 16, Color(1, 0.85, 0.35), W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 62), "OURO %d" % arena.ouro, 8, Color(1, 0.85, 0.35), W, HORIZONTAL_ALIGNMENT_CENTER)
	var px := 60.0
	var pw := W - 2 * px
	var y := 78.0
	var pulso := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)
	for i in ofertas.size() + 1:
		var sel := i == _sel
		_tela.draw_rect(Rect2(px - 2, y - 2, pw + 4, LINHA - 2), Color(1, 1, 1, 0.5 + 0.4 * pulso) if sel else Color(0.3, 0.34, 0.5))
		_tela.draw_rect(Rect2(px, y, pw, LINHA - 6), Color(0.15, 0.16, 0.26) if sel else Color(0.1, 0.11, 0.18))
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
				_tela.draw_texture(ic, Vector2(px + 8, y + 4), Color(1, 1, 1, a))
			var nome := str(c.get("nome", ""))
			if int(c.get("nivel", 0)) > 0:
				nome += "  NV %d" % int(c.nivel)
			_txt(Vector2(px + 44, y + 13), nome, 8, Color(1, 1, 1, a), pw - 150)
			_tela.draw_multiline_string(Dados.fonte, Vector2(px + 44, y + 25), str(c.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, pw - 150, 8, 2, Color(0.7, 0.74, 0.85, a))
			var ptxt := "COMPRADO" if comprado else "%d" % preco
			var cp := Color(0.5, 0.9, 0.5) if comprado else (Color(1, 0.85, 0.35) if pode else Color(0.9, 0.35, 0.35))
			_txt(Vector2(px + pw - 100, y + 24), ptxt, 8, cp, 92, HORIZONTAL_ALIGNMENT_RIGHT)
		y += LINHA
	if _t_aviso > 0.0 and _aviso != "":
		_txt(Vector2(0, 326), _aviso, 8, Color(1, 0.5, 0.5), W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 346), "Setas: escolher   Enter: comprar   Esc: voltar   Compras: %d" % compras_de(id), 8, Color(0.6, 0.65, 0.8), W, HORIZONTAL_ALIGNMENT_CENTER)
