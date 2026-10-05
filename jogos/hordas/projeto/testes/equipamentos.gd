extends Node
# Teste automático: equipamentos visuais modulares (seções 6 e 7 do design)
# Roda: godot --headless --path jogos/hordas/projeto res://testes/equipamentos.tscn  (imprime "EQUIP falhas=0")
const E := preload("res://scripts/hordas/equipamento.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func _ready() -> void:
	# montador de camadas
	ok(E.camadas([], {}) == ["cabelo"], "sem nada: só o cabelo (%s)" % [E.camadas([], {})])
	var c1 := E.camadas([], {"cabeca": "cabeca_guerreiro"})
	ok(not "cabelo" in c1 and "cabeca_guerreiro" in c1, "elmo esconde o cabelo (%s)" % [c1])
	var c2 := E.camadas(["katana"], {})
	ok("katana_mao" in c2 and not "katana_bainha" in c2, "katana sozinha fica na mão (%s)" % [c2])
	var c3 := E.camadas(["katana", "desert_eagles"], {})
	ok("pistolas" in c3 and "katana_bainha" in c3 and not "katana_mao" in c3, "pistolas nas mãos, katana na bainha (%s)" % [c3])
	var c4 := E.camadas(["arte_marcial"], {})
	ok(c4 == ["cabelo"], "arte marcial: nada nas mãos (%s)" % [c4])
	var tudo := E.camadas(["katana"], {"pes": "botas_guerra", "peitoral": "armadura_samurai", "cabeca": "cabeca_guerreiro"})
	ok(tudo.find("botas") < tudo.find("armadura_samurai") and tudo.find("armadura_samurai") < tudo.find("cabeca_guerreiro")
		and tudo.find("cabeca_guerreiro") < tudo.find("katana_mao"), "ordem de desenho (%s)" % [tudo])
	ok(E.bonus({"cabeca": "cabeca_guerreiro", "peitoral": "armadura_samurai"}).get("vida_max", 0.0) == 65.0, "bônus somam")
	# todo equipamento tem a camada desenhada
	for id in Dados.json("equipamentos"):
		var d := E.dados(id)
		if not d.is_empty():
			ok(ResourceLoader.exists("res://assets/personagens/hazaki/camadas/%s.png" % d.camada), "camada de %s existe" % id)
			ok(ResourceLoader.exists("res://assets/gerado/icone_%s.png" % d.icone), "ícone de %s existe" % id)
	# cartas: só pra quem tem modelo em camadas, e só slot livre
	var m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(0.3).timeout
	m._comecar("nicao")
	var a = m._arena
	var vistas := 0
	for i in 2000:
		for c in a.sortear_cartas():
			if c.tipo == "equipamento":
				vistas += 1
	ok(vistas == 0, "Nicão (sem camadas) nunca vê equipamento (%d)" % vistas)
	a.queue_free()
	await get_tree().process_frame
	m._comecar("hazaki")
	a = m._arena
	var hz := 0
	for i in 2000:
		for c in a.sortear_cartas():
			if c.tipo == "equipamento":
				hz += 1
	ok(hz > 0, "Hazaki vê equipamentos (%d)" % hz)
	a.aplicar({"tipo": "equipamento", "id": "cabeca_guerreiro"})
	var cabeca := 0
	for i in 2000:
		for c in a.sortear_cartas():
			if c.tipo == "equipamento" and c.id == "cabeca_guerreiro":
				cabeca += 1
	ok(cabeca == 0, "slot da cabeça ocupado: não oferece de novo (%d)" % cabeca)
	await get_tree().process_frame
	ok(a.jogador.camadas.has("cabeca_guerreiro") and not a.jogador.camadas.has("cabelo"), "jogador desenha o elmo e esconde o cabelo (%s)" % [a.jogador.camadas.keys()])
	ok(a.stat("vida_max") >= 125.0, "elmo deu vida (%s)" % a.stat("vida_max"))
	print("EQUIP falhas=%d  (Hazaki viu equipamentos %d vezes)" % [falhas, hz])
	get_tree().quit(1 if falhas > 0 else 0)
