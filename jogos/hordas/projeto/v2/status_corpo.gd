extends RefCounted
## Status que tomam o corpo inteiro do monstro: fogo, gelo, veneno, choque e sangue são desenhados pelo próprio shader do sprite, lendo o alfa do
## quadro atual. Por isso seguem a silhueta em toda direção e em todo quadro, sem nó nem folha por monstro. A chama sobe a partir do contorno
## e cobre o corpo; o gelo recolore e solta pontas; o veneno borbulha; o choque estala; o sangue escorre. Tudo em pixel inteiro, a 12 quadros por segundo.
## O lote da horda recebe o estado no alfa da instância (v2/horda.gd). Elite e chefe usam `material_no`.
## Perfil Baixo: estado 0 (fica a tinta do monstro.gd). Guia: docs/visual_2_5d/estilo_pixelfx.md.

const NADA := 0
const FOGO := 1
const GELO := 2
const VENENO := 3
const CHOQUE := 4
const SANGUE := 5
const ESTADOS := {"veneno": VENENO, "choque": CHOQUE, "sangue": SANGUE}

## Espera: `vec4 c` (a cor do sprite), `vec2 p` (pixel na célula, pode sair dela), `vec2 tam` (célula), `vec2 base` (canto da célula no atlas),
## `float est` (estado) e `float sem` (semente do monstro). TEXTURE é o atlas. Escreve em `c`.
const GLSL := """
	vec2 ta = vec2(textureSize(TEXTURE, 0));
	bool dentro = p.x >= 0.0 && p.y >= 0.0 && p.x < tam.x && p.y < tam.y;
	float corpo = dentro ? c.a : 0.0;
	float t = floor(TIME * 12.0);
	float baixo = 99.0;  // px até o corpo, olhando para baixo: a chama nasce do contorno
	float cima = 99.0;  // px até o corpo, olhando para cima: o que escorre
	for (int k = 0; k < 10; k++) {
		float f = float(k);
		vec2 q = p + vec2(0.0, f);
		if (baixo > 98.0 && q.x >= 0.0 && q.y >= 0.0 && q.x < tam.x && q.y < tam.y && texture(TEXTURE, (base + q + 0.5) / ta).a > 0.5) { baixo = f; }
		q = p - vec2(0.0, f);
		if (cima > 98.0 && q.x >= 0.0 && q.y >= 0.0 && q.x < tam.x && q.y < tam.y && texture(TEXTURE, (base + q + 0.5) / ta).a > 0.5) { cima = f; }
	}
	float lado = 99.0;
	for (int k = -2; k < 3; k++) {
		vec2 q = p + vec2(float(k), 0.0);
		if (k != 0 && q.x >= 0.0 && q.y >= 0.0 && q.x < tam.x && q.y < tam.y && texture(TEXTURE, (base + q + 0.5) / ta).a > 0.5) { lado = min(lado, abs(float(k))); }
	}
	float h1 = fract(sin(dot(vec2(floor(p.x / 2.0) + sem, t), vec2(12.9898, 78.233))) * 43758.5453);
	float h2 = fract(sin(dot(vec2(floor(p.x / 2.0) + sem, floor((p.y + t * 2.0) / 3.0)), vec2(39.346, 11.135))) * 24634.6345);
	float h3 = fract(sin(dot(p + vec2(sem, t), vec2(73.156, 52.235))) * 13758.5453);
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	if (est < 1.5) {  // fogo: o corpo fica legível (escurecido e aquecido, estável) e a chama sai do contorno em línguas que sobem
		if (corpo > 0.5) {
			if (lum < 0.1) { c.rgb = c.rgb * 0.6; }  // o contorno do bicho fica: ele continua legível dentro do fogo
			else {
				c.rgb = c.rgb * vec3(0.7, 0.42, 0.3);
				float a1 = p.y >= 1.0 ? texture(TEXTURE, (base + p - vec2(0.0, 1.0) + 0.5) / ta).a : 0.0;
				float a2 = p.y >= 2.0 ? texture(TEXTURE, (base + p - vec2(0.0, 2.0) + 0.5) / ta).a : 0.0;
				float hp = fract(sin(dot(p + vec2(sem, 3.0), vec2(91.7, 17.3))) * 43758.5453);
				float te = floor(TIME + hp);  // cada pixel sorteia a brasa no seu próprio compasso, 1 vez por segundo
				float hr = fract(sin(dot(p + vec2(sem, te), vec2(73.156, 52.235))) * 13758.5453);
				if (a1 < 0.5) { c.rgb = vec3(0.965, 0.659, 0.118); }  // a faixa logo abaixo da borda de cima brilha
				else if (a2 < 0.5) { c.rgb = vec3(0.878, 0.322, 0.102); }
				else if (hr > 0.96) { c.rgb = hr > 0.985 ? vec3(0.965, 0.659, 0.118) : vec3(0.878, 0.322, 0.102); }  // poucas brasas no corpo
			}
		} else {
			float col = floor(p.x / 2.0);
			float ca = fract(sin(dot(vec2(col, sem), vec2(12.9898, 78.233))) * 43758.5453);
			float cb = fract(sin(dot(vec2(col, sem), vec2(39.346, 11.135))) * 24634.6345);
			// Cada pixel de fora tem UMA fonte só (língua, brasa ou lado), para nunca somar trocas: a língua liga e desliga ao ser cruzada por uma onda lenta
			// (período de 1,6 a 3,5 s) e, de cor fixa pela distância, troca no máximo 2 vezes por segundo. Nas colunas de brasa a língua é baixa (até 5 px) e a
			// brasa sobe só acima disso (6 a 9 px), então as duas nunca disputam o mesmo pixel. t é inteiro e a derivada da onda não passa de 0,93: a altura muda
			// no máximo 1 px por quadro.
			bool com_brasa = ca > 0.55;
			float alto = com_brasa ? floor(3.6 + 1.5 * sin(t * (0.15 + 0.17 * cb) + ca * 6.2832 + col * 0.8)) : floor(5.5 + 2.9 * sin(t * (0.15 + 0.17 * cb) + ca * 6.2832 + col * 0.8));
			float lin = floor(p.y / 2.0);  // nos lados: a mesma ideia em 0, 1 ou 2 px, por faixa de 2 linhas
			float hl = fract(sin(dot(vec2(lin, sem), vec2(73.156, 52.235))) * 13758.5453);
			float alcance = floor(1.2 + 1.3 * sin(t * (0.15 + 0.15 * hl) + hl * 6.2832 + lin * 0.9));
			if (baixo < 98.0) {
				if (baixo <= alto) {  // a cor vem só da distância ao corpo: amarelo claro, laranja, vermelho e vermelho escuro na ponta alta
					c = vec4(baixo <= 1.0 ? vec3(1.0, 0.945, 0.659) : (baixo <= 3.0 ? vec3(0.965, 0.659, 0.118) : (baixo <= 6.0 ? vec3(0.878, 0.322, 0.102) : vec3(0.549, 0.11, 0.039))), 1.0);
				} else if (com_brasa && mod(p.x, 2.0) == floor(cb * 2.0)) {  // brasa solta que sobe acima da ponta, a cada ~2 s
					float ciclo = 20.0 + floor(ca * 12.0);
					float fase = mod(t + floor(cb * ciclo), ciclo);
					if (fase < 8.0 && baixo == 6.0 + floor(fase * 0.5)) { c = vec4(baixo < 8.0 ? vec3(1.0, 0.945, 0.659) : vec3(0.965, 0.659, 0.118), 1.0); }
				}
			} else if (lado <= alcance) {
				c = vec4(lado < 1.5 ? vec3(0.965, 0.659, 0.118) : vec3(0.878, 0.322, 0.102), 1.0);
			}
		}
	} else if (est < 2.5) {  // gelo: o corpo vira gelo em 3 tons, com a borda branca e pontas paradas para fora
		if (corpo > 0.5) {
			if (lum < 0.1) { c.rgb = vec3(0.08, 0.14, 0.3); }
			else { c.rgb = lum > 0.5 ? vec3(1.2, 1.5, 1.7) : (lum > 0.25 ? vec3(0.55, 1.0, 1.5) : vec3(0.22, 0.42, 0.95)); }
		} else {
			float ponta = fract(sin((floor(p.x / 3.0) + sem) * 12.9898) * 43758.5453);
			if (baixo <= 1.0 + ponta * 3.0 && ponta > 0.45) { c = vec4(0.7, 1.2, 1.6, 1.0); }
		}
	} else if (est < 3.5) {  // veneno: manchas que sobem pelo corpo e bolhas saindo
		if (corpo > 0.5) {
			if (lum >= 0.1) { c.rgb = h2 > 0.72 ? vec3(0.6, 1.5, 0.28) : c.rgb * vec3(0.6, 1.15, 0.5); }
		} else if (baixo <= 6.0 && h3 > 0.93) {
			c = vec4(0.7, 1.6, 0.35, 1.0);
		}
	} else if (est < 4.5) {  // choque: o corpo pisca e os arcos correm pelo contorno
		float pisca = mod(t, 2.0);
		if (corpo > 0.5) {
			if (h2 > 0.8 && lum >= 0.1) { c.rgb = vec3(1.5, 1.7, 2.1); }
			else if (pisca > 0.5) { c.rgb = c.rgb * vec3(0.8, 1.1, 1.8); }
		} else if ((baixo <= 2.0 || lado <= 1.0) && h1 > 0.6) {
			c = vec4(1.1, 1.4, 2.1, 1.0);
		}
	} else {  // sangue: manchas no corpo e gotas que caem pela gravidade
		if (corpo > 0.5) {
			if (h2 > 0.74 && lum >= 0.1) { c.rgb = vec3(1.1, 0.1, 0.12); }
		} else {
			float gota = fract(sin((floor(p.x / 2.0) + sem) * 78.233) * 43758.5453);
			float y = mod(t * 1.5 + gota * 9.0, 9.0);
			if (cima <= 8.0 && gota > 0.6 && abs(cima - y) < 1.0) { c = vec4(1.1, 0.08, 0.1, 1.0); }
		}
	}
"""
## Folga (px) que o quadrado do sprite de elite e chefe ganha com status, para a chama, o arco, a bolha e a gota passarem do contorno da célula:
## x nos dois lados, y em cima (a chama sobe até 8 px) e embaixo (a gota do sangue cai até 8 px). É a mesma folga do lote (v2/horda.gd).
const FOLGA_NO := Vector2(4.0, 9.0)

