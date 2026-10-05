extends RefCounted
## Cenário de uma fase (laboratório, masmorra, cidade): piso, enfeites e luzes gerados pelo Blender em
## fonte_arte/modelos3d/cenarios.py (pixel art com a luz "assada"). Qual cenário vai em qual fase: dados/cenarios.json.
## No jogo só entram truques baratos (rodam em qualquer PC): tom de ambiente e halos de luz somados.

var nome := ""
var piso: Texture2D
var atlas: Texture2D
var itens: Array = []            # {regiao: Rect2, pe: Vector2, peso: int, luz: {} ou {poca, halo: Rect2, fonte: Vector2, pisca}}
var ambiente := Color.WHITE
var densidade := 0.3             # chance de ter enfeite em cada célula do mapa
var fixos: Array = []            # {item, pos: Vector2} enfeites em lugar fixo dentro de cada azulejo (ex.: postes)
var _peso_total := 0


## Nome do cenário da fase i (0 = primeira), ou "" se não houver (aí o chão antigo continua).
static func da_fase(i: int) -> String:
	var lista: Array = Dados.json("cenarios").get("por_fase", [])
	if lista.is_empty():
		return ""
	return str(lista[clampi(i, 0, lista.size() - 1)])


func carregar(n: String) -> bool:
	var pasta := "res://assets/cenarios/%s/" % n
	if not FileAccess.file_exists(pasta + "cenario.json"):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(pasta + "cenario.json"))
	if not d is Dictionary:
		push_error("cenario.json com erro: " + pasta)
		return false
	nome = n
	piso = load(pasta + str(d.get("piso", "piso.png")))
	atlas = load(pasta + str(d.get("enfeites", "enfeites.png")))
	var amb: Array = d.get("ambiente", [1, 1, 1])
	ambiente = Color(amb[0], amb[1], amb[2])
	densidade = float(Dados.json("cenarios").get("densidade", 0.3))
	itens.clear()
	_peso_total = 0
	for it in d.get("itens", []):
		var item := {"nome": str(it.get("nome", "")), "regiao": _ret(it.regiao), "pe": Vector2(it.pe[0], it.pe[1]), "peso": int(it.get("peso", 1)), "luz": {}}
		if it.has("luz"):
			var l: Dictionary = it.luz
			item.luz = {"poca": _ret(l.poca), "halo": _ret(l.halo), "fonte": Vector2(l.fonte[0], l.fonte[1]),
				"pisca": float(l.get("pisca", 0.0))}
		itens.append(item)
		_peso_total += item.peso
	fixos.clear()
	for f in d.get("fixos", []):
		for it in itens:
			if it.nome == str(f.item):
				fixos.append({"item": it, "pos": Vector2(f.pos[0], f.pos[1])})
	return piso != null and atlas != null


## Enfeite sorteado pelo número h (sempre o mesmo pro mesmo lugar do mapa), respeitando o peso de cada um.
func item_por(h: int) -> Dictionary:
	var r := h % maxi(1, _peso_total)
	for it in itens:
		r -= it.peso
		if r < 0:
			return it
	return itens[0]


static func _ret(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2], a[3])
