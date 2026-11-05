extends "res://testes/isolamento_v2.gd"
# Teste do LW-1 (#511): o mecha do LightWolf jogável atrás do portão beta. Confere: o portão (escondido sem beta; liberado por --beta-tester,
# --heroi=lightwolf ou herói forçado; o nome só é oferecido a quem tem o herói), os dados (números do plano, folhas provisórias rotuladas,
# passos de tiro com custo_mult 0) e o tiro: a RAJADA dos canhões (pedido do Alisson: vários projéteis por braço, como a escopeta automática
# da D.Va; cada golpe solta `n` bolinhas em leque curto de um braço só, ~5 rajadas/s alternando as mãos), sem gastar fôlego mesmo no Difícil e
# mesmo com fôlego zerado; DPS no alvo único perto na faixa de antes (~50), menor longe (o leque abre e erra), dano na horda um pouco maior que o
# do canhão antigo de 1 bala; um número por rajada; pool com folga no pior caso (velocidade de ataque alta, nível no teto e a E junto); som de
# 1 em cada `som_cada` golpes.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_lightwolf.tscn  (imprime "v2_lightwolf falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Personagens := preload("res://v2/personagens.gd")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Meta := preload("res://v2/meta.gd")
const Progressao := preload("res://v2/progressao.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const SAVE_TESTE := "user://testes_v2/v2_lightwolf/teste_v2_lightwolf.cfg"
const INDICE_TESTE := "user://testes_v2/v2_lightwolf/teste_v2_lightwolf_indice.cfg"
const PREFIXO_TESTE := "user://testes_v2/v2_lightwolf/teste_v2_lightwolf_p"
const ANTIGO_TESTE := "user://testes_v2/v2_lightwolf/teste_v2_lightwolf_antigo.cfg"
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


func _apagar_save() -> void:
	var alvos := [SAVE_TESTE, INDICE_TESTE]
	for i in range(1, 6):
		alvos.append(Personagens.caminho_do_save("p%d" % i))
		alvos.append(Personagens.caminho_do_save("p%d" % i) + ".bak")
	for c in alvos:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))


