extends RefCounted
## Cenografia do santuário. Texturas opcionais em cache; nenhum nó ou carregamento por quadro.
const Paleta := preload("res://v2/paleta.gd")
const PASTA := "res://assets/v2/santuario/"
const POSICOES := {"estatuas": Vector2(180, 330), "altar": Vector2(780, 300), "codice": Vector2(780, 425)}
var texturas := {}
var rotulos_fora := false  # o salão vivo (salao_vivo.gd) desenha os nomes numa camada sem luz; o cenário não os desenha


func _init() -> void:
	for nome in ["fundo", "estatuas", "altar", "codice", "portal_floresta", "portal_laboratorio", "portal_cidade", "portal_medio", "portal_fechado"]:
		var caminho: String = PASTA + str(nome) + ".png"
		if ResourceLoader.exists(caminho):
			texturas[nome] = load(caminho)


static func posicao(id: String, original: Vector2) -> Vector2:
	return POSICOES.get(id, original)


func textura(n: Node2D, nome: String, r: Rect2, cor := Color.WHITE) -> bool:
	if not texturas.has(nome):
		return false
	n.draw_texture_rect(texturas[nome], r, false, cor)
	return true


func fundo(n: Node2D) -> void:
	if textura(n, "fundo", Rect2(0, 0, 960, 540)):
		return
	# Pedra sóbria; a zona caminhável permanece livre de paredes e degraus.
	n.draw_rect(Rect2(0, 0, 960, 540), Color("#17191f"))
	n.draw_rect(Rect2(0, 0, 960, 180), Color("#25232c"))
	for linha in range(1, 6):
		var y := linha * 30.0
		n.draw_line(Vector2(0, y), Vector2(960, y), Color("#16151c"), 2)
		for col in range(0, 13):
			var x := col * 80.0 + (40.0 if linha % 2 else 0.0)
			n.draw_line(Vector2(x, y - 30), Vector2(x, y), Color("#16151c"), 2)
	for y in range(210, 540, 54):
		n.draw_line(Vector2(0, y), Vector2(960, y), Color("#20212a"))
		for x in range(0, 960, 108):
			var dx := 54 if (y / 54) % 2 else 0
			n.draw_line(Vector2(x + dx, y), Vector2(x + dx, y + 54), Color("#20212a"))
	for x in [8.0, 928.0]:
		n.draw_rect(Rect2(x, 0, 24, 510), Color("#34313a"))
		n.draw_rect(Rect2(x + 5, 0, 3, 510), Color("#48404a"))


func portal(n: Node2D, a: Dictionary, fechado: bool, cor: Color) -> void:
	var p: Vector2 = a.pos
	var imagem := "portal_fechado" if fechado else "portal_" + str(a.id)
	if not textura(n, imagem, Rect2(p.x - 56, p.y - 142, 112, 142)):
		n.draw_rect(Rect2(p.x - 39, p.y - 85, 78, 85), Color("#55515b"))
		n.draw_circle(p + Vector2(0, -85), 39, Color("#55515b"))
		n.draw_rect(Rect2(p.x - 28, p.y - 83, 56, 80), cor.darkened(0.65))
		n.draw_circle(p + Vector2(0, -83), 28, cor.darkened(0.65))
		if fechado:
			n.draw_rect(Rect2(p.x - 8, p.y - 57, 16, 15), Paleta.TEXTO_APAGADO)
			n.draw_arc(p + Vector2(0, -57), 6, PI, TAU, 12, Paleta.TEXTO_APAGADO, 3)
	if not rotulos_fora:
		rotulo_portal(n, a, fechado)


## O nome do portal. 200 px entre portais: o nome mais longo usa duas linhas de Spleen 16. Trancado (a.trava, dados/v2_progressao.json),
## o nome fica numa linha só e a de baixo traz o cadeado e o que abre o portal.
func rotulo_portal(n: Node2D, a: Dictionary, fechado: bool) -> void:
	nome_portal(n, a, fechado)
	trava_portal(n, a)


