extends RefCounted
## Medidor de custo por sistema (microssegundos somados por trecho, médias impressas no log do `--sair`).
## Só liga com `Perf.ligado = true` (o main.gd liga com --sair); desligado, cada ponto custa só um `if`.

static var ligado := false
static var us := {}      # nome -> microssegundos acumulados desde o último relatório
static var quadros := 0


static func ini() -> int:
	return Time.get_ticks_usec() if ligado else 0


static func fim(nome: String, t0: int) -> void:
	if ligado:
		us[nome] = int(us.get(nome, 0)) + Time.get_ticks_usec() - t0


## Texto "nome=média_us ..." (média por quadro) e zera.
static func relatorio() -> String:
	var q := maxi(quadros, 1)
	var chaves := us.keys()
	chaves.sort()
	var partes: PackedStringArray = []
	for k in chaves:
		partes.append("%s=%d" % [k, int(us[k]) / q])
	us.clear()
	quadros = 0
	return " ".join(partes)