func novo(id: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true


## Mapa sem monstros, herói imortal e parado, sem diretor nem crítico (o dano fica previsível), mouse à direita, Difícil (o fôlego gasta no golpe).
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.heroi.m_critico = -1.0
	w.meta_bonus["dificuldade"] = Dificuldade.regras("dificil")
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	passos(3)


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	Personagens.caminho_indice = INDICE_TESTE
	Personagens.caminho_base = PREFIXO_TESTE
	Personagens.caminho_antigo = ANTIGO_TESTE
	_apagar_save()
	await _testes()
	_apagar_save()
	Herois.forcado = ""
	Progressao.args_teste = null
	print("v2_lightwolf falhas=%d" % falhas)
	get_tree().quit()


func _testes() -> void:
	_t_portao()
	_t_dados()
	await _t_tiro()
	await _t_sem_folego()
	await _t_som()


# ------------------------------------------------------------------ portão beta e dados


func _t_portao() -> void:
	Herois.forcado = ""
	Progressao.args_teste = []
	var ids := Herois.lista().map(func(h): return str(h.id))
	ok(not ids.has("lightwolf") and not Herois.existe("lightwolf"), "sem beta o LightWolf não aparece na lista (%s)" % str(ids))
	ok(Herois.escolhido() != "lightwolf" and ids.size() >= 8, "sem beta ninguém joga de LightWolf e os outros heróis seguem (%d)" % ids.size())
	var livres: Array = Personagens.nomes_livres().map(func(n): return str(n.nome))
	ok(not livres.has("LightWolf") and livres.has("Brendan"), "sem beta o nome LightWolf não é oferecido na criação (%s)" % str(livres))
	ok(Personagens.heroi_do_nome("LightWolf") == "hazaki", "sem beta um save de LightWolf joga de Hazaki, sem quebrar")
	Progressao.args_teste = ["--beta-tester"]
	ok(Herois.existe("lightwolf") and Herois.lista().size() == ids.size() + 1, "com --beta-tester o LightWolf entra na lista")
	livres = Personagens.nomes_livres().map(func(n): return str(n.nome))
	ok(livres.has("LightWolf") and Personagens.heroi_do_nome("LightWolf") == "lightwolf", "com beta o nome é oferecido e vale o herói lightwolf")
	Progressao.args_teste = []
	ok(not Herois.existe("lightwolf"), "sem beta de novo, some de novo")
	Herois.forcado = "lightwolf"
	ok(Herois.existe("lightwolf") and Herois.escolhido() == "lightwolf", "herói forçado por teste ou foto passa pelo portão")
	Herois.forcado = ""
	Progressao.args_teste = null


func _t_dados() -> void:
	var h: Dictionary = {}
	for x in Herois.catalogo().herois:
		if str(x.id) == "lightwolf":
			h = x
	ok(not h.is_empty() and bool(h.get("beta", false)), "lightwolf está no catálogo com beta: true")
	if h.is_empty():
		return
	var c: Dictionary = h.cfg
	ok(int(c.heroi.vida) == 130 and int(c.heroi.vel) == 90 and int(c.heroi.recuo_dano) == 40 and int(h.raio) == 9, "mecha: vida 130, vel 90, recuo 40, raio 9")
	var ps: Array = c.golpe.passos
	ok(ps.size() == 2, "mecha: dois passos, mão esquerda e direita")
	var todos_tiro := true
	for p in ps:
		todos_tiro = todos_tiro and str(p.tipo) == "adagas" and str(p.proj) == "bala" and float(p.custo_mult) == 0.0 and int(p.get("perfura", 0)) == 0
	ok(todos_tiro, "mecha: todo passo é tiro de bala, não fura e não gasta fôlego")
	ok(float(ps[0].lateral) == -float(ps[1].lateral) and float(ps[0].lateral) != 0.0, "mecha: as duas mãos ficam em lados opostos")
	for p in ps:
		ok(int(p.n) >= 4 and int(p.n) <= 6, "mecha: rajada de 4 a 6 projéteis por braço (n = %d)" % int(p.n))
		ok(float(p.leque) >= 12.0 and float(p.leque) <= 20.0, "mecha: leque curto de 12 a 20 graus (%.0f)" % float(p.leque))
		ok(float(p.alcance) <= 220.0, "mecha: alcance curto, até o de antes (%.0f px)" % float(p.alcance))
		ok(bool(p.get("numero_rajada", false)), "mecha: um número por rajada (numero_rajada)")
		ok(int(p.get("som_cada", 1)) >= 2, "mecha: o som do disparo não toca a cada golpe")
		# o dano da bolinha passa por roundi no ferir: abaixo de 1,5 o arredondamento come o bônus de dano das cartas
		ok(float(p.dano) >= 1.5, "mecha: dano por projétil não some no arredondamento (%.1f)" % float(p.dano))
	var cic: float = (float(ps[0].duracao) + float(ps[1].duracao)) / 2.0
	ok(cic > 0.12 and cic < 0.2, "mecha: ~5 rajadas por segundo no papel (%.3f s de passo, mais o quadro de recomeço)" % cic)
	for nome in ["lightwolf_mecha", "lightwolf_lobo"]:
		var info = JSON.parse_string(FileAccess.get_file_as_string(PASTA_SPRITES + nome + ".json"))
		# As duas formas já têm folha final do Blender (LW-7).
		ok(info is Dictionary and not info.has("provisorio"), "%s: folha final, sem rótulo provisório" % nome)
		ok(
			ResourceLoader.exists(PASTA_SPRITES + nome + "_albedo.png") and ResourceLoader.exists(PASTA_SPRITES + nome + "_normal.png"),
			"%s: albedo e normal existem" % nome
		)
	var mecha = JSON.parse_string(FileAccess.get_file_as_string(PASTA_SPRITES + "lightwolf_mecha.json"))
	ok(int(mecha.quadro[0]) == 128 and int(mecha.quadro[1]) == 192, "mecha: quadro ampliado 128x192 sem cortar o rolamento (#587)")
	ok(int(mecha.pe_y) == 120, "mecha: pés ancorados na linha 120 do quadro ampliado")
	var lobo = JSON.parse_string(FileAccess.get_file_as_string(PASTA_SPRITES + "lightwolf_lobo.json"))
	ok(int(lobo.quadro[0]) == 32 and int(lobo.quadro[1]) == 44, "lobo: folha 32x44 como a do Luke")


# ------------------------------------------------------------------ o tiro


func _balas_em_voo() -> int:
	var n := 0
	for i in w.combate.adagas.MAX:
		if w.combate.adagas.a_rest[i] > 0.0:
			n += 1
	return n


## Segura o tiro `quadros` quadros com monstros parados (vida enorme) nas posições `alvos` (relativas aos pés), mirando no primeiro.
## Devolve golpes, projéteis lançados, dano por segundo, números mostrados, rajadas de cada mão e o fôlego antes e depois.
func _segurar(alvos: Array, quadros: int) -> Dictionary:
	zerar()
	var h = w.heroi
	var ms := []
	for a in alvos:
		var m = w.nascer_monstro("inimigo_espantalho", h.pos + a)
		m.vida = 100000.0
		m.vida_max = 100000.0
		ms.append(m)
	# a mira sai do centro do corpo; o mouse vai onde a linha da boca (ORIGEM_GOLPE) ao peito do primeiro alvo aponta, como quem mira nele
	w.mouse_forcado = h.centro() + (alvos[0] + Vector2(0, -6) - Heroi.ORIGEM_GOLPE)
	var r := {"fol0": h.folego, "max_voo": 0, "maos": [0, 0]}
	var golpes0: int = h.golpes
	var sons0: int = w.combate.tiros_som
	var lanc0: int = w.combate.adagas.lancadas
	var dano0: float = w.combate.dano_causado
	var num0: int = w.combate.fx.usados.numeros
	var golpe_ant: int = h.golpes
	h.ataque_forcado = true
	for i in quadros:
		w.avancar(PASSO)
		for k in ms.size():
			ms[k].atordoa_t = 0.0
			ms[k].pos = h.pos + alvos[k]
		r.max_voo = maxi(r.max_voo, _balas_em_voo())
		if h.golpes != golpe_ant:
			r.maos[h.golpe_i % 2] += 1
			golpe_ant = h.golpes
	h.ataque_forcado = false
	passos(40)  # as últimas bolinhas ainda estão a caminho
	r.golpes = h.golpes - golpes0
	r.tiros = w.combate.adagas.lancadas - lanc0
	r.dps = (w.combate.dano_causado - dano0) * 60.0 / float(quadros)
	r.numeros = w.combate.fx.usados.numeros - num0
	r.fol = h.folego
	r.sons = w.combate.tiros_som - sons0
	return r


func _t_tiro() -> void:
	await novo("lightwolf")
	zerar()
	var h = w.heroi
	ok(str(w.combate.heroi_id) == "lightwolf" and str(h.chave) == "lightwolf", "o mundo nasce com o LightWolf")
	ok(is_equal_approx(float(h.vida_max), 130.0) and float(w.combate.cfg.heroi.vel) == 90.0, "mundo: vida 130 e vel 90 vindos do cfg")
	ok(float(Dificuldade.da_partida(w).golpe_custo) > 0.0, "no Difícil o golpe comum gasta fôlego (o teste só vale assim)")
	var n := int(w.combate.cfg.golpe.passos[0].n)
	# alvo único perto (40 px: o mecha anda devagar e luta encostado na horda), 3 s segurando o botão
	var perto := _segurar([Vector2(40, 0)], 180)
	print(
		(
			"v2_lightwolf medido: perto golpes=%d tiros=%d dps=%.1f numeros=%d voo=%d maos=%s"
			% [perto.golpes, perto.tiros, perto.dps, perto.numeros, perto.max_voo, str(perto.maos)]
		)
	)
	ok(perto.golpes >= 13 and perto.golpes <= 18, "segurando 3 s saem ~15 rajadas (5/s), saíram %d" % perto.golpes)
	ok(perto.tiros == perto.golpes * n and n >= 4, "cada rajada solta %d projéteis (%d em %d rajadas)" % [n, perto.tiros, perto.golpes])
	ok(perto.sons == perto.golpes, "o contador de som conta cada golpe (%d/%d)" % [perto.sons, perto.golpes])
	ok(perto.maos[0] >= 6 and perto.maos[1] >= 6, "as rajadas alternam as duas mãos (%s)" % str(perto.maos))
	ok(
		is_equal_approx(float(perto.fol), float(perto.fol0)) and not h.cansado,
		"atirando sem parar o fôlego não se mexe (%.2f de %.2f)" % [perto.fol, perto.fol0]
	)
	ok(perto.dps >= 42.0 and perto.dps <= 60.0, "DPS no alvo único perto na faixa de antes, ~50 (%.1f)" % perto.dps)
	ok(
		perto.numeros >= perto.golpes - 2 and perto.numeros <= perto.golpes,
		"um número por rajada, não um por projétil (%d números, %d rajadas)" % [perto.numeros, perto.golpes]
	)
	ok(perto.max_voo >= n and perto.max_voo <= 4 * n, "poucas rajadas em voo ao mesmo tempo (maior vista: %d projéteis)" % perto.max_voo)
	# longe (150 px): o leque abriu e parte erra; a escopeta perde força longe
	var meio := _segurar([Vector2(80, 0)], 180)
	var longe := _segurar([Vector2(150, 0)], 180)
	print("v2_lightwolf medido: meio dps=%.1f longe dps=%.1f" % [meio.dps, longe.dps])
	ok(
		meio.dps <= perto.dps + 3.0 and meio.dps >= longe.dps - 3.0,
		"o DPS cai com a distância (perto, 80 px, 150 px: %.1f, %.1f, %.1f)" % [perto.dps, meio.dps, longe.dps]
	)
	ok(longe.dps > 5.0 and longe.dps <= perto.dps * 0.85, "longe o leque abre e o DPS cai (%.1f contra %.1f perto)" % [longe.dps, perto.dps])
	# horda: um bolo de monstros na frente pega as bolinhas que o alvo único deixaria passar
	var bolo := [Vector2(70, 0), Vector2(90, -14), Vector2(90, 14), Vector2(110, 0), Vector2(115, -26), Vector2(115, 26), Vector2(135, -12), Vector2(135, 12)]
	var horda := _segurar(bolo, 180)
	print("v2_lightwolf medido: horda dps=%.1f numeros=%d golpes=%d" % [horda.dps, horda.numeros, horda.golpes])
	# o canhão antigo (1 bala de 4,8 a ~10/s) dava ~48 de dano por segundo no total, na horda ou no alvo único
	ok(horda.dps >= 52.0 and horda.dps <= 75.0, "na horda o dano sobe um pouco sobre os ~48 do canhão antigo, sem disparar (%.1f)" % horda.dps)
	ok(horda.numeros <= horda.golpes, "na horda também um número por rajada (%d números, %d rajadas)" % [horda.numeros, horda.golpes])
	_t_pool()


## Pior caso do pool (adagas.MAX): velocidade de ataque no alto (5 cartas de +15% e o ÁPICE x1,5 dão ~2,1), nível no teto do alcance, sem
## alvo (nenhuma bolinha acaba cedo) e a E (24 mísseis em 3,75 s; o canhão para durante ela e volta depois) junto. Nenhuma carta do LightWolf soma projéteis (chuva e mira são do Luke e cia.).
func _t_pool() -> void:
	zerar()
	var h = w.heroi
	var ad = w.combate.adagas
	h.m_vel_ataque = 2.2
	h.nivel = 40
	var maior := 0
	h.ataque_forcado = true
	for i in 420:  # 0,33 s de canhão, os 3,75 s da E e 2,9 s de canhão de novo (eram 240 quadros com a E de 0,9 s)
		if i == 20:
			h.habilidade()
		w.avancar(PASSO)
		maior = maxi(maior, ad.ativas())
	h.ataque_forcado = false
	print("v2_lightwolf medido: pool pior caso %d de %d" % [maior, ad.MAX])
	ok(ad.lancadas > 100, "o pior caso atirou de verdade (%d projéteis)" % ad.lancadas)
	# se o pool enchesse, `_livre` tomaria a vaga de um projétil ainda em voo; com 3/4 de teto isso não chega perto de acontecer.
	# O piso (o teste estressou de verdade) era > 20 com a E de 0,9 s (21 medido): a E de 3,75 s espalha os mísseis (~8 no ar) e o mecha não atira
	# durante ela, então o pico agora é o do canhão sozinho (20 medido em 05/11, determinístico: o piso é o medido, sem folga para baixo); o teto,
	# que é o que protege o pool, não mudou.
	ok(maior >= 20 and maior <= ad.MAX * 3 / 4, "pior caso cabe no pool com folga (%d de %d em voo)" % [maior, ad.MAX])
	h.m_vel_ataque = 1.0
	h.nivel = 1


func _t_sem_folego() -> void:
	zerar()
	var h = w.heroi
	h.folego = 0.0
	h.cansado = true
	var antes: int = w.combate.adagas.lancadas
	h.ataque_forcado = true
	passos(60)
	h.ataque_forcado = false
	ok(w.combate.adagas.lancadas - antes >= 15, "com o fôlego zerado e cansado o mecha ainda atira (%d projéteis em 1 s)" % (w.combate.adagas.lancadas - antes))
	# o controle: quem não tem custo_mult (Hazaki) gasta fôlego golpeando no Difícil, então a diferença acima é do campo e não do cenário
	await novo("hazaki")
	zerar()
	var fol0: float = w.heroi.folego
	w.heroi.ataque_forcado = true
	passos(45)
	w.heroi.ataque_forcado = false
	ok(w.heroi.golpes >= 2 and w.heroi.folego < fol0 - 0.2, "controle: o Hazaki golpeando no Difícil gasta fôlego (%.2f de %.2f)" % [w.heroi.folego, fol0])


## som_cada: sem monstros (nenhum som de impacto no meio) e sem a trava de 20 ms entre sons iguais (relógio de parede), nove golpes tocam 3 sons (o 1º, o 4º e o 7º).
func _t_som() -> void:
	await novo("lightwolf")
	zerar()
	var c = w.combate
	var passo: Dictionary = c.cfg.golpe.passos[0]
	var sons0: int = c.audio.tocados
	var tiros0: int = c.tiros_som
	for i in 9:
		c.audio._ultimo_t.clear()
		c.golpe_comecou(w.heroi, passo, Vector2.RIGHT, 0.09)
	var cada := int(passo.som_cada)
	var esperado := 0
	for k in range(1, 10):
		if (tiros0 + k) % cada == 1:
			esperado += 1
	ok(c.tiros_som - tiros0 == 9, "nove golpes de tiro contam nove (%d)" % (c.tiros_som - tiros0))
	ok(c.audio.tocados - sons0 == esperado, "som a cada %d golpes: nove golpes tocam %d sons (%d)" % [cada, esperado, c.audio.tocados - sons0])
	# o impacto: uma rajada inteira num monstro encostado fere com quase todas as bolinhas, mas toca UM som de impacto e mostra UM número
	var m = w.nascer_monstro("inimigo_espantalho", w.heroi.pos + Vector2(40, 0))
	m.vida = 100000.0
	m.vida_max = 100000.0
	var ad = c.adagas
	var acertos0: int = ad.acertos
	var num0: int = c.fx.usados.numeros
	c.golpear(w.heroi, w.heroi.pos + w.heroi.ORIGEM_GOLPE, Vector2.RIGHT, passo, 0)
	var sons1: int = c.audio.tocados
	for q in 30:
		c.audio._ultimo_t.clear()  # sem a trava de relógio: só a regra da rajada segura o som
		m.pos = w.heroi.pos + Vector2(40, 0)
		w.avancar(PASSO)
	ok(ad.acertos - acertos0 >= int(passo.n) - 1, "a rajada encostada acerta quase todas as bolinhas (%d de %d)" % [ad.acertos - acertos0, int(passo.n)])
	ok(c.audio.tocados - sons1 == 1, "uma rajada toca um som de impacto só (%d)" % (c.audio.tocados - sons1))
	ok(c.fx.usados.numeros - num0 == 1, "uma rajada mostra um número só (%d)" % (c.fx.usados.numeros - num0))
