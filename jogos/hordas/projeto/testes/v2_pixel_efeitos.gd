extends "res://testes/isolamento_v2.gd"
# Efeitos e partículas na grade de 1 px (pixel art: um tamanho de pixel só). Prova que (1) nenhuma folha do pixelfx é registrada ou tocada em
# escala fracionária, (2) o fx_folha arredonda para inteiro o que ainda vier fracionário, (3) as partículas da atmosfera (vaga-lumes, folhas,
# detritos, fogo, faíscas) usam escala 1, formas de lado inteiro e nenhuma rotação em tempo de execução, (4) o `Efeitos` desenha o brilho das
# partículas em disco de pixel de lado inteiro. Falha no código antigo (escala 0,45..1,1; scale_amount 0,012..0,2; angular_velocity != 0).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pixel_efeitos.tscn  (imprime "v2_pixel_efeitos falhas=0")
const FxFolha := preload("res://v2/fx_folha.gd")
const Atmosfera := preload("res://v2/atmosfera.gd")
const Efeitos := preload("res://v2/efeitos.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _inteiro(x: float) -> bool:
	return is_equal_approx(x, roundf(x))


func _ready() -> void:
	# 1. o registro: toda escala é inteira e a folha cabe na textura
	var reg: Dictionary = Dados.json("v2_pixelfx").get("efeitos", {})
	ok(reg.size() >= 10, "registro do pixelfx lido (%d)" % reg.size())
	for id in reg:
		var e: Dictionary = reg[id]
		ok(_inteiro(float(e.get("escala", 1.0))), "pixelfx '%s': escala não inteira (%s)" % [id, e.get("escala")])
		var tex := load("res://assets/v2/pixelfx/" + str(e.arquivo)) as Texture2D
		ok(tex != null, "pixelfx '%s': folha existe" % id)
		if tex != null:
			var linhas := ceili(float(e.quadros) / float(e.colunas))
			ok(
				tex.get_width() >= int(e.colunas) * int(e.quadro[0]) and tex.get_height() >= linhas * int(e.quadro[1]),
				"pixelfx '%s': a folha tem o tamanho de quadro x colunas x linhas (%dx%d)" % [id, tex.get_width(), tex.get_height()]
			)
	for id in ["spawn-portal", "spawn-portal-mini", "spawn-portal-chefe", "soul-rise"]:
		ok(reg.has(id), "o registro tem '%s' (o chefe.gd e a elite escolhem o id, não a escala)" % id)

	# 2. nenhum chamador passa escala fracionária ao fx_folha
	for arq in DirAccess.get_files_at("res://v2"):
		if not arq.ends_with(".gd"):
			continue
		for linha in FileAccess.get_file_as_string("res://v2/" + arq).split("\n"):
			if (".tocar(" in linha or ".prender(" in linha) and "fx_folha" in linha and '"escala"' in linha:
				ok(false, "%s: fx_folha com opção escala (use outro id de folha): %s" % [arq, linha.strip_edges()])

	# 3. o fx_folha arredonda o que vier fracionário (nunca menos de 1)
	var camada := Node2D.new()
	add_child(camada)
	var fx := FxFolha.new()
	fx.montar(camada)
	var base := {"arquivo": "pickups/collect-burst.png", "quadro": [112, 108], "colunas": 7, "quadros": 6, "fps": 10, "pivo": [56, 94]}
	for par in [[0.45, 1.0], [0.8, 1.0], [1.3, 1.0], [2.0, 2.0], [2.4, 2.0]]:
		var d := base.duplicate()
		d["escala"] = par[0]
		fx.registrar("t_esc", d)
		ok(is_equal_approx(float(fx._defs[fx._ids["t_esc"]].escala), float(par[1])), "registro com escala %s vira %s" % [par[0], par[1]])
	fx.registrar("t_esc", base)
	fx.tocar("t_esc", Vector2.ZERO, {"escala": 0.7})
	ok(is_equal_approx(float(fx._esc[fx._modo.find(1)]), 1.0), "tocar com escala 0,7 desenha em 1")
	fx.limpar()

	# 4. atmosfera: escala 1, formas inteiras, sem rotação
	var glow := Node2D.new()
	add_child(glow)
	var atm := Atmosfera.new()
	atm.montar(glow)
	atm.config = {"detritos": {"n": 6, "tam": 1.3}, "vaga": {"n": 4, "tam": 1.5}, "folhas": {"n": 4, "tam": 1.5}}
	atm.fator_det = 1.0
	atm.ambiente(Vector2(480, 270))
	atm.fogo(Vector2(100, 100), 1.5)
	atm.faiscas(Color(1, 0.5, 0.2), Vector2(50, 50))
	var emissores: Array = []
	for c in glow.get_children():
		if c is CPUParticles2D:
			emissores.append(c)
	ok(emissores.size() == 7, "emissores criados (%d)" % emissores.size())
	for p in emissores:
		var pp := p as CPUParticles2D
		ok(
			is_equal_approx(pp.scale_amount_min, 1.0) and is_equal_approx(pp.scale_amount_max, 1.0),
			"emissor com escala fracionária (%s..%s)" % [pp.scale_amount_min, pp.scale_amount_max]
		)
		ok(pp.angular_velocity_min == 0.0 and pp.angular_velocity_max == 0.0, "emissor gira em tempo de execução")
		ok(pp.angle_min == 0.0 and pp.angle_max == 0.0, "emissor com ângulo inicial")
		var mat := pp.material as CanvasItemMaterial
		ok(mat != null and mat.particles_animation and mat.particles_anim_h_frames >= 1, "emissor sorteia a forma pela folha de formas")
		var tex := pp.texture as ImageTexture
		ok(tex != null and mat != null and tex.get_width() % maxi(mat.particles_anim_h_frames, 1) == 0, "textura do emissor é uma fileira de células inteiras")
		ok(pp.texture != atm.tex_brilho, "emissor não usa o brilho suave esticado")
	# a folha de formas é pixel: só alfa 0, 0,5 ou 1 (sem gradiente) e a forma cabe na célula
	var folha := Atmosfera.folha_formas([{"w": 5, "h": 5, "disco": true}, {"w": 3, "h": 2}])
	var im := folha.get_image()
	ok(im.get_width() == 10 and im.get_height() == 5, "folha de formas: células do tamanho da maior (%dx%d)" % [im.get_width(), im.get_height()])
	var so_degraus := true
	for y in im.get_height():
		for x in im.get_width():
			var a := im.get_pixel(x, y).a
			if not (is_zero_approx(a) or absf(a - 0.5) < 0.01 or is_equal_approx(a, 1.0)):
				so_degraus = false
	ok(so_degraus, "folha de formas sem gradiente (alfa em degraus)")
	ok(Atmosfera.px(0.3) == 1 and Atmosfera.px(3.0, 1.5) == 5, "px() devolve inteiro de no mínimo 1")

	# 5. Efeitos: o brilho das partículas é um disco de pixel de lado inteiro
	var ef := Efeitos.new()
	var d1: Texture2D = ef._disco_pixel(9)
	ok(d1.get_width() == 9 and d1.get_height() == 9, "disco de pixel de 9 px (%dx%d)" % [d1.get_width(), d1.get_height()])
	ok(ef._disco_pixel(9) == d1, "disco de pixel em cache por lado")
	print("v2_pixel_efeitos falhas=", falhas)
	get_tree().quit(1 if falhas else 0)
