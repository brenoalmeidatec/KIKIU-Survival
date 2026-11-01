extends "res://testes/v2_segredos.gd"
## Metade 2 dos segredos (a metade 1, os segredos de cada mapa, é testes/v2_segredos.gd): o robô não grava segredo, o "parado" resiste a
## empurrão, no coop qualquer herói dispara, o estado de uma partida nova e o Códice.


func _ready() -> void:
	var md5_real := _preparar()
	await _riscos()
	_nova_partida_e_estado()
	await _codice()
	_fim(md5_real, "v2_segredos_riscos")
