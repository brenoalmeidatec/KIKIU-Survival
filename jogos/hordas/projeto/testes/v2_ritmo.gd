extends Node
const Mundo := preload("res://v2/mundo.tscn")
var falhas := 0
var w
const Meta := preload("res://v2/meta.gd")
const Slots := preload("res://v2/personagens.gd")
const FIXTURE := "user://testes_v2/v2_ritmo/"
var anteriores: Array = []


func _isolar() -> void:
	anteriores = [Meta.caminho_save, Slots.caminho_indice, Slots.caminho_base, Slots.caminho_antigo, Config.arquivo]
	Meta.caminho_save = FIXTURE + "meta.cfg"
	Slots.caminho_indice = FIXTURE + "indice.cfg"
	Slots.caminho_base = FIXTURE + "slot_"
	Slots.caminho_antigo = FIXTURE + "antigo.cfg"
	Config.arquivo = FIXTURE + "opcoes.cfg"
	_limpar_fixture(FIXTURE)
	DirAccess.make_dir_recursive_absolute(FIXTURE)
	Config.recarregar()


func _limpar_fixture(pasta: String) -> void:
	var d := DirAccess.open(pasta)
	if d == null:
		return
	d.include_hidden = true
	d.list_dir_begin()
	var nome := d.get_next()
	while nome != "":
		var p := pasta.path_join(nome)
		if d.current_is_dir():
			_limpar_fixture(p)
		else:
			ok(DirAccess.remove_absolute(p) == OK, "limpa arquivo QA")
		nome = d.get_next()
	d.list_dir_end()
	ok(DirAccess.remove_absolute(pasta) == OK, "limpa diretorio QA")


func _exit_tree() -> void:
	_finalizar()


