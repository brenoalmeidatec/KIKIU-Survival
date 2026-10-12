extends RefCounted
## Roteiros de teste manual da v2 (medição e fotos), ligados por opções após `--`:
##   --imortal             ninguém tira vida do herói
##   --robo                o herói golpeia sozinho o monstro mais perto e escolhe a 1ª carta quando sobe de nível
##   --estresse=N          mantém N monstros vivos DENTRO da tela, caçando o herói (medir o desempenho com a horda)
##   --roteiro=combate     sequência de fotos do viewport: o corte acertando com número de dano, a estocada, a tela de nível e a de resultado.
##                         Usar com --fotos=PASTA --nome=prefixo (as fotos saem como prefixo_01_corte.png ...). Nunca captura a área de trabalho.
##   --roteiro=correr      foto do herói correndo com a poeira e a câmera adiantada
##   --build               começa a partida com uma build cheia (aura, lâminas, corvos, raio e runa) para medir o desempenho
##   --roteiro=build|elite|chefe|vitoria|escolha   (leva 3) fotos da build cheia, da elite com baú e roleta, do mini-chefe e do chefe anunciando
##                         o ataque, da tela de vitória e da escolha com raridades (na trava, 20_escolha_trava, e depois de liberar,
##                         21_escolha_liberada). Fotos 11_build ... 21_escolha_liberada, sempre só do viewport.
##   --roteiro=vitrine|ordem|cerco   (leva 4, desempenho) vitrine: os 5 tipos parados em 3 fileiras, para comparar antes e depois do mesmo quadro;
##                         ordem: aranhas grandes (escala 2) atrás e na frente do herói (ordem de desenho); cerco: a horda com 2 aranhas grandes
##                         depois de 3 s de perseguição, com o herói parado (os monstros cercam e não entram no corpo dele).
##   --roteiro=oclusao     (leva 4) herói atrás de uma árvore (1_arvore) e herói coberto por uma aranha grande na frente (2_aranha).
## Nada disto roda no jogo normal.

var mundo
var args := {}
var estresse := 0
var robo := false
var roteiro := ""
var passo := 0
var t_passo := 0.0
var ocupado := false
var pasta := ""
var prefixo := "v2"


func montar(m, a: Dictionary) -> void:
	mundo = m
	args = a
	estresse = int(a.get("estresse", 0))
	robo = a.has("robo")
	roteiro = str(a.get("roteiro", ""))
	pasta = str(a.get("fotos", ""))
	prefixo = str(a.get("nome", "v2"))
	if a.has("imortal") or roteiro != "":
		mundo.heroi.imortal = true
	if estresse > 0 or roteiro != "":
		mundo.combate.diretor.ligado = false
	if a.has("build"):
		armar_build()
	if estresse > 0:
		reabastecer()


func ativo() -> bool:
	return estresse > 0 or robo or roteiro != ""


func atualizar(dt: float) -> void:
	if mundo.combate == null:
		return
	if robo or estresse > 0:
		_robo()
	if estresse > 0:
		reabastecer()
	if roteiro != "" and not ocupado:
		t_passo += dt
		match roteiro:
			"combate":
				_combate()
			"correr":
				_correr()
			"build":
				_r_build()
			"elite":
				_r_elite()
			"chefe":
				_r_chefe()
			"vitoria":
				_r_vitoria()
			"escolha":
				_r_escolha()
			"oclusao":
				_r_oclusao()
			"vitrine":
				_r_vitrine()
			"ordem":
				_r_ordem()
			"cerco":
				_r_cerco()


# ------------------------------------------------------------------ robô e estresse


func _robo() -> void:
	var h = mundo.heroi
	if mundo.combate.jogo == "escolha":
		mundo.combate.progresso.escolher(0)
		return
	if not robo:
		return
	var alvo = null
	var melhor := 1e12
	for m in mundo.monstros:
		var d: float = m.pos.distance_squared_to(h.pos)
		if d < melhor:
			melhor = d
			alvo = m
	if alvo != null:
		mundo.mouse_forcado = alvo.pos + Vector2(0, -6)
		h.fonte = h.Fonte.MOUSE
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = alvo != null and melhor < 70.0 * 70.0
	if mundo.combate.jogo == "morte":
		mundo.reiniciar()


## Mantém `estresse` monstros vivos dentro da tela, a 90 a 380 px do herói.
func reabastecer() -> void:
	var h = mundo.heroi
	var falta: int = estresse - mundo.monstros.size()
	for i in mini(falta, 6):
		var a := randf() * TAU
		var r := randf_range(90.0, 380.0)
		var p: Vector2 = h.pos + Vector2(cos(a) * r, sin(a) * r * 0.62)
		p = p.clamp(mundo.limite_andavel.position, mundo.limite_andavel.end)
		var tipos: Array = mundo.TIPOS_MONSTRO
		mundo.nascer_monstro(tipos[randi() % tipos.size()], p, true)


