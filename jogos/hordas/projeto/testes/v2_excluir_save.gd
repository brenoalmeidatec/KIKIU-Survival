extends "res://testes/isolamento_v2.gd"
# Excluir save na v2 (#426): Personagens.excluir (um slot), Personagens.apagar_tudo, a confirmação da tela PERSONAGENS (EXCLUIR, dois passos,
# foco em NÃO) e "Apagar todo o progresso" em Ajustes (só fora da partida). Saves ISOLADOS pela fixture da v2 (user://testes_v2/v2_excluir_save/):
# excluir um slot não toca nos outros (md5 igual); o .bak e o .tmp do slot saem junto; excluir o ativo deixa ninguém ativo (a escolha volta);
# apagar tudo leva slots, .bak, índice e o save antigo (senão a migração o traria de volta) e preserva as opções do jogador (Config) e o
# marcador da migração de pasta.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_excluir_save.tscn  (imprime "v2_excluir_save falhas=0")

const Personagens := preload("res://v2/personagens.gd")
const Meta := preload("res://v2/meta.gd")
const Tela := preload("res://v2/personagens.tscn")
const Pausa := preload("res://v2/pausa.tscn")

var falhas := 0
var _apagou := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	_slot()
	_tudo()
	await _tela()
	await _ajustes()
	print("v2_excluir_save falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func _md5(c: String) -> String:
	return FileAccess.get_md5(c) if FileAccess.file_exists(c) else ""


func _existe(c: String) -> bool:
	return FileAccess.file_exists(c)


func _escrever(c: String, texto := "x") -> void:
	var f := FileAccess.open(c, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


func _raiz() -> String:
	return AmbienteTesteV2.raiz


## Esvazia a pasta da fixture, menos as opções (Config) que o resto do teste confere.
func _limpar() -> void:
	for ent in DirAccess.get_files_at(_raiz()):
		if ent != "opcoes.cfg":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_raiz() + ent))


## Cria n personagens, cada um com um save que já tem .bak (duas gravações). Deixa o último ativo.
func _criar(n: int) -> Array:
	var ids := []
	for i in n:
		var id := Personagens.criar(["Breno", "Nicão", "Lucas", "Matheus"][i])
		Personagens.ativar(id)
		Meta.creditar(10 * (i + 1))
		Meta.creditar(5)
		ids.append(id)
	return ids


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func _slot() -> void:
	_limpar()
	var ids := _criar(3)
	var s: Array = ids.map(Personagens.caminho_do_save)
	ok(_existe(s[1] + ".bak"), "preparo: o slot tem .bak")
	_escrever(s[1] + ".tmp")  # sobra de uma gravação interrompida
	var opcoes := _raiz() + "opcoes.cfg"
	Config.definir("musica", 0.3)
	var md5_opcoes := _md5(opcoes)
	ok(md5_opcoes != "", "preparo: as opções existem")
	var md5_0 := _md5(s[0])
	var md5_0b := _md5(s[0] + ".bak")
	var md5_2 := _md5(s[2])
	ok(not Personagens.excluir("p99"), "excluir um id que não existe devolve false")
	ok(Personagens.excluir(ids[1]), "excluir o p2 devolve true")
	ok(not _existe(s[1]) and not _existe(s[1] + ".bak") and not _existe(s[1] + ".tmp"), "o save, o .bak e o .tmp do slot saem")
	ok(Personagens.lista() == [ids[0], ids[2]], "o índice perde só o p2: %s" % [Personagens.lista()])
	ok(Personagens.nome(ids[1]) == "", "o nome do p2 sai do índice")
	ok(_md5(s[0]) == md5_0 and _md5(s[0] + ".bak") == md5_0b, "o slot 1 (e o .bak) ficam intactos")
	ok(_md5(s[2]) == md5_2, "o slot 3 fica intacto")
	ok(Personagens.ativo() == ids[2], "excluir outro não muda o ativo")
	ok(_md5(opcoes) == md5_opcoes, "as opções do jogador não mudam")
	# o ativo: ninguém fica ativo (a tela de escolha reaparece) e a meta não aponta mais para o slot apagado
	ok(Personagens.excluir(ids[2]), "excluir o ativo")
	ok(Personagens.ativo() == "", "sem ativo depois de excluir o ativo")
	ok(Meta.caminho_save != s[2], "a meta deixa de apontar para o slot apagado")
	Meta.saldo()
	ok(not _existe(s[2]), "ler a meta não recria o save apagado")
	ok(Personagens.lista() == [ids[0]], "sobra o p1")
	Personagens.iniciar()
	ok(Personagens.ativo() == "" and Personagens.lista() == [ids[0]], "reabrir o jogo não reativa nem migra nada")
	# um personagem novo não herda o slot apagado
	var novo := Personagens.criar("Lucas")
	ok(novo != "" and not _existe(Personagens.caminho_do_save(novo)), "o personagem novo começa sem save")
	_limpar()


