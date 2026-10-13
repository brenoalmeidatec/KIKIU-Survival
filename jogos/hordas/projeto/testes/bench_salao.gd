extends Node
# Bench do fluxo do personagem (título → escolha → salão → compra → portal → partida → morte → salão) e do fps no salão. Não entra
# na bateria do CI (bench_*). Precisa de janela (não --headless), porque grava as telas e mede o quadro de verdade.
# Roda: godot --path jogos/hordas/projeto res://testes/bench_salao.tscn -- --fotos=PASTA
# A navegação usa entradas de verdade (ações de teclado e cliques do mouse, pelo Input). Só o clique que anda até uma estrutura
# e a morte da partida (combate.abandonar, o mesmo caminho do "Voltar ao santuário" da pausa) são disparados pelo código.
# Imprime fps_salao_parado e fps_salao_andando, e grava PNGs (só o viewport) em PASTA.
# Usa saves TEMPORÁRIOS (user://bench_salao_*): os saves reais não são tocados.

const Personagens := preload("res://v2/personagens.gd")
const Meta := preload("res://v2/meta.gd")
const Salao := "res://v2/salao.gd"
const TITULO := "res://v2/menu_principal.tscn"

var _pasta := ""
var _passo := 0


func _ready() -> void:
	if not has_meta("condutor"):  # a cena só cria o condutor: ele fica de fora da cena atual, que as trocas de cena liberam
		var c := Node.new()
		c.set_script(get_script())
		c.set_meta("condutor", true)
		get_tree().root.add_child.call_deferred(c)
		return
	Personagens.caminho_base = "user://bench_salao_p"
	Personagens.caminho_indice = "user://bench_salao_personagens.cfg"
	Personagens.caminho_antigo = "user://bench_salao_antigo.cfg"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
	_limpar()
	_correr()


func _limpar() -> void:
	for f in ["user://bench_salao_personagens.cfg"] + range(1, 4).map(func(i): return Personagens.caminho_do_save("p%d" % i)):
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Meta.caminho_save = "user://bench_salao_meta.cfg"


func _correr() -> void:
	get_tree().change_scene_to_file(TITULO)
	await _esperar(1.0)
	await _foto("01_titulo.png")
	await _tecla("ui_accept")  # JOGAR
	await _esperar(0.6)
	await _foto("02_escolha_vazia.png")  # sem personagem: só NOVO PERSONAGEM
	await _tecla("ui_accept")  # NOVO PERSONAGEM
	await _esperar(0.3)
	await _foto("03_escolha_nomes.png")
	await _tecla("ui_accept")  # o primeiro nome livre: Breno
	await _esperar(1.2)
	var salao = get_tree().current_scene
	print("cena_apos_criar=%s" % salao.get_script().resource_path)
	await _foto("04_salao_zerado.png")
	await _fps("salao_parado", 3.0, false)
	await _fps("salao_andando", 3.0, true)
	# a partida credita almas (o caminho real do fim de partida), e o salão mostra o saldo quando volta
	Meta.registrar_partida({"tempo": 320.0, "abates": 40, "nivel": 4, "maior_combo": 12, "venceu": false, "almas": 300})
	get_tree().current_scene.call_deferred("_atualizar_textos")
	await _clicar(Vector2(250, 300))  # estátuas: anda até lá e abre o painel sozinha
	await _esperar_ate(func(): return salao._painel.visible, 8.0)
	await _foto("05_painel_estatuas.png")
	salao._p_comprar.pressed.emit()  # COMPRAR (o item selecionado é o primeiro: vida)
	await _esperar(0.3)
	await _foto("06_painel_comprado.png")
	await _tecla("ui_cancel")  # ESC fecha o painel
	await _esperar(0.3)
	await _clicar(Vector2(150, 170))  # portal da floresta: anda até lá e entra
	await _esperar_ate(func(): return get_tree().current_scene.get("combate") != null, 40.0)
	await _esperar(4.0)
	await _foto("07_partida.png")
	var mundo = get_tree().current_scene
	await _fps("partida", 3.0, false)
	mundo.combate.abandonar()  # a morte (ou abandono): o mesmo caminho da pausa
	await _esperar(2.0)
	await _foto("08_resultado.png")
	await _tecla("ui_accept")  # CONTINUAR
	await _esperar_ate(func(): return get_tree().current_scene.get_script() != null and get_tree().current_scene.get_script().resource_path == Salao, 15.0)
	print("cena_apos_morte=%s" % get_tree().current_scene.get_script().resource_path)
	await _esperar(1.0)
	await _foto("09_salao_volta.png")
	print("saldo_volta=%d" % Meta.saldo())
	print("bench_salao fim")
	get_tree().quit()


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _esperar_ate(condicao: Callable, limite: float) -> void:
	var t := 0.0
	while not condicao.call() and t < limite:
		await get_tree().process_frame
		t += get_process_delta_time()


func _tecla(acao: String) -> void:
	var p := InputEventAction.new()
	p.action = acao
	p.pressed = true
	Input.parse_input_event(p)
	await get_tree().process_frame
	var s := InputEventAction.new()
	s.action = acao
	s.pressed = false
	Input.parse_input_event(s)
	await get_tree().process_frame


func _clicar(pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	var s := InputEventMouseButton.new()
	s.button_index = MOUSE_BUTTON_LEFT
	s.position = pos
	s.global_position = pos
	s.pressed = false
	Input.parse_input_event(s)
	await get_tree().process_frame


## fps médio durante `seg` segundos; com `andar`, segura a direita o tempo todo (o herói anda na sala).
func _fps(nome: String, seg: float, andar: bool) -> void:
	if andar:
		var p := InputEventAction.new()
		p.action = "direita"
		p.pressed = true
		Input.parse_input_event(p)
	var soma := 0.0
	var n := 0
	var t := 0.0
	while t < seg:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		soma += Engine.get_frames_per_second()
		n += 1
	if andar:
		var s := InputEventAction.new()
		s.action = "direita"
		s.pressed = false
		Input.parse_input_event(s)
	print("fps_%s=%.1f (quadros=%d)" % [nome, soma / maxf(1.0, n), n])


func _foto(nome: String) -> void:
	if _pasta == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_pasta.path_join(nome))
