extends "res://testes/isolamento_v2.gd"
## Pool por mapa: o mundo só pré-cria os monstros que o elenco do mapa pode fazer nascer (elenco + chefes), e não os de todos os mapas.
## Antes, cada mapa pré-criava ~780 monstros escondidos (golem 166, espectro 182, homúnculo 192, aldeão 64, corvo 64 + os 5 base), pesado no
## perfil Baixo (#127). Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pool_mapa.tscn  (imprime "v2_pool_mapa falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Mapas := preload("res://v2/mapas.gd")
## Os cinco inimigos que só os elencos usam (SPRITES_EXTRA), e o total que o mapa fora do elenco pré-criava (todos os sprites do pool).
const EXTRAS := ["inimigo_corvo_carniceiro", "inimigo_golem_vidro", "inimigo_espectro", "inimigo_homunculo", "inimigo_aldeao_morto"]
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var pool: Dictionary = Dados.json("v2_combate").pool
	var antes := 0  # o que o mundo pré-criava antes do conserto: o pool de todos os sprites, em todo mapa
	for nome in preload("res://v2/mundo.gd").SPRITES_MONSTRO:
		antes += int(pool.get(nome, 0))
	print("pool: antes do conserto, %d pré-criados por mapa" % antes)
	var elencos: Dictionary = Dados.json("v2_elencos").mapas
	for id in Mapas.ids():
		await _mapa(str(id), elencos, pool, antes)
	await _fallback()
	print("v2_pool_mapa falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


## Quantos monstros de cada tipo o mundo criou (vivos ou no pool): `_todos_monstros` guarda todos os nós.
func _contar(w) -> Dictionary:
	var c := {}
	for mo in w._todos_monstros:
		c[mo.chave] = int(c.get(mo.chave, 0)) + 1
	return c


func _mapa(id: String, elencos: Dictionary, pool: Dictionary, antes: int) -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = id
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var c := _contar(w)
	var total := 0
	for nome in c:
		total += int(c[nome])
	print("pool: mapa %s pré-criou %d monstros (antes do conserto: %d)" % [id, total, antes])
	var usados := {}
	if elencos.has(id):
		for tipo in elencos[id].tipos:
			usados[str(tipo.sprite)] = true
	else:
		for tipo in Dados.json("v2_combate").diretor.tipos:
			usados[str(tipo.sprite)] = true
	var especiais := _especiais(id, elencos)
	for nome in especiais:
		usados[nome] = true
	for nome in usados:
		ok(int(c.get(nome, 0)) == int(pool[nome]), "%s: %s tem o pool configurado (%d)" % [id, nome, int(pool[nome])])
	for nome in EXTRAS:
		if not usados.has(nome):
			ok(int(c.get(nome, 0)) == 0, "%s: %s fora do elenco não é pré-criado" % [id, nome])
	var teto := 0
	for nome in c:
		teto += int(pool.get(nome, 0))
	ok(total == teto, "%s: nada pré-criado além do pool configurado" % id)
	if id == "floresta":
		for nome in EXTRAS:
			ok(not c.has(nome), "floresta: nenhum dos 5 extras (%s)" % nome)
		ok(total < antes, "floresta: bem menos que os %d de antes" % antes)
	await _nascer_especiais(w, id, especiais)
	w.queue_free()
	await get_tree().process_frame


## Os sprites que o mapa faz nascer fora do sorteio comum: elite, pesado, invocados da elite (elenco do mapa) e os dos chefes (marcas e filhotes
## de dados/v2_cartas.json). Lido do JSON, sem chamar o elenco do jogo, para o teste não repetir a conta que testa.
func _especiais(id: String, elencos: Dictionary) -> Dictionary:
	var r := {}
	if not elencos.has(id):
		return r
	var m: Dictionary = elencos[id]
	for t in m.tipos:
		if int(t.get("elite_desde", -1)) >= 0 or str(t.id) == str(m.pesado) or str(t.id) in m.invocados:
			r[str(t.sprite)] = true
	var chefes: Dictionary = Dados.json("v2_cartas").chefes
	for mk in chefes.marcas:
		r[str(mk.tipo)] = true
	for at in chefes.ataques.values():
		if at is Dictionary and at.has("filhote"):
			r[str(at.filhote)] = true
	return r


## Nascer no meio da partida: cada tipo especial sai do pool pré-criado (`nascer_monstro` reusa o pool), e nenhum nó novo aparece.
func _nascer_especiais(w, id: String, especiais: Dictionary) -> void:
	var casos: Array = []  # [sprite, tipo do elenco (vazio para chefe)]
	for e in w.elenco.elites_lista:
		casos.append([str(e.sprite), e.tipo])
	casos.append([str(w.elenco.pesado.sprite), w.elenco.pesado])
	for k in 2:
		casos.append([str(w.elenco.invocado(k).sprite), w.elenco.invocado(k)])
	for nome in especiais:
		casos.append([nome, {}])  # chefes e o que não é de elenco (marca e filhote)
	var n0: int = w._todos_monstros.size()
	var i := 0
	for caso in casos:
		var m = w.nascer_monstro(str(caso[0]), w.heroi.pos + Vector2(200 + 10 * i, 0), true, 1.0, 1.0, caso[1])
		ok(m != null and m.vivo and m.chave == caso[0], "%s: %s nasce" % [id, caso[0]])
		i += 1
	ok(w._todos_monstros.size() == n0, "%s: nenhum nó novo no meio da partida (%d criados)" % [id, w._todos_monstros.size() - n0])
	await get_tree().process_frame


## Um tipo fora do elenco que nasce mesmo assim (roteiro, teste): o fallback cria o monstro na hora, sem quebrar.
func _fallback() -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = "floresta"
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var extra: String = EXTRAS[1]
	ok(not w._pool_monstros.has(extra), "fallback: a floresta não tem pool do golem")
	var n: int = w._todos_monstros.size()
	var m = w.nascer_monstro(extra, w.heroi.pos + Vector2(200, 0))
	ok(m != null and m.vivo and m.chave == extra, "fallback: o golem nasce mesmo assim")
	ok(w._todos_monstros.size() == n + 1, "fallback: um monstro novo criado")
	w.combate.limpar_partida()
	ok(w._pool_monstros.get(extra, []).size() == 1, "fallback: ao morrer volta para o pool do tipo")
	w.queue_free()
	await get_tree().process_frame
