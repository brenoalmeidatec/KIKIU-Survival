extends "res://testes/isolamento_v2.gd"
## A chama alta do status de fogo (v2/fx_status.gd, folhas de fonte_arte/chama/gerar_chama.py): prova a ARTE e o jeito de tocá-la.
## Parte 1 (a folha, em qualquer modo): 3 tamanhos (P, M, G) de 12 quadros a 12-15 fps, em loop; o tamanho da folha bate com o quadro do registro; alfa só 0 ou 255
## (pixel art); o ciclo emenda sem salto (do último quadro ao primeiro a troca não é maior que a pior troca do meio); a chama é alta (a altura do que é pintado passa
## de 55% da altura do monstro em todo o alcance do tamanho); o pivô fica na base e no centro.
## Parte 2 (o mundo, em qualquer modo): nenhum nó nasce com 20 monstros queimando; "Reduzir piscadas" troca de quadro no máximo 2 vezes por segundo em qualquer janela de 1 s
## (então nenhum pixel da chama troca mais que isso: cada pixel só muda quando o quadro muda), e com a opção desligada o quadro corre a 12 ou mais por segundo; duas chamas
## de monstros diferentes não começam no mesmo ponto do ciclo; perfil Baixo não toca sprite nenhum.
## Parte 3 (só com janela, sem --headless): desenha de verdade um lobo e uma elite queimando e confere que há pixels da paleta da chama acima do corpo dos dois.
## Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_chama_sprites.tscn  (imprime "v2_chama_sprites falhas=0")
const Anim := preload("res://v2/anim_golpes.gd")
const Mundo := preload("res://v2/mundo.tscn")
const Piscadas := preload("res://v2/piscadas.gd")
const PASSO := 1.0 / 60.0
const TIPO := "inimigo_cao_ossos"
const PASTA := "res://assets/v2/pixelfx/"
const CHAMAS := ["chama_p", "chama_m", "chama_g"]
const MIN_ALTURA := 0.55  # a chama pintada tem de passar disto da altura (alt) do monstro, do menor ao maior alt do tamanho dela
const ALT_MAIOR := 182.0  # o maior alt de monstro do jogo (espantalho x4); a chama G cobre dele para cima
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _nos_total(raiz: Node) -> int:
	var n := 1
	for c in raiz.get_children():
		n += _nos_total(c)
	return n


