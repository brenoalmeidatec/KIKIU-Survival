extends Node
# Teste automático do menu de pausa da v2 (v2/pausa.gd, ligado ao mundo e ao santuário). Usa saves TEMPORÁRIOS: a meta
# (user://teste_v2_pausa_meta.cfg) e as opções (user://teste_v2_pausa_opcoes.cfg). O save real (user://v2_progresso.cfg) e
# user://opcoes.cfg não são tocados, e a conferência por md5 garante isso.
# Confere: ESC e Start pausam e despausam; Continuar fecha; na escolha de cartas e no baú o ESC não faz nada; Sair do jogo pede
# confirmação e só o "Sim" chama o gancho (que é o quit de verdade); Gráficos (Sombras, Partículas, Mostrar FPS) grava pelo Config e
# muda a sombra do mundo ao vivo; Volume grava e aplica no Som; o clique do mouse escolhe a linha; o hit-stop e a câmera lenta
# seguem depois de pausar e voltar; Voltar ao santuário despausa, abandona a partida (venceu = false) e credita as almas;
# perder o foco não pausa em headless; e no santuário o ESC só abre "Sair do jogo?".
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pausa.tscn  (imprime "v2_pausa falhas=0")
# Prints (precisa de janela, não de --headless): godot --path jogos/hordas/projeto res://testes/v2_pausa.tscn -- --fotos=PASTA
#   grava pausa_menu, pausa_graficos, pausa_confirmar_sair e santuario_sair (só o viewport) e sai.
const Mundo := preload("res://v2/mundo.tscn")
const Altar := preload("res://v2/altar.tscn")
const Meta := preload("res://v2/meta.gd")
const Resultado := preload("res://v2/resultado_meta.gd")
const Sombras := preload("res://v2/sombras.gd")
const SAVE_TESTE := "user://teste_v2_pausa_meta.cfg"
const OPCOES_TESTE := "user://teste_v2_pausa_opcoes.cfg"
const SAVE_REAL := "user://v2_progresso.cfg"
const OPCOES_REAL := "user://opcoes.cfg"

var falhas := 0
var saiu := 0  # o gancho ao_sair conta aqui: o processo de teste não fecha
var _mouse_alvo := Vector2.ZERO


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	Config.arquivo = OPCOES_TESTE
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
	else:
		await _testes()
	_limpar()
	print("v2_pausa falhas=%d" % falhas)
	get_tree().quit()


func _limpar() -> void:
	get_tree().paused = false
	for c in [SAVE_TESTE, OPCOES_TESTE]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))
	Config.arquivo = "user://opcoes.cfg"


func _md5(caminho: String) -> String:
	return FileAccess.get_md5(caminho) if FileAccess.file_exists(caminho) else ""


