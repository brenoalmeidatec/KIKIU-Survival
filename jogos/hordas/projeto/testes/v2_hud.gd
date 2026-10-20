extends Node
# Teste automático do HUD da v2 (v2/hud.tscn + v2/hud.gd). Monta o HUD sobre um "mundo" falso (heroi, abates, combo, tempo, monstros
# vivos e o sinal nivel_subiu), muda os valores e confere que barras e textos refletem; que o combo pulsa a cada abate, some quando zera
# e volta à posição de repouso; que o brilho do XP acende com nivel_subiu e apaga; que o HUD aguenta mundo nulo ou sem campos; que o
# canto superior direito (minimapa) fica livre; e que o HUD está no mundo da v2, acima da vinheta, fora da luz e com fonte sem AA.
# Leva de anúncios (seção 10): a faixa mostra um anúncio por vez e a fila segura o resto; os marcos de combo anunciam o mais alto
# cruzado; o nível faz pop no selo e anel de luz; a barra de chefe desce com a fantasma; a vinheta liga abaixo de 25% de vida;
# o relógio pisca ao virar o minuto; e um mundo só com nivel_subiu continua funcionando.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_hud.tscn  (imprime "v2_hud falhas=0")
# Prints: godot --path jogos/hordas/projeto res://testes/v2_hud.tscn -- --fotos=PASTA  (grava PNG do HUD sobre o mundo da v2 e sai)
const Mundo := preload("res://v2/mundo.tscn")
const Hud := preload("res://v2/hud.gd")
const StatusHud := preload("res://v2/status.gd")
const PASSO := 1.0 / 60.0
const ZONA_MINIMAPA := Rect2(800, 0, 160, 130)  # canto superior direito: o minimapa (de outro agente)

var falhas := 0


class Heroi:
	extends RefCounted
	var vida := 100.0
	var vida_max := 100.0
	var xp := 0.0
	var xp_proximo := 100.0
	var nivel := 1
	var folego := 100.0
	var folego_max := 100.0
	var cansado := false


class HeroiComRuptura:
	extends Heroi
	var rup_carga := 0.0
	var rup_recarga := 0.0
	var rup_recarga_max := 2.6
	var rup_perfeita := false
	var rup_nega_t := 0.0
	var contragolpe_t := 0.0
	var contragolpe_max := 1.5


class DiretorFalso:
	extends RefCounted
	var nivel := 1
	var niveis_total := 30
	var fracao := 0.0
	var trava := false
	var chefes_mapa: Array = [{"nivel": 10, "mk": {"mini": true}}, {"nivel": 30, "mk": {"mini": false}}]

	func fracao_mapa() -> float:
		return fracao

	func travado() -> bool:
		return trava


class CombateFalso:
	extends RefCounted
	var diretor := DiretorFalso.new()


class MundoFalso:
	extends RefCounted
	signal nivel_subiu(nivel)
	signal onda_forte(numero)
	signal elite_apareceu(nome)
	signal chefe_apareceu(nome, vida_max)
	signal chefe_vida(vida)
	signal evolucao(nome)
	signal anuncio(texto, cor)
	var heroi := Heroi.new()
	var abates := 0
	var combo := 0
	var tempo_partida := 0.0
	var monstros_vivos := 0
	var combate = null


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
		get_tree().quit()
		return
	_testes()
	print("v2_hud falhas=%d" % falhas)
	get_tree().quit()


