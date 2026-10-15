extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	seed(144)
	AudioServer.set_bus_mute(0, true)
	var meta = load("res://v2/meta.gd")
	meta.caminho_save = "user://qa_visual_benchmark_%s.cfg" % Time.get_ticks_usec()
	root.size = Vector2i(960, 540)
	var mundo = load("res://v2/mundo.tscn").instantiate()
	root.add_child(mundo)
