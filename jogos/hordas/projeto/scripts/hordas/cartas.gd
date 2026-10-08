extends CanvasLayer
## Escolha de cartas ao subir de nível (ou na tomada) e a tela do baú (#7: UI/UX).
## Teclado: setas/A-D escolhem, Enter/E confirmam, 1-4 pegam direto, R sorteia de novo, X pula, B bane a carta escolhida.
## Controle: direcional/analógico, A confirma, Y sorteia, LB pula, SELECT bane. Mouse: passar por cima escolhe, clique pega.
## "Baixo" leva o foco pra fileira de botões (sortear / pular / banir), "cima" volta pras cartas.
##
## Leitura em 2 segundos: moldura e tira de título na cor do TIPO (arma, passivo, equipamento, exclusiva, evolução) mais um
## GLIFO de forma (triângulo, círculo, quadrado, estrela...) pra quem não distingue as cores; ícone grande; pips de nível
## (o novo pisca); "antes > depois" do atributo que muda (HoloCure / Halls of Torment). Entrada animada em tempo real.

const Interface := preload("res://scripts/hordas/interface.gd")
const W := 640.0
const H := 360.0
const LARG := 144.0
const ALT := 200.0
const GAP := 8.0
const Y0 := 58.0
const ENTRADA := 0.18      # duração da animação de entrada de cada carta (s, tempo real)
const ESCALONA := 0.06     # atraso entre uma carta e a próxima
const BTN_W := 150.0
const BTN_H := 16.0
const BTN_Y := 268.0

var arena: Node
var _tela := Control.new()
var _modo := ""          # "", "escolher", "bau"
var _titulo := ""
var _cartas: Array = []
var _sel := 0
var _foco := "cartas"    # "cartas" ou "botoes"
var _bsel := 0           # botão com foco (índice na lista de _botoes())
var _espera := 0.0
var _t := 0.0
var _inicio: Array = []  # por carta: instante (ms) em que a animação de entrada dela começa
var _mouse_ult := Vector2(-1, -1)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


func aberto() -> bool:
	return _modo != ""


func escolher(titulo: String, cartas: Array) -> void:
	_abrir("escolher", titulo, cartas)


func mostrar_bau(premios: Array) -> void:
	_abrir("bau", "Baú!" if premios[0].tipo != "evolucao" else "EVOLUÇÃO!", premios)


func _abrir(modo: String, titulo: String, cartas: Array) -> void:
	_modo = modo
	_titulo = titulo
	_cartas = cartas
	_sel = 0
	_foco = "cartas"
	_bsel = 0
	_espera = 0.35
	_reiniciar_animacao()
	_mouse_ult = _tela.get_local_mouse_position()   # mouse parado não rouba a seleção do teclado
	get_tree().paused = not arena.eh_online   # no online o jogo dos outros não para
	if not arena.bot:
		Som.ui("abrir")
	_tela.queue_redraw()


func _reiniciar_animacao() -> void:
	var agora := Time.get_ticks_msec()
	_inicio = []
	for i in _cartas.size():
		_inicio.append(agora + int(i * ESCALONA * 1000.0))


func _fechar() -> void:
	_modo = ""
	get_tree().paused = false
	_tela.queue_redraw()


# ---------- layout (desenho e mouse usam as mesmas contas) ----------

func _larg(n: int) -> float:
	return minf(LARG, (W - 16.0 - (n - 1) * GAP) / n)   # baú de 5 cartas encolhe pra caber


func _rect_carta(i: int) -> Rect2:
	var n := _cartas.size()
	var larg := _larg(n)
	var x0 := (W - n * larg - (n - 1) * GAP) / 2
	return Rect2(x0 + i * (larg + GAP), Y0, larg, ALT)


## Botões da fileira de baixo. Só existem ao escolher carta (o baú não tem) e não nas dádivas (sem sortear/pular).
func _botoes() -> Array:
	if _modo != "escolher" or _cartas.is_empty() or _cartas[0].tipo == "dadiva":
		return []
	var pad := not Input.get_connected_joypads().is_empty()
	var c: Dictionary = _cartas[clampi(_sel, 0, _cartas.size() - 1)]
	return [
		{"id": "resortear", "txt": "[%s] Sortear x%d" % ["Y" if pad else "R", arena.resortear], "ativo": arena.resortear > 0},
		{"id": "pular", "txt": "[%s] Pular x%d" % ["LB" if pad else "X", arena.pular], "ativo": arena.pular > 0},
		{"id": "banir", "txt": "[%s] Banir x%d" % ["SEL" if pad else "B", arena.banir], "ativo": arena.banir > 0 and arena.carta_banivel(c)},
	]


