extends Node
# Teste automático: mapa de progressão entre as fases (#32 item 8).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/mapa.tscn  (imprime "MAPA falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Mapa := preload("res://scripts/hordas/mapa.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func nova(semente: int) -> Node:
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = true
	a.semente = semente
	add_child(a)
	await esperar(0.2)
	a.xp = -1.0e12   # sem subir de nível: o robô escolheria carta e mudaria a build no meio do teste
	return a


func gerar(semente: int) -> Dictionary:
	Sorte.iniciar(semente)
	return Mapa.gerar()


## Espera (tempo real) até a condição valer. false = estourou o limite.
func ate(cond: Callable, limite: float) -> bool:
	var t := 0.0
	while not cond.call() and t < limite:
		await esperar(0.1)
		t += 0.1
	return cond.call()


func _ready() -> void:
	var c: Dictionary = Mapa.cfg()
	var andares := int(c.andares)

	# --- mesma semente = mesmo mapa; semente diferente = (quase sempre) outro
	ok(gerar(7).hash() == gerar(7).hash() and Mapa.resumo(gerar(7)) == Mapa.resumo(gerar(7)), "mesma semente dá o mesmo mapa")
	var distintos := {}
	for s in range(1, 21):
		distintos[Mapa.resumo(gerar(s))] = true
	ok(distintos.size() >= 15, "sementes diferentes dão mapas diferentes (%d de 20)" % distintos.size())

	# --- 300 sementes: estrutura e regras
	var tipos_vistos := {}
	var max_iniciais := 0
	for s in range(1, 301):
		var m := gerar(s)
		var e := Mapa.erros(m)
		ok(e.is_empty(), "semente %d: mapa válido (%s)" % [s, e.slice(0, 2)])
		var nos := Mapa.todos(m)
		var cont := {}
		for n in nos:
			tipos_vistos[str(n.tipo)] = true
			cont[str(n.tipo)] = int(cont.get(str(n.tipo), 0)) + 1
			var andar := int(n.andar) + 1
			var r: Dictionary = c.regras.get(str(n.tipo), {})
			ok(andar >= int(r.get("andar_min", 1)) and andar <= int(r.get("andar_max", 999)) or str(n.tipo) in ["fase", "chefe"], "semente %d: %s no andar %d fora das regras" % [s, n.tipo, andar])
			for p in n.prox:
				var filho := Mapa.no(m, int(n.andar) + 1, int(p))
				ok(not (str(n.tipo) in ["descanso", "loja"] and str(filho.tipo) in ["descanso", "loja"]), "semente %d: descanso/loja seguidos (andar %d)" % [s, andar])
		for t in c.regras:
			ok(int(cont.get(t, 0)) <= int(c.regras[t].get("max_por_mapa", 9999)), "semente %d: limite de %s" % [s, t])
		var a1 := nos.filter(func(n): return int(n.andar) == 0)
		max_iniciais = maxi(max_iniciais, a1.size())
		ok(a1.size() >= 2 and a1.all(func(n): return str(n.tipo) == "fase" and Mapa.alcanca_chefe(m, 0, int(n.faixa))), "semente %d: andar 1 com 2+ nós de fase que chegam ao chefe" % s)
		ok(nos.filter(func(n): return int(n.andar) == andares - 1).size() == 1, "semente %d: um chefe só no último andar" % s)
		ok(Mapa.inicio(m) >= 0 and not Mapa.no(m, 0, Mapa.inicio(m)).is_empty(), "semente %d: início é um nó do andar 1" % s)
	for t in ["fase", "elite", "descanso", "loja", "evento", "santuario", "chefe"]:
		ok(tipos_vistos.has(t), "tipo %s aparece em algum mapa" % t)

	# --- caminhos sem cruzar: o detector pega um cruzamento fabricado
	var m2 := gerar(3)
	ok(Mapa._cruza([[0, 1]], 1, 0) and not Mapa._cruza([[0, 1]], 1, 2) and not Mapa._cruza([[0, 0]], 1, 1), "detector de cruzamento")
	m2.nos[0][0] = Mapa._no(0, 0, "fase")
	m2.nos[0][1] = Mapa._no(0, 1, "fase")
	m2.nos[0][0].prox = [1]
	m2.nos[0][1].prox = [0]
	ok(Mapa.erros(m2).any(func(x): return str(x).begins_with("cruzamento")), "mapa com cruzamento é reprovado")

	# --- limite de tentativas: regras impossíveis não travam, viram "fase"
	var m3 := gerar(5)
	var pesos_ruins := {"descanso": 1.0}
	var no_x: Dictionary = Mapa.todos(m3).filter(func(n): return int(n.andar) == 1)[0]
	var cfg_ruim := {"tentativas": 20, "regras": {"descanso": {"andar_min": 99}}}
	ok(Mapa._tipo_valido(m3, Sorte.criar("teste_tent"), cfg_ruim, no_x, ["descanso"], pesos_ruins, {}) == "fase", "regra impossível cai em 'fase' sem travar")

	# --- votação online: maioria, empate = anfitrião, sem voto = primeira opção
	ok(Mapa.resolver_votos({1: 2, 2: 3, 3: 3}, 1, [2, 3]) == 3, "maioria vence")
	ok(Mapa.resolver_votos({1: 2, 2: 3}, 1, [2, 3]) == 2, "empate: vale o voto do anfitrião")
	ok(Mapa.resolver_votos({2: 3, 3: 2}, 1, [2, 3]) == 2, "empate sem voto do anfitrião: a menor faixa")
	ok(Mapa.resolver_votos({}, 1, [1, 2]) == 1, "ninguém votou: primeira opção")
	ok(Mapa.resolver_votos({1: 9, 2: 7}, 1, [1, 2]) == 1, "voto fora das opções é ignorado")
	ok(Mapa.resolver_votos({1: 0}, 1, []) == -1, "sem opções: -1")

	# --- no jogo: o mapa vem da semente e é igual em duas partidas
	var a := await nova(7)
	var b := await nova(7)
	ok(Mapa.resumo(a.mapa) == Mapa.resumo(b.mapa) and Mapa.resumo(a.mapa) == Mapa.resumo(gerar(7)), "arena: mesma semente, mesmo mapa")
	ok(a.mapa_pos.x == 0 and a.mapa_trilha.size() == 1, "começa no andar 1")
	b.queue_free()

	# --- ouro: abate, elite e chefe somam
	var o0: int = a.ouro
	a.recompensa(Vector2(500, 500), "bug", false)
	ok(a.ouro == o0 + 1, "abate dá 1 de ouro (%d)" % (a.ouro - o0))
	o0 = a.ouro
	a.recompensa(Vector2(500, 500), "bug", true)
	ok(a.ouro == o0 + 4, "elite dá 4")
	o0 = a.ouro
	a.recompensa(Vector2(500, 500), "trojan_gigante", false)
	ok(a.ouro == o0 + 40, "chefe dá 40")

	# --- cada tipo de nó resolve com o robô (força o próximo nó a ter o tipo)
	for tipo in ["descanso", "loja", "evento", "santuario"]:
		a.entre_fases = true
		a.inimigos.limpar()
		var ac: Array = a.mapa_acessiveis()
		var f: int = ac[0]
		for x in ac:   # todas as opções viram o tipo testado (o robô escolhe a que quiser)
			a.mapa.nos[a.mapa_pos.x + 1][x].tipo = tipo
		a.ouro = 1000
		a.jogador.hp = 10.0
		var itens0: int = a.armas.lista.size() + a.passivos.size() + a.descobertas.dadivas.size()
		var andar0: int = a.mapa_pos.x
		a.abrir_mapa()
		ok(a.tela_mapa.aberto(), "%s: o mapa abre" % tipo)
		var chegou: bool = await ate(func(): return a.tela_mapa.aberto() and a.mapa_pos.x == andar0 + 1, 30.0)
		ok(chegou, "%s: o robô resolveu o nó e voltou ao mapa/seguiu (andar %d)" % [tipo, a.mapa_pos.x])
		ok(a.mapa_trilha.size() > andar0 + 1 and a.mapa_trilha[andar0 + 1].x == andar0 + 1 and a.no_tipo == tipo, "%s: o nó entrou na trilha" % tipo)
		match tipo:
			"descanso":
				ok(a.jogador.hp >= a.stat("vida_max") - 0.01 or a.jogador.hp > 10.0, "descanso recupera a vida (%s)" % a.jogador.hp)
			"loja":
				ok(a.ouro < 1000, "loja: o robô gastou ouro (%d)" % a.ouro)
			_:
				var itens1: int = a.armas.lista.size() + a.passivos.size() + a.descobertas.dadivas.size()
				ok(itens1 > itens0 or a.fase_stat.itens.size() > 0 or a.jogador.hp < 10.0 or tipo == "evento", "%s: deu alguma coisa" % tipo)
		a.tela_mapa.fechar()
		a.loja.fechar()
		a.entre_fases = true
	a.queue_free()

	# --- nó elite: dificuldade e recompensa
	var e := await nova(11)
	e.entre_fases = true
	e.mapa.nos[1][e.mapa_acessiveis()[0]].tipo = "elite"
	e.escolher_no(e.mapa_acessiveis()[0])
	await esperar(0.1)
	ok(e.no_tipo == "elite" and not e.entre_fases and e.diretor.fase_idx == 1, "elite: começa a fase do andar 2")
	ok(is_equal_approx(e.diretor.bonus_minutos, 1.5) and e.diretor.xp_mult == 1.5 and e.diretor.mult_elite == 3.0, "elite: dificuldade e XP a mais")
	e.entre_fases = true
	e.escolher_no(e.mapa_acessiveis()[0])
	await esperar(0.1)
	ok(e.diretor.bonus_minutos == 0.0 and e.diretor.xp_mult == 1.0, "fase normal zera o bônus da elite")
	e.queue_free()

	# --- o robô atravessa a corrida inteira pelo mapa, andar por andar, até o chefe final
	var r := await nova(21)
	var visitados := []
	r.entre_fases = true
	r.abrir_mapa()
	var t := 0.0
	while r.mapa_pos.x < andares - 1 and t < 120.0:
		await esperar(0.1)
		t += 0.1
		if not r.entre_fases and not r.tela_mapa.aberto():   # entrou numa fase de combate: dá por vencida
			visitados.append(r.no_tipo)
			ok(r.diretor.fase_idx == r.mapa_pos.x, "a fase em jogo é a do andar (%d x %d)" % [r.diretor.fase_idx, r.mapa_pos.x])
			r.inimigos.limpar()
			r.entre_fases = true
			if r.mapa_pos.x < andares - 1:
				r.abrir_mapa()
	ok(r.mapa_pos.x == andares - 1, "o robô chegou ao andar do chefe pelo mapa (andar %d em %.0f s)" % [r.mapa_pos.x + 1, t])
	await esperar(0.2)
	ok(r.no_tipo == "chefe" and r.diretor.fase_idx == andares - 1, "o último nó é o chefe e a fase do andar 10 começou (%s, fase %d)" % [r.no_tipo, r.diretor.fase_idx + 1])
	ok(r.mapa_trilha.size() == andares and r.mapa_trilha[andares - 1].x == andares - 1, "trilha com um nó por andar (%d)" % r.mapa_trilha.size())
	var ult: Dictionary = r.diretor.fases()[andares - 1] if r.diretor.fases().size() >= andares else {}
	ok(Dados.json("inimigos").get(str(ult.get("chefe", "")), {}).get("final", false), "o último andar é o chefe final (depois vem o duelo)")
	r.queue_free()

	print("MAPA falhas=", falhas)
	get_tree().quit()
