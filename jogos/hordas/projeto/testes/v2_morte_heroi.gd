extends Node
# Teste do visual da morte do herói (#253): o corpo ganha o shader de dissolução ao morrer, o progresso anda no relógio de jogo (parado no
# hit-stop da morte e na pausa, sem TIME no shader), termina em 1 e o recomeço limpa tudo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_morte_heroi.tscn  (imprime "v2_morte_heroi falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.entrada_forcada = Vector2.ZERO
	passos(3)
	ok(h.sprite.material == null and h.morte_k() == 0.0, "vivo: sem material de dissolução")
	ok(not Heroi.SHADER_MORTE.contains("TIME"), "o shader da morte não usa TIME")

	h.imortal = false
	h.invenc = 0.0
	h.levar_dano(h.vida + 100.0, h.pos + Vector2(10, 0))
	ok(h.estado == Heroi.Estado.MORTO, "morreu")
	ok(h.sprite.material != null, "a morte põe o material de dissolução")
	ok(w.combate.parada_t > 0.0, "a morte dispara hit-stop")
	passos(3)  # hit-stop: o relógio do herói está parado, a dissolução não anda
	ok(h.morte_t == 0.0 and h.morte_k() == 0.0, "hit-stop congela a dissolução (morte_t=%f)" % h.morte_t)
	var mat := h.sprite.material as ShaderMaterial
	ok(float(mat.get_shader_parameter("branco")) == 1.0, "começa no flash branco")
	var n := 0
	while w.combate.parada_t > 0.0 and n < 100:
		passos(1)
		n += 1
	passos(10)
	ok(h.morte_t > 0.0 and h.morte_k() > 0.0, "depois do hit-stop a dissolução anda (k=%f)" % h.morte_k())
	var k1: float = h.morte_k()
	passos(20)
	ok(h.morte_k() > k1, "continua andando")
	var m_ant: float = h.morte_t
	w.combate.pausado = true
	passos(10)
	ok(h.morte_t == m_ant, "pausa congela a dissolução")
	w.combate.pausado = false
	passos(600)
	ok(h.morte_k() == 1.0 and float(mat.get_shader_parameter("dissolver")) >= 0.99, "termina em 1 (k=%f)" % h.morte_k())
	ok(float(mat.get_shader_parameter("branco")) == 0.0, "flash branco acabou")

	h.resetar(h.pos)
	ok(h.sprite.material == null and h.morte_t == 0.0, "recomeço limpa o material e o relógio")
	print("v2_morte_heroi falhas=%d" % falhas)
	get_tree().quit()
