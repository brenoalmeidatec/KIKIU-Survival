extends Node
# Teste automático: troca de tema (#65). Tudo o que os dados citam (ícones, sprites de projétil, coletáveis, pira) existe,
# as cores dos efeitos estão nos dados, e nenhum nome que o jogador vê voltou a ser de informática.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/tema.tscn  (imprime "TEMA falhas=0")
const Armas := preload("res://scripts/hordas/armas.gd")
const ANTIGOS := ["pendrive", "ssd", "cabo de rede", "fibra", "ventoinha", "water cooler", "café", "garrafa térmica", "wi-fi",
	"roteador", "energético", "overclock", "monitor", "ctrl+", "tênis", "marmita", "antena", "fitinha", "água de coco",
	"apostila", "mouse", "tomada", "vírus"]
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func antigo(txt: String) -> String:
	var t := txt.to_lower()
	for a in ANTIGOS:
		if t.contains(a):
			return a
	return ""

func _ready() -> void:
	var globais := ["pendrive", "ssd", "cabo_rede", "fibra_optica", "ventoinha", "water_cooler", "cafe", "garrafa_termica", "wifi", "roteador_5g"]
	for arq in ["armas", "passivos"]:
		var d: Dictionary = Dados.json(arq)
		for k in d:
			if k.begins_with("_") or not d[k] is Dictionary:
				continue
			var it: Dictionary = d[k]
			ok(Dados.icone(str(it.get("icone", k))) != null, "%s %s: o ícone %s existe" % [arq, k, it.get("icone", k)])
			if it.has("sprite"):
				ok(Dados.tex(str(it.sprite)) != null, "%s %s: o sprite %s existe" % [arq, k, it.sprite])
			if arq == "passivos" or k in globais:
				ok(antigo(str(it.get("nome", ""))) == "", "%s %s: o nome '%s' ainda é de informática" % [arq, k, it.get("nome", "")])
				ok(antigo(str(it.get("descricao", ""))) == "", "%s %s: a descrição ainda fala de '%s'" % [arq, k, antigo(str(it.get("descricao", "")))])
	# cores dos efeitos vêm dos dados
	ok(Armas.cor_de(Dados.item("wifi"), Color.BLACK) != Color.BLACK, "a aura do sino tem cor no armas.json")
	ok(Armas.cor_de(Dados.item("cabo_rede"), Color.BLACK) != Color.BLACK, "a corrente tem cor no armas.json")
	ok(Dados.item("fibra_optica").get("fios", []).size() == 3, "a corrente do carrasco tem 3 fios de brasa")
	ok(Armas.rampa_de(Dados.item("cafe")) != Armas.rampa_de({}), "o fogo grego tem rampa própria (não é a do café)")
	# coletáveis, loja e pira
	var col: Dictionary = Dados.json("coletaveis")
	for t in ["marmita", "wifi"]:
		ok(Dados.tex(str(col.get(t, {}).get("sprite", ""))) != null, "coletável %s: o sprite existe" % t)
		ok(antigo(str(col.get(t, {}).get("msg", "x"))) == "", "coletável %s: a mensagem não é de informática" % t)
	ok(Dados.icone(str(col.get("loja_cura", {}).get("icone", ""))) != null, "a cura da loja tem ícone")
	var san: Dictionary = Dados.json("descobertas").get("santuarios", {})
	ok(Dados.tex(str(san.get("sprite", ""))) != null, "o sprite dos santuários (pira) existe")
	ok(antigo(str(san.get("nomes", {}).get("tomada", "Tomada"))) == "", "a tomada virou outra coisa")
	ok(antigo(str(san.get("titulo_tomada", "Tomada"))) == "", "o título da carta da tomada também")
	# heróis não citam as armas antigas
	var her: Dictionary = Dados.json("herois")
	for h in her:
		if her[h] is Dictionary:
			ok(antigo(str(her[h].get("descricao", ""))) == "", "herói %s: a descrição ainda cita '%s'" % [h, antigo(str(her[h].get("descricao", "")))])
	print("TEMA falhas=%d" % falhas)
	get_tree().quit()
