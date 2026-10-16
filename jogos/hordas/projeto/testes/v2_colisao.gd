extends Node
# Teste automático: colisão da v2 (v2/colisao.gd). Usa as formas reais do prototipos/objetos/cenario.json (torii,
# muro, árvores) e casos sintéticos: 8 direções sem entrar na forma, deslizar na parede, passar entre os pilares,
# não atravessar uma fila de árvores, a caixa (retângulo: 8 direções, deslizar, canto, nascer dentro) e o desempenho (500 corpos x 150 objetos, uma passada de resolver).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_colisao.tscn  (imprime "v2_colisao falhas=0")
const Colisao := preload("res://v2/colisao.gd")
const META_US := 2000  # meta: uma passada de resolver em menos de 2 ms
const MARGEM := 4.0  # margem para CI com carga (4 cenas em paralelo deram ~5,6 ms de mediana): o limite e META_US * MARGEM
var falhas := 0
var _formas_por_nome: Dictionary = {}


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func carregar_cenario() -> Dictionary:
	var por_nome := {}
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://prototipos/objetos/cenario.json"))
	if d is Dictionary:
		for it in d.get("itens", []):
			por_nome[it["nome"]] = it.get("colisao", [])
	return por_nome


# --- 8 direcoes: a partir de fora, andando para o centro, nunca termina dentro da forma
func teste_oito_direcoes() -> void:
	Colisao.limpar()
	var pe := Vector2(300, 200)
	Colisao.adicionar_objeto(pe, [{"tipo": "elipse", "centro": [0, -10], "raio": [20, 10]}])
	var raio := 8.0
	var dentro := 0
	var encostou := 0
	for i in 8:
		var dir := Vector2.RIGHT.rotated(i * TAU / 8.0)
		var p := pe + Vector2(0, -10) + dir * 90.0
		ok(Colisao.livre(p, raio), "direcao %d: comeca livre" % i)
		for _passo in 300:
			p = Colisao.resolver(p - dir * 0.5, raio)
			if not Colisao.livre(p, raio):
				dentro += 1
		# parou na borda: distancia no espaco escalado (y * rx/ry) = rx + raio
		var q := p - (pe + Vector2(0, -10))
		var escalada := Vector2(q.x, q.y * 2.0).length()
		if absf(escalada - (20.0 + raio)) < 0.5:
			encostou += 1
	ok(dentro == 0, "8 direcoes: nenhum passo termina dentro (%d passos dentro)" % dentro)
	ok(encostou == 8, "8 direcoes: para encostado na borda (%d de 8)" % encostou)


# --- deslizar: diagonal contra o muro (3 elipses em fila), o corpo anda ao longo do topo
func teste_desliza_no_muro() -> void:
	Colisao.limpar()
	Colisao.adicionar_objeto(Vector2(400, 300), _formas_por_nome["muro"])
	var raio := 6.0
	# Chega pela frente do muro (de baixo), andando para cima e para a direita: o corpo desliza para a direita
	# ao longo da face e passa a ponta direita (o muro vai de x = 370 a 431, com a base em y = 300).
	var p := Vector2(360, 340)
	var dentro := 0
	var x_saida := -1.0  # x quando o corpo passa da ponta (x > 440): -1 = nunca passou, travou
	for _passo in 400:
		p = Colisao.resolver(p + Vector2(0.6, -0.8), raio)
		if not Colisao.livre(p, raio):
			dentro += 1
		if p.x > 440.0:
			x_saida = p.x
			break
	ok(dentro == 0, "muro: o corpo nunca entra no muro (%d passos)" % dentro)
	ok(x_saida > 440.0, "muro: desliza ao longo da face e passa a ponta (x=%.1f, esperado > 440; -1 = travou)" % x_saida)


