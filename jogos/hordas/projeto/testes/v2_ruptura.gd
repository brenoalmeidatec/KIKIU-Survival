extends Node
# Teste automático da RUPTURA, a habilidade da tecla E (LB no controle) (v2/ruptura.gd, heroi.gd, combate.gd, cartas.gd, hud.gd, dados/v2_ruptura.json):
# dados, ação de entrada (tecla E e LB), carga que cresce, toque curto que cancela, disparo em 360 graus pela elipse do chão
# (cheio, parcial, perfeito), apanhar sem cancelar, esquiva que cancela, pausa/escolha/baú/morte que cancelam e não deixam o clique vazar, salto de
# relógio, recarga e buffer, golpe da katana (buffer, prioridade), chefe e elite, mortes em massa, contragolpe, as 5 cartas, os stats existentes,
# crítico explosivo, limites de efeito, reinício, o slot do HUD e a medição do alívio do cerco (só imprime) e do tempo do disparo com 100 monstros.
# O mundo anda em passos fixos de 1/60 s. Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_ruptura.tscn  (imprime "v2_ruptura falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Hud := preload("res://v2/hud.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var _variacao := 0.12


class HeroiFalso:
	extends RefCounted
	var vida := 100.0
	var vida_max := 100.0


class MundoFalso:
	extends RefCounted
	var heroi := HeroiFalso.new()


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func perto(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


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
	w.combate.cfg.golpe.variacao = _variacao
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = null
	h.correr_forcado = null
	h.ruptura_forcada = false
	h.m_dano = 1.0  # o santuário (Meta.aplicar) pode ter melhorado o herói nesta máquina: o teste parte de stats conhecidos
	h.m_area = 1.0
	h.m_vel_ataque = 1.0
	h.m_vel_mov = 1.0
	h.m_critico = 0.0
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)


## Dano exato: sem variação e sem crítico.
func exato() -> void:
	w.combate.cfg.golpe.variacao = 0.0
	w.heroi.m_critico = -0.1


func monstro_a(dx: float, dy := 0.0, vida := 5000.0, nome := "inimigo_cao_ossos"):
	var m = w.nascer_monstro(nome, w.heroi.pos + Vector2(dx, dy))
	m.atordoa_t = 0.0
	m.vida = vida
	m.vida_max = vida
	return m


## Aperta e segura o botão da ruptura (modo forçado).
func segurar() -> void:
	w.heroi.ruptura_forcada = true
	w.heroi.ruptura()


func soltar() -> void:
	w.heroi.ruptura_forcada = false


func cor_corte() -> Color:
	var fx = w.combate.fx
	var i: int = (fx._ci + fx.MAX_CORTES - 1) % fx.MAX_CORTES
	return (fx._cortes[i].material as ShaderMaterial).get_shader_parameter("cor")


