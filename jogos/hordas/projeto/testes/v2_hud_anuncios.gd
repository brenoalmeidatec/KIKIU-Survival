extends "res://testes/isolamento_v2.gd"
# Teste automático da FAIXA DE ANÚNCIO do HUD da v2 (v2/hud_anuncios.gd, no hud.tscn): o texto aparece INTEIRO, sem corte (#443). Texto curto fica
# numa linha na fonte cheia; o que passa disso encolhe a fonte; o que ainda não cabe quebra em linhas na largura máxima. Confere com o maior texto
# de placa que os dados da v2 trazem, com nomes de chefe longos e com textos de 45+ e 120+ letras, em telas do HUD de 960x540 para cima.
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_hud_anuncios.tscn  (imprime "v2_hud_anuncios falhas=0")
const Hud := preload("res://v2/hud.gd")
const Anuncios := preload("res://v2/hud_anuncios.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const PASSO := 1.0 / 60.0
const CANVAS_MIN := Vector2(960, 540)
const COR := Color(1.0, 0.8, 0.4)
## Textos fixos: os de hoje e os que vêm por aí (nomes de chefe mais longos).
const FIXOS := [
	"VITÓRIA!",
	"ULTIMATE PRONTA",
	"ORDEM ERRADA: os pilares se apagam",
	"Devoradora da Estrutura chegou!",
	"CHEFE: DEVORADORA DA ESTRUTURA",
	"CHEFE: Devoradora da Estrutura, Senhora das Ruínas",
	"MINI-CHEFE: Vigia Esquecido do Portão do Cemitério Velho",
	"MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM",
	"Um texto muito, muito, muito longo para uma faixa de anúncio de HUD, de propósito, para estressar a quebra de linha e a fonte mínima da faixa",
]

var falhas := 0


class Heroi:
	extends RefCounted
	var vida := 100.0
	var vida_max := 100.0
	var folego := 3.0
	var folego_max := 3.0
	var cansado := false
	var chave := "hazaki"
	var esp_nome := "Corte Relâmpago"
	var esp_carga := 0.0
	var esp_carga_max := 100.0
	var esp_cor := Color(0.55, 0.85, 1.0)
	var esp_rotulo := "CORTE"
	var escudo_ativo := false


class MundoFalso:
	extends RefCounted
	var heroi := Heroi.new()
	var tempo_partida := 95.0
	var abates := 12
	var combo := 12
	var monstros_vivos := 30


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var vista := SubViewport.new()
	vista.size = Vector2i(960, 540)
	vista.disable_3d = true
	add_child(vista)
	var hud = Hud.criar(MundoFalso.new())
	vista.add_child(hud)
	hud.set_process(false)
	hud.avancar(PASSO)
	var textos: Array = FIXOS.duplicate()
	var placa := _maior_placa()
	ok(placa.length() >= 55, "os dados da v2 têm uma placa de 55+ letras (achou %d)" % placa.length())
	textos.append(placa)
	textos.append("x".repeat(45) + " " + "y".repeat(5))  # 51 letras
	for t in textos:
		_cabe_inteiro(hud, str(t))
	_curto_fica_como_antes(hud)
	_fila_com_longos(hud)
	vista.queue_free()
	print("v2_hud_anuncios falhas=%d" % falhas)
	get_tree().quit()


## O maior "texto" de uma placa em dados/v2_*.json (as placas das Ruínas são o caso do relato).
func _maior_placa() -> String:
	var maior := ""
	var pasta := "res://dados/"
	for arq in DirAccess.get_files_at(pasta):
		if not (arq.begins_with("v2_") and arq.ends_with(".json")):
			continue
		var f := FileAccess.open(pasta + arq, FileAccess.READ)
		if f == null:
			continue
		var j = JSON.parse_string(f.get_as_text())
		if j != null:
			maior = _varrer(j, maior)
	return maior


func _varrer(no, maior: String) -> String:
	if no is Dictionary:
		if str(no.get("tipo", "")) == "placa" and str(no.get("texto", "")).length() > maior.length():
			maior = str(no["texto"])
		for k in no:
			maior = _varrer(no[k], maior)
	elif no is Array:
		for x in no:
			maior = _varrer(x, maior)
	return maior


## Avança o HUD até a faixa esvaziar (anúncio da tela e fila).
func _esvaziar(hud) -> void:
	var an = hud.get_node("Raiz/Anuncio")
	an.fila.clear()
	for i in 400:
		if not an.ocupado():
			break
		hud.avancar(PASSO)


## Mostra o texto, deixa a entrada assentar (escala 1,0) e confere que nada dele fica de fora da faixa nem da tela.
func _cabe_inteiro(hud, texto: String) -> void:
	_esvaziar(hud)
	var an = hud.get_node("Raiz/Anuncio")
	an.anunciar(texto, COR, 0)
	for i in 30:
		hud.avancar(PASSO)
	var rot := "'%s' (%d letras)" % [texto.left(30), texto.length()]
	var lb: Label = an.get_node("Texto")
	ok(an.texto_ativo == texto and lb.text == texto, "%s: o texto na tela é o inteiro" % rot)
	ok(not lb.clip_text and lb.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "%s: o Label não corta nem põe reticências" % rot)
	ok(lb.get_line_count() == lb.get_visible_line_count(), "%s: todas as linhas do Label estão visíveis" % rot)
	var fonte: Font = lb.get_theme_font("font")
	var tam: int = lb.get_theme_font_size("font_size")
	ok(tam >= Anuncios.TAM_MIN and tam <= Anuncios.TAM_FONTE, "%s: fonte %d dentro dos limites" % [rot, tam])
	var linhas := lb.get_line_count()
	ok(linhas * fonte.get_height(tam) <= lb.size.y + 0.01, "%s: %d linhas de %d px cabem na altura %s" % [rot, linhas, tam, lb.size.y])
	# a maior linha, medida com a mesma quebra do Label, cabe na largura dele
	var medida := fonte.get_multiline_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, lb.size.x, tam)
	ok(medida.x <= lb.size.x + 0.5, "%s: a maior linha (%s) cabe na largura do Label (%s)" % [rot, medida.x, lb.size.x])
	if linhas == 1:
		var w := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		ok(w <= lb.size.x + 0.5, "%s: em uma linha, o texto (%s) cabe no Label (%s)" % [rot, w, lb.size.x])
	ok(Rect2(Vector2.ZERO, an.size).encloses(Rect2(lb.position, lb.size)), "%s: o Label fica dentro da faixa" % rot)
	ok(an.scale == Vector2.ONE, "%s: a entrada assentou (escala %s)" % [rot, an.scale])
	ok(an.size.x <= Anuncios.LARGURA_MAX + 0.01, "%s: a faixa (%s) não passa da largura máxima" % [rot, an.size.x])
	for tela in [[Vector2(960, 540), "auto"], [Vector2(1920, 1080), "grande"], [Vector2(1920, 1080), "auto"], [Vector2(3440, 1440), "auto"]]:
		var canvas := EscalaUi.canvas(tela[0], tela[1])
		var d := EscalaUi.deslocamento(canvas)
		hud.ui_reencaixar(canvas, d)
		hud.avancar(PASSO)
		var r := Rect2(an.position + d, an.size * an.scale)
		ok(Rect2(Vector2.ZERO, canvas).encloses(r), "%s: a faixa %s cabe no canvas %s (janela %s)" % [rot, r, canvas, tela[0]])
		ok(canvas.x >= CANVAS_MIN.x and canvas.y >= CANVAS_MIN.y, "canvas %s não é menor que o bloco 960x540" % canvas)
	hud.ui_reencaixar(CANVAS_MIN, Vector2.ZERO)


