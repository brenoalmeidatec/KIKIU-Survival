extends "res://testes/isolamento_v2.gd"
# Teste do ESC na partida da v2 ("ESC parou de funcionar no meio da partida"). Os testes antigos do menu (v2_pausa) injetavam a
# tecla com sv.push_input, direto no SubViewport, caminho que o jogador nunca usa: a janela só entrega teclado, controle e mouse à
# viewport RAIZ. Aqui TUDO entra por Input.parse_input_event (o caminho do sistema operacional) e o mundo, o menu e as telas são os de
# verdade. Confere:
#  1. ESC e Start abrem e fecham a pausa em "jogando"; o mouse (clique nas linhas) funciona pelo mesmo caminho; ESC nunca fecha o jogo.
#  2. Perder o foco abre a pausa (aqui chamada por pausar(), porque em headless o foco não conta) e ESC, Start e clique a fecham:
#     a árvore não fica congelada.
#  3. Soltar um botão que já estava apertado antes de o menu abrir (o golpe segurado, o clique da carta) não aciona a linha sob o cursor.
#  4. ESC sobre a escolha de cartas e sobre o baú abre o menu por cima e, ao fechar, tudo volta INTACTO: cartas, seleção,
#     a roleta, get_tree().paused, combate.pausado e combate.jogo. As teclas do menu não escolhem carta nem fecham o baú.
#  5. Na câmera lenta de morte e de vitória e nas telas de resultado a pausa não abre, e o ESC não fecha o jogo.
#  6. Intercalações: nível ganho durante o baú, câmera lenta do nível, Ajustes e volta, foco, hit-stop, ESC em sequência.
#  7. Com o processo de verdade (quadros reais), a pausa congela o mundo, a roleta e a escolha; ao fechar, tudo anda de novo.
#  8. Um fuzz curto de semente fixa: depois de qualquer ação, ESC abre a pausa se e só se o jogo está em jogando, escolha ou baú, e
#     fecha devolvendo o estado idêntico.
# Usa saves TEMPORÁRIOS (meta e opções); o save real não é tocado.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_esc.tscn  (imprime "v2_esc falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Meta := preload("res://v2/meta.gd")
const Resultado := preload("res://v2/resultado_meta.gd")
const SAVE_TESTE := "user://testes_v2/v2_esc/teste_v2_esc_meta.cfg"
const OPCOES_TESTE := "user://testes_v2/v2_esc/teste_v2_esc_opcoes.cfg"
const SAVE_REAL := "user://testes_v2/v2_esc/v2_progresso.cfg"
const OPCOES_REAL := "user://testes_v2/v2_esc/opcoes.cfg"
const PASSO := 1.0 / 60.0
const MAX_FALHAS_IMPRESSAS := 30
const PAINEL_X := 290.0  # pausa.gd: PAINEL, LINHA0 e LINHA_H
const PAINEL_Y := 55.0
const LINHA0 := 118.0
const LINHA_H := 36.0

var falhas := 0
var saiu := 0  # o gancho ao_sair conta aqui: o processo de teste não fecha
var mundo
var pausa
var _mouse_alvo := Vector2.ZERO


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		if falhas <= MAX_FALHAS_IMPRESSAS:
			print("FALHOU: ", msg)


func _ready() -> void:
	var md5_save := _md5(SAVE_REAL)
	var md5_opc := _md5(OPCOES_REAL)
	Meta.caminho_save = SAVE_TESTE
	Config.arquivo = OPCOES_TESTE
	Input.use_accumulated_input = false
	seed(20261012)
	await _montar_mundo()
	await _t_caminho_da_janela()
	await _t_foco()
	await _t_soltar_botao()
	await _t_escolha()
	await _t_bau()
	await _t_sem_pausa()
	await _t_intercalacoes()
	await _t_quadros_reais()
	await _t_fuzz()
	ok(saiu == 0, "nenhum ESC chamou o gancho de sair (saiu = %d)" % saiu)
	ok(_md5(SAVE_REAL) == md5_save, "o save real (v2_progresso.cfg) não foi tocado")
	ok(_md5(OPCOES_REAL) == md5_opc, "as opções reais (opcoes.cfg) não foram tocadas")
	_limpar()
	if falhas > MAX_FALHAS_IMPRESSAS:
		print("(mais %d falhas não impressas)" % (falhas - MAX_FALHAS_IMPRESSAS))
	print("v2_esc falhas=%d" % falhas)
	get_tree().quit()


func _limpar() -> void:
	get_tree().paused = false
	_soltar_tudo()
	for c in [SAVE_TESTE, SAVE_TESTE + ".bak", SAVE_TESTE + ".tmp", OPCOES_TESTE]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))
	Config.arquivo = "user://testes_v2/v2_esc/opcoes.cfg"


func _md5(caminho: String) -> String:
	return FileAccess.get_md5(caminho) if FileAccess.file_exists(caminho) else ""


# ------------------------------------------------------------------ mundo e entrada (como a janela entrega)


