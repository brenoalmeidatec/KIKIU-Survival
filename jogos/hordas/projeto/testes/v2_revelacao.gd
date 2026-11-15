extends Node
# Teste da revelação aos poucos do primeiro desenho (v2/revelacao.gd), numa árvore pequena, sem a carga da partida:
#  (1) o `_init` esconde tudo na hora (máscara 0 no SubViewport; cada item que desenha ganha um lote, um bit só, de 1 a 31);
#  (2) shaders diferentes caem em lotes diferentes, e o pai fica no menor lote entre o dele e o dos filhos (filho revelado nunca some);
#  (3) cada `quadro()` põe só o próximo lote na máscara, e um item aparece no quadro do lote dele, nem antes nem depois;
#  (4) quem nasce no meio (camada 1, o bit 0) só aparece no passo final; (5) no fim máscara e camadas voltam ao que eram e `quadro()`
#  devolve false; (6) nos `extras` (a janela) o bit 0 nunca sai da máscara: a tela de carregamento segue desenhando; (7) `encerrar()` no
#  meio (a partida saiu) solta tudo na hora.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_revelacao.tscn  (imprime "v2_revelacao falhas=0")
const Revelacao := preload("res://v2/revelacao.gd")
const TUDO := 0xFFFFFFFF
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	_lotes_e_passos()
	_encerrar_no_meio()
	print("v2_revelacao falhas=", falhas)
	get_tree().quit(1 if falhas else 0)


func _textura() -> ImageTexture:
	var im := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	return ImageTexture.create_from_image(im)