# --- torii: o corpo passa entre os dois pilares (formas reais) e para diante de um pilar
func teste_torii() -> void:
	Colisao.limpar()
	Colisao.adicionar_objeto(Vector2(300, 300), _formas_por_nome["torii"])
	var raio := 6.0
	for x0 in [296.0, 300.0, 304.0]:
		var p := Vector2(x0, 200)
		var dentro := 0
		for _passo in 200:
			p = Colisao.resolver(p + Vector2(0, 1), raio)
			if not Colisao.livre(p, raio):
				dentro += 1
		ok(dentro == 0, "torii x=%d: nenhum passo dentro dos pilares" % x0)
		ok(p.y > 330.0, "torii x=%d: passa entre os pilares (y=%.1f)" % [x0, p.y])
	var em_cima := Vector2(269, 200)  # em cima do pilar da esquerda: para antes dele
	for _passo in 200:
		em_cima = Colisao.resolver(em_cima + Vector2(0, 1), raio)
	ok(em_cima.y < 283.0, "torii: o pilar da esquerda bloqueia (y=%.1f)" % em_cima.y)


# --- fila de arvores: andando para baixo no meio da fila, o corpo nao atravessa
func teste_fila_de_arvores() -> void:
	Colisao.limpar()
	var arvore: Array = _formas_por_nome["arvore"]
	for x in range(0, 141, 20):
		Colisao.adicionar_objeto(Vector2(x, 300), arvore)
	var raio := 6.0
	for x in [70.0, 75.0, 85.0, 90.0]:
		var p := Vector2(x, 200)
		var dentro := 0
		for _passo in 200:
			p = Colisao.resolver(p + Vector2(0, 1), raio)
			if not Colisao.livre(p, raio):
				dentro += 1
		ok(dentro == 0, "fila x=%d: nenhum passo dentro de uma arvore" % int(x))
		ok(p.y < 290.0, "fila x=%d: nao atravessa a fila (y=%.1f)" % [int(x), p.y])


# --- formas vazias (arbusto, cogumelos, juncos, raizes) nao bloqueiam
func teste_atravessaveis() -> void:
	Colisao.limpar()
	for nome in ["arbusto", "cogumelos", "juncos", "raizes"]:
		Colisao.adicionar_objeto(Vector2(100, 100), _formas_por_nome[nome])
	ok(Colisao.livre(Vector2(100, 100), 8.0), "atravessaveis: nao bloqueiam")


# --- caixa: 8 direcoes a partir de fora, andando para o centro, nunca termina dentro e para encostado na face/canto
func teste_caixa_oito_direcoes() -> void:
	Colisao.limpar()
	var pe := Vector2(300, 200)
	Colisao.adicionar_objeto(pe, [{"tipo": "caixa", "centro": [0, -10], "meio": [20, 10]}])
	var raio := 8.0
	var c := pe + Vector2(0, -10)
	var dentro := 0
	var encostou := 0
	for i in 8:
		var dir := Vector2.RIGHT.rotated(i * TAU / 8.0)
		var p := c + dir * 90.0
		ok(Colisao.livre(p, raio), "caixa direcao %d: comeca livre" % i)
		for _passo in 300:
			p = Colisao.resolver(p + (c - p).normalized() * 0.5, raio)  # sempre rumo ao centro
			if not Colisao.livre(p, raio):
				dentro += 1
		# distancia do centro do corpo ao retangulo = raio (com folga)
		var q := p - c
		var d := Vector2(maxf(absf(q.x) - 20.0, 0.0), maxf(absf(q.y) - 10.0, 0.0)).length()
		if absf(d - raio) < 0.5 and absf(q.x) <= 20.0 + raio + 0.5 and absf(q.y) <= 10.0 + raio + 0.5:
			encostou += 1
	ok(dentro == 0, "caixa 8 direcoes: nenhum passo termina dentro (%d passos dentro)" % dentro)
	ok(encostou == 8, "caixa 8 direcoes: para encostado (%d de 8)" % encostou)


