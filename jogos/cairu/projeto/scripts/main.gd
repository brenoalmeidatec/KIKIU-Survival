extends Node
## Liga tudo: define os controles e troca entre o menu e os capítulos.

const Menu := preload("res://scripts/menu.gd")
const Mundo := preload("res://scripts/mundo.gd")


var _tela: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tema := ThemeDB.get_default_theme()
	tema.default_font = load("res://assets/fonte/PressStart2P.ttf")
	tema.default_font_size = 8
	Controles.aplicar()   # teclas (trocáveis em Opções > Controles) e controle
	if _linha_de_comando():
		return
	_abrir_menu()


## JOGO.exe --validar        confere as histórias, grava ERROS_HISTORIA.txt e fecha
## JOGO.exe --cena h3_lucas  abre já tocando a cena (modo teste, não mexe no save)
## JOGO.exe --mapa patio     abre já no mapa (modo teste)
func _linha_de_comando() -> bool:
	var args := Array(OS.get_cmdline_args()) + Array(OS.get_cmdline_user_args())
	var valor := func(chave: String) -> String:
		var i := args.find(chave)
		return str(args[i + 1]) if i >= 0 and i + 1 < args.size() else ""
	if "--validar" in args:
		var erros := Historia.verificar_tudo()
		var arq := Historia.gravar_relatorio(erros)
		print("%d problema(s). Relatório: %s" % [erros.size(), arq])
		for e in erros:
			print(e)
		get_tree().quit(1 if erros.size() > 0 else 0)
		return true
	if "--listar_vozes" in args:
		var quem: String = valor.call("--listar_vozes")
		var arq := Historia.gravar_lista_vozes(quem if quem != "" and not quem.begins_with("--") else "breno")
		print("Lista de falas: ", arq)
		get_tree().quit(0)
		return true
	var cena: String = valor.call("--cena")
	var mapa: String = valor.call("--mapa")
	if cena == "" and mapa == "":
		return false
	var caps := Dados.capitulos()
	if caps.is_empty():
		return false
	var cap: Dictionary = caps[0]
	for c in caps:
		if cena != "" and c.get("cenas", {}).has(cena):
			cap = c
			break
	var ini: Dictionary = cap.get("inicio", {}) if cap.get("inicio") is Dictionary else {}
	_abrir_capitulo(cap, {"mapa": cap.get("mapa_inicial", "recepcao"), "x": ini.get("x", 240), "y": ini.get("y", 200), "dir": ini.get("dir", "baixo")})
	_testar_depois.call_deferred(_tela, cena, mapa)
	return true


func _testar_depois(w: Node, cena: String, mapa: String) -> void:
	await get_tree().process_frame
	if cena != "":
		w.testar_cena(cena)
	else:
		w.testar_mapa(mapa)


func _trocar(nova: Node) -> void:
	if _tela:
		_tela.queue_free()
	_tela = nova
	add_child(nova)


func _abrir_menu() -> void:
	var m := Menu.new()
	m.escolheu.connect(_abrir_capitulo, CONNECT_DEFERRED)
	_trocar(m)


func _abrir_capitulo(cap: Dictionary, estado: Dictionary = {}) -> void:
	var w := Mundo.new()
	w.capitulo = cap
	w.carregar_estado = estado
	w.sair.connect(_abrir_menu, CONNECT_DEFERRED)
	_trocar(w)


## Alavanca do controle: vira "apertou cima/baixo/..." uma vez só quando passa do meio do caminho
## (senão os menus pulariam vários itens). Andar no mapa continua lendo a alavanca direto.
var _alavanca := {}


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		Controles.usando_controle = true
		get_viewport().set_input_as_handled()
		if event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y:
			var par := ["esquerda", "direita"] if event.axis == JOY_AXIS_LEFT_X else ["cima", "baixo"]
			for i in 2:
				var acao: String = par[i]
				var lado := -1.0 if i == 0 else 1.0
				var agora: bool = event.axis_value * lado > 0.6
				var antes: bool = _alavanca.get(acao, false)
				if agora == antes or (not agora and event.axis_value * lado > 0.3):
					continue
				_alavanca[acao] = agora
				var a := InputEventAction.new()
				a.action = acao
				a.pressed = agora
				Input.parse_input_event(a)
		return
	if event is InputEventJoypadButton:
		Controles.usando_controle = true
	elif event is InputEventKey:
		Controles.usando_controle = false
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		Jogo.opcoes.tela_cheia = not Jogo.opcoes.tela_cheia
		Jogo.aplicar_opcoes()
		Jogo.salvar_opcoes()
