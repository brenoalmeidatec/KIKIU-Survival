extends Node
# Teste automático do ULTIMATE da tecla Q (v2/ultimate.gd, heroi.gd, combate.gd, dados/v2_ultimate.json): dados e mapeamento herói -> id, a carga que
# enche com dano causado (golpe e golpe secundário) e com abates mas NÃO com o tempo parado, o teto de 100, Q com a carga abaixo de 100 (nada) e com 100
# (ativa), o Corte do Crepúsculo (dura 6 s do mundo, alcance x1,8, dano x1,6, onda que atravessa, sem empurrão, combo que não reinicia por demora),
# o hit-stop e a câmera lenta ao ativar, a carga que zera ao usar, ao morrer e ao reiniciar, e que sobrevive à escolha de cartas e à pausa.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_ultimate.tscn  (imprime "v2_ultimate falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func perto(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Começa de novo: mapa sem monstros, herói parado e imortal, de cara para a direita (mouse 100 px à direita), sem carga.
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = false
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = null
	h.correr_forcado = null
	h.ruptura_forcada = false
	h.escudo_forcado = false
	h.m_vel_mov = 1.0
	h.vida = h.vida_max
	h.folego = h.folego_max
	h.cansado = false
	h.invenc = 0.0
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)


func monstro_a(dx: float, dy := 0.0, vida := 100000.0):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, dy))
	m.atordoa_t = 0.0
	m.vida = vida
	m.vida_max = vida
	m.emp = Vector2.ZERO
	return m


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var h = w.heroi
	var c = w.combate
	var u = c.ultimate
	ok(u != null and u.no != null, "o combate tem o módulo do ultimate")

	# 1. dados, mapeamento por herói e entrada
	var d: Dictionary = Dados.json("v2_ultimate")
	ok(str(d.get("_ajuda", "")) != "", "v2_ultimate.json tem _ajuda")
	ok(d.has("herois") and d.has("carga") and d.has("corte_do_crepusculo"), "v2_ultimate.json tem herois, carga e o bloco do Corte do Crepúsculo")
	var b: Dictionary = d.corte_do_crepusculo
	ok(float(b.dur) == 6.0 and float(b.alcance) == 1.8 and float(b.dano) == 1.6, "6 s, alcance x1,8 e dano x1,6 nos dados")
	ok(u.id_de("hazaki") == "corte_do_crepusculo" and u.tem("hazaki"), "o Hazaki tem o Corte do Crepúsculo")
	ok(not u.tem("nicao") and not u.tem("lucas"), "herói sem linha nos dados não tem ultimate (Nicão e Lucas entram só com dados)")
	var tem_q := false
	var tem_rb := false
	for ev in InputMap.action_get_events("ultimate"):
		if ev is InputEventKey and ev.physical_keycode == KEY_Q:
			tem_q = true
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			tem_rb = true
	ok(tem_q and tem_rb, "ultimate: tecla Q e RB do controle")

	# 2. a carga enche com DANO e abates, não com o tempo
	zerar()
	ok(u.carga == 0.0 and not u.pronto() and not u.ativo(), "partida nova: sem carga")
	passos(1800)  # 30 s parado
	ok(u.carga == 0.0, "parado, a carga não enche com o tempo (%.2f)" % u.carga)
	var m1 = monstro_a(30)
	h.ataque_forcado = true
	passos(90)
	h.ataque_forcado = null
	ok(h.golpes >= 1 and u.carga > 0.0, "golpear enche a carga (%.2f)" % u.carga)
	var depois_golpe: float = u.carga
	ok(h.ult_carga > 0.0 and perto(h.ult_carga, depois_golpe / 100.0, 0.001), "o herói publica a carga (0 a 1) para o HUD")
	passos(600)
	ok(u.carga == depois_golpe, "depois de golpear, parar não muda a carga")
	var antes: float = u.carga
	c.ferir(m1, 200.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)  # golpe secundário (armas, ruptura) também conta
	ok(u.carga > antes, "o dano de arma/ruptura (ferir) também enche")
	zerar()
	var m2 = monstro_a(40, 0.0, 10.0)
	var a0: float = u.carga
	c.ferir(m2, 5000.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)  # 5000 de dano em 10 de vida: só os 10 contam
	passos(1)
	ok(perto(u.carga - a0, 10.0 * float(d.carga.por_dano) + float(d.carga.por_abate), 0.05), "só o dano real conta e o abate soma um pouco (%.3f)" % (u.carga - a0))
	# o teto de 100
	u.carga = 99.9
	u.dano_causado(100000.0)
	u.dano_causado(100000.0)
	ok(u.carga == 100.0 and h.ult_carga == 1.0 and h.ult_pronto, "a carga não passa de 100 e fica pronta")
	zerar()
	u.dano_causado(1.0e9)
	ok(u.carga <= float(d.carga.max_por_acerto) + 0.001, "um acerto gigante respeita max_por_acerto")
	# herói sem ultimate não carrega
	zerar()
	h.chave = "outro_heroi"
	u.dano_causado(1000.0)
	ok(u.carga == 0.0, "herói sem ultimate não carrega")
	ok(not h.ultimate(), "Q sem ultimate não faz nada")
	h.chave = "hazaki"

	# 3. Q com a carga abaixo de 100 não faz nada
	zerar()
	u.carga = 99.0
	ok(not h.ultimate() and not u.ativo() and u.carga == 99.0 and u.usos == 0, "Q com 99 não dispara e não gasta carga")
	var ev := InputEventAction.new()
	ev.action = "ultimate"
	ev.pressed = true
	h.entrada_evento(ev)
	ok(not u.ativo() and u.carga == 99.0, "o aperto de Q (evento) com 99 também não faz nada")

	# 4. Q com 100 ativa (pelo evento de entrada)
	var vida_antes_t: float = w.tempo_partida
	u.carga = 100.0
	var k_antes: float = c.alcance_do_passo(c.cfg.golpe.passos[0])
	var d_antes: float = c.dano_do_passo(c.cfg.golpe.passos[0])
	var parou: int = c.hit_stops
	h.entrada_evento(ev)
	ok(u.ativo() and u.usos == 1, "Q com 100 ativa o Corte do Crepúsculo")
	ok(u.carga == 0.0 and h.ult_carga == 0.0 and h.ult_ativo and not h.ult_pronto, "a carga zera ao usar e o herói publica 'ativo'")
	ok(perto(u.ativo_t, 6.0, 0.01), "dura 6 s (%.2f)" % u.ativo_t)
	ok(c.hit_stops > parou and c.parada_t > 0.0, "ao ativar: hit-stop")
	ok(c.lento_t > 0.0 and perto(c.lento_t, 0.3, 0.05) and c.lento_escala < 1.0, "ao ativar: câmera lenta de 0,3 s")
	ok(perto(c.alcance_do_passo(c.cfg.golpe.passos[0]), k_antes * 1.8, 0.01), "alcance x1,8")
	ok(perto(c.dano_do_passo(c.cfg.golpe.passos[0]), d_antes * 1.6, 0.01), "dano x1,6")
	h.entrada_evento(ev)
	ok(u.usos == 1, "Q de novo com o ultimate ativo (e sem carga) não dispara outra vez")
	u.carga = 100.0
	ok(not h.ultimate() and u.usos == 1, "com o ultimate ativo, mesmo cheia a carga não dispara de novo")
	u.carga = 0.0
	# 5. enquanto ativo, a carga não enche
	var m3 = monstro_a(30)
	h.ataque_forcado = true
	passos(60)
	h.ataque_forcado = null
	ok(u.carga == 0.0, "com o ultimate ativo, o dano não enche a carga")
	m3.vida = 0.0
	c.matar(m3)
	ok(u.carga == 0.0, "com o ultimate ativo, o abate não enche a carga")
	# 6. a duração corre no tempo do mundo: 6 s
	var t0: float = w.tempo_partida
	var n := 0
	while u.ativo() and n < 2000:
		passos(1)
		n += 1
	ok(not u.ativo() and not h.ult_ativo, "o ultimate termina")
	var dur_mundo: float = w.tempo_partida - t0
	ok(perto(dur_mundo, 6.0, 0.35), "6 s de tempo do mundo (%.2f, descontado o começo)" % dur_mundo)
	ok(perto(c.alcance_do_passo(c.cfg.golpe.passos[0]), k_antes, 0.01), "depois do fim o alcance volta ao normal")
	ok(perto(c.dano_do_passo(c.cfg.golpe.passos[0]), d_antes, 0.01), "depois do fim o dano volta ao normal")
	ok(vida_antes_t >= 0.0, "relógio ok")

	# 7. o alcance de verdade: um monstro a 75 px só apanha com o ultimate
	zerar()
	var m4 = monstro_a(78)
	h.ataque_forcado = true
	passos(40)
	h.ataque_forcado = null
	ok(m4.vida >= 99999.0, "sem o ultimate o golpe não alcança um monstro a 78 px (vida %.0f)" % m4.vida)
	zerar()
	u.carga = 100.0
	ok(h.ultimate(), "ativou para o teste de alcance")
	var m5 = monstro_a(78)
	h.ataque_forcado = true
	passos(120)
	h.ataque_forcado = null
	ok(m5.vida < 100000.0, "com o ultimate o golpe alcança um monstro a 78 px (vida %.0f)" % m5.vida)

	# 8. a onda em linha atravessa: dois monstros em fila, o de trás fora do alcance do golpe
	zerar()
	u.carga = 100.0
	h.ultimate()
	var perto_m = monstro_a(40)
	var longe_m = monstro_a(150)
	h.ataque_forcado = true
	passos(90)
	h.ataque_forcado = null
	ok(u.ondas >= 1, "o golpe solta uma onda (%d)" % u.ondas)
	ok(perto_m.vida < 100000.0 and longe_m.vida < 100000.0, "a onda atravessa e acerta o monstro de trás (%.0f / %.0f)" % [perto_m.vida, longe_m.vida])
	zerar()
	var m6 = monstro_a(40)
	var m7 = monstro_a(150)
	h.ataque_forcado = true
	passos(90)
	h.ataque_forcado = null
	ok(m6.vida < 100000.0 and m7.vida >= 100000.0 and u.ondas == 0, "sem o ultimate: nenhuma onda e o monstro de trás não apanha")

	# 9. imune a empurrão (não a dano)
	zerar()
	u.carga = 100.0
	h.ultimate()
	var v0: float = h.vida
	var m8 = monstro_a(-10)
	ok(h.levar_dano(10.0, m8.pos, m8), "levar dano devolve verdadeiro")
	ok(h.vida < v0 and h.emp == Vector2.ZERO, "ativo: leva o dano e não leva o empurrão (emp %s)" % str(h.emp))
	zerar()
	var v1: float = h.vida
	var m9 = monstro_a(-10)
	h.levar_dano(10.0, m9.pos, m9)
	ok(h.vida < v1 and h.emp.length() > 1.0, "sem o ultimate: leva o empurrão")

	# 10. o combo de 3 não reinicia por demora
	zerar()
	h.proximo = 1
	h.combo_t = float(c.cfg.golpe.janela_combo)
	passos(120)
	ok(h.proximo == 0, "sem o ultimate o combo reinicia depois da janela")
	zerar()
	u.carga = 100.0
	h.ultimate()
	h.proximo = 1
	h.combo_t = float(c.cfg.golpe.janela_combo)
	passos(120)
	ok(h.proximo == 1 and h.combo_t > 0.0, "com o ultimate o combo não reinicia por demora")

	# 11. morrer, reiniciar e voltar zeram; cartas e pausa não
	zerar()
	u.carga = 100.0
	h.ultimate()
	u.carga = 55.0  # (enche_ativo é falso; só para o teste da morte ver a carga)
	h.vida = 1.0
	var mk = monstro_a(-10)
	h.levar_dano(50.0, mk.pos, mk)
	ok(h.estado == Heroi.Estado.MORTO and u.carga == 0.0 and not u.ativo() and not h.ult_ativo, "morrer zera a carga e o ultimate ativo")
	zerar()
	ok(u.carga == 0.0 and not u.ativo(), "reiniciar a partida zera tudo")
	u.carga = 60.0
	w.reiniciar()
	ok(u.carga == 0.0 and h.ult_carga == 0.0, "reiniciar zera a carga e o que o HUD lê")
	u.carga = 60.0
	c.limpar_partida()
	ok(u.carga == 0.0, "limpar a partida (voltar ao santuário e jogar de novo) zera a carga")
	zerar()
	u.carga = 60.0
	h.ultimate()  # 60 < 100: nada
	c.progresso.abrir_escolha()
	ok(c.pausado and c.jogo == "escolha", "a escolha de cartas pausa o jogo")
	passos(120)
	ok(u.carga == 60.0, "abrir as cartas não zera a carga")
	u.carga = 100.0
	ok(not h.ultimate() and u.carga == 100.0, "com as cartas abertas Q não dispara e não gasta a carga")
	c.progresso.escolher(0)
	ok(not c.pausado and u.carga == 100.0, "escolher a carta mantém a carga")
	ok(h.ultimate() and u.ativo(), "depois das cartas Q dispara")
	var restante: float = u.ativo_t
	c.progresso.abrir_escolha()
	passos(120)
	ok(perto(u.ativo_t, restante, 0.001), "o tempo do ultimate ativo não corre com as cartas abertas")
	c.progresso.escolher(0)
	# baú/pausa: pausado = verdadeiro
	zerar()
	u.carga = 80.0
	c.pausado = true
	passos(60)
	c.pausado = false
	ok(u.carga == 80.0, "pausar não mexe na carga")
	zerar()
	u.carga = 100.0
	c.pausado = true
	ok(not h.ultimate(), "em pausa Q não dispara")
	c.pausado = false

	# 12. o painel de status e o resumo
	zerar()
	u.carga = 42.0
	u.dano_causado(0.0)
	var r: Dictionary = u.resumo()
	ok(str(r.nome) == "Corte do Crepúsculo" and int(r.carga) == 42 and not bool(r.pronto), "resumo(): nome e carga")
	u.efeitos(PASSO)

	print("v2_ultimate falhas=%d" % falhas)
	get_tree().quit()
