extends "res://testes/isolamento_v2.gd"
# Teste automático da MATRIZ DE DEFESA do LightWolf (LW-3: v2/matriz.gd, v2/escudo.gd, v2/heroi.gd, dados/v2_secundario.json > matriz): o secundário do mecha é a matriz (segurar),
# que usa a MESMA barra de defesa do escudo com os números dela por cima (100, gasta 5/s, retorno 35%, atraso 2 s, recarga 6/s); empurra os monstros da casca (m.emp para fora, sem
# tirar vida) dentro do arco de 140 graus; absorve 1 para 1 o dano que vem de dentro do arco e deixa vazar o que passa da barra; zerar a barra é a sobrecarga; a cura repõe a barra;
# no Difícil não recarrega sozinha; o Lobo não tem matriz; o herói publica os campos sec_* para o slot S. O mundo anda em passos fixos de 1/60 s.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_matriz.tscn  (imprime "v2_matriz falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const PASSO := 1.0 / 60.0
const ACHATA := 0.62
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func perto(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)
		w.combate.efeitos(PASSO)  # o visual da barreira também anda (desenha de verdade no mundo de teste)


## Começa de novo na dificuldade `dif`: mapa sem monstros, mecha parado e mortal, mirando para a direita, botão solto, barra cheia.
func zerar(dif := "facil") -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.meta_bonus["dificuldade"] = Dificuldade.regras(dif)
	var h = w.heroi
	h.imortal = false
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.correr_forcado = null
	h.ruptura_forcada = false
	h.escudo_forcado = false
	h.m_vel_mov = 1.0
	h.vida = h.vida_max
	h.def = h.def_max
	h.def_atraso_t = 0.0
	h.def_quebrado = false
	h.invenc = 0.0
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)
	h.def = h.def_max
	h.def_atraso_t = 0.0


func monstro_a(dx: float, dy := 0.0):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, dy))
	m.atordoa_t = 0.0
	m.vida = 5000.0
	m.vida_max = 5000.0
	m.emp = Vector2.ZERO
	m.recarga = 99.0  # não bate sozinho: o teste manda o dano
	return m


## Um ponto no chão a `graus` da mira (para a direita), `dist` px de distância (a conta do arco é no chão: y dividido pela achatada).
func ponto(graus: float, dist := 30.0) -> Vector2:
	var a := deg_to_rad(graus)
	return w.heroi.pos + Vector2(cos(a), sin(a) * ACHATA) * dist


## Um ponto no chão a `graus` da mira `u` (no chão, unitária), `dist` px de distância, de volta para a tela.
func ponto_u(u: Vector2, graus: float, dist: float) -> Vector2:
	var v := u.rotated(deg_to_rad(graus)) * dist
	return w.heroi.pos + Vector2(v.x, v.y * ACHATA)


