extends Node
# Teste automático da TELA DE CARREGAMENTO da partida (v2/carregando.gd, Transicoes.ir_para_carregando; números em
# dados/v2_carregando.json). Saves TEMPORÁRIOS em user://testes_v2/v2_carregando/ (testes/ambiente_v2.gd).
# Confere: a barra só enche; os pontos de CARREGANDO trocam no máximo 2 vezes por segundo e ficam parados com "Reduzir piscadas",
# "Reduzir animações" e no perfil Baixo; a carga de verdade até a partida (thread + aquecimento) termina na cena da partida, com a
# entrada bloqueada durante TODA a carga, um segundo pedido descartado, a tela escondida no fim e o aquecimento das folhas solto;
# em todo quadro desenhado com a tela aberta (inclusive o da troca, quando o modo de escala da janela muda) o fundo cobre a tela e o
# bloco fica no centro; com fade no perfil Alto e sem quadro de fade no Baixo; e a tela de dificuldade com o hover mais fraco.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_carregando.tscn  (imprime "v2_carregando falhas=0"). A conferência
# de cada quadro desenhado só vale com janela (sem --headless), porque sem renderizador não há quadro: rode também com janela.
const Carregando := preload("res://v2/carregando.gd")
const Sprites := preload("res://v2/sprites.gd")
const Ambiente := preload("res://testes/ambiente_v2.gd")
const PARTIDA := "res://v2/mundo.tscn"

var falhas := 0
var _quadros_ruins := 0
var _quadros_vistos := 0


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
	await _hover_dificuldade()
	await _carga_real("alto")
	await _carga_real("baixo")
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
	t.assentar()  # assentar pula para o alvo: um alvo menor não pode ter rebaixado o alvo
	ok(is_equal_approx(t.valor, 0.5) and is_equal_approx(t._cheio.size.x, 160.0), "a barra nunca volta (%s)" % t.valor)
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


## Sem o selo ESCOLHIDA, o cartão com o mouse por cima não pode ficar igual ao escolhido.
func _hover_dificuldade() -> void:
	var e = preload("res://v2/escolha_dificuldade.gd").new()
	add_child(e)
	e.abrir("Floresta")
	e._selecionar(0)
	var sel: StyleBoxFlat = e._cartoes[0].get_theme_stylebox("normal")
	for i in [1, 2]:
		var h: StyleBoxFlat = e._cartoes[i].get_theme_stylebox("hover")
		ok(h.bg_color != sel.bg_color and h.border_width_top < sel.border_width_top, "hover do cartão %d diferente do escolhido" % i)
	e.queue_free()
	await get_tree().process_frame


func _carga_real(perfil: String) -> void:
	Config.g_perfil_temporario(perfil)
	# o teste sobrevive à troca de cena: sai da cena atual e fica na raiz. A cena de partida é como o salão: tela na escala da UI
	var vazio := Control.new()
	vazio.add_child(preload("res://v2/ui_janela.gd").new().montar(vazio))
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
	var sempre_bloqueada := true
	var viu_fade := false
	_quadros_ruins = 0
	_quadros_vistos = 0
	RenderingServer.frame_pre_draw.connect(_conferir_quadro)  # liga depois da tela: roda depois do reencaixe dela
	var fim := Time.get_ticks_msec() + 60000
	while Transicoes.ativa() and Time.get_ticks_msec() < fim:
		viu_barra = viu_barra or (Transicoes._carga.valor > 0.0 and Transicoes._carga.valor < 1.0)
		if Transicoes._pendente:
			sempre_bloqueada = sempre_bloqueada and Transicoes.entrada_bloqueada() and get_tree().root.gui_disable_input
		var a: float = Transicoes._carga.modulate.a
		viu_fade = viu_fade or (Transicoes._carga.visible and a > 0.01 and a < 0.99)
		await get_tree().process_frame
	RenderingServer.frame_pre_draw.disconnect(_conferir_quadro)
	ok(sempre_bloqueada, "a entrada fica bloqueada a carga inteira, até a troca (%s)" % perfil)
	if DisplayServer.get_name() != "headless":  # sem renderizador não há quadro desenhado (frame_pre_draw não dispara): só com janela
		ok(
			_quadros_vistos > 3 and _quadros_ruins == 0,
			"fundo cobre a tela e bloco no centro em todo quadro (%d de %d ruins, %s)" % [_quadros_ruins, _quadros_vistos, perfil]
		)
	if perfil == "baixo":
		ok(not viu_fade, "no perfil Baixo a tela some sem fade")
	else:
		ok(viu_fade, "no perfil %s a tela some com fade" % perfil)
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


## Antes de cada quadro desenhado com a tela de carregamento aberta: o fundo cobre a área visível e o bloco está no centro dela.
func _conferir_quadro() -> void:
	var c = Transicoes._carga
	if c == null or not c.visible:
		return
	_quadros_vistos += 1
	var vis := c.get_viewport().get_visible_rect()
	var fundo: Rect2 = c._fundo.get_global_rect()
	var bloco := Rect2(c._bloco.global_position, c._bloco.size * c._bloco.scale)
	if not fundo.encloses(vis) or bloco.get_center().distance_to(vis.get_center()) > 2.0 or not vis.encloses(bloco):
		_quadros_ruins += 1
		print("quadro ruim: vis=%s fundo=%s bloco=%s" % [vis, fundo, bloco])
