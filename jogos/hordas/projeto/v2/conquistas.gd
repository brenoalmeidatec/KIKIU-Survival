extends RefCounted
## A lista de conquistas em linguagem de gente (#373): o que a conquista pede, o progresso (ex.: 3/5 min) e o prêmio. É a MESMA conta
## para o Códice do santuário (salao.gd) e para a lista "Conquistas" da pausa (pausa.gd), então as duas telas nunca discordam.
## Os dados vêm de dados/v2_meta.json (via Meta) e o progresso, dos recordes do save (Meta.estado().recordes); na pausa, `vivo`
## ({"tempo": s, "combo": n}) traz a partida em andamento e vale se for maior que o recorde.

const Meta := preload("res://v2/meta.gd")


## Uma linha por conquista, na ordem do catálogo: {id, nome, fazer, feita, frac (0..1), progresso, premio, icone, icone_premio}.
## `premio` vem vazio só quando a recompensa não existe no catálogo; o último mapa não abre nada e diz "o fim da jornada".
static func linhas(vivo := {}) -> Array:
	var e := Meta.estado()
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
			_:
				atual = 1.0 if feita else 0.0
				unidade = "chefe"
		var frac := 1.0 if feita else clampf(atual / maxf(lim, 0.001), 0.0, 1.0)
		var mostra := lim if feita else minf(floorf(atual), lim)  # inteiro: "3/5 min" (a fração de minuto não entra)
		var linha := {
			"id": str(c.id),
			"nome": str(c.nome),
			"fazer": fazer(c),
			"feita": feita,
			"frac": frac,
			"progresso": "%d/%d %s" % [int(mostra), int(lim), unidade],
			"premio": premio(c),
			"icone": "portal_%s" % c.mapa if c.has("mapa") else str(c.id),
			"icone_premio": icone_do_premio(c.get("recompensa", {})),
		}
		out.append(linha)
	return out


## O que fazer, curto. Conquista de vitória usa o texto do próprio catálogo (cada mapa tem o seu chefe).
static func fazer(c: Dictionary) -> String:
	match str(c.get("condicao", "")):
		"tempo":
			return "Sobreviver %d min numa partida" % roundi(float(c.get("limite", 0)) / 60.0)
		"combo":
			return "Fazer um combo de %d abates" % int(c.get("limite", 0))
	return str(c.get("desc", "Vencer o chefe"))


## O que a conquista libera, em texto ("Treino de guerreiro", "o Laboratório e o Altar").
static func premio(c: Dictionary) -> String:
	var item := Meta.item_da_recompensa(c.get("recompensa", {}))
	if not item.is_empty():
		return str(item.nome)
	return "o fim da jornada" if str(c.get("recompensa", {}).get("tipo", "")) == "progresso" else ""


## O ícone do prêmio: o id do item, ou o portal que a vitória abre (assets/v2/icones_santuario/portal_<id>.png).
static func icone_do_premio(r: Dictionary) -> String:
	if str(r.get("tipo", "")) == "progresso":
		return "portal_%s" % r.get("id", "")
	return str(r.get("id", ""))


## Quantas estão cumpridas e quantas existem: [feitas, total].
static func contagem(linhas_: Array) -> Array:
	var n := 0
	for l in linhas_:
		if l.feita:
			n += 1
	return [n, linhas_.size()]
