extends Node
# Teste automÃ¡tico do personagem, do salÃ£o e da escolha de personagem da v2 (v2/personagens.gd, v2/salao.gd e
# v2/personagens_tela.gd). Usa arquivos TEMPORÃRIOS (user://teste_salao_*): o save real da meta (user://v2_progresso.cfg) e os saves
# dos personagens de verdade nÃ£o sÃ£o tocados; a conferÃªncia por md5 garante isso.
# Confere: cada personagem tem o santuÃ¡rio dele (o saldo de um nÃ£o aparece no outro); um personagem novo comeÃ§a zerado; o save antigo
# vira o primeiro personagem sem perder nada e a migraÃ§Ã£o nÃ£o roda duas vezes; comprar numa estrutura desconta as almas e recusa sem
# almas; um portal aberto grava o mapa no personagem e leva Ã  partida, e um fechado nÃ£o leva; as almas de uma partida voltam ao
# salÃ£o do personagem ativo; e a escolha de personagem cria e abre um personagem com o santuÃ¡rio zerado.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_salao.tscn  (imprime "v2_salao falhas=0")

const Personagens := preload("res://v2/personagens.gd")
const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const Salao := preload("res://v2/salao.tscn")
const Tela := preload("res://v2/personagens.tscn")
const PREFIXO := "user://teste_salao_p"
const INDICE := "user://teste_salao_personagens.cfg"
const ANTIGO := "user://teste_salao_progresso.cfg"
const SAVE_REAL := "user://v2_progresso.cfg"
const SAVE_META_TESTE := "user://teste_salao_meta.cfg"
const FLORESTA := "res://v2/mundo.tscn"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Personagens.caminho_base = PREFIXO
	Personagens.caminho_indice = INDICE
	Personagens.caminho_antigo = ANTIGO
	Meta.caminho_save = SAVE_META_TESTE
	var md5_real := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	_limpar()
	await _testes()
	_limpar()
	var depois := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	ok(md5_real == depois, "o save real da meta nao foi tocado")
	print("v2_salao falhas=%d" % falhas)
	get_tree().quit()


func _limpar() -> void:
	_apagar(INDICE)
	_apagar(ANTIGO)
	_apagar(ANTIGO + ".bak")
	for i in range(1, 6):
		var base := Personagens.caminho_do_save("p%d" % i)
		_apagar(base)
		_apagar(base + ".bak")
	_apagar(SAVE_META_TESTE)
	_apagar(SAVE_META_TESTE + ".bak")
	_apagar(SAVE_META_TESTE + ".tmp")


## Apaga o Ã­ndice e os slots (o save antigo fica).
func _limpar_personagens() -> void:
	_apagar(INDICE)
	for i in range(1, 6):
		_apagar(Personagens.caminho_do_save("p%d" % i))


func _apagar(caminho: String) -> void:
	if FileAccess.file_exists(caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))


