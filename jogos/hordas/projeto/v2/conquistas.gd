extends RefCounted
## A lista de conquistas em linguagem de gente (#373): o que a conquista pede, o progresso (ex.: 3/5 min) e o prêmio. É a MESMA conta
## para o Códice do santuário (salao.gd) e para a lista "Conquistas" da pausa (pausa.gd), então as duas telas nunca discordam.
## Os dados vêm de dados/v2_meta.json (via Meta) e o progresso, dos recordes do save (Meta.estado().recordes); na pausa, `vivo`
## ({"tempo": s, "combo": n}) traz a partida em andamento e vale se for maior que o recorde.

const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const UNIDADES := {"abates": "abates", "nivel": "nível", "evolucoes": "evoluções", "partidas": "partidas", "abates_total": "abates"}


## Uma linha por conquista, na ordem do catálogo: {id, nome, frase, fazer, feita, frac (0..1), progresso, contagem (o progresso sem unidade), premio, frase_premio, icone, icone_premio, selo, lore}.
## `frase` é a frase do Breno da própria conquista (dados/v2_meta.json; "" quando o catálogo não traz) e `frase_premio` a do item que ela
## libera (Pesadelo, Rastro de katana, melhorias; "" se o prêmio não tem frase). O Códice mostra a `frase`; a pausa, as duas.
## Segredo dos mapas (#424): antes de achar, nome "???" e `fazer` é a dica; depois, o nome e `lore` traz as frases do fragmento (o Códice escreve uma por linha extra).
## `selo` é o rótulo de quem está feita ("CUMPRIDA", ou "ACHADO" no segredo).
## `premio` vem vazio só quando a recompensa não existe no catálogo; o último mapa não abre nada e diz "o fim da jornada".
## `estado` é o Meta.estado() já lido (a HUD lê uma vez por partida); vazio, a função lê o save.
## Campos extras para a escolha da conquista em andamento: `condicao` (o tipo do catálogo), `heroi` ("" se vale para todos) e `segredo`.
static func linhas(vivo := {}, estado := {}) -> Array:
	var e: Dictionary = estado if not estado.is_empty() else Meta.estado()
	var r: Dictionary = e.recordes
	var tempo := maxf(float(r.tempo), float(vivo.get("tempo", 0.0)))
	var combo := maxi(int(r.combo), int(vivo.get("combo", 0)))
	var out := []
	for c in Meta.conquistas():
		var feita := bool(e.conquistas.get(str(c.id), false))
		var lim := float(c.get("limite", 1))
		var atual := 0.0
		var unidade := ""
		match str(c.get("condicao", "")):
			"tempo":
				atual = tempo / 60.0
				lim /= 60.0
				unidade = "min"
			"combo":
				atual = float(combo)
				unidade = "abates"
			"segredo":
				atual = 1.0 if feita else 0.0
				unidade = "segredo"
			"abates", "nivel", "evolucoes", "partidas", "abates_total":  # o recorde (ou o total) do save; na pausa, a partida viva se for maior
				atual = maxf(float(r.get(str(c.condicao), 0)), float(vivo.get(str(c.condicao), 0)))
				unidade = UNIDADES[str(c.condicao)]
			_:
				atual = 1.0 if feita else 0.0
				unidade = "chefe"
		var frac := 1.0 if feita else clampf(atual / maxf(lim, 0.001), 0.0, 1.0)
		var mostra := lim if feita else minf(floorf(atual), lim)  # inteiro: "3/5 min" (a fração de minuto não entra)
		var linha := {
			"id": str(c.id),
			"nome": str(c.nome),
			"frase": str(c.get("frase", "")),
			"fazer": fazer(c),
			"feita": feita,
			"frac": frac,
			"progresso": "%d/%d %s" % [int(mostra), int(lim), unidade],
			"contagem": "%d/%d" % [int(mostra), int(lim)],  # o progresso sem unidade, para a HUD quando o nome e a unidade não cabem juntos
			"premio": premio(c),
			"frase_premio": str(Meta.item_da_recompensa(c.get("recompensa", {})).get("frase", "")),
			"icone": icone_da_conquista(c),
			"icone_premio": icone_do_premio(c.get("recompensa", {})),
			"selo": "ACHADO" if c.has("segredo") else "CUMPRIDA",
			"lore": [],
			"condicao": str(c.get("condicao", "")),
			"heroi": str(c.get("heroi", "")),
			"segredo": c.has("segredo"),
		}
		if c.has("segredo"):
			linha.nome = str(c.nome) if feita else "???"
			linha.fazer = "Segredo: %s" % _nome_do_mapa(str(c.local)) if feita else str(c.dica)
			linha.lore = c.lore if feita else []
		out.append(linha)
	return out


