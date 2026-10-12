extends Node
# Teste das fontes da v2 (regra em v2/LEIA-ME.md). Roda sem janela e confere o que se pode medir sem olhar:
#  - as fontes vêm do lugar central (Dados) e estão sem anti-aliasing, sem hinting e sem posição de subpixel (o pixel da fonte cai no
#    pixel da tela; é isso que mantém o desenho nítido no shader sharp bilinear);
#  - o texto corrido está na Spleen 8x16 e todo tamanho dele nas telas é múltiplo da grade (16);
#  - todos os caracteres do português e os símbolos das telas existem em cada fonte que os desenha;
#  - os dígitos têm desenhos próprios: os contornos de 5 e S, 0 e O, 1 e I e l, 2 e Z, 6 e G, 8 e B, e dos dez dígitos entre si, são
#    diferentes. Isto só pega fonte que repete o desenho ou não o tem; se o desenho é LEGÍVEL (o defeito da Pixelify Sans: o 5 saía
#    quase como um S e "500" lia-se "800") quem confere é o olho, nos prints de testes/v2_fontes_prints.tscn;
#  - nenhuma caixa estoura: nem os cartões (descrição, próximo, nível, evolução, em todas as cartas e raridades e em todos os níveis), nem
#    as linhas e a ajuda do menu de Gráficos, nem o crédito da aba Áudio.
# Os prints para OLHAR ficam em testes/v2_fontes_prints.tscn e a folha de comparação em testes/v2_fontes_folha.tscn.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_fontes.tscn  (imprime "v2_fontes falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Telas := preload("res://v2/telas.gd")
const Pausa := preload("res://v2/pausa.gd")
const Status := preload("res://v2/status.gd")
const AjustesGraficos := preload("res://v2/ajustes_graficos.gd")
const OPCOES_TESTE := "user://teste_v2_fontes_opcoes.cfg"
const PT := "ãçéêõüÃÇÉÊÕÜáíóúâôàÁÍÓÚÂÔÀ"
const SIMBOLOS := "0123456789*()%+-/:.,'\"x[]°×"
const PARES := [["5", "S"], ["0", "O"], ["1", "I"], ["1", "l"], ["I", "l"], ["2", "Z"], ["6", "G"], ["8", "B"], ["0", "D"], ["3", "8"], ["6", "b"]]

## Tamanhos fora da grade que ficam de propósito. Motivo escrito aqui; o PR e o DESIGN.md (seção 8) repetem.
const EXCECOES := {
	"status.TAM": "SUA BUILD: Spleen 12 px. Em 16 as colunas não cabem (v2/status.gd:7-10); a Spleen 6x12 seria o certo.",
	"status.TAM_P": "SUA BUILD: Spleen 11 px, a mesma pendência de status.TAM.",
	"status.TAM_NOME_PEQ": "SUA BUILD: Jersey 14 px para o nome de golpe que não cabe em 19.",
	"telas.TAM_NOME_CURTO": "Escolha: Jersey 28 px para o nome longo (Lâminas Rodopiantes) que não cabe em 37.",
}

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Config.arquivo = OPCOES_TESTE
	_fontes_centrais()
	_cobertura()
	_digitos()
	_tamanhos()
	await _cartoes()
	_menu_graficos()
	if FileAccess.file_exists(OPCOES_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OPCOES_TESTE))
	Config.arquivo = "user://opcoes.cfg"
	print("v2_fontes falhas=%d" % falhas)
	get_tree().quit()


func _fontes() -> Dictionary:
	return {"texto": Dados.fonte_texto, "titulo": Dados.fonte_titulo, "hud": Dados.fonte}


func _fontes_centrais() -> void:
	for nome in _fontes():
		ok(_fontes()[nome] is FontFile, "Dados.fonte_%s é um FontFile" % nome)
	for nome in ["texto", "titulo"]:  # a Press Start 2P (HUD) já é nítida no tamanho 8 e fica como estava
		var ff := _fontes()[nome] as FontFile
		ok(ff.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "%s sem anti-aliasing" % nome)
		ok(ff.hinting == TextServer.HINTING_NONE, "%s sem hinting" % nome)
		ok(ff.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_DISABLED, "%s sem posição de subpixel" % nome)
	ok((Dados.fonte_texto as FontFile).resource_path.ends_with("spleen-8x16.otf"), "o texto corrido é a Spleen 8x16")
	ok(FileAccess.file_exists("res://assets/fonte/spleen/LICENSE.txt"), "a licença da Spleen está ao lado da fonte")
	ok(FileAccess.file_exists("res://assets/fonte/jersey10/OFL.txt"), "a licença da Jersey 10 está ao lado da fonte")
	ok(not FileAccess.file_exists("res://assets/fonte/pixelify_sans/PixelifySans.ttf"), "a Pixelify Sans (o 5 saía como S) não voltou")


