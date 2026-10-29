extends "res://testes/isolamento_v2.gd"
# Teste automático das frases do Breno (dados/v2_meta.json) que existiam no dado e não apareciam na tela (LOGBOOK de 23/10):
# a frase de cada conquista e a do prêmio dela (Pesadelo, Rastro de katana, melhorias). Confere, no nó certo de cada tela e sem
# estourar a caixa de texto: o Códice do santuário (salao.gd: rótulo "frase" de cada linha), o rodapé da lista de Conquistas da
# pausa (pausa.gd: _ajuda) e o tooltip do Pesadelo e do Rastro de katana no santuário (altar.gd), com o detalhe sem a frase.
# Usa saves TEMPORÁRIOS (meta, personagens e opções); o save real da meta não é tocado (conferência por md5).
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_frases_na_tela.tscn  (imprime "v2_frases_na_tela falhas=0")

const Meta := preload("res://v2/meta.gd")
const Paleta := preload("res://v2/paleta.gd")
const Conquistas := preload("res://v2/conquistas.gd")
const Personagens := preload("res://v2/personagens.gd")
const Salao := preload("res://v2/salao.tscn")
const SalaoGd := preload("res://v2/salao.gd")
const Altar := preload("res://v2/altar.tscn")
const Mundo := preload("res://v2/mundo.tscn")
const PASTA := "user://testes_v2/v2_frases_na_tela/"
const SAVE_TESTE := PASTA + "teste_v2_frases_na_tela_meta.cfg"
const OPCOES_TESTE := PASTA + "teste_v2_frases_na_tela_opcoes.cfg"
const SAVE_REAL := PASTA + "v2_progresso.cfg"

const DETALHE_H := 54.0  # a caixa do detalhe no santuário (altar.gd: Rect2(48, 386, 384, 54))

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var md5_real := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	Meta.caminho_save = SAVE_TESTE
	Config.arquivo = OPCOES_TESTE
	Personagens.caminho_base = PASTA + "teste_v2_frases_na_tela_p"
	Personagens.caminho_indice = PASTA + "teste_v2_frases_na_tela_personagens.cfg"
	Personagens.caminho_antigo = PASTA + "teste_v2_frases_na_tela_antigo.cfg"
	_limpar()
	_dados()
	await _codice()
	await _pausa()
	await _altar()
	_limpar()
	var depois := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	ok(md5_real == depois, "o save real da meta nao foi tocado")
	print("v2_frases_na_tela falhas=%d" % falhas)
	get_tree().quit()


func _limpar() -> void:
	get_tree().paused = false
	for f in DirAccess.get_files_at(PASTA):
		if f.begins_with("teste_v2_frases_na_tela_"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PASTA + f))


func _linha(linhas: Array, id: String) -> Dictionary:
	for l in linhas:
		if str(l.id) == id:
			return l
	return {}


## As conquistas do catálogo que têm frase (a conta do teste não pode ficar em zero sem ninguém perceber).
func _com_frase() -> Array:
	return Meta.conquistas().filter(func(c): return str(c.get("frase", "")) != "")


## O dado: cada conquista com frase a entrega na linha, e o prêmio que é item (Pesadelo, Rastro de katana) entrega a dele.
func _dados() -> void:
	var linhas := Conquistas.linhas()
	ok(_com_frase().size() >= 17, "o catalogo tem as frases das conquistas (%d)" % _com_frase().size())
	for c in Meta.conquistas():
		var l := _linha(linhas, str(c.id))
		ok(str(l.frase) == str(c.get("frase", "")), "a linha traz a frase de " + str(c.id))
	var pesadelo: Dictionary = Meta.item_extra("modo", "pesadelo")
	var rastro: Dictionary = Meta.item_extra("visual", "rastro_katana")
	ok(str(pesadelo.get("frase", "")) != "" and str(rastro.get("frase", "")) != "", "Pesadelo e Rastro de katana tem frase no catalogo")
	ok(str(_linha(linhas, "derrota_chefe").frase_premio) == str(pesadelo.frase), "o premio de Derrote o chefe entrega a frase do Pesadelo")
	ok(str(_linha(linhas, "combo_50").frase_premio) == str(rastro.frase), "o premio de Combo de cinquenta entrega a frase do Rastro de katana")
	ok(str(_linha(linhas, "vence_medio").frase_premio) == "", "premio sem item nao inventa frase")


