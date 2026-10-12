extends Node
# Teste do Marco 3 (#127): os inimigos são desenhados em lote (MultiMesh) e o limite de vivos vem da fase.
#  - limite_vivos(): padrão 250 por fase, 500 só na prorrogação e no Enxame Final, o menor entre a fase e a qualidade vale;
#  - cada bicho visível vira 1 instância de sprite (na ordem por altura) e até 2 de sombra; o retângulo e o recorte do atlas batem
#    com o que o bicho desenha (v.dr, quadro, vista, espelho) e os pixels do atlas são os da folha;
#  - nascendo = nuvem de 4 discos; aura e elite = 1 disco; inclinação = 2 faixas; os buffers crescem além da capacidade inicial;
#  - telegrafia: quem atira pisca avermelhado nos 0,4 s antes do tiro (e só nesses).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/desenho_lote.tscn  (imprime "LOTE falhas=0")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _quadro(I) -> void:
	I._dt = 1.0 / 60.0
	I.queue_redraw()
	await get_tree().process_frame


## As instâncias de sprite do quadro: lista de {x, y, w, h, cor, rx, ry, rw, rh}.
func _inst(buf: PackedFloat32Array, n: int) -> Array:
	var res := []
	for k in n:
		var o := k * 16
		res.append(
			{
				"x": buf[o + 3],
				"y": buf[o + 7],
				"w": buf[o],
				"h": buf[o + 5],
				"cor": Color(buf[o + 8], buf[o + 9], buf[o + 10], buf[o + 11]),
				"rx": buf[o + 12],
				"ry": buf[o + 13],
				"rw": buf[o + 14],
				"rh": buf[o + 15]
			}
		)
	return res


