extends Control
## Quadradinho do HUD (ícone de build, habilidade, consumível): moldura, ícone, relógio de recarga e dois textos
## pequenos. É um nó de cena; quem o usa só chama `definir()` a cada quadro e ele só redesenha se algo mudou.
## O texto usa a fonte e o tamanho do Theme do HUD (então obedece à opção "Tamanho da fonte do HUD").

const Mochila := preload("res://scripts/hordas/mochila.gd")

var _e := {}


## Chaves (todas opcionais): tex, item (id de consumível da mochila), borda, fundo, tom, apagado, recarga (0..1 que ainda falta),
## sup (texto no canto de cima à direita), inf (texto embaixo à esquerda), cor_sup, cor_inf, vazio (quadro oco).
func definir(e: Dictionary) -> void:
	if e == _e:
		return
	_e = e
	queue_redraw()


func _txt(p: Vector2, s: String, cor: Color, larg: float, alinhar: HorizontalAlignment) -> void:
	if s == "":
		return
	var f := get_theme_default_font()
	var tam := get_theme_default_font_size()
	draw_string(f, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, 0.85))
	draw_string(f, p, s, alinhar, larg, tam, cor)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var borda: Color = _e.get("borda", Color(0.35, 0.38, 0.5))
	if bool(_e.get("vazio", false)):
		draw_rect(r, Color(borda, 0.5), false, 1.0)
		draw_rect(r.grow(-1.0), Color(0.04, 0.04, 0.08, 0.45))
		return
	draw_rect(r, borda)
	draw_rect(r.grow(-1.0), _e.get("fundo", Color(0.06, 0.06, 0.1)))
	var area := r.grow(-2.0)
	if _e.has("item"):
		Mochila.desenhar_icone(self, str(_e.item), area, bool(_e.get("apagado", false)))
	elif _e.get("tex") is Texture2D:
		var t: Texture2D = _e.tex
		# ícones de 16 px ficam nítidos no tamanho original; rostos e outros esticam para a área
		if t.get_width() <= 16 and area.size.x >= 16.0:
			draw_texture(t, (r.size - t.get_size()) * 0.5, _e.get("tom", Color.WHITE))
		else:
			draw_texture_rect(t, area, false, _e.get("tom", Color.WHITE))
	var falta: float = clampf(float(_e.get("recarga", 0.0)), 0.0, 1.0)
	if falta > 0.01:
		# relógio: a parte que falta da recarga fica escura, girando no sentido horário a partir do topo
		var c := r.get_center()
		var pts := PackedVector2Array([c])
		var passos := 24
		for i in passos + 1:
			var a := -PI / 2 + TAU * (1.0 - falta) + TAU * falta * i / passos
			var dir := Vector2.from_angle(a)
			var ate := (area.size.x * 0.5) / maxf(absf(dir.x), absf(dir.y))   # até a borda do quadro, não um círculo
			pts.append(c + dir * ate)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	if _e.has("barra"):   # tempo restante de um efeito: barrinha de 2 px no pé do quadro
		draw_rect(Rect2(1, size.y - 3.0, size.x - 2.0, 2.0), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(1, size.y - 3.0, (size.x - 2.0) * clampf(float(_e.barra), 0.0, 1.0), 2.0), _e.get("cor_barra", Color.WHITE))
	var tam := float(get_theme_default_font_size())
	_txt(Vector2(0, tam + 1.0), str(_e.get("sup", "")), _e.get("cor_sup", Color.WHITE), size.x - 2.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_txt(Vector2(2, size.y - 2.0), str(_e.get("inf", "")), _e.get("cor_inf", Color(0.85, 0.87, 0.95)), size.x - 2.0, HORIZONTAL_ALIGNMENT_LEFT)
