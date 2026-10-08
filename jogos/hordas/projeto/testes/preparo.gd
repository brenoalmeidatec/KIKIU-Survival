extends Node
# Teste automático: Preparo, mochila e baú pessoal (#72, marcos 3 e 4). Capacidade, comida, consumíveis, amuleto, trazer pra casa,
# morte apaga herói e baú, heróis antigos carregam (migração) e a rede recusa mochila inválida.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/preparo.tscn  (imprime "PREPARO falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Criacao := preload("res://scripts/hordas/criacao.gd")
const Mochila := preload("res://scripts/hordas/mochila.gd")
const TelaPreparo := preload("res://scripts/hordas/tela_preparo.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func ficha(nome: String, raca := "orc", classe := "guerreiro") -> Dictionary:
	var f := Criacao.ficha_nova(raca, classe)
	f["nome"] = nome
	return f


func uma_arena(id: String, m: Dictionary) -> Node:
	var a := Arena.new()
	a.heroi_id = id
	a.mochila_cfg = m
	add_child(a)
	return a


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar", "banir", "pular", "resortear",
			"consumivel1", "consumivel2", "consumivel3", "consumivel_usar", "consumivel_trocar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	Criacao.arquivo = "user://teste_preparo.json"
	Criacao.apagar()
	Dados.recarregar()

	# --- os dados: tudo o que eles apontam existe
	var cat: Dictionary = Dados.json("itens")
	ok(Mochila.lista().size() >= 10, "o catálogo tem itens (%d)" % Mochila.lista().size())
	var tipos := {"comida": 0, "consumivel": 0, "amuleto": 0}
	for id in Mochila.lista():
		var d := Mochila.item(id)
		ok(not d.is_empty() and d.has("nome") and d.has("descricao") and d.has("glifo"), "item %s tem nome, descrição e glifo" % id)
		ok(tipos.has(str(d.get("tipo", ""))), "item %s tem tipo válido" % id)
		tipos[str(d.get("tipo", ""))] = int(tipos.get(str(d.get("tipo", "")), 0)) + 1
		for k in d.get("bonus", {}):
			ok(Construcao_BASE().has(k), "item %s: %s existe em Construcao.BASE" % [id, k])
		for k in d.get("efeito", {}).get("bonus", {}):
			ok(Construcao_BASE().has(k), "item %s (efeito): %s existe em Construcao.BASE" % [id, k])
	ok(tipos.comida >= 3 and tipos.consumivel >= 4 and tipos.amuleto >= 3, "comida, consumíveis e amuletos em quantidade (%s)" % str(tipos))
	for id in Mochila.cfg().get("kit_inicial", {}):
		ok(not Mochila.item(id).is_empty(), "kit inicial: %s existe" % id)
	for id in Mochila.cfg().get("achados", []):
		ok(not Mochila.item(id).is_empty(), "achado: %s existe" % id)
	ok(cat.size() > 0, "itens.json carregou")

	# --- capacidade respeitada (espaços, tipos de consumível, comida)
	var cap := Mochila.capacidade("orc", "guerreiro")
	ok(cap == 6, "orc guerreiro: 5 + 1 + 0 = 6 espaços (%d)" % cap)
	ok(Mochila.capacidade("anao", "ladino") == 9, "anão ladino: 5 + 2 + 2 = 9")
	ok(Mochila.erro({"itens": {"bomba": 1, "pocao_cura": 2}, "amuleto": ""}, "orc", "guerreiro") == "", "4 espaços cabem")
	ok(Mochila.erro({"itens": {"bomba": 2, "pocao_cura": 3}, "amuleto": ""}, "orc", "guerreiro") != "", "7 espaços não cabem em 6")
	ok(Mochila.erro({"itens": {"bomba": 2, "pocao_cura": 3}, "amuleto": ""}, "anao", "ladino") == "", "os mesmos 7 espaços cabem num anão ladino (9)")
	ok(Mochila.erro({"itens": {"pao_duro": 1, "ensopado": 1, "carne_seca": 1}, "amuleto": ""}, "anao", "ladino") != "", "3 comidas passam do limite de 2")
	ok(Mochila.erro({"itens": {"pocao_cura": 1, "pocao_vigor": 1, "bomba": 1, "pergaminho_gelo": 1}, "amuleto": ""}, "anao", "ladino") != "", "4 tipos de consumível passam do limite de 3")
	ok(Mochila.erro({"itens": {"pocao_cura": 4}, "amuleto": ""}, "anao", "ladino") != "", "mais unidades que o máximo do item")
	ok(Mochila.erro({"itens": {"amuleto_corvo": 1}, "amuleto": ""}, "orc", "guerreiro") != "", "amuleto não vai nos itens")
	ok(Mochila.erro({"itens": {}, "amuleto": "pocao_cura"}, "orc", "guerreiro") != "", "poção não vai no pescoço")
	ok(Mochila.erro({"itens": {"pocao_cura": 1}, "amuleto": "amuleto_corvo"}, "orc", "guerreiro") == "", "amuleto não ocupa espaço da mochila")

	# --- a tela de Preparo respeita a capacidade (o que o jogador faz de verdade com as setas)
	var id := Criacao.salvar_ficha(ficha("Brutus"))
	ok(id != "", "salvou o herói")
	ok(Criacao.salvo(id), "o herói está salvo")
	var bau := Mochila.bau_limpo(Criacao.bau_de(id))
	ok(bau == Mochila.kit_inicial(), "herói novo começa com o kit inicial no baú")
	var t := TelaPreparo.new()
	t.heroi_id = id
	t.bau = bau.duplicate()
	t.mochila = {}
	add_child(t)
	await esperar(0.1)
	for i in 12:   # tenta encher a mochila com tudo do baú, item por item
		t._sel = i % t._itens.size()
		t._mudar(1)
		t._mudar(1)
	ok(Mochila.espacos(t.mochila) <= cap, "a tela nunca passou da capacidade (%d de %d)" % [Mochila.espacos(t.mochila), cap])
	ok(Mochila.erro(t.mochila, "orc", "guerreiro") == "", "a mochila montada na tela vale (%s)" % str(t.mochila))
	ok(Mochila.espacos(t.mochila) > 0, "a tela deixou levar alguma coisa")
	var antes := t.mochila.duplicate(true)
	t._sel = t._itens.find("bomba")
	for i in 6:
		t._mudar(1)
	ok(Mochila.espacos(t.mochila) <= cap and int(t.mochila.itens.get("bomba", 0)) <= 2, "bomba: no máximo 2 e dentro dos espaços")
	t._sel = t._itens.find("amuleto_ferro")
	t._mudar(1)
	ok(t.mochila.amuleto == "amuleto_ferro", "amuleto escolhido")
	t._sel = t._itens.find("amuleto_corvo")
	t._mudar(1)
	ok(t.mochila.amuleto == "amuleto_corvo", "trocar o amuleto: só 1 no pescoço")
	t._mudar(-1)
	ok(t.mochila.amuleto == "", "tirar o amuleto")
	t._sel = t._itens.find("pocao_cura")
	for i in 5:
		t._mudar(1)
	ok(int(t.mochila.itens.get("pocao_cura", 0)) <= 2, "só leva o que tem no baú (2 poções)")
	ok(antes.size() > 0, "mochila anterior guardada")
	t.queue_free()

	# --- comida e amuleto aplicam efeito na partida
	Criacao.registrar_ficha(id, ficha("Brutus"))
	var sem := uma_arena(id, {})
	await esperar(0.4)
	ok(sem.provisoes == null, "sem mochila, nenhum nó de provisões (corrida igual à de antes)")
	var vida0: float = sem.stat("vida_max")
	var crit0: float = sem.stat("critico")
	var dano0: float = sem.stat("dano")
	sem.queue_free()
	await esperar(0.1)
	var com := uma_arena(id, {"itens": {"ensopado": 1, "carne_seca": 1}, "amuleto": "amuleto_corvo"})
	await esperar(0.4)
	ok(com.provisoes != null, "com mochila, as provisões existem")
	ok(is_equal_approx(com.stat("vida_max"), vida0 + 30.0), "ensopado: +30 de vida máxima (%s -> %s)" % [vida0, com.stat("vida_max")])
	ok(is_equal_approx(com.stat("dano"), dano0 + 0.12), "carne seca: +12%% de dano")
	ok(is_equal_approx(com.stat("critico"), crit0 + 0.1), "amuleto do corvo: +10%% de crítico")
	ok(is_equal_approx(com.jogador.hp, com.stat("vida_max")), "começa com a vida cheia, já com a comida")
	com.diretor.fase_idx = 6   # o ensopado vale por 7 andares, a carne seca por 6
	com.provisoes._recalcular()
	ok(is_equal_approx(com.stat("vida_max"), vida0 + 30.0), "andar 7: o ensopado ainda vale")
	ok(is_equal_approx(com.stat("dano"), dano0), "andar 7: a carne seca já acabou")
	com.diretor.fase_idx = 7
	com.provisoes._recalcular()
	ok(is_equal_approx(com.stat("vida_max"), vida0), "andar 8: nenhuma comida vale mais")
	ok(is_equal_approx(com.stat("critico"), crit0 + 0.1), "o amuleto vale a corrida toda")
	com.queue_free()
	await esperar(0.1)

	# --- consumível usa e some
	var cons := uma_arena(id, {"itens": {"pocao_cura": 2, "pocao_vigor": 1, "bomba": 1, "elixir_ferro": 1}, "amuleto": "amuleto_fenix"})
	await esperar(0.4)
	var p = cons.provisoes
	ok(p.slots == ["pocao_cura", "pocao_vigor", "elixir_ferro", "bomba"], "slots na ordem do catálogo (%s)" % str(p.slots))
	var vmax: float = cons.stat("vida_max")
	cons.jogador.hp = 10.0
	p.consumir("pocao_cura")
	ok(is_equal_approx(cons.jogador.hp, 10.0 + vmax * 0.45), "poção de cura devolve 45%% da vida (%s)" % cons.jogador.hp)
	ok(int(p.restantes.pocao_cura) == 1, "uma poção a menos")
	p.consumir("pocao_cura")
	ok(int(p.restantes.pocao_cura) == 0, "a segunda também gasta")
	var hp_antes: float = cons.jogador.hp
	p.consumir("pocao_cura")
	ok(int(p.restantes.pocao_cura) == 0 and is_equal_approx(cons.jogador.hp, hp_antes), "acabou: usar de novo não faz nada")
	ok(not p.pode(p.slots.find("pocao_cura")), "pode() recusa o que acabou")
	var d0: float = cons.stat("dano")
	p.consumir("pocao_vigor")
	ok(is_equal_approx(cons.stat("dano"), d0 + 0.25), "poção de vigor: +25%% de dano por um tempo")
	p.atualizar(16.0)
	ok(is_equal_approx(cons.stat("dano"), d0), "o vigor acaba depois de 15 s")
	cons.jogador.invencivel = 0.0
	p.consumir("elixir_ferro")
	ok(cons.jogador.invencivel >= 3.4, "elixir de ferro: invencível")
	# bomba: acerta bicho perto e empurra
	var tipo_inim := ""
	for k in Dados.json("inimigos"):
		if not k.begins_with("_") and Dados.json("inimigos")[k] is Dictionary and not Dados.json("inimigos")[k].get("chefe", false):
			tipo_inim = k
			break
	var v = cons.inimigos.criar(tipo_inim, cons.jogador.position + Vector2(40, 0))
	await esperar(0.2)   # o bicho entra na grade de busca no próximo quadro
	var hp_v: float = v.hp
	p.consumir("bomba")
	ok(v.hp < hp_v or v.hp <= 0.0, "bomba machuca o bicho perto (%s -> %s)" % [hp_v, v.hp])
	ok(int(p.restantes.bomba) == 0, "a bomba some")
	var u: Dictionary = p.sobra()
	ok(u.itens.is_empty() and u.amuleto == "amuleto_fenix", "tudo usado: a sobra só tem o amuleto (%s)" % str(u))
	# fênix: levanta uma vez
	cons.jogador.hp = 0.0
	ok(p.fenix(), "Pena de Fênix levanta uma vez")
	ok(cons.jogador.hp >= vmax * 0.4 - 1.0, "com 40%% da vida (%s)" % cons.jogador.hp)
	ok(not p.fenix(), "só uma vez por corrida")
	cons.queue_free()
	await esperar(0.1)

	# --- trazer pra casa: o que sobra e o que achou vai pro baú; o que não cabe se perde
	var b0 := {"pocao_cura": 1}
	var r := Mochila.trazer(b0, {"itens": {"bomba": 1, "pocao_vigor": 1}, "amuleto": "amuleto_corvo"}, ["carne_seca", "pao_duro"])
	ok(r.bau.get("bomba", 0) == 1 and r.bau.get("amuleto_corvo", 0) == 1 and r.bau.get("carne_seca", 0) == 1 and r.bau.get("pocao_cura", 0) == 1, "sobra e achados foram pro baú (%s)" % str(r.bau))
	ok(r.perdidos.is_empty(), "coube tudo")
	var cheio := {}
	for k in ["pocao_cura", "pocao_vigor", "pergaminho_ima", "elixir_ferro", "pao_duro", "ensopado", "carne_seca", "queijo_forte", "hidromel", "amuleto_corvo", "amuleto_ferro", "amuleto_trevo"]:
		cheio[k] = 2
	ok(Mochila.bau_espacos(cheio) == 24, "baú cheio: 24 espaços (%d)" % Mochila.bau_espacos(cheio))
	var r2 := Mochila.trazer(cheio, {"itens": {"bomba": 2}, "amuleto": ""}, ["pocao_cura"])
	ok(Mochila.bau_espacos(r2.bau) <= Mochila.bau_max(), "o baú nunca passa do limite (%d)" % Mochila.bau_espacos(r2.bau))
	ok(not r2.perdidos.is_empty() and r2.trazidos.is_empty(), "sem lugar: o que sobrou se perdeu (%s)" % str(r2.perdidos))
	var achados_demais := ["pocao_cura", "pocao_cura", "pocao_cura", "pocao_cura", "pocao_cura"]
	var r3 := Mochila.trazer({}, vazia(), achados_demais)
	ok(int(r3.bau.get("pocao_cura", 0)) == int(Mochila.cfg().trazer_max), "só traz %d achados" % int(Mochila.cfg().trazer_max))
	# o ciclo completo no arquivo: retirar ao sair, devolver ao vencer
	var bau_h := Mochila.bau_limpo(Criacao.bau_de(id))
	var m := {"itens": {"pocao_cura": 2, "bomba": 1}, "amuleto": "amuleto_corvo"}
	ok(Mochila.cabe_no_bau(bau_h, m), "o baú tem o que a mochila leva")
	Criacao.definir_bau(id, Mochila.retirar(bau_h, m))
	var fora := Mochila.bau_limpo(Criacao.bau_de(id))
	ok(int(fora.get("pocao_cura", 0)) == 0 and int(fora.get("bomba", 0)) == 0 and int(fora.get("amuleto_corvo", 0)) == 0, "saiu da casa: o baú perdeu o que foi na mochila (%s)" % str(fora))
	ok(int(fora.get("pao_duro", 0)) == 1, "o que ficou em casa continua lá")
	var vol := Mochila.trazer(fora, {"itens": {"pocao_cura": 1}, "amuleto": "amuleto_corvo"}, [])
	Criacao.definir_bau(id, vol.bau)
	var depois := Mochila.bau_limpo(Criacao.bau_de(id))
	ok(int(depois.get("pocao_cura", 0)) == 1 and int(depois.get("amuleto_corvo", 0)) == 1 and int(depois.get("bomba", 0)) == 0, "venceu: voltou a poção que sobrou e o amuleto; a bomba usada ficou pelo caminho")
	ok(Mochila.cabe_no_bau(depois, {"itens": {"pocao_cura": 1}, "amuleto": ""}) and not Mochila.cabe_no_bau(depois, {"itens": {"pocao_cura": 2}, "amuleto": ""}), "cabe_no_bau confere as quantidades")
	var aj := Mochila.ajustar_ao_bau({"itens": {"pocao_cura": 3, "bomba": 2}, "amuleto": "amuleto_fenix"}, depois, id)
	ok(aj.itens == {"pocao_cura": 1} and aj.amuleto == "", "ajustar à casa: só leva o que há no baú (%s)" % str(aj))

	# --- a mochila guardada no herói (a última que montou)
	Criacao.definir_mochila(id, m)
	ok(Criacao.mochila_de(id).get("amuleto") == "amuleto_corvo", "a última mochila fica guardada no herói")

	# --- morte: herói, mochila e baú somem juntos
	var outro := Criacao.salvar_ficha(ficha("Lyra", "elfo_sombrio", "mago"))
	ok(outro != "" and Criacao.bau_de(outro).size() > 0, "um segundo herói tem o próprio baú")
	Criacao.definir_bau(outro, {"bomba": 1})
	Criacao.definir_mochila(outro, m)
	ok(Criacao.morreu_de_vez({"heroi": outro, "vitoria": false}), "derrota de herói criado = morte de vez")
	ok(not Criacao.morreu_de_vez({"heroi": outro, "vitoria": true}), "vitória não mata")
	Criacao.apagar(outro)
	ok(not Criacao.salvo(outro), "o herói morto saiu do arquivo")
	ok(Criacao.bau_de(outro).is_empty() and Criacao.mochila_de(outro).is_empty(), "o baú e a mochila dele sumiram junto")
	ok(Criacao.salvo(id) and not Criacao.bau_de(id).is_empty(), "o outro herói não foi tocado")
	Criacao.apagar()
	ok(Criacao.bau_de(id).is_empty(), "sem arquivo, sem baú")

	# --- heróis antigos carregam (migração): sem "bau" ganham o kit inicial e continuam funcionando
	var fa := Criacao.validar_ficha(ficha("Velho"))
	var f := FileAccess.open(Criacao.arquivo, FileAccess.WRITE)
	f.store_string(JSON.stringify({"herois": [{"id": "c:hab1", "ficha": fa, "em_corrida": false}, {"id": "c:orc:guerreiro", "em_corrida": false}]}))
	f.close()
	var cr := Criacao.carregar(false)
	ok(cr.ids.size() == 2 and "c:hab1" in cr.ids, "heróis salvos antes do marco 3 carregam (%s)" % str(cr.ids))
	ok(Mochila.bau_limpo(Criacao.bau_de("c:hab1")) == Mochila.kit_inicial(), "herói antigo ganha o kit inicial")
	ok(Mochila.bau_limpo(Criacao.bau_de("c:orc:guerreiro")) == Mochila.kit_inicial(), "herói do marco 1 também")
	ok(Criacao.mochila_de("c:hab1").is_empty(), "e começa sem mochila guardada")
	var tx := FileAccess.get_file_as_string(Criacao.arquivo)
	ok(tx.contains("\"bau\""), "o baú migrado foi gravado no arquivo")
	var f2 := FileAccess.open(Criacao.arquivo, FileAccess.WRITE)
	f2.store_string(JSON.stringify({"id": "c:elfo_sombrio:mago"}))   # o formato do marco 1: um herói só
	f2.close()
	ok(Criacao.carregar(false).ids == ["c:elfo_sombrio:mago"], "o arquivo do marco 1 (um herói) carrega")
	ok(not Criacao.bau_de("c:elfo_sombrio:mago").is_empty(), "e tem baú")
	Criacao.apagar()

	# --- a rede recusa mochila inválida (o anfitrião confere tudo contra os JSON)
	var fo := ficha("Brutus")
	var hid := "c:h1234"
	ok(Rede.erro_mochila({"itens": {"bomba": 1, "pocao_cura": 2}, "amuleto": "amuleto_corvo"}, hid, fo) == "", "mochila válida passa")
	ok(Rede.erro_mochila({}, "hazaki", {}) == "", "sem mochila passa pra qualquer herói")
	ok(Rede.erro_mochila({"itens": {"pocao_cura": 1}, "amuleto": ""}, "hazaki", {}) != "", "herói fixo não leva mochila")
	ok(Rede.erro_mochila({"itens": {"bomba": 2, "pocao_cura": 3}, "amuleto": ""}, hid, fo) != "", "mochila maior que o espaço do herói é recusada")
	ok(Rede.erro_mochila({"itens": {"item_inventado": 1}, "amuleto": ""}, hid, fo) != "", "item que não existe é recusado")
	ok(Rede.erro_mochila({"itens": {"pocao_cura": 99}, "amuleto": ""}, hid, fo) != "", "quantidade exagerada é recusada")
	ok(Rede.erro_mochila({"itens": {"pocao_cura": -1}, "amuleto": ""}, hid, fo) != "", "quantidade negativa é recusada")
	ok(Rede.erro_mochila({"itens": {"pocao_cura": 1.5}, "amuleto": ""}, hid, fo) != "", "quantidade quebrada é recusada")
	ok(Rede.erro_mochila({"itens": {"pocao_cura": "2"}, "amuleto": ""}, hid, fo) != "", "quantidade em texto é recusada")
	ok(Rede.erro_mochila({"itens": [], "amuleto": ""}, hid, fo) != "", "itens que não são um dicionário são recusados")
	ok(Rede.erro_mochila({"itens": {}, "amuleto": "amuleto_inventado"}, hid, fo) != "", "amuleto que não existe é recusado")
	ok(Rede.erro_mochila({"itens": {}, "amuleto": 5}, hid, fo) != "", "amuleto de outro tipo é recusado")
	ok(Rede.erro_mochila({"itens": {}, "amuleto": "amuleto_corvo", "extra": 1}, hid, fo) != "", "campo desconhecido é recusado")
	ok(Rede.erro_mochila("mochila", hid, fo) != "", "mochila que não é dicionário é recusada")
	ok(Rede.erro_mochila({"itens": {"pocao_cura": 2.0}, "amuleto": ""}, hid, fo) == "", "2.0 vindo do JSON/rede vale como 2")
	ok(Mochila.limpar({"itens": {"pocao_cura": 2.0}, "amuleto": ""}, "orc", "guerreiro") == {"itens": {"pocao_cura": 2}, "amuleto": ""}, "limpar converte pra inteiro")
	ok(Mochila.limpar({"itens": {"bomba": 5}, "amuleto": ""}, "orc", "guerreiro").is_empty(), "limpar devolve {} pra mochila inválida")
	# e o teste de uso no anfitrião: só conta o que foi declarado (o cálculo que o online.gd faz)
	var declarada := {"itens": {"pocao_cura": 2, "bomba": 1}, "amuleto": ""}
	ok(Mochila.slots(declarada) == ["pocao_cura", "bomba"], "os slots que cliente e anfitrião calculam são os mesmos (%s)" % str(Mochila.slots(declarada)))
	ok(Mochila.de_texto("pocao_cura:2,bomba,amuleto_corvo,pao_duro") == {"itens": {"pocao_cura": 2, "bomba": 1, "pao_duro": 1}, "amuleto": "amuleto_corvo"}, "--mochila= vira mochila")
	Criacao.apagar()
	Criacao.arquivo = Criacao.ARQUIVO
	print("PREPARO falhas=%d" % falhas)
	get_tree().quit()


func vazia() -> Dictionary:
	return Mochila.vazia()


func Construcao_BASE() -> Dictionary:
	return preload("res://scripts/hordas/construcao.gd").BASE
