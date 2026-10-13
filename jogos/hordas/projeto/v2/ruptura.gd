extends RefCounted
## A RUPTURA da v2 (tecla E ou LB do controle; o botão direito é o secundário, o escudo: v2/escudo.gd): segura para carregar, solta para rachar o chão em 360 graus em volta do herói.
## Dano, atordoamento e empurrão em tudo dentro da elipse do chão (a mesma dos avisos e das sombras), sem mira. É a resposta ao cerco: a
## katana cobre um arco na frente, a ruptura alcança a fila de trás. Depois de um disparo que acertou, a katana causa mais dano por um instante
## (contragolpe): a ruptura abre, o combo de 3 fecha.
##
## O herói (v2/heroi.gd) cuida da entrada e do estado (Estado.CARGA: carregar, soltar, cancelar, recarga); este módulo cuida do disparo
## (geometria, dano, controle, cartas, eco), do visual e do som. Dono: o combate (`combate.ruptura`). Tudo em dados/v2_ruptura.json (veja o
## `_ajuda` de lá): nenhum número de jogo fica fixo aqui. Nenhum nó por monstro nem por quadro: um Node2D aditivo na camada glow, redesenhado
## só enquanto há algo ativo (carga, anel, rachadura).
##
## API (herói e combate chamam; os testes também): montar(c, camada), limpar(), definir(chave, soma) [as cartas], carga_max(h),
## raio_de/dano_de/atordoa_de/empurrao_de/recarga_de, disparar(h, f, perfeito) -> acertos, tique(h, i), pronta(h), negou(h), cancelou(h),
## fator_contragolpe(h), atualizar(dt) [tempo do mundo: o eco], efeitos(dt) [relógio de parede: o visual], resumo() e linha() [painel de status].

const Armas := preload("res://v2/armas.gd")
const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x
const COR_LARANJA := Color(1.0, 0.55, 0.2)
const COR_OURO := Color(1.0, 0.85, 0.3)
const COR_CINZA := Color(0.6, 0.6, 0.6)
const COR_NUM := Color(1.0, 0.96, 0.84)
const COR_CRIT := Color(1.0, 0.74, 0.2)
const COR_POEIRA := Color(0.58, 0.5, 0.42, 0.75)
const PTS := 44  # pontos da elipse desenhada
const MAX_ANEIS := 12
const MAX_RACH := 2  # disparos com rachadura ao mesmo tempo
const FISSURAS := 9
const PONTOS_FISSURA := 6
const RACH_DUR := 0.7  # s da rachadura (brilho laranja que escurece para vermelho)

var combate
var mundo
var cfg: Dictionary = {}  # os números de agora: dados/v2_ruptura.json > ruptura, com a troca do herói (> herois > chave dele) por cima
var trocas: Dictionary = {}  # dados/v2_ruptura.json > herois: por chave de herói, só o que muda (os testes mexem aqui)
var _base: Dictionary = {}  # dados/v2_ruptura.json > ruptura, como está no arquivo
var _cfg_chave := ""  # de que herói são os números de `cfg`
var no: Node2D
var somas := {"dano": 0.0, "recarga": 0.0, "atordoa": 0.0, "contra": 0.0, "eco": 0.0}  # o que as cartas somaram (em %)
var ultimo: Dictionary = {}  # o último disparo (testes): n (acertos), f, raio, dano (base, sem variação), atordoa, perfeito, mortes
var disparos := 0
var ecos := 0

# anéis (onda de choque, anel branco, dourado, cinza do cancelamento, anel de "pronta"): pool em vetores planos
var a_vivo := PackedByteArray()
var a_pos := PackedVector2Array()
var a_t := PackedFloat32Array()
var a_dur := PackedFloat32Array()
var a_r0 := PackedFloat32Array()
var a_r1 := PackedFloat32Array()
var a_w0 := PackedFloat32Array()
var a_w1 := PackedFloat32Array()
var a_alfa := PackedFloat32Array()
var a_cor := PackedColorArray()
var _ai := 0
# rachaduras: por disparo, 9 fissuras de 6 pontos
var r_ativa := PackedByteArray()
var r_t := PackedFloat32Array()
var r_pts: Array = []
var _ri := 0

