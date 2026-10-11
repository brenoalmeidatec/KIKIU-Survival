extends CanvasLayer
## Tela do mapa de progressão (#32 item 8): mostra o mapa inteiro, o caminho percorrido e as opções do próximo andar.
## Setas escolhem, Enter confirma; a informação do nó selecionado aparece embaixo. Com --bot escolhe sozinha em ~1 s.
## Solo: confirmar vai direto pra arena.escolher_no(). Online: confirmar manda o VOTO ao anfitrião e a tela fica
## aberta esperando; quem fecha é o evento "proxima_fase" do anfitrião (maioria, empate = anfitrião, limite de tempo).
## Tempo REAL (Time.get_ticks_msec), como resultado.gd, pra não depender de pausa nem de Engine.time_scale.
## Os dados e a geração ficam em mapa.gd; aqui só desenho e entrada.

const Mapa := preload("res://scripts/hordas/mapa.gd")
const Regioes := preload("res://scripts/hordas/regioes.gd")
const Cenario := preload("res://scripts/hordas/cenario.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")

const W := 640.0
const H := 360.0
const X0 := 54.0  # centro do andar 1
const DX := 58.0  # distância entre andares
const AREA := Rect2(16, 60, 608, 186)  # o mapa desenhado (chão e enfeites da região); o painel de informação fica embaixo
const MARGEM_Y := 20.0  # do topo/fundo da área até o centro da primeira/última faixa
const TRAVA := 0.35  # ignora teclas logo ao abrir (o botão que o jogador já estava apertando)
const AUTO_BOT := 1.0

var arena: Node
var _tela := Control.new()
var _aberto := false
var _t0 := 0
var _sel := 0  # índice em _opcoes
var _opcoes: Array = []  # faixas acessíveis a partir do nó atual
var _voto := -1  # online: faixa em que já votei
var _espera := 0.0  # online: segundos que faltam pro anfitrião fechar a votação
var _a0 := 0  # primeiro andar mostrado (veja _janela)
var _na := 10  # quantos andares mostrar


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
	_janela()
	_sel = 0
	_voto = -1
	_espera = float(Mapa.cfg().get("espera_voto", 40.0))
	_t0 = Time.get_ticks_msec()
	_aberto = true
	get_tree().paused = not arena.eh_online  # no online o jogo dos outros não para
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
	if Chat.digitando:  # o teclado é do chat (chat.gd)
		return
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


## Andares que a tela mostra: com regiões (#64), só os da região do PRÓXIMO andar (o mapa costurado tem 25);
## sem regiões, o mapa inteiro. Centralizados, mais espaçados quando são poucos.
func _janela() -> void:
	var m: Dictionary = arena.mapa
	var k := int(m.get("por_regiao", m.andares))
	_a0 = ((arena.mapa_pos.x + 1) / k) * k
	if _a0 >= int(m.andares):
		_a0 = maxi(0, int(m.andares) - k)
	_na = k


func centro_no(andar: int, faixa: int) -> Vector2:
	var dx := DX if _na >= 8 else minf(120.0, (W - 2.0 * X0) / maxf(1.0, _na - 1.0))
	var x0 := (W - dx * (_na - 1)) / 2.0
	var f := maxf(2.0, float(arena.mapa.faixas))
	var dy := (AREA.size.y - 2.0 * MARGEM_Y) / (f - 1.0)
	return Vector2(x0 + (andar - _a0) * dx, AREA.position.y + MARGEM_Y + faixa * dy)


# ---------- arte da região (#96): chão e enfeites do cenário da região, sem arte nova pra manter ----------

var _cenarios := {}  # nome -> Cenario carregado (ou null)
var _enfeites_de := ""  # chave do mapa/região dos enfeites já espalhados
var _enfeites: Array = []  # {item, pos (onde fica o pé)}


## Configuração de arte da região mostrada (dados/mapa.json > arte), com o "padrao" por baixo.
func _arte() -> Dictionary:
	var a: Dictionary = Mapa.cfg().get("arte", {})
	var res: Dictionary = a.get("padrao", {}).duplicate()
	var reg := _regiao()
	res.merge(a.get(str(reg.get("id", "")), {}), true)
	return res


func _regiao() -> Dictionary:
	return Regioes.regiao(Regioes.do_andar(_a0)) if Regioes.ativo() else {}


func _cenario() -> Cenario:
	var nome := str(_regiao().get("cenario", Cenario.da_fase(_a0)))
	if nome == "":
		return null
	if not _cenarios.has(nome):
		var c := Cenario.new()
		_cenarios[nome] = c if c.carregar(nome) else null
	return _cenarios[nome]


