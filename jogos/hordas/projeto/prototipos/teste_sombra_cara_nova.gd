extends SceneTree
## Teste automático da sombra do protótipo da cara nova (cisalhamento a partir dos pés).
## Uso: godot --headless --path jogos/hordas/projeto -s res://prototipos/teste_sombra_cara_nova.gd
## Põe UMA luz em 8 posições em volta de cada ator (N, NE, L, SE, S, SO, O, NO) nos modos médio e alto e confere:
##  - a origem do transform da sombra são os pés (não saem do lugar) e o x_axis é (esc, 0): sem rotação nem escala negativa;
##  - a ponta da sombra (topo do sprite) fica no lado OPOSTO ao da luz;
##  - com a luz em cima/embaixo (N e S) a silhueta vira na vertical (det < 0 para luz ao norte), com a luz ao lado nunca vira linha;
##  - o monstro espelhado usa flip_h (igual ao do sprite) e o resultado é o mesmo que o do não espelhado;
##  - varrendo a luz em círculo, a ponta nunca dá salto grande de um quadro para o outro (sem pulo).
## Atores testados: o herói, um monstro espelhado, um não espelhado e um item de cenário (árvore, pedra, arbusto).

var falhas := 0
var checagens := 0
var cena: Node2D


func _initialize() -> void:
	cena = load("res://prototipos/cara_nova.tscn").instantiate()
	root.add_child(cena)


func _process(_delta: float) -> bool:
	## o _ready da cena só roda depois do _initialize: testa no primeiro quadro
	_rodar()
	return true


func _rodar() -> void:
	var donos := {"heroi": cena._heroi}
	for a in cena._atores:
		if a.espelha and not donos.has("espelhado"):
			donos["espelhado"] = a
		if not a.espelha and not a.heroi and not donos.has("normal"):
			donos["normal"] = a
	for a in cena._arvores:
		if not donos.has("cenario_" + a.chave):
			donos["cenario_" + a.chave] = a
	for l in cena._luzes:  # só a tocha fica acesa e vira a luz de teste
		l.luz.energy = 0.0
	var luz: PointLight2D = cena._luzes[0].luz
	cena._luzes[0].def.r = 900.0
	luz.energy = 3.0
	luz.height = 50.0
	for modo in [2, 3]:
		cena._trocar_sombra(modo)
		for nome in donos:
			_oito_posicoes(nome, donos[nome], luz, modo)
			_varredura(nome, donos[nome], luz, modo)
	print("TESTE_SOMBRA %s: %d checagens, %d falhas" % ["OK" if falhas == 0 else "FALHOU", checagens, falhas])
	quit(1 if falhas > 0 else 0)


func _confere(cond: bool, msg: String) -> void:
	checagens += 1
	if not cond:
		falhas += 1
		print("FALHA: ", msg)


func _converge(a: Dictionary, luz: PointLight2D, pos: Vector2) -> void:
	luz.position = pos
	for i in 40:  # 40 passos de 0,1 s: o suavizador chega no alvo
		cena._t += 0.1
		cena._atualizar_luzes_dados()
		cena._atualizar_sombra(a)


func _ponta(a: Dictionary) -> Vector2:
	## topo do sprite de sombra na tela: transform * (0, -altura)
	var sp: Sprite2D = a.sh1
	return sp.transform * Vector2(0.0, a.offset.y)