func _rect_botao(i: int, n: int) -> Rect2:
	var gap := 8.0
	var larg := minf(BTN_W + 22.0, (W - 24.0 - (n - 1) * gap) / n)
	var x0 := (W - n * larg - (n - 1) * gap) / 2
	return Rect2(x0 + i * (larg + gap), BTN_Y, larg, BTN_H)


# ---------- entrada ----------

func _process(dt: float) -> void:
	_t += dt
	if _modo == "":
		return
	_tela.queue_redraw()
	_espera -= dt
	if _espera > 0:
		return
	if arena.bot:
		_confirmar()
		return
	_mouse()
	if _modo == "bau":
		if Input.is_action_just_pressed("confirmar") or Input.is_action_just_pressed("voltar"):
			Som.ui("confirmar")
			_confirmar()
		return
	var botoes := _botoes()
	if _foco == "botoes" and botoes.is_empty():
		_foco = "cartas"
	if Input.is_action_just_pressed("esquerda") or (_foco == "cartas" and Input.is_action_just_pressed("cima")):
		_mover(-1)
	elif Input.is_action_just_pressed("direita"):
		_mover(1)
	elif Input.is_action_just_pressed("baixo"):
		if _foco == "cartas" and not botoes.is_empty():
			_foco = "botoes"
			_bsel = clampi(_bsel, 0, botoes.size() - 1)
			Som.ui("cursor")
		elif _foco == "cartas":
			_mover(1)
	elif Input.is_action_just_pressed("cima") and _foco == "botoes":
		_foco = "cartas"
		Som.ui("cursor")
	elif Input.is_action_just_pressed("confirmar"):
		if _foco == "botoes":
			_acao(str(botoes[_bsel].id))
		else:
			_confirmar()
	elif Input.is_action_just_pressed("resortear"):
		_acao("resortear")
	elif Input.is_action_just_pressed("pular"):
		_acao("pular")
	elif Input.is_action_just_pressed("banir"):
		_acao("banir")


func _mover(passo: int) -> void:
	if _foco == "botoes":
		var n := _botoes().size()
		_bsel = (_bsel + passo + n) % n
	else:
		_sel = (_sel + passo + _cartas.size()) % _cartas.size()
	Som.ui("cursor")


## Mouse: passar por cima escolhe (só quando o mouse se MEXEU, senão ele brigaria com o teclado).
func _mouse() -> void:
	var mp := _tela.get_local_mouse_position()
	if mp == _mouse_ult:
		return
	_mouse_ult = mp
	if _modo != "escolher":
		return
	for i in _cartas.size():
		if _rect_carta(i).has_point(mp):
			if _sel != i or _foco != "cartas":
				_sel = i
				_foco = "cartas"
				Som.ui("cursor")
			return
	var botoes := _botoes()
	for i in botoes.size():
		if _rect_botao(i, botoes.size()).has_point(mp):
			if _bsel != i or _foco != "botoes":
				_bsel = i
				_foco = "botoes"
				Som.ui("cursor")
			return


func _input(e: InputEvent) -> void:
	if Chat.digitando:   # o teclado é do chat (chat.gd)
		return
	if _modo == "" or _espera > 0 or arena.bot:
		return
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var mp := _tela.get_local_mouse_position()
	get_viewport().set_input_as_handled()
	if _modo == "bau":
		Som.ui("confirmar")
		_confirmar()
		return
	for i in _cartas.size():
		if _rect_carta(i).has_point(mp):
			_sel = i
			_confirmar()
			return
	var botoes := _botoes()
	for i in botoes.size():
		if _rect_botao(i, botoes.size()).has_point(mp):
			_acao(str(botoes[i].id))
			return


func _unhandled_key_input(e: InputEvent) -> void:
	if Chat.digitando:
		return
	if _modo != "escolher" or _espera > 0 or not e.is_pressed():
		return
	var k: int = e.physical_keycode - KEY_1
	if k >= 0 and k < _cartas.size():
		_sel = k
		_confirmar()


# ---------- ações ----------

