extends Node
# Teste automático (#55): Esc nos menus, no meio da transição. Cada Esc volta UMA tela, a cortina termina sozinha e nada fica preso.
# Esc entra como InputEventKey físico e como InputEventAction "voltar", em vários instantes depois da troca de tela.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/esc_transicao.tscn  (imprime "ESC_TRANSICAO falhas=0")
const Main := preload("res://scripts/hordas/main.gd")
var falhas := 0
var m: Node


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Esc de verdade: aperta e solta. como = "tecla" (KEY_ESCAPE físico) ou "acao" (InputEventAction).
func esc(como: String, segura := 0.05) -> void:
	_esc(true, como)
	await esperar(segura)
	_esc(false, como)


func _esc(p: bool, como: String) -> void:
	if como == "acao":
		var a := InputEventAction.new()
		a.action = "voltar"
		a.pressed = p
		Input.parse_input_event(a)
	else:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = p
		Input.parse_input_event(e)


func tecla(k: Key) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = p
		Input.parse_input_event(e)
		await quadros(2)


func estado() -> String:
	return str(m._estado)


## Espera a cortina acabar (no máximo 3 s) e devolve quanto levou em segundos reais.
func fim_da_cortina() -> float:
	var t0 := Time.get_ticks_msec()
	while Transicao.ativa() and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	return (Time.get_ticks_msec() - t0) / 1000.0


func ir_para_herois() -> void:
	m._estado = "titulo"
	await esperar(0.7)
	m._sel = 0
	m._titulo_confirmar()
	await quadros(2)


func _tem_tela_aberta() -> bool:
	for f in m.get_children():
		if f.get_script() and str(f.get_script().resource_path).contains("tela_"):
			return true
	return false


func _ready() -> void:
	m = Main.new()
	m.name = "Main"
	add_child(m)
	await esperar(0.8)
	for como in ["tecla", "acao"]:
		for atraso in [0.0, 0.03, 0.12, 0.3, 0.6]:
			# heróis -> Esc -> título, apertando Esc `atraso` s depois da troca (cortina no começo, no meio, no fim ou já acabada)
			await ir_para_herois()
			ok(estado() == "herois", "[%s %.2f] título -> heróis" % [como, atraso])
			await esperar(atraso)
			await esc(como)
			await quadros(3)
			ok(estado() == "titulo", "[%s %.2f] Esc nos heróis volta ao título (está em %s)" % [como, atraso, estado()])
			var dur := await fim_da_cortina()
			ok(not Transicao.ativa(), "[%s %.2f] a cortina acaba (%.2f s)" % [como, atraso, dur])
			await esperar(0.2)
			ok(estado() == "titulo", "[%s %.2f] e o título fica (está em %s)" % [como, atraso, estado()])
		# heróis -> calor -> Esc -> heróis (uma tela só) -> Esc -> título
		for atraso in [0.0, 0.1, 0.5]:
			await ir_para_herois()
			await esperar(0.6)
			await tecla(KEY_ENTER)
			await quadros(3)
			ok(estado() == "calor" or estado() == "preparo", "[%s %.2f] Enter nos heróis abre o calor (está em %s)" % [como, atraso, estado()])
			await esperar(atraso)
			await esc(como)
			await quadros(3)
			ok(estado() == "herois", "[%s %.2f] Esc no calor volta SÓ pros heróis (está em %s)" % [como, atraso, estado()])
			await esperar(atraso)
			await esc(como)
			await quadros(3)
			ok(estado() == "titulo", "[%s %.2f] segundo Esc volta ao título (está em %s)" % [como, atraso, estado()])
			await fim_da_cortina()
			ok(not Transicao.ativa(), "[%s %.2f] cortina acaba" % [como, atraso])
		# título -> opções -> Esc -> título
		for atraso in [0.0, 0.2, 0.6]:
			m._estado = "titulo"
			await esperar(0.7)
			m._sel = m.OPCOES.find("Opções")
			m._titulo_confirmar()
			await quadros(3)
			ok(estado() == "opcoes", "[%s %.2f] opções abrem" % [como, atraso])
			await esperar(atraso)
			await esc(como)
			await quadros(3)
			ok(estado() == "titulo", "[%s %.2f] Esc nas opções volta ao título (está em %s)" % [como, atraso, estado()])
			await esperar(0.2)
			ok(not _tem_tela_aberta(), "[%s %.2f] a tela de opções fechou" % [como, atraso])
		# título -> créditos -> Esc
		for atraso in [0.0, 0.2, 0.6]:
			m._estado = "titulo"
			await esperar(0.7)
			m._sel = m.OPCOES.find("Créditos")
			m._titulo_confirmar()
			await quadros(3)
			ok(estado() == "creditos", "[%s %.2f] créditos abrem" % [como, atraso])
			await esperar(atraso)
			await esc(como)
			await quadros(3)
			ok(estado() == "titulo", "[%s %.2f] Esc nos créditos volta ao título (está em %s)" % [como, atraso, estado()])
			await fim_da_cortina()
	# heróis -> "Meus heróis" (a tela de vagas lê o Esc em _input) -> Esc volta SÓ pros heróis, não pro título
	for como in ["tecla", "acao"]:
		for atraso in [0.0, 0.3, 0.7]:
			await ir_para_herois()
			await esperar(0.6)
			m._escolher_heroi(m._herois().size())
			await quadros(3)
			ok(estado() == "criacao", "[%s %.2f] 'Meus heróis' abre (está em %s)" % [como, atraso, estado()])
			await esperar(atraso)
			await esc(como)
			await quadros(3)
			if como == "tecla":  # a tela de vagas só lê tecla de verdade
				ok(estado() == "herois", "[%s %.2f] Esc em 'Meus heróis' volta SÓ pros heróis (está em %s)" % [como, atraso, estado()])
				ok(not _tem_tela_aberta(), "[%s %.2f] 'Meus heróis' fechou" % [como, atraso])
			else:
				m._estado = "herois"  # a ação sem tecla não fecha a tela: tira ela do caminho pro próximo giro
				for f in m.get_children():
					if f.get_script() and str(f.get_script().resource_path).contains("tela_"):
						f.queue_free()
			await fim_da_cortina()
	# metralhadora de Esc: a cortina ainda acaba
	await ir_para_herois()
	for i in 6:
		await esc("tecla", 0.02)
		await esperar(0.03)
	await fim_da_cortina()
	ok(not Transicao.ativa() and estado() == "titulo", "metralhadora de Esc: acaba no título e sem cortina (%s)" % estado())
	print("ESC_TRANSICAO falhas=", falhas)
	get_tree().quit()
