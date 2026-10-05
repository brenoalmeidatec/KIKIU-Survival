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
	var remoto := false              # online: outra pessoa (id = peer dela)


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
var online := false           # duelo entre pessoas (o anfitrião decide luta, quedas e fim)
var _luta_mandada := false
var _ultimo_golpe := 0        # online: peer de quem bateu por último (pra dizer quem derrubou)
var _forca_local := 1.0


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
	if l.remoto:
		return float(Rede.remotos.get(l.id, {}).get("hp", 0.0))
	return clampf(l.no.hp / l.no.hpmax, 0.0, 1.0)


func vivos() -> Array:
	return lutadores.filter(func(l): return l.vivo)


# ---------- começo ----------

## Regras do pvp.json e limpeza da arena (igual no solo e no online).
func _preparar(a: Node, c: Vector2) -> void:
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
	centro = c
	a.inimigos.limpar()
	a.coleta.limpar()
	a.efeitos.limpar()
	a.chao.santuarios.clear()
	a.armas.limpar_tiros()
	a.duelo_ativo = true
	a.camera.position = centro


func iniciar(a: Node) -> void:
	_preparar(a, a.jogador.position.snapped(Vector2(32, 32)))

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
	var ests := []
	for l in lutadores:
		ests.append(_forca(l))
	var media := 0.0
	for e in ests:
		media += e
	media /= ests.size()
	for i in lutadores.size():
		lutadores[i].mult = _mult(ests[i], media)


## "Força" de um lutador: dano de catálogo de cada tipo de arma x eficiência daquele tipo.
func _forca(l: Lutador) -> float:
	var ef: Dictionary = cfg.get("eficiencia", {})
	var st: Dictionary
	var armas_l: Array
	if l.jogador:
		st = Construcao.stats(arena.heroi, arena.passivos, arena.equipamentos)
		armas_l = arena.armas.lista
	else:
		st = l.no.stats
		armas_l = l.no.build.armas
	l.nom = Construcao.dps_por_tipo(armas_l, st)
	var est := 0.0
	for tipo in l.nom:
		est += l.nom[tipo] * float(ef.get(tipo, 0.6))
	return maxf(est, 0.5)


func _mult(est: float, media: float) -> float:
	var ref := float(cfg.get("dps_ref", 12.0))
	var ex := float(cfg.get("expoente_forca", 0.7))
	return clampf(ref * pow(est / media, ex) / est, 0.02, 30.0)


# ---------- a cada quadro ----------

func atualizar(dt: float) -> void:
	if not ativo or estado == "fim":
		return
	_t += dt
	lut_jogador.pos = arena.jogador.centro()
	if online:
		_posicoes_remotas()
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
			if not online:
				_comecar_luta()
			elif Rede.anfitriao() and not _luta_mandada:
				checar_forcas(t_contagem < -3.0)   # espera a força de todo mundo, até 3 s a mais
		_anel.queue_redraw()
		return
	t_luta += dt
	for r in rivais:
		if r.lut.vivo:
			r.atualizar(dt)
			r.lut.pos = r.centro()
	_atualizar_anel(dt)
	if online:
		if Rede.anfitriao():
			_fim_anfitriao(dt)
		_anel.queue_redraw()
		return
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
		if l.remoto:
			continue   # online: cada um calcula o anel só pra si
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
	var morreu := false
	if alvo.remoto:
		# online: quem apanha decide (vida, invencibilidade, dash); aqui só manda o golpe e mostra o número
		Rede.golpe(alvo.id, d, empurrao * float(cfg.get("empurrao_mult", 0.5)))
	else:
		morreu = alvo.no.receber(d, atq.nome, empurrao * float(cfg.get("empurrao_mult", 0.5)))
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
	if online:
		# online: avisa o anfitrião, que dá o lugar e conta pra todo mundo
		if lut_jogador.vivo:
			lut_jogador.vivo = false
			arena.jogador.visible = false
			Rede.avisar("caiu", 0.0, _ultimo_golpe if quem.begins_with("rival:") else 0)
		return
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