var _eco_t := -1.0  # s até o eco (< 0: nenhum pendente)
var _eco_raio := 0.0
var _eco_dano := 0.0
var _eco_emp := 0.0
var _brasa_t := 0.0
var _desenhou := false
# alvos do pulso em andamento (reaproveitados: nada de Array novo por disparo)
var _hit_m: Array = []
var _hit_d := PackedFloat32Array()
var _hit_dn := PackedInt32Array()
var _hit_crit := PackedByteArray()
var _hit_fora := PackedVector2Array()
var _mortes := 0
var _explosoes := 0


func montar(c, camada: Node) -> void:
	combate = c
	mundo = c.mundo
	var d: Dictionary = Dados.json("v2_ruptura")
	_base = d.ruptura
	trocas = d.get("herois", {})
	cfg = _base
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	no = Node2D.new()
	no.material = mat
	no.draw.connect(_desenhar)
	camada.add_child(no)
	a_vivo.resize(MAX_ANEIS)
	a_pos.resize(MAX_ANEIS)
	a_t.resize(MAX_ANEIS)
	a_dur.resize(MAX_ANEIS)
	a_r0.resize(MAX_ANEIS)
	a_r1.resize(MAX_ANEIS)
	a_w0.resize(MAX_ANEIS)
	a_w1.resize(MAX_ANEIS)
	a_alfa.resize(MAX_ANEIS)
	a_cor.resize(MAX_ANEIS)
	r_ativa.resize(MAX_RACH)
	r_t.resize(MAX_RACH)
	r_pts.resize(MAX_RACH)


## Partida nova: bônus das cartas, eco pendente, anéis e rachaduras zerados.
func limpar() -> void:
	for k in somas:
		somas[k] = 0.0
	ultimo = {}
	disparos = 0
	ecos = 0
	_eco_t = -1.0
	_brasa_t = 0.0
	a_vivo.fill(0)
	r_ativa.fill(0)
	for i in MAX_RACH:
		r_pts[i] = null
	if no != null:
		no.queue_redraw()
	_desenhou = false


## Põe os números do herói `chave`: a base com a troca dele (dados > herois > chave) por cima. Chave que não está em `herois` fica com a base.
## Um bloco (perfeito, contragolpe, chefe, eco) troca só as chaves que a troca traz; um par ([min, max]) ou um número troca inteiro. O herói
## é o mesmo script para todos (Hazaki, Nicão, Lucas...): quem quiser uma ruptura diferente (ou mais fraca) só escreve a troca nos dados.
func para_heroi(chave: String) -> void:
	if chave == _cfg_chave:
		return
	_cfg_chave = chave
	var troca: Dictionary = trocas.get(chave, {})
	if troca.is_empty():
		cfg = _base
		return
	cfg = _base.duplicate(true)
	for k in troca:
		if cfg.get(k) is Dictionary and troca[k] is Dictionary:
			cfg[k].merge(troca[k], true)
		else:
			cfg[k] = troca[k]


## As cartas somam aqui: `chave` = dano, recarga, atordoa, contra ou eco; `soma` = total acumulado em %.
func definir(chave: String, soma: float) -> void:
	if somas.has(chave):
		somas[chave] = soma


# ------------------------------------------------------------------ os números (tudo dos dados)


## lerp de um par [carga mínima, carga cheia] dos dados com f de 0 a 1.
func _par(nome: String, f: float) -> float:
	var a: Array = cfg[nome]
	return lerpf(float(a[0]), float(a[1]), clampf(f, 0.0, 1.0))


## Tempo até a carga cheia: o Punho ligeiro encurta, com piso.
func carga_max(h) -> float:
	return maxf(float(cfg.carga_piso), float(cfg.carga_max) / maxf(h.m_vel_ataque, 0.01))


