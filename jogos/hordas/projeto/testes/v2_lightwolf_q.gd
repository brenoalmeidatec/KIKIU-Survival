extends "res://testes/isolamento_v2.gd"
# Teste do LW-5 (#511): o Q do LightWolf em forma de mecha, a AUTODESTRUIÇÃO (v2/especial.gd `_q_autodestruicao`, v2/mecha.gd `autodestruir`, dados/v2_especial.json >
# autodestruicao), e a Maré do LightWolf ligada a ele (v2/diretor.gd `mare_chamar`, bloco `mare`: anel, atraso 4 s, curta). Confere: os dados e os ícones A20 e A21; o aperto
# (o piloto vira Lobo na hora, invulnerável, com o chamado em 45 e o Q do mecha gasto, sem estouro de quebra), o fusível de 1 s (nada morre antes, o piloto salta para trás da
# mira, o corpo não leva dano, a pausa congela), a explosão (um estouro, uma limpeza saindo de onde o mecha ficou: comuns morrem, a elite perde 60% e vive), a Maré chamada
# (4 s depois, curta, em anel pelos quatro lados) e a volta do mecha pelo CHAMAR (vida cheia, Q de novo em 0). Um herói sem formas (Hazaki) segue com o Q dele.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_lightwolf_q.tscn  (imprime "v2_lightwolf_q falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const PASSO := 1.0 / 60.0
const COMUM := "inimigo_homunculo"

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func novo(id: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()


## Mapa sem monstros, sem diretor, herói parado e vulnerável com a mira à direita, câmera nele, Q ainda sem carga.
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = false
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = null
	h.correr_forcado = null
	h.ruptura_forcada = false
	h.escudo_forcado = false
	h.fonte = Heroi.Fonte.MOUSE
	h.m_critico = -1.0
	h.vida = h.vida_max
	h.invenc = 0.0
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)
	w.cam.cravar(h.centro())


func parado(m, vida: float) -> void:
	m.vida = vida
	m.vida_max = vida
	m.emp = Vector2.ZERO
	m.atordoa_t = 60.0


## `n` comuns parados e com muita vida numa grade de 14 colunas dentro da câmera (±420 x ±200 px do herói); devolve a lista.
func comuns(n: int) -> Array:
	var lista: Array = []
	var p: Vector2 = w.heroi.pos
	for k in n:
		var m = w.nascer_monstro(COMUM, p + Vector2(-420.0 + float(k % 14) * 64.6, -200.0 + float(k / 14) * 36.4))
		parado(m, 5000.0)
		lista.append(m)
	return lista


func vivos(lista: Array) -> int:
	var n := 0
	for m in lista:
		if m.vivo:
			n += 1
	return n


func _ready() -> void:
	_t_dados()
	await _t_cena()
	await _t_pausa()
	await _t_mare()
	await _t_hazaki()
	Herois.forcado = ""
	print("v2_lightwolf_q falhas=%d" % falhas)
	get_tree().quit()


func _t_dados() -> void:
	var d: Dictionary = Dados.json("v2_especial")
	ok(str(d.herois.get("lightwolf", "")) == "autodestruicao" and d.has("autodestruicao"), "o Q do mecha é a AUTODESTRUIÇÃO (não o Terremoto provisório)")
	ok(str(d.herois.get("lightwolf_lobo", "")) == "chamar", "o Q do Lobo segue o CHAMAR")
	var b: Dictionary = d.autodestruicao
	ok(is_equal_approx(float(b.dur), 1.0) and is_equal_approx(float(b.limpa_em), 1.0), "fusível de 1,0 s e a limpeza no instante da explosão (D07)")
	ok(float(b.salto.t) > 0.0 and float(b.salto.t) < float(b.dur) and float(b.salto.distancia) > 0.0, "o salto do piloto cabe dentro do fusível")
	var m: Dictionary = b.mare
	ok(str(m.formacao) == "anel" and is_equal_approx(float(m.atraso), 4.0) and bool(m.get("curta", false)), "Maré do LightWolf: anel, atraso 4 s, curta")
	ok(is_equal_approx(float(d.chamar.inicio_autodestruicao), 45.0), "depois da autodestruição o chamado começa em 45")
	for nome in ["lightwolf", "lightwolf_lobo"]:
		var t := load("res://assets/v2/especial_q/%s.png" % nome) as Texture2D
		ok(t != null and t.get_width() == 32 and t.get_height() == 32, "ícone do Q %s existe e tem 32x32 (A20 / A21)" % nome)


