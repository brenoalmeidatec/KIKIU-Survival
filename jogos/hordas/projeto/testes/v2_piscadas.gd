extends "res://testes/isolamento_v2.gd"
# Teste da opção "Reduzir piscadas" (#512, UI-2): o helper v2/piscadas.gd, a linha em Gráficos (que não vira Personalizado) e, numa partida de verdade,
# o que mais liga e desliga: a invencibilidade do herói, o fôlego cansado, a vida baixa e o chão anunciado. Cada série é amostrada por 3 s (180 quadros)
# e as trocas de luz são contadas. Desligada, o herói dá ~28 por segundo (prova que o teste pega o defeito); ligada, no máximo 3 por segundo.
# Também confere: clarão de tela, glitch do clima, flash de acerto (tinta fixa e sem repetir em 0,33 s) e o flash da morte, que fica.
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
	ok(Piscadas.trocas([0.0, 1.0, 0.0, 1.0, 0.0]) == 4 and Piscadas.trocas([0.5, 0.5, 0.51]) == 0, "trocas(): conta os cruzamentos e ignora série parada")

	# 2. a linha em Gráficos: liga e desliga e NÃO vira Personalizado
	opcao(false)
	Config.g_aplicar_perfil("medio")
	var aj := AjustesGraficos.new()
	var achou := false
	for it in aj.itens():
		if str(it.id) == "g:piscadas":
			achou = str(it.rotulo) == "Reduzir piscadas" and str(it.valor) == "Não"
	ok(achou, "Gráficos tem a linha Reduzir piscadas: Não")
	aj.agir("piscadas", 1)
	ok(Piscadas.ligado() and Config.g_perfil() == "medio", "a linha liga a opção e o perfil continua Médio (não vira Personalizado)")
	aj.agir("piscadas", 1)
	ok(not Piscadas.ligado() and Config.g_perfil() == "medio", "a linha desliga a opção e o perfil continua Médio")
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
		else:
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
	ok(fx.usados.flashes - antes == 1, "ligada: o mesmo monstro não leva outro flash em 0,33 s")
	fx.flash(outro, 0.1)
	ok(fx.usados.flashes - antes == 2, "ligada: outro monstro leva o flash normalmente")
	passos(12)  # passou de 0,33 s desde o primeiro
	fx.flash(mo, 0.1)
	ok(fx.usados.flashes - antes == 3, "ligada: depois de 0,33 s o mesmo monstro leva de novo")
	var fixo := false
	for s in fx._fl:
		if s.visible and s.material != null and is_equal_approx(float((s.material as ShaderMaterial).get_shader_parameter("k")), Piscadas.FLASH_ALFA):
			fixo = true
	ok(fixo, "ligada: o flash de acerto é tinta de alfa %.1f" % Piscadas.FLASH_ALFA)
	antes = fx.usados.flashes
	fx.flash(mo, 0.24, Color.WHITE, 1)
	fx.flash(mo, 0.24, Color.WHITE, 1)
	ok(fx.usados.flashes - antes == 2, "ligada: o flash da morte fica (não é cortado)")

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

	opcao(false)
	Config.g_soltar_temporario()
	print("v2_piscadas falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
