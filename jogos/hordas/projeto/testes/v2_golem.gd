extends Node
## O Golem de Barro da v2 (v2/golem.gd, ligado em v2/armas_novas.gd): a folha 3D confere com as constantes do código, a vista sai da direção
## (5 linhas, com histerese), o passo anda com a distância andada, o ciclo surgir -> andar -> atacar -> andar -> desmoronar acontece de verdade,
## parado durante o golpe, e o dano cai UMA vez por pancada, no quadro do impacto (não no começo do ataque). Nenhum nó novo na camada de desenho.
## Também: a passada da arte bate com o ciclo do código (pé não escorrega), a pancada em área pega 3 alvos, o Colosso (escala 1,3) segue o tique da carta e sem a folha vale o caminho antigo.
## Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_golem.tscn  (imprime "v2_golem falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Golem := preload("res://v2/golem.gd")
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


## A folha e o .json do gerador (fonte_arte/blender_golem/gerar_golem.py) batem com as constantes: regerar a arte com outro tamanho de quadro não desalinha em silêncio.
func checar_folha() -> void:
	var t := Golem.tex()
	ok(t != null, "golem: a folha carrega")
	if t == null:
		return
	var colunas := Golem.COL_ANDAR + Golem.COL_ATAQUE
	var esperado := Vector2(Golem.QUADRO.x * colunas, Golem.QUADRO.y * Golem.LINHAS)
	ok(
		t.get_size() == esperado,
		"golem: a folha tem %d x %d quadros de %s (esperado %s, tem %s)" % [colunas, Golem.LINHAS, Golem.QUADRO, esperado, t.get_size()]
	)
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v2/armas/golem_barro_dir.json"))
	ok(d is Dictionary, "golem: o .json da folha lê")
	if d is Dictionary:
		ok(Vector2(float(d.quadro[0]), float(d.quadro[1])) == Golem.QUADRO, "golem: o quadro do .json é o do código")
		ok(Vector2(float(d.pe_x), float(d.pe_y)) == Golem.PE, "golem: o pé do .json é o do código")
		ok(int(d.andar) == Golem.COL_ANDAR and int(d.ataque) == Golem.COL_ATAQUE, "golem: as colunas de andar e ataque do .json são as do código")
		ok(int(d.impacto) == Golem.QUADRO_IMPACTO and d.linhas.size() == Golem.LINHAS, "golem: o quadro do impacto e as linhas do .json são os do código")


