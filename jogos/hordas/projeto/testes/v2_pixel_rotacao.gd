extends "res://testes/isolamento_v2.gd"
# Teste automático da regra "pixel art não gira livre" da v2 (v2/pixel_rot.gd, v2/efeitos.gd, v2/heroi.gd, frente ROTAÇÃO do PIXEL-1):
#  - PixelRot arredonda a múltiplos de 90 graus;
#  - o corte da katana (e o eco dele) não gira o sprite: a folha traz o desenho girado 0, 22,5, 45 e 67,5 graus (desenhado no Blender, uma linha cada)
#    em 16 direções e o resto é calculado no shader;
#  - as folhas só têm os tons de alfa e de calor da quantização (sem suavização) e a troca de direção do corte (inclusive
#    com o corte espelhado) leva o miolo do desenho à direção certa na tela, em todos os tamanhos de folha;
#  - os pedaços do monstro que voam giram em passos de 90 graus;
#  - o giro da esquiva e a queda do herói (o caminho de reserva, sem o rolamento desenhado) usam só múltiplos de 90 graus.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pixel_rotacao.tscn  (imprime "v2_pixel_rotacao falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const PixelRot := preload("res://v2/pixel_rot.gd")
const Efeitos := preload("res://v2/efeitos.gd")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const PASSO := 1.0 / 60.0
const FOLHAS := {"corte": 7, "corte_ciano": 5}  # variante -> quantos tons de alfa a quantização deixa (com o zero)
const ARQ := {"corte": "res://assets/v2/efeitos/corte_hazaki_e%d.png", "corte_ciano": "res://assets/v2/efeitos/corte_hazaki_ciano_e%d.png"}

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Herois.forcado = "hazaki"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	_t_pixel_rot()
	for nome in FOLHAS:
		_t_folhas(nome)
	_t_cortes()
	_t_fragmentos()
	_t_heroi()
	Herois.forcado = ""
	print("v2_pixel_rotacao falhas=%d" % falhas)
	get_tree().quit()


func _t_pixel_rot() -> void:
	ok(is_zero_approx(PixelRot.quarto(0.7)), "quarto(0,7 rad) = 0 (%s)" % PixelRot.quarto(0.7))
	ok(is_equal_approx(PixelRot.quarto(0.9), PI / 2.0), "quarto(0,9 rad) = 90 graus")
	ok(is_equal_approx(PixelRot.quarto(-3.0), -PI), "quarto(-3 rad) = -180 graus")
	ok(PixelRot.e_quarto(PI) and PixelRot.e_quarto(0.0) and not PixelRot.e_quarto(0.5), "e_quarto separa os múltiplos de 90 graus")


## A posição do miolo (centro de massa do alfa) do quadro `q` da linha `linha` da folha, em relação ao centro do quadro de `lado` px.
func _miolo(im: Image, q: int, linha: int, lado: int) -> Vector2:
	var soma := Vector2.ZERO
	var peso := 0.0
	for y in lado:
		for x in lado:
			var a := im.get_pixel(q * lado + x, linha * lado + y).a
			if a > 0.0:
				soma += Vector2(x + 0.5 - lado / 2.0, y + 0.5 - lado / 2.0) * a
				peso += a
	return soma / peso if peso > 0.0 else Vector2.ZERO


## Mesma troca de UV do shader do corte (modo 2) aplicada ao quadro `q`: devolve o miolo do quadro como o corte o desenha na tela.
func _miolo_na_tela(im: Image, q: int, lado: int, dir: Vector2i, esp: float) -> Vector2:
	var soma := Vector2.ZERO
	var peso := 0.0
	for y in lado:
		for x in lado:
			var d := Vector2(x + 0.5 - lado / 2.0, y + 0.5 - lado / 2.0)  # posição na tela, em relação ao centro
			if esp < 0.0:
				d.y = -d.y
			var giros := dir.y
			if giros == 3:
				d = Vector2(-d.y, d.x)
			elif giros == 2:
				d = -d
			elif giros == 1:
				d = Vector2(d.y, -d.x)
			var a := (
				im.get_pixel(q * lado + clampi(int(floorf(d.x + lado / 2.0)), 0, lado - 1), dir.x * lado + clampi(int(floorf(d.y + lado / 2.0)), 0, lado - 1)).a
			)
			if a > 0.0:
				soma += Vector2(x + 0.5 - lado / 2.0, y + 0.5 - lado / 2.0) * a
				peso += a
	return soma / peso if peso > 0.0 else Vector2.ZERO


