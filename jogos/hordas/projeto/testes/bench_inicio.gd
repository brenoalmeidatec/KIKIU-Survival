extends Node
## Bench dos primeiros quadros (não é teste de regra: só mede). Janela real, sem V-Sync.
## Roda: godot --path jogos/hordas/projeto res://testes/bench_inicio.tscn -- [--quadros=120] [--fase=1] [--qualidade=alta]
## Mede o tempo de cada quadro (ms) em 3 momentos: abrir o título, trocar de tela (título -> Meus heróis) e começar uma partida.
## Imprime por momento: o custo síncrono da chamada, os 12 primeiros quadros "total(script)" (script = todos os _process,
## o resto é desenho + troca de buffer + driver), o pior quadro, a mediana do fim, quantos quadros até estabilizar
## (primeiro quadro depois do qual 10 seguidos ficam abaixo de 1,5x a mediana do fim) e o tempo perdido (soma do que passou da mediana).
const Perf := preload("res://scripts/hordas/perf.gd")
var _args := {}
var _ini := 0          # início do quadro (este nó tem a prioridade mais baixa)
var _fim_script := 0   # fim dos _process (sinal frame_pre_draw do RenderingServer)
var _scripts: Array[float] = []


func _ready() -> void:
	process_priority = -100000
	RenderingServer.frame_pre_draw.connect(func(): _fim_script = Time.get_ticks_usec())
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=", true, 1)
		_args[p[0]] = p[1] if p.size() > 1 else "1"
	var n := int(_args.get("quadros", 120))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Config.temporario("qualidade", str(_args.get("qualidade", "alta")))
	Config.temporario("pausar_fora", false)   # sem foco (outra janela na frente) a partida pausaria e a rodada ficaria inválida (logica < 1)
	var t0 := Time.get_ticks_usec()
	var m = load("res://main.tscn").instantiate()
	m._args["semente"] = "7"
	for k in ["fase", "estresse", "heroi"]:
		if _args.has(k):
			m._args[k] = str(_args[k])
	get_tree().root.add_child.call_deferred(m)
	var criar_ms := (Time.get_ticks_usec() - t0) / 1000.0
	await _medir("titulo", n, criar_ms)
	if _args.has("so_titulo"):
		get_tree().quit()
		return
	await get_tree().create_timer(0.5).timeout
	m._estado = "herois"
	await _medir("trocar_tela", n, 0.0)
	await get_tree().create_timer(0.5).timeout
	t0 = Time.get_ticks_usec()
	Perf.ligado = true   # custo por sistema nos primeiros quadros da partida (us acumulados em 4 quadros)
	m._comecar("hazaki")
	var sinc := (Time.get_ticks_usec() - t0) / 1000.0
	await _medir("partida", n, sinc)
	get_tree().quit()


func _process(_dt: float) -> void:
	_ini = Time.get_ticks_usec()


func _medir(nome: String, n: int, sinc_ms: float) -> void:
	var ts: Array[float] = []
	_scripts.clear()
	var ult := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		ts.append((agora - ult) / 1000.0)
		_scripts.append(maxf(0.0, (_fim_script - _ini) / 1000.0))
		ult = agora
		if nome == "partida" and i == 3:
			print("PRIMEIROS4 ", Perf.us)
			Perf.ligado = false
	var fim := ts.slice(n * 2 / 3)
	fim.sort()
	var med: float = fim[fim.size() / 2]
	var estab := 0
	for i in n - 10:
		var ok := true
		for k in 10:
			if ts[i + k] > med * 1.5 + 0.5:
				ok = false
				break
		if ok:
			estab = i
			break
	var mx := 0.0
	var perdido := 0.0
	for x in ts:
		mx = maxf(mx, x)
		perdido += maxf(0.0, x - med)
	var primeiros := ""
	for i in 12:
		primeiros += "%.1f(%.1f) " % [ts[i], _scripts[i]]
	print("INICIO %s sinc_ms=%.1f pior_ms=%.1f mediana_fim_ms=%.2f estabiliza_no_quadro=%d tempo_perdido_ms=%.0f total(script)=[%s]" % [nome, sinc_ms, mx, med, estab, perdido, primeiros.strip_edges()])