func _montar_mundo() -> void:
	mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)  # o mundo anda só pelos passos do teste (e pelos quadros reais da seção 7)
	await get_tree().process_frame
	pausa = null
	for c in mundo.ui.get_children():
		if c.has_method("abrir_sair"):
			pausa = c
	ok(pausa != null, "o mundo monta o menu de pausa")
	if pausa == null:
		print("v2_esc falhas=%d" % (falhas + 1))
		get_tree().quit()
		return
	pausa.ao_sair = Callable(self, "_marcar_saida")
	pausa.mouse_fn = Callable(self, "_mouse_teste")
	mundo.combate.audio.mudo = true
	_preparar()


func _marcar_saida() -> void:
	saiu += 1


func _mouse_teste() -> Vector2:
	return _mouse_alvo


## Partida nova e quieta (sem diretor, herói imortal), com o menu fechado e a árvore rodando.
func _preparar() -> void:
	_fechar_se_aberta()
	_soltar_tudo()
	get_tree().paused = false
	mundo.reiniciar()
	mundo.combate.limpar_partida()
	mundo.combate.diretor.ligado = false
	mundo.heroi.imortal = true
	mundo.combate.cartas.rng.seed = 12345
	_andar(3)


## Se um teste anterior deixou o menu aberto (é uma falha dele), fecha sem barulho para o resto não cair em cascata.
func _fechar_se_aberta() -> void:
	if pausa.aberto:
		pausa.aberto = false
		pausa._raiz.visible = false
	get_tree().paused = false


## Anda o mundo n quadros fixos. Com a árvore pausada o mundo não recebe _process: aqui também não anda.
func _andar(n: int) -> void:
	for i in n:
		if get_tree().paused:
			return
		mundo.avancar(PASSO)


func _enviar(e: InputEvent) -> void:
	Input.parse_input_event(e)  # o caminho do sistema: entra pela viewport raiz, como a tecla de verdade
	Input.flush_buffered_events()


func _tecla(k: Key, solta := true) -> void:
	for pressionado in [true, false]:
		if not pressionado and not solta:
			return
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionado
		_enviar(e)


func _esc() -> void:
	_tecla(KEY_ESCAPE)


## A pausa abre sem passar pelo ESC (perder o foco da janela chama pausa.pausar()): é o caminho que sobra para pausar POR CIMA da escolha de
## cartas, porque o ESC e o Start lá pedem confirmação (telas.intercepta_pausa).
func _pausa_foco() -> void:
	pausa.pausar()


func _start() -> void:
	for pressionado in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_START
		e.pressed = pressionado
		_enviar(e)


func _botao(pos: Vector2, pressionado: bool, botao := MOUSE_BUTTON_LEFT) -> void:
	_mouse_alvo = pos
	var e := InputEventMouseButton.new()
	e.button_index = botao
	e.pressed = pressionado
	e.position = pos
	e.global_position = pos
	_enviar(e)


func _clique(pos: Vector2) -> void:
	_botao(pos, true)
	_botao(pos, false)


func _mexer_mouse(pos: Vector2) -> void:
	_mouse_alvo = pos
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	_enviar(e)


func _soltar_tudo() -> void:
	for b in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if Input.is_mouse_button_pressed(b):
			_botao(_mouse_alvo, false, b)


## Centro da linha i do menu de pausa (em 960x540, o mesmo espaço do mouse_fn).
func _linha(i: int) -> Vector2:
	return Vector2(PAINEL_X + 190.0, PAINEL_Y + LINHA0 + i * LINHA_H + 16.0)


func _ids() -> Array:
	var r: Array = []
	for it in pausa._itens_atuais:
		r.append(str(it.id))
	return r


func _ir_para(id: String) -> void:
	for i in 40:
		if pausa.sel < pausa._itens_atuais.size() and str(pausa._itens_atuais[pausa.sel].id) == id:
			return
		_tecla(KEY_DOWN)


## Estado que a pausa não pode mexer: a partida e as telas. sem_arvore = ignora get_tree().paused (que a pausa liga de propósito).
func _snap(sem_arvore := false) -> Dictionary:
	var c = mundo.combate
	var t = c.telas
	var d := {
		"jogo": c.jogo,
		"pausado": c.pausado,
		"lento_t": c.lento_t,
		"lento_acao": c.lento_acao,
		"parada_t": c.parada_t,
		"tempo": mundo.tempo_partida,
		"escolha": t.escolha_aberta,
		"bau": t.bau_aberto,
		"resultado": t.resultado_aberto,
		"pendentes": c.progresso.pendentes,
		"nivel": mundo.heroi.nivel
	}
	if not sem_arvore:
		d["arvore"] = get_tree().paused
	if t.escolha_aberta:
		var ids: Array = []
		for k in c.progresso.cartas:
			ids.append(str(k.id))
		d["cartas"] = ids
		d["sel"] = t.sel
	if t.bau_aberto:
		d["bau_i"] = t._bau_i
		d["bau_t"] = t._bau_t
		d["bau_fase"] = t._bau_fase
		d["bau_pronto"] = t.bau_pronto
		d["bau_n"] = t._bau_cartas.size()
	return d


## Fecha a pausa com ESC, quantas vezes precisar (submenus e confirmações voltam um nível por ESC). Devolve quantos ESC gastou.
func _fechar_com_esc(max_esc := 6) -> int:
	var n := 0
	while pausa.aberto and n < max_esc:
		_esc()
		n += 1
	return n