func _t_folhas(nome: String) -> void:
	var def: Dictionary = Dados.json("v2_folhas_fx").get(nome, {})
	ok(not def.is_empty(), "%s: está no dados/v2_folhas_fx.json" % nome)
	if def.is_empty():
		return
	var fx = w.combate.fx
	ok(fx.has_method("corte_direcao"), "%s: o Efeitos escolhe a linha da folha (corte_direcao)" % nome)
	ok(int(def.linhas) == 4, "%s: 4 linhas (0, 22,5, 45 e 67,5 graus)" % nome)
	var niveis := float(FOLHAS[nome] - 1)
	var grade: Array = []
	for par in def.tam:
		var lado := int(par[0])
		ok(int(par[1]) == lado and lado % 2 == 0, "%s %d: quadro quadrado e par (a troca de quartos de volta e o sprite centrado precisam)" % [nome, lado])
		var tex := load(ARQ[nome] % lado) as Texture2D
		ok(tex != null, "%s %d: a folha existe" % [nome, lado])
		if tex == null:
			continue
		var im := tex.get_image()
		ok(im.get_size() == Vector2i(lado * int(def.quadros), lado * 4), "%s %d: tamanho da folha %s" % [nome, lado, im.get_size()])
		# só tons da quantização (sem suavização): alfa em passos de 1/níveis e calor em passos de 1/3
		var ruim := 0
		for y in range(0, im.get_height(), 1):
			for x in range(0, im.get_width(), 1):
				var c := im.get_pixel(x, y)
				if c.a > 0.0 and (absf(c.a * niveis - roundf(c.a * niveis)) > 0.02 or absf(c.r * 3.0 - roundf(c.r * 3.0)) > 0.02):
					ruim += 1
		ok(ruim == 0, "%s %d: %d pixels fora dos tons da quantização" % [nome, lado, ruim])
		grade.append([lado, im])
	if grade.is_empty():
		return
	# o quadro do crescente cheio: a direção do miolo (quatro linhas, 16 direções, os dois lados) bate com o pedido
	var q := 6
	var lado: int = grade[grade.size() / 2][0]
	var im: Image = grade[grade.size() / 2][1]
	var base := _miolo(im, q, 0, lado)
	ok(base.length() > 5.0, "%s: o quadro de teste tem miolo fora do centro (%s)" % [nome, base])
	var pior := 0.0
	for k in 16:
		for esp in [1.0, -1.0]:
			var ang := deg_to_rad(22.5 * k)
			var quer: Vector2i = fx.call("corte_direcao", ang, esp)  # a linha e os giros que o corte usa para esse ângulo e esse lado
			var alvo := Vector2(base.x, base.y * (-1.0 if esp < 0.0 else 1.0)).rotated(ang)  # onde o miolo deve cair: espelha (lado) e depois gira
			var tela := _miolo_na_tela(im, q, lado, quer, esp)
			pior = maxf(pior, absf(wrapf(tela.angle() - alvo.angle(), -PI, PI)))
	ok(
		rad_to_deg(pior) < 10.0,
		"%s %d: o miolo do corte cai na direção pedida nas 16 direções e nos dois lados (pior erro %.1f graus)" % [nome, lado, rad_to_deg(pior)]
	)


