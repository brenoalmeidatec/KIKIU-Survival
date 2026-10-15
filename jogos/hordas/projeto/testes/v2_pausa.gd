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
# é devolvido à navegação local, e o botão Ajustes abre o submenu.
# Tela cheia (linha e F11, com a pausa aberta ou fechada) e Baixar a qualidade se travar ficam fora do perfil: não viram
# personalizado. A queda por fps (qualidade_auto) vale só na memória: o arquivo não recebe o perfil caído.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pausa.tscn  (imprime "v2_pausa falhas=0")
# Prints (com janela): godot --path jogos/hordas/projeto res://testes/v2_pausa.tscn -- --fotos=PASTA
#   grava pausa_menu, pausa_ajustes, pausa_graficos, pausa_graficos_topo, pausa_audio, pausa_creditos, pausa_confirmar_sair e santuario_ajustes (só o viewport).
const Mundo := preload("res://v2/mundo.tscn")
const Altar := preload("res://v2/altar.tscn")
const Meta := preload("res://v2/meta.gd")
const Resultado := preload("res://v2/resultado_meta.gd")
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
	ok(
		pausa.tela == "ajustes" and _ids(pausa) == ["graficos", "audio", "versao", "creditos", "voltar"],
		"Ajustes abre com Gráficos, Áudio, aviso de versão, Créditos e Voltar"
	)
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
	_ir_para(pausa, "g:fps")
	var fps_antes := bool(Config.v("mostrar_fps"))
	_tecla(KEY_ENTER)
	ok(bool(Config.v("mostrar_fps")) != fps_antes, "Mostrar FPS liga e desliga")
	pausa._fps_t = 0.0
	await get_tree().process_frame
	ok(pausa._fps.visible == (not fps_antes), "o contador de fps segue a opção ao vivo")

	# 6b. Tela cheia, Baixar a qualidade e Mostrar FPS são opções fora do perfil: mexer nelas não vira personalizado
	var ids_topo := _ids(pausa)
	ok(
		ids_topo.find("g:tela") >= 0 and ids_topo.find("g:tela") < ids_topo.find("g:qualidade") and ids_topo.find("g:qualidade") < ids_topo.find("g:fps"),
		"a aba tem Tela cheia, Baixar a qualidade e Mostrar FPS no topo, nessa ordem"
	)
	Config.g_aplicar_perfil("alto")
	_ir_para(pausa, "g:tela")
	var tela_antes := bool(Config.v("tela_cheia"))
	_tecla(KEY_ENTER)
	ok(bool(Config.v("tela_cheia")) != tela_antes and Config.g_perfil() == "alto", "Tela cheia liga e desliga pela linha, sem mudar o perfil")
	_tecla(KEY_F11)
	ok(bool(Config.v("tela_cheia")) == tela_antes and pausa.aberto, "F11 com o menu aberto volta a Tela cheia, e o menu continua aberto")
	_ir_para(pausa, "g:qualidade")
	var qual_antes := bool(Config.v("qualidade_auto"))
	_tecla(KEY_ENTER)
	ok(bool(Config.v("qualidade_auto")) != qual_antes and Config.g_perfil() == "alto", "Baixar a qualidade liga e desliga pela linha, sem mudar o perfil")
	_tecla(KEY_ENTER)
	ok(bool(Config.v("qualidade_auto")) == qual_antes, "Baixar a qualidade volta ao valor de antes")

	# 6c. a baixa automática (fps abaixo de 40 por 8 s) desce o perfil só na memória; o arquivo guarda o que o jogador escolheu
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
	var sem_descer := ""
	for i in 100:
		sem_descer += qa.passo(0.5, 30.0, "baixo") + qa.passo(0.5, 30.0, "personalizado")
	ok(sem_descer == "", "Baixo e Personalizado nunca descem")
	_ir_para(pausa, "g:detectar")
	_tecla(KEY_ENTER)
	ok(pausa._graficos.mensagem != "", "Detectar pela máquina dá um aviso (%s)" % pausa._graficos.mensagem)
	var todas_lidas := true
	for it in pausa._itens_atuais:
		var iid: String = str(it.get("id", ""))
		if iid.begins_with("g:op:") and not pausa._graficos.lida_na_v2(iid.substr(5)):
			todas_lidas = false
	ok(
		todas_lidas and not ("g:op:escala_render" in _ids(pausa)) and not ("g:op:max_inimigos" in _ids(pausa)),
		"a aba só mostra opções que a v2 lê (sem escala de render nem máximo de inimigos)"
	)
	_ir_para(pausa, "g:op:luz_relevo")
	ok(
		not str(pausa._itens_atuais[pausa.sel].rotulo).ends_with("*") and not str(pausa._itens_atuais[pausa.sel].ajuda).contains("Etapa"),
		"a ajuda das opções não cita etapa nem marca com *"
	)
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
	_ir_para(pausa, "g:qualidade")  # o topo da aba: Perfil, Detectar, Tela cheia, Baixar a qualidade e Mostrar FPS
	await mundo.ap.foto(pasta.path_join("pausa_graficos_topo.png"))
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