## Abre a escolha de cartas como o jogo abre (um nível pendente).
func _abrir_escolha() -> void:
	var c = mundo.combate
	c.progresso.pendentes = 1
	c.progresso.abrir_escolha()


## Solta um baú em cima do herói e abre (como encostar nele); a roleta começa a girar.
func _abrir_bau(n := 3) -> void:
	var c = mundo.combate
	c.baus.soltar(mundo.heroi.pos, 1.0, n)
	for b in c.baus.lista:
		if b.ativo:
			c.baus.abrir(b)
			return


# ------------------------------------------------------------------ 1. o caminho da janela


func _t_caminho_da_janela() -> void:
	_preparar()
	ok(mundo.get("pausa") == pausa, "o mundo guarda o nó da pausa em mundo.pausa (as telas leem mundo.pausa.aberto)")
	# a entrada da partida tem um caminho só: a Antena (filha do mundo, ALWAYS); o _input do menu dentro do SubViewport fica desligado
	var antena = mundo.get_node_or_null("AntenaPausa")
	ok(antena != null and antena.process_mode == Node.PROCESS_MODE_ALWAYS, "a Antena da pausa existe e roda com a árvore pausada")
	ok(not pausa.is_processing_input(), "o _input do menu dentro do SubViewport está desligado (a janela não entrega nada lá)")
	ok(mundo.combate.jogo == "jogando" and not get_tree().paused, "a partida começa em jogando, com a árvore rodando")
	_esc()
	ok(pausa.aberto and get_tree().paused, "ESC (entregue pela janela) abre a pausa na partida")
	ok(pausa.tela == "menu" and _ids() == ["continuar", "conquistas", "ajustes", "santuario", "sair"], "a pausa abre no menu de 5 itens (%s)" % str(_ids()))
	_esc()
	ok(not pausa.aberto and not get_tree().paused, "ESC de novo fecha a pausa e despausa")
	_start()
	ok(pausa.aberto and get_tree().paused, "Start (entregue pela janela) abre a pausa")
	_start()
	ok(not pausa.aberto and not get_tree().paused, "Start de novo fecha")

	# o mouse chega pelo mesmo caminho: clicar em Continuar fecha, clicar em Ajustes abre o submenu
	_esc()
	ok(pausa.aberto, "ESC abre a pausa antes do clique")
	_clique(_linha(0))
	ok(not pausa.aberto and not get_tree().paused, "clicar em Continuar (mouse pela janela) fecha a pausa")
	_esc()
	ok(pausa.aberto, "ESC abre a pausa antes do segundo clique")
	_clique(_linha(2))
	ok(pausa.aberto and pausa.tela == "ajustes", "clicar em Ajustes (mouse pela janela) abre o submenu")
	_esc()
	ok(pausa.tela == "menu" and pausa.aberto, "ESC em Ajustes volta um nível, sem fechar a pausa")
	_esc()
	ok(not pausa.aberto and not get_tree().paused, "ESC fecha a pausa")

	# o teclado do menu (setas e Enter) também chega pela janela
	_esc()
	_tecla(KEY_DOWN)
	ok(pausa.sel == 1, "a seta para baixo move a seleção do menu")
	_tecla(KEY_UP)
	_tecla(KEY_ENTER)
	ok(not pausa.aberto and not get_tree().paused, "Enter em Continuar fecha")

	# com o menu aberto, o jogo não recebe nada (nem o golpe nem a esquiva) e o tempo não anda
	var t0: float = mundo.tempo_partida
	_esc()
	_tecla(KEY_SPACE)  # ui_accept em Continuar: fecha o menu (e não pode virar esquiva)
	ok(not pausa.aberto, "Espaço em Continuar fecha o menu")
	_esc()
	_andar(30)
	ok(is_equal_approx(mundo.tempo_partida, t0), "com a pausa aberta o mundo não anda")
	_esc()
	ok(saiu == 0, "ESC nunca fecha o jogo")


# ------------------------------------------------------------------ 2. foco


func _t_foco() -> void:
	_preparar()
	# FOCUS_OUT chama pausar() (pausa.gd); em headless o foco não conta, então o teste chama o mesmo caminho direto.
	pausa.pausar()
	ok(pausa.aberto and get_tree().paused, "perder o foco abre a pausa")
	_esc()
	ok(not pausa.aberto and not get_tree().paused, "depois de perder o foco, ESC fecha a pausa (a árvore não fica congelada)")
	pausa.pausar()
	_start()
	ok(not pausa.aberto and not get_tree().paused, "depois de perder o foco, Start fecha a pausa")
	_fechar_se_aberta()
	pausa.pausar()
	_clique(_linha(0))
	ok(not pausa.aberto and not get_tree().paused, "depois de perder o foco, o clique em Continuar fecha a pausa")
	_fechar_se_aberta()
	pausa.pausar()
	_tecla(KEY_ENTER)
	ok(not pausa.aberto and not get_tree().paused, "depois de perder o foco, Enter em Continuar fecha a pausa")
	_fechar_se_aberta()
	# o foco que volta com a pausa aberta e ela dentro de um submenu: ESC desce os níveis e fecha
	pausa.pausar()
	_ir_para("ajustes")
	_tecla(KEY_ENTER)
	_ir_para("graficos")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "graficos", "chegou em Gráficos")
	var gastos := _fechar_com_esc()
	ok(gastos == 3 and not pausa.aberto and not get_tree().paused, "de Gráficos, 3 ESC fecham a pausa (gastou %d)" % gastos)
	_fechar_se_aberta()
	# pausar() com a pausa já aberta não empilha nem perde o estado
	pausa.pausar()
	pausa.pausar()
	_esc()
	ok(not pausa.aberto and not get_tree().paused, "pausar() duas vezes ainda fecha com um ESC")
	_fechar_se_aberta()


