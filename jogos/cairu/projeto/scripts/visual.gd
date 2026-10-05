class_name Visual
## Acabamento visual: pós-processamento (cor, brilho, vinheta), transição em losangos,
## partículas no ar, luzes 2D e o estilo das janelas. Tudo em código (nada de arquivo extra).
##
## No mapa (capitulos/mapas/<id>.json), tudo opcional:
##   "visual": {"ambiente": "#e6e2f0", "saturacao": 1.1, "contraste": 1.06, "tinta": "#fff4e6",
##              "sombras": "#101830", "brilho": 0.35, "limiar": 0.72, "vinheta": 0.35}
##   "particulas": [{"tipo": "poeira" | "folhas" | "vapor" | "brilhos" | "faiscas", "x", "y", "w", "h", "quantidade"}]

const AMARELO := Color("ffd34e")
const AZUL := Color("1a2050")

const POS := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_nearest;
uniform float saturacao = 1.1;
uniform float contraste = 1.06;
uniform vec3 tinta = vec3(1.0);
uniform vec3 sombras = vec3(0.04, 0.05, 0.12);
uniform float brilho = 0.35;
uniform float limiar = 0.72;
uniform float vinheta = 0.35;
uniform float ligado = 1.0;
uniform int aneis = 3;    // brilho: 3 = qualidade alta, 1 = média (mais leve)

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(tela, uv).rgb;
	if (ligado > 0.5) {
		vec2 px = SCREEN_PIXEL_SIZE;
		vec3 b = vec3(0.0);
		if (aneis >= 3) {          // qualidade alta: 12 direções x 3 distâncias
			for (int i = 0; i < 12; i++) {
				float a = float(i) * 0.5236;
				vec2 dir = vec2(cos(a), sin(a));
				b += max(texture(tela, uv + dir * 2.0 * px).rgb - limiar, vec3(0.0));
				b += max(texture(tela, uv + dir * 5.0 * px).rgb - limiar, vec3(0.0)) * 0.7;
				b += max(texture(tela, uv + dir * 9.0 * px).rgb - limiar, vec3(0.0)) * 0.4;
			}
			b /= 12.0;
		} else {                   // média: 8 direções x 1 distância
			for (int i = 0; i < 8; i++) {
				float a = float(i) * 0.7854;
				b += max(texture(tela, uv + vec2(cos(a), sin(a)) * 4.0 * px).rgb - limiar, vec3(0.0)) * 2.1;
			}
			b /= 8.0;
		}
		c += b * brilho * 1.6;
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(vec3(l), c, saturacao);
		c = (c - 0.5) * contraste + 0.5;
		c *= tinta;
		c = mix(c, c + sombras, clamp(1.0 - l * 1.6, 0.0, 1.0));
		vec2 d = (uv - 0.5) * vec2(1.0, 0.85);
		c *= clamp(1.0 - dot(d, d) * vinheta * 2.4, 0.0, 1.0);
	}
	COLOR = vec4(c, 1.0);
}
"""

const CORTINA := """
shader_type canvas_item;
uniform float progresso : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cor : source_color = vec4(0.03, 0.035, 0.09, 1.0);
void fragment() {
	vec2 p = SCREEN_UV * vec2(480.0, 270.0);
	vec2 cel = fract(p / 18.0) - 0.5;
	float d = abs(cel.x) + abs(cel.y);
	float onda = (SCREEN_UV.x * 0.7 + SCREEN_UV.y * 0.3) * 0.55;
	float a = step(d, progresso * 1.55 - onda);
	if (progresso >= 0.999) a = 1.0;
	COLOR = vec4(cor.rgb, cor.a * a);
}
"""

const DESFOQUE := """
shader_type canvas_item;
uniform float escuro = 0.5;
uniform vec3 tinta = vec3(0.55, 0.6, 0.95);
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 c = vec3(0.0);
	float n = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			c += texture(TEXTURE, UV + vec2(float(x), float(y)) * px * 1.5).rgb;
			n += 1.0;
		}
	}
	c /= n;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 0.5) * tinta * escuro;
	vec2 d = UV - vec2(0.5, 0.55);
	c *= clamp(1.2 - dot(d, d) * 2.5, 0.0, 1.0);
	COLOR = vec4(c, 1.0);
}
"""

const CEU := """
shader_type canvas_item;
uniform float tempo = 0.0;
void fragment() {
	vec3 alto = vec3(0.04, 0.05, 0.16);
	vec3 meio = vec3(0.16, 0.10, 0.30);
	vec3 baixo = vec3(0.55, 0.22, 0.30);
	float y = UV.y;
	vec3 c = mix(alto, meio, smoothstep(0.0, 0.6, y));
	c = mix(c, baixo, smoothstep(0.55, 1.0, y));
	// faixas de cor em degraus (cara de pixel art)
	c = floor(c * 24.0) / 24.0;
	COLOR = vec4(c, 1.0);
}
"""

static var _shaders := {}


static func shader(nome: String) -> Shader:
	if not _shaders.has(nome):
		var s := Shader.new()
		s.code = {"pos": POS, "cortina": CORTINA, "desfoque": DESFOQUE, "ceu": CEU}[nome]
		_shaders[nome] = s
	return _shaders[nome]


static func ligado() -> bool:
	var jogo := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Jogo")
	return jogo == null or jogo.opcoes.get("visual", true)


## "alta", "media" ou "baixa" (Opções > Qualidade).
static func qualidade() -> String:
	var jogo := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Jogo")
	return "alta" if jogo == null else str(jogo.opcoes.get("qualidade", "alta"))


# ======================================================== movimento da interface

## Janela que abre com mola (cresce um pouco além e volta) em vez de aparecer seca.
static func surgir(c: Control, tempo := 0.25) -> void:
	if not ligado():
		return
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(0.86, 0.86)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, tempo).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, tempo * 0.6)


## Lista com cursor: a opção escolhida dá um pulinho quando chega e fica pulsando.
## Chame depois de pintar as cores (em todo _atualizar/_marcar).
static func marcar_lista(labels: Array, sel: int) -> void:
	for i in labels.size():
		var l: Control = labels[i]
		var era: bool = l.get_meta("sel", false)
		if i == sel and not era:
			if ligado():
				l.pivot_offset = Vector2(0, l.size.y / 2.0)
				l.scale = Vector2(1.16, 1.16)
				l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				var pulso := l.create_tween().set_loops()
				pulso.tween_property(l, "modulate", Color(1.35, 1.3, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
				pulso.tween_property(l, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
				l.set_meta("pulso", pulso)
		elif i != sel and era:
			var pulso = l.get_meta("pulso", null)
			if pulso is Tween and pulso.is_valid():
				pulso.kill()
			l.scale = Vector2.ONE
			l.modulate = Color.WHITE
		l.set_meta("sel", i == sel)


## Camada de pós-processamento (cor, brilho em volta das luzes, vinheta).
static func criar_pos(layer: int) -> CanvasLayer:
	var c := CanvasLayer.new()
	c.layer = layer
	var r := ColorRect.new()
	r.name = "Pos"
	r.size = Vector2(480, 270)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = shader("pos")
	r.material = m
	c.add_child(r)
	return c


## Aplica o "visual" de um mapa (ou os padrões) na camada de pós.
static func ajustar_pos(camada: CanvasLayer, v: Dictionary, tempo := 0.6) -> void:
	var r: ColorRect = camada.get_node("Pos")
	var m: ShaderMaterial = r.material
	r.visible = ligado()
	m.set_shader_parameter("aneis", 3 if qualidade() == "alta" else 1)
	var alvo := {
		"saturacao": float(v.get("saturacao", 1.1)), "contraste": float(v.get("contraste", 1.06)),
		"brilho": float(v.get("brilho", 0.35)), "limiar": float(v.get("limiar", 0.72)),
		"vinheta": float(v.get("vinheta", 0.35)),
	}
	var tinta := Color(v.get("tinta", "#ffffff"))
	var sombras := Color(v.get("sombras", "#0a0c1e"))
	var tw := camada.create_tween().set_parallel(true)
	for k in alvo:
		tw.tween_method(func(x): m.set_shader_parameter(k, x), m.get_shader_parameter(k) if m.get_shader_parameter(k) != null else alvo[k], alvo[k], tempo)
	var t0 = m.get_shader_parameter("tinta")
	var s0 = m.get_shader_parameter("sombras")
	tw.tween_method(func(x): m.set_shader_parameter("tinta", x), t0 if t0 != null else Vector3.ONE, Vector3(tinta.r, tinta.g, tinta.b), tempo)
	tw.tween_method(func(x): m.set_shader_parameter("sombras", x), s0 if s0 != null else Vector3.ZERO, Vector3(sombras.r, sombras.g, sombras.b), tempo)


## Cortina de transição (losangos). Use a propriedade "progresso" via set_shader_parameter.
static func criar_cortina() -> ColorRect:
	var r := ColorRect.new()
	r.size = Vector2(480, 270)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = shader("cortina")
	m.set_shader_parameter("progresso", 0.0)
	r.material = m
	return r


static func cortina(r: ColorRect, ate: float, tempo: float) -> Tween:
	var m: ShaderMaterial = r.material
	var tw := r.create_tween()
	tw.tween_method(func(x): m.set_shader_parameter("progresso", x), float(m.get_shader_parameter("progresso")), ate, max(tempo, 0.01))
	return tw


static func progresso(r: ColorRect) -> float:
	return float((r.material as ShaderMaterial).get_shader_parameter("progresso"))


# ======================================================== estilo das janelas

## Caixa padrão: fundo azul, borda dourada dupla e sombra.
static func painel(fundo := AZUL, borda := AMARELO, margem := 6) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = fundo
	e.border_color = borda
	e.set_border_width_all(2)
	e.shadow_color = Color(0, 0, 0, 0.45)
	e.shadow_size = 1
	e.shadow_offset = Vector2(3, 3)
	e.set_content_margin_all(margem)
	return e


## Linha fina interna (dá o efeito de borda dupla) desenhada por cima de um Control.
static func borda_interna(c: Control, cor := Color(1, 0.83, 0.3, 0.35)) -> void:
	c.draw.connect(func(): c.draw_rect(Rect2(Vector2(4, 4), c.size - Vector2(8, 8)), cor, false, 1.0))


# ======================================================== partículas

static var _ponto: ImageTexture


static func _textura_ponto() -> ImageTexture:
	if not _ponto:
		var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		img.set_pixel(1, 1, Color.WHITE)
		img.set_pixel(0, 1, Color(1, 1, 1, 0.5))
		img.set_pixel(2, 1, Color(1, 1, 1, 0.5))
		img.set_pixel(1, 0, Color(1, 1, 1, 0.5))
		img.set_pixel(1, 2, Color(1, 1, 1, 0.5))
		_ponto = ImageTexture.create_from_image(img)
	return _ponto


static var _folha: ImageTexture


static func _textura_folha() -> ImageTexture:
	if not _folha:
		var img := Image.create(4, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		for xy in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2)]:
			img.set_pixelv(xy, Color.WHITE)
		_folha = ImageTexture.create_from_image(img)
	return _folha


static func _rampa(cores: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(range(cores.size()).map(func(i): return float(i) / (cores.size() - 1)))
	g.colors = PackedColorArray(cores)
	return g


## Partículas no ar de um tipo, espalhadas no retângulo dado.
static func particulas(p: Dictionary) -> CPUParticles2D:
	var c := CPUParticles2D.new()
	var tipo: String = p.get("tipo", "poeira")
	var r := Rect2(p.get("x", 0), p.get("y", 0), p.get("w", 480), p.get("h", 270))
	c.position = r.get_center()
	c.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	c.emission_rect_extents = r.size / 2
	c.z_index = 40
	c.preprocess = 8.0
	c.local_coords = false
	var fator := 0.5 if qualidade() == "media" else 1.0   # média: metade das partículas
	match tipo:
		"poeira":
			c.amount = maxi(1, int(int(p.get("quantidade", 24)) * fator))
			c.lifetime = 7.0
			c.direction = Vector2(1, -0.3)
			c.spread = 180
			c.initial_velocity_min = 1.0
			c.initial_velocity_max = 4.0
			c.gravity = Vector2(0, -1.2)
			c.scale_amount_min = 0.5
			c.scale_amount_max = 1.0
			c.color_ramp = _rampa([Color(1, 0.97, 0.85, 0), Color(1, 0.97, 0.85, 0.55), Color(1, 0.97, 0.85, 0)])
			c.texture = _textura_ponto()
		"folhas":
			c.amount = maxi(1, int(int(p.get("quantidade", 10)) * fator))
			c.lifetime = 9.0
			c.direction = Vector2(1, 1)
			c.spread = 30
			c.initial_velocity_min = 6.0
			c.initial_velocity_max = 12.0
			c.gravity = Vector2(3, 6)
			c.angular_velocity_min = -90
			c.angular_velocity_max = 90
			c.scale_amount_min = 1.0
			c.scale_amount_max = 1.5
			c.color_ramp = _rampa([Color(0.45, 0.7, 0.25, 0), Color(0.5, 0.75, 0.25, 1), Color(0.85, 0.6, 0.2, 1), Color(0.85, 0.6, 0.2, 0)])
			c.texture = _textura_folha()
		"vapor":
			c.amount = maxi(1, int(int(p.get("quantidade", 14)) * fator))
			c.lifetime = 2.5
			c.direction = Vector2(0, -1)
			c.spread = 15
			c.initial_velocity_min = 6.0
			c.initial_velocity_max = 10.0
			c.gravity = Vector2(1.5, -2)
			c.scale_amount_min = 1.0
			c.scale_amount_max = 2.0
			c.scale_amount_curve = Curve.new()
			c.scale_amount_curve.add_point(Vector2(0, 0.5))
			c.scale_amount_curve.add_point(Vector2(1, 2.0))
			c.color_ramp = _rampa([Color(1, 1, 1, 0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
			c.texture = _textura_ponto()
		"brilhos":
			c.amount = maxi(1, int(int(p.get("quantidade", 16)) * fator))
			c.lifetime = 2.0
			c.spread = 180
			c.initial_velocity_min = 0.0
			c.initial_velocity_max = 2.0
			c.gravity = Vector2.ZERO
			c.scale_amount_min = 0.6
			c.scale_amount_max = 1.2
			c.color_ramp = _rampa([Color(1, 0.85, 0.4, 0), Color(1, 0.95, 0.6, 1), Color(1, 0.85, 0.4, 0)])
			c.texture = _textura_ponto()
		"faiscas":
			c.amount = maxi(1, int(int(p.get("quantidade", 8)) * fator))
			c.lifetime = 0.8
			c.direction = Vector2(0, -1)
			c.spread = 60
			c.initial_velocity_min = 10.0
			c.initial_velocity_max = 30.0
			c.gravity = Vector2(0, 60)
			c.color_ramp = _rampa([Color(0.6, 0.85, 1, 1), Color(0.4, 0.6, 1, 0)])
			c.texture = _textura_ponto()
		"estrelas":
			c.amount = maxi(1, int(int(p.get("quantidade", 40)) * fator))
			c.lifetime = 4.0
			c.spread = 180
			c.initial_velocity_min = 0.0
			c.initial_velocity_max = 0.5
			c.gravity = Vector2.ZERO
			c.scale_amount_min = 0.4
			c.scale_amount_max = 1.0
			c.color_ramp = _rampa([Color(1, 1, 1, 0), Color(1, 1, 0.9, 0.9), Color(1, 1, 1, 0)])
			c.texture = _textura_ponto()
	return c


# ======================================================== luzes 2D

static var _luz_tex: GradientTexture2D


static func textura_luz() -> GradientTexture2D:
	if not _luz_tex:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_luz_tex = GradientTexture2D.new()
		_luz_tex.gradient = g
		_luz_tex.fill = GradientTexture2D.FILL_RADIAL
		_luz_tex.fill_from = Vector2(0.5, 0.5)
		_luz_tex.fill_to = Vector2(1.0, 0.5)
		_luz_tex.width = 128
		_luz_tex.height = 128
	return _luz_tex


## Luz de verdade (ilumina chão E personagens que passam por ela).
static func luz(r: Rect2, cor: Color, forca: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = textura_luz()
	l.position = r.get_center()
	l.scale = r.size / 128.0
	l.color = cor
	l.energy = forca * 2.0
	l.blend_mode = Light2D.BLEND_MODE_ADD
	return l