func _acao(id: String) -> void:
	if _modo != "escolher" or _cartas.is_empty() or _cartas[0].tipo == "dadiva":
		return
	match id:
		"resortear":
			if not arena.pode_resortear():
				Som.ui("erro")
				return
			_cartas = arena.gastar_resortear()
			_sel = 0
			_reiniciar_animacao()
			Som.tocar("whoosh")
		"pular":
			if not arena.gastar_pular():
				Som.ui("erro")
				return
			Som.ui("voltar")
			_fechar()
			arena.escolheu({"tipo": "nada"})
		"banir":
			var r: Dictionary = arena.gastar_banir(_cartas[_sel], _cartas)
			if r.has("erro"):
				Som.ui("erro")
				return
			if r.is_empty():
				_cartas.remove_at(_sel)
				_inicio.remove_at(_sel)
				if _cartas.is_empty():   # nada sobrou no sorteio: a carta de cura nunca deixa a mesa vazia
					_cartas = [{"tipo": "cura", "id": "vida", "nome": "Café da tarde", "desc": "Recupera 40 de vida.", "icone": "vida", "nivel": 0, "max": 1, "cmp": []}]
					_inicio = [Time.get_ticks_msec()]
				_sel = clampi(_sel, 0, _cartas.size() - 1)
			else:
				_cartas[_sel] = r
				_inicio[_sel] = Time.get_ticks_msec()
			Som.tocar("whoosh", 0.05, 0.8)


func _confirmar() -> void:
	if _modo == "bau":
		_fechar()
		arena.escolheu({"tipo": "nada"})
		return
	var c: Dictionary = _cartas[_sel]
	Som.ui("confirmar")
	_fechar()
	arena.escolheu(c)


# ---------- desenho ----------

func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := -1.0, alinhar := HORIZONTAL_ALIGNMENT_CENTER, f: Font = null) -> void:
	if f == null:
		f = Dados.fonte
	_tela.draw_string(f, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, 0.8))
	_tela.draw_string(f, p, s, alinhar, larg, tam, cor)


## Cor, glifo e rótulo do tipo da carta. Glifos: triangulo=arma, circulo=passivo, quadrado=equipamento,
## estrela=exclusiva/evolução, cruz=cura, losango=dádiva (a forma carrega a informação além da cor).
static func estilo(c: Dictionary, t := 0.0) -> Dictionary:
	var tipo := str(c.get("tipo", ""))
	match tipo:
		"evolucao":
			var a := Interface.cor("evolucao")
			var b := Color(0.4, 0.9, 1) if not Interface.daltonico() else Color(0.9, 0.6, 0.0)
			return {"cor": a.lerp(b, 0.5 + 0.5 * sin(t * 6)), "glifo": "estrela", "rotulo": "EVOLUÇÃO"}
		"cura":
			return {"cor": Interface.cor("cura"), "glifo": "cruz", "rotulo": "CURA"}
		"dadiva":
			return {"cor": Interface.cor_raridade(str(c.get("raridade", "")), c.get("cor", Color.WHITE)), "glifo": "losango", "rotulo": "DÁDIVA"}
		"comportamento":
			return {"cor": Interface.cor("comportamento"), "glifo": "estrela", "rotulo": "COMPORTAMENTO"}
		"equipamento":
			return {"cor": Interface.cor("equipamento"), "glifo": "quadrado", "rotulo": "EQUIPAMENTO"}
		"passivo":
			return {"cor": Interface.cor("passivo"), "glifo": "circulo", "rotulo": "PASSIVO"}
	if c.has("exclusiva"):
		return {"cor": Interface.cor("exclusiva"), "glifo": "estrela", "rotulo": "EXCLUSIVA"}
	return {"cor": Interface.cor("arma"), "glifo": "triangulo", "rotulo": "ARMA"}


func _glifo(g: String, c: Vector2, r: float, cor: Color) -> void:
	var pts: PackedVector2Array
	match g:
		"triangulo":
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)])
		"quadrado":
			_tela.draw_rect(Rect2(c - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), cor)
			return
		"circulo":
			_tela.draw_circle(c, r, cor)
			return
		"losango":
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		"cruz":
			_tela.draw_rect(Rect2(c + Vector2(-r, -r * 0.3), Vector2(r * 2, r * 0.6)), cor)
			_tela.draw_rect(Rect2(c + Vector2(-r * 0.3, -r), Vector2(r * 0.6, r * 2)), cor)
			return
		_:   # estrela de 5 pontas
			pts = PackedVector2Array()
			for k in 10:
				var ang := -PI / 2 + k * PI / 5
				pts.append(c + Vector2.from_angle(ang) * (r if k % 2 == 0 else r * 0.45))
	_tela.draw_colored_polygon(pts, cor)


