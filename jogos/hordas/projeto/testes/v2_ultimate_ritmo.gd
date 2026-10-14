extends Node
# MEDIÇÃO (não é do conjunto de testes): em quantos segundos de luta normal o 1º ultimate fica pronto. Roda o diretor de verdade (ondas, elites) e um
# bot que golpeia o monstro mais perto e escolhe a 1ª carta ao subir de nível (o mesmo do --robo do v2/roteiro.gd), em dois estilos: PARADO (o herói
# fica no lugar, como o robô) e CAÇADOR (anda até o monstro mais perto, mais perto de um jogador de verdade). O herói é imortal para a medição durar.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_ultimate_ritmo.tscn  (imprime a carga a cada 15 s e o instante do pronto)
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
var w


func bot(cacador: bool) -> void:
	var h = w.heroi
	var c = w.combate
	if c.jogo == "escolha":
		c.progresso.escolher(0)
		return
	var alvo = null
	var melhor := 1e12
	for m in w.monstros:
		var dd: float = m.pos.distance_squared_to(h.pos)
		if dd < melhor:
			melhor = dd
			alvo = m
	if alvo != null:
		w.mouse_forcado = alvo.pos + Vector2(0, -6)
		h.fonte = Heroi.Fonte.MOUSE
	h.entrada_forcada = Vector2.ZERO
	if cacador and alvo != null and melhor > 50.0 * 50.0:
		h.entrada_forcada = (alvo.pos - h.pos).normalized()
	h.ataque_forcado = alvo != null and melhor < 70.0 * 70.0


func rodar(nome: String, cacador: bool, limite_s: float) -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = true
	w.heroi.imortal = true
	var u = w.combate.ultimate
	var t_pronto := -1.0
	var proximo := 15.0
	var cr: float = 0.0
	while cr < limite_s and t_pronto < 0.0:
		bot(cacador)
		w.avancar(PASSO)
		cr += PASSO
		if u.pronto():
			t_pronto = w.tempo_partida
		if w.tempo_partida >= proximo:
			print("  [%s] t=%.0fs carga=%.1f abates=%d nivel=%d" % [nome, w.tempo_partida, u.carga, w.abates, w.heroi.nivel])
			proximo += 15.0
	print("RITMO %s: 1º ultimate pronto em %.1f s de partida (carga %.1f, abates %d, nível %d)" % [nome, t_pronto, u.carga, w.abates, w.heroi.nivel])


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	rodar("parado", false, 400.0)
	rodar("cacador", true, 400.0)
	get_tree().quit()
