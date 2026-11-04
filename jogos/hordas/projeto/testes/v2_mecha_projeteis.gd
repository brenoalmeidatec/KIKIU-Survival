extends "res://testes/isolamento_v2.gd"
## Visual próprio dos mísseis sem mudar quantidade, movimento nem dano; pools estáveis mesmo depois de acabar o voo.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
# Godot 4.4.1, seed 781923; mesma fixture com efeitos.gd E adagas.gd originais extraídos por git show
# do commit ad0f315f16fc6af273c30834954073feda0af096, executados em cópias externas ao repo.
# [direção, vida do alvo, críticos, próximos três randi], por fator de partículas.
# Direção/dano têm tolerância entre plataformas; as amostras PCG uint32 são exatas.
const RNG_BASELINE := {
	0.25: [Vector2(0.999774, 0.021257), 990.0, 1, 1720902221, 2413150676, 1815383821],
	0.6: [Vector2(0.999977, -0.006773), 990.0, 1, 3371356732, 3628179373, 1186623667],
	1.0: [Vector2(0.999817, 0.019107), 990.0, 1, 1907011038, 3160003473, 987873203],
}
var falhas := 0
var w


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
	w.combate.cfg.golpe.variacao = 0.0
	w.heroi.imortal = true
	w.heroi.m_critico = -1.0
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(300, 0)
	passos(3)


func monstro(p: Vector2):
	var m = w.nascer_monstro("inimigo_cao_ossos", p)
	m.vida_max = 1000.0
	m.vida = 1000.0
	m.atordoa_t = 60.0
	m.emp = Vector2.ZERO
	return m


func comparar_rng() -> void:
	var referencia: Array = []
	for desenhar in [true, false]:
		zerar()
		var c = w.combate
		var ad = c.adagas
		var h = w.heroi
		h.m_critico = 0.4
		var m = monstro(h.pos + Vector2(100, 0))
		seed(781923)
		c.fx.faiscas(h.pos, Vector2.RIGHT, 6, Color.WHITE, 110.0, desenhar)
		c.fx.estouro(h.pos, Color.WHITE, 3, desenhar)
		# fixture congelada no canhão de 1 bala de 4,8 do baseline ad0f315: a rajada nova (n, leque, dano) sortearia outra sequência
		var passo_base: Dictionary = c.cfg.golpe.passos[0].duplicate(true)
		passo_base.n = 1
		passo_base.leque = 0
		passo_base.dano = 4.8
		ad.lancar(h, h.pos, Vector2.RIGHT, passo_base)
		ad._acertar(0, m, m.pos)
		var obtido: Array = [ad.a_dir[0], m.vida, c.criticos, randi(), randi(), randi()]
		var esperado: Array = RNG_BASELINE[c.fx.fator_part]
		ok(
			(obtido[0] as Vector2).distance_to(esperado[0]) <= 0.00001 and absf(float(obtido[1]) - float(esperado[1])) <= 0.00001 and obtido[2] == esperado[2],
			"dispersão/crítico/dano equivalem ao baseline ad0f315, fator %s" % c.fx.fator_part
		)
		ok(obtido.slice(3) == esperado.slice(3), "próximos três randi equivalem exatamente ao baseline ad0f315")
		if desenhar:
			referencia = obtido
		else:
			ok(obtido == referencia, "omitir faíscas/estouro mantém dispersão, crítico, dano e próximos sorteios com a mesma seed")


