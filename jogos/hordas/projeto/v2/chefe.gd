extends RefCounted
## Mini-chefes e o CHEFÃO da v2. Nascem nos níveis de chefe do mapa (dados/v2_niveis.json, contados por v2/diretor.gd: na Floresta, nos
## níveis 10 e 20 e o chefão no 30). Usam o sprite 2D de um monstro do protótipo em escala maior, com cor nova, e cada MARCA tem identidade
## própria: um ataque que só ela usa e uma aparência feita em código (v2/chefe_visual.gd: capa, pluma, teia, coroa, corvos, brasas, luz da cor
## dela). Têm muita vida, não levam empurrão nem atordoamento e atacam sempre ANUNCIANDO: uma área no chão pisca (v2/avisos.gd) por ~1 s
## antes do dano, então dá para sair ou esquivar.
##   comuns:   estouro = um círculo grande sob o herói;   chuva = vários círculos pequenos em volta dele, um atrás do outro;
##             investida = uma faixa avisa o caminho e o chefe corre por ela.
##   próprios: leque (Devorador da Carne) = um setor de golpe de lâmina voltado para o herói (na fúria, um segundo para o lado oposto);
##             teia (Devoradora da Estrutura) = um círculo de teia que, ao disparar, deixa o herói lento e solta filhotes de aranha;
##             revoada (Devorador da Terra, o chefão) = faixas paralelas que partem dele, uma por cima do herói, varridas por corvos no disparo.
## Abaixo de `fase2` da vida o chefe fica mais rápido e os ataques crescem (chuva com mais círculos, segundo leque, mais filhotes e faixas). Vencer o
## CHEFE é a vitória da partida. As fichas (marcas) ficam em dados/v2_cartas.json > "chefes" (os ataques em "ataques", a lista de cada marca em
## "marcas" > "ataques" e a aparência em "visual"); o diretor copia a marca com a vida do mapa e mini = false só no último nível. O mundo expõe os
## sinais chefe_apareceu(nome, vida_max) e chefe_vida(vida) para o HUD, que mostra o nome e a barra; o combate anuncia "MINI-CHEFE: nome" ou "CHEFE: nome".

const Anim := preload("res://v2/anim_golpes.gd")  # as folhas dos ataques inimigos (docs/combate_v2)
const Visual := preload("res://v2/chefe_visual.gd")  # a aparência de cada marca
const TINTA_FILHOTE := Color(0.7, 1.0, 0.6)  # a cor dos filhotes da Rainha (quem renasce comum volta ao branco: não conta mais)

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
var _poeira_t := 0.0  # s até a próxima poeira da investida
var _aviso_dur := 0.0  # s do aviso do ataque em curso (o segundo golpe do leque, na fúria, estica)
var _filhotes: Array = []  # os filhotes da Rainha em campo
var _teia_t := 0.0  # s de lentidão que faltam no herói (a teia da Rainha); `_teia_mult` é a fração da velocidade dele enquanto dura
var _teia_mult := 0.5
var _teia_marca_t := 0.0  # s até a próxima partícula de teia no herói lento
var _h_antes := Vector2.ZERO  # onde o herói estava no fim do quadro anterior (a lentidão corta o que ele andou)
var visual
var _idx_ataque := 0
var _vida_enviada := -1.0
var _t_vida := 0.0
var _fase2 := false
var luz: PointLight2D


func montar(c) -> void:
	combate = c
	mundo = c.mundo
	cfg = c.cartas.cfg.chefes
	visual = Visual.new()
	visual.montar(self, c)
	luz = PointLight2D.new()  # o chefe é escuro: uma luz da cor dele em volta o deixa legível na floresta
	luz.texture = c.armas.luz_fogo.texture
	luz.enabled = false
	luz.shadow_enabled = false
	luz.height = 30.0
	mundo.sv.add_child(luz)
	zerar()


## Sai da partida (combate.liberar): o visual aponta de volta para este controlador, então é preciso soltá-lo para nenhum dos dois ficar vivo.
func liberar() -> void:
	if visual != null:
		visual.liberar()
		visual = null
	combate = null
	mundo = null


