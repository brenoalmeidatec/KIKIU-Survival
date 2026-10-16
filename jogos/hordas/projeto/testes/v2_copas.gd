extends Node
# Teste do modo "inteiro" das copas da v2 (Cidade): o PRÉDIO INTEIRO fica translúcido quando o herói passa atrás dele.
#   - cidade: herói atrás de um predio_*: a força sobe (sprite todo a ALFA_INTEIRO); na frente dele não sobe;
#   - objetos fora de `mapa.copas_inteiro` (poste) seguem com o buraco, sem modo inteiro;
#   - floresta: nada muda (nenhum objeto em modo inteiro; a árvore continua com o buraco).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_copas.tscn  (imprime "v2_copas falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _mundo(id: String):
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = id
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.imortal = true
	w.combate.diretor.ligado = false
	w.combate.limpar_partida()
	return w


func _passos(w, n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _ready() -> void:
	# cidade
	var w = _mundo("cidade")
	var predio = null
	for o in w.cenario.objetos:
		if o.chave.begins_with("predio_") and w.copas.e_inteiro(o):
			predio = o
			break
	ok(predio != null, "cidade: há prédio em modo inteiro")
	if predio != null:
		var topo: float = predio.sprite.get_rect().size.y
		w.heroi.definir_pos(predio.pos + Vector2(0, -40))
		_passos(w, 90)
		ok(w.copas.fuerza_da_copa(predio) > 0.97, "cidade: atrás do prédio a força sobe (%.2f)" % w.copas.fuerza_da_copa(predio))
		ok(predio.sprite.material.get_shader_parameter("inteiro") == true, "cidade: o material do prédio está em modo inteiro")
		ok(absf(float(predio.sprite.material.get_shader_parameter("alfa_inteiro")) - 0.4) < 0.001, "cidade: alfa inteiro 0,4")
		w.heroi.definir_pos(predio.pos + Vector2(0, 60))
		_passos(w, 90)
		ok(w.copas.fuerza_da_copa(predio) < 0.01, "cidade: na frente do prédio a força não sobe (%.2f)" % w.copas.fuerza_da_copa(predio))
		ok(topo > 0.0, "cidade: o sprite do prédio tem altura")
	var poste = null
	for o in w.cenario.objetos:
		if o.chave.begins_with("poste_rua") and w.copas._altos.has(o):
			poste = o
			break
	if poste != null:
		ok(not w.copas.e_inteiro(poste), "cidade: poste fica com o buraco (fora de copas_inteiro)")
	w.queue_free()
	await get_tree().process_frame

	# floresta: nada de modo inteiro
	var f = _mundo("floresta")
	var n_int := 0
	for o in f.cenario.objetos:
		if f.copas.e_inteiro(o):
			n_int += 1
	ok(n_int == 0, "floresta: nenhum objeto em modo inteiro (%d)" % n_int)
	var arvore = null
	for o in f.cenario.objetos:
		if o.chave == "arvore" and o.pos.x > 500.0 and o.pos.x < 2300.0 and o.pos.y > 500.0 and o.pos.y < 1100.0:
			arvore = o
			break
	ok(arvore != null, "floresta: há árvore")
	if arvore != null:
		f.heroi.definir_pos(arvore.pos + Vector2(0, -40))
		_passos(f, 90)
		ok(f.copas.fuerza_da_copa(arvore) > 0.97, "floresta: o buraco da árvore segue ligando")
		ok(arvore.sprite.material.get_shader_parameter("inteiro") != true, "floresta: a árvore não está em modo inteiro")
	print("v2_copas falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
