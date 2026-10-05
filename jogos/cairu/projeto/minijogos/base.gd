extends CanvasLayer
## Base de todo minijogo: tela de instruções -> jogo -> tela de resultado.
##
## Pra criar um minijogo novo:
##   1. crie minijogos/meu_jogo.gd começando com  extends "res://minijogos/base.gd"
##   2. preencha titulo e instrucoes em _init(), e escreva _comecar(), _tecla(event)
##      e (se quiser) _process(delta) / _desenhar(area) — area é um Control 440x200.
##   3. quando acabar, chame vencer() ou perder("motivo")
##   4. registre o nome em scripts/minijogo.gd (MINIJOGOS)
##
## Na cena: {"minijogo": "meu_jogo", "guardar": "marca", "dificuldade": 1..3}
## (também aceita "titulo", "instrucoes" e "tentar_de_novo": false).

signal terminou(ganhou: bool)

const AMARELO := Color("ffd34e")
const BRANCO := Color("f3efe2")
const AZUL := Color("1a2050")
const CINZA := Color("8a90b8")
const VERDE := Color("6fd08c")
const VERMELHO := Color("e0505a")

var nome := ""
var params: Dictionary = {}
var dificuldade := 1
var titulo := "Minijogo"
var instrucoes := ""
var estado := "intro"   # intro, jogando, resultado
var musica := "minijogo"   # cada minijogo pode ter a sua (ou "musica" na cena)

var area := Control.new()      # onde o minijogo desenha (440x196)
var _titulo := Label.new()
var _texto := Label.new()
var _rodape := Label.new()
var _ganhou := false
var _escolha_res := 0
var _musica_antes := ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("minijogo")
	dificuldade = clampi(int(params.get("dificuldade", 1)), 1, 3)
	titulo = params.get("titulo", titulo)
	instrucoes = params.get("instrucoes", instrucoes)
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.04, 0.1, 0.92)
	fundo.size = Vector2(480, 270)
	add_child(fundo)
	var p := Panel.new()
	var e := Visual.painel()
	p.add_theme_stylebox_override("panel", e)
	Visual.borda_interna(p)
	p.position = Vector2(12, 10)
	p.size = Vector2(456, 250)
	add_child(p)
	_titulo.add_theme_color_override("font_color", AMARELO)
	_titulo.add_theme_font_size_override("font_size", 16)
	_titulo.position = Vector2(12, 10)
	p.add_child(_titulo)
	area.position = Vector2(8, 32)
	area.size = Vector2(440, 196)
	area.clip_contents = true
	area.draw.connect(func(): _desenhar(area))
	p.add_child(area)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_constant_override("line_spacing", 6)
	_texto.position = Vector2(16, 44)
	_texto.size = Vector2(424, 150)
	p.add_child(_texto)
	_rodape.add_theme_color_override("font_color", CINZA)
	_rodape.position = Vector2(12, 232)
	p.add_child(_rodape)
	_musica_antes = Jogo.musica_atual()
	Jogo.tocar_musica(params.get("musica", musica), 0.4)
	_mostrar_intro()


func _mostrar_intro() -> void:
	estado = "intro"
	_titulo.text = titulo
	_texto.visible = true
	_texto.text = instrucoes + "\n\n" + ["", "Dificuldade: fácil", "Dificuldade: média", "Dificuldade: difícil"][dificuldade]
	_rodape.text = Controles.tecla("interagir") + ": começar"
	area.visible = false


func _iniciar() -> void:
	estado = "jogando"
	_texto.visible = false
	area.visible = true
	_rodape.text = ""
	Jogo.som("confirmar")
	_comecar()
	area.queue_redraw()


func vencer() -> void:
	if estado != "jogando":
		return
	_ganhou = true
	_resultado("CONSEGUIU!", params.get("texto_vitoria", "Mandou bem."))
	Jogo.som("vitoria")


func perder(motivo := "") -> void:
	if estado != "jogando":
		return
	_ganhou = false
	_resultado("DEU RUIM...", motivo if motivo != "" else params.get("texto_derrota", "Não foi dessa vez."))
	Jogo.som("derrota")


