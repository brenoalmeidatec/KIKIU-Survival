extends Node2D
## Cena de teste dos chefes da v3 (isolada, fora da v2). Teclas 1 Vornak, 2 Nythrax, 3 Maltherion; D = 100 de dano; R = reinicia.
## Aviso no chão antes de cada golpe (círculo ou faixa), raízes no impacto do Vornak e partículas na absorção.
## Não entra no fluxo da v2.

const Vornak := preload("res://v3/chefes/vornak.gd")
const Nythrax := preload("res://v3/chefes/nythrax.gd")
const Maltherion := preload("res://v3/chefes/maltherion.gd")
const Visual := preload("res://v3/chefes/chefe_visual.gd")

var origem := Vector2(320, 260)
var tipo := "vornak"
var chefe
var visual
var aviso_ativo := false
var aviso_raio := 0.0
var golpes := 0
var ultimo_golpe := ""
var efeitos: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	origem = get_viewport_rect().size * Vector2(0.5, 0.72)
	_rng.randomize()
	## --chefe=nythrax na linha de comando abre o lobo (para testes e capturas)
	var escolhido := "vornak"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chefe="):
			escolhido = a.trim_prefix("--chefe=")
	_novo_chefe(escolhido)


func _novo_chefe(novo_tipo: String) -> void:
	tipo = novo_tipo
	if visual != null:
		visual.queue_free()
	if tipo == "vornak":
		chefe = Vornak.new()
		chefe.iniciar(Vornak.CONFIG)
	elif tipo == "nythrax":
		chefe = Nythrax.new()
		chefe.iniciar(Nythrax.CONFIG)
	else:
		chefe = Maltherion.new()
		chefe.iniciar(Maltherion.CONFIG)
	visual = Visual.new()
	visual.prefixo = tipo
	visual.position = origem
	add_child(visual)
	visual.ligar(chefe)
	chefe.aviso_iniciou.connect(_on_aviso)
	chefe.golpe.connect(_on_golpe)
	aviso_ativo = false
	golpes = 0
	efeitos.clear()


func _on_aviso(_nome: String, raio: float) -> void:
	aviso_ativo = true
	aviso_raio = raio * 40.0


func _on_golpe(nome: String, raio: float, _dano: float) -> void:
	aviso_ativo = false
	golpes += 1
	ultimo_golpe = nome
	if nome == "absorcao_de_vida":
		for i in 14:
			var a := _rng.randf_range(0.0, TAU)
			var d := _rng.randf_range(90.0, 150.0)
			efeitos.append({"tipo": "particula", "t": 0.0, "dur": 0.9, "de": origem + Vector2(cos(a), sin(a)) * d * 0.6 + Vector2(0, -20)})
	elif tipo == "vornak":
		for i in 6:
			var a := _rng.randf_range(0.0, TAU)
			var d := _rng.randf_range(0.0, raio * 40.0)
			efeitos.append({"tipo": "raiz", "t": 0.0, "dur": 0.7, "base": origem + Vector2(cos(a), sin(a)) * d, "dir": Vector2(cos(a), sin(a))})


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D:
			chefe.receber_dano(100.0)
		elif event.keycode == KEY_R:
			_novo_chefe(tipo)
		elif event.keycode == KEY_1:
			_novo_chefe("vornak")
		elif event.keycode == KEY_2:
			_novo_chefe("nythrax")
		elif event.keycode == KEY_3:
			_novo_chefe("maltherion")


func _process(delta: float) -> void:
	chefe.avancar(delta)
	visual.olhar_para(Vector2(0.6, 0.8))
	for e in efeitos:
		e.t += delta
	efeitos = efeitos.filter(func(e): return e.t < e.dur)
	queue_redraw()


func _draw() -> void:
	if aviso_ativo:
		var pulso := 0.18 + 0.1 * sin(Time.get_ticks_msec() / 90.0)
		draw_circle(origem, aviso_raio, Color(0.4, 1.0, 0.2, pulso))
		draw_arc(origem, aviso_raio, 0.0, TAU, 48, Color(0.4, 1.0, 0.2, 0.9), 2.0)
	for e in efeitos:
		var k: float = e.t / e.dur
		if e.tipo == "raiz":
			var altura := 26.0 * sin(k * PI)
			var ponta: Vector2 = e.base + e.dir * 18.0 + Vector2(0, -altura)
			draw_line(e.base, ponta, Color(0.25, 0.2, 0.1), 4.0)
			draw_line(e.base, ponta, Color(0.45, 0.9, 0.25, 0.8), 1.0)
		else:
			var p: Vector2 = e.de.lerp(origem + Vector2(0, -60), k)
			draw_circle(p, 3.0 * (1.0 - k * 0.5), Color(0.55, 1.0, 0.3, 1.0 - k * 0.6))
	var nome: String = {"vornak": "Vornak", "nythrax": "Nythrax", "maltherion": "Maltherion"}[tipo]
	var linhas := [
		"%s: %s, fase %d" % [nome, chefe.estado, chefe.fase],
		"vida %d / %d" % [int(chefe.vida), int(chefe.vida_max)],
		"golpes: %d" % golpes,
		"1 V  2 N  3 M  D dano  R reinicia",
	]
	for i in linhas.size():
		draw_string(ThemeDB.fallback_font, Vector2(20, 36 + i * 26), linhas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.95, 0.85))
