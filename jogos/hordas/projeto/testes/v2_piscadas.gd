extends "res://testes/isolamento_v2.gd"
# Teste da opção "Reduzir piscadas" (#512, UI-2): o helper v2/piscadas.gd, a linha em Gráficos (que não vira Personalizado) e, numa partida de verdade,
# o que mais liga e desliga: a invencibilidade do herói, o fôlego cansado, a vida baixa e o chão anunciado. Cada série é amostrada por 3 s (180 quadros)
# e as trocas de luz são contadas. Desligada, o herói dá ~28 por segundo (prova que o teste pega o defeito); ligada, no máximo 3 por segundo.
# Também confere a luz do fogo da aura (energia fixa), a cor da carga sobre a invencibilidade e o cache da opção no Config. Também confere: clarão de tela, glitch do clima, flash de acerto (tinta fixa e sem repetir em 0,7 s; conta TROCAS de luminância, não flashes) e o flash da morte, que fica.
# Também: a granada (pavio, mira, disco do pavio estourando) e o aviso do meteoro/cometa em janela deslizante de 1 s, e os uniforms que congelam a explosão grande e a aura.
# Também: o brilho da barra de XP ao subir de nível e o escudo avermelhado de defesa baixa (cor fixa), a vinheta de vida baixa (alfa parado desde a entrada). Roda nos perfis Alto e Baixo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_piscadas.tscn  (imprime "v2_piscadas falhas=0")
# Não prova que PINTA: a medição na tela, em janela de verdade, é feita à parte (ver o PR).
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const Clima := preload("res://v2/clima.gd")
const Anim := preload("res://v2/anim_golpes.gd")
const HudHabilidades := preload("res://v2/hud_habilidades.gd")
const HudGolpes := preload("res://v2/hud_golpes.gd")
const HudNivel := preload("res://v2/hud_nivel.gd")
const AjustesGraficos := preload("res://v2/ajustes_graficos.gd")
const ArmasNovas := preload("res://v2/armas_novas.gd")
const PASSO := 1.0 / 60.0
const QUADROS := 180  # 3 s
const JANELA := 60  # 1 s em quadros: a janela deslizante da WCAG (no máximo 3 trocas em qualquer 1 s)
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


## Trocas por segundo de `f` (devolve número) amostrada no relógio de parede por `ms` ms (os HUDs de quadro lêem Time.get_ticks_msec).
func por_segundo_real(f: Callable, ms := 1200) -> float:
	var serie: Array = []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		serie.append(float(f.call()))
		OS.delay_msec(3)
	return float(Piscadas.trocas(serie)) / (float(ms) / 1000.0)


