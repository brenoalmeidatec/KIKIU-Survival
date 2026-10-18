extends Node
# Teste automatico: vermelho so para o que machuca o jogador (v2/DESIGN.md, secao 2).
#   - nenhuma arma nem aliado do heroi tem cor vermelha: os golpes de dados/v2_cartas.json (o jogo le esse arquivo)
#     e o registro dos lotes em dados/v2_armas/lote_*.json;
#   - os Fogos de Festival (v2/armas_novas.gd) e as fichas do andante (mistura, cor_fx, tinta) nao sao vermelhos;
#   - o aviso do Explosivo (elite, dados/v2_cartas.json) e vermelho: e perigo para o jogador;
#   - o criterio separa vermelho de dourado, ciano, verde e laranja (PERIGO e vermelho).
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_cores_perigo.tscn  (imprime "v2_cores_perigo falhas=0")
const Armas := preload("res://v2/armas_novas.gd")
const Andante := preload("res://v2/andante.gd")
const Paleta := preload("res://v2/paleta.gd")

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


# Vermelho: matiz de 0 a 16 graus (ou de 344 a 360), saturado e claro. Laranja (de 17 graus para cima) nao conta.
func vermelho(c: Color) -> bool:
	var graus := c.h * 360.0
	return (graus <= 16.0 or graus >= 344.0) and c.s >= 0.5 and c.v >= 0.5


func ler_json(caminho: String):
	return JSON.parse_string(FileAccess.get_file_as_string(caminho))


# Procura, em qualquer nivel do JSON, o dicionario com esse "id".
func achar(v, id: String):
	if v is Dictionary:
		if str(v.get("id", "")) == id:
			return v
		for k in v:
			var r = achar(v[k], id)
			if r != null:
				return r
	elif v is Array:
		for x in v:
			var r = achar(x, id)
			if r != null:
				return r
	return null


func _ready() -> void:
	# o criterio tem de separar vermelho de laranja, dourado, ciano e verde
	ok(vermelho(Paleta.PERIGO), "PERIGO devia ser vermelho")
	for c in [Paleta.OURO, Paleta.DICA, Paleta.BONUS, Color(1.0, 0.7, 0.25), Color(0.5, 0.95, 1.0)]:
		ok(not vermelho(c), "cor que nao e vermelha foi lida como vermelha: %s" % str(c))
	# golpes que o jogo le (dados/v2_cartas.json > golpes): nenhuma cor vermelha
	var cartas = ler_json("res://dados/v2_cartas.json")
	var golpes := 0
	for g in cartas.golpes:
		golpes += 1
		if g.has("cor"):
			ok(not vermelho(Color(g.cor[0], g.cor[1], g.cor[2])), "golpe %s tem cor vermelha %s" % [g.get("id", "?"), str(g.cor)])
	ok(golpes >= 40, "poucos golpes lidos em v2_cartas.json: %d" % golpes)
	# registro dos lotes (dados/v2_armas, so referencia): o mesmo criterio
	var dir := DirAccess.open("res://dados/v2_armas")
	var armas := 0
	for arq in dir.get_files():
		if not (arq.begins_with("lote_") and arq.ends_with(".json")):
			continue
		for a in ler_json("res://dados/v2_armas/" + arq):
			armas += 1
			if a.has("cor"):
				var c := Color(a.cor[0], a.cor[1], a.cor[2])
				ok(not vermelho(c), "%s (%s) tem cor vermelha %s" % [a.get("id", "?"), arq, str(a.cor)])
	ok(armas >= 30, "poucas armas lidas em dados/v2_armas: %d" % armas)
	# Fogos de Festival
	for c in Armas.FOGOS_CORES:
		ok(not vermelho(c), "Fogos de Festival com vermelho: %s" % str(c))
	# andante: aliados (mistura, cor_fx, tinta)
	for id in Andante.FICHAS:
		var f: Dictionary = Andante.FICHAS[id]
		for chave in ["mistura", "cor_fx", "tinta"]:
			if f.has(chave):
				ok(not vermelho(f[chave]), "andante %s: %s e vermelho" % [id, chave])
	# aviso inimigo: o Explosivo e vermelho
	var ex = achar(ler_json("res://dados/v2_cartas.json"), "explosivo")
	ok(ex != null, "explosivo nao achado em dados/v2_cartas.json")
	if ex != null:
		ok(vermelho(Color(ex.cor[0], ex.cor[1], ex.cor[2])), "aviso do Explosivo nao e vermelho: %s" % str(ex.cor))
	print("v2_cores_perigo falhas=%d" % falhas)
	get_tree().quit()
