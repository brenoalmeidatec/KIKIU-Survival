extends "res://testes/isolamento_v2.gd"
## MIRA DO LIGHTWOLF ANDANDO E ATIRANDO (rodada 5, 05/11/2026). O vídeo da rodada 4 mostrou três defeitos, e este teste prova cada um:
##  1. andando e segurando o tiro, a mira ATRASAVA 6 a 9 quadros a cada virada do mouse: a rajada (um "golpe" de 0,16 s) travava dir_olhar e
##     golpe_dir até o próximo tiro, e a bala do quadro de acerto saía na direção antiga. Agora, com `golpe.mira_continua` (dados/v2_herois.json),
##     braços (a linha da folha) e balas seguem o mouse no MESMO quadro, e nenhuma bala sai fora da mira de agora;
##  2. segurando o tiro com o mouse e virando o ANDAR sem mexer o mouse, a fonte virava ANDA e a mira congelava. Agora a fonte segue MOUSE
##     enquanto o tiro estiver segurado, e a mira acompanha o ponto do mouse com o herói andando;
##  3. andando SEM atirar com a mira contra o passo (de costas), o andar tocava para a frente (moonwalk). Agora recua um quadro por vez, como o
##     andar_tiro de costas (v2_lw_anda_atira).
## E o controle: os heróis corpo a corpo (Hazaki) seguem com a direção do golpe travada no começo dele.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const TOL := 0.035  # rad (~2 graus): o mesmo quadro, a mesma direção
var falhas := 0
var w


