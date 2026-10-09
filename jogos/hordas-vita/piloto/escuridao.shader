// Escuridão por pixel para GLES2: até 8 luzes em uniforms escalares (lN = x, y em pixels de tela, raio; cN = cor).
// Multiplica a cena (blend_mul), então não precisa ler a tela.
shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform vec2 tela = vec2(480.0, 272.0);
uniform vec3 ambiente = vec3(0.16, 0.13, 0.26);
uniform vec3 l0; uniform vec3 c0;
uniform vec3 l1; uniform vec3 c1;
uniform vec3 l2; uniform vec3 c2;
uniform vec3 l3; uniform vec3 c3;
uniform vec3 l4; uniform vec3 c4;
uniform vec3 l5; uniform vec3 c5;
uniform vec3 l6; uniform vec3 c6;
uniform vec3 l7; uniform vec3 c7;

vec3 luz(vec2 p, vec3 l, vec3 c) {
	float d = clamp(length(p - l.xy) / l.z, 0.0, 1.0);
	return c * pow(1.0 - d, 1.6);
}

void fragment() {
	vec2 p = UV * tela;
	vec3 s = ambiente;
	s += luz(p, l0, c0);
	s += luz(p, l1, c1);
	s += luz(p, l2, c2);
	s += luz(p, l3, c3);
	s += luz(p, l4, c4);
	s += luz(p, l5, c5);
	s += luz(p, l6, c6);
	s += luz(p, l7, c7);
	COLOR = vec4(min(s, vec3(1.0)), 1.0);
}
