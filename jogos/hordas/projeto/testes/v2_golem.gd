extends Node
## O Golem de Barro da v2 (v2/golem.gd, ligado em v2/armas_novas.gd): a folha 3D confere com as constantes do código, a vista sai da direção
## (5 linhas, com histerese), o passo anda com a distância andada, o ciclo surgir -> andar -> atacar -> andar -> desmoronar acontece de verdade,
## parado durante o golpe, e o dano cai UMA vez por pancada, no quadro do impacto (não no começo do ataque). Nenhum nó novo na camada de desenho.
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
		absf(Golem.tempo_impacto() - 0.40) < 0.001 and Golem.tempo_ataque() > Golem.tempo_impacto() + 0.3,
		"tempos do ataque: impacto em 0,40 s e a volta depois"
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
	ok(Golem.eh_golem("golem_barro") and Golem.eh_golem("colosso_de_pedra") and not Golem.eh_golem("lobo_espirito"), "quem é golem")


func monstro_a(dx: float, dy: float):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, dy))
	m.vida_max = 100000.0
	m.vida = 100000.0
	m.atordoa_t = 0.0
	m.cacador = false
	m.raio_vaga = 0.0
	return m


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
	ok(int(it.e) == Golem.SURGINDO and Golem.quadro_de(it).y == 0, "nasce subindo do chão, de frente")
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
	var pf_andou := 0.0
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
			pf_andou = float(it.pf) - pf_antes
			linhas_vistas[Golem.quadro_de(it).y] = true
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
	ok(pf_andou > 0.0 and absf(pf_andou * Golem.CICLO_PX - andou) < 1.0, "o passo avança com a distância andada (pf %.3f, %.0f px)" % [pf_andou, andou])
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
func recorte(it) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = w.sv.get_texture().get_image()
	var c: Vector2 = Vector2(img.get_size()) * 0.5 + ((it.p as Vector2) - (w.cam.pos as Vector2) - (w.cam.deslocamento as Vector2))
	var r := Rect2i(Vector2i(c) + Vector2i(-80, -92), Vector2i(160, 120))
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


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	checar_folha()
	checar_funcoes()
	checar_partida()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			await fotos(a.trim_prefix("--fotos="))
	print("v2_golem falhas=%d" % falhas)
	get_tree().quit()
