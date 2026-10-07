extends Node2D
## Piloto de desempenho do port para PS Vita. Ao abrir, roda sozinho uma RAMPA de medição (herói andando em círculo,
## horda real com lógica, golpe automático, sangue, luz), grava um CSV e mostra a tabela na tela. Depois vira modo livre.
##
## Controles (Vita / teclado):
##   analógico esq. / setas ........ mover            cima/baixo no D-pad / PgUp PgDn .. +-50 inimigos
##   Triângulo / 1 ................. modo de luz      Quadrado / 2 ..... atlas liga/desliga
##   Círculo / 3 ................... ordem por Y      L / 4 ............ 480x272 <-> 640x360
##   R / 5 ......................... governador       Start / Enter .... refaz a rampa
## O índice do último botão do controle aparece no HUD (para conferir o mapa do Vita no aparelho).

const Horda := preload("res://horda.gd")
const Luz := preload("res://luz.gd")
const Tipos := preload("res://tipos.gd")

const RESOLUCOES = [Vector2(480, 272), Vector2(640, 360)]
const NOMES_LUZ = ["SEM", "BUFFER", "SHADER"]
const QUANTIDADES = [50, 100, 200, 300, 450, 600]
const ARQ_USER = "user://piloto_bench.csv"
const ARQ_VITA = "ux0:data/kikiu_piloto.csv"

var horda: Horda
var luz: Luz
var cam = Camera2D.new()
var chao = Node2D.new()
var marcas = Node2D.new()
var heroi = Node2D.new()
var hud = Label.new()
var tex_chao: ImageTexture
var tex_heroi: Texture

var res = 0
var base = Vector2(480, 272)
var heroi_pos = Vector2.ZERO
var heroi_fase = 0.0
var heroi_vira = false
var golpe_t = 0.0
var golpe_vis = 0.0
var sangue = []            # [Vector2] anel de no máximo SANGUE_MAX
var sangue_i = 0
const SANGUE_MAX = 96
var tochas = []
var idx_fogo = -1
var governador = false
var ultimo_botao = -1

# rampa
var passos = []
var passo = -1
var passo_t = 0.0
var aquece = 1.5
var mede = 4.0
var rapido = false
var med = {}
var resultados = []
var resumo = ""

# HUD
var hud_t = 0.0
var q_n = 0
var q_us = 0
var q_pior = 0
var q_t0 = 0
var fps_q = 0.0
var ms_medio = 0.0
var ms_pior = 0.0
var us_quadro_ant = 0


func _ready() -> void:
	randomize()
	rapido = Array(OS.get_cmdline_args()).has("--bench-rapido")
	if rapido:
		aquece = 0.3
		mede = 0.7
	tex_chao = ImageTexture.new()
	tex_chao.create_from_image(load("res://sprites/chao.png").get_data(), Texture.FLAG_REPEAT)
	tex_heroi = load("res://sprites/heroi.png")
	chao.connect("draw", self, "_desenha_chao")
	marcas.connect("draw", self, "_desenha_marcas")
	heroi.connect("draw", self, "_desenha_heroi")
	add_child(chao)
	add_child(marcas)
	horda = Horda.new()
	horda.carregar(Tipos.LISTA)
	add_child(horda)
	add_child(heroi)
	cam.current = true
	add_child(cam)
	luz = Luz.new()
	add_child(luz)
	var camada = CanvasLayer.new()
	camada.layer = 10
	add_child(camada)
	hud.add_color_override("font_color", Color(1, 1, 0.8))
	hud.add_color_override("font_color_shadow", Color(0, 0, 0))
	hud.add_constant_override("shadow_as_outline", 1)
	hud.rect_position = Vector2(4, 2)
	camada.add_child(hud)
	for i in Tipos.LISTA.size():
		if Tipos.LISTA[i].id == "fogo_fatuo":
			idx_fogo = i
	for i in 40:
		tochas.append(Vector2(rand_range(-900, 900), rand_range(-900, 900)))
	_montar_passos()
	_iniciar_rampa()


func _montar_passos() -> void:
	passos.clear()
	for l in [0, 1, 2]:
		for n in QUANTIDADES:
			passos.append({"n": n, "luz": l, "atlas": true, "ysort": true, "res": 0})
	passos.append({"n": 300, "luz": 1, "atlas": false, "ysort": true, "res": 0})
	passos.append({"n": 300, "luz": 1, "atlas": true, "ysort": false, "res": 0})
	passos.append({"n": 300, "luz": 1, "atlas": true, "ysort": true, "res": 1})
	passos.append({"n": 300, "luz": 2, "atlas": true, "ysort": true, "res": 1})


