extends "res://testes/isolamento_v2.gd"
# Teste do modo beta tester (argumento de usuário --beta-tester, Progressao.beta_tester). Sem a flag: personagem novo só tem Floresta e
# Estátuas. Com a flag (simulada por Progressao.args_teste): todos os portais e estruturas liberados, sem cadeado nem aviso, o selo
# BETA TESTER aparece no salão e NENHUM arquivo de save muda (md5 igual). Voltando a flag para vazio, as travas voltam.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_beta_tester.tscn  (imprime "v2_beta_tester falhas=0")

const Personagens := preload("res://v2/personagens.gd")
const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const Progressao := preload("res://v2/progressao.gd")
const Salao := preload("res://v2/salao.tscn")
const PASTA := "user://testes_v2/v2_beta_tester/"
const ESTRUTURAS := ["estatuas", "altar", "codice"]

var falhas := 0
var prefixo := ""
var fim := false


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	prefixo = "teste_beta_%d_" % Time.get_ticks_usec()
	Personagens.caminho_indice = PASTA + prefixo + "indice.cfg"
	Personagens.caminho_base = PASTA + prefixo + "p"
	Personagens.caminho_antigo = PASTA + prefixo + "antigo.cfg"
	Meta.caminho_save = PASTA + prefixo + "meta.cfg"
	await _testes()
	Progressao.args_teste = null
	ok(fim, "o teste chegou ao fim")
	var d := DirAccess.open(PASTA)
	for arquivo in d.get_files():
		if arquivo.begins_with(prefixo):
			d.remove(arquivo)
	print("v2_beta_tester falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


## md5 de todos os arquivos do teste (saves do personagem, índice e meta), numa só string.
func _hash_saves() -> String:
	var partes := PackedStringArray()
	var d := DirAccess.open(PASTA)
	var nomes := Array(d.get_files()).filter(func(a): return str(a).begins_with(prefixo))
	nomes.sort()
	for a in nomes:
		partes.append("%s=%s" % [a, FileAccess.get_md5(PASTA + a)])
	return ",".join(partes)


func _abertos() -> Array:
	return Mapas.ids().filter(func(id): return Mapas.condicao(Mapas.buscar(id)) == "")


func _selo(no: Node) -> bool:
	for c in no.get_children():
		if c is Label and c.text == "BETA TESTER":
			return true
	return false


func _testes() -> void:
	var id := Personagens.criar("Isac")
	ok(Personagens.ativar(id), "ativa o personagem")

	# 1. sem a flag: tudo como sempre
	Progressao.args_teste = []
	ok(not Progressao.beta_tester(), "sem --beta-tester o modo fica desligado")
	ok(_abertos() == ["floresta"], "sem a flag, personagem novo: só a Floresta aberta (%s)" % str(_abertos()))
	ok(not Progressao.aberto("mapa", "laboratorio"), "sem a flag, Laboratório trancado")
	ok(not Progressao.aberto("estrutura", "altar") and not Progressao.aberto("estrutura", "codice"), "sem a flag, Altar e Códice trancados")
	ok(Progressao.aviso("mapa", "laboratorio") != "", "sem a flag, o aviso do Laboratório existe")
	var antes := _hash_saves()

	# 2. com a flag: tudo liberado
	Progressao.args_teste = ["--outra", "--beta-tester"]
	ok(Progressao.beta_tester(), "com --beta-tester o modo liga")
	ok(_abertos().size() == Mapas.ids().size(), "com a flag, todos os portais abertos (%s)" % str(_abertos()))
	for m in ["floresta", "laboratorio", "cidade", "medio"]:
		ok(Mapas.ids().has(m), "o mapa %s existe na lista" % m)
		ok(Progressao.aberto("mapa", m) and Mapas.condicao(Mapas.buscar(m)) == "" and Mapas.curto(Mapas.buscar(m)) == "", "mapa %s liberado, sem cadeado" % m)
	for e in ESTRUTURAS:
		ok(Progressao.aberto("estrutura", e), "estrutura %s liberada" % e)
		ok(Progressao.curto("estrutura", e) == "" and Progressao.aviso("estrutura", e) == "", "estrutura %s sem cadeado nem aviso" % e)

	# 3. no salão: alvos sem trava, portal e estrutura antes trancados entram, selo visível
	var s = Salao.instantiate()
	add_child(s)
	var entrou := []
	s.ao_entrar = func(cena): entrou.append(cena)
	await get_tree().process_frame
	await get_tree().process_frame
	for a in s._alvos:
		ok(str(a.trava) == "", "salão: alvo %s sem trava" % a.id)
	s.abrir_estrutura("altar")
	ok(s._painel.visible, "salão: o Altar abre o painel")
	s._painel.visible = false
	ok(s.usar_portal("laboratorio"), "salão: o Laboratório entra no modo beta")
	ok(_selo(s), "salão: selo BETA TESTER visível")
	s.queue_free()
	await get_tree().process_frame

	# 4. nada gravado
	var depois := _hash_saves()
	ok(depois == antes, "os saves não mudam com o modo beta (antes=%s depois=%s)" % [antes, depois])

	# 5. desligando a flag as travas voltam
	Progressao.args_teste = []
	ok(not Progressao.aberto("mapa", "laboratorio"), "sem a flag de novo, o Laboratório volta a ficar trancado")
	var s2 = Salao.instantiate()
	add_child(s2)
	await get_tree().process_frame
	ok(not _selo(s2), "sem a flag, o salão não mostra o selo")
	s2.queue_free()
	fim = true
