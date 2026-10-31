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
	ok(d._mare_ativa(), "Maré ativa para Nicão na Vila")
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


## O Q Terremoto chama a próxima Maré (sem texto de ligação) e os abates da Maré carregam o Q mais rápido.
func _q_chama_mare() -> void:
	await _novo("nicao", "cidade")
	var d = w.combate.diretor
	var cfg: Dictionary = w.combate.cfg.diretor.mare
	d.ligado = true
	d.rng.seed = 449
	w.tempo_partida = 30.0
	d.proxima_onda = 90.0
	ok(d.mare_chamada_t < 0.0 and d.mare_chamadas == 0, "sem Q, nenhuma Maré chamada")
	var anuncios0: int = w.combate.anuncios
	ok(w.heroi.especial(), "Q do Nicão dispara na Vila")
	ok(d.mare_chamadas == 0, "a Maré só é chamada na pancada, não ao apertar")
	_passos(40)
	ok(d.mare_chamadas == 1 and d.mare_chamada_t > 0.0, "a pancada do Q chamou a Maré")
	ok(d.mare_chamada_t <= float(cfg.q_atraso), "a Maré chega em até q_atraso segundos")
	ok(w.combate.anuncios == anuncios0, "o Q não anuncia nada sobre a Maré")
	ok(str(w.combate.especial.blocos["terremoto"].desc).find("Maré") < 0, "a descrição do Q não cita a Maré")
	# o aviso normal da Maré vem 1,2 s antes de chegar
	w.combate.ultimo_anuncio = ""
	d.mare_chamada_t = 1.5
	d.atualizar(0.4)
	ok(d.mare_aviso and w.combate.ultimo_anuncio == "MARÉ DE SANGUE!", "o aviso normal da Maré sai antes de ela chegar")
	var antes: int = d.ondas
	var t0: float = w.tempo_partida
	d.atualizar(1.2)
	ok(d.ondas == antes + 1 and d.mare_chamada_t < 0.0, "a Maré chamada chegou")
	ok(w.monstros.size() > 0, "a Maré chamada põe monstros em campo")
	ok(d.proxima_onda >= t0 + float(cfg.intervalo_min), "a Maré normal fica depois do intervalo mínimo")
	ok(d.mare_ultima_t == w.tempo_partida, "a Maré chamada marca a última Maré")
	# intervalo mínimo: logo depois não chama de novo (sem spam)
	ok(not d.mare_chamar(), "dentro do intervalo mínimo o Q não chama outra Maré")
	# recusa quando a Maré normal já está para chegar
	d.mare_ultima_t = w.tempo_partida - 100.0
	d.proxima_onda = w.tempo_partida + float(cfg.q_atraso) - 0.5
	ok(not d.mare_chamar(), "com a Maré normal logo ali o Q não chama")
	# curta se a última foi há pouco, cheia se faz tempo
	d.mare_pendente = 0
	d.mare_t = -1.0
	d.proxima_onda = w.tempo_partida + 200.0
	d.mare_ultima_t = w.tempo_partida - (float(cfg.intervalo_min) + 2.0)
	ok(d.mare_chamar() and is_equal_approx(d.mare_chamada_fator, float(cfg.q_curta)), "logo após outra Maré a chamada vem curta")
	d.mare_chamada_t = -1.0
	d.mare_ultima_t = w.tempo_partida - (float(cfg.q_cheia_apos) + 5.0)
	ok(d.mare_chamar() and is_equal_approx(d.mare_chamada_fator, 1.0), "faz tempo desde a última: a chamada vem cheia")
	d.mare_chamada_t = -1.0
	# tamanho: a Maré curta é menor que a cheia e ambas respeitam o teto
	_limpar_monstros()
	d.onda_forte(float(cfg.q_curta))
	d.atualizar(1.1)
	var curta: int = w.monstros.size()
	_limpar_monstros()
	d.onda_forte(1.0)
	d.atualizar(1.1)
	var cheia: int = w.monstros.size()
	ok(curta > 0 and curta < cheia and cheia <= d.teto(), "Maré curta (%d) menor que a cheia (%d), dentro do teto" % [curta, cheia])
	# os monstros da Maré levam a marca
	var marcados := 0
	for m in w.monstros:
		if m.mare:
			marcados += 1
	ok(marcados == cheia, "todo monstro da Maré leva a marca (%d de %d)" % [marcados, cheia])
	_limpar_monstros()
	# abate da Maré carrega o Q mais rápido, só dos monstros marcados
	var e = w.combate.especial
	e.cancelar(w.heroi)  # o Q ainda estava no ar: encerra e tira a graça pós-Q, que não carrega
	e._graca = 0.0
	e._onda_t = -1.0
	var comum_m = _alvo(Vector2(300, 0))
	var mare_m = _alvo(Vector2(-300, 0))
	mare_m.mare = true
	w.heroi.esp_carga = 0.0
	e.abate(comum_m)
	var c_comum: float = w.heroi.esp_carga
	w.heroi.esp_carga = 0.0
	e.abate(mare_m)
	var c_mare: float = w.heroi.esp_carga
	ok(c_comum > 0.0 and is_equal_approx(c_mare / c_comum, float(cfg.abate_carga)), "abate da Maré carrega x%s (%s / %s)" % [cfg.abate_carga, c_mare, c_comum])
	_limpar_monstros()
	var tipo: Dictionary = w.elenco.tipos[0]
	var reaproveitado = w.nascer_monstro(str(tipo.sprite), w.heroi.pos + Vector2(200, 0), true, 1.0, 1.0, tipo)
	ok(not reaproveitado.mare, "monstro reaproveitado do pool nasce sem a marca da Maré")
	# fora da Vila / sem o Nicão nada acontece
	await _novo("nicao", "floresta")
	w.combate.diretor.ligado = true
	ok(not w.combate.diretor.mare_chamar(), "na floresta o Q não chama Maré")
	await _novo("hazaki", "cidade")
	w.combate.diretor.ligado = true
	ok(not w.combate.diretor.mare_chamar(), "outro herói não chama Maré")


