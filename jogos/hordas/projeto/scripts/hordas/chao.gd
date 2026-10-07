extends Node2D
const Perf := preload("res://scripts/hordas/perf.gd")
## Chão infinito (azulejos que se repetem), enfeites espalhados e os santuários (tomadas).
## Santuário (ideia do Megabonk): fique dentro do círculo até carregar e ganhe uma carta.

const Visual := preload("res://scripts/hordas/visual.gd")
const ESCALA := 2.0
const BLOCO := 256.0          # tamanho da textura do chão na tela (128 px x 2)
const CEL_DECO := 150.0
const Cenario := preload("res://scripts/hordas/cenario.gd")
const Descobertas := preload("res://scripts/hordas/descobertas.gd")
const Ambiente := preload("res://scripts/hordas/ambiente.gd")
const Regioes := preload("res://scripts/hordas/regioes.gd")
## cor do anel de cada tipo de santuário
const COR_TIPO := {"tomada": Color(1.0, 0.85, 0.3), "dadiva": Color(0.4, 0.9, 1.0), "fragmento": Color(0.45, 0.55, 1.0), "maldito": Color(0.85, 0.35, 0.8)}

var arena: Node
var _fundo := TextureRect.new()
var santuarios: Array = []    # {pos, carga, usado}
var _t := 0.0
var _deco: Texture2D
var _deco_regioes := [Rect2(0, 0, 14, 18), Rect2(15, 6, 10, 12), Rect2(26, 12, 8, 6), Rect2(35, 6, 14, 12)]
var cenario = null              # cenário da fase (Cenario), ou null = chão antigo
var _bloco := BLOCO             # lado do azulejo na tela
var _desloc := Vector2(512, 384)  # o azulejo começa até isso à esquerda/acima da câmera
var _luzes := Node2D.new()      # halos das luzes do cenário, somados (blend ADD) por cima de tudo
var _ambiente := CanvasModulate.new()
var _amb := Ambiente.new()      # detalhes de chão, partículas e bichos do cenário (#32 item 2)


func _ready() -> void:
	z_index = -10
	_fundo.texture = Dados.tex("chao")
	_fundo.stretch_mode = TextureRect.STRETCH_TILE
	# tela 640x360 + passo de 256 da posição + folga: com 1280x1024 nunca sobra borda preta
	_fundo.size = Vector2(1280, 1024) / ESCALA
	_fundo.scale = Vector2(ESCALA, ESCALA)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.show_behind_parent = true
	add_child(_fundo)
	_deco = Dados.tex("deco")
	_luzes.z_index = 60
	var somar := CanvasItemMaterial.new()
	somar.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_luzes.material = somar
	_luzes.draw.connect(_desenhar_luzes)
	add_child(_luzes)
	add_child(_ambiente)
	add_child(_amb)
	_aplicar_cenario.call_deferred()


func criar_santuarios() -> void:
	var di = arena.diretor
	var fase: Dictionary = di.fases()[di.fase_idx]
	# posições e tipos vêm da semente da corrida (descobertas.gd): no online os dois lados veem os mesmos santuários.
	# Online a âncora é a origem do mapa (cada jogador está num lugar); solo, onde o jogador está.
	var c: Vector2 = Vector2.ZERO if arena.jogador == null or arena.eh_online else arena.jogador.position
	santuarios.append_array(Descobertas.planejar_fase(di.fase_idx, di.fases().size(), int(fase.get("santuarios", 6)), c))
	var cor: Array = fase.get("cor", [1, 1, 1])
	_fundo.modulate = Color(cor[0], cor[1], cor[2])


## Nova fase: tomadas novas em volta de onde o jogador está e o chão muda de cor.
func nova_fase() -> void:
	_aplicar_cenario()
	_aplicar_luz()   # o cenário pode ser o mesmo do andar anterior (mesma região), mas a luz muda
	santuarios.clear()
	criar_santuarios()


func mais_perto_livre(p: Vector2):
	var melhor = null
	var md := INF
	for s in santuarios:
		if s.usado:
			continue
		var d: float = s.pos.distance_squared_to(p)
		if d < md:
			md = d
			melhor = s
	return melhor


func atualizar(dt: float) -> void:
	var _pp := Perf.ini()
	atualizar_i(dt)
	Perf.fim("chao_a", _pp)


