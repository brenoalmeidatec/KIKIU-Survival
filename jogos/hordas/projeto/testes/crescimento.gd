extends Node
# Teste automático: curva de crescimento das armas (dados/crescimento_armas.json + scripts/hordas/crescimento.gd).
# Arma fraca e pequena no nível 1, maior e mais forte a cada nível, evolução no topo; o duelo e o jogo usam a mesma conta.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/crescimento.tscn  (imprime "CRESCIMENTO falhas=0")
# Com `-- --tabela` imprime a tabela de área/dano/DPS por nível de cada arma (pra ajustar a curva).
const Cresc := preload("res://scripts/hordas/crescimento.gd")
const Armas := preload("res://scripts/hordas/armas.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


## Todas as armas do armas.json (as chaves com "_" são texto e configuração).
func ids() -> Array:
	var res := []
	for id in Dados.json("armas"):
		if not str(id).begins_with("_"):
			res.append(id)
	return res


func _ready() -> void:
	var cfg := Cresc.cfg()
	# --- dados: padrões que o jogo exige existem e fazem sentido
	ok(cfg.has("_ajuda") and str(cfg._ajuda).length() > 100, "o json explica os campos em _ajuda")
	ok(cfg.get("area", []).size() >= 2 and cfg.get("dano", []).size() >= 2, "curvas de area e dano com 2+ pontos")
	ok(cfg.get("evoluida", {}).has("area") and cfg.get("evoluida", {}).has("dano"), "tem o bloco da arma evoluída")
	ok(cfg.get("efeitos", []).size() == Cresc.TIER_MAX + 1, "um bloco de efeitos por tier (0 a %d)" % Cresc.TIER_MAX)
	ok(is_equal_approx(Cresc.curva(cfg.area, 0.0), float(cfg.area[0][1])) and is_equal_approx(Cresc.curva(cfg.area, 1.0), float(cfg.area[-1][1])), "a curva começa e termina nos pontos do json")
	ok(Cresc.curva([], 0.5) == 1.0, "curva vazia = multiplicador 1")
	ok(is_equal_approx(Cresc.curva([[0.0, 1.0], [1.0, 2.0]], 0.25), 1.25), "interpolação linear")
	var a0 := float(cfg.area[0][1])
	var a1 := float(cfg.area[-1][1])
	ok(a0 >= 0.55 and a0 <= 0.8, "nível 1 começa pequeno (%.2f)" % a0)
	ok(a1 >= 1.1 and a1 <= 1.35, "nível máximo fica maior que o tamanho de antes (%.2f)" % a1)
	var d0 := float(cfg.dano[0][1])
	var d1 := float(cfg.dano[-1][1])
	ok(d0 < 1.0 and d1 >= 1.0 and d1 <= 1.2, "dano: mais fraco no começo (%.2f) e igual ou um pouco mais forte no fim (%.2f)" % [d0, d1])
	# efeitos por tier só crescem (cada tier tem pelo menos o que o anterior tinha)
	for k in ["faiscas", "grossura", "halo", "tremor", "brilho", "imagens", "brasas"]:
		for t in range(1, Cresc.TIER_MAX + 1):
			ok(float(Cresc.fx(t)[k]) >= float(Cresc.fx(t - 1)[k]), "efeito %s não diminui do tier %d pro %d" % [k, t - 1, t])
	ok(float(Cresc.fx(Cresc.TIER_MAX).brasas) > float(Cresc.fx(0).brasas) and float(Cresc.fx(Cresc.TIER_MAX).halo) > 0.0, "o topo tem mais efeitos que o começo")
	ok(Cresc.fx(0).faiscas == 0 and not Cresc.fx(0).arco_extra, "tier 0 (nível 1-2) é limpo, sem enfeite")
	ok(Cresc.fx(3).arco_extra and Cresc.fx(4).arco_extra, "máximo e evoluída têm o arco extra")

	# --- cada arma: área e dano sobem a cada nível; nível 1 menor que o máximo; tiers certos
	var w := Armas.new()   # só pra usar o _s() (atributos finais): jogador sem bônus nenhum
	w.statf = func(k): return 0 if k == "quantidade" else 1.0
	var n_base := 0
	for id in ids():
		var d := Dados.item(id)
		var nmax := Cresc.nivel_max(id)
		if bool(d.get("evolucao", false)):
			ok(nmax == 1, "%s: evolução não tem níveis" % id)
			ok(Cresc.tier(id, 1) == Cresc.TIER_MAX, "%s: evoluída é o tier %d" % [id, Cresc.TIER_MAX])
			continue
		n_base += 1
		ok(not Cresc.evoluida(id), "%s: não é evoluída" % id)
		var ant_area := -1.0
		var ant_dano := -1.0
		var ant_tier := -1
		for nv in range(1, nmax + 1):
			var s: Dictionary = w._s({"id": id, "nivel": nv})
			var ar := float(s.area)
			var ta := int(s.tier)
			ok(ar > ant_area, "%s nv%d: área sobe (%.3f > %.3f)" % [id, nv, ar, ant_area])
			if s.has("dano") and nv > 1:
				ok(float(s.dano) > ant_dano, "%s nv%d: dano sobe (%.2f > %.2f)" % [id, nv, float(s.dano), ant_dano])
			ok(ta >= ant_tier and ta <= 3, "%s nv%d: tier não desce e só chega a 3 sem evolução (%d)" % [id, nv, ta])
			ant_area = ar
			ant_dano = float(s.get("dano", 0.0))
			ant_tier = ta
		ok(Cresc.tier(id, 1) == 0 and Cresc.tier(id, 2) == 0, "%s: nível 1 e 2 são tier 0" % id)
		ok(Cresc.tier(id, nmax) == 3, "%s: nível máximo é o tier 3" % id)
		ok(Cresc.tier(id, 3) == 1 or nmax == 3, "%s: nível 3 é o tier 1" % id)
		var a1b := Cresc.atributos(id, 1)
		var amax := Cresc.atributos(id, nmax)
		ok(float(a1b.area) < float(amax.area) * 0.75, "%s: nível 1 tem menos de 75%% da área do máximo (%.2f x %.2f)" % [id, a1b.area, amax.area])
		# o crescimento mora na curva: nenhuma arma soma área nos níveis (senão cresceria em dobro)
		for lv in d.get("niveis", []):
			ok(not lv.has("area"), "%s: o armas.json não soma 'area' nos níveis (a curva cuida disso)" % id)
		# o duelo (construcao.gd) estima o dano com a mesma conta do jogo
		ok(is_equal_approx(float(Construcao.atributos_arma(id, nmax).get("dano", 0.0)), float(Cresc.atributos(id, nmax).get("dano", 0.0))), "%s: duelo e jogo usam o mesmo dano" % id)
	ok(n_base >= 20, "conferi as armas base (%d)" % n_base)

	# --- evoluções ficam no topo: tier acima do máximo da base, área e dano pelo menos iguais ao nível máximo da base
	var evs: Array = Dados.json("evolucoes").get("lista", [])
	ok(not evs.is_empty(), "há evoluções")
	for e in evs:
		var base_max := Cresc.nivel_max(str(e.arma))
		ok(Cresc.tier(str(e.vira), 1) > Cresc.tier(str(e.arma), base_max), "%s: tier da evolução acima do máximo de %s" % [e.vira, e.arma])
		var sb: Dictionary = Cresc.atributos(str(e.arma), base_max)
		var se: Dictionary = Cresc.atributos(str(e.vira), 1)
		ok(float(se.area) >= float(sb.area), "%s: evolução (%.2f) pelo menos tão grande quanto %s no máximo (%.2f)" % [e.vira, se.area, e.arma, sb.area])
		ok(_dps(str(e.vira), 1) >= _dps(str(e.arma), base_max), "%s: evolução (DPS %.0f) pelo menos tão forte quanto %s no máximo (%.0f)" % [e.vira, _dps(str(e.vira), 1), e.arma, _dps(str(e.arma), base_max)])
		ok(Cresc.mult(str(e.vira), 1, "area") >= 1.0 and Cresc.mult(str(e.vira), 1, "dano") >= 1.0, "%s: evolução não é penalizada pela curva" % e.vira)

	# --- override por arma: bloco "crescimento" no armas.json
	var arm: Dictionary = Dados.json("armas")
	var alvo := "katana"
	var orig = arm[alvo].get("crescimento")
	arm[alvo]["crescimento"] = {"desligado": true}
	ok(Cresc.mult(alvo, 1, "area") == 1.0 and Cresc.mult(alvo, 1, "dano") == 1.0, "crescimento desligado = sem curva")
	arm[alvo]["crescimento"] = {"area": [[0.0, 0.9], [1.0, 1.0]]}
	ok(is_equal_approx(Cresc.mult(alvo, 1, "area"), 0.9) and is_equal_approx(Cresc.mult(alvo, Cresc.nivel_max(alvo), "area"), 1.0), "a arma pode trocar só a curva de área")
	ok(is_equal_approx(Cresc.mult(alvo, 1, "dano"), d0), "...e continua com a curva padrão de dano")
	if orig == null:
		arm[alvo].erase("crescimento")
	else:
		arm[alvo]["crescimento"] = orig
	ok(is_equal_approx(Cresc.mult(alvo, 1, "area"), a0), "voltou ao padrão")

	# --- os bônus do jogador multiplicam por cima da curva
	var w2 := Armas.new()
	w2.statf = func(k): return 1.5 if k == "area" else (0 if k == "quantidade" else 1.0)
	var s2: Dictionary = w2._s({"id": "katana", "nivel": 1})
	ok(is_equal_approx(float(s2.area), a0 * 1.5), "passivo de área (x1.5) multiplica a área da curva (%.3f)" % float(s2.area))
	w.free()
	w2.free()

	# --- compensação: os primeiros níveis do jogador custam menos XP (a arma começa fraca), e a curva de XP nunca desce
	var ini: Dictionary = cfg.get("xp_inicial", {})
	ok(int(ini.get("ate", 0)) >= 5 and float(ini.get("fator", 1.0)) < 1.0 and float(ini.get("fator", 1.0)) >= 0.3, "xp_inicial: até que nível e fator (%s)" % str(ini))
	var ar_ := preload("res://scripts/hordas/arena.gd").new()
	var ant_xp := 0.0
	for n in range(1, 70):
		var x: float = ar_.xp_para(n)
		ok(x > ant_xp, "xp do nível %d (%.1f) maior que o anterior (%.1f)" % [n, x, ant_xp])
		ant_xp = x
	ok(is_equal_approx(ar_.xp_para(1), 5.0 * float(ini.get("fator", 1.0))), "o nível 1 pede o XP do json (%.1f)" % ar_.xp_para(1))
	ok(is_equal_approx(ar_.xp_para(int(ini.ate) + 1), 5.0 + float(ini.ate) * 6.0), "depois do último nível rápido a curva volta ao normal")
	ar_.free()

	if OS.get_cmdline_user_args().has("--tabela"):
		_tabela()
	print("CRESCIMENTO falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


## Dano por segundo "de catálogo" (o mesmo cálculo do duelo) de uma arma nesse nível.
func _dps(id: String, nivel: int) -> float:
	var v := 0.0
	var dps: Dictionary = Construcao.dps_por_tipo([{"id": id, "nivel": nivel}], {})
	for k in dps:
		v += float(dps[k])
	return v


func _tabela() -> void:
	var tw := Armas.new()
	tw.statf = func(k): return 0 if k == "quantidade" else 1.0
	print("TABELA arma | nivel tier area dano dps(catalogo)")
	for id in ids():
		var nmax := Cresc.nivel_max(id)
		var linha := []
		for nv in range(1, nmax + 1):
			var s: Dictionary = tw._s({"id": id, "nivel": nv})
			var dps: Dictionary = Construcao.dps_por_tipo([{"id": id, "nivel": nv}], {})
			var v := 0.0
			for k in dps:
				v += float(dps[k])
			linha.append("n%d t%d a%.2f d%.1f dps%.0f" % [nv, int(s.tier), float(s.area), float(s.get("dano", 0)), v])
		print("TABELA %s | %s" % [id, " | ".join(linha)])
	tw.free()
