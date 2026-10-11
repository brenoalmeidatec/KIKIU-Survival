extends Node
# Teste: mortes violentas e finalizações de chefe (#32, comentário do Breno).
#  - cada causa de golpe escolhe o efeito certo (tabela de dados + elemento da bola do Poder Elemental);
#  - o inimigo que morre de verdade (inimigos.ferir) vira o registro certo; longe da tela não gasta nada;
#  - teto: 500 mortes de uma vez não passam de `mortes`/`particulas`/`simples` e nada estoura;
#  - opção "Mortes violentas" = Reduzida: nada de partes nem sangue (conferido no DESENHO, com um canvas de mentira);
#  - finalização por arma, restaura câmera lenta e zoom no fim e mesmo se a arena fechar no meio; online sem câmera lenta.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/mortes.tscn  (imprime "MORTE falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Mortes := preload("res://scripts/hordas/mortes.gd")
const Finalizacao := preload("res://scripts/hordas/finalizacao.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## Canvas de mentira: conta o que o desenho pediu (headless não pinta; é o nível que dá pra observar aqui).
class Gravador:
	var regioes := 0          # draw_texture_rect_region (corpo = 1; pedaços/faixas = vários)
	var poligonos_tex := 0    # draw_polygon com a textura do sprite (metades e cacos)
	var sangue := 0           # qualquer coisa vermelho-escura (gotas, corte aberto, buracos)
	var total := 0

	func _cor(c: Color) -> void:
		total += 1
		if c.r > 0.2 and c.g < 0.13 and c.b < 0.16 and c.a > 0.0:
			sangue += 1

	func draw_set_transform(_p = null, _r = 0.0, _s = null) -> void:
		pass

	func draw_texture_rect_region(_t, _r, _s, c = Color.WHITE) -> void:
		regioes += 1
		total += 1

	func draw_polygon(_pts, cores, _uv = null, tex = null) -> void:
		total += 1
		if tex != null:
			poligonos_tex += 1
		for c in cores:
			_cor(c)

	func draw_circle(_p, _r, c) -> void:
		_cor(c)

	func draw_rect(_r, c, _fill = true) -> void:
		_cor(c)

	func draw_line(_a, _b, c, _w = 1.0) -> void:
		_cor(c)

	func draw_polyline(_p, c, _w = 1.0) -> void:
		_cor(c)

	func draw_arc(_c, _r, _a, _b, _n, c, _w = 1.0) -> void:
		_cor(c)

	func partes() -> int:
		return poligonos_tex + maxi(0, regioes - 1)


func nova() -> Node:
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = true
	add_child(a)
	await esperar(0.2)
	return a


## Mata um inimigo comum perto do herói com a arma dada (e, se quiser, o elemento da bola). Devolve o efeito escolhido.
func matar(a: Node, arma: String, elem := "", dx := 60.0) -> String:
	var v = a.inimigos.criar("bug", a.jogador.position + Vector2(dx, 20))
	v.causa_pend = elem
	a.mortes.ult_efeito = "?"
	a.inimigos.ferir(v, 1.0e9, Vector2(40, 0), arma)
	return a.mortes.ult_efeito


func _ready() -> void:
	Config.g_perfil_temporario("alto")
	Config.temporario("mortes", "normal")
	Config.temporario("tremor", 1.0)
	var dm: Dictionary = Dados.json("mortes")
	var df: Dictionary = Dados.json("finalizacoes")

	# ---------- dados coerentes ----------
	var causas: Dictionary = dm.efeito_por_causa
	for arma in dm.causa_por_arma:
		ok(causas.has(dm.causa_por_arma[arma]), "causa da arma %s existe" % arma)
	for ef in causas.values():
		ok(dm.efeitos.has(ef), "efeito %s tem duração e partículas" % ef)
	for k in df.por_arma:
		ok(df.finalizacoes.has(df.por_arma[k]), "finalização %s existe" % df.por_arma[k])
	for k in df.por_causa:
		ok(df.finalizacoes.has(df.por_causa[k]), "finalização por causa %s existe" % k)
	for arma in Dados.json("armas"):
		if str(arma).begins_with("_"):
			continue
		ok(causas.has(Mortes.causa_de(str(arma))), "toda arma do armas.json tem causa (%s)" % arma)

	# ---------- causa e efeito (funções puras) ----------
	var casos := {"katana": "corte", "desert_eagles": "tiro", "arte_marcial": "impacto", "aura_hazaki": "aura", "baforada": "fogo",
		"wifi": "raio", "energia_draconica": "explosao", "garrafa_termica": "padrao", "cabo_rede": "corte", "": "padrao", "arma_que_nao_existe": "padrao"}
	for arma in casos:
		ok(Mortes.causa_de(arma) == casos[arma], "causa de '%s' = %s (deu %s)" % [arma, casos[arma], Mortes.causa_de(arma)])
	ok(Mortes.causa_de("poder_elemental", "gelo") == "gelo", "elemental gelo")
	ok(Mortes.causa_de("poder_elemental", "raio") == "raio", "elemental raio")
	ok(Mortes.causa_de("poder_elemental", "fogo") == "fogo", "elemental fogo")
	ok(Mortes.causa_de("katana", "") == "corte", "elemento vazio não atrapalha")
	var efs := {"fogo": "cinzas", "gelo": "estilhaco", "raio": "choque", "corte": "corte", "impacto": "pedacos", "explosao": "pedacos", "tiro": "furo", "aura": "desintegrar", "padrao": "simples"}
	for c in efs:
		ok(Mortes.efeito_de(c) == efs[c], "efeito da causa %s = %s" % [c, efs[c]])
		ok(Mortes.efeito_de(c, true) == ("simples" if c == "padrao" else "suave"), "reduzida: %s vira suave" % c)
	var fins := {"katana": "katana", "desert_eagles": "pistolas", "arte_marcial": "marcial", "aura_hazaki": "aura", "poder_elemental": "elemental",
		"pendrive": "pistolas", "cabo_rede": "katana", "garrafa_termica": "global", "arma_que_nao_existe": "global", "": "global"}
	for arma in fins:
		ok(Finalizacao.chave_de(arma) == fins[arma], "finalização de '%s' = %s (deu %s)" % [arma, fins[arma], Finalizacao.chave_de(arma)])

	# ---------- morte de verdade: o efeito certo por causa ----------
	var a := await nova()
	a.bot = false
	a.jogador.invencivel = 999.0
	a.diretor.bonus_minutos = -1000.0   # nada nasce sozinho: só o que o teste cria
	for arma in ["katana", "desert_eagles", "arte_marcial", "aura_hazaki", "baforada", "wifi", "energia_draconica", "garrafa_termica"]:
		var esperado := str(Mortes.efeito_de(Mortes.causa_de(arma)))
		ok(matar(a, arma) == esperado, "morrer por %s usa %s" % [arma, esperado])
	for elem in ["fogo", "gelo", "raio"]:
		var esperado := str(Mortes.efeito_de(elem))
		ok(matar(a, "poder_elemental", elem) == esperado, "elemental %s usa %s" % [elem, esperado])
	# a causa é a do ÚLTIMO golpe, e o elemento não vaza pro golpe seguinte
	var vv = a.inimigos.criar("bug", a.jogador.position + Vector2(50, 0))
	vv.causa_pend = "gelo"
	a.inimigos.ferir(vv, 0.1, Vector2.ZERO, "poder_elemental")
	a.inimigos.ferir(vv, 1.0e9, Vector2.ZERO, "katana")
	ok(a.mortes.ult_efeito == "corte", "o último golpe manda (katana depois do gelo: %s)" % a.mortes.ult_efeito)
	# longe da tela: nada
	var longe = a.inimigos.criar("bug", a.jogador.position + Vector2(2000, 0))
	a.mortes.ult_efeito = "?"
	a.inimigos.ferir(longe, 1.0e9, Vector2.ZERO, "katana")
	ok(a.mortes.ult_efeito == "?", "inimigo longe da tela morre sem efeito")
	# o registro guarda a cor da morte do inimigo (cor_morte do inimigos.json), quando tem
	var com_cor := ""
	for id in Dados.json("inimigos"):
		if Dados.json("inimigos")[id] is Dictionary and Dados.json("inimigos")[id].has("cor_morte") and not Dados.json("inimigos")[id].get("chefe", false):
			com_cor = str(id)
			break
	if com_cor != "":
		var vc = a.inimigos.criar(com_cor, a.jogador.position + Vector2(50, 0))
		var rc := Mortes.registro(vc, "padrao", "simples")
		var cm: Array = vc.d.cor_morte
		ok(rc.cor.is_equal_approx(Color(cm[0], cm[1], cm[2])), "morte padrão usa a cor_morte de %s" % com_cor)

	# ---------- teto: 500 mortes de uma vez ----------
	a.mortes.limpar()
	var armas_sort := ["katana", "desert_eagles", "arte_marcial", "aura_hazaki", "baforada", "wifi", "energia_draconica", "garrafa_termica", "cafe", "pendrive"]
	var teto: Dictionary = dm.teto
	var maximo_ativas := 0
	var maximo_part := 0
	var maximo_simples := 0
	var criados: Array = []
	for i in 500:
		var v = a.inimigos.criar("bug", a.jogador.position + Vector2(randf_range(-300, 300), randf_range(-170, 170)))
		v.causa_pend = ["fogo", "gelo", "raio"].pick_random() if i % 7 == 0 else ""
		criados.append(v)
		a.inimigos.ferir(v, 1.0e9, Vector2.from_angle(randf() * TAU) * 60.0, armas_sort[i % armas_sort.size()] if i % 7 != 0 else "poder_elemental")
		maximo_ativas = maxi(maximo_ativas, a.mortes.ativas.size())
		maximo_part = maxi(maximo_part, a.mortes.particulas())
		maximo_simples = maxi(maximo_simples, a.mortes.simples.size())
	ok(maximo_ativas <= int(teto.mortes), "500 mortes: no máximo %d efeitos grandes (foram %d)" % [teto.mortes, maximo_ativas])
	ok(maximo_part <= int(teto.particulas), "500 mortes: no máximo %d partículas (foram %d)" % [teto.particulas, maximo_part])
	ok(maximo_simples <= int(teto.simples), "500 mortes: no máximo %d mortes simples (foram %d)" % [teto.simples, maximo_simples])
	ok(a.mortes.ativas.size() == int(teto.mortes), "o teto é mesmo atingido com 500 mortes (%d)" % a.mortes.ativas.size())
	ok(a.mortes.manchas.size() <= int(teto.manchas), "manchas no chão respeitam o teto")
	ok(criados.all(func(v): return v.hp <= 0), "os 500 morreram de verdade")
	for i in 40:   # tudo termina e a contagem de partículas volta a zero
		a.mortes.atualizar(0.1)
	ok(a.mortes.ativas.is_empty() and a.mortes.simples.is_empty() and a.mortes.particulas() == 0, "efeitos acabam e liberam as partículas (%d)" % a.mortes.particulas())

	# ---------- o desenho de cada efeito roda e faz o que diz ----------
	var vd = a.inimigos.criar("bug", a.jogador.position + Vector2(50, 0))
	for ef in ["cinzas", "estilhaco", "choque", "corte", "pedacos", "furo", "desintegrar", "suave", "simples"]:
		var r := Mortes.registro(vd, "corte", ef)
		var viram := {}
		for k in 11:   # varre o efeito inteiro
			r.t = r.dur * k / 10.0
			var g := Gravador.new()
			Mortes.desenhar(g, r)
			ok(g.total > 0, "%s desenha algo em t=%d" % [ef, k])
			viram[k] = g
		var meio: Gravador = viram[5]
		if ef in ["estilhaco", "corte", "pedacos", "desintegrar"]:
			ok(viram[6].partes() > 0 or meio.partes() > 0, "%s mostra partes do corpo" % ef)
		if ef in ["suave", "simples", "cinzas", "choque"]:
			ok(meio.partes() == 0, "%s não mostra partes" % ef)
		if ef in ["corte", "pedacos", "furo"]:
			ok(viram[3].sangue > 0, "%s mostra sangue escuro" % ef)
		if ef in ["suave", "simples", "estilhaco", "desintegrar", "cinzas", "choque"]:
			var sg := 0
			for g in viram.values():
				sg += g.sangue
			ok(sg == 0, "%s não mostra sangue (%d)" % [ef, sg])

	# ---------- opção Reduzida: nada de partes nem sangue ----------
	Config.temporario("mortes", "reduzida")
	a.mortes.limpar()
	for arma in ["katana", "desert_eagles", "arte_marcial", "aura_hazaki", "baforada", "wifi", "energia_draconica", "poder_elemental"]:
		var ef := matar(a, arma, "gelo" if arma == "poder_elemental" else "")
		ok(ef == "suave", "reduzida: %s -> suave (deu %s)" % [arma, ef])
	ok(a.mortes.manchas.is_empty(), "reduzida: sem mancha de sangue no chão")
	var partes := 0
	var sangue := 0
	for r in a.mortes.ativas:
		ok(not Mortes.tem_partes(r.ef) and not Mortes.tem_sangue(r.ef), "reduzida: registro %s sem partes/sangue" % r.ef)
		for k in 11:
			r.t = r.dur * k / 10.0
			var g := Gravador.new()
			Mortes.desenhar(g, r)
			partes += g.partes()
			sangue += g.sangue
	ok(partes == 0, "reduzida: o desenho não tem partes (%d)" % partes)
	ok(sangue == 0, "reduzida: o desenho não tem sangue (%d)" % sangue)
	Config.temporario("mortes", "normal")
	a.mortes.limpar()

	# ---------- finalização de chefe (arena nova: as 500 mortes acima abriram cartas de nível e pausaram a árvore) ----------
	a.queue_free()
	get_tree().paused = false
	await esperar(0.2)
	Engine.time_scale = 1.0
	a = await nova()
	a.diretor.xp_mult = 0.0   # sem XP dos chefes: nenhuma carta de nível abre no meio (abrir pausa a árvore e congela a finalização)
	a.bot = false
	a.jogador.invencivel = 999.0
	a.diretor.bonus_minutos = -1000.0
	var casos_fin := {"katana": "x_katana", "desert_eagles": "rajada", "arte_marcial": "soco", "aura_hazaki": "coluna", "poder_elemental": "elemental", "pendrive": "rajada", "garrafa_termica": "global"}
	for arma in casos_fin:
		var b = a.inimigos.criar("trojan_gigante", a.jogador.position + Vector2(120, 0))
		a.inimigos.ferir(b, 1.0e9, Vector2(60, 0), arma)
		ok(a.finalizacao.ativa(), "chefe morto por %s inicia a finalização" % arma)
		ok(str(a.finalizacao._cfg.golpe) == casos_fin[arma], "golpe de %s = %s (deu %s)" % [arma, casos_fin[arma], a.finalizacao._cfg.golpe])
		# desenha o golpe em vários instantes (canvas de mentira não cobre o Node2D, então só confere que o registro existe)
		ok(not a.finalizacao._rec.is_empty() and a.finalizacao._rec.has("ef"), "finalização de %s tem corpo" % arma)
		a.finalizacao.restaurar()
	a.finalizacao.restaurar()
	# câmera lenta e zoom enquanto dura; voltam ao normal no fim
	var b2 = a.inimigos.criar("trojan_gigante", a.jogador.position + Vector2(120, 0))
	a.inimigos.ferir(b2, 1.0e9, Vector2(60, 0), "katana")
	await esperar(0.3)
	ok(Engine.time_scale < 0.6, "durante a finalização o jogo fica em câmera lenta (%.2f)" % Engine.time_scale)
	ok(a.camera.zoom.x > 1.05, "durante a finalização a câmera aproxima (%.2f)" % a.camera.zoom.x)
	await esperar(2.6)
	ok(not a.finalizacao.ativa(), "a finalização termina sozinha")
	ok(is_equal_approx(Engine.time_scale, 1.0), "o tempo volta ao normal no fim (%.3f)" % Engine.time_scale)
	ok(is_equal_approx(a.camera.zoom.x, 1.0), "o zoom volta ao normal no fim (%.3f)" % a.camera.zoom.x)
	# a arena fecha no meio (voltou pro menu, fim de jogo): o tempo não pode ficar preso
	a.cartas._fechar()   # o XP dos chefes anteriores abriu carta de nível e pausou a árvore
	var b3 = a.inimigos.criar("trojan_gigante", a.jogador.position + Vector2(120, 0))
	a.inimigos.ferir(b3, 1.0e9, Vector2(60, 0), "aura_hazaki")
	await esperar(0.3)
	ok(Engine.time_scale < 0.6, "câmera lenta ligada antes de fechar a arena (%.2f)" % Engine.time_scale)
	a.queue_free()
	await esperar(0.2)
	ok(is_equal_approx(Engine.time_scale, 1.0), "arena fechada no meio da finalização: tempo normal (%.3f)" % Engine.time_scale)

	# ---------- online: só o desenho, sem câmera lenta nem zoom ----------
	var a2 := await nova()
	a2.bot = false
	a2.jogador.invencivel = 999.0
	a2.diretor.bonus_minutos = -1000.0
	a2.eh_online = true
	var b4 = a2.inimigos.criar("trojan_gigante", a2.jogador.position + Vector2(120, 0))
	a2.inimigos.ferir(b4, 1.0e9, Vector2(60, 0), "katana")
	await esperar(0.4)
	ok(a2.finalizacao.ativa(), "online: a finalização aparece")
	ok(is_equal_approx(Engine.time_scale, 1.0), "online: sem câmera lenta (%.3f)" % Engine.time_scale)
	ok(is_equal_approx(a2.camera.zoom.x, 1.0), "online: sem zoom")
	a2.eh_online = false
	a2.finalizacao.restaurar()
	# reduzida: a finalização vira coluna de luz com o corpo só sumindo
	Config.temporario("mortes", "reduzida")
	var b5 = a2.inimigos.criar("trojan_gigante", a2.jogador.position + Vector2(120, 0))
	a2.inimigos.ferir(b5, 1.0e9, Vector2(60, 0), "katana")
	ok(str(a2.finalizacao._cfg.golpe) == "coluna_suave", "reduzida: finalização sem sangue e sem partes (%s)" % a2.finalizacao._cfg.golpe)
	ok(not Mortes.tem_partes(a2.finalizacao._rec.ef) and not Mortes.tem_sangue(a2.finalizacao._rec.ef), "reduzida: corpo do chefe sem partes (%s)" % a2.finalizacao._rec.ef)
	Config.temporario("mortes", "normal")
	a2.finalizacao.restaurar()
	a2.queue_free()
	await esperar(0.2)
	Engine.time_scale = 1.0
	print("MORTE falhas=", falhas)
	get_tree().quit()
