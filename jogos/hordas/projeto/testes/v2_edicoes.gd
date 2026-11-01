extends "res://testes/isolamento_v2.gd"
# Teste automático da loja do Códice (ECO-6): as EDIÇÕES, que vendem +1 nível máximo de uma melhoria do santuário (v2/meta.gd e a
# página EDIÇÕES do Códice em v2/salao.gd). Usa saves TEMPORÁRIOS (meta, personagens e opções); o save real da meta não é tocado (md5).
# Confere: o preço é 2x o custo normal do nível extra; só depois do nível máximo normal; no máximo +2 por melhoria; sem a conquista
# que libera a melhoria não vende; o "max" da melhoria sobe junto (6/6) e o comprar() normal continua parado no máximo normal; o nível
# extra de uma conquista (nivel_max) soma com as edições; no salão, o Códice ganha o botão EDIÇÕES, a página tem uma linha por melhoria,
# COMPRAR EDIÇÃO desconta as almas e sobe o nível, e as Estátuas e a página de conquistas seguem como eram.
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_edicoes.tscn  (imprime "v2_edicoes falhas=0")

const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const Conquistas := preload("res://v2/conquistas.gd")
const Salao := preload("res://v2/salao.tscn")
const PASTA := "user://testes_v2/v2_edicoes/"
const SAVE_REAL := PASTA + "v2_progresso.cfg"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var md5_real := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	Meta.caminho_save = PASTA + "teste_v2_edicoes_meta.cfg"
	Config.arquivo = PASTA + "teste_v2_edicoes_opcoes.cfg"
	Personagens.caminho_base = PASTA + "teste_v2_edicoes_p"
	Personagens.caminho_indice = PASTA + "teste_v2_edicoes_personagens.cfg"
	Personagens.caminho_antigo = PASTA + "teste_v2_edicoes_antigo.cfg"
	_limpar()
	_regras()
	_travas()
	_com_conquista()
	await _tela()
	_limpar()
	var depois := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	ok(md5_real == depois, "o save real da meta nao foi tocado")
	print("v2_edicoes falhas=%d" % falhas)
	get_tree().quit()


func _limpar() -> void:
	get_tree().paused = false
	for f in DirAccess.get_files_at(PASTA):
		if f.begins_with("teste_v2_edicoes_"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PASTA + f))


## Personagem novo, zerado, com `almas` no saldo e `nivel` comprado em `id` (direto no save, sem passar pelo preço).
func _novo(almas: int, id := "", nivel := 0) -> void:
	Personagens.ativar(Personagens.criar("Teste"))
	var cf := Meta._ler()
	cf.set_value("moeda", "almas", almas)
	if id != "":
		cf.set_value("melhorias", id, nivel)
	Meta._gravar(cf)


func _preco_2x(id: String, n: int) -> int:
	var m := Meta.melhoria(id)
	return roundi(2.0 * float(m.custo) * pow(float(m.cresce), n))


