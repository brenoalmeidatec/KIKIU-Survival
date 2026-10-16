extends RefCounted
## Mini-chefes (aos 3 e aos 6 min) e chefe (aos 10 min) da v2 (leva 3). Usam o sprite de um monstro do protótipo, em escala maior e com cor
## nova (arte própria fica para depois). Têm muita vida, não levam empurrão nem atordoamento e atacam sempre ANUNCIANDO: uma área no chão
## pisca (v2/avisos.gd) por ~1 s antes do dano, então dá para sair ou esquivar.
##   estouro   = um círculo grande sob o herói;   chuva = vários círculos pequenos em volta dele, um atrás do outro;
##   investida = uma faixa avisa o caminho e o chefe corre por ela.
## Abaixo de `fase2` da vida o chefe fica mais rápido e a chuva ganha círculos. Vencer o CHEFE é a vitória da partida. Os números ficam em
## dados/v2_cartas.json > "chefes". O mundo expõe os sinais chefe_apareceu(nome, vida_max) e chefe_vida(vida) para o HUD.

var combate
var mundo
var cfg: Dictionary = {}
var atual = null  # o monstro-chefe em campo (ou null)
var marca: Dictionary = {}  # os dados da marca em campo
var vivo := false
var feitos := {}  # id da marca -> true (já nasceu)
var derrotados := 0  # chefes e mini-chefes mortos (testes)
var estado := "andar"  # andar, aviso, investida, recupera
var ataques_feitos := 0  # quantos ataques anunciados saíram (testes)
var t_estado := 0.0
var _prox_ataque := 2.0
var _ataque := ""
var _fila_ataques := 0
var _dir := Vector2.RIGHT
var _faixa := -1
var _chuva_n := 0
var _chuva_t := 0.0
var _chuva_dur := 0.0
var _idx_ataque := 0
var _vida_enviada := -1.0
var _t_vida := 0.0
var _fase2 := false
var luz: PointLight2D


func montar(c) -> void:
	combate = c
	mundo = c.mundo
	cfg = c.cartas.cfg.chefes
	luz = PointLight2D.new()  # o chefe é escuro: uma luz da cor dele em volta o deixa legível na floresta
	luz.texture = c.armas.luz_fogo.texture
	luz.enabled = false
	luz.shadow_enabled = false
	luz.height = 30.0
	mundo.sv.add_child(luz)
	zerar()


func zerar() -> void:
	if luz != null:
		luz.enabled = false
	atual = null
	marca = {}
	vivo = false
	feitos.clear()
	derrotados = 0
	estado = "andar"
	ataques_feitos = 0
	_vida_enviada = -1.0
	_fase2 = false


func atualizar(dt: float) -> void:
	var t: float = mundo.tempo_partida
	if atual == null:
		for mk in cfg.marcas:
			if not feitos.has(mk.id) and t >= float(mk.tempo) * mundo.fator_pesadelo("chefe_tempo_mult"):
				nascer(mk)
				break
		return
	if not atual.vivo:
		return
	luz.position = (atual.pos + Vector2(0, -float(atual.alt) * 0.5)).round()
	luz.energy = 1.0 + 0.2 * sin(mundo.t * 6.0)
	_ia(dt)
	_t_vida -= dt
	if _t_vida <= 0.0 and atual.vida != _vida_enviada:
		_t_vida = 0.05
		_vida_enviada = atual.vida
		mundo.chefe_vida.emit(maxf(atual.vida, 0.0))


## Faz nascer a marca `mk` (dados) fora da tela. Devolve o monstro.
func nascer(mk: Dictionary, onde: Variant = null):
	var p: Variant = onde if onde != null else combate.diretor.ponto_fora_da_tela()
	if p == null:
		var h = mundo.heroi
		p = (h.pos + Vector2(260, 0)).clamp(mundo.limite_andavel.position, mundo.limite_andavel.end)
	var m = mundo.nascer_monstro(str(mk.tipo), p, true)
	feitos[mk.id] = true
	marca = mk
	atual = m
	vivo = true
	m.virar_no()  # chefe é desenhado por nós, não pelo lote da horda
	m.chefe = true
	m.vida_max = float(mk.vida) * mundo.fator_pesadelo("vida_mult")
	m.vida = m.vida_max
	m.dano = float(mk.dano) * mundo.fator_pesadelo("dano_mult")
	m.vel_caca = float(mk.vel)
	m.xp = float(mk.xp)
	m.n_orbes = int(mk.orbes)
	m.peso = 20.0
	m.stun_mult = 0.0
	m.emp_mult = 0.05
	m._base_raio = float(mk.raio) / float(mk.escala)
	m.definir_escala(float(mk.escala))
	m.tinta = Color(mk.tinta[0] * 1.5, mk.tinta[1] * 1.5, mk.tinta[2] * 1.5)  # >1: clareia o sprite escuro
	var cor := Color(mk.cor[0], mk.cor[1], mk.cor[2])
	luz.color = cor
	luz.texture_scale = (110.0 + 36.0 * float(mk.escala)) / 128.0
	luz.enabled = true
	m.cor_elite = cor
	combate.elites.dar_contorno(m, cor)
	estado = "andar"
	_prox_ataque = 2.2
	_ataque = ""
	_fila_ataques = 0
	_idx_ataque = 0
	_fase2 = false
	_vida_enviada = -1.0
	_t_vida = 0.0
	combate.chefe_apareceu(m, mk)
	return m


func _intervalo() -> float:
	return float(marca.intervalo) * (0.7 if _fase2 else 1.0)


