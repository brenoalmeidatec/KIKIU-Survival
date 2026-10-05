extends "res://minijogos/base.gd"
## Impressora: o papel travou. Aperte E quando o marcador passar na faixa verde.
## Cada acerto puxa um pouco o papel; errou, a impressora engasga (3 engasgos = perdeu).

var _pos := 0.0
var _dir := 1.0
var _vel := 0.8
var _faixa := 0.25
var _centro := 0.5
var _acertos := 0
var _meta := 4
var _engasgos := 0
var _tremor := 0.0
var _flash := 0.0


func _init() -> void:
	titulo = "Destrava a impressora!"
	instrucoes = "A impressora do segundo andar travou de novo (e o Fábio é mais da estratégia).\nAperte E quando o marcador passar na faixa verde.\nErrou três vezes, ela come o papel de vez."


func _comecar() -> void:
	_pos = 0.0
	_dir = 1.0
	_vel = 0.7 + dificuldade * 0.25
	_faixa = 0.28 - dificuldade * 0.04
	_meta = 3 + dificuldade
	_acertos = 0
	_engasgos = 0
	_nova_faixa()


func _nova_faixa() -> void:
	_centro = randf_range(_faixa, 1.0 - _faixa)


func _process(delta: float) -> void:
	if estado != "jogando":
		return
	_pos += _dir * _vel * delta
	if _pos > 1.0:
		_pos = 1.0
		_dir = -1.0
	elif _pos < 0.0:
		_pos = 0.0
		_dir = 1.0
	_tremor = max(_tremor - delta, 0.0)
	_flash = max(_flash - delta, 0.0)
	area.queue_redraw()


func _tecla(event: InputEvent) -> void:
	if acao_de(event) != "interagir":
		return
	if abs(_pos - _centro) <= _faixa / 2.0:
		_acertos += 1
		_flash = 0.2
		Jogo.som("acerto")
		_vel += 0.12
		_faixa = max(_faixa * 0.88, 0.08)
		if _acertos >= _meta:
			vencer()
			return
		_nova_faixa()
	else:
		_engasgos += 1
		_tremor = 0.4
		Jogo.som("erro")
		if _engasgos >= 3:
			perder("Comeu o papel. E o boleto do aluno junto.")


func _desenhar(a: Control) -> void:
	var tx := randf_range(-3, 3) if _tremor > 0.0 else 0.0
	# impressora
	var r := Rect2(150 + tx, 30, 140, 70)
	caixa(a, r, Color("d8d4e6"), Color("0d1030"))
	a.draw_rect(Rect2(r.position.x + 10, r.position.y + 10, 120, 8), Color("8a90b8"))
	a.draw_rect(Rect2(r.position.x + 112, r.position.y + 50, 8, 6), VERDE if _flash > 0.0 else (VERMELHO if _engasgos > 0 else Color("4a5078")))
	# papel saindo
	var saiu := 6.0 + 50.0 * float(_acertos) / _meta
	a.draw_rect(Rect2(r.position.x + 30, r.position.y + 70, 80, saiu), Color("fffaf0"))
	for k in int(saiu / 8):
		a.draw_rect(Rect2(r.position.x + 38, r.position.y + 76 + k * 8, 50 + (k % 3) * 6, 2), Color("b2abc6"))
	# barra
	var b := Rect2(60, 168, 320, 14)
	a.draw_rect(b.grow(2), Color("0d1030"))
	a.draw_rect(b, Color("2b2f55"))
	a.draw_rect(Rect2(b.position.x + (_centro - _faixa / 2.0) * b.size.x, b.position.y, _faixa * b.size.x, b.size.y), VERDE)
	a.draw_rect(Rect2(b.position.x + _pos * b.size.x - 2, b.position.y - 5, 4, b.size.y + 10), AMARELO)
	texto(a, Vector2(220, 160), "%d / %d" % [_acertos, _meta], BRANCO, 8, true)
	for i in 3:
		a.draw_rect(Rect2(400 + i * 12, 8, 8, 8), VERMELHO if i < _engasgos else Color("3a3f6a"))
	texto(a, Vector2(330, 16), "engasgos", CINZA)
