extends "res://testes/isolamento_v2.gd"
## Homúnculo da Torre: folha própria sem mudar regras, atlas, oito direções e reciclagem até a capacidade pré-criada.
const Mundo := preload("res://v2/mundo.tscn")
const Sprites := preload("res://v2/sprites.gd")
const Meta := preload("res://v2/meta.gd")
const NOVO := "inimigo_homunculo"
const ANTIGO := "inimigo_aranha_tecela"
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var comb: Dictionary = Dados.json("v2_combate")
	ok(comb.monstros.get(NOVO) == comb.monstros[ANTIGO], "stats iguais aos da aranha substituída")
	var densidade := 1.0
	for dificuldade in Dados.json("v2_dificuldade").opcoes:
		densidade = maxf(densidade, float(dificuldade.densidade_mult))
	var elites: Dictionary = Dados.json("v2_cartas").elites
	var filhos := 0
	for modificador in elites.modificadores:
		if modificador.id == "invoca":
			filhos = int(modificador.max)
	# Piso conservador do teste: diretor + elites atuais e seus filhos. Filhos de elites mortas podem ultrapassar esse piso.
	var piso := roundi(float(comb.diretor.teto) * densidade * float(Meta.regras_pesadelo().densidade_mult)) + int(elites.max_vivos) * (1 + filhos)
	ok(int(comb.pool[NOVO]) >= piso, "pool cobre diretor, elites simultâneas e seus filhos (%d)" % piso)
	var usos := 0
	var alvo: Dictionary = {}
	for mapa in Dados.json("v2_elencos").mapas:
		for tipo in Dados.json("v2_elencos").mapas[mapa].tipos:
			if tipo.sprite == NOVO:
				usos += 1
				ok(mapa == "laboratorio" and tipo.id == "homunculo", "folha exclusiva do homúnculo da Torre")
				alvo = tipo
	ok(usos == 1, "um único tipo usa a folha")
	var sp := Sprites.new()
	var folha: Dictionary = sp.tipo(NOVO)
	ok(folha.info.linhas.size() == 5 and folha.info.colunas.size() == 4, "cinco vistas e quatro quadros")
	ok(folha.tex.normal_texture != null and folha.emissao != null, "normal e emissão disponíveis")
	var im: Image = Sprites.png("res://prototipos/cara_nova/sprites/" + NOVO + "_albedo.png")
	ok(im != null and im.get_size() == Vector2i(int(folha.w) * 4, int(folha.h) * 5), "dimensões da folha")
	if im != null:
		for linha in 5:
			for coluna in 4:
				ok(im.get_region(Rect2i(coluna * int(folha.w), linha * int(folha.h), int(folha.w), int(folha.h))).get_used_rect().has_area(), "quadro com arte")
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = "laboratorio"
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	for tipo in w.elenco.tipos:
		if tipo.id == "homunculo":
			alvo = tipo
	ok(not w.TIPOS_MONSTRO.has(NOVO) and w.SPRITES_EXTRA.has(NOVO), "padrão não ganha o novo tipo")
	for tipo in comb.diretor.tipos:
		ok(tipo.sprite != NOVO, "sorteio padrão preservado")
	ok(w.horda.atlas.origem.has(NOVO), "folha presente no atlas da horda")
	var capacidade := int(comb.pool[NOVO])
	var quantos: int = w._todos_monstros.size()
	var nos := get_tree().get_node_count()
	var ativos: Array = []
	for mo in w.monstros:
		if mo.chave == NOVO:
			ativos.append(mo)
	while ativos.size() < capacidade:
		ativos.append(w.nascer_monstro(NOVO, w.heroi.pos + Vector2(200, 0), false, 1.0, 1.0, alvo))
	ok(w._todos_monstros.size() == quantos and get_tree().get_node_count() == nos, "até a capacidade não cria monstro ou nó")
	var mo = ativos.back()
	ok(mo.variante == "homunculo", "tipo do elenco e seus multiplicadores preservados")
	var direcoes := {}
	for ang in range(0, 360, 45):
		mo.vel_v = Vector2.from_angle(deg_to_rad(float(ang))) * 50.0
		mo._escolher_quadro(mo.vel_v)
		direcoes[str(mo.linha) + str(mo.espelha)] = true
	ok(direcoes.size() == 8, "oito combinações de vista e espelho")
	for m in ativos:
		m.vivo = false
		m.raiz.visible = false
		w.devolver_monstro(m)
	var reciclado = w.nascer_monstro(NOVO, w.heroi.pos + Vector2(160, 0), false, 1.0, 1.0, alvo)
	ok(ativos.has(reciclado) and w._todos_monstros.size() == quantos, "renasce pelo pool")
	print("homunculo pool_capacidade=%d nós_estáveis=%s" % [capacidade, str(get_tree().get_node_count() == nos)])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fotos=") and DisplayServer.get_name() != "headless":
			await _foto(w, arg.trim_prefix("--fotos="), alvo)
	w.queue_free()
	await get_tree().process_frame
	print("v2_homunculo_torre falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _foto(w, pasta: String, tipo: Dictionary) -> void:
	get_window().size = Vector2i(960, 540)
	for m in w.monstros.duplicate():
		m.vivo = false
		m.raiz.visible = false
		w.devolver_monstro(m)
	for i in 8:
		var m = w.nascer_monstro(NOVO, w.heroi.pos + Vector2(-120 + (i % 4) * 80, 50 + (i / 4) * 65), false, 1.0, 1.0, tipo)
		m.vel_v = Vector2.from_angle(float(i) * PI / 4.0) * 50.0
		m._escolher_quadro(m.vel_v)
	w.avancar(0.0)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(pasta)
	var tam = await w.ap.foto(pasta.path_join("homunculo_torre.png"))
	print("FOTO homunculo_torre %s janela=%s render=%s" % [tam, get_window().size, DisplayServer.get_name()])