func _material(codigo: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = codigo
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _sprite(pai: Node, mat: Material = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _textura()
	s.material = mat
	pai.add_child(s)
	return s


## Um SubViewport com: um sprite do padrão, dois com shaders próprios diferentes, um Node2D (não desenha) com um filho de shader
## próprio, e um sprite do padrão com filho de outro shader (o pai tem de ficar no lote do filho, se o do filho vem antes).
func _montar() -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(32, 32)
	add_child(vp)
	var d := {"vp": vp}
	d.padrao = _sprite(vp)
	d.a = _sprite(vp, _material("shader_type canvas_item;\nvoid fragment(){ COLOR.r = 0.1; }\n"))
	d.b = _sprite(vp, _material("shader_type canvas_item;\nvoid fragment(){ COLOR.r = 0.2; }\n"))
	d.grupo = Node2D.new()
	vp.add_child(d.grupo)
	d.filho = _sprite(d.grupo, _material("shader_type canvas_item;\nvoid fragment(){ COLOR.r = 0.3; }\n"))
	var linha := Line2D.new()  # outro tipo de desenho (polígono) do material padrão
	linha.points = PackedVector2Array([Vector2.ZERO, Vector2(8, 8)])
	vp.add_child(linha)
	d.linha = linha
	var tela := TextureRect.new()  # um extra na janela (como ap.tela): a janela segue com o bit 0
	tela.texture = _textura()
	add_child(tela)
	d.tela = tela
	return d


func _bits(x: int) -> int:
	var n := 0
	while x != 0:
		n += x & 1
		x >>= 1
	return n


func _lote(ci: CanvasItem) -> int:
	return int(log(float(ci.visibility_layer)) / log(2.0) + 0.5)


func _visivel(ci: CanvasItem, vp: Viewport) -> bool:
	return (vp.canvas_cull_mask & ci.visibility_layer) != 0


func _lotes_e_passos() -> void:
	var d := _montar()
	var vp: SubViewport = d.vp
	var janela := get_viewport()
	var janela_antes := janela.canvas_cull_mask
	var r := Revelacao.new([vp], [d.tela], 8)
	# (1)
	ok(vp.canvas_cull_mask == 0, "(1) o SubViewport começa com a máscara 0 (%d)" % vp.canvas_cull_mask)
	ok(janela.canvas_cull_mask == 1, "(6) a janela começa só com o bit 0 (%d)" % janela.canvas_cull_mask)
	ok(r.lotes >= 4, "(2) quatro programas diferentes, pelo menos quatro lotes (%d)" % r.lotes)
	var itens: Array = [d.padrao, d.a, d.b, d.filho, d.linha]
	for ci in itens:
		var c: int = ci.visibility_layer
		ok(_bits(c) == 1 and c >= 2, "(1) %s num lote só, fora do bit 0 (%d)" % [ci.get_class(), c])
		ok(not _visivel(ci, vp), "(1) %s escondido depois do _init" % ci.get_class())
	ok(not _visivel(d.tela, janela), "(1) a tela do mundo na janela escondida")
	# (2)
	var l := {}
	for ci in [d.padrao, d.a, d.b, d.filho]:
		l[_lote(ci)] = true
	ok(l.size() == 4, "(2) padrão e três shaders próprios em quatro lotes diferentes (%s)" % str(l.keys()))
	ok(_lote(d.grupo) <= _lote(d.filho), "(2) o pai fica no lote do filho ou antes (%d > %d)" % [_lote(d.grupo), _lote(d.filho)])
	# (3) e (4)
	var novo := _sprite(vp)  # nasce no meio: camada 1
	ok(novo.visibility_layer == 1, "(4) quem nasce depois tem a camada 1")
	var adiantado := false
	var atrasado := false
	var janela_sem_bit0 := false
	for k in range(1, r.lotes + 1):
		ok(r.quadro(), "(3) o passo %d anda" % k)
		ok(vp.canvas_cull_mask == ((1 << (k + 1)) - 1) & ~1, "(3) no passo %d a máscara tem os lotes 1 a %d" % [k, k])
		for ci in itens:
			var lote := _lote(ci)
			if lote <= k and not _visivel(ci, vp):
				atrasado = true
			if lote > k and _visivel(ci, vp):
				adiantado = true
		ok(not _visivel(novo, vp), "(4) quem nasceu no meio segue escondido no passo %d" % k)
		janela_sem_bit0 = janela_sem_bit0 or (janela.canvas_cull_mask & 1) == 0
	ok(not adiantado and not atrasado, "(3) cada item aparece no passo do lote dele")
	ok(not janela_sem_bit0, "(6) o bit 0 da janela nunca saiu")
	ok(_visivel(d.tela, janela), "(3) a tela do mundo na janela aparece no lote dela")
	# (5)
	ok(r.quadro() and r.feito, "(5) o passo final encerra")
	ok(vp.canvas_cull_mask == TUDO and janela.canvas_cull_mask == janela_antes, "(5) as máscaras voltam ao que eram")
	ok(_visivel(novo, vp), "(4) quem nasceu no meio aparece no passo final")
	var mexidos := 0
	for ci in itens + [d.grupo, d.tela]:
		if ci.visibility_layer != 1:
			mexidos += 1
	ok(mexidos == 0, "(5) todas as camadas voltam a 1 (%d mexidas)" % mexidos)
	ok(not r.quadro(), "(5) depois do fim, quadro() devolve false")
	ok(r.progresso() == 1.0, "(5) progresso cheio no fim")
	vp.queue_free()
	d.tela.queue_free()


func _encerrar_no_meio() -> void:
	var d := _montar()
	var vp: SubViewport = d.vp
	var janela := get_viewport()
	var janela_antes := janela.canvas_cull_mask
	var r := Revelacao.new([vp], [d.tela], 8)
	r.quadro()
	ok(r.progresso() > 0.0 and r.progresso() < 1.0, "(7) no meio, a barra anda (%.2f)" % r.progresso())
	r.encerrar()
	ok(vp.canvas_cull_mask == TUDO and janela.canvas_cull_mask == janela_antes, "(7) encerrar no meio devolve as máscaras")
	ok(d.filho.visibility_layer == 1 and d.tela.visibility_layer == 1, "(7) e as camadas")
	ok(not r.quadro(), "(7) e não anda mais")
	vp.queue_free()
	d.tela.queue_free()