func _finalizar() -> void:
	if anteriores.is_empty():
		return
	_limpar_fixture(FIXTURE)
	if not anteriores.is_empty():
		Meta.caminho_save = anteriores[0]
		Slots.caminho_indice = anteriores[1]
		Slots.caminho_base = anteriores[2]
		Slots.caminho_antigo = anteriores[3]
		Config.arquivo = anteriores[4]
	anteriores.clear()


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func igual(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _ready() -> void:
	_isolar()
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.reiniciar()
	var c = w.combate
	c.audio.mudo = true
	c.limpar_partida()
	c.diretor.ligado = false
	var h = w.heroi
	var r = c.ritmo
	ok(r.itens.size() == 4, "pool fixo")
	for chave in r.cfg.curvas:
		ok(igual(r.multiplicador(chave, 1), 1.0), "%s sem bonus inicial" % chave)
		ok(igual(r.multiplicador(chave, 500), 1.0 + float(r.cfg.curvas[chave].teto)), "%s teto" % chave)
		var anterior := 0.0
		for n in range(1, 61):
			var valor: float = r.multiplicador(chave, n)
			ok(valor >= anterior, "%s monotona" % chave)
			anterior = valor
	h.nivel = 1
	h.m_ima = 2.0
	var inicial: float = h.alcance_ima()
	h.nivel = 500
	ok(igual(h.alcance_ima(), inicial * 1.75), "coleta compoe cartas uma vez")
	ok(igual(c.progresso.cura_por_nivel(), h.vida_max * float(c.cfg.heroi.cura_nivel) * 0.8), "cura 80% anterior")
	ok(igual(r.chance_cura(1), 0.008) and igual(r.chance_cura(0), 0.032), "cura aumenta com falta de vida")
	h.nivel = 1
	var taxa: float = c.diretor.taxa(0)
	h.nivel = 500
	ok(igual(c.diretor.taxa(0), taxa * 1.15) and c.diretor.limite(9999) <= c.diretor.teto(), "densidade cresce com teto tecnico")
	# Sorteio decorre de RNG proprio; pool/cooldown impedem avalanche.
	seed(77)
	var proximo := randi()
	seed(77)
	r.rng.seed = 77
	for i in 500:
		r.abate(h.pos + Vector2(100, 0))
	ok(randi() == proximo, "drops nao gastam RNG global")
	r.limpar()
	ok(r.soltar("cura", h.pos) and r.soltar("cura", h.pos) and not r.soltar("cura", h.pos), "limite duas curas")
	ok(r.soltar("ima", h.pos) and not r.soltar("ima", h.pos), "limite um ima/pool")
	h.vida = h.vida_max * 0.5
	var vida: float = h.vida
	c.pausado = true
	var resta: float = r.itens[0].resta
	r.atualizar(10)
	ok(r.itens[0].resta == resta and h.vida == vida, "pausa congela pickup e cura")
	c.pausado = false
	r.atualizar(0.01)
	ok(igual(h.vida, vida + h.vida_max * 0.16) and r.coletados.cura == 2, "coleta duas curas e contabiliza")
	r.limpar()
	r.soltar("cura", h.pos + Vector2(100, 0))
	r.atualizar(21)
	ok(r.ativos("cura") == 0, "expiracao libera pool")
	# Cura do aliado usa dt e orçamento efetivo, sem gastar quando a vida está cheia.
	r.limpar()
	ok(r.chance_cura(0, "curandeiro") > r.chance_cura(1, "curandeiro"), "chance aliado aumenta com falta HP")
	r.soltar("curandeiro", h.pos)
	var aliado: Dictionary = r.itens[0]
	ok(aliado.no.texture is AtlasTexture and aliado.no.texture.region.size == Vector2(77, 93), "frame guardiao recortado")
	h.vida = h.vida_max
	r.atualizar(1.0)
	ok(aliado.curado == 0.0, "overheal nao gasta budget")
	h.vida = h.vida_max * 0.5
	var antes_aliado: float = h.vida
	for i in 600:
		r.atualizar(1.0 / 60.0)
	ok(absf(h.vida - antes_aliado - h.vida_max * 0.12) < 0.01, "aliado cura limitada e independente FPS")
	r.limpar()
	r.soltar("curandeiro", h.pos)
	h.vida = h.vida_max * 0.5
	for i in 10:
		r.atualizar(1.0)
	ok(absf(h.vida - antes_aliado - h.vida_max * 0.12) < 0.01, "mesma cura em passos de 1s")
	r.limpar()
	ok(r.soltar("cura", h.pos) and r.soltar("cura", h.pos) and r.soltar("ima", h.pos) and r.soltar("curandeiro", h.pos), "quatro slots cabem simultaneamente")
	ok(not r.soltar("curandeiro", h.pos), "maximo um aliado")
	r.limpar()
	r.soltar("curandeiro", h.pos + Vector2(200, 0))
	var hp_fora: float = h.vida
	var xp_fora: float = h.xp
	var dano_fora: float = c.dano_causado
	c.pausado = true
	r.atualizar(30)
	ok(r.ativos("curandeiro") == 1, "pausa congela expiracao aliado")
	c.pausado = false
	r.atualizar(20)
	ok(h.vida == hp_fora and h.xp == xp_fora and c.dano_causado == dano_fora and r.ativos("curandeiro") == 0, "fora raio expira sem cura/dano/XP")
	# Mortes pendentes fora do combate não reabrem pickups após encerrar.
	var chance_anterior: float = r.cfg.cura.chance
	r.cfg.cura.chance = 1.0
	r.limpar()
	c.pausado = true
	r.abate(h.pos)
	ok(r.ativos("cura") == 0, "abate pausado nao solta pickup")
	c.pausado = false
	for jogo in ["escolha", "morrendo", "vencendo"]:
		r.limpar()
		c.jogo = jogo
		r.abate(h.pos)
		ok(r.ativos("cura") == 0, "abate fora combate nao solta: " + jogo)
	c.jogo = "jogando"
	r.limpar()
	_alvo(h.pos + Vector2(80, 0))
	c.vitoria()
	ok(r.ativos("cura") == 0 and r.ativos("ima") == 0 and r.ativos("curandeiro") == 0, "vitoria mata horda sem repor pickups")
	r.cfg.cura.chance = chance_anterior
	c.limpar_partida()
	# Repetir o RNG privado produz os mesmos drops e intervalos, sem afetar global.
	var seed_original = w.args.get("semente", null)
	w.args["semente"] = 123
	r.limpar()
	ok(r.rng.seed == 494, "seed propria derivada do argumento")
	var sequencias: Array = []
	for rodada in 2:
		r.limpar()
		var seq: Array = []
		for i in 1000:
			r.abate(h.pos + Vector2(200, 0))
			seq.append([r.ativos("cura"), r.ativos("ima"), r.ativos("curandeiro")])
			r.atualizar(0.2)
		sequencias.append(seq)
	ok(sequencias[0] == sequencias[1], "mesma seed mesmos drops")
	if seed_original == null:
		w.args.erase("semente")
	else:
		w.args["semente"] = seed_original
	# Fonte visível considera KEEP_ASPECT_COVERED do TextureRect (sem consultar janela OS).
	await get_tree().process_frame
	var tam_anterior: Vector2 = w.ap.tela.size
	var transform_anterior: Transform2D = w.sv.canvas_transform
	for exibida in [Vector2(960, 540), Vector2(800, 600), Vector2(1600, 600)]:
		w.ap.tela.size = exibida
		w.sv.canvas_transform = Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2(-120, -80))
		var tela: Rect2 = r.tela()
		var k: float = maxf(exibida.x / 960.0, exibida.y / 540.0)
		ok(tela.size.is_equal_approx(exibida / k / 2.0), "crop tamanho %s" % exibida)
		c.orbes.limpar()
		c.orbes.soltar(tela.position + Vector2(1, 1), 3)
		c.orbes.soltar(tela.position - Vector2(1, 1), 7)
		var xp: float = h.xp
		c.orbes.atrair_em_rect(tela)
		ok(c.orbes.estado[0] == 2 and c.orbes.estado[1] == 1, "ima apenas dentro crop %s" % exibida)
		ok(h.xp == xp and c.orbes.valor[0] + c.orbes.valor[1] == 10, "ima conserva XP")
	w.ap.tela.size = tam_anterior
	w.sv.canvas_transform = transform_anterior
	_provar_q_real()
	_provar_alcance_composto()
	_provar_broadphase_extra()
	# Cada familia de Q: dado original intacto, dano snapshot e area uma vez, inclusive rodada final.
	var e = c.especial
	var original: Dictionary = e.blocos.duplicate(true)
	var carga: Dictionary = e.comum.carga.duplicate(true)
	for id in ["hazaki", "nicao", "lucas"]:
		h.chave = id
		h.m_area = 1.0
		h.m_dano = 1.5
		h.nivel = 20
		ok(e.iniciar(h), "%s inicia Q" % id)
		var escala: float = e._escala
		ok(igual(escala, 1.2375), "%s raio nivel20" % id)
		var bloco: Dictionary = original[e.id_de(id)]
		conferir_danos(bloco, e._c, 1.665, id)
		h.nivel = 500
		ok(e._escala == escala, "%s area capturada ao inicio" % id)
		conferir_danos(bloco, e._c, 1.665, id + " snapshot apos nivel")
		if id == "lucas":
			for fase in ["adaga", "final"]:
				c.adagas.limpar()
				e._rodada(h, 1, e._c[fase])
				ok(igual(c.adagas.a_dano[0], float(bloco[fase].dano) * 1.665 * 1.5), "adaga %s dano uma vez" % fase)
				ok(igual(c.adagas.a_rest[0], float(bloco[fase].alcance) * escala), "adaga %s alcance uma vez" % fase)
		e.cancelar(h)
		ok(e._id == "" and not h.esp_invul, "%s termina estado Q" % id)
		h.nivel = 20
		e.iniciar(h)
		conferir_danos(bloco, e._c, 1.665, id + " repetido")
		e.fim_de_partida()
	ok(e.blocos == original and e.comum.carga == carga, "catalogo e carga preservados")
	r.soltar("ima", h.pos)
	h.chave = c.heroi_id
	w.reiniciar()
	ok(r.ativos("ima") == 0 and r.coletados.ima == 0, "restart limpa pickups/contadores")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fotos="):
			var pasta := arg.trim_prefix("--fotos=")
			DirAccess.make_dir_recursive_absolute(pasta)
			h.chave = c.heroi_id
			w.reiniciar()
			c.limpar_partida()
			h.nivel = 1
			h.vida = h.vida_max * 0.5
			r.soltar("cura", h.pos + Vector2(-75, 20))
			r.soltar("ima", h.pos + Vector2(75, 20))
			r.soltar("curandeiro", h.pos + Vector2(20, 100))
			w.cam.cravar(h.pos)
			await w.ap.foto(pasta.path_join("pickups_mundo.png"))
	w.queue_free()
	await get_tree().process_frame
	_finalizar()
	print("v2_ritmo falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func conferir_danos(a: Dictionary, b: Dictionary, k: float, id: String) -> void:
	for chave in a:
		if chave == "dano":
			ok(igual(float(b[chave]), float(a[chave]) * k), "%s dano %s uma vez" % [id, chave])
		elif a[chave] is Dictionary:
			conferir_danos(a[chave], b[chave], k, id + "/" + chave)


## Atravessa a função real de dano/faixa, pulso, onda e projétil, com alvo de vida alta.
func _alvo(pos: Vector2):
	var m = w.nascer_monstro("inimigo_cao_ossos", pos)
	m.vida = 10000.0
	m.vida_max = 10000.0
	m.peso = 1000000.0
	m.raio = 0.0
	return m


func _provar_q_real() -> void:
	var c = w.combate
	var h = w.heroi
	var e = c.especial
	c.cfg.golpe.variacao = 0.0
	h.m_critico = -1.0
	for nivel in [1, 20, 500]:
		for id in ["hazaki", "nicao", "lucas"]:
			c.limpar_partida()
			h.nivel = nivel
			h.chave = id
			h.m_area = 1.0
			h.m_dano = 1.5
			h.mira_mundo = h.centro() + Vector2(100, 0)
			e.iniciar(h)
			var k: float = c.ritmo.multiplicador("q_dano", nivel)
			var area: float = e._escala
			var b: Dictionary = e.blocos[e.id_de(id)]
			if id == "hazaki":
				var m = _alvo(h.pos + Vector2(80, float(b.largura) * area - 1.0))
				e._faixa(h, 160.0)
				ok(igual(10000.0 - m.vida, roundf(float(b.dano) * k * 1.5)), "faixa dano/width real n%d" % nivel)
				var f: Dictionary = e._c.final
				var alvo = _alvo(h.pos + Vector2(float(b.final.raio) * area - 1.0, 6))
				e._pulso(h, h.pos, float(f.raio) * area, float(f.dano), 0, 0, Color.WHITE, false, 0)
				ok(igual(10000.0 - alvo.vida, roundf(float(b.final.dano) * k * 1.5)), "final Hazaki real n%d" % nivel)
			elif id == "nicao":
				var m = _alvo(h.pos + Vector2(float(b.batida.raio) * area - 1.0, 6))
				e._t = float(e._c.golpe)
				e._q_terremoto(h)
				ok(igual(10000.0 - m.vida, roundf(float(b.batida.dano) * k * 1.5)), "batida real n%d" % nivel)
				var longe = _alvo(h.pos + Vector2(float(b.onda.raio) * area - 1.0, 6))
				for i in 40:
					e.atualizar(1.0 / 60.0)
				ok(igual(10000.0 - longe.vida, roundf(float(b.onda.dano) * k * 1.5)), "onda raio/dano real n%d" % nivel)
			else:
				for fase in ["adaga", "final"]:
					c.adagas.limpar()
					var m = _alvo(h.pos + h.ORIGEM_GOLPE + Vector2(float(b[fase].alcance) * area - 12.0, 6))
					e._giro = 0.0
					e._rodada(h, 1, e._c[fase])
					c.adagas.a_dir[0] = Vector2.RIGHT
					for i in 100:
						c.adagas.atualizar(1.0 / 60.0)
					ok(igual(10000.0 - m.vida, roundf(float(b[fase].dano) * k * 1.5)), "Lucas %s acerto real n%d" % [fase, nivel])
					m.morrendo = true
			e.cancelar(h)


## Regressão: a rodada final real do Q cresce além do antigo corte de 560 px.
func _provar_alcance_composto() -> void:
	var c = w.combate
	var h = w.heroi
	var e = c.especial
	for afastar in [false, true]:
		c.limpar_partida()
		h.chave = "lucas"
		h.nivel = 20
		h.m_area = 1.72
		h.m_dano = 1.0
		h.m_critico = -1.0
		e.armar(h)
		h.esp_carga = h.esp_carga_max
		ok(h.especial(), "Q real com area das seis cartas")
		var origem: Vector2 = h.pos + h.ORIGEM_GOLPE
		e._t = float(e._c.dur)
		e._q_chuva(h, 1.0 / 60.0, Vector2.ZERO)
		var dir: Vector2 = c.adagas.a_dir[0]
		var dentro = _alvo(origem + dir * 575.0 + Vector2(0, 6))
		var fora = _alvo(origem + dir * 620.0 + Vector2(0, 6))
		ok(c.adagas.ativas() == int(e._c.final.n), "rodada final usa pool real")
		ok(igual(c.adagas.a_rest[0], 584.793), "alcance final composto 584,793")
		var pos: Vector2 = h.pos
		if afastar:
			h.pos -= dir * 900.0
		for i in 160:
			c.adagas.atualizar(1.0 / 60.0)
		ok(dentro.vida < 10000.0, "Q atinge 575px com heroi afastado=%s" % afastar)
		ok(fora.vida == 10000.0, "Q nao atinge fora do alcance composto")
		ok(c.adagas.a_rest.size() == c.adagas.MAX and c.adagas.a_dir.size() == c.adagas.MAX, "pool nao cresce")
		h.pos = pos
		e.cancelar(h)


## Corpo grande intersecta a caixa mesmo com o peito fora. A Chuva nasce nesse peito
## e pode alcançar uma roda fora da caixa original ainda na mesma atualização.
func _provar_broadphase_extra() -> void:
	var c = w.combate
	var h = w.heroi
	c.limpar_partida()
	c.cfg.golpe.variacao = 0.0
	h.m_critico = -1.0
	c.armas.mods.chuva = 0.0
	var a = c.adagas
	var base_sem_chuva: Vector2 = h.pos + Vector2(200, 0)
	var corpo_sem_chuva = _alvo(base_sem_chuva + Vector2(70, 6))
	corpo_sem_chuva.raio = 60.0
	a._nova(base_sem_chuva, Vector2.RIGHT, 7200.0, 20.0, 10.0, 0.0, 0.0, Color.WHITE, 0, false, 4.0)
	a._selecionar_candidatos(1.0 / 60.0)
	ok(a._cand.has(corpo_sem_chuva), "sem Chuva: corpo entra com peito fora da caixa")
	a.atualizar(1.0 / 60.0)
	ok(corpo_sem_chuva.vida == 9990.0, "sem Chuva: narrowphase acerta corpo grande")
	c.limpar_partida()
	c.armas.mods.chuva = 100.0
	var base: Vector2 = h.pos + Vector2(200, 0)
	var grande = _alvo(base + Vector2(70, 6))
	grande.raio = 60.0
	var origem_extra: Vector2 = grande.pos + Vector2(0, -8)
	var roda: Array = []
	for i in 32:
		var pos: Vector2 = origem_extra + Vector2.from_angle(TAU * float(i) / 32.0) * 60.0
		var m = _alvo(pos + Vector2(0, 6))
		m.raio = 8.0
		roda.append(m)
	a._nova(base, Vector2.RIGHT, 7200.0, 20.0, 10.0, 0.0, 0.0, Color.WHITE, 0, false, 4.0)
	seed(371)
	var esperado := randi()
	seed(371)
	a._selecionar_candidatos(1.0 / 60.0)
	ok(randi() == esperado, "broadphase nao gasta RNG global")
	ok(a._cand.has(grande), "corpo intersecta mesmo com peito fora da caixa")
	for m in roda:
		ok(a._cand.has(m), "bound cobre destino possivel da extra mesmo quadro")
	a.atualizar(1.0 / 60.0)
	ok(grande.vida == 9990.0, "narrowphase acerta corpo grande")
	var feridos := 0
	for m in roda:
		if m.vida < 10000.0:
			feridos += 1
	ok(a.lancadas == 2 and a.acertos == 2 and feridos == 1, "extra nasce e acerta fora AABB original no mesmo quadro")
	ok(a.a_rest.size() == a.MAX and a.a_extra.size() == a.MAX, "pool permanece fixo com extra")
