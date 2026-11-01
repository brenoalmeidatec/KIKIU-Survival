extends "res://testes/isolamento_v2.gd"
# Teste automático da E MÍSSEIS do LightWolf (LW-4: v2/habilidade.gd, v2/adagas.gd, v2/hud_habilidades.gd, dados/v2_habilidade.json > misseis): o mecha tem a E, o Lobo não; o aperto
# solta 12 micro-mísseis em 0,9 s sem ficar invulnerável e andando a 50%; cada míssil escolhe ao sair o monstro mais perto no cone de 50 graus (no máximo 2 por alvo enquanto houver outro),
# gira até 3,2 rad/s para ele, fere (11) e explode em área pequena (raio 26); quem está fora do cone não é buscado; sem alvo ou com o alvo morto segue reto e acaba no alcance; o pool de
# projéteis nunca passa de 17 em voo com a E e não cria nó; as cartas da E (dano, recarga) valem; o HUD mostra o ícone A19. O mundo anda em passos fixos de 1/60 s.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_misseis.tscn  (imprime "v2_misseis falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const HudHabilidades := preload("res://v2/hud_habilidades.gd")
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


## Mapa sem monstros, mecha parado e mortal, mirando para a direita (mouse), E pronta, sem crítico (o dano fica previsível).
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = false
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.correr_forcado = null
	h.ruptura_forcada = false
	h.escudo_forcado = false
	h.m_critico = -1.0
	h.m_dano = 1.0
	h.m_area = 1.0
	h.vida = h.vida_max
	h.invenc = 0.0
	h.fonte = Heroi.Fonte.MOUSE
	w.combate.ruptura.somas.dano = 0
	w.combate.ruptura.somas.recarga = 0
	w.combate.ruptura.somas.atordoa = 0
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)
	h.hab_recarga = 0.0
	h.hab_nega_t = 0.0
	h.esp_carga = 0.0


## Um monstro parado (atordoado por muito tempo) e com muita vida, a (dx, dy) do herói.
func monstro_a(dx: float, dy := 0.0, vida := 5000.0):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, dy))
	m.atordoa_t = 60.0
	m.vida = vida
	m.vida_max = vida
	m.emp = Vector2.ZERO
	m.recarga = 99.0
	return m


func perdeu(m) -> float:
	return m.vida_max - m.vida


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	_dados()
	_disparo()
	_andar()
	_busca()
	_cone()
	_reto()
	_cartas()
	_hud()
	Herois.forcado = ""
	print("v2_misseis falhas=%d" % falhas)
	get_tree().quit()


func _dados() -> void:
	var d: Dictionary = Dados.json("v2_habilidade")
	ok(d.herois.get("lightwolf") == "misseis" and d.herois.get("lightwolf_lobo") == "nenhuma", "o mecha tem os Mísseis; o Lobo, nenhuma E")
	var b: Dictionary = d.get("misseis", {})
	ok(b.has("nome") and b.has("rotulo") and b.has("desc") and b.has("cor") and b.has("icone"), "bloco misseis completo")
	ok(str(b.rotulo).length() <= 10 and Dados.icone_carta(str(b.icone)) != null, "o rótulo cabe no slot e o ícone de carta existe (%s)" % b.get("icone", ""))
	ok(float(b.recarga) == 9.0 and int(b.n) == 12 and float(b.dur) == 0.9, "números do plano: recarga 9 s, 12 mísseis em 0,9 s")
	ok(float(b.mov) == 0.5 and not bool(b.invul), "anda a 50% e NÃO é invulnerável")
	ok(
		float(b.cone) == 50.0 and float(b.giro) == 3.2 and float(b.dano) == 11.0 and float(b.expl_raio) == 26.0,
		"cone 50 graus, giro 3,2 rad/s, dano 11, explosão de raio 26"
	)
	var ad = w.combate.adagas
	ok(ad._proj_nomes.has("missil") and int(ad._proj_nomes["missil"]) > 0, "o pool tem a imagem `missil` (a mesma tabela de projéteis)")
	ok(ad._proj_lista[int(ad._proj_nomes["missil"])].has("tex"), "o míssil é desenhado em código (sem folha nova)")


