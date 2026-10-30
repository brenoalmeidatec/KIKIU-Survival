extends RefCounted
## O ELENCO de inimigos de um mapa da v2 (dados/v2_elencos.json, chaveado pelo ID do mapa). Cada mapa tem os seus tipos de inimigo: uma
## VARIAÇÃO de um dos monstros que têm folha de sprite (mundo.gd SPRITES_MONSTRO) com outro nome, outra tinta (cor que multiplica a folha) e
## números próprios (vida, dano e velocidade como multiplicadores; xp e orbes não mudam, para o ritmo de nível ser o mesmo em todo mapa).
## Quem faz nascer monstro de horda (diretor, onda forte, moradores, defesa de ponto, elite e invocados da elite) pede o tipo aqui e passa
## o dicionário a mundo.nascer_monstro, que o aplica. Mapa fora do arquivo usa o PADRÃO: o que o jogo sorteava antes dos elencos
## (v2_combate.json > diretor > tipos e v2_cartas.json > elites > tipos, sem tinta), com as mesmas contas de sorteio. Os tipos do padrão
## levam `liso` = true (nascem como o monstro puro, sem aplicar nada).
## Um tipo normalizado: {id, nome, sprite, tinta (Color), desde, peso, vida, dano, vel, elite_desde (-1 = não é elite), liso}.

const ARQUIVO := "v2_elencos"
const SPRITE_PESADO := "inimigo_cavaleiro_oco"
const SPRITE_INVOCADOS := ["inimigo_aranha_tecela", "inimigo_cao_ossos"]

var id_mapa := ""
var padrao := true  # o mapa não tem elenco próprio: vale o padrão
var tipos: Array = []  # os tipos do diretor (sorteio por tempo de partida)
var elites_lista: Array = []  # [{sprite, nome, desde, tipo}]: de quem a elite pode nascer
var pesado: Dictionary = {}  # a ponta da onda forte
var invocados: Array = []  # [tipo, tipo]: os que a elite Invocadora faz nascer (alternando)


## Carrega o elenco do mapa `id`. `cfg_diretor` e `cfg_elites` são os blocos de v2_combate.json (diretor) e v2_cartas.json (elites), que
## formam o padrão.
func montar(id: String, cfg_diretor: Dictionary, cfg_elites: Dictionary) -> void:
	id_mapa = id
	var mapas: Dictionary = Dados.json(ARQUIVO).get("mapas", {})
	var dados: Variant = mapas.get(id)
	tipos.clear()
	elites_lista.clear()
	invocados.clear()
	pesado = {}
	padrao = true
	if dados is Dictionary and dados.get("tipos") is Array and not dados.tipos.is_empty():
		padrao = false
		for e in dados.tipos:
			var t := normalizar(e)
			tipos.append(t)
			if int(t.elite_desde) >= 0:
				elites_lista.append({"sprite": t.sprite, "nome": t.nome, "desde": t.elite_desde, "tipo": t})
		pesado = _achar(str(dados.get("pesado", "")))
		for i in dados.get("invocados", []):
			var inv := _achar(str(i))
			if not inv.is_empty():
				invocados.append(inv)
	if padrao or elites_lista.is_empty():
		elites_lista.clear()
		for e in cfg_elites.tipos:
			var t := _liso(str(e.sprite), str(e.nome), int(e.desde), 1)
			elites_lista.append({"sprite": t.sprite, "nome": t.nome, "desde": t.elite_desde, "tipo": t})
	if padrao:
		for e in cfg_diretor.tipos:
			tipos.append(_liso(str(e.sprite), str(e.sprite), int(e.desde), int(e.peso)))
	if pesado.is_empty():
		pesado = _liso(SPRITE_PESADO, SPRITE_PESADO, 0, 1)
	if invocados.size() < 2:
		invocados = [_liso(SPRITE_INVOCADOS[0], SPRITE_INVOCADOS[0], 0, 1), _liso(SPRITE_INVOCADOS[1], SPRITE_INVOCADOS[1], 0, 1)]


## Um tipo do arquivo, com os padrões preenchidos.
static func normalizar(e: Dictionary) -> Dictionary:
	var c: Array = e.get("tinta", [1.0, 1.0, 1.0])
	return {
		"id": str(e.id),
		"nome": str(e.get("nome", e.id)),
		"sprite": str(e.sprite),
		"tinta": Color(float(c[0]), float(c[1]), float(c[2])),
		"desde": float(e.get("desde", 0)),
		"peso": int(e.get("peso", 1)),
		"vida": float(e.get("vida", 1.0)),
		"dano": float(e.get("dano", 1.0)),
		"vel": float(e.get("vel", 1.0)),
		"elite_desde": int(e.get("elite_desde", -1)),
		"liso": false,
	}


static func _liso(sprite: String, nome: String, desde: int, peso: int) -> Dictionary:
	return {
		"id": sprite,
		"nome": nome,
		"sprite": sprite,
		"tinta": Color.WHITE,
		"desde": float(desde),
		"peso": peso,
		"vida": 1.0,
		"dano": 1.0,
		"vel": 1.0,
		"elite_desde": desde,
		"liso": true,
	}


func _achar(id: String) -> Dictionary:
	for t in tipos:
		if t.id == id:
			return t
	return {}


## O tipo sorteado para o instante `t` da partida (só entram os que já têm `desde` <= t), por peso. Mesma conta do diretor antes dos elencos:
## uma só chamada de rng.
func sortear(t: float, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for e in tipos:
		if t >= float(e.desde):
			total += int(e.peso)
	var r := rng.randi() % maxi(total, 1)
	for e in tipos:
		if t >= float(e.desde):
			r -= int(e.peso)
			if r < 0:
				return e
	return tipos[0]


## Um tipo qualquer do mapa, por peso e SEM olhar o `desde` (moradores e defesas de ponto). Vazio no padrão: quem chama usa o sorteio antigo.
func sortear_qualquer(rng: RandomNumberGenerator) -> Dictionary:
	if padrao:
		return {}
	var total := 0
	for e in tipos:
		total += int(e.peso)
	var r := rng.randi() % maxi(total, 1)
	for e in tipos:
		r -= int(e.peso)
		if r < 0:
			return e
	return tipos[0]


## O `k`-ésimo invocado da elite Invocadora (alterna entre os dois do mapa; no padrão: aranha e cão, como sempre).
func invocado(k: int) -> Dictionary:
	return invocados[k % invocados.size()]
