extends Node
const Mundo = preload("res://v2/mundo.tscn")
const Heroi = preload("res://v2/heroi.gd")
const Herois = preload("res://v2/herois.gd")
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
const Ambiente = preload("res://testes/ambiente_v2.gd")
var w
var falhas := 0


func _init() -> void:
	Ambiente.iniciar(get_script().resource_path)


func _exit_tree() -> void:
	Ambiente.finalizar()


func ok(c: bool, msg: String) -> void:
	if not c:
		falhas += 1
		print("FALHOU: ", msg)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.hit_stops = 0  # contador diagnóstico é cumulativo entre partidas
	w.combate.ultimo_hit_stop = 0
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.heroi.m_critico = -1
	for i in 120:
		w.avancar(1.0 / 60.0)
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	seed(7)


func alvo(dx: float):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, 0))
	m.vida_max = 1000000
	m.vida = m.vida_max
	m.peso = 1000000
	m.atordoa_t = 9999
	m.raio_vaga = 0
	return m


func lancar(principal := true) -> void:
	var p: Dictionary = w.combate.cfg.golpe.passos[0].duplicate(true)
	p.n = 5
	p.leque = 0
	p.perfura = 2
	w.combate.adagas.lancar(w.heroi, w.heroi.pos + w.heroi.ORIGEM_GOLPE, Vector2.RIGHT, p, principal)


func passos(n: int) -> void:
	for i in n:
		w.avancar(1.0 / 60.0)


func medir(hz: int, velocidade: float, impacto: bool) -> Dictionary:
	zerar()
	var h = w.heroi
	h.m_vel_ataque = velocidade
	w.combate.cfg.golpe.impacto_adagas.hit_stop = 0.014 if impacto else 0.0
	var modelo: float = w.combate.ciclo_do_combo(1.0 / hz)
	var m = alvo(30)
	h.ataque_forcado = true
	var inicios := []
	var danos := []
	var anterior := 0
	var dt := 1.0 / float(hz)
	for i in 30 * hz:
		w.avancar(dt)
		m.definir_pos(h.pos + Vector2(30, 0))
		if h.golpes != anterior:
			anterior = h.golpes
			if h.golpe_i == 0:
				inicios.append((i + 1) * dt)
				danos.append(m.vida_max - m.vida)
		if inicios.size() >= 17:
			break
	ok(inicios.size() >= 17, "Luke completa ciclos medidos")
	if inicios.size() < 17:
		return {}
	var dur: float = float(inicios[16]) - float(inicios[8])
	var ciclo := dur / 8.0
	var erro := absf(ciclo - modelo)
	print("CICLO Luke hz=", hz, " vel=", velocidade, " impacto=", impacto, " real=", ciclo, " modelo=", modelo, " erro=", erro)
	ok(erro <= dt + 0.000001, "modelo de alvo próximo difere no máximo um quadro por combo")
	return {
		"hz": hz,
		"velocidade": velocidade,
		"impacto": impacto,
		"ciclo_real": ciclo,
		"ciclo_modelo": modelo,
		"erro_s": erro,
		"dps_real": (float(danos[16]) - float(danos[8])) / dur,
		"dano_8_combos": float(danos[16]) - float(danos[8]),
		"hit_stops": w.combate.hit_stops
	}


