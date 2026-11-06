extends "res://testes/isolamento_v2.gd"
## A chama (e o gelo, o veneno, o choque e o sangue) de elite e chefe não pode ser cortada pela borda da célula. Elite e chefe usam folhas grandes `_xN`
## com 0 px de margem nos lados, e um Sprite2D com região só desenha o retângulo da região: o shader de status (v2/status_corpo.gd) nunca rodava fora
## dele. A correção estica o quadrado em `FOLGA_NO` px (vertex) e zera o que a folga lê das células vizinhas (fragment).
## Parte 1 (qualquer modo): o monstro com nó liga o material com `folga` e `centro` certos. Parte 2 (só com janela, sem --headless): desenha de verdade
## uma célula 100% opaca, vizinha de outra célula opaca, e mede em pixel se a chama sai da célula e se a vizinha não vaza.
## Parte 3 (só com janela): o FOGO num corpo oval com contorno escuro, por 3 s de relógio: o corpo continua legível (o miolo escurecido e aquecido, poucas brasas, sem confete)
## e nenhum pixel troca de cor mais de 2 vezes por segundo (teto do v2_piscadas, MAX_TROCAS_S). As gotas que sobem são medidas em v2_chama_particulas.
## Roda: godot --path jogos/hordas/projeto res://testes/v2_status_borda.tscn  (imprime "v2_status_borda falhas=0")
const Anim := preload("res://v2/anim_golpes.gd")
const Mundo := preload("res://v2/mundo.tscn")
const StatusCorpo := preload("res://v2/status_corpo.gd")
const PASSO := 1.0 / 60.0
const CEL := 24  # lado da célula sintética, em px
const FORA := Color(0.0, 0.0, 0.35)  # o fundo do teste: o que não foi desenhado
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	await _parte_no()
	if DisplayServer.get_name() == "headless":
		print("v2_status_borda: sem janela, a medição em pixel foi pulada (rode sem --headless)")
	else:
		await _parte_pixel()
		await _parte_vivo()
	print("v2_status_borda falhas=", falhas)
	get_tree().quit(1 if falhas else 0)


## O elite queimando liga o material do shader com a folga e o centro do quadrado (offset + metade da região).
func _parte_no() -> void:
	Anim.suave = true
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	var m = w.combate.elites.nascer("inimigo_cao_ossos", "", w.heroi.pos + Vector2(60, 0))
	ok(m != null and m.sprite != null, "a elite nasceu com nó")
	if m == null:
		return
	m.queimar(0.2, 5.0)
	for i in 6:
		w.avancar(PASSO)
	var mat := m.sprite.material as ShaderMaterial
	ok(mat != null and m._estado_corpo() == StatusCorpo.FOGO, "queimando: o sprite da elite tem o material do status")
	if mat != null:
		var r: Rect2 = m.sprite.region_rect
		var folga: Variant = mat.get_shader_parameter("folga")
		var centro: Variant = mat.get_shader_parameter("centro")
		ok(folga is Vector2 and folga.x > 0.0 and folga.y > 0.0, "o material leva a folga do quadrado (%s)" % [folga])
		ok(
			centro is Vector2 and centro == m.sprite.offset + r.size * 0.5,
			"o material leva o centro do quadrado (%s, esperado %s)" % [centro, m.sprite.offset + r.size * 0.5]
		)
		ok(
			float(folga.x if folga is Vector2 else 0.0) >= 2.0 and float(folga.y if folga is Vector2 else 0.0) >= 8.0,
			"a folga cobre o arco do choque (2 px) e a chama (8 px)"
		)
	m.queima_t = 0.0
	for i in 6:
		w.avancar(PASSO)
	ok(m.sprite.material == null, "o fogo acabou: o sprite volta sem material")
	w.queue_free()
	await get_tree().process_frame


## O pixel é o fundo (não foi desenhado)? A cor sai do render com arredondamento de 8 bits, então compara com tolerância.
func _vazio(c: Color) -> bool:
	return absf(c.r - FORA.r) < 0.02 and absf(c.g - FORA.g) < 0.02 and absf(c.b - FORA.b) < 0.02