## A tecla da habilidade (E). O nome antigo ficou: a ruptura já esteve no botão direito, que agora é o escudo (testes/v2_escudo.gd).
func evento_direito(apertado: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.physical_keycode = KEY_E
	ev.pressed = apertado
	return ev


## O LB do controle (valor >= 0,5 = apertado).
func evento_gatilho(valor: float) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_LEFT_SHOULDER
	ev.pressed = valor >= 0.5
	return ev


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	_variacao = float(w.combate.cfg.golpe.variacao)
	var h = w.heroi
	var cs = w.combate.cartas
	var rp = w.combate.ruptura
	var cfg: Dictionary = rp.cfg

	# 1. dados, sons e os números que os outros testes fixam
	var dj: Dictionary = Dados.json("v2_ruptura")
	ok(str(dj.get("_ajuda", "")) != "", "v2_ruptura.json tem _ajuda")
	ok(dj.has("ruptura") and dj.has("cartas"), "v2_ruptura.json tem as chaves ruptura e cartas")
	var ids := {}
	for cc in dj.cartas:
		ids[cc.id] = true
		ok(ResourceLoader.exists("res://assets/gerado/%s.png" % cc.icone), "o ícone %s existe" % cc.icone)
		ok(float(cc.valor) > 0.0 and int(cc.max) > 0, "carta %s tem valor e max" % cc.id)
		ok(str(cc.desc).contains("{v}"), "carta %s: a desc leva {v}" % cc.id)
		ok(not str(cc.nome).contains("_") and not str(cc.desc).contains("_"), "carta %s: nome e desc sem id interno" % cc.id)
	ok(dj.cartas.size() == 5 and ids.size() == 5, "5 cartas com ids únicos")
	for som in ["ruptura_tique", "ruptura_pronta", "ruptura_disparo", "ruptura_cancela"]:
		ok(ResourceLoader.exists("res://assets/audio/v2/%s.wav" % som), "o WAV %s existe" % som)
		ok(w.combate.audio._stream(som) != null, "o WAV %s carrega" % som)
	ok(
		cs.cfg.stats.size() == 7 and cs.cfg.golpes.size() == 52 and cs.cfg.modificadores.size() == 8,
		"v2_cartas preserva 7 stats, 52 golpes e 8 modificadores (4 da base e 4 dos heróis)"
	)
	ok(w.combate != null and rp != null and rp.no != null, "o combate tem o módulo da ruptura")

	# 2. entrada: a ação ruptura (tecla E e LB); o botão direito é do escudo; o resto continua
	ok(InputMap.has_action("ruptura"), "a ação ruptura existe")
	var tem_direito := false
	var tem_gatilho := false
	for e in InputMap.action_get_events("ruptura"):
		if e is InputEventKey and e.physical_keycode == KEY_E:
			tem_direito = true
		if e is InputEventJoypadButton and e.button_index == JOY_BUTTON_LEFT_SHOULDER:
			tem_gatilho = true
		ok(not (e is InputEventMouseButton), "ruptura: nenhum botão do mouse (o direito é do escudo)")
	ok(tem_direito, "ruptura: tecla E")
	ok(tem_gatilho, "ruptura: LB do controle")
	ok(InputMap.has_action("ultimate") and InputMap.has_action("escudo"), "as ações escudo e ultimate (reservada) existem")
	var atacar_esquerdo := false
	for e in InputMap.action_get_events("atacar"):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			atacar_esquerdo = true
	ok(atacar_esquerdo and InputMap.has_action("esquiva") and InputMap.has_action("correr"), "atacar no botão esquerdo, esquiva e correr continuam")

	# 3. sem apertar nada, nada acontece; aperto sem segurar também não inicia
	zerar()
	var m3 = monstro_a(60)
	passos(120)
	ok(h.rup_disparos == 0 and h.estado == Heroi.Estado.LIVRE and m3.acertos == 0 and rp.disparos == 0, "sem apertar nada: nada acontece")
	h.ruptura()  # aperto, mas o botão não está segurado
	passos(10)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0, "aperto sem segurar não inicia a carga")

	# 4. a carga: aperto + posse leva a CARGA; cresce linear até 1,0 em 0,9 s; anda a 45%; não corre nem golpeia
	zerar()
	segurar()
	passos(1)
	ok(h.estado == Heroi.Estado.CARGA, "aperto + segurar: o herói entra em CARGA")
	var p_meia := ate(func(): return h.rup_carga >= 0.5, 120)
	ok(p_meia >= 24 and p_meia <= 29, "metade da carga em ~0,45 s (%d passos)" % p_meia)
	var p_cheia := ate(func(): return h.rup_carga >= 1.0, 120)
	ok(p_cheia >= 25 and p_cheia <= 31, "carga cheia em ~0,9 s no total (mais %d passos)" % p_cheia)
	ok(h._rup_tique == 4, "os 4 tiques de som tocaram (%d)" % h._rup_tique)
	h.imortal = false  # (o teste usa herói imortal por padrão; aqui interessa a regra de verdade)
	ok(h.estado == Heroi.Estado.CARGA and h.vulneravel() and h.invenc == 0.0, "a carga NÃO dá invencibilidade")
	h.imortal = true
	soltar()
	passos(2)
	h.cancelar_ruptura(false)
	zerar()
	h.m_vel_ataque = 2.0
	segurar()
	var p2 := ate(func(): return h.rup_carga >= 1.0, 120)
	ok(p2 >= 25 and p2 <= 30, "com velocidade de ataque 2,0 a carga cheia leva ~0,45 s (%d passos)" % p2)
	zerar()
	h.m_vel_ataque = 6.0
	segurar()
	var p6 := ate(func(): return h.rup_carga >= 1.0, 120)
	ok(p6 >= 22 and p6 <= 27, "com velocidade de ataque 6 vale o piso de 0,4 s (%d passos)" % p6)
	zerar()
	h.entrada_forcada = Vector2(1, 0)
	h.correr_forcado = true
	segurar()
	passos(2)
	var x0: float = h.pos.x
	passos(30)
	var dx: float = h.pos.x - x0
	ok(dx > 22.5 * 0.85 and dx < 22.5 * 1.15, "andando por 0,5 s a carga desloca ~22 px, a 45%% (%.1f px)" % dx)
	ok(not h.correndo, "na carga não corre (Shift não conta)")
	var g4: int = h.golpes
	h.atacar()
	passos(5)
	ok(h.golpes == g4 and h.estado == Heroi.Estado.CARGA, "na carga o clique esquerdo é ignorado (golpes %d)" % h.golpes)
	h.cancelar_ruptura(false)

	# 5. toque curto cancela: sem disparo, sem recarga, ninguém ferido
	zerar()
	var m5 = monstro_a(50)
	segurar()
	passos(7)  # ~0,1 s
	soltar()
	passos(2)
	ok(h.rup_cancelados == 1 and h.rup_disparos == 0 and h.rup_recarga == 0.0, "toque curto (<0,2 s) cancela sem recarga")
	ok(h.estado == Heroi.Estado.LIVRE and m5.acertos == 0 and m5.vida == m5.vida_max, "toque curto: estado livre e ninguém ferido")

	# 6. disparo cheio sem perfeito: elipse do chão, dano, atordoamento, empurrão, recarga e contragolpe
	zerar()
	h.m_critico = -0.1
	var a_perto = monstro_a(98)  # raio 96 + corpo 7 = 103
	var a_longe = monstro_a(110)
	var v_perto = monstro_a(0, 55)  # a elipse vale 0,62: 103 * 0,62 = 63,9 na vertical
	var v_longe = monstro_a(0, 70)
	var esq = monstro_a(-40)
	var n6: int = rp.disparar(h, 1.0, false)
	ok(rp.ultimo.raio == 96.0 and perto(float(rp.ultimo.raio), 96.0, 0.01), "disparo cheio: raio 96 (%.1f)" % float(rp.ultimo.raio))
	ok(a_perto.acertos == 1 and a_longe.acertos == 0, "cão a 98 px na horizontal apanha, a 110 px não")
	ok(v_perto.acertos == 1 and v_longe.acertos == 0, "cão a 55 px na vertical apanha, a 70 px não (elipse de 0,62)")
	ok(esq.acertos == 1 and n6 == 3, "atinge os dois lados: 360 graus (acertou %d)" % n6)
	var dano6: float = a_perto.vida_max - a_perto.vida
	ok(dano6 >= 19.0 and dano6 <= 25.0, "dano 22 mais ou menos 12%% (%.0f)" % dano6)
	ok(perto(a_perto.atordoa_t, 0.5, 0.01), "atordoa 0,5 s (%.3f)" % a_perto.atordoa_t)
	ok(a_perto.emp.x > 240.0 and esq.emp.x < -240.0, "o empurrão aponta para fora (%.0f e %.0f)" % [a_perto.emp.x, esq.emp.x])
	ok(perto(h.rup_recarga, 2.6, 0.01) and perto(h.rup_recarga_max, 2.6, 0.01), "recarga de 2,6 s (%.2f)" % h.rup_recarga)
	ok(perto(h.contragolpe_t, 1.5, 0.01), "acertou: abre a janela do contragolpe de 1,5 s (%.2f)" % h.contragolpe_t)
	ok(h.vida == h.vida_max, "a ruptura nunca fere o herói")

	# 7. disparo parcial: a tabela de referência
	zerar()
	exato()
	var t0 = monstro_a(80)  # 65 + corpo 7 = 72: fora
	rp.disparar(h, 0.2 / 0.9, false)
	ok(
		perto(float(rp.ultimo.raio), 64.9, 1.0) and perto(float(rp.ultimo.dano), 12.4, 0.7),
		"toque de 0,2 s: raio ~65 e dano ~12 (%.1f, %.1f)" % [rp.ultimo.raio, rp.ultimo.dano]
	)
	ok(perto(float(rp.ultimo.atordoa), 0.31, 0.01), "toque de 0,2 s: atordoa ~0,31 s (%.3f)" % rp.ultimo.atordoa)
	ok(t0.acertos == 0, "o cão a 80 px fica de fora do raio de 65")
	var t1 = monstro_a(60)
	rp.disparar(h, 0.5, false)
	ok(
		perto(float(rp.ultimo.raio), 76.0, 0.01) and perto(float(rp.ultimo.dano), 16.0, 0.01) and perto(float(rp.ultimo.atordoa), 0.375, 0.001),
		"meia carga: raio 76, dano 16, atordoa 0,375"
	)
	ok(t1.acertos == 1 and t1.vida_max - t1.vida == 16.0, "meia carga tirou 16 de vida (%.1f)" % (t1.vida_max - t1.vida))
	ok(perto(rp.empurrao_de(0.5), 205.0, 0.01), "meia carga: empurrão 205")

	# 8. disparo perfeito pelo herói: carga cheia + janela de 0,2 s (fixa em segundos, não depende da velocidade de ataque)
	zerar()
	exato()
	var m8 = monstro_a(105)  # entra só com o raio de 110
	segurar()
	var ate_perf := ate(func(): return h.rup_perfeita, 120)
	ok(ate_perf > 0, "a janela perfeita abre depois da carga cheia")
	soltar()
	passos(1)
	ok(rp.ultimo.perfeito and perto(float(rp.ultimo.raio), 110.4, 0.1), "perfeito: raio 110 (%.1f)" % float(rp.ultimo.raio))
	ok(
		perto(float(rp.ultimo.dano), 27.5, 0.01) and perto(float(rp.ultimo.atordoa), 0.65, 0.001),
		"perfeito: dano 27,5 e atordoa 0,65 (%.2f, %.3f)" % [rp.ultimo.dano, rp.ultimo.atordoa]
	)
	ok(perto(h.rup_recarga, 2.2, 0.05), "perfeito: recarga 2,2 s (%.2f)" % h.rup_recarga)
	ok(m8.acertos == 1 and h.rup_disparos == 1, "o cão a 105 px só apanha com o raio perfeito")
	zerar()
	segurar()
	ate(func(): return h.rup_carga_t > 1.3, 200)
	ok(not h.rup_perfeita and h.rup_carga == 1.0, "passada a janela a carga fica cheia e sem bônus")
	soltar()
	passos(1)
	ok(not rp.ultimo.perfeito and perto(float(rp.ultimo.raio), 96.0, 0.01) and perto(h.rup_recarga, 2.6, 0.05), "soltar tarde: raio 96 e recarga 2,6")
	zerar()
	h.m_vel_ataque = 2.0
	segurar()
	ate(func(): return h.rup_carga_t >= 0.5, 100)
	ok(h.rup_perfeita, "com velocidade de ataque 2,0 a janela perfeita abre em 0,45 s")
	ate(func(): return h.rup_carga_t >= 0.7, 100)
	ok(not h.rup_perfeita, "e fecha 0,2 s depois, sem encolher (a janela é fixa em segundos)")
	h.cancelar_ruptura(false)

	# 9. apanhar NÃO cancela a carga; a primeira batida entra
	zerar()
	h.imortal = false
	h.vida = h.vida_max
	segurar()
	passos(3)
	ok(h.vulneravel(), "no começo da carga o herói é vulnerável")
	var mc = monstro_a(14)
	mc.cacador = true
	ate(func(): return h.vida < h.vida_max, 90)
	var t_antes: float = h.rup_carga_t
	ok(h.vida < h.vida_max, "o cão encostado bateu no herói carregando (%.0f)" % h.vida)
	passos(10)
	ok(h.estado == Heroi.Estado.CARGA and h.rup_carga_t > t_antes, "apanhar não cancela a carga: ela segue crescendo")
	h.cancelar_ruptura(false)

	# 10. esquiva cancela de graça; cansado a esquiva não sai e a carga continua
	zerar()
	var m10 = monstro_a(50)
	var fo0: float = h.folego
	segurar()
	passos(10)
	h.esquivar()
	passos(2)
	ok(h.estado == Heroi.Estado.ESQUIVA, "a esquiva cancela a carga e rola")
	ok(h.rup_recarga == 0.0 and h.rup_disparos == 0 and m10.acertos == 0 and h.rup_cancelados == 1, "cancelar com a esquiva não gasta recarga nem fere ninguém")
	ok(perto(fo0 - h.folego, 1.0, 0.05), "a esquiva gasta o fôlego dela (%.2f)" % (fo0 - h.folego))
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 80)
	passos(30)
	ok(h.estado == Heroi.Estado.LIVRE, "o botão ainda segurado depois da esquiva não recomeça a carga sozinho")
	zerar()
	h.cansado = true
	h.folego = 0.0
	segurar()
	passos(10)
	h.esquivar()
	passos(3)
	ok(h.estado == Heroi.Estado.CARGA, "cansado a esquiva não sai e a carga continua")
	h.cancelar_ruptura(false)

	# 11. pausa, escolha, baú, morte e resultado cancelam e não deixam iniciar
	zerar()
	segurar()
	passos(10)
	w.combate.pausado = true
	passos(1)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_carga == 0.0, "com a pausa do combate a carga cancela")
	soltar()
	w.combate.pausado = false
	passos(6)
	ok(h.rup_disparos == 0 and h.rup_recarga == 0.0, "soltar depois da pausa não dispara e não gasta recarga")
	for jogo in ["escolha", "bau", "morte", "vitoria", "abandono", "vencendo", "morrendo"]:
		zerar()
		segurar()
		passos(10)
		w.combate.jogo = jogo
		passos(1)
		ok(h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0, "com o jogo em '%s' a carga cancela sem disparar" % jogo)
		soltar()
		passos(4)
		ok(h.rup_disparos == 0 and h.rup_recarga == 0.0, "'%s': soltar não dispara" % jogo)
		segurar()  # fora do jogo o aperto não guarda nada
		passos(3)
		ok(h.estado == Heroi.Estado.LIVRE and h.rup_pedido_t == 0.0, "'%s': apertar não inicia nem guarda o pedido" % jogo)
		w.combate.jogo = "jogando"
		passos(3)
		ok(h.estado == Heroi.Estado.LIVRE, "'%s': o botão já segurado não recomeça sozinho quando o jogo volta" % jogo)
	zerar()
	w.combate.pausado = true
	segurar()
	w.combate.pausado = false
	passos(5)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_pedido_t == 0.0, "apertar com o jogo pausado não guarda o pedido")

	# 11b. o menu de pausa aberto (mundo.pausa.aberto) também trava a ruptura, mesmo sem a árvore pausada (testes e entrada forçada)
	zerar()
	ok(w.pausa != null, "o mundo guarda o menu de pausa")
	segurar()
	passos(10)
	ok(h.estado == Heroi.Estado.CARGA, "carregando antes de abrir o menu")
	w.pausa.aberto = true
	passos(1)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0, "com o menu de pausa aberto a carga cancela sem disparar")
	soltar()
	segurar()
	passos(3)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_pedido_t == 0.0, "com o menu aberto apertar não inicia nem guarda o pedido")
	soltar()
	w.pausa.aberto = false
	passos(3)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0 and h.rup_recarga == 0.0, "fechado o menu, o botão já solto não dispara nem gasta recarga")

	# 12. a escolha de melhoria de verdade: a carga cancela, o clique direito não vaza e o botão já segurado não recomeça
	zerar()
	segurar()
	passos(10)
	ok(h.estado == Heroi.Estado.CARGA, "carregando antes da escolha")
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	ate(func(): return w.combate.jogo == "escolha", 120)
	ok(w.combate.jogo == "escolha" and w.combate.telas.escolha_aberta, "abriu a escolha de melhoria")
	passos(1)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0, "a escolha cancelou a carga sem disparar")
	h.entrada_forcada = null
	w._input(evento_direito(true))
	w._input(evento_direito(false))
	ok(h.rup_pedido_t == 0.0 and h.estado == Heroi.Estado.LIVRE, "escolha: o clique direito não vaza para o jogo")
	h.entrada_forcada = Vector2.ZERO
	w.combate.progresso.escolher(0)
	passos(6)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0, "depois da escolha o botão já segurado não recomeça sozinho")
	# o baú
	zerar()
	segurar()
	passos(5)
	w.combate.baus.soltar(h.pos + Vector2(8, 0), 1.0, 1)
	ate(func(): return w.combate.jogo == "bau", 240)
	ok(w.combate.jogo == "bau" and w.combate.telas.bau_aberto, "abriu o baú")
	passos(1)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0, "o baú cancelou a carga sem disparar")
	h.entrada_forcada = null
	w._input(evento_direito(true))
	w._input(evento_direito(false))
	ok(h.rup_pedido_t == 0.0 and h.estado == Heroi.Estado.LIVRE, "baú: o clique direito não vaza para o jogo")
	h.entrada_forcada = Vector2.ZERO
	ate(func(): return w.combate.telas.bau_pronto, 900)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	w._input(enter)
	# a morte e o resultado
	zerar()
	h.imortal = false
	h.vida = 1.0
	segurar()
	passos(10)
	h.levar_dano(50.0, h.pos + Vector2(10, 0))
	ok(h.estado == Heroi.Estado.MORTO and h.rup_carga == 0.0 and h.rup_disparos == 0, "morrer carregando: estado MORTO, carga zerada, sem disparo")
	ate(func(): return w.combate.jogo == "morte", 240)
	ok(w.combate.jogo == "morte" and w.combate.telas.resultado_aberto, "abriu o resultado")
	h.entrada_forcada = null
	w._input(evento_direito(true))
	w._input(evento_direito(false))
	ok(h.rup_pedido_t == 0.0 and h.estado == Heroi.Estado.MORTO, "resultado: o clique direito não vaza para o jogo")
	h.entrada_forcada = Vector2.ZERO

	# 13. salto de relógio (ESC e perda de foco não passam por combate.pausado) e hit-stop
	zerar()
	segurar()
	passos(10)
	h._rup_us = Time.get_ticks_usec() - 600000
	passos(1)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0 and h.rup_cancelados == 1, "salto de relógio de 0,6 s: cancela sem disparar")
	soltar()
	passos(5)
	ok(h.rup_disparos == 0 and h.rup_recarga == 0.0, "soltar depois do salto não dispara ao voltar")
	zerar()
	segurar()
	passos(10)
	var tc: float = h.rup_carga_t
	w.combate.parada_t = 0.1
	passos(3)
	ok(h.rup_carga_t == tc and h.estado == Heroi.Estado.CARGA, "no hit-stop a carga não avança (e um hit-stop de 0,25 s não é salto)")
	h.rup_recarga = 1.0
	h.cancelar_ruptura(false)
	w.combate.parada_t = 0.2
	passos(6)
	ok(h.rup_recarga == 1.0, "no hit-stop a recarga não desce")
	passos(30)
	ok(h.rup_recarga < 1.0, "e depois do hit-stop ela volta a descer")

	# 14. aperto na recarga: negado, ou guardado se a recarga acaba dentro do buffer
	zerar()
	h.rup_recarga = 1.0
	h.ruptura_forcada = true
	h.ruptura()
	ok(h.rup_nega_t > 0.0 and h.rup_pedido_t == 0.0, "aperto na recarga: negado, não fica guardado")
	passos(5)
	ok(h.estado == Heroi.Estado.LIVRE, "e a carga não começa")
	var rec_antes: float = h.rup_recarga
	zerar()
	h.rup_recarga = 0.1
	h.ruptura_forcada = true
	h.ruptura()
	ok(h.rup_pedido_t > 0.0 and h.rup_nega_t == 0.0, "recarga dentro do buffer (0,18 s): o aperto fica guardado")
	var p14 := ate(func(): return h.estado == Heroi.Estado.CARGA, 30)
	ok(p14 >= 5 and p14 <= 9, "a carga começa quando a recarga zera (%d passos)" % p14)
	ok(rec_antes < 1.0, "a recarga corre sozinha")
	h.cancelar_ruptura(false)

	# 15. golpe da katana: buffer antes do acerto, cancela depois do acerto, prioridade e volta a golpear
	zerar()
	h.atacar()
	passos(1)
	ok(h.estado == Heroi.Estado.GOLPE, "começou o golpe")
	segurar()
	passos(2)
	ok(h.estado == Heroi.Estado.GOLPE and not h.golpe_acertou, "ruptura apertada antes do acerto não cancela o golpe")
	ate(func(): return h.estado != Heroi.Estado.GOLPE, 60)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_pedido_t > 0.0, "o golpe terminou inteiro e o pedido da ruptura ainda vale")
	passos(1)
	ok(h.estado == Heroi.Estado.CARGA and h.golpe_acertou and h.golpe_t >= h.golpe_dur - 0.02, "a carga começa quando o golpe acaba (acertou o golpe todo)")
	h.cancelar_ruptura(false)
	zerar()
	soltar()
	h.atacar()
	passos(1)
	ate(func(): return h.golpe_acertou, 40)
	segurar()
	passos(1)
	ok(h.estado == Heroi.Estado.CARGA, "ruptura apertada depois do acerto cancela o resto do golpe e carrega na hora")
	ok(h.proximo == 0 and h.combo_t == 0.0 and h.pedido_t == 0.0, "iniciar a carga zera o combo (o próximo clique volta ao corte 1)")
	h.cancelar_ruptura(false)
	zerar()
	var m15 = monstro_a(40)
	var g15: int = h.golpes
	h.ataque_forcado = true  # segura o clique esquerdo
	segurar()
	passos(2)
	ok(h.estado == Heroi.Estado.CARGA and h.golpes == g15, "clique esquerdo segurado e ruptura: a ruptura vence")
	passos(15)
	soltar()
	passos(2)
	ok(h.rup_disparos == 1 and m15.acertos >= 1, "soltou depois de 0,25 s: disparou")
	passos(4)
	ok(h.golpes == g15, "logo depois do disparo a katana espera 0,10 s")
	passos(14)
	ok(h.golpes > g15, "ao disparar o clique segurado volta a golpear")
	h.ataque_forcado = null

	# 16. chefe e mini-chefe: dano normal, lentidão, sem atordoar nem empurrar; elite: atordoa metade e blindado quase não sai do lugar
	zerar()
	exato()
	var ch = w.combate.chefes.nascer(cs.cfg.chefes.marcas[0], h.pos + Vector2(60, 0))
	var cv0: float = ch.vida
	var normal = monstro_a(-50)
	rp.disparar(h, 1.0, false)
	ok(cv0 - ch.vida >= 21.0 and cv0 - ch.vida <= 23.0, "o chefe leva o dano normal (%.1f)" % (cv0 - ch.vida))
	ok(ch.atordoa_t == 0.0 and ch.lento_t > 1.0, "chefe: sem atordoar, com lentidão de ~1,2 s (%.2f)" % ch.lento_t)
	ok(ch.emp.length() < 15.0, "chefe: empurrão desprezível (%.1f)" % ch.emp.length())
	ok(normal.atordoa_t > 0.4, "o monstro comum no mesmo disparo atordoa")
	zerar()
	exato()
	var el = w.combate.elites.nascer("inimigo_cao_ossos", "blindado", h.pos + Vector2(60, 0))
	var el2 = w.combate.elites.nascer("inimigo_cao_ossos", "rapido", h.pos + Vector2(-60, 0))
	var comum = monstro_a(0, 40)
	rp.disparar(h, 1.0, false)
	ok(el.acertos == 1 and el2.acertos == 1, "a elite entra no disparo")
	ok(el2.atordoa_t > 0.2 and el2.atordoa_t < comum.atordoa_t * 0.7, "a elite atordoa metade (%.2f contra %.2f)" % [el2.atordoa_t, comum.atordoa_t])
	ok(el.emp.length() < comum.emp.length() * 0.3, "o blindado quase não é empurrado (%.0f contra %.0f)" % [el.emp.length(), comum.emp.length()])

	# 17. mortes em massa: 12 cães com 5 de vida morrem juntos; abates, combo, orbes e nenhum nó novo
	zerar()
	exato()
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		var mm = monstro_a(cos(a) * 50.0, sin(a) * 50.0 * 0.62, 5.0)
		mm.vida_max = 5.0
	var nos_glow: int = w.glow.get_child_count()
	var nos_mundo: int = w.no_mundo.get_child_count()
	var ab0: int = w.abates
	rp.disparar(h, 1.0, false)
	ok(w.monstros.is_empty(), "os 12 cães morreram no mesmo disparo (restam %d)" % w.monstros.size())
	ok(w.abates == ab0 + 12 and w.combo == 12 and rp.ultimo.mortes == 12, "abates e combo subiram (abates %d, combo %d)" % [w.abates, w.combo])
	ok(w.combate.orbes.ativos >= 12, "caíram orbes (%d)" % w.combate.orbes.ativos)
	ok(w.combate.fx.n_txt.has("x12"), "texto xN com 3 ou mais mortes")
	var consistente := true
	for mo in w.monstros:
		consistente = consistente and mo.vivo and not mo.morrendo
	ok(consistente, "a lista de monstros ficou consistente")
	ok(
		w.glow.get_child_count() == nos_glow and w.no_mundo.get_child_count() == nos_mundo,
		"o disparo não cria nó (glow %d, mundo %d)" % [w.glow.get_child_count(), w.no_mundo.get_child_count()]
	)

	# 18. contragolpe: +30% no golpe direto da katana por 1,5 s depois de um disparo que acertou; no vazio não abre; as cores mudam só na janela
	zerar()
	exato()
	var alvo = monstro_a(34, 0, 9000.0)
	h.atacar()
	ate(func(): return alvo.acertos >= 1, 40)
	var base_dano: float = alvo.vida_max - alvo.vida
	ok(base_dano == 12.0, "o corte fora da janela causa 12 (%.0f)" % base_dano)
	ok(cor_corte().g > 0.9, "fora da janela o corte tem a cor normal (%.2f)" % cor_corte().g)
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 60)
	passos(40)
	rp.disparar(h, 1.0, false)
	ok(perto(h.contragolpe_t, 1.5, 0.01), "o disparo que acertou abriu a janela")
	h.pausa_t = 0.0
	h.combo_t = 0.0
	h.proximo = 0
	alvo.atordoa_t = 0.0
	alvo.emp = Vector2.ZERO
	alvo.definir_pos(h.pos + Vector2(34, 0))
	var vida0: float = alvo.vida
	h.atacar()
	ate(func(): return alvo.vida < vida0, 40)
	var d_contra: float = vida0 - alvo.vida
	ok(d_contra == 16.0, "dentro da janela o corte causa +30%% (16 contra 12; mediu %.0f)" % d_contra)
	ok(cor_corte().g < 0.8, "dentro da janela o corte sai alaranjado (%.2f)" % cor_corte().g)
	ate(func(): return h.contragolpe_t <= 0.0, 200)
	ok(h.contragolpe_t == 0.0, "depois de 1,5 s a janela fecha")
	zerar()
	exato()
	var vazio: int = rp.disparar(h, 1.0, false)
	ok(vazio == 0 and h.contragolpe_t == 0.0, "disparo no vazio não abre a janela")
	ok(perto(rp.fator_contragolpe(h), 1.0, 0.0001), "sem janela o fator é 1")

	# 19. cartas, uma por uma
	zerar()
	exato()
	var def_dano: Dictionary = cs.definicao("rb_dano")
	var c_comum: Dictionary = cs.montar_carta(def_dano, 0)
	var c_lend: Dictionary = cs.montar_carta(def_dano, 3)
	ok(
		c_comum.cat == "rb" and c_comum.valor == 15.0 and c_lend.valor == 48.0,
		"Punho de terra: 15 comum e 48 lendária (%.0f e %.0f)" % [c_comum.valor, c_lend.valor]
	)
	ok(not str(c_comum.desc).contains("{v}") and str(c_comum.desc).contains("15"), "a desc traz o número no lugar de {v}: %s" % c_comum.desc)
	var m19 = monstro_a(50)
	rp.disparar(h, 1.0, false)
	ok(perto(float(rp.ultimo.dano), 22.0, 0.001), "sem cartas o dano base é 22")
	cs.aplicar(c_comum)
	ok(perto(rp.somas.dano, 15.0, 0.001) and perto(rp.dano_de(h, 1.0, false), 25.3, 0.01), "Punho de terra comum: +15% (25,3 contra 22)")
	m19.vida = m19.vida_max
	rp.disparar(h, 1.0, false)
	ok(m19.vida_max - m19.vida == 25.0, "e o dano medido no disparo subiu para 25 (%.0f)" % (m19.vida_max - m19.vida))
	cs.aplicar(c_lend)
	ok(perto(rp.somas.dano, 63.0, 0.001), "somando a lendária: +63%")
	ok(cs.nivel_de("rb_dano") == 2 and cs.resumo().any(func(r): return r.id == "rb_dano"), "Punho de terra aparece no resumo da build")
	# Pulso ligeiro
	zerar()
	var def_rec: Dictionary = cs.definicao("rb_recarga")
	cs.aplicar(cs.montar_carta(def_rec, 0))
	ok(perto(rp.recarga_de(false), 2.444, 0.001), "Pulso ligeiro comum: recarga 2,444 s (%.3f)" % rp.recarga_de(false))
	for i in 3:
		cs.aplicar(cs.montar_carta(def_rec, 3))
	ok(rp.recarga_de(false) == 2.0 and rp.recarga_de(true) == 2.0, "com 4 cartas a recarga nunca passa do piso de 2,0 s (%.3f)" % rp.recarga_de(false))
	ok(cs.nivel_de("rb_recarga") == 4 and not cs._disponivel(def_rec) and not cs.disponiveis().has(def_rec), "no máximo (4) a carta deixa de sair")
	# Estrondo
	zerar()
	var def_est: Dictionary = cs.definicao("rb_estrondo")
	ok(perto(rp.atordoa_de(1.0, false), 0.5, 0.0001), "sem cartas atordoa 0,5 s")
	cs.aplicar(cs.montar_carta(def_est, 0))
	ok(perto(rp.atordoa_de(1.0, false), 0.6, 0.0001), "Estrondo comum: +20%% (0,6 s; %.3f)" % rp.atordoa_de(1.0, false))
	for i in 2:
		cs.aplicar(cs.montar_carta(def_est, 3))
	ok(rp.atordoa_de(1.0, false) == 1.0 and rp.atordoa_de(1.0, true) == 1.0, "o atordoamento nunca passa de 1,0 s (%.3f)" % rp.atordoa_de(1.0, true))
	ok(cs.nivel_de("rb_estrondo") == 3 and not cs._disponivel(def_est), "Estrondo respeita o máximo (3)")
	# Contragolpe
	zerar()
	var def_con: Dictionary = cs.definicao("rb_contra")
	ok(perto(rp.bonus_contragolpe(), 0.3, 0.0001), "sem cartas o contragolpe é +30%")
	cs.aplicar(cs.montar_carta(def_con, 0))
	ok(perto(rp.bonus_contragolpe(), 0.38, 0.0001), "Contragolpe comum: +38%% (%.3f)" % rp.bonus_contragolpe())
	zerar()
	for i in 3:
		cs.aplicar(cs.montar_carta(def_con, 3))
	ok(rp.bonus_contragolpe() == 1.0, "o contragolpe nunca passa de +100%% (%.3f)" % rp.bonus_contragolpe())
	ok(cs.nivel_de("rb_contra") == 3 and not cs._disponivel(def_con), "Contragolpe respeita o máximo (3)")
	# Eco do chão
	zerar()
	exato()
	var def_eco: Dictionary = cs.definicao("rb_eco")
	cs.aplicar(cs.montar_carta(def_eco, 0))
	ok(perto(rp.somas.eco, 25.0, 0.001), "Eco do chão comum: 25%")
	var e1 = monstro_a(60)  # dentro do primeiro pulso (raio 96) e do eco (raio 67)
	var e2 = monstro_a(90)  # só no primeiro
	var tp0: float = w.tempo_partida
	rp.disparar(h, 1.0, false)
	ok(e1.vida_max - e1.vida == 22.0 and e2.vida_max - e2.vida == 22.0, "o primeiro pulso acerta os dois")
	e1.atordoa_t = 0.0
	e1.emp = Vector2.ZERO
	e2.emp = Vector2.ZERO  # o empurrão não leva ninguém para fora ou para dentro do raio do eco
	var ecos0: int = rp.ecos
	ate(func(): return w.tempo_partida - tp0 >= 0.24, 200)
	ok(rp.ecos == ecos0 and e1.vida_max - e1.vida == 22.0, "o eco ainda não saiu aos 0,24 s do mundo")
	ate(func(): return rp.ecos > ecos0, 200)
	var t_eco: float = w.tempo_partida - tp0
	ok(rp.ecos == ecos0 + 1 and t_eco >= 0.28 and t_eco <= 0.36, "0,3 s depois do disparo sai o eco (%.3f s)" % t_eco)
	ok(
		e1.vida_max - e1.vida == 22.0 + 6.0 and e2.vida_max - e2.vida == 22.0,
		"eco: raio de 70%% e dano de 25%% (6 de 22); o de longe não apanha (%.0f e %.0f)" % [e1.vida_max - e1.vida, e2.vida_max - e2.vida]
	)
	ok(e1.atordoa_t == 0.0, "o eco não atordoa")
	ok(perto(h.contragolpe_t, 1.5 - t_eco, 0.08), "o eco não abre outro contragolpe (%.2f)" % h.contragolpe_t)
	passos(60)
	ok(rp.ecos == ecos0 + 1, "sem eco do eco")
	zerar()
	cs.aplicar(cs.montar_carta(def_eco, 3))
	cs.aplicar(cs.montar_carta(def_eco, 3))
	ok(cs.nivel_de("rb_eco") == 2 and not cs._disponivel(def_eco), "Eco respeita o máximo (2)")
	zerar()
	cs.aplicar(cs.montar_carta(def_eco, 0))
	monstro_a(40)
	rp.disparar(h, 1.0, false)
	w.reiniciar()
	passos(30)
	ok(rp.ecos == 0 and rp.somas.eco == 0.0, "reiniciar descarta o eco pendente e zera os bônus")
	# sorteio e textos
	zerar()
	ok(cs.disponiveis().filter(func(d): return d.id.begins_with("rb_")).size() == 5, "as 5 cartas aparecem em disponiveis()")
	var viu_rb := false
	for i in 40:
		var tres: Array = cs.sortear(3, 5)
		ok(tres.size() == 3, "sortear(3, 5) devolve 3 cartas")
		for cc in tres:
			if str(cc.id).begins_with("rb_"):
				viu_rb = true
				ok(not str(cc.desc).contains("{v}") and str(cc.desc).length() > 8, "a desc da carta sorteada traz o número: %s" % cc.desc)
	ok(viu_rb, "as cartas da ruptura saem no sorteio")

	# 20. os stats existentes valem na ruptura
	zerar()
	exato()
	h.m_area = 1.5
	ok(perto(rp.raio_de(h, 1.0, false), 124.8, 0.01), "Arco largo (m_area 1,5): raio 96 vezes 1,3 = 125 (%.1f)" % rp.raio_de(h, 1.0, false))
	h.m_area = 1.0
	h.m_dano = 2.0
	var m20 = monstro_a(50)
	rp.disparar(h, 1.0, false)
	ok(m20.vida_max - m20.vida == 44.0, "Lâmina afiada (m_dano 2,0) dobra o dano (%.0f)" % (m20.vida_max - m20.vida))
	h.m_dano = 1.0
	h.m_critico = 1.0
	m20.vida = m20.vida_max
	var n_crit0: int = w.combate.fx.usados.numeros
	rp.disparar(h, 1.0, false)
	ok(m20.vida_max - m20.vida == 44.0 and w.combate.fx.n_tam.has(24), "Olho de falcão (m_critico 1,0): todo alvo dá crítico (dano x2, número grande)")
	ok(w.combate.fx.usados.numeros > n_crit0, "o crítico mostra o número")

	# 21. crítico explosivo: no máximo 6 explosões por disparo, mesmo com 20 alvos
	zerar()
	exato()
	h.m_critico = 1.0
	w.combate.armas.mods.explode = 50.0
	for i in 20:
		var a21: float = TAU * float(i) / 20.0
		monstro_a(cos(a21) * 60.0, sin(a21) * 60.0 * 0.62, 5000.0)
	var ex0: int = int(w.combate.armas.acertos.get("explode", 0))
	rp.disparar(h, 1.0, false)
	ok(int(w.combate.armas.acertos.get("explode", 0)) > ex0, "crítico explosivo: a ruptura chama armas.explodir")
	ok(rp._explosoes == 6, "no máximo 6 explosões por disparo (%d)" % rp._explosoes)
	w.combate.armas.mods.explode = 0.0

	# 22. limites de efeito: 8 números (e todo crítico), 20 piscadas
	zerar()
	exato()
	for i in 24:
		var a22: float = TAU * float(i) / 24.0
		monstro_a(cos(a22) * 70.0, sin(a22) * 70.0 * 0.62, 5000.0)
	var nu0: int = w.combate.fx.usados.numeros
	var fl0: int = w.combate.fx.usados.flashes
	rp.disparar(h, 1.0, false)
	ok(w.combate.fx.usados.numeros - nu0 == 8, "número de dano só nos 8 mais perto (%d)" % (w.combate.fx.usados.numeros - nu0))
	ok(w.combate.fx.usados.flashes - fl0 <= 21, "no máximo 20 piscadas dos monstros mais a do herói (%d)" % (w.combate.fx.usados.flashes - fl0))
	h.m_critico = 1.0
	nu0 = w.combate.fx.usados.numeros
	rp.disparar(h, 1.0, false)
	ok(w.combate.fx.usados.numeros - nu0 == 24, "todo crítico tem número (%d)" % (w.combate.fx.usados.numeros - nu0))

	# 23. reinício: morrer carregando e jogar de novo zeram tudo
	zerar()
	segurar()
	passos(10)
	cs.aplicar(cs.montar_carta(def_dano, 0))
	h.rup_recarga = 1.0
	h.contragolpe_t = 1.0
	w.reiniciar()
	ok(
		(
			h.estado == Heroi.Estado.LIVRE
			and h.rup_carga == 0.0
			and h.rup_recarga == 0.0
			and h.contragolpe_t == 0.0
			and h.rup_disparos == 0
			and h.rup_cancelados == 0
		),
		"reiniciar zera rup_*, a recarga e o contragolpe"
	)
	ok(rp.somas.dano == 0.0 and rp.disparos == 0, "reiniciar zera os bônus das cartas da ruptura")

	# 24. HUD: o slot aparece com o herói da ruptura e some no mundo falso
	zerar()
	var vista := SubViewport.new()
	vista.size = Vector2i(960, 540)
	vista.disable_3d = true
	add_child(vista)
	var hud = Hud.criar(w)
	vista.add_child(hud)
	hud.set_process(false)
	hud.avancar(PASSO)
	ok(hud._rb != null and hud._rb.visible, "o slot da ruptura aparece com o herói da v2")
	ok(hud._rb.light_mask == 0 and hud._rb.mouse_filter == Control.MOUSE_FILTER_IGNORE, "o slot é fora da luz e não pega o mouse")
	segurar()
	passos(30)
	hud.avancar(PASSO)
	ok(hud._rb_barra > 5, "em carga a barra do slot enche (%d px)" % hud._rb_barra)
	h.cancelar_ruptura(false)
	h.rup_recarga = 1.3
	h.rup_recarga_max = 2.6
	hud.avancar(PASSO)
	ok(hud._rb_cortina >= 9 and hud._rb_cortina <= 11 and not hud._rb_pronta, "em recarga a cortina cobre a fração que falta (%d px)" % hud._rb_cortina)
	h.rup_recarga = 0.0
	hud.avancar(PASSO)
	ok(hud._rb_pronta and hud._rb_pop > 0.0, "recarga zerada: pop de 'pronta'")
	h.rup_nega_t = 0.2
	hud.avancar(PASSO)
	ok(hud._rb_nega, "negado: moldura vermelha")
	h.rup_nega_t = 0.0
	h.contragolpe_t = 0.75
	h.contragolpe_max = 1.5
	hud.avancar(PASSO)
	ok(hud._rb_contra == 10, "contragolpe aberto: faísca proporcional (%d px)" % hud._rb_contra)
	h.contragolpe_t = 0.0
	hud.queue_free()
	var vista2 := SubViewport.new()
	vista2.size = Vector2i(960, 540)
	add_child(vista2)
	var hud2 = Hud.criar(MundoFalso.new())
	vista2.add_child(hud2)
	hud2.set_process(false)
	hud2.avancar(PASSO)
	ok(hud2._rb != null and not hud2._rb.visible, "sem os campos da ruptura no herói o slot fica invisível")
	hud2.queue_free()
	var hud3 = Hud.criar(null)
	vista2.add_child(hud3)
	hud3.set_process(false)
	hud3.avancar(PASSO)
	ok(not hud3._rb.visible, "sem mundo o slot fica invisível")
	hud3.queue_free()

	# 25. painel de status: resumo() e linha()
	zerar()
	var r: Dictionary = rp.resumo()
	ok(r.dano_min == 10.0 and r.dano_max == 22.0 and r.raio_min == 56.0 and r.raio_max == 96.0, "resumo(): dano 10 a 22 e raio 56 a 96")
	ok(
		r.atordoa_max == 0.5 and r.recarga == 2.6 and perto(float(r.contra_bonus), 0.3, 0.0001) and r.contra_tempo == 1.5 and r.eco_pct == 0.0,
		"resumo(): atordoa, recarga, contragolpe e eco"
	)
	var linha: String = rp.linha()
	ok(
		linha.begins_with("Ruptura (E): dano 10 a 22 | raio 56 a 96 px | recarga 2,6 s | atordoa 0,25 a 0,5 s | contragolpe +30% por 1,5 s | eco 0%"),
		"linha(): %s" % linha
	)

	# 26. fim a fim com o evento do mouse de verdade (parse_input_event) e a posse por polling
	zerar()
	h.entrada_forcada = null
	h.fonte = Heroi.Fonte.MOUSE
	var m26 = monstro_a(50)
	Input.parse_input_event(evento_direito(true))
	await get_tree().process_frame
	passos(3)
	ok(h.estado == Heroi.Estado.CARGA, "o clique direito de verdade inicia a carga")
	passos(25)
	Input.parse_input_event(evento_direito(false))
	await get_tree().process_frame
	passos(2)
	ok(h.rup_disparos == 1 and m26.acertos == 1 and h.estado == Heroi.Estado.LIVRE, "soltar o botão dispara (disparos %d)" % h.rup_disparos)
	h.entrada_forcada = Vector2.ZERO
	# o clique esquerdo não aciona a ruptura
	h.rup_disparos = 0
	h.rup_recarga = 0.0
	h.entrada_forcada = null
	var esq_ev := InputEventMouseButton.new()
	esq_ev.button_index = MOUSE_BUTTON_LEFT
	esq_ev.pressed = true
	w._input(esq_ev)
	ok(h.rup_pedido_t == 0.0, "o clique esquerdo não pede a ruptura")
	esq_ev = InputEventMouseButton.new()
	esq_ev.button_index = MOUSE_BUTTON_LEFT
	esq_ev.pressed = false
	w._input(esq_ev)
	h.entrada_forcada = Vector2.ZERO

	# 26b. o gatilho esquerdo do controle (movimento analógico): só a borda do aperto conta e a posse vem do polling
	zerar()
	h.entrada_forcada = null
	h.fonte = Heroi.Fonte.MOUSE
	var m26b = monstro_a(50)
	Input.parse_input_event(evento_gatilho(1.0))
	await get_tree().process_frame
	passos(3)
	ok(h.estado == Heroi.Estado.CARGA, "o gatilho esquerdo inicia a carga")
	passos(25)
	passos(1)
	ok(h.estado == Heroi.Estado.CARGA, "o LB segurado mantém a carga")
	Input.parse_input_event(evento_gatilho(0.0))
	await get_tree().process_frame
	passos(2)
	ok(h.rup_disparos == 1 and m26b.acertos == 1, "soltar o gatilho dispara (disparos %d)" % h.rup_disparos)
	var sons0: int = w.combate.audio.tocados
	Input.parse_input_event(evento_gatilho(1.0))  # na recarga: negado uma vez só
	await get_tree().process_frame
	passos(3)
	ok(
		h.rup_nega_t > 0.0 and w.combate.audio.tocados == sons0 + 1,
		"gatilho segurado na recarga: o 'negado' toca uma vez (%d sons)" % (w.combate.audio.tocados - sons0)
	)
	Input.parse_input_event(evento_gatilho(0.0))
	await get_tree().process_frame
	h.entrada_forcada = Vector2.ZERO

	# 26c. a entrada como a janela entrega (ESC no meio da carga, clique direito no menu de pausa e na trava das cartas e do baú)
	await _janela()

	# 26d. a ruptura vale para qualquer herói e cada um pode ter a sua pelos dados (herois > chave por cima da base, par a par)
	zerar()
	var chave0: String = h.chave
	ok(rp.trocas is Dictionary and rp.trocas.is_empty(), "nenhum herói tem troca nos dados por enquanto (todos usam a base)")
	rp.trocas["teste_forte"] = {"raio": [100, 200], "recarga": 3.0, "perfeito": {"dano": 2.0}, "contragolpe": {"tempo": 2.5}}
	h.chave = "teste_forte"
	passos(2)  # o quadro dos efeitos pega a chave do herói
	ok(perto(rp.raio_de(h, 1.0, false), 200.0, 0.01) and perto(rp.raio_de(h, 0.0, false), 100.0, 0.01), "a troca do herói muda o par do raio (100 a 200)")
	ok(perto(rp.recarga_de(false), 3.0, 0.001), "a troca muda um número solto (recarga 3,0)")
	ok(
		perto(float(rp.cfg.perfeito.dano), 2.0, 0.001) and perto(float(rp.cfg.perfeito.raio), 1.15, 0.001),
		"um bloco troca só as chaves que a troca traz (perfeito.dano 2,0 e perfeito.raio continua 1,15)"
	)
	ok(perto(float(rp.cfg.contragolpe.tempo), 2.5, 0.001) and perto(float(rp.cfg.contragolpe.bonus), 0.3, 0.001), "idem no contragolpe")
	var m26d = monstro_a(150)
	rp.disparar(h, 1.0, false)
	ok(
		m26d.acertos == 1 and perto(h.rup_recarga, 3.0, 0.001) and perto(h.contragolpe_t, 2.5, 0.001),
		"o disparo usa os números do herói (alcance 200, recarga, contragolpe)"
	)
	ok(rp._base.raio[1] == 96 and rp._base.perfeito.dano == 1.25, "a base lida do arquivo não foi alterada pela troca")
	h.chave = chave0
	passos(2)
	ok(perto(rp.raio_de(h, 1.0, false), 96.0, 0.01) and perto(rp.recarga_de(false), 2.6, 0.001), "voltando ao herói de antes, voltam os números da base")
	rp.trocas.erase("teste_forte")

	# 27. medição do alívio do cerco (só imprime e avisa; o equilíbrio é do playtest)
	var base_i := _imunidade(30.0, false, false)
	var perf_i := _imunidade(30.0, true, false)
	var maxi_i := _imunidade(30.0, false, true)
	print("v2_ruptura imunidade_base=%.3f (meta até 0,40) imunidade_perfeita=%.3f imunidade_build_maxima=%.3f (meta até 0,60)" % [base_i, perf_i, maxi_i])
	if base_i > 0.45:
		print("AVISO v2_ruptura: a imunidade da base passou de 0,45 (%.3f): suba recarga_piso ou baixe atordoa_max nos dados" % base_i)
	if maxi_i > 0.60:
		print("AVISO v2_ruptura: a imunidade da build máxima passou de 0,60 (%.3f): suba recarga_piso para 2,2 ou baixe atordoa_max para 0,8" % maxi_i)

	# 28. tempo de um disparo com 100 monstros (só imprime)
	zerar()
	exato()
	for i in 100:
		var a28: float = TAU * float(i) / 100.0
		var rr: float = 30.0 + 40.0 * float(i % 4) / 3.0
		monstro_a(cos(a28) * rr, sin(a28) * rr * 0.62, 99999.0)
	var tempos: Array = []
	for i in 9:
		var t0u := Time.get_ticks_usec()
		rp.disparar(h, 1.0, false)
		tempos.append(Time.get_ticks_usec() - t0u)
		w.combate.fx.limpar()
	tempos.sort()
	var med: int = tempos[4]
	print("v2_ruptura desempenho: disparar() com 100 monstros = %d us (mediana de 9; min %d, max %d; meta 3000 us)" % [med, tempos[0], tempos[8]])
	if med > 3000:
		print("AVISO v2_ruptura: disparar() com 100 monstros levou %d us, acima de 3000 us (só aviso)" % med)
	# um passo do mundo com 100 monstros e a carga ativa
	segurar()
	var ts: Array = []
	for i in 30:
		var t1u := Time.get_ticks_usec()
		w.avancar(PASSO)
		ts.append(Time.get_ticks_usec() - t1u)
	ts.sort()
	print("v2_ruptura desempenho: um passo do mundo com 100 monstros e a ruptura carregando = %d us (mediana de 30)" % ts[15])
	h.cancelar_ruptura(false)

	print("v2_ruptura falhas=%d" % falhas)
	get_tree().quit()


