extends "res://testes/isolamento_v2.gd"
# Layout da tela PERSONAGENS da v2 (v2/personagens_tela.gd). Regressões desta tela:
# - a lista (com VOLTAR) fica acima do rodapé de teclas e rola até o último botão;
# - o foco de cada botão cabe na área visível da rolagem, inclusive o da primeira e o da última linha (a borda fica por dentro);
# - a ficha fica dentro da pedra (5 px), sem sobreposição entre nome, retrato, info e detalhe; o aviso fica acima da ficha;
# - PER-1b: o retrato é o CORPO inteiro (quadro parado da folha de sprites) de TODOS os heróis, na mesma escala inteira (3x), na mesma
#   caixa (120x132), centrado no eixo e com os pés na mesma linha; nenhum rosto.png aparece na tela de escolha (nem o LightWolf);
# - o pior caso de texto cabe: o info com o herói de cada nome e o detalhe com 4 melhorias no máximo e o nome de mapa mais longo.
# Usa índice e saves TEMPORÁRIOS (user://teste_pers_layout_*).
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_personagens_layout.tscn  (imprime "falhas=0")

const Personagens := preload("res://v2/personagens.gd")
const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const Herois := preload("res://v2/herois.gd")
const Tela := preload("res://v2/personagens.tscn")
const INDICE := "user://testes_v2/v2_personagens_layout/teste_pers_layout_indice.cfg"
const PREFIXO := "user://testes_v2/v2_personagens_layout/teste_pers_layout_p"
const ANTIGO := "user://testes_v2/v2_personagens_layout/teste_pers_layout_antigo.cfg"
const META := "user://testes_v2/v2_personagens_layout/teste_pers_layout_meta.cfg"
const RODAPE_Y := 498.0  # o rodapé de teclas começa aqui (DESIGN.md §1b)
const PEDRA := 5.0  # espessura da moldura de pedra: o conteúdo da ficha fica dentro dela
# Altura da caixa do nome: a linha do Jersey 56 na janela real (ascent 45 + descent 15 = 60; a 1920x1080 mede 60,8). O --headless
# usa o servidor de texto "dummy", que devolve outra métrica (74,67); por isso a referência é esta constante, medida na janela.
const NOME_ALT_REAL := 61.0
# Altura da caixa do aviso: Spleen 16 (linha de 19 px) na janela real. Mesmo motivo do nome: no headless a métrica dummy dá 32 px.
const AVISO_ALT_REAL := 20.0

var falhas := 0


## O pior detalhe com dados reais: "Melhorias:", os 4 efeitos mais longos no nível máximo e o nome de mapa mais longo.
## Estático para a ferramenta de foto (testes/fotos/personagens_fotos.gd) mostrar o mesmo texto que o teste mede.
static func pior_detalhe() -> String:
	var efeitos: Array = []
	for m in Meta.melhorias():
		efeitos.append("- " + Meta.texto_efeito(m, int(m.max)))
	efeitos.sort_custom(func(a, b): return a.length() > b.length())
	var mapa := ""
	for id in Mapas.ids():
		var nome := str(Mapas.buscar(id).nome)
		if nome.length() > mapa.length():
			mapa = nome
	var linhas := ["Melhorias:"]
	linhas.append_array(efeitos.slice(0, 4))
	linhas.append("Último mapa: %s" % mapa)
	return "\n".join(PackedStringArray(linhas))


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Personagens.caminho_indice = INDICE
	Personagens.caminho_base = PREFIXO
	Personagens.caminho_antigo = ANTIGO
	Meta.caminho_save = META
	_limpar()
	await _nomes()
	await _lista()
	_limpar()
	print("v2_personagens_layout falhas=%d" % falhas)
	get_tree().quit()


func _limpar() -> void:
	for c in [INDICE, ANTIGO, META, META + ".bak", META + ".tmp"]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))
	for i in range(1, 12):
		var c := Personagens.caminho_do_save("p%d" % i)
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))