## Desenha a célula opaca com o fogo ligado e mede a chama fora dela.
func _parte_pixel() -> void:
	var atlas := Image.create(CEL * 2, CEL, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.45, 0.45, 0.45, 1.0))  # as duas células opacas, sem margem nenhuma
	var tex := ImageTexture.create_from_image(atlas)
	var meio := CEL  # a célula do teste é a da direita; a da esquerda é a vizinha que não pode vazar
	var margem := 12
	var sv := SubViewport.new()
	sv.size = Vector2i(CEL + margem * 2, CEL + margem * 2)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var fundo := ColorRect.new()
	fundo.color = FORA
	fundo.size = Vector2(sv.size)
	sv.add_child(fundo)
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = Rect2(meio, 0, CEL, CEL)
	s.centered = false
	s.offset = Vector2(-CEL / 2.0, -CEL)  # como o monstro: x centrado, pés na origem
	s.position = Vector2(margem + CEL / 2.0, margem + CEL)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := StatusCorpo.material_no(3.0)
	mat.set_shader_parameter("estado", float(StatusCorpo.FOGO))
	mat.set_shader_parameter("regiao", Vector4(meio, 0, CEL, CEL))
	mat.set_shader_parameter("centro", s.offset + Vector2(CEL, CEL) * 0.5)
	s.material = mat
	sv.add_child(s)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = sv.get_texture().get_image()
	ok(img != null and img.get_width() == sv.size.x, "o teste conseguiu a imagem da janela")
	if img == null or img.is_empty():
		return
	# a célula ocupa [margem, margem + CEL) nos dois eixos da imagem
	var x0 := margem
	var y0 := margem
	var x1 := margem + CEL
	var y1 := margem + CEL
	var dentro_ok := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			if not _vazio(img.get_pixel(x, y)):
				dentro_ok += 1
	ok(dentro_ok == CEL * CEL, "a célula continua inteira desenhada (%d de %d px)" % [dentro_ok, CEL * CEL])
	# o fogo tinge o corpo e não pinta nada fora dele: a borda de cima e as dos lados da célula ficam vazias (as gotas são de v2/chama_gotas.gd)
	var fora_borda := 0
	for x in range(x0, x1):
		if not _vazio(img.get_pixel(x, y0 - 1)):
			fora_borda += 1
	for y in range(y0, y1):
		if not _vazio(img.get_pixel(x0 - 1, y)) or not _vazio(img.get_pixel(x1, y)):
			fora_borda += 1
	ok(fora_borda == 0, "o fogo não pinta fora da célula (%d px)" % fora_borda)
	# a folga lê as células vizinhas da folha: o que não é chama tem de ficar transparente (o fundo)
	var vazou := 0
	var fora_da_folga := 0
	for y in range(y0 - 3, y1 + 3):
		for x in [x0 - 4, x0 - 3, x1 + 2, x1 + 3]:  # além do alcance do fogo (2 px dos lados)
			if not _vazio(img.get_pixel(x, y)):
				vazou += 1
			fora_da_folga += 1
	ok(vazou == 0, "a célula vizinha da folha não vaza para a folga (%d de %d px)" % [vazou, fora_da_folga])
	# nada desenhado fora do retângulo da célula + folga
	var f := StatusCorpo.FOLGA_NO
	var alem := 0
	for y in img.get_height():
		for x in img.get_width():
			var fx := x < x0 - int(f.x) or x >= x1 + int(f.x)
			var fy := y < y0 - int(f.y) or y >= y1 + int(f.y)
			if (fx or fy) and not _vazio(img.get_pixel(x, y)):
				alem += 1
	ok(alem == 0, "nada passa da folga do quadrado (%d px)" % alem)
	var dbg := OS.get_environment("KIKIU_SALVAR_BORDA")
	if dbg != "":
		var g := Image.create(img.get_width() * 8, img.get_height() * 8, false, Image.FORMAT_RGBA8)
		g.copy_from(img)
		g.resize(img.get_width() * 8, img.get_height() * 8, Image.INTERPOLATE_NEAREST)
		g.save_png(dbg)
	sv.queue_free()


