extends CanvasLayer
## Tela do mapa de progressão (#32 item 8): mostra o mapa inteiro, o caminho percorrido e as opções do próximo andar.
## Setas escolhem, Enter confirma; a informação do nó selecionado aparece embaixo. Com --bot escolhe sozinha em ~1 s.
## Solo: confirmar vai direto pra arena.escolher_no(). Online: confirmar manda o VOTO ao anfitrião e a tela fica
## aberta esperando; quem fecha é o evento "proxima_fase" do anfitrião (maioria, empate = anfitrião, limite de tempo).
## Tempo REAL (Time.get_ticks_msec), como resultado.gd, pra não depender de pausa nem de Engine.time_scale.
## Os dados e a geração ficam em mapa.gd; aqui só desenho e entrada.

const Mapa := preload("res://scripts/hordas/mapa.gd")

const W := 640.0
const H := 360.0
const X0 := 54.0           # centro do andar 1
const DX := 58.0           # distância entre andares
const Y0 := 92.0           # centro da faixa 0
const DY := 46.0           # distância entre faixas
const TRAVA := 0.35        # ignora teclas logo ao abrir (o botão que o jogador já estava apertando)
const AUTO_BOT := 1.0

var arena: Node
var _tela := Control.new()
var _aberto := false
var _t0 := 0
var _sel := 0               # índice em _opcoes
var _opcoes: Array = []     # faixas acessíveis a partir do nó atual
var _voto := -1             # online: faixa em que já votei
var _espera := 0.0          # online: segundos que faltam pro anfitrião fechar a votação


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


func aberto() -> bool:
	return _aberto


func _agora() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


func abrir() -> void:
	_opcoes = Mapa.acessiveis(arena.mapa, arena.mapa_pos.x, arena.mapa_pos.y)
	_sel = 0
	_voto = -1
	_espera = float(Mapa.cfg().get("espera_voto", 40.0))
	_t0 = Time.get_ticks_msec()
	_aberto = true
	get_tree().paused = not arena.eh_online   # no online o jogo dos outros não para
	Som.tocar("plim", 0.0, 0.9, -6)
	_tela.queue_redraw()


func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	get_tree().paused = false
	_tela.queue_redraw()


func _escolher(i: int) -> void:
	if _voto >= 0 or _opcoes.is_empty():
		return
	var faixa: int = _opcoes[i]
	Som.tocar("confirmar")
	if arena.eh_online:
		_voto = faixa
		Rede.avisar("voto", float((arena.mapa_pos.x + 1) * 10 + faixa))
	else:
		arena.escolher_no(faixa)


func _process(dt: float) -> void:
	if not _aberto:
		return
	_tela.queue_redraw()
	if arena.bot and _agora() >= AUTO_BOT and _voto < 0:
		_escolher(maxi(0, _opcoes.find(Mapa.escolha_bot(arena.mapa, arena.mapa_pos.x, arena.mapa_pos.y))))


func _input(e: InputEvent) -> void:
	if not _aberto or _agora() < TRAVA or not e.is_pressed() or e.is_echo() or _voto >= 0 or _opcoes.is_empty():
		return
	var n := _opcoes.size()
	if e.is_action_pressed("cima") or e.is_action_pressed("esquerda"):
		_sel = (_sel - 1 + n) % n
		Som.tocar("cursor")
	elif e.is_action_pressed("baixo") or e.is_action_pressed("direita"):
		_sel = (_sel + 1) % n
		Som.tocar("cursor")
	elif e.is_action_pressed("confirmar"):
		_escolher(_sel)
	else:
		return
	get_viewport().set_input_as_handled()


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := -1.0, alinhar := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f: Font = Dados.fonte
	_tela.draw_string(f, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, cor.a * 0.8))
	_tela.draw_string(f, p, s, alinhar, larg, tam, cor)


static func centro_no(andar: int, faixa: int) -> Vector2:
	return Vector2(X0 + andar * DX, Y0 + faixa * DY)


static func cor_tipo(tipo: String) -> Color:
	var c: Array = Mapa.tipo_cfg(tipo).get("cor", [1, 1, 1])
	return Color(c[0], c[1], c[2])


