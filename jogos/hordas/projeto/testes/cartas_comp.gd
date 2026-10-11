extends Node
# Teste automático (#63, parte 2): cartas de comportamento (mudam COMO a arma funciona) e crossfade da música.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/cartas_comp.tscn  (imprime "CARTCOMP falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Armas := preload("res://scripts/hordas/armas.gd")
const Cartas := preload("res://scripts/hordas/cartas.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## Dono falso: só o que as armas pedem.
class Dono:
	extends Node2D
	var lado := 1

	func centro() -> Vector2:
		return position

	func curar(_x: float) -> void:
		pass

	func atacou(_dir := Vector2.ZERO) -> void:
		pass


## Campo falso: vírus são dicionários {id, pos, raio, hp, max}; guarda cada golpe recebido.
class Campo:
	extends RefCounted
	var alvos: Array = []
	var golpes: Array = []  # [id, valor]

	func no_circulo(c: Vector2, r: float) -> Array:
		return alvos.filter(func(v): return v.hp > 0.0 and v.pos.distance_to(c) <= r + v.raio)

	func n_mais_perto(p: Vector2, n: int, maximo := 400.0) -> Array:
		var l := no_circulo(p, maximo)
		l.sort_custom(func(a, b): return a.pos.distance_squared_to(p) < b.pos.distance_squared_to(p))
		return l.slice(0, n)

	func aleatorio_na_tela(_c: Vector2):
		return alvos[0] if not alvos.is_empty() else null

	func ferir(v, valor: float, _emp := Vector2.ZERO, _arma := "") -> bool:
		v.hp -= valor
		golpes.append([v.id, valor])
		return v.hp <= 0.0

	func total(id := -1) -> float:
		var t := 0.0
		for g in golpes:
			if id < 0 or g[0] == id:
				t += g[1]
		return t

	func vezes(id: int) -> int:
		return golpes.filter(func(g): return g[0] == id).size()


func vir(id: int, pos: Vector2) -> Dictionary:
	return {"id": id, "pos": pos, "raio": 8.0, "hp": 100000.0, "max": 100000.0}


## Armas soltas (sem arena): uma arma no nível pedido, com ou sem o comportamento, contra os alvos dados.
func montar(arma: String, nivel: int, comp: String, alvos: Array) -> Array:
	var ar = Armas.new()
	var dono := Dono.new()
	var campo := Campo.new()
	campo.alvos = alvos
	ar.dono = dono
	ar.campo = campo
	ar.statf = func(n): return {"dano": 1.0, "recarga": 1.0, "area": 1.0, "quantidade": 0.0, "duracao": 1.0, "velocidade_proj": 1.0}.get(n, 1.0)
	ar.adicionar(arma)
	ar.lista[0].nivel = nivel
	if comp != "":
		ar.dar_comportamento(arma, comp)
	return [ar, campo, dono]


func rodar(ar, segundos: float, dt := 0.016) -> void:
	for i in int(segundos / dt):
		ar.atualizar(dt)


func _ready() -> void:
	# --- dados: todo comportamento mira num tipo de arma que existe ---
	var lista: Dictionary = Dados.json("comportamentos").get("lista", {})
	var tipos_armas := {}
	for id in Dados.json("armas"):
		if not id.begins_with("_"):
			tipos_armas[str(Dados.json("armas")[id].get("tipo", ""))] = true
	ok(lista.size() >= 5, "pelo menos 5 comportamentos (%d)" % lista.size())
	for id in lista:
		var d: Dictionary = lista[id]
		ok(d.tipos.all(func(t): return tipos_armas.has(t)), "%s: todo tipo existe em armas.json" % id)
		ok(
			str(d.desc).begins_with("Muda ") and str(d.desc).length() <= 64 and str(d.nome) != "" and int(d.nivel_min) >= 2,
			"%s: texto curto que diz que muda o comportamento, com nível mínimo" % id
		)

	# --- elegibilidade: tipo certo, nível mínimo, sem repetir nem conflitar ---
	var m := montar("pendrive", 2, "", [])
	var ar = m[0]
	ok(ar.comportamentos_disponiveis(ar.lista[0]).is_empty(), "pendrive nível 2: ainda sem comportamento")
	ar.lista[0].nivel = 3
	var disp: Array = ar.comportamentos_disponiveis(ar.lista[0])
	disp.sort()
	ok(disp == ["ricochete", "vai_e_volta"], "pendrive nível 3 oferece ricochete e vai_e_volta (%s)" % [disp])
	ar.dar_comportamento("pendrive", "ricochete")
	ok(ar.comportamentos_disponiveis(ar.lista[0]).is_empty(), "ricochete já pego exclui o repetido e o 'vai e volta'")
	ok(not ar.dar_comportamento("pendrive", "ricochete"), "o mesmo comportamento não entra duas vezes")
	for par in [["cabo_rede", "rastro_fogo"], ["wifi", "pulso"], ["cafe", "explosao_final"], ["ventoinha", "respiracao"]]:
		var mm := montar(par[0], 3, "", [])
		ok(par[1] in mm[0].comportamentos_disponiveis(mm[0].lista[0]), "%s nível 3 oferece %s" % par)
		mm[0].free()
		mm[2].free()
	var ev := montar("ssd", 1, "", [])
	ok(ev[0].comportamentos_disponiveis(ev[0].lista[0]).is_empty(), "evolução (nível 1) ainda não oferece")
	ev[0].free()
	ev[2].free()
	ar.free()
	m[2].free()

	# --- ricochete: o tiro pula pro vírus vizinho ---
	var sem_ric := montar("pendrive", 1, "", [vir(1, Vector2(120, 0)), vir(2, Vector2(120, 100))])
	rodar(sem_ric[0], 1.4)
	ok(sem_ric[1].vezes(1) >= 1 and sem_ric[1].vezes(2) == 0, "sem comportamento o tiro só acerta o primeiro vírus")
	var com_ric := montar("pendrive", 1, "ricochete", [vir(1, Vector2(120, 0)), vir(2, Vector2(120, 100))])
	rodar(com_ric[0], 1.4)
	ok(
		com_ric[1].vezes(1) >= 1 and com_ric[1].vezes(2) >= 1,
		"com Ricochete o tiro pula pro segundo vírus (%d, %d)" % [com_ric[1].vezes(1), com_ric[1].vezes(2)]
	)
	# --- vai e volta: acerta de novo na volta ---
	var sem_vv := montar("pendrive", 1, "", [vir(1, Vector2(150, 0))])
	sem_vv[0].atualizar(0.016)  # só o primeiro tiro (a arma recarrega em ~1 s)
	rodar(sem_vv[0], 0.9)
	var vezes_sem: int = sem_vv[1].vezes(1)
	var com_vv := montar("pendrive", 1, "vai_e_volta", [vir(1, Vector2(150, 0))])
	rodar(com_vv[0], 1.6)
	ok(vezes_sem == 1 and com_vv[1].vezes(1) >= 2, "Vai e Volta acerta de novo na volta (%d x %d)" % [com_vv[1].vezes(1), vezes_sem])
	rodar(com_vv[0], 0.9)
	ok(com_vv[0].projeteis.size() <= 2, "os tiros que voltam somem ao chegar (sobram %d)" % com_vv[0].projeteis.size())

	# --- rastro de fogo: o golpe deixa poças que continuam machucando ---
	var sem_rf := montar("cabo_rede", 3, "", [vir(1, Vector2(100, 0))])
	rodar(sem_rf[0], 1.1)
	var com_rf := montar("cabo_rede", 3, "rastro_fogo", [vir(1, Vector2(100, 0))])
	rodar(com_rf[0], 1.1)
	ok(sem_rf[0].pocas.is_empty() and not com_rf[0].pocas.is_empty(), "o rastro deixa poças no chão (%d)" % com_rf[0].pocas.size())
	ok(com_rf[1].total() > sem_rf[1].total() * 1.2, "o rastro machuca além do golpe (%.0f x %.0f)" % [com_rf[1].total(), sem_rf[1].total()])
	var lim := int(lista.rastro_fogo.param.max)
	rodar(com_rf[0], 6.0)
	ok(com_rf[0].pocas.filter(func(p): return p.get("rastro", false)).size() <= lim, "poças de rastro respeitam o limite (%d)" % lim)

	# --- aura pulsante: pulso a cada N estalos e ao rolar ---
	var sem_p := montar("wifi", 3, "", [vir(1, Vector2(70, 0))])
	var com_p := montar("wifi", 3, "pulso", [vir(1, Vector2(70, 0))])
	rodar(sem_p[0], 2.0)
	rodar(com_p[0], 2.0)
	ok(com_p[1].total() > sem_p[1].total() * 1.3, "a aura pulsante bate mais forte (%.0f x %.0f)" % [com_p[1].total(), sem_p[1].total()])
	ok(not com_p[0].aneis.is_empty() or com_p[0]._t > 0.0, "o pulso desenha uma onda")
	var ant: float = com_p[1].total()
	com_p[0].aneis.clear()
	com_p[0].ao_rolar()
	ok(com_p[1].total() > ant and com_p[0].aneis.size() == 1, "rolar solta um pulso na hora")
	var dep: float = com_p[1].total()
	com_p[0].ao_rolar()
	ok(com_p[1].total() == dep, "rolar em seguida não repete (pausa)")
	sem_p[0].ao_rolar()
	ok(sem_p[0].aneis.is_empty(), "aura comum não pulsa ao rolar")

	# --- poça instável: explode ao sumir ---
	var sem_e := montar("cafe", 3, "", [vir(1, Vector2(30, 0))])
	var com_e := montar("cafe", 3, "explosao_final", [vir(1, Vector2(30, 0))])
	rodar(sem_e[0], 3.3)
	rodar(com_e[0], 3.3)
	var maior_sem := 0.0
	for g in sem_e[1].golpes:
		maior_sem = maxf(maior_sem, g[1])
	var maior_com := 0.0
	for g in com_e[1].golpes:
		maior_com = maxf(maior_com, g[1])
	ok(maior_com > maior_sem * 3.0, "a poça instável explode no fim (golpe maior %.1f x %.1f)" % [maior_com, maior_sem])

	# --- giro em espiral: o raio da órbita respira ---
	var sem_o := montar("ventoinha", 3, "", [])
	var com_o := montar("ventoinha", 3, "respiracao", [])
	var rs_sem := []
	var rs_com := []
	for i in 30:
		sem_o[0]._t = i * 0.2
		com_o[0]._t = i * 0.2
		rs_sem.append(sem_o[0]._raio_orbita(sem_o[0]._s(sem_o[0].lista[0])))
		rs_com.append(com_o[0]._raio_orbita(com_o[0]._s(com_o[0].lista[0])))
	ok(
		rs_com.max() - rs_com.min() > 0.5 * rs_sem.max() and rs_sem.max() - rs_sem.min() < 0.01,
		"a órbita em espiral abre e fecha (%.0f..%.0f)" % [rs_com.min(), rs_com.max()]
	)

	# --- na arena: a carta aparece, mostra que muda o comportamento e aplica o modificador ---
	Engine.time_scale = 3.0
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.semente = 4
	add_child(a)
	await esperar(0.3)
	a.xp = -1.0e12
	a.armas.lista.clear()
	a.armas.adicionar("pendrive")
	a.armas.lista[0].nivel = 2
	var viu2 := 0
	for i in 600:
		for c in a.sortear_cartas():
			if c.tipo == "comportamento":
				viu2 += 1
	ok(viu2 == 0, "nível 2: nenhuma carta de comportamento (%d)" % viu2)
	a.armas.lista[0].nivel = 3
	var vistas := 0
	var carta := {}
	var sempre_certa := true
	for i in 600:
		for c in a.sortear_cartas():
			if c.tipo == "comportamento":
				vistas += 1
				carta = c
				if c.arma != "pendrive" or not c.id in ["ricochete", "vai_e_volta"]:
					sempre_certa = false
	ok(vistas > 5 and sempre_certa, "nível 3: aparecem cartas de comportamento da arma certa (%d em 600 sorteios)" % vistas)
	ok(vistas < 600 * 3 * 0.25, "são raras (%d em 1800 cartas)" % vistas)
	var est: Dictionary = Cartas.estilo(carta)
	ok(
		est.rotulo == "COMPORTAMENTO" and carta.desc.begins_with("Muda ") and carta.arma_nome != "" and carta.desc.length() <= 64,
		"a carta diz que é comportamento (%s | %s)" % [est.rotulo, carta.nome]
	)
	ok(not Arena.carta_banivel(carta), "carta de comportamento não pode ser banida")
	var s_antes: Dictionary = a.armas._s(a.armas.lista[0])
	ok(s_antes.comp.is_empty(), "antes da carta a arma não tem modificador")
	a.escolheu(carta)
	var s_depois: Dictionary = a.armas._s(a.armas.lista[0])
	ok(s_depois.comp.has(carta.id), "depois da carta o módulo recebe o modificador (%s)" % [s_depois.comp.keys()])
	ok(a.armas.comportamentos_disponiveis(a.armas.lista[0]).is_empty(), "e a arma não recebe outro conflitante")
	# cartas abertas de verdade: a tela desenha a carta sem erro
	a.cartas.escolher("Teste", [carta, a.sortear_cartas()[0]])
	await esperar(0.5)
	ok(a.cartas.aberto(), "a tela de cartas abre com a carta de comportamento")
	a.cartas._confirmar()
	await esperar(0.1)
	a.queue_free()
	await esperar(0.1)
	Engine.time_scale = 1.0

	# --- crossfade da música ---
	Som.duracao_fade = 1.5
	Som.volume_musica = 0.6
	Som.parar_musica()
	Som.musica("menu")
	await esperar(0.2)
	ok(Som._atual.playing and not Som.fade_estado().ativo, "primeira faixa entra direto, no volume das opções")
	ok(absf(Som._atual.volume_db - linear_to_db(0.6)) < 0.5, "volume da faixa = opção (%.1f dB)" % Som._atual.volume_db)
	var velho := Som._atual.stream
	Som.musica("menu")
	ok(Som._atual.stream == velho and not Som.fade_estado().ativo, "pedir a mesma faixa não reinicia nem faz fade")
	Som.musica("chefe")
	var t0 := Time.get_ticks_msec()
	ok(
		Som._atual.playing and Som._saida.playing and Som._atual.stream != velho and Som._saida.stream == velho,
		"troca de faixa: a nova entra e a velha continua tocando"
	)
	var pior_potencia := 10.0
	var maior_potencia := 0.0
	var amostras := 0
	var viu_meio := false
	while Time.get_ticks_msec() - t0 < 1400:
		await esperar(0.1)
		if not Som.fade_estado().ativo:
			break
		var pn := db_to_linear(Som._atual.volume_db) if Som._atual.volume_db > -79.0 else 0.0
		var pv := db_to_linear(Som._saida.volume_db) if Som._saida.playing and Som._saida.volume_db > -79.0 else 0.0
		var pot := (pn * pn + pv * pv) / (0.6 * 0.6)
		pior_potencia = minf(pior_potencia, pot)
		maior_potencia = maxf(maior_potencia, pot)
		if pn > 0.05 and pv > 0.05:
			viu_meio = true
		amostras += 1
	ok(amostras >= 5 and viu_meio, "no meio da troca as duas faixas soam juntas (%d amostras)" % amostras)
	ok(pior_potencia > 0.6, "sem buraco: a potência somada não cai (mínimo %.2f do normal)" % pior_potencia)
	ok(maior_potencia < 1.15, "sem estouro: a potência somada não passa do normal (máximo %.2f)" % maior_potencia)
	await esperar(0.9)
	ok(not Som.fade_estado().ativo and not Som._saida.playing and Som._atual.playing, "ao fim do fade só a nova toca")
	ok(absf(Som._atual.volume_db - linear_to_db(0.6)) < 0.5, "a faixa nova termina no volume das opções (%.1f dB)" % Som._atual.volume_db)
	Som.volume_musica = 0.3
	Som.atualizar_volume()
	ok(absf(Som._atual.volume_db - linear_to_db(0.3)) < 0.5, "mudar o volume nas opções acompanha na hora")
	Som.volume_musica = 0.6
	Som.atualizar_volume()
	# troca no meio de outra troca: nunca fica mudo nem com 3 faixas
	Som.musica("fim")
	await esperar(0.3)
	Som.musica("menu")
	await esperar(0.2)
	ok(Som._atual.playing and (Som._saida.playing or Som._g_atual >= 1.0), "troca no meio da troca continua tocando")
	await esperar(2.0)
	ok(
		Som._atual.playing and not Som._saida.playing and absf(Som._atual.volume_db - linear_to_db(0.6)) < 0.5,
		"depois de duas trocas seguidas só uma faixa toca, no volume certo"
	)
	Som.parar_musica()
	ok(not Som._atual.playing and not Som._saida.playing, "parar_musica silencia as duas")
	print("CARTCOMP falhas=", falhas)
	get_tree().quit()
