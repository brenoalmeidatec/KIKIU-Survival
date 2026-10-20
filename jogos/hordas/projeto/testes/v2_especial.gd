extends Node
# Teste automático do ESPECIAL de cada herói, a tecla Q (v2/especial.gd, heroi.gd, combate.gd, hud_habilidades.gd, entrada.gd, dados/v2_especial.json):
# dados e entrada (Q e RB = ação ultimate, e o evento dispara o especial), o mapa herói -> id (Hazaki: investida, Nicão: terremoto, Lucas: chuva), e
# para CADA herói numa partida de verdade: nasce com a recarga de começo, o aperto na recarga é negado (slot treme, nada acontece), o aperto com a
# recarga zerada dispara, o herói fica invulnerável e em Estado.ESPECIAL pela duração, o especial causa dano de verdade na horda (os alvos certos,
# nem mais nem menos), entra em recarga cheia, não dispara de novo na recarga e dispara de novo quando ela zera. Também: cada abate encurta a
# recarga (comum, elite), o especial cancela a ruptura e o escudo, não dispara em pausa, sem especial no herói ou com id desconhecido, e o slot Q do
# HUD acende com o especial real. O mundo anda em passos fixos de 1/60 s.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_especial.tscn  (imprime "v2_especial falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const HudHabilidades := preload("res://v2/hud_habilidades.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Um mundo novo com o herói `id` (o mesmo caminho do jogo, sem passar pelo salão).
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


## Mapa sem monstros, herói parado e mortal, sem crítico (o dano fica previsível), mira (mouse) 100 px à direita, especial pronto.
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
	h.m_critico = -1.0
	h.vida = h.vida_max
	h.folego = h.folego_max
	h.cansado = false
	h.invenc = 0.0
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)
	h.esp_recarga = 0.0
	h.esp_nega_t = 0.0


## Um monstro parado (atordoado por muito tempo) e com muita vida, a (dx, dy) do herói.
func monstro_a(dx: float, dy := 0.0, vida := 5000.0):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, dy))
	m.atordoa_t = 60.0
	m.vida = vida
	m.vida_max = vida
	m.emp = Vector2.ZERO
	return m


func perdeu(m) -> float:
	return m.vida_max - m.vida


func _ready() -> void:
	_dados()
	for id in ["hazaki", "nicao", "lucas"]:
		await novo(id)
		if id == "hazaki":
			_entrada()  # as ações da v2 nascem com o mundo
		_comum(id)
	await novo("hazaki")
	_hazaki()
	await novo("nicao")
	_nicao()
	await novo("lucas")
	_lucas()
	await novo("hazaki")
	_revisao_hazaki()
	for id in ["hazaki", "nicao", "lucas"]:
		await novo(id)
		_fim_de_partida(id)
	await novo("hazaki")
	_cancelamentos_e_bordas()
	await novo("hazaki")
	_hud()
	Herois.forcado = ""
	print("v2_especial falhas=%d" % falhas)
	get_tree().quit()


func _dados() -> void:
	var d: Dictionary = Dados.json("v2_especial")
	ok(str(d.get("_ajuda", "")) != "", "v2_especial.json tem _ajuda")
	ok(d.has("padrao") and d.has("herois") and d.has("comum"), "v2_especial.json tem padrao, herois e comum")
	var mapa: Dictionary = d.herois
	ok(mapa.get("hazaki") == "investida" and mapa.get("nicao") == "terremoto" and mapa.get("lucas") == "chuva", "cada herói tem o especial dele")
	for id in ["investida", "terremoto", "chuva"]:
		var b: Dictionary = d.get(id, {})
		ok(b.has("nome") and b.has("rotulo") and b.has("desc") and b.has("cor") and b.has("dur") and b.has("anim"), "bloco %s completo" % id)
		ok(str(b.get("rotulo", "")).length() <= 10, "o rótulo de %s cabe no slot (até 10 letras)" % id)
	var r := float(d.comum.recarga)
	ok(r >= 45.0 and r <= 60.0, "recarga longa, de 45 a 60 s (%s)" % r)


func _entrada() -> void:
	var tem_q := false
	var tem_rb := false
	for ev in InputMap.action_get_events("ultimate"):
		if ev is InputEventKey and ev.physical_keycode == KEY_Q:
			tem_q = true
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			tem_rb = true
	ok(tem_q and tem_rb, "ultimate: tecla Q e RB do controle")


