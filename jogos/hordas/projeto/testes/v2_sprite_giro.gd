extends "res://testes/isolamento_v2.gd"
# Teste automático de "armas e projéteis não giram em ângulo livre" (v2/sprite_giro.gd, v2/pixel_rot.gd, adagas.gd, armas.gd, armas_novas.gd, anim_golpes.gd):
#  - as 16 direções: de 0 a 359 graus a direção escolhida fica a no máximo 11,25 graus do pedido e o ângulo que vai para a transformação é SEMPRE
#    múltiplo de 90 graus (o resto da direção está na cópia pré-girada);
#  - as cópias pré-giradas (22,5, 45 e 67,5) só têm cor e alfa que a arte original já tinha (nada de filtro nem interpolação), guardam a massa da
#    figura, têm âncora inteira dentro do quadro e o normal map gira junto (vetor RG pelo mesmo ângulo, Z e alfa intactos);
#  - a arte dos golpes é preparada quando o golpe entra no jogo (definir_golpe), não no meio do voo;
#  - nenhum desenho dessas camadas gira por ângulo livre: o segundo argumento de cada draw_set_transform nos arquivos é 0, múltiplo de 90 ou uma
#    das 16 direções (varredura do texto dos arquivos, porque o Godot não deixa interceptar o desenho em --headless).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_sprite_giro.tscn  (imprime "v2_sprite_giro falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const PixelRot := preload("res://v2/pixel_rot.gd")
const SpriteGiro := preload("res://v2/sprite_giro.gd")
const AnimGolpes := preload("res://v2/anim_golpes.gd")
const Novas := preload("res://v2/armas_novas.gd")
const Herois := preload("res://v2/herois.gd")
const ARQUIVOS := ["res://v2/adagas.gd", "res://v2/armas.gd", "res://v2/armas_novas.gd", "res://v2/anim_golpes.gd", "res://v2/sprite_giro.gd"]
## O segundo argumento que um draw_set_transform dessas camadas pode ter.
const ANGULOS_OK := ["0.0", "float(d.y) * PixelRot.QUARTO", "PixelRot.quarto(float(it.r))", "ang"]

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Herois.forcado = "hazaki"
	_t_direcoes()
	_t_copias_dagas()
	_t_copias_normal()
	_t_sem_pixel_solto()
	_t_normal_vetor()
	_t_tamanhos_do_indice()
	_t_varredura_fontes()
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	_t_preparo_ao_entrar()
	Herois.forcado = ""
	print("v2_sprite_giro falhas=%d" % falhas)
	get_tree().quit()


func _t_direcoes() -> void:
	var pior := 0.0
	var vistas := {}
	for graus in 360:
		var rad := deg_to_rad(float(graus))
		var d := PixelRot.direcao16(rad)
		vistas[d] = true
		ok(d.x >= 0 and d.x <= 3 and d.y >= 0 and d.y <= 3, "direção fora de 0 a 3 em %d graus: %s" % [graus, d])
		var feito := PixelRot.angulo16(d)
		var erro := absf(wrapf(feito - rad, -PI, PI))
		pior = maxf(pior, erro)
		ok(PixelRot.e_quarto(float(d.y) * PixelRot.QUARTO), "a transformação não é múltiplo de 90 graus em %d graus" % graus)
	ok(rad_to_deg(pior) <= 11.25 + 0.001, "a direção escolhida passa de 11,25 graus do pedido (%.2f)" % rad_to_deg(pior))
	ok(vistas.size() == 16, "as 16 direções não aparecem todas (%d)" % vistas.size())
	ok(PixelRot.direcao16(-0.1) == Vector2i(0, 0), "ângulo pequeno negativo vira a direção 0")
	ok(PixelRot.direcao16(-PI / 2.0) == Vector2i(0, 3), "-90 graus = 3 quartos de volta")


## Cores e alfas que a imagem tem (empacotados) e quantos pixels têm alfa.
func _conjunto(img: Image) -> Dictionary:
	var c := {}
	var d := img.get_data().to_int32_array()
	for v in d:
		if (v >> 24) & 255 != 0:
			c[v] = true
	return c


func _opacos(img: Image) -> int:
	var n := 0
	var d := img.get_data().to_int32_array()
	for v in d:
		if (v >> 24) & 255 != 0:
			n += 1
	return n