func bocas_visuais() -> void:
	zerar()
	var h = w.heroi
	var ad = w.combate.adagas
	var info_original: Dictionary = h.tipo.info
	h.tipo.info = info_original.duplicate(true)
	var tabela := {"canhoes": [], "pods": []}
	for linha in 8:
		tabela.canhoes.append([[-20.0 - linha, -40.0 - linha], [20.0 + linha, -40.0 - linha]])
		tabela.pods.append([[-16.0 - linha, -65.0 - linha], [16.0 + linha, -65.0 - linha]])
	for proj in ["bala", "missil"]:
		for ang in 8:
			var dir := Vector2.from_angle(float(ang) * PI / 4.0)
			var linha: int = h.linha_de(dir)
			for lado in 2:
				var passo: Dictionary = w.combate.cfg.golpe.passos[lado].duplicate(true)
				passo.proj = proj
				passo.cone_dir = dir
				var origem: Vector2 = h.pos + h.ORIGEM_GOLPE
				if proj == "missil":
					origem += Vector2(-dir.y, dir.x) * (-9.0 if lado == 0 else 9.0)
				var referencia: Array = []
				for com_tabela in [false, true]:
					ad.limpar()
					h.tipo.info["bocas_projeteis"] = tabela if com_tabela else {}
					seed(91723)
					if proj == "bala":
						w.combate.golpear(h, origem, dir, passo, lado)
					else:
						ad.lancar(h, origem, dir, passo)
					var logico: Array = [ad.a_pos[0], ad.a_dir[0], ad.a_vel[0], ad.a_rest[0], ad.a_raio[0], ad.a_dano[0], randi()]
					if not com_tabela:
						referencia = logico
					else:
						ok(logico == referencia, "boca visual não altera física nem RNG: %s direção %d lado %d" % [proj, linha, lado])
						var xy: Array = tabela["pods" if proj == "missil" else "canhoes"][linha][lado]
						ok(ad._pos_visual(0).distance_to(h.pos + Vector2(xy[0], xy[1])) < 0.001, "o centro do projétil nasce na boca projetada")
	var offset: Vector2 = ad.a_visual_offset[0]
	var alvo = monstro(h.pos + Vector2(0, 180))
	ad.a_alvo[0] = alvo
	ad.a_giro[0] = 3.2
	ad._guiar(0.1)
	ok(ad.a_visual_offset[0] == offset, "guiar o míssil não rotaciona o offset projetado")
	ad.a_visual_dist[0] = 60.0
	ok(ad._pos_visual(0) == ad.a_pos[0], "offset converge para a trajetória lógica após 60 px")
	ad.a_visual_dist[0] = 0.0
	ad.a_visual_t[0] = 0.0
	ok(ad._pos_visual(0) == ad.a_pos[0], "offset também converge pelo tempo curto")
	ad.a_rest[0] = 0.0
	ad.a_visual_t[0] = 0.1
	ad.a_visual_dist[0] = 22.0
	var reutilizada: int = ad._nova(h.pos, Vector2.RIGHT, 270.0, 320.0, 1.0, 0.0, 0.0, Color.WHITE, 0, false, 4.0)
	ok(
		reutilizada == 0 and ad.a_visual_offset[0] == Vector2.ZERO and ad.a_visual_t[0] == 0.0 and ad.a_visual_dist[0] == 0.0,
		"vaga reutilizada não herda a boca do projétil anterior"
	)
	ad.limpar()
	ok(ad.a_visual_offset[0] == Vector2.ZERO and ad.a_visual_t[0] == 0.0 and ad.a_visual_dist[0] == 0.0, "limpar zera todos os campos visuais")
	h.tipo.info = info_original


## Uma rajada do braço 0 só pelo canhão (o resto do mundo não anda), até todas as bolinhas acabarem.
func _rajada_isolada(ad, h, dir := Vector2.RIGHT) -> void:
	var passo: Dictionary = w.combate.cfg.golpe.passos[0]
	w.combate.golpear(h, h.pos + h.ORIGEM_GOLPE, dir, passo, 0)
	for q in 90:
		ad.atualizar(PASSO)
		if ad.ativas() == 0:
			break


func _sumir(lista: Array) -> void:
	for m in lista:
		m.vivo = false
		m.pos = w.heroi.pos + Vector2(5000, 5000)