func checar_funcoes() -> void:
	ok(Golem.linha_de(Vector2(0, 1), 0) == 0, "descendo: frente")
	ok(
		Golem.linha_de(Vector2(1, 1).normalized(), 0) == 1 and Golem.linha_de(Vector2(-1, 1).normalized(), 0) == 1,
		"diagonal para baixo: 3/4 frente (os dois lados)"
	)
	ok(Golem.linha_de(Vector2(1, 0), 0) == 2 and Golem.linha_de(Vector2(-1, 0), 0) == 2, "de lado: perfil (os dois lados)")
	ok(Golem.linha_de(Vector2(1, -1).normalized(), 0) == 3 and Golem.linha_de(Vector2(-1, -1).normalized(), 0) == 3, "diagonal para cima: 3/4 costas")
	ok(Golem.linha_de(Vector2(0, -1), 0) == 4, "subindo: costas")
	# histerese: 68 graus fica na fronteira entre 3/4 (45) e perfil (90); mantém a vista que já estava
	var v := Vector2(sin(deg_to_rad(68.0)), cos(deg_to_rad(68.0)))
	ok(Golem.linha_de(v, 1) == 1 and Golem.linha_de(v, 2) == 2, "histerese: perto da fronteira fica na vista que já estava")
	ok(
		absf(Golem.tempo_impacto() - 0.35) < 0.001 and Golem.tempo_ataque() > Golem.tempo_impacto() + 0.3,
		"tempos do ataque: impacto em 0,35 s e a volta depois"
	)
	ok(
		Golem.quadro_ataque(0.0) == 0 and Golem.quadro_ataque(Golem.tempo_impacto() - 0.001) == Golem.QUADRO_IMPACTO - 1,
		"o quadro antes do impacto é o anterior ao da pancada"
	)
	ok(
		Golem.quadro_ataque(Golem.tempo_impacto() + 0.001) == Golem.QUADRO_IMPACTO and Golem.quadro_ataque(99.0) == Golem.COL_ATAQUE - 1,
		"a pancada começa no quadro do impacto e a volta termina no último"
	)
	ok(
		Golem.quadro_andar(0.0) == 0 and Golem.quadro_andar(0.5) == 4 and Golem.quadro_andar(1.0) == 0 and Golem.quadro_andar(-0.1) == 7,
		"o ciclo de andar dá a volta (8 quadros)"
	)
	# entulho: o torrão cai, quica menos e FICA no chão parado; some quando o tempo acaba; as rachaduras também
	var ent := {"deb": PackedFloat32Array(), "rt": 0.5}
	Golem._deb_add(ent, Vector2(5, 5), 10.0, Vector2(20, 0), 100.0, 1.4, 4.0, 0.0, 0.5)
	for i in 45:  # 0,75 s: já aterrissou
		Golem._entulho(ent, PASSO)
	var peca: PackedFloat32Array = ent.deb
	ok(
		peca.size() == Golem.T_DEB and peca[2] == 0.0 and peca[3] == 0.0 and peca[6] > 0.0,
		"o torrão cai e fica parado no chão (z %.1f, vx %.1f)" % [peca[2], peca[3]]
	)
	for i in 150:  # +2,5 s
		Golem._entulho(ent, PASSO)
	ok((ent.deb as PackedFloat32Array).is_empty() and float(ent.rt) < 0.0, "o entulho e as rachaduras somem com o tempo")
	var cheio := {"deb": PackedFloat32Array(), "rt": -1.0}
	for i in Golem.MAX_DEB * 2:
		Golem._deb_add(cheio, Vector2.ZERO, 5.0, Vector2.ZERO, 50.0, 1.0, 4.0, 0.0, 0.0)
	ok((cheio.deb as PackedFloat32Array).size() == Golem.MAX_DEB * Golem.T_DEB, "o entulho tem teto por golem (%d)" % Golem.MAX_DEB)
	ok(Golem.eh_golem("golem_barro") and Golem.eh_golem("colosso_de_pedra") and not Golem.eh_golem("lobo_espirito"), "quem é golem")


## Separação (px) dos dois pés na vista de perfil no quadro PARADO, medida no png: o pé de apoio anda essa distância por passo
## (-1 se não achar dois pés). O corpo anda CICLO_PX por ciclo = 2 passos; se a arte e o código discordam, o pé escorrega.
func separacao_pes() -> float:
	var img := Image.load_from_file(ProjectSettings.globalize_path(Golem.FOLHA))
	if img == null:
		return -1.0
	var qw := int(Golem.QUADRO.x)
	var qh := int(Golem.QUADRO.y)
	var ox := Golem.PARADO * qw
	var oy := 2 * qh  # linha 2 = perfil
	var base := -1
	for y in range(qh - 1, -1, -1):
		for x in qw:
			if img.get_pixel(ox + x, oy + y).a > 0.5:
				base = y
				break
		if base >= 0:
			break
	if base < 0:
		return -1.0
	var grupos: Array = []
	for x in qw:
		var tem := false
		for y in range(base - 5, base + 1):
			if img.get_pixel(ox + x, oy + y).a > 0.5:
				tem = true
				break
		if not tem:
			continue
		if not grupos.is_empty() and x - (grupos[-1][-1] as int) <= 2:
			grupos[-1].append(x)
		else:
			grupos.append([x])
	if grupos.size() != 2:
		return -1.0
	var c: Array = []
	for g in grupos:
		var soma := 0.0
		for x in g:
			soma += x
		c.append(soma / g.size())
	return absf(float(c[1]) - float(c[0]))


