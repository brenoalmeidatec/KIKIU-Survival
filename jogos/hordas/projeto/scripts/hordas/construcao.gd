extends RefCounted
## "Construção" (build) de um lutador: atributos a partir do herói + passivos, e um gerador de
## builds de mentirinha pros rivais do duelo final (sobem de nível sorteando cartas, como um jogador).
## Tudo lê dados/*.json, então trocar armas, passivos e heróis muda isso também.

const BASE := {"dano": 1.0, "recarga": 1.0, "area": 1.0, "quantidade": 0.0, "velocidade_proj": 1.0, "duracao": 1.0,
	"vida_max": 100.0, "regen": 0.0, "velocidade": 1.0, "ima": 1.0, "sorte": 0.0, "xp": 1.0,
	"critico": 0.05, "critico_mult": 1.5}
const Equipamento := preload("res://scripts/hordas/equipamento.gd")
const Universais := preload("res://scripts/hordas/universais.gd")
const MAX_ARMAS := 4   # (só de reserva: o limite de verdade é Universais.max_total(), dados/armas_universais.json)
const MAX_PASSIVOS := 5


## equip = slot -> id dos equipamentos vestidos (somam bônus como os passivos).
static func stats(heroi: Dictionary, passivos: Dictionary, equip := {}, extra := {}) -> Dictionary:
	var s := BASE.duplicate()
	var eb := Equipamento.bonus(equip)
	for k in eb:
		s[k] = float(s.get(k, 0)) + float(eb[k])
	var bonus: Dictionary = heroi.get("bonus", {})
	for k in bonus:
		s[k] = float(s.get(k, 0)) + float(bonus[k])
	var pas: Dictionary = Dados.json("passivos")
	for id in passivos:
		var ef: Dictionary = pas.get(id, {}).get("efeito", {})
		for k in ef:
			s[k] = float(s.get(k, 0)) + float(ef[k]) * passivos[id]
	for k in extra:   # dádivas dos santuários (#21)
		s[k] = float(s.get(k, 0)) + float(extra[k])
	s["recarga"] = maxf(0.35, s.recarga)
	s["velocidade"] = maxf(0.4, s.velocidade)
	s["critico"] = clampf(s.critico, 0.0, 0.8)
	return s


static func nivel_max(arma: String) -> int:
	return 1 + Dados.json("armas").get(arma, {}).get("niveis", []).size()


## Sorteia uma build como se o jogador tivesse chegado a "nivel". Retorna {armas: [{id, nivel}], passivos: {id: nivel}}.
static func gerar(heroi_id: String, nivel: int, rng: RandomNumberGenerator) -> Dictionary:
	var heroi: Dictionary = Dados.json("herois").get(heroi_id, {})
	var armas_d: Dictionary = Dados.json("armas")
	var pas_d: Dictionary = Dados.json("passivos")
	var armas := [{"id": str(heroi.get("arma", "pendrive")), "nivel": 1}]
	var passivos := {}
	for _i in maxi(0, nivel - 1):
		var cand := []   # [peso, tipo, id]
		for a in armas:
			if a.nivel < nivel_max(a.id):
				cand.append([14.0, "sobe_arma", a.id])
		for id in passivos:
			if passivos[id] < int(pas_d[id].get("max", 5)):
				cand.append([6.0 * float(pas_d[id].get("peso_ia", 1.0)), "sobe_passivo", id])
		if armas.size() < max_armas():
			var ids: Array = armas.map(func(a): return a.id)
			for id in armas_d:
				if not arma_permitida(id, heroi_id, ids) or _evoluida(armas, id):
					continue
				cand.append([8.0, "nova_arma", id])
		if passivos.size() < MAX_PASSIVOS:
			for id in pas_d:
				if id.begins_with("_") or passivos.has(id):
					continue
				cand.append([4.0 * float(pas_d[id].get("peso_ia", 1.0)), "novo_passivo", id])
		if cand.is_empty():
			break
		var total := 0.0
		for c in cand:
			total += c[0]
		var r := rng.randf() * total
		var esc = cand[0]
		for c in cand:
			r -= c[0]
			if r <= 0:
				esc = c
				break
		match esc[1]:
			"sobe_arma":
				for a in armas:
					if a.id == esc[2]:
						a.nivel += 1
			"sobe_passivo":
				passivos[esc[2]] = int(passivos[esc[2]]) + 1
			"nova_arma":
				armas.append({"id": esc[2], "nivel": 1})
			"novo_passivo":
				passivos[esc[2]] = 1
		# baú de evolução: quando a receita está pronta, 20% de chance por nível de abrir o baú
		for e in Dados.json("evolucoes").get("lista", []):
			for a in armas:
				if a.id == e.arma and a.nivel >= nivel_max(a.id) and passivos.has(e.passivo) and rng.randf() < 0.2:
					a.id = e.vira
					a.nivel = 1
	return {"armas": armas, "passivos": passivos}


