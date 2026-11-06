extends "res://testes/isolamento_v2.gd"
## A chama do fogo DENTRO do monstro (v2/status_corpo.gd lê as folhas de fonte_arte/chama/gerar_chama.py e pinta só onde o corpo tem alfa 1).
## Parte 1 (a arte, em qualquer modo): 3 folhas de ladrilho (P, M, G) de 12 quadros, alfa só 0 ou 255, o ladrilho emenda no eixo x (nenhum contorno no meio da
## chama), o ciclo emenda sem salto, e os números dos dados fazem sentido (altura ~40%, sobra de 0 a 2 px, 12 a 15 quadros por segundo, no máximo 2 com
## "Reduzir piscadas"). Parte 2 (o mundo, em qualquer modo): o pool de sprites de chama NÃO existe mais (nem no fx_folha, nem no fx_status, nem nos dados) e 20
## monstros queimando não criam nó nem efeito; os dois materiais (o do lote e o de elite e chefe) levam as folhas e o ritmo, que segue a opção
## "Reduzir piscadas"; perfil Baixo não liga o shader.
## Parte 3 (só com janela, sem --headless): desenha de verdade. (a) a altura da chama é a fração dos dados da célula, em 5 alturas de célula; (b) num monstro
## sintético de contorno escuro, pernas e rabo fino, NENHUM pixel pintado cai fora da silhueta mais a sobra, o contorno escuro do bicho fica por cima da chama,
## a chama aparece mas o corpo continua legível; (c) a chama troca de quadro a 12 ou mais por segundo e, com "Reduzir piscadas", nenhum pixel troca de cor mais
## de 2 vezes por segundo; (d) no mundo, o elite queimando não pinta fora da célula + sobra (e o lobo do lote queima).
## Roda: godot --path jogos/hordas/projeto res://testes/v2_chama_corpo.tscn  (imprime "v2_chama_corpo falhas=0")
const Anim := preload("res://v2/anim_golpes.gd")
const Mundo := preload("res://v2/mundo.tscn")
const Piscadas := preload("res://v2/piscadas.gd")
const StatusCorpo := preload("res://v2/status_corpo.gd")
const PASSO := 1.0 / 60.0
const TIPO := "inimigo_cao_ossos"
const PASTA := "res://assets/v2/pixelfx/status/"
const FORA := Color(0.0, 0.0, 0.35)  # o fundo do teste: o que não foi desenhado
const MARGEM := 12  # px em volta da célula no SubViewport (a folga do quadrado do elite é 4 x 9)
## A paleta do gerador (gerar_chama.py): vermelho, laranja, âmbar, amarelo, miolo, o contorno da língua e as brasas.
const PALETA := [
	Color8(204, 42, 20), Color8(238, 102, 24), Color8(255, 166, 38), Color8(255, 214, 92), Color8(255, 242, 176), Color8(88, 14, 12), Color8(255, 190, 60)
]
var falhas := 0
var _dados: Dictionary = {}


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _nos_total(raiz: Node) -> int:
	var n := 1
	for c in raiz.get_children():
		n += _nos_total(c)
	return n


## `StatusCorpo.ritmo` por chamada dinâmica: num commit sem ela (o que o teste tem de reprovar) o teste falha em vez de nem carregar.
func _ritmo(mat: ShaderMaterial) -> void:
	var sc: Script = StatusCorpo
	sc.call("ritmo", mat)


