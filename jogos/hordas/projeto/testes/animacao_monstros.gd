extends Node
# Teste (#97, "muito duro"): o andar dos monstros de 5 vistas é um ciclo de verdade, movido pela distância.
#  - contas puras (animacao_monstros.gd): quadro da fase, sombra, aperto de golpe, curva da carga, assentar parado;
#  - TODAS as folhas de 5 vistas: colunas registradas em dados/quadros_monstros.json batem com a largura da imagem, o ciclo tem
#    mais de 2 quadros, todo quadro tem desenho e quadros vizinhos não são iguais (andar de verdade, não o pisca-pisca de 2 poses);
#  - no jogo: a fase anda com a distância (bicho lento não passa quadro, teleporte não conta), parado assenta nos pés juntos,
#    aperto ao levar golpe sobe e volta a 0, preparo de investida alarga e achata.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/animacao_monstros.tscn  (imprime "ANIMMONSTROS falhas=0")
const Anim := preload("res://scripts/hordas/animacao_monstros.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _quadro(I) -> void:
	I._dt = 1.0 / 60.0
	I._t += 1.0 / 60.0
	I.queue_redraw()
	await get_tree().process_frame


func _ready() -> void:
	_puras()
	_folhas()
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
	await _no_jogo(ar.inimigos, j)
	print("ANIMMONSTROS falhas=%d" % falhas)
	get_tree().quit()


func _puras() -> void:
	var c := Anim.config()
	for k in Anim.PADRAO:
		ok(c.has(k), "config tem %s" % k)
	ok(Anim.quadro(0.0, 6) == 0 and Anim.quadro(0.5, 6) == 3 and Anim.quadro(0.999, 6) == 5 and Anim.quadro(1.0, 6) == 5, "quadro da fase (0, 0,5, 0,999, 1)")
	var vistos := {}
	for k in 60:
		vistos[Anim.quadro(k / 60.0, 6)] = true
	ok(vistos.size() == 6, "um ciclo passa pelos 6 quadros (%d)" % vistos.size())
	for n in [3, 4, 6, 8]:
		for q in n:
			var cs := Anim.coluna_sombra(q, n)
			ok(cs >= 0 and cs < n and (cs == 0 or cs == n / 2), "coluna_sombra(%d, %d) = %d é 0 ou o meio" % [q, n, cs])
	ok(is_equal_approx(Anim.avancar(0.9, 11.0, 100.0), 0.01), "avancar dá a volta no ciclo (%f)" % Anim.avancar(0.9, 11.0, 100.0))
	ok(
		Anim.ciclo_px(20.0, 1.1, 22.0) == 22.0 and is_equal_approx(Anim.ciclo_px(100.0, 1.1, 22.0), 110.0) and Anim.ciclo_px(100.0, 1.1, 22.0, 2.0) == 200.0,
		"ciclo_px: piso, proporcional à altura e troca por tipo"
	)
	var f := 0.37
	for i in 200:
		f = Anim.assentar(f, 1.0 / 60.0, 1.5)
	ok(absf(f - 0.5) < 0.001, "parado assenta no pé-junto mais perto (0,5): %f" % f)
	f = 0.9
	for i in 200:
		f = Anim.assentar(f, 1.0 / 60.0, 1.5)
	ok(f < 0.001 or f > 0.999, "parado perto de 1 assenta em 0 / 1: %f" % f)
	var dur := 0.28
	ok(
		is_equal_approx(Anim.aperto(0.0, dur, 0.35), 1.0) and Anim.aperto(dur, dur, 0.35) == 0.0 and Anim.aperto(-1.0, dur, 0.35) == 0.0,
		"aperto: 1 no impacto, 0 no fim e antes do golpe"
	)
	var neg := 0.0
	var pos_meio := 0.0
	for k in 100:
		var a := Anim.aperto(dur * k / 100.0, dur, 0.35)
		neg = minf(neg, a)
		pos_meio = maxf(pos_meio, a)
	ok(neg < -0.05 and neg >= -0.36 and pos_meio <= 1.0, "aperto: quique pro lado oposto de até 0,35 do aperto (%.2f)" % neg)
	ok(Anim.aperto(dur * 0.5, dur, 0.0) >= 0.0, "aperto: quique 0 = sem estico")
	ok(
		Anim.carga(0.0, 2.0) == 0.0 and Anim.carga(1.0, 2.0) == 1.0 and Anim.carga(0.5, 2.0) < 0.5 and Anim.carga(0.5, 1.0) == 0.5,
		"carga: curva devagar no começo"
	)
	ok(
		is_equal_approx(Anim.subida(0.0), 1.0) and is_equal_approx(Anim.subida(0.25), 0.0) and is_equal_approx(Anim.subida(0.5), 1.0),
		"subida: alto com os pés juntos, baixo com as pernas abertas"
	)


## Todas as folhas de monstros de 5 vistas do inimigos.json.
func _folhas() -> void:
	var tab: Dictionary = Dados.json("inimigos")
	var n := 0
	for k in tab:
		var d = tab[k]
		if not (d is Dictionary and int(d.get("vistas", 1)) == 5):
			continue
		var sprite := str(d.sprite)
		var tex: Texture2D = Dados.tex(sprite)
		ok(tex != null, "%s: folha %s carrega" % [k, sprite])
		if tex == null:
			continue
		n += 1
		var cols := Anim.colunas(sprite)
		ok(cols > 3, "%s: folha nova (colunas = %d, esperado > 3; regere com o gerador)" % [k, cols])
		ok(tex.get_width() % cols == 0, "%s: largura %d divisível pelas %d colunas" % [k, tex.get_width(), cols])
		ok(tex.get_height() % 5 == 0, "%s: altura %d divisível por 5 vistas" % [k, tex.get_height()])
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		var w := tex.get_width() / cols
		var h := tex.get_height() / 5
		for vista in [0, 2]:  # frente e perfil bastam (as 5 vistas saem da mesma câmera)
			var dif_viz := 0
			for col in cols - 1:
				var vizinho := (col + 1) % (cols - 1)
				var dif := 0
				var tem := 0
				for y in range(0, h, 2):
					for x in range(0, w, 2):
						var a: Color = img.get_pixel(col * w + x, vista * h + y)
						var b: Color = img.get_pixel(vizinho * w + x, vista * h + y)
						if a.a > 0.5:
							tem += 1
						if (a.a > 0.5) != (b.a > 0.5) or (a.a > 0.5 and (a.r != b.r or a.g != b.g or a.b != b.b)):
							dif += 1
				ok(tem > 8, "%s: vista %d quadro %d tem desenho (%d)" % [k, vista, col, tem])
				if dif > 0:
					dif_viz += 1
			# a maioria dos pares vizinhos muda (no meio do ciclo uma perna pode parar: não exigimos todos)
			ok(dif_viz >= cols - 3, "%s: vista %d, quadros vizinhos diferentes em %d de %d pares" % [k, vista, dif_viz, cols - 1])
			# o branco de dano é a silhueta do quadro 0
			var errado := 0
			for y in range(0, h, 3):
				for x in range(0, w, 3):
					var p: Color = img.get_pixel(x, vista * h + y)
					var q: Color = img.get_pixel((cols - 1) * w + x, vista * h + y)
					if (p.a > 0.5) != (q.a > 0.5) or (q.a > 0.5 and (q.r < 0.99 or q.g < 0.99 or q.b < 0.99)):
						errado += 1
			ok(errado == 0, "%s: vista %d, a última coluna é o branco do quadro 0 (%d pixels errados)" % [k, vista, errado])
	ok(n >= 40, "achou as folhas de monstros (%d)" % n)


func _no_jogo(I, j) -> void:
	var origem: Vector2 = j.position
	I.limpar()
	var v = I.criar("cao_ossos", origem + Vector2(60, 40))
	v.t_nasc = 0.0
	ok(v.anim and v.nq == v.cols - 1 and v.nq > 2, "cao_ossos: anim ligado, %d quadros de andar" % v.nq)
	ok(v.tam.x * v.cols == v.tex.get_width(), "tam.x x colunas = largura da folha")
	for q in 3:
		await _quadro(I)
	var f0: float = v.fase
	# anda 3 ciclos exatos em linha reta, 2 px por quadro
	var dist := 0.0
	var quadros := {}
	for q in 400:
		if dist >= v.ciclo * 3.0:
			break
		v.pos += Vector2(2.0, 0)
		dist += 2.0
		await _quadro(I)
		quadros[v.qd] = true
	ok(quadros.size() == v.nq, "3 ciclos passam por todos os %d quadros (%d)" % [v.nq, quadros.size()])
	var esperado := fposmod(f0 + dist / v.ciclo, 1.0)
	ok(absf(angle_difference(esperado * TAU, v.fase * TAU)) < 0.5, "a fase anda com a distância (esperado %.3f, veio %.3f)" % [esperado, v.fase])
	ok(v.lean > 0.5, "anda pra direita: inclina pra direita (%.2f)" % v.lean)
	# teleporte (salto grande) não conta como passo
	var fa: float = v.fase
	v.pos += Vector2(45, 0)
	await _quadro(I)
	ok(absf(angle_difference(fa * TAU, v.fase * TAU)) < 0.001, "salto de 45 px num quadro (teleporte) não gira a fase")
	# bicho lento: metade da distância, metade do giro
	var fb: float = v.fase
	for q in 20:
		v.pos += Vector2(0.5, 0)
		await _quadro(I)
	var giro := fposmod(v.fase - fb, 1.0)
	ok(absf(giro - 10.0 / v.ciclo) < 0.05, "andar devagar (10 px) gira %.3f do ciclo (esperado %.3f)" % [giro, 10.0 / v.ciclo])
	# parado: assenta nos pés juntos e não inclina
	for q in 90:
		await _quadro(I)
	var assentou: bool = absf(v.fase - 0.0) < 0.01 or absf(v.fase - 0.5) < 0.01 or absf(v.fase - 1.0) < 0.01
	ok(assentou, "parado assenta nos pés juntos (fase %.3f)" % v.fase)
	ok(absf(v.lean) < 0.05, "parado volta a ficar reto (%.3f)" % v.lean)
	# aperto de golpe: acontece na hora, sobe e volta
	I.ferir(v, 1.0)
	v.hp = v.hpmax
	await _quadro(I)
	var larg0: float = absf(v.dr.size.x) / v.sz.x
	ok(larg0 > 1.1, "logo após o golpe o bicho está mais largo (%.2f)" % larg0)
	for q in 40:
		await _quadro(I)
	var larg1: float = absf(v.dr.size.x) / v.sz.x
	ok(larg1 < 1.06, "0,6 s depois do golpe voltou ao normal (%.2f)" % larg1)
	# preparo da investida: alarga e achata, e volta
	v.estado = 1
	v.t_estado = 0.05
	v.dir_inv = Vector2.RIGHT
	await _quadro(I)
	var l2: float = absf(v.dr.size.x) / v.sz.x
	var a2: float = v.dr.size.y / v.sz.y
	ok(l2 > 1.1 and a2 < 0.9, "preparo da investida: largura %.2f altura %.2f" % [l2, a2])
	v.estado = 0
	# folha antiga (3 colunas) continua andando pelo ritmo: vírus
	I.limpar()
	var vi = I.criar("bug", origem + Vector2(-60, 40))
	vi.t_nasc = 0.0
	await _quadro(I)
	ok(not vi.anim and vi.cols == 3 and vi.nq == 2, "vírus: 3 colunas, andar pelo ritmo (sem anim)")
	I.limpar()
