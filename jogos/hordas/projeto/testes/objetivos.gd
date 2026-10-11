extends Node
# Teste automático: objetivo próprio por andar (#63). Escolha igual em todo cliente, completa / falha / paga,
# nunca trava a corrida e o estado que o anfitrião manda deixa o cliente igual (com a recompensa paga uma vez só).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/objetivos.tscn  (imprime "OBJ falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Objetivos := preload("res://scripts/hordas/objetivos.gd")
const Regioes := preload("res://scripts/hordas/regioes.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func nova_arena(semente: int) -> Node:
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = true
	a.semente = semente
	add_child(a)
	return a


## O que o cliente receberia: o dicionário passa por bytes, como no RPC.
func pela_rede(d: Dictionary) -> Dictionary:
	return bytes_to_var(var_to_bytes(d))


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	var c := Objetivos.cfg()
	var inim: Dictionary = Dados.json("inimigos")
	var k := Regioes.por_regiao()

	# --- dados
	ok(c.get("tipos", {}).size() >= 3, "pelo menos 3 tipos de objetivo")
	for tid in c.tipos:
		var d: Dictionary = c.tipos[tid]
		ok(d.has("nome") and d.has("dica") and d.has("tempo") and d.has("recompensa") and d.has("falha"), "%s: nome, dica, tempo, recompensa e falha" % tid)
		ok(float(d.tempo) < 80.0, "%s: o tempo cabe na fase mais curta (%s)" % [tid, d.tempo])
		if d.has("inimigo"):
			ok(
				inim.has(str(d.inimigo)) and str(inim[d.inimigo].get("conjunto", "")) == "objetivo" and float(inim[d.inimigo].get("peso", 1)) == 0.0,
				"%s: o inimigo existe e o diretor nunca sorteia" % tid
			)
	for a in c.andares_regiao:
		ok(int(a) >= 1 and int(a) < k - 1, "andar %s da região nem é o primeiro nem o chefe" % a)
	var ids_reg := Regioes.lista().map(func(r): return str(r.id))
	for r in c.pool:
		ok(r in ids_reg, "pool de região que existe: " + r)
		for t in c.pool[r]:
			ok(c.tipos.has(t), "pool %s cita tipo que existe (%s)" % [r, t])

	# --- escolha: igual em todo cliente, só nos andares e nós certos
	Sorte.iniciar(11)
	var fases := Regioes.gerar_fases(Sorte.fluxo("regioes"))
	var tem := 0
	var tipos_vistos := {}
	for i in fases.size():
		var f: Dictionary = fases[i]
		var t := Objetivos.escolher(f, "fase", i)
		var esperado: bool = int(f.andar_regiao) in c.andares_regiao.map(func(x): return int(x)) and not f.chefe_regiao
		ok((t != "") == esperado, "andar %d (%d da região): objetivo só nos andares dos dados (%s)" % [i + 1, int(f.andar_regiao) + 1, t])
		ok(t == Objetivos.escolher(f, "fase", i), "andar %d: a escolha se repete" % (i + 1))
		if t != "":
			tem += 1
			tipos_vistos[t] = true
			ok(t in c.pool[str(Regioes.regiao(int(f.regiao)).id)], "andar %d: o tipo sai do pool da região" % (i + 1))
			ok(Objetivos.escolher(f, "elite", i) == t, "andar %d: nó de elite também tem" % (i + 1))
			ok(
				Objetivos.escolher(f, "loja", i) == "" and Objetivos.escolher(f, "descanso", i) == "" and Objetivos.escolher(f, "evento", i) == "",
				"andar %d: nó sem combate não tem" % (i + 1)
			)
			var forcado := f.duplicate()
			forcado["objetivo"] = "pira"
			ok(Objetivos.escolher(forcado, "fase", i) == "pira", "a fase pode forçar o objetivo")
			forcado["objetivo"] = false
			ok(Objetivos.escolher(forcado, "fase", i) == "", "a fase pode apagar o objetivo")
	ok(tem == Regioes.n() * c.andares_regiao.size(), "a corrida tem %d objetivos (%d)" % [Regioes.n() * c.andares_regiao.size(), tem])
	var variados := {}
	for s in range(1, 16):
		Sorte.iniciar(s)
		var fs := Regioes.gerar_fases(Sorte.fluxo("regioes"))
		for i in fs.size():
			var t2 := Objetivos.escolher(fs[i], "fase", i)
			if t2 != "":
				variados[t2] = true
	ok(variados.size() == c.tipos.size(), "com várias sementes saem todos os tipos (%s)" % [variados.keys()])
	var r0 := Objetivos.recompensa("totens", 0)
	var r3 := Objetivos.recompensa("totens", 3)
	ok(
		r3.ouro > r0.ouro and r3.xp > r0.xp and r0.ouro == int(c.tipos.totens.recompensa.ouro),
		"a recompensa cresce com a região (%d -> %d)" % [r0.ouro, r3.ouro]
	)

	# --- na partida (solo = anfitrião): totens
	var a := nova_arena(7)
	await esperar(0.2)
	a.xp = -1.0e12
	a.jogador.invencivel = 999.0
	a.saltar_para_andar(1)  # 2o andar da região 1: tem objetivo
	ok(a.objetivo._pendente != "" and a.objetivo.est == Objetivos.NENHUM, "chegou no andar com objetivo: ele aparece depois do 'inicio'")
	var tid: String = a.objetivo._pendente
	a.objetivo._espera = 0.01
	a.objetivo.atualizar(0.1)
	ok(a.objetivo.ativo() and a.objetivo.id == tid and a.objetivo.seq == 1, "o objetivo começou (%s)" % tid)
	ok(a.objetivo.resta > 50.0 and a.objetivo.alvo > 0.0, "tem tempo e meta")
	a.objetivo.est = Objetivos.NENHUM  # recomeça controlado, um tipo por vez
	a.objetivo._ids = []
	a.ouro = 100
	a.fase_stat.xp = 0.0
	a.objetivo._iniciar("totens")
	ok(a.objetivo.seq == 2 and a.objetivo._ids.size() == 3 and a.objetivo.marcas.size() == 3, "3 totens nasceram e têm seta (%d)" % a.objetivo._ids.size())
	for i in a.objetivo._ids:
		ok(a.inimigos.por_id.has(i) and a.inimigos.por_id[i].tipo == "totem_sombrio" and a.inimigos.por_id[i].vel == 0.0, "totem parado, do tipo certo")
	var antes_snap: Dictionary = a.objetivo.snapshot()
	var ids: Array = a.objetivo._ids.duplicate()
	a.inimigos.ferir(a.inimigos.por_id[ids[0]], 1.0e9, Vector2.ZERO, "teste")
	ok(a.objetivo.prog == 1.0 and a.objetivo.ativo(), "um totem caiu: 1/3")
	a.inimigos.ferir(a.inimigos.por_id[ids[1]], 1.0e9, Vector2.ZERO, "teste")
	a.inimigos.ferir(a.inimigos.por_id[ids[2]], 1.0e9, Vector2.ZERO, "teste")
	var r := Objetivos.recompensa("totens", 0)
	ok(a.objetivo.est == Objetivos.CUMPRIDO and not a.objetivo.ativo(), "os 3 caíram: cumprido")
	ok(a.ouro >= 100 + int(r.ouro), "pagou o ouro (%d)" % a.ouro)
	ok(a.fase_stat.xp >= float(r.xp) * 0.99, "pagou o XP (%.0f)" % a.fase_stat.xp)
	ok(int(a.fase_stat.objetivo.get("est", 0)) == Objetivos.CUMPRIDO, "a tela de resultado fica sabendo")
	var ouro_pago: int = a.ouro
	a.objetivo._pagar()
	ok(a.ouro == ouro_pago, "não paga duas vezes")
	ok(not a.acabou and not a.entre_fases, "completar não mexe no fluxo da corrida")

	# --- falha por tempo: penalidade, não game over
	a.objetivo._zerar()
	a.ouro = 200
	a.inimigos.limpar()
	a.objetivo._iniciar("totens")
	var vivos0: int = a.inimigos.vivos()
	var ids_f: Array = a.objetivo._ids.duplicate()
	a.objetivo.atualizar(a.objetivo.resta + 1.0)
	ok(a.objetivo.est == Objetivos.FALHOU and not a.objetivo.tarde, "o tempo acabou: falhou")
	ok(a.ouro < 200 and a.ouro >= 160, "perdeu parte do ouro (%d)" % a.ouro)
	ok(a.inimigos.vivos() >= vivos0 - 3 + int(c.tipos.totens.falha.anel) - 1, "uma horda extra nasceu (%d -> %d)" % [vivos0, a.inimigos.vivos()])
	for i in ids_f:
		ok(not a.inimigos.por_id.has(i) or a.inimigos.por_id[i].hp <= 0.0, "os totens que sobraram somem")
	ok(not a.acabou and not a.entre_fases and a.jogador.hp > 0.0, "falhar nunca é game over nem trava a fase")
	ok(a.objetivo.visivel(), "o resultado fica um tempo no HUD")

	# --- pira: conta só dentro do círculo e decai fora
	a.objetivo._zerar()
	a.objetivo._iniciar("pira")
	ok(a.objetivo.alvo == 22.0 and a.objetivo.marcas.size() == 1, "pira: 22 s e uma seta")
	a.jogador.position = a.objetivo.pos + Vector2(0, 30)
	a.objetivo.atualizar(5.0)
	ok(is_equal_approx(a.objetivo.prog, 5.0), "dentro do círculo: a pira acende (%.1f)" % a.objetivo.prog)
	a.jogador.position = a.objetivo.pos + Vector2(400, 0)
	a.objetivo.atualizar(4.0)
	ok(is_equal_approx(a.objetivo.prog, 3.0), "fora: o fogo diminui (%.1f)" % a.objetivo.prog)
	a.jogador.position = a.objetivo.pos
	a.ouro = 0
	for i in 5:
		a.objetivo.atualizar(5.0)
	ok(a.objetivo.est == Objetivos.CUMPRIDO and a.ouro > 0, "ficou o bastante: pira acesa e paga")

	# --- fugitivo
	a.objetivo._zerar()
	a.objetivo._iniciar("fugitivo")
	var fug = a.inimigos.por_id[a.objetivo._ids[0]]
	ok(fug.tipo == "cultista_fugitivo" and fug.elite and fug.distancia > 300.0, "o fugitivo é um elite que mantém distância")
	a.inimigos.ferir(fug, 1.0e9, Vector2.ZERO, "teste")
	ok(a.objetivo.est == Objetivos.CUMPRIDO, "matou o fugitivo: cumprido")

	# --- o chefe da fase chega antes: falha sem horda de castigo, mas com a perda de ouro
	a.objetivo._zerar()
	a.ouro = 100
	a.objetivo._iniciar("pira")
	var v_antes: int = a.inimigos.vivos()
	a.diretor.final_chamado = true
	a.objetivo.atualizar(0.1)
	ok(a.objetivo.est == Objetivos.FALHOU and a.objetivo.tarde and a.inimigos.vivos() <= v_antes, "chefe chegou: falha 'tarde', sem horda extra")
	ok(a.ouro < 100, "...mas a perda de ouro vale")
	a.diretor.final_chamado = false

	# --- novo andar limpa o objetivo velho
	a.objetivo.nova_fase(a.diretor.fases()[0], "fase", 0)
	ok(a.objetivo.est == Objetivos.NENHUM and a.objetivo.id == "" and not a.objetivo.visivel(), "andar novo limpa o objetivo")

	# --- online: o cliente recebe o estado do anfitrião e fica igual
	var h := nova_arena(7)
	var cl := nova_arena(7)
	await esperar(0.2)
	for x in [h, cl]:
		x.xp = -1.0e12
		x.jogador.invencivel = 999.0
	cl.inimigos.espelho = true  # esta arena é um cliente: não roda IA nem decide nada
	var fa: Dictionary = h.diretor.fases()[1]
	h.objetivo.nova_fase(fa, "fase", 1)
	cl.objetivo.nova_fase(fa, "fase", 1)
	ok(h.objetivo._pendente != "" and cl.objetivo._pendente == "" and cl.objetivo._espera < 0.0, "só o anfitrião decide")
	cl.objetivo.atualizar(30.0)
	ok(cl.objetivo.est == Objetivos.NENHUM, "o cliente sozinho nunca inicia nada")
	h.objetivo._espera = 0.01
	h.objetivo.atualizar(0.1)
	var s1 := pela_rede(h.objetivo.snapshot())
	cl.objetivo.aplicar(s1)
	ok(cl.objetivo.snapshot() == h.objetivo.snapshot(), "início igual nos dois lados (%s)" % [cl.objetivo.snapshot()])
	ok(cl.objetivo.ativo() and cl.objetivo.id == h.objetivo.id, "o cliente mostra o mesmo objetivo")
	h.objetivo.atualizar(7.0)  # anda o tempo; o totem ainda vive
	var s2 := pela_rede(h.objetivo.snapshot())
	cl.objetivo.aplicar(s2)
	ok(cl.objetivo.snapshot() == h.objetivo.snapshot(), "meio igual nos dois lados")
	# o cliente guarda marcas pra seta e relógio que anda sozinho entre dois estados
	var resta_antes: float = cl.objetivo.resta
	cl.objetivo.atualizar(1.0)
	ok(cl.objetivo.resta < resta_antes, "o relógio do cliente anda entre dois estados")
	# o anfitrião cumpre; o cliente paga a própria recompensa uma vez só
	var ouro_cl: int = cl.ouro
	var tipo_h: String = h.objetivo.id
	if tipo_h == "pira":
		h.jogador.position = h.objetivo.pos
		h.objetivo.atualizar(h.objetivo.alvo + 1.0)
	else:
		for i in h.objetivo._ids.duplicate():
			if h.inimigos.por_id.has(i):
				h.inimigos.ferir(h.inimigos.por_id[i], 1.0e9, Vector2.ZERO, "teste")
	ok(h.objetivo.est == Objetivos.CUMPRIDO, "o anfitrião cumpriu (%s)" % tipo_h)
	var s3 := pela_rede(h.objetivo.snapshot())
	cl.objetivo.aplicar(s3)
	ok(cl.objetivo.snapshot() == h.objetivo.snapshot(), "fim igual nos dois lados")
	ok(
		cl.objetivo.est == Objetivos.CUMPRIDO and cl.ouro == ouro_cl + int(Objetivos.recompensa(tipo_h, 0).ouro),
		"o cliente recebeu a própria recompensa (%d -> %d)" % [ouro_cl, cl.ouro]
	)
	cl.objetivo.aplicar(s3)
	cl.objetivo.aplicar(s2)  # estado velho chegando atrasado
	ok(
		cl.ouro == ouro_cl + int(Objetivos.recompensa(tipo_h, 0).ouro) and cl.objetivo.est == Objetivos.CUMPRIDO,
		"repetido ou atrasado não paga de novo nem volta atrás"
	)
	# andar novo no cliente: o estado do andar velho não volta
	cl.objetivo.nova_fase(h.diretor.fases()[2], "fase", 2)
	cl.objetivo.aplicar(s3)
	ok(cl.objetivo.est == Objetivos.NENHUM, "depois de mudar de andar, o estado do andar antigo é ignorado")
	# falha no anfitrião chega ao cliente com a perda de ouro
	h.objetivo.nova_fase(h.diretor.fases()[3], "fase", 3)
	cl.objetivo.nova_fase(h.diretor.fases()[3], "fase", 3)
	h.objetivo._zerar()
	h.objetivo._iniciar("totens")
	cl.objetivo.aplicar(pela_rede(h.objetivo.snapshot()))
	h.ouro = 100
	cl.ouro = 100
	h.objetivo.atualizar(h.objetivo.resta + 1.0)
	cl.objetivo.aplicar(pela_rede(h.objetivo.snapshot()))
	ok(cl.objetivo.snapshot() == h.objetivo.snapshot() and cl.objetivo.est == Objetivos.FALHOU, "falha igual nos dois lados")
	ok(cl.ouro < 100 and cl.ouro == h.ouro, "os dois perderam o mesmo ouro (%d e %d)" % [h.ouro, cl.ouro])
	# lixo vindo da rede não derruba nem muda nada
	for lixo in [
		{},
		{"seq": 99, "id": "nao_existe", "est": 1},
		{"seq": 99, "id": "pira", "est": 77},
		{"seq": "x", "id": 3},
		{"seq": 99, "id": "pira", "est": 1, "prog": INF, "x": NAN, "m": "ruim"}
	]:
		cl.objetivo.aplicar(lixo)
	ok(not is_nan(cl.objetivo.pos.x) and not is_inf(cl.objetivo.prog), "estado torto da rede não entra")
	a.queue_free()
	h.queue_free()
	cl.queue_free()
	print("OBJ falhas=", falhas)
	get_tree().quit()