## O Códice: o rótulo "frase" de cada linha tem o texto do catálogo, numa linha, dentro da coluna do nome e da altura da linha.
func _codice() -> void:
	Personagens.ativar(Personagens.criar("Teste"))
	Meta.registrar_partida({"tempo": 320.0, "maior_combo": 33})  # ativar() aponta a meta para o save do personagem
	var s = Salao.instantiate()
	add_child(s)
	await get_tree().process_frame
	s.abrir_estrutura("codice")
	await get_tree().process_frame
	var vistas := 0
	for i in s._p_itens.size():
		var l: Dictionary = s._p_itens[i]
		var b: Button = s._p_lista.get_child(i)
		var rotulo: Label = b.get_node_or_null("frase")
		if str(l.frase) == "":
			ok(rotulo == null, "sem frase no catalogo, sem rotulo no Codice: " + str(l.id))
			ok(
				b.custom_minimum_size.y == SalaoGd.LINHA_CONQUISTA + SalaoGd.LINHA_LORE * l.lore.size(),
				"sem frase, a linha de %s nao ganha os 20 px a mais" % l.id
			)
			continue
		ok(
			b.custom_minimum_size.y == SalaoGd.LINHA_CONQUISTA + SalaoGd.LINHA_FRASE + SalaoGd.LINHA_LORE * l.lore.size(),
			"com frase, a linha de %s ganha os 20 px" % l.id
		)
		vistas += 1
		ok(rotulo != null and rotulo.text == str(l.frase), "o Codice mostra a frase de " + str(l.id))
		if rotulo == null:
			continue
		var fonte: Font = rotulo.get_theme_font("font")
		var larg := fonte.get_string_size(rotulo.text, HORIZONTAL_ALIGNMENT_LEFT, -1, rotulo.get_theme_font_size("font_size")).x
		ok(larg <= rotulo.size.x, "a frase de %s cabe na coluna do nome (%.0f de %.0f px)" % [l.id, larg, rotulo.size.x])
		ok(rotulo.get_line_count() == 1, "a frase de %s fica numa linha so (%d)" % [l.id, rotulo.get_line_count()])
		var fazer: Label = null
		for f in b.get_children():
			if f is Label and f.text == str(l.fazer):
				fazer = f
		if fazer == null:
			ok(false, "o Codice tem o rotulo do que fazer de " + str(l.id))
			continue
		# Geometria pelas ORIGENS dos rótulos. A caixa do Label e a altura da linha NÃO servem aqui: com --headless a fonte Spleen mede o dobro
		# (get_line_height 32 e Label de 32 px; no jogo de verdade são 16 px de linha, 12 de ascent, e o rótulo fica nos 22 px de Rect2).
		# Medido no jogo com janela: tinta do "o que fazer" em y 45..59, da frase em y 67..81, folga mínima de 8 px, e a linha tem 92 px.
		var altura_texto: float = Paleta.TEXTO_TAMANHO + 4.0  # a linha de 16 px mais a descida das letras
		ok(
			rotulo.position.y - fazer.position.y >= altura_texto,
			"a frase de %s comeca embaixo do que fazer (%.0f px abaixo, minimo %.0f)" % [l.id, rotulo.position.y - fazer.position.y, altura_texto]
		)
		var fundo_linha: float = b.custom_minimum_size.y - SalaoGd.LINHA_LORE * l.lore.size()
		ok(
			rotulo.position.y + altura_texto <= fundo_linha,
			"a frase de %s fica dentro da linha (%.0f de %.0f px)" % [l.id, rotulo.position.y + altura_texto, fundo_linha]
		)
		ok(rotulo.position.x == fazer.position.x and rotulo.size.x == fazer.size.x, "a frase de %s fica na mesma coluna do que fazer" % l.id)
	ok(vistas == _com_frase().size(), "o Codice mostrou todas as frases do catalogo (%d de %d)" % [vistas, _com_frase().size()])
	s._fechar_painel()
	s.queue_free()
	await get_tree().process_frame


