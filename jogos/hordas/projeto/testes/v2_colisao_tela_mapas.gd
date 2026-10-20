extends Node
# Teste por mapa da colisão de monstro só perto da tela (#336). Para cada mapa de dados/v2_niveis.json, com o mundo de verdade (as formas
# do mapa), confere: 1) a horda chega ao herói nos primeiros segundos (partida de verdade, diretor ligado, herói parado);
# 2) nenhum monstro visível atravessa uma forma (passa de fora para dentro de uma forma com a tela à vista; quem já estava dentro quando
# a colisão ligou segue sem colisão até sair e não conta); 3) nenhum caçador trava ao entrar na faixa da colisão (em 1 s depois de entrar
# ele anda pelo menos MIN_AVANCO px, a não ser que já tenha chegado ao herói). Também prova que a saída livre foi exercida (caçadores que
# nascem logo fora da faixa, na reta de uma forma que a faixa corta).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_colisao_tela_mapas.tscn  (imprime "v2_colisao_tela_mapas falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Colisao := preload("res://v2/colisao.gd")
const PASSO := 1.0 / 60.0
const NIVEIS := "res://dados/v2_niveis.json"
const CHEGADA_S := 10.0  # (1) até aqui a horda tem de ter chegado ao herói; é também o tempo da partida observada
const CONTATO := 40.0  # px do centro do herói: chegou (o anel de cerco do herói fica bem perto disso)
const CACADORES_S := 8.0  # (2) e (3): uma horda de caçadores de vários tipos, de uma vez, sem o diretor
const N_CACADORES := 60
const N_SAIDA_LIVRE := 6  # caçadores que nascem logo fora da faixa, na reta de uma forma que a faixa corta (a saída livre)
const TIPOS := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_espantalho", "inimigo_lobo_sombrio", "inimigo_cavaleiro_oco"]
const MARGEM := 120.0  # a colisão liga 120 px antes da borda da tela (MARGEM_COLISAO de mundo.gd)
const BANDA := 160.0  # só monstro a até 160 px da tela entra na conta; a janela da (3) começa ao entrar nessa faixa (a colisão liga em 120)
const JANELA_QUADROS := 60  # (3): 1 s depois de entrar na faixa
const MIN_AVANCO := 10.0  # px que o caçador tem de andar nessa janela (parado fica em ~0)
var falhas := 0


