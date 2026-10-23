extends Control
## A mesma fixture, preservando o tipo Control das duas cenas de QA do salão.

const AmbienteTesteV2 := preload("res://testes/ambiente_v2.gd")


func _init() -> void:
	AmbienteTesteV2.iniciar(get_script().resource_path)


func _exit_tree() -> void:
	AmbienteTesteV2.finalizar()
