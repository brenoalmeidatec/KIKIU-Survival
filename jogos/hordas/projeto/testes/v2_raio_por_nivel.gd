extends Node
# Teste do CRESCIMENTO POR NÍVEL do alcance do golpe (katana) e do raio do escudo (v2/combate.gd alcance_do_passo, v2/progresso.gd
# bonus_por_nivel e bonus_nivel_golpe, v2/escudo.gd raio, arco e pontos_do_arco, v2/adagas.gd lancar; dados/v2_combate.json > golpe.raio_por_nivel e dados/v2_secundario.json >
# escudo.raio_por_nivel e arco_por_nivel): nível 1 igual ao de antes, cresce por nível e para no teto, o golpe soma com a área do herói
# (h.m_area) sem duplicar e o escudo não usa a área, o arco do golpe não muda com o nível, o acerto (golpear) e o desenho (fx.corte) crescem
# juntos, o escudo cresce em COBERTURA (arco do bloqueio, `cobre`) e o desenho (pontos_do_arco) acompanha, as adagas do golpe crescem e as do
# especial Q não, e o nível lido é o de quem golpeia (co-op). O mundo anda em passos fixos de 1/60 s.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_raio_por_nivel.tscn  (imprime "v2_raio_por_nivel falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Progresso := preload("res://v2/progresso.gd")
const Heroi := preload("res://v2/heroi.gd")
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func perto(a: float, b: float) -> bool:
	return absf(a - b) <= 0.001


## Um monstro parado a `d` px do centro do golpe, na frente do herói: quantos o golpe do jogo acerta. O monstro é tirado da conta depois.
func acertos_a(h, passo: Dictionary, d: float) -> int:
	var origem: Vector2 = h.pos + Heroi.ORIGEM_GOLPE
	var m = w.nascer_monstro("inimigo_cao_ossos", origem + Vector2(d, 6.0))  # o golpe mede até o tronco (y - 6): o corpo fica em (d, 0)
	m.vida = 5000.0
	m.vida_max = 5000.0
	m.cacador = false
	m.raio_vaga = 0.0
	m.atordoa_t = 0.0
	m.emp = Vector2.ZERO
	var n: int = w.combate.golpear(h, origem, Vector2(1, 0), passo, 0)
	m.morrendo = true  # golpear pula quem está morrendo: o monstro não conta no próximo teste
	return n


