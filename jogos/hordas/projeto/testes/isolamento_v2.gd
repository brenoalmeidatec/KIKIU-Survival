extends Node
## Base dos testes Node da v2: isola saves antes de qualquer _ready da cena.

const AmbienteTesteV2 := preload("res://testes/ambiente_v2.gd")


func _init() -> void:
	AmbienteTesteV2.iniciar(get_script().resource_path)


func _exit_tree() -> void:
	AmbienteTesteV2.finalizar()
