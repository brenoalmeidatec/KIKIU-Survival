extends RefCounted
## Peças puras da interface (#7): paleta (com modo daltônico), "antes > depois" das cartas, tabela de dano/DPS por
## arma do fim da corrida e hit-test de mouse. Tudo estático e sem estado, então o teste (testes/ui.gd) chama direto.
##
## Referências de design: cartas por tipo + glifo de forma (Halls of Torment / HoloCure: cor por categoria, e a forma
## carrega a informação pra quem não distingue cor); tabela do fim com dano, DPS e tempo por arma (Vampire Survivors,
## tela "Results"); modo daltônico = paleta Okabe-Ito (azul, laranja, amarelo, céu, vermelhão, rosa), a mais usada em
## jogos e em ciência por ser distinguível nos três tipos de daltonismo.

const PADRAO := {
	"arma": Color(0.45, 0.7, 1.0),
	"passivo": Color(0.5, 0.9, 0.5),
	"equipamento": Color(0.75, 0.6, 1.0),
	"exclusiva": Color(0.85, 0.65, 0.25),
	"evolucao": Color(1, 0.5, 0.9),
	"cura": Color(1, 0.65, 0.75),
	"bom": Color(0.5, 1, 0.5),
	"ruim": Color(1, 0.45, 0.4),
	"vida_chefe": Color(0.85, 0.15, 0.25),
	"vida_duelo": Color(0.9, 0.25, 0.3),
	"alerta": Color(1, 0.4, 0.4),
	"destaque": Color(1, 0.9, 0.4),
	"comportamento": Color(1.0, 0.55, 0.2),
	"perigo": Color(1.0, 0.25, 0.2),
	"area_aliada": Color(0.55, 0.85, 1.0),
}
const SEGURA := {
	"arma": Color(0.34, 0.7, 0.91),
	"passivo": Color(0.94, 0.89, 0.26),
	"equipamento": Color(0.8, 0.47, 0.65),
	"exclusiva": Color(0.9, 0.6, 0.0),
	"evolucao": Color(1, 1, 1),
	"cura": Color(0.9, 0.9, 0.9),
	"bom": Color(0.34, 0.7, 0.91),
	"ruim": Color(0.9, 0.45, 0.05),
	"vida_chefe": Color(0.9, 0.45, 0.05),
	"vida_duelo": Color(0.9, 0.45, 0.05),
	"alerta": Color(0.9, 0.5, 0.1),
	"destaque": Color(0.94, 0.89, 0.26),
	"comportamento": Color(0.0, 0.62, 0.45),
	"perigo": Color(0.9, 0.45, 0.05),
	"area_aliada": Color(0.34, 0.7, 0.91),
}
## raridade da dádiva (dadivas.json) -> cor segura (vale só no modo daltônico; no normal vale a cor do JSON)
const RARIDADE_SEGURA := {
	"comum": Color(0.78, 0.78, 0.78),
	"rara": Color(0.34, 0.7, 0.91),
	"epica": Color(0.94, 0.89, 0.26),
	"heroica": Color(0.9, 0.5, 0.0),
}
const ROTULOS := {
	"dano": "Dano",
	"recarga": "Recarga",
	"quantidade": "Qtd",
	"area": "Área",
	"alcance": "Alcance",
	"arco": "Arco",
	"perfura": "Atravessa",
	"duracao": "Duração",
	"tique": "Tique",
	"velocidade": "Veloc.",
	"velocidade_proj": "Veloc.",
	"vida_max": "Vida",
	"ima": "Ímã",
	"sorte": "Sorte",
	"xp": "XP",
	"critico": "Crítico",
	"regen": "Regen",
	"ricochete": "Ricochete",
	"explosivo": "Explosão",
	"corte_energia": "Corte",
}
## atributos em que MENOS é melhor (a cor do "depois" inverte)
const MENOR_MELHOR := ["recarga", "tique"]
## atributos que, nos passivos/equipamentos, viram porcentagem
const PERCENTUAL := ["dano", "recarga", "area", "velocidade", "velocidade_proj", "ima", "sorte", "xp", "critico", "duracao"]
const MAX_LINHAS_CMP := 3


static func daltonico() -> bool:
	return bool(Config.v("daltonico"))


## Cor semântica da interface (arma, passivo, bom, ruim, vida_chefe...) já respeitando o modo daltônico.
static func cor(chave: String) -> Color:
	var p: Dictionary = SEGURA if daltonico() else PADRAO
	return p.get(chave, Color.WHITE)


static func cor_raridade(raridade: String, original: Color) -> Color:
	return RARIDADE_SEGURA.get(raridade, original) if daltonico() else original


## Tamanho de fonte do HUD: a opção "Tamanho da fonte do HUD" (1x, 1,5x, 2x) multiplica os textos pequenos.
static func tam_hud(tam: int) -> int:
	return tam if tam >= 16 else int(round(tam * Config.fator_fonte()))


# ---------- mouse ----------


## Índice do primeiro retângulo que contém o ponto `p` (ou -1). Telas montam a lista de retângulos que desenham e
## usam a mesma lista pro passar-por-cima e pro clique, assim desenho e hit-test nunca divergem.
static func quem(retangulos: Array, p: Vector2) -> int:
	for i in retangulos.size():
		if retangulos[i].has_point(p):
			return i
	return -1


## Clique esquerdo de verdade (pressionado, sem eco).
static func clique(e: InputEvent) -> bool:
	return e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT


# ---------- cartas: "antes > depois" ----------


static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	var s := "%.2f" % v
	if s.ends_with("0"):
		s = s.left(-1)
	return s


static func _rot(k: String) -> String:
	return str(ROTULOS.get(k, k.capitalize())).left(9)


