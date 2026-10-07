extends RefCounted
## Mochila, baú pessoal e itens de viagem (#72, marcos 3 e 4). Só lógica pura e estática (o teste chama direto):
## regras de capacidade, validação (o anfitrião confere a mochila que vem pela rede com isto), contas do baú.
## Os dados ficam em dados/mochila.json (regras) e dados/itens.json (comida, consumíveis e amuletos).
## Uma mochila é {"itens": {id: quantidade}, "amuleto": id ou ""}; um baú é {id: quantidade} (amuletos inclusos).
## O baú de cada herói criado é guardado pelo criacao.gd junto da ficha dele; ao morrer, herói, mochila e baú somem juntos.

const Criacao := preload("res://scripts/hordas/criacao.gd")


static func cfg() -> Dictionary:
	return Dados.json("mochila")


static func lista() -> Array:
	return Dados.json("itens").get("lista", [])


## O item do catálogo, ou {} se o id não existe.
static func item(id) -> Dictionary:
	if not id is String or not id in lista():
		return {}
	var d = Dados.json("itens").get(id)
	return d if d is Dictionary else {}


static func tipo(id) -> String:
	return str(item(id).get("tipo", ""))


static func nome(id) -> String:
	return str(item(id).get("nome", str(id)))


static func vazia() -> Dictionary:
	return {"itens": {}, "amuleto": ""}


static func _inteiro(v) -> bool:
	return v is int or (v is float and v == floorf(v) and absf(v) < 1.0e6)


## Espaços da mochila deste herói: base + bônus da raça + bônus da classe.
static func capacidade(raca: String, classe: String) -> int:
	var c := cfg()
	return maxi(1, int(c.get("capacidade", 5)) + int(c.get("bonus_raca", {}).get(raca, 0)) + int(c.get("bonus_classe", {}).get(classe, 0)))


## Capacidade da mochila de um herói pelo id (c:h... ou c:raça:classe). Herói sem raça/classe conhecida: a base.
static func capacidade_de(heroi_id: String) -> int:
	var h: Dictionary = Dados.json("herois").get(heroi_id, {})
	return capacidade(str(h.get("raca", "")), str(h.get("classe", "")))


static func espacos(m: Dictionary) -> int:
	var n := 0
	var it = m.get("itens", {})
	if it is Dictionary:
		for id in it:
			n += int(item(id).get("espacos", 1)) * int(it[id])
	return n


static func comida_n(m: Dictionary) -> int:
	var n := 0
	for id in m.get("itens", {}):
		if tipo(id) == "comida":
			n += int(m.itens[id])
	return n


static func tipos_consumivel(m: Dictionary) -> int:
	var n := 0
	for id in m.get("itens", {}):
		if tipo(id) == "consumivel":
			n += 1
	return n


## Por que essa mochila não vale ("" = vale). Pode vir da rede: confere tipos, ids, faixas e todos os limites.
static func erro(m, raca: String, classe: String) -> String:
	if not m is Dictionary:
		return "mochila inválida"
	for k in m:
		if not k is String or not k in ["itens", "amuleto"]:
			return "mochila com campo desconhecido"
	var it = m.get("itens", {})
	if not it is Dictionary:
		return "itens inválidos"
	var c := cfg()
	for id in it:
		var d := item(id)
		if d.is_empty():
			return "item inexistente"
		if str(d.tipo) == "amuleto":
			return "amuleto fora do pescoço"
		var q = it[id]
		if not _inteiro(q) or int(q) < 1 or int(q) > int(d.get("max", 1)):
			return "quantidade fora da faixa em %s" % str(d.get("nome", id))
	var am = m.get("amuleto", "")
	if not am is String or (am != "" and tipo(am) != "amuleto"):
		return "amuleto inexistente"
	if comida_n(m) > int(c.get("max_comida", 2)):
		return "comida demais"
	if tipos_consumivel(m) > int(c.get("max_consumiveis", 3)):
		return "consumíveis demais"
	if espacos(m) > capacidade(raca, classe):
		return "mochila cheia demais (%d de %d espaços)" % [espacos(m), capacidade(raca, classe)]
	return ""


## A mochila limpa (só campos conhecidos, tipos certos), ou {} se não vale.
static func limpar(m, raca: String, classe: String) -> Dictionary:
	if erro(m, raca, classe) != "":
		return {}
	var itens := {}
	for id in m.get("itens", {}):
		itens[str(id)] = int(m.itens[id])
	return {"itens": itens, "amuleto": str(m.get("amuleto", ""))}


