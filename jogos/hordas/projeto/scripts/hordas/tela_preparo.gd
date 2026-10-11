extends CanvasLayer
## Tela de Preparo e Baú pessoal (#72, marcos 3 e 4). Dois modos, a mesma tela:
##   "preparo": antes da corrida, depois de escolher o herói criado. Monta a mochila com o que há no baú: comida de viagem, consumíveis
##     (teclas 1, 2, 3 na corrida) e 1 amuleto. Mostra os espaços, o que cada item faz e como a ficha do herói muda. Enter começa.
##   "bau": entre corridas (na lista "Meus heróis"). Só olha o baú; Delete descarta uma unidade (com confirmação).
## Teclado, mouse e controle: cima/baixo escolhem o item, esquerda/direita mudam quanto levar, Enter confirma, Esc volta.
## Uso: var t := TelaPreparo.new(); t.heroi_id = id; t.bau = {...}; t.mochila = {...}; add_child(t); t.fechou.connect(func(ok, mochila): ...)

signal fechou(confirmou: bool, mochila: Dictionary)
signal descartou(id: String)  # modo baú: o jogador jogou uma unidade fora (quem abriu a tela grava o baú)

const Mochila := preload("res://scripts/hordas/mochila.gd")
const Criacao := preload("res://scripts/hordas/criacao.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
const Interface := preload("res://scripts/hordas/interface.gd")
const W := 640.0
const H := 360.0
const Y0 := 78.0
const LIN := 15.0
const VISIVEIS := 14
const ROTULO_TIPO := {"comida": "COMIDA DE VIAGEM", "consumivel": "CONSUMÍVEIS (teclas 1, 2, 3)", "amuleto": "AMULETOS (1 no pescoço)"}

var heroi_id := ""
var modo := "preparo"
var bau := {}  # {id: n} o que o herói tem em casa
var mochila := {}  # a escolha atual (preparo)
var _raca := ""
var _classe := ""
var _heroi := {}
var _itens: Array = []  # ids que aparecem (os que há no baú ou que estão na mochila), na ordem do catálogo
var _sel := 0
var _topo := 0  # primeira linha visível
var _confirma_descartar := ""
var _msg := ""
var _msg_t := 0.0
var _quadro := 0
var _t := 0.0
var _retas_item: Array = []  # [id, Rect2 da linha] das linhas desenhadas (o clique usa as mesmas contas do desenho)
var _retas_mais: Array = []
var _retas_menos: Array = []
var _r_ok := Rect2()
var _r_voltar := Rect2()
var _tela := Control.new()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_quadro = Engine.get_process_frames()
	_heroi = Dados.json("herois").get(heroi_id, {})
	_raca = str(_heroi.get("raca", ""))
	_classe = str(_heroi.get("classe", ""))
	if modo == "preparo":
		mochila = Mochila.ajustar_ao_bau(mochila, bau, heroi_id)
	_refazer()
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


func _refazer() -> void:
	_itens = []
	for id in Mochila.lista():
		if int(bau.get(id, 0)) > 0:
			_itens.append(id)
	_sel = clampi(_sel, 0, maxi(0, _itens.size() - 1))
	_rolar()


func _levando(id: String) -> int:
	if Mochila.tipo(id) == "amuleto":
		return 1 if str(mochila.get("amuleto", "")) == id else 0
	return int(mochila.get("itens", {}).get(id, 0))


## O que cabe na tela: a lista é de linhas (cabeçalho de grupo + itens), e a seleção precisa ficar visível.
func _linhas() -> Array:
	var r := []
	var ult := ""
	for id in _itens:
		var t := Mochila.tipo(id)
		if t != ult:
			r.append({"cab": ROTULO_TIPO.get(t, t)})
			ult = t
		r.append({"id": id})
	return r


func _rolar() -> void:
	var l := _linhas()
	var i := 0
	for k in l.size():
		if l[k].has("id") and l[k].id == (_itens[_sel] if _sel < _itens.size() else ""):
			i = k
	if i < _topo:
		_topo = i
		if _topo > 0 and l[_topo - 1].has("cab"):
			_topo -= 1
	elif i >= _topo + VISIVEIS:
		_topo = i - VISIVEIS + 1
	_topo = clampi(_topo, 0, maxi(0, l.size() - VISIVEIS))


func _process(dt: float) -> void:
	_t += dt
	_msg_t = maxf(0.0, _msg_t - dt)
	_tela.queue_redraw()
	if Engine.get_process_frames() == _quadro:
		return
	if _confirma_descartar != "":
		if Input.is_action_just_pressed("confirmar"):
			_descartar_ok()
		elif Input.is_action_just_pressed("voltar"):
			_confirma_descartar = ""
			Som.ui("cursor")
		return
	if Input.is_action_just_pressed("cima"):
		_mover(-1)
	elif Input.is_action_just_pressed("baixo"):
		_mover(1)
	elif Input.is_action_just_pressed("esquerda"):
		_mudar(-1)
	elif Input.is_action_just_pressed("direita"):
		_mudar(1)
	elif Input.is_action_just_pressed("confirmar"):
		_ok()
	elif Input.is_action_just_pressed("voltar"):
		_voltar()


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_pressed() and not e.is_echo() and e.physical_keycode == KEY_DELETE and modo == "bau" and _confirma_descartar == "":
		_pedir_descarte()


func _input(e: InputEvent) -> void:
	if Engine.get_process_frames() == _quadro or _confirma_descartar != "":
		return
	if e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_X and modo == "bau":
		_pedir_descarte()  # controle: X descarta (o teclado usa Delete)
		return
	if e is InputEventMouseButton and e.pressed:
		var mp := _tela.get_local_mouse_position()
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_mover(-1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_mover(1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if modo == "preparo":
				var im := Interface.quem(_retas_mais, mp)
				var ie := Interface.quem(_retas_menos, mp)
				if im >= 0 or ie >= 0:
					var k := im if im >= 0 else ie
					_sel = _itens.find(_retas_item[k][0])
					_mudar(1 if im >= 0 else -1)
					return
			var ii := -1
			for k in _retas_item.size():
				if _retas_item[k][1].has_point(mp):
					ii = k
			if ii >= 0:
				_sel = _itens.find(_retas_item[ii][0])
				Som.ui("cursor")
			elif _r_ok.has_point(mp):
				_ok()
			elif _r_voltar.has_point(mp):
				_voltar()


func _mover(d: int) -> void:
	if _itens.is_empty():
		return
	_sel = (_sel + d + _itens.size()) % _itens.size()
	_rolar()
	Som.ui("cursor")


func _aviso(s: String) -> void:
	_msg = s
	_msg_t = 3.0
	Som.ui("erro")


## Leva mais (+1) ou menos (-1) do item escolhido. O que não cabe é recusado com o motivo.
func _mudar(d: int) -> void:
	if modo != "preparo" or _itens.is_empty():
		return
	var id: String = _itens[_sel]
	var novo: Dictionary = mochila.duplicate(true)
	if Mochila.tipo(id) == "amuleto":
		novo["amuleto"] = id if d > 0 else ("" if str(mochila.get("amuleto", "")) == id else str(mochila.get("amuleto", "")))
	else:
		var q := _levando(id) + d
		if q > int(bau.get(id, 0)):
			_aviso("Só tem %d no baú." % int(bau.get(id, 0)))
			return
		if q > int(Mochila.item(id).get("max", 1)):
			_aviso("Só cabe %d desse na mochila." % int(Mochila.item(id).get("max", 1)))
			return
		if q < 0:
			return
		if q == 0:
			novo.itens.erase(id)
		else:
			novo.itens[id] = q
	var e := Mochila.erro(novo, _raca, _classe)
	if e != "":
		_aviso(e.substr(0, 1).to_upper() + e.substr(1) + ".")
		return
	if novo == mochila:
		return
	mochila = novo
	Som.ui("cursor")


func _ok() -> void:
	if modo == "preparo":
		Som.ui("confirmar")
		fechou.emit(true, mochila.duplicate(true))
		queue_free()
	else:
		_voltar()


func _voltar() -> void:
	Som.ui("voltar")
	fechou.emit(false, mochila.duplicate(true))
	queue_free()


func _pedir_descarte() -> void:
	if _itens.is_empty():
		return
	_confirma_descartar = _itens[_sel]
	Som.ui("erro")


func _descartar_ok() -> void:
	var id := _confirma_descartar
	_confirma_descartar = ""
	if int(bau.get(id, 0)) <= 0:
		return
	bau[id] = int(bau[id]) - 1
	if int(bau[id]) <= 0:
		bau.erase(id)
	descartou.emit(id)
	Som.ui("voltar")
	_refazer()


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := W, alinhar := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_tela.draw_string(Dados.fonte, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, 0.8))
	_tela.draw_string(Dados.fonte, p, s, alinhar, larg, tam, cor)


func _txt_c(y: float, s: String, tam := 8, cor := Color.WHITE) -> void:
	_txt(Vector2(0, y), s, tam, cor, W, HORIZONTAL_ALIGNMENT_CENTER)


## Bônus de atributos que a mochila atual dá (comida e amuleto; as poções não, elas só valem quando usadas).
func _bonus_mochila(m: Dictionary) -> Dictionary:
	var b := {}
	for id in Mochila.comidas(m):
		for k in Mochila.item(id).get("bonus", {}):
			b[k] = float(b.get(k, 0.0)) + float(Mochila.item(id).bonus[k])
	var am := str(m.get("amuleto", ""))
	if am != "":
		for k in Mochila.item(am).get("bonus", {}):
			b[k] = float(b.get(k, 0.0)) + float(Mochila.item(am).bonus[k])
	return b


func _desenhar() -> void:
	_retas_item = []
	_retas_mais = []
	_retas_menos = []
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.045, 0.07, 0.99))
	var nome := str(_heroi.get("nome", "Herói"))
	var cap := Mochila.capacidade(_raca, _classe)
	if modo == "preparo":
		_txt_c(26, "Preparo", 16, Color(1, 0.85, 0.5))
		_txt_c(42, "%s: monte a mochila com o que há no baú." % nome, 8, Color(0.7, 0.68, 0.75))
	else:
		_txt_c(26, "Baú de %s" % nome, 16, Color(1, 0.85, 0.5))
		_txt_c(42, "Guardado em casa entre as corridas. Se o herói morre, o baú some junto.", 8, Color(0.85, 0.6, 0.55))
	# faixa de capacidade
	if modo == "preparo":
		var usados := Mochila.espacos(mochila)
		_txt(Vector2(10, 62), "Mochila %d/%d espaços" % [usados, cap], 8, Color(1, 0.9, 0.55) if usados < cap else Color(1, 0.6, 0.45), 200)
		for i in cap:
			var r := Rect2(172 + i * 9, 55, 7, 9)
			_tela.draw_rect(r, Color(0.95, 0.75, 0.3) if i < usados else Color(0.18, 0.17, 0.22))
		var cf := Mochila.cfg()
		_txt(
			Vector2(272, 62),
			(
				"Comida %d/%d   Poções %d/%d"
				% [Mochila.comida_n(mochila), int(cf.get("max_comida", 2)), Mochila.tipos_consumivel(mochila), int(cf.get("max_consumiveis", 3))]
			),
			8,
			Color(0.75, 0.78, 0.9),
			300
		)
	else:
		var ocup := Mochila.bau_espacos(bau)
		_txt(Vector2(10, 62), "Baú %d/%d espaços" % [ocup, Mochila.bau_max()], 8, Color(1, 0.9, 0.55) if ocup < Mochila.bau_max() else Color(1, 0.6, 0.45), 200)
		_txt(Vector2(272, 62), "O que não couber ao trazer pra casa se perde.", 8, Color(0.6, 0.62, 0.72), 360)
	# lista (esquerda)
	var l := _linhas()
	var y := Y0
	for k in range(_topo, mini(l.size(), _topo + VISIVEIS)):
		var ln: Dictionary = l[k]
		if ln.has("cab"):
			_txt(Vector2(10, y + 10), str(ln.cab), 8, Color(0.55, 0.6, 0.8), 320)
			y += LIN
			continue
		var id: String = ln.id
		var sel: bool = _itens[_sel] == id
		var linha := Rect2(8, y - 1, 322, LIN - 1)
		_retas_item.append([id, linha])
		if sel:
			_tela.draw_rect(linha, Color(0.25, 0.2, 0.1, 0.7))
			_tela.draw_rect(linha, Color(1, 0.8, 0.35), false, 1.0)
		var lev := _levando(id)
		Mochila.desenhar_icone(_tela, id, Rect2(12, y, 12, 12))
		_txt(Vector2(30, y + 9), Mochila.nome(id), 8, Color(1, 0.93, 0.7) if lev > 0 else Color(0.82, 0.82, 0.88), 180)
		if modo == "preparo":
			_txt(Vector2(206, y + 9), "baú %d" % int(bau.get(id, 0)), 8, Color(0.6, 0.62, 0.72), 50)
			var mx := 262.0
			var rm := Rect2(mx, y, 12, 12)
			var rp := Rect2(mx + 50, y, 12, 12)
			_retas_menos.append(rm)
			_retas_mais.append(rp)
			_tela.draw_rect(rm, Color(0.2, 0.2, 0.28))
			_tela.draw_rect(rp, Color(0.2, 0.2, 0.28))
			_txt(Vector2(rm.position.x, y + 9), "-", 8, Color.WHITE, 12, HORIZONTAL_ALIGNMENT_CENTER)
			_txt(Vector2(rp.position.x, y + 9), "+", 8, Color.WHITE, 12, HORIZONTAL_ALIGNMENT_CENTER)
			_txt(Vector2(mx + 13, y + 9), str(lev), 8, Color(0.5, 1, 0.6) if lev > 0 else Color(0.5, 0.5, 0.58), 36, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_txt(Vector2(240, y + 9), "x%d" % int(bau.get(id, 0)), 8, Color(1, 1, 1), 80, HORIZONTAL_ALIGNMENT_RIGHT)
		y += LIN
	if _itens.is_empty():
		_txt(Vector2(10, Y0 + 20), "O baú está vazio.", 8, Color(0.6, 0.6, 0.68), 300)
	if l.size() > VISIVEIS:
		_txt(
			Vector2(10, Y0 + VISIVEIS * LIN + 8),
			("^ " if _topo > 0 else "  ") + ("v mais abaixo" if _topo + VISIVEIS < l.size() else ""),
			8,
			Color(0.5, 0.52, 0.62),
			300
		)
	# painel do item (direita)
	_tela.draw_rect(Rect2(342, 72, 290, 236), Color(0.09, 0.085, 0.13))
	_tela.draw_rect(Rect2(342, 72, 290, 236), Color(0.3, 0.32, 0.45), false, 1.0)
	if not _itens.is_empty():
		_painel_item(str(_itens[_sel]))
	# a ficha do herói com a mochila (preparo)
	if modo == "preparo":
		_ficha()
	# rodapé
	if _msg_t > 0.0:
		_txt_c(322, _msg, 8, Color(1, 0.5, 0.45))
	var dica := (
		"Cima/baixo: item   Esq/dir: levar   Enter: começar   Esc: voltar"
		if modo == "preparo"
		else "Cima/baixo: item   Delete (X no controle): descartar 1   Esc: voltar"
	)
	_txt_c(346, dica, 8, Color(0.55, 0.55, 0.62))
	if modo == "preparo":
		_r_ok = Rect2(500, 314, 130, 20)
		_tela.draw_rect(_r_ok, Color(0.2, 0.45, 0.25))
		_tela.draw_rect(_r_ok, Color(0.6, 1, 0.65), false, 1.0)
		_txt(Vector2(500, 328), "Começar", 8, Color.WHITE, 130, HORIZONTAL_ALIGNMENT_CENTER)
	_r_voltar = Rect2(10, 314, 80, 20)
	_tela.draw_rect(_r_voltar, Color(0.18, 0.18, 0.26))
	_tela.draw_rect(_r_voltar, Color(0.45, 0.45, 0.6), false, 1.0)
	_txt(Vector2(10, 328), "Voltar", 8, Color.WHITE, 80, HORIZONTAL_ALIGNMENT_CENTER)
	if _confirma_descartar != "":
		_tela.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.75))
		_tela.draw_rect(Rect2(130, 130, 380, 90), Color(0.1, 0.06, 0.06))
		_tela.draw_rect(Rect2(130, 130, 380, 90), Color(1, 0.4, 0.35), false, 2.0)
		_txt_c(158, "Jogar fora 1 %s?" % Mochila.nome(_confirma_descartar), 8, Color(1, 0.8, 0.7))
		_txt_c(180, "Não volta.", 8, Color(1, 0.55, 0.5))
		_txt_c(204, "Enter: descartar   Esc: cancelar", 8, Color(0.8, 0.8, 0.85))


