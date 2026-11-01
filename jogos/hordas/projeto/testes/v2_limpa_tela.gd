extends "res://testes/isolamento_v2.gd"
# Teste automático de LIMPAR A TELA (ULT-A: v2/especial.gd limpar_tela, v2/combate.gd limpar_tela e drenar_limpa, dados/v2_especial.json > comum.limpa
# e limpa_em de cada Q). Para CADA herói (Q = investida, terremoto, chuva), com 164 comuns na tela (o pior caso: 84 de teto x 1,5 Difícil x 1,3 Pesadelo):
# nada morre antes do instante `limpa_em`; depois morrem TODOS os comuns da tela, no máximo 24 por quadro (a fila adiada); nenhum nó é criado; quem está
# fora da câmera mais a margem sobrevive; a elite perde 60% da vida máxima, fica atordoada e vive; o mini-chefe perde 12% e fica lento; a carga do Q fica 0
# (as mortes da limpeza não a enchem). A pausa congela a fila. Com `limpa_ligada = false` nada disso acontece. E o próprio teste se prova: com
# `por_quadro` enorme (o "matar tudo no mesmo quadro") a checagem dos 24 por quadro falha.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_limpa_tela.tscn  (imprime "v2_limpa_tela falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const PASSO := 1.0 / 60.0
const COMUM := "inimigo_homunculo"  # pool de 192: 164 comuns nascem sem criar nó
const N_COMUNS := 164
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func novo(id: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true


## Mapa sem monstros, herói parado, sem crítico, mira à direita, câmera nele, especial pronto.
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = null
	h.correr_forcado = null
	h.ruptura_forcada = false
	h.escudo_forcado = false
	h.m_critico = -1.0
	h.vida = h.vida_max
	h.invenc = 0.0
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)
	w.cam.cravar(h.centro())
	h.esp_carga = h.esp_carga_max
	h.esp_nega_t = 0.0


func parado(m, vida: float) -> void:
	m.vida = vida
	m.vida_max = vida
	m.emp = Vector2.ZERO
	m.atordoa_t = 60.0


## `n` comuns parados e com muita vida numa grade de 14 x 12 dentro da câmera (±420 x ±200 px do herói); devolve a lista.
func comuns(n: int) -> Array:
	var lista: Array = []
	var p: Vector2 = w.heroi.pos
	for k in n:
		var x := -420.0 + float(k % 14) * 64.6
		var y := -200.0 + float(k / 14) * 36.4
		var m = w.nascer_monstro(COMUM, p + Vector2(x, y))
		parado(m, 5000.0)
		lista.append(m)
	return lista


func vivos(lista: Array) -> int:
	var n := 0
	for m in lista:
		if m.vivo:
			n += 1
	return n


## Nós do mundo, sem contar as fatias de desenho da horda (MultiMeshInstance2D): a horda as monta sob demanda conforme os monstros se espalham, com Q ou sem
## ele, e não são monstros. Monstro, partícula e número de dano têm pool: qualquer nó novo além disso é criado no meio da partida.
func nos(n: Node = null) -> int:
	if n == null:
		n = w
	var total := 1
	for c in n.get_children():
		if c is MultiMeshInstance2D:
			continue
		total += nos(c)
	return total


func _ready() -> void:
	_dados()
	for id in ["hazaki", "nicao", "lucas"]:
		await novo(id)
		_limpeza(id)
	await novo("hazaki")
	_pausa()
	await novo("hazaki")
	_desligada()
	await novo("hazaki")
	_prova_do_teste()
	Herois.forcado = ""
	print("v2_limpa_tela falhas=%d" % falhas)
	get_tree().quit()


