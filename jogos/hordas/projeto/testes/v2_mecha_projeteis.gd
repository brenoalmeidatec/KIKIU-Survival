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


## O centro do clarão que a PRÓPRIA FOLHA desenha no quadro do disparo (combo1 = braço esquerdo da tela, combo7 = direito), em px relativos aos pés: a média dos pixels
## brancos puros que o quadro de mira (combo0 / combo6) não tem. É a medida independente da tabela `bocas_projeteis` (que o código usa), conferida aqui.
func _clarao_da_folha(h, linha: int, lado: int) -> Vector2:
	var info: Dictionary = h.tipo.info
	var nomes: Array = info.nomes_colunas
	var img: Image = (h.tipo.alb as Texture2D).get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var qw: int = h.tipo.w
	var qh: int = h.tipo.h
	var dados := img.get_data()
	var largura := img.get_width()
	var col_t: int = nomes.find("combo1" if lado == 0 else "combo7")
	var col_m: int = nomes.find("combo0" if lado == 0 else "combo6")
	var soma := Vector2.ZERO
	var n := 0
	for y in qh:
		for x in qw:
			if not _branco(dados, largura, col_t * qw + x, linha * qh + y):
				continue
			var tambem := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					tambem = tambem or _branco(dados, largura, col_m * qw + x + dx, linha * qh + y + dy)
			if not tambem:
				soma += Vector2(x + 0.5, y + 0.5)
				n += 1
	if n == 0:
		return Vector2.INF
	return soma / float(n) - Vector2(qw / 2.0, float(h.tipo.pe))