# --- caixa: diagonal contra a face de baixo, o corpo desliza ao longo dela e passa a ponta
func teste_caixa_desliza() -> void:
	Colisao.limpar()
	Colisao.adicionar_objeto(Vector2(400, 300), [{"tipo": "caixa", "centro": [0, -15], "meio": [30, 15]}])  # x 370..430, y 270..300
	var raio := 6.0
	var p := Vector2(360, 340)
	var dentro := 0
	var x_saida := -1.0
	for _passo in 400:
		p = Colisao.resolver(p + Vector2(0.6, -0.8), raio)
		if not Colisao.livre(p, raio):
			dentro += 1
		if p.x > 440.0:
			x_saida = p.x
			break
	ok(dentro == 0, "caixa desliza: nunca entra (%d passos)" % dentro)
	ok(x_saida > 440.0, "caixa desliza: anda ao longo da face e passa a ponta (x=%.1f; -1 = travou)" % x_saida)
	# a face de baixo e plana: durante o deslize o corpo fica a raio + folga dela (y = 300 + raio)
	var q := Vector2(400, 340)
	for _passo in 100:
		q = Colisao.resolver(q + Vector2(0, -1), raio)
	ok(absf(q.y - (300.0 + raio)) < 0.1, "caixa desliza: para na face de baixo (y=%.2f, esperado %.2f)" % [q.y, 300.0 + raio])


# --- caixa: canto convexo nao prende (mirando perto do canto, o corpo contorna e segue)
func teste_caixa_canto() -> void:
	Colisao.limpar()
	Colisao.adicionar_objeto(Vector2(300, 210), [{"tipo": "caixa", "centro": [0, -20], "meio": [20, 20]}])  # x 280..320, y 170..210
	var raio := 6.0
	# canto superior esquerdo (280, 170): mira um pouco a direita (vai deslizar sobre o topo) e um pouco abaixo (face esquerda)
	for caso in [
		{"ini": Vector2(250, 140), "dir": Vector2(1, 0.9), "fim_x": 340.0, "fim_y": 1e9},
		{"ini": Vector2(250, 140), "dir": Vector2(0.9, 1), "fim_x": 1e9, "fim_y": 230.0}
	]:
		var p: Vector2 = caso["ini"]
		var dentro := 0
		var passou := false
		for _passo in 500:
			p = Colisao.resolver(p + (caso["dir"] as Vector2).normalized(), raio)
			if not Colisao.livre(p, raio):
				dentro += 1
			if p.x > caso["fim_x"] or p.y > caso["fim_y"]:
				passou = true
				break
		ok(dentro == 0, "caixa canto %s: nunca entra" % str(caso["dir"]))
		ok(passou, "caixa canto %s: contorna o canto sem prender (p=%s)" % [str(caso["dir"]), str(p)])


# --- caixa: corpo nascido dentro sai pelo lado mais curto
func teste_caixa_nascido_dentro() -> void:
	Colisao.limpar()
	Colisao.adicionar_objeto(Vector2(300, 210), [{"tipo": "caixa", "centro": [0, -20], "meio": [30, 20]}])  # centro (300, 190), x 270..330, y 170..210
	var raio := 6.0
	var c := Vector2(300, 190)
	# (pos, eixo esperado, sinal)
	var casos := [
		[Vector2(325, 190), Vector2(1, 0)],  # perto da face direita
		[Vector2(275, 190), Vector2(-1, 0)],  # perto da face esquerda
		[Vector2(300, 175), Vector2(0, -1)],  # perto do topo
		[Vector2(300, 205), Vector2(0, 1)],  # perto da base
		[Vector2(310, 172), Vector2(0, -1)],  # perto do topo, fora do centro
	]
	for caso in casos:
		var p0: Vector2 = caso[0]
		var n: Vector2 = caso[1]
		var p := Colisao.resolver(p0, raio)
		ok(Colisao.livre(p, raio), "caixa dentro %s: termina livre (%s)" % [str(p0), str(p)])
		var andou := p - p0
		ok(andou.normalized().dot(n) > 0.999, "caixa dentro %s: sai pelo lado mais curto (andou %s, esperado eixo %s)" % [str(p0), str(andou), str(n)])
		var lado := absf((p - c).x) if n.x != 0.0 else absf((p - c).y)
		var meio := 30.0 if n.x != 0.0 else 20.0
		ok(absf(lado - (meio + raio)) < 0.1, "caixa dentro %s: para a raio da face (%.2f)" % [str(p0), lado])
	# o centro exato nao pode travar nem dar NaN
	var pc := Colisao.resolver(c, raio)
	ok(is_finite(pc.x) and is_finite(pc.y) and Colisao.livre(pc, raio), "caixa dentro: centro exato sai sem NaN (%s)" % str(pc))
	# caixas e elipses juntas: a grade, o livre e a formas_no_retangulo enxergam os dois tipos
	Colisao.adicionar_objeto(Vector2(500, 210), [{"tipo": "elipse", "centro": [0, -10], "raio": [20, 10]}])
	var fs := Colisao.formas_no_retangulo(Rect2(0, 0, 800, 400))
	ok(fs.size() == 2, "formas_no_retangulo: caixa e elipse (%d)" % fs.size())
	ok(Colisao.segmento_perto(Vector2(250, 190), Vector2(275, 190), 6.0), "segmento_perto: enxerga a caixa")
	ok(not Colisao.segmento_perto(Vector2(900, 900), Vector2(920, 900), 6.0), "segmento_perto: longe de tudo")


