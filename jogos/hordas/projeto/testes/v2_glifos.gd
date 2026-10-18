extends Node
# Teste dos glifos de controle da v2 (v2/glifos.gd): o último dispositivo usado (teclado e mouse, Xbox ou PlayStation) decide o botão de cada
# ação e a troca é na hora (avisa quem ouviu); o nome do controle cai no Xbox ou no PlayStation; cada ação existe nos três; a dica desenhada
# se refaz na troca; o título esconde o "Mouse também" no controle.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_glifos.tscn  (imprime "v2_glifos falhas=0")
const Glifos := preload("res://v2/glifos.gd")
const Titulo := preload("res://v2/menu_principal.tscn")

var falhas := 0
var avisos := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Glifos.forcado = false
	Glifos.definir(Glifos.Disp.TECLADO)
	Glifos.ao_mudar(func() -> void: avisos += 1)
	_nomes()
	_troca()
	_dica_e_titulo()
	Glifos.definir(Glifos.Disp.TECLADO)
	print("v2_glifos falhas=%d" % falhas)
	get_tree().quit()


func _nomes() -> void:
	ok(Glifos.tipo_pelo_nome("Xbox 360 Controller") == Glifos.Disp.XBOX, "Xbox 360 vira Xbox")
	ok(Glifos.tipo_pelo_nome("XInput Gamepad") == Glifos.Disp.XBOX, "XInput vira Xbox")
	ok(Glifos.tipo_pelo_nome("PS5 Controller") == Glifos.Disp.PS, "PS5 vira PlayStation")
	ok(Glifos.tipo_pelo_nome("DualSense Wireless Controller") == Glifos.Disp.PS, "DualSense vira PlayStation")
	ok(Glifos.tipo_pelo_nome("Wireless Controller") == Glifos.Disp.PS, "Wireless Controller (DualShock 4 no Windows) vira PlayStation")
	ok(Glifos.tipo_pelo_nome("Controle qualquer") == Glifos.Disp.XBOX, "controle desconhecido usa o layout do Xbox")
	for a in Glifos.TABELA:
		for d in 3:
			ok(not (Glifos.TABELA[a][d] as Array).is_empty(), "%s tem botão no dispositivo %d" % [a, d])


func _troca() -> void:
	ok(Glifos.texto("voltar") == "Esc", "teclado: voltar é Esc (%s)" % Glifos.texto("voltar"))
	ok(not Glifos.eh_controle(), "começa no teclado")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_A
	b.pressed = true
	Glifos.observar(b)  # device 0: sem controle ligado cai no Xbox
	ok(Glifos.eh_controle(), "apertar botão do controle troca para o controle")
	ok(avisos == 1, "a troca avisou uma vez (%d)" % avisos)
	ok(Glifos.texto("voltar") == "B", "Xbox: voltar é B (%s)" % Glifos.texto("voltar"))
	Glifos.observar(b)
	ok(avisos == 1, "repetir o mesmo dispositivo não avisa de novo")
	Glifos.definir(Glifos.Disp.PS)
	ok(Glifos.descritor("voltar")[0][0] == Glifos.PS and Glifos.descritor("voltar")[0][1] == "o", "PlayStation: voltar é a bola")
	ok(Glifos.descritor("confirmar")[0][1] == "x", "PlayStation: confirmar é a cruz")
	var m := InputEventJoypadMotion.new()
	m.axis_value = 0.2
	Glifos.definir(Glifos.Disp.TECLADO)
	Glifos.observar(m)
	ok(not Glifos.eh_controle(), "deriva do analógico não troca")
	m.axis_value = 0.9
	Glifos.observar(m)
	ok(Glifos.eh_controle(), "analógico firme troca para o controle")
	var k := InputEventKey.new()
	k.pressed = true
	Glifos.observar(k)
	ok(not Glifos.eh_controle(), "tecla volta ao teclado")
	Glifos.definir(Glifos.Disp.XBOX)
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(1, 0)
	Glifos.observar(mm)
	ok(Glifos.eh_controle(), "mouse tremendo (1 px) não troca")
	mm.relative = Vector2(10, 0)
	Glifos.observar(mm)
	ok(not Glifos.eh_controle(), "mover o mouse troca para teclado e mouse")
	Glifos.forcado = true
	Glifos.definir(Glifos.Disp.PS)
	Glifos.observar(k)
	ok(Glifos.eh_controle(), "com o dispositivo travado a detecção para")
	Glifos.forcado = false


func _dica_e_titulo() -> void:
	Glifos.definir(Glifos.Disp.TECLADO)
	var d := Glifos.dica(func() -> Array: return [["voltar", "Voltar"]])
	add_child(d)
	var w_teclado := d.get_minimum_size().x
	Glifos.definir(Glifos.Disp.XBOX)
	ok(d.get_minimum_size().x < w_teclado, "a dica se refaz na troca (%f -> %f)" % [w_teclado, d.get_minimum_size().x])
	d.queue_free()
	var titulo = Titulo.instantiate()
	Glifos.definir(Glifos.Disp.TECLADO)
	ok(titulo._itens_dica().size() == 4, "teclado: título mostra 'Mouse também'")
	Glifos.definir(Glifos.Disp.PS)
	ok(titulo._itens_dica().size() == 3, "controle: título não mostra o mouse")
	titulo.free()