func _assentar() -> void:
	for i in 4:
		await get_tree().process_frame


func _rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)


func _caixa_nome(t) -> Rect2:
	var r := _rect(t._nome)
	return Rect2(r.position, Vector2(r.size.x, NOME_ALT_REAL))


func _painel(t) -> Rect2:
	for f in t.get_children():
		if f is Panel:
			return _rect(f)
	return Rect2()


func _dentro(r: Rect2, pai: Rect2, msg: String) -> void:
	ok(pai.encloses(r), "%s: %s fora de %s" % [msg, r, pai])


func _separados(a: Rect2, b: Rect2, msg: String) -> void:
	ok(not a.intersects(b), "%s: %s encosta em %s" % [msg, a, b])


## O foco do botão (o stylebox "focus", com as margens de expansão dele) cabe na área visível da rolagem, sem a barra de rolagem.
func _foco_cabe(b: Button, rolagem: ScrollContainer) -> void:
	var s := b.get_theme_stylebox("focus")
	var m := [s.get_expand_margin(SIDE_LEFT), s.get_expand_margin(SIDE_TOP), s.get_expand_margin(SIDE_RIGHT), s.get_expand_margin(SIDE_BOTTOM)]
	var caixa := _rect(b).grow_individual(m[0], m[1], m[2], m[3])
	var visivel := _rect(rolagem)
	var barra := rolagem.get_v_scroll_bar()
	if barra.visible:
		visivel.size.x -= barra.size.x
	var dentro := caixa.position.x >= visivel.position.x - 0.5 and caixa.end.x <= visivel.end.x + 0.5
	dentro = dentro and caixa.position.y >= visivel.position.y - 0.5 and caixa.end.y <= visivel.end.y + 0.5
	ok(dentro, "foco de '%s' cortado pela rolagem: %s fora de %s" % [b.text, caixa, visivel])


## Quantas linhas o texto ocupa numa caixa de `larg` px com a fonte de `tam` px. Spleen: glifo de tam/2 px e linha de tam + 3 px
## (o espaço de linha padrão do Label). Conta à mão porque em --headless o servidor de texto é o "dummy", sem métrica de fonte.
func _linhas(txt: String, larg: float, tam: int) -> int:
	var por_linha := maxi(1, int(larg / (tam / 2.0)))
	var linhas := 0
	for par in txt.split("\n"):
		linhas += maxi(1, ceili(float(par.length()) / por_linha))
	return linhas


func _cabe(l: Label, msg: String) -> void:
	_cabe_texto(l.text, l.size, l.get_theme_font_size("font_size"), msg)


func _cabe_texto(txt: String, caixa: Vector2, tam: int, msg: String) -> void:
	var linhas := _linhas(txt, caixa.x, tam)
	ok(linhas * (tam + 3) <= caixa.y + 0.5, "%s: %d linhas (%d px) em %.0f px" % [msg, linhas, linhas * (tam + 3), caixa.y])


## A ficha de um personagem (não VOLTAR nem NOVO PERSONAGEM): tudo dentro da pedra, sem sobreposição, texto que cabe e o retrato certo.
func _ficha_cabe(t, painel_r: Rect2, nome: String) -> void:
	var interior := painel_r.grow(-PEDRA)
	ok(t._retrato.visible, "'%s' mostra retrato" % nome)
	_dentro(_caixa_nome(t), interior, "nome de " + nome)
	_dentro(_rect(t._retrato), interior, "retrato de " + nome)
	_dentro(_rect(t._info), interior, "info de " + nome)
	_dentro(_rect(t._detalhe), interior, "detalhe de " + nome)
	_separados(_caixa_nome(t), _rect(t._retrato), "nome e retrato de " + nome)
	_separados(_rect(t._retrato), _rect(t._info), "retrato e info de " + nome)
	_separados(_rect(t._info), _rect(t._detalhe), "info e detalhe de " + nome)
	_cabe(t._info, "info de " + nome)
	_cabe(t._detalhe, "detalhe de " + nome)
	_retrato_certo(t, nome)


