extends "res://minijogos/base.gd"
## QW: o joguinho velho que o Lukako ainda joga. Navinha embaixo, coisas caindo de cima.
## Esquerda/direita move, E atira. Acerte a meta antes de deixar passar três.

var _x := 220.0
var _tiros: Array = []      # Vector2
var _inimigos: Array = []   # [Vector2, vel]
var _prox := 0.0
var _pontos := 0
var _meta := 10
var _passaram := 0
var _recarga := 0.0
var _estrelas: Array = []


func _init() -> void:
	musica = "minijogo_retro"
	titulo = "QW das antigas"
	instrucoes = "O Lukako te chamou pra uma partida de QW. Ninguém mais joga isso.\nEsquerda/direita move, E atira.\nAcerte os bichos antes que três passem."


func _comecar() -> void:
	_x = 220.0
	_tiros.clear()
	_inimigos.clear()
	_prox = 0.6
	_pontos = 0
	_meta = 6 + dificuldade * 4
	_passaram = 0
	_estrelas.clear()
	for i in 30:
		_estrelas.append(Vector2(randf() * 440, randf() * 196))


func _process(delta: float) -> void:
	if estado != "jogando":
		return
	var mov := Input.get_axis("esquerda", "direita")
	_x = clamp(_x + mov * 170.0 * delta, 16.0, 424.0)
	_recarga = max(_recarga - delta, 0.0)
	for i in _estrelas.size():
		_estrelas[i].y = fmod(_estrelas[i].y + 30.0 * delta, 196.0)
	for t in _tiros:
		t.y -= 260.0 * delta
	_tiros = _tiros.filter(func(t): return t.y > 0.0)
	_prox -= delta
	if _prox <= 0.0:
		_prox = randf_range(0.6, 1.2) / (0.8 + dificuldade * 0.25)
		_inimigos.append([Vector2(randf_range(24, 416), -10), randf_range(30, 50) + dificuldade * 12.0])
	for e in _inimigos:
		e[0].y += e[1] * delta
	var vivos: Array = []
	for e in _inimigos:
		var morto := false
		for t in _tiros:
			if t.distance_to(e[0]) < 12.0:
				morto = true
				_tiros.erase(t)
				break
		if morto:
			_pontos += 1
			Jogo.som("acerto")
			if _pontos >= _meta:
				vencer()
				return
		elif e[0].y > 200.0:
			_passaram += 1
			Jogo.som("erro")
			if _passaram >= 3:
				perder("Game over. O Lukako fez 9.999.990 pontos. Ninguém sabe como.")
				return
		else:
			vivos.append(e)
	_inimigos = vivos
	area.queue_redraw()


func _tecla(event: InputEvent) -> void:
	if acao_de(event) == "interagir" and _recarga <= 0.0:
		_tiros.append(Vector2(_x, 170))
		_recarga = 0.18
		Jogo.som("cursor")


func _desenhar(a: Control) -> void:
	a.draw_rect(Rect2(0, 0, 440, 196), Color("05060f"))
	for s in _estrelas:
		a.draw_rect(Rect2(s, Vector2(1, 1)), Color("6b7299"))
	for e in _inimigos:
		var p: Vector2 = e[0]
		a.draw_rect(Rect2(p + Vector2(-8, -5), Vector2(16, 10)), Color("c070e0"))
		a.draw_rect(Rect2(p + Vector2(-5, -1), Vector2(3, 3)), Color("05060f"))
		a.draw_rect(Rect2(p + Vector2(2, -1), Vector2(3, 3)), Color("05060f"))
		a.draw_rect(Rect2(p + Vector2(-10, 3), Vector2(4, 4)), Color("c070e0"))
		a.draw_rect(Rect2(p + Vector2(6, 3), Vector2(4, 4)), Color("c070e0"))
	for t in _tiros:
		a.draw_rect(Rect2(t + Vector2(-1, -4), Vector2(2, 8)), AMARELO)
	# navinha
	a.draw_colored_polygon(PackedVector2Array([Vector2(_x, 168), Vector2(_x + 12, 188), Vector2(_x - 12, 188)]), Color("4b9be8"))
	a.draw_rect(Rect2(_x - 2, 176, 4, 6), BRANCO)
	texto(a, Vector2(8, 14), "PONTOS %d/%d" % [_pontos, _meta], VERDE)
	for i in 3:
		a.draw_rect(Rect2(420 - i * 12, 6, 8, 8), VERMELHO if i < _passaram else Color("3a3f6a"))
