extends "res://testes/v2_mare_sangue.gd"
## Metade 2 das regressões da Maré (a metade 1 é testes/v2_mare_sangue.gd): Maré no fator, Maré de cada herói, cone, borda, chamada pelo Q e som.


func _ready() -> void:
	await _mare_no_fator()
	await _formacao_por_heroi()
	await _cone()
	_borda()
	await _chamada_por_heroi()
	await _som_prioritario()
	await _fim("v2_mare_heroi")