func _limpar_monstros() -> void:
	for m in w.monstros.duplicate():
		m.vivo = false
		w.devolver_monstro(m)
	w.combate.diretor.mare_pendente = 0
	w.combate.diretor.mare_t = -1.0


## O som da Maré some quando as 10 vozes estão ocupadas pela horda: o aviso e o estouro (prioritários) tomam a voz de um som comum.
func _som_prioritario() -> void:
	await _novo("nicao", "cidade")
	var au = w.combate.audio
	au.mudo = false
	for p in au._players:
		p.stop()
	au._ultimo_t.clear()
	# a horda ocupa as 10 vozes com sons comuns
	for i in au._players.size():
		au.tocar("morte", 1.0, 0.0, 0.0)
	var ocupadas := 0
	for p in au._players:
		if p.playing:
			ocupadas += 1
	ok(ocupadas == au._players.size(), "a horda ocupa todas as vozes (%d)" % ocupadas)
	var desc0: int = au.descartados
	au.tocar("orbe", 1.0, 0.0, 0.0)
	ok(au.descartados == desc0 + 1, "som comum sem voz livre é descartado")
	var rou0: int = au.roubados
	au.tocar("onda", 0.8, -2.0, 0.0)
	ok(au.roubados == rou0 + 1 and _tocando(au, "onda") == 1, "o aviso da Maré toma a voz de um som comum e toca")
	var db := -99.0
	for p in au._players:
		if p.playing and p.stream != null and p.stream.resource_path.ends_with("/onda.wav"):
			db = p.volume_db
	ok(db > -20.0 and db < 6.0, "volume do player é audível (%s dB)" % db)
	au.tocar("ruptura_disparo", 0.7, 1.0, 0.0)
	ok(_tocando(au, "onda") == 1 and _tocando(au, "ruptura_disparo") == 1, "o aviso não é roubado pelo estouro do Q")
	au.mudo = true
	for p in au._players:
		p.stop()


func _tocando(au, nome: String) -> int:
	var n := 0
	for p in au._players:
		if p.playing and p.stream != null and p.stream.resource_path.ends_with("/" + nome + ".wav"):
			n += 1
	return n


func _ready() -> void:
	await _q_real("nicao", "cidade", 1.0, true)
	await _q_real("nicao", "cidade", 0.0, false)
	await _q_real("nicao", "floresta", 1.0, false)
	await _q_real("hazaki", "cidade", 1.0, false)
	await _onda()
	await _q_chama_mare()
	await _som_prioritario()
	Herois.forcado = ""
	if w != null:
		w.queue_free()
	await get_tree().process_frame
	print("v2_mare_sangue falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)
