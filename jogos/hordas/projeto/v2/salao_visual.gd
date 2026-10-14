extends RefCounted
## Cenografia do santuário. Texturas opcionais em cache; nenhum nó ou carregamento por quadro.
const Paleta := preload("res://v2/paleta.gd")
const PASTA := "res://assets/v2/santuario/"
const POSICOES := {"estatuas": Vector2(180, 330), "altar": Vector2(780, 300), "codice": Vector2(780, 425)}
var texturas := {}


func _init() -> void:
	for nome in ["fundo", "estatuas", "altar", "codice", "portal_floresta", "portal_laboratorio", "portal_cidade", "portal_medio", "portal_fechado"]:
		var caminho: String = PASTA + str(nome) + ".png"
		if ResourceLoader.exists(caminho):
			texturas[nome] = load(caminho)


static func posicao(id: String, original: Vector2) -> Vector2:
	return POSICOES.get(id, original)


func textura(n: Node2D, nome: String, r: Rect2) -> bool:
	if not texturas.has(nome):
		return false
	n.draw_texture_rect(texturas[nome], r, false)
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
	# 200 px entre portais: o nome mais longo usa duas linhas de Spleen 16.
	var linhas := [str(a.nome)]
	if str(a.nome) == "RUÍNAS DA FLORESTA":
		linhas = ["RUÍNAS DA", "FLORESTA"]
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


func estrutura(n: Node2D, a: Dictionary) -> void:
	var p: Vector2 = a.pos
	var id := str(a.id)
	var cor: Color = Paleta.ALMA if id == "altar" else Paleta.OURO
	n.draw_set_transform(p, 0, Vector2(1, 0.32))
	n.draw_circle(Vector2.ZERO, 48, Color(0, 0, 0, 0.36))
	n.draw_set_transform(Vector2.ZERO)
	if not textura(n, id, Rect2(p.x - 56, p.y - 100, 112, 112)):
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
	n.draw_string(Dados.fonte_titulo, Vector2(p.x - 100, p.y + 30), str(a.nome), HORIZONTAL_ALIGNMENT_CENTER, 200, 19, Paleta.OURO)


func chamas(n: Node2D, tempo: float) -> void:
	for x in [44.0, 918.0]:
		var p := Vector2(x, 80)
		var raio := 15.0 + sin(tempo * 7.0 + x) * 1.5
		n.draw_circle(p, raio, Color(1, 0.65, 0.3, 0.06))
	var altar: Vector2 = POSICOES.altar + Vector2(0, -53)
	n.draw_circle(altar, 24.0 + sin(tempo * 2.0) * 2.0, Paleta.alfa(Paleta.ALMA, 0.08))
