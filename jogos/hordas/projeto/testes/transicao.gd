extends Node
# Teste automático (#55): a cortina da transição dura DUR segundos em TEMPO REAL, mesmo com o jogo a poucos quadros por segundo
# (PC fraco) e mesmo se o quadro da troca de tela for longo (tela pesada carregando). Mede também o custo de desenhar a cortina.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/transicao.tscn  (imprime "TRANSICAO falhas=0")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


## Chama revelar() e devolve quantos segundos reais a cortina levou pra acabar, com `atraso_ms` de espera em cada quadro (simula fps baixo).
func medir(atraso_ms: int, quadro_longo_ms := 0) -> float:
	await get_tree().process_frame
	if quadro_longo_ms > 0:
		OS.delay_msec(quadro_longo_ms)  # a troca de tela carregando coisa pesada no mesmo quadro
	var t0 := Time.get_ticks_usec()
	Transicao.revelar()
	var n := 0
	while Transicao.ativa() and n < 2000:
		OS.delay_msec(atraso_ms)
		await get_tree().process_frame
		n += 1
	return (Time.get_ticks_usec() - t0) / 1.0e6


func _ready() -> void:
	await get_tree().create_timer(0.3, true, false, true).timeout
	var dur: float = Transicao.DUR
	for fps in [60, 30, 15, 8]:
		var s := await medir(maxi(1000 / fps - 2, 0))
		print("fps~%d: a cortina levou %.3f s reais (DUR %.2f)" % [fps, s, dur])
		ok(s >= dur - 0.02 and s <= dur + 2.0 / fps + 0.05, "fps~%d: a cortina leva ~DUR em tempo real (%.3f s)" % [fps, s])
	# quadro longo na troca de tela: a animação não pode ser engolida
	var s2 := await medir(10, 500)
	print("quadro longo de 500 ms na troca: %.3f s" % s2)
	ok(s2 >= dur - 0.02 and s2 <= dur + 0.15, "quadro longo na troca não pula a animação (%.3f s)" % s2)
	# time_scale alto (--rapido) não acelera a cortina
	Engine.time_scale = 3.0
	var s3 := await medir(10)
	Engine.time_scale = 1.0
	ok(s3 >= dur - 0.02 and s3 <= dur + 0.1, "time_scale 3 não muda a duração (%.3f s)" % s3)
	# custo de desenhar um quadro da cortina (a pior fase, no começo, com os losangos cheios)
	# Mede a MEDIANA dos quadros, não a média: quando a máquina está carregada, o sistema tira a CPU do teste no meio
	# de um _desenhar e um quadro sai com milissegundos a mais. Isso puxa a média pra cima e não diz nada sobre o custo
	# da cortina; a mediana mostra o custo típico e ainda pega uma regressão de verdade (que atinge todos os quadros).
	var amostras: Array = []
	var pior := 0
	for i in 5:  # 5 cortinas inteiras a ~60 fps
		await get_tree().process_frame
		Transicao.revelar()
		while Transicao.ativa():
			OS.delay_msec(14)
			await get_tree().process_frame
			if Transicao.ultimo_us > 0:
				amostras.append(Transicao.ultimo_us)
				pior = maxi(pior, Transicao.ultimo_us)
	amostras.sort()
	var n := amostras.size()
	var mediana: int = amostras[n / 2] if n > 0 else 0
	var medio := 0.0
	for v in amostras:
		medio += v
	medio /= float(maxi(n, 1))
	print("custo de _desenhar: mediana %d us, media %.0f us, pior %d us (%d quadros)" % [mediana, medio, pior, n])
	ok(n > 20 and mediana < 1000, "desenhar a cortina custa pouco (mediana %d us)" % mediana)
	print("TRANSICAO falhas=", falhas)
	get_tree().quit()
