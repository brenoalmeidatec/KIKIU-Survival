extends "res://testes/isolamento_v2.gd"
# Teste automático dos heróis da v2 (v2/herois.gd, adagas.gd, personagens.gd, dados/v2_herois.json): Hazaki (padrão), Nick (marreta) e Luke
# (adagas). Usa um save TEMPORÁRIO (user://teste_v2_herois.cfg): o save real não é tocado. Confere: o JSON (3 heróis, folhas de sprites que
# existem, o Hazaki repetindo os números do v2_combate.json); a escolha (sem chave = Hazaki, grava e relê, id inválido ignorado, o resto do
# save intacto); cada herói criando a partida de verdade (vida, velocidade, tamanho, bônus, sprite); o Hazaki sem mudar; o Nick batendo em
# arco e depois em volta, empurrando para fora; o Luke jogando adagas em leque na direção do mouse, que acertam monstro da horda, elite e
# chefe, furam, somem, repetem segurando e não criam nó; o filtro das cartas por herói (e as cartas novas funcionando); e o santuário
# com a seleção (cartões, mouse, teclado, ESC e a escolha gravada); e o card SUA BUILD com o herói escolhido (nome, arma e os
# modificadores dele).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_herois.tscn  (imprime "v2_herois falhas=0")
# Prints (precisa de janela): ... res://testes/v2_herois.tscn -- --fotos=PASTA  grava cada herói golpeando e o card SUA BUILD dele.
const Mundo := preload("res://v2/mundo.tscn")
const Altar := preload("res://v2/altar.tscn")
const Personagens := preload("res://v2/personagens.gd")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Meta := preload("res://v2/meta.gd")
const Status := preload("res://v2/status.gd")  # o card SUA BUILD (tecla C)
const SAVE_TESTE := "user://testes_v2/v2_herois/teste_v2_herois.cfg"
const SAVE_REAL := "user://testes_v2/v2_herois/v2_progresso.cfg"
const INDICE_REAL := "user://testes_v2/v2_herois/v2_personagens.cfg"
const INDICE_TESTE := "user://testes_v2/v2_herois/teste_v2_herois_indice.cfg"
const PREFIXO_TESTE := "user://testes_v2/v2_herois/teste_v2_herois_p"
const ANTIGO_TESTE := "user://testes_v2/v2_herois/teste_v2_herois_antigo.cfg"
const PASSO := 1.0 / 60.0
const PASTA_SPRITES := "res://prototipos/cara_nova/sprites/"

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func ate(cond: Callable, max_passos: int) -> int:
	for i in max_passos:
		if cond.call():
			return i
		w.avancar(PASSO)
	return -1 if not cond.call() else max_passos


func _apagar_save() -> void:
	var alvos := [SAVE_TESTE, INDICE_TESTE]
	for i in range(1, 6):
		alvos.append(Personagens.caminho_do_save("p%d" % i))
		alvos.append(Personagens.caminho_do_save("p%d" % i) + ".bak")
	for c in alvos:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))


## Um mundo novo com o herói `id` (a escolha vai pelo save temporário, o mesmo caminho do santuário).
func novo(id: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = id  # o mesmo caminho do jogo, sem passar pelo salão (a escolha por personagem é testada em _t_escolha)
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true


## Mapa sem monstros, herói imortal e parado, sem diretor nem crítico (o dano fica previsível), mouse à direita.
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.heroi.m_critico = -1.0
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	passos(3)


func monstro_a(dx: float, dy := 0.0, nome := "inimigo_espantalho"):
	var m = w.nascer_monstro(nome, w.heroi.pos + Vector2(dx, dy))
	m.atordoa_t = 0.0
	return m


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	Personagens.caminho_indice = INDICE_TESTE
	Personagens.caminho_base = PREFIXO_TESTE
	Personagens.caminho_antigo = ANTIGO_TESTE
	var md5_indice := FileAccess.get_md5(INDICE_REAL) if FileAccess.file_exists(INDICE_REAL) else ""
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	var md5_real := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	_apagar_save()
	if pasta != "":
		await _fotos(pasta)
	else:
		await _testes()
		ok((FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else "") == md5_real, "o save real da v2 não foi tocado")
		ok((FileAccess.get_md5(INDICE_REAL) if FileAccess.file_exists(INDICE_REAL) else "") == md5_indice, "o índice real de personagens não foi tocado")
	_apagar_save()
	Herois.forcado = ""
	if pasta == "":
		print("v2_herois falhas=%d" % falhas)
	get_tree().quit()


func _testes() -> void:
	_t_dados()
	_t_escolha()
	await _t_hazaki()
	await _t_matheus()
	await _t_nicao()
	await _t_lucas()
	await _t_cartas()
	await _t_card()
	await _t_altar()


# ------------------------------------------------------------------ dados e escolha


func _t_dados() -> void:
	var cat := Herois.catalogo()
	var ids := []
	for h in Herois.lista():
		ids.append(str(h.id))
		for k in ["id", "nome", "titulo", "arma", "desc", "sprite", "raio", "bonus", "cfg"]:
			ok(h.has(k), "%s tem o campo %s" % [h.id, k])
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PASTA_SPRITES + str(h.sprite) + ".json"))
		ok(
			info != null and info.linhas.size() == 8 and info.colunas.size() >= 5 and info.quadro.size() == 2,
			"%s: o json da folha tem quadro, 8 linhas e pelo menos 5 colunas (parado + andar)" % h.id
		)
		ok(
			ResourceLoader.exists(PASTA_SPRITES + str(h.sprite) + "_albedo.png") and ResourceLoader.exists(PASTA_SPRITES + str(h.sprite) + "_normal.png"),
			"%s: albedo e normal existem" % h.id
		)
		var ps: Array = h.cfg.golpe.passos
		ok(ps.size() >= 1, "%s tem passos de golpe" % h.id)
	ok(ids == ["hazaki", "nicao", "lucas"], "3 heróis na ordem hazaki, nicao, lucas (%s)" % str(ids))
	ok(str(cat.get("_ajuda", "")) != "", "v2_herois.json tem _ajuda")
	# o Hazaki repete v2_combate.json: nada muda para ele
	var base := Dados.json("v2_combate")
	var hz := Herois.cfg_para(base, "hazaki")
	ok(JSON.stringify(hz.golpe) == JSON.stringify(base.golpe), "Hazaki: o combo é igual ao do v2_combate.json")
	ok(
		(
			float(hz.heroi.vida) == float(base.heroi.vida)
			and float(hz.heroi.mov_golpe) == float(base.heroi.mov_golpe)
			and float(hz.folego.max) == float(base.folego.max)
		),
		"Hazaki: vida, mov_golpe e fôlego iguais ao v2_combate.json"
	)
	ok(float(hz.heroi.vel) == 100.0, "Hazaki: anda a 100 px/s, como sempre")
	ok(hz.esquiva == base.esquiva and hz.corrida == base.corrida and hz.contato == base.contato, "Hazaki: esquiva, corrida e contato intactos")
	ok(not base.heroi.has("vel"), "cfg_para copia: o v2_combate.json em cache não foi alterado")
	var nc := Herois.cfg_para(base, "nicao")
	ok(
		(
			float(nc.heroi.vida) == 180.0
			and nc.golpe.passos.size() == 2
			and float(nc.heroi.recuo_dano) == 70.0
			and float(nc.heroi.invencivel) == float(base.heroi.invencivel)
		),
		"Nick: cobre só o que muda e mantém o resto (invencivel)"
	)
	var num := Herois.numeros("lucas", base)
	ok(num.size() == 3 and num[0][0] == "VIDA" and num[0][1] == "70" and num[1][1] == "118", "números do cartão: vida e velocidade saem do cfg (%s)" % str(num))


