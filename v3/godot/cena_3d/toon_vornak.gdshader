// Toon de 2 tons (luz e sombra, corte seco) para o Vornak 3D. Sem especular, sem PBR, sem luz ambiente.
// A cor final vem só de cor_luz/cor_sombra (paleta da folha) mais a emissão controlada por "intensidade".
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform vec4 cor_luz : source_color = vec4(0.420, 0.290, 0.180, 1.0);    // #6b4a2e madeira
uniform vec4 cor_sombra : source_color = vec4(0.247, 0.173, 0.110, 1.0); // #3f2c1c madeira escura
uniform vec4 cor_emissao : source_color = vec4(0.722, 1.0, 0.290, 1.0);  // #b8ff4a energia
uniform float forca_emissao : hint_range(0.0, 2.0) = 0.0;  // 0 nas partes sem brilho
uniform float intensidade : hint_range(0.0, 4.0) = 1.0;    // pulso das fendas e dos olhos (0 a 4)
uniform float limiar : hint_range(-1.0, 1.0) = 0.15;       // onde a luz vira sombra

void fragment() {
	ALBEDO = vec3(1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = cor_emissao.rgb * forca_emissao * intensidade;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = step(limiar, ndl) * step(0.5, ATTENUATION);
	DIFFUSE_LIGHT = mix(cor_sombra.rgb, cor_luz.rgb, t);
}
