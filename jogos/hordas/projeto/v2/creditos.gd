extends RefCounted
## Créditos e licenças da v2 (Ajustes > Créditos, em pausa.gd). Cada linha tem rótulo, valor (à direita) e a ajuda, que o menu mostra
## no rodapé quando a linha é escolhida: é lá que ficam os avisos de licença completos. Quem entrar com recurso de terceiros
## (música, fonte, imagem) acrescenta a linha aqui, com o aviso que a licença pede; o teste (testes/v2_pausa) confere que toda
## linha tem rótulo e ajuda. A v1 tinha a tela de créditos dela (main.gd), que some junto com a v1.

const LINHAS := [
	{
		"rotulo": "Criadores",
		"valor": "Breno e Alisson",
		"ajuda": "K.I.K.I.U nasceu de uma ideia do Breno (história, personagens, mecânicas e a base do código) e virou jogo a quatro mãos: o Alisson cuidou da arte, dos cenários, do visual e do online.",
	},
	{
		"rotulo": "Feito com",
		"valor": "Blender, Claude Code",
		"ajuda": "A arte nasce no Blender e vira pixel art. O código foi escrito a quatro mãos com o Claude Code, um Claude de cada lado.",
	},
	{
		"rotulo": "Motor do jogo",
		"valor": "Godot Engine",
		"ajuda": "Godot Engine, licença MIT. Copyright (c) 2014-present Godot Engine contributors. Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur. godotengine.org/license",
	},
	{
		"rotulo": "Fontes",
		"valor": "Licença OFL",
		"ajuda": "Press Start 2P, de CodeMan38. Jersey 10, de The Soft Type Project (títulos). Pixelify Sans, de The Pixelify Sans Project (textos). Todas sob a SIL Open Font License 1.1.",
	},
	{
		"rotulo": "Música",
		"valor": "Kevin MacLeod",
		"ajuda": "Música: Kevin MacLeod (incompetech.com), licença Creative Commons Atribuição 4.0 (CC BY 4.0). As faixas foram cortadas e ganharam laço para o jogo.",
	},
	{
		"rotulo": "Efeitos sonoros",
		"valor": "Feitos no projeto",
		"ajuda": "Os efeitos sonoros são gerados por código, dentro do próprio projeto.",
	},
]


## As linhas do menu (ids "c:0", "c:1"... só para serem selecionáveis; a ajuda vem junto de cada uma).
static func itens() -> Array:
	var r: Array = []
	for i in LINHAS.size():
		var l: Dictionary = LINHAS[i]
		r.append({"id": "c:%d" % i, "rotulo": l.rotulo, "valor": l.valor, "ajuda": l.ajuda})
	return r