func checar_passada() -> void:
	var sep := separacao_pes()
	ok(sep > 8.0, "arte: dois pés separados no perfil, quadro parado (%.1f px, medida grosseira: pontas dos pés)" % sep)
	# a passada de verdade vem do gerador, que mede NOS PIXELS o pé de apoio (renderizado sozinho, quadros 2 a 6) em cada vista: o código tem de andar o mesmo, senão o pé escorrega
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/v2/armas/golem_barro_dir.json"))
	ok(d is Dictionary and d.has("ciclo_linha") and d.has("pe_apoio") and d.has("deslize_px"), "o .json traz a passada medida pelo gerador, por vista")
	if not (d is Dictionary and d.has("ciclo_linha") and d.has("pe_apoio") and d.has("deslize_px")):
		return
	ok(d.ciclo_linha.size() == Golem.LINHAS and Golem.CICLO_LINHA.size() == Golem.LINHAS, "passada: um ciclo por vista (%d)" % Golem.LINHAS)
	for v in Golem.LINHAS:
		var arte := float(d.ciclo_linha[v])
		ok(
			absf(arte - float(Golem.CICLO_LINHA[v])) <= 0.6,
			"vista %d: o ciclo do código (%.1f px) é a passada da arte (%.1f px): o pé não escorrega" % [v, Golem.CICLO_LINHA[v], arte]
		)
		# o pé de apoio anda em reta e a passos iguais entre os quadros 2 e 6 (na folha, em px): sem solavanco, sem recuar
		var pts: Array = d.pe_apoio[v]
		var total := Vector2(float(pts[4][0]) - float(pts[0][0]), float(pts[4][1]) - float(pts[0][1]))
		ok(absf(2.0 * total.length() - arte) <= 0.6, "vista %d: o ciclo gravado é 2 x o deslocamento do pé de apoio (%.1f px)" % [v, 2.0 * total.length()])
		var passo_medio := total / 4.0
		var desvio := 0.0
		for k in 4:
			var passo := Vector2(float(pts[k + 1][0]) - float(pts[k][0]), float(pts[k + 1][1]) - float(pts[k][1]))
			desvio = maxf(desvio, passo.distance_to(passo_medio))
		ok(desvio <= 2.0, "vista %d: o pé de apoio anda a passos iguais (desvio %.1f px)" % [v, desvio])
		ok(float(d.deslize_px[v]) <= 2.5, "vista %d: o pé de apoio não sai da reta (%.1f px)" % [v, float(d.deslize_px[v])])
	# o pé de apoio anda para trás: de perfil (olhando para a direita) vai para a esquerda; de frente sobe na tela, de costas desce
	ok(float(d.pe_apoio[2][4][0]) < float(d.pe_apoio[2][0][0]) - 20.0, "perfil: o pé de apoio corre para trás (esquerda)")
	ok(float(d.pe_apoio[0][4][1]) < float(d.pe_apoio[0][0][1]) - 12.0, "de frente: o pé de apoio sobe na tela")
	ok(float(d.pe_apoio[4][4][1]) > float(d.pe_apoio[4][0][1]) + 12.0, "de costas: o pé de apoio desce na tela")
	# passada larga: pelo menos 24 px entre os pés no apoio duplo, de perfil (a anterior tinha 20)
	ok(float(Golem.CICLO_LINHA[2]) * 0.5 >= 24.0, "passada larga: %.1f px entre os pés no apoio duplo" % (float(Golem.CICLO_LINHA[2]) * 0.5))
	ok(
		float(Golem.CICLO_LINHA[0]) < float(Golem.CICLO_LINHA[1]) and float(Golem.CICLO_LINHA[1]) < float(Golem.CICLO_LINHA[2]),
		"a câmera encurta a passada de frente e nas diagonais"
	)
	ok(Golem.EMPURRA <= 30.0 and Golem.ATORDOA <= 0.05, "a pancada não empurra nem atordoa mais por alvo que o golpe antigo (30, 0,05 s)")


func preparar_mundo() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	passos(3)


