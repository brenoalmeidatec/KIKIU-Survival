shader_type canvas_item;
render_mode unshaded;

uniform float instante = 0.0;
uniform float luz = 0.69;

void fragment() {
	vec2 px = vec2(960.0, 540.0);
	vec2 q = (floor(UV * px) + 0.5) / px;
	// A faixa de tecido mais próxima da câmera inclina com o vento, presa no alto.
	float pano = smoothstep(0.896, 0.921, q.x) * (1.0 - smoothstep(0.976, 1.0, q.x));
	pano *= smoothstep(0.146, 0.305, q.y) * (1.0 - smoothstep(0.435, 0.468, q.y));
	vec2 vento = vec2(round(sin(instante * 1.26 - q.y * 13.0) * pano * 2.5), 0.0) / px;
	vec3 cor = texture(TEXTURE, clamp(q - vento, vec2(0.0), vec2(1.0))).rgb;

	// Nuvens em bandas irregulares, em frente à lua pintada. O contorno do portal fica fora da máscara.
	vec2 lua = (q - vec2(0.800, 0.224)) * vec2(1.78, 1.0);
	float ceu = 1.0 - smoothstep(0.079, 0.149, length(lua));
	float passagem = q.x - instante * 0.022;
	float faixa = sin(passagem * 29.0 + q.y * 36.0) * 0.53 + sin(passagem * 56.0 - q.y * 61.0) * 0.32;
	faixa += sin(passagem * 109.0 + q.y * 96.0) * 0.15;
	float nuvem = floor(smoothstep(-0.04, 0.42, faixa) * 5.0 + 0.5) / 5.0;
	cor = mix(cor, vec3(0.16, 0.24, 0.28), ceu * nuvem * 0.57);

	vec2 d = (q - vec2(0.766, 0.748)) * vec2(1.78, 1.0);
	float halo = floor((1.0 - smoothstep(0.008, 0.084, length(d))) * 6.0 + 0.5) / 6.0;
	cor += vec3(0.23, 0.11, 0.035) * halo * luz;
	COLOR = vec4(cor, 1.0);
}
