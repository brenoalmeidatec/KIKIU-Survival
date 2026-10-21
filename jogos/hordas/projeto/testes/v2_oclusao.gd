extends Node
# Teste automático da oclusão da v2 (leva 4): o jogador sempre enxerga o herói.
#   - herói ATRÁS de uma árvore: o buraco raio-x da árvore liga (força 1, centro no herói) e a silhueta fica desligada (sem duplicar);
#   - campo aberto, sem nada na frente: os dois desligam;
#   - MONSTRO grande na FRENTE cobrindo o herói: a silhueta liga (entra aos poucos, depois fica inteira) e a árvore não muda;
#   - monstro ATRÁS do herói, ou na frente mas longe (sem cobrir o corpo): a silhueta fica desligada;
#   - a silhueta sai com transição quando o monstro some (não de um quadro para o outro);
#   - desempenho: o custo por atualização com 100 atores só imprime no CI (padrão do testes/v2_colisao.gd).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_oclusao.tscn  (imprime "v2_oclusao falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Oclusao := preload("res://v2/oclusao.gd")
const PASSO := 1.0 / 60.0
const ABERTO := Vector2(1440.0, 820.0)  # ponto de nascimento do herói: campo aberto, sem árvore atrás dele
const META_US := 400  # µs por atualização com 100 atores (só imprime no CI, onde a máquina é compartilhada)
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Um monstro grande (escala 2) com o pé em `p`, parado no lugar (sem vagar): o teste mede a posição, não o movimento dele.
func monstro_em(p: Vector2, escala := 2.0):
	var m = w.nascer_monstro("inimigo_aranha_tecela", p, false)
	m.definir_escala(escala)
	m.raio_vaga = 0.0
	return m


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)  # os passos são nossos
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.imortal = true  # o contato dos monstros do teste não derruba o herói no meio da conta
	w.combate.diretor.ligado = false  # nada de ondas nascendo na frente do herói durante o teste
	w.combate.limpar_partida()  # os monstros da abertura saem: o teste põe os seus
	_t_nicao_sem_vazio()

	# 1. herói atrás de uma árvore do meio do mapa: o buraco liga; a silhueta não (a árvore não é monstro)
	var arvore = null
	for o in w.cenario.objetos:
		if o.chave == "arvore" and o.pos.x > 500.0 and o.pos.x < 2300.0 and o.pos.y > 500.0 and o.pos.y < 1100.0:
			arvore = o
			break
	ok(arvore != null, "o mapa tem arvore no meio")
	if arvore != null:
		w.heroi.definir_pos(arvore.pos + Vector2(0, -40))
		passos(90)
		ok(w.copas.fuerza_da_copa(arvore) > 0.97, "atrás da árvore: o buraco raio-x liga (força %.2f)" % w.copas.fuerza_da_copa(arvore))
		var centro: Vector2 = arvore.sprite.material.get_shader_parameter("centro")
		ok(centro.distance_to(w.heroi.centro()) < 1.0, "atrás da árvore: o centro do buraco é o herói")
		ok(w.oclusao.alfa() < 0.03, "atrás da árvore: a silhueta fica desligada, sem duplicar o buraco (alfa %.2f)" % w.oclusao.alfa())

	# 2. campo aberto, sem nada na frente: os dois desligam
	w.heroi.definir_pos(ABERTO)
	passos(90)
	ok(not w.copas.alguma_ativa(), "campo aberto: nenhum buraco de árvore aberto")
	ok(w.oclusao.alfa() < 0.03, "campo aberto: a silhueta fica desligada (alfa %.2f)" % w.oclusao.alfa())

	# 3. monstro grande na frente cobrindo o corpo: a silhueta entra aos poucos e fica inteira
	var grande = monstro_em(ABERTO + Vector2(0, 12))
	passos(3)
	var entrando: float = w.oclusao.alfa()
	ok(entrando > 0.05 and entrando < 0.95, "monstro na frente: a silhueta entra aos poucos (3 quadros: %.2f)" % entrando)
	passos(60)
	ok(w.oclusao.alfa() > 0.97, "monstro na frente: a silhueta fica inteira (alfa %.2f)" % w.oclusao.alfa())
	ok(w.oclusao.coberto(), "monstro na frente: o teste de cobertura acha o monstro")
	ok(not w.copas.alguma_ativa(), "monstro na frente: a árvore não muda (o buraco é só do herói atrás dela)")

	# 4. o monstro some: a silhueta sai aos poucos
	w.combate.limpar_partida()
	passos(3)
	var saindo: float = w.oclusao.alfa()
	ok(saindo > 0.05 and saindo < 0.95, "monstro some: a silhueta sai aos poucos (3 quadros: %.2f)" % saindo)
	passos(60)
	ok(w.oclusao.alfa() < 0.03, "monstro some: a silhueta desliga (alfa %.2f)" % w.oclusao.alfa())

	# 5. monstro ATRÁS do herói: não encobre (quem desenha por cima é o herói)
	monstro_em(ABERTO + Vector2(0, -12))
	passos(60)
	ok(w.oclusao.alfa() < 0.03, "monstro atrás do herói: a silhueta fica desligada (alfa %.2f)" % w.oclusao.alfa())
	w.combate.limpar_partida()

	# 6. monstro na frente, mas longe (não cobre o corpo do herói): a silhueta fica desligada
	monstro_em(ABERTO + Vector2(150, 12))
	passos(60)
	ok(w.oclusao.alfa() < 0.03, "monstro na frente e longe: a silhueta fica desligada (alfa %.2f)" % w.oclusao.alfa())
	w.combate.limpar_partida()

	# 7. desempenho: 100 atores em volta do herói (a atualização da oclusão, sem o resto do mundo)
	w.heroi.definir_pos(ABERTO)
	for i in 100:
		var a := float(i) * TAU / 100.0
		var r := 60.0 + float(i % 5) * 40.0
		monstro_em(ABERTO + Vector2(cos(a) * r, sin(a) * r * 0.6), 1.0)
	var t0 := Time.get_ticks_usec()
	for i in 600:
		w.oclusao.atualizar(PASSO, w.heroi, w.monstros)
	var us := float(Time.get_ticks_usec() - t0) / 600.0
	if OS.get_environment("CI") != "":
		print("v2_oclusao desempenho: %.1f us por atualização com %d atores (meta %d us)" % [us, w.monstros.size(), META_US])
		if us >= META_US:
			print("AVISO v2_oclusao: desempenho %.1f us acima da meta %d us (só aviso no CI)" % [us, META_US])
	else:
		ok(us < META_US * 4.0, "desempenho: %.1f us por atualização com 100 atores (limite %d us)" % [us, META_US * 4])

	print("v2_oclusao falhas=%d" % falhas)
	get_tree().quit()


