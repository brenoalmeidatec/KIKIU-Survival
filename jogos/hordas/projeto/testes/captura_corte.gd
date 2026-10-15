extends SceneTree
## Captura o corte do Hazaki em jogo: heroi golpeando 3 vezes (combo) com uns monstros na frente, um PNG por quadro (60 fps de jogo).
## Uso: Godot --path jogos/hordas/projeto --script res://testes/captura_corte.gd -- --saida=<pasta>
## Roda com janela (precisa de GPU); o mundo avanca 1/60 s por passo, entao a captura sai igual em qualquer PC.

var w
var saida := ""
var variante := "katana"  # --corte=ciano usa a variante ciano


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
		if a.begins_with("--corte="):
			variante = a.trim_prefix("--corte=")
	if saida.is_empty():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(saida)
	AudioServer.set_bus_mute(0, true)
	var meta = load("res://v2/meta.gd")
	meta.caminho_save = "user://captura_corte_%s.cfg" % Time.get_ticks_usec()
	root.get_node("Config").g_perfil_temporario("medio")
	seed(7)
	w = load("res://v2/mundo.tscn").instantiate()
	w.modo_teste = true
	w.id_mapa = "floresta"
	root.size = Vector2i(960, 540)
	root.add_child(w)
	w.set_process(false)
	await process_frame
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.combate.audio.mudo = true
	w.combate.fx.variante = variante
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	for k in 3:
		var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(46.0 + 14.0 * k, -30.0 + 30.0 * k))
		m.vida_max = 100000.0
		m.vida = m.vida_max
		m.cacador = false
		m.raio_vaga = 0.0
	for i in 20:
		w.avancar(1.0 / 60.0)
		await process_frame
	w.heroi.atacar()
	for i in 80:
		if i == 22 or i == 50:
			w.heroi.atacar()
		w.avancar(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png(saida.path_join("q%03d.png" % i))
	print("CAPTURA_CORTE ok")
	quit()
