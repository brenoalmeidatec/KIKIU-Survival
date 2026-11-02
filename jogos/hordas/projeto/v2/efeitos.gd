extends RefCounted
## Efeitos de impacto da v2 (golpe, acerto, morte, dano). TUDO em pool: vetores de tamanho fixo e nós criados uma vez só; um acerto não cria
## nó nenhum. Fica na camada "glow" (acima do escurecimento do cenário, então o brilho não é apagado pela escuridão da floresta):
##  - cortes: o rastro da katana, um Sprite2D com shader (crescente que varre, ou estocada em linha) em mistura aditiva;
##  - luzes: PointLight2D rápidas que acendem o chão ao redor do golpe;
##  - flashes: silhueta branca (ou colorida) por cima do monstro que apanhou, que some em ~0,09 s; também o fantasma da morte e o rastro da esquiva;
##  - partículas (faíscas, estouro da morte, almas subindo) e ondas de choque, desenhadas numa só chamada aditiva por quadro;
##  - números de dano: texto com contorno que sobe e some, desenhado numa só chamada (fonte pixel do jogo, tamanhos 8 e 16).
## Posições são arredondadas para pixel inteiro ao desenhar (o pixel art não treme).

const MAX_PART := 360
const MAX_FRAGMENTOS := 24
const MAX_NUM := 64
const MAX_CORTES := 4
const MAX_FLASH := 24
const MAX_LUZES := 3
const MAX_ONDAS := 6
const MAX_FOLHAS := 14  # efeitos de folha (Blender): 0..5 cristal, anel e espiral; 6..13 a centelha de acerto
const PRIM_CENTELHA := 6
const MAX_MARCAS := 2  # marcas sustentadas ao mesmo tempo
# nome -> [folha, quadros]; feitas no Blender em fonte_arte/blender_efeitos, mesmo formato do corte (RGB = calor, A = intensidade)
const FOLHAS := {
	"cristal": [preload("res://assets/v2/efeitos/efeito_cristal_folha.png"), 14.0],
	"estrela": [preload("res://assets/v2/efeitos/efeito_estrela_folha.png"), 9.0],
	"anel": [preload("res://assets/v2/efeitos/efeito_anel_folha.png"), 18.0],
	"espiral": [preload("res://assets/v2/efeitos/efeito_espiral_folha.png"), 12.0],
}
const FOLHA_CORTE := preload("res://assets/v2/efeitos/corte_hazaki.png")  # 16 quadros 128x128, feita no Blender (fonte_arte/blender_corte)
const FOLHA_CORTE_CIANO := preload("res://assets/v2/efeitos/corte_hazaki_ciano.png")  # variante: so a energia ciano, 12 quadros
const Piscadas := preload("res://v2/piscadas.gd")  # "Reduzir piscadas": sem clarão de tela, flash de acerto em tinta fixa
const Anim := preload("res://v2/anim_golpes.gd")  # só a chave Anim.suave (golpes suaves ligados pela opção de partículas)
const CORTE_CRESCE := 0.3  # fração do corte em que o rastro abre de 88% a 100% do tamanho (ease-out; nunca passa do alcance)

const SHADER_CORTE := """
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform float prog = 0.0;
uniform float arco = 2.2;
uniform float lado = 1.0;
uniform float modo = 0.0;
uniform vec4 cor : source_color = vec4(1.0);
uniform float quadros = 16.0;
uniform float fixo = 0.0;  // 1 = rampa ciano fixa (variante ciano) em vez da cor do golpe
uniform float suave = 1.0;  // 1 = funde o quadro com o próximo (o meio-quadro que a folha não tem; Anim.suave)
uniform sampler2D folha : filter_nearest;  // corte feito no Blender (fonte_arte/blender_corte): 16 quadros em linha, RGB = calor, A = intensidade
float pos(float x) { return floor(x * 8.0 + 0.5) / 8.0; }
void fragment() {
	if (modo > 1.5) {
		float fq = prog * quadros;
		float q = min(floor(fq), quadros - 1.0);
		float vy = lado > 0.0 ? UV.y : 1.0 - UV.y;
		vec4 t = texture(folha, vec2((UV.x + q) / quadros, vy));
		if (suave > 0.5 && q < quadros - 1.0) {
			t = mix(t, texture(folha, vec2((UV.x + q + 1.0) / quadros, vy)), fract(fq));
		}
		vec3 c = mix(cor.rgb, vec3(1.0), t.r * 0.85);
		if (fixo > 0.5) {
			float h = clamp(t.r, 0.0, 1.0) * 3.0;
			c = h < 1.0 ? mix(vec3(0.04, 0.55, 0.62), vec3(0.10, 0.80, 0.85), h) : (h < 2.0 ? mix(vec3(0.10, 0.80, 0.85), vec3(0.40, 0.95, 1.0), h - 1.0) : mix(vec3(0.40, 0.95, 1.0), vec3(0.92, 1.0, 1.0), h - 2.0));
		}
		COLOR = vec4(c * (fixo > 0.5 ? 1.8 : 3.0), t.a);
	} else {
	vec2 p = (UV - 0.5) * 2.0;
	p.y *= lado;
	float r = length(p);
	float a = atan(p.y, p.x);
	float k = 0.0;
	float quente = 0.0;
	if (modo < 0.5) {
		float meio = arco * 0.5;
		float cabeca = mix(-meio * 1.15, meio * 1.05, clamp(prog * 1.3, 0.0, 1.0));
		float d = cabeca - a;
		float cauda = arco * 0.8;
		float rastro = d >= 0.0 ? smoothstep(cauda, 0.0, d) : 0.0;
		float t = clamp(1.0 - pow(abs(a) / meio, 2.0), 0.0, 1.0);
		float r_ext = 0.97;
		float r_int = r_ext - 0.56 * pow(t, 0.55);
		float dentro = smoothstep(r_int - 0.025, r_int + 0.025, r) * (1.0 - smoothstep(r_ext - 0.03, r_ext, r));
		dentro *= step(abs(a), meio);
		float fora = clamp((r - r_int) / max(r_ext - r_int, 0.01), 0.0, 1.0);
		k = dentro * rastro * (0.45 + 0.55 * fora);
		quente = dentro * pow(rastro, 5.0) * fora;
	} else {
		float cab = mix(0.05, 1.05, 1.0 - pow(1.0 - clamp(prog * 1.5, 0.0, 1.0), 2.0));
		float w = 0.17 * (1.0 - 0.5 * clamp(p.x, 0.0, 1.0)) + 0.02;
		float fio = exp(-pow(p.y / w, 2.0));
		float tras = clamp((cab - p.x) / 0.8, 0.0, 1.0);
		float na = step(0.02, p.x) * step(p.x, cab);
		k = fio * na * (1.0 - tras);
		float ponta = exp(-pow((p.x - cab) / 0.07, 2.0)) * exp(-pow(p.y / 0.16, 2.0));
		k = max(k, ponta);
		quente = max(fio * na * pow(1.0 - tras, 4.0), ponta);
	}
	float sai = 1.0 - smoothstep(0.55, 1.0, prog);
	k = pos(k * sai);
	vec3 c = mix(cor.rgb, vec3(1.0), clamp(quente, 0.0, 1.0) * 0.55);
	COLOR = vec4(c * k * 2.4, k);
	}
}
"""

