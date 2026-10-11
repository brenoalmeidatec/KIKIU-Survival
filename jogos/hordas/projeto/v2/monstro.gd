extends "res://v2/ator.gd"
## Monstro da v2: vaga perto de casa e persegue o herói quando ele chega perto (com histerese). Sem combate ainda. Todo deslocamento passa
## por mundo.mover(), o ponto único onde a colisão (v2/colisao.gd) vai entrar.

const VEL_VAGA := 24.0
const VEL_CACA := 54.0
const RAIO_VER := 170.0  # começa a perseguir
const RAIO_PERDER := 250.0  # desiste (maior que RAIO_VER: não fica trocando de estado na borda)
const PARAR_A := 16.0  # chega perto do herói e para
const PASSO_ANIM := 0.16

var mundo
var casa := Vector2.ZERO
var raio_vaga := 90.0
var persegue := false
var rng: RandomNumberGenerator
var _alvo := Vector2.ZERO
var _espera := 0.0
var _anim := 0.0


func criar(m, pai: Node, nome: String, t: Dictionary, p: Vector2, r: RandomNumberGenerator) -> void:
	mundo = m
	chave = nome
	rng = r
	casa = p
	_alvo = p
	_anim = rng.randf() * 4.0
	_espera = rng.randf_range(0.0, 2.0)
	montar_animado(pai, t, p, 0, rng.randi() % 4, false)


func atualizar(dt: float, heroi_pos: Vector2) -> void:
	var d := heroi_pos - pos
	var dist := d.length()
	if persegue and dist > RAIO_PERDER:
		persegue = false
		_espera = 0.5
	elif not persegue and dist < RAIO_VER:
		persegue = true
	var v := Vector2.ZERO
	if persegue:
		if dist > PARAR_A:
			v = d / dist * VEL_CACA
	elif _espera > 0.0:
		_espera -= dt
	else:
		var ate := _alvo - pos
		if ate.length() < 4.0:
			_espera = rng.randf_range(1.0, 3.0)
			var a := rng.randf() * TAU
			_alvo = casa + Vector2(cos(a), sin(a) * 0.6) * raio_vaga * sqrt(rng.randf())
		else:
			v = ate.normalized() * VEL_VAGA
	if v != Vector2.ZERO:
		mundo.mover(self, v * dt)
		_anim += dt
	if not ativo:
		return  # fora da tela não troca quadro nem olho: só a conta de andar
	var l := 0 if absf(v.x) < absf(v.y) * 0.5 else 1
	var esp := espelha if absf(v.x) < 1.0 else v.x < 0.0
	var c := int(_anim / PASSO_ANIM) % int(tipo.info.colunas.size())
	if l != linha or c != coluna or esp != espelha:
		quadro(c, l, esp, esp != espelha)
	if olho != null:
		olho.position = raiz.position
