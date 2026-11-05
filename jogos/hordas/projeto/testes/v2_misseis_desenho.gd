extends "res://testes/isolamento_v2.gd"
# Teste automático do DESENHO dos projéteis com imagem (v2/adagas.gd, v2/sprite_giro.gd, v2/pixel_rot.gd), achado no vídeo da rodada 4 do LightWolf:
#  - sem giro livre: nenhum draw_set_transform de adagas.gd gira por ângulo contínuo e nenhum desenho passa por AnimGolpes.desenhar (que gira livre);
#    a imagem sai de SpriteGiro.desenhar (16 direções, transformação só em quartos de volta). Varredura do texto, porque o Godot não deixa interceptar
#    o desenho em --headless (a mesma técnica de v2_pixel_efeitos);
#  - as cópias pré-giradas do míssil, da adaga e do plasma ficam prontas ao montar (nada gerado no meio da partida), com âncora inteira e o alfa
#    que a arte já tinha (o míssil é 0/1 em todas);
#  - o nariz do míssil segue o movimento DESENHADO: na descida da boca do pod até a trajetória do chão, a direção do desenho (`_ang_visual`) bate com
#    o deslocamento medido de `_pos_visual` quadro a quadro, e não com `a_dir` (a do chão), nas 8 miras;
#  - o míssil some sem alfa parcial: `_fade` fica em 1 até o fim do alcance (a adaga segue esmaecendo, como antes).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_misseis_desenho.tscn  (imprime "v2_misseis_desenho falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const PASSO := 1.0 / 60.0
const ARQ := "res://v2/adagas.gd"
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	_varredura()
	_copias()
	_nariz()
	_some_sem_alfa()
	Herois.forcado = ""
	print("v2_misseis_desenho falhas=%d" % falhas)
	get_tree().quit()


## O corpo de uma função do texto `src` (da linha `func nome(` até a próxima `func`).
func _corpo(src: String, nome: String) -> String:
	var a := src.find("\nfunc %s(" % nome)
	if a < 0:
		return ""
	var b := src.find("\nfunc ", a + 1)
	return src.substr(a, (b if b > 0 else src.length()) - a)


func _varredura() -> void:
	var src := FileAccess.get_file_as_string(ARQ)
	ok(src.length() > 1000, "leu %s" % ARQ)
	var giros := 0
	var pos := src.find("draw_set_transform(")
	while pos >= 0:
		var fim := src.find("\n", pos)
		var linha := src.substr(pos, fim - pos)
		var args := linha.substr(len("draw_set_transform("))
		var partes := args.split(",")
		var ang := partes[1].strip_edges() if partes.size() > 1 else ""
		if ang != "0.0":
			giros += 1
			print("  giro em adagas.gd: ", linha.strip_edges())
		pos = src.find("draw_set_transform(", fim)
	ok(giros == 0, "nenhum draw_set_transform de adagas.gd gira por ângulo (achei %d)" % giros)
	ok(src.find("AnimGolpes.desenhar(") < 0, "a folha animada não passa por AnimGolpes.desenhar (que gira por ângulo livre)")
	var corpo := _corpo(src, "_desenhar_corpo")
	ok(corpo.find("SpriteGiro.desenhar(") >= 0, "o corpo desenha a imagem por SpriteGiro.desenhar (16 direções)")
	ok(corpo.find("_ang_visual(") >= 0 and corpo.find("a_dir[i] as Vector2).angle()") < 0, "o corpo aponta a imagem pela direção do desenho, não pela do chão")
	var brilho := _corpo(src, "_desenhar_brilho")
	ok(brilho.find("direcao16(") >= 0, "o fogo do motor (brilho) usa a mesma direção quantizada")


func _rgba(t: Texture2D) -> Image:
	var im := t.get_image()
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	return im


func _copias() -> void:
	var sg = load("res://v2/sprite_giro.gd")
	ok(sg != null, "v2/sprite_giro.gd existe")
	if sg == null:
		return
	var ad = w.combate.adagas
	for nome in ["adaga", "plasma", "missil"]:
		var e: Dictionary = ad._proj_lista[int(ad._proj_nomes[nome])]
		var tex: Texture2D = e.tex
		ok(sg.preparada(tex), "%s: as cópias pré-giradas já existem ao montar" % nome)
		var tam := Vector2i(tex.get_size())
		for sub in 4:
			var v: Dictionary = sg.variante(tex, tam, tam / 2, 1, sub)
			var anc: Vector2 = v.ancora
			ok(anc == anc.floor(), "%s sub %d: âncora inteira (%s)" % [nome, sub, anc])
			if nome != "missil":
				continue
			var im := _rgba(v.tex)
			var parcial := 0
			for y in im.get_height():
				for x in im.get_width():
					var a := im.get_pixel(x, y).a8
					if a != 0 and a != 255:
						parcial += 1
			ok(parcial == 0, "míssil sub %d: alfa só 0 ou 255 (%d px parciais)" % [sub, parcial])


