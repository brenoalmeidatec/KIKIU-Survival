extends Node
# Teste das PARTÍCULAS da explosão do mecha (Q do LightWolf, rodada 7: v2/explosao_particulas.gd chamada por v2/explosao_mecha.gd), isolado, sem mundo:
#  1. pool fixo: nunca passa de MAX vagas, nem com 2 Q seguidas (a segunda reaproveita o pool), e nasce de cada tipo;
#  2. some no fim: depois da vida mais longa (fumaça) o pool fica vazio, e `limpar` zera;
#  3. perfil Baixo (`explodir(..., leve = true)`): nenhuma partícula nasce;
#  4. RNG da partida intacto: a sequência do RNG global depois de explodir e animar 4 s é a mesma de sem a explosão (o efeito usa hash próprio);
#  5. "Reduzir piscadas": faíscas e brasas de cor única, e cada partícula só desce de degrau (tamanho e cor nunca voltam), com degrau de fumaça >= 0,25 s de relógio;
#     detritos, faíscas, fumaça e pontos de calor trocam de desenho no máximo 1 vez e nenhum estado dura menos de 0,2 s (medido por vaga, quadro a quadro).
#  6. a sucção do fusível: 4 degraus de raio no normal e um só no calmo (desenho estático, conferido pelo número de pontos).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_lw_q_particulas.tscn  (imprime "v2_lw_q_particulas falhas=0")
const Ex := preload("res://v2/explosao_mecha.gd")
const P := preload("res://v2/explosao_particulas.gd")
const DT := 1.0 / 60.0

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _bloco() -> Dictionary:
	var f := FileAccess.open("res://dados/v2_especial.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	return d.autodestruicao


func _nova() -> Ex:
	var b := _bloco()
	var v := Ex.new()
	v.montar(null, null, b.explosao, float(b.limpa.vel))
	return v


func _ready() -> void:
	Config.temporario("reduzir_piscadas", false)
	var rect := Rect2(-500, -300, 1000, 600)
	# 1 e 2: pool fixo, 2 Q seguidas, tudo some
	var v := _nova()
	v.explodir(Vector2(10, 20), rect)
	ok(v.cheia(), "normal: a folha nova está ligada")
	var pt = v.particulas
	var nascidas: int = pt.emitidas
	print("partículas: %d nascidas (teto %d)" % [nascidas, P.MAX])
	ok(nascidas > 40 and nascidas <= P.MAX, "nascem dezenas de partículas, dentro do teto (%d)" % nascidas)
	var tipos := {}
	for i in P.MAX:
		if pt.tipo[i] != P.LIVRE:
			tipos[pt.tipo[i]] = true
	ok(tipos.size() == 5, "nasce de cada tipo: detrito, faísca, brasa, fumaça e calor (%d tipos)" % tipos.size())
	var pico := 0
	for f in 30:
		v.atualizar(DT)
		pico = maxi(pico, pt.vivas())
	v.explodir(Vector2(40, 20), rect)  # a 2ª Q logo depois
	for f in 300:
		v.atualizar(DT)
		pico = maxi(pico, pt.vivas())
		ok(pt.vivas() <= P.MAX, "o pool nunca passa do teto")
	ok(pico <= P.MAX and pico > 0, "pico de %d vagas com 2 Q seguidas (teto %d)" % [pico, P.MAX])
	ok(pt.vivas() == 0, "5 s depois da 2ª Q nenhuma partícula ficou (%d)" % pt.vivas())
	v.explodir(Vector2(40, 20), rect)
	v.limpar()
	ok(pt.vivas() == 0, "limpar zera o pool")
	# 3: perfil Baixo
	var b := _nova()
	b.explodir(Vector2.ZERO, rect, true)
	ok(not b.cheia(), "Baixo: a bola calma")
	ok(b.particulas.vivas() == 0 and b.particulas.emitidas == 0, "Baixo: nenhuma partícula (%d)" % b.particulas.emitidas)
	# 4: RNG da partida intacto
	seed(4242)
	var esperado := []
	for i in 5:
		esperado.append(randi())
	seed(4242)
	var r := _nova()
	r.explodir(Vector2(5, 5), rect)
	for f in 240:
		r.atualizar(DT)
	var visto := []
	for i in 5:
		visto.append(randi())
	ok(visto == esperado, "o RNG global segue a mesma sequência depois da explosão com partículas")
	# 5: Reduzir piscadas
	Config.temporario("reduzir_piscadas", true)
	var c := _nova()
	c.explodir(Vector2.ZERO, rect)
	Config.temporario("reduzir_piscadas", false)
	ok(not c.cheia() and c.particulas.calmo, "Reduzir piscadas: a bola calma e as partículas calmas")
	var cp = c.particulas
	var degrau_ant := {}
	var voltou := 0
	for f in 240:
		c.atualizar(DT)
		for i in P.MAX:
			if cp.tipo[i] == P.LIVRE or cp.idade[i] < 0.0:
				degrau_ant.erase(i)
				continue
			if cp.tipo[i] != P.FUMACA_T:
				continue
			var dg: int = cp.degrau_fumaca(i)
			if degrau_ant.has(i):
				if dg < degrau_ant[i]:
					voltou += 1
			degrau_ant[i] = dg
	ok(voltou == 0, "calmo: a fumaça nunca volta de degrau")
	# 5b: calmo, detritos, faíscas, brasas, fumaça e calor: o desenho de cada partícula (tamanho/cor) troca no máximo 1 vez, nunca volta, e nenhum estado dura < 0,2 s de relógio
	Config.temporario("reduzir_piscadas", true)
	var d := _nova()
	d.explodir(Vector2.ZERO, rect)
	Config.temporario("reduzir_piscadas", false)
	var dp = d.particulas
	var sig_ant := {}  # vaga -> assinatura de desenho
	var desde := {}  # vaga -> quadro em que a assinatura atual começou
	var trocas := {}  # vaga -> quantas trocas
	var menor := 1e9
	var menor_fumaca := 1e9
	var sig_tipo := {}
	var voltas := 0
	var vistos := {}
	for f in 300:
		d.atualizar(DT)
		for i in P.MAX:
			var t: int = dp.tipo[i]
			var vis: bool = t != P.LIVRE and dp.idade[i] >= 0.0
			if not vis:
				if sig_ant.has(i):  # sumiu: fecha o último estado
					menor = minf(menor, float(f - desde[i]) * DT / 1.25)
					if sig_tipo[i] == P.FUMACA_T:
						menor_fumaca = minf(menor_fumaca, float(f - desde[i]) * DT / 1.25)
					sig_ant.erase(i)
				continue
			var sg := -1
			match t:
				P.DETRITO:
					sg = dp.lado_detrito(i)
				P.FAISCA:
					sg = dp.lado_faisca(i)
				P.CALOR:
					sg = int(dp.cor_calor(i).b * 100.0)
				P.FUMACA_T:
					sg = -dp.degrau_fumaca(i)  # índice maior = blob menor
				_:
					sg = 0  # brasa: uma cor, um tamanho
			vistos[t] = true
			var chave := i * 8 + t
			if not sig_ant.has(i):
				sig_ant[i] = sg
				sig_tipo[i] = t
				desde[i] = f
				trocas[chave] = trocas.get(chave, 0)
			elif sg != sig_ant[i]:
				if sg > sig_ant[i] and t != P.CALOR:
					voltas += 1  # cresceu de novo
				menor = minf(menor, float(f - desde[i]) * DT / 1.25)
				if t == P.FUMACA_T:
					menor_fumaca = minf(menor_fumaca, float(f - desde[i]) * DT / 1.25)
				trocas[chave] = trocas.get(chave, 0) + 1
				sig_ant[i] = sg
				desde[i] = f
	var max_trocas := 0
	for k in trocas:
		max_trocas = maxi(max_trocas, trocas[k])
	ok(vistos.size() == 5, "calmo: foram medidos detrito, faísca, brasa, fumaça e calor (%d tipos)" % vistos.size())
	ok(voltas == 0, "calmo: nenhum detrito, faísca ou fumaça volta a crescer")
	ok(max_trocas <= 1, "calmo: cada partícula troca de desenho no máximo 1 vez (%d)" % max_trocas)
	print("calmo: o menor estado de partícula dura %.3f s de relógio (fumaça %.3f; trocas por partícula <= %d)" % [menor, menor_fumaca, max_trocas])
	ok(menor_fumaca < 1e8 and menor_fumaca >= 0.25, "calmo: cada estado da fumaça dura pelo menos 0,25 s de relógio (2 Hz) (%.3f)" % menor_fumaca)
	ok(menor >= 0.2, "calmo: nenhum estado dura menos de 0,2 s de relógio (%.3f)" % menor)
	# 6: a sucção (os pontos): 4 degraus que fecham no normal, um só no calmo
	var raios := []
	for kk in [0.1, 0.3, 0.6, 0.9]:
		raios.append(P.pontos_succao(Vector2.ZERO, kk, 16, false)[0].length())
	ok(raios[0] > raios[1] and raios[1] > raios[2] and raios[2] > raios[3], "a sucção fecha em 4 degraus (%s)" % str(raios))
	ok(P.pontos_succao(Vector2.ZERO, 0.1, 16, true) == P.pontos_succao(Vector2.ZERO, 0.9, 16, true), "calmo: a sucção não troca de degrau")
	ok(P.pontos_succao(Vector2.ZERO, 0.5, 16, false).size() == 16, "16 pontos")
	print("v2_lw_q_particulas falhas=%d" % falhas)
	get_tree().quit()
