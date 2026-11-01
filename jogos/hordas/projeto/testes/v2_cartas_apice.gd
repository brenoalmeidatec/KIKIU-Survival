extends "res://testes/isolamento_v2.gd"
# CAR-5: a COTA de 5/5 por mapa e o ÁPICE (o bônus que chega ao 5/5).
# Confere: os dados (a cota cresce por mapa e só o último chega a 50%; os 12 tipos de golpe têm regra de ÁPICE); na Floresta (cota 0) nenhum bônus passa
# do nível 4 em 500 escolhas; no último mapa, com 8 bônus, no máximo 4 em 5/5 (e a mão nunca traz mais upgrades de ÁPICE do que há vagas); o efeito
# numérico (stat e modificador x1,5, golpe por tipo); os pools de corvos e runas não passam do que já tinham; fusão comum não consome o ÁPICE e a
# lendária consome; largar um ÁPICE desfaz o stat; o degrau (a) da animação (anúncio, hit-stop, câmera lenta, passada de dano uma vez) e o perfil Baixo.
# Fotos: godot --path jogos/hordas/projeto res://testes/v2_cartas_apice.tscn -- --fotos=PASTA  (janela de verdade: a mão com a carta ÁPICE, o anúncio e o HUD de golpes)
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_cartas_apice.tscn  (imprime "v2_cartas_apice falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Mapas := preload("res://v2/mapas.gd")
const Armas := preload("res://v2/armas.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var cs


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func zerar(mapa: String) -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.id_mapa = mapa
	w.combate.cartas.rng.seed = 777
	for i in 3:
		w.avancar(PASSO)
	cs = w.combate.cartas


func dar(id: String, n: int) -> void:
	for k in n:
		cs.aplicar(cs.montar_carta(cs.definicao(id), 0))


func ultimo_mapa() -> String:
	return str(Mapas.LISTA[Mapas.LISTA.size() - 1].id)


## Quantos bônus estão em 5/5 (qualquer nível igual ao máximo) entre os que o herói tem.
func em_cinco() -> int:
	var n := 0
	for id in cs.estado:
		if cs.ativa(str(id)) and cs.nivel_de(str(id)) >= int(cs.definicao(str(id)).max):
			n += 1
	return n


## O pico de nível entre todos os bônus.
func maior_nivel() -> int:
	var m := 0
	for id in cs.estado:
		m = maxi(m, cs.nivel_de(str(id)))
	return m


## Demanda de um pool: quantos itens vivos o golpe pede ao mesmo tempo (quantidade x duração / recarga) com velocidade de ataque 1.
func demanda(st: Dictionary) -> float:
	return float(st.quantidade) * float(st.duracao) / float(st.recarga)


func _run() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
		get_tree().quit()
		return
	_testes()
	print("v2_cartas_apice falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _testes() -> void:
	# 1. os dados: a cota por mapa e o ÁPICE por tipo
	zerar("floresta")
	var m: Dictionary = cs.cfg.maestria
	var ultimo := ultimo_mapa()
	for mp in Mapas.LISTA:
		ok(m.mapas.has(str(mp.id)), "o mapa %s tem linha em maestria" % mp.id)
	ok(float(m.mapas[str(Mapas.LISTA[0].id)].fracao) == 0.0 and int(m.mapas[str(Mapas.LISTA[0].id)].piso) == 0, "o primeiro mapa tem cota 0")
	ok(float(m.mapas[ultimo].fracao) >= 0.5, "o último mapa da lista dá pelo menos metade dos bônus em 5/5")
	var anterior := -1.0
	for mp in Mapas.LISTA:
		var fr := float(m.mapas[str(mp.id)].fracao)
		ok(fr > anterior or (anterior == -1.0), "a fração cresce a cada mapa (%s: %.2f)" % [mp.id, fr])
		if str(mp.id) != ultimo:
			ok(fr < 0.5, "só o último mapa chega a 50%% (%s: %.2f)" % [mp.id, fr])
		anterior = fr
	var tipos := {}
	for g in cs.cfg.golpes:
		tipos[str(g.tipo)] = true
	ok(tipos.size() == 12, "são 12 tipos de golpe (%d)" % tipos.size())
	for t in tipos:
		var regra: Dictionary = cs.cfg.apice.golpe.tipos.get(t, {})
		ok(not regra.is_empty() and regra.has("texto"), "o tipo %s tem regra e texto de ÁPICE" % t)
		ok(str(regra.get("texto", "")).length() <= 40, "o texto de ÁPICE de %s cabe no cartão" % t)
		var chaves: Array = []
		chaves.append_array((regra.get("mult", {}) as Dictionary).keys())
		chaves.append_array((regra.get("soma", {}) as Dictionary).keys())
		for g in cs.cfg.golpes:
			if str(g.tipo) != t:
				continue
			for k in chaves:
				ok((g.base as Dictionary).has(k), "%s (%s): a regra de ÁPICE mexe em %s, que o golpe tem" % [g.id, t, k])
	ok(float(cs.cfg.apice.stat) > 1.0, "o ÁPICE de stat multiplica a soma")

	# 2. Floresta (cota 0): em 500 escolhas à mão nenhum bônus passa do nível 4
	zerar("floresta")
	ok(cs.cota_apice() == 0 and not cs.apice_livre(), "na Floresta a cota é 0")
	var escolhas := 0
	for i in 500:
		var mao: Array = cs.montar_mao(10, 1.0, 0, -1, true, false)
		if mao.is_empty():
			break
		var c: Dictionary = mao[cs.rng.randi() % mao.size()]
		ok(not bool(c.get("apice", false)), "na Floresta nenhuma carta leva ao ÁPICE (%s)" % c.id)
		cs.aplicar(c)
		escolhas += 1
		if maior_nivel() > 4:
			ok(false, "na Floresta %s passou do nível 4 na escolha %d" % [c.id, escolhas])
			break
	print("  Floresta: %d escolhas, maior nível %d" % [escolhas, maior_nivel()])
	ok(escolhas > 60, "a Floresta deu escolhas suficientes para o teste valer (%d)" % escolhas)
	ok(maior_nivel() <= 4 and em_cinco() == 0, "na Floresta o maior nível é 4 e ninguém está em 5/5 (nível %d)" % maior_nivel())
	# a carta velha na tela (montada com a cota aberta) não leva além: o aplicar respeita o teto
	zerar("floresta")
	dar("dano", 4)
	var c4: Dictionary = cs.montar_carta(cs.definicao("dano"), 0)
	ok(not cs._disponivel(cs.definicao("dano")), "o dano no nível 4 não sai na Floresta")
	cs.aplicar(c4)
	ok(cs.nivel_de("dano") == 4 and not cs.apice_de("dano"), "aplicar uma carta de nível 5 na Floresta não passa do 4")
	dar("laminas", 3)
	var lend: Dictionary = cs.montar_carta(cs.definicao("laminas"), 3)
	ok(int(lend.nivel_novo) == 4 and not bool(lend.apice), "a carta lendária de golpe também para no 4 sem cota (nv %d)" % int(lend.nivel_novo))

	# 3. último mapa, 8 bônus: no máximo 4 em 5/5, e a mão nunca oferece mais ÁPICES do que há vagas
	zerar(ultimo)
	var oito := ["dano", "vel_ataque", "area", "vel_mov", "vida", "ima", "critico", "laminas"]
	for id in oito:
		dar(id, 1)
	ok(cs.bonus_trocaveis().size() == 8 and cs.cota_apice() == 4, "8 bônus no último mapa: cota 4 (%d)" % cs.cota_apice())
	var passos := 0
	for i in 300:
		var mao2: Array = cs.montar_mao(10, 1.0, 0, -1, true, false)
		var ups: Array = mao2.filter(func(x): return str(x.tipo) == "up")
		if ups.is_empty():
			break
		var livres: int = cs.cota_apice() - cs.apices_atuais()
		var apices_na_mao: int = ups.filter(func(x): return bool(x.apice)).size()
		ok(apices_na_mao <= maxi(livres, 0), "a mão não traz mais ÁPICES (%d) do que há vagas (%d)" % [apices_na_mao, livres])
		var c2: Dictionary = ups[cs.rng.randi() % ups.size()]
		cs.aplicar(c2)
		passos += 1
		ok(em_cinco() <= cs.cota_apice(), "nunca mais bônus em 5/5 (%d) do que a cota (%d)" % [em_cinco(), cs.cota_apice()])
	print("  último mapa (%s): %d upgrades, %d bônus em 5/5" % [ultimo, passos, em_cinco()])
	ok(passos > 20, "o último mapa deu upgrades suficientes (%d)" % passos)
	ok(em_cinco() == 4 and cs.apices_atuais() == 4, "com 8 bônus fecham exatamente 4 em 5/5 (%d)" % em_cinco())
	ok(cs.cota_apice() == 4 and not cs.apice_livre(), "e a cota está cheia")
	var nao_apice := 0
	for id in cs.bonus_trocaveis():
		if not cs.apice_de(str(id)):
			ok(cs.nivel_de(str(id)) == 4, "quem ficou de fora está no nível 4 (%s: %d)" % [id, cs.nivel_de(str(id))])
			nao_apice += 1
	ok(nao_apice == 4, "os outros 4 ficaram no nível 4")

	# 4. efeito numérico: stat e modificador x1,5; golpe pelo tipo
	zerar(ultimo)
	var h = w.heroi
	var dano0: float = h.m_dano
	dar("dano", 5)
	ok(cs.apice_de("dano") and cs.nivel_de("dano") == 5, "5 cartas de dano levam ao ÁPICE no último mapa")
	ok(is_equal_approx(float(cs.estado.dano.soma), 180.0), "a soma do ÁPICE é 120 x 1,5 = 180 (%.1f)" % float(cs.estado.dano.soma))
	ok(is_equal_approx(h.m_dano - dano0, 1.8), "o herói recebeu +180%% de dano (%.2f)" % (h.m_dano - dano0))
	var vida0: float = h.vida_max
	dar("vida", 5)
	ok(is_equal_approx(h.vida_max - vida0, 240.0), "vida: 160 x 1,5 = 240 (%.0f)" % (h.vida_max - vida0))
	var removeu: bool = cs.remover_bonus("vida")
	ok(
		removeu and is_equal_approx(h.vida_max, vida0) and not cs.apice_de("vida"),
		"largar o ÁPICE da vida devolve a vida máxima (%.0f de %.0f)" % [h.vida_max, vida0]
	)
	dar("onda", 5)
	var base_mod: float = float(cs.definicao("onda").valor) * 5.0
	ok(
		is_equal_approx(float(w.combate.armas.mods.onda), base_mod * 1.5),
		"o modificador no ÁPICE é a soma x 1,5 (%.1f de %.1f)" % [float(w.combate.armas.mods.onda), base_mod * 1.5]
	)
	var armas = w.combate.armas
	armas.definir_golpe("laminas", 5, 0.0, false)
	var st5: Dictionary = (armas.ativas.laminas.st as Dictionary).duplicate()
	armas.definir_golpe("laminas", 5, 0.0, true)
	var sta: Dictionary = armas.ativas.laminas.st
	ok(is_equal_approx(float(sta.dano), float(st5.dano) * 1.5) and int(sta.quantidade) == int(st5.quantidade) + 1, "lâminas no ÁPICE: dano x1,5 e +1 lâmina")
	ok(bool(armas.ativas.laminas.apice), "o golpe guarda a marca de ÁPICE (o HUD lê)")
	armas.definir_golpe("aura_fogo", 5, 0.0, false)
	var raio5 := float(armas.ativas.aura_fogo.st.raio)
	armas.definir_golpe("aura_fogo", 5, 0.0, true)
	ok(is_equal_approx(float(armas.ativas.aura_fogo.st.raio), raio5 * 1.3), "aura no ÁPICE: raio +30%%")

	# 5. pools de corvos e runas: o ÁPICE não pede mais do que o nível 5 comum, e cabe no pool
	zerar(ultimo)
	armas = w.combate.armas
	armas.definir_golpe("corvos", 5, 0.0, false)
	var d_corvo := demanda(armas.ativas.corvos.st)
	armas.definir_golpe("corvos", 5, 0.0, true)
	var d_corvo_a := demanda(armas.ativas.corvos.st)
	ok(
		d_corvo_a <= d_corvo + 0.001 and d_corvo_a <= float(Armas.MAX_CORVOS),
		"corvos no ÁPICE pedem %.1f do pool (nv 5: %.1f, teto %d)" % [d_corvo_a, d_corvo, Armas.MAX_CORVOS]
	)
	armas.definir_golpe("runa", 5, 0.0, false)
	var d_runa := demanda(armas.ativas.runa.st)
	armas.definir_golpe("runa", 5, 0.0, true)
	var d_runa_a := demanda(armas.ativas.runa.st)
	ok(d_runa_a <= d_runa + 0.001, "runas no ÁPICE não pedem mais do pool que no nível 5 (%.1f contra %.1f)" % [d_runa_a, d_runa])
	ok(float(armas.ativas.runa.st.dano) > 0.0 and float(armas.ativas.runa.st.explosao) > 50.0 * 1.0, "mas ganham dano e área")

	# 6. fusão: a peça em ÁPICE não é consumida por uma fusão comum; a lendária consome
	zerar(ultimo)
	dar("laminas", 5)
	ok(cs.apice_de("laminas"), "lâminas chegou ao ÁPICE")
	dar("aura_fogo", 3)
	ok(cs.evoluidas.has("anel_de_brasas"), "a fusão Anel de Brasas aconteceu")
	ok(cs.ativa("laminas") and not bool(cs.estado.laminas.usada), "a peça em ÁPICE (lâminas) não foi consumida")
	ok(bool(cs.estado.aura_fogo.usada), "a outra peça foi consumida como sempre")
	zerar(ultimo)
	var lendarias: Array = cs.cfg.evolucoes.filter(func(e): return str(e.get("raridade", "")) == "lendario")
	var ev0: Dictionary = lendarias[0]
	for id in ev0.consome:
		cs.estado[str(id)] = {"n": 5, "bonus": 0.0, "soma": 0.0, "usada": false, "apice": true}
	cs.evoluir(ev0)
	var todas := true
	for id in ev0.consome:
		todas = todas and bool(cs.estado[str(id)].usada)
	ok(todas, "a fusão lendária consome as 4 peças, mesmo em ÁPICE")
	ok(cs.apices_atuais() == 0, "os ÁPICES consumidos em lendária saem da conta da cota")

	# 7. o degrau (a): anúncio, hit-stop, câmera lenta e a passada de dano, uma vez; o clarão e as luzes ficam fora do perfil Baixo
	zerar(ultimo)
	dar("laminas", 4)
	var perto: Array = []
	for k in 6:
		var mo = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(40.0 + 20.0 * k, 0.0))
		mo.vida_max = 100.0
		mo.vida = 100.0
		mo.atordoa_t = 0.0
		perto.append(mo)
	var longe = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(3000.0, 0.0))
	longe.vida_max = 100.0
	longe.vida = 100.0
	var antes_hit: int = w.combate.hit_stops
	dar("laminas", 1)
	ok(w.combate.apices == 1, "o ÁPICE foi contado")
	ok(w.combate.hit_stops == antes_hit + 1 and is_equal_approx(w.combate.ultimo_hit_stop, 0.1), "o mundo parou 0,1 s")
	ok(
		w.combate.lento_acao == "apice" and is_equal_approx(w.combate.lento_escala, 0.3) and is_equal_approx(w.combate.lento_t, 0.9),
		"câmera lenta de 0,9 s a 0,3x"
	)
	for i in 240:
		w.avancar(PASSO)
		if w.combate.apice_passada > 0:
			break
	ok(w.combate.ultimo_anuncio == "ÁPICE: Lâminas Rodopiantes", "o anúncio diz ÁPICE e o nome (%s)" % w.combate.ultimo_anuncio)
	ok(w.combate.apice_passada >= 6, "a passada atingiu os monstros da tela (%d)" % w.combate.apice_passada)
	var feridos := 0
	for mo in perto:
		if mo.vivo and mo.vida < 100.0:
			feridos += 1
	ok(feridos >= 5, "a passada tirou vida de quem estava perto (%d de 6)" % feridos)
	ok(longe.vida >= 100.0 or not longe.vivo, "quem estava fora da tela ficou de fora")
	var passada1: int = w.combate.apice_passada
	for i in 120:
		w.avancar(PASSO)
	ok(w.combate.apice_passada == passada1 and w.combate.apices == 1, "a passada acontece uma vez só")
	ok(w.combate.nome_da_fonte("apice") == "ÁPICE", "a tela de fim sabe o nome da fonte de dano")
	# o perfil Baixo: sem luz, partículas nem tremor, mas o anúncio, os anéis e a passada seguem
	ok(not w.combate._perfil_baixo(), "com as partículas do jeito de sempre não é perfil Baixo")
	w.args["particulas"] = "nenhuma"
	ok(w.combate._perfil_baixo(), "partículas em nenhuma é perfil Baixo")
	zerar(ultimo)
	w.args["particulas"] = "nenhuma"
	dar("laminas", 4)
	var m_baixo = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(50.0, 0.0))
	m_baixo.vida_max = 100.0
	m_baixo.vida = 100.0
	dar("laminas", 1)
	for i in 240:
		w.avancar(PASSO)
		if w.combate.apice_passada > 0:
			break
	ok(w.combate.apice_passada >= 1 and w.combate.ultimo_anuncio.begins_with("ÁPICE"), "no perfil Baixo o anúncio e a passada seguem")
	w.args.erase("particulas")

	# 8. o selo do cartão e o rodapé
	zerar(ultimo)
	dar("dano", 4)
	var carta: Dictionary = cs.montar_carta(cs.definicao("dano"), 0)
	ok(
		bool(carta.apice) and str(carta.nivel_txt) == "Nível 4 » ÁPICE" and str(carta.proximo).begins_with("ÁPICE"),
		"o cartão do último passo diz ÁPICE (%s | %s)" % [carta.nivel_txt, carta.proximo]
	)
	ok(str(carta.nivel_txt).length() <= cs.LINHA_RODAPE, "e o rodapé cabe na linha")
	dar("laminas", 4)
	var cg: Dictionary = cs.montar_carta(cs.definicao("laminas"), 0)
	ok(bool(cg.apice) and str(cg.proximo).contains("ÁPICE"), "o cartão do golpe mostra o que o ÁPICE traz (%s)" % cg.proximo)
	var c_normal: Dictionary = cs.montar_carta(cs.definicao("vida"), 0)
	ok(not bool(c_normal.apice), "a carta de um bônus novo não é ÁPICE")

	# 9. o automático nunca chega ao ÁPICE, nem com cota livre
	zerar(ultimo)
	dar("dano", 4)
	dar("vida", 1)
	var mao3: Array = [cs.montar_carta(cs.definicao("dano"), 0)]
	var auto: Dictionary = cs.escolha_automatica(mao3)
	ok(auto.is_empty(), "o Automático não leva um bônus de 4 a 5")
	ok(not cs.serve_ao_automatico(mao3[0]), "e a carta de ÁPICE não serve ao tempo esgotado")


