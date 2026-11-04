extends "res://testes/isolamento_v2.gd"
## Visual próprio dos mísseis sem mudar quantidade, movimento nem dano; pools estáveis mesmo depois de acabar o voo.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
# Godot 4.4.1, seed 781923; mesma fixture com efeitos.gd E adagas.gd originais extraídos por git show
# do commit ad0f315f16fc6af273c30834954073feda0af096, executados em cópias externas ao repo.
# [direção, vida do alvo, críticos, próximos três randi], por fator de partículas.
# Direção/dano têm tolerância entre plataformas; as amostras PCG uint32 são exatas.
const RNG_BASELINE := {
	0.25: [Vector2(0.999774, 0.021257), 990.0, 1, 1720902221, 2413150676, 1815383821],
	0.6: [Vector2(0.999977, -0.006773), 990.0, 1, 3371356732, 3628179373, 1186623667],
	1.0: [Vector2(0.999817, 0.019107), 990.0, 1, 1907011038, 3160003473, 987873203],
}
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.combate.cfg.golpe.variacao = 0.0
	w.heroi.imortal = true
	w.heroi.m_critico = -1.0
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(300, 0)
	passos(3)


func monstro(p: Vector2):
	var m = w.nascer_monstro("inimigo_cao_ossos", p)
	m.vida_max = 1000.0
	m.vida = 1000.0
	m.atordoa_t = 60.0
	m.emp = Vector2.ZERO
	return m


func comparar_rng() -> void:
	var referencia: Array = []
	for desenhar in [true, false]:
		zerar()
		var c = w.combate
		var ad = c.adagas
		var h = w.heroi
		h.m_critico = 0.4
		var m = monstro(h.pos + Vector2(100, 0))
		seed(781923)
		c.fx.faiscas(h.pos, Vector2.RIGHT, 6, Color.WHITE, 110.0, desenhar)
		c.fx.estouro(h.pos, Color.WHITE, 3, desenhar)
		ad.lancar(h, h.pos, Vector2.RIGHT, c.cfg.golpe.passos[0])
		ad._acertar(0, m, m.pos)
		var obtido: Array = [ad.a_dir[0], m.vida, c.criticos, randi(), randi(), randi()]
		var esperado: Array = RNG_BASELINE[c.fx.fator_part]
		ok(
			(obtido[0] as Vector2).distance_to(esperado[0]) <= 0.00001 and absf(float(obtido[1]) - float(esperado[1])) <= 0.00001 and obtido[2] == esperado[2],
			"dispersão/crítico/dano equivalem ao baseline ad0f315, fator %s" % c.fx.fator_part
		)
		ok(obtido.slice(3) == esperado.slice(3), "próximos três randi equivalem exatamente ao baseline ad0f315")
		if desenhar:
			referencia = obtido
		else:
			ok(obtido == referencia, "omitir faíscas/estouro mantém dispersão, crítico, dano e próximos sorteios com a mesma seed")


