extends Node
# Teste automático da HABILIDADE de cada herói, a tecla E (v2/habilidade.gd, heroi.gd, combate.gd, hud_habilidades.gd, dados/v2_habilidade.json,
# dados/v2_ruptura.json > cartas): o mapa herói -> id (Hazaki: ruptura, Nicão: investida_escudo, Lucas: salto_adagas), os campos hab_* que o HUD lê, e para
# CADA herói numa partida de verdade: a E nasce pronta, o aperto dispara (a ruptura do Hazaki pelo caminho antigo, segurando; as outras na hora), o herói
# fica invulnerável em Estado.HABILIDADE, a E faz o que diz (Nicão: investe empurrando e atordoando a faixa e fecha com a pancada; Lucas: salta para
# trás soltando dois leques de adagas), entra em recarga por TEMPO (8 a 14 s), o aperto na recarga é negado, a recarga corre sozinha e a E dispara de
# novo. Também: o Q corta a E, a E não dispara em pausa, as cartas da E (dano, recarga, atordoa) valem para qualquer E e Contragolpe/Eco só saem para a
# ruptura, o dano da E enche a carga do Q, e o slot E do HUD mostra o ícone, o rótulo e a recarga da E do herói. O mundo anda em passos fixos de 1/60 s.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_habilidade.tscn  (imprime "v2_habilidade falhas=0")
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


## Mapa sem monstros, herói parado e mortal, sem crítico (o dano fica previsível), mira (mouse) 100 px à direita, E e Q prontos.
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
	h.hab_recarga = 0.0
	h.hab_nega_t = 0.0
	h.rup_recarga = 0.0
	h.esp_carga = 0.0


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
		_publicado(id)
	await novo("hazaki")
	_hazaki()
	await novo("nicao")
	_nicao()
	for id in ["nicao", "lucas"]:
		await novo(id)
		_comum(id)
	await novo("lucas")
	_lucas()
	await novo("nicao")
	_cartas("nicao")
	await novo("hazaki")
	_cartas("hazaki")
	await novo("nicao")
	_bordas()
	for id in ["hazaki", "nicao", "lucas"]:
		await novo(id)
		_hud(id)
	Herois.forcado = ""
	print("v2_habilidade falhas=%d" % falhas)
	get_tree().quit()


func _dados() -> void:
	var d: Dictionary = Dados.json("v2_habilidade")
	ok(str(d.get("_ajuda", "")) != "", "v2_habilidade.json tem _ajuda")
	ok(d.has("padrao") and d.has("herois") and d.has("comum"), "v2_habilidade.json tem padrao, herois e comum")
	var mapa: Dictionary = d.herois
	ok(mapa.get("hazaki") == "ruptura" and mapa.get("nicao") == "investida_escudo" and mapa.get("lucas") == "salto_adagas", "cada herói tem a E dele")
	ok(mapa.get("nicao") != "ruptura" and mapa.get("lucas") != "ruptura", "só um herói tem a ruptura")
	for id in ["ruptura", "investida_escudo", "salto_adagas"]:
		var b: Dictionary = d.get(id, {})
		ok(b.has("nome") and b.has("rotulo") and b.has("desc") and b.has("cor") and b.has("icone"), "bloco %s completo" % id)
		ok(str(b.get("rotulo", "")).length() <= 10, "o rótulo de %s cabe no slot (até 10 letras)" % id)
		ok(Dados.icone_carta(str(b.get("icone", ""))) != null, "o ícone de %s existe (%s)" % [id, b.get("icone", "")])
	for id in ["investida_escudo", "salto_adagas"]:
		var b: Dictionary = d.get(id, {})
		var r := float(b.get("recarga", 0.0))
		ok(r >= 8.0 and r <= 14.0, "recarga curta por tempo, de 8 a 14 s (%s: %s)" % [id, r])
		ok(b.has("dur") and b.has("distancia") and b.has("anim"), "bloco %s traz dur, distancia e anim" % id)
	ok(d.investida_escudo.cor != d.salto_adagas.cor, "as E têm cores diferentes")


## O herói publica a E dele (id, nome, ícone) e ela nasce pronta.
func _publicado(id: String) -> void:
	var h = w.heroi
	var hab = w.combate.habilidade
	var b: Dictionary = hab.bloco_de(id)
	ok(
		h.hab_id == hab.id_de(id) and h.hab_nome == str(b.nome) and h.hab_icone == str(b.icone),
		"%s: o herói publica a E dele (%s, %s)" % [id, h.hab_id, h.hab_nome]
	)
	ok(h.hab_recarga == 0.0 and h.rup_recarga == 0.0, "%s: a E nasce pronta (recarga %s)" % [id, h.hab_recarga])
	ok(hab.e_ruptura(id) == (id == "hazaki"), "%s: só o Hazaki tem a ruptura como E" % id)


