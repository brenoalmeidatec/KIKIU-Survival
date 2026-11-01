extends Node
const Curva = preload("res://v2/curva_golpe.gd")
const Mundo = preload("res://v2/mundo.tscn")
const Heroi = preload("res://v2/heroi.gd")
const Herois = preload("res://v2/herois.gd")
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
const Ambiente = preload("res://testes/ambiente_v2.gd")
var falhas := 0


func _init() -> void:
	Ambiente.iniciar(get_script().resource_path)


func _exit_tree() -> void:
	Ambiente.finalizar()


func ok(c: bool, msg: String) -> void:
	if not c:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	print("ISOLAMENTO_USERDIR ", OS.get_user_data_dir())
	for acerto in [0.25, 0.42, 0.5]:
		ok(Curva.corpo(0, acerto) == Vector2.ZERO, "começa neutro")
		ok(Curva.corpo(acerto * 0.5, acerto).x == -2, "preparo de dois pixels")
		ok(Curva.corpo(acerto, acerto) == Vector2(3, 1), "pico no acerto")
		ok(Curva.corpo(1, acerto) == Vector2.ZERO, "termina neutro")
		var anterior := Curva.corpo(0, acerto)
		for i in range(1, 1001):
			var atual := Curva.corpo(i / 1000.0, acerto)
			ok(atual.x >= -2 and atual.x <= 3 and atual.y >= 0 and atual.y <= 1, "teto pequeno")
			ok(absf(atual.x - anterior.x) < 0.07, "sem salto contínuo entre fases")
			anterior = atual
	ok(Personagens.lista().is_empty(), "fixture começa sem slots herdados")
	ok(Meta.saldo() == 0 and Meta.nivel("vida") == 0, "fixture começa sem progresso herdado")
	ok(Config.arquivo.begins_with(Ambiente.raiz) and Personagens.caminho_antigo.begins_with(Ambiente.raiz), "opções e save antigo já isolados antes do ready")
	Config.temporario("pausar_fora", false)
	for nome in ["Breno", "Matthew", "Nick", "Luke", "John", "Bert", "Lukako", "Fabian"]:
		var id = Personagens.criar(nome, Personagens.heroi_do_nome(nome))
		Personagens.ativar(id)
		Herois.forcado = ""
		var w = Mundo.instantiate()
		w.modo_teste = true
		add_child(w)
		w.set_process(false)
		w.combate.audio.mudo = true
		w.reiniciar()
		w.combate.limpar_partida()
		w.combate.diretor.ligado = false
		var h = w.heroi
		h.imortal = true
		h.fonte = Heroi.Fonte.MOUSE
		h.entrada_forcada = Vector2.ZERO
		h.ataque_forcado = false
		h.m_critico = -1
		for i in 120:
			w.avancar(1.0 / 60.0)
		w.mouse_forcado = h.centro() + Vector2(100, 0)
		var m = w.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(34, 0))
		m.vida = 1000000
		m.vida_max = m.vida
		m.peso = 1000000
		m.atordoa_t = 9999
		m.raio_vaga = 0
		h.ataque_forcado = true
		var rastro_no_acerto := false
		var onda_no_acerto := false
		var pausa_no_acerto := false
		var cauda_no_acerto := false
		for i in 180:
			if h.golpes >= 3:
				h.ataque_forcado = false
			var antes: float = m.vida
			w.avancar(1.0 / 60.0)
			if m.vida < antes:
				pausa_no_acerto = pausa_no_acerto or w.combate.parada_t > 0
				for corte in w.combate.fx._cortes:
					rastro_no_acerto = rastro_no_acerto or corte.visible
				for j in w.combate.fx.o_t.size():
					onda_no_acerto = onda_no_acerto or w.combate.fx.o_t[j] < w.combate.fx.o_dur[j]
				cauda_no_acerto = cauda_no_acerto or w.combate.adagas.ativas() > 0
		ok(m.vida < m.vida_max and m.vivo, nome + " combo atinge alvo vivo")
		if nome == "Luke" or nome == "Fabian":
			ok(cauda_no_acerto, nome + ": projétil ativo com cauda no quadro do acerto")
			ok(pausa_no_acerto, nome + " tem micro hit-stop no primeiro acerto do arremesso")
		elif nome == "Matthew":  # a estrela sem outro alvo para ricochetear some no próprio acerto: só o hit-stop
			ok(pausa_no_acerto, "Matthew tem micro hit-stop no primeiro acerto do arremesso")
		else:
			ok(pausa_no_acerto, nome + " hit-stop curto por acerto preservado")
			ok(rastro_no_acerto, nome + " rastro visível no quadro do acerto")
		if nome == "Nick":
			ok(onda_no_acerto, "pancada da marreta preserva onda no impacto")
		h.golpe_cfg = w.combate.cfg.golpe.passos[0]
		h.golpe_dur = 0.4
		h.golpe_dir = Vector2(1, 1).normalized()
		h.estado = Heroi.Estado.GOLPE
		h.golpe_t = h.golpe_dur * float(h.golpe_cfg.acerto_em)
		h._visual(0, Vector2.ZERO)
		ok(h.sprite.position == h.sprite.position.round(), nome + " posição inteira diagonal")
		ok(h.sprite.scale.is_equal_approx(Vector2(1.1, 0.93)), nome + " pico preservado")
		# O visual usa só a fase atual: interromper não pode carregar o deslocamento do golpe.
		for estado in [Heroi.Estado.LIVRE, Heroi.Estado.CARGA, Heroi.Estado.HABILIDADE, Heroi.Estado.ESPECIAL]:
			h.estado = estado
			h.rup_carga = 0
			h._rup_punch = 0
			h._visual(0, Vector2.ZERO)
			ok(h.sprite.position == Vector2.ZERO and h.sprite.scale == Vector2.ONE, nome + " não herda golpe em estado " + str(estado))
		h.estado = Heroi.Estado.ESQUIVA
		h.esq_t = 0
		h._visual(0, Vector2.ZERO)
		ok(h.sprite.position == Vector2.ZERO and h.sprite.scale == Vector2.ONE, nome + " rolamento desenhado não herda golpe")
		h.estado = Heroi.Estado.LIVRE
		h.escudo_ativo = true
		h._visual(0, Vector2.ZERO)
		ok(h.sprite.position == Vector2.ZERO and h.sprite.scale == Vector2.ONE, nome + " escudo neutro")
		h._iniciar_morte()
		h._visual_morto(0)
		ok(h.sprite.position == Vector2.ZERO and h.sprite.scale == Vector2.ONE, nome + " morte não herda golpe")
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Ambiente.finalizar()
	ok(not DirAccess.dir_exists_absolute(Ambiente.raiz), "remove índice, slots, opções e resíduos da fixture")
	for caminho in [Config.arquivo, Meta.caminho_save, Personagens.caminho_indice, Personagens.caminho_base, Personagens.caminho_antigo]:
		ok(caminho.begins_with(Ambiente.raiz), "callback tardio mantém caminho no sandbox")
	print("v2_golpes_visuais falhas=", falhas)
	get_tree().quit(1 if falhas else 0)
