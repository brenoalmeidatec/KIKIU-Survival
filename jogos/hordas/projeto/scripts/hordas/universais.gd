extends RefCounted
## Armas universais (#115): qualquer herói pega, cada uma com variações sorteadas pela semente da corrida.
## Os dados moram em dados/armas_universais.json (veja o _ajuda de lá). Este arquivo tem só as contas (puras, testadas em
## testes/armas_universais): gerar as entradas por variação, o limite de slots, o sorteio da variação, ascensão e fusão.

const ARQUIVO := "armas_universais"


static func cfg() -> Dictionary:
	return Dados.json(ARQUIVO)


static func id_de(base: String, variacao: String) -> String:
	return "u_" + base if variacao == "puro" or variacao == "" else "u_%s__%s" % [base, variacao]


## Gera uma entrada de armas.json por arma base e variação, mais as armas fundidas. Chamado pelo Dados ao ler "armas".
static func injetar(armas: Dictionary) -> void:
	var c: Dictionary = Dados.json(ARQUIVO)
	var bases: Dictionary = c.get("armas", {})
	var vars: Dictionary = c.get("variacoes", {})
	for b in bases:
		var d: Dictionary = bases[b]
		if d.get("fusao", false):
			armas[id_de(b, "puro")] = _montar(b, d, "puro", {})
			continue
		for v in vars:
			armas[id_de(b, v)] = _montar(b, d, str(v), vars[v])


static func _montar(base: String, d: Dictionary, var_id: String, v: Dictionary) -> Dictionary:
	var e: Dictionary = d.duplicate(true)
	var g := 1 if str(d.get("genero", "m")) == "f" else 0
	e["universal"] = true
	e["base_universal"] = base
	e["variacao"] = var_id
	e["classe"] = "global"
	if v.is_empty():
		return e
	var suf := str(v.get("nome", ["", ""])[g])
	if suf != "":
		e["nome"] = "%s %s" % [d.nome, suf]
	if v.get("cor") != null:
		e["cor"] = v.cor
	if v.get("elemento") != null:
		e["elemento"] = v.elemento
	if v.get("etiqueta") != null and not str(v.etiqueta) in e.etiquetas:
		e.etiquetas.append(str(v.etiqueta))
	if str(v.get("desc", "")) != "":
		e["descricao"] = "%s %s" % [d.descricao, v.desc]
	var fd := float(v.get("dano", 1.0))
	var fa := float(v.get("area", 1.0))
	var fr := float(v.get("recarga", 1.0))
	e.base["dano"] = maxi(1, roundi(float(e.base.dano) * fd))
	for n in e.niveis:
		if n.has("dano"):
			n["dano"] = maxi(1, roundi(float(n.dano) * fd))
		if n.has("recarga"):
			n["recarga"] = snappedf(float(n.recarga) * fr, 0.01)
	if e.base.has("recarga"):
		e.base["recarga"] = snappedf(float(e.base.recarga) * fr, 0.01)
	e.base["area"] = snappedf(float(e.base.get("area", 1.0)) * fa, 0.01)
	return e


static func eh_universal(id: String) -> bool:
	return bool(Dados.json("armas").get(id, {}).get("universal", false))


static func base_de(id: String) -> String:
	return str(Dados.json("armas").get(id, {}).get("base_universal", id))


static func eh_fusao(id: String) -> bool:
	return bool(Dados.json("armas").get(id, {}).get("fusao", false))


static func bases_sorteaveis() -> Array:
	var res := []
	for b in cfg().get("armas", {}):
		if not cfg().armas[b].get("fusao", false):
			res.append(b)
	return res


## Variação desta arma para esta corrida: determinística (semente + arma + "rodada"), com peso de raridade.
static func variacao_para(base: String, semente: int, rodada: int) -> String:
	var vars: Dictionary = cfg().get("variacoes", {})
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|var|%s|%d" % [semente, base, rodada])
	var total := 0.0
	for v in vars:
		total += float(vars[v].get("peso", 1.0))
	var x := r.randf() * total
	for v in vars:
		x -= float(vars[v].get("peso", 1.0))
		if x <= 0.0:
			return str(v)
	return "puro"


## Outra variação (a reforja): igual ao sorteio, mas nunca a atual.
static func outra_variacao(base: String, atual: String, semente: int, rodada: int) -> String:
	for i in 8:
		var v := variacao_para(base, semente, rodada * 10 + i + 1)
		if v != atual:
			return v
	return "puro" if atual != "puro" else "sangue"


# ---------- limite de slots ----------

static func max_total() -> int:
	return int(cfg().get("limites", {}).get("total", 5))


static func max_unicas() -> int:
	return int(cfg().get("limites", {}).get("unicas", 2))


## Pode entrar mais uma arma NOVA? (única = exclusiva do herói; o resto, universal). 2 únicas + 3 universais, ou 5 universais.
static func cabe(ids: Array, nova_unica: bool) -> bool:
	if ids.size() >= max_total():
		return false
	if nova_unica:
		var n := ids.filter(func(i): return str(Dados.json("armas").get(i, {}).get("classe", "global")) == "character_exclusive").size()
		return n < max_unicas()
	return true


# ---------- ascensão (depois do nível máximo) ----------

static func asc_max() -> int:
	return int(cfg().get("ascensao", {}).get("max", 5))


static func fator_dano(asc: int) -> float:
	return 1.0 + float(cfg().get("ascensao", {}).get("dano", 0.12)) * asc


static func fator_area(asc: int) -> float:
	return 1.0 + float(cfg().get("ascensao", {}).get("area", 0.05)) * asc


# ---------- fusões ----------

## Receitas que dá pra fazer agora: todas as armas base presentes no nível máximo (qualquer variação).
## lista = armas.lista; nivel_max = Callable(id) -> int. Retorna [{vira, ids (as armas que serão consumidas)}].
static func fusoes_possiveis(lista: Array, nivel_max: Callable) -> Array:
	var res := []
	for f in cfg().get("fusoes", []):
		var ids := []
		var ok := true
		for ing in f.ingredientes:
			var achou := ""
			for a in lista:
				if base_de(str(a.id)) == str(ing) and int(a.nivel) >= int(nivel_max.call(a.id)) and not str(a.id) in ids:
					achou = str(a.id)
					break
			if achou == "":
				ok = false
				break
			ids.append(achou)
		if ok:
			res.append({"vira": id_de(str(f.vira), "puro"), "ids": ids})
	return res
