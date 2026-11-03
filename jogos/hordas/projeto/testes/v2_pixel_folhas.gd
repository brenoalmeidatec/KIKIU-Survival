extends "res://testes/isolamento_v2.gd"
# Teste automático do corte da katana e das folhas de efeito em 1 px de arte = 1 px do jogo (v2/efeitos.gd, dados/v2_folhas_fx.json):
#  - corte() e folha() desenham com escala 1: o quad do sprite tem exatamente o tamanho do quadro da folha escolhida (antes: quadro de 128 px
#    esticado por 2r/128, ~1,04x no alcance 46 e 2,08x na ciano de pixel de 2 px; o chão ainda achatado a 0,62 no Y);
#  - o tamanho do quadro é par (o sprite centrado fica com a borda em pixel inteiro) e o mais perto do pedido (erro de até ~12%, ou a ponta da lista);
#  - os efeitos de chão já vêm achatados na folha (altura ~0,62 da largura) e a centelha (estrela) é quadrada;
#  - o corte de folha não cresce em tempo de execução (o 0,88 a 1,0 do "suave" era escala fracionária animada).
# Falha no código antigo (escala 2,08 e 0,45..1,1; quad de 64 px). Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pixel_folhas.tscn
const Mundo := preload("res://v2/mundo.tscn")
const Efeitos := preload("res://v2/efeitos.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var fx = w.combate.fx
	_t_tamanho()
	_t_corte(fx, "katana")
	_t_corte(fx, "ciano")
	_t_folhas(fx)
	print("v2_pixel_folhas falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func _t_tamanho() -> void:
	var l := PackedInt32Array([56, 72, 92, 112, 134, 160, 192])
	ok(Efeitos.tamanho_perto(l, 133.4) == 4, "alcance 46 (quad 133) escolhe a folha de 134")
	ok(Efeitos.tamanho_perto(l, 10.0) == 0 and Efeitos.tamanho_perto(l, 900.0) == 6, "fora das pontas fica com a ponta (nunca amplia)")
	ok(Efeitos.tamanho_perto(l, 100.0) == 2 and Efeitos.tamanho_perto(l, 104.0) == 3, "o mais perto pela razão: 100 -> 92, 104 -> 112")


## O último sprite de corte que nasceu.
func _ultimo_corte(fx) -> Sprite2D:
	return fx._cortes[posmod(fx._ci - 1, fx.MAX_CORTES)]


func _t_corte(fx, variante: String) -> void:
	fx.variante = variante
	var nome := "corte_ciano" if variante == "ciano" else "corte"
	var def: Dictionary = Dados.json("v2_folhas_fx")[nome]
	var menor := float(def.tam[0][0])
	var maior := float(def.tam[def.tam.size() - 1][0])
	for alc in [20.0, 30.0, 40.0, 46.0, 48.0, 55.0, 64.0, 74.0, 90.0, 140.0]:
		for lado in [1.0, -1.0]:
			fx.limpar()
			fx.corte(Vector2(100.4, 100.6), 0.7, alc, 125.0, lado, "corte", Color.WHITE, 0.3)
			var s := _ultimo_corte(fx)
			var rot := "%s alcance %.0f" % [variante, alc]
			ok(s.visible and s.scale == Vector2.ONE, "%s: o corte de folha tem escala 1 (escala %s)" % [rot, s.scale])
			ok(s.position == s.position.round(), "%s: posição inteira (%s)" % [rot, s.position])
			var quad := s.texture.get_size()
			ok(quad.x == quad.y and int(quad.x) % 2 == 0, "%s: quad quadrado e par (%s)" % [rot, quad])
			var folha := (s.material as ShaderMaterial).get_shader_parameter("folha") as Texture2D
			var quadros := float((s.material as ShaderMaterial).get_shader_parameter("quadros"))
			ok(
				folha != null and is_equal_approx(folha.get_width(), quadros * quad.x),
				"%s: a folha tem os quadros do tamanho do quad (%s x %s)" % [rot, folha.get_size(), quad]
			)
			ok(folha != null and is_equal_approx(folha.get_height(), 4.0 * quad.y), "%s: as 4 linhas (giros) do tamanho do quad" % rot)
			var pedido: float = 2.0 * alc * 1.45
			if pedido >= menor and pedido <= maior:
				ok(absf(quad.x / pedido - 1.0) < 0.13, "%s: o quadro %s fica a ~12%% do pedido %.0f" % [rot, quad.x, pedido])
			# nada cresce no meio do golpe: a escala segue 1 durante todo o rastro (Anim.suave ligado ou não)
			for i in 12:
				fx.atualizar(PASSO)
				ok(s.scale == Vector2.ONE, "%s: a escala segue 1 durante o golpe (%s)" % [rot, s.scale])
	fx.limpar()
	# a estocada continua calculada no shader (sem folha): quad de 64 px com escala (formas por pixel do mundo)
	fx.corte(Vector2(100, 100), 0.0, 74.0, 46.0, 1.0, "estocada", Color.WHITE, 0.3)
	ok(_ultimo_corte(fx).texture.get_size() == Vector2(64, 64), "a estocada segue com o quad de 64 px")
	fx.variante = "katana"
	fx.limpar()


func _t_folhas(fx) -> void:
	var def_todas: Dictionary = Dados.json("v2_folhas_fx")
	for nome in ["cristal", "estrela", "anel", "espiral"]:
		var def: Dictionary = def_todas[nome]
		for par in def.tam:
			ok(int(par[0]) % 2 == 0 and int(par[1]) % 2 == 0, "%s %s: quadro par" % [nome, par])
			if nome == "estrela":
				ok(par[0] == par[1], "estrela %s: quadrada" % [par])
			else:
				ok(absf(float(par[1]) / float(par[0]) - 0.62) < 0.035, "%s %s: já achatada em ~0,62" % [nome, par])
		var menor := float(def.tam[0][0])
		var maior := float(def.tam[def.tam.size() - 1][0])
		for raio in [8.0, 11.0, 15.0, 22.0, 30.0, 40.0, 55.0, 77.0, 100.0, 150.0, 400.0]:
			fx.limpar()
			fx.folha(nome, Vector2(50.4, 60.6), raio, Color.WHITE, 0.3)
			var i: int = posmod(fx._ce_i - 1 - 6, 8) + 6 if nome == "estrela" else posmod(fx._fo_i - 1, 6)
			var s: Sprite2D = fx._fo[i]
			var rot := "%s raio %.0f" % [nome, raio]
			ok(s.visible and s.scale == Vector2.ONE, "%s: a folha tem escala 1 (escala %s)" % [rot, s.scale])
			ok(s.position == s.position.round(), "%s: posição inteira (%s)" % [rot, s.position])
			var quad := s.texture.get_size()
			var folha := (s.material as ShaderMaterial).get_shader_parameter("folha") as Texture2D
			var quadros := float((s.material as ShaderMaterial).get_shader_parameter("quadros"))
			ok(
				folha != null and is_equal_approx(folha.get_width(), quadros * quad.x) and is_equal_approx(folha.get_height(), quad.y),
				"%s: a folha tem o tamanho do quad (%s para %s quadros de %s)" % [rot, folha.get_size() if folha != null else "?", quadros, quad]
			)
			if 2.0 * raio >= menor and 2.0 * raio <= maior:
				ok(absf(quad.x / (2.0 * raio) - 1.0) < 0.25, "%s: o quadro %s fica perto do pedido %.0f" % [rot, quad.x, 2.0 * raio])
	fx.limpar()
