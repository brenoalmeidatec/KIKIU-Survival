extends "res://testes/isolamento_v2.gd"
# Teste da carga do Q por TAMANHO do alvo (05/11, pedido do Alisson: "quanto menor o alvo e acertar, o ult sobe mais rápido; quanto maior o alvo e fácil de
# acertar, mais lento"). Regra em dados/v2_especial.json > comum.tamanho (raio_ref, expoente, min, max), ligada pelo `carga_tamanho` do bloco do Q (hoje
# autodestruicao e chamar: o LightWolf de mecha e de Lobo); código em v2/especial.gd `fator_tamanho` e `dano`. Confere, pelo caminho real (combate.ferir):
# o mesmo dano num alvo pequeno enche MAIS a carga do mecha que num alvo médio, e num grande (elite, chefe) enche MENOS, com o fator preso entre min e max;
# o mesmo vale para o chamado do Lobo; o Hazaki (sem a regra) ganha a mesma carga em qualquer tamanho; abate e recebido não mudam.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_ult_tamanho.tscn  (imprime "v2_ult_tamanho falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const PASSO := 1.0 / 60.0
const PEQUENO := "inimigo_homunculo"  # raio 6
const MEDIO := "inimigo_cao_ossos"  # raio 7 = raio_ref
const GRANDE := "inimigo_cavaleiro_oco"  # raio 9
const DANO := 20.0

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func novo(id: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	for i in 3:
		w.avancar(PASSO)


## Um monstro do `tipo` parado, longe do herói, com muita vida, na escala `esc` (elite 1,5; chefe 3,2 e 4,4).
func alvo(tipo: String, esc := 1.0):
	var m = w.nascer_monstro(tipo, w.heroi.pos + Vector2(300, 0))
	if esc != 1.0:
		m.definir_escala(esc)
	m.vida = 100000.0
	m.vida_max = 100000.0
	m.atordoa_t = 60.0
	return m


## A carga que DANO pontos de dano em `m` dão ao herói de agora (combate.ferir, o caminho de toda fonte secundária).
func ganho(m) -> float:
	var h = w.heroi
	h.esp_carga = 10.0
	w.combate.ferir(m, DANO, Vector2.RIGHT, 0.0, 0.0, Color.WHITE, false)
	return h.esp_carga - 10.0


func _ready() -> void:
	_t_dados()
	await _t_mecha()
	await _t_lobo()
	await _t_hazaki()
	Herois.forcado = ""
	print("v2_ult_tamanho falhas=%d" % falhas)
	get_tree().quit()


func _t_dados() -> void:
	var d: Dictionary = Dados.json("v2_especial")
	var t: Dictionary = d.comum.get("tamanho", {})
	ok(not t.is_empty(), "comum.tamanho existe")
	if t.is_empty():
		return
	ok(float(t.min) < 1.0 and float(t.max) > 1.0 and float(t.min) >= 0.5 and float(t.max) <= 2.0, "limites contidos: min %s < 1 < max %s" % [t.min, t.max])
	ok(bool(d.autodestruicao.get("carga_tamanho", false)) and bool(d.chamar.get("carga_tamanho", false)), "ligado no mecha e no Lobo")
	for id in ["investida", "terremoto", "chuva"]:
		ok(not bool(d[id].get("carga_tamanho", false)), "%s segue sem a regra (decisão do Alisson)" % id)
	ok(str(d._ajuda).contains("carga_tamanho"), "_ajuda explica carga_tamanho")


## O mecha: pequeno > médio > grande > elite >= chefe, e o chefe no piso `min`.
func _t_mecha() -> void:
	await novo("lightwolf")
	var t: Dictionary = Dados.json("v2_especial").comum.get("tamanho", {"min": 0.6, "max": 1.5})
	var g_med := ganho(alvo(MEDIO))
	var g_peq := ganho(alvo(PEQUENO))
	var g_gra := ganho(alvo(GRANDE))
	var g_eli := ganho(alvo(GRANDE, 1.5))
	var g_che := ganho(alvo(GRANDE, 4.4))
	print("mecha: pequeno %.3f medio %.3f grande %.3f elite %.3f chefe %.3f" % [g_peq, g_med, g_gra, g_eli, g_che])
	ok(g_med > 0.0, "o alvo médio dá carga (%.3f)" % g_med)
	ok(is_equal_approx(g_med, DANO * float(Dados.json("v2_especial").comum.carga.dano)), "médio (raio_ref) = fator 1 (%.3f)" % g_med)
	ok(g_peq > g_med * 1.1, "pequeno enche mais rápido (%.3f > %.3f)" % [g_peq, g_med])
	ok(g_gra < g_med * 0.9, "grande enche mais devagar (%.3f < %.3f)" % [g_gra, g_med])
	ok(g_eli < g_gra, "elite (x1,5) enche menos que o comum grande (%.3f < %.3f)" % [g_eli, g_gra])
	ok(is_equal_approx(g_che, g_med * float(t.min)), "chefe preso no piso min (%.3f = %.3f x %s)" % [g_che, g_med, t.min])
	var tiny = alvo(PEQUENO, 0.25)  # raio 1,5: bem abaixo do teto
	ok(is_equal_approx(ganho(tiny), g_med * float(t.max)), "alvo minúsculo preso no teto max")
	# abate não muda com o tamanho (o abate já separa comum, elite e chefe)
	var h = w.heroi
	h.esp_carga = 10.0
	w.combate.especial.abate(alvo(PEQUENO))
	var a_peq: float = h.esp_carga - 10.0
	h.esp_carga = 10.0
	w.combate.especial.abate(alvo(GRANDE))
	ok(is_equal_approx(a_peq, h.esp_carga - 10.0), "abate igual em qualquer tamanho")


## O Lobo (o chamado tem carga própria) também segue o tamanho.
func _t_lobo() -> void:
	await novo("lightwolf")
	w.combate.mecha.virar_lobo(w.heroi, 10.0, true)
	ok(w.heroi.forma_lobo, "virou Lobo")
	var g_med := ganho(alvo(MEDIO))
	var g_peq := ganho(alvo(PEQUENO))
	var g_gra := ganho(alvo(GRANDE, 1.5))
	print("lobo: pequeno %.3f medio %.3f elite %.3f" % [g_peq, g_med, g_gra])
	ok(g_peq > g_med and g_med > g_gra and g_gra > 0.0, "Lobo: pequeno > médio > elite (%.3f, %.3f, %.3f)" % [g_peq, g_med, g_gra])


## O Hazaki não tem a regra: o mesmo dano vale a mesma carga em qualquer tamanho.
func _t_hazaki() -> void:
	await novo("hazaki")
	var g_peq := ganho(alvo(PEQUENO))
	var g_che := ganho(alvo(GRANDE, 4.4))
	ok(g_peq > 0.0 and is_equal_approx(g_peq, g_che), "Hazaki igual em qualquer tamanho (%.3f, %.3f)" % [g_peq, g_che])
