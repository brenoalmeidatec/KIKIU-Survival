extends "res://testes/isolamento_v2.gd"
# Teste do ritmo da partida a 1,25x (dados/v2_ritmo.json -> velocidade_partida, aplicado em combate.passo_tempo).
# Confere: o dado vale 1,25; numa partida de verdade (modo_teste desligado) o combate carrega 1,25 e nos testes fica em 1;
# com o fator, o mundo e o herói andam 1,25x por quadro real; a câmera lenta multiplica (não é sobrescrita); o hit-stop e a câmera lenta
# contam em tempo real (o relógio deles não acelera); a escolha de cartas, o baú, a pausa e o resultado zeram o dt (a UI não acelera);
# um monstro percorre 25% mais chão no mesmo tempo real; Engine.time_scale nunca sai de 1,0 (áudio e tweens de UI ficam como estão);
# ao sair da pausa o ritmo volta a 1,25 sem resíduo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_velocidade.tscn  (imprime "v2_velocidade falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
const FATOR := 1.25

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.herois = [w.heroi]
	w.combate.tempo_local_separado = false
	w.combate.velocidade = 1.0
	passos(3)


func teste_dado() -> void:
	var r: Dictionary = Dados.json("v2_ritmo")
	ok(
		is_equal_approx(float(r.get("velocidade_partida", 0.0)), FATOR),
		"dados/v2_ritmo.json: velocidade_partida vale 1,25 (%s)" % str(r.get("velocidade_partida"))
	)
	ok(w.combate.velocidade == 1.0, "nos testes (modo_teste) o combate fica em 1,0 (%.3f)" % w.combate.velocidade)


func teste_partida_real() -> void:
	# a partida de verdade: modo_teste desligado, como o jogo abre
	var real = Mundo.instantiate()
	add_child(real)
	real.set_process(false)
	real.combate.audio.mudo = true
	ok(is_equal_approx(real.combate.velocidade, FATOR), "partida de verdade: o combate carrega 1,25 (%.3f)" % real.combate.velocidade)
	real.combate.passo_tempo(PASSO)
	ok(is_equal_approx(real.combate.dt_mundo, PASSO * FATOR), "partida de verdade: dt do mundo = passo x 1,25 (%.5f)" % real.combate.dt_mundo)
	real.queue_free()
	await get_tree().process_frame


func teste_relogio() -> void:
	zerar()
	var c = w.combate
	c.velocidade = FATOR
	ok(
		is_equal_approx(c.passo_tempo(PASSO), PASSO * FATOR) and is_equal_approx(c.dt_local, PASSO * FATOR),
		"andando: mundo e herói a 1,25x (%.5f, %.5f)" % [c.dt_mundo, c.dt_local]
	)
	# o tempo de partida do mundo corre 1,25x o relógio real
	var t0: float = w.tempo_partida
	passos(60)
	ok(absf((w.tempo_partida - t0) - FATOR) < 0.01, "60 quadros reais = 1,25 s de partida (%.3f)" % (w.tempo_partida - t0))
	# câmera lenta multiplica o fator, não o sobrescreve
	c.camera_lenta("nivel", 0.5, 0.25)
	c.passo_tempo(PASSO)
	ok(is_equal_approx(c.dt_mundo, PASSO * 0.25 * FATOR), "câmera lenta x fator (%.5f)" % c.dt_mundo)
	c.lento_t = 0.0
	c.lento_acao = ""
	c.lento_escala = 1.0
	# hit-stop trava o mundo e o relógio dele corre em tempo real (não em 1,25x)
	c.hit_stop(0.1)
	var antes: float = c.parada_t
	ok(c.passo_tempo(PASSO) == 0.0, "hit-stop: o mundo para")
	ok(is_equal_approx(antes - c.parada_t, PASSO), "hit-stop: o relógio dele é o real (%.5f)" % (antes - c.parada_t))
	c.parada_t = 0.0
	# coop/tela dividida: o fator vale para o mundo e o local; o hit-stop só trava o local
	c.tempo_local_separado = true
	c.hit_stop(0.1)
	c.passo_tempo(PASSO)
	ok(is_equal_approx(c.dt_mundo, PASSO * FATOR) and c.dt_local == 0.0, "separado: mundo a 1,25x e local parado (%.5f, %.5f)" % [c.dt_mundo, c.dt_local])
	c.parada_t = 0.0
	c.tempo_local_separado = false
	c.velocidade = 1.0


func teste_ui_nao_acelera() -> void:
	zerar()
	var c = w.combate
	c.velocidade = FATOR
	for estado in ["pausado", "pausado_mundo"]:
		c.set(estado, true)
		ok(c.passo_tempo(PASSO) == 0.0 and c.dt_local == 0.0, "%s: dt zero, nada acelera" % estado)
		c.set(estado, false)
	var t0: float = w.tempo_partida
	c.pausado = true  # a escolha de cartas / o baú
	passos(120)
	ok(w.tempo_partida == t0, "escolha de cartas: o relógio da partida não anda (%.3f)" % (w.tempo_partida - t0))
	c.pausado = false
	ok(is_equal_approx(c.passo_tempo(PASSO), PASSO * FATOR), "ao sair da escolha volta a 1,25x sem resíduo (%.5f)" % c.dt_mundo)
	ok(Engine.time_scale == 1.0, "Engine.time_scale continua 1,0 (%.3f)" % Engine.time_scale)
	ok(AudioServer.playback_speed_scale == 1.0, "o áudio não muda de velocidade (%.3f)" % AudioServer.playback_speed_scale)
	c.velocidade = 1.0


func _distancia_monstro(fator: float) -> float:
	zerar()
	w.combate.velocidade = fator
	var h: Vector2 = w.heroi.pos
	var m = w.nascer_monstro("inimigo_cao_ossos", h + Vector2(500, 0), true)
	var d0: float = m.pos.distance_to(h)
	passos(60)
	var d1: float = m.pos.distance_to(h)
	w.combate.velocidade = 1.0
	return d0 - d1


func teste_monstro() -> void:
	var lento := _distancia_monstro(1.0)
	var rapido := _distancia_monstro(FATOR)
	ok(lento > 20.0, "base: o monstro se aproxima (%.1f px)" % lento)
	ok(absf(rapido / maxf(lento, 0.001) - FATOR) < 0.05, "a 1,25x o monstro anda 25%% mais no mesmo tempo real (%.1f vs %.1f px)" % [rapido, lento])


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	teste_dado()
	await teste_partida_real()
	teste_relogio()
	teste_ui_nao_acelera()
	teste_monstro()
	print("v2_velocidade falhas=%d" % falhas)
	get_tree().quit()
