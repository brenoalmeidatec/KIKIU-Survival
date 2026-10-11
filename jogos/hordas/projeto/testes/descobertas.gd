extends Node
# Teste automático: descobertas do mundo (#21): sorte controlada, santuários, fragmentos, dádivas e eventos.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/descobertas.tscn  (imprime "DESCOB falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
const Descobertas := preload("res://scripts/hordas/descobertas.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func plano(semente: int, n_fases := 10) -> Array:
	Sorte.iniciar(semente)
	var res := []
	for f in n_fases:
		res.append(Descobertas.planejar_fase(f, n_fases, 3, Vector2.ZERO))
	return res


func sequencia_eventos(semente: int, n: int, fase := 5) -> Array:
	Sorte.iniciar(semente)
	var rng := Sorte.fluxo("evento")
	var cd := {}
	var hist := []
	var res := []
	for i in n:
		var id := Descobertas.escolher_evento(rng, fase, cd, hist)
		res.append(id)
		hist.append(id)
		if hist.size() > 3:
			hist.pop_front()
	return res


func _ready() -> void:
	# --- streams: mesma semente, mesma sequência; independentes entre si ---
	Sorte.iniciar(7)
	var a1 := [Sorte.fluxo("x").randf(), Sorte.fluxo("x").randf(), Sorte.fluxo("y").randi()]
	Sorte.iniciar(7)
	var a2 := [Sorte.fluxo("x").randf(), Sorte.fluxo("x").randf(), Sorte.fluxo("y").randi()]
	Sorte.iniciar(8)
	var a3 := [Sorte.fluxo("x").randf(), Sorte.fluxo("x").randf(), Sorte.fluxo("y").randi()]
	ok(a1 == a2, "mesma semente, mesmos números")
	ok(a1 != a3, "semente diferente, números diferentes")
	Sorte.iniciar(7)
	Sorte.fluxo("y").randi()  # mexer em outra stream não desloca a "x"
	ok(Sorte.fluxo("x").randf() == a1[0], "streams independentes")
	var emb1 := Sorte.embaralhar(Sorte.criar("e"), range(20))
	var emb2 := Sorte.embaralhar(Sorte.criar("e"), range(20))
	var ordenado := emb1.duplicate()
	ordenado.sort()
	ok(emb1 == emb2 and ordenado == range(20) and emb1 != range(20), "Fisher-Yates semeado: permutação igual e completa")
	var peso := Sorte.criar("p")
	var viu := {}
	for i in 300:
		viu[Sorte.ponderado(peso, [0.0, 1.0, 3.0])] = true
	ok(not viu.has(0) and viu.has(1) and viu.has(2), "ponderado: peso 0 nunca sai")
	# shuffle bag: em cada 4 tiradas saem os 4 itens, sem repetir
	Sorte.iniciar(3)
	for rodada in 5:
		var tirou := []
		for i in 4:
			tirou.append(Sorte.saco("t", ["a", "b", "c", "d"]))
		tirou.sort()
		ok(tirou == ["a", "b", "c", "d"], "shuffle bag esvazia e enche (rodada %d)" % rodada)
	# --- pity: garante em até "limite" tentativas, qualquer semente ---
	var pior := 0
	var acertos := 0
	var tentativas := 0
	for sem in 40:
		Sorte.iniciar(sem)
		var seq := 0
		for i in 400:
			seq += 1
			tentativas += 1
			if Sorte.pity("t", 0.05, 0.05, 12):
				acertos += 1
				pior = maxi(pior, seq)
				seq = 0
		pior = maxi(pior, seq)
	ok(pior <= 12, "pity: nunca passa de 12 tentativas sem acertar (pior = %d)" % pior)
	var taxa := float(acertos) / float(tentativas)
	ok(taxa > 0.10 and taxa < 0.30, "pity: taxa média plausível (%.3f)" % taxa)
	Sorte.iniciar(1)
	var n_zero := 0
	for i in 5:
		n_zero += 1
		if Sorte.pity("z", 0.0, 0.0, 5):
			break
	ok(n_zero == 5, "pity com chance 0 acerta exatamente na tentativa do limite (%d)" % n_zero)
	# --- santuários e plano do mundo ---
	var p42 := plano(42)
	ok(JSON.stringify(p42) == JSON.stringify(plano(42)), "mesma semente: mesmos santuários (posição, tipo, variação)")
	ok(JSON.stringify(p42) != JSON.stringify(plano(43)), "semente diferente: santuários diferentes")
	var contagens := {}
	var dist_ruim := false
	var longe_ruim := false
	for sem in 150:
		var pl := plano(sem)
		var n := 0
		for fase in pl:
			var especiais: Array = fase.filter(func(s): return s.tipo != "tomada")
			for i in especiais.size():
				if especiais[i].pos.length() < 380.0:
					longe_ruim = true
				for j in range(i + 1, especiais.size()):
					if especiais[i].pos.distance_to(especiais[j].pos) < 419.0:
						dist_ruim = true
			n += fase.filter(func(s): return s.tipo == "fragmento").size()
		contagens[n] = int(contagens.get(n, 0)) + 1
	ok(contagens.keys().all(func(k): return k >= 0 and k <= 3), "0 a 3 santuários do dragão por corrida (%s)" % [contagens])
	ok(contagens.size() == 4, "todas as quantidades 0, 1, 2 e 3 aparecem entre as sementes (%s)" % [contagens])
	ok(contagens.get(0, 0) > 0, "há corridas sem santuário do dragão (intencional, seção 17)")
	ok(not dist_ruim, "distância mínima entre santuários especiais")
	ok(not longe_ruim, "nenhum especial colado na âncora")
	var variacoes := {}
	for sem in 60:
		for fase in plano(sem):
			for s in fase:
				if s.tipo == "fragmento":
					variacoes[s.variacao] = true
	ok(variacoes.size() >= 2, "variações do santuário aparecem (%s)" % [variacoes.keys()])
	# --- eventos ---
	ok(sequencia_eventos(5, 30) == sequencia_eventos(5, 30), "mesma semente: mesmos eventos")
	ok(sequencia_eventos(5, 30) != sequencia_eventos(6, 30), "semente diferente: eventos diferentes")
	ok(
		not sequencia_eventos(9, 60, 1).any(func(id): return id in ["chuva_baus", "horda_elite", "santuario_errante"]),
		"fase_min respeitada (fase 1 só tem o que a fase 1 permite)"
	)
	Sorte.iniciar(1)
	ok(
		(
			Descobertas.escolher_evento(
				Sorte.fluxo("evento"), 5, {"chuva_baus": 10.0, "horda_elite": 10.0, "santuario_maldito": 10.0, "santuario_errante": 10.0}, []
			)
			== ""
		),
		"cooldown bloqueia o evento"
	)
	var seq_ev := sequencia_eventos(11, 400)
	var tipos := {}
	var tres_iguais := 0
	for i in seq_ev.size():
		tipos[seq_ev[i]] = true
		if i >= 2 and seq_ev[i] == seq_ev[i - 1] and seq_ev[i] == seq_ev[i - 2]:
			tres_iguais += 1
	ok(tipos.size() == 4, "os 4 eventos saem (%s)" % [tipos.keys()])
	ok(tres_iguais < 6, "RNG controlado: quase nunca o mesmo evento 3 vezes seguidas (%d em 400)" % tres_iguais)
	# --- dádivas ---
	Sorte.iniciar(21)
	var of1 := Descobertas.oferta_dadivas(Sorte.fluxo("dadiva"))
	Sorte.iniciar(21)
	var of2 := Descobertas.oferta_dadivas(Sorte.fluxo("dadiva"))
	ok(
		of1.size() == 3 and JSON.stringify(of1.map(func(c): return [c.id, c.raridade])) == JSON.stringify(of2.map(func(c): return [c.id, c.raridade])),
		"3 dádivas, iguais com a mesma semente"
	)
	ok(
		of1.map(func(c): return c.id).size() == 3 and of1[0].id != of1[1].id and of1[1].id != of1[2].id and of1[0].id != of1[2].id,
		"dádivas da oferta são diferentes"
	)
	var raridades := {}
	for i in 300:
		for c in Descobertas.oferta_dadivas(Sorte.fluxo("dadiva")):
			raridades[c.raridade] = int(raridades.get(c.raridade, 0)) + 1
	ok(raridades.size() == 4 and raridades.comum > raridades.rara and raridades.rara > raridades.heroica, "raridades saem por peso (%s)" % [raridades])
	var min_ok := true
	for i in 100:
		for c in Descobertas.oferta_dadivas(Sorte.fluxo("dadiva"), "rara"):
			if c.raridade == "comum":
				min_ok = false
	ok(min_ok, "raridade mínima da maldição")
	# --- na partida: fragmentos, dragão, dádiva, eventos, santuários iguais ---
	Engine.time_scale = 3.0
	var assinatura := []
	for sem in [42, 42, 99]:
		var b := Arena.new()
		b.heroi_id = "hazaki"
		b.semente = sem
		add_child(b)
		await esperar(0.1)
		assinatura.append(JSON.stringify(b.chao.santuarios.map(func(s): return [s.pos, s.tipo, s.variacao])))
		b.queue_free()
		await esperar(0.05)
	ok(assinatura[0] == assinatura[1], "duas arenas com a mesma semente: mesmos santuários")
	ok(assinatura[0] != assinatura[2], "semente diferente: santuários diferentes na arena")
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.semente = 5
	add_child(a)
	await esperar(0.2)
	a.xp = -1.0e12
	var h = a.habilidades
	var d = a.descobertas
	ok(h.tem() and not h.desbloqueada and d.alvo_fragmento() == "dragao" and d.precisa("dragao") == 3, "dragão pede 3 fragmentos (configurável no JSON)")
	a.nivel = 20
	await esperar(0.3)
	ok(not h.desbloqueada, "nível não desbloqueia mais o dragão")
	d.dar_fragmento("dragao")
	d.dar_fragmento("dragao")
	await esperar(0.2)
	ok(not h.desbloqueada and d.tem_fragmentos("dragao") == 2, "2 de 3 fragmentos: continua bloqueado")
	# santuário do dragão (simples): dá o terceiro e desbloqueia
	var s := {"pos": Vector2.ZERO, "tipo": "fragmento", "variacao": "simples", "carga": 1.0, "usado": false}
	ok(d.ativar(s) and s.usado and d.tem_fragmentos("dragao") == 3, "santuário simples dá o fragmento")
	await esperar(0.2)
	ok(h.desbloqueada, "dragão desbloqueia ao atingir os fragmentos")
	d.dar_fragmento("dragao")
	ok(d.tem_fragmentos("dragao") == 3, "não passa do total")
	# elite: pity solta o fragmento no chão (outro herói da mesma arena de teste)
	var e := Arena.new()
	e.heroi_id = "hazaki"
	e.semente = 6
	add_child(e)
	await esperar(0.2)
	e.xp = -1.0e12
	var lim_elite := int(Descobertas.cfg().pity.elite.limite)
	for i in lim_elite:
		e.descobertas.elite_morreu(Vector2(100, 100))
	var caiu: bool = e.coleta.itens.any(func(it): return it.tipo == "fragmento")
	ok(caiu, "pity: o fragmento cai de elite em até %d elites" % lim_elite)
	e.coleta.itens = e.coleta.itens.filter(func(it): return it.tipo == "fragmento")
	e.coleta._pegar(e.coleta.itens[0])
	ok(e.descobertas.tem_fragmentos("dragao") == 1, "pegar o fragmento do chão conta")
	# dádiva: efeito soma nos atributos
	var dano0: float = e.stat("dano")
	e.escolheu(Descobertas._carta_dadiva("furia", "epica"))
	ok(e.stat("dano") > dano0 + 0.2 and e.descobertas.dadivas.size() == 1, "dádiva épica soma o efeito (dano %.2f -> %.2f)" % [dano0, e.stat("dano")])
	# santuário de dádiva abre a escolha de 3
	var sd := {"pos": Vector2.ZERO, "tipo": "dadiva", "variacao": "", "carga": 1.0, "usado": false}
	e.descobertas.ativar(sd)
	ok(sd.usado and e.cartas.aberto() and e.cartas._cartas.size() == 3 and e.cartas._cartas[0].tipo == "dadiva", "santuário de dádiva oferece 3 dádivas")
	await esperar(1.0)  # o robô não está ligado: fecha a escolha por código
	e.cartas._confirmar()
	# eventos: todos os do pool rodam sem erro e são iguais com a mesma semente
	var vistos := []
	for sem in [8, 8]:
		var c := Arena.new()
		c.heroi_id = "hazaki"
		c.semente = sem
		add_child(c)
		await esperar(0.1)
		c.xp = -1.0e12
		c.diretor.fase_idx = 4
		var seq := []
		for i in 14:
			c.descobertas._cd.clear()
			seq.append(c.descobertas.sortear_evento())
		vistos.append(JSON.stringify(seq))
		ok(seq.all(func(id): return id != ""), "evento sorteado sempre que não há cooldown")
		await esperar(0.3)
		c.queue_free()
		await esperar(0.05)
	ok(vistos[0] == vistos[1], "partidas com a mesma semente sorteiam os mesmos eventos")
	Engine.time_scale = 1.0
	print("DESCOB falhas=", falhas)
	get_tree().quit()
