extends Node
# Navegação com controle Xbox nas telas com glifo da v2: os apertos entram pelo caminho da janela (Input.parse_input_event), o mesmo do controle de
# verdade. Cartas: X rerrola, LB bane e Y escolhe automaticamente (os rótulos contam os usos). Baú: A fecha quando a roleta acabou. Personagens e
# Salão: A e B estão mapeados nas ações ui_accept e ui_cancel (quem decide é cada tela). O próprio teste trava o dispositivo em Xbox.
# Índice, slots de personagem, save antigo e opções são isolados: o teste funciona também num user:// vazio, como o do CI.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_controle_nav.tscn  (imprime "v2_controle_nav falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Personagens := preload("res://v2/personagens.tscn")
const Salao := preload("res://v2/salao.tscn")
const Glifos := preload("res://v2/glifos.gd")
const Meta := preload("res://v2/meta.gd")
const Slots := preload("res://v2/personagens.gd")
const PASTA_TESTE := "user://teste_v2_controle_nav"
const SAVE_TESTE := PASTA_TESTE + "/meta.cfg"
const OPCOES_TESTE := PASTA_TESTE + "/opcoes.cfg"
const INDICE_TESTE := PASTA_TESTE + "/indice.cfg"
const BASE_TESTE := PASTA_TESTE + "/personagem_"
const ANTIGO_TESTE := PASTA_TESTE + "/antigo.cfg"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var caminhos_antes := [Slots.caminho_indice, Slots.caminho_base, Slots.caminho_antigo, Meta.caminho_save, Config.arquivo]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA_TESTE))
	_limpar()
	Slots.caminho_indice = INDICE_TESTE
	Slots.caminho_base = BASE_TESTE
	Slots.caminho_antigo = ANTIGO_TESTE
	Meta.caminho_save = SAVE_TESTE
	Config.arquivo = OPCOES_TESTE
	Config.recarregar()
	Slots.iniciar()
	ok(Slots.lista().is_empty() and Slots.ativo() == "", "o cenário começa sem personagens nem save antigo de outro teste")
	var id := Slots.criar("Breno")
	var ativou := Slots.ativar(id)
	ok(id != "" and ativou and Slots.ativo() == id, "o personagem temporário fica ativo antes de abrir o salão")
	if not ativou:
		_limpar()
		print("v2_controle_nav falhas=%d" % falhas)
		get_tree().quit(1)
		return
	Glifos.forcado = true
	Glifos.definir(Glifos.Disp.XBOX)
	print("v2_controle_nav: cartas (personagem temporário ativo)")
	await _cartas()
	print("v2_controle_nav: baú")
	await _bau()
	print("v2_controle_nav: personagens e salão")
	await _mapeamento()
	Glifos.forcado = false
	_limpar()
	Slots.caminho_indice = caminhos_antes[0]
	Slots.caminho_base = caminhos_antes[1]
	Slots.caminho_antigo = caminhos_antes[2]
	Meta.caminho_save = caminhos_antes[3]
	Config.arquivo = caminhos_antes[4]
	print("v2_controle_nav falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _limpar() -> void:
	for nome in DirAccess.get_files_at(PASTA_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PASTA_TESTE.path_join(nome)))


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
	mundo.set_process(false)  # este teste envia entrada real, mas não precisa simular a partida entre os apertos
	await get_tree().process_frame
	var c = mundo.combate
	c.limpar_partida()
	c.diretor.ligado = false
	mundo.heroi.imortal = true
	var cs = c.cartas
	cs.rng.seed = 777
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
	# LB antes de X: a carta marcada (a 1ª) é banível; rerrolar troca as cartas e a 1ª pode virar uma cura, que não se bane
	await _aperto(JOY_BUTTON_LEFT_SHOULDER)
	var b_depois: String = c.telas._btn_b_txt.text
	ok(b_depois != b_antes and c.jogo == "escolha", "LB bane a marcada e mantém a escolha (%s -> %s)" % [b_antes, b_depois])
	c.telas.espera_escolha = 0.0  # o banimento mostra cartas novas e reabre a trava de 3 s; zerada de novo para o X
	await _aperto(JOY_BUTTON_X)
	var r_depois: String = c.telas._btn_r_txt.text
	ok(r_depois != r_antes, "X rerrola (%s -> %s)" % [r_antes, r_depois])
	ok(
		Glifos.texto("rerrolar") == "X" and Glifos.texto("automatico") == "Y" and Glifos.texto("banir") == "LB",
		"no controle os rótulos são X rerrolar, Y automático e LB banir"
	)
	c.telas.espera_escolha = 0.0
	var escolhas_antes: int = c.progresso.escolhidas
	var banimentos_antes: int = cs.banimentos_restantes()
	var rerrolares_antes: int = cs.rerrolares_restantes()
	await _aperto(JOY_BUTTON_Y)
	ok(c.jogo != "escolha" and c.progresso.escolhidas == escolhas_antes + 1, "Y aplica o automático pela entrada real e fecha a escolha")
	ok(cs.banimentos_restantes() == banimentos_antes and cs.rerrolares_restantes() == rerrolares_antes, "Y não gasta banimento nem rerrolagem")
	c.telas.esconder()
	mundo.queue_free()
	await get_tree().process_frame


func _bau() -> void:
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
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
	var cena_teste := get_tree().current_scene
	ok(cena_teste == self and Slots.ativo() != "", "o driver do teste e o personagem temporário estão prontos")
	var p = Personagens.instantiate()
	add_child(p)
	await get_tree().process_frame
	var s = Salao.instantiate()
	add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame  # inclui eventuais chamadas deferred de troca de cena
	ok(get_tree().current_scene == cena_teste, "o salão mantém a cena de teste, sem redirecionar para a escolha")
	ok(s.pausa != null and s._p_lista != null, "o salão terminou de montar a pausa e o painel com o personagem temporário")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	ok(InputMap.event_is_action(a, "ui_accept") and InputMap.event_is_action(b, "ui_cancel"), "A é ui_accept e B é ui_cancel (personagens e salão)")
	ok(Glifos.texto("voltar") == "B" and Glifos.texto("confirmar") == "A", "no controle, voltar é B e confirmar é A")
	p.queue_free()
	s.queue_free()
	await get_tree().process_frame