func _comecar_luta() -> void:
	estado = "luta"
	arena.anunciar("LUTEM!", Color(1, 0.45, 0.4))
	Som.tocar("soco")
	arena.tremer(6)


# ---------- online: duelo entre as pessoas da sala ----------
# Cada pessoa vira um Lutador "remoto" (a posição vem do pacote de posição; o boneco é o remoto.gd).
# Quem ataca detecta o acerto e manda o golpe; quem apanha decide. O anel cada um calcula pra si.
# O anfitrião junta as forças (equilíbrio), começa a luta, dá os lugares e encerra.

func iniciar_online(a: Node, d: Dictionary) -> void:
	online = true
	_preparar(a, Vector2(float(d.get("cx", 0.0)), float(d.get("cy", 0.0))))
	var ordem: Array = d.get("ordem", []).filter(func(p): return Rede.jogadores.has(p))
	var n := maxi(1, ordem.size())
	var ang0 := float(d.get("ang", 0.0))
	for s in ordem.size():
		var peer: int = ordem[s]
		var p := centro + Vector2.from_angle(ang0 + TAU * s / n) * raio_ini * 0.72
		var l := Lutador.new()
		l.id = peer
		l.heroi = Rede.heroi_de(peer)
		l.cor = CORES[s % CORES.size()]
		if peer == Rede.eu():
			l.nome = "Você"
			l.jogador = true
			l.no = a.jogador
			l.cor = Color(0.45, 0.8, 1.0)
			a.jogador.position = p + Vector2(0, 22)
			lut_jogador = l
		else:
			l.nome = Rede.nome_de(peer)
			l.remoto = true
			l.no = a.online.avatares.get(peer)
			l.pos = p
			if l.no:
				l.no.cor = l.cor
		lutadores.append(l)
	if lut_jogador == null:
		# não estou na lista (entrei atrasado?): só assiste
		lut_jogador = Lutador.new()
		lut_jogador.jogador = true
		lut_jogador.vivo = false
		lut_jogador.no = a.jogador
	lut_jogador.pos = a.jogador.centro()
	a.armas.campo = campo_de(lut_jogador, a.stat)
	a.jogador.hp = a.stat("vida_max")
	a.jogador.invencivel = 0.0
	_forca_local = _forca(lut_jogador)
	Rede.avisar("forca", _forca_local)
	Som.tocar("tremor")
	a.tremer(8)
	a.anunciar("DUELO FINAL!", Color(1, 0.45, 0.4))
	Som.musica(str(cfg.get("musica", "minijogo_retro")))


func _posicoes_remotas() -> void:
	for l in lutadores:
		if not l.remoto:
			continue
		if l.no == null or not is_instance_valid(l.no):
			l.no = arena.online.avatares.get(l.id)
		if l.no:
			l.pos = l.no.centro()


## Anfitrião: todo mundo mandou a força (ou passou do tempo)? Então começa a luta.
func checar_forcas(forcar := false) -> void:
	if not online or not Rede.anfitriao() or _luta_mandada or estado != "contagem" or t_contagem > 0:
		return
	var f: Dictionary = arena.online.forcas
	var todos := true
	for l in lutadores:
		if l.id != 0 and not f.has(l.id):
			todos = false
	if todos or forcar:
		_luta_mandada = true
		Rede.evento("luta", {"forcas": f.duplicate()})


func luta_online(d: Dictionary) -> void:
	if estado != "contagem":
		return
	var f: Dictionary = d.get("forcas", {})
	var media := 0.0
	var n := 0
	for k in f:
		media += float(f[k])
		n += 1
	if n == 0:
		media = _forca_local
	else:
		media /= n
	lut_jogador.mult = _mult(_forca_local, maxf(media, 0.5))
	t_luta = 0.0
	_comecar_luta()


