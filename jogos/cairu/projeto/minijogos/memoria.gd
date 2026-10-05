extends "res://minijogos/base.gd"
## Memória: a sequência de setas acende; repita na mesma ordem. A cada acerto ela cresce.

const SETAS := ["cima", "direita", "baixo", "esquerda"]
const CORES := {"cima": Color("e0505a"), "direita": Color("4aa0e0"), "baixo": Color("6fd08c"), "esquerda": Color("f0b020")}
const POS := {"cima": Vector2(220, 40), "direita": Vector2(270, 98), "baixo": Vector2(220, 156), "esquerda": Vector2(170, 98)}

var _seq: Array = []
var _meta := 6
var _vez := 0
var _mostrando := false
var _aceso := ""
var _vidas := 2
var _msg := ""
var _token := 0


func _init() -> void:
	titulo = "Decore a sequência"
	instrucoes = "As setas vão piscar numa ordem.\nDepois repita a mesma ordem com as setas do teclado.\nA cada rodada a sequência fica maior."


func _comecar() -> void:
	_meta = 4 + dificuldade
	_vidas = 2 if dificuldade < 3 else 1
	_seq = []
	for i in 2:
		_seq.append(SETAS.pick_random())
	_rodada_nova()


func _rodada_nova() -> void:
	_seq.append(SETAS.pick_random())
	_vez = 0
	_mostrar()


func _mostrar() -> void:
	_token += 1
	var meu := _token
	_mostrando = true
	_msg = "Preste atenção..."
	area.queue_redraw()
	var passo: float = [0.6, 0.6, 0.45, 0.32][dificuldade]
	await get_tree().create_timer(0.7).timeout
	for s in _seq:
		if meu != _token or estado != "jogando":
			return
		_aceso = s
		Jogo.som("nota_" + s)
		area.queue_redraw()
		await get_tree().create_timer(passo).timeout
		_aceso = ""
		area.queue_redraw()
		await get_tree().create_timer(passo * 0.4).timeout
	if meu != _token:
		return
	_mostrando = false
	_msg = "Sua vez!"
	area.queue_redraw()


func _tecla(event: InputEvent) -> void:
	if _mostrando:
		return
	var a := acao_de(event)
	if not a in SETAS:
		return
	_piscar(a)
	if a == _seq[_vez]:
		Jogo.som("nota_" + a)
		_vez += 1
		if _vez >= _seq.size():
			if _seq.size() >= _meta:
				vencer()
				return
			Jogo.som("acerto")
			_msg = "Isso!"
			await get_tree().create_timer(0.5).timeout
			if estado == "jogando":
				_rodada_nova()
	else:
		Jogo.som("erro")
		_vidas -= 1
		if _vidas <= 0:
			perder("Esqueceu a sequência. Acontece com quem dorme na aula.")
			return
		_msg = "Errou! Olha de novo."
		_vez = 0
		await get_tree().create_timer(0.6).timeout
		if estado == "jogando":
			_mostrar()


func _piscar(s: String) -> void:
	_aceso = s
	area.queue_redraw()
	await get_tree().create_timer(0.18).timeout
	if _aceso == s:
		_aceso = ""
		area.queue_redraw()


func _desenhar(a: Control) -> void:
	for s in SETAS:
		var cor: Color = CORES[s]
		tecla_desenho(a, POS[s], s, 44.0, Color.WHITE if _aceso == s else cor.darkened(0.2), cor if _aceso == s else Color("20265e"))
	texto(a, Vector2(20, 24), _msg, AMARELO)
	texto(a, Vector2(20, 44), "Tamanho: %d/%d" % [_seq.size(), _meta], CINZA)
	if not _mostrando:
		texto(a, Vector2(20, 60), "%d de %d" % [_vez, _seq.size()], BRANCO)
	for i in _vidas:
		a.draw_rect(Rect2(20 + i * 12, 176, 8, 8), VERMELHO)
