extends Node
# Teste automático: regiões do mundo (#64). A corrida sorteada, a costura do mapa, o calor e o cenário por região.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/regioes.tscn  (imprime "REGIOES falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Regioes := preload("res://scripts/hordas/regioes.gd")
const Mapa := preload("res://scripts/hordas/mapa.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func corrida(semente: int) -> Array:
	Sorte.iniciar(semente)
	return Regioes.gerar_fases(Sorte.fluxo("regioes"))

func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	ok(Regioes.ativo() and Regioes.n() >= 5, "pelo menos 5 regiões (%d)" % Regioes.n())
	var k := Regioes.por_regiao()
	ok(k == 5, "5 fases por região (%d)" % k)
	var inim: Dictionary = Dados.json("inimigos")

	# --- a corrida sorteada
	var f1 := corrida(7)
	ok(f1.size() == Regioes.n() * k, "25 fases na corrida (%d)" % f1.size())
	ok(JSON.stringify(f1) == JSON.stringify(corrida(7)), "mesma semente, mesma corrida (igual em todos os clientes)")
	var diferentes := 0
	for s in range(1, 11):
		if JSON.stringify(corrida(s)) != JSON.stringify(f1):
			diferentes += 1
	ok(diferentes >= 8, "sementes diferentes dão corridas diferentes (%d de 10)" % diferentes)
	for s in [1, 7, 33]:
		var fs := corrida(s)
		for r in Regioes.n():
			var reg := Regioes.regiao(r)
			var nomes := []
			for a in k:
				var f: Dictionary = fs[r * k + a]
				ok(int(f.regiao) == r and int(f.andar_regiao) == a, "semente %d: fase %d na região %d andar %d" % [s, r * k + a + 1, r + 1, a + 1])
				ok(str(f.get("conjunto", "")) == str(f.get("conjunto", reg.get("conjunto"))) and f.has("cenario") and f.has("musica"), "semente %d: a fase herda conjunto, cenário e música da região" % s)
				ok(inim.has(str(f.get("chefe", ""))), "semente %d: o chefe da fase %d existe (%s)" % [s, r * k + a + 1, f.get("chefe", "")])
				if a < k - 1:
					ok(not f.get("chefe_regiao", false), "semente %d: só o último andar é o chefe da região" % s)
					nomes.append(str(f.nome))
				else:
					ok(f.get("chefe_regiao", false) and str(f.nome) == str(reg.chefe.nome), "semente %d: último andar da região %d é o chefe dela" % [s, r + 1])
			var unicos := {}
			for nm in nomes:
				unicos[nm] = true
			ok(unicos.size() == nomes.size(), "semente %d: região %d não repete fase (%s)" % [s, r + 1, nomes])
		var ultimo: Dictionary = fs[-1]
		ok(bool(inim.get(str(ultimo.chefe), {}).get("final", false)), "semente %d: o chefe da última região leva ao duelo" % s)
		for i in fs.size() - 1:
			ok(not bool(inim.get(str(fs[i].chefe), {}).get("final", false)), "semente %d: só o último chefe é final (fase %d)" % [s, i + 1])

	# --- mapa costurado: um por região, chefe no fim de cada uma, e o chefe leva à região seguinte
	Sorte.iniciar(5)
	var m := Mapa.gerar()
	ok(int(m.andares) == Regioes.n() * k and Mapa.erros(m).is_empty(), "mapa de %d andares e válido (%s)" % [int(m.andares), Mapa.erros(m).slice(0, 2)])
	for r in Regioes.n() - 1:
		var chefe := Mapa.todos(m).filter(func(n): return int(n.andar) == r * k + k - 1)
		var entradas := Mapa.todos(m).filter(func(n): return int(n.andar) == (r + 1) * k)
		ok(chefe.size() == 1 and chefe[0].prox.size() == entradas.size() and entradas.size() >= 2, "o chefe da região %d leva a todas as entradas da próxima" % (r + 1))

	# --- na partida: calor e cenário seguem a região
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = true
	a.semente = 9
	a.calor = {"couro": 1}
	add_child(a)
	await esperar(0.2)
	a.xp = -1.0e12
	var vida_r1: float = a.ef("inimigo_vida")
	ok(is_equal_approx(vida_r1, 0.2), "região 1: só o calor do jogador (%.2f)" % vida_r1)
	a.saltar_para_andar(2 * k)   # primeira fase da região 3
	await esperar(0.2)
	var reg3: Dictionary = Regioes.calor(2)
	var esperado := 0.2 + 0.2 * int(reg3.get("couro", 0))
	ok(is_equal_approx(a.ef("inimigo_vida"), esperado), "região 3: o calor dela soma no do jogador (%.2f, esperava %.2f)" % [a.ef("inimigo_vida"), esperado])
	ok(a.calor_pts == 1, "a recompensa conta só o calor do jogador (%d)" % a.calor_pts)
	var f3: Dictionary = a.diretor.fases()[a.diretor.fase_idx]
	ok(int(f3.regiao) == 2, "o diretor está na região 3")
	ok(a.chao.cenario == null or a.chao.cenario.nome == str(f3.cenario), "o cenário é o da região (%s)" % f3.cenario)
	a.diretor.ir_para(0)   # (o saltar só anda pra frente no mapa)
	a._atualizar_calor()
	await esperar(0.1)
	ok(is_equal_approx(a.ef("inimigo_vida"), 0.2), "de volta à região 1, o calor da região 3 sai")
	a.queue_free()
	print("REGIOES falhas=", falhas)
	get_tree().quit()