func _painel_item(id: String) -> void:
	var d := Mochila.item(id)
	var x := 352.0
	Mochila.desenhar_icone(_tela, id, Rect2(x, 80, 28, 28))
	_txt(Vector2(x + 36, 92), Mochila.nome(id), 8, Color(1, 0.93, 0.65), 240)
	var tipo := str(d.get("tipo", ""))
	var sub := "Comida" if tipo == "comida" else ("Consumível" if tipo == "consumivel" else "Amuleto")  # "Comida de viagem" + "ocupa 1 espaço" passava da borda do painel (~240 px úteis)
	var esp := int(d.get("espacos", 1))
	sub += ("  ocupa %d espaço%s" % [esp, "s" if esp != 1 else ""]) if esp > 0 else "  não ocupa espaço"
	_txt(Vector2(x + 36, 105), sub, 8, Color(0.6, 0.68, 0.9), 240)
	_tela.draw_multiline_string(Dados.fonte, Vector2(x, 126), str(d.get("descricao", "")), HORIZONTAL_ALIGNMENT_LEFT, 270, 8, 4, Color(0.82, 0.84, 0.92))
	var y := 172.0
	for par in Mochila.linhas(id):
		_txt(Vector2(x, y), str(par[0]), 8, Color(0.5, 1, 0.55) if par[1] else Color(1, 0.55, 0.5), 270)
		y += 12.0
	# amuleto: comparação com o que já está no pescoço (a diferença líquida de atributos)
	if modo == "preparo" and tipo == "amuleto":
		var atual := str(mochila.get("amuleto", ""))
		if atual != "" and atual != id:
			y += 4.0
			_txt(Vector2(x, y), "Trocando o %s:" % Mochila.nome(atual), 8, Color(0.75, 0.75, 0.55), 280)
			y += 12.0
			var dif := {}
			for k in Mochila.item(id).get("bonus", {}):
				dif[k] = float(Mochila.item(id).bonus[k])
			for k in Mochila.item(atual).get("bonus", {}):
				dif[k] = float(dif.get(k, 0.0)) - float(Mochila.item(atual).bonus[k])
			for par in Criacao.descrever(dif):
				_txt(Vector2(x, y), str(par[0]), 8, Color(0.5, 1, 0.55) if par[1] else Color(1, 0.55, 0.5), 270)
				y += 12.0
		elif atual == id:
			_txt(Vector2(x, y + 4), "No pescoço.", 8, Color(0.6, 0.9, 0.6), 270)
	if modo == "preparo" and tipo != "amuleto":
		_txt(Vector2(x, 292), "Levando: %d   Baú: %d" % [_levando(id), int(bau.get(id, 0))], 8, Color(0.75, 0.78, 0.9), 270)