## O Q inteiro, com 60 comuns, uma elite e dois comuns longe da câmera.
func _t_cena() -> void:
	await novo("lightwolf")
	var h = w.heroi
	var c = w.combate
	var esp = c.especial
	ok(esp.id_de("lightwolf") == "autodestruicao" and h.esp_rotulo == "EXPLODIR", "o mecha nasce com o Q Autodestruição (rótulo %s)" % h.esp_rotulo)
	h.esp_carga = 40.0
	ok(not h.especial() and h.estado != Heroi.Estado.ESPECIAL and not h.forma_lobo, "sem a carga cheia o aperto é negado e nada muda")
	var lista := comuns(60)
	var p: Vector2 = h.pos
	var elite = w.nascer_monstro(COMUM, p + Vector2(-380, -100))
	parado(elite, 1000.0)
	elite.elite = true
	var longe: Array = []
	for dx in [-900.0, 900.0]:
		var lo = w.nascer_monstro(COMUM, p + Vector2(dx, 0))
		parado(lo, 5000.0)
		longe.append(lo)
	passos(2)
	h.esp_carga = h.esp_carga_max
	var vida_mecha_max: float = h.vida_max
	var origem: Vector2 = h.pos
	ok(h.especial(), "com a carga cheia o Q dispara")
	# o aperto: o piloto vira Lobo NA HORA, e o fusível o prende no estado do Q, invulnerável
	ok(h.forma_lobo and str(h.chave) == "lightwolf_lobo", "o piloto virou Lobo no aperto")
	ok(h.estado == Heroi.Estado.ESPECIAL and h.esp_invul, "o fusível é Estado.ESPECIAL e invulnerável")
	ok(h.invenc >= 1.49, "invulnerável por 1,5 s (%.2f)" % h.invenc)
	ok(
		is_equal_approx(h.vida_max, vida_mecha_max * 0.31) and is_equal_approx(h.vida, h.vida_max),
		"vida do Lobo: 31%% da do mecha, cheia (%.1f de %.1f)" % [h.vida, h.vida_max]
	)
	ok(is_equal_approx(h.esp_carga, 45.0) and h.esp_rotulo == "CHAMAR", "o chamado começa em 45 (%.1f) e o Q vira CHAMAR" % h.esp_carga)
	ok(is_equal_approx(c.mecha.carga_mecha, 0.0), "o Q do mecha foi gasto: volta a 0 quando ele cair (%.1f)" % c.mecha.carga_mecha)
	ok(c.mecha.autodestruicoes == 1 and c.mecha.quebras == 0, "uma autodestruição, nenhuma quebra (sem estouro nem empurrão de quebra)")
	ok(not esp._g_tipo.is_empty() and int(esp._g_tipo.w) == 64, "o mecha que fica no lugar guarda a folha dele (64 de largura)")
	# o fusível: meio segundo depois nada morreu, o piloto saltou para trás da mira, e o corpo não leva dano
	passos(30)
	ok(esp.limpas == 0 and esp.explosoes == 0 and vivos(lista) == 60, "durante o fusível nada explode nem morre")
	ok(h.pos.x < origem.x - 20.0, "o piloto saltou para trás da mira (x %.1f -> %.1f)" % [origem.x, h.pos.x])
	var vida0: float = h.vida
	ok(not h.levar_dano(30.0, h.pos + Vector2(10, 0)) and is_equal_approx(h.vida, vida0), "no fusível o Lobo não leva dano")
	h.imortal = true  # a elite acordaria depois; o resto do teste mede o Q, não a sobrevivência
	# a explosão: um estouro, uma limpeza
	var visto := 0
	for f in 120:
		w.avancar(PASSO)
		if esp.explosoes > 0:
			break
		visto += 1
	ok(esp.explosoes == 1 and esp.limpas == 1, "o mecha explode uma vez e limpa a tela uma vez (%d, %d)" % [esp.explosoes, esp.limpas])
	ok(
		h.estado == Heroi.Estado.LIVRE and h.forma_lobo and h.invenc > 0.0,
		"depois da explosão o Lobo está livre, ainda Lobo e ainda protegido (%.2f s)" % h.invenc
	)
	for f in 80:
		w.avancar(PASSO)
	ok(vivos(lista) == 0, "todos os comuns da tela morreram (sobraram %d)" % vivos(lista))
	ok(vivos(longe) == 2, "quem está fora da câmera mais a margem sobrevive")
	ok(
		elite.vivo and absf((elite.vida_max - elite.vida) / elite.vida_max - 0.6) < 0.02,
		"a elite perde 60%% e vive (%.0f de %.0f)" % [elite.vida, elite.vida_max]
	)
	ok(str(esp.ultimo.get("id", "")) == "autodestruicao", "o último Q foi a autodestruição")
	# o chamado: 45 não basta; cheio, o mecha cai e volta com vida cheia e o Q de antes (0)
	ok(h.forma_lobo and h.esp_carga < h.esp_carga_max and not h.especial(), "com o chamado em %.0f o CHAMAR é negado" % h.esp_carga)
	h.esp_carga = h.esp_carga_max
	ok(h.especial(), "chamado cheio: o Lobo chama o mecha")
	for f in 90:
		w.avancar(PASSO)
		if not h.forma_lobo:
			break
	ok(not h.forma_lobo and str(h.chave) == "lightwolf" and c.mecha.chamados == 1, "o mecha voltou")
	ok(is_equal_approx(h.vida_max, vida_mecha_max) and is_equal_approx(h.vida, vida_mecha_max), "voltou com a vida cheia (%.1f)" % h.vida)
	ok(h.esp_carga < 1.0 and h.esp_rotulo == "EXPLODIR", "o Q do mecha voltou gasto (%.1f) e é a Autodestruição de novo" % h.esp_carga)
	ok(esp.limpas == 1, "o CHAMAR não limpa a tela: segue uma limpeza só")


