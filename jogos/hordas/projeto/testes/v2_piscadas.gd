extends "res://testes/isolamento_v2.gd"
# Teste da opção "Reduzir piscadas" (#512, UI-2): o helper v2/piscadas.gd, a linha em Gráficos (que não vira Personalizado) e, numa partida de verdade,
# o que mais liga e desliga: a invencibilidade do herói, o fôlego cansado, a vida baixa e o chão anunciado. Cada série é amostrada por 3 s (180 quadros)
# e as trocas de luz são contadas. Desligada, o herói dá ~28 por segundo (prova que o teste pega o defeito); ligada, no máximo 3 por segundo.
# Também confere a luz do fogo da aura (energia fixa), a cor da carga sobre a invencibilidade e o cache da opção no Config. Também confere: clarão de tela, glitch do clima, flash de acerto (tinta fixa e sem repetir em 0,34 s, borda inclusa) e o flash da morte, que fica.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_piscadas.tscn  (imprime "v2_piscadas falhas=0")
# Não prova que PINTA: a medição na tela, em janela de verdade, é feita à parte (ver o PR).
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const Clima := preload("res://v2/clima.gd")
const AjustesGraficos := preload("res://v2/ajustes_graficos.gd")
const PASSO := 1.0 / 60.0
const QUADROS := 180  # 3 s
var falhas := 0
var w
var armas


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)
		w.hud.avancar(PASSO)


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
	passos(3)


func opcao(ligada: bool) -> void:
	Config.definir(Piscadas.OPCAO, ligada)