## A explosão grande dos golpes de impacto (referência: docs/visual_2_5d/referencia_kikiu, magia M2 e cristal M6): núcleo branco que
## estoura, dois anéis de energia em arcos que giram em sentidos opostos e abrem com ease-out, a "bolha" que fica dentro e some, e espinhos
## radiais no começo. Tudo num quad só (aditivo), com a grade de pixel do jogo (`px` = pixels de tela na largura) e a intensidade em degraus.
const SHADER_EXPLOSAO := """
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform float prog = 0.0;
uniform vec4 cor : source_color = vec4(1.0);
uniform float px = 128.0;
uniform float semente = 0.0;
uniform float espinhos = 1.0;
uniform float calmo = 0.0;  // 1 = "Reduzir piscadas": os anéis não giram (g1, g2 e a bolha cintilavam a 1,4 a 2,5 Hz por pixel)
float h(float x) { return fract(sin(x * 127.1 + semente * 31.7) * 43758.5453); }
void fragment() {
	vec2 uv = (floor(UV * px) + 0.5) / px;
	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = prog;
	float core = (1.0 - smoothstep(0.0, 0.22, t)) * exp(-r * r / (0.02 + 0.3 * t));
	float e1 = 1.0 - pow(1.0 - clamp(t / 0.4, 0.0, 1.0), 3.0);
	float r1 = 0.12 + 0.72 * e1;
	float w1 = 0.035 + 0.05 * (1.0 - e1);
	float g1 = smoothstep(0.2, 0.85, 0.5 + 0.5 * sin(a * 3.0 + t * 16.0 * (1.0 - calmo) + semente * 6.0));
	float anel1 = exp(-pow((r - r1) / w1, 2.0)) * (0.45 + 0.55 * g1);
	float e2 = 1.0 - pow(1.0 - clamp((t - 0.05) / 0.5, 0.0, 1.0), 3.0);
	float r2 = 0.08 + 0.88 * e2;
	float g2 = smoothstep(0.35, 0.95, 0.5 + 0.5 * sin(-a * 2.0 + t * 11.0 * (1.0 - calmo) + semente * 3.0));
	float anel2 = exp(-pow((r - r2) / 0.03, 2.0)) * g2 * step(0.05, t);
	float bolha = (1.0 - smoothstep(r1 - 0.3, r1, r)) * 0.16 * e1 * (0.7 + 0.3 * sin(a * 5.0 - t * 9.0 * (1.0 - calmo)));
	float setor = floor((a + 3.14159) / 6.28318 * 14.0);
	float meio = (setor + 0.5) / 14.0 * 6.28318 - 3.14159;
	float da = abs(mod(a - meio + 3.14159, 6.28318) - 3.14159);
	float st = 1.0 - pow(1.0 - clamp(t / 0.2, 0.0, 1.0), 2.0);
	float lp = (0.45 + 0.55 * h(setor)) * (0.25 + 0.95 * st);
	float larg = 0.13 * clamp(1.0 - r / max(lp, 0.01), 0.0, 1.0);
	float espinho = step(r, lp) * (1.0 - smoothstep(larg * 0.4, larg, da)) * (1.0 - smoothstep(0.12, 0.35, t)) * espinhos;
	float some = 1.0 - smoothstep(0.5, 1.0, t);
	float k = core * 1.6 + (anel1 + anel2 + bolha) * some + espinho;
	k = floor(clamp(k, 0.0, 1.6) * 6.0 + 0.5) / 6.0;
	vec3 c = mix(cor.rgb, vec3(1.0), clamp(core * 1.3 + anel1 * 0.3 + espinho * 0.5, 0.0, 1.0));
	COLOR = vec4(c * k * 1.7, min(k, 1.0));
}
"""
const MAX_EXPLOSOES := 6  # explosões grandes ao mesmo tempo (a mais velha é reaproveitada)
const EXPLOSAO_DUR := 0.75
const MAX_ECOS := 4
const MAX_MARCAS_CHAO := 10  # marcas de dano no chão (cratera, rachaduras) ao mesmo tempo; a mais velha é reaproveitada
const RACHAS := 7  # rachaduras por marca
const RACHA_PTS := 4  # pontos de cada rachadura (polilinha: sem triangular nada)
const MARCA_DUR := 3.5
const MARCA_BRASA := 1.2  # quanto tempo as rachaduras ficam acesas na cor do golpe (camada aditiva)
const ECO_ESCALA := 1.18  # o eco do corte é 18% maior que o rastro (só o desenho; o alcance do golpe é o mesmo)

const SHADER_FLASH := """
shader_type canvas_item;
render_mode unshaded;
uniform vec4 cor : source_color = vec4(1.0);
uniform float k = 1.0;
uniform float dissolver : hint_range(0.0, 1.0) = 0.0;
// Coordenadas da textura: a mascara nao muda com o tempo nem com o movimento do sprite.
float ruido_pixel(vec2 pixel) {
	return fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec3 tinta = cor.rgb;
	if (dissolver > 0.0) {
		float ruido = ruido_pixel(floor(UV / TEXTURE_PIXEL_SIZE));
		float resta = step(dissolver, ruido);
		float borda = (1.0 - smoothstep(0.0, 0.08, ruido - dissolver)) * resta;
		tinta = mix(tinta, vec3(1.0), borda * 0.25);
		a *= resta;
	}
	COLOR = vec4(tinta, a * k);
}
"""

var mundo
var _fragmentos: Array[Sprite2D] = []
var _frag_t := PackedFloat32Array()
var _frag_v := PackedVector2Array()
var _frag_i := 0
var raiz: Node  # a camada glow
var add: Node2D  # desenho aditivo (partículas, ondas)
var txt: Node2D  # desenho normal (números)
var fonte: Font
var tex_brilho: Texture2D
var fator_part := 1.0  # opção "partículas" da aba Gráficos (0 a 1)

# partículas
var p_pos := PackedVector2Array()
var p_vel := PackedVector2Array()
var p_vida := PackedFloat32Array()
var p_max := PackedFloat32Array()
var p_tam := PackedFloat32Array()
var p_sobe := PackedFloat32Array()  # aceleração vertical (px/s2): faíscas caem, almas sobem
var p_glow := PackedByteArray()  # 1 = brilho redondo, 0 = quadradinho
var p_cor := PackedColorArray()
var p_ativas := 0
var _pi := 0

# números de dano
var n_pos := PackedVector2Array()
var n_t := PackedFloat32Array()
var n_dur := PackedFloat32Array()
var n_txt := PackedStringArray()
var n_tam := PackedInt32Array()
var n_cor := PackedColorArray()
var n_ativos := 0
var _ni := 0

