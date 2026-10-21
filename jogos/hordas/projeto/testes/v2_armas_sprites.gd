extends "res://testes/isolamento_v2.gd"
# Teste automático dos sprites das armas da v2 (assets/v2/armas/indice.json, ligados em v2/armas_novas.gd): o índice lê e cada PNG
# carrega com o tamanho que ele diz; cada golpe novo (45) tem sprite com textura; cada arma citada no índice é um golpe ou evolução que existe;
# com os 45 golpes ligados ao mesmo tempo, todos os tipos acertam, o pool continua do mesmo tamanho, nenhum nó novo aparece no
# desenho e cada golpe ativo leva o sprite da sua arma.
# Com janela e `-- --fotos=PASTA`, salva o print do viewport com os golpes na tela (usado em docs/visual_2_5d/armas_v2).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_armas_sprites.tscn  (imprime "v2_armas_sprites falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Novas := preload("res://v2/armas_novas.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const PASTA := "res://assets/v2/armas/"
const ANTIGOS := ["laminas", "aura_fogo", "corvos", "raio", "runa"]  # os 5 golpes que já existiam (fora dos 45 novos)
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func golpe_existe(id: String) -> bool:
	for g in w.combate.cartas.cfg.golpes:
		if str(g.id) == id:
			return true
	for ev in w.combate.cartas.cfg.evolucoes:
		if str(ev.id) == id:
			return true
	return false


## O índice e os PNG: cada sprite carrega com o tamanho do índice, o normal map carrega, e toda arma citada é um golpe dos dados.
func checar_indice() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(PASTA.path_join("indice.json")))
	ok(d is Dictionary and d.has("sprites") and not d.sprites.is_empty(), "o indice.json lê e tem sprites")
	if not (d is Dictionary):
		return
	for nome in d.sprites:
		var s: Dictionary = d.sprites[nome]
		var tex := load(PASTA.path_join(str(s.arquivo))) as Texture2D
		ok(tex != null, "%s: o PNG carrega" % nome)
		if tex != null:
			var tam := Vector2(float(s.tamanho[0]), float(s.tamanho[1]))
			ok(tex.get_size() == tam, "%s: o PNG tem o tamanho do índice (%s, índice %s)" % [nome, tex.get_size(), tam])
		if s.get("normal") != null:
			var nor := load(PASTA.path_join(str(s.normal))) as Texture2D
			ok(nor != null, "%s: o normal map carrega" % nome)
		var armas: Array = s.armas_sugeridas + s.armas_aproximadas
		ok(not armas.is_empty(), "%s: serve pelo menos uma arma" % nome)
		for arma in armas:
			ok(golpe_existe(str(arma)), "%s serve %s, que não é golpe nem evolução nos dados" % [nome, arma])


## Cada golpe novo (os 45) tem sprite com textura.
func checar_golpes() -> void:
	var novos := 0
	var com := 0
	var em_codigo := 0  # golpes da leva 6 (torre e granada): desenhados em código, sem folha de sprite (campo "desenho": "codigo")
	for g in w.combate.cartas.cfg.golpes:
		var id := str(g.id)
		if id in ANTIGOS:
			continue
		if str(g.get("desenho", "")) == "codigo":
			em_codigo += 1
			continue
		novos += 1
		var sp: Dictionary = Novas.sprite_de(id)
		if not sp.is_empty() and sp.tex != null:
			com += 1
		else:
			ok(false, "golpe novo %s sem sprite com textura" % id)
	ok(novos == 45, "45 golpes novos nos dados (%d)" % novos)
	ok(com == novos, "todo golpe novo tem sprite com textura (%d de %d)" % [com, novos])
	for id in ANTIGOS:
		ok(not Novas.sprite_de(id).is_empty(), "golpe antigo %s tem sprite" % id)
	var evolucoes: Array = w.combate.cartas.cfg.evolucoes
	ok(evolucoes.size() == 27, "27 evolucoes nos dados")
	ok(em_codigo == 2, "2 golpes desenhados em código (Sentinela de Bambu e Cabaça de Pólvora): %d" % em_codigo)
	var ev_codigo := 0
	for ev in evolucoes:
		if str(ev.get("desenho", "")) == "codigo":
			ev_codigo += 1
			continue
		var sp: Dictionary = Novas.sprite_de(str(ev.id))
		ok(not sp.is_empty(), "evolucao %s tem sprite proprio" % str(ev.id))
		if not sp.is_empty():
			var textura: Texture2D = sp.tex
			if textura is CanvasTexture:
				textura = (textura as CanvasTexture).diffuse_texture
			ok(textura.resource_path.get_file() == str(ev.id) + ".png", "evolucao %s usa a propria arte" % str(ev.id))
	ok(ev_codigo == 2, "2 evoluções desenhadas em código (Pagode do Trovão e Fogos de Festival): %d" % ev_codigo)
	print("cobertura: %d de %d golpes novos, 5 antigos e 25 evolucoes com sprite" % [com, novos])


