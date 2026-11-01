extends "res://testes/isolamento_v2.gd"
# ECO-8: a escolha de carta do robô de playtest (v2/roteiro.gd, decidir_carta_robo e _pt_escolher_carta).
# O bug: no Difícil cheio (limite de 12 bônus) a mão traz uma carta TROCA; o robô pegava a mais rara, e `progresso.escolher` numa TROCA só abre o painel
# de troca, então ele repetia o pedido a cada quadro até o limite de 8,9 s da tela de cartas (blocos de 533 quadros no JSON bruto) e nunca concluía a troca.
# Confere: a) a decisão pura (a mais rara que NÃO é troca; só troca: a mais rara e larga o bônus mais recente; mão vazia: -1);
# b) numa partida de verdade no Difícil cheio, com a TROCA forçada como a carta mais rara, UMA chamada do robô conclui a escolha (a tela fecha, o bônus
# largado sai, o novo entra, o total segue em 12); c) mão só de TROCA também conclui; d) 30 níveis seguidos sem nunca deixar a escolha aberta.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_roteiro_robo.tscn  (imprime "v2_roteiro_robo falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const Roteiro := preload("res://v2/roteiro.gd")
const PASSO := 1.0 / 60.0
const MODS := ["onda", "fura", "explode"]
const STATS := ["dano", "vida", "area", "vel_ataque"]
var falhas := 0
var w
var cs


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


## Começa de novo no Difícil (mapa sem monstros, herói imortal).
func zerar() -> void:
	if w.pausa.aberto:
		w.pausa.fechar()
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.meta_bonus["dificuldade"] = Dificuldade.regras("dificil")
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	cs = w.combate.cartas
	cs.rng.seed = 777
	w.combate.telas.espera_escolha = 0.0
	w.combate.telas.espera_bau = 0.0
	passos(3)


func dar(id: String, n: int) -> void:
	for k in n:
		cs.aplicar(cs.montar_carta(cs.definicao(id), 0))


func golpes_livres(n: int) -> Array:
	var r: Array = []
	for d in cs.cfg.golpes:
		if cs._disponivel(d) and r.size() < n:
			r.append(str(d.id))
	return r


## Os 12 bônus de um Difícil cheio: 4 golpes, 3 modificadores, 1 ruptura e 4 stats, todos no nível 1.
func encher() -> void:
	var ids: Array = golpes_livres(4) + MODS + ["rb_dano"] + STATS
	for id in ids:
		dar(id, 1)


func subir_nivel() -> void:
	var h = w.heroi
	h.xp = h.xp_proximo - 0.1
	w.combate.progresso.ganhar_xp(0.2)
	ate(func(): return w.combate.jogo == "escolha", 120)


func indice_troca() -> int:
	var cartas: Array = w.combate.progresso.cartas
	for i in cartas.size():
		if str(cartas[i].get("tipo", "")) == "troca":
			return i
	return -1


func novo_robo() -> Object:
	var r = Roteiro.new()
	r.mundo = w
	r.pt = {"cartas": [], "trocas": 0}
	return r


func _ready() -> void:
	_run()


