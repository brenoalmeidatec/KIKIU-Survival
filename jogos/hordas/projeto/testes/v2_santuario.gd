extends "res://testes/isolamento_v2.gd"
## Navegação real do frontend e legibilidade do santuário em 960x540. Save/opções isolados.
const Meta := preload("res://v2/meta.gd")
const Altar := preload("res://v2/altar.tscn")
## Altura de UMA linha de texto em janela: a fonte Spleen 8x16 mede 16 px. Em --headless get_line_height devolve 32 (o dobro) e o
## size de um Label é forçado ao mínimo, então NENHUM dos dois serve de régua: a régua é esta constante de projeto mais a
## entrelinha do tema, contra as medidas de projeto (posições e tamanhos dos nós) da caixa.
const ALTURA_FONTE := 16
const TELA := Rect2(0, 0, 960, 540)
const SAVE := "user://testes_v2/v2_santuario/teste_v2_santuario.cfg"
const OPCOES := "user://testes_v2/v2_santuario/teste_v2_santuario_opcoes.cfg"
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Meta.caminho_save = SAVE
	Config.arquivo = OPCOES
	_limpar()
	# Driver persistente: change_scene troca a cena de verdade, sem destruir o teste.
	get_tree().current_scene = null
	Engine.set_meta("kikiu_entrada", true)
	for acao in ["escape", "start", "cancelar", "botao", "mouse"]:
		get_tree().change_scene_to_packed(Altar)
		await _frames(3)
		var a = get_tree().current_scene
		ok(a.scene_file_path == "res://v2/altar.tscn", "abre santuário real")
		a._ajustes.pressed.emit()
		ok(a.pausa.aberto and a.pausa.tela == "ajustes", "Ajustes abre no santuário")
		_tecla(KEY_ENTER)  # Gráficos
		ok(a.pausa.tela == "graficos", "Ajustes entra em Gráficos")
		_tecla(KEY_ESCAPE)
		ok(a.pausa.tela == "ajustes", "ESC em Gráficos volta um nível")
		_tecla(KEY_ESCAPE)
		await _frames(1)
		ok(not a.pausa.aberto and get_tree().current_scene == a, "ESC em Ajustes permanece no santuário")
		ok(get_viewport().gui_get_focus_owner() == a._ajustes, "Ajustes devolve foco")
		await _ver_caixa_detalhe(a)
		await _ver_conquistas(a)
		_ver_visual(a)
		if acao == "escape":
			_tecla(KEY_ESCAPE)
		elif acao in ["start", "cancelar"]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = JOY_BUTTON_START if acao == "start" else JOY_BUTTON_B
			ev.pressed = true
			Input.parse_input_event(ev)
			Input.flush_buffered_events()
		elif acao == "mouse":
			for pressionado in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.position = get_viewport().get_final_transform() * a._voltar.get_global_rect().get_center()
				ev.global_position = ev.position
				ev.pressed = pressionado
				Input.parse_input_event(ev)
				Input.flush_buffered_events()
		else:
			a._voltar.grab_focus()
			_tecla(KEY_ENTER)
		await _frames(3)
		ok(get_tree().current_scene.scene_file_path == "res://v2/menu_principal.tscn", "%s volta ao título" % acao)
		await _assentar()
	# O título continua pedindo Sair por ESC; o processo permanece vivo.
	_tecla(KEY_ESCAPE)
	await _frames(1)
	var titulo = get_tree().current_scene
	ok(titulo.pausa.aberto and titulo.pausa.tela == "confirmar_sair", "ESC só pede Sair no título")
	_tecla(KEY_ESCAPE)
	ok(not titulo.pausa.aberto, "ESC cancela Sair no título")
	_limpar()
	print("v2_santuario falhas=%d" % falhas)
	get_tree().quit(falhas)


