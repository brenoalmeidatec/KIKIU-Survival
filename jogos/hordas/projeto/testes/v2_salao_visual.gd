extends Control
# QA visual 960x540: contratos de PNG/cache, geometria medida, proximidade e interacao.
# Saves com prefixo unico; hashes dos saves reais conferidos no fim. Sem benchmark.
# godot --headless --path jogos/hordas/projeto res://testes/v2_salao_visual.tscn
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
const Mapas = preload("res://v2/mapas.gd")
var falhas := 0
var pasta := ""

var s
var chamadas := []
var reais := {}
var prefixo := ""


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prints="):
			pasta = arg.trim_prefix("--prints=")
	prefixo = "qa_visual_%d_" % Time.get_ticks_usec()
	var d := DirAccess.open("user://")
	for arquivo in d.get_files():
		if arquivo.begins_with("v2_"):
			reais[arquivo] = FileAccess.get_md5("user://" + arquivo)
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	Meta.caminho_save = "user://" + prefixo + "meta.cfg"
	var id := Personagens.criar("Matheus")
	ok(Personagens.ativar(id), "slot isolado ativo")
	DisplayServer.window_set_size(Vector2i(960, 540))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	s = load("res://v2/salao.tscn").instantiate()
	add_child(s)
	s.ao_entrar = func(cena): chamadas.append(cena)
	await get_tree().process_frame
	await get_tree().process_frame
	await foto("01_salao")
	ok(s._nome_lbl.text == "Matheus", "nome completo preservado")
	assets()
	camadas()
	saldo_no_painel()
	painel_graficos()
	for filho in s.get_children():
		if filho is Button:
			var largura: float = (
				filho.get_theme_font("font").get_string_size(filho.text, HORIZONTAL_ALIGNMENT_LEFT, -1, filho.get_theme_font_size("font_size")).x
			)
			var estilo: StyleBox = filho.get_theme_stylebox("normal")
			ok(largura + estilo.get_minimum_size().x <= filho.size.x + 0.5, "texto inteiro no botao: " + filho.text)
	ok(s._alvos.size() == 3 + Mapas.LISTA.size(), "todas estruturas e portais")
	for a in s._alvos:
		var ponto: Vector2 = a.pos.clamp(s.ANDAR_MIN, s.ANDAR_MAX)
		ok(ponto.distance_to(a.pos) <= s.ALCANCE * 0.8, "alvo alcançavel " + str(a.id))
		s._pos = ponto
		s._atualizar_prompt()
		ok(s._prompt.visible and s._prompt_de == str(a.id), "prompt proximidade " + str(a.id))
		ok(Rect2(0, 0, 960, 540).encloses(s._prompt.get_rect()), "prompt no viewport " + str(a.id))
		await foto("prompt_" + str(a.id))
		var evento := InputEventJoypadButton.new()
		evento.button_index = JOY_BUTTON_A
		evento.pressed = true
		s._unhandled_input(evento)
		if a.tipo == "estrutura":
			ok(s._painel.visible, "A abre " + str(a.id))
			await get_tree().process_frame
			await foto("painel_" + str(a.id))
			for i in s._p_itens.size():
				s._mostrar_item(i)
				await get_tree().process_frame
				geometria()
				await foto("item_" + str(a.id) + "_%02d" % i)
			s._fechar_painel()
		else:
			ok(chamadas.size() > 0 and Mapas.escolhido() == str(a.id), "A usa portal " + str(a.id))
	# Clique passa pelo handler da sala; simula deslocamento acelerado sem trocar cenas.
	for a in s._alvos:
		s._pos = Vector2(480, 480)
		var mouse := InputEventMouseButton.new()
		mouse.position = a.pos
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		s._unhandled_input(mouse)
		ok(s._destino == a.pos, "clique seleciona alvo " + str(a.id))
		for quadro in 300:
			if s._destino == Vector2.INF:
				break
			s._process(1.0 / 60.0)
		ok(s._destino == Vector2.INF, "clique chega e usa " + str(a.id))
		if s._painel.visible:
			s._fechar_painel()
	ok(Mapas.condicao({"requer": "combo_50"}).begins_with("Fechado"), "condicao bloqueada preservada")
	ok(Mapas.condicao({}) == "", "portais sem requisito abertos")
	Meta.creditar(300)
	s._atualizar_textos()
	ok(s.comprar_item("dano") and Meta.nivel("dano") == 1, "compra no save isolado")
	s._pos = Vector2(480, 400)
	s._destino = Vector2.INF
	await foto("02_salao_almas")

	for arquivo in reais:
		ok(FileAccess.get_md5("user://" + arquivo) == reais[arquivo], "save real intacto " + arquivo)
	for arquivo in d.get_files():
		if arquivo.begins_with(prefixo):
			d.remove(arquivo)
	s.queue_free()
	s = null
	await get_tree().process_frame
	await get_tree().process_frame
	print("v2_salao_visual falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func foto(nome: String) -> void:
	if pasta.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join("visual_" + nome + ".png"))


func geometria() -> void:
	var cartao := Rect2(36, 26, 888, 488)
	for controle in [s._p_titulo, s._p_icone_estrutura, s._p_icone, s._p_nome, s._p_frase, s._p_card, s._p_saldo, s._p_aviso, s._p_comprar, s._p_rolagem]:
		if controle.visible:
			ok(cartao.encloses(controle.get_rect()), "conteudo dentro do cartao: " + str(controle.name))
			ok(controle.get_minimum_size().y <= controle.size.y + 0.5, "altura minima medida cabe: " + str(controle.name))
	ok(s._p_rolagem.follow_focus, "rolagem acompanha foco do controle")
	for botao in s._p_lista.get_children():
		ok(botao.size.x <= s._p_rolagem.size.x, "lista sem overflow horizontal")


