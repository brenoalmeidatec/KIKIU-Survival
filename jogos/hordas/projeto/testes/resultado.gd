extends Node
# Teste automático: tela de resultados da fase e entrada do chefe (#32 itens 7 e 6).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/resultado.tscn  (imprime "RESULT falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Resultado := preload("res://scripts/hordas/resultado.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func nova(bot := true) -> Node:
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = bot
	add_child(a)
	await esperar(0.2)
	return a


func _ready() -> void:
	# --- estatísticas da fase: somam certo e zeram na troca de fase
	var a := await nova()
	a.xp = -1.0e12   # sem subir de nível: o robô escolheria carta e mudaria a build no meio do teste
	ok(a.fase_stat.abates == 0 and a.fase_stat.dano.is_empty() and a.fase_stat.itens.is_empty(), "fase começa zerada")
	for i in 3:
		a.registrar_dano("pendrive", 10.0, Vector2.ZERO)
	a.registrar_dano("katana", 5.0, Vector2.ZERO)
	a.recompensa(Vector2(500, 500), "bug", false)
	a.recompensa(Vector2(500, 500), "bug", false)
	a.ganhar_xp(1.0)
	a.aplicar({"tipo": "passivo", "id": "energetico", "nome": "Energético", "icone": "energetico", "nivel": 1})
	a.aplicar({"tipo": "cura"})
	ok(a.fase_stat.abates == 2, "abates da fase somam (%s)" % a.fase_stat.abates)
	ok(is_equal_approx(float(a.fase_stat.dano.get("pendrive", 0)), 30.0), "dano do pendrive soma 30 (%s)" % a.fase_stat.dano)
	ok(is_equal_approx(float(a.fase_stat.dano.get("katana", 0)), 5.0), "dano da katana soma 5")
	ok(a.fase_stat.xp > 0.0, "xp da fase soma")
	ok(a.fase_stat.itens.size() == 1, "só passivo/arma/equipamento entram em itens (cura não): %d" % a.fase_stat.itens.size())
	ok(a.abates == 2 and is_equal_approx(float(a.dano_por_arma.get("pendrive", 0)), 30.0), "os totais da corrida seguem somando")
	var linhas: Array = Resultado.montar_linhas(a.fase_stat)
	var armas_l := linhas.filter(func(l): return l.tipo == "arma")
	ok(armas_l.size() == 2 and armas_l[0].valor == 30.0, "linhas de arma ordenadas por dano")
	var muitas := {"dano": {"a": 1.0, "b": 9.0, "c": 5.0, "d": 7.0, "e": 2.0}}
	ok(Resultado.montar_linhas(muitas).filter(func(l): return l.tipo == "arma").size() == 3, "só as 3 armas que mais causaram dano")
	a.entre_fases = true
	a.proxima_fase()
	ok(a.fase_stat.abates == 0 and a.fase_stat.dano.is_empty() and a.fase_stat.itens.is_empty() and a.fase_stat.xp == 0.0, "fase_stat zera na troca de fase")
	ok(a.abates == 2, "o total de abates da corrida não zera")
	a.recompensa(Vector2(500, 500), "bug", false)
	ok(a.fase_stat.abates == 1, "e volta a somar na fase nova")

	# --- a tela de resultados fecha sozinha com o robô (~1 s) e despausa
	a.fase_stat.tempo = 75.0
	a.resultado.abrir(a.fase_stat)
	ok(a.resultado.aberto(), "tela de resultados abre")
	ok(get_tree().paused, "o jogo para na tela (solo)")
	await esperar(0.4)
	ok(a.resultado.aberto(), "ainda aberta com 0,4 s")
	await esperar(1.3)
	ok(not a.resultado.aberto(), "fecha sozinha com o robô")
	ok(not get_tree().paused, "o jogo volta a andar")

	# --- fim de fase inteiro, solo com robô: resultado -> baú -> próxima fase, sem ninguém apertar nada
	var f0: int = a.diretor.fase_idx
	a.fase_completa()
	var t := 0.0
	while t < 14.0 and a.diretor.fase_idx == f0:
		await esperar(0.25)
		t += 0.25
	ok(a.diretor.fase_idx == f0 + 1, "a corrida segue pra próxima fase sozinha (%.1f s)" % t)
	ok(a.fase_stat.abates == 0, "estatísticas zeradas na fase nova")
	a.queue_free()
	await esperar(0.1)

	# --- entrada do chefe: câmera lenta só sozinho, placa e volta ao normal
	var b := await nova()
	b.xp = -1.0e12
	var chefe = b.inimigos.criar("trojan_gigante", b.jogador.position + Vector2(300, 0), 1)
	b.chefe_final_chegou(false, "trojan_gigante")
	await esperar(0.5)
	ok(b.entradas.ativo(), "entrada do chefe ativa")
	ok(Engine.time_scale < 0.9, "câmera lenta durante a entrada (%.2f)" % Engine.time_scale)
	var foco: Vector2 = b.entradas.camera(b.jogador.centro())
	ok(foco.distance_to(b.jogador.centro()) > 20.0, "a câmera vai em direção ao chefe")
	await esperar(2.6)
	ok(not b.entradas.ativo(), "entrada termina")
	ok(is_equal_approx(Engine.time_scale, 1.0), "time_scale volta a 1 (%.2f)" % Engine.time_scale)
	ok(b.entradas.camera(b.jogador.centro()).is_equal_approx(b.jogador.centro()), "a câmera volta pro herói")
	# nome e subtítulo vêm dos dados
	ok(str(Dados.json("inimigos").get("trojan_gigante", {}).get("subtitulo", "")) != "", "subtítulo do chefe está nos dados")
	b.queue_free()
	await esperar(0.1)

	# --- se a arena sair no meio da entrada, o tempo é devolvido
	var c := await nova()
	c.inimigos.criar("ransomware", c.jogador.position + Vector2(300, 0), 1)
	c.chefe_final_chegou(false, "ransomware")
	await esperar(0.3)
	ok(Engine.time_scale < 0.9, "câmera lenta de novo")
	c.free()
	ok(is_equal_approx(Engine.time_scale, 1.0), "arena fechada no meio da entrada devolve o tempo")
	Engine.time_scale = 1.0

	print("RESULT falhas=", falhas)
	get_tree().quit()