## Hazaki: a E é a ruptura de sempre (segurar carrega, soltar dispara), sem tocar o módulo da habilidade nova.
func _hazaki() -> void:
	var h = w.heroi
	var hab = w.combate.habilidade
	zerar()
	var alvo = monstro_a(40)
	ok(not h.habilidade() and h.hab_disparos == 0 and h.estado == Heroi.Estado.LIVRE, "hazaki: a habilidade nova não dispara (a E dele é a ruptura)")
	h.ruptura_forcada = true
	h.ruptura()
	passos(70)
	ok(h.estado == Heroi.Estado.CARGA and h.rup_carga > 0.9, "hazaki: segurar a E carrega a ruptura (carga %s)" % h.rup_carga)
	h.ruptura_forcada = false
	passos(3)
	ok(h.rup_disparos == 1 and h.rup_recarga > 0.0 and perdeu(alvo) > 5.0, "hazaki: soltar dispara a ruptura (dano %s)" % perdeu(alvo))
	ok(hab.disparos == 0, "hazaki: o módulo da habilidade nova não foi usado")


## Nicão: investe para a frente (invulnerável) empurrando e atordoando quem está na faixa, fecha com a pancada; quem ficou para trás ou ao lado não leva.
func _nicao() -> void:
	var h = w.heroi
	var hab = w.combate.habilidade
	zerar()
	var frente = monstro_a(70)  # na faixa
	var frente2 = monstro_a(150, 10)  # na faixa, mais longe
	var fim = monstro_a(225, 0)  # perto de onde ele para (pancada final)
	var atras = monstro_a(-70)
	var lado = monstro_a(120, 120)  # fora da faixa e longe de onde ele para
	frente.atordoa_t = 0.0
	var p0: Vector2 = h.pos
	var disparos0: int = hab.disparos
	h.ruptura()  # o aperto da E (a ação se chama ruptura) chama a habilidade do herói
	ok(h.estado == Heroi.Estado.HABILIDADE and hab.disparos == disparos0 + 1 and h.hab_invul, "nicão: a E entra em Estado.HABILIDADE, invulnerável")
	ok(h.hab_recarga > 9.0 and h.hab_recarga <= h.hab_recarga_max, "nicão: a recarga cheia fica armada (%s de %s s)" % [h.hab_recarga, h.hab_recarga_max])
	ok(h.rup_disparos == 0 and h.estado != Heroi.Estado.CARGA, "nicão: o aperto da E não carrega a ruptura")
	var vida0: float = h.vida
	var m_c = monstro_a(6)
	ok(not h.levar_dano(10.0, m_c.pos, m_c) and h.vida == vida0, "nicão: invulnerável durante a investida")
	var n := 0
	while h.estado == Heroi.Estado.HABILIDADE and n < 200:
		passos(1)
		n += 1
	var dur := float(hab.bloco_de("nicao").dur)
	ok(absf(float(n) * PASSO - dur) < 0.12, "nicão: a investida dura ~%s s (durou %s)" % [dur, float(n) * PASSO])
	ok(h.estado == Heroi.Estado.LIVRE and not h.hab_invul, "nicão: acabou: livre e vulnerável de novo")
	var andou: float = (h.pos - p0).x
	var dist := float(hab.bloco_de("nicao").distancia)
	ok(andou > dist * 0.8 and andou < dist * 1.05, "nicão: avançou ~%s px na direção da mira (%s)" % [dist, andou])
	passos(30)
	ok(perdeu(frente) > 20.0 and perdeu(frente2) > 20.0, "nicão: a faixa fere quem está à frente (%s e %s)" % [perdeu(frente), perdeu(frente2)])
	ok(frente.emp.x > 0.0 or frente.pos.x > p0.x + 70.0, "nicão: empurra a horda para a frente")
	ok(perdeu(fim) > 15.0, "nicão: a pancada final fere quem está onde ele para (%s)" % perdeu(fim))
	ok(perdeu(atras) == 0.0 and perdeu(lado) == 0.0, "nicão: quem ficou para trás ou ao lado não é ferido")
	ok(hab.ultimo.get("id") == "investida_escudo" and hab.ultimo.get("n", 0) >= 3, "nicão: a E conta os atingidos (%s)" % str(hab.ultimo))
	# atordoa: o monstro da frente ficou atordoado
	ok(frente.atordoa_t > 0.3, "nicão: atordoa quem a faixa pega (%s s)" % frente.atordoa_t)


