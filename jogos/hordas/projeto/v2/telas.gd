extends RefCounted
## Telas simples do combate da v2 (o HUD bonito é de outro módulo): a escolha de melhoria ao subir de nível (3 cartas), a tela de resultado
## ao morrer, um aviso grande no alto ("ONDA FORTE!") e um texto de DEPURAÇÃO com vida, nível, XP, combo e abates (desligue com F1 ou
## --sem_depur; o HUD novo não depende dele). Tudo é desenhado numa CanvasLayer dentro do SubViewport 960x540; o mouse não chega nos
## Controls de dentro dele, então o clique é lido por aqui (mundo.ap.mouse_na_tela()) e a escolha também aceita 1, 2, 3, setas e Enter.

const LARG := 960
const ALT := 540
const CARTA_L := 224.0
const CARTA_A := 200.0
const CARTA_Y := 168.0
const FOLGA := 24.0

var combate
var mundo
var camada: CanvasLayer
var depuracao := true
var aviso_t := 0.0
var sel := 0
var mostrada_t := 0.0  # s desde que a tela de resultado abriu (ignora clique logo no começo)
var resultado_aberto := false
var escolha_aberta := false

var _fundo: ColorRect
var _escolha: Control
var _cartas: Array[Control] = []
var _estilos: Array[StyleBoxFlat] = []
var _titulo: Label
var _sub: Label
var _res: Control
var _res_linhas: Label
var _res_valores: Label
var _res_dica: Label
var _aviso: Label
var _dep: Label
var _dep_t := 0.0
var _fonte: Font
var _fonte_t: Font


