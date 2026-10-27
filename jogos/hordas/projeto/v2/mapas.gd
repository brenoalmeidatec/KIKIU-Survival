extends RefCounted
## Os mapas da v2: a lista que o santuário mostra, qual está escolhido e o arquivo de dados de cada um (dados/v2_<id>.json).
## A escolha fica no save da meta-progressão ([config] mapa, o mesmo `Meta.caminho_save`) e vale a partir da próxima partida; `--mapa=<id>`
## abre um mapa direto sem gravar. Para criar um mapa novo: gere o JSON (fonte_arte/gerar_v2_mapas.py) e ponha uma linha em LISTA.
## Sem class_name: carregue com preload, como o resto do projeto.

const Meta := preload("res://v2/meta.gd")
const Progressao := preload("res://v2/progressao.gd")  # travas dos portais (dados/v2_progressao.json)
const PADRAO := "floresta"
const LISTA := [
	{"id": "floresta", "nome": "FLORESTA", "entrar": "ENTRAR NA FLORESTA", "dados": "v2_floresta"},
	{"id": "laboratorio", "nome": "TORRE DO ALQUIMISTA", "entrar": "ENTRAR NA TORRE", "dados": "v2_laboratorio"},
	{"id": "cidade", "nome": "VILA AMALDIÇOADA", "entrar": "ENTRAR NA VILA", "dados": "v2_cidade"},
	{"id": "medio", "nome": "RUÍNAS DA FLORESTA", "entrar": "ENTRAR NAS RUÍNAS", "dados": "v2_medio"},
]


static func ids() -> Array:
	return LISTA.map(func(m): return m.id)


## O texto que fecha o portal do mapa, ou "" se ele está aberto. Duas travas: `requer` (opcional na LISTA, id de uma conquista do save
## do personagem; nenhum mapa usa hoje) e a progressão de dados/v2_progressao.json (v2/progressao.gd: cada mapa abre ao vencer o
## anterior). O texto começa com "Trancado".
static func condicao(m: Dictionary) -> String:
	var req := str(m.get("requer", ""))
	if req != "" and not Meta.estado().conquistas.get(req, false):
		for c in Meta.conquistas():
			if str(c.id) == req:
				return "Trancado: %s" % c.desc
		return "Trancado"
	var aviso := Progressao.aviso("mapa", str(m.get("id", "")))
	return "" if aviso == "" else "Trancado: %s" % aviso


## A linha curta do portal trancado, ao lado do cadeado ("Vença a Floresta"); "" se aberto.
static func curto(m: Dictionary) -> String:
	if condicao(m) == "":
		return ""
	var t := Progressao.curto("mapa", str(m.get("id", "")))
	return t if t != "" else "Trancado"


## O mapa da lista (ou o padrão, se o id não existir).
static func buscar(id: String) -> Dictionary:
	for m in LISTA:
		if m.id == id:
			return m
	return LISTA[0]


## O mapa escolhido no santuário (lido do save a cada chamada, como o resto da meta-progressão). Se o escolhido está trancado
## (save editado, ou escolha de antes das travas), volta ao padrão: ninguém entra num mapa que a progressão ainda não abriu.
static func escolhido() -> String:
	var cf := Meta._ler()
	var m := buscar(str(cf.get_value("config", "mapa", PADRAO)) if cf != null else PADRAO)
	return str(m.id) if condicao(m) == "" else PADRAO


## Grava o mapa da próxima partida. Mapa trancado não é gravado (devolve false e o save fica como estava).
static func escolher(id: String) -> bool:
	if condicao(buscar(id)) != "":
		return false
	Meta.erro_save = false
	var cf := Meta._ler()
	if cf == null:
		Meta.erro_save = true
		return false
	cf.set_value("config", "mapa", str(buscar(id).id))
	Meta.erro_save = not Meta._gravar(cf)
	return not Meta.erro_save


## O próximo mapa ABERTO da lista (dando a volta), a partir do id dado; sem outro aberto, o mesmo.
static func proximo(id: String, passo := 1) -> String:
	var i := ids().find(str(buscar(id).id))
	for k in LISTA.size():
		var m: Dictionary = LISTA[posmod(i + passo * (k + 1), LISTA.size())]
		if condicao(m) == "":
			return str(m.id)
	return str(LISTA[i].id)
