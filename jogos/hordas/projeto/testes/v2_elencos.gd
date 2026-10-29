extends "res://testes/isolamento_v2.gd"
# Teste dos ELENCOS por mapa (v2/elenco.gd e dados/v2_elencos.json, #430): cada mapa só faz nascer os inimigos do seu elenco (diretor, onda forte
# com a ponta pesada, moradores, defesa de ponto, elites e invocados da elite), os dados são válidos (sprite com folha, tinta, números), o
# orçamento de ameaça e de xp de cada elenco fica perto do padrão em cada marco do tempo (a curva de dificuldade não muda) e um mapa sem
# elenco cai no padrão de antes, com as mesmas contas de sorteio.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_elencos.tscn  (imprime "v2_elencos falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Elenco := preload("res://v2/elenco.gd")
const Mapas := preload("res://v2/mapas.gd")
const MARCOS := [0.0, 40.0, 75.0, 130.0, 300.0, 600.0]  # instantes (s) em que o orçamento é conferido: onde entra um tipo novo, e depois
const FOLGA_ORCAMENTO := 0.10
const SEM_ELENCO := "mapa_sem_elenco_teste"
const NOMES_PROIBIDOS := ["Cão de Ossos", "Aranha Tecelã", "Lobo Sombrio", "Espantalho", "Cavaleiro Oco"]  # nomes do padrão: não valem nos elencos
var falhas := 0
var cfg_dir: Dictionary
var cfg_elites: Dictionary
var monstros_cfg: Dictionary


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var comb: Dictionary = Dados.json("v2_combate")
	cfg_dir = comb.diretor
	monstros_cfg = comb.monstros
	cfg_elites = Dados.json("v2_cartas").elites
	_dados()
	_orcamento()
	_padrao()
	_sorteio_direto()
	for id in Mapas.ids():
		await _mundo_do_mapa(str(id), false)
	await _mundo_do_mapa(SEM_ELENCO, true)
	print("v2_elencos falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _elenco(id: String):
	var e = Elenco.new()
	e.montar(id, cfg_dir, cfg_elites)
	return e


## Os dados: todo mapa da lista tem elenco; cada tipo é válido; os nomes não se repetem entre mapas nem usam os nomes do padrão.
func _dados() -> void:
	var arq: Dictionary = Dados.json("v2_elencos")
	var tipos_sprite: Array = preload("res://v2/mundo.gd").SPRITES_MONSTRO
	var nomes_vistos := {}
	for id in Mapas.ids():
		var m: Variant = arq.mapas.get(id)
		ok(m is Dictionary, "%s: tem elenco em v2_elencos.json" % id)
		if not (m is Dictionary):
			continue
		var el = _elenco(str(id))
		ok(not el.padrao, "%s: o elenco foi lido (não caiu no padrão)" % id)
		var ids := {}
		var tem_d0 := false
		var elite_d0 := false
		for t in el.tipos:
			ok(not ids.has(t.id), "%s: id de tipo repetido (%s)" % [id, t.id])
			ids[t.id] = true
			ok(tipos_sprite.has(t.sprite), "%s/%s: sprite %s tem folha na v2 (SPRITES_MONSTRO)" % [id, t.id, t.sprite])
			ok(monstros_cfg.has(t.sprite), "%s/%s: sprite tem números em v2_combate.json > monstros" % [id, t.id])
			ok(str(t.nome).strip_edges() != "", "%s/%s: tem nome" % [id, t.id])
			ok(not NOMES_PROIBIDOS.has(t.nome), "%s/%s: nome %s é do elenco padrão" % [id, t.id, t.nome])
			ok(not nomes_vistos.has(t.nome), "%s/%s: nome %s já é de outro mapa (%s)" % [id, t.id, t.nome, nomes_vistos.get(t.nome)])
			nomes_vistos[t.nome] = id
			ok(t.peso >= 1, "%s/%s: peso >= 1" % [id, t.id])
			ok(t.desde >= 0.0, "%s/%s: desde >= 0" % [id, t.id])
			for k in ["vida", "dano", "vel"]:
				ok(t[k] >= 0.4 and t[k] <= 2.5, "%s/%s: %s fora de 0,4 a 2,5 (%f)" % [id, t.id, k, t[k]])
			var c: Color = t.tinta
			ok(c.r >= 0.0 and c.g >= 0.0 and c.b >= 0.0 and maxf(c.r, maxf(c.g, c.b)) <= 2.0, "%s/%s: tinta entre 0 e 2" % [id, t.id])
			ok(c != Color.WHITE, "%s/%s: a variação tem tinta própria" % [id, t.id])
			tem_d0 = tem_d0 or t.desde <= 0.0
			elite_d0 = elite_d0 or (t.elite_desde == 0)
		ok(tem_d0, "%s: tem tipo desde 0 (a partida abre com monstros)" % id)
		ok(elite_d0, "%s: tem tipo que pode ser elite desde 0" % id)
		ok(not el.pesado.is_empty() and ids.has(el.pesado.id), "%s: 'pesado' é um tipo do mapa" % id)
		ok(el.invocados.size() == 2, "%s: dois 'invocados' do mapa" % id)
		for t in el.invocados:
			ok(ids.has(t.id), "%s: invocado %s é do mapa" % [id, t.id])
		ok(el.elites_lista.size() >= 3, "%s: pelo menos 3 tipos de elite" % id)
	# o mapa da lista que não tem elenco cai no padrão; nenhuma chave sobra no arquivo sem mapa correspondente
	for id in arq.mapas.keys():
		ok(Mapas.ids().has(id), "v2_elencos.json: o elenco '%s' é de um mapa que existe" % id)


## A média ponderada de vida x dano x velocidade e de xp dos tipos possíveis em cada marco do tempo fica a FOLGA_ORCAMENTO do padrão.
func _media(el, t: float) -> Dictionary:
	var peso := 0.0
	var ameaca := 0.0
	var xp := 0.0
	for e in el.tipos:
		if t >= float(e.desde):
			var b: Dictionary = monstros_cfg[e.sprite]
			ameaca += float(e.peso) * float(b.vida) * float(e.vida) * float(b.dano) * float(e.dano) * float(b.vel) * float(e.vel)
			xp += float(e.peso) * float(b.xp)
			peso += float(e.peso)
	return {"ameaca": ameaca / peso, "xp": xp / peso}


func _orcamento() -> void:
	var pad = _elenco(SEM_ELENCO)
	for id in Mapas.ids():
		var el = _elenco(str(id))
		for t in MARCOS:
			var a := _media(el, t)
			var b := _media(pad, t)
			var ra: float = a.ameaca / b.ameaca
			var rx: float = a.xp / b.xp
			ok(absf(ra - 1.0) <= FOLGA_ORCAMENTO, "%s t=%d: ameaça média %.2fx a do padrão (limite %.0f%%)" % [id, t, ra, FOLGA_ORCAMENTO * 100.0])
			ok(absf(rx - 1.0) <= FOLGA_ORCAMENTO, "%s t=%d: xp médio %.2fx o do padrão" % [id, t, rx])


## Mapa sem elenco: o padrão, igual ao de antes (mesmos tipos, mesmos pesos, sem tinta, e a mesma sequência de sorteio do código antigo).
func _padrao() -> void:
	var el = _elenco(SEM_ELENCO)
	ok(el.padrao, "mapa sem elenco usa o padrão")
	ok(el.tipos.size() == cfg_dir.tipos.size(), "o padrão tem os mesmos tipos do diretor")
	ok(el.pesado.sprite == "inimigo_cavaleiro_oco", "padrão: a ponta pesada é o Cavaleiro Oco")
	ok(el.invocado(0).sprite == "inimigo_aranha_tecela" and el.invocado(1).sprite == "inimigo_cao_ossos", "padrão: invocados são aranha e cão")
	ok(el.elites_lista.size() == cfg_elites.tipos.size(), "padrão: as elites vêm de v2_cartas.json > elites > tipos")
	for e in el.tipos:
		ok(e.liso and e.tinta == Color.WHITE and e.vida == 1.0 and e.dano == 1.0 and e.vel == 1.0, "padrão: %s nasce puro" % e.sprite)
	ok(el.sortear_qualquer(RandomNumberGenerator.new()).is_empty(), "padrão: moradores seguem o sorteio antigo do mundo")
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 7777
	r2.seed = 7777
	for i in 400:
		var t := float(i) * 1.5
		ok(el.sortear(t, r1).sprite == _sortear_antigo(t, r2), "padrão: o sorteio %d coincide com o do código antigo" % i)


func _sortear_antigo(t: float, rng: RandomNumberGenerator) -> String:
	var total := 0
	for e in cfg_dir.tipos:
		if t >= float(e.desde):
			total += int(e.peso)
	var r := rng.randi() % maxi(total, 1)
	for e in cfg_dir.tipos:
		if t >= float(e.desde):
			r -= int(e.peso)
			if r < 0:
				return str(e.sprite)
	return str(cfg_dir.tipos[0].sprite)


## Sorteio sem mundo: milhares de sorteios por mapa só dão tipos do elenco, e só os que já podem nascer naquele instante.
func _sorteio_direto() -> void:
	for id in Mapas.ids():
		var el = _elenco(str(id))
		var ids := {}
		for t in el.tipos:
			ids[t.id] = t
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var vistos := {}
		for t in [0.0, 30.0, 60.0, 100.0, 200.0, 500.0]:
			for i in 1500:
				var s: Dictionary = el.sortear(t, rng)
				ok(ids.has(s.id), "%s: sorteou '%s' que não é do elenco" % [id, s.id])
				ok(float(s.desde) <= t, "%s t=%d: sorteou %s antes do desde" % [id, t, s.id])
				vistos[s.id] = true
		ok(vistos.size() == el.tipos.size(), "%s: com tempo todos os tipos aparecem (%d de %d)" % [id, vistos.size(), el.tipos.size()])
		var qualquer := {}
		for i in 1500:
			qualquer[el.sortear_qualquer(rng).id] = true
		ok(qualquer.size() == el.tipos.size(), "%s: moradores sorteiam entre todos os tipos" % id)


## Com o mundo de verdade: moradores, diretor, onda forte, elites e invocados. `sem` = o mapa não tem elenco (tudo puro, dos 5 sprites).
func _mundo_do_mapa(id: String, sem: bool) -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = id
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	var el = w.elenco
	ok(el.padrao == sem, "%s: o mundo montou o elenco certo (padrão=%s)" % [id, el.padrao])
	var ids := {}
	var sprites_padrao: Array = w.TIPOS_MONSTRO
	for t in el.tipos:
		ids[t.id] = t
	# moradores do começo
	ok(w.monstros.size() > 0, "%s: há moradores" % id)
	_confere(w, w.monstros.duplicate(), ids, sem, sprites_padrao, "%s morador" % id)
	# diretor (sem o relógio): sorteio por tempo de partida
	w.combate.diretor.ligado = false
	var antes: int = w.monstros.size()
	var novos: Array = []
	for t in [0.0, 50.0, 100.0, 200.0, 400.0]:
		w.tempo_partida = t
		for i in 30:
			var tp: Dictionary = w.combate.diretor.sortear(t)
			var n0: int = w.monstros.size()
			if w.combate.diretor.nascer(str(tp.sprite), null, tp):
				novos.append(w.monstros[n0])
	ok(w.monstros.size() > antes + 100, "%s: o diretor fez nascer monstros (%d)" % [id, w.monstros.size() - antes])
	_confere(w, novos, ids, sem, sprites_padrao, "%s diretor" % id)
	# os números e a tinta da variação chegam ao monstro
	if not sem:
		var tp: Dictionary = el.tipos[0]
		var base: Dictionary = w.combate.cfg.monstros[tp.sprite]
		w.tempo_partida = 0.0
		w.combate.diretor.nascer(str(tp.sprite), Vector2(1400, 800), tp)
		var m = w.monstros[w.monstros.size() - 1]
		var kv: float = w.fator_pesadelo("vida_mult")
		ok(absf(m.vida_max - float(base.vida) * float(tp.vida) * kv) < 0.01, "%s: a vida do tipo é a do sprite x o multiplicador" % id)
		ok(m.tinta == tp.tinta and m.variante == tp.id, "%s: a tinta e o id da variação chegam ao monstro" % id)
		ok(
			is_equal_approx(m.dano, float(base.dano) * float(tp.dano) * w.fator_pesadelo("dano_mult")),
			"%s: o dano do tipo é o do sprite x o multiplicador" % id
		)
	# onda forte: o anel inclui a ponta pesada do mapa e nada de fora do elenco
	for m in w.monstros.duplicate():
		m.vivo = false
		w.devolver_monstro(m)
	w.tempo_partida = 400.0
	w.combate.diretor.onda_forte()
	var anel: Array = w.monstros.duplicate()
	ok(anel.size() >= 10, "%s: a onda forte fez nascer um anel (%d)" % [id, anel.size()])
	_confere(w, anel, ids, sem, sprites_padrao, "%s onda forte" % id)
	var pesados := 0
	for m in anel:
		if m.chave == el.pesado.sprite and (sem or m.variante == el.pesado.id):
			pesados += 1
	ok(pesados >= int(w.combate.cfg.diretor.onda_elite), "%s: a ponta pesada (%s) abre a onda forte" % [id, el.pesado.id])
	# elites e invocados
	var ele: Array = []
	for i in 40:
		w.tempo_partida = [0.0, 70.0, 120.0, 400.0][i % 4]
		var e = w.combate.elites.nascer("", "", w.heroi.pos + Vector2(120, -10))
		ok(e != null, "%s: elite nasceu" % id)
		if e != null:
			ele.append(e)
			if not sem:
				ok(ids.has(e.variante) and int(ids[e.variante].elite_desde) >= 0, "%s: elite '%s' é um tipo de elite do mapa" % [id, e.variante])
				ok(float(ids[e.variante].elite_desde) <= w.tempo_partida, "%s: elite '%s' nasceu antes do tempo" % [id, e.variante])
				ok(e.tinta != Color.WHITE, "%s: a elite leva a tinta do tipo" % id)
			else:
				ok(e.variante == "" and sprites_padrao.has(e.chave), "%s: a elite do mapa sem elenco é pura" % id)
	var inv = w.combate.elites.nascer("", "invoca", w.heroi.pos + Vector2(60, 0))
	w.combate.elites._invocar(inv)
	var filhos: Array = w.combate.elites._filhos.get(inv, [])
	ok(filhos.size() >= 1, "%s: a elite Invocadora fez nascer filhotes" % id)
	_confere(w, filhos, ids, sem, sprites_padrao, "%s invocado" % id)
	w.queue_free()
	await get_tree().process_frame


## Todos os `lista` são do elenco: com elenco, a variante é um id dele e o sprite é o do tipo; sem, são puros e dos 5 sprites.
func _confere(w, lista: Array, ids: Dictionary, sem: bool, sprites_padrao: Array, rotulo: String) -> void:
	var ruins := 0
	for m in lista:
		if sem:
			if m.variante != "" or not sprites_padrao.has(m.chave):
				ruins += 1
		elif not ids.has(m.variante) or m.chave != ids[m.variante].sprite:
			ruins += 1
	ok(ruins == 0, "%s: %d de %d monstros fora do elenco" % [rotulo, ruins, lista.size()])
