extends Node
## As invocações que andam de verdade (v2/andante.gd, ligado em v2/armas_novas.gd): para cada ficha, a folha e o .json do gerador batem com o
## código; o ciclo surgir -> andar -> atacar -> andar -> sumir acontece; ele para em alcance; o passo só anda quando ele anda; o golpe fere
## UMA vez por ataque, no quadro do impacto, e o ciclo segue o "tique" da carta.
## Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_andante.tscn  (imprime "v2_andante falhas=0")
## Fotos (com janela): ... res://testes/v2_andante.tscn -- --fotos=PASTA  (ataque e direções de cada bicho)
const Mundo := preload("res://v2/mundo.tscn")
const Andante := preload("res://v2/andante.gd")
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


func checar_folha(id: String) -> void:
	var f := Andante.ficha(id)
	var t := Andante.tex(id)
	ok(t != null, "%s: a folha existe" % id)
	if t == null:
		return
	var q: Vector2 = f.quadro
	ok(t.get_size() == Vector2(q.x * 16, q.y * Andante.LINHAS), "%s: a folha tem 16 x 5 quadros de %s (tem %s)" % [id, q, t.get_size()])
	var js := str(f.folha).get_basename() + ".json"
	var d = JSON.parse_string(FileAccess.get_file_as_string(js))
	ok(d is Dictionary, "%s: o .json do gerador existe ao lado da folha" % id)
	if not d is Dictionary:
		return
	ok(Vector2(float(d.quadro[0]), float(d.quadro[1])) == q, "%s: quadro do .json = do código" % id)
	ok(Vector2(float(d.pe_x), float(d.pe_y)) == f.pe, "%s: pé do .json = do código" % id)
	ok(int(d.andar) == Andante.COL_ANDAR and int(d.ataque) == Andante.COL_ATAQUE and int(d.impacto) == int(f.impacto), "%s: colunas e impacto" % id)
	for v in Andante.LINHAS if not f.has("ciclo_s") else 0:  # quem voa ou flutua tem o ciclo no relógio, sem pé no chão
		ok(absf(float(d.ciclo_linha[v]) - float(f.ciclo[v])) <= 0.6, "%s vista %d: passada do código = da arte (o pé não escorrega)" % [id, v])
	ok(float(f.frente) <= float(d.alcance_pata_px), "%s: o golpe cai onde a pata alcança (%s <= %s px)" % [id, f.frente, d.alcance_pata_px])
	ok(f.tempos.size() == Andante.COL_ATAQUE, "%s: um tempo por quadro de ataque" % id)


func checar_funcoes() -> void:
	var f := Andante.ficha("espirito_urso")
	ok(Andante.eh_andante("espirito_urso") and not Andante.eh_andante("golem_barro") and not Andante.eh_andante("lobo_espirito"), "quem é andante")
	ok(Andante.quadro_andar(0.0) == 0 and Andante.quadro_andar(0.5) == 4 and Andante.quadro_andar(-0.1) == 7, "quadro de andar pela fase")
	ok(Andante.quadro_ataque(f, 0.0) == 0 and Andante.quadro_ataque(f, Andante.tempo_impacto(f) + 0.001) == int(f.impacto), "quadro do impacto")
	ok(Andante.quadro_ataque(f, 99.0) == Andante.COL_ATAQUE - 1, "o ataque termina no último quadro")


func preparar(id: String, dir: Vector2):
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	passos(3)
	w.combate.armas.definir_golpe(id, 1, 0.0)
	w.combate.armas.ativas[id].st.quantidade = 1  # o teste mede UM bicho por vez (o dano de um segundo contaria como fora do quadro do impacto)
	var m = monstro_a(dir.x, dir.y)
	var it = null
	for i in 400:
		passos(1)
		it = ativo()
		if it != null:
			break
	var a = w.combate.armas.ativas.get(id)
	if a != null:
		a.t = 999.0  # só este: a recarga mandaria outro antes deste sumir
	for outro in w.combate.armas.novas.itens:
		if outro != it and bool(outro.an) and float(outro.vida) > 0.0:
			outro.vida = 0.0  # cartas com quantidade > 1 (o Fantasma nasce em dupla): só o acompanhado fica, senão o golpe do outro conta como dano fora do impacto
	return [it, m]


func monstro_a(dx: float, dy: float):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, dy))
	m.vida_max = 100000.0
	m.vida = 100000.0
	m.cacador = false
	m.raio_vaga = 0.0
	m.vel_mult = 0.0
	return m


func ativo():
	for it in w.combate.armas.novas.itens:
		if float(it.vida) > 0.0 and bool(it.an):
			return it
	return null