func _t_escolha() -> void:
	ok(not FileAccess.file_exists(INDICE_TESTE) and Herois.escolhido() == "hazaki", "sem personagem: o herói é o Hazaki")
	# o herói é do personagem (dados/v2_salao.json > nomes > heroi), escolhido ao criá-lo no salão
	ok(Personagens.heroi_do_nome("Nick") == "nicao" and Personagens.heroi_do_nome("Luke") == "lucas", "Nick e Luke jogam com o herói deles")
	ok(
		Personagens.heroi_do_nome("Breno") == "hazaki" and Personagens.heroi_do_nome("Fábio") == "hazaki" and Personagens.heroi_do_nome("Ninguém") == "hazaki",
		"os outros nomes (e um nome fora da lista) jogam de Hazaki"
	)
	ok(
		Personagens.arma_inicial("hazaki") == "Katana" and Personagens.arma_inicial("nicao") != "" and Personagens.arma_inicial("lucas") != "",
		"a arma inicial vem do herói"
	)
	var id_h := Personagens.criar("Breno", Personagens.heroi_do_nome("Breno"))
	var id_n := Personagens.criar("Nick", Personagens.heroi_do_nome("Nick"))
	var id_l := Personagens.criar("Luke", Personagens.heroi_do_nome("Luke"))
	ok(
		Personagens.heroi(id_h) == "hazaki" and Personagens.heroi(id_n) == "nicao" and Personagens.heroi(id_l) == "lucas",
		"o índice guarda o herói de cada personagem"
	)
	ok(Personagens.ativar(id_n) and Herois.escolhido() == "nicao", "ativar o personagem do Nick faz o herói da partida ser o Nick")
	ok(Personagens.ativar(id_l) and Herois.escolhido() == "lucas", "e o do Luke, o Luke")
	ok(Personagens.ativar(id_h) and Herois.escolhido() == "hazaki", "e o do Breno, o Hazaki")
	ok(Personagens.resumo(id_n).heroi == "nicao", "o resumo do personagem traz o herói")
	var id_x := Personagens.criar("Beto", "sumiu")  # herói removido dos dados: cai no Hazaki
	ok(Personagens.ativar(id_x) and Herois.escolhido() == "hazaki", "id de herói inválido no índice cai no Hazaki")
	Personagens.ativar(id_l)
	Herois.forcado = "nicao"
	ok(Herois.escolhido() == "nicao", "forcado vale por cima do personagem (testes e fotos)")
	Herois.forcado = ""
	ok(Herois.escolhido() == "lucas", "sem forcado volta ao herói do personagem")
	# o save de cada personagem é separado: melhoria de um não aparece no outro
	Meta.creditar(300)
	ok(
		Meta.comprar("vida") and Personagens.niveis(id_l).get("vida", 0) == 1 and Personagens.niveis(id_n).get("vida", 0) == 0,
		"comprar melhoria vale só para o personagem ativo"
	)
	# a escolha de herói do salão é a única: não há mais seleção separada no santuário
	ok(not ResourceLoader.exists("res://v2/selecao_heroi.gd"), "uma só escolha de herói: a do salão (personagens)")
	Meta.caminho_save = SAVE_TESTE
	_apagar_save()


# ------------------------------------------------------------------ Hazaki (padrão, sem mudar)


func _t_hazaki() -> void:
	_apagar_save()  # sem as melhorias que o teste da escolha gravou: os números são os de base
	await novo("hazaki")
	var h = w.heroi
	var c: Dictionary = w.combate.cfg
	ok(w.combate.heroi_id == "hazaki" and h.chave == "hazaki", "a partida do Hazaki: heroi_id e chave")
	ok(h.vida_max == 100.0 and h.vel_base == 100.0 and h.raio == 6.0 and h.m_area == 1.0 and h.m_dano == 1.0, "Hazaki: vida 100, 100 px/s, raio 6, sem bônus")
	ok(h.tipo.w == 32 and h.tipo.h == 44, "Hazaki: folha de 32x44 (a samurai de antes)")
	ok(
		c.golpe.passos.size() == 3 and c.golpe.passos[2].nome == "estocada" and float(c.golpe.passos[0].dano) == 12.0,
		"Hazaki: combo de 3 com os números de sempre"
	)
	zerar()
	var m = monstro_a(40)
	h.atacar()
	var n := ate(func(): return h.golpe_acertou, 60)
	ok(n >= 0, "Hazaki golpeia")
	ok(m.vida < m.vida_max and m.vida >= m.vida_max - 14.0 * 1.2 - 0.01, "Hazaki: o primeiro corte tira ~12 (vida %d de %d)" % [m.vida, m.vida_max])
	ok(w.combate.adagas.lancadas == 0, "Hazaki não joga adaga")
	_t_animacoes("Hazaki")


