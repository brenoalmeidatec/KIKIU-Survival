extends SceneTree
## Fotos do crescimento por nível (v2/progresso.gd bonus_por_nivel): o golpe do Hazaki e do Nicão e o escudo, no nível 1 e no nível 20, no jogo real.
## Três monstros invencíveis na frente do herói, parados até o acerto, em -40, 0 e +40 graus: o primeiro dentro do alcance do nível 1, o segundo
## só dentro do alcance do nível 20 e o terceiro fora dos dois (o corpo do monstro soma uns 18 px ao alcance). Resultado esperado: o nível 1
## acerta 1 de 3 e o nível 20 acerta 2 de 3 (a linha CAPTURA_RAIO de cada cena diz quantos acertou).
## Grava golpe_<heroi>_nivel_NN_antes/acerto/depois.png (o corte, o quadro do dano e dois quadros depois) e escudo_<heroi>_nivel_NN.png.
## Uso: Godot --path jogos/hordas/projeto --script res://testes/captura_raio_nivel.gd -- --saida=<pasta>
## Roda com janela (precisa de GPU); o mundo avança 1/60 s por passo, então as fotos saem iguais em qualquer PC.
## Para ficar fora da tela: acrescente --position -3000,0 na linha do Godot.

const Heroi := preload("res://v2/heroi.gd")
const ANGULOS := [-40.0, 0.0, 40.0]  # graus da direção do golpe, um por monstro

var w
var saida := ""


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
	if saida.is_empty():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(saida)
	AudioServer.set_bus_mute(0, true)
	var meta = load("res://v2/meta.gd")
	meta.caminho_save = "user://captura_raio_%s.cfg" % Time.get_ticks_usec()
	root.get_node("Config").g_perfil_temporario("medio")
	root.size = Vector2i(960, 540)
	for heroi in ["hazaki", "nicao"]:
		for nivel in [1, 20]:
			await _cena(heroi, nivel)
	print("CAPTURA_RAIO ok")
	quit()


## Um mundo novo com o herói `heroi` no nível `nivel`: golpe e, depois, escudo erguido (os mesmos três monstros).
func _cena(heroi: String, nivel: int) -> void:
	seed(7)
	w = load("res://v2/mundo.tscn").instantiate()
	w.modo_teste = true
	w.id_mapa = "floresta"
	load("res://v2/herois.gd").forcado = heroi
	root.add_child(w)
	w.set_process(false)
	await process_frame
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.combate.audio.mudo = true
	w.combate.fx.variante = "katana"
	var h = w.heroi
	var passo: Dictionary = w.combate.cfg.golpe.passos[0]
	h.nivel = 1
	var alc1: float = w.combate.alcance_do_passo(passo)
	h.nivel = 20
	var alc20: float = w.combate.alcance_do_passo(passo)
	h.nivel = nivel
	var dists := [alc1 - 15.0, alc1 + 22.0, alc20 + 28.0]  # dentro nos dois níveis; só no 20; fora nos dois (o corpo do monstro soma uns 18 px ao alcance)
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = null
	h.escudo_forcado = null
	h.dir_olhar = Vector2(1, 0)
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	var origem: Vector2 = h.pos + Heroi.ORIGEM_GOLPE
	var monstros := []
	var fixos := []
	for k in 3:
		var d: float = dists[k]
		var a: float = deg_to_rad(ANGULOS[k])
		var m = w.nascer_monstro("inimigo_cao_ossos", origem + Vector2(d * cos(a), d * sin(a)) + Vector2(0, 6))
		m.vida_max = 100000.0
		m.vida = m.vida_max
		m.cacador = false
		m.raio_vaga = 0.0
		m.atordoa_t = 0.0
		monstros.append(m)
		fixos.append(m.pos)
	h.atacar()
	var acerto := -1  # o quadro em que o primeiro monstro apanhou
	var antes: Image = null
	for i in 45:
		if acerto < 0:  # até o acerto os monstros ficam parados onde nasceram (andariam para o herói); depois o golpe os empurra
			for k in 3:
				monstros[k].pos = fixos[k]
		w.avancar(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		if acerto < 0:
			for m in monstros:
				if m.vida < m.vida_max:
					acerto = i
			if acerto == i:  # o quadro anterior ao acerto (o corte já desenhado) e o do acerto (o dano aplicado)
				var base := "golpe_%s_nivel_%02d_" % [heroi, nivel]
				antes.save_png(saida.path_join(base + "antes.png"))
				img.save_png(saida.path_join(base + "acerto.png"))
				var n := 0
				for m in monstros:
					n += 1 if m.vida < m.vida_max else 0
				print("CAPTURA_RAIO %s nivel %d: alcance %.1f px, acertou %d de 3 no quadro %d" % [heroi, nivel, w.combate.alcance_do_passo(passo), n, i])
		elif i == acerto + 2:
			img.save_png(saida.path_join("golpe_%s_nivel_%02d_depois.png" % [heroi, nivel]))
		antes = img
	for i in 60:  # deixa o golpe acabar antes de erguer o escudo
		w.avancar(1.0 / 60.0)
		await process_frame
	for m in monstros:  # o escudo sozinho, sem monstro por cima dele
		m.pos = h.pos + Vector2(3000.0, 0.0)
		m.emp = Vector2.ZERO
	h.escudo_forcado = true
	for i in 12:
		w.avancar(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join("escudo_%s_nivel_%02d.png" % [heroi, nivel]))
	h.escudo_forcado = false
	root.remove_child(w)
	w.queue_free()
	load("res://v2/herois.gd").forcado = ""
	await process_frame
