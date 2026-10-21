extends Node
# Letreiros do santuário (v2/salao_vivo.gd e v2/salao_visual.gd): cada pedaço do nome (o texto, o cadeado grande e a linha de baixo) fica
# quase transparente enquanto o herói está sobre ele e volta quando ele sai; fora disso, todos seguem legíveis.
# godot --headless --path jogos/hordas/projeto res://testes/v2_letreiros.tscn
# Fotos reais (precisa de janela, sem --headless): ... res://testes/v2_letreiros.tscn -- --fotos=<pasta> --nome=<antes|depois> [--janela=1920x1080]
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
const Salao = preload("res://v2/salao.gd")
const Vivo = preload("res://v2/salao_vivo.gd")
const PASSO := 1.0 / 60.0
const QUASE_TRANSPARENTE := 0.3  # o nome que o herói cobre tem de ficar com alfa até isso (o valor de salao_vivo.gd é 0,25)

var falhas := 0
var args := {}


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.get_slice("=", 0).substr(2)] = a.get_slice("=", 1)
	var prefixo := "qa_letr_%d_" % Time.get_ticks_usec()  # saves isolados: não toca no save real
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	Meta.caminho_save = "user://" + prefixo + "meta.cfg"
	Personagens.ativar(Personagens.criar("Breno"))
	if args.has("janela"):
		var p := str(args.janela).split("x")
		get_window().size = Vector2i(int(p[0]), int(p[1]))
		await get_tree().create_timer(0.5).timeout
	if args.has("fotos"):
		await fotos(str(args.fotos), str(args.get("nome", "x")), str(args.get("janela", "padrao")))
	else:
		await testar()
	var d := DirAccess.open("user://")
	for arquivo in d.get_files():
		if arquivo.begins_with(prefixo):
			d.remove(arquivo)
	print("v2_letreiros falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


## Cada pedaço do nome tem a sua caixa; quem a cobre apaga só esse pedaço, e ele volta quando o herói sai.
func testar() -> void:
	ok(Vivo.ESCALA_HEROI == Salao.ESCALA, "o herói é desenhado na mesma escala de salao.gd")
	var s := await abrir()
	var v := vivo_de(s)
	ok(v != null, "o salão vivo está montado")
	if v == null:
		s.queue_free()
		return
	var pedacos := 0
	for a in s._alvos:
		pedacos += s._visual.partes_rotulo(a).size()
	ok(v._letreiros.size() == pedacos and v._rotulos.get_child_count() == pedacos, "um nó por pedaço do nome (%d)" % pedacos)
	for a in s._alvos:
		for p in s._visual.partes_rotulo(a):
			var caixa: Rect2 = p.caixa
			ok(caixa.has_point(ponto_do_pedaco(a, str(p.parte))), "a caixa de %s/%s contém o lugar onde ele é desenhado" % [a.id, p.parte])
	ok(str(alvo(s, "altar").trava) != "", "precondição: o altar começa trancado num save novo")
	# herói longe: todos os nomes legíveis
	s._pos = Vector2(480, 470)
	andar(v, 60)
	ok(todos_legiveis(v), "herói longe: nenhum nome apagado")
	# sobre o nome das Estátuas: um quadro só leva ao meio do caminho; depois, quase transparente
	s._pos = Vector2(180, 372)
	v._process(PASSO)
	var meio := opacidade(s, v, "estatuas", "nome")
	ok(meio < 0.99 and meio > QUASE_TRANSPARENTE, "o nome some aos poucos: um quadro não leva o alfa direto ao fundo (%.2f)" % meio)
	andar(v, 40)
	ok(opacidade(s, v, "estatuas", "nome") <= QUASE_TRANSPARENTE, "sobre o nome das Estátuas: quase transparente")
	ok(opacidade(s, v, "floresta", "nome") > 0.999, "o nome da Floresta, fora do herói, segue inteiro")
	# sobre o cadeado do Altar: o cadeado apaga; o nome e a linha de baixo, que o herói não cobre, seguem
	s._pos = Vector2(780, 300)
	andar(v, 40)
	ok(opacidade(s, v, "altar", "cadeado") <= QUASE_TRANSPARENTE, "o cadeado do altar apaga quando o herói está sobre ele")
	ok(opacidade(s, v, "altar", "nome") > 0.999, "o nome do altar segue inteiro (o herói não o cobre)")
	ok(opacidade(s, v, "altar", "trava") > 0.999, "a linha do altar segue inteira (o herói não a cobre)")
	# a cabeça fica abaixo da linha das Ruínas (a margem transparente do topo do quadro não conta): a linha segue inteira
	ok(v._caixa_corpo(s._pos).position.y > s._pos.y - s._quadro_h * 2.0 + 6.0, "a caixa do corpo começa abaixo do topo do quadro (não caiu no quadro inteiro)")
	ok(opacidade(s, v, "medio", "trava") > 0.999, "a linha das Ruínas segue inteira: a cabeça do herói fica abaixo dela")
	ok(opacidade(s, v, "medio", "nome") > 0.999, "o nome das Ruínas segue inteiro")
	# andando, a caixa muda com o quadro e a direção: a linha das Ruínas segue inteira em todos os quadros que a sala mostra
	var apagou := false
	for d in 8:
		for q in 5:
			s._dir = d
			s._quadro = q
			v._process(PASSO)
			apagou = apagou or opacidade(s, v, "medio", "trava") < 0.999
	s._dir = 0
	s._quadro = 0
	ok(not apagou, "andando (quadros 0 a 4, oito direções), a linha das Ruínas não apaga")
	# a cabeça (a partir de y 220) cruza a linha de baixo das Ruínas (y 212 a 229): ela apaga, e o nome de cima (y 195 a 212) segue inteiro
	s._pos = Vector2(780, 290)
	andar(v, 40)
	ok(opacidade(s, v, "medio", "trava") <= QUASE_TRANSPARENTE, "a cabeça cruza a linha das Ruínas: ela apaga")
	ok(opacidade(s, v, "medio", "nome") > 0.999, "o nome das Ruínas, acima da cabeça, segue inteiro")
	# por trás do cadeado (pés acima da base do altar): o cadeado também apaga, porque a sala não ordena pelo y
	s._pos = Vector2(780, 262)
	andar(v, 40)
	ok(opacidade(s, v, "altar", "cadeado") <= QUASE_TRANSPARENTE, "o cadeado apaga também com o herói atrás dele")
	# saiu de todos: volta tudo ao normal
	s._pos = Vector2(480, 470)
	andar(v, 40)
	ok(todos_legiveis(v), "herói saiu: todos os nomes voltam ao normal")
	# nenhum nó novo com o tempo
	var nos: int = v._rotulos.get_child_count()
	for i in 30:
		await get_tree().process_frame
	ok(v._rotulos.get_child_count() == nos and v._letreiros.size() == pedacos, "nenhum nó novo com o tempo")
	s.queue_free()
	await get_tree().process_frame


## Foto real da sala com o herói sobre o nome da Floresta (portal), sobre o nome das Estátuas, sobre o cadeado do Altar (trancado)
## e no canto livre, onde todos os nomes têm de seguir legíveis.
func fotos(pasta: String, nome: String, tam: String) -> void:
	var s: Control = load("res://v2/salao.tscn").instantiate()
	add_child(s)
	s.ao_entrar = func(_cena): pass
	await get_tree().create_timer(1.0).timeout
	var cenas := [["floresta", Vector2(180, 228)], ["estatuas", Vector2(180, 372)], ["altar", Vector2(780, 300)], ["livre", Vector2(480, 470)]]
	for c in cenas:
		s._pos = c[1]
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta.path_join("letreiros_%s_%s_%s.png" % [nome, c[0], tam]))
	s.queue_free()
	await get_tree().process_frame


