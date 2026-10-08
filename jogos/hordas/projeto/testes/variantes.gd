extends Node
# Teste automático: variantes de cenário por andar da região (#112 item 7).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/variantes.tscn  (imprime "VARIANTES falhas=0")
const Cenario := preload("res://scripts/hordas/cenario.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func _ready() -> void:
	var lista: Array = Dados.json("cenarios").get("variantes", {}).get("floresta", [])
	ok(lista.size() >= 5, "a floresta tem 5 variantes (%d)" % lista.size())
	for v in lista:
		ok(FileAccess.file_exists("res://assets/cenarios/%s/cenario.json" % v) and FileAccess.file_exists("res://assets/cenarios/%s/piso.png.import" % v), "a variante %s tem arte" % v)
	for s in [1, 7, 12345]:
		Sorte.iniciar(s)
		var vistos := {}
		for andar in lista.size():
			var a := Cenario.variante("floresta", andar)
			vistos[a] = true
			ok(Cenario.variante("floresta", andar) == a, "semente %d: o andar %d dá sempre a mesma variante" % [s, andar])
			ok(Cenario.variante("floresta", andar + lista.size()) == a, "o andar %d repete a cada volta" % andar)
			ok(a in lista, "%s é uma variante válida" % a)
		ok(vistos.size() == lista.size(), "semente %d: cada andar tem uma variante diferente (%d)" % [s, vistos.size()])
		ok(Cenario.variante("floresta", 0) == lista[0], "o andar 0 é a mata fechada")
		# mesma semente, sorteios no meio: a ordem não muda (stream independente)
		Sorte.fluxo("outra_coisa").randi()
		var antes := Cenario.variante("floresta", 3)
		Sorte.iniciar(s)
		ok(Cenario.variante("floresta", 3) == antes, "semente %d: igual em outro computador" % s)
	# sementes diferentes dão ordens diferentes em algum caso
	var ordens := {}
	for s in range(1, 30):
		Sorte.iniciar(s)
		ordens[str(Cenario.ordem_variantes("floresta", lista.size()))] = true
	ok(ordens.size() > 1, "a semente muda a ordem dos andares")
	# as outras regiões também têm variantes (3 a 5, a primeira é o cenário-base)
	for base in ["pantano", "deserto", "gelo", "reino"]:
		var lr: Array = Dados.json("cenarios").get("variantes", {}).get(base, [])
		ok(lr.size() >= 3 and lr[0] == base, "%s tem variantes (%d)" % [base, lr.size()])
		for v in lr:
			ok(FileAccess.file_exists("res://assets/cenarios/%s/cenario.json" % v) and FileAccess.file_exists("res://assets/cenarios/%s/piso.png.import" % v), "a variante %s tem arte" % v)
		Sorte.iniciar(7)
		var vistos_r := {}
		for andar in lr.size():
			vistos_r[Cenario.variante(base, andar)] = true
		ok(vistos_r.size() == lr.size(), "%s: cada andar tem uma variante diferente" % base)
		ok(Cenario.variante(base, 0) == base, "%s: o andar 0 é o cenário-base" % base)
	# região sem variantes = cenário único de hoje
	ok(Cenario.variante("cidade", 3) == "cidade", "sem variantes vale o cenário único")
	ok(Cenario.base_de("floresta_ruina") == "floresta" and Cenario.base_de("gelo") == "gelo", "base_de acha o cenário-base")
	print("VARIANTES falhas=", falhas)
	get_tree().quit()
