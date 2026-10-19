extends RefCounted
## Elites da v2 (leva 3): um monstro MAIOR, com contorno colorido que brilha e UM modificador (veloz, blindado, explosivo ou invocador).
## Nasce fora da tela de tempos em tempos (dados/v2_cartas.json > "elites"), vale muito mais XP e, ao morrer, solta um BAÚ (v2/bau.gd). O
## contorno é um sprite aditivo na camada glow, com um shader que desenha só a borda de fora da silhueta (e não vaza para o quadro vizinho
## da folha: a leitura é presa à região do quadro). Os chefes (v2/chefe.gd) usam o mesmo contorno.

const SHADER_CONTORNO := """
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform vec4 cor : source_color = vec4(1.0);
uniform vec4 reg = vec4(0.0, 0.0, 1.0, 1.0);
uniform float brilho = 1.0;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float a = texture(TEXTURE, UV).a;
	float v = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = 0.785398 * float(i);
		vec2 u = clamp(UV + vec2(cos(ang), sin(ang)) * px * 1.2, reg.xy + px * 0.5, reg.zw - px * 0.5);
		v = max(v, texture(TEXTURE, u).a);
	}
	float borda = step(0.3, v) * (1.0 - step(0.3, a));
	COLOR = vec4(cor.rgb * brilho * 1.6 * borda, borda);
}
"""

var combate
var mundo
var cfg: Dictionary = {}
var vivas: Array = []
var nascidas := 0  # quantas elites já nasceram (testes)
var proxima := 0.0
var _shader: Shader
var _filhos := {}  # elite -> invocados vivos
var _rng := RandomNumberGenerator.new()


func montar(c) -> void:
	combate = c
	mundo = c.mundo
	cfg = c.cartas.cfg.elites
	_shader = Shader.new()
	_shader.code = SHADER_CONTORNO
	zerar()


func zerar() -> void:
	vivas.clear()
	_filhos.clear()
	nascidas = 0
	proxima = float(cfg.primeira)
	_rng.seed = 424242


func atualizar(dt: float) -> void:
	var t: float = mundo.tempo_partida
	var i := vivas.size() - 1
	while i >= 0:
		var m = vivas[i]
		if not m.vivo or not m.elite:
			vivas.remove_at(i)
		elif m.mod_elite == "invoca":
			m.invoca_t -= dt
			if m.invoca_t <= 0.0:
				_invocar(m)
		i -= 1
	if t < proxima:
		return
	if vivas.size() >= int(cfg.max_vivos) or combate.chefes.vivo:
		proxima = t + 4.0
		return
	if nascer() != null:
		proxima = t + float(cfg.cada)
	else:
		proxima = t + 1.0


## Faz nascer uma elite fora da tela. `sprite` e `mod` vazios = sorteia (por tempo de partida). Devolve o monstro, ou null se não achou lugar.
func nascer(sprite := "", mod := "", onde: Variant = null):
	var p: Variant = onde if onde != null else combate.diretor.ponto_fora_da_tela()
	if p == null:
		return null
	var t: float = mundo.tempo_partida
	var info: Dictionary = {}
	var pool: Array = []
	for e in cfg.tipos:
		if sprite != "":
			if e.sprite == sprite:
				info = e
		elif t >= float(e.desde):
			pool.append(e)
	if info.is_empty():
		info = pool[_rng.randi() % pool.size()] if not pool.is_empty() else cfg.tipos[0]
	var md: Dictionary = {}
	for e in cfg.modificadores:
		if mod != "" and e.id == mod:
			md = e
	if md.is_empty():
		md = cfg.modificadores[_rng.randi() % cfg.modificadores.size()]
	var minutos: float = t / 60.0
	var dcfg: Dictionary = combate.cfg.diretor
	var m = mundo.nascer_monstro(str(info.sprite), p, true, 1.0 + float(dcfg.vida_por_min) * minutos, 1.0 + float(dcfg.dano_por_min) * minutos)
	if m == null:
		return null
	marcar(m, md)
	nascidas += 1
	vivas.append(m)
	var nome := "%s %s" % [info.nome, md.nome]
	combate.elite_apareceu(nome, m, Color(md.cor[0], md.cor[1], md.cor[2]))
	return m


