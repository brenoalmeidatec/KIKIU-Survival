extends "res://testes/isolamento_v2.gd"
## Sprite próprio do Espectro Uivante das Ruínas: folha, oito direções, dados e pool no pior pico de vivos.
const Mundo := preload("res://v2/mundo.tscn")
const Sprites := preload("res://v2/sprites.gd")
const ESPECTRO := "inimigo_espectro"
const ANTIGO := "inimigo_lobo_sombrio"
const PASTA := "res://prototipos/cara_nova/sprites/"
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	_folha()
	_dados()
	await _mundo()
	print("v2_espectro_ruinas falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _folha() -> void:
	var sp := Sprites.new()
	var t: Dictionary = sp.tipo(ESPECTRO)
	ok(t.info.linhas == sp.tipo(ANTIGO).info.linhas, "espectro: cinco vistas compatíveis")
	ok(t.info.colunas.size() == 4, "espectro: quatro quadros por vista")
	ok(t.tex.normal_texture != null and t.emissao != null, "espectro: normal e emissão carregam")
	var albedo: Image = Sprites.png(PASTA + ESPECTRO + "_albedo.png")
	var normal: Image = Sprites.png(PASTA + ESPECTRO + "_normal.png")
	ok(albedo != null and normal != null, "espectro: folhas legíveis")
	if albedo == null or normal == null:
		return
	var quadro := Vector2i(int(t.w), int(t.h))
	ok(albedo.get_size() == quadro * Vector2i(4, 5), "espectro: tamanho da folha")
	ok(normal.get_size() == albedo.get_size(), "espectro: normal no mesmo enquadramento")
	for linha in 5:
		var poses := {}
		for col in 4:
			var celula := albedo.get_region(Rect2i(Vector2i(col, linha) * quadro, quadro))
			ok(celula.get_used_rect().has_area(), "espectro: vista %d quadro %d não é vazio" % [linha, col])
			poses[hash(celula.get_data())] = true
		ok(poses.size() > 1, "espectro: animação muda na vista %d" % linha)


func _dados() -> void:
	var cfg: Dictionary = Dados.json("v2_combate")
	ok(cfg.monstros[ESPECTRO] == cfg.monstros[ANTIGO], "espectro: combate preserva os números do lobo anterior")
	var usos := 0
	for mapa in Dados.json("v2_elencos").mapas:
		for tipo in Dados.json("v2_elencos").mapas[mapa].tipos:
			if tipo.sprite == ESPECTRO:
				usos += 1
				ok(mapa == "medio" and tipo.id == "espectro_uivante", "espectro: somente o tipo das Ruínas usa a folha")
	ok(usos == 1, "espectro: exatamente um tipo usa a folha")
	var codigo = preload("res://v2/mundo.gd")
	ok(codigo.SPRITES_EXTRA.has(ESPECTRO) and not codigo.TIPOS_MONSTRO.has(ESPECTRO), "espectro: extra sem entrar no sorteio padrão")
	for tipo in cfg.diretor.tipos:
		ok(tipo.sprite != ESPECTRO, "espectro: diretor padrão preservado")
	for tipo in Dados.json("v2_cartas").elites.tipos:
		ok(tipo.sprite != ESPECTRO, "espectro: elites padrão preservadas")


## Limite conservador: todos os vivos permitidos poderiam ser deste tipo, não só a fração esperada no sorteio.
## Diretor inclui os moradores no teto; elites e defesa podem nascer acima dele. As invocações das Ruínas não são espectros.
func _pico() -> int:
	var densidade := 1.0
	for d in Dados.json("v2_dificuldade").opcoes:
		densidade = maxf(densidade, float(d.densidade_mult))
	var pesadelo := 1.0
	for modo in Dados.json("v2_meta").modos:
		if modo.id == "pesadelo":
			pesadelo = float(modo.regras.densidade_mult)
	var pico := roundi(float(Dados.json("v2_combate").diretor.teto) * densidade * pesadelo)
	pico += int(Dados.json("v2_cartas").elites.max_vivos)
	var codigo = preload("res://v2/mundo.gd")
	for marca in Dados.json("v2_medio").marcadores:
		if marca.tipo == "defesa":
			pico += ceili(float(marca.tempo) / codigo.DEFESA_ONDA_S) * codigo.DEFESA_MONSTROS_POR_ONDA
	for id in Dados.json("v2_elencos").mapas.medio.invocados:
		ok(id != "espectro_uivante", "pico: invocações não acrescentam espectros")
	return pico


func _mundo() -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = "medio"
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.combate.limpar_partida()
	w.heroi.imortal = true
	ok(w.horda.atlas.origem.has(ESPECTRO), "espectro: atlas da horda inclui a folha")
	var tipo: Dictionary = {}
	for t in w.elenco.tipos:
		if t.id == "espectro_uivante":
			tipo = t
	var pico := _pico()
	ok(int(Dados.json("v2_combate").pool[ESPECTRO]) >= pico, "pool cobre o pico conservador de %d vivos" % pico)
	var total_antes: int = w._todos_monstros.size()
	var nos_antes: int = w.no_mundo.get_child_count()
	var vivos: Array = []
	for i in pico:
		var m = w.nascer_monstro(ESPECTRO, w.heroi.pos + Vector2(180 + i % 10, 100 + i / 10), true, 1.0, 1.0, tipo)
		vivos.append(m)
		ok(m.chave == ESPECTRO and m.variante == "espectro_uivante", "espectro: variante nasce com a folha própria")
	ok(w._todos_monstros.size() == total_antes, "pico não cria outro objeto de monstro")
	ok(w.no_mundo.get_child_count() == nos_antes, "pico não cria nó durante a partida")
	var combos := {}
	for ang in range(0, 360, 45):
		vivos[0].vel_v = Vector2.from_angle(deg_to_rad(float(ang))) * 50.0
		vivos[0]._escolher_quadro(vivos[0].vel_v)
		combos[str(vivos[0].linha) + ("e" if vivos[0].espelha else "d")] = true
	ok(combos.size() == 8, "espectro: oito direções distintas")
	for m in vivos:
		m.vivo = false
		w.devolver_monstro(m)
	for i in pico:
		w.nascer_monstro(ESPECTRO, w.heroi.pos + Vector2(180, 100), true, 1.0, 1.0, tipo)
	ok(w._todos_monstros.size() == total_antes, "pool reutiliza todo o pico numa segunda leva")
	print(
		(
			"espectro pico=%d pool=%d objetos_extra=%d nos_extra=%d"
			% [pico, Dados.json("v2_combate").pool[ESPECTRO], w._todos_monstros.size() - total_antes, w.no_mundo.get_child_count() - nos_antes]
		)
	)
	w.queue_free()
	await get_tree().process_frame
