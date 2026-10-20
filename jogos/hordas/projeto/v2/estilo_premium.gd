extends RefCounted
## Visual premium dos menus da v2 (#152, fase V6): uma moldura e uma faixa de seleção para todas as telas, para o jogo ter a mesma
## cara do título ao santuário. Arte em v2/hud/moldura_premium.png e foco_premium.png (gerar_moldura_premium.py); a moldura de pedra
## do Alisson (moldura_pedra.png) continua no repositório para quem ainda a usa. Sem class_name: carregue com preload.

const MOLDURA := preload("res://v2/hud/moldura_premium.png")
const FOCO := preload("res://v2/hud/foco_premium.png")
const OURO := Color("#ffdb6b")
const MARGEM := 10  # a borda da moldura (contorno, bisel, filetes e os losangos dos cantos)


## O painel: moldura dourada com losangos nos cantos e miolo azul-noite. `conteudo` é a folga de dentro.
static func painel(conteudo := 8.0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = MOLDURA
	s.texture_margin_left = MARGEM
	s.texture_margin_top = MARGEM
	s.texture_margin_right = MARGEM
	s.texture_margin_bottom = MARGEM
	s.set_content_margin_all(conteudo)
	return s


## A linha ou o botão escolhido: barra dourada à esquerda e um brilho que some para a direita.
static func foco() -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = FOCO
	s.texture_margin_left = 3
	s.texture_margin_right = 3
	s.texture_margin_top = 2
	s.texture_margin_bottom = 2
	s.set_content_margin_all(4)
	return s


## Botão com o visual dos menus: escuro e translúcido com filete dourado; com foco, a faixa dourada. `recuo` é a folga do texto à
## esquerda (texto alinhado à esquerda acompanha a faixa, que brilha da esquerda para a direita).
static func estilo_botao(b: Button, recuo := 4.0) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.025, 0.05, 0.7)
	normal.border_color = Color(0.78, 0.62, 0.36, 0.45)
	normal.set_border_width_all(1)
	normal.anti_aliasing = false
	normal.set_content_margin_all(4)
	normal.content_margin_left = recuo
	var f := foco()
	f.content_margin_left = recuo
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", f)
	b.add_theme_stylebox_override("focus", f)
	b.add_theme_stylebox_override("pressed", f)


## Linha dourada com um losango no meio e dois pequenos nas pontas: separa o título do conteúdo.
static func ornamento(largura: float) -> Control:
	var c := Control.new()
	c.size = Vector2(largura, 12)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_desenhar_ornamento.bind(c))
	return c


static func _desenhar_ornamento(c: Control) -> void:
	var meio := c.size.x / 2.0
	var y := 6.0
	var passos := int((meio - 14.0) / 8.0)
	for lado in [-1.0, 1.0]:
		for i in passos:
			var x0: float = meio + lado * (12.0 + i * 8.0)
			c.draw_line(Vector2(x0, y), Vector2(x0 + lado * 8.0, y), Color(OURO, 0.85 * (1.0 - float(i) / passos)), 1.0)
		losango(c, Vector2(meio + lado * (meio - 2.0), y), 2.0, Color(OURO, 0.4))
	losango(c, Vector2(meio, y), 5.0, OURO)
	losango(c, Vector2(meio, y), 2.0, Color(0.15, 0.08, 0.02))


static func losango(c: CanvasItem, p: Vector2, r: float, cor: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), cor)
