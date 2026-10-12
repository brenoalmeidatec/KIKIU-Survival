extends Node
# Teste automático do menu de pausa da v2 (v2/pausa.gd, v2/ajustes_graficos.gd, ligado ao mundo e ao santuário). Usa saves
# TEMPORÁRIOS: a meta (user://teste_v2_pausa_meta.cfg) e as opções (user://teste_v2_pausa_opcoes.cfg). O save real
# (user://v2_progresso.cfg) e user://opcoes.cfg não são tocados, e a conferência por md5 garante isso.
# Confere: a pausa tem 4 itens (Continuar, Ajustes, Voltar ao santuário, Sair do jogo); ESC e Start pausam e despausam;
# Continuar fecha; na escolha de cartas e no baú o ESC abre a pausa por cima (e na morte não abre); Sair pede confirmação e só o
# Sim chama o gancho; a entrada vem pelo caminho da janela (Input.parse_input_event), o mesmo do jogador;
# Ajustes abre Gráficos (com CPU e GPU) e Áudio; trocar o perfil muda a config (e a sombra do mundo, ao vivo); Sombras,
# sliders, listas, Mostrar FPS e Detectar gravam pelo Config; Música e Efeitos mudam o volume (e o Som); o clique do mouse
# escolhe a linha; ESC dentro de Ajustes volta um nível; o hit-stop e a câmera lenta seguem depois de pausar; Voltar ao santuário
# despausa, abandona a partida (venceu = false) e credita as almas; perder o foco não pausa em headless; e no santuário o ESC
# abre só "Sair?", e o botão Ajustes abre o submenu.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pausa.tscn  (imprime "v2_pausa falhas=0")
# Prints (com janela): godot --path jogos/hordas/projeto res://testes/v2_pausa.tscn -- --fotos=PASTA
#   grava pausa_menu, pausa_ajustes, pausa_graficos, pausa_audio, pausa_confirmar_sair e santuario_ajustes (só o viewport).
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


