extends "res://testes/isolamento_v2.gd"
## Regressões da Maré: Q real, isolamento por mapa/herói e pool limitado.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
const Diretor := preload("res://v2/diretor.gd")
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
	w.combate.diretor.tempo_mult = 1.0  # este teste mede a Maré no relógio da partida; o fator por mapa (ECO-1) é o de testes/v2_tempo_mult
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
	# ULT-C: a Maré vale em todo mapa e para todo herói com Q; só `mare: false` no mapa a desliga (válvula)
	await _novo("nicao", "floresta")
	ok(w.combate.diretor._mare_ativa(), "a Maré vale na Floresta com o Nick (todo mapa)")
	w.dados = w.dados.duplicate()
	w.dados["mare"] = false
	ok(not w.combate.diretor._mare_ativa(), "mare: false no mapa desliga a Maré")
	await _novo("hazaki", "cidade")
	ok(w.combate.diretor._mare_ativa(), "a Maré vale para o Hazaki (todo herói tem a sua)")


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
	ok(d.mare_chamadas == 0, "a Maré só é chamada na limpeza da tela, não ao apertar")
	_passos(40)
	ok(d.mare_chamadas == 1 and d.mare_chamada_t > 0.0, "a limpeza do Q chamou a Maré")
	ok(w.combate.anuncios == anuncios0, "o Q não anuncia nada sobre a Maré")
	ok(str(w.combate.especial.blocos["terremoto"].desc).find("Maré") < 0, "a descrição do Q não cita a Maré")
	# o aviso normal da Maré vem 1,2 s antes de chegar
	w.combate.ultimo_anuncio = ""
	d.mare_chamada_t = 1.5
	d.atualizar(0.4)
	ok(d.mare_aviso and w.combate.ultimo_anuncio == "MARÉ DE SANGUE!", "o aviso normal da Maré sai antes de ela chegar")
	var antes: int = d.ondas
	var t0: float = w.tempo_partida
	d.proxima_onda = t0 + 10.0  # abaixo do intervalo mínimo: só o maxf do diretor a empurra para t0 + intervalo_min
	d.atualizar(1.2)
	ok(d.ondas == antes and d.mare_chamada_t < 0.0, "a Maré chamada chegou sem subir o contador de escalada")
	ok(w.monstros.size() > 0, "a Maré chamada põe monstros em campo")
	ok(is_equal_approx(d.proxima_onda, t0 + float(cfg.intervalo_min)), "a Maré normal foi empurrada para t0 + intervalo mínimo (%s)" % d.proxima_onda)
	ok(d.mare_ultima_t == w.tempo_partida, "a Maré chamada marca a última Maré")
	# intervalo mínimo: logo depois não chama de novo (sem spam)
	ok(not d.mare_chamar(), "dentro do intervalo mínimo o Q não chama outra Maré")
	# recusa quando a Maré normal já está para chegar
	d.mare_ultima_t = w.tempo_partida - 100.0
	d.proxima_onda = w.tempo_partida + float(_mare("nicao").atraso) - 0.5
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
	d.ondas = 2  # mesmo contador nas duas, para só o `fator` diferir
	d.onda_forte(float(cfg.q_curta), false)
	d.atualizar(1.1)
	var curta: int = w.monstros.size()
	_limpar_monstros()
	d.ondas = 2
	d.onda_forte(1.0, false)
	d.atualizar(1.1)
	var cheia: int = w.monstros.size()
	ok(d.ondas == 2, "a chamada não mexe no contador de escalada")
	ok(curta > 0 and cheia <= d.teto(), "as duas respeitam o teto (%d e %d)" % [curta, cheia])
	ok(
		absf(float(curta) / float(cheia) - float(cfg.q_curta)) < 0.1,
		"a Maré curta sai em ~%d%% da cheia (%d de %d)" % [roundi(float(cfg.q_curta) * 100.0), curta, cheia]
	)
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
	var ac: float = float(_mare("nicao").abate_carga)
	ok(c_comum > 0.0 and is_equal_approx(c_mare / c_comum, ac), "abate da Maré carrega x%s (%s / %s)" % [ac, c_mare, c_comum])
	_limpar_monstros()
	var tipo: Dictionary = w.elenco.tipos[0]
	var reaproveitado = w.nascer_monstro(str(tipo.sprite), w.heroi.pos + Vector2(200, 0), true, 1.0, 1.0, tipo)
	ok(not reaproveitado.mare, "monstro reaproveitado do pool nasce sem a marca da Maré")
	# ULT-C: a Maré vale na Floresta com o Nick; com mare: false no mapa o Q não chama
	await _novo("nicao", "floresta")
	w.combate.diretor.ligado = true
	ok(w.combate.diretor.mare_chamar(), "na Floresta o Nick chama Maré (ULT-C)")
	await _novo("nicao", "floresta")
	w.dados = w.dados.duplicate()
	w.dados["mare"] = false
	w.combate.diretor.ligado = true
	ok(not w.combate.diretor.mare_chamar(), "com mare: false no mapa o Q não chama Maré")


