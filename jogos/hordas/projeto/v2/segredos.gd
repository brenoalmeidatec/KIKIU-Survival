extends RefCounted
## Os segredos escondidos dos mapas (#424): a lista (dados/v2_segredos.json) e a conquista que cada um vira. Segredo achado é uma conquista
## `segredo_<id>` no save do personagem (Meta.achar_segredo), então o Códice e a pausa o mostram pela conta de sempre (v2/conquistas.gd):
## a dica e "???" antes, o nome e o fragmento de lore depois. Quem vigia a partida é v2/vigia_segredos.gd. Não carrega Meta (é o Meta que
## carrega este arquivo, e as duas precisam se ver sem laço): a gravação fica em Meta.achar_segredo.

const PREFIXO := "segredo_"

static var _conquistas: Array = []


## Os segredos do mapa `local` (ou todos, sem argumento), na ordem do json.
static func lista(local := "") -> Array:
	var todos: Array = Dados.json("v2_segredos").get("segredos", [])
	if local == "":
		return todos
	return todos.filter(func(s): return str(s.local) == local)


## O id da conquista de um segredo (o que fica gravado no save).
static func id_conquista(id: String) -> String:
	return PREFIXO + id


## A velocidade (px/s) abaixo da qual o herói conta como parado.
static func parado_vel_max() -> float:
	return float(Dados.json("v2_segredos").get("parado_vel_max", 8.0))


## O fragmento de lore inteiro, numa linha só.
static func lore(s: Dictionary) -> String:
	return " ".join(PackedStringArray(s.lore))


## Uma conquista por segredo, no formato do catálogo (Meta.conquistas junta estas com as de dados/v2_meta.json). Tem `local`, nunca `mapa`:
## conquista com `mapa` é vitória daquele mapa e mexeria nas travas dos portais.
static func conquistas() -> Array:
	if _conquistas.is_empty():
		for s in lista():
			(
				_conquistas
				. append(
					{
						"id": id_conquista(str(s.id)),
						"nome": str(s.nome),
						"desc": "Um segredo escondido num mapa.",  # curto e sem spoiler: é o que a tela antiga do santuário (altar.gd) mostra
						"condicao": "segredo",
						"limite": 1,
						"icone": str(s.get("icone", "codice")),
						"recompensa": s.recompensa,
						"segredo": true,
						"dica": str(s.dica),
						"lore": s.lore,
						"local": str(s.local),
					}
				)
			)
	return _conquistas
