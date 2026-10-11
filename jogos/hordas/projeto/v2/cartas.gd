extends RefCounted
## As cartas da v2 (leva 3): montagem de build. Sorteia cartas com RARIDADE (comum, raro, épico, lendário; a chance das altas sobe com o
## nível), aplica melhorias de stat, golpes secundários automáticos (v2/armas.gd), modificadores da katana e as EVOLUÇÕES (duas peças viram
## uma versão evoluída). Também guarda os banidos e os usos de rerrolar/banir. Tudo vem de dados/v2_cartas.json (veja o `_ajuda` de lá).
##
## Uma carta é um Dictionary: {id, nome, desc (já com o valor), cat ("stat", "golpe" ou "mod"), rar (0 a 3), rar_nome, cor (Color), valor
## (stat/mod, já multiplicado pela raridade), max, nivel_atual, nivel_novo, extra (texto do nível ou da sinergia), stat}.

const Armas := preload("res://v2/armas.gd")

var combate
var cfg: Dictionary = {}
var rar: Array = []
var rng := RandomNumberGenerator.new()
var estado := {}  # id -> {n: vezes que pegou, bonus: dano extra do golpe pela raridade, soma: valor acumulado (mod), usada: virou parte de evolução}
var evoluidas: Array = []  # ids das evoluções já feitas
var banidas := {}
var rerrolar_usados := 0
var banir_usados := 0
var rerrolar_na_tela := 0
var evolucoes_feitas := 0
var _def := {}  # id -> definição (stat, golpe ou modificador)
var _cat := {}


func montar(c) -> void:
	combate = c
	cfg = Dados.json("v2_cartas")
	rar = cfg.raridades
	for d in cfg.stats:
		_def[d.id] = d
		_cat[d.id] = "stat"
	for d in cfg.golpes:
		_def[d.id] = d
		_cat[d.id] = "golpe"
	for d in cfg.modificadores:
		_def[d.id] = d
		_cat[d.id] = "mod"
	rng.randomize()


func zerar() -> void:
	estado.clear()
	evoluidas.clear()
	banidas.clear()
	rerrolar_usados = 0
	banir_usados = 0
	rerrolar_na_tela = 0
	evolucoes_feitas = 0
	rng.randomize()


# ------------------------------------------------------------------ raridade


## Peso do sorteio da raridade `i` no nível `nivel`: anda em linha reta do peso_ini (nível 1) ao peso_fim (nível `nivel_fim`).
func peso_raridade(i: int, nivel: int) -> float:
	var k := clampf(float(nivel - 1) / maxf(float(int(cfg.nivel_fim) - 1), 1.0), 0.0, 1.0)
	return lerpf(float(rar[i].peso_ini), float(rar[i].peso_fim), k)


## Chance (0 a 1) de sair a raridade `i` no nível `nivel`, com `bonus` multiplicando o peso das raridades acima da comum (o baú usa).
func chance_raridade(i: int, nivel: int, bonus := 1.0) -> float:
	var total := 0.0
	for j in rar.size():
		total += peso_raridade(j, nivel) * (bonus if j > 0 else 1.0)
	return peso_raridade(i, nivel) * (bonus if i > 0 else 1.0) / total


func sortear_raridade(nivel: int, bonus := 1.0) -> int:
	var r := rng.randf()
	for j in rar.size():
		r -= chance_raridade(j, nivel, bonus)
		if r < 0.0:
			return j
	return 0


# ------------------------------------------------------------------ estado e sorteio


func definicao(id: String) -> Dictionary:
	return _def.get(id, {})


func nivel_de(id: String) -> int:
	return int(estado.get(id, {}).get("n", 0))


func ativa(id: String) -> bool:
	return nivel_de(id) > 0 and not bool(estado.get(id, {}).get("usada", false))


func _disponivel(d: Dictionary) -> bool:
	var id := str(d.id)
	if banidas.has(id) or bool(estado.get(id, {}).get("usada", false)):
		return false
	return nivel_de(id) < int(d.max)


## Quantas cartas ainda poderiam sair (testes).
func disponiveis() -> Array:
	var r: Array = []
	for id in _def:
		if _disponivel(_def[id]):
			r.append(_def[id])
	return r