## A folha por personagem (campo "sprite" de dados/v2_salao.json): o Matthew joga de Hazaki mas com a folha dele; o Breno (sem sprite) segue com a do Hazaki.
func _t_matheus() -> void:
	ok(Personagens.sprite_do_nome("Matthew") == "matheus", "o Matthew tem folha própria (campo sprite)")
	ok(
		Personagens.sprite_do_nome("Breno") == "" and Personagens.sprite_do_nome("Nick") == "" and Personagens.sprite_do_nome("Ninguém") == "",
		"quem não tem sprite fica sem folha própria"
	)
	var mat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PASTA_SPRITES + "matheus.json"))
	var haz: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PASTA_SPRITES + "hazaki_samurai.json"))
	ok(
		mat.quadro == haz.quadro and mat.linhas == haz.linhas and mat.colunas == haz.colunas and mat.pe_y == haz.pe_y,
		"a folha do Matthew tem o formato da do Hazaki (quadro, linhas, colunas, pé)"
	)
	ok(mat.animacoes.keys() == haz.animacoes.keys() and mat.grade == haz.grade, "e as mesmas animações e a mesma grade")
	var colunas_iguais := true
	for anim in haz.animacoes:  # E (ruptura), Q (estocada = passo 2 do combo), rolamento, escudo, dano e morte tocam estas colunas: a folha nova as tem nos mesmos lugares
		colunas_iguais = colunas_iguais and mat.animacoes[anim].colunas == haz.animacoes[anim].colunas
	ok(
		colunas_iguais and mat.animacoes.combo.golpes == 3 and mat.animacoes.combo.quadros_por_golpe == 6,
		"as colunas de cada animação (combo, rolamento, escudo, dano, morte) são as do Hazaki"
	)
	ok(
		ResourceLoader.exists(PASTA_SPRITES + "matheus_albedo.png") and ResourceLoader.exists(PASTA_SPRITES + "matheus_normal.png"),
		"as imagens da folha do Matthew existem"
	)
	var id_h := Personagens.criar("Breno", Personagens.heroi_do_nome("Breno"))
	var id_m := Personagens.criar("Matthew", Personagens.heroi_do_nome("Matthew"))
	ok(
		Personagens.heroi(id_m) == "hazaki" and Personagens.sprite(id_m) == "matheus" and Personagens.sprite(id_h) == "",
		"o Matthew joga de Hazaki, com a folha dele"
	)
	ok(Personagens.ativar(id_m) and Herois.sprite_da_partida("hazaki") == "matheus", "partida do Matthew: a folha é a dele")
	ok(
		Herois.sprite_da_partida("hazaki", true) == "hazaki" and Herois.sprite_da_partida("nicao") == "nicao",
		"--basico e outro herói forçado ficam com a folha do herói"
	)
	await novo("hazaki")
	var h = w.heroi
	var tm = w.sprites.tipo("matheus")
	ok(h.tipo.alb == tm.alb and h.chave == "hazaki" and h.vida_max == 100.0, "o herói da partida do Matthew usa a folha dele, com as regras do Hazaki")
	var retrato: TextureRect = null
	for n in w.ui.get_children():
		if n.has_node("Raiz/Retrato/Heroi"):
			retrato = n.get_node("Raiz/Retrato/Heroi")
	ok(
		retrato != null and retrato.texture is AtlasTexture and retrato.texture.atlas.resource_path == PASTA_SPRITES + "matheus_albedo.png",
		"o retrato do HUD na partida do Matthew é o quadro parado da folha dele"
	)
	if retrato != null:  # como os outros três: dentro da moldura de 90x108, centrado e em escala inteira
		var caixa := retrato.get_parent() as Control
		var rect := Rect2(retrato.position, retrato.size)
		var k := retrato.size.x / float(mat.quadro[0])
		ok(Rect2(Vector2.ZERO, caixa.size).encloses(rect), "retrato do Matthew cabe na moldura (%s em %s)" % [rect, caixa.size])
		ok(k >= 1.0 and k == floorf(k), "retrato do Matthew em escala inteira (%sx)" % k)
		ok(
			absf(rect.get_center().x - caixa.size.x / 2.0) <= 1.0 and absf(rect.get_center().y - caixa.size.y / 2.0) <= 1.0,
			"retrato do Matthew centrado na moldura (%s)" % rect.get_center()
		)
	var c := 0
	for y in mat.quadro[1]:
		for x in mat.quadro[0]:
			c += 1 if h.tipo.alb.get_image().get_pixel(x, y).a > 0.5 else 0
	ok(c > 200, "a folha do Matthew tem o corpo desenhado no quadro parado (%d px)" % c)
	_t_animacoes("Matthew")
	ok(Personagens.ativar(id_h) and Herois.sprite_da_partida("hazaki") == "hazaki_samurai", "partida do Breno: continua com a folha do Hazaki")
	await novo("hazaki")
	ok(w.heroi.tipo.alb == w.sprites.tipo("hazaki_samurai").alb and w.heroi.tipo.alb != tm.alb, "o herói do Breno usa a folha do Hazaki")
	Meta.caminho_save = SAVE_TESTE
	_apagar_save()
	var hud_base: String = Herois.sprite_da_partida(Herois.escolhido())
	ok(hud_base == "hazaki_samurai", "o retrato da partida do Breno é o do Hazaki")


## Primeira e última coluna da animação `nome` na folha do herói da partida (o json de animações da folha do Blender).
func _cols(nome: String) -> Vector2i:
	var c: Array = w.heroi.tipo.info.animacoes[nome].colunas
	return Vector2i(int(c[0]), int(c[c.size() - 1]))