## A roda do Q deixa dois cavaleiros a +/-32, +60: o quadro 64x96 do Nicão cruza os dois,
## mas o corpo 38x42 fica livre. Antes a silhueta inteira clareava o herói mesmo após o especial.
func _t_nicao_sem_vazio() -> void:
	var t: Dictionary = w.sprites.tipo("nicao")
	var heroi := {"pos": Vector2.ZERO, "tipo": t}
	var cavaleiro: Dictionary = w.sprites.tipo("inimigo_cavaleiro_oco")
	var roda: Array = [
		{"pos": Vector2(-32, 60), "tipo": cavaleiro, "escala": 1.0},
		{"pos": Vector2(32, 60), "tipo": cavaleiro, "escala": 1.0},
	]
	var oc = Oclusao.new()
	ok(Oclusao._corpo(Vector2.ZERO, t, 1.0) == Rect2(-22, -40, 38, 42), "Nicão: corpo sem o vazio do quadro e a marreta")
	ok(not oc._coberto(heroi, roda), "Nicão depois do Q: cavaleiros ao lado não acendem silhueta sobre o corpo livre")
	var cobrindo: Array = [{"pos": Vector2(0, 12), "tipo": cavaleiro, "escala": 1.0}]
	ok(oc._coberto(heroi, cobrindo), "Nicão realmente coberto por cavaleiro: a silhueta continua disponível")
	var simples := {"w": 32, "h": 44, "pe": 42}
	ok(Oclusao._corpo(Vector2.ZERO, simples, 1.0) == Rect2(-16, -21, 32, 44), "folha sem recorte mantém a cobertura anterior")
