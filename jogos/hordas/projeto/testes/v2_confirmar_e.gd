extends "res://testes/isolamento_v2.gd"
# A tecla E confirma em todos os menus (UI-1, pedido 5 de 01/11; decisão D10 do plano). A ação ui_accept leva a tecla E física (v2/entrada.gd),
# a página do card passa para R (pausa.gd, status.gd) e os rótulos do glifo mudam (v2/glifos.gd). Checagens:
# 1. ui_accept aceita E, Enter e Espaço (uma vez só, mesmo garantindo de novo); soltar o E não confirma; com o menu fechado o E segue a ruptura.
# 2. escolha de carta: E confirma a carta (escolhidas +1) e NÃO arma a ruptura (o herói não entra em CARGA).
# 3. pausa: com o menu aberto o E é do menu (consumido) e a página do card é R, não E.
# 4. glifos: confirmar mostra E/Enter; a página do card mostra R; a habilidade segue E e o especial Q.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_confirmar_e.tscn  (imprime "v2_confirmar_e falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Entrada := preload("res://v2/entrada.gd")
const Glifos := preload("res://v2/glifos.gd")
const PASSO := 1.0 / 60.0

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _tecla(k: Key, apertado := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = apertado
	return e


func _toque(k: Key) -> void:
	Input.parse_input_event(_tecla(k))
	Input.parse_input_event(_tecla(k, false))


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func ate(cond: Callable, max_passos: int) -> int:
	for i in max_passos:
		if cond.call():
			return i
		w.avancar(PASSO)
	return -1 if not cond.call() else max_passos


func _ready() -> void:
	_run()


func _run() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	Input.use_accumulated_input = false
	_testes()
	print("v2_confirmar_e falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _testes() -> void:
	# 1. a ação ui_accept aceita E, Enter e Espaço, uma só vez por tecla; a ruptura continua sendo E com o menu fechado
	Entrada.garantir()
	Entrada.garantir()
	var eventos_e := 0
	for ev in InputMap.action_get_events("ui_accept"):
		if ev is InputEventKey and ev.physical_keycode == KEY_E:
			eventos_e += 1
	ok(eventos_e == 1, "ui_accept tem a tecla E uma vez só depois de garantir duas vezes (%d)" % eventos_e)
	ok(_tecla(KEY_E).is_action_pressed("ui_accept"), "E confirma (ui_accept)")
	ok(_tecla(KEY_ENTER).is_action_pressed("ui_accept") and _tecla(KEY_SPACE).is_action_pressed("ui_accept"), "Enter e Espaço continuam confirmando")
	ok(not _tecla(KEY_E, false).is_action_pressed("ui_accept"), "soltar o E não confirma")
	ok(not _tecla(KEY_R).is_action_pressed("ui_accept"), "R não confirma")
	ok(_tecla(KEY_E).is_action_pressed("ruptura"), "com o menu fechado o E continua sendo a ruptura")

	# o mundo começa com uma escolha de carta aberta depois de subir de nível (roleta desligada: as cartas aparecem direto)
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	var c = w.combate
	var t = c.telas
	t.roleta_ligada = false
	w.heroi.xp = w.heroi.xp_proximo - 0.1
	c.progresso.ganhar_xp(0.2)
	ate(func(): return c.jogo == "escolha", 120)
	t.espera_escolha = 0.0
	ok(c.jogo == "escolha" and t.escolha_aberta, "o nível abre a escolha de carta")

	# 2. E confirma a carta e não arma a ruptura
	var esc0: int = c.progresso.escolhidas
	_toque(KEY_E)
	passos(3)
	ok(c.progresso.escolhidas == esc0 + 1, "E confirma a carta (%d -> %d)" % [esc0, c.progresso.escolhidas])
	ok(c.jogo != "escolha", "E fecha a escolha")
	ok(w.heroi.estado != Heroi.Estado.CARGA, "o E que confirmou a carta não arma a ruptura")

	# 3. com o menu fechado, E (segurado) arma a ruptura
	Input.parse_input_event(_tecla(KEY_E))
	passos(3)
	ok(w.heroi.estado == Heroi.Estado.CARGA, "com o menu fechado, E segurado arma a ruptura")
	Input.parse_input_event(_tecla(KEY_E, false))
	passos(2)

	# 4. pausa: com o menu aberto, E é do menu (consumido) e a página do card é R
	ok(w.pausa.pausar() and w.pausa.aberto, "a pausa abre")
	ok(w.pausa.entrada(_tecla(KEY_R)), "R é a página do card na pausa (consumido)")
	ok(w.pausa.aberto, "R não fecha a pausa")
	ok(w.pausa.entrada(_tecla(KEY_E)), "com a pausa aberta o E é do menu (consumido)")
	if w.pausa.aberto:
		w.pausa.fechar()

	# 5. glifos: confirmar mostra E/Enter; página do card R; habilidade segue E; especial segue Q
	Glifos.definir(Glifos.Disp.TECLADO)
	ok(Glifos.texto("confirmar") == "E/Enter", "o glifo de confirmar mostra E/Enter (%s)" % Glifos.texto("confirmar"))
	ok(Glifos.texto("aba_proxima") == "R", "a página seguinte é R (%s)" % Glifos.texto("aba_proxima"))
	ok(Glifos.texto("abas") == "Q/R", "as páginas são Q/R (%s)" % Glifos.texto("abas"))
	ok(Glifos.texto("habilidade") == "E", "a habilidade segue na E (%s)" % Glifos.texto("habilidade"))
	ok(Glifos.texto("ultimate") == "Q", "o especial segue no Q (%s)" % Glifos.texto("ultimate"))