## Ícone do tipo, desenhado à mão (sem arte): cabe num quadrado de ~20 px centrado em p.
func _icone(p: Vector2, tipo: String, cor: Color) -> void:
	var t := _tela
	match tipo:
		"fase":   # duas espadas cruzadas
			t.draw_line(p + Vector2(-7, 7), p + Vector2(7, -7), cor, 2.0)
			t.draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), cor, 2.0)
			t.draw_rect(Rect2(p + Vector2(-3, 2), Vector2(6, 2)), cor)
		"elite":   # caveira
			t.draw_circle(p + Vector2(0, -2), 6.0, cor)
			t.draw_rect(Rect2(p + Vector2(-3, 3), Vector2(6, 5)), cor)
			t.draw_rect(Rect2(p + Vector2(-4, -3), Vector2(3, 3)), Color(0.08, 0.08, 0.12))
			t.draw_rect(Rect2(p + Vector2(1, -3), Vector2(3, 3)), Color(0.08, 0.08, 0.12))
		"descanso":   # fogueira: chama
			t.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(6, 2), p + Vector2(3, 7), p + Vector2(-3, 7), p + Vector2(-6, 2)]), cor)
			t.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -1), p + Vector2(3, 3), p + Vector2(0, 7), p + Vector2(-3, 3)]), Color(1, 0.95, 0.6, cor.a))
		"loja":   # moeda
			t.draw_circle(p, 8.0, cor)
			t.draw_circle(p, 5.5, Color(cor.r * 0.6, cor.g * 0.6, cor.b * 0.6, cor.a))
			_txt(p + Vector2(-4, 4), "$", 8, cor)
		"evento":
			_txt(p + Vector2(-5, 6), "?", 16, cor)
		"santuario":   # losango duplo
			t.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(7, 0), p + Vector2(0, 9), p + Vector2(-7, 0)]), cor)
			t.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(3, 0), p + Vector2(0, 4), p + Vector2(-3, 0)]), Color(0.12, 0.1, 0.16, cor.a))
		"chefe":   # caveira com coroa
			t.draw_circle(p + Vector2(0, 1), 8.0, cor)
			t.draw_rect(Rect2(p + Vector2(-4, 6), Vector2(8, 5)), cor)
			t.draw_rect(Rect2(p + Vector2(-5, -1), Vector2(4, 4)), Color(0.08, 0.08, 0.12))
			t.draw_rect(Rect2(p + Vector2(1, -1), Vector2(4, 4)), Color(0.08, 0.08, 0.12))
			t.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -6), p + Vector2(-8, -12), p + Vector2(-4, -8), p + Vector2(0, -13), p + Vector2(4, -8), p + Vector2(8, -12), p + Vector2(8, -6)]), cor)


