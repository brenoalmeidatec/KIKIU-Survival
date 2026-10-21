extends RefCounted
## Roteiros de teste manual da v2 (medição e fotos), ligados por opções após `--`:
##   --imortal             ninguém tira vida do herói
##   --robo                o herói golpeia sozinho o monstro mais perto e escolhe a 1ª carta quando sobe de nível
##   --estresse=N          mantém N monstros vivos DENTRO da tela, caçando o herói (medir o desempenho com a horda)
##   --roteiro=combate     sequência de fotos do viewport: o corte acertando com número de dano, a estocada, a tela de nível e a de resultado.
##                         Usar com --fotos=PASTA --nome=prefixo (as fotos saem como prefixo_01_corte.png ...). Nunca captura a área de trabalho.
##   --roteiro=correr      foto do herói correndo com a poeira e a câmera adiantada
##   --build               começa a partida com uma build cheia (aura, lâminas, corvos, raio e runa) para medir o desempenho
##   --build=golpes        idem com os 36 projéteis, anéis, meteoros e nuvens no nível 5 (as folhas animadas de docs/combate_v2)
##   --build=tudo          os 36 mais corvos, aura, raio, runa, lâminas e as evoluções desses tipos
##   --roteiro=build|elite|chefe|vitoria|escolha   (leva 3) fotos da build cheia, da elite com baú e roleta, dos três chefes (Cavaleiro Rubro, Rainha Tecelã e Rei Espantalho) anunciando
##                         o ataque próprio e logo depois do disparo, e do chefão na fúria, da tela de vitória e da escolha com raridades (na trava, 20_escolha_trava, e depois de liberar,
##                         21_escolha_liberada). Fotos 11_build ... 21_escolha_liberada: a janela inteira (mundo e interface; em headless, só o viewport do mundo).
##   --roteiro=vitrine|ordem|cerco   (leva 4, desempenho) vitrine: os 5 tipos parados em 3 fileiras, para comparar antes e depois do mesmo quadro;
##                         ordem: aranhas grandes (escala 2) atrás e na frente do herói (ordem de desenho); cerco: a horda com 2 aranhas grandes
##                         depois de 3 s de perseguição, com o herói parado (os monstros cercam e não entram no corpo dele).
##   --roteiro=golpes      (golpes do vídeo KiKiu, PR #306) 1_cristal: explosão com o cristal 0,08 s depois; 2_marca: crítico com a marca branca; 3_telegrafo:
##                         chefe com a carga cheia e o retículo. Fotos prefixo_1_cristal ... Usar com --fotos=PASTA --nome=prefixo.
##   --roteiro=hud_golpes  a faixa de golpes do HUD numa partida real: 9 golpes ganhos, horda caçando o herói. Fotos do viewport: 31_parado (faixa
##                         esmaecida, parada), 32_pulso (0,15 s depois de subir o nível da runa: ícone claro, faixa opaca) e 33_novo (0,12 s
##                         depois de ganhar um golpe novo: pop). Usar com --fotos=PASTA --nome=prefixo.
##   --roteiro=inicio      a abertura real da partida (diretor ligado, herói parado): fotos aos 1, 10 e 20 s e a linha INICIO com o monstro mais perto.
##   --roteiro=cores       (cores de perigo) o herói com Fogo do Céu, Grito de Guerra, Cortina de Sangue e os aliados Golem de Barro e Dragãozinho,
##                         cercado de monstros e um Explosivo ao lado. Fotos 1 a 3 (armas e aliados) e 4_aviso e 5_aviso (o aviso do Explosivo, 0,25 s e 0,5 s depois da morte). Usar com --fotos=PASTA --nome=prefixo.
##   --roteiro=oclusao     (leva 4) herói atrás de uma árvore (1_arvore) e herói coberto por uma aranha grande na frente (2_aranha).
##   --roteiro=ruptura     (tecla E) 24 monstros a caminho do herói parado, que carrega a ruptura. Fotos do viewport: 1_carga (meia carga:
##                         anel fantasma no raio final e anel interno), 2_cheia_perfeita (anel piscando na janela perfeita), 3_disparo (0,10 s
##                         depois de soltar: onda, rachaduras, números), 4_depois (0,6 s: monstros empurrados e atordoados, katana alaranjada
##                         no contragolpe) e 5_slot (HUD com o slot em recarga). Usar com --fotos=PASTA --nome=prefixo.
##   --roteiro=especial    (tecla Q) o ESPECIAL do herói escolhido (--heroi=hazaki|nicao|lucas) contra 30 monstros em volta (e uma fila à frente, para
##                         a investida). Fotos do viewport: 0_vazio (o slot Q com 0% de carga) e 0b_meio (55%), 1_pronto (o slot Q cheio e pulsando, antes de apertar), 2_especial (o momento forte: a investida do
##                         Hazaki, a batida e a onda do Nicão, a tempestade do Lucas) e 3_slot (0,25 s depois de acabar: o slot Q vazio de novo). Usar com --fotos=PASTA --nome=prefixo.
##   --roteiro=habilidade  (tecla E) a HABILIDADE do herói escolhido (--heroi=hazaki|nicao|lucas: a ruptura, a investida de escudo ou o salto das adagas)
##                         contra 30 monstros em volta (e uma fila à frente). Fotos do viewport: 1_pronto (slots E pronto e Q a 55%), 2_habilidade (o momento
##                         forte) e 3_recarga (0,4 s depois: o slot E em recarga). Usar com --fotos=PASTA --nome=prefixo.
##   --playtest            robô de playtest (#301): joga a partida INTEIRA sozinho (anda, foge, golpeia, esquiva, pega baú, escolhe cartas)
##                         até morrer ou vencer e imprime uma linha `PLAYTEST_JSON: {...}` com o desfecho e os números. Vigia de trava: sem
##                         avanço do relógio, tela (cartas/baú) aberta demais ou herói parado no mesmo lugar imprime `TRAVA: <estado>` e sai
##                         com código 3. Opções: --semente=N (sorteios), --playtest_max=S (teto de tempo de jogo, padrão 900),
##                         --playtest_q (o robô aperta o Q quando enche e a E quando pronta; o JSON traz q_prontos, q_disparos, e_disparos e q_carga por fonte),
##                         --playtest_trava=cartas|bau (depuração: o robô para de responder àquela tela, para provar o vigia),
##                         --playtest_fim=morte (partida curta que termina na morte real: parado, com 1 de vida, até um monstro matar).
##                         Usa um save temporário próprio (mundo.gd troca Meta.caminho_save), nunca o do jogador.
##                         O lote, em paralelo e com relatório, roda pelo ferramentas/playtest_v2.py (docs/PLAYTEST_V2.md).
## Nada disto roda no jogo normal.

var mundo
var args := {}
var estresse := 0
var robo := false
var roteiro := ""
var passo := 0
var t_passo := 0.0
var ocupado := false
var pasta := ""
var prefixo := "v2"
var playtest := false
var pt := {}  # estado do robô de playtest (_pt_iniciar)
var pt_disparos := 0  # quantos avisos já tinham disparado quando o chefe nasceu (a foto do disparo)
var pt_fogo := -1.0  # t_passo em que o primeiro aviso disparou (a foto do disparo sai 0,12 s depois)


