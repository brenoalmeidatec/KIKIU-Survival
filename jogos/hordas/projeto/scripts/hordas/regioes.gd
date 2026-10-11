extends RefCounted
## Regiões do mundo (#64): a corrida atravessa as regiões de dados/regioes.json, cada uma com N andares
## (fases_por_regiao). Os primeiros andares de cada região saem sorteados do repertório dela (Sorte, então a
## mesma semente dá a mesma corrida em todos os clientes) e o último é sempre o chefe da região.
## A lista de fases da corrida inteira é montada uma vez (gerar_fases) e o diretor usa como antes: andar global
## = região * N + andar na região. O mapa de nós é um por região, costurado num só (mapa.gd).

const CAMPOS_DA_REGIAO := ["conjunto", "cenario", "musica", "musica_chefe", "cor"]


static func cfg() -> Dictionary:
	return Dados.json("regioes")


## Tem regiões? (sem dados/regioes.json, vale a corrida antiga do dados/corrida.json)
static func ativo() -> bool:
	return not lista().is_empty()


static func lista() -> Array:
	var l = cfg().get("regioes", [])
	return l if l is Array else []


static func n() -> int:
	return lista().size()


static func por_regiao() -> int:
	return maxi(2, int(cfg().get("fases_por_regiao", 5)))


static func regiao(i: int) -> Dictionary:
	var l := lista()
	return l[clampi(i, 0, l.size() - 1)] if not l.is_empty() else {}


## Região do andar global (0 = primeiro andar da corrida).
static func do_andar(andar: int) -> int:
	return clampi(andar / por_regiao(), 0, maxi(0, n() - 1))


static func primeiro_andar(r: int) -> int:
	return r * por_regiao()


## As fases da corrida inteira, na ordem dos andares. rng = Sorte.fluxo("regioes").
static func gerar_fases(rng: RandomNumberGenerator) -> Array:
	var res := []
	var k := por_regiao()
	for r in n():
		var reg := regiao(r)
		var pool: Array = (reg.get("fases", []) as Array).duplicate()
		var escolhidas := []
		for _i in k - 1:
			if pool.is_empty():
				pool = (reg.get("fases", []) as Array).duplicate()  # repertório pequeno: pode repetir, mas não seguido
				if not escolhidas.is_empty():
					pool.erase(escolhidas[-1])
			if pool.is_empty():
				break
			var f: Dictionary = _sortear(pool, rng)
			pool.erase(f)
			escolhidas.append(f)
		for i in escolhidas.size():
			res.append(_montar(reg, escolhidas[i], r, i, false))
		res.append(_montar(reg, reg.get("chefe", {}), r, k - 1, true))
	return res


static func _sortear(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for f in pool:
		total += maxf(0.0, float(f.get("peso", 1.0)))
	var x := rng.randf() * total
	for f in pool:
		x -= maxf(0.0, float(f.get("peso", 1.0)))
		if x <= 0.0:
			return f
	return pool[-1]


## A fase pronta: o molde da fase + o que vem da região (o molde ganha se tiver o mesmo campo).
static func _montar(reg: Dictionary, molde: Dictionary, r: int, andar: int, chefe_regiao: bool) -> Dictionary:
	var f := molde.duplicate(true)
	for c in CAMPOS_DA_REGIAO:
		if not f.has(c) and reg.has(c):
			f[c] = reg[c]
	f["regiao"] = r
	f["regiao_nome"] = str(reg.get("nome", "Região %d" % (r + 1)))
	f["andar_regiao"] = andar
	f["chefe_regiao"] = chefe_regiao
	return f


## Regras do mapa de nós DENTRO de uma região: dados/mapa.json + o "mapa" do regioes.json, com os andares da região.
static func mapa_cfg() -> Dictionary:
	var c: Dictionary = Dados.json("mapa").duplicate(true)
	var extra: Dictionary = cfg().get("mapa", {})
	for k in extra:
		c[k] = extra[k]
	c["andares"] = por_regiao()
	return c


## Modificadores de calor que a região soma por cima da escolha do jogador.
static func calor(r: int) -> Dictionary:
	var c = regiao(r).get("calor", {})
	return c if c is Dictionary else {}
