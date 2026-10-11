extends CanvasLayer
## Tela de resultados da fase (#32 item 7): para o jogo e mostra os ganhos DA FASE (arena.fase_stat),
## linha por linha, com contagem animada e um "plim" por linha.
## Qualquer tecla (ou clique) pula a contagem; Enter/E/Z, A do controle ou clique segue. Com --bot segue sozinha em ~1 s; no online ela
## fecha sozinha em ~8 s (cada um vê a própria tela e ninguém espera ninguém).
## A contagem usa tempo REAL (Time.get_ticks_msec), então não depende de pausa nem de Engine.time_scale.

const Interface := preload("res://scripts/hordas/interface.gd")
const Conjuntos := preload("res://scripts/hordas/conjuntos.gd")
const W := 640.0
const H := 360.0
const PASSO := 0.42  # segundos entre uma linha e a próxima
const CONTAR := 0.5  # quanto dura a contagem de cada número
const TRAVA := 0.35  # ignora teclas logo ao abrir (o botão que o jogador já estava apertando)
const AUTO_BOT := 1.0
const AUTO_ONLINE := 8.0
const MAX_ARMAS := 3
const MAX_ITENS := 12

var arena: Node
var _tela := Control.new()
var _aberto := false
var _t0 := 0
var _linhas: Array = []
var _tocadas := 0
var _pulou := false
var _final := 0.0  # instante (em s) em que a última linha termina de contar


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


func abrir(stat: Dictionary) -> void:
	_linhas = montar_linhas(stat)
	_tocadas = 0
	_pulou = false
	_final = (_linhas.size() - 1) * PASSO + CONTAR
	_t0 = Time.get_ticks_msec()
	_aberto = true
	get_tree().paused = not arena.eh_online  # no online o jogo dos outros não para
	_tela.queue_redraw()


func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	get_tree().paused = false
	_tela.queue_redraw()
	if arena and not arena.acabou:
		arena._abrir_proxima.call_deferred()  # carta que ficou esperando enquanto a tela estava aberta


## As linhas da tela, a partir das estatísticas da fase. Função pura (o teste usa).
static func montar_linhas(stat: Dictionary) -> Array:
	var l: Array = []
	l.append({"tipo": "tempo", "rotulo": "Tempo", "valor": float(stat.get("tempo", 0.0))})
	var extra := ""
	if int(stat.get("chefes", 0)) > 0:
		extra = "  (%d chefe)" % int(stat.chefes)
	l.append({"tipo": "num", "rotulo": "Abates", "valor": float(stat.get("abates", 0)), "extra": extra})
	l.append(
		{
			"tipo": "xp",
			"rotulo": "XP ganho",
			"valor": float(stat.get("xp", 0.0)),
			"extra": "  NV %d > %d" % [int(stat.get("nivel_ini", 1)), int(stat.get("nivel_fim", 1))]
		}
	)
	var ob: Dictionary = stat.get("objetivo", {})
	if not ob.is_empty():  # objetivo do andar (#63): cumprido ou falhou, e o que rendeu
		var cumprido: bool = int(ob.get("est", 0)) == 2
		l.append(
			{
				"tipo": "objetivo",
				"rotulo": str(ob.get("nome", "Objetivo")),
				"valor": 0.0,
				"cumprido": cumprido,
				"txt":
				("CUMPRIDO  +%d ouro  +%d XP" % [int(ob.get("ouro", 0)), int(ob.get("xp", 0))]) if cumprido else ("FALHOU  %d ouro" % int(ob.get("ouro", 0)))
			}
		)
	var dano: Dictionary = stat.get("dano", {})
	var ordem := dano.keys()
	ordem.sort_custom(func(a, b): return dano[a] > dano[b])
	l.append({"tipo": "titulo", "rotulo": "Dano por arma" if not ordem.is_empty() else "Dano por arma: nenhum", "valor": 0.0})
	for i in mini(MAX_ARMAS, ordem.size()):
		var d := Dados.item(str(ordem[i]))
		l.append({"tipo": "arma", "rotulo": str(d.get("nome", ordem[i])), "icone": str(d.get("icone", ordem[i])), "valor": float(dano[ordem[i]])})
	var itens: Array = stat.get("itens", [])
	l.append({"tipo": "itens", "rotulo": "Novos itens" if not itens.is_empty() else "Nenhum item novo", "itens": itens, "valor": 0.0})
	var conj: Array = stat.get("conjuntos", [])
	if not conj.is_empty():  # etiquetas da build e o degrau de cada conjunto (#63)
		l.append({"tipo": "conjuntos", "rotulo": "Conjuntos", "lin": conj, "valor": 0.0})
	return l


