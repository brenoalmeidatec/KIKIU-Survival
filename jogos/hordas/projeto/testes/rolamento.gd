extends Node
# Teste automático: rolamento de esquiva com fôlego (#68, no lugar do dash). Duas cargas, invencível rolando, o corpo
# dá uma volta, vai mais longe que o dash antigo, tem um instante de recuperação e o fôlego volta com o tempo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/rolamento.tscn  (imprime "ROLAMENTO falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Jogador := preload("res://scripts/hordas/jogador.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	var mov: Dictionary = Dados.json("movimento")
	var r: Dictionary = mov.get("rolamento", {})
	var cargas := int(mov.get("folego", {}).get("cargas", 2))
	ok(cargas == 2, "duas cargas de fôlego (%d)" % cargas)
	ok(float(r.get("velocidade", 0)) * float(r.get("tempo", 0)) > Jogador.DASH_VEL * Jogador.DASH_TEMPO,
		"o rolamento vai mais longe que o dash antigo (%.2f contra %.2f)" % [float(r.get("velocidade", 0)) * float(r.get("tempo", 0)), Jogador.DASH_VEL * Jogador.DASH_TEMPO])
	var a := Arena.new()
	a.heroi_id = "hazaki"
	add_child(a)
	await esperar(1.6)   # a chegada (o herói cai do céu) termina antes
	a.bot = false
	var j = a.jogador
	j.bot = false
	ok(is_equal_approx(j.folego, 2.0), "começa com o fôlego cheio (%.2f)" % j.folego)
	var antes: Vector2 = j.position
	ok(j.rolar(Vector2.RIGHT), "rola com fôlego")
	ok(j.folego < 1.05, "o rolamento gastou uma carga (%.2f)" % j.folego)
	ok(j.invencivel >= float(r.get("invulneravel", 0.25)) - 0.01, "invencível no começo do rolamento (#126: 0,25 s de 0,45 s)")
	ok(not j.rolar(Vector2.RIGHT), "não começa outro no meio do rolamento")
	await esperar(0.12)
	ok(absf(j.spr.rotation) > 0.3, "o corpo gira rolando (%.2f rad)" % j.spr.rotation)
	await esperar(0.38)   # o rolamento (0,45 s) acabou há pouco
	ok(j._rolando <= 0.0 and is_zero_approx(j.spr.rotation), "acabou de rolar: o corpo volta ao normal")
	ok(j._recupera >= 0.0, "a recuperação segue o movimento.json (%.2f s)" % j._recupera)
	var andou: float = j.position.x - antes.x
	var vmax: float = Jogador.VEL_BASE * a.stat("velocidade")
	ok(andou > vmax * Jogador.DASH_VEL * Jogador.DASH_TEMPO, "foi mais longe que o dash antigo (%.0f px)" % andou)
	ok(j.rolar(Vector2.LEFT), "a segunda carga deixa rolar de novo")
	await esperar(0.5)   # acabou o segundo: sobrou menos de 1 carga
	ok(j.folego < 1.0, "as duas cargas foram gastas (%.2f)" % j.folego)
	ok(not j.rolar(Vector2.LEFT), "sem uma carga cheia não rola")
	var f0: float = j.folego
	await esperar(1.0)
	ok(j.folego > f0 + 0.4, "o fôlego volta com o tempo (%.2f -> %.2f)" % [f0, j.folego])
	await esperar(2.5)
	ok(is_equal_approx(j.folego, 2.0), "e enche até as duas cargas (%.2f)" % j.folego)
	a.queue_free()
	await esperar(0.1)
	print("ROLAMENTO falhas=%d" % falhas)
	get_tree().quit()
