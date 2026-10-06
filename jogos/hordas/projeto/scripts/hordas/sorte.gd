extends RefCounted
## Sorte controlada (seção 29 do design e issue #21): TODO sorteio que afeta o mundo compartilhado passa por aqui.
## Cada sistema tem a sua stream (RandomNumberGenerator com seed = hash(semente da corrida + nome)), então sortear
## um drop não desloca os santuários, e dois computadores com a mesma semente veem as mesmas coisas.
## No online o anfitrião sorteia a semente (Rede.comecar) e ela viaja junto com o começo da partida; só ela e as
## escolhas trafegam. Sorteio só visual/local (partículas, tremor, variação de velocidade) continua com randf() global.
## Sem Sorte.iniciar() as streams acordam com uma semente aleatória (testes e telas que criam a arena direto).

static var semente := 0
static var _iniciada := false
static var _fluxos := {}
static var _sacos := {}
static var _falhas := {}


static func iniciar(s: int) -> void:
	semente = s
	_iniciada = true
	_fluxos.clear()
	_sacos.clear()
	_falhas.clear()


static func nova_semente() -> int:
	return randi() & 0x7fffffff


static func _garantir() -> void:
	if not _iniciada:
		iniciar(nova_semente())


## Stream persistente do sistema (a ordem das chamadas só importa dentro dela).
static func fluxo(nome: String) -> RandomNumberGenerator:
	_garantir()
	if not _fluxos.has(nome):
		_fluxos[nome] = criar(nome)
	return _fluxos[nome]


## Stream nova e independente de ordem: nome + índice (ex.: os santuários da fase 4 são sempre os mesmos,
## não importa quantos sorteios aconteceram antes).
static func criar(nome: String, indice := 0) -> RandomNumberGenerator:
	_garantir()
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|%s|%d" % [semente, nome, indice])
	return r


static func inteiro(rng: RandomNumberGenerator, a: int, b: int) -> int:
	return rng.randi_range(a, b)


static func real(rng: RandomNumberGenerator, a: float, b: float) -> float:
	return rng.randf_range(a, b)


static func chance(rng: RandomNumberGenerator, p: float) -> bool:
	return rng.randf() < p


## Índice sorteado por peso (pesos <= 0 nunca saem). -1 se não há peso nenhum.
static func ponderado(rng: RandomNumberGenerator, pesos: Array) -> int:
	var total := 0.0
	for p in pesos:
		total += maxf(0.0, float(p))
	if total <= 0.0:
		return -1
	var r := rng.randf() * total
	for i in pesos.size():
		var p := maxf(0.0, float(pesos[i]))
		if p > 0.0 and r < p:
			return i
		r -= p
	for i in range(pesos.size() - 1, -1, -1):
		if float(pesos[i]) > 0.0:
			return i
	return -1


static func escolher(rng: RandomNumberGenerator, itens: Array):
	return null if itens.is_empty() else itens[rng.randi_range(0, itens.size() - 1)]


## Fisher-Yates semeado (não usa Array.shuffle(), que é global). Embaralha o próprio array e o devolve.
static func embaralhar(rng: RandomNumberGenerator, a: Array) -> Array:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a


## Shuffle bag: tira um por vez de um saco embaralhado; esvaziou, enche de novo. Garante variedade
## (nada repete 3 vezes seguidas por azar) sem mexer em chances. "chave" separa os sacos.
static func saco(chave: String, itens: Array):
	if itens.is_empty():
		return null
	var s: Array = _sacos.get(chave, [])
	if s.is_empty():
		s = embaralhar(fluxo("saco_" + chave), itens.duplicate())
	var x = s.pop_back()
	_sacos[chave] = s
	return x


## Pity (chance que sobe a cada falha até um teto): a chance é base + passo * falhas; na tentativa
## número "limite" ela é 100%. Acertou, o contador zera. Os contadores são da corrida (iniciar() zera).
static func pity(chave: String, base: float, passo: float, limite: int) -> bool:
	var f := int(_falhas.get(chave, 0))
	var p := clampf(base + passo * f, 0.0, 1.0)
	var ganhou := f + 1 >= limite or fluxo("pity_" + chave).randf() < p
	_falhas[chave] = 0 if ganhou else f + 1
	return ganhou


static func falhas_de(chave: String) -> int:
	return int(_falhas.get(chave, 0))