func _ready() -> void:
	var m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(0.3).timeout
	m._comecar("hazaki")
	var ar = m._arena
	var j = ar.jogador
	await get_tree().create_timer(1.0).timeout
	ar.set_process(false)
	j.set_process(false)
	j.set_physics_process(false)
	var I = ar.inimigos
	var df = ar.diretor

	# ---------- limite de vivos por fase ----------
	var dados_fase: Dictionary = Dados.json("fase").get("dificuldade", {})
	ok(int(dados_fase.get("limite_vivos", 0)) == 250, "fase.json: limite_vivos padrão = 250")
	ok(int(dados_fase.get("limite_vivos_pror", 0)) == 350, "fase.json: limite_vivos_pror = 350")
	ok(int(dados_fase.get("limite_vivos_ref", 0)) == 500, "fase.json: limite_vivos_ref = 500")
	var qs := {"alto": 350, "medio": 350, "baixo": 250}
	df.enxame_final = false
	df.final_chamado = false
	for q in qs:
		Config.g_perfil_temporario(q)
		ok(df.limite_vivos() == 250, "jogo normal, qualidade %s: limite = 250 (deu %d)" % [q, df.limite_vivos()])
	df.enxame_final = true
	for q in qs:
		Config.g_perfil_temporario(q)
		ok(df.limite_vivos() == qs[q], "Enxame Final, qualidade %s: limite = %d (deu %d)" % [q, qs[q], df.limite_vivos()])
	df.enxame_final = false
	var t_ant: float = df.t_fase
	df.final_chamado = true
	df.t_fase = float(df._fase.get("duracao", 600)) + float(df.pror_cfg().get("janela_chefe", 120.0)) + 3.0
	ok(df.pror_ativa(), "preparo: a prorrogação está ativa")
	for q in qs:
		Config.g_perfil_temporario(q)
		ok(df.limite_vivos() == qs[q], "prorrogação, qualidade %s: limite = %d (deu %d)" % [q, qs[q], df.limite_vivos()])
	# o teto de 350 na prorrogação vem com mais dano em quem nasce (500/350), em qualquer perfil
	var esperado := 500.0 / 350.0
	for q in qs:
		Config.g_perfil_temporario(q)
		ok(absf(df.mult_dano_teto() - esperado) < 0.001, "prorrogação, qualidade %s: dano x%.3f (deu %.3f)" % [q, esperado, df.mult_dano_teto()])
	I.limpar()
	var com_pror = I.criar("bug", j.position + Vector2(300, 0), 1)
	var tiro_pror: float = I._mult_tiro()
	df.t_fase = t_ant
	df.final_chamado = false
	ok(df.mult_dano_teto() == 1.0, "fora da prorrogação o dano não muda")
	var sem_pror = I.criar("bug", j.position + Vector2(340, 0), 1)
	ok(
		absf(com_pror.dano / sem_pror.dano - esperado) < 0.001,
		"o bug que nasce na prorrogação tem x%.3f de dano (deu %.3f)" % [esperado, com_pror.dano / sem_pror.dano]
	)
	ok(absf(tiro_pror / I._mult_tiro() - esperado) < 0.001, "o tiro dos inimigos também compensa na prorrogação")
	df.enxame_final = true
	ok(absf(df.mult_dano_teto() - esperado) < 0.001, "Enxame Final: dano x%.3f" % esperado)
	df.enxame_final = false
	I.limpar()
	Config.g_perfil_temporario("alto")
	df._fase["limite_vivos"] = 120
	ok(df.limite_vivos() == 120, "uma fase pode ter o seu limite (120)")
	df._fase.erase("limite_vivos")
	ok(df.limite_vivos() == 250, "sem o limite da fase volta ao padrão")

	# ---------- desenho em lote ----------
	Config.g_perfil_temporario("alto")
	I.limpar()
	I._t = 1.0
	var origem: Vector2 = j.position
	var tipos := ["bug", "popup", "carnical", "cao_ossos", "arauto", "bug"]
	var lista := []
	for i in tipos.size():
		var v = I.criar(tipos[i], origem + Vector2(-110 + i * 44, -60 + (i % 3) * 50))
		v.t_nasc = 0.0
		lista.append(v)
	for q in 5:
		await _quadro(I)
	ok(I._ni == tipos.size(), "1 instância de sprite por bicho visível (%d de %d)" % [I._ni, tipos.size()])
	ok(I._ns == tipos.size() * 2, "2 instâncias de sombra por bicho (contato + sombra assada): %d de %d" % [I._ns, tipos.size() * 2])
	var sp := _inst(I._bi, I._ni)
	var atlas = I._atlas
	var vistos := {}
	for k in I._ordem.size():
		var v = I._ordem[k]
		var s: Dictionary = sp[k]  # a k-ésima instância é a do k-ésimo bicho na ordem por altura
		ok(is_equal_approx(s.x, v.dr.position.x) and is_equal_approx(s.y, v.dr.position.y), "%s: posição da instância = a do retângulo desenhado" % v.tipo)
		ok(is_equal_approx(s.w, absf(v.dr.size.x)) and is_equal_approx(s.h, v.dr.size.y), "%s: tamanho da instância = o do retângulo" % v.tipo)
		var ex: float = v.at.x + v.tam.x * v.qd + (v.tam.x if v.dr.size.x < 0.0 else 0.0)
		ok(
			is_equal_approx(s.rx, ex) and is_equal_approx(s.ry, v.at.y + v.tam.y * v.vista),
			"%s: recorte no atlas (quadro %d, vista %d, espelho %s)" % [v.tipo, v.qd, v.vista, str(v.dr.size.x < 0.0)]
		)
		ok(
			is_equal_approx(absf(s.rw), v.tam.x) and is_equal_approx(s.rh, v.tam.y) and (s.rw < 0.0) == (v.dr.size.x < 0.0),
			"%s: largura do recorte e espelho" % v.tipo
		)
		ok(s.cor.is_equal_approx(Color.WHITE), "%s: sem tinta (%s)" % [v.tipo, str(s.cor)])
		# os pixels do atlas são os da folha
		var folha: Image = v.tex.get_image()
		var qx := int(v.tam.x * v.qd) + int(v.tam.x * 0.5)
		var qy := int(v.tam.y * v.vista) + int(v.tam.y * 0.6)
		var p_atlas: Color = atlas._img.get_pixelv(Vector2i(int(v.at.x) + qx, int(v.at.y) + qy))
		ok(p_atlas.is_equal_approx(folha.get_pixel(qx, qy)), "%s: pixel do atlas = pixel da folha" % v.tipo)
		vistos[v.tex] = v.at
	var y_ant := -1.0e9
	for v in I._ordem:
		ok(v.pos.y >= y_ant - 0.01, "a ordem de desenho segue a altura")
		y_ant = v.pos.y
	# folhas diferentes não se sobrepõem no atlas
	var ks := vistos.keys()
	for a in ks.size():
		for b in range(a + 1, ks.size()):
			var ra := Rect2(vistos[ks[a]], Vector2(ks[a].get_width(), ks[a].get_height()))
			var rb := Rect2(vistos[ks[b]], Vector2(ks[b].get_width(), ks[b].get_height()))
			ok(not ra.intersects(rb), "folhas %d e %d não se sobrepõem no atlas" % [a, b])
	ok(ks.size() == 5, "5 folhas distintas no atlas (%d)" % ks.size())

	# sombras: contato sempre; a assada tem o recorte dentro do atlas de sombras
	var som := _inst(I._bs, I._ns)
	var contatos := 0
	for s in som:
		if s.rx == 0.0 and s.ry == 0.0 and s.rw == 24.0 and s.rh == 8.0:
			contatos += 1
		else:
			ok(s.rw > 0.0 and s.rx + s.rw <= 1024.0 and s.ry + s.rh <= 1024.0, "sombra assada dentro do atlas de sombras")
	ok(contatos == tipos.size(), "uma mancha de contato por bicho (%d)" % contatos)

	# ---------- nascendo, aura, elite, inclinação ----------
	I.limpar()
	var vn = I.criar("bug", origem + Vector2(-60, 0))
	vn.t_nasc = 0.2
	var va = I.criar("bug", origem + Vector2(0, -50))
	va.t_nasc = 0.0
	va.aura = Color(1, 0.2, 0.2, 1)
	var ve = I.criar("bug", origem + Vector2(60, 0), 1, true)
	ve.t_nasc = 0.0
	await _quadro(I)
	await _quadro(I)
	var discos := 0
	var sprites := 0
	for s in _inst(I._bi, I._ni):
		if s.rw == 0.0:
			discos += 1
		else:
			sprites += 1
	ok(sprites == 3, "nascendo + aura + elite: 3 sprites (%d)" % sprites)
	ok(discos == 4 + 1 + 1, "nuvem de nascer (4) + aura (1) + brilho de elite (1) = 6 discos (%d)" % discos)
	I.limpar()
	var vi = I.criar("carnical", origem + Vector2(0, -20))
	vi.t_nasc = 0.0
	await _quadro(I)
	vi.lean = 0.9
	vi.parado = 0.0
	vi.pos_f = vi.pos  # anda: o passo não zera a inclinação
	var inc_n := 0
	for q in 3:
		vi.lean = 0.9
		vi.parado = 0.0
		await _quadro(I)
		inc_n = maxi(inc_n, I._ni)
	ok(inc_n == 2 or inc_n == 1, "inclinação desenha 2 faixas (ou 1 se o passo assentou): %d" % inc_n)

	# ---------- os buffers crescem ----------
	I.limpar()
	for i in 300:
		var v = I.criar("bug", origem + Vector2(-250 + (i % 25) * 20, -150 + (i / 25) * 25))
		v.t_nasc = 0.0
	for q in 4:
		await _quadro(I)
	ok(I._ni == 300, "300 bichos = 300 instâncias de sprite (%d)" % I._ni)
	ok(I._ns == 600, "300 bichos = 600 instâncias de sombra (%d)" % I._ns)
	ok(I._bi.size() >= 300 * 16 and I._bs.size() >= 600 * 16, "os buffers cresceram além da capacidade inicial")
	I.limpar()
	await _quadro(I)
	ok(I._ni == 0 and I._ns == 0, "sem bichos, sem instâncias")

	# ---------- telegrafia do tiro (0,4 s) ----------
	var atirador := ""
	for k in Dados.json("inimigos"):
		var d = Dados.json("inimigos")[k]
		if d is Dictionary and float(d.get("atira", 0.0)) > 0.0 and int(d.get("vistas", 1)) <= 1 and not d.get("chefe", false):
			atirador = k
			break
	ok(atirador != "", "existe um atirador nos dados")
	if atirador != "":
		var corp := {}
		for t_atira in [0.5, 0.3, 0.1, 0.0]:
			var piscou := false
			var normal := false
			for t in [1.0, 1.04]:  # int(t * 25) par = pisca, ímpar = normal
				I.limpar()
				var vt = I.criar(atirador, origem + Vector2(40, 0))
				vt.t_nasc = 0.0
				vt.t_atira = t_atira
				I._t = t
				await _quadro(I)
				var c: Color = _inst(I._bi, I._ni)[0].cor
				if c.g < 0.9:
					piscou = true
				else:
					normal = true
			corp[t_atira] = [piscou, normal]
		ok(corp[0.5][0] == false, "faltando 0,5 s pro tiro não pisca")
		ok(corp[0.3][0] and corp[0.3][1], "faltando 0,3 s pro tiro pisca (alternando)")
		ok(corp[0.1][0] and corp[0.1][1], "faltando 0,1 s pro tiro pisca (alternando)")
		ok(corp[0.0][0] == false, "no instante do tiro (0) não pisca")
	I.limpar()
	print("LOTE falhas=%d" % falhas)
	get_tree().quit()
