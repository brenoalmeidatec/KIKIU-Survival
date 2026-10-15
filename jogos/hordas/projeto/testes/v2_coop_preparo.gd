extends Node
# Teste da etapa 0 do coop (docs/ONLINE_V2_PLANO.md): `mundo.herois` (lista; o solo tem 1), `alvo_mais_perto` para os monstros, e o tempo
# separado em "do mundo" e "do herói local" (hit-stop, câmera lenta e pausa). No solo nada muda: dt_mundo == dt_local. Com 2 heróis na
# lista o monstro persegue o mais perto; o herói caído não é alvo; com `tempo_local_separado` o hit-stop só trava o herói local.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_coop_preparo.tscn  (imprime "v2_coop_preparo falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


## Um herói remoto de mentira: só o que o mundo lê (posição, raio, vida).
class Falso:
	var pos := Vector2.ZERO
	var raio := 6.0
	var vida := 10.0


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
	passos(3)


func teste_lista() -> void:
	zerar()
	ok(w.herois.size() == 1 and w.herois[0] == w.heroi, "solo: herois tem só o herói local")
	ok(w.alvo_mais_perto(Vector2(5000, 5000)) == w.heroi, "solo: o alvo é o herói local")
	ok(w.coop_modo == "", "sem --coop: coop_modo vazio (%s)" % w.coop_modo)


func teste_alvo() -> void:
	zerar()
	var h: Vector2 = w.heroi.pos
	var f := Falso.new()
	f.pos = h + Vector2(600, 0)
	w.herois.append(f)
	ok(w.alvo_mais_perto(h + Vector2(500, 0)) == f, "perto do remoto: o alvo é o remoto")
	ok(w.alvo_mais_perto(h + Vector2(100, 0)) == w.heroi, "perto do local: o alvo é o local")
	f.vida = 0.0
	ok(w.alvo_mais_perto(h + Vector2(500, 0)) == w.heroi, "remoto caído não é alvo enquanto o local vive")
	f.vida = 10.0
	# o monstro persegue o mais perto: nasce a 500 px do local e a 100 do remoto
	var m = w.nascer_monstro("inimigo_cao_ossos", h + Vector2(500, 0), true)
	var d0: float = m.pos.distance_to(f.pos)
	passos(60)
	var d1: float = m.pos.distance_to(f.pos)
	ok(d1 < d0 - 20.0, "o monstro foi para o remoto (%.0f -> %.0f px)" % [d0, d1])
	ok(m.pos.distance_to(h) > 400.0, "e não para o herói local (%.0f px dele)" % m.pos.distance_to(h))
	# o remoto cai: o mesmo monstro passa a caçar o local
	f.vida = 0.0
	var e0: float = m.pos.distance_to(h)
	passos(60)
	ok(m.pos.distance_to(h) < e0 - 20.0, "com o remoto caído o monstro vai para o local (%.0f -> %.0f)" % [e0, m.pos.distance_to(h)])
	w.herois = [w.heroi]


func teste_tempo() -> void:
	zerar()
	var c = w.combate
	# solo: o hit-stop trava o mundo e o herói juntos
	c.hit_stop(0.1)
	var dm: float = c.passo_tempo(PASSO)
	ok(dm == 0.0 and c.dt_mundo == 0.0 and c.dt_local == 0.0, "solo: hit-stop trava mundo e herói (%.3f, %.3f)" % [c.dt_mundo, c.dt_local])
	c.parada_t = 0.0
	ok(is_equal_approx(c.passo_tempo(PASSO), PASSO) and c.dt_local == c.dt_mundo, "solo: sem efeito, os dois andam o passo inteiro")
	c.camera_lenta("nivel", 0.5, 0.25)
	c.passo_tempo(PASSO)
	ok(is_equal_approx(c.dt_mundo, PASSO * 0.25) and c.dt_local == c.dt_mundo, "solo: câmera lenta desacelera os dois (%.4f)" % c.dt_mundo)
	c.lento_t = 0.0
	c.lento_acao = ""
	c.lento_escala = 1.0
	# separado (coop, tela dividida): o hit-stop só trava o local
	c.tempo_local_separado = true
	c.hit_stop(0.1)
	c.passo_tempo(PASSO)
	ok(c.dt_mundo == PASSO and c.dt_local == 0.0, "separado: hit-stop trava só o herói local (%.3f, %.3f)" % [c.dt_mundo, c.dt_local])
	c.parada_t = 0.0
	c.camera_lenta("nivel", 0.5, 0.25)
	c.passo_tempo(PASSO)
	ok(c.dt_mundo == PASSO and is_equal_approx(c.dt_local, PASSO * 0.25), "separado: câmera lenta só no local (%.4f)" % c.dt_local)
	c.lento_t = 0.0
	c.lento_acao = ""
	c.lento_escala = 1.0
	c.pausado = true
	c.passo_tempo(PASSO)
	ok(c.dt_mundo == PASSO and c.dt_local == 0.0, "separado: a escolha de carta pausa só o local")
	c.pausado = false
	c.pausado_mundo = true
	c.passo_tempo(PASSO)
	ok(c.dt_mundo == 0.0 and c.dt_local == 0.0, "separado: a pausa do mundo (resultado) para todos")
	c.pausado_mundo = false
	c.tempo_local_separado = false


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	teste_lista()
	teste_alvo()
	teste_tempo()
	print("v2_coop_preparo falhas=%d" % falhas)
	get_tree().quit()
