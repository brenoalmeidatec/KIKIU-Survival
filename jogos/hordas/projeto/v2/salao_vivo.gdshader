shader_type canvas_item;
render_mode blend_add, unshaded;
// Salão vivo (v2/salao_vivo.gd). Dois usos, escolhidos por `modo`; sempre aditivo, em pixel inteiro (UV quantizado em células de `tam`).
//   modo 0: vão do portal. Redemoinho e ondas com ruído procedural, máscara em arco, brilhos pontuais. `forca` é a reação ao herói.
//   modo 1: névoa rasteira do rodapé (ruído que anda devagar, alfa baixo). O tempo `t` vem do script e para com a pausa e com o painel.

uniform int modo = 0;
uniform vec4 cor : source_color = vec4(0.3, 0.6, 0.4, 1.0);
uniform float t = 0.0;
uniform float forca = 1.0;
uniform float semente = 0.0;
uniform vec2 tam = vec2(40.0, 78.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 3; i++) {
		s += a * ruido(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec2 px = floor(UV * tam);
	vec2 uv = (px + 0.5) / tam;
	if (modo == 0) {
		float meio = tam.x * 0.5;
		vec2 c = vec2((uv.x - 0.5) * tam.x, uv.y * tam.y);
		float dentro = c.y < meio ? step(length(vec2(c.x, c.y - meio)), meio) : step(abs(c.x), meio);
		vec2 p = vec2(c.x, c.y - (meio + tam.y * 0.18)) / meio;
		float r = length(p);
		float ang = atan(p.y, p.x) + 1.7 / (r + 0.35) - t * 0.7;
		vec2 giro = vec2(cos(ang), sin(ang)) * r;
		float n = fbm(giro * 2.4 + vec2(semente, t * 0.3));
		float onda = 0.5 + 0.5 * sin(r * 9.0 - t * 2.1 + n * 4.5 + semente * 3.0);
		float padrao = mix(n, onda, 0.45);
		padrao = floor(smoothstep(0.18, 0.95, padrao) * 5.0) / 5.0;
		float luz = (0.3 + 0.7 * padrao) * forca;
		float estrela = step(0.987, hash(px + floor(t * 2.5) * 7.0 + semente)) * 0.9;
		COLOR = vec4(cor.rgb * (luz * 0.62 + estrela), dentro);
	} else {
		float x = uv.x * 7.0 + t * 0.035;
		float n = fbm(vec2(x, uv.y * 3.0 + t * 0.012));
		float faixa = smoothstep(0.0, 0.55, uv.y) * (1.0 - smoothstep(0.7, 1.0, uv.y));
		float a = floor(clamp((n - 0.3) * 2.0, 0.0, 1.0) * faixa * 3.0 + 0.5) / 3.0;
		COLOR = vec4(cor.rgb, a * forca * 0.15);
	}
}
