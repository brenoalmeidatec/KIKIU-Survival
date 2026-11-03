extends Node
## Um tamanho de pixel só: sem filtro linear no mundo e na interface da v2 (a única exceção é o sharp bilinear da tela, em apresentacao.gd), sombra em
## degraus de 1 px (mancha dos pés e silhueta) e HUD sem escala fracionária (faixa de golpes em pixel nativo, coração do curandeiro em 1:1,
## pops do combo, do selo, do anel, da fusão e dos anúncios sem `scale`). A prova é a mesma do código: varre o fonte e monta os nós de verdade.

const Sombras := preload("res://v2/sombras.gd")
const Horda := preload("res://v2/horda.gd")
const HudGolpes := preload("res://v2/hud_golpes.gd")
const PASTA := "res://v2/"
const SEM_ESCALA := ["hud.gd", "hud_anuncios.gd", "hud_golpes.gd", "ritmo.gd"]
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _fonte(arq: String) -> String:
	return FileAccess.get_file_as_string(PASTA + arq)


func _ready() -> void:
	_filtros()
	_sombras()
	_faixa_de_golpes()
	_sem_escala_fracionaria()
	print("v2_pixel_filtros falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


## Nenhum arquivo da v2 liga o filtro linear, a não ser o sharp bilinear da tela (apresentacao.gd).
func _filtros() -> void:
	var n := 0
	for arq in DirAccess.get_files_at(PASTA):
		if not arq.ends_with(".gd") or arq == "apresentacao.gd":
			continue
		n += 1
		ok(not _fonte(arq).contains("TEXTURE_FILTER_LINEAR"), "%s não pode usar TEXTURE_FILTER_LINEAR" % arq)
	ok(n > 50, "a varredura leu os arquivos da v2 (%d)" % n)


func _sombras() -> void:
	# a mancha dos pés: poucos degraus de alfa (o gradiente antigo passava de 30 níveis)
	var raiz := Node2D.new()
	add_child(raiz)
	var s := Sombras.new()
	s.montar(raiz)
	var im := s.textura_blob().get_image()
	ok(im.get_size() == Vector2i(64, 32), "a mancha tem 64x32 (%s)" % im.get_size())
	var graus: Array = (s.get_script() as GDScript).get_script_constant_map().get("BLOB_DEGRAUS", [])  # pelo mapa de constantes: no código antigo falha o teste, não o parse
	var niveis := {}
	for y in im.get_height():
		for x in im.get_width():
			niveis[roundi(im.get_pixel(x, y).a * 255.0)] = true
	ok(graus.size() > 0 and niveis.size() == graus.size() + 1, "a mancha tem só os degraus + transparente (%d níveis: %s)" % [niveis.size(), niveis.keys()])
	ok(im.get_pixel(32, 16).a > im.get_pixel(32, 2).a and im.get_pixel(32, 2).a > 0.0, "a mancha é mais forte no miolo que na borda")
	ok(im.get_pixel(0, 0).a == 0.0, "o canto da mancha é transparente")
	# a silhueta: os dois shaders (sprite e lote da horda) quantizam o alfa por fragmento
	var mat := s._material_sombra()
	ok(mat.shader.code.contains("cobertura(") and mat.shader.code.contains("banda("), "o shader da sombra de sprite usa os degraus")
	ok(Horda.SHADER_SOMBRA.contains("cobertura(") and Horda.SHADER_SOMBRA.contains("banda("), "o shader da sombra do lote usa os degraus")
	ok(not mat.shader.code.contains("clamp(1.0 - up"), "sem o esmaecimento contínuo antigo (sprite)")
	ok(
		not mat.shader.code.contains("cobertura(COLOR"),
		"a silhueta não quantiza o COLOR (que já leva a luz do modulate): senão a sombra some e pisca com a luz"
	)
	ok(
		mat.shader.code.contains("cobertura(texture(TEXTURE") and mat.shader.code.contains("luz = COLOR.a"),
		"a silhueta vem da textura e a luz (modulate) multiplica contínua"
	)
	ok(not Horda.SHADER_SOMBRA.contains("clamp(1.0 - up"), "sem o esmaecimento contínuo antigo (lote)")
	# o sprite de sombra e o lote da horda desenham em nearest
	var ator := preload("res://v2/ator.gd").new()
	var sp := s._sprite_sombra(ator)
	ok(sp.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "o sprite da sombra é nearest")
	raiz.queue_free()


func _faixa_de_golpes() -> void:
	var pai := Control.new()
	add_child(pai)
	var g := HudGolpes.new()
	pai.add_child(g)
	ok(g.scale == Vector2.ONE, "a faixa de golpes não é escalada (%s): desenha em pixel nativo" % g.scale)
	ok(g.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "a faixa de golpes é nearest")
	var tex: Texture2D = Dados.icone_carta("bola_fogo")
	ok(
		tex != null and tex.get_size() == Vector2(HudGolpes.ICONE, HudGolpes.ICONE),
		"o ícone da carta é desenhado em 1:1 (%s x %d)" % [tex.get_size() if tex else null, HudGolpes.ICONE]
	)
	ok(HudGolpes.CAIXA == HudGolpes.ICONE + 6 and HudGolpes.ALTURA >= HudGolpes.CAIXA + 3 + HudGolpes.PIP_A, "a caixa e a altura comportam o ícone e os pips")
	pai.queue_free()


func _sem_escala_fracionaria() -> void:
	var re := RegEx.create_from_string("\\bscale\\s*=\\s*(.*)")
	for arq in SEM_ESCALA:
		var linhas := _fonte(arq).split("\n")
		for i in linhas.size():
			var l: String = linhas[i].strip_edges()
			if l.begins_with("#") or l.begins_with("##"):
				continue
			var m := re.search(l)
			if m != null and m.get_string(1).split("#")[0].strip_edges() != "Vector2.ONE":
				ok(false, "%s:%d escala o desenho: %s" % [arq, i + 1, l])
			if l.contains('"scale"') and l.contains("tween_property"):
				ok(false, "%s:%d anima `scale`: %s" % [arq, i + 1, l])
