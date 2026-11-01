extends "res://testes/isolamento_v2.gd"
# Teste do LW-1 (#511): o mecha do LightWolf jogável atrás do portão beta. Confere: o portão (escondido sem beta; liberado por --beta-tester,
# --heroi=lightwolf ou herói forçado; o nome só é oferecido a quem tem o herói), os dados (números do plano, folhas provisórias rotuladas,
# passos de tiro com custo_mult 0) e o tiro (cadência ~10/s, sem gastar fôlego mesmo no Difícil e mesmo com fôlego zerado, poucas balas em voo,
# mão esquerda e direita alternadas, DPS na faixa do Luke, som de 1 em cada 3 tiros).
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
	ok(is_equal_approx(float(ps[0].dano), 4.8) and int(ps[0].som_cada) == 3, "mecha: dano 4,8 e som a cada 3 tiros")
	var cic: float = (float(ps[0].duracao) + float(ps[1].duracao)) / 2.0
	ok(cic > 0.06 and cic < 0.08, "mecha: ~10 tiros por segundo no papel: o passo mais o quadro de recomeço dá 6 quadros (%.3f s de passo)" % cic)
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


func _t_tiro() -> void:
	await novo("lightwolf")
	zerar()
	var h = w.heroi
	ok(str(w.combate.heroi_id) == "lightwolf" and str(h.chave) == "lightwolf", "o mundo nasce com o LightWolf")
	ok(is_equal_approx(float(h.vida_max), 130.0) and float(w.combate.cfg.heroi.vel) == 90.0, "mundo: vida 130 e vel 90 vindos do cfg")
	ok(float(Dificuldade.da_partida(w).golpe_custo) > 0.0, "no Difícil o golpe comum gasta fôlego (o teste só vale assim)")
	var m = w.nascer_monstro("inimigo_espantalho", h.pos + Vector2(150, 0))
	m.vida = 100000.0
	m.vida_max = 100000.0
	m.atordoa_t = 0.0
	var fol0: float = h.folego
	var antes: int = w.combate.adagas.lancadas
	var golpes0: int = h.golpes
	var tiros0: int = w.combate.tiros_som
	var dano0: float = w.combate.dano_causado
	var max_voo := 0
	var ys := []
	h.ataque_forcado = true
	for i in 180:  # 3 s segurando o botão
		w.avancar(PASSO)
		m.atordoa_t = 0.0
		m.pos = h.pos + Vector2(150, 0)
		max_voo = maxi(max_voo, _balas_em_voo())
		if i == 14:
			for j in w.combate.adagas.MAX:
				if w.combate.adagas.a_rest[j] > 0.0:
					ys.append(w.combate.adagas.a_pos[j].y)
	h.ataque_forcado = false
	passos(40)  # as últimas balas ainda estão a caminho do alvo
	var tiros: int = w.combate.adagas.lancadas - antes
	var golpes: int = h.golpes - golpes0
	ok(tiros >= 27 and tiros <= 33, "segurando 3 s saem ~30 tiros (10/s), saíram %d" % tiros)
	ok(golpes == tiros and w.combate.tiros_som - tiros0 == golpes, "um tiro por golpe e o contador de som conta cada golpe (%d/%d)" % [tiros, golpes])
	ok(
		is_equal_approx(h.folego, fol0) and h.golpe_calor_t == 0.0 and not h.cansado,
		"atirando sem parar o fôlego não se mexe (%.2f de %.2f)" % [h.folego, fol0]
	)
	ok(max_voo >= 3 and max_voo <= 7, "no máximo ~5 balas em voo (maior vista: %d)" % max_voo)
	ys.sort()
	ok(ys.size() >= 2 and float(ys[-1]) - float(ys[0]) >= 6.0, "as balas saem das duas mãos, lados opostos da mira (%s)" % str(ys))
	var dano: float = w.combate.dano_causado - dano0
	var dps := float(dano) / 3.0
	ok(dps >= 38.0 and dps <= 58.0, "DPS no alvo único perto de 50 (%.1f)" % dps)


func _t_sem_folego() -> void:
	zerar()
	var h = w.heroi
	h.folego = 0.0
	h.cansado = true
	var antes: int = w.combate.adagas.lancadas
	h.ataque_forcado = true
	passos(60)
	h.ataque_forcado = false
	ok(w.combate.adagas.lancadas - antes >= 8, "com o fôlego zerado e cansado o mecha ainda atira (%d tiros em 1 s)" % (w.combate.adagas.lancadas - antes))
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
	ok(c.tiros_som - tiros0 == 9, "nove golpes de tiro contam nove (%d)" % (c.tiros_som - tiros0))
	ok(c.audio.tocados - sons0 == 3, "som a cada 3 tiros: nove golpes tocam 3 sons (%d)" % (c.audio.tocados - sons0))
