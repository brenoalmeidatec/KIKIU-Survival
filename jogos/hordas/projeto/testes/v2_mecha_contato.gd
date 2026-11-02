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
	var tabela_real: Dictionary = info_original.get("bocas_projeteis", {}).duplicate(true)
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
								if entrada >= 60.0:
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
	_monotonicidade(m, h, ad, tabela_real)
	_dt_variavel(m, h, ad, tabela_real)
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
	var oculto = ad.get("a_visual_oculto")
	var seguir = ad.get("a_visual_seguir")
	var ultima = ad.get("a_visual_ultima")
	if oculto != null and seguir != null and ultima != null:
		for metodo in ["limpar", "nova"]:
			ad.limpar()
			oculto = ad.get("a_visual_oculto")
			seguir = ad.get("a_visual_seguir")
			ultima = ad.get("a_visual_ultima")
			oculto[0] = 1
			seguir[0] = 1
			ultima[0] = Vector2(123, 456)
			ad.set("a_visual_oculto", oculto)
			ad.set("a_visual_seguir", seguir)
			ad.set("a_visual_ultima", ultima)
			if metodo == "limpar":
				ad.limpar()
			else:
				ad._nova(h.pos, Vector2.RIGHT, 270.0, 320.0, 1.0, 0.0, 0.0, Color.WHITE, 0, false, 4.0)
			ok(
				int(ad.get("a_visual_oculto")[0]) == 0 and int(ad.get("a_visual_seguir")[0]) == 0 and ad.get("a_visual_ultima")[0] == Vector2.ZERO,
				"%s limpa estado de visibilidade da vaga" % metodo
			)
	h.tipo.info = info_original
	Herois.forcado = ""
	w.queue_free()
	await get_tree().process_frame
	print("v2_mecha_contato falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)


## Só conta pontos que o renderizador deve exibir; a base anterior ainda não tem o flag de ocultação.
func _visivel(ad) -> bool:
	var oculto = ad.get("a_visual_oculto")
	return oculto == null or int(oculto[0]) == 0


func _monotonicidade(m, h, ad, tabela: Dictionary) -> void:
	ok((tabela.get("canhoes", []) as Array).size() == 8 and (tabela.get("pods", []) as Array).size() == 8, "usa as bocas reais do atlas")
	for modo in ["fixo", "entrar", "nascer"]:
		for proj in ["bala", "missil"]:
			for ang in 8:
				var dir := Vector2.from_angle(float(ang) * PI / 4.0)
				for lado in 2:
					for distancia in [25.0, 45.0, 75.0, 120.0]:
						ad.limpar()
						w.combate.fx.limpar()
						h.esp_carga = 0.0
						h.tipo.info["bocas_projeteis"] = tabela
						m.vida = m.vida_max
						m.emp = Vector2.ZERO
						w.monstros.erase(m)
						if modo != "nascer":
							w.monstros.append(m)
						var origem: Vector2 = h.pos + h.ORIGEM_GOLPE
						if proj == "missil":
							origem += Vector2(-dir.y, dir.x) * (-9.0 if lado == 0 else 9.0)
						var passo: Dictionary = w.combate.cfg.golpe.passos[lado].duplicate(true)
						passo.proj = proj
						passo.cone_dir = dir
						passo.giro = 0.0
						var numero := 289219 + ang * 1000 + lado * 100 + int(distancia)
						seed(numero)
						var caminho := dir.rotated(randf_range(-0.025, 0.025))
						var inicio := origem + caminho * 10.0
						m.pos = inicio + caminho * (distancia if modo == "fixo" else 200.0) + Vector2(0, 6)
						seed(numero)
						ad.lancar(h, origem, dir, passo)
						var ultimo: Vector2 = ad._pos_visual(0)
						var tem_ultimo := _visivel(ad)
						var visiveis := 1 if tem_ultimo else 0
						var avanco := 0.0
						var recuou := false
						var espacoso := false
						if modo == "fixo":
							espacoso = distancia - float(m.raio) - float(ad.a_raio[0]) - (ultimo - inicio).dot(caminho) >= 10.0
						for q in 120:
							if q == 2 and modo != "fixo":
								if modo == "nascer":
									w.monstros.append(m)
								m.pos = ad.a_pos[0] + ad.a_dir[0] * distancia + Vector2(0, 6)
								espacoso = (
									(ad.a_pos[0] - inicio).dot(caminho) + distancia - float(m.raio) - float(ad.a_raio[0]) - (ultimo - inicio).dot(caminho)
									>= 10.0
								)
							ad.atualizar(DT)
							if ad.a_rest[0] <= 0.0:
								break
							if not _visivel(ad):
								continue
							var p: Vector2 = ad._pos_visual(0)
							if tem_ultimo:
								var passo_visual: float = (p - ultimo).dot(ad.a_dir[0])
								if passo_visual < -0.011:
									recuou = true
								avanco += maxf(passo_visual, 0.0)
							ultimo = p
							tem_ultimo = true
							visiveis += 1
						var etiqueta := "%s %s direção %d lado %d distância %.0f" % [modo, proj, ang, lado, distancia]
						ok(not recuou, "%s não recua nos pontos visíveis" % etiqueta)
						if distancia >= 75.0 or espacoso:
							ok(visiveis >= 2 and avanco > 0.05, "%s com espaço conserva voo visível" % etiqueta)
						ok(ad.acertos == 1, "%s ainda atinge o alvo" % etiqueta)
	if not w.monstros.has(m):
		w.monstros.append(m)


## O alvo entra após dois quadros; o voo precisa avançar com três tamanhos de passo, sem mudar física/RNG.
func _dt_variavel(m, h, ad, tabela: Dictionary) -> void:
	var dir := Vector2.RIGHT
	var origem: Vector2 = h.pos + h.ORIGEM_GOLPE
	var passo: Dictionary = w.combate.cfg.golpe.passos[0].duplicate(true)
	passo.cone_dir = dir
	passo.giro = 0.0
	for dt in [1.0 / 60.0, 1.0 / 120.0, 1.0 / 30.0]:
		var referencia := []
		for com_boca in [false, true]:
			ad.limpar()
			w.combate.fx.limpar()
			h.esp_carga = 0.0
			h.tipo.info["bocas_projeteis"] = tabela if com_boca else {}
			m.vida = m.vida_max
			m.emp = Vector2.ZERO
			m.pos = origem + Vector2(200, 6)
			seed(219421)
			ad.lancar(h, origem, dir, passo)
			var ultimo: Vector2 = ad._pos_visual(0)
			var tem_ultimo := _visivel(ad)
			var visiveis := 1 if tem_ultimo else 0
			var avanco := 0.0
			var recuou := false
			var amostras := []
			for q in 140:
				if q == 2:
					m.pos = ad.a_pos[0] + ad.a_dir[0] * 75.0 + Vector2(0, 6)
				ad.atualizar(dt)
				amostras.append([ad.a_pos[0], ad.a_dir[0], ad.a_rest[0], m.vida, ad.acertos])
				if ad.a_rest[0] <= 0.0:
					break
				if _visivel(ad):
					var p: Vector2 = ad._pos_visual(0)
					if tem_ultimo:
						var desloc: float = (p - ultimo).dot(ad.a_dir[0])
						recuou = recuou or desloc < -0.011
						avanco += maxf(desloc, 0.0)
					ultimo = p
					tem_ultimo = true
					visiveis += 1
			ok(ad.acertos == 1, "dt %.5f atinge o alvo tardio" % dt)
			var trilha := [amostras, randi(), randi(), randi()]
			if com_boca:
				ok(not recuou and visiveis >= 2 and avanco > 0.05, "dt %.5f mantém voo visível sem recuo" % dt)
				ok(trilha == referencia, "dt %.5f preserva física, dano e RNG" % dt)
			else:
				referencia = trilha


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
				var ric_antes: int = ad.a_ric[0]
				ad.atualizar(DT)
				if com_boca and modo == "ricochete" and ric_antes > 0 and ad.a_ric[0] == 0:
					var oculto = ad.get("a_visual_oculto")
					var ultima = ad.get("a_visual_ultima")
					if oculto != null and ultima != null:
						ok(int(oculto[0]) == 0 and (ultima[0] as Vector2).distance_to(ad.a_pos[0]) < 0.01, "ricochete reinicia posição visível no contato")
				var residual: float = (ad._pos_visual(0) - ad.a_pos[0]).length()
				if residual > anterior + 0.02:
					voltou = true
				anterior = residual
				if prazo < INF and ad.a_rest[0] > 0.0:
					var k := clampf(1.0 - nascimento.distance_to(ad.a_pos[0]) / prazo, 0.0, 1.0)
					if prazo >= 60.0:
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
