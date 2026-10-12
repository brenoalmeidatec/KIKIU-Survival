extends Node
# Teste automático: a cena que substitui o menu pelos argumentos (--prototipo, --v2, --cena) em main.gd e a v2 como cena principal.
# Testa só a função de resolução (Main.cena_de_argumentos), sem trocar de cena de verdade.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/entrada_cenas.tscn  (imprime "ENTRADA_CENAS falhas=0")
const Main := preload("res://scripts/hordas/main.gd")
const Altar := preload("res://v2/altar.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var existe_tudo := func(_p: String) -> bool: return true
	var existe_nada := func(_p: String) -> bool: return false
	var so_v2 := func(p: String) -> bool: return p == "res://v2/altar.tscn"
	var so_cena := func(p: String) -> bool: return p == "res://testes/algo.tscn"
	ok(Main.cena_de_argumentos({"prototipo": true}, existe_nada) == "res://prototipos/cara_nova.tscn", "--prototipo abre o protótipo")
	ok(Main.cena_de_argumentos({"v2": true}, existe_nada) == "res://prototipos/cara_nova.tscn", "--v2 sem o arquivo cai no protótipo")
	ok(Main.cena_de_argumentos({"v2": true}, so_v2) == "res://v2/altar.tscn", "--v2 com o arquivo abre o santuário da v2")
	ok(Main.cena_de_argumentos({"v2": true, "prototipo": true}, so_v2) == "res://v2/altar.tscn", "--v2 ganha de --prototipo")
	ok(Main.cena_de_argumentos({"cena": "res://testes/algo.tscn"}, so_cena) == "res://testes/algo.tscn", "--cena abre a cena pedida")
	ok(Main.cena_de_argumentos({"cena": "res://testes/nao_existe.tscn"}, existe_nada) == "", "--cena sem arquivo fica no menu")
	ok(Main.cena_de_argumentos({"cena": "res://testes/algo.tscn", "prototipo": true}, existe_tudo) == "res://testes/algo.tscn", "--cena ganha de --prototipo")
	ok(Main.cena_de_argumentos({}, existe_tudo) == "", "sem argumento, fica no menu")
	ok(Main.cena_de_argumentos({"bot": true, "heroi": "hazaki"}, existe_tudo) == "", "argumentos de partida não trocam a cena")
	ok(
		Main.cena_de_argumentos({"prototipo": "1", "fotos": "/x", "seq": "1.5"}, existe_tudo) == "res://prototipos/cara_nova.tscn",
		"os argumentos do protótipo (--fotos, --seq) não atrapalham"
	)
	# com o arquivo real: enquanto a v2 não existe, --v2 cai no protótipo (quando existir, este teste deixa de checar isso)
	if not ResourceLoader.exists(Main.CENA_V2):
		ok(
			Main.cena_de_argumentos({"v2": true}, func(p: String) -> bool: return ResourceLoader.exists(p)) == Main.CENA_PROTOTIPO,
			"--v2 com o arquivo real ausente cai no protótipo"
		)
	ok(ResourceLoader.exists(Main.CENA_PROTOTIPO), "o protótipo existe no projeto")
	# a v2 é a cena principal; a v1 abre com --v1 ou com os argumentos de teste dela (v2/altar.gd)
	ok(ProjectSettings.get_setting("application/run/main_scene") == "res://v2/altar.tscn", "a cena principal é o santuário da v2")
	ok(ResourceLoader.exists(Altar.CENA_V1), "a v1 (main.tscn) continua no projeto")
	ok(not Altar.pede_v1({}, true), "sem argumento, fica na v2")
	ok(not Altar.pede_v1({"fotos": "/x", "perfil": "baixo", "estresse": "50", "imortal": true}, true), "argumentos da v2 não abrem a v1")
	ok(Altar.pede_v1({"v1": true}, true), "--v1 abre a v1")
	ok(Altar.pede_v1({"bot": true, "heroi": "lucas", "sair": "60"}, true), "o robô da v1 (--bot --sair) abre a v1")
	ok(Altar.pede_v1({"online": "host"}, true), "--online abre a v1")
	ok(Altar.pede_v1({"prototipo": true}, true), "--prototipo passa pela v1 (que abre o protótipo)")
	ok(Main.cena_de_argumentos({"v1": true, "v2": true}, so_v2) == "", "--v1 ganha de --v2 no menu da v1")
	ok(not Altar.pede_v1({"v1": true, "v2": true}, false), "na segunda vez o santuário não volta à v1 (sem laço com --v2)")
	ok(Altar.ler_args(PackedStringArray(["--v1", "--heroi=lucas", "x"])) == {"v1": true, "heroi": "lucas"}, "lê --chave e --chave=valor")
	print("ENTRADA_CENAS falhas=%d" % falhas)
	get_tree().quit()
