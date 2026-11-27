extends Node
## Um tamanho de pixel só: sem filtro linear no mundo e na interface da v2 (a única exceção é o sharp bilinear da tela, em apresentacao.gd), sombra em
## degraus de 1 px (mancha dos pés e silhueta) e HUD sem escala fracionária (faixa de golpes em pixel nativo, coração do curandeiro em 1:1,
## pops do combo, do selo, do anel, da fusão e dos anúncios sem `scale`), o Q e o E/secundário do HUD e o logo do menu em pixel nativo (sem `scale`,
## ícones em 1:1, fontes na grade). A prova varre o fonte e monta os nós de verdade.

const Sombras := preload("res://v2/sombras.gd")
const Horda := preload("res://v2/horda.gd")
const HudGolpes := preload("res://v2/hud_golpes.gd")
const HudUltimate := preload("res://v2/hud_ultimate.gd")
const HudHabilidades := preload("res://v2/hud_habilidades.gd")
const Glifos := preload("res://v2/glifos.gd")
const Paleta := preload("res://v2/paleta.gd")
const PASTA := "res://v2/"
const SEM_ESCALA := ["hud.gd", "hud_anuncios.gd", "hud_golpes.gd", "ritmo.gd", "hud_ultimate.gd", "hud_habilidades.gd", "menu_principal.gd"]
const GRADE_PRESS_START := [8, 16]  # a grade da Press Start 2P (nativa 8, dobro 16)
const GRADE_JERSEY := [19, 37, 56, 75, 93, 112, 131, 149, 168]  # a grade da Jersey 10 (v2/LEIA-ME.md: 19, 37 e 56 e os múltiplos)
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
	_hud_em_pixel_nativo()
	_fontes_na_grade()
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


## Os slots de habilidades usam tamanho final, filtro nearest, ícones de 32 px e filete de 1 px.
func _hud_em_pixel_nativo() -> void:
	var raiz := Control.new()
	add_child(raiz)
	var hud := Control.new()
	hud.name = "Raiz"
	raiz.add_child(hud)
	var habilidades: Control = HudHabilidades.new()
	habilidades.name = "Habilidades"
	hud.add_child(habilidades)
	var ultimate: Control = HudUltimate.new()
	ultimate.name = "Ultimate"
	hud.add_child(ultimate)
	for no in [habilidades, ultimate]:
		ok(no.scale == Vector2.ONE, "%s não é escalado (%s): desenha em pixel nativo" % [no.name, no.scale])
		ok(no.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s desenha em nearest" % no.name)
	ok(ultimate.size == Vector2(90, 78), "o slot de Q mede 90x78 px no próprio nó (%s)" % ultimate.size)
	ok(habilidades.size == Vector2(274, 78), "impulso, E e secundário medem 274x78 no próprio nó (%s)" % habilidades.size)
	var ic_q: Variant = (HudUltimate as GDScript).get_script_constant_map().get("ESCALA_ICONE", 0)  # pelo mapa: no código antigo falha o teste, não o parse
	var ic_e: Variant = (HudHabilidades as GDScript).get_script_constant_map().get("ESCALA_ICONE", 0)
	ok(ic_q is int and ic_q == 1, "o ícone do Q usa escala nativa (%s)" % ic_q)
	ok(ic_e is int and ic_e == 1, "os ícones de habilidade usam escala nativa (%s)" % ic_e)
	var tam_q: Variant = Dados.icone_carta("ultimate_q")
	ok(tam_q != null and tam_q.get_size() * float(ic_q) == Vector2(32, 32), "o ícone do Q ocupa 32x32 px")
	var ch: Dictionary = (HudHabilidades as GDScript).get_script_constant_map()
	var quadro: Vector2 = ch.get("TAM_ICON", Vector2.ZERO)
	var topo: float = ch.get("TOPO_ICONE", 999.0)
	var base: float = ch.get("BASE_ROTULO", 999.0)
	var card: Vector2 = ch.get("TAM_CARD", Vector2.ZERO)
	ok(quadro.x >= 32.0 * float(ic_e) and quadro.y >= 32.0 * float(ic_e), "o quadro comporta o ícone de 32 px (%s)" % quadro)
	ok(
		topo + quadro.y + 8.0 <= base + 1.0 and base <= card.y - Glifos.ALTURA_SELO + 1.0,
		"quadro do ícone, rótulo de 8 px e selo da tecla cabem um sob o outro no card (%s, %s, %s)" % [topo, base, card]
	)
	var moldura_hab := _fonte("hud_habilidades.gd")
	var moldura_q := _fonte("hud_ultimate.gd")
	ok(moldura_hab.contains(", FILETE, false, 1.0)"), "os slots E, secundário e impulso desenham filete de 1 px")
	ok(moldura_q.contains(", Slots.FILETE, false, 1.0)"), "o slot de Q desenha filete de 1 px")
	ok(not moldura_hab.contains("draw_texture_rect_region(") and not moldura_q.contains("draw_texture_rect_region("), "os slots dispensam moldura de textura")
	raiz.queue_free()


## Fonte só na grade: a Press Start 2P em 8 ou 16 (nunca 12, 14 ou 10) e a Jersey 10 em 19, 37, 56 e múltiplos (nunca 20); o logo do menu em
## múltiplo da grade e sem `scale`.
func _fontes_na_grade() -> void:
	ok(Glifos.TAM_SELO in GRADE_PRESS_START, "a letra do selo do HUD (%s) está na grade da Press Start 2P" % Glifos.TAM_SELO)
	ok(
		Paleta.NUMERO_PEQUENO in GRADE_PRESS_START and _fonte("hud_ultimate.gd").contains("TAM.x, Paleta.NUMERO_PEQUENO, cor)"),
		"o texto do Q usa o tamanho de número na grade da Press Start 2P"
	)
	var hud := _fonte("hud.gd")
	var ini := hud.find("func _criar_selo_pesadelo")
	var fim := hud.find("\nfunc ", ini + 10)
	var corpo := hud.substr(ini, fim - ini)
	var m := RegEx.create_from_string(r'add_theme_font_size_override\("font_size",\s*(\d+)').search(corpo)
	ok(
		ini >= 0 and m != null and int(m.get_string(1)) in GRADE_JERSEY,
		"o selo PESADELO (Jersey 10) usa um tamanho da grade: %s" % (m.get_string(1) if m else "?")
	)
	var menu: Variant = load("res://v2/menu_principal.gd")
	var tam_logo: Variant = (menu as GDScript).get_script_constant_map().get("TAM_LOGO", 0)
	ok(tam_logo is int and tam_logo in GRADE_JERSEY, "o logo do menu (%s) está na grade da Jersey 10" % tam_logo)
	ok(not (menu as GDScript).get_script_constant_map().has("LOGO_ESCALA"), "o logo do menu não é mais ampliado por fator (LOGO_ESCALA)")