func _testes() -> void:
	var vista := SubViewport.new()  # 960x540, como o mundo
	vista.size = Vector2i(960, 540)
	vista.disable_3d = true
	add_child(vista)
	var falso := MundoFalso.new()
	var hud = Hud.criar(falso)
	vista.add_child(hud)
	hud.set_process(false)  # os passos são nossos
	_teste_habilidades(hud, falso)

	# 0. placa do NÍVEL DO MAPA: escondida sem o diretor; com ele mostra "NÍVEL n/total", a barra anda e o chefe trava
	hud.avancar(PASSO)
	var placa: Control = hud.get_node("Raiz/Nivel")
	ok(not placa.visible, "sem diretor a placa do nível do mapa fica escondida")
	falso.combate = CombateFalso.new()
	var dir: DiretorFalso = falso.combate.diretor
	dir.nivel = 7
	dir.fracao = 6.5 / 29.0
	hud.avancar(PASSO)
	ok(placa.visible and placa.get_node("Barra").texto() == "NÍVEL 7/30", "a placa mostra NÍVEL 7/30")
	ok(placa.get_node("Barra").chefes.size() == 2 and not placa.get_node("Barra").travado, "duas marcas de chefe, nível livre")
	dir.nivel = 10
	dir.trava = true
	hud.avancar(PASSO)
	ok(placa.get_node("Barra").travado and placa.get_node("Barra").nivel == 10, "com o chefe vivo a placa mostra o nível travado")
	ok(placa.position.x + placa.size.x <= hud._relogio.get_parent().position.x + 4.0, "a placa fica à esquerda do relógio")
	# grade do topo: relógio, nível e abates alinhados (mesmo y e altura entre nível e abates, folga igual, número do nível do tamanho do relógio)
	var abates: Control = hud.get_node("Raiz/Abates")
	var tempo_q: Control = hud.get_node("Raiz/Tempo")
	ok(placa.position.y == abates.position.y and placa.size.y == abates.size.y, "o quadro do nível e o dos abates têm o mesmo y e a mesma altura")
	ok(abates.position.x - (placa.position.x + placa.size.x) == 4.0, "folga de 4 px entre o nível e os abates")
	ok(abates.position.y - (tempo_q.position.y + tempo_q.size.y) >= 4.0, "o quadro de baixo não encosta no relógio")
	var nv: Control = placa.get_node("Barra")
	ok(nv.TAM_NUMERO >= tempo_q.get_node("Relogio").get_theme_font_size("font_size"), "o número do nível é do tamanho do relógio")
	ok(nv._barra_y() + nv.BARRA_A + 1.0 <= placa.size.y - nv.BORDA, "a barra do mapa cabe dentro da borda de baixo")
	ok(nv.BORDA + 1.0 + float(nv.TAM_NUMERO) < nv._barra_y() - 1.0, "o número do nível não encosta na barra do mapa")
	# o minimapa e o retrato usam a mesma margem de canto (6 px)
	ok(
		preload("res://v2/minimapa.gd").MARGEM_TELA == 6 and hud.get_node("Raiz/Retrato").position == Vector2(6, 6),
		"minimapa e retrato com a mesma margem de 6 px"
	)
	# slots E/Q: borda direita na da faixa de XP, com folga em cima dela
	var xp_q: Control = hud.get_node("Raiz/Xp")
	var hab_q: Control = hud.get_node("Raiz/Habilidades")
	ok(hab_q.position.x + hab_q.size.x == xp_q.position.x + xp_q.size.x, "os slots E/Q terminam na mesma borda direita da faixa de XP")
	ok(xp_q.position.y - (hab_q.position.y + hab_q.size.y) >= 2.0, "os slots E/Q não encostam na faixa de XP")
	falso.combate = null

	# 1. sem combate: vida cheia, XP 0, nível 1, tempo zero, combo escondido
	hud.avancar(PASSO)
	ok(hud._vida_barra.value == 100.0 and hud._vida_barra.max_value == 100.0, "vida cheia sem combate")
	ok(hud._vida_txt.text == "100/100", "texto da vida sem combate: %s" % hud._vida_txt.text)
	ok(hud._xp_barra.value == 0.0, "XP zero sem combate")
	ok(hud._selo_num.text == "1", "nível 1 sem combate")
	ok(hud._folego.value == 100.0, "fôlego cheio sem combate")
	ok(hud._relogio.text == "00:00", "tempo zero no começo")
	ok(not hud._combo.visible, "combo escondido sem abate")
	ok(hud._abates.text == "ABATES 0\nVIVOS 0", "abates e vivos zerados")

	# 2. os valores mudam: barras e textos refletem; o combo aparece e pulsa a cada abate
	falso.heroi.vida = 50.0
	falso.heroi.folego = 30.0
	falso.heroi.xp = 40.0
	falso.heroi.xp_proximo = 80.0
	falso.heroi.nivel = 7
	falso.abates = 37
	falso.monstros_vivos = 12
	falso.combo = 12
	falso.tempo_partida = 452.0
	hud.avancar(PASSO)
	ok(hud._vida_barra.value == 50.0, "barra de vida reflete 50")
	ok(hud._vida_txt.text == "50/100", "texto da vida: %s" % hud._vida_txt.text)
	ok(hud._folego.value == 30.0, "barra de fôlego reflete 30")
	ok(hud._xp_barra.value > 0.0 and hud._xp_barra.value < 40.0, "as almas rolam até 40, não pulam: %s" % hud._xp_barra.value)
	ok(hud._xp_barra.max_value == 80.0, "barra de XP com máximo 80")
	ok(hud._selo_num.text == "7", "selo mostra o nível 7")
	ok(hud._relogio.text == "07:32", "tempo 452 s vira 07:32: %s" % hud._relogio.text)
	ok(hud._abates.text == "ABATES 37\nVIVOS 12", "abates e vivos: %s" % hud._abates.text)
	ok(hud._combo.visible and hud._combo_num.text == "x12", "combo x12 aparece")
	ok(hud.pulso > 0.0, "o combo pulsa quando sobe o número de abates")
	ok(hud._combo.position.y < hud._combo_y, "o pulso sobe o combo logo depois do abate")
	var inteiro := true
	for i in 20:
		hud.avancar(PASSO)
		inteiro = inteiro and hud._combo.position == hud._combo.position.round()
	ok(inteiro, "o combo fica em pixel inteiro durante o pulso")
	ok(hud.pulso == 0.0, "o pulso acaba em 0,25 s")
	ok(hud._combo.position.y == hud._combo_y, "o combo volta à posição de repouso")
	_passar(hud, 1.0)
	ok(hud._xp_barra.value == 40.0 and hud._xp_txt.text == "40/80", "as almas acabam de rolar em 40/80: %s" % hud._xp_txt.text)

	# 3. o combo some quando zera
	falso.combo = 0
	hud.avancar(PASSO)
	ok(not hud._combo.visible, "combo some quando zera")

	# 3b. herói cansado (corrida no Shift esgotou o fôlego): a barra de fôlego pisca em vermelho até recuperar
	falso.heroi.cansado = true
	var piscou := false
	var vermelho_so := true
	for i in 60:
		hud.avancar(PASSO)
		if hud._folego.modulate != Color.WHITE:
			piscou = true
			vermelho_so = vermelho_so and hud._folego.modulate.g < 1.0
	ok(piscou, "a barra de fôlego pisca quando o herói está cansado")
	ok(vermelho_so, "o pisca do cansado é vermelho-laranja, não outra cor")
	falso.heroi.cansado = false
	hud.avancar(PASSO)
	ok(hud._folego.modulate == Color.WHITE, "a barra de fôlego para de piscar ao recuperar")

	# 4. nivel_subiu acende o brilho do XP e apaga em 1,2 s
	ok(hud.brilho == 0.0, "sem brilho antes do nível novo")
	falso.nivel_subiu.emit(8)
	ok(hud.brilho > 0.0, "nivel_subiu acende o brilho do XP")
	var clareou := false
	for i in 36:
		hud.avancar(PASSO)
		clareou = clareou or hud._xp_barra.modulate != Color.WHITE
	ok(clareou, "o brilho clareia a barra de XP")
	ok(hud._selo.modulate == hud._xp_barra.modulate, "o selo clareia junto com a barra")
	for i in 54:
		hud.avancar(PASSO)
	ok(hud.brilho == 0.0 and hud._xp_barra.modulate == Color.WHITE, "o brilho apaga em 1,2 s")

	# 5. troca de mundo: o sinal sai do falso antigo e entra no novo
	var outro := MundoFalso.new()
	hud.ligar(outro)
	ok(not falso.nivel_subiu.is_connected(hud._nivel_subiu), "trocar de mundo desliga o sinal do antigo")
	ok(outro.nivel_subiu.is_connected(hud._nivel_subiu), "trocar de mundo liga o sinal do novo")

	# 6. mundo sem nenhum campo e sem sinal, e mundo nulo: valores padrão, sem erro
	var vazio := Node.new()
	var hud2 = Hud.criar(vazio)
	vista.add_child(hud2)
	hud2.set_process(false)
	hud2.avancar(PASSO)
	ok(hud2._vida_txt.text == "100/100" and hud2._selo_num.text == "1", "mundo sem campos mostra os valores padrão")
	ok(not hud2.mundo.has_signal("nivel_subiu"), "mundo sem sinal não ganha sinal")
	var hud3 = Hud.criar(null)
	vista.add_child(hud3)
	hud3.set_process(false)
	hud3.avancar(PASSO)
	ok(hud3._vida_txt.text == "100/100" and hud3._xp_barra.value == 0.0, "mundo nulo mostra os valores padrão")
	vazio.free()

	# 7. o HUD do mundo da v2: uma linha no mundo.gd cria o HUD na SubViewport, acima da vinheta
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	var real = w.ui.get_node_or_null("Hud")
	ok(real != null, "o mundo da v2 põe o HUD na SubViewport")
	if real != null:
		ok(real.layer == 10, "o HUD fica na layer 10 (acima da vinheta, 3, e do rótulo, 4)")
		ok(real.mundo == w, "o HUD da v2 lê o mundo da v2")
		for i in 30:
			w.avancar(PASSO)
		real.avancar(PASSO)
		ok(real._vida_txt.text == "100/100" and not real._combo.visible, "o HUD da v2 começa com vida cheia e sem combo")

	# 8. layout: tudo dentro de 960x540, em pixel inteiro, e o canto superior direito livre (minimapa)
	var raiz: Control = hud.get_node("Raiz")
	var fora := 0
	var no_minimapa := 0
	var quebrado := 0
	for c in raiz.get_children():
		if not c is Control or c.name == "Vinheta":  # a vinheta é a borda da tela inteira, não um bloco
			continue
		var r := Rect2(c.position, c.size)
		if not Rect2(0, 0, 960, 540).encloses(r):
			fora += 1
		if r.intersects(ZONA_MINIMAPA):
			no_minimapa += 1
		if c.position != c.position.round():
			quebrado += 1
	ok(fora == 0, "todo o HUD cabe em 960x540 (%d fora)" % fora)
	ok(no_minimapa == 0, "o canto superior direito fica livre para o minimapa (%d blocos)" % no_minimapa)
	ok(quebrado == 0, "posições em pixel inteiro (%d fora)" % quebrado)

	# 9. a luz do mundo não toca no HUD, e a fonte é a Atkinson (lisa, com anti-aliasing e hinting leve)
	var luz_ok := true
	for n in hud.find_children("*", "CanvasItem", true, false):
		if n.light_mask != 0:
			luz_ok = false
	ok(luz_ok, "nenhum item do HUD recebe luz do mundo")
	var fonte = raiz.get_theme_font("font")
	ok(fonte is FontFile and fonte.antialiasing == TextServer.FONT_ANTIALIASING_GRAY, "fonte do HUD com anti-aliasing")
	ok(fonte is FontFile and fonte.hinting == TextServer.HINTING_LIGHT, "fonte do HUD com hinting leve")

	# 10. anúncios, marcos de combo, chefe, vinheta, relógio e sinais que faltam no mundo
	_testes_anuncios(vista)
	_teste_barra_elite()
	_testes_rotulo_e_cartas()


