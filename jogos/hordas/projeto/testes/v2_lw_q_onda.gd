extends "res://testes/isolamento_v2.gd"
# Teste da rodada 5 do Q do mecha (a Autodestruição do LightWolf), com os defeitos medidos no vídeo de 05/11:
#  1. CLARÃO DUPLO: o clarão de tela do estouro apagava durante o hit-stop e, logo depois, o cerco inteiro morria no MESMO quadro (a frente de onda a 2600 px/s
#     alcança um cerco de 150 px em 2 ou 3 quadros) e as nuvens de morte acendiam juntas num bloco claro: um par de piscadas a ~0,15 s. Agora o estouro não acende
#     clarão de tela e as mortes da limpeza deste Q saem em ONDA do centro, pela distância, ao longo de `limpa.espalha` s do mundo (v2/combate.gd `_espalhar_limpa`).
#  2. MECHA FANTASMA: o mecha vazio do fusível era desenhado na camada glow aditiva com alfa 0,3 a 0,9 (holograma ciano translúcido, viola o alfa 0/1) e crescia
#     10% (escala fracionária). Agora é arte opaca no nó do mundo (v2/especial.gd `_desenhar_casco`), com o aviso (contorno de 1 px e tom âmbar) ligando e desligando
#     abaixo de 2 Hz de relógio, e aceso parado com "Reduzir piscadas".
#     Na revisão: as nuvens de morte da onda saem no tom da fumaça (`limpa.tom_morte`), e o aviso conta em RELÓGIO (testado com o mundo a 1,5x).
#  3. A carga do chamado do Lobo: as mortes da limpeza do próprio Q (agora espalhadas) não enchem o chamado; ele fica nos 35 do começo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_lw_q_onda.tscn  (imprime "v2_lw_q_onda falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const PASSO := 1.0 / 60.0
const TIPOS := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_lobo_sombrio", "inimigo_espantalho"]

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func novo() -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.xp_proximo = 1.0e9  # sem subir de nível no meio: a escolha de cartas pausaria a onda de mortes
	w.heroi.entrada_forcada = Vector2.ZERO
	w.mouse_forcado = w.heroi.centro() + Vector2(200, 0)
	for i in 3:
		w.avancar(PASSO)
	w.cam.cravar(w.heroi.centro())


## O cerco do roteiro lw_q: `n` comuns numa elipse de 150 px em volta do herói (onde o mecha vai ficar).
func cercar(n: int) -> Array:
	var h = w.heroi
	var lista: Array = []
	for i in n:
		var a := TAU * float(i) / float(n)
		var m = w.nascer_monstro(TIPOS[i % TIPOS.size()], h.pos + Vector2(cos(a) * 150.0, sin(a) * 150.0 * 0.62), false)
		m.vida = 99999.0
		m.vida_max = 99999.0
		lista.append(m)
	return lista


func _ready() -> void:
	Config.temporario("reduzir_piscadas", false)
	Config.g_temporario("tremor_clarao", 100)
	Config.g_temporario("particulas_sim", "muitas")
	await _t_onda()
	await _t_casco(false)
	await _t_casco(true)
	Config.temporario("reduzir_piscadas", false)
	Herois.forcado = ""
	print("v2_lw_q_onda falhas=%d" % falhas)
	get_tree().quit()


