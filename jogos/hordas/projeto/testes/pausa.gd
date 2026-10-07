extends Node
# Teste automático: Esc abre o menu de pausa. Sozinho congela o jogo; Esc de novo (ou Continuar) retoma;
# o Esc que fecha a loja não abre a pausa junto; no online o menu abre mas o jogo NÃO para (os outros seguem).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/pausa.tscn  (imprime "PAUSA falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func tecla(pressionada: bool) -> void:
	var e := InputEventAction.new()
	e.action = "voltar"
	e.pressed = pressionada
	Input.parse_input_event(e)

func esc() -> void:
	tecla(true)
	await esperar(0.1)
	tecla(false)
	await esperar(0.1)

func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	# --- sozinho ---
	var a := Arena.new()
	a.heroi_id = "hazaki"
	add_child(a)
	await esperar(1.6)
	ok(not a.hud._pausado and not get_tree().paused, "começa sem pausa")
	await esc()
	ok(a.hud._pausado, "solo: Esc abre o menu")
	ok(get_tree().paused, "solo: Esc pausa a árvore")
	var m0: Vector2 = a.jogador.position
	await esperar(0.5)
	ok(a.jogador.position == m0, "solo: o herói fica parado na pausa")
	await esc()
	ok(not a.hud._pausado and not get_tree().paused, "solo: Esc de novo retoma")
	a.hud.pausar()
	await esperar(0.1)
	a.hud._op_pausa = 0
	a.hud._pausa_confirmar()
	ok(not a.hud._pausado and not get_tree().paused, "solo: Continuar retoma")
	a.loja.abrir([a._carta("arma", "katana", 1)])
	await esperar(0.5)
	ok(a.loja.aberto(), "loja abriu")
	await esc()
	ok(not a.loja.aberto() and not a.hud._pausado, "solo: Esc fecha a loja e NÃO abre a pausa junto")
	ok(not get_tree().paused, "solo: depois da loja o jogo segue")
	a.queue_free()
	await esperar(0.2)
	# --- online ---
	var b := Arena.new()
	b.heroi_id = "hazaki"
	b.eh_online = true
	add_child(b)
	await esperar(1.6)
	await esc()
	ok(b.hud._pausado, "online: Esc abre o menu")
	ok(not get_tree().paused, "online: o jogo NÃO pausa")
	await esc()
	ok(not b.hud._pausado, "online: Esc fecha o menu")
	b.queue_free()
	await esperar(0.1)
	print("PAUSA falhas=%d" % falhas)
	get_tree().quit()