## O que vale para todo herói: recarga de começo, negado, disparo, invulnerável, recarga cheia, sem repetir na recarga e disparando de novo.
func _comum(id: String) -> void:
	var h = w.heroi
	var esp = w.combate.especial
	var b: Dictionary = esp.bloco_de(id)
	ok(not b.is_empty() and h.esp_nome == str(b.nome), "%s: o herói publica o nome do especial (%s)" % [id, h.esp_nome])
	# recém nascido: a recarga de começo
	w.reiniciar()
	ok(h.esp_recarga > 0.0 and h.esp_recarga <= float(esp.comum.recarga), "%s: nasce com a recarga de começo (%s s)" % [id, h.esp_recarga])
	# na recarga: negado
	zerar()
	h.esp_recarga = 20.0
	var alvo = monstro_a(60)
	var disparos0: int = esp.disparos
	ok(not h.especial(), "%s: na recarga o aperto não dispara" % id)
	ok(h.esp_nega_t > 0.0 and h.esp_negados == 1, "%s: o aperto na recarga é negado (o slot treme)" % id)
	passos(5)
	ok(h.estado == Heroi.Estado.LIVRE and esp.disparos == disparos0 and perdeu(alvo) == 0.0, "%s: negado não faz nada" % id)
	# pronto: dispara
	zerar()
	var ring: Array = []
	for i in 12:
		var a := TAU * float(i) / 12.0
		ring.append(monstro_a(cos(a) * 70.0, sin(a) * 70.0 * 0.62))
	ok(h.especial(), "%s: com a recarga zerada o aperto dispara" % id)
	ok(h.estado == Heroi.Estado.ESPECIAL and esp.disparos == disparos0 + 1, "%s: o herói entra em Estado.ESPECIAL" % id)
	ok(h.esp_recarga > 44.0 and h.esp_recarga <= h.esp_recarga_max, "%s: entra em recarga cheia (%s de %s s)" % [id, h.esp_recarga, h.esp_recarga_max])
	# invulnerável durante o especial
	var vida0: float = h.vida
	var m_c = monstro_a(8)
	ok(not h.levar_dano(10.0, m_c.pos, m_c) and h.vida == vida0, "%s: invulnerável durante o especial" % id)
	# não dispara de novo (em andamento nem na recarga)
	ok(not h.especial() and esp.disparos == disparos0 + 1, "%s: não dispara de novo na recarga" % id)
	# dura a dur e volta ao normal
	var n := 0
	while h.estado == Heroi.Estado.ESPECIAL and n < 400:
		passos(1)
		n += 1
	var dur := float(b.dur)
	ok(absf(float(n) * PASSO - dur) < 0.15, "%s: o especial dura ~%s s (durou %s)" % [id, dur, float(n) * PASSO])
	ok(h.estado == Heroi.Estado.LIVRE and not h.esp_invul, "%s: acabou: herói livre e vulnerável de novo" % id)
	passos(80)  # a onda do Nicão ainda corre
	var feridos := 0
	for m in ring:
		if perdeu(m) > 0.0:
			feridos += 1
	if id != "hazaki":  # a investida do Hazaki só fere o que está na faixa e onde ele para (testado em _hazaki)
		ok(feridos >= 10, "%s: o especial feriu a roda de monstros em volta (%d de 12)" % [id, feridos])
	else:
		ok(feridos >= 1, "%s: o especial feriu quem estava no caminho (%d de 12)" % [id, feridos])
	ok(w.combate.dano_causado > 100.0, "%s: causou dano de verdade (%s)" % [id, w.combate.dano_causado])
	# recarga corre sozinha
	var r0: float = h.esp_recarga
	passos(60)
	ok(r0 - h.esp_recarga > 0.8 and r0 - h.esp_recarga < 1.2, "%s: a recarga corre ~1 s por segundo (%s para %s)" % [id, r0, h.esp_recarga])
	ok(not h.especial() and h.esp_negados == 1, "%s: depois do especial, na recarga, o aperto é negado" % id)
	# zerou: dispara de novo
	h.esp_recarga = 0.0
	ok(h.especial() and esp.disparos == disparos0 + 2, "%s: zerada a recarga, dispara de novo" % id)
	passos(3)
	esp.cancelar(h)
	ok(h.estado == Heroi.Estado.LIVRE, "%s: cancelar volta ao normal" % id)
	# cada abate encurta a recarga
	zerar()
	h.esp_recarga = 30.0
	var fraco = monstro_a(120, 0, 1.0)
	w.combate.ferir(fraco, 99999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE, false)
	w.combate.processar_mortes()
	ok(
		absf(h.esp_recarga - (30.0 - float(esp.comum.abate.comum))) < 0.01,
		"%s: um abate comum tira %s s da recarga (%s)" % [id, esp.comum.abate.comum, h.esp_recarga]
	)
	var elite = monstro_a(130, 0, 1.0)
	elite.elite = true
	h.esp_recarga = 30.0
	w.combate.ferir(elite, 99999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE, false)
	w.combate.processar_mortes()
	ok(absf(h.esp_recarga - (30.0 - float(esp.comum.abate.elite))) < 0.01, "%s: um abate de elite tira %s s (%s)" % [id, esp.comum.abate.elite, h.esp_recarga])
	var ultimo = monstro_a(140, 0, 1.0)
	h.esp_recarga = 0.1
	w.combate.ferir(ultimo, 99999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE, false)
	w.combate.processar_mortes()
	ok(h.esp_recarga == 0.0, "%s: o abate que zera a recarga deixa o especial pronto" % id)


