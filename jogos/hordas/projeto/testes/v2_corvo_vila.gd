extends "res://testes/isolamento_v2.gd"
# Teste do sprite próprio do corvo da Vila Amaldiçoada (#449, "Refs #449 (corvo)"): a folha nova (5 vistas x 4 quadros de andar, albedo + normal
# + emissão) carrega por v2/sprites.gd, entra no atlas da horda, tem os mesmos números de combate da aranha que ele substitui, só o tipo "corvo"
# do mapa "cidade" a usa, e todos os OUTROS tipos de todos os elencos continuam com o sprite que tinham (e o sorteio padrão não ganha o corvo).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_corvo_vila.tscn  (imprime "v2_corvo_vila falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Sprites := preload("res://v2/sprites.gd")
const PASTA_SPRITES := "res://prototipos/cara_nova/sprites/"
const CORVO := "inimigo_corvo_carniceiro"
const ANTIGO := "inimigo_aranha_tecela"
## O sprite de cada tipo de cada elenco ANTES do corvo novo (id do mapa -> id do tipo -> sprite). O corvo da cidade não está aqui de propósito.
const OUTROS := {
	"floresta":
	{
		"lobo_faminto": "inimigo_cao_ossos",
		"raposa_espectral": "inimigo_cao_ossos",
		"aranha_mata": "inimigo_aranha_tecela",
		"lobo_cinzento": "inimigo_lobo_sombrio",
		"espirito_mata": "inimigo_espantalho",
		"guardiao": "inimigo_cavaleiro_oco"
	},
	"medio":
	{
		"esqueleto": "inimigo_cao_ossos",
		"esqueleto_podre": "inimigo_cao_ossos",
		"larva_cripta": "inimigo_aranha_tecela",
		"espectro_uivante": "inimigo_espectro",
		"estatua_viva": "inimigo_espantalho",
		"cavaleiro_caido": "inimigo_cavaleiro_oco"
	},
	"laboratorio":
	{
		"larva_frasco": "inimigo_cao_ossos",
		"homunculo": "inimigo_aranha_tecela",
		"rato_alquimico": "inimigo_aranha_tecela",
		"quimera_frasco": "inimigo_lobo_sombrio",
		"golem_vidro": "inimigo_espantalho",
		"golem_alquimista": "inimigo_cavaleiro_oco"
	},
	"cidade":
	{
		"aldeao_morto": "inimigo_cao_ossos",
		"cao_amaldicoado": "inimigo_cao_ossos",
		"lobisomem": "inimigo_lobo_sombrio",
		"espantalho_vila": "inimigo_espantalho",
		"carrasco": "inimigo_cavaleiro_oco"
	}
}
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	_folha()
	_dados()
	await _mundo()
	print("v2_corvo_vila falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


## A folha carrega e tem o formato dos outros monstros: 5 linhas (frente, 3/4, perfil, 3/4 costas, costas; o jogo espelha para as 8 direções).
func _folha() -> void:
	var sp := Sprites.new()
	var t: Dictionary = sp.tipo(CORVO)
	var ref: Dictionary = sp.tipo(ANTIGO)
	ok(int(t.w) > 0 and int(t.h) > 0, "corvo: quadro com tamanho (%dx%d)" % [t.w, t.h])
	ok(t.info.linhas == ref.info.linhas, "corvo: as mesmas 5 vistas da aranha")
	ok(t.info.linhas.size() == 5, "corvo: 5 linhas (frente, 3/4, perfil, 3/4 costas, costas)")
	ok(t.info.colunas.size() == ref.info.colunas.size(), "corvo: o mesmo número de quadros de andar da aranha (%d)" % t.info.colunas.size())
	var im: Image = Sprites.png(PASTA_SPRITES + CORVO + "_albedo.png")
	ok(im != null, "corvo: o albedo carrega")
	if im == null:
		return
	ok(im.get_width() == int(t.w) * t.info.colunas.size() and im.get_height() == int(t.h) * 5, "corvo: o albedo tem colunas x quadro e 5 linhas")
	ok(t.emissao != null, "corvo: tem folha de emissão (olhos)")
	ok(t.alb != null and t.tex.normal_texture != null, "corvo: albedo e normal carregados")
	# cabe no quadro da aranha que ele substitui (mesma escala dos outros bichos)
	ok(int(t.w) <= int(ref.w) and int(t.h) <= int(ref.h), "corvo: quadro %dx%d cabe no da aranha %dx%d" % [t.w, t.h, ref.w, ref.h])
	# a folha tem arte em todas as linhas (as 5 vistas existem de verdade)
	for l in 5:
		var area: Rect2i = im.get_region(Rect2i(0, l * int(t.h), im.get_width(), int(t.h))).get_used_rect()
		ok(area.has_area(), "corvo: a linha %d da folha tem arte" % l)


## Os dados: o corvo da cidade usa o sprite novo (com os números da aranha); nenhum outro tipo de nenhum elenco mudou.
func _dados() -> void:
	var arq: Dictionary = Dados.json("v2_elencos")
	var achou := false
	for tp in arq.mapas.cidade.tipos:
		if tp.id == "corvo":
			achou = true
			ok(tp.sprite == CORVO, "cidade: o corvo usa o sprite novo (%s)" % tp.sprite)
	ok(achou, "cidade: o tipo 'corvo' existe")
	var usam := 0
	for mapa in arq.mapas:
		for tp in arq.mapas[mapa].tipos:
			if tp.sprite == CORVO:
				usam += 1
				ok(mapa == "cidade" and tp.id == "corvo", "%s/%s: só o corvo da cidade pode usar o sprite novo" % [mapa, tp.id])
			elif OUTROS.has(mapa) and OUTROS[mapa].has(tp.id):
				ok(tp.sprite == OUTROS[mapa][tp.id], "%s/%s: o sprite continua %s (é %s)" % [mapa, tp.id, OUTROS[mapa][tp.id], tp.sprite])
			else:
				ok(false, "%s/%s: tipo que o teste não conhece (atualize OUTROS)" % [mapa, tp.id])
	ok(usam == 1, "o sprite novo é usado por 1 tipo, não %d" % usam)
	for mapa in OUTROS:
		for id in OUTROS[mapa]:
			var vivo := false
			for tp in arq.mapas[mapa].tipos:
				vivo = vivo or tp.id == id
			ok(vivo, "%s/%s: o tipo continua no elenco" % [mapa, id])
	# números de combate: iguais aos da aranha, que ele substitui (a curva de dificuldade não muda)
	var comb: Dictionary = Dados.json("v2_combate")
	ok(comb.monstros.has(CORVO), "v2_combate: o corvo tem números de combate")
	ok(comb.monstros.get(CORVO) == comb.monstros[ANTIGO], "v2_combate: o corvo tem os mesmos números da aranha")
	# o sorteio padrão (mapa sem elenco) não ganhou o corvo
	var mundo = preload("res://v2/mundo.gd")
	ok(mundo.TIPOS_MONSTRO.size() == 5 and not mundo.TIPOS_MONSTRO.has(CORVO), "padrão: TIPOS_MONSTRO continua com os 5 de sempre")
	ok(mundo.PESOS_MONSTRO.size() == mundo.TIPOS_MONSTRO.size(), "padrão: um peso por tipo")
	ok(
		mundo.SPRITES_MONSTRO.has(CORVO) and mundo.SPRITES_MONSTRO.size() == mundo.TIPOS_MONSTRO.size() + mundo.SPRITES_EXTRA.size(),
		"SPRITES_MONSTRO contém os padrões e as folhas extras"
	)
	for t in comb.diretor.tipos:
		ok(t.sprite != CORVO, "padrão: o diretor não sorteia o corvo")
	for t in Dados.json("v2_cartas").elites.tipos:
		ok(t.sprite != CORVO, "padrão: a elite não nasce corvo")


## Com o mundo da cidade: o corvo nasce com o sprite novo, está no atlas da horda e os outros tipos nascem com o sprite de antes.
func _mundo() -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = "cidade"
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.heroi.imortal = true
	ok(w.horda.atlas.origem.has(CORVO), "horda: o atlas tem a folha do corvo")
	for s in w.TIPOS_MONSTRO:
		ok(w.horda.atlas.origem.has(s), "horda: o atlas continua com %s" % s)
	ok(not w._pool_monstros.get(CORVO, []).is_empty(), "o pool do corvo foi pré-criado")
	var visto := {}
	for tp in w.elenco.tipos:
		var m = w.nascer_monstro(str(tp.sprite), w.heroi.pos + Vector2(200, 0), false, 1.0, 1.0, tp)
		visto[tp.id] = m.chave
		if tp.id == "corvo":
			ok(m.chave == CORVO, "cidade: o corvo nasce com a folha nova (%s)" % m.chave)
			ok(m.variante == "corvo", "cidade: o corvo mantém o id do tipo (%s)" % m.variante)
			ok(m.n_lin == 5 and m.vida_max > 0.0, "cidade: o corvo tem 5 linhas e vida")
		else:
			ok(m.chave == OUTROS.cidade[tp.id], "cidade/%s: nasce com %s (é %s)" % [tp.id, OUTROS.cidade[tp.id], m.chave])
	ok(visto.size() == 6, "cidade: os 6 tipos do elenco nasceram (%d)" % visto.size())
	# as 8 direções: a linha e o espelho do corvo seguem o movimento como nos outros monstros
	var c = w.nascer_monstro(CORVO, w.heroi.pos + Vector2(220, 20))
	var combos := {}
	for ang in range(0, 360, 45):
		c.vel_v = Vector2.from_angle(deg_to_rad(float(ang))) * 50.0
		c._escolher_quadro(c.vel_v)
		combos[str(c.linha) + ("e" if c.espelha else "d")] = true
	ok(combos.size() == 8, "corvo: as 8 direções dão 8 combinações de linha/espelho (%d: %s)" % [combos.size(), combos.keys()])
	w.queue_free()
	await get_tree().process_frame
