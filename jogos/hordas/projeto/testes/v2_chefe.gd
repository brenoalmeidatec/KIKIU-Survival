extends Node
# Teste dos CHEFES da v2 (v2/chefe.gd): o mini-chefe do nível 10 (anúncio, barra, ataques anunciados que disparam, dano, baú, e matá-lo
# não é vitória), o do nível 20 e o CHEFÃO do nível 30, que é a vitória: o mapa fica vencido no save (combate.fim_de_partida chama
# Meta.marcar_mapa_vencido). Os níveis em si estão em testes/v2_diretor.gd.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_chefe.tscn  (imprime "v2_chefe falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Meta := preload("res://v2/meta.gd")
const PASSO := 1.0 / 60.0
const SAVE_TESTE := "user://teste_v2_chefe.cfg"
var falhas := 0
var w
var sinais := {}


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


func zerar() -> void:
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
	sinais.clear()
	passos(3)


func conta(nome: String) -> int:
	return int(sinais.get(nome, 0))


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	for nome in ["onda_forte", "elite_apareceu", "chefe_apareceu", "chefe_vida", "evolucao", "anuncio", "partida_terminou"]:
		ok(w.has_signal(nome), "sinal %s existe" % nome)
	w.evolucao.connect(
		func(n, d):
			sinais["evolucao"] = conta("evolucao") + 1
			sinais["evolucao_nome"] = n
			sinais["evolucao_desc"] = d
	)
	w.elite_apareceu.connect(
		func(n):
			sinais["elite"] = conta("elite") + 1
			sinais["elite_nome"] = n
	)
	w.chefe_apareceu.connect(
		func(n, v):
			sinais["chefe"] = conta("chefe") + 1
			sinais["chefe_nome"] = n
			sinais["chefe_vida_max"] = v
	)
	w.chefe_vida.connect(
		func(v):
			sinais["chefe_vida"] = conta("chefe_vida") + 1
			sinais["chefe_vida_ultima"] = v
	)
	w.anuncio.connect(
		func(t, _c):
			sinais["anuncio"] = conta("anuncio") + 1
			sinais["anuncio_texto"] = t
	)
	w.onda_forte.connect(
		func(n):
			sinais["onda"] = conta("onda") + 1
			sinais["onda_n"] = n
	)
	w.partida_terminou.connect(
		func(r):
			sinais["fim"] = conta("fim") + 1
			sinais["fim_res"] = r
	)

	# save de teste: a vitória marca o mapa como vencido nele, nunca no save de verdade
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TESTE))
	Meta.caminho_save = SAVE_TESTE
	# o mini-chefe do nível 10 em campo: o nível sobe sozinho até lá
	zerar()
	w.combate.diretor.ligado = false
	var dir = w.combate.diretor
	var seg: float = dir.seg_nivel()
	dir.ir_para_nivel(9)
	dir.t_nivel = seg - 0.5
	passos(50)
	ok(dir.nivel == 10 and w.combate.chefes.vivo and w.combate.chefes.marca.id == "n10", "o mini-chefe do nível 10 está em campo")

	var ch = w.combate.chefes.atual
	ok(ch.chefe and ch.escala > 2.0 and ch.vida_max >= 1000.0, "o mini-chefe é grande e tem muita vida")
	ok(conta("chefe") == 1 and sinais.get("chefe_vida_max", 0.0) == ch.vida_max, "sinal chefe_apareceu(nome, vida_max)")
	ok(
		str(sinais.get("anuncio_texto", "")).contains("MINI-CHEFE"),
		"anuncio('MINI-CHEFE: ...') junto do chefe_apareceu (%s)" % str(sinais.get("anuncio_texto", ""))
	)
	ate(func(): return w.combate.avisos.ativos() > 0, 900)
	ok(w.combate.avisos.ativos() > 0 and w.combate.chefes.ataques_feitos > 0, "o chefe anuncia o ataque com uma área piscando no chão")
	var vida_h: float = w.heroi.vida
	ate(func(): return w.combate.avisos.disparados > 0, 400)
	ok(w.combate.avisos.disparados > 0, "depois do aviso a área dispara")
	w.heroi.imortal = false
	w.heroi.vida = w.heroi.vida_max
	w.combate.avisos.circulo(w.heroi.pos, 40.0, 0.5, 15.0, Color.RED)
	passos(10)
	ok(w.heroi.vida == w.heroi.vida_max, "durante o aviso ninguém leva dano")
	passos(40)
	ok(w.heroi.vida < w.heroi.vida_max, "quem fica na área leva o dano quando ela dispara")
	w.heroi.imortal = true
	var chefe_v0: float = ch.vida
	w.combate.ferir(ch, 50.0, Vector2.RIGHT, 500.0, 2.0, Color.WHITE)
	ok(ch.vida < chefe_v0 and ch.emp.length() < 100.0 and ch.atordoa_t < 0.01, "o chefe apanha mas não sai voando nem fica atordoado")
	passos(5)
	ok(conta("chefe_vida") > 0, "sinal chefe_vida(vida) a cada mudança")
	var baus0: int = w.combate.baus.soltos
	w.combate.ferir(ch, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	w.combate.processar_mortes()
	ok(not w.combate.chefes.vivo and float(sinais.get("chefe_vida_ultima", 1.0)) == 0.0, "a morte do chefe emite chefe_vida(0)")
	ok(w.combate.baus.soltos == baus0 + 1, "o mini-chefe solta um baú")
	ok(w.combate.jogo == "jogando", "matar o mini-chefe não é vitória")
	ok(not dir.travado(), "mini-chefe morto: o nível destrava")
	dir.avancar_nivel(seg + 0.01)
	ok(dir.nivel == 11, "e segue para o nível 11")
	dir.ir_para_nivel(20)
	passos(2)
	ok(w.combate.chefes.vivo and w.combate.chefes.marca.id == "n20" and w.combate.chefes.marca.nome == "Rainha Tecelã", "nível 20: o segundo mini-chefe")
	w.combate.ferir(w.combate.chefes.atual, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	w.combate.processar_mortes()
	ok(w.combate.jogo == "jogando", "matar o segundo mini-chefe também não é vitória")
	dir.ir_para_nivel(29)
	dir.t_nivel = 0.0
	dir.avancar_nivel(seg + 0.01)
	ok(dir.nivel == 30 and w.combate.chefes.vivo and not bool(w.combate.chefes.marca.mini), "o CHEFÃO nasce no nível 30, o último")
	dir.avancar_nivel(seg * 10.0)
	ok(dir.nivel == 30, "o mapa tem fim: não passa do nível 30")
	ok(str(sinais.get("anuncio_texto", "")).contains("CHEFE"), "anuncia o chefe")
	# 8. vencer o chefe é a vitória
	w.abates = 321
	w.maior_combo = 55
	w.xp_coletado = 1234.0
	w.combate.ferir(w.combate.chefes.atual, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
	w.combate.processar_mortes()
	ok(w.combate.jogo == "vencendo" and w.monstros.is_empty(), "matar o chefe começa a vitória e os monstros estouram")
	ate(func(): return w.combate.jogo == "vitoria", 300)
	ok(w.combate.jogo == "vitoria" and w.combate.pausado and w.combate.telas.resultado_aberto, "a tela de resultado abre na vitória")
	ok(w.combate.telas._res_titulo.text == "VITÓRIA", "a tela mostra VITÓRIA")
	ok(conta("fim") == 1, "partida_terminou saiu uma vez")
	var res: Dictionary = sinais.get("fim_res", {})
	for k in ["tempo", "abates", "nivel", "maior_combo", "venceu", "almas", "mapa", "nivel_mapa", "niveis_mapa"]:
		ok(res.has(k), "partida_terminou traz o campo %s" % k)
	ok(res.get("venceu") == true and int(res.get("abates", 0)) >= 321 and int(res.get("maior_combo", 0)) == 55, "campos da vitória certos")
	ok(int(res.get("almas", -1)) == 123 and w.almas_partida == 123, "almas = XP coletado / 10 arredondado (123)")
	ok(int(res.get("nivel", 0)) >= 1, "nível do herói")
	ok(str(res.get("mapa", "")) == "floresta" and int(res.get("nivel_mapa", 0)) == 30, "a vitória é no último nível da floresta")
	ok(w.combate.telas._res_linhas.text.contains("Almas") and w.combate.telas._res_valores.text.contains("123"), "a tela mostra as almas ganhas")
	ok(Meta.mapa_vencido("floresta") and Meta.mapas_vencidos().size() == 1, "vencer o chefão marca a Floresta como vencida no save")
	print("v2_chefe falhas=%d" % falhas)
	get_tree().quit()