func ok(cond: bool, mensagem: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", mensagem)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.escudo_forcado = false
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(4000, 0)
	for i in 3:
		w.avancar(PASSO)


func montar(heroi: String) -> void:
	if w != null:
		w.queue_free()
	Herois.forcado = heroi
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()


## Andando para a direita e atirando, o mouse vira entre direita, cima, baixo-esquerda... a cada `cada` quadros (fases diferentes da rajada).
## Devolve [quadros atrasados (olhar fora do mouse), linhas da folha fora da do mouse, balas fora da mira de agora, balas contadas].
func viradas(cada: int) -> Array:
	zerar()
	var h = w.heroi
	h.entrada_forcada = Vector2.RIGHT
	h.ataque_forcado = true
	w.avancar(PASSO)
	h.fonte = Heroi.Fonte.MOUSE  # começar a andar troca a fonte para ANDA; o mouse "mexe" (o _input faria isto)
	var dirs := [Vector2.RIGHT, Vector2.UP, Vector2(-1, 1).normalized(), Vector2.DOWN, Vector2(1, -1).normalized(), Vector2.LEFT]
	var atrasos := 0
	var linhas := 0
	var tortas := 0
	var balas := 0
	var g0: int = w.combate.adagas._grupo
	for i in 240:
		var alvo: Vector2 = dirs[(i / cada) % dirs.size()]
		w.mouse_forcado = h.centro() + alvo * 4000.0
		w.avancar(PASSO)
		if i < 20:
			continue
		if absf(h.dir_olhar.angle_to(alvo)) > TOL:
			atrasos += 1
		if h.linha != h.linha_de(alvo):
			linhas += 1
		var g: int = w.combate.adagas._grupo
		if g != g0:  # saiu rajada neste quadro: ela foi na golpe_dir
			balas += 1
			if absf(h.golpe_dir.angle_to(alvo)) > TOL:
				tortas += 1
		g0 = g
	h.ataque_forcado = false
	h.entrada_forcada = Vector2.ZERO
	return [atrasos, linhas, tortas, balas]


func _ready() -> void:
	montar("lightwolf")
	var h = w.heroi
	ok(bool(w.combate.cfg.golpe.get("mira_continua", false)), "o canhão do mecha tem golpe.mira_continua nos dados")

	# 1. a mira e as balas seguem o mouse no mesmo quadro, em qualquer fase da rajada
	var tot := [0, 0, 0, 0]
	for cada in [7, 9, 11, 13, 17]:
		var r := viradas(cada)
		for k in 4:
			tot[k] += r[k]
	print(
		(
			"viradas do mouse andando e atirando: %d quadros com o olhar atrasado, %d com a linha da folha errada, %d de %d rajadas na direção antiga"
			% [tot[0], tot[1], tot[2], tot[3]]
		)
	)
	ok(tot[3] > 50, "as viradas atiraram de verdade (%d rajadas)" % tot[3])
	ok(tot[0] == 0, "o olhar segue o mouse no mesmo quadro, atirando (%d quadros atrasados)" % tot[0])
	ok(tot[1] == 0, "os braços (a linha da folha) seguem o mouse no mesmo quadro (%d quadros errados)" % tot[1])
	ok(tot[2] == 0, "nenhuma rajada sai na direção antiga (%d de %d)" % [tot[2], tot[3]])

	# 2. segurando o tiro com o mouse, virar o andar sem mexer o mouse: a fonte segue MOUSE e a mira segue o ponto do mouse
	zerar()
	h.entrada_forcada = Vector2.LEFT
	h.ataque_forcado = true
	w.avancar(PASSO)
	h.fonte = Heroi.Fonte.MOUSE
	for i in 20:
		w.avancar(PASSO)
	var ponto: Vector2 = h.centro() + Vector2(40, -30)  # o mouse parado num ponto do mundo perto do herói: andando, o ângulo até ele muda
	w.mouse_forcado = ponto
	for i in 6:
		w.avancar(PASSO)
	h.entrada_forcada = Vector2.DOWN  # vira o andar sem mexer o mouse
	var fora_mouse := 0
	var longe := 0
	var giro := 0.0
	var a0: float = (ponto - h.centro()).angle()
	for i in 60:
		w.avancar(PASSO)
		if h.fonte != Heroi.Fonte.MOUSE:
			fora_mouse += 1
		var quer: Vector2 = ponto - h.centro()
		if absf(h.dir_olhar.angle_to(quer)) > TOL:
			longe += 1
		giro = absf(angle_difference(a0, quer.angle()))
	print(
		(
			"virando o andar segurando o tiro: %d quadros fora do mouse, %d com a mira longe do ponto, o ponto girou %.0f graus"
			% [fora_mouse, longe, rad_to_deg(giro)]
		)
	)
	ok(giro > deg_to_rad(20.0), "o caso mede algo: o ângulo até o mouse mudou andando (%.0f graus)" % rad_to_deg(giro))
	ok(fora_mouse == 0, "segurando o tiro com o mouse, virar o andar não troca a fonte para ANDA (%d quadros)" % fora_mouse)
	ok(longe == 0, "a mira segue o ponto do mouse com o herói andando (%d quadros longe)" % longe)
	# soltou o tiro: virar o andar volta a olhar para onde anda (o comportamento de sempre sem tiro)
	h.ataque_forcado = false
	for i in 10:
		w.avancar(PASSO)
	h.entrada_forcada = Vector2.RIGHT
	w.avancar(PASSO)
	ok(h.fonte == Heroi.Fonte.ANDA, "sem tiro, virar o andar ainda passa a olhar para onde anda")
	h.entrada_forcada = Vector2.ZERO

	# 3. andando sem atirar, de costas (para a esquerda, mouse à direita): o andar recua um quadro por vez
	zerar()
	h.entrada_forcada = Vector2.LEFT
	w.avancar(PASSO)
	h.fonte = Heroi.Fonte.MOUSE
	var cs: Array = []
	for i in 150:
		w.mouse_forcado = h.centro() + Vector2(4000, 0)
		w.avancar(PASSO)
		if i >= 30:
			cs.append(h.coluna)
	var n_andar: int = (h.tipo.info.colunas as Array).size() - 1
	var recuos := 0
	var avancos := 0
	var fora := 0
	for i in cs.size():
		if cs[i] < 1 or cs[i] > n_andar:
			fora += 1
			continue
		if i > 0 and cs[i] != cs[i - 1] and cs[i - 1] >= 1 and cs[i - 1] <= n_andar:
			if cs[i] - 1 == posmod(cs[i - 1] - 1 - 1, n_andar):
				recuos += 1
			else:
				avancos += 1
	print("andando de costas sem atirar: %d fora do andar, %d recuos, %d outras trocas" % [fora, recuos, avancos])
	ok(h.dir_olhar.x > 0.9, "de costas: o mecha olha para o mouse (direita) andando para a esquerda")
	ok(fora == 0, "de costas sem atirar, todo quadro é do andar (%d fora)" % fora)
	ok(recuos >= 6 and avancos == 0, "de costas sem atirar, o andar só recua um quadro por vez (%d recuos, %d outras trocas: moonwalk)" % [recuos, avancos])
	# de frente segue avançando
	zerar()
	h.entrada_forcada = Vector2.RIGHT
	w.avancar(PASSO)
	h.fonte = Heroi.Fonte.MOUSE
	var fr: Array = []
	for i in 90:
		w.mouse_forcado = h.centro() + Vector2(4000, 0)
		w.avancar(PASSO)
		fr.append(h.coluna)
	var av := 0
	for i in range(1, fr.size()):
		if fr[i] != fr[i - 1] and fr[i] - 1 == posmod(fr[i - 1], n_andar):
			av += 1
	ok(av >= 6, "de frente, o andar segue avançando (%d avanços)" % av)
	h.entrada_forcada = Vector2.ZERO

	# controle: o Hazaki (corpo a corpo) segue com a direção do golpe travada no começo do golpe
	montar("hazaki")
	h = w.heroi
	ok(not bool(w.combate.cfg.golpe.get("mira_continua", false)), "a katana do Hazaki não tem mira_continua")
	h.ataque_forcado = true
	w.mouse_forcado = h.centro() + Vector2(4000, 0)
	var comecou := false
	for i in 40:
		w.avancar(PASSO)
		if h.estado == Heroi.Estado.GOLPE and h.golpe_t > 0.03:
			comecou = true
			break
	ok(comecou, "o Hazaki começou um golpe")
	var d0: Vector2 = h.golpe_dir
	w.mouse_forcado = h.centro() + Vector2(0, -4000)
	w.avancar(PASSO)
	ok(h.estado != Heroi.Estado.GOLPE or h.golpe_dir == d0, "o golpe do Hazaki não vira no meio (compromisso de direção)")
	h.ataque_forcado = false
	_fim()


func _fim() -> void:
	Herois.forcado = ""
	w.queue_free()
	await get_tree().process_frame
	print("v2_lw_mira falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)