# ------------------------------------------------------------------ 3. soltar o botão


func _t_soltar_botao() -> void:
	_preparar()
	# o jogador segura o botão (golpe repetido), aperta ESC e solta com o cursor em cima do menu: a pausa fica como está
	for i in 4:
		_botao(_linha(i), true)  # aperto com o menu fechado
		_esc()
		ok(pausa.aberto, "ESC com o botão apertado abre a pausa (linha %d)" % i)
		_botao(_linha(i), false)  # soltou em cima da linha i
		ok(
			pausa.aberto and pausa.tela == "menu",
			"soltar o botão apertado antes do menu não aciona a linha %d (aberto=%s tela=%s)" % [i, str(pausa.aberto), pausa.tela]
		)
		_fechar_com_esc()
		_fechar_se_aberta()
	# o botão direito também
	_botao(_linha(1), true, MOUSE_BUTTON_RIGHT)
	_esc()
	_botao(_linha(1), false, MOUSE_BUTTON_RIGHT)
	ok(pausa.aberto and pausa.tela == "menu", "soltar o botão direito apertado antes do menu não aciona nada")
	_fechar_com_esc()
	_fechar_se_aberta()
	# o clique inteiro dentro do menu continua valendo (aperto e soltura com o menu aberto)
	_esc()
	_clique(_linha(2))
	ok(pausa.tela == "ajustes", "o clique completo com o menu aberto abre a linha")
	_fechar_com_esc()
	_fechar_se_aberta()
	# a soltura vale uma vez: soltar de novo sem apertar não faz nada
	_esc()
	_botao(_linha(2), true)
	_botao(_linha(2), false)  # abre Ajustes
	_botao(_linha(0), false)  # soltura solta: Ajustes tem "Gráficos" na linha 0
	ok(pausa.tela == "ajustes", "uma soltura sem aperto não aciona a linha")
	_fechar_com_esc()
	_fechar_se_aberta()
	# a escolha por clique acontece no aperto; ESC antes de soltar e soltar sobre o menu não escolhe nem aciona nada
	_preparar()
	_abrir_escolha()
	var antes := _snap(true)
	_botao(_linha(3), true)  # aperto sobre o painel (sem carta ali: a escolha ignora)
	_pausa_foco()
	_botao(_linha(3), false)
	ok(pausa.aberto and pausa.tela == "menu", "na escolha, soltar depois do ESC não aciona 'Sair do jogo' (tela=%s)" % pausa.tela)
	_fechar_com_esc()
	ok(_snap(true) == antes and saiu == 0, "e a escolha continua como estava")
	_fechar_se_aberta()


# ------------------------------------------------------------------ 4. ESC sobre a escolha


