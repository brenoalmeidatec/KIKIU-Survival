extends RefCounted
## Mapa de progressão entre as fases (#32 item 8): dados + geração, tudo função pura (sem nó, sem tela).
## A tela fica em tela_mapa.gd e a configuração em dados/mapa.json.
##
## O mapa é uma grade de ANDARES (colunas na tela, 1 por fase da corrida) por FAIXAS (linhas na tela).
## Caminhos sobem de andar em andar indo pra mesma faixa ou pra uma vizinha, sem se cruzar.
## O algoritmo segue o do guladam/deck_builder_tutorial (MIT, map_generator.gd, o mesmo do Slay the Spire),
## trocando o aleatório global pela stream Sorte.fluxo("mapa") e limitando todo re-sorteio.
## Mesma semente = mesmo mapa em todos os clientes; só a semente e as escolhas trafegam no online.
##
## Estrutura: {"andares": N, "faixas": F, "nos": [andar][faixa] -> null ou {andar, faixa, tipo, prox: [faixas do andar seguinte]}}
## (andar e faixa são índices a partir de 0; nos textos pro jogador o andar começa em 1).

const Sorte := preload("res://scripts/hordas/sorte.gd")
const Regioes := preload("res://scripts/hordas/regioes.gd")

const TIPOS_COMBATE := ["fase", "elite", "chefe"]   # os que rodam a fase do andar; os outros pulam a fase e abrem a própria tela


static func cfg() -> Dictionary:
	return Dados.json("mapa")


static func tipo_cfg(tipo: String) -> Dictionary:
	return cfg().get("tipos", {}).get(tipo, {})


static func combate(tipo: String) -> bool:
	return tipo in TIPOS_COMBATE


# ---------- geração ----------

## Gera o mapa desta corrida. Chame depois de Sorte.iniciar(semente): usa a stream "mapa".
## Com regiões (#64, dados/regioes.json): um mapa por região, com as regras da região, costurados num só.
static func gerar() -> Dictionary:
	var rng := Sorte.fluxo("mapa")
	if Regioes.ativo():
		var c := Regioes.mapa_cfg()
		var partes := []
		for _r in Regioes.n():
			partes.append(_gerar_um(rng, c))
		return costurar(partes)
	return _gerar_um(rng, cfg())


static func _gerar_um(rng: RandomNumberGenerator, c: Dictionary) -> Dictionary:
	for _t in int(c.get("tentativas", 50)):
		var m := _tentar(rng, c)
		if not m.is_empty() and erros(m).is_empty():
			return m
	return _linear(c)


## Junta os mapas das regiões na ordem: o andar a da região r vira o andar r*k + a, e o chefe de cada região
## leva a todos os nós do primeiro andar da próxima (depois do chefe, o grupo escolhe por onde entra na região).
static func costurar(partes: Array) -> Dictionary:
	var k := int(partes[0].andares)
	var f := int(partes[0].faixas)
	var m := _vazio(k * partes.size(), f)
	for r in partes.size():
		var p: Dictionary = partes[r]
		for a in k:
			for x in f:
				var orig = p.nos[a][x]
				if orig == null:
					continue
				var novo: Dictionary = orig.duplicate(true)
				novo.andar = r * k + a
				m.nos[r * k + a][x] = novo
		if r + 1 < partes.size():
			var entradas := []
			for x in f:
				if partes[r + 1].nos[0][x] != null:
					entradas.append(x)
			for x in f:
				if m.nos[r * k + k - 1][x] != null:
					m.nos[r * k + k - 1][x].prox = entradas.duplicate()
	m["por_regiao"] = k
	return m


static func _vazio(andares: int, faixas: int) -> Dictionary:
	var nos := []
	for a in andares:
		var linha := []
		linha.resize(faixas)
		nos.append(linha)
	return {"andares": andares, "faixas": faixas, "nos": nos}