func _desenhar() -> void:
	if _modo == "":
		return
	var agora := Time.get_ticks_msec()
	var fade := clampf((agora - (_inicio[0] if not _inicio.is_empty() else agora)) / 120.0, 0.0, 1.0)
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.02, 0.06, 0.84 * maxf(fade, 0.35)))
	var cor_t: Color = Interface.cor("destaque") if _modo == "bau" else Color(0.6, 0.85, 1)
	_txt(Vector2(0, 28), _titulo, 24, cor_t, W, HORIZONTAL_ALIGNMENT_CENTER, Dados.fonte_titulo)
	var n := _cartas.size()
	for i in n:
		_carta(i, (agora - int(_inicio[i])) / 1000.0)
	var botoes := _botoes()
	for i in botoes.size():
		var b: Dictionary = botoes[i]
		var r := _rect_botao(i, botoes.size())
		var foco: bool = _foco == "botoes" and i == _bsel
		var ativo: bool = b.ativo
		_tela.draw_rect(r, Interface.cor("destaque") if foco else Color(0.3, 0.35, 0.5, 0.9 if ativo else 0.4))
		_tela.draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(0.14, 0.15, 0.24) if foco else Color(0.08, 0.09, 0.15))
		var cor_b: Color = (Color(1, 0.95, 0.6) if foco else Color(0.85, 0.88, 0.95)) if ativo else Color(0.4, 0.42, 0.5)
		_txt(r.position + Vector2(0, 11), str(b.txt), 8, cor_b, r.size.x)
	if _modo == "escolher":
		var pad := not Input.get_connected_joypads().is_empty()
		var dica := "D-pad: escolher   A: pegar   Y: sortear" if pad else "Setas ou mouse: escolher   Enter ou clique: pegar   1-%d: direto" % n
		_txt(Vector2(0, 306), dica, 8, Color(0.7, 0.7, 0.8), W)
		if not botoes.is_empty():
			_txt(Vector2(0, 322), "Pular não pega nada. Banir tira a carta escolhida da corrida.", 8, Color(0.5, 0.52, 0.62), W)
	else:
		_txt(Vector2(0, 306), "Enter ou clique: continuar", 8, Color(0.7, 0.7, 0.8), W)