## A pausa: ao focar cada conquista, o rodapé traz a frase dela; Derrote o chefe traz a do Pesadelo e Combo de cinquenta a do Rastro; tudo cabe.
func _pausa() -> void:
	Meta.caminho_save = SAVE_TESTE
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	var pausa = null
	for c in mundo.ui.get_children():
		if c.has_method("abrir_sair"):
			pausa = c
	ok(pausa != null and pausa.pausar(), "a pausa abre")
	pausa._executar("conquistas", 0)
	ok(pausa.tela == "conquistas", "a pausa abre a lista de conquistas")
	var linhas := Conquistas.linhas()
	var vistas := 0
	for i in linhas.size():
		var l: Dictionary = linhas[i]
		pausa.sel = i
		pausa._desenhar()
		var ajuda: String = pausa._ajuda.text
		if str(l.frase) != "":
			vistas += 1
			ok(ajuda.begins_with(str(l.frase)), "o rodape da pausa abre com a frase de " + str(l.id))
		ok(ajuda.contains(str(l.fazer)), "o rodape da pausa continua dizendo o que fazer em " + str(l.id))
		if str(l.frase_premio) != "":
			ok(ajuda.contains("Prêmio: %s — %s" % [l.premio, l.frase_premio]), "o rodape da pausa mostra o premio e a frase dele em " + str(l.id))
		await get_tree().process_frame
		var altura: float = pausa._ajuda.get_line_count() * pausa._ajuda.get_line_height()
		ok(
			altura <= pausa.AJUDA_H,
			"o rodape de %s cabe nas %s px da ajuda (%d linhas, %.0f px)" % [l.id, pausa.AJUDA_H, pausa._ajuda.get_line_count(), altura]
		)
	ok(vistas == _com_frase().size(), "a pausa mostrou todas as frases do catalogo (%d de %d)" % [vistas, _com_frase().size()])
	pausa.fechar()
	mundo.queue_free()
	await get_tree().process_frame


## O santuário com os botões do Pesadelo e do Rastro de katana: o tooltip traz a frase; o detalhe fica como era e tem que caber na caixa.
func _altar() -> void:
	Meta.caminho_save = SAVE_TESTE
	Meta.registrar_partida({"tempo": 100.0, "venceu": true, "mapa": "floresta", "maior_combo": 60, "mapa_vencido_agora": false})
	ok(Meta.liberado("modo", "pesadelo") and Meta.liberado("visual", "rastro_katana"), "as duas conquistas liberam o Pesadelo e o Rastro")
	get_tree().current_scene = null
	Engine.set_meta("kikiu_entrada", true)
	get_tree().change_scene_to_packed(Altar)
	for i in 3:
		await get_tree().process_frame
	var a = get_tree().current_scene
	ok(a != null and a.scene_file_path == "res://v2/altar.tscn", "abre o santuario")
	for par in [[a._modo_btn, "modo", "pesadelo"], [a._rastro_btn, "visual", "rastro_katana"]]:
		var item: Dictionary = Meta.item_extra(par[1], par[2])
		var b: Button = par[0]
		ok(b.visible, "o botao de %s aparece liberado" % par[2])
		ok(b.tooltip_text.contains(str(item.frase)), "o tooltip de %s traz a frase" % par[2])
		b.focus_entered.emit()
		await get_tree().process_frame
		# A frase fica só no tooltip: a caixa do detalhe (384x54 px, 3 linhas) já não comporta o efeito do Pesadelo (5 linhas no jogo), então o
		# detalhe tem que seguir IDÊNTICO ao de antes, sem a frase, para não piorar. (Cabe ou não cabe só se vê com janela: headless mede a fonte em dobro.)
		var texto: String = a._detalhe.text
		ok(texto == "%s\n%s" % [item.nome, Meta.texto_item(item)], "o detalhe de %s segue como antes: o nome e o texto do efeito" % par[2])
		ok(not texto.contains(str(item.frase)), "o detalhe de %s nao leva a frase (ela vai so no tooltip)" % par[2])
		ok(b.tooltip_text.begins_with(str(item.nome) + "\n" + str(item.frase)), "o tooltip de %s abre com o nome e a frase" % par[2])
		ok(b.tooltip_text.ends_with(Meta.texto_item(item)), "o tooltip de %s termina com o efeito" % par[2])
	a.queue_free()
	await get_tree().process_frame
