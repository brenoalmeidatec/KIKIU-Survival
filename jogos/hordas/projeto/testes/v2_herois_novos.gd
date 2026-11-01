extends "res://testes/isolamento_v2.gd"
# Teste dos cinco heróis novos do PER-3 (#509): Matthew (shuriken com ricochete), John (naginata), Bert (kusarigama que puxa), Lukako (tessen que
# solta vento) e Fabian (arco). Separado do v2_herois porque o CI dá 120 s por cena e os dois juntos estouravam. Confere: o JSON (folha própria ou
# a do Hazaki, passos que cabem nos golpes da folha, DPS entre 80% e 120% do Hazaki, uma arma por herói), a migração do save antigo (o herói vale
# pelo NOME), o combate de cada um (ricochete, alcance, puxão, giro, vento, flecha que atravessa), as cartas exclusivas por herói e o card SUA BUILD.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_herois_novos.tscn  (imprime "v2_herois_novos falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Personagens := preload("res://v2/personagens.gd")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Meta := preload("res://v2/meta.gd")
const Status := preload("res://v2/status.gd")
const SAVE_TESTE := "user://testes_v2/v2_herois_novos/teste_v2_herois_novos.cfg"
const INDICE_TESTE := "user://testes_v2/v2_herois_novos/teste_v2_herois_novos_indice.cfg"
const PREFIXO_TESTE := "user://testes_v2/v2_herois_novos/teste_v2_herois_novos_p"
const ANTIGO_TESTE := "user://testes_v2/v2_herois_novos/teste_v2_herois_novos_antigo.cfg"
const PASSO := 1.0 / 60.0
const PASTA_SPRITES := "res://prototipos/cara_nova/sprites/"
const NOVOS := ["matheus", "joao", "beto", "lukako", "fabio"]

var falhas := 0
var w


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


func _apagar_save() -> void:
	var alvos := [SAVE_TESTE, INDICE_TESTE]
	for i in range(1, 6):
		alvos.append(Personagens.caminho_do_save("p%d" % i))
		alvos.append(Personagens.caminho_do_save("p%d" % i) + ".bak")
	for c in alvos:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))