# ------------------------------------------------------------------ fotos


func _foto(nome: String) -> void:
	ocupado = true
	var caminho := pasta.path_join("%s_%s.png" % [prefixo, nome])
	var tam: Vector2i = await mundo.ap.foto(caminho)
	print("FOTO ", caminho, " ", tam, " t=%.2f" % mundo.t)
	ocupado = false


func _combate() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	match passo:
		0:  # prepara: monstros em arco na frente do herói e ataque segurado
			c.limpar_partida()
			h.entrada_forcada = Vector2.ZERO
			h.fonte = h.Fonte.MOUSE
			var tipos := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_cao_ossos", "inimigo_espantalho", "inimigo_lobo_sombrio", "inimigo_cao_ossos"]
			var pos := [Vector2(34, -8), Vector2(40, 14), Vector2(58, -22), Vector2(62, 8), Vector2(52, 34), Vector2(30, -34)]
			for i in tipos.size():
				var m = mundo.nascer_monstro(tipos[i], h.pos + pos[i], true)
				m.vida = m.vida_max * 3.0
				m.vida_max = m.vida
			mundo.mouse_forcado = h.centro() + Vector2(100, -4)
			h.ataque_forcado = true
			passo = 1
			t_passo = 0.0
		1:  # o corte varrendo o arco, um instante antes do acerto
			if h.estado == h.Estado.GOLPE and h.golpe_i == 0 and h.golpe_t >= 0.055 and not h.golpe_acertou:
				_foto("01_corte")
				passo = 2
				t_passo = 0.0
			elif t_passo > 6.0:
				passo = 2
		2:  # o acerto: hit-stop com flash, faíscas e números
			if c.parada_t > 0.0 and c.acertos >= 1:
				_foto("02_impacto")
				passo = 3
				t_passo = 0.0
			elif t_passo > 6.0:
				passo = 3
		3:  # a estocada (3º passo do combo)
			if h.estado == h.Estado.GOLPE and h.golpe_i == 2 and h.golpe_t >= 0.12 and c.acertos > 0:
				_foto("03_estocada")
				passo = 4
				t_passo = 0.0
			elif t_passo > 8.0:
				passo = 4
		4:  # sobe de nível: câmera lenta e a escolha
			h.ataque_forcado = false
			h.xp = h.xp_proximo - 0.1
			c.progresso.ganhar_xp(0.2)
			passo = 5
			t_passo = 0.0
		5:
			if c.jogo == "escolha" and t_passo > 0.35:
				_foto("04_nivel")
				passo = 6
				t_passo = 0.0
			elif t_passo > 4.0:
				passo = 6
		6:  # escolhe a 1ª carta e morre
			if c.jogo == "escolha":
				c.progresso.escolher(0)
			h.imortal = false
			h.vida = 1.0
			mundo.abates = 41
			mundo.maior_combo = 17
			mundo.tempo_partida = 143.0
			h.nivel = 6
			var m = mundo.nascer_monstro("inimigo_lobo_sombrio", h.pos + Vector2(-40, 0), true)
			m.vida = m.vida_max
			passo = 7
			t_passo = 0.0
		7:
			if c.jogo == "morte" and t_passo > 0.9:
				_foto("05_resultado")
				passo = 8
			elif t_passo > 8.0:
				passo = 8
		8:
			mundo.get_tree().quit()


func _correr() -> void:
	var h = mundo.heroi
	match passo:
		0:
			mundo.combate.limpar_partida()
			h.entrada_forcada = Vector2(1, 0.15).normalized()
			h.correr_forcado = true
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 0.9:
				_foto("06_correr")
				passo = 2
		2:
			mundo.get_tree().quit()


# ------------------------------------------------------------------ leva 3: build, elite, baú, chefe, vitória


## Uma build cheia sem evoluir: aura 4, lâminas 2, corvos 3, raio 2 e runa 2, em raridades variadas.
func armar_build() -> void:
	var cs = mundo.combate.cartas
	for par in [["aura_fogo", 4], ["laminas", 2], ["corvos", 3], ["raio", 2], ["runa", 2]]:
		for i in int(par[1]):
			cs.aplicar(cs.montar_carta(cs.definicao(str(par[0])), 1 + (i % 3)))


func _preparar(imortal := true) -> void:
	var c = mundo.combate
	c.limpar_partida()
	c.diretor.ligado = false
	mundo.heroi.imortal = imortal
	mundo.heroi.entrada_forcada = Vector2.ZERO
	mundo.heroi.fonte = mundo.heroi.Fonte.MOUSE
	mundo.heroi.xp_proximo = 1.0e9  # as fotos não podem abrir a escolha de nível por acidente


