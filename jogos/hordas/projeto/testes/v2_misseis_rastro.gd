extends "res://testes/isolamento_v2.gd"
# Teste automático do RASTRO dos micro-mísseis da E do LightWolf (v2/misseis_rastro.gd, ligado em v2/adagas.gd; pedido do Alisson de 05/11/2026):
#  - em voo nascem puffs de fumaça, em pixels inteiros, atrás do bocal da imagem DESENHADA (a ATRAS px do centro desenhado, também na descida do pod);
#  - com os mísseis já acabados os puffs terminam sozinhos em DUR (0,6 s do mundo = 0,48 s na tela a 1,25x) e o pool volta a zero;
#  - o pool é fixo (MAX): estressado com centenas de puffs não passa de MAX nem muda de tamanho, e o RNG da partida não é consumido;
#  - as cores são opacas (alfa 0/1), os degraus só escurecem (nunca voltam ao claro) e com "Reduzir piscadas" são só 3, sem o âmbar;
#  - perfil Baixo (poucas ou nenhuma partícula): nenhum puff nasce; a chama do bocal continua (é desenho do míssil, não partícula);
#  - o brilho aditivo não desenha mais a linha de fogo com alfa parcial (a chama é opaca e vai no corpo), e a fumaça é desenhada ANTES das imagens.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_misseis_rastro.tscn  (imprime "v2_misseis_rastro falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Rastro := preload("res://v2/misseis_rastro.gd")
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


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	_arquivo()
	_cores()
	_pool()
	_em_voo()
	_baixo()
	Herois.forcado = ""
	print("v2_misseis_rastro falhas=%d" % falhas)
	get_tree().quit()


func _corpo(src: String, nome: String) -> String:
	var a := src.find("\nfunc %s(" % nome)
	if a < 0:
		return ""
	var b := src.find("\nfunc ", a + 1)
	return src.substr(a, (b if b > 0 else src.length()) - a)


func _zerar(mira: Vector2) -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.centro() + mira * 120.0
	passos(3)
	h.hab_recarga = 0.0
	h.hab_nega_t = 0.0


## O texto: sem sorteio, sem nó, sem alfa parcial; o corpo desenha a fumaça antes do laço das imagens e a chama junto de cada imagem; o brilho não tem mais a linha de fogo.
func _arquivo() -> void:
	var rs := FileAccess.get_file_as_string("res://v2/misseis_rastro.gd")
	ok(rs.length() > 500, "leu misseis_rastro.gd")
	for proibido in ["randf", "randi", "rand_", "RandomNumberGenerator", ".new()", "add_child", "draw_line"]:
		ok(rs.find(proibido) < 0, "misseis_rastro.gd não usa `%s` (sem sorteio, sem nó, sem linha de alfa parcial)" % proibido)
	var ad := FileAccess.get_file_as_string("res://v2/adagas.gd")
	var fum := _corpo(ad, "_fumaca")
	ok(fum != "" and fum.find("rand") < 0, "`_fumaca` existe e não sorteia")
	var corpo := _corpo(ad, "_desenhar_corpo")
	var laco := corpo.find("for i in MAX:")
	var a := corpo.find("rastro.desenhar(")
	ok(a >= 0 and laco > a, "o corpo desenha a fumaça ANTES do laço das imagens (nunca tapa o míssil)")
	ok(corpo.find("MisseisRastro.chama(") > laco, "o corpo desenha a chama do bocal junto de cada míssil")
	ok(_corpo(ad, "_desenhar_brilho").find("Color(1.0, 0.55, 0.14, 0.65)") < 0, "o brilho aditivo não desenha mais a linha de fogo com alfa 0,65")


func _cores() -> void:
	var todas: Array = Rastro.CORES.duplicate()
	todas.append(Rastro.CHAMA_NUCLEO)
	todas.append(Rastro.CHAMA_PONTA)
	for c in todas:
		ok((c as Color).a == 1.0, "cor %s opaca (alfa 0/1)" % c)
	var r := Rastro.new()
	var ultimo := -1
	var vistos := {}
	for k in 101:
		var d := r.degrau(Rastro.DUR * (1.0 - float(k) / 100.0), false)
		ok(d >= ultimo, "degrau normal só avança (%d depois de %d)" % [d, ultimo])
		ultimo = d
		vistos[d] = true
	ok(vistos.size() == Rastro.DEGRAUS, "a vida passa pelos %d degraus (%d)" % [Rastro.DEGRAUS, vistos.size()])
	ultimo = -1
	vistos.clear()
	for k in 101:
		var d := r.degrau(Rastro.DUR * (1.0 - float(k) / 100.0), true)
		ok(d >= ultimo and d >= 1, "degrau calmo só avança e nunca é o âmbar (%d)" % d)
		ultimo = d
		vistos[d] = true
	ok(vistos.size() == 3, "Reduzir piscadas: 3 degraus, não 5 (%d)" % vistos.size())
	for e in range(1, Rastro.CORES.size() - 1):  # do claro para o escuro, sempre: a luminância nunca sobe de um degrau para o seguinte
		ok((Rastro.CORES[e] as Color).get_luminance() > (Rastro.CORES[e + 1] as Color).get_luminance(), "cor %d mais clara que a %d" % [e, e + 1])
	var seg: float = Rastro.DUR / 1.25
	ok(seg >= 0.4 and seg <= 0.6, "vida na tela %.2f s (0,4 a 0,6 com o ritmo 1,25)" % seg)


