extends CanvasLayer
## Escolha de cartas ao subir de nível (ou na tomada) e a tela do baú.
## Setas/A-D escolhem, Enter/E confirmam, 1-4 escolhem direto, R re-sorteia.

const W := 640.0
const H := 360.0
const LARG := 132.0
const ALT := 170.0

var arena: Node
var _tela := Control.new()
var _modo := ""          # "", "escolher", "bau"
var _titulo := ""
var _cartas: Array = []
var _sel := 0
var _espera := 0.0
var _t := 0.0


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
	_espera = 0.35
	get_tree().paused = true
	_tela.queue_redraw()


func _fechar() -> void:
	_modo = ""
	get_tree().paused = false
	_tela.queue_redraw()


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
	if _modo == "bau":
		if Input.is_action_just_pressed("confirmar") or Input.is_action_just_pressed("voltar"):
			Som.tocar("confirmar")
			_confirmar()
		return
	if Input.is_action_just_pressed("esquerda") or Input.is_action_just_pressed("cima"):
		_sel = (_sel - 1 + _cartas.size()) % _cartas.size()
		Som.tocar("cursor")
	elif Input.is_action_just_pressed("direita") or Input.is_action_just_pressed("baixo"):
		_sel = (_sel + 1) % _cartas.size()
		Som.tocar("cursor")
	elif Input.is_action_just_pressed("confirmar"):
		_confirmar()
	elif Input.is_action_just_pressed("resortear") and arena.pode_resortear():
		_cartas = arena.gastar_resortear()
		_sel = 0
		Som.tocar("whoosh")


func _unhandled_key_input(e: InputEvent) -> void:
	if _modo != "escolher" or _espera > 0 or not e.is_pressed():
		return
	var k: int = e.physical_keycode - KEY_1
	if k >= 0 and k < _cartas.size():
		_sel = k
		_confirmar()


func _confirmar() -> void:
	if _modo == "bau":
		_fechar()
		arena.escolheu({"tipo": "nada"})
		return
	var c: Dictionary = _cartas[_sel]
	Som.tocar("confirmar")
	_fechar()
	arena.escolheu(c)


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := -1.0, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var f: Font = Dados.fonte
	_tela.draw_string(f, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, 0.8))
	_tela.draw_string(f, p, s, alinhar, larg, tam, cor)


func _desenhar() -> void:
	if _modo == "":
		return
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.02, 0.06, 0.72))
	var cor_t := Color(1, 0.85, 0.3) if _modo == "bau" else Color(0.6, 0.85, 1)
	_txt(Vector2(0, 48), _titulo, 16, cor_t, W)
	var n := _cartas.size()
	var gap := 10.0
	var x0 := (W - n * LARG - (n - 1) * gap) / 2
	for i in n:
		var c: Dictionary = _cartas[i]
		var sel := i == _sel and _modo == "escolher"
		var p := Vector2(x0 + i * (LARG + gap), 80 - (6.0 if sel else 0.0))
		var borda := Color(1, 0.85, 0.3) if sel else Color(0.35, 0.4, 0.55)
		if c.tipo == "evolucao":
			borda = Color(1, 0.4, 0.9).lerp(Color(0.4, 0.9, 1), 0.5 + 0.5 * sin(_t * 6))
		_tela.draw_rect(Rect2(p - Vector2(2, 2), Vector2(LARG + 4, ALT + 4)), borda)
		_tela.draw_rect(Rect2(p, Vector2(LARG, ALT)), Color(0.1, 0.11, 0.18))
		var tex := Dados.icone(str(c.icone))
		if tex:
			_tela.draw_texture_rect(tex, Rect2(p + Vector2(LARG / 2 - 16, 12), Vector2(32, 32)), false)
		var etiqueta := ""
		var cor_e := Color(0.5, 1, 0.5)
		match str(c.tipo):
			"evolucao":
				etiqueta = "EVOLUÇÃO"
				cor_e = Color(1, 0.5, 0.9)
			"cura":
				etiqueta = ""
			_:
				etiqueta = "NOVO!" if c.nivel == 1 else "Nível %d" % c.nivel
				cor_e = Color(0.5, 1, 0.5) if c.nivel == 1 else Color(1, 0.9, 0.5)
		_txt(p + Vector2(0, 58), etiqueta, 8, cor_e, LARG)
		_tela.draw_multiline_string(Dados.fonte, p + Vector2(6, 76), str(c.nome), HORIZONTAL_ALIGNMENT_CENTER, LARG - 12, 8, 2, Color.WHITE)
		_tela.draw_multiline_string(Dados.fonte, p + Vector2(6, 106), str(c.desc), HORIZONTAL_ALIGNMENT_CENTER, LARG - 12, 8, 6, Color(0.75, 0.78, 0.85))
		if _modo == "escolher":
			_txt(p + Vector2(4, ALT - 6), str(i + 1), 8, Color(0.5, 0.5, 0.6), -1, HORIZONTAL_ALIGNMENT_LEFT)
	if _modo == "escolher":
		var dica := "Setas: escolher   Enter/E: pegar"
		if arena.pode_resortear():
			dica += "   R: sortear de novo (%d)" % arena.resortear
		_txt(Vector2(0, 280), dica, 8, Color(0.7, 0.7, 0.8), W)
	else:
		_txt(Vector2(0, 280), "Enter: continuar", 8, Color(0.7, 0.7, 0.8), W)
