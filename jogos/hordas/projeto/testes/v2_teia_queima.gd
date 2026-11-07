extends "res://testes/isolamento_v2.gd"
# Teste da QUEIMA da teia pelo mecha em voo (v2/teias.gd voando e _queimar, v2/impulso.gd, v2/mecha.gd; dados/v2_teia.json > queima). "Mecha flutuando" é o voo do impulso (Shift) do
# mecha do LightWolf, com os propulsores nas costas (v2/propulsor.gd). Confere: voando sobre a teia (a elipse mais a margem), a teia pega fogo no canto do lado do herói (bits 1 = H e 2 = V);
# sem voar (parado, andando, esquivando) nada queima; o Lobo (sem impulso) não voa e não queima; a teia em chamas não segura mais (queimando_lento false) e libera o slot ao fim da animação;
# o voo da quebra, do reiniciar e do Lobo desligam o estado.
# LABAREDAS (v2/teia_chamas.gd, as mini-animações das gotas de fogo sobre a frente de fogo da folha): nascem sobre pixels QUENTES da folha teia_queima no quadro que ela toca (conferido na imagem), 20 a 40
# vivas por teia, sobem 6 a 14 px, a cobertura de pixels quentes durante a queima fica bem acima da da folha sozinha (falha no head anterior, sem labaredas), pool fixo e nenhum nó novo, nada no perfil Baixo,
# e com "Reduzir piscadas" poucas, congeladas e nenhum pixel das labaredas troca mais de 2 vezes por segundo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_teia_queima.tscn  (imprime "v2_teia_queima falhas=0")

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
const Heroi := preload("res://v2/heroi.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const Anim := preload("res://v2/anim_golpes.gd")
const PASSO := 1.0 / 60.0
const COBERTURA_X := 2.0  # a cobertura de pixels quentes com as labaredas é no mínimo isto vezes a da folha sozinha

var falhas := 0
var w
var h
var t


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
	h.ataque_forcado = false
	h.correr_forcado = false
	h.fonte = Heroi.Fonte.MOUSE
	h.pos = w.limite_andavel.get_center()
	h.definir_pos(h.pos)
	w.mouse_forcado = h.centro() + Vector2(4000, 0)
	passos(3)


func poe_teia(p: Vector2) -> int:
	var i: int = t._livre()
	t._est[i] = t.PARADA
	t._t[i] = 0.0
	t._idade[i] = 0.0
	t._pos[i] = p
	t._geo[i] = 0
	t._var[i] = 0
	return i


func decolar() -> void:
	h.correr_forcado = true
	passos(1)
	h.correr_forcado = false


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	t = w.combate.teias
	var imp = w.combate.impulso
	ok(imp != null and imp.para(h), "o mecha tem o impulso (é o que voa)")

	# 1. parado ou andando: nada queima, e a teia segura
	var i := poe_teia(h.pos)
	passos(10)
	ok(t._est[i] == t.PARADA and t.queimadas == 0, "o mecha no chão sobre a teia não a queima")
	var q_zero: int = t.queimadas
	ok(not t.voando(h) and h.lento_fontes.has("teia"), "e ele fica preso nela")
	h.entrada_forcada = Vector2.RIGHT
	passos(5)
	h.entrada_forcada = Vector2.ZERO
	ok(t.queimadas == q_zero, "andando também não queima")

	# 2. voando sobre a teia: queima. O herói à direita e abaixo do centro: fogo nasce no canto espelhado H e V (bits 3)
	zerar()
	i = poe_teia(h.pos + Vector2(-10, -6))
	decolar()
	var q := 0
	while t._est[i] == t.PARADA and q < 90:
		passos(1)
		q += 1
	ok(t._est[i] == t.QUEIMANDO, "voando sobre a teia, ela pega fogo (%d quadros depois de decolar)" % q)
	ok(t.voando(h) and h.alt_px >= int(t.cfg.queima.alt_min_px), "o mecha estava voando, no alto (alt %d)" % h.alt_px)
	ok(t._var[i] == 3, "o mecha à direita e abaixo do centro: fogo no canto espelhado H e V (bits %d)" % t._var[i])
	ok(not h.lento_fontes.has("teia"), "voando, o mecha não fica lento")
	ok(t.queimadas == q_zero + 1, "uma teia queimada (%d)" % (t.queimadas - q_zero))

	# 3. o lado do herói escolhe o canto: ele voa para a direita e entra na teia pela esquerda, um pouco acima do centro (canto base) ou abaixo (bit V)
	zerar()
	var a := poe_teia(h.pos + Vector2(90, 8))
	decolar()
	passos(60)
	ok(t._est[a] == t.QUEIMANDO and t._var[a] == 0, "o mecha entra pela esquerda e acima do centro: fogo no canto base (bits %d)" % t._var[a])
	zerar()
	var a2 := poe_teia(h.pos + Vector2(90, -8))
	decolar()
	passos(60)
	ok(t._est[a2] == t.QUEIMANDO and t._var[a2] == 2, "entrando pela esquerda e abaixo do centro: espelha só em V (bits %d)" % t._var[a2])

	# 4. a teia em chamas não segura e a animação libera o slot
	zerar()
	var b := poe_teia(h.pos + Vector2(-70, 0))
	t._est[b] = t.QUEIMANDO
	t._t[b] = 0.0
	h.pos = t._pos[b]
	h.definir_pos(h.pos)
	passos(3)
	ok(not h.lento_fontes.has("teia"), "a teia em chamas não deixa o herói lento (queimando_lento false)")
	var dur: float = float(t._folhas.queima.quadros) / float(t._folhas.queima.fps)
	passos(int(dur * 60.0) + 3)
	ok(t._est[b] == t.LIVRE, "a queima acaba em %.2f s e libera o slot" % dur)

	# 5. a margem: o propulsor passando rente à borda acende; longe da borda não
	zerar()
	w.mouse_forcado = h.centro() + Vector2(-4000, 0)  # voa para longe da teia (3 quadros para a mira virar antes do aperto)
	passos(3)
	var c := poe_teia(h.pos + Vector2(t.raio + 20.0, 0))  # o herói a 20 px da borda (fora da elipse e da margem de 4)
	decolar()
	passos(10)
	ok(t._est[c] == t.PARADA, "o voo a 20 px da borda não queima")
	t._pos[c] = h.pos + Vector2(t.raio + 2.0, 0)
	t._heroi()  # a conta de um quadro, sem andar (o mecha segue voando)
	ok(t._est[c] == t.QUEIMANDO, "a 2 px da borda (dentro da margem de %d px) queima" % int(t.cfg.queima.margem))

	# 6. o Lobo não voa nem queima; o mecha que quebra para de voar
	zerar()
	w.combate.mecha.virar_lobo(h, 20.0)
	passos(3)
	ok(h.forma_lobo and not imp.para(h), "o Lobo não tem impulso")
	var d := poe_teia(h.pos)
	var q_ant: int = t.queimadas
	h.correr_forcado = true
	passos(30)
	h.correr_forcado = false
	ok(not t.voando(h) and t._est[d] != t.QUEIMANDO and t.queimadas == q_ant, "o Lobo não queima a teia (correr é só correr)")
	ok(h.lento_fontes.has("teia") or h.lento_k() == 1.0, "e o Lobo é lento na teia como os outros")
	zerar()
	ok(not h.forma_lobo, "reiniciar volta ao mecha")

	# 6b. LABAREDAS sobre a frente de fogo
	_labaredas()

	# 7. nada voa sem o impulso: Hazaki
	Herois.forcado = "hazaki"
	w.queue_free()
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	t = w.combate.teias
	var e := poe_teia(h.pos)
	h.correr_forcado = true
	passos(30)
	ok(not t.voando(h) and t._est[e] != t.QUEIMANDO, "outro herói correndo sobre a teia não queima (o Shift dele é correr)")
	print("v2_teia_queima falhas=%d" % falhas)
	get_tree().quit()


## É um pixel quente (laranja ou amarelo) da folha? A mesma conta de dados/v2_teia.json > chamas > quente.
func _quente(c: Color) -> bool:
	var q: Array = t.cfg.get("chamas", {}).get("quente", [200, 85, 40])  # o mesmo padrão no head sem labaredas (a prova de que o teste falha lá)
	return c.r8 >= int(q[0]) and c.g8 >= int(q[1]) and c.r8 - c.b8 >= int(q[2])


func _brasa(c: Color) -> bool:
	var b: Array = t.cfg.get("chamas", {}).get("brasa", [70, 170, 50, 45])
	return c.r8 >= int(b[0]) and c.r8 <= int(b[1]) and c.g8 <= int(b[2]) and c.b8 <= int(b[3])


func _queimar_teia(pos: Vector2, bits: int) -> int:
	var b := poe_teia(pos)
	t._est[b] = t.QUEIMANDO
	t._t[b] = 0.0
	t._var[b] = bits
	return b


func _filhos(n: Node) -> int:
	var c := n.get_child_count()
	for f in n.get_children():
		c += _filhos(f)
	return c


func _labaredas() -> void:
	zerar()
	var ch = t.get("chamas")  # null no head anterior (sem labaredas): o teste então falha nas provas abaixo, que é o que deve acontecer
	ok(ch != null, "a teia tem o módulo de labaredas (teia_chamas.gd)")
	var folha: Image = (t._folhas.queima.tex as Texture2D).get_image()
	var qw: int = int(t._folhas.queima.quadro.x)
	var qh: int = int(t._folhas.queima.quadro.y)
	var dur: float = float(t._folhas.queima.quadros) / float(t._folhas.queima.fps)
	var nos0 := _filhos(w.no_mundo)
	var tam_pool := 0
	if ch != null:
		tam_pool = ch.n_pool()
		ok(
			ch.no != null and ch.no.z_index > t.no.z_index and ch.no.z_index < 0,
			"as labaredas ficam num nó acima do chão da teia (%d) e abaixo dos monstros e do herói (%d)" % [t.no.z_index, ch.no.z_index]
		)
		ok(tam_pool == int(t.cfg.chamas.pool), "o pool é o de dados (%d)" % tam_pool)
	var b := _queimar_teia(h.pos + Vector2(-70, 0), 0)
	var linha: int = int(t._geo[b]) * 4 + int(t._var[b])
	var base: Vector2 = (t._pos[b] - t._folhas.queima.pivo).round()
	var cob_com := 0
	var cob_folha := 0
	var quadros_queima := 0
	var pico_fogo := 0
	var pico_total := 0
	var nascidas := 0
	var nascidas_ok := 0
	var ruins: Array = []
	var visto := {}  # g -> {y0, y_ult, idade}
	var subidas: Array = []
	var fagulhas := 0
	for k in int(dur * 60.0) + 90:
		passos(1)
		var vivo: bool = t._est[b] == t.QUEIMANDO
		if vivo:
			var q: int = mini(int(t._t[b] * float(t._folhas.queima.fps)), int(t._folhas.queima.quadros) - 1)
			quadros_queima += 1
			var quentes_folha := 0
			for y in qh:
				for x in qw:
					var c := folha.get_pixel(q * qw + x, linha * qh + y)
					if c.a > 0.5 and _quente(c):
						quentes_folha += 1
			cob_folha += quentes_folha
			cob_com += quentes_folha
		if ch == null:
			continue
		var fogo := 0
		var vivas := 0
		for g in ch.n_pool():
			var gt: Dictionary = ch.gota(g)
			if not gt.ativa:
				if visto.has(g):
					subidas.append(visto[g].y0 - visto[g].y_ult)
					visto.erase(g)
				continue
			vivas += 1
			if not gt.fagulha:
				fogo += 1
			if not visto.has(g):  # nasceu agora
				visto[g] = {"y0": gt.y0, "y_ult": gt.y}
				nascidas += 1
				if gt.fagulha:
					fagulhas += 1
				var bx := int(gt.x0 - base.x)
				var by := int(gt.y0 - base.y)
				var sobre := false
				if bx >= 0 and bx < qw and by >= 0 and by < qh:
					var c := folha.get_pixel(gt.q_teia * qw + bx, gt.linha * qh + by)
					sobre = c.a > 0.5 and (_brasa(c) if gt.fagulha else _quente(c))
				if sobre and bx == gt.px and by == gt.py and gt.linha == linha:
					nascidas_ok += 1
				elif ruins.size() < 4:
					ruins.append("g%d (%d,%d) q%d: sobre pixel certo %s" % [g, bx, by, gt.q_teia, str(sobre)])
			else:
				visto[g].y_ult = gt.y
		pico_fogo = maxi(pico_fogo, fogo)
		pico_total = maxi(pico_total, vivas)
		if vivo:
			var px: Dictionary = ch.pixels()
			for kk in px:
				if _quente(px[kk]):
					cob_com += 1
	print(
		(
			"labaredas: nascidas %d, sobre pixel certo %d, pico de fogo %d, pico total %d, fagulhas %d, cobertura media %.0f px (folha %.0f)"
			% [nascidas, nascidas_ok, pico_fogo, pico_total, fagulhas, float(cob_com) / maxf(quadros_queima, 1), float(cob_folha) / maxf(quadros_queima, 1)]
		)
	)
	ok(nascidas >= 30, "nasceram labaredas ao longo da frente de fogo (%d)" % nascidas)
	ok(
		nascidas_ok == nascidas and nascidas > 0,
		"toda labareda nasceu com a âncora sobre um pixel quente (brasa, se fagulha) do quadro da folha (%d de %d; %s)" % [nascidas_ok, nascidas, str(ruins)]
	)
	ok(pico_fogo >= 20 and pico_fogo <= 40, "20 a 40 labaredas vivas por teia no auge da frente (%d)" % pico_fogo)
	ok(pico_total <= 54, "com as fagulhas, no máximo 54 vivas por teia (%d)" % pico_total)
	ok(fagulhas >= 4, "depois da frente nascem fagulhas nas brasas (%d)" % fagulhas)
	var cobertura := float(cob_com) / maxf(float(cob_folha), 1.0)
	ok(cobertura >= COBERTURA_X, "a cobertura de pixels quentes durante a queima é %.1f x a da folha sozinha (mínimo %.1f)" % [cobertura, COBERTURA_X])
	var altas := 0
	for s in subidas:
		if s >= 5.0 and s <= 15.0:
			altas += 1
	ok(subidas.size() > 0 and altas * 10 >= subidas.size() * 8, "as labaredas sobem de 6 a 14 px (%d de %d entre 5 e 15)" % [altas, subidas.size()])
	ok(t._est[b] == t.LIVRE and ch != null and ch.vivas() == 0, "a teia e as labaredas acabam sozinhas (vivas %d)" % (ch.vivas() if ch != null else -1))
	ok(ch == null or ch.n_pool() == tam_pool, "o pool não cresce (%d)" % tam_pool)
	ok(_filhos(w.no_mundo) == nos0, "nenhum nó nasceu no mundo durante a queima (%d -> %d)" % [nos0, _filhos(w.no_mundo)])
	if ch == null:
		return

	# 6 teias queimando ao mesmo tempo: dentro do pool, sem nó novo
	zerar()
	for k in 6:
		_queimar_teia(h.pos + Vector2(-190 + 70 * (k % 3), -60 + 120 * (k / 3)), k % 4)
	var pico6 := 0
	for k in 60:
		passos(1)
		pico6 = maxi(pico6, ch.vivas())
	ok(pico6 > 60 and pico6 <= ch.n_pool(), "6 teias queimando juntas: %d labaredas, dentro do pool de %d" % [pico6, ch.n_pool()])
	passos(120)
	ok(ch.vivas() == 0, "tudo acaba (%d vivas)" % ch.vivas())

	# perfil Baixo: só a folha
	zerar()
	Anim.suave = false
	_queimar_teia(h.pos + Vector2(-70, 0), 0)
	passos(30)
	ok(ch.vivas() == 0, "perfil Baixo: nenhuma labareda (%d)" % ch.vivas())
	Anim.suave = true

	# Reduzir piscadas: poucas, congeladas, e nenhum pixel das labaredas troca mais de 2 vezes por segundo
	zerar()
	Config.temporario(Piscadas.OPCAO, true)
	_queimar_teia(h.pos + Vector2(-70, 0), 0)
	var hist := {}
	var ant := {}
	var pico_c := 0
	var quadros_vistos := {}
	for k in 150:
		passos(1)
		var agora: Dictionary = ch.pixels()
		for kk in agora:
			if not ant.has(kk) or ant[kk] != agora[kk]:
				if not hist.has(kk):
					hist[kk] = []
				hist[kk].append(k)
		for kk in ant:
			if not agora.has(kk):
				if not hist.has(kk):
					hist[kk] = []
				hist[kk].append(k)
		ant = agora
		var vv := 0
		for g in ch.n_pool():
			var gt: Dictionary = ch.gota(g)
			if gt.ativa:
				vv += 1
				quadros_vistos[gt.quadro] = true
		pico_c = maxi(pico_c, vv)
	var pior := 0
	for kk in hist:
		var l: Array = hist[kk]
		var j := 0
		for i in l.size():
			while l[i] - l[j] >= 60:
				j += 1
			pior = maxi(pior, i - j + 1)
	print("calmo: pico %d labaredas, quadros vistos %s, pior pixel troca %d vezes em 1 s" % [pico_c, str(quadros_vistos.keys()), pior])
	ok(pico_c >= 3 and pico_c <= 5, "Reduzir piscadas: 3 a 5 labaredas por teia (%d)" % pico_c)
	ok(quadros_vistos.size() == 1, "Reduzir piscadas: ficam num quadro só (%s)" % str(quadros_vistos.keys()))
	ok(pior <= 2, "Reduzir piscadas: nenhum pixel das labaredas troca mais de 2 vezes em 1 s (pior %d)" % pior)
	Config.temporario(Piscadas.OPCAO, false)
