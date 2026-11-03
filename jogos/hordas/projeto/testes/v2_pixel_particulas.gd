extends "res://testes/isolamento_v2.gd"
# Partículas de menu e escalas soltas na grade de 1 px (pixel art: um tamanho de pixel só, frente PARTÍCULAS do PIXEL-2). Prova que:
#  (1) a tela de título (menu_principal.tscn: faíscas do logo, brasas, espíritos e folhas do fundo vivo) usa escala inteira FIXA por emissor
#      e nenhuma rotação livre (angle, angular_velocity);
#  (2) o emissor do salão vivo (salao_vivo.gd) também;
#  (3) o código do especial (mecha), das armas novas (queda, balestra, cabaça), dos avisos (pedra) e do chefe visual (corvos) não desenha mais
#      com escala fracionária nem com ângulo livre (confere o texto do desenho: o desenho em si só se vê em janela).
# Falha no código antigo (scale_amount 0,5..1 / 1..2 / 2..3; angular_velocity +-120; escalas 0,85, 1,1, 1,18, 1,2, 1,5, 0,85 e 1,4).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pixel_particulas.tscn  (imprime "v2_pixel_particulas falhas=0")
const Menu := preload("res://v2/menu_principal.tscn")
const Vivo := preload("res://v2/salao_vivo.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _inteiro(x: float) -> bool:
	return is_equal_approx(x, roundf(x)) and x >= 1.0


func _emissores(raiz: Node, saida: Array) -> void:
	for n in raiz.get_children():
		if n is CPUParticles2D:
			saida.append(n)
		_emissores(n, saida)


func _checar(nome: String, lista: Array) -> void:
	ok(not lista.is_empty(), "%s: achou emissores" % nome)
	for p in lista:
		var pp := p as CPUParticles2D
		ok(
			_inteiro(pp.scale_amount_min) and is_equal_approx(pp.scale_amount_min, pp.scale_amount_max),
			"%s: escala fracionária ou variável (%s..%s)" % [nome, pp.scale_amount_min, pp.scale_amount_max]
		)
		ok(pp.angular_velocity_min == 0.0 and pp.angular_velocity_max == 0.0, "%s: emissor gira em tempo de execução" % nome)
		ok(pp.angle_min == 0.0 and pp.angle_max == 0.0, "%s: emissor com ângulo inicial livre" % nome)
		var tex := pp.texture
		ok(tex != null and tex.get_width() >= 1 and tex.get_height() >= 1, "%s: emissor com textura de pixel" % nome)


func _ready() -> void:
	# 1. a tela de título
	var menu := Menu.instantiate()
	add_child(menu)
	await get_tree().process_frame
	var lista: Array = []
	_emissores(menu, lista)
	ok(lista.size() >= 4, "título: faíscas, brasas, espíritos e folhas (%d emissores)" % lista.size())
	_checar("título", lista)
	menu.queue_free()

	# 2. o salão vivo
	var vivo := Vivo.new()
	vivo._fx = Node2D.new()
	vivo._mat_add = CanvasItemMaterial.new()
	vivo._tex_ponto = vivo._imagem_cor(Color.WHITE, 1, 1)
	add_child(vivo._fx)
	var g := Gradient.new()
	vivo._emissor(Vector2(10, 10), 5, 1.0, g)
	vivo._emissor(Vector2(20, 20), 5, 1.0, g, false)
	var l2: Array = []
	_emissores(vivo._fx, l2)
	ok(l2.size() == 2, "salão: emissores criados (%d)" % l2.size())
	_checar("salão", l2)
	vivo.free()

	# 3. o desenho: nada de escala fracionária nem ângulo livre nas linhas que eram o problema
	var ant := FileAccess.get_file_as_string("res://v2/armas_novas.gd")
	ok(not ("Vector2(1.5, 0.85)" in ant) and not ("Vector2(1.2, 1.2)" in ant), "cabaça sem escala 1,5 x 0,85 / 1,2")
	ok(not ("Vector2(pop, pop)" in ant), "balestra sem escala pop")
	ok(not ("Vector2(estica, " in ant), "queda do meteoro sem esticar")
	ok(not ("Vector2(s, s)" in ant), "rastro da queda sem encolher")
	var esp := FileAccess.get_file_as_string("res://v2/especial.gd")
	ok(not ("1.0 + 0.1 * e" in esp), "mecha do especial sem escala 1,1")
	var avi := FileAccess.get_file_as_string("res://v2/avisos.gd")
	ok(not ("Vector2(0.85, 0.85)" in avi), "pedra do aviso sem escala 0,85")
	ok("PixelRot.quarto((-QUEDA_DE).angle())" in avi, "pedra do aviso gira em passos de 90 graus")
	var chf := FileAccess.get_file_as_string("res://v2/chefe_visual.gd")
	ok(not ("1.4 if esq else 1.4, 1.4" in chf) and not ("(0.8 + 0.2 * sin(fase))" in chf), "corvos sem escala 1,4 nem 1,2 a 2,0")
	ok("PixelRot.quarto(" in chf, "corvo em voo gira em passos de 90 graus")
	print("v2_pixel_particulas falhas=", falhas)
	get_tree().quit(1 if falhas else 0)
