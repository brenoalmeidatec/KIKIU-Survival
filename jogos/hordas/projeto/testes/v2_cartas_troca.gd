extends "res://testes/isolamento_v2.gd"
# CAR-4: o LIMITE DE BÔNUS do Difícil e o painel de TROCA (dados/v2_dificuldade.json > limite_bonus; v2/cartas.gd cheio e remover_bonus; v2/telas.gd abrir_troca).
# Confere: 0 (sem limite) no Fácil e no Médio e 12 no Difícil; fusão feita conta 1 e libera vaga; com as vagas cheias a mão é 2 upgrades + a novidade marcada TROCA
# (o baú e o atalho `sortear` não oferecem novidade); remover_bonus devolve m_dano, vida_max, o golpe, o modificador e a ruptura ao valor de antes; o bônus largado
# NÃO volta em 300 sorteios; o automático nunca troca nem leva novidade; mão toda de TROCA ganha a cura; pela janela: Enter na carta TROCA abre o painel (12 linhas,
# 2 colunas, setas e mouse), ESC volta às 3 cartas sem perder nada, a guarda dos primeiros 0,3 s, confirmar larga o bônus marcado e leva o novo, o limite de 8 s
# segue correndo no painel e, zerado, roda o automático (que não troca); a linha "Bônus 12 / 12" do card de status.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_cartas_troca.tscn  (imprime "v2_cartas_troca falhas=0")
# Fotos: godot --path jogos/hordas/projeto res://testes/v2_cartas_troca.tscn -- --fotos=PASTA  (a mão com a TROCA e o painel; grava e sai)
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const Status := preload("res://v2/status.gd")
const PASSO := 1.0 / 60.0
const MODS := ["onda", "fura", "explode"]
const STATS := ["dano", "vida", "area", "vel_ataque"]
var falhas := 0
var w
var cs
var mouse_pos := Vector2(900, 60)


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


func _mouse_teste() -> Vector2:
	return mouse_pos


