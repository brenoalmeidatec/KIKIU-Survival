extends Node
## Descobertas do mundo (#21, seções 16 a 29 do design): santuários, fragmentos, dádivas e eventos aleatórios.
## Tudo vem de dados/descobertas.json e dados/dadivas.json e é sorteado por streams da Sorte (mesma semente = mesmo
## mundo). As funções "static" são puras (só semente + dados), então o teste e os dois lados do online chegam no mesmo plano.
##
## Santuário (entrada em chao.santuarios): {pos, tipo, variacao, carga, usado}. tipos:
##   tomada (carta, o de sempre), dadiva (escolha de 3 dádivas), fragmento (Santuário do Dragão: fragmento da
##   transformação, com variação simples/combate/sacrificio) e maldito (risco por uma dádiva melhor).
## Online: só a semente e as escolhas trafegam. Santuários e variações saem iguais nos dois lados (âncora = origem do
## mapa no online). Eventos usam a mesma stream, mas nascem em volta de cada jogador e a horda de elite só o anfitrião cria.

const Sorte := preload("res://scripts/hordas/sorte.gd")

var arena: Node
var fragmentos := {}         # id da habilidade -> quantos fragmentos já pegou
var dadivas: Array = []      # [{id, raridade}] já pegas
var eventos_vistos: Array = []   # ids dos eventos que já rolaram (teste e depuração)
var _rng_ev: RandomNumberGenerator
var _prox_evento := 0.0
var _cd := {}                # id do evento -> segundos de cooldown que faltam
var _hist: Array = []        # últimos eventos (o peso de quem saiu há pouco encolhe)
var _desafios: Array = []    # santuários de combate em andamento
var _hordas: Array = []      # hordas de elite de evento em andamento


static func cfg() -> Dictionary:
	return Dados.json("descobertas")


# ---------- plano do mundo (puro: só semente + dados) ----------

## Em que fases ficam os Santuários do Dragão desta corrida (0, 1, 2 ou 3, pesos configuráveis; fases diferentes).
static func plano_fragmentos(n_fases: int) -> Array:
	var rng := Sorte.criar("plano_fragmento")
	var n := mini(_contagem(rng, cfg().get("santuarios", {}).get("fragmento_por_corrida", {})), n_fases)
	var fases := Sorte.embaralhar(rng, range(n_fases))
	var res := fases.slice(0, n)
	res.sort()
	return res


static func _contagem(rng: RandomNumberGenerator, tabela: Dictionary) -> int:
	var chaves := tabela.keys()
	var i := Sorte.ponderado(rng, chaves.map(func(k): return float(tabela[k])))
	return 0 if i < 0 else int(chaves[i])


## Santuários de uma fase: tomadas (cartas), dádivas e, se a fase está no plano, o Santuário do Dragão.
## Posição em volta da âncora, com distância mínima entre eles e nunca colado na âncora (= onde o jogador começa a fase).
static func planejar_fase(fase_idx: int, n_fases: int, n_tomadas: int, ancora: Vector2) -> Array:
	var c: Dictionary = cfg().get("santuarios", {})
	var rng := Sorte.criar("santuarios_fase", fase_idx)
	var res := []
	var usados: Array = []
	for i in n_tomadas:
		var a := TAU * i / float(maxi(1, n_tomadas)) + rng.randf_range(-0.3, 0.3)
		var p := ancora + Vector2.from_angle(a) * rng.randf_range(350.0, 900.0)
		usados.append(p)
		res.append(_novo(p, "tomada"))
	for _i in _contagem(rng, c.get("dadiva_por_fase", {})):
		var p := _posicao_livre(rng, ancora, usados, c)
		usados.append(p)
		res.append(_novo(p, "dadiva"))
	if fase_idx in plano_fragmentos(n_fases):
		var p := _posicao_livre(rng, ancora, usados, c)
		usados.append(p)
		var vs: Dictionary = c.get("variacoes", {})
		var chaves := vs.keys()
		var k := Sorte.ponderado(rng, chaves.map(func(x): return float(vs[x].get("peso", 1))))
		res.append(_novo(p, "fragmento", "simples" if k < 0 else str(chaves[k])))
	return res