func montar(m, a: Dictionary) -> void:
	mundo = m
	args = a
	estresse = int(a.get("estresse", 0))
	robo = a.has("robo")
	playtest = a.has("playtest")
	if playtest:
		_pt_iniciar()
	roteiro = str(a.get("roteiro", ""))
	pasta = str(a.get("fotos", ""))
	prefixo = str(a.get("nome", "v2"))
	if a.has("imortal") or roteiro != "":
		mundo.heroi.imortal = true
	if estresse > 0 or (roteiro != "" and roteiro != "inicio"):
		mundo.combate.diretor.ligado = false  # "inicio" deixa o diretor ligado: é a abertura de verdade
	if a.has("build"):
		armar_build()
	if estresse > 0:
		reabastecer()


func ativo() -> bool:
	return estresse > 0 or robo or roteiro != "" or playtest


func atualizar(dt: float) -> void:
	if mundo.combate == null:
		return
	if playtest:
		_playtest(dt)
		return
	if robo or estresse > 0:
		_robo()
	if estresse > 0:
		reabastecer()
	if roteiro != "" and not ocupado:
		t_passo += dt
		match roteiro:
			"combate":
				_combate()
			"correr":
				_correr()
			"build":
				_r_build()
			"elite":
				_r_elite()
			"chefe":
				_r_chefe()
			"vitoria":
				_r_vitoria()
			"escolha":
				_r_escolha()
			"oclusao":
				_r_oclusao()
			"vitrine":
				_r_vitrine()
			"ordem":
				_r_ordem()
			"cerco":
				_r_cerco()
			"ruptura":
				_r_ruptura()
			"especial":
				_r_especial()
			"habilidade":
				_r_habilidade()
			"golpes":
				_r_golpes()
			"hud_golpes":
				_r_hud_golpes()
			"close":
				_r_close()
			"cores":
				_r_cores()
			"inicio":
				_r_inicio()


