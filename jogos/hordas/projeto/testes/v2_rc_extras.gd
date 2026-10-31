extends "res://testes/isolamento_v2.gd"
# Teste automático dos três extras da RC (#414): o dano por golpe na tela de fim (combate.dano_por_fonte e o quadro do
# resultado_meta.gd), as conquistas novas que destravam coisas (condições abates, nível, evoluções, partidas, abates_total e herói;
# prêmios em almas e em nível máximo de melhoria) e o recorde por herói x mapa x dificuldade da tela de escolha. Save TEMPORÁRIO.
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_rc_extras.tscn  (imprime "v2_rc_extras falhas=0")

const Meta := preload("res://v2/meta.gd")
const Conquistas := preload("res://v2/conquistas.gd")
const Mundo := preload("res://v2/mundo.tscn")
const Resultado := preload("res://v2/resultado_meta.gd")
const Escolha := preload("res://v2/escolha_dificuldade.gd")
const SAVE_TESTE := "user://testes_v2/v2_rc_extras/teste_v2_rc_extras_meta.cfg"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	_limpar()
	_conquistas()
	_limpar()
	_recordes()
	_limpar()
	await _dano_e_resultado()
	_limpar()
	print("v2_rc_extras falhas=%d" % falhas)
	get_tree().quit()