func _quadros(w, n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _ready() -> void:
	_dados = Dados.json("v2_pixelfx").get("status", {}).get("fogo", {}).get("corpo", {})
	_parte_folhas()
	await _parte_mundo()
	if DisplayServer.get_name() == "headless":
		print("v2_chama_corpo: sem janela, o desenho de verdade foi pulado (rode sem --headless)")
	else:
		await _parte_altura()
		await _parte_silhueta()
		await _parte_mundo_pixel()
	print("v2_chama_corpo falhas=", falhas)
	get_tree().quit(1 if falhas else 0)


# ------------------------------------------------------------------ parte 1: a arte e os dados


func _quadro_img(img: Image, tam: Vector2i, q: int) -> Image:
	return img.get_region(Rect2i(Vector2i((q % 6) * tam.x, (q / 6) * tam.y), tam))


func _diferenca(a: Image, b: Image) -> int:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func _parte_folhas() -> void:
	ok(not _dados.is_empty(), "os dados têm status.fogo.corpo")
	var alt := float(_dados.get("altura", 0.0))
	var sobra := float(_dados.get("sobra", -1.0))
	ok(alt >= 0.3 and alt <= 0.5, "a chama tem de 30%% a 50%% da célula (dados: %s)" % alt)
	ok(sobra >= 0.0 and sobra <= 2.0, "a ponta passa do contorno em 0 a 2 px (dados: %s)" % sobra)
	ok(
		float(_dados.get("quadros_s", 0.0)) >= 12.0 and float(_dados.get("quadros_s", 0.0)) <= 15.0,
		"12 a 15 quadros por segundo (%s)" % _dados.get("quadros_s")
	)
	ok(
		float(_dados.get("quadros_calmo", 9.0)) > 0.0 and float(_dados.get("quadros_calmo", 9.0)) <= 2.0,
		"com 'Reduzir piscadas', no máximo 2 quadros por segundo (%s)" % _dados.get("quadros_calmo")
	)
	var corte: Array = _dados.get("corte", [0, 0])
	var alturas := {}
	for t in ["p", "m", "g"]:
		var tex := load(PASTA + "chama_%s.png" % t) as Texture2D
		ok(tex != null, "chama_%s: a folha carrega" % t)
		if tex == null:
			continue
		var img := tex.get_image()
		var tam := Vector2i(img.get_width() / 6, img.get_height() / 2)
		alturas[t] = tam.y
		ok(img.get_width() == tam.x * 6 and img.get_height() == tam.y * 2, "chama_%s: 6 colunas x 2 linhas de ladrilhos (%s)" % [t, img.get_size()])
		var q: Array[Image] = []
		for i in 12:
			q.append(_quadro_img(img, tam, i))
		var meia := false
		var contorno_no_meio := 0
		var cont := Color8(88, 14, 12)
		for i in 12:
			for y in tam.y:
				for x in tam.x:
					var c := q[i].get_pixel(x, y)
					if c.a != 0.0 and c.a != 1.0:
						meia = true
					# o ladrilho emenda: um pixel de contorno (fora a base) sem nenhum vizinho vazio, contando a volta no eixo x, é uma costura
					if c.a == 1.0 and c.is_equal_approx(cont) and y < tam.y - 1:
						var vizinhos := [
							q[i].get_pixel((x + 1) % tam.x, y).a,
							q[i].get_pixel((x + tam.x - 1) % tam.x, y).a,
							q[i].get_pixel(x, y - 1).a if y > 0 else 0.0,
							q[i].get_pixel(x, y + 1).a
						]
						if not vizinhos.has(0.0):
							contorno_no_meio += 1
		ok(not meia, "chama_%s: alfa só 0 ou 1 (pixel art)" % t)
		ok(contorno_no_meio == 0, "chama_%s: o ladrilho emenda no eixo x, sem costura (%d contornos no meio)" % [t, contorno_no_meio])
		var iguais := 0
		var pior := 0
		for i in 11:
			var d := _diferenca(q[i], q[i + 1])
			pior = maxi(pior, d)
			if d == 0:
				iguais += 1
		var emenda := _diferenca(q[11], q[0])
		ok(iguais == 0, "chama_%s: dois quadros seguidos nunca são iguais (%d iguais)" % [t, iguais])
		ok(float(emenda) <= float(pior) * 1.25, "chama_%s: o ciclo emenda sem salto (%d px; pior troca do meio %d)" % [t, emenda, pior])
	ok(
		alturas.has("p") and alturas.has("m") and alturas.has("g") and alturas.p < alturas.m and alturas.m < alturas.g,
		"os três ladrilhos crescem (%s)" % [alturas]
	)
	if alturas.has("p") and alturas.has("m") and alturas.has("g") and corte.size() == 2:
		ok(
			float(alturas.p) >= 0.85 * float(corte[0]) and float(alturas.p) <= 1.15 * float(corte[0]),
			"o ladrilho P serve até a altura de corte P (%s e %s)" % [alturas.p, corte[0]]
		)
		ok(
			float(alturas.m) >= 0.85 * float(corte[1]) and float(alturas.m) <= 1.15 * float(corte[1]),
			"o ladrilho M serve até a altura de corte M (%s e %s)" % [alturas.m, corte[1]]
		)
		ok(float(alturas.g) >= alt * 182.0, "o ladrilho G cobre a chama do maior monstro do jogo, de alt 182 (%s px)" % alturas.g)


# ------------------------------------------------------------------ parte 2: o mundo


func _parte_mundo() -> void:
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
	var p0: Vector2 = w.heroi.pos
	# o pool de sprites de chama foi removido
	var reg: Dictionary = Dados.json("v2_pixelfx")
	ok(
		not (reg.efeitos as Dictionary).has("chama_p") and not cf.tem("chama_p") and not cf.tem("chama_m") and not cf.tem("chama_g"),
		"o registro do fx_folha não tem folha de chama"
	)
	ok(
		not (reg.status as Dictionary).has("max_monstros") and not (reg.status as Dictionary).has("limite"),
		"os dados não têm pool de monstros nem limite de chamas"
	)
	ok(st.get("max_monstros") == null and not st.has_method("id_fogo"), "o fx_status não tem mais pool de chama")
	ok(cf.MAX == 48, "o teto do fx_folha voltou a 48 (%d)" % cf.MAX)
	var nos0 := _nos_total(w.glow)
	for k in 20:
		var mk = w.nascer_monstro(TIPO, p0 + Vector2(-80 + 8 * k, 60 + 12 * (k % 3)))
		mk.queimar(0.0, 30.0)
	_quadros(w, 90)
	ok(st.n_efeitos() == 0 and cf.ativos == 0, "20 monstros queimando e nenhum sprite de chama (%d efeitos, %d no fx_folha)" % [st.n_efeitos(), cf.ativos])
	ok(_nos_total(w.glow) == nos0, "e nenhum nó nasceu (%d -> %d)" % [nos0, _nos_total(w.glow)])
	# os dois materiais levam as folhas e o ritmo
	var sc: Script = StatusCorpo
	var tem_ritmo: bool = sc.get_script_method_list().any(func(m): return m.name == "ritmo")
	var elite = c.elites.nascer(TIPO, "", p0 + Vector2(60, 0))
	if elite != null:
		elite.queimar(0.0, 30.0)
	_quadros(w, 6)
	var mats := {"lote": w.horda._mat_sprite, "elite": elite.sprite.material if elite != null and elite.sprite != null else null}
	for nome in mats:
		var mat = mats[nome]
		ok(mat is ShaderMaterial, "o material do %s existe" % nome)
		if not (mat is ShaderMaterial):
			continue
		ok(
			(
				mat.get_shader_parameter("chama_p") is Texture2D
				and mat.get_shader_parameter("chama_m") is Texture2D
				and mat.get_shader_parameter("chama_g") is Texture2D
			),
			"o material do %s leva as três folhas da chama" % nome
		)
		ok(
			(
				absf(float(mat.get_shader_parameter("chama_alt")) - float(_dados.get("altura", 0.0))) < 0.001
				and float(mat.get_shader_parameter("chama_sobra")) == float(_dados.get("sobra", -1.0))
			),
			(
				"o material do %s leva a altura (%s) e a sobra (%s) dos dados"
				% [nome, mat.get_shader_parameter("chama_alt"), mat.get_shader_parameter("chama_sobra")]
			)
		)
		if tem_ritmo:
			Config.temporario(Piscadas.OPCAO, false)
			_ritmo(mat)
			ok(
				float(mat.get_shader_parameter("chama_fps")) >= 12.0 and float(mat.get_shader_parameter("calmo")) == 0.0,
				"%s: sem 'Reduzir piscadas' a chama corre a %s quadros por segundo" % [nome, mat.get_shader_parameter("chama_fps")]
			)
			Config.temporario(Piscadas.OPCAO, true)
			_ritmo(mat)
			ok(
				float(mat.get_shader_parameter("chama_fps")) <= 2.0 and float(mat.get_shader_parameter("calmo")) == 1.0,
				"%s: com 'Reduzir piscadas' a chama anda a %s quadros por segundo" % [nome, mat.get_shader_parameter("chama_fps")]
			)
			Config.temporario(Piscadas.OPCAO, false)
		else:
			ok(false, "o StatusCorpo tem o `ritmo` (a chama segue 'Reduzir piscadas')")
	# perfil Baixo: sem shader de status (o monstro só é tingido) e nenhum efeito extra
	var lobo = w.nascer_monstro(TIPO, p0 + Vector2(-60, 0))
	lobo.queimar(0.0, 30.0)
	_quadros(w, 6)
	ok(lobo._estado_corpo() == StatusCorpo.FOGO, "perfil Médio: o lobo queimando tem o fogo no corpo")
	Anim.suave = false
	_quadros(w, 6)
	ok(lobo._estado_corpo() == StatusCorpo.NADA and lobo.queima_t > 0.0, "perfil Baixo: o shader do fogo fica desligado e o fogo segue avisando pela tinta")
	ok(st.n_efeitos() == 0 and cf.ativos == 0, "perfil Baixo: sem efeito extra (%d)" % st.n_efeitos())
	Anim.suave = true
	Config.recarregar()
	w.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------ parte 3: desenho de verdade


## O pixel (bytes RGBA de uma Image) é o fundo do teste (não foi desenhado)? A cor sai do render com arredondamento de 8 bits: compara com tolerância.
func _vazio(d: PackedByteArray, i: int) -> bool:
	return absi(d[i]) < 6 and absi(d[i + 1]) < 6 and absi(int(d[i + 2]) - 89) < 6


func _paleta(d: PackedByteArray, i: int) -> bool:
	for p in PALETA:
		if absi(d[i] - int(p.r8)) <= 3 and absi(d[i + 1] - int(p.g8)) <= 3 and absi(d[i + 2] - int(p.b8)) <= 3:
			return true
	return false


## Monta um SubViewport com o sprite (material_no, estado FOGO) desenhando a célula `atlas` inteira, pés na base, e devolve {sv, mat}. A célula fica a MARGEM px da borda.
func _montar(atlas: Image) -> Dictionary:
	var cw := atlas.get_width()
	var ch := atlas.get_height()
	var sv := SubViewport.new()
	sv.size = Vector2i(cw + MARGEM * 2, ch + MARGEM * 2)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var fundo := ColorRect.new()
	fundo.color = FORA
	fundo.size = Vector2(sv.size)
	sv.add_child(fundo)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(atlas)
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, cw, ch)
	s.centered = false
	s.position = Vector2(MARGEM, MARGEM)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := StatusCorpo.material_no(5.0)
	mat.set_shader_parameter("estado", float(StatusCorpo.FOGO))
	mat.set_shader_parameter("regiao", Vector4(0, 0, cw, ch))
	mat.set_shader_parameter("centro", Vector2(cw, ch) * 0.5)
	s.material = mat
	sv.add_child(s)
	return {"sv": sv, "mat": mat}


