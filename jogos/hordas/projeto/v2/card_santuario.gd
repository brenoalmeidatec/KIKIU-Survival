extends Control
## O card de barrinhas do painel do santuário (v2/salao.gd): até três linhas, cada uma com rótulo à esquerda, valor à direita, uma
## barra gráfica e uma nota curta embaixo (a altura do card acompanha o conteúdo). O salão monta as linhas (`mostrar`) e o card só desenha. Tipos de barra:
## "segmentos" (n de max em quadradinhos, como o nível), "barra" (fração cheia, com um pedaço "fantasma" do próximo nível).
## Uma linha pode trazer um ícone (Texture2D) antes da nota, como a recompensa do códice.

const Paleta := preload("res://v2/paleta.gd")
const MARGEM := 16.0
const ESPACO := 18.0  # entre uma linha e outra (o divisor fica no meio)
const ALT_BARRA := 16.0
const TAM := Paleta.TEXTO_TAMANHO

var linhas: Array = []  # o que está na tela: [{rotulo, valor, cor_valor, tipo, n, max, frac, fantasma, cor, nota, cor_nota, icone}]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = sem_luz()  # as luzes 2D da sala (salao_vivo) também alcançam a camada da interface e estouravam as cores das barras


## Material que ignora as luzes 2D: para o que é interface e precisa da cor exata da paleta (barras e ícones).
static func sem_luz() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m


## Troca as linhas e ajusta a altura do card ao conteúdo (linha sem nota é mais baixa; o card não sobra vazio embaixo).
func mostrar(novas: Array) -> void:
	linhas = novas
	var alt := MARGEM * 2.0 - ESPACO
	for l in linhas:
		alt += altura_da(l) + ESPACO
	size.y = alt
	queue_redraw()


## Altura de uma linha: rótulo (20) + barra (16) + nota (22), sem a nota quando ela não existe; sem barra, a nota sobe.
static func altura_da(l: Dictionary) -> float:
	var tem_nota: bool = str(l.get("nota", "")) != "" or l.get("icone", null) != null
	if str(l.get("tipo", "")) == "":
		return 24.0 + 32.0
	return 24.0 + ALT_BARRA + (30.0 if tem_nota else 0.0)


func _draw() -> void:
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Paleta.alfa(Paleta.PAINEL, 0.7)
	fundo.border_color = Paleta.BORDA
	fundo.set_border_width_all(1)
	draw_style_box(fundo, Rect2(Vector2.ZERO, size))
	var fonte: Font = Dados.fonte_texto
	var largura := size.x - MARGEM * 2.0
	var y := MARGEM
	for i in linhas.size():
		var l: Dictionary = linhas[i]
		if i > 0:  # divisor fino entre as linhas
			draw_line(Vector2(MARGEM, y - ESPACO / 2.0), Vector2(size.x - MARGEM, y - ESPACO / 2.0), Paleta.alfa(Paleta.DIVISOR, 0.25), 1.0)
		var base := y + fonte.get_ascent(TAM)
		draw_string(fonte, Vector2(MARGEM, base), str(l.get("rotulo", "")), HORIZONTAL_ALIGNMENT_LEFT, largura * 0.45, TAM, Paleta.CABECALHO)
		var valor := str(l.get("valor", ""))
		draw_string(fonte, Vector2(MARGEM + largura * 0.35, base), valor, HORIZONTAL_ALIGNMENT_RIGHT, largura * 0.65, TAM, l.get("cor_valor", Paleta.TEXTO))
		var barra := Rect2(MARGEM, y + 24.0, largura, ALT_BARRA)
		var y_nota := y + 24.0 + ALT_BARRA + 8.0
		var lado_icone := 20.0
		match str(l.get("tipo", "")):
			"segmentos":
				_segmentos(barra, int(l.get("n", 0)), int(l.get("max", 1)), l.get("cor", Paleta.OURO))
			"barra":
				_barra(barra, float(l.get("frac", 0.0)), float(l.get("fantasma", 0.0)), l.get("cor", Paleta.OURO))
			_:  # sem barra: a nota (com ícone maior) ocupa o lugar dela
				y_nota = y + 24.0
				lado_icone = 32.0
		var nota := str(l.get("nota", ""))
		var x_nota := MARGEM
		var icone: Texture2D = l.get("icone", null)
		if icone != null:
			draw_texture_rect(icone, Rect2(MARGEM, y_nota, lado_icone, lado_icone), false)
			x_nota += lado_icone + 8.0
		if nota != "":
			var alt_texto := fonte.get_height(TAM)
			var y_texto := y_nota + maxf(0.0, (lado_icone - alt_texto) / 2.0) if icone != null else y_nota
			draw_string(
				fonte,
				Vector2(x_nota, y_texto + fonte.get_ascent(TAM)),
				nota,
				HORIZONTAL_ALIGNMENT_LEFT,
				largura - (x_nota - MARGEM),
				TAM,
				l.get("cor_nota", Paleta.TEXTO_SECUNDARIO)
			)
		y += altura_da(l) + ESPACO


## `n` de `mx` em quadradinhos: os cheios na cor, os vazios em BARRA_VAZIA, todos com borda escura.
func _segmentos(r: Rect2, n: int, mx: int, cor: Color) -> void:
	mx = maxi(mx, 1)
	var folga := 4.0
	var w := (r.size.x - folga * (mx - 1)) / mx
	for i in mx:
		var s := Rect2(r.position.x + i * (w + folga), r.position.y, w, r.size.y)
		draw_rect(s, Paleta.BARRA_BORDA)
		draw_rect(s.grow(-2.0), cor if i < n else Paleta.BARRA_VAZIA)
		if i < n:  # brilho de 2 px no topo, como as barras do HUD
			draw_rect(Rect2(s.position + Vector2(2, 2), Vector2(s.size.x - 4.0, 2.0)), Paleta.alfa(Paleta.BRANCO, 0.25))


## Barra contínua: `frac` cheio na cor e, de `frac` até `fantasma`, a mesma cor apagada (o que o próximo nível acrescenta).
func _barra(r: Rect2, frac: float, fantasma: float, cor: Color) -> void:
	frac = clampf(frac, 0.0, 1.0)
	fantasma = clampf(fantasma, frac, 1.0)
	draw_rect(r, Paleta.BARRA_BORDA)
	var dentro := r.grow(-2.0)
	draw_rect(dentro, Paleta.BARRA_VAZIA)
	if fantasma > frac:
		draw_rect(Rect2(dentro.position + Vector2(dentro.size.x * frac, 0), Vector2(dentro.size.x * (fantasma - frac), dentro.size.y)), Paleta.alfa(cor, 0.35))
	if frac > 0.0:
		draw_rect(Rect2(dentro.position, Vector2(dentro.size.x * frac, dentro.size.y)), cor)
		draw_rect(Rect2(dentro.position, Vector2(dentro.size.x * frac, 2.0)), Paleta.alfa(Paleta.BRANCO, 0.25))
