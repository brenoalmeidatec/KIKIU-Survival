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
	Config.definir("texto_hud", "medio")
	Config.girar("texto_hud", -1)
	ok(Config.v("texto_hud") == "normal", "fonte: de médio pra trás vira normal")
	Config.girar("texto_hud", -1)
	ok(Config.v("texto_hud") == "grande", "fonte: de normal pra trás dá a volta e vira grande")
	Config.girar("texto_hud", 1)
	ok(Config.v("texto_hud") == "normal", "fonte: e volta pra normal")
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
	# remapeamento de teclas (#126): troca a tecla da esquiva, o InputMap acompanha e fica salvo; Esc não vale
	var tinha := InputMap.has_action("dash")
	if not tinha:
		InputMap.add_action("dash")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	ok(Config.remapear("dash", ev), "remapear a esquiva pra J")
	ok(InputMap.action_has_event("dash", ev), "o InputMap passou a ter o J")
	ok(Config.texto_acao("dash").contains("J"), "o rótulo mostra J (%s)" % Config.texto_acao("dash"))
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	ok(not Config.remapear("dash", esc), "Esc cancela, não vira tecla")
	var cfg2 := ConfigFile.new()
	cfg2.load(Config.ARQUIVO)
	ok(int(cfg2.get_value("teclas", "dash_teclado", 0)) == KEY_J, "a tecla trocada fica no arquivo")
	Config._cfg.erase_section("teclas")
	Config._cfg.save(Config.ARQUIVO)
	if not tinha:
		InputMap.erase_action("dash")
	else:
		InputMap.action_erase_event("dash", ev)
	for k in antes:
		Config.definir(k, antes[k])
	print("OPCOES falhas=", falhas)
	get_tree().quit()