func _rgba(t: Texture2D) -> Image:
	var im := t.get_image()
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	return im


func _t_copias_dagas() -> void:
	var f := AnimGolpes.de("adagas_voadoras").get("voo", {}) as Dictionary
	ok(not f.is_empty(), "a folha voo das adagas voadoras existe")
	if f.is_empty():
		return
	var q := Vector2i(f.quadro as Vector2)
	var anc := Vector2i(f.ancora as Vector2)
	var n := int(f.n)
	var fonte := _rgba(f.tex)
	var cores := _conjunto(fonte)
	for sub in range(1, 4):
		var v := SpriteGiro.variante(f.tex, q, anc, n, sub)
		var im := _rgba(v.tex)
		var qq := Vector2i(v.quadro as Vector2)
		var aa := v.ancora as Vector2
		ok(im.get_width() == qq.x * n and im.get_height() == qq.y, "sub %d: o quadro bate com a imagem (%s x%d, %s)" % [sub, qq, n, im.get_size()])
		ok(is_equal_approx(aa.x, floorf(aa.x)) and is_equal_approx(aa.y, floorf(aa.y)), "sub %d: a âncora é inteira (%s)" % [sub, aa])
		ok(aa.x >= 0.0 and aa.y >= 0.0 and aa.x <= float(qq.x) and aa.y <= float(qq.y), "sub %d: a âncora cai dentro do quadro" % sub)
		var novas := 0
		for c in _conjunto(im):
			if not cores.has(c):
				novas += 1
		ok(novas == 0, "sub %d: a cópia inventou %d cor(es)/alfa(s) que a folha não tem" % [sub, novas])
		var antes := _opacos(fonte)
		var depois := _opacos(im)
		ok(
			float(depois) >= 0.7 * float(antes) and float(depois) <= 1.3 * float(antes),
			"sub %d: a massa da figura se mantém (%d -> %d px)" % [sub, antes, depois]
		)
	ok(SpriteGiro.variante(f.tex, q, anc, n, 0).tex == f.tex, "sub 0 é a própria folha, sem cópia")


## O voto 2x2 do giro deixava pixel opaco sem nenhum vizinho; a arte original não tem. Nenhuma cópia pode ter.
func _t_sem_pixel_solto() -> void:
	var soltos := 0
	var folhas := 0
	for par in [
		["meteoro_flamejante", "queda"],
		["cometa_roxo", "queda"],
		["perigo_chuva", "queda"],
		["chuva_de_ferro", "queda"],
		["kunai_heroi", "voo"],
		["flecha_heroi", "voo"]
	]:
		var f := AnimGolpes.de(str(par[0])).get(str(par[1]), {}) as Dictionary
		if f.is_empty():
			continue
		folhas += 1
		for sub in range(1, 4):
			var v := SpriteGiro.variante(f.tex, Vector2i(f.quadro as Vector2), Vector2i(f.ancora as Vector2), int(f.n), sub)
			var im := _rgba(v.tex)
			var qw := int((v.quadro as Vector2).x)
			for y in im.get_height():
				for x in im.get_width():
					if im.get_pixel(x, y).a < 0.5:
						continue
					var viz := false
					var x0 := (x / qw) * qw
					for dy in range(maxi(y - 1, 0), mini(y + 2, im.get_height())):
						for dx in range(maxi(x - 1, x0), mini(x + 2, x0 + qw)):
							if (dx != x or dy != y) and im.get_pixel(dx, dy).a >= 0.5:
								viz = true
					if not viz:
						soltos += 1
	ok(folhas >= 4, "a checagem de pixel solto viu as folhas (%d)" % folhas)
	ok(soltos == 0, "as cópias pré-giradas têm %d pixel(s) opaco(s) sem vizinho" % soltos)


