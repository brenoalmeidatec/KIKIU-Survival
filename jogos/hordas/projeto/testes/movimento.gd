extends Node
# Teste (#32 item 4 e 2): movimento do herói (parada rápida, velocidade máxima igual à de antes), flash e tremor ligados/desligados
# pelas opções, hitstop só no solo, e os props do cenário (mesma semente = mesmos props, nada com colisão, tetos de partículas).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/movimento.tscn  (imprime "MOVE falhas=0")
const J := preload("res://scripts/hordas/jogador.gd")
const Cenario := preload("res://scripts/hordas/cenario.gd")
const Ambiente := preload("res://scripts/hordas/ambiente.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


## Quantos quadros (de 1/60 s) a velocidade leva pra zerar depois de soltar a direção.
func tempo_de_parada(vmax: float) -> float:
	var v := Vector2(vmax, 0)
	var t := 0.0
	while v != Vector2.ZERO and t < 2.0:
		v = J.passo_vel(v, Vector2.ZERO, vmax, 1.0 / 60.0)
		t += 1.0 / 60.0
	return t


func assinatura(c, a: int, b: int) -> String:
	var s := ""
	for cy in range(a, b):
		for cx in range(a, b):
			var cel: Dictionary = c.celula(cx, cy)
			for p in cel.props:
				s += "%s@%s;" % [p.item.nome, p.pos]
			for d in cel.detalhes:
				s += "%s@%s;" % [d.tipo, d.pos]
			for bi in cel.bichos:
				s += "%s@%s;" % [bi.tipo, bi.pos]
	return s


func _ready() -> void:
	# ---- função pura
	for vmax in [60.0, 100.0, 130.0, 220.0]:
		ok(tempo_de_parada(vmax) <= 0.1, "para em até 0,1 s com vmax %s (levou %s)" % [vmax, tempo_de_parada(vmax)])
	var v := Vector2.ZERO
	var alvo := Vector2(0.6, 0.8) * 100.0
	for i in 30:
		v = J.passo_vel(v, alvo, 100.0, 1.0 / 60.0)
		ok(v.length() <= 100.0 + 0.001, "nunca passa da velocidade máxima")
	ok(v.is_equal_approx(alvo), "chega na velocidade máxima na diagonal (%s)" % v)
	ok(J.ACEL_TEMPO <= 0.1 and J.FREIO_TEMPO <= 0.1 and J.FREIO_TEMPO > 0.0, "constantes de aceleração e freio")
	# ---- no jogo
	var m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(0.3).timeout
	m._comecar("hazaki")
	var a = m._arena
	var j = a.jogador
	await get_tree().create_timer(1.0).timeout   # passa a entrada (queda) e o cenário carrega
	a.set_process(false)                          # os quadros daqui pra frente são do teste
	j.bot = false
	j.dash_t = 0.0
	var vmax: float = J.VEL_BASE * a.stat("velocidade")
	var x0: float = j.position.x
	Input.action_press("direita")
	for i in 60:
		j.atualizar(1.0 / 60.0)
	ok(is_equal_approx(j._vel.length(), vmax), "velocidade máxima igual à de antes (%s x %s)" % [j._vel.length(), vmax])
	var dist: float = j.position.x - x0
	ok(dist <= vmax and dist >= vmax * 0.95, "em 1 s andou ~vmax px (%s de %s)" % [dist, vmax])
	Input.action_release("direita")
	var n := 0
	while j._vel != Vector2.ZERO and n < 30:
		j.atualizar(1.0 / 60.0)
		n += 1
	ok(n / 60.0 <= 0.1, "herói para em até 0,1 s (%d quadros)" % n)
	ok(j.spr.scale.is_equal_approx(Vector2.ONE + j._sq + j._corpo.escala()), "squash aplicado no sprite")
	for i in 40:
		j.atualizar(1.0 / 60.0)
	ok(j._sq == Vector2.ZERO and j.spr.scale.is_equal_approx(Vector2.ONE + j._corpo.escala()), "squash volta ao normal parado (%s)" % j.spr.scale)
	ok(absf(j.spr.scale.y - 1.0) <= 0.05, "parado só respira (escala %s)" % j.spr.scale)
	# poeira com teto
	for i in 200:
		j._poeira_em(3, 10.0)
	ok(j._poeira.size() <= J.POEIRA_MAX, "poeira respeita o teto (%d)" % j._poeira.size())
	# ---- flash e tremor seguem as opções
	j.invencivel = 0.0
	a._tremor = 0.0
	Config.temporario("flash_dano", false)
	Config.temporario("tremor", 0.0)
	j.hp = 100.0
	j.sofrer(1.0)
	j.atualizar(0.001)
	ok(j._flash_t == 0.0 and j.spr.material == null, "flash desligado pela opção")
	ok(a._tremor == 0.0, "tremor desligado pela opção (%s)" % a._tremor)
	j.invencivel = 0.0
	Config.temporario("flash_dano", true)
	Config.temporario("tremor", 1.0)
	j.sofrer(1.0)
	j.atualizar(0.001)
	ok(j._flash_t > 0.0 and j.spr.material != null, "flash ligado: shader no sprite")
	ok(a._tremor > 0.0, "tremor ligado")
	for i in 30:
		j.atualizar(1.0 / 60.0)
	ok(j.spr.material == null, "flash acaba e o material sai")
	# ---- hitstop: só solo, só crítico/chefe, em tempo real
	a._hitstop_ate = 0
	a._hitstop_crit_ate = 0
	a.registrar_dano("", 1.0, Vector2.ZERO, false)
	ok(a._hitstop_ate == 0, "acerto normal não dá hitstop")
	a.registrar_dano("", 1.0, Vector2.ZERO, true)
	ok(a._hitstop_ate > Time.get_ticks_msec(), "crítico dá hitstop")
	a._hitstop_ate = 0
	a.registrar_dano("", 1.0, Vector2.ZERO, true)
	ok(a._hitstop_ate == 0, "crítico seguido respeita o intervalo mínimo")
	a.eh_online = true
	a._hitstop_crit_ate = 0
	a.registrar_dano("", 1.0, Vector2.ZERO, true)
	a.hitstop(0.1)
	ok(a._hitstop_ate == 0, "nunca no online")
	a.eh_online = false
	# ---- props do cenário
	var c1 = Cenario.new()
	var c2 = Cenario.new()
	for nome in ["laboratorio", "masmorra", "cidade"]:
		ok(c1.carregar(nome) and c2.carregar(nome), "carrega o cenário " + nome)
		Sorte.iniciar(123)
		var s1 := assinatura(c1, -6, 6)
		var s2 := assinatura(c2, -6, 6)
		ok(s1 != "" and s1 == s2, "%s: mesma semente, mesmos props em dois clientes" % nome)
		ok(assinatura(c1, -6, 6) == s1, "%s: sorteio estável ao reler a célula" % nome)
		Sorte.iniciar(124)
		ok(assinatura(c1, -6, 6) != s1, "%s: semente diferente, mapa diferente" % nome)
		Sorte.iniciar(123)
		ok(assinatura(c1, -6, 6) == s1, "%s: voltou à semente, voltou o mapa" % nome)
		var cfg: Dictionary = c1.cfg
		var total := 0
		for e in cfg.get("particulas", []):
			total += int(e.get("n", 0))
		ok(cfg.has("detalhes") and cfg.has("particulas") and cfg.has("vida"), "%s: detalhes, partículas e vida em dados/cenarios.json" % nome)
		ok(total <= Ambiente.MAX_PARTICULAS, "%s: partículas ambientes dentro do teto (%d)" % [nome, total])
		var props := 0
		for cy in range(-6, 6):
			for cx in range(-6, 6):
				props += c1.celula(cx, cy).props.size()
		ok(props >= 40, "%s: bem mais de um enfeite por tela (%d em 144 células)" % [nome, props])
	# ---- nada bloqueia: a árvore do chão e do ambiente não tem corpo físico
	var bloqueia := 0
	var pilha: Array = [a.chao]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		if no is CollisionObject2D or no is CollisionShape2D or no is CollisionPolygon2D or no is NavigationRegion2D or no is TileMapLayer:
			bloqueia += 1
		pilha.append_array(no.get_children())
	ok(bloqueia == 0, "props, detalhes e bichos sem colisão (%d nós físicos)" % bloqueia)
	ok(a.chao._amb._part.size() <= Ambiente.MAX_PARTICULAS, "partículas vivas dentro do teto (%d)" % a.chao._amb._part.size())
	print("MOVE falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
