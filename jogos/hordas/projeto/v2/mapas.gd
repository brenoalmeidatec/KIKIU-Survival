extends RefCounted
## Os mapas da v2: a lista que o santuário mostra, qual está escolhido e o arquivo de dados de cada um (dados/v2_<id>.json).
## A escolha fica no save da meta-progressão ([config] mapa, o mesmo `Meta.caminho_save`) e vale a partir da próxima partida; `--mapa=<id>`
## abre um mapa direto sem gravar. Para criar um mapa novo: gere o JSON (fonte_arte/gerar_v2_mapas.py) e ponha uma linha em LISTA.
## Sem class_name: carregue com preload, como o resto do projeto.

const Meta := preload("res://v2/meta.gd")
const PADRAO := "floresta"
const LISTA := [
	{"id": "floresta", "nome": "FLORESTA", "entrar": "ENTRAR NA FLORESTA", "dados": "v2_floresta"},
	{"id": "laboratorio", "nome": "LABORATÓRIO", "entrar": "ENTRAR NO LABORATÓRIO", "dados": "v2_laboratorio"},
	{"id": "cidade", "nome": "CIDADE", "entrar": "ENTRAR NA CIDADE", "dados": "v2_cidade"},
]


static func ids() -> Array:
	return LISTA.map(func(m): return m.id)


## O mapa da lista (ou o padrão, se o id não existir).
static func buscar(id: String) -> Dictionary:
	for m in LISTA:
		if m.id == id:
			return m
	return LISTA[0]


## O mapa escolhido no santuário (lido do save a cada chamada, como o resto da meta-progressão).
static func escolhido() -> String:
	var cf := ConfigFile.new()
	cf.load(Meta.caminho_save)
	return str(buscar(str(cf.get_value("config", "mapa", PADRAO))).id)


static func escolher(id: String) -> void:
	var cf := ConfigFile.new()
	cf.load(Meta.caminho_save)
	cf.set_value("config", "mapa", str(buscar(id).id))
	var erro := cf.save(Meta.caminho_save)
	if erro != OK:
		push_warning("v2 mapas: não gravou %s (erro %d)" % [Meta.caminho_save, erro])


## O seguinte da lista (dando a volta), a partir do id dado.
static func proximo(id: String, passo := 1) -> String:
	var i := ids().find(str(buscar(id).id))
	return str(LISTA[posmod(i + passo, LISTA.size())].id)