func _cobertura() -> void:
	for nome in _fontes():
		var f: Font = _fontes()[nome]
		for c in PT + SIMBOLOS + "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz":
			ok(f.has_char(c.unicode_at(0)), "a fonte %s tem o caractere %s" % [nome, c])


## O contorno do glifo (a lista de pontos) como texto: igual só se o desenho for igual.
func _contorno(f: Font, c: String, tam: int) -> String:
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = f.get_rids()[0]
	var idx := ts.font_get_glyph_index(rid, tam, c.unicode_at(0), 0)
	var d: Dictionary = ts.font_get_glyph_contours(rid, tam, idx)
	return str(d.get("points", ""))


func _digitos() -> void:
	for nome in ["texto", "titulo", "hud"]:
		var f: Font = _fontes()[nome]
		var tam: int = {"texto": 16, "titulo": 19, "hud": 8}[nome]
		for par in PARES:
			if nome != "texto" and par == ["I", "l"]:
				continue  # na Jersey 10 o I e o l maiúsculo/minúsculo são a mesma barra; no texto corrido (Spleen) são diferentes
			var a := _contorno(f, par[0], tam)
			var b := _contorno(f, par[1], tam)
			ok(a != "" and b != "" and a != b, "%s: %s e %s têm desenhos diferentes" % [nome, par[0], par[1]])
		var vistos := {}
		for d in "0123456789":
			var k := _contorno(f, d, tam)
			ok(not vistos.has(k), "%s: o dígito %s não repete o desenho de outro dígito" % [nome, d])
			vistos[k] = true


func _tamanhos() -> void:
	for t in [Telas.TAM_TEXTO, Pausa.TAM_SUB, Pausa.TAM_VALOR, Pausa.TAM_AJUDA, Pausa.TAM_DICA]:
		ok(t % 16 == 0, "tamanho %d da Spleen é múltiplo da grade (16)" % t)
	ok(Telas.TAM_TITULO in [19, 37, 56] and Telas.TAM_NOME in [19, 37, 56], "títulos da Jersey 10 na grade (19, 37, 56)")
	_tamanhos_da_grade()


## Cada tamanho de texto da v2, por fonte, cai na grade (Spleen 16, Jersey 19/37/56, Press Start 8, múltiplos) ou está em EXCECOES
## com o motivo. Tamanho novo fora da grade falha aqui, e exceção sem constante correspondente também.
func _tamanhos_da_grade() -> void:
	var casos := [
		["spleen", "telas.TAM_TEXTO", Telas.TAM_TEXTO],
		["spleen", "pausa.TAM_SUB", Pausa.TAM_SUB],
		["spleen", "pausa.TAM_VALOR", Pausa.TAM_VALOR],
		["spleen", "pausa.TAM_AJUDA", Pausa.TAM_AJUDA],
		["spleen", "pausa.TAM_DICA", Pausa.TAM_DICA],
		["spleen", "status.TAM", Status.TAM],
		["spleen", "status.TAM_P", Status.TAM_P],
		["jersey", "telas.TAM_TITULO", Telas.TAM_TITULO],
		["jersey", "telas.TAM_NOME", Telas.TAM_NOME],
		["jersey", "telas.TAM_NOME_CURTO", Telas.TAM_NOME_CURTO],
		["jersey", "telas.TAM_CONTAGEM", Telas.TAM_CONTAGEM],
		["jersey", "status.TAM_CAB", Status.TAM_CAB],
		["jersey", "status.TAM_NOME_PEQ", Status.TAM_NOME_PEQ],
		["press", "status.TAM_NUM", Status.TAM_NUM],
		["press", "status.TAM_GRANDE", Status.TAM_GRANDE],
	]
	var nomes := []
	for c in casos:
		nomes.append(c[1])
		var na_grade: bool = (c[2] % 16 == 0) if c[0] == "spleen" else (c[2] % 8 == 0) if c[0] == "press" else (c[2] in [19, 37, 56])
		ok(na_grade or EXCECOES.has(c[1]), "%s = %d px (%s) fora da grade e sem exceção documentada" % [c[1], c[2], c[0]])
	for chave in EXCECOES:
		ok(chave in nomes, "exceção %s não corresponde a nenhum tamanho da lista" % chave)