## Cores de perigo (fotos antes e depois): o herói com as armas e os aliados que tinham vermelho, cercado de monstros, e um Explosivo
## parado ao lado. Fotos 1 a 3 (armas e aliados, 0,5 s cada); o Explosivo morre no passo 4 e as fotos 4_aviso e 5_aviso saem 0,25 s e 0,5 s
## depois da morte (o aviso dura 0,75 s).
func _r_cores() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	match passo:
		0:
			_preparar()
			for id in ["fogo_do_ceu", "grito_guerra", "cortina_sangue", "golem_barro", "dragao_filhote"]:
				c.armas.definir_golpe(id, 3, 0.0)
			for k in 8:
				mundo.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2.from_angle(TAU * k / 8.0) * 110.0, true)
			var e = c.elites.nascer("inimigo_cavaleiro_oco", "explosivo", h.pos + Vector2(120, -10))
			e.cacador = false
			e.raio_vaga = 0.0
			passo = 1
			t_passo = 0.0
		1, 2, 3:
			if t_passo >= 0.5:
				_foto("%d" % passo)
				passo += 1
				t_passo = 0.0
		4:
			if t_passo >= 0.5:
				if not c.elites.vivas.is_empty():
					c.ferir(c.elites.vivas[0], 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
					c.processar_mortes()
				passo = 5
				t_passo = 0.0
		5:
			if t_passo >= 0.25:
				_foto("4_aviso")
				passo = 6
				t_passo = 0.0
		6:
			if t_passo >= 0.25:
				_foto("5_aviso")
				passo = 7
				t_passo = 0.0
		7:
			mundo.get_tree().quit()


# ------------------------------------------------------------------ robô e estresse


func _robo() -> void:
	var h = mundo.heroi
	if mundo.combate.jogo == "escolha":
		mundo.combate.progresso.escolher(0)
		return
	if not robo:
		return
	var alvo = null
	var melhor := 1e12
	for m in mundo.monstros:
		var d: float = m.pos.distance_squared_to(h.pos)
		if d < melhor:
			melhor = d
			alvo = m
	if alvo != null:
		mundo.mouse_forcado = alvo.pos + Vector2(0, -6)
		h.fonte = h.Fonte.MOUSE
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = alvo != null and melhor < 70.0 * 70.0
	if mundo.combate.jogo == "morte":
		mundo.reiniciar()


## Mantém `estresse` monstros vivos dentro da tela, a 90 a 380 px do herói.
func reabastecer() -> void:
	var h = mundo.heroi
	var falta: int = estresse - mundo.monstros.size()
	for i in mini(falta, 6):
		var a := randf() * TAU
		var r := randf_range(90.0, 380.0)
		var p: Vector2 = h.pos + Vector2(cos(a) * r, sin(a) * r * 0.62)
		p = p.clamp(mundo.limite_andavel.position, mundo.limite_andavel.end)
		var tipos: Array = mundo.TIPOS_MONSTRO
		mundo.nascer_monstro(tipos[randi() % tipos.size()], p, true)


# ------------------------------------------------------------------ fotos


func _foto(nome: String) -> void:
	ocupado = true
	var caminho := pasta.path_join("%s_%s.png" % [prefixo, nome])
	var tam: Vector2i = await mundo.ap.foto(caminho)
	print("FOTO ", caminho, " ", tam, " t=%.2f" % mundo.t)
	ocupado = false


func _combate() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	match passo:
		0:  # prepara: monstros em arco na frente do herói e ataque segurado
			c.limpar_partida()
			h.entrada_forcada = Vector2.ZERO
			h.fonte = h.Fonte.MOUSE
			var tipos := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_cao_ossos", "inimigo_espantalho", "inimigo_lobo_sombrio", "inimigo_cao_ossos"]
			var pos := [Vector2(34, -8), Vector2(40, 14), Vector2(58, -22), Vector2(62, 8), Vector2(52, 34), Vector2(30, -34)]
			for i in tipos.size():
				var m = mundo.nascer_monstro(tipos[i], h.pos + pos[i], true)
				m.vida = m.vida_max * 3.0
				m.vida_max = m.vida
			mundo.mouse_forcado = h.centro() + Vector2(100, -4)
			h.ataque_forcado = true
			passo = 1
			t_passo = 0.0
		1:  # o corte varrendo o arco, um instante antes do acerto
			if h.estado == h.Estado.GOLPE and h.golpe_i == 0 and h.golpe_t >= 0.055 and not h.golpe_acertou:
				_foto("01_corte")
				passo = 2
				t_passo = 0.0
			elif t_passo > 6.0:
				passo = 2
		2:  # o acerto: hit-stop com flash, faíscas e números
			if c.parada_t > 0.0 and c.acertos >= 1:
				_foto("02_impacto")
				passo = 3
				t_passo = 0.0
			elif t_passo > 6.0:
				passo = 3
		3:  # a estocada (3º passo do combo)
			if h.estado == h.Estado.GOLPE and h.golpe_i == 2 and h.golpe_t >= 0.12 and c.acertos > 0:
				_foto("03_estocada")
				passo = 4
				t_passo = 0.0
			elif t_passo > 8.0:
				passo = 4
		4:  # sobe de nível: câmera lenta e a escolha
			h.ataque_forcado = false
			h.xp = h.xp_proximo - 0.1
			c.progresso.ganhar_xp(0.2)
			passo = 5
			t_passo = 0.0
		5:
			if c.jogo == "escolha" and t_passo > 0.35 and not c.telas.roleta_ativa:  # espera os rolos da roleta pararem
				_foto("04_nivel")
				passo = 6
				t_passo = 0.0
			elif t_passo > 4.0:
				passo = 6
		6:  # escolhe a 1ª carta e morre
			if c.jogo == "escolha":
				c.progresso.escolher(0)
			h.imortal = false
			h.vida = 1.0
			mundo.abates = 41
			mundo.maior_combo = 17
			mundo.tempo_partida = 143.0
			h.nivel = 6
			var m = mundo.nascer_monstro("inimigo_lobo_sombrio", h.pos + Vector2(-40, 0), true)
			m.vida = m.vida_max
			passo = 7
			t_passo = 0.0
		7:
			if c.jogo == "morte" and t_passo > 0.9:
				_foto("05_resultado")
				passo = 8
			elif t_passo > 8.0:
				passo = 8
		8:
			mundo.get_tree().quit()
			return


func _correr() -> void:
	var h = mundo.heroi
	match passo:
		0:
			mundo.combate.limpar_partida()
			h.entrada_forcada = Vector2(1, 0.15).normalized()
			h.correr_forcado = true
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 0.9:
				_foto("06_correr")
				passo = 2
		2:
			mundo.get_tree().quit()
			return


## A abertura de uma partida real (herói parado, diretor ligado): fotos aos 1, 10 e 20 s com a distância do monstro mais perto.
func _r_inicio() -> void:
	var alvos := [1.0, 10.0, 20.0]
	if passo >= alvos.size():
		mundo.get_tree().quit()
		return
	if t_passo < float(alvos[passo]):
		return
	var perto := 99999.0
	var n_perto := 0
	for m in mundo.monstros:
		var d: float = m.pos.distance_to(mundo.heroi.pos)
		perto = minf(perto, d)
		if d < 300.0:
			n_perto += 1
	print(
		(
			"INICIO t=%.1f vivos=%d mais_perto=%.0f a_menos_de_300=%d nascidos=%d"
			% [t_passo, mundo.monstros.size(), perto, n_perto, mundo.combate.diretor.nascidos]
		)
	)
	_foto("inicio_%02d" % int(alvos[passo]))
	passo += 1


# ------------------------------------------------------------------ leva 3: build, elite, baú, chefe, vitória


## Uma build cheia sem evoluir: aura 4, lâminas 2, corvos 3, raio 2 e runa 2, em raridades variadas.
func armar_build() -> void:
	var cs = mundo.combate.cartas
	if str(args.get("build", "")) == "invocacoes":  # medição de picos: todas as invocações no nível 5 e as fusões do tipo aliado juntas
		for g in cs.cfg.golpes:
			if str(g.get("tipo", "")) == "aliado":
				mundo.combate.armas.definir_golpe(str(g.id), 5, 0.0)
		for ev in cs.cfg.evolucoes:
			if str(ev.get("tipo", "")) == "aliado":
				mundo.combate.armas.adicionar_evoluida(ev, 0.0)
		return
	if str(args.get("build", "")) in ["golpes", "tudo"]:  # medição das folhas animadas (docs/combate_v2): projéteis, anéis, meteoros e nuvens no nível 5
		var tipos := ["projetil", "anel", "meteoro", "nuvem"]
		if str(args.build) == "tudo":  # e também corvos, aura, raio, runa, lâminas e as evoluções desses tipos
			tipos += ["corvos", "aura", "raio", "runa", "orbita"]
			for ev in cs.cfg.evolucoes:
				if str(ev.get("tipo", "")) in tipos:
					mundo.combate.armas.adicionar_evoluida(ev, 0.0)
		for g in cs.cfg.golpes:
			if str(g.get("tipo", "")) in tipos:
				mundo.combate.armas.definir_golpe(str(g.id), 5, 0.0)
		return
	for par in [["aura_fogo", 4], ["laminas", 2], ["corvos", 3], ["raio", 2], ["runa", 2]]:
		for i in int(par[1]):
			cs.aplicar(cs.montar_carta(cs.definicao(str(par[0])), 1 + (i % 3)))


func _r_hud_golpes() -> void:
	var cs = mundo.combate.cartas
	match passo:
		0:
			_preparar()
			var n := 0
			for id in ["bola_fogo", "laminas", "corvos", "raio", "runa", "aura_fogo", "golem_barro", "lobo_espirito", "espirito_urso"]:
				for i in 1 + (n % 3):  # níveis 1 a 3, em raridades variadas
					cs.aplicar(cs.montar_carta(cs.definicao(id), 1 + (i % 3)))
				n += 1
			estresse = 18
			robo = true
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 5.0:  # a faixa já esmaeceu
				_foto("31_parado")
				passo = 2
				t_passo = 0.0
		2:
			if t_passo > 0.9:
				cs.aplicar(cs.montar_carta(cs.definicao("runa"), 1))
				passo = 3
				t_passo = 0.0
		3:
			if t_passo > 0.15:
				_foto("32_pulso")
				passo = 4
				t_passo = 0.0
		4:
			if t_passo > 1.0:
				cs.aplicar(cs.montar_carta(cs.definicao("nuvem_veneno"), 1))
				passo = 5
				t_passo = 0.0
		5:
			if t_passo > 0.12:
				_foto("33_novo")
				passo = 6
		6:
			mundo.get_tree().quit()


func _preparar(imortal := true) -> void:
	var c = mundo.combate
	c.limpar_partida()
	c.diretor.ligado = false
	mundo.heroi.imortal = imortal
	mundo.heroi.entrada_forcada = Vector2.ZERO
	mundo.heroi.fonte = mundo.heroi.Fonte.MOUSE
	mundo.heroi.xp_proximo = 1.0e9  # as fotos não podem abrir a escolha de nível por acidente


func _r_build() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			armar_build()
			estresse = 26
			robo = true
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 3.0:
				_foto("11_build")
				passo = 2
				t_passo = 0.0
		2:
			if t_passo > 0.9:
				_foto("12_build_b")
				passo = 3
		3:
			mundo.get_tree().quit()
			return


func _r_elite() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	match passo:
		0:
			_preparar()
			var e = c.elites.nascer("inimigo_cavaleiro_oco", "explosivo", h.pos + Vector2(120, -10))
			e.cacador = false
			e.raio_vaga = 0.0
			for k in 4:
				var m = mundo.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(90 + 22 * k, 24 - 10 * k), true)
				m.vida_max = 3000.0
				m.vida = 3000.0
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 0.9:
				_foto("13_elite")
				passo = 2
				t_passo = 0.0
		2:
			var e = c.elites.vivas[0] if not c.elites.vivas.is_empty() else null
			if e != null:
				c.ferir(e, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
				c.processar_mortes()
			passo = 3
			t_passo = 0.0
		3:
			if t_passo > 1.3:
				_foto("14_bau")
				passo = 4
				t_passo = 0.0
		4:
			for b in c.baus.lista:
				if b.ativo:
					h.definir_pos(b.pos)
			if c.jogo == "bau":
				passo = 5
				t_passo = 0.0
			elif t_passo > 3.0:
				passo = 7
		5:
			if t_passo > 0.7:
				_foto("15_roleta")
				passo = 6
				t_passo = 0.0
		6:
			if c.telas.bau_pronto and t_passo > 0.3:
				_foto("16_bau_revelado")
				passo = 7
			elif t_passo > 12.0:
				passo = 7
		7:
			mundo.get_tree().quit()
			return


func _r_chefe() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	var ch = c.chefes
	# três chefes, quatro passos cada: nasce e anuncia o ataque PRÓPRIO (a foto do aviso), o disparo (a foto logo depois) e a troca; no fim a fúria do chefão
	var nomes := [["17_minichefe_aviso", "17c_minichefe_leque"], ["17b_rainha_aviso", "17d_rainha_teia"], ["18_chefe_aviso", "18b_chefe_revoada"]]
	var k := passo / 4
	if passo >= 12:
		_r_chefe_furia()
		return
	match passo % 4:
		0:
			_preparar()
			ch.nascer(ch.cfg.marcas[k], h.pos + Vector2(110, 150))
			pt_disparos = c.avisos.disparados
			pt_fogo = -1.0
			passo += 1
			t_passo = 0.0
		1:
			if c.avisos.ativos() > 0 and c.avisos.t[0] > 0.6 and t_passo > 2.0:
				_foto(nomes[k][0])
				passo += 1
				t_passo = 0.0
			elif t_passo > 14.0:
				passo += 1
				t_passo = 0.0
		2:
			if pt_fogo < 0.0 and c.avisos.disparados > pt_disparos:
				pt_fogo = t_passo
			if pt_fogo >= 0.0 and t_passo - pt_fogo > 0.12:
				_foto(nomes[k][1])
				passo += 1
				t_passo = 0.0
			elif t_passo > 8.0:
				passo += 1
				t_passo = 0.0
		3:
			if k < 2 and ch.atual != null:  # matar o chefão seria a vitória: ele só some na troca de cena
				c.ferir(ch.atual, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
				c.processar_mortes()
			c.avisos.limpar()
			c.jogo = "jogando"
			c.baus.limpar()
			passo += 1
			t_passo = 0.0


## A fúria do chefão (menos de metade da vida): a coroa brilha e os corvos giram mais rápido.
func _r_chefe_furia() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	var ch = c.chefes
	match passo:
		12:
			_preparar()
			ch.nascer(ch.cfg.marcas[2], h.pos + Vector2(110, 150))
			ch.atual.vida = ch.atual.vida_max * 0.4
			passo = 13
			t_passo = 0.0
		13:
			if t_passo > 1.4:
				_foto("18c_chefe_furia")
				passo = 14
		14:
			mundo.get_tree().quit()
			return


func _r_golpes() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	var ch = c.chefes
	match passo:
		0:
			_preparar()
			var m = mundo.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(70, 10), true)
			m.vida = m.vida_max * 9.0
			m.vida_max = m.vida
			c.armas.explodir(h.pos + Vector2(70, 10), 5.0, 56.0, Color(0.3, 0.9, 1.0), null)
			passo = 1
			t_passo = 0.0
		1:
			if t_passo >= 0.08:
				_foto("1_cristal")
				passo = 2
				t_passo = 0.0
		2:
			var m2 = mundo.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(-60, 10), true)
			m2.vida = m2.vida_max * 9.0
			m2.vida_max = m2.vida
			c.fx.flash(m2, 0.45, Color.WHITE, 3)
			c.fx.folha("estrela", m2.pos + Vector2(0, -8), 15.0, Color(0.3, 0.9, 1.0), 0.3)
			passo = 3
			t_passo = 0.0
		3:
			if t_passo >= 0.05:
				_foto("2_marca")
				passo = 4
				t_passo = 0.0
		4:
			c.limpar_partida()
			ch.nascer(ch.cfg.marcas[2], h.pos + Vector2(220, -30))
			passo = 5
			t_passo = 0.0
		5:
			if ch.atual != null and ch.atual.carga >= 0.9:
				_foto("3_telegrafo")
				passo = 6
			elif t_passo > 14.0:
				passo = 6
		6:
			mundo.get_tree().quit()
			return