## Toda a entrada daqui entra pelo caminho da janela (Input.parse_input_event: a viewport RAIZ, como o teclado de verdade). Antes
## ela era empurrada direto no SubViewport da partida (sv.push_input), que o jogador nunca usa: o ESC morto passava no teste.
func _enviar(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## Aperto e soltura da tecla, como um toque de verdade.
func _tecla(k: Key) -> void:
	for pressionado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionado
		_enviar(e)


func _baixo(n: int) -> void:
	for i in n:
		_tecla(KEY_DOWN)


func _pad(botao: JoyButton) -> void:
	for pressionado in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = botao
		e.pressed = pressionado
		_enviar(e)


## Clique completo (aperto e soltura na mesma linha): a ação do menu é no soltar.
func _clique(pos: Vector2) -> void:
	for pressionado in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressionado
		e.position = pos
		_enviar(e)


func _mouse_teste() -> Vector2:
	return _mouse_alvo


func _marcar_saida() -> void:
	saiu += 1


func _achar_pausa(pai: Node) -> Node:
	for c in pai.get_children():
		if c.has_method("abrir_sair"):
			return c
	return null


## Anda com as setas até a linha de id `id` (a seleção pula os cabeçalhos, como o jogador sente).
func _ir_para(pausa, id: String) -> void:
	for i in 80:
		if pausa.sel < pausa._itens_atuais.size() and str(pausa._itens_atuais[pausa.sel].id) == id:
			return
		_tecla(KEY_DOWN)


func _ids(pausa) -> Array:
	var r: Array = []
	for it in pausa._itens_atuais:
		r.append(str(it.id))
	return r


func _sel_id(pausa) -> String:
	return str(pausa._itens_atuais[pausa.sel].id) if pausa.sel < pausa._itens_atuais.size() else ""


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
	_tecla(KEY_ESCAPE)
	ok(pausa.aberto and get_tree().paused, "ESC pausa a partida e abre o menu")
	ok(
		_ids(pausa) == ["continuar", "ajustes", "santuario", "sair"],
		"a pausa tem 4 itens: Continuar, Ajustes, Voltar ao santuário, Sair (%s)" % str(_ids(pausa))
	)
	_tecla(KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused, "ESC de novo fecha o menu e despausa")
	_pad(JOY_BUTTON_START)
	ok(pausa.aberto and get_tree().paused, "Start no controle pausa")
	_pad(JOY_BUTTON_START)
	ok(not pausa.aberto and not get_tree().paused, "Start de novo despausa")

	# 2. o hit-stop e a câmera lenta não travam: pausa no meio deles, volta e o mundo anda até o fim
	mundo.combate.hit_stop(0.3)
	mundo.combate.camera_lenta("", 0.5, 0.25)
	_tecla(KEY_ESCAPE)
	_tecla(KEY_ESCAPE)
	for i in 120:
		mundo.avancar(1.0 / 60.0)
	ok(mundo.combate.parada_t <= 0.0 and mundo.combate.lento_t <= 0.0, "depois de pausar e voltar, o hit-stop e a câmera lenta acabam")
	# 2 s reais: 0,3 s de hit-stop (parados) e 0,5 s de câmera lenta a 0,25 (contam 0,125 s) -> 1,325 s de mundo
	ok(absf(mundo.tempo_partida - 1.325) < 0.05, "o mundo anda de novo: 2 s menos o hit-stop e a câmera lenta (tempo %.3f)" % mundo.tempo_partida)

	# 3. Continuar (primeira linha, Enter) fecha e despausa
	_tecla(KEY_ESCAPE)
	_tecla(KEY_ENTER)
	ok(not pausa.aberto and not get_tree().paused, "Continuar fecha e despausa")

	# 4. na escolha de cartas e no baú, o ESC abre a pausa por cima e, ao fechar, o jogo volta como estava (o detalhe está em v2_esc)
	mundo.combate.jogo = "escolha"
	mundo.combate.pausado = true
	_tecla(KEY_ESCAPE)
	ok(pausa.aberto and get_tree().paused and mundo.combate.jogo == "escolha", "ESC na escolha de cartas abre a pausa por cima")
	_tecla(KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused and mundo.combate.jogo == "escolha" and mundo.combate.pausado, "e ao fechar a escolha volta como estava")
	mundo.combate.jogo = "bau"
	_tecla(KEY_ESCAPE)
	ok(pausa.aberto and get_tree().paused and mundo.combate.jogo == "bau", "ESC no baú abre a pausa por cima")
	_tecla(KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused and mundo.combate.jogo == "bau" and mundo.combate.pausado, "e ao fechar o baú volta como estava")
	mundo.combate.jogo = "morrendo"
	_tecla(KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused and mundo.combate.jogo == "morrendo", "na câmera lenta da morte o ESC não abre a pausa")
	mundo.combate.jogo = "jogando"
	mundo.combate.pausado = false

	# 5. Sair do jogo: pede confirmação; "Não" volta ao menu sem sair; só "Sim" chama o gancho
	_tecla(KEY_ESCAPE)
	_ir_para(pausa, "sair")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "confirmar_sair" and saiu == 0, "Sair do jogo pede confirmação e ainda não sai")
	_tecla(KEY_ENTER)  # o padrão da confirmação é "Não"
	ok(pausa.tela == "menu" and pausa.aberto and saiu == 0, "Não volta ao menu e não sai")
	_ir_para(pausa, "sair")
	_tecla(KEY_ENTER)
	_tecla(KEY_UP)
	_tecla(KEY_ENTER)  # Sim
	ok(saiu == 1, "Sim em sair chama o gancho de saída (o único caminho que fecha)")
	_tecla(KEY_ESCAPE)  # volta da confirmação ao menu
	_tecla(KEY_ESCAPE)  # fecha a pausa
	ok(not pausa.aberto and not get_tree().paused, "ESC fecha a pausa depois da confirmação cancelada")

	# 6. Ajustes e Gráficos: a aba tem CPU e GPU; trocar o perfil muda a config e a sombra do mundo; as linhas gravam
	Config.g_aplicar_perfil("alto")  # ponto de partida conhecido (o save do jogador pode ter outro perfil)
	_tecla(KEY_ESCAPE)
	_ir_para(pausa, "ajustes")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "ajustes" and _ids(pausa) == ["graficos", "audio", "voltar"], "Ajustes abre com Gráficos, Áudio e Voltar")
	_ir_para(pausa, "graficos")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "graficos", "Gráficos abre a aba")
	var ids_g: Array = _ids(pausa)
	ok(
		"g:perfil" in ids_g and "g:fps" in ids_g and "g:op:sombras" in ids_g and "g:op:luz_relevo" in ids_g,
		"a aba Gráficos tem perfil, FPS e as opções do json"
	)
	var cabs := 0
	for it in pausa._itens_atuais:
		if bool(it.get("cab", false)):
			cabs += 1
	ok(cabs == 2, "a aba tem as duas seções, CPU e GPU (cabeçalhos: %d)" % cabs)
	_ir_para(pausa, "g:perfil")
	_tecla(KEY_RIGHT)  # alto -> baixo
	ok(Config.g_perfil() == "baixo", "trocar o perfil para Baixo muda a config (perfil = %s)" % Config.g_perfil())
	ok(str(Config.g("sombras")) == "baixa" and int(Config.g("limite_fps")) == 60, "o perfil Baixo põe sombras baixa e limite de 60 fps")
	ok(mundo.sombras.modo == Sombras.BAIXA, "a sombra do mundo acompanha o perfil ao vivo (graficos_mudou)")
	_ir_para(pausa, "g:op:sombras")
	_tecla(KEY_RIGHT)  # baixa -> media
	ok(str(Config.g("sombras")) == "media" and mundo.sombras.modo == Sombras.MEDIA, "Sombras (lista) muda a config e a sombra do mundo")
	ok(_sel_id(pausa) == "g:op:sombras" and pausa._ajuda.text != "", "o rodapé mostra a ajuda da linha escolhida")
	_ir_para(pausa, "g:op:brilhos_halos")
	var halos_antes := int(Config.g("brilhos_halos"))
	_tecla(KEY_RIGHT)  # slider: passo de 25
	ok(
		int(Config.g("brilhos_halos")) == mini(halos_antes + 25, 100),
		"um slider sobe pelo passo do json (%d -> %s)" % [halos_antes, str(Config.g("brilhos_halos"))]
	)
	_ir_para(pausa, "g:op:particulas_sim")
	var part_antes := str(Config.g("particulas_sim"))
	_tecla(KEY_RIGHT)
	ok(str(Config.g("particulas_sim")) != part_antes, "Partículas (lista) muda a config")
	_ir_para(pausa, "g:fps")
	var fps_antes := bool(Config.v("mostrar_fps"))
	_tecla(KEY_ENTER)
	ok(bool(Config.v("mostrar_fps")) != fps_antes, "Mostrar FPS liga e desliga")
	pausa._fps_t = 0.0
	await get_tree().process_frame
	ok(pausa._fps.visible == (not fps_antes), "o contador de fps segue a opção ao vivo")
	_ir_para(pausa, "g:detectar")
	_tecla(KEY_ENTER)
	ok(pausa._graficos.mensagem != "", "Detectar pela máquina dá um aviso (%s)" % pausa._graficos.mensagem)
	_ir_para(pausa, "g:op:luz_relevo")
	ok(str(pausa._itens_atuais[pausa.sel].rotulo).ends_with("*"), "uma opção que a v2 ainda não lê aparece marcada com *")
	_tecla(KEY_ESCAPE)  # ESC dentro de Gráficos volta a Ajustes (um nível)
	ok(pausa.tela == "ajustes" and pausa.aberto, "ESC em Gráficos volta um nível: a Ajustes, sem fechar a pausa")

	# 7. Áudio: Música e Efeitos mudam o volume (grava em opcoes e aplica no Som); ESC volta a Ajustes e depois à pausa
	_ir_para(pausa, "audio")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "audio", "Áudio abre a aba")
	var mus := float(Config.v("musica"))
	_ir_para(pausa, "musica")
	_tecla(KEY_RIGHT)
	ok(is_equal_approx(float(Config.v("musica")), snappedf(clampf(mus + 0.1, 0.0, 1.0), 0.1)), "seta direita soma 10% na música")
	ok(is_equal_approx(Som.volume_musica, float(Config.v("musica"))), "o volume da música vale na hora (Som)")
	var bus_mus := AudioServer.get_bus_index(Som.BUS_MUSICA)
	ok(bus_mus != -1 and absf(AudioServer.get_bus_volume_db(bus_mus) - linear_to_db(Som.volume_musica)) < 0.1, "o slider Música move o bus Musica")
	_tecla(KEY_LEFT)
	_tecla(KEY_LEFT)
	ok(is_equal_approx(float(Config.v("musica")), snappedf(clampf(mus - 0.1, 0.0, 1.0), 0.1)), "seta esquerda tira 10%")
	_ir_para(pausa, "efeitos")
	var efe := float(Config.v("efeitos"))
	_tecla(KEY_ENTER)  # Enter soma
	ok(is_equal_approx(float(Config.v("efeitos")), snappedf(clampf(efe + 0.1, 0.0, 1.0), 0.1)), "Enter também soma 10% nos efeitos")
	_tecla(KEY_ESCAPE)
	ok(pausa.tela == "ajustes" and pausa.aberto, "ESC em Áudio volta a Ajustes (sem fechar)")
	_tecla(KEY_ESCAPE)
	ok(pausa.tela == "menu" and pausa.aberto, "ESC em Ajustes volta à pausa (sem fechar a pausa de uma vez)")
	_tecla(KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused, "ESC na pausa fecha e despausa")

	# 8. o clique do mouse escolhe a linha (Ajustes é a linha 2 do menu: a lista começa no topo)
	_tecla(KEY_ESCAPE)
	pausa.mouse_fn = Callable(self, "_mouse_teste")
	_mouse_alvo = Vector2(354, 55 + 118 + 1 * 36 + 16)  # Ajustes: linha 2 (PAINEL, LINHA0, LINHA_H de pausa.gd)
	_clique(_mouse_alvo)
	ok(pausa.tela == "ajustes", "clique com o mouse abre a linha clicada")
	_tecla(KEY_ESCAPE)
	_tecla(KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused, "ESC fecha o menu depois do clique")

	# 9. Voltar ao santuário: confirmação; Sim despausa, abandona a partida e credita as almas (venceu = false)
	var saldo_antes := Meta.saldo()
	mundo.xp_coletado = 250.0  # 25 almas na partida
	var res = Resultado.new()
	mundo.sv.add_child(res)
	res.montar(mundo)  # o mesmo que o mundo faz fora do modo de teste
	_tecla(KEY_ESCAPE)
	_ir_para(pausa, "santuario")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "confirmar_santuario", "Voltar ao santuário pede confirmação")
	_tecla(KEY_UP)
	_tecla(KEY_ENTER)  # Sim
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

	# 11. santuário: o ESC só abre a confirmação de sair (Não por padrão; Sim chama o gancho); o botão Ajustes abre o submenu.
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
		_tecla(KEY_ESCAPE)
		ok(pa.aberto and pa.tela == "confirmar_sair", "no santuário, ESC abre a confirmação de sair")
		ok(not get_tree().paused, "no santuário, ESC não mexe na árvore")
		_tecla(KEY_ENTER)  # padrão: Não
		ok(not pa.aberto and saiu == saidas_antes, "Não fecha a confirmação sem sair")
		_tecla(KEY_ESCAPE)
		_tecla(KEY_UP)
		_tecla(KEY_ENTER)  # Sim
		ok(saiu == saidas_antes + 1, "no santuário, Sim chama o gancho de saída")
		_tecla(KEY_ESCAPE)  # fecha
		ok(not pa.aberto, "o ESC fecha a confirmação de sair (no santuário)")
		altar._ajustes.pressed.emit()  # o botão Ajustes do santuário
		ok(pa.aberto and pa.tela == "ajustes", "o botão Ajustes do santuário abre o submenu")
		_tecla(KEY_ESCAPE)  # no santuário, ESC em Ajustes fecha (não há pausa por trás)
		ok(not pa.aberto, "no santuário, ESC em Ajustes fecha o submenu")
	altar.queue_free()

	# o save real e as opções reais não foram tocados
	ok(_md5(SAVE_REAL) == md5_save, "o save real (v2_progresso.cfg) não foi tocado")
	ok(_md5(OPCOES_REAL) == md5_opc, "as opções reais (opcoes.cfg) não foram tocadas")
	_limpar_saves()


