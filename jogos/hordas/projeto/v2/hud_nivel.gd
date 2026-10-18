extends Control
## A placa de NÍVEL DO MAPA do HUD da v2 (abaixo das barras e à esquerda dos abates): "NÍVEL 7/30" e, embaixo, a barra do mapa inteiro (do nível 1 ao último),
## com uma marca em cada nível de chefe: losango laranja = mini-chefe, caveira vermelha = chefão (o fim do mapa). Com o chefe do nível em
## campo a ponta da barra pisca em vermelho (o nível está travado até ele morrer). Os números vêm do diretor (v2/diretor.gd) via hud.gd.

const Paleta := preload("res://v2/paleta.gd")
const BARRA_X := 6.0
const BARRA_A := 4.0
const BORDA := 5.0  # a borda da moldura de pedra
## O número do nível é Press Start 2P no tamanho do relógio (16); o rótulo "NÍVEL" é Spleen 8x16 em 16 px (como o resto do texto corrido da v2)
## porque o acento do Í não se lê na Press Start de 8 px. Os dois partilham a MESMA linha de base.
const TAM_NUMERO := 16
const TAM_ROTULO := 16
const FOLGA_ROTULO := 4.0

## Caveira 5x5 do chefão (1 = pixel aceso).
const CAVEIRA := ["01110", "11111", "10101", "11111", "01010"]

var nivel := 1
var total := 30
var fracao := 0.0
var chefes: Array = []  # [{nivel, mini}]
var travado := false
var _pisca := 0.0


## Atualiza a placa (hud.gd chama a cada quadro); só redesenha quando algo muda ou quando a ponta está piscando.
func mostrar(n: int, t: int, f: float, lista: Array, trava: bool, dt: float) -> void:
	var mudou := n != nivel or t != total or absf(f - fracao) > 0.001 or trava != travado or lista.size() != chefes.size()
	nivel = n
	total = maxi(t, 1)
	fracao = clampf(f, 0.0, 1.0)
	chefes = lista
	travado = trava
	_pisca = _pisca + dt if trava else 0.0
	if mudou or trava:
		queue_redraw()


func texto() -> String:
	return "NÍVEL %d/%d" % [nivel, total]


## O y da barra do mapa: rente à borda de baixo da moldura, com o contorno de 1 px dentro da parte lisa dela.
func _barra_y() -> float:
	return size.y - BORDA - 1.0 - BARRA_A


func _x_do_nivel(n: int, larg: float) -> float:
	return BARRA_X + larg * float(n - 1) / float(maxi(total - 1, 1))


func _draw() -> void:
	var fonte := get_theme_font("font")
	var larg := size.x - 2.0 * BARRA_X
	var barra_y := _barra_y()
	var rotulo := "NÍVEL"
	var numeros := "%d/%d" % [nivel, total]
	var fonte_rot: Font = Dados.fonte_texto if Dados.fonte_texto != null else fonte
	var w_rot := fonte_rot.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_ROTULO).x
	var w_num := fonte.get_string_size(numeros, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NUMERO).x
	var cor_txt := Paleta.PERIGO if travado else Paleta.TEXTO
	# o rótulo pequeno e o número grande, lado a lado e centrados como um grupo só, na mesma linha de base: o topo do número começa 1 px
	# abaixo da borda de pedra e a barra do mapa fica logo embaixo dele
	var x0 := roundf((size.x - (w_rot + FOLGA_ROTULO + w_num)) / 2.0)
	var base_y := BORDA + 1.0 + fonte.get_ascent(TAM_NUMERO)
	_texto(fonte_rot, Vector2(x0, base_y), rotulo, TAM_ROTULO, cor_txt)
	_texto(fonte, Vector2(x0 + w_rot + FOLGA_ROTULO, base_y), numeros, TAM_NUMERO, cor_txt)
	# a barra: borda escura, fundo vazio e o preenchimento dourado até onde o mapa já foi
	var fundo := Rect2(BARRA_X - 1.0, barra_y - 1.0, larg + 2.0, BARRA_A + 2.0)
	draw_rect(fundo, Paleta.BARRA_BORDA)
	draw_rect(Rect2(BARRA_X, barra_y, larg, BARRA_A), Paleta.BARRA_VAZIA)
	var cheio := roundf(larg * fracao)
	if cheio > 0.0:
		draw_rect(Rect2(BARRA_X, barra_y, cheio, BARRA_A), Paleta.XP)
		draw_rect(Rect2(BARRA_X, barra_y, cheio, 1.0), Paleta.VALOR)
	if travado and int(_pisca * 4.0) % 2 == 0:
		draw_rect(Rect2(BARRA_X + cheio - 2.0, barra_y - 1.0, 3.0, BARRA_A + 2.0), Paleta.PERIGO)
	# as marcas dos chefes (as já vencidas ficam apagadas)
	for c in chefes:
		var n := int(c.nivel)
		var x := roundf(_x_do_nivel(n, larg))
		var vencido := n < nivel or (n == nivel and not travado and n < total)
		if bool(c.mini):
			var cor := Paleta.TEXTO_APAGADO if vencido else Paleta.CARGA_LARANJA
			var cy := barra_y + BARRA_A / 2.0
			for i in 3:  # losango 5x5 em degraus
				var meia := float(2 - i)
				draw_rect(Rect2(x - meia - 0.5, cy - 2.5 + i, meia * 2.0 + 1.0, 1.0), cor)
				draw_rect(Rect2(x - meia - 0.5, cy + 2.5 - i - 1.0, meia * 2.0 + 1.0, 1.0), cor)
		else:
			var cor_c := Paleta.PERIGO if not travado or int(_pisca * 4.0) % 2 == 0 else Paleta.BRANCO
			var o := Vector2(minf(x - 2.0, size.x - 6.0), barra_y - 1.0)
			draw_rect(Rect2(o - Vector2(1, 1), Vector2(7, 7)), Paleta.BARRA_BORDA)
			for yy in CAVEIRA.size():
				for xx in CAVEIRA[yy].length():
					if CAVEIRA[yy][xx] == "1":
						draw_rect(Rect2(o + Vector2(xx, yy), Vector2.ONE), cor_c)


func _texto(fonte: Font, pos: Vector2, t: String, tam: int, cor: Color) -> void:
	draw_string_outline(fonte, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 2, Paleta.PRETO)
	draw_string(fonte, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