# Regressão do #320 ("santuário vazio"): a sala é desenhada pelo salao_vivo nas CanvasLayers -2 e -1, abaixo da camada padrão; um fundo
# opaco na camada padrão tampa tudo. O chão das bordas tem de ficar numa camada abaixo da sala.
func camadas() -> void:
	ok(s._camadas.size() == 3, "tres camadas da sala (fundo, cena, brilho)")
	ok(s._camadas[0].layer < s._camadas[1].layer and s._camadas[0].layer < s._camadas[2].layer, "chao das bordas abaixo da sala")
	for filho in s.get_children():
		if filho is ColorRect and filho.visible and filho.color.a > 0.95:
			ok(filho.size.x * filho.size.y < 960.0 * 540.0 * 0.5, "nenhum fundo opaco na camada da interface tapa a sala: " + str(filho.name))
	for c in s._camadas:
		ok(c.offset == s.EscalaUi.desloc_atual, "camada da sala segue o bloco")


# Pedido do Alisson (18/10): o saldo aparece no próprio painel e o COMPRAR sem almas parece desligado.
func saldo_no_painel() -> void:
	s.abrir_estrutura("estatuas")
	s._mostrar_item(0)
	ok(s._p_saldo.text == "ALMAS %d" % Meta.saldo(), "saldo no cabecalho do painel")
	ok(Rect2(36, 26, 888, 70).encloses(s._p_saldo.get_rect()), "saldo no cabecalho, ao lado do VOLTAR")
	ok(Meta.saldo() == 0 and s._p_comprar.disabled and s._p_comprar.text == "SEM ALMAS", "sem almas: botao desligado e diz por que")
	ok(s._p_comprar.focus_mode == Control.FOCUS_NONE, "desligado nao recebe o foco dourado")
	Meta.creditar(1000)
	s._mostrar_item(0)
	ok(not s._p_comprar.disabled and s._p_comprar.text == "COMPRAR" and s._p_comprar.focus_mode == Control.FOCUS_ALL, "com almas: COMPRAR ativo")
	ok(s._p_saldo.text == "ALMAS 1000", "saldo do painel atualiza")
	Meta.creditar(-1000)
	s._fechar_painel()


func assets() -> void:
	var contrato := {"fundo": Vector2i(960, 540), "estatuas": Vector2i(112, 112), "altar": Vector2i(112, 112), "codice": Vector2i(112, 112)}
	for id in ["floresta", "laboratorio", "cidade", "medio", "fechado"]:
		contrato["portal_" + id] = Vector2i(112, 142)
	var cache: Dictionary = s._visual.texturas.duplicate()
	for nome in contrato:
		ok(cache.has(nome), "asset carregado: " + nome)
		if not cache.has(nome):
			continue
		var textura: Texture2D = cache[nome]
		ok(Vector2i(textura.get_size()) == contrato[nome], "dimensoes: " + nome)
		if nome != "fundo":
			var imagem := textura.get_image()
			ok(imagem.detect_alpha() != Image.ALPHA_NONE and imagem.get_pixel(0, 0).a == 0.0, "sprite transparente: " + nome)
	for quadro in 30:
		s._process(1.0 / 60.0)
	for nome in cache:
		ok(s._visual.texturas[nome] == cache[nome], "textura memoizada: " + nome)


# Pedido do Alisson (18/10): o painel é título, uma frase de uma linha e um card de barrinhas; tudo com ícone; sem DETALHES; sala mais rápida.
func painel_graficos() -> void:
	ok(s.VELOCIDADE >= 130.0 * 1.6 - 0.5, "anda no santuario ~1,6x mais rapido")
	Meta.creditar(500)
	ok(s.comprar_item("vida") and s.comprar_item("vida"), "duas compras de vida para a barra ter o que mostrar")
	for id in ["estatuas", "altar", "codice"]:
		s.abrir_estrutura(id)
		ok(s._p_icone_estrutura.texture != null, "icone da estrutura no cabecalho: " + id)
		for b in s._p_lista.get_children():
			ok(b.icon != null, "icone em cada item da lista: " + b.text.get_slice(char(10), 0))
		for filho in s._painel.get_children():
			ok(not (filho is Button and filho.text == "DETALHES"), "sem botao DETALHES")
		for i in s._p_itens.size():
			s._mostrar_item(i)
			var it: Dictionary = s._p_itens[i]
			ok(s._p_icone.texture != null, "icone no titulo do item " + str(it.id))
			ok(s._p_frase.text != "" and s._p_frase.get_line_count() == 1, "subtitulo de uma linha: " + str(it.id))
			var linhas: Array = s._p_card.linhas
			ok(linhas.size() == 3, "card com tres linhas de barrinhas: " + str(it.id))
			if linhas.size() < 3:
				continue
			if id == "codice":
				ok(linhas[0].tipo == "segmentos" and int(linhas[0].max) == Meta.conquistas().size(), "codice: um segmento por conquista")
				ok(linhas[2].get("icone") != null, "codice: icone da recompensa")
			else:
				var n := Meta.nivel(str(it.id))
				ok(linhas[0].tipo == "segmentos" and int(linhas[0].max) == int(it.max) and int(linhas[0].n) == n, "nivel em segmentos: " + str(it.id))
				ok(linhas[1].tipo == "barra" and is_equal_approx(float(linhas[1].frac), float(n) / int(it.max)), "efeito em barra: " + str(it.id))
				if n < int(it.max) and s._liberada(it):
					var custo := Meta.custo_do_nivel(it, n)
					ok(is_equal_approx(float(linhas[2].frac), float(Meta.saldo()) / custo), "custo x saldo em barra: " + str(it.id))
		s._fechar_painel()
	Meta.creditar(-Meta.saldo())