## Um mundo novo com o herói `id` (a escolha vai pelo mesmo caminho do jogo, sem passar pelo salão).
func novo(id: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true


## Mapa sem monstros, herói imortal e parado, sem diretor nem crítico (o dano fica previsível), mouse à direita.
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.heroi.m_critico = -1.0
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	passos(3)


func monstro_a(dx: float, dy := 0.0, nome := "inimigo_espantalho"):
	var m = w.nascer_monstro(nome, w.heroi.pos + Vector2(dx, dy))
	m.atordoa_t = 0.0
	return m


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	Personagens.caminho_indice = INDICE_TESTE
	Personagens.caminho_base = PREFIXO_TESTE
	Personagens.caminho_antigo = ANTIGO_TESTE
	_apagar_save()
	await _testes()
	_apagar_save()
	Herois.forcado = ""
	print("v2_herois_novos falhas=%d" % falhas)
	get_tree().quit()


func _testes() -> void:
	_t_dados_novos()
	_t_migracao()
	await _t_novos()
	await _t_cartas_novos()
	await _t_card_novos()


# ------------------------------------------------------------------ dados e migração


## PER-3: cada herói novo tem folha (a própria ou a do Hazaki), arma própria, combo que cabe na folha e DPS parecido com o do Hazaki.
func _dps(id: String) -> float:
	var dano := 0.0
	var dur := 0.0
	for p in Herois.heroi(id).cfg.golpe.passos:
		dano += float(p.dano) * float(p.get("n", 1))
		dur += float(p.duracao)
	return dano / dur


func _t_dados_novos() -> void:
	var dps_hazaki := _dps("hazaki")
	ok(absf(dps_hazaki - 51.0 / 0.88) < 0.5, "a conta do DPS bate com a do plano para o Hazaki (%.1f)" % dps_hazaki)
	var armas := {}
	for h in Herois.lista():
		armas[str(h.arma)] = true
	ok(armas.size() == 8, "oito heróis, oito armas diferentes (%s)" % str(armas.keys()))
	var haz_folha: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PASTA_SPRITES + "hazaki_samurai.json"))
	for id in NOVOS:
		var h := Herois.heroi(id)
		ok(str(h.id) == id, "%s: o herói existe" % id)
		var folha: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PASTA_SPRITES + str(h.sprite) + ".json"))
		ok(str(h.sprite) == "hazaki_samurai" or str(h.sprite) == id, "%s: usa a folha própria ou, sem ela, a do Hazaki (%s)" % [id, h.sprite])
		ok(folha.quadro == haz_folha.quadro and folha.animacoes.has("combo"), "%s: a folha tem o quadro e o combo do Hazaki" % id)
		var ps: Array = h.cfg.golpe.passos
		var golpes := int(folha.animacoes.combo.golpes)
		ok(ps.size() >= 2 and ps.size() <= golpes, "%s: %d passos cabem nos %d golpes da folha" % [id, ps.size(), golpes])
		var ranged := str(ps[0].get("tipo", "melee")) == "adagas"
		for p in ps:
			ok(str(p.get("tipo", "melee")) == str(ps[0].get("tipo", "melee")), "%s: todos os passos são do mesmo tipo (corpo a corpo ou projétil)" % id)
		var razao := _dps(id) / dps_hazaki
		ok(razao >= 0.8 and razao <= 1.2, "%s: DPS de %.0f é %.0f%% do Hazaki (80%% a 120%%)" % [id, _dps(id), razao * 100.0])
		if id == "lukako":  # o vento soma uma onda por corte: com ela o DPS continua na faixa
			var com_vento := _dps(id) * (1.0 + float(ps[0].vento)) / dps_hazaki
			ok(com_vento <= 1.2, "%s: com a onda de vento o DPS fica em %.0f%% do Hazaki (até 120%%)" % [id, com_vento * 100.0])
		ok(ranged == (id == "matheus" or id == "fabio"), "%s: projétil só para o Matthew e o Fabian" % id)
		ok(float(h.cfg.heroi.vida) > 0.0 and float(h.cfg.heroi.vel) > 0.0, "%s: vida e velocidade definidas" % id)
	var ps_m: Array = Herois.heroi("matheus").cfg.golpe.passos
	ok(ps_m.size() == 3 and int(ps_m[0].ricochete) == 2 and str(ps_m[0].proj) == "shuriken", "Matthew: 3 lançamentos de shuriken que ricocheteiam 2 vezes")
	var ps_b: Array = Herois.heroi("beto").cfg.golpe.passos
	ok(
		ps_b[0].get("puxa", false) and ps_b[2].get("puxa", false) and not ps_b[1].get("puxa", false) and float(ps_b[1].arco) >= 359.0,
		"Bert: corrente que puxa, giro de 360 graus e corrente que puxa"
	)
	var ps_j: Array = Herois.heroi("joao").cfg.golpe.passos
	var ps_h: Array = Herois.heroi("hazaki").cfg.golpe.passos
	ok(
		float(ps_j[0].alcance) >= float(ps_h[0].alcance) * 1.35 and float(ps_j[2].alcance) >= float(ps_h[2].alcance) * 1.35,
		"John: alcance ~40% maior que o do Hazaki"
	)
	ok(float(Herois.heroi("lukako").cfg.golpe.passos[2].vento) > 0.0, "Lukako: o corte solta vento")
	var ps_f: Array = Herois.heroi("fabio").cfg.golpe.passos
	ok(int(ps_f[0].perfura) == 2 and str(ps_f[0].proj) == "flecha", "Fabian: a flecha atravessa até 3 monstros")
	for nome in ["John", "Matthew", "Bert", "Lukako", "Fabian"]:  # o salão aponta cada nome para o herói dele
		ok(Herois.existe(Personagens.heroi_do_nome(nome)) and Personagens.heroi_do_nome(nome) != "hazaki", "%s: o salão liga o nome a um herói próprio" % nome)


