extends Node
# Teste automático das transições suaves entre telas da v2 (#377, v2/transicoes.gd, autoload "Transicoes"). Usa saves TEMPORÁRIOS
# em user://testes_v2/v2_transicoes/: prepara antes do ready e remove a fixture inteira antes de informar o resultado.
# Confere: a duração de cada transição fica entre 0,15 e 0,25 s; "Reduzir animações" (Config, Acessibilidade) zera tudo e o painel
# aparece e some na hora; entrar/sair animam de verdade (alfa e posição) e voltam ao repouso, inclusive com a árvore pausada e
# com um sair no meio de um entrar; Container só faz fade; resize durante fades com e sem deslize preserva o novo layout, inclusive
# interrupção e os créditos reais; no perfil Baixo não há foto (véu); Enter duplo pede UMA troca de cena (a segunda é
# descartada); com a foto da tela antiga ainda visível Enter e ESC (inclusive ESC duplo) são descartados e a primeira entrada
# depois do fade vale, uma vez só; ir_para durante o fade anterior o cancela; e o fluxo de verdade título -> personagens ->
# santuário -> partida -> pausa (ESC) -> santuário, com cenas reais, não trava.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_transicoes.tscn  (imprime "v2_transicoes falhas=0")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const VitoriaFinal := preload("res://v2/vitoria_final.gd")
const Ambiente := preload("res://testes/ambiente_v2.gd")
const TITULO := "res://v2/menu_principal.tscn"
const ESCOLHA := "res://v2/personagens.tscn"
const SALAO := "res://v2/salao.tscn"
const PARTIDA := "res://v2/mundo.tscn"

var falhas := 0
var _alvo_layout: Control
var _pos_layout := Vector2.ZERO


func _init() -> void:
	Ambiente.iniciar(get_script().resource_path)


