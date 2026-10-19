// Contorno por casco invertido: segunda passagem (next_pass) que empurra a malha para fora ao longo da normal,
// em pixels de tela (largura_px), e desenha só as faces de trás com a cor escura. Funciona com malha skinada,
// porque na Godot 4 o skinning já foi aplicado quando o vertex() roda.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 cor : source_color = vec4(0.102, 0.078, 0.063, 1.0); // #1a1410
uniform float largura_px : hint_range(0.0, 4.0) = 1.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 nv = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(nv, 0.0)).xy;
	float l = length(dir);
	dir = l > 1e-5 ? dir / l : vec2(0.0);
	clip.xy += dir * largura_px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = cor.rgb;
}