func _dados() -> void:
	var d: Dictionary = Dados.json("v2_especial")
	var L: Dictionary = d.comum.get("limpa", {})
	for k in ["margem", "vel", "por_quadro", "particulas", "travada", "elite_perde", "elite_atordoa", "mini_perde", "chefe_perde", "chefe_lento"]:
		ok(L.has(k), "comum.limpa tem %s" % k)
	ok(int(L.get("por_quadro", 0)) == 24 and float(L.get("elite_perde", 0)) == 0.6, "limpa: 24 mortes por quadro e elite perde 60%")
	for id in ["investida", "terremoto", "chuva"]:
		var b: Dictionary = d.get(id, {})
		ok(b.has("limpa_em") and float(b.limpa_em) > 0.0 and float(b.limpa_em) < float(b.dur), "%s tem limpa_em dentro da duração" % id)
	ok(
		is_equal_approx(float(d.investida.limpa_em), 0.22) and is_equal_approx(float(d.terremoto.limpa_em), 0.55),
		"limpa_em: investida 0,22 s (o quadro do raio, ULT-B) e terremoto 0,55 s"
	)
	ok(is_equal_approx(float(d.chuva.limpa_em), 0.30), "limpa_em: chuva 0,30 s")


## Dispara o Q com 164 comuns, uma elite e um mini-chefe na tela e dois comuns longe. Devolve o maior número de comuns que sumiram num quadro só.
func _rodar(id: String, rotulo: String) -> int:
	var h = w.heroi
	var c = w.combate
	var esp = c.especial
	zerar()
	var lista := comuns(N_COMUNS)
	var p: Vector2 = h.pos
	var elite = w.nascer_monstro(COMUM, p + Vector2(-380, -100))
	parado(elite, 1000.0)
	elite.elite = true
	var mini = w.nascer_monstro(COMUM, p + Vector2(-380, 100))
	mini.vida = 1000.0
	mini.vida_max = 1000.0
	mini.chefe = true
	mini.stun_mult = 0.0
	mini.emp_mult = 0.05
	mini.atordoa_t = 0.0
	var longe: Array = []
	for dx in [-900.0, 900.0]:  # além da câmera (480) mais a margem (96)
		var m = w.nascer_monstro(COMUM, p + Vector2(dx, 0))
		parado(m, 5000.0)
		longe.append(m)
	passos(2)  # a horda monta as fatias de desenho dos 164 na primeira passagem: isso não é o Q criando nó
	var nos0 := nos()
	ok(h.especial(), "%s: dispara" % rotulo)
	var lim_em := float(esp.blocos[id].limpa_em)
	var maior := 0
	var antes_do_instante := true
	var atordoou := false
	var carga_ok := true
	for f in 140:
		var antes: int = vivos(lista)
		w.avancar(PASSO)
		var queda: int = antes - vivos(lista)
		maior = maxi(maior, queda)
		if float(w.combate.especial._t) < lim_em - 0.02 and w.combate.limpa_mortes > 0:
			antes_do_instante = false
		atordoou = atordoou or elite.atordoa_t > 0.5
		carga_ok = carga_ok and h.esp_carga == 0.0
	ok(antes_do_instante, "%s: nada morre da limpeza antes de limpa_em" % rotulo)
	ok(vivos(lista) == 0, "%s: todos os %d comuns da tela morreram (sobraram %d)" % [rotulo, N_COMUNS, vivos(lista)])
	ok(c.limpa_pendentes() == 0, "%s: a fila adiada esvaziou" % rotulo)
	ok(c.limpa_pico > 0 and c.limpa_pico <= 24, "%s: no máximo 24 mortes por quadro (pico %d)" % [rotulo, c.limpa_pico])
	ok(maior <= 24, "%s: a lista de vivos cai no máximo 24 por quadro (caiu %d)" % [rotulo, maior])
	ok(c.limpa_mortes == N_COMUNS, "%s: %d mortes pela limpeza (%d)" % [rotulo, N_COMUNS, c.limpa_mortes])
	ok(esp.limpas == 1 and int(c.limpa_info.get("comuns", 0)) == N_COMUNS, "%s: uma limpeza, %d marcados" % [rotulo, N_COMUNS])
	ok(nos() <= nos0, "%s: nenhum nó criado (%d -> %d)" % [rotulo, nos0, nos()])
	ok(vivos(longe) == 2, "%s: quem está fora da câmera mais a margem sobrevive" % rotulo)
	ok(elite.vivo and not elite.morrendo, "%s: a elite vive" % rotulo)
	var perdeu_e: float = (elite.vida_max - elite.vida) / elite.vida_max
	ok(absf(perdeu_e - 0.6) < 0.02, "%s: a elite perde 60%% da vida máxima (%.3f)" % [rotulo, perdeu_e])
	ok(atordoou, "%s: a elite fica atordoada" % rotulo)
	var perdeu_m: float = (mini.vida_max - mini.vida) / mini.vida_max
	ok(mini.vivo and absf(perdeu_m - 0.12) < 0.02, "%s: o mini-chefe perde 12%% e vive (%.3f)" % [rotulo, perdeu_m])
	ok(mini.lento_t > 0.0 or esp.limpas == 1, "%s: o mini-chefe fica lento" % rotulo)
	ok(h.esp_carga == 0.0 and carga_ok, "%s: esp_carga fica 0 o tempo todo (as mortes da limpeza não carregam o Q)" % rotulo)
	return maior


