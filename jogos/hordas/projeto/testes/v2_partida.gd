extends "res://testes/isolamento_v2.gd"
# Teste automático da profundidade da partida da v2 (leva 3): raridade que sobe com o nível, cartas (stat, golpe, modificador), rerrolar e
# banir, os 5 golpes secundários acertando, os modificadores da katana, as evoluções, a elite que solta baú e o baú que dá melhorias, a
# derrota e o sinal partida_terminou com os campos certos. Os níveis do mapa estão em v2_diretor.gd; os chefes e a vitória, em v2_chefe.gd.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_partida.tscn  (imprime "v2_partida falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const ArmasNovas := preload("res://v2/armas_novas.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var sinais := {}


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func ate(cond: Callable, max_passos: int) -> int:
	for i in max_passos:
		if cond.call():
			return i
		w.avancar(PASSO)
	return -1 if not cond.call() else max_passos


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.correr_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	w.combate.cartas.rng.seed = 12345
	sinais.clear()
	passos(3)


func monstro_a(dx: float, dy := 0.0, nome := "inimigo_cao_ossos", vida := 100000.0):
	var m = w.nascer_monstro(nome, w.heroi.pos + Vector2(dx, dy))
	m.vida_max = vida
	m.vida = vida
	m.atordoa_t = 0.0
	return m


## Pega a carta `id` na raridade `rar` (0 a 3) e aplica.
func pegar(id: String, rar := 0) -> Dictionary:
	var cs = w.combate.cartas
	var c: Dictionary = cs.montar_carta(cs.definicao(id), rar)
	cs.aplicar(c)
	return c


## O nome da elite pelo elenco do mapa (o do tipo que tem o sprite dela): muda de mapa para mapa (#430).
func _nome_elite(e) -> String:
	for t in w.elenco.elites_lista:
		if t.sprite == e.chave:
			return str(t.nome)
	return ""