## O texto do nome do portal, uma ou duas linhas (base em y + 20, de 17 em 17).
func nome_portal(n: Node2D, a: Dictionary, fechado: bool) -> void:
	var p: Vector2 = a.pos
	var linhas := linhas_portal(a)
	for i in linhas.size():
		n.draw_string(
			Dados.fonte_texto,
			Vector2(p.x - 106, p.y + 20 + i * 17),
			linhas[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			212,
			16,
			Paleta.TEXTO_APAGADO if fechado else Paleta.TEXTO
		)


## A linha de baixo do portal trancado: cadeado e o que abre. Com chave à venda (ECO-5, "preco" em almas) mostra só o preço, porque
## "Vença a Floresta ou 300 almas" não cabe nos 200 px entre portais; o texto completo fica no prompt e no aviso (salao.gd).
func trava_portal(n: Node2D, a: Dictionary) -> void:
	var p: Vector2 = a.pos
	var trava := str(a.get("trava", ""))
	if trava != "" and int(a.get("preco", 0)) > 0:
		trava = "%d almas" % int(a.preco)
	if trava != "":
		linha_trava(n, Vector2(p.x, p.y + 37), trava)


## As linhas do nome do portal (a mesma conta que nome_portal desenha e que partes_rotulo mede).
func linhas_portal(a: Dictionary) -> Array:
	if str(a.nome) == "RUÍNAS DA FLORESTA" and str(a.get("trava", "")) == "":
		return ["RUÍNAS DA", "FLORESTA"]
	return [str(a.nome)]


## Os pedaços do nome, cada um com a caixa dele na sala: "nome" (o texto), "trava" (a linha de baixo, trancado) e "cadeado" (o grande,
## da estrutura trancada). O salão vivo apaga cada pedaço sozinho quando o herói o cobre (salao_vivo.gd _letreiros_vivos). As caixas
## espelham as bases de nome_portal (y + 20), trava_portal (y + 37), nome_estrutura (y + 30), cadeado_estrutura (y - 52) e
## trava_estrutura (y + 47): se uma base mudar, mude a caixa dela.
func partes_rotulo(a: Dictionary) -> Array[Dictionary]:
	var p: Vector2 = a.pos
	var trancado := str(a.get("trava", "")) != ""
	var partes: Array[Dictionary] = []
	if str(a.tipo) == "portal":
		partes.append({"parte": "nome", "caixa": Rect2(p.x - 106, p.y + 7, 212, 17.0 * linhas_portal(a).size())})
		if trancado:
			partes.append({"parte": "trava", "caixa": Rect2(p.x - 106, p.y + 24, 212, 17)})
	else:
		partes.append({"parte": "nome", "caixa": Rect2(p.x - 100, p.y + 15, 200, 20)})
		if trancado:
			partes.append({"parte": "cadeado", "caixa": Rect2(p.x - 11, p.y - 64, 22, 24)})
			partes.append({"parte": "trava", "caixa": Rect2(p.x - 100, p.y + 34, 200, 17)})
	return partes


## Desenha um pedaço de partes_rotulo ("nome", "cadeado" ou "trava") no nó n.
func desenha_parte(n: Node2D, a: Dictionary, parte: String, fechado: bool) -> void:
	if str(a.tipo) == "portal":
		if parte == "nome":
			nome_portal(n, a, fechado)
		else:
			trava_portal(n, a)
	elif parte == "nome":
		nome_estrutura(n, a)
	elif parte == "cadeado":
		cadeado_estrutura(n, a)
	else:
		trava_estrutura(n, a)


func estrutura(n: Node2D, a: Dictionary) -> void:
	var p: Vector2 = a.pos
	var id := str(a.id)
	var cor: Color = Paleta.ALMA if id == "altar" else Paleta.OURO
	n.draw_set_transform(p, 0, Vector2(1, 0.32))
	n.draw_circle(Vector2.ZERO, 48, Color(0, 0, 0, 0.36))
	n.draw_set_transform(Vector2.ZERO)
	var trancada := str(a.get("trava", "")) != ""
	if not textura(n, id, Rect2(p.x - 56, p.y - 100, 112, 112), Color(0.42, 0.42, 0.48) if trancada else Color.WHITE):
		n.draw_rect(Rect2(p.x - 38, p.y - 9, 76, 16), Color("#55515b"))
		if id == "altar":
			n.draw_arc(p + Vector2(0, -46), 30, 0, TAU, 32, cor.darkened(0.3), 3)
			n.draw_colored_polygon(
				PackedVector2Array([p + Vector2(0, -85), p + Vector2(18, -52), p + Vector2(0, -24), p + Vector2(-18, -52)]), cor.darkened(0.15)
			)
		elif id == "codice":
			n.draw_rect(Rect2(p.x - 23, p.y - 34, 46, 24), Color("#69606c"))
			n.draw_colored_polygon(
				PackedVector2Array(
					[p + Vector2(-32, -54), p + Vector2(0, -62), p + Vector2(32, -54), p + Vector2(29, -30), p + Vector2(0, -37), p + Vector2(-29, -30)]
				),
				Color("#b5a384")
			)
			n.draw_line(p + Vector2(0, -60), p + Vector2(0, -38), Color("#574b42"), 2)
		else:
			for dx in [-29.0, 0.0, 29.0]:
				n.draw_rect(Rect2(p.x + dx - 10, p.y - 51, 20, 42), Color("#716a76"))
				n.draw_circle(p + Vector2(dx, -62), 10, Color("#918795"))
	if not rotulos_fora:
		rotulo_estrutura(n, a)


## O nome da estrutura; trancada (a.trava), o nome apaga, um cadeado grande fica sobre ela e a linha de baixo diz o que a abre.
func rotulo_estrutura(n: Node2D, a: Dictionary) -> void:
	nome_estrutura(n, a)
	cadeado_estrutura(n, a)
	trava_estrutura(n, a)


## O nome da estrutura (base em y + 30); trancada, o nome apaga.
func nome_estrutura(n: Node2D, a: Dictionary) -> void:
	var p: Vector2 = a.pos
	var trava := str(a.get("trava", ""))
	n.draw_string(
		Dados.fonte_titulo,
		Vector2(p.x - 100, p.y + 30),
		str(a.nome),
		HORIZONTAL_ALIGNMENT_CENTER,
		200,
		19,
		Paleta.TEXTO_APAGADO if trava != "" else Paleta.OURO
	)


## O cadeado grande sobre a estrutura trancada (centro em y - 52).
func cadeado_estrutura(n: Node2D, a: Dictionary) -> void:
	var p: Vector2 = a.pos
	if str(a.get("trava", "")) != "":
		cadeado(n, p + Vector2(0, -52), 3)


## A linha de baixo da estrutura trancada: cadeado e condição (base em y + 47).
func trava_estrutura(n: Node2D, a: Dictionary) -> void:
	var p: Vector2 = a.pos
	var trava := str(a.get("trava", ""))
	if trava != "":
		linha_trava(n, Vector2(p.x, p.y + 47), trava)


## Cadeado de pixel (7 x 8 quadrados de `k` px) centrado em `c`.
func cadeado(n: Node2D, c: Vector2, k: int) -> void:
	var bits := [".#####.", "#.....#", "#.....#", "#######", "#######", "###.###", "###.###", "#######"]
	var o := (c - Vector2(3.5, 4.0) * k).round()
	for y in bits.size():
		for x in bits[y].length():
			if bits[y][x] == "#":
				n.draw_rect(Rect2(o + Vector2(x, y) * k + Vector2(1, 1), Vector2(k, k)), Color(0, 0, 0, 0.6))  # sombra
	for y in bits.size():
		for x in bits[y].length():
			if bits[y][x] == "#":
				n.draw_rect(Rect2(o + Vector2(x, y) * k, Vector2(k, k)), Color(1.0, 0.8, 0.35))


## Uma linha "cadeado + condição" centrada em x = c.x, com a base do texto em c.y (Spleen 16).
func linha_trava(n: Node2D, c: Vector2, txt: String) -> void:
	var largura := Dados.fonte_texto.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var x0 := roundf(c.x - (largura + 20.0) / 2.0)
	cadeado(n, Vector2(x0 + 7.0, c.y - 6.0), 2)
	n.draw_string(Dados.fonte_texto, Vector2(x0 + 21.0, c.y + 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.7))
	n.draw_string(Dados.fonte_texto, Vector2(x0 + 20.0, c.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.8, 0.35))


func chamas(n: Node2D, tempo: float) -> void:
	for x in [44.0, 918.0]:
		var p := Vector2(x, 80)
		var raio := 15.0 + sin(tempo * 7.0 + x) * 1.5
		n.draw_circle(p, raio, Color(1, 0.65, 0.3, 0.06))
	var altar: Vector2 = POSICOES.altar + Vector2(0, -53)
	n.draw_circle(altar, 24.0 + sin(tempo * 2.0) * 2.0, Paleta.alfa(Paleta.ALMA, 0.08))