## O aperto: 12 mísseis em 0,9 s, vulnerável, recarga armada, nada de nó novo no pool, no máximo 17 em voo.
func _disparo() -> void:
	zerar()
	var h = w.heroi
	var hab = w.combate.habilidade
	var ad = w.combate.adagas
	ok(h.hab_id == "misseis" and h.hab_nome == "Mísseis" and h.hab_recarga == 0.0, "o mecha nasce com a E Mísseis pronta (%s)" % h.hab_id)
	var alvo = monstro_a(150, 30)
	var nos0: int = w.get_child_count()
	var lancadas0: int = ad.lancadas
	ok(h.habilidade() and h.estado == Heroi.Estado.HABILIDADE, "o aperto dispara a E")
	ok(not h.hab_invul and h.vulneravel(), "durante os Mísseis o mecha NÃO é invulnerável")
	ok(absf(h.hab_recarga - 9.0) < 0.01 and absf(h.hab_recarga_max - 9.0) < 0.01, "a recarga cheia (9 s) fica armada (%s)" % h.hab_recarga)
	ok(not h.habilidade(), "não dispara de novo durante a E")
	var maximo := 0
	var n := 0
	var vida0: float = h.vida
	while h.estado == Heroi.Estado.HABILIDADE and n < 200:
		passos(1)
		n += 1
		maximo = maxi(maximo, ad.ativas())
		if n == 20:
			ok(ad.lancadas - lancadas0 >= 3 and ad.lancadas - lancadas0 <= 5, "a ~0,33 s saíram ~4 mísseis (um a cada 75 ms): %d" % (ad.lancadas - lancadas0))
	ok(absf(float(n) * PASSO - 0.9) < 0.1, "a E dura ~0,9 s (durou %s)" % (float(n) * PASSO))
	ok(ad.lancadas - lancadas0 == 12, "saíram 12 mísseis (%d)" % (ad.lancadas - lancadas0))
	ok(maximo <= 17, "no máximo 17 projéteis em voo no pior caso (%d)" % maximo)
	ok(h.estado == Heroi.Estado.LIVRE and not h.hab_invul, "acabou: livre")
	ok(hab.disparos == 1 and hab.ultimo.get("id") == "misseis", "a E conta o disparo (%s)" % str(hab.ultimo))
	ok(w.get_child_count() == nos0, "nenhum nó novo na cena (pool)")
	ok(h.vida == vida0, "ninguém feriu o mecha (recarga dos monstros 99)")
	passos(120)
	ok(perdeu(alvo) >= 11.0 * 6.0, "o alvo no cone levou vários mísseis (%s de dano)" % perdeu(alvo))
	ok(float(w.combate.dano_por_fonte.get("habilidade", 0.0)) > 0.0, "o dano conta na fonte `habilidade` da tela de fim")
	ok(h.habilidade() == false and h.hab_negados >= 1, "na recarga o aperto é negado")
	h.hab_recarga = 0.0
	ok(h.habilidade(), "zerou a recarga: dispara de novo")
	passos(70)


## Anda a 50% durante a E (a direção é a do teclado; a mira não muda).
func _andar() -> void:
	zerar()
	var h = w.heroi
	h.m_vel_mov = 1.0
	h.entrada_forcada = Vector2(0, 1)
	passos(30)
	var p0: Vector2 = h.pos
	passos(30)
	var normal: float = (h.pos - p0).length()
	h.entrada_forcada = Vector2.ZERO
	passos(5)
	h.entrada_forcada = Vector2(0, 1)
	ok(h.habilidade(), "dispara andando")
	var mira0: Vector2 = h.dir_olhar
	passos(2)
	p0 = h.pos
	passos(30)
	var com_e: float = (h.pos - p0).length()
	ok(normal > 10.0 and absf(com_e / normal - 0.5) < 0.08, "anda a 50%% durante a E (normal %s, com a E %s)" % [normal, com_e])
	ok(h.dir_olhar.is_equal_approx(mira0), "a mira fica travada no disparo")
	ok(h.estado == Heroi.Estado.HABILIDADE and not h.hab_invul, "ainda na E, vulnerável")
	h.entrada_forcada = Vector2.ZERO
	passos(60)


## A busca: um alvo fora do eixo (dentro do cone) é buscado e acertado; a explosão fere o vizinho que não estava no caminho.
func _busca() -> void:
	zerar()
	var h = w.heroi
	var ad = w.combate.adagas
	var alvo = monstro_a(190, 80)  # ~23 graus da mira, dentro do cone de 50
	var vizinho = monstro_a(190 + 18, 80 + 10)  # perto o bastante para a explosão (26 + raio), atrás do alvo
	var acertos0: int = ad.acertos
	ok(h.habilidade(), "dispara com alvo fora do eixo")
	passos(150)
	ok(perdeu(alvo) >= 11.0 * 3.0, "os mísseis curvam até o alvo fora do eixo (%s de dano)" % perdeu(alvo))
	ok(perdeu(vizinho) > 0.0, "a explosão pequena fere o vizinho (%s)" % perdeu(vizinho))
	ok(w.combate.armas.acertos.get("missil", 0) > 0, "a explosão passa pelo dano em área das armas (acertos `missil`)")
	ok(ad.acertos - acertos0 >= 6, "vários mísseis acertaram (%d)" % (ad.acertos - acertos0))
	# no máximo 2 por alvo enquanto houver outro no cone: 6 mísseis, 3 alvos -> 2 em cada
	zerar()
	var a1 = monstro_a(140, -40)
	var a2 = monstro_a(190, 10)
	var a3 = monstro_a(240, 60)
	var b: Dictionary = w.combate.habilidade.bloco_de("lightwolf")
	var passo := {
		"n": 1,
		"leque": 0.0,
		"dano": 1.0,
		"vel": float(b.vel),
		"alcance": float(b.alcance),
		"perfura": 0,
		"empurrao": 0.0,
		"atordoa": 0.0,
		"cor": [1.0, 1.0, 1.0],
		"proj": "missil",
		"giro": float(b.giro),
		"cone": float(b.cone),
		"cone_dir": Vector2.RIGHT,
		"por_alvo": int(b.por_alvo),
	}
	for i in 6:
		ad.lancar(h, h.pos + Heroi.ORIGEM_GOLPE, Vector2.RIGHT, passo)
	var por := {a1: 0, a2: 0, a3: 0}
	for i in ad.MAX:
		if ad.a_rest[i] > 0.0 and ad.a_alvo[i] != null:
			por[ad.a_alvo[i]] = int(por.get(ad.a_alvo[i], 0)) + 1
	ok(por[a1] == 2 and por[a2] == 2 and por[a3] == 2, "6 mísseis espalham 2 por alvo (%d, %d, %d)" % [por[a1], por[a2], por[a3]])
	for i in ad.MAX:
		ad.a_rest[i] = 0.0


