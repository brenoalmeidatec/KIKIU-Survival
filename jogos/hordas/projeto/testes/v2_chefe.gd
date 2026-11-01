extends "res://testes/isolamento_v2.gd"
# Teste dos CHEFES da v2 (v2/chefe.gd): a IDENTIDADE de cada marca (ataque próprio anunciado e esquivável, adorno) e o mini-chefe do nível 10 (anúncio, barra, ataques anunciados que disparam, dano, baú, e matá-lo
# não é vitória), o do nível 20 e o CHEFÃO do nível 30, que é a vitória: o mapa fica vencido no save (combate.fim_de_partida chama
# Meta.marcar_mapa_vencido). Os níveis em si estão em testes/v2_diretor.gd.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_chefe.tscn  (imprime "v2_chefe falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Meta := preload("res://v2/meta.gd")
const PASSO := 1.0 / 60.0
const SAVE_TESTE := "user://testes_v2/v2_chefe/teste_v2_chefe.cfg"
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


func conta(nome: String) -> int:
	return int(sinais.get(nome, 0))


func conta_tipo(av, t: int) -> int:
	var n := 0
	for i in av.MAX:
		if av.tipo[i] == t:
			n += 1
	return n


## O chefe da marca `idx` em campo até o COMEÇO do primeiro ataque, que é o próprio dele. O herói fica mortal com a vida cheia e o chefe sem
## dano de contato (só o ataque anunciado pode machucar). Devolve o monstro.
func ate_o_aviso(idx: int, fase2 := false):
	zerar()
	var ch = w.combate.chefes
	var h = w.heroi
	var m = ch.nascer(ch.cfg.marcas[idx], h.pos + Vector2(120, 0))
	m.dano = 0.0
	if fase2:
		m.vida = m.vida_max * 0.4
	ate(func(): return ch.estado == "aviso", 900)
	h.imortal = false
	h.vida = h.vida_max
	h.invenc = 0.0
	return m


