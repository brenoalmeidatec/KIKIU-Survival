extends Node
# Teste automático (#112 marco C): missão do chefe. Cada tipo (fragmentos, pilares, selos, invocar) cumprido libera o chefe;
# o chefe fica segurado enquanto a missão rola; estourou a tolerância, ele vem sozinho; fases/chefes diferentes pegam missões diferentes.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/missao_chefe.tscn  (imprime "MISSAOCHEFE falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Missao := preload("res://scripts/hordas/missao_chefe.gd")
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
	# --- dados e funções puras
	var c: Dictionary = Missao.cfg()
	var tipos: Dictionary = c.get("tipos", {})
	ok(c.has("_ajuda") and tipos.size() >= 4, "missoes_chefe.json: _ajuda e pelo menos 4 tipos (fragmentos, pilares, selos, invocar)")
	for t in ["fragmentos", "pilares", "selos", "invocar"]:
		ok(tipos.has(t), "tem o tipo " + t)
	var usados := {}
	for ch in c.por_chefe:
		for t in c.por_chefe[ch]:
			ok(tipos.has(t), "chefe %s aponta pra tipo que existe (%s)" % [ch, t])
			usados[t] = true
		ok(Dados.json("inimigos").has(ch), "chefe %s existe no inimigos.json" % ch)
	ok(usados.size() >= 4, "os chefes usam os 4 tipos de missão")
	# todo chefe de região tem missão (própria ou o padrão)
	var chefes_regiao := {}
	for r in Dados.json("regioes").regioes:
		chefes_regiao[str(r.chefe.chefe)] = true
		for f in r.fases:
			chefes_regiao[str(f.chefe)] = true
	for ch in chefes_regiao:
		ok(Missao.escolher({"chefe": ch}, 0) != "", "chefe %s sempre tem uma missão" % ch)
	ok(Missao.escolher({"chefe": "mae_do_lodo"}, 3) == "pilares", "Mãe do Lodo: pilares")
	ok(Missao.escolher({"chefe": "velho_carvalho"}, 3) == "invocar", "Velho Carvalho: só invocar")
	ok(Missao.escolher({"chefe": "rei_escaravelho"}, 3) == "fragmentos", "Rei Escaravelho: fragmentos")
	ok(Missao.escolher({"chefe": "chefe_que_nao_existe"}, 0) == "invocar", "chefe fora da lista: padrão (invocar)")
	ok(Missao.escolher({"chefe": "mae_do_lodo", "missao": false}, 0) == "", "fase com missao:false não tem missão")
	ok(Missao.escolher({"chefe": "mae_do_lodo", "missao": "selos"}, 0) == "selos", "fase pode forçar o tipo")
	ok(Missao.escolher({"chefe": "mae_do_lodo", "missao": "nada"}, 0) == "", "tipo forçado que não existe: sem missão")
	ok(Missao.escolher({"chefe": "bruxa_do_mato"}, 5) == Missao.escolher({"chefe": "bruxa_do_mato"}, 5), "a escolha é determinística (mesma semente)")
	var vistos := {}
	for i in 12:
		vistos[Missao.escolher({"chefe": "bruxa_do_mato"}, i)] = true
	ok(vistos.size() >= 2, "o mesmo chefe varia a missão de uma fase pra outra (%s)" % [vistos.keys()])
	ok(
		Missao.escolher({"chefe": "rainha_sapo"}, 0) in ["selos", "fragmentos"] and Missao.escolher({"chefe": "mae_do_lodo"}, 0) == "pilares",
		"fases de chefes diferentes: missões diferentes"
	)
	ok(Missao.carregar(0.0, true, 1.0, 3.5, 0.5) == 1.0 and Missao.carregar(3.0, true, 1.0, 3.5, 0.5) == 3.5, "pilar: carga sobe e para no total")
	ok(Missao.carregar(1.0, false, 1.0, 3.5, 0.5) == 0.5 and Missao.carregar(0.2, false, 1.0, 3.5, 0.5) == 0.0, "pilar: longe, a carga cai e para no zero")

	# --- na arena
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = false
	a.semente = 7
	add_child(a)
	await esperar(0.3)
	a.bot = false
	a.jogador.bot = false
	a.jogador.invencivel = 9999.0
	var d = a.diretor
	var m = a.missao
	var f: Dictionary = d.fase_atual()
	var dur: float = d.duracao()
	var tol := float(c.tolerancia)
	var inicio := float(c.inicio)

	for tid in ["fragmentos", "pilares", "selos", "invocar"]:
		a.inimigos.limpar()
		d.ir_para(d.fase_idx)  # zera o relógio e o chefe da fase
		a.jogador.invencivel = 9999.0
		var fase := f.duplicate()
		fase["missao"] = tid
		m.nova_fase(fase, 0)
		ok(m.est == Missao.NENHUM, "%s: antes do início a missão não existe" % tid)
		d.t_fase = inicio + 0.5
		m.atualizar(0.05)
		ok(m.est == Missao.ANDAMENTO and m.id == tid, "%s: a missão aparece depois de 'inicio'" % tid)
		ok(m.marcas().size() > 0, "%s: tem pontos de interesse marcados" % tid)
		ok(m.texto().size() == 3 and str(m.texto()[1]) != "", "%s: tem texto curto pro HUD" % tid)
		ok(m.alvo_bot(a.jogador.centro()) != null, "%s: o robô sabe pra onde ir" % tid)
		# o tempo da fase passou: com a missão rolando o chefe fica segurado
		d.t_fase = dur + 1.0
		d._eventos()
		ok(not d.final_chamado, "%s: passou a duração e o chefe continua segurado pela missão" % tid)
		ok(a.chefes().is_empty(), "%s: nenhum chefe em campo" % tid)
		_cumprir(a, m, tid)
		ok(m.est == Missao.CUMPRIDO, "%s: missão cumprida" % tid)
		ok(d.final_chamado and d.chefe_fase == str(f.chefe), "%s: cumprir libera o chefe da fase (%s)" % [tid, str(f.chefe)])
		ok(a.chefes().size() == 1, "%s: o chefe nasceu em campo" % tid)

	# --- invocar exige segurar confirmar
	a.inimigos.limpar()
	d.ir_para(d.fase_idx)
	var fi := f.duplicate()
	fi["missao"] = "invocar"
	m.nova_fase(fi, 0)
	d.t_fase = inicio + 0.5
	m.atualizar(0.05)
	a.jogador.position += m.altar - a.jogador.centro()
	for i in 60:
		m.atualizar(0.05)
	ok(m.est == Missao.ANDAMENTO and not d.final_chamado, "invocar: no altar mas sem segurar confirmar, nada acontece")
	a.jogador.position += m.altar + Vector2(300, 0) - a.jogador.centro()
	m.bot_segurar = true
	for i in 60:
		m.atualizar(0.05)
	ok(m.est == Missao.ANDAMENTO, "invocar: segurar longe do altar não vale")

	# --- fragmentos: tem que levar ao altar (coletar não basta)
	a.inimigos.limpar()
	d.ir_para(d.fase_idx)
	var ff := f.duplicate()
	ff["missao"] = "fragmentos"
	m.nova_fase(ff, 0)
	d.t_fase = inicio + 0.5
	m.atualizar(0.05)
	for p in m.pontos.duplicate():
		a.jogador.position += p.pos - a.jogador.centro()
		m.atualizar(0.05)
	ok(m.etapa == 1 and m.est == Missao.ANDAMENTO and not d.final_chamado, "fragmentos: coletou todos, falta levar ao altar")
	ok(m.marcas().size() == 1 and (m.marcas()[0] as Vector2).distance_to(m.altar) < 0.1, "fragmentos: depois de coletar, a marca é o altar")

	# --- tolerância: estourou, o chefe vem sozinho
	d.t_fase = dur + tol + 1.0
	m.atualizar(0.05)
	ok(m.est == Missao.FALHOU, "estourou a tolerância: a missão falha")
	d._eventos()
	ok(d.final_chamado and a.chefes().size() >= 1, "a missão falhou: o chefe vem sozinho (nunca trava)")

	# --- sem missão (não iniciou): o chefe vem no fim do tempo, como sempre
	a.inimigos.limpar()
	d.ir_para(d.fase_idx)
	var fn := f.duplicate()
	fn["missao"] = false
	m.nova_fase(fn, 0)
	d.t_fase = dur + 1.0
	m.atualizar(0.05)
	d._eventos()
	ok(m.est == Missao.NENHUM and d.final_chamado, "sem missão: o chefe vem no fim do tempo")

	# --- fase muda: a missão zera
	m.nova_fase(ff, 1)
	ok(m.est == Missao.NENHUM and m.pontos.is_empty() and m.id == "", "nova fase zera a missão")
	print("MISSAOCHEFE falhas=", falhas)
	get_tree().quit(1 if falhas > 0 else 0)


## Cumpre a missão como um jogador faria.
func _cumprir(a, m, tid: String) -> void:
	match tid:
		"fragmentos":
			for p in m.pontos.duplicate():
				a.jogador.position += p.pos - a.jogador.centro()
				m.atualizar(0.05)
			a.jogador.position += m.altar - a.jogador.centro()
			m.atualizar(0.05)
		"pilares":
			for p in m.pontos.duplicate():
				a.jogador.position += p.pos - a.jogador.centro()
				for i in 100:
					m.atualizar(0.05)
		"selos":
			for i in m._ids.duplicate():
				var v = a.inimigos.por_id.get(i)
				ok(v != null and v.elite, "selos: o portador é um elite")
				if v:
					a.inimigos.ferir(v, 1.0e9, Vector2.ZERO, "teste")
			m.atualizar(0.05)
		"invocar":
			a.jogador.position += m.altar - a.jogador.centro()
			m.bot_segurar = true
			for i in 60:
				m.atualizar(0.05)