func _mouse_teste() -> Vector2:
	return Vector2(5, 5)  # fora de qualquer linha do menu de pausa


## Um evento como o sistema o entrega: pela viewport raiz (Input.parse_input_event), sem atalho para o mundo, o herói ou as telas.
func _enviar(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _direito(apertado: bool) -> void:
	var e := evento_direito(apertado)
	_enviar(e)


func _tecla(k: Key) -> void:
	for pressionado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionado
		_enviar(e)


## A entrada de verdade com a ruptura (tudo por parse_input_event, com o mundo, o menu de pausa e as telas reais):
##  a) carregando, o ESC abre a pausa; soltar o botão com o menu aberto e voltar depois de um tempo NÃO dispara (salto de relógio);
##  b) o clique direito com o menu aberto é do menu (a função dele lá continua) e não pede a ruptura; o botão segurado quando o menu fecha
##     não carrega sozinho;
##  c) a escolha de melhoria (na trava, depois dela e com o botão segurado quando fecha) e o baú: o clique direito não vaza, não acumula carga
##     e só um aperto NOVO carrega depois.
func _janela() -> void:
	var h = w.heroi
	var pausa = null
	for c in w.ui.get_children():
		if c.has_method("abrir_sair"):
			pausa = c
	ok(pausa != null, "o mundo monta o menu de pausa")
	if pausa == null:
		return
	pausa.mouse_fn = Callable(self, "_mouse_teste")
	get_tree().paused = false
	Input.use_accumulated_input = false

	# a) ESC no meio da carga
	zerar()
	h.entrada_forcada = null
	h.fonte = Heroi.Fonte.MOUSE
	var m_a = monstro_a(50)
	_direito(true)
	passos(20)
	ok(h.estado == Heroi.Estado.CARGA and h.rup_carga > 0.3, "a) o clique direito de verdade carrega")
	_tecla(KEY_ESCAPE)
	ok(pausa.aberto and get_tree().paused, "a) o ESC abre a pausa com a carga aberta")
	_direito(false)  # soltou com o menu aberto: é do menu, o herói não vê
	ok(h.rup_disparos == 0, "a) soltar o botão com o menu aberto não dispara")
	await get_tree().create_timer(0.45, true, false, true).timeout  # tempo real com a árvore pausada
	_tecla(KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused, "a) o ESC fecha a pausa")
	passos(3)
	ok(
		h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0 and h.rup_cancelados == 1 and h.rup_recarga == 0.0 and m_a.acertos == 0,
		"a) ao voltar, o salto de relógio cancelou: sem disparo, sem recarga, ninguém ferido (disparos %d)" % h.rup_disparos
	)

	# b) clique direito dentro do menu de pausa
	zerar()
	h.entrada_forcada = null
	h.fonte = Heroi.Fonte.MOUSE
	_tecla(KEY_ESCAPE)
	ok(pausa.aberto, "b) o ESC abre a pausa (sem carga)")
	_direito(true)
	ok(h.rup_pedido_t == 0.0 and h.estado == Heroi.Estado.LIVRE, "b) e o herói não recebe o aperto")
	_tecla(KEY_ESCAPE)  # fecha com o botão direito ainda segurado
	ok(not pausa.aberto and not get_tree().paused, "b) o ESC fecha a pausa")
	passos(8)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_pedido_t == 0.0 and h.rup_disparos == 0, "b) o botão segurado quando o menu fecha não carrega sozinho")
	_direito(false)
	passos(4)
	ok(h.rup_disparos == 0 and h.rup_recarga == 0.0, "b) soltar depois não dispara nem gasta recarga")
	_direito(true)
	passos(3)
	ok(h.estado == Heroi.Estado.CARGA, "b) um aperto novo carrega")
	passos(12)
	_direito(false)
	passos(2)
	ok(h.rup_disparos == 1, "b) e soltar dispara (disparos %d)" % h.rup_disparos)

	# c) a escolha de melhoria: carga aberta antes, botão segurado durante e depois da trava
	zerar()
	h.entrada_forcada = null
	h.fonte = Heroi.Fonte.MOUSE
	var tl = w.combate.telas
	_direito(true)
	passos(10)
	ok(h.estado == Heroi.Estado.CARGA, "c) carregando antes da escolha")
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	ate(func(): return w.combate.jogo == "escolha", 120)
	ok(tl.escolha_aberta and tl.espera_escolha > 0.0, "c) a escolha abriu, na trava")
	passos(1)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0 and h.rup_recarga == 0.0, "c) a escolha cancelou a carga sem disparar e sem recarga")
	_direito(false)  # solta e aperta DE NOVO durante a trava: descartado, não guarda pedido
	_direito(true)
	ok(h.rup_pedido_t == 0.0 and h.estado == Heroi.Estado.LIVRE and tl.escolha_aberta, "c) na trava o clique direito é descartado")
	passos(4)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_carga_t == 0.0, "c) na trava o botão segurado não acumula carga")
	tl.espera_escolha = 0.0  # a trava passou: o E é a tecla de confirmar da escolha (telas.gd) e passa a escolher
	_direito(false)
	_direito(true)
	ok(h.rup_pedido_t == 0.0, "c) depois da trava o E confirma a carta (como sempre) e não vaza para a ruptura")
	if tl.escolha_aberta:
		w.combate.progresso.escolher(0)
	passos(8)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0 and h.rup_carga_t == 0.0, "c) o botão segurado quando a escolha fecha não recomeça a carga")
	_direito(false)
	passos(4)
	ok(h.rup_disparos == 0 and h.rup_recarga == 0.0, "c) soltar depois não dispara nem gasta recarga")
	_direito(true)
	passos(3)
	ok(h.estado == Heroi.Estado.CARGA, "c) um aperto novo depois da escolha carrega")
	_direito(false)
	passos(2)  # soltou antes da carga mínima: cancela
	zerar()

	# c2) o baú (trava de 1,5 s)
	h.entrada_forcada = null
	h.fonte = Heroi.Fonte.MOUSE
	_direito(true)
	passos(5)
	w.combate.baus.soltar(h.pos + Vector2(8, 0), 1.0, 1)
	ate(func(): return w.combate.jogo == "bau", 240)
	ok(tl.bau_aberto and tl.espera_bau > 0.0, "c) o baú abriu, na trava")
	passos(1)
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0, "c) o baú cancelou a carga sem disparar")
	_direito(false)
	_direito(true)
	passos(3)
	ok(h.rup_pedido_t == 0.0 and h.estado == Heroi.Estado.LIVRE and tl.bau_aberto, "c) no baú o clique direito é descartado e não carrega")
	ate(func(): return tl.bau_pronto, 900)
	tl.espera_bau = 0.0
	_tecla(KEY_ENTER)
	ate(func(): return w.combate.jogo == "jogando", 120)
	passos(8)
	ok(w.combate.jogo == "jogando" and h.estado == Heroi.Estado.LIVRE and h.rup_disparos == 0, "c) o baú fechou e o botão segurado não carrega sozinho")
	_direito(false)
	passos(4)
	ok(h.rup_disparos == 0 and h.rup_recarga == 0.0, "c) soltar depois do baú não dispara")
	h.entrada_forcada = Vector2.ZERO
	get_tree().paused = false