func zerar() -> void:
	if luz != null:
		luz.enabled = false
	if visual != null:
		visual.desligar()
	_filhotes.clear()
	_teia_t = 0.0
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
	visual.atualizar(dt)  # os corvos da revoada ainda voam um instante depois do disparo
	_teia_atualizar(dt)  # a lentidão da teia dura além do chefe
	if atual == null:
		return  # quem faz o chefe nascer é o nível do mapa (diretor.avancar_nivel)
	if not atual.vivo:
		return
	luz.position = (atual.pos + Vector2(0, -float(atual.alt) * 0.5)).round()
	luz.energy = (1.0 + 0.2 * sin(mundo.t * 6.0)) * visual.luz_mult
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
	m.vel_caca = float(mk.vel) * preload("res://v2/dificuldade.gd").fator(mundo, "vel_mult")
	m.xp = float(mk.xp)  # XP base: combate.coletar aplica o bônus da dificuldade só à progressão do herói
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
	visual.ligar(m, mk)
	estado = "andar"
	_prox_ataque = 2.2
	_ataque = ""
	_fila_ataques = 0
	_idx_ataque = 0
	_fase2 = false
	_vida_enviada = -1.0
	_t_vida = 0.0
	combate.chefe_apareceu(m, mk)
	if not bool(mk.mini):  # o chefão entra com mais peso: duas ondas a mais e a câmera treme
		combate.fx.onda(m.pos, Color(cor.r, cor.g, cor.b, 0.8), 190.0, 1.0)
		combate.fx.onda(m.pos, Color(1.0, 0.85, 0.4, 0.6), 260.0, 1.3)
		mundo.cam.tremer(5.0, 0.7)
	return m


## O aviso `i` é meu: se eu morrer antes de ele disparar, `ao_morrer` o cancela (os avisos da elite e de outras fontes ficam).
func _meu(i: int) -> int:
	return combate.avisos.de(i, self)


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
				m.carga = clampf(t_estado / _aviso_dur, 0.0, 1.0)
			if _ataque == "chuva":
				_chuva(dt)
			elif t_estado >= _aviso_dur + 0.05:
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
			_poeira_t -= dt
			if _poeira_t <= 0.0:  # a investida levanta poeira atrás do chefe (folha perigo_investida, pool de efeitos das armas)
				_poeira_t = 0.07
				var fp: Dictionary = Anim.de("perigo_investida").get("impacto", {})
				if not fp.is_empty() and combate.armas != null:
					combate.armas.novas.tocar_fx(fp, m.pos - _dir.normalized() * 10.0)
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
	_aviso_dur = float(at.aviso)
	combate.audio.tocar("aviso", 1.0, -2.0, 0.1)
	if _ataque == "estouro" or _ataque == "investida":  # chuva, leque, teia e revoada já se anunciam por vários círculos ou pela própria área: o retículo só confundiria
		combate.avisos.reticulo(float(at.get("raio", 40.0)), float(at.aviso))
	match _ataque:
		"estouro":
			combate.avisos.com_estilo(_meu(combate.avisos.circulo(h.pos, float(at.raio), float(at.aviso), float(at.dano), cor)), 2)  # o chão explode (docs/combate_v2)
			if _fase2:  # na fúria, um segundo círculo logo ao lado
				var lado := Vector2.from_angle(randf() * TAU) * float(at.raio) * 1.4
				combate.avisos.com_estilo(_meu(combate.avisos.circulo(h.pos + lado, float(at.raio), float(at.aviso) + 0.25, float(at.dano), cor)), 2)
		"chuva":
			_chuva_n = int(at.n) + (3 if _fase2 else 0)
			_chuva_t = 0.0
			_chuva_dur = float(_chuva_n) * float(at.intervalo) + float(at.aviso) + 0.1
		"leque":
			_leque(at)
		"teia":
			_teia(at)
		"revoada":
			_revoada(at)
		"investida":
			var d: Vector2 = h.pos - m.pos
			d = d if d.length() > 1.0 else Vector2.RIGHT
			var dg := Vector2(d.x, d.y / 0.62).normalized()  # direção no chão
			_dir = Vector2(dg.x, dg.y * 0.62)  # a mesma direção na tela: o chefe corre por cima da faixa
			_faixa = _meu(combate.avisos.faixa(m.pos, d, float(at.compr), float(at.larg), float(at.aviso), 0.0, cor))
	_prox_ataque = _intervalo()


## O LEQUE do Devorador da Carne: um golpe de lâmina em setor voltado para o herói. Na fúria a lâmina gira: logo depois vem um segundo, para o lado oposto.
func _leque(at: Dictionary) -> void:
	var m = atual
	var d: Vector2 = mundo.heroi.pos - m.pos
	d = d if d.length() > 1.0 else Vector2.RIGHT
	_meu(combate.avisos.setor(m.pos, d, float(at.raio), float(at.abertura), float(at.aviso), float(at.dano), m.cor_elite))
	if _fase2:
		_aviso_dur += 0.3
		_meu(combate.avisos.setor(m.pos, -d, float(at.raio), float(at.abertura), _aviso_dur, float(at.dano), m.cor_elite))


## A TEIA da Devoradora da Estrutura: um círculo de teia sobre o herói; ao disparar, quem está dentro fica lento e a teia solta filhotes de aranha.
func _teia(at: Dictionary) -> void:
	var centro: Vector2 = mundo.heroi.pos
	var i: int = _meu(combate.avisos.circulo(centro, float(at.raio), float(at.aviso), float(at.dano), atual.cor_elite, _teia_disparou.bind(centro, at)))
	combate.avisos.com_estilo(i, 3)


