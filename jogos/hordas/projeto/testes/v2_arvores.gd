extends Node
# Teste automático da colisão das árvores da v2 (pegada). Para cada tipo de árvore e de tronco do mapa (arvore, arvore_pantano,
# arvore_morta, toco, tronco), o herói anda das 8 direções até a árvore pelo caminho de verdade (mundo.mover) e confere que:
#   - a árvore está registrada no mundo (o centro da base não é livre);
#   - nunca entra na base visual (os pixels opacos das 12 linhas de baixo do sprite, no chão: distância y * 2 ao pé);
#   - chega perto dela (a parada é de verdade, não um teste vazio).
# A caminhada isola a árvore testada na grade (os vizinhos atrapalhariam a parada, não a base). A árvore da borda do mapa
# (fora da área andável) anda no mundo inteiro e só confere que não entra na base. Depois: a copa fica semitransparente (45%)
# com o herói atrás e volta com ele na frente, em transição suave; e a tecla F4 liga e desliga o contorno de colisão.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_arvores.tscn  (imprime "v2_arvores falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Sprites := preload("res://v2/sprites.gd")
const Colisao := preload("res://v2/colisao.gd")
const TIPOS := ["arvore", "arvore_pantano", "arvore_morta", "toco", "tronco"]
const LINHAS_BASE := 12  # o mesmo corte do gerador (COLISAO_LINHAS_BASE)
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var base_de := {}  # nome -> PackedVector2Array: pixels da base, relativos ao pé
var formas_de := {}  # nome -> formas de colisão do cenario.json


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Distância no chão (y * 2, a escala em que a elipse vira círculo) do ponto `rel` (relativo ao pé) à base visual mais perto.
func folga(base: PackedVector2Array, rel: Vector2) -> float:
	var m := 1.0e9
	for q in base:
		var d := Vector2(rel.x - q.x, (rel.y - q.y) * 2.0).length()
		if d < m:
			m = d
	return m


func centro_da_base(nome: String) -> Vector2:
	var base: PackedVector2Array = base_de[nome]
	var meio := Vector2.ZERO
	for q in base:
		meio += q
	return meio / maxf(float(base.size()), 1.0)


func carregar_bases() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://prototipos/objetos/cenario.json"))
	var atlas: Image = Sprites.png("res://prototipos/objetos/" + str(d.get("enfeites", "enfeites.png")))
	atlas.convert(Image.FORMAT_RGBA8)
	var por_nome := {}
	for it in d.itens:
		por_nome[it.nome] = it
	for nome in TIPOS:
		var it: Dictionary = por_nome[nome]
		var r: Array = it.regiao
		var pe := Vector2(float(it.pe[0]), float(it.pe[1]))
		var base := PackedVector2Array()
		for dy in range(0, -LINHAS_BASE, -1):
			var yy := int(pe.y) + dy
			if yy < 0 or yy >= int(r[3]):
				continue
			for xx in int(r[2]):
				if atlas.get_pixel(int(r[0]) + xx, int(r[1]) + yy).a > 0.5:
					base.append(Vector2(xx - pe.x, dy))
		base_de[nome] = base
		formas_de[nome] = it.colisao


## A primeira instância do mapa com esse nome que passa no `filtro` (Callable sobre a posição do pé).
func escolher(nome: String, filtro: Callable) -> Variant:
	for a in w.cenario.objetos:
		if a.chave == nome and filtro.call(a.pos):
			return a
	return null