## As linhas da folha do Blender ligadas ao herói: combo, rolamento, escudo, dano e morte (sem girar o sprite). Vale para o Hazaki e o Luke: as colunas vêm do json.
func _t_animacoes(quem: String) -> void:
	var h = w.heroi
	var an: Dictionary = h.tipo.info.get("animacoes", {})
	ok(an.has("combo") and an.has("rolamento") and an.has("escudo") and an.has("dano") and an.has("morte"), "%s: a folha traz as animações de ação" % quem)
	var combo := _cols("combo")
	var por_golpe := int(an.combo.get("quadros_por_golpe", 6))
	var roll := _cols("rolamento")
	var esc := _cols("escudo")
	var dano := _cols("dano")
	var morte := _cols("morte")
	# parado: os 4 quadros da folha (colunas 0, 7, 8 e 9) tocam em ciclo; ao andar volta aos passos 1 a 6
	zerar()
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	var vistos := {}
	for i in 300:  # 5 s parado
		passos(1)
		vistos[h.coluna] = true
	ok(
		vistos.has(0) and vistos.has(7) and vistos.has(8) and vistos.has(9) and vistos.size() == 4,
		"%s: parado toca as colunas 0, 7, 8 e 9 (vistas %s)" % [quem, vistos.keys()]
	)
	# golpe
	zerar()
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	h.atacar()
	ate(func(): return h.estado == Heroi.Estado.GOLPE, 20)
	passos(2)
	ok(
		h.coluna >= combo.x and h.coluna < combo.x + por_golpe,
		"golpe 1: usa as colunas do combo %d-%d (coluna %d)" % [combo.x, combo.x + por_golpe - 1, h.coluna]
	)
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	# rolamento
	zerar()
	h.entrada_forcada = Vector2(1, 0)
	h.esquivar()
	ate(func(): return h.estado == Heroi.Estado.ESQUIVA, 20)
	passos(3)
	ok(h.coluna >= roll.x and h.coluna <= roll.y, "esquiva: usa as colunas do rolamento %d-%d (coluna %d)" % [roll.x, roll.y, h.coluna])
	ok(is_zero_approx(h.sprite.rotation), "esquiva: o sprite não gira (o rolamento é da folha)")
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	# escudo
	zerar()
	h.escudo_forcado = true
	passos(30)
	ok(h.escudo_ativo and h.coluna >= esc.x and h.coluna <= esc.y, "escudo: usa as colunas %d-%d (coluna %d)" % [esc.x, esc.y, h.coluna])
	h.escudo_forcado = null
	passos(5)
	# dano
	zerar()
	h.imortal = false
	h.invenc = 0.0
	h.levar_dano(1.0, h.pos + Vector2(30, 0))
	ate(func(): return h.coluna >= dano.x and h.coluna <= dano.y, 60)
	ok(h.coluna >= dano.x and h.coluna <= dano.y, "dano: usa as colunas %d-%d (coluna %d)" % [dano.x, dano.y, h.coluna])
	ate(func(): return h.coluna < dano.x or h.coluna > dano.y, 600)
	ok(h.coluna < dano.x or h.coluna > dano.y, "dano: a animação acaba e volta ao parado (coluna %d)" % h.coluna)
	# morte
	h.invenc = 0.0
	h.levar_dano(100000.0, h.pos + Vector2(30, 0))
	ate(func(): return h.coluna >= morte.x, 120)
	ok(h.estado == Heroi.Estado.MORTO and h.coluna >= morte.x and h.coluna <= morte.y, "morte: usa as colunas %d-%d (coluna %d)" % [morte.x, morte.y, h.coluna])
	ate(func(): return h.coluna == morte.y, 1200)
	ok(h.coluna == morte.y, "morte: trava no último quadro, deitado (coluna %d)" % h.coluna)
	ok(is_zero_approx(h.sprite.rotation), "morte: o sprite não gira 90 graus (rotação %.2f)" % h.sprite.rotation)


# ------------------------------------------------------------------ Nick


func _t_nicao() -> void:
	await novo("nicao")
	var h = w.heroi
	ok(w.combate.heroi_id == "nicao" and h.chave == "nicao", "a partida do Nick: heroi_id e chave")
	ok(h.vida_max == 180.0 and h.vida == 180.0, "Nick: 180 de vida (Meta.aplicar não voltou para 100)")
	ok(h.vel_base == 78.0 and h.raio == 8.0, "Nick: anda a 78 px/s e o corpo é maior (raio 8)")
	ok(absf(h.m_area - 1.2) < 0.001, "Nick: bônus de área 1,2 (%.2f)" % h.m_area)
	ok(
		h.tipo.w == 64 and h.tipo.h == 96 and h.tipo.has("alb") and h.sprite.texture != null,
		"Nick: folha própria do Blender, de quadro maior (64x96, a marreta passa da cabeça)"
	)
	ok(w.combate.cfg.golpe.passos.size() == 2 and w.combate.cfg.golpe.passos[1].nome == "pancada", "Nick: combo curto, batida e pancada no chão")
	w.reiniciar()
	ok(h.vida_max == 180.0 and absf(h.m_area - 1.2) < 0.001 and h.vel_base == 78.0, "jogar de novo: os números do Nick continuam (valores absolutos)")
	# anda mais devagar que o Hazaki
	zerar()
	h.entrada_forcada = Vector2(0, 1)
	passos(30)
	ok(absf(h.vel.length() - 78.0) < 8.0, "Nick anda a ~78 px/s (%.1f)" % h.vel.length())
	h.entrada_forcada = Vector2.ZERO
	passos(10)
	# batida em arco e pancada em volta
	zerar()
	var frente = monstro_a(40, 0, "inimigo_cavaleiro_oco")  # vida 96: aguenta a batida e a pancada sem morrer
	var atras = monstro_a(-38, 0, "inimigo_cavaleiro_oco")
	var dur0: float = float(w.combate.cfg.golpe.passos[0].duracao)
	ok(dur0 > 0.4, "a batida é lenta (%.2f s, a do Hazaki é 0,26)" % dur0)
	h.atacar()
	ok(ate(func(): return h.golpe_acertou, 80) >= 0 and h.golpe_cfg.nome == "batida", "1º golpe: batida")
	passos(2)
	ok(frente.vida < frente.vida_max, "a batida acerta quem está na frente")
	ok(atras.vida == atras.vida_max, "a batida não acerta quem está atrás (arco de 150 graus)")
	ok(frente.emp.x > 0.0, "a batida empurra para a frente (emp.x=%.0f)" % frente.emp.x)
	var emp_batida: float = frente.emp.length()
	ok(ate(func(): return h.estado == Heroi.Estado.LIVRE, 80) >= 0, "a batida termina")
	atras.vida = atras.vida_max
	frente.atordoa_t = 0.0
	var g1: int = h.golpes
	h.atacar()  # dentro da janela do combo: o 2º passo
	ok(ate(func(): return h.golpes > g1 and h.golpe_acertou, 80) >= 0 and h.golpe_cfg.nome == "pancada", "2º golpe: pancada no chão")
	passos(2)
	ok(atras.vida < atras.vida_max, "a pancada acerta em volta, inclusive atrás")
	ok(atras.emp.x < 0.0, "a pancada empurra para FORA (atrás vai para trás, emp.x=%.0f)" % atras.emp.x)
	ok(atras.emp.length() > emp_batida * 0.9, "a pancada empurra forte (%.0f contra %.0f da batida)" % [atras.emp.length(), emp_batida])
	# o empurrão leva o monstro para longe de verdade
	var d0: float = atras.pos.distance_to(h.pos)
	passos(20)
	ok(atras.pos.distance_to(h.pos) > d0 + 10.0, "o monstro de trás foi mesmo empurrado (%.0f -> %.0f px)" % [d0, atras.pos.distance_to(h.pos)])
	# cartas do Nick
	var cs = w.combate.cartas
	cs.aplicar(cs.montar_carta(cs.definicao("muralha"), 0))
	ok(float(w.combate.armas.mods.muralha) == 25.0, "carta Peso de muralha liga o modificador")
	cs.aplicar(cs.montar_carta(cs.definicao("abalo"), 0))
	ok(float(w.combate.armas.mods.abalo) == 45.0, "carta Abalo sísmico liga o modificador")
	zerar()  # limpa_partida zera os modificadores: refaz
	cs.aplicar(cs.montar_carta(cs.definicao("abalo"), 0))
	cs.aplicar(cs.montar_carta(cs.definicao("muralha"), 0))
	var alvo = monstro_a(40, 0, "inimigo_cavaleiro_oco")
	var gA: int = h.golpes
	h.atacar()
	ate(func(): return h.golpes > gA and h.golpe_acertou, 80)
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 80)
	var l0: int = w.combate.armas.lancadas
	var g2: int = h.golpes
	h.atacar()
	ate(func(): return h.golpes > g2 and h.golpe_acertou, 80)
	passos(2)
	ok(w.combate.armas.lancadas > l0, "com o Abalo, a pancada solta uma onda de choque (lançadas %d -> %d)" % [l0, w.combate.armas.lancadas])
	ok(alvo.vida < alvo.vida_max, "o alvo apanhou")
	_t_nicao_animacoes()


