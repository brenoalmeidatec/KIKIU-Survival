extends "res://testes/isolamento_v2.gd"
# Teste do código secreto (v2/codigo_secreto.gd): Konami (setas/direcional/analógico + B + A) ou IDKFA liga o "tudo liberado"
# (Progressao.beta_tester) como opção salva em Config (seção [segredos] do opcoes.cfg, nunca no save do personagem). Confere: a sequência
# certa liga, a errada não, o tempo limite entre teclas, IDKFA, repetir desliga com aviso, o selo CÓDIGO SECRETO (e o BETA TESTER do
# argumento continua mandando), o B e o A do final do Konami não vazam para o menu, o analógico conta uma vez por inclinada, o estado
# sobrevive ao Config.recarregar() e NENHUM arquivo de save muda. No título e no santuário, com a entrada passando pela janela de verdade.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_codigo_secreto.tscn  (imprime "v2_codigo_secreto falhas=0")

const Personagens := preload("res://v2/personagens.gd")
const Meta := preload("res://v2/meta.gd")
const Progressao := preload("res://v2/progressao.gd")
const CodigoSecreto := preload("res://v2/codigo_secreto.gd")
const Salao := preload("res://v2/salao.tscn")
const Titulo := preload("res://v2/menu_principal.tscn")
const PASTA := "user://testes_v2/v2_codigo_secreto/"
const KONAMI := ["cima", "cima", "baixo", "baixo", "esq", "dir", "esq", "dir", "b", "a"]

