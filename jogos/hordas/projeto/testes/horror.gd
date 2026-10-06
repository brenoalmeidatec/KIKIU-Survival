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
	# --- cada inimigo novo existe nos dados, com sprite de 3 quadros carregável e conjunto horror
	for id in todos:
		var d: Dictionary = inim.get(id, {})
		ok(not d.is_empty(), "%s existe em inimigos.json" % id)
		ok(str(d.get("conjunto", "")) == "horror", "%s é do conjunto horror" % id)
		var tex: Texture2D = Dados.tex(str(d.get("sprite", "")))
		ok(tex != null and tex.get_width() % 3 == 0 and tex.get_width() >= 3 * 16, "%s: sprite carrega e tem 3 quadros" % id)
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

	# --- fases: só uma é de horror e só ela tem escuridão
	var fases: Array = Dados.json("corrida").get("fases", [])
	var horror_idx := []
	for i in fases.size():
		var f: Dictionary = fases[i]
		var h: bool = str(f.get("conjunto", "virus")) == "horror"
		ok(h == not Escuridao.da_fase(f).is_empty(), "fase %d: escuridão só onde o conjunto é horror" % (i + 1))
		if h:
			horror_idx.append(i)
			ok(i >= 4 and i <= 8, "a fase de horror é uma entre 5 e 9 (é a %d)" % (i + 1))
			ok(str(f.get("chefe", "")) == CHEFE, "o chefe da fase de horror é o arauto")
			for ev in f.get("eventos", []):
				var ti: Dictionary = inim.get(str(ev.get("inimigo", "")), {})
				ok(str(ti.get("conjunto", "virus")) == "horror", "evento da fase de horror usa só tenebrosos (%s)" % ev.get("inimigo", ""))
		else:
			ok(str(inim.get(str(f.get("chefe", "")), {}).get("conjunto", "virus")) == "virus", "fase %d clara não tem chefe de horror" % (i + 1))
			for ev in f.get("eventos", []):
				ok(str(inim.get(str(ev.get("inimigo", "")), {}).get("conjunto", "virus")) == "virus", "fase %d clara só tem vírus nos eventos" % (i + 1))
	ok(horror_idx.size() == 1, "exatamente uma fase de horror (%d)" % horror_idx.size())
	var hi: int = horror_idx[0] if not horror_idx.is_empty() else 5

	# --- o diretor sorteia só o conjunto da fase
	var a := await nova()
	a.xp = -1.0e12
	for i in fases.size():
		a.diretor.ir_para(i)
		a.diretor.t_fase = 200.0
		var disp: Array = a.diretor._disponiveis()
		ok(not disp.is_empty(), "fase %d tem inimigos pra sortear" % (i + 1))
		var conj := "horror" if i == hi else "virus"
		for k in disp:
			ok(str(inim[k].get("conjunto", "virus")) == conj, "fase %d só sorteia %s (veio %s)" % [i + 1, conj, k])
		if i == hi:
			for k in COMUNS + [ELITE]:
				ok(k in disp, "fase de horror sorteia %s" % k)
	a.diretor.ir_para(0)
	await esperar(0.4)
	ok(not a.escuridao.ligada(), "fase 1: escuridão desligada")
	a.diretor.ir_para(hi)
	await esperar(0.4)
	ok(a.escuridao.ligada(), "fase de horror: escuridão ligada")
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
	await esperar(1.0)   # alguns quadros de desenho, IA, tiros e investida com todos vivos
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
