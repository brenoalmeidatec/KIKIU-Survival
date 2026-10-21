extends Node
# Teste dos glifos de controle da v2 (v2/glifos.gd): o último dispositivo usado (teclado e mouse, Xbox ou PlayStation) decide o botão de cada
# ação e a troca é na hora (avisa quem ouviu); o nome do controle cai no Xbox ou no PlayStation; cada ação existe nos três; a dica desenhada
# se refaz na troca; o título esconde o "Mouse também" no controle.
# Fotos: godot --path jogos/hordas/projeto res://testes/v2_glifos.tscn -- --fotos=PASTA  (a folha de glifos de cada dispositivo, ampliada 3x; grava e sai)
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_glifos.tscn  (imprime "v2_glifos falhas=0")
const Glifos := preload("res://v2/glifos.gd")
const Titulo := preload("res://v2/menu_principal.tscn")

var falhas := 0
var avisos := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			await _fotos(a.trim_prefix("--fotos="))
			get_tree().quit()
			return
	Glifos.forcado = false
	Glifos.definir(Glifos.Disp.TECLADO)
	Glifos.ao_mudar(func() -> void: avisos += 1)
	_nomes()
	_troca()
	_cartas()
	_mouse_e_teclas()
	_dica_e_titulo()
	Glifos.definir(Glifos.Disp.TECLADO)
	Glifos._ouvintes.clear()  # o ouvinte da linha 22 captura este nó: tirá-lo antes de sair evita o segfault (exit 139) no encerramento
	print("v2_glifos falhas=%d" % falhas)
	get_tree().quit()


func _nomes() -> void:
	ok(Glifos.tipo_pelo_nome("Xbox 360 Controller") == Glifos.Disp.XBOX, "Xbox 360 vira Xbox")
	ok(Glifos.tipo_pelo_nome("XInput Gamepad") == Glifos.Disp.XBOX, "XInput vira Xbox")
	ok(Glifos.tipo_pelo_nome("PS5 Controller") == Glifos.Disp.PS, "PS5 vira PlayStation")
	ok(Glifos.tipo_pelo_nome("DualSense Wireless Controller") == Glifos.Disp.PS, "DualSense vira PlayStation")
	ok(Glifos.tipo_pelo_nome("Wireless Controller") == Glifos.Disp.PS, "Wireless Controller (DualShock 4 no Windows) vira PlayStation")
	ok(Glifos.tipo_pelo_nome("Controle qualquer") == Glifos.Disp.XBOX, "controle desconhecido usa o layout do Xbox")
	for a in Glifos.TABELA:
		for d in 3:
			if a == "mouse" and d != Glifos.Disp.TECLADO:
				continue  # o mouse só existe no teclado: a dica "mouse também" some sozinha no controle
			ok(not (Glifos.TABELA[a][d] as Array).is_empty(), "%s tem botão no dispositivo %d" % [a, d])


func _troca() -> void:
	ok(Glifos.texto("voltar") == "Esc", "teclado: voltar é Esc (%s)" % Glifos.texto("voltar"))
	ok(not Glifos.eh_controle(), "começa no teclado")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_A
	b.pressed = true
	Glifos.observar(b)  # device 0: sem controle ligado cai no Xbox
	ok(Glifos.eh_controle(), "apertar botão do controle troca para o controle")
	ok(avisos == 1, "a troca avisou uma vez (%d)" % avisos)
	ok(Glifos.texto("voltar") == "B", "Xbox: voltar é B (%s)" % Glifos.texto("voltar"))
	Glifos.observar(b)
	ok(avisos == 1, "repetir o mesmo dispositivo não avisa de novo")
	Glifos.definir(Glifos.Disp.PS)
	ok(Glifos.descritor("voltar")[0][0] == Glifos.PS and Glifos.descritor("voltar")[0][1] == "o", "PlayStation: voltar é a bola")
	ok(Glifos.descritor("confirmar")[0][1] == "x", "PlayStation: confirmar é a cruz")
	var m := InputEventJoypadMotion.new()
	m.axis_value = 0.2
	Glifos.definir(Glifos.Disp.TECLADO)
	Glifos.observar(m)
	ok(not Glifos.eh_controle(), "deriva do analógico não troca")
	m.axis_value = 0.9
	Glifos.observar(m)
	ok(Glifos.eh_controle(), "analógico firme troca para o controle")
	var k := InputEventKey.new()
	k.pressed = true
	Glifos.observar(k)
	ok(not Glifos.eh_controle(), "tecla volta ao teclado")
	Glifos.definir(Glifos.Disp.XBOX)
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(1, 0)
	Glifos.observar(mm)
	ok(Glifos.eh_controle(), "mouse tremendo (1 px) não troca")
	mm.relative = Vector2(10, 0)
	Glifos.observar(mm)
	ok(not Glifos.eh_controle(), "mover o mouse troca para teclado e mouse")
	Glifos.forcado = true
	Glifos.definir(Glifos.Disp.PS)
	Glifos.observar(k)
	ok(Glifos.eh_controle(), "com o dispositivo travado a detecção para")
	Glifos.forcado = false


