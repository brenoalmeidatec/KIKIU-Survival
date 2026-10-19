extends Node
# Teste automático das fases dos golpes secundários com folha animada (v2/anim_golpes.gd ligado em v2/armas_novas.gd; docs/combate_v2):
# as folhas dos índices carregam com o tamanho certo; o tiro nasce em PREPARO (na boca, sem hitbox) e só fere depois; cada monstro leva um
# acerto por tiro; o impacto toca no acerto (não no fim do voo); a velocidade de ataque encolhe o preparo dentro dos limites; o anel não fere
# no preparo e acerta cada monstro uma vez; a nuvem não fere enquanto se forma; o meteoro fere na queda e toca impacto e marca; o tiro segue
# sem erro quando o alvo morre no meio do voo; o ricochete muda de alvo; o crítico das cartas vale para o tiro; a katana só fere no quadro
# do acerto; e o pool e a camada de desenho não crescem.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_combate_fases.tscn  (imprime "v2_combate_fases falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Novas := preload("res://v2/armas_novas.gd")
const Anim := preload("res://v2/anim_golpes.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.correr_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	w.heroi.m_critico = -1.0  # sem crítico por sorteio (o teste do crítico liga de propósito)
	passos(3)


## Um monstro parado (atordoado para sempre) que não morre.
func alvo(dx: float, dy := 0.0):
	var m = w.nascer_monstro("inimigo_espantalho", w.heroi.pos + Vector2(dx, dy))
	m.vida_max = 100000.0
	m.vida = 100000.0
	m.atordoa_t = 9999.0
	m.cacador = false
	m.raio_vaga = 0.0
	return m


func novas():
	return w.combate.armas.novas


## Os itens vivos do pool do tipo `k`.
func vivos(k: String) -> Array:
	var r := []
	for it in novas().itens:
		if float(it.vida) > 0.0 and str(it.k) == k:
			r.append(it)
	return r


## O id é um golpe, um modificador ou uma evolução dos dados (ou a peça "<id>_queda" de um deles).
func existe(id: String) -> bool:
	if id.ends_with("_queda"):  # a peça que cai antes do golpe ("martelo_trovao_queda"): vale o golpe de base
		id = id.trim_suffix("_queda")
	if not w.combate.cartas.definicao(id).is_empty():
		return true
	for ev in w.combate.cartas.cfg.evolucoes:
		if str(ev.id) == id:
			return true
	return false


func checar_folhas() -> void:
	var n := 0
	for g in Anim.GRUPOS:
		var caminho: String = Anim.PASTA.path_join("indice_%s.json" % g)
		var d = JSON.parse_string(FileAccess.get_file_as_string(caminho))
		ok(d is Dictionary and d.has("folhas"), "%s lê" % caminho)
		if not (d is Dictionary):
			continue
		for nome in d.folhas:
			for an in d.folhas[nome].anims:
				var s: Dictionary = d.folhas[nome].anims[an]
				var tex := load(Anim.PASTA.path_join(str(s.arquivo))) as Texture2D
				ok(tex != null, "%s/%s carrega" % [nome, an])
				if tex != null:
					var esperado := Vector2(float(s.quadro[0]) * float(s.n), float(s.quadro[1]))
					ok(tex.get_size() == esperado, "%s/%s mede n x quadro (%s, esperado %s)" % [nome, an, tex.get_size(), esperado])
				n += 1
			for arma in d.folhas[nome].armas:
				ok(existe(str(arma)), "%s serve %s, que existe nos dados" % [nome, arma])
	ok(n >= 83, "as folhas dos 4 grupos (%d animações)" % n)
	var ids := ["bola_fogo", "adagas_voadoras", "meteoro_flamejante", "chuva_pedras", "onda_choque", "nuvem_veneno", "laminas"]
	ids += ["corvos", "revoada_de_trovoes", "runa", "circulo_runico", "raio", "aura_fogo", "anel_de_brasas", "ventania", "onda", "fura"]
	ids += ["urso_solar", "chuva_de_lacas", "bola_incendiaria", "chuva_de_ferro", "tempestade_primordial", "estrondo", "terra_partida"]
	ids += ["juramento_sagrado", "pedreira_ardente", "cometa_duplo", "eclipse_negro", "juizo_final", "nevasca_congelante", "cinzas_acidas"]
	ids += ["peste_negra", "furacao_glacial"]
	for id in ids:
		ok(not Anim.de(id).is_empty(), "%s tem folha animada" % id)
	var voo: Dictionary = Anim.de("bola_fogo").voo
	ok(Anim.quadro_em(voo, 0.0) == 0 and Anim.quadro_em(voo, 1.0 / 12.0 + 0.001) == 1, "o quadro anda no fps da folha")
	ok(Anim.quadro_em(voo, float(voo.n) / float(voo.fps) + 0.001) == 0, "o voo dá a volta (loop)")
	var imp: Dictionary = Anim.de("bola_fogo").impacto
	ok(Anim.quadro_em(imp, 99.0) == int(imp.n) - 1, "o impacto trava no último quadro (uma vez)")


## Tiro: preparo sem hitbox na boca, acerto depois, um acerto por monstro por tiro, impacto no acerto.
func checar_projetil() -> void:
	zerar()
	var m = alvo(40.0)
	var arma := "bola_fogo"
	w.combate.armas.definir_golpe(arma, 1, 0.0)
	var a: Dictionary = w.combate.armas.ativas[arma]
	a.st.quantidade = 1
	a.st.perfura = 0.0
	a.st.explosao = 0.0
	a.t = 0.0
	passos(1)
	var tiros := vivos("projetil")
	ok(tiros.size() == 1, "o tiro nasceu (%d)" % tiros.size())
	if tiros.is_empty():
		return
	var it: Dictionary = tiros[0]
	ok(int(it.fk) == Novas.F_PREPARO, "o tiro nasce em PREPARO")
	var boca: Vector2 = it.p
	w.heroi.pos += Vector2(0, 8)  # o herói anda: a carga vai junto
	passos(1)
	ok((it.p as Vector2).distance_to(boca + Vector2(0, 8)) < 0.5, "no preparo a carga acompanha a boca")
	w.heroi.pos -= Vector2(0, 8)
	var vida0 := float(m.vida)
	var imp0: int = novas().impactos
	var prep_passos := int(ceil(Novas.PREPARO_PROJ / PASSO)) - 3
	passos(prep_passos)
	ok(float(m.vida) == vida0, "nenhum dano no preparo")
	ok(int(it.fk) == Novas.F_PREPARO, "ainda no preparo depois de %d passos" % prep_passos)
	var n := 0
	while float(m.vida) == vida0 and n < 90:
		passos(1)
		n += 1
	ok(float(m.vida) < vida0, "o tiro fere depois do preparo")
	ok(novas().impactos == imp0 + 1, "o impacto toca no acerto (%d)" % (novas().impactos - imp0))
	var vida1 := float(m.vida)
	passos(30)
	ok(float(m.vida) == vida1 or vivos("projetil").size() > 0, "um tiro, um acerto: o mesmo tiro não fere de novo")
	ok(novas().x_ativos > 0 or novas().impactos > imp0, "o impacto ficou tocando no pool de efeitos")


## A velocidade de ataque das cartas encolhe o preparo, mas dentro de VEL_ANIM_MIN..VEL_ANIM_MAX.
func checar_velocidade() -> void:
	zerar()
	alvo(60.0)
	for caso in [[0.2, Novas.VEL_ANIM_MIN], [1.0, 1.0], [9.0, Novas.VEL_ANIM_MAX]]:
		w.heroi.m_vel_ataque = float(caso[0])
		ok(is_equal_approx(novas().vel_anim(w.heroi), float(caso[1])), "vel_anim(%s) = %s" % caso)
		novas().limpar()
		w.combate.armas.definir_golpe("lanca_geada", 1, 0.0)
		var a: Dictionary = w.combate.armas.ativas["lanca_geada"]
		a.t = 0.0
		passos(1)
		var tiros := vivos("projetil")
		ok(not tiros.is_empty(), "a lança saiu com vel_ataque %s" % caso[0])
		if not tiros.is_empty():
			var esperado := Novas.PREPARO_PROJ / float(caso[1])
			ok(absf(float(tiros[0].age) - esperado) < 0.001, "preparo %.3f com vel_ataque %s (esperado %.3f)" % [float(tiros[0].age), caso[0], esperado])
		w.combate.armas.remover("lanca_geada")
	w.heroi.m_vel_ataque = 1.0


## O alvo morre no meio do voo: o tiro segue reto, sem erro, e some no fim do alcance.
func checar_alvo_some() -> void:
	zerar()
	var m = alvo(150.0)
	w.combate.armas.definir_golpe("flechas_sombrias", 1, 0.0)
	var a: Dictionary = w.combate.armas.ativas["flechas_sombrias"]
	a.st.quantidade = 1
	a.t = 0.0
	passos(1)
	var tiros := vivos("projetil")
	ok(tiros.size() == 1, "a flecha saiu")
	passos(10)
	w.combate.matar(m)
	w.combate.processar_mortes()
	passos(150)
	ok(vivos("projetil").is_empty(), "sem alvo, a flecha acaba o percurso e some")


## Ricochete: depois do acerto, o tiro muda de rumo para o vizinho e acerta o segundo.
func checar_ricochete() -> void:
	zerar()
	var m1 = alvo(50.0)
	var m2 = alvo(50.0, 50.0)
	w.combate.armas.definir_golpe("adagas_voadoras", 1, 0.0)
	var a: Dictionary = w.combate.armas.ativas["adagas_voadoras"]
	a.st.quantidade = 1
	a.st.perfura = 0.0
	a.st.ricochete = 1.0
	a.st.recarga = 99.0
	a.t = 0.0
	passos(80)
	ok(m1.vida < m1.vida_max and m2.vida < m2.vida_max, "a adaga acertou um e ricocheteou no outro (%.0f, %.0f)" % [m1.vida, m2.vida])


## O crítico das cartas (Olho de falcão) vale para o tiro: com 100% de chance, o dano dobra pela regra da katana.
func checar_critico() -> void:
	zerar()
	var m = alvo(40.0)
	w.combate.armas.definir_golpe("bolas_chumbo", 1, 0.0)
	var a: Dictionary = w.combate.armas.ativas["bolas_chumbo"]
	a.st.quantidade = 1
	a.st.explosao = 0.0
	a.st.dano = 10.0
	a.st.recarga = 99.0
	a.t = 0.0
	w.heroi.m_critico = 5.0
	w.heroi.m_dano = 1.0
	var antes := float(m.vida)
	passos(60)
	var mult := float(w.combate.cfg.golpe.critico.mult)
	ok(absf((antes - float(m.vida)) - 10.0 * mult) < 1.5, "crítico do tiro: %.1f de dano (esperado ~%.0f)" % [antes - float(m.vida), 10.0 * mult])
	w.heroi.m_critico = -1.0


## Anel: nada no preparo; cada monstro uma vez.
func checar_anel() -> void:
	zerar()
	var perto = alvo(25.0)
	var longe = alvo(-60.0)
	w.combate.armas.definir_golpe("onda_choque", 1, 0.0)
	var a: Dictionary = w.combate.armas.ativas["onda_choque"]
	a.st.recarga = 99.0
	a.st.empurra = 0.0
	a.t = 0.0
	passos(1)
	var aneis := vivos("anel")
	ok(aneis.size() == 1 and int(aneis[0].fk) == Novas.F_PREPARO, "o anel nasce em PREPARO")
	var v0 := float(perto.vida)
	passos(int(Novas.PREPARO_ANEL / PASSO) - 2)
	ok(float(perto.vida) == v0, "nenhum dano no preparo do anel, nem colado no herói")
	passos(120)
	ok(perto.acertos == 1 and longe.acertos == 1, "o anel acerta cada monstro uma vez (%d e %d)" % [perto.acertos, longe.acertos])


## Martelo do Trovão: o martelo cai no herói (preparo de QUEDA_ANEL, sem dano) e só então a onda abre.
func checar_martelo() -> void:
	zerar()
	var m = alvo(30.0)
	w.combate.armas.definir_golpe("martelo_trovao", 1, 0.0)
	var a: Dictionary = w.combate.armas.ativas["martelo_trovao"]
	a.st.recarga = 99.0
	a.t = 0.0
	passos(1)
	var aneis := vivos("anel")
	ok(
		aneis.size() == 1 and absf(float(aneis[0].aux) - Novas.QUEDA_ANEL) < 0.001,
		"o martelo cai antes da onda (preparo %.2f)" % (float(aneis[0].aux) if aneis.size() > 0 else -1.0)
	)
	var v0 := float(m.vida)
	passos(int(Novas.QUEDA_ANEL / PASSO) - 2)
	ok(float(m.vida) == v0, "nenhum dano enquanto o martelo cai")
	passos(40)
	ok(float(m.vida) < v0, "a onda do martelo fere depois da queda")


## Nuvem: não fere enquanto se forma; fere depois.
func checar_nuvem() -> void:
	zerar()
	var m = alvo(60.0)
	w.combate.armas.definir_golpe("nuvem_veneno", 1, 0.0)
	var a: Dictionary = w.combate.armas.ativas["nuvem_veneno"]
	a.st.recarga = 99.0
	a.t = 0.0
	passos(1)
	ok(vivos("nuvem").size() == 1, "a nuvem caiu")
	var v0 := float(m.vida)
	passos(int(Novas.ENTRADA_NUVEM / PASSO) - 3)
	ok(float(m.vida) == v0, "nenhum dano enquanto a nuvem se forma")
	passos(30)
	ok(float(m.vida) < v0, "a nuvem fere depois de formada")


## Meteoro: fere na queda (não antes) e toca impacto e marca no chão.
func checar_meteoro() -> void:
	zerar()
	var m = alvo(60.0)
	w.combate.armas.definir_golpe("meteoro_flamejante", 1, 0.0)
	var a: Dictionary = w.combate.armas.ativas["meteoro_flamejante"]
	a.st.quantidade = 1
	a.st.recarga = 99.0
	a.t = 0.0
	passos(1)
	var met := vivos("meteoro")
	ok(met.size() == 1, "o meteoro marcou o chão")
	if met.is_empty():
		return
	var v0 := float(m.vida)
	var imp0: int = novas().impactos
	var it: Dictionary = met[0]
	ok(novas()._queda_e(it) < 0.0, "no começo do aviso o meteoro só cintila no alto")
	passos(int(float(a.st.aviso) * 0.6 / PASSO))
	var e1: float = novas()._queda_e(it)
	var meio: Vector2 = novas()._queda(it)
	passos(int(float(a.st.aviso) * 0.2 / PASSO))
	var e2: float = novas()._queda_e(it)
	ok(e1 >= 0.0 and e2 > e1 and (e2 - e1) > e1 * 0.5, "a queda acelera (%.2f -> %.2f)" % [e1, e2])
	ok(absf(meio.x - (it.p as Vector2).x) > 2.0, "a trajetória é inclinada, não reta para baixo")
	passos(int(float(a.st.aviso) * 0.2 / PASSO) - 2)
	ok(
		(novas()._queda(it) as Vector2).distance_to(it.p) < 24.0,
		"no fim do aviso o meteoro chega perto do chão (%.0f px)" % (novas()._queda(it) as Vector2).distance_to(it.p)
	)
	ok(float(m.vida) == v0, "nada de dano durante o aviso")
	passos(10)
	ok(float(m.vida) < v0, "o meteoro fere na queda")
	ok(novas().impactos == imp0 + 2, "impacto e marca tocaram na queda (%d)" % (novas().impactos - imp0))


## Runa: só arma depois de 0,5 s (o glifo se desenha sem gatilho) e o estouro toca no instante do dano; raio: o estalo toca em cada alvo.
func checar_runa_raio() -> void:
	zerar()
	var m = alvo(70.0)
	w.combate.armas.definir_golpe("runa", 1, 0.0)
	var a: Dictionary = w.combate.armas.ativas["runa"]
	a.t = 0.0
	var armas = w.combate.armas
	passos(1)
	var i := -1
	for j in armas.MAX_RUNAS:
		if armas.r_vida[j] > 0.0:
			i = j
	ok(i >= 0, "a runa caiu no chão")
	if i >= 0:
		armas.r_pos[i] = m.pos  # em cima do monstro: só pode estourar depois de armada
		var v0 := float(m.vida)
		passos(20)
		ok(float(m.vida) == v0, "a runa não estoura enquanto se arma")
		var imp0: int = novas().impactos
		passos(30)
		ok(float(m.vida) < v0, "a runa armada estoura com o monstro em cima")
		ok(novas().impactos > imp0, "o estouro da runa tocou a folha")
	zerar()
	var m2 = alvo(60.0)
	w.combate.armas.definir_golpe("raio", 1, 0.0)
	w.combate.armas.ativas["raio"].t = 0.0
	var imp1: int = novas().impactos
	passos(3)
	ok(m2.vida < m2.vida_max and novas().impactos > imp1, "o raio fere e o estalo toca no alvo")


## A katana só fere no quadro do acerto (acerto_em) e uma vez por golpe.
func checar_katana() -> void:
	zerar()
	var m = alvo(30.0)
	var v0 := float(m.vida)
	w.heroi.ataque_forcado = true
	passos(2)
	w.heroi.ataque_forcado = false
	var passo: Dictionary = w.combate.cfg.golpe.passos[0]
	var t_acerto: float = float(passo.duracao) * float(passo.acerto_em) / float(w.heroi.m_vel_ataque)
	var antes := int(floor(t_acerto / PASSO)) - 2
	if antes > 0:
		passos(antes)
	ok(float(m.vida) == v0, "a katana não fere antes do acerto")
	ok(w.heroi.fase_golpe() == "preparo", "antes do acerto a fase é preparo (%s)" % w.heroi.fase_golpe())
	passos(4)
	ok(m.acertos == 1, "a katana fere no quadro do acerto (%d)" % m.acertos)
	passos(4)
	ok(w.heroi.fase_golpe() in ["recuperacao", "pronto"], "depois do acerto a fase é recuperação (%s)" % w.heroi.fase_golpe())
	passos(int(float(passo.duracao) / PASSO))
	ok(m.acertos == 1, "a katana fere uma vez por golpe (%d)" % m.acertos)


## Muitos golpes e monstros juntos: o pool não cresce e nenhum nó aparece na camada.
func checar_volume() -> void:
	zerar()
	for i in 30:
		var ang := TAU * i / 30.0
		alvo(cos(ang) * 120.0, sin(ang) * 70.0)
	for g in w.combate.cartas.cfg.golpes:
		if str(g.get("tipo", "")) in ["projetil", "anel", "meteoro", "nuvem"]:
			w.combate.armas.definir_golpe(str(g.id), 5, 0.0)
	for id in ["corvos", "aura_fogo", "raio", "runa", "laminas"]:
		w.combate.armas.definir_golpe(id, 5, 0.0)
	w.heroi.m_vel_ataque = 3.0
	passos(600)
	ok(novas().itens.size() == Novas.MAX, "o pool continua com %d slots" % Novas.MAX)
	ok(novas().x_pos.size() == Novas.MAX_FX, "o pool de efeitos continua com %d" % Novas.MAX_FX)
	var armas = w.combate.armas
	ok(armas.no_brilho.get_child_count() == 0 and armas.no_corpo.get_child_count() == 0 and armas.no_nevoa.get_child_count() == 0, "nenhum nó novo")
	ok(novas().impactos > 50, "os impactos tocaram com a horda (%d)" % novas().impactos)
	w.heroi.m_vel_ataque = 1.0


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	checar_folhas()
	checar_projetil()
	checar_velocidade()
	checar_alvo_some()
	checar_ricochete()
	checar_critico()
	checar_anel()
	checar_nuvem()
	checar_meteoro()
	checar_martelo()
	checar_runa_raio()
	checar_katana()
	checar_volume()
	print("v2_combate_fases falhas=%d" % falhas)
	get_tree().quit()
