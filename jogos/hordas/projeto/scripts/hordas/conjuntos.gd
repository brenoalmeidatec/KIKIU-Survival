extends RefCounted
## Etiquetas e bônus de conjunto (#63, estilo Brotato/Soulstone). Tudo vem de dados/conjuntos.json.
## Cada arma, passivo e equipamento tem "etiquetas"; quem tem N itens da mesma etiqueta liga os degraus dela
## (2, 4, 6...), e os degraus de baixo continuam ligados. Funções puras: a arena guarda o resultado (arena.conj_*)
## e recalcula a cada mudança de build (armas.adicionar/trocar, passivo, equipamento).
##
## GANCHO PARA AS CARTAS (cartas.gd não foi mexido): arena._carta() põe `etiquetas` (ids) e `etiquetas_txt`
## (ex.: "Lâmina 2>3  Fogo 1>2") em cada carta de arma/passivo/equipamento; a tela de cartas só precisa
## desenhar `c.etiquetas_txt` onde quiser. `rotulo_carta()` monta esse texto.


static func cfg() -> Dictionary:
	return Dados.json("conjuntos")


## Etiquetas (ids) de uma arma, passivo ou equipamento.
static func etiquetas_de(id: String) -> Array:
	var e = Dados.item(id).get("etiquetas", [])
	return e if e is Array else []


static func nome_etiqueta(etq: String) -> String:
	var d = cfg().get("etiquetas", {}).get(etq, {})
	return str(d.get("nome", etq.capitalize()))


static func cor_etiqueta(etq: String) -> Color:
	var c = cfg().get("etiquetas", {}).get(etq, {}).get("cor", [1, 1, 1])
	return Color(float(c[0]), float(c[1]), float(c[2]))


## Quantos itens de cada etiqueta a build tem: {etiqueta: n}. Passivo conta 1 em qualquer nível;
## equipamento é o dicionário slot -> id.
static func contar(armas_ids: Array, passivos: Dictionary, equipados: Dictionary) -> Dictionary:
	var res := {}
	var ids: Array = armas_ids.duplicate()
	ids.append_array(passivos.keys())
	ids.append_array(equipados.values())
	for id in ids:
		for e in etiquetas_de(str(id)):
			res[str(e)] = int(res.get(str(e), 0)) + 1
	return res


## Degraus de uma etiqueta, em ordem crescente (ints).
static func degraus(etq: String) -> Array:
	var d: Dictionary = cfg().get("limiares", {}).get(etq, {})
	var r := []
	for k in d:
		r.append(int(k))
	r.sort()
	return r


static func _degrau(etq: String, n: int) -> Dictionary:
	return cfg().get("limiares", {}).get(etq, {}).get(str(n), {})


## Degrau mais alto que a contagem n já alcançou (0 = nenhum).
static func nivel_ativo(etq: String, n: int) -> int:
	var m := 0
	for g in degraus(etq):
		if n >= g:
			m = g
	return m


## Próximo degrau que ainda falta (0 = já está no último).
static func proximo(etq: String, n: int) -> int:
	for g in degraus(etq):
		if n < g:
			return g
	return 0


static func _somar(contagem: Dictionary, campo: String) -> Dictionary:
	var s := {}
	for etq in contagem:
		for g in degraus(etq):
			if int(contagem[etq]) >= g:
				var b: Dictionary = _degrau(etq, g).get(campo, {})
				for k in b:
					s[k] = float(s.get(k, 0.0)) + float(b[k])
	return s


## Soma dos bônus de atributo de todos os degraus ligados.
static func bonus(contagem: Dictionary) -> Dictionary:
	return _somar(contagem, "bonus")


## Soma dos efeitos de comportamento ligados (explosao_morte, lento_acerto, cura_abate...). Veja arena.conj().
## Os que são "duração" (lento_acerto) pegam o maior em vez da soma, pra não empilhar lentidão eterna.
static func efeitos(contagem: Dictionary) -> Dictionary:
	var s := _somar(contagem, "efeito")
	var maior := {}
	for etq in contagem:
		for g in degraus(etq):
			if int(contagem[etq]) >= g:
				var b: Dictionary = _degrau(etq, g).get("efeito", {})
				if b.has("lento_acerto"):
					maior["lento_acerto"] = maxf(float(maior.get("lento_acerto", 0.0)), float(b.lento_acerto))
	for k in maior:
		s[k] = maior[k]
	return s


## Resumo para o HUD e a tela de fim: uma linha por etiqueta que a build tem (as que já ligaram primeiro, depois
## as mais cheias). {etq, nome, n, ativo (degrau ligado), prox (próximo degrau), cor, texto (do degrau ligado), conjunto}
static func resumo(contagem: Dictionary) -> Array:
	var r := []
	for etq in contagem:
		var n := int(contagem[etq])
		if n <= 0 or degraus(etq).is_empty():
			continue
		var at := nivel_ativo(etq, n)
		var d: Dictionary = cfg().get("etiquetas", {}).get(etq, {})
		r.append(
			{
				"etq": etq,
				"nome": str(d.get("conjunto", nome_etiqueta(etq))),
				"n": n,
				"ativo": at,
				"prox": proximo(etq, n),
				"cor": cor_etiqueta(etq),
				"texto": str(_degrau(etq, at).get("texto", "")) if at > 0 else ""
			}
		)
	r.sort_custom(
		func(a, b):
			if (a.ativo > 0) != (b.ativo > 0):
				return a.ativo > 0
			if a.n != b.n:
				return a.n > b.n
			return str(a.etq) < str(b.etq)
	)
	return r


## "n/próximo" como o jogador lê: "2/4" (ou "6" quando já está no último degrau).
static func progresso_txt(l: Dictionary) -> String:
	return "%d/%d" % [int(l.n), int(l.prox)] if int(l.prox) > 0 else "%d" % int(l.n)


## Texto de carta: o que as etiquetas do item mudariam na build atual ("Lâmina 2>3  Fogo 0>1").
static func rotulo_carta(id: String, contagem: Dictionary) -> String:
	var partes := []
	for e in etiquetas_de(id):
		if degraus(str(e)).is_empty():
			continue
		var n := int(contagem.get(str(e), 0))
		partes.append("%s %d>%d" % [nome_etiqueta(str(e)), n, n + 1])
	return "  ".join(partes)
