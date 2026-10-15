extends Node
# Teste dos ícones próprios das cartas da v2 (arte do PR #272, assets/v2/icones_cartas, gerados por gerar_objetos.py icones).
#  - o índice indice.json existe, traz _ajuda e tem entrada para cada ID de carta de dados/v2_cartas.json (stats, golpes,
#    modificadores e evoluções) e para katana, escudo, ruptura e ultimate_q;
#  - cada um desses IDs tem o ícone de 32x32 (escolha, baú, slots da HUD) e o de 16x16 (linha do SUA BUILD), e os dois carregam;
#  - sem ícone próprio, vale o ícone antigo (campo icone, assets/gerado/); ID desconhecido não dá ícone.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_icones_cartas.tscn  (imprime "v2_icones_cartas falhas=0")

const INDICE := "res://assets/v2/icones_cartas/indice.json"
const SECUNDARIOS := ["katana", "escudo", "ruptura", "ultimate_q"]

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHA: ", msg)


func _ready() -> void:
	var cartas: Dictionary = Dados.json("v2_cartas")
	var ids: Array = []
	for secao in ["stats", "golpes", "modificadores", "evolucoes"]:
		for d in cartas[secao]:
			ids.append(str(d.id))
	ok(ids.size() == 86, "v2_cartas.json tem %d cartas, esperava 86" % ids.size())

	var lido: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDICE))
	ok(lido is Dictionary, "indice.json não lê como JSON")
	if lido is Dictionary:
		var icones: Dictionary = lido.get("icones", {})
		ok(str(lido.get("_ajuda", "")) != "", "indice.json sem _ajuda")
		ok(icones.size() == 90, "indice.json tem %d ícones, esperava 90" % icones.size())
		for id in ids + SECUNDARIOS:
			ok(icones.has(id), "%s sem entrada no indice.json" % id)

	for id in ids + SECUNDARIOS:
		var grande := Dados.icone_carta(id)
		ok(grande != null, "%s: ícone de 32 px não carrega" % id)
		if grande != null:
			ok(grande.get_size() == Vector2(32, 32), "%s: ícone de 32 px tem %s" % [id, grande.get_size()])
		var pequeno := Dados.icone_carta(id, "", true)
		ok(pequeno != null, "%s: ícone de 16 px não carrega" % id)
		if pequeno != null:
			ok(pequeno.get_size() == Vector2(16, 16), "%s: ícone de 16 px tem %s" % [id, pequeno.get_size()])

	# sem ícone próprio: o antigo (campo icone, assets/gerado/) continua valendo
	ok(Dados.icone_carta("cura", "icone_vida") == Dados.tex("icone_vida"), "ID sem ícone próprio deveria cair no antigo")
	ok(Dados.icone_carta("cura", "icone_vida", true) == Dados.tex("icone_vida"), "ID sem ícone próprio (16 px) deveria cair no antigo")
	ok(Dados.icone_carta("nao_existe") == null, "ID desconhecido sem antigo deveria dar null")
	ok(Dados.icone_carta("") == null, "ID vazio sem antigo deveria dar null")

	print("v2_icones_cartas falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