func _zerar(mira: Vector2) -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.centro() + mira * 120.0
	passos(3)
	h.hab_recarga = 0.0
	h.hab_nega_t = 0.0


## O nariz: em cada uma das 8 miras, a E solta mísseis que descem do pod; quadro a quadro, a direção do desenho tem de bater com o caminho
## que a imagem fez (`_pos_visual` de um quadro para o outro). Na descida esse caminho se afasta da direção do chão (é o defeito do vídeo).
func _nariz() -> void:
	var ad = w.combate.adagas
	if not ad.has_method("_ang_visual"):
		ok(false, "adagas.gd não tem a direção do desenho (_ang_visual): o míssil aponta para a direção do chão")
		return
	var idx := int(ad._proj_nomes["missil"])
	var medidos := 0
	var errados := 0
	var pior := 0.0
	var descida := 0
	var descida_quant := 0
	for k in 8:
		var mira := Vector2.from_angle(float(k) * TAU / 8.0)
		_zerar(mira)
		ok(w.heroi.habilidade(), "mira %d: a E dispara" % k)
		var antes := {}  # slot -> [pos desenhada, ângulo do desenho, distância voada]
		for _q in 90:
			passos(1)
			for i in ad.MAX:
				if ad.a_rest[i] <= 0.0 or ad.a_proj[i] != idx or ad.a_visual_oculto[i] != 0:
					antes.erase(i)
					continue
				var pv: Vector2 = ad._pos_visual(i)
				var ang: float = ad._ang_visual(i)
				var dist: float = ad.a_visual_dist[i]
				if antes.has(i) and dist > float(antes[i][2]):
					var mov: Vector2 = pv - (antes[i][0] as Vector2)
					if mov.length() >= 2.0:
						medidos += 1
						var erro := minf(absf(angle_difference(ang, mov.angle())), absf(angle_difference(float(antes[i][1]), mov.angle())))
						pior = maxf(pior, erro)
						if erro > deg_to_rad(15.0):
							errados += 1
						var chao := (ad.a_dir[i] as Vector2).angle()
						if absf(angle_difference(mov.angle(), chao)) > deg_to_rad(20.0):
							descida += 1
							if ad.PixelRot.direcao16(ang) != ad.PixelRot.direcao16(chao):
								descida_quant += 1
				antes[i] = [pv, ang, dist]
	ok(medidos > 200, "mediu o caminho desenhado de muitos mísseis (%d quadros)" % medidos)
	ok(errados == 0, "a direção do desenho segue o caminho da imagem (%d quadros fora de 15 graus; pior %.1f)" % [errados, rad_to_deg(pior)])
	ok(descida > 20, "houve descida do pod em que o caminho desenhado se afasta mais de 20 graus do chão (%d quadros)" % descida)
	ok(descida_quant >= descida / 2, "na descida a direção quantizada do desenho não é a do chão (%d de %d)" % [descida_quant, descida])


## O fim do alcance: o míssil fica com alfa 1 até o último quadro; a adaga ainda esmaece (comportamento antigo dela).
func _some_sem_alfa() -> void:
	var ad = w.combate.adagas
	if not ad.has_method("_fade"):
		ok(false, "adagas.gd não tem `_fade`: o míssil esmaece com alfa parcial (clampf(a_rest / 24))")
		return
	_zerar(Vector2.RIGHT)
	ok(w.heroi.habilidade(), "a E dispara")
	passos(2)
	var i := -1
	for j in ad.MAX:
		if ad.a_rest[j] > 0.0 and ad.a_proj[j] == int(ad._proj_nomes["missil"]):
			i = j
	ok(i >= 0, "achou um míssil em voo")
	if i < 0:
		return
	for resto in [200.0, 24.0, 12.0, 3.0, 0.5]:
		ad.a_rest[i] = resto
		ok(ad._fade(i) == 1.0, "míssil com %s px de alcance: alfa 1 (deu %s)" % [resto, ad._fade(i)])
	ad.a_proj[i] = 0  # a adaga
	ad.a_rest[i] = 12.0
	ok(absf(ad._fade(i) - 0.5) < 0.001, "a adaga segue esmaecendo nos últimos 24 px (%s)" % ad._fade(i))
	ad.a_rest[i] = 0.0