func _t_escolha() -> void:
	_preparar()
	var c = mundo.combate
	_abrir_escolha()
	ok(c.jogo == "escolha" and c.pausado and c.telas.escolha_aberta and not get_tree().paused, "a escolha abre pausando o combate, não a árvore")
	c.telas.sel = 2
	c.telas._marcar()
	var antes := _snap()
	# o ESC na escolha NÃO pausa: pede "Pausar agora? Você perde estas cartas" e o segundo ESC volta (o detalhe está em v2_cartas_limite)
	_esc()
	ok(c.telas.conf_aberta and not pausa.aberto and not get_tree().paused, "ESC sobre a escolha pede confirmação em vez de pausar")
	_esc()
	ok(not c.telas.conf_aberta and not pausa.aberto and _snap() == antes, "ESC de novo é 'Não': a escolha volta intacta")
	_pausa_foco()
	ok(pausa.aberto and get_tree().paused, "a pausa abre por cima da escolha por outro caminho (perder o foco da janela)")
	ok(_snap(true) == _sem_arvore(antes), "com a pausa aberta a escolha segue exatamente como estava")
	# as teclas e os cliques da escolha não passam pelo menu: nada escolhe nem muda a seleção
	for k in [KEY_1, KEY_2, KEY_3, KEY_R, KEY_B, KEY_X, KEY_A, KEY_D, KEY_E]:
		_tecla(k)
	_tecla(KEY_RIGHT)
	_clique(Vector2(120, 300))
	_clique(Vector2(480, 440))
	ok(pausa.aberto and pausa.tela == "menu", "as teclas e os cliques da escolha são do menu enquanto ele está aberto")
	ok(_snap(true) == _sem_arvore(antes), "nada da escolha mudou com o menu aberto (cartas e seleção)")
	_esc()
	ok(not pausa.aberto, "ESC fecha a pausa sobre a escolha")
	ok(_snap() == antes, "ao fechar, a escolha, get_tree().paused, combate.pausado e combate.jogo voltam exatamente ao que eram")

	# Ajustes por cima da escolha e volta
	_pausa_foco()
	_ir_para("ajustes")
	_tecla(KEY_ENTER)
	_ir_para("audio")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "audio" and get_tree().paused, "Áudio abre por cima da escolha")
	var gastos := _fechar_com_esc()
	ok(gastos == 3 and _snap() == antes, "Áudio, Ajustes e pausa se desfazem em 3 ESC e a escolha volta intacta (gastou %d)" % gastos)

	# 'Não' nas confirmações também devolve o estado
	_pausa_foco()
	_ir_para("sair")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "confirmar_sair", "Sair do jogo pede confirmação por cima da escolha")
	_tecla(KEY_ENTER)  # Não
	ok(pausa.tela == "menu" and saiu == 0, "Não volta ao menu sem sair")
	_fechar_com_esc()
	ok(_snap() == antes, "e a escolha segue intacta")

	# a escolha continua escolhível depois da pausa (a espera das cartas, se houver, passa com o mundo andando)
	_andar(260)
	ok(c.jogo == "escolha" and c.telas.escolha_aberta, "a escolha segue aberta enquanto ninguém escolhe")
	_tecla(KEY_1)
	ok(c.jogo == "jogando" and not c.pausado and not c.telas.escolha_aberta, "depois da pausa, a tecla 1 escolhe a carta e o jogo volta")

	# Voltar ao santuário por cima da escolha: a partida acaba como abandonada, sem deixar a escolha aberta
	_preparar()
	var res = Resultado.new()  # o resultado com as almas (o mundo o monta fora do modo de teste)
	mundo.ui.add_child(res)
	res.montar(mundo)
	var saldo_antes: int = Meta.saldo()
	mundo.xp_coletado = 250.0  # 25 almas na partida
	_abrir_escolha()
	_pausa_foco()
	_ir_para("santuario")
	_tecla(KEY_ENTER)
	ok(pausa.tela == "confirmar_santuario", "Voltar ao santuário pede confirmação por cima da escolha")
	_tecla(KEY_UP)
	_tecla(KEY_ENTER)  # Sim
	ok(not pausa.aberto and not get_tree().paused, "Sim fecha o menu e despausa a árvore")
	ok(c.jogo == "abandono" and c.pausado and c.venceu == false, "a partida acaba como abandonada (jogo = %s)" % c.jogo)
	ok(not c.telas.escolha_aberta and c.telas.resultado_aberto, "a escolha sai e o resultado entra")
	ok(res._terminou and Meta.saldo() - saldo_antes >= 25, "o resultado com as almas é montado e as almas são creditadas")
	_esc()
	ok(not pausa.aberto, "no resultado o ESC não abre a pausa")
	res.queue_free()
	_preparar()


## O mesmo snapshot sem a chave da árvore (durante a pausa a árvore está pausada de propósito).
func _sem_arvore(d: Dictionary) -> Dictionary:
	var r := d.duplicate()
	r.erase("arvore")
	return r


# ------------------------------------------------------------------ 5. ESC sobre o baú


func _t_bau() -> void:
	_preparar()
	var c = mundo.combate
	_abrir_bau(3)
	ok(c.jogo == "bau" and c.pausado and c.telas.bau_aberto, "o baú abre pausando o combate")
	_andar(50)  # a roleta gira
	var antes := _snap()
	ok(c.telas._bau_t > 0.0 or c.telas._bau_i > 0, "a roleta está girando (t=%.2f i=%d)" % [c.telas._bau_t, c.telas._bau_i])
	_esc()
	ok(pausa.aberto and get_tree().paused, "ESC sobre o baú abre a pausa por cima")
	_tecla(KEY_ENTER)
	# o Enter fecha o menu (Continuar); o que importa: o Enter que fechou o menu NÃO pode ter pulado a roleta
	ok(not pausa.aberto, "Enter em Continuar fecha o menu sobre o baú")
	ok(_snap() == antes, "o Enter que fechou o menu não pulou nem fechou o baú, e a roleta está como estava")
	_esc()
	_clique(Vector2(120, 300))
	_clique(Vector2(480, 440))
	ok(pausa.aberto and _snap(true) == _sem_arvore(antes), "cliques sobre o baú com o menu aberto não pulam a roleta")
	_esc()
	ok(not pausa.aberto and _snap() == antes, "ESC fecha e a roleta volta intacta")

	# roleta pronta
	for i in 600:
		if c.telas.bau_pronto:
			break
		_andar(1)
	ok(c.telas.bau_pronto, "a roleta termina sozinha")
	var pronta := _snap()
	_esc()
	ok(pausa.aberto and get_tree().paused, "ESC abre a pausa sobre a roleta pronta")
	_esc()
	ok(not pausa.aberto and _snap() == pronta, "e fecha com a roleta pronta intacta")
	_tecla(KEY_ENTER)
	ok(c.jogo == "jogando" and not c.pausado and not c.telas.bau_aberto and not get_tree().paused, "depois da pausa, Enter fecha o baú e o jogo volta")
	_esc()
	ok(pausa.aberto and get_tree().paused, "e o ESC abre a pausa de novo")
	_esc()

	# Voltar ao santuário por cima do baú
	_preparar()
	_abrir_bau(2)
	_esc()
	_ir_para("santuario")
	_tecla(KEY_ENTER)
	_tecla(KEY_UP)
	_tecla(KEY_ENTER)
	ok(
		c.jogo == "abandono" and not c.telas.bau_aberto and c.telas.resultado_aberto and not get_tree().paused,
		"Voltar ao santuário por cima do baú abandona a partida"
	)
	_preparar()


