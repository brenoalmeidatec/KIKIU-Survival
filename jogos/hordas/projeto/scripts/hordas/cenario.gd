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
	carregar_cfg()
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


# ---------- #32 item 2: células do mapa (props, detalhes de chão e bichos), sorteadas pela semente da corrida ----------

const Sorte := preload("res://scripts/hordas/sorte.gd")
const CEL := 150.0              # lado da célula do mapa, em px
const AFASTA := 38.0            # distância mínima entre dois props da mesma célula
const MAX_CACHE := 500          # células guardadas (passou disso, esquece e sorteia de novo: o resultado é o mesmo)

var cfg := {}                   # dados/cenarios.json > cenarios > <nome>
var _cache := {}                # Vector2i -> {props, detalhes, bichos}
var _semente_cache := -1


## Config deste cenário em dados/cenarios.json (densidade, detalhes, particulas, vida). Vazio = só o que já existia.
func carregar_cfg() -> void:
	cfg = Dados.json("cenarios").get("cenarios", {}).get(nome, {})
	densidade = float(cfg.get("densidade", densidade))
	_cache.clear()
	Sorte.criar("cenario_" + nome, 0)   # garante a semente da corrida (Sorte.semente) antes da primeira célula


## Tudo o que mora na célula (cx, cy): sempre igual pra mesma semente da corrida + cenário + célula, em qualquer computador.
## props = [{pos (mundo), item, k}], detalhes = [{tipo, pos (mundo), k, pts, cor}], bichos = [{tipo, pos, ...}] (estado muda no jogo).
## Nada daqui tem colisão: é só desenho.
func celula(cx: int, cy: int) -> Dictionary:
	if Sorte.semente != _semente_cache:
		_cache.clear()
		_semente_cache = Sorte.semente
	var k := Vector2i(cx, cy)
	if _cache.has(k):
		return _cache[k]
	if _cache.size() >= MAX_CACHE:
		_cache.clear()
	var r := Sorte.criar("cenario_" + nome, hash(k))
	var o := Vector2(cx, cy) * CEL
	var res := {"props": [], "detalhes": [], "bichos": []}
	# props: 1 por célula com chance `densidade`, e um segundo com chance `segundo`; afastados entre si
	if _peso_total > 0 and r.randf() < densidade:
		var n := 1 + (1 if r.randf() < float(cfg.get("segundo", 0.0)) else 0)
		for i in n:
			var p := o + Vector2(r.randf_range(0.0, 110.0), r.randf_range(0.0, 110.0))
			var livre := true
			for q in res.props:
				if q.pos.distance_to(p) < AFASTA:
					livre = false
			if livre:
				res.props.append({"pos": p, "item": _item_sorteado(r), "k": r.randi()})
	# detalhes de chão
	var lista: Array = cfg.get("detalhes", [])
	if not lista.is_empty() and r.randf() < float(cfg.get("detalhes_chance", 0.0)):
		for i in r.randi_range(1, int(cfg.get("detalhes_max", 3))):
			res.detalhes.append(_detalhe(r, lista, o))
	# bichos (só visual: fogem do herói)
	var vida: Dictionary = cfg.get("vida", {})
	if not vida.is_empty() and r.randf() < float(vida.get("chance", 0.0)):
		var centro := o + Vector2(r.randf_range(10.0, 140.0), r.randf_range(10.0, 140.0))
		for i in r.randi_range(1, int(vida.get("grupo", 1))):
			var tipo := _tipo_sorteado(r, vida.get("bichos", []))
			if tipo != "":
				res.bichos.append({"tipo": tipo, "pos": centro + Vector2(r.randf_range(-12.0, 12.0), r.randf_range(-8.0, 8.0)), "estado": 0,
					"t": 0.0, "dir": Vector2.ZERO, "alt": 0.0, "ph": r.randf() * TAU, "lado": 1.0 if r.randf() < 0.5 else -1.0})
	_cache[k] = res
	return res


func _item_sorteado(r: RandomNumberGenerator) -> Dictionary:
	var x := r.randi() % maxi(1, _peso_total)
	for it in itens:
		if it.peso <= 0:
			continue
		x -= it.peso
		if x < 0:
			return it
	return itens[0]


static func _tipo_sorteado(r: RandomNumberGenerator, lista: Array) -> String:
	var total := 0
	for e in lista:
		total += int(e.get("peso", 1))
	if total <= 0:
		return ""
	var x := r.randi() % total
	for e in lista:
		x -= int(e.get("peso", 1))
		if x < 0:
			return str(e.tipo)
	return ""


## Um detalhe de chão: o contorno (pontos) já sai pronto pra não gastar no desenho.
static func _detalhe(r: RandomNumberGenerator, lista: Array, o: Vector2) -> Dictionary:
	var tipo := _tipo_sorteado(r, lista)
	var cor: Array = [0.1, 0.1, 0.1, 0.4]
	for e in lista:
		if str(e.tipo) == tipo:
			cor = e.get("cor", cor)
	var d := {"tipo": tipo, "pos": o + Vector2(r.randf_range(6.0, 144.0), r.randf_range(6.0, 144.0)), "k": r.randi(),
		"cor": Color(cor[0], cor[1], cor[2], cor[3]), "pts": PackedVector2Array()}
	var pts := PackedVector2Array()
	match tipo:
		"rachadura":   # caminhada torta
			var p := Vector2.ZERO
			var a := r.randf() * TAU
			for i in r.randi_range(4, 7):
				pts.append(p)
				a += r.randf_range(-0.7, 0.7)
				p += Vector2.from_angle(a) * r.randf_range(5.0, 10.0)
			pts.append(p)
		"cabo":   # curva suave
			var a := r.randf() * TAU
			var p := Vector2.ZERO
			for i in 8:
				pts.append(p)
				a += r.randf_range(-0.45, 0.45)
				p += Vector2.from_angle(a) * 5.0
		"mancha", "poca":   # elipse irregular achatada (vista de cima em 3/4)
			var rx := r.randf_range(7.0, 16.0) * (1.4 if tipo == "poca" else 1.0)
			for i in 10:
				var ang := TAU * i / 10.0
				pts.append(Vector2(cos(ang) * rx * r.randf_range(0.75, 1.1), sin(ang) * rx * 0.5 * r.randf_range(0.75, 1.1)))
		"folha":   # 3 a 5 folhinhas espalhadas
			for i in r.randi_range(3, 5):
				pts.append(Vector2(r.randf_range(-10.0, 10.0), r.randf_range(-5.0, 5.0)))
		"papel":
			var a := r.randf() * PI
			pts.append(Vector2.from_angle(a) * 4.0)
			pts.append(Vector2.from_angle(a + 1.2) * 3.0)
	d.pts = pts
	return d
