extends Node2D
## Piloto de desempenho do port para PS Vita (v3). Ao abrir, roda sozinho uma RAMPA de medição (herói andando em
## círculo, horda com lógica, golpe automático, projéteis, sangue, luz, som espacial), grava um CSV e mostra a
## tabela na tela. Depois vira modo livre com governador e os controles do Vita.
##
## v3: a horda roda no módulo C++ HordaVita quando o template próprio está presente (motor "C++"); no editor do PC
## cai na horda em GDScript (motor "GD"). Usa o hardware do Vita pelo VitaHW (mesmo módulo): touch frontal e traseiro,
## acelerômetro, clocks e bateria.
##
## Controles no modo livre:
##   analógico esq. / setas ........ mover          touch frontal, metade ESQUERDA .. stick virtual (arraste)
##   touch frontal, metade DIREITA .. especial (golpe grande)      touch TRASEIRO ... rolamento (dash)
##   Select / 6 ..................... câmera que inclina com o Vita (acelerômetro) liga/desliga
##   Triângulo / 1 .. modo de luz   Quadrado / 2 .. projéteis   Círculo / 3 .. som liga/desliga
##   L / 4 .. 480x272 <-> 640x360   R / 5 .. governador   Start / Enter .. refaz a rampa   cima/baixo .. +-50 inimigos

const HordaGD = preload("res://horda.gd")
const HordaNativa = preload("res://horda_nativa.gd")
const Luz = preload("res://luz.gd")
const Som = preload("res://som.gd")
const Tipos = preload("res://tipos.gd")

const VERSAO = 3
const RESOLUCOES = [Vector2(480, 272), Vector2(640, 360)]
const NOMES_LUZ = ["SEM", "BUFFER", "SHADER"]
const QUANTIDADES = [100, 200, 300, 400, 500, 650, 800]
const ARQ_USER = "user://piloto_bench.csv"
const ARQ_VITA = "ux0:data/kikiu_piloto.csv"
const SANGUE_MAX = 96
const TIRO_CADA = 0.2
const TIROS_POR_VEZ = 4

var horda
var motor = "GD"
var hw = null                 # VitaHW (só no template próprio)
var luz: Luz
var som: Som
var cam = Camera2D.new()
var chao = Node2D.new()
var marcas = Node2D.new()
var heroi = Node2D.new()
var marcas_toque = Node2D.new()
var hud = Label.new()
var tex_chao: ImageTexture
var tex_heroi: Texture

var res = 0
var base = Vector2(480, 272)
var heroi_pos = Vector2.ZERO
var heroi_dir = Vector2.RIGHT
var heroi_fase = 0.0
var heroi_vira = false
var golpe_t = 0.0
var golpe_vis = 0.0
var tiro_t = 0.0
var tiro_ang = 0.0
var grunhido_t = 0.0
var projeteis = true
var sangue = []
var sangue_i = 0
var chao_ini = Vector2.INF
var tochas = []
var governador = false
var ultimo_botao = -1

# hardware / toque
var toques_f = PoolVector2Array()
var toques_t = PoolVector2Array()
var stick_origem = null
var stick = Vector2.ZERO
var especial_antes = false
var tras_antes = false
var especial_t = 0.0
var rola_t = 0.0
var rola_cd = 0.0
var clarao = 0.0
var inclina = false
var acel = Vector3.ZERO
var info_hw = ""
var info_hw_t = 0.0
var arm_mhz = 0

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

# HUD / medição
var hud_t = 0.0
var q_n = 0
var q_us = 0
var q_pior = 0
var fps_q = 0.0
var us_quadro_ant = 0
var us_main = 0
var _gov_t = 0.0