## Hazaki: a investida atravessa e corta a faixa à frente e fecha com um corte em cruz onde para; o que ficou para trás não é ferido.
func _hazaki() -> void:
	var h = w.heroi
	zerar()
	var frente = monstro_a(120)  # no meio da faixa
	var fim = monstro_a(235, 30)  # perto de onde o herói para
	var atras = monstro_a(-70)
	var lado = monstro_a(120, 90)  # fora da faixa e longe de onde ele para
	var p0: Vector2 = h.pos
	ok(h.especial(), "hazaki: dispara")
	passos(70)
	ok((h.pos - p0).x > 150.0, "hazaki: avançou na direção da mira (%s px)" % (h.pos - p0).x)
	ok(perdeu(frente) > 30.0, "hazaki: a faixa corta quem está à frente (%s)" % perdeu(frente))
	ok(perdeu(fim) > 30.0, "hazaki: o corte em cruz pega quem está onde ele para (%s)" % perdeu(fim))
	ok(perdeu(atras) == 0.0 and perdeu(lado) == 0.0, "hazaki: quem ficou para trás ou fora da faixa não é ferido")
	ok(w.combate.especial.ultimo.get("id") == "investida", "hazaki: o último especial foi a investida")


## Revisão do PR 351: o corte final sai onde o herói parou de verdade (em qualquer passo de tempo) e o limite de números não passa de um Q para o outro.
func _revisao_hazaki() -> void:
	var h = w.heroi
	var esp = w.combate.especial
	for dt in [1.0 / 20.0, 1.0 / 45.0, 1.0 / 30.0, 1.0 / 60.0]:
		zerar()
		var p0: Vector2 = h.pos
		var borda = monstro_a(330)  # na linha da mira, a ~90 px de onde ele para (raio do corte final: 100) e além do alcance da faixa no último passo
		ok(h.especial(), "revisão: dispara (dt %s)" % dt)
		for i in int(ceil(1.0 / dt)):
			w.avancar(dt)
		ok((h.pos - p0).x > 235.0, "revisão: parou na distância cheia (dt %s, %s px)" % [dt, (h.pos - p0).x])
		ok(perdeu(borda) > 30.0, "revisão: o corte final pega quem está na borda do raio em volta da parada (dt %s, perdeu %s)" % [dt, perdeu(borda)])
	# dois Q seguidos contra vários alvos: os dois mostram números
	zerar()
	var inicio: Vector2 = h.pos
	for i in 14:
		monstro_a(250.0 + cos(i) * 60.0, sin(i) * 60.0)
	ok(h.especial(), "revisão: primeiro Q")
	passos(60)
	ok(esp._numeros >= int(esp.comum.numeros_max), "revisão: o primeiro Q gastou o limite de números (%s)" % esp._numeros)
	passos(40)
	h.definir_pos(inicio)  # volta ao começo: o fim da faixa andável está perto de onde o primeiro Q parou
	h.esp_recarga = 0.0
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	for i in 3:
		monstro_a(50.0 + i * 40.0)
	ok(h.especial(), "revisão: segundo Q")
	ok(esp._numeros == 0, "revisão: o segundo Q começa sem herdar o limite do primeiro (%s)" % esp._numeros)
	passos(15)
	ok(esp._numeros > 0, "revisão: o segundo Q também mostra números (%s)" % esp._numeros)
	esp._numeros = 5
	esp.limpar()
	ok(esp._numeros == 0, "revisão: limpar zera os números")


