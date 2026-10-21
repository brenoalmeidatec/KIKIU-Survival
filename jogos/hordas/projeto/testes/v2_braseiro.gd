extends "res://testes/isolamento_v2.gd"
# Teste automático do Braseiro Antigo (v2/braseiros.gd): o braseiro do mapa começa apagado; o herói perto por 3 s SEGUIDOS acende (aviso no HUD
# pelo sinal anuncio); aceso, deixa os monstros dentro do raio lentos; depois de 20 s apaga e só acende de novo após a recarga. Também confere
# a Area2D de verdade (o herói andando até o braseiro dispara o sinal) e que nada novo roda por quadro quando está tudo apagado.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_braseiro.tscn  (imprime "v2_braseiro falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Braseiros := preload("res://v2/braseiros.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var avisos: Array = []


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func segundos(s: float) -> void:
	passos(int(round(s / PASSO)))


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.imortal = true
	w.anuncio.connect(func(texto, _cor): avisos.append(texto))
	var bs = w.braseiros
	var cfg: Dictionary = bs.cfg

	# 1. o braseiro do mapa existe e começa apagado
	ok(bs.lista.size() == 1, "o mapa tem 1 braseiro antigo (deu %d)" % bs.lista.size())
	var b = bs.lista[0]
	ok(b.estado == Braseiros.APAGADO, "começa apagado")
	ok(b.luz.energia < b.energia_base * 0.5, "apagado: a luz fica fraca (%.2f de %.2f)" % [b.luz.energia, b.energia_base])
	ok(b.luz.particulas.is_empty(), "apagado: sem fogo")
	ok(float(cfg.raio_acender) == 120.0 and float(cfg.tempo_acender) == 3.0, "números do json: 120 px e 3 s")
	ok(float(cfg.duracao) == 20.0 and float(cfg.recarga) == 60.0, "números do json: 20 s acesa e 60 s de recarga")

	# 2. longe do braseiro nada acontece
	w.heroi.imortal = true
	segundos(4.0)
	ok(b.estado == Braseiros.APAGADO and avisos.is_empty(), "herói longe: continua apagado e sem aviso")

	# 3. o herói chega e sai antes de 3 s: o tempo zera
	bs.heroi_chegou(b)
	segundos(2.0)
	ok(b.estado == Braseiros.CARREGANDO, "herói perto: carregando")
	bs.heroi_saiu(b)
	ok(b.estado == Braseiros.APAGADO and b.t == 0.0, "saiu antes de 3 s: voltou a zero")
	bs.heroi_chegou(b)
	segundos(2.0)
	ok(b.estado == Braseiros.CARREGANDO and avisos.is_empty(), "2 s de novo: ainda não acendeu")

	# 4. completa 3 s seguidos: acende, avisa uma vez e a luz volta
	segundos(1.1)
	ok(b.estado == Braseiros.ACESO, "3 s seguidos: acendeu")
	ok(avisos.size() == 1 and avisos[0] == "BRASEIRO ANTIGO ACESO!", "avisou no HUD uma vez (%s)" % str(avisos))
	ok(b.luz.energia == b.energia_base, "aceso: a luz volta ao normal")
	ok(not b.luz.particulas.is_empty(), "aceso: o fogo volta")

	# 5. aceso: monstro dentro do raio fica lento, fora do raio não
	var dentro = w.monstros[0]
	var fora = w.monstros[1]
	dentro.pos = b.pos + Vector2(60, 0)
	fora.pos = b.pos + Vector2(float(cfg.raio_seguro) + 80.0, 0)
	dentro.lento_t = 0.0
	fora.lento_t = 0.0
	segundos(0.5)
	ok(dentro.lento_t > 0.0, "monstro dentro do raio ficou lento")
	ok(fora.lento_t <= 0.0, "monstro fora do raio não ficou lento")

	# 6. depois de 20 s apaga e entra em recarga; mesmo com o herói ali, não acende de novo
	segundos(20.0)
	ok(b.estado == Braseiros.RECARGA, "20 s depois: apagou e recarrega")
	ok(b.luz.energia < b.energia_base * 0.5 and b.luz.particulas.is_empty(), "apagou: luz fraca e sem fogo")
	dentro.lento_t = 0.0
	dentro.pos = b.pos + Vector2(60, 0)
	segundos(1.0)
	ok(dentro.lento_t <= 0.0, "apagado: ninguém fica lento")
	segundos(30.0)
	ok(b.estado == Braseiros.RECARGA and bs.acendeu == 1, "30 s depois ainda recarrega, sem acender")
	segundos(31.0)
	ok(b.estado == Braseiros.CARREGANDO, "passou a recarga com o herói ali: já carrega de novo")
	bs.heroi_saiu(b)
	ok(b.estado == Braseiros.APAGADO, "herói saiu: apagado, pronto para outra vez")

	# 7. a Area2D de verdade: o herói anda até o braseiro e o sinal dispara sozinho
	var w2 = Mundo.instantiate()
	w2.modo_teste = true
	add_child(w2)
	w2.set_process(false)
	w2.heroi.imortal = true
	var b2 = w2.braseiros.lista[0]
	w2.heroi.pos = b2.pos + Vector2(300, 0)
	w2.heroi.raiz.position = w2.heroi.pos
	w2.heroi.entrada_forcada = Vector2.ZERO
	for i in 6:
		await get_tree().physics_frame
		w2.avancar(PASSO)
	ok(not b2.heroi_perto, "longe (300 px): a Area2D não detectou o herói")
	w2.heroi.pos = b2.pos + Vector2(40, 0)
	w2.heroi.raiz.position = w2.heroi.pos
	for i in 6:
		await get_tree().physics_frame
		w2.avancar(PASSO)
	ok(b2.heroi_perto and b2.estado == Braseiros.CARREGANDO, "a 40 px: a Area2D detectou o herói e o braseiro carrega")
	w2.heroi.pos = b2.pos + Vector2(300, 0)
	w2.heroi.raiz.position = w2.heroi.pos
	for i in 6:
		await get_tree().physics_frame
		w2.avancar(PASSO)
	ok(not b2.heroi_perto and b2.estado == Braseiros.APAGADO, "saiu: a Area2D avisou e o tempo zerou")

	print("v2_braseiro falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