func _ready() -> void:
	_run()


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## As fotos de janela de verdade: a mão com duas cartas de ÁPICE, o instante logo depois de escolher uma (anúncio e anéis) e o HUD de golpes dourado.
func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	zerar(ultimo_mapa())
	dar("laminas", 4)
	dar("dano", 4)
	dar("aura_fogo", 2)
	for k in 6:
		var mo = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(60.0 + 30.0 * k, -40.0 + 15.0 * k))
		mo.vida_max = 200.0
		mo.vida = 200.0
	var h = w.heroi
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	for i in 120:
		if w.combate.jogo == "escolha":
			break
		w.avancar(PASSO)
	var t = w.combate.telas
	t.espera_escolha = 0.0
	t._liberar_cartas()
	t._marcar()
	t._atualizar_botoes()
	passos(30)
	var tipos_mao: Array = []
	for c in w.combate.progresso.cartas:
		tipos_mao.append("%s:%s" % [c.id, "ÁPICE" if bool(c.get("apice", false)) else c.tipo])
	print("MAO ", tipos_mao)
	var tam = await w.ap.foto(pasta.path_join("mao_apice.png"))
	print("FOTO mao_apice %s" % tam)
	var i_apice := 0
	for q in w.combate.progresso.cartas.size():
		if str(w.combate.progresso.cartas[q].id) == "laminas":
			i_apice = q
	w.combate.progresso.escolher(i_apice)
	passos(30)
	tam = await w.ap.foto(pasta.path_join("apice_instante.png"))
	print("FOTO apice_instante %s anuncio=%s passada=%d" % [tam, w.combate.ultimo_anuncio, w.combate.apice_passada])
	passos(70)
	tam = await w.ap.foto(pasta.path_join("apice_hud.png"))
	print("FOTO apice_hud %s" % tam)