func _iniciar_rampa() -> void:
	resultados.clear()
	resumo = ""
	governador = false
	passo = -1
	_proximo_passo()


func _proximo_passo() -> void:
	passo += 1
	passo_t = 0.0
	med = {"q": 0, "us": 0, "pior": 0, "log": 0, "des": 0, "dc": 0, "perto": 0, "desen": 0, "t0": 0}
	if passo >= passos.size():
		_fim_rampa()
		return
	var p: Dictionary = passos[passo]
	_aplicar_res(p.res)
	luz.definir_modo(p.luz)
	horda.usar_atlas = p.atlas
	horda.ordenar_y = p.ysort
	horda.lod_longe = 4
	horda.max_desenho = 2000
	horda.definir_quantidade(p.n)


func _aplicar_res(r: int) -> void:
	if r == res and base == RESOLUCOES[r]:
		return
	res = r
	base = RESOLUCOES[r]
	get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT, SceneTree.STRETCH_ASPECT_KEEP, base)
	luz.definir_base(base)


func _fim_rampa() -> void:
	passo = -1
	var csv = "passo,n,luz,atlas,ysort,res,fps,quadro_ms,pior_ms,logica_ms,desenho_ms,draw_calls,perto,desenhados,mem_mb\n"
	for r in resultados:
		csv += r.csv + "\n"
	var salvos = []
	for caminho in [ARQ_USER, ARQ_VITA]:
		if caminho == ARQ_VITA and not OS.has_feature("Vita"):
			continue
		var f = File.new()
		if f.open(caminho, File.WRITE) == OK:
			f.store_string(csv)
			f.close()
			salvos.append(ProjectSettings.globalize_path(caminho))
	# tabela: fps por modo de luz x quantidade
	resumo = "RAMPA COMPLETA (fps medio | pior quadro ms)\n        "
	for n in QUANTIDADES:
		resumo += "%6d" % n
	resumo += "\n"
	for l in 3:
		resumo += "%-8s" % NOMES_LUZ[l]
		for n in QUANTIDADES:
			for r in resultados:
				if r.luz == l and r.n == n and r.atlas and r.ysort and r.res == 0:
					resumo += "%6.0f" % r.fps
		resumo += "\n"
	for r in resultados.slice(18, resultados.size() - 1):
		resumo += "300 luz=%s atlas=%s ysort=%s %dx%d: %.0f fps\n" % [NOMES_LUZ[r.luz], "S" if r.atlas else "N",
			"S" if r.ysort else "N", RESOLUCOES[r.res].x, RESOLUCOES[r.res].y, r.fps]
	resumo += "CSV: " + PoolStringArray(salvos).join("  ")
	if rapido:
		print(csv)
		print(resumo)
		get_tree().quit()
		return
	# modo livre
	_aplicar_res(0)
	luz.definir_modo(1)
	horda.usar_atlas = true
	horda.ordenar_y = true
	horda.definir_quantidade(300)
	governador = true


func _process(dt: float) -> void:
	var agora = OS.get_ticks_usec()
	var us_quadro = agora - us_quadro_ant if us_quadro_ant > 0 else 16667
	us_quadro_ant = agora
	_mover_heroi(dt)
	horda.alvo = heroi_pos
	horda.visivel = Rect2(heroi_pos - base * 0.5, base)
	horda.atualizar(dt)
	_golpear(dt)
	cam.position = heroi_pos
	_montar_luzes()
	luz.atualizar()
	chao.update()
	marcas.update()
	horda.update()
	heroi.update()
	_medir(dt, us_quadro)
	if governador:
		_governar(dt)
	_hud(dt, us_quadro)


func _mover_heroi(dt: float) -> void:
	var v = Vector2.ZERO
	if passo >= 0:
		var ang = OS.get_ticks_msec() * 0.0005
		var alvo = Vector2(cos(ang), sin(ang)) * 150.0
		v = (alvo - heroi_pos) / max(dt, 0.001)
		v = v.limit_length(90.0)
	else:
		v = Vector2(Input.get_joy_axis(0, JOY_AXIS_0), Input.get_joy_axis(0, JOY_AXIS_1))
		if v.length() < 0.2:
			v = Vector2.ZERO
		if Input.is_key_pressed(KEY_LEFT): v.x -= 1
		if Input.is_key_pressed(KEY_RIGHT): v.x += 1
		if Input.is_key_pressed(KEY_UP): v.y -= 1
		if Input.is_key_pressed(KEY_DOWN): v.y += 1
		v = v.limit_length(1.0) * 90.0
	heroi_pos += v * dt
	if v.length() > 5.0:
		heroi_fase += dt
		heroi_vira = v.x < 0.0


