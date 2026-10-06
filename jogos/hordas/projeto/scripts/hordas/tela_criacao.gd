extends CanvasLayer
## Criação de herói (#72, marco 1): raça e classe. Nome, pontos e aparência chegam no marco 2.
## Cima/baixo escolhem a linha (raça ou classe), esquerda/direita trocam, Enter cria e segue pro Calor, Esc volta.
## O mouse também serve: as setas trocam e o botão cria. Mostra o que a raça e a classe dão e tiram, a arma inicial,
## o especial (tecla E) e a ficha do herói montado.
## Uso: var t := TelaCriacao.new(); add_child(t); t.fechou.connect(func(ok, id): ...)

signal fechou(confirmou: bool, id: String)

const Criacao := preload("res://scripts/hordas/criacao.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
const W := 640.0
const H := 360.0
const PAINEL_Y := 148.0
const PAINEL_H := 150.0

var raca := 0
var classe := 0
var _linha := 0        # 0 = raça, 1 = classe
var _quadro := 0
var _t := 0.0
var _tela := Control.new()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_quadro = Engine.get_process_frames()   # a tecla que abriu a tela não conta aqui
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


func id() -> String:
	return Criacao.id_de(Criacao.lista_racas()[raca], Criacao.lista_classes()[classe])


func _process(dt: float) -> void:
	_t += dt
	_tela.queue_redraw()
	if Engine.get_process_frames() == _quadro or Criacao.lista_racas().is_empty() or Criacao.lista_classes().is_empty():
		return
	if Input.is_action_just_pressed("cima") or Input.is_action_just_pressed("baixo"):
		_linha = 1 - _linha
		Som.ui("cursor")
	elif Input.is_action_just_pressed("esquerda"):
		_trocar(_linha, -1)
	elif Input.is_action_just_pressed("direita"):
		_trocar(_linha, 1)
	elif Input.is_action_just_pressed("confirmar"):
		_criar()
	elif Input.is_action_just_pressed("voltar"):
		Som.ui("voltar")
		fechou.emit(false, "")
		queue_free()


func _input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var mp := _tela.get_local_mouse_position()
	for linha in 2:
		var x0 := 24.0 if linha == 0 else 336.0
		if Rect2(x0, PAINEL_Y + 18, 30, 22).has_point(mp):
			_linha = linha
			_trocar(linha, -1)
		elif Rect2(x0 + 250, PAINEL_Y + 18, 30, 22).has_point(mp):
			_linha = linha
			_trocar(linha, 1)
	if _botao().has_point(mp):
		_criar()


func _trocar(linha: int, passo: int) -> void:
	if linha == 0:
		var n := Criacao.lista_racas().size()
		raca = (raca + passo + n) % n
	else:
		var n := Criacao.lista_classes().size()
		classe = (classe + passo + n) % n
	Som.ui("cursor")


func _criar() -> void:
	Som.ui("confirmar")
	var i := id()
	Criacao.registrar(i)
	Criacao.salvar(i)
	fechou.emit(true, i)
	queue_free()


func _botao() -> Rect2:
	return Rect2(W / 2 - 70, 320, 140, 16)


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := W, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	_tela.draw_string(Dados.fonte, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, 0.8))
	_tela.draw_string(Dados.fonte, p, s, alinhar, larg, tam, cor)