func _t_copias_normal() -> void:
	Novas.carregar_sprites()
	var sp := Novas.sprite_de("adagas_voadoras")
	ok(not sp.is_empty() and sp.tex is CanvasTexture, "o sprite da adaga é um CanvasTexture com normal map")
	if sp.is_empty():
		return
	var ct: CanvasTexture = sp.tex
	var tam := Vector2i(sp.tam as Vector2)
	var dif := _rgba(ct.diffuse_texture)
	var cores := _conjunto(dif)
	for sub in range(1, 4):
		var v := SpriteGiro.variante(sp.tex, tam, tam / 2, 1, sub)
		ok(v.tex is CanvasTexture, "sub %d: a cópia mantém o normal map" % sub)
		var cd := _rgba((v.tex as CanvasTexture).diffuse_texture)
		var cn := _rgba((v.tex as CanvasTexture).normal_texture)
		ok(cd.get_size() == cn.get_size(), "sub %d: difusa e normal têm o mesmo tamanho" % sub)
		for c in _conjunto(cd):
			if not cores.has(c):
				ok(false, "sub %d: cor nova na cópia do sprite" % sub)
				break
		# onde a difusa é opaca o normal também é, e o Z do normal não muda
		var dd := cd.get_data().to_int32_array()
		var dn := cn.get_data().to_int32_array()
		var estranho := 0
		for i in dd.size():
			var ad := (dd[i] >> 24) & 255
			var an := (dn[i] >> 24) & 255
			if (ad == 0) != (an == 0):
				estranho += 1
		ok(estranho == 0, "sub %d: %d pixel(s) onde a difusa e o normal discordam no alfa" % [sub, estranho])


## O sprite que o golpe gira vem do `tamanho` do índice: o PNG tem de ter exatamente esse tamanho (a cópia pré-girada recorta por ele; o código antigo
## esticava a textura até `tamanho`, e uma divergência cortaria o projétil). Vale para todo projétil e para as duas entradas `ventania`.
func _t_tamanhos_do_indice() -> void:
	var visto := 0
	for pasta in ["res://assets/v2/armas/", "res://assets/v2/fusoes/"]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pasta + "indice.json"))
		for nome in d.sprites:
			var e: Dictionary = d.sprites[nome]
			if str(e.tipo) != "projetil" and nome != "ventania":
				continue
			var tam := Vector2i(int(e.tamanho[0]), int(e.tamanho[1]))
			var dif := load(pasta + str(e.arquivo)) as Texture2D
			ok(
				dif != null and Vector2i(dif.get_size()) == tam,
				"%s%s: o PNG (%s) não tem o tamanho do índice (%s)" % [pasta, nome, dif.get_size() if dif != null else "?", tam]
			)
			if e.get("normal") != null:
				var nor := load(pasta + str(e.normal)) as Texture2D
				ok(nor != null and Vector2i(nor.get_size()) == tam, "%s%s: o normal não tem o tamanho do índice" % [pasta, nome])
			visto += 1
	ok(visto >= 28, "o laço viu os projéteis e a ventania (%d)" % visto)
	# a `ventania` que o jogo usa (a das fusões, lida por último) é a que `preparar_giros` prepara
	Novas.carregar_sprites()
	var sp := Novas.sprite_de("ventania")
	ok(not sp.is_empty() and Vector2i(sp.tam as Vector2) == Vector2i(64, 32), "a ventania do jogo é a das fusões (64x32)")


## Um normal uniforme (1, 0) girado em 45 graus vira (cos, -sen) = (0,707, -0,707) no que está gravado (verde para cima, tela para baixo),
## que é o que o motor faz ao girar o desenho (medido numa janela real: ver NORMAL_SINAL em sprite_giro.gd).
func _t_normal_vetor() -> void:
	var d := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	d.fill(Color.WHITE)
	var n := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	n.fill(Color(1.0, 0.5, 0.5, 1.0))
	var ct := CanvasTexture.new()
	ct.diffuse_texture = ImageTexture.create_from_image(d)
	ct.normal_texture = ImageTexture.create_from_image(n)
	var v := SpriteGiro.variante(ct, Vector2i(16, 16), Vector2i(8, 8), 1, 2)
	var cn := _rgba((v.tex as CanvasTexture).normal_texture)
	var meio := cn.get_pixel(int(v.quadro.x) / 2, int(v.quadro.y) / 2)
	var nx := meio.r * 2.0 - 1.0
	var ny := meio.g * 2.0 - 1.0
	ok(absf(nx - 0.7071) < 0.02 and absf(ny + 0.7071) < 0.02, "normal (1,0) girado 45 graus vira (0,707, -0,707): deu (%.3f, %.3f)" % [nx, ny])
	ok(absf(meio.b - 0.5) < 0.01, "o Z do normal não muda")


