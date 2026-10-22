extends "res://testes/isolamento_v2.gd"
# Teste automático do tamanho da interface (v2/escala_ui.gd, v2/apresentacao.gd): o fator por tamanho de janela e opção (tabela), o canvas
# que nunca é menor que o bloco 960x540 nem deixa a janela sem cobertura, a opção "Tamanho da interface" em Ajustes > Gráficos (gira e
# salva em opções), e o mundo da v2 reagindo: o SubViewport da UI ganha o tamanho do canvas, as CanvasLayers vão para o centro, o HUD,
# o minimapa e o fps grudam nas bordas do canvas, os fundos cobrem tudo e o mouse da janela volta ao bloco. Troca da opção ao vivo.
# O tamanho da janela é forçado por EscalaUi.janela_forcada (headless não tem janela de verdade). Opções num arquivo temporário.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_escala_ui.tscn  (imprime "v2_escala_ui falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const EscalaUi := preload("res://v2/escala_ui.gd")
const AjustesGraficos := preload("res://v2/ajustes_graficos.gd")
const OPCOES_TESTE := "user://testes_v2/v2_escala_ui/teste_v2_escala_ui_opcoes.cfg"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func perto(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.01


func _ready() -> void:
	Config.arquivo = OPCOES_TESTE
	_tabela()
	await _mundo()
	EscalaUi.janela_forcada = Vector2i.ZERO
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OPCOES_TESTE))
	Config.arquivo = "user://testes_v2/v2_escala_ui/opcoes.cfg"
	print("v2_escala_ui falhas=%d" % falhas)
	get_tree().quit()


