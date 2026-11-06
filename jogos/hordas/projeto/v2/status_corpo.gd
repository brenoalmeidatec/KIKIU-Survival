extends RefCounted
## Status que tomam o corpo inteiro do monstro: fogo, gelo, veneno, choque e sangue são desenhados pelo próprio shader do sprite, lendo o alfa do
## quadro atual. Por isso seguem a silhueta em toda direção e em todo quadro, sem nó nem folha por monstro. A chama é DENTRO do monstro: o shader escurece
## o corpo e pinta, só nos pixels onde ele tem alfa 1, uma folha de chama (fonte_arte/chama/gerar_chama.py) ancorada na base da célula e com `altura` (~40%)
## dela, no máximo `sobra` px acima do contorno (0 = recorte puro); o contorno escuro do bicho fica por cima. O gelo recolore e solta pontas; o veneno
## borbulha; o choque estala; o sangue escorre. Tudo em pixel inteiro (a chama a 14 quadros por segundo, o resto a 12). Os números moram em
## dados/v2_pixelfx.json, status.fogo.corpo.
## O lote da horda recebe o estado no alfa da instância (v2/horda.gd). Elite e chefe usam `material_no`.
## Perfil Baixo: estado 0 (fica a tinta do monstro.gd). Guia: docs/visual_2_5d/estilo_pixelfx.md.

const NADA := 0
const FOGO := 1
const GELO := 2
const VENENO := 3
const CHOQUE := 4
const SANGUE := 5
const ESTADOS := {"veneno": VENENO, "choque": CHOQUE, "sangue": SANGUE}
const Piscadas := preload("res://v2/piscadas.gd")  # "Reduzir piscadas": a chama troca de quadro devagar e as brasas do corpo somem
const PASTA_CHAMA := "res://assets/v2/pixelfx/status/"
const TAMANHOS_CHAMA := ["p", "m", "g"]  # as três folhas: o shader escolhe pela altura da chama (`chama_corte`)