## Main mostra E indisponível e Q não implementada; quando um herói publica os campos reais da Ruptura, o slot E lê esses números.
func _teste_habilidades(hud, mundo_falso: MundoFalso) -> void:
	var slots = hud.get_node("Raiz/Habilidades")
	slots.sincronizar(mundo_falso.heroi)
	ok(not slots.e_disponivel and not slots.e_pronta, "na main, E fica indisponível sem os campos da Ruptura")
	ok(not slots.q_implementada, "Q permanece não implementada, sem disponibilidade falsa")
	var h := HeroiComRuptura.new()
	h.rup_carga = 0.75
	h.rup_recarga = 1.3
	h.rup_recarga_max = 2.6
	h.rup_perfeita = true
	h.rup_nega_t = 0.2
	h.contragolpe_t = 0.75
	slots.sincronizar(h)
	ok(slots.e_disponivel and slots.estado_e == "ruptura", "E reconhece a Ruptura pelos campos reais do herói")
	ok(slots.carga_px == 15 and slots.recarga_px == 10, "E lê carga 75% e recarga 50% dos campos do herói")
	ok(slots.contragolpe_px == 10 and slots.perfeita and slots.negada, "E lê janela perfeita, negada e contragolpe")
	ok(not slots.q_implementada, "Q continua reservada mesmo com Ruptura disponível")
	ok(slots._rotulo_e() == "1.3 S", "E exibe os segundos reais de recarga")
	h.rup_recarga = 1.1
	slots.sincronizar(h)
	var px_recarga_11: int = slots.recarga_px
	h.rup_recarga = 1.0
	slots.sincronizar(h)
	ok(slots.recarga_px == px_recarga_11 and slots._rotulo_e() == "1.0 S", "texto da recarga atualiza mesmo sem mudança no pixel")
	h.rup_recarga = 0.0
	h.rup_carga = 0.24
	slots.sincronizar(h)
	var px_carga_24: int = slots.carga_px
	h.rup_carga = 0.25
	slots.sincronizar(h)
	ok(slots.carga_px == px_carga_24 and slots._rotulo_e() == "25%", "percentual da carga atualiza mesmo sem mudança no pixel")
	h.rup_carga = 0.75
	slots.sincronizar(h)
	ok(slots.e_pronta and slots._rotulo_e() == "75%", "E mostra carga e fica pronta ao zerar a recarga")
	h.rup_carga = 0.0
	slots.sincronizar(h)
	ok(slots._rotulo_e() == "RUPTURA", "E anuncia Ruptura pronta sem carga pendente")
	var area := Rect2(slots.position, slots.size)
	ok(area.position == Vector2(506, 434) and area.size == Vector2(174, 74), "E/Q ocupa a faixa inferior sem cobrir status/XP")
	ok(Rect2(0, 0, 960, 540).encloses(area), "E/Q cabe integralmente dentro da tela")
	ok(not area.intersects(ZONA_MINIMAPA), "E/Q não cobre o minimapa")
	var xp = hud.get_node("Raiz/Xp")
	var zona_xp := Rect2(xp.position, xp.size)
	ok(not area.intersects(zona_xp), "E/Q não cobre a faixa de XP real")
	ok(not area.intersects(StatusHud.COLUNAS_HUD[1]), "E/Q não cobre a coluna direita do status")