func _branco(dados: PackedByteArray, largura: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= largura:
		return false
	var k := (y * largura + x) * 4
	return dados[k] >= 235 and dados[k + 1] >= 235 and dados[k + 2] >= 235 and dados[k + 3] >= 200


## Pedido do Alisson (a ideia da D.Va): o clarão de boca no cano, a rajada saindo da boca de cada braço nas 8 direções e as bolinhas a 840 px/s.
func boca_e_velocidade() -> void:
	zerar()
	var c = w.combate
	var ad = c.adagas
	var h = w.heroi
	var e = ad.estalos
	var args_antes: Dictionary = w.args.duplicate()
	w.args["particulas"] = "muitas"  # Alto: efe_impactos 1
	# 1) a velocidade: 840 nos dois braços (dobro de 420), no dado e na bolinha que sai; o alcance de 170 px é distância e continua
	for idx in 2:
		var passo: Dictionary = c.cfg.golpe.passos[idx]
		ok(is_equal_approx(float(passo.vel), 840.0), "braço %d: a bolinha voa a 840 px/s (dobro dos 420 antigos): %s" % [idx, str(passo.vel)])
		ok(is_equal_approx(float(passo.alcance), 170.0), "braço %d: o alcance de 170 px é distância e não muda com a velocidade" % idx)
		ok(bool(passo.get("clarao_boca", false)), "braço %d: o passo liga o clarão de boca (clarao_boca)" % idx)
	ad.limpar()
	c.golpear(h, h.pos + h.ORIGEM_GOLPE, Vector2.RIGHT, c.cfg.golpe.passos[0], 0)
	var vivas := 0
	for i in ad.MAX:
		if ad.a_rest[i] > 0.0:
			vivas += 1
			ok(is_equal_approx(ad.a_vel[i], 840.0 * (1.0 + float(c.armas.mods.mira) / 100.0)), "a bolinha sai a 840 px/s")
	var passos_ate_fim := 0
	while ad.ativas() > 0 and passos_ate_fim < 120:
		ad.atualizar(PASSO)
		passos_ate_fim += 1
	ok(vivas == 5 and passos_ate_fim >= 11 and passos_ate_fim <= 13, "170 px a 840 px/s: ~12 quadros de voo (%d)" % passos_ate_fim)
	# 2) sem atravessar: um monstro PEQUENO parado no caminho (raio 5 + bolinha 4), com a bolinha passando na borda (a corda do círculo é mais curta que
	# o passo de 14 px), em todas as fases de 1 px do passo, a 60, 30 e 20 Hz. Testar só o ponto de chegada deixaria passar; o teste do segmento não.
	zerar()
	var alvo = monstro(h.pos + Vector2(500, 500))
	alvo.raio = 5.0
	var passo_um: Dictionary = c.cfg.golpe.passos[0].duplicate(true)
	passo_um.n = 1
	passo_um.leque = 0
	var origem: Vector2 = h.pos + h.ORIGEM_GOLPE
	var casos := 0
	var furou := 0
	var pontual_perderia := 0
	for dt in [1.0 / 60.0, 1.0 / 30.0, 1.0 / 20.0]:
		for fase in 14:
			for lateral in [0.0, 5.0, 8.0]:
				ad.limpar()
				c.fx.limpar()
				seed(40117 + fase)
				c.golpear(h, origem, Vector2.RIGHT, passo_um, 0)
				var pos_s: Vector2 = ad.a_pos[0]
				var dir_s: Vector2 = ad.a_dir[0]
				alvo.vivo = true
				alvo.morrendo = false
				alvo.vida = alvo.vida_max
				alvo.atordoa_t = 60.0
				alvo.emp = Vector2.ZERO
				alvo.pos = pos_s + dir_s * (100.0 + float(fase)) + Vector2(-dir_s.y, dir_s.x) * lateral + Vector2(0, 6)  # o peito fica `lateral` px ao lado do caminho
				var lim: float = float(alvo.raio) + ad.a_raio[0]
				var peito: Vector2 = alvo.pos + Vector2(0, -6)
				var rest: float = ad.a_rest[0]
				var dentro := false  # o teste de PONTO (só onde a bolinha chega a cada quadro): ela cairia dentro do círculo em algum quadro?
				var andou := 0.0
				while andou < rest:
					andou += 840.0 * dt
					dentro = dentro or (pos_s + dir_s * minf(andou, rest)).distance_to(peito) <= lim
				for q in 200:
					ad.atualizar(dt)
					if ad.a_rest[0] <= 0.0:
						break
				var cruza := absf((peito - pos_s).dot(Vector2(-dir_s.y, dir_s.x))) < lim  # o caminho reto passa pelo círculo
				if cruza:
					casos += 1
					furou += 1 if ad.acertos == 0 else 0
					pontual_perderia += 0 if dentro else 1
	ok(casos >= 100 and furou == 0, "bolinha a 840 px/s não atravessa monstro pequeno: %d acertos em %d casos (furou %d)" % [casos - furou, casos, furou])
	print("sem atravessar a 840 px/s: %d casos, furou %d; só o ponto de chegada perderia %d" % [casos, furou, pontual_perderia])
	ok(pontual_perderia > 0, "o cenário é duro de verdade: um teste só do ponto de chegada perderia %d desses casos" % pontual_perderia)
	_sumir([alvo])
	# 3) a boca de cada braço, nas 8 direções: a tabela do código bate com o clarão desenhado na folha (<= 3 px) e a primeira posição de TODAS as bolinhas
	# da rajada fica na boca medida (<= 3 px); braço esquerdo (passo 0, lateral < 0) e direito (passo 1) alternam as bocas
	zerar()
	e.limpar()
	var pior_tabela := 0.0
	var pior_saida := 0.0
	for ang in 8:
		var dir := Vector2.from_angle(float(ang) * PI / 4.0)
		var linha: int = h.linha_de(dir)
		var medidas: Array = []
		for lado in 2:
			var medida: Vector2 = _clarao_da_folha(h, linha, lado)
			ok(medida.is_finite(), "linha %d lado %d: a folha tem clarão no quadro do disparo" % [linha, lado])
			medidas.append(medida)
		ok((medidas[0] as Vector2).distance_to(medidas[1]) > 20.0, "linha %d: as duas bocas são lugares diferentes (um clarão por braço)" % linha)
		for lado in 2:
			var medida: Vector2 = medidas[lado]
			var xy: Array = h.tipo.info.bocas_projeteis.canhoes[linha][lado]
			pior_tabela = maxf(pior_tabela, Vector2(xy[0], xy[1]).distance_to(medida))
			ad.limpar()
			e.limpar()
			c.golpear(h, h.pos + h.ORIGEM_GOLPE, dir, c.cfg.golpe.passos[lado], lado)
			var boca: Vector2 = h.pos + medida
			var todas := 0
			for i in ad.MAX:
				if ad.a_rest[i] > 0.0:
					todas += 1
					var d: float = ad._pos_visual(i).distance_to(boca)
					pior_saida = maxf(pior_saida, d)
					ok(d <= 3.0, "direção %d braço %d: a bolinha nasce a %.1f px da boca medida na folha (<= 3)" % [ang, lado, d])
			ok(todas == 5, "direção %d braço %d: a rajada de 5 sai da mesma boca" % [ang, lado])
			ok(e.bocas_emitidas == 1 and e.bocas_ativas() == 1, "direção %d braço %d: UM clarão de boca por rajada (%d)" % [ang, lado, e.bocas_emitidas])
			ok(
				e.boca_pos[0] == (e.boca_pos[0] as Vector2).round() and e.boca_pos[0].distance_to(boca) <= 3.0,
				"direção %d braço %d: o clarão fica na boca, em pixel inteiro" % [ang, lado]
			)
	# 3b) saem DA BOCA, não de baixo dela: com 840 px/s, 2 quadros depois (~28 px de voo) uma bolinha só ainda está a <= 4 px da linha do cano (a boca na direção do tiro);
	# com a descida de 60 px de antes ela já estava ~16 px abaixo (o braço de cima do mecha fica ~35 px acima do chão da trajetória). E no fim do alcance chega à lógica.
	var pior_linha := 0.0
	for ang in 8:
		var dir := Vector2.from_angle(float(ang) * PI / 4.0)
		for lado in 2:
			var um: Dictionary = c.cfg.golpe.passos[lado].duplicate(true)
			um.n = 1
			um.leque = 0
			ad.limpar()
			c.golpear(h, h.pos + h.ORIGEM_GOLPE, dir, um, lado)
			var xy: Array = h.tipo.info.bocas_projeteis.canhoes[h.linha_de(dir)][lado]
			var boca: Vector2 = h.pos + Vector2(xy[0], xy[1])
			ad.atualizar(PASSO)
			ad.atualizar(PASSO)
			var d_linha: float = absf((ad._pos_visual(0) - boca).dot(Vector2(-ad.a_dir[0].y, ad.a_dir[0].x)))
			var voou: float = (ad.a_pos[0] - (h.pos + h.ORIGEM_GOLPE + dir.orthogonal() * float(um.lateral) + dir * 10.0)).length()
			pior_linha = maxf(pior_linha, d_linha)
			ok(
				d_linha <= 4.0 and voou > 25.0,
				"direção %d braço %d: com %.0f px de voo a bolinha está a %.1f px da linha do cano (<= 4)" % [ang, lado, voou, d_linha]
			)
			for q in 30:
				ad.atualizar(PASSO)
				if ad.a_rest[0] <= 0.0:
					break
			ok(
				ad.a_rest[0] <= 0.0 or ad._pos_visual(0).distance_to(ad.a_pos[0]) < 0.01,
				"direção %d braço %d: o desenho chega à trajetória lógica" % [ang, lado]
			)
	print("bolinha a 2 quadros: pior distância da linha do cano %.1f px" % pior_linha)
	ok(pior_tabela <= 3.0, "a tabela bocas_projeteis difere até %.2f px do clarão da folha (<= 3)" % pior_tabela)
	print("boca: tabela x folha, pior diferença %.2f px; primeira posição da bolinha x boca medida, pior %.2f px" % [pior_tabela, pior_saida])
	# 4) o clarão é desenhado em quadros inteiros na grade de 1 px (alfa 0 ou 1), 13x13, miolo branco no começo e nenhum branco no brilho parado
	var lista: Array = e.quadros[e.BOCA]
	ok(lista.size() == 4 and float(e.DUR[e.BOCA]) >= 0.08 and float(e.DUR[e.BOCA]) <= 0.12, "clarão de boca: 3 quadros + o brilho parado, ~0,1 s")
	for q in lista.size():
		var img: Image = (lista[q] as Texture2D).get_image()
		ok(img.get_width() == 13 and img.get_height() == 13, "clarão %d: 13x13 na grade de 1 px" % q)
		var binario := true
		var branco := false
		for y in 13:
			for x in 13:
				var px := img.get_pixel(x, y)
				binario = binario and (px.a == 0.0 or px.a == 1.0)
				branco = branco or (px.a == 1.0 and px.r > 0.99 and px.g > 0.99 and px.b > 0.99)
		ok(binario, "clarão %d: sem alfa parcial" % q)
		ok(branco == (q == 0), "clarão %d: miolo branco só no primeiro quadro, o brilho parado e as faíscas não têm branco" % q)
	# 5) uma vez por rajada no jogo de verdade: atirando 3 s, o clarão acende o mesmo número de vezes que rajadas saem, sem nó novo e sem sorteio extra
	zerar()
	e.limpar()
	w.mouse_forcado = h.centro() + Vector2(300, 0)
	h.ataque_forcado = true
	var nos: int = get_tree().get_node_count()
	var lanc0: int = ad.lancadas
	var maximo := 0
	for q in 180:
		w.avancar(PASSO)
		maximo = maxi(maximo, e.bocas_ativas())
	h.ataque_forcado = false
	var rajadas: int = (ad.lancadas - lanc0) / 5
	ok(rajadas >= 14 and e.bocas_emitidas == rajadas, "atirando 3 s: %d rajadas, %d clarões de boca (um por rajada)" % [rajadas, e.bocas_emitidas])
	ok(maximo <= 2 and e.boca_tempo.size() == e.BOCA_VAGAS, "um herói, dois braços: no máximo 2 clarões acesos (pico %d)" % maximo)
	ok(get_tree().get_node_count() == nos, "o clarão de boca não cria nó")
	# 6) perfil Baixo e sem partículas: o clarão de boca conta como partícula extra e não sai (a rajada, a bolinha e o dano seguem)
	for nivel in ["poucas", "nenhuma"]:
		w.args["particulas"] = nivel
		zerar()
		e.limpar()
		c.golpear(h, h.pos + h.ORIGEM_GOLPE, Vector2.RIGHT, c.cfg.golpe.passos[0], 0)
		ok(
			ad.ativas() == 5 and e.bocas_emitidas == 0 and e.bocas_ativas() == 0,
			"perfil %s: a rajada sai e o clarão de boca não (%d)" % [nivel, e.bocas_emitidas]
		)
	w.args["particulas"] = "medias"  # Médio (0,67): o clarão volta
	zerar()
	e.limpar()
	c.golpear(h, h.pos + h.ORIGEM_GOLPE, Vector2.RIGHT, c.cfg.golpe.passos[0], 0)
	ok(e.bocas_emitidas == 1, "perfil Médio ainda acende o clarão de boca (%d)" % e.bocas_emitidas)
	w.args["particulas"] = "muitas"
	# 7) "Reduzir piscadas": sem flash e sem miolo branco, UM brilho parado por boca; atirando 3 s e parando, o lugar nunca acende e apaga acima de 2 Hz
	var reduzir: bool = Config.reduzir_piscadas
	Config.reduzir_piscadas = true
	zerar()
	e.limpar()
	ok(
		e.quadro_boca(float(e.DUR[e.BOCA]), true) == 3 and e.quadro_boca(0.01, true) == 3,
		"reduzir piscadas: o clarão é sempre o brilho parado (sem quadros, sem miolo branco)"
	)
	w.mouse_forcado = h.centro() + Vector2(300, 0)
	h.ataque_forcado = true
	var series := [[], []]  # o brilho (alfa) de cada lugar: o do braço esquerdo e o do direito
	var lugares := []
	for lado in 2:
		lugares.append(
			(
				h.pos
				+ Vector2(
					h.tipo.info.bocas_projeteis.canhoes[h.linha_de(Vector2.RIGHT)][lado][0],
					h.tipo.info.bocas_projeteis.canhoes[h.linha_de(Vector2.RIGHT)][lado][1]
				)
			)
		)
	var menor_atirando := 1.0
	for q in 240:  # 4 s: 3 s atirando e 1 s de pausa
		if q == 180:
			h.ataque_forcado = false
		w.avancar(PASSO)
		for lado in 2:
			var alfa := 0.0
			for i in e.BOCA_VAGAS:
				if e.boca_tempo[i] > 0.0 and (e.boca_pos[i] as Vector2).distance_to(lugares[lado]) < 6.0:
					alfa = maxf(alfa, e.alfa_boca(i, true))
			(series[lado] as Array).append(alfa)
			if q >= 30 and q < 175:
				menor_atirando = minf(menor_atirando, alfa)
	ok(menor_atirando >= 0.999, "reduzir piscadas: atirando, o brilho de cada boca fica parado em 1 (o menor foi %.2f)" % menor_atirando)
	var pior_troca := 0
	for lado in 2:
		var serie: Array = series[lado]
		ok(serie.max() >= 0.999 and serie[serie.size() - 1] < 0.01, "reduzir piscadas: a boca %d acende atirando e apaga depois do último tiro" % lado)
		for inicio in range(serie.size() - 60):
			pior_troca = maxi(pior_troca, e.Piscadas.trocas(serie.slice(inicio, inicio + 61)))
	ok(pior_troca <= 2, "reduzir piscadas: em qualquer janela de 1 s o clarão de boca troca no máximo 2 vezes, ou seja, nunca acima de 1 Hz (%d)" % pior_troca)
	var quadro_calmo: Image = (e.quadros[e.BOCA][3] as Texture2D).get_image()
	ok(quadro_calmo.get_pixel(6, 6).a == 1.0 and quadro_calmo.get_pixel(6, 6).get_luminance() < 0.9, "o brilho parado é âmbar, sem o miolo branco")
	Config.reduzir_piscadas = reduzir
	h.ataque_forcado = false
	w.args = args_antes
	zerar()
	ok(e.bocas_emitidas == 0 and e.bocas_ativas() == 0, "reiniciar limpa os clarões de boca")


## O TRAÇANTE da bolinha (05/11/2026, "acho que rastros"): uma linha contínua de pixels inteiros atrás da bolinha, pelo caminho desenhado, nascendo na boca e
## crescendo até ~20 px (2 px de espessura perto da bolinha); no perfil Baixo, curto (<= 6 px) e fino. O rastro antigo era 6 pixels soltos em linha reta.
func tracante() -> void:
	zerar()
	var h = w.heroi
	var c = w.combate
	var ad = c.adagas
	ok(ad.TRACO >= 16 and ad.TRACO_BAIXO <= 6, "traçante de %d px (Baixo %d)" % [ad.TRACO, ad.TRACO_BAIXO])
	for ang in 8:
		var dir := Vector2.from_angle(float(ang) * PI / 4.0)
		var um: Dictionary = c.cfg.golpe.passos[0].duplicate(true)
		um.n = 1
		um.leque = 0
		ad.limpar()
		c.golpear(h, h.pos + h.ORIGEM_GOLPE, dir, um, 0)
		var boca: Vector2 = ad._pos_visual(0)
		var pv0: Vector2 = boca.round()
		ok(ad._tracar(0, pv0, false) == 0, "direção %d: no quadro do disparo não há traço atrás do cano" % ang)
		ad.atualizar(PASSO)
		ad.atualizar(PASSO)
		var pv: Vector2 = ad._pos_visual(0).round()
		var voado: float = ad.a_visual_dist[0]
		ok(
			ad._pos_visual_em(0, voado).distance_to(boca) < 1.5,
			"direção %d: o caminho desenhado volta à boca (%.2f px)" % [ang, ad._pos_visual_em(0, voado).distance_to(boca)]
		)
		var n: int = ad._tracar(0, pv, false)
		var px := {}
		for k in n:
			var q: Vector2 = ad._traco_px[k]
			ok(q == q.round(), "direção %d: pixel do traço em posição inteira" % ang)
			px[Vector2i(q)] = true
		# contínuo: todo pixel do traço se liga (vizinhança de 8) à bolinha desenhada (o losango de raio 2 em volta de pv), sem furo no meio
		var aberto: Array = []
		var visto := {}
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if absi(dx) + absi(dy) <= 2:
					var b := Vector2i(pv) + Vector2i(dx, dy)
					visto[b] = true
					aberto.append(b)
		var ligados := 0
		while not aberto.is_empty():
			var a: Vector2i = aberto.pop_back()
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var v := a + Vector2i(dx, dy)
					if px.has(v) and not visto.has(v):
						visto[v] = true
						ligados += 1
						aberto.append(v)
		var soltos := 0
		for v in px:
			if not visto.has(v):
				soltos += 1
		ok(soltos == 0 and ligados > 0, "direção %d: o traço é contínuo e encosta na bolinha (%d pixels soltos)" % [ang, soltos])
		var baixo: int = ad._tracar(0, pv, true)
		ok(px.size() >= 16, "direção %d: traço de ~20 px com a parte grossa (%d pixels)" % [ang, px.size()])
		ok(baixo >= 1 and baixo <= ad.TRACO_BAIXO and baixo < px.size() - 10, "direção %d: perfil Baixo, traço curto e fino (%d px)" % [ang, baixo])
	ad.limpar()


## Regressão (revisão do PR #620): o clarão ficava PRESO NO MUNDO onde o tiro saiu. Andando e atirando (~72 px/s), a boca anda ~23 px entre dois tiros do mesmo
## braço: o tiro novo nunca renovava o clarão velho, abria outra vaga, e com "Reduzir piscadas" ficavam até 3 discos âmbar parados atrás do mecha, com tiros saindo
## sem brilho (vagas cheias). Agora: no máximo UM clarão por braço, sempre no pixel da boca desenhada (h.pr + a boca da folha arredondada), em todos os quadros,
## e nenhum cortado. E sem o pulo de 1 px em relação ao cano (antes arredondava h.pos + boca, fracionário, em vez de h.pr + boca arredondada).
func boca_andando() -> void:
	var c = w.combate
	var h = w.heroi
	var e = c.adagas.estalos
	var args_antes: Dictionary = w.args.duplicate()
	var reduzir: bool = Config.reduzir_piscadas
	w.args["particulas"] = "muitas"
	var tabela: Array = h.tipo.info.bocas_projeteis.canhoes
	for calmo in [false, true]:
		Config.reduzir_piscadas = calmo
		zerar()
		e.limpar()
		var nome := "reduzir piscadas" if calmo else "normal"
		var inicio: Vector2 = h.pos
		h.entrada_forcada = Vector2.DOWN  # anda para baixo atirando para a direita: a boca anda de lado em relação ao tiro
		h.ataque_forcado = true
		var pior := 0.0  # a maior distância entre um clarão aceso e a boca desenhada mais perto (px)
		var exato := true  # todo clarão aceso está EXATAMENTE em h.pr + a boca arredondada (sem o pulo de 1 px)
		var mais_por_braco := 0
		var quadros_acesos := 0
		var ambos_atirando := 0  # calmo: quadros (atirando) com os dois braços acesos
		for q in 180:
			w.mouse_forcado = h.centro() + Vector2(300, 0)
			w.avancar(PASSO)
			var no_braco := [0, 0]
			var mundo: PackedVector2Array = e.boca_pos
			for i in e.BOCA_VAGAS:
				if e.boca_tempo[i] <= 0.0:
					continue
				quadros_acesos += 1
				var perto := INF
				var lado_perto := 0
				var linha: int = h.linha_de(h.dir_olhar)  # a linha que a folha está desenhando, não qualquer uma das 8
				for lado in 2:
					var xy: Array = tabela[linha][lado]
					var d: float = (mundo[i] as Vector2).distance_to((h.pr as Vector2) + Vector2(xy[0], xy[1]).round())
					if d < perto:
						perto = d
						lado_perto = lado
				pior = maxf(pior, perto)
				exato = exato and perto == 0.0
				no_braco[lado_perto] += 1
			mais_por_braco = maxi(mais_por_braco, maxi(no_braco[0], no_braco[1]))
			if calmo and q >= 30 and no_braco[0] >= 1 and no_braco[1] >= 1:
				ambos_atirando += 1
		h.ataque_forcado = false
		h.entrada_forcada = Vector2.ZERO
		var andou: float = h.pos.distance_to(inicio)
		ok(andou > 100.0, "%s: o mecha andou atirando (%.0f px em 3 s)" % [nome, andou])
		ok(e.bocas_emitidas >= 14 and quadros_acesos > 0, "%s: atirando andando acende o clarão (%d tiros)" % [nome, e.bocas_emitidas])
		ok(pior <= 1.0, "%s: andando, o clarão fica a <= 1 px da boca desenhada em todos os quadros (pior %.1f px)" % [nome, pior])
		ok(exato, "%s: o clarão está sempre exatamente em h.pr + a boca arredondada (sem pular 1 px em relação ao cano)" % nome)
		ok(mais_por_braco <= 1, "%s: andando, no máximo UM clarão por braço (pico %d)" % [nome, mais_por_braco])
		ok(e.bocas_cortadas == 0, "%s: andando, nenhum tiro sai sem clarão por vaga cheia (%d cortados)" % [nome, e.bocas_cortadas])
		if calmo:
			ok(ambos_atirando >= 140, "reduzir piscadas: andando e atirando, os dois braços ficam com o brilho aceso (%d de 150 quadros)" % ambos_atirando)
	# coop: dois heróis com clarão ao mesmo tempo, mesmo braço: cada um na sua vaga, cada um desenhado a partir do seu herói
	if "boca_heroi" in e:
		Config.reduzir_piscadas = true
		e.limpar()
		var outro = Heroi.new()
		outro.pos = h.pos + Vector2(200.4, 50.6)
		outro.pr = outro.pos.round()
		ok(e.emitir_boca(h, Vector2(20.9, -8.5), 1, 1.0) and e.emitir_boca(outro, Vector2(20.9, -8.5), 1, 1.0), "coop: dois heróis acendem o mesmo braço")
		ok(e.bocas_ativas() == 2 and e.emitir_boca(h, Vector2(20.9, -8.5), 1, 1.0) and e.bocas_ativas() == 2, "coop: o tiro de um herói renova só a vaga dele")
		var lugares: Array = []
		for i in e.BOCA_VAGAS:
			if e.boca_tempo[i] > 0.0:
				lugares.append(e.boca_pos[i])
		ok(
			lugares.has((h.pr as Vector2) + Vector2(21, -9)) and lugares.has((outro.pr as Vector2) + Vector2(21, -9)),
			"coop: cada clarão é desenhado no cano do seu herói"
		)
		outro.pr += Vector2(7, 3)
		ok(e.boca_pos.has((outro.pr as Vector2) + Vector2(21, -9)), "coop: o clarão do outro herói anda com ele")
		e.limpar()
	Config.reduzir_piscadas = reduzir
	w.args = args_antes
	zerar()


## Regressão (revisão do PR #620): com o brilho aceso a mira vira (atirando, ou logo depois de parar) e a folha passa a desenhar o cano em outra das 8 linhas,
## 20 a 40 px dali. O clarão ficava no deslocamento da linha do tiro até aquele braço atirar de novo (até ~0,45 s no "Reduzir piscadas"). Agora, em todo
## quadro, cada clarão aceso está exatamente na boca de um braço da linha desenhada (h.pr + a tabela da folha em linha_de(dir_olhar)), sem apagar e reacender.
func boca_virando() -> void:
	var c = w.combate
	var h = w.heroi
	var e = c.adagas.estalos
	var args_antes: Dictionary = w.args.duplicate()
	var reduzir: bool = Config.reduzir_piscadas
	w.args["particulas"] = "muitas"
	var tabela: Array = h.tipo.info.bocas_projeteis.canhoes
	var miras := [Vector2(300, 0), Vector2(-300, 0), Vector2(0, -300)]  # direita atirando, esquerda atirando, cima já sem atirar
	for calmo in [false, true]:
		Config.reduzir_piscadas = calmo
		zerar()
		e.limpar()
		var nome := "reduzir piscadas" if calmo else "normal"
		var fora := 0  # quadros com um clarão aceso fora da boca da linha desenhada
		var pior := 0.0
		var virado_aceso := 0  # quadros com o brilho aceso numa linha diferente da do tiro que o acendeu
		var series := [[], []]  # calmo: aceso (1) ou não (0) em cada braço, para contar trocas
		for q in 180:
			var fase: int = q / 60
			w.mouse_forcado = h.centro() + miras[fase]
			h.ataque_forcado = fase < 2
			w.avancar(PASSO)
			var linha: int = h.linha_de(h.dir_olhar)
			var aceso := [0.0, 0.0]
			for i in e.BOCA_VAGAS:
				if e.boca_tempo[i] <= 0.0:
					continue
				var perto := INF
				var lado_perto := 0
				for lado in 2:
					var xy: Array = tabela[linha][lado]
					var d: float = (e.boca_pos[i] as Vector2).distance_to((h.pr as Vector2) + Vector2(xy[0], xy[1]).round())
					if d < perto:
						perto = d
						lado_perto = lado
				pior = maxf(pior, perto)
				if perto != 0.0:
					fora += 1
				aceso[lado_perto] = 1.0
				if "boca_linha" in e and e.boca_linha[i] != linha:
					virado_aceso += 1
			for lado in 2:
				(series[lado] as Array).append(aceso[lado])
		h.ataque_forcado = false
		ok(fora == 0, "%s: virando a mira, o clarão está sempre na boca da linha que a folha desenha (%d quadros fora, pior %.1f px)" % [nome, fora, pior])
		if calmo:
			ok(virado_aceso >= 10, "reduzir piscadas: o caso foi exercitado (brilho aceso depois de virar a mira em %d quadros)" % virado_aceso)
			var pior_troca := 0
			for lado in 2:
				var serie: Array = series[lado]
				for inicio in range(serie.size() - 60):
					pior_troca = maxi(pior_troca, e.Piscadas.trocas(serie.slice(inicio, inicio + 61)))
			ok(pior_troca <= 2, "reduzir piscadas: virar a mira não apaga e reacende o brilho (no máximo 2 trocas por segundo, %d)" % pior_troca)
	Config.reduzir_piscadas = reduzir
	w.args = args_antes
	zerar()


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
	ok(int(hab.n) == 24 and is_equal_approx(float(hab.dur), 3.75), "a E solta vinte e quatro mísseis em 3,75 s do mundo (3 s na tela)")
	h.habilidade()
	passos(55)
	ok(ad.lancadas >= 5 and ad.lancadas <= 7, "aos 0,9 s a E ainda está atirando (%d de 24)" % ad.lancadas)
	passos(180)
	ok(ad.lancadas == 24, "a E real lança exatamente vinte e quatro mísseis")
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
	boca_e_velocidade()
	boca_andando()
	tracante()
	boca_virando()
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
