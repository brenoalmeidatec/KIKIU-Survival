extends Node
# Teste (pedido do Alisson): os monstros viram com sprites de verdade, não achatando até virar uma linha.
#  - as folhas dos 6 monstros de horror têm 5 linhas (frente, 3/4, perfil, 3/4 costas, costas) e todas têm desenho;
#  - numa virada de 180° (esquerda -> frente -> direita, e por trás) nenhum quadro é desenhado com menos de 90% da
#    largura normal, e a virada passa pelas vistas intermediárias (sem pular de perfil a perfil);
#  - vírus (vistas = 1) nunca espelham nem achatam, de qualquer lado do herói;
#  - cliente online: o olhar vem do deslocamento desenhado.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/vistas.tscn  (imprime "VISTA falhas=0")
const HORROR := ["carnical", "cao_ossos", "cavaleiro_oco", "espectro", "abominacao", "arauto"]
const VIRUS := ["bug", "popup", "spam", "trojan", "minerador"]
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _quadro(I) -> void:
	I._dt = 1.0 / 60.0
	I.queue_redraw()
	await get_tree().process_frame


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
	var origem: Vector2 = j.position

	# ---------- folhas: 5 linhas, todas com desenho ----------
	for t in HORROR:
		I.limpar()
		var v = I.criar(t, j.position + Vector2(0, 80))
		ok(v.vistas == 5, "%s: vistas = 5 no json" % t)
		var img: Image = v.tex.get_image()
		ok(img.get_height() % 5 == 0 and absf(v.tam.y * 5.0 - img.get_height()) < 0.01, "%s: a folha tem 5 linhas (altura %d)" % [t, img.get_height()])
		var w := int(v.tam.x)
		var h := int(v.tam.y)
		for fila in 5:
			for col in v.cols:
				var n := 0
				for y in range(0, h, 2):
					for x in range(0, w, 2):
						if img.get_pixel(col * w + x, fila * h + y).a > 0.5:
							n += 1
				ok(n > 15, "%s: vista %d quadro %d tem desenho (%d amostras)" % [t, fila, col, n])
	for t in VIRUS:
		I.limpar()
		var v = I.criar(t, j.position + Vector2(0, 80))
		ok(v.vistas == 1, "%s: vírus tem vistas = 1" % t)

	# ---------- virada de 180° dos monstros de horror ----------
	for t in HORROR:
		for rota in ["frente", "costas"]:
			var r: Dictionary = await _virada(I, j, origem, t, rota)
			ok(r.min_larg >= 0.9, "%s (%s): menor largura numa virada = %.2f (>= 0.9)" % [t, rota, r.min_larg])
			ok(r.pulos == 0, "%s (%s): a vista nunca pula de setor (%d pulos)" % [t, rota, r.pulos])
			var esperado: Array = [-2, -1, 0, 1, 2] if rota == "frente" else [-2, -3, 4, 3, 2]
			for s in esperado:
				ok(r.setores.has(s), "%s (%s): passou pelo setor %d (viu %s)" % [t, rota, s, str(r.setores.keys())])
			ok(r.trocas <= 6, "%s (%s): sem piscar entre vistas (%d trocas)" % [t, rota, r.trocas])

	# ---------- vírus: sem espelho, sem achatar ----------
	I.limpar()
	var lista := []
	for i in VIRUS.size():
		lista.append(I.criar(VIRUS[i], j.position + Vector2(-90 + i * 8, 40)))
		lista.append(I.criar(VIRUS[i], j.position + Vector2(90 - i * 8, -40)))
	for v in lista:
		v.t_nasc = 0.0
	var min_l := 9.0
	var espelhou := 0
	for q in 8:
		await _quadro(I)
		for v in lista:
			min_l = minf(min_l, v.dr.size.x / v.sz.x)
			if v.espelho or v.dr.size.x < 0.0:
				espelhou += 1
		if q == 3:
			j.position = origem + Vector2(260, 0)  # o herói passa pro outro lado de todos
	ok(min_l >= 0.9, "vírus: menor largura = %.2f (>= 0.9, nunca uma linha)" % min_l)
	ok(espelhou == 0, "vírus nunca espelham nem desenham com largura negativa (%d vezes)" % espelhou)
	j.position = origem

	# ---------- cliente online: o olhar vem do deslocamento ----------
	I.limpar()
	I.espelho = true
	var vc = I.criar("cavaleiro_oco", j.position + Vector2(-120, 60))
	vc.t_nasc = 0.0
	for q in 4:
		await _quadro(I)
	for q in 40:
		vc.pos += Vector2(2.5, 0)  # anda pra direita no desenho
		await _quadro(I)
	ok(vc.vista == 2 and not vc.espelho, "cliente online: andando pra direita mostra o perfil direito (vista %d, espelho %s)" % [vc.vista, str(vc.espelho)])
	for q in 40:
		vc.pos += Vector2(-2.5, 0)
		await _quadro(I)
	ok(vc.vista == 2 and vc.espelho, "cliente online: andando pra esquerda mostra o perfil espelhado (vista %d, espelho %s)" % [vc.vista, str(vc.espelho)])
	I.espelho = false
	I.limpar()
	print("VISTA falhas=%d" % falhas)
	get_tree().quit()


## Gira o herói em volta do monstro (parado no lugar) de um lado ao outro, por frente ou por trás, e mede o que foi desenhado.
func _virada(I, j, centro: Vector2, tipo: String, rota: String) -> Dictionary:
	I.limpar()
	var v = I.criar(tipo, centro)
	v.t_nasc = 0.0
	var ini := -PI * 0.5  # a = ângulo a partir de "embaixo do monstro" (frente): -90 = esquerda, 0 = embaixo, +90 = direita, 180 = em cima
	var passos := 90
	var res := {"min_larg": 9.0, "pulos": 0, "setores": {}, "trocas": 0}
	j.position = centro + Vector2(sin(ini), cos(ini)) * 110.0
	for q in 5:  # na primeira passada ele já olha direto pro herói
		await _quadro(I)
	var ant: int = v.setor
	for q in passos + 40:
		var u := minf(1.0, float(q) / passos)
		var a := ini + u * PI if rota == "frente" else ini - u * PI  # costas: -90 -> -270 (= +90) passando por cima
		j.position = centro + Vector2(sin(a), cos(a)) * 110.0
		v.flash = 0.0
		await _quadro(I)
		res.min_larg = minf(res.min_larg, absf(v.dr.size.x) / v.sz.x)
		res.setores[v.setor] = true
		if v.setor != ant:
			res.trocas += 1
			var dif := absi((v.setor + 8) % 8 - (ant + 8) % 8)
			if mini(dif, 8 - dif) > 1:
				res.pulos += 1
		ant = v.setor
	return res
