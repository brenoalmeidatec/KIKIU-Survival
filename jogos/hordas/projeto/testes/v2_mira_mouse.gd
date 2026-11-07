extends "res://testes/isolamento_v2.gd"
## MIRA PRESA NO MOUSE (RC1, achado de 05/11). Antes, QUALQUER InputEventMouseMotion punha a fonte da mira em MOUSE (mundo._input) e andar não a
## devolvia (regra do strafe, heroi.gd): um esbarrão no mouse prendia a mira no cursor de quem joga no teclado ou no controle. Agora só um
## movimento intencional (deslocamento líquido >= dados/v2_combate.json > heroi > mira_mouse.limiar_px de TELA numa janela curta) ou um clique
## troca a fonte para MOUSE. Cobre, em dois heróis (um corpo a corpo e o mecha de mira contínua):
##  1. tremor, esbarrão pequeno e ida e volta (soma líquida < limiar) NÃO trocam a fonte: o teclado puro segue em ANDA e olhando para onde anda;
##  2. movimento grande (num evento só ou em vários pequenos) troca; clique esquerdo, direito e meio trocam; soltar o botão e a roda não;
##  3. a janela é curta: deriva lenta (poucos px por segundo) não acumula até o limiar (pelo relógio de mundo.mouse_intencional);
##  4. fonte MOUSE já estabelecida + mouse parado: andar de lado continua sem tirar a mira do mouse (o strafe de 05/11 não foi desfeito);
##  5. o analógico direito volta para STICK, o mouse tremendo não a tira de lá, e andar depois devolve para ANDA como antes.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const HEROIS := ["hazaki", "lightwolf"]
var falhas := 0
var w