## Os consumíveis da mochila, na ordem do catálogo: o 1º é a tecla 1, o 2º a tecla 2 e assim por diante.
static func slots(m: Dictionary) -> Array:
	var r := []
	var it = m.get("itens", {})
	if it is Dictionary:
		for id in lista():
			if it.has(id) and tipo(id) == "consumivel" and int(it[id]) > 0:
				r.append(id)
	return r


static func comidas(m: Dictionary) -> Array:
	var r := []
	var it = m.get("itens", {})
	if it is Dictionary:
		for id in lista():
			if it.has(id) and tipo(id) == "comida" and int(it[id]) > 0:
				r.append(id)
	return r


static func vazio(m: Dictionary) -> bool:
	return m.get("itens", {}).is_empty() and str(m.get("amuleto", "")) == ""


## "pocao_cura:2,bomba,amuleto_corvo,pao_duro" -> mochila (atalho --mochila= dos testes). Item sem número = 1.
## Não confere limites: quem usa chama erro() depois.
static func de_texto(txt: String) -> Dictionary:
	var m := vazia()
	for p in txt.split(",", false):
		var kv := p.split(":")
		var id := kv[0].strip_edges()
		var n := int(kv[1]) if kv.size() > 1 else 1
		if tipo(id) == "amuleto":
			m["amuleto"] = id
		elif item(id).is_empty() == false and n > 0:
			m.itens[id] = n
	return m


# ---------------------------------------------------------------- baú

## Baú limpo: só ids que existem, quantidades inteiras e positivas.
static func bau_limpo(b) -> Dictionary:
	var r := {}
	if b is Dictionary:
		for id in b:
			if not item(id).is_empty() and _inteiro(b[id]) and int(b[id]) > 0:
				r[str(id)] = int(b[id])
	return r


static func kit_inicial() -> Dictionary:
	return bau_limpo(cfg().get("kit_inicial", {}))


## Espaços ocupados no baú (o amuleto também ocupa 1 lá dentro).
static func bau_espacos(b: Dictionary) -> int:
	var n := 0
	for id in b:
		n += maxi(1, int(item(id).get("espacos", 1))) * int(b[id])
	return n


static func bau_max() -> int:
	return int(cfg().get("bau_max", 24))


## Tem no baú tudo o que a mochila leva (itens e amuleto)?
static func cabe_no_bau(b: Dictionary, m: Dictionary) -> bool:
	for id in m.get("itens", {}):
		if int(b.get(id, 0)) < int(m.itens[id]):
			return false
	var am := str(m.get("amuleto", ""))
	return am == "" or int(b.get(am, 0)) >= 1


## O baú depois de tirar a mochila dele (sai de casa). Devolve {} se faltar item (não deve acontecer: a tela só deixa levar o que tem).
static func retirar(b: Dictionary, m: Dictionary) -> Dictionary:
	if not cabe_no_bau(b, m):
		return {}
	var r := b.duplicate()
	for id in m.get("itens", {}):
		r[id] = int(r[id]) - int(m.itens[id])
	var am := str(m.get("amuleto", ""))
	if am != "":
		r[am] = int(r[am]) - 1
	for id in r.keys():
		if int(r[id]) <= 0:
			r.erase(id)
	return r


## Trazer pra casa: devolve ao baú o que sobrou (uma mochila, com o amuleto) e os achados (lista de ids).
## Respeita o espaço do baú; o que não cabe se perde. Devolve {"bau": novo, "trazidos": {id: n}, "perdidos": {id: n}}.
static func trazer(b: Dictionary, sobra: Dictionary, achados: Array) -> Dictionary:
	var novo := b.duplicate()
	var trazidos := {}
	var perdidos := {}
	var fila := []   # [id, quantidade]
	for id in sobra.get("itens", {}):
		fila.append([str(id), int(sobra.itens[id])])
	if str(sobra.get("amuleto", "")) != "":
		fila.append([str(sobra.amuleto), 1])
	var max_achados := int(cfg().get("trazer_max", 3))
	for i in mini(achados.size(), max_achados):
		fila.append([str(achados[i]), 1])
	for par in fila:
		var id: String = par[0]
		if item(id).is_empty():
			continue
		var peso := maxi(1, int(item(id).get("espacos", 1)))
		for _k in int(par[1]):
			if bau_espacos(novo) + peso <= bau_max():
				novo[id] = int(novo.get(id, 0)) + 1
				trazidos[id] = int(trazidos.get(id, 0)) + 1
			else:
				perdidos[id] = int(perdidos.get(id, 0)) + 1
	return {"bau": novo, "trazidos": trazidos, "perdidos": perdidos}