## As animações do Nick feitas no Blender (folha de 38 colunas, quadro 64x96) ligadas ao herói: combo de 2 golpes (batida e pancada), rolamento,
## defesa, dano e morte. As colunas vêm do JSON da folha (`animacoes`), então o teste vale para qualquer reordenação da folha.
func _t_nicao_animacoes() -> void:
	var h = w.heroi
	var an: Dictionary = h.tipo.info.get("animacoes", {})
	ok(an.has("combo") and an.has("rolamento") and an.has("escudo") and an.has("dano") and an.has("morte"), "Nick: a folha traz as animações de ação")
	ok(int(an.combo.golpes) == 2 and int(an.combo.quadros_por_golpe) == 6 and (an.combo.colunas as Array).size() == 12, "Nick: combo de 2 golpes x 6 quadros")
	ok(h.tipo.info.colunas.size() == 7 and h.tipo.info.has("pe_y"), "Nick: 'colunas' é só o andar (parado + 6) e a folha tem pe_y")
	var cc: Array = an.combo.colunas
	var cr: Array = an.rolamento.colunas
	var ce: Array = an.escudo.colunas
	var cd: Array = an.dano.colunas
	var cm: Array = an.morte.colunas
	# batida: colunas do golpe 1
	zerar()
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	h.atacar()
	ate(func(): return h.estado == Heroi.Estado.GOLPE, 20)
	passos(2)
	ok(h.coluna >= int(cc[0]) and h.coluna <= int(cc[5]), "batida: usa as colunas do golpe 1 (%d a %d; coluna %d)" % [int(cc[0]), int(cc[5]), h.coluna])
	# o impacto (acerto_em) cai no quadro 3 do golpe, o da marreta batendo
	ate(func(): return h.golpe_acertou, 80)
	ok(h.coluna == int(cc[3]), "batida: o dano sai no quadro de IMPACTO (coluna %d, impacto %d)" % [h.coluna, int(cc[3])])
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	# pancada: golpe 2 (colunas 6 a 11 do combo)
	h.atacar()
	ate(func(): return h.estado == Heroi.Estado.GOLPE, 20)
	passos(2)
	ok(
		h.golpe_cfg.nome == "pancada" and h.coluna >= int(cc[6]) and h.coluna <= int(cc[11]),
		"pancada: usa as colunas do golpe 2 (%d a %d; coluna %d)" % [int(cc[6]), int(cc[11]), h.coluna]
	)
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	# rolamento
	zerar()
	h.entrada_forcada = Vector2(1, 0)
	h.esquivar()
	ate(func(): return h.estado == Heroi.Estado.ESQUIVA, 20)
	passos(3)
	ok(h.coluna >= int(cr[0]) and h.coluna <= int(cr[5]), "esquiva: usa as colunas do rolamento (coluna %d)" % h.coluna)
	ok(is_zero_approx(h.sprite.rotation), "esquiva: o sprite não gira (o rolamento é da folha)")
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	# defesa
	zerar()
	h.escudo_forcado = true
	passos(30)
	ok(h.escudo_ativo and h.coluna >= int(ce[0]) and h.coluna <= int(ce[1]), "defesa: usa as 2 colunas da guarda (coluna %d)" % h.coluna)
	ok(h.coluna == int(ce[1]), "defesa: segurando, fica no quadro da guarda (coluna %d)" % h.coluna)
	h.escudo_forcado = null
	passos(5)
	# dano
	zerar()
	h.imortal = false
	h.invenc = 0.0
	h.levar_dano(1.0, h.pos + Vector2(30, 0))
	ate(func(): return h.coluna >= int(cd[0]) and h.coluna <= int(cd[1]), 60)
	ok(h.coluna >= int(cd[0]) and h.coluna <= int(cd[1]), "dano: usa as colunas do dano (coluna %d)" % h.coluna)
	ate(func(): return h.coluna < int(cd[0]) or h.coluna > int(cd[1]), 600)
	ok(h.coluna < int(cd[0]) or h.coluna > int(cd[1]), "dano: a animação acaba e volta ao parado (coluna %d)" % h.coluna)
	# morte: cai de lado e trava no último quadro
	h.invenc = 0.0
	h.levar_dano(100000.0, h.pos + Vector2(30, 0))
	ate(func(): return h.coluna >= int(cm[0]), 120)
	ok(h.estado == Heroi.Estado.MORTO and h.coluna >= int(cm[0]) and h.coluna <= int(cm[5]), "morte: usa as colunas da morte (coluna %d)" % h.coluna)
	ate(func(): return h.coluna == int(cm[5]), 1200)
	ok(h.coluna == int(cm[5]), "morte: trava no último quadro, deitado (coluna %d)" % h.coluna)
	ok(is_zero_approx(h.sprite.rotation), "morte: o sprite não gira 90 graus (rotação %.2f)" % h.sprite.rotation)
	_t_nicao_e_q(cc, ce)
	w.reiniciar()


