extends Node
# Teste automático: criação de personagem (#72, marco 1). Raças e classes em JSON, montagem do herói pelo id
# "c:raça:classe", registro na tabela de heróis (sobrevive ao recarregar) e uma partida com o herói criado.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/criacao.tscn  (imprime "CRIACAO falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Criacao := preload("res://scripts/hordas/criacao.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):   # sem o main.gd, ninguém registrou as teclas
			InputMap.add_action(acao)
	# --- os dados: 5 raças e 5 classes, tudo o que elas apontam existe
	var racas := Criacao.lista_racas()
	var classes := Criacao.lista_classes()
	ok(racas.size() == 5, "5 raças na primeira versão (%d)" % racas.size())
	ok(classes.size() >= 5, "pelo menos 5 classes (%d)" % classes.size())
	for rid in racas:
		var r: Dictionary = Criacao.racas().get(rid, {})
		ok(not r.is_empty() and r.has("nome") and r.has("curto"), "raça %s tem nome e nome curto" % rid)
		for k in r.get("bonus", {}).keys() + r.get("fraquezas", {}).keys():
			ok(Construcao.BASE.has(k), "raça %s: atributo %s existe em Construcao.BASE" % [rid, k])
		ok(Dados.tex_personagem(str(r.get("sprite", "")), "rosto") != null, "raça %s: o corpo tem rosto" % rid)
	for cid in classes:
		var c: Dictionary = Criacao.classes().get(cid, {})
		var arma := str(c.get("arma_inicial", ""))
		ok(not Dados.item(arma).is_empty(), "classe %s: a arma inicial %s existe" % [cid, arma])
		ok(not Construcao.exclusiva(arma), "classe %s: a arma inicial %s não é exclusiva de herói" % [cid, arma])
		ok(Dados.json("especiais").has(str(c.get("especial", ""))), "classe %s: o especial %s existe" % [cid, c.get("especial", "")])
		for k in c.get("bonus", {}):
			ok(Construcao.BASE.has(k), "classe %s: atributo %s existe em Construcao.BASE" % [cid, k])
	# --- o id diz como montar; id inválido não monta
	var id := Criacao.id_de("orc", "guerreiro")
	ok(id == "c:orc:guerreiro", "id do herói criado (%s)" % id)
	ok(Criacao.partes(id) == ["orc", "guerreiro"], "partes do id")
	for ruim in ["hazaki", "c:", "c:orc", "c:orc:guerreiro:x", "c:dragao:guerreiro", "c:orc:pizzaiolo"]:
		ok(not Criacao.valido(ruim) and not Criacao.registrar(ruim), "id inválido recusado (%s)" % ruim)
	# --- montagem: bônus da raça + fraquezas + bônus da classe somados
	var h := Criacao.montar("anao", "clerigo")
	ok(is_equal_approx(float(h.bonus.vida_max), 30.0 + 10.0), "anão clérigo: vida +40 (%s)" % h.bonus.get("vida_max"))
	ok(is_equal_approx(float(h.bonus.regen), 0.3 + 0.4), "anão clérigo: regen +0,7 (%s)" % h.bonus.get("regen"))
	ok(is_equal_approx(float(h.bonus.velocidade), -0.15), "anão clérigo: velocidade -15%% (%s)" % h.bonus.get("velocidade"))
	ok(str(h.arma) == "cafe" and str(h.especial) == "nicao" and is_equal_approx(float(h.reviver), 2.0), "anão clérigo: arma, especial e reviver da classe")
	ok(str(h.nome) == "Anão Clérigo", "nome do herói criado (%s)" % h.nome)
	var s := Construcao.stats(Criacao.montar("goblin", "ladino"), {}, {})
	ok(is_equal_approx(float(s.vida_max), 100.0 - 30.0 - 10.0), "goblin ladino: vida 60 na ficha (%s)" % s.vida_max)
	ok(is_equal_approx(float(s.critico), 0.05 + 0.1), "goblin ladino: crítico 15%% (%s)" % s.critico)
	# --- registro: entra na tabela de heróis e continua lá depois de recarregar
	ok(Criacao.registrar(id), "registra o orc guerreiro")
	ok(str(Dados.json("herois").get(id, {}).get("nome", "")) == "Orc Guerreiro", "herói criado na tabela de heróis")
	Dados.recarregar()
	ok(Dados.json("herois").has(id), "herói criado continua na tabela depois de recarregar")
	ok(Dados.json("herois").get("lista", []) == ["hazaki", "nicao", "lucas"], "a lista dos heróis fixos não muda")
	# --- textos da tela: recarga positiva é ruim e sai como "mais lentos"
	var linhas := Criacao.descrever({"recarga": 0.1, "dano": 0.2, "vida_max": -25})
	ok(linhas.has(["ataques 10% mais lentos", false]), "recarga +10%% sai como ataques mais lentos e ruim")
	ok(linhas.has(["+20% de dano", true]) and linhas.has(["-25 de vida", false]), "dano e vida descritos")
	# --- uma partida com o herói criado: arma da classe, especial da classe, tom da raça e a ficha da raça
	var a := Arena.new()
	a.heroi_id = id
	add_child(a)
	await esperar(0.3)
	ok(a.armas.achar("cabo_rede") != null, "orc guerreiro começa com a arma do guerreiro")
	ok(a.especial.tem(), "orc guerreiro tem o especial do guerreiro")
	ok(a.jogador.tom.is_equal_approx(Color(0.76, 1.0, 0.72)), "orc guerreiro: o corpo tem o tom da raça (%s)" % a.jogador.tom)
	ok(is_equal_approx(a.stat("dano"), 1.2), "orc guerreiro: +20%% de dano na partida (%s)" % a.stat("dano"))
	ok(is_equal_approx(a.stat("vida_max"), 125.0), "orc guerreiro: vida 125 na partida (%s)" % a.stat("vida_max"))
	a.queue_free()
	await esperar(0.1)
	# --- herói fixo continua igual (branco, sem especial de outro)
	var hz := Arena.new()
	hz.heroi_id = "hazaki"
	add_child(hz)
	await esperar(0.3)
	ok(hz.jogador.tom == Color.WHITE, "herói fixo continua sem tom")
	ok(hz.especial.tem() and str(hz.especial.d.get("nome", "")) == "Sou Gostoso!", "Hazaki continua com o especial dele")
	hz.queue_free()
	await esperar(0.1)
	# --- morte de vez (permadeath): num arquivo de teste, pra não mexer no herói salvo de verdade
	Criacao.arquivo = "user://teste_heroi_criado.json"
	Criacao.apagar()
	ok(str(Criacao.carregar().id) == "", "sem arquivo, sem herói salvo")
	Criacao.salvar(id)
	ok(str(Criacao.carregar().id) == id, "herói salvo volta ao abrir o jogo")
	Criacao.comecou(id)
	var r2 := Criacao.carregar(false)
	ok(str(r2.id) == id and str(r2.perdido) == "", "lendo sem matar (teste com o jogo aberto), o herói em corrida continua")
	var r3 := Criacao.carregar()
	ok(str(r3.id) == "" and str(r3.perdido) == id, "fechou o jogo no meio da corrida: o herói morreu")
	ok(not FileAccess.file_exists(Criacao.arquivo), "e o arquivo dele foi apagado")
	Criacao.salvar(id)
	Criacao.comecou(id)
	Criacao.sobreviveu(id)
	ok(str(Criacao.carregar().id) == id, "venceu a corrida: continua vivo")
	Criacao.comecou("c:goblin:mago")
	ok(str(Criacao.carregar().id) == id, "corrida de outro herói não marca o salvo")
	ok(Criacao.morreu_de_vez({"heroi": id, "vitoria": false}), "corrida perdida (morte ou desistência) mata o herói criado")
	ok(not Criacao.morreu_de_vez({"heroi": id, "vitoria": false, "duelo": {"lugar": 3}}), "perder o duelo final não mata")
	ok(not Criacao.morreu_de_vez({"heroi": id, "vitoria": true}), "vencer não mata")
	ok(not Criacao.morreu_de_vez({"heroi": "hazaki", "vitoria": false}), "herói fixo nunca morre de vez")
	Criacao.apagar()
	Criacao.arquivo = Criacao.ARQUIVO
	print("CRIACAO falhas=%d" % falhas)
	get_tree().quit()
