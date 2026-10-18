extends Node
# Layout da tela PERSONAGENS da v2 (v2/personagens_tela.gd). Regressão do bug "a lista passa por baixo do rodapé e o retrato vira uma
# tira de pontinhos": a lista de nomes (com VOLTAR) tem de ficar acima do rodapé de teclas e rolar até o último botão; a ficha da
# direita tem de ficar dentro do painel; o retrato do rosto é UM quadro quadrado da tira rosto.png (nunca a tira inteira de 27 quadros),
# em escala inteira e centrado no eixo da ficha. Usa índice e saves TEMPORÁRIOS (user://teste_pers_layout_*).
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_personagens_layout.tscn  (imprime "falhas=0")

const Personagens := preload("res://v2/personagens.gd")
const Meta := preload("res://v2/meta.gd")
const Tela := preload("res://v2/personagens.tscn")
const INDICE := "user://teste_pers_layout_indice.cfg"
const PREFIXO := "user://teste_pers_layout_p"
const ANTIGO := "user://teste_pers_layout_antigo.cfg"
const META := "user://teste_pers_layout_meta.cfg"
const RODAPE_Y := 498.0  # o rodapé de teclas começa aqui (DESIGN.md §1b)

var falhas := 0


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


func _dentro(c: Control, pai: Rect2, msg: String) -> void:
	var r := _rect(c)
	ok(pai.encloses(r), "%s: %s fora de %s" % [msg, r, pai])


## As linhas do texto (com a quebra) cabem na altura do rótulo? Conta à mão porque em --headless o servidor de texto é o "dummy" (sem
## métrica de fonte): o Spleen 8x16 tem glifo de tam/2 px de largura e linha de tam + 3 px (espaço de linha padrão do Label).
func _cabe(l: Label, msg: String) -> void:
	var tam := l.get_theme_font_size("font_size")
	var por_linha := maxi(1, int(l.size.x / (tam / 2.0)))
	var linhas := 0
	for par in l.text.split("\n"):
		linhas += maxi(1, ceili(float(par.length()) / por_linha))
	var alt := float(linhas * (tam + 3))
	ok(alt <= l.size.y + 0.5, "%s: %d linhas (%.0f px) em %.0f px" % [msg, linhas, alt, l.size.y])


func _nomes() -> void:
	var t = Tela.instantiate()
	add_child(t)
	await _assentar()
	t._abrir_nomes()
	await _assentar()
	var rolagem: ScrollContainer = t._lista.get_parent()
	var painel_r := Rect2()
	for f in t.get_children():
		if f is Panel:
			painel_r = _rect(f)
	ok(painel_r.size.x > 0, "a ficha tem painel")
	ok(_rect(rolagem).end.y <= RODAPE_Y - 8.0, "a lista termina 8 px acima do rodapé (fim %s)" % _rect(rolagem).end.y)
	ok(rolagem.global_position.x >= 36.0 and _rect(rolagem).end.x <= painel_r.position.x, "a lista não encosta na ficha")
	ok(painel_r.end.y <= RODAPE_Y - 8.0 and painel_r.end.x <= 924.0, "a ficha fica dentro da grade (fim %s)" % painel_r.end)
	var botoes: Array = t._lista.get_children()
	ok(botoes.size() == Personagens.nomes_livres().size() + 1, "um botão por nome mais VOLTAR")
	# cada botão (até o VOLTAR) fica visível dentro da lista ao ganhar o foco
	for b in botoes:
		b.grab_focus()
		await _assentar()
		var rb := _rect(b)
		var rr := _rect(rolagem)
		ok(rb.position.y >= rr.position.y - 1.0 and rb.end.y <= rr.end.y + 1.0, "'%s' visível na lista ao focar (%s em %s)" % [b.text, rb, rr])
		ok(rb.end.y <= RODAPE_Y, "'%s' acima do rodapé" % b.text)
		if b.text == "VOLTAR":
			ok(not t._retrato.visible, "VOLTAR não mostra retrato")
			continue
		ok(t._retrato.visible, "'%s' mostra retrato" % b.text)
		_dentro(t._retrato, painel_r, "retrato de " + b.text)
		_dentro(t._nome, painel_r, "nome de " + b.text)
		_dentro(t._info, painel_r, "info de " + b.text)
		_dentro(t._detalhe, painel_r, "detalhe de " + b.text)
		_cabe(t._info, "info de " + b.text)
		_cabe(t._detalhe, "detalhe de " + b.text)
		_retrato_certo(t, b.text)
	# o pior caso do detalhe (Melhorias + 4 efeitos + último mapa): 6 linhas de 16 px cabem
	t._detalhe.text = "Melhorias:\n- a\n- b\n- c\n- d\nÚltimo mapa: Floresta"
	_cabe(t._detalhe, "detalhe com 6 linhas")
	t.queue_free()
	await get_tree().process_frame


func _retrato_certo(t, nome: String) -> void:
	var tex = t._retrato.texture
	ok(tex is AtlasTexture, "retrato de %s é um quadro (AtlasTexture), não a imagem inteira" % nome)
	if not tex is AtlasTexture:
		return
	var reg: Rect2 = tex.region
	ok(reg.position == Vector2.ZERO, "retrato de %s é o primeiro quadro" % nome)
	ok(reg.size.x <= reg.size.y * 1.0 + 0.5 and reg.size.y > 0, "retrato de %s tem proporção de quadro (%s), não de tira" % [nome, reg.size])
	var esc: float = t._retrato.size.x / reg.size.x
	ok(is_equal_approx(esc, roundf(esc)) and esc >= 1.0, "retrato de %s em escala inteira (%s)" % [nome, esc])
	ok(is_equal_approx(t._retrato.size.y, reg.size.y * esc), "retrato de %s sem distorção" % nome)
	ok(absf(t._retrato.position.x + t._retrato.size.x / 2.0 - 682.0) < 1.0, "retrato de %s centrado no eixo da ficha" % nome)


func _lista() -> void:
	Personagens.criar("Breno", "hazaki")
	Personagens.criar("Lucas", "lucas")
	var t = Tela.instantiate()
	add_child(t)
	await _assentar()
	var painel_r := Rect2()
	for f in t.get_children():
		if f is Panel:
			painel_r = _rect(f)
	for b in t._lista.get_children():
		b.grab_focus()
		await _assentar()
		if b.text == "NOVO PERSONAGEM":
			ok(not t._retrato.visible, "NOVO PERSONAGEM não mostra retrato")
			continue
		_retrato_certo(t, b.text)
		_dentro(t._detalhe, painel_r, "detalhe de " + b.text)
		_cabe(t._info, "info de " + b.text)
		_cabe(t._detalhe, "detalhe de " + b.text)
	t.queue_free()
	await get_tree().process_frame
