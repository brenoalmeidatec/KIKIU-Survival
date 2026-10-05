extends "res://minijogos/base.gd"
## Digitar: aparece uma palavra; digite ela no teclado antes do tempo acabar.
## Na cena: "palavras": ["boleto", "matricula", ...] troca a lista.

const PALAVRAS := ["boleto", "matricula", "senha", "cafe", "impressora", "cairu", "planilha",
	"protocolo", "wifi", "coordenacao", "carimbo", "reuniao", "pendrive", "salvador", "projetor"]

var _fila: Array = []
var _palavra := ""
var _digitado := 0
var _tempo := 0.0
var _tempo_max := 20.0
var _erros := 0
var _tremor := 0.0


func _init() -> void:
	musica = "minijogo_retro"
	titulo = "Digita rápido!"
	instrucoes = "Vai aparecer uma palavra.\nDigite ela letra por letra no teclado antes do tempo acabar.\nLetra errada faz o tempo correr mais.\n(No controle: aperte A rápido, cada A é uma letra.)"


func _comecar() -> void:
	var lista: Array = params.get("palavras", PALAVRAS).duplicate()
	lista.shuffle()
	_fila = lista.slice(0, 3 + dificuldade * 2)
	_tempo_max = [0, 24.0, 20.0, 16.0][dificuldade]
	_tempo = _tempo_max
	_erros = 0
	_proxima()


func _proxima() -> void:
	if _fila.is_empty():
		vencer()
		return
	_palavra = str(_fila.pop_front())
	_digitado = 0


func _process(delta: float) -> void:
	if estado != "jogando":
		return
	_tempo -= delta
	_tremor = max(_tremor - delta, 0.0)
	if _tempo <= 0.0:
		perder("O tempo acabou. A fila do protocolo agradece.")
	area.queue_redraw()


func _tecla(event: InputEvent) -> void:
	var c := ""
	if event is InputEventJoypadButton and event.is_action_pressed("interagir"):
		c = _palavra.substr(_digitado, 1)   # no controle, cada A digita a próxima letra
	elif not (event is InputEventKey and event.pressed and not event.echo) or event.unicode == 0:
		return
	else:
		c = String.chr(event.unicode).to_lower()
	if c == _palavra.substr(_digitado, 1):
		_digitado += 1
		Jogo.som("blip", -6.0, 0.1)
		if _digitado >= _palavra.length():
			Jogo.som("acerto")
			_proxima()
	elif c.strip_edges() != "":
		_erros += 1
		_tempo -= 1.0
		_tremor = 0.25
		Jogo.som("erro")


func _desenhar(a: Control) -> void:
	texto(a, Vector2(10, 16), "faltam %d" % (_fila.size() + 1), CINZA)
	texto(a, Vector2(360, 16), "erros: %d" % _erros, VERMELHO if _erros > 0 else CINZA)
	var f: Font = ThemeDB.get_default_theme().default_font
	var tam := 16
	var largura := f.get_string_size(_palavra, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var x := 220.0 - largura / 2 + (randf_range(-2, 2) if _tremor > 0.0 else 0.0)
	var feito := _palavra.substr(0, _digitado)
	var resto := _palavra.substr(_digitado)
	texto(a, Vector2(x, 100), feito, VERDE, tam)
	var wf := f.get_string_size(feito, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	texto(a, Vector2(x + wf, 100), resto, BRANCO, tam)
	# cursor piscando embaixo da próxima letra
	if int(Time.get_ticks_msec() / 250.0) % 2 == 0 and resto != "":
		var wl := f.get_string_size(resto.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		a.draw_rect(Rect2(x + wf, 106, wl, 2), AMARELO)
	barra(a, Rect2(120, 150, 200, 8), _tempo / _tempo_max)