func atualizar_i(dt: float) -> void:
	_t += dt
	var cam: Vector2 = arena.camera.position
	_fundo.position = Vector2(floorf((cam.x - _desloc.x) / _bloco) * _bloco, floorf((cam.y - _desloc.y) / _bloco) * _bloco)
	var cfg: Dictionary = Descobertas.cfg().get("santuarios", {})
	var raio := float(cfg.get("raio_interacao", 48.0))
	var tempo_tomada := float(Dados.json("fase").get("santuario_tempo", cfg.get("tempo_carga_tomada", 4.0)))
	var tempo_outros := float(cfg.get("tempo_carga", 5.0))
	var jp: Vector2 = arena.jogador.position
	for s in santuarios:
		if s.usado:
			continue
		var tempo := tempo_tomada if s.tipo == "tomada" else tempo_outros
		if s.pos.distance_to(jp) < raio:
			s.carga += dt / tempo
			if s.carga >= 1.0:
				s.carga = 1.0
				arena.descobertas.ativar(s)   # tipo decide: carta, dádiva, fragmento (com variação) ou maldição
		else:
			s.carga = maxf(0.0, s.carga - dt / tempo * 0.5)
	_luzes.queue_redraw()
	_amb.atualizar(dt)
	queue_redraw()


## Troca o piso, os enfeites e o tom do ambiente pro cenário da fase atual (dados/cenarios.json).
## Sem cenário configurado, fica o chão antigo.
## Luz do andar (#68): cada região começa convidativa e escurece andar a andar até o chefe, puxando pro tom dele
## (regioes.json > luz, que cada região pode sobrescrever). Sem regiões, é o ambiente do cenário puro.
func _aplicar_luz() -> void:
	if cenario == null:
		return
	var cor: Color = cenario.ambiente
	if arena and arena.diretor and Regioes.ativo():
		var fs: Array = arena.diretor.fases()
		var f: Dictionary = fs[clampi(arena.diretor.fase_idx, 0, fs.size() - 1)] if not fs.is_empty() else {}
		if f.has("andar_regiao"):
			var luz: Dictionary = Regioes.cfg().get("luz", {}).merged(Regioes.regiao(int(f.get("regiao", 0))).get("luz", {}), true)
			var u := clampf(float(f.andar_regiao) / maxf(1.0, Regioes.por_regiao() - 1.0), 0.0, 1.0)   # 0 na entrada, 1 no chefe
			var fator := lerpf(1.0, float(luz.get("chefe", 0.8)), u)
			var tom: Array = luz.get("tom_chefe", [1.0, 1.0, 1.0])
			var t := Color(float(tom[0]), float(tom[1]), float(tom[2])).lerp(Color.WHITE, 1.0 - u)
			cor = Color(cor.r * fator * t.r, cor.g * fator * t.g, cor.b * fator * t.b, cor.a)
	_ambiente.color = cor


func _aplicar_cenario() -> void:
	var n := Cenario.da_fase(arena.diretor.fase_idx if arena and arena.diretor else 0)
	if arena and arena.diretor:   # regiões (#64): a fase diz o cenário (o da região dela)
		var fs: Array = arena.diretor.fases()
		var f: Dictionary = fs[clampi(arena.diretor.fase_idx, 0, fs.size() - 1)] if not fs.is_empty() else {}
		if f.has("cenario"):
			n = str(f.cenario)
	if n == "" or (cenario and cenario.nome == n):
		return
	var c = Cenario.new()
	if not c.carregar(n):
		return
	cenario = c
	_fundo.texture = c.piso
	_fundo.scale = Vector2.ONE
	_bloco = c.piso.get_width()
	# o azulejo começa um múltiplo do bloco antes da câmera e cobre a tela (640x360) com folga em qualquer posição
	_desloc = Vector2(ceilf(330.0 / _bloco) * _bloco, ceilf(190.0 / _bloco) * _bloco)
	_fundo.size = _desloc + Vector2(_bloco, _bloco) + Vector2(330, 190)
	_aplicar_luz()
	_amb.configurar(c, arena)


var _enf_cen = null
var _enf_a := Vector2i.ZERO
var _enf_b := Vector2i.ZERO
var _enf_ta := Vector2i.ZERO
var _enf_tb := Vector2i.ZERO
var _enf_lista: Array = []


