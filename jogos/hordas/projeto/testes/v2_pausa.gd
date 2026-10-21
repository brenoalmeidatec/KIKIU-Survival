extends Node
# Teste automático do menu de pausa da v2 (v2/pausa.gd, v2/ajustes_graficos.gd, ligado ao mundo e ao santuário). Usa saves
# TEMPORÁRIOS: a meta (user://teste_v2_pausa_meta.cfg) e as opções (user://teste_v2_pausa_opcoes.cfg). O save real
# (user://v2_progresso.cfg) e user://opcoes.cfg não são tocados, e a conferência por md5 garante isso.
# Confere: a pausa tem 5 itens (Continuar, Conquistas, Ajustes, Voltar ao santuário, Sair do jogo); ESC e Start pausam e despausam;
# Continuar fecha; na escolha de cartas e no baú o ESC abre a pausa por cima (e na morte não abre); Sair pede confirmação e só o
# Sim chama o gancho; a entrada vem pelo caminho da janela (Input.parse_input_event), o mesmo do jogador;
# Ajustes abre Gráficos (com CPU e GPU) e Áudio; trocar o perfil muda a config (e a sombra do mundo, ao vivo); Sombras,
# sliders, listas, Mostrar FPS e Detectar gravam pelo Config; Música e Efeitos mudam o volume (e o Som); o clique do mouse
# escolhe a linha; ESC dentro de Ajustes volta um nível; o hit-stop e a câmera lenta seguem depois de pausar; Voltar ao santuário
# despausa, abandona a partida (venceu = false) e credita as almas; perder o foco não pausa em headless; e no santuário o ESC
# é devolvido à navegação local, e o botão Ajustes abre o submenu.
# Tela cheia (linha e F11, com a pausa aberta ou fechada) e o Detalhe dinâmico (qualidade_auto) ficam fora do perfil: não viram
# personalizado. O Perfil tem só Baixo, Médio e Alto; o Detalhe dinâmico é uma linha própria logo abaixo, e o Perfil escolhido é o
# teto da subida. A queda por fps (qualidade_auto) vale só na memória: o arquivo não recebe o perfil caído. Save antigo
# (qualidade_auto ligada com o perfil Alto, o antigo "Dinâmico") vira Perfil Alto + Detalhe dinâmico Sim.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pausa.tscn  (imprime "v2_pausa falhas=0")
# Prints (com janela): godot --path jogos/hordas/projeto res://testes/v2_pausa.tscn -- --fotos=PASTA
#   grava pausa_menu, pausa_menu_detalhes, pausa_ajustes, pausa_graficos, pausa_graficos_topo, pausa_audio, pausa_creditos, pausa_confirmar_sair e santuario_ajustes (a janela inteira).
const Mundo := preload("res://v2/mundo.tscn")
const Altar := preload("res://v2/altar.tscn")
const Meta := preload("res://v2/meta.gd")
const Resultado := preload("res://v2/resultado_meta.gd")
const Pausa := preload("res://v2/pausa.gd")
const Sombras := preload("res://v2/sombras.gd")
const QualidadeAuto := preload("res://v2/qualidade_auto.gd")
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
	for c in [SAVE_TESTE, SAVE_TESTE + ".bak", SAVE_TESTE + ".tmp", OPCOES_TESTE]:
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
	var sv: SubViewport = mundo.ui
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
		_ids(pausa) == ["continuar", "conquistas", "ajustes", "santuario", "sair"],
		"a pausa tem 5 itens: Continuar, Conquistas, Ajustes, Voltar ao santuário, Sair (%s)" % str(_ids(pausa))
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
	Config.definir("qualidade_auto", false)  # o Perfil à mão só vale com o Detalhe dinâmico Não (com Sim ele fica travado, testado abaixo)
	_tecla(KEY_ESCAPE)
	_ir_para(pausa, "ajustes")
	_tecla(KEY_ENTER)
	ok(
		pausa.tela == "ajustes" and _ids(pausa) == ["graficos", "audio", "animacoes", "versao", "creditos", "voltar"],
		"Ajustes abre com Gráficos, Áudio, Reduzir animações, aviso de versão, Créditos e Voltar"
	)
	_ir_para(pausa, "graficos")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "graficos", "Gráficos abre a aba")
	var ids_g: Array = _ids(pausa)
	ok(
		"g:perfil" in ids_g and "g:fps" in ids_g and "g:avancado" in ids_g and not ("g:op:sombras" in ids_g),
		"a aba Gráficos tem perfil, FPS e o Avançado; as opções soltas ficam no Avançado"
	)
	_ir_para(pausa, "g:perfil")
	pausa._desenhar()
	var linha_perfil: Dictionary = pausa._itens_atuais[0]
	ok(str(linha_perfil.rotulo) == "Perfil" and bool(linha_perfil.get("icone", false)), "a linha Perfil leva o ícone ? e o nome é só Perfil (sem (?) no texto)")
	var icone_visivel := false
	for l in pausa._linhas:
		icone_visivel = icone_visivel or (bool(l["linha"].visible) and bool(l["icone"].visible))
	ok(icone_visivel, "o ícone ? aparece na linha Perfil")
	_tecla(KEY_RIGHT)  # alto -> baixo
	ok(Config.g_perfil() == "baixo", "trocar o perfil para Baixo muda a config (perfil = %s)" % Config.g_perfil())
	ok(str(Config.g("sombras")) == "baixa" and int(Config.g("limite_fps")) == 60, "o perfil Baixo põe sombras baixa e limite de 60 fps")
	ok(mundo.sombras.modo == Sombras.BAIXA, "a sombra do mundo acompanha o perfil ao vivo (graficos_mudou)")
	_ir_para(pausa, "g:avancado")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "avancado" and pausa._titulo.text == "AVANÇADO", "Avançado abre a tela das opções soltas")
	var cabs := 0
	for it in pausa._itens_atuais:
		if bool(it.get("cab", false)):
			cabs += 1
	ok(cabs == 2, "o Avançado tem as duas seções, CPU e GPU (cabeçalhos: %d)" % cabs)
	ok("g:op:sombras" in _ids(pausa) and "g:op:luz_relevo" in _ids(pausa) and "g:op:particulas_sim" in _ids(pausa), "o Avançado tem as opções do json")
	var linhas_cpu := 0
	var em_cpu := false
	for it in pausa._itens_atuais:
		if bool(it.get("cab", false)):
			em_cpu = str(it.rotulo).begins_with("CPU")
		elif em_cpu and str(it.get("id", "")).begins_with("g:op:"):
			linhas_cpu += 1
	ok(linhas_cpu == 2, "a CPU do Avançado tem as duas opções que a v2 lê (partículas, cálculo dos monstros): %d" % linhas_cpu)
	# com o Detalhe dinâmico ligado (o padrão) os detalhes ficam apagados: não mudam com Enter, setas nem clique, e a ajuda diz por quê
	ok(bool(Config.item("qualidade_auto").get("padrao", false)), "o Detalhe dinâmico vem ligado de fábrica (padrão)")
	Config.definir("qualidade_auto", true)
	pausa._desenhar()
	var todos_bloqueados := true
	for it in pausa._itens_atuais:
		if str(it.get("id", "")).begins_with("g:op:") and not bool(it.get("bloqueado", false)):
			todos_bloqueados = false
	ok(todos_bloqueados, "com o Detalhe dinâmico Sim, todos os detalhes do Avançado estão bloqueados (apagados)")
	_ir_para(pausa, "g:op:sombras")
	var sombras_antes := str(Config.g("sombras"))
	_tecla(KEY_RIGHT)
	_tecla(KEY_LEFT)
	_tecla(KEY_ENTER)
	pausa._acao_sel(1, true)  # o caminho do clique esquerdo
	pausa._acao_sel(-1, false)  # e o do direito
	ok(
		str(Config.g("sombras")) == sombras_antes and Config.g_perfil() == "baixo" and pausa.tela == "avancado",
		"bloqueado: setas, Enter e clique não mudam o detalhe nem viram Personalizado"
	)
	ok("Controlado pelo Detalhe dinâmico" in pausa._ajuda.text and "Desligue-o" in pausa._ajuda.text, "a ajuda do detalhe bloqueado diz que o dinâmico manda")
	ok(pausa._linhas[pausa.sel - pausa._topo]["rotulo"].get_theme_color("font_color").a < 0.7, "a linha bloqueada aparece apagada")
	Config.definir("qualidade_auto", false)  # desliga: tudo volta a ser editável
	pausa._desenhar()
	var algum_bloqueado := false
	for it in pausa._itens_atuais:
		if bool(it.get("bloqueado", false)):
			algum_bloqueado = true
	ok(not algum_bloqueado, "com o Detalhe dinâmico Não, os detalhes voltam a ser editáveis")
	_ir_para(pausa, "g:op:sombras")
	_tecla(KEY_RIGHT)  # baixa -> media
	ok(str(Config.g("sombras")) == "media" and mundo.sombras.modo == Sombras.MEDIA, "Sombras (lista) muda a config e a sombra do mundo")
	ok(_sel_id(pausa) == "g:op:sombras" and pausa._ajuda.text != "", "o rodapé mostra a ajuda da linha escolhida")
	_ir_para(pausa, "g:op:tremor_clarao")
	var tremor_antes := int(Config.g("tremor_clarao"))
	_tecla(KEY_LEFT)  # slider: passo de 25
	ok(
		int(Config.g("tremor_clarao")) == maxi(tremor_antes - 25, 0),
		"um slider muda pelo passo do json (%d -> %s)" % [tremor_antes, str(Config.g("tremor_clarao"))]
	)
	Config.g_temporario("tremor_clarao", 0)
	mundo.cam.tremor_t = 0.0
	mundo.cam.tremer(4.0, 0.3)
	ok(mundo.cam.tremor_t == 0.0, "a câmera não treme com Tremor e clarões em 0%")
	Config.g_temporario("tremor_clarao", 50)
	mundo.cam.tremer(4.0, 0.3)
	ok(is_equal_approx(mundo.cam.tremor_amp, 2.0) and mundo.cam.tremor_t > 0.0, "a câmera treme pela metade com 50%% (amp %s)" % str(mundo.cam.tremor_amp))
	mundo.cam.tremor_t = 0.0
	mundo.cam.tremor_amp = 0.0
	_ir_para(pausa, "g:op:particulas_sim")
	var part_antes := str(Config.g("particulas_sim"))
	_tecla(KEY_RIGHT)
	ok(str(Config.g("particulas_sim")) != part_antes, "Partículas (lista) muda a config")
	_tecla(KEY_ESCAPE)
	ok(pausa.tela == "graficos" and pausa.aberto, "ESC no Avançado volta para Gráficos")
	_ir_para(pausa, "g:fps")
	var fps_antes := bool(Config.v("mostrar_fps"))
	_tecla(KEY_ENTER)
	ok(bool(Config.v("mostrar_fps")) != fps_antes, "Mostrar FPS liga e desliga")
	pausa._fps_t = 0.0
	await get_tree().process_frame
	ok(pausa._fps.visible == (not fps_antes), "o contador de fps segue a opção ao vivo")

	# 6b. Tela cheia, Dinâmico (qualidade_auto) e Mostrar FPS são opções fora do perfil: mexer nelas não vira personalizado
	var ids_topo := _ids(pausa)
	ok(
		ids_topo.find("g:perfil") >= 0 and ids_topo.find("g:perfil") < ids_topo.find("g:tela") and ids_topo.find("g:tela") < ids_topo.find("g:fps"),
		"a aba tem Perfil, Tela cheia e Mostrar FPS nessa ordem"
	)
	ok(ids_topo.find("g:dinamico") == ids_topo.find("g:perfil") + 1, "a linha Detalhe dinâmico fica logo abaixo do Perfil")
	Config.g_aplicar_perfil("alto")
	_ir_para(pausa, "g:tela")
	var tela_antes := bool(Config.v("tela_cheia"))
	_tecla(KEY_ENTER)
	ok(bool(Config.v("tela_cheia")) != tela_antes and Config.g_perfil() == "alto", "Tela cheia liga e desliga pela linha, sem mudar o perfil")
	_tecla(KEY_F11)
	ok(bool(Config.v("tela_cheia")) == tela_antes and pausa.aberto, "F11 com o menu aberto volta a Tela cheia, e o menu continua aberto")
	# o Perfil só tem Baixo, Médio e Alto; o Detalhe dinâmico é a linha de baixo e não muda com as setas do Perfil
	_ir_para(pausa, "g:perfil")
	Config.definir("qualidade_auto", false)  # o Perfil à mão: só com o Detalhe dinâmico Não
	Config.g_aplicar_perfil("baixo")
	for nome in ["Médio", "Alto", "Baixo", "Médio"]:
		_tecla(KEY_RIGHT)
		ok(str(pausa._itens_atuais[pausa.sel].valor) == nome, "a seta do Perfil chega em %s (mostra %s)" % [nome, str(pausa._itens_atuais[pausa.sel].valor)])
		ok(not bool(Config.v("qualidade_auto")), "trocar o Perfil (%s) não mexe no Detalhe dinâmico" % nome)
	_tecla(KEY_LEFT)
	ok(str(pausa._itens_atuais[pausa.sel].valor) == "Baixo", "a seta para a esquerda volta um perfil")
	_tecla(KEY_LEFT)
	ok(str(pausa._itens_atuais[pausa.sel].valor) == "Alto", "o Perfil dá a volta: só os três fixos (sem Dinâmico entre o Alto e o Baixo)")
	ok(
		not ("?" in str(pausa._itens_atuais[pausa.sel].rotulo)) and bool(pausa._itens_atuais[pausa.sel].get("icone", false)),
		"o Perfil tem o ícone '?' (o nome é só Perfil)"
	)
	ok("Personalizado" in pausa._ajuda.text, "o rodapé do Perfil explica o Personalizado")
	# o Detalhe dinâmico: Sim/Não, com a ajuda no rodapé, e mexer nele não vira Personalizado
	Config.g_aplicar_perfil("medio")
	Config.definir("qualidade_auto", true)
	_ir_para(pausa, "g:dinamico")
	ok(
		str(pausa._itens_atuais[pausa.sel].rotulo) == "Detalhe dinâmico" and str(pausa._itens_atuais[pausa.sel].valor) == "Sim",
		"a linha Detalhe dinâmico existe e mostra Sim"
	)
	ok(
		"sem passar do Perfil escolhido" in pausa._ajuda.text and "travados" in pausa._ajuda.text,
		"o rodapé do Detalhe dinâmico explica o teto e que os detalhes ficam travados"
	)
	_tecla(KEY_ENTER)
	ok(not bool(Config.v("qualidade_auto")) and str(pausa._itens_atuais[pausa.sel].valor) == "Não", "Enter desliga o Detalhe dinâmico")
	ok(Config.g_perfil() == "medio", "mexer no Detalhe dinâmico não vira Personalizado (o perfil segue Médio)")
	_tecla(KEY_ENTER)
	ok(
		bool(Config.v("qualidade_auto")) and str(pausa._itens_atuais[pausa.sel].valor) == "Sim" and Config.g_perfil() == "medio",
		"Enter alterna de volta para Sim"
	)
	_tecla(KEY_LEFT)
	ok(not bool(Config.v("qualidade_auto")) and str(pausa._itens_atuais[pausa.sel].valor) == "Não", "a seta esquerda alterna a linha (Sim -> Não)")
	_tecla(KEY_RIGHT)
	ok(
		bool(Config.v("qualidade_auto")) and str(pausa._itens_atuais[pausa.sel].valor) == "Sim" and Config.g_perfil() == "medio",
		"a seta direita alterna a linha (Não -> Sim)"
	)
	# com o dinâmico Sim, só o Perfil (o seletor manual de detalhe) fica apagado; Detectar, Tela cheia, Mostrar FPS e interface seguem livres
	var apagadas: Array = []
	for it in pausa._itens_atuais:
		if bool(it.get("bloqueado", false)):
			apagadas.append(str(it.id))
	ok(apagadas == ["g:perfil"], "com o Detalhe dinâmico Sim, só o Perfil fica apagado na tela Gráficos (apagadas: %s)" % str(apagadas))
	ok(str(pausa._itens_atuais[pausa.sel - 1].valor) == "Médio", "o Perfil mostra só Médio enquanto o perfil não caiu")
	await _testar_perfil_travado(pausa)
	# o Detectar escolhe o Perfil e deixa o Detalhe dinâmico como está
	_ir_para(pausa, "g:detectar")
	_tecla(KEY_ENTER)
	ok(bool(Config.v("qualidade_auto")) and Config.g_perfil() == Config.g_detectar(), "Detectar escolhe o perfil da máquina e o Detalhe dinâmico segue Sim")

	# 6c. o Detalhe dinâmico (fps abaixo de 40 por 8 s) desce o perfil só na memória; o arquivo guarda o que o jogador escolheu
	pausa.fechar()  # a medição de FPS só vale durante a jogabilidade, sem o menu aberto
	Config.definir("qualidade_auto", true)  # o Detalhe dinâmico
	Config.g_aplicar_perfil("alto")
	mundo._qualidade_ligada = true  # o jogo de verdade (no teste o mundo fica desligado de propósito)
	for i in 500:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	ok(Config.g_perfil() == "medio" and mundo.sombras.modo == Sombras.MEDIA, "8 s com fps abaixo de 40 desce de Alto para Médio, e a sombra do mundo acompanha")
	var salvo := ConfigFile.new()
	salvo.load(OPCOES_TESTE)
	ok(str(salvo.get_value("graficos", "perfil", "")) == "alto", "a queda não grava: o arquivo continua com o perfil Alto")
	Config.definir("mostrar_fps", Config.v("mostrar_fps"))  # salvar outra opção não pode levar a queda para o arquivo
	salvo.load(OPCOES_TESTE)
	ok(
		str(salvo.get_value("graficos", "perfil", "")) == "alto" and str(salvo.get_value("graficos", "sombras", "")) == "alta",
		"salvar outra opção não leva a queda para o arquivo"
	)
	ok(Config.g_perfil() == "medio", "a queda vale na memória até o jogador mexer numa opção da aba")
	for i in 500:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	ok(Config.g_perfil() == "baixo" and mundo.sombras.modo == Sombras.BAIXA, "mais 8 s de fps baixo desce até Baixo")
	for i in 600:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	ok(Config.g_perfil() == "baixo", "no Baixo não desce mais")
	Config.g_aplicar_perfil("alto")
	ok(Config.g_perfil() == "alto" and Config.g("sombras") == "alta", "escolher Alto de novo tira a queda")
	Config.g_definir("max_inimigos", 300)  # personalizado
	for i in 600:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	ok(Config.g_perfil() == "personalizado", "o Personalizado não é derrubado pela baixa automática")
	Config.g_aplicar_perfil("alto")
	Config.definir("qualidade_auto", false)
	for i in 600:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	ok(Config.g_perfil() == "alto", "com Baixar a qualidade desligado, o fps baixo não muda nada")
	Config.definir("qualidade_auto", true)
	mundo._qualidade_ligada = false
	for i in 600:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	ok(Config.g_perfil() == "alto", "fora do jogo de verdade (testes, medições) a baixa não age")
	Config.g_aplicar_perfil("alto")
	await _testar_teto_e_migracao(mundo, pausa)
	_testar_janelas_qualidade(mundo, pausa)

	# 6d. a contagem sozinha (v2/qualidade_auto.gd): 8 s abaixo de 40 fps desce um degrau; 40 fps zera; Baixo e Personalizado não descem
	var qa := QualidadeAuto.new()
	var antes_de_8s := ""
	for i in 15:
		antes_de_8s += qa.passo(0.5, 30.0, "alto")
	ok(antes_de_8s == "" and qa.passo(0.5, 30.0, "alto") == "medio", "7,5 s abaixo de 40 fps não desce; no 8º segundo desce para médio")
	qa.passo(0.5, 40.0, "medio")  # 40 fps ainda não é travado: zera a contagem
	var depois_de_zerar := ""
	for i in 15:
		depois_de_zerar += qa.passo(0.5, 30.0, "medio")
	ok(depois_de_zerar == "" and qa.passo(0.5, 30.0, "medio") == "baixo", "40 fps zera a contagem: são outros 8 s para descer de médio para baixo")
	var sem_teto := QualidadeAuto.new()
	var sobe_ate_teto := ""
	for i in 60:
		sobe_ate_teto += sem_teto.passo(0.5, 60.0, "baixo", 55.0, "medio")
	var passa_do_teto := ""
	for i in 400:
		passa_do_teto += sem_teto.passo(0.5, 60.0, "medio", 55.0, "medio")
	ok(sobe_ate_teto == "medio" and passa_do_teto == "", "com o teto em Médio, a subida para no Médio")
	var sem_descer := ""
	for i in 100:
		sem_descer += qa.passo(0.5, 30.0, "baixo") + qa.passo(0.5, 30.0, "personalizado")
	ok(sem_descer == "", "Baixo e Personalizado nunca descem")
	# a subida: 30 s com o fps no alvo sobe um degrau; fps abaixo do alvo zera; no Alto não sobe; subiu e travou logo, a espera dobra
	var qs := QualidadeAuto.new()
	var antes_de_30s := ""
	for i in 59:
		antes_de_30s += qs.passo(0.5, 60.0, "baixo")
	ok(antes_de_30s == "" and qs.passo(0.5, 60.0, "baixo") == "medio", "29,5 s com fps no alvo não sobe; aos 30 s sobe de Baixo para Médio")
	qs.passo(0.5, 50.0, "medio")  # abaixo do alvo, mas acima de 40: nem sobe nem desce, e zera a contagem de subida
	var depois_de_zerar_sobe := ""
	for i in 59:
		depois_de_zerar_sobe += qs.passo(0.5, 60.0, "medio")
	ok(depois_de_zerar_sobe == "" and qs.passo(0.5, 60.0, "medio") == "alto", "fps abaixo do alvo zera a subida: outros 30 s para Médio -> Alto")
	var sem_subir := ""
	for i in 80:  # 40 s: dentro da janela de 60 s de ir e voltar
		sem_subir += qs.passo(0.5, 60.0, "alto")
	ok(sem_subir == "", "no Alto não sobe mais")
	var travou := ""
	for i in 15:
		travou += qs.passo(0.5, 20.0, "alto")
	ok(travou == "" and qs.passo(0.5, 20.0, "alto") == "medio", "subiu e travou: desce de novo")
	var espera_dobrada := ""
	for i in 59:
		espera_dobrada += qs.passo(0.5, 60.0, "medio")
	ok(espera_dobrada == "" and qs.passo(0.5, 60.0, "medio") == "", "depois de subir e travar logo, 30 s não bastam para subir (a espera dobrou para 60 s)")
	var sobe_60s := ""
	for i in 60:
		sobe_60s += qs.passo(0.5, 60.0, "medio")
	ok(sobe_60s == "alto", "com a espera dobrada, aos 60 s firmes sobe")
	# 6e. limite de fps baixo (30): com o alvo em 27,6, rodar a 30 é o jogo no próprio limite e não conta como travado
	var no_limite := QualidadeAuto.new()
	var desceu_no_limite := ""
	for i in 60:  # 30 s a 30 fps
		desceu_no_limite += no_limite.passo(0.5, 30.0, "alto", 27.6)
	ok(desceu_no_limite == "", "com limite de 30 fps, rodar a 30 não desce o perfil (30 s)")
	var sobe_no_limite := QualidadeAuto.new()
	var sobe_limite := ""
	for i in 60:  # 30 s firmes no alvo: sobem de Baixo para Médio
		sobe_limite += sobe_no_limite.passo(0.5, 30.0, "baixo", 27.6)
	ok(sobe_limite == "medio", "com limite de 30 fps, 30 s no alvo sobem o perfil")
	var abaixo_do_alvo := QualidadeAuto.new()
	var desce_abaixo := ""
	for i in 17:  # 8,5 s a 25 fps, abaixo do alvo de 27,6
		desce_abaixo += abaixo_do_alvo.passo(0.5, 25.0, "alto", 27.6)
	ok(desce_abaixo == "medio", "com limite de 30 fps, 8 s abaixo do alvo desce o perfil")
	pausa.pausar()
	pausa._ir("graficos")  # devolve ao menu que estava aberto antes das medições de jogabilidade
	# 6f. as opções de CPU mudam a conta da v2: o Máximo de inimigos saiu do menu (a v2 não o lê) e o recálculo da separação segue
	var teto_base: int = mundo.combate.diretor.teto()
	Config.g_definir("max_inimigos", 40)  # mexida à mão (ou de um json antigo), não derruba o teto da v2
	ok(
		teto_base > 40 and mundo.combate.diretor.teto() == teto_base,
		"o teto da v2 ignora o Máximo de inimigos (teto %d com a opção em 40)" % mundo.combate.diretor.teto()
	)
	for par in [[2.0, 6], [0.5, 2], [1.0, 3]]:
		Config.g_definir("calculo_monstros", par[0])
		ok(mundo.combate._passo_sep() == par[1], "Cálculo dos monstros %s: a separação recalcula a cada %d quadros" % [str(par[0]), par[1]])
	Config.g_aplicar_perfil("alto")
	_ir_para(pausa, "g:detectar")
	_tecla(KEY_ENTER)
	ok(pausa._graficos.mensagem != "", "Detectar pela máquina dá um aviso (%s)" % pausa._graficos.mensagem)
	_ir_para(pausa, "g:avancado")
	_tecla(KEY_ENTER)
	ok(_sel_id(pausa) == "g:op:particulas_sim", "ao abrir o Avançado o foco cai na 1ª opção da CPU, não no cabeçalho (foco em %s)" % _sel_id(pausa))
	var todas_lidas := true
	for it in pausa._itens_atuais:
		var iid: String = str(it.get("id", ""))
		if iid.begins_with("g:op:") and not pausa._graficos.lida_na_v2(iid.substr(5)):
			todas_lidas = false
	ok(
		(
			todas_lidas
			and not ("g:op:escala_render" in _ids(pausa))
			and not ("g:op:max_inimigos" in _ids(pausa))
			and "g:op:calculo_monstros" in _ids(pausa)
			and not ("g:op:lod_monstros" in _ids(pausa))
			and not ("g:op:restos_chao" in _ids(pausa))
		),
		"a aba só mostra opções que a v2 lê (sem escala de render, detalhe fora da tela, tempo dos restos nem máximo de inimigos: a v2 não lê essas)"
	)
	_ir_para(pausa, "g:op:luz_relevo")
	ok(
		not str(pausa._itens_atuais[pausa.sel].rotulo).ends_with("*") and not str(pausa._itens_atuais[pausa.sel].ajuda).contains("Etapa"),
		"a ajuda das opções não cita etapa nem marca com *"
	)
	_tecla(KEY_ESCAPE)  # Avançado -> Gráficos
	_tecla(KEY_ESCAPE)  # ESC dentro de Gráficos volta a Ajustes (um nível)
	ok(pausa.tela == "ajustes" and pausa.aberto, "ESC em Gráficos volta um nível: a Ajustes, sem fechar a pausa")

	# 6b. Créditos: uma linha por crédito, com o aviso da licença no rodapé (o aviso do Godot é obrigação da licença MIT)
	_ir_para(pausa, "creditos")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "creditos" and pausa._titulo.text == "CRÉDITOS", "Créditos abre a tela")
	var motor_ok := false
	var vazios := 0
	for it in pausa._itens_atuais:
		if str(it.id).begins_with("c:") and (str(it.rotulo) == "" or str(it.ajuda) == ""):
			vazios += 1
		if str(it.rotulo) == "Motor do jogo" and str(it.ajuda).contains("MIT") and str(it.ajuda).contains("Juan Linietsky"):
			motor_ok = true
	ok(motor_ok and vazios == 0, "os créditos trazem o aviso da licença MIT do Godot e nenhuma linha vazia")
	_ir_para(pausa, "c:2")
	ok(pausa._ajuda.text.contains("Godot Engine"), "o rodapé mostra o aviso da linha escolhida")
	_tecla(KEY_ESCAPE)
	ok(pausa.tela == "ajustes" and pausa.aberto, "ESC em Créditos volta a Ajustes")

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

	# 8. o clique do mouse escolhe a linha (Ajustes é a linha 3 do menu: a lista começa no topo)
	_tecla(KEY_ESCAPE)
	pausa.mouse_fn = Callable(self, "_mouse_teste")
	_mouse_alvo = Vector2(354, 55 + 118 + 2 * 36 + 16)  # Ajustes: linha 3 (PAINEL, LINHA0, LINHA_H de pausa.gd)
	_clique(_mouse_alvo)
	ok(pausa.tela == "ajustes", "clique com o mouse abre a linha clicada")
	_tecla(KEY_ESCAPE)
	_tecla(KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused, "ESC fecha o menu depois do clique")

	# 9. Voltar ao santuário: confirmação; Sim despausa, abandona a partida e credita as almas (venceu = false)
	var saldo_antes := Meta.saldo()
	mundo.xp_coletado = 250.0  # 25 almas na partida
	var res = Resultado.new()
	mundo.ui.add_child(res)
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

	# 10b. F11 com a pausa fechada liga a tela cheia pela Antena e não abre o menu
	var tela_fechada := bool(Config.v("tela_cheia"))
	_tecla(KEY_F11)
	ok(
		bool(Config.v("tela_cheia")) != tela_fechada and not pausa.aberto and not get_tree().paused,
		"F11 com a pausa fechada liga a tela cheia e não abre o menu"
	)
	_tecla(KEY_F11)
	ok(bool(Config.v("tela_cheia")) == tela_fechada, "F11 de novo volta ao que estava")

	# 11. santuário: a pausa devolve ESC à navegação local; Ajustes fecha e restaura foco.
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
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		ok(not pa.entrada(esc), "pausa fechada do santuário devolve ESC à navegação local")
		ok(not pa.aberto and saiu == saidas_antes, "santuário nunca abre Sair ao receber ESC")
		ok(not get_tree().paused, "santuário não pausa a árvore")
		altar._ajustes.pressed.emit()  # o botão Ajustes do santuário
		ok(pa.aberto and pa.tela == "ajustes", "o botão Ajustes do santuário abre o submenu")
		# o mesmo menu, sem partida (título e santuário): Dinâmico Sim trava o Perfil também aqui
		Config.g_aplicar_perfil("medio")
		Config.definir("qualidade_auto", true)
		pa._ir("graficos")
		_ir_para(pa, "g:perfil")
		_tecla(KEY_RIGHT)
		_tecla(KEY_ENTER)
		ok(
			Config.g_perfil_escolhido() == "medio" and bool(pa._itens_atuais[pa.sel].get("bloqueado", false)),
			"no menu sem partida, Dinâmico Sim também trava o Perfil"
		)
		_ir_para(pa, "g:avancado")
		_tecla(KEY_ENTER)
		_tecla(KEY_RIGHT)
		ok(Config.g_perfil() == "medio" and pa.tela == "avancado", "e as opções do Avançado")
		pa._ir("ajustes")
		_tecla(KEY_ESCAPE)  # no santuário, ESC em Ajustes fecha (não há pausa por trás)
		ok(not pa.aberto, "no santuário, ESC em Ajustes fecha o submenu")
		ok(get_viewport().gui_get_focus_owner() == altar._ajustes, "fechar Ajustes restaura foco no botão")
	altar.queue_free()

	# o save real e as opções reais não foram tocados
	ok(_md5(SAVE_REAL) == md5_save, "o save real (v2_progresso.cfg) não foi tocado")
	ok(_md5(OPCOES_REAL) == md5_opc, "as opções reais (opcoes.cfg) não foram tocadas")
	_limpar_saves()


