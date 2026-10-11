extends Node
# Teste automático: especial de cada herói (#63, tecla E). Usa o especial com inimigos em volta e confere o efeito.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/especiais.tscn  (imprime "ESPECIAL falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func arena_de(heroi: String) -> Node:
	var a := Arena.new()
	a.heroi_id = heroi
	add_child(a)
	await esperar(0.2)
	return a


## Um anel de vírus comuns em volta do herói, a "dist" px.
func cercar(a: Node, dist: float, n := 8) -> Array:
	var l := []
	for i in n:
		var v = a.inimigos.criar("bug", a.jogador.centro() + Vector2.from_angle(TAU * i / n) * dist)
		if v:
			v.hp = 99999.0
			v.hpmax = 99999.0
			l.append(v)
	return l


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):  # sem o main.gd, ninguém registrou as teclas
			InputMap.add_action(acao)
	# quem não tem especial no JSON não ganha um
	var joao = await arena_de("joao")
	ok(not joao.especial.tem(), "João (sem especial no JSON) não tem especial")
	joao.queue_free()

	# Hazaki: "Sou Gostoso!" atordoa quem está perto e dá crítico por uns segundos
	var h = await arena_de("hazaki")
	ok(h.especial.tem() and not h.especial.pronto(), "Hazaki tem especial e começa recarregando")
	var perto: Array = cercar(h, 60.0)
	var longe: Array = cercar(h, 400.0, 4)
	await esperar(0.05)  # os recém-criados entram na grade (no_circulo) no próximo quadro
	var crit_antes: float = h.stat("critico")
	h.especial.recarga = 0.0
	h.especial.usar()
	ok(perto.all(func(v): return v.atordoado > 0.0), "Sou Gostoso!: os de perto ficam atordoados")
	ok(longe.all(func(v): return v.atordoado <= 0.0), "Sou Gostoso!: os de longe não")
	ok(h.stat("critico") > crit_antes, "Sou Gostoso!: crítico sobe")
	ok(h.especial.recarga >= 3.0 and h.especial.usos == 1, "recarga começa de novo (%.1f s)" % h.especial.recarga)
	h.especial._bonus_t = 0.0
	ok(is_equal_approx(h.stat("critico"), crit_antes), "bônus some quando acaba")
	h.queue_free()

	# Nicão: "Na Manha" fica invencível, se cura e deixa lento quem chega perto
	var n = await arena_de("nicao")
	n.jogador.hp = n.jogador.vida_max() * 0.4
	var hp_antes: float = n.jogador.hp
	var cerco: Array = cercar(n, 70.0)
	await esperar(0.05)
	n.especial.recarga = 0.0
	n.especial.usar()
	ok(n.jogador.invencivel >= 3.5, "Na Manha: invencível (%.1f s)" % n.jogador.invencivel)
	ok(n.jogador.hp > hp_antes, "Na Manha: se cura (%.0f -> %.0f)" % [hp_antes, n.jogador.hp])
	await esperar(0.15)
	ok(cerco.any(func(v): return v.lento > 0.0), "Na Manha: quem está perto fica lento")
	n.queue_free()

	# Lucas: "Pegou Onda" surfa (dash) e a onda atropela quem está na frente
	var l = await arena_de("lucas")
	l.jogador.lado = 1.0
	var frente: Array = []
	for i in 3:
		var v = l.inimigos.criar("bug", l.jogador.position + Vector2(140.0 + i * 60.0, -10.0 + i * 15.0))
		v.hp = 99999.0
		v.hpmax = 99999.0
		frente.append(v)
	var atras_v = l.inimigos.criar("bug", l.jogador.position + Vector2(-200.0, 0.0))
	atras_v.hp = 99999.0
	await esperar(0.05)
	l.especial.recarga = 0.0
	l.especial.usar()
	ok(l.jogador.dash_t > 0.3, "Pegou Onda: o Lucas surfa (dash %.2f s)" % l.jogador.dash_t)
	await esperar(1.0)
	var onda: Array = l.armas.especiais.filter(func(e): return e.tipo == "onda")
	var acertou: Array = []
	for e in onda:
		acertou.append_array(e.acertou)
	ok(frente.all(func(v): return v.hp < 99999.0) or frente.all(func(v): return v.id in acertou), "Pegou Onda: a onda acerta os da frente")
	ok(atras_v.hp >= 99999.0, "Pegou Onda: quem está atrás não")
	l.queue_free()

	print("ESPECIAL falhas=", falhas)
	get_tree().quit()