## Golpe de outra pessoa em mim. Quem apanha decide: vida, invencibilidade e dash valem daqui.
func golpe_online(quem: int, dano: float, empurrao: Vector2) -> void:
	if not online or estado != "luta" or not lut_jogador.vivo:
		return
	_ultimo_golpe = quem
	var antes: float = arena.jogador.hp
	arena.jogador.receber(dano, Rede.nome_de(quem), empurrao)
	if arena.jogador.hp < antes:
		arena.efeitos.numero(lut_jogador.pos, antes - arena.jogador.hp, Color(1, 0.6, 0.55), false)
		Som.tocar("acerto", 0.06, randf_range(0.9, 1.2), -12)
		arena.tremer(2.0)


## Anfitrião: alguém caiu (por = quem derrubou, 0 = anel). O lugar é quantos ainda estavam de pé.
func caiu_online(quem: int, por: int) -> void:
	if not online or not Rede.anfitriao() or estado == "fim":
		return
	var l = _lut(quem)
	if l == null or l.lugar > 0:
		return
	var de_pe := lutadores.filter(func(o): return o.lugar == 0).size()
	Rede.evento("eliminado", {"peer": quem, "lugar": de_pe, "por": por})


func eliminado_online(d: Dictionary) -> void:
	var l = _lut(int(d.get("peer", 0)))
	if l == null or l.lugar > 0:
		return
	var por := int(d.get("por", 0))
	l.lugar = int(d.get("lugar", 0))
	l.vivo = false
	l.vivo_ate = t_luta
	arena.efeitos.explodir(l.pos, l.cor, 22, 200.0)
	arena.tremer(5)
	Som.tocar("soco", 0.05, 0.8)
	var nome_por := "Você" if por == Rede.eu() else Rede.nome_de(por)
	if por == 0:
		arena.mensagem("%s caiu fora do anel!" % l.nome, l.cor.lightened(0.3))
	else:
		arena.mensagem("%s derrubou %s!" % [nome_por, l.nome], Color(1, 0.85, 0.5))
	if por == Rede.eu() and l != lut_jogador:
		abates += 1
	if l == lut_jogador:
		arena.jogador.visible = false
		arena.jogador.hp = 0
	elif l.no and is_instance_valid(l.no):
		l.no.fora = true


## Anfitrião: sobrou um (ou passou do tempo máximo)? Espera um pouco e manda o ranking.
func _fim_anfitriao(dt: float) -> void:
	if _fim_em >= 0.0:
		_fim_em -= dt
		if _fim_em <= 0.0:
			var de_pe := lutadores.filter(func(o): return o.lugar == 0)
			de_pe.sort_custom(func(a, b): return _hp_frac(a) > _hp_frac(b))
			var lugares := {}
			for l in lutadores:
				lugares[l.id] = l.lugar
			for i in de_pe.size():
				lugares[de_pe[i].id] = i + 1
			Rede.evento("duelo_fim", {"lugares": lugares, "duracao": t_luta})
			_fim_em = 999.0
	elif lutadores.filter(func(o): return o.lugar == 0).size() <= 1:
		_fim_em = 1.5
	elif t_luta > float(cfg.get("tempo_max", 150)):
		_fim_em = 0.01


func fim_online(d: Dictionary) -> void:
	if estado == "fim":
		return
	estado = "fim"
	var lugares: Dictionary = d.get("lugares", {})
	for l in lutadores:
		l.lugar = int(lugares.get(l.id, l.lugar))
	var ranking := []
	for l in lutadores:
		ranking.append({"nome": l.nome, "heroi": l.heroi, "lugar": l.lugar, "jogador": l == lut_jogador})
	ranking.sort_custom(func(a, b): return a.lugar < b.lugar)
	arena.fim_duelo({"lugar": maxi(1, lut_jogador.lugar), "total": lutadores.size(), "ranking": ranking,
		"abates": abates, "dano": dano_causado, "duracao": float(d.get("duracao", t_luta))})


func _lut(peer: int):
	for l in lutadores:
		if l.id == peer:
			return l
	return null


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