func _nomes() -> void:
	var t = Tela.instantiate()
	add_child(t)
	await _assentar()
	t._abrir_nomes()
	await _assentar()
	var rolagem: ScrollContainer = t._lista.get_parent()
	var painel_r := _painel(t)
	ok(painel_r.size.x > 0, "a ficha tem painel")
	ok(_rect(rolagem).end.y <= RODAPE_Y - 8.0, "a lista termina 8 px acima do rodapé (fim %s)" % _rect(rolagem).end.y)
	ok(rolagem.global_position.x >= 36.0 and _rect(rolagem).end.x <= painel_r.position.x, "a lista não encosta na ficha")
	ok(painel_r.end.y <= RODAPE_Y - 8.0 and painel_r.end.x <= 924.0, "a ficha fica dentro da grade (fim %s)" % painel_r.end)
	var aviso := _rect(t._aviso)
	ok(aviso.position.y + AVISO_ALT_REAL <= painel_r.position.y, "o aviso fica acima da ficha (y %s, caixa de %s)" % [aviso.position.y, AVISO_ALT_REAL])
	var botoes: Array = t._lista.get_children()
	ok(botoes.size() == Personagens.nomes_livres().size() + 1, "um botão por nome mais VOLTAR")
	# cada botão (até o VOLTAR) fica visível dentro da lista ao ganhar o foco, com a borda inteira
	for b in botoes:
		b.grab_focus()
		await _assentar()
		var rb := _rect(b)
		var rr := _rect(rolagem)
		ok(rb.position.y >= rr.position.y - 1.0 and rb.end.y <= rr.end.y + 1.0, "'%s' visível na lista ao focar (%s em %s)" % [b.text, rb, rr])
		ok(rb.end.y <= RODAPE_Y, "'%s' acima do rodapé" % b.text)
		_foco_cabe(b, rolagem)
		if b.text == "VOLTAR":
			ok(not t._retrato.visible, "VOLTAR não mostra retrato")
			ok(t._detalhe.text != "", "VOLTAR explica o que faz")
			continue
		_ficha_cabe(t, painel_r, b.text)
	var pior := pior_detalhe()
	_cabe_texto(pior, t._detalhe.size, 16, "pior detalhe (4 melhorias no máximo + último mapa)")
	print("pior detalhe: %d linhas na caixa de %.0f px" % [_linhas(pior, t._detalhe.size.x, 16), t._detalhe.size.y])
	for n in Personagens.nomes():
		var heroi := Personagens.heroi_do_nome(str(n.nome))
		var info := "Almas: 99999\nHerói: %s (%s)" % [str(Herois.heroi(heroi).nome), Personagens.arma_inicial(heroi)]
		_cabe_texto(info, t._info.size, 32, "info com o herói de %s" % n.nome)
		# PER-1b: todo nome mostra o corpo, da folha própria (Matthew) ou da do herói dele; nunca o rosto.png
		var folha := Personagens.folha_do_nome(str(n.nome))
		var esperada := Personagens.sprite_do_nome(str(n.nome))
		ok(folha == (esperada if esperada != "" else str(Herois.heroi(heroi).sprite)), "'%s' usa a folha %s (do herói %s)" % [n.nome, folha, heroi])
	var barra := rolagem.get_v_scroll_bar()
	print("rolagem: max=%.0f altura=%.0f barra_visivel=%s" % [barra.max_value, _rect(rolagem).size.y, barra.visible])
	_todos_iguais(t)
	t.queue_free()
	await get_tree().process_frame