# ondas de choque
var o_pos := PackedVector2Array()
var o_t := PackedFloat32Array()
var o_dur := PackedFloat32Array()
var o_raio := PackedFloat32Array()
var o_cor := PackedColorArray()
var _oi := 0

# cortes
var _cortes: Array[Sprite2D] = []
var _cortes_t := PackedFloat32Array()
var _cortes_dur := PackedFloat32Array()
var _cortes_esc := PackedFloat32Array()  # a escala final de cada corte (o rastro cresce até ela)
var _ci := 0
var variante := "katana"  # qual folha o corte usa: "katana" (katana + linha de anime) ou "ciano" (so a energia ciano)

# luzes rápidas
var _luzes: Array[PointLight2D] = []
var _luzes_t := PackedFloat32Array()
var _luzes_dur := PackedFloat32Array()
var _luzes_e := PackedFloat32Array()
var _li := 0

# flashes
var _fl: Array[Sprite2D] = []
var _fl_alvo: Array = []  # Ator que o flash segue (ou null: parado onde nasceu)
var _fl_t := PackedFloat32Array()
var _fl_dur := PackedFloat32Array()
var _pisca_rel := 0.0  # relógio dos flashes de acerto (s de simulação): só serve ao intervalo mínimo da opção "Reduzir piscadas"
# Os últimos alvos de flash de acerto (anel de 4 x MAX_FLASH = 96, tamanho fixo) e quando cada um levou. Limite aceito: mais de 96 flashes de
# acerto em 0,7 s sobrescrevem o mais velho, e esse monstro pode levar flash de novo.
var _pisca_alvo: Array = []
var _pisca_quando := PackedFloat32Array()
var _pisca_i := 0
var _fl_esc := PackedFloat32Array()  # tamanho do ator (elite e chefe são maiores)
var _fl_modo := PackedByteArray()  # 0 = piscada de dano, 1 = morte (encolhe e some), 2 = rastro da esquiva
var _fi := 0

# efeitos de folha (cristal, estrela, anel, espiral): mesmo shader do corte, em modo folha
var _fo: Array[Sprite2D] = []
var _fo_t := PackedFloat32Array()
var _fo_dur := PackedFloat32Array()
var _fo_cristal := PackedByteArray()  # 1 = o slot mostra um cristal (para ignorar explosões coladas)
var _fo_i := 0
var _ce_i := PRIM_CENTELHA

# explosões grandes (SHADER_EXPLOSAO)
var _ex: Array[Sprite2D] = []
var _ex_t := PackedFloat32Array()
var _ex_dur := PackedFloat32Array()
# eco do corte: um crescente branco maior por trás da folha do Blender (pool próprio: não mexe em _ci, que o v2_ruptura lê)
var _eco: Array[Sprite2D] = []
var _eco_t := PackedFloat32Array()
var _eco_dur := PackedFloat32Array()
var _eco_i := 0
# marcas de dano no chão: um nó no mundo (z -60: acima do piso e dos decalques, abaixo das sombras e dos atores), recebe a luz da cena
var chao: Node2D
var _mc_pos := PackedVector2Array()
var _mc_raio := PackedFloat32Array()
var _mc_t := PackedFloat32Array()
var _mc_cor := PackedColorArray()
var _mc_pts := PackedVector2Array()  # MAX_MARCAS_CHAO * RACHAS * RACHA_PTS, relativos ao centro
var _mc_i := 0
var _mc_ativas := false
# clarão de tela (impacto grande): um retângulo aditivo do tamanho da câmera que some rápido
var _cl_t := 9.0
var _cl_dur := 0.15
var _cl_cor := Color.WHITE
var _ex_i := 0
var _rng := RandomNumberGenerator.new()  # sorteio dos enfeites novos: fora do randf() global, de que o jogo e os testes dependem

var usados := {"cortes": 0, "flashes": 0, "particulas": 0, "numeros": 0, "folhas": 0, "marcas": 0, "explosoes": 0, "chao": 0}  # contadores para os testes


func montar(m, camada: Node, sv: Node, tex_glow: Texture2D) -> void:
	mundo = m
	raiz = camada
	tex_brilho = tex_glow
	fonte = Dados.fonte
	var mat_add := CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add = Node2D.new()
	add.material = mat_add
	add.draw.connect(_desenhar_add)
	camada.add_child(add)
	txt = Node2D.new()
	txt.draw.connect(_desenhar_numeros)
	camada.add_child(txt)
	p_pos.resize(MAX_PART)
	p_vel.resize(MAX_PART)
	p_vida.resize(MAX_PART)
	p_max.resize(MAX_PART)
	p_tam.resize(MAX_PART)
	p_sobe.resize(MAX_PART)
	p_glow.resize(MAX_PART)
	p_cor.resize(MAX_PART)
	n_pos.resize(MAX_NUM)
	n_t.resize(MAX_NUM)
	n_dur.resize(MAX_NUM)
	n_txt.resize(MAX_NUM)
	n_tam.resize(MAX_NUM)
	n_cor.resize(MAX_NUM)
	o_pos.resize(MAX_ONDAS)
	o_t.resize(MAX_ONDAS)
	o_dur.resize(MAX_ONDAS)
	o_raio.resize(MAX_ONDAS)
	o_cor.resize(MAX_ONDAS)
	o_dur.fill(1.0)
	o_t.fill(9.0)
	n_t.fill(9.0)
	n_dur.fill(1.0)
	_montar_cortes()
	_montar_luzes(sv)
	_montar_flashes()
	_montar_fragmentos()
	_montar_folhas()
	_montar_explosoes()
	_montar_chao(m)


func _montar_fragmentos() -> void:
	_frag_t.resize(MAX_FRAGMENTOS)
	_frag_v.resize(MAX_FRAGMENTOS)
	for i in MAX_FRAGMENTOS:
		var s := Sprite2D.new()
		s.region_enabled = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.visible = false
		raiz.add_child(s)
		_fragmentos.append(s)


## Recortes do quadro atual, antes de devolver o inimigo ao pool. Só visuais, sem física ou dano.
func fragmentar(m, fora: Vector2) -> void:
	if float(mundo._nivel_particulas().get("efe_particulas", 1.0)) <= 0.0 or m.tipo.is_empty() or m.chefe:
		return
	var reg: Rect2 = m.regiao
	for parte in 2:
		var i := _frag_i
		_frag_i = (_frag_i + 1) % MAX_FRAGMENTOS
		var s := _fragmentos[i]
		s.texture = m.tipo.alb
		s.region_rect = Rect2(reg.position + Vector2(reg.size.x * 0.25 * parte, reg.size.y * 0.2), reg.size * Vector2(0.5, 0.6))
		s.flip_h = m.espelha
		s.scale = Vector2.ONE * m.escala
		s.modulate = m.tinta
		s.position = m.raiz.position + m.offset * m.escala
		s.rotation = 0.0
		s.visible = true
		_frag_t[i] = 0.6
		var lado := -1.0 if parte == 0 else 1.0
		_frag_v[i] = fora * 125.0 + Vector2(lado * 40.0, -70.0)


