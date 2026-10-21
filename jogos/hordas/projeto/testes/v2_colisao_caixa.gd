extends "res://testes/isolamento_v2.gd"
# Teste automático: forma "caixa" (retângulo alinhado aos eixos no chão) de v2/colisao.gd. O corpo é a elipse r x r/2 (chão 2:1),
# a mesma convenção da elipse: folga de r em x e de r/2 em y.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_colisao_caixa.tscn  (imprime "v2_colisao_caixa falhas=0")
const Colisao := preload("res://v2/colisao.gd")
const PE := Vector2(500, 400)
const CAIXA := [{"tipo": "caixa", "centro": [0, -50], "meio": [100, 50]}]  # ocupa x 400..600, y 300..400
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func nova(formas: Array = CAIXA) -> void:
	Colisao.limpar()
	Colisao.adicionar_objeto(PE, formas)


func teste_centro() -> void:
	nova()
	var raio := 8.0
	for p in [Vector2(500, 350), Vector2(410, 350), Vector2(590, 350), Vector2(500, 310), Vector2(500, 390), Vector2(500, 350.0)]:
		ok(not Colisao.livre(p, raio), "centro %s: dentro da caixa nao e livre" % p)
		var r := Colisao.resolver(p, raio)
		ok(Colisao.livre(r, raio), "centro %s: resolver tira o corpo da caixa (%s)" % [p, r])
	# o menor eixo: perto da face de cima sai por cima; perto da lateral sai pela lateral
	var por_cima := Colisao.resolver(Vector2(500, 310), raio)
	ok(por_cima.y < 300.0 and absf(por_cima.x - 500.0) < 0.01, "perto da face de cima sai por cima (%s)" % por_cima)
	var lateral := Colisao.resolver(Vector2(590, 350), raio)
	ok(lateral.x > 600.0 and absf(lateral.y - 350.0) < 0.01, "perto da lateral sai pela lateral (%s)" % lateral)


func teste_livre() -> void:
	nova()
	ok(Colisao.livre(Vector2(500, 295), 8.0), "livre: 5 px da face de cima, raio 8 (meio raio em y = 4)")
	ok(not Colisao.livre(Vector2(500, 297), 8.0), "nao livre: 3 px da face de cima, raio 8")
	ok(Colisao.livre(Vector2(500, 405), 8.0), "livre: 5 px da face de baixo")
	ok(not Colisao.livre(Vector2(500, 403), 8.0), "nao livre: 3 px da face de baixo")
	ok(Colisao.livre(Vector2(391, 350), 8.0), "livre: 9 px da lateral")
	ok(not Colisao.livre(Vector2(393, 350), 8.0), "nao livre: 7 px da lateral")
	# o canto e arredondado pela elipse do corpo (no espaco com y x2: 9 e 10 px = 13,5 livre; 5 e 4 px = 6,4 nao)
	ok(Colisao.livre(Vector2(391, 295), 8.0), "livre: diagonal da quina a 9 px em x e 5 em y")
	ok(not Colisao.livre(Vector2(395, 298), 8.0), "nao livre: diagonal da quina a 5 px em x e 2 em y")
	# a caixa nao tem a forma de uma elipse: o canto do retangulo e solido
	ok(not Colisao.livre(Vector2(598, 398), 1.0), "canto do retangulo e solido (uma elipse deixaria passar)")


func teste_deslizar_na_face() -> void:
	nova()
	var raio := 8.0
	# anda para cima e para a direita contra a face de baixo (y=400): o x tem que avancar, o y fica abaixo da face
	var p := Vector2(420, 420)
	var x0 := p.x
	for _i in 100:
		p = Colisao.resolver(p + Vector2(1.0, -1.0), raio)
		ok(Colisao.livre(p, raio), "deslizar: passo fora da caixa (%s)" % p)
	ok(p.x - x0 > 90.0, "deslizar: avancou ao longo da face de baixo (dx=%.1f)" % (p.x - x0))
	ok(p.y >= 400.0 + raio * 0.5 - 0.5 and p.y < 400.0 + raio, "deslizar: continua colado na face, nao entrou (%s)" % p)
	# lateral esquerda para baixo
	p = Colisao.resolver(Vector2(380, 310), raio)
	for _i in 60:
		p = Colisao.resolver(p + Vector2(1.0, 1.0), raio)
		ok(Colisao.livre(p, raio), "deslizar lateral: fora da caixa (%s)" % p)
	ok(p.y > 360.0, "deslizar lateral: desceu ao longo da face (%s)" % p)


func teste_quina() -> void:
	nova()
	var raio := 8.0
	# contorna a quina inferior direita (600,400) subindo pela direita depois de passar por baixo
	var p := Vector2(560, 412)
	for _i in 200:
		p = Colisao.resolver(p + Vector2(1.0, -0.6), raio)
		ok(Colisao.livre(p, raio), "quina: nunca dentro (%s)" % p)
	ok(p.x > 650.0 and p.y < 400.0, "quina: contornou e subiu pela lateral direita (%s)" % p)
	# empurrao na quina e na diagonal (nao preso, nao teleporta)
	var r := Colisao.resolver(Vector2(603, 403), raio)
	ok(r.x > 603.0 and r.y > 403.0 and r.distance_to(Vector2(603, 403)) < raio + 1.0, "quina: empurrao diagonal curto (%s)" % r)
	# 4 quinas
	for c in [Vector2(400, 300), Vector2(600, 300), Vector2(400, 400), Vector2(600, 400)]:
		var q: Vector2 = Colisao.resolver(c + (c - Vector2(500, 350)).normalized() * 2.0, raio)
		ok(Colisao.livre(q, raio), "quina %s: resolvido fora" % c)