## Acabar a partida (vitória; no Hazaki também a derrota) com o Q ativo desfaz estado, invulnerabilidade e onda.
func _fim_de_partida(id: String) -> void:
	var h = w.heroi
	var esp = w.combate.especial
	zerar()
	ok(h.especial(), "fim de partida: %s dispara" % id)
	passos(40 if id == "nicao" else 12)
	ok(h.estado == Heroi.Estado.ESPECIAL and h.esp_invul, "fim de partida: %s está no especial" % id)
	if id == "nicao":
		ok(esp._onda_t >= 0.0, "fim de partida: a onda do terremoto está no ar")
	w.combate.vitoria()
	ok(h.estado != Heroi.Estado.ESPECIAL and not h.esp_invul and esp._id == "", "fim de partida: %s sai do especial na vitória" % id)
	ok(esp._onda_t < 0.0, "fim de partida: %s sem onda depois da vitória" % id)
	if id == "hazaki":
		zerar()
		ok(h.especial(), "fim de partida: dispara de novo")
		passos(12)
		w.combate.heroi_morreu()
		ok(h.estado != Heroi.Estado.ESPECIAL and not h.esp_invul and esp._id == "", "fim de partida: sai do especial na derrota")


## Nicão: a batida fere e empurra quem está perto, a onda de choque fere quem está longe depois, e quem está fora de tudo não é ferido.
func _nicao() -> void:
	var h = w.heroi
	zerar()
	var perto = monstro_a(60)
	var longe = monstro_a(230)
	var fora = monstro_a(420)
	var fraco = monstro_a(0, 70, 5.0)  # morre na batida
	var esp = w.combate.especial
	var abates0: int = w.abates
	ok(h.especial(), "nicão: dispara")
	passos(18)  # a marreta ainda está no ar
	ok(perdeu(perto) == 0.0, "nicão: a marreta sobe antes de bater (%s)" % perdeu(perto))
	passos(24)  # 0,7 s: bateu, a onda ainda não chegou longe
	ok(perdeu(perto) > 60.0, "nicão: a batida fere forte quem está perto (%s)" % perdeu(perto))
	ok(perdeu(longe) == 0.0 and esp.ondas == 1, "nicão: a onda de choque saiu e ainda não alcançou quem está longe")
	ok(perto.pos.x > h.pos.x + 60.0 or perto.emp.x > 20.0, "nicão: a batida empurra para fora")
	passos(50)
	ok(perdeu(longe) > 30.0, "nicão: a onda de choque fere quem estava longe (%s)" % perdeu(longe))
	ok(perdeu(fora) == 0.0, "nicão: quem está fora do alcance não é ferido")
	ok(not fraco.vivo and w.abates > abates0, "nicão: a batida mata quem tem pouca vida (abates %d)" % (w.abates - abates0))
	ok(esp.ultimo.get("mortes", 0) >= 1, "nicão: o especial conta a morte")


## Lucas: a tempestade solta adagas em todas as direções e fere os monstros em volta, sem sair do lugar de graça.
func _lucas() -> void:
	var h = w.heroi
	zerar()
	var ring: Array = []
	for i in 8:
		var a := TAU * float(i) / 8.0
		ring.append(monstro_a(cos(a) * 110.0, sin(a) * 110.0 * 0.62))
	var fora = monstro_a(600)
	var adagas = w.combate.adagas
	var lancadas0: int = adagas.lancadas
	ok(h.especial(), "lucas: dispara")
	passos(30)
	ok(adagas.lancadas - lancadas0 >= 20, "lucas: as adagas começam a sair (%d)" % (adagas.lancadas - lancadas0))
	passos(120)
	var feridos := 0
	for m in ring:
		if perdeu(m) > 0.0:
			feridos += 1
	ok(feridos >= 7, "lucas: as adagas ferem a roda de monstros em volta (%d de 8)" % feridos)
	ok(adagas.lancadas - lancadas0 >= 100, "lucas: mais de 100 adagas no total (%d)" % (adagas.lancadas - lancadas0))
	ok(perdeu(fora) == 0.0, "lucas: quem está além do alcance não é ferido")
	# anda devagar durante o especial
	zerar()
	h.entrada_forcada = Vector2(-1, 0)
	var p0: Vector2 = h.pos
	ok(h.especial(), "lucas: dispara andando")
	passos(30)
	var andou: float = absf((h.pos - p0).x)
	var livre: float = h.vel_andar() * 0.5
	ok(andou > 2.0 and andou < livre * 0.6, "lucas: anda devagar durante o especial (%s px em 0,5 s)" % andou)