## Para Sprite2D de elite e chefe: `regiao` é o recorte do quadro no atlas, em px. Um Sprite2D com região só desenha o retângulo da região, e as folhas
## grandes (`_xN`) têm 0 px de margem nos lados: o shader de fragmento nunca roda fora dele e a chama saía cortada na borda da célula. Por isso o
## vertex() estica o quadrado em `folga` px para os quatro lados (a posição e o UV na mesma conta, pixel inteiro, o desenho do monstro não anda) e o
## fragment() zera o que cai fora da célula (o UV esticado lê as células vizinhas da folha). `centro` é o centro do quadrado no espaço do nó
## (`offset` + metade da região; o sprite não é centralizado). Quem sabe de que lado cada canto está é o sinal de VERTEX - centro; o espelho
## (flip_h) inverte o UV mas não a posição, então o sentido do UV vem de onde o canto leu a célula.
const SHADER_NO := (
	"""shader_type canvas_item;
uniform float estado = 0.0;
uniform float semente = 0.0;
uniform vec4 regiao = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 centro = vec2(0.0);
uniform vec2 folga = vec2(4.0, 9.0);
void vertex() {
	if (estado > 0.5) {
		vec2 ts = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 p = UV * ts - regiao.xy;
		vec2 lado = vec2(VERTEX.x < centro.x ? -1.0 : 1.0, VERTEX.y < centro.y ? -1.0 : 1.0);
		vec2 sentido = vec2((p.x > regiao.z * 0.5) == (lado.x > 0.0) ? 1.0 : -1.0, (p.y > regiao.w * 0.5) == (lado.y > 0.0) ? 1.0 : -1.0);
		VERTEX += lado * folga;
		UV = (regiao.xy + p + lado * sentido * folga) / ts;
	}
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (estado > 0.5) {
		vec2 base = regiao.xy;
		vec2 tam = regiao.zw;
		vec2 p = floor(UV * vec2(textureSize(TEXTURE, 0)) - base);
		if (p.x < 0.0 || p.y < 0.0 || p.x >= tam.x || p.y >= tam.y) { c = vec4(0.0); }
		float est = estado;
		float sem = semente;
"""
	+ GLSL
	+ """	}
	COLOR = c;
}
"""
)

static var _shader_no: Shader


## O material do sprite de uma elite ou chefe (um por monstro: a região muda a cada quadro).
static func material_no(semente: float) -> ShaderMaterial:
	if _shader_no == null:
		_shader_no = Shader.new()
		_shader_no.code = SHADER_NO
	var m := ShaderMaterial.new()
	m.shader = _shader_no
	m.set_shader_parameter("semente", semente)
	m.set_shader_parameter("folga", FOLGA_NO)
	return m
