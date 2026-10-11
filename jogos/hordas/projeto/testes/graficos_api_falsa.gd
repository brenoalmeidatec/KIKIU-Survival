extends Node
## Dublê local da API de gráficos (Config.g_*), só para os testes e prints da aba Gráficos (#150) enquanto o PR
## graficos-dados não entra na main. Lê testes/graficos_exemplo.json. Não vai para o jogo.

signal graficos_mudou

const ARQUIVO := "res://testes/graficos_exemplo.json"
var _dados: Dictionary = {}
var _vals := {}

func _init() -> void:
	_dados = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	_vals = _dados.perfis.medio.duplicate()

func g_opcoes() -> Array:
	return _dados.opcoes

func g(chave: String) -> Variant:
	return _vals.get(chave)

func g_definir(chave: String, valor: Variant) -> void:
	_vals[chave] = valor
	graficos_mudou.emit()

func g_perfil() -> String:
	for p in ["baixo", "medio", "alto"]:
		var igual := true
		for k in _dados.perfis[p]:
			if _vals.get(k) != _dados.perfis[p][k]:
				igual = false
		if igual:
			return p
	return "personalizado"

func g_aplicar_perfil(nome: String) -> void:
	for k in _dados.perfis[nome]:
		_vals[k] = _dados.perfis[nome][k]
	graficos_mudou.emit()

## Detecção falsa: sempre sugere Médio (não aplica sozinha, como a API deve fazer).
func g_detectar() -> String:
	return "medio"