## Preço 2x, só depois do máximo normal, no máximo +2 por melhoria, e o comprar() normal não passa do máximo normal.
func _regras() -> void:
	_novo(20000, "vida", 4)
	var antes := Meta.edicao("vida")
	ok(
		str(antes.estado) == "antes" and not Meta.comprar_edicao("vida") and Meta.saldo() == 20000,
		"no nível 4 de 5 a edição não vende e não gasta (%s)" % antes.estado
	)
	ok(Meta.comprar("vida") and Meta.nivel("vida") == 5, "o nível 5 compra pelo preço normal")
	ok(not Meta.comprar("vida"), "o comprar() normal para no máximo normal (5)")
	var saldo := Meta.saldo()
	var e1 := Meta.edicao("vida")
	ok(
		str(e1.estado) == "pronta" and int(e1.preco) == _preco_2x("vida", 5),
		"no máximo normal a edição 1 está pronta por 2x o custo do nível 6 (%d)" % int(e1.preco)
	)
	ok(
		int(e1.preco) == 2 * Meta.custo_do_nivel(Meta.melhoria("vida"), 5) or absi(int(e1.preco) - 2 * Meta.custo_do_nivel(Meta.melhoria("vida"), 5)) <= 1,
		"o preço da edição é o dobro do custo normal desse nível"
	)
	ok(Meta.comprar_edicao("vida") and Meta.nivel("vida") == 6, "comprar a edição 1 entrega o nível 6")
	ok(Meta.saldo() == saldo - int(e1.preco), "a edição 1 desconta o preço (%d)" % (saldo - Meta.saldo()))
	ok(int(Meta.melhoria("vida").max) == 6 and not Meta.comprar("vida"), "o max vira 6 e o comprar() normal segue parado")
	var e2 := Meta.edicao("vida")
	ok(str(e2.estado) == "pronta" and int(e2.feitas) == 1 and int(e2.preco) == _preco_2x("vida", 6), "a edição 2 custa 2x o nível 7 (%d)" % int(e2.preco))
	ok(Meta.comprar_edicao("vida") and Meta.nivel("vida") == 7, "comprar a edição 2 entrega o nível 7")
	var depois := Meta.saldo()
	ok(str(Meta.edicao("vida").estado) == "completa", "com 2 edições a melhoria fica completa")
	ok(not Meta.comprar_edicao("vida") and Meta.saldo() == depois and Meta.nivel("vida") == 7, "a 3ª edição é recusada, sem gastar")
	ok(int(Meta.melhoria("vida").max) == 7, "o max nunca passa de máximo normal + 2")
	ok(int(Meta.estado().niveis.vida) == 7, "o nível 7 aparece no estado do save")
	# sem almas bastando
	_novo(100, "dano", 5)
	var e := Meta.edicao("dano")
	ok(
		str(e.estado) == "sem_almas" and not Meta.comprar_edicao("dano") and Meta.saldo() == 100 and Meta.nivel("dano") == 5,
		"sem almas bastando a edição não vende (%s)" % e.estado
	)
	# o Ímã (máximo 4): o exemplo de preço do plano, ~459 almas no nível 5
	_novo(1000, "ima", 4)
	ok(int(Meta.edicao("ima").preco) == 459, "Ímã de almas: a edição 1 custa 459 (%d)" % int(Meta.edicao("ima").preco))


## Sem a conquista que libera a melhoria (treino pede sobreviva_5min) a edição não vende, mesmo no nível cheio.
func _travas() -> void:
	_novo(20000, "treino", 4)
	var e := Meta.edicao("treino")
	ok(str(e.estado) == "bloqueada" and not Meta.comprar_edicao("treino") and Meta.saldo() == 20000, "melhoria travada não vende edição (%s)" % e.estado)
	ok(str(Meta.edicao("nao_existe").estado) == "bloqueada" and not Meta.comprar_edicao("nao_existe"), "id desconhecido não vende")
	var cf := Meta._ler()
	cf.set_value("conquistas", "sobreviva_5min", true)
	Meta._gravar(cf)
	ok(
		str(Meta.edicao("treino").estado) == "pronta" and Meta.comprar_edicao("treino") and Meta.nivel("treino") == 5,
		"com a conquista a edição do treino vende"
	)


## O nível extra de uma conquista (nivel_max) soma com as edições: o máximo normal sobe e as edições vêm depois dele.
func _com_conquista() -> void:
	_novo(50000, "dano", 5)
	var cf := Meta._ler()
	cf.set_value("conquistas", "abates_1000", true)  # Ceifador: +1 nível em Gume de herança
	Meta._gravar(cf)
	var m := Meta.melhoria("dano")
	ok(Meta.max_normal(m) == 6 and int(m.max) == 6, "a conquista sobe o máximo normal de dano para 6")
	ok(str(Meta.edicao("dano").estado) == "antes" and not Meta.comprar_edicao("dano"), "no 5 de 6 ainda falta o máximo normal (a conquista liberou o 6)")
	ok(Meta.comprar("dano") and Meta.nivel("dano") == 6, "o nível 6 compra pelo preço normal")
	ok(Meta.comprar_edicao("dano") and Meta.comprar_edicao("dano") and Meta.nivel("dano") == 8, "depois do 6 vêm as 2 edições (7 e 8)")
	ok(not Meta.comprar_edicao("dano") and int(Meta.melhoria("dano").max) == 8, "e para no 8")