func _montar_cortes() -> void:
	var im := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(im)
	var sh := Shader.new()
	sh.code = SHADER_CORTE
	for i in MAX_CORTES:
		var s := Sprite2D.new()
		s.texture = tex
		var mat := ShaderMaterial.new()
		mat.shader = sh
		s.material = mat
		s.visible = false
		raiz.add_child(s)
		_cortes.append(s)
	_cortes_t.resize(MAX_CORTES)
	_cortes_dur.resize(MAX_CORTES)
	_cortes_esc.resize(MAX_CORTES)
	_cortes_t.fill(9.0)
	_cortes_dur.fill(1.0)


func _montar_folhas() -> void:
	var sh := Shader.new()
	sh.code = SHADER_CORTE
	var tex: Texture2D = _cortes[0].texture
	for i in MAX_FOLHAS:
		var s := Sprite2D.new()
		s.texture = tex
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("modo", 2.0)
		mat.set_shader_parameter("lado", 1.0)
		s.material = mat
		s.visible = false
		raiz.add_child(s)
		_fo.append(s)
	_fo_t.resize(MAX_FOLHAS)
	_fo_dur.resize(MAX_FOLHAS)
	_fo_cristal.resize(MAX_FOLHAS)
	_fo_t.fill(9.0)
	_fo_dur.fill(1.0)


func _montar_chao(m) -> void:
	_mc_pos.resize(MAX_MARCAS_CHAO)
	_mc_raio.resize(MAX_MARCAS_CHAO)
	_mc_t.resize(MAX_MARCAS_CHAO)
	_mc_t.fill(99.0)
	_mc_cor.resize(MAX_MARCAS_CHAO)
	_mc_pts.resize(MAX_MARCAS_CHAO * RACHAS * RACHA_PTS)
	var no = m.get("no_mundo") if m != null else null
	if not (no is Node):
		return
	chao = Node2D.new()
	chao.z_index = -60
	chao.draw.connect(_desenhar_chao)
	no.add_child(chao)


func _montar_explosoes() -> void:
	var sh := Shader.new()
	sh.code = SHADER_EXPLOSAO
	var tex: Texture2D = _cortes[0].texture
	for i in MAX_EXPLOSOES:
		var s := Sprite2D.new()
		s.texture = tex
		var mat := ShaderMaterial.new()
		mat.shader = sh
		s.material = mat
		s.visible = false
		raiz.add_child(s)
		_ex.append(s)
	_ex_t.resize(MAX_EXPLOSOES)
	_ex_dur.resize(MAX_EXPLOSOES)
	_ex_t.fill(9.0)
	_ex_dur.fill(1.0)
	var sh_c := Shader.new()
	sh_c.code = SHADER_CORTE
	for i in MAX_ECOS:
		var s := Sprite2D.new()
		s.texture = tex
		var mat := ShaderMaterial.new()
		mat.shader = sh_c
		mat.set_shader_parameter("modo", 0.0)
		s.material = mat
		s.visible = false
		raiz.add_child(s)
		_eco.append(s)
	_eco_t.resize(MAX_ECOS)
	_eco_dur.resize(MAX_ECOS)
	_eco_t.fill(9.0)
	_eco_dur.fill(1.0)


func _montar_luzes(sv: Node) -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.45, 0.45, 0.45, 1), Color(0, 0, 0, 1)])
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	tx.width = 128
	tx.height = 128
	for i in MAX_LUZES:
		var l := PointLight2D.new()
		l.texture = tx
		l.enabled = false
		l.shadow_enabled = false
		l.height = 26.0
		sv.add_child(l)
		_luzes.append(l)
	_luzes_t.resize(MAX_LUZES)
	_luzes_dur.resize(MAX_LUZES)
	_luzes_e.resize(MAX_LUZES)
	_luzes_t.fill(9.0)
	_luzes_dur.fill(1.0)


func _montar_flashes() -> void:
	var sh := Shader.new()
	sh.code = SHADER_FLASH
	for i in MAX_FLASH:
		var s := Sprite2D.new()
		s.centered = false
		s.region_enabled = true
		var mat := ShaderMaterial.new()
		mat.shader = sh
		s.material = mat
		s.visible = false
		raiz.add_child(s)
		_fl.append(s)
		_fl_alvo.append(null)
	_fl_t.resize(MAX_FLASH)
	_fl_esc.resize(MAX_FLASH)
	_fl_dur.resize(MAX_FLASH)
	_pisca_alvo.resize(MAX_FLASH * 4)
	_pisca_quando.resize(MAX_FLASH * 4)
	_pisca_quando.fill(-9.0)
	_fl_modo.resize(MAX_FLASH)
	_fl_t.fill(9.0)
	_fl_dur.fill(1.0)


# ------------------------------------------------------------------ pedidos


## O rastro da katana. `ang` = direção do golpe (rad), `lado` = sentido do corte (1 ou -1), `tipo` = "corte" ou "estocada".
func corte(origem: Vector2, ang: float, alcance: float, arco_graus: float, lado: float, tipo: String, cor: Color, dur: float) -> void:
	var i := _ci
	_ci = (_ci + 1) % MAX_CORTES
	var s := _cortes[i]
	var folha := tipo == "corte"  # o corte usa a folha do Blender; a estocada continua no shader
	var r := alcance * (1.45 if folha else 1.25)  # na folha o arco ocupa 0,8 da meia-largura
	s.position = origem.round()
	s.rotation = ang
	_cortes_esc[i] = r / 32.0
	s.scale = Vector2.ONE * (r / 32.0) * (0.88 if Anim.suave else 1.0)
	s.visible = true
	var mat := s.material as ShaderMaterial
	mat.set_shader_parameter("suave", 1.0 if Anim.suave else 0.0)
	mat.set_shader_parameter("prog", 0.0)
	mat.set_shader_parameter("arco", deg_to_rad(arco_graus))
	mat.set_shader_parameter("lado", lado)
	mat.set_shader_parameter("modo", 2.0 if folha else (1.0 if tipo == "estocada" else 0.0))
	var ciano := variante == "ciano"
	mat.set_shader_parameter("folha", FOLHA_CORTE_CIANO if ciano else FOLHA_CORTE)
	mat.set_shader_parameter("quadros", 12.0 if ciano else 16.0)
	mat.set_shader_parameter("fixo", 1.0 if ciano else 0.0)
	mat.set_shader_parameter("cor", cor)
	_cortes_t[i] = 0.0
	_cortes_dur[i] = dur
	usados.cortes += 1
	if Anim.suave and tipo == "corte":  # brilhos ao longo do arco que ficam um instante no ar e escorregam na direção do corte
		var meio := deg_to_rad(arco_graus) * 0.5
		var claro := cor.lerp(Color.WHITE, 0.5)
		var n := roundi(10 * fator_part)
		for k in n:
			var aa := ang + lerpf(-meio, meio, (float(k) + _rng.randf()) / float(n))
			var pt := origem + Vector2.from_angle(aa) * alcance * _rng.randf_range(0.8, 1.15)
			var tang := Vector2.from_angle(aa + PI * 0.5 * lado) * _rng.randf_range(40.0, 110.0)
			particula(pt, tang, _rng.randf_range(0.3, 0.55), _rng.randf_range(10.0, 16.0), Color(claro.r, claro.g, claro.b, 0.95), -24.0, true)
		_corte_eco(origem, ang, alcance * ECO_ESCALA, arco_graus * 1.1, lado, Color(claro.r * 0.75, claro.g * 0.75, claro.b * 0.75), dur * 0.9)
		var ponta := origem + Vector2.from_angle(ang + meio * lado) * alcance * 0.95  # onde o arco termina: a estrela que pisca no fim da varrida
		folha("estrela", ponta, alcance * 0.45, claro, dur * 0.8)
	elif Anim.suave and tipo == "estocada":  # o golpe pesado: estoura na ponta e racha o chão
		var ponta := origem + Vector2.from_angle(ang) * alcance
		explosao(ponta + Vector2(0, 10), alcance * 0.4, cor, 1.0, 0.5)
		if mundo != null and mundo.get("cam") != null:
			mundo.cam.socar(0.03)
		marca_chao(ponta + Vector2(0, 12), alcance * 0.3, cor)
	luz_rapida(origem + Vector2.from_angle(ang) * alcance * 0.55, cor, 1.7 if tipo == "estocada" else 1.35, alcance * 2.3, dur * 0.9)


