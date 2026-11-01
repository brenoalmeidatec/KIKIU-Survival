extends RefCounted
## Entrada da v2: garante as ações que o mundo lê quando a cena roda sozinha (godot ... res://v2/mundo.tscn), sem passar pelo main.gd, que é
## quem cria o InputMap do jogo (TECLAS em scripts/hordas/main.gd). Só cria o que faltar: com o main.gd rodando nada muda, e as teclas que o
## jogador trocou em Opções > Controles continuam valendo. Andar = ações esquerda, direita, cima e baixo (WASD, setas e analógico esquerdo);
## mirar com o controle = mira_* (analógico direito); golpe principal = atacar (botão esquerdo do mouse e gatilho direito); esquiva = Espaço e botão B; correr = Shift e L3 (analógico apertado);
## secundário = escudo (v2/escudo.gd, por herói em dados/v2_secundario.json): botão direito do mouse e gatilho esquerdo do controle (segurar ergue);
## habilidade = ruptura (v2/ruptura.gd): tecla E e LB do controle (segurar carrega, soltar dispara); especial = ação ultimate (v2/especial.gd, por herói em
## dados/v2_especial.json): tecla Q e RB do controle (apertar dispara).

const Glifos := preload("res://v2/glifos.gd")
const Controles := preload("res://v2/controles.gd")  # as teclas e botões que o jogador trocou em Ajustes > Controles (#422)

const TECLAS := {"esquerda": [KEY_A, KEY_LEFT], "direita": [KEY_D, KEY_RIGHT], "cima": [KEY_W, KEY_UP], "baixo": [KEY_S, KEY_DOWN]}
const EIXOS := {
	"esquerda": [JOY_AXIS_LEFT_X, -1.0],
	"direita": [JOY_AXIS_LEFT_X, 1.0],
	"cima": [JOY_AXIS_LEFT_Y, -1.0],
	"baixo": [JOY_AXIS_LEFT_Y, 1.0],
	"mira_esquerda": [JOY_AXIS_RIGHT_X, -1.0],
	"mira_direita": [JOY_AXIS_RIGHT_X, 1.0],
	"mira_cima": [JOY_AXIS_RIGHT_Y, -1.0],
	"mira_baixo": [JOY_AXIS_RIGHT_Y, 1.0],
}


## Os menus (título, santuário, pausa, escolhas) usam ui_accept e ui_cancel. O Godot traz o D-pad e o analógico nas ações ui_*,
## mas não o A nem o B: sem eles o controle não confirma nem volta. Acrescenta o A e o B quando faltarem.
## A tecla E também confirma (pedido de 01/11): entra em ui_accept como tecla física, do mesmo jeito que a ruptura. Com o menu fechado
## o E continua sendo a ruptura, porque nenhum menu aberto consome o evento antes do herói (mundo.gd).
static func _garantir_botoes_de_menu() -> void:
	for par in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var tem := false
		for e in InputMap.action_get_events(par[0]):
			if e is InputEventJoypadButton and e.button_index == par[1]:
				tem = true
		if not tem:
			var b := InputEventJoypadButton.new()
			b.button_index = par[1]
			InputMap.action_add_event(par[0], b)
	var tem_e := false
	for e in InputMap.action_get_events("ui_accept"):
		if e is InputEventKey and e.physical_keycode == KEY_E:
			tem_e = true
	if not tem_e:
		var tecla := InputEventKey.new()
		tecla.physical_keycode = KEY_E
		InputMap.action_add_event("ui_accept", tecla)


static func garantir() -> void:
	Glifos.instalar()  # escuta o último dispositivo usado (teclado, Xbox, PlayStation) para os rótulos de tecla
	_garantir_botoes_de_menu()
	for acao: String in EIXOS:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao, 0.4)
		for k in TECLAS.get(acao, []):
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(acao, e)
		var m := InputEventJoypadMotion.new()
		m.axis = EIXOS[acao][0]
		m.axis_value = EIXOS[acao][1]
		InputMap.action_add_event(acao, m)
	if not InputMap.has_action("atacar"):
		InputMap.add_action("atacar", 0.4)
		var clique := InputEventMouseButton.new()
		clique.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("atacar", clique)
		var gatilho := InputEventJoypadMotion.new()
		gatilho.axis = JOY_AXIS_TRIGGER_RIGHT
		gatilho.axis_value = 1.0
		InputMap.action_add_event("atacar", gatilho)
	if not InputMap.has_action("esquiva"):
		InputMap.add_action("esquiva", 0.4)
		var espaco := InputEventKey.new()
		espaco.physical_keycode = KEY_SPACE
		InputMap.action_add_event("esquiva", espaco)
		var b := InputEventJoypadButton.new()
		b.button_index = JOY_BUTTON_B
		InputMap.action_add_event("esquiva", b)
	if not InputMap.has_action("correr"):
		InputMap.add_action("correr", 0.4)
		var shift := InputEventKey.new()
		shift.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("correr", shift)
		var l3 := InputEventJoypadButton.new()
		l3.button_index = JOY_BUTTON_LEFT_STICK
		InputMap.action_add_event("correr", l3)
	# habilidade (E / LB): a ruptura. Padrão Overwatch: o botão direito é o tiro SECUNDÁRIO, a habilidade fica numa tecla.
	if not InputMap.has_action("ruptura"):
		InputMap.add_action("ruptura", 0.4)
		var e := InputEventKey.new()
		e.physical_keycode = KEY_E
		InputMap.action_add_event("ruptura", e)
		var lb := InputEventJoypadButton.new()
		lb.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event("ruptura", lb)
	# secundário (botão direito / LT): definido por herói em dados/v2_secundario.json; hoje é o escudo (v2/escudo.gd)
	if not InputMap.has_action("escudo"):
		InputMap.add_action("escudo", 0.4)
		var direito := InputEventMouseButton.new()
		direito.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("escudo", direito)
		var lt := InputEventJoypadMotion.new()
		lt.axis = JOY_AXIS_TRIGGER_LEFT
		lt.axis_value = 1.0
		InputMap.action_add_event("escudo", lt)
	# ESPECIAL (Q / RB): a ação se chama `ultimate`; o herói (heroi.gd, entrada_evento) dispara o especial dele (v2/especial.gd) ao apertar.
	if not InputMap.has_action("ultimate"):
		InputMap.add_action("ultimate", 0.4)
		var q := InputEventKey.new()
		q.physical_keycode = KEY_Q
		InputMap.action_add_event("ultimate", q)
		var rb := InputEventJoypadButton.new()
		rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event("ultimate", rb)
	Controles.aplicar()  # o padrão está completo: põe por cima o que o jogador trocou (idempotente; cada tela chama garantir)