## D04 (#509): o herói vale pelo NOME. Save antigo que gravou o Hazaki para um nome que hoje tem herói próprio passa a jogar com ele.
func _t_migracao() -> void:
	var id_m := Personagens.criar("Matheus", "hazaki")  # como estava no save antigo: nome de antes da troca, herói padrão
	var id_j := Personagens.criar("João", "hazaki")
	var id_b := Personagens.criar("Beto", "hazaki")
	var id_k := Personagens.criar("Lukako", "hazaki")
	var id_f := Personagens.criar("Fábio", "hazaki")
	ok(Personagens.nome(id_m) == "Matthew" and Personagens.heroi(id_m) == "matheus", "save antigo do Matthew (hazaki) passa a jogar de matheus")
	ok(Personagens.heroi(id_j) == "joao" and Personagens.heroi(id_b) == "beto", "e o do John vira joao e o do Bert vira beto")
	ok(Personagens.heroi(id_k) == "lukako" and Personagens.heroi(id_f) == "fabio", "e o da Lukako vira lukako e o do Fabian vira fabio")
	ok(Personagens.ativar(id_m) and Herois.escolhido() == "matheus", "ativar o save migrado faz a partida ser do herói novo")
	ok(Personagens.resumo(id_k).heroi == "lukako", "o resumo do salão mostra o herói migrado")
	var cf := ConfigFile.new()
	cf.load(INDICE_TESTE)
	ok(str(cf.get_value(id_m, "heroi", "")) == "hazaki", "a migração só lê: o índice no disco não foi reescrito")
	_apagar_save()
	var id_h := Personagens.criar("Breno", "hazaki")
	var id_x := Personagens.criar("Matthew", "lucas")  # herói gravado que não é o padrão vale como está
	ok(Personagens.heroi(id_h) == "hazaki", "o Brendan continua de Hazaki")
	ok(Personagens.heroi(id_x) == "lucas", "herói gravado diferente do padrão não é trocado")
	ok(Personagens.heroi("p99") == "hazaki", "slot que não existe cai no padrão")
	_apagar_save()


## Monstro parado no lugar (não anda, não apanha de empurrão) com muita vida: só para contar quem foi atingido.
func _alvo_fixo(dx: float, dy := 0.0):
	var m = monstro_a(dx, dy, "inimigo_cao_ossos")
	m.vida = 1000000
	m.vida_max = m.vida
	m.peso = 1000000
	m.atordoa_t = 9999
	m.raio_vaga = 0
	return m


func _atingidos(lista: Array) -> int:
	var n := 0
	for m in lista:
		n += 1 if m.vida < m.vida_max else 0
	return n


func _t_novos() -> void:
	await _t_matheus_shuriken()
	await _t_joao()
	await _t_beto()
	await _t_lukako()
	await _t_fabio()


func _partida_do(id: String, vida: float, vel: float, tamanho: float) -> void:
	await novo(id)
	var h = w.heroi
	ok(w.combate.heroi_id == id and h.chave == id, "%s: heroi_id e chave da partida" % id)
	ok(h.vida_max == vida and h.vel_base == vel and h.raio == tamanho, "%s: vida %d, %d px/s e raio %d" % [id, vida, vel, tamanho])
	ok(h.tipo.w == 32 and h.tipo.h == 44, "%s: folha de 32x44 (o quadro do Hazaki)" % id)
	w.reiniciar()
	ok(h.vida_max == vida and h.vel_base == vel, "%s: jogar de novo mantém os números" % id)


func _t_matheus_shuriken() -> void:
	await _partida_do("matheus", 80.0, 108.0, 5.0)
	var h = w.heroi
	var ad = w.combate.adagas
	# três monstros em triângulo, a menos de 110 px um do outro: uma estrela acerta os três (2 ricochetes)
	zerar()
	var alvos := [_alvo_fixo(70, 0), _alvo_fixo(110, 60), _alvo_fixo(50, 100)]
	h.atacar()
	ate(func(): return ad.lancadas >= 1, 60)
	ate(func(): return ad.ativas() == 0, 200)
	ok(_atingidos(alvos) == 3, "Matthew: uma estrela ricocheteia e acerta 3 monstros diferentes (%d)" % _atingidos(alvos))
	ok(ad.lancadas == 1 and ad.sumiram == 1, "e foi uma estrela só (lançadas=%d)" % ad.lancadas)


