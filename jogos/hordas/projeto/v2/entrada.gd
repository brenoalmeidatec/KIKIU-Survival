extends RefCounted
## Entrada da v2: garante as ações que o mundo lê quando a cena roda sozinha (godot ... res://v2/mundo.tscn), sem passar pelo main.gd, que é
## quem cria o InputMap do jogo (TECLAS em scripts/hordas/main.gd). Só cria o que faltar: com o main.gd rodando nada muda, e as teclas que o
## jogador trocou em Opções > Controles continuam valendo. Andar = ações esquerda, direita, cima e baixo (WASD, setas e analógico esquerdo);
## mirar com o controle = mira_* (analógico direito); golpe principal = atacar (botão esquerdo do mouse e gatilho direito); esquiva = Espaço e botão B; correr = Shift e L3 (analógico apertado).

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


static func garantir() -> void:
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