## O chefe morre no meio do aviso (revoada do chefão, teia da Rainha): os avisos dele são cancelados, então nada dispara depois (nem dano, nem
## filhote, nem lentidão), mas o aviso de outra fonte (aqui um círculo sem dono, como o da elite explosiva) continua.
func morte_no_aviso() -> void:
	var ch = w.combate.chefes
	var h = w.heroi
	var av = w.combate.avisos
	for idx in [2, 1]:
		ate_o_aviso(idx)
		h.xp_proximo = 1.0e9  # matar o chefe não pode abrir a escolha de nível
		ate(func(): return av.t[0] >= av.dur[0] - 0.15, 120)  # quase no disparo: a câmera lenta da vitória não segura o que sobrou
		var estranho: int = av.circulo(h.pos + Vector2(300, 0), 30.0, 0.3, 0.0, Color.WHITE)  # dispara depois do aviso do chefe
		ok(av.ativos() > 1, "morte no aviso (%s): há avisos pendentes do chefe" % ch.marca.nome)
		var d0: int = av.disparados
		w.combate.ferir(ch.atual, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
		w.combate.processar_mortes()
		ok(not ch.vivo and av.ativos() == 1 and av.tipo[estranho] == 1, "morte no aviso (%s): só os avisos do chefe saem de cena" % ch.marca.nome)
		w.combate.jogo = "jogando"
		passos(100)
		ok(av.disparados == d0 + 1, "morte no aviso (%s): nada do chefe dispara (disparados +%d)" % [ch.marca.nome, av.disparados - d0])
		ok(
			h.vida == h.vida_max and ch._teia_t == 0.0 and ch._filhotes.is_empty() and ch.visual.voos.is_empty(),
			"morte no aviso (%s): sem dano, lentidão, filhote nem corvo" % ch.marca.nome
		)
		w.combate.jogo = "jogando"


## Cada marca tem identidade: um ataque só dela (anunciado, esquivável) e uma aparência própria (v2/chefe_visual.gd).
func identidade_dos_chefes() -> void:
	var ch = w.combate.chefes
	var h = w.heroi
	var av = w.combate.avisos
	var marcas: Array = ch.cfg.marcas
	var proprios := {"mini1": "leque", "mini2": "teia", "chefe": "revoada"}
	var adornos := {}
	for mk in marcas:
		var meu: String = proprios[mk.id]
		ok(mk.ataques.has(meu) and ch.cfg.ataques.has(meu), "%s: o ataque próprio (%s) está nos dados e na lista dele" % [mk.nome, meu])
		for outro in proprios:
			if outro != mk.id:
				ok(not mk.ataques.has(proprios[outro]), "%s não usa o ataque de %s" % [mk.nome, outro])
		ok(str(mk.ataques[0]) == meu, "%s: o primeiro ataque é o próprio" % mk.nome)
		adornos[str(mk.visual.adorno)] = true
	ok(adornos.size() == marcas.size(), "cada marca tem um adorno diferente")
	# --- Devourer of Flesh: o leque (setor no chão)
	var m = ate_o_aviso(0)
	ok(ch._ataque == "leque" and conta_tipo(av, 3) == 1 and av.ativos() == 1, "leque: o aviso é um setor no chão")
	var d0: int = av.disparados
	passos(30)
	ok(h.vida == h.vida_max and av.disparados == d0, "leque: durante o aviso ninguém leva dano")
	ate(func(): return av.disparados > d0, 120)
	ok(av.disparados == d0 + 1 and h.vida < h.vida_max, "leque: depois do aviso o setor dispara e machuca quem ficou nele")
	ok(is_equal_approx(h.vida_max - h.vida, float(ch.cfg.ataques.leque.dano)), "leque: o dano é o dos dados")
	m = ate_o_aviso(0)
	var d: Vector2 = h.pos - m.pos
	h.definir_pos(m.pos - d.normalized() * 30.0)  # para o lado oposto do leque: dá para sair
	d0 = av.disparados
	ate(func(): return av.disparados > d0, 120)
	ok(av.disparados == d0 + 1 and h.vida == h.vida_max, "leque: dá para esquivar (sair do setor)")
	m = ate_o_aviso(0, true)
	ok(ch._fase2 and ch._ataque == "leque" and conta_tipo(av, 3) == 2, "leque na fúria: um segundo golpe para o lado oposto")
	# --- Devourer of Structure: a teia (círculo que deixa lento e solta filhotes)
	m = ate_o_aviso(1)
	ok(ch._ataque == "teia" and conta_tipo(av, 1) == 1 and av.estilo[0] == 3, "teia: o aviso é um círculo de teia")
	d0 = av.disparados
	passos(30)
	ok(h.vida == h.vida_max and ch._teia_t == 0.0 and ch._filhotes.is_empty(), "teia: durante o aviso nada acontece ainda")
	ate(func(): return av.disparados > d0, 150)
	ok(h.vida < h.vida_max and ch._teia_t > 2.0, "teia: quem ficou nela leva o dano e fica lento")
	ok(ch._filhotes.size() == int(ch.cfg.ataques.teia.filhotes), "teia: solta os filhotes de aranha (%d)" % ch._filhotes.size())
	ok(ch._filhotes[0].vivo and ch._filhotes[0].cacador and ch._filhotes[0].chave == "inimigo_aranha_tecela", "teia: os filhotes são aranhas que caçam o herói")
	var x0: float = h.pos.x
	h.entrada_forcada = Vector2.RIGHT
	ch._teia_t = 5.0
	passos(30)
	var lento: float = h.pos.x - x0
	ch._teia_t = 0.0
	x0 = h.pos.x
	passos(30)
	var normal: float = h.pos.x - x0
	h.entrada_forcada = Vector2.ZERO
	ok(normal > 10.0 and lento > 2.0 and lento < normal * 0.65, "teia: lento anda a metade (%.1f contra %.1f px)" % [lento, normal])
	m = ate_o_aviso(1)
	h.definir_pos(h.pos + Vector2(300, 0))  # longe do círculo: sair da teia
	d0 = av.disparados
	ate(func(): return av.disparados > d0, 150)
	ok(h.vida == h.vida_max and ch._teia_t == 0.0, "teia: dá para esquivar (sair do círculo)")
	# esquiva com i-frames no disparo: não leva dano, então não fica lento (os filhotes nascem de qualquer jeito: são monstros)
	m = ate_o_aviso(1)
	ate(func(): return av.t[0] >= av.dur[0] - 2.0 * PASSO, 150)
	h.estado = Heroi.Estado.ESQUIVA
	h.esq_t = 0.0
	var dentro: float = (h.pos - av.pos[0]).length()
	ok(dentro < float(ch.cfg.ataques.teia.raio) * 0.5, "teia (esquiva): o herói esquiva de dentro do círculo (%.0f px do centro)" % dentro)
	d0 = av.disparados
	ate(func(): return av.disparados > d0, 30)
	ok(av.disparados == d0 + 1 and not av.acertou and h.vida == h.vida_max, "teia (esquiva): os i-frames evitam o dano")
	ok(ch._teia_t == 0.0, "teia (esquiva): quem não levou dano não fica lento")
	ok(ch._filhotes.size() == int(ch.cfg.ataques.teia.filhotes), "teia (esquiva): os filhotes nascem mesmo assim")
	h.estado = Heroi.Estado.LIVRE
	# escudo erguido de frente para a teia: o escudo consome o golpe (levar_dano devolve true), mas a vida fica intacta e o herói NÃO fica lento
	m = ate_o_aviso(1)
	h.escudo_forcado = true
	ate(func(): return av.t[0] >= av.dur[0] - 2.0 * PASSO, 150)
	ok(h.escudo_ativo, "teia (escudo): o escudo está erguido no disparo")
	var bl0: int = w.combate.escudo.bloqueios
	d0 = av.disparados
	ate(func(): return av.disparados > d0, 30)
	h.escudo_forcado = false
	ok(av.disparados == d0 + 1 and h.vida == h.vida_max, "teia (escudo): o escudo segura o golpe, a vida fica intacta")
	ok(w.combate.escudo.bloqueios == bl0 + 1, "teia (escudo): o golpe foi bloqueado pelo escudo")
	ok(not av.acertou and ch._teia_t == 0.0, "teia (escudo): quem bloqueou não perdeu vida e não fica lento")
	ok(ch._filhotes.size() == int(ch.cfg.ataques.teia.filhotes), "teia (escudo): os filhotes nascem mesmo assim")
	passos(3)
	h.estado = Heroi.Estado.LIVRE
	# a lentidão só corta o andar LIVRE: esquiva, golpe e carga andam à vontade (o herói "andou" 10 px no quadro)
	for e in [Heroi.Estado.LIVRE, Heroi.Estado.ESQUIVA, Heroi.Estado.GOLPE, Heroi.Estado.CARGA]:
		h.estado = e
		ch._teia_t = 5.0
		ch._h_antes = h.pos - Vector2(10, 0)
		var antes: Vector2 = h.pos
		ch._teia_atualizar(0.0)
		var cortou: float = (antes - h.pos).x
		if e == Heroi.Estado.LIVRE:
			ok(is_equal_approx(cortou, 10.0 * (1.0 - ch._teia_mult)), "teia: corta o andar livre (%.1f px)" % cortou)
		else:
			ok(h.pos == antes, "teia: não corta o estado %d" % e)
	h.estado = Heroi.Estado.LIVRE
	ch._teia_t = 0.0
	m = ate_o_aviso(1, true)
	ate(func(): return not ch._filhotes.is_empty(), 150)
	ok(ch._filhotes.size() == int(ch.cfg.ataques.teia.filhotes_fase2), "teia na fúria: mais filhotes (%d)" % ch._filhotes.size())
	# --- Devourer of Land: a revoada (faixas paralelas varridas por corvos)
	m = ate_o_aviso(2)
	var linhas := int(ch.cfg.ataques.revoada.linhas)
	ok(ch._ataque == "revoada" and conta_tipo(av, 2) == linhas, "revoada: o aviso são %d faixas no chão" % linhas)
	d0 = av.disparados
	passos(30)
	ok(h.vida == h.vida_max and av.disparados == d0 and ch.visual.voos.is_empty(), "revoada: durante o aviso ninguém leva dano e os corvos ainda não voaram")
	ate(func(): return av.disparados > d0, 150)
	ok(av.disparados == d0 + linhas and h.vida < h.vida_max, "revoada: as faixas disparam juntas e a que passa por cima do herói machuca")
	ok(is_equal_approx(h.vida_max - h.vida, float(ch.cfg.ataques.revoada.dano)), "revoada: leva o dano uma vez só")
	ok(ch.visual.voos.size() == linhas * ch.visual.CORVOS_POR_FAIXA, "revoada: os corvos voam pelas faixas")
	var varreu: int = ate(func(): return ch.visual.voos.is_empty(), 180)  # o acerto no herói dá um instante de hit-stop
	ok(varreu >= 0 and ch.visual.VOO_S <= 0.2, "revoada: os corvos varrem a faixa em %.2f s, junto com o dano e não meio segundo depois" % ch.visual.VOO_S)
	ok(ch.visual.voos.is_empty(), "revoada: os corvos somem depois de varrer")
	m = ate_o_aviso(2)
	var g := Vector2(h.pos.x - m.pos.x, (h.pos.y - m.pos.y) / 0.62).normalized()
	var perp := Vector2(-g.y, g.x) * (float(ch.cfg.ataques.revoada.espaco) * 0.5)  # no meio do vão entre duas faixas
	h.definir_pos(h.pos + Vector2(perp.x, perp.y * 0.62))
	d0 = av.disparados
	ate(func(): return av.disparados > d0, 150)
	ok(av.disparados == d0 + linhas and h.vida == h.vida_max, "revoada: dá para esquivar (ficar no vão entre as faixas)")
	m = ate_o_aviso(2, true)
	ok(ch._fase2 and conta_tipo(av, 2) == int(ch.cfg.ataques.revoada.linhas_fase2), "revoada na fúria: mais faixas")
	morte_no_aviso()
	# --- a aparência: o adorno é desenhado sobre o corpo de cada chefe e some quando ele morre
	for i in marcas.size():
		zerar()
		m = ch.nascer(marcas[i], h.pos + Vector2(200, 0))
		var vis = ch.visual
		ok(
			vis.adorno == str(marcas[i].visual.adorno) and vis.atras.get_parent() == m.raiz and vis.frente.get_parent() == m.raiz,
			"%s: o adorno está no corpo" % marcas[i].nome
		)
		ok(
			vis.atras.visible and vis.frente.visible and m.raiz.get_child(0) == vis.atras,
			"%s: o adorno aparece e a parte de trás é desenhada antes do sprite" % marcas[i].nome
		)
		passos(5)
		w.combate.ferir(m, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
		w.combate.processar_mortes()
		ok(not vis.atras.visible and not vis.frente.visible and vis.adorno == "", "%s: o adorno some com o chefe" % marcas[i].nome)
		w.combate.jogo = "jogando"
	ok(float(marcas[2].visual.get("luz", 1.0)) > 1.0, "o chefão brilha mais que os mini-chefes")
	h.imortal = true


## Sair do mapa libera os controladores e os nós do visual do chefe (a referência cruzada chefe <-> visual não pode segurá-los), com e sem chefe.
func liberacao() -> void:
	for com_chefe in [false, true]:
		var w2 = Mundo.instantiate()
		w2.modo_teste = true
		add_child(w2)
		w2.set_process(false)
		w2.combate.audio.mudo = true
		var ch = w2.combate.chefes
		if com_chefe:
			ch.nascer(ch.cfg.marcas[2], w2.heroi.pos + Vector2(120, 0))
			w2.avancar(PASSO)
		var v = ch.visual
		var refs := {
			"combate": weakref(w2.combate),
			"chefes": weakref(ch),
			"visual": weakref(v),
			"atras": weakref(v.atras),
			"frente": weakref(v.frente),
			"no_voo": weakref(v.no_voo)
		}
		var etiqueta := "com chefe" if com_chefe else "sem chefe"
		ok(
			v.atras.get_parent() != null if com_chefe else v.atras.get_parent() == null,
			"liberação (%s): o adorno %s" % [etiqueta, "está no corpo" if com_chefe else "ainda é órfão"]
		)
		v = null
		ch = null
		remove_child(w2)
		w2.free()
		await get_tree().process_frame
		for k in refs:
			ok(refs[k].get_ref() == null, "liberação (%s): %s é liberado ao sair da partida" % [etiqueta, k])


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

	identidade_dos_chefes()
	await liberacao()

	# save de teste: a vitória marca o mapa como vencido nele, nunca no save de verdade
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TESTE))
	Meta.caminho_save = SAVE_TESTE
	# o chefão do nível 10 (o último da Floresta) em campo: o nível sobe sozinho até lá
	zerar()
	w.combate.diretor.ligado = false
	var dir = w.combate.diretor
	var seg: float = dir.seg_nivel()
	dir.ir_para_nivel(9)
	dir.t_nivel = seg - 0.5
	passos(50)
	ok(dir.nivel == 10 and w.combate.chefes.vivo and w.combate.chefes.marca.id == "n10", "o chefão do nível 10 está em campo")

	var ch = w.combate.chefes.atual
	ok(ch.chefe and ch.escala > 2.0 and ch.vida_max >= 4000.0, "o chefão é grande e tem muita vida (%s)" % ch.vida_max)
	ok(conta("chefe") == 1 and sinais.get("chefe_vida_max", 0.0) == ch.vida_max, "sinal chefe_apareceu(nome, vida_max)")
	ok(
		str(sinais.get("anuncio_texto", "")).contains("CHEFE") and not str(sinais.get("anuncio_texto", "")).contains("MINI"),
		"anuncio('CHEFE: ...') junto do chefe_apareceu (%s)" % str(sinais.get("anuncio_texto", ""))
	)
	ate(func(): return w.combate.avisos.ativos() > 0, 900)
	ok(w.combate.avisos.ativos() > 0 and w.combate.chefes.ataques_feitos > 0, "o chefe anuncia o ataque com uma área piscando no chão")
	var vida_h: float = w.heroi.vida
	ate(func(): return w.combate.avisos.disparados > 0, 400)
	ok(w.combate.avisos.disparados > 0, "depois do aviso a área dispara")
	w.heroi.imortal = false
	w.heroi.vida = w.heroi.vida_max
	w.combate.avisos.circulo(w.heroi.pos, 40.0, 0.5, 15.0, Color.RED)
	passos(10)
	ok(w.heroi.vida == w.heroi.vida_max, "durante o aviso ninguém leva dano")
	passos(40)
	ok(w.heroi.vida < w.heroi.vida_max, "quem fica na área leva o dano quando ela dispara")
	w.heroi.imortal = true
	var chefe_v0: float = ch.vida
	w.combate.ferir(ch, 50.0, Vector2.RIGHT, 500.0, 2.0, Color.WHITE)
	ok(ch.vida < chefe_v0 and ch.emp.length() < 100.0 and ch.atordoa_t < 0.01, "o chefe apanha mas não sai voando nem fica atordoado")
	passos(5)
	ok(conta("chefe_vida") > 0, "sinal chefe_vida(vida) a cada mudança")
	# o chefão é o último nível: o nível fica travado até ele morrer, e não há mais nível depois dele
	dir.avancar_nivel(seg * 10.0)
	ok(dir.nivel == 10 and w.combate.chefes.vivo and not bool(w.combate.chefes.marca.mini), "com o chefão vivo o nível 10 segue travado")
	ok(w.combate.jogo == "jogando", "o chefão ainda vivo: a partida segue")
	# 8. vencer o chefão é a vitória
	w.abates = 321
	w.maior_combo = 55
	w.xp_coletado = 1234.0
	w.combate.ferir(w.combate.chefes.atual, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	w.combate.processar_mortes()
	ok(w.combate.jogo == "vencendo" and w.monstros.is_empty(), "matar o chefe começa a vitória e os monstros estouram")
	ate(func(): return w.combate.jogo == "vitoria", 300)
	ok(w.combate.jogo == "vitoria" and w.combate.pausado and w.combate.telas.resultado_aberto, "a tela de resultado abre na vitória")
	ok(w.combate.telas._res_titulo.text == "VITÓRIA", "a tela mostra VITÓRIA")
	ok(conta("fim") == 1, "partida_terminou saiu uma vez")
	var res: Dictionary = sinais.get("fim_res", {})
	for k in ["tempo", "abates", "nivel", "maior_combo", "venceu", "almas", "mapa", "nivel_mapa", "niveis_mapa"]:
		ok(res.has(k), "partida_terminou traz o campo %s" % k)
	ok(res.get("venceu") == true and int(res.get("abates", 0)) >= 321 and int(res.get("maior_combo", 0)) == 55, "campos da vitória certos")
	ok(int(res.get("almas", -1)) == 123 and w.almas_partida == 123, "almas = XP coletado / 10 arredondado (123)")
	ok(int(res.get("nivel", 0)) >= 1, "nível do herói")
	ok(str(res.get("mapa", "")) == "floresta" and int(res.get("nivel_mapa", 0)) == 10, "a vitória é no último nível da floresta (o 10)")
	ok(w.combate.telas._res_linhas.text.contains("Almas") and w.combate.telas._res_valores.text.contains("123"), "a tela mostra as almas ganhas")
	ok(Meta.mapa_vencido("floresta") and Meta.mapas_vencidos().size() == 1, "vencer o chefão marca a Floresta como vencida no save")
	# o ciclo do mini-chefe (ECO-1 o tirou da Floresta, cujo chefão agora está no nível 10): na Torre o nível 10 é mini e o 20 é o chefão
	zerar()
	dir.carregar_niveis("laboratorio")
	dir.zerar()
	seg = dir.seg_nivel()
	dir.ir_para_nivel(9)
	dir.t_nivel = seg - 0.5
	passos(50)
	ok(
		dir.nivel == 10 and w.combate.chefes.vivo and bool(w.combate.chefes.marca.mini) and w.combate.chefes.marca.id == "n10",
		"Torre: o mini-chefe do nível 10 está em campo"
	)
	var baus0: int = w.combate.baus.soltos
	w.combate.ferir(w.combate.chefes.atual, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	w.combate.processar_mortes()
	ok(not w.combate.chefes.vivo and float(sinais.get("chefe_vida_ultima", 1.0)) == 0.0, "a morte do mini-chefe emite chefe_vida(0)")
	ok(w.combate.baus.soltos == baus0 + 1, "o mini-chefe solta um baú")
	ok(w.combate.jogo == "jogando", "matar o mini-chefe não é vitória")
	ok(not dir.travado(), "mini-chefe morto: o nível destrava")
	dir.avancar_nivel(seg + 0.01)
	ok(dir.nivel == 11, "e segue para o nível 11")
	dir.ir_para_nivel(19)
	dir.t_nivel = 0.0
	dir.avancar_nivel(seg + 0.01)
	ok(dir.nivel == 20 and w.combate.chefes.vivo and not bool(w.combate.chefes.marca.mini), "o CHEFÃO nasce no nível 20, o último da Torre")
	dir.avancar_nivel(seg * 10.0)
	ok(dir.nivel == 20, "o mapa tem fim: não passa do nível 20")
	print("v2_chefe falhas=%d" % falhas)
	get_tree().quit()
