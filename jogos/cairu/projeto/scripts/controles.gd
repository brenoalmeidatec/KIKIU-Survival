class_name Controles
## Teclas e controle (gamepad). As teclas de cada ação podem ser trocadas na tela de
## Opções > Controles e ficam salvas em Jogo.opcoes["teclas"] (ação -> lista de teclas físicas).
## O controle usa o padrão do Xbox (no PlayStation: A = X, B = O, X = quadrado, Y = triângulo).

const TECLAS := {
	"cima": [KEY_W, KEY_UP],
	"baixo": [KEY_S, KEY_DOWN],
	"esquerda": [KEY_A, KEY_LEFT],
	"direita": [KEY_D, KEY_RIGHT],
	"interagir": [KEY_E, KEY_ENTER, KEY_SPACE, KEY_KP_ENTER],
	"voltar": [KEY_ESCAPE],
	"acelerar": [KEY_X, KEY_CTRL],
	"historico": [KEY_H],
	"diario": [KEY_J, KEY_TAB],
	"depurar": [KEY_F3, KEY_M],
	"recarregar": [KEY_F5],
	"modo_teste": [KEY_F6],
}

## Botões do controle: número = botão; [eixo, lado] = alavanca esquerda.
const CONTROLE := {
	"cima": [JOY_BUTTON_DPAD_UP, [JOY_AXIS_LEFT_Y, -1.0]],
	"baixo": [JOY_BUTTON_DPAD_DOWN, [JOY_AXIS_LEFT_Y, 1.0]],
	"esquerda": [JOY_BUTTON_DPAD_LEFT, [JOY_AXIS_LEFT_X, -1.0]],
	"direita": [JOY_BUTTON_DPAD_RIGHT, [JOY_AXIS_LEFT_X, 1.0]],
	"interagir": [JOY_BUTTON_A],
	"voltar": [JOY_BUTTON_B, JOY_BUTTON_START],
	"acelerar": [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER],
	"historico": [JOY_BUTTON_LEFT_SHOULDER],
	"diario": [JOY_BUTTON_Y, JOY_BUTTON_BACK],
}

## Ações que aparecem na tela de trocar teclas, com o nome que o jogador vê.
const EDITAVEIS := [["cima", "Andar pra cima"], ["baixo", "Andar pra baixo"], ["esquerda", "Andar pra esquerda"],
	["direita", "Andar pra direita"], ["interagir", "Falar / confirmar"], ["voltar", "Voltar / pausa"],
	["acelerar", "Acelerar cena"], ["diario", "Diário"], ["historico", "Histórico de falas"]]

const NOME_BOTAO := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Select", JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "Cima", JOY_BUTTON_DPAD_DOWN: "Baixo",
	JOY_BUTTON_DPAD_LEFT: "Esq.", JOY_BUTTON_DPAD_RIGHT: "Dir."}

static var usando_controle := false


## Teclas atuais de uma ação (as trocadas pelo jogador, ou as de fábrica).
static func teclas(acao: String) -> Array:
	var t = Jogo.opcoes.get("teclas", {})
	if t is Dictionary and t.get(acao) is Array and not t[acao].is_empty():
		return t[acao].map(func(k): return int(k))
	return TECLAS.get(acao, []).duplicate()


## Monta o InputMap com as teclas e os botões do controle.
static func aplicar() -> void:
	for acao in TECLAS:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao, 0.45)
		InputMap.action_erase_events(acao)
		for k in teclas(acao):
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(acao, ev)
		for b in CONTROLE.get(acao, []):
			if b is Array:
				var m := InputEventJoypadMotion.new()
				m.axis = b[0]
				m.axis_value = b[1]
				InputMap.action_add_event(acao, m)
			else:
				var jb := InputEventJoypadButton.new()
				jb.button_index = b
				InputMap.action_add_event(acao, jb)


## Troca a tecla principal de uma ação. Se outra ação usava essa tecla, ela perde a tecla
## (e ganha a antiga desta, pra nunca ficar sem nenhuma). Devolve o nome da ação que perdeu ("" se nenhuma).
static func trocar(acao: String, tecla: int) -> String:
	var mapa: Dictionary = {}
	for a in TECLAS:
		mapa[a] = teclas(a)
	var antiga: int = mapa[acao][0] if not mapa[acao].is_empty() else 0
	var perdeu := ""
	for a in mapa:
		if a != acao and tecla in mapa[a]:
			mapa[a].erase(tecla)
			if mapa[a].is_empty() and antiga != 0:
				mapa[a].append(antiga)
			perdeu = a
	mapa[acao].erase(tecla)
	if mapa[acao].is_empty():
		mapa[acao].append(tecla)
	else:
		mapa[acao][0] = tecla
	var salvar := {}
	for a in mapa:
		if mapa[a] != TECLAS[a]:
			salvar[a] = mapa[a]
	Jogo.opcoes["teclas"] = salvar
	aplicar()
	return perdeu


static func restaurar() -> void:
	Jogo.opcoes["teclas"] = {}
	aplicar()


static func nome_tecla(k: int) -> String:
	var lk := DisplayServer.keyboard_get_keycode_from_physical(k)
	var s := OS.get_keycode_string(lk if lk != KEY_NONE else k)
	const PT := {"Escape": "Esc", "Up": "Seta cima", "Down": "Seta baixo", "Left": "Seta esq.", "Right": "Seta dir.",
		"Space": "Espaço", "Enter": "Enter", "Kp Enter": "Enter", "Ctrl": "Ctrl", "Tab": "Tab", "Shift": "Shift"}
	return PT.get(s, s)


static func nome_botao(acao: String) -> String:
	for b in CONTROLE.get(acao, []):
		if not b is Array:
			return NOME_BOTAO.get(b, str(b))
	return ""


## Nome curto pra mostrar na tela ("E", ou "A" se o jogador está no controle).
static func tecla(acao: String) -> String:
	if usando_controle and nome_botao(acao) != "":
		return nome_botao(acao)
	var t := teclas(acao)
	return nome_tecla(t[0]) if not t.is_empty() else "?"


## Texto das teclas de uma ação pra tela de opções ("W / Seta cima").
static func descrever(acao: String) -> String:
	var t := teclas(acao).slice(0, 2).map(func(k): return nome_tecla(k))
	return " / ".join(t)
