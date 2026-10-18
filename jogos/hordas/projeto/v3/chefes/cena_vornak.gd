extends Node2D
## Cena de teste do Vornak da v3 (isolada, fora da v2): mostra o chefe atacando com aviso no chão.
## Teclas: D = leva 100 de dano (fase 2 abaixo de 40%); R = reinicia. Não entra no fluxo da v2.

const Vornak := preload("res://v3/chefes/vornak.gd")
const Visual := preload("res://v3/chefes/vornak_visual.gd")
var origem := Vector2(320, 260)

var chefe
var visual
var aviso_ativo := false
var aviso_raio := 0.0
var aviso_nome := ""
var golpes := 0
var ultimo_golpe := ""


func _ready() -> void:
	origem = get_viewport_rect().size * Vector2(0.5, 0.72)
	_novo_chefe()


func _novo_chefe() -> void:
	if visual != null:
		visual.queue_free()
	chefe = Vornak.new()
	chefe.iniciar(Vornak.CONFIG)
	visual = Visual.new()
	visual.position = origem
	add_child(visual)
	visual.ligar(chefe)
	chefe.aviso_iniciou.connect(_on_aviso)
	chefe.golpe.connect(_on_golpe)
	aviso_ativo = false
	golpes = 0


func _on_aviso(nome: String, raio: float) -> void:
	aviso_ativo = true
	aviso_nome = nome
	aviso_raio = raio * 40.0


func _on_golpe(nome: String, _raio: float, _dano: float) -> void:
	aviso_ativo = false
	golpes += 1
	ultimo_golpe = nome


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D:
			chefe.receber_dano(100.0)
		elif event.keycode == KEY_R:
			_novo_chefe()


func _process(delta: float) -> void:
	chefe.avancar(delta)
	visual.olhar_para(Vector2(0.6, 0.8))
	queue_redraw()


func _draw() -> void:
	if aviso_ativo:
		draw_circle(origem, aviso_raio, Color(0.4, 1.0, 0.2, 0.28))
		draw_arc(origem, aviso_raio, 0.0, TAU, 48, Color(0.4, 1.0, 0.2, 0.9), 2.0)
	var linhas := [
		"Vornak: %s, fase %d" % [chefe.estado, chefe.fase],
		"vida %d / %d" % [int(chefe.vida), int(chefe.vida_max)],
		"golpes: %d" % golpes,
		"D = dano   R = reiniciar",
	]
	for i in linhas.size():
		draw_string(ThemeDB.fallback_font, Vector2(20, 36 + i * 26), linhas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.95, 0.85))