func _run() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	_testes()
	print("v2_roteiro_robo falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _testes() -> void:
	var c = w.combate

	# a) a decisão pura
	var mao := [{"id": "a", "tipo": "up", "rar": 0}, {"id": "t", "tipo": "troca", "rar": 3}, {"id": "b", "tipo": "up", "rar": 1}]
	var d: Dictionary = Roteiro.decidir_carta_robo(mao, ["x", "y", "z"])
	ok(d.i == 2 and d.saida == "", "com troca e upgrades, pega o upgrade mais raro e não larga nada (%s)" % str(d))
	mao = [{"id": "a", "tipo": "up", "rar": 1}, {"id": "b", "tipo": "up", "rar": 1}, {"id": "t", "tipo": "troca", "rar": 3}]
	d = Roteiro.decidir_carta_robo(mao, ["x"])
	ok(d.i == 0, "empate de raridade: a primeira (%s)" % str(d))
	mao = [{"id": "t1", "tipo": "troca", "rar": 1}, {"id": "t2", "tipo": "troca", "rar": 2}, {"id": "t3", "tipo": "troca", "rar": 2}]
	d = Roteiro.decidir_carta_robo(mao, ["x", "y", "z"])
	ok(d.i == 1 and d.saida == "z", "só troca: a mais rara (a primeira no empate) e larga o bônus mais recente (%s)" % str(d))
	d = Roteiro.decidir_carta_robo([], ["x"])
	ok(d.i == -1 and d.saida == "", "mão vazia: -1")
	d = Roteiro.decidir_carta_robo([{"id": "t", "tipo": "troca", "rar": 0}], [])
	ok(d.i == 0 and d.saida == "", "só troca e nada para largar: não inventa saída")

	# b) partida de verdade: a TROCA é a carta mais rara e uma chamada do robô tem de concluir a escolha
	zerar()
	encher()
	ok(cs.cheio() and cs.bonus_contados() == 12, "Difícil cheio (%d bônus)" % cs.bonus_contados())
	subir_nivel()
	ok(c.jogo == "escolha", "a escolha de cartas abriu")
	var i := indice_troca()
	ok(i >= 0, "a mão tem a carta TROCA")
	if i >= 0:
		for k in c.progresso.cartas.size():
			c.progresso.cartas[k].rar = 3 if k == i else 0
		var novo := str(c.progresso.cartas[i].id)
		var robo = novo_robo()
		robo._pt_escolher_carta()
		ok(c.jogo != "escolha", "UMA chamada do robô fecha a escolha mesmo com a TROCA como carta mais rara (jogo=%s)" % c.jogo)
		ok(not cs.bonus_trocaveis().has(novo), "o robô prefere o upgrade: o bônus da TROCA não entrou")
		ok(cs.bonus_contados() == 12, "o total segue em 12 (%d)" % cs.bonus_contados())
		ok(robo.pt.trocas == 0 and robo.pt.cartas.size() == 1 and robo.pt.cartas[0] != novo, "o robô levou outra carta e não contou troca (%s)" % str(robo.pt))

	# c) mão só de TROCA (a cura garantida do Difícil é outra regra; aqui forçamos o pior caso)
	zerar()
	encher()
	subir_nivel()
	for k in c.progresso.cartas.size():
		if str(c.progresso.cartas[k].get("tipo", "")) != "troca":
			c.progresso.cartas[k] = c.progresso.cartas[indice_troca()].duplicate()
	var recente := str(cs.bonus_trocaveis().back())
	var novo2 := str(c.progresso.cartas[0].id)
	var robo2 = novo_robo()
	robo2._pt_escolher_carta()
	ok(not cs.bonus_trocaveis().has(recente), "mão só de TROCA: o bônus mais recente foi largado")
	ok(cs.bonus_trocaveis().has(novo2), "mão só de TROCA: o bônus novo entrou")
	ok(robo2.pt.trocas == 1 and robo2.pt.cartas.size() == 1, "mão só de TROCA: o robô contou a troca (%s)" % str(robo2.pt))
	ok(c.jogo != "escolha", "mão só de TROCA: uma chamada fecha a escolha (jogo=%s)" % c.jogo)
	ok(cs.bonus_contados() == 12, "mão só de TROCA: o total segue em 12 (%d)" % cs.bonus_contados())

	# d) 30 níveis seguidos: o robô nunca deixa a escolha aberta (com o código antigo a TROCA mais rara travava)
	zerar()
	encher()
	var abertas := 0
	var robo3 = novo_robo()
	for n in 30:
		subir_nivel()
		if c.jogo != "escolha":
			continue
		robo3._pt_escolher_carta()
		if c.jogo == "escolha":
			abertas += 1
			c.progresso.descartar_rodada()
	ok(abertas == 0, "30 níveis: a escolha ficou aberta %d vezes depois do robô" % abertas)