func _t_onda() -> void:
	await novo()
	var c = w.combate
	var esp = c.especial
	var h = w.heroi
	var mons := cercar(24)
	for i in 2:
		w.avancar(PASSO)
	var centro: Vector2 = h.pos
	c.fx._cl_t = 9.0
	h.esp_carga = h.esp_carga_max
	ok(h.especial(), "o Q do mecha dispara")
	var f_estouro := -1
	for f in 120:
		w.avancar(PASSO)
		if esp.explosoes > 0:
			f_estouro = f
			break
	ok(f_estouro >= 0, "o mecha explodiu")
	ok(c.fx._cl_t >= c.fx._cl_dur, "o estouro não acende clarão de tela (o claro do impacto é só o miolo da bola)")
	# as mortes, quadro a quadro (relógio de 60 por segundo; o hit-stop congela o mundo e conta como quadro parado)
	var vivo: Dictionary = {}
	var d0: Dictionary = {}  # a distância de cada um ao mecha no estouro (a ordem da onda)
	for m in mons:
		vivo[m.get_instance_id()] = true
		d0[m.get_instance_id()] = (m.pos - centro).length()
	var mortes: Array = []  # [quadro, distância]
	var por_quadro: Array = []
	var carga_fim := -1.0  # o chamado no quadro da última morte do cerco
	var cf = c.fx_folha
	var toques0: int = cf.usados.tocar
	var xp0: float = w.xp_coletado
	var quadros := 0
	var plins_max := 0  # o máximo de brilhos de coleta (a alma de 9 px do orbe pego) vivos ao mesmo tempo
	var almas_max := 0  # o máximo de almas (brilho aditivo de 9 px) NASCIDAS DEPOIS da 1ª morte da onda e vivas ao mesmo tempo (as do estouro do mecha não contam)
	var f_1a := -1
	for f in 180:
		w.avancar(PASSO)
		quadros += 1
		var plins := 0
		for i in c.fx.MAX_PART:
			var kc: Color = c.fx.p_cor[i]
			if c.fx.p_vida[i] > 0.0 and c.fx.p_glow[i] == 1 and absf(kc.g - 0.95) < 0.01 and absf(kc.a - 0.7) < 0.01:
				plins += 1
		plins_max = maxi(plins_max, plins)
		if f_1a >= 0:
			var idade := float(f - f_1a) / 60.0 + 0.001
			var almas := 0
			for i in c.fx.MAX_PART:
				var k: Color = c.fx.p_cor[i]  # a cor da alma do estouro (o plim do orbe é outro brilho de 9 px)
				var alma := absf(k.g - 0.9) < 0.01 and absf(k.a - 0.6) < 0.01
				if alma and c.fx.p_vida[i] > 0.0 and c.fx.p_glow[i] == 1 and c.fx.p_tam[i] == 9.0 and c.fx.p_max[i] - c.fx.p_vida[i] < idade:
					almas += 1
			almas_max = maxi(almas_max, almas)
		var n := 0
		for m in mons:
			var id: int = m.get_instance_id()
			if vivo[id] and not m.vivo:
				vivo[id] = false
				n += 1
				mortes.append([f, float(d0[id])])
		por_quadro.append(n)
		if n > 0:
			carga_fim = h.esp_carga
			if f_1a < 0:
				f_1a = f - 1  # as almas da 1ª morte nasceram neste quadro
		if mortes.size() >= mons.size() and f > 90:  # (+0,5 s depois da onda: os orbes chegam ao herói)
			break
	# os orbes do cerco chegam ao herói quase juntos: o brilho aditivo da coleta (collect-burst e a alma de 9 px) não acende um por orbe, senão soma num bloco branco
	var toques: int = cf.usados.tocar - toques0
	ok(w.xp_coletado - xp0 > 5.0, "o herói pegou os orbes do cerco (%.0f de XP)" % (w.xp_coletado - xp0))
	ok(plins_max <= 1, "os brilhos de coleta não se somam (%d vivos no pico)" % plins_max)
	ok(toques <= quadros / 18 + 1, "o brilho da coleta sai no máximo 1 vez a cada 0,3 s (%d em %d quadros)" % [toques, quadros])
	ok(mortes.size() == mons.size(), "o Q matou o cerco inteiro (%d de %d)" % [mortes.size(), mons.size()])
	if mortes.size() < 2:
		return
	var pico := 0
	for n in por_quadro:
		pico = maxi(pico, n)
	var espalho := float(int(mortes[mortes.size() - 1][0]) - int(mortes[0][0])) / 60.0
	ok(pico <= 2, "no máximo 2 mortes do cerco no mesmo quadro (pico %d): o cerco não acende num bloco" % pico)
	ok(espalho >= 0.3, "as mortes se espalham por pelo menos 0,3 s de relógio (%.2f s)" % espalho)
	ok(espalho <= 0.6, "e acabam em até 0,6 s de relógio: leem como UM impacto (%.2f s)" % espalho)
	# em onda: quem morre depois está mais longe (ou à mesma distância)
	var fora_de_ordem := 0
	for i in range(1, mortes.size()):
		if float(mortes[i][1]) + 0.5 < float(mortes[i - 1][1]):
			fora_de_ordem += 1
	ok(fora_de_ordem == 0, "as mortes saem do centro para fora (%d fora de ordem)" % fora_de_ordem)
	# nenhum vão: entre a primeira e a última morte, nunca 6 quadros (0,1 s) seguidos sem morte (sem dois picos separados por um vale)
	var vao := 0
	var maior_vao := 0
	for f in range(int(mortes[0][0]), int(mortes[mortes.size() - 1][0]) + 1):
		vao = vao + 1 if por_quadro[f] == 0 else 0
		maior_vao = maxi(maior_vao, vao)
	ok(maior_vao < 6, "a onda de mortes é contínua, sem vale de 0,1 s no meio (maior vão %d quadros)" % maior_vao)
	# as nuvens de morte da limpeza deste Q: no tom da fumaça, não brancas. Elas duram mais que a onda e se somam; brancas, faziam um bloco claro logo
	# depois que a bola apaga na fumaça escura da cratera (claro-escuro-claro local a ~2,9 Hz no vídeo de 05/11, também com Reduzir piscadas)
	var nov = c.armas.novas
	var folha: Dictionary = preload("res://v2/anim_golpes.gd").de("fx_morte").get("impacto", {})
	var nuvens := 0
	var lum_max := 0.0
	for i in nov.MAX_FX:
		if nov.x_folha[i] == folha:
			nuvens += 1
			var k: Color = nov.x_cor[i]
			lum_max = maxf(lum_max, 0.299 * k.r + 0.587 * k.g + 0.114 * k.b)
	ok(nuvens >= 10, "as mortes da onda tocam a nuvem de morte (%d no pool)" % nuvens)
	ok(almas_max <= 2, "as mortes da onda não soltam almas no brilho aditivo (somadas viravam o bloco branco; %d nascidas na onda e vivas no pico)" % almas_max)
	ok(lum_max <= 0.45, "a nuvem de morte da limpeza do Q sai no tom da fumaça, sem branco cheio (luminância do tom %.2f, teto 0,45)" % lum_max)
	var inicio := float(esp.bloco_de("lightwolf").get("inicio_autodestruicao", esp.blocos.chamar.inicio_autodestruicao))
	ok(absf(carga_fim - inicio) < 0.01, "as mortes do próprio Q não enchem o chamado do Lobo (%.2f na última morte, começa em %.0f)" % [carga_fim, inicio])