# ------------------------------------------------------------------ 6. onde a pausa não abre


func _t_sem_pausa() -> void:
	var c = mundo.combate
	# câmera lenta da morte: a pausa não abre, o ESC não fecha nada e a morte segue o fluxo dela
	_preparar()
	c.heroi_morreu()
	ok(c.jogo == "morrendo", "o herói morreu: câmera lenta da morte")
	_esc()
	_start()
	ok(not pausa.aberto and not get_tree().paused and c.jogo == "morrendo", "na câmera lenta da morte a pausa não abre")
	for i in 400:
		if c.jogo == "morte":
			break
		_andar(1)
	ok(c.jogo == "morte" and c.telas.resultado_aberto, "a morte chega ao resultado")
	var res := _snap()
	_esc()
	_start()
	ok(not pausa.aberto and not get_tree().paused and _snap() == res, "no resultado da derrota o ESC não abre a pausa nem mexe em nada")
	# câmera lenta da vitória
	_preparar()
	c.vitoria()
	ok(c.jogo == "vencendo", "o chefe caiu: câmera lenta da vitória")
	_esc()
	ok(not pausa.aberto and not get_tree().paused and c.jogo == "vencendo", "na câmera lenta da vitória a pausa não abre")
	for i in 400:
		if c.jogo == "vitoria":
			break
		_andar(1)
	ok(c.jogo == "vitoria" and c.telas.resultado_aberto, "a vitória chega ao resultado")
	res = _snap()
	_esc()
	ok(not pausa.aberto and not get_tree().paused and _snap() == res, "no resultado da vitória o ESC não abre a pausa nem mexe em nada")
	ok(saiu == 0 and is_instance_valid(mundo), "o ESC não fechou o jogo em nenhum desses estados")
	# depois do resultado, a partida nova abre a pausa de novo
	_preparar()
	_esc()
	ok(pausa.aberto, "na partida nova o ESC abre a pausa de novo")
	_esc()


# ------------------------------------------------------------------ 7. intercalações


func _t_intercalacoes() -> void:
	var c = mundo.combate
	var h = mundo.heroi
	# nível ganho com o baú aberto: o ESC abre sobre o baú e, com o baú fechado, em jogando
	_preparar()
	_abrir_bau(1)
	c.progresso.ganhar_xp(h.xp_proximo + 1.0)
	_esc()
	ok(pausa.aberto, "nível ganho durante o baú: ESC abre a pausa sobre o baú")
	_esc()
	ok(not pausa.aberto and c.jogo == "bau", "e fecha de volta ao baú")
	c.telas.espera_bau = 0.0  # a trava de 1,5 s do baú (testes/v2_cartas_espera.gd) já passou: aqui o assunto é o ESC
	_tecla(KEY_ENTER)  # pula a roleta
	_tecla(KEY_ENTER)  # fecha o baú
	ok(c.jogo == "jogando" or c.jogo == "escolha", "o baú fecha (jogo = %s)" % c.jogo)
	if c.jogo == "jogando":
		_esc()
		ok(pausa.aberto and get_tree().paused, "com o nível ainda pendente depois do baú, o ESC abre em jogando")
		_esc()
		ok(not pausa.aberto and not get_tree().paused, "e fecha")

	# câmera lenta do nível: a pausa abre e o relógio dela fica parado
	_preparar()
	c.progresso.ganhar_xp(h.xp_proximo + 1.0)
	ok(c.lento_acao == "nivel" and c.lento_t > 0.0, "subir de nível arma a câmera lenta")
	_andar(5)
	var lento: float = c.lento_t
	_esc()
	ok(pausa.aberto and get_tree().paused and c.jogo == "jogando", "ESC abre a pausa na câmera lenta do nível")
	_andar(60)
	ok(is_equal_approx(c.lento_t, lento), "com a pausa aberta o relógio da câmera lenta não anda")
	_esc()
	ok(not pausa.aberto and is_equal_approx(c.lento_t, lento) and c.lento_acao == "nivel", "ao fechar, a câmera lenta segue de onde parou")
	# ESC no último quadro antes de abrir a escolha
	c.lento_t = 0.002
	_esc()
	ok(pausa.aberto and c.jogo == "jogando", "ESC no último instante da câmera lenta ainda abre a pausa")
	_esc()
	_andar(3)
	ok(c.jogo == "escolha" and c.telas.escolha_aberta, "depois da pausa a escolha abre normalmente")
	_esc()
	ok(c.telas.conf_aberta and not pausa.aberto and c.jogo == "escolha", "e o ESC pede confirmação sobre a escolha recém-aberta")
	_esc()
	ok(c.jogo == "escolha" and c.pausado and c.telas.escolha_aberta and not get_tree().paused, "e volta intacta")

	# hit-stop
	_preparar()
	c.hit_stop(0.3)
	_esc()
	ok(pausa.aberto, "ESC abre a pausa durante o hit-stop")
	_esc()
	ok(not pausa.aberto and c.parada_t > 0.0, "e o hit-stop segue depois")

	# Ajustes e volta, várias vezes, sem perder o ESC
	_preparar()
	for volta in 3:
		_esc()
		ok(pausa.aberto, "ESC abre a pausa (volta %d)" % volta)
		_ir_para("ajustes")
		_tecla(KEY_ENTER)
		_ir_para("graficos")
		_tecla(KEY_ENTER)
		_esc()
		_esc()
		ok(pausa.aberto and pausa.tela == "menu", "de Gráficos, dois ESC voltam ao menu da pausa (volta %d)" % volta)
		_esc()
		ok(not pausa.aberto and not get_tree().paused, "e o terceiro fecha (volta %d)" % volta)

	# ESC em sequência rápida: par fecha, ímpar abre
	for n in 9:
		_esc()
	ok(pausa.aberto and get_tree().paused, "nove ESC seguidos deixam a pausa aberta")
	_esc()
	ok(not pausa.aberto and not get_tree().paused, "o décimo fecha")

	# foco perdido em cada estado em que a pausa abre
	for estado in ["jogando", "escolha", "bau"]:
		_preparar()
		if estado == "escolha":
			_abrir_escolha()
		elif estado == "bau":
			_abrir_bau(2)
		var antes := _snap()
		pausa.pausar()
		ok(pausa.aberto and get_tree().paused, "perder o foco em %s abre a pausa" % estado)
		_esc()
		ok(not pausa.aberto and _snap() == antes, "e o ESC devolve o estado de %s" % estado)

	# estado interno torto: jogando com combate.pausado ligado por engano; o ESC ainda abre
	_preparar()
	c.pausado = true
	_esc()
	ok(pausa.aberto, "jogando com combate.pausado ligado por engano: o ESC ainda abre a pausa")
	_esc()
	ok(not pausa.aberto and c.pausado and not get_tree().paused, "e fecha sem mexer nesse flag")
	c.pausado = false