func _process(_dt: float) -> void:
	if not _aberto:
		return
	var t := _agora()
	if _pulou:
		t = _final + 1.0
	# um "plim" por linha que aparece (o tom sobe a cada linha)
	while _tocadas < _linhas.size() and t >= _tocadas * PASSO:
		if not _pulou and _tocadas > 0:
			Som.tocar("plim", 0.0, 1.0 + 0.06 * _tocadas, -6)
		_tocadas += 1
	_tela.queue_redraw()
	if arena.bot and t >= AUTO_BOT:
		fechar()
	elif arena.eh_online and t >= AUTO_ONLINE:
		fechar()


func _input(e: InputEvent) -> void:
	if Chat.digitando:  # o teclado é do chat (chat.gd)
		return
	if not _aberto or _agora() < TRAVA or not e.is_pressed() or e.is_echo():
		return
	if not (e is InputEventKey or e is InputEventJoypadButton or e is InputEventMouseButton):
		return
	get_viewport().set_input_as_handled()
	if _agora() < _final and not _pulou:
		_pulou = true  # qualquer tecla acelera: mostra tudo na hora
		Som.tocar("blip", 0.0, 1.3, -6)
	elif e.is_action_pressed("confirmar") or e.is_action_pressed("dash") or e.is_action_pressed("voltar") or Interface.clique(e):
		Som.ui("confirmar")
		fechar()


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := -1.0, alinhar := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f: Font = Dados.fonte
	_tela.draw_string(f, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, cor.a * 0.8))
	_tela.draw_string(f, p, s, alinhar, larg, tam, cor)


static func texto_valor(l: Dictionary, v: float) -> String:
	if str(l.tipo) == "tempo":
		return "%02d:%02d" % [int(v) / 60, int(v) % 60]
	return str(int(round(v)))