## Efeito de folha do Blender no chão ("cristal", "anel", "espiral") ou a centelha de acerto ("estrela", no ar). `raio` = metade da largura
## do desenho; o chão achata em 0,62 no Y. Reaproveita o shader do corte e um pool fixo: não cria nó.
func folha(nome: String, p: Vector2, raio: float, cor: Color, dur: float) -> void:
	var cristal := nome == "cristal"
	var estrela := nome == "estrela"
	if cristal:  # crítico explosivo em horda densa: uma explosão colada na anterior não gasta slot
		for j in PRIM_CENTELHA:
			if _fo_cristal[j] == 1 and _fo_t[j] < 0.05 and _fo_t[j] < _fo_dur[j] and _fo[j].position.distance_to(p) < 20.0:
				return
	var i: int
	if estrela:
		i = _ce_i
		_ce_i = PRIM_CENTELHA + (_ce_i - PRIM_CENTELHA + 1) % (MAX_FOLHAS - PRIM_CENTELHA)
	else:
		i = _fo_i
		_fo_i = (_fo_i + 1) % PRIM_CENTELHA
	var d: Array = FOLHAS[nome]
	var s := _fo[i]
	s.position = p.round()
	s.scale = Vector2(raio / 32.0, raio / 32.0 * (1.0 if estrela else 0.62))
	s.visible = true
	var mat := s.material as ShaderMaterial
	mat.set_shader_parameter("folha", d[0])
	mat.set_shader_parameter("quadros", d[1])
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("prog", 0.0)
	mat.set_shader_parameter("suave", 1.0 if Anim.suave else 0.0)
	_fo_t[i] = 0.0
	_fo_dur[i] = dur
	_fo_cristal[i] = 1 if cristal else 0
	usados.folhas += 1


## O eco do corte: o crescente procedural (modo 0 do shader do corte), branco-claro e maior, varrendo junto da folha do Blender.
func _corte_eco(origem: Vector2, ang: float, alcance: float, arco_graus: float, lado: float, cor: Color, dur: float) -> void:
	var i := _eco_i
	_eco_i = (_eco_i + 1) % MAX_ECOS
	var s := _eco[i]
	s.position = origem.round()
	s.rotation = ang
	s.scale = Vector2.ONE * (alcance * 1.25 / 32.0)
	s.visible = true
	var mat := s.material as ShaderMaterial
	mat.set_shader_parameter("prog", 0.0)
	mat.set_shader_parameter("arco", deg_to_rad(arco_graus))
	mat.set_shader_parameter("lado", lado)
	mat.set_shader_parameter("cor", cor)
	_eco_t[i] = 0.0
	_eco_dur[i] = dur


## Clarão de tela na cor `cor` (o alfa é a força, 0,1 a 0,4), que some em `dur` s. Escala com a opção "Tremor e clarões"; em 0% não
## acende. Um clarão mais fraco não apaga um mais forte em andamento.
func clarao(cor: Color, dur := 0.15) -> void:
	if not Anim.suave or not Piscadas.clarao_permitido():
		return
	var f = Config.g("tremor_clarao")
	if f != null:
		cor.a *= clampf(float(f) / 100.0, 0.0, 1.0)
	if cor.a <= 0.0:
		return
	var agora := _cl_cor.a * (1.0 - clampf(_cl_t / _cl_dur, 0.0, 1.0))
	if cor.a < agora:
		return
	_cl_cor = cor
	_cl_dur = maxf(dur, 0.05)
	_cl_t = 0.0
	add.queue_redraw()


## Marca de dano no chão em `p`: cratera escura achatada e rachaduras tortas saindo do centro, que ficam MARCA_DUR s e somem; nos
## primeiros MARCA_BRASA s as rachaduras brilham na cor do golpe. Só desenho (pool fixo, polilinhas). Com Anim.suave desligado, nada.
func marca_chao(p: Vector2, raio: float, cor: Color) -> void:
	if not Anim.suave or chao == null:
		return
	var i := _mc_i
	_mc_i = (_mc_i + 1) % MAX_MARCAS_CHAO
	_mc_pos[i] = p.round()
	_mc_raio[i] = raio
	_mc_t[i] = 0.0
	_mc_cor[i] = cor
	var base := i * RACHAS * RACHA_PTS
	var giro := _rng.randf() * TAU
	for r in RACHAS:
		var ang := giro + TAU * (float(r) + _rng.randf_range(-0.3, 0.3)) / float(RACHAS)
		var comp := raio * _rng.randf_range(0.55, 1.0)
		var q := Vector2.ZERO
		for k in RACHA_PTS:
			if k > 0:
				ang += _rng.randf_range(-0.5, 0.5)
				q += Vector2(cos(ang), sin(ang) * 0.62) * comp / float(RACHA_PTS - 1)
			_mc_pts[base + r * RACHA_PTS + k] = q.round()
	_mc_ativas = true
	usados.chao += 1


