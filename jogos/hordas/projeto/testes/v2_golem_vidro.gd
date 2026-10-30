extends "res://testes/isolamento_v2.gd"
## Sprite próprio da Torre (#449), sem alterar números; pool cobre diretor Difícil+Pesadelo e as duas elites.

const Mundo := preload("res://v2/mundo.tscn")
const Sprites := preload("res://v2/sprites.gd")
const Meta := preload("res://v2/meta.gd")
const NOVO := "inimigo_golem_vidro"
const ANTIGO := "inimigo_espantalho"
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	_folhas()
	_dados()
	await _mundo()
	print("v2_golem_vidro falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _folhas() -> void:
	var tp: Dictionary = Sprites.new().tipo(NOVO)
	ok(tp.info.linhas.size() == 5 and tp.info.colunas.size() == 4, "cinco vistas e quatro quadros de andar")
	ok(tp.w <= 64 and tp.h <= 64, "quadro cabe no atlas sem inflar a horda")
	ok(tp.tex.normal_texture != null and tp.emissao != null, "normal e emissão carregadas")
	var base := "res://prototipos/cara_nova/sprites/" + NOVO
	var albedo := Sprites.png(base + "_albedo.png")
	for passe in ["albedo", "normal", "emissao"]:
		var im := Sprites.png(base + "_" + passe + ".png")
		ok(im != null and im.get_size() == Vector2i(int(tp.w) * 4, int(tp.h) * 5), "dimensão do passe " + passe)
	for linha in 5:
		for quadro in 4:
			var rec := Rect2i(quadro * int(tp.w), linha * int(tp.h), int(tp.w), int(tp.h))
			ok(albedo.get_region(rec).get_used_rect().has_area(), "arte em cada vista e quadro")


func _dados() -> void:
	var cfg: Dictionary = Dados.json("v2_combate")
	ok(cfg.monstros[NOVO] == cfg.monstros[ANTIGO], "todos os números preservados do espantalho")
	var usos := 0
	for mapa in Dados.json("v2_elencos").mapas:
		for tipo in Dados.json("v2_elencos").mapas[mapa].tipos:
			if tipo.sprite == NOVO:
				usos += 1
				ok(mapa == "laboratorio" and tipo.id == "golem_vidro", "somente o golem da Torre usa a folha")
	ok(usos == 1, "uma única entrada do elenco foi substituída")
	var script = preload("res://v2/mundo.gd")
	ok(script.SPRITES_MONSTRO.has(NOVO) and not script.TIPOS_MONSTRO.has(NOVO), "extra registrado fora do sorteio padrão")
	for tipo in cfg.diretor.tipos:
		ok(tipo.sprite != NOVO, "sorteio padrão preservado")
	for tipo in Dados.json("v2_cartas").elites.tipos:
		ok(tipo.sprite != NOVO, "elite padrão preservada")
	var densidade := 1.0
	for dificuldade in Dados.json("v2_dificuldade").opcoes:
		densidade = maxf(densidade, float(dificuldade.densidade_mult))
	var teto := roundi(float(cfg.diretor.teto) * densidade * float(Meta.regras_pesadelo().densidade_mult))
	var elites := int(Dados.json("v2_cartas").elites.max_vivos)
	ok(int(cfg.pool[NOVO]) >= teto + elites, "pool cobre todos os vivos do diretor mais as elites: %d+%d" % [teto, elites])
	for marcador in Dados.json("v2_laboratorio").get("marcadores", []):
		ok(marcador.tipo != "defesa", "Torre não tem outra fonte de golem em defesa de ponto")
	var elenco: Dictionary = Dados.json("v2_elencos").mapas.laboratorio
	ok(not elenco.invocados.has("golem_vidro"), "invocadores não acrescentam golems fora do teto")


func _mundo() -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = "laboratorio"
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.combate.limpar_partida()
	ok(w.horda.atlas.origem.has(NOVO), "folha presente no atlas")
	var total_antes: int = w._todos_monstros.size()
	var capacidade: int = w.combate.cfg.pool[NOVO]
	var vivos := []
	var ids := {}
	var tipo: Dictionary = {}
	for tp in w.elenco.tipos:
		if tp.id == "golem_vidro":
			tipo = tp
	for i in capacidade:
		var m = w.nascer_monstro(NOVO, w.heroi.pos + Vector2(150 + i % 12, 40 + i / 12), false, 1, 1, tipo)
		vivos.append(m)
		ids[m.get_instance_id()] = true
		ok(m.chave == NOVO and m.variante == "golem_vidro", "tipo novo nasce com a variação correta")
	ok(vivos.size() == capacidade and ids.size() == capacidade, "pico adversarial inteiro usa instâncias distintas")
	ok(w._todos_monstros.size() == total_antes and w._pool_monstros[NOVO].is_empty(), "nenhuma criação tardia até o pico")
	var oito := {}
	for ang in range(0, 360, 45):
		var m = vivos[0]
		m.vel_v = Vector2.from_angle(deg_to_rad(float(ang))) * 50
		m._escolher_quadro(m.vel_v)
		oito[str(m.linha) + str(m.espelha)] = true
	ok(oito.size() == 8, "oito direções distintas por linha e espelho")
	w.combate.limpar_partida()
	ok(w._pool_monstros[NOVO].size() == capacidade, "pico inteiro volta ao pool")
	var m = w.nascer_monstro(NOVO, w.heroi.pos + Vector2(100, 20), false, 1, 1, tipo)
	ok(ids.has(m.get_instance_id()) and w._todos_monstros.size() == total_antes, "renascer reutiliza a mesma instância")
	await _foto(w, tipo)
	w.queue_free()
	await get_tree().process_frame


## Captura opcional em janela: -- --fotos=C:/pasta_externa/golem.png. Sem esse argumento, o CI só executa os contratos.
func _foto(w, tipo: Dictionary) -> void:
	var caminho := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fotos="):
			caminho = arg.trim_prefix("--fotos=")
	if caminho == "":
		return
	ok(DisplayServer.get_name() != "headless", "captura exige janela real")
	if DisplayServer.get_name() == "headless":
		return
	ok(caminho.is_absolute_path() and not caminho.begins_with(ProjectSettings.globalize_path("res://")), "foto fora do projeto")
	if not caminho.is_absolute_path() or caminho.begins_with(ProjectSettings.globalize_path("res://")):
		return
	w.combate.limpar_partida()
	for i in 8:
		var pos: Vector2 = w.heroi.pos + Vector2(-165 + (i % 4) * 110, -70 if i < 4 else 90)
		var c = w.nascer_monstro(NOVO, pos, false, 1, 1, tipo)
		c.vel_v = Vector2.from_angle(deg_to_rad(float(i * 45))) * 50
		c._escolher_quadro(c.vel_v)
		c.coluna = i % 4
	w.avancar(0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	ok(get_viewport().get_texture().get_image().save_png(caminho) == OK, "foto salva fora do projeto")
	print("GOLEM_FOTO ", caminho)
