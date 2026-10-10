extends RefCounted
## Mapa fechado de cada fase (#128, marco 4): uma grade de azulejos com relevo, estruturas e perigos, montada com peças
## pré-desenhadas (dados/mapa_fase.json) a partir das streams da Sorte. Puro (só semente + dados): todo cliente com a
## mesma semente monta o mesmo mapa. Conectividade garantida: todo ponto que anda alcança o portal.
## A grade é só dado aqui; o desenho, a colisão e o minimapa ficam com quem usa (arena e minimapa).

const Sorte := preload("res://scripts/hordas/sorte.gd")
const Regioes := preload("res://scripts/hordas/regioes.gd")

const PASSAVEIS := ".=lpes"   # chão, ponte e os perigos (espinho, veneno, lodo, gelo): dá para andar
const CARDINAIS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func cfg() -> Dictionary:
	return Dados.json("mapa_fase")


static func passavel(ch: String) -> bool:
	return PASSAVEIS.contains(ch)


## Mapa de uma fase: {largura, altura, linhas, inicio, portal, regiao, andar, ok}. `linhas` é a grade em texto (uma string por linha).
## Regiao e andar (dentro da região) escolhem as peças e o portão; a semente vem de Sorte.iniciar().
static func gerar(regiao: String, andar: int) -> Dictionary:
	var m := {}
	for t in int(cfg().get("tentativas", 20)):
		m = _montar(regiao, andar, t)
		if m.ok:
			break
	return m


static func _montar(regiao: String, andar: int, tent: int) -> Dictionary:
	var c := cfg()
	var w := int(c.get("largura", 40))
	var h := int(c.get("altura", 24))
	var rng := Sorte.criar("mapa_fase_" + regiao, andar * 100 + tent)
	var g := PackedStringArray()
	g.resize(w * h)
	g.fill(".")
	for x in w:   # borda de relevo: nada sai do mapa
		g[x] = "#"
		g[(h - 1) * w + x] = "#"
	for y in h:
		g[y * w] = "#"
		g[y * w + w - 1] = "#"
	var pecas: Dictionary = c.get("pecas", {})
	var ids := _ids_da_regiao(pecas, regiao)
	var n := rng.randi_range(int(c.get("pecas_min", 12)), int(c.get("pecas_max", 20)))
	for _i in n:
		if ids.is_empty():
			break
		var rows: Array = pecas[Sorte.escolher(rng, ids)].mapa
		var pw := str(rows[0]).length()
		var ph := rows.size()
		if pw > w - 2 or ph > h - 2:
			continue
		_carimbar(g, w, rows, rng.randi_range(1, w - pw - 1), rng.randi_range(1, h - ph - 1))
	var por_regiao: Dictionary = c.get("portoes", {}).get(regiao, {})   # um portão por região (dados/mapa_fase.json > portoes)
	var portao: Array = por_regiao.get("linhas", c.get("portao", []))
	if portao.is_empty():
		return {"ok": false}
	var tema := str(por_regiao.get("tema", c.get("temas_portao", {}).get(regiao, "x")))
	var gw := str(portao[0]).length()
	var gh := portao.size()
	var gx := rng.randi_range(1, w - gw - 1)
	var gy := rng.randi_range(1, h - gh - 1)
	for j in gh:
		var linha := str(portao[j])
		for i in gw:
			var ch := linha[i]
			g[(gy + j) * w + gx + i] = tema if ch == "G" else ch
	var pn: Array = c.get("portal_no_portao", [8, 7])
	var portal := Vector2i(gx + int(pn[0]), gy + int(pn[1]))
	var inicio := _inicio(g, w, h, portal, rng, int(c.get("distancia_min", 18)))
	_conectar(g, w, h, portal)
	var vis := _alcancaveis(g, w, h, portal)
	var ok := true
	for k in g.size():
		if passavel(g[k]) and vis[k] == 0:
			ok = false
			break
	ok = ok and vis[inicio.y * w + inicio.x] == 1
	var linhas := PackedStringArray()
	for y in h:
		linhas.append("".join(g.slice(y * w, (y + 1) * w)))
	return {"ok": ok, "largura": w, "altura": h, "linhas": linhas, "inicio": inicio, "portal": portal, "regiao": regiao, "andar": andar}