## Vida, dano, velocidade e crítico do herói: sem a mochila e com ela (comida e amuleto).
func _ficha() -> void:
	var b0 := Construcao.stats(_heroi, {}, {}, {})
	var b1 := Construcao.stats(_heroi, {}, {}, _bonus_mochila(mochila))
	var x := 352.0
	var y := 232.0
	_txt(Vector2(x, y), "Ficha com a mochila:", 8, Color(0.75, 0.75, 0.55), 270)
	var cols := [["Vida", "vida_max", false], ["Dano", "dano", true], ["Veloc.", "velocidade", true], ["Crít.", "critico", true], ["Regen", "regen", false]]
	var i := 0
	for c in cols:
		var a := float(b0[c[1]])
		var b := float(b1[c[1]])
		var cx := x + (i % 2) * 140.0
		var cy := y + 13.0 + (i / 2) * 12.0
		var f := func(v: float) -> String:
			return ("%d%%" % roundi(v * 100.0)) if c[2] else (("%.1f" % v).replace(".", ",") if c[1] == "regen" else str(roundi(v)))
		var txt := "%s %s" % [c[0], f.call(a)]
		var cor := Color(0.78, 0.8, 0.9)
		if not is_equal_approx(a, b):
			txt += ">" + f.call(b)
			cor = Color(0.5, 1, 0.55) if b > a else Color(1, 0.55, 0.5)
		_txt(Vector2(cx, cy), txt, 8, cor, 140)
		i += 1
