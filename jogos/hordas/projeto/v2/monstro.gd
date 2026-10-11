extends "res://v2/ator.gd"
## Monstro da v2: vaga perto de casa e persegue o herói quando ele chega perto (com histerese), ou sempre, se nasceu de uma onda do diretor.
## Tem vida (por tipo, em dados/v2_combate.json), fica atordoado ao apanhar, leva empurrão e dá dano por contato (o contato é resolvido em
## combate.gd). Todo deslocamento passa por mundo.mover(), o ponto único onde a colisão (v2/colisao.gd) age. Quem morre não é apagado: volta
## para o pool do combate e renasce depois (`reviver`), sem criar nó novo.

const VEL_VAGA := 24.0
const VEL_CACA := 54.0
const RAIO_VER := 170.0  # começa a perseguir
const RAIO_PERDER := 250.0  # desiste (maior que RAIO_VER: não fica trocando de estado na borda)
const PARAR_A := 16.0  # chega perto do herói e para
const PASSO_ANIM := 0.16
const AMORTECE_EMP := 9.0  # o empurrão perde força: emp *= exp(-9 dt)

var mundo
var casa := Vector2.ZERO
var raio_vaga := 90.0
var persegue := false
var rng: RandomNumberGenerator
var vivo := true
var cacador := false  # nasceu de uma onda: persegue de qualquer distância
var vida := 20.0
var vida_max := 20.0
var dano := 6.0  # dano por contato
var xp := 1.0
var vel_caca := VEL_CACA
var peso := 1.0  # o empurrão é dividido por ele
var n_orbes := 1
var atordoa_t := 0.0  # sem agir enquanto > 0
var emp := Vector2.ZERO  # empurrão em andamento (px/s)
var recarga := 0.0  # s até poder tirar dano de novo por contato
var sep := Vector2.ZERO  # empurrão de quem está colado nele (px/s), escolhido por combate.gd
var acertos := 0  # quantos golpes levou (testes)
var morrendo := false  # a vida zerou e a morte está na fila do combate (não leva mais dano)
var cd := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])  # por golpe secundário: até quando não leva outro acerto dele
var ultimo_proj := 0  # id do último projétil (onda ou lança) que o acertou: cada um acerta uma vez
var queima_t := 0.0  # s de fogo que faltam
var queima_dps := 0.0
var lento_t := 0.0  # s de lentidão que faltam
var elite := false  # elite: maior, com contorno colorido e um modificador (v2/elites.gd)
var mod_elite := ""
var cor_elite := Color.WHITE
var chefe := false  # mini-chefe ou chefe (v2/chefe.gd manda no movimento)
var vel_ia := Vector2.ZERO  # chefe: a velocidade que o controlador quer (px/s)
var vel_mult := 1.0
var stun_mult := 1.0  # quanto do atordoamento vale (chefe: 0)
var emp_mult := 1.0  # quanto do empurrão vale
var tinta := Color.WHITE  # cor nova do sprite (chefes e elites)
var contorno: Sprite2D = null  # o contorno colorido da elite (camada glow, aditivo)
var invoca_t := 0.0
var escala_base := 1.0
var _base_raio := 7.0
var _queima_tick := 0.0
var _alvo := Vector2.ZERO
var _espera := 0.0
var _anim := 0.0
var _batida := 0.0  # s do "soco" visual (encolhe na vertical) depois de apanhar


func criar(m, pai: Node, nome: String, t: Dictionary, p: Vector2, r: RandomNumberGenerator) -> void:
	mundo = m
	chave = nome
	rng = r
	casa = p
	_alvo = p
	_anim = rng.randf() * 4.0
	_espera = rng.randf_range(0.0, 2.0)
	montar_animado(pai, t, p, 0, rng.randi() % 4, false)