func _ver_visual(a) -> void:
	for nome in ["FLORESTA", "LABORATÓRIO", "RUÍNAS DA FLORESTA", "CIDADE"]:
		var largura: float = (
			a._mapa.get_theme_font("font").get_string_size("< %s >" % nome, HORIZONTAL_ALIGNMENT_LEFT, -1, a._mapa.get_theme_font_size("font_size")).x
		)
		ok(largura + 8 <= a._mapa.size.x, "nome completo %s cabe no botão" % nome)
	ok(a._mapa.position.x + a._mapa.size.x <= a._entrar.position.x, "MAPA não invade ENTRAR")
	for id in a._linhas:
		var linha: Dictionary = a._linhas[id]
		var selecionar: Button = linha.selecionar
		ok(not selecionar.disabled and selecionar.focus_mode == Control.FOCUS_ALL, "cartão %s sempre selecionável" % id)
		selecionar.grab_focus()
		ok(a._detalhe.text.begins_with(str(Meta.melhoria(id).nome)), "foco mostra detalhe de %s" % id)
		for chave in ["nome", "efeito"]:
			var l: Label = linha[chave]
			var largura: float = l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
			ok(largura <= l.size.x, "texto %s/%s cabe no cartão" % [id, chave])
		for chave in ["nome", "efeito", "botao", "cadeado", "progresso", "selecionar"]:
			var c: Control = linha[chave]
			ok(c.position.x >= 36 and c.position.x + c.size.x <= 608, "cartão %s/%s cabe na coluna" % [id, chave])
		ok(a._detalhe.get_minimum_size().y <= a._detalhe.size.y, "detalhe %s cabe" % id)
	a._linhas["treino"].selecionar.grab_focus()
	ok(a._detalhe.text.contains("Sobreviva 5 minutos"), "bloqueado explica requisito ao teclado")
	for id in a._conq:
		a._conq[id].selecionar.grab_focus()
		ok(a._detalhe.text.contains(str(Meta.conquistas().filter(func(c): return str(c.id) == id)[0].desc)), "conquista %s tem detalhe por foco" % id)
		ok(a._detalhe.get_minimum_size().y <= a._detalhe.size.y, "detalhe conquista %s cabe" % id)
	a._conq["combo_50"].selecionar.grab_focus()  # a última do laço é uma conquista de progresso (vence_medio), sem recompensa
	ok(
		a._detalhe.text.contains("Libera: Rastro de katana") and not a._detalhe.text.contains("sem efeito"),
		"a recompensa do rastro aparece no detalhe, sem aviso de efeito pendente"
	)
	ok(a._conq["sobreviva_5min"].barra.value == 0, "sem partida a barra começa vazia")
	Meta.registrar_partida({"tempo": 150, "maior_combo": 25})
	a._atualizar()
	ok(a._conq["sobreviva_5min"].barra.value == 50 and a._conq["combo_50"].barra.value == 50, "barras medem última partida")
	Meta.creditar(10000)
	for i in int(Meta.melhoria("vida").max):
		Meta.comprar("vida")
	a._atualizar()
	var vida: Dictionary = a._linhas["vida"]
	ok(vida.botao.disabled and not vida.selecionar.disabled, "máximo ainda permite selecionar detalhe")
	vida.selecionar.grab_focus()
	ok(a._detalhe.text.contains("nível máximo"), "máximo explica estado por foco")
	ok(vida.progresso.nivel == vida.progresso.maximo, "nível máximo preenche todos marcadores")
	ok(a._detalhe.get_minimum_size().y <= a._detalhe.size.y, "detalhe máximo cabe")
	_limpar()


