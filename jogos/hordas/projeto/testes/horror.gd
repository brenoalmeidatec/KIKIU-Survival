extends Node
# Teste automático: inimigos de horror, fase de horror e escuridão (#32 item 5).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/horror.tscn  (imprime "HORROR falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Escuridao := preload("res://scripts/hordas/escuridao.gd")
const COMUNS := ["carnical", "cao_ossos", "cavaleiro_oco", "espectro"]
const ELITE := "abominacao"
const CHEFE := "arauto"
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func nova() -> Node:
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = true
	add_child(a)
	await esperar(0.2)
	return a


func _ready() -> void:
	var inim: Dictionary = Dados.json("inimigos")
	var todos: Array = COMUNS + [ELITE, CHEFE]
	# --- cada inimigo novo existe nos dados, com sprite de colunas do ciclo de andar + branco carregável e conjunto horror
	for id in todos:
		var d: Dictionary = inim.get(id, {})
		ok(not d.is_empty(), "%s existe em inimigos.json" % id)
		ok(str(d.get("conjunto", "")) == "horror", "%s é do conjunto horror" % id)
		var tex: Texture2D = Dados.tex(str(d.get("sprite", "")))
		var cols := preload("res://scripts/hordas/animacao_monstros.gd").colunas(str(d.get("sprite", "")))
		ok(tex != null and tex.get_width() % cols == 0 and tex.get_width() >= cols * 16, "%s: sprite carrega e tem %d colunas (andar + branco)" % [id, cols])
		ok(str(d.get("nome", "")) != "", "%s tem nome" % id)
		if d.get("tiro") is Dictionary:
			ok(Dados.tex(str(d.tiro.get("sprite", ""))) != null, "%s: sprite do tiro carrega" % id)
		if d.get("invoca") is Dictionary:
			ok(inim.has(str(d.invoca.get("tipo", ""))), "%s invoca algo que existe" % id)
	# comportamentos distintos usando o que o motor tem
	ok(inim.cao_ossos.has("investida") and inim.cavaleiro_oco.has("investida"), "cão e cavaleiro fazem investida")
	ok(inim.espectro.has("atira") and float(inim.espectro.get("distancia", 0)) > 0, "espectro atira de longe")
	ok(inim.abominacao.has("invoca") and bool(inim.abominacao.get("elite", false)), "abominação é elite e invoca")
	# chefe de horror: entrada com nome e subtítulo
	var ch: Dictionary = inim.get(CHEFE, {})
	ok(bool(ch.get("chefe", false)) and not bool(ch.get("final", false)), "arauto é chefe de fase, não o final")
	ok(str(ch.get("nome", "")) != "" and str(ch.get("subtitulo", "")) != "", "arauto tem nome e subtítulo pra placa")
	# vírus continuam sem conjunto (= virus)
	for k in ["bug", "popup", "spam", "trojan", "minerador"]:
		ok(str(inim[k].get("conjunto", "virus")) == "virus", "%s segue sendo vírus" % k)

	# --- fases (regiões, #64): a corrida sorteada. Escuridão só onde a fase tem "escuro", e essas são de horror;
	# o horror (tenebrosos, Arauto) mora no Reino Sombrio, a última região.
	var a := await nova()
	a.xp = -1.0e12
	var fases: Array = a.diretor.fases()
	var escuras := []
	var horror := []
	for i in fases.size():
		var f: Dictionary = fases[i]
		var conj := str(f.get("conjunto", "virus"))
		if not Escuridao.da_fase(f).is_empty():
			escuras.append(i)
			ok(conj == "horror", "fase %d escura é de horror" % (i + 1))
		if conj == "horror":
			horror.append(i)
			ok(str(f.get("regiao_nome", "")) == "Reino Sombrio", "horror só no Reino Sombrio (fase %d é de %s)" % [i + 1, f.get("regiao_nome", "?")])
			if not f.get("chefe_regiao", false):
				ok(str(f.get("chefe", "")) == CHEFE, "o chefe das fases do Reino é o arauto (fase %d)" % (i + 1))
			for ev in f.get("eventos", []):
				var ti: Dictionary = inim.get(str(ev.get("inimigo", "")), {})
				ok(str(ti.get("conjunto", "virus")) == "horror", "evento de fase de horror usa só tenebrosos (%s)" % ev.get("inimigo", ""))
	ok(not horror.is_empty(), "a corrida tem fases de horror (%d)" % horror.size())
	var hi: int = escuras[0] if not escuras.is_empty() else (horror[0] if not horror.is_empty() else 0)

	# --- o diretor sorteia só o conjunto da fase
	for i in fases.size():
		a.diretor.ir_para(i)
		a.diretor.t_fase = 200.0
		var disp: Array = a.diretor._disponiveis()
		ok(not disp.is_empty(), "fase %d tem inimigos pra sortear" % (i + 1))
		var conj := str(fases[i].get("conjunto", "virus"))
		for k in disp:
			ok(str(inim[k].get("conjunto", "virus")) == conj, "fase %d só sorteia %s (veio %s)" % [i + 1, conj, k])
		if conj == "horror":
			for k in COMUNS + [ELITE]:
				ok(k in disp, "fase de horror sorteia %s" % k)
	a.diretor.ir_para(0)
	await esperar(0.4)
	ok(not a.escuridao.ligada(), "fase 1: escuridão desligada")
	if not escuras.is_empty():
		a.diretor.ir_para(hi)
		await esperar(0.4)
		ok(a.escuridao.ligada(), "fase escura: escuridão ligada")
		a.diretor.ir_para(0)
		await esperar(0.4)
		ok(not a.escuridao.ligada(), "voltou pra uma fase clara: escuridão desligada")

	# --- criar cada um: tamanho real (escala 1), elite de fábrica sem vida multiplicada, desenho sem erro
	a.diretor.ir_para(hi)
	for id in todos:
		var v = a.inimigos.criar(id, a.jogador.position + Vector2(120, 40), 1)
		ok(v != null and v.ppx == 1.0, "%s nasce com escala 1" % id)
		if id == ELITE:
			ok(v.elite and is_equal_approx(v.hpmax, float(inim[id].vida)), "abominação é elite sem vida multiplicada")
			ok(v.luz.x > 0.0, "abominação tem luz")
	var bug = a.inimigos.criar("bug", a.jogador.position + Vector2(-100, 0), 1)
	ok(bug.ppx == 2.0, "vírus continuam em escala 2")
	await esperar(1.0)  # alguns quadros de desenho, IA, tiros e investida com todos vivos
	ok(a.inimigos.vivos() > 0, "inimigos seguem vivos e desenhando")
	# --- a entrada do chefe de horror dispara (placa com nome e subtítulo)
	a.inimigos.criar(CHEFE, a.jogador.position + Vector2(260, -40), 1)
	a.chefe_final_chegou(false, CHEFE)
	await esperar(0.1)
	ok(a.entradas.ativo(), "entrada do Arauto dispara")
	ok(a.entradas._nome == "O ARAUTO SEM ROSTO" and a.entradas._sub == str(ch.subtitulo), "placa com nome e subtítulo do Arauto")
	a.entradas.restaurar_tempo()
	Engine.time_scale = 1.0
	a.free()

	print("HORROR falhas=", falhas)
	get_tree().quit()