func _ready() -> void:
	print("ISOLAMENTO_USERDIR ", OS.get_user_data_dir())
	ok(Personagens.lista().is_empty(), "fixture começa sem slots herdados")
	ok(Meta.saldo() == 0 and Meta.nivel("vida") == 0, "fixture começa sem progresso herdado")
	ok(Config.arquivo.begins_with(Ambiente.raiz) and Personagens.caminho_antigo.begins_with(Ambiente.raiz), "opções e save antigo já isolados antes do ready")
	Config.temporario("pausar_fora", false)
	Personagens.ativar(Personagens.criar("Luke", "lucas"))
	Herois.forcado = ""
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	lancar()
	passos(60)
	ok(w.combate.hit_stops == 0, "sem alvo vivo não pausa")
	zerar()
	for dx in [24, 40, 56]:
		alvo(dx)
	lancar()
	passos(30)
	ok(w.combate.adagas.acertos >= 10, "várias lâminas e perfurações acertaram")
	ok(w.combate.hit_stops == 1 and is_equal_approx(w.combate.ultimo_hit_stop, 0.014), "só primeiro acerto do grupo pausa 14 ms")
	zerar()
	alvo(24)
	lancar()
	passos(1)
	var a = w.combate.adagas
	var recarga: float = a._pausa_recarga
	var pausa: float = w.combate.parada_t
	ok(recarga > 0 and pausa > 0, "impacto arma cooldown e pausa")
	w.combate.pausado = true
	passos(20)
	ok(a._pausa_recarga == recarga and w.combate.parada_t == pausa, "menu congela cooldown e pausa pendentes")
	w.combate.pausado = false
	lancar()
	passos(3)
	ok(w.combate.hit_stops == 1, "novo grupo dentro do cooldown não pausa")
	passos(10)
	lancar()
	passos(4)
	ok(w.combate.hit_stops == 2, "novo grupo depois do cooldown pode pausar")
	zerar()
	alvo(24)
	lancar(false)
	w.combate.armas.mods.chuva = 100
	passos(30)
	ok(w.combate.adagas.acertos > 0 and w.combate.hit_stops == 0, "Q e chuva atingem sem pausar")
	zerar()
	for dx in [24, 40, 56]:
		alvo(dx)
	w.heroi.esp_carga = w.heroi.esp_carga_max
	ok(w.heroi.especial(), "Q real do Luke iniciou")
	passos(180)
	ok(w.combate.adagas.acertos > 0 and w.combate.hit_stops == 0, "Tempestade real atinge sem pedir hit-stop")
	zerar()
	ok(a.a_grupo.size() == a.MAX and a.a_pausa.size() == a.MAX, "metadados limitados ao pool")
	ok(a._grupo == 0 and a._pausa_recarga == 0 and a.a_pausa.count(1) == 0, "restart limpa grupos e cooldown")
	alvo(24)
	lancar()
	passos(4)
	ok(w.combate.hit_stops == 1, "primeiro grupo da nova partida pausa normalmente")
	var c = w.combate
	c.ciclo_do_combo()
	var calculos: int = c._ciclo_adagas_calculos
	for i in 20:
		c.ciclo_do_combo()
	ok(c._ciclo_adagas_calculos == calculos, "consultas repetidas de Status reutilizam uma entrada")
	w.heroi.m_vel_ataque *= 1.5
	c.ciclo_do_combo()
	ok(c._ciclo_adagas_calculos == calculos + 1, "velocidade invalida cache")
	for par in ["pausa_fim_combo", "hit_stop", "recarga", "duracao", "acerto_em"]:
		var d: Dictionary = c.cfg.golpe
		if par in ["hit_stop", "recarga"]:
			d = c.cfg.golpe.impacto_adagas
		elif par in ["duracao", "acerto_em"]:
			d = c.cfg.golpe.passos[0]
		var original: float = d[par]
		calculos = c._ciclo_adagas_calculos
		d[par] = original + 0.01
		c.ciclo_do_combo()
		ok(c._ciclo_adagas_calculos == calculos + 1, "dado " + par + " invalida cache")
		d[par] = original
		c.ciclo_do_combo()
	calculos = c._ciclo_adagas_calculos
	c.ciclo_do_combo(1.0 / 120.0)
	ok(c._ciclo_adagas_calculos == calculos + 1, "dt invalida cache")
	ok(c._ciclo_adagas_chave.size() == 5 + c.cfg.golpe.passos.size() * 2, "cache único tem tamanho limitado aos parâmetros")
	var medidas := []
	for hz in [60, 120]:
		for vel in [1.0, 1.5, 3.0]:
			for impacto in [false, true]:
				medidas.append(medir(hz, vel, impacto))
	for i in range(0, medidas.size(), 2):
		ok(medidas[i].dano_8_combos == medidas[i + 1].dano_8_combos, "micro pausa preserva dano dos mesmos oito combos")
		ok(medidas[i + 1].ciclo_real > medidas[i].ciclo_real, "micro pausa aumenta honestamente tempo real do combo")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			var f := FileAccess.open(arg.trim_prefix("--saida="), FileAccess.WRITE)
			f.store_string(JSON.stringify(medidas, "\t"))
			f.close()
	w.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Ambiente.finalizar()
	ok(not DirAccess.dir_exists_absolute(Ambiente.raiz), "remove índice, slots, opções e resíduos da fixture")
	for caminho in [Config.arquivo, Meta.caminho_save, Personagens.caminho_indice, Personagens.caminho_base, Personagens.caminho_antigo]:
		ok(caminho.begins_with(Ambiente.raiz), "callback tardio mantém caminho no sandbox")
	print("v2_adagas_impacto falhas=", falhas)
	get_tree().quit(1 if falhas else 0)
