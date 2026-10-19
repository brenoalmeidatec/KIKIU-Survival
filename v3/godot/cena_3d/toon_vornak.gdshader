// Toon de 5 tons para o Vornak 3D. Sem especular, sem PBR, sem luz ambiente e sem emissão contínua:
// cada pixel cai num dos 5 tons da rampa do material (paleta fechada), o que mantém a imagem nítida.
// O tom vem da luz (5 faixas de N·L), da sombra projetada, da textura de detalhe (512 px, nearest)
// e de uma luz de borda que sobe um tom na silhueta. Nas partes de energia, o tom segue "intensidade".
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform vec4 tom_0 : source_color = vec4(0.149, 0.102, 0.078, 1.0); // sombra funda
uniform vec4 tom_1 : source_color = vec4(0.247, 0.173, 0.110, 1.0); // sombra
uniform vec4 tom_2 : source_color = vec4(0.361, 0.247, 0.157, 1.0); // meio
uniform vec4 tom_3 : source_color = vec4(0.478, 0.333, 0.204, 1.0); // luz
uniform vec4 tom_4 : source_color = vec4(0.612, 0.463, 0.314, 1.0); // brilho
uniform sampler2D detalhe : filter_nearest_mipmap, repeat_enable;
uniform float escala_uv = 1.0;
uniform float usa_detalhe : hint_range(0.0, 1.0) = 1.0;
uniform float energia : hint_range(0.0, 1.0) = 0.0;          // 1 nas fendas, olhos, boca e marca
uniform float intensidade : hint_range(0.0, 4.0) = 1.0;      // pulso da energia (curva do clipe)
uniform float rim : hint_range(0.0, 1.0) = 1.0;              // luz de borda (1 tom a mais na silhueta)
uniform float rim_limiar : hint_range(0.0, 1.0) = 0.62;

varying float v_det;

void fragment() {
	ALBEDO = vec3(1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	v_det = texture(detalhe, UV * escala_uv).r;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	int i = ndl < -0.3 ? 0 : (ndl < 0.1 ? 1 : (ndl < 0.5 ? 2 : (ndl < 0.85 ? 3 : 4)));
	if (ATTENUATION < 0.5) {
		i = min(i, 1);
	}
	if (energia > 0.5) {
		i = 1 + int(round(clamp(intensidade, 0.0, 3.0)));
	}
	i += int(round(v_det * 4.0 - 2.0) * usa_detalhe);
	float borda = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	if (rim > 0.5 && borda > rim_limiar && ndl > -0.2) {
		i += 1;
	}
	i = clamp(i, 0, 4);
	vec3 tons[5] = vec3[](tom_0.rgb, tom_1.rgb, tom_2.rgb, tom_3.rgb, tom_4.rgb);
	DIFFUSE_LIGHT = tons[i];
}
