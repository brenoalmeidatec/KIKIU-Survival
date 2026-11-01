extends "res://testes/isolamento_v2.gd"
# CAR-2: a MÃO de cartas (cartas.montar_mao): 2 upgrades + 1 novidade, sem repetição.
# Confere: com 3 golpes + 2 stats a mão é 2 upgrades + 1 novidade em 200 sorteios (o código antigo dava ~5% de upgrade);
# no começo da partida são 3 novidades e a regra do golpe garantido continua valendo; a novidade não repete o que passou nas
# últimas 2 rodadas nem o bônus descartado, mas o upgrade pode voltar; sem candidato de um tipo o espaço vira o outro;
# pool esgotado cai na cura (sem travar); o selo e o rodapé do cartão; o baú usa a mesma mão; o atalho `sortear` não guarda nada.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_cartas_mao.tscn  (imprime "v2_cartas_mao falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var cs


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.combate.cartas.rng.seed = 4242
	for i in 3:
		w.avancar(PASSO)
	cs = w.combate.cartas


func dar(id: String, n: int) -> void:
	for k in n:
		cs.aplicar(cs.montar_carta(cs.definicao(id), 0))


## Conta os tipos da mão: {"up": n, "nov": n}.
func tipos(mao: Array) -> Dictionary:
	var r := {"up": 0, "nov": 0}
	for c in mao:
		var t := str(c.get("tipo", ""))
		r[t] = int(r.get(t, 0)) + 1
	return r


func ids(mao: Array) -> Array:
	var r: Array = []
	for c in mao:
		r.append(str(c.id))
	return r


func unicos(lista: Array) -> int:
	var d := {}
	for x in lista:
		d[x] = true
	return d.size()


func id_do_tipo(mao: Array, tipo: String) -> String:
	for c in mao:
		if str(c.tipo) == tipo:
			return str(c.id)
	return ""


## Sobe um nível de verdade e espera a escolha abrir.
func subir_nivel() -> void:
	var h = w.heroi
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	for i in 120:
		if w.combate.jogo == "escolha":
			break
		w.avancar(PASSO)


