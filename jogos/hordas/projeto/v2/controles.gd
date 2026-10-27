extends RefCounted
## Remapeamento de controles da v2 (#422): troca as teclas, o mouse e os botões das ações do InputMap (atacar, escudo, esquiva, correr, ruptura,
## ultimate e as quatro direções) e guarda a escolha num arquivo PRÓPRIO, `controles.cfg`, na mesma pasta do arquivo de opções do Config (um
## arquivo só do Config seria apagado pelo próprio Config a cada gravação, e o save do personagem nunca é tocado). A seção é [controles]: uma
## chave `<acao>_teclado` e uma `<acao>_controle` por slot trocado, com a lista dos códigos ("k:32" tecla física, "m:1" botão do mouse, "b:1" botão do
## controle, "t:5" gatilho). Só o que difere do padrão é gravado; sem nenhuma troca o arquivo nem existe.
## Cada ação tem dois SLOTS: `teclado` (teclas e botões do mouse) e `controle` (botões e gatilhos). O analógico (andar e mirar) não é remapeável e
## fica sempre como está. Trocar um slot substitui TODOS os eventos dele (andar: a letra e a seta da direção saem juntas). Conflito: se a tecla nova já
## é de outra ação, as duas TROCAM de lugar (a outra ganha o que esta tinha). Esc, Start (a pausa), F11, Tab, C e PageUp/PageDown são reservadas.
## O padrão é o que Entrada.garantir() criou no InputMap: a primeira chamada de aplicar() tira uma foto dele antes de qualquer troca.
## Sem dependência de glifos.gd (ele é quem lê este módulo): quem troca um comando chama Glifos.avisar() para as dicas e o HUD se refazerem.

const NOME_ARQUIVO := "controles.cfg"
const SECAO := "controles"
const SLOTS := ["teclado", "controle"]
const LIMIAR_GATILHO := 0.6
## id da ação do InputMap, nome na tela e os slots que dá para trocar.
const ACOES := [
	{"id": "atacar", "nome": "Atacar", "slots": ["teclado", "controle"]},
	{"id": "escudo", "nome": "Escudo", "slots": ["teclado", "controle"]},
	{"id": "esquiva", "nome": "Esquiva", "slots": ["teclado", "controle"]},
	{"id": "correr", "nome": "Correr", "slots": ["teclado", "controle"]},
	{"id": "ruptura", "nome": "Habilidade", "slots": ["teclado", "controle"]},
	{"id": "ultimate", "nome": "Especial", "slots": ["teclado", "controle"]},
	{"id": "cima", "nome": "Andar para cima", "slots": ["teclado"]},
	{"id": "baixo", "nome": "Andar para baixo", "slots": ["teclado"]},
	{"id": "esquerda", "nome": "Andar para a esquerda", "slots": ["teclado"]},
	{"id": "direita", "nome": "Andar para a direita", "slots": ["teclado"]},
]
## Teclas que o jogo já usa fora do InputMap (pausa, tela cheia, card SUA BUILD, minimapa, depuração): não vale pôr uma ação nelas.
const TECLAS_RESERVADAS := [KEY_ESCAPE, KEY_F11, KEY_TAB, KEY_C, KEY_PAGEUP, KEY_PAGEDOWN, KEY_DELETE, KEY_F1, KEY_F3, KEY_F4]
const BOTOES_RESERVADOS := [JOY_BUTTON_START, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]  # Start é a pausa; o direcional navega os menus
const BOTOES_MOUSE := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]

static var _padrao: Dictionary = {}  # "acao|slot" -> lista de códigos do padrão (foto do InputMap criado por Entrada)
static var _alterada: Dictionary = {}  # "acao|slot" -> true quando difere do padrão (cache para o desenho do HUD)


## Onde se grava: ao lado do arquivo de opções do Config (os testes que trocam Config.arquivo levam este junto).
static func arquivo() -> String:
	return Config.arquivo.get_base_dir().path_join(NOME_ARQUIVO)


## Depois de cada troca o cache de "alterada" é refeito. Quem desenha glifos (a HUD, as dicas) é avisado por Glifos.avisar(), que a tela de Controles chama
## (este módulo não conhece glifos.gd, que é quem o lê).
static func _avisar() -> void:
	_recalcular()