func _ready() -> void:
	randomize()
	rapido = Array(OS.get_cmdline_args()).has("--bench-rapido")
	if rapido:
		aquece = 0.3
		mede = 0.7
	if ClassDB.class_exists("VitaHW"):
		hw = ClassDB.instance("VitaHW")
		if hw.no_vita():
			hw.iniciar()
		else:
			hw = null                     # módulo compilado fora do Vita (build Linux de teste): sem hardware
	tex_chao = ImageTexture.new()
	tex_chao.create_from_image(load("res://sprites/chao.png").get_data(), Texture.FLAG_REPEAT)
	tex_heroi = load("res://sprites/heroi.png")
	chao.connect("draw", self, "_desenha_chao")
	marcas.connect("draw", self, "_desenha_marcas")
	heroi.connect("draw", self, "_desenha_heroi")
	marcas_toque.connect("draw", self, "_desenha_toques")
	add_child(chao)
	add_child(marcas)
	if HordaNativa.disponivel() and not Array(OS.get_cmdline_args()).has("--horda-gd"):
		horda = HordaNativa.new()
		motor = "C++"
	else:
		horda = HordaGD.new()
	horda.carregar(Tipos.LISTA, "proj_adaga.png")
	add_child(horda)
	add_child(heroi)
	cam.current = true
	add_child(cam)
	luz = Luz.new()
	add_child(luz)
	som = Som.new()
	add_child(som)
	var camada = CanvasLayer.new()
	camada.layer = 10
	add_child(camada)
	camada.add_child(marcas_toque)
	hud.add_color_override("font_color", Color(1, 1, 0.8))
	hud.add_color_override("font_color_shadow", Color(0, 0, 0))
	hud.add_constant_override("shadow_as_outline", 1)
	hud.rect_position = Vector2(4, 2)
	camada.add_child(hud)
	for i in 40:
		tochas.append(Vector2(rand_range(-900, 900), rand_range(-900, 900)))
	_montar_passos()
	_iniciar_rampa()


func _montar_passos() -> void:
	passos.clear()
	for l in [0, 1]:
		for n in QUANTIDADES:
			passos.append({"n": n, "luz": l, "proj": true, "som": true, "res": 0})
	passos.append({"n": 300, "luz": 2, "proj": true, "som": true, "res": 0})
	passos.append({"n": 300, "luz": 1, "proj": true, "som": false, "res": 0})
	passos.append({"n": 300, "luz": 1, "proj": true, "som": true, "res": 1})
	passos.append({"n": 500, "luz": 1, "proj": true, "som": true, "res": 1})


func _iniciar_rampa() -> void:
	resultados.clear()
	resumo = ""
	governador = false
	passo = -1
	_proximo_passo()


func _proximo_passo() -> void:
	passo += 1
	passo_t = 0.0
	med = {"q": 0, "us": 0, "pior": 0, "log": 0, "des": 0, "prj": 0, "main": 0, "np": 0, "dc": 0, "perto": 0,
		"desen": 0, "t0": 0}
	if passo >= passos.size():
		_fim_rampa()
		return
	var p: Dictionary = passos[passo]
	_aplicar_res(p.res)
	luz.definir_modo(p.luz)
	projeteis = p.proj
	som.definir(p.som)
	horda.ordenar_y = true
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
	chao_ini = Vector2.INF


func _fim_rampa() -> void:
	passo = -1
	var csv = "versao,motor,passo,n,luz,proj,som,res,fps,quadro_ms,pior_ms,logica_ms,desenho_ms,proj_ms,main_ms,n_proj,draw_calls,perto,desenhados,arm_mhz\n"
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
	resumo = "RAMPA v%d (%s) COMPLETA: fps medio\n        " % [VERSAO, motor]
	for n in QUANTIDADES:
		resumo += "%5d" % n
	resumo += "\n"
	for l in 2:
		resumo += "%-8s" % NOMES_LUZ[l]
		for n in QUANTIDADES:
			for r in resultados:
				if r.luz == l and r.n == n and r.som and r.res == 0:
					resumo += "%5.0f" % r.fps
		resumo += "\n"
	for r in resultados.slice(QUANTIDADES.size() * 2, resultados.size() - 1):
		resumo += "%d luz=%s som=%s %dx%d: %.0f fps\n" % [r.n, NOMES_LUZ[r.luz], "S" if r.som else "N",
			RESOLUCOES[r.res].x, RESOLUCOES[r.res].y, r.fps]
	resumo += "CSV: " + PoolStringArray(salvos).join("  ")
	if rapido:
		print(csv)
		print(resumo)
		get_tree().quit()
		return
	_aplicar_res(0)
	luz.definir_modo(1)
	projeteis = true
	som.definir(true)
	horda.definir_quantidade(300)
	governador = true


