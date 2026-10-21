extends "res://testes/isolamento_v2.gd"
# Teste automático da faixa preta lateral (v2/mundo.gd, _ajustar_janela): maximizada ou em tela cheia o SO manda no tamanho da janela; se o
# jogo pedir outro, o Windows ignora mas o Window.size guarda o valor pedido, o viewport encolhe e sobra uma faixa à direita e embaixo
# (visto no notebook, 2560x1351 maximizada virou 2328x1310). Só o modo normal pode ser redimensionado, e a guarda vem antes de qualquer
# `janela.size =`. Headless não tem janela de verdade, então a conta e a ordem no código é o que dá para conferir aqui.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_janela_modo.tscn  (imprime "v2_janela_modo falhas=0")
const Mundo := preload("res://v2/mundo.gd")

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	ok(Mundo.janela_ajustavel(Window.MODE_WINDOWED), "janela normal aceita o tamanho do jogo")
	ok(not Mundo.janela_ajustavel(Window.MODE_MAXIMIZED), "janela maximizada (notebook) não é redimensionada")
	ok(not Mundo.janela_ajustavel(Window.MODE_FULLSCREEN), "tela cheia não é redimensionada")
	ok(not Mundo.janela_ajustavel(Window.MODE_EXCLUSIVE_FULLSCREEN), "tela cheia exclusiva não é redimensionada")
	ok(not Mundo.janela_ajustavel(Window.MODE_MINIMIZED), "janela minimizada não é redimensionada")
	var fonte := FileAccess.get_file_as_string("res://v2/mundo.gd")
	var ini := fonte.find("func _ajustar_janela()")
	var fim := fonte.find("# ----", ini)
	var corpo := fonte.substr(ini, fim - ini)
	var guarda := corpo.find("janela_ajustavel(janela.mode)")
	ok(guarda >= 0, "_ajustar_janela consulta janela_ajustavel")
	var primeiro := corpo.find("janela.size =")
	ok(primeiro > guarda, "a guarda vem antes do primeiro janela.size =")
	print("v2_janela_modo falhas=", falhas)
	get_tree().quit(1 if falhas > 0 else 0)
