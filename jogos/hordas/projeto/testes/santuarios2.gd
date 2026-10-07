extends Node
# Teste automático (#63, parte 2): santuário de prova, santuário selado (pré-requisito), dádivas em dupla.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/santuarios2.tscn  (imprime "SANT2 falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
const Descobertas := preload("res://scripts/hordas/descobertas.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func plano(semente: int, n_fases := 10, tomadas := 3) -> Array:
	Sorte.iniciar(semente)
	var res := []
	for f in n_fases:
		res.append(Descobertas.planejar_fase(f, n_fases, tomadas, Vector2.ZERO))
	return res

func santuario(tipo: String, extra := {}) -> Dictionary:
	var s := {"pos": Vector2.ZERO, "tipo": tipo, "variacao": "", "carga": 1.0, "usado": false}
	s.merge(extra)
	return s

func fechar_cartas(a) -> void:
	if a.cartas.aberto():
		await esperar(0.8)
		a.cartas._confirmar()
		await esperar(0.1)

func _ready() -> void:
	# --- plano: determinístico, prova/selado/relíquia aparecem, regras de posição e consistência do pré-requisito ---
	ok(JSON.stringify(plano(31)) == JSON.stringify(plano(31)), "mesma semente: mesmo plano (inclui prova e selado)")
	ok(JSON.stringify(plano(31)) != JSON.stringify(plano(32)), "semente diferente: plano diferente")
	var n_prova := 0
	var n_selado := 0
	var requisitos := {}
	var dist_ruim := false
	var incoerente := false
	for sem in 120:
		for fase in plano(sem):
			var especiais: Array = fase.filter(func(s): return s.tipo != "tomada")
			for i in especiais.size():
				if especiais[i].pos.length() < 380.0:
					dist_ruim = true
				for j in range(i + 1, especiais.size()):
					if especiais[i].pos.distance_to(especiais[j].pos) < 419.0:
						dist_ruim = true
			var n_tomadas: int = fase.filter(func(s): return s.tipo == "tomada").size()
			var n_rel: int = fase.filter(func(s): return s.tipo == "reliquia").size()
			n_prova += fase.filter(func(s): return s.tipo == "prova").size()
			for s in fase:
				if s.tipo != "selado":
					continue
				n_selado += 1
				requisitos[s.requisito] = true
				if s.requisito == "reliquia" and n_rel < 1:
					incoerente = true
				if s.requisito == "piras" and (s.qtd > n_tomadas or s.qtd < 1):
					incoerente = true
	ok(n_prova > 10 and n_selado > 10, "provas e selados aparecem nas sementes (%d, %d)" % [n_prova, n_selado])
	ok(requisitos.has("piras") and requisitos.has("reliquia"), "os dois pré-requisitos saem (%s)" % [requisitos.keys()])
	ok(not dist_ruim, "prova, selado e relíquia respeitam as distâncias dos santuários especiais")
	ok(not incoerente, "selado de relíquia tem relíquia na fase; de piras não pede mais piras do que existem")
	# sem tomadas na fase, o selado nunca pede piras
	var sem_piras := true
	for sem in 60:
		for fase in plano(sem, 10, 0):
			for s in fase:
				if s.tipo == "selado" and s.requisito == "piras":
					sem_piras = false
	ok(sem_piras, "fase sem tomadas: selado pede relíquia")

	# --- duo de dádivas: só com os requisitos ---
	var viu_duo_sem := false
	for sem in 200:
		Sorte.iniciar(sem)
		for tenho in [[], ["furia"], ["vento"], ["furia", "olho", "pedra"] if false else ["pedra", "olho"]]:
			for c in Descobertas.oferta_dadivas(Sorte.fluxo("dadiva"), "", tenho):
				if c.raridade == "dupla":
					viu_duo_sem = true
	ok(not viu_duo_sem, "dádiva em dupla nunca aparece sem as duas dádivas exigidas")
	ok(Descobertas.duplas_disponiveis(["furia", "vento"]) == ["tormenta"], "furia+vento libera só a Tormenta Carmesim (%s)" % [Descobertas.duplas_disponiveis(["furia", "vento"])])
	ok(Descobertas.duplas_disponiveis(["furia", "vento", "tormenta"]).is_empty(), "dupla já pega não é oferecida de novo")
	var viu := 0
	var ruim := false
	var tamanho_ok := true
	Sorte.iniciar(77)
	for i in 200:
		var of := Descobertas.oferta_dadivas(Sorte.fluxo("dadiva"), "", ["furia", "vento", "olho"])
		for c in of:
			if c.raridade == "dupla":
				viu += 1
				if not c.id in ["tormenta", "mira"]:
					ruim = true
				if c.desc.find("+") < 0 or c.nome == "":
					ruim = true
		tamanho_ok = tamanho_ok and of.size() in [3, 4]
	ok(viu > 100 and not ruim, "com os requisitos a dupla aparece (%d de 200) e só as permitidas" % viu)
	ok(tamanho_ok, "oferta: 3 dádivas, mais a dupla quando liberada")
	Sorte.iniciar(5)
	var o1 := JSON.stringify(Descobertas.oferta_dadivas(Sorte.fluxo("dadiva"), "", ["furia", "vento"]))
	Sorte.iniciar(5)
	var o2 := JSON.stringify(Descobertas.oferta_dadivas(Sorte.fluxo("dadiva"), "", ["furia", "vento"]))
	ok(o1 == o2, "oferta com dupla é igual com a mesma semente")

	# --- na arena ---
	Engine.time_scale = 3.0
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.semente = 12
	add_child(a)
	await esperar(0.3)
	a.xp = -1.0e12
	var d = a.descobertas
	a.chao.santuarios.clear()
	# dupla aplicada: soma os dois atributos e fica no HUD como dádiva
	d.dadivas.append({"id": "furia", "raridade": "comum"})
	d.dadivas.append({"id": "vento", "raridade": "comum"})
	a._recalcular()
	var dano0: float = a.stat("dano")
	var vel0: float = a.stat("velocidade")
	var carta_duo: Dictionary = Descobertas._carta_dupla("tormenta")
	a.escolheu(carta_duo)
	ok(a.stat("dano") > dano0 + 0.1 and a.stat("velocidade") > vel0 + 0.08, "a dupla soma os dois efeitos (dano %.2f>%.2f, vel %.2f>%.2f)" % [a.stat("dano"), dano0, a.stat("velocidade"), vel0])
	ok(d.dadivas.size() == 3 and d.dadivas[2].raridade == "dupla", "a dupla entra na lista de dádivas")
	# o santuário de dádiva passa as dádivas que o jogador já tem pra oferta (a dupla já pega não volta)
	d.dadivas.append({"id": "olho", "raridade": "comum"})
	var sd := santuario("dadiva")
	d.ativar(sd)
	var cartas: Array = a.cartas._cartas
	ok(sd.usado and a.cartas.aberto(), "santuário de dádiva abriu a escolha")
	ok(not cartas.any(func(c): return c.id == "tormenta"), "a dupla já pega não é oferecida de novo")
	await fechar_cartas(a)

	# --- selado: relíquia ---
	var sel := santuario("selado", {"requisito": "reliquia", "qtd": 1})
	var rel := santuario("reliquia")
	a.chao.santuarios = [sel, rel]
	ok(Descobertas.progresso(sel, a.chao.santuarios) == Vector2i(0, 1), "selado: relíquia ainda não pega (0/1)")
	d.ativar(sel)
	ok(not sel.usado and sel.carga == 0.0 and not a.cartas.aberto(), "selado fechado: não abre, zera a carga")
	ok(Descobertas.dica(sel, a.chao.santuarios).find("relíquia") >= 0, "a dica diz o que falta (%s)" % Descobertas.dica(sel, a.chao.santuarios))
	d.ativar(rel)
	ok(rel.usado and Descobertas.progresso(sel, a.chao.santuarios) == Vector2i(1, 1), "pegar a relíquia cumpre o pré-requisito")
	sel.carga = 1.0
	d.ativar(sel)
	ok(sel.usado and a.cartas.aberto(), "selado liberado oferece a dádiva")
	var raridade_ok := true
	for c in a.cartas._cartas:
		if c.raridade == "comum":
			raridade_ok = false
	ok(raridade_ok, "selado só oferece raridade rara ou melhor")
	await fechar_cartas(a)

	# --- selado: piras ---
	var t1 := santuario("tomada")
	var t2 := santuario("tomada")
	var sel2 := santuario("selado", {"requisito": "piras", "qtd": 2})
	a.chao.santuarios = [t1, t2, sel2]
	d.ativar(sel2)
	ok(not sel2.usado and not a.cartas.aberto(), "selado de piras fechado com 0/2")
	t1.usado = true
	ok(Descobertas.progresso(sel2, a.chao.santuarios) == Vector2i(1, 2), "uma pira acesa: 1/2")
	sel2.carga = 1.0
	d.ativar(sel2)
	ok(not sel2.usado and not a.cartas.aberto(), "selado de piras ainda fechado com 1/2")
	t2.usado = true
	sel2.carga = 1.0
	d.ativar(sel2)
	ok(sel2.usado and a.cartas.aberto(), "acendeu as 2 piras: o selado libera a dádiva")
	await fechar_cartas(a)

	# --- prova: vence ---
	a.jogador.position = Vector2.ZERO
	var p1 := santuario("prova", {"pos": Vector2(60, 0)})
	a.chao.santuarios = [p1]
	var antes: int = a.inimigos.lista.size()
	d.ativar(p1)
	var pv: Dictionary = d._provas[0] if not d._provas.is_empty() else {}
	var cfgp: Dictionary = Descobertas.cfg().santuarios.prova
	ok(p1.usado and not pv.is_empty() and pv.ids.size() == 1 + int(cfgp.escoltas) and not pv.local, "prova nasce com mini-chefe e %d escoltas" % int(cfgp.escoltas))
	var chefe = a.inimigos.por_id.get(pv.ids[0])
	ok(chefe != null and chefe.elite and chefe.hpmax > 6.0 * float(Dados.json("inimigos").trojan.vida), "o mini-chefe é um elite com vida extra (%.0f)" % (chefe.hpmax if chefe else 0.0))
	ok(a.inimigos.lista.size() >= antes + 1 + int(cfgp.escoltas), "os inimigos da prova existem no mundo")
	for id in pv.ids.duplicate():
		var v = a.inimigos.por_id.get(id)
		if v:
			a.inimigos.ferir(v, 1.0e9)
	d._atualizar_provas(0.1)
	ok(d._provas.is_empty() and p1.prog >= 1.0, "todos mortos antes do tempo: prova vencida")
	ok(not d._premios.is_empty() or a.cartas.aberto(), "vencer dá recompensa")
	d.atualizar(0.0)
	await esperar(0.2)
	ok(a.cartas.aberto() and a.cartas._cartas.all(func(c): return c.raridade in ["epica", "heroica"] or c.raridade == "dupla"), "recompensa da prova é de raridade rara+ (épica ou melhor)")
	ok(a.coleta.itens.any(func(it): return it.tipo == "bau"), "a prova vencida solta um baú")
	await fechar_cartas(a)

	# --- prova: perde (o tempo acaba) ---
	var p2 := santuario("prova", {"pos": Vector2(80, 0)})
	a.chao.santuarios = [p2]
	d.ativar(p2)
	var pv2: Dictionary = d._provas[0]
	var sobreviventes_antes := 0
	for id in pv2.ids:
		if a.inimigos.por_id.get(id):
			sobreviventes_antes += 1
	pv2.t = 0.05
	d._atualizar_provas(0.1)
	var sobrevivem := 0
	for id in pv2.ids:
		if a.inimigos.por_id.get(id):
			sobrevivem += 1
	ok(d._provas.is_empty() and p2.prog == 0.0 and d._premios.is_empty() and not a.cartas.aberto(), "tempo esgotado: prova perdida, sem recompensa")
	ok(sobrevivem == sobreviventes_antes and sobrevivem > 0, "ao perder, os inimigos continuam (%d)" % sobrevivem)

	# --- prova no cliente online (sem vírus próprios): vale sobreviver o tempo perto ---
	a.inimigos.espelho = true
	var p3 := santuario("prova", {"pos": Vector2(50, 0)})
	a.chao.santuarios = [p3]
	d.ativar(p3)
	var pv3: Dictionary = d._provas[0]
	ok(pv3.ids.is_empty() and pv3.local, "cliente online: prova vira sobreviver o tempo perto")
	pv3.t = 0.2
	a.jogador.position = Vector2(2000, 2000)
	d._atualizar_provas(0.5)
	ok(not d._provas.is_empty() and pv3.t == 0.2, "longe do santuário o tempo não conta")
	a.jogador.position = Vector2.ZERO
	d._atualizar_provas(0.5)
	ok(d._provas.is_empty() and not d._premios.is_empty(), "perto, o tempo passa e a prova é vencida")
	a.inimigos.espelho = false
	# trocar de andar (lista de santuários nova) descarta a prova em andamento
	d._premios.clear()
	var p4 := santuario("prova", {"pos": Vector2(70, 0)})
	a.chao.santuarios = [p4]
	d.ativar(p4)
	a.chao.santuarios = []
	d._atualizar_provas(0.1)
	ok(d._provas.is_empty() and d._premios.is_empty(), "mudou de andar: a prova em andamento some sem recompensa")

	Engine.time_scale = 1.0
	print("SANT2 falhas=", falhas)
	get_tree().quit()