## Transforma o monstro `m` em elite com o modificador `md` (dados).
func marcar(m, md: Dictionary) -> void:
	m.virar_no()  # elite é desenhada por nós (poucas e grandes), não pelo lote da horda
	m.elite = true
	m.mod_elite = str(md.id)
	m.cor_elite = Color(md.cor[0], md.cor[1], md.cor[2])
	m.vida_max *= float(cfg.vida_mult) * float(md.get("vida_mult", 1.0))
	m.vida = m.vida_max
	m.dano *= float(cfg.dano_mult)
	m.xp *= float(cfg.xp_mult)
	m.n_orbes += int(cfg.orbes_extra)
	m.vel_mult = float(md.get("vel_mult", 1.0))
	m.emp_mult = float(md.get("empurrao_mult", 1.0))
	m.stun_mult = 0.5
	m.tinta = Color.WHITE.lerp(m.cor_elite, 0.25)
	m.invoca_t = float(md.get("cada", 4.5)) * 0.6
	m.definir_escala(float(cfg.escala))
	dar_contorno(m, m.cor_elite)
	m.garantir_barra_vida_elite()
	if mundo.sombras != null and m.ativo:
		mundo.sombras.atualizar(m, mundo.t)


## O contorno colorido (sprite aditivo na camada glow, criado uma vez por monstro do pool).
func dar_contorno(m, cor: Color) -> void:
	if m.contorno == null:
		var s := Sprite2D.new()
		s.centered = false
		s.region_enabled = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		s.material = mat
		mundo.glow.add_child(s)
		m.contorno = s
	m.contorno.texture = m.tipo.alb
	m.contorno.offset = m.offset
	(m.contorno.material as ShaderMaterial).set_shader_parameter("cor", cor)
	m.contorno.visible = true
	m._sincronizar_contorno()


func _invocar(m) -> void:
	var md: Dictionary = {}
	for e in cfg.modificadores:
		if e.id == "invoca":
			md = e
	m.invoca_t = float(md.cada)
	var lista: Array = _filhos.get(m, [])
	var i := lista.size() - 1
	while i >= 0:
		if not lista[i].vivo:
			lista.remove_at(i)
		i -= 1
	_filhos[m] = lista
	if not m.ativo and m.pos.distance_to(mundo.heroi.pos) > 420.0:
		return  # longe demais para valer a pena
	for k in int(md.n):
		if lista.size() >= int(md.max):
			break
		var a := _rng.randf() * TAU
		var f = mundo.nascer_monstro("inimigo_aranha_tecela" if k % 2 == 0 else "inimigo_cao_ossos", m.pos + Vector2(cos(a), sin(a) * 0.6) * 22.0, true)
		if f != null:
			lista.append(f)
			combate.fx.onda(f.pos, Color(m.cor_elite.r, m.cor_elite.g, m.cor_elite.b, 0.8), 16.0, 0.25)
			combate.fx.estouro(f.pos + Vector2(0, -6), m.cor_elite, 4)


## A elite morreu (o combate chama depois de esconder o monstro): solta o baú e, se for explosiva, o aviso da explosão.
func ao_morrer(m) -> void:
	var cor: Color = m.cor_elite
	if m.mod_elite == "explosivo":
		var md: Dictionary = {}
		for e in cfg.modificadores:
			if e.id == "explosivo":
				md = e
		combate.avisos.com_estilo(combate.avisos.circulo(m.pos, float(md.raio), float(md.aviso), float(md.dano), cor), 2)  # o chão explode (docs/combate_v2)
	combate.baus.soltar(m.pos)
	vivas.erase(m)
	_filhos.erase(m)
	m.elite = false