func _tecla(k: Key, apertado := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = apertado
	return e


func _toque(k: Key) -> void:  # aperta e solta pela janela, a rota do jogador de verdade
	Input.parse_input_event(_tecla(k))
	Input.parse_input_event(_tecla(k, false))


func _clique(pos: Vector2) -> void:
	mouse_pos = pos
	for p in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = p
		e.position = pos
		Input.parse_input_event(e)


## Começa de novo na dificuldade `dif` (mapa sem monstros, herói imortal) com a janela de escolha pronta para ser aberta.
func zerar(dif := "dificil") -> void:
	if w.pausa.aberto:
		w.pausa.fechar()
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.meta_bonus["dificuldade"] = Dificuldade.regras(dif)
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	cs = w.combate.cartas
	cs.rng.seed = 777
	w.combate.telas.mouse_fn = Callable(self, "_mouse_teste")
	w.combate.telas.espera_escolha = 0.0
	w.combate.telas.espera_bau = 0.0
	passos(3)


func dar(id: String, n: int) -> void:
	for k in n:
		cs.aplicar(cs.montar_carta(cs.definicao(id), 0))


func golpes_livres(n: int) -> Array:
	var r: Array = []
	for d in cs.cfg.golpes:
		if cs._disponivel(d) and r.size() < n:
			r.append(str(d.id))
	return r


## Os 12 bônus de um Difícil cheio: 4 golpes, 3 modificadores, 1 ruptura e 4 stats, todos no nível 1 (nenhuma fusão acontece).
func encher() -> Array:
	var ids: Array = golpes_livres(4) + MODS + ["rb_dano"] + STATS
	for id in ids:
		dar(id, 1)
	return ids


func tipos(mao: Array) -> Dictionary:
	var r := {"up": 0, "nov": 0, "troca": 0}
	for c in mao:
		var t := str(c.get("tipo", ""))
		r[t] = int(r.get(t, 0)) + 1
	return r


func subir_nivel() -> void:
	var h = w.heroi
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	ate(func(): return w.combate.jogo == "escolha", 120)
	var t = w.combate.telas
	ate(func(): return t.espera_escolha <= 0.0, 120)
	passos(2)


## O índice da carta TROCA na mão aberta, ou -1.
func indice_troca() -> int:
	var cartas: Array = w.combate.progresso.cartas
	for i in cartas.size():
		if str(cartas[i].get("tipo", "")) == "troca":
			return i
	return -1


## Marca a carta `i` e aperta Enter pela janela.
func escolher_pela_janela(i: int) -> void:
	var t = w.combate.telas
	t.sel = i
	t._marcar()
	_toque(KEY_ENTER)
	passos(2)


func _run() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	Input.use_accumulated_input = false
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
		get_tree().quit()
		return
	_testes()
	print("v2_cartas_troca falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _testes() -> void:
	var c = w.combate
	var t = c.telas

	# 1. o limite está nos dados: 0 no Fácil e no Médio, 12 no Difícil (a partida usa a foto das regras)
	ok(int(Dificuldade.regras("facil").limite_bonus) == 0, "Fácil sem limite")
	ok(int(Dificuldade.regras("medio").limite_bonus) == 0, "Médio sem limite")
	ok(int(Dificuldade.regras("dificil").limite_bonus) == 12, "Difícil com limite de 12")
	zerar("facil")
	ok(cs.limite_bonus() == 0, "partida no Fácil lê limite 0")
	encher()
	for id in ["ima", "critico", "vel_mov", "vida"]:
		dar(id, 1)
	ok(not cs.cheio(), "sem limite nunca fica cheio (%d bônus)" % cs.bonus_contados())
	var mao_f: Array = cs.montar_mao(8, 1.0, 0, -1, false, true)
	ok(tipos(mao_f).nov == 1 and tipos(mao_f).troca == 0, "no Fácil a novidade é NOVO, não TROCA")

	# 2. o Difícil conta 12: 11 não está cheio, 12 está; subir o nível de um bônus não ocupa vaga
	zerar("dificil")
	ok(cs.limite_bonus() == 12, "partida no Difícil lê limite 12")
	var ids := encher()
	ok(cs.bonus_contados() == 12 and cs.cheio(), "12 bônus distintos = cheio (%d)" % cs.bonus_contados())
	dar("dano", 3)
	ok(cs.bonus_contados() == 12, "subir o nível de um bônus que já tenho não ocupa vaga")
	zerar("dificil")
	for id in ids.slice(0, 11):
		dar(id, 1)
	ok(not cs.cheio() and cs.bonus_contados() == 11, "11 bônus ainda tem vaga")

	# 3. fusão feita conta 1 e libera vaga: duas peças (2 vagas) viram uma fusão (1 vaga), as peças não aparecem na lista de troca
	zerar("dificil")
	var ev: Dictionary = {}
	for e in cs.cfg.evolucoes:
		if (
			str(e.get("raridade", "")) != "lendario"
			and e.pecas.size() == 2
			and cs._cat[str(e.pecas[0].id)] == "golpe"
			and cs._cat[str(e.pecas[1].id)] == "golpe"
		):
			ev = e
			break
	ok(not ev.is_empty(), "achei uma fusão comum de dois golpes para testar")
	if not ev.is_empty():
		dar(str(ev.pecas[0].id), int(ev.pecas[0].nivel) - 1)
		dar(str(ev.pecas[1].id), int(ev.pecas[1].nivel) - 1)
		ok(cs.bonus_contados() == 2 and cs.evoluidas.is_empty(), "duas peças antes da fusão ocupam 2 vagas (%d)" % cs.bonus_contados())
		dar(str(ev.pecas[1].id), 1)
		dar(str(ev.pecas[0].id), 1)
		ok(cs.evoluidas.has(ev.id), "a fusão aconteceu")
		ok(cs.bonus_contados() == 1, "a fusão feita ocupa 1 vaga e libera a outra (%d)" % cs.bonus_contados())
		ok(cs.bonus_trocaveis().is_empty(), "peça consumida e fusão feita não aparecem na lista de troca")

	# 4. mão de Difícil cheio: 2 upgrades + a novidade TROCA em 200 sorteios; o baú e `sortear` não oferecem novidade
	zerar("dificil")
	var meus := encher()
	var certas := 0
	var novidade_dos_meus := 0
	for i in 200:
		var mao: Array = cs.montar_mao(8, 1.0, 0, -1, false, true)
		var tp := tipos(mao)
		if mao.size() == 3 and tp.up == 2 and tp.troca == 1 and tp.nov == 0:
			certas += 1
		for k in mao:
			if str(k.tipo) == "troca":
				if meus.has(str(k.id)) or str(k.nivel_txt) != "Cheio: escolha quem sai":
					novidade_dos_meus += 1
	ok(certas == 200, "cheio: a mão é 2 upgrades + 1 TROCA em 200 sorteios (%d de 200)" % certas)
	ok(novidade_dos_meus == 0, "a TROCA é de bônus que não tenho e diz 'Cheio: escolha quem sai'")
	var so_ups := 0
	for i in 100:
		var mb: Array = cs.montar_mao(8, 1.0, 0, 3, false)  # o baú: sem com_troca
		var mc: Array = cs.sortear(3, 8)
		for k in mb + mc:
			if str(k.tipo) != "up":
				so_ups += 1
	ok(so_ups == 0, "baú e `sortear` cheios: a novidade não cabe e vira upgrade")

	# 5. remover_bonus desfaz o efeito de cada categoria
	zerar("dificil")
	var h = w.heroi
	var golpe: String = golpes_livres(1)[0]
	var dano0: float = h.m_dano
	var vida0: float = h.vida_max
	var area0: float = h.m_area
	var mod0: float = c.armas.mods["onda"]
	var rup0: float = c.ruptura.somas["dano"]
	dar(golpe, 2)
	dar("dano", 2)
	dar("vida", 2)
	dar("area", 1)
	dar("onda", 2)
	dar("rb_dano", 2)
	ok(
		c.armas.ativas.has(golpe) and h.m_dano > dano0 and h.vida_max > vida0 and c.armas.mods["onda"] > mod0 and c.ruptura.somas["dano"] > rup0,
		"os bônus de teste entraram"
	)
	h.vida = h.vida_max
	var n_antes: int = cs.bonus_contados()
	ok(cs.remover_bonus("dano") and is_equal_approx(h.m_dano, dano0), "trocar o stat dano devolve m_dano ao valor de antes (%.4f vs %.4f)" % [h.m_dano, dano0])
	ok(cs.remover_bonus("vida") and is_equal_approx(h.vida_max, vida0), "trocar a vida devolve vida_max ao valor de antes (%.2f vs %.2f)" % [h.vida_max, vida0])
	ok(h.vida <= h.vida_max, "a vida atual não passa da nova vida máxima")
	ok(cs.remover_bonus("area") and is_equal_approx(h.m_area, area0), "trocar a área devolve m_area")
	ok(cs.remover_bonus(golpe) and not c.armas.ativas.has(golpe), "trocar o golpe tira a arma do herói")
	ok(cs.remover_bonus("onda") and is_equal_approx(c.armas.mods["onda"], mod0), "trocar o modificador zera o efeito dele")
	ok(cs.remover_bonus("rb_dano") and is_equal_approx(c.ruptura.somas["dano"], rup0), "trocar a ruptura zera a soma dela")
	ok(cs.bonus_contados() == n_antes - 6, "seis bônus largados, seis vagas livres (%d)" % cs.bonus_contados())
	ok(not cs.remover_bonus("dano"), "largar de novo o que já saiu não faz nada")
	ok(not cs.remover_bonus("nao_existe"), "id desconhecido não faz nada")
	ok(cs.nivel_de("dano") == 0 and not c.progresso.melhorias.has("dano"), "o nível e as melhorias do bônus largado voltam a zero")

	# 6. o bônus largado nunca volta, nem como novidade, em 300 sorteios (e o Fácil/outros não são afetados)
	zerar("dificil")
	encher()
	cs.remover_bonus("dano")
	var largado: String = cs.descartadas[0]
	var voltou := 0
	for i in 300:
		for k in cs.montar_mao(8, 1.0, 0, -1, false, true):
			if str(k.id) == largado:
				voltou += 1
	ok(voltou == 0, "o bônus largado (%s) não volta em 300 sorteios (voltou %d)" % [largado, voltou])
	zerar("dificil")
	ok(cs.descartadas.is_empty(), "uma partida nova esquece os descartes")

	# 7. o automático nunca leva novidade nem troca no Difícil cheio
	zerar("dificil")
	encher()
	var auto_ruim := 0
	var auto_vazio := 0
	for i in 100:
		var mao_a: Array = cs.montar_mao(8, 1.0, 0, -1, false, true)
		var r: Dictionary = cs.escolha_automatica(mao_a)
		if r.is_empty():
			auto_vazio += 1
		elif int(r.nivel_atual) == 0 or str(r.tipo) == "troca":
			auto_ruim += 1
	ok(auto_ruim == 0 and auto_vazio == 0, "o automático escolhe sempre um upgrade (ruim %d, vazio %d)" % [auto_ruim, auto_vazio])
	zerar("facil")
	for id in ["dano", "vida"]:
		dar(id, 1)
	dar(golpes_livres(1)[0], 2)  # um golpe no nível 2: o automático libera a novidade (auto_novidade_nivel)
	var novidade_no_facil := false
	for i in 60:
		var r2: Dictionary = cs.escolha_automatica(cs.montar_mao(8, 1.0, 0, -1, false, true))
		if not r2.is_empty() and int(r2.nivel_atual) == 0:
			novidade_no_facil = true
	ok(novidade_no_facil, "no Fácil o automático ainda leva uma novidade (a regra de CAR-3 não mudou)")

	# 8. mão toda de TROCA (todos os bônus no máximo) ganha a cura para o tempo esgotado ter o que escolher
	zerar("dificil")
	for id in ["dano", "vida", "area", "vel_ataque", "vel_mov", "ima", "critico", "explode", "folego", "abalo", "rb_dano", "rb_recarga"]:
		dar(id, int(cs.definicao(id).max) - cs.nivel_de(id))
	var cheios := 0
	for id in cs.bonus_trocaveis():
		if cs.nivel_de(id) >= int(cs.definicao(id).max):
			cheios += 1
	var niveis := {}
	for id in cs.bonus_trocaveis():
		niveis[id] = cs.nivel_de(id)
	ok(cs.cheio() and cheios == 12, "doze bônus no máximo (%d no máximo, %d no total, %s)" % [cheios, cs.bonus_contados(), niveis])
	c.progresso.pendentes = 1
	c.progresso.abrir_escolha()
	var tp8 := tipos(c.progresso.cartas)
	var tem_cura := false
	for k in c.progresso.cartas:
		if str(k.id) == "cura":
			tem_cura = true
	ok(c.progresso.cartas.size() == 3 and tem_cura and tp8.troca == 2, "mão sem upgrade possível: 2 TROCA + a cura (troca %d, cura %s)" % [tp8.troca, tem_cura])
	var i_cura := 0  # escolher a cura não é um bônus: não ocupa vaga, não entra na lista de troca e o resumo da build não quebra (regressão: estado["cura"])
	for q in c.progresso.cartas.size():
		if str(c.progresso.cartas[q].id) == "cura":
			i_cura = q
	c.progresso.escolher(i_cura)
	ok(
		c.jogo == "jogando" and cs.bonus_contados() == 12 and not cs.estado.has("cura") and not cs.bonus_trocaveis().has("cura"),
		"a carta Cura não vira bônus nem ocupa vaga"
	)
	ok(cs.resumo().size() == 5, "o resumo da build segue sem a cura (%d linhas)" % cs.resumo().size())

	# 9. pela janela: subir de nível no Difícil cheio, Enter na TROCA abre o painel
	zerar("dificil")
	encher()
	subir_nivel()
	var i_troca := indice_troca()
	ok(c.jogo == "escolha" and c.progresso.cartas.size() == 3 and i_troca >= 0, "o nível abriu a escolha com uma carta TROCA (índice %d)" % i_troca)
	var antes_ids: Array = []
	for k in c.progresso.cartas:
		antes_ids.append(str(k.id))
	var novo_id: String = antes_ids[i_troca]
	escolher_pela_janela(i_troca)
	ok(t.troca_aberta and c.jogo == "escolha", "Enter na carta TROCA abre o painel e a escolha continua")
	ok(t.troca_ids.size() == 12 and t._troca.visible, "o painel lista as 12 linhas")
	var visiveis := 0
	for p in t._troca_linhas:
		if p.visible:
			visiveis += 1
	ok(visiveis == 12, "12 linhas visíveis (%d)" % visiveis)
	ok(c.progresso.escolhidas == 0 and cs.nivel_de(novo_id) == 0 and cs.bonus_contados() == 12, "abrir o painel não escolheu nem largou nada")

	# 10. a guarda de 0,3 s: Enter e clique logo depois de abrir não largam nada
	_toque(KEY_ENTER)
	passos(1)
	ok(t.troca_aberta and cs.bonus_contados() == 12, "Enter nos primeiros 0,3 s não larga bônus")
	passos(25)
	ok(t._troca_guarda <= 0.0, "a guarda de 0,3 s acabou")

	# 11. ESC volta às 3 cartas sem perder nada, e não abre a pausa nem o 'Pausar agora?'
	var limite_antes: float = t.limite_t
	_toque(KEY_ESCAPE)
	passos(2)
	var depois_ids: Array = []
	for k in c.progresso.cartas:
		depois_ids.append(str(k.id))
	ok(not t.troca_aberta and not t._troca.visible, "ESC fecha o painel")
	ok(c.jogo == "escolha" and not w.pausa.aberto and not t.conf_aberta, "ESC no painel não pausa nem pergunta 'Pausar agora?'")
	ok(depois_ids == antes_ids and cs.bonus_contados() == 12 and cs.descartadas.is_empty(), "as 3 cartas e os 12 bônus continuam iguais")
	ok(t.limite_t < limite_antes, "o limite de tempo seguiu correndo no painel (%.2f -> %.2f)" % [limite_antes, t.limite_t])
	_toque(KEY_ESCAPE)
	passos(2)
	ok(t.conf_aberta, "ESC de novo, fora do painel, abre o 'Pausar agora?' (comportamento antigo)")
	_toque(KEY_ESCAPE)
	passos(2)
	ok(not t.conf_aberta and c.jogo == "escolha", "ESC fecha o 'Pausar agora?'")

	# 12. navegação: baixo anda, direita muda de coluna (a lista enche a primeira coluna e depois a segunda), a volta fecha o círculo
	escolher_pela_janela(i_troca)
	passos(25)
	ok(t.troca_sel == 0, "o painel abre na primeira linha")
	_toque(KEY_DOWN)
	ok(t.troca_sel == 1, "baixo vai para a linha 2 (%d)" % t.troca_sel)
	_toque(KEY_UP)
	_toque(KEY_UP)
	ok(t.troca_sel == 5, "cima da primeira linha dá a volta para a última da coluna (%d)" % t.troca_sel)
	_toque(KEY_RIGHT)
	ok(t.troca_sel == 11, "direita passa para a segunda coluna na mesma linha (%d)" % t.troca_sel)
	_toque(KEY_LEFT)
	ok(t.troca_sel == 5, "esquerda volta (%d)" % t.troca_sel)
	var area0b: float = w.heroi.m_dano
	var alvo: int = t.troca_ids.find("dano")
	ok(alvo >= 0, "o stat dano está na lista")

	# 13. confirmar larga o bônus marcado e leva o novo; m_dano volta ao valor sem o stat
	var sem_dano: float = w.heroi.m_dano - float(cs.estado["dano"].soma) / 100.0
	t.troca_sel = alvo
	t._marcar_troca()
	_toque(KEY_ENTER)
	passos(3)
	ok(not t.troca_aberta and c.jogo == "jogando", "confirmar fecha o painel e a partida segue")
	ok(cs.nivel_de("dano") == 0 and cs.nivel_de(novo_id) == 1, "o dano saiu e o bônus novo (%s) entrou" % novo_id)
	ok(is_equal_approx(w.heroi.m_dano, sem_dano), "m_dano voltou ao valor sem o stat largado (%.4f vs %.4f, antes %.4f)" % [w.heroi.m_dano, sem_dano, area0b])
	ok(cs.bonus_contados() == 12 and cs.descartadas == ["dano"], "continuam 12 bônus e o dano é o descartado")
	ok(c.progresso.escolhidas == 1, "contou como uma escolha")

	# 14. o mouse: passar marca a linha, clicar larga
	zerar("dificil")
	encher()
	subir_nivel()
	i_troca = indice_troca()
	novo_id = str(c.progresso.cartas[i_troca].id)
	escolher_pela_janela(i_troca)
	passos(25)
	var linha: Panel = t._troca_linhas[7]
	var centro := linha.position + linha.size * 0.5
	var alvo7: String = str(t.troca_ids[7])
	mouse_pos = centro
	var mov := InputEventMouseMotion.new()
	mov.position = centro
	Input.parse_input_event(mov)
	passos(1)
	ok(t.troca_sel == 7, "passar o mouse na linha 8 marca ela (%d)" % t.troca_sel)
	_clique(centro)
	passos(3)
	ok(
		not t.troca_aberta and cs.nivel_de(alvo7) == 0 and cs.nivel_de(novo_id) == 1,
		"clicar na linha larga aquele bônus (%s) e leva o novo (%s)" % [alvo7, novo_id]
	)

	# 15. o limite de 8 s segue correndo no painel e, zerado, o automático roda sem trocar
	zerar("dificil")
	encher()
	subir_nivel()
	i_troca = indice_troca()
	var trocaveis_antes: Array = cs.bonus_trocaveis()
	escolher_pela_janela(i_troca)
	passos(25)
	t.limite_t = 0.5
	passos(60)
	ok(not t.troca_aberta and c.jogo == "jogando", "o tempo esgotou com o painel aberto: fechou e a partida seguiu")
	ok(cs.bonus_contados() == 12 and cs.descartadas.is_empty(), "o automático não largou nenhum bônus")
	var tinha_todos := true
	for id in trocaveis_antes:
		if cs.nivel_de(id) == 0:
			tinha_todos = false
	ok(tinha_todos, "todos os bônus de antes continuam; o automático subiu um upgrade")
	ok(c.progresso.escolhidas == 1, "o automático fez a escolha")

	# 16. ESC (Sim) com a mão de TROCA perde a rodada sem largar nada
	zerar("dificil")
	encher()
	subir_nivel()
	_toque(KEY_ESCAPE)
	passos(2)
	t.conf_sel = 0
	t._conf_agir()
	passos(2)
	ok(cs.bonus_contados() == 12 and cs.descartadas.is_empty() and not t.troca_aberta, "perder a rodada não larga bônus")
	if w.pausa.aberto:
		w.pausa.fechar()

	# 17. o card de status mostra "Bônus 12 / 12" no Difícil e nada no Fácil
	zerar("dificil")
	encher()
	var lin: Dictionary = Status.linha(Status.coletar(w), "heroi.bonus")
	ok(not lin.is_empty() and str(lin.valor) == "12 / 12", "status: Bônus 12 / 12 (%s)" % str(lin.get("valor", "")))
	zerar("facil")
	ok(Status.linha(Status.coletar(w), "heroi.bonus").is_empty(), "status: sem a linha de Bônus no Fácil")

	# 18. cada dificuldade tem o texto da carta TROCA só quando cheio (a mão do Fácil nunca tem selo de troca)
	zerar("facil")
	encher()
	subir_nivel()
	ok(indice_troca() < 0 and c.jogo == "escolha", "no Fácil a escolha de nível não tem carta TROCA")
	c.progresso.descartar_rodada()


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	zerar("dificil")
	encher()
	dar("dano", 3)
	dar("vida", 4)
	dar(golpes_livres(1)[0], 4)
	var t = w.combate.telas
	subir_nivel()
	passos(30)
	var tam = await w.ap.foto(pasta.path_join("mao_troca.png"))
	print("FOTO mao_troca %s" % tam)
	var i := indice_troca()
	t.abrir_troca(i)
	passos(30)
	tam = await w.ap.foto(pasta.path_join("painel_troca.png"))
	print("FOTO painel_troca %s limite=%.2f" % [tam, t.limite_t])
	t.troca_sel = 7
	t._marcar_troca()
	t.limite_t = 2.5
	passos(10)
	tam = await w.ap.foto(pasta.path_join("painel_troca_urgente.png"))
	print("FOTO painel_troca_urgente %s" % tam)


func _ready() -> void:
	_run()