func _desenhar() -> void:
	if not _aberto:
		return
	var m: Dictionary = arena.mapa
	var pos: Vector2i = arena.mapa_pos
	var tt := Time.get_ticks_msec() / 1000.0
	var pulso := 0.6 + 0.4 * sin(tt * 6.0)
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.03, 0.08, 1.0))
	_txt(Vector2(0, 30), "MAPA", 16, Color(1, 0.9, 0.4), W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 50), "Andar %d de %d" % [pos.x + 1, int(m.andares)], 8, Color(0.7, 0.9, 1), W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(W - 150, 24), "OURO %d" % arena.ouro, 8, Color(1, 0.85, 0.35), 138.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var trilha: Array = arena.mapa_trilha
	var alvo := -1 if _opcoes.is_empty() else int(_opcoes[_sel])
	# ligações: apagadas, e acesas as do caminho percorrido e as que saem do nó atual
	for a in int(m.andares) - 1:
		for x in int(m.faixas):
			var n := Mapa.no(m, a, x)
			for p in n.get("prox", []):
				var de := centro_no(a, x)
				var para := centro_no(a + 1, int(p))
				var cor := Color(0.3, 0.33, 0.45, 0.6)
				var larg := 1.0
				if Vector2i(a, x) in trilha and Vector2i(a + 1, int(p)) in trilha:
					cor = Color(0.95, 0.85, 0.4)
					larg = 3.0
				elif a == pos.x and x == pos.y:
					cor = Color(1, 1, 1, 0.5 + 0.4 * pulso) if int(p) == alvo else Color(0.75, 0.8, 1, 0.55)
					larg = 3.0 if int(p) == alvo else 2.0
				_tela.draw_line(de, para, cor, larg)
	# nós
	for a in int(m.andares):
		for x in int(m.faixas):
			var n := Mapa.no(m, a, x)
			if n.is_empty():
				continue
			var c := centro_no(a, x)
			var tipo := str(n.tipo)
			var cor_t := cor_tipo(tipo)
			var visitado := Vector2i(a, x) in trilha
			var atual := a == pos.x and x == pos.y
			var acessivel := a == pos.x + 1 and x in _opcoes
			var escolhido := acessivel and x == alvo
			var fundo := Color(0.12, 0.13, 0.2)
			var borda := Color(0.25, 0.28, 0.4)
			var cor_i := Color(cor_t.r, cor_t.g, cor_t.b, 0.4)
			if visitado:
				borda = Color(0.95, 0.85, 0.4)
				cor_i = Color(cor_t.r, cor_t.g, cor_t.b, 0.75)
			if acessivel:
				borda = cor_t
				cor_i = cor_t
			if atual:
				borda = Color(1, 1, 1)
				cor_i = cor_t
			if escolhido:
				borda = Color(1, 1, 1, 0.55 + 0.45 * pulso)
			var raio := 13.0 if tipo == "chefe" else 12.0
			var r := Rect2(c - Vector2(raio, raio), Vector2(raio, raio) * 2.0)
			_tela.draw_rect(r.grow(2.0 if escolhido or atual else 1.0), borda)
			_tela.draw_rect(r, fundo)
			_icone(c, tipo, cor_i)
			if visitado and not atual:
				_txt(c + Vector2(4, -7), "v", 8, Color(0.5, 1, 0.5))
			if escolhido:
				_tela.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -raio - 8), c + Vector2(5, -raio - 8), c + Vector2(0, -raio - 2)]), Color(1, 1, 1, pulso))
	# números dos andares embaixo
	for a in int(m.andares):
		var cor_n := Color(1, 0.9, 0.4) if a == pos.x else Color(0.45, 0.5, 0.65)
		_txt(Vector2(X0 + a * DX - 14, 72.0), "%d" % (a + 1), 8, cor_n, 28.0, HORIZONTAL_ALIGNMENT_CENTER)
	# painel de informação do nó selecionado
	var py := 258.0
	_tela.draw_rect(Rect2(38, py - 2, W - 76, 84), Color(0.35, 0.4, 0.55))
	_tela.draw_rect(Rect2(40, py, W - 80, 80), Color(0.1, 0.11, 0.18))
	if alvo >= 0:
		var n := Mapa.no(m, pos.x + 1, alvo)
		var tipo := str(n.tipo)
		var tc := Mapa.tipo_cfg(tipo)
		var cor_t := cor_tipo(tipo)
		_tela.draw_rect(Rect2(52, py + 12, 28, 28), cor_t)
		_tela.draw_rect(Rect2(54, py + 14, 24, 24), Color(0.12, 0.13, 0.2))
		_icone(Vector2(66, py + 26), tipo, cor_t)
		_txt(Vector2(92, py + 24), str(tc.get("nome", tipo)), 16, cor_t)
		_tela.draw_multiline_string(Dados.fonte, Vector2(92, py + 44), str(tc.get("info", "")), HORIZONTAL_ALIGNMENT_LEFT, W - 150, 8, 3, Color(0.8, 0.84, 0.95))
		if Mapa.combate(tipo) and tipo != "chefe":
			var fa: Dictionary = arena.diretor.fases()[pos.x + 1]
			_txt(Vector2(92, py + 74), "Fase: " + str(fa.get("nome", "")), 8, Color(0.6, 0.7, 0.9))
	else:
		_txt(Vector2(40, py + 44), "Sem caminho adiante.", 8, Color(1, 0.6, 0.6), W - 80, HORIZONTAL_ALIGNMENT_CENTER)
	# dica
	if _voto >= 0:
		_txt(Vector2(0, 352), "Voto enviado. Esperando os outros... %d s" % ceili(maxf(0.0, _espera - _agora())), 8, Color(0.7, 0.9, 1, 0.6 + 0.4 * pulso), W, HORIZONTAL_ALIGNMENT_CENTER)
	elif arena.eh_online:
		_txt(Vector2(0, 352), "Setas: escolher   Enter: votar (maioria, empate = anfitrião)", 8, Color(0.6, 0.65, 0.8), W, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_txt(Vector2(0, 352), "Setas: escolher   Enter: ir", 8, Color(0.6, 0.65, 0.8), W, HORIZONTAL_ALIGNMENT_CENTER)