func _cartas() -> void:
	var esperado := [["R", "Q", "B"], ["X", "Y", "LB"], ["Quad.", "Tri.", "L1"]]
	for d in 3:
		Glifos.definir(d)
		var acoes := ["rerrolar", "automatico", "banir"]
		for i in acoes.size():
			ok(Glifos.texto(acoes[i]) == esperado[d][i], "carta: %s usa %s no dispositivo %d" % [acoes[i], esperado[d][i], d])


## #374: o botão do mouse é um ícone de mouse pixel a pixel (esquerdo, direito, do meio), não o texto "Mouse D"; as teclas são teclinhas com a letra; Xbox e PS seguem.
func _mouse_e_teclas() -> void:
	Glifos.definir(Glifos.Disp.TECLADO)
	var sec := Glifos.descritor("secundario")
	ok(sec[0][0] == Glifos.MOUSE and sec[0][1] == "d", "teclado: o secundário é o ícone do mouse com o botão direito (%s)" % str(sec))
	ok(Glifos.descritor("clique")[0] == [Glifos.MOUSE, "e"], "teclado: o clique é o mouse com o botão esquerdo")
	ok(Glifos.largura(sec[0]) == 12.0, "o mouse tem 12 px de largura (%s)" % Glifos.largura(sec[0]))
	for t in [["Esc", "voltar"], ["Espaço", "esquiva"], ["Shift", "correr"], ["Tab", "detalhes"], ["E", "habilidade"], ["Q", "ultimate"]]:
		var dd := Glifos.descritor(t[1])
		ok(dd[0][0] == Glifos.TECLA and dd[0][1] == t[0], "teclado: %s é a teclinha '%s' (%s)" % [t[1], t[0], str(dd)])
	# os pixels: cada botão aceso só pinta a sua metade, e o resto do mouse é igual
	for altura in [Glifos.ALTURA, Glifos.ALTURA_MINI]:
		var ref := Glifos.pixels_mouse("", altura)
		ok(ref.size() > 40, "o mouse de %s px tem pixels (%d)" % [altura, ref.size()])
		var acesos := {}
		for q in ["e", "d", "m", ""]:
			var cel := []
			for px in Glifos.pixels_mouse(q, altura):
				if px[1] == "A":
					cel.append(px[0])
			acesos[q] = cel
		ok(acesos[""].is_empty(), "sem botão aceso nada é pintado de ouro (altura %s)" % altura)
		for q in ["e", "d", "m"]:
			ok(not acesos[q].is_empty(), "o botão '%s' aceso pinta pixels (altura %s)" % [q, altura])
		var larg := 0
		for px in ref:
			larg = maxi(larg, px[0].x + 1)
		var meio := float(larg) * 0.5
		ok(acesos["e"].all(func(c): return c.x < meio), "o botão esquerdo fica na metade esquerda (altura %s)" % altura)
		ok(acesos["d"].all(func(c): return c.x >= meio), "o botão direito fica na metade direita (altura %s)" % altura)
		ok(acesos["m"].all(func(c): return absf(float(c.x) + 0.5 - meio) <= 1.5), "a roda fica no meio (altura %s)" % altura)
		ok(acesos["e"].size() == acesos["d"].size(), "os dois botões têm o mesmo tamanho (altura %s)" % altura)
		for q in ["e", "d", "m"]:
			ok(Glifos.pixels_mouse(q, altura).size() == ref.size(), "o botão aceso não muda a silhueta (altura %s)" % altura)
	ok(Glifos.largura_mini(sec[0]) == 7.0, "o mouse mini tem 7 px de largura (mais alto que largo: 10 px)")
	ok(Glifos.MOUSE_MINI.size() > Glifos.MOUSE_MINI[0].length(), "o mouse mini é mais alto que largo")
	var cupula: String = Glifos.MOUSE_MINI[0]
	ok(cupula.strip_edges().length() < Glifos.MOUSE_MINI[4].strip_edges().length(), "o mini tem cúpula: a linha de cima é mais estreita que a da costura")
	ok(Glifos.texto("secundario") == "Mouse D", "o texto do mouse (para quem só lê texto) segue 'Mouse D'")
	Glifos.definir(Glifos.Disp.XBOX)
	ok(Glifos.descritor("secundario")[0] == [Glifos.TECLA, "LT"], "Xbox: o secundário continua o gatilho LT")
	ok(Glifos.descritor("clique")[0] == [Glifos.TECLA, "RT"], "Xbox: o clique é o gatilho RT")
	ok(Glifos.descritor("mouse").is_empty(), "Xbox: não há mouse")
	Glifos.definir(Glifos.Disp.PS)
	ok(Glifos.descritor("secundario")[0] == [Glifos.TECLA, "L2"], "PS: o secundário continua o gatilho L2")
	ok(Glifos.descritor("confirmar")[0] == [Glifos.PS, "x"], "PS: confirmar segue a cruz")
	Glifos.definir(Glifos.Disp.TECLADO)