## A explosão grande de impacto em `p` (chão achatado), com `raio` = o da área do golpe: os anéis param na borda real (~1,05 raio) e só o
## anel de fora e os espinhos passam um pouco dela. `espinhos` 0 tira o estouro de cristal (raio, anel saindo). Mais os brilhos que sobem
## e ficam no ar depois (pool de partículas). Só desenho: o dano já saiu em quem chamou. Com Anim.suave desligado (perfil Baixo), nada.
func explosao(p: Vector2, raio: float, cor: Color, espinhos := 1.0, dur := EXPLOSAO_DUR) -> void:
	if not Anim.suave:
		return
	var i := _ex_i
	_ex_i = (_ex_i + 1) % MAX_EXPLOSOES
	var s := _ex[i]
	var r := raio * 1.25
	s.position = p.round()
	s.scale = Vector2(r / 32.0, r / 32.0 * 0.62)
	s.visible = true
	var mat := s.material as ShaderMaterial
	mat.set_shader_parameter("prog", 0.0)
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("px", roundf(r * 2.0))
	mat.set_shader_parameter("calmo", 1.0 if Piscadas.ligado() else 0.0)
	mat.set_shader_parameter("semente", _rng.randf() * 10.0)
	mat.set_shader_parameter("espinhos", espinhos)
	_ex_t[i] = 0.0
	_ex_dur[i] = maxf(dur, 0.2)
	usados.explosoes += 1
	brilhos(p, raio, cor, roundi(clampf(raio / 6.0, 4.0, 14.0)))


## Brilhos que ficam no ar: pontos de luz que abrem do centro, flutuam subindo devagar e apagam em 0,5 a 1 s (a "cauda" do impacto).
func brilhos(p: Vector2, raio: float, cor: Color, n: int) -> void:
	n = roundi(n * fator_part)
	var claro := cor.lerp(Color.WHITE, 0.45)
	for k in n:
		var ang := _rng.randf() * TAU
		var d := raio * _rng.randf_range(0.25, 0.95)
		var v := Vector2(cos(ang), sin(ang) * 0.62) * d * _rng.randf_range(1.2, 2.0)
		particula(p + Vector2(0, -6), v, _rng.randf_range(0.5, 1.0), _rng.randf_range(5.0, 9.0), Color(claro.r, claro.g, claro.b, 0.85), -28.0, true)


func luz_rapida(pos: Vector2, cor: Color, energia: float, raio: float, dur: float) -> void:
	var i := _li
	_li = (_li + 1) % MAX_LUZES
	var l := _luzes[i]
	l.position = pos.round()
	l.color = cor
	l.energy = energia
	l.texture_scale = raio / 128.0
	l.enabled = true
	_luzes_t[i] = 0.0
	_luzes_dur[i] = dur
	_luzes_e[i] = energia


## Silhueta sobre o ator (branca por padrão). modo 0 = piscada de dano (segue o ator), 1 = morte (fica onde estava, encolhe e sobe), 2 = rastro da esquiva,
## 3 = marca sustentada do golpe forte (segue o ator, fica cheia e só some no fim; no máximo MAX_MARCAS, o revezamento a pula).
func flash(a, dur: float, cor := Color.WHITE, modo := 0, forca := 1.0) -> void:
	if a == null or a.tipo.is_empty():
		return
	if (modo == 0 or modo == 3) and Piscadas.ligado():  # "Reduzir piscadas": o mesmo ator não leva outra silhueta (flash ou marca) logo em seguida
		if not _pode_flash_acerto(a):
			return
		if modo == 0:
			forca = Piscadas.FLASH_ALFA  # a marca do golpe forte já é cheia: não tem alfa a fixar
	if modo == 3:
		var marcas := 0
		for j in MAX_FLASH:
			if _fl_modo[j] == 3 and _fl_t[j] < _fl_dur[j]:
				marcas += 1
		if marcas >= MAX_MARCAS:
			return
		usados.marcas += 1
	var i := _fi
	for _k in MAX_FLASH:  # o revezamento não pisa numa marca que ainda dura
		if _fl_modo[i] == 3 and _fl_t[i] < _fl_dur[i]:
			i = (i + 1) % MAX_FLASH
	_fi = i
	# reaproveita o flash que já segue este ator (piscadas seguidas não gastam slot)
	if modo == 0:
		for j in MAX_FLASH:
			if _fl_alvo[j] == a and _fl_t[j] < _fl_dur[j] and _fl_modo[j] == 0:
				i = j
				break
	if i == _fi:
		_fi = (_fi + 1) % MAX_FLASH
	var s := _fl[i]
	s.texture = a.tipo.alb
	s.offset = a.sprite.offset if a.sprite != null else a.offset
	s.region_rect = a.regiao
	s.flip_h = a.espelha
	s.position = a.raiz.position
	_fl_esc[i] = a.escala
	s.scale = Vector2.ONE * a.escala
	s.rotation = 0.0
	s.visible = true
	var mat := s.material as ShaderMaterial
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("k", forca)
	mat.set_shader_parameter("dissolver", 0.0)
	_fl_alvo[i] = a if (modo == 0 or modo == 3) else null
	_fl_t[i] = 0.0
	_fl_dur[i] = dur
	_fl_modo[i] = modo
	usados.flashes += 1


## Pode uma silhueta de acerto nova em `a` (flash de acerto ou marca do golpe forte)? Não, se ele levou outra há menos de FLASH_REPETE_S. Registra esta
## (anel de tamanho fixo, nada nasce). O flash e a marca do MESMO golpe chegam no mesmo quadro e se fundem num liga e desliga só: o segundo passa sem registrar.
func _pode_flash_acerto(a) -> bool:
	for j in _pisca_alvo.size():
		if _pisca_alvo[j] == a:
			var desde: float = _pisca_rel - _pisca_quando[j]
			if absf(desde) < 0.001:
				return true
			if desde < Piscadas.FLASH_REPETE_S:
				return false
	_pisca_alvo[_pisca_i] = a
	_pisca_quando[_pisca_i] = _pisca_rel
	_pisca_i = (_pisca_i + 1) % _pisca_alvo.size()
	return true


func _livre() -> int:
	for k in MAX_PART:
		var i := (_pi + k) % MAX_PART
		if p_vida[i] <= 0.0:
			_pi = (i + 1) % MAX_PART
			return i
	var j := _pi
	_pi = (_pi + 1) % MAX_PART
	return j


func particula(pos: Vector2, vel: Vector2, vida: float, tam: float, cor: Color, sobe := 0.0, brilho := false) -> void:
	var i := _livre()
	if p_vida[i] <= 0.0:
		p_ativas += 1
	p_pos[i] = pos
	p_vel[i] = vel
	p_vida[i] = vida
	p_max[i] = vida
	p_tam[i] = tam
	p_sobe[i] = sobe
	p_glow[i] = 1 if brilho else 0
	p_cor[i] = cor
	usados.particulas += 1


## Faíscas do acerto: um cone para longe do golpe, mais a estrela de impacto.
## desenhar=false mantém a mesma sequência de RNG, sem ocupar vagas (o mecha tem visual próprio).
func faiscas(pos: Vector2, dir: Vector2, n: int, cor: Color, vel := 170.0, desenhar := true) -> void:
	n = maxi(1, roundi(n * fator_part))
	var base := dir.angle()
	for i in n:
		var a := base + randf_range(-1.1, 1.1)
		var v := Vector2.from_angle(a) * vel * randf_range(0.35, 1.0)
		var vida := randf_range(0.12, 0.28)
		var tam := 2.0 if randf() < 0.6 else 3.0
		var tinta := cor.lerp(Color.WHITE, randf() * 0.6)
		if desenhar:
			particula(pos, v, vida, tam, tinta, 120.0)
	if desenhar:
		particula(pos, Vector2.ZERO, 0.11, 22.0, Color(1, 0.95, 0.8, 0.9), 0.0, true)