func conta(nome: String) -> int:
	return int(sinais.get(nome, 0))


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	for nome in ["onda_forte", "elite_apareceu", "chefe_apareceu", "chefe_vida", "evolucao", "anuncio", "partida_terminou"]:
		ok(w.has_signal(nome), "sinal %s existe" % nome)
	w.evolucao.connect(
		func(n, d):
			sinais["evolucao"] = conta("evolucao") + 1
			sinais["evolucao_nome"] = n
			sinais["evolucao_desc"] = d
	)
	w.elite_apareceu.connect(
		func(n):
			sinais["elite"] = conta("elite") + 1
			sinais["elite_nome"] = n
	)
	w.chefe_apareceu.connect(
		func(n, v):
			sinais["chefe"] = conta("chefe") + 1
			sinais["chefe_nome"] = n
			sinais["chefe_vida_max"] = v
	)
	w.chefe_vida.connect(
		func(v):
			sinais["chefe_vida"] = conta("chefe_vida") + 1
			sinais["chefe_vida_ultima"] = v
	)
	w.anuncio.connect(
		func(t, _c):
			sinais["anuncio"] = conta("anuncio") + 1
			sinais["anuncio_texto"] = t
	)
	w.onda_forte.connect(
		func(n):
			sinais["onda"] = conta("onda") + 1
			sinais["onda_n"] = n
	)
	w.partida_terminou.connect(
		func(r):
			sinais["fim"] = conta("fim") + 1
			sinais["fim_res"] = r
	)
	var cs = w.combate.cartas
	var cfg: Dictionary = cs.cfg

	# 0. dados
	ok(str(cfg.get("_ajuda", "")) != "", "v2_cartas.json tem _ajuda")
	ok(
		cfg.raridades.size() == 4 and cfg.golpes.size() == 52 and cfg.modificadores.size() == 8,
		"4 raridades, 52 golpes secundários e 8 modificadores (4 de sempre, 2 do Nick e 2 do Luke, que só saem para eles)"
	)
	ok(cfg.evolucoes.size() == 27, "27 evoluções nos dados (4 antigas, 5 novas, 16 de 2, 3 e 4 peças e 2 da leva 6)")
	ok(cfg.chefes.marcas.size() == 3, "3 fichas de chefe (2 mini-chefes e o chefão)")

	# 1. a raridade sobe com o nível
	zerar()
	var alta1: float = cs.chance_raridade(2, 1) + cs.chance_raridade(3, 1)
	var alta20: float = cs.chance_raridade(2, 20) + cs.chance_raridade(3, 20)
	ok(alta20 > alta1 * 4.0, "épico e lendário ficam bem mais prováveis no nível 20 (%.3f contra %.3f)" % [alta20, alta1])
	ok(cs.chance_raridade(0, 20) < cs.chance_raridade(0, 1), "a comum cai com o nível")
	var soma1 := 0
	var soma20 := 0
	for i in 3000:
		soma1 += cs.sortear_raridade(1)
		soma20 += cs.sortear_raridade(20)
	ok(soma20 > soma1 * 2, "sorteando, a raridade média sobe do nível 1 ao 20 (%d contra %d)" % [soma1, soma20])
	var bau_soma := 0
	for i in 3000:
		bau_soma += cs.sortear_raridade(1, float(cfg.bau.bonus_raridade))
	ok(bau_soma > soma1, "o baú favorece as raridades altas")
	var total := 0.0
	for i in 4:
		total += cs.chance_raridade(i, 7)
	ok(absf(total - 1.0) < 0.001, "as chances somam 1")
	# a raridade muda o número da carta e a cor
	var c0: Dictionary = cs.montar_carta(cs.definicao("dano"), 0)
	var c3: Dictionary = cs.montar_carta(cs.definicao("dano"), 3)
	ok(c3.valor > c0.valor * 2.5 and c3.desc != c0.desc, "o lendário dá bem mais que o comum (%s contra %s)" % [c3.desc, c0.desc])
	ok(c0.cor != c3.cor and c0.rar_nome == "Comum" and c3.rar_nome == "Lendário", "cada raridade tem a sua cor e nome")
	# sorteio: 3 cartas diferentes
	var tres: Array = cs.sortear(3, 5)
	var ids := {}
	for c in tres:
		ids[c.id] = true
	ok(tres.size() == 3 and ids.size() == 3, "o sorteio traz 3 cartas diferentes")
	# o começo da build: sem golpe nenhum, o nível 1 traz pelo menos um golpe secundário
	var sem_golpe := 0
	for i in 60:
		var t3: Array = cs.sortear(3, 1)
		var tem := false
		for c in t3:
			if c.cat == "golpe":
				tem = true
		if not tem:
			sem_golpe += 1
	ok(sem_golpe == 0, "no começo a escolha sempre traz um golpe secundário")

	# 2. escolha de nível: rerrolar (1x por tela) e banir
	zerar()
	var h = w.heroi
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	ate(func(): return w.combate.jogo == "escolha", 120)
	ok(w.combate.jogo == "escolha" and w.combate.progresso.cartas.size() == 3, "a escolha abre com 3 cartas")
	var antes_ids: Array = []
	for c in w.combate.progresso.cartas:
		antes_ids.append(c.id)
	ok(w.combate.progresso.rerrolar(), "rerrolar funciona uma vez")
	var depois_ids: Array = []
	for c in w.combate.progresso.cartas:
		depois_ids.append(c.id)
	var repetiu := false
	for id in depois_ids:
		if antes_ids.has(id):
			repetiu = true
	ok(not repetiu, "as cartas rerroladas são novas")
	ok(not w.combate.progresso.rerrolar(), "só 1 rerrolar por tela")
	ok(cs.rerrolar_usados == 1, "o rerrolar gasta um uso da partida")
	var alvo_ban: String = w.combate.progresso.cartas[1].id
	ok(w.combate.progresso.banir(1), "banir funciona")
	ok(w.combate.progresso.cartas.size() == 3 and not _tem_id(w.combate.progresso.cartas, alvo_ban), "a carta banida some e outra toma o lugar")
	var voltou := false
	for i in 80:
		if _tem_id(cs.sortear(3, 5), alvo_ban):
			voltou = true
	ok(not voltou, "a carta banida nunca mais sai")
	# 2b. carta escondida até ter efeito (oculta_ate_ter_efeito em dados/v2_cartas.json) não sai no sorteio, e volta sem a flag
	var escondida: Dictionary = cs.definicao("critico")
	var tinha: bool = cs.disponiveis().has(escondida)
	ok(tinha, "a carta de teste (critico) começa disponível no sorteio")
	escondida["oculta_ate_ter_efeito"] = true
	ok(not cs.disponiveis().has(escondida), "a carta escondida sai da lista de disponíveis")
	var saiu_escondida := false
	for i in 80:
		if _tem_id(cs.sortear(3, 5), "critico"):
			saiu_escondida = true
	ok(not saiu_escondida, "a carta escondida nunca sai no sorteio")
	escondida.erase("oculta_ate_ter_efeito")
	ok(cs.disponiveis().has(escondida), "sem a flag a carta volta a ficar disponível")
	ok(w.combate.progresso.banir(0) and not w.combate.progresso.banir(0), "os banimentos acabam (%d no total)" % int(cfg.escolha.banir_total))
	w.combate.progresso.escolher(0)
	ok(not w.combate.pausado and w.combate.jogo == "jogando", "escolher fecha a tela")

	# 3. os 5 golpes secundários acertam
	var casos := {
		"laminas": ["orbita", 36.0],
		"aura_fogo": ["aura", 30.0],
		"corvos": ["corvos", 70.0],
		"raio": ["raio", 90.0],
		"runa": ["runa", 70.0],
	}
	for id in casos:
		zerar()
		var tipo: String = casos[id][0]
		var m = monstro_a(float(casos[id][1]), 0.0)
		m.cacador = false
		m.raio_vaga = 0.0
		pegar(id, 0)
		ok(w.combate.armas.tem(id), "o golpe %s entra pela carta" % id)
		var v0: float = m.vida
		ate(func(): return int(w.combate.armas.acertos.get(tipo, 0)) > 0, 900)
		ok(
			int(w.combate.armas.acertos.get(tipo, 0)) > 0 and m.vida < v0,
			"o golpe %s (%s) acerta o monstro (vida %d de %d)" % [id, tipo, roundi(m.vida), roundi(v0)]
		)
	# 3b. os golpes novos (leva 5): o primeiro de cada tipo novo acerta (o meteoro conta como "explode", o estouro da explosão)
	var vistos := {}
	# sorteio fixo: com algumas sementes o Lobo Espiritual nasce em cima do monstro e não ataca (bug do aliado, ver LOGBOOK 19/10); antes o teste dependia da sorte
	seed(7)  # era 3; mudou quando o tremor da câmera passou a ter sorteio próprio (camera_mundo._rng) e deixou de gastar o randf() global
	for d in cfg.golpes:
		var tp := str(d.tipo)
		if tp in ["orbita", "aura", "corvos", "raio", "runa"] or vistos.has(tp):
			continue
		vistos[tp] = true
		var chave := {"meteoro": "explode", "torre": "projetil"}.get(tp, tp) as String  # o meteoro conta como "explode"; o virote da torre, como "projetil"
		zerar()
		var mn = monstro_a(60.0, 0.0)
		mn.cacador = false
		mn.raio_vaga = 0.0
		pegar(str(d.id), 0)
		ok(w.combate.armas.tem(str(d.id)), "o golpe novo %s entra pela carta" % str(d.id))
		var vn: float = mn.vida
		ate(func(): return mn.vida < vn, 1200)
		var ac := int(w.combate.armas.acertos.get(chave, 0))
		ok(
			ac > 0 and mn.vida < vn,
			(
				"o golpe novo %s (%s) acerta o monstro (acertos %d, vida %d de %d, perto %d, ativos %s)"
				% [str(d.id), tp, ac, roundi(mn.vida), roundi(vn), w.combate.armas._perto.size(), str(w.combate.armas.novas.tem_ativos())]
			)
		)
	ok(vistos.size() == 7, "os 7 tipos novos estão nos dados (%d)" % vistos.size())
	# 3c. nuvens têm motivos, fades e feedback ligado à vida removida
	ok(
		(
			ArmasNovas.motivo_nuvem("nevoa_espectral") == "espectros"
			and ArmasNovas.motivo_nuvem("nuvem_veneno") == "bolhas"
			and ArmasNovas.motivo_nuvem("nevoeiro_gelado") == "cristais"
			and ArmasNovas.motivo_nuvem("cinzas_vulcanicas") == "brasas"
			and ArmasNovas.motivo_nuvem("cortina_sangue") == "sangue"
			and ArmasNovas.motivo_nuvem("fumaca_sonolenta") == "sono"
		),
		"cada nuvem escolhe o motivo animado do seu elemento"
	)
	ok(
		(
			ArmasNovas.opacidade_nuvem(4.0, 4.0) == 0.0
			and is_equal_approx(ArmasNovas.opacidade_nuvem(2.0, 4.0), 1.0)
			and ArmasNovas.opacidade_nuvem(0.0, 4.0) == 0.0
		),
		"a nuvem surge e desaparece com fade sem alterar sua duração"
	)
	ok(w.combate.armas.novas.itens.size() == ArmasNovas.MAX, "efeitos usam o pool fixo de 48 slots")
	zerar()
	var mn_nuvem = monstro_a(0.0, 0.0)
	var arma_nuvem := {"id": "nevoa_espectral", "st": {"dano": 8.0, "tique": 0.5, "duracao": 4.0, "lentidao": 0.4}, "cor": Color(0.8, 0.95, 0.95)}
	var camada_nuvem = w.combate.armas.novas
	var slot_nuvem: Dictionary = camada_nuvem._novo("nuvem", arma_nuvem, mn_nuvem.pos, 4.0)
	slot_nuvem.r = 50.0
	slot_nuvem.t = 0.01
	var vida_nuvem: float = mn_nuvem.vida
	camada_nuvem._tique_nuvem(slot_nuvem, PASSO)
	ok(mn_nuvem.vida < vida_nuvem and slot_nuvem.pulso > 0.0 and mn_nuvem.lento_t > 0.0, "o pulso aparece com dano real e preserva a lentidão da nuvem")
	slot_nuvem.t = 0.01
	camada_nuvem._tique_nuvem(slot_nuvem, PASSO)
	ok(slot_nuvem.pulso > 0.0 and int(w.combate.armas.acertos.get("nuvem", 0)) == 2, "cada tique real renova um pulso e conta um acerto de área")
	zerar()
	var nuvem_vazia := {"id": "nevoa_espectral", "st": {"dano": 8.0, "tique": 0.5, "duracao": 4.0, "lentidao": 0.0}, "cor": Color(0.8, 0.95, 0.95)}
	var slot_vazio: Dictionary = w.combate.armas.novas._novo("nuvem", nuvem_vazia, w.heroi.pos, 4.0)
	slot_vazio.r = 50.0
	slot_vazio.t = 0.01
	w.combate.armas.novas._tique_nuvem(slot_vazio, PASSO)
	ok(slot_vazio.pulso == 0.0 and int(w.combate.armas.acertos.get("nuvem", 0)) == 0, "sem vida removida a névoa não pulsa nem anuncia acerto")
	var imune = monstro_a(0.0, 0.0)
	imune.morrendo = true
	var nuvem_sem_hit := {
		"id": "nevoeiro_gelado", "st": {"dano": 8.0, "tique": 0.5, "duracao": 4.0, "lentidao": 0.4, "gelo_mult": 2.0}, "cor": Color(0.2, 0.55, 1.0)
	}
	var slot_sem_hit: Dictionary = w.combate.armas.novas._novo("nuvem", nuvem_sem_hit, imune.pos, 4.0)
	slot_sem_hit.r = 50.0
	slot_sem_hit.t = 0.01
	w.combate.armas.novas._tique_nuvem(slot_sem_hit, PASSO)
	ok(slot_sem_hit.pulso == 0.0, "alvo imune ou morrendo nunca acende o pulso de acerto")
	zerar()
	var lento = monstro_a(0.0, 0.0)
	lento.lento_t = 1.0
	var nuvem_gelo := {
		"id": "nevoeiro_gelado", "st": {"dano": 8.0, "tique": 0.5, "duracao": 4.0, "lentidao": 0.4, "gelo_mult": 2.0}, "cor": Color(0.2, 0.55, 1.0)
	}
	var slot_gelo: Dictionary = w.combate.armas.novas._novo("nuvem", nuvem_gelo, lento.pos, 4.0)
	slot_gelo.r = 50.0
	slot_gelo.t = 0.01
	var vida_gelo: float = lento.vida
	w.combate.armas.novas._tique_nuvem(slot_gelo, PASSO)
	ok(
		vida_gelo - lento.vida >= 16.0 and lento.lento_t >= 1.0 and slot_gelo.pulso > 0.0,
		"o gelo dobra o dano no alvo lento, renova a lentidão e conta o impacto real"
	)
	# a aura queima, as lâminas passam, o raio salta
	zerar()
	var ma = monstro_a(30.0, 0.0)
	pegar("aura_fogo", 0)
	ate(func(): return ma.queima_t > 0.0, 200)
	ok(ma.queima_t > 0.0, "a aura de fogo deixa o monstro queimando")
	var vq: float = ma.vida
	passos(60)
	ok(ma.vida < vq, "o fogo continua tirando vida")
	zerar()
	var r1 = monstro_a(70.0, 0.0)
	var r2 = monstro_a(110.0, 10.0)
	var r3 = monstro_a(140.0, -10.0)
	for rr in [r1, r2, r3]:
		rr.cacador = false
		rr.raio_vaga = 0.0
	pegar("raio", 0)
	ate(func(): return r3.vida < r3.vida_max, 300)
	ok(r1.vida < r1.vida_max and r2.vida < r2.vida_max, "o raio em cadeia pula para os vizinhos")
	# nível e raridade do golpe
	zerar()
	var cg: Dictionary = cs.montar_carta(cs.definicao("laminas"), 3)
	cs.aplicar(cg)
	ok(cs.nivel_de("laminas") == 2, "a carta lendária de golpe sobe 2 níveis")
	for i in 4:
		cs.aplicar(cs.montar_carta(cs.definicao("laminas"), 0))
	ok(cs.nivel_de("laminas") == 5 and int(w.combate.armas.ativas["laminas"].st.quantidade) >= 4, "o golpe chega ao nível 5 com mais lâminas")
	ok(not _tem_id(cs.sortear(3, 5), "laminas") or cs.nivel_de("laminas") < 5, "no nível máximo a carta deixa de sair")

	# 4. modificadores da katana
	zerar()
	var mo = monstro_a(110.0, 0.0)
	mo.cacador = false
	mo.raio_vaga = 0.0
	pegar("onda", 0)
	h = w.heroi
	h.ataque_forcado = true
	ate(func(): return int(w.combate.armas.acertos.get("onda", 0)) > 0, 300)
	ok(int(w.combate.armas.acertos.get("onda", 0)) > 0 and mo.vida < mo.vida_max, "o corte solta uma onda que acerta de longe")
	h.ataque_forcado = null
	zerar()
	var ml = monstro_a(120.0, 0.0)
	ml.cacador = false
	ml.raio_vaga = 0.0
	pegar("fura", 0)
	w.combate.armas.lancar_lanca(w.heroi.pos + w.heroi.ORIGEM_GOLPE, Vector2.RIGHT, 40.0)
	passos(40)
	ok(int(w.combate.armas.acertos.get("lanca", 0)) > 0 and ml.vida < ml.vida_max, "a lança da estocada atravessa e acerta")
	zerar()
	var m1 = monstro_a(30.0, 0.0)
	var m2 = monstro_a(40.0, 6.0)
	m1.cacador = false
	m2.cacador = false
	m1.raio_vaga = 0.0
	m2.raio_vaga = 0.0
	pegar("explode", 0)
	w.heroi.m_critico = 5.0
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	w.heroi.ataque_forcado = true
	ate(func(): return int(w.combate.armas.acertos.get("explode", 0)) > 0, 300)
	ok(int(w.combate.armas.acertos.get("explode", 0)) > 0, "o crítico explode e fere quem está em volta")
	zerar()
	var mf = monstro_a(30.0, 0.0, "inimigo_cao_ossos", 5.0)
	mf.cacador = false
	pegar("folego", 0)
	w.heroi.folego = 1.0
	w.combate.ferir(mf, 100.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	w.combate.processar_mortes()
	ok(w.heroi.folego > 1.05, "matar devolve fôlego (%.2f)" % w.heroi.folego)

	# 5. evoluções
	zerar()
	ok(not cs._pesos_sinergia().has("laminas"), "sem nenhuma peça, a outra peça não pesa mais no sorteio")
	pegar("aura_fogo", 0)
	var sin: Dictionary = cs._pesos_sinergia()
	ok(
		float(sin.get("laminas", 1.0)) == float(cs.cfg.escolha.peso_sinergia) and not sin.has("aura_fogo"),
		"com a aura, as lâminas (a peça que falta) pesam peso_sinergia no sorteio e a aura não"
	)
	pegar("aura_fogo", 0)
	pegar("laminas", 0)
	pegar("laminas", 0)
	ok(cs.evoluidas.is_empty(), "com as peças no nível 2 ainda não evolui")
	pegar("aura_fogo", 0)
	ok(cs.evoluidas.is_empty(), "com uma peça só ainda não evolui")
	pegar("laminas", 0)
	ok(cs.evoluidas.has("anel_de_brasas"), "aura de fogo 3 + lâminas 3 viram o Anel de Brasas")
	ok(
		w.combate.armas.tem("anel_de_brasas") and not w.combate.armas.tem("laminas") and not w.combate.armas.tem("aura_fogo"),
		"as duas peças somem e fica a evoluída"
	)
	ok(conta("evolucao") == 1 and str(sinais.get("evolucao_nome", "")) == "Anel de Brasas", "sinal evolucao(nome) com o nome certo")
	var me = monstro_a(40.0, 0.0)
	me.cacador = false
	ate(func(): return me.vida < me.vida_max, 200)
	ok(me.vida < me.vida_max and me.queima_t > 0.0, "o Anel de Brasas fere e queima")
	ok(not _tem_id(cs.sortear(3, 8), "laminas") and not _tem_id(cs.sortear(3, 8), "aura_fogo"), "as peças consumidas não saem mais")
	zerar()
	for i in 3:
		pegar("corvos", 0)
		pegar("raio", 0)
	ok(cs.evoluidas.has("revoada_de_trovoes") and w.combate.armas.tem("revoada_de_trovoes"), "corvos 3 + raio 3 viram a Revoada de Trovões")
	# 5b. as 5 fusões novas (leva 5): duas peças no nível 3 viram a evolução e as peças somem
	var fusoes := [
		["dragao_filhote", "serpente_ardente", "dragao_de_brasa"],
		["lobo_espirito", "espirito_raposa", "cacada_espiritual"],
		["espirito_urso", "raio_solar", "urso_solar"],
		["esqueleto_guerreiro", "fantasma_mata", "exercito_esquecido"],
		["golem_barro", "guardiao_pedra", "colosso_de_pedra"],
	]
	for f in fusoes:
		zerar()
		for i in 3:
			pegar(f[0], 0)
			pegar(f[1], 0)
		ok(cs.evoluidas.has(f[2]) and w.combate.armas.tem(f[2]), "%s e %s viram %s" % [f[0], f[1], f[2]])
		ok(not w.combate.armas.tem(f[0]) and not w.combate.armas.tem(f[1]), "as peças de %s somem" % f[2])
	zerar()
	for i in 3:
		pegar("runa", 0)
	for i in 2:
		pegar("explode", 0)
	ok(
		cs.evoluidas.has("circulo_runico") and w.combate.armas.tem("circulo_runico") and cs.ativa("explode"),
		"runa 3 + crítico explosivo 2 viram o Círculo Rúnico (o modificador fica)"
	)
	zerar()
	for i in 2:
		pegar("onda", 0)
		pegar("fura", 0)
	ok(cs.evoluidas.has("ventania") and not w.combate.armas.ventania.is_empty(), "onda 2 + estocada perfurante 2 viram a Ventania Cortante")
	# 5c. as 16 fusões novas (comuns, raras e lendárias) viram arma, com o tipo certo, e só uma lendária por partida
	for ev in cfg.evolucoes.slice(9):
		zerar()
		cs.evoluir(ev)
		ok(w.combate.armas.tem(str(ev.id)), "%s (%s) vira arma" % [ev.nome, ev.tipo])
	zerar()
	var lendarias: Array = cfg.evolucoes.filter(func(e): return str(e.get("raridade", "")) == "lendario")
	ok(lendarias.size() == 4, "4 fusões lendárias nos dados")
	zerar()
	cs.evoluir(lendarias[0])
	var mecanica: Dictionary = w.combate.armas.ativas.get(str(lendarias[0].id), {}).get("st", {})
	ok(mecanica.has("puxa") or mecanica.has("prende") or mecanica.has("cadeia") or mecanica.has("gelo_mult"), "a lendária tem mecânica própria")
	ok(cs.lendarias_feitas == 1 and not cs._evo_livre(lendarias[1]), "depois de uma lendária, as outras ficam fora da partida")
	zerar()
	ok(cs.lendarias_feitas == 0 and cs._evo_livre(lendarias[1]), "jogar de novo libera a lendária")
	zerar()
	ok(cs.evoluidas.is_empty() and w.combate.armas.ativas.is_empty() and w.combate.armas.ventania.is_empty(), "jogar de novo zera a build")

	# 6. elite com contorno solta baú; baú dá de 1 a 3 melhorias de graça
	zerar()
	h = w.heroi
	var el = w.combate.elites.nascer("inimigo_cao_ossos", "blindado", h.pos + Vector2(120, 0))
	ok(
		el != null and el.elite and el.escala > 1.3 and el.vida_max > 100.0,
		"a elite nasce maior e com mais vida (%.1fx, %d de vida)" % [el.escala, roundi(el.vida_max)]
	)
	ok(el.contorno != null and el.contorno.visible, "a elite tem o contorno colorido")
	ok(
		conta("elite") == 1 and str(sinais.get("elite_nome", "")) == "%s Blindado" % _nome_elite(el),
		"sinal elite_apareceu(nome): %s" % str(sinais.get("elite_nome", ""))
	)
	passos(5)
	w.combate.ferir(el, 9999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	w.combate.processar_mortes()
	ok(not el.vivo and not el.contorno.visible, "a elite morre e o contorno some")
	ok(w.combate.baus.ativos() == 1, "a elite solta um baú")
	var bau_pos: Vector2 = w.combate.baus.lista.filter(func(b): return b.ativo)[0].pos
	passos(30)
	var estado_antes := _total_cartas()
	h.entrada_forcada = Vector2.ZERO
	h.definir_pos(bau_pos)
	ate(func(): return w.combate.jogo == "bau", 120)
	ok(w.combate.jogo == "bau" and w.combate.pausado and w.combate.telas.bau_aberto, "encostar no baú abre a roleta e para o mundo")
	var n_bau: int = w.combate.baus.ultimas.size()
	ok(n_bau >= 1 and n_bau <= 3, "o baú dá de 1 a 3 melhorias (%d)" % n_bau)
	ok(_total_cartas() > estado_antes, "as melhorias do baú já valem")
	var tp := float(w.tempo_partida)
	passos(30)
	ok(w.tempo_partida == tp, "durante a roleta o mundo está parado")
	ate(func(): return w.combate.telas.bau_pronto, 900)
	ok(w.combate.telas.bau_pronto, "a roleta termina sozinha")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	w._input(enter)
	ok(w.combate.jogo == "jogando" and not w.combate.pausado and not w.combate.telas.bau_aberto, "Enter fecha a roleta e o jogo volta")
	# pular a roleta (sem orbes de XP voando: um nível novo abriria a escolha)
	w.combate.orbes.limpar()
	h.xp = 0.0
	w.combate.baus.soltar(h.pos + Vector2(40, 0), 1.0, 3)
	h.definir_pos(h.pos + Vector2(40, 0))
	ate(func(): return w.combate.jogo == "bau", 120)
	ok(w.combate.baus.ultimas.size() >= 1 and w.combate.jogo == "bau", "baú forçado a 3 melhorias abre")
	w._input(enter)  # dentro da trava de 1,5 s do baú: descartado (não pula)
	ok(w.combate.telas.bau_aberto and not w.combate.telas.bau_pronto, "Enter na trava de 1,5 s do baú é descartado")
	passos(92)  # 1,53 s de tempo real: a trava passou
	w._input(enter)
	ok(w.combate.telas.bau_pronto, "Enter depois da trava revela tudo na hora")
	w._input(enter)
	ok(w.combate.jogo == "jogando", "e o próximo Enter fecha")
	# os outros modificadores da elite
	zerar()
	var ex = w.combate.elites.nascer("inimigo_cao_ossos", "explosivo", w.heroi.pos + Vector2(150, 0))
	w.combate.ferir(ex, 9999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	w.combate.processar_mortes()
	ok(w.combate.avisos.ativos() >= 1, "a elite explosiva anuncia a explosão no chão ao morrer")
	zerar()
	var inv = w.combate.elites.nascer("inimigo_cao_ossos", "invoca", w.heroi.pos + Vector2(150, 0))
	inv.invoca_t = 0.1
	var vivos0: int = w.monstros.size()
	passos(30)
	ok(w.monstros.size() > vivos0, "a elite invocadora chama monstros")
	zerar()
	var rap = w.combate.elites.nascer("inimigo_lobo_sombrio", "rapido", w.heroi.pos + Vector2(150, 0))
	ok(rap.vel_mult > 1.4, "a elite veloz é mais rápida")
	# o diretor faz nascer elites sozinho
	zerar()
	w.combate.diretor.ligado = true
	w.tempo_partida = float(cfg.elites.primeira) + 1.0
	ate(func(): return w.combate.elites.nascidas > 0, 400)
	ok(w.combate.elites.nascidas > 0, "a primeira elite nasce sozinha depois de %d s" % int(cfg.elites.primeira))

	# 9. derrota: partida_terminou com venceu = false
	var res: Dictionary = {}
	zerar()
	w.heroi.imortal = false
	w.abates = 12
	w.maior_combo = 9
	w.xp_coletado = 47.0
	w.tempo_partida = 75.0
	w.heroi.vida = 1.0
	var mm = monstro_a(14.0, 0.0, "inimigo_cao_ossos", 50.0)
	mm.cacador = true
	ate(func(): return w.combate.jogo == "morte", 400)
	ok(w.combate.jogo == "morte" and w.combate.telas._res_titulo.text == "VOCÊ CAIU", "morrer mostra VOCÊ CAIU")
	res = sinais.get("fim_res", {})
	ok(conta("fim") == 1 and res.get("venceu") == false, "partida_terminou na derrota (venceu = false)")
	ok(int(res.get("abates", 0)) == 12 and int(res.get("maior_combo", 0)) == 9 and int(res.get("almas", -1)) == 5, "abates, combo e almas (47 / 10 = 5)")
	ok(absf(float(res.get("tempo", 0.0)) - 75.0) < 3.0, "tempo da derrota ~75 s (%.1f)" % float(res.get("tempo", 0.0)))
	zerar()
	ok(w.xp_coletado == 0.0 and w.almas_partida == 0 and w.resultado.is_empty(), "jogar de novo zera as almas")
	w.xp_coletado = 14.0
	ok(w.almas_partida == 1, "14 de XP viram 1 alma")
	w.xp_coletado = 15.0
	ok(w.almas_partida == 2, "15 de XP arredondam para 2 almas")

	# 10. números de dano maiores
	zerar()
	var mn = monstro_a(30.0, 0.0)
	mn.cacador = false
	w.combate.fx.n_tam.fill(0)
	w.combate.ferir(mn, 10.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	ok(w.combate.fx.n_tam.has(16), "o número de dano normal tem 16 px")

	# 11. bônus do santuário (mundo.meta_bonus): raridade melhor e rolagem a mais
	zerar()
	var base_soma := 0
	var meta_soma := 0
	w.meta_bonus = {"raridade": 0.0, "rolagem": 0, "almas": 0.0}
	for i in 3000:
		base_soma += cs.sortear_raridade(1)
	ok(cs.rerrolar_total() == int(cfg.escolha.rerrolar_total), "sem bônus, o total de rerrolar é o dos dados")
	w.meta_bonus = {"raridade": 0.5, "rolagem": 2, "almas": 0.0}
	for i in 3000:
		meta_soma += cs.sortear_raridade(1)
	ok(meta_soma > base_soma * 2, "o bônus de raridade do santuário melhora as cartas (%d contra %d)" % [meta_soma, base_soma])
	ok(cs.rerrolar_total() == int(cfg.escolha.rerrolar_total) + 2 and cs.rerrolar_por_tela() == 3, "o bônus de rolagem soma rerrolares")
	w.meta_bonus = {}

	# 5b2. (leva 6) a receita à vista: a carta de uma peça diz com quem junta e o que sai; a fusão pede o cartão grande e câmera lenta
	zerar()
	pegar("aura_fogo", 0)
	pegar("aura_fogo", 0)
	var dica := str(cs.montar_carta(cs.definicao("aura_fogo"), 0).get("evolui", ""))
	ok(dica == "Lâminas nv3 » FUSÃO Anel", "a aura nv 2 mostra a receita da fusão (%s)" % dica)
	ok(str(cs.montar_carta(cs.definicao("laminas"), 0).get("evolui", "")) == "Aura nv3 » FUSÃO Anel", "as lâminas mostram a receita espelhada")
	for i in 1:
		pegar("aura_fogo", 0)
	pegar("laminas", 0)
	pegar("laminas", 0)
	ok(not cs.evoluidas.has("anel_de_brasas"), "com a aura no 3 e as lâminas no 2 a fusão ainda não acontece")
	pegar("laminas", 0)
	ok(cs.evoluidas.has("anel_de_brasas"), "lâminas no 3 fecham o Anel de Brasas")
	ok(str(sinais.get("evolucao_desc", "")).contains("Seis lâminas"), "o sinal da fusão leva o que ela faz para o cartão grande")
	ok(w.combate.lento_acao == "fusao" and w.combate.lento_escala < 1.0, "a fusão pede câmera lenta (%s)" % w.combate.lento_acao)
	# o ganho de poder da Ventania: a onda de 80% (2 cartas comuns) vira 80% x 2,4 = 192% do dano do corte (antes 1,9 = 152%)
	zerar()
	pegar("onda", 0)
	pegar("onda", 0)
	pegar("fura", 0)
	pegar("fura", 0)
	ok(absf(w.combate.armas.pct_onda() - 80.0 * 2.4) < 0.001, "a Ventania leva a onda a 80%% x 2,4 (%s)" % w.combate.armas.pct_onda())
	print("v2_partida falhas=%d" % falhas)
	get_tree().quit()


func _tem_id(lista: Array, id: String) -> bool:
	for c in lista:
		if str(c.id) == id:
			return true
	return false


func _total_cartas() -> int:
	var n := 0
	for id in w.combate.cartas.estado:
		n += int(w.combate.cartas.estado[id].n)
	return n