static func _tentar(rng: RandomNumberGenerator, c: Dictionary) -> Dictionary:
	var n := maxi(3, int(c.get("andares", 10)))
	var f := maxi(2, int(c.get("faixas", 4)))
	var m := _vazio(n, f)
	var boss := f / 2
	m.nos[n - 1][boss] = _no(n - 1, boss, "chefe")
	# faixas iniciais: pelo menos "inicios_distintos_min" diferentes (limite de tentativas)
	var qtd := clampi(int(c.get("caminhos", 3)), 1, f)
	var inicios: Array = []
	for _t in int(c.get("tentativas", 50)):
		inicios = []
		for _i in qtd:
			inicios.append(rng.randi_range(0, f - 1))
		var distintos := {}
		for x in inicios:
			distintos[x] = true
		if distintos.size() >= mini(int(c.get("inicios_distintos_min", 2)), qtd):
			break
	var arestas: Array = []   # arestas[andar] = [[de, para], ...] do andar ao seguinte
	for _a in n - 1:
		arestas.append([])
	for ini in inicios:
		var j: int = ini
		for a in n - 2:   # do andar 0 até o penúltimo; o penúltimo liga sempre no chefe
			var viz: Array = []
			for p in [j - 1, j, j + 1]:
				if p >= 0 and p < f and not _cruza(arestas[a], j, p):
					viz.append(p)
			if viz.is_empty():
				return {}   # sem saída sem cruzar: sorteia de novo o mapa inteiro
			var para: int = viz[rng.randi_range(0, viz.size() - 1)]
			if not [j, para] in arestas[a]:
				arestas[a].append([j, para])
			j = para
		if not [j, boss] in arestas[n - 2]:
			arestas[n - 2].append([j, boss])
	# nós: só existem os que estão em algum caminho
	for a in n - 1:
		for e in arestas[a]:
			if m.nos[a][e[0]] == null:
				m.nos[a][e[0]] = _no(a, e[0], "")
			if not e[1] in m.nos[a][e[0]].prox:
				m.nos[a][e[0]].prox.append(e[1])
			if m.nos[a + 1][e[1]] == null:
				m.nos[a + 1][e[1]] = _no(a + 1, e[1], "")
	for a in n:
		for x in f:
			if m.nos[a][x] != null:
				m.nos[a][x].prox.sort()
	_sortear_tipos(m, rng, c)
	return m


static func _no(andar: int, faixa: int, tipo: String) -> Dictionary:
	return {"andar": andar, "faixa": faixa, "tipo": tipo, "prox": []}


## A aresta (j -> p) cruza alguma já existente no mesmo andar?
static func _cruza(arestas: Array, j: int, p: int) -> bool:
	for e in arestas:
		if (j < e[0] and p > e[1]) or (j > e[0] and p < e[1]):
			return true
	return false


static func pais(m: Dictionary, andar: int, faixa: int) -> Array:
	var res := []
	if andar <= 0:
		return res
	for x in int(m.faixas):
		var p = m.nos[andar - 1][x]
		if p != null and faixa in p.prox:
			res.append(p)
	return res