func _teia_disparou(centro: Vector2, at: Dictionary) -> void:
	var h = mundo.heroi
	var achata: float = combate.avisos.ACHATA
	if combate.avisos.acertou:  # a mesma regra do dano: quem esquivou (i-frames) ou já estava invulnerável não fica preso. Os filhotes nascem de qualquer jeito
		_teia_t = float(at.lento)
		_teia_mult = float(at.lento_mult)
		combate.fx.flash(h, 0.35, Color(0.6, 1.0, 0.5), 0, 0.8)
	_filhotes = _filhotes.filter(func(f): return f.vivo and f.tinta == TINTA_FILHOTE)
	var n := int(at.filhotes_fase2 if _fase2 else at.filhotes)
	for k in n:
		if _filhotes.size() >= int(at.max_filhotes):
			break
		var a := TAU * (float(k) + randf()) / float(n)
		var p: Vector2 = (centro + Vector2(cos(a), sin(a) * achata) * float(at.raio) * 0.9).clamp(mundo.limite_andavel.position, mundo.limite_andavel.end)
		var f = mundo.nascer_monstro(str(at.filhote), p, true)
		f.tinta = TINTA_FILHOTE
		_filhotes.append(f)
		combate.fx.estouro(p + Vector2(0, -4), Color(0.6, 1.0, 0.5), 5)


## A lentidão por desfazer deslocamento é provisória: ela vai morar em v2/heroi.gd num PR depois do #351 (travado pela #348) e esta função some.
## Enquanto o herói está lento pela teia, o que ele andou a pé no quadro (andando ou correndo, nunca na esquiva, no golpe ou na carga) é cortado para
## `_teia_mult` e fios verdes sobem dos pés dele (o aviso de que está preso). Fica aqui, no chefe, e não no herói: é um efeito só da Rainha.
func _teia_atualizar(dt: float) -> void:
	var h = mundo.heroi
	if _teia_t <= 0.0:
		_h_antes = h.pos
		return
	_teia_t -= dt
	if h.estado == h.Estado.LIVRE and h.vivo():
		var andou: Vector2 = h.pos - _h_antes
		if andou.length_squared() > 0.0001 and andou.length() < 40.0:  # um salto grande é teleporte, não passo
			mundo.mover(h, -andou * (1.0 - _teia_mult))
	_h_antes = h.pos
	_teia_marca_t -= dt
	if _teia_marca_t <= 0.0:
		_teia_marca_t = 0.12
		combate.fx.particula(
			h.pos + Vector2(randf_range(-6, 6), -randf_range(0, 10)),
			Vector2(randf_range(-4, 4), -randf_range(6, 16)),
			0.5,
			2.0,
			Color(0.85, 1.0, 0.8, 0.9),
			-6.0,
			true
		)


## A REVOADA do Devorador da Terra: faixas paralelas que partem dele na direção do herói (uma por cima do herói, as outras dos lados, com vãos entre elas
## onde dá para ficar); no disparo os corvos varrem as faixas e quem está nelas apanha.
func _revoada(at: Dictionary) -> void:
	var m = atual
	var achata: float = combate.avisos.ACHATA
	var d: Vector2 = mundo.heroi.pos - m.pos
	d = d if d.length() > 1.0 else Vector2.RIGHT
	var g := Vector2(d.x, d.y / achata).normalized()  # direção no chão
	var perp := Vector2(-g.y, g.x)
	var n := int(at.linhas_fase2 if _fase2 else at.linhas)
	var compr := maxf(float(at.compr), Vector2(d.x, d.y / achata).length() + 120.0)
	for k in n:
		var off := (float(k) - float(n - 1) * 0.5) * float(at.espaco)
		var o: Vector2 = m.pos + Vector2(perp.x * off, perp.y * off * achata) + Vector2(g.x, g.y * achata) * 20.0
		_meu(combate.avisos.faixa(o, d, compr, float(at.larg), float(at.aviso), float(at.dano), m.cor_elite, visual.revoada.bind(o, g, compr, float(at.larg))))


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
		combate.avisos.com_estilo(_meu(combate.avisos.circulo(p, float(at.raio), float(at.aviso), float(at.dano), atual.cor_elite)), 1)  # a pedra cai do céu
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
	combate.avisos.cancelar(self)  # a revoada, a teia e o resto pendentes não saem depois da morte (nem na câmera lenta da vitória)
	combate.avisos.ret_t = 9.0
	atual = null
	vivo = false
	luz.enabled = false
	visual.desligar()
	derrotados += 1
	mundo.chefe_vida.emit(0.0)
	if bool(mk.mini):
		combate.baus.soltar(m.pos, 1.0, 3)
		combate.anunciar("MINI-CHEFE DERROTADO!", Color(1.0, 0.85, 0.4), str(mk.nome), 2.2)
		combate.audio.tocar("nivel", 0.8, 0.0, 0.2)
	else:
		combate.vitoria()