func raio_de(h, f: float, perfeito: bool) -> float:
	var r: float = _par("raio", f) * (1.0 + (float(h.m_area) - 1.0) * float(cfg.area_k))
	return r * float(cfg.perfeito.raio) if perfeito else r


## Dano base por alvo (antes da variação e do crítico).
func dano_de(h, f: float, perfeito: bool) -> float:
	var d: float = _par("dano", f) * float(h.m_dano) * (1.0 + float(somas.dano) / 100.0)
	return d * float(cfg.perfeito.dano) if perfeito else d


func atordoa_de(f: float, perfeito: bool) -> float:
	var a := _par("atordoa", f) * (1.0 + float(somas.atordoa) / 100.0)
	if perfeito:
		a += float(cfg.perfeito.atordoa_mais)
	return minf(a, float(cfg.atordoa_max))


func empurrao_de(f: float) -> float:
	return _par("empurrao", f)


func recarga_de(perfeito: bool) -> float:
	var r := float(cfg.recarga) * (1.0 - minf(float(somas.recarga) / 100.0, float(cfg.recarga_cartas_max)))
	if perfeito:
		r -= float(cfg.perfeito.recarga_menos)
	return maxf(r, float(cfg.recarga_piso))


func bonus_contragolpe() -> float:
	return minf(float(cfg.contragolpe.bonus) + float(somas.contra) / 100.0, float(cfg.contragolpe.bonus_max))


## Multiplicador do golpe direto da katana (combate.golpear): vale enquanto a janela do contragolpe do herói está aberta.
func fator_contragolpe(h) -> float:
	return 1.0 + bonus_contragolpe() if h.contragolpe_t > 0.0 else 1.0


# ------------------------------------------------------------------ o disparo


## Solta a ruptura com a carga `f` (0 a 1). Atinge tudo dentro da elipse do chão em volta do herói (elite e chefe entram; o herói nunca é
## ferido), arma a recarga e o contragolpe, agenda o eco e faz o visual e o som. Devolve quantos monstros acertou. O herói cuida do estado.
func disparar(h, f: float, perfeito: bool) -> int:
	f = clampf(f, 0.0, 1.0)
	var c = combate
	para_heroi(str(h.chave))
	var raio := raio_de(h, f, perfeito)
	var dano_b := dano_de(h, f, perfeito)
	var atordoa := atordoa_de(f, perfeito)
	_explosoes = 0
	disparos += 1
	var n := _pulso(h, h.pos, raio, dano_b, atordoa, empurrao_de(f), f, false)
	ultimo = {"n": n, "f": f, "raio": raio, "dano": dano_b, "atordoa": atordoa, "perfeito": perfeito, "mortes": _mortes}
	var rec := recarga_de(perfeito)
	h.rup_recarga = rec
	h.rup_recarga_max = rec
	if n > 0:
		h.contragolpe_t = float(cfg.contragolpe.tempo)
		h.contragolpe_max = float(cfg.contragolpe.tempo)
	if float(somas.eco) > 0.0:
		_eco_t = float(cfg.eco.atraso)
		_eco_raio = raio * float(cfg.eco.raio)
		_eco_dano = dano_de(h, f, false) * float(somas.eco) / 100.0
		_eco_emp = empurrao_de(f) * float(cfg.eco.empurrao)
	# o visual: onda em elipse, anel branco, rachaduras, poeira, estouro, luz, o herói, câmera e som
	var p: Vector2 = h.pos
	_anel(p, raio * 0.25, raio, 0.22, 3.0, 1.0, COR_LARANJA.lerp(Color.WHITE, 0.35), 1.0)
	_anel(p, raio * 0.25, raio, 0.12, 1.0, 1.0, Color.WHITE, 1.0)
	if perfeito:
		_anel(p, raio * 0.3, raio * 1.05, 0.3, 2.0, 1.0, COR_OURO, 1.0)
	_rachar(p, raio)
	var fx = c.fx
	for i in maxi(6, roundi(16.0 * fx.fator_part)):
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a) * ACHATA) * randf_range(90.0, 160.0)
		fx.particula(p + Vector2(0, -1), v, randf_range(0.35, 0.5), 2.0 if randf() < 0.6 else 3.0, COR_POEIRA, 40.0)
	fx.estouro(p + Vector2(0, -2), COR_LARANJA, 10)
	fx.luz_rapida(p + Vector2(0, -6), Color(1.0, 0.65, 0.3), 2.2, 2.6 * raio, 0.3)
	fx.flash(h, 0.18, Color(1.0, 0.8, 0.5), 0, 0.8)
	c.audio.tocar("ruptura_disparo", 1.1 - 0.25 * f, 0.0, 0.0)
	var tremor := _par("tremor", f)
	var parada := _par("hit_stop", f)
	if perfeito:
		tremor += float(cfg.perfeito.tremor_mais)
		parada += float(cfg.perfeito.hit_stop_mais)
		fx.numero(p + Vector2(0, -58), "PERFEITO!", COR_OURO, true)
		c.audio.tocar("ruptura_pronta", 1.5, -3.0, 0.0)
	mundo.cam.tremer(tremor, float(cfg.tremor_dur))
	if n > 0:
		c.hit_stop(parada)
	if _mortes >= 3:
		fx.numero(p + Vector2(0, -44), "x%d" % _mortes, COR_OURO, true)
	c.processar_mortes()  # as mortes saem DEPOIS do laço (abates, combo, XP, orbes e Fôlego de caçador valem sozinhos)
	return n