## Golem de Barro ou Colosso (evoluido) contra 3 alvos juntos: a pancada pega todos de uma vez, uma vez por ataque, e o ciclo segue o "tique" da carta.
func checar_area(id: String, evoluido: bool) -> void:
	preparar_mundo()
	var tique := 0.0
	if evoluido:
		for ev in w.combate.cartas.cfg.evolucoes:
			if str(ev.id) == id:
				w.combate.armas.adicionar_evoluida(ev, 0.0)
				tique = float(ev.arma.tique)
	else:
		w.combate.armas.definir_golpe(id, 1, 0.0)
		tique = float(w.combate.armas.ativas[id].st.tique)
	ok(tique > 0.0, "%s: achou o tique nos dados" % id)
	var alvos := [monstro_a(150.0, 0.0), monstro_a(150.0, 10.0), monstro_a(150.0, -10.0)]
	var it = null
	for i in 600:
		passos(1)
		it = golem_ativo()
		if it != null:
			break
	ok(it != null and str(it.a.id) == id, "%s: nasce como golem" % id)
	if it == null:
		return
	segurar_recarga(id)
	ok(is_equal_approx(Golem.escala(id), 1.3 if evoluido else 1.0), "%s: escala do golem" % id)
	var vidas: Array = []
	for m in alvos:
		vidas.append(float(m.vida))
	var instantes: Array = []
	var area_ok := true
	var juntou := false
	var esc_a := Golem.escala(id)
	var imp_ant := false
	var t := 0.0
	for i in 60 * 7:
		passos(1)
		t += PASSO
		if float(it.vida) <= 0.0:
			break
		if int(it.e) == Golem.ATACANDO and not bool(it.imp) and float(it.et) >= Golem.tempo_impacto() - 0.05 and not juntou:
			# a pancada é em área: os 3 alvos ficam juntos dentro dela (a 0,5 x o raio do ponto do golpe) um instante antes de cair, e TODOS têm de ser feridos
			juntou = true
			for k in alvos.size():
				alvos[k].pos = (it.ip as Vector2) + [Vector2.ZERO, Vector2(9, 5), Vector2(-9, -5)][k] * esc_a
		var imp := bool(it.imp) and int(it.e) == Golem.ATACANDO
		if int(it.e) != Golem.ATACANDO:
			juntou = false
		if imp and not imp_ant:
			instantes.append(t)
			var feridos := 0
			for k in alvos.size():
				if float(alvos[k].vida) < float(vidas[k]) - 0.01:
					feridos += 1
			if feridos < alvos.size():
				area_ok = false
			for k in alvos.size():
				vidas[k] = float(alvos[k].vida)
		imp_ant = imp
	ok(instantes.size() >= 3, "%s: pelo menos 3 pancadas em 7 s (%d)" % [id, instantes.size()])
	ok(area_ok, "%s: toda pancada fere os 3 alvos que estão dentro dela" % id)
	if instantes.size() >= 3:
		var periodo := (float(instantes[-1]) - float(instantes[1])) / float(instantes.size() - 2)
		var esperado := maxf(tique, Golem.tempo_ataque() + Golem.RESPIRO_MIN)
		ok(absf(periodo - esperado) <= 0.06, "%s: ciclo de %.3f s segue o tique da carta (%.2f s)" % [id, periodo, esperado])
	print("%s: pancadas %d em %s" % [id, instantes.size(), instantes])


## O entulho e as rachaduras ficam no chão depois que o golem some (o slot do pool já é livre, mas o pool continua andando e desenhando o que sobrou).
func checar_restos() -> void:
	preparar_mundo()
	w.combate.armas.definir_golpe("golem_barro", 1, 0.0)
	monstro_a(150.0, 0.0)
	var it = null
	for i in 600:
		passos(1)
		it = golem_ativo()
		if it != null:
			break
	ok(it != null, "restos: o golem nasce")
	if it == null:
		return
	segurar_recarga("golem_barro")
	it.vida = Golem.SUMIR_T + 0.05  # a vida acaba logo: o desmoronar solta a rajada de torrões com 0,6 s de vida restando
	var peso_max := 0
	for i in 60:
		passos(1)
		if float(it.vida) <= 0.0:
			break
		peso_max = maxi(peso_max, (it.deb as PackedFloat32Array).size() / Golem.T_DEB)
	ok(float(it.vida) <= 0.0 and peso_max >= 8, "restos: o desmoronar solta o entulho (%d peças) antes de a vida acabar" % peso_max)
	ok(Golem.tem_restos(it) and w.combate.armas.novas.tem_ativos(), "restos: o golem acabou e o entulho continua (e o pool segue ativo para desenhá-lo)")
	var antes := (it.deb as PackedFloat32Array).size() / Golem.T_DEB
	passos(12)  # 0,2 s depois: as peças de vida curta saem, os torrões (1,2 s ou mais) continuam
	var depois := (it.deb as PackedFloat32Array).size() / Golem.T_DEB
	ok(depois >= 1 and depois <= antes, "restos: 0,2 s depois do fim ainda há entulho no chão (%d de %d peças)" % [depois, antes])
	var torroes := 0
	var d: PackedFloat32Array = it.deb
	for k in d.size() / Golem.T_DEB:
		if d[k * Golem.T_DEB + 9] < 1.5 and d[k * Golem.T_DEB + 6] > 0.4:
			torroes += 1
	ok(torroes >= 3, "restos: os torrões seguem no chão com mais de 0,4 s pela frente (%d)" % torroes)
	passos(60 * 3)
	ok(not Golem.tem_restos(it) and not w.combate.armas.novas.tem_ativos(), "restos: 3 s depois tudo some e o pool volta a repousar")
	# um slot com resto não é reaproveitado se houver outro livre e limpo
	var n_livres_limpos := 0
	for x in w.combate.armas.novas.itens:
		if float(x.vida) <= 0.0 and not Golem.tem_restos(x):
			n_livres_limpos += 1
	ok(n_livres_limpos == w.combate.armas.novas.itens.size(), "restos: todos os slots voltam livres e limpos")
	it.deb = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 4.0, 0.0, 0.0])
	it.vida = 0.0
	var novo: Dictionary = w.combate.armas.novas._novo("projetil", w.combate.armas.ativas["golem_barro"], Vector2.ZERO, 1.0)
	ok(not novo.is_empty() and not is_same(novo, it), "restos: um slot novo evita o que ainda guarda entulho")
	novo.vida = 0.0
	w.combate.armas.novas.limpar()
	ok(not Golem.tem_restos(it), "restos: limpar() (nova partida) apaga o entulho")