func _golpear(dt: float) -> void:
	golpe_t -= dt
	golpe_vis = max(golpe_vis - dt, 0.0)
	if golpe_t > 0.0:
		return
	golpe_t = 0.45
	golpe_vis = 0.12
	for p in horda.golpe(heroi_pos, 46.0):
		if sangue.size() < SANGUE_MAX:
			sangue.append(p)
		else:
			sangue[sangue_i] = p
			sangue_i = (sangue_i + 1) % SANGUE_MAX


func _montar_luzes() -> void:
	var l = []
	var top = heroi_pos - base * 0.5
	l.append([base * 0.5, 120.0, Color(1.0, 0.85, 0.6)])
	var area = Rect2(top, base).grow(80.0)
	for t in tochas:
		if area.has_point(t):
			l.append([t - top, 80.0, Color(1.0, 0.55, 0.2)])
	if idx_fogo >= 0:
		var vis = Rect2(top, base)
		var achados = 0
		for i in horda.pos.size():
			if horda.tp[i] == idx_fogo and vis.has_point(horda.pos[i]):
				l.append([horda.pos[i] - top, 40.0, Color(0.3, 0.6, 1.0)])
				achados += 1
				if achados >= 10:
					break
	luz.luzes = l


func _medir(dt: float, us_quadro: int) -> void:
	q_n += 1
	q_us += us_quadro
	q_pior = max(q_pior, us_quadro)
	if passo < 0:
		return
	passo_t += dt
	if passo_t < aquece:
		return
	if med.q == 0:
		med.t0 = OS.get_ticks_usec()
	med.q += 1
	med.us += us_quadro
	med.pior = max(med.pior, us_quadro)
	med.log += horda.us_logica
	med.des += horda.us_desenho
	med.dc += Performance.get_monitor(Performance.RENDER_2D_DRAW_CALLS_IN_FRAME)
	med.perto += horda.n_perto
	med.desen += horda.n_desenhados
	if passo_t >= aquece + mede:
		var p: Dictionary = passos[passo]
		var q = float(max(med.q, 1))
		var seg = (OS.get_ticks_usec() - med.t0) / 1000000.0
		var r = {"n": p.n, "luz": p.luz, "atlas": p.atlas, "ysort": p.ysort, "res": p.res,
			"fps": (med.q - 1) / max(seg, 0.001)}
		r.csv = "%d,%d,%s,%d,%d,%dx%d,%.1f,%.2f,%.2f,%.2f,%.2f,%.0f,%.0f,%.0f,%.1f" % [passo + 1, p.n, NOMES_LUZ[p.luz],
			int(p.atlas), int(p.ysort), RESOLUCOES[p.res].x, RESOLUCOES[p.res].y, r.fps, med.us / q / 1000.0,
			med.pior / 1000.0, med.log / q / 1000.0, med.des / q / 1000.0, med.dc / q, med.perto / q, med.desen / q,
			OS.get_static_memory_usage() / 1048576.0]
		resultados.append(r)
		if rapido and p.n == 300:     # foto da tela pra conferir o visual no PC (user://foto_passoN.png)
			var img: Image = get_viewport().get_texture().get_data()
			img.flip_y()
			img.save_png("user://foto_passo%d.png" % (passo + 1))
		_proximo_passo()


## Governador (modo livre): mira 30 fps estáveis. Abaixo de 29, corta o desenho e espaça a lógica dos distantes;
## acima de 50 com folga, devolve aos poucos.
var _gov_t = 0.0
func _governar(dt: float) -> void:
	_gov_t += dt
	if _gov_t < 0.5:
		return
	_gov_t = 0.0
	if fps_q > 0.0 and fps_q < 29.0:
		horda.max_desenho = int(max(60, horda.max_desenho * 0.85))
		horda.lod_longe = int(min(8, horda.lod_longe + 1))
	elif fps_q > 50.0:
		horda.max_desenho = int(min(2000, horda.max_desenho + 20))
		if horda.lod_longe > 2:
			horda.lod_longe -= 1