## Uma partida curta: nasce da névoa, anda até o alvo (o passo só avança andando), para em alcance, ataca, o dano cai no impacto (uma vez) e some.
func checar_partida(id: String) -> void:
	var f := Andante.ficha(id)
	var r: Array = preparar(id, Vector2(160, 0))
	var it = r[0]
	var m = r[1]
	ok(it != null and str(it.a.id) == id, "%s: nasce como andante" % id)
	if it == null:
		return
	ok(int(it.e) == Andante.SURGINDO and Andante.presenca(it) < 1.0, "%s: começa surgindo" % id)
	it.vida = 6.0  # a duração da carta (4 s) dá 2 ou 3 golpes conforme onde ele nasce: com 6 s a conta do ritmo fica firme
	var andou := false
	var parou_em := -1.0
	var impactos: Array = []
	var vida_ant := float(m.vida)
	var dano_fora := false
	var t := 0.0
	var pf_parado_ok := true
	for i in 60 * 7:
		var pf_antes := float(it.pf)
		passos(1)
		t += PASSO
		if float(it.vida) <= 0.0:
			break
		if int(it.e) == Andante.ANDANDO and bool(it.mov):
			andou = true
		if not f.has("ciclo_s") and not bool(it.mov) and float(it.pf) != pf_antes:
			pf_parado_ok = false
		if int(it.e) == Andante.ATACANDO and parou_em < 0.0:
			parou_em = w.combate.armas.novas._eli((m.pos as Vector2) - (it.p as Vector2)).length()
		if float(m.vida) < vida_ant - 0.01:
			var no_impacto := int(it.e) == Andante.ATACANDO and absf(float(it.et) - Andante.tempo_impacto(f)) <= PASSO * 1.5
			if not no_impacto:
				dano_fora = true
			impactos.append(t)
			vida_ant = float(m.vida)
	ok(andou, "%s: anda até o alvo" % id)
	ok(pf_parado_ok, "%s: parado, o passo não avança (o pé não escorrega)" % id)
	ok(parou_em > 0.0 and parou_em <= float(f.alcance) + float(m.raio) + 2.0, "%s: para em alcance para atacar (%.1f px)" % [id, parou_em])
	ok(impactos.size() >= 3, "%s: pelo menos 3 golpes (%d)" % [id, impactos.size()])
	ok(not dano_fora, "%s: o dano só cai no quadro do impacto" % id)
	if impactos.size() >= 3:
		var periodo := (float(impactos[-1]) - float(impactos[1])) / float(impactos.size() - 2)
		var esperado := maxf(float(it.a.st.tique), Andante.tempo_ataque(f) + Andante.RESPIRO_MIN)
		ok(absf(periodo - esperado) <= 0.06, "%s: ciclo de %.3f s segue o tique (%.2f s)" % [id, periodo, esperado])
	ok(float(it.vida) <= 0.0, "%s: some no fim da vida" % id)


## Direções: a vista sai da direção do alvo (frente descendo, costas subindo, perfil de lado) e o lado esquerdo é o espelho.
func checar_direcoes(id: String) -> void:
	for caso in [[Vector2(0, 150), 0], [Vector2(0, -150), 4], [Vector2(170, 0), 2], [Vector2(-170, 0), 2], [Vector2(120, 110), 1], [Vector2(-120, -110), 3]]:
		var r: Array = preparar(id, caso[0])
		var it = r[0]
		if it == null:
			ok(false, "%s: nasceu" % id)
			continue
		var visto := -1  # a vista no começo do golpe (travada na direção do alvo); andando, ela vira suave a partir da frente
		for i in 60 * 3:
			passos(1)
			if int(it.e) == Andante.ATACANDO:
				visto = int(it.lin)
				break
		ok(visto == int(caso[1]), "%s: atacando para %s usa a vista %d (usou %d)" % [id, caso[0], caso[1], visto])
		if (caso[0] as Vector2).x < -1.0:
			ok(float(it.r) < 0.0, "%s: para a esquerda, espelhado" % id)


func fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	Config.g_aplicar_perfil("alto")
	for id in Andante.FICHAS:
		var f := Andante.ficha(id)
		var r: Array = preparar(id, Vector2(150, 0))
		var it = r[0]
		var seq: Array = []
		var quer := 0
		for i in 60 * 5:
			passos(1)
			if it == null or float(it.vida) <= 0.0 or seq.size() >= 12:
				break
			if seq.size() < 4 and int(it.e) == Andante.ANDANDO and bool(it.mov) and Andante.quadro_andar(float(it.pf)) == quer * 2:
				seq.append(await recorte(it))
				quer += 1
			elif seq.size() >= 4 and int(it.e) == Andante.ATACANDO and Andante.quadro_ataque(f, float(it.et)) == seq.size() - 4:
				seq.append(await recorte(it))
		if not seq.is_empty():
			juntar(seq, 4).save_png(pasta.path_join(id + "_andar_ataque.png"))
		var rec: Array = []
		for d in [
			Vector2(150, 0), Vector2(-150, 0), Vector2(0, 130), Vector2(0, -130), Vector2(110, 90), Vector2(-110, 90), Vector2(110, -90), Vector2(-110, -90)
		]:
			r = preparar(id, d)
			it = r[0]
			for i in 60 * 3:
				passos(1)
				if (
					it != null
					and int(it.e) == Andante.ANDANDO
					and bool(it.mov)
					and (f.has("ciclo_s") and float(it.et) >= 0.3 or Andante.quadro_andar(float(it.pf)) == 3)
				):  # ciclo no relógio (flutua, rasteja): pega um quadro andando, com a vista já virada
					rec.append(await recorte(it))
					break
		if not rec.is_empty():
			juntar(rec, 4).save_png(pasta.path_join(id + "_direcoes.png"))
	print("FOTO ", pasta)


func recorte(it, meia := Vector2(64, 70), alto := 100) -> Image:
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


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	checar_funcoes()
	for id in Andante.FICHAS:
		checar_folha(id)
		checar_partida(id)
		checar_direcoes(id)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			await fotos(a.trim_prefix("--fotos="))
	print("v2_andante falhas=%d" % falhas)
	get_tree().quit()
