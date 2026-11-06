extends "res://testes/isolamento_v2.gd"
# Teste da QUEIMA da teia pelo mecha em voo (v2/teias.gd voando e _queimar, v2/impulso.gd, v2/mecha.gd; dados/v2_teia.json > queima). "Mecha flutuando" é o voo do impulso (Shift) do
# mecha do LightWolf, com os propulsores nas costas (v2/propulsor.gd). Confere: voando sobre a teia (a elipse mais a margem), a teia pega fogo no canto do lado do herói (bits 1 = H e 2 = V);
# sem voar (parado, andando, esquivando) nada queima; o Lobo (sem impulso) não voa e não queima; a teia em chamas não segura mais (queimando_lento false) e libera o slot ao fim da animação;
# o voo da quebra, do reiniciar e do Lobo desligam o estado.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_teia_queima.tscn  (imprime "v2_teia_queima falhas=0")

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0

var falhas := 0
var w
var h
var t


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
	Colisao.limpar()
	h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.correr_forcado = false
	h.fonte = Heroi.Fonte.MOUSE
	h.pos = w.limite_andavel.get_center()
	h.definir_pos(h.pos)
	w.mouse_forcado = h.centro() + Vector2(4000, 0)
	passos(3)


func poe_teia(p: Vector2) -> int:
	var i: int = t._livre()
	t._est[i] = t.PARADA
	t._t[i] = 0.0
	t._idade[i] = 0.0
	t._pos[i] = p
	t._geo[i] = 0
	t._var[i] = 0
	return i


func decolar() -> void:
	h.correr_forcado = true
	passos(1)
	h.correr_forcado = false


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	t = w.combate.teias
	var imp = w.combate.impulso
	ok(imp != null and imp.para(h), "o mecha tem o impulso (é o que voa)")

	# 1. parado ou andando: nada queima, e a teia segura
	var i := poe_teia(h.pos)
	passos(10)
	ok(t._est[i] == t.PARADA and t.queimadas == 0, "o mecha no chão sobre a teia não a queima")
	var q_zero: int = t.queimadas
	ok(not t.voando(h) and h.lento_fontes.has("teia"), "e ele fica preso nela")
	h.entrada_forcada = Vector2.RIGHT
	passos(5)
	h.entrada_forcada = Vector2.ZERO
	ok(t.queimadas == q_zero, "andando também não queima")

	# 2. voando sobre a teia: queima. O herói à direita e abaixo do centro: fogo nasce no canto espelhado H e V (bits 3)
	zerar()
	i = poe_teia(h.pos + Vector2(-10, -6))
	decolar()
	var q := 0
	while t._est[i] == t.PARADA and q < 90:
		passos(1)
		q += 1
	ok(t._est[i] == t.QUEIMANDO, "voando sobre a teia, ela pega fogo (%d quadros depois de decolar)" % q)
	ok(t.voando(h) and h.alt_px >= int(t.cfg.queima.alt_min_px), "o mecha estava voando, no alto (alt %d)" % h.alt_px)
	ok(t._var[i] == 3, "o mecha à direita e abaixo do centro: fogo no canto espelhado H e V (bits %d)" % t._var[i])
	ok(not h.lento_fontes.has("teia"), "voando, o mecha não fica lento")
	ok(t.queimadas == q_zero + 1, "uma teia queimada (%d)" % (t.queimadas - q_zero))

	# 3. o lado do herói escolhe o canto: ele voa para a direita e entra na teia pela esquerda, um pouco acima do centro (canto base) ou abaixo (bit V)
	zerar()
	var a := poe_teia(h.pos + Vector2(90, 8))
	decolar()
	passos(60)
	ok(t._est[a] == t.QUEIMANDO and t._var[a] == 0, "o mecha entra pela esquerda e acima do centro: fogo no canto base (bits %d)" % t._var[a])
	zerar()
	var a2 := poe_teia(h.pos + Vector2(90, -8))
	decolar()
	passos(60)
	ok(t._est[a2] == t.QUEIMANDO and t._var[a2] == 2, "entrando pela esquerda e abaixo do centro: espelha só em V (bits %d)" % t._var[a2])

	# 4. a teia em chamas não segura e a animação libera o slot
	zerar()
	var b := poe_teia(h.pos + Vector2(-70, 0))
	t._est[b] = t.QUEIMANDO
	t._t[b] = 0.0
	h.pos = t._pos[b]
	h.definir_pos(h.pos)
	passos(3)
	ok(not h.lento_fontes.has("teia"), "a teia em chamas não deixa o herói lento (queimando_lento false)")
	var dur: float = float(t._folhas.queima.quadros) / float(t._folhas.queima.fps)
	passos(int(dur * 60.0) + 3)
	ok(t._est[b] == t.LIVRE, "a queima acaba em %.2f s e libera o slot" % dur)

	# 5. a margem: o propulsor passando rente à borda acende; longe da borda não
	zerar()
	w.mouse_forcado = h.centro() + Vector2(-4000, 0)  # voa para longe da teia (3 quadros para a mira virar antes do aperto)
	passos(3)
	var c := poe_teia(h.pos + Vector2(t.raio + 20.0, 0))  # o herói a 20 px da borda (fora da elipse e da margem de 4)
	decolar()
	passos(10)
	ok(t._est[c] == t.PARADA, "o voo a 20 px da borda não queima")
	t._pos[c] = h.pos + Vector2(t.raio + 2.0, 0)
	t._heroi()  # a conta de um quadro, sem andar (o mecha segue voando)
	ok(t._est[c] == t.QUEIMANDO, "a 2 px da borda (dentro da margem de %d px) queima" % int(t.cfg.queima.margem))

	# 6. o Lobo não voa nem queima; o mecha que quebra para de voar
	zerar()
	w.combate.mecha.virar_lobo(h, 20.0)
	passos(3)
	ok(h.forma_lobo and not imp.para(h), "o Lobo não tem impulso")
	var d := poe_teia(h.pos)
	var q_ant: int = t.queimadas
	h.correr_forcado = true
	passos(30)
	h.correr_forcado = false
	ok(not t.voando(h) and t._est[d] != t.QUEIMANDO and t.queimadas == q_ant, "o Lobo não queima a teia (correr é só correr)")
	ok(h.lento_fontes.has("teia") or h.lento_k() == 1.0, "e o Lobo é lento na teia como os outros")
	zerar()
	ok(not h.forma_lobo, "reiniciar volta ao mecha")

	# 7. nada voa sem o impulso: Hazaki
	Herois.forcado = "hazaki"
	w.queue_free()
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	t = w.combate.teias
	var e := poe_teia(h.pos)
	h.correr_forcado = true
	passos(30)
	ok(not t.voando(h) and t._est[e] != t.QUEIMANDO, "outro herói correndo sobre a teia não queima (o Shift dele é correr)")
	print("v2_teia_queima falhas=%d" % falhas)
	get_tree().quit()