static func _tem(armas: Array, id: String) -> bool:
	for a in armas:
		if a.id == id:
			return true
	return false


## True se a evolução de "base" já está na build (aí a arma base não volta a aparecer).
static func _evoluida(armas: Array, base: String) -> bool:
	for e in Dados.json("evolucoes").get("lista", []):
		if e.arma == base and _tem(armas, e.vira):
			return true
	return false


## Atributos de uma arma num nível (base + soma dos níveis + curva de crescimento de dano e área), sem os bônus do jogador.
## É a mesma conta do jogo (crescimento.gd), então o dano "de catálogo" do duelo concorda com o da horda.
static func atributos_arma(id: String, nivel: int) -> Dictionary:
	return preload("res://scripts/hordas/crescimento.gd").atributos(id, nivel)


## Dano por segundo "de catálogo" de cada tipo de arma da build (se todo golpe acertasse um alvo).
## O duelo usa isso pra deixar todas as lutas com a mesma duração, seja build de nível 10 ou de nível 60.
static func dps_por_tipo(armas: Array, st: Dictionary) -> Dictionary:
	var res := {}
	var d: Dictionary = Dados.json("armas")
	var crit := 1.0 + float(st.get("critico", 0.0)) * (float(st.get("critico_mult", 1.5)) - 1.0)
	for w in armas:
		var def: Dictionary = d.get(w.id, {})
		var tipo := str(def.get("familia", def.get("tipo", "projetil")))   # arma de tipo novo diz a família
		var a := atributos_arma(w.id, w.nivel)
		var dano := float(a.get("dano", 1)) * float(st.get("dano", 1.0)) * crit
		var rec := maxf(0.1, float(a.get("recarga", 1)) * float(st.get("recarga", 1.0)))
		var q := float(a.get("quantidade", 1)) + float(st.get("quantidade", 0.0))
		var dur := float(a.get("duracao", 1)) * float(st.get("duracao", 1.0))
		var v := 0.0
		match tipo:
			"projetil", "chicote":
				v = dano * q / maxf(0.15, rec)
			"orbita":
				v = dano * q * 2.0 * (dur / (dur + rec)) if dur < 100 else dano * q * 2.0
			"poca":
				var tique := maxf(0.1, float(a.get("tique", 0.4)))
				v = dano / tique * minf(q * dur / maxf(0.3, rec), 4.0)
			"aura":
				v = dano / maxf(0.15, float(a.get("tique", 0.5)))
		res[tipo] = float(res.get(tipo, 0.0)) + v
	return res


# ---------- quem pode pegar cada arma (cartas do jogador E build dos rivais usam isto) ----------
# Cada arma em dados/armas.json tem "classe": "global" (qualquer personagem; é o padrão) ou
# "character_exclusive" com "characterId" (só aquele personagem). Por partida, cada um pega no máximo
# _config.limite_exclusivas armas exclusivas (2 por padrão). Evolução de arma exclusiva também é exclusiva.

static func max_armas() -> int:
	return Universais.max_total()


static func limite_exclusivas() -> int:
	return int(Dados.json("armas").get("_config", {}).get("limite_exclusivas", 2))


## Definição da arma (ou {} se não for arma: as chaves que começam com "_" são texto e configuração).
static func _def(id: String) -> Dictionary:
	var d = Dados.json("armas").get(id, {})
	return d if d is Dictionary and not id.begins_with("_") else {}


static func exclusiva(id: String) -> bool:
	return str(_def(id).get("classe", "global")) == "character_exclusive"


static func dono(id: String) -> String:
	return str(_def(id).get("characterId", ""))


## Quantas armas exclusivas do personagem já estão na lista (ids).
static func n_exclusivas(ids: Array, heroi_id: String) -> int:
	return ids.filter(func(i): return exclusiva(i) and dono(i) == heroi_id).size()


## A arma pode ser oferecida/pega como NOVA por este personagem agora? (nunca oferecer carta impossível)
static func arma_permitida(id: String, heroi_id: String, ids: Array) -> bool:
	var d := _def(id)
	if d.is_empty() or d.get("evolucao", false) or id in ids or d.get("universal", false):
		return false   # universais saem por carta própria (arena.gd, variação sorteada); rivais não as usam
	if str(d.get("classe", "")) == "transformacao":   # arma da forma (dragão): vem da transformação, nunca de carta
		return false
	if exclusiva(id):
		return dono(id) == heroi_id and n_exclusivas(ids, heroi_id) < limite_exclusivas()
	return true
