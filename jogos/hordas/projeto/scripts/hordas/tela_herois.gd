extends CanvasLayer
## Meus heróis (#72, marco 2): até 6 heróis criados salvos. Setas escolhem a vaga; Enter joga com o herói (ou cria, se a vaga
## está vazia); Delete ou X apaga, com confirmação (apagar é pra sempre, como se ele tivesse morrido). Esc volta.
## Uso: var t := TelaHerois.new(); add_child(t); t.jogar.connect(func(id): ...); t.fechou.connect(func(): ...)

signal jogar(id: String)
signal fechou

const Criacao := preload("res://scripts/hordas/criacao.gd")
const Paleta := preload("res://scripts/hordas/paleta.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
const TelaCriacao := preload("res://scripts/hordas/tela_criacao.gd")
const TelaPreparo := preload("res://scripts/hordas/tela_preparo.gd")
const Mochila := preload("res://scripts/hordas/mochila.gd")
const W := 640.0
const H := 360.0
const COLUNAS := 3

var sel := 0
var confirmando := ""        # id do herói que o jogador está prestes a apagar ("" = não está)
var _ids: Array = []
var _quadro := 0
var _t := 0.0
var _msg := ""
var _msg_t := 0.0
var _criando := false
var _tela := Control.new()


func _ready() -> void:
	layer = 29
	process_mode = Node.PROCESS_MODE_ALWAYS
	_quadro = Engine.get_process_frames()
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)
	_recarregar()


func _recarregar() -> void:
	_ids = Criacao.carregar(false).ids
	sel = clampi(sel, 0, Criacao.MAX_HEROIS - 1)


func _rect_vaga(i: int) -> Rect2:
	return Rect2(10 + (i % COLUNAS) * 210, 60 + (i / COLUNAS) * 122, 200, 114)


func _process(dt: float) -> void:
	_t += dt
	_msg_t = maxf(0.0, _msg_t - dt)
	_tela.queue_redraw()


func _input(e: InputEvent) -> void:
	if Engine.get_process_frames() == _quadro or _criando:
		return
	if e is InputEventKey and e.pressed:
		get_viewport().set_input_as_handled()
		if confirmando != "":
			if e.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				Criacao.apagar(confirmando)
				confirmando = ""
				_recarregar()
				Som.ui("voltar")
			elif e.keycode == KEY_ESCAPE:
				confirmando = ""
				Som.ui("cursor")
			return
		match e.keycode:
			KEY_LEFT, KEY_A:
				_ir(-1, 0)
			KEY_RIGHT, KEY_D:
				_ir(1, 0)
			KEY_UP, KEY_W:
				_ir(0, -1)
			KEY_DOWN, KEY_S:
				_ir(0, 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_E:
				_escolher()
			KEY_B:
				_abrir_bau()
			KEY_DELETE, KEY_X:
				_apagar()
			KEY_ESCAPE:
				Som.ui("voltar")
				fechou.emit()
				queue_free()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and confirmando == "":
		var mp := _tela.get_local_mouse_position()
		for i in Criacao.MAX_HEROIS:
			if _rect_vaga(i).has_point(mp):
				sel = i
				_escolher()
				break


func _ir(dx: int, dy: int) -> void:
	var n := Criacao.MAX_HEROIS
	var linhas := n / COLUNAS
	var x := (sel % COLUNAS + dx + COLUNAS) % COLUNAS
	var y := (sel / COLUNAS + dy + linhas) % linhas
	sel = y * COLUNAS + x
	Som.ui("cursor")


func _escolher() -> void:
	if sel < _ids.size():
		Som.ui("confirmar")
		jogar.emit(str(_ids[sel]))
		queue_free()
		return
	_criando = true
	var t := TelaCriacao.new()
	add_child(t)
	t.fechou.connect(func(ok: bool, id: String):
		_criando = false
		_quadro = Engine.get_process_frames()
		if ok:
			jogar.emit(id)
			queue_free()
		else:
			_recarregar())


## B: o baú pessoal do herói da vaga (só olhar e descartar). O baú morre junto com o herói.
func _abrir_bau() -> void:
	if sel >= _ids.size():
		return
	var id := str(_ids[sel])
	_criando = true   # a tela do baú é que escuta as teclas agora
	var t := TelaPreparo.new()
	t.modo = "bau"
	t.heroi_id = id
	t.bau = Mochila.bau_limpo(Criacao.bau_de(id))
	add_child(t)
	t.descartou.connect(func(_i: String): Criacao.definir_bau(id, t.bau))
	t.fechou.connect(func(_ok: bool, _m: Dictionary):
		_criando = false
		_quadro = Engine.get_process_frames())


func _apagar() -> void:
	if sel >= _ids.size():
		return
	confirmando = str(_ids[sel])
	Som.ui("erro")


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := W, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	_tela.draw_string(Dados.fonte, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, 0.8))
	_tela.draw_string(Dados.fonte, p, s, alinhar, larg, tam, cor)