## As condições que a partida em andamento consegue medir (o save só soma no fim: partidas e abates_total ficam de fora, e "venceu" e segredos também).
const CONDICOES_AO_VIVO := ["tempo", "combo", "abates", "nivel", "evolucoes"]


## A conquista em andamento: a linha de maior fração entre as que a partida em andamento pode cumprir (não feitas, não segredo, do herói
## da partida ou de todos). Empate vale a primeira do catálogo. Vazia ({}) quando não sobra nenhuma.
static func escolher(linhas_: Array, heroi := "") -> Dictionary:
	var melhor := {}
	for l in linhas_:
		if bool(l.feita) or bool(l.segredo) or not CONDICOES_AO_VIVO.has(str(l.condicao)):
			continue
		if str(l.heroi) != "" and str(l.heroi) != heroi:
			continue
		if melhor.is_empty() or float(l.frac) > float(melhor.frac):
			melhor = l
	return melhor


## A linha com este id (dentro de uma lista de `linhas`); {} se não estiver.
static func linha_da_id(linhas_: Array, id: String) -> Dictionary:
	for l in linhas_:
		if str(l.id) == id:
			return l
	return {}


## O nome do mapa (v2/mapas.gd) pelo id; o próprio id se não existir.
static func _nome_do_mapa(id: String) -> String:
	for m in Mapas.LISTA:
		if str(m.id) == id:
			return str(m.nome).substr(0, 1) + str(m.nome).substr(1).to_lower()
	return id


## O que fazer, curto. Conquista de vitória usa o texto do próprio catálogo (cada mapa tem o seu chefe).
static func fazer(c: Dictionary) -> String:
	match str(c.get("condicao", "")):
		"tempo":
			return "Sobreviver %d min numa partida" % roundi(float(c.get("limite", 0)) / 60.0)
		"combo":
			return "Fazer um combo de %d abates" % int(c.get("limite", 0))
		"abates":
			return "Derrubar %d monstros numa partida" % int(c.get("limite", 0))
		"nivel":
			return "Chegar ao nível %d numa partida" % int(c.get("limite", 0))
		"evolucoes":
			return "Fazer %d %s numa partida" % [int(c.get("limite", 0)), "evolução" if int(c.get("limite", 0)) == 1 else "evoluções"]
		"partidas":
			return "Jogar %d partidas" % int(c.get("limite", 0))
		"abates_total":
			return "Derrubar %d monstros no total" % int(c.get("limite", 0))
	return str(c.get("desc", "Vencer o chefe"))


## O que a conquista libera, em texto ("Treino de guerreiro", "a Torre e o Altar").
static func premio(c: Dictionary) -> String:
	var item := Meta.item_da_recompensa(c.get("recompensa", {}))
	if not item.is_empty():
		return str(item.nome)
	return "o fim da jornada" if str(c.get("recompensa", {}).get("tipo", "")) == "progresso" else ""


## O ícone da conquista: o "icone" do catálogo, o portal do mapa (vence_<mapa>) ou o próprio id (assets/v2/icones_santuario/<x>.png).
static func icone_da_conquista(c: Dictionary) -> String:
	if c.has("icone"):
		return str(c.icone)
	return "portal_%s" % c.mapa if c.has("mapa") else str(c.id)


## O ícone do prêmio: o id do item, ou o portal que a vitória abre (assets/v2/icones_santuario/portal_<id>.png).
## Sem id (o último mapa, "o fim da jornada") não há ícone: "" (antes caía no genérico, portal_ não existe).
static func icone_do_premio(r: Dictionary) -> String:
	var id := str(r.get("id", ""))
	if id == "":
		return ""
	if str(r.get("tipo", "")) == "progresso":
		return "portal_%s" % id
	return id


## Quantas estão cumpridas e quantas existem: [feitas, total].
static func contagem(linhas_: Array) -> Array:
	var n := 0
	for l in linhas_:
		if l.feita:
			n += 1
	return [n, linhas_.size()]