static func _novo(pos: Vector2, tipo: String, variacao := "") -> Dictionary:
	return {"pos": pos, "tipo": tipo, "variacao": variacao, "carga": 0.0, "usado": false}


static func _posicao_livre(rng: RandomNumberGenerator, ancora: Vector2, usados: Array, c: Dictionary) -> Vector2:
	var dmin := float(c.get("dist_min_entre", 400.0))
	var p := ancora
	for _t in 40:
		p = ancora + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(float(c.get("raio_min", 380.0)), float(c.get("raio_max", 1000.0)))
		var bom := true
		for u in usados:
			if p.distance_to(u) < dmin:
				bom = false
				break
		if bom:
			return p
	return p


## Evento do pool: peso, fase mínima e cooldown; quem saiu há pouco perde peso (RNG controlado, seção 29).
static func escolher_evento(rng: RandomNumberGenerator, fase_num: int, cd: Dictionary, hist: Array) -> String:
	var ev: Dictionary = cfg().get("eventos", {})
	var lista: Dictionary = ev.get("lista", {})
	var ids := []
	var pesos := []
	for id in lista:
		var e: Dictionary = lista[id]
		if fase_num < int(e.get("fase_min", 1)) or float(cd.get(id, 0.0)) > 0.0:
			continue
		ids.append(id)
		pesos.append(float(e.get("peso", 1.0)) * pow(float(ev.get("peso_recente_mult", 0.5)), hist.count(id)))
	var i := Sorte.ponderado(rng, pesos)
	return "" if i < 0 else str(ids[i])


## 3 dádivas diferentes, cada uma com a raridade sorteada depois (a raridade multiplica o efeito).
static func oferta_dadivas(rng: RandomNumberGenerator, raridade_min := "") -> Array:
	var d: Dictionary = Dados.json("dadivas")
	var raras: Dictionary = d.get("_config", {}).get("raridades", {})
	var nomes := raras.keys()
	var minimo := maxi(0, nomes.find(raridade_min))
	var ids: Array = d.get("lista", {}).keys()
	Sorte.embaralhar(rng, ids)
	var res := []
	for id in ids.slice(0, int(d.get("_config", {}).get("oferta", 3))):
		var pesos := []
		for i in nomes.size():
			pesos.append(float(raras[nomes[i]].get("peso", 1)) if i >= minimo else 0.0)
		var r := Sorte.ponderado(rng, pesos)
		res.append(_carta_dadiva(str(id), str(nomes[maxi(r, 0)])))
	return res


static func _carta_dadiva(id: String, raridade: String) -> Dictionary:
	var d: Dictionary = Dados.json("dadivas")
	var def: Dictionary = d.get("lista", {}).get(id, {})
	var rar: Dictionary = d.get("_config", {}).get("raridades", {}).get(raridade, {})
	var cor: Array = rar.get("cor", [1, 1, 1])
	var partes := []
	var efeito: Dictionary = def.get("efeito", {})
	for k in efeito:
		var v := absf(float(efeito[k]) * float(rar.get("mult", 1.0)))
		var txt := "+%d%%" % roundi(v * 100.0) if str(def.get("formato", "pct")) == "pct" else ("+%d" % roundi(v) if absf(v - roundf(v)) < 0.05 else "+%.1f" % v)
		partes.append("%s %s" % [txt, str(def.get("rotulo", k))])
	return {"tipo": "dadiva", "id": id, "raridade": raridade, "rar_nome": str(rar.get("nome", raridade)), "cor": Color(cor[0], cor[1], cor[2]),
		"nome": str(def.get("nome", id)), "desc": ", ".join(partes), "icone": str(def.get("icone", id)), "nivel": 0}


