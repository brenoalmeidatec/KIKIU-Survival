extends Node
## Captura as transições entre telas da v2 (#377) com as cenas de verdade: um PNG por quadro desenhado, em pastas por trecho, com o
## instante (ms) de cada quadro no nome (para montar o GIF no ritmo real). Roda com janela (precisa de GPU).
## Uso: Godot --path jogos/hordas/projeto --position -3000,0 --resolution 960x540 res://testes/fotos/transicoes_fotos.tscn -- --saida=<pasta> [--reduzido] [--perfil=baixo|medio|alto]
## Usa saves TEMPORÁRIOS (user://captura_transicoes_*): o save real e as opções reais não são tocados.
## Trechos: 01_titulo_personagens, 02_personagens_santuario, 03_santuario_partida, 04_pausa_abre, 05_pausa_ajustes, 05b_pausa_conquistas, 06_pausa_fecha,
## 07_resultado, 08_resultado_santuario, 09_santuario_painel, 10_painel_fecha, 11_santuario_personagens. Com --reduzido, a opção "Reduzir animações" vale.

const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const INDICE := "user://captura_transicoes_personagens.cfg"
const PREFIXO := "user://captura_transicoes_p"
const ANTIGO := "user://captura_transicoes_progresso.cfg"
const META := "user://captura_transicoes_meta.cfg"
const OPCOES := "user://captura_transicoes_opcoes.cfg"

var saida := ""
var gravando := ""
var contador := 0
var t0 := 0
var reduzido := false
var perfil := "medio"
var imagens: Array = []  # [pasta, nome, Image]


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
		if a == "--reduzido":
			reduzido = true
		if a.begins_with("--perfil="):
			perfil = a.trim_prefix("--perfil=")
	if saida.is_empty():
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(saida)
	AudioServer.set_bus_mute(0, true)
	Personagens.caminho_indice = INDICE
	Personagens.caminho_base = PREFIXO
	Personagens.caminho_antigo = ANTIGO
	Meta.caminho_save = META
	Config.arquivo = OPCOES
	_limpar()
	Config.definir("reduzir_animacoes", reduzido)
	Config.g_perfil_temporario(perfil)
	var id: String = Personagens.criar("Alisson")
	Personagens.ativar(id)
	RenderingServer.frame_post_draw.connect(_pos_desenho)
	get_tree().root.size = Vector2i(960, 540)
	var titulo: Node = load("res://v2/menu_principal.tscn").instantiate()
	get_tree().root.add_child(titulo)
	get_tree().current_scene = titulo
	await _seg_quadros(40)

	await _trecho("01_titulo_personagens", func(): _tecla(KEY_ENTER), 0.6)
	await _seg_quadros(20)
	await _trecho("02_personagens_santuario", func(): _tecla(KEY_ENTER), 0.6)
	await _seg_quadros(40)
	await _trecho("03_santuario_partida", func(): get_tree().current_scene.usar_portal("floresta"), 0.7)
	await _seg_quadros(120)
	var pausa: Node = _achar_pausa(get_tree().current_scene.ui)
	await _trecho("04_pausa_abre", func(): _tecla(KEY_ESCAPE), 0.5)
	await _seg_quadros(20)
	_ir_para(pausa, "ajustes")
	await _trecho("05_pausa_ajustes", func(): _tecla(KEY_ENTER), 0.5)
	await _seg_quadros(20)
	_tecla(KEY_ESCAPE)  # Ajustes volta ao menu da pausa
	await _seg_quadros(20)
	_ir_para(pausa, "conquistas")
	await _trecho("05b_pausa_conquistas", func(): _tecla(KEY_ENTER), 0.5)
	await _seg_quadros(20)
	await _trecho("06_pausa_fecha", _esc_duplo, 0.5)
	await _seg_quadros(20)
	_tecla(KEY_ESCAPE)
	await _seg_quadros(20)
	_ir_para(pausa, "santuario")
	_tecla(KEY_ENTER)
	_tecla(KEY_UP)
	await _trecho("07_resultado", func(): _tecla(KEY_ENTER), 0.6)
	await get_tree().create_timer(2.2).timeout
	await _trecho("08_resultado_santuario", func(): _tecla(KEY_ENTER), 0.7)
	await _seg_quadros(60)
	# painel de uma estrutura do santuário (Estátuas): abre, fecha com ESC e o ESC seguinte volta à escolha de personagem
	var salao: Node = get_tree().current_scene
	await _trecho("09_santuario_painel", func(): salao.abrir_estrutura("estatuas"), 0.5)
	await _seg_quadros(20)
	await _trecho("10_painel_fecha", func(): _tecla(KEY_ESCAPE), 0.4)
	await _seg_quadros(20)
	await _trecho("11_santuario_personagens", func(): _tecla(KEY_ESCAPE), 0.5)

	_salvar_tudo()
	_limpar()
	print("captura_transicoes: %d quadros em %s" % [imagens.size(), saida])
	get_tree().quit(0)


func _esc_duplo() -> void:
	_tecla(KEY_ESCAPE)
	_tecla(KEY_ESCAPE)


func _limpar() -> void:
	for c in [INDICE, ANTIGO, ANTIGO + ".bak", META, META + ".bak", META + ".tmp", OPCOES]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))
	for i in range(1, 4):
		var base: String = Personagens.caminho_do_save("p%d" % i)
		for s in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(base + s):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(base + s))


func _seg_quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Faz a ação com a gravação ligada e segue gravando por `dur` segundos reais.
func _trecho(nome: String, acao: Callable, dur: float) -> void:
	gravando = nome
	contador = 0
	t0 = Time.get_ticks_msec()
	await get_tree().process_frame  # um quadro da tela de antes
	acao.call()
	await get_tree().create_timer(dur).timeout
	gravando = ""


func _pos_desenho() -> void:
	if gravando == "":
		return
	var img: Image = get_tree().root.get_texture().get_image()
	if img == null or img.is_empty():
		return
	imagens.append([gravando, "%03d_%04d" % [contador, Time.get_ticks_msec() - t0], img])
	contador += 1


func _salvar_tudo() -> void:
	for it in imagens:
		var pasta: String = saida.path_join(it[0])
		DirAccess.make_dir_recursive_absolute(pasta)
		(it[2] as Image).save_png(pasta.path_join(it[1] + ".png"))


func _tecla(k: Key) -> void:
	for pressionado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionado
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _achar_pausa(pai: Node) -> Node:
	for c in pai.get_children():
		if c.has_method("abrir_sair"):
			return c
	return null


func _ir_para(pausa: Node, id: String) -> void:
	for i in 40:
		if pausa.sel < pausa._itens_atuais.size() and str(pausa._itens_atuais[pausa.sel].id) == id:
			return
		_tecla(KEY_DOWN)