func _resultado(manchete: String, texto: String) -> void:
	estado = "resultado"
	area.visible = false
	_texto.visible = true
	_titulo.text = manchete
	_titulo.add_theme_color_override("font_color", VERDE if _ganhou else VERMELHO)
	_texto.text = texto
	_escolha_res = 0
	_atualizar_rodape()


func _pode_tentar() -> bool:
	return not _ganhou and params.get("tentar_de_novo", true)


func _atualizar_rodape() -> void:
	if _pode_tentar():
		_rodape.text = ("> Tentar de novo   Continuar" if _escolha_res == 0 else "  Tentar de novo > Continuar")
		_rodape.add_theme_color_override("font_color", AMARELO)
	else:
		_rodape.text = Controles.tecla("interagir") + ": continuar"
		_rodape.add_theme_color_override("font_color", CINZA)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	match estado:
		"intro":
			if event.is_action_pressed("interagir"):
				_iniciar()
		"jogando":
			_tecla(event)
		"resultado":
			if _pode_tentar() and (event.is_action_pressed("esquerda") or event.is_action_pressed("direita")):
				_escolha_res = 1 - _escolha_res
				Jogo.som("cursor")
				_atualizar_rodape()
			elif event.is_action_pressed("interagir"):
				if _pode_tentar() and _escolha_res == 0:
					_titulo.add_theme_color_override("font_color", AMARELO)
					_titulo.text = titulo
					_rodape.add_theme_color_override("font_color", CINZA)
					_iniciar()
				else:
					Jogo.som("confirmar")
					Jogo.tocar_musica(_musica_antes, 0.4)
					terminou.emit(_ganhou)
					queue_free()


# ---------- pra sobrescrever ----------

func _comecar() -> void:
	pass


func _tecla(_event: InputEvent) -> void:
	pass


func _desenhar(_a: Control) -> void:
	pass


# ---------- ajudas de desenho ----------

func texto(a: Control, pos: Vector2, s: String, cor := BRANCO, tamanho := 8, centro := false) -> void:
	var f: Font = ThemeDB.get_default_theme().default_font
	if centro:
		pos.x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x / 2
	a.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)


func caixa(a: Control, r: Rect2, cor: Color, borda := Color.TRANSPARENT) -> void:
	if borda.a > 0:
		a.draw_rect(r.grow(1), borda)
	a.draw_rect(r, cor)


## Barra de tempo (0..1).
func barra(a: Control, r: Rect2, frac: float, cor := AMARELO) -> void:
	a.draw_rect(r, Color("0d1030"))
	a.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y)), cor if frac > 0.3 else VERMELHO)


## Tecla desenhada: "cima", "baixo", "esquerda", "direita" ou um texto (ex.: "E").
func tecla_desenho(a: Control, centro: Vector2, qual: String, tam := 28.0, cor := BRANCO, fundo := Color("2a2fa8")) -> void:
	var r := Rect2(centro - Vector2(tam, tam) / 2, Vector2(tam, tam))
	a.draw_rect(r.grow(2), Color("0d1030"))
	a.draw_rect(r, fundo)
	a.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), fundo.darkened(0.4))
	var k := tam * 0.28
	var pts: PackedVector2Array
	match qual:
		"cima":
			pts = [centro + Vector2(0, -k), centro + Vector2(k, k * 0.7), centro + Vector2(-k, k * 0.7)]
		"baixo":
			pts = [centro + Vector2(0, k), centro + Vector2(k, -k * 0.7), centro + Vector2(-k, -k * 0.7)]
		"esquerda":
			pts = [centro + Vector2(-k, 0), centro + Vector2(k * 0.7, -k), centro + Vector2(k * 0.7, k)]
		"direita":
			pts = [centro + Vector2(k, 0), centro + Vector2(-k * 0.7, -k), centro + Vector2(-k * 0.7, k)]
	if pts.size() == 3:
		a.draw_colored_polygon(pts, cor)
	else:
		texto(a, centro + Vector2(0, tam * 0.2), qual, cor, 16 if tam >= 28 else 8, true)


const ACOES := ["cima", "baixo", "esquerda", "direita", "interagir"]


## Qual das teclas do jogo foi apertada ("" se nenhuma).
func acao_de(event: InputEvent) -> String:
	for a in ACOES:
		if event.is_action_pressed(a):
			return a
	return ""