# ---------- fragmentos ----------

func iniciar(a: Node) -> void:
	arena = a
	_rng_ev = Sorte.fluxo("evento")
	var ev: Dictionary = cfg().get("eventos", {})
	_prox_evento = _rng_ev.randf_range(float(ev.get("primeiro", [45, 75])[0]), float(ev.get("primeiro", [45, 75])[1]))


## Habilidade do herói que depende de fragmentos e ainda não está completa ("" = nenhuma).
func alvo_fragmento() -> String:
	var h = arena.habilidades
	if h == null or not h.tem() or str(h.d().get("desbloqueio", {}).get("tipo", "")) != "fragmentos" or h.desbloqueada:
		return ""
	return "" if completo(h.atual) else h.atual


func precisa(id: String) -> int:
	return int(Dados.json("habilidades").get(id, {}).get("fragmentos", 3))


func tem_fragmentos(id: String) -> int:
	return int(fragmentos.get(id, 0))


func completo(id: String) -> bool:
	return tem_fragmentos(id) >= precisa(id)


## Um fragmento da habilidade (santuário, elite ou evento). Ao juntar todos, habilidades.gd libera a forma.
func dar_fragmento(id: String) -> void:
	if id == "" or completo(id):
		return
	var n := tem_fragmentos(id) + 1
	fragmentos[id] = n
	var nomes: Array = Dados.json("habilidades").get(id, {}).get("fragmentos_nomes", [])
	var nome: String = str(nomes[n - 1]) if n - 1 < nomes.size() else str(n)
	arena.mensagem("Fragmento da %s! (%d/%d)" % [nome, n, precisa(id)], Color(0.55, 0.8, 1.0))
	Som.tocar("plim", 0.1, 1.3)


## Elite caiu: o fragmento cai com pity (chance sobe a cada elite sem fragmento e é garantida na tentativa "limite").
func elite_morreu(pos: Vector2) -> void:
	if alvo_fragmento() == "":
		return
	var p: Dictionary = cfg().get("pity", {}).get("elite", {})
	if Sorte.pity("elite", float(p.get("base", 0.05)), float(p.get("passo", 0.05)), int(p.get("limite", 12))):
		arena.coleta.soltar(pos + Vector2(10, -6), "fragmento")


## O que fazer com um fragmento no chão que o jogador pegou.
func pegou_fragmento() -> void:
	dar_fragmento(alvo_fragmento())


# ---------- dádivas ----------

func bonus() -> Dictionary:
	var res := {}
	var d: Dictionary = Dados.json("dadivas")
	var mult: Dictionary = d.get("_config", {}).get("raridades", {})
	for x in dadivas:
		var ef: Dictionary = d.get("lista", {}).get(x.id, {}).get("efeito", {})
		for k in ef:
			res[k] = float(res.get(k, 0.0)) + float(ef[k]) * float(mult.get(x.raridade, {}).get("mult", 1.0))
	return res


func aplicar_dadiva(c: Dictionary) -> void:
	dadivas.append({"id": c.id, "raridade": c.raridade})
	arena._recalcular()
	arena.mensagem("%s (%s)" % [c.nome, c.rar_nome], c.cor)


func _oferecer(titulo: String, raridade_min := "") -> void:
	Som.tocar("plim", 0.05, 1.2)
	arena.cartas.escolher(titulo, oferta_dadivas(Sorte.fluxo("dadiva"), raridade_min))


# ---------- santuários ----------

