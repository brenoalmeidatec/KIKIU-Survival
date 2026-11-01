extends "res://testes/isolamento_v2.gd"
# Teste das travas do santuário (v2/progressao.gd, dados/v2_progressao.json, v2/mapas.gd e o salão). Saves TEMPORÁRIOS com prefixo
# único; os saves reais (user://v2_*) são conferidos por md5 no fim.
# Confere: um personagem novo só tem a Floresta e as Estátuas abertas; vencer a Floresta abre o Laboratório e o Altar, e vencer outro
# mapa não abre o Laboratório; a 1ª conquista abre o Códice e o Altar só abre vencendo a Floresta (partidas sozinhas não abrem nada); um save de antes das travas com
# progresso NÃO fica com tudo aberto: segue as travas e mantém só o que conquistou (Derrote o chefe vale como Vença a Floresta, mapa
# vencido fica aberto) e ganha a marca de versão na próxima gravação; um slot novo não vira "antigo" depois de gravar; no
# salão, portal e estrutura trancados mostram a trava, o prompt diz "Trancado" e Enter só avisa.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_progressao.tscn  (imprime "v2_progressao falhas=0")
# Fotos (com janela): godot --path jogos/hordas/projeto res://testes/v2_progressao.tscn -- --prints=<pasta>

const Personagens := preload("res://v2/personagens.gd")
const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const Progressao := preload("res://v2/progressao.gd")
const Salao := preload("res://v2/salao.tscn")

