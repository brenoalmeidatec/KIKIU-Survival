extends Node
# Teste automático da tela de título da v2 (v2/menu_principal.gd): a cena principal abre com Jogar, Ajustes, Créditos e Sair; o foco
# começa em Jogar e anda com as setas, o D-pad e o mouse (passar o cursor põe o foco); Jogar leva ao santuário (gancho ao_jogar, e a
# cena existe); Ajustes abre o submenu da pausa (Gráficos e Áudio) e fechar devolve o foco; Créditos abre a tela de Créditos e o
# Voltar (ou ESC) fecha direto, sem passar por Ajustes; ESC e Start pedem "Sair?" com "Não" marcado (o gancho ao_sair não é
# chamado), e só o "Sim" sai; a música do título é a do santuário (faixa "menu"). O gancho ao_sair e o ao_jogar são dos testes:
# o processo não fecha nem troca de cena.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_menu.tscn  (imprime "v2_menu falhas=0")
# Prints (com janela): godot --path jogos/hordas/projeto res://testes/v2_menu.tscn -- --fotos=PASTA
#   grava menu_principal, menu_ajustes, menu_creditos e menu_sair (só o viewport).
const Menu := preload("res://v2/menu_principal.gd")
const Titulo := preload("res://v2/menu_principal.tscn")
const OPCOES_TESTE := "user://teste_v2_menu_opcoes.cfg"

var falhas := 0
var saiu := 0  # o gancho ao_sair da pausa conta aqui
var jogou := 0  # o gancho ao_jogar do título conta aqui


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Config.arquivo = OPCOES_TESTE  # o Áudio e os Gráficos do título gravam aqui, nunca no opcoes.cfg do jogador
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
	else:
		await _testes()
	_limpar()
	print("v2_menu falhas=%d" % falhas)
	get_tree().quit()


func _limpar() -> void:
	get_tree().paused = false
	if FileAccess.file_exists(OPCOES_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OPCOES_TESTE))
	Config.arquivo = "user://opcoes.cfg"


# ------------------------------------------------------------------ entrada (pela janela, como o jogador)