func bocas_visuais() -> void:
	zerar()
	var h = w.heroi
	var ad = w.combate.adagas
	var info_original: Dictionary = h.tipo.info
	h.tipo.info = info_original.duplicate(true)
	var tabela := {"canhoes": [], "pods": []}
	for linha in 8:
		tabela.canhoes.append([[-20.0 - linha, -40.0 - linha], [20.0 + linha, -40.0 - linha]])
		tabela.pods.append([[-16.0 - linha, -65.0 - linha], [16.0 + linha, -65.0 - linha]])
	for proj in ["bala", "missil"]:
		for ang in 8:
			var dir := Vector2.from_angle(float(ang) * PI / 4.0)
			var linha: int = h.linha_de(dir)
			for lado in 2:
				var passo: Dictionary = w.combate.cfg.golpe.passos[lado].duplicate(true)
				passo.proj = proj
				passo.cone_dir = dir
				var origem: Vector2 = h.pos + h.ORIGEM_GOLPE
				if proj == "missil":
					origem += Vector2(-dir.y, dir.x) * (-9.0 if lado == 0 else 9.0)
				var referencia: Array = []
				for com_tabela in [false, true]:
					ad.limpar()
					h.tipo.info["bocas_projeteis"] = tabela if com_tabela else {}
					seed(91723)
					if proj == "bala":
						w.combate.golpear(h, origem, dir, passo, lado)
					else:
						ad.lancar(h, origem, dir, passo)
					var logico: Array = [ad.a_pos[0], ad.a_dir[0], ad.a_vel[0], ad.a_rest[0], ad.a_raio[0], ad.a_dano[0], randi()]
					if not com_tabela:
						referencia = logico
					else:
						ok(logico == referencia, "boca visual não altera física nem RNG: %s direção %d lado %d" % [proj, linha, lado])
						var xy: Array = tabela["pods" if proj == "missil" else "canhoes"][linha][lado]
						ok(ad._pos_visual(0).distance_to(h.pos + Vector2(xy[0], xy[1])) < 0.001, "o centro do projétil nasce na boca projetada")
	var offset: Vector2 = ad.a_visual_offset[0]
	var alvo = monstro(h.pos + Vector2(0, 180))
	ad.a_alvo[0] = alvo
	ad.a_giro[0] = 3.2
	ad._guiar(0.1)
	ok(ad.a_visual_offset[0] == offset, "guiar o míssil não rotaciona o offset projetado")
	ad.a_visual_dist[0] = 60.0
	ok(ad._pos_visual(0) == ad.a_pos[0], "offset converge para a trajetória lógica após 60 px")
	ad.a_visual_dist[0] = 0.0
	ad.a_visual_t[0] = 0.0
	ok(ad._pos_visual(0) == ad.a_pos[0], "offset também converge pelo tempo curto")
	ad.a_rest[0] = 0.0
	ad.a_visual_t[0] = 0.1
	ad.a_visual_dist[0] = 22.0
	var reutilizada: int = ad._nova(h.pos, Vector2.RIGHT, 270.0, 320.0, 1.0, 0.0, 0.0, Color.WHITE, 0, false, 4.0)
	ok(
		reutilizada == 0 and ad.a_visual_offset[0] == Vector2.ZERO and ad.a_visual_t[0] == 0.0 and ad.a_visual_dist[0] == 0.0,
		"vaga reutilizada não herda a boca do projétil anterior"
	)
	ad.limpar()
	ok(ad.a_visual_offset[0] == Vector2.ZERO and ad.a_visual_t[0] == 0.0 and ad.a_visual_dist[0] == 0.0, "limpar zera todos os campos visuais")
	h.tipo.info = info_original


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	var h = w.heroi
	var c = w.combate
	var ad = c.adagas
	var visual = ad.misseis_visual
	var quadros: Array = visual.quadros.duplicate()
	var missil: Dictionary = ad._proj_lista[ad._indice_proj("missil")]
	ok(missil.tex.get_width() == 24 and missil.tex.get_height() == 9, "míssil tem corpo/ogiva/aletas maiores que uma bala")
	ok(visual.quadros.size() == 8 and visual.tempo.size() == 16, "oito quadros e dezesseis vagas preparados uma vez")
	ok(visual.quadros[0].get_image().get_data() != visual.quadros[4].get_image().get_data(), "a explosão tem quadros diferentes")
	for idx in 2:
		var antes: int = ad.lancadas
		var part: int = c.fx.usados.particulas
		var passo: Dictionary = c.cfg.golpe.passos[idx]
		c.golpear(h, h.pos + h.ORIGEM_GOLPE, Vector2.RIGHT, passo, idx)
		ok(ad.lancadas - antes == 1, "cada evento de cada braço lança exatamente uma bala")
		ok(c.fx.usados.particulas == part, "bala não espalha faíscas extras parecendo outros tiros")
		var i: int = ad.lancadas - 1
		ok(
			is_equal_approx(ad.a_vel[i], float(passo.vel)) and is_equal_approx(ad.a_dano[i], float(passo.dano) * h.m_dano),
			"velocidade e dano da bala preservados"
		)
		ok(
			is_equal_approx(ad.a_rest[i], float(passo.alcance) * (1.0 + c.bonus_nivel_golpe(h))) and is_equal_approx(ad.a_raio[i], 4.0 * sqrt(h.m_area)),
			"alcance e raio de colisão não crescem com a imagem"
		)
	zerar()
	var hab: Dictionary = Dados.json("v2_habilidade").misseis
	ok(int(hab.n) == 12 and is_equal_approx(float(hab.dur), 0.9), "a E mantém doze mísseis em 0,9 s")
	h.habilidade()
	passos(55)
	ok(ad.lancadas == 12, "a E real lança exatamente doze mísseis")
	for i in ad.MAX:
		if ad.a_rest[i] > 0.0:
			ok(ad.a_vel[i] == float(hab.vel), "velocidade do míssil preservada")
	zerar()
	var p: Vector2 = h.pos + Vector2(100, 0)
	var direto = monstro(p)
	var area = monstro(p + Vector2(0, 16))
	var fora = monstro(p + Vector2(0, 80))
	var passo_m := {
		"n": 1,
		"dano": 11.0,
		"vel": 270.0,
		"alcance": 320.0,
		"empurrao": 90.0,
		"atordoa": 0.12,
		"cor": [0.5, 0.95, 1.0],
		"proj": "missil",
		"expl_raio": 26.0,
		"expl_dano": 6.0
	}
	ad.lancar(h, h.pos, Vector2.RIGHT, passo_m)
	ad._acertar(0, direto, p)
	ad._acabar(0)
	ok(is_equal_approx(1000.0 - direto.vida, 11.0 * h.m_dano), "explosão não repete dano no alvo direto")
	ok(is_equal_approx(1000.0 - area.vida, 6.0 * h.m_dano) and fora.vida == 1000.0, "dano e raio em área preservados")
	ok(visual.emitidas == 1 and visual.ativas() == 1 and ad.ativas() == 0, "um impacto anima uma explosão mesmo sem projéteis em voo")
	ad.atualizar(0.1)
	ok(visual.ativas() == 1 and ad._desenha, "a explosão continua sendo redesenhada depois do voo")
	var dano_antes: float = c.dano_causado
	var nos: int = get_tree().get_node_count()
	for i in 100:
		visual.emitir(p, 26.0)
		ad.atualizar(0.01)
	ok(visual.ativas() <= 16 and visual.tempo.size() == 16 and visual.quadros == quadros, "cem efeitos reutilizam vagas e texturas")
	ok(get_tree().get_node_count() == nos and c.dano_causado == dano_antes, "efeito visual não cria nós nem causa dano")
	ad.atualizar(0.5)
	ok(visual.ativas() == 0, "a explosão termina sem deixar vaga presa")
	ad.atualizar(0.01)
	ok(not ad._desenha, "o desenho dorme quando não há projéteis nem explosões")
	zerar()
	ok(visual.emitidas == 0 and visual.ativas() == 0, "reiniciar limpa o pool visual")
	# O novo tratamento vale só para bala do mecha e míssil; as outras imagens seguem no caminho anterior.
	ok(not ad._visual_mecha(ad._indice_proj("adaga")) and not ad._visual_mecha(ad._indice_proj("plasma")), "adagas e plasma preservam seus efeitos")
	var fator_antes: float = c.fx.fator_part
	for fator in [0.25, 0.6, 1.0]:
		c.fx.fator_part = fator
		comparar_rng()
	c.fx.fator_part = fator_antes
	bocas_visuais()
	var reduzir: bool = Config.reduzir_piscadas
	Config.reduzir_piscadas = true
	visual.limpar()
	var nos_calmo: int = get_tree().get_node_count()
	for i in 24:
		visual.emitir(h.pos, 26.0)
		for t in [0.36, 0.27, 0.18, 0.09]:
			ok(visual.quadro_em(t, false, visual.Piscadas.ligado()) == 6, "reduzir piscadas mantém fumaça escura fixa em impactos consecutivos")
	ok(visual.ativas() == 1 and get_tree().get_node_count() == nos_calmo, "impactos coincidentes são agrupados sem novos nós no modo calmo")
	visual.limpar()
	visual.emitir(h.pos, 26.0)
	for i in 16:
		visual.emitir(h.pos + Vector2(float(i + 1) * 100.0, 0), 26.0)
	visual.emitir(h.pos, 26.0)
	ok(
		visual.emitidas == 16 and visual.pos[0] == h.pos + Vector2(0, -6),
		"saturação em regiões distintas não sobrescreve a proteção temporal do primeiro impacto"
	)
	visual.limpar()
	var amostras: Array = []
	for quadro in 180:
		if quadro % 4 == 0:
			visual.emitir(h.pos, 26.0)
		var alfa := 0.0
		for t in visual.tempo:
			alfa += t / visual.DUR  # soma da opacidade do conjunto, não apenas o índice de um quadro
		amostras.append(alfa)
		visual.atualizar(PASSO)
	for inicio in range(amostras.size() - 60):
		ok(visual.Piscadas.trocas(amostras.slice(inicio, inicio + 61)) <= 3, "impactos contínuos respeitam três trocas em qualquer janela de um segundo")
	Config.reduzir_piscadas = reduzir
	c.heroi_id = "lucas"
	ok(not ad._visual_mecha(ad._indice_proj("bala")), "a bala de outro herói não herda o tratamento do mecha")
	Herois.forcado = ""
	print("v2_mecha_projeteis falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