func _process(dt: float) -> void:
	var agora = OS.get_ticks_usec()
	var us_quadro = agora - us_quadro_ant if us_quadro_ant > 0 else 16667
	us_quadro_ant = agora
	_ler_hardware(dt)
	_mover_heroi(dt)
	horda.alvo = heroi_pos
	horda.visivel = Rect2(heroi_pos - base * 0.5, base)
	horda.atualizar(dt)
	_golpear(dt)
	_atirar(dt)
	_grunhir(dt)
	cam.position = heroi_pos
	if inclina:
		cam.offset = cam.offset.linear_interpolate(Vector2(acel.y, acel.x) * 28.0, 0.15)
	elif cam.offset != Vector2.ZERO:
		cam.offset = cam.offset.linear_interpolate(Vector2.ZERO, 0.2)
	_montar_luzes()
	luz.atualizar()
	var ini = ((heroi_pos - base * 0.5) / 128.0).floor() * 128.0
	if ini != chao_ini:
		chao_ini = ini
		chao.update()
	horda.update()
	heroi.update()
	us_main = OS.get_ticks_usec() - agora
	_medir(dt, us_quadro)
	if governador:
		_governar(dt)
	_hud(dt)


## Touch frontal e traseiro, acelerômetro (pelo VitaHW) e, a cada 2 s, clocks e bateria.
func _ler_hardware(dt: float) -> void:
	especial_t = max(especial_t - dt, 0.0)
	rola_cd = max(rola_cd - dt, 0.0)
	rola_t = max(rola_t - dt, 0.0)
	if clarao > 0.0:
		clarao = max(clarao - dt * 3.0, 0.0)
		marcas_toque.update()
	if hw == null:
		return
	info_hw_t -= dt
	if info_hw_t <= 0.0:
		info_hw_t = 2.0
		var c: Dictionary = hw.clocks()
		var b: Dictionary = hw.bateria()
		arm_mhz = c.arm
		info_hw = "CPU %d bus %d GPU %d/%d MHz  bateria %d%%%s" % [c.arm, c.bus, c.gpu, c.xbar, b.porcento,
			" carregando" if b.carregando else ""]
	var tinha = toques_f.size() + toques_t.size() > 0
	toques_f = hw.toques_frente()
	toques_t = hw.toques_tras()
	if tinha or toques_f.size() + toques_t.size() > 0:
		marcas_toque.update()
	if inclina:
		acel = hw.movimento().acel
	if passo >= 0:
		return                          # a rampa não lê controles
	# frente: metade esquerda = stick virtual; metade direita = especial (ao encostar)
	var esq = false
	var dir = false
	for t in toques_f:
		var s: Vector2 = t * base
		if t.x < 0.5:
			esq = true
			if stick_origem == null:
				stick_origem = s
			stick = ((s - stick_origem) / 40.0).limit_length(1.0)
		else:
			dir = true
	if not esq:
		stick_origem = null
		stick = Vector2.ZERO
	if dir and not especial_antes and especial_t <= 0.0:
		_especial()
	especial_antes = dir
	# trás: rolamento ao encostar
	var tras = toques_t.size() > 0
	if tras and not tras_antes and rola_cd <= 0.0:
		rola_t = 0.22
		rola_cd = 0.7
		if heroi_dir == Vector2.ZERO:
			heroi_dir = Vector2.LEFT if toques_t[0].x < 0.5 else Vector2.RIGHT
		som.tocar("whoosh", heroi_pos, -2.0)
	tras_antes = tras


func _especial() -> void:
	especial_t = 1.0
	clarao = 1.0
	_sangrar(horda.golpe(heroi_pos, 90.0))
	som.tocar("tremor", heroi_pos, 0.0)


func _mover_heroi(dt: float) -> void:
	var v = Vector2.ZERO
	if passo >= 0:
		var ang = OS.get_ticks_msec() * 0.0005
		var alvo = Vector2(cos(ang), sin(ang)) * 150.0
		v = ((alvo - heroi_pos) / max(dt, 0.001)).limit_length(90.0)
	else:
		v = Vector2(Input.get_joy_axis(0, JOY_AXIS_0), Input.get_joy_axis(0, JOY_AXIS_1))
		if v.length() < 0.2:
			v = Vector2.ZERO
		v += stick
		if Input.is_key_pressed(KEY_LEFT): v.x -= 1
		if Input.is_key_pressed(KEY_RIGHT): v.x += 1
		if Input.is_key_pressed(KEY_UP): v.y -= 1
		if Input.is_key_pressed(KEY_DOWN): v.y += 1
		v = v.limit_length(1.0) * 90.0
		if v.length() > 5.0:
			heroi_dir = v.normalized()
		if rola_t > 0.0:
			v = heroi_dir * 300.0
	heroi_pos += v * dt
	if v.length() > 5.0:
		heroi_fase += dt
		heroi_vira = v.x < 0.0