## O estouro da morte do monstro: ossos/cinzas para todo lado e almas que sobem.
## desenhar=false mantém o consumo de RNG do efeito substituído sem criar partículas/onda.
func estouro(pos: Vector2, cor: Color, n: int, desenhar := true) -> void:
	n = maxi(2, roundi(n * fator_part))
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a) * 0.7) * randf_range(35.0, 150.0)
		var vida := randf_range(0.3, 0.55)
		var tam := 2.0 if randf() < 0.7 else 3.0
		var tinta := cor.lerp(Color(0.85, 0.85, 0.8), randf() * 0.7)
		if desenhar:
			particula(pos, v, vida, tam, tinta, 150.0)
	for i in maxi(2, roundi(5 * fator_part)):
		var origem := pos + Vector2(randf_range(-5, 5), randf_range(-4, 2))
		var vel := Vector2(randf_range(-14, 14), randf_range(-30, -12))
		var vida := randf_range(0.45, 0.8)
		if desenhar:
			particula(origem, vel, vida, 9.0, Color(0.5, 0.9, 1.0, 0.6), -20.0, true)
	if desenhar:
		particula(pos, Vector2.ZERO, 0.16, 34.0, Color(1, 0.9, 0.75, 0.85), 0.0, true)
		onda(pos, Color(1, 0.9, 0.8, 0.8), 26.0, 0.18)


func onda(pos: Vector2, cor: Color, raio: float, dur: float) -> void:
	var i := _oi
	_oi = (_oi + 1) % MAX_ONDAS
	o_pos[i] = pos
	o_t[i] = 0.0
	o_dur[i] = dur
	o_raio[i] = raio
	o_cor[i] = cor


## Número de dano que salta, com contorno. `grande` = crítico (fonte 24; o normal é 16). Um dano que não é do golpe da katana (fogo,
## raio, aura...) usa `tam` menor se quiser.
func numero(pos: Vector2, texto: String, cor: Color, grande := false, tam := 0, exato := false) -> void:
	var i := _ni
	_ni = (_ni + 1) % MAX_NUM
	# `exato`: quem chama já escolheu o lugar (os estilhaços abrem em leque), então sem o sorteio de lado e de altura
	n_pos[i] = pos if exato else pos + Vector2(randf_range(-12.0, 12.0), -10.0 - float(_ni % 4) * 8.0)
	n_t[i] = 0.0
	n_dur[i] = 1.0 if grande else 0.75
	n_txt[i] = texto
	n_tam[i] = tam if tam > 0 else (24 if grande else 16)
	n_cor[i] = cor
	n_ativos += 1
	usados.numeros += 1


func limpar() -> void:
	_frag_t.fill(0.0)
	for s in _fragmentos:
		s.visible = false
	p_vida.fill(0.0)
	p_ativas = 0
	n_t.fill(9.0)
	n_ativos = 0
	o_t.fill(9.0)
	_cortes_t.fill(9.0)
	_fl_t.fill(9.0)
	_fo_t.fill(9.0)
	_luzes_t.fill(9.0)
	for s in _cortes:
		s.visible = false
	for s in _fl:
		s.visible = false
	for s in _fo:
		s.visible = false
	_ex_t.fill(9.0)
	_eco_t.fill(9.0)
	_mc_t.fill(99.0)
	_mc_ativas = false
	_cl_t = 9.0
	if chao != null:
		chao.queue_redraw()
	for s in _ex:
		s.visible = false
	for s in _eco:
		s.visible = false
	for l in _luzes:
		l.enabled = false
	add.queue_redraw()
	txt.queue_redraw()


# ------------------------------------------------------------------ quadro (relógio de parede: continua durante o hit-stop)


func atualizar(dt: float) -> void:
	_pisca_rel += dt
	for i in MAX_FRAGMENTOS:
		if _frag_t[i] <= 0.0:
			continue
		_frag_t[i] -= dt
		var s := _fragmentos[i]
		if _frag_t[i] <= 0.0:
			s.visible = false
			continue
		s.position += _frag_v[i] * dt
		_frag_v[i].y += 180.0 * dt
		s.rotation += dt * (2.0 if i % 2 == 0 else -2.0)
	var desenha := false
	# partículas
	if p_ativas > 0:
		desenha = true
		for i in MAX_PART:
			var v := p_vida[i]
			if v <= 0.0:
				continue
			v -= dt
			if v <= 0.0:
				p_vida[i] = 0.0
				p_ativas -= 1
				continue
			p_vida[i] = v
			var vel := p_vel[i]
			vel.y += p_sobe[i] * dt
			vel *= exp(-3.0 * dt)
			p_vel[i] = vel
			p_pos[i] += vel * dt
	# números
	if n_ativos > 0:
		var vivos := 0
		for i in MAX_NUM:
			if n_t[i] >= n_dur[i]:
				continue
			n_t[i] += dt
			if n_t[i] >= n_dur[i]:
				continue
			vivos += 1
			var k := n_t[i] / n_dur[i]
			var q := n_pos[i]
			q.y -= (62.0 * (1.0 - k) + 6.0) * dt
			n_pos[i] = q
		n_ativos = vivos
		txt.queue_redraw()
	# ondas
	var ondas := false
	for i in MAX_ONDAS:
		if o_t[i] < o_dur[i]:
			o_t[i] += dt
			ondas = true
	if ondas or desenha:
		add.queue_redraw()
	# cortes
	for i in MAX_CORTES:
		if _cortes_t[i] >= _cortes_dur[i]:
			continue
		_cortes_t[i] += dt
		var s := _cortes[i]
		if _cortes_t[i] >= _cortes_dur[i]:
			s.visible = false
			continue
		var pr := _cortes_t[i] / _cortes_dur[i]
		(s.material as ShaderMaterial).set_shader_parameter("prog", pr)
		if Anim.suave:  # abre rápido e assenta (ease-out), em vez de nascer já do tamanho final
			var k := clampf(pr / CORTE_CRESCE, 0.0, 1.0)
			s.scale = Vector2.ONE * _cortes_esc[i] * (0.88 + 0.12 * (1.0 - (1.0 - k) * (1.0 - k)))
	# clarão
	if _cl_t < _cl_dur:
		_cl_t += dt
		add.queue_redraw()
	# marcas no chão
	if _mc_ativas:
		var alguma := false
		for i in MAX_MARCAS_CHAO:
			if _mc_t[i] < MARCA_DUR:
				_mc_t[i] += dt
				alguma = true
		_mc_ativas = alguma
		if chao != null:
			chao.queue_redraw()
		add.queue_redraw()
	# explosões grandes
	for i in MAX_EXPLOSOES:
		if _ex_t[i] >= _ex_dur[i]:
			continue
		_ex_t[i] += dt
		if _ex_t[i] >= _ex_dur[i]:
			_ex[i].visible = false
			continue
		(_ex[i].material as ShaderMaterial).set_shader_parameter("prog", _ex_t[i] / _ex_dur[i])
		(_ex[i].material as ShaderMaterial).set_shader_parameter("calmo", 1.0 if Piscadas.ligado() else 0.0)
	for i in MAX_ECOS:
		if _eco_t[i] >= _eco_dur[i]:
			continue
		_eco_t[i] += dt
		if _eco_t[i] >= _eco_dur[i]:
			_eco[i].visible = false
			continue
		(_eco[i].material as ShaderMaterial).set_shader_parameter("prog", _eco_t[i] / _eco_dur[i])
	# folhas
	for i in MAX_FOLHAS:
		if _fo_t[i] >= _fo_dur[i]:
			continue
		_fo_t[i] += dt
		if _fo_t[i] >= _fo_dur[i]:
			_fo[i].visible = false
			continue
		(_fo[i].material as ShaderMaterial).set_shader_parameter("prog", _fo_t[i] / _fo_dur[i])
	# luzes
	for i in MAX_LUZES:
		if _luzes_t[i] >= _luzes_dur[i]:
			continue
		_luzes_t[i] += dt
		var l := _luzes[i]
		if _luzes_t[i] >= _luzes_dur[i]:
			l.enabled = false
			continue
		var k := 1.0 - _luzes_t[i] / _luzes_dur[i]
		l.energy = _luzes_e[i] * k * k
	# flashes
	for i in MAX_FLASH:
		if _fl_t[i] >= _fl_dur[i]:
			continue
		_fl_t[i] += dt
		var s := _fl[i]
		if _fl_t[i] >= _fl_dur[i]:
			s.visible = false
			_fl_alvo[i] = null
			continue
		var k := _fl_t[i] / _fl_dur[i]
		var mat := s.material as ShaderMaterial
		match _fl_modo[i]:
			0:
				var a = _fl_alvo[i]
				if a != null:
					s.position = a.raiz.position
					s.region_rect = a.regiao
					s.flip_h = a.espelha
				mat.set_shader_parameter("k", Piscadas.FLASH_ALFA if Piscadas.ligado() else 1.0 - k * k)  # com a opção: alfa parado, sem esmaecer em degraus
			3:
				var a = _fl_alvo[i]
				if a != null:
					s.position = a.raiz.position
					s.region_rect = a.regiao
					s.flip_h = a.espelha
				mat.set_shader_parameter("k", 1.0 if k < 0.65 else (1.0 - k) / 0.35)
			1:
				mat.set_shader_parameter("dissolver", k)
				s.scale = Vector2(1.0 + 0.25 * k, 1.0 - 0.35 * k) * _fl_esc[i]
				s.position.y -= 24.0 * dt
				mat.set_shader_parameter("k", 1.0 - k)
			2:
				mat.set_shader_parameter("k", 0.55 * (1.0 - k))


