extends "res://minijogos/base.gd"
## Abas: o João tá chegando e o PC do Lucas tá cheio de aba suspeita.
## Cada aba aparece num canto da tela: aperte a seta daquele canto pra fechar.
## Aba suspeita que fica aberta tempo demais = o João vê. Fechar a PLANILHA também conta.

const SUSPEITAS := ["aba anônima (7)", "pesquisa: anatomia", "video (3).mp4", "site_seguro.exe", "???", "fotos_praia.zip"]
const SERIAS := ["PLANILHA", "chamados", "e-mail coord."]
const LUGAR := {"cima": Vector2(220, 52), "baixo": Vector2(220, 142), "esquerda": Vector2(110, 97), "direita": Vector2(330, 97)}

var _abas := {}     # canto -> {nome, seria, vida}
var _tempo := 0.0
var _duracao := 20.0
var _prox := 0.0
var _flagras := 0
var _tremor := 0.0


func _init() -> void:
	musica = "minijogo_tenso"
	titulo = "Fecha as abas!"
	instrucoes = "O João tá vindo e o PC do Lucas tá cheio de aba suspeita.\nCada aba abre num canto: aperte a seta daquele canto pra fechar.\nNão feche a PLANILHA! Três flagras e já era."


func _comecar() -> void:
	_abas.clear()
	_tempo = 0.0
	_duracao = 16.0 + dificuldade * 4.0
	_prox = 0.5
	_flagras = 0


func _flagra(motivo: String) -> void:
	_flagras += 1
	_tremor = 0.35
	Jogo.som("erro")
	if _flagras >= 3:
		perder(motivo)


func _process(delta: float) -> void:
	if estado != "jogando":
		return
	_tempo += delta
	_tremor = max(_tremor - delta, 0.0)
	if _tempo >= _duracao:
		vencer()
		return
	_prox -= delta
	if _prox <= 0.0:
		_prox = randf_range(0.5, 1.1) / (0.7 + dificuldade * 0.3)
		var livres := LUGAR.keys().filter(func(k): return not _abas.has(k))
		if not livres.is_empty():
			var seria := randf() < 0.25
			_abas[livres.pick_random()] = {"nome": (SERIAS if seria else SUSPEITAS).pick_random(), "seria": seria,
				"vida": 2.6 - dificuldade * 0.4}
	for k in _abas.keys():
		_abas[k].vida -= delta
		if _abas[k].vida <= 0.0:
			var seria: bool = _abas[k].seria
			_abas.erase(k)
			if not seria:
				_flagra("O João viu a aba. O Lucas disse que era \"pesquisa\". O João não acreditou.")
				if estado != "jogando":
					return
	area.queue_redraw()


func _tecla(event: InputEvent) -> void:
	var a := acao_de(event)
	if not LUGAR.has(a):
		return
	if not _abas.has(a):
		return
	var seria: bool = _abas[a].seria
	_abas.erase(a)
	if seria:
		_flagra("Fechou a planilha sem salvar. O João ficou mais bravo com isso do que com as abas.")
	else:
		Jogo.som("acerto")


func _desenhar(a: Control) -> void:
	var tx := randf_range(-3, 3) if _tremor > 0.0 else 0.0
	# monitor
	caixa(a, Rect2(40 + tx, 22, 360, 160), Color("15183a"), Color("8a90b8"))
	a.draw_rect(Rect2(40 + tx, 22, 360, 10), Color("2a2fa8"))
	# João chegando
	barra(a, Rect2(120, 6, 200, 6), 1.0 - _tempo / _duracao, VERDE)
	texto(a, Vector2(330, 13), "João chegando", CINZA)
	for i in 3:
		a.draw_rect(Rect2(10 + i * 12, 6, 8, 8), VERMELHO if i < _flagras else Color("3a3f6a"))
	for k in _abas:
		var ab: Dictionary = _abas[k]
		var c: Vector2 = LUGAR[k] + Vector2(tx, 0)
		var seria: bool = ab.seria
		var r := Rect2(c - Vector2(62, 18), Vector2(124, 36))
		caixa(a, r, Color("f3efe2") if seria else Color("ffd8e0"), Color("0d1030"))
		a.draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), Color("2a5be8") if seria else Color("e0505a"))
		texto(a, c + Vector2(0, 6), str(ab.nome), AZUL, 8, true)
		tecla_desenho(a, r.position + Vector2(r.size.x - 4, 4), k, 14.0)
