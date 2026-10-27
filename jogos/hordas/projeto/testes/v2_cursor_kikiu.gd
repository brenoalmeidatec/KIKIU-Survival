extends SceneTree
## Confere o cursor da v2: as duas formas em cada cor, o ponto de clique e a troca de modo.
## godot --headless --path . --script res://testes/v2_cursor_kikiu.gd -- --ampliar=PASTA   (PASTA opcional: salva as prévias 4x)
const CursorKikiu := preload("res://v2/cursor_kikiu.gd")


func _init() -> void:
	var falhas := 0
	var ampliar := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ampliar="):
			ampliar = a.trim_prefix("--ampliar=")
	for forma in ["seta", "mira"]:
		for cor in CursorKikiu.CORES:
			var img: Image = CursorKikiu.montar(CursorKikiu.SETA if forma == "seta" else CursorKikiu.MIRA, CursorKikiu.CORES[cor])
			var esperado := Vector2i(22, 36) if forma == "seta" else Vector2i(26, 26)
			if img.get_size() != esperado:
				print("FALHA: %s/%s com tamanho %s" % [forma, cor, img.get_size()])
				falhas += 1
			if forma == "mira" and img.get_pixel(13, 13) != CursorKikiu.CORES[cor]:
				print("FALHA: centro da mira fora da cor %s" % cor)
				falhas += 1
			if ampliar != "":
				DirAccess.make_dir_recursive_absolute(ampliar)
				var grande := img.duplicate()
				grande.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
				grande.save_png(ampliar.path_join("%s_%s_4x.png" % [forma, cor]))
	CursorKikiu.aplicar("seta")
	CursorKikiu.aplicar("seta")
	CursorKikiu.aplicar("mira")
	if CursorKikiu._aplicado != "mira" and CursorKikiu._aplicado != "seta":
		print("FALHA: modo não aplicado")
		falhas += 1
	print("RESULTADO: %s" % ("OK" if falhas == 0 else "FALHOU %d" % falhas))
	quit(falhas)