## Sem a folha o aliado volta ao desenho antigo (não vira golem) e continua funcionando.
func checar_sem_folha() -> void:
	Golem._tex = null
	Golem._lida = true
	preparar_mundo()
	w.combate.armas.definir_golpe("golem_barro", 1, 0.0)
	monstro_a(150.0, 0.0)
	var item = null
	for i in 600:
		passos(1)
		for x in w.combate.armas.novas.itens:
			if float(x.vida) > 0.0:
				item = x
		if item != null:
			break
	ok(item != null and not bool(item.g), "sem a folha: o aliado nasce pelo caminho antigo, sem estado de golem")
	Golem._lida = false  # a próxima chamada de tex() carrega a folha de novo
	Golem._tex = null
	ok(Golem.tex() != null, "a folha volta a carregar depois do teste do fallback")


func monstro_a(dx: float, dy: float):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, dy))
	m.vida_max = 100000.0
	m.vida = 100000.0
	m.atordoa_t = 0.0
	m.cacador = false
	m.raio_vaga = 0.0
	m.vel_mult = 0.0  # parado: o monstro que anda sai de baixo da pancada e a conta dos 3 alvos vira sorte
	return m


## Só o golem que já nasceu: a recarga (4 s) mandaria um segundo golem antes do primeiro sumir (7 s), e o dano dele contaminaria as contas do primeiro.
func segurar_recarga(id: String) -> void:
	var a = w.combate.armas.ativas.get(id)
	ok(a != null, "%s: a arma está ativa" % id)
	if a != null:
		a.t = 999.0


func golem_ativo():
	for it in w.combate.armas.novas.itens:
		if float(it.vida) > 0.0 and bool(it.g):
			return it
	return null