func _limpar_saves() -> void:
	for c in [SAVE_TESTE, SAVE_TESTE + ".bak", SAVE_TESTE + ".tmp"]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))


## Prints do menu (só o viewport): a pausa, Ajustes, Gráficos (rolada até uma opção com ajuda), Áudio, a confirmação de sair e
## o submenu no santuário.
func _testar_janelas_qualidade(mundo, pausa) -> void:
	mundo._qualidade_ligada = true
	Config.definir("qualidade_auto", true)
	Config.g_aplicar_perfil("alto")  # o teto
	Config.g_perfil_temporario("medio")  # e a queda de agora, para a subida ter para onde ir
	for estado in ["escolha", "bau", "vitoria"]:
		mundo.combate.jogo = estado
		mundo.combate.pausado = true
		mundo._baixar_qualidade(40.0, 60.0)
		mundo._baixar_qualidade(10.0, 20.0)
		ok(Config.g_perfil() == "medio", "o Dinâmico não mede a tela estática de " + estado)
	mundo.combate.jogo = "jogando"
	mundo._baixar_qualidade(40.0, 60.0)
	ok(Config.g_perfil() == "medio", "a flag de pausa também interrompe a medição")
	mundo.combate.pausado = false
	mundo._baixar_qualidade(20.0, 60.0)
	mundo.combate.jogo = "escolha"
	mundo._baixar_qualidade(40.0, 60.0)
	mundo.combate.jogo = "jogando"
	mundo._baixar_qualidade(15.0, 60.0)
	ok(Config.g_perfil() == "medio", "20 s antes das cartas não somam com 15 s depois: a subida pede FPS contínuo")
	mundo._baixar_qualidade(15.0, 60.0)
	ok(Config.g_perfil() == "alto", "30 s contínuos depois das cartas permitem a subida")
	mundo._baixar_qualidade(5.0, 20.0)
	pausa.pausar()
	pausa.fechar()  # durante a pausa a árvore não chama o mundo; o sinal de fechamento deve limpar o intervalo
	mundo._baixar_qualidade(4.0, 20.0)
	ok(Config.g_perfil() == "alto", "5 s lentos antes da pausa não somam com 4 s depois")
	mundo._baixar_qualidade(4.0, 20.0)
	ok(Config.g_perfil() == "medio", "8 s lentos contínuos depois da pausa permitem a queda")
	var espera_antes: float = mundo._qualidade._espera
	pausa.pausar()
	pausa.fechar()
	ok(espera_antes > QualidadeAuto.SEGUNDOS_SUBIR and mundo._qualidade._espera == espera_antes, "pausar limpa a contagem sem apagar a espera anti-oscilação")
	mundo._qualidade_ligada = false
	Config.g_aplicar_perfil("alto")


