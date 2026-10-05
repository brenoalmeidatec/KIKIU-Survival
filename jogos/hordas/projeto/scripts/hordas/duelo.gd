extends Node2D
## DUELO FINAL: depois da horda, todo mundo da partida se enfrenta numa arena redonda que vai fechando.
## Quem sobrar é o mais forte. Cada um luta com a build que montou (as mesmas armas e passivos),
## com três regras de equilíbrio (dados/pvp.json): vida do duelo, dano comprimido e anel que fecha.
##
## Aqui os rivais são controlados pela IA (rival.gd) com builds sorteadas do mesmo nível do jogador.
## No jogo online cada rival será uma pessoa: o resto do duelo (anel, dano, ranking) continua igual.

const Rival := preload("res://scripts/hordas/rival.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
const IA := preload("res://scripts/hordas/ia_luta.gd")

const CORES := [Color(1.0, 0.45, 0.4), Color(1.0, 0.75, 0.3), Color(0.75, 0.5, 1.0), Color(0.4, 0.9, 0.6),
	Color(1.0, 0.55, 0.85), Color(0.6, 0.85, 1.0)]


class Lutador:
	var id := 0
	var nome := ""
	var heroi := ""
	var pos := Vector2.ZERO
	var raio := 11.0
	var lento := 0.0
	var vivo := true
	var lugar := 0
	var no: Node2D
	var cor := Color.WHITE
	var jogador := false
	var mult := 1.0                  # multiplicador de dano do duelo (equilíbrio)
	var nom := {}                    # dano de catálogo por tipo de arma (calibragem)
	var raw := {}                    # dano bruto que acertou, por tipo (calibragem)
	var vivo_ate := 0.0


## O que as armas de UM lutador enxergam: todos os outros lutadores vivos (mesma interface do inimigos.gd).
class Campo:
	var duelo
	var eu: Lutador
	var statf: Callable

	func _alvos() -> Array:
		return duelo.lutadores.filter(func(l): return l != eu and l.vivo)

	func no_circulo(c: Vector2, r: float) -> Array:
		var res := []
		for l in _alvos():
			var rr: float = r + l.raio
			if l.pos.distance_squared_to(c) <= rr * rr:
				res.append(l)
		return res

	func n_mais_perto(p: Vector2, n: int, maximo := 400.0) -> Array:
		var perto := no_circulo(p, maximo)
		perto.sort_custom(func(a, b): return a.pos.distance_squared_to(p) < b.pos.distance_squared_to(p))
		return perto.slice(0, n)

	func mais_perto(p: Vector2, maximo := 99999.0):
		var r := n_mais_perto(p, 1, maximo)
		return r[0] if not r.is_empty() else null

	func aleatorio_na_tela(centro: Vector2):
		var perto := no_circulo(centro, 260)
		return perto.pick_random() if not perto.is_empty() else null

	func ferir(v, valor: float, empurrao := Vector2.ZERO, arma := "") -> bool:
		return duelo.ferir(eu, v, valor, empurrao, arma, statf)


var arena: Node
var cfg: Dictionary
var ativo := false
var estado := ""              # contagem, luta, fim
var t_contagem := 0.0
var t_luta := 0.0
var centro := Vector2.ZERO
var raio := 340.0
var raio_ini := 340.0
var lutadores: Array = []
var rivais: Array = []
var lut_jogador: Lutador
var hp_base := 220.0
var hp_por_vida := 1.0
var regen_mult := 0.25
var iframes := 0.12
var _anel := Node2D.new()
var _fim_em := -1.0
var _ultimo_numero := 99
var _t := 0.0
var abates := 0               # quantos o jogador derrubou
var dano_causado := 0.0


func _ready() -> void:
	_anel.z_index = -5
	_anel.draw.connect(_desenhar_anel)
	add_child(_anel)


## Vida que um lutador tem no duelo, a partir da vida máxima da build.
func hp_pvp(vida_max: float) -> float:
	return hp_base + vida_max * hp_por_vida


func campo_de(l: Lutador, statf: Callable) -> Campo:
	var c := Campo.new()
	c.duelo = self
	c.eu = l
	c.statf = statf
	return c


func alvos_de(l: Lutador) -> Array:
	var res := []
	for o in lutadores:
		if o != l and o.vivo:
			res.append({"pos": o.pos, "hp_frac": _hp_frac(o), "raio": o.raio})
	return res


func _hp_frac(l: Lutador) -> float:
	if l.jogador:
		return clampf(arena.jogador.hp / maxf(1.0, arena.stat("vida_max")), 0.0, 1.0)
	return clampf(l.no.hp / l.no.hpmax, 0.0, 1.0)


func vivos() -> Array:
	return lutadores.filter(func(l): return l.vivo)


# ---------- começo ----------

func iniciar(a: Node) -> void:
	arena = a
	cfg = Dados.json("pvp")
	ativo = true
	estado = "contagem"
	var cont: Dictionary = cfg.get("arena", {})
	hp_base = float(cfg.get("hp_base", 220.0))
	hp_por_vida = float(cfg.get("hp_por_vida_max", 1.0))
	regen_mult = float(cfg.get("regen_mult", 0.25))
	iframes = float(cfg.get("iframes", 0.12))
	t_contagem = float(cfg.get("contagem", 4.0))
	raio_ini = float(cont.get("raio", 340.0))
	raio = raio_ini
	centro = a.jogador.position.snapped(Vector2(32, 32))
	a.inimigos.limpar()
	a.coleta.limpar()
	a.efeitos.limpar()
	a.chao.santuarios.clear()
	a.armas.limpar_tiros()
	a.duelo_ativo = true
	a.camera.position = centro

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := int(cfg.get("rivais_solo", 3))
	var slots := n + 1
	var slot_jog := rng.randi() % slots
	var ang0 := rng.randf() * TAU
	lut_jogador = Lutador.new()
	lut_jogador.id = 0
	lut_jogador.nome = "Você"
	lut_jogador.heroi = a.heroi_id
	lut_jogador.no = a.jogador
	lut_jogador.jogador = true
	lut_jogador.cor = Color(0.45, 0.8, 1.0)
	lutadores.append(lut_jogador)
	var elenco: Array = cfg.get("elenco", []).filter(func(h): return h != a.heroi_id)
	elenco.shuffle()
	var herois: Dictionary = Dados.json("herois")
	var f: Array = cfg.get("rival_nivel_fator", [0.85, 1.1])
	var usados := {}
	var k := 0
	for s in slots:
		var p := centro + Vector2.from_angle(ang0 + TAU * s / slots) * raio_ini * 0.72
		if s == slot_jog:
			a.jogador.position = p + Vector2(0, 22)
			continue
		var h: String = elenco[k % elenco.size()] if not elenco.is_empty() else a.heroi_id
		var nome := str(herois.get(h, {}).get("nome", h))
		if usados.has(nome):
			nome += str(usados[nome] + 1)
		usados[nome] = int(usados.get(nome, 0)) + 1
		var nivel_r := maxi(2, roundi(a.nivel * rng.randf_range(float(f[0]), float(f[1]))))
		var l := Lutador.new()
		l.id = k + 1
		l.nome = nome
		l.heroi = h
		l.cor = CORES[k % CORES.size()]
		var r := Rival.new()
		r.position = p + Vector2(0, 22)
		add_child(r)
		l.no = r
		r.configurar(self, l, nome, h, Construcao.gerar(h, nivel_r, rng), l.cor, float(cfg.get("habilidade_rival", 0.85)))
		l.pos = r.centro()
		lutadores.append(l)
		rivais.append(r)
		k += 1
	lut_jogador.pos = a.jogador.centro()
	_equilibrar()
	a.armas.campo = campo_de(lut_jogador, a.stat)
	a.jogador.hp = a.stat("vida_max")
	a.jogador.invencivel = 0.0
	Som.tocar("tremor")
	a.tremer(8)
	a.anunciar("DUELO FINAL!", Color(1, 0.45, 0.4))
	Som.musica(str(cfg.get("musica", "minijogo_retro")))


## Equilibra o dano: todo mundo bate com "dps_ref x (força relativa)^expoente". Assim o duelo dura
## o mesmo tempo com build de nível 10 ou de nível 60 (força média = dps_ref), e uma build 2x mais
## forte que a média rende só 2^0,7 = 1,6x. A "eficiência" diz que fração do dano de catálogo de cada
## tipo de arma realmente acerta alguém que se mexe (calibrada com duelos de robôs).
func _equilibrar() -> void:
	var ef: Dictionary = cfg.get("eficiencia", {})
	var ref := float(cfg.get("dps_ref", 12.0))
	var ex := float(cfg.get("expoente_forca", 0.7))
	var ests := []
	for l in lutadores:
		var st: Dictionary
		var armas_l: Array
		if l.jogador:
			st = Construcao.stats(arena.heroi, arena.passivos)
			armas_l = arena.armas.lista
		else:
			st = l.no.stats
			armas_l = l.no.build.armas
		l.nom = Construcao.dps_por_tipo(armas_l, st)
		var est := 0.0
		for tipo in l.nom:
			est += l.nom[tipo] * float(ef.get(tipo, 0.6))
		ests.append(maxf(est, 0.5))
	var media := 0.0
	for e in ests:
		media += e
	media /= ests.size()
	for i in lutadores.size():
		lutadores[i].mult = clampf(ref * pow(ests[i] / media, ex) / ests[i], 0.02, 30.0)


# ---------- a cada quadro ----------

func atualizar(dt: float) -> void:
	if not ativo or estado == "fim":
		return
	_t += dt
	lut_jogador.pos = arena.jogador.centro()
	for l in lutadores:
		l.lento = maxf(0.0, l.lento - dt)
	if estado == "contagem":
		t_contagem -= dt
		var n := ceili(t_contagem)
		if n != _ultimo_numero and n > 0:
			_ultimo_numero = n
			arena.anunciar(str(n), Color(1, 0.9, 0.5))
			Som.tocar("cursor", 0.1, 1.0 + (4 - n) * 0.15)
		if t_contagem <= 0:
			estado = "luta"
			arena.anunciar("LUTEM!", Color(1, 0.45, 0.4))
			Som.tocar("soco")
			arena.tremer(6)
		_anel.queue_redraw()
		return
	t_luta += dt
	for r in rivais:
		if r.lut.vivo:
			r.atualizar(dt)
			r.lut.pos = r.centro()
	_atualizar_anel(dt)
	if _fim_em >= 0.0:
		_fim_em -= dt
		if _fim_em <= 0.0:
			_fim()
	elif vivos().size() <= 1:
		_fim_em = 1.5
	elif t_luta > float(cfg.get("tempo_max", 150)):
		_fim_em = 0.01
	_anel.queue_redraw()


func fracao_anel() -> float:
	var c: Dictionary = cfg.get("arena", {})
	var ini := float(c.get("inicio_encolher", 12.0))
	var dur := float(c.get("duracao_encolher", 70.0))
	return clampf((t_luta - ini) / dur, 0.0, 1.0)


func _atualizar_anel(dt: float) -> void:
	var c: Dictionary = cfg.get("arena", {})
	var f := fracao_anel()
	raio = lerpf(raio_ini, float(c.get("raio_final", 70.0)), f * f * (3.0 - 2.0 * f))
	var pct := float(c.get("dano_anel_pct", 0.04)) * (1.0 + f * float(c.get("dano_anel_cresce", 1.0)))
	var no_anel: Array = vivos()
	no_anel.sort_custom(func(a, b): return _hp_frac(a) < _hp_frac(b))   # empate: quem tem menos vida cai primeiro
	for l in no_anel:
		if not l.vivo:
			continue
		if l.pos.distance_to(centro) > raio:
			var hpmax: float = arena.stat("vida_max") if l.jogador else l.no.hpmax
			if l.no.dano_direto(pct * hpmax * dt, "anel"):
				eliminado(l, "")


# ---------- dano e eliminação ----------

## Uma arma do lutador "atq" acertou "alvo". Retorna true se o alvo caiu.
func ferir(atq: Lutador, alvo: Lutador, valor: float, empurrao: Vector2, arma: String, statf: Callable) -> bool:
	if estado != "luta" or not alvo.vivo or not atq.vivo:
		return false
	var d := valor * atq.mult
	var tipo := str(Dados.item(arma).get("tipo", "?")) if arma != "" else "?"
	atq.raw[tipo] = float(atq.raw.get(tipo, 0.0)) + valor
	var crit := randf() < float(statf.call("critico"))
	if crit:
		d *= float(statf.call("critico_mult"))
	var morreu: bool = alvo.no.receber(d, atq.nome, empurrao * float(cfg.get("empurrao_mult", 0.5)))
	if atq.jogador:
		dano_causado += d
		if arma != "":
			arena.dano_por_arma[arma] = float(arena.dano_por_arma.get(arma, 0.0)) + d
	var cor := Color(1, 0.9, 0.4) if crit else (Color(1, 1, 1) if atq.jogador else Color(1, 0.6, 0.55))
	arena.efeitos.numero(alvo.pos, d, cor, crit)
	Som.tocar("acerto", 0.06, randf_range(0.9, 1.2), -12)
	if alvo.jogador:
		arena.tremer(2.0)
	if morreu:
		eliminado(alvo, atq.nome)
	return morreu


func jogador_caiu(quem: String) -> void:
	eliminado(lut_jogador, quem)


func eliminado(l: Lutador, quem: String) -> void:
	if not l.vivo:
		return
	l.vivo_ate = t_luta
	l.lugar = vivos().size()      # 4 vivos e você caiu = 4º lugar
	l.vivo = false
	quem = quem.trim_prefix("rival:")
	arena.efeitos.explodir(l.pos, l.cor, 22, 200.0)
	arena.tremer(5)
	Som.tocar("soco", 0.05, 0.8)
	if quem == "desistiu":
		arena.mensagem("%s desistiu!" % l.nome, l.cor.lightened(0.3))
	elif quem == "" or quem == "anel":
		arena.mensagem("%s caiu fora do anel!" % l.nome, l.cor.lightened(0.3))
	else:
		arena.mensagem("%s derrubou %s!" % [quem, l.nome], Color(1, 0.85, 0.5))
	if quem == "Você":
		abates += 1
	if l.jogador:
		arena.jogador.visible = false
		arena.jogador.hp = 0
		_fim_em = float(cfg.get("espera_apos_cair", 2.5))
	else:
		l.no.sumir()
	if vivos().size() <= 1 and _fim_em < 0.0:
		_fim_em = 1.5


func _fim() -> void:
	if estado == "fim":
		return
	estado = "fim"
	# quem ainda está vivo: o de mais vida ganha
	var vivos_: Array = vivos()
	vivos_.sort_custom(func(a, b): return _hp_frac(a) > _hp_frac(b))
	for i in vivos_.size():
		vivos_[i].lugar = i + 1
	var ranking := []
	for l in lutadores:
		ranking.append({"nome": l.nome, "heroi": l.heroi, "lugar": l.lugar, "jogador": l.jogador})
	ranking.sort_custom(func(a, b): return a.lugar < b.lugar)
	for l in lutadores:
		if l.vivo:
			l.vivo_ate = t_luta
	var res := {"lugar": lut_jogador.lugar, "total": lutadores.size(), "ranking": ranking, "abates": abates,
		"dano": dano_causado, "duracao": t_luta}
	if OS.get_cmdline_user_args().has("--calibrar"):
		var calib := []
		for l in lutadores:
			calib.append({"nom": l.nom, "raw": l.raw, "t": l.vivo_ate, "mult": l.mult, "lugar": l.lugar})
		print("CALIB ", JSON.stringify(calib))
	arena.fim_duelo(res)


# ---------- desenho ----------

func _desenhar_anel() -> void:
	if not ativo:
		return
	var fora := Color(0.04, 0.0, 0.08, 0.55)
	_anel.draw_arc(centro, raio + 330.0, 0.0, TAU, 200, fora, 660.0)
	var pulso := 0.6 + 0.4 * sin(_t * 6.0)
	var cor := Color(1, 0.35, 0.3, 0.55 + 0.4 * pulso)
	_anel.draw_arc(centro, raio, 0.0, TAU, 160, cor, 3.0)
	_anel.draw_arc(centro, raio - 6.0, 0.0, TAU, 160, Color(1, 0.6, 0.5, 0.18), 6.0)