func teste_corpo_grande() -> void:
	nova()
	var raio := 60.0  # > RAIO_BUSCA: nao usa a tabela _perto
	ok(raio > Colisao.RAIO_BUSCA, "premissa: raio maior que RAIO_BUSCA")
	ok(not Colisao.livre(Vector2(500, 275), raio), "corpo grande a 25 px da face (raio/2 = 30 em y): toca")
	ok(Colisao.livre(Vector2(500, 260), raio), "corpo grande a 40 px da face: livre")
	var r := Colisao.resolver(Vector2(500, 330), raio)
	ok(Colisao.livre(r, raio), "corpo grande com o centro dentro sai (%s)" % r)
	# caixa alta (my > rx): a busca precisa alcancar pelo maior meio-lado
	nova([{"tipo": "caixa", "centro": [0, -300], "meio": [20, 300]}])  # y -200..400
	var q := Colisao.resolver(Vector2(500, -180), 40.0)
	ok(Colisao.livre(q, 40.0), "caixa alta e estreita: corpo no topo resolvido (%s)" % q)
	ok(not Colisao.livre(Vector2(500, 390), 14.0), "caixa alta: base ainda solida")
	ok(Colisao.livre(Vector2(530, 390), 8.0), "caixa alta: ao lado livre")


func teste_segmento() -> void:
	nova()
	ok(Colisao.segmento_perto(Vector2(300, 350), Vector2(700, 350), 8.0), "segmento atravessando a caixa e perto")
	ok(Colisao.segmento_perto(Vector2(380, 350), Vector2(395, 350), 8.0), "segmento terminando na face e perto")
	ok(not Colisao.segmento_perto(Vector2(100, 100), Vector2(200, 100), 8.0), "segmento longe nao e perto")
	ok(not Colisao.segmento_perto(Vector2(300, 100), Vector2(700, 100), 8.0), "segmento paralelo 200 px acima nao e perto")
	ok(Colisao.segmento_perto(Vector2(100, 100), Vector2(200, 100), 40.0), "corpo grande: sempre perto")
	# formas_no_retangulo (depuracao): devolve a caixa marcada como caixa
	var fs := Colisao.formas_no_retangulo(Rect2(300, 200, 400, 300))
	ok(fs.size() == 1 and fs[0].caixa and absf(fs[0].rx - 100.0) < 0.01 and absf(fs[0].ry - 50.0) < 0.01, "formas_no_retangulo da a caixa (%s)" % [fs])
	ok(Colisao.formas_no_retangulo(Rect2(0, 0, 100, 100)).is_empty(), "formas_no_retangulo longe: vazio")


func teste_mesma_convencao_da_elipse() -> void:
	# a elipse 2:1 e a caixa dao a mesma folga do corpo: r em x e r/2 em y
	var raio := 10.0
	Colisao.limpar()
	Colisao.adicionar_objeto(Vector2(0, 0), [{"tipo": "elipse", "centro": [0, 0], "raio": [40, 20]}])
	ok(Colisao.livre(Vector2(0, 26), raio) and not Colisao.livre(Vector2(0, 24), raio), "elipse: folga em y = ry + r/2")
	ok(Colisao.livre(Vector2(51, 0), raio) and not Colisao.livre(Vector2(49, 0), raio), "elipse: folga em x = rx + r")
	nova()
	ok(Colisao.livre(Vector2(500, 294), raio) and not Colisao.livre(Vector2(500, 296), raio), "caixa: folga em y = r/2 (5 px)")
	ok(Colisao.livre(Vector2(389, 350), raio) and not Colisao.livre(Vector2(391, 350), raio), "caixa: folga em x = r (10 px)")


func teste_mistura_com_elipse() -> void:
	Colisao.limpar()
	Colisao.adicionar_objeto(Vector2(200, 200), [{"tipo": "elipse", "centro": [0, -10], "raio": [20, 10]}])
	Colisao.adicionar_objeto(Vector2(600, 200), CAIXA)
	ok(not Colisao.livre(Vector2(200, 190), 4.0), "elipse continua solida ao lado de caixa")
	ok(not Colisao.livre(Vector2(600, 150), 4.0), "caixa solida ao lado de elipse")
	ok(Colisao.livre(Vector2(400, 190), 4.0), "entre as duas e livre")
	ok(Colisao.formas_no_retangulo(Rect2(0, 0, 1000, 500)).size() == 2, "duas formas registradas")


func _ready() -> void:
	teste_centro()
	teste_livre()
	teste_deslizar_na_face()
	teste_quina()
	teste_corpo_grande()
	teste_segmento()
	teste_mesma_convencao_da_elipse()
	teste_mistura_com_elipse()
	print("v2_colisao_caixa falhas=%d" % falhas)
	get_tree().quit()
