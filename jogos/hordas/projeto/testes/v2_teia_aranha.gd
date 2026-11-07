extends "res://testes/isolamento_v2.gd"
# Teste da ARANHA ATIRADORA (v2/monstro.gd _teia_ia, v2/teias.gd disparar, dados/v2_teia.json > aranha, a folha da aranha com as colunas disparo0..3). Confere: a folha tem a ação
# (andar0..3 + disparo0..3) e o monstro lê n_col = 4 e col_acao = 4; a aranha com a flag, em alcance e com recarga 0, percorre preparo, disparo e recuperação (parada, nas colunas
# disparo0..3) e gera UMA bolota que pousa onde o herói estava; recarga sorteada depois; sem a flag, longe demais, perto demais, fora da tela, atordoada ou numa folha sem ação ela
# não atira; golpe no preparo cancela o tiro; no máximo max_voando bolotas.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_teia_aranha.tscn  (imprime "v2_teia_aranha falhas=0")

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
const PASSO := 1.0 / 60.0
const TIPO := {"id": "t", "liso": true, "teia": true}

var falhas := 0
var w
var h


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	Colisao.limpar()
	h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.pos = w.limite_andavel.get_center()
	h.definir_pos(h.pos)
	passos(3)


func aranha(dist: float, tipo := TIPO, sprite := "inimigo_aranha_tecela"):
	var m = w.nascer_monstro(sprite, h.pos + Vector2(dist, 0), false, 1.0, 1.0, tipo)
	m._teia_cd = 0.0
	m.vida_max = 9999.0
	m.vida = 9999.0
	m.recarga = 9999.0
	m.persegue = false
	m._espera = 999.0
	return m


func _ready() -> void:
	Herois.forcado = "hazaki"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	var t = w.combate.teias
	var a: Dictionary = t.aranha

	# 1. a folha: andar0..3 e disparo0..3
	var info: Dictionary = w.sprites.tipo("inimigo_aranha_tecela").info
	ok(
		(info.colunas as Array).size() == 8 and str(info.colunas[4]) == "disparo0" and str(info.colunas[7]) == "disparo3",
		"a folha tem andar0..3 e disparo0..3: %s" % str(info.colunas)
	)
	var m0 = aranha(150.0)
	ok(m0.n_col == 4 and m0.col_acao == 4, "o monstro lê 4 colunas de andar e a ação na coluna 4 (%d, %d)" % [m0.n_col, m0.col_acao])
	ok(m0.teia, "nasceu com a flag teia")
	var x3: Dictionary = w.sprites.tipo("inimigo_aranha_tecela_x3").info
	ok(not (x3.colunas as Array).has("disparo0"), "a folha x3 (chefe) não tem ação: a aranha grande não atira")

	# 2. o ciclo completo: preparo -> disparo -> recuperação, parada, uma bolota
	m0.pos = h.pos + Vector2(150, 0)
	m0.definir_pos(m0.pos)
	var fases: Array = []
	var colunas: Array = []
	var pos0: Vector2 = m0.pos
	var pos_ini := Vector2.ZERO
	var pos_fim := Vector2.ZERO
	var bolotas := 0
	for q in 120:
		passos(1)
		if fases.is_empty() or fases[-1] != m0._teia_fase:
			fases.append(m0._teia_fase)
			if m0._teia_fase == 1:
				pos_ini = m0.pos
		if m0._teia_fase > 0:
			pos_fim = m0.pos
		if m0._teia_fase > 0:
			colunas.append(m0.coluna)
		bolotas = maxi(bolotas, t.lancadas)
	ok(fases.slice(0, 5) == [0, 1, 2, 3, 0], "as fases são livre, preparo, disparo, recuperação, livre: %s" % str(fases))
	ok(t.lancadas == 1, "saiu UMA bolota (%d)" % t.lancadas)
	ok(pos_ini.distance_to(pos_fim) < 3.0, "a aranha ficou parada enquanto atirava (andou %.1f px)" % pos_ini.distance_to(pos_fim))
	var cols_vistas := {}
	for c in colunas:
		cols_vistas[c] = true
	ok(cols_vistas.size() == 0 or cols_vistas.keys().all(func(c): return c >= 4), "enquanto atira, mostra só as colunas disparo*: %s" % str(cols_vistas.keys()))
	ok(m0._teia_cd >= float(a.recarga[0]) - 2.0, "depois do tiro, recarga de %.1f s" % m0._teia_cd)
	# pousa onde o herói estava (parado): perto do herói
	passos(60)
	var i: int = t._est.find(t.ABRINDO) if t._est.find(t.ABRINDO) >= 0 else t._est.find(t.PARADA)
	ok(i >= 0 and t._pos[i].distance_to(h.pos) < 3.0, "a bolota pousou no herói parado (%.1f px)" % (t._pos[i].distance_to(h.pos) if i >= 0 else -1.0))

	# 3. quem não atira
	zerar()
	var l0: int = t.lancadas
	var sem_flag = aranha(150.0, {"id": "x", "liso": true})
	var longe = aranha(float(a.dist_max) + 40.0)
	var perto = aranha(float(a.dist_min) - 40.0)
	var tonta = aranha(150.0)
	tonta.atordoa_t = 10.0
	var cao = w.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(0, 150), false, 1.0, 1.0, TIPO)
	cao._teia_cd = 0.0
	ok(not cao.teia, "o cão com a flag no tipo não atira: a folha dele não tem a ação (col_acao %d)" % cao.col_acao)
	for m in [sem_flag, longe, perto, cao]:
		m.atordoa_t = 0.0
	passos(2)
	for m in [sem_flag, longe, perto, tonta]:
		m.pos.y = h.pos.y
	for m in [sem_flag, longe, perto, tonta, cao]:
		m.vel_caca = 0.0
	passos(100)
	ok(t.lancadas == l0, "sem flag, longe demais, perto demais, atordoada ou numa folha sem ação: ninguém atira (%d)" % (t.lancadas - l0))
	ok(sem_flag._teia_fase == 0 and longe._teia_fase == 0 and perto._teia_fase == 0 and tonta._teia_fase == 0, "e ninguém entrou em fase de tiro")

	# 4. fora da tela não atira
	zerar()
	var fora = aranha(150.0)
	fora.ativo = false
	fora.pos = h.pos + Vector2(150, 0)
	# o monstro fora da tela: a horda o desativa; forçamos o mesmo caminho da IA
	fora._ia(PASSO, h.pos)
	ok(fora._teia_fase == 0, "monstro fora da tela (ativo=false) não começa o tiro")

	# 5. golpe no preparo cancela o tiro
	zerar()
	var m5 = aranha(150.0)
	var n_ant: int = t.lancadas
	var q5 := 0
	while m5._teia_fase != 1 and q5 < 30:
		passos(1)
		q5 += 1
	ok(m5._teia_fase == 1, "entrou no preparo")
	m5.apanhar(1.0, Vector2.ZERO, 0.0)
	ok(m5._teia_fase == 0 and m5._teia_cd > 0.0, "o golpe cancela o preparo e pede recarga")
	passos(40)
	ok(t.lancadas == n_ant, "sem tiro depois do golpe no preparo")

	# 6. teto de bolotas no ar
	zerar()
	for k in 10:
		t.lancar(h.pos + Vector2(-100, 0), 8.0, h.pos)
	ok(t.contar(t.VOANDO) == t.max_voando and not t.pode_lancar(), "no máximo %d bolotas no ar" % t.max_voando)
	print("v2_teia_aranha falhas=%d" % falhas)
	get_tree().quit()
