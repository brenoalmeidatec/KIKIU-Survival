extends CanvasLayer
const Perf := preload("res://scripts/hordas/perf.gd")
## Escuridão da fase de horror (#32 item 5). Só liga nas fases de corrida.json que têm o campo "escuro".
## Como funciona (GL Compatibility, um draw call): um ColorRect em tela cheia, ENTRE o mundo e o HUD (layer 1),
## com um shader que lê a tela já desenhada e a escurece, deixando luz em volta do herói, das tochas, dos santuários
## e dos inimigos com "luz" no json (espectro, abominação, chefe). A luz cai de forma contínua (sem degraus e sem
## pontilhado: a direção visual 2.5D quer escuro liso). O que é MUITO claro na tela (olhos e chamas dos bichos, tiros, gemas, números de dano)
## atravessa a escuridão: é o que faz os olhos brilharem no escuro, sem desenhar nada a mais por inimigo.
## As tochas são decoração do mundo (posições sorteadas por hash, iguais em toda máquina), desenhadas por aqui
## porque o cenário (cenario.gd/chao.gd) não sabe de horror. Clima: névoa no shader e sons graves de vez em quando.

const W := 640.0
const H := 360.0
const MAX_LUZES := 16
const CELULA := 340.0          # uma tocha possível por célula do mundo
const SOM_CLIMA := [["tremor", 0.38, -13.0], ["tremor", 0.55, -15.0], ["whoosh", 0.28, -15.0], ["whoosh", 0.4, -17.0]]