func _pool() -> void:
	var r := Rastro.new()
	r.montar()
	ok(r.pos.size() == Rastro.MAX and r.resta.size() == Rastro.MAX, "pool montado com MAX posições")
	var semente := randi()
	seed(77)
	var esperado := randi()
	seed(77)
	for k in 400:  # muito mais que o pool, sem envelhecer: toma o lugar do mais antigo
		r.emitir(Vector2(k * 1.3, k * 0.7))
	ok(r.vivos() == Rastro.MAX, "400 puffs de uma vez: %d vivos (teto %d)" % [r.vivos(), Rastro.MAX])
	ok(r.pos.size() == Rastro.MAX and r.resta.size() == Rastro.MAX, "o pool não cresceu")
	var inteiros := true
	for i in Rastro.MAX:
		inteiros = inteiros and r.pos[i] == r.pos[i].round()
	ok(inteiros, "todas as posições são inteiras")
	ok(randi() == esperado, "emitir não consumiu o RNG")
	seed(semente)
	r.atualizar(Rastro.DUR * 0.5)
	ok(r.vivos() == Rastro.MAX, "na metade da vida seguem todos")
	r.atualizar(Rastro.DUR * 0.6)
	ok(r.vivos() == 0, "passada a vida, o pool zera (%d)" % r.vivos())


## Na E: os puffs nascem a ATRAS px do centro da imagem desenhada de algum míssil, em pixel inteiro; depois dos mísseis, a fumaça acaba sozinha.
func _em_voo() -> void:
	var ad = w.combate.adagas
	var idx := int(ad._proj_nomes["missil"])
	var novos := 0
	var fora := 0
	var vivos_max := 0
	for k in [0, 3, 6]:
		_zerar(Vector2.from_angle(float(k) * TAU / 8.0))
		ok(w.heroi.habilidade(), "mira %d: a E dispara" % k)
		var antes: int = ad.rastro.emitidos
		var voando := false
		for _q in 150:
			var e0: int = ad.rastro.emitidos
			var r0: PackedFloat32Array = ad.rastro.resta.duplicate()
			var q0: PackedVector2Array = ad.rastro.pos.duplicate()
			passos(1)
			vivos_max = maxi(vivos_max, ad.rastro.vivos())
			ok(ad.rastro.pos.size() == Rastro.MAX, "pool fixo durante a E")
			var ms: Array = []
			for i in ad.MAX:
				if ad.a_rest[i] > 0.0 and ad.a_proj[i] == idx and ad.a_visual_oculto[i] == 0:
					ms.append(i)
					voando = true
			if ad.rastro.emitidos == e0 or ms.is_empty():
				continue
			for j in Rastro.MAX:
				if ad.rastro.resta[j] < Rastro.DUR - 0.0001 or (r0[j] >= Rastro.DUR - 0.0001 and q0[j] == ad.rastro.pos[j]):  # só os que nasceram neste quadro (com dt 0, no hit-stop, os antigos seguem com DUR cheio)
					continue
				var p: Vector2 = ad.rastro.pos[j]
				var erro := 9999.0  # o puff é o bocal de ALGUM míssil: a ATRAS px do centro desenhado (outro míssil pode estar mais perto dele)
				for i in ms:
					erro = minf(erro, absf(p.distance_to((ad._pos_visual(i) as Vector2).round()) - Rastro.ATRAS))
				novos += 1
				if p != p.round() or erro > 1.6:
					fora += 1
		ok(voando, "mira %d: houve míssil em voo" % k)
		ok(ad.rastro.emitidos > antes, "mira %d: nasceram puffs (%d)" % [k, ad.rastro.emitidos - antes])
	ok(novos > 60, "mediu o lugar de muitos puffs recém-nascidos (%d)" % novos)
	ok(fora == 0, "todo puff nasce a %d px do centro desenhado de um míssil, em pixel inteiro (%d fora)" % [int(Rastro.ATRAS), fora])
	ok(vivos_max > 8 and vivos_max <= Rastro.MAX, "fumaça viva no pico: %d (teto %d)" % [vivos_max, Rastro.MAX])
	var k2 := 0
	while k2 < 600:
		var algum := false
		for i in ad.MAX:
			algum = algum or ad.a_rest[i] > 0.0
		if not algum:
			break
		passos(1)
		k2 += 1
	ok(k2 < 600, "os mísseis acabaram")
	passos(int(Rastro.DUR / PASSO) + 3)
	ok(ad.rastro.vivos() == 0, "sem míssil em voo a fumaça acaba em DUR (%d vivos)" % ad.rastro.vivos())


## Perfil Baixo: nenhum puff (só a chama); "poucas" e "nenhuma" valem. Depois volta ao normal.
func _baixo() -> void:
	var ad = w.combate.adagas
	for nivel in ["poucas", "nenhuma"]:
		w.args["particulas"] = nivel
		_zerar(Vector2.RIGHT)
		ok(w.heroi.habilidade(), "%s: a E dispara" % nivel)
		var voo := 0
		for _q in 100:
			passos(1)
			for i in ad.MAX:
				if ad.a_rest[i] > 0.0 and ad.a_proj[i] == int(ad._proj_nomes["missil"]):
					voo += 1
		ok(voo > 50, "%s: os mísseis voaram (%d)" % [nivel, voo])
		ok(ad.rastro.emitidos == 0 and ad.rastro.vivos() == 0, "%s: nenhum puff (nasceram %d)" % [nivel, ad.rastro.emitidos])
	w.args.erase("particulas")
	_zerar(Vector2.RIGHT)
	ok(w.heroi.habilidade(), "volta ao normal: a E dispara")
	passos(60)
	ok(ad.rastro.emitidos > 0, "no perfil normal a fumaça volta (%d)" % ad.rastro.emitidos)
