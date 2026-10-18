extends Node
# Navegação com controle Xbox nas telas com glifo da v2: os apertos entram pelo caminho da janela (Input.parse_input_event), o mesmo do controle de
# verdade. Cartas: X rerrola e Y bane (os rótulos "Rerrolar (n)" e "Banir a marcada (n)" contam). Baú: A fecha quando a roleta acabou. Personagens e
# Salão: A e B estão mapeados nas ações ui_accept e ui_cancel (quem decide é cada tela). O próprio teste trava o dispositivo em Xbox.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_controle_nav.tscn  (imprime "v2_controle_nav falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Personagens := preload("res://v2/personagens.tscn")
const Salao := preload("res://v2/salao.tscn")
const Glifos := preload("res://v2/glifos.gd")
const Meta := preload("res://v2/meta.gd")
const SAVE_TESTE := "user://teste_v2_controle_nav_meta.cfg"
const OPCOES_TESTE := "user://teste_v2_controle_nav_opcoes.cfg"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	Config.arquivo = OPCOES_TESTE
	Glifos.forcado = true
	Glifos.definir(Glifos.Disp.XBOX)
	await _cartas()
	await _bau()
	await _mapeamento()
	Glifos.forcado = false
	for c in [SAVE_TESTE, SAVE_TESTE + ".bak", SAVE_TESTE + ".tmp", OPCOES_TESTE]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))
	Config.arquivo = "user://opcoes.cfg"
	print("v2_controle_nav falhas=%d" % falhas)
	get_tree().quit()


func _aperto(botao: int) -> void:
	for pressionado in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = botao
		e.pressed = pressionado
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _cartas() -> void:
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	await get_tree().process_frame
	var c = mundo.combate
	c.limpar_partida()
	c.diretor.ligado = false
	mundo.heroi.imortal = true
	var cs = c.cartas
	for par in [["aura_fogo", 4], ["laminas", 2], ["corvos", 3], ["raio", 2], ["runa", 2]]:
		for i in int(par[1]):
			cs.aplicar(cs.montar_carta(cs.definicao(str(par[0])), 1 + (i % 3)))
	mundo.heroi.nivel = 20
	c.progresso.cartas = cs.sortear(3, 20)
	c.jogo = "escolha"
	c.pausado = true
	c.telas.mostrar_escolha(c.progresso.cartas, 20)
	c.telas.espera_escolha = 0.0  # a trava de 3 s não é o que este teste mede
	await get_tree().process_frame
	var r_antes: String = c.telas._btn_r_txt.text
	var b_antes: String = c.telas._btn_b_txt.text
	# Y antes de X: a carta marcada (a 1ª) é banível; rerrolar troca as cartas e a 1ª pode virar uma cura, que não se bane
	await _aperto(JOY_BUTTON_Y)
	var b_depois: String = c.telas._btn_b_txt.text
	ok(b_depois != b_antes, "Y bane a marcada (%s -> %s)" % [b_antes, b_depois])
	c.telas.espera_escolha = 0.0  # o banimento mostra cartas novas e reabre a trava de 3 s; zerada de novo para o X
	await _aperto(JOY_BUTTON_X)
	var r_depois: String = c.telas._btn_r_txt.text
	ok(r_depois != r_antes, "X rerrola (%s -> %s)" % [r_antes, r_depois])
	ok(Glifos.texto("rerrolar") == "X" and Glifos.texto("banir") == "Y", "no controle o rótulo de rerrolar e banir é X e Y")
	c.telas.esconder()
	mundo.queue_free()
	await get_tree().process_frame


func _bau() -> void:
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	await get_tree().process_frame
	var c = mundo.combate
	c.jogo = "bau"  # como bau.gd: o baú abre com jogo "bau" (fechar() só vale nesse estado)
	c.pausado = true
	c.telas.mostrar_bau(c.progresso.cartas if not c.progresso.cartas.is_empty() else c.cartas.sortear(3, 20))
	c.telas._pular_bau()
	c.telas.espera_bau = 0.0
	await get_tree().process_frame
	ok(c.telas.bau_aberto, "o baú está aberto antes do A")
	await _aperto(JOY_BUTTON_A)
	ok(not c.telas.bau_aberto, "A fecha o baú quando a roleta acabou")
	mundo.queue_free()
	await get_tree().process_frame


func _mapeamento() -> void:
	var p = Personagens.instantiate()
	add_child(p)
	await get_tree().process_frame
	var s = Salao.instantiate()
	add_child(s)
	await get_tree().process_frame
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	ok(InputMap.event_is_action(a, "ui_accept") and InputMap.event_is_action(b, "ui_cancel"), "A é ui_accept e B é ui_cancel (personagens e salão)")
	ok(Glifos.texto("voltar") == "B" and Glifos.texto("confirmar") == "A", "no controle, voltar é B e confirmar é A")
	p.queue_free()
	s.queue_free()
	await get_tree().process_frame
