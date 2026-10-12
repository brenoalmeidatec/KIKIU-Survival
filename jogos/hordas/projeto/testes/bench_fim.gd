extends Node
## Bench do pior caso do fim da partida (relato dos ~15 fps: 25 min, nível 70, ~500 inimigos). Não é teste de regra: só mede.
## Com janela e SEM V-Sync. Determinístico: semente 7, build de nível 70 com semente fixa, herói andando num quadrado.
## Roda: godot --path jogos/hordas/projeto res://testes/bench_fim.tscn -- --perfil=alto|medio|baixo
##   opções: --n=500 (bichos pedidos; também limita o diretor do jogo, então --n=350 dá mesmo ~350 vivos) --seg=12 --aquecer=3 --fase=4 --build=70 --pular=1500 (s de partida: 25 min)
##           --picos=MS (quadros acima de MS ms, com o que pesou neles) --dissecar_hud (chamadas de desenho por nó do HUD) --sem_hud
##           --limite (repõe só até o teto de vivos do jogo, diretor.limite_vivos(): é o que a partida de verdade faz;
##           sem ele, repõe sempre até n, que é o custo cru de n bichos) --armas=a,b,c --nivel_arma=8 (no lugar das armas da build)
## Diferente do bench_horda: entra com a build cheia (armas evoluídas, passivos), o relógio no fim e os efeitos ligados,
## então mede também projéteis, poças, números, partículas e mortes, não só a horda.
## Linha final: BENCH_FIM ... fps=... ms_med=... ms_p95=... ms_max=... vivos_med=... (use a mediana de várias rodadas).
const Perf := preload("res://scripts/hordas/perf.gd")
var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=", true, 1)
		_args[p[0]] = p[1] if p.size() > 1 else "1"
	var seg := float(_args.get("seg", 12))
	var aquecer := float(_args.get("aquecer", 3))
	var n := int(_args.get("n", 500))
	var perfil := str(_args.get("perfil", "alto"))
	seed(7)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if Config.has_method("g_perfil_temporario"):
		Config.g_perfil_temporario(perfil)
	else:  # versões antes do #155 (Release do hotfix #140 e anteriores): qualidade alta|media|baixa
		Config.temporario("qualidade", {"alto": "alta", "medio": "media", "baixo": "baixa"}.get(perfil, perfil))
	Config.temporario("pausar_fora", false)
	Config.temporario("qualidade_auto", false)  # a qualidade automática trocaria o perfil no meio da medição
	var m = load("res://main.tscn").instantiate()
	m._args["fase"] = str(_args.get("fase", 4))
	m._args["semente"] = "7"
	m._args["pular"] = str(_args.get("pular", 1500))
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(0.3).timeout
	m._comecar("hazaki")
	var a = m._arena
	var j = a.jogador
	_dar_build(a, int(_args.get("build", 70)))
	if _args.has("n"):  # --n=N também limita o diretor: sem isso ele enche até o teto do jogo e o n pedido não vale
		a.diretor._dif["limite_vivos"] = n
		a.diretor._dif["limite_vivos_pror"] = n
		a.diretor._fase["limite_vivos"] = n
	a.diretor.xp_mult = 0.0  # ninguém sobe de nível no meio (a carta pausaria o jogo)
	var tabela: Array = m._tipos_do_conjunto(a.diretor.conjunto())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	await get_tree().create_timer(1.5).timeout  # entrada do herói
	if _args.has("dissecar_hud"):
		await _dissecar(a.hud)
	if _args.has("sem_hud"):  # isola o custo da interface (chamadas de desenho e o hud_a)
		a.hud.visible = false
	Perf.ligado = true
	var tempos: Array[float] = []
	var vivos_soma := 0.0
	var t := 0.0
	var q0: int = a.inimigos._quadro
	var pf0 := Engine.get_process_frames()
	var ult := Time.get_ticks_usec()
	var dirs := ["direita", "baixo", "esquerda", "cima"]
	var dir_atual := ""
	var chamadas := 0.0
	var proc := 0.0
	var alvo := n
	var pausas := 0
	while t < aquecer + seg:
		await get_tree().process_frame
		if get_tree().paused:  # baú de elite ou carta no meio da rodada: a lógica continua (a carta fica na tela) e a rodada conta
			get_tree().paused = false
			pausas += 1
		var agora := Time.get_ticks_usec()
		var dt := (agora - ult) / 1e6
		ult = agora
		t += dt
		j.invencivel = 1.0
		j.hp = j.hp if j.hp > 50.0 else 100.0
		alvo = mini(n, _limite(a)) if _args.has("limite") else n
		var falta: int = alvo - a.inimigos.vivos()
		for i in mini(maxi(falta, 0), 12):
			a.inimigos.criar(tabela[rng.randi() % tabela.size()], j.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(250, 420))
		var d: String = dirs[int(t / 2.0) % 4]
		if d != dir_atual:
			if dir_atual != "":
				Input.action_release(dir_atual)
			Input.action_press(d)
			dir_atual = d
		if t < aquecer:
			Perf.relatorio()
			continue
		tempos.append(dt * 1000.0)
		if _args.has("picos"):
			_pico(dt * 1000.0, float(_args.picos))
		vivos_soma += a.inimigos.vivos()
		chamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var logica: float = float(a.inimigos._quadro - q0) / maxf(1.0, float(Engine.get_process_frames() - pf0))
	Input.action_release(dir_atual)
	tempos.sort()
	var soma := 0.0
	for x in tempos:
		soma += x
	print("  perf_us: ", Perf.relatorio())
	if "_atlas" in a.inimigos:  # atlas das folhas (#127): geração > 0 = foi refeito (cheio) no meio da partida
		print("  atlas: geracao=%d altura=%d" % [a.inimigos._atlas.geracao, a.inimigos._atlas._img.get_height()])
	print(
		(
			"BENCH_FIM perfil=%s n=%d alvo=%d limite=%s armas=%d quadros=%d logica=%.2f chamadas=%d proc_ms=%.2f fps=%.1f ms_med=%.2f ms_p95=%.2f ms_max=%.1f vivos_med=%d pausas=%d"
			% [
				perfil,
				n,
				alvo,
				str(_args.has("limite")),
				a.armas.lista.size(),
				tempos.size(),
				logica,
				chamadas / tempos.size(),
				proc / tempos.size(),
				1000.0 * tempos.size() / soma,
				tempos[tempos.size() / 2],
				tempos[int(tempos.size() * 0.95)],
				tempos[-1],
				int(vivos_soma / tempos.size()),
				pausas,
			]
		)
	)
	get_tree().quit()