func _retrato_certo(t, nome: String) -> void:
	var tex = t._retrato.texture
	ok(tex is AtlasTexture, "retrato de %s é um quadro (AtlasTexture), não a imagem inteira" % nome)
	if not tex is AtlasTexture:
		return
	# nenhum rosto: o retrato vem da folha _albedo.png do herói, nunca de assets/personagens/<pasta>/rosto.png
	var caminho: String = tex.atlas.resource_path
	ok(
		caminho.ends_with("_albedo.png") and caminho.begins_with(Personagens.PASTA_SPRITES),
		"retrato de %s é a folha de sprites (%s), não o rosto" % [nome, caminho]
	)
	ok(not caminho.contains("rosto"), "retrato de %s não usa rosto.png (%s)" % [nome, caminho])
	# mesmo enquadramento para todos: a mesma caixa, escala inteira igual e os pés na mesma linha
	var esc: float = t._retrato.size.x / tex.get_width()
	ok(
		t._retrato.size == Vector2(t.RETRATO_L, t.RETRATO_ALT),
		"retrato de %s na caixa padrão %sx%s (tem %s)" % [nome, t.RETRATO_L, t.RETRATO_ALT, t._retrato.size]
	)
	ok(is_equal_approx(esc, float(t.RETRATO_ESC)), "retrato de %s em %dx (tem %s)" % [nome, t.RETRATO_ESC, esc])
	ok(is_equal_approx(t._retrato.size.y, tex.get_height() * esc), "retrato de %s sem distorção" % nome)
	var reg: Rect2 = tex.region
	ok(reg.size.x * esc <= t.RETRATO_L and reg.size.y * esc <= t.RETRATO_ALT, "corpo de %s cabe na caixa (%s)" % [nome, reg.size * esc])
	ok(reg.size.y * esc >= 100.0, "corpo inteiro de %s: pelo menos 100 px de altura (tem %s)" % [nome, reg.size.y * esc])
	ok(is_equal_approx(tex.margin.position.y + reg.size.y, tex.get_height()), "pés de %s apoiados na base da caixa" % nome)
	ok(absf(t._retrato.position.x + t._retrato.size.x / 2.0 - 682.0) < 1.0, "retrato de %s centrado no eixo da ficha" % nome)
	ok(is_equal_approx(t._retrato.position.y, 100.0 + 5.0 + 61.0), "retrato de %s na mesma altura da ficha" % nome)


## Os retratos de todos os nomes têm o mesmo tamanho e a mesma escala, e a tela nunca carrega rosto.png (checado pelo caminho).
func _todos_iguais(t) -> void:
	var tamanhos := {}
	var escalas := {}
	var vistos := 0
	for n in Personagens.nomes():
		t._definir_retrato(true, Personagens.folha_do_nome(str(n.nome)))
		ok(t._retrato.visible, "'%s' mostra o corpo" % n.nome)
		tamanhos[t._retrato.size] = true
		escalas[t._retrato.size.x / t._retrato.texture.get_width()] = true
		ok(not str(t._retrato.texture.atlas.resource_path).contains("rosto"), "'%s' sem rosto.png" % n.nome)
		vistos += 1
	ok(vistos >= 9, "todos os nomes checados, LightWolf incluído (%d)" % vistos)
	ok(tamanhos.size() == 1, "todos os retratos com o mesmo tamanho (%s)" % [tamanhos.keys()])
	ok(escalas.size() == 1, "todos os retratos na mesma escala (%s)" % [escalas.keys()])


func _lista() -> void:
	Personagens.criar("Breno", "hazaki")
	Personagens.criar("Luke", "lucas")
	var t = Tela.instantiate()
	add_child(t)
	await _assentar()
	var painel_r := _painel(t)
	var rolagem: ScrollContainer = t._lista.get_parent()
	for b in t._lista.get_children():
		b.grab_focus()
		await _assentar()
		_foco_cabe(b, rolagem)
		if b.text == "NOVO PERSONAGEM":
			ok(not t._retrato.visible, "NOVO PERSONAGEM não mostra retrato")
			ok(t._detalhe.text != "", "NOVO PERSONAGEM explica o que faz")
			continue
		_ficha_cabe(t, painel_r, b.text)
	t.queue_free()
	await get_tree().process_frame