## O pulso: um laço sobre mundo.monstros. `eco` = o segundo pulso da carta Eco do chão (sem lentidão no chefe).
func _pulso(h, centro: Vector2, raio: float, dano_b: float, atordoa: float, emp: float, f: float, eco: bool) -> int:
	var c = combate
	var g: Dictionary = c.cfg.golpe
	var chance: float = float(g.critico.chance) + float(h.m_critico)
	var mult_crit := float(g.critico.mult)
	var variacao := float(g.variacao)
	var lento := _par_chefe(f)
	var explode := float(c.armas.mods.explode)
	_hit_m.clear()
	_hit_d.clear()
	_hit_dn.clear()
	_hit_crit.clear()
	_hit_fora.clear()
	_mortes = 0
	for m in mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var rel: Vector2 = m.pos - centro
		if not Armas.na_elipse(rel, raio + m.raio):
			continue
		var dist := rel.length()
		var fora: Vector2 = rel / dist if dist > 0.5 else Vector2.from_angle(m.ang_cerco)
		var crit: bool = randf() < chance
		var d := dano_b * (1.0 + randf_range(-variacao, variacao))
		if crit:
			d *= mult_crit
		var dn := maxi(1, roundi(d))
		# numero = false: o número e a piscada saem abaixo, com limite (a horda de 100 não vira uma parede de texto)
		if c.ferir(m, d, fora, emp, atordoa, COR_NUM, false):
			_mortes += 1
		if m.chefe and not eco:
			m.deixar_lento(lento)  # o chefe não é atordoado nem empurrado: a lentidão abre espaço para sair e bater
		if crit and explode > 0.0 and _explosoes < int(cfg.explosoes_critico):  # modificador da katana: crítico explode
			_explosoes += 1
			var raio_e: float = float(c.cartas.definicao("explode").raio) * (1.0 + (h.m_area - 1.0) * 0.6)
			c.armas.explodir(m.pos, float(dn) * explode / 100.0, raio_e, COR_CRIT, m)
		_hit_m.append(m)
		_hit_d.append(dist)
		_hit_dn.append(dn)
		_hit_crit.append(1 if crit else 0)
		_hit_fora.append(fora)
	var n := _hit_m.size()
	_visual_alvos(n, eco)
	return n


