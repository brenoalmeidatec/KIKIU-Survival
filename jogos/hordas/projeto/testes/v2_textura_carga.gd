extends "res://testes/isolamento_v2.gd"
# A carga da partida não sobe textura que a partida não usa (pedido do Alisson, 15/11: "ataca cortando a textura não usada"), e o que fica
# de fora não sobe no meio da luta:
#  (1) silhueta borrada da sombra só no Médio (Sprites.blur_de); trocar para o Médio cria as que faltam;
#  (2) rastro da katana (`corte`): o herói que não corta só tem o tamanho do leque dos chefes; o que corta, todos;
#  (3) folhas do martelo só com o Nicão;
#  (4) pixelfx decorativo fora no perfil Baixo, e carregado quando o perfil sobe (menu de pausa);
#  (5) folhas grandes das elites do mapa já carregadas;
#  (6) retrato do HUD é a folha que a partida já subiu.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_textura_carga.tscn  (imprime "v2_textura_carga falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Sombras := preload("res://v2/sombras.gd")
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func novo(id: String, perfil: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Config.g_perfil_temporario(perfil)
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true


func _carregados(nome: String) -> Array:
	var r: Array = []
	var fx = w.combate.fx
	if not fx._fx_tex.has(nome):
		return r
	for k in fx._fx_tex[nome].size():
		if fx._fx_tex[nome][k] != null:
			r.append(int(fx._fx_larg[nome][k]))
	return r


func _ready() -> void:
	await _alto_lightwolf()
	await _baixo_hazaki()
	await _nicao()
	Config.g_perfil_temporario("alto")
	print("v2_textura_carga falhas=", falhas)
	get_tree().quit(1 if falhas else 0)


func _alto_lightwolf() -> void:
	await novo("lightwolf", "alto")
	ok(w.sombras.modo == Sombras.ALTA, "perfil Alto: sombra alta")
	var com_blur: Array = []
	for nome in w.sprites._tipos:
		var t = w.sprites._tipos[nome]
		if t is Dictionary and t.get("blur") != null:
			com_blur.append(nome)
	ok(com_blur.is_empty(), "(1) no Alto nenhuma folha tem silhueta borrada na placa: %s" % str(com_blur))
	ok(w.horda.atlas.get("blur") == null and w.horda.lote_sombra.mmi.texture == w.horda.atlas.alb, "(1) o atlas da horda sem silhueta borrada no Alto")
	ok(_carregados("corte") == [312], "(2) quem não corta só tem o tamanho do leque: %s" % str(_carregados("corte")))
	ok(not w.combate.fx._fx_tex.has("martelo_rastro"), "(3) sem martelo para o LightWolf")
	ok(not w.combate.fx._fx_tex.has("anel") and not w.combate.fx._fx_tex.has("espiral"), "anel e espiral fora da carga")
	var n := int(maxf(1.0, roundf(float(w.combate.elites.cfg.escala))))
	for info in w.elenco.elites_lista:
		var g := "%s_x%d" % [info.sprite, n]
		if ResourceLoader.exists("res://prototipos/cara_nova/sprites/%s_albedo.png" % g):
			ok(w.sprites._tipos.has(g) and not w.sprites._tipos[g].is_empty(), "(5) folha grande da elite %s já carregada" % g)
	var retrato: TextureRect = null
	for no in w.ui.get_children():
		if no.has_node("Raiz/Retrato/Heroi"):
			retrato = no.get_node("Raiz/Retrato/Heroi")
	ok(retrato != null and retrato.texture is AtlasTexture and retrato.texture.atlas == w.heroi.tipo.alb, "(6) o retrato usa a folha do herói já na placa")
	ok(w.combate.fx_folha.adiar_deco == false and w.combate.fx_folha._defs.all(func(d): return d.tex != null), "(4) no Alto o pixelfx carrega todo")
	# a troca para o Médio (menu de pausa): a silhueta nasce e vai para a sombra do herói e do lote
	w.sombras.definir_modo(Sombras.MEDIA)
	w.horda._trocar_modo(Sombras.MEDIA)
	ok(w.heroi.tipo.get("blur") != null and w.heroi.sh1.texture == w.heroi.tipo.blur, "(1) no Médio o herói ganha a silhueta borrada")
	ok(w.horda.lote_sombra.mmi.texture == w.horda.atlas.get("blur") and w.horda.atlas.get("blur") != null, "(1) no Médio o lote da horda ganha a silhueta")
	# o leque do chefe desenha o tamanho já carregado: nada sobe na hora
	w.combate.fx.corte(w.heroi.pos, 0.0, 120.0 * 0.9, 110.0, 1.0, "corte", Color.WHITE, 0.3)
	ok(w.combate.fx.tamanhos_fora_da_conta == 0, "(2) o corte do leque não carrega no meio da partida")


func _baixo_hazaki() -> void:
	await novo("hazaki", "baixo")
	ok(w.sombras.modo == Sombras.BAIXA, "perfil Baixo: sombra baixa")
	var ff = w.combate.fx_folha
	ok(ff.adiar_deco, "(4) no Baixo sem ajuste o pixelfx decorativo fica adiado")
	var vazias: int = ff._defs.filter(func(d): return d.tex == null).size()
	ok(vazias == ff._defs.size() and vazias > 0, "(4) nenhuma folha decorativa na placa (%d de %d)" % [vazias, ff._defs.size()])
	ok(not ff.tocar("level-up", w.heroi.pos), "(4) no Baixo o enfeite não nasce")
	ok(_carregados("corte").size() == w.combate.fx._fx_larg["corte"].size(), "(2) quem corta tem todos os tamanhos: %s" % str(_carregados("corte")))
	Config.g_perfil_temporario("medio")  # o menu de pausa: graficos_mudou > _ler_graficos
	ok(ff._defs.all(func(d): return d.tex != null), "(4) subir do Baixo carrega as folhas adiadas")
	ok(ff.tocar("level-up", w.heroi.pos), "(4) e o enfeite volta a nascer")


func _nicao() -> void:
	await novo("nicao", "alto")
	for k in ["martelo_rastro", "martelo_impacto", "martelo_onda"]:
		ok(w.combate.fx._fx_tex.has(k) and _carregados(k).size() == w.combate.fx._fx_larg[k].size(), "(3) %s já na carga do Nicão" % k)
	ok(_carregados("corte") == [312], "(2) o Nicão (martelo, especial terremoto) só tem o tamanho do leque")
