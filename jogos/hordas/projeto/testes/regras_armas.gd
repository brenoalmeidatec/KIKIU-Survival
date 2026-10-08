extends Node
# Teste automático: confere as regras de armas exclusivas (seções 2, 5 e 12 do design)
# Roda: godot --headless --path jogos/hordas/projeto res://testes/regras_armas.tscn  (imprime "REGRAS falhas=0")
const C := preload("res://scripts/hordas/construcao.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func excl_hazaki() -> Array:
	var r := []
	var d: Dictionary = Dados.json("armas")
	for id in d:
		if not id.begins_with("_") and C.exclusiva(id) and C.dono(id) == "hazaki":
			r.append(id)
	return r

func _ready() -> void:
	var m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(0.3).timeout
	var ex := excl_hazaki()
	ok(ex.size() == 5, "Hazaki tem 5 exclusivas (tem %d)" % ex.size())
	# 1) cartas de outro personagem: nunca exclusiva do Hazaki
	m._comecar("nicao")
	var a = m._arena
	var vistas := 0
	for i in 3000:
		for c in a.sortear_cartas():
			if c.tipo == "arma" and c.id in ex:
				vistas += 1
	ok(vistas == 0, "Nicão nunca vê exclusiva do Hazaki (viu %d)" % vistas)
	a.queue_free()
	await get_tree().process_frame
	# 2) Hazaki: vê exclusivas; com 2 equipadas, não vê mais nenhuma
	m._comecar("hazaki")
	a = m._arena
	var antes := 0
	for i in 3000:
		for c in a.sortear_cartas():
			if c.tipo == "arma" and c.id in ex:
				antes += 1
	ok(antes > 0, "Hazaki vê exclusivas (viu %d)" % antes)
	a.armas.adicionar("katana")
	a.armas.adicionar("aura_hazaki")
	var depois := 0
	var impossivel := 0
	for i in 3000:
		for c in a.sortear_cartas():
			if c.tipo == "arma" and c.id in ex and c.nivel == 1:
				depois += 1
			if c.tipo == "arma" and c.nivel == 1 and not Dados.json("armas").get(c.id, {}).get("universal", false) and not C.arma_permitida(c.id, "hazaki", a.armas.lista.map(func(x): return x.id)):
				impossivel += 1
	ok(depois == 0, "Hazaki com 2 exclusivas não vê outra nova (viu %d)" % depois)
	ok(impossivel == 0, "nenhuma carta nova impossível (%d)" % impossivel)
	# subir de nível as 2 que tem continua possível
	var sobe := 0
	for i in 500:
		for c in a.sortear_cartas():
			if c.tipo == "arma" and c.id in ["katana", "aura_hazaki"] and c.nivel > 1:
				sobe += 1
	ok(sobe > 0, "as 2 exclusivas que ele tem continuam subindo de nível (%d)" % sobe)
	# 3) limite configurável: com limite 3, a terceira volta a aparecer
	Dados.json("armas")["_config"]["limite_exclusivas"] = 3
	var terceira := 0
	for i in 3000:
		for c in a.sortear_cartas():
			if c.tipo == "arma" and c.id in ex and c.nivel == 1:
				terceira += 1
	ok(terceira > 0, "com limite 3, aparece a terceira (%d)" % terceira)
	Dados.json("armas")["_config"]["limite_exclusivas"] = 2
	# 4) builds dos rivais (duelo): Hazaki no máximo 2 exclusivas; outros nunca
	var rng := RandomNumberGenerator.new()
	var max_h := 0
	var outros := 0
	for i in 400:
		var b: Dictionary = C.gerar("hazaki", 60, rng)
		max_h = maxi(max_h, b.armas.filter(func(w): return w.id in ex).size())
		for h in ["nicao", "lucas", "joao", "beto"]:
			var b2: Dictionary = C.gerar(h, 60, rng)
			outros += b2.armas.filter(func(w): return w.id in ex).size()
	ok(max_h <= 2 and max_h > 0, "rival Hazaki: 1 a 2 exclusivas (máximo visto %d)" % max_h)
	ok(outros == 0, "rival de outro personagem nunca tem exclusiva do Hazaki (%d)" % outros)
	print("REGRAS falhas=%d  (Hazaki viu exclusivas %d vezes; com 2: %d; limite 3: %d; rival max %d)" % [falhas, antes, depois, terceira, max_h])
	get_tree().quit(1 if falhas > 0 else 0)