## Parte global do shader do corpo (o do lote e o de elite e chefe a põem antes de tudo, logo após `shader_type`): as três folhas da chama, os números
## vindos dos dados e a leitura de um pixel da chama. Cada folha tem 6 colunas x 2 linhas de quadros (12) e o quadro é um LADRILHO que emenda no eixo x: o
## monstro largo repete o ladrilho, cada repetição num quadro diferente. `texelFetch`: 1 texel da folha por pixel do monstro, sem filtro nem escala em x.
## O quadro cresce da base da célula (`tam.y - 1`) para cima; em y a folha é amostrada por vizinho mais próximo até a altura alvo `hf` (fração da célula).
const UNIFORMS := """
uniform sampler2D chama_p;
uniform sampler2D chama_m;
uniform sampler2D chama_g;
uniform float chama_alt = 0.4;
uniform float chama_sobra = 1.0;
uniform float chama_fps = 14.0;
uniform vec2 chama_corte = vec2(30.0, 56.0);
uniform float calmo = 0.0;
vec3 chama_texel(vec2 fs, vec2 p, vec2 tam, float sem, float hf, float tempo) {
	float d = tam.y - 1.0 - p.y;
	if (d < 0.0) { return vec3(0.0); }
	float sy = floor(d * fs.y / hf);
	if (sy >= fs.y) { return vec3(0.0); }
	float xx = p.x + floor(fract(sin(sem * 12.9898) * 43758.5453) * fs.x);
	float k = floor(xx / fs.x);
	float q = mod(floor(tempo * chama_fps) + floor(mod(sem * 5.0, 12.0)) + k * 5.0, 12.0);
	return vec3(vec2(mod(q, 6.0), floor(q / 6.0)) * fs + vec2(xx - k * fs.x, fs.y - 1.0 - sy), 1.0);
}
vec4 chama_cor(vec2 p, vec2 tam, float sem, float tempo) {
	float hf = max(floor(chama_alt * tam.y + 0.5), 1.0);
	if (hf <= chama_corte.x) {
		vec3 r = chama_texel(vec2(textureSize(chama_p, 0)) / vec2(6.0, 2.0), p, tam, sem, hf, tempo);
		return r.z > 0.5 ? texelFetch(chama_p, ivec2(r.xy), 0) : vec4(0.0);
	}
	if (hf <= chama_corte.y) {
		vec3 r = chama_texel(vec2(textureSize(chama_m, 0)) / vec2(6.0, 2.0), p, tam, sem, hf, tempo);
		return r.z > 0.5 ? texelFetch(chama_m, ivec2(r.xy), 0) : vec4(0.0);
	}
	vec3 r = chama_texel(vec2(textureSize(chama_g, 0)) / vec2(6.0, 2.0), p, tam, sem, hf, tempo);
	return r.z > 0.5 ? texelFetch(chama_g, ivec2(r.xy), 0) : vec4(0.0);
}
"""

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
	if (est < 1.5) {  // fogo: o corpo fica legível (escurecido e aquecido) e a chama é pintada só dentro dele (mais `chama_sobra` px acima do contorno)
		bool chama = false;
		if (corpo > 0.5) {
			if (lum < 0.1) { c.rgb = c.rgb * 0.6; }  // o contorno e os detalhes escuros do bicho ficam por cima da chama: ele continua legível dentro do fogo
			else {
				c.rgb = c.rgb * vec3(0.7, 0.42, 0.3);
				float a1 = p.y >= 1.0 ? texture(TEXTURE, (base + p - vec2(0.0, 1.0) + 0.5) / ta).a : 0.0;
				float a2 = p.y >= 2.0 ? texture(TEXTURE, (base + p - vec2(0.0, 2.0) + 0.5) / ta).a : 0.0;
				float hp = fract(sin(dot(p + vec2(sem, 3.0), vec2(91.7, 17.3))) * 43758.5453);
				float te = floor(TIME + hp);  // cada pixel sorteia a brasa no seu próprio compasso, 1 vez por segundo
				float hr = fract(sin(dot(p + vec2(sem, te), vec2(73.156, 52.235))) * 13758.5453);
				if (a1 < 0.5) { c.rgb = vec3(0.965, 0.659, 0.118); }  // a faixa logo abaixo da borda de cima brilha
				else if (a2 < 0.5) { c.rgb = vec3(0.878, 0.322, 0.102); }
				else if (calmo < 0.5 && hr > 0.96) { c.rgb = hr > 0.985 ? vec3(0.965, 0.659, 0.118) : vec3(0.878, 0.322, 0.102); }  // poucas brasas no corpo (com "Reduzir piscadas" não)
				chama = true;
			}
		} else if (baixo <= chama_sobra) {
			chama = true;  // a ponta da chama passa do contorno em até `chama_sobra` px (com 0 nunca entra aqui: `baixo` de um pixel vazio é 1 ou mais)
		}
		if (chama) {
			vec4 f = chama_cor(p, tam, sem, TIME);
			if (f.a > 0.5) { c = vec4(f.rgb, 1.0); }
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
## x nos dois lados, y em cima (a bolha do veneno sobe até 6 px) e embaixo (a gota do sangue cai até 8 px). A chama do fogo não usa a folga: fica no corpo
## (no máximo `chama_sobra` px acima dele). É a mesma folga do lote (v2/horda.gd).
const FOLGA_NO := Vector2(4.0, 9.0)

## Para Sprite2D de elite e chefe: `regiao` é o recorte do quadro no atlas, em px. Um Sprite2D com região só desenha o retângulo da região, e as folhas
## grandes (`_xN`) têm 0 px de margem nos lados: o shader de fragmento nunca roda fora dele e a chama saía cortada na borda da célula. Por isso o
## vertex() estica o quadrado em `folga` px para os quatro lados (a posição e o UV na mesma conta, pixel inteiro, o desenho do monstro não anda) e o
## fragment() zera o que cai fora da célula (o UV esticado lê as células vizinhas da folha). `centro` é o centro do quadrado no espaço do nó
## (`offset` + metade da região; o sprite não é centralizado). Quem sabe de que lado cada canto está é o sinal de VERTEX - centro; o espelho
## (flip_h) inverte o UV mas não a posição, então o sentido do UV vem de onde o canto leu a célula.
const SHADER_NO := (
	"""shader_type canvas_item;
"""
	+ UNIFORMS
	+ """uniform float estado = 0.0;
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
	preparar(m)
	return m


static var _chamas: Array = []


## Liga a um material do corpo (o do lote da horda ou o de elite e chefe) as folhas da chama e os números dos dados (status.fogo.corpo), e o ritmo atual.
static func preparar(m: ShaderMaterial) -> void:
	if _chamas.is_empty():
		for t in TAMANHOS_CHAMA:
			_chamas.append(load(PASTA_CHAMA + "chama_" + t + ".png"))
	for i in TAMANHOS_CHAMA.size():
		m.set_shader_parameter("chama_" + TAMANHOS_CHAMA[i], _chamas[i])
	var d: Dictionary = Dados.json("v2_pixelfx").get("status", {}).get("fogo", {}).get("corpo", {})
	m.set_shader_parameter("chama_alt", clampf(float(d.get("altura", 0.4)), 0.1, 0.9))
	m.set_shader_parameter("chama_sobra", clampf(float(d.get("sobra", 1.0)), 0.0, 4.0))
	var corte: Array = d.get("corte", [30, 56])
	m.set_shader_parameter("chama_corte", Vector2(float(corte[0]), float(corte[1])))
	ritmo(m)


## O ritmo da chama agora: 14 quadros por segundo; com "Reduzir piscadas", 1,5 (nenhum pixel troca mais de 2 vezes por segundo) e sem as brasas do corpo.
## Chame a cada quadro: a opção muda a qualquer hora.
static func ritmo(m: ShaderMaterial) -> void:
	var calmo := Piscadas.ligado()
	var d: Dictionary = Dados.json("v2_pixelfx").get("status", {}).get("fogo", {}).get("corpo", {})
	m.set_shader_parameter("calmo", 1.0 if calmo else 0.0)
	m.set_shader_parameter("chama_fps", float(d.get("quadros_calmo", 1.5)) if calmo else float(d.get("quadros_s", 14.0)))