## Enfeites na tela: [pé no mundo, item, número sorteado]. Espalhados por célula (sempre iguais no mesmo lugar)
## e, se o cenário tiver, os fixos de cada azulejo (ex.: postes nas esquinas da cidade).
func _enfeites_na_tela() -> Array:
	var cam: Vector2 = arena.camera.position
	var a := Vector2i(floori((cam.x - 380) / Cenario.CEL), floori((cam.y - 260) / Cenario.CEL))
	var b := Vector2i(floori((cam.x + 380) / Cenario.CEL), floori((cam.y + 260) / Cenario.CEL))
	var ta := Vector2i(floori((cam.x - 400) / _bloco), floori((cam.y - 300) / _bloco))
	var tb := Vector2i(floori((cam.x + 400) / _bloco), floori((cam.y + 300) / _bloco))
	# a lista só muda quando a câmera entra em célula nova (a cada ~150 px): guarda e reaproveita (era refeita e ordenada 2x por quadro)
	if _enf_cen == cenario and _enf_a == a and _enf_b == b and _enf_ta == ta and _enf_tb == tb:
		return _enf_lista
	var res := []
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			for p in cenario.celula(cx, cy).props:   # sorteados pela semente da corrida (Cenario.celula)
				res.append([p.pos, p.item, p.k])
	if not cenario.fixos.is_empty():
		for ty in range(ta.y, tb.y + 1):
			for tx in range(ta.x, tb.x + 1):
				for f in cenario.fixos:
					res.append([Vector2(tx, ty) * _bloco + f.pos, f.item, hash(Vector2i(tx, ty)) + int(f.pos.x)])
	res.sort_custom(func(p, q): return p[0].y < q[0].y)   # quem está mais embaixo fica na frente
	_enf_cen = cenario
	_enf_a = a
	_enf_b = b
	_enf_ta = ta
	_enf_tb = tb
	_enf_lista = res
	return res


## Halos das luzes (poça no chão e brilho na fonte), somados à cena. A chama cintila um pouco.
func _desenhar_luzes() -> void:
	if cenario == null:
		return
	for e in _enfeites_na_tela():
		var l: Dictionary = e[1].luz
		if l.is_empty():
			continue
		var k: int = e[2]
		# chama que treme: três senos de períodos diferentes (não repete na vista) e a poça respira junto
		var ruido := sin(_t * 11.0 + k % 97) * sin(_t * 7.3 + k % 53) + 0.5 * sin(_t * 23.0 + k % 31)
		var f: float = clampf(1.0 - float(l.pisca) * (0.5 + 0.4 * ruido), 0.0, 1.0)
		var poca: Rect2 = l.poca
		var halo: Rect2 = l.halo
		var respira := 1.0 + float(l.pisca) * 0.12 * ruido
		var ps: Vector2 = poca.size * respira
		_luzes.draw_texture_rect_region(cenario.atlas, Rect2(e[0] + Vector2(l.fonte.x, 0) - ps / 2, ps), poca, Color(1, 1, 1, f))   # poça embaixo da lâmpada
		_luzes.draw_texture_rect_region(cenario.atlas, Rect2(e[0] + l.fonte - halo.size / 2, halo.size), halo, Color(1, 1, 1, f))


func _draw() -> void:
	var _pp := Perf.ini()
	_draw_i()
	Perf.fim("chao_d", _pp)