## Peças que servem nesta região: as sem "regioes" (genéricas) e as que listam a região.
static func _ids_da_regiao(pecas: Dictionary, regiao: String) -> Array:
	var res := []
	for id in pecas:
		var lista = pecas[id].get("regioes", null)
		if lista == null or (lista is Array and regiao in lista):
			res.append(id)
	res.sort()   # ordem fixa: o sorteio não depende da ordem do dicionário
	return res


static func _carimbar(g: PackedStringArray, w: int, rows: Array, ox: int, oy: int) -> void:
	for j in rows.size():
		var linha := str(rows[j])
		for i in linha.length():
			var ch := linha[i]
			if ch != ".":   # o chão da peça não apaga o que já estava lá
				g[(oy + j) * w + ox + i] = ch


## Onde o herói nasce: um ponto que anda, longe do portal (pelo menos distancia_min tiles).
static func _inicio(g: PackedStringArray, w: int, h: int, portal: Vector2i, rng: RandomNumberGenerator, dmin: int) -> Vector2i:
	var longe := []
	var qualquer := []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if not passavel(g[y * w + x]):
				continue
			qualquer.append(Vector2i(x, y))
			if Vector2(x, y).distance_to(Vector2(portal)) >= dmin:
				longe.append(Vector2i(x, y))
	var lista: Array = longe if not longe.is_empty() else qualquer
	if lista.is_empty():
		return portal
	return Sorte.escolher(rng, lista)


## Tudo que anda e está ligado ao portal (1 = alcança). Busca em largura pelos quatro lados.
static func _alcancaveis(g: PackedStringArray, w: int, h: int, a: Vector2i) -> PackedByteArray:
	var vis := PackedByteArray()
	vis.resize(w * h)
	vis.fill(0)
	vis[a.y * w + a.x] = 1
	var fila := [a]
	var i := 0
	while i < fila.size():
		var p: Vector2i = fila[i]
		i += 1
		for d in CARDINAIS:
			var q: Vector2i = p + d
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			var k := q.y * w + q.x
			if vis[k] == 0 and passavel(g[k]):
				vis[k] = 1
				fila.append(q)
	return vis


## Liga o que ficou de fora do portal: enquanto houver um ponto que anda e não alcança o portal, cava um corredor em L
## do ponto até o pedaço mais próximo ligado. Água vira ponte; o resto (relevo, pilar, foco, portão) vira chão.
## Cada corredor junta pelo menos um pedaço, então o laço acaba em no máximo (número de pedaços) voltas.
static func _conectar(g: PackedStringArray, w: int, h: int, portal: Vector2i) -> void:
	for _k in w * h:
		var vis := _alcancaveis(g, w, h, portal)
		var fora := -1
		for k in g.size():
			if vis[k] == 0 and passavel(g[k]):
				fora = k
				break
		if fora < 0:
			return
		var de := Vector2i(fora % w, floori(fora / float(w)))
		var perto := _mais_perto(vis, w, h, de)
		_cavar(g, w, h, de, perto)


static func _mais_perto(vis: PackedByteArray, w: int, h: int, de: Vector2i) -> Vector2i:
	var melhor := Vector2i(-1, -1)
	var md := INF
	for k in vis.size():
		if vis[k] == 0:
			continue
		var p := Vector2i(k % w, floori(k / float(w)))
		var d := Vector2(p).distance_squared_to(Vector2(de))
		if d < md:
			md = d
			melhor = p
	return melhor


static func _cavar(g: PackedStringArray, w: int, h: int, a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	while x != b.x:
		_abrir(g, w, h, x, a.y)
		x += signi(b.x - x)
	var y := a.y
	while y != b.y:
		_abrir(g, w, h, b.x, y)
		y += signi(b.y - y)
	_abrir(g, w, h, b.x, b.y)


static func _abrir(g: PackedStringArray, w: int, h: int, x: int, y: int) -> void:
	if x <= 0 or y <= 0 or x >= w - 1 or y >= h - 1:
		return
	var k := y * w + x
	if passavel(g[k]):
		return
	g[k] = "=" if g[k] == "~" else "."


## Névoa do minimapa (#128): marca como visto (1) o que está até `raio` tiles de `centro`. Sem linha de visão: é o raio cru.
static func revelar(visto: PackedByteArray, w: int, h: int, centro: Vector2i, raio: int) -> void:
	for y in range(maxi(0, centro.y - raio), mini(h, centro.y + raio + 1)):
		for x in range(maxi(0, centro.x - raio), mini(w, centro.x + raio + 1)):
			if Vector2(x, y).distance_to(Vector2(centro)) <= raio:
				visto[y * w + x] = 1
