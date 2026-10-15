extends Node
# Teste automático (#150, E1): a aba Gráficos. Os 3 perfis (dados/graficos.json) preenchem todas as opções e batem com os
# números de hoje; mexer numa opção vira "personalizado"; salvar e carregar; o detectar devolve um perfil válido; a migração
# da "Qualidade gráfica" antiga; a partícula única (particulas_sim) e os fatores que o jogo usa.
# Grava num arquivo de teste próprio (Config.arquivo): nunca o opcoes.cfg do jogador nem o de outro teste em paralelo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/graficos.tscn  (imprime "GRAFICOS falhas=0")
const Cresc := preload("res://scripts/hordas/crescimento.gd")
const ARQ_TESTE := "user://teste_graficos.cfg"
var falhas := 0
var sinais := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Config.arquivo = ARQ_TESTE
	var vazio := ConfigFile.new()  # começa sem nada salvo
	vazio.save(ARQ_TESTE)
	Config.recarregar()
	Config.graficos_mudou.connect(func(): sinais += 1)
	var perfis: Dictionary = Dados.json("graficos").get("perfis", {})
	var opcoes: Array = Config.g_opcoes()

	# 1. o json: 15 opções (5 de CPU, 10 de GPU), tipos válidos, cada perfil traz todas
	ok(opcoes.size() == 15, "15 opções na aba (deu %d)" % opcoes.size())
	var secoes := {"cpu": 0, "gpu": 0}
	for o in opcoes:
		secoes[o.secao] = int(secoes.get(o.secao, 0)) + 1
		ok(o.tipo in ["slider", "menu", "sim_nao"], "%s: tipo válido" % o.chave)
		ok(str(o.get("ajuda", "")) != "" and o.peso in ["leve", "medio", "pesado"], "%s: tem ajuda e peso" % o.chave)
		for p in ["baixo", "medio", "alto"]:
			ok(perfis.get(p, {}).has(o.chave), "%s: o perfil %s traz a opção" % [o.chave, p])
	ok(secoes.cpu == 5 and secoes.gpu == 10, "CPU 5 e GPU 10 (deu %s)" % str(secoes))
	ok(
		Config.item("qualidade").is_empty() and Config.item("vsync").is_empty() and Config.item("fps_max").is_empty() and Config.item("vinheta").is_empty(),
		"qualidade, vsync, fps_max e vinheta saíram do ITENS (a aba manda)"
	)
	ok(Config.item("particulas").is_empty(), "a opção de leitura 'Partículas' saiu: a única é particulas_sim")

	# 2. cada perfil: g() devolve o que o perfil diz, e o valor pertence ao domínio da opção (menu, faixa do slider)
	for p in ["baixo", "medio", "alto"]:
		Config.g_perfil_temporario(p)
		ok(Config.g_perfil() == p, "perfil %s aplicado" % p)
		for o in opcoes:
			var val = Config.g(o.chave)
			ok(val == perfis[p][o.chave], "%s: %s = %s" % [p, o.chave, str(val)])
			if o.tipo == "menu":
				ok(val in o.valores, "%s: %s no menu" % [p, o.chave])
			elif o.tipo == "slider":
				ok(val >= o.min and val <= o.max, "%s: %s na faixa" % [p, o.chave])
			else:
				ok(typeof(val) == TYPE_BOOL, "%s: %s é sim/não" % [p, o.chave])

	# 3. os números de hoje (dados/qualidade.json antigo): alto = alta, medio = media, baixo = baixa
	Config.g_perfil_temporario("alto")
	ok(
		Config.g("max_inimigos") == 500 and Config.fator_particulas("efe_faiscas") == 1.0 and Config.fator_particulas("elem_part") == 1.0,
		"alto: 500 vivos e partículas cheias"
	)
	ok(
		Config.leituras_horror() == 8 and Config.luzes_horror() == 16 and is_equal_approx(Config.fator_brilho(), 1.0),
		"alto: horror 8 leituras, 16 luzes, halos 100%"
	)
	ok(
		is_equal_approx(Cresc.fator(), 1.0) and Config.g("nevoa") == true and Config.g("vinheta") == true,
		"alto: efeitos das armas 100%, névoa e vinheta ligadas"
	)
	Config.g_perfil_temporario("medio")
	ok(
		(
			Config.g("max_inimigos") == 350
			and is_equal_approx(Config.fator_particulas("efe_faiscas"), 0.6)
			and is_equal_approx(Config.fator_particulas("efe_impactos"), 0.67)
		),
		"médio: 350 vivos, faíscas 0,6 e impactos 0,67 (como a media antiga)"
	)
	ok(
		is_equal_approx(Config.fator_particulas("mortes_simples"), 0.6) and Config.leituras_horror() == 4 and Config.luzes_horror() == 12,
		"médio: mortes simples 0,6, horror 4 leituras e 12 luzes"
	)
	ok(is_equal_approx(Cresc.fator(), 0.6) and is_equal_approx(Config.fator_brilho(), 0.5), "médio: efeitos das armas 60% e halos 50%")
	Config.g_perfil_temporario("baixo")
	ok(
		(
			Config.g("max_inimigos") == 250
			and is_equal_approx(Config.fator_particulas("amb_particulas"), 0.25)
			and is_equal_approx(Config.fator_particulas("mortes_simples"), 0.4)
		),
		"baixo: 250 vivos, ambiente 0,25 e mortes simples 0,4 (como a baixa antiga)"
	)
	ok(
		Config.g("nevoa") == false and Config.g("vinheta") == false and Config.g("sombras") == "baixa",
		"baixo: sem névoa, sem vinheta e sombra baixa (só a mancha no pé)"
	)
	ok(Config.g("particulas_sim") == "poucas" and is_equal_approx(float(Config.g("calculo_monstros")), 2.0), "baixo: partículas poucas, monstros espaçados")
	ok(
		Config.leituras_horror() == 0 and Config.luzes_horror() == 8 and is_equal_approx(Cresc.fator(), 0.3),
		"baixo: sem leitura de tela no horror, 8 luzes, efeitos 30%"
	)

	# 4. partículas: uma opção só (particulas_sim). Nenhuma zera tudo; Poucas e Médias seguem a escala antiga
	Config.g_perfil_temporario("alto")
	Config.g_temporario("particulas_sim", "nenhuma")
	ok(
		(
			is_zero_approx(Config.fator_particulas("amb_particulas"))
			and is_zero_approx(Config.fator_particulas("elem_part"))
			and is_zero_approx(Config.fator_particulas("efe_faiscas"))
			and is_zero_approx(Config.fator_particulas("mortes_simples"))
		),
		"Nenhuma zera todas as partículas"
	)
	Config.g_temporario("particulas_sim", "medias")
	ok(
		is_equal_approx(Config.fator_particulas("amb_particulas"), 0.5) and is_equal_approx(Config.fator_particulas("elem_part"), 0.5),
		"Médias: metade do ambiente e dos elementos"
	)
	Config.g_perfil_temporario("alto")

	# 5. mexer numa opção vira personalizado, salva e avisa
	var n0 := sinais
	Config.g_aplicar_perfil("alto")
	ok(Config.g_perfil() == "alto" and sinais == n0 + 1, "aplicar o perfil alto salva e avisa")
	Config.g_definir("max_inimigos", 300)
	ok(Config.g_perfil() == "personalizado", "mexer num detalhe vira personalizado")
	ok(Config.g("max_inimigos") == 300 and Config.g("nevoa") == true, "o detalhe mexido vale e o resto continua do perfil")
	ok(sinais == n0 + 2, "mexer avisa a tela (graficos_mudou)")

	# 6. salvar e carregar: o arquivo tem o que foi salvo e recarregar devolve o mesmo estado
	var arq := ConfigFile.new()
	arq.load(ARQ_TESTE)
	ok(
		arq.get_value("graficos", "max_inimigos", -1) == 300 and arq.get_value("graficos", "perfil", "") == "personalizado",
		"salvo no arquivo: 300 e personalizado"
	)
	Config.recarregar()
	ok(Config.g("max_inimigos") == 300 and Config.g_perfil() == "personalizado", "carregado: 300 e personalizado")
	Config.g_aplicar_perfil("baixo")
	Config.recarregar()
	ok(Config.g_perfil() == "baixo" and Config.g("max_inimigos") == 250 and Config.g("sombras") == "baixa", "carregado depois de baixo: perfil baixo inteiro")

	# 7. detectar devolve um perfil válido
	ok(Config.g_detectar() in ["baixo", "medio", "alto"], "detectar: um perfil válido (%s)" % Config.g_detectar())

	# 8. migração: quem tinha a "Qualidade gráfica" antiga (media) vira o perfil médio, uma vez, e a chave antiga some
	var velho := ConfigFile.new()
	velho.set_value("opcoes", "qualidade", "media")
	velho.save(ARQ_TESTE)
	Config.recarregar()
	ok(Config.g_perfil() == "medio" and Config.g("max_inimigos") == 350, "migração: media antiga vira medio")
	ok(not Config._cfg.has_section_key("opcoes", "qualidade"), "migração: a chave antiga sai do arquivo")

	# 9. sombras (#150 -> baixa, media, alta): os 3 perfis dão o valor certo; a opção é menu na GPU com os rótulos da tela;
	# quem tinha contato ou projetadas salvo vira baixa ou media (uma vez)
	var sombra_do_perfil := {"baixo": "baixa", "medio": "media", "alto": "alta"}
	for p in sombra_do_perfil:
		Config.g_perfil_temporario(p)
		ok(Config.g("sombras") == sombra_do_perfil[p], "%s: sombras = %s" % [p, sombra_do_perfil[p]])
	var op_sombras: Dictionary = Config.g_opcao("sombras")
	ok(
		op_sombras.get("tipo") == "menu" and op_sombras.get("secao") == "gpu" and op_sombras.get("valores") == ["baixa", "media", "alta"],
		"sombras: menu na GPU com baixa, media e alta"
	)
	ok(op_sombras.get("rotulos") == ["Simples", "Suaves", "Detalhadas"], "sombras: rótulos Simples, Suaves e Detalhadas")
	for par in [["contato", "baixa"], ["projetadas", "media"]]:
		var arq_s := ConfigFile.new()
		arq_s.set_value("graficos", "sombras", par[0])
		arq_s.save(ARQ_TESTE)
		Config.recarregar()
		ok(Config.g("sombras") == par[1], "migração: sombras %s vira %s" % [par[0], par[1]])
	Config.g_aplicar_perfil("alto")

	# 10. a queda automática é só da memória: g_perfil_temporario não grava, nem quando outra opção é salva depois;
	# recarregar e mexer numa opção da aba tiram o temporário; g_temporario muda o valor e não o perfil
	Config.g_aplicar_perfil("alto")
	Config.g_perfil_temporario("baixo")
	Config.definir("mostrar_fps", true)  # salva o arquivo com outra opção
	var arq_t := ConfigFile.new()
	arq_t.load(ARQ_TESTE)
	ok(Config.g_perfil() == "baixo" and Config.g("sombras") == "baixa", "temporário: vale na memória")
	ok(
		arq_t.get_value("graficos", "perfil", "") == "alto" and arq_t.get_value("graficos", "sombras", "") == "alta",
		"temporário: o arquivo continua com o perfil alto"
	)
	Config.recarregar()
	ok(Config.g_perfil() == "alto" and Config.g("sombras") == "alta", "recarregar tira o temporário")
	Config.g_perfil_temporario("medio")
	Config.g_definir("max_inimigos", 300)
	ok(Config.g_perfil() == "personalizado" and Config.g("sombras") == "alta", "mexer numa opção tira o temporário: vale o salvo")
	Config.g_aplicar_perfil("alto")
	Config.g_temporario("tremor_clarao", 0)
	ok(Config.g_perfil() == "alto" and Config.g("tremor_clarao") == 0, "g_temporario muda o valor e não o perfil")
	Config.g_aplicar_perfil("alto")

	print("GRAFICOS falhas=%d" % falhas)
	get_tree().quit()