static func _cor(a, padrao := Color.WHITE) -> Color:
	return Color(a[0], a[1], a[2]) if a is Array and a.size() >= 3 else padrao


## Espalha os enfeites da região na área do mapa, longe dos nós e das trilhas (pra não esconder nada).
## Sorteio fixo pela semente e pela região: o mesmo mapa mostra sempre os mesmos enfeites.
func _espalhar(cen: Cenario, qtd: int) -> void:
	_enfeites = []
	if cen == null or cen.itens.is_empty():
		return
	var m: Dictionary = arena.mapa
	var centros := []
	var segs := []
	for a in range(_a0, mini(_a0 + _na, int(m.andares))):
		for x in int(m.faixas):
			var n := Mapa.no(m, a, x)
			if n.is_empty():
				continue
			centros.append(centro_no(a, x))
			if _na_janela(a + 1):
				for p in n.get("prox", []):
					segs.append([centro_no(a, x), centro_no(a + 1, int(p))])
	var r := Sorte.criar("mapa_arte", Regioes.do_andar(_a0))
	var dentro := AREA.grow(-3.0)
	for _i in qtd:
		var it: Dictionary = cen._item_sorteado(r)
		var tam: Vector2 = it.regiao.size
		var pe := Vector2(r.randf_range(dentro.position.x, dentro.end.x), r.randf_range(dentro.position.y, dentro.end.y))
		var ret := Rect2(pe - it.pe, tam)
		if not dentro.encloses(ret):
			continue
		var livre := true
		var folga := ret.grow(5.0)
		for c in centros:
			if folga.grow(12.0).has_point(c):
				livre = false
				break
		if livre:
			for s in segs:
				if _seg_toca(s[0], s[1], folga):
					livre = false
					break
		if livre:
			for e in _enfeites:
				if e.pos.distance_to(pe) < 14.0:
					livre = false
					break
		if livre:
			_enfeites.append({"item": it, "pos": pe})
	_enfeites.sort_custom(func(p, q): return p.pos.y < q.pos.y)


static func _seg_toca(de: Vector2, para: Vector2, r: Rect2) -> bool:
	var passos := maxi(1, int(de.distance_to(para) / 4.0))
	for i in passos + 1:
		if r.has_point(de.lerp(para, float(i) / passos)):
			return true
	return false


func _desenhar_regiao(arte: Dictionary) -> void:
	var tom := _cor(arte.get("tom"))
	var cen := _cenario()
	var chave := "%s|%d|%s" % [Mapa.resumo(arena.mapa), _a0, str(cen.nome if cen else "")]
	if chave != _enfeites_de:
		_enfeites_de = chave
		_espalhar(cen, int(arte.get("enfeites", 40)))
	var moldura := _cor(arte.get("moldura"), Color(0.45, 0.5, 0.65))
	_tela.draw_rect(AREA.grow(3.0), Color(0, 0, 0))
	_tela.draw_rect(AREA.grow(2.0), moldura)
	_tela.draw_rect(AREA.grow(1.0), moldura.darkened(0.55))
	var b := float(arte.get("piso", 0.5))
	if cen != null and cen.piso != null:
		_tela.draw_texture_rect(cen.piso, AREA, true, Color(tom.r * b, tom.g * b, tom.b * b))
	else:
		_tela.draw_rect(AREA, Color(0.1, 0.11, 0.16))
	if cen != null:
		var te := tom.lerp(Color.WHITE, 0.3) * Color(b + 0.25, b + 0.25, b + 0.25)
		for e in _enfeites:
			_tela.draw_texture_rect_region(cen.atlas, Rect2(e.pos - e.item.pe, e.item.regiao.size), e.item.regiao, te)
	# borda escurecida (vinheta) para o mapa parecer pintado e os nós saltarem
	for i in 10:
		var al := 0.32 * (1.0 - i / 10.0)
		var faixa := Rect2(AREA.position + Vector2(i, i), AREA.size - Vector2(i, i) * 2.0)
		_tela.draw_rect(faixa, Color(0, 0, 0, al), false, 1.0)
	# cantos da moldura
	for c in [AREA.position, Vector2(AREA.end.x, AREA.position.y), Vector2(AREA.position.x, AREA.end.y), AREA.end]:
		_tela.draw_rect(Rect2(c - Vector2(4, 4), Vector2(8, 8)), Color(0, 0, 0))
		_tela.draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), moldura)
		_tela.draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), moldura.lightened(0.5))