func _tudo() -> void:
	_limpar()
	var ids := _criar(3)
	var raiz := _raiz()
	_escrever(raiz + "v2_personagem_p9.cfg")  # slot órfão: fora do índice, mas é progresso
	_escrever(Personagens.caminho_antigo)  # o save antigo (copiado para a pasta própria)
	_escrever(Personagens.caminho_antigo + ".bak")
	_escrever(raiz + "migrado_da_pasta_godot.txt", "marcador")
	Config.definir("efeitos", 0.4)
	var opcoes := raiz + "opcoes.cfg"
	var md5_opcoes := _md5(opcoes)
	Personagens.apagar_tudo()
	for id in ids:
		var c := Personagens.caminho_do_save(id)
		ok(not _existe(c) and not _existe(c + ".bak"), "apagar tudo leva o slot %s e o .bak" % id)
	ok(not _existe(raiz + "v2_personagem_p9.cfg"), "leva também o slot órfão")
	ok(not _existe(Personagens.caminho_indice), "leva o índice")
	ok(not _existe(Personagens.caminho_antigo) and not _existe(Personagens.caminho_antigo + ".bak"), "leva o save antigo e o .bak dele")
	ok(Personagens.lista().is_empty() and Personagens.ativo() == "", "sem personagens e sem ativo")
	ok(_md5(opcoes) == md5_opcoes and md5_opcoes != "", "as opções (gráficos, som, controle) ficam iguais")
	ok(_existe(raiz + "migrado_da_pasta_godot.txt"), "o marcador da migração de pasta fica")
	Personagens.iniciar()
	ok(Personagens.lista().is_empty(), "reabrir o jogo não traz o progresso de volta pela migração")
	ok(not _existe(Personagens.caminho_indice), "e não recria o índice")
	_limpar()


func _tela() -> void:
	_limpar()
	var ids := _criar(3)  # Breno, Nicão, Lucas; o Lucas é o ativo
	var t = Tela.instantiate()
	add_child(t)
	await _frames()
	ok(t._lista.get_child_count() == 4, "a lista tem 3 personagens e NOVO PERSONAGEM")
	ok(t._excluir.visible and t._alvo == ids[0], "com o 1º personagem na ficha, EXCLUIR aparece para ele")
	ok(not t._modal_aberto(), "a confirmação começa fechada")
	ok(t._lista.get_child(0).focus_neighbor_right == t._excluir.get_path(), "a seta para a direita (teclado e controle) chega ao EXCLUIR")
	ok(t._excluir.focus_neighbor_left == t._lista.get_child(0).get_path(), "e a esquerda volta ao personagem")
	t._lista.get_child(3).grab_focus()
	ok(not t._excluir.visible, "em NOVO PERSONAGEM o EXCLUIR some")
	t._lista.get_child(2).grab_focus()
	ok(t._excluir.visible and t._alvo == ids[2], "o EXCLUIR segue o personagem em foco")
	# passo 1: pedir; padrão em NÃO
	t._excluir.pressed.emit()
	ok(t._modal_aberto(), "EXCLUIR abre a confirmação")
	ok(t._modal_titulo.text == "EXCLUIR LUCAS?", "o título nomeia o personagem: %s" % t._modal_titulo.text)
	var txt: String = t._modal_texto.text
	ok(txt.contains("almas") and txt.contains("estátuas") and txt.contains("conquistas"), "o texto diz o que se perde")
	ok(get_viewport().gui_get_focus_owner() == t._modal_nao, "o foco começa em NÃO")
	ok(Personagens.lista().size() == 3, "pedir não apaga nada")
	# ESC (B) é NÃO
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames()
	ok(not t._modal_aberto() and Personagens.lista().size() == 3, "ESC fecha a confirmação sem apagar")
	ok(get_viewport().gui_get_focus_owner() == t._lista.get_child(2), "o foco volta ao personagem")
	# NÃO pelo botão
	t._excluir.pressed.emit()
	t._modal_nao.pressed.emit()
	ok(not t._modal_aberto() and Personagens.lista().size() == 3, "NÃO fecha sem apagar")
	# o foco da confirmação não vaza para a lista por trás
	t._excluir.pressed.emit()
	var preso: bool = t._modal_nao.focus_neighbor_left == t._modal_sim.get_path() and t._modal_nao.focus_neighbor_top == t._modal_nao.get_path()
	ok(preso, "o foco fica preso na confirmação")
	# passo 2: SIM (o Lucas é o ativo)
	var md5_p1 := _md5(Personagens.caminho_do_save(ids[0]))
	ok(Personagens.ativo() == ids[2], "o Lucas é o ativo antes")
	t._modal_sim.pressed.emit()
	await _frames()
	ok(not t._modal_aberto(), "SIM fecha a confirmação")
	ok(Personagens.lista() == [ids[0], ids[1]], "SIM exclui o Lucas")
	var c_lucas := Personagens.caminho_do_save(ids[2])
	ok(not _existe(c_lucas) and not _existe(c_lucas + ".bak"), "o save e o .bak dele saem")
	ok(Personagens.ativo() == "", "excluir o ativo volta à escolha: ninguém ativo")
	ok(_md5(Personagens.caminho_do_save(ids[0])) == md5_p1, "o save do Breno não é tocado")
	ok(t._lista.get_child_count() == 3 and t._aviso.text == "Lucas excluído.", "a lista se refaz e avisa: %s" % t._aviso.text)
	# excluir os dois que sobram: a lista fica só com NOVO PERSONAGEM
	for i in 2:
		t._lista.get_child(0).grab_focus()
		t._pedir_exclusao()
		t._modal_sim.pressed.emit()
		await _frames()
	ok(Personagens.lista().is_empty() and t._lista.get_child_count() == 1 and not t._excluir.visible, "sem personagens: só NOVO PERSONAGEM e sem EXCLUIR")
	t.queue_free()
	await _frames()
	_limpar()