var falhas := 0
var prefixo := ""
var ligou: Array = []  # o que o sinal `alternado` disse, na ordem


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	prefixo = "teste_codigo_%d_" % Time.get_ticks_usec()
	Personagens.caminho_indice = PASTA + prefixo + "indice.cfg"
	Personagens.caminho_base = PASTA + prefixo + "p"
	Personagens.caminho_antigo = PASTA + prefixo + "antigo.cfg"
	Meta.caminho_save = PASTA + prefixo + "meta.cfg"
	await _testes()
	Progressao.args_teste = null
	var d := DirAccess.open(PASTA)
	for arquivo in d.get_files():
		if arquivo.begins_with(prefixo):
			d.remove(arquivo)
	print("v2_codigo_secreto falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func _hash_saves() -> String:
	var partes := PackedStringArray()
	var d := DirAccess.open(PASTA)
	var nomes := Array(d.get_files()).filter(func(a): return str(a).begins_with(prefixo))
	nomes.sort()
	for a in nomes:
		partes.append("%s=%s" % [a, FileAccess.get_md5(PASTA + a)])
	return ",".join(partes)


## Digita uma lista de tokens, 100 ms entre um e outro, a partir de `t0`. Devolve o relógio da última.
func _digitar(c: Node, tokens: Array, t0: int) -> int:
	var t := t0
	for tk in tokens:
		c.registrar(tk, t)
		t += 100
	return t - 100


func _novo() -> Node:
	var c := CodigoSecreto.new()
	add_child(c)
	c.alternado.connect(func(l: bool): ligou.append(l))
	return c


func _selo(no: Node) -> String:
	for l in no.find_children("*", "Label", false, false):
		if l.text == "BETA TESTER" or l.text == "CÓDIGO SECRETO":
			return l.text
	return ""


func _tecla(k: Key) -> void:
	for pressionado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionado
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _botao(b: JoyButton) -> void:
	for pressionado in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = pressionado
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _testes() -> void:
	var id := Personagens.criar("Isac")
	ok(Personagens.ativar(id), "ativa o personagem")
	Progressao.args_teste = []
	ok(not Progressao.beta_tester() and not Progressao.codigo_ligado() and Progressao.selo() == "", "começa desligado")
	var antes := _hash_saves()

	# 1. a sequência certa liga; a errada e a incompleta não
	var c := _novo()
	_digitar(c, ["cima", "cima", "baixo", "baixo", "esq", "dir", "esq", "dir", "a", "b"], 1000)  # B e A trocados
	ok(not Progressao.codigo_ligado(), "Konami com B e A trocados não liga")
	_digitar(c, ["cima", "cima", "baixo", "baixo", "esq", "dir", "esq", "dir", "b"], 5000)  # falta o A
	ok(not Progressao.codigo_ligado(), "Konami sem o A final não liga")
	_digitar(c, ["cima", "baixo", "cima", "baixo", "esq", "dir", "esq", "dir", "b", "a"], 9000)
	ok(not Progressao.codigo_ligado(), "Konami com uma seta errada não liga")
	_digitar(c, ["i", "d", "k", "a", "f"], 12000)
	ok(not Progressao.codigo_ligado(), "IDKAF (letras fora de ordem) não liga")
	ok(ligou.is_empty(), "nenhum sinal nas tentativas erradas")
	_digitar(c, KONAMI, 20000)
	ok(Progressao.codigo_ligado() and Progressao.beta_tester(), "Konami certo liga o modo")
	ok(ligou == [true], "o sinal avisou que ligou")
	ok(Progressao.selo() == "CÓDIGO SECRETO", "selo CÓDIGO SECRETO (sem o argumento)")
	ok(c.aviso_visivel() == "TUDO LIBERADO!", "anúncio TUDO LIBERADO! na tela (%s)" % c.aviso_visivel())
	ok(Config.segredo("tudo_liberado"), "a opção está em Config")
	ok(FileAccess.get_file_as_string(Config.arquivo).contains("tudo_liberado=true"), "e gravada no arquivo de opções")
	ok(Progressao.aberto("mapa", "laboratorio") and Progressao.aberto("estrutura", "altar"), "portais e estruturas liberados")
	ok(not Config.ITENS.any(func(i): return i.chave == "tudo_liberado"), "não vira linha da tela de Opções")

	# 2. repetir desliga, com aviso
	_digitar(c, KONAMI, 30000)
	ok(not Progressao.codigo_ligado() and not Progressao.beta_tester(), "repetir o Konami desliga")
	ok(ligou == [true, false], "o sinal avisou que desligou")
	ok(c.aviso_visivel() == "Tudo liberado desligado.", "aviso de desligado (%s)" % c.aviso_visivel())
	ok(not Progressao.aberto("mapa", "laboratorio"), "as travas voltam")
	ok(Progressao.selo() == "", "sem selo")

	# 3. IDKFA liga e desliga; com ruído antes
	_digitar(c, ["x", "i", "d", "k", "f", "a"], 40000)
	ok(Progressao.codigo_ligado(), "IDKFA liga (com uma letra solta antes)")
	_digitar(c, ["i", "d", "k", "f", "a"], 50000)
	ok(not Progressao.codigo_ligado(), "IDKFA de novo desliga")

	# 4. tempo limite: mais de 1,5 s entre duas teclas recomeça
	var t := _digitar(c, KONAMI.slice(0, 5), 60000)
	_digitar(c, KONAMI.slice(5), t + CodigoSecreto.TEMPO_MS + 200)
	ok(not Progressao.codigo_ligado(), "pausa de mais de 1,5 s no meio do Konami zera a sequência")
	t = _digitar(c, ["i", "d", "k"], 70000)
	_digitar(c, ["f", "a"], t + CodigoSecreto.TEMPO_MS + 200)
	ok(not Progressao.codigo_ligado(), "o mesmo para o IDKFA")
	t = _digitar(c, KONAMI.slice(0, 9), 80000)
	_digitar(c, KONAMI.slice(9), t + CodigoSecreto.TEMPO_MS)  # exatamente no limite ainda vale
	ok(Progressao.codigo_ligado(), "1,5 s exatos entre as teclas ainda vale")
	_digitar(c, KONAMI, 90000)
	ok(not Progressao.codigo_ligado(), "desliga de novo")

	# 5. o B e o A finais não vazam para o menu; as outras teclas passam
	var eventos := {}
	for i in KONAMI.size():
		eventos[i] = c.registrar(KONAMI[i], 100000 + i * 100)
	for i in 8:
		ok(not eventos[i], "tecla %d do Konami não é consumida" % (i + 1))
	ok(eventos[8] and eventos[9], "o B e o A finais são consumidos (não abrem a saída nem apertam o botão)")
	_digitar(c, KONAMI, 110000)  # desliga
	ok(not c.registrar("b", 120000) and not c.registrar("a", 120100), "um B e um A soltos continuam normais")
	ok(not Progressao.codigo_ligado(), "estado fechado")

	# 6. eventos de verdade: setas, direcional, analógico (uma inclinada = uma tecla), letras e botões do controle
	ok(c.token_de(_ev_tecla(KEY_UP)) == "cima" and c.token_de(_ev_tecla(KEY_RIGHT)) == "dir", "setas do teclado")
	ok(c.token_de(_ev_tecla(KEY_W)) == "w", "WASD são letras comuns (não contam como seta)")
	ok(c.token_de(_ev_tecla(KEY_B)) == "b" and c.token_de(_ev_tecla(KEY_A)) == "a", "B e A do teclado")
	var eco := _ev_tecla(KEY_UP)
	eco.echo = true
	ok(c.token_de(eco) == "", "tecla repetindo (eco) não conta")
	var solta := _ev_tecla(KEY_UP)
	solta.pressed = false
	ok(c.token_de(solta) == "", "soltar não conta")
	ok(c.token_de(_ev_botao(JOY_BUTTON_DPAD_DOWN)) == "baixo" and c.token_de(_ev_botao(JOY_BUTTON_DPAD_LEFT)) == "esq", "direcional do controle")
	ok(c.token_de(_ev_botao(JOY_BUTTON_B)) == "b" and c.token_de(_ev_botao(JOY_BUTTON_A)) == "a", "B e A do controle (○ e ✕ no PlayStation)")
	ok(c.token_de(_ev_botao(JOY_BUTTON_X)) == "", "outros botões não contam")
	ok(c.token_de(_ev_eixo(JOY_AXIS_LEFT_Y, -0.9)) == "cima", "analógico para cima")
	ok(c.token_de(_ev_eixo(JOY_AXIS_LEFT_Y, -0.95)) == "", "analógico segurado não repete")
	ok(c.token_de(_ev_eixo(JOY_AXIS_LEFT_Y, -0.45)) == "", "analógico entre o limiar e a zona de soltar não repete")
	ok(c.token_de(_ev_eixo(JOY_AXIS_LEFT_Y, 0.0)) == "", "analógico volta ao centro")
	ok(c.token_de(_ev_eixo(JOY_AXIS_LEFT_Y, -0.9)) == "cima", "nova inclinada conta de novo")
	ok(c.token_de(_ev_eixo(JOY_AXIS_LEFT_X, 0.1)) == "", "analógico fraco não conta")
	ok(c.token_de(_ev_eixo(JOY_AXIS_RIGHT_X, 1.0)) == "", "analógico direito não conta")
	c.token_de(_ev_eixo(JOY_AXIS_LEFT_Y, 0.0))
	ok(
		c.token_de(_ev_eixo(JOY_AXIS_LEFT_X, -1.0)) == "esq" and c.token_de(_ev_eixo(JOY_AXIS_LEFT_X, 1.0)) == "dir",
		"analógico para os lados (de um lado ao outro sem passar por zero)"
	)
	c.queue_free()
	await get_tree().process_frame

	# 7. no título, com a entrada pela janela: setas + B + A e IDKFA; o B não abre "Sair?" e o A não aperta o botão com foco
	ligou.clear()
	var jogou := [0]
	var menu = Titulo.instantiate()
	menu.ao_jogar = func(): jogou[0] += 1
	add_child(menu)
	await get_tree().process_frame
	ok(menu.codigo != null and _selo(menu) == "", "título: tem o código e começa sem selo")
	menu.codigo.alternado.connect(func(l: bool): ligou.append(l))
	for k in [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]:
		_tecla(k)
	await get_tree().process_frame
	ok(Progressao.codigo_ligado() and ligou == [true], "título: setas + B + A ligam")
	ok(_selo(menu) == "CÓDIGO SECRETO", "título: selo CÓDIGO SECRETO")
	ok(jogou[0] == 0, "título: o A final não apertou o botão Jogar")
	ok(not menu.pausa.aberto, "título: o B final não abriu o Sair")
	for k in [KEY_I, KEY_D, KEY_K, KEY_F, KEY_A]:
		_tecla(k)
	await get_tree().process_frame
	ok(not Progressao.codigo_ligado() and _selo(menu) == "", "título: IDKFA desliga e o selo some")
	# controle de verdade: direcional + B + A
	for b in [
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT,
		JOY_BUTTON_DPAD_RIGHT,
		JOY_BUTTON_DPAD_LEFT,
		JOY_BUTTON_DPAD_RIGHT,
		JOY_BUTTON_B,
		JOY_BUTTON_A
	]:
		_botao(b)
	await get_tree().process_frame
	ok(Progressao.codigo_ligado() and jogou[0] == 0 and not menu.pausa.aberto, "título: direcional + B + A ligam sem acionar o menu")
	# com o menu de Ajustes aberto o código não vale (o menu come as teclas)
	menu.pausa.abrir_ajustes()
	await get_tree().process_frame
	for k in [KEY_I, KEY_D, KEY_K, KEY_F, KEY_A]:
		_tecla(k)
	ok(Progressao.codigo_ligado(), "título: com o menu aberto o IDKFA não vale")
	menu.queue_free()
	await get_tree().process_frame
	Config.definir_segredo("tudo_liberado", false)

	# 8. persistência: sobrevive ao recarregar das opções (próxima partida), e o save do personagem não muda
	Progressao.alternar_codigo()
	Config.recarregar()
	ok(Progressao.codigo_ligado() and Progressao.aberto("mapa", "laboratorio"), "o modo sobrevive ao reabrir as opções do disco")

	# 9. santuário: selo, portal liberado e a sala se refaz
	var s = Salao.instantiate()
	s.recarregar_ao_codigo = false
	add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(_selo(s) == "CÓDIGO SECRETO", "santuário: selo CÓDIGO SECRETO com o modo ligado")
	for a in s._alvos:
		ok(str(a.trava) == "", "santuário: alvo %s sem trava" % a.id)
	ok(s.codigo != null, "santuário: tem o código")
	s.codigo.registrar("i", 200000)
	s.codigo.registrar("d", 200100)
	s.codigo.registrar("k", 200200)
	s.codigo.registrar("f", 200300)
	s.codigo.registrar("a", 200400)
	await get_tree().process_frame
	ok(not Progressao.codigo_ligado() and _selo(s) == "", "santuário: IDKFA desliga e o selo some")
	ok(not Progressao.aberto("mapa", "laboratorio"), "santuário: o Laboratório volta a ficar trancado")
	# o argumento --beta-tester manda no selo
	Progressao.args_teste = ["--beta-tester"]
	Config.definir_segredo("tudo_liberado", true)
	s.codigo.alternar()  # ligado -> desligado, o argumento continua
	await get_tree().process_frame
	ok(Progressao.beta_tester() and Progressao.selo() == "BETA TESTER" and _selo(s) == "BETA TESTER", "com o argumento o selo é BETA TESTER")
	Progressao.args_teste = []
	s.queue_free()
	await get_tree().process_frame

	# 10. nada nos saves
	Config.definir_segredo("tudo_liberado", false)
	var depois := _hash_saves()
	ok(depois == antes, "os saves do personagem não mudam (antes=%s depois=%s)" % [antes, depois])


func _ev_tecla(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	return e


func _ev_botao(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	return e


func _ev_eixo(eixo: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = eixo
	e.axis_value = v
	return e
