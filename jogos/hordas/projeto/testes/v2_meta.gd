extends Node
# Teste automático da meta-progressão da v2 (v2/meta.gd, v2/altar.gd e v2/resultado_meta.gd). Usa um save TEMPORÁRIO
# (user://teste_v2_meta.cfg): o save real (user://v2_progresso.cfg) não é tocado, e a conferência por md5 garante isso.
# Confere: comprar desconta as almas e sobe o nível; sem almas não compra; o save é gravado no arquivo; aplicar muda a vida e o dano
# iniciais do herói no mundo de verdade; o marco de 5 min e o combo de 50 desbloqueiam a melhoria nova e marcam as conquistas;
# vencer marca o chefe; registrar a partida soma as almas (com o bônus) e guarda o resumo; o santuário monta uma linha por melhoria
# e por conquista, trava o que está bloqueado e atualiza o saldo ao comprar; e o resultado sobe as almas até o total.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_meta.tscn  (imprime "v2_meta falhas=0")
# Prints (precisa de janela, não de --headless): godot --path jogos/hordas/projeto res://testes/v2_meta.tscn -- --fotos=PASTA
#   grava santuario_sem_almas.png, santuario_com_almas.png, resultado_meio.png e resultado_fim.png (só o viewport) e sai.
const Meta := preload("res://v2/meta.gd")
const Mundo := preload("res://v2/mundo.tscn")
const Altar := preload("res://v2/altar.tscn")
const Resultado := preload("res://v2/resultado_meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const SAVE_TESTE := "user://teste_v2_meta.cfg"
const SAVE_CORRUPTO := "user://teste_v2_meta_corrupto.cfg"
const SAVE_FALHA := "user://teste_v2_meta_falha.cfg"
const SAVE_REAL := "user://v2_progresso.cfg"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
		_apagar_save()
		get_tree().quit()
		return
	await _testes()
	_apagar_save()
	print("v2_meta falhas=%d" % falhas)
	get_tree().quit()


func _apagar_save() -> void:
	_apagar_caminho(SAVE_TESTE)
	_apagar_caminho(SAVE_TESTE + ".tmp")
	_apagar_caminho(SAVE_TESTE + ".bak")


func _apagar_caminho(caminho: String) -> void:
	if FileAccess.file_exists(caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))