## Uma partida curta com um golem e um alvo parado: acompanha o item quadro a quadro.
func checar_partida() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	passos(3)
	w.combate.armas.definir_golpe("golem_barro", 1, 0.0)
	var alvo = monstro_a(150.0, 0.0)
	var nos_antes: int = w.combate.armas.no_brilho.get_child_count() + w.combate.armas.no_corpo.get_child_count()
	var it = null
	for i in 400:
		passos(1)
		it = golem_ativo()
		if it != null:
			break
	ok(it != null, "o golem nasce do golpe")
	if it == null:
		return
	segurar_recarga("golem_barro")
	ok(int(it.e) == Golem.SURGINDO and Golem.quadro_de(it).y == 0, "nasce subindo do chão, de frente")
	ok(float(it.vida) >= 30.0 and float(it.vida) <= 60.0, "o golem é um brinde temporário: dura de 30 a 60 s (%.0f s)" % float(it.vida))
	it.vida = minf(float(it.vida), 8.0)  # a duração real é de 45 s: o teste mede o fim da vida dentro dos 9 s do laço
	var pos_antes: Vector2 = it.p
	var pf_antes := float(it.pf)
	var andou := 0.0
	var ataques := 0
	var impactos := 0
	var dano_fora := 0
	var parado_no_golpe := true
	var pos_golpe := Vector2.ZERO
	var vida_alvo := float(alvo.vida)
	var estado_ant := int(it.e)
	var imp_ant := false
	var sumiu := false
	var estados := {}
	var linhas_vistas := {}
	var deb_max := 0
	var racha_vista := false
	var pf_andou := 0.0
	var pf_esperado := 0.0  # a fase que a distância andada deveria dar: cada passo vale 1 / (ciclo da vista em que ele estava)
	for i in 60 * 9:
		passos(1)
		if float(it.vida) <= 0.0:
			break
		var vida_agora := float(alvo.vida)
		var caiu := vida_agora < vida_alvo - 0.01
		vida_alvo = vida_agora
		var e := int(it.e)
		estados[e] = true
		var cruzou := false
		if e == Golem.ATACANDO:
			if estado_ant != Golem.ATACANDO:
				ataques += 1
				pos_golpe = it.p
				imp_ant = false
				ok(Golem.linha_de(it.v, int(it.lin)) == int(it.lin), "a vista do golpe é a da direção em que ele olha")
				if absf(alvo.pos.x - it.p.x) > 3.0:
					ok(signf(float(it.r)) == signf(alvo.pos.x - it.p.x), "no golpe, olha para o lado do alvo")
			if (it.p as Vector2).distance_to(pos_golpe) > 0.01:
				parado_no_golpe = false
			if bool(it.imp) and not imp_ant:
				cruzou = true
				impactos += 1
				ok(float(it.et) >= Golem.tempo_impacto() - 0.001, "o impacto só cai depois do tempo do impacto (et=%f)" % float(it.et))
				ok(Golem.quadro_de(it).x == Golem.COL_ANDAR + Golem.QUADRO_IMPACTO, "no quadro do impacto o desenho mostra o quadro da pancada")
				ok(caiu, "o dano cai no mesmo quadro em que a animação cruza o impacto")
			imp_ant = bool(it.imp)
		if caiu and e == Golem.ATACANDO and not bool(it.imp):
			dano_fora += 1  # dano durante a antecipação, antes da pancada
		if e == Golem.ANDANDO and bool(it.mov):
			andou += (it.p as Vector2).distance_to(pos_antes)
			pf_esperado += (it.p as Vector2).distance_to(pos_antes) / float(Golem.CICLO_LINHA[int(it.lin)])
			pf_andou = float(it.pf) - pf_antes
			linhas_vistas[Golem.quadro_de(it).y] = true
		deb_max = maxi(deb_max, (it.deb as PackedFloat32Array).size() / Golem.T_DEB)
		if float(it.rt) >= 0.0:
			racha_vista = true
		pos_antes = it.p
		estado_ant = e
		if bool(it.sumiu):
			sumiu = true
	ok(
		estados.has(Golem.SURGINDO) and estados.has(Golem.ANDANDO) and estados.has(Golem.ATACANDO),
		"passou pelos estados surgir, andar e atacar (%s)" % [estados.keys()]
	)
	ok(ataques >= 2, "o golem ataca mais de uma vez em 9 s (%d)" % ataques)
	ok(impactos >= ataques - 1 and impactos <= ataques, "uma pancada por ataque (%d pancadas, %d ataques)" % [impactos, ataques])
	ok(dano_fora == 0, "nenhum dano durante a antecipação, antes do impacto (%d)" % dano_fora)
	ok(parado_no_golpe, "o golem fica plantado durante o golpe")
	ok(andou > 3.0, "o golem andou até o alvo (%.0f px)" % andou)
	ok(
		pf_andou > 0.0 and absf(pf_andou - pf_esperado) < 0.02,
		"o passo avança com a distância andada, pelo ciclo da vista (pf %.3f, esperado %.3f, %.0f px)" % [pf_andou, pf_esperado, andou]
	)  # a relação com a ARTE está em checar_passada
	ok(deb_max >= 6 and deb_max <= Golem.MAX_DEB, "a pancada espalha entulho no chão (até %d peças, máximo %d)" % [deb_max, Golem.MAX_DEB])
	ok(racha_vista, "a pancada abre rachaduras no chão")
	ok(not linhas_vistas.is_empty(), "andou com alguma vista (linhas %s)" % [linhas_vistas.keys()])
	ok(sumiu or float(it.vida) <= 0.0, "o golem desmorona no fim da duração")
	var nos_depois: int = w.combate.armas.no_brilho.get_child_count() + w.combate.armas.no_corpo.get_child_count()
	ok(nos_antes == nos_depois, "nenhum nó novo na camada de desenho (%d -> %d)" % [nos_antes, nos_depois])
	print("golem: ataques %d, pancadas %d, andou %.0f px, estados %s" % [ataques, impactos, andou, estados.keys()])


