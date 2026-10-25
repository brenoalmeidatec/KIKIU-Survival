extends SceneTree
## Confere a arte do cursor da v2 e a troca entre seta e mira (godot --headless --script res://testes/v2_cursor_kikiu.gd).
const CursorKikiu := preload("res://v2/cursor_kikiu.gd")


func _init() -> void:
	var falhas := 0
	for modo in ["seta", "mira"]:
		var tex = CursorKikiu._carregar(modo)
		if tex == null:
			print("FALHA: %s sem textura" % modo)
			falhas += 1
			continue
		print("%s: %dx%d" % [modo, tex.get_width(), tex.get_height()])
	CursorKikiu.aplicar("seta")
	CursorKikiu.aplicar("seta")  # repetido não refaz nada
	CursorKikiu.aplicar("mira")
	print("modo final: %s" % CursorKikiu._modo)
	if CursorKikiu._modo != "mira":
		falhas += 1
	print("RESULTADO: %s" % ("OK" if falhas == 0 else "FALHOU %d" % falhas))
	quit(falhas)
