extends Node
# Teste automático do HUD da v2 (v2/hud.tscn + v2/hud.gd). Monta o HUD sobre um "mundo" falso (heroi, abates, combo, tempo, monstros
# vivos e o sinal nivel_subiu), muda os valores e confere que barras e textos refletem; que o combo pulsa a cada abate, some quando zera
# e volta à posição de repouso; que o brilho do XP acende com nivel_subiu e apaga; que o HUD aguenta mundo nulo ou sem campos; que o
# canto superior direito (minimapa) fica livre; e que o HUD está no mundo da v2, acima da vinheta, fora da luz e com fonte sem AA.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_hud.tscn  (imprime "v2_hud falhas=0")
# Prints: godot --path jogos/hordas/projeto res://testes/v2_hud.tscn -- --fotos=PASTA  (grava PNG do HUD sobre o mundo da v2 e sai)
const Mundo := preload("res://v2/mundo.tscn")
const Hud := preload("res://v2/hud.gd")
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


class MundoFalso:
	extends RefCounted
	signal nivel_subiu(nivel)
	var heroi := Heroi.new()
	var abates := 0
	var combo := 0
	var tempo_partida := 0.0
	var monstros_vivos := 0


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
	ok(hud._xp_barra.value == 40.0 and hud._xp_barra.max_value == 80.0, "barra de XP reflete 40 de 80")
	ok(hud._xp_txt.text == "40/80", "texto do XP: %s" % hud._xp_txt.text)
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
	var real = w.sv.get_node_or_null("Hud")
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
		if not c is Control:
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

	# 9. a luz do mundo não toca no HUD, e a fonte é a do jogo sem anti-aliasing e sem hinting
	var luz_ok := true
	for n in hud.find_children("*", "CanvasItem", true, false):
		if n.light_mask != 0:
			luz_ok = false
	ok(luz_ok, "nenhum item do HUD recebe luz do mundo")
	var fonte = raiz.get_theme_font("font")
	ok(fonte is FontFile and fonte.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "fonte do HUD sem anti-aliasing")
	ok(fonte is FontFile and fonte.hinting == TextServer.HINTING_NONE, "fonte do HUD sem hinting")


## Prints do HUD sobre o mundo da v2, com valores falsos: começo, vida pela metade com combo x12 e nível 7, nível novo, e combo zerado.
func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	var falso := MundoFalso.new()
	w.sv.get_node("Hud").ligar(falso)
	for i in 60:
		w.avancar(PASSO)
	await _foto(w, pasta, "hud_inicio")

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


func _foto(w, pasta: String, nome: String) -> void:
	var tam = await w.ap.foto(pasta.path_join("%s.png" % nome))
	print("FOTO %s %s" % [nome, tam])
