extends CanvasLayer
## Loja do mapa (#32 item 8): troca OURO por cartas que já existem no jogo (arma, passivo, equipamento) e por cura.
## Ouro = 1 por abate (chefe e elite valem mais, veja "ouro" em dados/mapa.json); é uma moeda só da corrida, guardada em arena.ouro.
## Setas escolhem, Enter compra, Esc/Voltar sai. Com --bot compra o que dá e sai em ~1,5 s; no online sai sozinha em 30 s.
## As ofertas saem de Sorte.criar("loja", andar): mesma semente e mesmo andar = mesma vitrine.

const W := 640.0
const H := 360.0
const TRAVA := 0.35
const AUTO_ONLINE := 30.0
const LINHA := 48.0

var arena: Node
var _tela := Control.new()
var _aberto := false
var _t0 := 0
var _ofertas: Array = []    # [{carta, preco, comprado}]; a última linha é "Sair"
var _sel := 0
var _aviso := ""
var _t_aviso := 0.0


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


func aberto() -> bool:
	return _aberto


func _agora() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


## A vitrine do andar: n cartas sorteadas com preço pelo tipo, mais uma cura. Função pura em cima de dados (o teste usa).
static func montar_ofertas(cartas: Array) -> Array:
	var cfg: Dictionary = Dados.json("mapa").get("tipos", {}).get("loja", {})
	var precos: Dictionary = cfg.get("preco", {})
	var res := []
	for c in cartas.slice(0, int(cfg.get("ofertas", 3))):
		if str(c.tipo) == "cura":
			continue
		var base := float(precos.get(str(c.tipo), 150))
		res.append({"carta": c, "preco": int(base * (1.0 + 0.25 * maxi(0, int(c.get("nivel", 1)) - 1))), "comprado": false})
	var cura: Dictionary = Dados.json("coletaveis").get("loja_cura", {})   # nome, texto e ícone no coletaveis.json (#65)
	res.append({"carta": {"tipo": "cura", "id": "vida", "nome": str(cura.get("nome", "Cura")), "desc": str(cura.get("desc", "Recupera toda a vida.")),
		"icone": str(cura.get("icone", "marmita")), "nivel": 0},
		"preco": int(precos.get("cura", 90)), "comprado": false, "completa": true})
	return res


func abrir(cartas: Array) -> void:
	_ofertas = montar_ofertas(cartas)
	_sel = 0
	_aviso = ""
	_t0 = Time.get_ticks_msec()
	_aberto = true
	get_tree().paused = not arena.eh_online
	Som.tocar("plim", 0.0, 1.1, -6)
	_tela.queue_redraw()


func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	get_tree().paused = false
	_tela.queue_redraw()
	if arena and not arena.acabou:
		arena._abrir_proxima.call_deferred()


## Tenta comprar a oferta i. true = comprou.
func comprar(i: int) -> bool:
	if i < 0 or i >= _ofertas.size():
		return false
	var o: Dictionary = _ofertas[i]
	if bool(o.comprado):
		_aviso = "Já comprado."
	elif arena.ouro < int(o.preco):
		_aviso = "Ouro insuficiente."
	else:
		arena.ouro -= int(o.preco)
		o.comprado = true
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


func _process(_dt: float) -> void:
	if not _aberto:
		return
	_tela.queue_redraw()
	var t := _agora()
	if arena.bot and t >= 0.8:
		# robô: compra o que couber (mais barato primeiro) e sai
		var melhor := -1
		for i in _ofertas.size():
			var o: Dictionary = _ofertas[i]
			if not bool(o.comprado) and not bool(o.get("completa", false)) and arena.ouro >= int(o.preco) and (melhor < 0 or int(o.preco) < int(_ofertas[melhor].preco)):
				melhor = i
		if melhor >= 0:
			comprar(melhor)
			_t0 += 300   # um pouco de pausa entre compras
		elif t >= 1.2:
			fechar()
	elif arena.eh_online and t >= AUTO_ONLINE:
		fechar()