## Leva de interface: o texto de depuração (fps e atores) começa DESLIGADO na partida normal e a tecla F3 liga e desliga;
## com a escolha de carta (ou o baú) aberta, o HUD esconde o combo e a faixa de anúncio (o título grande fica no alto).
## A elite mostra vida sobre o sprite, atualiza dano, some ao morrer e não reaparece como monstro comum ao sair do pool.
func _teste_barra_elite() -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	var cfg: Dictionary = w.combate.elites.cfg
	var tipo: Dictionary = cfg.tipos[0]
	var mod: Dictionary = cfg.modificadores[0]
	var p: Vector2 = w.heroi.pos + Vector2(72.0, 0.0)
	var m = w.combate.elites.nascer(str(tipo.sprite), str(mod.id), p)
	ok(m != null, "o mundo cria elite para testar a barra")
	if m == null:
		w.queue_free()
		return
	var barra = m.barra_vida_elite
	ok(barra != null and barra.is_visible_in_tree(), "a barra nasce visível com a elite")
	if barra == null:
		w.queue_free()
		return
	var topo_visual: float = m.sprite.position.y + m.sprite.get_rect().position.y * m.sprite.scale.y
	ok(barra.position.y < topo_visual, "a barra fica acima do topo visual do sprite, com offset e escala")
	m.vida = m.vida_max * 0.4
	barra.sincronizar(m)
	ok(is_equal_approx(barra.fracao, 0.4), "a barra acompanha hp/hpmax da elite: %s" % barra.fracao)
	m.vida = 1.0
	w.combate.matar(m)
	ok(not barra.visible and not barra.is_visible_in_tree(), "a barra some quando a elite morre")
	var reutilizado = w.nascer_monstro(m.chave, p + Vector2(20.0, 0.0), true)
	ok(reutilizado == m, "a morte devolve o mesmo ator ao pool")
	ok(not barra.visible and not barra.is_visible_in_tree(), "a barra continua escondida quando o pool reutiliza o ator como comum")
	w.combate.elites.marcar(reutilizado, mod)
	barra.sincronizar(reutilizado)
	ok(barra.visible and barra.is_visible_in_tree() and is_equal_approx(barra.fracao, 1.0), "a barra volta cheia ao reutilizar o ator como elite")
	w.queue_free()