var falhas := 0
var pasta := ""
var prefixo := ""
var reais := {}
var fim := false  # um erro de script no meio para o teste: sem isto ele sairia com falhas=0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prints="):
			pasta = arg.trim_prefix("--prints=")
	prefixo = "teste_progressao_%d_" % Time.get_ticks_usec()
	var d := DirAccess.open("user://testes_v2/v2_progressao/")
	for arquivo in d.get_files():
		if arquivo.begins_with("v2_"):
			reais[arquivo] = FileAccess.get_md5("user://testes_v2/v2_progressao/" + arquivo)
	Personagens.caminho_indice = "user://testes_v2/v2_progressao/" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://testes_v2/v2_progressao/" + prefixo + "p"
	Personagens.caminho_antigo = "user://testes_v2/v2_progressao/" + prefixo + "antigo.cfg"
	Meta.caminho_save = "user://testes_v2/v2_progressao/" + prefixo + "meta.cfg"
	if pasta != "":
		DisplayServer.window_set_size(Vector2i(960, 540))
	await _testes()
	ok(fim, "o teste chegou ao fim")
	for arquivo in reais:
		ok(FileAccess.get_md5("user://testes_v2/v2_progressao/" + arquivo) == reais[arquivo], "save real intacto " + arquivo)
	for arquivo in d.get_files():
		if arquivo.begins_with(prefixo):
			d.remove(arquivo)
	print("v2_progressao falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func _novo(nome: String) -> String:
	var id := Personagens.criar(nome)
	ok(Personagens.ativar(id), "ativa o personagem " + nome)
	return id


func _partida(venceu: bool, mapa: String) -> Dictionary:
	return Meta.registrar_partida({"tempo": 30.0, "abates": 3, "nivel": 2, "maior_combo": 2, "venceu": venceu, "almas": 5, "mapa": mapa})


func _abertos() -> Array:
	return Mapas.ids().filter(func(id): return Mapas.condicao(Mapas.buscar(id)) == "")


func _testes() -> void:
	# 1. personagem novo: só a Floresta e as Estátuas
	_novo("Breno")
	ok(_abertos() == ["floresta"], "personagem novo: só a Floresta aberta (%s)" % str(_abertos()))
	ok(Progressao.aberto("estrutura", "estatuas"), "Estátuas abertas desde o começo")
	ok(not Progressao.aberto("estrutura", "altar") and not Progressao.aberto("estrutura", "codice"), "Altar e Códice trancados no começo")
	ok(Mapas.condicao(Mapas.buscar("laboratorio")).begins_with("Trancado"), "o texto do portal trancado começa com Trancado")
	ok(
		Mapas.curto(Mapas.buscar("laboratorio")) == "Vença a Floresta ou 300 almas",
		"linha do cadeado do Laboratório (%s)" % Mapas.curto(Mapas.buscar("laboratorio"))
	)
	ok(Mapas.curto(Mapas.buscar("floresta")) == "", "a Floresta não tem linha de cadeado")
	ok(Progressao.curto("estrutura", "altar") == "Vença a Floresta", "linha do Altar (%s)" % Progressao.curto("estrutura", "altar"))
	ok(Progressao.curto("estrutura", "codice") == "1 conquista", "linha do Códice (%s)" % Progressao.curto("estrutura", "codice"))
	ok(Progressao.aviso("estrutura", "codice").find("(0/1)") > 0, "o aviso do Códice mostra quanto falta (%s)" % Progressao.aviso("estrutura", "codice"))

	# 2. salão de um personagem novo: trava no desenho, no prompt e no Enter
	var s = Salao.instantiate()
	add_child(s)
	s.ao_entrar = func(_cena): ok(false, "portal trancado não pode levar à partida")
	await get_tree().process_frame
	await get_tree().process_frame
	await foto("01_novo")
	var por_id := {}
	for a in s._alvos:
		por_id[str(a.id)] = a
	ok(str(por_id.laboratorio.trava) == "Vença a Floresta ou 300 almas" and str(por_id.floresta.trava) == "", "o alvo do portal leva a linha do cadeado")
	ok(str(por_id.altar.trava) != "" and str(por_id.estatuas.trava) == "", "o alvo da estrutura leva a linha do cadeado")
	ok(not s.usar_portal("laboratorio"), "portal trancado não entra")
	ok(s._aviso_lbl.text.begins_with("Trancado"), "Enter no portal trancado avisa (%s)" % s._aviso_lbl.text)
	s.abrir_estrutura("altar")
	ok(not s._painel.visible, "estrutura trancada não abre o painel")
	ok(s._aviso_lbl.text.begins_with("Altar trancado"), "estrutura trancada avisa (%s)" % s._aviso_lbl.text)
	s._pos = por_id.altar.pos.clamp(s.ANDAR_MIN, s.ANDAR_MAX)
	s._atualizar_prompt()
	ok(s._prompt.text.begins_with("Trancado: "), "o prompt perto do trancado diz Trancado (%s)" % s._prompt.text)
	await foto("02_aviso_altar")
	s._aviso_t = 0.0
	s._pos = por_id.medio.pos.clamp(s.ANDAR_MIN, s.ANDAR_MAX)
	s._atualizar_prompt()
	ok(not s.usar_portal("medio"), "as Ruínas trancadas não entram")
	await foto("03_aviso_ruinas")
	s.abrir_estrutura("estatuas")
	ok(s._painel.visible, "Estátuas abrem o painel")
	s._fechar_painel()
	s.queue_free()
	await get_tree().process_frame

	# 3. vencer OUTRO mapa não abre o Laboratório; morrer na Floresta também não
	_novo("Luke")
	_partida(true, "cidade")
	_partida(false, "floresta")
	ok(not _abertos().has("laboratorio"), "vencer a Cidade (ou morrer na Floresta) não abre o Laboratório")

	# 4. vencer a Floresta abre o Laboratório e o Altar (e só eles)
	_novo("Matthew")
	var r := _partida(true, "floresta")
	ok(r.get("novas", []).has("vence_floresta"), "vencer a Floresta cumpre vence_floresta (%s)" % str(r.get("novas", [])))
	ok(_abertos() == ["floresta", "laboratorio"], "vencer a Floresta abre o Laboratório (%s)" % str(_abertos()))
	ok(Progressao.aberto("estrutura", "altar"), "vencer a Floresta abre o Altar")
	ok(Progressao.aberto("estrutura", "codice"), "a 1ª conquista abre o Códice")
	ok(str(Meta.estado().ultima.get("mapa", "")) == "floresta", "o resumo guarda o mapa da última partida")
	_partida(true, "laboratorio")
	ok(_abertos() == ["floresta", "laboratorio", "cidade"], "vencer o Laboratório abre a Cidade")
	_partida(true, "cidade")
	ok(_abertos() == Mapas.ids(), "vencer a Cidade abre as Ruínas (todos abertos)")
	var s2 = Salao.instantiate()
	add_child(s2)
	await get_tree().process_frame
	await get_tree().process_frame
	await foto("04_tudo_aberto")
	ok(s2._alvos.all(func(a): return str(a.trava) == ""), "com tudo vencido nenhum alvo tem cadeado")
	s2.queue_free()
	await get_tree().process_frame

	# 5. partidas sozinhas (sem vitória nem conquista) não abrem nada, mas ficam contadas no save
	_novo("João")
	for i in 5:
		_partida(false, "floresta")
	ok(Progressao.partidas() == 5, "o save conta as partidas (%d)" % Progressao.partidas())
	ok(not Progressao.aberto("estrutura", "codice") and not Progressao.aberto("estrutura", "altar"), "5 partidas sem conquista não abrem Altar nem Códice")
	ok(not _abertos().has("laboratorio"), "partidas não abrem mapas")

	# 6. save de antes das travas, com progresso mas SEM vitória: segue as travas (não fica "tudo aberto" por ser velho)
	var antigo := "user://testes_v2/v2_progressao/" + prefixo + "legado.cfg"
	var cf := ConfigFile.new()
	cf.set_value("moeda", "almas", 120)
	cf.set_value("melhorias", "vida", 1)
	cf.set_value("ultima", "tempo", 50.0)
	cf.save(antigo)
	Meta.caminho_save = antigo
	ok(_abertos() == ["floresta"], "save antigo sem vitória: só a Floresta aberta (%s)" % str(_abertos()))
	ok(not Progressao.aberto("estrutura", "altar"), "save antigo sem vitória: Altar trancado")
	Meta.creditar(1)
	var gravado := ConfigFile.new()
	gravado.load(antigo)
	ok(int(gravado.get_value("progressao", "versao", 0)) == Meta.VERSAO_PROGRESSAO, "a gravação persiste a versão")
	ok(not gravado.has_section_key("progressao", "legado"), "a gravação não grava legado")
	_partida(false, "floresta")
	ok(_abertos() == ["floresta"], "depois de uma partida sem vitória o save antigo continua com as travas")
	# 6b. o que o save antigo já conquistou continua conquistado: Derrote o chefe (de antes dos mapas) vale como Vença a Floresta
	var com_chefe := "user://testes_v2/v2_progressao/" + prefixo + "legado_chefe.cfg"
	var cc := ConfigFile.new()
	cc.set_value("moeda", "almas", 300)
	cc.set_value("conquistas", "derrota_chefe", true)
	cc.save(com_chefe)
	Meta.caminho_save = com_chefe
	ok(_abertos() == ["floresta", "laboratorio"], "save antigo que derrotou o chefe: Laboratório aberto (%s)" % str(_abertos()))
	ok(Progressao.aberto("estrutura", "altar") and Progressao.aberto("estrutura", "codice"), "save antigo que derrotou o chefe: Altar e Códice abertos")
	# 6c. save antigo que já tinha o save com legado = true gravado pelo #333: a marca é ignorada e apagada
	var com_marca := "user://testes_v2/v2_progressao/" + prefixo + "legado_marca.cfg"
	var cm := ConfigFile.new()
	cm.set_value("progressao", "versao", 1)
	cm.set_value("progressao", "legado", true)
	cm.set_value("moeda", "almas", 500)
	cm.set_value("conquistas", "vence_cidade", true)
	cm.save(com_marca)
	Meta.caminho_save = com_marca
	ok(
		_abertos() == ["floresta", "cidade", "medio"],
		"legado=true de antes é ignorado: a Cidade já vencida fica aberta e abre as Ruínas (%s)" % str(_abertos())
	)
	ok(not Progressao.aberto("estrutura", "altar"), "legado=true de antes é ignorado: Altar segue trancado sem vencer a Floresta")
	Meta.creditar(1)
	var limpo := ConfigFile.new()
	limpo.load(com_marca)
	ok(
		not limpo.has_section_key("progressao", "legado") and int(limpo.get_value("progressao", "versao", 0)) == Meta.VERSAO_PROGRESSAO,
		"a marca legado some na próxima gravação"
	)

	# 7. save antigo SEM progresso (só a escolha de mapa) não vira legado
	var vazio := "user://testes_v2/v2_progressao/" + prefixo + "vazio.cfg"
	var cv := ConfigFile.new()
	cv.set_value("config", "mapa", "cidade")
	cv.save(vazio)
	Meta.caminho_save = vazio
	ok(_abertos() == ["floresta"], "save sem progresso segue as travas")

	# 8. slot novo: a 1ª gravação marca versão sem legado, e a 1ª partida não o torna antigo
	_novo("Beto")
	Meta.creditar(10)
	_partida(false, "floresta")
	var slot := ConfigFile.new()
	slot.load(Meta.caminho_save)
	ok(not slot.has_section_key("progressao", "legado"), "slot novo não tem a marca de save antigo")
	ok(_abertos() == ["floresta"], "slot novo depois de uma partida: só a Floresta")
	# 9. mapa vencido: marcar_mapa_vencido marca a conquista vence_<mapa> no cf (quem grava é o chamador); a trava lê o mesmo save
	_novo("Mapa")
	ok(not Meta.mapa_vencido("floresta"), "mapa_vencido: personagem novo não tem mapa vencido")
	var mv := Meta._ler()
	ok(Meta.marcar_mapa_vencido("floresta", mv), "marcar_mapa_vencido marca a Floresta no cf")
	ok(not Meta.marcar_mapa_vencido("floresta", mv), "marcar_mapa_vencido de novo não marca (já vencida)")
	ok(not Meta.marcar_mapa_vencido("", mv), "marcar_mapa_vencido recusa id vazio")
	ok(not Meta.mapa_vencido("floresta"), "sem gravar, o save segue sem a Floresta vencida")
	ok(Meta._gravar(mv), "grava o save com a Floresta vencida")
	ok(Meta.mapa_vencido("floresta") and not Meta.mapa_vencido("cidade"), "depois de gravar: a Floresta vencida e a Cidade não")
	ok(_abertos() == ["floresta", "laboratorio"], "o mapa vencido pela função abre o Laboratório (%s)" % str(_abertos()))
	# 10. vitória pelo caminho real do combate: grava antes da tela de resultado, abre o portal e ainda anuncia a conquista.
	_novo("Chefe")
	var nova := Meta.marcar_mapa_vencido("floresta")
	ok(nova and _abertos() == ["floresta", "laboratorio"], "a vitória grava direto e abre o Laboratório antes do resultado")
	var resultado := Meta.registrar_partida({"venceu": true, "mapa": "floresta", "mapa_vencido_agora": nova})
	ok(resultado.novas.count("vence_floresta") == 1, "a conquista da vitória aparece uma vez no resultado")
	ok(Progressao.aberto("estrutura", "altar") and Progressao.aberto("estrutura", "codice"), "vitória direta abre Altar e Códice")
	# 11. saves da frente de níveis: migra [mapas_vencidos], inclusive quando a versão da progressão já existe.
	_novo("Migração")
	var antigo_niveis := Meta._ler()
	antigo_niveis.set_value("mapas_vencidos", "floresta", true)
	antigo_niveis.set_value("mapas_vencidos", "cidade", false)
	Meta._gravar(antigo_niveis)
	ok(Meta.mapa_vencido("floresta") and not Meta.mapa_vencido("cidade"), "a leitura migra só os mapas vencidos")
	ok(bool(Meta.estado().conquistas.vence_floresta), "o Códice lê a mesma conquista migrada")
	ok(_abertos() == ["floresta", "laboratorio"], "o mapa migrado abre o próximo sem transformar o slot em legado")
	Meta.creditar(1)
	var migrado := ConfigFile.new()
	migrado.load(Meta.caminho_save)
	ok(not migrado.has_section("mapas_vencidos") and bool(migrado.get_value("conquistas", "vence_floresta", false)), "grava só o estado canônico")
	# 12. as melhorias do Altar abrem pelos mapas vencidos: Olho para o raro (Laboratório), com o requisito escrito
	_novo("Altar")
	Meta.creditar(2000)
	ok(Meta.marcar_mapa_vencido("floresta"), "12: vence a Floresta")
	ok(Meta.comprar("ima") and Meta.comprar("almas"), "12: com o Altar aberto, Ímã e Almas abundantes compram")
	ok(not Meta.comprar("raridade") and Meta.nivel("raridade") == 0, "12: Olho para o raro segue trancada sem vencer o Laboratório")
	ok(not Meta.comprar("rolagem") and Meta.nivel("rolagem") == 0, "12: a Segunda chance saiu do jogo (não existe mais para comprar)")
	var s3 = Salao.instantiate()
	add_child(s3)
	await get_tree().process_frame
	s3.abrir_estrutura("altar")
	var pos_rar := -1
	for i in s3._p_itens.size():
		if str(s3._p_itens[i].id) == "raridade":
			pos_rar = i
	ok(pos_rar >= 0, "12: o Altar lista Olho para o raro mesmo trancada (não some)")
	s3._p_atual = pos_rar
	s3._mostrar_item(pos_rar)
	ok(s3._p_comprar.text == "BLOQUEADA" and s3._p_comprar.disabled, "12: o botão diz BLOQUEADA (%s)" % s3._p_comprar.text)
	ok(
		s3._motivo_recusa(s3._p_itens[pos_rar]) == "Falta a conquista: Vença a Torre do Alquimista",
		"12: o motivo escreve o requisito (%s)" % s3._motivo_recusa(s3._p_itens[pos_rar])
	)
	await foto("05_altar_melhoria_trancada")
	s3.queue_free()
	await get_tree().process_frame
	ok(Meta.marcar_mapa_vencido("laboratorio") and Meta.comprar("raridade"), "12: vencer o Laboratório libera Olho para o raro")
	ok(Meta.marcar_mapa_vencido("cidade") and not Meta.comprar("rolagem"), "12: vencer a Cidade não traz a Segunda chance de volta")
	fim = true


func foto(nome: String) -> void:
	if pasta.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join("progressao_" + nome + ".png"))