func _limpar() -> void:
	for f in [SAVE_TESTE, SAVE_TESTE + ".bak", SAVE_TESTE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


func _feita(id: String) -> bool:
	return bool(Meta.estado().conquistas.get(id, false))


## Conquistas novas: cada condição, o filtro de herói, o prêmio em almas e o nível extra no máximo da melhoria.
func _conquistas() -> void:
	ok(Meta.conquistas().size() >= 25, "pelo menos 25 conquistas (eram 11)")
	var ids := {}
	for c in Meta.conquistas():
		ok(not ids.has(c.id), "id único: " + str(c.id))
		ids[c.id] = true
		ok(Conquistas.premio(c) != "" or str(c.recompensa.tipo) in ["nenhuma", "progresso"], "toda conquista nova tem prêmio: " + str(c.id))
	ok(int(Meta.melhoria("dano").max) == 5, "Gume de herança começa com 5 níveis")
	var r := Meta.registrar_partida({"tempo": 100.0, "abates": 320, "nivel": 16, "maior_combo": 5, "venceu": false, "almas": 0, "evolucoes": 1})
	ok(_feita("abates_300") and _feita("nivel_15") and _feita("evolucao_1"), "300 abates, nível 15 e uma evolução numa partida")
	ok(not _feita("abates_1000") and not _feita("nivel_25") and not _feita("evolucao_3"), "as metas maiores ainda não")
	ok(int(r.premios) == 350 and Meta.saldo() == 350, "os prêmios em almas entram no saldo (100 + 150 + 100)")
	ok(int(r.depois) == 350, "o resultado devolve o saldo com os prêmios")
	Meta.registrar_partida({"tempo": 100.0, "abates": 1200, "nivel": 3, "maior_combo": 5, "venceu": false, "almas": 0})
	ok(_feita("abates_1000"), "1000 abates numa partida")
	ok(int(Meta.melhoria("dano").max) == 6 and int(Meta.melhoria("dano").max_base) == 5, "Ceifador dá +1 nível em Gume de herança")
	ok(int(Meta.estado().recordes.abates) == 1200 and int(Meta.estado().recordes.nivel) == 16, "recordes de abates e de nível só sobem")
	ok(int(Meta.estado().recordes.abates_total) == 1520, "os abates somam no total (320 + 1200)")
	var linha := {}
	for l in Conquistas.linhas():
		if str(l.id) == "abates_total_10000":
			linha = l
	ok(str(linha.get("progresso", "")) == "1520/10000 abates", "o Códice mostra o total de abates: " + str(linha.get("progresso", "")))
	# comprar até o novo máximo: o 6º nível só existe com a conquista
	Meta.creditar(100000)
	for i in 6:
		ok(Meta.comprar("dano"), "compra o nível %d de Gume de herança" % (i + 1))
	ok(not Meta.comprar("dano"), "não passa do máximo novo (6)")
	ok(Meta.nivel("dano") == 6, "6 níveis comprados")
	# herói: só a vitória com ele
	Meta.registrar_partida({"tempo": 10.0, "venceu": true, "almas": 0, "mapa": "floresta", "heroi": "nicao"})
	ok(_feita("vence_nicao") and not _feita("vence_hazaki") and not _feita("vence_lucas"), "vencer com o Nick marca só a dele")
	Meta.registrar_partida({"tempo": 10.0, "venceu": false, "almas": 0, "heroi": "lucas"})
	ok(not _feita("vence_lucas"), "perder com o Luke não marca a dele")
	# partidas: contadas no save, antes de conferir
	for i in 6:
		Meta.registrar_partida({"tempo": 1.0, "venceu": false, "almas": 0})
	ok(int(Meta.estado().recordes.partidas) == 10 and _feita("partidas_10"), "a 10ª partida já vale para Frequentador")
	ok(int(Meta.melhoria("ima").max) == int(Meta.melhoria("ima").max_base) + 1, "Frequentador dá +1 nível no Ímã de almas")
	# ao vivo: abates, nível e evoluções no meio da partida
	_limpar()
	var novas := Meta.checar_ao_vivo(30.0, 3, {"abates": 310, "nivel": 2, "evolucoes": 0, "heroi": "hazaki"})
	ok(novas == ["abates_300"], "ao vivo: 300 abates conta no meio da partida " + str(novas))
	ok(Meta.saldo() == 100, "o prêmio ao vivo também entra no saldo")


## Recorde por herói x mapa x dificuldade: o maior tempo, os abates dele e se já venceu (vitória fica marcada).
func _recordes() -> void:
	ok(not bool(Meta.recorde_hmd("hazaki", "floresta", "facil").tem), "sem partida, sem recorde")
	ok(Escolha.texto_recorde(Meta.recorde_hmd("hazaki", "floresta", "facil")) == "SEM RECORDE", "texto sem recorde")
	var base := {"almas": 0, "mapa": "floresta", "heroi": "hazaki", "dificuldade": "medio", "maior_combo": 0}
	Meta.registrar_partida(base.merged({"tempo": 200.0, "abates": 150, "venceu": false}))
	Meta.registrar_partida(base.merged({"tempo": 90.0, "abates": 400, "venceu": false}))
	var rec := Meta.recorde_hmd("hazaki", "floresta", "medio")
	ok(bool(rec.tem) and is_equal_approx(float(rec.tempo), 200.0) and int(rec.abates) == 150, "fica o maior tempo, com os abates dele")
	ok(Escolha.texto_recorde(rec) == "RECORDE 03:20 · 150 ABATES", "texto do recorde: " + Escolha.texto_recorde(rec))
	ok(not bool(Meta.recorde_hmd("hazaki", "floresta", "facil").tem), "o Fácil é outro recorde")
	ok(not bool(Meta.recorde_hmd("nicao", "floresta", "medio").tem), "outro herói, outro recorde")
	ok(not bool(Meta.recorde_hmd("hazaki", "cidade", "medio").tem), "outro mapa, outro recorde")
	Meta.registrar_partida(base.merged({"tempo": 150.0, "abates": 99, "venceu": true}))
	rec = Meta.recorde_hmd("hazaki", "floresta", "medio")
	ok(bool(rec.venceu) and is_equal_approx(float(rec.tempo), 200.0), "vencer marca VENCEU sem baixar o tempo")
	ok(Escolha.texto_recorde(rec) == "RECORDE 03:20 · VENCEU", "texto da vitória: " + Escolha.texto_recorde(rec))
	var tela := Escolha.new()
	add_child(tela)
	tela.abrir("Floresta", "floresta")
	var achou := false
	for l in tela._recordes:
		achou = achou or l.text.begins_with("RECORDE") or l.text == "SEM RECORDE"
	ok(tela._recordes.size() == 3 and achou, "a tela de escolha mostra o recorde em cada cartão")
	tela.queue_free()


## O dano por golpe: o combate soma por fonte e a tela de fim mostra o ranking, do maior para o menor, com barra e porcentagem.
func _dano_e_resultado() -> void:
	var m = Mundo.instantiate()
	m.modo_teste = true
	m.id_mapa = "floresta"
	add_child(m)
	m.set_process(false)
	var c = m.combate
	c.dano_por_fonte.clear()
	c.contar_dano("principal", 600.0)
	c.contar_dano("especial", 300.0)
	c.contar_dano("", 100.0)
	var lista: Array = c.ranking_dano()
	ok(lista.size() == 3 and str(lista[0].fonte) == "principal" and str(lista[2].fonte) == "outros", "ranking do maior para o menor")
	ok(is_equal_approx(float(lista[0].frac), 0.6), "porcentagem do total")
	ok(str(lista[0].nome) == "Katana", "o ataque principal leva o nome da arma do herói: " + str(lista[0].nome))
	# ferir de verdade com uma fonte de golpe secundário
	c.dano_por_fonte.clear()
	var alvo = m.nascer_monstro("inimigo_cao_ossos", m.heroi.pos + Vector2(200, 0))
	ok(alvo != null, "nasce um monstro para apanhar")
	if alvo != null:
		c.fonte_dano = "teste_golpe"
		var vida: float = alvo.vida
		c.ferir(alvo, 5.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE, false)
		ok(is_equal_approx(float(c.dano_por_fonte.get("teste_golpe", 0.0)), minf(5.0, vida)), "ferir() soma o dano na fonte atual")
	# tela de fim: quadro do dano e mais de seis conquistas de uma vez
	c.dano_por_fonte.clear()
	c.contar_dano("principal", 1500.0)
	c.contar_dano("especial", 500.0)
	var res = m.meta_res
	if res == null:
		res = Resultado.new()
		res.montar(m)
		m.ui.add_child(res)
	res.set_process(false)
	var ids: Array = []
	for cq in Meta.conquistas().slice(0, 9):
		ids.append(str(cq.id))
	res._antes = 0
	res._mostrar({"tempo": 60.0, "abates": 10, "nivel": 3, "maior_combo": 4, "venceu": false}, ids)
	res._animar(2.0)
	ok(res._dano_tit.visible and res._dano_nomes[0].visible and res._dano_nomes[1].visible and not res._dano_nomes[2].visible, "duas linhas de dano")
	ok(res._dano_nomes[0].text.begins_with("Katana") and res._dano_pct[0].text == "75%", "a maior primeiro, com %: " + res._dano_nomes[0].text)
	ok(is_equal_approx(res._dano_barras[0].size.x, res.DANO_LARG), "a barra do maior enche")
	ok(is_equal_approx(res._dano_barras[1].size.x, res.DANO_LARG / 3.0), "a barra do segundo é proporcional")
	var dano_fim: float = res._dano_barras[0].position.x + res.DANO_LARG
	ok(dano_fim <= res.LARG - 24, "o quadro do dano cabe na tela")
	ok(res._valores.position.x + res._valores.size.x <= res.DANO_X, "os números não encostam no quadro do dano")
	ok(res._novas.text.count("Conquista: ") == 5 and res._novas.text.contains("+4 conquistas"), "nove conquistas: cinco nomes e +4")
	ok(res._novas.text.split("\n").size() == 3, "continua em três linhas")
	m.queue_free()
	await get_tree().process_frame