## Altura de um texto quebrado na largura dada, na fonte e no tamanho dados.
func _altura(f: Font, texto: String, larg: float, tam: int, alin := HORIZONTAL_ALIGNMENT_LEFT) -> float:
	return f.get_multiline_string_size(texto, alin, larg, tam, -1, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y


func _cartoes() -> void:
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	await get_tree().process_frame
	var c = w.combate
	var cs = c.cartas
	var tl = c.telas
	var painel: Panel = tl._cartas[0]
	var f: Font = Dados.fonte_texto
	var larg := Telas.CARTA_L - 2.0 * Telas.MARGEM
	var n := 0
	var maior := {"desc": 0.0, "proximo": 0.0, "evolui": 0.0, "nivel": 0.0}
	for d in cs.disponiveis():
		cs.zerar()
		for nivel in int(d.max):
			for rar in 4:
				var carta: Dictionary = cs.montar_carta(d, rar)
				tl._preencher(painel, carta)
				n += 1
				for campo in ["desc", "proximo", "nivel", "evolui"]:
					var l := painel.get_node(campo) as Label
					var h := _altura(f, l.text, l.size.x, Telas.TAM_TEXTO)
					maior[campo] = maxf(float(maior[campo]), h)
					if l.text != "":
						ok(h <= l.size.y, "carta %s (raridade %d, nível %d): %s cabe na caixa (%d de %d px de altura)" % [d.id, rar, nivel, campo, h, l.size.y])
				for campo in ["nivel", "evolui"]:
					var l := painel.get_node(campo) as Label
					ok(
						f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Telas.TAM_TEXTO).x <= larg,
						"carta %s: %s numa linha só (%s)" % [d.id, campo, l.text]
					)
				var nome := painel.get_node("nome") as Label
				var tam_nome: int = nome.get_theme_font_size("font_size")
				ok(
					Dados.fonte_titulo.get_string_size(nome.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_nome).x <= larg,
					"carta %s: o nome cabe (%s)" % [d.id, nome.text]
				)
			cs.aplicar(cs.montar_carta(d, 0))
	ok(n > 60, "mediu o conjunto todo das cartas (%d)" % n)
	print("v2_fontes: %d cartões medidos; maiores alturas (px): %s" % [n, str(maior)])
	w.queue_free()
	await get_tree().process_frame


func _menu_graficos() -> void:
	var itens: Array = AjustesGraficos.new().itens()
	var f: Font = Dados.fonte_texto
	var larg_linha := Pausa.PAINEL.size.x - 48.0 - 24.0
	var larg_ajuda := Pausa.PAINEL.size.x - 44.0
	var maior_ajuda := 0.0
	for it in itens:
		if bool(it.get("cab", false)):
			continue
		var nome := str(it.rotulo)
		var valor := str(it.get("valor", ""))
		var l_nome := Dados.fonte_titulo.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, Pausa.TAM_BOTAO).x
		var l_val := f.get_string_size(valor, HORIZONTAL_ALIGNMENT_LEFT, -1, Pausa.TAM_VALOR).x
		ok(l_nome + l_val + 12.0 <= larg_linha, 'linha "%s" (%s): nome e valor não se encostam (%d + %d de %d px)' % [nome, valor, l_nome, l_val, larg_linha])
		var h := _altura(f, str(it.get("ajuda", "")), larg_ajuda, Pausa.TAM_AJUDA)
		maior_ajuda = maxf(maior_ajuda, h)
		ok(h <= Pausa.AJUDA_H, 'ajuda de "%s" cabe no rodapé (%d de %d px)' % [nome, h, Pausa.AJUDA_H])
	ok(maior_ajuda > 0.0, "mediu a ajuda das opções")
	print("v2_fontes: %d linhas de Gráficos medidas; a ajuda mais alta tem %d px (rodapé de %d)" % [itens.size(), maior_ajuda, Pausa.AJUDA_H])
	var credito := _altura(f, Pausa.CREDITO_MUSICA, larg_ajuda, Pausa.TAM_AJUDA)
	ok(credito <= Pausa.AJUDA_H, "o crédito da música cabe no rodapé do Áudio (%d px)" % credito)
	ok(
		f.get_string_size(Pausa.DICA, HORIZONTAL_ALIGNMENT_LEFT, -1, Pausa.TAM_DICA).x <= Pausa.PAINEL.size.x - 16.0,
		"a dica de teclas cabe numa linha do painel"
	)