func _draw_i() -> void:
	if cenario:
		var vis: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()   # só desenha o que cai na tela (com folga pro tamanho)
		for e in _enfeites_na_tela():
			var it: Dictionary = e[1]
			var reg: Rect2 = it.regiao
			var pe: Vector2 = it.pe
			var ep: Vector2 = e[0]
			var folga := maxf(reg.size.x, reg.size.y) * 1.6 + 24.0
			if ep.x < vis.position.x - folga or ep.x > vis.end.x + folga or ep.y < vis.position.y - folga or ep.y > vis.end.y + folga:
				continue
			Visual.contato(self, e[0], reg.size.x * 0.8)
			Visual.sombra(self, cenario.atlas, Rect2(-pe, reg.size), reg, e[0])
			draw_texture_rect_region(cenario.atlas, Rect2(e[0] - pe, reg.size), reg)
	else:
		_draw_enfeites_antigos()
	var tex := Dados.tex(str(Descobertas.cfg().get("santuarios", {}).get("sprite", "tomada")))   # a pira (#65)
	for s in santuarios:
		var base: Color = COR_TIPO.get(s.tipo, Color.WHITE)
		var cor := Color(0.4, 0.6, 0.7, 0.5) if s.usado else Color(base, 0.8)
		draw_set_transform(s.pos, 0, Vector2(1, 0.55))
		draw_circle(Vector2.ZERO, 48, Color(cor, 0.12))
		draw_arc(Vector2.ZERO, 48, 0, TAU, 40, cor, 2)
		if s.carga > 0 and not s.usado:
			draw_arc(Vector2.ZERO, 44, -PI / 2, -PI / 2 + TAU * s.carga, 40, Color(0.5, 1.0, 0.5), 4)
		if s.get("prog", 0.0) > 0.0:   # desafio em andamento (santuário do combate): anel que enche
			draw_arc(Vector2.ZERO, 44, -PI / 2, -PI / 2 + TAU * s.prog, 40, Color(1.0, 0.6, 0.25), 4)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var sz := tex.get_size() * ESCALA
		var flut := 0.0 if s.usado else sin(_t * 3.0) * 2.0
		var alt := 2.0 - flut   # flutuando: a sombra fica no chão e encolhe quando sobe
		Visual.contato(self, s.pos, sz.x * 0.8, alt)
		Visual.sombra(self, tex, Rect2(-sz.x / 2, -sz.y, sz.x, sz.y), Rect2(Vector2.ZERO, tex.get_size()), s.pos, alt)
		var tinta := Color.WHITE if s.tipo == "tomada" else Color.WHITE.lerp(base, 0.55)
		draw_texture_rect(tex, Rect2(s.pos - Vector2(sz.x / 2, sz.y) + Vector2(0, flut), sz), false, Color(0.6, 0.6, 0.6) if s.usado else tinta)
		if s.usado:
			continue
		if s.tipo != "tomada":   # energia girando em volta e, no do dragão, o fragmento flutuando em cima
			for k in 4:
				var ang := _t * 1.6 + k * TAU / 4.0
				draw_circle(s.pos + Vector2(cos(ang) * 30.0, sin(ang) * 16.0 - sz.y * 0.45), 1.8, Color(base, 0.9))
		if s.tipo == "fragmento":
			var c: Vector2 = s.pos + Vector2(0, -sz.y - 14.0 + flut)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0)]), Color(0.55, 0.8, 1.0))
		if s.pos.distance_to(arena.jogador.position) < 150.0:   # dica de interação
			var cs: Dictionary = Descobertas.cfg().get("santuarios", {})
			var nome := str(cs.get("variacoes", {}).get(str(s.variacao), {}).get("nome", ""))
			nome = str(cs.get("nomes", {}).get(str(s.tipo), nome))   # dádiva, maldito, tomada: o nome do tipo (#65)
			draw_string(Dados.fonte, s.pos + Vector2(-130, 22), nome, HORIZONTAL_ALIGNMENT_CENTER, 260, 8, Color(base, 1.0))
			draw_string(Dados.fonte, s.pos + Vector2(-130, 33), "fique perto", HORIZONTAL_ALIGNMENT_CENTER, 260, 8, Color(0.85, 0.85, 0.9, 0.8))


## Enfeites do chão antigo (sem cenário configurado).
func _draw_enfeites_antigos() -> void:
	var cam: Vector2 = arena.camera.position
	var a := Vector2i(floori((cam.x - 380) / CEL_DECO), floori((cam.y - 240) / CEL_DECO))
	var b := Vector2i(floori((cam.x + 380) / CEL_DECO), floori((cam.y + 240) / CEL_DECO))
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var h := hash(Vector2i(cx, cy))
			if h % 100 >= 30:
				continue
			var reg: Rect2 = _deco_regioes[(h / 100) % _deco_regioes.size()]
			var p := Vector2(cx * CEL_DECO + (h / 7) % 110, cy * CEL_DECO + (h / 13) % 110)
			var sz := reg.size * ESCALA
			Visual.contato(self, p + Vector2(sz.x / 2, sz.y), sz.x * 0.9)
			Visual.sombra(self, _deco, Rect2(-sz.x / 2, -sz.y, sz.x, sz.y), reg, p + Vector2(sz.x / 2, sz.y))
			draw_texture_rect_region(_deco, Rect2(p, reg.size * ESCALA), reg, Color(1, 1, 1, 0.9))
