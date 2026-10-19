// Chão de teste: ladrilhos de 1 m em 2 tons de verde da paleta, com junta escura e a mesma luz de 2 tons do toon.
// Serve para o movimento do chefe ficar visível com a câmera seguindo.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform vec4 cor_a : source_color = vec4(0.204, 0.329, 0.122, 1.0);   // #34541f
uniform vec4 cor_b : source_color = vec4(0.165, 0.184, 0.212, 1.0);   // #2a2f36
uniform vec4 cor_junta : source_color = vec4(0.118, 0.208, 0.078, 1.0); // #1e3514
uniform float escurecer_sombra = 0.6;
uniform float tamanho = 1.0;

varying vec3 pos_mundo;

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = vec3(1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	vec2 q = pos_mundo.xz / tamanho;
	vec2 f = fract(q);
	float xadrez = mod(floor(q.x) + floor(q.y), 2.0);
	float junta = step(f.x, 0.04) + step(f.y, 0.04);
	vec3 c = mix(cor_a.rgb, mix(cor_a.rgb, cor_b.rgb, 0.35), xadrez);
	c = mix(c, cor_junta.rgb, clamp(junta, 0.0, 1.0));
	float luz = step(0.5, ATTENUATION);
	DIFFUSE_LIGHT = c * mix(escurecer_sombra, 1.0, luz);
}
