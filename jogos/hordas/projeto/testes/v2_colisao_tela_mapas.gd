extends "res://testes/isolamento_v2.gd"
# Teste por mapa da colisão de monstro só perto da tela (#336). Para cada mapa de dados/v2_niveis.json, com o mundo de verdade (as formas
# do mapa), confere: 1) a horda chega ao herói nos primeiros segundos (partida de verdade, diretor ligado, herói parado);
# 2) nenhum monstro visível atravessa uma forma (passa de fora para dentro de uma forma com a tela à vista; quem já estava dentro quando
# a colisão ligou segue sem colisão até sair e não conta); 3) nenhum caçador trava ao entrar na faixa da colisão (em 1 s depois de entrar
# ele anda pelo menos MIN_AVANCO px, a não ser que já tenha chegado ao herói). Também prova que a saída livre foi exercida (caçadores que
# nascem logo fora da faixa, na reta de uma forma que a faixa corta). 4) Longe da tela (fora da faixa da colisão), um caçador sozinho anda
# em linha reta até o herói e atravessa uma forma sem colidir: a colisão só vale perto da tela. 5) Quando a colisão liga com o monstro já
# dentro de uma forma, ele não salta: o deslocamento por quadro segue a velocidade até sair da forma.
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
const MIN_AVANCO := 15.0  # px que o caçador tem de andar nessa janela (parado fica em ~0; o menor real medido foi 21,7 px)
const DIRECOES := 72  # rumos a partir do herói: (4) procura uma reta que cruza uma forma fora da faixa; (5) uma faixa que corta uma forma
const MAX_POR_MAPA := 2  # cenários de (4) e de (5) por mapa (cada um é uma partida curta de um monstro só)
const RAIO_CORPO := 7.0  # Ator.raio: o corpo que as buscas de forma usam (a contagem dentro da forma usa o raio do próprio monstro)
const TOL_RETA := 0.5  # px de desvio, para um lado, da reta até o herói em (4): sem colisão e sem separação, o desvio é zero
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
	var retas := 0
	var ligadas_dentro := 0
	for id in niveis.mapas.keys():
		var w = _mundo(str(id))
		_partida(w, str(id))
		livres += _cacadores(w, str(id))
		retas += _longe_atravessa(w, str(id))
		ligadas_dentro += _sem_salto(w, str(id))
		w.queue_free()
		await get_tree().process_frame
	# a saída livre pede uma forma cortada pela faixa no caminho de fora até o herói: nem todo mapa tem uma no ponto de partida
	print("  saídas livres exercidas nos mapas: %d" % livres)
	ok(livres >= 1, "nenhum caçador exerceu a saída livre em nenhum mapa")
	print("  retas longe da tela conferidas: %d; colisões ligadas dentro de forma conferidas: %d" % [retas, ligadas_dentro])
	ok(retas >= 1, "nenhuma reta longe da tela cruzou uma forma em nenhum mapa")
	ok(ligadas_dentro >= 1, "nenhuma colisão ligou com o monstro dentro de uma forma em nenhum mapa")
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


## Tira a horda do mundo (como em _cacadores): só o monstro que o teste solta fica vivo.
func _isolar(w) -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false


## Dentro de uma forma, com o corpo de raio `raio` (o mesmo critério do Vigia).
func _dentro(p: Vector2, raio: float) -> bool:
	return not Colisao.livre(p, raio - 0.05)


## Quantos px, na direção `dir` a partir de `h`, a reta fica dentro da faixa da colisão.
func _saida_faixa(w, h: Vector2, dir: Vector2) -> float:
	var s := 0.0
	while w.cam.retangulo(MARGEM).has_point(h + dir * s) and s < 1000.0:
		s += 1.0
	return s


## (4) Longe da tela a colisão não vale: um caçador sozinho, nascido do outro lado de uma forma que fica fora da faixa, anda até o herói.
## Enquanto está fora da faixa, ele anda na reta até o herói (sem desviar) e passa por dentro da forma: se a colisão valesse, a borda
## o pararia ou o desviaria.
func _longe_atravessa(w, id: String) -> int:
	_isolar(w)
	var h: Vector2 = w.heroi.pos
	var n := 0
	for k in DIRECOES:
		if n >= MAX_POR_MAPA:
			break
		var dir := Vector2.from_angle(k * TAU / DIRECOES)
		var s := _saida_faixa(w, h, dir)
		var t_in := s
		while t_in < s + 400.0 and not _dentro(h + dir * t_in, RAIO_CORPO):
			t_in += 2.0
		var t_out := t_in
		while t_out < s + 400.0 and _dentro(h + dir * t_out, RAIO_CORPO):
			t_out += 2.0
		if t_in >= s + 400.0 or t_out - t_in < 20.0:
			continue  # sem forma fora da faixa nesta reta, ou forma fina demais para o monstro ficar dentro dela
		var nascer := h + dir * (t_out + 15.0)
		if not w.limite_andavel.has_point(nascer) or _dentro(nascer, RAIO_CORPO):
			continue
		w.combate.limpar_partida()
		var r: Dictionary = _sozinho(w, nascer)
		print("    longe: desvio máximo %.3f px, quadros dentro da forma %d, vivo %s" % [r.desvio, r.dentro, r.vivo])
		ok(r.vivo, "%s: o caçador longe da tela morreu antes de chegar à faixa" % id)
		ok(r.desvio <= TOL_RETA, "%s: caçador longe da tela saiu da reta até o herói (%.2f px)" % [id, r.desvio])
		ok(r.dentro >= 1, "%s: caçador longe da tela não atravessou a forma (quadros dentro dela: %d)" % [id, r.dentro])
		n += 1
	print("  %s longe da tela: %d reta(s) conferida(s)" % [id, n])
	return n