func _sangrar(mortes: Array) -> void:
	if mortes.empty():
		return
	som.tocar("acerto", mortes[0], -3.0)
	for p in mortes:
		if sangue.size() < SANGUE_MAX:
			sangue.append(p)
		else:
			sangue[sangue_i] = p
			sangue_i = (sangue_i + 1) % SANGUE_MAX
	marcas.update()


func _golpear(dt: float) -> void:
	golpe_t -= dt
	golpe_vis = max(golpe_vis - dt, 0.0)
	if golpe_t > 0.0:
		return
	golpe_t = 0.45
	golpe_vis = 0.12
	_sangrar(horda.golpe(heroi_pos, 46.0))


func _atirar(dt: float) -> void:
	if projeteis:
		tiro_t -= dt
		if tiro_t <= 0.0:
			tiro_t = TIRO_CADA
			for k in TIROS_POR_VEZ:
				tiro_ang += TAU / TIROS_POR_VEZ + 0.37
				horda.disparar(heroi_pos, Vector2(240, 0).rotated(tiro_ang), 1.0)
	_sangrar(horda.atualizar_proj(dt))


## Grunhidos dos bichos vindos de lados variados (demonstra o pan estéreo: esquerda/direita, perto/longe).
func _grunhir(dt: float) -> void:
	grunhido_t -= dt
	if grunhido_t > 0.0:
		return
	grunhido_t = rand_range(0.5, 1.1)
	som.tocar("soco", heroi_pos + Vector2(rand_range(-260, 260), rand_range(-140, 140)), -6.0, 0.7)


func _montar_luzes() -> void:
	var l = []
	var top = heroi_pos - base * 0.5
	l.append([base * 0.5 - cam.offset, 120.0, Color(1.0, 0.85, 0.6)])
	var area = Rect2(top, base).grow(80.0)
	for t in tochas:
		if area.has_point(t):
			l.append([t - top - cam.offset, 80.0, Color(1.0, 0.55, 0.2)])
	for p in horda.luzes_visiveis(Rect2(top, base), 10):
		l.append([p - top - cam.offset, 40.0, Color(0.3, 0.6, 1.0)])
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
	med.prj += horda.us_proj
	med.main += us_main
	med.np += horda.n_proj
	med.dc += Performance.get_monitor(Performance.RENDER_2D_DRAW_CALLS_IN_FRAME)
	med.perto += horda.n_perto
	med.desen += horda.n_desenhados
	if passo_t >= aquece + mede:
		var p: Dictionary = passos[passo]
		var q = float(max(med.q, 1))
		var seg = (OS.get_ticks_usec() - med.t0) / 1000000.0
		var r = {"n": p.n, "luz": p.luz, "som": p.som, "res": p.res, "fps": (med.q - 1) / max(seg, 0.001)}
		r.csv = "%d,%s,%d,%d,%s,%d,%d,%dx%d,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.1f,%.0f,%.0f,%.0f,%d" % [VERSAO, motor,
			passo + 1, p.n, NOMES_LUZ[p.luz], int(p.proj), int(p.som), RESOLUCOES[p.res].x, RESOLUCOES[p.res].y,
			r.fps, med.us / q / 1000.0, med.pior / 1000.0, med.log / q / 1000.0, med.des / q / 1000.0,
			med.prj / q / 1000.0, med.main / q / 1000.0, med.np / q, med.dc / q, med.perto / q, med.desen / q, arm_mhz]
		resultados.append(r)
		if rapido and p.n == 300:     # foto da tela pra conferir o visual no PC (user://foto_passoN.png)
			var img: Image = get_viewport().get_texture().get_data()
			img.flip_y()
			img.save_png("user://foto_passo%d.png" % (passo + 1))
		_proximo_passo()


## Governador (modo livre): mira 40 fps. Abaixo de 38, corta o desenho e espaça a lógica dos distantes;
## acima de 55, devolve aos poucos.
func _governar(dt: float) -> void:
	_gov_t += dt
	if _gov_t < 0.5:
		return
	_gov_t = 0.0
	if fps_q > 0.0 and fps_q < 38.0:
		horda.max_desenho = int(max(60, horda.max_desenho * 0.85))
		horda.lod_longe = int(min(8, horda.lod_longe + 1))
	elif fps_q > 55.0:
		horda.max_desenho = int(min(2000, horda.max_desenho + 20))
		if horda.lod_longe > 2:
			horda.lod_longe -= 1


