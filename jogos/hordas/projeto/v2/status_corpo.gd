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
	for (int k = 0; k < 9; k++) {
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
	if (est < 1.5) {  // fogo: o corpo arde em línguas que sobem; por fora, a chama sai do contorno
		float alto = 3.0 + 5.0 * h1;
		float d = corpo > 0.5 ? 0.0 : min(baixo, lado * 2.0);
		if (corpo > 0.5) {
			float k = h2 + (p.y / tam.y) * 0.3;
			if (lum < 0.1) { c.rgb = c.rgb * 0.6; }  // o contorno do bicho fica: ele continua legível dentro do fogo
			else if (k > 1.05) { c.rgb = vec3(1.9, 1.6, 0.8); }
			else if (k > 0.86) { c.rgb = vec3(1.9, 0.95, 0.22); }
			else if (k > 0.68) { c.rgb = vec3(1.5, 0.38, 0.08); }
			else { c.rgb = c.rgb * vec3(0.62, 0.4, 0.32); }
		} else if (d <= alto) {
			float k = d / alto;
			c = vec4(k < 0.35 ? vec3(1.9, 1.5, 0.7) : (k < 0.7 ? vec3(1.9, 0.85, 0.2) : vec3(1.4, 0.3, 0.07)), 1.0);
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
## Para Sprite2D de elite e chefe: `regiao` é o recorte do quadro no atlas, em px. Sem folga: esses sprites já têm margem na célula.
const SHADER_NO := (
	"""shader_type canvas_item;
uniform float estado = 0.0;
uniform float semente = 0.0;
uniform vec4 regiao = vec4(0.0, 0.0, 1.0, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (estado > 0.5) {
		vec2 base = regiao.xy;
		vec2 tam = regiao.zw;
		vec2 p = floor(UV * vec2(textureSize(TEXTURE, 0)) - base);
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
	return m