## Prepara o mundo com o golem e um alvo parado na direção `dir` (em px do herói) e devolve o item do golem.
func preparar_foto(dir: Vector2):
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	passos(3)
	w.combate.armas.definir_golpe("golem_barro", 1, 0.0)
	monstro_a(dir.x, dir.y)
	for i in 400:
		passos(1)
		if golem_ativo() != null:
			break
	return golem_ativo()


## Recorte (ampliado 3x, vizinho mais próximo) do viewport em volta do golem, agora.
func recorte(it, meia := Vector2(80, 92), alto := 120) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = w.sv.get_texture().get_image()
	var c: Vector2 = Vector2(img.get_size()) * 0.5 + ((it.p as Vector2) - (w.cam.pos as Vector2) - (w.cam.deslocamento as Vector2))
	var r := Rect2i(Vector2i(c) + Vector2i(-meia), Vector2i(int(meia.x * 2.0), alto))
	r.position.x = clampi(r.position.x, 0, img.get_width() - r.size.x)
	r.position.y = clampi(r.position.y, 0, img.get_height() - r.size.y)
	var out := img.get_region(r)
	out.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_NEAREST)
	return out


func juntar(recortes: Array, colunas: int) -> Image:
	var rw: int = (recortes[0] as Image).get_width()
	var rh: int = (recortes[0] as Image).get_height()
	var linhas := ceili(float(recortes.size()) / colunas)
	var folha := Image.create(rw * colunas, rh * linhas, false, Image.FORMAT_RGBA8)
	folha.fill(Color(0.05, 0.05, 0.05))
	for i in recortes.size():
		folha.blit_rect(recortes[i], Rect2i(0, 0, rw, rh), Vector2i((i % colunas) * rw, (i / colunas) * rh))
	return folha


## Prints do jogo de verdade (com janela): a sequência de um ataque e o golem andando e batendo para cada lado.
func fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	Config.g_aplicar_perfil("alto")
	var seq: Array = []
	var it = preparar_foto(Vector2(150, 0))
	var pedidos := [["mov", 0], ["atq", 1], ["atq", 3], ["atq", 4], ["atq", 4], ["atq", 5], ["atq", 7]]
	var feitos := 0
	var visto_atq := -1
	var apos_impacto := 0
	for i in 60 * 6:
		passos(1)
		if float(it.vida) <= 0.0 or feitos >= pedidos.size():
			break
		var ped: Array = pedidos[feitos]
		var e := int(it.e)
		var q := Golem.quadro_ataque(float(it.et)) if e == Golem.ATACANDO else -1
		if ped[0] == "mov" and e == Golem.ANDANDO and bool(it.mov) and Golem.quadro_andar(float(it.pf)) == 3:
			seq.append(await recorte(it))
			feitos += 1
		elif ped[0] == "mov" and e == Golem.ATACANDO:
			feitos += 1  # chegou perto demais para dar tempo de pegar o passo: segue para o ataque
		elif ped[0] == "atq" and q == int(ped[1]) and q != visto_atq:
			if q == 4 and feitos > 0 and int(pedidos[feitos - 1][1]) == 4 and apos_impacto < 4:
				apos_impacto += 1
				continue
			apos_impacto = 0
			visto_atq = q
			seq.append(await recorte(it))
			feitos += 1
		elif q < 0:
			visto_atq = -1
	juntar(seq, 4).save_png(pasta.path_join("jogo_ataque.png"))
	var dirs := [
		["direita", Vector2(150, 0)],
		["esquerda", Vector2(-150, 0)],
		["baixo", Vector2(0, 130)],
		["cima", Vector2(0, -130)],
		["diag_baixo", Vector2(110, 80)],
		["diag_cima", Vector2(-110, -80)]
	]
	var rec: Array = []
	for d in dirs:
		it = preparar_foto(d[1])
		var andando := false
		var batendo := false
		for i in 60 * 5:
			passos(1)
			if float(it.vida) <= 0.0 or (andando and batendo):
				break
			if not andando and int(it.e) == Golem.ANDANDO and bool(it.mov) and Golem.quadro_andar(float(it.pf)) == 3:
				rec.append(await recorte(it))
				andando = true
			if not batendo and int(it.e) == Golem.ATACANDO and Golem.quadro_ataque(float(it.et)) == 4:
				passos(2)
				rec.append(await recorte(it))
				batendo = true
		print("FOTO direção ", d[0], " lin ", it.lin, " r ", it.r)
	juntar(rec, 4).save_png(pasta.path_join("jogo_direcoes.png"))
	print("FOTO ", pasta)


