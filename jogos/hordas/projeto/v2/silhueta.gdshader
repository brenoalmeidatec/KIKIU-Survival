shader_type canvas_item;
// Silhueta do herói (oclusao.gd): preenchimento translúcido por dentro e contorno de 1 px por fora.
// COLOR.a é a transição (a silhueta entra e some aos poucos): o sprite vem com modulate.a = alfa do oclusao.gd.
// UV já é o da textura inteira (o mesmo que o desenho padrão usa), então a máscara do quadro sai direto.

uniform vec4 cor_contorno : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform vec4 cor_preenchimento : source_color = vec4(1.0, 0.8, 0.42, 0.35);

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float a = texture(TEXTURE, UV).a;
	float vizinho = max(
		max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a)
	);
	if (a > 0.5) {
		COLOR = vec4(cor_preenchimento.rgb, cor_preenchimento.a * COLOR.a);
	} else if (vizinho > 0.5) {
		COLOR = vec4(cor_contorno.rgb, COLOR.a);
	} else {
		COLOR = vec4(0.0);
	}
}