static func nome_da_acao(id: String) -> String:
	for a in ACOES:
		if a.id == id:
			return a.nome
	return id


static func slots_da_acao(id: String) -> Array:
	for a in ACOES:
		if a.id == id:
			return a.slots
	return []


# ------------------------------------------------------------------ eventos e códigos


## Em que slot um evento cabe: "teclado" (tecla ou botão do mouse), "controle" (botão ou gatilho) ou "" (analógico e o resto: fica fora).
static func slot_de(e: InputEvent) -> String:
	if e is InputEventKey or e is InputEventMouseButton:
		return "teclado"
	if e is InputEventJoypadButton:
		return "controle"
	if e is InputEventJoypadMotion and _eh_gatilho(e.axis):
		return "controle"
	return ""


static func _eh_gatilho(eixo: int) -> bool:
	return eixo == JOY_AXIS_TRIGGER_LEFT or eixo == JOY_AXIS_TRIGGER_RIGHT


static func codigo(e: InputEvent) -> String:
	if e is InputEventKey:
		return "k:%d" % (e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode)
	if e is InputEventMouseButton:
		return "m:%d" % e.button_index
	if e is InputEventJoypadButton:
		return "b:%d" % e.button_index
	if e is InputEventJoypadMotion:
		return "t:%d" % e.axis
	return ""


## O evento do InputMap que um código descreve (null se o código não vale: arquivo editado à mão ou de outra versão).
static func evento(c: String) -> InputEvent:
	var partes := c.split(":")
	if partes.size() != 2 or not partes[1].is_valid_int():
		return null
	var n := int(partes[1])
	match partes[0]:
		"k":
			if n <= 0:
				return null
			var k := InputEventKey.new()
			k.physical_keycode = n as Key
			return k
		"m":
			if not (n in BOTOES_MOUSE):
				return null
			var m := InputEventMouseButton.new()
			m.button_index = n as MouseButton
			return m
		"b":
			if n < 0 or n >= JOY_BUTTON_SDL_MAX:
				return null
			var b := InputEventJoypadButton.new()
			b.button_index = n as JoyButton
			return b
		"t":
			if not _eh_gatilho(n):
				return null
			var t := InputEventJoypadMotion.new()
			t.axis = n as JoyAxis
			t.axis_value = 1.0
			return t
	return null


## Os eventos do slot que o InputMap tem agora (a verdade do que vale no jogo).
static func eventos(id: String, slot: String) -> Array:
	var r: Array = []
	if not InputMap.has_action(id):
		return r
	for e in InputMap.action_get_events(id):
		if slot_de(e) == slot:
			r.append(e)
	return r


static func codigos(id: String, slot: String) -> Array:
	var r: Array = []
	for e in eventos(id, slot):
		r.append(codigo(e))
	return r


static func _chave(id: String, slot: String) -> String:
	return "%s|%s" % [id, slot]


## Troca TODOS os eventos do slot pelos códigos dados (analógicos e eventos de outro slot ficam como estão).
static func _por_codigos(id: String, slot: String, novos: Array) -> void:
	for e in eventos(id, slot):
		InputMap.action_erase_event(id, e)
	for c in novos:
		var ev := evento(str(c))
		if ev != null:
			InputMap.action_add_event(id, ev)


## Tira a foto do padrão (uma vez por ação e slot), antes de qualquer troca.
static func _fotografar_padrao() -> void:
	for a in ACOES:
		if not InputMap.has_action(a.id):
			continue
		for s in a.slots:
			if not _padrao.has(_chave(a.id, s)):
				_padrao[_chave(a.id, s)] = codigos(a.id, s)


static func padrao(id: String, slot: String) -> Array:
	return _padrao.get(_chave(id, slot), [])


static func _recalcular() -> void:
	_alterada.clear()
	for a in ACOES:
		for s in a.slots:
			if InputMap.has_action(a.id) and _padrao.has(_chave(a.id, s)) and codigos(a.id, s) != _padrao[_chave(a.id, s)]:
				_alterada[_chave(a.id, s)] = true


## Este slot da ação foi trocado pelo jogador? (barato: lê um cache; é o que o HUD pergunta a cada desenho)
static func alterada(id: String, slot: String) -> bool:
	return _alterada.has(_chave(id, slot))


static func alguma_alterada() -> bool:
	return not _alterada.is_empty()


# ------------------------------------------------------------------ arquivo