func _testes_rotulo_e_cartas() -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	ok(w._rotulo != null, "a partida livre monta o texto de depuração")
	ok(w._rotulo != null and not w._rotulo.visible, "o texto de depuração começa desligado na partida normal")
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_F3
	tecla.physical_keycode = KEY_F3
	tecla.pressed = true
	w._input(tecla)
	ok(w._rotulo != null and w._rotulo.visible, "F3 liga o texto de depuração")
	w._input(tecla)
	ok(w._rotulo != null and not w._rotulo.visible, "F3 desliga de novo")
	var real = w.ui.get_node_or_null("Hud")
	ok(real != null, "o mundo da v2 tem o HUD (para o teste da escolha)")
	if real != null:
		w.combo = 12
		real.avancar(PASSO)
		ok(real._combo.visible, "combo x12 aparece na partida")
		real._anuncio.anunciar("NÍVEL 3!", Color.WHITE)
		real.avancar(PASSO)
		ok(real._anuncio.visible, "a faixa de anúncio aparece na partida")
		w.combate.telas.escolha_aberta = true
		real.avancar(PASSO)
		ok(not real._combo.visible, "com a escolha aberta, o combo some")
		ok(not real._anuncio.visible, "com a escolha aberta, a faixa some")
		w.combate.telas.escolha_aberta = false
		w.combate.telas.bau_aberto = true
		real.avancar(PASSO)
		ok(not real._combo.visible and not real._anuncio.visible, "com o baú aberto, o combo e a faixa também somem")
		w.combate.telas.bau_aberto = false
		real.avancar(PASSO)
		ok(real._combo.visible, "o combo volta quando a escolha fecha")
	w.queue_free()