func montar(c, sv: Node) -> void:
	combate = c
	mundo = c.mundo
	_fonte = Dados.fonte
	_fonte_t = Dados.fonte_titulo
	camada = CanvasLayer.new()
	camada.layer = 5
	sv.add_child(camada)
	_fundo = ColorRect.new()
	_fundo.color = Color(0.02, 0.02, 0.05, 0.62)
	_fundo.size = Vector2(LARG, ALT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.visible = false
	camada.add_child(_fundo)
	_montar_escolha()
	_montar_resultado()
	_aviso = _rotulo("", 36, true, Color(1.0, 0.82, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
	_aviso.position = Vector2(0, 92)
	_aviso.size = Vector2(LARG, 48)
	_aviso.visible = false
	camada.add_child(_aviso)
	_dep = _rotulo("", 8, false, Color(0.9, 1.0, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	_dep.position = Vector2(6, 30)
	_dep.size = Vector2(500, 40)
	camada.add_child(_dep)
	depuracao = not mundo.args.has("sem_depur") and mundo.get_modo() == "livre"
	_dep.visible = depuracao


func _rotulo(texto: String, tam: int, titulo: bool, cor: Color, alin: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", _fonte_t if titulo else _fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 4 if titulo else 3)
	l.horizontal_alignment = alin
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _estilo(sel_: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.13, 0.12, 0.17, 0.97) if sel_ else Color(0.07, 0.065, 0.1, 0.96)
	s.border_color = Color(1.0, 0.82, 0.35) if sel_ else Color(0.36, 0.34, 0.45)
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)
	return s


func _montar_escolha() -> void:
	_escolha = Control.new()
	_escolha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escolha.visible = false
	camada.add_child(_escolha)
	_titulo = _rotulo("", 48, true, Color(1.0, 0.86, 0.42), HORIZONTAL_ALIGNMENT_CENTER)
	_titulo.position = Vector2(0, 60)
	_titulo.size = Vector2(LARG, 60)
	_escolha.add_child(_titulo)
	_sub = _rotulo("Escolha uma melhoria", 8, false, Color(0.85, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	_sub.position = Vector2(0, 132)
	_sub.size = Vector2(LARG, 12)
	_escolha.add_child(_sub)
	var x0 := (LARG - (3.0 * CARTA_L + 2.0 * FOLGA)) * 0.5
	for i in 3:
		var p := Panel.new()
		p.position = Vector2(x0 + i * (CARTA_L + FOLGA), CARTA_Y)
		p.size = Vector2(CARTA_L, CARTA_A)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := _estilo(false)
		p.add_theme_stylebox_override("panel", st)
		_estilos.append(st)
		var tecla := _rotulo("[%d]" % (i + 1), 8, false, Color(0.7, 0.7, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
		tecla.position = Vector2(10, 10)
		tecla.size = Vector2(60, 12)
		p.add_child(tecla)
		var nome := _rotulo("", 24, true, Color(1.0, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		nome.name = "nome"
		nome.position = Vector2(8, 36)
		nome.size = Vector2(CARTA_L - 16, 60)
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(nome)
		var desc := _rotulo("", 8, false, Color(0.88, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		desc.name = "desc"
		desc.position = Vector2(12, 106)
		desc.size = Vector2(CARTA_L - 24, 56)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(desc)
		var nv := _rotulo("", 8, false, Color(0.6, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		nv.name = "nivel"
		nv.position = Vector2(8, CARTA_A - 24)
		nv.size = Vector2(CARTA_L - 16, 12)
		p.add_child(nv)
		_escolha.add_child(p)
		_cartas.append(p)


func _montar_resultado() -> void:
	_res = Control.new()
	_res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res.visible = false
	camada.add_child(_res)
	var t := _rotulo("VOCÊ CAIU", 60, true, Color(1.0, 0.38, 0.32), HORIZONTAL_ALIGNMENT_CENTER)
	t.position = Vector2(0, 90)
	t.size = Vector2(LARG, 72)
	_res.add_child(t)
	_res_linhas = _rotulo("Tempo\nAbates\nMaior combo\nNível", 16, false, Color(0.8, 0.82, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	_res_linhas.position = Vector2(330, 196)
	_res_linhas.size = Vector2(190, 150)
	_res_linhas.add_theme_constant_override("line_spacing", 12)
	_res.add_child(_res_linhas)
	_res_valores = _rotulo("", 16, false, Color(1.0, 0.95, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
	_res_valores.position = Vector2(520, 196)
	_res_valores.size = Vector2(110, 150)
	_res_valores.add_theme_constant_override("line_spacing", 12)
	_res.add_child(_res_valores)
	_res_dica = _rotulo("ENTER ou clique para jogar de novo", 8, false, Color(1.0, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	_res_dica.position = Vector2(0, 400)
	_res_dica.size = Vector2(LARG, 12)
	_res.add_child(_res_dica)


# ------------------------------------------------------------------ mostrar


func mostrar_escolha(cartas: Array, nivel: int) -> void:
	escolha_aberta = true
	sel = 0
	_fundo.visible = true
	_escolha.visible = true
	_titulo.text = "NÍVEL %d" % nivel
	var maxn := cartas.size()
	for i in 3:
		var p := _cartas[i]
		p.visible = i < maxn
		if i >= maxn:
			continue
		var c: Dictionary = cartas[i]
		(p.get_node("nome") as Label).text = str(c.nome)
		(p.get_node("desc") as Label).text = combate.progresso.texto_carta(c)
		var feito := int(combate.progresso.melhorias.get(c.id, 0))
		(p.get_node("nivel") as Label).text = "nível %d/%d" % [feito + 1, int(c.max)] if int(c.max) < 99 else ""
	_marcar()
	combate.audio.tocar("carta", 1.0, 0.0, 0.0)


func _marcar() -> void:
	for i in 3:
		_estilos[i].bg_color = _estilo(i == sel).bg_color
		_estilos[i].border_color = _estilo(i == sel).border_color
		_cartas[i].position.y = CARTA_Y - (8.0 if i == sel else 0.0)


func mostrar_resultado() -> void:
	resultado_aberto = true
	mostrada_t = 0.0
	_fundo.visible = true
	_fundo.color = Color(0.05, 0.0, 0.0, 0.72)
	_res.visible = true
	var h = mundo.heroi
	var seg := int(mundo.tempo_partida)
	_res_valores.text = "%02d:%02d
%d
x%d
%d" % [floori(seg / 60.0), seg % 60, mundo.abates, mundo.maior_combo, h.nivel]
	combate.audio.tocar("carta", 0.7, 0.0, 0.0)


func esconder() -> void:
	escolha_aberta = false
	resultado_aberto = false
	_escolha.visible = false
	_res.visible = false
	_fundo.visible = false
	_fundo.color = Color(0.02, 0.02, 0.05, 0.62)


func aviso(texto: String, dur: float) -> void:
	if texto == "":
		return
	_aviso.text = texto
	_aviso.visible = true
	aviso_t = dur


func ligar_depuracao(v: bool) -> void:
	depuracao = v
	_dep.visible = v


# ------------------------------------------------------------------ quadro e entrada


func atualizar(dt: float) -> void:
	if aviso_t > 0.0:
		aviso_t -= dt
		_aviso.modulate.a = clampf(aviso_t / 0.5, 0.0, 1.0)
		if aviso_t <= 0.0:
			_aviso.visible = false
	if resultado_aberto:
		mostrada_t += dt
		_res_dica.visible = int(mostrada_t * 2.0) % 2 == 0 or mostrada_t < 0.6
	if depuracao:
		_dep_t -= dt
		if _dep_t <= 0.0:
			_dep_t = 0.1
			var h = mundo.heroi
			_dep.text = (
				"VIDA %d/%d   NV %d   XP %d/%d   FOLEGO %.1f\nCOMBO x%d   ABATES %d   VIVOS %d   %02d:%02d   [F1 esconde]"
				% [
					roundi(h.vida),
					roundi(h.vida_max),
					h.nivel,
					roundi(h.xp),
					roundi(h.xp_proximo),
					h.folego,
					mundo.combo,
					mundo.abates,
					mundo.monstros.size(),
					floori(mundo.tempo_partida / 60.0),
					int(mundo.tempo_partida) % 60
				]
			)


## Entrada das telas. Devolve true se o evento foi usado (escolha de carta, jogar de novo, F1).
func entrada(e: InputEvent) -> bool:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F1:
		ligar_depuracao(not depuracao)
		return true
	if escolha_aberta:
		return _entrada_escolha(e)
	if resultado_aberto:
		return _entrada_resultado(e)
	return false


func _carta_sob_mouse() -> int:
	var m: Vector2 = mundo.ap.mouse_na_tela()
	for i in 3:
		if _cartas[i].visible and Rect2(_cartas[i].position, _cartas[i].size).grow(6.0).has_point(m):
			return i
	return -1


func _entrada_escolha(e: InputEvent) -> bool:
	var n: int = combate.progresso.cartas.size()
	if e is InputEventMouseMotion:
		var i := _carta_sob_mouse()
		if i >= 0 and i != sel:
			sel = i
			_marcar()
			combate.audio.tocar("carta", 1.2, -6.0, 0.03)
		return true
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i := _carta_sob_mouse()
		if i >= 0:
			combate.progresso.escolher(i)
		return true
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1, KEY_2, KEY_3:
				var i: int = e.keycode - KEY_1
				if i < n:
					combate.progresso.escolher(i)
			KEY_LEFT, KEY_A:
				_mover(-1, n)
			KEY_RIGHT, KEY_D:
				_mover(1, n)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
				combate.progresso.escolher(sel)
		return true
	if e.is_action_pressed("ui_left"):
		_mover(-1, n)
		return true
	if e.is_action_pressed("ui_right"):
		_mover(1, n)
		return true
	if e.is_action_pressed("ui_accept"):
		combate.progresso.escolher(sel)
		return true
	return false


func _mover(d: int, n: int) -> void:
	if n <= 0:
		return
	sel = posmod(sel + d, n)
	_marcar()
	combate.audio.tocar("carta", 1.2, -6.0, 0.03)


func _entrada_resultado(e: InputEvent) -> bool:
	if mostrada_t < 0.6:
		return false
	var vai := false
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		vai = true
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		vai = true
	elif e.is_action_pressed("ui_accept"):
		vai = true
	if vai:
		mundo.reiniciar()
	return vai
