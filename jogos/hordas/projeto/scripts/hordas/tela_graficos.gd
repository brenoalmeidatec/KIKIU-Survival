extends Control
## Aba Gráficos (#150), aberta pelo item "Gráficos" das Opções (tela_opcoes.gd). Topo: perfil (Baixo, Médio, Alto ou
## Personalizado) e "Detectar automaticamente". Depois, duas seções com as opções de dados/graficos.json: CPU (simulação)
## e GPU (visual). Cada opção tem nome, o controle (controle deslizante, menu com setas ou sim/não), uma linha de ajuda
## com o peso (leve, médio ou pesado) e fps ao vivo no canto.
## Mexer numa opção chama api.g_definir; escolher um perfil chama api.g_aplicar_perfil; a tela atualiza com o sinal
## graficos_mudou. A API é o autoload Config (valor padrão de `api`; só troque para testar outra fonte).
## Teclado: cima/baixo escolhem, esquerda/direita mudam, Enter aplica, Esc volta. Mouse: passar escolhe, clique muda
## (direito volta), arrastar o controle deslizante, roda do mouse rola a lista. Ao fechar emite `fechou`; quem abriu
## volta para a sua tela.

signal fechou

const TEMA := preload("res://cenas/tema_hud.tres")
const W := 640.0
const H := 360.0
const ESQ := 40.0
const DIR := 600.0
const TOPO_LISTA := 96.0      # y da primeira linha rolável
const BASE_LISTA := 330.0     # y onde a lista rolável termina (o rodapé fica abaixo)
const ALT_LISTA := 234.0      # BASE_LISTA - TOPO_LISTA
const BARRA_X := 400.0        # início da barra do controle deslizante
const BARRA_W := 120.0
const PERFIS := ["baixo", "medio", "alto"]
const NOMES_PERFIL := {"baixo": "Baixo", "medio": "Médio", "alto": "Alto", "personalizado": "Personalizado"}
const SECOES := ["cpu", "gpu"]
const NOMES_SECAO := {"cpu": "CPU  (simulação)", "gpu": "GPU  (visual)"}
const PESO_COR := {"leve": Color(0.45, 0.85, 0.5), "medio": Color(1.0, 0.8, 0.3), "pesado": Color(1.0, 0.45, 0.4)}
const PESO_NOME := {"leve": "LEVE", "medio": "MÉDIO", "pesado": "PESADO"}
const AMARELO := Color(1.0, 0.9, 0.4)
const COR_TEXTO := Color(0.85, 0.85, 0.9)
const COR_VALOR := Color(0.6, 0.85, 1.0)
const COR_AJUDA := Color(0.7, 0.72, 0.82)
const COR_DICA := Color(0.5, 0.52, 0.62)
const FUNDO := Color(0.04, 0.035, 0.07, 0.97)
const SOMBRA := Color(0, 0, 0, 0.8)

## API de gráficos: o autoload Config por padrão. Sem tipo de propósito: os métodos g_* são da API (pode estar em outro PR).
var api = null
## Perfil para aplicar ao abrir (prints: --perfil=baixo). "" não mexe em nada.
var perfil_inicial := ""

var _opcoes: Array = []        # opções da API, na ordem do json
var _valores := {}             # chave -> valor atual (lido da API em _recarregar)
var _perfil := "personalizado"
var _linhas: Array = []        # o que se desenha no conteúdo rolável: cabeçalhos de seção e opções
var _foco: Array = []          # o que o teclado percorre: perfil, detectar, opções e voltar
var _sel := 0                  # índice em _foco
var _rolagem := 0.0
var _rolagem_max := 0.0
var _quadro := -1              # quadro em que a tela abriu: a tecla ou clique que a abriu não vale aqui
var _arrastando := -1          # índice em _foco do controle deslizante que o mouse arrasta
var _mouse_ult := Vector2(-1, -1)
var _msg := ""                 # aviso curto (detectar)
var _msg_ate := 0.0
var _lista: Control


func _ready() -> void:
	if api == null:
		api = Config
	_quadro = Engine.get_process_frames()
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista = Control.new()
	_lista.position = Vector2(0, TOPO_LISTA)
	_lista.size = Vector2(W, ALT_LISTA)
	_lista.clip_contents = true
	_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista.draw.connect(_desenhar_lista)
	add_child(_lista)
	draw.connect(_desenhar)
	_opcoes = api.g_opcoes()
	if perfil_inicial != "":
		api.g_perfil_temporario(perfil_inicial)   # só na memória: o print não grava nas opções do jogador
	if api.has_signal("graficos_mudou"):
		api.graficos_mudou.connect(_recarregar)
	_montar_layout()
	_recarregar()