func _r_build() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			armar_build()
			estresse = 26
			robo = true
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 3.0:
				_foto("11_build")
				passo = 2
				t_passo = 0.0
		2:
			if t_passo > 0.9:
				_foto("12_build_b")
				passo = 3
		3:
			mundo.get_tree().quit()


func _r_elite() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	match passo:
		0:
			_preparar()
			var e = c.elites.nascer("inimigo_cavaleiro_oco", "explosivo", h.pos + Vector2(120, -10))
			e.cacador = false
			e.raio_vaga = 0.0
			for k in 4:
				var m = mundo.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(90 + 22 * k, 24 - 10 * k), true)
				m.vida_max = 3000.0
				m.vida = 3000.0
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 0.9:
				_foto("13_elite")
				passo = 2
				t_passo = 0.0
		2:
			var e = c.elites.vivas[0] if not c.elites.vivas.is_empty() else null
			if e != null:
				c.ferir(e, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
				c.processar_mortes()
			passo = 3
			t_passo = 0.0
		3:
			if t_passo > 1.3:
				_foto("14_bau")
				passo = 4
				t_passo = 0.0
		4:
			for b in c.baus.lista:
				if b.ativo:
					h.definir_pos(b.pos)
			if c.jogo == "bau":
				passo = 5
				t_passo = 0.0
			elif t_passo > 3.0:
				passo = 7
		5:
			if t_passo > 0.7:
				_foto("15_roleta")
				passo = 6
				t_passo = 0.0
		6:
			if c.telas.bau_pronto and t_passo > 0.3:
				_foto("16_bau_revelado")
				passo = 7
			elif t_passo > 12.0:
				passo = 7
		7:
			mundo.get_tree().quit()


func _r_chefe() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	var ch = c.chefes
	match passo:
		0:
			_preparar()
			ch.nascer(ch.cfg.marcas[0], h.pos + Vector2(200, -30))
			passo = 1
			t_passo = 0.0
		1:
			if c.avisos.ativos() > 0 and c.avisos.t[0] > 0.35 and t_passo > 2.0:
				_foto("17_minichefe_aviso")
				passo = 2
				t_passo = 0.0
			elif t_passo > 14.0:
				passo = 2
		2:
			if ch.atual != null:
				c.ferir(ch.atual, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
				c.processar_mortes()
			c.avisos.limpar()
			passo = 3
			t_passo = 0.0
		3:
			if t_passo > 1.0:
				c.jogo = "jogando"
				c.baus.limpar()
				ch.nascer(ch.cfg.marcas[2], h.pos + Vector2(220, -30))
				passo = 4
				t_passo = 0.0
		4:
			if c.avisos.ativos() > 0 and c.avisos.t[0] > 0.35 and t_passo > 2.0:
				_foto("18_chefe_aviso")
				passo = 5
			elif t_passo > 14.0:
				passo = 5
		5:
			mundo.get_tree().quit()


func _r_vitoria() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	match passo:
		0:
			_preparar()
			armar_build()
			mundo.abates = 412
			mundo.maior_combo = 87
			mundo.xp_coletado = 2860.0
			mundo.tempo_partida = 612.0
			h.nivel = 14
			c.chefes.nascer(c.chefes.cfg.marcas[2], h.pos + Vector2(160, -20))
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 1.2:
				c.ferir(c.chefes.atual, 99999999.0, Vector2.RIGHT, 0.0, 0.0, Color.WHITE)
				c.processar_mortes()
				passo = 2
				t_passo = 0.0
		2:
			if c.jogo == "vitoria" and t_passo > 3.2:
				_foto("19_vitoria")
				passo = 3
			elif t_passo > 12.0:
				passo = 3
		3:
			mundo.get_tree().quit()


func _r_escolha() -> void:
	var h = mundo.heroi
	var c = mundo.combate
	match passo:
		0:
			_preparar()
			armar_build()
			h.nivel = 20
			# procura uma escolha com as três cartas de raridades diferentes, para a foto mostrar a escala de cores e os ícones
			var achada := 0
			for semente in 400:
				c.cartas.rng.seed = semente
				var cs: Array = c.cartas.sortear(3, 20)
				var raridades := {}
				for k in cs:
					raridades[int(k.rar)] = true
				if raridades.size() == 3:
					achada = semente
					break
			c.cartas.rng.seed = achada
			c.progresso.cartas = c.cartas.sortear(3, 20)
			c.jogo = "escolha"
			c.pausado = true
			c.telas.mostrar_escolha(c.progresso.cartas, 20)
			passo = 1
			t_passo = 0.0
		1:  # a trava: cartas apagadas e a contagem ("Escolha em 2") na legenda, com a barra no meio
			if t_passo > 1.2:
				_foto("20_escolha_trava")
				passo = 2
				t_passo = 0.0
		2:  # logo depois de liberar (3 s de tempo real): as cartas acendem
			if c.telas.espera_escolha <= 0.0 and t_passo > 0.12:
				_foto("21_escolha_liberada")
				passo = 3
		3:
			mundo.get_tree().quit()


# ------------------------------------------------------------------ leva 4: oclusão (herói atrás de árvore e coberto por monstro)


## 1_arvore: o herói atrás de uma árvore do meio do mapa (a copa e o tronco o escondem). 2_aranha: o herói no ponto de
## nascimento, com uma aranha grande na frente cobrindo o corpo (a silhueta do herói aparece por cima).
## Vitrine (comparar antes e depois do mesmo quadro): os 5 tipos de monstro parados em 3 fileiras (de frente, de três quartos, espelhados, com
## quadros e tintas diferentes), um elite-escala e um com fogo, tudo congelado (atordoado) perto do herói. Foto "1_vitrine".
func _r_vitrine() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			mundo.mouse_forcado = h.centro() + Vector2(100, 0)  # o herói olha sempre para a direita (a foto não depende do mouse)
			var tipos: Array = mundo.TIPOS_MONSTRO
			for fila in 3:
				for i in tipos.size():
					var m = mundo.nascer_monstro(tipos[i], h.pos + Vector2(-110.0 + i * 55.0, 50.0 + fila * 38.0), true)
					m.atordoa_t = 9999.0
					m.quadro((i + fila) % 4, fila % 2, fila == 2, fila == 2)
					if fila == 1 and i == 1:
						m.definir_escala(1.6)
						m.tinta = Color(0.9, 0.7, 1.2)
					if fila == 2 and i == 3:
						m.queimar(1.0, 99.0)
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 1.0:
				_foto("1_vitrine")
				passo = 2
		2:
			mundo.get_tree().quit()


## Ordem de desenho: uma aranha grande (escala 2) logo atrás do herói e outra logo na frente, paradas. A de trás fica por baixo dele e a
## da frente por cima (y-sort pelos pés). Foto "1_ordem".
func _r_ordem() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			mundo.mouse_forcado = h.centro() + Vector2(100, 0)  # o herói olha sempre para a direita (a foto não depende do mouse)
			for dy in [-26.0, 28.0]:
				var m = mundo.nascer_monstro("inimigo_aranha_tecela", h.pos + Vector2(6.0 * signf(dy), dy), false)
				m.definir_escala(2.0)
				m.atordoa_t = 9999.0
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 1.0:
				_foto("1_ordem")
				passo = 2
		2:
			mundo.get_tree().quit()


## Cerco: 34 monstros e 2 aranhas grandes (escala 2 e 3) caçando o herói parado. Depois de 3 s: foto "1_cerco" (eles formam uma roda em volta
## dele, sem entrar no corpo, e nenhum fica por cima).
func _r_cerco() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			mundo.mouse_forcado = h.centro() + Vector2(100, 0)  # o herói olha sempre para a direita (a foto não depende do mouse)
			var tipos: Array = mundo.TIPOS_MONSTRO
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 34:
				var a := rng.randf() * TAU
				var r := rng.randf_range(70.0, 190.0)
				mundo.nascer_monstro(tipos[i % tipos.size()], h.pos + Vector2(cos(a) * r, sin(a) * r * 0.62), true)
			for k in [2.0, 3.0]:
				var m = mundo.nascer_monstro("inimigo_aranha_tecela", h.pos + Vector2(110.0 * (k - 2.5) * 2.0, 60.0), true)
				m.definir_escala(k)
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 3.0:
				_foto("1_cerco")
				passo = 2
		2:
			mundo.get_tree().quit()


func _r_oclusao() -> void:
	var h = mundo.heroi
	match passo:
		0:
			_preparar()
			var arvore = null
			for o in mundo.cenario.objetos:
				if o.chave == "arvore" and o.pos.x > 900.0 and o.pos.x < 2000.0 and o.pos.y > 500.0 and o.pos.y < 1100.0:
					arvore = o
					break
			if arvore != null:
				h.definir_pos(arvore.pos + Vector2(0, -40))
			passo = 1
			t_passo = 0.0
		1:
			if t_passo > 0.9:
				_foto("1_arvore")
				passo = 2
				t_passo = 0.0
		2:
			var c: Array = mundo.dados.get("nascimento", {}).get("heroi", [1440, 820])
			h.definir_pos(Vector2(float(c[0]), float(c[1])))
			var m = mundo.nascer_monstro("inimigo_aranha_tecela", h.pos + Vector2(0, 12), false)
			m.definir_escala(2.0)
			passo = 3
			t_passo = 0.0
		3:
			if t_passo > 0.9:
				_foto("2_aranha")
				passo = 4
		4:
			mundo.get_tree().quit()
