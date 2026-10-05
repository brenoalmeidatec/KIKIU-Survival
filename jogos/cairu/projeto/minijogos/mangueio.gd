extends "res://minijogos/base.gd"
## Mangueio: ajude o Beto a sair de fininho pro banheiro (conferir a aposta).
## Segure a seta direita pra andar. Quando o coordenador virar, PARE.

var _andado := 0.0
var _dist := 300.0
var _estado_coord := "costas"   # costas, virando, olhando
var _t := 0.0
var _vidas := 2
var _pego := 0.0


func _init() -> void:
	musica = "minijogo_tenso"
	titulo = "Manguear o trabalho!"
	instrucoes = "O Beto quer ir pro banheiro conferir a aposta sem o coordenador ver.\nSegure a seta direita pra andar.\nQuando o coordenador começar a virar, PARE."


func _comecar() -> void:
	_andado = 0.0
	_dist = 260.0 + dificuldade * 60.0
	_estado_coord = "costas"
	_t = randf_range(1.2, 2.5)
	_vidas = 2
	_pego = 0.0


func _process(delta: float) -> void:
	if estado != "jogando":
		return
	_pego = max(_pego - delta, 0.0)
	_t -= delta
	if _t <= 0.0:
		match _estado_coord:
			"costas":
				_estado_coord = "virando"
				_t = 0.75 - dificuldade * 0.12
				Jogo.som("cursor")
			"virando":
				_estado_coord = "olhando"
				_t = randf_range(0.9, 1.8)
			"olhando":
				_estado_coord = "costas"
				_t = randf_range(0.8, 2.6) / (0.8 + dificuldade * 0.2)
	var andando := Input.is_action_pressed("direita") and _pego <= 0.0
	if andando:
		_andado += 70.0 * delta
		if _estado_coord == "olhando":
			_vidas -= 1
			_pego = 1.0
			_andado = max(_andado - 40.0, 0.0)
			Jogo.som("erro")
			if _vidas <= 0:
				perder("\"Beto! Já terminou aquele relatório?\" Não terminou. Nem começou.")
				return
	if _andado >= _dist:
		vencer()
		return
	area.queue_redraw()


func _desenhar(a: Control) -> void:
	# sala
	a.draw_rect(Rect2(0, 0, 440, 196), Color("c9c3d8"))
	a.draw_rect(Rect2(0, 0, 440, 60), Color("8f9ad0"))
	a.draw_rect(Rect2(400, 70, 30, 90), Color("7a4a2a"))
	texto(a, Vector2(415, 66), "WC", AZUL, 8, true)
	barra(a, Rect2(120, 8, 200, 6), _andado / _dist, VERDE)
	for i in 2:
		a.draw_rect(Rect2(420 - i * 12, 8, 8, 8), VERMELHO if i < _vidas else Color("3a3f6a"))
	# coordenador (em cima, no meio)
	var cx := 230.0
	var cor_coord := Color("2b1d14")
	a.draw_rect(Rect2(cx - 10, 70, 20, 30), Color("4a5078"))
	a.draw_rect(Rect2(cx - 7, 56, 14, 14), Color("c8875a"))
	match _estado_coord:
		"costas":
			a.draw_rect(Rect2(cx - 7, 56, 14, 8), cor_coord)
			texto(a, Vector2(cx, 48), "...", AZUL, 8, true)
		"virando":
			a.draw_rect(Rect2(cx - 7, 56, 14, 5), cor_coord)
			a.draw_rect(Rect2(cx + 2, 62, 2, 2), AZUL)
			texto(a, Vector2(cx, 48), "hm?", AMARELO, 8, true)
		"olhando":
			a.draw_rect(Rect2(cx - 7, 56, 14, 4), cor_coord)
			a.draw_rect(Rect2(cx - 4, 62, 2, 2), AZUL)
			a.draw_rect(Rect2(cx + 2, 62, 2, 2), AZUL)
			texto(a, Vector2(cx, 48), "!!!", VERMELHO, 8, true)
			a.draw_colored_polygon(PackedVector2Array([Vector2(cx, 80), Vector2(cx - 140, 196), Vector2(cx + 140, 196)]), Color(1, 0.3, 0.3, 0.18))
	texto(a, Vector2(cx, 112), "coordenador", AZUL, 8, true)
	# Beto
	var bx := 20.0 + (_andado / _dist) * 370.0
	if _pego <= 0.0 or int(_pego * 12) % 2 == 0:
		a.draw_rect(Rect2(bx - 8, 140, 16, 26), Color("2a5be8"))
		a.draw_rect(Rect2(bx - 6, 128, 12, 12), Color("8a5a3a"))
		a.draw_rect(Rect2(bx - 6, 166, 5, 8), AZUL)
		a.draw_rect(Rect2(bx + 1, 166, 5, 8), AZUL)
	texto(a, Vector2(bx, 122), "Beto", BRANCO, 8, true)
