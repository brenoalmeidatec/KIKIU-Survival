extends "res://testes/isolamento_v2.gd"
# Teste automático do v2/clima.gd (clima por mapa, portado do pixelfx): dados dos quatro mapas, quantidade fixa e nenhum nó por partícula,
# perfil (Baixo desliga, Médio usa metade), tetos de alfa, glitch raro que respeita "Tremor e clarões", camada abaixo do brilho e a ponta a ponta
# no mundo de cada mapa. Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_clima.tscn  (imprime "v2_clima falhas=0")
const Clima := preload("res://v2/clima.gd")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _nos_total(raiz: Node) -> int:
	var n := 1
	for c in raiz.get_children():
		n += _nos_total(c)
	return n


func _montar(id: String, pai: Node):
	var c := Clima.new()
	c.montar(pai, id)
	return c


## Espera o quadro do motor: é ele quem emite o `draw` dos dois nós (chamar o desenho à mão é erro do motor).
func _desenhar(_c) -> void:
	await get_tree().process_frame


func _rodar(c, seg: float) -> void:
	for i in int(seg / 0.1):
		c.atualizar(0.1)
		await _desenhar(c)


func _ready() -> void:
	Config.g_temporario("tremor_clarao", 100)
	var tudo: Dictionary = Dados.json("v2_clima")
	var mapas: Dictionary = tudo.mapas
	# 1. dados: os quatro mapas, cada um com o seu tema
	for id in ["floresta", "cidade", "laboratorio", "medio"]:
		ok(mapas.has(id), "o mapa %s tem bloco" % id)
	ok(mapas.floresta.has("vagalumes") and mapas.floresta.has("folhas"), "floresta: vagalumes e folhas")
	ok(mapas.cidade.has("nevoa") and mapas.cidade.has("chuva"), "cidade: névoa e chuva")
	ok(mapas.laboratorio.has("glitch"), "laboratório: glitch")
	ok(mapas.medio.has("nevoa"), "médio: névoa")

	# 2. montagem: 1 CanvasLayer + 2 nós de desenho, na camada 1 (abaixo do brilho, camada 2); nada nasce depois
	var pai := Node.new()
	add_child(pai)
	var c = _montar("cidade", pai)
	ok(c.camada.layer == 1, "camada 1, abaixo do brilho (2)")
	ok(c.camada.get_child_count() == 2, "dois nós de desenho")
	var antes := _nos_total(pai)
	await _rodar(c, 30.0)
	ok(_nos_total(pai) == antes, "30 s de clima não criam nó (%d -> %d)" % [antes, _nos_total(pai)])
	ok(c.quadros_desenhados > 100, "desenhou (%d quadros)" % c.quadros_desenhados)
	ok(c.desenhado.chuva == 110, "chuva: 110 gotas por quadro (%d)" % c.desenhado.chuva)
	ok(c.desenhado.nevoa >= 2, "névoa: bancos desenhados (%d)" % c.desenhado.nevoa)
	var respingos := 0
	for i in 100:
		c.atualizar(0.1)
		await _desenhar(c)
		respingos += c.desenhado.respingos
	ok(respingos > 0, "chuva: há respingo no chão (%d)" % respingos)

	# 3. perfil: Médio metade, Baixo desligado e invisível
	c.definir_fator(0.5)
	ok(c.contagem().chuva == 55 and c.camada.visible, "Médio: 55 gotas")
	await _rodar(c, 1.0)
	ok(c.desenhado.chuva == 55, "Médio desenha 55 (%d)" % c.desenhado.chuva)
	c.definir_fator(0.0)
	var t0: float = c.tempo
	c.atualizar(0.1)
	ok(not c.ativo and not c.camada.visible and c.tempo == t0, "Baixo: invisível e parado")
	ok(c.contagem().chuva == 0 and c.contagem().nevoa == 0, "Baixo: contagem zero")
	c.definir_fator(1.0)
	ok(c.ativo and c.camada.visible, "Alto volta")

	# 4. tetos de alfa em todos os mapas (nada cobre o inimigo)
	for id in mapas:
		var x = _montar(id, pai)
		ok(x._nv_alfa <= Clima.ALFA_TETO.nevoa and x._ch_alfa <= Clima.ALFA_TETO.chuva, "%s: alfa de névoa e chuva dentro do teto" % id)
		ok(x._gl_alfa <= Clima.ALFA_TETO.glitch and x._fl_alfa <= Clima.ALFA_TETO.folhas, "%s: alfa de glitch e folhas dentro do teto" % id)
		ok(x._vg_ef <= Clima.MAX_VAGA and x._fl_ef <= Clima.MAX_FOLHA and x._ch_ef <= Clima.MAX_CHUVA, "%s: dentro dos máximos" % id)
		x.camada.queue_free()

	# 5. floresta: vagalumes acendem e apagam (o número de acesos varia), folhas caem
	var fl = _montar("floresta", pai)
	var vistos := {}
	for i in 600:
		fl.atualizar(0.1)
		await _desenhar(fl)
		vistos[fl.desenhado.vagalumes] = true
	ok(vistos.size() > 2, "o número de vagalumes acesos varia (%d valores)" % vistos.size())
	await _desenhar(fl)
	ok(fl.desenhado.folhas == 8, "8 folhas (%d)" % fl.desenhado.folhas)
	fl.camada.queue_free()

	# 6. glitch raro e que respeita "Tremor e clarões"
	var lab = _montar("laboratorio", pai)
	var em := 0
	for i in 12000:  # 1200 s
		lab.atualizar(0.1)
		if lab.em_rajada:
			em += 1
	ok(lab.rajadas >= 60 and lab.rajadas <= 140, "20 min: rajadas raras e regulares (%d)" % lab.rajadas)
	ok(em < 12000 * 0.06, "o glitch ocupa menos de 6%% do tempo (%d de 12000)" % em)
	lab.disparar_rajada()
	await _desenhar(lab)
	ok(lab.em_rajada and lab.desenhado.glitch > 3, "a rajada desenha faixas e linhas (%d)" % lab.desenhado.glitch)
	Config.g_temporario("tremor_clarao", 0)
	var lab0 = _montar("laboratorio", pai)
	ok(not lab0.disparar_rajada(), "clarão 0%%: disparar recusa")
	for i in 6000:
		lab0.atualizar(0.1)
	ok(lab0.rajadas == 0 and not lab0.em_rajada, "clarão 0%%: 10 min sem nenhuma rajada (%d)" % lab0.rajadas)
	await _desenhar(lab0)
	ok(lab0.desenhado.glitch == 0, "clarão 0%%: nada de glitch desenhado")
	Config.g_temporario("tremor_clarao", 100)
	lab.camada.queue_free()
	lab0.camada.queue_free()
	pai.queue_free()

	# 7. ponta a ponta: o mundo de cada mapa monta o clima, o Baixo o apaga e nenhum nó nasce andando
	for id in ["floresta", "cidade", "laboratorio", "medio"]:
		var w = Mundo.instantiate()
		w.modo_teste = true
		w.id_mapa = id
		add_child(w)
		w.set_process(false)
		w.combate.audio.mudo = true
		w.reiniciar()
		w.combate.limpar_partida()
		w.combate.diretor.ligado = false
		ok(w.clima != null and w.clima.id_mapa == id and w.clima.camada.get_parent() == w.sv, "%s: o mundo monta o clima no sv" % id)
		w.clima.definir_fator(1.0)
		var nos := _nos_total(w)
		for i in 180:
			w.avancar(PASSO)
		ok(w.clima.tempo > 2.5, "%s: o clima anda com o mundo (%.2f s)" % [id, w.clima.tempo])
		ok(_nos_total(w) == nos, "%s: andar não cria nó no mundo (%d -> %d)" % [id, nos, _nos_total(w)])
		w.clima.definir_fator(0.0)
		var tt: float = w.clima.tempo
		w.avancar(0.1)
		ok(w.clima.tempo == tt and not w.clima.camada.visible, "%s: Baixo não anda nem aparece" % id)
		w.queue_free()
		await get_tree().process_frame
	print("v2_clima falhas=", falhas)
	get_tree().quit(1 if falhas else 0)