func _t_joao() -> void:
	await _partida_do("joao", 95.0, 96.0, 6.0)
	var h = w.heroi
	zerar()
	var longe = monstro_a(62, 0, "inimigo_cavaleiro_oco")  # a 62 px: o corte da katana (46) não chega, o da naginata (64) sim
	h.atacar()
	ate(func(): return h.golpe_acertou, 80)
	passos(2)
	ok(longe.vida < longe.vida_max, "John acerta quem está a 62 px com o primeiro corte (vida %d de %d)" % [longe.vida, longe.vida_max])
	ok(h.golpe_cfg.nome == "corte", "o primeiro passo é um corte")
	ok(ate(func(): return h.estado == Heroi.Estado.LIVRE, 80) >= 0, "o corte termina")
	var g1: int = h.golpes
	h.atacar()
	ok(
		ate(func(): return h.golpes > g1 and h.golpe_acertou, 80) >= 0 and h.golpe_cfg.nome == "corte" and h.golpe_cfg.lado == -1,
		"2º passo: corte do outro lado"
	)
	ok(ate(func(): return h.estado == Heroi.Estado.LIVRE, 80) >= 0, "o 2º corte termina")
	var g2: int = h.golpes
	h.atacar()
	ok(ate(func(): return h.golpes > g2 and h.golpe_acertou, 80) >= 0 and h.golpe_cfg.nome == "estocada", "3º passo: estocada longa")
	# as cartas da katana valem para ele (onda no corte, lança na estocada)
	zerar()
	var cs = w.combate.cartas
	cs.aplicar(cs.montar_carta(cs.definicao("onda"), 0))
	cs.aplicar(cs.montar_carta(cs.definicao("fura"), 0))
	var l0: int = w.combate.armas.lancadas
	var g3: int = h.golpes
	h.atacar()
	ate(func(): return h.golpes > g3 and h.golpe_acertou, 80)
	ok(w.combate.armas.lancadas == l0 + 1, "John: com a carta Corte ondulante, o corte solta uma onda (%d -> %d)" % [l0, w.combate.armas.lancadas])


func _t_beto() -> void:
	await _partida_do("beto", 110.0, 92.0, 7.0)
	var h = w.heroi
	zerar()
	var frente = monstro_a(70, 0, "inimigo_cavaleiro_oco")
	var atras = monstro_a(-30, 0, "inimigo_cavaleiro_oco")
	var d0: float = frente.pos.x - h.pos.x
	h.atacar()
	ok(ate(func(): return h.golpe_acertou, 80) >= 0 and h.golpe_cfg.nome == "corrente", "1º passo: corrente")
	passos(2)
	ok(frente.vida < frente.vida_max and atras.vida == atras.vida_max, "a corrente acerta quem está na frente e não quem está atrás")
	ok(frente.emp.x < 0.0, "a corrente PUXA: o empurrão aponta para o herói (emp.x=%.0f)" % frente.emp.x)
	passos(25)
	var d1: float = frente.pos.x - h.pos.x
	ok(d1 < d0 - 8.0 and d1 > 0.0, "o monstro chegou mais perto e não passou do herói (%.0f -> %.0f px)" % [d0, d1])
	ok(ate(func(): return h.estado == Heroi.Estado.LIVRE, 80) >= 0, "a corrente termina")
	# o giro acerta em volta toda e empurra para fora (quem estava atrás vai para trás)
	frente.atordoa_t = 0.0
	atras.atordoa_t = 0.0
	var g1: int = h.golpes
	var v_atras: float = atras.vida
	h.atacar()
	ok(ate(func(): return h.golpes > g1 and h.golpe_acertou, 80) >= 0 and h.golpe_cfg.nome == "giro", "2º passo: giro")
	passos(2)
	ok(atras.vida < v_atras, "o giro acerta em volta, inclusive atrás")
	ok(atras.emp.x < 0.0, "o giro empurra para fora (atrás vai para trás, emp.x=%.0f)" % atras.emp.x)
	ok(ate(func(): return h.estado == Heroi.Estado.LIVRE, 80) >= 0, "o giro termina")
	# o puxão não ultrapassa o herói: monstro colado leva um puxão curto
	zerar()
	var perto = monstro_a(22, 0, "inimigo_cavaleiro_oco")
	h.atacar()
	ate(func(): return h.golpe_acertou, 80)
	passos(30)
	ok(perto.pos.x > h.pos.x - 4.0, "um monstro a 22 px puxado não atravessa o herói (x relativo %.1f)" % (perto.pos.x - h.pos.x))
	ok(ate(func(): return h.estado == Heroi.Estado.LIVRE, 80) >= 0, "e o golpe termina")


