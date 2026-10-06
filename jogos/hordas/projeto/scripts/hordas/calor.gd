extends RefCounted
## Calor (#63): dificuldade escolhida antes da corrida, com modificadores opcionais (dados/calor.json).
## Uma "escolha" é {id do modificador: nível}. Daqui saem os pontos de calor, os efeitos somados (que a arena
## aplica: inimigos, diretor, cura, cartas, vida do herói) e a recompensa (mais ouro e XP por ponto).
## A escolha vem do jogador (tela_calor.gd), é lembrada em user://calor.json e, no online, vai do anfitrião pra todos.

const ARQUIVO := "user://calor.json"


static func modificadores() -> Array:
	var m = Dados.json("calor").get("modificadores", [])
	return m if m is Array else []


static func mod(id: String) -> Dictionary:
	for m in modificadores():
		if str(m.get("id", "")) == id:
			return m
	return {}


## Só ids que existem e níveis entre 0 e o máximo (a escolha pode vir da rede ou de um arquivo velho).
static func validar(escolha) -> Dictionary:
	var out := {}
	if not escolha is Dictionary:
		return out
	for id in escolha:
		var m := mod(str(id))
		var nv = escolha[id]
		if m.is_empty() or not (nv is int or nv is float):
			continue
		var n := clampi(int(nv), 0, int(m.get("niveis", 1)))
		if n > 0:
			out[str(id)] = n
	return out


static func pontos(escolha: Dictionary) -> int:
	var p := 0
	for id in escolha:
		p += int(mod(id).get("calor", 1)) * int(escolha[id])
	return p


static func maximo() -> int:
	var p := 0
	for m in modificadores():
		p += int(m.get("calor", 1)) * int(m.get("niveis", 1))
	return p


## Efeitos somados: {inimigo_vida: 0.4, ...} (cada efeito vezes o nível do modificador).
static func efeitos(escolha: Dictionary) -> Dictionary:
	var ef := {}
	for id in escolha:
		var m := mod(id)
		for k in m.get("efeito", {}):
			ef[k] = float(ef.get(k, 0.0)) + float(m.efeito[k]) * int(escolha[id])
	return ef


## Recompensa a mais por ponto de calor (ouro, xp).
static func recompensa(k: String) -> float:
	return float(Dados.json("calor").get("recompensa", {}).get(k, 0.0))


static func ler() -> Dictionary:
	if not FileAccess.file_exists(ARQUIVO):
		return {}
	return validar(JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO)))


static func salvar(escolha: Dictionary) -> void:
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(validar(escolha)))


## "--calor=couro:2,garras:1" (testes) -> {couro: 2, garras: 1}
static func de_texto(t: String) -> Dictionary:
	var e := {}
	for par in t.split(",", false):
		var kv := par.split(":")
		if kv.size() == 2 and kv[1].is_valid_int():
			e[kv[0].strip_edges()] = int(kv[1])
	return validar(e)
