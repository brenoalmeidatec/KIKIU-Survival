extends "res://testes/isolamento_v2.gd"
## Folha de comparação de fontes da v2 (ferramenta de olhar, não é teste automático).
## Lê uma especificação JSON e desenha cada fonte candidata exatamente como o jogo desenha texto: dentro de um SubViewport com filtro
## nearest, sem anti-aliasing, sem hinting e sem posição de subpixel (as mesmas opções dos .import das fontes da v2), em tamanhos
## múltiplos da grade da fonte. Cada bloco mostra os dígitos, os números que confundiam (500 200 1000 3500), os pares que se confundem
## (0 O, 1 l I, 5 S, 2 Z), a frase do menu de gráficos em 3 tamanhos, as palavras com acento e os símbolos.
## Uso (precisa de janela): godot --path jogos/hordas/projeto res://testes/v2_fontes_folha.tscn -- --spec=ARQ.json
## A especificação: {"saida": "x.png", "largura": 1920, "colunas": 2, "candidatas": [{"nome": "...", "arq": "caminho absoluto ou res://",
## "tamanhos": [8, 10, 12], "nota": "SIL OFL"}], "frase": "...", "palavras": "...", "numeros": "..."}.
## Saem só imagens do viewport (nunca da área de trabalho).

const FUNDO := Color(0.027, 0.04, 0.09)
const TEXTO := Color(0.92, 0.9, 0.96)
const OURO := Color(1.0, 0.86, 0.42)
const FRASE := "Quantos monstros podem estar vivos ao mesmo tempo (vale o menor). * ainda sem efeito"
const NUMEROS := "0123456789   500 200 1000 3500   0O 1lI 5S 2Z 6G 8B"
const PALAVRAS := "Ação, coração, é, ê, õ, ü: Máximo, Gráficos, Música, Efeitos, Santuário, Épico, Nível, Próximo, Evolução, Lendário"
const SIMBOLOS := "* ( ) % + - / : . , ' \" x  (*) [*] † ‡ ✱ ★ »"

var _rot: Font


func _ready() -> void:
	var spec_arq := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--spec="):
			spec_arq = a.trim_prefix("--spec=")
	if spec_arq == "":  # sem --spec não há o que desenhar: o CI roda toda cena de testes/ e pede "falhas=0"
		print("v2_fontes_folha: ferramenta de olhar, use --spec=ARQ.json (com janela). falhas=0")
		get_tree().quit()
		return
	var spec = JSON.parse_string(FileAccess.get_file_as_string(spec_arq))
	if spec == null:
		print("v2_fontes_folha: spec inválida ", spec_arq, " falhas=1")
		get_tree().quit(1)
		return
	await _montar_e_salvar(spec)
	get_tree().quit()


func _carregar(arq: String) -> Font:
	var f := FontFile.new()
	if arq.begins_with("res://"):
		f = load(arq)
		f = f.duplicate()
	else:
		f.load_dynamic_font(arq)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.oversampling = 0.0
	var ts := TextServerManager.get_primary_interface()
	f.opentype_feature_overrides = {ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0}
	return f


func _label(texto: String, fonte: Font, tam: int, cor: Color, largura: float) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if largura > 0.0 else TextServer.AUTOWRAP_OFF
	if largura > 0.0:
		l.custom_minimum_size.x = largura
	return l


func _montar_e_salvar(spec: Dictionary) -> void:
	_rot = _carregar("res://assets/fonte/PressStart2P.ttf")
	var larg := int(spec.get("largura", 1920))
	var cols := int(spec.get("colunas", 2))
	var sv := SubViewport.new()
	sv.size = Vector2i(larg, 6000)
	sv.disable_3d = true
	sv.transparent_bg = false
	sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var fundo := ColorRect.new()
	fundo.color = FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	sv.add_child(fundo)
	var grade := GridContainer.new()
	grade.columns = cols
	grade.add_theme_constant_override("h_separation", 20)
	grade.add_theme_constant_override("v_separation", 14)
	sv.add_child(grade)
	var col_larg := float(larg - 20 * (cols + 1)) / float(cols)
	var frase := str(spec.get("frase", FRASE))
	var numeros := str(spec.get("numeros", NUMEROS))
	var palavras := str(spec.get("palavras", PALAVRAS))
	var simbolos := str(spec.get("simbolos", SIMBOLOS))
	for c in spec.candidatas:
		var f := _carregar(str(c.arq))
		var bloco := VBoxContainer.new()
		bloco.add_theme_constant_override("separation", 2)
		bloco.custom_minimum_size.x = col_larg
		var tams: Array = c.tamanhos
		bloco.add_child(_label("%s   [%s]   tamanhos %s" % [c.nome, str(c.get("nota", "")), str(tams)], _rot, 8, OURO, col_larg))
		for t in tams:
			var s := int(t)
			var larg_frase := int(f.get_string_size(frase, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x)
			var larg_dig := int(f.get_string_size("500", HORIZONTAL_ALIGNMENT_LEFT, -1, s).x)
			bloco.add_child(
				_label('%dpx  linha %d  frase %d px  "500" %d px' % [s, int(f.get_height(s)), larg_frase, larg_dig], _rot, 8, Color(0.5, 0.55, 0.7), 0.0)
			)
			bloco.add_child(_label(numeros, f, s, TEXTO, col_larg))
			bloco.add_child(_label(frase, f, s, TEXTO, col_larg))
		var mid := int(tams[tams.size() / 2])
		bloco.add_child(_label(palavras, f, mid, TEXTO, col_larg))
		bloco.add_child(_label(simbolos, f, mid, TEXTO, col_larg))
		var sep := ColorRect.new()
		sep.color = Color(0.2, 0.22, 0.34)
		sep.custom_minimum_size = Vector2(col_larg, 2)
		bloco.add_child(sep)
		grade.add_child(bloco)
	for i in 3:
		await get_tree().process_frame
	var tam: Vector2 = grade.get_combined_minimum_size()
	sv.size = Vector2i(larg, int(tam.y) + 8)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(str(spec.saida).get_base_dir())
	img.save_png(str(spec.saida))
	print("v2_fontes_folha: ", spec.saida, " ", img.get_size())