func _exit_tree() -> void:
	if api != null and api.has_signal("graficos_mudou") and api.graficos_mudou.is_connected(_recarregar):
		api.graficos_mudou.disconnect(_recarregar)


# ---------- dados ----------

## Lê da API o perfil e o valor de cada opção. Chamado ao abrir e a cada mudança.
func _recarregar(_x = null) -> void:
	_perfil = str(api.g_perfil())
	if not NOMES_PERFIL.has(_perfil):
		_perfil = "personalizado"
	for op in _opcoes:
		_valores[str(op.chave)] = api.g(str(op.chave))
	queue_redraw()
	_lista.queue_redraw()


## Monta as linhas (seção e opções, com altura pelo texto da ajuda) e a ordem do foco. Só muda se o json mudar.
func _montar_layout() -> void:
	_linhas.clear()
	_foco.clear()
	_foco.append({"tipo": "perfil"})
	_foco.append({"tipo": "detectar"})
	var f: Font = TEMA.default_font
	var lh := f.get_height(8)
	var y := 0.0
	for sec in SECOES:
		var y_cab := y
		_linhas.append({"tipo": "secao", "nome": NOMES_SECAO[sec], "y": y, "h": 20.0})
		y += 20.0
		var primeira := true
		for i in _opcoes.size():
			var op: Dictionary = _opcoes[i]
			if str(op.get("secao", "")) != sec:
				continue
			var peso := str(op.get("peso", "medio"))
			if not PESO_COR.has(peso):
				peso = "medio"
			var tag_w: float = f.get_string_size(PESO_NOME[peso], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8.0
			var x_ajuda := ESQ + 4.0 + tag_w + 6.0
			var larg_ajuda := DIR - x_ajuda
			var alt_ajuda: float = f.get_multiline_string_size(str(op.get("ajuda", "")), HORIZONTAL_ALIGNMENT_LEFT, larg_ajuda, 8).y
			var nl := maxi(1, ceili(alt_ajuda / lh))
			var h := 22.0 + (nl - 1) * lh + 6.0
			var li := _linhas.size()
			_linhas.append({"tipo": "opcao", "y": y, "h": h, "op": i, "peso": peso, "tag_w": tag_w,
				"x_ajuda": x_ajuda, "larg_ajuda": larg_ajuda})
			var topo := y_cab if primeira else y   # a 1ª opção de cada seção leva o cabeçalho junto
			primeira = false
			_foco.append({"tipo": "opcao", "linha": li, "top": topo, "bot": y + h})
			y += h
		y += 6.0
	_foco.append({"tipo": "voltar"})
	_rolagem_max = maxf(0.0, y - ALT_LISTA)
	_sel = clampi(_sel, 0, _foco.size() - 1)


func _opcao_de(li: int) -> Dictionary:
	return _opcoes[int(_linhas[li].op)]


func _linha_sel() -> int:
	var f: Dictionary = _foco[_sel]
	return int(f.get("linha", -1))


## Valor que a API devolve, arredondado para a grade do controle (min, passo, max). Inteiro quando a grade é inteira.
func _ajustar(op: Dictionary, v: float) -> Variant:
	var lo := float(op.get("min", 0))
	var hi := float(op.get("max", 1))
	var st := float(op.get("passo", 1))
	var r := clampf(v, lo, hi)
	if st > 0.0:
		r = clampf(lo + roundf((r - lo) / st) * st, lo, hi)
	if is_equal_approx(lo, roundf(lo)) and is_equal_approx(hi, roundf(hi)) and is_equal_approx(st, roundf(st)):
		return roundi(r)
	return r


# ---------- ações (teclado, controle e mouse chamam estas) ----------

func _mudar_perfil(d: int) -> void:
	var i := PERFIS.find(_perfil)
	if i < 0:
		i = 0 if d > 0 else PERFIS.size() - 1
	else:
		i = posmod(i + d, PERFIS.size())
	api.g_aplicar_perfil(PERFIS[i])
	Som.ui("cursor")
	_recarregar()


func _mudar_opcao(op: Dictionary, d: int) -> void:
	var chave := str(op.chave)
	var atual = _valores.get(chave)
	if str(op.get("tipo", "")) == "slider":
		var base := float(atual) if atual != null else float(op.get("min", 0))
		api.g_definir(chave, _ajustar(op, base + d * float(op.get("passo", 1))))
	else:
		var padrao: Array = [false, true] if str(op.get("tipo", "")) == "sim_nao" else []
		var vals: Array = op.get("valores", padrao)
		if vals.is_empty():
			return
		var i := _indice(vals, atual)
		if i < 0:
			i = 0 if d > 0 else vals.size() - 1
		else:
			i = posmod(i + d, vals.size())
		api.g_definir(chave, vals[i])
	Som.ui("cursor")
	_recarregar()


## Controle deslizante: a posição x (em tela) vira o valor.
func _arrastar(op: Dictionary, x: float) -> void:
	var frac := clampf((x - BARRA_X) / BARRA_W, 0.0, 1.0)
	var lo := float(op.get("min", 0))
	var hi := float(op.get("max", 1))
	api.g_definir(str(op.chave), _ajustar(op, lo + frac * (hi - lo)))
	_recarregar()


func _detectar() -> void:
	var r = api.g_detectar()
	if r is String and PERFIS.has(r):
		api.g_aplicar_perfil(r)
		_msg = "Detectado: %s" % NOMES_PERFIL[r]
	else:
		_msg = "Não deu para detectar"
	_msg_ate = Time.get_ticks_msec() / 1000.0 + 3.0
	Som.ui("confirmar")
	_recarregar()


## Enter ou direita (d = 1) e esquerda (d = -1) no item escolhido.
func _agir(d: int, confirmar := false) -> void:
	var f: Dictionary = _foco[_sel]
	match str(f.tipo):
		"perfil":
			_mudar_perfil(d)
		"detectar":
			if confirmar:
				_detectar()
		"voltar":
			if confirmar:
				_sair()
		"opcao":
			_mudar_opcao(_opcao_de(int(f.linha)), d)


func _mover(d: int) -> void:
	var novo := clampi(_sel + d, 0, _foco.size() - 1)
	if novo != _sel:
		_sel = novo
		_garantir_visivel()
	Som.ui("cursor")


func _rolar(d: float) -> void:
	_rolagem = clampf(_rolagem + d, 0.0, _rolagem_max)


## Rola o mínimo para a opção escolhida (e o cabeçalho da seção, se for a 1ª) caberem na lista.
func _garantir_visivel() -> void:
	var f: Dictionary = _foco[_sel]
	if str(f.tipo) != "opcao":
		return
	var topo := float(f.top)
	var bot := float(f.bot)
	if topo < _rolagem:
		_rolagem = topo
	elif bot > _rolagem + ALT_LISTA:
		_rolagem = bot - ALT_LISTA
	_rolagem = clampf(_rolagem, 0.0, _rolagem_max)


func _sair() -> void:
	Som.ui("voltar")
	fechou.emit()
	queue_free()


func _clicar(q: int, btn: int) -> void:
	var esq := btn == MOUSE_BUTTON_LEFT
	if not (esq or btn == MOUSE_BUTTON_RIGHT):
		return
	var f: Dictionary = _foco[q]
	match str(f.tipo):
		"perfil":
			_mudar_perfil(1 if esq else -1)
		"detectar":
			if esq:
				_detectar()
		"voltar":
			if esq:
				_sair()
		"opcao":
			var op: Dictionary = _opcao_de(int(f.linha))
			if str(op.get("tipo", "")) == "slider":
				if esq:
					_arrastando = q
					_arrastar(op, get_local_mouse_position().x)
				else:
					_mudar_opcao(op, -1)
			else:
				_mudar_opcao(op, 1 if esq else -1)


# ---------- entrada ----------

func _process(_dt: float) -> void:
	queue_redraw()
	_lista.queue_redraw()
	if Engine.get_process_frames() == _quadro:
		return
	var mp := get_local_mouse_position()
	if mp != _mouse_ult:   # passar o mouse por cima escolhe (só se ele se mexeu, pra não brigar com o teclado)
		_mouse_ult = mp
		var q := _item_em(mp)
		if q >= 0 and q != _sel:
			_sel = q
			Som.ui("cursor")
	if Input.is_action_just_pressed("cima"):
		_mover(-1)
	elif Input.is_action_just_pressed("baixo"):
		_mover(1)
	elif Input.is_action_just_pressed("voltar"):
		_sair()
	elif Input.is_action_just_pressed("esquerda"):
		_agir(-1)
	elif Input.is_action_just_pressed("direita"):
		_agir(1)
	elif Input.is_action_just_pressed("confirmar"):
		_agir(1, true)


func _input(e: InputEvent) -> void:
	if Engine.get_process_frames() == _quadro:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if not mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_arrastando = -1
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rolar(-24.0)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rolar(24.0)
			get_viewport().set_input_as_handled()
			return
		var q := _item_em(get_local_mouse_position())
		if q < 0:
			return
		get_viewport().set_input_as_handled()
		_sel = q
		_clicar(q, mb.button_index)
	elif e is InputEventMouseMotion and _arrastando >= 0:
		if (e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			var f: Dictionary = _foco[_arrastando]
			_arrastar(_opcao_de(int(f.linha)), get_local_mouse_position().x)
			get_viewport().set_input_as_handled()
		else:
			_arrastando = -1


## Índice em _foco do item sob o ponto (coordenadas da tela), ou -1.
func _item_em(p: Vector2) -> int:
	for k in _foco.size():
		if _rect_foco(k).has_point(p):
			return k
	return -1


func _rect_foco(k: int) -> Rect2:
	var f: Dictionary = _foco[k]
	match str(f.tipo):
		"perfil":
			return Rect2(150, 54, 150, 16)
		"detectar":
			return Rect2(390, 54, 210, 16)
		"voltar":
			return Rect2(530, 338, 70, 16)
	var a := maxf(TOPO_LISTA + float(f.top) - _rolagem, TOPO_LISTA)
	var b := minf(TOPO_LISTA + float(f.bot) - _rolagem, BASE_LISTA)
	if b <= a:
		return Rect2()
	return Rect2(ESQ - 6, a, DIR - ESQ + 12, b - a)


# ---------- desenho ----------

func _txt(ci: CanvasItem, p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := -1.0, alinhar := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f: Font = TEMA.default_font
	ci.draw_string(f, p + Vector2(1, 1), s, alinhar, larg, tam, SOMBRA)
	ci.draw_string(f, p, s, alinhar, larg, tam, cor)


func _caixa(ci: CanvasItem, r: Rect2, sel: bool) -> void:
	ci.draw_rect(r, Color(0.3, 0.35, 0.6, 0.45) if sel else Color(0.1, 0.1, 0.18, 0.9))
	ci.draw_rect(r, Color(0.35, 0.38, 0.55, 0.8), false, 1.0)


func _desenhar() -> void:
	draw_rect(Rect2(0, 0, W, H), FUNDO)
	TEMA.get_stylebox("panel", "PanelContainer").draw(get_canvas_item(), Rect2(6, 6, W - 12, H - 12))
	_txt(self, Vector2(0, 34), "Gráficos", 16, Color.WHITE, W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(self, Vector2(0, 22), "%d fps" % roundi(Engine.get_frames_per_second()), 8, Color(0.6, 1.0, 0.6), 616, HORIZONTAL_ALIGNMENT_RIGHT)
	# perfil e detectar
	var f_sel: Dictionary = _foco[_sel]
	var sel_p: bool = str(f_sel.tipo) == "perfil"
	var sel_d: bool = str(f_sel.tipo) == "detectar"
	var sel_v: bool = str(f_sel.tipo) == "voltar"
	_txt(self, Vector2(ESQ, 66), "Perfil", 8, COR_TEXTO)
	_caixa(self, Rect2(150, 54, 150, 16), sel_p)
	_txt(self, Vector2(150, 66), "< %s >" % NOMES_PERFIL.get(_perfil, "Personalizado"), 8, AMARELO if sel_p else COR_VALOR, 150, HORIZONTAL_ALIGNMENT_CENTER)
	_caixa(self, Rect2(390, 54, 210, 16), sel_d)
	_txt(self, Vector2(390, 66), "Detectar automaticamente", 8, AMARELO if sel_d else Color.WHITE, 210, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(self, Vector2(ESQ, 84), "Mexer em um detalhe vira Personalizado.", 8, COR_DICA)
	if _msg != "" and Time.get_ticks_msec() / 1000.0 < _msg_ate:
		_txt(self, Vector2(0, 84), _msg, 8, AMARELO, DIR, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_line(Vector2(ESQ, 90), Vector2(DIR, 90), Color(0.35, 0.38, 0.55, 0.8))
	draw_line(Vector2(ESQ, 332), Vector2(DIR, 332), Color(0.35, 0.38, 0.55, 0.8))
	# rodapé
	_txt(self, Vector2(ESQ, 350), "Cima/baixo escolhe   Esq/dir muda   Esc volta", 8, COR_DICA)
	_caixa(self, Rect2(530, 338, 70, 16), sel_v)
	_txt(self, Vector2(530, 350), "Voltar", 8, AMARELO if sel_v else COR_TEXTO, 70, HORIZONTAL_ALIGNMENT_CENTER)


func _desenhar_lista() -> void:
	var sel := _linha_sel()
	for i in _linhas.size():
		var l: Dictionary = _linhas[i]
		var y := float(l.y) - _rolagem
		if y > ALT_LISTA or y + float(l.h) < 0.0:
			continue
		if str(l.tipo) == "secao":
			_txt(_lista, Vector2(ESQ, y + 12.0), str(l.nome), 8, AMARELO)
			_lista.draw_line(Vector2(ESQ, y + 16.0), Vector2(DIR, y + 16.0), Color(1.0, 0.85, 0.3, 0.35))
		else:
			_desenhar_opcao(l, y, i == sel)
	if _rolagem > 0.5:
		_lista.draw_colored_polygon(PackedVector2Array([Vector2(606, 4), Vector2(612, 10), Vector2(600, 10)]), AMARELO)
	if _rolagem < _rolagem_max - 0.5:
		_lista.draw_colored_polygon(PackedVector2Array([Vector2(600, ALT_LISTA - 10), Vector2(612, ALT_LISTA - 10), Vector2(606, ALT_LISTA - 4)]), AMARELO)


func _desenhar_opcao(l: Dictionary, y: float, sel: bool) -> void:
	var op: Dictionary = _opcoes[int(l.op)]
	var valor = _valores.get(str(op.chave))
	var tipo := str(op.get("tipo", "menu"))
	var h := float(l.h)
	if sel:
		_lista.draw_rect(Rect2(ESQ - 6, y + 1, DIR - ESQ + 12, h - 2), Color(0.3, 0.35, 0.6, 0.35))
	_txt(_lista, Vector2(ESQ + 4, y + 10), str(op.nome), 8, AMARELO if sel else COR_TEXTO, 330)
	var cor_v := Color.WHITE if sel else COR_VALOR
	if tipo == "slider":
		var lo := float(op.get("min", 0))
		var hi := float(op.get("max", 1))
		var v := float(valor) if valor != null else lo
		var frac := clampf((v - lo) / (hi - lo), 0.0, 1.0) if hi > lo else 0.0
		_lista.draw_rect(Rect2(BARRA_X, y + 5, BARRA_W, 6), Color(0.27, 0.27, 0.38))
		_lista.draw_rect(Rect2(BARRA_X, y + 5, BARRA_W * frac, 6), Color(0.3, 0.6, 1.0))
		_lista.draw_rect(Rect2(BARRA_X + BARRA_W * frac - 2, y + 2, 4, 12), Color.WHITE)
		var txt_v := _fmt_num(v, float(op.get("passo", 1))) + str(op.get("unidade", ""))   # "%" e "s" vêm do graficos.json
		_txt(_lista, Vector2(DIR - 56, y + 10), txt_v, 8, cor_v, 56, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_txt(_lista, Vector2(ESQ, y + 10), "< %s >" % _rotulo(op, valor), 8, cor_v, DIR - ESQ, HORIZONTAL_ALIGNMENT_RIGHT)
	# linha de ajuda com a etiqueta de peso
	var peso := str(l.peso)
	_lista.draw_rect(Rect2(ESQ + 4, y + 13, float(l.tag_w), 11), PESO_COR[peso])
	_lista.draw_string(TEMA.default_font, Vector2(ESQ + 8, y + 22), PESO_NOME[peso], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.08, 0.06, 0.1))
	_lista.draw_multiline_string(TEMA.default_font, Vector2(float(l.x_ajuda), y + 22), str(op.get("ajuda", "")), HORIZONTAL_ALIGNMENT_LEFT, float(l.larg_ajuda), 8, -1, COR_AJUDA)


## Posição de um valor na lista de valores do menu. Número compara por valor (75 e 75.0 são o mesmo).
func _indice(vals: Array, valor) -> int:
	for i in vals.size():
		var v = vals[i]
		if (v is float or v is int) and (valor is float or valor is int):
			if is_equal_approx(float(v), float(valor)):
				return i
		elif v == valor:
			return i
	return -1


func _rotulo(op: Dictionary, valor) -> String:
	var padrao: Array = [false, true] if str(op.get("tipo", "")) == "sim_nao" else []
	var vals: Array = op.get("valores", padrao)
	var rot: Array = op.get("rotulos", [])
	var i := _indice(vals, valor)
	if i >= 0 and i < rot.size():
		return str(rot[i])
	if valor is bool:
		return "Sim" if valor else "Não"
	return str(valor)


func _fmt_num(v: float, passo: float) -> String:
	if passo >= 1.0 and is_equal_approx(v, roundf(v)):
		return "%d" % roundi(v)
	return "%.2f" % v