## A Maré da Vila no fator de tempo REAL do mapa (ECO-1, tempo_mult 1,25): proxima_onda está no relógio do diretor, mas o atraso da Maré e o aviso de
## 1,2 s andam em dt (tempo real). A guarda do Q e o aviso comparam o tempo real que falta, não os segundos do relógio.
func _mare_no_fator() -> void:
	await _novo("nicao", "cidade")
	var d = w.combate.diretor
	d.tempo_mult = 1.25
	d.ligado = true
	w.tempo_partida = 30.0
	ok(is_equal_approx(d.relogio(), 37.5), "Vila: aos 30 s reais o relógio do diretor marca 37,5 s")
	d.proxima_onda = d.relogio() + 5.0
	ok(is_equal_approx(d.falta_onda_real(), 4.0), "faltam 5 s do relógio = 4 s reais (%s)" % d.falta_onda_real())
	# 3,5 s do relógio = 2,8 s reais, menos que o atraso do Nick (3 s): a Maré normal chega antes da chamada, então o Q não chama
	d.proxima_onda = d.relogio() + float(_mare("nicao").atraso) + 0.5
	ok(not d.mare_chamar(), "Vila 1,25: a Maré normal chega em 2,8 s reais (< atraso do Nick), o Q não chama")
	# 3,9 s do relógio = 3,12 s reais, mais que o atraso: chama
	d.proxima_onda = d.relogio() + 3.9
	ok(d.mare_chamar() and d.mare_chamadas == 1, "Vila 1,25: a Maré normal só chega em 3,12 s reais (> atraso), o Q chama")
	d.mare_chamada_t = -1.0
	d.mare_aviso = false
	# o aviso sai 1,2 s REAIS antes: 2 s do relógio = 1,6 s reais ainda não, 1,4 s do relógio = 1,12 s reais já
	d.proxima_onda = d.relogio() + 2.0
	d.atualizar(0.0)
	ok(not d.mare_aviso, "Vila 1,25: a 1,6 s reais da Maré o aviso ainda não saiu")
	d.proxima_onda = d.relogio() + 1.4
	d.atualizar(0.0)
	ok(d.mare_aviso, "Vila 1,25: a 1,12 s reais da Maré o aviso já saiu")


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
	# o aviso real (_mare_avisar) com a horda ocupando todas as vozes e o áudio ligado
	for p in au._players:
		p.stop()
	au._ultimo_t.clear()
	for i in au._players.size():
		au.tocar("morte", 1.0, 0.0, 0.0)
	var d = w.combate.diretor
	d.mare_aviso = false
	rou0 = au.roubados
	d._mare_avisar()
	ok(au.roubados == rou0 + 1 and _tocando(au, "onda") == 1, "_mare_avisar toca mesmo com todas as vozes ocupadas")
	au.mudo = true
	for p in au._players:
		p.stop()


func _tocando(au, nome: String) -> int:
	var n := 0
	for p in au._players:
		if p.playing and p.stream != null and p.stream.resource_path.ends_with("/" + nome + ".wav"):
			n += 1
	return n


func _mare(chave: String) -> Dictionary:
	return w.combate.especial.mare_de(chave)


## O bloco `mare` de cada Q (ULT-C): a formação e o atraso de cada herói, e o padrão do abate quando o bloco não diz outro.
func _formacao_por_heroi() -> void:
	await _novo("hazaki", "floresta")
	ok(str(_mare("hazaki").formacao) == "cone" and is_equal_approx(float(_mare("hazaki").atraso), 2.5), "Hazaki: cone, atraso 2,5 s")
	ok(str(_mare("nicao").formacao) == "pinca" and is_equal_approx(float(_mare("nicao").atraso), 3.0), "Nick: pinça, atraso 3,0 s")
	ok(str(_mare("lucas").formacao) == "anel" and is_equal_approx(float(_mare("lucas").atraso), 3.5), "Luke: anel, atraso 3,5 s")
	ok(is_equal_approx(float(_mare("hazaki").abate_carga), 2.2), "abate da Maré: padrão 2,2 onde o bloco não diz outro")
	ok(str(_mare("sem_q").formacao) == "cone", "herói fora de herois cai no Q padrão (investida) e na Maré dele")