static func _fmt_bonus(k: String, v: float) -> String:
	if k in PERCENTUAL:
		return "%+d%%" % roundi(v * 100.0)
	var sinal := "+" if v >= 0.0 else ""
	if k == "regen":
		return sinal + _num(v) + "/s"
	return sinal + _num(v)


## Linhas "Dano 18>24" de uma carta. Cada linha: {rot, antes, depois, bom}. `antes` vazio = atributo novo (só mostra o depois).
## arma nível 1: atributos-base; arma nível N: o que o nível N muda (acumulado); passivo: efeito x (N-1) > x N;
## equipamento: bônus. Evolução, cura e dádiva não têm (o texto da carta já explica).
static func comparacao(tipo: String, id: String, nv: int) -> Array:
	var d := Dados.item(id)
	var res := []
	match tipo:
		"arma":
			var base: Dictionary = d.get("base", {})
			var niveis: Array = d.get("niveis", [])
			if nv <= 1:
				for k in ["dano", "recarga", "quantidade"]:
					if float(base.get(k, 0.0)) > (1.0 if k == "quantidade" else 0.0) and res.size() < 2:
						res.append({"rot": _rot(k), "antes": "", "depois": _num(float(base[k])), "bom": true})
			elif nv - 2 < niveis.size():
				var delta: Dictionary = niveis[nv - 2]
				for k in delta:
					var acum := float(base.get(k, 0.0))
					for j in nv - 2:
						acum += float(niveis[j].get(k, 0.0))
					var novo := acum + float(delta[k])
					var melhor := novo < acum if k in MENOR_MELHOR else novo > acum
					res.append({"rot": _rot(str(k)), "antes": _num(acum), "depois": _num(novo), "bom": melhor})
			# a arma também cresce de tamanho a cada nível (curva de dados/crescimento_armas.json): linha própria, sempre à vista
			if (
				not d.is_empty()
				and d.has("niveis")
				and not d.get("evolucao", false)
				and nv > 1
				and nv - 2 < niveis.size()
				and not Dados.json("crescimento_armas").is_empty()
			):
				var cr := preload("res://scripts/hordas/crescimento.gd")
				if res.size() >= MAX_LINHAS_CMP:
					res.resize(MAX_LINHAS_CMP - 1)
				res.append(
					{
						"rot": "Tamanho",
						"antes": "%d%%" % roundi(cr.mult(id, nv - 1, "area") * 100.0),
						"depois": "%d%%" % roundi(cr.mult(id, nv, "area") * 100.0),
						"bom": true
					}
				)
		"passivo":
			var ef: Dictionary = d.get("efeito", {})
			for k in ef:
				var v := float(ef[k])
				var melhor := v < 0.0 if k in MENOR_MELHOR else v > 0.0
				res.append(
					{"rot": _rot(str(k)), "antes": _fmt_bonus(str(k), v * (nv - 1)) if nv > 1 else "", "depois": _fmt_bonus(str(k), v * nv), "bom": melhor}
				)
		"equipamento":
			var bn: Dictionary = d.get("bonus", {})
			for k in bn:
				var v := float(bn[k])
				res.append({"rot": _rot(str(k)), "antes": "", "depois": _fmt_bonus(str(k), v), "bom": v > 0.0})
	if res.size() > MAX_LINHAS_CMP:
		res.resize(MAX_LINHAS_CMP)
	return res


# ---------- fim da corrida: dano / DPS / tempo por arma ----------


## Uma linha por arma usada na corrida, da que mais causou dano pra que menos. dps = dano / tempo com a arma
## (no mínimo 1 s, pra uma arma que acabou de entrar não dar DPS absurdo). `top_dano` e `top_dps` marcam a melhor
## de cada coluna (a tela pinta de amarelo, como no Vampire Survivors). Arma sem tempo registrado usa o tempo da corrida.
static func tabela_armas(dano: Dictionary, nivel: Dictionary, tempo: Dictionary, tempo_total := 0.0) -> Array:
	var ids := {}
	for id in dano:
		ids[id] = true
	for id in tempo:
		ids[id] = true
	var linhas := []
	for id in ids:
		var d := Dados.item(str(id))
		if str(id).begins_with("elem_"):  # dano de elemento (#72): queimadura, veneno, saltos e reações aparecem como uma linha com nome e ícone próprios
			d = Dados.json("elementos").get("elementos", {}).get(str(id).substr(5), {}).duplicate()
			d["nome"] = d.get("nome_dano", id)
		var t := float(tempo.get(id, tempo_total))
		var dn := float(dano.get(id, 0.0))
		linhas.append(
			{
				"id": str(id),
				"nome": str(d.get("nome", id)),
				"icone": str(d.get("icone", id)),
				"nivel": int(nivel.get(id, 1)),
				"evo": bool(d.get("evolucao", false)),
				"dano": dn,
				"tempo": t,
				"dps": dn / maxf(t, 1.0),
				"top_dano": false,
				"top_dps": false
			}
		)
	linhas.sort_custom(func(a, b): return a.dano > b.dano or (a.dano == b.dano and a.id < b.id))
	var mx_d := 0.0
	var mx_p := 0.0
	for l in linhas:
		mx_d = maxf(mx_d, l.dano)
		mx_p = maxf(mx_p, l.dps)
	for l in linhas:
		l.top_dano = mx_d > 0.0 and l.dano == mx_d
		l.top_dps = mx_p > 0.0 and l.dps == mx_p
	return linhas


static func texto_tempo(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


## Números grandes ficam curtos na tabela: 52000 -> "52.0k".
static func texto_dano(v: float) -> String:
	if v >= 1.0e6:
		return "%.1fM" % (v / 1.0e6)
	if v >= 1.0e4:
		return "%.1fk" % (v / 1.0e3)
	return str(int(round(v)))