## Clique completo com o botão dado: a ação do menu é no soltar.
func _clique_botao(pos: Vector2, botao: MouseButton) -> void:
	for pressionado in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = botao
		e.pressed = pressionado
		e.position = pos
		_enviar(e)


## Feedback do Alisson (build de 20/10): "marcar Sim em Detalhe dinâmico não está travando o seletor manual de detalhes". O seletor manual
## é o Perfil (Baixo, Médio e Alto fixam todos os detalhes de uma vez) tanto quanto as opções soltas do Avançado. O teste faz o caminho dele,
## tudo pela entrada da janela: teclado, controle e mouse (esquerdo e direito), em cada Perfil, na tela Gráficos e no Avançado, e de novo
## depois de reabrir o jogo (Config.recarregar). No código antigo o Perfil mudava com Sim e este teste falhava.
func _testar_perfil_travado(pausa) -> void:
	var mouse_antes: Callable = pausa.mouse_fn
	pausa.mouse_fn = Callable(self, "_mouse_teste")
	ok(bool(Config.v("qualidade_auto")) and pausa.tela == "graficos", "travar o Perfil: parte da tela Gráficos com o dinâmico Sim")
	var x_linha: float = Pausa.PAINEL.position.x + 120.0
	var y_perfil: float = Pausa.PAINEL.position.y + Pausa.LINHA0 + 16.0
	for nome in ["baixo", "medio", "alto"]:
		Config.g_aplicar_perfil(nome)
		pausa._ir("graficos")
		_ir_para(pausa, "g:perfil")
		var ids_antes: Array = _ids(pausa)
		for gesto in ["direita", "esquerda", "enter", "pad_direita", "pad_esquerda", "pad_a", "mouse_esq", "mouse_dir"]:
			match gesto:
				"direita":
					_tecla(KEY_RIGHT)
				"esquerda":
					_tecla(KEY_LEFT)
				"enter":
					_tecla(KEY_ENTER)
				"pad_direita":
					_pad(JOY_BUTTON_DPAD_RIGHT)
				"pad_esquerda":
					_pad(JOY_BUTTON_DPAD_LEFT)
				"pad_a":
					_pad(JOY_BUTTON_A)
				"mouse_esq":
					_mouse_alvo = Vector2(x_linha, y_perfil)
					_clique_botao(_mouse_alvo, MOUSE_BUTTON_LEFT)
				"mouse_dir":
					_clique_botao(_mouse_alvo, MOUSE_BUTTON_RIGHT)
			ok(
				Config.g_perfil_escolhido() == nome and Config.g_perfil() == nome and pausa.tela == "graficos" and _ids(pausa) == ids_antes,
				"Dinâmico Sim, Perfil %s: %s não muda o Perfil (agora %s)" % [nome, gesto, Config.g_perfil_escolhido()]
			)
		ok(bool(pausa._itens_atuais[pausa.sel].get("bloqueado", false)) and _sel_id(pausa) == "g:perfil", "o Perfil %s aparece bloqueado" % nome)
		ok(
			"Travado" in pausa._ajuda.text and "Detalhe dinâmico" in pausa._ajuda.text and "Desligue" in pausa._ajuda.text,
			"o rodapé do Perfil travado diz que o dinâmico manda e como destravar"
		)
		ok(pausa._linhas[0]["rotulo"].get_theme_color("font_color").a < 0.7, "a linha do Perfil bloqueado é desenhada apagada")
		# o Avançado, pelo mesmo caminho (o clique do mouse numa linha de detalhe)
		var sombras_antes := str(Config.g("sombras"))
		_ir_para(pausa, "g:avancado")
		_tecla(KEY_ENTER)
		_mouse_alvo = Vector2(x_linha, Pausa.PAINEL.position.y + Pausa.LINHA0 + 1 * Pausa.LINHA_H + 16.0)  # a 1ª opção (a 0 é o cabeçalho CPU)
		_clique_botao(_mouse_alvo, MOUSE_BUTTON_LEFT)
		_clique_botao(_mouse_alvo, MOUSE_BUTTON_RIGHT)
		_tecla(KEY_RIGHT)
		_pad(JOY_BUTTON_DPAD_LEFT)
		_pad(JOY_BUTTON_A)
		ok(
			pausa.tela == "avancado" and Config.g_perfil() == nome and str(Config.g("sombras")) == sombras_antes,
			"Dinâmico Sim, Perfil %s: clique, setas e A no Avançado não mudam nenhum detalhe (agora %s)" % [nome, Config.g_perfil()]
		)
		_tecla(KEY_ESCAPE)  # Avançado -> Gráficos
	# reabrir o jogo: o arquivo manda e o Perfil segue travado com o dinâmico Sim
	Config.g_aplicar_perfil("medio")
	Config.recarregar()
	pausa._ir("graficos")
	ok(
		bool(pausa._graficos.itens()[0].get("bloqueado", false)) and bool(Config.v("qualidade_auto")),
		"depois de reabrir o jogo o Perfil segue travado com o dinâmico Sim"
	)
	_tecla(KEY_RIGHT)
	ok(Config.g_perfil_escolhido() == "medio", "depois de reabrir o jogo a seta não muda o Perfil")
	# ligar na hora: Não -> Sim trava o que estava livre
	_ir_para(pausa, "g:dinamico")
	_tecla(KEY_ENTER)
	ok(not bool(Config.v("qualidade_auto")) and not bool(pausa._graficos.itens()[0].get("bloqueado", false)), "Dinâmico Não: o Perfil fica livre")
	_ir_para(pausa, "g:perfil")
	_tecla(KEY_RIGHT)
	ok(Config.g_perfil_escolhido() == "alto" and Config.g_perfil() == "alto", "Dinâmico Não: a seta troca o Perfil (Médio -> Alto)")
	_ir_para(pausa, "g:dinamico")
	_tecla(KEY_ENTER)
	ok(bool(Config.v("qualidade_auto")) and bool(pausa._graficos.itens()[0].get("bloqueado", false)), "ligar na hora (Não -> Sim) trava o Perfil")
	_ir_para(pausa, "g:perfil")
	_tecla(KEY_RIGHT)
	ok(Config.g_perfil_escolhido() == "alto", "recém ligado, a seta não troca o Perfil: o Alto fica como teto")
	# Personalizado + ligar o dinâmico: sem Perfil para escolher e sem Personalizado com ele ligado, então a máquina escolhe o teto
	_ir_para(pausa, "g:dinamico")
	_tecla(KEY_ENTER)  # Não
	Config.g_definir("max_inimigos", 300)  # Personalizado (o jogador mexeu num detalhe à mão)
	ok(Config.g_perfil() == "personalizado", "montado à mão: Personalizado")
	_tecla(KEY_ENTER)  # Sim
	ok(
		bool(Config.v("qualidade_auto")) and Config.g_perfil_escolhido() == Config.g_detectar(),
		"ligar o dinâmico estando em Personalizado aplica o perfil da máquina (sem Perfil travado em Personalizado)"
	)
	Config.g_aplicar_perfil("medio")
	pausa._ir("graficos")
	pausa.mouse_fn = mouse_antes