## janela -> fator por opção (auto, pequeno, medio, grande)
func _tabela() -> void:
	var casos := [
		[Vector2(960, 540), [1.0, 1.0, 1.0, 1.0]],
		[Vector2(1280, 720), [1.0, 1.0, 1.0, 1.0]],
		[Vector2(1280, 800), [1.0, 1.0, 1.0, 1.0]],
		[Vector2(1600, 900), [1.0, 1.0, 1.0, 1.5]],
		[Vector2(1680, 1050), [1.0, 1.0, 1.0, 1.5]],
		[Vector2(1920, 1080), [1.25, 1.0, 1.5, 2.0]],
		[Vector2(2560, 1080), [1.25, 1.0, 1.5, 2.0]],
		[Vector2(2560, 1440), [1.75, 1.5, 2.0, 2.5]],
		[Vector2(3840, 2160), [2.5, 2.0, 3.0, 4.0]],
		[Vector2(800, 450), [800.0 / 960.0, 800.0 / 960.0, 800.0 / 960.0, 800.0 / 960.0]],
	]
	var opcoes := ["auto", "pequeno", "medio", "grande"]
	for caso in casos:
		var j: Vector2 = caso[0]
		for i in opcoes.size():
			var f := EscalaUi.fator(j, opcoes[i])
			ok(absf(f - float(caso[1][i])) < 0.0001, "fator %s %s = %.4f (esperado %.4f)" % [str(j), opcoes[i], f, float(caso[1][i])])
			var cv := EscalaUi.canvas(j, opcoes[i])
			ok(cv.x >= 960.0 and cv.y >= 540.0, "canvas %s %s não é menor que o bloco: %s" % [str(j), opcoes[i], str(cv)])
			ok(cv.x * f >= j.x - 0.01 and cv.y * f >= j.y - 0.01, "canvas %s %s cobre a janela inteira" % [str(j), opcoes[i]])
			ok(f <= minf(j.x / 960.0, j.y / 540.0) + 0.0001, "fator %s %s nunca corta o bloco" % [str(j), opcoes[i]])
			var gran := 4.0 if opcoes[i] == "auto" else 2.0
			var passo := f * gran
			ok(f < 1.0 or absf(passo - roundf(passo)) < 0.0001, "fator %s %s anda no passo certo (0,25 no automático, 0,5 nos fixos)" % [str(j), opcoes[i]])
	var cv := EscalaUi.canvas(Vector2(1920, 1080), "medio")
	ok(cv == Vector2(1280, 720), "1920x1080 médio = canvas 1280x720")
	ok(EscalaUi.deslocamento(cv) == Vector2(160, 90), "o bloco fica no centro do canvas")
	ok(EscalaUi.cobertura(cv, Vector2(160, 90)) == Rect2(-160, -90, 1280, 720), "a cobertura começa em -deslocamento")
	ok(EscalaUi.deslocamento(Vector2(960, 540)) == Vector2.ZERO, "canvas igual ao bloco: sem deslocamento")
	# a opção forçada (o salão usa "grande"): ignora o que está salvo e encaixa o bloco na janela
	Config.temporario("tamanho_ui", "pequeno")
	EscalaUi.janela_forcada = Vector2i(1920, 1080)
	ok(
		is_equal_approx(EscalaUi.atualizar(null, "grande"), 2.0) and EscalaUi.canvas_atual == Vector2(960, 540),
		"opção forçada grande: fator 2, canvas 960x540, mesmo com Pequeno salvo"
	)
	ok(is_equal_approx(EscalaUi.atualizar(null), 1.0) and EscalaUi.canvas_atual == Vector2(1920, 1080), "sem forçar, vale a opção salva (Pequeno)")
	Config.temporario("tamanho_ui", "auto")
	EscalaUi.atualizar(null)
	# a v1 não mostra a linha do tamanho da interface (não faria nada)
	var opc_v1 = load("res://scripts/hordas/tela_opcoes.gd").new()
	opc_v1._ready()
	var achou_v1 := false
	for it in opc_v1._itens:
		achou_v1 = achou_v1 or str(it.chave) == "tamanho_ui"
	ok(not achou_v1, "a tela de Opções da v1 não lista Tamanho da interface")
	opc_v1.free()
	# o automático fica entre o Pequeno e o Médio (o Alisson achou a UI encaixada grande demais) e nunca passa do encaixe do bloco
	for j in [Vector2(1280, 720), Vector2(1366, 768), Vector2(1600, 900), Vector2(1920, 1080), Vector2(2560, 1440), Vector2(3840, 2160)]:
		var fa := EscalaUi.fator(j, "auto")
		ok(fa >= EscalaUi.fator(j, "pequeno") - 0.0001, "automático %s >= Pequeno" % str(j))
		ok(fa <= EscalaUi.fator(j, "medio") + 0.0001, "automático %s <= Médio (%.2f x %.2f)" % [str(j), fa, EscalaUi.fator(j, "medio")])
		ok(fa <= minf(j.x / 960.0, j.y / 540.0) + 0.0001, "automático %s não passa do encaixe do bloco" % str(j))
	ok(is_equal_approx(EscalaUi.fator(Vector2(1920, 1080), "auto"), 1.25), "1920x1080 automático = 1,25 (cartas em cerca de metade da tela)")
	# DPI do sistema (Windows 125/150/175%): o Automático cresce junto; os fixos não; nunca passa do encaixe
	var tab_dpi := [[1.0, 1.25], [1.25, 1.5], [1.5, 2.0], [1.75, 2.0], [2.0, 2.0]]
	for t in tab_dpi:
		var fd := EscalaUi.fator(Vector2(1920, 1080), "auto", t[0])
		ok(is_equal_approx(fd, t[1]), "1920x1080 automático com DPI %d%% = %.2f (deu %.2f)" % [int(t[0] * 100), t[1], fd])
	ok(is_equal_approx(EscalaUi.fator(Vector2(2560, 1440), "auto", 1.25), 2.0), "2560x1440 automático a 125%% = 2")
	ok(is_equal_approx(EscalaUi.fator(Vector2(1366, 768), "auto", 1.5), 1.25), "1366x768 automático a 150%% = 1,25")
	for o in ["pequeno", "medio", "grande"]:
		ok(is_equal_approx(EscalaUi.fator(Vector2(1920, 1080), o, 1.5), EscalaUi.fator(Vector2(1920, 1080), o)), "%s ignora o DPI" % o)
	ok(is_equal_approx(EscalaUi.fator(Vector2(1920, 1080), "auto", 0.5), 1.25), "DPI abaixo de 100%% não encolhe a UI")
	ok(is_equal_approx(EscalaUi.escala_dpi(null), 1.0), "headless: DPI 1")
	EscalaUi.dpi_forcado = 1.5
	EscalaUi.janela_forcada = Vector2i(1920, 1080)
	ok(is_equal_approx(EscalaUi.atualizar(null, "auto"), 2.0) and EscalaUi.canvas_atual == Vector2(960, 540), "atualizar lê o DPI forçado (150%% em 1080p = 2)")
	EscalaUi.dpi_forcado = 0.0
	EscalaUi.janela_forcada = Vector2i.ZERO
	EscalaUi.atualizar(null)

	# a opção: salva em opções, gira por Ajustes > Gráficos e cai em auto com lixo
	ok(EscalaUi.opcao_atual() == "auto", "o padrão é Automático")
	var aj := AjustesGraficos.new()
	var linha := {}
	for it in aj.itens():
		if str(it.id) == "g:ui":
			linha = it
	ok(
		not linha.is_empty() and str(linha.rotulo) == "Tamanho da interface" and str(linha.valor) == "Automático",
		"Ajustes tem a linha Tamanho da interface: Automático"
	)
	aj.agir("ui", 1)
	ok(EscalaUi.opcao_atual() == "pequeno", "Enter/seta direita: Automático -> Pequeno")
	ok(Config.rotulo("tamanho_ui") == "Pequeno", "o rótulo acompanha: Pequeno")
	aj.agir("ui", 1)
	aj.agir("ui", 1)
	ok(EscalaUi.opcao_atual() == "grande", "Pequeno -> Médio -> Grande")
	aj.agir("ui", 1)
	ok(EscalaUi.opcao_atual() == "auto", "Grande -> Automático (dá a volta)")
	aj.agir("ui", -1)
	ok(EscalaUi.opcao_atual() == "grande", "seta esquerda volta")
	var recarregado := ConfigFile.new()
	recarregado.load(OPCOES_TESTE)
	ok(str(recarregado.get_value("opcoes", "tamanho_ui", "")) == "grande", "a escolha foi salva no arquivo de opções")
	Config.temporario("tamanho_ui", "lixo")
	ok(EscalaUi.opcao_atual() == "auto", "valor inválido vira Automático")
	Config.temporario("tamanho_ui", "auto")