func _quadros(w, n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _ready() -> void:
	var altura := _parte_folhas()
	await _parte_mundo(altura)
	if DisplayServer.get_name() == "headless":
		print("v2_chama_sprites: sem janela, o desenho de verdade foi pulado (rode sem --headless)")
	else:
		await _parte_pixel()
	print("v2_chama_sprites falhas=", falhas)
	get_tree().quit(1 if falhas else 0)


## Recorta o quadro `q` da folha como Image.
func _quadro_img(img: Image, tam: Vector2i, colunas: int, q: int) -> Image:
	return img.get_region(Rect2i(Vector2i((q % colunas) * tam.x, (q / colunas) * tam.y), tam))


## Quantos pixels (opacos em um dos dois) diferem entre dois quadros.
func _diferenca(a: Image, b: Image) -> int:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


## Altura (px) do que é pintado no quadro, da linha mais alta com pixel opaco até o pé do quadro.
func _altura_pintada(q: Image) -> int:
	for y in q.get_height():
		for x in q.get_width():
			if q.get_pixel(x, y).a > 0.0:
				return q.get_height() - y
	return 0


## Confere as três folhas. Devolve a maior altura pintada por id (a parte do mundo e o relatório usam).
func _parte_folhas() -> Dictionary:
	var reg: Dictionary = Dados.json("v2_pixelfx")
	var efeitos: Dictionary = reg.efeitos
	var faixas: Array = reg.status.fogo.faixas
	var altura := {}
	var h_antes := 0
	for id in CHAMAS:
		ok(efeitos.has(id), "o registro tem %s" % id)
		if not efeitos.has(id):
			continue
		var e: Dictionary = efeitos[id]
		var tex := load(PASTA + str(e.arquivo)) as Texture2D
		ok(tex != null, "%s: a folha carrega" % id)
		if tex == null:
			continue
		var img := tex.get_image()
		var tam := Vector2i(int(e.quadro[0]), int(e.quadro[1]))
		var n := int(e.quadros)
		var cols := int(e.colunas)
		ok(n == 12 and float(e.fps) >= 12.0 and float(e.fps) <= 15.0 and bool(e.loop), "%s: 12 quadros a 12 a 15 fps em loop (%d, %s fps)" % [id, n, e.fps])
		ok(
			img.get_width() == tam.x * cols and img.get_height() == tam.y * ceili(float(n) / float(cols)),
			"%s: a folha %s tem o tamanho de %d quadros de %s em %d colunas" % [id, img.get_size(), n, tam, cols]
		)
		ok(
			float(e.get("fps_calmo", 0.0)) > 0.0 and float(e.fps_calmo) <= 2.0,
			"%s: o fps_calmo de 'Reduzir piscadas' é de no máximo 2 (%s)" % [id, e.get("fps_calmo", 0)]
		)
		ok(int(e.pivo[0]) == tam.x / 2 and int(e.pivo[1]) == tam.y, "%s: o pivô fica na base, no meio do quadro (%s em %s)" % [id, e.pivo, tam])
		# alfa só 0 ou 255; quadros todos diferentes; o salto do fim para o começo não passa do pior do meio; o que é pintado
		var q: Array[Image] = []
		for i in n:
			q.append(_quadro_img(img, tam, cols, i))
		var meio := 0
		var meia := false
		for i in n:
			for y in tam.y:
				for x in tam.x:
					var a := q[i].get_pixel(x, y).a
					if a != 0.0 and a != 1.0:
						meia = true
		ok(not meia, "%s: alfa só 0 ou 1 (pixel art, sem meio-tom)" % id)
		var iguais := 0
		var pior_meio := 0
		var soma := 0
		for i in n - 1:
			var d := _diferenca(q[i], q[i + 1])
			pior_meio = maxi(pior_meio, d)
			soma += d
			if d == 0:
				iguais += 1
		var emenda := _diferenca(q[n - 1], q[0])
		ok(iguais == 0, "%s: dois quadros seguidos nunca são iguais (%d iguais)" % [id, iguais])
		ok(
			float(emenda) <= float(pior_meio) * 1.25,
			"%s: o ciclo emenda sem salto (último para o primeiro: %d px; pior troca do meio: %d; vale até 125%%)" % [id, emenda, pior_meio]
		)
		ok(float(soma) / float(n - 1) > 0.0 and meio == 0, "%s: tem movimento (%d px por troca, em média)" % [id, soma / (n - 1)])
		var alto := 0
		var cheio := 0
		for i in n:
			alto = maxi(alto, _altura_pintada(q[i]))
			cheio = maxi(cheio, tam.y)
		altura[id] = alto
		ok(alto >= tam.y * 0.7 and alto < tam.y, "%s: a chama ocupa o quadro de cima a baixo mas cabe nele (%d de %d px)" % [id, alto, tam.y])
		ok(alto > h_antes, "%s: cada tamanho é mais alto que o anterior (%d > %d)" % [id, alto, h_antes])
		h_antes = alto
	# a altura: do menor ao maior alt de cada faixa, a chama pintada passa de MIN_ALTURA do alt do monstro
	var de := 0.0
	for f in faixas:
		var id := str(f.id)
		var ate := minf(float(f.alt_ate), ALT_MAIOR + 1.0)
		ok(altura.has(id) and de < ate, "faixa %s: de alt %.0f a %.0f" % [id, de, ate])
		if altura.has(id):
			var pior := float(altura[id]) / (ate - 1.0)
			ok(
				pior >= MIN_ALTURA,
				(
					"%s: chama alta, %d px pintados são %.0f%% do maior monstro dela (alt %.0f; mínimo %.0f%%)"
					% [id, altura[id], pior * 100.0, ate - 1.0, MIN_ALTURA * 100.0]
				)
			)
		de = float(f.alt_ate)
	return altura


func _parte_mundo(_altura: Dictionary) -> void:
	Anim.suave = true
	Config.temporario(Piscadas.OPCAO, false)
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	var c = w.combate
	var cf = c.fx_folha
	var st = c.fx_status
	var nos0 := _nos_total(w.glow)
	var p0: Vector2 = w.heroi.pos

	# 1. pool fixo: 20 monstros queimando e nenhum nó novo; as chamas nunca passam do limite do registro
	var lista: Array = []
	for k in 20:
		var mk = w.nascer_monstro(TIPO, p0 + Vector2(-80 + 8 * k, 60 + 12 * (k % 3)))
		mk.queimar(0.0, 30.0)
		lista.append(mk)
	_quadros(w, 120)
	var chamas := 0
	for i in st.max_monstros:
		if st._m[i] != null and st._alca[i * 3] != 0 and cf.vivo(st._alca[i * 3]):
			chamas += 1
	ok(chamas == st.max_monstros - st.reserva_elite, "chama presa em cada monstro com vaga (%d de %d)" % [chamas, st.max_monstros - st.reserva_elite])
	ok(
		chamas <= st.limite[0] and cf.ativos <= cf.MAX,
		"o pool dimensionado pelo pico: %d chamas, limite %d, fx_folha %d de %d" % [chamas, st.limite[0], cf.ativos, cf.MAX]
	)
	ok(_nos_total(w.glow) == nos0, "20 monstros queimando e nenhum nó nasceu (%d -> %d)" % [nos0, _nos_total(w.glow)])

	# 2. cada chama começa num ponto do ciclo: a fase de duas chamas não é a mesma (os monstros não marcham juntos)
	var fases := {}
	for i in st.max_monstros:
		if st._m[i] != null and cf.vivo(st._alca[i * 3]):
			fases[snappedf(cf._t[st._alca[i * 3] & 255], 0.001)] = true
	ok(fases.size() >= 4, "as chamas começam em pontos diferentes do ciclo (%d fases em %d chamas)" % [fases.size(), chamas])

	# 3. "Reduzir piscadas": quadro novo no máximo 2 vezes por segundo em qualquer janela de 1 s; desligada, corre a 12 ou mais por segundo
	for id in CHAMAS:
		Config.temporario(Piscadas.OPCAO, true)
		var troca_calma := _trocas_por_segundo(cf, id)
		Config.temporario(Piscadas.OPCAO, false)
		var troca_livre := _trocas_por_segundo(cf, id)
		ok(troca_calma <= 2, "%s: com 'Reduzir piscadas' o quadro troca %d vez(es) no pior segundo (máximo 2)" % [id, troca_calma])
		ok(troca_livre >= 12, "%s: com a opção desligada a chama é fluida, %d trocas por segundo (mínimo 12)" % [id, troca_livre])
		Config.temporario(Piscadas.OPCAO, true)
		var vistos := {}
		for i in int(7.0 / PASSO):
			vistos[cf.quadro_em(id, float(i) * PASSO)] = true
		ok(vistos.size() >= 6, "%s: mesmo calma, a chama passeia por vários quadros (%d em 7 s)" % [id, vistos.size()])
		Config.temporario(Piscadas.OPCAO, false)

	# 4. perfil Baixo: nenhum sprite extra (a chama some, o corpo em brasa do shader fica)
	Anim.suave = false
	_quadros(w, 6)
	ok(st.n_efeitos() == 0 and cf.ativos == 0, "perfil Baixo: sem chama nenhuma (%d efeitos, %d no fx_folha)" % [st.n_efeitos(), cf.ativos])
	ok(lista[0].queima_t > 0.0 and lista[0]._estado_corpo() == 0, "perfil Baixo: o shader fica desligado e o fogo segue avisando pela tinta do monstro")
	Anim.suave = true
	_quadros(w, 60)
	ok(st.n_efeitos() > 0, "perfil Médio de novo: as chamas voltam (%d)" % st.n_efeitos())
	Config.recarregar()
	w.queue_free()
	await get_tree().process_frame


## O pior número de trocas de quadro em qualquer janela de 1 s (estrita: [t, t + 1 s)) numa varredura de 8 s a 60 quadros por segundo.
func _trocas_por_segundo(cf, id: String) -> int:
	var momentos: Array[float] = []
	var ant: int = cf.quadro_em(id, 0.0)
	for i in range(1, int(8.0 / PASSO)):
		var t := float(i) * PASSO
		var q: int = cf.quadro_em(id, t)
		if q != ant:
			momentos.append(t)
			ant = q
	var pior := 0
	for a in momentos.size():
		var n := 0
		for b in range(a, momentos.size()):
			if momentos[b] - momentos[a] < 1.0 - 0.0001:
				n += 1
		pior = maxi(pior, n)
	return pior


## Com janela: um lobo e uma elite queimando, desenhados de verdade. Conta pixels com a cor EXATA da paleta da chama (a folha é NEAREST, alfa 1, na camada
## glow, acima do escurecimento: a cor sai como está na folha) com e sem fogo, e confere que há chama acima do corpo.
func _parte_pixel() -> void:
	Anim.suave = true
	Config.temporario(Piscadas.OPCAO, false)
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	var p0: Vector2 = w.heroi.pos
	var lobo = w.nascer_monstro(TIPO, p0 + Vector2(-70, 30))
	var elite = w.combate.elites.nascer(TIPO, "", p0 + Vector2(70, 30))
	ok(lobo != null and elite != null, "o lobo e a elite nasceram")
	if lobo == null or elite == null:
		w.queue_free()
		return
	_quadros(w, 20)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var antes: Image = get_viewport().get_texture().get_image()
	lobo.queimar(0.0, 30.0)
	elite.queimar(0.0, 30.0)
	_quadros(w, 40)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var depois: Image = get_viewport().get_texture().get_image()
	var pal := [Color8(204, 42, 20), Color8(238, 102, 24), Color8(255, 166, 38), Color8(255, 214, 92), Color8(255, 242, 176)]
	var n_antes := _contar(antes, pal, Rect2i(Vector2i.ZERO, antes.get_size()))
	var n_depois := _contar(depois, pal, Rect2i(Vector2i.ZERO, depois.get_size()))
	ok(n_depois > n_antes + 150, "a chama aparece na tela: %d pixels da paleta com fogo contra %d sem (a folha pequena tem ~300)" % [n_depois, n_antes])
	# acima das costas: a faixa de 130 px acima do ponto onde a chama nasce, em cada monstro, ganha pixels da paleta
	var canto: Vector2 = w.cam.retangulo().position  # o canto de cima da tela, em px do mundo (a tela do jogo é 960x540; a janela pode estar esticada)
	var k: float = float(depois.get_width()) / 960.0
	for par in [[lobo, "o lobo"], [elite, "a elite"]]:
		var m = par[0]
		var costas: Vector2 = (m.pr - canto - Vector2(0, float(m.alt) * 0.45)) * k  # onde a chama nasce (a base dela, nas costas)
		var faixa := Rect2i(Vector2i(int(costas.x - 40.0 * k), int(costas.y - 130.0 * k)), Vector2i(int(80.0 * k), int(130.0 * k)))
		var no_topo := _contar(depois, pal, faixa) - _contar(antes, pal, faixa)
		ok(no_topo >= 20, "%s: há chama subindo das costas (%d pixels a mais que sem fogo)" % [par[1], no_topo])
	var dbg := OS.get_environment("KIKIU_SALVAR_CHAMA")
	if dbg != "":
		depois.save_png(dbg)
		antes.save_png(dbg.replace(".png", "_antes.png"))
	w.queue_free()
	await get_tree().process_frame


func _contar(img: Image, pal: Array, r: Rect2i) -> int:
	var n := 0
	var lim := Rect2i(Vector2i.ZERO, img.get_size()).intersection(r)
	for y in range(lim.position.y, lim.end.y):
		for x in range(lim.position.x, lim.end.x):
			var c := img.get_pixel(x, y)
			for p in pal:
				if absf(c.r - p.r) < 0.012 and absf(c.g - p.g) < 0.012 and absf(c.b - p.b) < 0.012:
					n += 1
					break
	return n