## O jogador carregou o santuário até o fim. false = ainda não dá (ex.: já tem uma escolha aberta); chao tenta de novo.
func ativar(s: Dictionary) -> bool:
	if arena.cartas.aberto():
		return false
	var c: Dictionary = cfg().get("santuarios", {})
	match str(s.tipo):
		"dadiva":
			s.usado = true
			_oferecer("Dádiva do santuário")
		"maldito":
			s.usado = true
			var m: Dictionary = c.get("maldito", {})
			_cercar(s.pos, int(m.get("inimigos", 4)), ["trojan", "spam"], true)
			arena.anunciar("MALDIÇÃO!", Color(0.85, 0.35, 0.8))
			_oferecer("Dádiva sombria", str(m.get("raridade_min", "rara")))
		"fragmento":
			return _ativar_fragmento(s, c)
		_:
			s.usado = true
			arena.ganhar_carta_tomada()
	return true


func _ativar_fragmento(s: Dictionary, c: Dictionary) -> bool:
	var alvo := alvo_fragmento()
	if alvo == "":
		s.usado = true   # sem forma pra desbloquear (outro herói, ou já desbloqueou): vira uma dádiva
		_oferecer("O santuário reage...")
		return true
	var v: Dictionary = c.get("variacoes", {}).get(str(s.variacao), {})
	match str(s.variacao):
		"combate":
			s.usado = true
			s["prog"] = 0.001
			_desafios.append({"s": s, "t": float(v.get("duracao", 14.0)), "total": float(v.get("duracao", 14.0)), "falta": int(v.get("inimigos", 14)),
				"acc": 0.0, "raio": float(v.get("raio", 190.0)), "avisou": false})
			arena.anunciar("SOBREVIVA!", Color(1, 0.6, 0.3))
			arena.mensagem("Fique perto do santuário até a energia acalmar", Color(1, 0.8, 0.5))
		"sacrificio":
			var custo: float = arena.stat("vida_max") * float(v.get("custo_vida", 0.35))
			if arena.jogador.hp <= custo + 1.0:
				arena.mensagem("Vida demais baixa pro sacrifício", Color(1, 0.5, 0.5))
				s.carga = 0.0
				return true
			arena.jogador.hp -= custo
			s.usado = true
			arena.anunciar("SACRIFÍCIO", Color(1, 0.4, 0.4))
			dar_fragmento(alvo)
		_:
			s.usado = true
			dar_fragmento(alvo)
	return true


## Inimigos em volta de um ponto (só quem cria vírus: no online, o anfitrião). Devolve os criados.
func _cercar(centro: Vector2, n: int, tipos: Array, elite: bool, raio := Vector2(110, 170)) -> Array:
	var res := []
	if arena.inimigos.espelho:
		return res
	var nivel: int = arena.diretor.nivel()
	for i in n:
		var a := TAU * i / float(maxi(1, n)) + randf() * 0.5
		var v = arena.inimigos.criar(str(tipos[randi() % tipos.size()]), centro + Vector2.from_angle(a) * randf_range(raio.x, raio.y), nivel, elite)
		if v:
			res.append(v)
	return res


# ---------- eventos aleatórios ----------

func atualizar(dt: float) -> void:
	if arena.duelo_ativo or arena.pre_duelo or arena.acabou:
		return
	for k in _cd:
		_cd[k] = maxf(0.0, float(_cd[k]) - dt)
	if not arena.entre_fases:
		_prox_evento -= dt
		if _prox_evento <= 0.0:
			sortear_evento()
	if not _desafios.is_empty():
		_atualizar_desafios(dt)
	if not _hordas.is_empty():
		_atualizar_hordas()


