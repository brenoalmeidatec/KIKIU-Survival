extends "res://testes/isolamento_v2.gd"
## Regressões da Maré: Q real, isolamento por mapa/herói e pool limitado.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, texto: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", texto)


func _novo(heroi: String, mapa: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = heroi
	w = Mundo.instantiate()
	w.id_mapa = mapa
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.definir_pos(w.mapa.get_center())
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	w.cam.cravar(w.heroi.centro())
	for m in w.monstros.duplicate():
		m.vivo = false
		w.devolver_monstro(m)
	w.heroi.esp_carga = w.heroi.esp_carga_max


func _alvo(p: Vector2):
	var tipo: Dictionary = w.elenco.tipos[0]
	var m = w.nascer_monstro(str(tipo.sprite), w.heroi.pos + p, true, 1.0, 1.0, tipo)
	m.atordoa_t = 60.0
	m.vida = 1.0
	m.vida_max = 1.0
	return m


func _ativos() -> int:
	var n := 0
	for t in w.combate.fx._frag_t:
		if t > 0.0:
			n += 1
	return n


func _passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _q_real(heroi: String, mapa: String, fator: float, espera_fragmentos: bool) -> void:
	Config.temporario("particulas_sim", "nenhuma" if fator <= 0.0 else "poucas")
	await _novo(heroi, mapa)
	w.args["particulas"] = "nenhuma" if fator <= 0.0 else "poucas"
	var fx = w.combate.fx
	var ids: Array[int] = []
	for s in fx._fragmentos:
		ids.append(s.get_instance_id())
	ok(ids.size() == 24, "24 fragmentos pré-criados")
	for i in 16:
		var a := TAU * float(i) / 16.0
		_alvo(Vector2(cos(a) * 60.0, sin(a) * 60.0 * 0.62))
	var mortes0: int = w.combate.mortes
	ok(w.heroi.especial(), "%s/%s: Q cheio dispara" % [heroi, mapa])
	_passos(43)
	ok(w.combate.mortes > mortes0, "%s/%s: Q matou alvos reais" % [heroi, mapa])
	var ativos := _ativos()
	ok(ativos <= 24, "pool respeita teto de 24")
	ok((ativos > 0) == espera_fragmentos, "%s/%s/fator%s: fragmentos=%d" % [heroi, mapa, fator, ativos])
	var depois: Array[int] = []
	for s in fx._fragmentos:
		depois.append(s.get_instance_id())
	ok(ids == depois, "Q reutiliza exatamente os mesmos nós do pool")
	_passos(120)
	ok(_ativos() == 0, "fragmentos terminam após o TTL")


func _onda() -> void:
	await _novo("nicao", "cidade")
	var d = w.combate.diretor
	d.rng.seed = 449
	ok(d._mare_ativa(), "Maré ativa para Nick na Vila")
	var tela: Rect2 = w.cam.retangulo()
	for lado in [-1, 1]:
		var ponto = d._ponto_mare(lado)
		ok(ponto != null and not tela.has_point(ponto), "ponto central nasce fora da tela")
		if ponto != null:
			ok(w.limite_andavel.has_point(ponto) and Colisao.livre(ponto, 7.0), "ponto central é livre e andável")
	d.ligado = true
	d.proxima_onda = 10.0
	w.tempo_partida = 8.9
	d.atualizar(0.01)
	ok(d.mare_aviso and w.combate.ultimo_anuncio == "MARÉ DE SANGUE!", "aviso antecede a onda")
	w.tempo_partida = 10.0
	d.atualizar(0.01)
	ok(d.ondas == 1, "primeiro pulso nasce no horário")
	ok(d.mare_pendente > 0 and d.mare_t > 0.0, "segundo pulso fica pendente")
	ok(w.monstros.size() > 0, "primeiro pulso cria monstros")
	ok(w.monstros.size() <= d.teto(), "primeiro pulso respeita teto")
	d.atualizar(1.1)
	ok(d.mare_pendente == 0 and d.mare_t < 0.0, "segundo pulso consome a espera")
	ok(w.monstros.size() <= d.teto(), "segundo pulso respeita teto")
	# Borda esquerda na altura central: o lado esquerdo esgota, mas há setores livres na Vila.
	w.heroi.definir_pos(Vector2(w.limite_andavel.position.x + 16.0, w.mapa.get_center().y))
	w.cam.cravar(w.heroi.centro())
	d.rng.seed = 449
	var ponto_borda = d._ponto_mare(-1)
	ok(ponto_borda != null, "borda esquerda: fallback encontra setor livre")
	if ponto_borda != null:
		ok(not w.cam.retangulo().has_point(ponto_borda), "borda: fora da tela")
		ok(w.limite_andavel.has_point(ponto_borda) and Colisao.livre(ponto_borda, 7.0), "borda: ponto livre e andável")
	w.reiniciar()
	ok(d.mare_pendente == 0 and d.mare_t < 0.0 and not d.mare_aviso, "reiniciar limpa estado da Maré")
	await _novo("nicao", "floresta")
	ok(not w.combate.diretor._mare_ativa(), "outro mapa não ativa Maré")
	await _novo("hazaki", "cidade")
	ok(not w.combate.diretor._mare_ativa(), "outro herói não ativa Maré")


func _ready() -> void:
	await _q_real("nicao", "cidade", 1.0, true)
	await _q_real("nicao", "cidade", 0.0, false)
	await _q_real("nicao", "floresta", 1.0, false)
	await _q_real("hazaki", "cidade", 1.0, false)
	await _onda()
	Herois.forcado = ""
	if w != null:
		w.queue_free()
	await get_tree().process_frame
	print("v2_mare_sangue falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)