## Anda das 8 direções até a árvore `a` pelo ponto de movimento real e confere a base. `isolado`: só a árvore na grade
## (confere a parada, que um vizinho poderia atrapalhar); sem isolar, confere só que não entra na base.
func caminhar_8(nome: String, a, isolado: bool) -> void:
	var base: PackedVector2Array = base_de[nome]
	var alvo: Vector2 = a.pos + centro_da_base(nome)
	var raio: float = w.heroi.raio
	if isolado:
		Colisao.limpar()
		Colisao.adicionar_objeto(a.pos, formas_de[nome])
	for i in 8:
		var dir := Vector2.RIGHT.rotated(i * TAU / 8.0)
		w.heroi.definir_pos(alvo + dir * 140.0)
		var mais_perto := 1.0e9
		var entrou := 0
		var bloqueado := 0  # passos em que o colisor segurou o herói (o deslocamento saiu quase zero)
		for _s in 300:
			var antes: Vector2 = w.heroi.pos
			w.mover(w.heroi, -dir)
			if (w.heroi.pos - antes).length() < 0.5:
				bloqueado += 1
			var g := folga(base, w.heroi.pos - a.pos)
			mais_perto = minf(mais_perto, g)
			if g < raio - 0.5:
				entrou += 1
		var rotulo := "%s (%.0f,%.0f) dir %d" % [nome, a.pos.x, a.pos.y, i]
		ok(entrou == 0, "%s: o herói entrou na base em %d passos (folga mínima %.2f, raio %.0f)" % [rotulo, entrou, mais_perto, raio])
		if isolado:
			ok(bloqueado > 0, "%s: o colisor nunca segurou o herói: teste sem contato (folga mínima %.2f)" % [rotulo, mais_perto])


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)  # os passos são nossos
	w.heroi.entrada_forcada = Vector2.ZERO
	carregar_bases()
	var raio: float = w.heroi.raio

	# 1. cada tipo de árvore e de tronco: registrada no mundo, e segura o herói das 8 direções
	var meio_mapa := func(p: Vector2) -> bool: return p.x > 500.0 and p.x < 2300.0 and p.y > 500.0 and p.y < 1100.0
	var escolhidas := {}
	for nome in TIPOS:
		var a = escolher(nome, meio_mapa)
		ok(a != null, "o mapa tem %s no meio" % nome)
		if a == null:
			continue
		escolhidas[nome] = a
		ok(not Colisao.livre(a.pos + centro_da_base(nome), raio), "%s em (%.0f,%.0f) está registrada no mundo" % [nome, a.pos.x, a.pos.y])
	for nome in escolhidas:
		caminhar_8(nome, escolhidas[nome], true)

	# 2. a árvore da borda (x acima de 1800, onde a grade prende as bordas) também segura, no mundo inteiro.
	# A grade ficou com só uma árvore isolada: um mundo novo registra tudo de novo (cenario.carregar zera e registra).
	w.queue_free()
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	var na_borda := func(p: Vector2) -> bool: return p.x > 1800.0 and p.x < 2700.0 and p.y > 600.0 and p.y < 1100.0
	var borda = escolher("arvore", na_borda)
	ok(borda != null, "o mapa tem arvore na borda leste (x > 1800)")
	if borda != null:
		ok(not Colisao.livre(borda.pos + centro_da_base("arvore"), raio), "arvore da borda registrada no mundo")
		caminhar_8("arvore", borda, false)

	# 3. copa transparente: herói atrás da árvore alta fica encoberto (alfa 45%); na frente, volta a 100%; a troca é suave
	var arvore_alta = escolher("arvore", meio_mapa)  # do mundo novo (o de cima foi descartado)
	ok(arvore_alta != null, "há arvore para o teste da copa")
	if arvore_alta != null:
		w.monstros.clear()  # monstro perto da árvore também a encobriria: o teste mede só o herói
		w.heroi.definir_pos(arvore_alta.pos + Vector2(0, -40))  # atrás: a cabeça cruza a copa (acima de 40 px do pé)
		var meio_caminho := -1.0
		for i in 90:
			w.avancar(PASSO)
			if i == 4:
				meio_caminho = w.copas.alfa_da_copa(arvore_alta)  # 5 quadros depois de encostar: a transição está em curso
		var alfa_atras: float = w.copas.alfa_da_copa(arvore_alta)
		ok(absf(alfa_atras - 0.45) < 0.03, "atrás da árvore: copa a 45%% (deu %.2f)" % alfa_atras)
		ok(meio_caminho > 0.46 and meio_caminho < 0.99, "a copa muda aos poucos (5 quadros depois: %.2f)" % meio_caminho)
		w.heroi.definir_pos(arvore_alta.pos + Vector2(0, 30))  # na frente: a árvore não encobre o herói
		passos(90)
		ok(absf(w.copas.alfa_da_copa(arvore_alta) - 1.0) < 0.03, "na frente da árvore: copa volta a 100%% (deu %.2f)" % w.copas.alfa_da_copa(arvore_alta))

	# 4. F4 liga e desliga o contorno de colisão (desligado por padrão)
	var f4 := InputEventKey.new()
	f4.keycode = KEY_F4
	f4.pressed = true
	f4.echo = false
	var antes: bool = w.dbg_colisao.visible
	ok(not antes, "contorno de colisão desligado por padrão")
	w._input(f4)
	ok(w.dbg_colisao.visible != antes, "F4 liga o contorno de colisão")
	w._input(f4)
	ok(w.dbg_colisao.visible == antes, "F4 de novo desliga")

	print("v2_arvores falhas=%d" % falhas)
	get_tree().quit()