func _ia(dt: float) -> void:
	var m = atual
	var h = mundo.heroi
	if not _fase2 and m.vida < m.vida_max * float(cfg.fase2):
		_fase2 = true
		m.vel_caca *= 1.25
		combate.anunciar("FÚRIA!", Color(1.0, 0.3, 0.25), "", 1.6)
		combate.audio.tocar("chefe", 0.8, 0.0, 0.2)
		combate.fx.onda(m.pos, Color(1.0, 0.3, 0.25, 0.9), 90.0, 0.5)
		mundo.cam.tremer(3.0, 0.3)
	t_estado += dt
	var d: Vector2 = h.pos - m.pos
	var dist := d.length()
	match estado:
		"andar":
			m.vel_ia = d / maxf(dist, 1.0) * m.vel_caca if dist > 22.0 else Vector2.ZERO
			_prox_ataque -= dt
			if _prox_ataque <= 0.0 and h.vivo():
				_comecar_ataque()
		"aviso":
			m.vel_ia = Vector2.ZERO
			if _ataque != "chuva":  # a chuva dura vários círculos: a carga ficaria no máximo o tempo todo
				m.carga = clampf(t_estado / float(cfg.ataques[_ataque].aviso), 0.0, 1.0)
			if _ataque == "chuva":
				_chuva(dt)
			elif t_estado >= float(cfg.ataques[_ataque].aviso) + 0.05:
				m.carga = 0.0
				if _ataque == "investida":
					estado = "investida"
					t_estado = 0.0
					combate.audio.tocar("chefe", 1.3, 0.0, 0.1)
				else:
					_terminou_ataque()
		"investida":
			var at: Dictionary = cfg.ataques.investida
			m.vel_ia = _dir * float(at.vel)
			if t_estado >= float(at.compr) / float(at.vel):
				_terminou_ataque()
			elif h.vulneravel() and _encostou(h):
				h.levar_dano(float(at.dano), m.pos, m)
		"recupera":
			m.vel_ia = Vector2.ZERO
			if t_estado >= 0.7:
				estado = "andar"
				t_estado = 0.0


## O corpo do chefe encostou no herói (a elipse do chão)?
func _encostou(h) -> bool:
	var m = atual
	var rel: Vector2 = h.pos - m.pos
	return Vector2(rel.x, rel.y / 0.62).length() < m.raio + h.raio + 6.0


func _comecar_ataque() -> void:
	var lista: Array = marca.ataques
	_ataque = str(lista[_idx_ataque % lista.size()])
	_idx_ataque += 1
	var at: Dictionary = cfg.ataques[_ataque]
	var m = atual
	var h = mundo.heroi
	estado = "aviso"
	t_estado = 0.0
	ataques_feitos += 1
	var cor: Color = m.cor_elite
	combate.audio.tocar("aviso", 1.0, -2.0, 0.1)
	if _ataque != "chuva":  # na chuva há vários círculos, o retículo só confundiria
		combate.avisos.reticulo(float(at.get("raio", 40.0)), float(at.aviso))
	match _ataque:
		"estouro":
			combate.avisos.circulo(h.pos, float(at.raio), float(at.aviso), float(at.dano), cor)
			if _fase2:  # na fúria, um segundo círculo logo ao lado
				var lado := Vector2.from_angle(randf() * TAU) * float(at.raio) * 1.4
				combate.avisos.circulo(h.pos + lado, float(at.raio), float(at.aviso) + 0.25, float(at.dano), cor)
		"chuva":
			_chuva_n = int(at.n) + (3 if _fase2 else 0)
			_chuva_t = 0.0
			_chuva_dur = float(_chuva_n) * float(at.intervalo) + float(at.aviso) + 0.1
		"investida":
			var d: Vector2 = h.pos - m.pos
			d = d if d.length() > 1.0 else Vector2.RIGHT
			var dg := Vector2(d.x, d.y / 0.62).normalized()  # direção no chão
			_dir = Vector2(dg.x, dg.y * 0.62)  # a mesma direção na tela: o chefe corre por cima da faixa
			_faixa = combate.avisos.faixa(m.pos, d, float(at.compr), float(at.larg), float(at.aviso), 0.0, cor)
	_prox_ataque = _intervalo()


func _chuva(dt: float) -> void:
	var at: Dictionary = cfg.ataques.chuva
	_chuva_t -= dt
	if _chuva_n > 0 and _chuva_t <= 0.0:
		_chuva_t = float(at.intervalo)
		_chuva_n -= 1
		var h = mundo.heroi
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * float(at.espalha)
		if _chuva_n % 2 == 0:
			off *= 0.3  # metade cai perto do herói
		var p: Vector2 = (h.pos + off).clamp(mundo.limite_andavel.position, mundo.limite_andavel.end)
		combate.avisos.circulo(p, float(at.raio), float(at.aviso), float(at.dano), atual.cor_elite)
		combate.audio.tocar("aviso", 1.3, -6.0, 0.05)
	if _chuva_n <= 0 and t_estado >= _chuva_dur:
		_terminou_ataque()


func _terminou_ataque() -> void:
	if atual != null:
		atual.carga = 0.0
	estado = "recupera"
	t_estado = 0.0
	_ataque = ""


## O chefe morreu (o combate chama depois de esconder o monstro).
func ao_morrer(m) -> void:
	if m != atual:
		return
	var mk := marca
	m.carga = 0.0
	atual = null
	vivo = false
	luz.enabled = false
	derrotados += 1
	mundo.chefe_vida.emit(0.0)
	if bool(mk.mini):
		combate.baus.soltar(m.pos, 1.0, 3)
		combate.anunciar("MINI-CHEFE DERROTADO!", Color(1.0, 0.85, 0.4), str(mk.nome), 2.2)
		combate.audio.tocar("nivel", 0.8, 0.0, 0.2)
	else:
		combate.vitoria()