## Põe os números do tipo (dados) e a escala de força da onda.
func aplicar_stats(d: Dictionary, k_vida := 1.0, k_dano := 1.0) -> void:
	vida_max = float(d.get("vida", 20.0)) * k_vida
	vida = vida_max
	dano = float(d.get("dano", 6.0)) * k_dano
	xp = float(d.get("xp", 1.0))
	vel_caca = float(d.get("vel", VEL_CACA))
	raio = float(d.get("raio", 7.0))
	peso = maxf(float(d.get("peso", 1.0)), 0.1)
	n_orbes = int(d.get("orbes", 1))
	_base_raio = raio
	vel_mult = 1.0
	stun_mult = 1.0
	emp_mult = 1.0
	definir_escala(1.0)


## Volta do pool: vivo de novo em `p`, com vida cheia.
func reviver(p: Vector2) -> void:
	vivo = true
	vida = vida_max
	atordoa_t = 0.0
	emp = Vector2.ZERO
	sep = Vector2.ZERO
	recarga = 0.0
	acertos = 0
	_batida = 0.0
	morrendo = false
	cd.fill(0.0)
	ultimo_proj = 0
	queima_t = 0.0
	lento_t = 0.0
	elite = false
	mod_elite = ""
	chefe = false
	vel_ia = Vector2.ZERO
	tinta = Color.WHITE
	invoca_t = 0.0
	sprite.modulate = Color.WHITE
	if contorno != null:
		contorno.visible = false
	persegue = false
	casa = p
	_alvo = p
	_espera = rng.randf_range(0.0, 1.0)
	raiz.visible = true
	sprite.scale = Vector2.ONE
	sprite.position = Vector2.ZERO
	definir_pos(p)
	if olho != null:
		olho.position = raiz.position
		olho.scale = Vector2.ONE


## Tirou dano: vida, atordoamento, empurrão (px/s) e o "soco" visual. Devolve true se morreu. O resto (número, som, partículas) é do combate.
func apanhar(dano_tirado: float, empurrao: Vector2, atordoamento: float) -> bool:
	vida -= dano_tirado
	acertos += 1
	atordoa_t = maxf(atordoa_t, atordoamento * stun_mult)
	emp += empurrao / peso * emp_mult
	_batida = 0.14
	persegue = true
	return vida <= 0.0


func atualizar(dt: float, heroi_pos: Vector2) -> void:
	if recarga > 0.0:
		recarga -= dt
	if queima_t > 0.0:
		_queimar(dt)
	if lento_t > 0.0:
		lento_t -= dt
	var v := Vector2.ZERO
	if atordoa_t > 0.0:
		atordoa_t -= dt
	else:
		v = _ia(dt, heroi_pos)
	var desl := v * dt
	if emp.length_squared() > 4.0:
		desl += emp * dt
		emp *= exp(-AMORTECE_EMP * dt)
	else:
		emp = Vector2.ZERO
	if sep != Vector2.ZERO:
		desl += sep * dt
	if desl != Vector2.ZERO:
		mundo.mover(self, desl)
	if v != Vector2.ZERO:
		_anim += dt
	if not ativo:
		return  # fora da tela não troca quadro nem olho: só a conta de andar
	if _batida > 0.0:
		_batida -= dt
	var k := clampf(_batida / 0.14, 0.0, 1.0)
	sprite.scale = Vector2(1.0 + 0.2 * k, 1.0 - 0.16 * k) * escala
	sprite.position = Vector2(float(rng.randi_range(-1, 1)), 0.0) if (atordoa_t > 0.0 and k > 0.0) else Vector2.ZERO
	var l := 0 if absf(v.x) < absf(v.y) * 0.5 else 1
	var esp := espelha if absf(v.x) < 1.0 else v.x < 0.0
	var c := int(_anim / PASSO_ANIM) % int(tipo.info.colunas.size())
	if v == Vector2.ZERO and atordoa_t > 0.0:
		l = linha
		c = coluna
		esp = espelha
	if l != linha or c != coluna or esp != espelha:
		quadro(c, l, esp, esp != espelha)
	if olho != null:
		olho.position = raiz.position + sprite.position
		olho.scale = sprite.scale
	if contorno != null and contorno.visible:
		_sincronizar_contorno()
	var queimando := queima_t > 0.0
	if queimando or lento_t > 0.0 or tinta != Color.WHITE:
		var cf := tinta
		if queimando:
			cf = cf.lerp(Color(1.5, 0.8, 0.5), 0.55)
		if lento_t > 0.0:
			cf = cf.lerp(Color(0.6, 0.95, 1.4), 0.5)
		sprite.modulate = cf
	elif sprite.modulate != Color.WHITE:
		sprite.modulate = Color.WHITE


