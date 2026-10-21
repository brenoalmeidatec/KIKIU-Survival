extends RefCounted
## Regras de dificuldade, independentes do modificador Pesadelo. A partida usa uma foto das regras: trocar a escolha no save não muda a luta.


static func opcoes() -> Array:
	return Dados.json("v2_dificuldade").opcoes


static func normalizar(id: String) -> String:
	for d in opcoes():
		if str(d.id) == id:
			return id
	return str(Dados.json("v2_dificuldade").padrao)


static func regras(id: String) -> Dictionary:
	var escolhido := normalizar(id)
	for d in opcoes():
		if str(d.id) == escolhido:
			return d.duplicate(true)
	return {}


static func da_partida(mundo) -> Dictionary:
	return mundo.meta_bonus.get("dificuldade", regras("facil"))


static func fator(mundo, chave: String) -> float:
	return float(da_partida(mundo).get(chave, 1.0))