## O Perfil escolhido é o teto do Detalhe dinâmico, o Perfil mostra "(dinâmico)" quando o fps o derrubou e o save antigo migra.
func _testar_teto_e_migracao(mundo, pausa) -> void:
	mundo._qualidade = QualidadeAuto.new()
	mundo._qualidade_ligada = true
	mundo.combate.jogo = "jogando"
	Config.definir("qualidade_auto", true)
	Config.g_aplicar_perfil("medio")
	for i in 500:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	ok(Config.g_perfil() == "baixo" and Config.g_perfil_escolhido() == "medio", "Médio + dinâmico desce para Baixo, e o escolhido segue Médio")
	var linhas: Array = pausa._graficos.itens()
	ok(str(linhas[0].valor) == "Baixo (dinâmico)", "o Perfil mostra o de agora e '(dinâmico)' quando desceu (mostra %s)" % str(linhas[0].valor))
	for i in 600:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	ok(Config.g_perfil() == "baixo", "no Baixo com o dinâmico ligado não há para onde descer")
	for i in 2000:  # 33 s no alvo: sobe um degrau
		mundo._baixar_qualidade(1.0 / 60.0, 60.0)
	ok(
		Config.g_perfil() == "medio" and str(pausa._graficos.itens()[0].valor) == "Médio",
		"fps firme sobe de volta ao Médio e o Perfil volta a mostrar só Médio"
	)
	for i in 20000:  # mais de 5 min de fps ótimo: o Alto não é do jogador, não sobe
		mundo._baixar_qualidade(1.0 / 60.0, 60.0)
	ok(Config.g_perfil() == "medio", "o Perfil escolhido é o teto: Médio nunca sobe para Alto")
	for i in 500:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	ok(Config.g_perfil() == "baixo", "cai de novo para Baixo")
	pausa._graficos.agir("perfil", 1)  # com o dinâmico Sim o Perfil é teto travado: a seta não muda nada nem tira a queda
	ok(
		Config.g_perfil() == "baixo" and Config.g_perfil_escolhido() == "medio" and bool(Config.v("qualidade_auto")),
		"com o dinâmico Sim a seta do Perfil não mexe no teto nem na queda"
	)
	Config.definir("qualidade_auto", false)
	pausa._graficos.agir("perfil", 1)  # as setas partem do escolhido (Médio), não do Baixo caído
	ok(Config.g_perfil() == "alto" and Config.g_perfil_escolhido() == "alto", "a seta do Perfil parte do escolhido (Médio -> Alto) e tira a queda")
	Config.definir("qualidade_auto", true)
	Config.g_aplicar_perfil("medio")
	for i in 500:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	pausa._graficos.agir("dinamico", 1)
	ok(not bool(Config.v("qualidade_auto")) and Config.g_perfil() == "medio", "desligar o Detalhe dinâmico com o perfil caído volta na hora ao escolhido")
	for i in 600:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	ok(Config.g_perfil() == "medio", "desligado, o fps baixo não derruba o perfil")
	Config.definir("qualidade_auto", true)
	Config.g_definir("max_inimigos", 300)  # Personalizado
	for i in 600:
		mundo._baixar_qualidade(1.0 / 60.0, 30.0)
	ok(
		Config.g_perfil() == "personalizado" and str(pausa._graficos.itens()[0].valor) == "Personalizado",
		"no Personalizado o dinâmico não age e o Perfil mostra Personalizado"
	)
	mundo._qualidade_ligada = false
	# save antigo: qualidade_auto ligada + perfil Alto (o antigo "Dinâmico") = Perfil Alto + Detalhe dinâmico Sim; os outros casos ficam como estavam
	var casos := [
		["alto", true, "Alto", "Sim"],
		["alto", false, "Alto", "Não"],
		["medio", true, "Médio", "Sim"],
		["baixo", false, "Baixo", "Não"],
		["personalizado", true, "Personalizado", "Não"]
	]
	for c in casos:
		var cfg := ConfigFile.new()
		cfg.set_value("graficos", "perfil", c[0])
		cfg.set_value("graficos", "base", c[0])
		cfg.set_value("opcoes", "qualidade_auto", c[1])
		cfg.save(OPCOES_TESTE)
		Config.recarregar()
		var l: Array = pausa._graficos.itens()
		ok(
			str(l[0].valor) == c[2] and str(l[1].valor) == c[3] and Config.g_perfil_escolhido() == c[0],
			(
				"save antigo (%s, qualidade_auto %s) abre como Perfil %s e Detalhe dinâmico %s (mostra %s e %s)"
				% [c[0], str(c[1]), c[2], c[3], str(l[0].valor), str(l[1].valor)]
			)
		)
	# Personalizado + dinâmico ligado (montado à mão antes): abre com o dinâmico Não e o que ele montou fica editável
	var pers := ConfigFile.new()
	pers.set_value("graficos", "perfil", "personalizado")
	pers.set_value("graficos", "base", "alto")
	pers.set_value("graficos", "sombras", "baixa")
	pers.save(OPCOES_TESTE)  # sem qualidade_auto salvo: o padrão (Sim) também não pode ficar com o Personalizado
	Config.recarregar()
	ok(
		not bool(Config.v("qualidade_auto")) and Config.g_perfil() == "personalizado" and str(Config.g("sombras")) == "baixa",
		"save Personalizado sem a opção salva abre com o dinâmico Não e mantém o montado à mão"
	)
	var salvo_pers := ConfigFile.new()
	salvo_pers.load(OPCOES_TESTE)
	ok(not bool(salvo_pers.get_value("opcoes", "qualidade_auto", true)), "e grava o dinâmico como Não (a migração não repete)")
	ok(not bool(pausa._graficos.itens_avancado()[1].get("bloqueado", false)), "no save Personalizado os detalhes abrem editáveis")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OPCOES_TESTE))
	Config.recarregar()
	ok(bool(Config.v("qualidade_auto")), "sem nada salvo (máquina nova) o Detalhe dinâmico vem Sim")
	Config.g_aplicar_perfil("alto")
	await get_tree().process_frame


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	var sv: SubViewport = mundo.ui
	var pausa = _achar_pausa(sv)
	Config.g_aplicar_perfil("alto")
	_tecla(KEY_ESCAPE)
	await mundo.ap.foto(pasta.path_join("pausa_menu.png"))
	_tecla(KEY_TAB)  # a tabela de detalhes do SUA BUILD: os quadros laterais mantêm o topo e a altura do menu
	await mundo.ap.foto(pasta.path_join("pausa_menu_detalhes.png"))
	_tecla(KEY_TAB)
	_ir_para(pausa, "ajustes")
	_tecla(KEY_ENTER)
	await mundo.ap.foto(pasta.path_join("pausa_ajustes.png"))
	_ir_para(pausa, "graficos")
	_tecla(KEY_ENTER)
	Config.definir("qualidade_auto", true)
	Config.g_aplicar_perfil("alto")
	_ir_para(pausa, "g:dinamico")  # a linha Detalhe dinâmico, com a ajuda no rodapé
	await mundo.ap.foto(pasta.path_join("pausa_graficos_topo.png"))
	_ir_para(pausa, "g:avancado")
	await mundo.ap.foto(pasta.path_join("pausa_graficos.png"))
	_tecla(KEY_ENTER)
	await mundo.ap.foto(pasta.path_join("pausa_avancado_cpu.png"))  # a CPU inteira, no topo da lista
	_ir_para(pausa, "g:op:sombras")
	await mundo.ap.foto(pasta.path_join("pausa_avancado.png"))
	_ir_para(pausa, "g:op:limite_fps")
	await mundo.ap.foto(pasta.path_join("pausa_avancado_gpu.png"))
	_tecla(KEY_ESCAPE)
	_tecla(KEY_ESCAPE)
	_ir_para(pausa, "audio")
	_tecla(KEY_ENTER)
	await mundo.ap.foto(pasta.path_join("pausa_audio.png"))
	_tecla(KEY_ESCAPE)  # Áudio -> Ajustes
	_ir_para(pausa, "creditos")
	_tecla(KEY_ENTER)
	_ir_para(pausa, "c:2")
	await mundo.ap.foto(pasta.path_join("pausa_creditos.png"))
	_tecla(KEY_ESCAPE)  # Créditos -> Ajustes
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