## O que vale para as E novas (Nicão e Lucas): recarga por tempo, negado, de novo, o Q corta a E, nada em pausa, a E enche a carga do Q.
func _comum(id: String) -> void:
	var h = w.heroi
	var hab = w.combate.habilidade
	var b: Dictionary = hab.bloco_de(id)
	zerar()
	var alvo = monstro_a(60, 0, 5000.0)
	var disparos0: int = hab.disparos
	ok(h.habilidade(), "%s: com a E pronta o aperto dispara" % id)
	var rmax: float = h.hab_recarga_max
	ok(rmax >= 8.0 and rmax <= 14.0 and absf(h.hab_recarga - rmax) < 0.01, "%s: a recarga armada é de 8 a 14 s (%s)" % [id, rmax])
	# durante a E não dispara de novo nem conta como negado
	ok(not h.habilidade() and hab.disparos == disparos0 + 1, "%s: não dispara de novo durante a E" % id)
	var n := 0
	while h.estado == Heroi.Estado.HABILIDADE and n < 200:
		passos(1)
		n += 1
	ok(h.hab_recarga > rmax - 0.05, "%s: a recarga só começa a correr depois da E (%s de %s)" % [id, h.hab_recarga, rmax])
	# negado na recarga
	ok(not h.habilidade() and h.hab_negados == 1 and h.hab_nega_t > 0.0, "%s: na recarga o aperto é negado (o slot treme)" % id)
	ok(h.estado == Heroi.Estado.LIVRE, "%s: negado não faz nada" % id)
	# a recarga corre por TEMPO
	var r0: float = h.hab_recarga
	passos(60)
	ok(r0 - h.hab_recarga > 0.9 and r0 - h.hab_recarga < 1.1, "%s: a recarga corre ~1 s por segundo (%s para %s)" % [id, r0, h.hab_recarga])
	passos(int(rmax * 60.0))
	ok(h.hab_recarga == 0.0, "%s: depois de %s s a E está pronta de novo" % [id, rmax])
	ok(h.habilidade() and hab.disparos == disparos0 + 2, "%s: pronta, dispara de novo" % id)
	passos(3)
	hab.cancelar(h)
	ok(h.estado == Heroi.Estado.LIVRE and not h.hab_invul, "%s: cancelar volta ao normal" % id)
	# o Q corta a E em andamento
	zerar()
	h.esp_carga = h.esp_carga_max
	ok(h.habilidade() and h.estado == Heroi.Estado.HABILIDADE, "%s: E em andamento" % id)
	passos(5)
	ok(h.especial() and h.estado == Heroi.Estado.ESPECIAL, "%s: o Q corta a E e entra" % id)
	ok(not h.habilidade(), "%s: durante o Q a E não dispara" % id)
	w.combate.especial.cancelar(h)
	# pausa: não dispara
	zerar()
	w.combate.pausado = true
	ok(not h.habilidade() and h.estado == Heroi.Estado.LIVRE, "%s: com o jogo pausado a E não dispara" % id)
	w.combate.pausado = false
	# morto: não dispara
	zerar()
	h.estado = Heroi.Estado.MORTO
	ok(not h.habilidade(), "%s: morto, a E não dispara" % id)
	h.estado = Heroi.Estado.LIVRE
	# o dano da E carrega a ultimate (a do Nicão fere a faixa; a do Lucas, as adagas): só fora do Q
	zerar()
	monstro_a(80)
	monstro_a(140, 8)
	monstro_a(-120 if id == "lucas" else 210, 0)
	ok(h.habilidade(), "%s: dispara para provar a carga do Q" % id)
	passos(70)
	ok(h.esp_carga > 0.0, "%s: o dano da E enche a carga do Q (%s)" % [id, h.esp_carga])
	ok(b.has("nome"), "%s: bloco da E" % id)