## A página EDIÇÕES do Códice: botão, lista, card, COMPRAR EDIÇÃO e o resto do salão como era.
func _tela() -> void:
	_novo(3000, "vida", 5)
	var cf := Meta._ler()
	cf.set_value("conquistas", "sobreviva_5min", true)  # o Códice só abre com uma conquista cumprida
	Meta._gravar(cf)
	var s = Salao.instantiate()
	add_child(s)
	await get_tree().process_frame
	s.abrir_estrutura("estatuas")
	ok(not s._p_pagina.visible, "as Estátuas não têm o botão EDIÇÕES")
	s.abrir_estrutura("codice")
	await get_tree().process_frame
	ok(s._p_pagina.visible and s._p_pagina.text == "EDIÇÕES" and not s._p_edicoes, "o Códice abre nas conquistas, com o botão EDIÇÕES")
	var n_conquistas: int = s._p_lista.get_child_count()
	ok(n_conquistas == Meta.conquistas().size() and not s._p_card.visible and s._p_rolagem.size.x > 800.0, "a página de conquistas segue como era")
	s._p_pagina.pressed.emit()
	await get_tree().process_frame
	ok(s._p_edicoes and s._p_pagina.text == "CONQUISTAS", "o botão leva às EDIÇÕES e passa a dizer CONQUISTAS")
	ok(
		s._p_lista.get_child_count() == Meta.melhorias_visiveis().size() and s._p_card.visible and s._p_rolagem.size.x < 400.0,
		"EDIÇÕES: uma linha por melhoria, com o card ao lado"
	)
	var vida: Button = s._p_lista.get_child(0)
	ok(
		vida.text.contains("5/7") and vida.text.contains(str(_preco_2x("vida", 5))),
		"a linha da Vida mostra 5/7 e o preço da edição (%s)" % vida.text.replace("\n", " | ")
	)
	ok(s._p_comprar.text == "COMPRAR EDIÇÃO" and not s._p_comprar.disabled, "a Vida no máximo normal, com almas, libera COMPRAR EDIÇÃO")
	var dano: Button = s._p_lista.get_child(1)
	dano.grab_focus()
	s._mostrar_item(1)
	ok(s._p_comprar.disabled and s._p_comprar.text == "FALTA O MÁXIMO", "o Dano no nível 0 mostra FALTA O MÁXIMO (%s)" % s._p_comprar.text)
	s._mostrar_item(0)
	var preco := int(Meta.edicao("vida").preco)
	s._comprar_atual()
	ok(Meta.nivel("vida") == 6 and Meta.saldo() == 3000 - preco, "COMPRAR EDIÇÃO sobe a Vida para 6 e desconta %d (saldo %d)" % [preco, Meta.saldo()])
	ok(
		s._p_aviso.text.begins_with("Comprado") and s._p_saldo.text == "ALMAS %d" % Meta.saldo(),
		"o painel avisa a compra e atualiza o saldo (%s)" % s._p_aviso.text
	)
	ok(s._p_lista.get_child(0).text.contains("6/7"), "a linha da Vida passa a 6/7")
	s._comprar_atual()
	ok(Meta.nivel("vida") == 7, "a 2ª edição sobe a Vida para 7")
	ok(s._p_comprar.disabled and s._p_comprar.text == "NO MÁXIMO", "com 2 edições o botão vira NO MÁXIMO")
	s._comprar_atual()
	ok(Meta.nivel("vida") == 7 and s._p_aviso.text == "Já tem todas as edições.", "a 3ª tentativa avisa e não compra (%s)" % s._p_aviso.text)
	# volta às conquistas e reabre: sempre começa nas conquistas
	s._p_pagina.pressed.emit()
	await get_tree().process_frame
	ok(not s._p_edicoes and s._p_lista.get_child_count() == n_conquistas and not s._p_card.visible, "CONQUISTAS volta à lista larga")
	s._p_pagina.pressed.emit()
	s._fechar_painel()
	s.abrir_estrutura("codice")
	ok(not s._p_edicoes and s._p_pagina.text == "EDIÇÕES", "reabrir o Códice começa nas conquistas")
	s.abrir_estrutura("estatuas")
	ok(not s._p_codice and not s._p_edicoes and s._p_card.visible and not s._p_pagina.visible, "as Estátuas voltam ao painel de sempre")
	ok(s._p_lista.get_child(0).text.contains("7/7"), "a Estátua da Vida mostra 7/7 depois das edições (%s)" % s._p_lista.get_child(0).text.replace("\n", " | "))
	s._fechar_painel()
	s.queue_free()