# ------------------------------------------------------------------ 8. quadros reais


func _t_quadros_reais() -> void:
	var c = mundo.combate
	_preparar()
	mundo.set_process(true)
	for i in 5:
		await get_tree().process_frame
	var q0: int = mundo.quadros
	ok(q0 > 0, "com o processo ligado o mundo anda")
	_esc()
	ok(pausa.aberto and get_tree().paused, "ESC abre a pausa com o mundo rodando")
	var q1: int = mundo.quadros
	for i in 8:
		await get_tree().process_frame
	ok(mundo.quadros == q1, "com a pausa aberta o mundo não processa nenhum quadro (%d -> %d)" % [q1, mundo.quadros])
	_esc()
	for i in 5:
		await get_tree().process_frame
	ok(not pausa.aberto and mundo.quadros > q1, "ao fechar, o mundo anda de novo")

	# a escolha: o relógio das telas e o brilho das cartas param com a pausa
	mundo.set_process(false)
	_abrir_escolha()
	mundo.set_process(true)
	for i in 3:
		await get_tree().process_frame
	var ui0: float = c.telas._t_ui
	_pausa_foco()
	for i in 8:
		await get_tree().process_frame
	ok(c.telas._t_ui == ui0, "a escolha não anima com a pausa aberta (%.3f -> %.3f)" % [ui0, c.telas._t_ui])
	_esc()
	for i in 3:
		await get_tree().process_frame
	ok(c.telas._t_ui > ui0 and c.jogo == "escolha", "ao fechar, a escolha anima de novo e continua aberta")

	# o baú: a roleta para
	mundo.set_process(false)
	_preparar()
	_abrir_bau(3)
	mundo.set_process(true)
	for i in 6:
		await get_tree().process_frame
	_esc()
	var bt: float = c.telas._bau_t
	var bi: int = c.telas._bau_i
	for i in 8:
		await get_tree().process_frame
	ok(c.telas._bau_t == bt and c.telas._bau_i == bi, "a roleta do baú para com a pausa aberta")
	_esc()
	mundo.set_process(false)
	_preparar()


# ------------------------------------------------------------------ 9. fuzz de semente fixa


