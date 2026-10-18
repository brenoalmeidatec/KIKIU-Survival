extends Node
const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const Altar := preload("res://v2/altar.tscn")
const SAVE := "user://foto_santuario_conjunto.cfg"

func _ready() -> void:
	Meta.caminho_save = SAVE
	_limpar()
	var a = Altar.instantiate()
	add_child(a)
	for id in ["medio", "cidade"]:
		Mapas.escolher(id)
		a._atualizar_mapa()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("C:/Dev/Breno/kikiu-santuario/logs-santuario/conjunto/santuario_" + id + ".png")
		print("FOTO ", id, " MAPA fim=", a._mapa.position.x + a._mapa.size.x, " ENTRAR início=", a._entrar.position.x)
	_limpar()
	get_tree().quit()

func _limpar() -> void:
	for caminho in [SAVE,SAVE+".bak",SAVE+".tmp"]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
