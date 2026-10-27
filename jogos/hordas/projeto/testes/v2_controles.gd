extends "res://testes/isolamento_v2.gd"
# Controles da v2 (#422): Ajustes > Controles, v2/controles.gd, v2/ajustes_controles.gd e os glifos que seguem a troca. Saves ISOLADOS pela fixture da v2
# (user://testes_v2/v2_controles/): o controles.cfg fica ao lado do opcoes.cfg do Config, e o save do personagem (md5) nunca muda.
# Confere: o padrão do InputMap; remapear tecla, mouse, botão e gatilho; salvar, "recarregar" (apaga as ações, Entrada.garantir as recria e o arquivo
# volta por cima) e aplicar; conflito troca de lugar (e o aviso diz quais); Esc/Start cancelam e tecla reservada, direcional e analógico não valem; arquivo
# estragado cai no padrão; Restaurar padrão apaga o arquivo; o glifo da HUD segue a troca (teclado, Xbox, PlayStation); e a tela de verdade, pelo caminho
# da janela (Input.parse_input_event): linhas, captura por teclado, mouse e controle, Esc cancela, soltar o mouse não reabre a captura.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_controles.tscn  (imprime "v2_controles falhas=0")
# Fotos (com janela): godot --path jogos/hordas/projeto res://testes/v2_controles.tscn -- --fotos=PASTA  (controles_teclado, controles_conflito, controles_controle)