func _limpar_saves() -> void:
	if FileAccess.file_exists(SAVE_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TESTE))


## Prints do menu (só o viewport): a pausa, Ajustes, Gráficos (rolada até uma opção com ajuda), Áudio, a confirmação de sair e
## o submenu no santuário.
func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	var sv: SubViewport = mundo.sv
	var pausa = _achar_pausa(sv)
	Config.g_aplicar_perfil("alto")
	_tecla(KEY_ESCAPE)
	await mundo.ap.foto(pasta.path_join("pausa_menu.png"))
	_ir_para(pausa, "ajustes")
	_tecla(KEY_ENTER)
	await mundo.ap.foto(pasta.path_join("pausa_ajustes.png"))
	_ir_para(pausa, "graficos")
	_tecla(KEY_ENTER)
	_ir_para(pausa, "g:op:sombras")
	await mundo.ap.foto(pasta.path_join("pausa_graficos.png"))
	_tecla(KEY_ESCAPE)
	_ir_para(pausa, "audio")
	_tecla(KEY_ENTER)
	await mundo.ap.foto(pasta.path_join("pausa_audio.png"))
	_tecla(KEY_ESCAPE)  # Áudio -> Ajustes
	_tecla(KEY_ESCAPE)  # Ajustes -> pausa (a pausa continua aberta)
	_ir_para(pausa, "sair")
	_tecla(KEY_ENTER)
	await mundo.ap.foto(pasta.path_join("pausa_confirmar_sair.png"))
	get_tree().paused = false
	mundo.queue_free()
	await get_tree().process_frame  # a janela volta à escala antes do santuário montar a dele (ver _testes)
	var altar = Altar.instantiate()
	add_child(altar)
	await get_tree().process_frame
	altar._ajustes.pressed.emit()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join("santuario_ajustes.png"))
	altar.queue_free()
	print("v2_pausa fotos em ", pasta)