## A mochila que dá pra montar com o que há no baú: pega o que a mochila `m` quer, na ordem do catálogo, e pára onde
## o baú, os espaços ou os limites não deixam. Vira a escolha inicial do Preparo (a última mochila, menos o que já foi gasto).
static func ajustar_ao_bau(m: Dictionary, bau: Dictionary, heroi_id: String) -> Dictionary:
	var r := vazia()
	var cap := capacidade_de(heroi_id)
	var c := cfg()
	var itens = m.get("itens", {})
	if itens is Dictionary:
		for id in lista():
			if not itens.has(id) or tipo(id) == "amuleto":
				continue
			var d := item(id)
			var q := mini(mini(int(itens[id]), int(bau.get(id, 0))), int(d.get("max", 1)))
			for _k in q:
				var peso := int(d.get("espacos", 1))
				if espacos(r) + peso > cap:
					break
				if str(d.tipo) == "comida" and comida_n(r) >= int(c.get("max_comida", 2)):
					break
				if str(d.tipo) == "consumivel" and not r.itens.has(id) and tipos_consumivel(r) >= int(c.get("max_consumiveis", 3)):
					break
				r.itens[id] = int(r.itens.get(id, 0)) + 1
	var am := str(m.get("amuleto", ""))
	if am != "" and tipo(am) == "amuleto" and int(bau.get(am, 0)) >= 1:
		r["amuleto"] = am
	return r


## Efeito no mundo dos vírus que só quem roda a IA (solo ou anfitrião) aplica: o gelo deixa os bichos em volta lentos.
static func aplicar_mundo(arena: Node, id: String, centro: Vector2) -> void:
	var ef: Dictionary = item(id).get("efeito", {})
	if str(ef.get("tipo", "")) != "lento" or arena.inimigos.espelho:
		return
	for v in arena.inimigos.no_circulo(centro, float(ef.get("raio", 150))):
		if "lento" in v:
			v.lento = maxf(float(v.lento), float(ef.get("tempo", 4.0)))


## Outro jogador usou um consumível (online): só mostra o aviso e a faísca no lugar onde ele está.
static func ver_outro(arena: Node, peer: int, id: String) -> void:
	var d := item(id)
	if d.is_empty():
		return
	var cor := Color(float(d.cor[0]), float(d.cor[1]), float(d.cor[2]))
	arena.mensagem("%s usou %s" % [Rede.nome_de(peer), str(d.get("nome", id))], cor)
	var r: Dictionary = Rede.remotos.get(peer, {})
	if not r.is_empty():
		arena.efeitos.explodir(Vector2(float(r.x), float(r.y) - 22.0), cor, 10, 90.0)


## "2 Poção de Cura, 1 Bomba de Pólvora" (para as mensagens). Vazio: "nada".
static func resumo(d: Dictionary) -> String:
	var l := []
	for id in lista():
		if d.has(id):
			l.append("%d %s" % [int(d[id]), nome(id)])
	return ", ".join(l) if not l.is_empty() else "nada"


## Uma linha por atributo do item (bom/ruim), pra tela de preparo: [[texto, bom], ...]. Reaproveita a descrição da criação.
static func linhas(id: String) -> Array:
	var d := item(id)
	var r: Array = Criacao.descrever(d.get("bonus", {}))
	var ef: Dictionary = d.get("efeito", {})
	if not ef.is_empty():
		match str(ef.get("tipo", "")):
			"cura":
				r.append(["cura %d%% da vida" % roundi(float(ef.frac) * 100.0), true])
			"buff":
				r.append(["por %d s:" % int(ef.tempo), true])
				r.append_array(Criacao.descrever(ef.get("bonus", {})))
			"escudo":
				r.append(["invencível por %s s" % str(ef.tempo).replace(".", ","), true])
			"explosao":
				r.append(["%d de dano em %d px" % [int(ef.dano), int(ef.raio)], true])
			"lento":
				r.append(["lentos por %d s (%d px)" % [int(ef.tempo), int(ef.raio)], true])
			"ima":
				r.append(["puxa as gemas do andar", true])
			"fenix":
				r.append(["levanta 1 vez com %d%% da vida" % roundi(float(ef.frac) * 100.0), true])
	if str(d.get("tipo", "")) == "comida":
		r.append(["vale por %d andares" % int(d.get("andares", 5)), true])
	return r


