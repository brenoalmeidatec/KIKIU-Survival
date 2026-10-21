extends "res://testes/isolamento_v2.gd"
# Teste automático da colisão das árvores da v2 (pegada). Para cada tipo de árvore e de tronco do mapa (arvore, arvore_pantano,
# arvore_morta, toco, tronco), o herói anda das 8 direções até a árvore pelo caminho de verdade (mundo.mover) e confere que:
#   - a árvore está registrada no mundo (o centro da base não é livre);
#   - nunca entra na base visual (os pixels opacos das 12 linhas de baixo do sprite, no chão: distância y * 2 ao pé);
#   - chega perto dela (a parada é de verdade, não um teste vazio).
# A caminhada isola a árvore testada na grade (os vizinhos atrapalhariam a parada, não a base). A árvore da borda do mapa
# (fora da área andável) anda no mundo inteiro e só confere que não entra na base. Depois: um buraco raio-x abre em volta do herói atrás da árvore
# com o herói atrás e volta com ele na frente, em transição suave; e a tecla F4 liga e desliga o contorno de colisão.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_arvores.tscn  (imprime "v2_arvores falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
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


## Procura no mapa cheio uma trajetória que começa e termina livre, mas cruza a base da árvore; aplica o passo de uma esquiva lenta.
func testar_esquiva_rapida(nome: String, distancia: float) -> void:
	var raio: float = w.heroi.raio
	var encontrou := false
	for a in w.cenario.objetos:
		if a.chave != nome:
			continue
		var alvo: Vector2 = a.pos + centro_da_base(nome)
		for i in 8:
			var dir := Vector2.RIGHT.rotated(i * TAU / 8.0)
			var inicio: Vector2 = alvo - dir * (distancia * 0.5)
			var fim: Vector2 = alvo + dir * (distancia * 0.5)
			if not Colisao.livre(inicio, raio) or Colisao.livre(alvo, raio) or not Colisao.livre(fim, raio):
				continue
			w.heroi.definir_pos(inicio)
			w.heroi.estado = Heroi.Estado.ESQUIVA
			w.heroi.esq_t = 0.0
			w.heroi.esq_dir = dir
			w.heroi.atualizar(0.1)
			ok((w.heroi.pos - inicio).dot(dir) < distancia - 1.0, "%s: esquiva rápida não atravessa a pegada" % nome)
			ok(Colisao.livre(w.heroi.pos, raio), "%s: esquiva termina fora da base" % nome)
			encontrou = true
			break
		if encontrou:
			break
	ok(encontrou, "%s: mapa real tem trajetória de esquiva que cruza a base" % nome)


## Corrida tem passos menores: chega até a base em 16 px, mas não entra nela.
func testar_corrida(nome: String, distancia: float) -> void:
	var raio: float = w.heroi.raio
	var encontrou := false
	for a in w.cenario.objetos:
		if a.chave != nome:
			continue
		var alvo: Vector2 = a.pos + centro_da_base(nome)
		for i in 8:
			var dir := Vector2.RIGHT.rotated(i * TAU / 8.0)
			for recuo in range(100, int(distancia), -1):
				var inicio: Vector2 = alvo - dir * float(recuo)
				var fim: Vector2 = inicio + dir * distancia
				if not Colisao.livre(inicio, raio) or Colisao.livre(fim, raio):
					continue
				w.heroi.definir_pos(inicio)
				w.heroi.estado = Heroi.Estado.LIVRE
				w.heroi.folego = w.heroi.folego_max
				w.heroi.cansado = false
				w.heroi.entrada_forcada = dir
				w.heroi.correr_forcado = true
				w.heroi.atualizar(0.1)
				ok(w.heroi.correndo, "%s: o herói usa corrida real contra a base" % nome)
				ok(Colisao.livre(w.heroi.pos, raio), "%s: corrida termina fora da base" % nome)
				ok((w.heroi.pos - alvo).dot(dir) <= 0.1, "%s: corrida não termina do outro lado da base" % nome)
				encontrou = true
				break
			if encontrou:
				break
		if encontrou:
			break
	ok(encontrou, "%s: mapa real tem árvore que intercepta a corrida" % nome)


