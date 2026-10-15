shader_type canvas_item;
// Contorno claro de 1 px do herói (v2/heroi.gd, aplicar_legibilidade; números em dados/v2_herois.json, "legibilidade"): onde o pixel é
// vazio e algum vizinho (4 direções) é corpo, pinta a cor do contorno. Sem TIME: a borda não pisca nem depende do relógio.
// O alfa do sprite (piscada de dano, esquiva) multiplica o contorno, então ele some junto com o corpo.
uniform vec4 cor_contorno : source_color = vec4(1.0, 0.93, 0.8, 0.85);
uniform float forca : hint_range(0.0, 1.0) = 1.0;
varying float alfa_corpo;

void vertex() {
	alfa_corpo = COLOR.a;
}

void fragment() {
	vec4 corpo = COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float viz = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	viz = max(viz, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	viz = max(viz, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	viz = max(viz, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	float borda = step(0.5, viz) * (1.0 - step(0.01, texture(TEXTURE, UV).a));
	float a = cor_contorno.a * forca * alfa_corpo * borda;
	COLOR = vec4(mix(corpo.rgb, cor_contorno.rgb, borda), max(corpo.a, a));
}