func _perto(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.03 and absf(a.g - b.g) < 0.03 and absf(a.b - b.b) < 0.03


## Um corpo oval de contorno escuro queimando por 3 s: legível, sem confete, línguas suaves e nenhum pixel piscando.
func _parte_vivo() -> void:
	var atlas := Image.create(CEL, CEL, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var corpo := {}  # Vector2i -> true: o oval (rx 9, ry 5, centro 12,14)
	for y in CEL:
		for x in CEL:
			var e := pow((x - 12.0) / 9.0, 2.0) + pow((y - 14.0) / 5.0, 2.0)
			if e <= 1.0:
				corpo[Vector2i(x, y)] = true
	var interior := []  # sem contorno e sem a faixa de 2 px logo abaixo da borda de cima
	for k in corpo:
		var borda := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not corpo.has(k + d):
				borda = true
		atlas.set_pixelv(k, Color(0.04, 0.04, 0.04, 1.0) if borda else Color(0.5, 0.5, 0.5, 1.0))
		if not borda and corpo.has(k - Vector2i(0, 1)) and corpo.has(k - Vector2i(0, 2)):
			interior.append(k)
	var tex := ImageTexture.create_from_image(atlas)
	var margem := 12
	var sv := SubViewport.new()
	sv.size = Vector2i(CEL + margem * 2, CEL + margem * 2)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var fundo := ColorRect.new()
	fundo.color = FORA
	fundo.size = Vector2(sv.size)
	sv.add_child(fundo)
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, CEL, CEL)
	s.centered = false
	s.position = Vector2(margem, margem)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := StatusCorpo.material_no(7.0)
	mat.set_shader_parameter("estado", float(StatusCorpo.FOGO))
	mat.set_shader_parameter("regiao", Vector4(0, 0, CEL, CEL))
	mat.set_shader_parameter("centro", Vector2(CEL, CEL) * 0.5)
	s.material = mat
	sv.add_child(s)
	for i in 4:
		await get_tree().process_frame
	var quadros: Array[Image] = []
	var tempos: Array[int] = []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await RenderingServer.frame_post_draw
		var im: Image = sv.get_texture().get_image()
		if im == null or im.is_empty():
			ok(false, "o teste conseguiu a imagem do corpo queimando")
			sv.queue_free()
			return
		quadros.append(im)
		tempos.append(Time.get_ticks_msec() - t0)
	ok(quadros.size() >= 30, "o corpo queimando rendeu quadros suficientes (%d)" % quadros.size())
	# 1. o corpo fica legível: o miolo é o cinza escurecido e aquecido, e poucos pixels viram brasa
	var contagem := {}  # a cor mais comum do miolo (a conta exata depende do render): é o corpo escurecido, sem brasa
	for k in interior:
		var h := quadros[0].get_pixel(k.x + margem, k.y + margem).to_html(false)
		contagem[h] = int(contagem.get(h, 0)) + 1
	var base := Color.BLACK
	var mais := 0
	for h in contagem:
		if contagem[h] > mais:
			mais = contagem[h]
			base = Color(h)
	ok(base.r > base.g and base.g > base.b and base.r < 0.5, "o miolo é o corpo escurecido e aquecido (%s)" % base.to_html(false))
	var soma_brasa := 0.0
	var pior_brasa := 0.0
	for im in quadros:
		var brasa := 0
		for k in interior:
			if not _perto(im.get_pixel(k.x + margem, k.y + margem), base):
				brasa += 1
		var f := float(brasa) / float(interior.size())
		soma_brasa += f
		pior_brasa = maxf(pior_brasa, f)
	var media_brasa := soma_brasa / float(quadros.size())
	ok(media_brasa >= 0.005 and media_brasa <= 0.08, "poucas brasas no corpo: %.1f%% do miolo em média (de 0,5%% a 8%%)" % (media_brasa * 100.0))
	ok(pior_brasa <= 0.15, "nenhum quadro vira confete: no máximo %.1f%% do miolo em brasa (teto 15%%)" % (pior_brasa * 100.0))
	# 2. nenhum pixel troca de cor mais que 2 vezes em qualquer janela de 1 s (o teto do v2_piscadas é MAX_TROCAS_S; aqui o alvo é 2)
	var pior := 0
	var pior_xy := Vector2i.ZERO
	for y in sv.size.y:
		for x in sv.size.x:
			var trocas: Array[int] = []
			var ant: Color = quadros[0].get_pixel(x, y)
			for i in range(1, quadros.size()):
				var c: Color = quadros[i].get_pixel(x, y)
				if not _perto(c, ant) or absf(c.a - ant.a) > 0.01:
					trocas.append(tempos[i])
					ant = c
			for a in trocas.size():
				var q := 0
				for b in range(a, trocas.size()):
					if trocas[b] - trocas[a] < 1000:
						q += 1
				if q > pior:
					pior = q
					pior_xy = Vector2i(x - margem, y - margem)
	ok(pior <= 2, "nenhum pixel troca de cor mais que 2 vezes por segundo (pior: %d em %s)" % [pior, pior_xy])
	sv.queue_free()


## A linha (y) do pixel de corpo mais alto da coluna x do oval.
func _topo_do_corpo(corpo: Dictionary, x: int) -> int:
	for y in CEL:
		if corpo.has(Vector2i(x, y)):
			return y
	return 0