## Garante que o filtro espacial vê células intermediárias quando as duas pontas estão longe da árvore.
func testar_segmento_longo() -> void:
	var raio: float = w.heroi.raio
	var encontrou := false
	for a in w.cenario.objetos:
		if a.chave != "arvore":
			continue
		var alvo: Vector2 = a.pos + centro_da_base("arvore")
		var inicio: Vector2 = alvo + Vector2(0.0, -80.0)
		var fim: Vector2 = alvo + Vector2(0.0, 80.0)
		if not Colisao.livre(inicio, raio) or Colisao.livre(alvo, raio) or not Colisao.livre(fim, raio):
			continue
		ok(Colisao.segmento_perto(inicio, fim, raio), "AABB do movimento longo encontra a célula intermediária da árvore")
		w.heroi.definir_pos(inicio)
		w.mover(w.heroi, fim - inicio)
		ok(w.heroi.pos.distance_to(fim) > 1.0, "movimento longo para antes da árvore, mesmo com pontas livres")
		encontrou = true
		break
	ok(encontrou, "mapa real tem árvore com percurso longo entre duas pontas livres")


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

	# Reproduz a esquiva com delta alto: no jogo o avanço pode chegar a ~35 px num passo (0,1 s), enquanto
	# a espessura de uma pegada atravessada de frente é menor. O teste mantém as 572 formas do cenário.
	# caminhar_8 isola as formas e limpa a grade; recarrega o cenário para esta parte refletir a partida real.
	w.queue_free()
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	for nome in TIPOS:
		testar_esquiva_rapida(nome, 100.0 * 2.6 * (1.35 - 0.7 * (0.1 / 0.42)) * 0.1)
		testar_corrida(nome, 16.0)  # corrida: 100 px/s × 1,6 × 0,1 s
	testar_segmento_longo()
	# A copa é só visual: o herói pode atravessar a área alta da árvore por trás dela.
	var arvore_copa: Variant = null
	for a in w.cenario.objetos:
		if a.chave != "arvore":
			continue
		var inicio_copa: Vector2 = a.pos + Vector2(-60.0, -40.0)
		var livre := true
		for passo in 5:
			if not Colisao.livre(inicio_copa + Vector2(30.0 * passo, 0.0), raio):
				livre = false
				break
		if livre:
			arvore_copa = a
			break
	ok(arvore_copa != null, "há copa alta que o herói pode atravessar sem tocar na base")
	if arvore_copa != null:
		var copa: Vector2 = arvore_copa.pos + Vector2(-60.0, -40.0)
		w.heroi.definir_pos(copa)
		w.mover(w.heroi, Vector2(120.0, 0.0))
		ok(w.heroi.pos.distance_to(copa + Vector2(120.0, 0.0)) < 1.0, "o herói atravessa a copa sem colisão")

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
				meio_caminho = w.copas.fuerza_da_copa(arvore_alta)  # 5 quadros depois de encostar: o buraco está abrindo
		var forca_atras: float = w.copas.fuerza_da_copa(arvore_alta)
		ok(forca_atras > 0.97, "atrás da árvore: o buraco raio-x está aberto (força %.2f)" % forca_atras)
		ok(meio_caminho > 0.05 and meio_caminho < 0.95, "o buraco abre aos poucos (5 quadros depois: %.2f)" % meio_caminho)
		var centro_no_shader: Vector2 = arvore_alta.sprite.material.get_shader_parameter("centro")
		ok(centro_no_shader.distance_to(w.heroi.centro()) < 1.0, "o centro do buraco é o herói")
		w.heroi.definir_pos(arvore_alta.pos + Vector2(0, 30))  # na frente: a árvore não encobre o herói
		passos(90)
		ok(w.copas.fuerza_da_copa(arvore_alta) < 0.03, "na frente da árvore: o buraco fecha (força %.2f)" % w.copas.fuerza_da_copa(arvore_alta))

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