## Fração do tempo SEM nenhum monstro dentro do alcance de contato (corpo do herói + do monstro + 4 px) com 8 cães de vida alta em cerco em
## volta do herói parado, a ruptura apertada assim que fica pronta e segurada até a carga cheia. `perfeito` solta no primeiro quadro cheio
## (dentro da janela); senão solta depois da janela. `maxima` = a build extrema (6 Punhos ligeiros, 4 Pulsos e 3 Estrondos lendários).
func _imunidade(segundos: float, perfeito: bool, maxima: bool) -> float:
	zerar()
	var h = w.heroi
	var cs = w.combate.cartas
	if maxima:
		for i in 6:
			cs.aplicar(cs.montar_carta(cs.definicao("vel_ataque"), 0))
		for i in 4:
			cs.aplicar(cs.montar_carta(cs.definicao("rb_recarga"), 3))
		for i in 3:
			cs.aplicar(cs.montar_carta(cs.definicao("rb_estrondo"), 3))
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		var m = w.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(cos(a), sin(a) * 0.62) * 40.0, true)
		m.vida = 99999.0
		m.vida_max = 99999.0
	passos(120)
	var sem := 0
	var total := int(segundos * 60.0)
	for i in total:
		if h.estado == Heroi.Estado.LIVRE and h.rup_recarga <= 0.0 and not h.ruptura_forcada:
			segurar()
		elif h.estado == Heroi.Estado.CARGA and h.rup_carga >= 1.0 and (perfeito or not h.rup_perfeita):
			soltar()
		w.avancar(PASSO)
		var algum := false
		for m in w.monstros:
			if (m.pos - h.pos).length() <= h.raio + m.raio + 4.0:
				algum = true
				break
		if not algum:
			sem += 1
	soltar()
	return float(sem) / float(total)
