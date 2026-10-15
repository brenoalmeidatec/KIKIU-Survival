extends RefCounted
## Efeitos de impacto da v2 (golpe, acerto, morte, dano). TUDO em pool: vetores de tamanho fixo e nós criados uma vez só; um acerto não cria
## nó nenhum. Fica na camada "glow" (acima do escurecimento do cenário, então o brilho não é apagado pela escuridão da floresta):
##  - cortes: o rastro da katana, um Sprite2D com shader (crescente que varre, ou estocada em linha) em mistura aditiva;
##  - luzes: PointLight2D rápidas que acendem o chão ao redor do golpe;
##  - flashes: silhueta branca (ou colorida) por cima do monstro que apanhou, que some em ~0,09 s; também o fantasma da morte e o rastro da esquiva;
##  - partículas (faíscas, estouro da morte, almas subindo) e ondas de choque, desenhadas numa só chamada aditiva por quadro;
##  - números de dano: texto com contorno que sobe e some, desenhado numa só chamada (fonte pixel do jogo, tamanhos 8 e 16).
## Posições são arredondadas para pixel inteiro ao desenhar (o pixel art não treme).

const Herois := preload("res://v2/herois.gd")
const MAX_PART := 360
const MAX_NUM := 64
const MAX_CORTES := 4
const MAX_FLASH := 24
const MAX_LUZES := 3
const MAX_ONDAS := 6
const FOLHA_CORTE := preload("res://assets/v2/efeitos/corte_hazaki.png")  # 16 quadros 128x128, feita no Blender (fonte_arte/blender_corte)
const FOLHA_CORTE_CIANO := preload("res://assets/v2/efeitos/corte_hazaki_ciano.png")  # variante: so a energia ciano, 12 quadros

const SHADER_CORTE := """
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform float prog = 0.0;
uniform float arco = 2.2;
uniform float lado = 1.0;
uniform float modo = 0.0;
uniform vec4 cor : source_color = vec4(1.0);
uniform float quadros = 16.0;
uniform float raio_px = 80.0;  // raio do arco na tela (px): converte a distância em UV para px
uniform vec3 poupa = vec3(0.0, 1.0, 1.0);  // poupar o corpo do herói: x = raio apagado (px), y = largura do degradê (px), z = brilho que sobra no centro
uniform float fixo = 0.0;  // 1 = rampa ciano fixa (variante ciano) em vez da cor do golpe
uniform sampler2D folha : filter_nearest;  // corte feito no Blender (fonte_arte/blender_corte): 16 quadros em linha, RGB = calor, A = intensidade
float pos(float x) { return floor(x * 8.0 + 0.5) / 8.0; }
void fragment() {
	if (modo > 1.5) {
		float q = min(floor(prog * quadros), quadros - 1.0);
		vec4 t = texture(folha, vec2((UV.x + q) / quadros, lado > 0.0 ? UV.y : 1.0 - UV.y));
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
	// o herói por cima do arco: perto da origem do golpe (o corpo) o brilho aditivo cai para `poupa.z`, para o rastro não apagar o herói
	float dist_px = length(UV - 0.5) * 2.0 * raio_px;
	float dim = mix(poupa.z, 1.0, smoothstep(poupa.x, poupa.x + poupa.y, dist_px));
	COLOR *= dim;
}
"""

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
var _fl_esc := PackedFloat32Array()  # tamanho do ator (elite e chefe são maiores)
var _fl_modo := PackedByteArray()  # 0 = piscada de dano, 1 = morte (encolhe e some), 2 = rastro da esquiva
var _fi := 0

var usados := {"cortes": 0, "flashes": 0, "particulas": 0, "numeros": 0}  # contadores para os testes


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
	_cortes_t.fill(9.0)
	_cortes_dur.fill(1.0)


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
	s.scale = Vector2.ONE * (r / 32.0)
	s.visible = true
	var mat := s.material as ShaderMaterial
	mat.set_shader_parameter("prog", 0.0)
	mat.set_shader_parameter("arco", deg_to_rad(arco_graus))
	mat.set_shader_parameter("lado", lado)
	mat.set_shader_parameter("raio_px", r)
	mat.set_shader_parameter("poupa", _poupa_corpo())
	mat.set_shader_parameter("modo", 2.0 if folha else (1.0 if tipo == "estocada" else 0.0))
	var ciano := variante == "ciano"
	mat.set_shader_parameter("folha", FOLHA_CORTE_CIANO if ciano else FOLHA_CORTE)
	mat.set_shader_parameter("quadros", 12.0 if ciano else 16.0)
	mat.set_shader_parameter("fixo", 1.0 if ciano else 0.0)
	mat.set_shader_parameter("cor", cor)
	_cortes_t[i] = 0.0
	_cortes_dur[i] = dur
	usados.cortes += 1
	luz_rapida(origem + Vector2.from_angle(ang) * alcance * 0.55, cor, 1.7 if tipo == "estocada" else 1.35, alcance * 2.3, dur * 0.9)