## O mecha vazio no fusível: opaco, no nó do mundo, com o aviso abaixo de 2 Hz (ou aceso parado com "Reduzir piscadas").
func _t_casco(piscadas: bool) -> void:
	Config.temporario("reduzir_piscadas", piscadas)
	await novo()
	w.combate.velocidade = 1.5  # o mundo mais rápido que o relógio, como no jogo (velocidade_partida 1,25) e com folga: o aviso conta em relógio
	var esp = w.combate.especial
	var h = w.heroi
	var rot := " (Reduzir piscadas)" if piscadas else ""
	h.esp_carga = h.esp_carga_max
	ok(h.especial(), "o Q do mecha dispara" + rot)
	var casco = esp.get("no_casco")
	ok(casco != null, "o mecha vazio tem um nó próprio no mundo (no_casco)" + rot)
	ok(esp.has_method("casco_visivel") and esp.has_method("casco_alerta"), "o especial diz se o mecha vazio e o aviso estão à mostra" + rot)
	if casco == null or not esp.has_method("casco_alerta"):
		return
	ok(casco.get_parent() == w.no_mundo, "o mecha vazio fica no nó do mundo (y-sort com os atores), não na camada glow aditiva" + rot)
	var mat = casco.material
	ok(mat == null or not (mat is CanvasItemMaterial and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD), "o mecha vazio não é luz aditiva" + rot)
	ok(casco.modulate.a == 1.0 and casco.self_modulate.a == 1.0, "o nó do mecha vazio não tem alfa parcial" + rot)
	ok(casco.position == casco.position.round() and casco.scale == Vector2.ONE, "o mecha vazio fica em posição inteira e sem escala" + rot)
	var cont = esp.get("_g_contorno")
	ok(cont != null, "o contorno de alerta existe" + rot)
	if cont != null:
		var im: Image = cont.get_image()
		var meio := 0
		var opacos := 0
		for y in im.get_height():
			for x in im.get_width():
				var a := im.get_pixel(x, y).a
				if a > 0.999:
					opacos += 1
				elif a > 0.001:
					meio += 1
		ok(meio == 0 and opacos > 40, "o contorno é de pixels inteiros, alfa 0/1 (%d opacos, %d no meio)" % [opacos, meio] + rot)
	# o aviso durante o fusível, quadro a quadro de relógio
	var amostras: Array = []
	var visto := 0
	for f in 120:
		if esp.explosoes > 0:
			break
		if esp.casco_visivel():
			visto += 1
			amostras.append(1 if esp.casco_alerta() else 0)
		w.avancar(PASSO)
	ok(visto >= 30, "o mecha vazio fica à mostra no fusível (%d quadros)" % visto + rot)
	var trocas := 0
	var menor := 9999  # o menor meio-período em quadros de relógio (do aperto à 1ª troca e entre trocas): a frequência de verdade, não a média da janela
	var ultima := 0
	for i in range(1, amostras.size()):
		if amostras[i] != amostras[i - 1]:
			trocas += 1
			menor = mini(menor, i - ultima)
			ultima = i
	var hz := 0.5 * 60.0 / float(menor) if trocas > 0 else 0.0
	if piscadas:
		ok(trocas == 0 and amostras.size() > 0 and amostras[0] == 1, "com Reduzir piscadas o aviso fica aceso parado (%d trocas)" % trocas)
	else:
		ok(trocas >= 1, "o aviso pulsa (%d trocas)" % trocas)
		ok(hz <= 2.0, "o aviso pulsa a no máximo 2 Hz de relógio (%.2f Hz)" % hz)
	ok(not esp.casco_visivel(), "depois do estouro o mecha vazio some" + rot)