func _desenhar() -> void:
	if not _aberto:
		return
	var t := _final + 1.0 if _pulou else _agora()
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.02, 0.06, 0.8))
	var px := 110.0
	var pw := W - 2 * px
	_tela.draw_rect(Rect2(px - 2, 22, pw + 4, 316), Color(0.35, 0.4, 0.55))
	_tela.draw_rect(Rect2(px, 24, pw, 312), Color(0.1, 0.11, 0.18))
	var n: int = arena.diretor.fase_idx + 1
	var titulo := "FASE %d COMPLETA!" % n
	var fr: Dictionary = arena.diretor.fases()[arena.diretor.fase_idx]
	if fr.has("regiao"):  # regiões (#64)
		titulo = (
			"REGIÃO CONQUISTADA!"
			if fr.get("chefe_regiao", false)
			else "FASE %d/%d COMPLETA!" % [int(fr.andar_regiao) + 1, int(Dados.json("regioes").get("fases_por_regiao", 5))]
		)
	_txt(Vector2(px, 52), titulo, 16, Color(1, 0.9, 0.4), pw, HORIZONTAL_ALIGNMENT_CENTER)
	var fa: Dictionary = arena.diretor.fases()[arena.diretor.fase_idx]
	_txt(Vector2(px, 70), str(fa.get("nome", "")), 8, Color(0.7, 0.9, 1), pw, HORIZONTAL_ALIGNMENT_CENTER)
	var y := 104.0
	for i in _linhas.size():
		var l: Dictionary = _linhas[i]
		var ti: float = t - i * PASSO
		if ti < 0.0:
			break
		var a := clampf(ti * 6.0, 0.0, 1.0)  # entra rapidinho
		var k := clampf(ti / CONTAR, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)  # a contagem desacelera no fim
		var v: float = float(l.valor) * k
		var x := px + 24
		match str(l.tipo):
			"titulo":
				_txt(Vector2(x, y + 4), str(l.rotulo), 8, Color(0.7, 0.8, 1, a))
				y += 22
			"arma":
				var ic := Dados.icone(str(l.icone))
				if ic:
					_tela.draw_texture(ic, Vector2(x + 8, y - 12), Color(1, 1, 1, a))
				_txt(Vector2(x + 34, y), str(l.rotulo), 8, Color(1, 1, 1, a), 180)
				_txt(Vector2(px + pw - 140, y), texto_valor(l, v), 8, Color(1, 0.9, 0.5, a), 116, HORIZONTAL_ALIGNMENT_RIGHT)
				y += 20
			"objetivo":
				var co := Color(0.5, 1.0, 0.6, a) if l.cumprido else Color(1.0, 0.5, 0.45, a)
				_txt(Vector2(x, y), "Objetivo", 8, Color(0.85, 0.9, 1, a))
				_txt(Vector2(x + 90, y), str(l.rotulo), 8, co, 160)
				_txt(Vector2(px + pw - 260, y + 11), str(l.txt), 8, co, 236, HORIZONTAL_ALIGNMENT_RIGHT)
				y += 28
			"conjuntos":
				_txt(Vector2(x, y), str(l.rotulo), 8, Color(0.7, 0.8, 1, a))
				var xc := x + 100.0
				var yc := y
				for c in l.lin:
					var lig: bool = int(c.ativo) > 0
					var cc: Color = c.cor if lig else Color(0.55, 0.55, 0.62)
					var s2 := "%s %s" % [str(c.nome).left(12), Conjuntos.progresso_txt(c)]
					var w2: float = Dados.fonte.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10.0
					if xc + w2 > px + pw - 16:
						xc = x + 100.0
						yc += 11.0
					_txt(Vector2(xc, yc), s2, 8, Color(cc, a))
					xc += w2
				y = yc + 20.0
			"itens":
				_txt(Vector2(x, y), str(l.rotulo), 8, Color(0.7, 0.8, 1, a))
				var xi := x + 150.0
				var lista: Array = l.itens
				for j in mini(lista.size(), MAX_ITENS):
					var ic := Dados.icone(str(lista[j].icone))
					if ic:
						_tela.draw_texture(ic, Vector2(xi + j * 20.0, y - 12), Color(1, 1, 1, a))
				if lista.size() > MAX_ITENS:
					_txt(Vector2(xi + MAX_ITENS * 20.0, y), "+%d" % (lista.size() - MAX_ITENS), 8, Color(1, 1, 0.6, a))
				y += 20
			_:
				var s := texto_valor(l, v)
				if str(l.tipo) == "xp":
					s = "+" + s
				if k >= 1.0:
					s += str(l.get("extra", ""))
				_txt(Vector2(x, y), str(l.rotulo), 8, Color(0.85, 0.9, 1, a))
				_txt(Vector2(px + pw - 260, y), s, 8, Color(1, 0.9, 0.5, a), 236, HORIZONTAL_ALIGNMENT_RIGHT)
				y += 22
	if t >= _final:
		var pisca := 0.55 + 0.45 * sin(_agora() * 6.0)
		_txt(Vector2(px, 320), "Enter: continuar", 8, Color(0.8, 0.85, 1, pisca), pw, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_txt(Vector2(px, 320), "Qualquer tecla: pular", 8, Color(0.5, 0.55, 0.7), pw, HORIZONTAL_ALIGNMENT_CENTER)