## Número de dano e faíscas só nos mais perto (e todo crítico); o resto só pisca. Limites dos dados.
func _visual_alvos(n: int, eco: bool) -> void:
	if n == 0:
		return
	var fx = combate.fx
	var com_numero := PackedByteArray()
	com_numero.resize(n)
	var d_tmp := _hit_d.duplicate()
	var n_num := mini(n, int(cfg.numeros_max))
	var n_fai := mini(n, int(cfg.faiscas_alvos))
	for r in n_num:
		var k := 0
		var melhor := INF
		for j in n:
			if d_tmp[j] < melhor:
				melhor = d_tmp[j]
				k = j
		d_tmp[k] = INF
		com_numero[k] = 1
		if r < n_fai and not eco:
			var m = _hit_m[k]
			fx.faiscas(m.pos + Vector2(0, -8), _hit_fora[k], 6, COR_LARANJA, 170.0)
	var flashes := 0
	for k in n:
		var m = _hit_m[k]
		var crit := _hit_crit[k] == 1
		if com_numero[k] == 1 or crit:
			fx.numero(m.pos + Vector2(0, -float(m.alt) * 0.85), str(_hit_dn[k]), COR_CRIT if crit else COR_NUM, crit)
		if flashes < int(cfg.flash_max):
			flashes += 1
			fx.flash(m, 0.08)


func _par_chefe(f: float) -> float:
	var a: Array = cfg.chefe.lento
	return lerpf(float(a[0]), float(a[1]), f)


# ------------------------------------------------------------------ eventos (herói e combate chamam)


## Marco da carga (25, 50, 75 e 100%): o tom sobe; o último é o "pronta".
func tique(_h, i: int) -> void:
	var tons: Array = cfg.tique_tom
	combate.audio.tocar("ruptura_tique", float(tons[clampi(i, 0, tons.size() - 1)]), -8.0, 0.05)
	if i >= cfg.tiques.size() - 1:
		combate.audio.tocar("ruptura_pronta", 1.0, -8.0, 0.0)


## A recarga zerou: um anelzinho branco nos pés e um tique, uma vez.
func pronta(h) -> void:
	_anel(h.pos, 6.0, 14.0, 0.15, 1.0, 1.0, Color.WHITE, 0.9)
	combate.audio.tocar("ruptura_tique", 1.0, -10.0, 0.0)


## Apertou na recarga: o som grave (o slot do HUD treme pelo rup_nega_t do herói).
func negou(_h) -> void:
	combate.audio.tocar("ruptura_cancela", 0.7, -4.0, 0.0)


## A carga acabou sem disparar: o anel interno some cinza (sem luz). `som` = toca o ruptura_cancela.
func cancelou(h, som := true) -> void:
	var r := raio_de(h, h.rup_carga, false)
	_anel(h.pos, r, r * 0.9, 0.15, 2.0, 1.0, COR_CINZA, 0.9)
	if som:
		combate.audio.tocar("ruptura_cancela", 1.0, -6.0, 0.0)


# ------------------------------------------------------------------ o quadro


## Tempo do mundo (combate.atualizar, só com o jogo rolando): o eco da carta Eco do chão sai `eco.atraso` s depois do disparo, centrado em
## onde o herói está AGORA. Descartado se o herói morreu ou a partida recomeçou (limpar).
func atualizar(dt: float) -> void:
	if _eco_t < 0.0:
		return
	_eco_t -= dt
	if _eco_t > 0.0:
		return
	_eco_t = -1.0
	var h = mundo.heroi
	if not h.vivo():
		return
	ecos += 1
	var p: Vector2 = h.pos
	_pulso(h, p, _eco_raio, _eco_dano, 0.0, _eco_emp, 0.0, true)
	_anel(p, _eco_raio * 0.25, _eco_raio, 0.22, 2.0, 1.0, COR_LARANJA.lerp(Color.WHITE, 0.35), 0.6)
	combate.audio.tocar("ruptura_disparo", 1.4, -6.0, 0.0)
	mundo.cam.tremer(1.5, 0.12)
	combate.processar_mortes()


