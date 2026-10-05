extends "res://minijogos/base.gd"
## Esquiva: atravesse o corredor desviando do que vem na sua direção (setas cima/baixo).
## Na cena: "coisas": ["CAFÉ", "PAPEL", ...] troca o que aparece; "distancia" o tamanho.

const COISAS := ["CAFÉ", "PAPEL", "CAIXA", "CARRINHO", "ALUNO", "PROF"]
const FAIXAS := [52.0, 92.0, 132.0, 172.0]

var _faixa := 1
var _y := 92.0
var _andado := 0.0
var _distancia := 1000.0
var _vel := 120.0
var _obst: Array = []   # [x, faixa, nome]
var _prox := 0.0
var _vidas := 3
var _invul := 0.0


func _init() -> void:
	musica = "minijogo_tenso"
	titulo = "Corredor lotado!"
	instrucoes = "Atravesse o corredor até o fim.\nSetas cima e baixo trocam de faixa.\nBateu em alguma coisa, perde uma vida."


func _comecar() -> void:
	_faixa = 1
	_y = FAIXAS[1]
	_andado = 0.0
	_distancia = float(params.get("distancia", 900 + dificuldade * 300))
	_vel = 110.0 + dificuldade * 30.0
	_obst.clear()
	_prox = 0.6
	_vidas = 3
	_invul = 0.0


func _process(delta: float) -> void:
	if estado != "jogando":
		return
	_andado += _vel * delta
	_y = lerp(_y, FAIXAS[_faixa], min(1.0, delta * 14.0))
	_invul = max(_invul - delta, 0.0)
	_prox -= delta
	if _prox <= 0.0 and _andado < _distancia - 200:
		_prox = randf_range(0.45, 0.9) / (0.8 + dificuldade * 0.2)
		var livre := randi() % 4
		for k in 4:
			if k != livre and randf() < 0.28 + dificuldade * 0.08:
				_obst.append([460.0, k, params.get("coisas", COISAS).pick_random()])
	for o in _obst:
		o[0] -= _vel * delta
		if _invul <= 0.0 and o[1] == _faixa and abs(o[0] - 60.0) < 22.0:
			_vidas -= 1
			_invul = 1.0
			Jogo.som("erro")
			if _vidas <= 0:
				perder("Trombou em tudo. O corredor venceu.")
				return
	_obst = _obst.filter(func(o): return o[0] > -40.0)
	if _andado >= _distancia:
		vencer()
	area.queue_redraw()


func _tecla(event: InputEvent) -> void:
	if event.is_action_pressed("cima") and _faixa > 0:
		_faixa -= 1
		Jogo.som("cursor")
	elif event.is_action_pressed("baixo") and _faixa < 3:
		_faixa += 1
		Jogo.som("cursor")


func _desenhar(a: Control) -> void:
	# chão rolando
	a.draw_rect(Rect2(0, 30, 440, 166), Color("c9c3d8"))
	var off := fmod(_andado, 40.0)
	for i in 13:
		a.draw_rect(Rect2(i * 40 - off, 30, 1, 166), Color("b2abc6"))
	for f in FAIXAS:
		a.draw_rect(Rect2(0, f + 18, 440, 1), Color("b2abc6"))
	barra(a, Rect2(120, 10, 200, 6), _andado / _distancia, VERDE)
	texto(a, Vector2(10, 16), "corredor", CINZA)
	for i in _vidas:
		a.draw_rect(Rect2(420 - i * 12, 8, 8, 8), VERMELHO)
	for o in _obst:
		var y: float = FAIXAS[o[1]]
		caixa(a, Rect2(o[0] - 22, y - 12, 44, 24), Color("e0505a"), Color("1a2050"))
		texto(a, Vector2(o[0], y + 3), str(o[2]), BRANCO, 8, true)
	# jogador (pisca quando acabou de bater)
	if _invul <= 0.0 or int(_invul * 12) % 2 == 0:
		caixa(a, Rect2(48, _y - 14, 24, 28), Color("2a5be8"), Color("1a2050"))
		a.draw_rect(Rect2(54, _y - 24, 12, 10), Color("c8875a"))
		a.draw_rect(Rect2(54, _y - 26, 12, 4), Color("2b1d14"))