## Lucas: salta para trás (contra a mira) soltando um leque na decolagem e outro no pouso; as adagas ferem quem está à frente.
func _lucas() -> void:
	var h = w.heroi
	var hab = w.combate.habilidade
	var adagas = w.combate.adagas
	zerar()
	var frente = monstro_a(120)
	var frente2 = monstro_a(200, 0)  # na mesma linha: a adaga do meio fura o primeiro e chega nele
	var lado = monstro_a(0, 200)  # fora do leque (a ~50 graus da mira de onde ele pousa)
	var fora = monstro_a(700)
	var p0: Vector2 = h.pos
	var lancadas0: int = adagas.lancadas
	h.ruptura()  # o aperto da E (a ação se chama ruptura) chama a habilidade do herói
	ok(h.estado == Heroi.Estado.HABILIDADE and h.hab_invul, "lucas: a E entra em Estado.HABILIDADE, invulnerável")
	var saida := int(hab.bloco_de("lucas").saida.n)
	ok(adagas.lancadas - lancadas0 >= saida, "lucas: o primeiro leque sai na decolagem (%d adagas)" % (adagas.lancadas - lancadas0))
	var vida0: float = h.vida
	var m_c = monstro_a(-6)  # atrás: a adaga do meio não fura ele antes dos alvos da frente
	ok(not h.levar_dano(10.0, m_c.pos, m_c) and h.vida == vida0, "lucas: invulnerável durante o salto")
	var n := 0
	while h.estado == Heroi.Estado.HABILIDADE and n < 200:
		passos(1)
		n += 1
	var dur := float(hab.bloco_de("lucas").dur)
	ok(absf(float(n) * PASSO - dur) < 0.12, "lucas: o salto dura ~%s s (durou %s)" % [dur, float(n) * PASSO])
	var dx: float = (h.pos - p0).x
	var dist := float(hab.bloco_de("lucas").distancia)
	ok(dx < -dist * 0.8 and dx > -dist * 1.05, "lucas: saltou ~%s px PARA TRÁS, contra a mira (%s)" % [dist, dx])
	var pouso := int(hab.bloco_de("lucas").pouso.n)
	ok(adagas.lancadas - lancadas0 >= saida + pouso, "lucas: o segundo leque sai no pouso (%d adagas no total)" % (adagas.lancadas - lancadas0))
	passos(60)
	ok(perdeu(frente) > 5.0 and perdeu(frente2) > 0.0, "lucas: as adagas ferem quem está à frente (%s e %s)" % [perdeu(frente), perdeu(frente2)])
	ok(perdeu(lado) == 0.0 and perdeu(fora) == 0.0, "lucas: quem está fora do leque não é ferido")
	ok(h.dir_olhar.x > 0.5, "lucas: olha para a mira durante o salto, não para onde salta (%s)" % h.dir_olhar)
	# a mira para o outro lado inverte o salto
	zerar()
	w.mouse_forcado = h.centro() + Vector2(-100, 0)
	passos(2)
	var q0: Vector2 = h.pos
	ok(h.habilidade(), "lucas: dispara mirando para a esquerda")
	passos(30)
	ok((h.pos - q0).x > dist * 0.8, "lucas: mirando para a esquerda salta para a direita (%s)" % (h.pos - q0).x)


## As cartas da E: dano, recarga e atordoa valem para qualquer E; Contragolpe e Eco do chão só saem para quem tem a ruptura.
func _cartas(id: String) -> void:
	var h = w.heroi
	var hab = w.combate.habilidade
	var cartas = w.combate.cartas
	var ids: Array = []
	for d in cartas.disponiveis():
		ids.append(str(d.id))
	ok(ids.has("rb_dano") and ids.has("rb_recarga") and ids.has("rb_estrondo"), "%s: as cartas de dano, recarga e atordoa da E saem para qualquer herói" % id)
	if id == "hazaki":
		ok(ids.has("rb_contra") and ids.has("rb_eco"), "hazaki: Contragolpe e Eco do chão saem (a E dele é a ruptura)")
		return
	ok(not ids.has("rb_contra") and not ids.has("rb_eco"), "%s: Contragolpe e Eco do chão NÃO saem (a E dele não é a ruptura)" % id)
	var b: Dictionary = hab.bloco_de(id)
	# recarga: Pulso ligeiro encurta, com piso
	var base := float(b.recarga)
	ok(absf(hab.recarga_de(b) - base) < 0.001, "%s: sem cartas a recarga é a dos dados (%s)" % [id, hab.recarga_de(b)])
	w.combate.ruptura.definir("recarga", 12.0)
	ok(absf(hab.recarga_de(b) - base * 0.88) < 0.001, "%s: Pulso ligeiro (12%%) encurta a recarga da E (%s)" % [id, hab.recarga_de(b)])
	w.combate.ruptura.definir("recarga", 5000.0)
	ok(hab.recarga_de(b) >= float(hab.comum.piso) - 0.001 and hab.recarga_de(b) < base, "%s: o teto de redução e o piso valem (%s)" % [id, hab.recarga_de(b)])
	w.combate.ruptura.definir("recarga", 0.0)
	# dano: Punho de terra multiplica o dano da E
	zerar()
	var alvo = monstro_a(70, 0)
	ok(h.habilidade(), "%s: dispara sem cartas" % id)
	passos(40)
	var sem := perdeu(alvo)
	zerar()
	w.combate.ruptura.definir("dano", 100.0)
	var alvo2 = monstro_a(70, 0)
	ok(h.habilidade(), "%s: dispara com Punho de terra +100%%" % id)
	passos(40)
	var com := perdeu(alvo2)
	ok(sem > 5.0 and com > sem * 1.6, "%s: Punho de terra dobra o dano da E (%s para %s)" % [id, sem, com])
	w.combate.ruptura.definir("dano", 0.0)


