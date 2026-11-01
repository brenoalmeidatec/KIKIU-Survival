extends "res://testes/isolamento_v2.gd"
# Teste do fator de tempo por mapa (ECO-1): dados/v2_niveis.json > tempo_mult, lido por v2/diretor.gd. O relógio do diretor (ondas
# fortes, taxa de nascimento, teto de vivos, elenco e a força por minuto dos monstros) anda tempo_mult vezes mais depressa que o tempo
# da partida, então um mapa mais curto passa pela mesma curva de monstros. A Floresta fica em 1,0 (nada muda para ela). Aqui se
# confere: os quatro mapas (fator, níveis, duração do nível, chefão no último nível com a vida do desenho), a taxa, o teto e a vida
# das Ruínas iguais aos da Floresta no tempo multiplicado, e a onda forte nas Ruínas vindo no relógio do diretor e não no real.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_tempo_mult.tscn  (imprime "v2_tempo_mult falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const TEMPOS := [0.0, 60.0, 200.0, 400.0]
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


## Um mundo do mapa `id` com o diretor sob controle do teste (o mundo não roda sozinho). Quem chama libera com queue_free().
func mundo_do_mapa(id: String):
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = id
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.combate.diretor.ligado = false
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.imortal = true
	await get_tree().process_frame
	return w


func _ready() -> void:
	# 1. os quatro mapas: fator, níveis, duração do nível e o chefão no último nível com a vida que o desenho manda (9.000 x fator)
	var esperado := {
		"floresta": [1.0, 10, 25.0, 4500.0],
		"laboratorio": [1.15, 20, 24.0, 10800.0],
		"cidade": [1.25, 30, 22.0, 15300.0],
		"medio": [1.4, 40, 22.0, 19800.0],
	}
	for id in esperado:
		var e: Array = esperado[id]
		var w = await mundo_do_mapa(id)
		var dir = w.combate.diretor
		ok(absf(dir.tempo_mult - float(e[0])) < 0.0001, "%s: tempo_mult %s (era %s)" % [id, dir.tempo_mult, e[0]])
		ok(dir.niveis_total == int(e[1]), "%s: %d níveis (%d)" % [id, int(e[1]), dir.niveis_total])
		ok(absf(dir.duracao_nivel - float(e[2])) < 0.0001, "%s: %s s por nível" % [id, dir.duracao_nivel])
		var ultimo: Dictionary = dir.chefes_mapa[-1]
		ok(ultimo.nivel == dir.niveis_total and not bool(ultimo.mk.mini), "%s: o chefão está no último nível" % id)
		ok(absf(float(ultimo.mk.vida) - float(e[3])) < 0.5, "%s: vida do chefão %s (esperado %s)" % [id, ultimo.mk.vida, e[3]])
		w.queue_free()
		await get_tree().process_frame

	# 2. Floresta (fator 1,0): taxa, teto, vida, e a onda forte no tempo da partida
	var f = await mundo_do_mapa("floresta")
	var df = f.combate.diretor
	ok(absf(df.relogio() - 0.0) < 0.001, "Floresta: o relógio começa em 0")
	f.tempo_partida = 100.0
	ok(absf(df.relogio() - 100.0) < 0.001, "Floresta: o relógio é o tempo da partida (100 s)")
	var taxas_f := []
	var limites_f := []
	for t in TEMPOS:
		taxas_f.append(df.taxa(float(t) * 1.4))
		limites_f.append(df.limite(float(t) * 1.4))
	f.tempo_partida = 140.0
	df.nascer("inimigo_cao_ossos")
	var vida_f_140: float = f.monstros.back().vida_max
	f.tempo_partida = 100.0
	df.nascer("inimigo_cao_ossos")
	var vida_f_100: float = f.monstros.back().vida_max
	df.ligado = true
	df.proxima_onda = 60.0
	f.tempo_partida = 59.5
	df.atualizar(0.0)
	ok(df.ondas == 0, "Floresta: a onda forte ainda não veio aos 59,5 s")
	f.tempo_partida = 60.5
	df.atualizar(0.0)
	ok(df.ondas == 1, "Floresta: a onda forte vem aos 60 s reais")
	df.ligado = false
	f.queue_free()
	await get_tree().process_frame

	# 3. Ruínas (fator 1,4): a curva é a da Floresta no tempo multiplicado
	var m = await mundo_do_mapa("medio")
	var dm = m.combate.diretor
	m.tempo_partida = 100.0
	ok(absf(dm.relogio() - 140.0) < 0.001, "Ruínas: aos 100 s reais o relógio do diretor marca 140 s")
	for i in TEMPOS.size():
		var t: float = float(TEMPOS[i])
		ok(absf(dm.taxa(t) - taxas_f[i]) < 0.0001, "taxa das Ruínas aos %s s = a da Floresta aos %s s (%.3f x %.3f)" % [t, t * 1.4, dm.taxa(t), taxas_f[i]])
		ok(dm.limite(t) == limites_f[i], "teto de vivos das Ruínas aos %s s = o da Floresta aos %s s (%d x %d)" % [t, t * 1.4, dm.limite(t), limites_f[i]])
	dm.nascer("inimigo_cao_ossos")
	var vida_m_100: float = m.monstros.back().vida_max
	ok(absf(vida_m_100 - vida_f_140) < 0.01, "vida de um monstro das Ruínas aos 100 s = a da Floresta aos 140 s (%.3f x %.3f)" % [vida_m_100, vida_f_140])
	ok(absf(vida_m_100 - vida_f_100) > 0.01, "e a vida muda com o relógio: as Ruínas aos 100 s não são a Floresta aos 100 s")

	# 4. a onda forte das Ruínas vem aos 60 s do relógio do diretor, ou seja ~42,9 s reais
	dm.ligado = true
	dm.proxima_onda = 60.0
	m.tempo_partida = 60.0 / 1.4 - 0.5
	dm.atualizar(0.0)
	ok(dm.ondas == 0, "Ruínas: a onda forte ainda não veio aos %.1f s reais" % m.tempo_partida)
	m.tempo_partida = 60.0 / 1.4 + 0.5
	dm.atualizar(0.0)
	ok(dm.ondas == 1, "Ruínas: a onda forte vem aos 60 s do relógio (~42,9 s reais)")
	dm.ligado = false
	m.queue_free()
	await get_tree().process_frame

	print("v2_tempo_mult falhas=%d" % falhas)
	get_tree().quit()