## Trilha pontilhada (contorno escuro + traços), como num mapa desenhado.
func _trilha(de: Vector2, para: Vector2, cor: Color, larg: float) -> void:
	var d := de.distance_to(para)
	var dir := (para - de) / maxf(1.0, d)
	var t := 14.0
	while t < d - 14.0:
		var a := de + dir * t
		var b := de + dir * minf(t + 5.0, d - 14.0)
		_tela.draw_line(a, b, Color(0, 0, 0, cor.a * 0.8), larg + 2.0)
		_tela.draw_line(a, b, cor, larg)
		t += 9.0


func _na_janela(andar: int) -> bool:
	return andar >= _a0 and andar < _a0 + _na


static func cor_tipo(tipo: String) -> Color:
	var c: Array = Mapa.tipo_cfg(tipo).get("cor", [1, 1, 1])
	return Color(c[0], c[1], c[2])


## Ícone do tipo, desenhado à mão (sem arte): cabe num quadrado de ~20 px centrado em p.
func _icone(p: Vector2, tipo: String, cor: Color) -> void:
	var t := _tela
	match tipo:
		"fase":  # duas espadas cruzadas
			t.draw_line(p + Vector2(-7, 7), p + Vector2(7, -7), cor, 2.0)
			t.draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), cor, 2.0)
			t.draw_rect(Rect2(p + Vector2(-3, 2), Vector2(6, 2)), cor)
		"elite":  # caveira
			t.draw_circle(p + Vector2(0, -2), 6.0, cor)
			t.draw_rect(Rect2(p + Vector2(-3, 3), Vector2(6, 5)), cor)
			t.draw_rect(Rect2(p + Vector2(-4, -3), Vector2(3, 3)), Color(0.08, 0.08, 0.12))
			t.draw_rect(Rect2(p + Vector2(1, -3), Vector2(3, 3)), Color(0.08, 0.08, 0.12))
		"descanso":  # fogueira: chama
			t.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(6, 2), p + Vector2(3, 7), p + Vector2(-3, 7), p + Vector2(-6, 2)]), cor)
			t.draw_colored_polygon(
				PackedVector2Array([p + Vector2(0, -1), p + Vector2(3, 3), p + Vector2(0, 7), p + Vector2(-3, 3)]), Color(1, 0.95, 0.6, cor.a)
			)
		"loja":  # moeda
			t.draw_circle(p, 8.0, cor)
			t.draw_circle(p, 5.5, Color(cor.r * 0.6, cor.g * 0.6, cor.b * 0.6, cor.a))
			_txt(p + Vector2(-4, 4), "$", 8, cor)
		"evento":
			_txt(p + Vector2(-5, 6), "?", 16, cor)
		"santuario":  # losango duplo
			t.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(7, 0), p + Vector2(0, 9), p + Vector2(-7, 0)]), cor)
			t.draw_colored_polygon(
				PackedVector2Array([p + Vector2(0, -4), p + Vector2(3, 0), p + Vector2(0, 4), p + Vector2(-3, 0)]), Color(0.12, 0.1, 0.16, cor.a)
			)
		"chefe":  # caveira com coroa
			t.draw_circle(p + Vector2(0, 1), 8.0, cor)
			t.draw_rect(Rect2(p + Vector2(-4, 6), Vector2(8, 5)), cor)
			t.draw_rect(Rect2(p + Vector2(-5, -1), Vector2(4, 4)), Color(0.08, 0.08, 0.12))
			t.draw_rect(Rect2(p + Vector2(1, -1), Vector2(4, 4)), Color(0.08, 0.08, 0.12))
			t.draw_colored_polygon(
				PackedVector2Array(
					[
						p + Vector2(-8, -6),
						p + Vector2(-8, -12),
						p + Vector2(-4, -8),
						p + Vector2(0, -13),
						p + Vector2(4, -8),
						p + Vector2(8, -12),
						p + Vector2(8, -6)
					]
				),
				cor
			)


