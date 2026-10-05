extends RefCounted
## Diretor das hordas: decide quantos vírus nascem, de que tipo e quando.
## Ideia do Risk of Rain 2: um "coeficiente" cresce com o tempo; o diretor ganha créditos
## proporcionais a ele e gasta comprando inimigos (fraco = barato, forte = caro).
## Ideia do Vampire Survivors: um mínimo de vivos por minuto e eventos marcados (chefe, anel, enxame).
## Tudo configurado em dados/fase.json.

var arena: Node
var tempo := 0.0
var creditos := 0.0
var final_chamado := false
var enxame_final := false
var _feitos := {}
var _fase: Dictionary
var _dif: Dictionary


func iniciar(a: Node) -> void:
	arena = a
	_fase = Dados.json("fase")
	_dif = _fase.get("dificuldade", {})


func minutos() -> float:
	return tempo / 60.0


func coeficiente() -> float:
	var c := 1.0 + minutos() * float(_dif.get("por_minuto", 0.35))
	c *= 1.0 + 0.3 * (arena.jogadores() - 1)
	return c


func nivel() -> int:
	return 1 + int((coeficiente() - 1.0) / 0.33)


func atualizar(dt: float) -> void:
	tempo += dt
	var mult := 1.0
	if enxame_final:
		var depois := tempo - float(_fase.get("duracao", 600))
		mult = float(_dif.get("enxame_final_multiplicador", 3.0)) * (1.0 + depois / 30.0)
	creditos += float(_dif.get("creditos_base", 1.5)) * pow(coeficiente(), float(_dif.get("expoente", 1.3))) * mult * dt
	_eventos()
	_gastar()


func _eventos() -> void:
	for i in _fase.get("eventos", []).size():
		var ev: Dictionary = _fase.eventos[i]
		if _feitos.has(i) or tempo < float(ev.get("tempo", 0)):
			continue
		_feitos[i] = true
		var tipo := str(ev.get("inimigo", "bug"))
		var n := int(ev.get("quantos", 1))
		var c: Vector2 = arena.jogador.centro()
		match str(ev.get("tipo", "")):
			"chefe":
				arena.inimigos.criar(tipo, _ponto_fora(), nivel())
				arena.anunciar("Chefe: " + str(Dados.json("inimigos").get(tipo, {}).get("nome", tipo)), Color(1, 0.4, 0.4))
				Som.tocar("tremor")
				arena.tremer(6)
			"anel":
				for k in n:
					arena.inimigos.criar(tipo, c + Vector2.from_angle(TAU * k / n) * 230.0, nivel())
				arena.anunciar("Cercado!", Color(1, 0.8, 0.4))
			"enxame":
				var lado := Vector2.from_angle(randf() * TAU)
				var base := c + lado * 400.0
				for k in n:
					arena.inimigos.criar(tipo, base + lado.orthogonal() * randf_range(-180, 180) + lado * randf_range(0, 80), nivel())
				arena.anunciar("Enxame!", Color(1, 0.8, 0.4))
	var dur := float(_fase.get("duracao", 600))
	if tempo >= dur and not final_chamado:
		final_chamado = true
		enxame_final = true
		var chefe := str(_fase.get("chefe_final", "tela_azul"))
		arena.inimigos.criar(chefe, _ponto_fora(), nivel())
		arena.anunciar(str(Dados.json("inimigos").get(chefe, {}).get("nome", chefe)).to_upper() + "!", Color(0.4, 0.6, 1))
		arena.chefe_final_chegou()
		Som.tocar("tremor")
		arena.tremer(10)


func _gastar() -> void:
	var vivos: int = arena.inimigos.vivos()
	var limite := int(_dif.get("limite_vivos", 500))
	if vivos >= limite:
		return
	var tabela := _disponiveis()
	if tabela.is_empty():
		return
	# mínimo de vivos: se a tela está vazia demais, cria de graça
	var minimo := int(float(_dif.get("minimo_vivos_base", 12)) + minutos() * float(_dif.get("minimo_vivos_por_minuto", 20)))
	var criados := 0
	while vivos < mini(minimo, limite) and criados < 8:
		_criar_grupo(_sortear(tabela), 1)
		vivos += 1
		criados += 1
	# compra com os créditos
	var tentativas := 0
	while creditos > 0 and tentativas < 6 and vivos < limite:
		tentativas += 1
		var tipo := _sortear(tabela)
		var d: Dictionary = Dados.json("inimigos")[tipo]
		var g: Array = d.get("grupo", [1, 1])
		var n := randi_range(int(g[0]), int(g[1]))
		var custo := float(d.get("custo", 1)) * n
		if custo > creditos:
			break
		creditos -= custo
		_criar_grupo(tipo, n)
		vivos += n


func _disponiveis() -> Array:
	var res := []
	var inim: Dictionary = Dados.json("inimigos")
	for k in inim:
		if k.begins_with("_") or not inim[k] is Dictionary:
			continue
		var d: Dictionary = inim[k]
		if float(d.get("peso", 0)) > 0 and minutos() >= float(d.get("desde", 0)):
			res.append(k)
	return res


func _sortear(tabela: Array) -> String:
	var inim: Dictionary = Dados.json("inimigos")
	var total := 0.0
	for k in tabela:
		total += float(inim[k].get("peso", 1))
	var r := randf() * total
	for k in tabela:
		r -= float(inim[k].get("peso", 1))
		if r <= 0:
			return k
	return tabela[0]


func _criar_grupo(tipo: String, n: int) -> void:
	var p := _ponto_fora()
	var chance_elite := minutos() * float(_dif.get("chance_elite_por_minuto", 0.004))
	for i in n:
		arena.inimigos.criar(tipo, p + Vector2(randf_range(-20, 20), randf_range(-20, 20)), nivel(), randf() < chance_elite)


## Um ponto fora da tela, num anel em volta do jogador (mais na direção em que ele anda).
func _ponto_fora() -> Vector2:
	var jog: Node2D = arena.jogador
	var ang := randf() * TAU
	if jog.direcao_mov() != Vector2.ZERO and randf() < 0.5:
		ang = jog.direcao_mov().angle() + randf_range(-1.2, 1.2)
	return jog.centro() + Vector2.from_angle(ang) * randf_range(380, 430)
