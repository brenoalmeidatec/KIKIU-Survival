extends Node
# Teste automático da TELA DE CARREGAMENTO da partida (v2/carregando.gd, Transicoes.ir_para_carregando; números em
# dados/v2_carregando.json). Saves TEMPORÁRIOS em user://testes_v2/v2_carregando/ (testes/ambiente_v2.gd).
# Confere: a barra só enche; os pontos de CARREGANDO trocam no máximo 2 vezes por segundo e ficam parados com "Reduzir piscadas",
# "Reduzir animações" e no perfil Baixo; a carga de verdade até a partida (thread + aquecimento) termina na cena da partida, com a
# entrada bloqueada durante a carga, um segundo pedido descartado, a tela escondida no fim e o aquecimento das folhas solto.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_carregando.tscn  (imprime "v2_carregando falhas=0")
const Carregando := preload("res://v2/carregando.gd")
const Sprites := preload("res://v2/sprites.gd")
const Ambiente := preload("res://testes/ambiente_v2.gd")
const PARTIDA := "res://v2/mundo.tscn"

var falhas := 0


func _init() -> void:
	Ambiente.iniciar(get_script().resource_path)


func _exit_tree() -> void:
	Ambiente.finalizar()


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	_dados()
	await _barra_e_pontos()
	await _carga_real()
	Transicoes._encerrar()
	Ambiente.finalizar()
	print("v2_carregando falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func _dados() -> void:
	var c := Carregando.cfg()
	ok(c.has("_ajuda"), "o json tem _ajuda")
	ok(float(c.pontos_s) >= 0.5, "os pontos trocam no máximo 2 vezes por segundo (pontos_s %s)" % c.pontos_s)
	ok(float(c.peso_cena) + float(c.peso_passos) < 1.0, "sobra uma fatia da barra para a montagem da partida")
	for d in c.dicas:
		ok(str(d).length() <= 60, "dica curta: " + str(d))


func _barra_e_pontos() -> void:
	var t := Carregando.new()
	add_child(t)
	t.abrir("Floresta")
	ok(t.visible and t._titulo.text == "FLORESTA" and t.valor == 0.0, "abrir mostra o destino e a barra vazia")
	t.alvo(0.5)
	t._process(10.0)
	ok(is_equal_approx(t.valor, 0.5), "a barra chega ao alvo")
	t.alvo(0.2)
	t._process(10.0)
	ok(is_equal_approx(t.valor, 0.5), "a barra nunca volta")
	# pontos: conta as trocas do texto num segundo simulado em passos de 1/60 s
	Config.temporario("reduzir_piscadas", false)
	Config.temporario("reduzir_animacoes", false)
	Config.g_perfil_temporario("alto")
	ok(_trocas_em_1s(t) <= 2 and _trocas_em_1s(t) >= 1, "os pontos andam, no máximo 2 trocas por segundo")
	Config.temporario("reduzir_piscadas", true)
	ok(_trocas_em_1s(t) == 0, "com Reduzir piscadas os pontos ficam parados")
	Config.temporario("reduzir_piscadas", false)
	Config.temporario("reduzir_animacoes", true)
	ok(_trocas_em_1s(t) == 0, "com Reduzir animações os pontos ficam parados")
	Config.temporario("reduzir_animacoes", false)
	Config.g_perfil_temporario("baixo")
	ok(_trocas_em_1s(t) == 0, "no perfil Baixo os pontos ficam parados")
	Config.g_perfil_temporario("alto")
	t.queue_free()
	await get_tree().process_frame


func _trocas_em_1s(t) -> int:
	t._process(0.0)  # assenta o texto da opção recém-mudada antes de contar
	var antes: String = t._estado.text
	var n := 0
	for i in 60:
		t._process(1.0 / 60.0)
		if t._estado.text != antes:
			n += 1
			antes = t._estado.text
	return n


func _carga_real() -> void:
	# o teste sobrevive à troca de cena: sai da cena atual e fica na raiz
	var vazio := Node.new()
	get_tree().root.add_child(vazio)
	var r := get_tree().root
	r.remove_child(self)
	r.add_child(self)
	get_tree().current_scene = vazio
	await get_tree().process_frame
	var cargas0: int = Transicoes.cargas
	ok(Transicoes.ir_para_carregando(vazio, PARTIDA, "Floresta"), "o pedido de carga é aceito")
	ok(not Transicoes.ir_para_carregando(vazio, PARTIDA, "Floresta"), "o segundo pedido no mesmo instante é descartado")
	ok(Transicoes.carregando() and Transicoes._carga.visible, "a tela de carregamento aparece na hora")
	ok(Transicoes.entrada_bloqueada() and get_tree().root.gui_disable_input, "a entrada fica bloqueada durante a carga")
	var viu_barra := false
	var fim := Time.get_ticks_msec() + 60000
	while Transicoes.ativa() and Time.get_ticks_msec() < fim:
		viu_barra = viu_barra or (Transicoes._carga.valor > 0.0 and Transicoes._carga.valor < 1.0)
		await get_tree().process_frame
	ok(not Transicoes.ativa(), "a carga termina")
	ok(viu_barra, "a barra andou no meio da carga")
	var cena := get_tree().current_scene
	ok(cena != null and cena.scene_file_path == PARTIDA, "terminou na partida")
	ok(not Transicoes._carga.visible and not Transicoes.entrada_bloqueada(), "a tela some e a entrada volta")
	ok(Transicoes.cargas == cargas0 + 1, "uma carga só")
	ok(Sprites._quentes.is_empty() and Sprites._borradas.is_empty() and Sprites.aquecendo() == 0, "o aquecimento das folhas foi solto")
	if cena != null:
		ok(cena.sprites.ms_blur < 100.0, "as sombras borradas vieram prontas da thread (%.0f ms no _ready)" % cena.sprites.ms_blur)
		cena.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