func _cancelamentos_e_bordas() -> void:
	var h = w.heroi
	var esp = w.combate.especial
	# o evento do Q dispara (o mesmo caminho do teclado e do controle)
	zerar()
	var ev := InputEventAction.new()
	ev.action = "ultimate"
	ev.pressed = true
	h.entrada_evento(ev)
	ok(h.estado == Heroi.Estado.ESPECIAL, "o evento da ação ultimate dispara o especial")
	esp.cancelar(h)
	# cancela a ruptura em carga
	zerar()
	h.ruptura_forcada = true
	h.ruptura()
	passos(10)
	ok(h.estado == Heroi.Estado.CARGA, "a ruptura está carregando")
	ok(h.especial() and h.estado == Heroi.Estado.ESPECIAL, "o especial cancela a ruptura em carga")
	h.ruptura_forcada = false
	esp.cancelar(h)
	# derruba o escudo
	zerar()
	h.escudo_forcado = true
	passos(5)
	ok(h.escudo_ativo, "o escudo está erguido")
	ok(h.especial() and not h.escudo_ativo, "o especial derruba o escudo")
	h.escudo_forcado = false
	esp.cancelar(h)
	# pausa: não dispara
	zerar()
	w.combate.pausado = true
	ok(not h.especial() and h.estado == Heroi.Estado.LIVRE, "com o jogo pausado o especial não dispara")
	w.combate.pausado = false
	# morto: não dispara
	zerar()
	var vida: float = h.vida
	h.vida = 0.0
	h.estado = Heroi.Estado.MORTO
	ok(not h.especial(), "morto, o especial não dispara")
	h.estado = Heroi.Estado.LIVRE
	h.vida = vida
	# herói sem especial (id desconhecido): a tecla Q não faz nada
	zerar()
	esp.herois["teste_sem"] = "nao_existe"
	ok(esp.id_de("teste_sem") == "" and esp.id_de("hazaki") == "investida", "id desconhecido não tem especial; os outros ficam com o deles")
	esp.herois.erase("teste_sem")
	h.esp_nome = ""
	ok(not h.especial() and h.estado == Heroi.Estado.LIVRE, "sem especial no herói, a tecla Q não faz nada")
	esp.armar(h)
	ok(h.esp_nome != "", "armar devolve o nome do especial")
	# partida nova: recarga de começo de novo e nada em andamento
	zerar()
	ok(h.especial(), "dispara")
	w.reiniciar()
	ok(h.estado == Heroi.Estado.LIVRE and h.esp_recarga > 0.0 and not h.esp_invul, "reiniciar cancela o especial e rearma a recarga de começo")


func _hud() -> void:
	var h = w.heroi
	var slots = HudHabilidades.new()
	zerar()
	h.esp_recarga = 0.0
	slots.sincronizar(h)
	ok(slots.q_implementada and slots.q_pronta, "HUD: o slot Q acende com o especial pronto")
	ok(slots._rotulo_q() == h.esp_rotulo and slots.q_cor == h.esp_cor, "HUD: o slot mostra o rótulo e a cor do especial")
	h.esp_recarga = h.esp_recarga_max * 0.5
	slots.sincronizar(h)
	ok(
		not slots.q_pronta and slots.q_recarga_px == 10 and slots._rotulo_q() == "%d S" % ceili(h.esp_recarga),
		"HUD: em recarga mostra a cortina (%d/20) e os segundos" % slots.q_recarga_px
	)
	h.esp_nega_t = 0.2
	slots.sincronizar(h)
	ok(slots.q_negada, "HUD: o aperto negado treme o slot")
	var sem = Node.new()  # um herói sem os campos do especial (a main): o slot fica apagado, sem disponibilidade falsa
	slots.sincronizar(sem)
	ok(not slots.q_implementada and slots._rotulo_q() == "EM BREVE", "HUD: sem os campos do herói, Q fica apagada (EM BREVE)")
	sem.free()
	slots.free()