func _carta(i: int, ti_total: float) -> void:
	var c: Dictionary = _cartas[i]
	if ti_total < 0.0:
		return   # ainda não chegou a vez dessa carta
	var k := clampf(ti_total / ENTRADA, 0.0, 1.0)
	var u := k - 1.0
	var suave := 1.0 + 2.70158 * u * u * u + 1.70158 * u * u   # ease-out-back: passa de 1 e volta
	var esc := lerpf(0.82, 1.0, suave)
	var r := _rect_carta(i)
	var sel := i == _sel and _modo == "escolher" and _foco == "cartas"
	var larg := r.size.x
	var centro := r.position + r.size / 2 + Vector2(0, (1.0 - clampf(suave, 0, 1)) * 14.0 - (4.0 if sel else 0.0))
	_tela.draw_set_transform(centro, 0.0, Vector2(esc, esc))
	var o := -r.size / 2   # origem da carta no espaço transformado
	var est := estilo(c, _t)
	var cor: Color = est.cor
	var borda: Color = Interface.cor("destaque") if sel else cor.darkened(0.25)
	var esp := 3.0 if sel else 2.0
	_tela.draw_rect(Rect2(o - Vector2(esp, esp), r.size + Vector2(esp, esp) * 2), borda)
	_tela.draw_rect(Rect2(o, r.size), Color(0.1, 0.11, 0.18))
	# tira de título na cor do tipo + glifo da forma
	_tela.draw_rect(Rect2(o, Vector2(larg, 14)), cor.darkened(0.45))
	_tela.draw_rect(Rect2(o + Vector2(0, 13), Vector2(larg, 1)), cor)
	_glifo(str(est.glifo), o + Vector2(10, 7), 4.0, cor.lightened(0.15))
	_txt(o + Vector2(20, 11), str(est.rotulo), 8, Color.WHITE, larg - 22, HORIZONTAL_ALIGNMENT_LEFT)
	# ícone grande (3x dos 16 px originais) sobre um fundo na cor do tipo
	var cx := o.x + larg / 2
	_tela.draw_rect(Rect2(Vector2(cx - 28, o.y + 17), Vector2(56, 52)), cor.darkened(0.7))
	var tex := Dados.icone(str(c.icone))
	if tex:
		_tela.draw_texture_rect(tex, Rect2(Vector2(cx - 24, o.y + 19), Vector2(48, 48)), false)
	# NOVO! / nível e pips
	var nv := int(c.get("nivel", 0))
	var mx := int(c.get("max", 1))
	var tipo := str(c.tipo)
	if tipo in ["arma", "passivo", "equipamento"]:
		var novo := nv <= 1
		var et := "NOVO!" if novo else "NÍVEL %d" % nv
		if c.has("exclusiva") and novo:
			et = "EXCLUSIVA " + str(c.exclusiva)
		_txt(Vector2(o.x, o.y + 80), et, 8, Interface.cor("bom") if novo else Interface.cor("destaque"), larg)
		if mx > 1 and mx <= 9:
			var px := cx - (mx * 7.0 - 2.0) / 2.0
			for j in mx:
				var pr := Rect2(Vector2(px + j * 7.0, o.y + 85), Vector2(5, 5))
				if j < nv - 1:
					_tela.draw_rect(pr, Interface.cor("destaque"))
				elif j == nv - 1:
					_tela.draw_rect(pr, Interface.cor("bom").lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 8)))   # o pip que você ganha
				else:
					_tela.draw_rect(pr, Color(0.25, 0.27, 0.36))
	elif tipo == "dadiva":
		# raridade aparece só aqui (a tira do topo diz DÁDIVA): filetes na cor da raridade e o nome em destaque
		var rar := str(c.get("rar_nome", ""))
		_tela.draw_rect(Rect2(o + Vector2(10, 76), Vector2(larg - 20, 1)), cor)
		_txt(Vector2(o.x, o.y + 78), rar, 12, cor, larg, HORIZONTAL_ALIGNMENT_CENTER, Dados.fonte_titulo)
		_tela.draw_rect(Rect2(o + Vector2(10, 94), Vector2(larg - 20, 1)), cor)
	elif tipo == "comportamento":   # carta rara: deixa claro que muda o jeito da arma, não só um número
		_txt(Vector2(o.x, o.y + 80), str(c.get("arma_nome", "")), 8, Interface.cor("destaque"), larg)
	_tela.draw_multiline_string(Dados.fonte_titulo, o + Vector2(4, 104), str(c.nome), HORIZONTAL_ALIGNMENT_CENTER, larg - 8, 12, 1, Color.WHITE)
	# antes > depois (o atributo que muda, com o valor novo em destaque)
	var y := o.y + 132.0
	var cmp: Array = c.get("cmp", [])
	for ln in cmp:
		var ant := str(ln.antes)
		var esq := str(ln.rot) + " " + ant
		var tw := 0.0
		var sep := ">" if ant != "" else ""
		var f: Font = Dados.fonte
		tw = f.get_string_size(esq + sep + str(ln.depois), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var x := o.x + (larg - tw) / 2
		_txt(Vector2(x, y), esq, 8, Color(0.7, 0.73, 0.82), -1, HORIZONTAL_ALIGNMENT_LEFT)
		x += f.get_string_size(esq, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		if sep != "":
			_txt(Vector2(x, y), sep, 8, Color(0.55, 0.57, 0.68), -1, HORIZONTAL_ALIGNMENT_LEFT)
			x += 8.0
		_txt(Vector2(x, y), str(ln.depois), 8, Interface.cor("bom") if ln.bom else Interface.cor("ruim"), -1, HORIZONTAL_ALIGNMENT_LEFT)
		y += 11.0
	# descrição: só quando a carta não é um "nível" de algo que já tem (aí o antes > depois já diz tudo)
	if not (tipo in ["arma", "passivo"] and nv > 1):
		_tela.draw_multiline_string(Dados.fonte, Vector2(o.x + 4, y + 4.0), str(c.desc), HORIZONTAL_ALIGNMENT_CENTER, larg - 8, 8, 4, Color(0.75, 0.78, 0.85))
	if _modo == "escolher":
		_txt(o + Vector2(larg - 12, 11), str(i + 1), 8, Color(0.75, 0.78, 0.9, 0.8), -1, HORIZONTAL_ALIGNMENT_LEFT)
	_tela.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