## Quanto o arco do golpe poupa o corpo do herói (dados/v2_herois.json, legibilidade.arco): (raio apagado px, degradê px, brilho que sobra).
func _poupa_corpo() -> Vector3:
	var a: Dictionary = Herois.legibilidade().get("arco", {})
	return Vector3(float(a.get("raio_px", 0.0)), maxf(float(a.get("borda_px", 1.0)), 1.0), float(a.get("minimo", 1.0)))


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


## Silhueta sobre o ator (branca por padrão). modo 0 = piscada de dano (segue o ator), 1 = morte (fica onde estava, encolhe e sobe), 2 = rastro da esquiva.
func flash(a, dur: float, cor := Color.WHITE, modo := 0, forca := 1.0) -> void:
	if a == null or a.tipo.is_empty():
		return
	var i := _fi
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
	_fl_alvo[i] = a if modo == 0 else null
	_fl_t[i] = 0.0
	_fl_dur[i] = dur
	_fl_modo[i] = modo
	usados.flashes += 1


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
func faiscas(pos: Vector2, dir: Vector2, n: int, cor: Color, vel := 170.0) -> void:
	n = maxi(1, roundi(n * fator_part))
	var base := dir.angle()
	for i in n:
		var a := base + randf_range(-1.1, 1.1)
		var v := Vector2.from_angle(a) * vel * randf_range(0.35, 1.0)
		particula(pos, v, randf_range(0.12, 0.28), 2.0 if randf() < 0.6 else 3.0, cor.lerp(Color.WHITE, randf() * 0.6), 120.0)
	particula(pos, Vector2.ZERO, 0.11, 22.0, Color(1, 0.95, 0.8, 0.9), 0.0, true)


## O estouro da morte do monstro: ossos/cinzas para todo lado e almas que sobem.
func estouro(pos: Vector2, cor: Color, n: int) -> void:
	n = maxi(2, roundi(n * fator_part))
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a) * 0.7) * randf_range(35.0, 150.0)
		particula(pos, v, randf_range(0.3, 0.55), 2.0 if randf() < 0.7 else 3.0, cor.lerp(Color(0.85, 0.85, 0.8), randf() * 0.7), 150.0)
	for i in maxi(2, roundi(5 * fator_part)):
		particula(
			pos + Vector2(randf_range(-5, 5), randf_range(-4, 2)),
			Vector2(randf_range(-14, 14), randf_range(-30, -12)),
			randf_range(0.45, 0.8),
			9.0,
			Color(0.5, 0.9, 1.0, 0.6),
			-20.0,
			true
		)
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
func numero(pos: Vector2, texto: String, cor: Color, grande := false, tam := 0) -> void:
	var i := _ni
	_ni = (_ni + 1) % MAX_NUM
	n_pos[i] = pos + Vector2(randf_range(-12.0, 12.0), -10.0 - float(_ni % 4) * 8.0)
	n_t[i] = 0.0
	n_dur[i] = 1.0 if grande else 0.75
	n_txt[i] = texto
	n_tam[i] = tam if tam > 0 else (24 if grande else 16)
	n_cor[i] = cor
	n_ativos += 1
	usados.numeros += 1


func limpar() -> void:
	p_vida.fill(0.0)
	p_ativas = 0
	n_t.fill(9.0)
	n_ativos = 0
	o_t.fill(9.0)
	_cortes_t.fill(9.0)
	_fl_t.fill(9.0)
	_luzes_t.fill(9.0)
	for s in _cortes:
		s.visible = false
	for s in _fl:
		s.visible = false
	for l in _luzes:
		l.enabled = false
	add.queue_redraw()
	txt.queue_redraw()


# ------------------------------------------------------------------ quadro (relógio de parede: continua durante o hit-stop)


func atualizar(dt: float) -> void:
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
		(s.material as ShaderMaterial).set_shader_parameter("prog", _cortes_t[i] / _cortes_dur[i])
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
				mat.set_shader_parameter("k", 1.0 - k * k)
			1:
				mat.set_shader_parameter("dissolver", k)
				s.scale = Vector2(1.0 + 0.25 * k, 1.0 - 0.35 * k) * _fl_esc[i]
				s.position.y -= 24.0 * dt
				mat.set_shader_parameter("k", 1.0 - k)
			2:
				mat.set_shader_parameter("k", 0.55 * (1.0 - k))


# ------------------------------------------------------------------ desenho


func _desenhar_add() -> void:
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
