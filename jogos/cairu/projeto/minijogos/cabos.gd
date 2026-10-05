extends "res://minijogos/base.gd"
## Cabos: religue cada cabo de rede na porta da mesma cor.
## Cima/baixo escolhe a porta, E liga. Porta errada tira 2 segundos.

const CORES := [Color("e0505a"), Color("4b9be8"), Color("6fd08c"), Color("ffd34e"), Color("c070e0"), Color("f0a050")]
const NOMES := ["VERMELHO", "AZUL", "VERDE", "AMARELO", "ROXO", "LARANJA"]

var _n := 4
var _portas: Array = []    # cor de cada porta (lado direito)
var _ligados: Array = []   # porta em que cada cabo foi ligado, ou -1
var _cabo := 0
var _sel := 0
var _tempo := 0.0
var _tempo_max := 25.0
var _tremor := 0.0


func _init() -> void:
	titulo = "Religa os cabos!"
	instrucoes = "O Lukako arrancou os cabos de rede do Núcleo pra fazer rapel.\nLigue cada cabo na porta da mesma cor.\nCima/baixo escolhe a porta, E liga. Porta errada tira tempo."


func _comecar() -> void:
	_n = 3 + dificuldade
	_portas = range(_n)
	_portas.shuffle()
	_ligados.clear()
	for i in _n:
		_ligados.append(-1)
	_cabo = 0
	_sel = 0
	_tempo_max = [0.0, 25.0, 22.0, 18.0][dificuldade]
	_tempo = _tempo_max


func _process(delta: float) -> void:
	if estado != "jogando":
		return
	_tempo -= delta
	_tremor = max(_tremor - delta, 0.0)
	if _tempo <= 0.0:
		perder("A internet continua caindo. O Lukako jura que não foi ele.")
		return
	area.queue_redraw()


func _y(i: int) -> float:
	return 44.0 + (i + 0.5) * (140.0 / _n)


func _tecla(event: InputEvent) -> void:
	match acao_de(event):
		"cima":
			_sel = (_sel - 1 + _n) % _n
			Jogo.som("cursor")
		"baixo":
			_sel = (_sel + 1) % _n
			Jogo.som("cursor")
		"interagir":
			if _portas[_sel] == _cabo and not (_sel in _ligados):
				_ligados[_cabo] = _sel
				Jogo.som("acerto")
				_cabo += 1
				if _cabo >= _n:
					vencer()
			else:
				_tempo -= 2.0
				_tremor = 0.3
				Jogo.som("erro")


func _desenhar(a: Control) -> void:
	barra(a, Rect2(120, 8, 200, 6), _tempo / _tempo_max)
	if _cabo < _n:
		texto(a, Vector2(220, 30), "ligue o cabo " + NOMES[_cabo], CORES[_cabo], 8, true)
	var tx := randf_range(-2, 2) if _tremor > 0.0 else 0.0
	# switch do lado direito
	caixa(a, Rect2(340 + tx, 36, 70, 156), Color("2b2f55"), Color("0d1030"))
	for j in _n:
		var y := _y(j)
		var livre := not (j in _ligados)
		caixa(a, Rect2(352 + tx, y - 8, 22, 16), Color("15183a"), CORES[_portas[j]] if livre else Color("3a3f6a"))
		a.draw_rect(Rect2(380 + tx, y - 3, 6, 6), CORES[_portas[j]] if livre else VERDE)
		if j == _sel and _cabo < _n:
			a.draw_rect(Rect2(346 + tx, y - 11, 34, 22), AMARELO, false, 2.0)
	# cabos do lado esquerdo
	for i in _n:
		var y := _y(i)
		caixa(a, Rect2(30, y - 5, 26, 10), CORES[i], Color("0d1030"))
		var fim: Vector2
		if _ligados[i] >= 0:
			fim = Vector2(352 + tx, _y(_ligados[i]))
		elif i == _cabo:
			fim = Vector2(352 + tx, _y(_sel))
		else:
			fim = Vector2(90, y + 18)
		var pts := PackedVector2Array()
		for k in 13:
			var t := k / 12.0
			var p := Vector2(56, y).lerp(fim, t)
			p.y += sin(t * PI) * (14.0 if _ligados[i] < 0 else 6.0)
			pts.append(p)
		var cor: Color = CORES[i]
		if i == _cabo and _ligados[i] < 0:
			cor.a = 0.55 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
		a.draw_polyline(pts, cor, 3.0)