## E (investida) e Q (terremoto) do Nick com quadros coerentes da folha: a E segura a guarda (marreta de través) e fecha na pancada até o impacto;
## o Q toca a pancada inteira (antecipação, impacto no `golpe` do terremoto, volta). Sem pose própria: reaproveitam a defesa e o combo.
func _t_nicao_e_q(cc: Array, ce: Array) -> void:
	var h = w.heroi
	zerar()
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	ok(h.habilidade(), "E: a investida dispara")
	var ce_i := ce.map(func(x): return int(x))
	var vistas := []
	for i in 40:
		passos(1)
		if h.estado != Heroi.Estado.HABILIDADE:
			break
		if vistas.is_empty() or vistas[vistas.size() - 1] != h.coluna:
			vistas.append(h.coluna)
	ok(vistas.size() >= 3 and int(vistas[0]) == int(ce[0]), "E: começa na guarda do escudo (colunas %s)" % [vistas])
	var fim := int(vistas[vistas.size() - 1])
	ok(fim == int(cc[9]), "E: termina no quadro de impacto da pancada (coluna %d, impacto %d)" % [fim, int(cc[9])])
	for c in vistas:
		ok(ce_i.has(int(c)) or (int(c) >= int(cc[6]) and int(c) <= int(cc[11])), "E: só usa colunas da guarda e da pancada (coluna %d)" % int(c))
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 60)
	zerar()
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	h.esp_carga = h.esp_carga_max
	ok(h.especial(), "Q: o terremoto dispara")
	var q := []
	for i in 120:
		passos(1)
		if h.estado != Heroi.Estado.ESPECIAL:
			break
		if q.is_empty() or q[q.size() - 1] != h.coluna:
			q.append(h.coluna)
	ok(q.size() == 6 and int(q[0]) == int(cc[6]) and int(q[5]) == int(cc[11]), "Q: toca os 6 quadros da pancada (colunas %s)" % [q])
	var tempo: float = float(w.combate.especial.blocos.terremoto.golpe)
	var dur: float = float(w.combate.especial.blocos.terremoto.dur)
	ok(tempo >= dur * 3.0 / 6.0 and tempo < dur * 4.0 / 6.0, "Q: o quadro de impacto da pancada cobre o instante do golpe (%.2f s de %.2f s)" % [tempo, dur])


# ------------------------------------------------------------------ Luke