## O cone do Hazaki (ULT-C): os pontos saem do leque centrado na direção em que ele está virado, fora da tela, andáveis e livres.
func _cone() -> void:
	await _novo("hazaki", "floresta")
	var d = w.combate.diretor
	d.rng.seed = 311
	var tela: Rect2 = w.cam.retangulo()
	var centro := tela.get_center()
	var meio := deg_to_rad(35.0) + 0.02
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		w.heroi.dir_olhar = dir
		var pontos := 0
		var no_leque := 0
		var fora := 0
		var andaveis := 0
		for i in 40:
			var p = d._ponto_cone(70.0)
			if p == null:
				continue
			pontos += 1
			if absf(angle_difference(dir.angle(), (p - centro).angle())) <= meio:
				no_leque += 1
			if not tela.has_point(p):
				fora += 1
			if w.limite_andavel.has_point(p) and Colisao.livre(p, 7.0):
				andaveis += 1
		ok(pontos >= 30, "cone %s: quase todo sorteio acha ponto (%d de 40)" % [dir, pontos])
		ok(no_leque == pontos, "cone %s: todo ponto cai no leque de 70 graus (%d de %d)" % [dir, no_leque, pontos])
		ok(fora == pontos and andaveis == pontos, "cone %s: pontos fora da tela, andáveis e livres" % dir)


## O ponto de borda (função pura): o raio do centro cruza a borda certa em cada direção, inclusive os cantos.
func _borda() -> void:
	var r := Rect2(0, 0, 960, 540)
	var c := Vector2(480, 270)
	ok(Diretor.ponto_na_borda(c, Vector2.RIGHT, r).is_equal_approx(Vector2(960, 270)), "borda: direita")
	ok(Diretor.ponto_na_borda(c, Vector2.LEFT, r).is_equal_approx(Vector2(0, 270)), "borda: esquerda")
	ok(Diretor.ponto_na_borda(c, Vector2.UP, r).is_equal_approx(Vector2(480, 0)), "borda: cima")
	ok(Diretor.ponto_na_borda(c, Vector2.DOWN, r).is_equal_approx(Vector2(480, 540)), "borda: baixo")
	ok(Diretor.ponto_na_borda(c, (Vector2(960, 540) - c).normalized(), r).is_equal_approx(Vector2(960, 540)), "borda: canto")


## O Q chama a Maré no instante da limpeza (não ao apertar), com o atraso do herói: Hazaki 2,5 s, Nick 3,0 s, Luke 3,5 s.
func _chamada_por_heroi() -> void:
	for par in [["hazaki", 2.5], ["nicao", 3.0], ["lucas", 3.5]]:
		await _novo(str(par[0]), "floresta")
		var d = w.combate.diretor
		d.ligado = true
		d.proxima_onda = 900.0
		d.mare_ultima_t = -1000.0
		w.tempo_partida = 30.0
		var limpa: float = float(w.combate.especial.bloco_de(str(par[0])).limpa_em)
		ok(w.heroi.especial(), "%s: Q dispara" % par[0])
		ok(d.mare_chamada_t < 0.0, "%s: ao apertar o Q não chama Maré" % par[0])
		var n := 0
		while d.mare_chamada_t < 0.0 and n < 240:
			_passos(1)
			n += 1
		ok(d.mare_chamadas == 1, "%s: a limpeza chama uma Maré" % par[0])
		ok(absf(n * PASSO - limpa) <= 2.0 * PASSO + 0.01, "%s: chama no instante da limpeza (%.2f s, limpa em %.2f)" % [par[0], n * PASSO, limpa])
		var atraso := float(par[1])
		ok(
			d.mare_chamada_t <= atraso + 0.001 and d.mare_chamada_t >= atraso - 2.0 * PASSO,
			"%s: a Maré chega em %s s (%.3f)" % [par[0], atraso, d.mare_chamada_t]
		)
		d.atualizar(atraso + 0.05)
		var marcados := 0
		for m in w.monstros:
			if m.mare:
				marcados += 1
		ok(d.mare_chamada_t < 0.0 and marcados > 0, "%s: a Maré chegou com monstros marcados (%d)" % [par[0], marcados])


func _ready() -> void:
	await _q_real("nicao", "cidade", 1.0, true)
	await _q_real("nicao", "cidade", 0.0, false)
	await _q_real("nicao", "floresta", 1.0, false)
	await _q_real("hazaki", "cidade", 1.0, false)
	await _onda()
	await _q_chama_mare()
	await _mare_no_fator()
	await _formacao_por_heroi()
	await _cone()
	_borda()
	await _chamada_por_heroi()
	await _som_prioritario()
	Herois.forcado = ""
	if w != null:
		w.queue_free()
	await get_tree().process_frame
	print("v2_mare_sangue falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)
