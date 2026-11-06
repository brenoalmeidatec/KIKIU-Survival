extends "res://testes/isolamento_v2.gd"
# Teste dos DADOS da teia da aranha (dados/v2_teia.json, lido por v2/teias.gd): o arquivo existe e é válido, tem as seções e os campos que o código lê, o multiplicador de lentidão
# é 0,5 (pedido do Alisson, 06/11: metade da velocidade), o chão usa a mesma proporção dos avisos, o teto do perfil Baixo não passa do normal, a lista `corta` só tem desenhos
# conhecidos e cada folha declarada tem os campos. Também confere o elenco (a flag `teia` só nas aranhas da Mata e no padrão) e que cada chave do _ajuda do JSON está mesmo lá.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_teia_dados.tscn  (imprime "v2_teia_dados falhas=0")

const Avisos := preload("res://v2/avisos.gd")
const Elenco := preload("res://v2/elenco.gd")

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var d: Dictionary = Dados.json("v2_teia")
	ok(not d.is_empty(), "dados/v2_teia.json existe e é um objeto")
	ok(str(d.get("_ajuda", "")).length() > 200, "o arquivo tem _ajuda explicando os números")
	for k in ["teia", "lento", "aranha", "queima", "corta", "folhas"]:
		ok(d.get(k) is Dictionary, "seção '%s'" % k)
	var t: Dictionary = d.get("teia", {})
	for k in ["raio", "achata", "vida_s", "sumir_s", "max_vivas", "max_vivas_baixo", "max_voando"]:
		ok(t.has(k) and float(t[k]) > 0.0, "teia.%s > 0" % k)
	ok(int(t.get("max_vivas", 0)) >= 1, "max_vivas >= 1")
	ok(int(t.get("max_vivas_baixo", 99)) <= int(t.get("max_vivas", 0)), "o perfil Baixo não tem mais teias que o normal")
	ok(is_equal_approx(float(t.get("achata", 0.0)), Avisos.ACHATA), "a teia no chão usa a mesma proporção dos avisos (%s)" % Avisos.ACHATA)
	var l: Dictionary = d.get("lento", {})
	ok(is_equal_approx(float(l.get("mult", 1.0)), 0.5), "a teia deixa o herói a metade da velocidade (lento.mult 0,5)")
	ok(not (l.get("estados", []) as Array).is_empty(), "lento.estados não é vazio")
	for nome in l.get("estados", []):
		ok(preload("res://v2/teias.gd").estado_do_heroi(str(nome)) >= 0, "lento.estados: '%s' é um estado do herói" % nome)
	ok(not (l.get("estados", []) as Array).has("ESQUIVA"), "a esquiva escapa da teia (o contra-jogo)")
	var a: Dictionary = d.get("aranha", {})
	for k in ["dist_min", "dist_max", "preparo_s", "disparo_s", "recuperar_s", "voo_s", "arco_px", "boca_dist", "boca_alt", "fio_s", "abre_ar_s"]:
		ok(a.has(k) and float(a[k]) > 0.0, "aranha.%s > 0" % k)
	ok(float(a.get("dist_min", 0)) < float(a.get("dist_max", 0)), "dist_min < dist_max")
	for k in ["recarga", "recarga_inicial"]:
		var r: Array = a.get(k, [])
		ok(r.size() == 2 and float(r[0]) > 0.0 and float(r[0]) <= float(r[1]), "aranha.%s é [min, max] positivo" % k)
	for nome in d.get("corta", {}).get("passos", {}) as Dictionary:
		ok(["corte", "quebra"].has(str(d.corta.passos[nome])), "corta.passos.%s tem desenho conhecido" % nome)
	ok(["corte", "quebra", false].has(d.get("corta", {}).get("ruptura", null)), "corta.ruptura conhecido")
	for id in d.get("corta", {}).get("especiais", {}):
		ok(["corte", "quebra", false].has(d.corta.especiais[id]), "corta.especiais.%s conhecido" % id)
	var f: Dictionary = d.get("folhas", {})
	for k in ["abre", "queima", "corte", "quebra", "some", "bolota", "abre_ar"]:
		var e: Dictionary = f.get(k, {})
		for c in ["arquivo", "quadro", "colunas", "quadros", "linhas", "fps", "pivo"]:
			ok(e.has(c), "folhas.%s.%s" % [k, c])
	# o elenco: a Aranha da Mata atira, a Larva de Cripta (mesmo sprite, provisório) não, e o padrão (tipo liso) atira
	var el = Elenco.new()
	el.montar("floresta", Dados.json("v2_combate").diretor, Dados.json("v2_cartas").elites)
	var mata: Dictionary = el._achar("aranha_mata")
	ok(bool(mata.get("teia", false)), "floresta: a Aranha da Mata atira teia")
	for t2 in el.tipos:
		if t2.id != "aranha_mata":
			ok(not bool(t2.get("teia", false)), "floresta: %s não atira teia" % t2.id)
	var el2 = Elenco.new()
	el2.montar("medio", Dados.json("v2_combate").diretor, Dados.json("v2_cartas").elites)
	for t3 in el2.tipos:
		ok(not bool(t3.get("teia", false)), "medio: %s (sprite provisório da aranha) não atira" % t3.id)
	var el3 = Elenco.new()
	el3.montar("mapa_que_nao_existe", Dados.json("v2_combate").diretor, Dados.json("v2_cartas").elites)
	for t4 in el3.tipos:
		ok(bool(t4.get("teia", false)) == (t4.sprite == "inimigo_aranha_tecela"), "padrão: só a aranha comum atira (%s)" % t4.sprite)
	print("v2_teia_dados falhas=%d" % falhas)
	get_tree().quit()
