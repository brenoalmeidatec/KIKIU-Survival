shader_type canvas_item;
render_mode unshaded;

// Véu do Códice. A coluna segue o bloco de 960 px, mesmo em telas largas.
uniform float canvas_largura = 960.0;
uniform float margem_esquerda = 0.0;
uniform vec4 verde : source_color = vec4(0.067, 0.090, 0.075, 1.0);

void fragment() {
	float x = UV.x * canvas_largura - margem_esquerda;
	float coluna = 1.0 - smoothstep(272.0, 676.0, x);
	float rodape = smoothstep(0.85, 1.0, UV.y) * 0.72;
	float opacidade = 1.0 - (1.0 - coluna) * (1.0 - rodape) * 0.94;
	COLOR = vec4(mix(verde.rgb, verde.rgb * 0.54, rodape), opacidade);
}