func _testes() -> void:
	# 1. sem save antigo nem personagem: nada Ã© criado e nÃ£o hÃ¡ ativo
	Personagens.migrar_se_preciso()
	ok(Personagens.lista().is_empty() and Personagens.ativo() == "", "sem save antigo a lista de personagens comeÃ§a vazia")
	ok(not FileAccess.file_exists(INDICE), "sem save antigo nenhum Ã­ndice Ã© gravado")

	# 2. criar personagens: cada um ganha o prÃ³prio slot de save e o nome que escolheu
	var p1 := Personagens.criar("Breno")
	var p2 := Personagens.criar("Lucas")
	ok(p1 == "p1" and p2 == "p2", "os personagens novos ganham os ids p1 e p2 (%s, %s)" % [p1, p2])
	ok(Personagens.lista() == ["p1", "p2"], "a lista guarda a ordem de criaÃ§Ã£o")
	ok(Personagens.nome("p2") == "Lucas", "o nome fica no Ã­ndice")
	ok(Personagens.resumo("p2").almas == 0 and Personagens.resumo("p2").niveis == 0, "um personagem novo comeÃ§a com o santuÃ¡rio zerado")

	# 3. isolamento: almas do p1 nÃ£o aparecem no p2
	ok(Personagens.ativar("p1"), "ativar p1 funciona")
	ok(Meta.caminho_save == Personagens.caminho_do_save("p1"), "ativar aponta a meta para o save do p1")
	Meta.creditar(300)
	ok(Meta.saldo() == 300, "p1 tem 300 almas depois de creditar")
	ok(Personagens.ativar("p2") and Meta.saldo() == 0, "p2 nÃ£o herda as almas do p1")
	ok(Personagens.ativar("p1") and Meta.saldo() == 300, "voltar ao p1 mostra as 300 almas dele")
	ok(not Personagens.ativar("p9"), "ativar um id que nÃ£o existe nÃ£o faz nada")

	# 4. migraÃ§Ã£o: o save antigo vira o p1, sem perder nada; o arquivo antigo fica como estava; roda uma vez sÃ³
	_limpar_personagens()
	var antigo := ConfigFile.new()
	antigo.set_value("moeda", "almas", 77)
	antigo.set_value("melhorias", "vida", 2)
	antigo.set_value("config", "mapa", "cidade")
	antigo.set_value("conquistas", "sobreviva_5min", true)
	antigo.save(ANTIGO)
	Personagens.migrar_se_preciso()
	ok(Personagens.lista() == ["p1"] and Personagens.ativo() == "p1", "a migraÃ§Ã£o cria o p1 e o deixa ativo")
	var r := Personagens.resumo("p1")
	ok(int(r.almas) == 77 and int(Personagens.niveis("p1").vida) == 2, "a migraÃ§Ã£o copia almas e melhorias (%d almas)" % int(r.almas))
	ok(str(r.mapa) == "cidade", "a migraÃ§Ã£o copia o mapa escolhido")
	ok(FileAccess.file_exists(ANTIGO), "o save antigo continua no lugar (nada se perde)")
	Personagens.migrar_se_preciso()
	ok(Personagens.lista() == ["p1"], "rodar a migraÃ§Ã£o de novo nÃ£o duplica o personagem")

	# 5. salÃ£o: o saldo e a compra sÃ£o os do personagem ativo
	var s = Salao.instantiate()
	add_child(s)
	var cenas := []
	s.ao_entrar = func(cena): cenas.append(cena)
	ok(s.saldo() == 77, "o salÃ£o mostra o saldo do personagem ativo (%d)" % s.saldo())
	ok(s.comprar_item("dano"), "com 77 almas compra o 1Âº nÃ­vel de dano (40)")
	ok(Meta.saldo() == 37 and Meta.nivel("dano") == 1, "a compra desconta 40 almas e sobe o nÃ­vel (saldo %d)" % Meta.saldo())
	ok(not s.comprar_item("velocidade"), "sem almas bastantes (50 > 37) a compra Ã© recusada")
	ok(Meta.saldo() == 37 and Meta.nivel("velocidade") == 0, "a compra recusada nÃ£o gasta nada")
	ok(s.alvos().size() == 3 + Mapas.LISTA.size(), "o salÃ£o tem as 3 estruturas e um portal por mapa")
	ok(s.saldo() == 37, "o saldo na tela acompanha a compra")
	s.abrir_estrutura("estatuas")
	ok(s._p_itens.size() == 5, "as estÃ¡tuas mostram as 5 melhorias de corpo")
	s.abrir_estrutura("codice")
	ok(s._p_itens.size() == Meta.conquistas().size(), "o cÃ³dice lista todas as conquistas")

	# 6. portais: um aberto grava o mapa no personagem e leva Ã  partida; um fechado nÃ£o leva
	ok(not s.usar_portal("cidade") and cenas.is_empty(), "o portal da cidade está trancado até vencer o Laboratório")
	ok(Mapas.escolhido() == "floresta", "a escolha trancada de um save antigo não vale")
	ok(Meta.marcar_mapa_vencido("floresta") and Meta.marcar_mapa_vencido("laboratorio"), "libera de forma explícita: vence Floresta e Laboratório")
	ok(s.usar_portal("cidade") and Mapas.escolhido() == "cidade", "o portal da cidade grava a escolha")
	ok(cenas == [FLORESTA], "o portal leva Ã  cena da partida")
	ok(Mapas.condicao({"requer": "combo_50"}) != "", "um mapa com conquista nÃ£o cumprida fica fechado e diz o porquÃª")
	ok(Mapas.condicao({"requer": "combo_50"}).find("Trancado") == 0, "o texto do portal trancado comeÃ§a com Trancado")
	ok(Mapas.condicao({}) == "", "sem condiÃ§Ã£o o portal estÃ¡ aberto")

	# 7. a partida termina: as almas entram no personagem ativo e o salÃ£o aberto de novo as mostra
	var ganho := Meta.registrar_partida({"tempo": 10.0, "abates": 55, "nivel": 3, "maior_combo": 55, "venceu": false, "almas": 100})
	ok(int(ganho.get("depois", -1)) == 137, "a partida credita as almas no personagem ativo (depois=%d)" % int(ganho.get("depois", -1)))
	ok(Mapas.condicao({"requer": "combo_50"}) == "", "cumprir a conquista de combo abre o mapa que ela libera")
	remove_child(s)
	s.queue_free()
	var s2 = Salao.instantiate()
	add_child(s2)
	ok(s2.saldo() == 137, "ao voltar, o salÃ£o mostra as almas da partida (%d)" % s2.saldo())
	ok(s2._quadro_w == 32 and s2._pe_y == 42, "o Hazaki no salão segue com a folha de 32x44 e os pés na linha 42")
	remove_child(s2)
	s2.queue_free()

	# 8. escolha de personagem: lista os personagens e os nomes livres; criar um personagem novo abre o salÃ£o zerado
	Personagens.criar("Lucas")  # a migração deixou só o p1: agora são dois personagens, o Breno e o Lucas
	var t = Tela.instantiate()
	add_child(t)
	t.ao_escolher = func(cena): cenas.append(cena)
	ok(t._lista.get_child_count() == 2 + 1, "a escolha mostra 2 personagens e NOVO PERSONAGEM")
	t._abrir_nomes()
	ok(t._lista.get_child_count() == Personagens.nomes_livres().size() + 1, "criar mostra os nomes livres e VOLTAR")
	var lucas_usado := Personagens.nomes().filter(func(n): return n.nome == "Lucas")
	ok(lucas_usado.size() == 1 and not Personagens.nomes_livres().any(func(n): return n.nome == "Lucas"), "um nome jÃ¡ usado nÃ£o volta a ser oferecido")
	t._criar(Personagens.nomes_livres()[0])
	ok(Personagens.lista().size() == 3 and Personagens.ativo() == "p3", "criar um personagem novo o deixa ativo")
	ok(Meta.saldo() == 0 and Meta.caminho_save == Personagens.caminho_do_save("p3"), "o personagem criado comeÃ§a com 0 almas e usa o prÃ³prio save")
	ok(cenas.back() == "res://v2/salao.tscn", "criar leva ao salÃ£o")
	remove_child(t)
	t.queue_free()

	# 9. o personagem que joga o Nicão anda no salão com a folha do Nicão (64x96, pés na linha 74, andar de 6 quadros; o do Hazaki segue na folha dele)
	var id_nicao := Personagens.criar("Nicão", "nicao")
	ok(Personagens.heroi(id_nicao) == "nicao" and Personagens.ativar(id_nicao), "o Nicão joga o herói nicao")
	var s3 = Salao.instantiate()
	add_child(s3)
	ok(
		s3._quadro_w == 64 and s3._quadro_h == 96 and s3._pe_y == 74 and s3._passos == 6,
		"o salão do Nicão usa a folha dele (%dx%d, pés %d, %d passos)" % [s3._quadro_w, s3._quadro_h, s3._pe_y, s3._passos]
	)
	ok(s3._sprite.resource_path.ends_with("nicao_albedo.png"), "e a textura é a do Nicão (%s)" % s3._sprite.resource_path)
	remove_child(s3)
	s3.queue_free()