## A vontade do monstro: devolve a velocidade (px/s) que ele quer andar.
func _ia(dt: float, heroi_pos: Vector2) -> Vector2:
	var d := heroi_pos - pos
	var dist := d.length()
	if cacador:
		persegue = true
	elif persegue and dist > RAIO_PERDER:
		persegue = false
		_espera = 0.5
	elif not persegue and dist < RAIO_VER:
		persegue = true
	if chefe:
		return vel_ia * (0.5 if lento_t > 0.0 else 1.0)
	var k_vel := vel_mult * (0.45 if lento_t > 0.0 else 1.0)
	if persegue:
		if dist > PARAR_A:
			return d / dist * vel_caca * k_vel
		return Vector2.ZERO
	if _espera > 0.0:
		_espera -= dt
		return Vector2.ZERO
	var ate := _alvo - pos
	if ate.length() < 4.0:
		_espera = rng.randf_range(1.0, 3.0)
		var a := rng.randf() * TAU
		_alvo = casa + Vector2(cos(a), sin(a) * 0.6) * raio_vaga * sqrt(rng.randf())
		return Vector2.ZERO
	return ate.normalized() * VEL_VAGA


# ------------------------------------------------------------------ fogo, lentidão, tamanho e contorno (leva 3)


## Tamanho do monstro (elite e chefe): o sprite, o corpo, o olho, a sombra e o flash crescem juntos, a partir dos pés.
func definir_escala(e: float) -> void:
	escala = e
	raio = _base_raio * e
	if tipo.is_empty():
		return
	esc = e
	alt = float(tipo.pe) * e
	larg_blob = tipo.w * 0.75 * e
	sprite.scale = Vector2.ONE * e
	if olho != null:
		olho.scale = sprite.scale


## Fogo: derrete `dps` de vida por segundo durante `t` s (reaplicar só renova; vale o maior).
func queimar(dps: float, t: float) -> void:
	queima_dps = maxf(queima_dps if queima_t > 0.0 else 0.0, dps)
	queima_t = maxf(queima_t, t)


func deixar_lento(t: float) -> void:
	lento_t = maxf(lento_t, t)


func _queimar(dt: float) -> void:
	queima_t -= dt
	_queima_tick -= dt
	if _queima_tick > 0.0:
		return
	_queima_tick = 0.5
	var c = mundo.combate
	if c == null:
		return
	c.ferir(self, queima_dps * 0.5, Vector2.ZERO, 0.0, 0.0, Color(1.0, 0.6, 0.25), false)
	if ativo:
		for i in maxi(1, roundi(2.0 * c.fx.fator_part)):
			c.fx.particula(
				pos + Vector2(randf_range(-4, 4), -float(alt) * randf_range(0.2, 0.7)), Vector2(randf_range(-8, 8), -28.0), 0.4, 3.0, Color(1.0, 0.55, 0.15, 0.8), -20.0, randf() < 0.4
			)


## Some da tela (morreu ou a partida recomeçou).
func esconder() -> void:
	vivo = false
	raiz.visible = false
	if olho != null:
		olho.visible = false
	if contorno != null:
		contorno.visible = false


func _sincronizar_contorno() -> void:
	contorno.region_rect = regiao
	contorno.flip_h = espelha
	contorno.position = raiz.position + sprite.position
	contorno.scale = sprite.scale
	var tx: Texture2D = tipo.alb
	var r := regiao
	var mat := contorno.material as ShaderMaterial
	mat.set_shader_parameter("reg", Vector4(r.position.x / tx.get_width(), r.position.y / tx.get_height(), r.end.x / tx.get_width(), r.end.y / tx.get_height()))
	mat.set_shader_parameter("brilho", 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008))
