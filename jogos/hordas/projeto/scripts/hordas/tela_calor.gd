extends CanvasLayer
## Tela do Calor (#63): antes da corrida (depois de escolher o herói; no online, o anfitrião abre com C no lobby).
## Cima/baixo escolhem o modificador, esquerda/direita mudam o nível, 0 zera tudo, Enter confirma, Esc volta.
## Mostra o calor total, a recompensa (mais ouro e XP por ponto) e a descrição do modificador escolhido.
## Uso: var t := TelaCalor.new(); t.escolha = {...}; add_child(t); t.fechou.connect(func(ok, escolha): ...)

signal fechou(confirmou: bool, escolha: Dictionary)

const Calor := preload("res://scripts/hordas/calor.gd")
const W := 640.0
const H := 360.0
const Y0 := 66.0
const PASSO := 22.0

var escolha := {}  # {id: nível}
var titulo_confirmar := "começar"
var _sel := 0
var _quadro := 0
var _t := 0.0
var _tela := Control.new()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	escolha = Calor.validar(escolha)
	_quadro = Engine.get_process_frames()  # a tecla que abriu a tela não conta aqui
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


func _process(dt: float) -> void:
	_t += dt
	_tela.queue_redraw()
	if Engine.get_process_frames() == _quadro:
		return
	var mods := Calor.modificadores()
	var n := mods.size()
	if n == 0:
		return
	if Input.is_action_just_pressed("cima"):
		_sel = (_sel - 1 + n) % n
		Som.ui("cursor")
	elif Input.is_action_just_pressed("baixo"):
		_sel = (_sel + 1) % n
		Som.ui("cursor")
	elif Input.is_action_just_pressed("direita") or Input.is_action_just_pressed("esquerda"):
		var m: Dictionary = mods[_sel]
		var id := str(m.id)
		var maxn := int(m.get("niveis", 1))
		var passo := 1 if Input.is_action_just_pressed("direita") else -1
		var nv := (int(escolha.get(id, 0)) + passo + maxn + 1) % (maxn + 1)  # dá a volta: 0..max
		if nv == 0:
			escolha.erase(id)
		else:
			escolha[id] = nv
		Som.ui("cursor")
	elif Input.is_action_just_pressed("confirmar"):
		Som.ui("confirmar")
		Calor.salvar(escolha)
		fechou.emit(true, escolha.duplicate())
		queue_free()
	elif Input.is_action_just_pressed("voltar"):
		Som.ui("voltar")
		Calor.salvar(escolha)
		fechou.emit(false, escolha.duplicate())
		queue_free()


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_pressed() and not e.is_echo() and e.physical_keycode == KEY_0:
		escolha.clear()  # 0: zera tudo
		Som.ui("voltar")


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := W, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	_tela.draw_string(Dados.fonte, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, 0.8))
	_tela.draw_string(Dados.fonte, p, s, alinhar, larg, tam, cor)


## Chama de pixel (o símbolo do calor), centrada em c, altura h.
func _chama(c: Vector2, h: float, f: float) -> void:
	var balanco := sin(_t * 9.0) * h * 0.06
	var fora := PackedVector2Array(
		[
			c + Vector2(-h * 0.36, 0),
			c + Vector2(-h * 0.42, -h * 0.4),
			c + Vector2(-h * 0.12 + balanco, -h * 0.72),
			c + Vector2(balanco, -h),
			c + Vector2(h * 0.2 + balanco, -h * 0.62),
			c + Vector2(h * 0.4, -h * 0.38),
			c + Vector2(h * 0.34, 0)
		]
	)
	_tela.draw_colored_polygon(fora, Color(0.9, 0.3, 0.08).lerp(Color(1, 0.55, 0.1), f))
	var dentro := PackedVector2Array(
		[c + Vector2(-h * 0.18, 0), c + Vector2(-h * 0.2, -h * 0.3), c + Vector2(balanco, -h * 0.58), c + Vector2(h * 0.18, -h * 0.3), c + Vector2(h * 0.16, 0)]
	)
	_tela.draw_colored_polygon(dentro, Color(1, 0.85, 0.35))


func _desenhar() -> void:
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.03, 0.04, 0.99))
	_txt(Vector2(0, 32), "Calor", 16, Color(1, 0.75, 0.4))
	_txt(Vector2(0, 48), "Deixe a corrida mais difícil. Cada ponto de calor rende mais ouro e XP.", 8, Color(0.7, 0.66, 0.62))
	var pts := Calor.pontos(escolha)
	var frac := clampf(float(pts) / maxf(1.0, Calor.maximo()), 0.0, 1.0)
	_chama(Vector2(560, 40), 24.0 + 10.0 * frac, frac)
	_txt(Vector2(578, 36), str(pts), 16, Color(1, 0.85, 0.5), 60, HORIZONTAL_ALIGNMENT_LEFT)
	var mods := Calor.modificadores()
	for i in mods.size():
		var m: Dictionary = mods[i]
		var y := Y0 + i * PASSO
		var sel := i == _sel
		var nv := int(escolha.get(str(m.id), 0))
		if sel:
			_tela.draw_rect(Rect2(96, y - 2, 448, PASSO - 3), Color(0.35, 0.15, 0.08, 0.6))
			_tela.draw_rect(Rect2(96, y - 2, 448, PASSO - 3), Color(1, 0.6, 0.3), false, 1.0)
		var cor := Color(1, 0.85, 0.55) if nv > 0 else Color(0.72, 0.7, 0.7)
		_txt(Vector2(106, y + 12), str(m.get("nome", m.id)), 8, cor, 260, HORIZONTAL_ALIGNMENT_LEFT)
		# um quadradinho por nível: cheio = ligado
		var maxn := int(m.get("niveis", 1))
		for k in maxn:
			var r := Rect2(420 + k * 16, y + 4, 11, 9)
			_tela.draw_rect(r, Color(0.95, 0.45, 0.15) if k < nv else Color(0.2, 0.16, 0.16))
			_tela.draw_rect(r, Color(1, 0.75, 0.4) if k < nv else Color(0.4, 0.33, 0.3), false, 1.0)
		_txt(Vector2(486, y + 12), "+%d" % int(m.get("calor", 1)), 8, Color(0.85, 0.55, 0.35), 50, HORIZONTAL_ALIGNMENT_RIGHT)
	if _sel < mods.size():
		_txt(Vector2(0, 274), str(mods[_sel].get("descricao", "")), 8, Color(0.9, 0.86, 0.8))
	var ouro := roundi(pts * Calor.recompensa("ouro") * 100.0)
	var xp := roundi(pts * Calor.recompensa("xp") * 100.0)
	_txt(
		Vector2(0, 296),
		"Recompensa: +%d%% de ouro, +%d%% de XP" % [ouro, xp] if pts > 0 else "Sem calor: a corrida normal.",
		8,
		Color(1, 0.8, 0.45) if pts > 0 else Color(0.6, 0.6, 0.65)
	)
	_txt(Vector2(0, 340), "Cima/baixo: escolher   Esq/dir: nível   0: zerar   Enter: %s   Esc: voltar" % titulo_confirmar, 8, Color(0.55, 0.52, 0.5))