## A caixa de detalhe tem que comportar o MAIOR detalhe do santuário (melhorias, conquistas, modos e visuais, com os
## placeholders preenchidos) e nada pode se sobrepor nem sair dos 960x540.
func _ver_caixa_detalhe(a) -> void:
	var caixa: Panel = null
	for no in a.get_children():
		if no is Panel and Rect2(no.position, no.size).has_point(a._detalhe.position):
			caixa = no
	ok(caixa != null, "o detalhe está dentro de um painel")
	if caixa == null:
		return
	var folga: float = a._detalhe.position.y - caixa.position.y
	var util: float = caixa.size.y - 2.0 * folga  # a mesma folga em cima e embaixo
	var linha: int = ALTURA_FONTE + a._detalhe.get_theme_constant("line_spacing")
	var pior := 0
	var textos: Dictionary = {}
	for id in a._linhas:
		a._linhas[id].selecionar.grab_focus()
		textos["melhoria " + id] = a._detalhe.text
	for id in a._conq:
		a._conq[id].selecionar.grab_focus()
		textos["conquista " + id] = a._detalhe.text
	for par in [["modo", "pesadelo"], ["visual", "rastro_katana"]]:
		a._detalhar_extra(par[0], par[1])
		textos["extra " + par[1]] = a._detalhe.text
	for chave in textos:
		a._detalhe.text = textos[chave]
		var n: int = a._detalhe.get_line_count()
		pior = maxi(pior, n)
		ok(n * linha <= util, "detalhe '%s' (%d linhas x %d px = %d) cabe na caixa de %d px úteis" % [chave, n, linha, n * linha, util])
	print("v2_santuario: pior detalhe = %d linhas, %d px; caixa útil = %d px" % [pior, pior * linha, util])
	ok(pior >= 5, "o pior caso medido inclui o Pesadelo (5 linhas)")
	# Nada se sobrepõe: grade -> caixa -> rótulo MAPA/status -> botões, e tudo dentro da tela mínima.
	var fim_grade := 0.0
	for id in a._linhas:
		var b: Control = a._linhas[id].botao
		fim_grade = maxf(fim_grade, b.position.y + b.size.y)
	ok(caixa.position.y >= fim_grade, "a caixa começa depois da grade")
	var rotulo: Label = null
	for no in a.get_children():
		if no is Label and no.text == "MAPA":
			rotulo = no
	ok(rotulo != null and caixa.position.y + caixa.size.y <= rotulo.position.y, "a caixa termina acima do rótulo MAPA")
	ok(caixa.position.y + caixa.size.y <= a._status.position.y, "a caixa termina acima do status")
	for b in [a._modo_btn, a._rastro_btn]:
		var r := Rect2(b.position, b.size)
		ok(r.position.y >= caixa.position.y and r.end.y <= caixa.position.y + caixa.size.y, "botão de extra dentro da faixa da caixa")
		ok(r.position.x >= caixa.position.x + caixa.size.x, "botão de extra não invade a caixa")
	ok(a._modo_btn.position.y + a._modo_btn.size.y <= a._rastro_btn.position.y, "os dois botões de extra não se sobrepõem")
	var fixos: Array = [caixa, a._detalhe, a._modo_btn, a._rastro_btn, rotulo, a._status, a._mapa, a._entrar, a._ajustes, a._voltar]
	for c in fixos:
		ok(TELA.encloses(Rect2(c.position, c.size)), "%s dentro dos 960x540" % c.name)
	for c in [rotulo, a._status]:
		for d in [a._mapa, a._entrar, a._ajustes, a._voltar]:
			ok(not Rect2(c.position, c.size).intersects(Rect2(d.position, d.size)), "rótulo/status não toca os botões de baixo")