func _input(e: InputEvent) -> void:
	if Chat.digitando:   # o teclado é do chat (chat.gd)
		return
	if not _aberto or _agora() < TRAVA or not e.is_pressed() or e.is_echo():
		return
	var n := _ofertas.size() + 1   # + "Sair"
	if e.is_action_pressed("cima") or e.is_action_pressed("esquerda"):
		_sel = (_sel - 1 + n) % n
		Som.tocar("cursor")
	elif e.is_action_pressed("baixo") or e.is_action_pressed("direita"):
		_sel = (_sel + 1) % n
		Som.tocar("cursor")
	elif e.is_action_pressed("confirmar"):
		if _sel >= _ofertas.size():
			Som.tocar("confirmar")
			fechar()
		else:
			comprar(_sel)
	elif e.is_action_pressed("voltar"):
		fechar()
	else:
		return
	get_viewport().set_input_as_handled()


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := -1.0, alinhar := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f: Font = Dados.fonte
	_tela.draw_string(f, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, cor.a * 0.8))
	_tela.draw_string(f, p, s, alinhar, larg, tam, cor)


func _desenhar() -> void:
	if not _aberto:
		return
	_t_aviso = maxf(0.0, _t_aviso - 0.016)
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.03, 0.08, 1.0))
	_txt(Vector2(0, 40), "LOJA", 16, Color(1, 0.85, 0.35), W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 62), "OURO %d" % arena.ouro, 8, Color(1, 0.85, 0.35), W, HORIZONTAL_ALIGNMENT_CENTER)
	var px := 60.0
	var pw := W - 2 * px
	var y := 78.0
	var pulso := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)
	for i in _ofertas.size() + 1:
		var sel := i == _sel
		_tela.draw_rect(Rect2(px - 2, y - 2, pw + 4, LINHA - 2), Color(1, 1, 1, 0.5 + 0.4 * pulso) if sel else Color(0.3, 0.34, 0.5))
		_tela.draw_rect(Rect2(px, y, pw, LINHA - 6), Color(0.15, 0.16, 0.26) if sel else Color(0.1, 0.11, 0.18))
		if i >= _ofertas.size():
			_txt(Vector2(px, y + 24), "Sair da loja", 8, Color(0.85, 0.9, 1), pw, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var o: Dictionary = _ofertas[i]
			var c: Dictionary = o.carta
			var comprado := bool(o.comprado)
			var pode: bool = arena.ouro >= int(o.preco)
			var a := 0.4 if comprado else 1.0
			var ic := Dados.icone(str(c.get("icone", "")))
			if ic:
				_tela.draw_texture(ic, Vector2(px + 8, y + 4), Color(1, 1, 1, a))
			var nome := str(c.get("nome", ""))
			if int(c.get("nivel", 0)) > 0:
				nome += "  NV %d" % int(c.nivel)
			_txt(Vector2(px + 44, y + 13), nome, 8, Color(1, 1, 1, a), pw - 150)
			_tela.draw_multiline_string(Dados.fonte, Vector2(px + 44, y + 25), str(c.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, pw - 150, 8, 2, Color(0.7, 0.74, 0.85, a))
			var ptxt := "COMPRADO" if comprado else "%d" % int(o.preco)
			var cp := Color(0.5, 0.9, 0.5) if comprado else (Color(1, 0.85, 0.35) if pode else Color(0.9, 0.35, 0.35))
			_txt(Vector2(px + pw - 100, y + 24), ptxt, 8, cp, 92, HORIZONTAL_ALIGNMENT_RIGHT)
		y += LINHA
	if _t_aviso > 0.0 and _aviso != "":
		_txt(Vector2(0, 326), _aviso, 8, Color(1, 0.5, 0.5), W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 346), "Setas: escolher   Enter: comprar   Esc: sair", 8, Color(0.6, 0.65, 0.8), W, HORIZONTAL_ALIGNMENT_CENTER)