var _snap := {}


func _chamadas(q: int) -> float:
	var c := 0.0
	for i in q:
		await get_tree().process_frame
		get_tree().paused = false
		c += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return c / q


## --dissecar_hud: esconde cada nó visível do HUD por alguns quadros e imprime quantas chamadas de desenho ele custa.
func _dissecar(raiz: Node) -> void:
	var nos: Array = []
	var pilha: Array = [raiz]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		if no is CanvasItem and no.is_visible_in_tree():
			nos.append(no)
	var base: float = await _chamadas(20)
	print("DISSECAR base=%.0f nos=%d" % [base, nos.size()])
	for no in nos:
		no.visible = false
		var c: float = await _chamadas(12)
		no.visible = true
		await _chamadas(3)
		if base - c > 5:
			print("DISSECAR %s (%s) custa=%.0f filhos=%d" % [raiz.get_path_to(no), no.get_class(), base - c, no.get_child_count()])


## --picos=MS: imprime os quadros acima de MS ms com os 5 sistemas (perf.gd) que mais gastaram NESSE quadro e o que o perf.gd não cobre
## (desenho no driver, nós de interface, física, GC). O Perf acumula desde o último relatório: a diferença entre dois quadros é o quadro.
func _pico(ms: float, limite_ms: float) -> void:
	var agora: Dictionary = Perf.us.duplicate()
	if ms > limite_ms and not _snap.is_empty():
		var difs := []
		var soma := 0
		for k in agora:
			var d := int(agora[k]) - int(_snap.get(k, 0))
			if d > 0:
				difs.append([k, d])
				soma += d
		difs.sort_custom(func(x, y): return x[1] > y[1])
		var txt := ""
		for x in difs.slice(0, 5):
			txt += " %s=%.1f" % [x[0], x[1] / 1000.0]
		print("PICO ms=%.1f medido=%.1f fora=%.1f |%s" % [ms, soma / 1000.0, ms - soma / 1000.0, txt])
	_snap = agora


## Teto de vivos de cada versão: a main tem diretor.limite_vivos() (#127); o hotfix #140 lia o do perfil em Config.q;
## antes dele só existia o da fase (500).
func _limite(a) -> int:
	if a.diretor.has_method("limite_vivos"):
		return a.diretor.limite_vivos()
	var lim := int(a.diretor._dif.get("limite_vivos", 500))
	if Config.has_method("q") and Config.q("limite_vivos") != null:
		lim = mini(lim, int(Config.q("limite_vivos")))
	return lim


## A build sai daqui (e não do --build do main) para ser a mesma em todas as versões: antes do #140 o --build não tinha semente.
func _dar_build(a, nv: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 70707
	var b: Dictionary = a.Construcao.gerar(a.heroi_id, nv, rng)
	if _args.has("armas"):
		b.armas = []
		for id in str(_args.armas).split(","):
			b.armas.append({"id": id, "nivel": int(_args.get("nivel_arma", 8))})
	a.armas.lista.clear()
	for x in b.armas:
		a.armas.adicionar(x.id)
		a.armas.achar(x.id).nivel = x.nivel
	a.passivos = b.passivos
	a.nivel = nv
	a._recalcular()
	a.jogador.hp = a.stat("vida_max")
	a.atualizar_visual()
