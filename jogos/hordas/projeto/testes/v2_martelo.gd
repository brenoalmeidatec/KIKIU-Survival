extends "res://testes/isolamento_v2.gd"
# Teste do golpe de MARTELO do Nick (v2/combate.gd, v2/efeitos.gd, dados/v2_martelo.json, dados/v2_folhas_fx.json martelo_*):
#  - os passos batida e pancada do Nick são de martelo ("fx") e os da katana não;
#  - a batida usa o rastro NOVO (folha martelo_rastro, 10 quadros, 4 linhas de direção) e NÃO o arco de lâmina (fx.corte não é chamado); no acerto
#    cai o impacto (folha martelo_impacto, achatada 0,62) à frente do herói; a pancada em volta vira a onda de choque (martelo_onda, 14 quadros) nos pés;
#  - as folhas em disco: N quadros, alfa só nos degraus do estilo, nada preso à borda do quadro, chão achatado em ~0,62;
#  - pool fixo (o número de nós não cresce com 60 golpes), escala 1, posição inteira, 16 direções pré-desenhadas (nada de rotação livre);
#  - o FLASH do chão é pequeno e curto (área clara por quadro ≤ FLASH_MAX_PCT da área do anel) e as RACHADURAS são escuras (calor 0, nunca luz): falha nas folhas antigas;
#  - tremor de câmera quando a batida erra, sem alvo;
#  - Reduzir piscadas: o chão do martelo (impacto e onda) troca de luz no máximo 3 vezes por segundo em qualquer janela de 1 s (desligada passa disso);
#  - perfil Baixo (Anim.suave desligado): o martelo continua usando as folhas, sem quadro fundido.
# Falha no código antigo (o passo da batida desenhava o corte da katana). Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_martelo.tscn
const Mundo := preload("res://v2/mundo.tscn")
const Efeitos := preload("res://v2/efeitos.gd")
const Herois := preload("res://v2/herois.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const Anim := preload("res://v2/anim_golpes.gd")
const PASSO := 1.0 / 60.0
const FLASH_MAX_PCT := 9.0  # área com calor >= CLARO por quadro, em % da elipse do anel (raio da folha x 0,62); as folhas antigas passavam de 20%
const BRANCO_MAX_PCT := 2.0  # e o branco cheio (calor 255) no máximo isto
const CLARO := 0.6
const ESCURO_ATE := 0.1  # calor abaixo disto com alfa = rachadura escura
const ESCURO_MIN_PX := 40  # em algum quadro cada folha tem pelo menos isto de rachadura escura
const TONS_ALFA := [0, 64, 128, 212, 255]  # os degraus de alfa do estilo (0 = vazio)
var falhas := 0
var w
var h
var fx
var _cache_brilho := {}


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Herois.forcado = "nicao"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	h = w.heroi
	fx = w.combate.fx
	zerar()
	_t_dados()
	_t_folhas_em_disco()
	_t_flash_e_rachaduras()
	_t_batida()
	_t_pancada()
	_t_direcoes()
	_t_pool()
	_t_tremor()
	_t_piscadas()
	_t_baixo()
	Anim.suave = true
	Config.definir(Piscadas.OPCAO, false)
	print("v2_martelo falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.m_critico = -1.0
	fx.limpar()


func passo_de(nome: String) -> Dictionary:
	return w.combate.passos_de(nome)[0]


## O último slot do pool do martelo que nasceu.
func ultimo() -> Sprite2D:
	return fx._fo[Efeitos.PRIM_MARTELO + posmod(fx._mt_i - 1 - Efeitos.PRIM_MARTELO, fx.MAX_FOLHAS - Efeitos.PRIM_MARTELO)]


func folha_de(s: Sprite2D) -> Texture2D:
	return (s.material as ShaderMaterial).get_shader_parameter("folha") as Texture2D


func _t_dados() -> void:
	ok(w.combate.martelo_do_passo(passo_de("batida")) and w.combate.martelo_do_passo(passo_de("pancada")), "Nick: batida e pancada são passos de martelo")
	ok(
		not w.combate.martelo_do_passo({"nome": "corte"}) and not w.combate.martelo_do_passo({"nome": "estocada", "fx": ""}),
		"katana: corte e estocada não são de martelo"
	)
	for hid in ["hazaki", "lightwolf"]:
		for hd in Dados.json("v2_herois").herois:
			if str(hd.id) == hid:
				for p in hd.cfg.golpe.passos:
					ok(str(p.get("fx", "")) != "martelo", "%s: o passo %s não é de martelo" % [hid, p.nome])
	var def: Dictionary = Dados.json("v2_folhas_fx")
	ok(int(def.martelo_rastro.quadros) == 10 and int(def.martelo_rastro.linhas) == 4, "martelo_rastro: 10 quadros e 4 linhas (16 direções)")
	ok(int(def.martelo_impacto.quadros) == 12 and int(def.martelo_onda.quadros) == 14, "martelo_impacto 12 quadros, martelo_onda 14")
	for nome in ["martelo_impacto", "martelo_onda"]:
		for par in def[nome].tam:
			ok(
				absf(float(par[1]) / float(par[0]) - 0.62) < 0.035 and int(par[0]) % 2 == 0 and int(par[1]) % 2 == 0,
				"%s %s: par e achatada em ~0,62 (avisos.ACHATA)" % [nome, par]
			)
	var m: Dictionary = Dados.json("v2_martelo")
	ok(m.has("_ajuda") and m.has("rastro") and m.has("impacto") and m.has("onda") and float(m.repete_calmo) > 0.0, "v2_martelo.json: tem _ajuda e os blocos")


func _t_folhas_em_disco() -> void:
	var def: Dictionary = Dados.json("v2_folhas_fx")
	for nome in ["martelo_rastro", "martelo_impacto", "martelo_onda"]:
		var d: Dictionary = def[nome]
		for par in d.tam:
			var lar := int(par[0])
			var alt := int(par[1])
			var tex := load("res://assets/v2/efeitos/efeito_%s_e%d.png" % [nome, lar]) as Texture2D
			var im := tex.get_image() if tex != null else null
			ok(
				im != null and im.get_width() == int(d.quadros) * lar and im.get_height() == int(d.linhas) * alt,
				"%s %s: a folha tem %d quadros x %d linhas" % [nome, par, d.quadros, d.linhas]
			)
			if im == null:
				continue
			var ruim_alfa := 0
			var preso := 0
			var vivos: Array = []
			for l in int(d.linhas):
				for q in int(d.quadros):
					var n := 0
					for y in alt:
						for x in lar:
							var a := roundi(im.get_pixel(q * lar + x, l * alt + y).a * 255.0)
							if not TONS_ALFA.has(a):
								ruim_alfa += 1
							if a > 0:
								n += 1
								if x == 0 or y == 0 or x == lar - 1 or y == alt - 1:
									preso += 1
					vivos.append(n)
			ok(ruim_alfa == 0, "%s %s: o alfa só tem os degraus do estilo (%d pixels fora)" % [nome, par, ruim_alfa])
			ok(preso == 0, "%s %s: nada preso à borda do quadro (%d)" % [nome, par, preso])
			ok(int(vivos[0]) > 0 and int(vivos[int(d.quadros) / 2]) > 0, "%s %s: os quadros do começo e do meio têm desenho" % [nome, par])


func _t_flash_e_rachaduras() -> void:
	var def: Dictionary = Dados.json("v2_folhas_fx")
	for nome in ["martelo_impacto", "martelo_onda"]:
		var d: Dictionary = def[nome]
		for par in d.tam:
			var lar := int(par[0])
			var alt := int(par[1])
			var tex := load("res://assets/v2/efeitos/efeito_%s_e%d.png" % [nome, lar]) as Texture2D
			var im := tex.get_image()
			var area := PI * pow(lar / 2.0 - 2.0, 2.0) * 0.62
			var pior_claro := 0.0
			var pior_branco := 0.0
			var mais_escuro := 0
			for q in int(d.quadros):
				var claro := 0
				var branco := 0
				var escuro := 0
				for y in alt:
					for x in lar:
						var c := im.get_pixel(q * lar + x, y)
						if c.a <= 0.0:
							continue
						if c.r >= CLARO:
							claro += 1
						if c.r >= 0.99:
							branco += 1
						if c.r < ESCURO_ATE:
							escuro += 1
				pior_claro = maxf(pior_claro, 100.0 * claro / area)
				pior_branco = maxf(pior_branco, 100.0 * branco / area)
				mais_escuro = maxi(mais_escuro, escuro)
			ok(
				pior_claro <= FLASH_MAX_PCT,
				"%s %s: o flash claro cobre no máximo %.1f%% da área do anel por quadro (máx %.1f%%)" % [nome, par, pior_claro, FLASH_MAX_PCT]
			)
			ok(
				pior_branco <= BRANCO_MAX_PCT,
				"%s %s: o branco cheio cobre no máximo %.1f%% do anel por quadro (máx %.1f%%)" % [nome, par, pior_branco, BRANCO_MAX_PCT]
			)
			ok(
				mais_escuro >= ESCURO_MIN_PX,
				"%s %s: as rachaduras são ESCURAS (calor < %.2f): %d px no melhor quadro (mín %d)" % [nome, par, ESCURO_ATE, mais_escuro, ESCURO_MIN_PX]
			)


func _t_batida() -> void:
	zerar()
	var p0 := passo_de("batida")
	var dir := Vector2.RIGHT
	var cortes: int = fx.usados.cortes
	var mart: int = fx.usados.martelo
	w.combate.golpe_comecou(h, p0, dir, float(p0.duracao))
	ok(fx.usados.cortes == cortes, "batida: NÃO desenha o corte (arco de lâmina) da katana")
	ok(fx.usados.martelo == mart + 1, "batida: desenha o rastro do martelo")
	var s := ultimo()
	var quad := s.texture.get_size()
	ok(s.visible and s.scale == Vector2.ONE and s.position == s.position.round(), "batida: rastro com escala 1 e posição inteira")
	var folha := folha_de(s)
	ok(
		folha != null and is_equal_approx(folha.get_width(), 10.0 * quad.x) and is_equal_approx(folha.get_height(), 4.0 * quad.y),
		"batida: usa a folha martelo_rastro (10 quadros, 4 linhas; %s para quad %s)" % [folha.get_size() if folha != null else "?", quad]
	)
	var alc: float = w.combate.alcance_do_passo(p0, h)
	ok(absf(quad.x / (2.0 * alc * 1.3) - 1.0) < 0.2, "batida: o quadro %s fica perto do pedido %.0f" % [quad.x, 2.0 * alc * 1.3])
	# o controle: o mesmo passo SEM o campo fx desenha o corte da katana (prova que o teste pega o código antigo)
	var igual := p0.duplicate()
	igual.erase("fx")
	cortes = fx.usados.cortes
	mart = fx.usados.martelo
	w.combate.golpe_comecou(h, igual, dir, float(p0.duracao))
	ok(fx.usados.cortes == cortes + 1 and fx.usados.martelo == mart, "controle: sem o fx, o passo desenha o corte da katana e nada do martelo")
	# o acerto: o impacto cai à frente
	mart = fx.usados.martelo
	w.combate.golpear(h, h.pos + h.ORIGEM_GOLPE, dir, p0, 0)
	ok(fx.usados.martelo == mart + 1, "batida: o acerto solta o impacto no chão")
	s = ultimo()
	quad = s.texture.get_size()
	folha = folha_de(s)
	ok(
		folha != null and is_equal_approx(folha.get_width(), 12.0 * quad.x) and is_equal_approx(folha.get_height(), quad.y),
		"batida: o impacto usa a folha martelo_impacto (12 quadros)"
	)
	ok(absf(quad.y / quad.x - 0.62) < 0.035, "batida: o impacto vem achatado no chão (%s)" % quad)
	var esperado: Vector2 = h.pos + Vector2(0, -2) + dir * alc * 0.8
	ok(s.position.distance_to(esperado) <= 1.01, "batida: o impacto cai a 0,8 do alcance à frente (%s, esperado %s)" % [s.position, esperado])


func _t_pancada() -> void:
	zerar()
	var p1 := passo_de("pancada")
	var mart: int = fx.usados.martelo
	var cortes: int = fx.usados.cortes
	w.combate.golpe_comecou(h, p1, Vector2.RIGHT, float(p1.duracao))
	ok(fx.usados.cortes == cortes, "pancada: não desenha corte de lâmina")
	w.combate.golpear(h, h.pos + h.ORIGEM_GOLPE, Vector2.RIGHT, p1, 1)
	ok(fx.usados.martelo == mart + 1, "pancada: solta a onda de choque")
	var s := ultimo()
	var quad := s.texture.get_size()
	var folha := folha_de(s)
	ok(
		folha != null and is_equal_approx(folha.get_width(), 14.0 * quad.x) and is_equal_approx(folha.get_height(), quad.y),
		"pancada: usa a folha martelo_onda (14 quadros)"
	)
	ok(absf(quad.y / quad.x - 0.62) < 0.035, "pancada: a onda vem achatada no chão (%s)" % quad)
	var alc: float = w.combate.alcance_do_passo(p1, h)
	ok(quad.x >= 2.0 * alc * 0.8 and quad.x <= 2.0 * alc * 1.5, "pancada: a onda cobre o alcance (%.0f px para alcance %.0f)" % [quad.x, alc])
	ok(s.position.distance_to(h.pos + Vector2(0, -2)) <= 1.01, "pancada: a onda é centrada nos pés do herói")


func _t_direcoes() -> void:
	var p0 := passo_de("batida")
	for k in 16:
		var ang := float(k) * TAU / 16.0
		zerar()
		w.combate.golpe_comecou(h, p0, Vector2.from_angle(ang), float(p0.duracao))
		var mat := ultimo().material as ShaderMaterial
		var d := Efeitos.corte_direcao(ang, 1.0)
		ok(
			int(mat.get_shader_parameter("fila")) == d.x and int(mat.get_shader_parameter("giros")) == d.y,
			"direção %d: linha %d e %d quartos de volta (pré-desenhado)" % [k, d.x, d.y]
		)
		ok(ultimo().rotation == 0.0, "direção %d: o sprite não gira" % k)


func _t_pool() -> void:
	zerar()
	var antes: int = fx.raiz.get_child_count()
	var n_fo: int = fx._fo.size()
	var p0 := passo_de("batida")
	var p1 := passo_de("pancada")
	for i in 60:
		w.combate.golpe_comecou(h, p0, Vector2.from_angle(float(i)), float(p0.duracao))
		w.combate.golpear(h, h.pos, Vector2.from_angle(float(i)), p0 if i % 2 == 0 else p1, i % 2)
		fx.atualizar(PASSO)
	ok(fx.raiz.get_child_count() == antes and fx._fo.size() == n_fo, "pool fixo: 60 golpes não criaram nó (%d -> %d)" % [antes, fx.raiz.get_child_count()])
	ok(fx.MAX_FOLHAS - Efeitos.PRIM_MARTELO >= 4, "o pool do martelo tem vagas de sobra para dois golpes sobrepostos")
	# o martelo não rouba a vaga do cristal nem da centelha
	fx.limpar()
	fx.folha("anel", Vector2(40, 40), 20.0, Color.WHITE, 0.4)
	var vaga_anel: int = posmod(fx._fo_i - 1, 6)
	w.combate.golpear(h, h.pos, Vector2.RIGHT, p1, 1)
	ok(fx._fo[vaga_anel].visible, "o martelo não apaga o anel que já estava no pool de folhas")


func _t_tremor() -> void:
	zerar()
	w.cam.tremor_amp = 0.0
	w.combate.golpear(h, h.pos + h.ORIGEM_GOLPE, Vector2.RIGHT, passo_de("batida"), 0)
	ok(w.cam.tremor_amp > 0.0, "batida no ar (sem alvo): a câmera treme um pouco (%.1f)" % w.cam.tremor_amp)
	w.cam.tremor_amp = 0.0
	w.combate.golpear(h, h.pos + h.ORIGEM_GOLPE, Vector2.RIGHT, passo_de("pancada"), 1)
	ok(w.cam.tremor_amp >= float(passo_de("pancada").tremor) * 0.5 - 0.01, "pancada: o chão treme (%.1f)" % w.cam.tremor_amp)


## Brilho (soma de calor x alfa) do quadro `q` da folha `tex` com `quadros` quadros em linha (uma linha só), guardado.
func _brilho(tex: Texture2D, quadros: int, q: int) -> float:
	var k := "%d_%d" % [tex.get_instance_id(), q]
	if not _cache_brilho.has(k):
		var im := tex.get_image()
		var lar := im.get_width() / quadros
		var soma := 0.0
		for y in im.get_height():
			for x in lar:
				var px := im.get_pixel(q * lar + x, y)
				soma += px.r * px.a
		_cache_brilho[k] = soma
	return _cache_brilho[k]


## A luz do chão do martelo agora (impacto e onda): o rastro (4 linhas) é um risco que se move, como o arco da katana, e não entra.
func _luminancia_chao() -> float:
	var total := 0.0
	for i in range(Efeitos.PRIM_MARTELO, fx.MAX_FOLHAS):
		if fx._fo_t[i] >= fx._fo_dur[i]:
			continue
		var s: Sprite2D = fx._fo[i]
		var tex := folha_de(s)
		if int(tex.get_height()) > int(s.texture.get_size().y) + 1:
			continue
		var quadros := int(float((s.material as ShaderMaterial).get_shader_parameter("quadros")))
		var q := mini(int(fx._fo_t[i] / fx._fo_dur[i] * float(quadros)), quadros - 1)
		total += _brilho(tex, quadros, q)
	return total


## `so_batida`: só batidas, uma a cada `cada` s (ataque rápido); senão batida e pancada em seguida, no ritmo do combo.
func _serie_golpes(so_batida := false, cada := 0.4) -> Array:
	zerar()
	var p0 := passo_de("batida")
	var p1 := passo_de("pancada")
	var serie: Array = []
	var proximo := 0.0
	var alterna := 0
	for q in 360:  # 6 s de golpes seguidos: batida (0,55 s) e pancada (0,75 s)
		var t := float(q) * PASSO
		if t >= proximo:
			var p: Dictionary = p0 if (so_batida or alterna % 2 == 0) else p1
			w.combate.golpear(h, h.pos + h.ORIGEM_GOLPE, Vector2.RIGHT, p, 0 if so_batida else alterna % 2)
			proximo = t + (cada if so_batida else float(p.duracao))
			alterna += 1
		fx.atualizar(PASSO)
		serie.append(_luminancia_chao())
	return serie


func _t_piscadas() -> void:
	Config.definir(Piscadas.OPCAO, false)
	var pior_sem := Piscadas.trocas_janela(_serie_golpes(true), 60)
	ok(pior_sem > Piscadas.MAX_TROCAS_S, "controle: sem a opção, batidas a cada 0,4 s trocam %d vezes na pior janela de 1 s (passa de 3)" % pior_sem)
	Config.definir(Piscadas.OPCAO, true)
	for modo in 2:
		var com: Array = _serie_golpes(modo == 0)
		var pior_com := Piscadas.trocas_janela(com, 60)
		ok(pior_com > 0, "ligada (%s): o chão do martelo ainda aparece de vez em quando" % ("só batidas" if modo == 0 else "combo"))
		ok(
			pior_com <= Piscadas.MAX_TROCAS_S,
			"ligada (%s): o chão do martelo troca %d vezes na pior janela de 1 s (máximo 3)" % ["só batidas" if modo == 0 else "combo", pior_com]
		)
	# a luz do rastro também respeita o intervalo: dois rastros colados acendem uma luz só
	zerar()
	fx.martelo_rastro(Vector2(100, 100), 0.0, 70.0, Color.WHITE, 0.4)
	fx.martelo_rastro(Vector2(100, 100), 0.0, 70.0, Color.WHITE, 0.4)
	var acesas := 0
	for l in fx._luzes:
		if l.enabled:
			acesas += 1
	ok(acesas == 1, "ligada: dois rastros colados acendem 1 luz (acenderam %d)" % acesas)
	# o intervalo: dois impactos colados, o segundo é pulado; depois do intervalo volta
	zerar()
	var alc := 70.0
	ok(fx.martelo_chao(false, Vector2(100, 100), alc, Color.WHITE), "ligada: o primeiro impacto desenha")
	ok(not fx.martelo_chao(false, Vector2(100, 100), alc, Color.WHITE), "ligada: o segundo, colado, é pulado (o dano não depende disso)")
	for q in 65:
		fx.atualizar(PASSO)  # 1,08 s
	ok(fx.martelo_chao(true, Vector2(100, 100), alc, Color.WHITE), "ligada: passado o intervalo (>= 1,0 s) volta a desenhar")
	Config.definir(Piscadas.OPCAO, false)
	zerar()
	ok(
		fx.martelo_chao(false, Vector2(100, 100), alc, Color.WHITE) and fx.martelo_chao(false, Vector2(100, 100), alc, Color.WHITE),
		"desligada: nenhum impacto é pulado"
	)


func _t_baixo() -> void:
	Config.definir(Piscadas.OPCAO, false)
	Anim.suave = false  # perfil Baixo: sem golpes suaves
	zerar()
	var p0 := passo_de("batida")
	var mart: int = fx.usados.martelo
	w.combate.golpe_comecou(h, p0, Vector2.RIGHT, float(p0.duracao))
	w.combate.golpear(h, h.pos + h.ORIGEM_GOLPE, Vector2.RIGHT, p0, 0)
	w.combate.golpear(h, h.pos + h.ORIGEM_GOLPE, Vector2.RIGHT, passo_de("pancada"), 1)
	ok(fx.usados.martelo == mart + 3, "Baixo: rastro, impacto e onda do martelo continuam desenhados (3 folhas)")
	var mat := ultimo().material as ShaderMaterial
	ok(float(mat.get_shader_parameter("suave")) == 0.0 and ultimo().visible, "Baixo: sem quadro fundido, folha visível")
	for q in 40:
		fx.atualizar(PASSO)
	Anim.suave = true
