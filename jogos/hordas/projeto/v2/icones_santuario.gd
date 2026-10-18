extends RefCounted
## Ícones pixel art do santuário (melhorias, conquistas, recompensas e estruturas): `assets/v2/icones_santuario/<id>.png` (fonte em
## `jogos/hordas/fonte_arte/icones_santuario/`). Id sem arte usa `generico.png`. Quem mostra o ícone deve usar `texture_filter = NEAREST`.

const PASTA := "res://assets/v2/icones_santuario/"

static var _memo := {}


## A textura do ícone de `id`. Devolve o ícone genérico se o id não tiver arte própria.
static func textura(id: String) -> Texture2D:
	if not _memo.has(id):
		var caminho := PASTA + id + ".png"
		if not ResourceLoader.exists(caminho):
			caminho = PASTA + "generico.png"
		_memo[id] = load(caminho) as Texture2D
	return _memo[id]