func _r_vitoria() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	match passo:
		0:
			_preparar()
			armar_build()
			mundo.abates = 412
			mundo.maior_combo = 87
			mundo.xp_coletado = 2860.0
			mundo.tempo_partida = 612.0
			h.nivel = 14
			c.chefes.nascer(c.chefes.cfg.marcas[2], h.pos + Vector2(160, -20))
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 1.2:
				c.ferir(c.chefes.atual, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
				c.processar_mortes()
				passo = 2
				t_passo = 0.0
		2:
			if c.jogo == "vitoria" and t_passo > 3.2:
				_foto("19_vitoria")
				passo = 3
			elif t_passo > 12.0:
				passo = 3
		3:
			mundo.get_tree().quit()
			return


func _r_escolha() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	match passo:
		0:
			_preparar()
			armar_build()
			h.nivel = 20
			# procura uma escolha com as três cartas de raridades diferentes, para a foto mostrar a escala de cores e os ícones
			var achada := 0
			for semente in 400:
				c.cartas.rng.seed = semente
				var cs: Array = c.cartas.sortear(3, 20)
				var raridades := {}
				for k in cs:
					raridades[int(k.rar)] = true
				if raridades.size() == 3:
					achada = semente
					break
			c.cartas.rng.seed = achada
			c.progresso.cartas = c.cartas.sortear(3, 20)
			c.jogo = "escolha"
			c.pausado = true
			c.telas.roleta_ligada = false  # a foto da trava quer as cartas paradas (a roleta do #376 tem as fotos dela)
			c.telas.mostrar_escolha(c.progresso.cartas, 20)
			passo = 1
			t_passo = 0.0
		1:  # a trava: cartas apagadas e a contagem ("Escolha em 2") na legenda, com a barra no meio
			if t_passo > 1.2:
				_foto("20_escolha_trava")
				passo = 2
				t_passo = 0.0
		2:  # logo depois de liberar (3 s de tempo real): as cartas acendem
			if c.telas.espera_escolha <= 0.0 and t_passo > 0.12:
				_foto("21_escolha_liberada")
				passo = 3
		3:  # o menu de pausa por cima da escolha (cortina escura; os cards SUA BUILD e da arma ao lado). A árvore pausa: espera por um timer que roda pausado
			passo = 4
			ocupado = true
			mundo.pausa.pausar()
			await mundo.get_tree().create_timer(0.5, true, false, true).timeout
			ocupado = false
			await _foto("22_escolha_pausa")
			mundo.get_tree().quit()  # pausada, a árvore não volta aqui no próximo quadro
		4:
			return


# ------------------------------------------------------------------ leva 4: oclusão (herói atrás de árvore e coberto por monstro)


## 1_arvore: o herói atrás de uma árvore do meio do mapa (a copa e o tronco o escondem). 2_aranha: o herói no ponto de
## nascimento, com uma aranha grande na frente cobrindo o corpo (a silhueta do herói aparece por cima).
## Vitrine (comparar antes e depois do mesmo quadro): os 5 tipos de monstro parados em 3 fileiras (de frente, de três quartos, espelhados, com
## quadros e tintas diferentes), um elite-escala e um com fogo, tudo congelado (atordoado) perto do herói. Foto "1_vitrine".
func _r_vitrine() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			mundo.mouse_forcado = h.centro() + Vector2(100, 0)  # o herói olha sempre para a direita (a foto não depende do mouse)
			var tipos: Array = mundo.TIPOS_MONSTRO
			for fila in 3:
				for i in tipos.size():
					var m = mundo.nascer_monstro(tipos[i], h.pos + Vector2(-110.0 + i * 55.0, 50.0 + fila * 38.0), true)
					m.atordoa_t = 9999.0
					m.quadro((i + fila) % 4, fila % 2, fila == 2, fila == 2)
					if fila == 1 and i == 1:
						m.definir_escala(1.6)
						m.tinta = Color(0.9, 0.7, 1.2)
					if fila == 2 and i == 3:
						m.queimar(1.0, 99.0)
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 1.0:
				_foto("1_vitrine")
				passo = 2
		2:
			mundo.get_tree().quit()
			return


## Ordem de desenho: uma aranha grande (escala 2) logo atrás do herói e outra logo na frente, paradas. A de trás fica por baixo dele e a
## da frente por cima (y-sort pelos pés). Foto "1_ordem".
func _r_ordem() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			mundo.mouse_forcado = h.centro() + Vector2(100, 0)  # o herói olha sempre para a direita (a foto não depende do mouse)
			for dy in [-26.0, 28.0]:
				var m = mundo.nascer_monstro("inimigo_aranha_tecela", h.pos + Vector2(6.0 * signf(dy), dy), false)
				m.definir_escala(2.0)
				m.atordoa_t = 9999.0
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 1.0:
				_foto("1_ordem")
				passo = 2
		2:
			mundo.get_tree().quit()
			return


## Cerco: 34 monstros e 2 aranhas grandes (escala 2 e 3) caçando o herói parado. Depois de 3 s: foto "1_cerco" (eles formam uma roda em volta
## dele, sem entrar no corpo, e nenhum fica por cima).
func _r_cerco() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			mundo.mouse_forcado = h.centro() + Vector2(100, 0)  # o herói olha sempre para a direita (a foto não depende do mouse)
			var tipos: Array = mundo.TIPOS_MONSTRO
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 34:
				var a := rng.randf() * TAU
				var r := rng.randf_range(70.0, 190.0)
				mundo.nascer_monstro(tipos[i % tipos.size()], h.pos + Vector2(cos(a) * r, sin(a) * r * 0.62), true)
			for k in [2.0, 3.0]:
				var m = mundo.nascer_monstro("inimigo_aranha_tecela", h.pos + Vector2(110.0 * (k - 2.5) * 2.0, 60.0), true)
				m.definir_escala(k)
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 3.0:
				_foto("1_cerco")
				passo = 2
		2:
			mundo.get_tree().quit()
			return


func _r_ruptura() -> void:
	var h = mundo.heroi
	match passo:
		0:  # a horda vem de várias distâncias (60 a 190 px) e o herói parado começa a carregar: na soltura uns estão dentro da elipse e outros fora
			_preparar()
			mundo.mouse_forcado = h.centro() + Vector2(100, 0)
			var tipos := [
				"inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_lobo_sombrio", "inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_espantalho"
			]
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			for i in 24:
				var a := TAU * float(i) / 24.0 + rng.randf_range(-0.12, 0.12)
				var r := rng.randf_range(60.0, 190.0)
				var m = mundo.nascer_monstro(tipos[i % tipos.size()], h.pos + Vector2(cos(a) * r, sin(a) * r * 0.62), true)
				m.vida = 99999.0
				m.vida_max = 99999.0
			passo = 1
			t_passo = 0.0
		1:  # aperta e segura a tecla E com a horda ainda a caminho
			if t_passo > 0.3:
				h.ruptura_forcada = true
				h.ruptura()
				passo = 2
				t_passo = 0.0
		2:
			if h.estado == h.Estado.CARGA and h.rup_carga >= 0.5:
				_foto("1_carga")
				passo = 3
				t_passo = 0.0
			elif t_passo > 4.0:
				passo = 3
		3:  # a janela perfeita: o anel pisca
			if h.rup_perfeita:
				_foto("2_cheia_perfeita")
				passo = 4
				t_passo = 0.0
			elif t_passo > 4.0:
				passo = 4
		4:  # solta
			h.ruptura_forcada = false
			passo = 5
			t_passo = 0.0
		5:
			if t_passo > 0.10:
				_foto("3_disparo")
				passo = 6
				t_passo = 0.0
		6:  # a katana fecha o combo dentro da janela do contragolpe
			h.ataque_forcado = true
			if t_passo > 0.6:
				_foto("4_depois")
				passo = 7
				t_passo = 0.0
		7:
			h.ataque_forcado = false
			if t_passo > 0.3:
				_foto("5_slot")
				passo = 8
		8:
			mundo.get_tree().quit()
			return


## O especial (tecla Q) do herói escolhido: 30 monstros em volta, 6 em fila à frente (a faixa da investida) e o herói imortal e parado. A foto do
## slot aceso sai aos 0,3 s e o especial dispara em seguida; a foto 2 sai no instante forte de cada herói (`foto` no bloco dele em dados/v2_especial.json)
## e a 3 logo depois do fim.
func _r_especial() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			mundo.mouse_forcado = h.centro() + Vector2(100, 0)
			var tipos := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_lobo_sombrio", "inimigo_espantalho"]
			var rng := RandomNumberGenerator.new()
			rng.seed = 23
			for i in 30:
				var a := TAU * float(i) / 30.0 + rng.randf_range(-0.1, 0.1)
				var r := rng.randf_range(70.0, 230.0)
				var m = mundo.nascer_monstro(tipos[i % tipos.size()], h.pos + Vector2(cos(a) * r, sin(a) * r * 0.62), true)
				m.vida = 99999.0
				m.vida_max = 99999.0
			for i in 6:
				var m = mundo.nascer_monstro(tipos[i % tipos.size()], h.pos + Vector2(70.0 + 35.0 * float(i), rng.randf_range(-6.0, 6.0)), true)
				m.vida = 99999.0
				m.vida_max = 99999.0
			h.esp_carga = 0.0
			passo = 10
			t_passo = 0.0
		10:  # o slot Q vazio (0%), depois no meio (55%) e por fim cheio e pulsando (a foto é assíncrona: a carga só muda no passo seguinte)
			if t_passo > 0.3:
				_foto("0_vazio")
				passo = 12
				t_passo = 0.0
		12:
			h.esp_carga = h.esp_carga_max * 0.55
			passo = 11
			t_passo = 0.0
		11:
			if t_passo > 0.3:
				_foto("0b_meio")
				passo = 13
				t_passo = 0.0
		13:
			h.esp_carga = h.esp_carga_max
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 0.3:
				_foto("1_pronto")
				passo = 2
				t_passo = 0.0
		2:
			h.especial()
			passo = 3
			t_passo = 0.0
		3:
			var b: Dictionary = mundo.combate.especial.bloco_de(str(h.chave))
			if h.estado == h.Estado.ESPECIAL and h.esp_t >= float(b.get("foto", 0.5)):
				_foto("2_especial")
				passo = 4
				t_passo = 0.0
			elif t_passo > 4.0:
				passo = 4
		4:
			if h.estado != h.Estado.ESPECIAL:
				passo = 5
				t_passo = 0.0
			elif t_passo > 4.0:
				passo = 5
		5:
			if t_passo > 0.25:
				_foto("3_slot")
				passo = 6
		6:
			mundo.get_tree().quit()


## A habilidade (tecla E) do herói escolhido: 30 monstros em volta (e uma fila à frente, para a investida do Nicão) e o herói imortal e parado, com a
## ultimate (Q) a 55% para o HUD mostrar os dois slots. Fotos 1_pronto (slot E pronto), 2_habilidade (o momento forte; no Hazaki, a ruptura recém solta) e
## 3_recarga (0,4 s depois de acabar: o slot E em recarga). O Hazaki segura a E (ruptura_forcada) por 1,1 s; os outros disparam no aperto.
func _r_habilidade() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			mundo.mouse_forcado = h.centro() + Vector2(100, 0)
			var tipos := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_lobo_sombrio", "inimigo_espantalho"]
			var rng := RandomNumberGenerator.new()
			rng.seed = 23
			for i in 30:
				var a := TAU * float(i) / 30.0 + rng.randf_range(-0.1, 0.1)
				var r := rng.randf_range(70.0, 230.0)
				var m = mundo.nascer_monstro(tipos[i % tipos.size()], h.pos + Vector2(cos(a) * r, sin(a) * r * 0.62), true)
				m.vida = 99999.0
				m.vida_max = 99999.0
			for i in 6:
				var m = mundo.nascer_monstro(tipos[i % tipos.size()], h.pos + Vector2(70.0 + 35.0 * float(i), rng.randf_range(-6.0, 6.0)), true)
				m.vida = 99999.0
				m.vida_max = 99999.0
			h.esp_carga = h.esp_carga_max * 0.55
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 0.3:
				_foto("1_pronto")
				passo = 2
				t_passo = 0.0
		2:
			if h.hab_id == "ruptura":
				h.ruptura_forcada = true
				h.ruptura()
			else:
				h.habilidade()
			passo = 3
			t_passo = 0.0
		3:
			var b: Dictionary = mundo.combate.habilidade.bloco_de(str(h.chave))
			if h.hab_id == "ruptura":
				if t_passo > 1.1:
					h.ruptura_forcada = false
					passo = 5
					t_passo = 0.0
			elif h.estado == h.Estado.HABILIDADE and h.hab_t >= float(b.get("foto", 0.2)):
				_foto("2_habilidade")
				passo = 4
				t_passo = 0.0
			elif t_passo > 4.0:
				passo = 4
		4:
			if h.estado != h.Estado.HABILIDADE:
				passo = 7
				t_passo = 0.0
			elif t_passo > 4.0:
				passo = 7
		5:  # o Hazaki: a ruptura saiu agora; a foto sai um instante depois, com a onda no ar
			if t_passo > 0.1:
				_foto("2_habilidade")
				passo = 7
				t_passo = 0.0
		7:
			if t_passo > 0.4:
				_foto("3_recarga")
				passo = 8
		8:
			mundo.get_tree().quit()


func _r_oclusao() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			var arvore = null
			for o in mundo.cenario.objetos:
				if o.chave == "arvore" and o.pos.x > 900.0 and o.pos.x < 2000.0 and o.pos.y > 500.0 and o.pos.y < 1100.0:
					arvore = o
					break
			if arvore != null:
				h.definir_pos(arvore.pos + Vector2(0, -40))
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 0.9:
				_foto("1_arvore")
				passo = 2
				t_passo = 0.0
		2:
			var c: Array = mundo.dados.get("nascimento", {}).get("heroi", [1440, 820])
			h.definir_pos(Vector2(float(c[0]), float(c[1])))
			var m = mundo.nascer_monstro("inimigo_aranha_tecela", h.pos + Vector2(0, 12), false)
			m.definir_escala(2.0)
			passo = 3
			t_passo = 0.0
		3:
			if t_passo > 0.9:
				_foto("2_aranha")
				passo = 4
		4:
			mundo.get_tree().quit()
			return


# ------------------------------------------------------------------ robô de playtest (#301)

const QUADROS_TRAVA_RELOGIO := 600  # 10 s de quadros sem o relógio da partida andar (jogando, sem pausa)
const QUADROS_TRAVA_TELA := 1200  # 20 s de quadros com a mesma tela aberta (cartas, baú, queda, vitória)
const SEG_MORTE_INICIO := 1.0  # --playtest_fim=morte: a partir de 1 s de jogo o robô fica parado, com 1 de vida, até um monstro matá-lo
const SEG_TRAVA_PRESO := 30.0  # 30 s de jogo com o herói no mesmo lugar (menos de 6 px) querendo andar


func _pt_iniciar() -> void:
	var semente := int(args.get("semente", 1))
	pt = {
		"semente": semente,
		"max": float(args.get("playtest_max", 900.0)),
		"trava_forcada": str(args.get("playtest_trava", "")),
		"fim": str(args.get("playtest_fim", "")),
		"q": args.has("playtest_q"),  # --playtest_q: o robô aperta o Q assim que a carga enche
		"q_vistos": 0,
		"q_prontos": [],
		"q_disparos": [],
		"e_disparos": 0,
		"rng": RandomNumberGenerator.new(),
		"quadros": 0,
		"us_ant": int(mundo._us_total),
		"proc_ms": PackedFloat32Array(),
		"quadro_ms": PackedFloat32Array(),
		"pico_vivos": 0,
		"cartas": [],
		"baus": 0,
		"elites": 0,
		"chefes": [],
		"evolucoes": [],
		"linha": [],
		"prox_linha": 60.0,
		"estado": "",
		"estado_q": 0,
		"relogio_ant": -1.0,
		"relogio_q": 0,
		"ponto": Vector2.ZERO,
		"ponto_t": 0.0,
		"preso_pos": mundo.heroi.pos,
		"preso_t": 0.0,
		"curto_pos": mundo.heroi.pos,
		"curto_q": 0,
		"desvio_t": 0.0,
		"alvo": Vector2.ZERO,
		"fuga": Vector2.ZERO,
		"esquiva_q": 0,
		"fim_q": 0,
		"t_real": Time.get_ticks_msec(),
	}
	pt.rng.seed = semente
	mundo.combate.cartas.rng.seed = semente * 7919 + 1
	mundo.heroi.imortal = false
	mundo.heroi.fonte = mundo.heroi.Fonte.MOUSE
	mundo.elite_apareceu.connect(func(_n): pt.elites += 1)
	mundo.chefe_apareceu.connect(func(n, _v): pt.chefes.append(n))
	mundo.evolucao.connect(func(n, _d): pt.evolucoes.append(n))
	_pt_novo_ponto()
	print("PLAYTEST inicio heroi=%s mapa=%s semente=%d" % [mundo.combate.heroi_id, mundo.id_mapa, semente])


func _playtest(dt: float) -> void:
	var c = mundo.combate
	var h = mundo.heroi
	pt.quadros += 1
	var us: int = int(mundo._us_total)
	pt.proc_ms.append((us - int(pt.us_ant)) / 1000.0)
	pt.us_ant = us
	pt.quadro_ms.append(dt * 1000.0)
	pt.pico_vivos = maxi(int(pt.pico_vivos), mundo.monstros.size())
	while int(pt.q_vistos) < int(c.especial.prontos):  # a carga do Q chegou a 100: anota o segundo de jogo
		pt.q_vistos = int(pt.q_vistos) + 1
		pt.q_prontos.append(snappedf(mundo.tempo_partida, 0.1))
	if mundo.tempo_partida >= float(pt.prox_linha):
		pt.prox_linha = float(pt.prox_linha) + 60.0
		pt.linha.append({"t": roundi(mundo.tempo_partida), "nivel": h.nivel, "vida": roundi(h.vida), "vivos": mundo.monstros.size(), "abates": mundo.abates})
		print("PLAYTEST t=%d nivel=%d vida=%d/%d vivos=%d abates=%d" % [mundo.tempo_partida, h.nivel, h.vida, h.vida_max, mundo.monstros.size(), mundo.abates])
	# quanto tempo a mesma tela está aberta
	if c.jogo != pt.estado:
		pt.estado = c.jogo
		pt.estado_q = 0
	pt.estado_q += 1
	match c.jogo:
		"jogando":
			if pt.fim == "morte" and mundo.tempo_partida >= SEG_MORTE_INICIO:
				_pt_parar_para_morrer()
			else:
				_pt_jogar(dt)
			_pt_vigiar_relogio()
			if mundo.tempo_partida >= float(pt.max):
				_pt_fim("tempo")
				return
		"escolha":
			h.entrada_forcada = Vector2.ZERO
			h.ataque_forcado = false
			if pt.trava_forcada == "cartas":
				c.telas.limite_t = 1.0e9  # a prova do vigia precisa da tela aberta: o limite de 8 s das cartas escolheria sozinho
			elif pt.estado_q >= 20 and not c.progresso.cartas.is_empty():
				_pt_escolher_carta()
		"bau":
			h.entrada_forcada = Vector2.ZERO
			h.ataque_forcado = false
			if pt.estado_q == 1:
				pt.baus += 1
			if pt.trava_forcada != "bau" and pt.estado_q >= 20 and c.telas.bau_pronto:
				c.baus.fechar()
		"morte", "vitoria", "abandono":
			pt.fim_q += 1
			if pt.fim_q > 30:  # deixa o resultado_meta gravar a partida (no save temporário)
				_pt_fim(c.jogo)
			return
	if int(pt.estado_q) > QUADROS_TRAVA_TELA and c.jogo != "jogando":
		_pt_trava("tela_%s" % c.jogo)


## Anda, foge, golpeia e esquiva. Não precisa jogar bem: precisa jogar a partida inteira sem ficar parado.
func _pt_jogar(dt: float) -> void:
	var h = mundo.heroi
	var c = mundo.combate
	var perto = null
	var perto_d := 1e12
	var fuga := Vector2.ZERO
	var colados := 0
	var chefe_colado := false
	for m in mundo.monstros:
		var dv: Vector2 = h.pos - m.pos
		var d2 := dv.length_squared()
		if d2 < perto_d:
			perto_d = d2
			perto = m
		if d2 < 150.0 * 150.0:
			var d := maxf(sqrt(d2), 8.0)
			fuga += dv / d * (150.0 - d) / 150.0
			if d < 46.0:
				colados += 1
		if m.chefe and d2 < 260.0 * 260.0:  # chefe e mini-chefe: o contato tira 20+ a cada 0,9 s, então sai da frente mais cedo e mais forte
			var dc := maxf(sqrt(d2), 8.0)
			fuga += dv / dc * (260.0 - dc) / 260.0 * 2.0
			if dc < 70.0:
				chefe_colado = true
	# ataque anunciado do chefe (círculo ou faixa piscando no chão): sai de dentro dele
	var av = c.avisos
	for i in av.tipo.size():
		if av.tipo[i] == 1:
			var rel: Vector2 = h.pos - av.pos[i]
			var g := Vector2(rel.x, rel.y / 0.62)
			if g.length() < float(av.tam[i]) + 40.0:
				fuga += (rel.normalized() if rel.length() > 1.0 else Vector2.RIGHT) * 3.0
				chefe_colado = true
		elif av.tipo[i] == 2 and av.na_faixa(i, h.pos, 30.0):
			var gd: Vector2 = av.dir[i]
			var lado := Vector2(-gd.y, gd.x)
			var rel2: Vector2 = h.pos - av.pos[i]
			fuga += (lado if rel2.dot(lado) >= 0.0 else -lado) * 3.0
			chefe_colado = true
		elif av.tipo[i] == 3 and av.na_setor(i, h.pos, 30.0):  # o leque: foge para longe de quem bate (e do lado do setor)
			var rel3: Vector2 = h.pos - av.pos[i]
			var lado3 := Vector2(-av.dir[i].y, av.dir[i].x)
			fuga += (rel3.normalized() if rel3.length() > 1.0 else Vector2.RIGHT) * 2.0 + (lado3 if rel3.dot(lado3) >= 0.0 else -lado3) * 2.0
			chefe_colado = true
	# para onde ir: baú no chão, senão orbe perto, senão um ponto do mapa que muda de tempos em tempos.
	# Em desvio (acabou de ficar preso), só o ponto: sem rota, o baú do outro lado de uma árvore prende o herói nela.
	var alvo: Vector2 = pt.ponto
	var achou := false
	var melhor := 700.0 * 700.0
	pt.desvio_t = maxf(float(pt.desvio_t) - dt, 0.0)
	var em_desvio: bool = pt.desvio_t > 0.0
	for b in c.baus.lista:
		if not em_desvio and b.ativo and b.pos.distance_squared_to(h.pos) < melhor:
			melhor = b.pos.distance_squared_to(h.pos)
			alvo = b.pos
			achou = true
	if not achou and not em_desvio:
		var o = c.orbes
		melhor = 320.0 * 320.0
		for i in o.estado.size():
			if o.estado[i] == 1 and o.pos[i].distance_squared_to(h.pos) < melhor:
				melhor = o.pos[i].distance_squared_to(h.pos)
				alvo = o.pos[i]
	pt.ponto_t = float(pt.ponto_t) + dt
	if pt.ponto_t > 14.0 or h.pos.distance_squared_to(pt.ponto) < 40.0 * 40.0:
		_pt_novo_ponto()
	var hp: Vector2 = h.pos
	var ir: Vector2 = (alvo - hp).normalized() if alvo.distance_squared_to(h.pos) > 16.0 else Vector2.ZERO
	# perto da borda do mapa (50 px): tira da fuga só o que empurra para a parede; o alvo (baú ou orbe dentro da faixa) continua valendo.
	# Sem sobra (canto), vai para o alvo ou para o centro, nunca para dentro da parede.
	var lim: Rect2 = mundo.limite_andavel
	var fg: Vector2 = fuga
	if (hp.x < lim.position.x + 50.0 and fg.x < 0.0) or (hp.x > lim.end.x - 50.0 and fg.x > 0.0):
		fg.x = 0.0
	if (hp.y < lim.position.y + 50.0 and fg.y < 0.0) or (hp.y > lim.end.y - 50.0 and fg.y > 0.0):
		fg.y = 0.0
	var dir: Vector2 = ir * 0.7 + fg * 1.4
	if dir.length() < 0.15:
		dir = ir if ir != Vector2.ZERO else (lim.get_center() - hp).normalized()
	h.entrada_forcada = dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	pt.alvo = alvo  # só para a mensagem de TRAVA
	pt.fuga = fuga
	# preso em parede ou árvore por 1,5 s: outro ponto, e 3 s sem perseguir baú nem orbe para dar a volta
	pt.curto_q += 1
	if pt.curto_q >= 90:
		if h.pos.distance_squared_to(pt.curto_pos) < 4.0:
			_pt_novo_ponto()
			pt.desvio_t = 3.0
		pt.curto_pos = h.pos
		pt.curto_q = 0
	# mira e golpe no mais perto
	if perto != null:
		mundo.mouse_forcado = perto.pos + Vector2(0, -6)
	else:
		mundo.mouse_forcado = h.centro() + h.entrada_forcada * 60.0
	h.fonte = h.Fonte.MOUSE
	h.ataque_forcado = perto != null and perto_d < 78.0 * 78.0
	if pt.q and perto != null and perto_d < 150.0 * 150.0 and h.esp_carga >= h.esp_carga_max and h.especial():
		pt.q_disparos.append(snappedf(mundo.tempo_partida, 0.1))
	if pt.q and perto != null and perto_d < 130.0 * 130.0 and h.hab_id != "ruptura" and h.hab_recarga <= 0.0 and h.habilidade():
		pt.e_disparos = int(pt.e_disparos) + 1  # a E dos heróis que não têm a ruptura (investida, salto)
	pt.esquiva_q += 1
	if (colados >= 5 or (chefe_colado and h.invenc <= 0.0)) and pt.esquiva_q > 60:
		h.esquivar()
		pt.esquiva_q = 0
	# vigia: herói no mesmo lugar por muito tempo
	pt.preso_t = float(pt.preso_t) + dt
	if pt.preso_t >= SEG_TRAVA_PRESO:
		if h.pos.distance_to(pt.preso_pos) < 6.0:
			_pt_trava("heroi_preso pos=%s alvo=%s bau=%s fuga=%s" % [str(h.pos.round()), str(pt.alvo.round()), str(achou), str(pt.fuga.round())])
		pt.preso_pos = h.pos
		pt.preso_t = 0.0


## --playtest_fim=morte: parado, sem golpe nem esquiva e com 1 de vida; quem mata é o dano normal dos monstros, então a morte segue o
## caminho real (combate.jogo = "morte" -> resultado_meta -> Meta.registrar_partida, que grava o save temporário).
func _pt_parar_para_morrer() -> void:
	var h = mundo.heroi
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.vida = minf(h.vida, 1.0)


func _pt_novo_ponto() -> void:
	var r: Rect2 = mundo.limite_andavel.grow(-80.0)
	pt.ponto = Vector2(pt.rng.randf_range(r.position.x, r.end.x), pt.rng.randf_range(r.position.y, r.end.y))
	pt.ponto_t = 0.0


## Maior raridade; no empate, a primeira.
func _pt_escolher_carta() -> void:
	var cs: Array = mundo.combate.progresso.cartas
	var i := 0
	for k in cs.size():
		if int(cs[k].get("rar", 0)) > int(cs[i].get("rar", 0)):
			i = k
	pt.cartas.append(str(cs[i].get("id", "?")))
	mundo.combate.progresso.escolher(i)


func _pt_vigiar_relogio() -> void:
	var c = mundo.combate
	if c.pausado or c.parada_t > 0.0 or c.lento_t > 0.0:
		pt.relogio_q = 0
		return
	if mundo.tempo_partida == float(pt.relogio_ant):
		pt.relogio_q += 1
		if pt.relogio_q > QUADROS_TRAVA_RELOGIO:
			_pt_trava("relogio_parado")
	else:
		pt.relogio_q = 0
	pt.relogio_ant = mundo.tempo_partida


func _pt_trava(onde: String) -> void:
	print("TRAVA: %s jogo=%s t=%.1f" % [onde, mundo.combate.jogo, mundo.tempo_partida])
	_pt_fim("trava", onde)


func _pt_fim(desfecho: String, trava := "") -> void:
	if not playtest:
		return
	playtest = false
	var c = mundo.combate
	var h = mundo.heroi
	var r := {
		"desfecho": desfecho,
		"trava": trava,
		"heroi": c.heroi_id,
		"mapa": mundo.id_mapa,
		"semente": pt.semente,
		"tempo_jogo": snappedf(mundo.tempo_partida, 0.1),
		"nivel": h.nivel,
		"abates": mundo.abates,
		"maior_combo": mundo.maior_combo,
		"vida_final": roundi(h.vida),
		"vida_max": roundi(h.vida_max),
		"dano_causado": roundi(c.dano_causado),
		"dano_sofrido": roundi(c.dano_sofrido),
		"golpes_tomados": c.golpes_tomados,
		"almas": mundo.almas_partida,
		"cartas": pt.cartas,
		"build": c.progresso.melhorias,
		"evolucoes": pt.evolucoes,
		"baus": pt.baus,
		"elites": pt.elites,
		"chefes": pt.chefes,
		"pico_vivos": pt.pico_vivos,
		"q_prontos": pt.q_prontos,
		"q_disparos": pt.q_disparos,
		"e_disparos": pt.e_disparos,
		"q_carga":
		{
			"dano": snappedf(float(c.especial.carga_total.dano), 0.1),
			"abate": snappedf(float(c.especial.carga_total.abate), 0.1),
			"recebido": snappedf(float(c.especial.carga_total.recebido), 0.1)
		},
		"quadros": pt.quadros,
		"proc_ms": _pt_pcts(pt.proc_ms),
		"quadro_ms": _pt_pcts(pt.quadro_ms),
		"tempo_real_s": snappedf((Time.get_ticks_msec() - int(pt.t_real)) / 1000.0, 0.1),
		"linha_tempo": pt.linha,
		"args": " ".join(OS.get_cmdline_user_args()),
	}
	print("PLAYTEST_JSON: ", JSON.stringify(r))
	_pt_apagar_save()
	mundo.get_tree().quit(3 if desfecho == "trava" else 0)


static func _pt_pcts(a: PackedFloat32Array) -> Dictionary:
	if a.is_empty():
		return {}
	var s := a.duplicate()
	s.sort()
	var n := s.size()
	var soma := 0.0
	for v in s:
		soma += v
	return {
		"media": snappedf(soma / n, 0.01),
		"p50": snappedf(s[n / 2], 0.01),
		"p95": snappedf(s[mini(n - 1, n * 95 / 100)], 0.01),
		"p99": snappedf(s[mini(n - 1, n * 99 / 100)], 0.01),
		"max": snappedf(s[n - 1], 0.01),
	}


## O save temporário do robô (mundo.gd apontou Meta.caminho_save para ele) sai junto com a partida.
func _pt_apagar_save() -> void:
	var base: String = mundo.Meta.caminho_save
	if not base.begins_with("user://playtest/"):
		return
	for p in [base, base + ".tmp", base + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Close de uma invocação para o GIF: só a invocação de --so=ID (no nível 5), o herói parado e as fotos 02 a 17, a cada 0,1 s.
## Uso: --roteiro=close --so=espirito_raposa --fotos=PASTA
func _r_close() -> void:
	match passo:
		0:
			_preparar()
			var so := str(args.get("so", ""))
			for g in mundo.combate.cartas.cfg.golpes:
				if str(g.get("id", "")) == so:
					mundo.combate.armas.definir_golpe(so, 5, 0.0)
			var alvo = mundo.nascer_monstro("inimigo_cao_ossos", mundo.heroi.pos + Vector2(150, 0), true)  # um alvo parado para o aliado atacar
			alvo.vida = alvo.vida_max * 50.0
			alvo.vida_max = alvo.vida
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 1.2:  # tempo para o aliado nascer e entrar na cena
				passo = 2
				t_passo = 0.0
		_:
			if passo > 17:
				mundo.get_tree().quit()
				return
			if t_passo >= 0.1:
				_foto("%02d" % passo)
				passo += 1
				t_passo = 0.0