func _run() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	_testes()
	print("v2_cartas_mao falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _testes() -> void:
	# 1. 3 golpes + 2 stats: 200 sorteios, sempre 2 upgrades + 1 novidade, 3 cartas diferentes, upgrade só de bônus que ele tem
	zerar()
	var golpes: Array = []
	for d in cs.cfg.golpes:
		if cs._disponivel(d) and golpes.size() < 3:
			golpes.append(str(d.id))
	for g in golpes:
		dar(g, 1)
	dar("dano", 1)
	dar("vida", 1)
	var meus: Array = golpes + ["dano", "vida"]
	var certas := 0
	var repetiu_na_mao := 0
	var upgrade_estranho := 0
	var novidade_ja_tinha := 0
	for i in 200:
		var mao: Array = cs.montar_mao(8, 1.0, 0, -1, false)
		var t := tipos(mao)
		if mao.size() == 3 and t.up == 2 and t.nov == 1:
			certas += 1
		if unicos(ids(mao)) != mao.size():
			repetiu_na_mao += 1
		for c in mao:
			if str(c.tipo) == "up" and not meus.has(str(c.id)):
				upgrade_estranho += 1
			if str(c.tipo) == "nov" and meus.has(str(c.id)):
				novidade_ja_tinha += 1
	ok(certas == 200, "com 3 golpes + 2 stats a mão é 2 upgrades + 1 novidade em 200 sorteios (%d de 200)" % certas)
	ok(repetiu_na_mao == 0, "dentro da mão nenhuma carta repete")
	ok(upgrade_estranho == 0 and novidade_ja_tinha == 0, "upgrade só de bônus que ele tem; novidade só de bônus que ele não tem")

	# 2. o rodapé: upgrade mostra "Nível 1 » 2 de 5"; novidade "Novo ..."
	var mao2: Array = cs.montar_mao(8, 1.0, 0, -1, false)
	for c in mao2:
		if str(c.tipo) == "up":
			ok(str(c.nivel_txt) == "Nível %d » %d de %d" % [int(c.nivel_atual), int(c.nivel_novo), int(c.max)], "rodapé do upgrade (%s)" % c.nivel_txt)
		else:
			ok(int(c.nivel_atual) == 0 and str(c.nivel_txt).begins_with("Novo"), "rodapé da novidade (%s)" % c.nivel_txt)

	# 3. começo da partida: nenhum bônus = 3 novidades, e pelo menos um golpe (garantir_golpe_ate)
	zerar()
	var sem_golpe := 0
	var todas_novas := 0
	for i in 100:
		var mao3: Array = cs.montar_mao(1, 1.0, 0, -1, false)
		var t3 := tipos(mao3)
		if mao3.size() == 3 and t3.nov == 3:
			todas_novas += 1
		var tem_golpe := false
		for c in mao3:
			if str(c.cat) == "golpe":
				tem_golpe = true
		if not tem_golpe:
			sem_golpe += 1
	ok(todas_novas == 100, "sem bônus nenhum a mão é de 3 novidades (%d de 100)" % todas_novas)
	ok(sem_golpe == 0, "no começo a mão sempre traz um golpe (%d sem)" % sem_golpe)
	# a regra do golpe vale também com stats na mão e nenhum golpe (o último espaço, a novidade, vira golpe)
	dar("dano", 1)
	dar("vida", 1)
	var sem_golpe2 := 0
	for i in 60:
		var mao3b: Array = cs.montar_mao(2, 1.0, 0, -1, false)
		var tem2 := false
		for c in mao3b:
			if str(c.cat) == "golpe":
				tem2 = true
		if not tem2:
			sem_golpe2 += 1
	ok(sem_golpe2 == 0, "com 2 stats e nenhum golpe a mão ainda traz um golpe (%d sem)" % sem_golpe2)

	# 4. a novidade não repete o que passou nas últimas 2 rodadas (se não foi pega); o upgrade pode voltar
	zerar()
	dar("dano", 1)
	var nov_a := id_do_tipo(cs.montar_mao(8), "nov")
	var nov_b := id_do_tipo(cs.montar_mao(8), "nov")
	var nov_c := id_do_tipo(cs.montar_mao(8), "nov")
	ok(nov_b != nov_a, "a novidade da rodada 2 não repete a da rodada 1 (%s, %s)" % [nov_a, nov_b])
	ok(nov_c != nov_a and nov_c != nov_b, "a da rodada 3 não repete as 2 rodadas anteriores (%s, %s, %s)" % [nov_a, nov_b, nov_c])
	ok(cs.vistas.size() == 2, "o anel guarda só as 2 últimas rodadas (%d)" % cs.vistas.size())
	var voltou_up := false
	for i in 20:
		if ids(cs.montar_mao(8, 1.0, 0, -1, false)).has("dano"):
			voltou_up = true
	ok(voltou_up, "o upgrade (bônus que ele já tem) pode voltar na rodada seguinte")
	var antes: Array = cs.vistas.duplicate(true)
	cs.sortear(3, 8)
	ok(cs.vistas == antes, "o atalho sortear não guarda rodada em vistas")
	# 100 rodadas seguidas: nenhuma novidade igual a uma das 2 rodadas anteriores
	zerar()
	dar("dano", 1)
	var ultimas: Array = []  # as 2 mãos anteriores
	var repetiu_nov := 0
	for i in 100:
		var m: Array = cs.montar_mao(8)
		var nv := id_do_tipo(m, "nov")
		for anterior in ultimas:
			if (anterior as Array).has(nv):
				repetiu_nov += 1
		ultimas.append(ids(m))
		if ultimas.size() > 2:
			ultimas.pop_front()
	ok(repetiu_nov == 0, "em 100 rodadas a novidade nunca repete as 2 rodadas anteriores (%d vezes)" % repetiu_nov)

	# 5. bônus descartado (a troca do Difícil, CAR-4) não volta em 300 sorteios
	zerar()
	dar("dano", 1)
	cs.descartadas.append("area")
	var voltou := 0
	for i in 300:
		if ids(cs.montar_mao(8, 1.0, 0, -1, false)).has("area"):
			voltou += 1
	ok(voltou == 0, "bônus descartado não volta em 300 sorteios (%d)" % voltou)

	# 6. sem candidato de um tipo o espaço vira o outro; no máximo não é oferecido
	zerar()
	dar("dano", 1)
	for id in cs._def:  # tudo que ele não tem fica "usado": nenhuma novidade
		if cs.nivel_de(str(id)) == 0:
			cs.estado[id] = {"n": 0, "usada": true}
	var mao6: Array = cs.montar_mao(8, 1.0, 0, -1, false)
	ok(
		mao6.size() == 1 and str(mao6[0].id) == "dano" and str(mao6[0].tipo) == "up",
		"só há 1 upgrade e nenhuma novidade: a mão é essa carta (%s)" % str(ids(mao6))
	)
	zerar()
	dar("dano", 4)  # no nível 4 de 5 ainda é upgrade
	var mao6b: Array = cs.montar_mao(8, 1.0, 0, -1, false)
	var t6b := tipos(mao6b)
	ok(mao6b.size() == 3 and t6b.up == 1 and t6b.nov == 2, "com 1 upgrade, o espaço que sobra vira novidade (%s)" % str(t6b))
	zerar()
	dar("dano", 5)
	var mao6c: Array = cs.montar_mao(8, 1.0, 0, -1, false)
	ok(not ids(mao6c).has("dano") and tipos(mao6c).up == 0, "bônus no máximo não é oferecido")

	# 7. pool esgotado: a mão é vazia e a escolha de nível cai na cura, sem travar
	zerar()
	for id in cs._def:
		cs.estado[id] = {"n": 0, "usada": true}
	ok(cs.montar_mao(8).is_empty(), "sem nenhuma carta a mão é vazia")
	subir_nivel()
	ok(w.combate.jogo == "escolha" and w.combate.progresso.cartas.size() == 1, "a escolha abre só com a cura quando nada sobra")
	ok(str(w.combate.progresso.cartas[0].id) == "cura", "a carta é a cura")
	w.combate.telas.espera_escolha = 0.0
	w.combate.progresso.escolher(0)
	ok(w.combate.jogo == "jogando" and not w.combate.pausado, "escolher a cura fecha a escolha")

	# 8. sobrou 1 carta: a cura ocupa um espaço da mão (uma só)
	zerar()
	for id in cs._def:
		cs.estado[id] = {"n": 0, "usada": true}
	cs.estado["dano"] = {"n": 1, "bonus": 0.0, "soma": 0.0, "usada": false}
	subir_nivel()
	var pc: Array = w.combate.progresso.cartas
	ok(pc.size() == 2 and str(pc[0].id) == "dano" and str(pc[1].id) == "cura", "com 1 carta sobrando a mão é ela mais a cura (%s)" % str(ids(pc)))

	# 9. o cartão mostra o selo UPGRADE ou NOVO (e nada na carta de cura)
	zerar()
	dar("dano", 1)
	dar("vida", 1)
	var mao9: Array = cs.montar_mao(8, 1.0, 0, -1, false)
	w.combate.progresso.cartas = mao9
	w.combate.jogo = "escolha"
	w.combate.pausado = true
	w.combate.telas.roleta_ligada = false
	w.combate.telas.mostrar_escolha(mao9, 8)
	w.avancar(PASSO)
	for i in mao9.size():
		var tp := str(mao9[i].get("tipo", ""))
		var esperado := "UPGRADE" if tp == "up" else ("NOVO" if tp == "nov" else "")
		var p: Control = w.combate.telas._cartas[i]
		ok((p.get_node("selo") as Label).text == esperado, "o selo do cartão %d acompanha o tipo '%s' (%s)" % [i, tp, (p.get_node("selo") as Label).text])
	ok(tipos(mao9).up == 2 and tipos(mao9).nov == 1, "a mão da foto é 2 upgrades + 1 novidade (%s)" % str(tipos(mao9)))
	var cura_p: Control = w.combate.telas._cartas[0]  # a carta de cura não leva selo
	w.combate.telas._preencher(cura_p, w.combate.progresso._carta_cura())
	ok((cura_p.get_node("selo") as Label).text == "", "a carta de cura não leva selo")

	# 10. o baú com escolha usa a mesma mão (2 upgrades + 1 novidade), com o piso de raridade, e guarda a rodada
	zerar()
	dar("dano", 1)
	dar("vida", 1)
	var antes_b: int = cs.vistas.size()
	var cand: Array = cs.montar_mao(8, 5.0, 1, 3)
	var tb := tipos(cand)
	ok(cand.size() == 3 and tb.up == 2 and tb.nov == 1, "a mão do baú também é 2 upgrades + 1 novidade (%s)" % str(tb))
	var piso_ok := true
	for c in cand:
		if int(c.rar) < 1:
			piso_ok = false
	ok(piso_ok, "o piso de raridade do baú continua valendo")
	ok(cs.vistas.size() == antes_b + 1, "a mão do baú entra em vistas")
	# o atalho (baú que entrega de graça) respeita a quantidade pedida
	ok(cs.sortear(2, 8).size() == 2 and cs.sortear(1, 8).size() == 1, "o atalho sortear devolve a quantidade pedida")

	# 12. ressalva 2 do CAR-2: quando todo golpe passou há pouco, a garantia do golpe não repete um deles (carta não se repete)
	zerar()
	var todos: Array = []
	for d in cs.cfg.golpes:
		todos.append(str(d.id))
	cs.vistas = [todos]
	var mao12: Array = cs.montar_mao(1, 1.0, 0, -1, false)
	var golpes12 := 0
	for c in mao12:
		if cs._cat[str(c.id)] == "golpe":
			golpes12 += 1
	ok(golpes12 == 0, "a garantia não repete golpe visto nas últimas rodadas (%d golpes na mão)" % golpes12)

	# 13. ressalva 1 do CAR-2: o baú monta a mão, mas se só sobra uma carta ela nem é mostrada, e então não entra em vistas
	zerar()
	for id in cs._def:
		if id != "dano":
			cs.estado[id] = {"n": 0, "usada": true}
	var n_vistas: int = cs.vistas.size()
	var bau = w.combate.baus
	bau.soltar(Vector2(480, 270), 1.0, 0)
	var b_aberto = null
	for x in bau.lista:
		if x.ativo:
			b_aberto = x
	ok(b_aberto != null, "o baú foi solto para o teste")
	if b_aberto != null:
		bau.abrir(b_aberto)
	ok(cs.vistas.size() == n_vistas, "a mão do baú que não é mostrada não entra em vistas (%d -> %d)" % [n_vistas, cs.vistas.size()])
	# e a mão que abre a escolha entra, uma vez
	cs.registrar_mao(cs.montar_mao(1, 1.0, 0, 3, false))
	ok(cs.vistas.size() == n_vistas + 1, "registrar_mao guarda a mão mostrada")

	# 11. zerar a partida limpa vistas e descartadas
	cs.descartadas.append("area")
	cs.zerar()
	ok(cs.vistas.is_empty() and cs.descartadas.is_empty(), "zerar limpa vistas e descartadas")


func _ready() -> void:
	_run()
