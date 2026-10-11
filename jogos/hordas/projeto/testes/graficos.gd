extends Node
# Teste automático (#150, E1): a aba Gráficos. Os 3 perfis (dados/graficos.json) preenchem todas as opções e batem com os
# números de hoje; mexer numa opção vira "personalizado"; salvar e carregar; o detectar devolve um perfil válido; a migração
# da "Qualidade gráfica" antiga; e os fatores que o jogo usa (partículas, halos, efeitos das armas, limite de inimigos).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/graficos.tscn  (imprime "GRAFICOS falhas=0")
# Salva e restaura o user://opcoes.cfg do jogador (como testes/opcoes.gd).
const Cresc := preload("res://scripts/hordas/crescimento.gd")
var falhas := 0
var sinais := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var antes := ConfigFile.new()
	var tinha := antes.load(Config.ARQUIVO) == OK
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
	ok(Config.item("qualidade").is_empty() and Config.item("vsync").is_empty() and Config.item("fps_max").is_empty() and Config.item("vinheta").is_empty(), "qualidade, vsync, fps_max e vinheta saíram do ITENS (a aba manda)")

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
	ok(Config.g("max_inimigos") == 500 and Config.fator_particulas("efe_faiscas") == 1.0 and Config.fator_particulas("elem_part") == 1.0, "alto: 500 vivos e partículas cheias")
	ok(Config.leituras_horror() == 8 and Config.luzes_horror() == 16 and is_equal_approx(Config.fator_brilho(), 1.0), "alto: horror 8 leituras, 16 luzes, halos 100%")
	ok(is_equal_approx(Cresc.fator(), 1.0) and Config.g("nevoa") == true and Config.g("vinheta") == true, "alto: efeitos das armas 100%, névoa e vinheta ligadas")
	Config.g_perfil_temporario("medio")
	ok(Config.g("max_inimigos") == 350 and is_equal_approx(Config.fator_particulas("efe_faiscas"), 0.6) and is_equal_approx(Config.fator_particulas("efe_impactos"), 0.67), "médio: 350 vivos, faíscas 0,6 e impactos 0,67 (como a media antiga)")
	ok(is_equal_approx(Config.fator_particulas("mortes_simples"), 0.6) and Config.leituras_horror() == 4 and Config.luzes_horror() == 12, "médio: mortes simples 0,6, horror 4 leituras e 12 luzes")
	ok(is_equal_approx(Cresc.fator(), 0.6) and is_equal_approx(Config.fator_brilho(), 0.5), "médio: efeitos das armas 60% e halos 50%")
	Config.g_perfil_temporario("baixo")
	ok(Config.g("max_inimigos") == 250 and is_equal_approx(Config.fator_particulas("amb_particulas"), 0.25) and is_equal_approx(Config.fator_particulas("mortes_simples"), 0.4), "baixo: 250 vivos, ambiente 0,25 e mortes simples 0,4 (como a baixa antiga)")
	ok(Config.g("nevoa") == false and Config.g("vinheta") == false and Config.g("sombras") == "contato", "baixo: sem névoa, sem vinheta e só o contato no pé")
	ok(Config.g("particulas_sim") == "poucas" and is_equal_approx(float(Config.g("calculo_monstros")), 2.0), "baixo: partículas poucas, monstros espaçados")
	ok(Config.leituras_horror() == 0 and Config.luzes_horror() == 8 and is_equal_approx(Cresc.fator(), 0.3), "baixo: sem leitura de tela no horror, 8 luzes, efeitos 30%")

	# 4. partículas: a opção "Partículas" (Nenhuma) ainda zera as que ela reduz, por cima do perfil
	Config.g_perfil_temporario("alto")
	var part_antes = Config.v("particulas")
	Config.temporario("particulas", 0.0)
	ok(is_zero_approx(Config.fator_particulas("amb_particulas")) and is_zero_approx(Config.fator_particulas("elem_part")), "Partículas: Nenhuma zera ambiente e elementos")
	ok(is_equal_approx(Config.fator_particulas("efe_faiscas"), 1.0), "Partículas: Nenhuma não mexe nas faíscas (só ambiente e elementos, como antes)")
	Config.temporario("particulas", part_antes)

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
	arq.load(Config.ARQUIVO)
	ok(arq.get_value("graficos", "max_inimigos", -1) == 300 and arq.get_value("graficos", "perfil", "") == "personalizado", "salvo no arquivo: 300 e personalizado")
	Config.recarregar()
	ok(Config.g("max_inimigos") == 300 and Config.g_perfil() == "personalizado", "carregado: 300 e personalizado")
	Config.g_aplicar_perfil("baixo")
	Config.recarregar()
	ok(Config.g_perfil() == "baixo" and Config.g("max_inimigos") == 250 and Config.g("sombras") == "contato", "carregado depois de baixo: perfil baixo inteiro")

	# 7. detectar devolve um perfil válido (e a máquina de teste é uma das três)
	ok(Config.g_detectar() in ["baixo", "medio", "alto"], "detectar: um perfil válido (%s)" % Config.g_detectar())

	# 8. migração: quem tinha a "Qualidade gráfica" antiga (media) vira o perfil médio, uma vez, e a chave antiga some
	var velho := ConfigFile.new()
	velho.set_value("opcoes", "qualidade", "media")
	velho.save(Config.ARQUIVO)
	Config.recarregar()
	ok(Config.g_perfil() == "medio" and Config.g("max_inimigos") == 350, "migração: media antiga vira medio")
	ok(not Config._cfg.has_section_key("opcoes", "qualidade"), "migração: a chave antiga sai do arquivo")

	# restaura o arquivo do jogador
	if tinha:
		antes.save(Config.ARQUIVO)
	print("GRAFICOS falhas=%d" % falhas)
	get_tree().quit()