func _tecla(alvo: Viewport, k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	alvo.push_input(e)


func _baixo(alvo: Viewport, n: int) -> void:
	for i in n:
		_tecla(alvo, KEY_DOWN)


func _pad(alvo: Viewport, botao: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = botao
	e.pressed = true
	alvo.push_input(e)


## Clique completo (aperto e soltura na mesma linha): a ação do menu é no soltar.
func _clique(alvo: Viewport, pos: Vector2) -> void:
	for pressionado in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressionado
		e.position = pos
		alvo.push_input(e)


func _mouse_teste() -> Vector2:
	return _mouse_alvo


func _marcar_saida() -> void:
	saiu += 1


func _achar_pausa(pai: Node) -> Node:
	for c in pai.get_children():
		if c.has_method("abrir_sair"):
			return c
	return null


func _testes() -> void:
	var md5_save := _md5(SAVE_REAL)
	var md5_opc := _md5(OPCOES_REAL)
	_limpar_saves()
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)  # o mundo anda só pelos passos do teste (avancar)
	await get_tree().process_frame
	var sv: SubViewport = mundo.sv
	var pausa = _achar_pausa(sv)
	ok(pausa != null, "o mundo monta o menu de pausa")
	if pausa == null:
		mundo.queue_free()
		return
	pausa.ao_sair = Callable(self, "_marcar_saida")
	ok(pausa.process_mode == Node.PROCESS_MODE_ALWAYS, "o menu roda com a árvore pausada (PROCESS_MODE_ALWAYS)")

	# 1. ESC pausa e de novo despausa; Start do controle faz o mesmo
	_tecla(sv, KEY_ESCAPE)
	ok(pausa.aberto and get_tree().paused, "ESC pausa a partida e abre o menu")
	_tecla(sv, KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused, "ESC de novo fecha o menu e despausa")
	_pad(sv, JOY_BUTTON_START)
	ok(pausa.aberto and get_tree().paused, "Start no controle pausa")
	_pad(sv, JOY_BUTTON_START)
	ok(not pausa.aberto and not get_tree().paused, "Start de novo despausa")

	# 2. o hit-stop e a câmera lenta não travam: pausa no meio deles, volta e o mundo anda até o fim
	mundo.combate.hit_stop(0.3)
	mundo.combate.camera_lenta("", 0.5, 0.25)
	_tecla(sv, KEY_ESCAPE)
	_tecla(sv, KEY_ESCAPE)
	for i in 120:
		mundo.avancar(1.0 / 60.0)
	ok(mundo.combate.parada_t <= 0.0 and mundo.combate.lento_t <= 0.0, "depois de pausar e voltar, o hit-stop e a câmera lenta acabam")
	# 2 s reais: 0,3 s de hit-stop (parados) e 0,5 s de câmera lenta a 0,25 (contam 0,125 s) -> 1,325 s de mundo
	ok(absf(mundo.tempo_partida - 1.325) < 0.05, "o mundo anda de novo: 2 s menos o hit-stop e a câmera lenta (tempo %.3f)" % mundo.tempo_partida)

	# 3. Continuar (primeira linha, Enter) fecha e despausa
	_tecla(sv, KEY_ESCAPE)
	_tecla(sv, KEY_ENTER)
	ok(not pausa.aberto and not get_tree().paused, "Continuar fecha e despausa")

	# 4. na escolha de cartas e no baú, o ESC não abre a pausa nem fecha a escolha
	mundo.combate.jogo = "escolha"
	mundo.combate.pausado = true
	_tecla(sv, KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused and mundo.combate.jogo == "escolha", "ESC na escolha de cartas não abre a pausa nem fecha nada")
	mundo.combate.jogo = "bau"
	_tecla(sv, KEY_ESCAPE)
	ok(not pausa.aberto and mundo.combate.jogo == "bau", "ESC no baú é ignorado")
	mundo.combate.jogo = "jogando"
	mundo.combate.pausado = false

	# 5. Sair do jogo: pede confirmação; "Não" volta ao menu sem sair; só "Sim" chama o gancho
	_tecla(sv, KEY_ESCAPE)
	_baixo(sv, 4)
	_tecla(sv, KEY_ENTER)
	ok(pausa.tela == "confirmar_sair" and saiu == 0, "Sair do jogo pede confirmação e ainda não sai")
	_tecla(sv, KEY_ENTER)  # o padrão da confirmação é "Não"
	ok(pausa.tela == "menu" and pausa.aberto and saiu == 0, "Não volta ao menu e não sai")
	_baixo(sv, 4)
	_tecla(sv, KEY_ENTER)
	_tecla(sv, KEY_UP)
	_tecla(sv, KEY_ENTER)  # Sim
	ok(saiu == 1, "Sim em sair chama o gancho de saída (o único caminho que fecha)")
	_tecla(sv, KEY_ESCAPE)  # volta da confirmação ao menu
	_tecla(sv, KEY_ESCAPE)  # fecha a pausa
	ok(not pausa.aberto and not get_tree().paused, "ESC fecha a pausa depois da confirmação cancelada")

	# 6. Gráficos: Sombras e Partículas gravam pelo Config e a sombra do mundo muda na hora; Mostrar FPS liga e desliga
	_tecla(sv, KEY_ESCAPE)
	_baixo(sv, 1)
	_tecla(sv, KEY_ENTER)
	ok(pausa.tela == "graficos", "Gráficos abre a aba")
	var nomes: Array = Config.g_opcao("sombras").valores
	var antes_s := str(Config.g("sombras"))
	var prox_s := str(nomes[(nomes.find(antes_s) + 1) % nomes.size()])
	_tecla(sv, KEY_ENTER)  # linha 0: Sombras
	ok(str(Config.g("sombras")) == prox_s, "Sombras pela pausa grava na configuração (%s -> %s)" % [antes_s, prox_s])
	ok(mundo.sombras.modo == Sombras.NOMES.find(prox_s), "a sombra do mundo muda ao vivo (graficos_mudou)")
	var part: Array = Config.g_opcao("particulas_sim").valores
	var antes_p := str(Config.g("particulas_sim"))
	var prox_p := str(part[(part.find(antes_p) + 1) % part.size()])
	_baixo(sv, 1)
	_tecla(sv, KEY_ENTER)  # linha 1: Partículas
	ok(str(Config.g("particulas_sim")) == prox_p, "Partículas pela pausa grava na configuração")
	ok(Config.g_perfil() == "personalizado", "mudar uma opção de gráficos vira personalizado, como na aba")
	_baixo(sv, 1)
	var fps_antes := bool(Config.v("mostrar_fps"))
	_tecla(sv, KEY_ENTER)  # linha 2: Mostrar FPS
	ok(bool(Config.v("mostrar_fps")) != fps_antes, "Mostrar FPS liga e desliga")
	pausa._fps_t = 0.0
	await get_tree().process_frame
	ok(pausa._fps.visible == (not fps_antes), "o contador de fps segue a opção ao vivo")
	_baixo(sv, 1)
	_tecla(sv, KEY_ENTER)  # linha 3: Voltar
	ok(pausa.tela == "menu", "Voltar na aba volta ao menu")

	# 7. Volume: seta direita soma 10% em Música (grava em opcoes e aplica no Som); a esquerda tira; ESC volta sem fechar
	_baixo(sv, 2)
	_tecla(sv, KEY_ENTER)
	ok(pausa.tela == "volume", "Volume abre a aba")
	var mus := float(Config.v("musica"))
	_tecla(sv, KEY_RIGHT)
	ok(is_equal_approx(float(Config.v("musica")), snappedf(clampf(mus + 0.1, 0.0, 1.0), 0.1)), "seta direita soma 10% na música")
	ok(is_equal_approx(Som.volume_musica, float(Config.v("musica"))), "o volume da música vale na hora (Som)")
	_tecla(sv, KEY_LEFT)
	_tecla(sv, KEY_LEFT)
	ok(is_equal_approx(float(Config.v("musica")), snappedf(clampf(mus - 0.1, 0.0, 1.0), 0.1)), "seta esquerda tira 10%")
	_tecla(sv, KEY_ESCAPE)
	ok(pausa.tela == "menu" and pausa.aberto, "ESC na aba volta ao menu, sem fechar a pausa")

	# 8. o clique do mouse escolhe a linha (Gráficos é a linha 1 do menu)
	pausa.mouse_fn = Callable(self, "_mouse_teste")
	_mouse_alvo = Vector2(354, 110 + 92 + 1 * 36 + 10)
	_clique(sv, _mouse_alvo)
	ok(pausa.tela == "graficos", "clique com o mouse abre a linha clicada")
	_tecla(sv, KEY_ESCAPE)
	_tecla(sv, KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused, "ESC fecha o menu depois do clique")

	# 9. Voltar ao santuário: confirmação; Sim despausa, abandona a partida e credita as almas (venceu = false)
	var saldo_antes := Meta.saldo()
	mundo.xp_coletado = 250.0  # 25 almas na partida
	var res = Resultado.new()
	mundo.sv.add_child(res)
	res.montar(mundo)  # o mesmo que o mundo faz fora do modo de teste
	_tecla(sv, KEY_ESCAPE)
	_baixo(sv, 3)
	_tecla(sv, KEY_ENTER)
	ok(pausa.tela == "confirmar_santuario", "Voltar ao santuário pede confirmação")
	_tecla(sv, KEY_UP)
	_tecla(sv, KEY_ENTER)  # Sim
	ok(not get_tree().paused and not pausa.aberto, "Sim despausa a árvore antes do resultado (que anima com a árvore rodando)")
	ok(mundo.combate.jogo == "abandono" and mundo.combate.pausado, "a partida acaba como abandonada")
	ok(mundo.resultado.get("venceu") == false, "o resultado sai com venceu = false")
	ok(int(mundo.resultado.get("almas", -1)) == 25, "as almas coletadas até ali vão no resultado")
	ok(Meta.saldo() - saldo_antes >= 25, "as almas são creditadas no save pelo mesmo caminho do fim de partida")
	ok(res._terminou, "o resultado com as almas foi montado")
	var t_antes: float = mundo.tempo_partida
	mundo.avancar(1.0 / 60.0)
	ok(is_equal_approx(mundo.tempo_partida, t_antes), "com a partida abandonada o mundo fica parado")

	# 10. perder o foco não pausa em headless (a v1 faz o mesmo: sem janela, não há foco a respeitar)
	pausa._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(not pausa.aberto and not get_tree().paused, "perder o foco não pausa em headless")

	# 11. santuário: o ESC só abre a confirmação de sair (Não por padrão; Sim chama o gancho).
	# O mundo sai antes: o Apresentacao devolve a escala da janela na saída, e o santuário precisa ter a dele.
	mundo.queue_free()
	await get_tree().process_frame
	var altar = Altar.instantiate()
	add_child(altar)
	await get_tree().process_frame
	var pa = _achar_pausa(altar)
	ok(pa != null, "o santuário monta o menu de pausa")
	if pa != null:
		pa.ao_sair = Callable(self, "_marcar_saida")
		var saidas_antes := saiu
		_tecla(get_viewport(), KEY_ESCAPE)
		ok(pa.aberto and pa.tela == "confirmar_sair", "no santuário, ESC abre a confirmação de sair")
		ok(not get_tree().paused, "no santuário, ESC não mexe na árvore")
		_tecla(get_viewport(), KEY_ENTER)  # padrão: Não
		ok(not pa.aberto and saiu == saidas_antes, "Não fecha a confirmação sem sair")
		_tecla(get_viewport(), KEY_ESCAPE)
		_tecla(get_viewport(), KEY_UP)
		_tecla(get_viewport(), KEY_ENTER)  # Sim
		ok(saiu == saidas_antes + 1, "no santuário, Sim chama o gancho de saída")
	altar.queue_free()

	# o save real e as opções reais não foram tocados
	ok(_md5(SAVE_REAL) == md5_save, "o save real (v2_progresso.cfg) não foi tocado")
	ok(_md5(OPCOES_REAL) == md5_opc, "as opções reais (opcoes.cfg) não foram tocadas")
	_limpar_saves()


func _limpar_saves() -> void:
	if FileAccess.file_exists(SAVE_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TESTE))


## Prints do menu (só o viewport): o menu da partida, a confirmação de sair, a aba de gráficos e a confirmação do santuário.
func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	var sv: SubViewport = mundo.sv
	_tecla(sv, KEY_ESCAPE)
	await mundo.ap.foto(pasta.path_join("pausa_menu.png"))
	_baixo(sv, 4)
	_tecla(sv, KEY_ENTER)
	await mundo.ap.foto(pasta.path_join("pausa_confirmar_sair.png"))
	_tecla(sv, KEY_ESCAPE)
	_tecla(sv, KEY_ESCAPE)
	_tecla(sv, KEY_ESCAPE)
	_baixo(sv, 1)
	_tecla(sv, KEY_ENTER)
	await mundo.ap.foto(pasta.path_join("pausa_graficos.png"))
	get_tree().paused = false
	mundo.queue_free()
	await get_tree().process_frame  # a janela volta à escala antes do santuário montar a dele (ver _testes)
	var altar = Altar.instantiate()
	add_child(altar)
	await get_tree().process_frame
	_tecla(get_viewport(), KEY_ESCAPE)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join("santuario_sair.png"))
	altar.queue_free()
	print("v2_pausa fotos em ", pasta)
