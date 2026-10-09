"""Ajustes por arquivo, aplicados DEPOIS da conversão automática (conversor.py).

Para o que não dá para traduzir por regra geral. Cada ajuste é (trecho_velho, trecho_novo) no texto já convertido; se
o trecho velho não aparecer (a main mudou), o conversor avisa no conversao.json em vez de falhar em silêncio.
Prefira isto a copiar o arquivo inteiro para jogo_vita_manual/: um ajuste pequeno sobrevive às mudanças da main.
"""

# ---------------------------------------------------------------- escuridao.gd: shader GLES2 sem ler a tela
# O original lê a tela (hint_screen_texture) e recebe as luzes num array de uniforms (uniform vec4 luzes[16]); o
# GLES2 do Godot 3 não tem array de uniforms. Aqui: overlay que MULTIPLICA a cena (blend_mul), 8 luzes em uniforms
# escalares, degraus de luz com pontilhado Bayer 4x4 por fórmula (sem array) e a névoa. Os olhos brilhando no escuro
# (que dependiam de ler a tela) ficam de fora no Vita.
SHADER_VITA = '''const SHADER = """
shader_type canvas_item;
render_mode blend_mul, unshaded;
uniform vec4 l0; uniform vec4 l1; uniform vec4 l2; uniform vec4 l3;
uniform vec4 l4; uniform vec4 l5; uniform vec4 l6; uniform vec4 l7;
uniform int n = 0;
uniform float forca = 0.9;
uniform vec3 tom = vec3(0.03, 0.025, 0.07);
uniform float nevoa = 0.5;
uniform float t = 0.0;
uniform int halo_n = 0;
uniform float aparece = 1.0;
uniform vec3 ambiente = vec3(1.0);
uniform vec2 tela = vec2(640.0, 360.0);

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float luz(vec2 p, vec4 L) {
	float d = distance(p, L.xy);
	float k = 1.0 - smoothstep(L.z * 0.2, L.z, d);
	return k * k * (3.0 - 2.0 * k) * L.w;
}
float b2(vec2 q) { return 2.0 * q.x + 3.0 * q.y - 4.0 * q.x * q.y; }

void fragment() {
	vec2 p = floor(UV * tela);
	float l = 0.0;
	if (n > 0) { l = max(l, luz(p, l0)); }
	if (n > 1) { l = max(l, luz(p, l1)); }
	if (n > 2) { l = max(l, luz(p, l2)); }
	if (n > 3) { l = max(l, luz(p, l3)); }
	if (n > 4) { l = max(l, luz(p, l4)); }
	if (n > 5) { l = max(l, luz(p, l5)); }
	if (n > 6) { l = max(l, luz(p, l6)); }
	if (n > 7) { l = max(l, luz(p, l7)); }
	float lq = clamp(l, 0.0, 1.0) * 6.0;
	float faixa = floor(lq);
	vec2 q1 = mod(p, 2.0);
	vec2 q2 = mod(floor(p / 2.0), 2.0);
	float bayer = 4.0 * b2(q1) + b2(q2);
	faixa += step((bayer + 0.5) / 16.0, lq - faixa);
	l = faixa / 6.0;
	float f = ruido(p / 70.0 + vec2(t * 0.06, t * 0.02)) * 0.6 + ruido(p / 26.0 - vec2(t * 0.04, 0.0)) * 0.4;
	vec3 escuro = vec3(1.0 - forca) + tom * 2.0 + vec3(0.09, 0.1, 0.13) * f * nevoa;
	vec3 claro = mix(vec3(1.0), vec3(1.1, 0.97, 0.82), l * 0.7);
	vec3 fator = mix(escuro, claro, l);
	COLOR = vec4(mix(vec3(1.0), fator, aparece), 1.0);
}
"""
'''


def escuridao(texto, avisos):
    ini = texto.find('const SHADER = """')
    fim = texto.find('"""', ini + len('const SHADER = """')) + 3 if ini >= 0 else -1
    if ini < 0 or fim < 3:
        avisos.append("ajuste escuridao: SHADER não encontrado")
    else:
        texto = texto[:ini] + SHADER_VITA.strip() + texto[fim:]
    trocas = [
        ('\t_mat.set_shader_param("luzes", _luzes)\n',
         '\tfor k in 8:\n\t\t_mat.set_shader_param("l%d" % k, _luzes[k] if k < n else Color(0, 0, 0, 0))\n'),
        ('\t_mat.set_shader_param("n", n)', '\t_mat.set_shader_param("n", min(n, 8))'),
        ("var max_l = min(MAX_LUZES, int(Config.q(\"escuro_luzes\")))", "var max_l = min(8, int(Config.q(\"escuro_luzes\")))"),
        ("return int(abs((cx * 73856093) ^ (cy * 19349663) ^ (sem * 83492791 + 12345))) & 0x7fffffff",
         "return int(abs((int(cx) * 73856093) ^ (int(cy) * 19349663) ^ (int(sem) * 83492791 + 12345))) & 0x7fffffff"),
    ]
    for velho, novo in trocas:
        if velho in texto:
            texto = texto.replace(velho, novo)
        else:
            avisos.append("ajuste escuridao: trecho não encontrado: " + velho.strip()[:70])
    return texto


import ajustes_inimigos  # noqa: E402

AJUSTES = {
    "scripts/hordas/escuridao.gd": escuridao,
    "scripts/hordas/inimigos.gd": ajustes_inimigos.inimigos,
}