static func _sortear_tipos(m: Dictionary, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var pesos: Dictionary = c.get("pesos", {"fase": 1})
	var tipos := pesos.keys()
	var contagem := {}
	for a in int(m.andares):
		for x in int(m.faixas):
			var no = m.nos[a][x]
			if no == null:
				continue
			var fixo := str(c.get("fixos", {}).get(str(a + 1), ""))
			if fixo != "":
				no.tipo = fixo
			else:
				no.tipo = _tipo_valido(m, rng, c, no, tipos, pesos, contagem)
			contagem[no.tipo] = int(contagem.get(no.tipo, 0)) + 1


## Sorteia um tipo e re-sorteia enquanto as regras recusarem; passado o limite de tentativas vira "fase".
static func _tipo_valido(m: Dictionary, rng: RandomNumberGenerator, c: Dictionary, no: Dictionary, tipos: Array, pesos: Dictionary, contagem: Dictionary) -> String:
	for _t in int(c.get("tentativas", 50)):
		var i := Sorte.ponderado(rng, tipos.map(func(k): return float(pesos[k])))
		if i < 0:
			break
		var t: String = str(tipos[i])
		if regra_ok(m, c, no, t, contagem):
			return t
	return "fase"


static func regra_ok(m: Dictionary, c: Dictionary, no: Dictionary, tipo: String, contagem: Dictionary) -> bool:
	var r: Dictionary = c.get("regras", {}).get(tipo, {})
	var andar: int = int(no.andar) + 1   # nas regras o andar começa em 1
	if andar < int(r.get("andar_min", 1)) or andar > int(r.get("andar_max", 999)):
		return false
	if int(contagem.get(tipo, 0)) >= int(r.get("max_por_mapa", 9999)):
		return false
	for p in pais(m, int(no.andar), int(no.faixa)):
		if str(p.tipo) in r.get("apos_proibido", []):
			return false
		if bool(r.get("pai_igual_proibido", false)) and str(p.tipo) == tipo:
			return false
	return true


## Plano B se nenhuma tentativa deu certo (não deve acontecer): uma faixa só, tudo "fase" e chefe no fim.
static func _linear(c: Dictionary) -> Dictionary:
	var n := maxi(3, int(c.get("andares", 10)))
	var f := maxi(2, int(c.get("faixas", 4)))
	var m := _vazio(n, f)
	var x := f / 2
	for a in n:
		m.nos[a][x] = _no(a, x, "chefe" if a == n - 1 else "fase")
		if a < n - 1:
			m.nos[a][x].prox = [x]
	return m


# ---------- consulta ----------

static func no(m: Dictionary, andar: int, faixa: int) -> Dictionary:
	if andar < 0 or andar >= int(m.andares) or faixa < 0 or faixa >= int(m.faixas):
		return {}
	var n = m.nos[andar][faixa]
	return {} if n == null else n


## Faixas do andar seguinte em que dá pra ir a partir de (andar, faixa).
static func acessiveis(m: Dictionary, andar: int, faixa: int) -> Array:
	return no(m, andar, faixa).get("prox", [])


static func todos(m: Dictionary) -> Array:
	var res := []
	for a in int(m.andares):
		for x in int(m.faixas):
			if m.nos[a][x] != null:
				res.append(m.nos[a][x])
	return res


## Onde a corrida começa: um nó do andar 1 (a fase 1 abre direto, sem tela), sorteado com a semente.
static func inicio(m: Dictionary) -> int:
	var l := []
	for x in int(m.faixas):
		if m.nos[0][x] != null:
			l.append(x)
	return int(l[Sorte.criar("mapa_inicio").randi_range(0, l.size() - 1)])


## Todo nó leva ao chefe? Devolve a lista de problemas (vazia = mapa bom). O teste e o gerador usam.
static func erros(m: Dictionary) -> Array:
	var res := []
	var n := int(m.andares)
	var ultimo := todos(m).filter(func(x): return int(x.andar) == n - 1)
	if ultimo.size() != 1 or str(ultimo[0].tipo) != "chefe":
		res.append("o último andar deve ter só o chefe")
	var iniciais := todos(m).filter(func(x): return int(x.andar) == 0)
	if iniciais.size() < 2:
		res.append("menos de 2 nós no andar 1")
	for no_ in todos(m):
		if int(no_.andar) < n - 1 and no_.prox.is_empty():
			res.append("nó sem saída: andar %d faixa %d" % [int(no_.andar), int(no_.faixa)])
		elif int(no_.andar) > 0 and pais(m, int(no_.andar), int(no_.faixa)).is_empty():
			res.append("nó sem entrada: andar %d faixa %d" % [int(no_.andar), int(no_.faixa)])
		if not alcanca_chefe(m, int(no_.andar), int(no_.faixa)):
			res.append("nó que não chega ao chefe: andar %d faixa %d" % [int(no_.andar), int(no_.faixa)])
	for a in n - 1:
		var arestas := []
		for x in int(m.faixas):
			for p in acessiveis(m, a, x):
				if _cruza(arestas, x, p):
					res.append("cruzamento no andar %d" % a)
				arestas.append([x, p])
	return res


static func alcanca_chefe(m: Dictionary, andar: int, faixa: int) -> bool:
	var fronteira := [faixa]
	var a := andar
	while a < int(m.andares) - 1:
		var nova := []
		for x in fronteira:
			for p in acessiveis(m, a, x):
				if not p in nova:
					nova.append(p)
		if nova.is_empty():
			return false
		fronteira = nova
		a += 1
	return not fronteira.is_empty()


## Hash curto do mapa (tipos + ligações), pra comparar entre clientes nos logs.
static func resumo(m: Dictionary) -> String:
	var s := ""
	for no_ in todos(m):
		s += "%d.%d%s%s;" % [int(no_.andar), int(no_.faixa), str(no_.tipo).left(2), "".join(no_.prox.map(func(p): return str(p)))]
	return "%d" % s.hash()


# ---------- escolha ----------

## Votação online: maioria; empate = o voto do anfitrião se ele está entre os empatados, senão a menor faixa.
## Sem nenhum voto válido vale a primeira opção. votos: {peer: faixa}, opcoes: faixas acessíveis.
static func resolver_votos(votos: Dictionary, anfitriao: int, opcoes: Array) -> int:
	if opcoes.is_empty():
		return -1
	var cont := {}
	for p in votos:
		var v := int(votos[p])
		if v in opcoes:
			cont[v] = int(cont.get(v, 0)) + 1
	if cont.is_empty():
		return int(opcoes[0])
	var melhor := 0
	for v in cont:
		melhor = maxi(melhor, int(cont[v]))
	var empatados := []
	for v in cont:
		if int(cont[v]) == melhor:
			empatados.append(int(v))
	empatados.sort()
	var vh := int(votos.get(anfitriao, -1))
	if vh in empatados:
		return vh
	return int(empatados[0])


## O robô alterna: andar de índice par prefere combate; ímpar prefere o que não é combate (loja, evento, santuário, descanso), pra exercitar todos os nós.
static func escolha_bot(m: Dictionary, andar: int, faixa: int) -> int:
	var ac := acessiveis(m, andar, faixa)
	if ac.is_empty():
		return -1
	var prio := ["fase", "evento", "santuario", "descanso", "elite", "loja", "chefe"] if andar % 2 == 0 else ["loja", "evento", "santuario", "descanso", "fase", "elite", "chefe"]
	var melhor: int = ac[0]
	var pm := 99
	for x in ac:
		var p := prio.find(str(no(m, andar + 1, x).get("tipo", "")))
		if p >= 0 and p < pm:
			pm = p
			melhor = x
	return melhor
