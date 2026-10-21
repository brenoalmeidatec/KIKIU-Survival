extends Node
# Teste automático do LAYOUT do HUD da partida no estilo Overwatch (v2/hud.tscn, hud.gd, hud_habilidades.gd, hud_ultimate.gd): vida e fôlego no canto de baixo
# à esquerda, o Q em círculo no centro acima do XP, o E e o secundário no canto de baixo à direita. Confere que NENHUM bloco do HUD cobre outro (retrato e barras,
# faixa de golpes, tempo, abates, nível do mapa, combo, barra do chefe, anúncio, XP, Q, E/secundário, minimapa) em 960x540 e nas telas maiores (16:9 e 21:9, em todos
# os tamanhos de interface), que as barras no comprimento máximo continuam antes do Q, que as colunas do card SUA BUILD não cobrem o herói nem o E/secundário e
# que o círculo do Q a 100% muda de estado em relação aos 99% (pronto) e cada herói tem o ícone do Q.
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_hud_layout.tscn  (imprime "v2_hud_layout falhas=0")
# Fotos: godot --path jogos/hordas/projeto res://testes/v2_hud_layout.tscn -- --fotos=PASTA [--janela=WxH]  (a partida de cada herói com o Q a 40% e a 100%; sai)
const Hud := preload("res://v2/hud.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const Herois := preload("res://v2/herois.gd")
const StatusHud := preload("res://v2/status.gd")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
const HEROIS := ["hazaki", "nicao", "lucas"]
const MARGEM_MINIMAPA := 6.0
const MINIMAPA := Vector2(176.0, 112.0)  # o minimapa pequeno com a moldura, no canto de cima à direita (o card da build o considera até y 112)
## Os blocos do HUD que não podem se cobrir. O selo do nível fica colado na barra de XP de propósito e é conferido à parte.
const BLOCOS := ["Retrato", "MolduraBarras", "Golpes", "Tempo", "Abates", "Nivel", "Combo", "Chefe", "Anuncio", "Xp", "Ultimate", "Habilidades"]
## (janela, opção de tamanho): 960x540 (o bloco), 16:9 maiores e 21:9 (ultrawide).
const TELAS := [
	[Vector2(960, 540), "auto"],
	[Vector2(1280, 720), "auto"],
	[Vector2(1920, 1080), "auto"],
	[Vector2(1920, 1080), "pequeno"],
	[Vector2(1920, 1080), "grande"],
	[Vector2(2560, 1440), "auto"],
	[Vector2(2560, 1080), "auto"],
	[Vector2(3440, 1440), "auto"],
	[Vector2(3440, 1440), "pequeno"],
]

var falhas := 0
var _janela := Vector2i.ZERO


class Heroi:
	extends RefCounted
	var vida := 100.0
	var vida_max := 100.0
	var folego := 3.0
	var folego_max := 3.0
	var cansado := false
	var chave := "hazaki"
	var esp_nome := "Corte Relâmpago"
	var esp_carga := 0.0
	var esp_carga_max := 100.0
	var esp_cor := Color(0.55, 0.85, 1.0)
	var esp_rotulo := "CORTE"
	var escudo_ativo := false


class MundoFalso:
	extends RefCounted
	var heroi := Heroi.new()
	var tempo_partida := 95.0
	var abates := 12
	var combo := 12
	var monstros_vivos := 30


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
	print("v2_hud_layout falhas=%d" % falhas)
	get_tree().quit()


func _testes() -> void:
	var vista := SubViewport.new()
	vista.size = Vector2i(960, 540)
	vista.disable_3d = true
	add_child(vista)
	var falso := MundoFalso.new()
	var hud = Hud.criar(falso)
	vista.add_child(hud)
	hud.set_process(false)
	hud.avancar(PASSO)
	hud.get_node("Raiz/Chefe").visible = true  # o pior caso: tudo aparece ao mesmo tempo
	hud.get_node("Raiz/Anuncio").visible = true
	for tela in TELAS:
		_nao_se_cobrem(hud, tela[0], tela[1])
	_barras_no_teto(hud, falso)
	_colunas_do_card(hud)
	_circulo_do_q(hud, falso)
	vista.queue_free()


## Os blocos do HUD em coordenadas do canvas: a posição do bloco mais o deslocamento dele no canvas.
func _retangulos(hud, canvas: Vector2, d: Vector2) -> Dictionary:
	hud.ui_reencaixar(canvas, d)
	hud.avancar(PASSO)
	var r := {}
	for nome in BLOCOS:
		var no: Control = hud.get_node("Raiz/" + nome)
		r[nome] = Rect2(no.position + d, no.size * no.scale)  # o Q, o E/secundário e os golpes são escalados (1,5x) pelo nó
	r["Minimapa"] = Rect2(canvas.x - MARGEM_MINIMAPA - MINIMAPA.x, 0.0, MINIMAPA.x, MINIMAPA.y)
	return r


func _nao_se_cobrem(hud, janela: Vector2, opcao: String) -> void:
	var canvas := EscalaUi.canvas(janela, opcao)
	var d := EscalaUi.deslocamento(canvas)
	var rects := _retangulos(hud, canvas, d)
	var rotulo := "%dx%d %s (canvas %dx%d)" % [janela.x, janela.y, opcao, canvas.x, canvas.y]
	var nomes := rects.keys()
	for i in nomes.size():
		var a: Rect2 = rects[nomes[i]]
		if nomes[i] != "Minimapa":
			ok(Rect2(Vector2.ZERO, canvas).encloses(a), "%s: %s cabe no canvas %s" % [rotulo, nomes[i], a])
		for j in range(i + 1, nomes.size()):
			var b: Rect2 = rects[nomes[j]]
			ok(not a.intersects(b), "%s: %s %s cobre %s %s" % [rotulo, nomes[i], a, nomes[j], b])
	# o selo do nível (colado na barra de XP) não cobre mais nada além dela
	var selo: Control = hud.get_node("Raiz/Selo")
	var r_selo := Rect2(selo.position + d, selo.size)
	for nome in nomes:
		if nome != "Xp":
			ok(not r_selo.intersects(rects[nome]), "%s: o selo do nível cobre %s" % [rotulo, nome])
	# as âncoras (com 1 px de folga: num canvas de medida ímpar o deslocamento do bloco arredonda para baixo): o herói cola no canto de baixo à esquerda do canvas, o E e o secundário no de baixo à direita, o Q e o XP no centro de baixo
	var ret: Rect2 = rects.Retrato
	ok(ret.position.x == 6.0 and absf(ret.end.y - (canvas.y - 6.0)) <= 1.0, "%s: o retrato cola no canto de baixo à esquerda (%s)" % [rotulo, ret])
	var hab: Rect2 = rects.Habilidades
	ok(
		absf(hab.end.x - (canvas.x - 6.0)) <= 1.0 and absf(hab.end.y - (canvas.y - 6.0)) <= 1.0,
		"%s: o E e o secundário colam no canto de baixo à direita (%s)" % [rotulo, hab]
	)
	var ult: Rect2 = rects.Ultimate
	var xp: Rect2 = rects.Xp
	ok(absf(ult.get_center().x - canvas.x * 0.5) <= 0.5 and absf(xp.get_center().x - canvas.x * 0.5) <= 0.5, "%s: o Q e o XP no centro (%s)" % [rotulo, ult])
	ok(absf(xp.end.y - (canvas.y - 6.0)) <= 1.0 and ult.end.y < xp.position.y, "%s: o Q fica acima do XP, que cola embaixo" % rotulo)


## No teto de capacidade, a moldura compacta de 252x66 px cabe em todas as resoluções e fica antes do Q, da faixa de XP e do selo.
func _barras_no_teto(hud, falso: MundoFalso) -> void:
	falso.heroi.vida_max = 100000.0
	falso.heroi.vida = 100000.0
	falso.heroi.folego_max = 999.0
	falso.heroi.folego = 999.0
	hud.ui_reencaixar(Vector2(960, 540), Vector2.ZERO)
	for i in 120:
		hud.avancar(PASSO)
	var barras: Control = hud.get_node("Raiz/MolduraBarras")
	var r := Rect2(barras.position, barras.size)
	ok(r.size.x == Hud.BARRA_TETO_PX + 8.0, "a moldura no teto tem %s px" % r.size.x)
	ok(r.size.y == 66.0, "a moldura no teto continua fina (66 px de altura)")
	for nome in ["Xp", "Selo", "Ultimate", "Habilidades"]:
		var no: Control = hud.get_node("Raiz/" + nome)
		ok(not r.intersects(Rect2(no.position, no.size * no.scale)), "no teto, a moldura das barras %s não cobre %s" % [r, nome])
	ok(hud.get_node("Raiz/Ultimate").position.x - r.end.x >= 8.0, "no teto, ainda sobra espaço entre as barras e o círculo do Q")
	ok(hud.get_node("Raiz/Selo").position.x - r.end.x >= 4.0, "no teto, a moldura das barras não toca o selo de nível")
	for tela in TELAS:
		_nao_se_cobrem(hud, tela[0], tela[1])  # as mesmas garantias com as barras já no teto, em cada tela e tamanho de interface
	falso.heroi.vida_max = 100.0
	falso.heroi.vida = 100.0
	falso.heroi.folego_max = 3.0
	falso.heroi.folego = 3.0
	for i in 120:
		hud.avancar(PASSO)


## As colunas do card SUA BUILD (tecla C, v2/status.gd) ficam acima do herói e do E/secundário, no 960x540.
func _colunas_do_card(hud) -> void:
	hud.ui_reencaixar(Vector2(960, 540), Vector2.ZERO)
	hud.avancar(PASSO)
	for c in StatusHud.COLUNAS_HUD.size():
		var col: Rect2 = StatusHud.COLUNAS_HUD[c]
		for nome in BLOCOS:
			if nome == "Golpes":
				continue  # a faixa de golpes se esconde com o card aberto (hud_golpes.gd)
			var no: Control = hud.get_node("Raiz/" + nome)
			if nome in ["Chefe", "Anuncio", "Combo", "Tempo", "Abates", "Nivel"]:
				continue  # o card já foi desenhado para ficar fora destes (v2_status confere com a build máxima)
			ok(not col.intersects(Rect2(no.position, no.size * no.scale)), "a coluna %d do card %s cobre %s" % [c, col, nome])


## O Q: a 99,6% ainda não está pronto; a 100% fica pronto (anel completo, ícone aceso e pulso) e o estado do círculo muda. Cada herói tem o ícone dele.
func _circulo_do_q(hud, falso: MundoFalso) -> void:
	var slots = hud.get_node("Raiz/Habilidades")
	var h: Heroi = falso.heroi
	h.esp_carga = 99.6
	slots.sincronizar(h)
	var chave_99: String = slots.q_chave()
	ok(not slots.q_pronta and slots.q_carga_pct == 99, "a 99,6% o Q ainda não está pronto e mostra 99%")
	h.esp_carga = 100.0
	slots.sincronizar(h)
	ok(slots.q_pronta and slots.q_carga_pct == 100 and slots.q_chave() != chave_99, "a 100% o Q está pronto e o estado do círculo muda")
	ok(slots.q_heroi == "hazaki", "o círculo recebe a chave do herói para achar o ícone dele")
	for id in HEROIS:
		ok(ResourceLoader.exists("res://assets/v2/especial_q/%s.png" % id), "o herói %s tem o ícone do Q próprio" % id)
	h.esp_carga = 0.0
	slots.sincronizar(h)


## Fotos da partida real de cada herói, com o Q a 40% e a 100%, no tamanho de janela pedido.
func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--janela="):
			var wh := a.trim_prefix("--janela=").split("x")
			_janela = Vector2i(int(wh[0]), int(wh[1]))
			for c in get_window().size_changed.get_connections():  # a Config força 16:9 a cada mudança de tamanho
				get_window().size_changed.disconnect(c.callable)
			get_window().size = _janela
	for id in HEROIS:
		Herois.forcado = id
		var w = Mundo.instantiate()
		w.modo_teste = true
		add_child(w)
		w.set_process(false)
		w.heroi.entrada_forcada = Vector2.ZERO
		var cs = w.combate.cartas
		for golpe in ["laminas", "corvos", "raio", "runa", "aura_fogo"]:
			cs.aplicar(cs.montar_carta(cs.definicao(golpe), 0))
		for i in 60:
			w.avancar(PASSO)
		w.heroi.vida = w.heroi.vida_max * 0.7
		w.heroi.xp = w.heroi.xp_proximo * 0.45
		w.heroi.nivel = 7
		w.abates = 37
		w.combo = 12
		w.tempo_partida = 452.0
		for q in [0.4, 1.0]:
			w.heroi.esp_carga = w.heroi.esp_carga_max * q
			await get_tree().create_timer(0.6).timeout
			var nome := "hud_%s_q%d_%dx%d" % [id, roundi(q * 100.0), get_window().size.x, get_window().size.y]
			var tam = await w.ap.foto(pasta.path_join(nome + ".png"))
			print("FOTO %s %s janela %s" % [nome, tam, get_window().size])
			if _janela != Vector2i.ZERO and tam != _janela:
				print("FALHA: a foto saiu %s e o pedido era %s" % [tam, _janela])
				get_tree().quit(1)
		w.queue_free()
		await get_tree().process_frame
	Herois.forcado = ""
