extends "res://testes/isolamento_v2.gd"
# Teste de DESEMPENHO da teia (v2/teias.gd): com 100 monstros (metade aranhas atiradoras), 6 teias no chão e 3 queimando, o passo da teia (atualizar) custa pouco, não cria nó (o pool é fixo),
# e no perfil gráfico Baixo o teto cai (3 teias). Imprime o tempo médio por quadro; o limite é folgado (a conta é um laço de ~10 slots e 6 testes de elipse).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_teia_perf.tscn  (imprime "v2_teia_perf falhas=0")

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
const Anim := preload("res://v2/anim_golpes.gd")
const PASSO := 1.0 / 60.0
const LIMITE_US := 400.0  # µs por quadro (o passo todo do jogo com 100 monstros é ~8 ms: a teia fica abaixo de 5% disso)

var falhas := 0
var w
var h


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _nos() -> Dictionary:
	var d := {}
	var fila: Array = [get_tree().root]
	while not fila.is_empty():
		var n: Node = fila.pop_back()
		d[str(n.get_path())] = true
		fila.append_array(n.get_children())
	return d


func _ready() -> void:
	Herois.forcado = "hazaki"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	Colisao.limpar()
	h = w.heroi
	h.imortal = true
	h.pos = w.limite_andavel.get_center()
	h.definir_pos(h.pos)
	var t = w.combate.teias
	var tipo := {"id": "t", "liso": true, "teia": true}
	for k in 100:
		var m = w.nascer_monstro(
			"inimigo_aranha_tecela" if k % 2 == 0 else "inimigo_cao_ossos", h.pos + Vector2.from_angle(k * 0.37) * (110.0 + 3.0 * k), false, 1.0, 1.0, tipo
		)
		m.vida_max = 99999.0
		m.vida = 99999.0
	passos(5)
	for k in t.max_vivas:
		var i: int = t._livre()
		t._est[i] = t.PARADA
		t._pos[i] = h.pos + Vector2(-200 + 70 * k, 90 + 14 * (k % 2))
		t._t[i] = 0.0
		t._idade[i] = 0.0
	for k in 3:
		var j: int = t._est.find(t.PARADA)
		t._est[j] = t.QUEIMANDO
		t._t[j] = 0.0
	ok(t.contar(t.QUEIMANDO) == 3 and t.contar(t.PARADA) == t.max_vivas - 3, "6 teias: 3 queimando, o resto parado")
	var antes := _nos()
	var t0 := Time.get_ticks_usec()
	var n := 600
	for k in n:
		t.atualizar(PASSO)
		# repõe as teias que acabam, para o laço ter sempre o mesmo trabalho
		for j in t._est.size():
			if t._est[j] == t.LIVRE and t.contar(t.PARADA) < t.max_vivas - 3:
				t._est[j] = t.PARADA
				t._pos[j] = h.pos + Vector2(-150 + 40 * j, 90)
				t._t[j] = 0.0
				t._idade[j] = 0.0
	var us := float(Time.get_ticks_usec() - t0) / float(n)
	print("teias.atualizar: %.1f us por quadro (limite %.0f)" % [us, LIMITE_US])
	ok(us < LIMITE_US, "o passo da teia custa menos de %.0f us por quadro (%.1f)" % [LIMITE_US, us])
	# com os monstros e as aranhas atirando: o passo do mundo inteiro, só para constar
	var t1 := Time.get_ticks_usec()
	passos(480)
	print("mundo com 100 monstros e 50 aranhas atiradoras: %.2f ms por quadro" % (float(Time.get_ticks_usec() - t1) / 480.0 / 1000.0))
	# a horda (v2/horda.gd) cria as fatias do y-sort do lote sob demanda, com 100 monstros andando (MultiMeshInstance2D): isso não é da teia e fica fora da conta
	var novos: Array = []
	for n2 in _nos():
		if not antes.has(n2) and not str(n2).contains("MultiMeshInstance2D"):
			novos.append(n2)
	ok(novos.is_empty(), "o passo e os disparos da teia não criam nó (novos: %s)" % str(novos))
	ok(t.lancadas > 0, "as aranhas atiraram durante o teste (%d)" % t.lancadas)
	ok(t.contar(t.VOANDO) <= t.max_voando, "nunca passa de %d bolotas no ar" % t.max_voando)
	# perfil Baixo
	Anim.suave = false
	ok(t.teto_vivas() == 3, "o perfil Baixo limita a 3 teias vivas")
	Anim.suave = true
	print("v2_teia_perf falhas=%d" % falhas)
	get_tree().quit()
