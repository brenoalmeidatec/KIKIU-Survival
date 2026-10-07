extends Node
# Teste automático: etiquetas e bônus de conjunto (#63). Contagem, degraus que ligam e desligam, efeitos no jogo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/conjuntos.tscn  (imprime "CONJ falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Conjuntos := preload("res://scripts/hordas/conjuntos.gd")
const STATS := ["dano", "recarga", "area", "quantidade", "velocidade_proj", "duracao", "vida_max", "regen", "velocidade", "ima", "sorte", "xp", "critico", "critico_mult"]
const EFEITOS := ["explosao_morte", "lento_acerto", "cura_abate"]
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	var c := Conjuntos.cfg()
	var etqs: Dictionary = c.get("etiquetas", {})
	ok(etqs.size() >= 10, "pelo menos 10 etiquetas (%d)" % etqs.size())
	for e in ["lamina", "fogo", "gelo", "trovao", "sangue", "sombra", "sagrado", "arremesso", "invocacao", "pesado"]:
		ok(etqs.has(e), "etiqueta pedida existe: " + e)

	# --- dados: todo item tem etiqueta, e todo degrau é válido
	var usadas := {}
	for arq in ["armas", "passivos", "equipamentos"]:
		var d: Dictionary = Dados.json(arq)
		for id in d:
			if id.begins_with("_") or not d[id] is Dictionary:
				continue
			var et: Array = d[id].get("etiquetas", [])
			ok(not et.is_empty(), "%s/%s tem etiquetas" % [arq, id])
			for e in et:
				ok(etqs.has(str(e)), "%s/%s: etiqueta '%s' existe nos dados" % [arq, id, e])
				usadas[str(e)] = true
	for e in etqs:
		ok(not Conjuntos.degraus(e).is_empty(), "etiqueta %s tem degraus" % e)
		var ant := 0
		for g in Conjuntos.degraus(e):
			ok(g > ant, "%s: degraus em ordem crescente" % e)
			ant = g
			var dg: Dictionary = c.limiares[e][str(g)]
			ok(str(dg.get("texto", "")) != "", "%s %d tem texto" % [e, g])
			ok(dg.has("bonus") or dg.has("efeito"), "%s %d muda alguma coisa" % [e, g])
			for k in dg.get("bonus", {}):
				ok(k in STATS, "%s %d: atributo conhecido (%s)" % [e, g, k])
			for k in dg.get("efeito", {}):
				ok(k in EFEITOS, "%s %d: efeito conhecido (%s)" % [e, g, k])
	for e in ["lamina", "fogo", "gelo", "trovao", "sangue", "sombra", "sagrado", "arremesso", "invocacao", "pesado", "guerreiro"]:
		ok(usadas.has(e), "alguém usa a etiqueta " + e)
	ok(Conjuntos.degraus("guerreiro") == [3, 5], "o conjunto nomeado do Hazaki tem degraus 3 e 5")
	ok(str(etqs.guerreiro.get("conjunto", "")) == "Panóplia do Shogun", "o conjunto das 5 peças tem nome próprio")

	# --- contagem (função pura)
	var n := Conjuntos.contar(["pendrive", "machado"], {"energetico": 3}, {})
	ok(n.get("lamina", 0) == 3 and n.get("arremesso", 0) == 2, "pendrive + machado + Pedra de Amolar: Lâmina 3, Arremesso 2 (%s)" % [n])
	ok(Conjuntos.contar([], {}, {}).is_empty(), "build vazia não tem etiqueta")
	var eq := {"cabeca": "cabeca_guerreiro", "peitoral": "armadura_samurai", "rosto": "mascara_menpo", "bracos": "bracadeiras_ferro", "pes": "botas_guerra"}
	ok(Conjuntos.contar([], {}, eq).get("guerreiro", 0) == 5, "as 5 peças do Hazaki dão Guerreiro 5")
	ok(Conjuntos.nivel_ativo("lamina", 1) == 0 and Conjuntos.nivel_ativo("lamina", 2) == 2 and Conjuntos.nivel_ativo("lamina", 3) == 2 and Conjuntos.nivel_ativo("lamina", 7) == 6, "degrau ativo por contagem")
	ok(Conjuntos.proximo("lamina", 1) == 2 and Conjuntos.proximo("lamina", 2) == 4 and Conjuntos.proximo("lamina", 6) == 0, "próximo degrau")

	# --- bônus liga e desliga nos limiares
	ok(Conjuntos.bonus({"lamina": 1}).is_empty(), "1 Lâmina: nada")
	ok(is_equal_approx(float(Conjuntos.bonus({"lamina": 2}).get("critico", 0)), 0.08), "2 Lâminas: +8% de crítico")
	ok(Conjuntos.bonus({"lamina": 3}) == Conjuntos.bonus({"lamina": 2}), "3 Lâminas: o mesmo que 2")
	var b4 := Conjuntos.bonus({"lamina": 4})
	ok(is_equal_approx(float(b4.get("critico", 0)), 0.08) and is_equal_approx(float(b4.get("dano", 0)), 0.15), "4 Lâminas: soma os degraus de baixo (%s)" % [b4])
	var b6 := Conjuntos.bonus({"lamina": 6})
	ok(is_equal_approx(float(b6.get("critico", 0)), 0.15) and is_equal_approx(float(b6.get("critico_mult", 0)), 0.5), "6 Lâminas: tudo ligado (%s)" % [b6])
	var somado := Conjuntos.bonus({"lamina": 2, "pesado": 2})
	ok(is_equal_approx(float(somado.get("critico", 0)), 0.08) and is_equal_approx(float(somado.get("vida_max", 0)), 20.0), "duas etiquetas somam")
	ok(Conjuntos.efeitos({"fogo": 5}).is_empty() and float(Conjuntos.efeitos({"fogo": 6}).get("explosao_morte", 0)) == 1.0, "Fogo 6 liga a explosão, 5 não")
	ok(float(Conjuntos.efeitos({"gelo": 6}).get("lento_acerto", 0)) == 0.6, "lentidão do Gelo não empilha (pega o maior)")
	var res := Conjuntos.resumo({"lamina": 2, "fogo": 1, "pesado": 4, "gelo": 0})
	ok(res.size() == 3 and res[0].etq == "pesado" and res[1].etq == "lamina" and res[2].etq == "fogo", "resumo: ligados primeiro, mais cheios antes (%s)" % [res.map(func(l): return l.etq)])
	ok(Conjuntos.progresso_txt(res[0]) == "4/6" and Conjuntos.progresso_txt(res[2]) == "1/2", "progresso '4/6' e '1/2'")
	ok(Conjuntos.rotulo_carta("pendrive", {"lamina": 1}) == "Lâmina 1>2  Arremesso 0>1", "texto de carta: %s" % Conjuntos.rotulo_carta("pendrive", {"lamina": 1}))

	# --- dentro da partida: o atributo muda de verdade quando a build muda
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = true
	a.semente = 5
	add_child(a)
	await esperar(0.2)
	a.xp = -1.0e12   # sem carta de nível no meio do teste
	a.jogador.invencivel = 999.0
	a.armas.lista.clear()
	a.armas.adicionar("pendrive")
	var crit0: float = a.stat("critico")
	ok(a.conj_contagem.get("lamina", 0) == 1 and is_equal_approx(a.stat("critico"), crit0), "1 Lâmina na partida: sem bônus")
	a.armas.adicionar("lanca")   # 2 lâminas
	ok(a.conj_contagem.get("lamina", 0) == 2 and is_equal_approx(a.stat("critico") - crit0, 0.08), "2 Lâminas: +8%% de crítico na partida (%.3f)" % (a.stat("critico") - crit0))
	ok(not a.conj_resumo.is_empty() and a.conj_resumo[0].etq == "lamina", "o resumo do HUD acompanha")
	a.armas.trocar("lanca", "lanca_ardente")   # evolução também é lâmina (e fogo)
	ok(a.conj_contagem.get("lamina", 0) == 2 and a.conj_contagem.get("fogo", 0) == 1, "evoluir troca as etiquetas na hora (%s)" % [a.conj_contagem])
	var dano0: float = a.stat("dano")
	a.passivos["energetico"] = 1   # + Lâmina
	a.armas.adicionar("ventoinha")   # + Lâmina = 4
	ok(a.conj_contagem.get("lamina", 0) == 4 and is_equal_approx(a.stat("dano") - dano0, 0.25), "4 Lâminas: +15%% do conjunto +10%% da Pedra de Amolar (%.3f)" % (a.stat("dano") - dano0))
	a.armas.lista.clear()
	a.armas.adicionar("pendrive")   # volta a 1 + passivo = 2
	ok(a.conj_contagem.get("lamina", 0) == 2, "tirou armas: a contagem cai (%s)" % [a.conj_contagem])
	a.passivos.clear()
	a._recalcular()
	ok(is_equal_approx(a.stat("critico"), crit0) and a.stat("dano") <= dano0 + 0.0001, "sem os itens, o bônus desliga")

	# equipamento: o conjunto nomeado do Hazaki
	a.equipamentos = eq.duplicate()
	a._recalcular()
	ok(a.conj_contagem.get("guerreiro", 0) == 5 and a.conj("cura_abate") >= 1.0, "5 peças do Shogun ligam o efeito do conjunto")
	a.equipamentos = {"cabeca": "cabeca_guerreiro", "peitoral": "armadura_samurai", "rosto": "mascara_menpo"}
	a._recalcular()
	ok(a.conj_contagem.get("guerreiro", 0) == 3 and a.conj("cura_abate") == 0.0, "3 peças: só o primeiro degrau")
	a.equipamentos = {}
	a.armas.lista.clear()
	a.passivos.clear()

	# comportamentos: Sangue 4 cura no abate; Gelo 4 deixa lento; Fogo 6 explode
	for id in ["cabo_rede", "fibra_optica", "garras_dragao"]:
		a.armas.adicionar(id)
	a.passivos["agua_coco"] = 1
	a._recalcular()
	ok(a.conj_contagem.get("sangue", 0) == 4 and a.conj("cura_abate") == 0.5, "Sangue 4: cura no abate")
	a.jogador.hp = 50.0
	a._conj_ao_abater(Vector2.ZERO)
	ok(is_equal_approx(a.jogador.hp, 50.5), "o abate devolveu 0,5 de vida (%.2f)" % a.jogador.hp)
	a.armas.lista.clear()
	a.passivos.clear()
	for id in ["roteador_5g", "circulo_runico", "terremoto", "poder_elemental"]:
		a.armas.adicionar(id)
	ok(a.conj("lento_acerto") > 0.0, "Gelo 4 liga a lentidão")
	var jp: Vector2 = a.jogador.position
	var alvo = a.inimigos.criar("bug", jp + Vector2(300, 300), 1)
	alvo.hpmax = 1.0e6
	alvo.hp = 1.0e6
	a.inimigos.ferir(alvo, 1.0, Vector2.ZERO, "teste")
	ok(alvo.lento > 0.0, "o golpe deixou o inimigo lento")
	a.armas.lista.clear()
	a.armas.adicionar("pendrive")
	ok(a.conj("lento_acerto") == 0.0, "tirou o Gelo: sem lentidão")
	for id in ["cafe", "garrafa_termica", "machados_brasa", "lanca_ardente", "fibra_optica", "baforada"]:
		a.armas.adicionar(id)
	ok(a.conj("explosao_morte") == 1.0, "Fogo 6 liga a explosão (%s)" % [a.conj_contagem])
	var longe: Vector2 = jp + Vector2(-300, 200)
	var morre = a.inimigos.criar("bug", longe, 1)
	var vizinho = a.inimigos.criar("trojan", longe + Vector2(20, 0), 1)
	var outro = a.inimigos.criar("bug", longe + Vector2(-20, 10), 1)
	for v in [morre, vizinho, outro]:
		v.vel = 0.0
	vizinho.hpmax = 1.0e6
	vizinho.hp = 1.0e6
	a.inimigos.atualizar(0.016, a.jogador)   # reconstrói a grade espacial
	var hp_ant: float = vizinho.hp
	a.inimigos.ferir(morre, 1.0e6, Vector2.ZERO, "teste")
	ok(vizinho.hp < hp_ant, "quem morre explode e machuca o vizinho (%.0f -> %.0f)" % [hp_ant, vizinho.hp])
	ok(not a._conj_explodindo, "a explosão não fica presa")
	# gancho das cartas
	a.armas.lista.clear()
	a.passivos.clear()
	a.armas.adicionar("pendrive")
	var carta: Dictionary = a._carta("passivo", "energetico", 1)
	ok(carta.get("etiquetas", []) == ["lamina"] and str(carta.get("etiquetas_txt", "")) == "Lâmina 1>2", "carta de passivo traz as etiquetas e o 'depois' (%s)" % [carta.get("etiquetas_txt")])
	a.passivos["energetico"] = 1
	ok(str(a._carta("passivo", "energetico", 2).get("etiquetas_txt", "x")) == "", "subir nível do que já tem não muda a contagem")
	a.queue_free()
	print("CONJ falhas=", falhas)
	get_tree().quit()