## Anúncios (faixa, fila, marcos, nível, sinal livre), barra de chefe com fantasma, vinheta de vida baixa e pisca do relógio.
func _testes_anuncios(vista: SubViewport) -> void:
	var f := MundoFalso.new()
	var h = Hud.criar(f)
	vista.add_child(h)
	h.set_process(false)
	h.avancar(PASSO)
	var an = h._anuncio

	# A. um anúncio por vez: entra com a cor do tipo, segura e sai
	f.onda_forte.emit(3)
	h.avancar(PASSO)
	ok(an.texto_ativo == "ONDA FORTE!" and an.visible, "ONDA FORTE! aparece na faixa")
	ok(an._texto.get_theme_color("font_color") == Hud.COR_ONDA, "ONDA FORTE! sai em vermelho")
	_passar(h, 1.0)
	ok(an.texto_ativo == "ONDA FORTE!" and an.visible, "o anúncio segura por cerca de 1,2 s")
	_passar(h, 1.0)
	ok(an.texto_ativo == "" and not an.visible, "o anúncio some depois de sair")

	# B. fila: os seguintes esperam e entram um de cada vez, sem sobrepor
	f.onda_forte.emit(1)
	f.elite_apareceu.emit("Lobo")
	f.evolucao.emit("Lança")
	h.avancar(PASSO)
	ok(an.texto_ativo == "ONDA FORTE!" and an.fila.size() == 2, "a fila segura os anúncios seguintes")
	_passar(h, 1.7)
	ok(an.texto_ativo == "ELITE!" and an.fila.size() == 1, "o próximo da fila entra quando o anterior sai")
	ok(an._texto.get_theme_color("font_color") == Hud.COR_ELITE, "ELITE! sai em roxo")
	_passar(h, 1.7)
	ok(an.texto_ativo == "EVOLUÇÃO: LANÇA" and an.fila.size() == 0, "EVOLUÇÃO: vem com o nome em caixa-alta")
	_passar(h, 2.0)
	ok(an.texto_ativo == "" and not an.ocupado(), "a fila esvazia e a faixa fica livre")

	# C. a fila tem limite: com muitos anúncios, sai o mais antigo
	for i in 8:
		f.anuncio.emit("X%d" % i, Color.WHITE)
	h.avancar(PASSO)
	ok(an.texto_ativo == "X0" and an.fila.size() == 5, "a fila para em 5 anúncios esperando")
	ok(an.fila[0]["texto"] == "X3", "a fila larga o mais antigo: %s" % an.fila[0]["texto"])
	_passar(h, 12.0)
	ok(not an.ocupado(), "a fila drena toda")

	# B2. (leva 6) a fusão abre o cartão grande com o nome e o que ela faz; a faixa pequena continua
	f.evolucao.emit("Anel de Brasas", "Seis lâminas em brasa.")
	ok(h._fusao != null and h._fusao.visible, "a fusão abre o cartão grande")
	ok(h._fusao_nome.text == "ANEL DE BRASAS" and h._fusao_desc.text == "Seis lâminas em brasa.", "o cartão grande leva o nome e o que faz")
	_passar(h, 12.0)  # a faixa da fusão sai da fila antes dos próximos testes de anúncio

	# D. marcos de combo: o anúncio é o mais alto cruzado, e cresce em intensidade
	var g := MundoFalso.new()
	var hg = Hud.criar(g)
	vista.add_child(hg)
	hg.set_process(false)
	hg.avancar(PASSO)
	var ag = hg._anuncio
	g.combo = 9
	hg.avancar(PASSO)
	ok(not ag.ocupado(), "abaixo de 10 não há anúncio de combo")
	g.combo = 10
	hg.avancar(PASSO)
	ok(ag.texto_ativo == "SEQUÊNCIA!", "marco 10 anuncia SEQUÊNCIA!")
	_passar(hg, 2.5)
	g.combo = 25
	hg.avancar(PASSO)
	ok(ag.texto_ativo == "CARNIFICINA!", "marco 25 anuncia CARNIFICINA!")
	_passar(hg, 2.5)
	g.combo = 0
	hg.avancar(PASSO)
	g.combo = 50
	hg.avancar(PASSO)
	ok(ag.texto_ativo == "MASSACRE!", "marco 50 anuncia MASSACRE!")
	ok(hg._combo_num.scale.x > 1.0, "o número do combo dá o soco de escala no abate")
	_passar(hg, 2.5)
	g.combo = 60
	hg.avancar(PASSO)
	ok(not ag.ocupado(), "sem cruzar marco novo, não há anúncio")
	g.combo = 0
	hg.avancar(PASSO)
	g.combo = 250
	hg.avancar(PASSO)
	ok(ag.texto_ativo == "LENDÁRIO!" and ag.fila.size() == 0, "de 0 a 250 num quadro, só o marco mais alto (LENDÁRIO!)")
	ok(ag.scale.x > 1.5, "o marco 200 entra maior que os outros: %s" % ag.scale.x)
	_passar(hg, 3.0)

	# E. nível: o anúncio NÍVEL N!, o pop do selo e o anel de luz
	f.nivel_subiu.emit(8)
	h.avancar(PASSO)
	ok(an.texto_ativo == "NÍVEL 8!", "nível novo anuncia NÍVEL 8!")
	ok(an._texto.get_theme_color("font_color") == Hud.COR_NIVEL, "NÍVEL N! sai em azul-claro")
	ok(h._anel.visible and h._selo.scale.x > 1.0, "o selo dá pop e o anel de luz sai")
	_passar(h, 0.6)
	ok(not h._anel.visible and h._selo.scale.x == 1.0, "o anel some em meio segundo e o selo volta ao tamanho")
	_passar(h, 3.0)

	# F. sinal livre: a cor vem do sinal (Color ou o texto de uma cor)
	f.anuncio.emit("PORTAL ABERTO", Color.GREEN)
	h.avancar(PASSO)
	ok(an.texto_ativo == "PORTAL ABERTO" and an._texto.get_theme_color("font_color") == Color.GREEN, "anúncio livre com a cor do sinal")
	f.anuncio.emit("OLÁ", "#ff0000")
	ok(an.fila.size() == 1 and an.fila[0]["cor"] == Color.RED, "cor em texto hexadecimal vira Color")
	_passar(h, 4.0)

	# G. chefe: a real cai na hora; a fantasma segura e desce devagar; some ao chegar a zero
	f.chefe_apareceu.emit("Guardião do bosque", 1000)
	h.avancar(PASSO)
	ok(h._chefe.visible and h._chefe_barra.max_value == 1000.0 and h._chefe_barra.value == 1000.0, "a barra do chefe aparece cheia")
	ok(h._chefe_nome.text == "GUARDIÃO DO BOSQUE", "o nome do chefe em caixa-alta: %s" % h._chefe_nome.text)
	f.chefe_vida.emit(500)
	h.avancar(PASSO)
	ok(h._chefe_barra.value == 500.0 and h._chefe_txt.text == "500/1000", "a barra real cai na hora: %s" % h._chefe_txt.text)
	ok(h._chefe_fantasma_barra.value == 1000.0, "a fantasma segura antes de descer")
	_passar(h, 0.6)
	var fantasma: float = h._chefe_fantasma_barra.value
	ok(fantasma < 1000.0 and fantasma > 500.0, "a fantasma desce atrás da real: %s" % fantasma)
	_passar(h, 10.0)
	ok(h._chefe_fantasma_barra.value == 500.0, "a fantasma chega à real e para")
	f.chefe_vida.emit(0)
	_passar(h, 10.0)
	ok(not h._chefe.visible, "o painel do chefe some quando ele chega a zero")

	# H. vida baixa: abaixo de 25%, a barra pisca e a vinheta liga; acima, a vinheta apaga
	f.heroi.vida = 20.0
	var piscou := false
	for i in 30:
		h.avancar(PASSO)
		piscou = piscou or h._vida_barra.modulate != Color.WHITE
	ok(piscou, "a barra de vida pisca abaixo de 25%")
	_passar(h, 0.5)
	ok(h.vinheta_alfa > 0.3 and h._vinheta.visible, "a vinheta liga abaixo de 25%%: %s" % h.vinheta_alfa)
	f.heroi.vida = 26.0
	_passar(h, 1.0)
	ok(h.vinheta_alfa == 0.0 and not h._vinheta.visible, "a vinheta apaga acima de 25%")
	ok(h._vida_barra.modulate == Color.WHITE, "a barra de vida para de piscar acima de 25%")

	# I. relógio: pisca dourado ao virar o minuto
	f.tempo_partida = 59.0
	h.avancar(PASSO)
	ok(h._relogio.modulate == Color.WHITE, "sem virar o minuto, o relógio fica branco")
	f.tempo_partida = 61.0
	h.avancar(PASSO)
	ok(h._relogio.modulate != Color.WHITE, "o tempo pisca dourado ao virar o minuto")
	_passar(h, 1.0)
	ok(h._relogio.modulate == Color.WHITE, "o pisca do tempo acaba")

	# J. mundo com só o nivel_subiu (o da v1 ou um antigo): anuncia o nível e não conecta o resto
	var s := MundoSoNivel.new()
	var hs = Hud.criar(s)
	vista.add_child(hs)
	hs.set_process(false)
	s.nivel_subiu.emit(3)
	hs.avancar(PASSO)
	ok(hs._anuncio.texto_ativo == "NÍVEL 3!", "com só nivel_subiu, o nível anuncia")
	ok(not s.has_signal("onda_forte") and not s.has_signal("chefe_apareceu"), "mundo sem os sinais novos não ganha sinais")
	hs.ligar(null)
	hs.avancar(PASSO)
	ok(hs._anuncio.texto_ativo == "NÍVEL 3!", "trocar para mundo nulo não derruba a faixa")


