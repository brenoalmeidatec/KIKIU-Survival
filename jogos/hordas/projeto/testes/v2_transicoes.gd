extends Node
# Teste automático das transições suaves entre telas da v2 (#377, v2/transicoes.gd, autoload "Transicoes"). Usa saves TEMPORÁRIOS
# (user://teste_v2_transicoes_*): o save real, os personagens e user://opcoes.cfg não são tocados (conferido por md5).
# Confere: a duração de cada transição fica entre 0,15 e 0,25 s; "Reduzir animações" (Config, Acessibilidade) zera tudo e o painel
# aparece e some na hora; entrar/sair animam de verdade (alfa e posição) e voltam ao repouso, inclusive com a árvore pausada e
# com um sair no meio de um entrar; um painel dentro de Container só faz fade; Enter duplo pede UMA troca de cena (a segunda é
# descartada), a entrada logo depois da troca chega à cena nova uma vez só e o ESC no meio da transição ainda volta uma tela;
# e o fluxo de verdade título -> personagens -> santuário -> partida -> pausa (ESC) -> santuário, com cenas reais, não trava.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_transicoes.tscn  (imprime "v2_transicoes falhas=0")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const PREFIXO := "user://teste_v2_transicoes_p"
const INDICE := "user://teste_v2_transicoes_personagens.cfg"
const ANTIGO := "user://teste_v2_transicoes_progresso.cfg"
const META_TESTE := "user://teste_v2_transicoes_meta.cfg"
const OPCOES_TESTE := "user://teste_v2_transicoes_opcoes.cfg"
const SAVE_REAL := "user://v2_progresso.cfg"
const OPCOES_REAL := "user://opcoes.cfg"
const TITULO := "res://v2/menu_principal.tscn"
const ESCOLHA := "res://v2/personagens.tscn"
const SALAO := "res://v2/salao.tscn"
const PARTIDA := "res://v2/mundo.tscn"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Personagens.caminho_base = PREFIXO
	Personagens.caminho_indice = INDICE
	Personagens.caminho_antigo = ANTIGO
	Meta.caminho_save = META_TESTE
	Config.arquivo = OPCOES_TESTE
	var md5_save := _md5(SAVE_REAL)
	var md5_opc := _md5(OPCOES_REAL)
	_limpar()
	await _testes()
	_limpar()
	get_tree().paused = false
	ok(_md5(SAVE_REAL) == md5_save, "o save real da meta não foi tocado")
	ok(_md5(OPCOES_REAL) == md5_opc, "as opções reais não foram tocadas")
	print("v2_transicoes falhas=%d" % falhas)
	get_tree().quit()


func _md5(caminho: String) -> String:
	return FileAccess.get_md5(caminho) if FileAccess.file_exists(caminho) else ""


func _limpar() -> void:
	for c in [INDICE, ANTIGO, ANTIGO + ".bak", META_TESTE, META_TESTE + ".bak", META_TESTE + ".tmp", OPCOES_TESTE]:
		_apagar(c)
	for i in range(1, 6):
		var base := Personagens.caminho_do_save("p%d" % i)
		for s in ["", ".bak", ".tmp"]:
			_apagar(base + s)


func _apagar(caminho: String) -> void:
	if FileAccess.file_exists(caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))


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


func _cena() -> Node:
	return get_tree().current_scene


func _na_cena(caminho: String) -> bool:
	return _cena() != null and _cena().scene_file_path == caminho


func _testes() -> void:
	await _quadros(5)  # o primeiro quadro do Godot tem um delta enorme; as animações medidas começam depois dele
	_constantes()
	_opcao()
	await _painel()
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
	await _esperar(Transicoes.DUR_ENTRAR + 0.15)
	ok(filho.modulate.a == 1.0 and _perto(filho.position, pos), "e termina opaco no mesmo lugar")
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
	var t0 := Time.get_ticks_msec()
	await _ate(func(): return not Transicoes.ativa(), 2.0)
	var dur := (Time.get_ticks_msec() - t0) / 1000.0
	ok(not Transicoes.ativa() and dur <= Transicoes.DUR_TROCA + 0.35, "a transição termina sozinha em cerca de 0,2 s (%.2f)" % dur)
	# ESC na escolha volta ao título, uma vez
	var trocas1: int = Transicoes.trocas
	_tecla(KEY_ESCAPE)
	chegou = await _ate(func(): return _na_cena(TITULO), 4.0)
	ok(chegou and Transicoes.trocas == trocas1 + 1, "ESC na escolha volta ao título, uma vez só")
	await _quadros(3)
	# com a transição de volta ainda rodando, Enter vai à escolha de novo (a entrada não se perde)
	var trocas2: int = Transicoes.trocas
	ok(Transicoes.ativa(), "a transição de volta ainda está rodando")
	_tecla(KEY_ENTER)
	chegou = await _ate(func(): return _na_cena(ESCOLHA), 4.0)
	ok(chegou and Transicoes.trocas == trocas2 + 1, "Enter durante a transição de volta ainda vale")
	await _quadros(4)
	# escolhe o personagem (Enter na linha dele) e entra no santuário
	_tecla(KEY_ENTER)
	chegou = await _ate(func(): return _na_cena(SALAO), 4.0)
	ok(chegou, "a escolha leva ao santuário")
	await _quadros(6)
	var salao := _cena()
	var id_salao := salao.get_instance_id() if salao != null else 0
	ok(salao != null and salao.has_method("usar_portal"), "o santuário carregou")
	if salao == null or not salao.has_method("usar_portal"):
		return
	# portal da Floresta -> partida
	ok(salao.usar_portal("floresta"), "o portal da Floresta está aberto")
	chegou = await _ate(func(): return _na_cena(PARTIDA), 5.0)
	ok(chegou, "o portal leva à partida")
	await _esperar(0.6)
	var mundo := _cena()
	if mundo == null or mundo.scene_file_path != PARTIDA:
		return
	var pausa = _achar_pausa(mundo.ui)
	ok(pausa != null, "a partida montou a pausa")
	if pausa == null:
		return
	# ESC logo depois da transição de entrada na partida: a pausa responde
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
	await _esperar(Transicoes.DUR_TROCA + 0.3)
	ok(not Transicoes.ativa() and not get_tree().paused, "fim do fluxo: sem transição presa e sem árvore pausada")
	if _cena() != null:
		_cena().queue_free()
	await _quadros(2)


func _achar_pausa(pai: Node) -> Node:
	for c in pai.get_children():
		if c.has_method("abrir_sair"):
			return c
	return null