## Todo draw_set_transform das camadas de arma e projétil tem como ângulo 0, um múltiplo de 90 graus ou uma das 16 direções.
func _t_varredura_fontes() -> void:
	var total := 0
	for caminho in ARQUIVOS:
		var texto := FileAccess.get_file_as_string(caminho)
		ok(not texto.is_empty(), "leu %s" % caminho)
		var de := 0
		while true:
			var i := texto.find("draw_set_transform(", de)
			if i < 0:
				break
			de = i + 1
			var args := _argumentos(texto, i + "draw_set_transform(".length())
			total += 1
			if args.size() < 3 or not ANGULOS_OK.has(args[1]):
				ok(false, "%s: draw_set_transform com ângulo livre (%s)" % [caminho, args])
		if texto.contains("draw_set_transform_matrix("):  # a runa de reserva (armas.gd) gira a matriz: o ângulo dela passa por PixelRot.quarto
			ok(texto.contains("var rot := PixelRot.quarto("), "%s: draw_set_transform_matrix com giro livre" % caminho)
	ok(total >= 5, "a varredura achou os draw_set_transform dos arquivos (%d)" % total)
	# o único `ang` liberado é o da balestra da torre, que aponta em 16 direções
	var novas := FileAccess.get_file_as_string("res://v2/armas_novas.gd")
	ok(novas.contains("var ang := PixelRot.angulo16(PixelRot.direcao16(float(it.r)))"), "a balestra da torre aponta em 16 direções")


## Os argumentos (cortados nas vírgulas fora de parênteses) da chamada que começa em `ini` (logo depois do "(").
func _argumentos(texto: String, ini: int) -> Array:
	var res := []
	var prof := 0
	var atual := ""
	for k in range(ini, texto.length()):
		var ch := texto[k]
		if ch == "(":
			prof += 1
		elif ch == ")":
			if prof == 0:
				res.append(atual.strip_edges())
				return res
			prof -= 1
		if ch == "," and prof == 0:
			res.append(atual.strip_edges())
			atual = ""
		else:
			atual += ch
	return res


func _t_preparo_ao_entrar() -> void:
	# o que gira nos ataques inimigos e nos projéteis do Luke é preparado ao montar o mundo (adagas.gd e afins); a pedra da chuva e a revoada giram só em passos de 90 graus (PixelRot.quarto) e não precisam de cópia
	for par in [["onda", "voo"], ["fura", "voo"], ["shuriken_heroi", "voo"], ["kunai_heroi", "voo"], ["flecha_heroi", "voo"]]:
		var fo := AnimGolpes.de(str(par[0])).get(str(par[1]), {}) as Dictionary
		ok(not fo.is_empty() and SpriteGiro.preparada(fo.tex), "%s/%s foi preparada ao montar o mundo" % [par[0], par[1]])
	var antes := SpriteGiro.geradas
	w.combate.armas.definir_golpe("meteoro_flamejante", 1, 0.0)
	var f := AnimGolpes.de("meteoro_flamejante").get("queda", {}) as Dictionary
	ok(not f.is_empty() and SpriteGiro.preparada(f.tex), "a folha de queda do meteoro foi preparada ao entrar o golpe")
	ok(SpriteGiro.geradas > antes, "entrar o golpe gerou as cópias (%d -> %d)" % [antes, SpriteGiro.geradas])
	var depois := SpriteGiro.geradas
	w.combate.armas.definir_golpe("meteoro_flamejante", 2, 0.0)
	ok(SpriteGiro.geradas == depois, "subir o nível não gera de novo")
	w.combate.armas.definir_golpe("adagas_voadoras", 1, 0.0)
	var sp := Novas.sprite_de("adagas_voadoras")
	ok(not sp.is_empty() and SpriteGiro.preparada(sp.tex), "o sprite de projétil foi preparado ao entrar o golpe")
	# a queda do meteoro tem direção fixa (esquerda ou direita): a cópia certa existe e o ângulo da transformação é de 90 graus
	var d := PixelRot.direcao16((-Vector2(-1.0, 1.0)).angle())
	ok(PixelRot.e_quarto(float(d.y) * PixelRot.QUARTO), "a queda do meteoro vira quartos de volta exatos")
