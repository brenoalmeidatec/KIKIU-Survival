extends Node
# Teste automático (#125, Marco 1A): o HUD novo (cenas/hud.tscn). Elementos presentes e no lugar certo, a opção de tamanho da
# fonte muda o Theme, as opções de leitura (partículas, números de dano, nomes) valem, o banner de conjunto aparece e some
# em 2 s, a prorrogação aparece no topo e o que saiu da tela (abates, lista de conjuntos) não voltou.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/hud.tscn  (imprime "HUD falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func rect(h: Node, nome: String) -> Rect2:
	var n: Control = h.get_node("%" + nome)
	return n.get_global_rect()


func textos(n: Node, saida: Array) -> void:
	if n is Label:
		saida.append((n as Label).text)
	for c in n.get_children():
		textos(c, saida)


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	Config.temporario("texto_hud", "normal")
	Config.g_perfil_temporario("alto")
	Config.g_temporario("particulas_sim", "muitas")
	Config.temporario("numeros_dano", true)
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = false
	add_child(a)
	await esperar(1.6)
	var h = a.hud
	h.atualizar(0.05)
	await esperar(0.1)

	# --- elementos e lugares
	ok(h.get_node("Raiz").theme != null, "o HUD tem um Theme")
	for nome in ["Retrato", "HeroiNome", "HeroiVida", "Carga", "Ouro", "Almas", "Tempo", "Regiao", "Hab1", "Hab2", "Provisoes", "Minimapa", "Xp", "Msgs", "Banner", "Pausa", "Duelo"]:
		ok(h.get_node_or_null("%" + nome) != null, "existe o nó " + nome)
	var heroi := rect(h, "Heroi")
	ok(heroi.position.x < 20.0 and heroi.position.y < 30.0 and heroi.end.x < 200.0, "retrato, nome e vida ficam em cima à esquerda: %s" % heroi)
	ok(rect(h, "Retrato").size.x >= 30.0, "o retrato tem tamanho")
	ok(h.get_node("%HeroiNome").text == str(a.heroi.get("nome", "")), "o nome do herói")
	ok(h.get_node("%HeroiVida").max_value >= 1.0 and h.get_node("%HeroiVidaTxt").text.contains("/"), "vida mostra atual/máxima")
	var dir := rect(h, "Dir")
	ok(dir.end.x > 600.0 and dir.position.y < 30.0, "ouro e almas ficam em cima à direita: %s" % dir)
	ok(h.get_node("%Ouro").text.begins_with("Ouro") and h.get_node("%Almas").text == "Almas 0", "ouro e almas (almas fica em 0)")
	var tempo := rect(h, "Tempo")
	ok(absf(tempo.get_center().x - 320.0) < 20.0 and tempo.position.y < 40.0, "cronômetro pequeno no topo, centralizado: %s" % tempo)
	ok(absf(rect(h, "Regiao").get_center().x - 320.0) < 20.0, "região e andar no topo, centralizados")
	ok(h.get_node("%Regiao").text.contains("/"), "região mostra o andar (n/5): " + h.get_node("%Regiao").text)
	ok(rect(h, "Hab1").position.x < 100.0 and rect(h, "Hab1").position.y > 250.0, "habilidade 1 embaixo à esquerda: %s" % rect(h, "Hab1"))
	ok(rect(h, "Hab2").position.x > rect(h, "Hab1").position.x and rect(h, "Hab2").position.y > 250.0, "habilidade 2 ao lado da 1")
	var mm := rect(h, "Minimapa")
	ok(mm.end.x > 600.0 and mm.end.y > 330.0 and mm.size.x >= 60.0, "espaço do minimapa embaixo à direita: %s" % mm)
	ok(not h.get_node("%Minimapa").visible, "o espaço do minimapa fica reservado (escondido até o Marco 4)")
	ok(rect(h, "Xp").size.x >= 639.0 and rect(h, "Xp").position.y < 1.0, "barra de XP no topo, de ponta a ponta")
	ok(not h.get_node("%Pausa").visible and not h.get_node("%Banner").visible and not h.get_node("%Duelo").visible, "pausa, banner e duelo começam escondidos")

	# --- o que saiu da tela não voltou
	var todos: Array = []
	textos(h, todos)
	var junto := " | ".join(todos)
	ok(not junto.contains("Abates"), "sem contador de abates na tela: " + junto)

	# --- opção de tamanho da fonte
	var th: Theme = h.get_node("Raiz").theme
	ok(th.default_font_size == 8, "1x: fonte 8 no Theme")
	var larg1: float = rect(h, "Heroi").size.x
	Config.temporario("texto_hud", "medio")
	h._process_i(0.016)
	await esperar(0.1)
	ok(th.default_font_size == 12 and h.get_node("%Ouro").get_theme_font_size("font_size") == 12, "1,5x: fonte 12 em todo o HUD")
	ok(rect(h, "Heroi").size.x >= larg1, "1,5x: o painel do herói não encolhe")
	Config.temporario("texto_hud", "grande")
	h._process_i(0.016)
	await esperar(0.1)
	ok(th.default_font_size == 16 and h.get_node("%Ouro").get_theme_font_size("font_size") == 16, "2x: fonte 16 em todo o HUD")
	ok(rect(h, "Dir").end.x <= 640.0 and rect(h, "Dir").position.x > 320.0, "2x: ouro e almas continuam dentro da tela")
	Config.temporario("texto_hud", "normal")
	h._process_i(0.016)
	ok(th.default_font_size == 8, "voltando para 1x")

	# --- partículas, números de dano e nomes de inimigo
	var ef = a.efeitos
	ef.limpar()
	ef.explodir(Vector2.ZERO, Color.WHITE, 6)
	ok(ef.particulas.size() == 6, "partículas Todas: %d" % ef.particulas.size())
	ef.limpar()
	Config.g_temporario("particulas_sim", "nenhuma")
	ef.explodir(Vector2.ZERO, Color.WHITE, 6)
	ef.faisca(Vector2.ZERO, Vector2.ZERO, Color.WHITE, 3)
	ok(ef.particulas.is_empty() and ef.faiscas.is_empty(), "partículas Nenhuma: nada nasce")
	ok(is_zero_approx(Config.fator_particulas("elem_part")) and is_zero_approx(Config.fator_particulas("amb_particulas")), "Nenhuma zera as partículas do ambiente e dos elementos")
	Config.g_temporario("particulas_sim", "medias")
	ef.explodir(Vector2.ZERO, Color.WHITE, 6)
	ok(ef.particulas.size() == 4, "partículas Médias (60%% do alto, o nível médio de particulas_sim): %d" % ef.particulas.size())
	Config.g_perfil_temporario("alto")
	Config.g_temporario("particulas_sim", "muitas")
	ef.limpar()
	ef.numero(Vector2.ZERO, 5.0)
	ok(ef.numeros.size() == 1, "números de dano ligados")
	ef.limpar()
	Config.temporario("numeros_dano", false)
	ef.numero(Vector2.ZERO, 5.0)
	ok(ef.numeros.is_empty(), "números de dano desligados")
	Config.temporario("numeros_dano", true)
	ok(Config.item("nomes_inimigo").get("padrao") == true and not Config.g_opcao("particulas_sim").is_empty() and Config.item("texto_hud").valores.size() == 3, "as opções novas estão na lista")
	var it_texto: Dictionary = Config.item("texto_hud")
	ok(tr(str(it_texto.nome)) == "Tamanho da fonte do HUD" and Config.rotulo("texto_hud") == "1x", "tradução pt_BR das opções: " + tr(str(it_texto.nome)))

	# --- banner de conjunto (2 s)
	h.banner_conjunto("Lâmina", "Dano +10%")
	ok(h.get_node("%Banner").visible, "o banner de conjunto aparece")
	ok(h.get_node("%BannerTitulo").text.contains("Lâmina"), "o banner diz o conjunto: " + h.get_node("%BannerTitulo").text)
	h.atualizar(1.0)
	ok(h.get_node("%Banner").visible, "depois de 1 s o banner ainda está lá")
	h.atualizar(1.2)
	ok(not h.get_node("%Banner").visible, "depois de 2 s o banner some")
	# o mesmo banner disparado pela build: um degrau novo de conjunto
	h._t = 5.0
	a.conj_resumo = [{"etq": "teste", "nome": "Teste", "n": 2, "ativo": 0, "prox": 2, "cor": Color.RED, "texto": ""}]
	h.atualizar(0.1)
	ok(not h.get_node("%Banner").visible, "sem degrau novo, sem banner")
	a.conj_resumo = [{"etq": "teste", "nome": "Teste", "n": 2, "ativo": 1, "prox": 4, "cor": Color.RED, "texto": "Dano +5%"}]
	h.atualizar(0.1)
	ok(h.get_node("%Banner").visible, "degrau novo de conjunto dispara o banner")
	h.atualizar(2.5)
	ok(not h.get_node("%Banner").visible, "e ele some sozinho")

	# --- prorrogação e mensagens
	var d = a.diretor
	var dur := float(d.fases()[d.fase_idx].get("duracao", 600))
	d.final_chamado = true
	d.t_fase = dur + float(d.pror_cfg().get("janela_chefe", 120.0)) + 7.0
	h.atualizar(0.05)
	ok(h.get_node("%Tempo").text.begins_with("+00:0"), "a prorrogação mostra o cronômetro subindo: " + h.get_node("%Tempo").text)
	ok(h.get_node("%Sub").visible and h.get_node("%Sub").text.contains("PRORROGA"), "e o nível/ouro dela: " + h.get_node("%Sub").text)
	h.mensagem("Teste de mensagem")
	h.atualizar(0.05)
	var vistos: Array = []
	textos(h.get_node("%Msgs"), vistos)
	ok("Teste de mensagem" in vistos, "mensagem aparece")
	h.anunciar("Anúncio")
	h.atualizar(0.05)
	ok(h.get_node("%Anuncio").visible and h.get_node("%Anuncio").text == "Anúncio", "anúncio aparece")

	# --- pausa
	h.pausar()
	await esperar(0.1)
	ok(h.get_node("%Pausa").visible and get_tree().paused, "pausa abre o menu e para o jogo")
	var tp: Array = []
	textos(h.get_node("%Pausa"), tp)
	ok("PAUSADO" in tp and " ".join(tp).contains("Continuar") and " ".join(tp).contains("Opções") and " ".join(tp).contains("Desistir"), "menu de pausa com as 3 opções: " + str(tp))
	h._retomar()
	ok(not h.get_node("%Pausa").visible and not get_tree().paused, "continuar fecha o menu")

	a.queue_free()
	await esperar(0.2)
	print("HUD falhas=%d" % falhas)
	get_tree().quit()
