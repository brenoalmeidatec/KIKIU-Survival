extends RefCounted
## Um Shader por código para o processo inteiro (15/11, junto com v2/revelacao.gd). No renderizador Compatibility cada Shader novo é um
## programa novo, compilado no primeiro desenho que o usa, mesmo quando o código é igual ao de outro: os três materiais do corte em
## efeitos.gd, os lotes da horda e o resto compilavam cada um o seu. Pegando o shader daqui, código igual compila uma vez só, e a
## partida seguinte (na mesma execução) reusa o que a anterior já compilou. Os parâmetros continuam no ShaderMaterial de cada um.

static var _shaders := {}  # código -> Shader, vivo o processo inteiro


## O Shader com este código, o mesmo para o processo inteiro.
static func shader(codigo: String) -> Shader:
	var sh: Shader = _shaders.get(codigo)
	if sh == null:
		sh = Shader.new()
		sh.code = codigo
		_shaders[codigo] = sh
	return sh


## Quantos shaders diferentes já foram pedidos (medição e teste).
static func quantos() -> int:
	return _shaders.size()