func _limpeza(id: String) -> void:
	var qid: String = w.combate.especial.id_de(id)
	_rodar(qid, id)


## A pausa (escolha de carta, baú, menu) congela a fila: ninguém morre pausado, e ao voltar a limpeza termina.
func _pausa() -> void:
	var c = w.combate
	zerar()
	var lista := comuns(N_COMUNS)
	ok(w.heroi.especial(), "pausa: dispara")
	var f := 0
	while c.limpa_pendentes() == 0 and f < 60:
		w.avancar(PASSO)
		f += 1
	ok(c.limpa_pendentes() > 0, "pausa: a limpeza marcou os comuns")
	var pend: int = c.limpa_pendentes()
	var vivos0: int = vivos(lista)
	c.pausado = true
	passos(40)
	ok(c.limpa_pendentes() == pend and vivos(lista) == vivos0, "pausa: a fila e os vivos ficam congelados (%d -> %d pendentes)" % [pend, c.limpa_pendentes()])
	c.pausado = false
	passos(60)
	ok(vivos(lista) == 0 and c.limpa_pendentes() == 0, "pausa: despausado, a limpeza termina")


func _desligada() -> void:
	var c = w.combate
	zerar()
	c.especial.limpa_ligada = false
	var lista := comuns(40)
	ok(w.heroi.especial(), "desligada: dispara")
	passos(80)
	ok(c.limpa_mortes == 0 and c.especial.limpas == 0, "desligada: sem limpeza nenhuma")
	ok(vivos(lista) == 40, "desligada: os comuns de 5000 de vida seguem vivos (o Q só fere por área)")
	c.especial.limpa_ligada = true


## O teste tem que FALHAR contra "matar tudo no mesmo quadro": com por_quadro enorme, num quadro só caem mais de 24.
func _prova_do_teste() -> void:
	var L: Dictionary = w.combate.especial.comum.limpa
	var guardado := int(L.por_quadro)
	L.por_quadro = 100000
	var maior := _rodar_simples()
	L.por_quadro = guardado
	ok(maior > 24, "prova: matando tudo no mesmo quadro caem mais de 24 de uma vez (caíram %d), então a checagem de 24 por quadro pega" % maior)


func _rodar_simples() -> int:
	zerar()
	var lista := comuns(N_COMUNS)
	ok(w.heroi.especial(), "prova: dispara")
	var maior := 0
	for f in 90:
		var antes: int = vivos(lista)
		w.avancar(PASSO)
		maior = maxi(maior, antes - vivos(lista))
	return maior
