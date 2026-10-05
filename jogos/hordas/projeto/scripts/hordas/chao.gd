extends Node2D
## Chão infinito (azulejos que se repetem), enfeites espalhados e os santuários (tomadas).
## Santuário (ideia do Megabonk): fique dentro do círculo até carregar e ganhe uma carta.

const Visual := preload("res://scripts/hordas/visual.gd")
const ESCALA := 2.0
const BLOCO := 256.0          # tamanho da textura do chão na tela (128 px x 2)
const CEL_DECO := 150.0
const Cenario := preload("res://scripts/hordas/cenario.gd")

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
	_aplicar_cenario.call_deferred()


func criar_santuarios() -> void:
	var fase: Dictionary = arena.diretor.fases()[arena.diretor.fase_idx]
	var n := int(fase.get("santuarios", 6))
	var c: Vector2 = Vector2.ZERO if arena.jogador == null else arena.jogador.position
	for i in n:
		var a := TAU * i / float(n) + randf_range(-0.3, 0.3)
		santuarios.append({"pos": c + Vector2.from_angle(a) * randf_range(350, 900), "carga": 0.0, "usado": false})
	var cor: Array = fase.get("cor", [1, 1, 1])
	_fundo.modulate = Color(cor[0], cor[1], cor[2])


## Nova fase: tomadas novas em volta de onde o jogador está e o chão muda de cor.
func nova_fase() -> void:
	_aplicar_cenario()
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
	_t += dt
	var cam: Vector2 = arena.camera.position
	_fundo.position = Vector2(floorf((cam.x - _desloc.x) / _bloco) * _bloco, floorf((cam.y - _desloc.y) / _bloco) * _bloco)
	var tempo := float(Dados.json("fase").get("santuario_tempo", 4.0))
	for s in santuarios:
		if s.usado:
			continue
		if s.pos.distance_to(arena.jogador.position) < 48:
			s.carga += dt / tempo
			if s.carga >= 1.0:
				s.usado = true
				arena.ganhar_carta_tomada()
		else:
			s.carga = maxf(0.0, s.carga - dt / tempo * 0.5)
	_luzes.queue_redraw()
	queue_redraw()


## Troca o piso, os enfeites e o tom do ambiente pro cenário da fase atual (dados/cenarios.json).
## Sem cenário configurado, fica o chão antigo.
func _aplicar_cenario() -> void:
	var n := Cenario.da_fase(arena.diretor.fase_idx if arena and arena.diretor else 0)
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
	_ambiente.color = c.ambiente


## Enfeites na tela: [pé no mundo, item, número sorteado]. Espalhados por célula (sempre iguais no mesmo lugar)
## e, se o cenário tiver, os fixos de cada azulejo (ex.: postes nas esquinas da cidade).
func _enfeites_na_tela() -> Array:
	var res := []
	var cam: Vector2 = arena.camera.position
	var a := Vector2i(floori((cam.x - 380) / CEL_DECO), floori((cam.y - 260) / CEL_DECO))
	var b := Vector2i(floori((cam.x + 380) / CEL_DECO), floori((cam.y + 260) / CEL_DECO))
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var h := hash(Vector2i(cx, cy))
			if h % 100 >= int(cenario.densidade * 100):
				continue
			var it: Dictionary = cenario.item_por(h / 100)
			if it.peso <= 0:
				continue
			res.append([Vector2(cx * CEL_DECO + (h / 7) % 110, cy * CEL_DECO + (h / 13) % 110), it, h])
	if not cenario.fixos.is_empty():
		var ta := Vector2i(floori((cam.x - 400) / _bloco), floori((cam.y - 300) / _bloco))
		var tb := Vector2i(floori((cam.x + 400) / _bloco), floori((cam.y + 300) / _bloco))
		for ty in range(ta.y, tb.y + 1):
			for tx in range(ta.x, tb.x + 1):
				for f in cenario.fixos:
					res.append([Vector2(tx, ty) * _bloco + f.pos, f.item, hash(Vector2i(tx, ty)) + int(f.pos.x)])
	res.sort_custom(func(p, q): return p[0].y < q[0].y)   # quem está mais embaixo fica na frente
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
		var f: float = 1.0 - float(l.pisca) * (0.5 + 0.5 * sin(_t * 11.0 + k % 97) * sin(_t * 7.3 + k % 53))
		var poca: Rect2 = l.poca
		var halo: Rect2 = l.halo
		_luzes.draw_texture_rect_region(cenario.atlas, Rect2(e[0] + Vector2(l.fonte.x, 0) - poca.size / 2, poca.size), poca, Color(1, 1, 1, f))   # poça embaixo da lâmpada
		_luzes.draw_texture_rect_region(cenario.atlas, Rect2(e[0] + l.fonte - halo.size / 2, halo.size), halo, Color(1, 1, 1, f))


func _draw() -> void:
	if cenario:
		for e in _enfeites_na_tela():
			var it: Dictionary = e[1]
			var reg: Rect2 = it.regiao
			var pe: Vector2 = it.pe
			Visual.contato(self, e[0], reg.size.x * 0.8)
			Visual.sombra(self, cenario.atlas, Rect2(-pe, reg.size), reg, e[0])
			draw_texture_rect_region(cenario.atlas, Rect2(e[0] - pe, reg.size), reg)
	else:
		_draw_enfeites_antigos()
	var tex := Dados.tex("tomada")
	for s in santuarios:
		var cor := Color(0.4, 0.6, 0.7, 0.5) if s.usado else Color(1.0, 0.85, 0.3, 0.8)
		draw_set_transform(s.pos, 0, Vector2(1, 0.55))
		draw_circle(Vector2.ZERO, 48, Color(cor, 0.12))
		draw_arc(Vector2.ZERO, 48, 0, TAU, 40, cor, 2)
		if s.carga > 0 and not s.usado:
			draw_arc(Vector2.ZERO, 44, -PI / 2, -PI / 2 + TAU * s.carga, 40, Color(0.5, 1.0, 0.5), 4)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var sz := tex.get_size() * ESCALA
		var flut := 0.0 if s.usado else sin(_t * 3.0) * 2.0
		var alt := 2.0 - flut   # flutuando: a sombra fica no chão e encolhe quando sobe
		Visual.contato(self, s.pos, sz.x * 0.8, alt)
		Visual.sombra(self, tex, Rect2(-sz.x / 2, -sz.y, sz.x, sz.y), Rect2(Vector2.ZERO, tex.get_size()), s.pos, alt)
		draw_texture_rect(tex, Rect2(s.pos - Vector2(sz.x / 2, sz.y) + Vector2(0, flut), sz), false, Color(0.6, 0.6, 0.6) if s.usado else Color.WHITE)


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