## Retângulo de um nó em coordenadas do canvas, recortado pelos ScrollContainer que o contêm (o que realmente aparece).
func _visivel(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			r = r.intersection(p.get_global_rect())
		p = p.get_parent()
	return r


## #457: ~26 conquistas não cabem nos 340 px livres da coluna. Nenhuma parte visível pode cruzar ENTRAR, MAPA, AJUSTES, VOLTAR, o
## status e o rodapé; o ENTRAR não invade a coluna; a rolagem (roda e foco) alcança a última; os títulos não tocam a "Última partida".
## Medido por geometria de projeto (posição e tamanho dos nós), nunca pelo tamanho da fonte (em --headless ela mede o dobro).
func _ver_conquistas(a) -> void:
	await _frames(3)  # o contêiner de rolagem dimensiona o conteúdo no primeiro layout
	var ids: Array = a._conq.keys()
	ok(ids.size() >= 20, "o teste cobre a lista cheia de conquistas (%d)" % ids.size())
	var botoes: Array = [a._entrar, a._mapa, a._ajustes, a._voltar]
	var proibidos: Array = []
	for b in botoes:
		proibidos.append(Rect2(a.get_global_transform() * b.position, b.size))
	proibidos.append(Rect2(a.get_global_transform() * a._status.position, a._status.size))
	proibidos.append(Rect2(a.get_global_transform() * Vector2(0, 508), Vector2(960, 32)))  # rodapé de teclas (y 510 a 532)
	var cruza := 0
	var topo_col := 1.0e9
	for id in ids:
		var v := _visivel(a._conq[id].selecionar)
		if v.size.x <= 0.0 or v.size.y <= 0.0:
			continue
		topo_col = minf(topo_col, v.position.y)
		for r in proibidos:
			if v.intersects(r):
				cruza += 1
	ok(cruza == 0, "nenhuma conquista visível cruza botão, status ou rodapé (%d cruzamentos)" % cruza)
	var x_col: float = a.get_global_transform().origin.x + 632.0
	ok(a._entrar.position.x + a._entrar.size.x <= 632.0, "ENTRAR termina antes da coluna CONQUISTAS (x 632)")
	var x_item_min := 1.0e9
	for id in ids:
		x_item_min = minf(x_item_min, a._conq[id].selecionar.get_global_rect().position.x)
	ok(x_item_min >= x_col, "as conquistas começam na coluna (x 632)")
	# Rolagem: a roda do mouse anda a lista e o foco leva até a última conquista, sempre inteira dentro da área livre.
	var rol = a.get("_rolagem")
	ok(rol != null, "a lista de conquistas tem área de rolagem")
	if rol != null:
		ok(rol.get_global_rect().end.y <= a._status.get_global_rect().position.y + 0.5, "a área da lista termina acima do MAPA/status")
		rol.scroll_vertical = 0
		var antes: int = rol.scroll_vertical
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		ev.position = get_viewport().get_final_transform() * rol.get_global_rect().get_center()
		ev.global_position = ev.position
		get_viewport().push_input(ev)
		var solta := ev.duplicate()  # a roda precisa do "soltar", senão o viewport segura o mouse na lista e o clique do VOLTAR não chega
		solta.pressed = false
		get_viewport().push_input(solta)  # direto no viewport: não mexe no estado do mouse do Input (o clique no VOLTAR vem depois)
		await _frames(2)
		var mov := InputEventMouseMotion.new()  # tira o mouse de cima da lista (o hover ficaria preso nela e o clique do VOLTAR iria para lá)
		mov.position = get_viewport().get_final_transform() * a._voltar.get_global_rect().get_center()
		mov.global_position = mov.position
		get_viewport().push_input(mov)
		await _frames(1)
		ok(rol.scroll_vertical > antes, "a roda do mouse rola a lista de conquistas")
		rol.scroll_vertical = 0
	var ultima_id: String = ids[ids.size() - 1]
	a._entrar.grab_focus()  # a última pode já ter o foco (pelos testes anteriores): sem trocar, grab_focus não rola nada
	await _frames(1)
	a._conq[ultima_id].selecionar.grab_focus()
	await _frames(3)
	var ult := a._conq[ultima_id].selecionar as Control
	var area: Rect2 = rol.get_global_rect() if rol != null else TELA
	ok(area.encloses(ult.get_global_rect()), "o foco leva a última conquista (%s) inteira para a área visível" % ultima_id)
	ok(not _visivel(ult).intersects(proibidos[0]) and not _visivel(ult).intersects(proibidos[3]), "a última conquista não cruza ENTRAR/VOLTAR")
	# Foco de teclado: cada conquista, uma a uma, fica visível ao receber o foco.
	var fora := 0
	for id in ids:
		a._conq[id].selecionar.grab_focus()
		await _frames(2)
		if not area.encloses(a._conq[id].selecionar.get_global_rect()):
			fora += 1
	ok(fora == 0, "toda conquista fica visível ao receber o foco (%d fora)" % fora)
	# Títulos MELHORIAS/CONQUISTAS não tocam a linha "Última partida" (caixas de texto dos rótulos).
	var tocam := 0
	for no in a.get_children():
		if no is Label and no.text in ["MELHORIAS", "CONQUISTAS"]:
			if Rect2(no.position, no.size).intersects(Rect2(a._ultima.position, a._ultima.size)):
				tocam += 1
	ok(tocam == 0, "os títulos MELHORIAS/CONQUISTAS não tocam a linha 'Última partida'")


func _tecla(tecla: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = tecla
	ev.physical_keycode = tecla
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	ev = InputEventKey.new()
	ev.keycode = tecla
	ev.physical_keycode = tecla
	ev.pressed = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _limpar() -> void:
	for caminho in [SAVE, SAVE + ".bak", SAVE + ".tmp", OPCOES, OPCOES + ".bak", OPCOES + ".tmp"]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))


## Espera o fim do fade da troca de cena (#377): enquanto a foto da tela antiga está na tela a entrada da janela é descartada.
func _assentar() -> void:
	var t0 := Time.get_ticks_msec()
	while Transicoes.ativa() and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