## Relógio de parede (continua no hit-stop): anéis e rachaduras envelhecem, as brasas da carga nascem e o desenho só roda se há o que mostrar.
func efeitos(dt: float) -> void:
	var h = mundo.heroi
	if h != null:
		para_heroi(str(h.chave))  # os números do herói de agora (barato: só compara a chave)
	var carregando: bool = h != null and h.estado == h.Estado.CARGA
	var vivo := carregando
	for i in MAX_ANEIS:
		if a_vivo[i] == 1:
			a_t[i] += dt
			if a_t[i] >= a_dur[i]:
				a_vivo[i] = 0
			else:
				vivo = true
	for i in MAX_RACH:
		if r_ativa[i] == 1:
			r_t[i] += dt
			if r_t[i] >= RACH_DUR:
				r_ativa[i] = 0
				r_pts[i] = null
			else:
				vivo = true
	if carregando:
		_brasa_t -= dt
		if _brasa_t <= 0.0:
			_brasa_t = 0.05
			var r := raio_de(h, h.rup_carga, h.rup_perfeita)
			for i in roundi(2.0 * combate.fx.fator_part):
				var off := Vector2.from_angle(randf() * TAU)
				off = Vector2(off.x * r, off.y * r * ACHATA)
				combate.fx.particula(h.pos + off + Vector2(0, -1), -off / 0.3, 0.3, 2.0, Color(1.0, 0.6, 0.25, 0.9), 0.0, true)
	if vivo or _desenhou:
		no.queue_redraw()
	_desenhou = vivo


# ------------------------------------------------------------------ desenho (um Node2D aditivo; elipse de chão achatada em 0,62)


func _anel(p: Vector2, r0: float, r1: float, dur: float, w0: float, w1: float, c: Color, alfa: float) -> void:
	var i := _ai
	_ai = (_ai + 1) % MAX_ANEIS
	a_vivo[i] = 1
	a_pos[i] = p
	a_t[i] = 0.0
	a_dur[i] = dur
	a_r0[i] = r0
	a_r1[i] = r1
	a_w0[i] = w0
	a_w1[i] = w1
	a_alfa[i] = alfa
	a_cor[i] = c
	no.queue_redraw()
	_desenhou = true


## Nove fissuras irregulares de seis pontos do centro até 90% do raio.
func _rachar(p: Vector2, raio: float) -> void:
	var i := _ri
	_ri = (_ri + 1) % MAX_RACH
	var fissuras: Array = []
	for k in FISSURAS:
		var dir := Vector2.from_angle(TAU * (float(k) + randf_range(-0.3, 0.3)) / float(FISSURAS))
		var perp := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array()
		pts.append(p.round())
		var desvio := 0.0
		for j in range(1, PONTOS_FISSURA + 1):
			desvio += randf_range(-0.07, 0.07) * raio
			var q := dir * (raio * 0.9 * float(j) / float(PONTOS_FISSURA)) + perp * desvio
			pts.append((p + Vector2(q.x, q.y * ACHATA)).round())
		fissuras.append(pts)
	r_pts[i] = fissuras
	r_t[i] = 0.0
	r_ativa[i] = 1


func _elipse(p: Vector2, r: float, n: int) -> PackedVector2Array:
	var v := PackedVector2Array()
	v.resize(n + 1)
	for k in n:
		var a := TAU * float(k) / float(n)
		v[k] = (p + Vector2(cos(a) * r, sin(a) * r * ACHATA)).round()
	v[n] = v[0]
	return v