# ------------------------------------------------------------------ desenho


func _desenhar_add() -> void:
	if _cl_t < _cl_dur and mundo != null and mundo.get("cam") != null:
		var k := 1.0 - _cl_t / _cl_dur
		add.draw_rect(mundo.cam.retangulo(16.0), Color(_cl_cor.r, _cl_cor.g, _cl_cor.b, _cl_cor.a * k * k))
	if _mc_ativas:  # as rachaduras acesas na cor do golpe, apagando
		for i in MAX_MARCAS_CHAO:
			var t := _mc_t[i]
			if t >= MARCA_BRASA:
				continue
			var k := 1.0 - t / MARCA_BRASA
			var c := _mc_cor[i].lerp(Color(1.0, 0.85, 0.6), 0.35)
			c.a = k * k
			var base := i * RACHAS * RACHA_PTS
			for r in RACHAS:
				var linha := PackedVector2Array()
				for j in RACHA_PTS:
					linha.append(_mc_pos[i] + _mc_pts[base + r * RACHA_PTS + j])
				add.draw_polyline(linha, c, 2.0)
	for i in MAX_PART:
		var v := p_vida[i]
		if v <= 0.0:
			continue
		var c := p_cor[i]
		var k := v / p_max[i]
		c.a *= minf(1.0, k * 2.2)
		var tam := p_tam[i]
		var p := p_pos[i].round()
		if p_glow[i] == 1:
			var t2 := tam * (1.6 - 0.6 * k)
			add.draw_texture_rect(tex_brilho, Rect2(p - Vector2(t2, t2) * 0.5, Vector2(t2, t2)), false, c)
		else:
			add.draw_rect(Rect2(p - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), c)
	for i in MAX_ONDAS:
		if o_t[i] >= o_dur[i]:
			continue
		var k := o_t[i] / o_dur[i]
		var c := o_cor[i]
		c.a *= 1.0 - k
		var r := o_raio[i] * (1.0 - (1.0 - k) * (1.0 - k))
		add.draw_arc(o_pos[i].round(), r, 0.0, TAU, 28, c, 2.0)


## A cratera e as rachaduras (camada do mundo, normal): escurecem o chão e somem no último terço.
func _desenhar_chao() -> void:
	for i in MAX_MARCAS_CHAO:
		var t := _mc_t[i]
		if t >= MARCA_DUR:
			continue
		var fade := 1.0 - smoothstep(MARCA_DUR * 0.6, MARCA_DUR, t)
		var p := _mc_pos[i]
		var r := _mc_raio[i]
		var cresce := minf(1.0, t / 0.08)
		var tam := Vector2(r * 1.5, r * 0.93) * cresce
		chao.draw_texture_rect(tex_brilho, Rect2(p - tam * 0.5, tam), false, Color(0, 0, 0, 0.65 * fade))
		chao.draw_texture_rect(tex_brilho, Rect2(p - tam * 0.25, tam * 0.5), false, Color(0.02, 0.01, 0.01, 0.55 * fade))
		var base := i * RACHAS * RACHA_PTS
		for k in RACHAS:
			var linha := PackedVector2Array()
			for j in RACHA_PTS:
				linha.append(p + _mc_pts[base + k * RACHA_PTS + j] * cresce)
			chao.draw_polyline(linha, Color(0.05, 0.03, 0.03, 0.9 * fade), 3.0 if r >= 40.0 else 2.0)


func _desenhar_numeros() -> void:
	if fonte == null:
		return
	for i in MAX_NUM:
		if n_t[i] >= n_dur[i]:
			continue
		var k := n_t[i] / n_dur[i]
		var tam := n_tam[i]
		if tam == 24 and n_t[i] < 0.08:
			tam = 32
		var c := n_cor[i]
		c.a = 1.0 if k < 0.65 else 1.0 - (k - 0.65) / 0.35
		var t: String = n_txt[i]
		var larg := fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var p := (n_pos[i] - Vector2(larg * 0.5, 0)).round()
		txt.draw_string_outline(fonte, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 6 if tam >= 24 else 5, Color(0, 0, 0, c.a))
		txt.draw_string(fonte, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, c)