func _t_cortes() -> void:
	var fx = w.combate.fx
	ok(fx.has_method("corte_direcao"), "o Efeitos escolhe a folha pré-girada (corte_direcao)")
	for ang in [0.7, 2.3, -1.0, 3.0]:
		for lado in [1.0, -1.0]:
			for tipo in ["corte", "estocada"]:
				fx.limpar()
				fx.corte(Vector2(100, 100), ang, 46.0, 110.0, lado, tipo, Color.WHITE, 0.3)
				var visiveis := 0
				for s in fx._cortes:
					if s.visible:
						visiveis += 1
						ok(is_zero_approx(s.rotation), "corte %s a %.1f rad (lado %d): o sprite não gira (rotação %.3f)" % [tipo, ang, int(lado), s.rotation])
						var mat := s.material as ShaderMaterial
						if tipo == "estocada":
							ok(is_equal_approx(float(mat.get_shader_parameter("ang")), ang), "estocada: o shader recebe o ângulo %.1f" % ang)
						else:
							ok(is_zero_approx(float(mat.get_shader_parameter("ang"))), "corte de folha: o shader não gira a forma")
							var g := float(mat.get_shader_parameter("giros"))
							ok(g >= 0.0 and g <= 3.0 and is_equal_approx(g, roundf(g)), "corte de folha: giros inteiros de 0 a 3 (%s)" % g)
				for s in fx._eco:
					if s.visible:
						ok(is_zero_approx(s.rotation), "eco do corte a %.1f rad: o sprite não gira (rotação %.3f)" % [ang, s.rotation])
				ok(visiveis >= 1, "o corte %s nasceu" % tipo)
	fx.limpar()
	# a forma girada no shader mantém o recorte do quad girado de antes (|x| e |y| <= 1 no referencial do golpe): senão a ponta da estocada
	# (até 1,05) aparece inteira nas diagonais
	var codigo: String = Efeitos.SHADER_CORTE
	ok(codigo.contains("if (abs(p.x) > 1.0 || abs(p.y) > 1.0) discard;"), "o shader do corte recorta a forma girada no quadrado do golpe")


func _t_fragmentos() -> void:
	var fx = w.combate.fx
	w.reiniciar()
	w.combate.limpar_partida()
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(60, 0), true)
	fx.fragmentar(m, Vector2.RIGHT)
	var vistos := 0
	var girou := false
	for passo in 33:
		fx.atualizar(0.016)
		for s in fx._fragmentos:
			if s.visible:
				vistos += 1
				ok(PixelRot.e_quarto(s.rotation), "pedaço do monstro: rotação múltipla de 90 graus (%.3f rad)" % s.rotation)
				if absf(s.rotation) > 1.0:
					girou = true
	ok(vistos > 0, "os pedaços do monstro apareceram")
	ok(girou, "os pedaços giram (em passos de 90 graus)")
	fx.limpar()


func _t_heroi() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	# o caminho de reserva: uma folha sem o rolamento e a morte desenhados
	var t2: Dictionary = h.tipo.duplicate()
	var info2: Dictionary = (h.tipo.info as Dictionary).duplicate()
	info2.erase("animacoes")
	t2.info = info2
	h.tipo = t2
	ok(not h._tem_anim("rolamento") and not h._tem_anim("morte"), "reserva: a folha de teste não tem rolamento nem morte")
	h.entrada_forcada = Vector2(1, 0)
	h.esquivar()
	for i in 20:
		if h.estado == Heroi.Estado.ESQUIVA:
			break
		w.avancar(PASSO)
	var maior := 0.0
	var passos := 0
	while h.estado == Heroi.Estado.ESQUIVA and passos < 120:
		w.avancar(PASSO)
		passos += 1
		ok(PixelRot.e_quarto(h.sprite.rotation), "esquiva sem rolamento: rotação múltipla de 90 graus (%.3f rad)" % h.sprite.rotation)
		maior = maxf(maior, absf(h.sprite.rotation))
	ok(passos > 5 and maior > 1.0, "esquiva sem rolamento: o corpo gira (maior rotação %.2f rad em %d passos)" % [maior, passos])
	h.entrada_forcada = Vector2.ZERO
	for i in 60:
		w.avancar(PASSO)
	h.imortal = false
	h.invenc = 0.0
	h.levar_dano(100000.0, h.pos + Vector2(30, 0))
	for i in 90:
		w.avancar(PASSO)
		if h.estado == Heroi.Estado.MORTO:
			ok(PixelRot.e_quarto(h.sprite.rotation), "queda sem morte desenhada: rotação múltipla de 90 graus (%.3f rad)" % h.sprite.rotation)
	ok(h.estado == Heroi.Estado.MORTO, "o herói morreu")
	ok(is_equal_approx(absf(h.sprite.rotation), PI / 2.0), "a queda termina deitada (90 graus, rotação %.3f)" % h.sprite.rotation)