func _bordas() -> void:
	var h = w.heroi
	var hab = w.combate.habilidade
	# id desconhecido: a tecla E não faz nada
	zerar()
	hab.herois["teste_sem"] = "nao_existe"
	ok(hab.id_de("teste_sem") == "" and hab.id_de("nicao") == "investida_escudo", "id desconhecido não tem E; os outros ficam com a deles")
	hab.herois.erase("teste_sem")
	h.hab_nome = ""
	h.hab_id = ""
	h.ruptura()
	ok(h.estado == Heroi.Estado.LIVRE and h.rup_pedido_t == 0.0, "sem E no herói, a tecla E não faz nada")
	hab.armar(h)
	ok(h.hab_nome != "" and h.hab_id == "investida_escudo", "armar devolve a E do herói")
	# o evento da ação ruptura dispara a E nova (o mesmo caminho do teclado e do controle)
	zerar()
	var ev := InputEventAction.new()
	ev.action = "ruptura"
	ev.pressed = true
	h.entrada_evento(ev)
	ok(h.estado == Heroi.Estado.HABILIDADE, "o evento da ação ruptura (tecla E, LB) dispara a E do Nicão")
	hab.cancelar(h)
	# fim de partida com a E no ar
	zerar()
	ok(h.habilidade(), "dispara")
	passos(5)
	w.combate.vitoria()
	ok(h.estado != Heroi.Estado.HABILIDADE and not h.hab_invul, "a vitória desfaz a E")
	zerar()
	ok(h.habilidade(), "dispara de novo")
	passos(5)
	w.combate.heroi_morreu()
	ok(h.estado != Heroi.Estado.HABILIDADE and not h.hab_invul, "a derrota desfaz a E")
	# partida nova: E pronta e nada em andamento
	zerar()
	ok(h.habilidade(), "dispara")
	w.reiniciar()
	ok(h.estado == Heroi.Estado.LIVRE and h.hab_recarga == 0.0 and not h.hab_invul, "reiniciar cancela a E e a deixa pronta")


func _hud(id: String) -> void:
	var h = w.heroi
	var slots = HudHabilidades.new()
	zerar()
	slots.sincronizar(h)
	ok(slots.e_disponivel and slots.e_pronta, "HUD %s: o slot E acende com a E pronta" % id)
	ok(slots.e_icone == (h.hab_icone if id != "hazaki" else "ruptura"), "HUD %s: o ícone é o da E do herói (%s)" % [id, slots.e_icone])
	if id == "hazaki":
		ok(slots._rotulo_e() == "RUPTURA" and slots.estado_e == "ruptura", "HUD hazaki: a E é a ruptura (%s)" % slots._rotulo_e())
		return
	ok(
		slots.estado_e == "habilidade" and slots._rotulo_e() == h.hab_rotulo and slots.e_cor == h.hab_cor,
		"HUD %s: o slot mostra o rótulo e a cor da E (%s)" % [id, slots._rotulo_e()]
	)
	ok(h.habilidade(), "HUD %s: dispara" % id)
	passos(2)
	slots.sincronizar(h)
	ok(slots.e_ativa and slots.e_pronta, "HUD %s: durante a E o slot pulsa" % id)
	var n := 0
	while h.estado == Heroi.Estado.HABILIDADE and n < 200:
		passos(1)
		n += 1
	slots.sincronizar(h)
	ok(
		not slots.e_pronta and slots.recarga_px == 20 and slots._rotulo_e() == "%.1f S" % h.hab_recarga,
		"HUD %s: em recarga mostra a cortina (%d/20) e os segundos (%s)" % [id, slots.recarga_px, slots._rotulo_e()]
	)
	passos(300)
	slots.sincronizar(h)
	ok(slots.recarga_px > 0 and slots.recarga_px < 20, "HUD %s: a cortina desce com o tempo (%d/20)" % [id, slots.recarga_px])
	h.hab_nega_t = 0.2
	slots.sincronizar(h)
	ok(slots.negada, "HUD %s: o aperto negado treme o slot" % id)
	slots.free()