## Acompanha os monstros quadro a quadro: os cruzamentos da (2), as travas da (3) e as saídas livres exercidas.
class Vigia:
	extends RefCounted
	var antes := {}  # id do monstro -> {"vis": na tela, "dentro": dentro de uma forma}, no quadro anterior (só quem estava na faixa)
	var entrando := {}  # id -> {"pos": onde entrou na faixa, "quadros": quantos quadros já passou nela}
	var cruzamentos: Array = []
	var travas: Array = []
	var avancos: Array = []  # px andados em cada janela que fechou (a menor é a pior)
	var entradas := 0
	var saidas_livres := {}  # ids dos monstros que estavam dentro de uma forma quando a colisão ligou (sem colisão até sair)

	func observar(w, heroi: Vector2) -> void:
		var tela: Rect2 = w.cam.retangulo(0.0)
		var faixa: Rect2 = w.cam.retangulo(BANDA)
		var agora := {}
		for m in w.monstros:
			if not faixa.has_point(m.pos):
				continue  # longe da tela: fora da conta, e para entrar na faixa ele tem de andar até ela
			var id: int = m.get_instance_id()
			var vis: bool = tela.has_point(m.pos)
			var dentro: bool = not Colisao.livre(m.pos, m.raio - 0.05)
			var ant: Dictionary = antes.get(id, {})
			if m.sem_colisao_ate_sair:
				saidas_livres[id] = true
			if vis and dentro and ant.has("dentro") and not ant.dentro:
				cruzamentos.append(m.pos)
			if not ant.has("dentro") and m.cacador:
				entrando[id] = {"pos": m.pos, "quadros": 0}
				entradas += 1
			if entrando.has(id):
				var e: Dictionary = entrando[id]
				e.quadros += 1
				if m.pos.distance_to(heroi) <= CONTATO:
					entrando.erase(id)  # chegou ao herói antes de fechar a janela: não é trava
				elif e.quadros >= JANELA_QUADROS:
					var andou: float = m.pos.distance_to(e.pos)
					avancos.append(andou)
					if andou < MIN_AVANCO:
						travas.append(m.pos)
					entrando.erase(id)
			agora[id] = {"vis": vis, "dentro": dentro}
		for id in entrando.keys():
			if not agora.has(id):
				entrando.erase(id)
		antes = agora


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var niveis = JSON.parse_string(FileAccess.get_file_as_string(NIVEIS))
	var livres := 0
	for id in niveis.mapas.keys():
		var w = _mundo(str(id))
		_partida(w, str(id))
		livres += _cacadores(w, str(id))
		w.queue_free()
		await get_tree().process_frame
	# a saída livre pede uma forma cortada pela faixa no caminho de fora até o herói: nem todo mapa tem uma no ponto de partida
	print("  saídas livres exercidas nos mapas: %d" % livres)
	ok(livres >= 1, "nenhum caçador exerceu a saída livre em nenhum mapa")
	print("v2_colisao_tela_mapas falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _mundo(id: String):
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = id
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.imortal = true
	return w


## (1), (2) e (3) com a partida de verdade: o diretor ligado, o herói parado e as formas do mapa.
func _partida(w, id: String) -> void:
	w.reiniciar()
	var v := Vigia.new()
	var primeiro := -1.0  # s até o primeiro caçador chegar ao herói (-1 = nunca)
	var tempo := 0.0
	for i in int(CHEGADA_S / PASSO):
		w.avancar(PASSO)
		tempo += PASSO
		v.observar(w, w.heroi.pos)
		if primeiro < 0.0:
			for m in w.monstros:
				if m.cacador and m.pos.distance_to(w.heroi.pos) <= CONTATO:
					primeiro = tempo
					break
	print("  %s partida: 1º caçador no herói em %.1f s, entradas %d" % [id, primeiro, v.entradas])
	print("    saídas livres %d, cruzamentos %d, travas %d, menor avanço %s px" % [v.saidas_livres.size(), v.cruzamentos.size(), v.travas.size(), _menor(v)])
	ok(primeiro >= 0.0 and primeiro <= CHEGADA_S, "%s: a horda não chegou ao herói em até %.0f s (1º contato em %.1f s)" % [id, CHEGADA_S, primeiro])
	_conferir(id, v)


## (2) e (3) com uma horda de caçadores de vários tipos nascendo de uma vez, fora da tela, sem o diretor (o mesmo mundo, nova partida).
func _cacadores(w, id: String) -> int:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var nascidos := 0
	for i in N_CACADORES:
		if w.combate.diretor.nascer(TIPOS[i % TIPOS.size()]):
			nascidos += 1
	ok(nascidos == N_CACADORES, "%s: nasceram %d de %d caçadores" % [id, nascidos, N_CACADORES])
	var na_saida := _nascer_na_saida_livre(w, N_SAIDA_LIVRE)
	var v := Vigia.new()
	for i in int(CACADORES_S / PASSO):
		w.avancar(PASSO)
		v.observar(w, w.heroi.pos)
	print("  %s caçadores: entradas %d, nasceram na saída livre %d, janelas %d" % [id, v.entradas, na_saida, v.avancos.size()])
	print("    saídas livres %d, cruzamentos %d, travas %d, menor avanço %s px" % [v.saidas_livres.size(), v.cruzamentos.size(), v.travas.size(), _menor(v)])
	_conferir(id, v)
	return v.saidas_livres.size()


## Caçadores que nascem 10 px fora da faixa, na reta do herói, num ponto em que a faixa corta uma forma: como a colisão liga com eles
## já dentro da forma, vale a saída livre (seguem sem colisão até sair). Só as direções em que o corte cai numa forma contam.
func _nascer_na_saida_livre(w, max_n: int) -> int:
	var faixa: Rect2 = w.cam.retangulo(MARGEM)
	var h: Vector2 = w.heroi.pos
	var n := 0
	for k in 36:
		if n >= max_n:
			break
		var dir := Vector2.from_angle(k * TAU / 36.0)
		var s := 0.0
		while faixa.has_point(h + dir * s) and s < 1000.0:
			s += 1.0
		if Colisao.livre(h + dir * (s - 4.0), 0.5):
			continue  # 4 px para dentro da faixa não há forma: o monstro chegaria livre
		w.nascer_monstro(TIPOS[n % TIPOS.size()], h + dir * (s + 10.0), true)
		n += 1
	return n


func _conferir(id: String, v: Vigia) -> void:
	for p in v.cruzamentos.slice(0, 3):
		print("    cruzou em %s" % str(p))
	for p in v.travas.slice(0, 3):
		print("    travou em %s" % str(p))
	ok(v.cruzamentos.is_empty(), "%s: %d monstro(s) visível(is) atravessaram uma forma" % [id, v.cruzamentos.size()])
	ok(v.travas.is_empty(), "%s: %d caçador(es) travaram ao entrar na faixa da colisão" % [id, v.travas.size()])


func _menor(v: Vigia) -> String:
	return "-" if v.avancos.is_empty() else "%.1f" % float(v.avancos.min())