func ok(cond: bool, mensagem: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", mensagem)


func zerar(fonte: int) -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.escudo_forcado = false
	w.heroi.fonte = fonte
	w.mouse_forcado = w.heroi.centro() + Vector2(4000, 0)
	if "_mm_acum" in w:
		w._mm_acum = Vector2.ZERO
	for i in 20:
		w.avancar(PASSO)


func mexe(rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = Vector2(480, 270) + rel
	e.relative = rel
	e.screen_relative = rel
	w._input(e)


func botao(qual: int, apertado := true) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = qual
	e.pressed = apertado
	e.position = Vector2(480, 270)
	w._input(e)


func andar(v: Vector2, n: int) -> void:
	w.heroi.entrada_forcada = v
	for i in n:
		w.avancar(PASSO)


func testar(id: String) -> void:
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar(Heroi.Fonte.ANDA)
	var h = w.heroi
	var lim := float(w.combate.cfg.heroi.get("mira_mouse", {}).get("limiar_px", 0.0))
	ok(lim >= 8.0 and lim <= 40.0, "%s: o limiar vem dos dados (dados/v2_combate.json > heroi > mira_mouse): %s" % [id, lim])

	# 1. tremor e esbarrões pequenos: teclado puro continua em ANDA
	for i in 100:
		mexe(Vector2(3, 0) if i % 2 == 0 else Vector2(-3, 0))
	mexe(Vector2(5, 4))  # um esbarrão de ~6 px
	mexe(Vector2(-5, -4))
	mexe(Vector2(10, 0))  # 10 px de uma vez, abaixo do limiar
	ok(h.fonte == Heroi.Fonte.ANDA, "%s: tremor e esbarrão de poucos px NÃO prendem a mira no mouse (fonte=%d)" % [id, h.fonte])
	andar(Vector2.DOWN, 30)
	ok(h.fonte == Heroi.Fonte.ANDA, "%s: o teclado puro segue em ANDA (fonte=%d)" % [id, h.fonte])
	ok(h.dir_olhar.dot(Vector2.DOWN) > 0.99, "%s: e olha para onde anda (%s)" % [id, h.dir_olhar])

	# 2. movimento grande troca (num evento só, e em vários pequenos na mesma janela)
	zerar(Heroi.Fonte.ANDA)
	mexe(Vector2(40, 0))
	ok(h.fonte == Heroi.Fonte.MOUSE, "%s: um movimento grande troca para o mouse (fonte=%d)" % [id, h.fonte])
	zerar(Heroi.Fonte.ANDA)
	for i in 6:
		mexe(Vector2(4, 0))
	ok(h.fonte == Heroi.Fonte.MOUSE, "%s: vários passos pequenos na mesma direção somam e trocam (fonte=%d)" % [id, h.fonte])

	# 2b. clique (qualquer botão de verdade) troca; soltar e a roda, não
	for b in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		zerar(Heroi.Fonte.ANDA)
		botao(b)
		ok(h.fonte == Heroi.Fonte.MOUSE, "%s: o clique (botão %d) troca para o mouse (fonte=%d)" % [id, b, h.fonte])
	zerar(Heroi.Fonte.ANDA)
	botao(MOUSE_BUTTON_LEFT, false)
	botao(MOUSE_BUTTON_WHEEL_UP)
	botao(MOUSE_BUTTON_WHEEL_DOWN)
	ok(h.fonte == Heroi.Fonte.ANDA, "%s: soltar o botão e girar a roda não trocam (fonte=%d)" % [id, h.fonte])

	# 3. a janela é curta: deriva lenta não acumula (pelo relógio injetado, só se a função existir)
	if w.has_method("mouse_intencional"):
		zerar(Heroi.Fonte.ANDA)
		var t := 10000
		var trocou := false
		for i in 60:  # 1 px a cada 100 ms = 10 px/s por 6 s: 60 px no total, mas nunca >= limiar na janela
			var e := InputEventMouseMotion.new()
			e.relative = Vector2(1, 0)
			e.screen_relative = Vector2(1, 0)
			t += 100
			trocou = trocou or w.mouse_intencional(e, t)
		ok(not trocou, "%s: deriva lenta (10 px/s) não vira intenção" % id)
		var e2 := InputEventMouseMotion.new()
		e2.screen_relative = Vector2(30, 0)
		ok(w.mouse_intencional(e2, t + 20), "%s: 30 px num evento é intenção (relógio injetado)" % id)

	# 4. fonte MOUSE já estabelecida, mouse parado: o strafe segue (andar não solta a mira)
	zerar(Heroi.Fonte.MOUSE)
	var mira0: Vector2 = h.dir_olhar
	andar(Vector2.DOWN, 20)
	andar(Vector2.UP, 20)
	ok(h.fonte == Heroi.Fonte.MOUSE and h.dir_olhar.dot(mira0) > 0.99, "%s: mouse parado + andar de lado mantém a mira no mouse (fonte=%d)" % [id, h.fonte])

	# 5. analógico direito: volta para STICK, o mouse tremendo não tira, andar devolve ANDA como antes
	zerar(Heroi.Fonte.MOUSE)
	h.entrada_forcada = null  # o analógico só vale na entrada real
	Input.action_press("mira_cima", 1.0)
	w.avancar(PASSO)
	ok(h.fonte == Heroi.Fonte.STICK, "%s: mexer o analógico direito volta a fonte para STICK (fonte=%d)" % [id, h.fonte])
	Input.action_release("mira_cima")
	for i in 40:
		mexe(Vector2(2, 0) if i % 2 == 0 else Vector2(-2, 0))
	w.avancar(PASSO)
	ok(h.fonte == Heroi.Fonte.STICK, "%s: o mouse tremendo não tira a mira do analógico (fonte=%d)" % [id, h.fonte])
	andar(Vector2.RIGHT, 5)
	ok(h.fonte == Heroi.Fonte.ANDA, "%s: e andar devolve ANDA, como antes (fonte=%d)" % [id, h.fonte])
	w.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	for id in HEROIS:
		await testar(id)
	Herois.forcado = ""
	print("v2_mira_mouse falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)