func _ready() -> void:
	for perfil in ["alto", "baixo"]:  # o perfil Baixo corta efeitos: nada que pisca pode voltar por lá
		rodar(perfil)
	opcao(false)
	Config.g_soltar_temporario()
	print("v2_piscadas falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func rodar(perfil: String) -> void:
	print("v2_piscadas perfil=", perfil)
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.hud.set_process(false)  # o HUD anda no passo do teste (hud.avancar), não no tempo de parede
	w.combate.audio.mudo = true
	Config.g_perfil_temporario(perfil)

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
	ok(
		Piscadas.FLASH_REPETE_S >= 1.0,
		"o intervalo do flash de acerto é de pelo menos 1,0 s (cada flash liga e desliga: 2 trocas; dois flashes a 1,0 s cabem 3 trocas numa janela de 1 s)"
	)
	ok(
		Piscadas.trocas_janela([0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0], 2) == 2 and Piscadas.trocas_janela([0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0], 2) == 2,
		"trocas_janela(): o máximo em qualquer janela, não a média"
	)
	ok(
		Piscadas.trocas_janela([0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0], 4) == 4 and Piscadas.trocas_janela([0.3, 0.3, 0.3], 2) == 0,
		"trocas_janela(): conta 4 numa janela de 4 e ignora série parada"
	)
	# o cache do Config acompanha a opção em definir(), temporario() e recarregar()
	Config.definir(Piscadas.OPCAO, true)
	ok(Config.reduzir_piscadas and Piscadas.ligado(), "o cache do Config liga com definir()")
	Config.temporario(Piscadas.OPCAO, false)
	ok(not Config.reduzir_piscadas and not Piscadas.ligado(), "o cache do Config desliga com temporario()")
	Config.recarregar()
	ok(Config.reduzir_piscadas == bool(Config.v(Piscadas.OPCAO)) and Piscadas.ligado(), "o cache do Config volta ao arquivo com recarregar()")
	Config.definir(Piscadas.OPCAO, false)
	ok(not Config.reduzir_piscadas, "o cache do Config desliga com definir()")
	Config.g_perfil_temporario(perfil)

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
	Config.g_aplicar_perfil(perfil)

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
		w.hud.vinheta_alfa = 0.0  # cada rodada entra do zero (a anterior deixou a vinheta pulsando)
		w.hud._tempo_vinheta = 0.0
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
			var sobe_so := true
			for q in range(1, vinheta.size()):
				sobe_so = sobe_so and float(vinheta[q]) >= float(vinheta[q - 1]) - 0.00001
			ok(sobe_so, "ligada: a vinheta de vida baixa só sobe até o alfa fixo, sem descer no meio (nem na entrada)")
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
	ok(fx._cl_t < fx._cl_dur or not Anim.suave, "desligada: o clarão acende (o perfil Baixo, sem animação suave, nem o tem)")
	fx._cl_t = 9.0
	opcao(true)
	fx.clarao(Color(0.8, 0.85, 1.0, 0.25), 0.15)
	ok(fx._cl_t >= 9.0, "ligada: o clarão de tela não acende")

	# 7. flash de acerto: tinta fixa, sem repetir no mesmo monstro em menos de 1,0 s; o da morte fica
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
	ok(fx.usados.flashes - antes == 1, "ligada: o mesmo monstro não leva outro flash em 1,0 s")
	fx.flash(outro, 0.1)
	ok(fx.usados.flashes - antes == 2, "ligada: outro monstro leva o flash normalmente")
	passos(52)  # passou de 1,0 s desde o primeiro (1,03 s)
	fx.flash(mo, 0.1)
	ok(fx.usados.flashes - antes == 3, "ligada: depois de 1,0 s o mesmo monstro leva de novo")
	var fixo := false
	for s in fx._fl:
		if s.visible and s.material != null and is_equal_approx(float((s.material as ShaderMaterial).get_shader_parameter("k")), Piscadas.FLASH_ALFA):
			fixo = true
	ok(fixo, "ligada: o flash de acerto é tinta de alfa %.1f" % Piscadas.FLASH_ALFA)
	antes = fx.usados.flashes
	fx.flash(mo, 0.24, Color.WHITE, 1)
	fx.flash(mo, 0.24, Color.WHITE, 1)
	ok(fx.usados.flashes - antes == 2, "ligada: o flash da morte fica (não é cortado)")

	# 7b. TROCAS de luminância (não flashes): tentando um flash por quadro no mesmo monstro por 6 s, o disco de tinta liga e desliga; cada flash são 2 trocas
	# (com 0,34 s: ~6 trocas por segundo, o defeito da rodada 2; com 0,7 s a média dava 2,9 mas a janela de 1 s pegava 4, o da rodada 3)
	zerar()
	mo = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(120, 0))
	opcao(true)
	var tinta: Array = []
	for q in 360:
		fx.flash(mo, 0.1)
		passos(1)
		var lum_f := 0.0
		for j in fx._fl.size():
			if fx._fl[j].visible and fx._fl_alvo[j] == mo:
				lum_f = maxf(lum_f, float((fx._fl[j].material as ShaderMaterial).get_shader_parameter("k")))
		tinta.append(lum_f)
	var trocas_flash := por_segundo(tinta)
	var pior_flash := Piscadas.trocas_janela(tinta, JANELA)
	ok(trocas_flash > 0.0, "ligada: o flash de acerto acende de vez em quando (%.1f trocas por segundo)" % trocas_flash)
	ok(trocas_flash <= Piscadas.MAX_TROCAS_S, "ligada: o mesmo monstro apanhando sem parar troca a luminância %.1f vezes por segundo (máximo 3)" % trocas_flash)
	ok(
		pior_flash <= int(Piscadas.MAX_TROCAS_S),
		"ligada: em QUALQUER janela de 1 s o flash de acerto troca %d vezes (máximo 3; a média não basta)" % pior_flash
	)
	# a borda: aos 0,983 s (59 quadros) ainda é barrado; aos 1,017 s (61) passa
	zerar()
	mo = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(120, 0))
	antes = fx.usados.flashes
	fx.flash(mo, 0.1)
	passos(59)
	fx.flash(mo, 0.1)
	ok(fx.usados.flashes - antes == 1, "ligada: aos 0,983 s o mesmo monstro ainda não leva outro flash (a borda)")
	passos(2)
	fx.flash(mo, 0.1)
	ok(fx.usados.flashes - antes == 2, "ligada: aos 1,017 s o mesmo monstro leva de novo")

	# 7e. a marca sustentada do golpe forte (modo 3, 0,45 s cheia): golpes fortes a cada 0,5 s no mesmo monstro ligavam e desligavam a silhueta
	# ~4 vezes por segundo. Ligada, a marca passa pelo mesmo intervalo do flash de acerto; o flash e a marca do MESMO golpe se fundem (um liga e desliga só).
	zerar()
	mo = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(120, 0))
	opcao(true)
	antes = fx.usados.flashes
	var marcas_antes: int = fx.usados.marcas
	fx.flash(mo, 0.1)
	fx.flash(mo, 0.45, Color.WHITE, 3)
	ok(fx.usados.flashes - antes == 2 and fx.usados.marcas - marcas_antes == 1, "ligada: o flash e a marca do mesmo golpe passam juntos")
	passos(10)
	fx.flash(mo, 0.45, Color.WHITE, 3)
	ok(fx.usados.marcas - marcas_antes == 1, "ligada: outra marca no mesmo monstro em menos de 1,0 s é barrada")
	zerar()
	mo = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(120, 0))
	var sil: Array = []
	for q in 360:  # golpe forte a cada 0,5 s por 6 s
		if q % 30 == 0:
			fx.flash(mo, 0.1)
			fx.flash(mo, 0.45, Color.WHITE, 3)
		passos(1)
		var acesa := 0.0
		for j in fx._fl.size():
			if fx._fl[j].visible and fx._fl_alvo[j] == mo:
				acesa = 1.0
		sil.append(acesa)
	var pior_sil := Piscadas.trocas_janela(sil, JANELA)
	ok(pior_sil > 0, "ligada: a marca do golpe forte acende de vez em quando")
	ok(
		pior_sil <= int(Piscadas.MAX_TROCAS_S),
		"ligada: golpes fortes a cada 0,5 s ligam e desligam a silhueta %d vezes na pior janela de 1 s (máximo 3)" % pior_sil
	)

	# 7c. o anel de alvos: 60 outros acertos dentro de 1,0 s não apagam o primeiro (com o anel de 48 ele era sobrescrito e levava flash de novo)
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
	passos(1)  # no mesmo quadro valeria a fusão do flash com a marca do mesmo golpe
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

	# 11. o brilho da barra de XP ao subir de nível (sin(brilho*16), ~2,5 Hz): oscila desligado; ligado, tom parado e uma subida e uma descida só
	zerar()
	var hud = w.hud
	var xp_lum: Array = []
	var xp_selo_igual := true
	for ligada in [false, true]:
		opcao(ligada)
		xp_lum.clear()
		hud.brilho = hud.BRILHO_T
		for q in int(hud.BRILHO_T / PASSO):
			passos(1)
			xp_lum.append(Piscadas.luminancia(hud._xp_barra.modulate))
			xp_selo_igual = xp_selo_igual and hud._selo.modulate.is_equal_approx(hud._xp_barra.modulate)
		var tx := por_segundo(xp_lum)
		if ligada:
			ok(tx <= Piscadas.MAX_TROCAS_S, "ligada: o brilho da barra de XP troca %.1f vezes por segundo (máximo 3)" % tx)
			var parado := xp_lum.slice(0, xp_lum.size() - 2)  # menos o último quadro, em que o brilho acaba
			ok(
				float(parado.max()) - float(parado.min()) < 0.0001 and float(parado.min()) > float(xp_lum.back()),
				"ligada: a barra de XP fica num tom fixo enquanto o brilho dura (variou %.4f)" % (float(parado.max()) - float(parado.min()))
			)
		else:
			ok(tx > Piscadas.MAX_TROCAS_S, "desligada: o brilho da barra de XP pisca (%.1f por segundo): o teste pega o defeito" % tx)
	ok(xp_selo_igual, "o selo do nível acompanha a barra de XP (mesmo tom)")
	hud.brilho = 0.0

	# 12. o escudo de defesa baixa, de lado (não há quadro rachado): o aviso avermelhado pulsava a ~2,2 Hz; ligado, vermelho parado
	# DEF-2: o escudo é só do Nick; o aviso do escudo é testado no herói padrão, a quem o dado devolve o escudo neste teste (antes do reiniciar, que monta o sprite)
	w.combate.escudo.herois["hazaki"] = "escudo"
	zerar()
	h = w.heroi
	var esc = w.combate.escudo
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	var esc_lum: Array = []
	var esc_cor: Array = []
	for ligada in [false, true]:
		opcao(ligada)
		esc_lum.clear()
		esc_cor.clear()
		for q in QUADROS:
			h.escudo_forcado = true
			h.def = h.def_max * 0.2
			passos(1)
			w.combate.efeitos(PASSO)
			esc_lum.append(Piscadas.luminancia(esc._spr.modulate))
			esc_cor.append(esc._spr.modulate)
		var te := por_segundo(esc_lum.slice(QUADROS / 3))
		if ligada:
			ok(not esc.visual_estado().rachado and esc.visual_estado().aviso, "o escudo de lado em defesa baixa está no aviso avermelhado")
			ok(te <= Piscadas.MAX_TROCAS_S, "ligada: o escudo de defesa baixa troca %.1f vezes por segundo (máximo 3)" % te)
			var c0: Color = esc_cor[QUADROS / 3]
			var parado_e := true
			for c in esc_cor.slice(QUADROS / 3):
				parado_e = parado_e and (c as Color).is_equal_approx(c0)
			ok(parado_e and c0.r > c0.g and c0.r > c0.b, "ligada: o escudo de defesa baixa fica num vermelho parado (%s)" % str(c0))
		else:
			ok(te > Piscadas.MAX_TROCAS_S, "desligada: o escudo de defesa baixa pisca (%.1f por segundo): o teste pega o defeito" % te)
	h.escudo_forcado = false
	h.def = h.def_max

	# 13. os outros pulsos de HUD e de anel: a E em andamento e o escudo erguido (3,1 Hz), a janela perfeita da ruptura (10 Hz), o losango de fusão (2 Hz),
	# a ponta travada da barra de nível (2 Hz, vermelha) e o pulso(): desligados trocam mais de 3 vezes por segundo; ligados, parados.
	var hh = HudHabilidades.new()
	hh.e_disponivel = true
	hh.e_pronta = true
	hh.perfeita = true
	var hg = HudGolpes.new()
	var hn = HudNivel.new()
	hn.travado = true
	for ligada in [false, true]:
		opcao(ligada)
		var r_pulsa := por_segundo_real(func(): return 1.0 if hh._pulsa() else 0.0)
		var r_perf := por_segundo_real(func(): return Piscadas.luminancia(hh._cor_do_card(true, false)))
		var r_quase := por_segundo_real(func(): return hg._fase_quase_agora())
		var r_ponta: Array = []
		for q in QUADROS:
			hn._pisca = float(q) * PASSO
			r_ponta.append(1.0 if hn._ponta_acesa() else 0.0)
		var r_p: Array = []
		for q in QUADROS:
			r_p.append(Piscadas.pulso(float(q) * PASSO, 2.0))
		var rp := por_segundo(r_ponta)
		var rq := por_segundo(r_p)
		if ligada:
			ok(r_pulsa == 0.0, "ligada: o quadro da E/escudo em andamento fica parado (%.1f trocas por segundo)" % r_pulsa)
			ok(r_perf == 0.0, "ligada: o quadro da E na janela perfeita fica parado (%.1f trocas por segundo)" % r_perf)
			ok(r_quase == 0.0, "ligada: o losango de fusão quase pronta fica parado (%.1f trocas por segundo)" % r_quase)
			ok(rp == 0.0, "ligada: a ponta travada da barra de nível fica vermelha e parada (%.1f trocas por segundo)" % rp)
			ok(rq == 0.0, "ligada: pulso() fica parado (%.1f trocas por segundo)" % rq)
		else:
			ok(r_pulsa > Piscadas.MAX_TROCAS_S, "desligada: o quadro em andamento pulsa (%.1f por segundo): o teste pega o defeito" % r_pulsa)
			ok(r_perf > Piscadas.MAX_TROCAS_S, "desligada: o quadro da janela perfeita pisca (%.1f por segundo): o teste pega o defeito" % r_perf)
			ok(r_quase > Piscadas.MAX_TROCAS_S, "desligada: o losango de fusão pisca (%.1f por segundo): o teste pega o defeito" % r_quase)
			ok(rp > Piscadas.MAX_TROCAS_S, "desligada: a ponta travada pisca (%.1f por segundo): o teste pega o defeito" % rp)
			ok(rq > Piscadas.MAX_TROCAS_S, "desligada: pulso() oscila (%.1f por segundo): o teste pega o defeito" % rq)
	hh.free()
	hg.free()
	hn.free()

	# 14. a granada (pavio, mira no chão, disco branco do pavio estourando) e o aviso do meteoro/cometa: ~2,9, ~1,9, 6 a 24 e ~1,9 Hz.
	# Janela deslizante de 1 s sobre 3 s de fase (it.fase anda 6 rad/s). Desligadas passam de 3 trocas; ligadas, o centro da faixa parado.
	var fases: Array = []
	for q in QUADROS:
		fases.append(float(q) * PASSO * 6.0)
	for ligada in [false, true]:
		opcao(ligada)
		var s_pavio: Array = []
		var s_mira: Array = []
		var s_aviso: Array = []
		var s_estoura: Array = []
		for q in QUADROS:
			s_pavio.append(ArmasNovas.alfa_pavio(fases[q]))
			s_mira.append(ArmasNovas.pulso_mira(fases[q]))
			s_aviso.append(0.5 + 0.4 * ArmasNovas.pisca_aviso(fases[q]))  # o alfa do arco do aviso, como o desenho monta
		for q in 30:  # os 0,5 s do pavio estourando, a 60 quadros por segundo
			s_estoura.append(ArmasNovas.alfa_pavio_estourando(float(q) * PASSO, float(q) * PASSO / 0.5))
		var w_pavio := Piscadas.trocas_janela(s_pavio, JANELA)
		var w_mira := Piscadas.trocas_janela(s_mira, JANELA)
		var w_aviso := Piscadas.trocas_janela(s_aviso, JANELA)
		var w_estoura := Piscadas.trocas_janela(s_estoura, JANELA)
		if ligada:
			ok(w_pavio <= 3, "ligada: a faísca do pavio da granada troca %d vezes na pior janela de 1 s (máximo 3)" % w_pavio)
			ok(w_mira <= 3, "ligada: a mira no chão da granada troca %d vezes na pior janela de 1 s (máximo 3)" % w_mira)
			ok(w_aviso <= 3, "ligada: o aviso do meteoro/cometa troca %d vezes na pior janela de 1 s (máximo 3)" % w_aviso)
			ok(w_estoura <= 3, "ligada: o disco branco do pavio estourando troca %d vezes na pior janela de 1 s (máximo 3)" % w_estoura)
			ok(is_equal_approx(float(s_pavio[0]), 0.7) and is_equal_approx(float(s_pavio[77]), 0.7), "ligada: o pavio fica no centro da faixa (0,7)")
			ok(is_equal_approx(float(s_mira[0]), 0.8) and is_equal_approx(float(s_mira[77]), 0.8), "ligada: a mira fica no centro da faixa (0,8)")
			ok(is_equal_approx(float(s_aviso[0]), 0.7) and is_equal_approx(float(s_aviso[77]), 0.7), "ligada: o arco do aviso fica no centro da faixa (0,7)")
		else:
			ok(w_pavio > 3, "desligada: a faísca do pavio pisca (%d trocas na pior janela de 1 s): o teste pega o defeito" % w_pavio)
			ok(w_mira > 3, "desligada: a mira no chão da granada pisca (%d trocas na pior janela de 1 s): o teste pega o defeito" % w_mira)
			ok(w_aviso > 3, "desligada: o aviso do meteoro/cometa pisca (%d trocas na pior janela de 1 s): o teste pega o defeito" % w_aviso)
			ok(w_estoura > 3, "desligada: o disco do pavio estourando pisca (%d trocas na pior janela de 1 s): o teste pega o defeito" % w_estoura)

	# 15. os dois shaders que cintilam por pixel: a explosão grande (anéis girando a 1,4 a 2,5 Hz) e a aura de fogo (1,1 e 1,75 Hz). Ligada, o uniform congela:
	# a explosão sobe `calmo` = 1 e a aura passa t = 0 e pulso = 0 (a chama não gira nem pulsa). Desligada, `calmo` = 0 e t anda com a fase.
	zerar()
	fx = w.combate.fx
	armas = w.combate.armas
	for ligada in [false, true]:
		opcao(ligada)
		armas.ativas = {"aura_teste": {"tipo": "aura", "R": 60.0, "cor": Color(1.0, 0.5, 0.15), "pulso": 0.6}}
		armas._fase = 3.0
		armas._aura_visual(w.heroi)
		var mat_a := armas._aura_sp.material as ShaderMaterial
		if ligada:
			ok(
				is_equal_approx(float(mat_a.get_shader_parameter("t")), 0.0) and is_equal_approx(float(mat_a.get_shader_parameter("pulso")), 0.0),
				"ligada: a aura de fogo não gira nem pulsa (t e pulso zerados)"
			)
		else:
			ok(
				is_equal_approx(float(mat_a.get_shader_parameter("t")), 3.0) and float(mat_a.get_shader_parameter("pulso")) > 0.5,
				"desligada: a aura de fogo gira e pulsa (t = fase)"
			)
		armas.ativas = {}  # a aura falsa não anda no passo do mundo (faltam campos): só o _aura_visual acima a usou
		if Anim.suave:  # o perfil Baixo não tem explosão grande
			fx.explosao(w.heroi.pos + Vector2(80, 0), 60.0, Color(1.0, 0.5, 0.2))
			passos(2)
			var vistas := 0
			for sp in fx._ex:
				if sp.visible:
					vistas += 1
					var calmo := float((sp.material as ShaderMaterial).get_shader_parameter("calmo"))
					ok(is_equal_approx(calmo, 1.0 if ligada else 0.0), "%s: a explosão grande tem calmo=%.0f" % ["ligada" if ligada else "desligada", calmo])
			ok(vistas > 0, "a explosão grande nasceu (%d)" % vistas)
	armas._aura_sp.visible = false

	pai.free()
	w.free()