## Peso extra da carta que ajuda a fechar uma evolução (a outra peça já foi pega).
func _peso_sinergia(id: String) -> float:
	for ev in cfg.evolucoes:
		if evoluidas.has(ev.id):
			continue
		var tem_peca := false
		var outras := 0
		for p in ev.pecas:
			if p.id == id:
				tem_peca = true
			elif nivel_de(str(p.id)) > 0:
				outras += 1
		if tem_peca and outras >= ev.pecas.size() - 1:
			return float(cfg.escolha.peso_sinergia)
	return 1.0


func _sinergia_texto(id: String) -> String:
	for ev in cfg.evolucoes:
		if evoluidas.has(ev.id):
			continue
		for p in ev.pecas:
			if p.id == id:
				return "Evolui: %s" % ev.nome
	return ""


func golpes_ativos() -> int:
	var n := 0
	for d in cfg.golpes:
		if ativa(str(d.id)):
			n += 1
	return n


## Sorteia `n` cartas diferentes. `bonus` = quanto o baú favorece as raridades altas. Até o nível `garantir_golpe_ate`, quem ainda não tem
## nenhum golpe secundário vê pelo menos um na escolha (o começo da build). `excluir` = ids que não podem sair nesta rodada (rerrolar).
func sortear(n: int, nivel: int, bonus := 1.0, excluir: Array = []) -> Array:
	var cand: Array = []
	var pesos: Array = []
	for id in _def:
		var d: Dictionary = _def[id]
		if not _disponivel(d) or excluir.has(id):
			continue
		cand.append(d)
		pesos.append(float(d.get("peso", 1.0)) * _peso_sinergia(str(id)))
	var escolhidas: Array = []
	for k in mini(n, cand.size()):
		var total := 0.0
		for p in pesos:
			total += float(p)
		var r := rng.randf() * total
		var i := 0
		while i < cand.size() - 1:
			r -= float(pesos[i])
			if r < 0.0:
				break
			i += 1
		escolhidas.append(cand[i])
		cand.remove_at(i)
		pesos.remove_at(i)
	if nivel <= int(cfg.escolha.garantir_golpe_ate) and golpes_ativos() == 0 and not escolhidas.is_empty():
		var tem := false
		for d in escolhidas:
			if _cat[d.id] == "golpe":
				tem = true
		if not tem:
			var gs: Array = []
			for d in cfg.golpes:
				if _disponivel(d) and not excluir.has(d.id):
					gs.append(d)
			if not gs.is_empty():
				escolhidas[escolhidas.size() - 1] = gs[rng.randi() % gs.size()]
	var cartas: Array = []
	for d in escolhidas:
		cartas.append(montar_carta(d, sortear_raridade(nivel, bonus)))
	return cartas


## A carta `d` na raridade `r`: texto com o valor da raridade e o que o nível novo traz.
func montar_carta(d: Dictionary, r: int) -> Dictionary:
	var id := str(d.id)
	var cat: String = _cat[id]
	var ra: Dictionary = rar[r]
	var n := nivel_de(id)
	var c := {
		"id": id, "nome": d.nome, "cat": cat, "rar": r, "rar_nome": ra.nome, "cor": Color(ra.cor[0], ra.cor[1], ra.cor[2]), "max": int(d.max),
		"nivel_atual": n, "nivel_novo": n + 1, "valor": 0.0, "extra": "", "stat": str(d.get("stat", "")), "desc": ""
	}
	if cat == "golpe":
		var sobe := 2 if r == rar.size() - 1 else 1
		c.nivel_novo = mini(n + sobe, int(d.max))
		c.desc = str(d.desc)
		var ni: int = c.nivel_novo
		if n == 0:
			c.extra = "Novo golpe automático"
		else:
			var partes: Array = []
			for k in range(n, ni):
				partes.append(str(d.niveis[k - 1].texto))
			c.extra = "Nível %d: %s" % [ni, ", ".join(partes)]
		if ra.bonus_arma > 0.0:
			c.extra += "  (+%d%% de dano)" % roundi(float(ra.bonus_arma) * 100.0)
	else:
		c.valor = float(d.valor) * float(ra.mult)
		c.desc = str(d.desc).replace("{v}", str(roundi(float(c.valor))))
		c.extra = "Nível %d/%d" % [n + 1, int(d.max)]
	var sin := _sinergia_texto(id)
	if sin != "" and cat != "stat":
		c.extra += "\n" + sin
	return c


