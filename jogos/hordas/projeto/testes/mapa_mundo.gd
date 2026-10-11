extends Node
# Teste automático: mapa fechado no mundo (#128, parte 2) - o herói não atravessa parede, escorrega num eixo só,
# o começo do mapa cai em (0, 0) e a névoa do minimapa revela em volta do herói.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/mapa_mundo.tscn  (imprime "MAPA_MUNDO falhas=0")
const MapaFase := preload("res://scripts/hordas/mapa_fase.gd")
const MapaFaseMundo := preload("res://scripts/hordas/mapa_fase_mundo.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Sorte.iniciar(42)
	var m := MapaFase.gerar("floresta", 1)
	ok(m.ok, "mapa de teste sai conectado")
	var mundo := MapaFaseMundo.new()
	add_child(mundo)
	mundo.configurar(m)

	# --- o começo do mapa cai em (0, 0), e não é parede
	ok(mundo.tile_de(Vector2.ZERO) == m.inicio, "o começo do herói cai no tile de início")
	ok(not mundo.parede_em(Vector2.ZERO), "o começo do herói não é parede")
	ok(mundo.parede_em(Vector2(-100000, 0)), "fora do mapa é parede")

	# --- uma parede de verdade bloqueia a caixa do herói
	var achou := Vector2.INF
	for y in range(1, m.altura - 1):
		for x in range(1, m.largura - 1):
			if m.linhas[y][x] == "#" and achou == Vector2.INF:
				achou = mundo.origem + (Vector2(x, y) + Vector2(0.5, 0.5)) * MapaFaseMundo.TILE
	ok(achou != Vector2.INF, "o mapa tem parede (borda)")
	ok(mundo.bate_heroi(achou - MapaFaseMundo.PES), "a caixa do herói bate na parede")

	# --- prender: o herói que entra na parede volta; se só um eixo bate, escorrega no outro
	var j := Node2D.new()
	add_child(j)
	# acha um ponto de chão com parede logo à direita (escorregar em y, eixo x bloqueado)
	var pe := Vector2.INF
	for y in range(2, m.altura - 2):
		for x in range(2, m.largura - 3):
			if MapaFase.passavel(m.linhas[y][x]) and m.linhas[y][x + 1] == "#" and m.linhas[y - 1][x] == "." and pe == Vector2.INF:
				pe = mundo.origem + (Vector2(x, y) + Vector2(0.5, 0.5)) * MapaFaseMundo.TILE - MapaFaseMundo.PES
	ok(pe != Vector2.INF, "acha um ponto de chão encostado na parede")
	if pe != Vector2.INF:
		var antes := pe
		j.position = pe + Vector2(MapaFaseMundo.TILE, -MapaFaseMundo.TILE * 0.5)   # tenta ir para a parede e subir
		mundo.prender(j, antes)
		ok(j.position != antes or not mundo.bate_heroi(j.position), "o herói não fica dentro da parede")
		ok(not mundo.bate_heroi(j.position), "depois de prender, o herói está livre")
		# um movimento livre não é mexido
		j.position = antes + Vector2(1, 0)
		var livre := j.position
		mundo.prender(j, antes)
		ok(j.position == livre or mundo.bate_heroi(livre), "movimento em chão livre não é cortado")

	# --- névoa: o minimapa revela em volta do herói e nada além do raio
	mundo.atualizar(Vector2.ZERO)
	var t := mundo.tile_de(Vector2.ZERO)
	var vistos := 0
	for v in mundo.visto:
		vistos += v
	ok(vistos > 0 and mundo.visto[t.y * m.largura + t.x] == 1, "a névoa revela o tile do herói")
	ok(mundo.visto[0] == 0 or t.x - 0 <= MapaFaseMundo.RAIO_NEBLINA, "a névoa não passa do raio")

	# --- portal: fica no centro do pátio do portão (chão), e o portal_mundo cai nele
	var pt := mundo.tile_de(mundo.portal_mundo())
	ok(pt == m.portal, "o portal sai no tile do portão")
	ok(not mundo.parede_em(mundo.portal_mundo()), "o portal não nasce em parede")

	# --- perigos: chão de espinho, veneno, lodo ou gelo machuca por segundo; chão comum não
	var perigo := Vector2.INF
	var comum := Vector2.INF
	for y in range(1, m.altura - 1):
		for x in range(1, m.largura - 1):
			var ch: String = m.linhas[y][x]
			var no := mundo.origem + (Vector2(x, y) + Vector2(0.5, 0.5)) * MapaFaseMundo.TILE
			if ch in ["s", "p", "l", "e"] and perigo == Vector2.INF:
				perigo = no
			if ch == "." and comum == Vector2.INF:
				comum = no
	if perigo != Vector2.INF:
		ok(mundo.dano_seg_em(perigo) > 0.0, "chão perigoso machuca por segundo")
	ok(comum != Vector2.INF and mundo.dano_seg_em(comum) == 0.0, "chão comum não machuca")
	ok(mundo.dano_seg_em(Vector2(-100000, 0)) == 0.0, "fora do mapa não machuca")
	ok(mundo.chao_em(Vector2(-100000, 0)) == "", "fora do mapa não tem chão")
	var gelo := Vector2.INF
	for y in range(1, m.altura - 1):
		for x in range(1, m.largura - 1):
			if m.linhas[y][x] == "e" and gelo == Vector2.INF:
				gelo = mundo.origem + (Vector2(x, y) + Vector2(0.5, 0.5)) * MapaFaseMundo.TILE
	if gelo != Vector2.INF:
		ok(mundo.chao_em(gelo) == "e", "chão de gelo fino é reconhecido")

	print("MAPA_MUNDO falhas=%d" % falhas)
	get_tree().quit()
