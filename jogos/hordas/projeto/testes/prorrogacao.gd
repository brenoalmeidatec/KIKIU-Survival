extends Node
# Teste automático (#112): prorrogação (sobe a dificuldade e o ouro a cada degrau), portal de saída só depois do chefe,
# e a fase só acaba quando o jogador entra no portal e segura confirmar.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/prorrogacao.tscn  (imprime "PROR falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Diretor := preload("res://scripts/hordas/diretor_hordas.gd")
const Saida := preload("res://scripts/hordas/saida.gd")
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
	# --- dados e funções puras
	var c: Dictionary = Dados.json("prorrogacao")
	ok(c.has("_ajuda") and float(c.get("degrau_s", 0)) == 5.0, "prorrogacao.json: degrau de 5 s e _ajuda")
	ok(float(c.get("janela_chefe", 0)) > 0.0 and int(c.get("max_degraus", 0)) > 3, "janela do chefe e teto de degraus")
	ok(Diretor.degrau_de(-3.0, c) == 0 and Diretor.degrau_de(0.0, c) == 0 and Diretor.degrau_de(4.9, c) == 0, "antes de 5 s: degrau 0")
	ok(Diretor.degrau_de(5.0, c) == 1 and Diretor.degrau_de(9.9, c) == 1 and Diretor.degrau_de(10.0, c) == 2, "a cada 5 s sobe um degrau")
	ok(Diretor.degrau_de(99999.0, c) == int(c.max_degraus), "o degrau tem teto")
	ok(Saida.avancar(0.0, true, true, 0.5, 1.0) == 0.5 and Saida.avancar(0.5, true, false, 0.1, 1.0) < 0.5, "segurar sobe; soltar desce")
	ok(Saida.avancar(0.0, false, true, 0.5, 1.0) == 0.0, "segurar fora do portal não adianta")
	ok(Saida.avancar(0.9, true, true, 5.0, 1.0) == 1.0, "o progresso para no total")
	ok(Saida.dentro_do_portal(Vector2(10, 0), Vector2.ZERO, 34.0) and not Saida.dentro_do_portal(Vector2(100, 0), Vector2.ZERO, 34.0), "dentro / fora do raio")

	# --- na arena
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = false
	a.semente = 7
	add_child(a)
	await esperar(0.3)
	# o mapa fechado (#128) tem teste próprio (mapa_mundo.gd): aqui o terreno é livre, para testar só o portal e a saída
	if a.mapa_fase_mundo:
		a.mapa_fase_mundo.free()
		a.mapa_fase_mundo = null
	a.bot = false
	a.jogador.bot = false
	var d = a.diretor
	var dur := float(d.fases()[d.fase_idx].get("duracao", 600))
	var janela := float(c.janela_chefe)
	var tipo := str(d.fases()[d.fase_idx].get("chefe", ""))
	ok(not a.saida.aberta, "a saída começa fechada")
	d.final_chamado = true   # (o chefe já nasceu)
	d.chefe_fase = tipo
	var ouro_ini := 0
	var min_base := 0.0
	# antes de acabar a janela: sem prorrogação
	d.t_fase = dur + janela - 1.0
	ok(not d.pror_ativa() and d.pror_degrau() == 0 and is_equal_approx(d.mult_ouro(), 1.0), "dentro da janela do chefe não há prorrogação")
	ok(d.janela_resta() > 0.0, "a janela mostra o tempo que resta")
	d.t_fase = dur + janela
	min_base = d.minutos() - d.t_fase / 60.0
	ok(d.pror_ativa() and d.pror_degrau() == 0, "acabou a janela: a prorrogação começa no degrau 0")
	var ouro0 := a.ouro
	a.recompensa(Vector2.ZERO, tipo, false)
	var ganho0: int = a.ouro - ouro0
	var mins: Array = []
	var ouros: Array = []
	for k in 5:
		d.t_fase = dur + janela + 5.0 * k + 0.2
		ok(d.pror_degrau() == k, "a %d s da prorrogação: degrau %d (veio %d)" % [5 * k, k, d.pror_degrau()])
		mins.append(d.minutos() - d.t_fase / 60.0)
		ouros.append(d.mult_ouro())
	for k in range(1, 5):
		ok(mins[k] > mins[k - 1] + 0.3, "a dificuldade (minutos) sobe a cada degrau (%d)" % k)
		ok(ouros[k] > ouros[k - 1] + 0.2, "o multiplicador de ouro sobe a cada degrau (%d)" % k)
	ouro0 = a.ouro
	a.recompensa(Vector2.ZERO, tipo, false)
	var ganho4: int = a.ouro - ouro0
	ok(ganho4 >= ganho0 * 2 - 1, "o ouro do abate no degrau 4 é ~2x o do degrau 0 (%d vs %d)" % [ganho4, ganho0])
	d.t_fase = 5.0
	d.final_chamado = true
	ok(not d.pror_ativa(), "voltou o relógio: sem prorrogação")

	# --- portal só depois do chefe
	await esperar(0.2)
	ok(not a.saida.aberta and not a.entre_fases, "o chefe vivo: sem portal")
	a.jogador.position = a.jogador.position   # o herói fica onde está
	var boss = a.inimigos.criar(tipo, a.jogador.position + Vector2(300, 0), 1)
	var onde: Vector2 = boss.pos
	a.inimigos.ferir(boss, 1.0e9, Vector2.ZERO, "teste")
	ok(a.saida.aberta, "chefe morto: o portal abre")
	ok(a.saida.pos.distance_to(onde) < 1.0, "o portal abre onde o chefe caiu")
	ok(not a.entre_fases, "chefe morto NÃO leva sozinho pra próxima fase")
	ok(d.saida_leve, "a horda fica mais leve com a saída aberta")

	# --- sair só pelo portal
	await esperar(2.0)
	ok(a.saida.aberta and not a.entre_fases and a.saida.seg == 0.0, "longe do portal e sem segurar: a fase não acaba")
	a.jogador.position = a.saida.pos + Vector2(0, 8)
	a.jogador.invencivel = 99.0
	await esperar(0.5)
	ok(not a.entre_fases and a.saida.seg == 0.0, "dentro do portal mas sem segurar confirmar: não sai")
	a.jogador.position = a.saida.pos + Vector2(160, 8)   # longe: o robô precisa andar até o portal sozinho
	a.bot = true   # o robô anda até o portal e segura confirmar sozinho
	a.jogador.bot = true
	var n := 0
	while a.saida.seg <= 0.0 and n < 40:   # (o tempo do jogo pode andar mais devagar que o relógio: câmera lenta da entrada do chefe)
		await esperar(0.1)
		n += 1
	ok(a.saida.seg > 0.0 and not a.entre_fases, "segurando: o progresso sobe (ainda não saiu)")
	n = 0
	while not a.entre_fases and n < 150:
		await esperar(0.1)
		n += 1
	ok(a.entre_fases, "segurou até o fim: a fase acaba (resultados e mapa)")
	print("PROR falhas=", falhas)
	get_tree().quit(1 if falhas > 0 else 0)
