extends Node
## UI da dificuldade: a seleção não grava, confirmar grava antes do sinal e uma falha conserva a tela aberta.
## Meta, Config e slots usam prefixo único; os arquivos existentes em user:// são conferidos por MD5.

const Escolha := preload("res://v2/escolha_dificuldade.gd")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const UiJanela := preload("res://v2/ui_janela.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const Glifos := preload("res://v2/glifos.gd")

var falhas := 0
var prefixo := ""
var anteriores := {}
var confirmacoes: Array = []
var cancelamentos := 0
var terminou := false


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for f in DirAccess.get_files_at("user://"):
		anteriores[f] = FileAccess.get_md5("user://" + f)
	prefixo = "teste_escolha_dif_%d_" % Time.get_ticks_usec()
	Meta.caminho_save = "user://" + prefixo + "meta.cfg"
	Config.arquivo = "user://" + prefixo + "opcoes.cfg"
	Config.recarregar()
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	await _testar()
	ok(terminou, "o teste chegou ao fim")
	for f in anteriores:
		ok(FileAccess.get_md5("user://" + f) == anteriores[f], "arquivo anterior intacto: " + f)
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with(prefixo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	print("v2_escolha_dificuldade falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func _testar() -> void:
	var tela := Control.new()
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tela)
	var ajuste := UiJanela.new().montar(tela, "grande")
	tela.add_child(ajuste)
	var escolha := Escolha.new()
	tela.add_child(escolha)
	escolha.confirmou.connect(_confirmou)
	escolha.cancelou.connect(func(): cancelamentos += 1)
	ok(not escolha.visible, "o componente começa fechado")
	ok(Meta.escolher_dificuldade("medio"), "prepara a última escolha")
	var hash_antes := FileAccess.get_md5(Meta.caminho_save)
	escolha.abrir("Ruínas da Floresta")
	ok(escolha.visible and escolha.selecionado == 1, "abrir começa na última dificuldade salva")
	ok(escolha._mapa.text.contains("RUÍNAS DA FLORESTA"), "o cabeçalho identifica o mapa")
	_tecla(KEY_RIGHT)
	ok(escolha.selecionado == 2 and escolha._aviso.text.contains("3 s"), "direita seleciona Difícil e mostra 3 s de espera")
	ok(FileAccess.get_md5(Meta.caminho_save) == hash_antes and confirmacoes.is_empty(), "navegar não grava nem confirma")
	_tecla(KEY_ESCAPE)
	ok(not escolha.visible and cancelamentos == 1 and Meta.dificuldade() == "medio", "Esc volta sem alterar o save")
	escolha.abrir("Floresta")
	_tecla(KEY_LEFT)
	ok(escolha.selecionado == 0 and escolha._aviso.text.contains("livre de fôlego"), "esquerda seleciona Fácil e mostra ataque livre")
	_tecla(KEY_ENTER)
	ok(not escolha.visible and confirmacoes == ["facil"] and Meta.dificuldade() == "facil", "Enter salva a dificuldade e só então confirma")
	escolha.abrir("Floresta")
	_pad(JOY_BUTTON_DPAD_RIGHT)
	ok(escolha.selecionado == 1 and escolha._aviso.text.contains("2 s"), "direcional do controle seleciona Médio com espera de 2 s")
	_pad(JOY_BUTTON_A)
	ok(confirmacoes == ["facil", "medio"] and Meta.dificuldade() == "medio", "A confirma a escolha do controle")
	escolha.abrir("Cidade")
	_pad(JOY_BUTTON_B)
	ok(not escolha.visible and cancelamentos == 2 and Meta.dificuldade() == "medio", "B volta sem gravar")
	escolha.abrir("Cidade")
	await get_tree().process_frame
	_clique(escolha._cartoes[2].get_global_rect().get_center())
	ok(escolha.selecionado == 2 and escolha.visible and Meta.dificuldade() == "medio", "clicar no cartão só seleciona")
	_clique(escolha._entrar.get_global_rect().get_center())
	ok(confirmacoes == ["facil", "medio", "dificil"] and Meta.dificuldade() == "dificil", "o botão Entrar confirma o cartão clicado")
	# Um temporário bloqueado como pasta faz a mesma gravação falhar sem substituir o save válido.
	var temporario := ProjectSettings.globalize_path(Meta.caminho_save + ".tmp")
	ok(DirAccess.make_dir_recursive_absolute(temporario) == OK, "prepara falha de gravação")
	escolha.abrir("Laboratório")
	_tecla(KEY_LEFT)
	_tecla(KEY_ENTER)
	ok(escolha.visible and not escolha._erro.text.is_empty() and confirmacoes.size() == 3, "falha ao salvar mostra erro e não emite confirmou")
	ok(Meta.dificuldade() == "dificil", "a falha conserva a escolha anterior")
	DirAccess.remove_absolute(temporario)
	_tecla(KEY_ENTER)
	ok(not escolha.visible and confirmacoes.size() == 4 and Meta.dificuldade() == "medio", "depois da falha o jogador pode tentar confirmar de novo")
	for tamanho in [Vector2i(960, 540), Vector2i(1920, 1080)]:
		EscalaUi.janela_forcada = tamanho
		ajuste.refazer()
		escolha.abrir("Ruínas da Floresta")
		await get_tree().process_frame
		for cartao in escolha._cartoes:
			ok(escolha._painel.get_global_rect().encloses(cartao.get_global_rect()), "cartão dentro do painel em " + str(tamanho))
			for filho in cartao.get_children():
				if filho is Label:
					ok(
						cartao.get_global_rect().encloses(filho.get_global_rect()),
						"texto '%s' %s dentro do cartão %s em %s" % [filho.text, filho.get_global_rect(), cartao.get_global_rect(), tamanho]
					)
		ok(escolha._aviso.get_minimum_size().y <= escolha._aviso.size.y, "o aviso cabe em " + str(tamanho))
		ok(escolha._aviso.get_global_rect().end.y < escolha._entrar.get_global_rect().position.y, "aviso separado de Entrar em " + str(tamanho))
	EscalaUi.janela_forcada = Vector2i.ZERO
	tela.queue_free()
	await get_tree().process_frame
	terminou = true


func _confirmou(id: String) -> void:
	ok(Meta.dificuldade() == id, "o sinal só é emitido depois de persistir " + id)
	confirmacoes.append(id)


func _tecla(k: Key) -> void:
	for pressionado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionado
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _pad(b: JoyButton) -> void:
	for pressionado in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = pressionado
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _clique(pos: Vector2) -> void:
	var na_janela := get_viewport().get_final_transform() * pos
	var movimento := InputEventMouseMotion.new()
	movimento.position = na_janela
	movimento.global_position = na_janela
	Input.parse_input_event(movimento)
	Input.flush_buffered_events()
	for pressionado in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = na_janela
		e.global_position = na_janela
		e.pressed = pressionado
		Input.parse_input_event(e)
		Input.flush_buffered_events()