## Põe no InputMap o que o jogador guardou. Idempotente: o que não está no arquivo volta ao padrão, então chamar de novo (cada tela chama
## Entrada.garantir) nunca empilha eventos. Tira a foto do padrão antes da primeira troca.
static func aplicar() -> void:
	_fotografar_padrao()
	var cfg := ConfigFile.new()
	var tem := cfg.load(arquivo()) == OK
	for a in ACOES:
		if not InputMap.has_action(a.id):
			continue
		for s in a.slots:
			var chave := "%s_%s" % [a.id, s]
			var lista: Array = padrao(a.id, s)
			if tem and cfg.has_section_key(SECAO, chave):
				var salvo := _validar(cfg.get_value(SECAO, chave), s)
				if not salvo.is_empty():
					lista = salvo
			_por_codigos(a.id, s, lista)
	_avisar()


## Só entram os códigos que viram um evento do slot certo; vazio = o arquivo não vale para este slot (cai no padrão).
static func _validar(valor: Variant, slot: String) -> Array:
	var r: Array = []
	if not (valor is Array):
		return r
	for c in valor:
		var ev := evento(str(c))
		if ev != null and slot_de(ev) == slot and not (str(c) in r):
			r.append(str(c))
	return r


## Grava só o que difere do padrão. Sem nenhuma troca apaga o arquivo. Devolve false se não conseguiu gravar.
static func salvar() -> bool:
	var cfg := ConfigFile.new()
	var n := 0
	for a in ACOES:
		for s in a.slots:
			var atual := codigos(a.id, s)
			if InputMap.has_action(a.id) and _padrao.has(_chave(a.id, s)) and atual != _padrao[_chave(a.id, s)]:
				cfg.set_value(SECAO, "%s_%s" % [a.id, s], atual)
				n += 1
	var caminho := arquivo()
	if n == 0:
		if FileAccess.file_exists(caminho):
			return DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho)) == OK
		return true
	return cfg.save(caminho) == OK


# ------------------------------------------------------------------ remapear


## Por que um evento não serve como comando ("" = serve). O Esc e o Start não chegam aqui: cancelam a captura.
static func motivo_recusa(e: InputEvent) -> String:
	if e is InputEventKey:
		var k: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
		if k in TECLAS_RESERVADAS:
			return "reservada"
		return "" if k > 0 else "invalida"
	if e is InputEventMouseButton:
		return "" if e.button_index in BOTOES_MOUSE else "invalida"
	if e is InputEventJoypadButton:
		return "reservada" if e.button_index in BOTOES_RESERVADOS else ""
	if e is InputEventJoypadMotion:
		return "" if _eh_gatilho(e.axis) else "invalida"
	return "invalida"


## Põe `e` como comando da ação. Devolve {"ok": bool, "motivo": "reservada"|"invalida"|"slot"|"igual"|"", "troca": id da ação que foi para o lugar
## desta ("" = nenhuma)}. Já é o comando: nada muda ("igual", ok). Conflito: a outra ação fica com o que esta tinha (troca de lugar).
static func definir(id: String, e: InputEvent) -> Dictionary:
	_fotografar_padrao()
	var slot := slot_de(e)
	var r := {"ok": false, "motivo": "invalida", "troca": ""}
	if slot == "" or not InputMap.has_action(id):
		return r
	if not (slot in slots_da_acao(id)):
		r.motivo = "slot"
		return r
	var recusa := motivo_recusa(e)
	if recusa != "":
		r.motivo = recusa
		return r
	var c := codigo(e)
	var antes := codigos(id, slot)
	if c in antes:
		r.ok = true
		r.motivo = "igual"
		return r
	for a in ACOES:
		if a.id != id and slot in a.slots and c in codigos(a.id, slot):
			_por_codigos(a.id, slot, antes)
			r.troca = a.id
			break
	_por_codigos(id, slot, [c])
	r.ok = true
	r.motivo = ""
	salvar()
	_avisar()
	return r


## Restaurar padrão: todos os slots voltam ao que o jogo traz e o arquivo some.
static func restaurar() -> void:
	_fotografar_padrao()
	for a in ACOES:
		if not InputMap.has_action(a.id):
			continue
		for s in a.slots:
			_por_codigos(a.id, s, padrao(a.id, s))
	salvar()
	_avisar()