func _desenhar() -> void:
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.04, 0.07, 0.99))
	_txt(Vector2(0, 28), "Meus heróis", 16, Color(1, 0.85, 0.45))
	_txt(Vector2(0, 46), "%d de %d vagas. Herói que morre some de vez." % [_ids.size(), Criacao.MAX_HEROIS], 8, Color(1, 0.6, 0.5))
	for i in Criacao.MAX_HEROIS:
		var q := _rect_vaga(i)
		var ativo := i == sel
		_tela.draw_rect(q.grow(2) if ativo else q, Color(1, 0.85, 0.3) if ativo else Color(0.3, 0.35, 0.5))
		_tela.draw_rect(q, Color(0.1, 0.11, 0.18))
		if i >= _ids.size():
			_txt(Vector2(q.position.x, q.position.y + 54), "+ Criar herói", 8, Color(0.75, 0.78, 0.9) if ativo else Color(0.5, 0.52, 0.62), q.size.x)
			_txt(Vector2(q.position.x, q.position.y + 70), "vaga livre", 8, Color(0.4, 0.42, 0.52), q.size.x)
			continue
		var id := str(_ids[i])
		var h: Dictionary = Dados.json("herois").get(id, {})
		var rosto := Paleta.textura(str(h.get("sprite", "hazaki")), "rosto", h.get("paleta", {}))
		if rosto:
			_tela.draw_texture_rect_region(rosto, Rect2(q.position + Vector2(8, 8), Vector2(52, 52)), Rect2(0, 0, 52, 52))
		_txt(q.position + Vector2(66, 20), str(h.get("nome", id)), 8, Color(1, 0.95, 0.7), 128, HORIZONTAL_ALIGNMENT_LEFT)
		_txt(q.position + Vector2(66, 32), str(h.get("titulo", "")), 8, Color(0.6, 0.85, 1), 128, HORIZONTAL_ALIGNMENT_LEFT)
		var arma := Dados.item(str(h.get("arma", "")))
		var ic := Dados.icone(str(arma.get("icone", "")))
		if ic:
			_tela.draw_texture_rect(ic, Rect2(q.position + Vector2(8, 64), Vector2(16, 16)), false)
		_txt(q.position + Vector2(28, 76), str(arma.get("nome", "")), 8, Color(1, 0.9, 0.5), 168, HORIZONTAL_ALIGNMENT_LEFT)
		var s := Construcao.stats(h, {}, {})
		_txt(q.position + Vector2(8, 92), "Vida %d  Dano %d%%" % [roundi(s.vida_max), roundi(s.dano * 100.0)], 8, Color(0.82, 0.85, 0.95), 190, HORIZONTAL_ALIGNMENT_LEFT)
		var f: Dictionary = h.get("ficha", {})
		var def := str(f.get("defeito", ""))
		if def != "":
			_txt(q.position + Vector2(8, 106), "Defeito: " + str(Criacao.defeitos().get(def, {}).get("nome", def)), 8, Color(1, 0.65, 0.5), 190, HORIZONTAL_ALIGNMENT_LEFT)
		else:
			_txt(q.position + Vector2(8, 106), "Sem defeito", 8, Color(0.5, 0.52, 0.62), 190, HORIZONTAL_ALIGNMENT_LEFT)
	_txt(Vector2(0, 346), "Setas: vaga   Enter: jogar ou criar   B: baú   Delete: apagar   Esc: voltar", 8, Color(0.55, 0.55, 0.62))
	if confirmando != "":
		var nome := str(Dados.json("herois").get(confirmando, {}).get("nome", "o herói"))
		_tela.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.75))
		_tela.draw_rect(Rect2(130, 130, 380, 90), Color(0.1, 0.06, 0.06))
		_tela.draw_rect(Rect2(130, 130, 380, 90), Color(1, 0.4, 0.35), false, 2.0)
		_txt(Vector2(0, 158), "Apagar %s?" % nome, 16, Color(1, 0.8, 0.7))
		_txt(Vector2(0, 180), "Ele some de vez e não volta.", 8, Color(1, 0.55, 0.5))
		_txt(Vector2(0, 204), "Enter: apagar   Esc: cancelar", 8, Color(0.8, 0.8, 0.85))