## Sorteia e executa um evento do pool (chamado pelo relógio; público pro teste).
func sortear_evento() -> String:
	var ev: Dictionary = cfg().get("eventos", {})
	var id := escolher_evento(_rng_ev, arena.diretor.fase_idx + 1, _cd, _hist)
	var iv: Array = ev.get("intervalo", [55, 95])
	_prox_evento = _rng_ev.randf_range(float(iv[0]), float(iv[1])) if id != "" else 15.0
	if id == "":
		return ""
	var e: Dictionary = ev.lista[id]
	_cd[id] = float(e.get("cooldown", 200.0))
	_hist.append(id)
	if _hist.size() > 3:
		_hist.pop_front()
	eventos_vistos.append(id)
	var pos: Vector2 = arena.jogador.position
	arena.anunciar(str(e.get("nome", id)).to_upper(), Color(1, 0.8, 0.4))
	arena.mensagem(str(e.get("msg", "")), Color(1, 0.9, 0.7))
	match str(e.get("acao", "")):
		"baus":
			var q: Array = e.get("qtd", [3, 5])
			var rr: Array = e.get("raio", [90, 230])
			for _i in _rng_ev.randi_range(int(q[0]), int(q[1])):
				arena.coleta.soltar(pos + Vector2.from_angle(_rng_ev.randf_range(0.0, TAU)) * _rng_ev.randf_range(float(rr[0]), float(rr[1])), "bau")
		"elites":
			var q: Array = e.get("qtd", [3, 5])
			var rr: Array = e.get("raio", [260, 340])
			var n := _rng_ev.randi_range(int(q[0]), int(q[1]))
			var r := _rng_ev.randf_range(float(rr[0]), float(rr[1]))
			var vs := _cercar(pos, n, e.get("tipos", ["bug"]), true, Vector2(r, r + 40.0))
			if not vs.is_empty():
				_hordas.append({"ids": vs.map(func(v): return v.id), "pos": pos, "evento": id})
		"santuario":
			var rr: Array = e.get("raio", [350, 600])
			var p := pos + Vector2.from_angle(_rng_ev.randf_range(0.0, TAU)) * _rng_ev.randf_range(float(rr[0]), float(rr[1]))
			var vs: Dictionary = cfg().get("santuarios", {}).get("variacoes", {})
			var chaves := vs.keys()
			var k := Sorte.ponderado(_rng_ev, chaves.map(func(x): return float(vs[x].get("peso", 1))))
			arena.chao.santuarios.append(_novo(p, str(e.get("tipo", "dadiva")), str(chaves[maxi(k, 0)]) if str(e.get("tipo", "")) == "fragmento" else ""))
	return id


func _atualizar_hordas() -> void:
	for h in _hordas.duplicate():
		var vivo = null
		for id in h.ids:
			vivo = arena.inimigos.por_id.get(id)
			if vivo:
				break
		if vivo:
			h.pos = vivo.pos
			continue
		_hordas.erase(h)
		arena.mensagem("Horda vencida!", Color(1, 0.9, 0.5))
		arena.coleta.soltar(h.pos, "bau")
		if alvo_fragmento() != "":
			var p: Dictionary = cfg().get("pity", {}).get("evento", {})
			if Sorte.pity("evento", float(p.get("base", 0.5)), float(p.get("passo", 0.25)), int(p.get("limite", 3))):
				arena.coleta.soltar(h.pos + Vector2(14, 0), "fragmento")


func _atualizar_desafios(dt: float) -> void:
	for d in _desafios.duplicate():
		var s: Dictionary = d.s
		var perto: bool = arena.jogador.position.distance_to(s.pos) < d.raio
		if perto:
			d.t -= dt
			d.avisou = false
			# os inimigos chegam espalhados ao longo do tempo
			d.acc += dt * d.falta / maxf(0.5, d.t + dt)
			while d.acc >= 1.0 and d.falta > 0:
				d.acc -= 1.0
				d.falta -= 1
				_cercar(s.pos, 1, ["bug", "popup", "spam"], false, Vector2(150, 230))
		elif not d.avisou:
			d.avisou = true
			arena.mensagem("Volte pro santuário!", Color(1, 0.5, 0.4))
		s["prog"] = clampf(1.0 - d.t / d.total, 0.001, 1.0)
		if d.t <= 0.0:
			_desafios.erase(d)
			s["prog"] = 1.0
			arena.anunciar("SANTUÁRIO VENCIDO", Color(0.6, 1, 0.6))
			dar_fragmento(alvo_fragmento())