func _capturar(sv: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	var im: Image = sv.get_texture().get_image()
	if im != null and not im.is_empty():
		im.convert(Image.FORMAT_RGBA8)
	return im


## (a) A altura da chama numa célula toda opaca (corpo cinza sem contorno): o pixel de chama mais alto, em 1,3 s de quadros, é a fração dos dados da célula.
func _parte_altura() -> void:
	Anim.suave = true
	Config.temporario(Piscadas.OPCAO, false)
	var frac := float(_dados.get("altura", 0.4))
	for ch: int in [48, 64, 100, 128, 176]:
		var atlas := Image.create(48, ch, false, Image.FORMAT_RGBA8)
		atlas.fill(Color(0.5, 0.5, 0.5, 1.0))
		var cena := _montar(atlas)
		var sv: SubViewport = cena.sv
		for i in 4:
			await get_tree().process_frame
		var topo := ch  # a linha (da célula) do pixel de chama mais alto
		var t0 := Time.get_ticks_msec()
		var n := 0
		while Time.get_ticks_msec() - t0 < 1300:
			var im := await _capturar(sv)
			if im == null or im.is_empty():
				ok(false, "o teste conseguiu a imagem da célula de %d px" % ch)
				break
			n += 1
			var d := im.get_data()
			var w := im.get_width()
			for y in ch:
				var achou := false
				for x in 48:
					if _paleta(d, ((y + MARGEM) * w + x + MARGEM) * 4):
						achou = true
						break
				if achou:
					topo = mini(topo, y)
					break
		var alt := ch - topo
		var esperado := roundf(frac * float(ch))
		ok(n >= 30, "célula %d: quadros capturados (%d)" % [ch, n])
		ok(
			float(alt) <= esperado and float(alt) >= esperado * 0.8,
			"célula %d: a chama chega a %d px, esperado %.0f (%.0f%% da célula, de 80%% a 100%% do alvo)" % [ch, alt, esperado, frac * 100.0]
		)
		sv.queue_free()


## (b) e (c): um monstro sintético (corpo oval de contorno escuro, duas pernas com um vão, um rabo fino) queimando em 3 s com a opção desligada e em 3 s com ela ligada.
func _parte_silhueta() -> void:
	Anim.suave = true
	var cw := 48
	var ch := 64
	var sobra := int(_dados.get("sobra", 1))
	var corpo := {}
	for y in ch:
		for x in cw:
			var e := pow((x - 22.0) / 18.0, 2.0) + pow((y - 30.0) / 24.0, 2.0)
			var perna := (x >= 12 and x < 32 and y >= 50 and y < 64) and not (x >= 20 and x < 25)  # duas pernas com um vão
			var rabo := x >= 38 and x < 40 and y >= 24 and y < 62  # um rabo fino de 2 px, que sobe ao lado do corpo
			if e <= 1.0 or perna or rabo:
				corpo[Vector2i(x, y)] = true
	var atlas := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var contorno := []
	var miolo := 0
	for k in corpo:
		var borda := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not corpo.has(k + d):
				borda = true
		atlas.set_pixelv(k, Color(0.04, 0.04, 0.04, 1.0) if borda else Color(0.5, 0.5, 0.5, 1.0))
		if borda:
			contorno.append(k)
		else:
			miolo += 1
	# o permitido: o corpo dilatado em `sobra` px (quadrado)
	var permitido := {}
	for k in corpo:
		for dy in range(-sobra, sobra + 1):
			for dx in range(-sobra, sobra + 1):
				permitido[k + Vector2i(dx, dy)] = true
	var hf := roundf(float(_dados.get("altura", 0.4)) * float(ch))
	for calmo in [false, true]:
		Config.temporario(Piscadas.OPCAO, calmo)
		var cena := _montar(atlas)
		var sv: SubViewport = cena.sv
		_ritmo(cena.mat)
		for i in 4:
			await get_tree().process_frame
		var imgs: Array[PackedByteArray] = []
		var tempos: Array[int] = []
		var t0 := Time.get_ticks_msec()
		var w := sv.size.x
		var h := sv.size.y
		while Time.get_ticks_msec() - t0 < 3000:
			var im := await _capturar(sv)
			if im == null or im.is_empty():
				ok(false, "o teste conseguiu a imagem do monstro queimando")
				sv.queue_free()
				return
			imgs.append(im.get_data())
			tempos.append(Time.get_ticks_msec() - t0)
		var rot := "com 'Reduzir piscadas'" if calmo else "sem 'Reduzir piscadas'"
		ok(imgs.size() >= 60, "%s: o monstro queimando rendeu quadros suficientes (%d)" % [rot, imgs.size()])
		# (b) nenhum pixel pintado fora da silhueta + sobra; o contorno do bicho fica; a chama aparece sem comer o corpo
		var fora := 0
		var fora_xy := Vector2i.ZERO
		var contorno_comido := 0
		var chama_dentro := 0
		var baixo_dentro := 0
		var baixo_chama := 0
		for d in imgs:
			for y in h:
				for x in w:
					var i := (y * w + x) * 4
					var k := Vector2i(x - MARGEM, y - MARGEM)
					if not _vazio(d, i) and not permitido.has(k):
						fora += 1
						fora_xy = k
			for k in contorno:
				var i: int = ((k.y + MARGEM) * w + k.x + MARGEM) * 4
				if _paleta(d, i):
					contorno_comido += 1
			for k in corpo:
				var i: int = ((k.y + MARGEM) * w + k.x + MARGEM) * 4
				var chama := _paleta(d, i)
				if chama:
					chama_dentro += 1
		for d in imgs:
			for k in corpo:
				if float(ch - k.y) <= hf and atlas.get_pixelv(k).r > 0.2:  # o miolo (sem contorno) da faixa da chama
					baixo_dentro += 1
					if _paleta(d, ((k.y + MARGEM) * w + k.x + MARGEM) * 4):
						baixo_chama += 1
		ok(fora == 0, "%s: nenhum pixel pintado fora da silhueta + %d px (%d; o último em %s)" % [rot, sobra, fora, fora_xy])
		ok(contorno_comido == 0, "%s: o contorno escuro do bicho fica por cima da chama (%d pixels de contorno viraram chama)" % [rot, contorno_comido])
		ok(
			float(chama_dentro) / float(imgs.size()) >= 60.0,
			"%s: a chama aparece no corpo (%.0f pixels por quadro)" % [rot, float(chama_dentro) / float(imgs.size())]
		)
		var cobre := float(baixo_chama) / float(maxi(baixo_dentro, 1))
		ok(cobre >= 0.15 and cobre <= 0.8, "%s: a chama cobre de 15%% a 80%% do miolo da faixa baixa; o monstro não some (%.0f%%)" % [rot, cobre * 100.0])
		# (c) fluidez e piscadas
		var trocas: Array[int] = []
		for i in range(1, imgs.size()):
			if imgs[i] != imgs[i - 1]:
				trocas.append(tempos[i])
		var dur := float(tempos[tempos.size() - 1] - tempos[0]) / 1000.0
		var por_s := float(trocas.size()) / maxf(dur, 0.1)
		if calmo:
			var pior_janela := 0
			for a in trocas.size():
				var q := 0
				for b in range(a, trocas.size()):
					if trocas[b] - trocas[a] < 1000:
						q += 1
				pior_janela = maxi(pior_janela, q)
			ok(pior_janela <= 2, "%s: a imagem troca no máximo 2 vezes em qualquer janela de 1 s (pior: %d)" % [rot, pior_janela])
			var pior := 0
			var pior_xy := Vector2i.ZERO
			for y in h:
				for x in w:
					var i := (y * w + x) * 4
					var tp: Array[int] = []
					for n in range(1, imgs.size()):
						var j := i
						if imgs[n][j] != imgs[n - 1][j] or imgs[n][j + 1] != imgs[n - 1][j + 1] or imgs[n][j + 2] != imgs[n - 1][j + 2]:
							tp.append(tempos[n])
					for a in tp.size():
						var q := 0
						for b in range(a, tp.size()):
							if tp[b] - tp[a] < 1000:
								q += 1
						if q > pior:
							pior = q
							pior_xy = Vector2i(x - MARGEM, y - MARGEM)
			ok(pior <= 2, "%s: nenhum pixel troca de cor mais que 2 vezes por segundo (pior: %d em %s)" % [rot, pior, pior_xy])
		else:
			ok(por_s >= 12.0, "%s: a chama é fluida, %.1f trocas de quadro por segundo (mínimo 12)" % [rot, por_s])
		var dbg := OS.get_environment("KIKIU_SALVAR_CHAMA")
		if dbg != "":
			var ult := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, imgs[imgs.size() - 1])
			ult.resize(w * 6, h * 6, Image.INTERPOLATE_NEAREST)
			ult.save_png(dbg.replace(".png", "_calmo.png" if calmo else "_livre.png"))
		sv.queue_free()
	Config.temporario(Piscadas.OPCAO, false)


