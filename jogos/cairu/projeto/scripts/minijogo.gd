extends CanvasLayer
## Porta de entrada dos minijogos. Uma cena chama {"minijogo": "nome"} e espera
## o sinal "terminou" com o resultado (true = ganhou).
##
## Para criar um minijogo de verdade: veja minijogos/base.gd (explica o passo a passo)
## e registre o nome aqui em MINIJOGOS.
## Enquanto um nome não estiver registrado, aparece esta tela provisória para
## escolher o resultado na mão (dá pra testar as cenas antes do minijogo existir).

signal terminou(ganhou: bool)

const MINIJOGOS := {
	"consertar_pc": "res://minijogos/consertar_pc.gd",
	"memoria": "res://minijogos/memoria.gd",
	"reflexo": "res://minijogos/reflexo.gd",
	"digitar": "res://minijogos/digitar.gd",
	"esquiva": "res://minijogos/esquiva.gd",
	"cabos": "res://minijogos/cabos.gd",
	"impressora": "res://minijogos/impressora.gd",
	"abas": "res://minijogos/abas.gd",
	"qw": "res://minijogos/qw.gd",
	"mangueio": "res://minijogos/mangueio.gd",
	"virus": "res://minijogos/virus.gd",
	"violao": "res://minijogos/violao.gd",
	"escada": "res://minijogos/escada.gd",
}

var nome := ""
var params: Dictionary = {}
var _sel := 0
var _opcoes: Array[Label] = []


static func criar(nome_minijogo: String, params: Dictionary = {}) -> CanvasLayer:
	var caminho: String = MINIJOGOS.get(nome_minijogo, "")
	var m: CanvasLayer
	if caminho != "" and ResourceLoader.exists(caminho):
		m = load(caminho).new()
	else:
		m = load("res://scripts/minijogo.gd").new()
	m.set("nome", nome_minijogo)
	m.set("params", params)
	return m


func _ready() -> void:
	layer = 20
	add_to_group("minijogo")
	var fundo := ColorRect.new()
	fundo.color = Color(0.067, 0.082, 0.173, 0.96)
	fundo.size = Vector2(480, 270)
	add_child(fundo)
	var t := Label.new()
	t.text = "MINIJOGO: " + nome
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Color("ffd34e"))
	t.position = Vector2(24, 60)
	add_child(t)
	var s := Label.new()
	s.text = "Esse minijogo ainda não existe.\nEscolha o resultado pra continuar a cena:"
	s.add_theme_constant_override("line_spacing", 6)
	s.position = Vector2(24, 100)
	add_child(s)
	for i in 2:
		var l := Label.new()
		l.position = Vector2(48, 150 + i * 18)
		add_child(l)
		_opcoes.append(l)
	_marcar()


func _marcar() -> void:
	var textos := ["Ganhou", "Perdeu"]
	for i in 2:
		_opcoes[i].text = ("> " if i == _sel else "  ") + textos[i]
		_opcoes[i].add_theme_color_override("font_color", Color("ffd34e") if i == _sel else Color("f3efe2"))


func _unhandled_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("cima") or event.is_action_pressed("baixo"):
		_sel = 1 - _sel
		_marcar()
	elif event.is_action_pressed("interagir"):
		terminou.emit(_sel == 0)
		queue_free()