## Toda a entrada entra pelo caminho da janela (Input.parse_input_event), o mesmo do teclado, do controle e do mouse de verdade.
func _enviar(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## Aperto e soltura da tecla.
func _tecla(k: Key) -> void:
	for pressionado in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionado
		_enviar(e)


func _pad(botao: JoyButton) -> void:
	for pressionado in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = botao
		e.pressed = pressionado
		_enviar(e)


## O cursor passa sobre o ponto, dado no canvas de 960x540 (como o pausa.gd). A janela recebe pixels da tela: o canvas vira
## pixels pela transformação final da viewport (em headless ela é de 64x64, e em janela de 1280x720 é 1,33x).
func _mouse_sobre(pos: Vector2) -> void:
	var tela := get_viewport().get_final_transform() * pos
	var e := InputEventMouseMotion.new()
	e.position = tela
	e.global_position = tela
	_enviar(e)


## Clique completo: passa o cursor, aperta e solta no mesmo ponto (a ação do botão é na soltura).
func _clique(pos: Vector2) -> void:
	_mouse_sobre(pos)
	var tela := get_viewport().get_final_transform() * pos
	for pressionado in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressionado
		e.position = tela
		e.global_position = tela
		_enviar(e)


# ------------------------------------------------------------------ apoio


## Abre o título com os ganchos (ida ao santuário e saída) e espera o primeiro quadro: o _ready monta tudo.
func _abrir() -> Node:
	var t = Titulo.instantiate()
	t.ao_jogar = Callable(self, "_marcar_jogar")
	add_child(t)
	t.pausa.ao_sair = Callable(self, "_marcar_saida")
	await get_tree().process_frame
	return t


func _marcar_jogar() -> void:
	jogou += 1


func _marcar_saida() -> void:
	saiu += 1


## Os botões do título de cima para baixo: Jogar, Ajustes, Créditos e Sair.
func _botoes(t: Node) -> Array:
	var r: Array = t.find_children("*", "Button", false, false)
	r.sort_custom(func(a, b): return a.position.y < b.position.y)
	return r


func _logo(t: Node) -> Label:
	for l in t.find_children("*", "Label", false, false):
		if l.text == "K.I.K.I.U":
			return l
	return null


func _foco() -> Control:
	return get_viewport().gui_get_focus_owner()


func _centro(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _foto(pasta: String, nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join(nome + ".png"))


# ------------------------------------------------------------------ testes


func _testes() -> void:
	var t = await _abrir()
	var bs := _botoes(t)
	ok(bs.size() == 4, "o título tem 4 botões (Jogar, Ajustes, Créditos e Sair)")
	if bs.size() != 4:
		return
	ok([bs[0].text, bs[1].text, bs[2].text, bs[3].text] == ["JOGAR", "AJUSTES", "CRÉDITOS", "SAIR"], "a ordem é Jogar, Ajustes, Créditos e Sair")
	var logo := _logo(t)
	ok(logo != null and logo.get_theme_font_size("font_size") == Menu.TAM_LOGO, "o logo K.I.K.I.U existe, na Jersey 10 no tamanho do logo")
	ok(logo != null and logo.get_theme_font("font") == Dados.fonte_titulo, "o logo usa a fonte de título (Jersey 10)")
	ok(t.pausa != null and not t.pausa.aberto, "o menu de pausa começa fechado")
	ok(t._trilha != null and t._trilha.faixa == "menu" and t._trilha.momento == "santuario", "a música do título é a do santuário (faixa menu)")
	ok(_foco() == bs[0], "o foco começa em Jogar")

	# teclado: setas e controle (D-pad) descem e sobem a lista
	_tecla(KEY_DOWN)
	ok(_foco() == bs[1], "seta para baixo leva o foco a Ajustes")
	_tecla(KEY_UP)
	ok(_foco() == bs[0], "seta para cima volta o foco a Jogar")
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_DOWN)
	_pad(JOY_BUTTON_DPAD_DOWN)
	ok(_foco() == bs[3], "o D-pad para baixo desce até Sair (controle)")
	_pad(JOY_BUTTON_DPAD_UP)
	ok(_foco() == bs[2], "o D-pad para cima sobe a Créditos (controle)")

	# mouse: passar o cursor põe o foco sob ele
	_mouse_sobre(_centro(bs[1]))
	ok(_foco() == bs[1], "o mouse sobre Ajustes põe o foco nele")
	_mouse_sobre(_centro(bs[0]))
	ok(_foco() == bs[0], "o mouse sobre Jogar põe o foco nele")

	# Jogar: teclado, controle e mouse chamam a ida ao santuário (o gancho); a cena de destino existe
	_tecla(KEY_ENTER)
	ok(jogou == 1, "Enter em Jogar vai ao santuário")
	_pad(JOY_BUTTON_A)
	ok(jogou == 2, "o botão A do controle em Jogar vai ao santuário")
	_clique(_centro(bs[0]))
	ok(jogou == 3, "o clique em Jogar vai ao santuário")
	var cena := load(Menu.ESCOLHA) as PackedScene
	ok(Menu.ESCOLHA == "res://v2/personagens.tscn" and cena != null and cena.can_instantiate(), "o destino de Jogar é o santuário da v2 e a cena carrega")

	# ESC e Start no título: pedem "Sair?" com "Não" marcado; não saem
	_tecla(KEY_ESCAPE)
	ok(t.pausa.aberto and t.pausa.tela == "confirmar_sair", "ESC no título abre 'Sair?' (não fecha o jogo de surpresa)")
	ok(saiu == 0, "ESC não chama a saída")
	_tecla(KEY_ESCAPE)
	ok(not t.pausa.aberto and saiu == 0, "ESC em 'Sair?' é 'Não': fecha e fica no título")
	ok(_foco() == bs[0], "fechar a confirmação devolve o foco a Jogar")
	_pad(JOY_BUTTON_START)
	ok(t.pausa.aberto and t.pausa.tela == "confirmar_sair", "Start no título abre 'Sair?' também")
	_pad(JOY_BUTTON_B)
	ok(not t.pausa.aberto and saiu == 0, "B em 'Sair?' é 'Não' (sem sair)")

	# Ajustes (clique): o submenu da pausa, Gráficos e Áudio, e volta ao foco
	_clique(_centro(bs[1]))
	ok(t.pausa.aberto and t.pausa.tela == "ajustes", "Ajustes abre o submenu da pausa")
	_tecla(KEY_ENTER)
	ok(t.pausa.tela == "graficos", "dentro de Ajustes, o primeiro item abre Gráficos")
	_tecla(KEY_ESCAPE)
	ok(t.pausa.tela == "ajustes", "ESC em Gráficos volta a Ajustes")
	_tecla(KEY_DOWN)
	_tecla(KEY_ENTER)
	ok(t.pausa.tela == "audio", "Áudio abre a partir de Ajustes")
	_tecla(KEY_ESCAPE)
	_tecla(KEY_ESCAPE)
	ok(not t.pausa.aberto and _foco() == bs[1], "ESC em Ajustes fecha e devolve o foco a Ajustes")

	# Créditos (clique): a tela de Créditos da pausa; Voltar (ESC ou o item) fecha direto, sem passar por Ajustes
	_clique(_centro(bs[2]))
	ok(t.pausa.aberto and t.pausa.tela == "creditos", "Créditos abre a tela de Créditos")
	_tecla(KEY_ESCAPE)
	ok(not t.pausa.aberto, "ESC em Créditos fecha direto ao título (não vai a Ajustes)")
	ok(_foco() == bs[2], "fechar Créditos devolve o foco a Créditos")
	_clique(_centro(bs[2]))
	_tecla(KEY_UP)
	_tecla(KEY_ENTER)
	ok(not t.pausa.aberto, "o item Voltar, no fim da lista de Créditos, também fecha direto")

	# Sair (clique): pede confirmação; só o Sim chama a saída
	_clique(_centro(bs[3]))
	ok(t.pausa.aberto and t.pausa.tela == "confirmar_sair" and saiu == 0, "Sair pede confirmação e não sai")
	_tecla(KEY_ESCAPE)
	ok(not t.pausa.aberto and saiu == 0, "Não em 'Sair?' volta ao título")
	_clique(_centro(bs[3]))
	_tecla(KEY_UP)
	_tecla(KEY_ENTER)
	ok(saiu == 1, "o Sim em 'Sair?' chama a saída")

	t.queue_free()
	await get_tree().process_frame
	await _testes_versao()


## Aviso de versão nova (#106), sem rede: a resposta da API é simulada e o carimbo é injetado.
func _testes_versao() -> void:
	var A := preload("res://v2/atualizador.gd")
	var carimbo := {"data": "2026-10-10", "commit": "aaaaaaa"}
	ok(A.mais_nova("build-2026-10-15-bbbbbbb", carimbo), "tag de data posterior é mais nova")
	ok(A.mais_nova("build-2026-10-10-bbbbbbb", carimbo), "mesma data com outro commit é mais nova")
	ok(not A.mais_nova("build-2026-10-10-aaaaaaa", carimbo), "mesmo commit não é mais nova")
	ok(not A.mais_nova("build-2026-10-10-aaaaaaa1234", {"data": "2026-10-10", "commit": "aaaaaaa+"}), "commit com + e o mesmo prefixo não é mais nova")
	ok(not A.mais_nova("build-2026-10-01-bbbbbbb", carimbo), "tag de data anterior não é mais nova")
	ok(not A.mais_nova("lixo", carimbo) and not A.mais_nova("build-2026-10-15-bbbbbbb", {}), "tag fora do formato ou build dev nunca avisa")
	var nova := '{"tag_name": "build-2026-10-15-bbbbbbb", "html_url": "https://github.com/brenoalmeidatec/KIKIU-Survival/releases/tag/build-2026-10-15-bbbbbbb"}'

	# com Release mais nova: o botão aparece e abre a página (gancho, sem navegador)
	var t = Titulo.instantiate()
	t.atualizador.carimbo = carimbo
	t.atualizador.resposta_simulada = nova
	t.abrir_url = Callable(self, "_marcar_url")
	add_child(t)
	await get_tree().process_frame
	ok(t.aviso_versao != null and t.aviso_versao.text == "Versão nova disponível", "Release mais nova mostra o aviso no título")
	if t.aviso_versao != null:
		t.aviso_versao.pressed.emit()
		ok(url_aberta.ends_with("/releases/tag/build-2026-10-15-bbbbbbb"), "o aviso abre a página da Release")
	t.queue_free()
	await get_tree().process_frame

	# a mesma versão, resposta com lixo, URL de outro site e build dev: sem aviso (e a URL de fora cai na página de Releases)
	for caso in [['{"tag_name": "build-2026-10-10-aaaaaaa"}', carimbo], ["não é json", carimbo], [nova, {}]]:
		var u = Titulo.instantiate()
		u.atualizador.carimbo = caso[1]
		u.atualizador.resposta_simulada = caso[0]
		add_child(u)
		await get_tree().process_frame
		ok(u.aviso_versao == null, "sem Release mais nova (ou sem carimbo) não aparece aviso")
		u.queue_free()
		await get_tree().process_frame
	var f = Titulo.instantiate()
	f.atualizador.carimbo = carimbo
	f.atualizador.resposta_simulada = '{"tag_name": "build-2026-10-15-bbbbbbb", "html_url": "https://malicioso.example/x"}'
	f.abrir_url = Callable(self, "_marcar_url")
	add_child(f)
	await get_tree().process_frame
	f.aviso_versao.pressed.emit()
	ok(url_aberta == A.PREFIXO_PAGINA, "URL de outro site na resposta é trocada pela página de Releases do repositório")
	f.queue_free()
	await get_tree().process_frame

	# opção desligada em Ajustes: nem consulta
	Config.definir("verificar_versao", false)
	var d = Titulo.instantiate()
	d.atualizador.carimbo = carimbo
	d.atualizador.resposta_simulada = nova
	add_child(d)
	await get_tree().process_frame
	ok(d.aviso_versao == null and not d.atualizador.verificar(), "com a verificação desligada não consulta nem avisa")
	d._abrir_ajustes()
	var itens: Array = d.pausa._itens()
	var ids: Array = itens.map(func(i): return i.id)
	ok(ids.has("versao"), "Ajustes tem a linha de avisar versão nova")
	d.pausa._executar("versao", 1)
	ok(bool(Config.v("verificar_versao")), "a linha de Ajustes liga a verificação de novo")
	d.queue_free()
	await get_tree().process_frame


var url_aberta := ""


func _marcar_url(u: String) -> void:
	url_aberta = u


func _fotos(pasta: String) -> void:
	var t = await _abrir()
	var bs := _botoes(t)
	bs[0].grab_focus()  # o foco de Jogar, como ao abrir: um cursor real parado sobre um botão mudaria a foto
	_mouse_sobre(Vector2(-100, -100))
	await _foto(pasta, "menu_principal")
	_clique(_centro(bs[1]))
	await _foto(pasta, "menu_ajustes")
	_tecla(KEY_ESCAPE)
	_clique(_centro(bs[2]))
	await _foto(pasta, "menu_creditos")
	_tecla(KEY_ESCAPE)
	_clique(_centro(bs[3]))
	await _foto(pasta, "menu_sair")
	t.queue_free()
	await get_tree().process_frame
	print("v2_menu fotos em ", pasta)
