extends Node
## Cena de verificação (copiada pelo gerar.py): roda com os autoloads ativos e carrega cada script do projeto.
## Imprime "G4VERIFICA <caminho> OK|ERRO"; os erros de parse saem no stderr com arquivo:linha.

func _ready() -> void:
	var lista = []
	_coletar("res://scripts", lista)
	for p in lista:
		var s = load(p)
		print("G4VERIFICA %s %s" % [p, "OK" if s != null and s.can_instance() else "ERRO"])
	print("G4VERIFICA_FIM")
	get_tree().quit()


func _coletar(dir: String, lista: Array) -> void:
	var d = Directory.new()
	if d.open(dir) != OK:
		return
	d.list_dir_begin(true, true)
	var n = d.get_next()
	while n != "":
		var c = dir + "/" + n
		if d.current_is_dir():
			_coletar(c, lista)
		elif n.ends_with(".gd"):
			lista.append(c)
		n = d.get_next()
	d.list_dir_end()