## Quem está fora do cone (60 graus, atrás, longe demais) não é buscado.
func _cone() -> void:
	zerar()
	var h = w.heroi
	var ad = w.combate.adagas
	var fora = monstro_a(100, 175)  # ~60 graus
	var atras = monstro_a(-120, 0)
	var longe = monstro_a(420, 0)  # além do alcance de busca (320)
	ok(h.habilidade(), "dispara com todos fora do cone")
	var buscando := 0
	for i in 20:
		passos(3)
		for j in ad.MAX:
			if ad.a_rest[j] > 0.0 and ad.a_alvo[j] != null:
				buscando += 1
	ok(buscando == 0, "nenhum míssil busca quem está fora do cone ou longe (%d)" % buscando)
	passos(200)
	ok(perdeu(fora) == 0.0 and perdeu(atras) == 0.0 and perdeu(longe) == 0.0, "e ninguém fora do cone é ferido")


## Sem alvo: segue reto e acaba no alcance. Alvo que morre no caminho: não quebra, os outros mísseis seguem.
func _reto() -> void:
	zerar()
	var h = w.heroi
	var ad = w.combate.adagas
	ok(h.habilidade(), "dispara sem ninguém")
	passos(70)
	ok(ad.ativas() > 0, "os mísseis voam sem alvo")
	passos(120)
	ok(ad.ativas() == 0, "e acabam no alcance (%d em voo)" % ad.ativas())
	zerar()
	var alvo = monstro_a(220, 20, 30.0)
	ok(h.habilidade(), "dispara no alvo frágil")
	passos(200)
	ok(not alvo.vivo or alvo.morrendo or alvo.vida <= 0.0, "o alvo frágil morre")
	passos(100)
	ok(ad.ativas() == 0, "depois da morte do alvo nenhum míssil fica preso no ar (%d)" % ad.ativas())


## As cartas da E valem: dano multiplica e recarga encurta (piso 4 s).
func _cartas() -> void:
	zerar()
	var h = w.heroi
	var ad = w.combate.adagas
	w.combate.ruptura.somas.dano = 100
	w.combate.ruptura.somas.recarga = 50
	var alvo = monstro_a(150, 0)
	ok(h.habilidade(), "dispara com as cartas")
	ok(h.hab_recarga_max < 9.0 and h.hab_recarga_max >= 4.0, "Pulso ligeiro encurta a recarga (%s)" % h.hab_recarga_max)
	passos(8)
	var maior := 0.0
	for j in ad.MAX:
		if ad.a_rest[j] > 0.0:
			maior = maxf(maior, ad.a_dano[j])
	ok(absf(maior - 22.0) < 0.5, "Punho de terra dobra o dano do míssil (%s)" % maior)
	passos(160)
	ok(perdeu(alvo) > 0.0, "e o alvo apanha")
	w.combate.ruptura.somas.dano = 0
	w.combate.ruptura.somas.recarga = 0


## O slot E do HUD mostra a arte A19 reduzida (32x32) e o rótulo.
func _hud() -> void:
	zerar()
	var h = w.heroi
	var slots = HudHabilidades.new()
	slots.sincronizar(h)
	ok(slots.e_disponivel and slots.e_pronta, "HUD: o slot E acende com a E pronta")
	var arte: Texture2D = slots.arte_e()
	ok(arte != null and arte.resource_path == "res://assets/v2/habilidade_e/lightwolf.png", "HUD: usa a arte própria A19 do LightWolf")
	ok(arte != null and arte.get_size() == Vector2(32, 32), "HUD: a arte tem 32x32")
	ok(slots._rotulo_e() == "MÍSSEIS", "HUD: o rótulo é MÍSSEIS (%s)" % slots._rotulo_e())
	slots.free()
