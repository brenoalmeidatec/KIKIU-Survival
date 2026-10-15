extends SceneTree

var w
var output := ""
const ANTIGOS := ["laminas", "aura_fogo", "corvos", "raio", "runa"]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			output = a.trim_prefix("--saida=")
	if output.is_empty():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	AudioServer.set_bus_mute(0, true)
	var meta = load("res://v2/meta.gd")
	meta.caminho_save = "user://qa251_visual_%s.cfg" % Time.get_ticks_usec()
	root.get_node("Config").g_perfil_temporario("medio")
	seed(209)
	w = load("res://v2/mundo.tscn").instantiate()
	w.modo_teste = true
	w.id_mapa = "floresta"
	root.size = Vector2i(960, 540)
	root.add_child(w)
	w.set_process(false)
	await process_frame
	var grupos := {
		"antigos": ANTIGOS,
		"evolucoes_antigas": ["anel_de_brasas", "revoada_de_trovoes", "circulo_runico", "ventania"],
		"evolucoes_projeteis":
		[
			"urso_solar",
			"chuva_de_lacas",
			"bola_incendiaria",
			"pedreira_ardente",
			"cometa_duplo",
			"chuva_de_ferro",
			"eclipse_negro",
			"tempestade_primordial",
			"juizo_final"
		],
		"evolucoes_aliados": ["dragao_de_brasa", "cacada_espiritual", "exercito_esquecido", "colosso_de_pedra", "eclipse_de_almas"],
		"evolucoes_areas": ["nevasca_congelante", "cinzas_acidas", "estrondo", "terra_partida", "peste_negra", "juramento_sagrado", "furacao_glacial"]
	}
	for nome in grupos:
		await reset()
		for id in grupos[nome]:
			if id in ANTIGOS:
				w.combate.armas.definir_golpe(str(id), 1, 0.0)
			else:
				for ev in w.combate.cartas.cfg.evolucoes:
					if str(ev.id) != str(id):
						continue
					if str(id) == "ventania":
						w.combate.armas.definir_evolucao_katana(ev)
					else:
						w.combate.armas.adicionar_evoluida(ev, 0.0)
		await steps(110)
		if nome == "evolucoes_antigas":
			w.combate.armas.lancar_onda(w.heroi.pos, Vector2.RIGHT, 20.0)
			w.combate.armas.lancar_lanca(w.heroi.pos, Vector2.LEFT, 20.0)
			await steps(8)
		await shot(str(nome))
	print("QA251_VISUAL falhas=0")
	quit()


func reset() -> void:
	seed(209)
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.combate.audio.mudo = true
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.correr_forcado = null
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	w.combate.cartas.rng.seed = 12345
	await steps(3)
	for i in 24:
		var a := TAU * i / 24.0
		var r := 130.0 + 40.0 * (i % 3)
		var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(cos(a) * r, sin(a) * r * 0.62))
		m.vida_max = 100000.0
		m.vida = m.vida_max
		m.atordoa_t = 5.0
		m.cacador = false
		m.raio_vaga = 0.0


func projectile(id: String, pos: Vector2, dir: Vector2) -> void:
	w.combate.armas.definir_golpe(id, 1, 0.0)
	var a: Dictionary = w.combate.armas.ativas[id]
	var it: Dictionary = w.combate.armas.novas._novo("projetil", a, pos, 3.0)
	it.v = dir * 200.0


func steps(n: int) -> void:
	for i in n:
		w.avancar(1.0 / 60.0)
		await process_frame


func shot(name: String) -> void:
	w.combate.armas.no_corpo.queue_redraw()
	w.combate.armas.no_nevoa.queue_redraw()
	w.combate.armas.no_brilho.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = w.sv.get_texture().get_image()
	img.save_png(output.path_join(name + ".png"))
	print("CAPTURE ", name, " ", img.get_size())