func _dica_e_titulo() -> void:
	Glifos.definir(Glifos.Disp.TECLADO)
	var d := Glifos.dica(func() -> Array: return [["voltar", "Voltar"]])
	add_child(d)
	var w_teclado := d.get_minimum_size().x
	Glifos.definir(Glifos.Disp.XBOX)
	ok(d.get_minimum_size().x < w_teclado, "a dica se refaz na troca (%f -> %f)" % [w_teclado, d.get_minimum_size().x])
	d.queue_free()
	var titulo = Titulo.instantiate()
	Glifos.definir(Glifos.Disp.TECLADO)
	ok(titulo._itens_dica().size() == 4, "teclado: título mostra 'Mouse também'")
	Glifos.definir(Glifos.Disp.PS)
	ok(titulo._itens_dica().size() == 3, "controle: título não mostra o mouse")
	titulo.free()


class Folha:
	extends Control
	const ACOES := [
		"confirmar", "voltar", "pausa", "detalhes", "habilidade", "ultimate", "secundario", "clique", "mouse", "esquiva", "correr", "navegar", "andar", "abas"
	]

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#14121c"))
		var f: Font = Dados.fonte_texto
		for d in 3:
			Glifos.definir(d)
			var y := 8.0 + 30.0 * d
			draw_string(f, Vector2(4, y + 12), ["TECLADO", "XBOX", "PS"][d], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#8c87ad"))
			var x := 58.0
			for a in ACOES:
				if Glifos.descritor(a).is_empty():
					continue
				draw_string(f, Vector2(x, y + 2), a, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#8c87ad"))
				var wl := f.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
				x += maxf(Glifos.desenhar_acao(self, a, Vector2(x, y + 5)), wl) + 10.0
				if x > size.x - 40.0:
					break
		Glifos.definir(Glifos.Disp.TECLADO)
		# o mini (selo do HUD) em cada botão aceso, ao lado
		var xm := 58.0
		for q in ["e", "d", "m", ""]:
			xm += Glifos.desenhar_mouse(self, q, Vector2(xm, 96), Glifos.ALTURA_MINI) + 6.0
		for q in ["e", "d", "m", ""]:
			xm += Glifos.desenhar_mouse(self, q, Vector2(xm, 92), Glifos.ALTURA) + 6.0


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	Glifos.forcado = false
	var folha := Folha.new()
	folha.size = Vector2(640, 118)
	folha.scale = Vector2(1, 1)
	var cam := CanvasLayer.new()
	add_child(cam)
	cam.add_child(folha)
	for i in 4:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, 640, 118))
	img.resize(1920, 354, Image.INTERPOLATE_NEAREST)  # 3x sem borrar: a folha é pixel art de 1x
	img.save_png(pasta.path_join("glifos_folha_3x.png"))
	print("FOTO glifos_folha_3x ", img.get_size())
	# o título com a dica de rodapé de cada dispositivo (teclado e mouse: ícone do mouse; Xbox e PS: sem mouse)
	folha.queue_free()
	var titulo = Titulo.instantiate()
	add_child(titulo)
	await get_tree().create_timer(3.0).timeout  # a entrada do título faz fade
	for d in 3:
		Glifos.definir(d)
		await get_tree().create_timer(0.3).timeout
		var tela := get_viewport().get_texture().get_image()
		tela.save_png(pasta.path_join("titulo_%s.png" % Glifos.NOMES[d]))
		print("FOTO titulo_%s " % Glifos.NOMES[d], tela.get_size())
	Glifos.definir(Glifos.Disp.TECLADO)