func _desenhar() -> void:
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.04, 0.07, 0.99))
	_txt(Vector2(0, 26), "Criar herói", 16, Color(1, 0.85, 0.45))
	_txt(Vector2(0, 42), "Escolha a raça e a classe. Atenção: se ele morrer, morre de vez.", 8, Color(1, 0.6, 0.5))
	if Criacao.lista_racas().is_empty() or Criacao.lista_classes().is_empty():
		return
	var rid := str(Criacao.lista_racas()[raca])
	var cid := str(Criacao.lista_classes()[classe])
	var r: Dictionary = Criacao.racas().get(rid, {})
	var c: Dictionary = Criacao.classes().get(cid, {})
	var heroi := Criacao.montar(rid, cid)
	var rosto := Dados.tex_personagem(str(heroi.sprite), "rosto")
	if rosto:
		var tom: Array = heroi.tom
		_tela.draw_texture_rect_region(rosto, Rect2(W / 2 - 30, 52, 60, 60), Rect2(0, 0, 52, 52), Color(tom[0], tom[1], tom[2]))
	_txt(Vector2(0, 132), str(heroi.nome), 16, Color.WHITE)
	_painel(Rect2(24, PAINEL_Y, 280, PAINEL_H), "RAÇA", r, _linha == 0)
	_painel(Rect2(336, PAINEL_Y, 280, PAINEL_H), "CLASSE", c, _linha == 1)
	var y := PAINEL_Y + 88
	for linha in Criacao.descrever(r.get("bonus", {})) + Criacao.descrever(r.get("fraquezas", {})):
		_txt(Vector2(36, y), str(linha[0]), 8, Color(0.55, 0.95, 0.55) if linha[1] else Color(1, 0.5, 0.45), 260, HORIZONTAL_ALIGNMENT_LEFT)
		y += 12
	var arma := Dados.item(str(heroi.arma))
	var ic := Dados.icone(str(arma.get("icone", "")))
	if ic:
		_tela.draw_texture_rect(ic, Rect2(348, PAINEL_Y + 76, 16, 16), false)
	_txt(Vector2(370, PAINEL_Y + 88), "Começa com: " + str(arma.get("nome", heroi.arma)), 8, Color(1, 0.9, 0.5), 240, HORIZONTAL_ALIGNMENT_LEFT)
	var esp: Dictionary = Dados.json("especiais").get(str(heroi.especial), {})
	if not esp.is_empty():
		_txt(Vector2(348, PAINEL_Y + 102), "Especial (E): " + str(esp.get("nome", "")), 8, Color(0.6, 0.85, 1), 260, HORIZONTAL_ALIGNMENT_LEFT)
	y = PAINEL_Y + 116
	for linha in Criacao.descrever(c.get("bonus", {})):
		_txt(Vector2(348, y), str(linha[0]), 8, Color(0.55, 0.95, 0.55) if linha[1] else Color(1, 0.5, 0.45), 260, HORIZONTAL_ALIGNMENT_LEFT)
		y += 12
	var s := Construcao.stats(heroi, {}, {})
	_txt(Vector2(0, 312), "Vida %d   Dano %d%%   Velocidade %d%%   Área %d%%   Crítico %d%%" % [roundi(s.vida_max), roundi(s.dano * 100.0),
		roundi(s.velocidade * 100.0), roundi(s.area * 100.0), roundi(s.critico * 100.0)], 8, Color(0.82, 0.85, 0.95))
	var b := _botao()
	var pulsa := 0.5 + 0.5 * sin(_t * 4.0)
	_tela.draw_rect(b, Color(0.35, 0.25, 0.08).lerp(Color(0.5, 0.36, 0.1), pulsa))
	_tela.draw_rect(b, Color(1, 0.8, 0.35), false, 1.0)
	_txt(Vector2(b.position.x, b.position.y + 12), "Criar e jogar", 8, Color(1, 0.92, 0.7), b.size.x)
	_txt(Vector2(0, 350), "Cima/baixo: linha   Esq/dir: trocar   Enter: criar   Esc: voltar", 8, Color(0.55, 0.55, 0.62))


func _painel(q: Rect2, titulo: String, d: Dictionary, ativo: bool) -> void:
	_tela.draw_rect(q, Color(0.09, 0.09, 0.15))
	_tela.draw_rect(q, Color(1, 0.85, 0.3) if ativo else Color(0.3, 0.33, 0.48), false, 2.0 if ativo else 1.0)
	_txt(q.position + Vector2(0, 12), titulo, 8, Color(0.6, 0.65, 0.8), q.size.x)
	var seta := Color(1, 0.85, 0.3) if ativo else Color(0.45, 0.47, 0.6)
	_txt(q.position + Vector2(8, 34), "<", 16, seta, 30, HORIZONTAL_ALIGNMENT_LEFT)
	_txt(q.position + Vector2(q.size.x - 26, 34), ">", 16, seta, 30, HORIZONTAL_ALIGNMENT_LEFT)
	_txt(q.position + Vector2(30, 32), str(d.get("nome", "")), 8, Color.WHITE, q.size.x - 60)
	_tela.draw_multiline_string(Dados.fonte, q.position + Vector2(12, 52), str(d.get("descricao", "")), HORIZONTAL_ALIGNMENT_LEFT, q.size.x - 24, 8, 3,
		Color(0.75, 0.78, 0.85))