func _t_lukako() -> void:
	await _partida_do("lukako", 85.0, 112.0, 5.0)
	var h = w.heroi
	var ar = w.combate.armas
	zerar()
	var l0: int = ar.lancadas
	h.atacar()
	ok(ate(func(): return h.golpe_acertou, 80) >= 0, "Lukako golpeia")
	ok(ar.lancadas == l0 + 1, "o corte solta uma onda de vento mesmo sem acertar ninguém (lançadas %d -> %d)" % [l0, ar.lancadas])
	var dano_onda := 0.0
	for i in ar.MAX_ONDAS:
		if ar.w_dist[i] > 0.0:
			dano_onda = maxf(dano_onda, ar.w_dano[i])
	var passo0: Dictionary = Herois.heroi("lukako").cfg.golpe.passos[0]
	ok(absf(dano_onda - float(passo0.dano) * float(passo0.vento)) < 0.01, "a onda leva 40%% do dano do corte (%.2f)" % dano_onda)
	# com a carta Corte ondulante junto, ainda sai uma onda só por corte (a maior)
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 80)
	zerar()
	var cs = w.combate.cartas
	cs.aplicar(cs.montar_carta(cs.definicao("onda"), 3))  # lendária: onda forte
	var forte: float = ar.dano_da_onda(float(passo0.dano) * h.m_dano)
	var l1: int = ar.lancadas
	var g1: int = h.golpes
	h.atacar()
	ate(func(): return h.golpes > g1 and h.golpe_acertou, 80)
	ok(ar.lancadas == l1 + 1, "com a carta, o corte solta uma onda só (lançadas %d -> %d)" % [l1, ar.lancadas])
	dano_onda = 0.0
	for i in ar.MAX_ONDAS:
		if ar.w_dist[i] > 0.0:
			dano_onda = maxf(dano_onda, ar.w_dano[i])
	ok(absf(dano_onda - maxf(forte, float(passo0.dano) * float(passo0.vento))) < 0.01, "e vale a maior das duas (%.2f)" % dano_onda)


func _t_fabio() -> void:
	await _partida_do("fabio", 75.0, 98.0, 5.0)
	var h = w.heroi
	var ad = w.combate.adagas
	zerar()
	var fila := [_alvo_fixo(60, 0), _alvo_fixo(110, 0), _alvo_fixo(160, 0), _alvo_fixo(210, 0)]
	h.atacar()
	ate(func(): return ad.lancadas >= 1, 60)
	ate(func(): return ad.ativas() == 0, 200)
	ok(ad.lancadas == 1, "o primeiro tiro é uma flecha só (%d)" % ad.lancadas)
	ok(_atingidos(fila) == 3 and fila[3].vida == fila[3].vida_max, "a flecha atravessa 3 monstros e para (%d atingidos, o 4º intacto)" % _atingidos(fila))
	# o duplo: duas flechas em leque curto
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 80)
	zerar()
	var g0: int = h.golpes
	h.atacar()
	ate(func(): return h.golpes >= g0 + 1 and h.estado == Heroi.Estado.LIVRE, 80)
	h.atacar()
	ate(func(): return h.golpes >= g0 + 2 and h.estado == Heroi.Estado.LIVRE, 80)
	var l0: int = ad.lancadas
	h.atacar()
	ok(ate(func(): return ad.lancadas >= l0 + 2, 80) >= 0, "o terceiro passo solta duas flechas (%d -> %d)" % [l0, ad.lancadas])


# ------------------------------------------------------------------ cartas e card


