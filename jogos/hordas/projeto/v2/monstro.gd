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
	atordoa_t = maxf(atordoa_t, atordoamento)
	emp += empurrao / peso
	_batida = 0.14
	persegue = true
	return vida <= 0.0


func atualizar(dt: float, heroi_pos: Vector2) -> void:
	if recarga > 0.0:
		recarga -= dt
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
	sprite.scale = Vector2(1.0 + 0.2 * k, 1.0 - 0.16 * k)
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
	if persegue:
		if dist > PARAR_A:
			return d / dist * vel_caca
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