const Controles := preload("res://v2/controles.gd")
const Glifos := preload("res://v2/glifos.gd")
const Entrada := preload("res://v2/entrada.gd")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const Pausa := preload("res://v2/pausa.tscn")
const Altar := preload("res://v2/altar.tscn")
const Mundo := preload("res://v2/mundo.tscn")

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Glifos.definir(Glifos.Disp.TECLADO)
	Entrada.garantir()
	var salvos := _criar_saves()
	var md5_saves := _md5s(salvos)
	_padrao()
	_remapear()
	_persistencia()
	_conflito()
	_recusas()
	_arquivo_estragado()
	_glifos()
	_restaurar()
	await _tela()
	ok(_md5s(salvos) == md5_saves, "o save do personagem e as opções do Config não foram tocados (md5 igual)")
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
	Glifos._ouvintes.clear()  # o lambda de _glifos guarda o script do teste numa lista estática: solto, o Godot trava ao desligar
	print("v2_controles falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func _escrever(c: String, texto: String) -> void:
	var f := FileAccess.open(c, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


## Um save de personagem, o índice e a meta de mentira: o teste prova que nenhum passou por escrita.
func _criar_saves() -> Array:
	var r := [Meta.caminho_save, Personagens.caminho_indice, Personagens.caminho_base + "a.cfg"]
	for c in r:
		_escrever(c, '[teste]\nvalor="%s"\n' % c.get_file())
	Config.definir("musica", 0.3)  # as opções do Config também existem e não podem ser tocadas pelo controles.cfg
	r.append(Config.arquivo)
	return r


func _md5s(cs: Array) -> Array:
	return cs.map(func(c): return FileAccess.get_md5(c) if FileAccess.file_exists(c) else "")


func _k(k: Key, pressionado := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = pressionado
	return e


func _m(b: MouseButton, pressionado := true) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	e.pressed = pressionado
	return e


func _b(b: JoyButton, pressionado := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = pressionado
	return e


func _gatilho(eixo: JoyAxis) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = eixo
	e.axis_value = 1.0
	return e


func _tem_tecla(acao: String, k: Key) -> bool:
	return ("k:%d" % k) in Controles.codigos(acao, "teclado")


func _padrao() -> void:
	ok(
		Controles.codigos("esquiva", "teclado") == ["k:%d" % KEY_SPACE] and Controles.codigos("esquiva", "controle") == ["b:%d" % JOY_BUTTON_B],
		"esquiva: Espaço e B"
	)
	ok(
		Controles.codigos("atacar", "teclado") == ["m:1"] and Controles.codigos("atacar", "controle") == ["t:%d" % JOY_AXIS_TRIGGER_RIGHT],
		"atacar: mouse esquerdo e RT"
	)
	ok(
		Controles.codigos("escudo", "teclado") == ["m:2"] and Controles.codigos("escudo", "controle") == ["t:%d" % JOY_AXIS_TRIGGER_LEFT],
		"escudo: mouse direito e LT"
	)
	ok(_tem_tecla("ruptura", KEY_E) and Controles.codigos("ruptura", "controle") == ["b:%d" % JOY_BUTTON_LEFT_SHOULDER], "habilidade: E e LB")
	ok(_tem_tecla("ultimate", KEY_Q) and Controles.codigos("ultimate", "controle") == ["b:%d" % JOY_BUTTON_RIGHT_SHOULDER], "especial: Q e RB")
	ok(_tem_tecla("correr", KEY_SHIFT) and Controles.codigos("correr", "controle") == ["b:%d" % JOY_BUTTON_LEFT_STICK], "correr: Shift e L3")
	ok(_tem_tecla("esquerda", KEY_A) and _tem_tecla("esquerda", KEY_LEFT), "andar para a esquerda: A e seta")
	ok(Controles.slots_da_acao("cima") == ["teclado"], "andar só tem o slot do teclado (o analógico não muda)")
	ok(not Controles.alguma_alterada() and not FileAccess.file_exists(Controles.arquivo()), "sem troca não existe controles.cfg")
	ok(Controles.arquivo() == Config.arquivo.get_base_dir().path_join("controles.cfg"), "o arquivo fica ao lado do arquivo de opções do Config")
	ok(Controles.arquivo().begins_with(AmbienteTesteV2.PREFIXO), "e o teste roda isolado (%s)" % Controles.arquivo())


func _remapear() -> void:
	var r := Controles.definir("esquiva", _k(KEY_J))
	ok(bool(r.ok) and String(r.troca) == "", "J livre: troca sem conflito")
	ok(Controles.codigos("esquiva", "teclado") == ["k:%d" % KEY_J], "a esquiva agora é J (e não mais o Espaço)")
	ok(Controles.codigos("esquiva", "controle") == ["b:%d" % JOY_BUTTON_B], "o slot do controle da esquiva ficou como estava")
	ok(InputMap.action_has_event("esquiva", _k(KEY_J)), "o InputMap vale na hora")
	ok(not InputMap.action_has_event("esquiva", _k(KEY_SPACE)), "o Espaço saiu da esquiva")
	ok(Controles.alterada("esquiva", "teclado") and not Controles.alterada("esquiva", "controle"), "só o slot trocado conta como alterado")
	r = Controles.definir("esquiva", _b(JOY_BUTTON_X))
	ok(bool(r.ok) and Controles.codigos("esquiva", "controle") == ["b:%d" % JOY_BUTTON_X], "botão X do controle na esquiva")
	r = Controles.definir("ultimate", _m(MOUSE_BUTTON_MIDDLE))
	ok(bool(r.ok) and Controles.codigos("ultimate", "teclado") == ["m:3"], "botão do meio do mouse no especial")
	ok(InputMap.action_has_event("ultimate", _m(MOUSE_BUTTON_MIDDLE)), "o mouse também entra no InputMap")
	r = Controles.definir("cima", _k(KEY_I))
	ok(bool(r.ok) and Controles.codigos("cima", "teclado") == ["k:%d" % KEY_I], "andar para cima: a letra e a seta saem, fica só o I")
	r = Controles.definir("esquiva", _k(KEY_J))
	ok(bool(r.ok) and String(r.motivo) == "igual", "apertar o comando que já vale não muda nada")
	ok(bool(Controles.definir("esquiva", _k(KEY_ENTER)).ok), "Enter pode")
	Controles.definir("esquiva", _k(KEY_J))


func _persistencia() -> void:
	ok(FileAccess.file_exists(Controles.arquivo()), "a troca gravou o controles.cfg")
	var cfg := ConfigFile.new()
	ok(cfg.load(Controles.arquivo()) == OK and cfg.has_section_key("controles", "cima_teclado"), "o arquivo tem a seção [controles]")
	ok(not cfg.has_section_key("controles", "atacar_teclado"), "só o que difere do padrão é gravado")
	# "recarregar": o jogo abre de novo (as ações somem, Entrada.garantir cria o padrão e o arquivo vale por cima)
	var antes := Controles.codigos("esquiva", "controle")
	for a in Controles.ACOES:
		InputMap.erase_action(a.id)
	ok(Controles.codigos("cima", "teclado").is_empty(), "ações apagadas (jogo recém-aberto)")
	Entrada.garantir()
	ok(Controles.codigos("cima", "teclado") == ["k:%d" % KEY_I], "depois de recarregar, o I continua em cima")
	ok(Controles.codigos("esquiva", "controle") == antes, "e o botão do controle da esquiva também")
	ok(Controles.codigos("ultimate", "teclado") == ["m:3"], "e o botão do meio do mouse no especial")
	ok(_tem_tecla("ruptura", KEY_E) and _tem_tecla("correr", KEY_SHIFT), "o resto segue no padrão")
	Entrada.garantir()
	ok(Controles.codigos("cima", "teclado").size() == 1 and InputMap.action_get_events("ruptura").size() == 2, "garantir de novo não empilha eventos")
	Controles.restaurar()


func _conflito() -> void:
	var r := Controles.definir("correr", _k(KEY_E))  # o E é da habilidade
	ok(bool(r.ok) and String(r.troca) == "ruptura", "E já era da habilidade: as duas trocam (%s)" % [r])
	ok(Controles.codigos("correr", "teclado") == ["k:%d" % KEY_E], "correr ficou com o E")
	ok(Controles.codigos("ruptura", "teclado") == ["k:%d" % KEY_SHIFT], "a habilidade ganhou o Shift que o correr tinha")
	ok(Controles.alterada("ruptura", "teclado"), "a ação que foi trocada também conta como alterada")
	# o mesmo pelo controle (gatilho): atacar com LT troca com o escudo
	r = Controles.definir("atacar", _gatilho(JOY_AXIS_TRIGGER_LEFT))
	ok(String(r.troca) == "escudo", "LT era do escudo")
	ok(
		(
			Controles.codigos("atacar", "controle") == ["t:%d" % JOY_AXIS_TRIGGER_LEFT]
			and Controles.codigos("escudo", "controle") == ["t:%d" % JOY_AXIS_TRIGGER_RIGHT]
		),
		"os gatilhos trocaram"
	)
	# andar tem duas teclas: a troca leva o conjunto inteiro
	r = Controles.definir("cima", _k(KEY_A))  # o A é da esquerda (A e seta)
	ok(String(r.troca) == "esquerda", "o A era da esquerda")
	ok(Controles.codigos("cima", "teclado") == ["k:%d" % KEY_A], "cima ficou com o A")
	ok(_tem_tecla("esquerda", KEY_W) and _tem_tecla("esquerda", KEY_UP), "a esquerda ganhou o W e a seta de cima")
	# ninguém fica com um comando repetido
	var vistos := {}
	var repetido := false
	for a in Controles.ACOES:
		for s in a.slots:
			for c in Controles.codigos(a.id, s):
				repetido = repetido or vistos.has(s + c)
				vistos[s + c] = true
	ok(not repetido, "depois das trocas nenhum comando vale para duas ações")
	Controles.restaurar()


func _recusas() -> void:
	var antes := Controles.codigos("esquiva", "teclado")
	ok(not bool(Controles.definir("esquiva", _k(KEY_ESCAPE)).ok), "Esc é reservada")
	ok(not bool(Controles.definir("esquiva", _k(KEY_F11)).ok) and not bool(Controles.definir("esquiva", _k(KEY_TAB)).ok), "F11 e Tab são reservadas")
	ok(String(Controles.definir("esquiva", _b(JOY_BUTTON_START)).motivo) == "reservada", "Start (a pausa) é reservado")
	ok(String(Controles.definir("esquiva", _b(JOY_BUTTON_DPAD_UP)).motivo) == "reservada", "o direcional navega os menus: reservado")
	ok(String(Controles.definir("esquiva", _m(MOUSE_BUTTON_WHEEL_UP)).motivo) == "invalida", "a roda do mouse não é comando")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	ok(not bool(Controles.definir("esquiva", stick).ok), "o analógico não é remapeável")
	ok(String(Controles.definir("cima", _b(JOY_BUTTON_A)).motivo) == "slot", "andar só aceita tecla")
	ok(not bool(Controles.definir("nao_existe", _k(KEY_J)).ok), "ação que não existe")
	ok(Controles.codigos("esquiva", "teclado") == antes and not Controles.alguma_alterada(), "nada disso mudou o InputMap")


func _arquivo_estragado() -> void:
	_escrever(
		Controles.arquivo(),
		'[controles]\nesquiva_teclado=["k:0", "lixo", "b:1", "m:99"]\natacar_controle="texto"\nruptura_teclado=["k:%d"]\nescudo_controle=["k:65"]\n' % KEY_H
	)
	Controles.aplicar()
	ok(Controles.codigos("esquiva", "teclado") == ["k:%d" % KEY_SPACE], "códigos que não valem caem no padrão da ação")
	ok(Controles.codigos("atacar", "controle") == ["t:%d" % JOY_AXIS_TRIGGER_RIGHT], "valor que não é lista cai no padrão")
	ok(Controles.codigos("escudo", "controle") == ["t:%d" % JOY_AXIS_TRIGGER_LEFT], "tecla num slot de controle não vale: padrão")
	ok(Controles.codigos("ruptura", "teclado") == ["k:%d" % KEY_H], "o que vale no mesmo arquivo é aplicado")
	_escrever(Controles.arquivo(), "isto nem é um arquivo de configuração [[[")
	Controles.aplicar()
	ok(_tem_tecla("ruptura", KEY_E), "arquivo ilegível: tudo no padrão")
	Controles.restaurar()


func _glifos() -> void:
	var avisos := [0]
	Glifos.ao_mudar(func(): avisos[0] += 1)
	Glifos.definir(Glifos.Disp.TECLADO)
	ok(
		Glifos.descritor("esquiva") == [[Glifos.TECLA, "Espaço"]] and Glifos.descritor("secundario") == [[Glifos.MOUSE, "d"]],
		"padrão: Espaço e o mouse direito"
	)
	Controles.definir("esquiva", _k(KEY_J))
	Controles.definir("escudo", _m(MOUSE_BUTTON_MIDDLE))
	Glifos.avisar()  # a tela de Controles faz isto depois de cada troca
	ok(avisos[0] >= 1, "trocar um comando avisa as dicas e a HUD (%d)" % avisos[0])
	ok(Glifos.descritor("esquiva") == [[Glifos.TECLA, "J"]], "o glifo da esquiva segue o J: %s" % [Glifos.descritor("esquiva")])
	ok(Glifos.descritor("secundario") == [[Glifos.MOUSE, "m"]], "o glifo do escudo vira o botão do meio")
	ok(Glifos.texto("esquiva") == "J", "e o texto também")
	ok(Glifos.descritor("habilidade") == [[Glifos.TECLA, "E"]], "o que não foi trocado segue a tabela")
	Controles.definir("esquiva", _b(JOY_BUTTON_X))
	Glifos.definir(Glifos.Disp.XBOX)
	ok(Glifos.descritor("esquiva") == [[Glifos.FACE, "X"]], "Xbox: esquiva no X")
	Glifos.definir(Glifos.Disp.PS)
	ok(Glifos.descritor("esquiva") == [[Glifos.PS, "q"]], "PlayStation: esquiva no quadrado")
	Controles.definir("escudo", _gatilho(JOY_AXIS_TRIGGER_RIGHT))
	ok(Glifos.descritor("secundario") == [[Glifos.TECLA, "R2"]], "PlayStation: escudo no R2")
	Glifos.definir(Glifos.Disp.XBOX)
	ok(Glifos.descritor("secundario") == [[Glifos.TECLA, "RT"]], "Xbox: escudo no RT")
	Controles.definir("atacar", _k(KEY_X))
	Glifos.definir(Glifos.Disp.TECLADO)
	ok(Glifos.descritor("clique") == [[Glifos.MOUSE, "e"]], "o clique do salão (explorar) é o mouse, não segue o atacar")
	Glifos.definir(Glifos.Disp.XBOX)
	ok(Glifos.descritor("ultimate") == [[Glifos.TECLA, "RB"]], "o especial não mudou")
	var d: Array = Glifos.descritores_da_acao("esquiva")
	ok(d[0] == [[Glifos.TECLA, "J"]] and d[1] == [[Glifos.FACE, "X"]], "a tela mostra os dois slots lado a lado: %s" % [d])
	Controles.restaurar()
	ok(Glifos.descritor("esquiva") == [[Glifos.FACE, "B"]], "restaurado: o glifo volta ao do padrão")
	Glifos.definir(Glifos.Disp.TECLADO)
	ok(Glifos.descritor("esquiva") == [[Glifos.TECLA, "Espaço"]], "restaurado: Espaço")


func _restaurar() -> void:
	Controles.definir("esquiva", _k(KEY_J))
	Controles.definir("correr", _k(KEY_E))
	ok(FileAccess.file_exists(Controles.arquivo()), "há troca gravada")
	Controles.restaurar()
	ok(
		Controles.codigos("esquiva", "teclado") == ["k:%d" % KEY_SPACE] and _tem_tecla("ruptura", KEY_E) and _tem_tecla("correr", KEY_SHIFT),
		"Restaurar padrão: tudo volta"
	)
	ok(not FileAccess.file_exists(Controles.arquivo()) and not Controles.alguma_alterada(), "e o controles.cfg some")


# ------------------------------------------------------------------ a tela de verdade


func _enviar(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _toque(k: Key) -> void:
	_enviar(_k(k))
	_enviar(_k(k, false))


func _ids(p) -> Array:
	return p._itens_atuais.map(func(i): return str(i.id))


func _ir_para(p, id: String) -> void:
	for i in 20:
		if str(p._itens_atuais[p.sel].id) == id:
			return
		_toque(KEY_DOWN)


func _tela() -> void:
	var p = Pausa.instantiate().iniciar(null)
	add_child(p)
	await get_tree().process_frame
	p.abrir_ajustes()
	var ajustes: Array = _ids(p)
	ok(
		ajustes.has("controles") and ajustes.find("controles") == ajustes.find("audio") + 1,
		"Ajustes tem a entrada Controles logo depois de Áudio: %s" % [ajustes]
	)
	var visiveis := 0
	for l in p._linhas:
		visiveis += 1 if l["linha"].visible else 0
	ok(visiveis == ajustes.size(), "as %d linhas do Ajustes cabem sem rolar (%d)" % [ajustes.size(), visiveis])
	_ir_para(p, "controles")
	_toque(KEY_ENTER)
	ok(p.tela == "controles" and p._titulo.text == "CONTROLES", "Enter abre a tela de Controles")
	var ids := _ids(p)
	ok(
		ids.size() == Controles.ACOES.size() + 2 and ids[0] == "ct:atacar" and ids[-2] == "ct:restaurar" and ids[-1] == "voltar",
		"uma linha por ação, Restaurar padrão e Voltar: %s" % [ids]
	)
	ok(p._linhas[0]["glifos"].visible and p._linhas[0]["glifos"].acao == "atacar", "a linha mostra os glifos da ação")
	# teclado: esquiva -> J
	_ir_para(p, "ct:esquiva")
	_toque(KEY_ENTER)
	ok(p._controles.capturando == "esquiva", "Enter espera o comando novo")
	ok(str(p._itens_atuais[p.sel].valor) != "" and not p._linhas[p.sel - p._topo]["glifos"].visible, "a linha avisa que espera e esconde os glifos")
	_toque(KEY_J)
	ok(p._controles.capturando == "" and p.tela == "controles", "a tecla fecha a captura e fica na tela")
	ok(Controles.codigos("esquiva", "teclado") == ["k:%d" % KEY_J], "pela janela: a esquiva virou J")
	ok(FileAccess.file_exists(Controles.arquivo()), "e foi salvo")
	# Esc cancela (e não volta uma tela)
	_toque(KEY_ENTER)
	ok(p._controles.capturando == "esquiva", "de novo")
	_toque(KEY_ESCAPE)
	ok(
		p._controles.capturando == "" and p.tela == "controles" and Controles.codigos("esquiva", "teclado") == ["k:%d" % KEY_J],
		"Esc cancela sem trocar e sem sair da tela"
	)
	# tecla reservada: avisa e segue esperando; depois uma boa
	_toque(KEY_ENTER)
	_toque(KEY_TAB)
	ok(p._controles.capturando == "esquiva" and p._sub.text.contains("reservado"), "Tab é reservada: avisa e segue esperando (%s)" % p._sub.text)
	_toque(KEY_K)
	ok(p._controles.capturando == "" and Controles.codigos("esquiva", "teclado") == ["k:%d" % KEY_K], "outra tecla vale")
	# conflito pela tela: correr com E troca com a habilidade
	_ir_para(p, "ct:correr")
	_toque(KEY_ENTER)
	_toque(KEY_E)
	ok(p._sub.text == "Correr e Habilidade trocaram de lugar.", "o aviso do conflito diz quais: %s" % p._sub.text)
	ok(_tem_tecla("correr", KEY_E) and _tem_tecla("ruptura", KEY_SHIFT), "trocaram de fato")
	_toque(KEY_DOWN)
	ok(p._sub.text == "", "mexer na lista limpa o aviso")
	# mouse: o clique direito vira o especial; a soltura não reabre a captura nem aperta a linha
	_ir_para(p, "ct:ultimate")
	_toque(KEY_ENTER)
	_enviar(_m(MOUSE_BUTTON_RIGHT))
	_enviar(_m(MOUSE_BUTTON_RIGHT, false))
	ok(p._controles.capturando == "" and Controles.codigos("ultimate", "teclado") == ["m:2"], "clique direito no especial (troca com o escudo)")
	ok(_tem_tecla("escudo", KEY_Q), "o escudo ganhou o Q")
	ok(p._apertos.is_empty(), "o clique capturado não fica para a soltura acionar uma linha")
	# controle: botão Y na esquiva, gatilho RT no escudo
	_ir_para(p, "ct:esquiva")
	_toque(KEY_ENTER)
	_enviar(_b(JOY_BUTTON_Y))
	_enviar(_b(JOY_BUTTON_Y, false))
	ok(Controles.codigos("esquiva", "controle") == ["b:%d" % JOY_BUTTON_Y] and p._controles.capturando == "", "botão Y do controle na esquiva")
	_ir_para(p, "ct:escudo")
	_toque(KEY_ENTER)
	var deriva := _gatilho(JOY_AXIS_TRIGGER_RIGHT)
	deriva.axis_value = 0.2
	_enviar(deriva)
	ok(p._controles.capturando == "escudo", "gatilho de leve (deriva) não conta")
	var repouso := _gatilho(JOY_AXIS_TRIGGER_RIGHT)
	repouso.axis_value = -1.0  # alguns drivers deixam o gatilho parado em -1
	_enviar(repouso)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	_enviar(stick)
	ok(p._controles.capturando == "escudo" and p._sub.text == "", "gatilho em repouso e analógico firme são ignorados em silêncio")
	_enviar(_gatilho(JOY_AXIS_TRIGGER_RIGHT))
	ok(
		(
			Controles.codigos("escudo", "controle") == ["t:%d" % JOY_AXIS_TRIGGER_RIGHT]
			and Controles.codigos("atacar", "controle") == ["t:%d" % JOY_AXIS_TRIGGER_LEFT]
		),
		"gatilho RT no escudo troca com o atacar"
	)
	# Start cancela a captura
	_ir_para(p, "ct:atacar")
	_toque(KEY_ENTER)
	_enviar(_b(JOY_BUTTON_START))
	ok(p._controles.capturando == "" and p.tela == "controles" and p.aberto, "Start cancela a captura (não fecha a tela)")
	# com a captura aberta o B vai para a captura (não volta a tela)
	_toque(KEY_ENTER)
	_enviar(_b(JOY_BUTTON_B))
	ok(Controles.codigos("atacar", "controle") == ["b:%d" % JOY_BUTTON_B] and p.tela == "controles", "B vira o comando do atacar (não volta a tela)")
	# Restaurar padrão pela tela
	_ir_para(p, "ct:restaurar")
	_toque(KEY_ENTER)
	ok(not Controles.alguma_alterada() and not FileAccess.file_exists(Controles.arquivo()), "Restaurar padrão pela tela")
	ok(p._sub.text == "Controles restaurados.", "e avisa")
	# Esc volta a Ajustes, Voltar também
	_toque(KEY_ESCAPE)
	ok(p.tela == "ajustes" and p.aberto, "Esc volta a Ajustes")
	_ir_para(p, "controles")
	_toque(KEY_ENTER)
	_ir_para(p, "voltar")
	_toque(KEY_ENTER)
	ok(p.tela == "ajustes", "Voltar volta a Ajustes")
	p.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------ fotos (só com janela)


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	# a HUD da partida com a habilidade no Shift e o especial no Espaço (as teclas de nome mais largo): o selo tem de caber no slot
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	Controles.definir("ruptura", _k(KEY_SHIFT))
	Controles.definir("ultimate", _k(KEY_SPACE))
	Glifos.avisar()
	await get_tree().process_frame
	await mundo.ap.foto(pasta.path_join("controles_hud.png"))
	Controles.restaurar()
	Glifos.avisar()
	mundo.queue_free()
	await get_tree().process_frame  # a janela volta à escala antes de o santuário montar a dele
	var altar = Altar.instantiate()  # a janela de verdade: o santuário monta a escala da UI (960x540) e o menu de pausa dele
	add_child(altar)
	await _quadros(3)
	var p = altar.pausa
	altar._ajustes.pressed.emit()
	p._executar("controles", 0)
	Controles.definir("esquiva", _k(KEY_J))
	Controles.definir("atacar", _k(KEY_X))
	p._desenhar()
	await _foto(pasta.path_join("controles_teclado.png"))
	Controles.definir("correr", _k(KEY_E))
	Glifos.avisar()
	p._controles.mensagem = "Correr e Habilidade trocaram de lugar."
	p.sel = 3
	p._desenhar()
	await _foto(pasta.path_join("controles_conflito.png"))
	Glifos.definir(Glifos.Disp.PS)
	p._controles.mensagem = ""
	p.sel = 2
	p._executar("ct:esquiva", 0)
	await _foto(pasta.path_join("controles_controle.png"))
	p._controles.limpar()
	Controles.restaurar()
	altar.queue_free()
	await get_tree().process_frame


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto(caminho: String) -> void:
	await _quadros(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(caminho)