## Um caçador sozinho nasce em `inicio`, fora da faixa, e anda até o herói. Devolve o maior desvio dele da reta de `inicio` ao herói
## (px), quantos quadros ele passou dentro de uma forma fora da faixa e se ainda está vivo.
func _sozinho(w, inicio: Vector2) -> Dictionary:
	var h: Vector2 = w.heroi.pos
	var m = w.nascer_monstro(TIPOS[0], inicio, true)
	var reta := h - inicio
	var desvio := 0.0
	var dentro := 0
	for _i in 1200:
		w.avancar(PASSO)
		if w.cam.retangulo(MARGEM).has_point(m.pos):
			break
		desvio = maxf(desvio, absf((m.pos - inicio).cross(reta)) / reta.length())
		if _dentro(m.pos, m.raio):
			dentro += 1
	return {"desvio": desvio, "dentro": dentro, "vivo": m.vivo}


## (5) A colisão liga com o monstro já dentro de uma forma: a faixa corta uma forma no ponto em que o caçador, vindo de fora, entra nela
## (o centro dele já está dentro da forma ali) e a colisão liga ali. Ele segue sem colisão até sair da forma e não pode saltar: o
## deslocamento de cada quadro sem colisão fica no que a velocidade pede. Se a colisão empurrasse para fora da forma, aí apareceria o salto.
func _sem_salto(w, id: String) -> int:
	_isolar(w)
	var h: Vector2 = w.heroi.pos
	var n := 0
	for k in DIRECOES:
		if n >= MAX_POR_MAPA:
			break
		var dir := Vector2.from_angle(k * TAU / DIRECOES)
		var s := _saida_faixa(w, h, dir)
		var corte := h + dir * s  # onde a faixa corta a reta: a colisão liga aqui, com o monstro vindo de fora
		if not (_dentro(corte, 0.5) and _dentro(corte - dir, 0.5)):
			continue  # a borda da faixa, nesta reta, não cai dentro de uma forma
		var nascer := h + dir * (s + 40.0)
		if not w.limite_andavel.has_point(nascer):
			continue
		w.combate.limpar_partida()
		var r: Dictionary = _cruza_ao_ligar(w, nascer)
		if not r.ligou_dentro:
			continue  # quando a colisão ligou, o monstro não estava dentro da forma: este rumo não exercita a saída livre
		print("    ligou dentro: %d quadro(s) sem colisão, maior deslocamento %.2f px (limite %.2f)" % [r.livres, r.maior, r.limite])
		ok(
			r.saltos == 0,
			"%s: caçador saltou ao ligar a colisão dentro da forma (%d quadro(s); maior %.2f px, limite %.2f px)" % [id, r.saltos, r.maior, r.limite]
		)
		ok(r.saiu, "%s: caçador não saiu da forma antes de chegar ao herói (%d quadro(s) sem colisão)" % [id, r.livres])
		n += 1
	print("  %s colisão ligada dentro de forma: %d cenário(s) conferido(s)" % [id, n])
	return n


## Um caçador sozinho nasce fora da faixa e entra nela. Devolve se ele estava dentro de uma forma quando a colisão ligou (o cenário
## só vale então), quantos quadros andou sem colisão dentro da faixa, quantos saltaram (deslocamento acima de vel*dt*1.5 + 1 px), o
## maior deslocamento e se saiu da forma.
func _cruza_ao_ligar(w, nascer: Vector2) -> Dictionary:
	var h: Vector2 = w.heroi.pos
	var m = w.nascer_monstro(TIPOS[0], nascer, true)
	var entrou := false
	var ligou_dentro := false
	var livres := 0
	var saltos := 0
	var maior := 0.0
	var limite := 0.0
	var saiu := false
	for _i in 900:
		var antes: Vector2 = m.pos
		var ligada: bool = w.cam.retangulo(MARGEM).has_point(antes)  # como em mundo.mover_monstro: vale pela posição de partida do quadro
		w.avancar(PASSO)
		if not entrou:
			if not ligada:
				continue
			entrou = true
			ligou_dentro = m.sem_colisao_ate_sair  # depois do quadro em que a colisão ligou
			if not ligou_dentro:
				break
		if m.sem_colisao_ate_sair:
			livres += 1
			var disp: float = m.pos.distance_to(antes)
			limite = m.vel_v.length() * PASSO * 1.5 + 1.0
			maior = maxf(maior, disp)
			if disp > limite:
				saltos += 1
		elif livres > 0:
			saiu = true
			break
		if m.pos.distance_to(h) <= CONTATO:
			break
	return {"ligou_dentro": ligou_dentro, "livres": livres, "saltos": saltos, "maior": maior, "limite": limite, "saiu": saiu}


func _conferir(id: String, v: Vigia) -> void:
	for p in v.cruzamentos.slice(0, 3):
		print("    cruzou em %s" % str(p))
	for p in v.travas.slice(0, 3):
		print("    travou em %s" % str(p))
	ok(v.cruzamentos.is_empty(), "%s: %d monstro(s) visível(is) atravessaram uma forma" % [id, v.cruzamentos.size()])
	ok(v.travas.is_empty(), "%s: %d caçador(es) travaram ao entrar na faixa da colisão" % [id, v.travas.size()])


func _menor(v: Vigia) -> String:
	return "-" if v.avancos.is_empty() else "%.1f" % float(v.avancos.min())