func _desenhar() -> void:
	for i in MAX_RACH:
		if r_ativa[i] == 1 and r_pts[i] != null:
			var k := r_t[i] / RACH_DUR
			var cor := COR_LARANJA.lerp(Color(0.55, 0.06, 0.03), clampf(k * 1.3, 0.0, 1.0))
			cor.a = 1.0 - k
			for pts in r_pts[i]:
				no.draw_polyline(pts, cor, 2.0)
	for i in MAX_ANEIS:
		if a_vivo[i] != 1:
			continue
		var k := a_t[i] / a_dur[i]
		var e := 1.0 - (1.0 - k) * (1.0 - k)  # saída suave: abre rápido e assenta
		var cor: Color = a_cor[i]
		cor.a = a_alfa[i] * (1.0 - k)
		no.draw_polyline(_elipse(a_pos[i], lerpf(a_r0[i], a_r1[i], e), PTS), cor, lerpf(a_w0[i], a_w1[i], k))
	var h = mundo.heroi
	if h != null and h.estado == h.Estado.CARGA:
		_desenhar_carga(h)


## A carga: o anel fantasma no raio final (alfa 0,22) e o anel interno no raio de agora, que é exatamente o que sai se soltar agora.
## Laranja, amarelo e branco no cheio; na janela perfeita pisca branco e dourado a 20 Hz (o raio já mostra o bônus).
func _desenhar_carga(h) -> void:
	var f: float = h.rup_carga
	var p: Vector2 = h.pos
	no.draw_polyline(_elipse(p, raio_de(h, 1.0, false), PTS), Color(1.0, 0.9, 0.7, 0.22), 1.0)
	var cor: Color
	if h.rup_perfeita:
		cor = Color.WHITE if int(Time.get_ticks_msec() / 25) % 2 == 0 else COR_OURO
	elif f >= 1.0:
		cor = Color.WHITE
	elif f < 0.5:
		cor = COR_LARANJA.lerp(COR_OURO, f / 0.5)
	else:
		cor = COR_OURO.lerp(Color.WHITE, (f - 0.5) / 0.5)
	cor.a = 0.95
	no.draw_polyline(_elipse(p, raio_de(h, f, h.rup_perfeita), PTS), cor, 3.0 if h.rup_perfeita else 2.0)


# ------------------------------------------------------------------ painel de status (v2/status.gd lê estas duas)


## Os números de agora (m_dano, m_area e cartas), para o painel de status da build.
func resumo() -> Dictionary:
	var h = mundo.heroi
	return {
		"dano_min": dano_de(h, 0.0, false),
		"dano_max": dano_de(h, 1.0, false),
		"raio_min": raio_de(h, 0.0, false),
		"raio_max": raio_de(h, 1.0, false),
		"atordoa_min": atordoa_de(0.0, false),
		"atordoa_max": atordoa_de(1.0, false),
		"recarga": recarga_de(false),
		"carga": carga_max(h),
		"contra_bonus": bonus_contragolpe(),
		"contra_tempo": float(cfg.contragolpe.tempo),
		"eco_pct": float(somas.eco),
		"soma_dano": float(somas.dano),
		"soma_recarga": float(somas.recarga),
		"soma_atordoa": float(somas.atordoa),
		"soma_contra": float(somas.contra),
		"soma_eco": float(somas.eco)
	}


## Uma linha pronta para o painel, com vírgula decimal.
func linha() -> String:
	var r := resumo()
	return (
		"Ruptura (E): dano %s a %s | raio %s a %s px | recarga %s s | atordoa %s a %s s | contragolpe +%s%% por %s s | eco %s%%"
		% [
			_fmt(r.dano_min),
			_fmt(r.dano_max),
			_fmt(r.raio_min),
			_fmt(r.raio_max),
			_fmt(r.recarga),
			_fmt(r.atordoa_min),
			_fmt(r.atordoa_max),
			_fmt(roundf(float(r.contra_bonus) * 100.0)),
			_fmt(r.contra_tempo),
			_fmt(r.eco_pct)
		]
	)


## Número com até duas casas, sem zeros sobrando e com vírgula.
static func _fmt(x: float) -> String:
	var s := "%.2f" % x
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s.replace(".", ",")