func _t_lucas() -> void:
	await novo("lucas")
	var h = w.heroi
	var ad = w.combate.adagas
	ok(w.combate.heroi_id == "lucas" and h.chave == "lucas", "a partida do Luke: heroi_id e chave")
	ok(h.vida_max == 70.0 and h.vel_base == 118.0 and h.raio == 5.0, "Luke: frágil (70), rápido (118 px/s), pequeno (raio 5)")
	ok(h.tipo.w == 32 and h.tipo.h == 44, "Luke: folha própria (a do Blender, 32x44)")
	ok(float(w.meta_bonus.raridade) >= 0.15 - 0.0001, "Luke: sorte nas cartas (meta_bonus.raridade %.2f)" % float(w.meta_bonus.raridade))
	ok(w.combate.cfg.golpe.passos.size() == 3 and str(w.combate.cfg.golpe.passos[0].tipo) == "adagas", "Luke: combo de 3 arremessos de adagas")
	w.reiniciar()
	ok(float(w.meta_bonus.raridade) < 0.2, "jogar de novo não soma a sorte duas vezes (%.2f)" % float(w.meta_bonus.raridade))
	zerar()
	h.entrada_forcada = Vector2(0, 1)
	passos(30)
	ok(absf(h.vel.length() - 118.0) < 10.0, "Luke anda a ~118 px/s (%.1f)" % h.vel.length())
	h.entrada_forcada = Vector2.ZERO
	# o arremesso: leque na direção do mouse
	zerar()
	var nos0: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	w.mouse_forcado = h.centro() + Vector2(-70, -70)
	h.atacar()
	ok(ate(func(): return ad.lancadas >= 2, 60) >= 0, "o arremesso solta adagas (lançadas=%d)" % ad.lancadas)
	var esperado := Vector2(-1, -1).normalized()
	var dentro := 0
	for i in ad.MAX:
		if ad.a_rest[i] > 0.0 and (ad.a_dir[i] as Vector2).dot(esperado) > 0.97:
			dentro += 1
	ok(dentro == 2, "as 2 adagas do 1º arremesso saem na direção do mouse (cima-esquerda): %d" % dentro)
	ok(ate(func(): return ad.ativas() == 0, 200) >= 0, "as adagas somem sozinhas (alcance)")
	ok(ad.sumiram == ad.lancadas, "toda adaga que saiu acabou (%d de %d)" % [ad.sumiram, ad.lancadas])
	ok(
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= nos0,
		"arremessar e sumir não cria nó (%d -> %d)" % [nos0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
	)
	# acerta o monstro da horda, fura, empurra e mata
	zerar()
	var m1 = monstro_a(80, 0, "inimigo_cao_ossos")
	var m2 = monstro_a(130, 0, "inimigo_cao_ossos")
	var v1: float = m1.vida
	h.atacar()
	ate(func(): return ad.lancadas >= 2, 60)
	ate(func(): return ad.acertos >= 1, 60)
	passos(3)
	ok(m1.vida < v1 or not m1.vivo, "a adaga acerta o monstro da horda (vida %d de %d)" % [m1.vida, v1])
	ok(m1.emp.x > 0.0 or not m1.vivo, "e o empurra para longe do herói")
	ate(func(): return ad.ativas() == 0, 120)
	ok(ad.acertos >= 2 and (m2.vida < m2.vida_max or not m2.vivo), "furar: a mesma adaga atravessa e acerta o de trás também (acertos=%d)" % ad.acertos)
	# acerta elite e chefe
	zerar()
	var el = w.combate.elites.nascer("inimigo_cao_ossos", "blindado", h.pos + Vector2(110, 0))
	var vida_el: float = el.vida
	h.atacar()
	ate(func(): return ad.acertos >= 1, 120)
	passos(4)
	ok(el.vida < vida_el, "a adaga acerta a elite (vida %d de %d)" % [el.vida, vida_el])
	zerar()
	var ch = w.combate.chefes.nascer(w.combate.cartas.cfg.chefes.marcas[0], h.pos + Vector2(120, 0))
	var vida_ch: float = ch.vida
	h.atacar()
	ate(func(): return ad.acertos >= 1, 120)
	passos(4)
	ok(ch.vida < vida_ch, "a adaga acerta o chefe (vida %d de %d)" % [ch.vida, vida_ch])
	# segurar repete
	zerar()
	var gs0: int = h.golpes
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = true
	passos(120)
	h.ataque_forcado = false
	ok(h.golpes - gs0 >= 5, "segurar o botão repete os arremessos (%d em 2 s)" % (h.golpes - gs0))
	ok(ad.lancadas >= 10, "adagas em quantidade (%d); o pool segura (<= %d voando)" % [ad.lancadas, ad.MAX])
	ok(ad.ativas() <= ad.MAX, "nunca passa do pool")
	# o terceiro arremesso é o leque de 5
	zerar()
	var g0: int = h.golpes
	h.atacar()
	ate(func(): return h.golpes >= g0 + 1 and h.estado == Heroi.Estado.LIVRE, 60)
	h.atacar()
	ate(func(): return h.golpes >= g0 + 2 and h.estado == Heroi.Estado.LIVRE, 60)
	var l0: int = ad.lancadas
	h.atacar()
	ate(func(): return h.golpes >= g0 + 3 and h.golpe_acertou, 80)
	ok(ad.lancadas - l0 == 5, "o 3º arremesso é o leque de 5 adagas (%d)" % (ad.lancadas - l0))
	# modificadores do Luke
	zerar()
	var cs = w.combate.cartas
	cs.aplicar(cs.montar_carta(cs.definicao("mira"), 0))
	ok(float(w.combate.armas.mods.mira) == 15.0, "carta Mira longa liga o modificador")
	h.atacar()
	ate(func(): return ad.lancadas >= 2, 60)
	var rest_max := 0.0
	for i in ad.MAX:
		rest_max = maxf(rest_max, ad.a_rest[i])
	ok(rest_max > 220.0, "com a Mira longa a adaga voa mais longe (%.0f px)" % rest_max)
	zerar()
	cs.aplicar(cs.montar_carta(cs.definicao("chuva"), 3))  # lendária: 15 x 3,2 = 48%
	w.combate.armas.mods.chuva = 100.0
	monstro_a(70, 0, "inimigo_cavaleiro_oco")
	h.atacar()
	ate(func(): return ad.lancadas >= 2, 60)
	var l1: int = ad.lancadas
	ate(func(): return ad.acertos >= 1, 60)
	passos(2)
	ok(ad.lancadas > l1, "com a Chuva de adagas um acerto solta outra adaga (%d -> %d)" % [l1, ad.lancadas])
	w.combate.armas.mods.chuva = 0.0
	# limpar a partida tira as adagas do ar
	w.combate.limpar_partida()
	ok(ad.ativas() == 0 and ad.lancadas == 0, "limpar a partida zera as adagas")
	_t_animacoes("Luke")
	ok(
		int(h.tipo.info.animacoes.combo.get("golpes", 0)) == 3 and int(h.tipo.info.animacoes.combo.get("quadros_por_golpe", 0)) == 4,
		"Luke: o combo da folha tem 3 arremessos de 4 quadros"
	)


# ------------------------------------------------------------------ cartas


func _t_cartas() -> void:
	var quer := {
		"hazaki": {"sim": ["onda", "fura", "explode", "folego", "dano", "area"], "nao": ["abalo", "muralha", "chuva", "mira"]},
		"nicao": {"sim": ["abalo", "muralha", "explode", "folego", "dano", "area"], "nao": ["onda", "fura", "chuva", "mira"]},
		"lucas": {"sim": ["chuva", "mira", "explode", "folego", "dano", "area"], "nao": ["onda", "fura", "abalo", "muralha"]},
	}
	for id in quer:
		await novo(id)
		var ids := []
		for d in w.combate.cartas.disponiveis():
			ids.append(str(d.id))
		for c in quer[id].sim:
			ok(ids.has(c), "%s: a carta %s pode sair" % [id, c])
		for c in quer[id].nao:
			ok(not ids.has(c), "%s: a carta %s NÃO pode sair" % [id, c])
		var vistas := {}
		for k in 120:
			for c in w.combate.cartas.sortear(3, 1 + k % 20):
				vistas[str(c.id)] = true
		for c in quer[id].nao:
			ok(not vistas.has(c), "%s: o sorteio nunca traz %s (120 sorteios)" % [id, c])
		var algum := false
		for c in quer[id].sim:
			algum = algum or vistas.has(c)
		ok(algum, "%s: o sorteio traz as cartas dele" % id)
		# o baú usa o mesmo sorteio
		ok(w.combate.cartas.sortear(1, 5, 3.0).size() == 1, "%s: o sorteio do baú funciona" % id)


# ------------------------------------------------------------------ card SUA BUILD


func _secao_card(secs: Array, id: String) -> Dictionary:
	for s in secs:
		if str(s.get("id", "")) == id:
			return s
	return {}


## O card SUA BUILD mostra o herói ESCOLHIDO: o nome na seção HERÓI, a arma na seção de golpe, os números dele e os modificadores
## dele (e só os dele). O número de cada modificador é o que o jogo usa (armas.mods).
func _t_card() -> void:
	var arma := {"hazaki": "KATANA (CLIQUE)", "nicao": "KANABO (CLIQUE)", "lucas": "KUNAI (CLIQUE)"}
	var mods := {"hazaki": ["onda", "fura"], "nicao": ["abalo", "muralha"], "lucas": ["chuva", "mira"]}
	for id in ["hazaki", "nicao", "lucas"]:
		await novo(id)
		zerar()
		var h = w.heroi
		var cfg_h: Dictionary = Herois.heroi(id).cfg
		var secs: Array = Status.coletar(w)
		var titulo_h := str(_secao_card(secs, "heroi").get("titulo", ""))
		ok(titulo_h == "HERÓI: " + str(Herois.heroi(id).nome).to_upper(), "%s: o card abre a seção HERÓI com o nome dele (%s)" % [id, titulo_h])
		var titulo_k := str(_secao_card(secs, "katana").get("titulo", ""))
		ok(titulo_k == arma[id], "%s: a seção de golpe leva a arma dele (%s)" % [id, titulo_k])
		var vida_card := str(Status.linha(secs, "heroi.vida").get("valor", ""))
		ok(
			vida_card == "%d / %d" % [roundi(h.vida), roundi(h.vida_max)] and roundi(h.vida_max) == roundi(float(cfg_h.heroi.vida)),
			"%s: a vida no card é a do herói (%s)" % [id, vida_card]
		)
		var andar_card := str(Status.linha(secs, "heroi.andar").get("valor", ""))
		ok(andar_card == "%d px/s" % roundi(float(cfg_h.heroi.vel)), "%s: o andar no card é a velocidade do herói (%s)" % [id, andar_card])
		ok(
			Status.linha(secs, "katana.dano").get("n", []).size() == cfg_h.golpe.passos.size(),
			"%s: a seção de golpe tem uma conta por passo do combo dele" % id
		)
		var cs = w.combate.cartas
		for md in mods[id]:
			cs.aplicar(cs.montar_carta(cs.definicao(md), 0))
		secs = Status.coletar(w)
		for md in mods[id]:
			var bl: Dictionary = Status.linha(secs, "katana." + md)
			ok(
				not bl.is_empty() and absf(float(bl.n[0]) - float(w.combate.armas.mods[md])) < 0.001,
				"%s: o card mostra o modificador %s com o número do jogo (%s)" % [id, md, str(bl.get("n", []))]
			)
		for outro in ["hazaki", "nicao", "lucas"]:
			if outro == id:
				continue
			for md in mods[outro]:
				ok(Status.linha(secs, "katana." + md).is_empty(), "%s: o card não mostra o modificador %s, que é de outro herói" % [id, md])


# ------------------------------------------------------------------ santuário


func _t_altar() -> void:
	if w != null:
		w.queue_free()
		w = null
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = "hazaki"
	var altar = Altar.instantiate()
	add_child(altar)
	await get_tree().process_frame
	# o santuário continua funcionando com qualquer herói: comprar melhoria, e o resultado
	Meta.creditar(500)
	altar._atualizar()
	var antes := Meta.nivel("vida")
	var saldo_antes := Meta.saldo()
	altar._comprar("vida")
	ok(Meta.nivel("vida") == antes + 1 and Meta.saldo() < saldo_antes, "comprar melhoria no santuário segue funcionando com herói escolhido")
	altar.queue_free()
	await get_tree().process_frame
	# Meta.aplicar com a melhoria comprada vale sobre a vida base do herói
	await novo("nicao")
	ok(
		w.heroi.vida_max == 180.0 + float(Meta.melhoria("vida").valor) * Meta.nivel("vida"),
		"Meta.aplicar soma a melhoria de vida à vida do Nick (%.0f)" % w.heroi.vida_max
	)
	await novo("lucas")
	ok(w.heroi.vida_max == 70.0 + float(Meta.melhoria("vida").valor) * Meta.nivel("vida"), "e à do Luke (%.0f)" % w.heroi.vida_max)
	zerar()
	var m = monstro_a(40)
	w.heroi.atacar()
	passos(40)
	w.combate.abandonar()  # resultado e almas funcionam com qualquer herói
	ok(w.combate.fim_emitido, "a partida do Luke termina e registra o resultado")


func _tecla(k: Key) -> void:
	for pressionada in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionada
		Input.parse_input_event(e)


# ------------------------------------------------------------------ prints


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto_janela(pasta: String, nome: String) -> void:
	await RenderingServer.frame_post_draw
	var c := pasta.path_join(nome + ".png")
	get_viewport().get_texture().get_image().save_png(c)
	print("FOTO ", c)


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	for id in ["hazaki", "nicao", "lucas"]:
		Herois.forcado = id
		w = Mundo.instantiate()
		w.modo_teste = false
		add_child(w)
		w.set_process(false)
		w.combate.audio.mudo = true
		await _quadros(3)
		await _golpes_foto(pasta, id)
		w.status.alternar()  # o card SUA BUILD (tecla C), ao lado da partida
		await _quadros(6)
		await _foto_janela(pasta, "card_%s" % id)
		w.status.alternar()
		if id == "hazaki" or id == "lucas":
			await _anim_fotos(pasta, id)
		w.queue_free()
		w = null
		await _quadros(3)


## Uma foto de cada animação de ação do herói do Blender (combo, rolamento, escudo, dano e morte), na partida de verdade.
func _anim_fotos(pasta: String, id: String) -> void:
	zerar()
	var h = w.heroi
	h.imortal = false
	h.atacar()
	ate(func(): return h.estado == Heroi.Estado.GOLPE, 20)
	passos(6)
	await RenderingServer.frame_post_draw
	await w.ap.foto(pasta.path_join("%s_anim_combo.png" % id))
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	h.entrada_forcada = Vector2(1, 0)
	h.esquivar()
	ate(func(): return h.estado == Heroi.Estado.ESQUIVA, 20)
	passos(10)
	await RenderingServer.frame_post_draw
	await w.ap.foto(pasta.path_join("%s_anim_rolamento.png" % id))
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	h.entrada_forcada = Vector2.ZERO
	h.escudo_forcado = true
	passos(30)
	await RenderingServer.frame_post_draw
	await w.ap.foto(pasta.path_join("%s_anim_escudo.png" % id))
	h.escudo_forcado = null
	passos(5)
	h.invenc = 0.0
	h.levar_dano(1.0, h.pos + Vector2(30, 0))
	var dano := _cols("dano")
	ate(func(): return h.coluna >= dano.x and h.coluna <= dano.y, 60)
	passos(2)
	await RenderingServer.frame_post_draw
	await w.ap.foto(pasta.path_join("%s_anim_dano.png" % id))
	h.invenc = 0.0
	h.levar_dano(100000.0, h.pos + Vector2(30, 0))
	var morte := _cols("morte")
	ate(func(): return h.coluna >= morte.y - 1, 1200)  # o quadro deitado antes do dissolve (no último a dissolução já começou)
	await RenderingServer.frame_post_draw
	await w.ap.foto(pasta.path_join("%s_anim_morte.png" % id))


func _golpes_foto(pasta: String, id: String) -> void:
	zerar()
	w.heroi.m_critico = 0.0
	var h = w.heroi
	var tipos := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_espantalho", "inimigo_lobo_sombrio"]
	var k := 0
	if id == "lucas":  # horda à frente, em fila e espalhada
		for fila in 4:
			for lado in 3:
				monstro_a(70.0 + fila * 38.0, (lado - 1) * 26.0 + (fila % 2) * 9.0, tipos[(fila + lado) % 4])
	else:  # em volta
		for a in 10:
			var ang := TAU * a / 10.0
			var r := 34.0 + 14.0 * (a % 3)
			monstro_a(cos(ang) * r, sin(ang) * r * 0.8, tipos[a % 4])
	passos(2)
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	h.atacar()
	var g0: int = h.golpes
	if id == "nicao":
		ate(func(): return h.golpe_acertou, 80)
		passos(6)
		await RenderingServer.frame_post_draw
		await w.ap.foto(pasta.path_join("%s_batida.png" % id))
		ate(func(): return h.estado == Heroi.Estado.LIVRE, 80)
		h.atacar()
		ate(func(): return h.golpes > g0 + 1 and h.golpe_acertou, 80)
		passos(5)
		await RenderingServer.frame_post_draw
		await w.ap.foto(pasta.path_join("%s_pancada.png" % id))
	elif id == "lucas":
		ate(func(): return h.golpes >= g0 + 1 and h.estado == Heroi.Estado.LIVRE, 60)
		h.atacar()
		ate(func(): return h.golpes >= g0 + 2 and h.estado == Heroi.Estado.LIVRE, 60)
		h.atacar()
		ate(func(): return h.golpe_acertou and h.golpes >= g0 + 3, 80)
		passos(10)
		await RenderingServer.frame_post_draw
		await w.ap.foto(pasta.path_join("%s_leque.png" % id))
	else:
		ate(func(): return h.golpe_acertou, 80)
		passos(4)
		await RenderingServer.frame_post_draw
		await w.ap.foto(pasta.path_join("%s_golpe.png" % id))