## A pausa congela o fusível: o relógio do Q não anda e o mecha não explode.
func _t_pausa() -> void:
	await novo("lightwolf")
	var h = w.heroi
	var esp = w.combate.especial
	h.esp_carga = h.esp_carga_max
	ok(h.especial(), "dispara")
	passos(10)
	var t0: float = esp._t
	w.combate.pausado = true
	passos(90)
	ok(is_equal_approx(esp._t, t0) and esp.explosoes == 0, "a pausa congela o fusível (%.3f -> %.3f)" % [t0, esp._t])
	w.combate.pausado = false
	passos(70)
	ok(esp.explosoes == 1, "solta a pausa, o fusível termina e explode")


## A Maré do LightWolf: chamada pela explosão, 4 s depois, curta e em anel (sai também por cima e por baixo da tela).
func _t_mare() -> void:
	await novo("lightwolf")
	var h = w.heroi
	var c = w.combate
	var d = c.diretor
	h.imortal = true
	d.ligado = true
	d.mare_ultima_t = -1000.0
	d.proxima_onda = d.relogio() + 500.0
	h.esp_carga = h.esp_carga_max
	ok(h.especial(), "dispara")
	for f in 160:
		w.avancar(PASSO)
		if d.mare_chamadas > 0:
			break
	ok(d.mare_chamadas == 1 and d.mare_chamada_t > 3.5 and d.mare_chamada_t <= 4.0, "a explosão chama a Maré para daqui a 4 s (%.2f)" % d.mare_chamada_t)
	ok(
		is_equal_approx(d.mare_chamada_fator, float(d._mare_cfg("q_curta"))),
		"a Maré do LightWolf vem curta mesmo faz tempo desde a última (x%.2f)" % d.mare_chamada_fator
	)
	var m: Dictionary = c.especial.mare_de(str(c.heroi_id))
	ok(str(m.formacao) == "anel" and is_equal_approx(float(m.atraso), 4.0), "o diretor lê a Maré do herói da partida: anel de 4 s")
	ok(h.forma_lobo and str(h.chave) == "lightwolf_lobo", "e é Lobo quem aperta o Q: a Maré não depende da chave da forma")
	# a Maré chega: anel (cima, baixo e os lados), tudo marcado
	d.mare_chamada_t = 0.02
	d.atualizar(0.1)
	d.atualizar(1.1)
	var tela: Rect2 = w.cam.retangulo()
	var marcados := 0
	var lados := 0
	var cima_baixo := 0
	for mo in w.monstros:
		if not mo.mare:
			continue
		marcados += 1
		if mo.pos.y < tela.position.y or mo.pos.y > tela.end.y:
			cima_baixo += 1
		if mo.pos.x < tela.position.x or mo.pos.x > tela.end.x:
			lados += 1
	ok(marcados >= 6, "a Maré chegou com monstros marcados (%d)" % marcados)
	ok(cima_baixo >= 1 and lados >= 1, "em anel: sai por cima/baixo (%d) e pelos lados (%d)" % [cima_baixo, lados])
	# abater a Maré enche o chamado do Lobo (x2,2 do comum.mare), não o Q do mecha
	c.especial.cancelar(h)
	c.especial._graca = 0.0
	c.especial._onda_t = -1.0
	h.esp_carga = 10.0
	var mo2 = w.nascer_monstro(COMUM, h.pos + Vector2(300, 0))
	mo2.mare = true
	c.especial.abate(mo2)
	var ganho: float = h.esp_carga - 10.0
	var esperado: float = 0.8 * float(m.abate_carga) / (1.0 + 0.15 * float(maxi(h.nivel - 1, 0)))
	ok(is_equal_approx(ganho, esperado), "abate da Maré enche o chamado x%.1f (+%.2f, esperado %.2f)" % [float(m.abate_carga), ganho, esperado])


## O Hazaki (sem formas) segue com o Q dele: nada da autodestruição vaza.
func _t_hazaki() -> void:
	await novo("hazaki")
	var h = w.heroi
	ok(w.combate.especial.id_de("hazaki") == "investida" and not w.combate.mecha.tem(), "o Hazaki segue com a investida e sem formas")
	h.esp_carga = h.esp_carga_max
	ok(h.especial() and not h.forma_lobo and str(h.chave) == "hazaki", "o Q do Hazaki não vira Lobo")
	passos(70)
	ok(w.combate.mecha.autodestruicoes == 0 and w.combate.especial.explosoes == 0, "nenhuma autodestruição")