## Trocas por segundo de uma série amostrada em QUADROS quadros (3 s).
func por_segundo(serie: Array) -> float:
	return float(Piscadas.trocas(serie)) / (float(serie.size()) * PASSO)


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.hud.set_process(false)  # o HUD anda no passo do teste (hud.avancar), não no tempo de parede
	w.combate.audio.mudo = true
	Config.g_perfil_temporario("alto")

	# 1. o helper e a opção
	opcao(false)
	ok(not Piscadas.ligado() and Piscadas.clarao_permitido(), "o padrão é desligado (decisão D11)")
	ok(Piscadas.pisca(0.0, 14.0) and not Piscadas.pisca(1.0 / 28.0, 14.0), "desligada: pisca() liga e desliga a cada meio ciclo")
	ok(is_equal_approx(Piscadas.valor(0.2, 0.9), 0.2), "desligada: valor() devolve o variável")
	opcao(true)
	ok(Piscadas.ligado() and not Piscadas.clarao_permitido(), "ligada: sem clarão de tela")
	ok(not Piscadas.pisca(0.0, 14.0) and not Piscadas.pisca(1.0 / 28.0, 14.0), "ligada: pisca() nunca acende")
	ok(is_equal_approx(Piscadas.valor(0.2, 0.9), 0.9), "ligada: valor() devolve o fixo")
	ok(
		Piscadas.trocas([0.0, 1.0, 0.0, 1.0, 0.0]) == 4 and Piscadas.trocas([0.5, 0.5, 0.5000001]) == 0,
		"trocas(): conta os cruzamentos e só ignora série parada"
	)
	ok(Piscadas.trocas([0.50, 0.51, 0.50, 0.51, 0.50]) == 4, "trocas(): uma oscilação pequena (0,01) também conta: nada passa por 'quase parado'")
	ok(Piscadas.trocas([0.0, 0.0, 0.0, 0.0]) == 0 and Piscadas.trocas([0.2]) == 0, "trocas(): série constante ou de um ponto não troca")
	ok(Piscadas.FLASH_REPETE_S >= 0.34, "o intervalo do flash de acerto é de pelo menos 0,34 s (3 por segundo no máximo)")
	# o cache do Config acompanha a opção em definir(), temporario() e recarregar()
	Config.definir(Piscadas.OPCAO, true)
	ok(Config.reduzir_piscadas and Piscadas.ligado(), "o cache do Config liga com definir()")
	Config.temporario(Piscadas.OPCAO, false)
	ok(not Config.reduzir_piscadas and not Piscadas.ligado(), "o cache do Config desliga com temporario()")
	Config.recarregar()
	ok(Config.reduzir_piscadas == bool(Config.v(Piscadas.OPCAO)) and Piscadas.ligado(), "o cache do Config volta ao arquivo com recarregar()")
	Config.definir(Piscadas.OPCAO, false)
	ok(not Config.reduzir_piscadas, "o cache do Config desliga com definir()")
	Config.g_perfil_temporario("alto")

	# 2. a linha em Gráficos: liga e desliga e NÃO vira Personalizado
	opcao(false)
	Config.g_aplicar_perfil("medio")
	var aj := AjustesGraficos.new()
	var achou := false
	for it in aj.itens():
		if str(it.id) == "g:piscadas":
			achou = str(it.rotulo) == "Reduzir piscadas" and str(it.valor) == "Não"
	ok(achou, "Gráficos tem a linha Reduzir piscadas: Não")
	var antes_g := {}
	for o in Config.g_opcoes():
		antes_g[str(o.chave)] = Config.g(str(o.chave))
	aj.agir("piscadas", 1)
	ok(Piscadas.ligado() and Config.g_perfil() == "medio", "a linha liga a opção e o perfil continua Médio (não vira Personalizado)")
	ok(Config.g_perfil_escolhido() == "medio", "ligada: o perfil escolhido (o gravado) continua Médio")
	aj.agir("piscadas", 1)
	ok(not Piscadas.ligado() and Config.g_perfil() == "medio", "a linha desliga a opção e o perfil continua Médio")
	var iguais := true
	for k in antes_g:
		if Config.g(k) != antes_g[k]:
			iguais = false
			print("  mudou: ", k)
	ok(iguais, "ligar e desligar a linha não mexe em nenhuma das opções do perfil (nem uma muda de valor)")
	# o inverso: mexer numa opção do perfil de verdade vira Personalizado (prova que a checagem acima pegaria o defeito)
	Config.g_definir("sombras", "alta" if str(Config.g("sombras")) != "alta" else "media")
	ok(Config.g_perfil() == "personalizado", "controle: mexer numa opção do perfil vira Personalizado")
	Config.g_aplicar_perfil("alto")

	# 3. o herói invencível: 3 s com a invencibilidade sempre cheia
	zerar()
	var h = w.heroi
	var lum: Array = []
	opcao(false)
	for i in QUADROS:
		h.invenc = 0.5
		passos(1)
		lum.append(Piscadas.luminancia(h.sprite.modulate))
	var sem := por_segundo(lum)
	ok(sem > 20.0, "opção desligada: o herói invencível troca ~28 vezes por segundo (deu %.1f)" % sem)
	lum.clear()
	opcao(true)
	for i in QUADROS:
		h.invenc = 0.5
		passos(1)
		lum.append(Piscadas.luminancia(h.sprite.modulate))
	var com := por_segundo(lum)
	ok(com <= Piscadas.MAX_TROCAS_S, "opção ligada: o herói invencível troca %.1f vezes por segundo (máximo 3)" % com)
	var m: Color = h.sprite.modulate
	ok(m.r > m.g and m.a < 1.0, "ligada: invencível é translúcido com tom vermelho fixo")

	# 4. fôlego cansado e vida baixa na HUD
	zerar()
	h = w.heroi
	var folego: Array = []
	var vida: Array = []
	var vinheta: Array = []
	for ligada in [false, true]:
		opcao(ligada)
		folego.clear()
		vida.clear()
		vinheta.clear()
		for i in QUADROS:
			h.cansado = true
			h.folego = 0.0
			h.vida = h.vida_max * 0.15
			passos(1)
			folego.append(Piscadas.luminancia(w.hud._folego.modulate))
			vida.append(Piscadas.luminancia(w.hud._vida_barra.modulate))
			vinheta.append(w.hud._vinheta.modulate.a)
		var f := por_segundo(folego)
		var v := por_segundo(vida)
		var vg := por_segundo(vinheta)
		if ligada:
			ok(f <= Piscadas.MAX_TROCAS_S, "ligada: fôlego cansado troca %.1f vezes por segundo" % f)
			ok(v <= Piscadas.MAX_TROCAS_S, "ligada: vida baixa troca %.1f vezes por segundo" % v)
			ok(vg <= Piscadas.MAX_TROCAS_S, "ligada: a vinheta de vida baixa troca %.1f vezes por segundo" % vg)
			# a vinheta é vermelha: nenhum vermelho pisca. Não basta ficar abaixo de 3 trocas; o alfa tem que ficar PARADO (depois de entrar)
			var cauda := vinheta.slice(QUADROS / 3)
			var vmin := float(cauda.min())
			var vmax := float(cauda.max())
			ok(vmax - vmin < 0.0001, "ligada: o alfa da vinheta de vida baixa fica parado (variou %.4f)" % (vmax - vmin))
			ok(vmax > 0.3, "ligada: a vinheta de vida baixa continua acesa, só parada (alfa %.2f)" % vmax)
		else:
			var dc := vinheta.slice(QUADROS / 3)
			ok(
				float(dc.max()) - float(dc.min()) > 0.05,
				"desligada: o alfa da vinheta pulsa (variou %.3f): o teste pega o defeito" % (float(dc.max()) - float(dc.min()))
			)
			ok(f > 3.0, "desligada: fôlego cansado pisca (%.1f por segundo): o teste pega o defeito" % f)
			ok(v > 3.0, "desligada: vida baixa pisca (%.1f por segundo): o teste pega o defeito" % v)
	h.cansado = false
	h.vida = h.vida_max

	# 5. o chão anunciado: o pulso do aviso
	zerar()
	var av = w.combate.avisos
	var pulsos: Array = []
	for ligada in [false, true]:
		opcao(ligada)
		pulsos.clear()
		var i_av: int = av.circulo(w.heroi.pos + Vector2(200, 0), 60.0, 3.5, 0.0, Color(1.0, 0.3, 0.2))
		for q in QUADROS:
			passos(1)
			pulsos.append(av.pulso(i_av))
		var p := por_segundo(pulsos)
		if ligada:
			ok(p <= Piscadas.MAX_TROCAS_S, "ligada: o chão anunciado troca %.1f vezes por segundo" % p)
			ok(float(pulsos[QUADROS - 1]) > float(pulsos[0]), "ligada: o aviso continua crescendo (%.2f -> %.2f)" % [pulsos[0], pulsos[QUADROS - 1]])
		else:
			ok(p > 3.0, "desligada: o chão anunciado pisca (%.1f por segundo): o teste pega o defeito" % p)
		av.limpar()

	# 6. clarão de tela
	zerar()
	var fx = w.combate.fx
	opcao(false)
	fx.clarao(Color(0.8, 0.85, 1.0, 0.25), 0.15)
	ok(fx._cl_t < fx._cl_dur, "desligada: o clarão acende")
	fx._cl_t = 9.0
	opcao(true)
	fx.clarao(Color(0.8, 0.85, 1.0, 0.25), 0.15)
	ok(fx._cl_t >= 9.0, "ligada: o clarão de tela não acende")

	# 7. flash de acerto: tinta fixa, sem repetir no mesmo monstro em menos de 0,33 s; o da morte fica
	zerar()
	var mo = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(120, 0))
	var outro = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(-120, 0))
	opcao(false)
	var antes: int = fx.usados.flashes
	fx.flash(mo, 0.1)
	fx.flash(mo, 0.1)
	ok(fx.usados.flashes - antes == 2, "desligada: dois flashes seguidos no mesmo monstro passam")
	opcao(true)
	antes = fx.usados.flashes
	fx.flash(mo, 0.1)
	ok(fx.usados.flashes - antes == 1, "ligada: o primeiro flash de acerto passa")
	passos(10)  # 0,17 s
	fx.flash(mo, 0.1)
	ok(fx.usados.flashes - antes == 1, "ligada: o mesmo monstro não leva outro flash em 0,34 s")
	fx.flash(outro, 0.1)
	ok(fx.usados.flashes - antes == 2, "ligada: outro monstro leva o flash normalmente")
	passos(12)  # passou de 0,34 s desde o primeiro
	fx.flash(mo, 0.1)
	ok(fx.usados.flashes - antes == 3, "ligada: depois de 0,34 s o mesmo monstro leva de novo")
	var fixo := false
	for s in fx._fl:
		if s.visible and s.material != null and is_equal_approx(float((s.material as ShaderMaterial).get_shader_parameter("k")), Piscadas.FLASH_ALFA):
			fixo = true
	ok(fixo, "ligada: o flash de acerto é tinta de alfa %.1f" % Piscadas.FLASH_ALFA)
	antes = fx.usados.flashes
	fx.flash(mo, 0.24, Color.WHITE, 1)
	fx.flash(mo, 0.24, Color.WHITE, 1)
	ok(fx.usados.flashes - antes == 2, "ligada: o flash da morte fica (não é cortado)")

	# 7b. a borda do intervalo: tentando um flash por quadro no mesmo monstro, em 1 s (61 quadros) passam no máximo 3 (com 0,33 passavam 4)
	zerar()
	mo = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(120, 0))
	opcao(true)
	antes = fx.usados.flashes
	for q in 61:
		fx.flash(mo, 0.1)
		passos(1)
	var passaram: int = fx.usados.flashes - antes
	ok(passaram <= 3, "ligada: um flash por quadro no mesmo monstro deixa passar %d em 1 s (máximo 3)" % passaram)
	zerar()
	mo = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(120, 0))
	antes = fx.usados.flashes
	fx.flash(mo, 0.1)
	passos(20)  # 0,333 s: ainda dentro de 0,34 s
	fx.flash(mo, 0.1)
	ok(fx.usados.flashes - antes == 1, "ligada: aos 0,333 s o mesmo monstro ainda não leva outro flash (a borda)")
	passos(1)  # 0,350 s
	fx.flash(mo, 0.1)
	ok(fx.usados.flashes - antes == 2, "ligada: aos 0,350 s o mesmo monstro leva de novo")

	# 7c. o anel de alvos: 60 outros acertos dentro de 0,34 s não apagam o primeiro (com o anel de 48 ele era sobrescrito e levava flash de novo)
	opcao(true)
	var primeiro := Node.new()
	add_child(primeiro)
	ok(fx._pode_flash_acerto(primeiro), "anel: o primeiro alvo passa")
	var extras: Array = []
	for q in 60:
		var n := Node.new()
		add_child(n)
		extras.append(n)
		fx._pode_flash_acerto(n)
	ok(not fx._pode_flash_acerto(primeiro), "anel: depois de 60 outros acertos no mesmo instante o primeiro alvo ainda é barrado")
	primeiro.free()
	for n in extras:
		n.free()

	# 7d. o brilho da runa armada (~1 Hz): oscila desligada, parado ligado
	armas = w.combate.armas
	var pulsos_runa: Array = []
	for ligada in [false, true]:
		opcao(ligada)
		pulsos_runa.clear()
		for q in QUADROS:
			armas._fase += PASSO
			pulsos_runa.append(armas._pulso_runa(0))
		var dr := float(pulsos_runa.max()) - float(pulsos_runa.min())
		if ligada:
			ok(dr < 0.0001 and is_equal_approx(float(pulsos_runa[0]), Piscadas.PULSO_RUNA_FIXO), "ligada: o brilho da runa fica parado (variou %.4f)" % dr)
		else:
			ok(dr > 0.2, "desligada: o brilho da runa pulsa (variou %.2f): o teste pega o defeito" % dr)

	# 8. glitch do clima
	var pai := Node.new()
	add_child(pai)
	opcao(false)
	var lab = Clima.new()
	lab.montar(pai, "laboratorio")
	ok(lab.disparar_rajada(), "desligada: o glitch do laboratório dispara")
	opcao(true)
	var lab2 = Clima.new()
	lab2.montar(pai, "laboratorio")
	ok(not lab2.disparar_rajada(), "ligada: disparar o glitch é recusado")
	for i in 6000:
		lab2.atualizar(0.1)
	ok(lab2.rajadas == 0 and not lab2.em_rajada, "ligada: 10 min de laboratório sem nenhuma rajada (%d)" % lab2.rajadas)

	# 9. a luz do fogo da aura (PointLight2D): energia tremeluz a 3 a 5 Hz desligada; fixa ligada
	zerar()
	armas = w.combate.armas
	armas.ativas = {"aura_teste": {"tipo": "aura", "R": 60.0}}
	var energia: Array = []
	for ligada in [false, true]:
		opcao(ligada)
		energia.clear()
		for q in QUADROS:
			armas._fase += PASSO
			armas._luzes(w.heroi, PASSO)
			energia.append(armas.luz_fogo.energy)
		var e := por_segundo(energia)
		if ligada:
			ok(e <= Piscadas.MAX_TROCAS_S, "ligada: a luz do fogo da aura troca %.1f vezes por segundo (máximo 3)" % e)
			ok(is_equal_approx(float(energia[0]), float(energia[QUADROS - 1])), "ligada: a energia da luz do fogo fica parada")
		else:
			ok(e > 3.0, "desligada: a luz do fogo da aura pisca (%.1f por segundo): o teste pega o defeito" % e)
	armas.ativas = {}
	armas.luz_fogo.enabled = false

	# 10. a carga prevalece sobre a invencibilidade: o corpo esquenta (quente = branco para (1, 0.85, 0.65)) mesmo com a opção ligada
	zerar()
	h = w.heroi
	opcao(true)
	h.estado = Heroi.Estado.CARGA
	h.rup_carga = 1.0
	h.invenc = 0.5
	h._visual(PASSO, Vector2.ZERO)
	var quente := Color.WHITE.lerp(Color(1.0, 0.85, 0.65), 1.0)
	ok(h.sprite.modulate.is_equal_approx(quente), "ligada: carregando e invencível, o corpo toma a cor da carga (deu %s)" % str(h.sprite.modulate))
	h.rup_carga = 0.5
	h._visual(PASSO, Vector2.ZERO)
	ok(
		h.sprite.modulate.is_equal_approx(Color.WHITE.lerp(Color(1.0, 0.85, 0.65), 0.5)),
		"ligada: o aquecimento da carga acompanha rup_carga (meia carga, meia cor)"
	)
	h.estado = Heroi.Estado.LIVRE
	h.rup_carga = 0.0
	h._visual(PASSO, Vector2.ZERO)
	ok(h.sprite.modulate.is_equal_approx(Piscadas.INVENCIVEL), "ligada: sem carga, invencível continua no tom fixo")

	opcao(false)
	Config.g_soltar_temporario()
	print("v2_piscadas falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
