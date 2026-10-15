extends Control
# Benchmark portátil: --baseline=<salao.gd> --out=<pasta> --pairs=3.
# Janela renderizada com vsync desativado; capturas fora da janela de medição.
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
var baseline := ""
var destino := "user://bench_salao"
var pares := 3
var reais := {}
var prefixo := ""
var resultados := []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline="):
			baseline = arg.trim_prefix("--baseline=")
		if arg.begins_with("--out="):
			destino = arg.trim_prefix("--out=")
		if arg.begins_with("--pairs="):
			pares = int(arg.trim_prefix("--pairs="))
	DirAccess.make_dir_recursive_absolute(destino)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(960, 540))
	prefixo = "qa_bench_vivo_%d_" % Time.get_ticks_usec()
	var d := DirAccess.open("user://")
	for arquivo in d.get_files():
		if not arquivo.begins_with("qa_"):
			reais[arquivo] = FileAccess.get_sha256("user://" + arquivo)
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	Meta.caminho_save = "user://" + prefixo + "meta.cfg"
	Personagens.ativar(Personagens.criar("Matheus"))
	# Prime ambos os shaders antes dos pares para evitar favorecer o segundo cenário.
	for versao in ["antes", "depois"]:
		if versao == "antes" and baseline.is_empty():
			continue
		await rodada(versao, "medio", "idle", -1, false)
	for par in pares:
		var ordem := ["antes", "depois"] if par % 2 == 0 else ["depois", "antes"]
		for perfil in ["baixo", "medio"]:
			for movimento in ["idle", "moving"]:
				for versao in ordem:
					if versao == "antes" and baseline.is_empty():
						continue
					await rodada(versao, perfil, movimento, par, true)
	var falhas := 0
	for arquivo in reais:
		if FileAccess.get_sha256("user://" + arquivo) != reais[arquivo]:
			push_error("Save real alterado: " + arquivo)
			falhas += 1
	for arquivo in d.get_files():
		if arquivo.begins_with(prefixo):
			d.remove(arquivo)
	var f := FileAccess.open(destino.path_join("metrics.json"), FileAccess.WRITE)
	f.store_string(
		JSON.stringify(
			{
				"renderer": RenderingServer.get_video_adapter_name(),
				"godot": Engine.get_version_info(),
				"size": [960, 540],
				"warmup_seconds": 3,
				"sample_seconds": 3,
				"vsync": false,
				"max_fps": Engine.max_fps,
				"save_hashes_before": reais,
				"save_failures": falhas,
				"results": resultados
			},
			"\t"
		)
	)
	var csv := FileAccess.open(destino.path_join("metrics.csv"), FileAccess.WRITE)
	csv.store_line("version,profile,movement,pair,frames,fps,median_frame_ms,p95_frame_ms,median_cpu_ms,p95_cpu_ms")
	for r in resultados:
		csv.store_line(
			(
				"%s,%s,%s,%d,%d,%.3f,%.3f,%.3f,%.3f,%.3f"
				% [r.version, r.profile, r.movement, r.pair, r.frames, r.fps, r.median_frame_ms, r.p95_frame_ms, r.median_cpu_ms, r.p95_cpu_ms]
			)
		)
	print("bench_salao_vivo falhas=%d resultados=%d" % [falhas, resultados.size()])
	get_tree().quit(falhas)


func rodada(versao: String, perfil: String, movimento: String, par: int, medir: bool) -> void:
	Config.g_perfil_temporario(perfil)
	seed(123456)
	var s: Control = load("res://v2/salao.tscn").instantiate()
	if versao == "antes":
		s.set_script(load(baseline))
	add_child(s)
	s.ao_entrar = func(_cena): pass
	await get_tree().process_frame
	var inicio := Time.get_ticks_usec()
	var ultimo := inicio
	var frames := []
	var cpu := []
	var total := 0
	while Time.get_ticks_usec() - inicio < 6000000:
		var tempo := float(Time.get_ticks_usec() - inicio) / 1000000.0
		# Caminho periódico fixo, independente da taxa de quadros; não abre painéis.
		if movimento == "moving":
			var fase := fmod(tempo, 4.0)
			for acao in ["esquerda", "direita", "cima", "baixo"]:
				Input.action_release(acao)
			Input.action_press("direita" if fase < 1.0 else ("cima" if fase < 2.0 else ("esquerda" if fase < 3.0 else "baixo")))
			s._destino = Vector2.INF
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		if tempo >= 3.0:
			frames.append(float(agora - ultimo) / 1000.0)
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			total += agora - ultimo
		ultimo = agora
	if medir:
		frames.sort()
		cpu.sort()
		var r := {
			"version": versao,
			"profile": perfil,
			"movement": movimento,
			"pair": par,
			"frames": frames.size(),
			"fps": frames.size() * 1000000.0 / total,
			"median_frame_ms": frames[frames.size() / 2],
			"p95_frame_ms": frames[int(frames.size() * 0.95)],
			"median_cpu_ms": cpu[cpu.size() / 2],
			"p95_cpu_ms": cpu[int(cpu.size() * 0.95)]
		}
		resultados.append(r)
		print(JSON.stringify(r))
		if par == 0 and movimento == "idle":
			for i in 10:
				await get_tree().create_timer(0.1).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(destino.path_join("%s_%s_%02d.png" % [versao, perfil, i]))
	for acao in ["esquerda", "direita", "cima", "baixo"]:
		Input.action_release(acao)
	s.queue_free()
	await get_tree().process_frame