func monstro_a(dx: float, dy: float):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, dy))
	m.vida_max = 100000.0
	m.vida = 100000.0
	m.atordoa_t = 0.0
	m.cacador = false
	m.raio_vaga = 0.0
	return m


## Os 45 golpes ligados ao mesmo tempo, com 24 monstros que não morrem em volta.
func preparar_partida() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.correr_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	w.combate.cartas.rng.seed = 12345
	passos(3)
	for g in w.combate.cartas.cfg.golpes:
		if str(g.id) in ANTIGOS:
			continue
		w.combate.armas.definir_golpe(str(g.id), 1, 0.0)
	for i in 24:
		var a := TAU * i / 24.0
		var r := 130.0 + 40.0 * (i % 3)
		monstro_a(cos(a) * r, sin(a) * r * 0.62)


## Depois de 10 s de jogo: todos os tipos acertam, o pool e a camada de desenho não crescem, e cada golpe ativo leva o sprite da sua arma.
func checar_partida() -> void:
	passos(600)
	var armas = w.combate.armas
	var acertos: Dictionary = armas.acertos
	for tipo in ["projetil", "nuvem", "anel", "explode", "aliado"]:
		ok(int(acertos.get(tipo, 0)) > 0, "os golpes do tipo %s acertam (%d)" % [tipo, int(acertos.get(tipo, 0))])
	ok(armas.novas.itens.size() == Novas.MAX, "o pool continua com %d slots" % Novas.MAX)
	ok(armas.no_brilho.get_child_count() == 0 and armas.no_corpo.get_child_count() == 0, "nenhum nó novo na camada de desenho")
	var ativos := 0
	var com_sp := 0
	for it in armas.novas.itens:
		if float(it.vida) <= 0.0:
			continue
		ativos += 1
		var esperado: Dictionary = Novas.sprite_de(str(it.a.id))
		ok(it.sp.is_empty() == esperado.is_empty(), "golpe %s: o sprite do item bate com o da arma" % str(it.a.id))
		if not it.sp.is_empty():
			com_sp += 1
	ok(ativos > 0 and com_sp > 0, "há golpes ativos com sprite (%d de %d)" % [com_sp, ativos])
	print("partida: acertos %s; golpes ativos %d, com sprite %d" % [acertos, ativos, com_sp])


## Print do viewport (com janela): o mesmo mundo da partida, uns 2 s depois, com os golpes na tela.
func foto(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	Config.g_aplicar_perfil("alto")
	passos(120)
	await RenderingServer.frame_post_draw
	var img: Image = w.sv.get_texture().get_image()
	img.save_png(pasta.path_join("golpes_com_sprite.png"))
	print("FOTO ", pasta.path_join("golpes_com_sprite.png"), " ", img.get_size())


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	checar_indice()
	checar_golpes()
	preparar_partida()
	checar_partida()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			await foto(a.trim_prefix("--fotos="))
	print("v2_armas_sprites falhas=%d" % falhas)
	get_tree().quit()
