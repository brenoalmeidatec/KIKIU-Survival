extends Node
# Teste automático do combate e do laço de jogo da v2 (leva 2): golpe no clique (só sai com clique, na direção do cursor), combo de 3 que
# encadeia e repete segurando, dano/atordoamento/empurrão/hit-stop/número/flash, morte com orbe, orbe voando para o herói e dando XP, nível
# com escolha de melhoria (e o mundo parado enquanto escolhe), contato que tira vida com invencibilidade, esquiva com i-frames, correr
# (gasta fôlego, cansa, trava corrida e esquiva até 30%, recuperação com atraso), o diretor de ondas por 60 s simulados, a morte com a
# tela de resultado e o "jogar de novo", e que acertar e matar não cria nó. O mundo anda em passos fixos de 1/60 s.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_combate.tscn  (imprime "v2_combate falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Colisao := preload("res://v2/colisao.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var _niveis := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Anda até `cond` ficar verdadeira (no máximo `max_passos`). Devolve quantos passos deu, ou -1 se não chegou.
func ate(cond: Callable, max_passos: int) -> int:
	for i in max_passos:
		if cond.call():
			return i
		w.avancar(PASSO)
	return -1 if not cond.call() else max_passos


## Começa de novo: mapa sem monstros, herói imortal e parado no meio, sem diretor, sem mouse nem tecla.
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
	passos(3)