func _ajustes() -> void:
	_limpar()
	var ids := _criar(2)
	var s: Array = ids.map(Personagens.caminho_do_save)
	var md5_a := _md5(s[0])
	var p = Pausa.instantiate().iniciar(null)
	add_child(p)
	p.apagou_tudo.connect(func(): _apagou += 1)
	p.abrir_ajustes()
	var itens: Array = p._itens_atuais.map(func(i): return i.id)
	ok(
		itens == ["graficos", "audio", "controles", "animacoes", "versao", "creditos", "apagar", "voltar"],
		"Ajustes (fora da partida) tem Apagar todo o progresso: %s" % [itens]
	)
	ok(str(p._itens_atuais[6].rotulo) == "Apagar todo o progresso", "o rótulo da opção")
	var visiveis := 0
	for l in p._linhas:
		visiveis += 1 if l["linha"].visible else 0
	ok(visiveis == 8, "as 8 linhas cabem sem rolar: %d" % visiveis)
	# passo 1: pede; "Não" é o padrão e devolve a Ajustes
	p._executar("apagar", 0)
	ok(p.tela == "confirmar_apagar" and p.sel == 1, "pedir abre a confirmação com 'Não' marcado")
	ok(p._itens_atuais.map(func(i): return i.id) == ["ok_apagar", "nao"], "Sim e Não")
	ok(p._titulo.text == "APAGAR TUDO?", "título: %s" % p._titulo.text)
	p._voltar_tela()  # ESC / B
	ok(p.tela == "ajustes" and Personagens.lista().size() == 2 and _md5(s[0]) == md5_a, "ESC é Não: volta a Ajustes sem apagar")
	p._executar("apagar", 0)
	p._executar("nao", 0)
	ok(p.tela == "ajustes" and Personagens.lista().size() == 2, "Não volta a Ajustes sem apagar")
	# passo 2: Sim
	var opcoes := _raiz() + "opcoes.cfg"
	Config.definir("musica", 0.7)
	var md5_opcoes := _md5(opcoes)
	p._executar("apagar", 0)
	p._executar("ok_apagar", 0)
	ok(not p.aberto and _apagou == 1, "Sim fecha o menu e avisa o santuário")
	ok(Personagens.lista().is_empty() and not _existe(s[0]) and not _existe(s[1]) and not _existe(Personagens.caminho_indice), "Sim apaga todo o progresso")
	ok(_md5(opcoes) == md5_opcoes, "as opções do jogador ficam")
	# na partida (mundo != null) a opção não existe: as almas dela ainda vão para o save
	p.mundo = self
	p.tela = "ajustes"
	ok(not p._itens().any(func(i): return i.id == "apagar"), "durante a partida a opção não aparece")
	p.mundo = null
	p.queue_free()
	await _frames()
	_limpar()