## A escala do desenho do corte que o golpe acabou de criar (fx.corte guarda um Sprite2D por corte, no índice `_ci`).
func escala_do_corte(h, passo: Dictionary) -> float:
	var fx = w.combate.fx
	var i: int = fx._ci
	w.combate.golpe_comecou(h, passo, Vector2(1, 0), 0.26)
	return fx._cortes[i].scale.x


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = true
	h.m_area = 1.0
	var c = w.combate
	var esc = c.escudo
	var passos: Array = c.cfg.golpe.passos
	var corte: Dictionary = passos[0]
	var ultimo: Dictionary = passos[passos.size() - 1]  # a estocada: o alcance maior

	# 1. dados: as duas regras estão nos dados (golpe e escudo)
	var dc: Dictionary = Dados.json("v2_combate").golpe.raio_por_nivel
	ok(perto(float(dc.por_nivel), 0.015) and perto(float(dc.teto), 0.4), "v2_combate.json > golpe.raio_por_nivel: 1,5% por nível e teto de 40%")
	var de: Dictionary = Dados.json("v2_secundario").escudo.raio_por_nivel
	ok(perto(float(de.por_nivel), 0.01) and perto(float(de.teto), 0.3), "v2_secundario.json > escudo.raio_por_nivel: 1% por nível e teto de 30%")

	# 2. a regra: nível 1 sem bônus, sobe por nível, para no teto e não passa dele
	ok(Progresso.bonus_por_nivel(1, dc) == 0.0, "nível 1 não ganha bônus")
	ok(perto(Progresso.bonus_por_nivel(20, dc), 0.285), "nível 20: 19 níveis x 1,5% = 28,5%")
	ok(perto(Progresso.bonus_por_nivel(27, dc), 0.39), "nível 27 ainda não bateu o teto (26 x 1,5% = 39%)")
	ok(perto(Progresso.bonus_por_nivel(28, dc), 0.4), "nível 28 bate o teto de 40%")
	ok(perto(Progresso.bonus_por_nivel(500, dc), 0.4), "nível 500 fica no teto de 40%")
	var anterior := -1.0
	var sobe := true
	for n in range(1, 61):
		var b: float = Progresso.bonus_por_nivel(n, dc)
		sobe = sobe and b >= anterior
		anterior = b
	ok(sobe, "o bônus nunca cai com o nível (1 a 60)")

	# 3. o alcance do golpe no jogo: nível 1 = o do dado; nível 20 = +28,5%; teto de +40%
	h.nivel = 1
	var a1: float = c.alcance_do_passo(corte)
	ok(perto(a1, float(corte.alcance)), "nível 1: o alcance do golpe é o do dado (%s px), sem bônus" % corte.alcance)
	h.nivel = 20
	var a20: float = c.alcance_do_passo(corte)
	ok(perto(a20, float(corte.alcance) * 1.285), "nível 20: o alcance do dado x 1,285 (%.2f px)" % a20)
	ok(a20 > a1, "o alcance cresce do nível 1 para o 20")
	h.nivel = 500
	ok(perto(c.alcance_do_passo(ultimo), float(ultimo.alcance) * 1.4), "nível 500: o alcance para no teto (x1,4)")

	# 4. soma com a área das cartas (h.m_area) sem duplicar: 1,2 + 0,285 e não 1,2 x 1,285
	h.nivel = 20
	h.m_area = 1.2
	ok(perto(c.alcance_do_passo(corte), float(corte.alcance) * 1.485), "área 1,2 e nível 20 somam (x1,485), não multiplicam (x1,542)")
	h.m_area = 1.0

	# 5. o arco não muda com o nível (o cone do acerto continua o mesmo)
	h.nivel = 1
	var arco1: float = c.arco_do_passo(corte)
	h.nivel = 20
	ok(perto(c.arco_do_passo(corte), arco1), "o arco do golpe não muda com o nível")

	# 6. o card de status lê o alcance que o golpe usa (alcance mais o avanço)
	ok(perto(c.alcance_efetivo_do_passo(corte), c.alcance_do_passo(corte) + float(corte.get("avanco", 0.0))), "o card de status mostra o alcance crescido")

	# 7. acerto: um monstro 10 px além do alcance do dado não é atingido no nível 1, e é no nível 20 (o acerto usa o mesmo alcance)
	h.nivel = 1
	ok(acertos_a(h, corte, float(corte.alcance) + 10.0) == 0, "nível 1: monstro a 10 px além do alcance do dado não é acertado")
	h.nivel = 20
	ok(acertos_a(h, corte, float(corte.alcance) + 10.0) == 1, "nível 20: o mesmo monstro (dentro do alcance crescido) é acertado")

	# 8. desenho: a escala do corte cresce na mesma proporção que o alcance (o visual bate com a área de acerto)
	h.nivel = 1
	var e1 := escala_do_corte(h, corte)
	var alc1: float = c.alcance_do_passo(corte)
	h.nivel = 20
	var e20 := escala_do_corte(h, corte)
	var alc20: float = c.alcance_do_passo(corte)
	ok(e1 > 0.0 and perto(e20 / e1, alc20 / alc1), "o desenho do corte cresce como o alcance (razão %.4f e %.4f)" % [e20 / e1, alc20 / alc1])

	# 9. escudo, o raio: o do dado no nível 1 (IGUAL ao de antes, mesmo com área de cartas), cresce por nível, para no teto, e NÃO usa h.m_area
	var raio0: float = float(esc.cfg.raio)
	h.m_area = 1.0
	h.nivel = 1
	ok(perto(esc.raio(h), raio0), "escudo nível 1: o raio do dado (%s px)" % raio0)
	h.m_area = 1.2
	ok(perto(esc.raio(h), raio0), "escudo nível 1 com área 1,2 (Nicão): o raio continua o do dado, a área das cartas não entra")
	h.nivel = 20
	ok(perto(esc.raio(h), raio0 * 1.19), "escudo nível 20: raio x 1,19 mesmo com área 1,2 (%.2f px)" % esc.raio(h))
	h.m_area = 1.0
	h.nivel = 500
	ok(perto(esc.raio(h), raio0 * 1.3), "escudo nível 500: o raio para no teto (x1,3)")

	# 10. escudo, a COBERTURA: o arco de bloqueio cresce 1 grau por nível até +25, e o que é desenhado (pontos_do_arco) acompanha raio e arco.
	# Os números esperados saem dos DADOS e do nível, não das funções raio/arco do escudo: desfazer o uso delas no desenho faz isto falhar.
	var arco0: float = float(esc.cfg.arco)
	var da: Dictionary = Dados.json("v2_secundario").escudo.arco_por_nivel
	ok(perto(float(da.por_nivel), 1.0) and perto(float(da.teto), 25.0), "v2_secundario.json > escudo.arco_por_nivel: 1 grau por nível e teto de 25")
	h.dir_olhar = Vector2(1, 0)
	h.m_area = 1.0
	for caso in [[1, 0.0], [20, 19.0], [500, 25.0]]:
		h.nivel = caso[0]
		var cc: Vector2 = h.pos + Vector2(0, -8)
		var pts: PackedVector2Array = esc.pontos_do_arco(h)
		var esp_raio: float = raio0 * (1.0 + minf(float(caso[0] - 1) * 0.01, 0.3))
		var esp_arco: float = arco0 + float(caso[1])
		var no_chao := PackedVector2Array()
		for q in pts:
			no_chao.append(Vector2(q.x - cc.x, (q.y - cc.y) / esc.ACHATA))
		var raios_ok := true
		for q in no_chao:
			raios_ok = raios_ok and perto(q.length(), esp_raio)
		ok(raios_ok, "nível %d: todo ponto desenhado do escudo está a %.2f px do corpo (raio)" % [caso[0], esp_raio])
		var aberto := rad_to_deg(absf(no_chao[0].angle_to(no_chao[no_chao.size() - 1])))
		ok(perto(aberto, esp_arco), "nível %d: o escudo desenhado abre %.1f graus (visto %.2f)" % [caso[0], esp_arco, aberto])

	# 11. o bloqueio: a cobertura cresce com o arco. A 68 graus da mira: fora do arco no nível 1 (60 de cada lado), dentro no 20 (69,5)
	var a68: Vector2 = Vector2.from_angle(deg_to_rad(68.0)) * 100.0
	var de68: Vector2 = h.pos + Vector2(a68.x, a68.y * esc.ACHATA)
	h.nivel = 1
	ok(esc.cobre(h, h.pos + Vector2(100, 0)), "bloqueio da frente: barra no nível 1")
	ok(not esc.cobre(h, h.pos + Vector2(-100, 0)), "bloqueio das costas: não barra no nível 1")
	ok(not esc.cobre(h, de68), "nível 1: o que vem a 68 graus da mira passa (o arco é de 120)")
	h.nivel = 20
	ok(esc.cobre(h, h.pos + Vector2(100, 0)), "bloqueio da frente: barra no nível 20")
	ok(not esc.cobre(h, h.pos + Vector2(-100, 0)), "bloqueio das costas: não barra no nível 20")
	ok(esc.cobre(h, de68), "nível 20: o que vem a 68 graus da mira é barrado (o arco é de 139)")
	ok(not esc.cobre(h, h.pos + Vector2.from_angle(deg_to_rad(71.0)) * Vector2(100, 100 * esc.ACHATA)), "nível 20: a 71 graus ainda passa (a borda é 69,5)")
	h.nivel = 500
	ok(perto(float(esc.resumo().arco), arco0 + 25.0), "o painel de status lê o arco crescido (teto +25 graus)")

	# 12. as adagas do Lucas: o golpe cresce com o nível (mesmo ponto central, combate.bonus_nivel_golpe), o especial Q (lancar sem a marca) não
	var adaga := {
		"tipo": "adagas",
		"nome": "adaga",
		"n": 1,
		"leque": 0.0,
		"vel": 300.0,
		"alcance": 200.0,
		"dano": 5.0,
		"empurrao": 0.0,
		"atordoa": 0.0,
		"cor": [1.0, 1.0, 1.0]
	}
	var mira := 1.0 + float(c.armas.mods.mira) / 100.0
	h.m_area = 1.0
	for nv in [1, 20, 500]:
		h.nivel = nv
		var bonus := minf(float(nv - 1) * 0.015, 0.4)
		c.adagas.limpar()
		c.golpear(h, h.pos + Heroi.ORIGEM_GOLPE, Vector2(1, 0), adaga, 0)
		ok(
			perto(maxf(c.adagas.a_rest[0], 0.0), 200.0 * mira * (1.0 + bonus)),
			"nível %d: a adaga do golpe voa %.1f px (x%.3f)" % [nv, 200.0 * mira * (1.0 + bonus), 1.0 + bonus]
		)
		c.adagas.limpar()
		c.adagas.lancar(h, h.pos + Heroi.ORIGEM_GOLPE, Vector2(1, 0), adaga)  # o especial Q chama assim
		ok(perto(maxf(c.adagas.a_rest[0], 0.0), 200.0 * mira), "nível %d: a adaga do especial Q não cresce (%.1f px)" % [nv, 200.0 * mira])
	c.adagas.limpar()

	# 13. co-op: o golpe lê o nível de quem golpeia (h), não o do herói do mundo
	h.nivel = 1
	var outro := Heroi.new()
	outro.m_area = 1.0
	outro.nivel = 20
	ok(perto(c.alcance_do_passo(corte, outro), float(corte.alcance) * 1.285), "alcance_do_passo(passo, outro herói): usa o nível e a área dele (x1,285)")
	ok(perto(c.alcance_do_passo(corte), float(corte.alcance)), "alcance_do_passo(passo) sem herói: o do mundo (nível 1)")

	print("v2_raio_por_nivel falhas=%d" % falhas)
	get_tree().quit()
