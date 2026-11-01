extends "res://testes/isolamento_v2.gd"
# Teste dos ÍCONES ÚNICOS das cartas (CAR-7, plano de 01/11): o campo icone de cada carta de dados/v2_cartas.json
# (stats, golpes e modificadores; as evoluções não têm ícone) é único entre as cartas, aponta para um PNG que carrega
# de assets/gerado/ e esse PNG não é o mesmo desenho (pixel a pixel) de outro ícone. Antes do CAR-7 havia 14 grupos de
# cartas com o mesmo ícone e dois ícones com desenho idêntico em nomes diferentes. A arte que o jogador vê na escolha,
# no baú e na HUD é a de assets/v2/icones_cartas (por ID); este teste guarda o ícone antigo, que vale de fallback.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_cartas_icones.tscn  (imprime "v2_cartas_icones falhas=0")

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHA: ", msg)


func _ready() -> void:
	var cartas: Dictionary = Dados.json("v2_cartas")
	var donos := {}  # icone -> [id, ...]
	var total := 0
	for secao in ["stats", "golpes", "modificadores"]:
		for d in cartas[secao]:
			var icone := str(d.get("icone", ""))
			total += 1
			ok(icone != "", "%s: sem campo icone" % d.id)
			ok(Dados.tex(icone) != null, "%s: o ícone %s não carrega de assets/gerado/" % [d.id, icone])
			if not donos.has(icone):
				donos[icone] = []
			donos[icone].append(str(d.id))
	ok(total >= 67, "v2_cartas.json tem %d cartas com ícone, esperava pelo menos 67" % total)  # cresce quando entram cartas novas
	var desenhos := {}  # hash dos pixels -> icone
	for icone in donos:
		ok(donos[icone].size() == 1, "ícone %s repetido em %s" % [icone, ", ".join(donos[icone])])
		var tex := Dados.tex(icone)
		if tex == null:
			continue
		var h := str(hash(tex.get_image().get_data()))
		if desenhos.has(h):
			ok(false, "ícone %s tem o mesmo desenho que %s" % [icone, desenhos[h]])
		else:
			desenhos[h] = icone

	print("v2_cartas_icones falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
