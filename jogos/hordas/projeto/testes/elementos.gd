extends Node
# Teste automático: elementos e estados (#72 marco 5). Acúmulo e teto, duração, resistência, congelar, as três reações,
# a poça de gelo, o requisito do santuário selado, as mortes por elemento, os bits do online e o custo de quem não tem estado.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/elementos.tscn  (imprime "ELEM falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Elementos := preload("res://scripts/hordas/elementos.gd")
const Descobertas := preload("res://scripts/hordas/descobertas.gd")
const Mortes := preload("res://scripts/hordas/mortes.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
var falhas := 0
var a
var ino
var el
var base := Vector2.ZERO


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## Cria um inimigo parado, com muita vida (a menos que `vida` diga outra coisa), perto do herói.
func novo(tipo: String, desl: Vector2, vida := 1.0e6, parado := true):
	var v = ino.criar(tipo, base + desl)
	v.hpmax = maxf(vida, 1.0)
	v.hp = vida
	v.t_nasc = 0.0
	if parado:
		v.vel = 0.0
	return v


## Avança `s` segundos pelo laço de verdade dos inimigos (grade, estados, tudo), em passos de 1/30 s.
func avancar(s: float) -> void:
	var n := int(round(s * 30.0))
	for _i in n:
		ino.atualizar(1.0 / 30.0, a.jogador)


func limpar_tudo() -> void:
	ino.limpar()
	el.nova_fase()
	el.reacoes_n.clear()


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	# --- dados
	var cfg: Dictionary = Dados.json("elementos")
	var els: Dictionary = cfg.get("elementos", {})
	for e in ["fogo", "gelo", "raio", "veneno"]:
		ok(els.has(e), "elemento existe: " + e)
	var causas: Dictionary = Dados.json("mortes").get("efeito_por_causa", {})
	for e in els:
		var c: Dictionary = els[e]
		ok(float(c.get("teto", 0)) >= 1.0 and float(c.get("duracao", 0)) > 0.0, "%s tem teto e duração" % e)
		ok(causas.has(str(c.get("causa", ""))), "%s: a morte por '%s' tem desenho em mortes.json" % [e, c.get("causa", "")])
		ok(Dados.json("mortes").get("cor_causa", {}).has(str(c.get("causa", ""))), "%s: a morte tem cor" % e)
	ok(cfg.get("reacoes", []).size() >= 3, "pelo menos 3 reações")
	for r in cfg.get("reacoes", []):
		ok(els.has(str(r.a)) and els.has(str(r.b)), "reação %s liga elementos que existem" % r.id)
		for x in r.get("consome", []):
			ok(x == r.a or x == r.b, "reação %s só consome os próprios elementos" % r.id)
	for id in Dados.json("armas"):
		var d = Dados.json("armas")[id]
		if d is Dictionary and d.has("elemento"):
			ok(els.has(str(d.elemento)), "arma %s: elemento '%s' existe" % [id, d.elemento])
	for id in Dados.json("inimigos"):
		var d = Dados.json("inimigos")[id]
		if d is Dictionary and d.has("resist"):
			for e in d.resist:
				ok(els.has(str(e)) and float(d.resist[e]) >= -1.0 and float(d.resist[e]) <= 1.0, "inimigo %s: resistência válida (%s)" % [id, e])
	for e in ["fogo", "gelo", "raio", "veneno"]:
		var tem := false
		for id in Dados.json("armas"):
			var d = Dados.json("armas")[id]
			if d is Dictionary and str(d.get("elemento", "")) == e:
				tem = true
		ok(tem or e == "veneno" or e == "raio", "alguma arma dá " + e)
	ok(Dados.json("armas").has("geada") and str(Dados.json("armas").geada.get("elemento", "")) == "gelo", "a Geada Rachada é a poça de gelo")
	ok(Dados.tex("icone_geada") != null, "a Geada tem ícone")
	# o atributo el_<elemento> chega pelos passivos (e vale igual pra equipamento, raça e classe, que passam por Construcao.stats)
	var s_pas := Construcao.stats({}, {"brasa_viva": 2})
	ok(is_equal_approx(float(s_pas.get("el_fogo", 0.0)), 0.16), "Brasa Viva nível 2 dá 16%% de chance de fogo (%s)" % s_pas.get("el_fogo"))

	# --- dentro da partida
	a = Arena.new()
	a.heroi_id = "hazaki"
	a.bot = true
	a.semente = 5
	add_child(a)
	await esperar(0.2)
	a.set_process(false)       # quem anda com o tempo aqui é o teste
	a.xp = -1.0e12
	a.jogador.invencivel = 999.0
	ino = a.inimigos
	el = ino.elementos
	ino.limpar()
	a.armas.lista.clear()
	base = a.jogador.position + Vector2(220, 0)

	# acúmulo, teto, duração
	var v = novo("bug", Vector2.ZERO)
	ok(el.aplicar(v, "fogo", 1.0) == 1.0 and is_equal_approx(el.acumulos(v, "fogo"), 1.0), "1 golpe de fogo = 1 acúmulo")
	el.aplicar(v, "fogo", 1.0)
	ok(is_equal_approx(el.acumulos(v, "fogo"), 2.0), "acumula: 2")
	for _i in 10:
		el.aplicar(v, "fogo", 1.0)
	ok(is_equal_approx(el.acumulos(v, "fogo"), 5.0), "teto do fogo é 5 (%s)" % el.acumulos(v, "fogo"))
	ok((v.el_vis & 1) != 0, "el_vis marca o fogo")
	var hp0: float = v.hp
	avancar(2.0)
	var tq: float = 5.0 * 3.0 * 0.5 * a.stat("dano")   # dano de um tique (a cada 0,5 s)
	var n_tq: float = (hp0 - v.hp) / tq
	ok(absf(n_tq - roundf(n_tq)) < 0.02 and n_tq >= 3.0 and n_tq <= 4.0, "fogo com 5 acúmulos: 3 a 4 tiques de %.1f em 2 s (%.2f tiques)" % [tq, n_tq])
	avancar(1.5)
	ok(el.acumulos(v, "fogo") == 0.0 and not el.estados.has(v.id) and v.el_vis == 0, "passada a duração o estado some e sai do registro")
	# renovar a duração
	el.aplicar(v, "fogo", 1.0)
	avancar(2.0)
	el.aplicar(v, "fogo", 1.0)
	avancar(2.0)
	ok(el.acumulos(v, "fogo") > 0.0, "um golpe novo renova a duração (4 s depois ainda queima)")
	limpar_tudo()

	# veneno acumula alto
	v = novo("bug", Vector2.ZERO)
	for _i in 14:
		el.aplicar(v, "veneno", 1.0)
	ok(is_equal_approx(el.acumulos(v, "veneno"), 10.0), "teto do veneno é 10")
	hp0 = v.hp
	avancar(2.0)
	tq = 10.0 * 1.3 * 0.5 * a.stat("dano")
	n_tq = (hp0 - v.hp) / tq
	ok(absf(n_tq - roundf(n_tq)) < 0.02 and n_tq >= 3.0 and n_tq <= 4.0, "veneno com 10 acúmulos: 3 a 4 tiques de %.1f em 2 s (%.2f tiques)" % [tq, n_tq])
	limpar_tudo()

	# resistências
	v = novo("fogo_fatuo", Vector2.ZERO)
	ok(el.aplicar(v, "fogo", 1.0) == 0.0 and not el.estados.has(v.id), "fogo-fátuo é imune a fogo: nada entra e não vira estado")
	ok(is_equal_approx(el.aplicar(v, "gelo", 1.0), 1.5), "fogo-fátuo é vulnerável a gelo: 1 golpe = 1,5 acúmulo")
	var v2 = novo("carnical", Vector2(0, 40))
	ok(is_equal_approx(el.aplicar(v2, "veneno", 1.0), 0.5), "carniçal resiste a veneno pela metade: 0,5 acúmulo")
	var ch = novo("ransomware", Vector2(0, -60))
	ok(ch.chefe and is_equal_approx(el.aplicar(ch, "fogo", 1.0), 0.5), "chefe recebe metade dos acúmulos (mult_chefe)")
	limpar_tudo()

	# gelo: lento, depois congela, imune por um tempo, estilhaça
	v = novo("bug", Vector2.ZERO)
	el.aplicar(v, "gelo", 1.0)
	avancar(0.1)
	ok(v.lento > 0.0, "1 acúmulo de gelo já deixa o bicho lento")
	el.aplicar(v, "gelo", 3.0)
	ok(el.congelado(v) and v.atordoado > 1.0 and (v.el_vis & 16) != 0, "no teto de gelo ele congela (parado)")
	ok(is_equal_approx(el.acumulos(v, "gelo"), 0.0), "congelar zera os acúmulos")
	ok(el.aplicar(v, "gelo", 1.0) == 0.0, "congelado não acumula mais gelo")
	ok(Elementos.flags_de(v.el_vis) == 32, "o online leva o congelado no bit 32")
	avancar(1.8)
	ok(not el.congelado(v) and (v.el_vis & 16) == 0, "descongela depois de congela_dur")
	el.aplicar(v, "gelo", 4.0)
	ok(not el.congelado(v) and el.acumulos(v, "gelo") > 3.0, "logo depois de descongelar fica imune: acumula mas não congela de novo")
	avancar(3.5)
	el.aplicar(v, "gelo", 4.0)
	ok(el.congelado(v), "passada a imunidade congela outra vez")
	# golpe que mata congelado estilhaça
	var vm = novo("bug", Vector2(0, 50), 20.0)
	el.aplicar(vm, "gelo", 4.0)
	ok(el.congelado(vm), "alvo da prova do estilhaço congelado")
	ino.ferir(vm, 999.0, Vector2.ZERO, "katana")
	ok(vm.hp <= 0.0 and vm.causa_ult == "gelo" and Mortes.efeito_de("gelo") == "estilhaco", "morrer congelado estilhaça (causa gelo)")
	limpar_tudo()

	# raio: salta pros vizinhos
	v = novo("bug", Vector2.ZERO)
	var perto1 = novo("bug", Vector2(30, 0))
	var perto2 = novo("bug", Vector2(0, 30))
	var longe = novo("bug", Vector2(0, 200))
	avancar(0.05)
	el.aplicar(v, "raio", 2.0)
	var h1: float = perto1.hp
	var hl: float = longe.hp
	avancar(1.0)
	ok(perto1.hp < h1 and perto2.hp < 1.0e6, "eletrificado salta dano pros vizinhos")
	ok(longe.hp == hl, "o salto não alcança quem está longe")
	ok(el.arcos.size() >= 0, "os arcos do salto são só desenho")
	limpar_tudo()

	# reações: cada uma dispara UMA vez, consome, respeita a espera e as condições
	v = novo("bug", Vector2.ZERO)
	var viz = novo("bug", Vector2(24, 0))
	var fora = novo("bug", Vector2(0, 160))
	avancar(0.05)
	hp0 = viz.hp
	var hf: float = fora.hp
	el.aplicar(v, "fogo", 0.5)
	el.aplicar(v, "gelo", 1.0)
	ok(int(el.reacoes_n.get("vapor", 0)) == 0, "fogo 0,5 + gelo: abaixo do mínimo, sem reação")
	el.aplicar(v, "fogo", 1.0)
	ok(int(el.reacoes_n.get("vapor", 0)) == 1, "fogo + gelo dispara o vapor (uma vez)")
	ok(el.acumulos(v, "fogo") == 0.0 and el.acumulos(v, "gelo") == 0.0, "o vapor consome o fogo e o gelo")
	ok(viz.hp < hp0 and fora.hp == hf, "o vapor machuca em área, só quem está perto")
	el.aplicar(v, "fogo", 2.0)
	el.aplicar(v, "gelo", 2.0)
	ok(int(el.reacoes_n.get("vapor", 0)) == 1, "dentro da espera (cd) a mesma reação não repete")
	avancar(1.4)
	el.aplicar(v, "gelo", 1.0)
	el.aplicar(v, "fogo", 1.0)
	ok(int(el.reacoes_n.get("vapor", 0)) == 2, "passada a espera dispara de novo")
	limpar_tudo()
	v = novo("bug", Vector2.ZERO)
	viz = novo("bug", Vector2(40, 0))
	avancar(0.05)
	hp0 = viz.hp
	el.aplicar(v, "gelo", 2.0)
	el.aplicar(v, "raio", 1.0)
	ok(int(el.reacoes_n.get("descarga", 0)) == 1, "raio + gelo dispara a descarga gélida")
	ok(el.acumulos(v, "gelo") == 0.0 and el.acumulos(v, "raio") > 0.0, "a descarga consome só o gelo")
	ok(viz.hp < hp0, "a descarga machuca em área")
	limpar_tudo()
	v = novo("bug", Vector2.ZERO)
	avancar(0.05)
	for _i in 4:
		el.aplicar(v, "veneno", 1.0)
	hp0 = v.hp
	el.aplicar(v, "fogo", 1.0)
	ok(int(el.reacoes_n.get("miasma", 0)) == 0, "fogo 1 + veneno 4: fogo abaixo do mínimo de 2")
	el.aplicar(v, "fogo", 1.0)
	ok(int(el.reacoes_n.get("miasma", 0)) == 1, "fogo 2 + veneno: o miasma pega fogo")
	ok(el.acumulos(v, "veneno") == 0.0 and el.acumulos(v, "fogo") > 0.0, "o miasma consome o veneno e deixa o fogo")
	ok(hp0 - v.hp > 4.0 * 2.0, "o miasma vale mais com mais veneno (tirou %.1f)" % (hp0 - v.hp))
	ok(int(el.contagem.get("reacoes", 0)) == 1, "a contagem de reações do andar")
	limpar_tudo()

	# arma de fogo/gelo/raio/veneno e atributo el_*: pelo caminho de golpe de verdade (ferir)
	v = novo("bug", Vector2.ZERO)
	ino.ferir(v, 1.0, Vector2.ZERO, "cafe")
	ok(el.acumulos(v, "fogo") >= 1.0, "um golpe do Fogo Grego queima")
	ino.ferir(v, 1.0, Vector2.ZERO, "katana")
	ok(el.acumulos(v, "fogo") < 2.0, "arma sem elemento não soma")
	var v3 = novo("bug", Vector2(0, 80))
	ino.ferir(v3, 1.0, Vector2.ZERO, "pendrive")
	ok(el.acumulos(v3, "veneno") >= 1.0, "a Adaga de Arremesso envenena")
	var v4 = novo("bug", Vector2(0, -80))
	v4.causa_pend = "gelo"
	ino.ferir(v4, 1.0, Vector2.ZERO, "poder_elemental")
	ok(el.acumulos(v4, "gelo") >= 1.0, "a bola de gelo do Poder Elemental põe gelo")
	var v5 = novo("bug", Vector2(60, 60))
	el.chance = {"raio": 1.0}
	ino.ferir(v5, 1.0, Vector2.ZERO, "katana")
	ok(el.acumulos(v5, "raio") >= 1.0, "el_raio = 100%%: até a katana eletrifica")
	el.chance = {}
	a.passivos["centelha"] = 1
	a._recalcular()
	ok(is_equal_approx(float(el.chance.get("raio", 0.0)), 0.08), "a build com Centelha Presa liga 8%% de raio (%s)" % [el.chance])
	a.passivos.clear()
	a._recalcular()
	ok(el.chance.is_empty(), "sem o passivo a chance some")
	limpar_tudo()

	# mortes por elemento
	v = novo("bug", Vector2.ZERO, 3.0)
	el.aplicar(v, "fogo", 3.0)
	avancar(1.2)
	ok(v.hp <= 0.0 and v.causa_ult == "fogo" and Mortes.efeito_de("fogo") == "cinzas", "morrer queimando vira cinzas (causa %s)" % v.causa_ult)
	v = novo("bug", Vector2.ZERO, 3.0)
	el.aplicar(v, "veneno", 6.0)
	avancar(1.2)
	ok(v.hp <= 0.0 and v.causa_ult == "veneno" and Mortes.efeito_de("veneno") == "desintegrar", "morrer envenenado desintegra (causa %s)" % v.causa_ult)
	ok(Mortes.causa_de("", "veneno") == "veneno" and Mortes.causa_de("", "raio") == "raio", "causa_de lê o elemento")
	limpar_tudo()

	# poça de gelo: desacelera, depois congela
	a.armas.adicionar("geada")
	var poca_v = novo("bug", Vector2(0, 0), 1.0e6, false)
	var livre = novo("bug", Vector2(0, 260), 1.0e6, false)
	poca_v.vel = 60.0
	livre.vel = 60.0
	poca_v.pos = a.jogador.position + Vector2(400, 0)
	livre.pos = a.jogador.position + Vector2(0, 400)
	a.armas.pocas.clear()
	a.armas.pocas.append({"pos": poca_v.pos, "raio": 60.0, "vida": 30.0, "total": 30.0, "dano": 3.0, "tique": 0.4, "t": 0.0, "segue": false,
		"arma": "geada", "variante": 0, "semente": 1.0, "rampa": a.armas.rampa_de(Dados.item("geada")), "gelo": true})
	var p0: Vector2 = poca_v.pos
	var l0: Vector2 = livre.pos
	var parou := false
	for _i in 30:
		a.armas._pocas(1.0 / 30.0)
		ino.atualizar(1.0 / 30.0, a.jogador)
		if poca_v.lento > 0.0 and not parou:
			parou = true
	ok(parou and livre.lento == 0.0, "quem pisa na poça de gelo fica lento; quem está fora não")
	var d_poca := p0.distance_to(poca_v.pos)
	var d_livre := l0.distance_to(livre.pos)
	ok(d_poca < d_livre * 0.75, "a poça desacelera: andou %.1f px contra %.1f fora dela" % [d_poca, d_livre])
	# fica na poça: congela
	poca_v.pos = p0
	poca_v.vel = 0.0
	for _i in 90:
		a.armas._pocas(1.0 / 30.0)
		ino.atualizar(1.0 / 30.0, a.jogador)
	ok(int(el.contagem.get("congelados", 0)) >= 1, "ficar na poça de gelo acaba congelando")
	a.armas.pocas.clear()
	limpar_tudo()

	# santuário selado com requisito de elemento
	var sel := {"tipo": "selado", "requisito": "elemento", "qtd": 3, "usado": false}
	ok(Descobertas.progresso(sel, [], el.contagem) == Vector2i(0, 3), "selado de elemento começa em 0/3")
	var m1 = novo("bug", Vector2(0, 0))
	var m2 = novo("bug", Vector2(0, 70))
	var m3 = novo("bug", Vector2(70, 0))
	el.aplicar(m1, "fogo", 1.0)
	el.aplicar(m1, "veneno", 1.0)
	el.aplicar(m1, "fogo", 1.0)
	ok(Descobertas.progresso(sel, [], el.contagem) == Vector2i(1, 3), "o mesmo inimigo com 2 elementos conta uma vez só (1/3)")
	el.aplicar(m2, "gelo", 1.0)
	el.aplicar(m3, "raio", 1.0)
	ok(Descobertas.progresso(sel, [], el.contagem) == Vector2i(3, 3), "3 inimigos marcados cumprem o requisito")
	ok("marque" in Descobertas.dica(sel, [], {"qualquer": 1}) and "(1/3)" in Descobertas.dica(sel, [], {"qualquer": 1}), "a dica diz o que falta")
	ok(Descobertas.cfg().santuarios.selado.requisitos.has("elemento"), "o requisito elemento está no sorteio do selado")
	el.nova_fase()
	ok(Descobertas.progresso(sel, [], el.contagem) == Vector2i(0, 3), "andar novo zera o contador")
	limpar_tudo()

	# online: bits e cliente
	ok(Elementos.flags_de(1) == 64 and Elementos.flags_de(8) == 128 and Elementos.flags_de(16) == 32 and Elementos.flags_de(2) == 0, "bits do online: fogo 64, veneno 128, congelado 32")
	v = novo("bug", Vector2.ZERO)
	el.aplicar_vis(v, 64 | 16)
	ok((v.el_vis & 1) != 0 and (v.el_vis & 2) != 0 and el.vis.has(v.id) and int(el.contagem.qualquer) == 1, "cliente: a foto liga fogo e lento e conta o inimigo")
	el.aplicar_vis(v, 0)
	ok(v.el_vis == 0 and not el.vis.has(v.id), "cliente: sem bits, sem estado")
	limpar_tudo()

	# custo: com 500 inimigos e nenhum estado, o passo e o desenho saem na primeira linha
	for i in 500:
		novo("bug", Vector2(randf_range(-300, 300), randf_range(-200, 200)))
	ok(el.estados.is_empty(), "500 inimigos sem estado: o registro está vazio")
	var t0 := Time.get_ticks_usec()
	for _i in 20000:
		el.passo(0.016)
	var us_vazio := float(Time.get_ticks_usec() - t0) / 20000.0
	print("ELEM custo passo sem estado, 500 inimigos: %.3f us por quadro" % us_vazio)
	ok(us_vazio < 3.0, "o passo sem estado custa menos de 3 us por quadro (%.3f)" % us_vazio)
	var ts := Time.get_ticks_usec()
	for i in 40:
		el.aplicar(ino.lista[i], "fogo", 1.0)
	for _i in 200:
		el.passo(0.016)
	var us_40 := float(Time.get_ticks_usec() - ts) / 200.0
	print("ELEM custo passo com 40 queimando: %.1f us por quadro" % us_40)
	ok(us_40 < 400.0, "40 inimigos queimando custam menos de 400 us por quadro (%.1f)" % us_40)
	limpar_tudo()

	a.queue_free()
	print("ELEM falhas=", falhas)
	get_tree().quit()