## Prints do passo e da pancada (opção --fotos_novas=PASTA): o golem andando de lado (8 quadros seguidos do ciclo, para ver a passada larga e o corpo
## descendo e subindo) e a pancada (o impacto, 0,07 s, 0,2 s, 0,5 s e 1,0 s depois: poeira, torrões e rachaduras no chão).
func fotos_novas(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	Config.g_aplicar_perfil("alto")
	await faixa_andar(pasta.path_join("jogo_andar.png"), Vector2(300, 0))
	await faixa_andar(pasta.path_join("jogo_andar_frente.png"), Vector2(0, 300))  # de frente: o pé de apoio sobe na tela, o corpo balança
	var it = preparar_foto(Vector2(150, 0))
	if it == null:
		return
	segurar_recarga("golem_barro")
	var pancada: Array = []
	var depois := [0, 4, 12, 30, 60]
	var impacto_em := -1
	for i in 60 * 5:
		passos(1)
		if float(it.vida) <= 0.0 or pancada.size() >= depois.size():
			break
		if impacto_em < 0 and bool(it.imp) and int(it.e) == Golem.ATACANDO:
			impacto_em = i
		if impacto_em >= 0 and i - impacto_em == int(depois[pancada.size()]):
			pancada.append(await recorte(it, Vector2(100, 92), 130))
	juntar(pancada, 3).save_png(pasta.path_join("jogo_pancada.png"))
	# o fim do golem: o desmoronar solta o entulho, e ele continua no chão depois que o golem some
	it = preparar_foto(Vector2(150, 0))
	segurar_recarga("golem_barro")
	it.vida = Golem.SUMIR_T + 0.05
	var restos: Array = []
	var quando := [1, 20, 40, 60, 90, 150]
	for i in 160:
		passos(1)
		if restos.size() < quando.size() and i == int(quando[restos.size()]):
			restos.append(await recorte(it, Vector2(70, 80), 100))
	juntar(restos, 3).save_png(pasta.path_join("jogo_restos.png"))
	print("FOTO ", pasta)


## Os 8 quadros seguidos do ciclo de andar do golem indo para um alvo na direção `dir`.
func faixa_andar(arquivo: String, dir: Vector2) -> void:
	var it = preparar_foto(dir)
	if it == null:
		return
	segurar_recarga("golem_barro")
	var andar: Array = []
	var proximo := -1
	for i in 60 * 5:
		passos(1)
		if float(it.vida) <= 0.0 or andar.size() >= 8:
			break
		if int(it.e) == Golem.ANDANDO and bool(it.mov):
			var q := Golem.quadro_andar(float(it.pf))
			if proximo < 0 and q == 0:
				proximo = 0
			if q == proximo:
				andar.append(await recorte(it, Vector2(60, 76), 100))
				proximo = (proximo + 1) % 8
	if not andar.is_empty():
		juntar(andar, 4).save_png(arquivo)


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	checar_folha()
	checar_funcoes()
	checar_partida()
	checar_passada()
	checar_area("golem_barro", false)
	checar_area("colosso_de_pedra", true)
	checar_restos()
	checar_sem_folha()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			await fotos(a.trim_prefix("--fotos="))
		if a.begins_with("--fotos_novas="):
			await fotos_novas(a.trim_prefix("--fotos_novas="))
	print("v2_golem falhas=%d" % falhas)
	get_tree().quit()