# ------------------------------------------------------------------ aplicar


func aplicar(c: Dictionary) -> void:
	var h = combate.mundo.heroi
	var id := str(c.id)
	var cat := str(c.get("cat", "stat"))
	if not estado.has(id):
		estado[id] = {"n": 0, "bonus": 0.0, "soma": 0.0, "usada": false}
	var e: Dictionary = estado[id]
	var d: Dictionary = _def.get(id, {})
	match cat:
		"golpe":
			var ni: int = int(c.get("nivel_novo", e.n + 1))
			e.n = clampi(ni, 1, int(d.max))
			e.bonus = float(e.bonus) + float(rar[int(c.get("rar", 0))].bonus_arma)
			combate.armas.definir_golpe(id, int(e.n), float(e.bonus))
		"mod":
			e.n = int(e.n) + 1
			e.soma = float(e.soma) + float(c.get("valor", d.valor))
			combate.armas.definir_modificador(str(d.mod), float(e.soma))
		_:
			e.n = int(e.n) + 1
			_aplicar_stat(h, str(c.get("stat", "")), float(c.get("valor", 0.0)))
	combate.progresso.melhorias[id] = int(e.n)
	_checar_evolucoes()


func _aplicar_stat(h, stat: String, v: float) -> void:
	match stat:
		"dano":
			h.m_dano += v / 100.0
		"vel_ataque":
			h.m_vel_ataque += v / 100.0
		"area":
			h.m_area += v / 100.0
		"vel_mov":
			h.m_vel_mov += v / 100.0
		"vida":
			h.vida_max += v
			h.curar(v)
		"ima":
			h.m_ima += v / 100.0
		"critico":
			h.m_critico += v / 100.0
		"cura":
			h.curar(h.vida_max)


# ------------------------------------------------------------------ evolução


func _peca_ok(p: Dictionary) -> bool:
	return ativa(str(p.id)) and nivel_de(str(p.id)) >= int(p.nivel)


## Confere se alguma evolução ficou pronta (as duas peças no nível pedido) e faz acontecer. Devolve o nome da última feita, ou "".
func _checar_evolucoes() -> String:
	var feita := ""
	for ev in cfg.evolucoes:
		if evoluidas.has(ev.id):
			continue
		var pronta := true
		for p in ev.pecas:
			if not _peca_ok(p):
				pronta = false
		if not pronta:
			continue
		evoluir(ev)
		feita = str(ev.nome)
	return feita


func evoluir(ev: Dictionary) -> void:
	evoluidas.append(ev.id)
	evolucoes_feitas += 1
	var bonus := 0.0
	for id in ev.consome:
		bonus = maxf(bonus, float(estado.get(id, {}).get("bonus", 0.0)))
		if estado.has(id):
			estado[id].usada = true
		combate.armas.remover(str(id))
	if ev.has("tipo"):
		combate.armas.adicionar_evoluida(ev, bonus)
	if ev.has("katana"):
		combate.armas.definir_evolucao_katana(ev)
	combate.evolucao_feita(ev)


# ------------------------------------------------------------------ rerrolar e banir


func pode_rerrolar() -> bool:
	return rerrolar_usados < int(cfg.escolha.rerrolar_total) and rerrolar_na_tela < int(cfg.escolha.rerrolar_por_tela)


func rerrolares_restantes() -> int:
	return int(cfg.escolha.rerrolar_total) - rerrolar_usados


func banimentos_restantes() -> int:
	return int(cfg.escolha.banir_total) - banir_usados


func pode_banir() -> bool:
	return banir_usados < int(cfg.escolha.banir_total)


func banir(id: String) -> void:
	banidas[id] = true
	banir_usados += 1


## Dados de resumo para a tela (build atual): lista de {nome, nivel, cor}.
func resumo() -> Array:
	var r: Array = []
	for id in estado:
		var e: Dictionary = estado[id]
		if int(e.n) > 0 and not bool(e.usada) and _cat[id] != "stat":
			r.append({"id": id, "nome": str(_def[id].nome), "nivel": int(e.n)})
	for ev in cfg.evolucoes:
		if evoluidas.has(ev.id):
			r.append({"id": ev.id, "nome": str(ev.nome), "nivel": 0})
	return r
