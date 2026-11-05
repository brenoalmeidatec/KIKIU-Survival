extends "res://testes/isolamento_v2.gd"
# Teste automático da regra "pixel art não gira livre" da v2 (v2/pixel_rot.gd, v2/efeitos.gd, v2/heroi.gd, frente ROTAÇÃO do PIXEL-1):
#  - PixelRot arredonda a múltiplos de 90 graus;
#  - o corte da katana (e o eco dele) não gira o sprite: a folha sai pré-girada (RotSprite) em 16 direções e o resto é calculado no shader;
#  - as folhas pré-giradas só têm cores e alfas que já existem na folha original (sem suavização) e a troca de direção do corte (inclusive
#    com o corte espelhado) leva o miolo do desenho à direção certa na tela;
#  - os pedaços do monstro que voam giram em passos de 90 graus;
#  - o giro da esquiva e a queda do herói (o caminho de reserva, sem o rolamento desenhado) usam só múltiplos de 90 graus.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pixel_rotacao.tscn  (imprime "v2_pixel_rotacao falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const PixelRot := preload("res://v2/pixel_rot.gd")
const Efeitos := preload("res://v2/efeitos.gd")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const PASSO := 1.0 / 60.0
const FOLHA_FONTE := "res://assets/v2/efeitos/corte_pfx.png"
const FOLHAS_R := [
	"res://assets/v2/efeitos/corte_pfx_r1.png",
	"res://assets/v2/efeitos/corte_pfx_r2.png",
	"res://assets/v2/efeitos/corte_pfx_r3.png",
]
const FOLHA_FONTE_CIANO := "res://assets/v2/efeitos/corte_pfx_ciano.png"
const FOLHAS_R_CIANO := [
	"res://assets/v2/efeitos/corte_pfx_ciano_r1.png",
	"res://assets/v2/efeitos/corte_pfx_ciano_r2.png",
	"res://assets/v2/efeitos/corte_pfx_ciano_r3.png",
]

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
	_t_folhas("corte", FOLHA_FONTE, FOLHAS_R)
	_t_folhas("corte ciano", FOLHA_FONTE_CIANO, FOLHAS_R_CIANO)
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


## As cores (RGBA) de uma imagem, como texto, num dicionário.
func _cores(im: Image, regiao: Rect2i) -> Dictionary:
	var d := {}
	for y in range(regiao.position.y, regiao.end.y):
		for x in range(regiao.position.x, regiao.end.x):
			var c := im.get_pixel(x, y)
			if c.a > 0.0:
				d[c.to_html(true)] = true
	return d


## A posição do miolo (centro de massa do alfa) do quadro `q` da imagem, em relação ao centro do quadro de 128 px.
func _miolo(im: Image, q: int) -> Vector2:
	var soma := Vector2.ZERO
	var peso := 0.0
	for y in 128:
		for x in 128:
			var a := im.get_pixel(q * 128 + x, y).a
			if a > 0.0:
				soma += Vector2(x + 0.5 - 64.0, y + 0.5 - 64.0) * a
				peso += a
	return soma / peso if peso > 0.0 else Vector2.ZERO


## Mesma troca de UV do shader do corte (modo 2) aplicada ao quadro `q`: devolve o miolo do quadro como o corte o desenha na tela.
func _miolo_na_tela(folhas: Array, q: int, dir: Vector2i, lado: float) -> Vector2:
	var im: Image = folhas[dir.x]
	var soma := Vector2.ZERO
	var peso := 0.0
	for y in 128:
		for x in 128:
			var d := Vector2(x + 0.5 - 64.0, y + 0.5 - 64.0)  # posição na tela, em relação ao centro
			if lado < 0.0:
				d.y = -d.y
			var giros := dir.y
			if giros == 3:
				d = Vector2(-d.y, d.x)
			elif giros == 2:
				d = -d
			elif giros == 1:
				d = Vector2(d.y, -d.x)
			var a := im.get_pixel(q * 128 + clampi(int(floorf(d.x + 64.0)), 0, 127), clampi(int(floorf(d.y + 64.0)), 0, 127)).a
			if a > 0.0:
				soma += Vector2(x + 0.5 - 64.0, y + 0.5 - 64.0) * a
				peso += a
	return soma / peso if peso > 0.0 else Vector2.ZERO


func _t_folhas(nome: String, fonte: String, giradas: Array) -> void:
	var fi := (load(fonte) as Texture2D).get_image()
	var cores_fonte := _cores(fi, Rect2i(0, 0, fi.get_width(), fi.get_height()))
	var folhas: Array = [fi]
	for caminho in giradas:
		var tex := load(caminho) as Texture2D
		ok(tex != null, "%s: a folha %s existe" % [nome, caminho])
		if tex == null:
			return
		var im := tex.get_image()
		ok(im.get_size() == fi.get_size(), "%s: %s tem o mesmo tamanho da folha original" % [nome, caminho.get_file()])
		var novas := 0
		for c in _cores(im, Rect2i(0, 0, im.get_width(), im.get_height())):
			if not cores_fonte.has(c):
				novas += 1
		ok(novas == 0, "%s: %s só usa cores da folha original (sem suavização), %d cores novas" % [nome, caminho.get_file(), novas])
		folhas.append(im)
	# o quadro mais cheio do desenho: o crescente
	var q := 6
	var base := _miolo(fi, q)
	ok(base.length() > 5.0, "%s: o quadro de teste tem miolo fora do centro (%s)" % [nome, base])
	var fx = w.combate.fx
	if not fx.has_method("corte_direcao"):
		ok(false, "%s: sem corte_direcao não dá para conferir as direções" % nome)
		return
	var pior := 0.0
	for k in 16:
		for lado in [1.0, -1.0]:
			var ang := deg_to_rad(22.5 * k)
			var quer: Vector2i = fx.call("corte_direcao", ang, lado)  # a folha e os giros que o corte usa para esse ângulo e esse lado
			var alvo := Vector2(base.x, base.y * (-1.0 if lado < 0.0 else 1.0)).rotated(ang)  # onde o miolo deve cair: espelha (lado) e depois gira
			var tela := _miolo_na_tela(folhas, q, quer, lado)
			pior = maxf(pior, absf(wrapf(tela.angle() - alvo.angle(), -PI, PI)))
	ok(rad_to_deg(pior) < 10.0, "%s: o miolo do corte cai na direção pedida nas 16 direções e nos dois lados (pior erro %.1f graus)" % [nome, rad_to_deg(pior)])


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

	# a folha ciano é desenhada numa grade 2x2: as giradas também têm de ser (nada de pixel de 1 px misturado)
	for arq in FOLHAS_R_CIANO:
		var im: Image = load(arq).get_image()
		var puro := true
		for y in range(0, im.get_height(), 2):
			for x in range(0, im.get_width(), 2):
				var c := im.get_pixel(x, y)
				for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var o := im.get_pixel(x + d.x, y + d.y)
					if o.a != c.a or (c.a > 0.0 and o != c):  # o RGB de pixel transparente não conta (o importador mexe nele)
						puro = false
		ok(puro, "%s: grade 2x2 pura" % arq)


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