# --- desempenho: 500 corpos x 150 objetos, uma passada de resolver
func teste_desempenho() -> void:
	Colisao.limpar()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260111
	var pes: Array = []
	for _i in 150:
		var pe := Vector2(rng.randf_range(0.0, 960.0), rng.randf_range(0.0, 540.0))
		var rx := rng.randf_range(4.0, 14.0)
		pes.append(pe)
		Colisao.adicionar_objeto(pe, [{"tipo": "elipse", "centro": [0.0, -rx * 0.5], "raio": [rx, rx * 0.5]}])
	var corpos: Array = []
	for i in 500:
		var perto: Vector2 = pes[i % pes.size()]
		corpos.append(perto + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-30.0, 30.0)))
	# Cinco passadas completas (500 resolver cada) e a mediana: o tempo da maquina oscila com a carga do sistema.
	var tempos: Array = []
	for _rep in 5:
		var c := corpos.duplicate()
		var t0 := Time.get_ticks_usec()
		for i in 500:
			c[i] = Colisao.resolver(c[i], 8.0)
		tempos.append(Time.get_ticks_usec() - t0)
	tempos.sort()
	var dt: int = tempos[2]
	print(
		(
			"v2_colisao desempenho: uma passada de resolver, 500 corpos x 150 objetos = %d us (mediana de 5; min %d, max %d; meta %d us, limite %d us)"
			% [dt, tempos[0], tempos[4], META_US, int(META_US * MARGEM)]
		)
	)
	# No CI (variável CI do GitHub) a máquina é compartilhada e o tempo absoluto oscila (deu 8,1 ms com 4 cenas em
	# paralelo); lá o número só é impresso. Na máquina de quem desenvolve, o limite vale.
	if OS.get_environment("CI") != "":
		if dt >= META_US * MARGEM:
			print("AVISO v2_colisao: desempenho %d us acima do limite %d us (só aviso no CI)" % [dt, int(META_US * MARGEM)])
	else:
		ok(dt < META_US * MARGEM, "desempenho: %d us acima do limite %d us" % [dt, int(META_US * MARGEM)])


func _ready() -> void:
	_formas_por_nome = carregar_cenario()
	ok(_formas_por_nome.size() == 28, "cenario.json tem 28 itens (%d)" % _formas_por_nome.size())
	ok(_formas_por_nome.get("torii", []).size() == 2, "torii tem 2 formas (uma por pilar)")
	ok(_formas_por_nome.get("muro", []).size() == 1, "muro tem uma elipse larga (sem quina entre formas)")
	teste_oito_direcoes()
	teste_desliza_no_muro()
	teste_torii()
	teste_fila_de_arvores()
	teste_atravessaveis()
	teste_caixa_oito_direcoes()
	teste_caixa_desliza()
	teste_caixa_canto()
	teste_caixa_nascido_dentro()
	teste_desempenho()
	print("v2_colisao falhas=%d" % falhas)
	get_tree().quit()