func _hud(dt: float) -> void:
	hud_t += dt
	if hud_t < 0.25:
		return
	var seg = hud_t
	hud_t = 0.0
	fps_q = q_n / seg
	var ms_medio = q_us / float(max(q_n, 1)) / 1000.0
	var ms_pior = q_pior / 1000.0
	q_n = 0
	q_us = 0
	q_pior = 0
	var s = "v%d %s  FPS %.0f  quadro %.1fms (pior %.1f)  main %.1fms\n" % [VERSAO, motor, fps_q, ms_medio, ms_pior,
		us_main / 1000.0]
	s += "N %d  perto %d  desenha %d/%d  lod %d  dc %d  tiros %d\n" % [horda.quantidade(), horda.n_perto,
		horda.n_desenhados, horda.max_desenho, horda.lod_longe,
		Performance.get_monitor(Performance.RENDER_2D_DRAW_CALLS_IN_FRAME), horda.n_proj]
	s += "logica %.2f  desenho %.2f  proj %.2f ms  luz %s  som %s  %dx%d\n" % [horda.us_logica / 1000.0,
		horda.us_desenho / 1000.0, horda.us_proj / 1000.0, NOMES_LUZ[luz.modo], "S" if som.ligado else "N",
		base.x, base.y]
	if info_hw != "":
		s += info_hw + "\n"
	if passo >= 0:
		s += "RAMPA passo %d/%d  (Start refaz)\n" % [passo + 1, passos.size()]
	else:
		s += "LIVRE  governador %s  inclina %s  botao %d  toque F%d T%d\n" % ["S" if governador else "N",
			"S" if inclina else "N", ultimo_botao, toques_f.size(), toques_t.size()]
		s += resumo
	hud.text = s


func _input(e: InputEvent) -> void:
	var cmd = ""
	if e is InputEventJoypadButton and e.pressed:
		ultimo_botao = e.button_index
		match e.button_index:
			3: cmd = "luz"
			2: cmd = "proj"
			1: cmd = "som"
			6: cmd = "res"
			7: cmd = "gov"
			10: cmd = "inclina"
			11: cmd = "rampa"
			12: cmd = "mais"
			13: cmd = "menos"
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.scancode:
			KEY_1: cmd = "luz"
			KEY_2: cmd = "proj"
			KEY_3: cmd = "som"
			KEY_4: cmd = "res"
			KEY_5: cmd = "gov"
			KEY_6: cmd = "inclina"
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
		"proj": projeteis = not projeteis
		"som": som.definir(not som.ligado)
		"res": _aplicar_res((res + 1) % 2)
		"gov": governador = not governador
		"inclina": inclina = not inclina
		"mais": horda.definir_quantidade(horda.quantidade() + 50)
		"menos": horda.definir_quantidade(int(max(0, horda.quantidade() - 50)))


func _desenha_chao() -> void:
	chao.draw_texture_rect(tex_chao, Rect2(chao_ini, base + Vector2(256, 256)), true, Color(0.75, 0.72, 0.68))


func _desenha_marcas() -> void:
	var src = horda.src_sangue
	for p in sangue:
		marcas.draw_texture_rect_region(horda.tex_atlas, Rect2(p - src.size * 0.5, src.size), src)


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
	if especial_t > 0.7:
		heroi.draw_arc(heroi_pos + Vector2(0, -14), 90.0 * (1.3 - especial_t), 0.0, TAU, 32, Color(1, 0.8, 0.4, 0.9), 3.0)


## Onde o jogador está tocando (frente: círculos brancos; trás: quadrados ciano, vistos de frente) e o clarão.
func _desenha_toques() -> void:
	for t in toques_f:
		marcas_toque.draw_circle(t * base, 10.0, Color(1, 1, 1, 0.35))
	for t in toques_t:
		marcas_toque.draw_rect(Rect2(t * base - Vector2(8, 8), Vector2(16, 16)), Color(0.3, 1, 1, 0.45))
	if stick_origem != null:
		marcas_toque.draw_arc(stick_origem, 40.0, 0.0, TAU, 24, Color(1, 1, 1, 0.3), 2.0)
	if clarao > 0.0:
		marcas_toque.draw_rect(Rect2(Vector2.ZERO, base), Color(1, 0.9, 0.7, clarao * 0.35))