## Texto curto continua numa linha só, na fonte cheia, com a faixa na altura de sempre; o nome de chefe longo cabe numa linha.
func _curto_fica_como_antes(hud) -> void:
	_esvaziar(hud)
	var an = hud.get_node("Raiz/Anuncio")
	var lb: Label = an.get_node("Texto")
	an.anunciar("NÍVEL 7!", COR, 0)
	hud.avancar(PASSO)
	ok(lb.get_theme_font_size("font_size") == Anuncios.TAM_FONTE and lb.get_line_count() == 1, "texto curto: fonte cheia e uma linha")
	ok(an.size.y == Anuncios.ALTURA, "texto curto: faixa na altura de sempre (%s)" % an.size.y)
	_esvaziar(hud)
	an.anunciar("Devoradora da Estrutura chegou!", COR, 0)
	hud.avancar(PASSO)
	ok(an.size.y == Anuncios.ALTURA and lb.get_line_count() == 1, "'Devoradora da Estrutura chegou!' cabe numa linha (altura %s)" % an.size.y)


## Um anúncio longo na frente de outro: o seguinte volta à fonte, às linhas e à altura certas (a faixa não herda o ajuste do anterior).
func _fila_com_longos(hud) -> void:
	_esvaziar(hud)
	var an = hud.get_node("Raiz/Anuncio")
	var lb: Label = an.get_node("Texto")
	an.anunciar("x".repeat(30) + " " + "y".repeat(30), COR, 0)
	an.anunciar("ONDA FORTE!", COR, 0)
	hud.avancar(PASSO)
	ok(lb.get_line_count() >= 2 or lb.get_theme_font_size("font_size") < Anuncios.TAM_FONTE, "o anúncio longo ocupa mais de uma linha ou fonte menor")
	for i in 120:
		hud.avancar(PASSO)
	ok(an.texto_ativo == "ONDA FORTE!", "o segundo anúncio da fila é o seguinte (%s)" % an.texto_ativo)
	ok(
		lb.get_line_count() == 1 and lb.get_theme_font_size("font_size") == Anuncios.TAM_FONTE and an.size.y == Anuncios.ALTURA,
		"depois de um longo, o curto volta à fonte cheia, uma linha e altura normal"
	)
