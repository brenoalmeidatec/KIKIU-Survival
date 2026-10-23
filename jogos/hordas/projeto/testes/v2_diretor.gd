extends "res://testes/isolamento_v2.gd"
# Teste dos NÍVEIS do mapa (v2/diretor.gd e dados/v2_niveis.json): a Floresta tem 30 níveis, o nível sobe a cada seg_nivel() segundos e,
# nos níveis de chefe, o diretor faz nascer o mini-chefe (o chefão no último) e o nível TRAVA até ele morrer. Os chefes e a vitória
# ficam em testes/v2_chefe.gd.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_diretor.tscn  (imprime "v2_diretor falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var sinais := {}


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func ate(cond: Callable, max_passos: int) -> int:
	for i in max_passos:
		if cond.call():
			return i
		w.avancar(PASSO)
	return -1 if not cond.call() else max_passos


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.correr_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	w.combate.cartas.rng.seed = 12345
	sinais.clear()
	passos(3)


func conta(nome: String) -> int:
	return int(sinais.get(nome, 0))


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	for nome in ["onda_forte", "elite_apareceu", "chefe_apareceu", "chefe_vida", "evolucao", "anuncio", "partida_terminou"]:
		ok(w.has_signal(nome), "sinal %s existe" % nome)
	w.evolucao.connect(
		func(n, d):
			sinais["evolucao"] = conta("evolucao") + 1
			sinais["evolucao_nome"] = n
			sinais["evolucao_desc"] = d
	)
	w.elite_apareceu.connect(
		func(n):
			sinais["elite"] = conta("elite") + 1
			sinais["elite_nome"] = n
	)
	w.chefe_apareceu.connect(
		func(n, v):
			sinais["chefe"] = conta("chefe") + 1
			sinais["chefe_nome"] = n
			sinais["chefe_vida_max"] = v
	)
	w.chefe_vida.connect(
		func(v):
			sinais["chefe_vida"] = conta("chefe_vida") + 1
			sinais["chefe_vida_ultima"] = v
	)
	w.anuncio.connect(
		func(t, _c):
			sinais["anuncio"] = conta("anuncio") + 1
			sinais["anuncio_texto"] = t
	)
	w.onda_forte.connect(
		func(n):
			sinais["onda"] = conta("onda") + 1
			sinais["onda_n"] = n
	)
	w.partida_terminou.connect(
		func(r):
			sinais["fim"] = conta("fim") + 1
			sinais["fim_res"] = r
	)
	# 7. níveis do mapa (Floresta: 30 níveis, mini-chefes no 10 e no 20, chefão no 30), ataques anunciados
	zerar()
	w.combate.diretor.ligado = false
	var dir = w.combate.diretor
	ok(dir.nivel == 1 and dir.niveis_total == 30, "a Floresta começa no nível 1 de 30 (%d/%d)" % [dir.nivel, dir.niveis_total])
	ok(dir.chefes_mapa.map(func(e): return e.nivel) == [10, 20, 30], "chefes nos níveis 10, 20 e 30")
	ok(dir.chefes_mapa[0].mk.mini and dir.chefes_mapa[1].mk.mini and not dir.chefes_mapa[2].mk.mini, "só o do último nível é o chefão")
	var seg: float = dir.seg_nivel()
	dir.avancar_nivel(seg * 2.5)
	ok(dir.nivel == 3 and absf(dir.t_nivel - seg * 0.5) < 0.2, "o nível sobe a cada %.0f s (nível %d)" % [seg, dir.nivel])
	ok(absf(dir.fracao_mapa() - 2.5 / 29.0) < 0.02, "a barra do mapa anda com o nível (%.3f)" % dir.fracao_mapa())
	dir.ir_para_nivel(9)
	dir.t_nivel = seg - 0.5
	passos(10)
	ok(not w.combate.chefes.vivo and dir.nivel == 9, "no nível 9 ainda não tem mini-chefe")
	passos(40)
	ok(dir.nivel == 10 and w.combate.chefes.vivo and w.combate.chefes.marca.id == "n10", "o mini-chefe nasce ao chegar no nível 10")
	ok(w.combate.chefes.marca.nome == "Cavaleiro Rubro", "o do nível 10 é o Cavaleiro Rubro")
	ok(dir.travado(), "com o mini-chefe vivo o nível trava")
	dir.avancar_nivel(seg * 5.0)
	ok(dir.nivel == 10 and dir.fracao_mapa() <= 9.0 / 29.0 + 0.001, "travado: o nível e a barra não andam (%d)" % dir.nivel)

	# Mini-chefe da exploração das Ruínas: não perde a referência quando chega a hora de nascer o chefe de um nível.
	zerar()
	dir.ir_para_nivel(9)
	dir.t_nivel = seg - 0.5
	var marca_exploracao: Dictionary = Dados.json("v2_medio").marcadores.filter(func(m): return str(m.tipo) == "chefe")[0]
	var exploracao = w.combate.chefes.nascer(w._marca_chefe(str(marca_exploracao.marca)), w.heroi.pos + Vector2(160, 0))
	var fracao_antes: float = dir.fracao_mapa()
	dir.avancar_nivel(seg * 3.0)
	dir.avancar_nivel(PASSO)
	ok(dir.nivel == 9 and is_equal_approx(dir.t_nivel, seg - 0.5), "chefe de exploração para o relógio sem acumular tempo devido")
	ok(is_equal_approx(dir.fracao_mapa(), fracao_antes), "a barra preserva a fração do nível enquanto o chefe de exploração vive")
	ok(w.combate.chefes.atual == exploracao and not w.combate.chefes.feitos.has("n10"), "o chefe do nível não substitui o mini-chefe em campo")
	w.combate.ferir(exploracao, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	w.combate.processar_mortes()
	ok(not w.combate.chefes.vivo, "a morte do chefe de exploração continua ligada ao módulo de chefes")
	dir.avancar_nivel(0.51)
	ok(dir.nivel == 10 and w.combate.chefes.vivo and w.combate.chefes.marca.id == "n10", "depois da exploração o relógio retoma e nasce o chefe do nível 10")
	# Também protege um nível de chefe já alcançado (depuração ou outro chamador de ir_para_nivel).
	zerar()
	exploracao = w.combate.chefes.nascer(w._marca_chefe(str(marca_exploracao.marca)), w.heroi.pos + Vector2(160, 0))
	dir.ir_para_nivel(10)
	dir.avancar_nivel(seg)
	ok(w.combate.chefes.atual == exploracao and not w.combate.chefes.feitos.has("n10"), "nível 10 já alcançado ainda espera o chefe de exploração morrer")
	w.combate.ferir(exploracao, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	w.combate.processar_mortes()
	dir.avancar_nivel(PASSO)
	ok(w.combate.chefes.vivo and w.combate.chefes.marca.id == "n10", "sem chefe de exploração o nível pendente faz nascer o próprio chefe")

	print("v2_diretor falhas=%d" % falhas)
	get_tree().quit()
