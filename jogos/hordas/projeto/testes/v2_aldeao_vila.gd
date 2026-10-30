extends "res://testes/isolamento_v2.gd"
# Teste do sprite próprio do aldeão da Vila Amaldiçoada (#449, "Refs #449 (aldeão)"): a folha nova (5 vistas x 4 quadros de andar, albedo + normal
# + emissão) carrega por v2/sprites.gd, entra no atlas da horda, tem os mesmos números de combate do cão que ele substitui, só o tipo "aldeão"
# do mapa "cidade" a usa, e todos os OUTROS tipos de todos os elencos continuam com o sprite que tinham (e o sorteio padrão não ganha o aldeão).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_aldeao_vila.tscn  (imprime "v2_aldeao_vila falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Sprites := preload("res://v2/sprites.gd")
const PASTA_SPRITES := "res://prototipos/cara_nova/sprites/"
const ALDEAO := "inimigo_aldeao_morto"
const ANTIGO := "inimigo_cao_ossos"
## Pico observado no estresse da Vila: Difícil + Pesadelo, robô imortal; reavaliar ao mudar o elenco/diretor.
const PICO_MEDIDO := 39
## O sprite de cada tipo de cada elenco ANTES do aldeão novo (id do mapa -> id do tipo -> sprite). O aldeão da cidade não está aqui de propósito.
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
		"espectro_uivante": ["inimigo_lobo_sombrio", "inimigo_espectro"],
		"estatua_viva": "inimigo_espantalho",
		"cavaleiro_caido": "inimigo_cavaleiro_oco"
	},
	"laboratorio":
	{
		"larva_frasco": "inimigo_cao_ossos",
		"homunculo": ["inimigo_aranha_tecela", "inimigo_homunculo"],
		"rato_alquimico": "inimigo_aranha_tecela",
		"quimera_frasco": "inimigo_lobo_sombrio",
		"golem_vidro": ["inimigo_espantalho", "inimigo_golem_vidro"],
		"golem_alquimista": "inimigo_cavaleiro_oco"
	},
	"cidade":
	{
		"corvo": "inimigo_corvo_carniceiro",
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
	print("v2_aldeao_vila falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


## A folha carrega e tem o formato dos outros monstros: 5 linhas (frente, 3/4, perfil, 3/4 costas, costas; o jogo espelha para as 8 direções).
func _folha() -> void:
	var sp := Sprites.new()
	var t: Dictionary = sp.tipo(ALDEAO)
	var ref: Dictionary = sp.tipo(ANTIGO)
	ok(int(t.w) > 0 and int(t.h) > 0, "aldeão: quadro com tamanho (%dx%d)" % [t.w, t.h])
	ok(t.info.linhas == ref.info.linhas, "aldeão: as mesmas 5 vistas do cão")
	ok(t.info.linhas.size() == 5, "aldeão: 5 linhas (frente, 3/4, perfil, 3/4 costas, costas)")
	ok(t.info.colunas.size() == ref.info.colunas.size(), "aldeão: o mesmo número de quadros de andar do cão (%d)" % t.info.colunas.size())
	var im: Image = Sprites.png(PASTA_SPRITES + ALDEAO + "_albedo.png")
	ok(im != null, "aldeão: o albedo carrega")
	if im == null:
		return
	ok(im.get_width() == int(t.w) * t.info.colunas.size() and im.get_height() == int(t.h) * 5, "aldeão: o albedo tem colunas x quadro e 5 linhas")
	ok(t.emissao != null, "aldeão: tem folha de emissão (olhos)")
	ok(t.alb != null and t.tex.normal_texture != null, "aldeão: albedo e normal carregados")
	# cabe no quadro do cão que ele substitui (mesma escala dos outros bichos)
	ok(int(t.w) <= int(ref.w) and int(t.h) <= int(ref.h), "aldeão: quadro %dx%d cabe no do cão %dx%d" % [t.w, t.h, ref.w, ref.h])
	# a folha tem arte em todas as linhas (as 5 vistas existem de verdade)
	for l in 5:
		var area: Rect2i = im.get_region(Rect2i(0, l * int(t.h), im.get_width(), int(t.h))).get_used_rect()
		ok(area.has_area(), "aldeão: a linha %d da folha tem arte" % l)
		for q in 4:
			var celula := im.get_region(Rect2i(q * int(t.w), l * int(t.h), int(t.w), int(t.h)))
			ok(celula.get_used_rect().has_area(), "aldeão: vista %d quadro %d tem arte" % [l, q])


## Os dados: o aldeão da cidade usa o sprite novo (com os números do cão); nenhum outro tipo de nenhum elenco mudou.
func _dados() -> void:
	var arq: Dictionary = Dados.json("v2_elencos")
	var achou := false
	for tp in arq.mapas.cidade.tipos:
		if tp.id == "aldeao_morto":
			achou = true
			ok(tp.sprite == ALDEAO, "cidade: o aldeão usa o sprite novo (%s)" % tp.sprite)
	ok(achou, "cidade: o tipo 'aldeão' existe")
	var usam := 0
	for mapa in arq.mapas:
		for tp in arq.mapas[mapa].tipos:
			if tp.sprite == ALDEAO:
				usam += 1
				ok(mapa == "cidade" and tp.id == "aldeao_morto", "%s/%s: só o aldeão da cidade pode usar o sprite novo" % [mapa, tp.id])
			elif OUTROS.has(mapa) and OUTROS[mapa].has(tp.id):
				ok(
					_sprite_preservado(str(mapa), str(tp.id), str(tp.sprite)),
					"%s/%s: o sprite continua %s (é %s)" % [mapa, tp.id, OUTROS[mapa][tp.id], tp.sprite]
				)
			else:
				ok(false, "%s/%s: tipo que o teste não conhece (atualize OUTROS)" % [mapa, tp.id])
	ok(usam == 1, "o sprite novo é usado por 1 tipo, não %d" % usam)
	for mapa in OUTROS:
		for id in OUTROS[mapa]:
			var vivo := false
			for tp in arq.mapas[mapa].tipos:
				vivo = vivo or tp.id == id
			ok(vivo, "%s/%s: o tipo continua no elenco" % [mapa, id])
	# números de combate: iguais aos do cão, que ele substitui (a curva de dificuldade não muda)
	var comb: Dictionary = Dados.json("v2_combate")
	ok(comb.monstros.has(ALDEAO), "v2_combate: o aldeão tem números de combate")
	ok(comb.monstros.get(ALDEAO) == comb.monstros[ANTIGO], "v2_combate: o aldeão tem os mesmos números do cão")
	# o sorteio padrão (mapa sem elenco) não ganhou o aldeão
	var mundo = preload("res://v2/mundo.gd")
	ok(mundo.TIPOS_MONSTRO.size() == 5 and not mundo.TIPOS_MONSTRO.has(ALDEAO), "padrão: TIPOS_MONSTRO continua com os 5 de sempre")
	ok(mundo.PESOS_MONSTRO.size() == mundo.TIPOS_MONSTRO.size(), "padrão: um peso por tipo")
	ok(mundo.SPRITES_MONSTRO.has(ALDEAO) and mundo.SPRITES_MONSTRO.size() >= 7, "SPRITES_MONSTRO inclui os 5 originais e o aldeão")
	for t in comb.diretor.tipos:
		ok(t.sprite != ALDEAO, "padrão: o diretor não sorteia o aldeão")
	for t in Dados.json("v2_cartas").elites.tipos:
		ok(t.sprite != ALDEAO, "padrão: a elite não nasce aldeão")


## Com o mundo da cidade: o aldeão nasce com o sprite novo, está no atlas da horda e os outros tipos nascem com o sprite de antes.
func _mundo() -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = "cidade"
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.heroi.imortal = true
	ok(w.horda.atlas.origem.has(ALDEAO), "horda: o atlas tem a folha do aldeão")
	for s in w.TIPOS_MONSTRO:
		ok(w.horda.atlas.origem.has(s), "horda: o atlas continua com %s" % s)
	ok(not w._pool_monstros.get(ALDEAO, []).is_empty(), "o pool do aldeão foi pré-criado")
	for inicial in w.monstros.duplicate():
		inicial.vivo = false
		w.devolver_monstro(inicial)
	var capacidade := int(Dados.json("v2_combate").pool[ALDEAO])
	ok(capacidade >= ceili(float(PICO_MEDIDO) * 1.25), "pool: cobre o pico medido com ao menos 25% de folga")
	var ids_pool := {}
	for mo in w._pool_monstros[ALDEAO]:
		ids_pool[mo.get_instance_id()] = true
	ok(ids_pool.size() == capacidade, "pool: capacidade formada por nós distintos pré-criados")
	var retirados := []
	for i in capacidade:
		var mo = w.nascer_monstro(ALDEAO, w.heroi.pos + Vector2(250, 0))
		ok(ids_pool.has(mo.get_instance_id()), "pool: nascimento %d reutiliza nó pré-criado" % i)
		retirados.append(mo)
	for mo in retirados:
		mo.vivo = false
		w.devolver_monstro(mo)
	ok(w._pool_monstros[ALDEAO].size() == capacidade, "pool: todos os nós voltam após o pico")
	var visto := {}
	for tp in w.elenco.tipos:
		var m = w.nascer_monstro(str(tp.sprite), w.heroi.pos + Vector2(200, 0), false, 1.0, 1.0, tp)
		visto[tp.id] = m.chave
		if tp.id == "aldeao_morto":
			ok(m.chave == ALDEAO, "cidade: o aldeão nasce com a folha nova (%s)" % m.chave)
			ok(m.variante == "aldeao_morto", "cidade: o aldeão mantém o id do tipo (%s)" % m.variante)
			ok(m.n_lin == 5 and m.vida_max > 0.0, "cidade: o aldeão tem 5 linhas e vida")
		else:
			ok(_sprite_preservado("cidade", str(tp.id), str(m.chave)), "cidade/%s: nasce com %s (é %s)" % [tp.id, OUTROS.cidade[tp.id], m.chave])
	ok(visto.size() == 6, "cidade: os 6 tipos do elenco nasceram (%d)" % visto.size())
	# as 8 direções: a linha e o espelho do aldeão seguem o movimento como nos outros monstros
	var c = w.nascer_monstro(ALDEAO, w.heroi.pos + Vector2(220, 20))
	var combos := {}
	for ang in range(0, 360, 45):
		c.vel_v = Vector2.from_angle(deg_to_rad(float(ang))) * 50.0
		c._escolher_quadro(c.vel_v)
		combos[str(c.linha) + ("e" if c.espelha else "d")] = true
	ok(combos.size() == 8, "aldeão: as 8 direções dão 8 combinações de linha/espelho (%d: %s)" % [combos.size(), combos.keys()])
	w.queue_free()
	await get_tree().process_frame


## Os quatro sprites aprovados na #449 podem entrar em PRs separados; cada alias continua vinculado ao seu tipo.
func _sprite_preservado(mapa: String, id: String, sprite: String) -> bool:
	if not preload("res://v2/mundo.gd").SPRITES_MONSTRO.has(sprite):
		return false
	var esperado: Variant = OUTROS[mapa][id]
	return esperado.has(sprite) if esperado is Array else sprite == str(esperado)
