extends Node
const Meta := preload("res://v2/meta.gd")
const Altar := preload("res://v2/altar.tscn")
const SAVE := "user://foto_santuario_final.cfg"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Meta.caminho_save = SAVE
	_limpar()
	Meta.registrar_partida({"tempo":150, "maior_combo":25, "almas":150})
	var a = Altar.instantiate()
	get_tree().root.add_child(a)
	await get_tree().process_frame
	await get_tree().process_frame
	a._selecionar_conquista("sobreviva_5min")
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("C:/Dev/Breno/kikiu-santuario/logs-santuario/final/santuario_progresso_parcial.png")
	Meta.registrar_partida({"tempo":600, "abates":220, "maior_combo":85, "nivel":20, "venceu":true, "almas":12000})
	for id in ["vida","dano","treino"]:
		for i in int(Meta.melhoria(id).max):
			Meta.comprar(id)
	a._atualizar()
	a._selecionar_conquista("derrota_chefe")
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("C:/Dev/Breno/kikiu-santuario/logs-santuario/final/santuario_conquistas_cumpridas.png")
	_limpar()
	get_tree().quit()

func _limpar() -> void:
	for caminho in [SAVE,SAVE+".bak",SAVE+".tmp"]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