func _hud(dt: float, _us_quadro: int) -> void:
	hud_t += dt
	if hud_t < 0.25:
		return
	var seg = hud_t
	hud_t = 0.0
	fps_q = q_n / seg
	ms_medio = q_us / float(max(q_n, 1)) / 1000.0
	ms_pior = q_pior / 1000.0
	q_n = 0
	q_us = 0
	q_pior = 0
	var s = "FPS %.0f  quadro %.1fms (pior %.1f)  mem %.0fMB\n" % [fps_q, ms_medio, ms_pior,
		OS.get_static_memory_usage() / 1048576.0]
	s += "N %d  perto %d  desenha %d/%d  lod %d  dc %d\n" % [horda.pos.size(), horda.n_perto, horda.n_desenhados,
		horda.max_desenho, horda.lod_longe, Performance.get_monitor(Performance.RENDER_2D_DRAW_CALLS_IN_FRAME)]
	s += "logica %.1fms  desenho %.1fms  luz %s  atlas %s  ysort %s  %dx%d\n" % [horda.us_logica / 1000.0,
		horda.us_desenho / 1000.0, NOMES_LUZ[luz.modo], "S" if horda.usar_atlas else "N",
		"S" if horda.ordenar_y else "N", base.x, base.y]
	if passo >= 0:
		s += "RAMPA passo %d/%d  (Start refaz)\n" % [passo + 1, passos.size()]
	else:
		s += "LIVRE  governador %s  botao %d\n" % ["S" if governador else "N", ultimo_botao]
		s += resumo
	hud.text = s


func _input(e: InputEvent) -> void:
	var cmd = ""
	if e is InputEventJoypadButton and e.pressed:
		ultimo_botao = e.button_index
		match e.button_index:
			3: cmd = "luz"
			2: cmd = "atlas"
			1: cmd = "ysort"
			6: cmd = "res"
			7: cmd = "gov"
			11: cmd = "rampa"
			12: cmd = "mais"
			13: cmd = "menos"
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.scancode:
			KEY_1: cmd = "luz"
			KEY_2: cmd = "atlas"
			KEY_3: cmd = "ysort"
			KEY_4: cmd = "res"
			KEY_5: cmd = "gov"
			KEY_ENTER: cmd = "rampa"
			KEY_PAGEUP: cmd = "mais"
			KEY_PAGEDOWN: cmd = "menos"
	if cmd == "rampa":
		_iniciar_rampa()
		return
	if cmd == "" or passo >= 0:
		return
	match cmd:
		"luz": luz.definir_modo((luz.modo + 1) % 3)
		"atlas": horda.usar_atlas = not horda.usar_atlas
		"ysort": horda.ordenar_y = not horda.ordenar_y
		"res": _aplicar_res((res + 1) % 2)
		"gov": governador = not governador
		"mais": horda.definir_quantidade(horda.pos.size() + 50)
		"menos": horda.definir_quantidade(int(max(0, horda.pos.size() - 50)))


func _desenha_chao() -> void:
	var top = heroi_pos - base * 0.5
	var ini = (top / 128.0).floor() * 128.0
	chao.draw_texture_rect(tex_chao, Rect2(ini, base + Vector2(256, 256)), true, Color(0.75, 0.72, 0.68))


func _desenha_marcas() -> void:
	var tex: Texture = horda.tex_atlas if horda.usar_atlas else horda.tex_sangue
	var src = horda.src_sangue if horda.usar_atlas else Rect2(Vector2.ZERO, horda.src_sangue.size)
	for p in sangue:
		marcas.draw_texture_rect_region(tex, Rect2(p - src.size * 0.5, src.size), src)


func _desenha_heroi() -> void:
	var q = Vector2(44, 60)
	var col = int(heroi_fase * 8.0) % 9
	var dst = Rect2(heroi_pos.x - q.x * 0.5, heroi_pos.y - q.y + 4.0, q.x, q.y)
	if heroi_vira:
		dst.position.x += q.x
		dst.size.x = -q.x
	heroi.draw_texture_rect_region(tex_heroi, dst, Rect2(Vector2(col * q.x, 0), q))
	if golpe_vis > 0.0:
		heroi.draw_arc(heroi_pos + Vector2(0, -14), 46.0, 0.0, TAU, 24, Color(1, 1, 1, golpe_vis * 5.0), 2.0)
