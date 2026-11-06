extends "res://testes/isolamento_v2.gd"
# Teste automático do v2/fx_status.gd: chama (queima_t), relógio (lento_t) e estrelas (atordoa_t) sobre o monstro, e o relógio sobre o herói na teia
# da Rainha. Prova: o efeito nasce quando o status começa e some quando acaba; o atordoamento curto (corte comum) não acende estrelas; morte, volta ao
# pool, saída da tela, perfil Baixo e limpar_partida soltam tudo; o limite de monstros com efeito vale (e as últimas vagas são de elite e chefe);
# nenhum nó nasce no meio da partida. A chama alta é uma folha por monstro (3 tamanhos); a arte e o desenho dela estão em v2_chama_sprites.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_fx_status.tscn  (imprime "v2_fx_status falhas=0")
const Anim := preload("res://v2/anim_golpes.gd")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
const TIPO := "inimigo_cao_ossos"
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _nos_total(raiz: Node) -> int:
	var n := 1
	for c in raiz.get_children():
		n += _nos_total(c)
	return n


func _quadros(w, n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _ready() -> void:
	Anim.suave = true
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	var c = w.combate
	var cf = c.fx_folha
	var st = c.fx_status
	ok(
		st != null and cf.tem("chama_p") and cf.tem("chama_m") and cf.tem("chama_g") and cf.tem("slowed") and cf.tem("stunned"),
		"o combate monta o fx_status e o registro tem as três chamas, o relógio e as estrelas"
	)
	var nos0 := _nos_total(w.glow)  # a camada onde moram as âncoras e os nós de desenho do fx_folha
	var p0: Vector2 = w.heroi.pos

	# 1. fogo: o corpo em brasa vem do shader (v2/status_corpo.gd) e a chama alta é uma folha presa ao monstro, do tamanho dele
	var m = w.nascer_monstro(TIPO, p0 + Vector2(40, 0))
	m.queimar(0.2, 0.6)
	_quadros(w, 20)
	ok(m._estado_corpo() == 1 and st.n_efeitos() == 1, "queimando: o fogo está no corpo e há uma chama presa (efeitos=%d)" % st.n_efeitos())
	var vaga: int = st._m.find(m)
	ok(vaga >= 0 and cf.vivo(st._alca[vaga * 3]), "a chama é do monstro que queima (vaga %d)" % vaga)
	ok(
		st.id_fogo(m.alt) == ("chama_p" if m.alt < 56.0 else "chama_m"),
		"a folha da chama segue a altura do monstro (alt %.0f: %s)" % [m.alt, st.id_fogo(m.alt)]
	)
	m.definir_pos(m.pos + Vector2(30, 0))
	_quadros(w, 4)
	ok((st._anc[vaga] as Node2D).global_position == m.pr, "a chama segue o monstro: a âncora está nos pés dele")
	_quadros(w, 40)
	ok(m.queima_t <= 0.0 and m._estado_corpo() == 0 and st.n_efeitos() == 0, "o fogo acabou: o corpo volta ao normal e a chama é solta (%d)" % st.n_efeitos())

	# 2. lento e atordoado no mesmo monstro: três efeitos; o corte curto não acende estrelas
	m.atordoa_t = 0.3
	_quadros(w, 12)
	ok(st.n_efeitos() == 0, "atordoamento curto (0,3 s) não acende estrelas (%d)" % st.n_efeitos())
	m.deixar_lento(1.0)
	m.queimar(0.2, 1.0)
	m.atordoa_t = 0.9
	_quadros(w, 12)
	ok(st.n_efeitos() == 3 and st.ativos == 1, "fogo, lento e atordoado juntos: chama, relógio e estrelas num monstro (%d)" % st.n_efeitos())
	_quadros(w, 80)
	ok(st.n_efeitos() == 0 and st.ativos == 0, "tudo acabou: nada preso (%d)" % st.n_efeitos())

	# 3. morte solta
	m.queimar(0.2, 5.0)
	m.deixar_lento(5.0)
	_quadros(w, 12)
	ok(st.n_efeitos() == 2, "antes de morrer: a chama e o relógio (%d)" % st.n_efeitos())
	c.ferir(m, 9999.0, Vector2.ZERO, 0.0, 0.0, Color.WHITE, false)
	_quadros(w, 4)
	ok(not m.vivo and st.n_efeitos() == 0 and st.ativos == 0, "o monstro morreu: os efeitos foram soltos (%d)" % st.n_efeitos())

	# 4. volta ao pool com status: o monstro reaproveitado nasce limpo e sem efeito
	var m2 = w.nascer_monstro(TIPO, p0 + Vector2(-40, 0))
	m2.deixar_lento(5.0)
	_quadros(w, 12)
	ok(st.n_efeitos() == 1, "segundo monstro lento (%d)" % st.n_efeitos())
	m2.esconder()
	m2.morrendo = false
	w.devolver_monstro(m2)
	_quadros(w, 4)
	ok(st.n_efeitos() == 0 and st.ativos == 0, "monstro devolvido ao pool solta o efeito (%d)" % st.n_efeitos())
	# o mesmo monstro renasce do pool: sem fogo, sem lentidão, sem atordoamento e sem efeito nenhum preso
	var m2b = w.nascer_monstro(TIPO, p0 + Vector2(-40, 0))
	ok(m2b == m2, "o pool devolveu o mesmo monstro (reaproveitado)")
	ok(
		m2b.vivo and m2b.queima_t == 0.0 and m2b.lento_t == 0.0 and m2b.atordoa_t == 0.0,
		"o reaproveitado renasce sem status (fogo=%.2f lento=%.2f atordoa=%.2f)" % [m2b.queima_t, m2b.lento_t, m2b.atordoa_t]
	)
	_quadros(w, 24)
	ok(st.n_efeitos() == 0 and st.ativos == 0, "o reaproveitado nasce sem efeito (%d)" % st.n_efeitos())
	m2b.esconder()
	m2b.morrendo = false
	w.devolver_monstro(m2b)

	# 5. saiu da tela: solta; voltou: pega de novo
	var m3 = w.nascer_monstro(TIPO, p0 + Vector2(0, 40))
	m3.deixar_lento(30.0)
	_quadros(w, 12)
	ok(st.n_efeitos() == 1, "lento na tela: relógio (%d)" % st.n_efeitos())
	m3.sem_colisao_ate_sair = true
	m3.definir_pos(p0 + Vector2(4000, 0))
	_quadros(w, 12)
	ok(st.n_efeitos() == 0, "fora da tela: sem efeito (%d)" % st.n_efeitos())
	m3.definir_pos(p0 + Vector2(0, 40))
	_quadros(w, 24)
	ok(st.n_efeitos() == 1, "voltou à tela: o relógio volta (%d)" % st.n_efeitos())
	m3.lento_t = 0.0
	_quadros(w, 4)

	# 6. limite: mais monstros com status que o teto de monstros, misturando os três tipos para o teto de cada um não barrar antes. O monstro comum
	# para em max_monstros - reserva_elite: as últimas vagas são de elite e chefe (a horda queimando não tira a chama de quem importa)
	var lista: Array = []
	for k in 24:
		var mk = w.nascer_monstro(TIPO, p0 + Vector2(-90 + 7 * k, 70))
		match k % 3:
			0:
				mk.deixar_lento(20.0)
			1:
				mk.atordoa_t = 20.0
			_:
				mk.queimar(0.0, 20.0)
		lista.append(mk)
	var com_status := 0
	for mk in lista:
		if mk.queima_t > 0.0 or mk.lento_t > 0.0 or mk.atordoa_t >= st.ATORDOA_MIN:
			com_status += 1
	var teto_comum: int = st.max_monstros - st.reserva_elite
	ok(com_status > st.max_monstros, "há mais monstros com status (%d) que o teto de monstros (%d)" % [com_status, st.max_monstros])
	_quadros(w, 90)
	ok(st.ativos == teto_comum, "o teto dos comuns foi o que barrou: %d de %d com efeito" % [st.ativos, teto_comum])
	ok(st.n_efeitos() >= teto_comum, "e há ao menos um efeito por monstro preso (%d)" % st.n_efeitos())
	ok(st.n_efeitos() <= st.limite[0] + st.limite[1] + st.limite[2], "efeitos dentro da soma dos limites por tipo (%d)" % st.n_efeitos())
	ok(st.limite[0] >= st.max_monstros, "o limite de chamas cobre um fogo por monstro com efeito (%d de %d)" % [st.limite[0], st.max_monstros])
	var elite = w.combate.elites.nascer(TIPO, "", p0 + Vector2(0, -60))
	var chefe = w.combate.elites.nascer(TIPO, "", p0 + Vector2(40, -60))
	ok(elite != null and chefe != null, "duas elites nasceram")
	nos0 = _nos_total(w.glow)  # a elite tem nós próprios (contorno, olhos): só o que o status criar depois disto conta
	if elite != null and chefe != null:
		elite.queimar(0.0, 20.0)
		chefe.queimar(0.0, 20.0)
		_quadros(w, 90)
		ok(st.ativos == st.max_monstros, "a elite e o chefe ocuparam as vagas reservadas: %d de %d" % [st.ativos, st.max_monstros])
		ok(st._m.has(elite) and st._m.has(chefe), "as duas elites queimando têm vaga com a horda queimando")
		var ve: int = st._m.find(elite)
		ok(ve >= 0 and cf.vivo(st._alca[ve * 3]), "e têm a chama presa")
		ok(st.id_fogo(elite.alt) != "chama_p", "a elite (alt %.0f) usa uma chama maior que a do monstro comum (%s)" % [elite.alt, st.id_fogo(elite.alt)])

	# 7. perfil Baixo: nada é desenhado (nem a chama alta: sem sprite extra, fica só o corpo em brasa do shader)
	Anim.suave = false
	_quadros(w, 4)
	ok(st.n_efeitos() == 0 and st.ativos == 0, "perfil Baixo: sem efeito (%d)" % st.n_efeitos())
	Anim.suave = true
	_quadros(w, 40)
	ok(st.n_efeitos() > 0 and cf.ativos > 0, "perfil Médio de novo: os efeitos voltam (%d)" % st.n_efeitos())

	# 8. herói na teia da Rainha: o relógio fica nele e sai quando a teia acaba
	c.limpar_partida()
	ok(st.n_efeitos() == 0 and st.ativos == 0 and cf.ativos == 0, "limpar_partida solta tudo (%d)" % cf.ativos)
	c.chefes._teia_t = 1.0
	_quadros(w, 6)
	ok(st.heroi_com_efeito() and cf.vivo(st._alca_heroi), "herói preso na teia: relógio sobre ele")
	c.chefes._teia_t = 0.0
	_quadros(w, 6)
	ok(not st.heroi_com_efeito(), "a teia acabou: relógio solto")

	ok(_nos_total(w.glow) == nos0, "nenhum nó nasceu na camada de efeitos durante a partida (%d -> %d)" % [nos0, _nos_total(w.glow)])
	w.queue_free()
	await get_tree().process_frame
	print("v2_fx_status falhas=", falhas)
	get_tree().quit(1 if falhas else 0)
