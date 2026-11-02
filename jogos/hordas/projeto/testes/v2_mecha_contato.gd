extends "res://testes/isolamento_v2.gd"
## Contato dos projéteis do mecha: a boca visual converge antes do impacto sem alterar a simulação.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const DT := 1.0 / 120.0

var falhas := 0
var w


func ok(cond: bool, mensagem: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", mensagem)


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.imortal = true
	var ad = w.combate.adagas
	var m = w.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(100, 0))
	m.vida_max = 10000.0
	m.vida = 10000.0
	m.atordoa_t = 60.0
	var info_original: Dictionary = h.tipo.info
	h.tipo.info = info_original.duplicate(true)
	var tabela := {"canhoes": [], "pods": []}
	for linha in 8:
		tabela.canhoes.append([[-20.0 - linha, -40.0 - linha], [20.0 + linha, -40.0 - linha]])
		tabela.pods.append([[-16.0 - linha, -65.0 - linha], [16.0 + linha, -65.0 - linha]])
	for proj in ["bala", "missil"]:
		for ang in 8:
			var dir := Vector2.from_angle(float(ang) * PI / 4.0)
			for lado in 2:
				for distancia in [25.0, 45.0, 75.0, 120.0]:
					var etiqueta := "%s direção %d lado %d distância %.0f" % [proj, ang, lado, distancia]
					var origem: Vector2 = h.pos + h.ORIGEM_GOLPE
					if proj == "missil":
						origem += Vector2(-dir.y, dir.x) * (-9.0 if lado == 0 else 9.0)
					var passo: Dictionary = w.combate.cfg.golpe.passos[lado].duplicate(true)
					passo.proj = proj
					passo.cone_dir = dir
					passo.giro = 0.0
					var numero := 875123 + ang * 1000 + lado * 100 + int(distancia)
					seed(numero)
					var caminho := dir.rotated(randf_range(-0.025, 0.025))
					var inicio := origem + caminho * 10.0
					m.pos = inicio + caminho * distancia + Vector2(0, 6)
					var resultado := []
					for com_boca in [false, true]:
						ad.limpar()
						w.combate.fx.limpar()
						h.esp_carga = 0.0  # não cruzar o limiar do Q só em uma das duas repetições
						m.vida = m.vida_max
						m.atordoa_t = 60.0
						m.emp = Vector2.ZERO
						h.tipo.info["bocas_projeteis"] = tabela if com_boca else {}
						seed(numero)
						ad.lancar(h, origem, dir, passo)
						var nascimento: Vector2 = ad.a_pos[0]
						var desvio: float = (ad._pos_visual(0) - nascimento).length()
						var entrada := maxf(0.001, distancia - float(m.raio) - float(ad.a_raio[0]))
						var amostras := []
						var excedeu := false
						var passos_ativos := 0
						if com_boca:
							ok(desvio > 1.0, "%s nasce na boca, deslocada da física" % etiqueta)
						for _quadro in 120:
							ad.atualizar(DT)
							var percorreu: float = nascimento.distance_to(ad.a_pos[0])
							if ad.a_rest[0] > 0.0:
								passos_ativos += 1
								var k := clampf(1.0 - percorreu / entrada, 0.0, 1.0)
								k = k * k * (3.0 - 2.0 * k)
								var residual: float = (ad._pos_visual(0) - ad.a_pos[0]).length()
								if com_boca and residual > desvio * k + 0.15:
									excedeu = true
							amostras.append([ad.a_pos[0], ad.a_dir[0], ad.a_rest[0], m.vida, ad.acertos])
							if ad.a_rest[0] <= 0.0:
								break
						if com_boca:
							ok(passos_ativos > 0 and not excedeu, "%s converge desde o primeiro passo até o contato" % etiqueta)
							ok((ad._pos_visual(0) - ad.a_pos[0]).length() < 0.01, "%s impacto sem desvio visual" % etiqueta)
						ok(ad.acertos == 1 and m.vida < 10000.0, "%s acerta uma vez" % etiqueta)
						var trilha := [amostras, randi(), randi(), randi()]
						if not com_boca:
							resultado = trilha
						else:
							if trilha != resultado:
								print(
									"DETALHE física/RNG ",
									etiqueta,
									" passos=",
									amostras.size(),
									"/",
									resultado[0].size(),
									" RNG=",
									trilha.slice(1),
									"/",
									resultado.slice(1)
								)
								for q in mini(amostras.size(), resultado[0].size()):
									if amostras[q] != resultado[0][q]:
										print("DETALHE primeiro passo divergente ", q, " ", amostras[q], " / ", resultado[0][q])
										break
							ok(trilha == resultado, "%s conserva trajetória, dano e RNG" % etiqueta)
	_extras(m, h, ad, tabela)
	# A vaga reutilizada ou limpa não pode herdar o limite visual de um tiro anterior.
	var compr = ad.get("a_visual_compr")
	if compr != null:
		compr[0] = 1.0
		ad.set("a_visual_compr", compr)
		ad.limpar()
		compr = ad.get("a_visual_compr")
		ok(float(compr[0]) >= 59.9, "limpar restaura a distância visual padrão")
		compr[0] = 1.0
		ad.set("a_visual_compr", compr)
		ad._nova(h.pos, Vector2.RIGHT, 270.0, 320.0, 1.0, 0.0, 0.0, Color.WHITE, 0, false, 4.0)
		compr = ad.get("a_visual_compr")
		ok(float(compr[0]) >= 59.9, "vaga reutilizada restaura a distância visual padrão")
	h.tipo.info = info_original
	Herois.forcado = ""
	w.queue_free()
	await get_tree().process_frame
	print("v2_mecha_contato falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)


## Casos de alvo dinâmico e acertos múltiplos, comparados à mesma simulação sem boca visual.
func _extras(m, h, ad, tabela: Dictionary) -> void:
	var m2 = w.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(500, 500))
	m2.vida_max = 10000.0
	var dir := Vector2.RIGHT
	var origem: Vector2 = h.pos + h.ORIGEM_GOLPE
	var passo: Dictionary = w.combate.cfg.golpe.passos[0].duplicate(true)
	passo.cone_dir = dir
	passo.giro = 0.0
	seed(49301)
	var caminho := dir.rotated(randf_range(-0.025, 0.025))
	var perpendicular := Vector2(-caminho.y, caminho.x)
	var nascimento := origem + caminho * 10.0
	for modo in ["entrar", "nascer", "morrer", "furar", "ricochete"]:
		var referencia := []
		for com_boca in [false, true]:
			ad.limpar()
			w.combate.fx.limpar()
			h.esp_carga = 0.0
			h.tipo.info["bocas_projeteis"] = tabela if com_boca else {}
			m.vivo = true
			m.morrendo = false
			m.vida = m.vida_max
			m.emp = Vector2.ZERO
			m2.vivo = true
			m2.morrendo = false
			m2.vida = m2.vida_max
			m2.emp = Vector2.ZERO
			w.monstros.erase(m)
			w.monstros.erase(m2)
			if modo != "nascer":
				w.monstros.append(m)
			if modo == "furar" or modo == "ricochete":
				w.monstros.append(m2)
			m.pos = nascimento + caminho * (120.0 if modo == "entrar" else 30.0) + Vector2(0, 6)
			m2.pos = nascimento + caminho * (45.0 if modo == "ricochete" else 70.0) + Vector2(0, 6)
			if modo == "ricochete":
				m2.pos += perpendicular * 25.0
			passo.perfura = 2 if modo == "furar" else 0
			passo.ricochete = 1 if modo == "ricochete" else 0
			seed(49301)
			ad.lancar(h, origem, dir, passo, modo == "ricochete")
			var offset_inicial: float = (ad._pos_visual(0) - ad.a_pos[0]).length()
			var anterior := offset_inicial
			var prazo := INF
			var voltou := false
			var excedeu := false
			var amostras := []
			for quadro in 140:
				if quadro == 2:
					if modo == "entrar" or modo == "nascer":
						if modo == "nascer":
							w.monstros.append(m)
						m.pos = ad.a_pos[0] + ad.a_dir[0] * 25.0 + Vector2(0, 6)
						prazo = nascimento.distance_to(ad.a_pos[0]) + 25.0 - float(m.raio) - float(ad.a_raio[0])
					elif modo == "morrer":
						m.vivo = false
				ad.atualizar(DT)
				var residual: float = (ad._pos_visual(0) - ad.a_pos[0]).length()
				if residual > anterior + 0.02:
					voltou = true
				anterior = residual
				if prazo < INF and ad.a_rest[0] > 0.0:
					var k := clampf(1.0 - nascimento.distance_to(ad.a_pos[0]) / prazo, 0.0, 1.0)
					k = k * k * (3.0 - 2.0 * k)
					if residual > offset_inicial * k + 0.15:
						excedeu = true
				if com_boca and ad.acertos > 0 and residual > 0.01:
					voltou = true
				amostras.append([ad.a_pos[0], ad.a_dir[0], ad.a_rest[0], m.vida, m2.vida, ad.acertos])
				if ad.a_rest[0] <= 0.0:
					break
			var esperado := 0 if modo == "morrer" else (2 if modo == "furar" or modo == "ricochete" else 1)
			ok(ad.acertos == esperado, "%s acerta %d alvos" % [modo, esperado])
			if com_boca:
				ok(not voltou, "%s nunca recupera o desvio após reduzir ou acertar" % modo)
				if modo == "entrar" or modo == "nascer":
					ok(not excedeu, "%s converge desde que o alvo aparece" % modo)
			var trilha := [amostras, randi(), randi(), randi()]
			if com_boca:
				ok(trilha == referencia, "%s preserva trajetória, dano e RNG" % modo)
			else:
				referencia = trilha
	w.monstros.erase(m2)
	if not w.monstros.has(m):
		w.monstros.append(m)
	m.vivo = true
