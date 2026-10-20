shader_type canvas_item;
// Fundo vivo da tela de título (v2/titulo_vivo.gd) sobre a arte assets/titulo/fundo.png (960x540).
// Tudo numa passada só, para o PC fraco: câmera lenta (zoom e deriva), halo da lua, nuvens passando na frente dela, névoa no
// chão, brilho na água do pântano, clarão do relâmpago e vinheta. O ruído é amostrado na grade de pixels da arte e os níveis são
// quantizados, para a névoa e as nuvens terem cara de pixel art e não de borrão liso.

uniform sampler2D ruido : repeat_enable, filter_linear;
uniform float zoom = 1.03;
uniform vec2 deriva = vec2(0.0);
uniform float clarao = 0.0;  // 0 a 1: o relâmpago
uniform vec2 lua = vec2(0.854, 0.102);  // centro da lua na arte (UV)
uniform vec2 arte = vec2(960.0, 540.0);  // pixels da arte: a grade do ruído

float niveis(float v, float n) {
	return floor(v * n + 0.5) / n;
}

void fragment() {
	vec2 uv = (UV - 0.5) / zoom + 0.5 + deriva;
	vec4 c = texture(TEXTURE, uv);
	vec2 q = floor(uv * arte) / arte;  // a grade da arte
	float t = TIME;

	// lua: halo que respira e nuvens que passam na frente dela
	vec2 d = (q - lua) * vec2(arte.x / arte.y, 1.0);
	float r = length(d);
	float halo = smoothstep(0.24, 0.0, r);
	float n1 = texture(ruido, q * vec2(1.1, 2.2) + vec2(t * 0.0045, 0.0)).r;
	float n2 = texture(ruido, q * vec2(2.6, 4.0) + vec2(t * 0.009, t * 0.0015)).r;
	float nuvem = smoothstep(0.5, 0.82, n1 * 0.62 + n2 * 0.48) * smoothstep(0.46, 0.06, q.y);
	nuvem = niveis(nuvem, 5.0);
	vec3 cor_nuvem = mix(vec3(0.04, 0.05, 0.1), vec3(0.62, 0.68, 0.86), pow(halo, 1.6));
	c.rgb = mix(c.rgb, cor_nuvem, nuvem * 0.6);
	float respira = 0.85 + 0.15 * sin(t * 0.6);
	c.rgb += vec3(0.5, 0.58, 0.82) * niveis(halo * halo, 6.0) * 0.16 * respira * (1.0 - nuvem * 0.7);

	// névoa rasteira: duas camadas em sentidos opostos, mais densa na beira da água
	float f1 = texture(ruido, q * vec2(1.4, 5.0) + vec2(-t * 0.010, 0.0)).r;
	float f2 = texture(ruido, q * vec2(3.2, 8.0) + vec2(t * 0.017, 0.0)).r;
	float banda = smoothstep(0.38, 0.6, q.y) * smoothstep(1.02, 0.72, q.y);
	float nevoa = niveis(smoothstep(0.4, 0.82, f1 * 0.66 + f2 * 0.44) * banda, 4.0);
	c.rgb = mix(c.rgb, vec3(0.38, 0.44, 0.6), nevoa * 0.3);

	// água do pântano (direita, embaixo): reflexo da lua cintilando onde a arte já é clara
	float agua = smoothstep(0.6, 0.66, q.y) * smoothstep(0.58, 0.7, q.x) * smoothstep(1.0, 0.9, q.y);
	float onda = texture(ruido, q * vec2(9.0, 34.0) + vec2(t * 0.025, 0.0)).r;
	float luz = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	c.rgb += vec3(0.62, 0.72, 0.98) * agua * step(0.7, onda) * smoothstep(0.16, 0.42, luz) * 0.45;

	// relâmpago: o céu clareia mais que o chão
	c.rgb += vec3(0.5, 0.58, 0.95) * clarao * (0.15 + 0.55 * smoothstep(0.75, 0.0, q.y));

	// vinheta e chão mais escuro (os botões ficam legíveis)
	vec2 v = (UV - 0.5) * vec2(1.05, 1.35);
	c.rgb *= mix(1.0, 0.5, smoothstep(0.42, 0.95, length(v)));
	COLOR = c;
}
