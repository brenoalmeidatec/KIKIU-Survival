extends Node
# Teste das travas do santuário (v2/progressao.gd, dados/v2_progressao.json, v2/mapas.gd e o salão). Saves TEMPORÁRIOS com prefixo
# único; os saves reais (user://v2_*) são conferidos por md5 no fim.
# Confere: um personagem novo só tem a Floresta e as Estátuas abertas; vencer a Floresta abre o Laboratório e o Altar, e vencer outro
# mapa não abre o Laboratório; 3 partidas (ou 1 conquista) abrem o Códice e 5 partidas o Altar; um save de antes das travas com
# progresso fica com tudo aberto e ganha a marca de versão na próxima gravação; um slot novo não vira "antigo" depois de gravar; no
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
	var d := DirAccess.open("user://")
	for arquivo in d.get_files():
		if arquivo.begins_with("v2_"):
			reais[arquivo] = FileAccess.get_md5("user://" + arquivo)
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	Meta.caminho_save = "user://" + prefixo + "meta.cfg"
	if pasta != "":
		DisplayServer.window_set_size(Vector2i(960, 540))
	await _testes()
	ok(fim, "o teste chegou ao fim")
	for arquivo in reais:
		ok(FileAccess.get_md5("user://" + arquivo) == reais[arquivo], "save real intacto " + arquivo)
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
	ok(Mapas.condicao(Mapas.buscar("laboratorio")).begins_with("Fechado"), "o texto do portal trancado começa com Fechado")
	ok(Mapas.curto(Mapas.buscar("laboratorio")) == "Vença a Floresta", "linha do cadeado do Laboratório (%s)" % Mapas.curto(Mapas.buscar("laboratorio")))
	ok(Mapas.curto(Mapas.buscar("floresta")) == "", "a Floresta não tem linha de cadeado")
	ok(Progressao.curto("estrutura", "altar") == "Vença a Floresta ou 5 partidas", "linha do Altar (%s)" % Progressao.curto("estrutura", "altar"))
	ok(Progressao.curto("estrutura", "codice") == "1 conquista ou 3 partidas", "linha do Códice (%s)" % Progressao.curto("estrutura", "codice"))
	ok(Progressao.aviso("estrutura", "altar").find("(0/5)") > 0, "o aviso do Altar mostra quanto falta (%s)" % Progressao.aviso("estrutura", "altar"))

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
	ok(str(por_id.laboratorio.trava) == "Vença a Floresta" and str(por_id.floresta.trava) == "", "o alvo do portal leva a linha do cadeado")
	ok(str(por_id.altar.trava) != "" and str(por_id.estatuas.trava) == "", "o alvo da estrutura leva a linha do cadeado")
	ok(not s.usar_portal("laboratorio"), "portal trancado não entra")
	ok(s._aviso_lbl.text.begins_with("Fechado"), "Enter no portal trancado avisa (%s)" % s._aviso_lbl.text)
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
	_novo("Lucas")
	_partida(true, "cidade")
	_partida(false, "floresta")
	ok(not _abertos().has("laboratorio"), "vencer a Cidade (ou morrer na Floresta) não abre o Laboratório")

	# 4. vencer a Floresta abre o Laboratório e o Altar (e só eles)
	_novo("Matheus")
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

	# 5. partidas: 3 abrem o Códice, 5 abrem o Altar (sem conquista nenhuma)
	_novo("João")
	for i in 3:
		_partida(false, "floresta")
	ok(Progressao.partidas() == 3, "o save conta as partidas (%d)" % Progressao.partidas())
	ok(Progressao.aberto("estrutura", "codice") and not Progressao.aberto("estrutura", "altar"), "3 partidas abrem o Códice, não o Altar")
	ok(Progressao.aviso("estrutura", "altar").find("(3/5)") > 0, "o aviso do Altar mostra 3/5")
	_partida(false, "floresta")
	_partida(false, "floresta")
	ok(Progressao.aberto("estrutura", "altar"), "5 partidas abrem o Altar")
	ok(not _abertos().has("laboratorio"), "partidas não abrem mapas")

	# 6. save de antes das travas, com progresso: tudo aberto e marca de versão gravada na próxima escrita
	var antigo := "user://" + prefixo + "legado.cfg"
	var cf := ConfigFile.new()
	cf.set_value("moeda", "almas", 120)
	cf.set_value("melhorias", "vida", 1)
	cf.set_value("ultima", "tempo", 50.0)
	cf.save(antigo)
	Meta.caminho_save = antigo
	ok(_abertos() == Mapas.ids(), "save antigo com progresso: todos os mapas abertos")
	ok(Progressao.aberto("estrutura", "altar") and Progressao.aberto("estrutura", "codice"), "save antigo: todas as estruturas abertas")
	Meta.creditar(1)
	var gravado := ConfigFile.new()
	gravado.load(antigo)
	ok(int(gravado.get_value("progressao", "versao", 0)) == Meta.VERSAO_PROGRESSAO, "a gravação persiste a versão")
	ok(bool(gravado.get_value("progressao", "legado", false)), "a gravação persiste o legado")
	_partida(false, "floresta")
	ok(_abertos() == Mapas.ids(), "depois de uma partida o save antigo continua todo aberto")

	# 7. save antigo SEM progresso (só a escolha de mapa) não vira legado
	var vazio := "user://" + prefixo + "vazio.cfg"
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
	ok(not bool(slot.get_value("progressao", "legado", true)), "slot novo não é tratado como antigo")
	ok(_abertos() == ["floresta"], "slot novo depois de uma partida: só a Floresta")
	fim = true


func foto(nome: String) -> void:
	if pasta.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join("progressao_" + nome + ".png"))
