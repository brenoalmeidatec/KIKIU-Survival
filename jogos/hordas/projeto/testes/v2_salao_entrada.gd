extends "res://testes/isolamento_v2_control.gd"
# Regressão do #423: no santuário, Enter (ou A do controle) perto de um portal ou de uma estrutura faz a ação DELA, não abre os Ajustes.
# A causa era o foco: passar o mouse num botão de baixo (AJUSTES, VOLTAR) o focava, e o ui_accept, que a interface trata ANTES do
# _unhandled_input da sala, apertava o botão em vez de usar o alvo. Aqui o evento entra pelo viewport de verdade (Input.parse_input_event),
# com o mouse "passado" sobre cada botão, em vez de chamar _unhandled_input direto (foi assim que o furo passou batido).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_salao_entrada.tscn  (imprime "v2_salao_entrada falhas=0")
const Personagens := preload("res://v2/personagens.gd")
const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const Progressao := preload("res://v2/progressao.gd")
const PASTA := "user://testes_v2/v2_salao_entrada/"

var falhas := 0
var s


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var prefixo := "entrada_%d_" % Time.get_ticks_usec()
	Personagens.caminho_indice = PASTA + prefixo + "indice.cfg"
	Personagens.caminho_base = PASTA + prefixo + "p"
	Personagens.caminho_antigo = PASTA + prefixo + "antigo.cfg"
	Meta.caminho_save = PASTA + prefixo + "meta.cfg"
	ok(Personagens.ativar(Personagens.criar("Teste")), "personagem isolado ativo")
	s = load("res://v2/salao.tscn").instantiate()
	add_child(s)
	s.ao_entrar = func(_cena): pass
	await get_tree().process_frame
	await get_tree().process_frame
	# 1) save novo: há portais trancados (o aviso aparece, sem Ajustes); 2) tudo liberado: o portal pede a dificuldade
	await _rodada("save novo")
	var cf: ConfigFile = Meta._ler()
	for c in ["vence_floresta", "vence_laboratorio", "vence_cidade"]:
		cf.set_value("conquistas", c, true)
	cf.set_value("progressao", "partidas", 3)
	ok(Meta._gravar(cf), "save com tudo liberado")
	await _rodada("tudo liberado")
	# o botão AJUSTES continua funcionando com o clique
	_botao("AJUSTES").pressed.emit()
	ok(s.pausa.aberto, "clicar em AJUSTES abre os Ajustes")
	s.pausa.fechar()
	print("v2_salao_entrada falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func _botao(texto: String) -> Button:
	for f in s.get_children():
		if f is Button and f.text == texto:
			return f
	return null


## Cada alvo da sala, com o mouse sobre (nenhum, AJUSTES ou VOLTAR) e cada entrada (Enter, Espaço, A do controle).
func _rodada(rotulo: String) -> void:
	for a in s._alvos:
		for sobre in ["", "AJUSTES", "VOLTAR"]:
			for entrada in ["enter", "espaco", "joy_a"]:
				await _tentar(a, sobre, entrada, "%s: %s, mouse sobre '%s', %s" % [rotulo, a.id, sobre, entrada])


func _tentar(a: Dictionary, sobre: String, entrada: String, ctx: String) -> void:
	s._pos = a.pos.clamp(s.ANDAR_MIN, s.ANDAR_MAX)
	s._destino = Vector2.INF
	s._atualizar_prompt()
	s._aviso_lbl.text = ""
	if sobre != "":
		_botao(sobre).mouse_entered.emit()  # o mouse passou pelo botão: é assim que ele ganhava o foco
	var trocas: int = Transicoes.trocas
	await get_tree().process_frame
	_apertar(entrada)
	await get_tree().process_frame
	ok(not s.pausa.aberto, "nao abre os Ajustes: " + ctx)
	ok(Transicoes.trocas == trocas, "nao sai do santuario (VOLTAR): " + ctx)
	var trancado := Progressao.aviso("estrutura", str(a.id)) != "" if a.tipo == "estrutura" else Mapas.condicao(Mapas.buscar(str(a.id))) != ""
	if trancado:
		ok(s._aviso_lbl.visible and s._aviso_lbl.text.to_lower().contains("trancado"), "alvo trancado avisa: " + ctx)
	elif a.tipo == "estrutura":
		ok(s._painel.visible, "abre a estrutura: " + ctx)
	else:
		ok(s._escolha_dificuldade.visible and s._mapa_pendente == str(a.id), "pede a dificuldade do portal certo: " + ctx)
	if s.pausa.aberto:  # não deixa uma falha desta volta contaminar as seguintes
		s.pausa.fechar()
	s._fechar_painel()
	s._escolha_dificuldade.hide()
	s._mapa_pendente = ""
	var dono := get_viewport().gui_get_focus_owner()
	if dono != null:
		dono.release_focus()


func _apertar(entrada: String) -> void:
	for pressionado in [true, false]:
		var e: InputEvent
		if entrada == "joy_a":
			e = InputEventJoypadButton.new()
			e.button_index = JOY_BUTTON_A
		else:
			e = InputEventKey.new()
			var k := KEY_ENTER if entrada == "enter" else KEY_SPACE
			e.keycode = k
			e.physical_keycode = k
		e.pressed = pressionado
		Input.parse_input_event(e)
		Input.flush_buffered_events()