func _parede() -> Array:
	var h = w.heroi
	var lista := []
	for k in 7:
		lista.append(monstro(h.pos + h.ORIGEM_GOLPE + Vector2(90, -2) + Vector2(0, (k - 3) * 9.0)))
	return lista


## O estalo da bolinha (pedido do Alisson: "animação da explosão do projétil"): o acerto e o fim do alcance tocam o impacto, com teto
## por quadro, por rajada e por lugar, pool fixo no pior caso (horda grande + crítico sempre) e o perfil Baixo cortando.
func estalos_rajada() -> void:
	zerar()
	var c = w.combate
	var ad = c.adagas
	var h = w.heroi
	var e = ad.get("estalos")
	ok(e != null, "o canhão do mecha tem pool de estalos (acerto e fim do alcance)")
	if e == null:
		return
	var args_antes: Dictionary = w.args.duplicate()
	w.args["particulas"] = "muitas"  # Alto: efe_impactos 1
	# quadros na grade de 1 px: tamanho ímpar inteiro, alfa só 0 ou 1 (sem antialiasing), miolo branco no começo e sem branco no fim
	var tamanhos := [11, 15, 7]
	var contagens := [4, 5, 3]
	for t in 3:
		var lista: Array = e.quadros[t]
		ok(lista.size() == contagens[t], "tipo %d tem %d quadros" % [t, contagens[t]])
		var difere := false
		for q in lista.size():
			var img: Image = (lista[q] as Texture2D).get_image()
			ok(img.get_width() == tamanhos[t] and img.get_height() == tamanhos[t], "quadro %d/%d no tamanho inteiro %d" % [t, q, tamanhos[t]])
			var binario := true
			for y in img.get_height():
				for x in img.get_width():
					var a := img.get_pixel(x, y).a
					binario = binario and (a == 0.0 or a == 1.0)
			ok(binario, "quadro %d/%d sem alfa parcial (1 px, sem antialiasing)" % [t, q])
			if q > 0 and img.get_data() != (lista[q - 1] as Texture2D).get_image().get_data():
				difere = true
		ok(difere, "o impacto %d anima (quadros diferentes)" % t)
		ok(float(e.DUR[t]) >= 0.15 and float(e.DUR[t]) <= 0.25, "duração curta do impacto %d (0,15 a 0,25 s)" % t)
	var f0: Image = (e.quadros[e.ESTALO][0] as Texture2D).get_image()
	var fz: Image = (e.quadros[e.ESTALO][3] as Texture2D).get_image()
	ok(f0.get_pixel(5, 5) == Color.WHITE and fz.get_pixel(5, 5).a == 0.0, "o estalo nasce com miolo branco e termina em faíscas soltas")
	# 1) o ACERTO toca o estalo no ponto do contato, em pixel inteiro, sem nó novo
	var alvo = monstro(h.pos + Vector2(70, 0))
	var nos: int = get_tree().get_node_count()
	_rajada_isolada(ad, h)
	ok(ad.acertos > 0 and e.emitidos >= 1, "acerto da bolinha toca o estalo (%d acertos, %d estalos)" % [ad.acertos, e.emitidos])
	var achou := false
	for i in e.MAX:
		var pe: Vector2 = e.pos[i]
		if e.tipo[i] == e.ESTALO and pe == pe.round():
			achou = achou or pe.distance_to(alvo.pos + Vector2(0, -6)) < float(alvo.raio) + 8.0
	ok(achou, "o estalo fica no contato com o monstro, em pixel inteiro")
	ok(e.emitidos <= e.POR_RAJADA, "uma rajada no mesmo alvo não passa de %d estalos (%d)" % [e.POR_RAJADA, e.emitidos])
	ok(get_tree().get_node_count() == nos, "o estalo não cria nó")
	_sumir([alvo])
	# 2) o FIM DO ALCANCE sem acerto toca o fizzle
	zerar()
	_rajada_isolada(ad, h)
	ok(ad.acertos == 0 and e.emitidos >= 1 and e.emitidos <= e.POR_RAJADA, "fim do alcance sem acerto toca o fizzle, com teto por rajada (%d)" % e.emitidos)
	ok(e.tipo[0] == e.FIZZLE, "o impacto do fim do alcance é o fizzle")
	# 3) teto por RAJADA: as bolinhas em vários monstros diferentes, sem crítico
	zerar()
	var parede := _parede()
	_rajada_isolada(ad, h)
	ok(ad.acertos >= 3 and e.emitidos <= e.POR_RAJADA, "rajada em vários monstros: %d acertos, %d estalos (teto %d)" % [ad.acertos, e.emitidos, e.POR_RAJADA])
	_sumir(parede)
	# 4) teto por QUADRO e por LUGAR (direto no pool)
	e.limpar()
	var aceitos := 0
	for k in 10:
		aceitos += 1 if e.emitir(Vector2(k * 40.0, 0.0), e.ESTALO, 0, 1.0) else 0
	ok(aceitos == e.POR_QUADRO, "no máximo %d impactos por quadro (%d)" % [e.POR_QUADRO, aceitos])
	e.limpar()
	ok(e.emitir(Vector2(10, 10), e.ESTALO, 0, 1.0), "primeiro estalo num lugar toca")
	e.atualizar(0.2)
	ok(not e.emitir(Vector2(13, 12), e.ESTALO, 0, 1.0), "o mesmo lugar não reacende antes de 0,5 s (2 Hz)")
	e.atualizar(0.31)
	ok(e.emitir(Vector2(13, 12), e.ESTALO, 0, 1.0), "o mesmo lugar reacende depois de 0,5 s")
	# 5) o mesmo ponto pedido a cada quadro por 3 s (crítico, que passa do teto por rajada): no máximo 2 acesos por segundo
	e.limpar()
	var acesos := []
	for q in 180:
		e.emitir(Vector2(50, 50), e.ESTALO, 0, 1.0, true)
		acesos.append(1.0 if e.ativas() > 0 else 0.0)
		e.atualizar(PASSO)
	var pior := 0
	for ini in range(acesos.size() - 60):
		pior = maxi(pior, e.Piscadas.trocas(acesos.slice(ini, ini + 61)))
	ok(pior <= 4, "o mesmo ponto acende no máximo 2 vezes por segundo (%d trocas em 1 s)" % pior)
	# 6) PIOR CASO: horda grande colada + crítico em todo acerto, atirando de verdade por 4 s
	zerar()
	e.limpar()
	h.m_critico = 1.0
	var horda := []
	for k in 56:
		horda.append(monstro(h.pos + Vector2(30 + (k / 7) * 14, -48 + (k % 7) * 14)))
	w.mouse_forcado = h.centro() + Vector2(300, 0)
	h.ataque_forcado = true
	var lanc0: int = ad.lancadas
	for q in 240:
		w.avancar(PASSO)
		for k in horda.size():
			horda[k].pos = h.pos + Vector2(30 + (k / 7) * 14, -48 + (k % 7) * 14)
			horda[k].vida = 1000.0
			horda[k].atordoa_t = 60.0
	h.ataque_forcado = false
	ok(ad.lancadas - lanc0 > 60 and e.emitidos > 0, "pior caso atirou (%d bolinhas, %d estalos)" % [ad.lancadas - lanc0, e.emitidos])
	ok(e.pico <= e.MAX and e.tempo.size() == e.MAX, "pior caso (horda de 56 + crítico) cabe no pool: pico %d de %d" % [e.pico, e.MAX])
	print("estalos, pior caso: %d bolinhas, %d estalos, %d barrados, pico %d/%d vagas" % [ad.lancadas - lanc0, e.emitidos, e.descartados, e.pico, e.MAX])
	_sumir(horda)
	h.m_critico = -1.0
	# 7) perfil BAIXO (poucas: efe_impactos 0,34): sem estalo nem fizzle (efeito extra); sem partículas: nada
	w.args["particulas"] = "poucas"
	zerar()
	_rajada_isolada(ad, h)
	ok(e.emitidos == 0, "perfil Baixo corta o fizzle do fim do alcance (%d)" % e.emitidos)
	zerar()
	var parede_b := _parede()
	_rajada_isolada(ad, h)
	ok(ad.acertos >= 3 and e.emitidos == 0, "perfil Baixo: sem estalo extra no acerto (%d acertos, %d estalos)" % [ad.acertos, e.emitidos])
	_sumir(parede_b)
	w.args["particulas"] = "medias"  # Médio (efe_impactos 0,67): o estalo volta, com o teto por rajada reduzido
	zerar()
	parede_b = _parede()
	_rajada_isolada(ad, h)
	ok(ad.acertos >= 3 and e.emitidos >= 1, "perfil Médio ainda estala (%d acertos, %d estalos)" % [ad.acertos, e.emitidos])
	_sumir(parede_b)
	w.args["particulas"] = "nenhuma"
	zerar()
	parede_b = _parede()
	_rajada_isolada(ad, h)
	ok(ad.acertos >= 3 and e.emitidos == 0, "sem partículas: nenhum estalo (%d)" % e.emitidos)
	_sumir(parede_b)
	# 8) "Reduzir piscadas": sem o miolo branco (só o último quadro) e o lugar espera 1,0 s
	var reduzir: bool = Config.reduzir_piscadas
	Config.reduzir_piscadas = true
	e.limpar()
	ok(e.quadro_em(e.ESTALO, float(e.DUR[e.ESTALO]), true) == 3, "reduzir piscadas mostra só as faíscas, sem o miolo branco")
	e.emitir(Vector2(10, 10), e.ESTALO, 0, 1.0)
	e.atualizar(0.6)
	ok(not e.emitir(Vector2(10, 10), e.ESTALO, 0, 1.0), "reduzir piscadas: o mesmo lugar espera 1,0 s")
	Config.reduzir_piscadas = reduzir
	w.args = args_antes
	zerar()
	ok(e.emitidos == 0 and e.ativas() == 0, "reiniciar limpa o pool de estalos")


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	var h = w.heroi
	var c = w.combate
	var ad = c.adagas
	var visual = ad.misseis_visual
	var quadros: Array = visual.quadros.duplicate()
	var missil: Dictionary = ad._proj_lista[ad._indice_proj("missil")]
	ok(missil.tex.get_width() == 24 and missil.tex.get_height() == 9, "míssil tem corpo/ogiva/aletas maiores que uma bala")
	ok(visual.quadros.size() == 8 and visual.tempo.size() == 16, "oito quadros e dezesseis vagas preparados uma vez")
	ok(visual.quadros[0].get_image().get_data() != visual.quadros[4].get_image().get_data(), "a explosão tem quadros diferentes")
	var bolinha: Dictionary = ad._proj_lista[ad._indice_proj("bala")]
	ok(bolinha.tex.get_width() == 5 and bolinha.tex.get_height() == 5, "a bala do mecha é uma bolinha 5x5 na grade de 1 px")
	var img_b: Image = bolinha.tex.get_image()
	ok(
		img_b.get_pixel(2, 2) == Color.WHITE and img_b.get_pixel(2, 0).get_luminance() < 0.15 and img_b.get_pixel(0, 0).a == 0.0,
		"a bolinha tem miolo branco, contorno escuro (destaca do chão quente) e cantos vazios (losango)"
	)
	ok(ad._bolinha(ad._indice_proj("bala")) and not ad._bolinha(ad._indice_proj("missil")), "só a bala do mecha é desenhada sem giro")
	# a RAJADA (pedido do Alisson: vários projéteis por braço): cada evento de cada braço solta n bolinhas em leque curto, todas do lado dele
	for idx in 2:
		var antes: int = ad.lancadas
		var part: int = c.fx.usados.particulas
		var passo: Dictionary = c.cfg.golpe.passos[idx]
		var vivas := {}
		for j in ad.MAX:
			if ad.a_rest[j] > 0.0:
				vivas[j] = true
		c.golpear(h, h.pos + h.ORIGEM_GOLPE, Vector2.RIGHT, passo, idx)
		var novas := []
		for j in ad.MAX:
			if ad.a_rest[j] > 0.0 and not vivas.has(j):
				novas.append(j)
		ok(int(passo.n) >= 4 and ad.lancadas - antes == int(passo.n) and novas.size() == int(passo.n), "cada evento de cada braço solta a rajada inteira")
		ok(c.fx.usados.particulas == part, "bala não espalha faíscas extras parecendo outros tiros")
		var a_min := INF
		var a_max := -INF
		var lado_ok := true
		for i in novas:
			ok(
				is_equal_approx(ad.a_vel[i], float(passo.vel)) and is_equal_approx(ad.a_dano[i], float(passo.dano) * h.m_dano),
				"velocidade e dano de cada bolinha preservados"
			)
			ok(
				is_equal_approx(ad.a_rest[i], float(passo.alcance) * (1.0 + c.bonus_nivel_golpe(h))) and is_equal_approx(ad.a_raio[i], 4.0 * sqrt(h.m_area)),
				"alcance e raio de colisão não crescem com a imagem"
			)
			var ang: float = rad_to_deg((ad.a_dir[i] as Vector2).angle())
			a_min = minf(a_min, ang)
			a_max = maxf(a_max, ang)
			# a boca do braço: combate.golpear desloca a origem `lateral` px para Vector2.RIGHT.orthogonal() = (0, -1)
			var lateral: float = (ad.a_pos[i] - (h.pos + h.ORIGEM_GOLPE)).dot(Vector2.RIGHT.orthogonal())
			lado_ok = lado_ok and signf(lateral) == signf(float(passo.lateral))
		var leque: float = float(passo.leque) * (1.0 + (h.m_area - 1.0) * 0.5)
		ok(a_max - a_min >= leque - 3.0 and a_max - a_min <= leque + 3.0, "leque curto da rajada (%.1f graus, dado %.0f)" % [a_max - a_min, leque])
		ok(lado_ok, "todas as bolinhas do braço %d saem do lado dele" % idx)
	zerar()
	var hab: Dictionary = Dados.json("v2_habilidade").misseis
	ok(int(hab.n) == 12 and is_equal_approx(float(hab.dur), 0.9), "a E mantém doze mísseis em 0,9 s")
	h.habilidade()
	passos(55)
	ok(ad.lancadas == 12, "a E real lança exatamente doze mísseis")
	for i in ad.MAX:
		if ad.a_rest[i] > 0.0:
			ok(ad.a_vel[i] == float(hab.vel), "velocidade do míssil preservada")
	zerar()
	var p: Vector2 = h.pos + Vector2(100, 0)
	var direto = monstro(p)
	var area = monstro(p + Vector2(0, 16))
	var fora = monstro(p + Vector2(0, 80))
	var passo_m := {
		"n": 1,
		"dano": 11.0,
		"vel": 270.0,
		"alcance": 320.0,
		"empurrao": 90.0,
		"atordoa": 0.12,
		"cor": [0.5, 0.95, 1.0],
		"proj": "missil",
		"expl_raio": 26.0,
		"expl_dano": 6.0
	}
	ad.lancar(h, h.pos, Vector2.RIGHT, passo_m)
	ad._acertar(0, direto, p)
	ad._acabar(0)
	ok(is_equal_approx(1000.0 - direto.vida, 11.0 * h.m_dano), "explosão não repete dano no alvo direto")
	ok(is_equal_approx(1000.0 - area.vida, 6.0 * h.m_dano) and fora.vida == 1000.0, "dano e raio em área preservados")
	ok(visual.emitidas == 1 and visual.ativas() == 1 and ad.ativas() == 0, "um impacto anima uma explosão mesmo sem projéteis em voo")
	ad.atualizar(0.1)
	ok(visual.ativas() == 1 and ad._desenha, "a explosão continua sendo redesenhada depois do voo")
	var dano_antes: float = c.dano_causado
	var nos: int = get_tree().get_node_count()
	for i in 100:
		visual.emitir(p, 26.0)
		ad.atualizar(0.01)
	ok(visual.ativas() <= 16 and visual.tempo.size() == 16 and visual.quadros == quadros, "cem efeitos reutilizam vagas e texturas")
	ok(get_tree().get_node_count() == nos and c.dano_causado == dano_antes, "efeito visual não cria nós nem causa dano")
	ad.atualizar(0.5)
	ok(visual.ativas() == 0, "a explosão termina sem deixar vaga presa")
	ad.atualizar(0.01)
	ok(not ad._desenha, "o desenho dorme quando não há projéteis nem explosões")
	zerar()
	ok(visual.emitidas == 0 and visual.ativas() == 0, "reiniciar limpa o pool visual")
	# O novo tratamento vale só para bala do mecha e míssil; as outras imagens seguem no caminho anterior.
	ok(not ad._visual_mecha(ad._indice_proj("adaga")) and not ad._visual_mecha(ad._indice_proj("plasma")), "adagas e plasma preservam seus efeitos")
	var fator_antes: float = c.fx.fator_part
	for fator in [0.25, 0.6, 1.0]:
		c.fx.fator_part = fator
		comparar_rng()
	c.fx.fator_part = fator_antes
	bocas_visuais()
	estalos_rajada()
	var reduzir: bool = Config.reduzir_piscadas
	Config.reduzir_piscadas = true
	visual.limpar()
	var nos_calmo: int = get_tree().get_node_count()
	for i in 24:
		visual.emitir(h.pos, 26.0)
		for t in [0.36, 0.27, 0.18, 0.09]:
			ok(visual.quadro_em(t, false, visual.Piscadas.ligado()) == 6, "reduzir piscadas mantém fumaça escura fixa em impactos consecutivos")
	ok(visual.ativas() == 1 and get_tree().get_node_count() == nos_calmo, "impactos coincidentes são agrupados sem novos nós no modo calmo")
	visual.limpar()
	visual.emitir(h.pos, 26.0)
	for i in 16:
		visual.emitir(h.pos + Vector2(float(i + 1) * 100.0, 0), 26.0)
	visual.emitir(h.pos, 26.0)
	ok(
		visual.emitidas == 16 and visual.pos[0] == h.pos + Vector2(0, -6),
		"saturação em regiões distintas não sobrescreve a proteção temporal do primeiro impacto"
	)
	visual.limpar()
	var amostras: Array = []
	for quadro in 180:
		if quadro % 4 == 0:
			visual.emitir(h.pos, 26.0)
		var alfa := 0.0
		for t in visual.tempo:
			alfa += t / visual.DUR  # soma da opacidade do conjunto, não apenas o índice de um quadro
		amostras.append(alfa)
		visual.atualizar(PASSO)
	for inicio in range(amostras.size() - 60):
		ok(visual.Piscadas.trocas(amostras.slice(inicio, inicio + 61)) <= 3, "impactos contínuos respeitam três trocas em qualquer janela de um segundo")
	Config.reduzir_piscadas = reduzir
	c.heroi_id = "lucas"
	ok(not ad._visual_mecha(ad._indice_proj("bala")), "a bala de outro herói não herda o tratamento do mecha")
	Herois.forcado = ""
	print("v2_mecha_projeteis falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
