extends "res://testes/isolamento_v2.gd"
## STRAFE COM O MOUSE PARADO (regra aprovada pelo Alisson, 05/11): se a última fonte da mira foi o MOUSE, trocar a direção de andar no teclado
## não passa a fonte para ANDA. O herói segue olhando o cursor e andar de lado toca o strafe desde o 1º quadro, com o mouse parado (o v2_strafe
## refaz a fonte MOUSE todo quadro, como um mouse que mexe, e por isso não via o estalo). Cobre, em todos os heróis:
##  1. mouse parado, parado -> andar de lado (os dois lados): todo quadro, do 1º ao último, é do strafe; a fonte e a mira não saem do mouse;
##  2. o ciclo começa na pose 0 (junta) nos dois lados e cada pose dura o mesmo (±1 quadro): sem o quadro-relâmpago da pose 0 + salto à pose 5;
##  3. inverter o lado no meio do passo (S -> W -> S) não tem quadro de andar de frente nem salto de pose;
##  4. com a fonte ANDA (teclado puro, nunca usou o mouse) nada mudou: olha para onde anda, andar de frente, sem strafe;
##  5. o analógico direito (STICK) continua tirando a mira do mouse: ao voltar a andar o herói olha para onde anda.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const HEROIS := ["hazaki", "matheus", "joao", "beto", "lukako", "fabio", "lucas", "nicao", "lightwolf", "lightwolf_lobo"]
var falhas := 0
var w
var lobo := false


func ok(cond: bool, mensagem: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", mensagem)


## Mundo limpo, herói parado há 20 quadros com o mouse PARADO à direita (a fonte MOUSE é posta uma vez só, aqui).
func zerar(fonte: int) -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.escudo_forcado = false
	if lobo:
		w.combate.mecha.virar_lobo(w.heroi, 0.0)
		w.heroi.invenc = 0.0
	w.heroi.fonte = fonte
	w.mouse_forcado = w.heroi.centro() + Vector2(4000, 0)
	for i in 20:
		w.avancar(PASSO)


## Anda em `entrada` por `n` quadros SEM tocar na fonte nem no mouse; devolve as colunas, quadro a quadro.
func rodar(entrada: Vector2, n: int) -> Array:
	w.heroi.entrada_forcada = entrada
	var r: Array = []
	for i in n:
		w.avancar(PASSO)
		r.append(w.heroi.coluna)
	return r


func ints(a: Array) -> Array:
	return a.map(func(x): return int(x))


## Trocas de quadro dentro de `cols`: quantas avançam (+1), recuam (-1) e saltam; `fora` = quadros fora do conjunto; `corridas` = duração de cada pose.
func ciclo(cs: Array, cols: Array) -> Dictionary:
	var r := {"fora": 0, "outras": 0, "corridas": [], "primeira": -1}
	var n := 0
	for i in cs.size():
		if not cols.has(cs[i]):
			r.fora += 1
		if i == 0:
			r.primeira = cs[0]
			n = 1
		elif cs[i] == cs[i - 1]:
			n += 1
		else:
			r.corridas.append(n)
			n = 1
			var de: int = cols.find(cs[i - 1])
			var para: int = cols.find(cs[i])
			if de < 0 or para < 0 or (para != (de + 1) % cols.size() and para != posmod(de - 1, cols.size())):
				r.outras += 1
	return r


func testar(id: String) -> void:
	Herois.forcado = "lightwolf" if id == "lightwolf_lobo" else id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	lobo = id == "lightwolf_lobo"
	zerar(Heroi.Fonte.MOUSE)
	var h = w.heroi
	var anims: Dictionary = h.tipo.info.get("animacoes", {})
	ok(anims.has("strafe"), "%s: a folha tem o strafe" % id)
	if not anims.has("strafe"):
		await _soltar()
		return
	var st := ints(anims.strafe.colunas)
	var andar := range(1, 7)
	var mira0: Vector2 = h.dir_olhar

	# 1 e 2. mouse parado, saindo do repouso, os dois lados
	for e in [Vector2.DOWN, Vector2.UP]:
		zerar(Heroi.Fonte.MOUSE)
		var cs := rodar(e, 90)
		var c := ciclo(cs, st)
		var tag := "%s %s" % [id, "baixo" if e == Vector2.DOWN else "cima"]
		print("%s: 1o quadro=%d fora=%d saltos=%d poses=%s fonte=%d" % [tag, cs[0], c.fora, c.outras, c.corridas, h.fonte])
		ok(c.fora == 0, "%s: mouse parado, todo quadro é do strafe, inclusive o 1o (%d fora)" % [tag, c.fora])
		ok(c.outras == 0, "%s: o strafe só troca um quadro por vez (%d saltos)" % [tag, c.outras])
		ok(h.fonte == Heroi.Fonte.MOUSE, "%s: a fonte da mira continua o mouse" % tag)
		ok(h.dir_olhar.dot(mira0) > 0.99, "%s: o herói segue olhando o mouse (%s)" % [tag, h.dir_olhar])
		ok(c.primeira == st[0], "%s: o ciclo começa na pose 0 (%d, esperado %d)" % [tag, c.primeira, st[0]])
		var poses: Array = c.corridas.slice(0, c.corridas.size())  # a última corrida pode estar no meio: descarta
		poses.pop_back()
		ok(poses.size() >= 8, "%s: o teste viu poses suficientes (%d)" % [tag, poses.size()])
		if poses.size() >= 2:
			ok(poses.max() - poses.min() <= 1, "%s: cada pose dura o mesmo, ±1 quadro (%s)" % [tag, poses])

	# 3. inverter o lado no meio do passo, mouse parado
	zerar(Heroi.Fonte.MOUSE)
	var inv := rodar(Vector2.DOWN, 20) + rodar(Vector2.UP, 40) + rodar(Vector2.DOWN, 40)
	var ci := ciclo(inv, st)
	ok(ci.fora == 0, "%s: invertendo o lado com o mouse parado, nenhum quadro de andar de frente (%d fora)" % [id, ci.fora])
	ok(ci.outras == 0, "%s: invertendo o lado, nenhum salto de pose (%d)" % [id, ci.outras])

	# 4. fonte ANDA (teclado puro): como antes
	zerar(Heroi.Fonte.ANDA)
	var an := rodar(Vector2.DOWN, 60)
	var ca := ciclo(an, andar)
	ok(ca.fora == 0, "%s: fonte ANDA anda de frente, sem strafe (%d fora)" % [id, ca.fora])
	ok(h.fonte == Heroi.Fonte.ANDA and h.dir_olhar.dot(Vector2.DOWN) > 0.99, "%s: fonte ANDA olha para onde anda (%s)" % [id, h.dir_olhar])

	# 5. o analógico direito tira a mira do mouse: ao andar de novo, olha para onde anda
	zerar(Heroi.Fonte.STICK)
	h.dir_olhar = Vector2.RIGHT
	var sk := ciclo(rodar(Vector2.DOWN, 60), andar)
	ok(sk.fora == 0, "%s: fonte STICK, ao mudar o andar olha para onde anda (%d fora)" % [id, sk.fora])
	ok(h.fonte == Heroi.Fonte.ANDA, "%s: o STICK vira ANDA ao mudar a direção de andar" % id)
	await _soltar()


func _soltar() -> void:
	w.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	for id in HEROIS:
		await testar(id)
	Herois.forcado = ""
	print("v2_strafe_mouse falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)
