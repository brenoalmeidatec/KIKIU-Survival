extends "res://testes/isolamento_v2.gd"
## Percorre morte -> resultado -> entrada real -> salão na cena atual, sem modo_teste.
## Save exclusivo (um personagem de teste, em arquivos temporários); também confere saída do resultado quando a gravação falha.
const Mundo := preload("res://v2/mundo.tscn")
const Meta := preload("res://v2/meta.gd")
const Heroi := preload("res://v2/heroi.gd")
const Personagens := preload("res://v2/personagens.gd")
const SAVE_REAL := "user://testes_v2/v2_morte/v2_progresso.cfg"
var falhas := 0
var caminho := ""


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var real_antes := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	var antigo := Meta.caminho_save
	# o salão precisa de um personagem ativo: usa um de teste, em arquivos temporários (os saves reais ficam fora)
	var prefixo := "user://testes_v2/v2_morte/teste_v2_morte_%s_" % Time.get_ticks_usec()
	Personagens.caminho_base = prefixo + "personagem_"
	Personagens.caminho_indice = prefixo + "personagens.cfg"
	Personagens.caminho_antigo = prefixo + "antigo.cfg"
	var personagem := Personagens.criar("Breno")
	Personagens.ativar(personagem)
	caminho = "user://testes_v2/v2_morte/teste_v2_morte_%s.cfg" % Time.get_ticks_usec()
	Meta.caminho_save = caminho
	# Não pode pertencer à cena que a troca destruirá: mantém o teste vivo na raiz.
	reparent(get_tree().root)
	get_tree().current_scene = null
	for i in 4:
		await _caso(["floresta", "laboratorio", "cidade", "medio"][i], i)
	Meta.caminho_save = antigo
	for arquivo in [Personagens.caminho_indice, Personagens.caminho_do_save(personagem)]:
		if FileAccess.file_exists(arquivo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(arquivo))
	for sufixo in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(caminho + sufixo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho + sufixo))
	var real_depois := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	ok(real_antes == real_depois, "progresso real preservado")
	print("v2_morte falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)


func _caso(mapa: String, tipo: int) -> void:
	Meta.caminho_save = caminho  # a sala de cada caso pode trocar o save ativo (o salão aponta a meta para o personagem)
	var tree := get_tree()
	var w = Mundo.instantiate()
	w.id_mapa = mapa
	tree.root.add_child(w)
	tree.current_scene = w
	w.set_process(false)
	w.combate.audio.mudo = true
	w.combate.diretor.ligado = false
	w.heroi.entrada_forcada = Vector2.ZERO
	await tree.process_frame
	var antes := Meta.saldo()
	var falha_save := tipo == 3
	if falha_save:
		ok(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(caminho + ".tmp")) == OK, "prepara falha de gravação")
	w.xp_coletado = 170.0
	w.heroi.invenc = 0.0
	w.heroi.imortal = false
	ok(w.heroi.levar_dano(w.heroi.vida_max + 1.0, w.heroi.pos + Vector2(60, 0)), "dano fatal consumido")
	ok(w.heroi.estado == Heroi.Estado.MORTO and w.combate.jogo == "morrendo", "morte inicia câmera lenta")
	for i in 120:
		w.avancar(1.0 / 60.0)
	ok(w.combate.pausado and w.meta_res.aberto, "resultado abre pelo fluxo real")
	var tempo: float = w.tempo_partida
	var pos: Vector2 = w.heroi.pos
	w.avancar(0.1)
	ok(w.tempo_partida == tempo and w.heroi.pos == pos, "resultado trava mundo")
	var res = w.meta_res
	res.set_process(false)
	var evento := _evento(tipo)
	Input.parse_input_event(evento.duplicate())
	Input.flush_buffered_events()
	ok(tree.current_scene == w and not res._saindo, "entrada precoce não pula resultado")
	res._process(0.9)
	ok(res._botao.modulate.a > 0.9, "continuar aparece mesmo se save falha")
	if falha_save:
		ok(not res._save_ok and res._almas_tit.text == "NÃO FOI POSSÍVEL SALVAR", "erro visível sem bloquear saída")
		ok(Meta.saldo() == antes, "falha não credita almas")
	else:
		ok(Meta.saldo() == antes + 17, "almas creditadas uma vez")
	w.combate.fim_de_partida(false)
	ok(Meta.saldo() == (antes if falha_save else antes + 17), "sinal duplicado não credita novamente")
	# Dois eventos antes do fim do quadro não podem destruir o viewport nem repetir a troca.
	Input.parse_input_event(evento.duplicate())
	Input.parse_input_event(evento.duplicate())
	Input.flush_buffered_events()
	ok(is_instance_valid(w) and w.is_inside_tree() and res._saindo, "cena sobrevive ao processamento do evento")
	await tree.process_frame
	await tree.process_frame
	ok(tree.current_scene != null and tree.current_scene.scene_file_path == "res://v2/salao.tscn", "entrada real retorna ao santuário")
	if falha_save:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho + ".tmp"))
	if tree.current_scene != null:
		tree.current_scene.queue_free()
	await tree.process_frame


func _evento(tipo: int) -> InputEvent:
	if tipo == 1:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = Vector2(480, 498)
		return e
	if tipo == 2:
		var e := InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_A
		e.pressed = true
		return e
	var e := InputEventKey.new()
	e.keycode = KEY_ENTER
	e.physical_keycode = KEY_ENTER
	e.pressed = true
	return e
