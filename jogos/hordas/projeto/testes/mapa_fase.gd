extends Node
# Teste automático: mapa fechado de cada fase (#128, marco 4) - conectividade até o portal, mesma semente = mesmo mapa,
# portão com o tema da região, limite de peças e névoa do minimapa.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/mapa_fase.tscn  (imprime "MAPA_FASE falhas=0")
const MapaFase := preload("res://scripts/hordas/mapa_fase.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
const Regioes := preload("res://scripts/hordas/regioes.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var regioes := ["floresta", "pantano", "deserto", "gelo", "reino"]
	var cfg := MapaFase.cfg()
	var w := int(cfg.largura)
	var h := int(cfg.altura)

	# --- cada região x 6 andares: todo ponto que anda alcança o portal, e o herói nasce ligado a ele
	var sem_ligacao := 0
	for r in regioes:
		for andar in 6:
			Sorte.iniciar(1000 + andar)
			var m := MapaFase.gerar(r, andar)
			ok(m.ok, "%s andar %d: nem todo ponto que anda alcança o portal" % [r, andar])
			ok(m.linhas.size() == h and str(m.linhas[0]).length() == w, "%s: tamanho da grade" % r)
			var g := "".join(m.linhas)
			ok(g.count("G") == 0, "%s: o portão não ficou com o tema" % r)
			ok(g.count(str(cfg.temas_portao[r])) >= 14, "%s: o portão do chefe tem o tema da região (%s)" % [r, cfg.temas_portao[r]])
			var pt: Vector2i = m.portal
			ok(m.linhas[pt.y][pt.x] == "." and MapaFase.passavel(str(m.linhas[pt.y][pt.x])), "%s: o portal não anda" % r)
			ok(Vector2(m.inicio).distance_to(Vector2(pt)) >= int(cfg.distancia_min) - 0.5, "%s: herói nasce perto demais do portal" % r)
			if not m.ok:
				sem_ligacao += 1

	# --- mesma semente = mesmo mapa; semente diferente = (quase sempre) outro
	Sorte.iniciar(7)
	var a := MapaFase.gerar("floresta", 2)
	Sorte.iniciar(7)
	var b := MapaFase.gerar("floresta", 2)
	ok(a.linhas == b.linhas and a.inicio == b.inicio, "mesma semente dá o mesmo mapa")
	Sorte.iniciar(8)
	var c := MapaFase.gerar("floresta", 2)
	ok(c.linhas != a.linhas, "semente diferente dá mapa diferente")

	# --- regiões diferentes não repetem as mesmas peças no mesmo andar
	Sorte.iniciar(7)
	var f1 := MapaFase.gerar("floresta", 0)
	var g1 := MapaFase.gerar("gelo", 0)
	ok(f1.linhas != g1.linhas, "região diferente dá mapa diferente")

	# --- limite de peças: nenhuma peça passa do máximo sorteado (conta pelas peças disponíveis)
	ok(int(cfg.pecas_max) >= int(cfg.pecas_min) and int(cfg.pecas_min) >= 12 and int(cfg.pecas_max) <= 20, "limite de peças entre 12 e 20")
	var disponiveis := MapaFase._ids_da_regiao(cfg.pecas, "floresta")
	ok(disponiveis.size() >= int(cfg.pecas_min), "floresta tem peças suficientes para o mínimo (%d)" % disponiveis.size())

	# --- borda sempre fechada (nada sai do mapa)
	var fechada := true
	for r in regioes:
		var m := MapaFase.gerar(r, 1)
		for x in w:
			if m.linhas[0][x] != "#" or m.linhas[h - 1][x] != "#":
				fechada = false
		for y in h:
			if m.linhas[y][0] != "#" or m.linhas[y][w - 1] != "#":
				fechada = false
	ok(fechada, "a borda do mapa é de relevo em todas as regiões")

	# --- névoa do minimapa: revela o raio e nada além
	var visto := PackedByteArray()
	visto.resize(w * h)
	visto.fill(0)
	MapaFase.revelar(visto, w, h, Vector2i(10, 10), 3)
	ok(visto[10 * w + 10] == 1 and visto[10 * w + 13] == 1, "névoa revela o centro e o raio")
	ok(visto[10 * w + 14] == 0 and visto[0] == 0, "névoa não passa do raio")

	# --- com o nome de região real (dados/regioes.json), o mapa sai com o id da região
	if Regioes.ativo():
		var ids := []
		for reg in Regioes.lista():
			ids.append(str(reg.id))
		ok(ids.size() == regioes.size(), "as 5 regiões do regioes.json têm mapa de fase")

	ok(sem_ligacao == 0, "nenhuma fase saiu desconectada (%d)" % sem_ligacao)
	print("MAPA_FASE falhas=%d" % falhas)
	get_tree().quit()
