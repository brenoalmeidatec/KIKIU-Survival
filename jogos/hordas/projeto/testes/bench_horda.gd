extends Node
## Bench de desempenho determinístico (não é teste de regra: não falha, só mede). Com janela e SEM V-Sync.
## Roda: godot --path jogos/hordas/projeto res://testes/bench_horda.tscn -- --qualidade=alta|media|baixa --n=500 --seg=12
##   opções: --aquecer=3 (s ignorados) --fase=4 --pacifico (sem armas: ninguém morre, a conta de bichos não muda)
## O herói anda num quadrado (2 s por lado) e é invulnerável; os bichos nascem em posições de uma semente fixa (seed 7),
## o diretor repõe até o limite de 500 vivos. Imprime fps médio, tempo por quadro (mediana, p95, pior) e o custo por sistema (perf.gd).
## Linha final: BENCH qualidade=... n=... fps=... ms_med=... ms_p95=... (use a mediana de várias rodadas: o fps de uma rodada varia ~5%).
const Perf := preload("res://scripts/hordas/perf.gd")
var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=", true, 1)
		_args[p[0]] = p[1] if p.size() > 1 else "1"
	var seg := float(_args.get("seg", 12))
	var aquecer := float(_args.get("aquecer", 3))
	var n := int(_args.get("n", 500))
	seed(7)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Config.temporario("qualidade", str(_args.get("qualidade", "alta")))
	Config.temporario("pausar_fora", false)   # sem foco (outra janela na frente) a partida pausaria e a rodada ficaria inválida (logica < 1)
	var m = load("res://main.tscn").instantiate()
	m._args["fase"] = str(_args.get("fase", 4))
	m._args["estresse"] = str(n)
	m._args["semente"] = "7"   # mesmo mapa, santuários e props em toda rodada
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(0.3).timeout
	m._comecar("hazaki")
	var a = m._arena
	var j = a.jogador
	a.diretor.xp_mult = 0.0   # sem XP: ninguém sobe de nível no meio da medição (a carta pausaria o jogo)
	var tabela: Array = m._tipos_do_conjunto(a.diretor.conjunto())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	if _args.has("pacifico"):
		a.armas.lista.clear()
	await get_tree().create_timer(1.5).timeout   # entrada do herói
	Perf.ligado = true
	var tempos: Array[float] = []
	var t := 0.0
	var vivos_ini: int = a.inimigos.vivos()
	var q0: int = a.inimigos._quadro
	var pf0 := Engine.get_process_frames()
	var ult := Time.get_ticks_usec()
	var dirs := ["direita", "baixo", "esquerda", "cima"]
	var dir_atual := ""
	var chamadas := 0.0
	var prims := 0.0
	var proc := 0.0
	while t < aquecer + seg:
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		var dt := (agora - ult) / 1e6
		ult = agora
		t += dt
		j.invencivel = 1.0
		j.hp = 100.0
		var falta: int = n - a.inimigos.vivos()   # repõe o que as armas mataram (no máximo 12 por quadro): o número de bichos fica em ~n
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
		chamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var logica: float = float(a.inimigos._quadro - q0) / maxf(1.0, float(Engine.get_process_frames() - pf0))   # 1.0 = a lógica rodou todo quadro; menos = a partida pausou (carta, loja, fim da fase): rodada inválida
	Input.action_release(dir_atual)
	tempos.sort()
	var soma := 0.0
	for x in tempos:
		soma += x
	var med := tempos[tempos.size() / 2]
	var p95 := tempos[int(tempos.size() * 0.95)]
	var fps := 1000.0 * tempos.size() / soma
	print("  perf_us: ", Perf.relatorio())
	print("BENCH qualidade=%s n=%d cpus=%d vivos_ini=%d vivos_fim=%d quadros=%d logica=%.2f chamadas=%d prims=%d proc_ms=%.2f fps=%.1f ms_med=%.2f ms_p95=%.2f ms_max=%.1f" % [
		str(_args.get("qualidade", "alta")), n, OS.get_processor_count(), vivos_ini, a.inimigos.vivos(), tempos.size(), logica, chamadas / tempos.size(), prims / tempos.size(), proc / tempos.size(), fps, med, p95, tempos[-1]])
	get_tree().quit()
