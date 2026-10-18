extends Control
## A placa de NÍVEL DO MAPA do HUD da v2 (abaixo das barras e à esquerda dos abates): "NÍVEL 7/30" e, embaixo, a barra do mapa inteiro (do nível 1 ao último),
## com uma marca em cada nível de chefe: losango laranja = mini-chefe, caveira vermelha = chefão (o fim do mapa). Com o chefe do nível em
## campo a ponta da barra pisca em vermelho (o nível está travado até ele morrer). Os números vêm do diretor (v2/diretor.gd) via hud.gd.

const Paleta := preload("res://v2/paleta.gd")
const BARRA_X := 6.0
const BARRA_Y := 16.0
const BARRA_A := 4.0
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


func _x_do_nivel(n: int, larg: float) -> float:
	return BARRA_X + larg * float(n - 1) / float(maxi(total - 1, 1))


func _draw() -> void:
	var fonte := get_theme_font("font")
	var tam := 8
	var larg := size.x - 2.0 * BARRA_X
	var t := texto()
	var w := fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var cor_txt := Paleta.PERIGO if travado else Paleta.TEXTO
	var pos_txt := Vector2(roundf((size.x - w) / 2.0), 12.0)
	draw_string_outline(fonte, pos_txt, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 2, Paleta.PRETO)
	draw_string(fonte, pos_txt, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor_txt)
	# a barra: borda escura, fundo vazio e o preenchimento dourado até onde o mapa já foi
	var fundo := Rect2(BARRA_X - 1.0, BARRA_Y - 1.0, larg + 2.0, BARRA_A + 2.0)
	draw_rect(fundo, Paleta.BARRA_BORDA)
	draw_rect(Rect2(BARRA_X, BARRA_Y, larg, BARRA_A), Paleta.BARRA_VAZIA)
	var cheio := roundf(larg * fracao)
	if cheio > 0.0:
		draw_rect(Rect2(BARRA_X, BARRA_Y, cheio, BARRA_A), Paleta.XP)
		draw_rect(Rect2(BARRA_X, BARRA_Y, cheio, 1.0), Paleta.VALOR)
	if travado and int(_pisca * 4.0) % 2 == 0:
		draw_rect(Rect2(BARRA_X + cheio - 2.0, BARRA_Y - 1.0, 3.0, BARRA_A + 2.0), Paleta.PERIGO)
	# as marcas dos chefes (as já vencidas ficam apagadas)
	for c in chefes:
		var n := int(c.nivel)
		var x := roundf(_x_do_nivel(n, larg))
		var vencido := n < nivel or (n == nivel and not travado and n < total)
		if bool(c.mini):
			var cor := Paleta.TEXTO_APAGADO if vencido else Paleta.CARGA_LARANJA
			var cy := BARRA_Y + BARRA_A / 2.0
			for i in 3:  # losango 5x5 em degraus
				var meia := float(2 - i)
				draw_rect(Rect2(x - meia - 0.5, cy - 2.5 + i, meia * 2.0 + 1.0, 1.0), cor)
				draw_rect(Rect2(x - meia - 0.5, cy + 2.5 - i - 1.0, meia * 2.0 + 1.0, 1.0), cor)
		else:
			var cor_c := Paleta.PERIGO if not travado or int(_pisca * 4.0) % 2 == 0 else Paleta.BRANCO
			var o := Vector2(minf(x - 2.0, size.x - 6.0), BARRA_Y - 1.0)
			draw_rect(Rect2(o - Vector2(1, 1), Vector2(7, 7)), Paleta.BARRA_BORDA)
			for yy in CAVEIRA.size():
				for xx in CAVEIRA[yy].length():
					if CAVEIRA[yy][xx] == "1":
						draw_rect(Rect2(o + Vector2(xx, yy), Vector2.ONE), cor_c)
