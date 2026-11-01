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
	ok(float(mz.arco) == 140.0 and float(mz.casca) == 40.0, "matriz: arco 140 graus, casca a 40 px")
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
	var perto_a = monstro_a(30.0)
	var longe = monstro_a(80.0)
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
	ok(longe.emp.length() < 5.0, "fora da casca (80 px): nada")
	ok(atras.emp.length() < 5.0, "atrás do herói (fora do arco): nada")
	ok(lado.emp.length() < 5.0, "a 90 graus da mira (fora do arco de 140): nada")
	passos(30)
	ok(perto_a.pos.x > antes_x, "o monstro da casca é afastado do herói (x %s para %s)" % [antes_x, perto_a.pos.x])
	for m in [perto_a, longe, atras, lado]:
		m.vivo = false

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
	ok(dmin > 25.0, "a horda de 8 cães à frente não chega ao corpo (distância mínima %.1f px)" % dmin)
	ok(h.vida == vida_h, "e não tira vida do herói em 4 s")
	for cao in horda:
		cao.vivo = false

	Herois.forcado = ""
	print("v2_matriz falhas=%d" % falhas)
	get_tree().quit()