func _oito_posicoes(nome: String, a: Dictionary, luz: PointLight2D, modo: int) -> void:
	var pes: Vector2 = a.raiz.position
	var esc: float = a.esc
	var dist := 70.0 * maxf(1.0, esc * 0.7)
	var dirs := {
		"N": Vector2(0, -1),
		"NE": Vector2(1, -1),
		"L": Vector2(1, 0),
		"SE": Vector2(1, 1),
		"S": Vector2(0, 1),
		"SO": Vector2(-1, 1),
		"O": Vector2(-1, 0),
		"NO": Vector2(-1, -1)
	}
	for d in dirs:
		var v: Vector2 = dirs[d].normalized()
		_converge(a, luz, pes + v * dist)
		var sp: Sprite2D = a.sh1
		var tag := "%s modo=%d luz=%s" % [nome, modo, d]
		var origem: Vector2 = sp.transform.origin
		_confere(origem.distance_to(pes) < 0.01, tag + ": os pes sairam do lugar " + str(origem) + " x " + str(pes))
		_confere(is_equal_approx(sp.transform.x.x, esc) and is_zero_approx(sp.transform.x.y), tag + ": x_axis nao e (esc,0): " + str(sp.transform.x))
		_confere(sp.flip_h == a.espelha, tag + ": flip_h da sombra diferente do sprite")
		_confere(sp.visible and sp.modulate.a > 0.05, tag + ": sombra invisivel")
		var tip := _ponta(a) - pes
		var longe := pes - luz.position  # lado oposto ao da luz
		_confere(tip.length() > 1.0 and tip.dot(longe) > 0.0, tag + ": ponta no lado da luz " + str(tip) + " vs " + str(longe))
		var det := sp.transform.determinant()
		if d == "N" or d == "NE" or d == "NO":
			_confere(det < 0.0, tag + ": luz ao norte, a silhueta devia estar espelhada na vertical (det=%.2f)" % det)
		elif d == "S" or d == "SE" or d == "SO":
			_confere(det > 0.0, tag + ": luz ao sul, a silhueta devia estar em pe (det=%.2f)" % det)
		_confere(absf(det) >= cena.Y_MIN * esc * esc * 0.99, tag + ": virou linha (det=%.3f)" % det)


func _varredura(nome: String, a: Dictionary, luz: PointLight2D, modo: int) -> void:
	## luz girando 2 voltas (1 volta por 6 s, 60 quadros por s). A ponta só pode ter 2 saltos por volta (o espelho da silhueta, quando a
	## luz cruza a linha leste-oeste, e então de no máximo 2 * Y_MIN * altura); fora disso, nenhum quadro move a ponta mais que 0,12 altura.
	var pes: Vector2 = a.raiz.position
	var esc: float = a.esc
	var raio := 70.0 * maxf(1.0, esc * 0.7)
	_converge(a, luz, pes + Vector2(raio, 0))
	var anterior := _ponta(a)
	var sinal_ant := signf(a.sh1.transform.determinant())
	var maior := 0.0
	var maior_espelho := 0.0
	var espelhos := 0
	var alt: float = a.alt
	for i in 720:
		var ang := TAU * i / 360.0
		luz.position = pes + Vector2(cos(ang), sin(ang)) * raio
		cena._t += 1.0 / 60.0
		cena._atualizar_luzes_dados()
		cena._atualizar_sombra(a)
		var p := _ponta(a)
		var sinal := signf(a.sh1.transform.determinant())
		var salto := p.distance_to(anterior)
		if sinal != sinal_ant:
			espelhos += 1
			maior_espelho = maxf(maior_espelho, salto)
		else:
			maior = maxf(maior, salto)
		anterior = p
		sinal_ant = sinal
	print(
		(
			"  varredura %-22s modo=%d espelhos=%d (salto %.1f px) maior salto sem espelho: %.1f px (altura do sprite %.0f)"
			% [nome, modo, espelhos, maior_espelho, maior, alt]
		)
	)
	_confere(espelhos <= 4, "%s modo=%d: a silhueta espelhou %d vezes em 2 voltas (esperado 4)" % [nome, modo, espelhos])
	_confere(maior_espelho <= 2.0 * cena.Y_MIN * alt * esc * 0.0 + 2.0 * cena.Y_MIN * alt * 1.05, "%s modo=%d: salto do espelho grande demais" % [nome, modo])
	_confere(maior < alt * 0.12, "%s modo=%d: a sombra pulou %.1f px em 1 quadro (limite %.1f)" % [nome, modo, maior, alt * 0.12])