func _t_fuzz() -> void:
	_preparar()
	var c = mundo.combate
	var h = mundo.heroi
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var contagem := {"jogando": 0, "escolha": 0, "bau": 0, "fora": 0, "resultado": 0}
	var passos_fuzz := 1000  # A escolha de 1 s dura menos; mantém a cobertura de todos os estados sem reduzir os mínimos.
	for passo in passos_fuzz:
		# o fuzz não fica preso nos estados sem pausa: dá quadros à câmera lenta e aperta CONTINUAR no resultado (nova partida)
		if c.jogo == "morrendo" or c.jogo == "vencendo":
			if rng.randf() < 0.3:
				_andar(rng.randi_range(10, 60))
		elif c.jogo == "morte" or c.jogo == "vitoria" or c.jogo == "abandono":
			if rng.randf() < 0.3:
				_andar(40)
				_tecla(KEY_ENTER)
		var a: int = rng.randi_range(0, 16)
		match a:
			0, 1, 2:
				_andar(rng.randi_range(1, 40))
			3:
				c.progresso.ganhar_xp(h.xp_proximo * rng.randf_range(0.2, 1.4))
			4:
				if c.jogo == "jogando":
					_abrir_bau(rng.randi_range(1, 3))
			5:
				_tecla([KEY_1, KEY_2, KEY_3][rng.randi_range(0, 2)])
			6:
				_tecla([KEY_ENTER, KEY_SPACE, KEY_E][rng.randi_range(0, 2)])
			7:
				_tecla([KEY_R, KEY_B, KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D][rng.randi_range(0, 5)])
			8:
				c.hit_stop(rng.randf_range(0.05, 0.3))
			9:
				if c.jogo == "jogando" and c.lento_acao == "":
					c.camera_lenta("", rng.randf_range(0.1, 0.6), 0.25)
			10:
				_botao(Vector2(rng.randf_range(0, 960), rng.randf_range(0, 540)), true)
			11:
				_botao(_mouse_alvo, false)
			12:
				_mexer_mouse(Vector2(rng.randf_range(0, 960), rng.randf_range(0, 540)))
			13:
				pausa.pausar()  # o foco saiu da janela
			14:
				_tecla([KEY_W, KEY_S, KEY_SHIFT, KEY_F1, KEY_F3][rng.randi_range(0, 4)])
			15:
				if rng.randf() < 0.5 and c.jogo == "jogando":
					c.heroi_morreu()
			16:
				if rng.randf() < 0.4 and c.jogo == "jogando":
					c.vitoria()
		h.imortal = true  # o CONTINUAR do fuzz reinicia a partida
		c.diretor.ligado = false
		# a sonda: o ESC abre se e só se o jogo está em jogando, escolha ou baú; ao fechar, o estado volta idêntico
		_soltar_tudo()
		if pausa.aberto:  # aberta pela ação (foco): tem que fechar com ESC
			var gastos := _fechar_com_esc(8)
			ok(
				not pausa.aberto and not get_tree().paused,
				"fuzz passo %d: a pausa aberta pelo foco fecha com ESC (gastou %d, jogo=%s)" % [passo, gastos, c.jogo]
			)
			_fechar_se_aberta()
		var antes := _snap()
		var deve: bool = c.jogo in ["jogando", "escolha", "bau"]
		_esc()
		if c.jogo == "escolha":  # na escolha o ESC pede confirmação (não pausa) e o segundo ESC volta com tudo parado
			contagem.escolha += 1
			ok(c.telas.conf_aberta and not pausa.aberto and not get_tree().paused, "fuzz passo %d: ESC na escolha pede confirmação (ação %d)" % [passo, a])
			_esc()
			ok(not c.telas.conf_aberta and not pausa.aberto and _snap() == antes, "fuzz passo %d: e o segundo ESC volta idêntico" % passo)
		elif deve:
			contagem[c.jogo] += 1
			ok(pausa.aberto and get_tree().paused, "fuzz passo %d: ESC em %s tem que abrir a pausa (ação %d)" % [passo, antes.jogo, a])
			if rng.randf() < 0.6:
				_navegar(rng)
			var gastos2 := _fechar_com_esc(8)
			ok(not pausa.aberto and not get_tree().paused, "fuzz passo %d: e fechar (gastou %d)" % [passo, gastos2])
			ok(_snap() == antes, "fuzz passo %d: ao fechar, o estado volta idêntico (%s)" % [passo, str(antes.jogo)])
		else:
			contagem["resultado" if antes.jogo in ["morte", "vitoria", "abandono"] else "fora"] += 1
			ok(not pausa.aberto and not get_tree().paused, "fuzz passo %d: ESC em %s não abre a pausa" % [passo, antes.jogo])
			ok(_snap() == antes, "fuzz passo %d: e não mexe em nada em %s" % [passo, antes.jogo])
		_fechar_se_aberta()
	print(
		(
			"fuzz: %d passos, ESC em jogando=%d escolha=%d bau=%d resultado=%d câmera lenta da morte/vitória=%d"
			% [passos_fuzz, contagem.jogando, contagem.escolha, contagem.bau, contagem.resultado, contagem.fora]
		)
	)
	ok(contagem.jogando > 60 and contagem.escolha > 10 and contagem.bau > 10, "o fuzz passou por jogando, escolha e baú (%s)" % str(contagem))
	ok(contagem.resultado > 5 and contagem.fora > 5, "e pelos estados sem pausa (%s)" % str(contagem))
	_preparar()


## Percorre o menu aberto sem executar nada que saia dele: setas, mouse e Enter só nas linhas que abrem submenu.
func _navegar(rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(1, 6):
		match rng.randi_range(0, 4):
			0:
				_tecla(KEY_DOWN)
			1:
				_tecla(KEY_UP)
			2:
				_mexer_mouse(Vector2(rng.randf_range(0, 960), rng.randf_range(0, 540)))
			3:
				_tecla(KEY_LEFT if rng.randf() < 0.5 else KEY_RIGHT)
			4:
				var id: String = str(pausa._itens_atuais[pausa.sel].id) if pausa.sel < pausa._itens_atuais.size() else ""
				if id in ["ajustes", "graficos", "audio"]:
					_tecla(KEY_ENTER)