# ---------------------------------------------------------------- ícone desenhado no código (sem arte nova)

## Desenha o ícone do item (glifo e cor do itens.json) no retângulo r de qualquer CanvasItem. fraco = apagado (acabou).
static func desenhar_icone(c: CanvasItem, id: String, r: Rect2, fraco := false) -> void:
	var d := item(id)
	if d.is_empty():
		return
	var k: Array = d.get("cor", [0.8, 0.8, 0.8])
	var cor := Color(float(k[0]), float(k[1]), float(k[2]))
	var escuro := Color(0.06, 0.05, 0.08)
	if fraco:
		cor = cor.darkened(0.55)
	var u := r.size.x / 16.0
	var o := r.position
	var R := func(x: float, y: float, w: float, h: float, col: Color): c.draw_rect(Rect2(o + Vector2(x, y) * u, Vector2(w, h) * u), col)
	match str(d.get("glifo", "")):
		"pocao":
			R.call(3, 6, 10, 9, escuro)
			R.call(4, 7, 8, 7, cor)
			R.call(6, 2, 4, 5, escuro)
			R.call(7, 3, 2, 4, cor.lightened(0.3))
			R.call(6, 1, 4, 2, Color(0.55, 0.38, 0.2))
			R.call(5, 8, 2, 4, Color(1, 1, 1, 0.45))
		"bomba":
			c.draw_circle(o + Vector2(8, 10) * u, 6.0 * u, escuro)
			c.draw_circle(o + Vector2(8, 10) * u, 5.0 * u, cor.darkened(0.25) if not fraco else cor)
			c.draw_line(o + Vector2(9, 4.5) * u, o + Vector2(12, 1.5) * u, Color(0.6, 0.45, 0.25), maxf(1.0, u))
			R.call(11, 0, 3, 3, Color(1, 0.9, 0.3) if not fraco else cor)
			R.call(5, 8, 2, 2, Color(1, 1, 1, 0.45))
		"pergaminho":
			R.call(3, 3, 10, 11, escuro)
			R.call(4, 4, 8, 9, cor.lightened(0.35))
			R.call(2, 2, 12, 3, escuro)
			R.call(3, 3, 10, 1, cor)
			R.call(2, 12, 12, 3, escuro)
			R.call(3, 13, 10, 1, cor)
			for i in 3:
				R.call(5, 6 + i * 2, 6, 1, cor.darkened(0.4))
		"pao":
			R.call(1, 6, 14, 8, escuro)
			R.call(2, 7, 12, 6, cor)
			R.call(3, 5, 10, 2, escuro)
			R.call(4, 6, 8, 1, cor.lightened(0.25))
			R.call(4, 8, 2, 1, cor.darkened(0.3))
			R.call(8, 9, 3, 1, cor.darkened(0.3))
		"carne":
			c.draw_circle(o + Vector2(9, 8) * u, 6.0 * u, escuro)
			c.draw_circle(o + Vector2(9, 8) * u, 5.0 * u, cor)
			R.call(1, 11, 6, 2, escuro)
			R.call(2, 11, 5, 1, Color(0.95, 0.92, 0.8) if not fraco else cor)
			c.draw_circle(o + Vector2(8, 7) * u, 2.0 * u, cor.lightened(0.3))
		"caneca":
			R.call(2, 4, 10, 11, escuro)
			R.call(3, 6, 8, 8, cor)
			R.call(3, 4, 8, 3, Color(0.95, 0.95, 0.9) if not fraco else cor.lightened(0.2))
			R.call(12, 6, 3, 6, escuro)
		"amuleto":
			c.draw_line(o + Vector2(3, 1) * u, o + Vector2(8, 7) * u, Color(0.7, 0.7, 0.75), maxf(1.0, u * 0.8))
			c.draw_line(o + Vector2(13, 1) * u, o + Vector2(8, 7) * u, Color(0.7, 0.7, 0.75), maxf(1.0, u * 0.8))
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(8, 6) * u, o + Vector2(13, 11) * u, o + Vector2(8, 16) * u, o + Vector2(3, 11) * u]), escuro)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(8, 7.5) * u, o + Vector2(11.5, 11) * u, o + Vector2(8, 14.5) * u, o + Vector2(4.5, 11) * u]), cor)
			R.call(7, 9, 2, 2, Color(1, 1, 1, 0.6))
		_:
			R.call(3, 3, 10, 10, cor)