func _exit_tree() -> void:
	Ambiente.finalizar()


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	print("ISOLAMENTO_USERDIR ", OS.get_user_data_dir())
	ok(Personagens.lista().is_empty() and Meta.saldo() == 0, "fixture começa sem slots ou progresso herdados")
	for caminho in [Config.arquivo, Meta.caminho_save, Personagens.caminho_indice, Personagens.caminho_base, Personagens.caminho_antigo]:
		ok(caminho.begins_with(Ambiente.raiz), "caminho isolado antes de criar cenas reais")
	await _testes()
	get_tree().paused = false
	# Drena trocas pendentes e libera a última cena, inclusive se o fluxo retornou cedo.
	# current_scene é substituída no fluxo; nunca libera o próprio runner que ainda está aguardando.
	await _quadros(2)
	var cena := get_tree().current_scene
	if is_instance_valid(cena) and cena != self:
		cena.queue_free()
		await _quadros(2)
	Transicoes._encerrar()
	Ambiente.finalizar()
	ok(not DirAccess.dir_exists_absolute(Ambiente.raiz), "fixture removida antes do resultado, incluindo índice, slots e resíduos")
	for caminho in [Config.arquivo, Meta.caminho_save, Personagens.caminho_indice, Personagens.caminho_base, Personagens.caminho_antigo]:
		ok(caminho.begins_with(Ambiente.raiz), "callbacks tardios continuam no sandbox")
	print("v2_transicoes falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


## Espera `s` segundos reais e mais dois quadros: o timer dispara antes dos tweens do mesmo quadro, e num quadro longo (CI cheio) a
## última passada da animação só vem no quadro seguinte.
func _esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout
	await get_tree().process_frame
	await get_tree().process_frame


## Espera até a condição valer (ou o prazo, em segundos reais). Devolve se valeu.
func _ate(cond: Callable, prazo: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > prazo:
			return false
		await get_tree().process_frame
	return true


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Tecla pelo caminho da janela (Input.parse_input_event), o mesmo do jogador: aperta e solta.
func _tecla(k: Key) -> void:
	for pressionado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionado
		Input.parse_input_event(e)
		Input.flush_buffered_events()


## Posição de Control passa por offsets e âncoras: aceita o ruído de ponto flutuante (milésimos de pixel).
func _perto(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.01


## Reflow fake usado pelos controles independentes deste teste; créditos reais usam o próprio ui_reencaixar.
func ui_reencaixar(_canvas: Vector2, _desloc: Vector2) -> void:
	if is_instance_valid(_alvo_layout):
		_alvo_layout.position = _pos_layout


func _simular_reencaixe(c: Control, nova_pos: Vector2) -> void:
	_alvo_layout = c
	_pos_layout = nova_pos
	add_to_group("ui_escala")
	Transicoes.reencaixar_ui(Vector2(1024, 576), Vector2(32, 18))
	remove_from_group("ui_escala")
	_alvo_layout = null


func _cena() -> Node:
	return get_tree().current_scene


func _na_cena(caminho: String) -> bool:
	return _cena() != null and _cena().scene_file_path == caminho


func _testes() -> void:
	await _quadros(5)  # o primeiro quadro do Godot tem um delta enorme; as animações medidas começam depois dele
	_constantes()
	_opcao()
	_perfil_baixo()
	await _painel()
	await _reencaixe()
	await _fluxo()


func _constantes() -> void:
	for nome in ["DUR_TROCA", "DUR_ENTRAR", "DUR_SAIR"]:
		var d: float = Transicoes.get(nome)
		ok(d >= 0.15 and d <= 0.25, "%s fica entre 0,15 e 0,25 s (%.2f)" % [nome, d])
	ok(Transicoes.duracao(0.2) == 0.2, "sem a opção, duracao(base) devolve a base")
	var it := Config.item("reduzir_animacoes")
	ok(not it.is_empty() and it.grupo == "Acessibilidade" and it.padrao == false, "Reduzir animações existe nas opções, em Acessibilidade, desligada")


func _opcao() -> void:
	Config.definir("reduzir_animacoes", true)
	ok(Transicoes.reduzido() and Transicoes.duracao(0.2) == 0.0, "com Reduzir animações ligada, a duração é zero")
	var c := ColorRect.new()
	add_child(c)
	Transicoes.entrar(c)
	ok(c.visible and c.modulate.a == 1.0 and c.position == Vector2.ZERO and not Transicoes.animando(c), "reduzido: entrar mostra na hora, sem animar")
	Transicoes.sair(c)
	ok(not c.visible and c.modulate.a == 1.0 and not Transicoes.animando(c), "reduzido: sair esconde na hora")
	c.queue_free()
	Config.definir("reduzir_animacoes", false)
	ok(not Transicoes.reduzido(), "desligar a opção devolve as transições")


## Perfil Baixo: a foto custa uma espera da GPU, então não se fotografa; o véu de cor faz o fade.
func _perfil_baixo() -> void:
	ok(Transicoes.usa_foto() == (DisplayServer.get_name() != "headless"), "fora do Baixo fotografa quando há renderizador")
	Config.g_perfil_temporario("baixo")
	ok(Config.g_perfil() == "baixo" and not Transicoes.usa_foto(), "no perfil Baixo não se fotografa: o véu faz o papel")
	Config.g_soltar_temporario()
	ok(Transicoes.usa_foto() == (DisplayServer.get_name() != "headless"), "soltar o perfil temporário devolve a foto")


## Um reencaixe de layout (resize) no meio do fade não pode ser desfeito pelo fim da animação quando ela não deslizou.
func _reencaixe() -> void:
	var c := ColorRect.new()
	c.position = Vector2(0, 498)
	c.size = Vector2(100, 40)
	add_child(c)
	Transicoes.entrar(c, Vector2.ZERO)
	await _esperar(0.04)
	_simular_reencaixe(c, Vector2(-320, 678))
	await _esperar(Transicoes.DUR_ENTRAR + 0.15)
	ok(c.modulate.a == 1.0 and c.position == Vector2(-320, 678), "entrar sem deslize deixa o reencaixe do meio do fade como está (%s)" % c.position)
	Transicoes.sair(c, Vector2.ZERO)
	await _esperar(0.03)
	_simular_reencaixe(c, Vector2(12, 34))
	await _esperar(Transicoes.DUR_SAIR + 0.15)
	ok(not c.visible and c.modulate.a == 1.0 and c.position == Vector2(12, 34), "sair sem deslize também (%s)" % c.position)
	# O resize pode acontecer durante um slide; uma interrupção para fade puro deve terminar no novo lugar do layout.
	c.position = Vector2(30, 40)
	Transicoes.entrar(c)
	await _esperar(0.04)
	_simular_reencaixe(c, Vector2(210, 130))
	ok(c.get_meta("tr_base").pos == Vector2(210, 130), "reflow durante o slide atualiza a base do painel")
	await _quadros(1)
	ok(
		Transicoes.animando(c) and c.modulate.a < 1.0 and is_equal_approx(c.position.x, 210.0) and c.position.y >= 130.0 and c.position.y <= 140.0,
		"o restante do slide de entrada segue o layout novo durante o fade (%s)" % c.position
	)
	Transicoes.entrar(c, Vector2.ZERO)
	await _esperar(Transicoes.DUR_ENTRAR + 0.15)
	ok(_perto(c.position, Vector2(210, 130)) and c.modulate.a == 1.0, "interromper o slide com fade puro respeita o novo layout (%s)" % c.position)
	# Saída também acompanha o lugar reencaixado durante o movimento.
	Transicoes.sair(c)
	await _esperar(0.03)
	_simular_reencaixe(c, Vector2(305, 210))
	await _quadros(1)
	ok(
		Transicoes.animando(c) and is_equal_approx(c.position.x, 305.0) and c.position.y >= 210.0 and c.position.y <= 215.0,
		"o restante do slide de saída parte do layout novo (%s)" % c.position
	)
	await _esperar(Transicoes.DUR_SAIR + 0.15)
	ok(not c.visible and _perto(c.position, Vector2(305, 210)), "sair durante resize preserva o novo layout (%s)" % c.position)
	# com deslize a posição de repouso continua sendo devolvida
	c.position = Vector2(30, 40)
	Transicoes.entrar(c)
	await _esperar(Transicoes.DUR_ENTRAR + 0.15)
	ok(_perto(c.position, Vector2(30, 40)) and c.modulate.a == 1.0, "entrar com deslize termina no lugar (%s)" % c.position)
	# o callback de sair roda no fim do fade e `esconder` false deixa o painel visível
	var fim := [0]
	Transicoes.sair(c, Vector2.ZERO, Transicoes.DUR_SAIR, func(): fim[0] += 1, false)
	ok(fim[0] == 0 and Transicoes.animando(c), "o callback de sair não roda antes do fim do fade")
	await _esperar(Transicoes.DUR_SAIR + 0.15)
	ok(fim[0] == 1 and c.visible and c.modulate.a == 1.0, "e roda uma vez no fim; com esconder=false o painel fica visível e opaco")
	c.queue_free()
	await _reencaixe_creditos()


## Os três painéis reais de Créditos entram só com fade e precisam manter o layout que a tela recalcula no resize.
func _reencaixe_creditos() -> void:
	var cena = load(VitoriaFinal.CENA).instantiate()
	cena.set_process(false)
	get_tree().root.add_child(cena)
	await _quadros(2)
	cena.proxima()  # vitória -> créditos: animação real da tela
	await _esperar(0.04)
	Transicoes.reencaixar_ui(Vector2(1024, 576), Vector2(32, 18))
	var pos := Vector2(150, -8)
	ok(cena._cred_painel.position == pos, "a tela real de Créditos se reencaixa durante o fade")
	await _esperar(Transicoes.DUR_ENTRAR + 0.15)
	ok(cena._cred_painel.position == pos and cena._recorte.position.y == 6.0, "o fim do fade preserva o layout refeito dos Créditos")
	cena.queue_free()
	await _quadros(2)


func _painel() -> void:
	var c := ColorRect.new()
	c.position = Vector2(30, 40)
	c.size = Vector2(50, 50)
	add_child(c)
	Transicoes.entrar(c)
	ok(c.visible and c.modulate.a < 0.5 and not _perto(c.position, Vector2(30, 40)) and Transicoes.animando(c), "entrar começa quase transparente e deslocado")
	await _esperar(Transicoes.DUR_ENTRAR / 2.0)
	ok(c.modulate.a < 1.0 or not Transicoes.animando(c), "o entrar não pula direto para o fim (%.2f)" % c.modulate.a)
	await _esperar(Transicoes.DUR_ENTRAR / 2.0 + 0.15)
	ok(c.modulate.a == 1.0 and _perto(c.position, Vector2(30, 40)) and c.visible and not Transicoes.animando(c), "entrar termina no lugar, opaco e visível")
	Transicoes.sair(c)
	ok(c.visible and Transicoes.animando(c), "sair não esconde de uma vez: a imagem some suave")
	await _esperar(Transicoes.DUR_SAIR + 0.15)
	ok(not c.visible and c.modulate.a == 1.0 and _perto(c.position, Vector2(30, 40)), "sair termina invisível e devolve alfa e posição de repouso")
	# sair no meio de um entrar e entrar de novo no meio de um sair: terminam certos e sem empilhar o deslize
	Transicoes.entrar(c)
	await _esperar(0.05)
	Transicoes.sair(c)
	await _esperar(0.04)
	Transicoes.entrar(c)
	await _esperar(Transicoes.DUR_ENTRAR + 0.15)
	ok(
		c.visible and c.modulate.a == 1.0 and _perto(c.position, Vector2(30, 40)),
		"entrar, sair e entrar de novo acaba aberto e no lugar (%s %s %s)" % [c.visible, c.modulate.a, c.position]
	)
	# com a árvore pausada (a pausa abre assim) e com o tempo em câmera lenta, a animação anda no relógio real
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	Transicoes.sair(c)
	await _esperar(0.01)
	get_tree().paused = true
	Engine.time_scale = 0.1
	await _esperar(Transicoes.DUR_SAIR + 0.2)
	get_tree().paused = false
	Engine.time_scale = 1.0
	ok(not c.visible and _perto(c.position, Vector2(30, 40)), "a animação termina com a árvore pausada e em câmera lenta (%s %s)" % [c.visible, c.position])
	c.queue_free()
	# dentro de um Container o pai manda na posição: só fade
	var caixa := VBoxContainer.new()
	add_child(caixa)
	var filho := ColorRect.new()
	filho.custom_minimum_size = Vector2(20, 20)
	caixa.add_child(filho)
	await get_tree().process_frame
	var pos := filho.position
	Transicoes.entrar(filho)
	ok(_perto(filho.position, pos) and filho.modulate.a < 0.5, "em Container o painel só faz fade")
	await _esperar(0.04)
	_simular_reencaixe(filho, Vector2(18, 26))
	await _esperar(Transicoes.DUR_ENTRAR + 0.15)
	ok(filho.modulate.a == 1.0 and _perto(filho.position, Vector2(18, 26)), "e termina opaco no lugar refeito pelo Container")
	caixa.queue_free()


## Título -> personagens -> santuário -> partida -> pausa -> santuário, com as cenas de verdade.
func _fluxo() -> void:
	var id := Personagens.criar("Teste")
	Personagens.ativar(id)
	var titulo: Node = load(TITULO).instantiate()
	get_tree().root.add_child(titulo)
	get_tree().current_scene = titulo  # a troca de cena libera esta; o teste fica na raiz
	await _quadros(4)
	var trocas0: int = Transicoes.trocas
	# Enter duplo no título, no mesmo instante: uma troca só
	_tecla(KEY_ENTER)
	_tecla(KEY_ENTER)
	var chegou := await _ate(func(): return _na_cena(ESCOLHA), 4.0)
	ok(chegou, "Enter no título leva à escolha de personagem")
	ok(Transicoes.trocas == trocas0 + 1, "Enter duplo pede uma troca só (%d)" % (Transicoes.trocas - trocas0))
	ok(Transicoes.ativa(), "logo depois da troca a transição ainda está rodando")
	# a foto do título ainda está na tela: Enter impaciente (escolheria o personagem às cegas) e ESC duplo (iria ao título e abriria
	# "Sair") são descartados
	await _impaciente([KEY_ENTER, KEY_ESCAPE, KEY_ESCAPE], ESCOLHA)
	var t0 := Time.get_ticks_msec()
	await _fim_transicao()
	var dur := (Time.get_ticks_msec() - t0) / 1000.0
	ok(dur <= 3.0, "a transição termina sozinha (%.2f s depois da troca)" % dur)
	# a primeira entrada depois do fade vale: ESC na escolha volta ao título, uma vez
	var trocas1: int = Transicoes.trocas
	_tecla(KEY_ESCAPE)
	chegou = await _ate(func(): return _na_cena(TITULO), 4.0)
	ok(chegou and Transicoes.trocas == trocas1 + 1, "ESC na escolha volta ao título, uma vez só")
	ok(chegou and not _cena().pausa.aberto, "e o ESC não abriu o Sair do título")
	await _impaciente([KEY_ENTER], TITULO)
	await _fim_transicao()
	# Enter no título depois do fade vale, uma vez (a entrada descartada não ficou guardada para repetir)
	var trocas2: int = Transicoes.trocas
	_tecla(KEY_ENTER)
	chegou = await _ate(func(): return _na_cena(ESCOLHA), 4.0)
	ok(chegou and Transicoes.trocas == trocas2 + 1, "Enter depois do fade vai à escolha, uma vez só")
	# ir_para durante o fade da troca anterior: cancela o fade (foto e véu somem) e a nova troca acontece
	ok(Transicoes.ativa(), "o fade da ida à escolha está rodando")
	var trocas3: int = Transicoes.trocas
	ok(Transicoes.ir_para(_cena(), TITULO, true), "ir_para durante o fade da troca anterior é aceito")
	ok(not Transicoes._foto.visible and not Transicoes._veu.visible and Transicoes.ativa(), "e cancela o fade anterior na hora (nada de foto fantasma)")
	ok(not Transicoes.ir_para(_cena(), TITULO, true), "mas dois pedidos no mesmo instante continuam valendo um só")
	chegou = await _ate(func(): return _na_cena(TITULO), 4.0)
	ok(chegou and Transicoes.trocas == trocas3 + 1, "a segunda troca leva ao título (%d)" % (Transicoes.trocas - trocas3))
	await _fim_transicao()
	ok(not Transicoes._foto.visible and not Transicoes._veu.visible and Transicoes._foto.texture == null, "no fim não sobram foto nem véu nem textura guardada")
	_tecla(KEY_ENTER)
	chegou = await _ate(func(): return _na_cena(ESCOLHA), 4.0)
	ok(chegou, "Enter no título volta à escolha")
	await _fim_transicao()
	# escolhe o personagem (Enter na linha dele) e entra no santuário
	_tecla(KEY_ENTER)
	chegou = await _ate(func(): return _na_cena(SALAO), 4.0)
	ok(chegou, "a escolha leva ao santuário")
	await _fim_transicao()
	await _quadros(6)
	var salao := _cena()
	var id_salao := salao.get_instance_id() if salao != null else 0
	ok(salao != null and salao.has_method("usar_portal"), "o santuário carregou")
	if salao == null or not salao.has_method("usar_portal"):
		return
	# portal da Floresta -> partida
	ok(salao.usar_portal("floresta"), "o portal da Floresta está aberto")
	# Com #390, o portal primeiro abre a escolha; confirma pela mesma entrada real do jogador.
	if salao.has_method("_confirmar_dificuldade"):
		ok(_na_cena(SALAO), "a escolha de dificuldade mantém o santuário antes de confirmar")
		var escolha = salao.get("_escolha_dificuldade")
		ok(is_instance_valid(escolha) and escolha.visible, "o portal mostra a escolha de dificuldade")
		_tecla(KEY_ENTER)
	chegou = await _ate(func(): return _na_cena(PARTIDA), 5.0)
	ok(chegou, "o portal leva à partida")
	await _fim_transicao()
	await _esperar(0.6)
	var mundo := _cena()
	if mundo == null or mundo.scene_file_path != PARTIDA:
		return
	var pausa = _achar_pausa(mundo.ui)
	ok(pausa != null, "a partida montou a pausa")
	if pausa == null:
		return
	# ESC assim que a transição de entrada na partida acaba: a pausa responde
	_tecla(KEY_ESCAPE)
	ok(pausa.aberto and get_tree().paused, "o ESC pausa a partida mesmo logo depois da transição")
	ok(pausa._raiz.visible, "o menu de pausa aparece")
	_tecla(KEY_ESCAPE)
	ok(not pausa.aberto and not get_tree().paused, "ESC de novo fecha e despausa na hora")
	await _esperar(Transicoes.DUR_SAIR + 0.1)
	ok(not pausa._raiz.visible, "e a imagem do menu some depois do fade")
	# pausa -> Voltar ao santuário (confirma) -> resultado -> Enter -> santuário
	_tecla(KEY_ESCAPE)
	for i in 40:
		if str(pausa._itens_atuais[pausa.sel].id) == "santuario":
			break
		_tecla(KEY_DOWN)
	_tecla(KEY_ENTER)
	ok(pausa.tela == "confirmar_santuario", "Voltar ao santuário pede confirmação")
	_tecla(KEY_UP)
	_tecla(KEY_ENTER)
	ok(not get_tree().paused and not pausa.aberto, "Sim despausa a árvore")
	await _esperar(2.2)  # o resultado só aceita Enter depois de um tempo (TEMPO_ACEITA)
	_tecla(KEY_ENTER)
	chegou = await _ate(func(): return _na_cena(SALAO) and _cena().get_instance_id() != id_salao, 5.0)
	ok(chegou, "o resultado leva de volta ao santuário")
	var assentou := await _ate(func(): return not Transicoes.ativa(), 6.0)  # no CI cheio a pintura da cena nova demora
	ok(assentou and not get_tree().paused, "fim do fluxo: sem transição presa e sem árvore pausada")
	if _cena() != null:
		_cena().queue_free()
	await _quadros(2)


## Com a foto da tela antiga ainda visível, as teclas são descartadas: nada vale na cena nova, nenhuma troca nova.
func _impaciente(teclas: Array, cena: String) -> void:
	var atual := _cena()
	var trocas: int = Transicoes.trocas
	ok(
		Transicoes.ativa() and Transicoes.entrada_bloqueada() and get_tree().root.gui_disable_input,
		"com a foto da tela antiga na tela a entrada está bloqueada"
	)
	for k in teclas:
		_tecla(k)
	await _quadros(3)
	ok(_cena() == atual and _na_cena(cena) and Transicoes.trocas == trocas, "a entrada impaciente é descartada (a cena e as trocas ficam como estavam)")


## Espera o fim do fade: a entrada volta e não sobra foto, véu nem bloqueio.
func _fim_transicao() -> void:
	var fim := await _ate(func(): return not Transicoes.ativa(), 6.0)  # no CI cheio a pintura da cena nova demora
	ok(fim and not Transicoes.entrada_bloqueada() and not get_tree().root.gui_disable_input, "no fim do fade a entrada volta (fim=%s)" % fim)


func _achar_pausa(pai: Node) -> Node:
	for c in pai.get_children():
		if c.has_method("abrir_sair"):
			return c
	return null
