extends Node
# Teste: animação procedural dos heróis (#97): tabela dados/animacao.json, respiração, passo, golpe, recuo e queda.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/animacao_heroi.tscn  (imprime "ANIM_HEROI falhas=0")
const A := preload("res://scripts/hordas/animacao_heroi.gd")
const D := preload("res://scripts/hordas/direcao.gd")
const Remoto := preload("res://scripts/hordas/remoto.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	# ---- tabela: o arquivo tem todas as chaves dos padrões do código (e _ajuda fala de cada uma)
	var d: Dictionary = Dados.json("animacao")
	var ajuda := str(d.get("_ajuda", ""))
	ok(ajuda.length() > 500, "animacao.json tem _ajuda")
	for sec in A.PADRAO:
		ok(d.has(sec) and d[sec] is Dictionary, "animacao.json tem a seção %s" % sec)
		ok(ajuda.contains(str(sec) + ":"), "_ajuda explica a seção %s" % sec)
		for k in A.PADRAO[sec]:
			ok(d.get(sec, {}).has(k), "animacao.json > %s tem %s" % [sec, k])
			var pad = A.PADRAO[sec][k]
			var arq = d.get(sec, {}).get(k)
			ok(arq == pad or (not pad is bool and is_equal_approx(float(arq), float(pad))), "padrão do código = arquivo (%s.%s)" % [sec, k])
			ok(ajuda.contains(str(k)), "_ajuda cita a chave %s" % k)
	ok(A.sec("golpe").tempo == d.golpe.tempo, "sec() lê o arquivo")
	# ---- fase de cada boneco: estável e espalhada
	ok(A.fase_de("nicao") == A.fase_de("nicao"), "fase é estável")
	var fases := {}
	for h in ["beto", "fabio", "joao", "lucas", "lukako", "matheus", "nicao", "cavaleiro", "hazaki"]:
		var f := A.fase_de(h + "|eu")
		ok(f >= 0.0 and f < 1.0, "fase de %s em 0..1" % h)
		fases[snappedf(f, 0.05)] = true
	ok(fases.size() >= 5, "9 heróis têm pelo menos 5 fases diferentes (%d)" % fases.size())
	# ---- respiração: periódica, entre 0 e a altura, passos de 1 px
	var r: Dictionary = A.sec("respiracao")
	var mx := 0.0
	var mn := 9.0
	for i in 400:
		var v := A.respiracao(i / 100.0, 0.0, r)
		mx = maxf(mx, v.y)
		mn = minf(mn, v.y)
		var px := v.y * float(r.altura_px)
		ok(absf(px - roundf(px)) < 0.001, "respiração em passos de 1 px (%.3f)" % px)
		ok(v.x <= 0.0, "afina quando estica")
	var teto := ceilf(float(r.altura) * float(r.altura_px)) / float(r.altura_px)  # em px inteiros: 0,03 de 56 px = 2 px
	ok(mn == 0.0 and mx > 0.0 and mx <= teto + 0.001, "respiração entre 0 e %.3f (%.3f..%.3f)" % [teto, mn, mx])
	ok(is_equal_approx(A.respiracao(0.3, 0.0, r).y, A.respiracao(0.3 + 1.0 / float(r.hz), 0.0, r).y), "respiração periódica")
	var igual := true
	for i in 40:
		if not is_equal_approx(A.respiracao(i * 0.05, 0.0, r).y, A.respiracao(i * 0.05, 0.5, r).y):
			igual = false
	ok(not igual, "fases diferentes respiram fora de sincronia")
	var rc: Dictionary = r.duplicate()
	rc.pixel = false
	ok(is_equal_approx(A.respiracao(0.0, 0.25, rc).y, float(r.altura)), "sem pixel: topo = altura exata")
	# ---- passo: quadros 1..8, balanço com 2 subidas por ciclo, dentro do máximo
	var a: Dictionary = A.sec("andar")
	for i in 100:
		var q := A.quadro_andar(i / 100.0)
		ok(q >= 1 and q <= 8, "quadro de andar %d" % q)
	ok(A.quadro_andar(0.0) == 1 and A.quadro_andar(0.99) == 8 and A.quadro_andar(1.0) == 1, "ciclo percorre 1..8 e volta")
	var subidas := 0
	var ant := A.balanco(0.0, 1.0, a)
	var sobe := false
	for i in range(1, 401):
		var b := A.balanco(i / 400.0, 1.0, a)
		ok(b >= -0.0001 and b <= float(a.balanco_px) + 0.0001, "balanço dentro de 0..%.1f (%.2f)" % [a.balanco_px, b])
		if b > ant and not sobe:
			subidas += 1
		sobe = b > ant
		ant = b
	ok(subidas == 2, "2 balanços por ciclo (%d)" % subidas)
	ok(A.balanco(0.25, 0.0, a) == 0.0 and A.balanco(0.25, 0.5, a) < A.balanco(0.25, 1.0, a), "balanço cresce com a velocidade")
	# ---- estado do boneco: o ciclo anda com a distância (sem patinar), parar suaviza e não estala
	var c := A.new()
	for i in 60:
		c.atualizar(1.0 / 60.0, Vector2(100, 0), true)
	var cic100 := c.ciclo
	var c2 := A.new()
	for i in 60:
		c2.atualizar(1.0 / 60.0, Vector2(50, 0), true)
	var esp100 := fposmod(100.0 / float(a.px_por_ciclo), 1.0)
	var esp50 := fposmod(50.0 / float(a.px_por_ciclo), 1.0)
	ok(absf(cic100 - esp100) < 0.03, "a 100 px/s: 1,5 ciclo/s como os 12 quadros/s de antes (%.3f, esperado %.3f)" % [cic100, esp100])
	ok(absf(c2.ciclo - esp50) < 0.03, "a 50 px/s anda metade da distância por ciclo (%.3f, esperado %.3f)" % [c2.ciclo, esp50])
	ok(c.mix > 0.99 and c.resp == Vector2.ZERO, "andando: mix 1 e sem respiração")
	ok(c.incl > 0.0 and c.incl <= float(a.inclina) * 1.2 + 0.0001, "andando pra direita inclina pra frente (%.4f)" % c.incl)
	var maxdi := 0.0
	var antes_i := c.incl
	var antes_m := c.mix
	for i in 30:
		c.atualizar(1.0 / 60.0, Vector2.ZERO, false)
		maxdi = maxf(maxdi, absf(c.incl - antes_i))
		ok(absf(c.mix - antes_m) < 0.35, "parar não estala o mix (%.2f -> %.2f)" % [antes_m, c.mix])
		antes_i = c.incl
		antes_m = c.mix
	ok(maxdi < float(a.inclina) * 0.35, "parar solta a inclinação aos poucos (salto máx %.4f)" % maxdi)
	ok(c.mix < 0.01 and absf(c.incl) < 0.001, "depois de parar: sem inclinação nem balanço")
	for i in 60:
		c.atualizar(1.0 / 60.0, Vector2.ZERO, false)
	ok(c.escala().y >= 0.0 and c.escala().y <= float(r.altura) + 0.001, "parado respira (%s)" % c.escala())
	var e := A.new()  # folha que já tem quadros de parado respira menos
	var f := A.new()
	var m1 := 0.0
	var m2 := 0.0
	for i in 200:
		e.atualizar(0.02, Vector2.ZERO, false, true, true)
		f.atualizar(0.02, Vector2.ZERO, false, true, false)
		m1 = maxf(m1, e.escala().y)
		m2 = maxf(m2, f.escala().y)
	ok(m1 < m2 and m1 > 0.0, "folha animada respira menos (%.3f < %.3f)" % [m1, m2])
	f.atualizar(0.02, Vector2(100, 0), true, false)  # inativo (rolando): sem efeito
	ok(f.escala() == Vector2.ZERO and f.desloc() == Vector2.ZERO, "inativo: sem respiração nem balanço")
	var g := A.new()
	for i in 30:
		g.atualizar(1.0 / 60.0, Vector2(-100, 0), true)
	ok(g.incl < 0.0, "andando pra esquerda inclina pra esquerda")
	g = A.new()
	g.atualizar(0.01, Vector2(100, 0), true)
	ok(A.quadro_andar(g.ciclo) == 1, "começa o passo no quadro 1")
	# ---- golpe: antecipação, passa do alvo, assenta; contínuo
	var gc: Dictionary = A.sec("golpe")
	var maior := 0.0
	var pa := A.pose_golpe(0.0)
	for i in range(1, 241):
		var p := A.pose_golpe(i / 240.0)
		maior = maxf(maior, absf(p.x - pa.x))
		pa = p
	ok(maior < float(gc.avanco) * 0.6, "golpe contínuo (maior salto %.2f px por 1/240)" % maior)
	ok(A.pose_golpe(float(gc.antecipa)).x < 0.0 and A.pose_golpe(float(gc.antecipa)).y < 0.0, "fim da antecipação: recuado e comprimido")
	ok(A.pose_golpe(float(gc.bate)).y > 0.0 and A.pose_golpe(float(gc.bate)).z == 1.0, "no auge: esticado e inclinado")
	ok(A.pose_golpe(0.9).x < float(gc.avanco) * 0.1, "no fim já assentou (%.2f px)" % A.pose_golpe(0.9).x)
	ok(A.pose_golpe(1.0) == Vector3.ZERO and A.pose_golpe(-1.0) == Vector3.ZERO, "extremos no lugar")
	# ---- recuo ao apanhar
	var dc: Dictionary = A.sec("dano")
	ok(A.pose_dano(0.0) == Vector3.ZERO and A.pose_dano(1.0) == Vector3.ZERO, "recuo começa e termina no lugar")
	ok(is_equal_approx(A.pose_dano(0.25).x, float(dc.recuo_px)), "recuo máximo em 25%% do tempo (%.2f)" % A.pose_dano(0.25).x)
	ok(A.pose_dano(0.1).x < A.pose_dano(0.25).x and A.pose_dano(0.6).x < A.pose_dano(0.25).x and A.pose_dano(0.6).x > 0.0, "sobe rápido e volta suave")
	# ---- queda: de pé -> deitado na pose de sempre, pros dois lados
	var mc: Dictionary = A.sec("morte")
	for s in [1.0, -1.0]:
		var p0 := A.pose_morte(0.0, s)
		var p1 := A.pose_morte(1.0, s)
		ok(is_zero_approx(p0.rot) and p0.pos.length() < 0.001 and p0.mix == 0.0, "queda começa em pé (%s)" % s)
		ok(
			is_equal_approx(p1.rot, s * PI / 2.0) and p1.pos.is_equal_approx(Vector2(float(mc.x) * s, float(mc.y))) and p1.mix == 1.0,
			"queda termina deitada (%s)" % s
		)
		var topo := 0.0
		var voltou := 0.0
		for i in range(13, 101):  # depois do tropeço: o quanto levanta de novo depois de encostar no chão
			var rr := absf(A.pose_morte(i / 100.0, s).rot)
			topo = maxf(topo, rr)
			voltou = maxf(voltou, topo - rr)
		ok(voltou > 0.05 and voltou < 0.4, "quica ao bater no chão (%.3f rad)" % voltou)
	var tropeco := A.pose_morte(float(mc.tropeco) * 0.5, 1.0)
	ok(tropeco.rot < 0.0, "tropeça pra trás antes de cair")
	# ---- pessoa do online (remoto.gd): tudo derivado de posição, vida e bits que já vão na rede
	var rm := Remoto.new()
	add_child(rm)
	rm.configurar(2, "nicao", "Teste")
	var est := {"x": 0.0, "y": 0.0, "mx": 1.0, "my": 0.0, "hp": 1.0, "ajuda": false, "caido": false, "lado": 1.0, "rola": false}
	rm.atualizar(0.016, est)
	rm._ent_t = 0.0  # sem a queda da chegada
	var cols_ok := true
	var inclinou := false
	for i in 90:  # anda pra direita a 100 px/s (a posição vem em pacotes, como na rede)
		est.x = i * 100.0 / 60.0
		rm.atualizar(1.0 / 60.0, est)
		var col: int = rm.spr.frame % rm.spr.hframes
		if col < 1 or col > 8:
			cols_ok = false
		inclinou = inclinou or rm.spr.skew > 0.01
	ok(cols_ok, "remoto andando usa as colunas 1..8")
	ok(inclinou and rm.spr.skew <= float(a.inclina) * 1.3, "remoto inclina pra frente andando (%.4f)" % rm.spr.skew)
	ok(rm._corpo.ciclo > 0.0 and rm._vel.x > 60.0, "remoto: velocidade e ciclo vêm da posição (%.0f px/s)" % rm._vel.x)
	est.mx = 0.0
	for i in 40:  # para: a posição pára, o corpo volta a respirar sem estalo
		rm.atualizar(1.0 / 60.0, est)
	ok(absf(rm.spr.skew) < 0.005 and rm.spr.frame % rm.spr.hframes == 0, "remoto parado: sem inclinação e no quadro parado")
	est.hp = 0.6  # perdeu vida: recuo visual (pra longe do lado em que olha)
	rm.atualizar(1.0 / 60.0, est)
	for i in 6:
		rm.atualizar(1.0 / 60.0, est)
	ok(
		rm._dano_pose_t > 0.0 and rm.spr.position.x < 0.0 and rm.spr.scale.x > 1.0,
		"remoto apanhou: recua e achata (pos %s, escala %s)" % [rm.spr.position, rm.spr.scale]
	)
	for i in 30:
		rm.atualizar(1.0 / 60.0, est)
	ok(rm.spr.position == Vector2.ZERO, "o recuo do remoto volta ao lugar")
	est.rola = true
	rm.atualizar(0.1, est)
	ok(absf(rm.spr.rotation) > 0.1 and rm.spr.skew == 0.0, "remoto rolando gira")
	est.rola = false
	est.caido = true
	for i in 70:
		rm.atualizar(1.0 / 60.0, est)
	ok(
		is_equal_approx(rm.spr.rotation, -PI / 2.0) and rm.spr.position.is_equal_approx(Vector2(30.0, -10.0)),
		"remoto caído deitado pra trás (%s, %s)" % [rm.spr.rotation, rm.spr.position]
	)
	est.caido = false
	rm.atualizar(1.0 / 60.0, est)
	ok(is_zero_approx(rm.spr.rotation) and rm.spr.modulate == Color.WHITE, "levantou: corpo de pé outra vez")
	rm.queue_free()
	# ---- direção de 4 linhas: histerese (sem pisca na diagonal) mas a primeira escolha segue a regra de sempre
	var o := D.new()
	var trocas := 0
	var ult := ""
	for i in 120:
		var ang := deg_to_rad(40.0 + (6.0 if i % 2 == 0 else -6.0))  # em volta da diagonal
		o.atualizar(Vector2.from_angle(ang), 1.0 / 60.0, 4)
		if o.dir != ult:
			trocas += 1
			ult = o.dir
	ok(trocas <= 1, "4 linhas: oscilar na diagonal não pisca (%d trocas)" % trocas)
	ok(D.direcao4(Vector2(1, 1)) == "direita" and D.direcao4(Vector2(1, 1), "baixo") == "baixo", "sem atual vale a regra seca; com atual há folga")
	ok(D.direcao4(Vector2(1, 0.2), "baixo") == "direita" and D.direcao4(Vector2(0.2, 1), "direita") == "baixo", "dominância clara troca mesmo com histerese")
	print("ANIM_HEROI falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
