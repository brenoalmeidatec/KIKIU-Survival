extends "res://testes/isolamento_v2.gd"
## A Maré em todo mapa e herói (ULT-C): matriz de ondas 1..20 sem nó novo no pool e com vivos <= teto. Separado do v2_mare_sangue para cada cena caber nos 120 s do CI.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const Meta := preload("res://v2/meta.gd")
var falhas := 0
var w


func ok(cond: bool, texto: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", texto)


func _novo(heroi: String, mapa: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = heroi
	w = Mundo.instantiate()
	w.id_mapa = mapa
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.combate.diretor.ligado = false
	w.combate.diretor.tempo_mult = 1.0  # este teste mede a Maré no relógio da partida; o fator por mapa (ECO-1) é o de testes/v2_tempo_mult
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.definir_pos(w.mapa.get_center())
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	w.cam.cravar(w.heroi.centro())
	for m in w.monstros.duplicate():
		m.vivo = false
		w.devolver_monstro(m)
	w.heroi.esp_carga = w.heroi.esp_carga_max


func _limpar_monstros() -> void:
	for m in w.monstros.duplicate():
		m.vivo = false
		w.devolver_monstro(m)
	w.combate.diretor.mare_pendente = 0
	w.combate.diretor.mare_t = -1.0


## A matriz do pool (ULT-C): 4 mapas x 3 heróis x {Difícil + Pesadelo, Fácil} x ondas 1 a 20. Cada onda é a Maré inteira (os dois
## pulsos), no relógio da própria onda (minuto k), e os monstros NÃO são limpos entre as ondas: o campo acumula até o teto, como numa partida de
## verdade. Mede o pico de vivos de cada tipo e exige: vivos <= teto, nenhum nó novo na partida e pico de cada tipo <= o pool dele (v2_combate.json).
func _matriz() -> void:
	var mapas := ["floresta", "laboratorio", "cidade", "medio"]
	var herois := ["hazaki", "nicao", "lucas"]
	# O pico do Difícil+Pesadelo (164) cobre o do Difícil puro (126). Um mundo por (mapa, herói) serve aos dois modos (criar o mundo é o custo do teste, e o
	# CI dá 120 s por cena): o mais pesado vem primeiro, então o pool é medido no pior caso, e os monstros voltam ao pool entre um modo e o outro.
	var modos := [["dificil", true], ["facil", false]]
	var pool: Dictionary = {}
	for mapa in mapas:
		for heroi in herois:
			await _novo(heroi, mapa)
			pool = w.combate.cfg.pool
			for modo in modos:
				_limpar_monstros()
				w.meta_bonus = w.meta_bonus.duplicate()
				w.meta_bonus["dificuldade"] = Dificuldade.regras(str(modo[0]))
				w.meta_bonus.erase("pesadelo")
				if modo[1]:
					w.meta_bonus["pesadelo"] = Meta.regras_pesadelo()
				var d = w.combate.diretor
				d.ligado = true
				d.proxima_onda = 1.0e9
				d.acum = -1000.0
				var nos0: int = w._todos_monstros.size()
				var pico := 0
				var pico_tipo := {}
				var tag := "%s/%s/%s%s" % [mapa, heroi, modo[0], "+pesadelo" if modo[1] else ""]
				for k in range(1, 21):
					w.tempo_partida = 60.0 * k
					d.ondas = k - 1
					d.onda_forte()
					d.atualizar(1.1)
					var vivos: int = w.monstros.size()
					pico = maxi(pico, vivos)
					ok(vivos <= d.teto(), "%s onda %d: vivos %d <= teto %d" % [tag, k, vivos, d.teto()])
					ok(vivos > 0, "%s onda %d: a Maré põe monstros em campo" % [tag, k])
					var por_tipo := {}
					for m in w.monstros:
						por_tipo[m.chave] = int(por_tipo.get(m.chave, 0)) + 1
					for t in por_tipo:
						pico_tipo[t] = maxi(int(pico_tipo.get(t, 0)), int(por_tipo[t]))
				ok(w._todos_monstros.size() == nos0, "%s: nenhum nó novo (pico %d, nós %d -> %d)" % [tag, pico, nos0, w._todos_monstros.size()])
				for t in pico_tipo:
					ok(int(pico_tipo[t]) <= int(pool.get(t, 0)), "%s: pico de %s = %d cabe no pool %d" % [tag, t, pico_tipo[t], int(pool.get(t, 0))])
				print("MEDIDO %s pico_total=%d tipos=%s" % [tag, pico, pico_tipo])
	_limpar_monstros()


func _ready() -> void:
	await _matriz()
	Herois.forcado = ""
	if w != null:
		w.queue_free()
	await get_tree().process_frame
	print("v2_mare_matriz falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)