func _desenhar() -> void:
	if not _aberto:
		return
	var m: Dictionary = arena.mapa
	var pos: Vector2i = arena.mapa_pos
	var tt := Time.get_ticks_msec() / 1000.0
	var pulso := 0.6 + 0.4 * sin(tt * 6.0)
	var arte := _arte()
	_tela.draw_rect(Rect2(0, 0, W, H), _cor(arte.get("fundo"), Color(0.03, 0.03, 0.08)))
	_desenhar_regiao(arte)
	var cor_trilha := _cor(arte.get("trilha"), Color(0.7, 0.72, 0.85))
	var fases: Array = arena.diretor.fases()
	var prox_f: Dictionary = fases[clampi(pos.x + 1, 0, fases.size() - 1)] if not fases.is_empty() else {}
	if prox_f.has("regiao"):  # regiões (#64): o nome da região no lugar de "MAPA"
		_txt(Vector2(0, 30), str(prox_f.regiao_nome).to_upper(), 16, Color(1, 0.9, 0.4), W, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(
			Vector2(0, 50),
			"Região %d de %d   ·   andar %d de %d" % [int(prox_f.regiao) + 1, int(m.andares) / _na, pos.x + 2 - _a0, _na],
			8,
			Color(0.7, 0.9, 1),
			W,
			HORIZONTAL_ALIGNMENT_CENTER
		)
	else:
		_txt(Vector2(0, 30), "MAPA", 16, Color(1, 0.9, 0.4), W, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(0, 50), "Andar %d de %d" % [pos.x + 1, int(m.andares)], 8, Color(0.7, 0.9, 1), W, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(W - 150, 24), "OURO %d" % arena.ouro, 8, Color(1, 0.85, 0.35), 138.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var trilha: Array = arena.mapa_trilha
	var alvo := -1 if _opcoes.is_empty() else int(_opcoes[_sel])
	# ligações: apagadas, e acesas as do caminho percorrido e as que saem do nó atual
	for a in int(m.andares) - 1:
		if not (_na_janela(a) and _na_janela(a + 1)):
			continue
		for x in int(m.faixas):
			var n := Mapa.no(m, a, x)
			for p in n.get("prox", []):
				var de := centro_no(a, x)
				var para := centro_no(a + 1, int(p))
				if Vector2i(a, x) in trilha and Vector2i(a + 1, int(p)) in trilha:  # caminho já feito: linha cheia dourada
					_tela.draw_line(de, para, Color(0, 0, 0, 0.8), 5.0)
					_tela.draw_line(de, para, Color(0.95, 0.85, 0.4), 3.0)
				elif a == pos.x and x == pos.y:  # as opções de agora: a escolhida pisca
					_trilha(
						de,
						para,
						Color(1, 1, 1, 0.55 + 0.45 * pulso) if int(p) == alvo else Color(cor_trilha.lightened(0.3), 0.95),
						3.0 if int(p) == alvo else 2.0
					)
				else:
					_trilha(de, para, Color(cor_trilha, 0.75), 1.0)
	# nós
	for a in int(m.andares):
		if not _na_janela(a):
			continue
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
			var fundo := Color(0.07, 0.07, 0.11, 0.92)
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
				_tela.draw_colored_polygon(
					PackedVector2Array([c + Vector2(-5, -raio - 8), c + Vector2(5, -raio - 8), c + Vector2(0, -raio - 2)]), Color(1, 1, 1, pulso)
				)
	# painel de informação do nó selecionado
	var py := 258.0
	_tela.draw_rect(Rect2(38, py - 2, W - 76, 84), _cor(arte.get("moldura"), Color(0.35, 0.4, 0.55)))
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
		_tela.draw_multiline_string(
			Dados.fonte, Vector2(92, py + 44), str(tc.get("info", "")), HORIZONTAL_ALIGNMENT_LEFT, W - 150, 8, 3, Color(0.8, 0.84, 0.95)
		)
		if Mapa.combate(tipo):
			var fa: Dictionary = arena.diretor.fases()[pos.x + 1]
			if tipo == "chefe":  # quem espera no fim da região
				var ch := str(fa.get("chefe", ""))
				_txt(
					Vector2(92, py + 74), "%s  ·  chefe: %s" % [fa.get("nome", ""), Dados.json("inimigos").get(ch, {}).get("nome", ch)], 8, Color(1, 0.6, 0.55)
				)
			else:
				_txt(Vector2(92, py + 74), "Fase: " + str(fa.get("nome", "")), 8, Color(0.6, 0.7, 0.9))
	else:
		_txt(Vector2(40, py + 44), "Sem caminho adiante.", 8, Color(1, 0.6, 0.6), W - 80, HORIZONTAL_ALIGNMENT_CENTER)
	# dica
	if _voto >= 0:
		_txt(
			Vector2(0, 352),
			"Voto enviado. Esperando os outros... %d s" % ceili(maxf(0.0, _espera - _agora())),
			8,
			Color(0.7, 0.9, 1, 0.6 + 0.4 * pulso),
			W,
			HORIZONTAL_ALIGNMENT_CENTER
		)
	elif arena.eh_online:
		_txt(Vector2(0, 352), "Setas: escolher   Enter: votar (maioria, empate = anfitrião)", 8, Color(0.6, 0.65, 0.8), W, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_txt(Vector2(0, 352), "Setas: escolher   Enter: ir", 8, Color(0.6, 0.65, 0.8), W, HORIZONTAL_ALIGNMENT_CENTER)