## (d) No mundo: o elite queimando (nó, material próprio) e o lobo do lote. Ao redor da célula do elite, a mais de MARGEM_PX dela, não pode haver mais laranja de fogo
## que antes de queimar; dentro da célula do lobo e do elite muda a cor de pelo menos 30 pixels (o fogo).
func _parte_mundo_pixel() -> void:
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
	var canto: Vector2 = w.cam.retangulo().position
	var k: float = float(depois.get_width()) / 960.0
	var sp: Sprite2D = elite.sprite
	var cel_elite := Rect2((sp.global_position + sp.offset * sp.scale - canto) * k, sp.region_rect.size * sp.scale * k)
	var cel_lobo := Rect2(
		(Vector2(lobo.pr.x - float(lobo.fw) * 0.5 * lobo.v_sx, lobo.pr.y - float(lobo.fpe) * lobo.v_sy) - canto) * k,
		Vector2(float(lobo.fw) * lobo.v_sx, float(lobo.fh) * lobo.v_sy) * k
	)
	var margem := 3.0 * k  # a sobra (1 px) com folga para o arredondamento da conversão tela-mundo
	for par in [[cel_elite, "a elite"], [cel_lobo, "o lobo"]]:
		var cel: Rect2 = par[0]
		var dentro := _mudou(antes, depois, Rect2i(cel))
		var anel := Rect2i(cel.grow(margem + 10.0 * k))
		var fora_depois := _fogo(depois, anel) - _fogo(depois, Rect2i(cel.grow(margem)))
		var fora_antes := _fogo(antes, anel) - _fogo(antes, Rect2i(cel.grow(margem)))
		ok(dentro >= 30, "%s: o fogo aparece na célula (%d pixels mudaram de cor)" % [par[1], dentro])
		ok(fora_depois <= fora_antes + 2, "%s: nada de fogo num anel de 10 px fora da célula (%d com fogo, %d sem)" % [par[1], fora_depois, fora_antes])
	var dbg := OS.get_environment("KIKIU_SALVAR_CHAMA")
	if dbg != "":
		depois.save_png(dbg.replace(".png", "_mundo.png"))
	w.queue_free()
	await get_tree().process_frame


## Pixels de cor de fogo (laranja saturado) no retângulo.
func _fogo(img: Image, r: Rect2i) -> int:
	var n := 0
	var lim := Rect2i(Vector2i.ZERO, img.get_size()).intersection(r)
	for y in range(lim.position.y, lim.end.y):
		for x in range(lim.position.x, lim.end.x):
			var c := img.get_pixel(x, y)
			if c.r > 0.55 and c.g > 0.15 and c.g < 0.8 and c.b < 0.3 and c.r > c.g * 1.25:
				n += 1
	return n


## Quantos pixels do retângulo mudaram de cor de uma imagem para outra.
func _mudou(a: Image, b: Image, r: Rect2i) -> int:
	var n := 0
	var lim := Rect2i(Vector2i.ZERO, a.get_size()).intersection(r)
	for y in range(lim.position.y, lim.end.y):
		for x in range(lim.position.x, lim.end.x):
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				n += 1
	return n