func monstro_a(dx: float, dy := 0.0, nome := "inimigo_cao_ossos"):
	var m = w.nascer_monstro(nome, w.heroi.pos + Vector2(dx, dy))
	m.atordoa_t = 0.0
	return m


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.nivel_subiu.connect(func(_n): _niveis += 1)
	var c: Dictionary = w.combate.cfg

	# 0. dados e API pública
	ok(str(c.get("_ajuda", "")) != "", "v2_combate.json tem _ajuda")
	ok(c.golpe.passos.size() == 3 and c.golpe.passos[2].nome == "estocada", "combo de 3: corte, corte, estocada")
	for chave in ["vida", "vida_max", "xp", "xp_proximo", "nivel", "folego", "folego_max", "cansado"]:
		ok(w.heroi.get(chave) != null, "API do herói: %s" % chave)
	for chave in ["abates", "combo", "tempo_partida", "monstros_vivos"]:
		ok(w.get(chave) != null, "API do mundo: %s" % chave)
	ok(w.has_signal("nivel_subiu"), "sinal nivel_subiu(nivel)")
	ok(w.monstros_vivos == w.monstros.size() and w.monstros.size() == 20, "monstros_vivos = 20 no começo")

	# 1. sem clique não sai golpe
	zerar()
	var m1 = monstro_a(30)
	w.heroi.entrada_forcada = null  # teclado e mouse de verdade (a máquina de teste não tem entrada)
	w.heroi.fonte = Heroi.Fonte.MOUSE
	passos(120)
	ok(w.heroi.golpes == 0 and w.heroi.estado == Heroi.Estado.LIVRE, "sem clique não sai golpe (golpes=%d)" % w.heroi.golpes)
	ok(w.combate.fx.usados.cortes == 0 and m1.vida == m1.vida_max, "sem clique: nenhum corte e o monstro intacto")

	# 2. com clique (evento de mouse de verdade) sai golpe, na direção do cursor
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	passos(2)
	ok(w.heroi.golpes >= 1 and w.heroi.estado == Heroi.Estado.GOLPE, "com clique sai golpe (golpes=%d)" % w.heroi.golpes)
	ok(w.heroi.golpe_dir.dot(Vector2(1, 0)) > 0.99, "golpe para a direita, na direção do cursor (%s)" % str(w.heroi.golpe_dir))
	ok(w.combate.fx.usados.cortes >= 1, "o golpe desenha o rastro do corte")
	ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().process_frame
	ate(func(): return w.heroi.estado == Heroi.Estado.LIVRE, 60)
	w.heroi.entrada_forcada = Vector2.ZERO
	passos(40)  # a janela do combo passa
	w.mouse_forcado = w.heroi.centro() + Vector2(-70, -70)  # cima e à esquerda
	w.heroi.atacar()
	passos(2)
	var esperado := Vector2(-1, -1).normalized()
	ok(w.heroi.golpe_dir.dot(esperado) > 0.98, "outro clique, outra direção: cima-esquerda (%s)" % str(w.heroi.golpe_dir))
	ok(w.heroi.linha == Heroi.linha_de(esperado), "o herói se vira para o cursor ao golpear")

	# 3. combo de 3 que encadeia; passou a janela, volta ao primeiro; segurando repete
	zerar()
	w.heroi.atacar()
	passos(2)
	ok(w.heroi.estado == Heroi.Estado.GOLPE and w.heroi.golpe_i == 0, "1º clique: corte (passo %d)" % w.heroi.golpe_i)
	ate(func(): return w.heroi.estado == Heroi.Estado.LIVRE, 60)
	ok(w.heroi.combo_t > 0.0 and w.heroi.proximo == 1, "terminou o corte: janela aberta para o 2º passo")
	passos(6)
	w.heroi.atacar()
	passos(2)
	ok(w.heroi.estado == Heroi.Estado.GOLPE and w.heroi.golpe_i == 1, "2º clique na janela: 2º corte (passo %d)" % w.heroi.golpe_i)
	ate(func(): return w.heroi.estado == Heroi.Estado.LIVRE, 60)
	passos(6)
	w.heroi.atacar()
	passos(2)
	ok(w.heroi.golpe_i == 2 and w.heroi.golpe_cfg.nome == "estocada", "3º clique: estocada (passo %d)" % w.heroi.golpe_i)
	ate(func(): return w.heroi.estado == Heroi.Estado.LIVRE, 60)
	ok(w.heroi.proximo == 0 and w.heroi.pausa_t > 0.0, "depois da estocada o combo fecha, com uma folga")
	passos(60)
	w.heroi.atacar()
	passos(2)
	ok(w.heroi.golpe_i == 0, "passada a janela o combo volta ao primeiro corte")
	ate(func(): return w.heroi.estado == Heroi.Estado.LIVRE, 60)
	passos(60)
	w.heroi.combo_t = 0.0
	w.heroi.proximo = 0
	var vistos := {}
	var antes_golpes: int = w.heroi.golpes
	w.heroi.ataque_forcado = true  # botão segurado
	for i in 240:
		w.avancar(PASSO)
		if w.heroi.estado == Heroi.Estado.GOLPE:
			vistos[w.heroi.golpe_i] = true
	w.heroi.ataque_forcado = null
	ok(w.heroi.golpes - antes_golpes >= 6, "segurar o botão repete o combo (%d golpes em 4 s)" % (w.heroi.golpes - antes_golpes))
	ok(vistos.has(0) and vistos.has(1) and vistos.has(2), "segurando passa pelos 3 passos")

	# 4. o monstro perde vida, é atordoado, empurrado, e o impacto tem peso (hit-stop, flash, número, faíscas)
	zerar()
	var m = monstro_a(34)
	m.vida = m.vida_max
	var x0: float = m.pos.x
	var num0: int = w.combate.fx.usados.numeros
	var fl0: int = w.combate.fx.usados.flashes
	w.combate.cfg.golpe.critico.chance = 0.0
	w.heroi.atacar()
	var t_antes: float = w.tempo_partida
	ate(func(): return m.acertos > 0, 40)
	ok(m.acertos == 1 and m.vida < m.vida_max, "o corte tira vida do monstro (%.1f de %.1f)" % [m.vida, m.vida_max])
	ok(m.atordoa_t > 0.1, "o monstro fica atordoado (%.2f s)" % m.atordoa_t)
	ok(m.emp.x > 50.0, "o monstro leva empurrão para longe do herói (%.0f px/s)" % m.emp.x)
	ok(w.combate.parada_t >= 0.04 and w.combate.parada_t <= 0.075, "hit-stop de 40 a 70 ms (%.3f s)" % w.combate.parada_t)
	ok(w.combate.fx.usados.numeros > num0, "aparece o número de dano")
	ok(w.combate.fx.usados.flashes > fl0, "o monstro pisca em branco")
	ok(w.combate.fx.p_ativas > 0, "saem faíscas do acerto")
	var tp: float = w.tempo_partida
	passos(2)
	ok(w.tempo_partida == tp, "durante o hit-stop o mundo para (tempo_partida %.3f)" % w.tempo_partida)
	ate(func(): return w.combate.parada_t <= 0.0, 20)
	passos(12)
	ok(m.pos.x > x0 + 2.0, "o empurrão leva o monstro para trás (de %.1f a %.1f)" % [x0, m.pos.x])
	ok(w.tempo_partida > t_antes, "o mundo volta a andar depois do hit-stop")
	ok(w.cam.position == w.cam.position.round(), "a câmera segue em pixel inteiro")
	# crítico: tremor de câmera e número grande
	w.combate.cfg.golpe.critico.chance = 1.0
	m.vida = 100.0
	m.atordoa_t = 0.0
	ate(func(): return w.heroi.estado == Heroi.Estado.LIVRE, 60)
	passos(70)
	m.pos = w.heroi.pos + Vector2(30, 0)
	m.definir_pos(m.pos)
	var cr0: int = w.combate.criticos
	w.heroi.atacar()
	var tremeu := false
	var inteira := true
	for i in 40:
		w.avancar(PASSO)
		tremeu = tremeu or w.cam.tremor_t > 0.0
		inteira = inteira and w.cam.position == w.cam.position.round() and absf(w.cam.deslocamento.x) <= 3.0
	ok(w.combate.criticos > cr0, "o crítico saiu")
	ok(tremeu and inteira, "crítico: a câmera treme, sempre em pixel inteiro")
	ok(w.combate.fx.n_tam.has(24), "o número do crítico é maior (24 px; o normal tem 16)")
	w.combate.cfg.golpe.critico.chance = 0.1
	# a estocada tem peso: hit-stop de 70 ms e tremor
	zerar()
	w.combate.cfg.golpe.critico.chance = 0.0
	m = monstro_a(40)
	m.vida = 500.0
	w.heroi.proximo = 2
	w.heroi.combo_t = 1.0
	w.heroi.atacar()
	ate(func(): return m.acertos > 0, 40)
	ok(w.combate.parada_t > 0.06 and w.cam.tremor_t > 0.0, "a estocada acerta com hit-stop de ~70 ms e tremor (%.3f)" % w.combate.parada_t)
	w.combate.cfg.golpe.critico.chance = 0.1

	# 5. morte: estouro, orbe de alma e o combo de abates
	zerar()
	m = monstro_a(30)
	m.vida = 1.0
	var vivos0: int = w.monstros.size()
	w.heroi.atacar()
	ate(func(): return not m.vivo, 40)
	ok(not m.vivo and w.monstros.size() == vivos0 - 1, "o monstro morre e sai da lista dos vivos")
	ok(w.abates == 1 and w.combo == 1, "abates=%d combo=%d" % [w.abates, w.combo])
	ok(w.combate.orbes.ativos >= 1, "a morte solta um fragmento de alma (orbe: %d)" % w.combate.orbes.ativos)
	ok(w.combate.fx.p_ativas > 8, "estouro de partículas na morte (%d)" % w.combate.fx.p_ativas)
	ok(not m.raiz.visible, "o corpo some")
	w.combate.combo_t = 0.01
	ate(func(): return w.combo == 0, 30)
	ok(w.combo == 0 and w.maior_combo == 1, "sem matar por um tempo, o combo zera (maior=%d)" % w.maior_combo)

	# 6. o orbe voa para o herói e vira XP; vários seguidos fazem o "plim" subir
	zerar()
	var h = w.heroi
	var xp0: float = h.xp
	w.combate.orbes.soltar(h.pos + Vector2(40, 0), 2.0)
	passos(3)
	ok(w.combate.orbes.estado.count(2) >= 1, "o herói chegou perto: o orbe é atraído")
	var a_longe: int = w.combate.orbes.ativos
	ate(func(): return w.combate.orbes.ativos < a_longe, 120)
	ok(h.xp > xp0 + 1.5, "pegar o orbe dá XP (%.1f)" % h.xp)
	var longe_pos: Vector2 = h.pos + Vector2(300, 0)
	w.combate.orbes.soltar(longe_pos, 1.0)
	passos(30)
	ok(w.combate.orbes.estado[w.combate.orbes.estado.find(1)] == 1, "orbe longe fica parado no chão")
	w.combate.orbes.limpar()
	for i in 6:
		w.combate.orbes.soltar(h.pos + Vector2(20 + i * 6, 0), 0.1)
	ate(func(): return w.combate.orbes.ativos == 0, 200)
	ok(w.combate._plim_n >= 4, "orbes seguidos: o plim sobe (sequência %d)" % w.combate._plim_n)

	# 7. nível: câmera lenta de 0,4 s, escolha de 1 entre 3 melhorias (o mundo para), melhoria aplicada
	zerar()
	h = w.heroi
	_niveis = 0
	var nv0: int = h.nivel
	h.xp = h.xp_proximo - 0.5
	w.combate.orbes.soltar(h.pos + Vector2(20, 0), 2.0)
	ate(func(): return h.nivel > nv0, 120)
	ok(h.nivel == nv0 + 1 and _niveis == 1, "o XP enche a barra e sobe o nível (sinal nivel_subiu: %d)" % _niveis)
	ok(w.combate.lento_t > 0.0 and w.combate.lento_escala < 0.5, "câmera lenta ao subir de nível")
	var passos_lento := ate(func(): return w.combate.jogo == "escolha", 120)
	ok(passos_lento >= 20 and passos_lento <= 30, "a câmera lenta dura ~0,4 s antes da escolha (%d passos)" % passos_lento)
	ok(w.combate.pausado and w.combate.progresso.cartas.size() == 3, "abre a escolha com 3 cartas")
	var ids := {}
	for cc in w.combate.progresso.cartas:
		ids[cc.id] = true
	ok(ids.size() == 3, "as 3 cartas são diferentes")
	ok(w.combate.telas.escolha_aberta, "a tela de escolha aparece")
	var tp7: float = w.tempo_partida
	passos(40)
	ok(w.tempo_partida == tp7, "com a escolha aberta o mundo está parado")
	passos(150)  # a trava de 3 s (tempo real) passa antes de a tecla valer (v2_cartas_espera.tscn testa a trava)
	var snap_antes := [h.m_dano, h.m_vel_ataque, h.m_area, h.m_vel_mov, h.vida_max, h.m_ima, h.m_critico]
	var carta: Dictionary = w.combate.progresso.cartas[1]
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_2
	tecla.pressed = true
	w._input(tecla)  # escolher a 2ª carta com a tecla 2
	var snap_depois := [h.m_dano, h.m_vel_ataque, h.m_area, h.m_vel_mov, h.vida_max, h.m_ima, h.m_critico]
	ok(snap_depois != snap_antes or carta.cat != "stat", "a carta %s mudou o herói" % carta.id)
	ok(not w.combate.pausado and w.combate.progresso.melhorias.get(carta.id, 0) == 1, "a escolha fecha e o jogo segue")
	passos(10)
	ok(w.tempo_partida > tp7, "o mundo volta a andar depois da escolha")
	# todas as 7 melhorias de stat aplicam um efeito
	var base_h := [h.m_dano, h.m_vel_ataque, h.m_area, h.m_vel_mov, h.vida_max, h.m_ima, h.m_critico]
	var stats: Array = w.combate.cartas.cfg.stats
	for cc in stats:
		var antes_v := [h.m_dano, h.m_vel_ataque, h.m_area, h.m_vel_mov, h.vida_max, h.m_ima, h.m_critico]
		w.combate.progresso.aplicar(cc)
		var depois_v := [h.m_dano, h.m_vel_ataque, h.m_area, h.m_vel_mov, h.vida_max, h.m_ima, h.m_critico]
		ok(antes_v != depois_v, "melhoria %s tem efeito" % cc.id)
	ok(stats.size() == 7, "7 melhorias de stat nos dados")
	ok(base_h != [h.m_dano, h.m_vel_ataque, h.m_area, h.m_vel_mov, h.vida_max, h.m_ima, h.m_critico], "melhorias acumulam")

	# 8. o contato tira vida, com recarga e invencibilidade; o pisca; a esquiva dá i-frames
	zerar()
	h = w.heroi
	h.imortal = false
	h.vida = h.vida_max
	m = monstro_a(14)
	m.cacador = true
	ate(func(): return h.vida < h.vida_max, 60)
	ok(h.vida < h.vida_max, "monstro encostado tira vida do herói (%.0f)" % h.vida)
	ok(h.invenc > 0.5, "ao apanhar o herói fica invencível um instante (%.2f s)" % h.invenc)
	var v1: float = h.vida
	passos(20)
	ok(h.vida == v1, "na invencibilidade não apanha de novo")
	ok(h.emp.length() > 0.0 or h.vel.length() >= 0.0, "o golpe empurra o herói")
	ate(func(): return h.vida < v1, 200)
	ok(h.vida < v1, "passada a invencibilidade e a recarga, o contato volta a ferir")
	# esquiva
	zerar()
	h = w.heroi
	h.imortal = false
	h.vida = h.vida_max
	var fo0: float = h.folego
	h.entrada_forcada = Vector2(1, 0)
	var px0: float = h.pos.x
	h.esquivar()
	passos(2)
	ok(h.estado == Heroi.Estado.ESQUIVA, "Espaço: o herói rola")
	ok(h.folego < fo0, "a esquiva gasta fôlego (%.2f de %.2f)" % [h.folego, fo0])
	ok(not h.vulneravel(), "no começo do rolamento o herói é invulnerável")
	ok(not h.levar_dano(10.0, h.pos + Vector2(10, 0)) and h.vida == h.vida_max, "i-frames: o dano não entra")
	ate(func(): return h.esq_t > h.esq_inv + 0.02, 60)
	ok(h.estado == Heroi.Estado.ESQUIVA and h.vulneravel(), "no fim do rolamento já dá para apanhar (compromisso)")
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 60)
	ok(h.pos.x - px0 > 80.0, "o rolamento leva o herói longe (%.0f px)" % (h.pos.x - px0))
	h.entrada_forcada = Vector2.ZERO
	# esquiva também corta o fim do golpe
	passos(60)
	h.atacar()
	ate(func(): return h.golpe_acertou, 40)
	h.esquivar()
	passos(2)
	ok(h.estado == Heroi.Estado.ESQUIVA, "a esquiva cancela o fim do golpe")

	# 9. correr: gasta fôlego, zerar cansa e trava corrida e esquiva até 30%, recuperação com atraso
	zerar()
	h = w.heroi
	h.imortal = true
	var p0: float = h.pos.x
	h.entrada_forcada = Vector2(1, 0)
	passos(30)
	var anda: float = h.pos.x - p0
	ok(h.folego == h.folego_max and not h.correndo, "andar não gasta fôlego")
	p0 = h.pos.x
	h.correr_forcado = true
	passos(30)
	var corre: float = h.pos.x - p0
	ok(h.correndo, "Shift: correndo")
	ok(corre > anda * 1.5 and corre < anda * 1.75, "correr é ~1,6x mais rápido (%.0f contra %.0f px)" % [corre, anda])
	ok(h.folego < h.folego_max - 0.7, "correr gasta fôlego do mesmo estoque da esquiva (%.2f de %.2f)" % [h.folego, h.folego_max])
	ate(func(): return h.cansado, 200)
	ok(h.cansado and h.folego <= 0.001 and not h.correndo, "fôlego zerado: para de correr na hora e fica cansado")
	h.entrada_forcada = Vector2.ZERO
	h.correr_forcado = null
	var f0: float = h.folego
	passos(20)  # 0,33 s: ainda no atraso da recuperação
	ok(h.folego == f0, "a recuperação só começa depois do atraso (%.3f)" % h.folego)
	h.entrada_forcada = Vector2(1, 0)
	var p1: float = h.pos.x
	passos(30)
	var cansada: float = h.pos.x - p1
	ok(not h.correndo and cansada < anda and cansada > anda * 0.6, "cansado anda um pouco mais devagar (%.0f contra %.0f px)" % [cansada, anda])
	h.esquivar()
	passos(3)
	ok(h.estado != Heroi.Estado.ESQUIVA, "cansado não esquiva")
	h.entrada_forcada = Vector2.ZERO
	ok(h.folego > f0 + 0.05, "depois do atraso o fôlego volta (%.2f)" % h.folego)
	ok(h.cansado, "ainda cansado antes dos 30%% (%.2f de %.2f)" % [h.folego, h.folego_max])
	ate(func(): return not h.cansado, 300)
	ok(not h.cansado and h.folego >= 0.3 * h.folego_max - 0.01, "recuperou 30%%: o cansaço acaba (%.2f)" % h.folego)
	h.esquivar()
	passos(3)
	ok(h.estado == Heroi.Estado.ESQUIVA, "recuperado, a esquiva volta")
	# parado recupera mais rápido do que andando
	zerar()
	h = w.heroi
	h.folego = 0.5
	h._atraso_t = 0.0
	passos(60)
	var parado_g: float = h.folego - 0.5
	h.folego = 0.5
	h.entrada_forcada = Vector2(1, 0)
	passos(60)
	var andando_g: float = h.folego - 0.5
	ok(parado_g > andando_g * 1.4 and andando_g > 0.0, "parado recupera mais rápido que andando (%.2f contra %.2f)" % [parado_g, andando_g])
	# atacar cancela a corrida
	zerar()
	h = w.heroi
	h.entrada_forcada = Vector2(1, 0)
	h.correr_forcado = true
	passos(10)
	ok(h.correndo, "correndo de novo")
	h.atacar()
	passos(2)
	ok(h.estado == Heroi.Estado.GOLPE and not h.correndo, "atacar cancela a corrida")
	h.correr_forcado = null
	h.entrada_forcada = Vector2.ZERO
	# por distância a corrida sai mais cara que a esquiva
	var px_corrida: float = float(Heroi.VEL) * float(c.corrida.velocidade) / float(c.corrida.gasto)
	var px_esquiva: float = float(Heroi.VEL) * float(c.esquiva.velocidade) * float(c.esquiva.tempo) / float(c.esquiva.gasto)
	ok(px_corrida < px_esquiva, "correr custa mais fôlego por distância que esquivar (%.0f contra %.0f px por carga)" % [px_corrida, px_esquiva])

	# 10. sem nó novo por acerto: acertar e matar não cria nó (pool de monstros, números, partículas, orbes)
	zerar()
	h = w.heroi
	passos(5)
	var nos0: int = get_tree().get_node_count()
	for i in 12:
		var mm = monstro_a(26)
		mm.vida = 2.0
		h.combo_t = 0.0
		h.atacar()
		ate(func(): return not mm.vivo, 60)
		w.combate.orbes.limpar()  # sem XP: não sobe de nível (a escolha pararia o mundo)
		ate(func(): return h.estado == Heroi.Estado.LIVRE and h.pausa_t <= 0.0, 60)
		passos(30)
	ok(w.abates >= 10, "12 monstros mortos em sequência (abates=%d)" % w.abates)
	ok(get_tree().get_node_count() == nos0, "acertar e matar não cria nó (%d contra %d)" % [get_tree().get_node_count(), nos0])

	# 11. o diretor: 60 s simulados, fora da tela, aumentando, onda forte aos 60 s
	zerar()
	h = w.heroi
	w.combate.diretor.ligado = true
	h.imortal = true
	var d = w.combate.diretor
	var foras := 0
	var tela_antes: Rect2 = w.cam.retangulo()
	for i in 60:
		var p = d.ponto_fora_da_tela()
		if p != null and not tela_antes.has_point(p) and w.limite_andavel.has_point(p) and Colisao.livre(p, 7.0):
			foras += 1
	ok(foras >= 55, "o diretor acha ponto fora da tela, andável e livre (%d de 60)" % foras)
	ok(d.taxa(0.0) < d.taxa(200.0) and d.limite(0.0) < d.limite(200.0), "o diretor começa leve e aperta com o tempo")
	var max_vivos := 0
	var vivos_30 := 0
	for i in 3700:
		w.avancar(PASSO)
		max_vivos = maxi(max_vivos, w.monstros.size())
		if i == 1800:
			vivos_30 = w.monstros.size()
	ok(w.tempo_partida > 60.0, "60 s de partida simulados (%.1f)" % w.tempo_partida)
	ok(d.nascidos > 20, "o diretor fez nascer monstros (%d)" % d.nascidos)
	ok(d.ondas >= 1, "veio a onda forte aos 60 s (ondas=%d)" % d.ondas)
	ok(max_vivos <= int(c.diretor.teto), "nunca passa do teto de monstros vivos (%d)" % max_vivos)
	ok(vivos_30 > 0, "monstros vivos aos 30 s: %d" % vivos_30)
	print("v2_combate diretor: nascidos=%d ondas=%d max_vivos=%d vivos_30s=%d nos=%d" % [d.nascidos, d.ondas, max_vivos, vivos_30, get_tree().get_node_count()])

	# 12. a morte do herói: câmera lenta, tela de resultado e jogar de novo com Enter
	zerar()
	h = w.heroi
	h.imortal = false
	h.vida = 1.0
	w.abates = 7
	w.maior_combo = 5
	m = monstro_a(14)
	m.cacador = true
	ate(func(): return h.estado == Heroi.Estado.MORTO, 120)
	ok(h.estado == Heroi.Estado.MORTO and h.vida <= 0.0, "o contato derruba o herói")
	ate(func(): return w.combate.jogo == "morte", 200)
	ok(w.combate.jogo == "morte" and w.combate.pausado and w.combate.telas.resultado_aberto, "tela de resultado aberta")
	var texto: String = w.combate.telas._res_linhas.text + "\n" + w.combate.telas._res_valores.text
	ok(
		texto.contains("Abates") and texto.contains("7") and texto.contains("x5") and texto.contains("Nível"),
		"o resultado mostra tempo, abates, maior combo e nível: %s" % texto.replace("\n", " | ")
	)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	w._input(enter)
	ok(w.combate.telas.resultado_aberto, "Enter logo ao abrir é ignorado (evita clique sem querer)")
	passos(60)
	w._input(enter)
	ok(not w.combate.telas.resultado_aberto and w.combate.jogo == "jogando" and not w.combate.pausado, "Enter: jogar de novo")
	ok(w.heroi.vida == w.heroi.vida_max and w.heroi.estado == Heroi.Estado.LIVRE and w.abates == 0 and w.tempo_partida < 0.1, "partida zerada")
	ok(w.monstros.size() == 20 and w.heroi.nivel == 1, "os 20 monstros do começo e nível 1")
	passos(30)

	print("v2_combate falhas=%d" % falhas)
	get_tree().quit()