func _testes() -> void:
	var md5_real := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	_apagar_save()

	# 1. economia: sem almas não compra; com almas desconta e sobe o nível; o preço cresce a cada nível
	var vida := Meta.melhoria("vida")
	ok(Meta.saldo() == 0, "começa sem almas")
	ok(not Meta.comprar("vida"), "sem almas não compra")
	ok(Meta.nivel("vida") == 0, "sem compra o nível continua 0")
	ok(not FileAccess.file_exists(SAVE_TESTE), "comprar sem almas não cria save")
	Meta.creditar(100)
	ok(Meta.saldo() == 100, "creditar soma no saldo")
	ok(Meta.comprar("vida"), "com 100 almas compra o 1º nível de vida")
	ok(Meta.saldo() == 60, "o 1º nível custa 40 almas: sobram 60 (tem %d)" % Meta.saldo())
	ok(Meta.nivel("vida") == 1, "o nível sobe para 1")
	ok(Meta.custo_do_nivel(vida, 1) == 60, "o 2º nível custa 60")
	ok(Meta.comprar("vida") and Meta.saldo() == 0 and Meta.nivel("vida") == 2, "o 2º nível cabe com 60 almas e zera o saldo")
	ok(not Meta.comprar("vida"), "o 3º nível (90) não cabe com 0 almas")
	ok(Meta.nivel("vida") == 2, "a compra recusada não mexe no nível")

	# 2. o save é gravado no arquivo (lido de outro ConfigFile, como uma sessão nova faria)
	var cf := ConfigFile.new()
	ok(cf.load(SAVE_TESTE) == OK, "o save foi gravado no caminho de teste")
	ok(int(cf.get_value("moeda", "almas", -1)) == 0, "o saldo está no arquivo")
	ok(int(cf.get_value("melhorias", "vida", -1)) == 2, "o nível está no arquivo")
	ok(int(Meta.estado().niveis["vida"]) == 2 and int(Meta.estado().almas) == 0, "estado() relê o arquivo")

	# 3. aplicar: o mundo de verdade põe a vida e o dano iniciais (o mundo chama Meta.aplicar em _montar)
	var m = Mundo.instantiate()
	m.modo_teste = true
	add_child(m)
	m.set_process(false)
	var base_vida := float(m.combate.cfg.heroi.vida)
	ok(is_equal_approx(m.heroi.vida_max, base_vida + 20.0), "aplicar: vida máxima = base + 2 níveis (%s)" % str(m.heroi.vida_max))
	ok(is_equal_approx(m.heroi.vida, m.heroi.vida_max), "aplicar: a vida começa cheia")
	ok(is_equal_approx(m.heroi.m_dano, 1.0), "sem compra de dano o multiplicador fica em 1")
	Meta.creditar(200)
	ok(Meta.comprar("dano"), "compra o 1º nível de dano")
	Meta.aplicar(m)
	ok(is_equal_approx(m.heroi.m_dano, 1.06), "aplicar: dano inicial sobe 6%% (%s)" % str(m.heroi.m_dano))
	ok(m.meta_bonus.has("raridade") and m.meta_bonus.has("rolagem") and m.meta_bonus.has("almas"), "os bônus de raridade, rolagem e almas ficam em meta_bonus")
	m.queue_free()
	await get_tree().process_frame

	# 4. marcos: bloqueado até cumprir; 5 min e combo 50 marcam as conquistas e liberam a melhoria nova
	ok(not Meta.comprar("treino"), "melhoria travada (requer 5 min) não compra, mesmo com almas")
	ok(Meta.checar_ao_vivo(299.0, 49).is_empty(), "antes dos 5 min e do combo 50 nada é cumprido")
	var novas := Meta.checar_ao_vivo(300.0, 50)
	ok(novas.has("sobreviva_5min") and novas.has("combo_50"), "5 min e combo 50 cumprem as duas conquistas: %s" % str(novas))
	ok(bool(Meta.estado()["conquistas"]["sobreviva_5min"]), "a conquista de 5 min fica no save")
	ok(Meta.comprar("treino"), "o marco libera a melhoria nova (treino)")
	ok(Meta.nivel("treino") == 1, "o treino sobe para o nível 1")
	ok(Meta.checar_ao_vivo(400.0, 60).is_empty(), "conquista já cumprida não repete")

	# 5. fim da partida: as almas entram com o bônus, o resumo fica guardado, vencer marca o chefe
	var antes := Meta.saldo()
	var r := Meta.registrar_partida({"tempo": 320.0, "abates": 40, "nivel": 5, "maior_combo": 12, "venceu": false, "almas": 20})
	ok(int(r.ganhas) == 20 and int(r.antes) == antes and int(r.depois) == antes + 20, "a partida soma as almas que trouxe (+20)")
	ok(Meta.comprar("almas"), "compra o 1º nível de almas abundantes")
	r = Meta.registrar_partida({"tempo": 90.0, "abates": 7, "nivel": 2, "maior_combo": 3, "venceu": false, "almas": 100})
	ok(int(r.ganhas) == 108, "o bônus de almas (+8%%) entra: 100 viram 108 (%s)" % str(r.ganhas))
	var u: Dictionary = Meta.estado()["ultima"]
	ok(int(u.abates) == 7 and int(u.nivel) == 2 and int(u.ganhas) == 108, "o resumo da última partida fica no save")
	r = Meta.registrar_partida({"tempo": 600.0, "abates": 90, "nivel": 9, "maior_combo": 20, "venceu": true, "almas": 0})
	ok(bool(Meta.estado()["conquistas"]["derrota_chefe"]), "vencer marca a conquista do chefe")
	ok(not Meta.mapa_vencido("floresta") and Meta.mapas_vencidos().is_empty(), "vencer sem dizer o mapa não marca mapa nenhum")
	Meta.registrar_partida({"tempo": 10.0, "venceu": false, "almas": 0, "mapa": "floresta"})
	ok(not Meta.mapa_vencido("floresta"), "perder no mapa não o marca como vencido")
	Meta.registrar_partida({"tempo": 10.0, "venceu": true, "almas": 0, "mapa": "floresta"})
	ok(Meta.mapa_vencido("floresta") and not Meta.mapa_vencido("laboratorio"), "vencer o chefão da Floresta marca só a Floresta")
	ok(Meta.marcar_mapa_vencido("laboratorio") and Meta.mapa_vencido("laboratorio"), "marcar_mapa_vencido grava direto")
	ok(Meta.mapas_vencidos().size() == 2 and not Meta.marcar_mapa_vencido(""), "lista de vencidos e id vazio recusado")

	# 6. santuário: uma linha por melhoria e conquista, bloqueio, saldo na tela, compra pelo botão e o máximo
	_apagar_save()
	var a = Altar.instantiate()
	add_child(a)
	await get_tree().process_frame
	ok(a._linhas.size() == Meta.melhorias_visiveis().size(), "uma linha por melhoria visível no santuário")
	ok(a._conq.size() == Meta.conquistas().size(), "uma linha por conquista no santuário")
	# 6b. Pesadelo e Rastro de katana têm efeito: aparecem no santuário (sem "sem efeito ainda"), os botões só surgem com a conquista
	#     cumprida e ligam e desligam; o item marcado com oculta_ate_ter_efeito segue escondido (a regra geral continua valendo)
	var modo_pesadelo := Meta.item_da_recompensa({"tipo": "modo", "id": "pesadelo"})
	var visual_rastro := Meta.item_da_recompensa({"tipo": "visual", "id": "rastro_katana"})
	ok(not Meta.oculto(modo_pesadelo) and not Meta.oculto(visual_rastro), "pesadelo e rastro de katana não estão mais escondidos")
	ok(str(modo_pesadelo.get("efeito", "")) != "pendente" and str(visual_rastro.get("efeito", "")) != "pendente", "nenhum dos dois tem efeito pendente")
	ok(
		not Meta.oculto(Meta.melhoria("raridade")) and not Meta.oculto(Meta.melhoria("rolagem")) and not Meta.oculto(Meta.melhoria("almas")),
		"raridade, rolagem e almas têm efeito e seguem visíveis"
	)
	a._atualizar()
	ok(
		a._conq["derrota_chefe"].rec.text == "Libera: modo Pesadelo" and a._conq["combo_50"].rec.text == "Libera: Rastro de katana",
		"a recompensa volta ao santuário, sem aviso de efeito pendente (%s / %s)" % [a._conq["derrota_chefe"].rec.text, a._conq["combo_50"].rec.text]
	)
	ok(a._conq["combo_50"].nome.text == "Combo de cinquenta", "a conquista segue na lista")
	ok(not a._modo_btn.visible and not a._rastro_btn.visible, "sem as conquistas os botões de Pesadelo e Rastro ficam escondidos")
	ok(not Meta.ligar("modo", "pesadelo", true) and not Meta.ligar("visual", "rastro_katana", true), "sem a conquista não liga")
	Meta.registrar_partida({"tempo": 10.0, "maior_combo": 50, "venceu": true})
	a._atualizar()
	ok(a._modo_btn.visible and a._rastro_btn.visible, "com as conquistas cumpridas os botões aparecem")
	ok(
		a._modo_btn.text == "PESADELO: DESLIGADO" and a._rastro_btn.text == "RASTRO: DESLIGADO",
		"começam desligados (%s / %s)" % [a._modo_btn.text, a._rastro_btn.text]
	)
	ok(
		a._modo_btn.get_minimum_size().x <= a._modo_btn.size.x and a._rastro_btn.get_minimum_size().x <= a._rastro_btn.size.x,
		"o texto dos botões cabe (%s)" % a._modo_btn.get_minimum_size()
	)
	a._modo_btn.pressed.emit()
	a._rastro_btn.pressed.emit()
	ok(Meta.ligado("modo", "pesadelo") and Meta.ligado("visual", "rastro_katana"), "clicar liga e grava no save")
	ok(
		a._modo_btn.text == "PESADELO: LIGADO" and a._detalhe.text.contains("Rastro de katana"),
		"o botão mostra o modo ligado e o detalhe, o último item tocado"
	)
	a._modo_btn.pressed.emit()
	ok(not Meta.ligado("modo", "pesadelo") and Meta.ligado("visual", "rastro_katana"), "clicar de novo desliga só o modo")
	Meta.ligar("visual", "rastro_katana", false)
	modo_pesadelo["oculta_ate_ter_efeito"] = true
	visual_rastro["oculta_ate_ter_efeito"] = true
	a._atualizar()
	ok(
		a._conq["derrota_chefe"].rec.text == "" and a._conq["combo_50"].rec.text == "",
		"item marcado como escondido some do santuário (%s / %s)" % [a._conq["derrota_chefe"].rec.text, a._conq["combo_50"].rec.text]
	)
	modo_pesadelo.erase("oculta_ate_ter_efeito")
	visual_rastro.erase("oculta_ate_ter_efeito")
	a._atualizar()
	var mel_vida := Meta.melhoria("vida")
	mel_vida["oculta_ate_ter_efeito"] = true
	ok(
		Meta.melhorias_visiveis().size() == Meta.melhorias().size() - 1 and not Meta.melhorias_visiveis().has(mel_vida),
		"melhoria marcada sai da lista do santuário e do card"
	)
	mel_vida.erase("oculta_ate_ter_efeito")
	ok(Meta.melhorias_visiveis().size() == Meta.melhorias().size(), "sem a flag a melhoria volta à lista")
	ok(a._linhas["treino"].botao.disabled and a._linhas["treino"].botao.text == "BLOQUEADA", "o treino aparece bloqueado sem o marco")
	ok(not a._linhas["vida"].botao.disabled, "vida (liberada) aparece comprável")
	Meta.creditar(500)
	a._atualizar()
	a._comprar("vida")
	ok(Meta.nivel("vida") == 1 and a._saldo.text == "460", "comprar no santuário sobe o nível e o saldo da tela acompanha (%s)" % a._saldo.text)
	ok(a._linhas["vida"].botao.text == "COMPRAR 60", "o botão mostra o preço do próximo nível")
	a._comprar("treino")
	ok(a._status.text.begins_with("Bloqueada"), "tentar comprar o bloqueado avisa o motivo")
	Meta.creditar(10000)
	for i in 4:
		a._comprar("vida")
	ok(Meta.nivel("vida") == 5 and a._linhas["vida"].botao.disabled and a._linhas["vida"].botao.text == "MÁXIMO", "no máximo o botão vira MÁXIMO e trava")
	a._comprar("vida")
	ok(a._status.text == "Nível máximo", "comprar no máximo avisa")
	a.queue_free()
	await get_tree().process_frame

	# 7. resultado: as almas sobem até o total e entram no saldo; antes de 0,8 s o toque não sai da tela
	var m2 = Mundo.instantiate()
	m2.modo_teste = true
	add_child(m2)
	m2.set_process(false)
	var res = Resultado.new()
	res.montar(m2)
	var saldo_antes := Meta.saldo()
	res._terminar({"tempo": 125.0, "abates": 30, "nivel": 4, "maior_combo": 9, "venceu": false, "almas": 30})
	ok(res.aberto and res._ganhas == 30, "a tela abre com as almas da partida (save zerado: sem bônus, 30; tem %d)" % res._ganhas)
	ok(Meta.saldo() == saldo_antes + res._ganhas, "o resultado grava as almas no saldo")
	res._animar(0.2)
	ok(res._almas_num.text != "+%d" % res._ganhas, "no começo a animação ainda não chegou ao total")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	res.entrada(ev)
	ok(not res._saindo, "clique logo no começo não sai do resultado")
	res._animar(2.0)
	ok(res._almas_num.text == "+%d" % res._ganhas, "a animação termina no total: %s" % res._almas_num.text)
	ok(res._saldo.text == "Saldo: %d" % Meta.saldo(), "o saldo na tela bate com o save")
	res._terminou = true  # garante que nada mais grava nesta tela
	m2.queue_free()
	await get_tree().process_frame

	# 8. sem o sinal do mundo: a conquista de tempo é gravada no meio da partida, e a tela com as almas abre sozinha
	#    quando a tela de resultado (telas.gd) abre, que é quando o herói cai
	_apagar_save()
	var m3 = Mundo.instantiate()
	m3.modo_teste = true
	add_child(m3)
	m3.set_process(false)
	var r3 = Resultado.new()
	r3.montar(m3)
	m3.add_child(r3)
	m3.tempo_partida = 302.0
	await _frames(2)
	ok(bool(Meta.estado()["conquistas"]["sobreviva_5min"]), "a conquista de 5 min é gravada no meio da partida, sem esperar o fim")
	ok(not r3.aberto, "no meio da partida a tela de resultado não abre")
	m3.combate.telas.mostrar_resultado()
	await _frames(2)
	ok(r3.aberto and r3._terminou, "a tela com as almas abre sozinha quando a tela de resultado abre")
	ok(int(Meta.estado()["ultima"]["tempo"]) == 302, "o resumo da partida é gravado pelo caminho sem sinal")
	m3.queue_free()
	await get_tree().process_frame

	# 9. save corrompido recupera o backup e não troca o arquivo corrompido por um save vazio
	_apagar_caminho(SAVE_CORRUPTO)
	_apagar_caminho(SAVE_CORRUPTO + ".bak")
	var arquivo_corrupto := FileAccess.open(SAVE_CORRUPTO, FileAccess.WRITE)
	arquivo_corrupto.store_string("[moeda\nisto não é um ConfigFile\n")
	arquivo_corrupto.close()
	var backup_cfg := ConfigFile.new()
	backup_cfg.set_value("moeda", "almas", 77)
	backup_cfg.set_value("melhorias", "vida", 1)
	ok(backup_cfg.save(SAVE_CORRUPTO + ".bak") == OK, "prepara backup válido do save corrompido")
	Meta.caminho_save = SAVE_CORRUPTO
	ok(Meta.saldo() == 77 and Meta.nivel("vida") == 1, "save corrompido recupera saldo e melhoria do .bak")
	Meta.creditar(10)
	ok(not Meta.erro_save and Meta.saldo() == 87, "save recuperado aceita gravação mantendo o backup")
	ok(FileAccess.file_exists(SAVE_CORRUPTO + ".bak"), "a recuperação mantém o .bak disponível")

	# 10. falha ao criar temporário: comprar e registrar_partida propagam falha sem ganho
	_apagar_caminho(SAVE_FALHA)
	_apagar_caminho(SAVE_FALHA + ".bak")
	var inicial := ConfigFile.new()
	inicial.set_value("moeda", "almas", 100)
	ok(inicial.save(SAVE_FALHA) == OK, "prepara saldo para simular falha de gravação")
	var temp_como_pasta := ProjectSettings.globalize_path(SAVE_FALHA + ".tmp")
	ok(DirAccess.make_dir_recursive_absolute(temp_como_pasta) == OK, "bloqueia o caminho do temporário como pasta")
	Meta.caminho_save = SAVE_FALHA
	ok(not Meta.comprar("vida") and Meta.erro_save, "compra devolve falha se não consegue gravar")
	ok(Meta.saldo() == 100 and Meta.nivel("vida") == 0, "compra que falhou não persiste saldo nem nível")
	var altar_falha = Altar.instantiate()
	add_child(altar_falha)
	await get_tree().process_frame
	altar_falha._comprar("vida")
	ok(altar_falha._status.text == "Não foi possível salvar", "o santuário informa falha de gravação em vez de anunciar o nível")
	altar_falha.queue_free()
	await get_tree().process_frame
	ok(Meta.checar_ao_vivo(300.0, 50).is_empty() and Meta.erro_save, "conquista sem gravação não é anunciada como concluída")
	var r_falha := Meta.registrar_partida({"tempo": 60.0, "abates": 2, "nivel": 2, "maior_combo": 3, "venceu": false, "almas": 50})
	ok(r_falha.is_empty() and Meta.erro_save, "registrar_partida devolve resultado vazio se não consegue gravar")
	ok(Meta.saldo() == 100 and Meta.estado().ultima.is_empty(), "partida que falhou não mostra nem persiste almas ou resumo")
	var mundo_falha = Mundo.instantiate()
	mundo_falha.modo_teste = true
	add_child(mundo_falha)
	var resultado_falha = Resultado.new()
	resultado_falha.montar(mundo_falha)
	resultado_falha._terminar({"tempo": 60.0, "abates": 2, "nivel": 2, "maior_combo": 3, "venceu": false, "almas": 50})
	ok(resultado_falha.aberto and resultado_falha._ganhas == 0, "resultado não anima almas quando o save falha")
	ok(resultado_falha._almas_tit.text == "NÃO FOI POSSÍVEL SALVAR", "resultado identifica a falha de gravação")
	mundo_falha.queue_free()
	await get_tree().process_frame

	# 11. sem backup, corrupção bloqueia gravações e preserva os bytes originais
	_apagar_caminho(SAVE_CORRUPTO)
	var sem_backup := FileAccess.open(SAVE_CORRUPTO, FileAccess.WRITE)
	sem_backup.store_string("[section")
	sem_backup.close()
	var conteudo_sem_backup := FileAccess.get_file_as_string(SAVE_CORRUPTO)
	_apagar_caminho(SAVE_CORRUPTO + ".bak")
	ok(not FileAccess.file_exists(SAVE_CORRUPTO + ".bak"), "remove o backup antes de testar corrupção sem backup")
	Meta.caminho_save = SAVE_CORRUPTO
	Meta.creditar(500)
	ok(Meta.erro_save, "corrupção sem backup bloqueia a gravação")
	ok(FileAccess.get_file_as_string(SAVE_CORRUPTO) == conteudo_sem_backup, "corrupção sem backup nunca é substituída por save vazio")
	ok(not Mapas.escolher("laboratorio") and Meta.erro_save, "escolha de mapa propaga falha no mesmo save")
	ok(Mapas.escolhido() == Mapas.PADRAO, "falha ao salvar mapa não altera a escolha")
	Meta.caminho_save = SAVE_TESTE
	_apagar_caminho(SAVE_CORRUPTO)
	_apagar_caminho(SAVE_CORRUPTO + ".bak")
	_apagar_caminho(SAVE_FALHA)
	_apagar_caminho(SAVE_FALHA + ".bak")
	DirAccess.remove_absolute(temp_como_pasta)

	# o save real não foi tocado por este teste
	var md5_depois := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	ok(md5_depois == md5_real, "o save real (user://v2_progresso.cfg) não foi alterado")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto_janela(caminho: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(caminho)
	print("FOTO ", caminho)


func _fotos(pasta: String) -> void:
	# santuário sem almas (save vazio)
	_apagar_save()
	var a = Altar.instantiate()
	add_child(a)
	await _frames(3)
	await _foto_janela(pasta.path_join("santuario_sem_almas.png"))
	a.queue_free()
	await get_tree().process_frame

	# santuário com almas, algumas melhorias compradas e o treino liberado
	Meta.creditar(300)
	Meta.comprar("vida")
	Meta.comprar("vida")
	Meta.comprar("dano")
	Meta.comprar("ima")
	Meta.comprar("folego")
	Meta.checar_ao_vivo(300.0, 50)
	Meta.creditar(120)
	Meta.comprar("treino")
	Meta.registrar_partida({"tempo": 212.0, "abates": 44, "nivel": 6, "maior_combo": 17, "venceu": false, "almas": 0})
	a = Altar.instantiate()
	add_child(a)
	await _frames(3)
	await _foto_janela(pasta.path_join("santuario_com_almas.png"))
	a.queue_free()
	await get_tree().process_frame

	# resultado com as almas subindo: no meio da animação e no fim
	var m = Mundo.instantiate()
	m.modo_teste = false
	add_child(m)
	m.set_process(false)
	await _frames(2)
	var res = m.meta_res
	if res == null:  # sem a tela do mundo (não deveria acontecer fora do modo de teste)
		res = Resultado.new()
		res.montar(m)
		m.ui.add_child(res)
	res._terminar({"tempo": 412.0, "abates": 58, "nivel": 8, "maior_combo": 34, "venceu": false, "almas": 46})
	await get_tree().create_timer(0.55).timeout
	await m.ap.foto(pasta.path_join("resultado_meio.png"))
	await get_tree().create_timer(1.6).timeout
	await m.ap.foto(pasta.path_join("resultado_fim.png"))
	res._terminou = true
	m.queue_free()
	await get_tree().process_frame