func abrir() -> Control:
	var s: Control = load("res://v2/salao.tscn").instantiate()
	add_child(s)
	s.ao_entrar = func(_cena): pass
	await get_tree().process_frame
	await get_tree().process_frame
	return s


func vivo_de(s: Control) -> Node:
	for n in s.get_children():
		if n.get_script() == Vivo:
			return n
	return null


func alvo(s: Control, id: String) -> Dictionary:
	for a in s._alvos:
		if str(a.id) == id:
			return a
	return {}


## Os quadros do salão vivo, sem esperar o motor (o tempo do teste é o PASSO).
func andar(v: Node, quadros: int) -> void:
	for i in quadros:
		v._process(PASSO)


func opacidade(s: Control, v: Node, id: String, parte: String) -> float:
	var i := 0
	for a in s._alvos:
		for p in s._visual.partes_rotulo(a):
			if str(a.id) == id and str(p.parte) == parte:
				var no: Node2D = v._letreiros[i].no
				return no.modulate.a
			i += 1
	return -1.0


func todos_legiveis(v: Node) -> bool:
	for l in v._letreiros:
		var no: Node2D = l.no
		if no.modulate.a < 0.999:
			return false
	return true


## Onde cada pedaço é desenhado em salao_visual.gd: a base do texto (y + 20 no portal, y + 30 na estrutura), a linha de baixo
## (y + 37 e y + 47) e o cadeado grande (y - 52).
func ponto_do_pedaco(a: Dictionary, parte: String) -> Vector2:
	var p: Vector2 = a.pos
	if parte == "cadeado":
		return p + Vector2(0, -52)
	if str(a.tipo) == "portal":
		return p + Vector2(0, 20 if parte == "nome" else 37)
	return p + Vector2(0, 30 if parte == "nome" else 47)