class MundoSoNivel:
	extends RefCounted
	signal nivel_subiu(nivel)


func _passar(h, segundos: float) -> void:
	for i in roundi(segundos / PASSO):
		h.avancar(PASSO)


## Prints do HUD sobre o mundo da v2, com valores falsos: começo, vida pela metade com combo x12 e nível 7, nível novo, e combo zerado.
func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	var falso := MundoFalso.new()
	w.ui.get_node("Hud").ligar(falso)
	for i in 60:
		w.avancar(PASSO)
	await _foto(w, pasta, "hud_inicio")
	var ecfg: Dictionary = w.combate.elites.cfg
	var elite = w.combate.elites.nascer(str(ecfg.tipos[0].sprite), str(ecfg.modificadores[0].id), w.heroi.pos + Vector2(72.0, 0.0))
	if elite != null:
		elite.vida = elite.vida_max * 0.56
		elite._visual_no(Vector2.ZERO)
		await get_tree().create_timer(0.3).timeout
		await _foto(w, pasta, "elite_barra_vida")
		w.combate.matar(elite)
	falso.heroi.vida = 50.0
	falso.heroi.folego = 35.0
	falso.heroi.xp = 60.0
	falso.heroi.xp_proximo = 120.0
	falso.heroi.nivel = 7
	falso.abates = 37
	falso.monstros_vivos = 12
	falso.combo = 12
	falso.tempo_partida = 452.0
	await get_tree().create_timer(0.5).timeout
	await _foto(w, pasta, "hud_vida_combo_nivel7")

	falso.nivel_subiu.emit(8)
	falso.heroi.nivel = 8
	falso.heroi.xp = 5.0
	await get_tree().create_timer(0.3).timeout
	await _foto(w, pasta, "hud_nivel_subiu")

	falso.combo = 0
	falso.heroi.vida = 100.0
	await get_tree().create_timer(0.5).timeout
	await _foto(w, pasta, "hud_combo_zerado")

	# Anúncios, chefe e vida baixa: um print de cada, com a faixa sozinha na tela.
	await get_tree().create_timer(2.0).timeout
	falso.onda_forte.emit(3)
	await get_tree().create_timer(0.5).timeout
	await _foto(w, pasta, "anuncio_onda_forte")

	await get_tree().create_timer(2.0).timeout
	falso.combo = 50
	await get_tree().create_timer(0.5).timeout
	await _foto(w, pasta, "anuncio_massacre_x50")

	await get_tree().create_timer(2.0).timeout
	falso.combo = 0
	falso.heroi.vida = 18.0
	await get_tree().create_timer(0.6).timeout
	await _foto(w, pasta, "vida_baixa_vinheta")

	falso.heroi.vida = 100.0
	await get_tree().create_timer(2.0).timeout
	falso.chefe_apareceu.emit("Guardião do bosque", 1000)
	falso.chefe_vida.emit(500)
	await get_tree().create_timer(0.8).timeout
	await _foto(w, pasta, "chefe_meia_com_fantasma")

	# Slots E e Q: herói com os campos da Ruptura. E em recarga (cortina) e E carregada (Q segue reservado: a mecânica não existe).
	var h2 := HeroiComRuptura.new()
	falso.heroi = h2
	falso.tempo_partida = 120.0
	h2.rup_recarga = 1.6
	await get_tree().create_timer(0.5).timeout
	await _foto(w, pasta, "hud_e_recarga")
	h2.rup_recarga = 0.0
	h2.rup_carga = 1.0
	await get_tree().create_timer(0.5).timeout
	await _foto(w, pasta, "hud_e_carga_cheia")

	# A barra do chefe das fotos acima segue no HUD falso: zera e espera ela sumir (a fantasma desce devagar) antes de o HUD ir para o mundo de verdade.
	falso.chefe_vida.emit(0)
	for i in 900:
		if not w.ui.get_node("Hud")._chefe.visible:
			break
		await get_tree().process_frame
	# Nível do mapa com o mundo de verdade ligado ao HUD: nível 14, com a barra andando, e o chefão do nível 30 em campo (nível travado).
	w.ui.get_node("Hud").ligar(w)
	w.combate.diretor.ir_para_nivel(14)
	w.combate.diretor.t_nivel = w.combate.diretor.seg_nivel() * 0.5
	await get_tree().create_timer(0.5).timeout
	await _foto(w, pasta, "hud_nivel_mapa_14")
	w.combate.diretor.ir_para_nivel(30)
	await get_tree().create_timer(0.8).timeout
	await _foto(w, pasta, "hud_nivel_mapa_30_chefao")


func _foto(w, pasta: String, nome: String) -> void:
	var tam = await w.ap.foto(pasta.path_join("%s.png" % nome))
	print("FOTO %s %s" % [nome, tam])
