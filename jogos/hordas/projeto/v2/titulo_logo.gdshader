shader_type canvas_item;
// Logo K.I.K.I.U da tela de título (v2/titulo_vivo.gd): ouro em degradê (claro em cima, âmbar embaixo) e um brilho que corre
// pelas letras de tempos em tempos. A cor da fonte é branca; o contorno preto continua preto (a conta multiplica a cor).
// `topo` e `altura` são a faixa das letras dentro do Label, em pixels locais.

uniform float topo = 14.0;
uniform float altura = 92.0;
uniform float periodo = 6.5;  // s entre duas passadas do brilho
uniform float largura_logo = 960.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float y = clamp((local.y - topo) / altura, 0.0, 1.0);
	y = floor(y * 8.0) / 8.0;  // degradê em faixas, como ouro de pixel art
	vec3 claro = vec3(1.0, 0.95, 0.7);
	vec3 meio = vec3(1.0, 0.76, 0.3);
	vec3 fundo = vec3(0.72, 0.38, 0.12);
	vec3 ouro = y < 0.5 ? mix(claro, meio, y * 2.0) : mix(meio, fundo, (y - 0.5) * 2.0);
	float fase = mod(TIME, periodo) / periodo;
	float x = local.x + local.y * 0.45;
	float faixa = 1.0 - smoothstep(0.0, 14.0, abs(x - mix(-200.0, largura_logo + 200.0, fase)));
	faixa = step(0.5, faixa);
	vec3 cor = ouro + vec3(1.0, 0.98, 0.9) * faixa * 0.7;
	COLOR.rgb *= cor;
}
