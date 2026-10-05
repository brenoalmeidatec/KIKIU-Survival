extends Node
# Teste automático: tela de Opções (Config). Muda as opções de verdade e devolve como estavam no fim.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/opcoes.tscn  (imprime "OPCOES falhas=0")
const Efeitos := preload("res://scripts/hordas/efeitos.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func _ready() -> void:
	var antes := {}
	for it in Config.ITENS:
		antes[it.chave] = Config.v(it.chave)
		ok(it.valores.has(it.padrao), "%s: o padrão está na lista de valores" % it.chave)
		ok(not it.has("rotulos") or it.rotulos.size() == it.valores.size(), "%s: um rótulo por valor" % it.chave)
		ok(Config.rotulo(it.chave) != "", "%s: tem rótulo" % it.chave)
	# girar dá a volta nos dois sentidos
	Config.definir("fps_max", 30)
	Config.girar("fps_max", -1)
	ok(Config.v("fps_max") == 0 and Config.rotulo("fps_max") == "Sem limite", "FPS: de 30 pra trás vira Sem limite")
	Config.girar("fps_max", 1)
	ok(Config.v("fps_max") == 30, "FPS: e volta pra 30")
	Config.definir("musica", 0.3)
	ok(Config.rotulo("musica") == "30%" and is_equal_approx(Som.volume_musica, 0.3), "música: 30%% e o Som acompanha (%s)" % Config.rotulo("musica"))
	# fica salvo no arquivo
	var cfg := ConfigFile.new()
	cfg.load(Config.ARQUIVO)
	ok(is_equal_approx(float(cfg.get_value("opcoes", "musica", -1.0)), 0.3), "música salva no arquivo")
	# números de dano desligados: nenhum número aparece
	var ef := Efeitos.new()
	Config.definir("numeros_dano", false)
	ef.numero(Vector2.ZERO, 10)
	ok(ef.numeros.is_empty(), "sem números de dano")
	Config.definir("numeros_dano", true)
	ef.numero(Vector2.ZERO, 10)
	ok(ef.numeros.size() == 1, "com números de dano")
	ef.free()
	for k in antes:
		Config.definir(k, antes[k])
	print("OPCOES falhas=", falhas)
	get_tree().quit()