const SHADER := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 luzes[16];
uniform int n = 0;
uniform float forca = 0.9;
uniform vec3 tom = vec3(0.03, 0.025, 0.07);
uniform float nevoa = 0.5;
uniform float t = 0.0;
uniform int halo_n = 8;   // leituras da tela do halo (perfil de qualidade: 8 alta, 4 média, 0 baixa)
uniform float aparece = 1.0;
uniform vec3 ambiente = vec3(1.0);   // tom do cenário (CanvasModulate do chão): desfeito pra medir o brilho de verdade
const vec2 OFS[8] = vec2[8](vec2(2.0, 0.0), vec2(-2.0, 0.0), vec2(0.0, 2.0), vec2(0.0, -2.0), vec2(3.0, 3.0), vec2(-3.0, 3.0), vec2(3.0, -3.0), vec2(-3.0, -3.0));

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = floor(FRAGCOORD.xy);
	vec3 c = textureLod(tela, SCREEN_UV, 0.0).rgb;
	float l = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= n) { break; }
		vec4 L = luzes[i];
		float d = distance(p, L.xy);
		float k = 1.0 - smoothstep(L.z * 0.2, L.z, d);
		l = max(l, k * k * (3.0 - 2.0 * k) * L.w);
	}
	l = clamp(l, 0.0, 1.0);   // luz contínua: sem degraus e sem pontilhado (escuro liso, como o resto da direção 2.5D)
	vec3 amb = max(ambiente, vec3(0.3));
	float v = max(c.r / amb.r, max(c.g / amb.g, c.b / amb.b));
	float brilho = smoothstep(0.86, 0.96, v);
	float vis = max(l, brilho);
	// névoa que anda devagar, só no escuro
	float f = ruido(p / 70.0 + vec2(t * 0.06, t * 0.02)) * 0.6 + ruido(p / 26.0 - vec2(t * 0.04, 0.0)) * 0.4;
	vec3 escuro = c * (1.0 - forca) + tom + vec3(0.09, 0.1, 0.13) * f * nevoa;
	vec3 claro = c * mix(vec3(1.0), vec3(1.1, 0.97, 0.82), l * 0.7);
	vec3 res = mix(escuro, claro, vis);
	// halo: o que brilha "sangra" um pouco de luz em volta (olhos, chamas e tiros no escuro); só onde está escuro
	if (halo_n > 0 && vis < 0.99) {
		vec3 halo = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			if (i >= halo_n) { break; }
			vec3 cc = textureLod(tela, SCREEN_UV + OFS[i] * SCREEN_PIXEL_SIZE, 0.0).rgb;
			float g = smoothstep(0.86, 0.96, max(cc.r / amb.r, max(cc.g / amb.g, cc.b / amb.b)));
			halo += cc * g * (i < 4 ? 0.15 : 0.1);
		}
		res = mix(res + halo * 0.55, res, vis);
	}
	COLOR = vec4(mix(c, res, aparece), 1.0);
}
"""

var arena: Node
var _rect := ColorRect.new()
var _mat := ShaderMaterial.new()
var _tochas := Node2D.new()
var _ligada := false
var _aparece := 0.0
var _t := 0.0
var _cfg: Dictionary = {}
var _luzes := PackedVector4Array()
var _prox_som := 6.0
var luzes_ativas := 0          # teste e depuração: quantas luzes foram mandadas no último quadro


## Configuração de escuridão de uma fase (o dicionário "escuro" de corrida.json), ou {} se a fase é clara.
static func da_fase(fase: Dictionary) -> Dictionary:
	var e = fase.get("escuro", {})
	return e if e is Dictionary else {}


func _ready() -> void:
	layer = 1
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_luzes.resize(MAX_LUZES)
	_rect.size = Vector2(W, H)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	_tochas.draw.connect(_desenhar_tochas)
	_tochas.visible = false
	arena.add_child.call_deferred(_tochas)
	_acomodar_tochas.call_deferred()


func _acomodar_tochas() -> void:
	# as tochas ficam logo acima do chão, abaixo de inimigos e herói
	if is_instance_valid(arena.chao) and _tochas.is_inside_tree():
		arena.move_child(_tochas, arena.chao.get_index() + 1)


func ligada() -> bool:
	return _ligada


func _process(dt: float) -> void:
	var _pp := Perf.ini()
	_process_i(dt)
	Perf.fim("esc_p", _pp)


func _process_i(dt: float) -> void:
	if arena == null or arena.diretor == null:
		return
	var fases: Array = arena.diretor.fases()
	var idx: int = clampi(arena.diretor.fase_idx, 0, fases.size() - 1)
	_cfg = da_fase(fases[idx])
	var quer: bool = not _cfg.is_empty() and not arena.acabou and not arena.duelo_ativo
	if quer != _ligada:
		_ligada = quer
		_prox_som = 4.0
	var alvo := 1.0 if _ligada else 0.0
	_aparece = move_toward(_aparece, alvo, dt / (1.6 if _ligada else 0.3))
	var visivel := _aparece > 0.001
	_rect.visible = visivel
	_tochas.visible = _ligada
	if not visivel:
		return
	_t += dt
	_mat.set_shader_parameter("t", _t)
	_mat.set_shader_parameter("halo_n", Config.leituras_horror())
	_mat.set_shader_parameter("aparece", _aparece)
	var amb: Color = arena.chao._ambiente.color if arena.chao and "_ambiente" in arena.chao else Color.WHITE
	_mat.set_shader_parameter("ambiente", Vector3(amb.r, amb.g, amb.b))
	if not _cfg.is_empty():
		_mat.set_shader_parameter("forca", float(_cfg.get("forca", 0.9)))
		_mat.set_shader_parameter("nevoa", float(_cfg.get("nevoa", 0.5)))
		var tom: Array = _cfg.get("tom", [0.03, 0.025, 0.07])
		_mat.set_shader_parameter("tom", Vector3(tom[0], tom[1], tom[2]))
	_atualizar_luzes()
	_tochas.queue_redraw()
	_clima(dt)


func _atualizar_luzes() -> void:
	var ct: Transform2D = get_viewport().get_canvas_transform()
	var n := 0
	var max_l := mini(MAX_LUZES, Config.luzes_horror())   # perfil de qualidade
	var jog: Vector2 = ct * arena.jogador.centro()
	var pisca := 1.0 + 0.035 * sin(_t * 9.0) + 0.02 * sin(_t * 23.0)
	_luzes[n] = Vector4(jog.x, jog.y, float(_cfg.get("raio_heroi", 130.0)) * pisca, 1.0)
	n += 1
	var rt := float(_cfg.get("raio_tocha", 100.0))
	for tc in _tochas_perto():
		if n >= max_l - 4:
			break
		var sp: Vector2 = ct * (tc[0] + Vector2(0, -12))
		_luzes[n] = Vector4(sp.x, sp.y, rt * (1.0 + 0.07 * sin(_t * 11.0 + tc[1]) + 0.04 * sin(_t * 27.0 + tc[1] * 2.0)), 0.95)
		n += 1
	for s in arena.chao.santuarios:
		if n >= max_l - 2:
			break
		var sp2: Vector2 = ct * s.pos
		if sp2.x > -80 and sp2.x < W + 80 and sp2.y > -80 and sp2.y < H + 80:
			_luzes[n] = Vector4(sp2.x, sp2.y, 52.0, 0.6)
			n += 1
	for v in arena.inimigos.lista:
		if v.luz.x <= 0.0 or v.hp <= 0.0:
			continue
		var sv: Vector2 = ct * (v.pos + Vector2(0, -v.sz.y * 0.3))
		if sv.x > -140 and sv.x < W + 140 and sv.y > -140 and sv.y < H + 140:
			_luzes[n] = Vector4(sv.x, sv.y, v.luz.x, v.luz.y)
			n += 1
			if n >= max_l:
				break
	luzes_ativas = n
	_mat.set_shader_parameter("luzes", _luzes)
	_mat.set_shader_parameter("n", n)


# ---------- tochas ----------

static func _hash(cx: int, cy: int, sem: int) -> int:
	return absi((cx * 73856093) ^ (cy * 19349663) ^ (sem * 83492791 + 12345)) & 0x7fffffff


## Tochas do mundo perto da câmera: [posição, número] (o número varia a chama de cada uma).
func _tochas_perto() -> Array:
	var res := []
	var cam: Vector2 = arena.camera.get_screen_center_position()
	var c0 := Vector2i(floori((cam.x - W / 2 - 120) / CELULA), floori((cam.y - H / 2 - 120) / CELULA))
	var c1 := Vector2i(floori((cam.x + W / 2 + 120) / CELULA), floori((cam.y + H / 2 + 120) / CELULA))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var h := _hash(cx, cy, int(arena.semente))
			if h % 100 < 34:
				res.append([Vector2(cx * CELULA + 40 + (h >> 8) % int(CELULA - 80), cy * CELULA + 40 + (h >> 16) % int(CELULA - 80)), h % 97])
	if absf(cam.x) < 600 and absf(cam.y) < 500:
		res.append([Vector2(120, -70), 3])    # sempre uma tocha perto de onde o herói nasce
	return res


func _desenhar_tochas() -> void:
	for tc in _tochas_perto():
		var p: Vector2 = tc[0]
		var f: float = float(tc[1])
		# bacia de ferro num poste; a chama oscila
		_tochas.draw_rect(Rect2(p.x - 1, p.y - 12, 3, 12), Color(0.12, 0.1, 0.14))
		_tochas.draw_rect(Rect2(p.x - 3, p.y - 15, 7, 4), Color(0.2, 0.17, 0.22))
		var a := sin(_t * 12.0 + f) * 0.5 + sin(_t * 29.0 + f * 3.0) * 0.5
		var alt := 6.0 + a * 1.5
		_tochas.draw_rect(Rect2(p.x - 2, p.y - 15 - alt, 5, alt), Color(0.94, 0.57, 0.12))
		_tochas.draw_rect(Rect2(p.x - 1, p.y - 15 - alt + 1.0, 3, alt - 1.0), Color(1.0, 0.82, 0.38))
		_tochas.draw_rect(Rect2(p.x, p.y - 17 - alt * 0.5, 1, 2), Color(1.0, 0.95, 0.7))


# ---------- clima ----------

func _clima(dt: float) -> void:
	if not _ligada:
		return
	_prox_som -= dt
	if _prox_som > 0.0:
		return
	_prox_som = randf_range(5.0, 11.0)
	var s: Array = SOM_CLIMA[randi() % SOM_CLIMA.size()]
	Som.tocar(str(s[0]), 0.5, float(s[1]), float(s[2]))
