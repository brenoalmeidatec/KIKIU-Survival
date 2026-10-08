extends Node
# Teste automático (#115): armas universais (50+), variações pela semente, limite de slots, ascensão, fusão e ofertas
# do nível 30-40 sem depender de cura.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/armas_universais.tscn  (imprime "ARMASUNIV falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Univ := preload("res://scripts/hordas/universais.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	var bases := Univ.bases_sorteaveis()
	ok(bases.size() >= 50, "pelo menos 50 armas universais (%d)" % bases.size())
	var armas_d: Dictionary = Dados.json("armas")
	var vars: Dictionary = Univ.cfg().variacoes
	for b in bases:
		for v in vars:
			var id := Univ.id_de(b, v)
			var d: Dictionary = armas_d.get(id, {})
			ok(not d.is_empty() and d.has("base") and d.has("niveis") and d.has("tipo") and d.get("classe") == "global", "entrada " + id)
			ok(Dados.tex("icone_" + str(d.get("icone", ""))) != null, "ícone existe: " + id)
	ok(armas_d["u_espada_treino__gelida"].nome == "Espada de Treino Gélida" and armas_d["u_marreta_enferrujada__gelida"].nome == "Marreta Enferrujada Gélida", "nome com gênero")
	ok(armas_d["u_espada_treino__gelida"].elemento == "gelo", "variação gélida tem elemento gelo")
	ok(Univ.base_de("u_espada_treino__lunar") == "espada_treino" and Univ.eh_universal("u_espada_treino"), "base_de / eh_universal")
	var v1 := []
	var v2 := []
	for b in bases:
		v1.append(Univ.variacao_para(b, 7, 3))
		v2.append(Univ.variacao_para(b, 7, 3))
	ok(v1 == v2, "mesma semente, mesmas variações")
	var dist := {}
	for s in 400:
		dist[Univ.variacao_para("arco_tosco", s, 1)] = true
	ok(dist.size() >= 6, "as variações aparecem no sorteio (%d)" % dist.size())
	ok(Univ.outra_variacao("arco_tosco", "sangue", 7, 2) != "sangue", "reforja nunca devolve a atual")
	var cinco := ["u_a", "u_b", "u_c", "u_d", "u_e"]
	ok(not Univ.cabe(cinco, false) and Univ.cabe(["u_a", "u_b", "u_c", "u_d"], false), "limite total 5")
	ok(not Univ.cabe(["katana", "desert_eagles"], true), "máximo 2 únicas")
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = false
	a.semente = 7
	add_child(a)
	await get_tree().create_timer(0.3, true, false, true).timeout
	a.bot = false
	a.jogador.bot = false
	for i in 40:
		for c in a.sortear_cartas():
			if c.tipo == "arma" and Univ.eh_universal(str(c.id)) and c.nivel == 1 and a.armas.lista.size() < Univ.max_total():
				a.aplicar(c)
				break
	ok(a.armas.lista.size() == Univ.max_total(), "slots enchem até o limite (%d)" % a.armas.lista.size())
	for i in 20:
		for c in a.sortear_cartas():
			ok(not (c.tipo == "arma" and c.nivel == 1), "com slots cheios não oferece arma nova")
	for w in a.armas.lista:
		w.nivel = a.armas.nivel_max(w.id)
	var pas: Dictionary = Dados.json("passivos")
	for id in pas:
		if not id.begins_with("_") and a.passivos.size() < 5:
			a.passivos[id] = 0
	for id in a.passivos:
		a.passivos[id] = int(pas[id].get("max", 5))
	var so_cura := true
	var tipos := {}
	for i in 30:
		for c in a.sortear_cartas():
			tipos[c.tipo] = true
			if c.tipo != "cura":
				so_cura = false
	ok(not so_cura and tipos.has("ascensao"), "tudo no máximo: há ascensão, não só cura " + str(tipos.keys()))
	a.armas.lista.clear()
	for ing in ["pocao_corrosiva", "frasco_incendiario"]:
		a.armas.adicionar(Univ.id_de(ing, "sangue"))
	for w in a.armas.lista:
		w.nivel = a.armas.nivel_max(w.id)
	var fs: Array = Univ.fusoes_possiveis(a.armas.lista, a.armas.nivel_max)
	ok(fs.size() == 1 and fs[0].vira == "u_fusao_lua_veneno", "receita reconhecida com variações")
	var carta_fusao := {}
	for i in 40:
		for c in a.sortear_cartas():
			if c.tipo == "fusao":
				carta_fusao = c
	ok(not carta_fusao.is_empty(), "a carta de fusão aparece")
	if not carta_fusao.is_empty():
		a.aplicar(carta_fusao)
		ok(a.armas.lista.size() == 1 and a.armas.lista[0].id == "u_fusao_lua_veneno", "fusão consome 2 e deixa 1 (libera slot)")
		ok(Univ.cabe(a.armas.lista.map(func(x): return x.id), false), "slot livre depois da fusão")
	var w0: Dictionary = a.armas.lista[0]
	var d0: float = float(a.armas._s(w0).dano)
	a.aplicar({"tipo": "ascensao", "id": w0.id, "nome": "x", "nivel": 1})
	ok(float(a.armas._s(w0).dano) > d0 * 1.1, "ascensão soma dano")
	print("ARMASUNIV falhas=", falhas)
	get_tree().quit(1 if falhas > 0 else 0)
