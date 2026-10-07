extends Node
# Teste automático: combate com peso (estilo Dimraeth). Meia-lua, estrela de impacto e faíscas têm teto e somem
# sozinhas; o número de dano só usa tamanhos múltiplos de 8 (a fonte é pixel); o golpe do corpo sai e volta ao
# lugar; a katana solta a meia-lua e faz o herói (sem quadros de ataque) avançar na direção do golpe.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/golpes.tscn  (imprime "GOLPES falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Jogador := preload("res://scripts/hordas/jogador.gd")
const Efeitos := preload("res://scripts/hordas/efeitos.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	_efeitos()
	_numeros()
	_pose()
	await _katana()
	print("GOLPES falhas=%d" % falhas)
	get_tree().quit()


func _efeitos() -> void:
	var e := Efeitos.new()
	add_child(e)
	e.corte(Vector2.ZERO, 0.0, 2.0, 50.0, Color.WHITE, -1.0, 0.16)
	ok(e.cortes.size() == 1, "corte nasce")
	e.atualizar(0.1)
	ok(e.cortes.size() == 1, "corte ainda vivo no meio")
	e.atualizar(0.1)
	ok(e.cortes.is_empty(), "corte some sozinho depois da duração")
	for i in Efeitos.MAX_CORTES + 10:
		e.corte(Vector2.ZERO, 0.0, 2.0, 50.0, Color.WHITE)
	ok(e.cortes.size() == Efeitos.MAX_CORTES, "teto de cortes (%d)" % e.cortes.size())
	e.limpar()
	for i in 40:   # arma de área: 40 acertos no mesmo quadro
		e.impacto(Vector2(i, 0))
	ok(e.impactos.size() == Efeitos.IMPACTOS_QUADRO, "no máximo %d estrelas novas por quadro (%d)" % [Efeitos.IMPACTOS_QUADRO, e.impactos.size()])
	e.atualizar(0.01)
	e.impacto(Vector2.ZERO)
	ok(e.impactos.size() == Efeitos.IMPACTOS_QUADRO + 1, "o limite por quadro zera no quadro seguinte")
	e.atualizar(Efeitos.IMPACTO_VIDA + 0.01)
	ok(e.impactos.is_empty(), "estrelas somem sozinhas")
	for i in 200:
		e.faisca(Vector2.ZERO, Vector2.RIGHT, Color.WHITE, 5)
	ok(e.faiscas.size() == Efeitos.MAX_FAISCAS, "teto de faíscas (%d)" % e.faiscas.size())
	e.atualizar(0.5)
	ok(e.faiscas.is_empty(), "faíscas somem sozinhas")
	e.queue_free()


func _numeros() -> void:
	for base in [8, 16]:
		for pop in [0.0, Efeitos.POP * 0.25, Efeitos.POP * 0.75, Efeitos.POP]:
			var t := Efeitos.tamanho_numero(base, pop)
			ok(t % 8 == 0 and t >= base and t <= base * 2, "número %d no soco %.3f usa tamanho múltiplo de 8 (%d)" % [base, pop, t])
	ok(Efeitos.tamanho_numero(8, Efeitos.POP) == 16 and Efeitos.tamanho_numero(16, Efeitos.POP) == 32, "o soco dobra o tamanho")
	ok(Efeitos.tamanho_numero(8, 0.0) == 8 and Efeitos.tamanho_numero(16, 0.0) == 16, "depois do soco volta ao normal")


func _pose() -> void:
	var p0 := Jogador.pose_golpe(0.0)
	var p1 := Jogador.pose_golpe(1.0)
	var pico := Jogador.pose_golpe(0.4)
	ok(p0.length() < 0.001 and p1.length() < 0.001, "o golpe do corpo começa e termina no lugar")
	ok(is_equal_approx(pico.x, Jogador.GOLPE_AVANCO), "no auge o corpo avança %.0f px (%.2f)" % [Jogador.GOLPE_AVANCO, pico.x])
	ok(Jogador.pose_golpe(0.15).x < 0.0, "antecipação: recua antes de avançar")


func _katana() -> void:
	var a := Arena.new()
	a.heroi_id = "beto"   # 9 colunas: sem quadros de ataque, só o golpe do corpo
	add_child(a)
	await esperar(1.6)
	a.bot = false
	a.jogador.bot = false
	a.jogador.invencivel = 999.0
	a.inimigos.limpar()
	a.armas.lista.clear()
	a.armas.adicionar("katana")
	var j = a.jogador
	var v = a.inimigos.criar("jacare_lodo", j.position + Vector2(40, 0), 1)
	ok(v != null, "inimigo de teste nasceu")
	if v:
		v.vel = 0.0
		v.t_nasc = 0.0
	a.efeitos.limpar()
	a.armas.achar("katana").t = 0.0
	await esperar(0.06)
	ok(not a.efeitos.cortes.is_empty(), "a katana solta a meia-lua no efeitos.gd")
	ok(j._golpe_t > 0.0, "o herói sem quadros de ataque também golpeia (golpe do corpo)")
	ok(j._golpe_vira and j._golpe_dir.x > 0.5, "o golpe vai na direção do inimigo (%s)" % j._golpe_dir)
	ok(j.spr.position.x != 0.0 or j.spr.scale != Vector2.ONE, "o corpo se mexe no golpe (pos %s, escala %s)" % [j.spr.position, j.spr.scale])
	await esperar(Jogador.GOLPE_TEMPO + 0.05)
	ok(j.spr.position.x == 0.0 and j.spr.rotation == 0.0, "depois do golpe o corpo volta ao lugar")
	var antes: int = a._golpe_ate
	a.golpe_pesado(1.0)
	var depois: int = a._golpe_ate
	a.golpe_pesado(1.0)
	ok(a._golpe_ate == depois and depois >= antes, "golpe pesado tem intervalo mínimo")
	ok(not a._tem_impacto("cafe") and a._tem_impacto("katana"), "poça não solta estrela a cada tique; katana solta")
	a.queue_free()