func _mundo() -> void:
	Config.temporario("tamanho_ui", "medio")  # em 1920x1080: fator 1,5 e canvas 1280x720 (o Automático aqui encaixa o bloco, fator 2)
	EscalaUi.janela_forcada = Vector2i(1920, 1080)
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	await get_tree().process_frame
	var ap = w.ap
	ok(absf(ap.fator - 1.5) < 0.0001, "o mundo em 1920x1080 (Médio) usa fator 1,5 (%.3f)" % ap.fator)
	ok(ap.canvas == Vector2(1280, 720) and Vector2(ap.ui.size) == Vector2(1280, 720), "o SubViewport da UI tem o tamanho do canvas")
	ok(ap.desloc == Vector2(160, 90), "o bloco fica no centro do canvas")
	ok(absf(ap.tela_ui.size.x - 1920.0) < 0.5 and absf(ap.tela_ui.size.y - 1080.0) < 0.5, "a UI é mostrada na janela inteira (canvas x fator)")
	var camadas := 0
	for c in w.ui.get_children():
		if c is CanvasLayer:
			camadas += 1
			ok((c as CanvasLayer).offset == Vector2(160, 90), "a camada %s já nasce no centro do canvas" % c.name)
	ok(camadas >= 4, "HUD, minimapa, pausa e status moram na UI (%d camadas)" % camadas)
	# mouse: o centro da janela é o centro do bloco; o canto da janela é o canto do canvas
	ok(perto(ap.pos_ui(Vector2(960, 540)), Vector2(480, 270)), "o centro da janela é o centro do bloco")
	ok(perto(ap.pos_ui(Vector2.ZERO), Vector2(-160, -90)), "o canto da janela fica fora do bloco, no canvas")
	ok(perto(ap.pos_ui(Vector2(1920, 1080)), Vector2(1120, 630)), "o outro canto também")

	var hud = w.ui.get_node("Hud")
	var m = w.ui.get_node("Minimapa")
	var pausa: Node = null
	for c in w.ui.get_children():
		if c.has_method("abrir_sair"):
			pausa = c
	# HUD (estilo Overwatch): o retrato no canto de baixo à esquerda do canvas, o XP e o Q embaixo no centro, o E e o secundário embaixo à direita, o relógio em cima
	var retrato: Control = hud.get_node("Raiz/Retrato")
	ok(
		perto(hud.offset + retrato.position + Vector2(0, retrato.size.y), Vector2(6, 720 - 6)),
		"o retrato gruda no canto de baixo à esquerda do canvas: %s" % str(hud.offset + retrato.position)
	)
	var tempo: Control = hud.get_node("Raiz/Tempo")
	ok(perto(hud.offset + tempo.position, Vector2(428 + 160, 6)), "o relógio gruda no topo e fica no centro: %s" % str(hud.offset + tempo.position))
	var xp: Control = hud.get_node("Raiz/Xp")
	ok(perto(hud.offset + xp.position + Vector2(0, xp.size.y), Vector2(380 + 160, 720 - 6)), "a barra de XP gruda embaixo: %s" % str(hud.offset + xp.position))
	var hab: Control = hud.get_node("Raiz/Habilidades")
	ok(
		perto(hud.offset + hab.position + hab.size * hab.scale, Vector2(1280 - 6, 720 - 6)),
		"o E e o secundário colam no canto de baixo à direita do canvas: %s" % str(hud.offset + hab.position)
	)
	var ult: Control = hud.get_node("Raiz/Ultimate")
	ok(
		perto(hud.offset + ult.position + ult.size * ult.scale * 0.5, Vector2(640, 720 - 6 - xp.size.y - 4 - ult.size.y * ult.scale.y * 0.5)),
		"o círculo do Q fica no centro, logo acima do XP: %s" % str(hud.offset + ult.position)
	)
	var vinheta: Control = hud.get_node("Raiz/Vinheta")
	ok(Rect2(vinheta.position, vinheta.size) == Rect2(-160, -90, 1280, 720), "a vinheta cobre o canvas: %s" % str(Rect2(vinheta.position, vinheta.size)))
	var mini_dir: float = m.offset.x + m._quadro.position.x + m._quadro.size.x
	ok(absf(mini_dir - (1280.0 - float(m.MARGEM_TELA))) < 0.5, "o minimapa gruda no canto de cima à direita do canvas (borda direita %.1f)" % mini_dir)
	ok(absf(m.offset.y + m._quadro.position.y - float(m.MARGEM_TELA)) < 0.5, "o minimapa fica na margem do topo do canvas")
	# fundos que cobrem o canvas inteiro
	var fundo: ColorRect = w.combate.telas._fundo
	ok(Rect2(fundo.position, fundo.size) == Rect2(-160, -90, 1280, 720), "o fundo das cartas cobre o canvas")
	ok(pausa != null, "a pausa mora na UI")
	if pausa != null:
		var f2: ColorRect = pausa._raiz.get_child(0)
		ok(Rect2(f2.position, f2.size) == Rect2(-160, -90, 1280, 720), "o escurecedor da pausa cobre o canvas")
		ok(pausa._fps.position == Vector2(6 - 160, 540 + 90 - 16), "o contador de fps fica no canto de baixo do canvas")
		ok(pausa.mouse_fn.is_valid(), "a pausa lê o mouse pelo bloco da UI (mouse_ui)")

	# troca da opção ao vivo: Grande em 1920x1080 = fator 2, canvas 960x540, tudo de volta ao bloco
	Config.temporario("tamanho_ui", "grande")
	Config.tamanho_ui_mudou.emit()
	ok(absf(ap.fator - 2.0) < 0.0001 and ap.canvas == Vector2(960, 540) and ap.desloc == Vector2.ZERO, "Grande em 1920x1080: fator 2, canvas 960x540")
	ok(hud.offset == Vector2.ZERO and perto(retrato.position, Vector2(6, 426)) and perto(xp.position, Vector2(380, 512)), "o HUD volta às posições do bloco")
	ok(Rect2(fundo.position, fundo.size) == Rect2(0, 0, 960, 540), "o fundo das cartas volta a 960x540")
	ok(m.offset.x + m._quadro.position.x + m._quadro.size.x <= 960.0, "o minimapa volta para o canto do bloco")
	Config.temporario("tamanho_ui", "pequeno")
	Config.tamanho_ui_mudou.emit()
	ok(absf(ap.fator - 1.0) < 0.0001 and ap.canvas == Vector2(1920, 1080), "Pequeno em 1920x1080: fator 1, canvas 1920x1080")
	ok(
		perto(hud.offset + retrato.position + Vector2(0, retrato.size.y), Vector2(6, 1080 - 6)) and ap.desloc == Vector2(480, 270),
		"Pequeno: o retrato continua no canto de baixo do canvas"
	)

	# a janela muda de tamanho (size_changed): refaz tudo
	Config.temporario("tamanho_ui", "medio")
	EscalaUi.janela_forcada = Vector2i(2560, 1440)
	ap.recalcular()
	ok(absf(ap.fator - 2.0) < 0.0001 and ap.canvas == Vector2(1280, 720), "2560x1440 Médio: fator 2, canvas 1280x720")
	Config.temporario("tamanho_ui", "auto")
	ap.recalcular()
	ok(absf(ap.fator - 1.75) < 0.0001 and ap.canvas == Vector2(1463, 823), "2560x1440 Automático: fator 1,75, canvas 1463x823")
	EscalaUi.janela_forcada = Vector2i(800, 450)
	ap.recalcular()
	ok(ap.canvas == Vector2(960, 540) and ap.fator < 1.0, "janela menor que o bloco: o bloco inteiro cabe (fator %.3f)" % ap.fator)
	ok(perto(ap.pos_ui(Vector2(400, 225)), Vector2(480, 270)), "janela pequena: o centro continua no centro do bloco")
	w.queue_free()
	await get_tree().process_frame