## Até onde a matriz SEGURA o monstro `m` na direção `graus` da mira `u` (no chão): a maior distância, de `de` px para dentro em passos de 0,5 px, em que um quadro
## de `atualizar` o empurra (0 = em nenhuma). O monstro não anda: é a forma da parede, medida pela própria regra.
func alcance(m, u: Vector2, graus: float, de := 200.0) -> float:
	var mat = w.combate.matriz
	var d := de
	while d > 0.0:
		m.pos = ponto_u(u, graus, d)
		m.emp = Vector2.ZERO
		mat.atualizar(0.0)
		if mat.empurrados > 0:
			return d
		d -= 0.5
	return 0.0


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var h = w.heroi
	var esc = w.combate.escudo
	var mat = w.combate.matriz
	var d: Dictionary = Dados.json("v2_secundario")

	# 1. dados: quem tem a matriz e a barra única (a do escudo com os números dela por cima)
	ok(str(d.herois.lightwolf) == "matriz" and str(d.herois.lightwolf_lobo) == "nenhum", "o mecha tem a matriz; o Lobo, nada")
	ok(
		esc.matriz_para("lightwolf") and esc.posse_para("lightwolf") and not esc.ativo_para("lightwolf") and not esc.aparo_para("lightwolf"),
		"a matriz é por posse e não é escudo nem aparo"
	)
	ok(
		not esc.posse_para("lightwolf_lobo") and esc.posse_para("nicao") and not esc.posse_para("hazaki"),
		"posse: LightWolf e Nick sim, Lobo e Hazaki (aparo) não"
	)
	var bm: Dictionary = esc.barra_de("lightwolf")
	var be: Dictionary = esc.barra_de("nicao")
	ok(float(bm.max) == 100.0 and float(bm.gasto_s) == 5.0 and float(bm.atraso_recarga) == 2.0, "matriz: barra 100, gasto 5/s, atraso 2 s")
	ok(float(bm.regen_parado) == 6.0 and float(bm.regen_andando) == 6.0 and float(bm.retorno) == 0.35, "matriz: recarga 6/s e sobrecarga até 35%")
	ok(
		bm.reposicao == be.reposicao and float(bm.minimo) == float(be.minimo),
		"a reposição pela cura e o mínimo são os mesmos do escudo (um só bloco de números)"
	)
	ok(float(be.regen_parado) == 3.0 and float(be.atraso_recarga) == 2.5 and float(be.retorno) == 0.25, "a barra do escudo do Nick não mudou")
	ok(perto(esc.mov_de("lightwolf"), 0.75, 0.001) and perto(esc.mov_de("nicao"), float(d.escudo.mov), 0.001), "andar erguido: matriz 75%, escudo o dele")
	var mz: Dictionary = d.matriz
	ok(float(mz.arco) == 140.0 and float(mz.casca) == 88.0, "matriz: arco 140 graus, casca a 88 px (no pé da moldura da frente)")
	ok(float(mz.visual.pulso_hz) <= 2.0 and float(mz.visual.impacto_min) >= 0.5, "o brilho pulsa a no máximo 2 Hz e o clarão não passa de 2 por segundo")

	# 2. o herói nasce com a barra e publica o slot S
	zerar()
	ok(
		h.chave == "lightwolf" and h.def_max == 100.0 and h.def == 100.0 and not h.def_quebrado,
		"o mecha nasce com a barra cheia (%s de %s)" % [h.def, h.def_max]
	)
	ok(h.sec_nome == "MATRIZ" and h.sec_pronta and not h.sec_ativo and h.sec_barra == 1.0 and h.sec_recarga == 0.0, "sec_*: a matriz pronta, barra cheia")
	ok(Dados.icone_carta(str(esc.rotulo_de("lightwolf").icone)) != null, "o ícone de carta da matriz existe")
	ok(ResourceLoader.exists("res://assets/v2/secundario_s/lightwolf.png"), "o ícone próprio do slot S existe (A22 reduzida)")

	# 3. segurar: ergue, gasta 5/s, anda a 75%, não atira
	h.escudo_forcado = true
	passos(2)
	ok(h.escudo_ativo and mat.ativa(h) and h.sec_ativo and h.sec_pronta, "segurar ergue a matriz")
	var def0: float = h.def
	passos(60)
	ok(perto(def0 - h.def, 5.0, 0.15), "segurar gasta 5 por segundo (gastou %s)" % [def0 - h.def])
	ok(h.cansado == false and h.folego >= h.folego_max - 0.001, "a matriz não mexe no fôlego")
	var lancadas0: int = w.combate.adagas.lancadas
	h.ataque_forcado = true
	passos(30)
	h.ataque_forcado = false
	ok(w.combate.adagas.lancadas == lancadas0, "erguida, o mecha não atira")
	h.entrada_forcada = Vector2(1, 0)
	var x0: float = h.pos.x
	passos(30)
	var andou: float = h.pos.x - x0
	ok(
		perto(andou, h.vel_andar() * 0.75 * 0.5, h.vel_andar() * 0.04),
		"anda a 75%% da velocidade erguida (%s px em 0,5 s, esperado %s)" % [andou, h.vel_andar() * 0.375]
	)
	h.entrada_forcada = Vector2.ZERO
	h.escudo_forcado = false
	passos(3)
	ok(not h.escudo_ativo and not mat.ativa(h) and not h.sec_ativo, "soltar baixa a matriz")

	# 4. absorve 1 para 1 o dano de dentro do arco; vida intacta
	zerar()
	h.escudo_forcado = true
	passos(5)
	var abs0: float = mat.absorvido
	var vida0: float = h.vida
	var def1: float = h.def
	ok(h.levar_dano(14.0, ponto(0.0), null), "o golpe de 14 da frente é consumido")
	ok(h.vida == vida0 and perto(def1 - h.def, 14.0, 0.001), "absorveu 14 da barra, 1 para 1, sem tirar vida (%s de defesa)" % [def1 - h.def])
	ok(perto(mat.absorvido - abs0, 14.0, 0.001) and mat.golpes == 1 and mat.vazado == 0.0, "a matriz conta o absorvido (gancho das cartas de cura do LW-6)")
	ok(h.invenc <= 0.0, "absorver não dá invencibilidade nem recuo (como o escudo)")
	h.levar_dano(9.0, ponto(60.0), null)
	ok(h.vida == vida0 and perto(def1 - h.def, 23.0, 0.001), "dentro do arco (60 graus da mira): absorvido")
	# fora do arco (cobertura de 140: metade 70): entra na vida
	var def2: float = h.def
	h.invenc = 0.0
	h.levar_dano(8.0, ponto(80.0), null)
	ok(h.vida == vida0 - 8.0 and h.def == def2, "a 80 graus da mira (fora do arco): leva o dano na vida, a barra não gasta")
	h.invenc = 0.0
	h.levar_dano(5.0, ponto(180.0), null)
	ok(h.vida == vida0 - 13.0, "pelas costas: leva o dano")
	# dano de ambiente não é absorvido
	h.invenc = 0.0
	var vida_amb: float = h.vida
	var def3: float = h.def
	h.levar_dano(3.0, ponto(0.0), null, false)
	ok(h.vida == vida_amb - 3.0 and h.def == def3, "espinho do mapa (ambiente) passa pela matriz")

	# 5. vaza o que passa da barra e a sobrecarga derruba a matriz
	zerar()
	h.escudo_forcado = true
	passos(3)
	h.def = 5.0
	var vz0: float = mat.vazado
	var v1: float = h.vida
	ok(h.levar_dano(14.0, ponto(0.0), null), "golpe de 14 com 5 de barra: consumido")
	ok(
		perto(h.vida, v1 - 9.0, 0.001) and h.def == 0.0 and h.def_quebrado,
		"5 absorvidos, 9 vazaram para a vida e a barra zerou: sobrecarga (vida %s)" % [h.vida]
	)
	ok(perto(mat.vazado - vz0, 9.0, 0.001) and h.invenc > 0.0, "o que vaza conta como dano de verdade (invencibilidade)")
	passos(30)  # o hit-stop do golpe que vazou segura o mundo por um instante
	ok(
		not h.escudo_ativo and h.sec_recarga == 1.0 and not h.sec_pronta,
		"a barreira caiu e o slot mostra a recarga cheia (%s %s %s)" % [h.escudo_ativo, h.sec_recarga, h.sec_pronta]
	)
	passos(30)
	ok(not h.escudo_ativo, "sobrecarregada, segurar o botão não ergue a matriz de novo")

	# 6. recarga (Médio, 1,0): espera 2 s, depois 6/s até 35 e a sobrecarga acaba
	zerar("medio")
	h.escudo_forcado = true
	passos(3)
	h.def = 0.0
	h.def_quebrado = true
	h.def_atraso_t = 2.0
	h.escudo_forcado = false
	passos(60)
	ok(h.def == 0.0, "no atraso (2 s sem segurar) a barra não recarrega")
	var seg := 0.0
	for i in 900:
		passos(1)
		if not h.def_quebrado:
			seg = 1.0 + float(i + 1) / 60.0
			break
	ok(seg > 0.0 and perto(seg, 2.0 + 35.0 / 6.0, 0.4), "a sobrecarga acaba em 2 s + 35/6 s = 7,8 s (acabou em %s s)" % seg)
	ok(perto(h.def, 35.0, 1.0), "e a barra está em 35 (%s)" % h.def)
	h.escudo_forcado = true
	passos(3)
	ok(h.escudo_ativo, "passou do retorno: ergue de novo")

	# 7. Difícil: não recarrega sozinha; a cura repõe e conserta a sobrecarga
	zerar("dificil")
	h.def = 40.0
	h.def_atraso_t = 0.0
	passos(600)
	ok(h.def == 40.0, "Difícil: 10 s sem apanhar não mudam a barra (%s)" % h.def)
	h.def = 0.0
	h.def_quebrado = true
	h.repor_defesa_de("coracao")
	ok(perto(h.def, 35.0, 0.001) and not h.def_quebrado, "o coração do mapa repõe 35%% da barra e conserta a sobrecarga (%s)" % h.def)
	h.repor_defesa_de("carta_cura")
	ok(h.def == 100.0, "a carta Cura enche a barra da matriz")

	# 8. empurra a casca (sem tirar vida), só dentro do arco e só erguida
	zerar()
	var peso: float = monstro_a(0.0).peso
	for m in w.monstros.duplicate():
		if m != null and m.vivo:
			m.vivo = false
	zerar()
	var casca := float(mz.casca)
	var perto_a = monstro_a(30.0)
	var meio_a = monstro_a(70.0)  # longe do corpo, no meio do campo grande desenhado (a casca de antes, 40 px, não chegava aqui)
	var longe = monstro_a(casca + float(perto_a.raio) + 15.0)
	var atras = monstro_a(-30.0)
	var lado = monstro_a(0.0, 30.0)
	perto_a.recarga = 99.0
	passos(2)
	ok(perto_a.emp == Vector2.ZERO or perto_a.emp.length() < 5.0, "sem erguer, a matriz não empurra ninguém")
	h.escudo_forcado = true
	var vida_m: float = perto_a.vida
	var antes_x: float = perto_a.pos.x
	w.avancar(PASSO)
	ok(mat.empurrados >= 1 and perto_a.emp.x > 100.0, "erguida, quem está na casca e no arco leva empurrão para fora (emp %s, peso %s)" % [perto_a.emp, peso])
	ok(perto_a.vida == vida_m, "o empurrão não tira vida")
	ok(meio_a.emp.x > 100.0, "a 70 px (onde o campo está desenhado) também leva empurrão (emp %s)" % meio_a.emp)
	ok(longe.emp.length() < 5.0, "fora da casca (%.0f px): nada" % (casca + float(perto_a.raio) + 15.0))
	ok(atras.emp.length() < 5.0, "atrás do herói (fora do arco): nada")
	ok(lado.emp.length() < 5.0, "a 90 graus da mira (fora do arco de 140): nada")
	passos(30)
	ok(perto_a.pos.x > antes_x, "o monstro da casca é afastado do herói (x %s para %s)" % [antes_x, perto_a.pos.x])
	for m in [perto_a, meio_a, longe, atras, lado]:
		m.vivo = false

	# 8b. a PAREDE de frente: mirando para baixo (o campo largo na tela), na frente da moldura da frente o monstro para na distância da casca MEDIDA NA MIRA, rente
	# ao pé dela, e não no raio: num raio de 88 o monstro a 35 graus parava com o pé a ~72 px na mira, 12 px para dentro da moldura (atravessando o campo). Fora da
	# largura do campo, nas pontas do arco, vale o raio (a marca no chão). Até o #620 este caso mirava para a DIREITA, e o "para na mira" de lá era o defeito: de lado
	# a moldura da frente cobre só ~±6 px na vertical, e a parede-caixa segurava o cão a 35 graus parado no ar ~30 px fora da moldura e da marca no chão (abaixo).
	zerar()
	w.mouse_forcado = h.centro() + Vector2(0, 100)
	passos(3)
	var u_b: Vector2 = mat._mira_chao(h)
	var meia_f := float(mat._plano(h, mat._n() - 1).w)
	var diag = monstro_a(0.0)
	diag.pos = ponto_u(u_b, 35.0, 75.0)
	var ponta = monstro_a(0.0)
	ponta.pos = ponto_u(u_b, -66.0, 75.0)  # de lado além da largura do campo, ainda dentro do arco de 140
	h.escudo_forcado = true
	var fmin := 999.0
	var rmin_p := 999.0
	var lado_d := 0.0
	for i in 180:  # 3 s: os dois andam para o herói e o empurrão os segura
		passos(1)
		if i >= 90:
			var rd: Vector2 = diag.pos - h.pos
			var rdc := Vector2(rd.x, rd.y / ACHATA)
			fmin = minf(fmin, rdc.dot(u_b))  # a distância na mira, no chão
			lado_d = absf(rdc.cross(u_b))
			var rp: Vector2 = ponta.pos - h.pos
			rmin_p = minf(rmin_p, Vector2(rp.x, rp.y / ACHATA).length())
	print("parede: diagonal na mira %.1f px (lado %.1f, meia-largura %.0f); ponta no raio %.1f px" % [fmin, lado_d, meia_f, rmin_p])
	ok(lado_d <= meia_f + float(diag.raio), "o monstro da diagonal está na frente do campo (de lado %.1f, meia-largura %.0f)" % [lado_d, meia_f])
	ok(
		fmin >= float(mz.casca) - 4.0,
		"a 35 graus ele para rente ao pé da moldura da frente, na mira (%.1f px, o pé a %.0f): não atravessa o campo" % [fmin, float(mz.casca) - 4.0]
	)
	ok(
		rmin_p >= float(mz.casca) - 6.0 and rmin_p <= float(mz.casca) + float(ponta.raio) + 12.0,
		"na ponta do arco ele para no raio da casca (%.1f px)" % rmin_p
	)
	diag.vivo = false
	ponta.vivo = false
	# e mirando DE LADO (para a direita): o cão a 35 graus para rente à marca no chão (a frente dele a ~4 px do traço), não no ar fora da moldura e da marca
	zerar()
	var lado_c = monstro_a(0.0)
	lado_c.pos = ponto(35.0, 75.0)
	h.escudo_forcado = true
	var rmin_l := 999.0
	for i in 180:
		passos(1)
		if i >= 90:
			var rl: Vector2 = lado_c.pos - h.pos
			rmin_l = minf(rmin_l, Vector2(rl.x, rl.y / ACHATA).length())  # o mais perto que ele chega (o empurrão o devolve)
	var folga_l: float = rmin_l - float(lado_c.raio) - mat._raio()
	print("parede de lado: o cão a 35 graus para com a frente a %.1f px da marca no chão" % folga_l)
	ok(absf(folga_l) <= 6.0, "mirando de lado, o cão a 35 graus para rente à marca no chão (a frente dele a %.1f px dela), não parado no ar" % folga_l)
	lado_c.vivo = false

	# 8c. a FORMA da parede, medida pela própria regra (até onde um quadro de `atualizar` empurra, raio a raio de 0 grau até a ponta do arco, dos dois lados):
	# mirando para baixo, para a direita e na diagonal, com o arco do dado e com a MATRIZ AMPLA no máximo (300 graus). Ninguém é segurado a mais de casca + raio +
	# 30 px do herói (a caixa de antes, com a Ampla, segurava no canto a ~180 px, além dos 170 do canhão, e no FLANCO a ~154 px, a 89 graus) e a parede não tem
	# degrau de mais de 10 px de um grau para o outro (a caixa dava ~26 px no arco do dado e ~58 px com a Ampla, a 90 graus). Na mira ela continua na casca.
	zerar()
	h.escudo_forcado = true
	passos(3)
	var sonda = monstro_a(0.0)
	var teto_p := float(mz.casca) + float(sonda.raio) + 30.0
	var amp_antes: float = float(w.combate.armas.mods.get("ampla", 0.0))
	var pior_d := 0.0
	var pior_degrau := 0.0
	var na_mira_ok := true
	var onde := ""
	for ampla in [0.0, 999.0]:
		w.combate.armas.mods["ampla"] = ampla
		for alvo in [Vector2(0, 100), Vector2(100, 0), Vector2(100, 100)]:
			w.mouse_forcado = h.centro() + alvo
			passos(2)
			var u_c: Vector2 = mat._mira_chao(h)
			var meio_arco := int(floorf(mat.arco_graus() * 0.5)) - 1
			na_mira_ok = na_mira_ok and perto(alcance(sonda, u_c, 0.0), float(mz.casca) + float(sonda.raio), 1.0)
			for lado_s in [1.0, -1.0]:
				var ant := -1.0
				for g in meio_arco + 1:
					var dg := alcance(sonda, u_c, lado_s * float(g))
					if dg > pior_d:
						pior_d = dg
						onde = "arco %.0f, mira %s, %.0f graus" % [mat.arco_graus(), alvo, lado_s * g]
					if ant >= 0.0 and absf(dg - ant) > pior_degrau:
						pior_degrau = absf(dg - ant)
					ant = dg
	w.combate.armas.mods["ampla"] = amp_antes
	sonda.vivo = false
	print("forma da parede: o mais longe %.1f px (%s; teto %.0f), maior degrau %.1f px" % [pior_d, onde, teto_p, pior_degrau])
	ok(na_mira_ok, "na mira a parede segura na casca + raio (o pé da moldura da frente), com e sem a Ampla")
	ok(pior_d <= teto_p, "ninguém é segurado a mais de casca + raio + 30 px (%.1f px; %s)" % [pior_d, onde])
	ok(pior_degrau <= 10.0, "a parede não tem degrau de mais de 10 px de um grau para o outro (%.1f px)" % pior_degrau)

	# 9. o Lobo não tem matriz: a quebra do mecha apaga o slot e a barra
	zerar()
	h.vida = 10.0
	h.escudo_forcado = true
	passos(3)
	h.levar_dano(999.0, ponto(120.0), null)
	passos(30)
	ok(
		h.forma_lobo and h.def_max == 0.0 and not h.escudo_ativo and h.sec_nome == "",
		"o Lobo não tem matriz nem barra de defesa (%s %s %s '%s')" % [h.forma_lobo, h.def_max, h.escudo_ativo, h.sec_nome]
	)
	passos(30)
	ok(not h.escudo_ativo, "o Lobo segura o botão e nada se ergue")

	# 10. uma horda de 8 cães à frente (e o contato de verdade ligado): a barreira os segura na casca; a barra gasta pouco além do segurar
	zerar("medio")
	var horda: Array = []
	for i in 8:
		var cao = w.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(110.0 + 6.0 * i, -21.0 + 6.0 * i))
		cao.atordoa_t = 0.0
		cao.vida = 5000.0
		cao.vida_max = 5000.0
		cao.recarga = 0.0
		horda.append(cao)
	h.escudo_forcado = true
	var dmin := 999.0
	var vida_h: float = h.vida
	var abs_h: float = mat.absorvido
	for i in 240:  # 4 s
		passos(1)
		for cao in horda:
			var rel: Vector2 = cao.pos - h.pos
			if h.dir_olhar.dot(rel.normalized()) > 0.5:
				dmin = minf(dmin, Vector2(rel.x, rel.y / ACHATA).length())
	print("horda: dist min %.1f px, vida %.1f -> %.1f, absorvido %.1f, barra %.1f" % [dmin, vida_h, h.vida, mat.absorvido - abs_h, h.def])
	ok(
		dmin > 0.75 * float(mz.casca),
		"a horda de 8 cães à frente fica na casca, na frente do campo (distância mínima %.1f px; casca %.0f)" % [dmin, float(mz.casca)]
	)
	ok(
		h.def >= 75.0 and mat.absorvido - abs_h <= 5.0,
		"e a barra só gasta o segurar: 4 s x 5 = 20, de 100 para ~80 (%.1f, absorvido %.1f)" % [h.def, mat.absorvido - abs_h]
	)
	ok(h.vida == vida_h, "e não tira vida do herói em 4 s")
	# 10b. o CANHÃO contra a horda que a matriz segurou (a medida que faltava da casca de 88): baixa a matriz e atira 3 s nas posições em que os cães pararam
	# (espantalhos de vida enorme, presos lá), e de novo com a mesma horda puxada para a distância em que a casca antiga (40) a segurava (~35 px).
	var held: Array = []
	for cao in horda:
		var rel_c: Vector2 = cao.pos - h.pos
		if h.dir_olhar.dot(rel_c.normalized()) > 0.5:
			held.append(rel_c)
		cao.vivo = false
	held.sort_custom(func(a, b): return Vector2(a.x, a.y / ACHATA).length() < Vector2(b.x, b.y / ACHATA).length())
	var dps_nova := _dps_horda(held)
	var perto_h: Array = []
	for rel_c in held:
		perto_h.append(rel_c * (35.5 / maxf(dmin, 1.0)))
	var dps_antiga := _dps_horda(perto_h)
	print("canhão na horda segurada: %d alvos, dps %.1f a ~%.0f px (casca 88) contra %.1f a ~35 px (casca 40)" % [held.size(), dps_nova, dmin, dps_antiga])
	ok(
		held.size() >= 6 and dps_nova >= 40.0,
		"o canhão ainda rende na horda segurada mais longe (%.1f de dano por segundo em %d alvos)" % [dps_nova, held.size()]
	)

	# 11. perfil Baixo (partículas "poucas"): só a faixa parada e o som, sem clarão na faixa, luz rápida nem tremor de tela (item 7 do plano)
	zerar()
	w.args["particulas"] = "poucas"
	h.escudo_forcado = true
	passos(5)
	ok(mat._leve() and mat._pulso() == 1.0, "o perfil Baixo está ligado e o brilho não pulsa")
	w.cam.tremor_amp = 0.0
	var luzes0: int = w.combate.fx._li
	ok(h.levar_dano(14.0, ponto(0.0), null), "Baixo: o golpe é absorvido")
	passos(2)
	ok(mat._flash_t == 0.0 and mat.claroes == 0, "Baixo: sem clarão de absorção na faixa (%s)" % mat._flash_t)
	ok(w.cam.tremor_amp == 0.0, "Baixo: absorver não treme a tela (%s)" % w.cam.tremor_amp)
	ok(w.combate.fx._li == luzes0, "Baixo: absorver não acende luz rápida")
	h.def_quebrado = true
	mat.abaixou(h)
	ok(w.cam.tremor_amp == 0.0 and w.combate.fx._li == luzes0, "Baixo: a sobrecarga também não treme nem acende luz")
	# o mesmo golpe no perfil normal liga o clarão, a luz e o tremor (o teste acima falharia se o perfil não fosse lido)
	w.args.erase("particulas")
	zerar()
	h.escudo_forcado = true
	passos(5)
	w.cam.tremor_amp = 0.0
	luzes0 = w.combate.fx._li
	ok(not mat._leve(), "perfil normal: não é o Baixo")
	h.levar_dano(14.0, ponto(0.0), null)
	ok(mat._flash_t > 0.0 and mat.claroes == 1 and w.combate.fx._li == (luzes0 + 1) % 3, "perfil normal: o golpe absorvido dá clarão e uma luz rápida")
	ok(w.cam.tremor_amp > 0.0, "perfil normal: e um tremor curto (%s)" % w.cam.tremor_amp)

	# 12. no máximo 2 clarões por segundo (impacto_min 0,5 s) mesmo com golpes a cada 0,1 s, e o pulso nunca passa de 2 Hz mesmo que o dado peça mais
	zerar()
	h.escudo_forcado = true
	passos(5)
	passos(40)  # deixa o clarão do teste anterior acabar
	var relogio0: float = mat._relogio
	for i in 20:  # golpes a cada 0,1 s
		h.levar_dano(1.0, ponto(0.0), null)
		passos(6)
	var n_claroes: int = mat.claroes
	var dur: float = mat._relogio - relogio0  # o relógio de parede do visual (o mundo de teste também roda `efeitos` em `avancar`, então corre mais que os passos)
	ok(
		n_claroes >= 2 and float(n_claroes) <= dur / 0.5 + 1.0,
		"20 golpes em %.1f s de relógio dão no máximo 1 clarão a cada 0,5 s (%d, e mais de 1)" % [dur, n_claroes]
	)
	ok(mat.golpes >= 20, "e todos foram absorvidos (%d)" % mat.golpes)
	var hz0 = mat.visual.get("pulso_hz")
	mat.visual["pulso_hz"] = 9.0
	ok(mat._hz() == 2.0, "um dado de 9 Hz é limitado a 2 Hz (%s)" % mat._hz())
	var troca := 0  # quantas vezes o brilho cruza o meio da faixa em 1 s de relógio de parede: 2 por ciclo, então 4 (até 5 contando a borda)
	var ant: float = mat._pulso() - 0.84
	for i in 600:
		mat._relogio += 1.0 / 600.0
		var cur: float = mat._pulso() - 0.84
		if (cur >= 0.0) != (ant >= 0.0):
			troca += 1
		ant = cur
	ok(troca <= 5, "o brilho cruza o meio no máximo 4 vezes (5 com a borda) em 1 s, ou seja 2 Hz (%d)" % troca)
	mat.visual["pulso_hz"] = hz0

	Herois.forcado = ""
	print("v2_matriz falhas=%d" % falhas)
	get_tree().quit()


## O dano por segundo do canhão em 3 s de tiro contra espantalhos de vida enorme presos nas posições `alvos` (relativas aos pés), a matriz baixada, mirando no 1º
## (como `_segurar` de testes/v2_lightwolf: o mouse onde a linha da boca ao peito do alvo aponta).
func _dps_horda(alvos: Array) -> float:
	zerar("medio")
	var h = w.heroi
	var ms := []
	for a in alvos:
		var m = w.nascer_monstro("inimigo_espantalho", h.pos + a)
		m.vida = 100000.0
		m.vida_max = 100000.0
		ms.append(m)
	w.mouse_forcado = h.centro() + (alvos[0] + Vector2(0, -6) - Heroi.ORIGEM_GOLPE)
	var dano0: float = w.combate.dano_causado
	h.ataque_forcado = true
	for i in 180:
		w.avancar(PASSO)
		for k in ms.size():
			ms[k].atordoa_t = 0.0
			ms[k].pos = h.pos + alvos[k]
	h.ataque_forcado = false
	passos(40)  # as últimas bolinhas ainda estão a caminho
	var dps: float = (w.combate.dano_causado - dano0) * 60.0 / 180.0
	for m in ms:
		m.vivo = false
	return dps