## Os modificadores exclusivos filtram por herói (dados/v2_cartas.json > herois): onda = hazaki, joao, lukako; fura = hazaki, joao; chuva e mira = lucas, matheus, fabio.
func _t_cartas_novos() -> void:
	var quer := {
		"matheus": {"sim": ["chuva", "mira", "explode", "folego", "dano", "area"], "nao": ["onda", "fura", "abalo", "muralha"]},
		"joao": {"sim": ["onda", "fura", "explode", "folego", "dano", "area"], "nao": ["abalo", "muralha", "chuva", "mira"]},
		"beto": {"sim": ["explode", "folego", "dano", "area"], "nao": ["onda", "fura", "abalo", "muralha", "chuva", "mira"]},
		"lukako": {"sim": ["onda", "explode", "folego", "dano", "area"], "nao": ["fura", "abalo", "muralha", "chuva", "mira"]},
		"fabio": {"sim": ["chuva", "mira", "explode", "folego", "dano", "area"], "nao": ["onda", "fura", "abalo", "muralha"]},
	}
	for id in quer:
		await novo(id)
		var ids := []
		for d in w.combate.cartas.disponiveis():
			ids.append(str(d.id))
		for c in quer[id].sim:
			ok(ids.has(c), "%s: a carta %s pode sair" % [id, c])
		for c in quer[id].nao:
			ok(not ids.has(c), "%s: a carta %s NÃO pode sair" % [id, c])
		var vistas := {}
		for k in 60:
			for c in w.combate.cartas.sortear(3, 1 + k % 20):
				vistas[str(c.id)] = true
		for c in quer[id].nao:
			ok(not vistas.has(c), "%s: o sorteio nunca traz %s (60 sorteios)" % [id, c])


func _secao_card(secs: Array, id: String) -> Dictionary:
	for s in secs:
		if str(s.get("id", "")) == id:
			return s
	return {}


## O card SUA BUILD de cada herói novo: nome, arma, números e só os modificadores dele.
func _t_card_novos() -> void:
	var mods := {"matheus": ["chuva", "mira"], "joao": ["onda", "fura"], "beto": [], "lukako": ["onda"], "fabio": ["chuva", "mira"]}
	var todos := {"hazaki": ["onda", "fura"], "nicao": ["abalo", "muralha"], "lucas": ["chuva", "mira"]}
	todos.merge(mods)
	for id in NOVOS:
		await novo(id)
		zerar()
		var h = w.heroi
		var cfg_h: Dictionary = Herois.heroi(id).cfg
		var secs: Array = Status.coletar(w)
		var titulo_h := str(_secao_card(secs, "heroi").get("titulo", ""))
		ok(titulo_h == "HERÓI: " + str(Herois.heroi(id).nome).to_upper(), "%s: o card abre a seção HERÓI com o nome dele (%s)" % [id, titulo_h])
		var titulo_k := str(_secao_card(secs, "katana").get("titulo", ""))
		ok(titulo_k == str(Herois.heroi(id).arma) + " (CLIQUE)", "%s: a seção de golpe leva a arma dele (%s)" % [id, titulo_k])
		var vida_card := str(Status.linha(secs, "heroi.vida").get("valor", ""))
		ok(
			vida_card == "%d / %d" % [roundi(h.vida), roundi(h.vida_max)] and roundi(h.vida_max) == roundi(float(cfg_h.heroi.vida)),
			"%s: a vida no card é a do herói (%s)" % [id, vida_card]
		)
		ok(
			Status.linha(secs, "katana.dano").get("n", []).size() == cfg_h.golpe.passos.size(),
			"%s: a seção de golpe tem uma conta por passo do combo dele" % id
		)
		var cs = w.combate.cartas
		for md in mods[id]:
			cs.aplicar(cs.montar_carta(cs.definicao(md), 0))
		secs = Status.coletar(w)
		for md in mods[id]:
			var bl: Dictionary = Status.linha(secs, "katana." + md)
			ok(
				not bl.is_empty() and absf(float(bl.n[0]) - float(w.combate.armas.mods[md])) < 0.001,
				"%s: o card mostra o modificador %s com o número do jogo" % [id, md]
			)
		for outro in todos:
			for md in todos[outro]:
				if outro != id and not mods[id].has(md):
					ok(Status.linha(secs, "katana." + md).is_empty(), "%s: o card não mostra o modificador %s, que é de outro herói" % [id, md])
