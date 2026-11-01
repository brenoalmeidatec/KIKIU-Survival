extends Node
## Fotos da tela PERSONAGENS (v2/personagens_tela.gd) numa janela real (sem --headless). Só o viewport do jogo é salvo.
## Usa índice e saves TEMPORÁRIOS (user://teste_fotos_*): não toca nos personagens do jogador.
## Roda: godot --path jogos/hordas/projeto --resolution 1280x720 res://testes/fotos/personagens_fotos.tscn -- --fotos=PASTA --prefixo=X
## Grava PREFIXO_nomes.png (NOVO PERSONAGEM: os 7 nomes e VOLTAR), PREFIXO_nomes_<n>.png (foco em cada nome: o retrato é o corpo, PER-1b),
## PREFIXO_nomes_fim.png (foco no VOLTAR), PREFIXO_lista.png (2 salvos), PREFIXO_pior_detalhe.png (o pior caso do texto,
## medido com a fonte da janela) e PREFIXO_aviso.png (o aviso de erro entre o título e a ficha).
const Tela := preload("res://v2/personagens.tscn")
const Personagens := preload("res://v2/personagens.gd")
const Layout := preload("res://testes/v2_personagens_layout.gd")

var _pasta := ""
var _prefixo := "foto"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("FOTOS: precisa de janela (rode sem --headless)")
		get_tree().quit()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--prefixo="):
			_prefixo = a.trim_prefix("--prefixo=")
	DirAccess.make_dir_recursive_absolute(_pasta)
	Personagens.caminho_indice = "user://teste_fotos_indice.cfg"
	Personagens.caminho_base = "user://teste_fotos_slot_"
	Personagens.caminho_antigo = "user://teste_fotos_antigo.cfg"
	Config.arquivo = "user://teste_fotos_opcoes.cfg"
	_limpar()
	var t = Tela.instantiate()
	add_child(t)
	await _assentar()
	t._abrir_nomes()
	await _assentar()
	await _foto("nomes")
	for i in t._lista.get_child_count() - 1:  # cada nome (menos o VOLTAR): o retrato de corpo inteiro, no mesmo enquadramento
		t._lista.get_child(i).grab_focus()
		await _assentar()
		await _foto("nomes_%d" % (i + 1))
	var ultimo: Control = t._lista.get_child(t._lista.get_child_count() - 1)
	ultimo.grab_focus()
	await _assentar()
	await _foto("nomes_fim")
	t.queue_free()
	await get_tree().process_frame
	var nomes := Personagens.nomes()
	Personagens.criar(str(nomes[0].nome), Personagens.heroi_do_nome(str(nomes[0].nome)))
	Personagens.criar(str(nomes[1].nome), Personagens.heroi_do_nome(str(nomes[1].nome)))
	t = Tela.instantiate()
	add_child(t)
	await _assentar()
	await _foto("lista")
	# o pior caso do detalhe com o texto real (4 melhorias no máximo e o mapa mais longo), medido pela fonte da janela, e o aviso
	t._detalhe.text = Layout.pior_detalhe()
	await _assentar()
	var linha := Dados.fonte_texto.get_height(16)
	var real := Dados.fonte_texto.get_multiline_string_size(t._detalhe.text, HORIZONTAL_ALIGNMENT_CENTER, t._detalhe.size.x, 16)
	print("PIOR real: %d linhas (%.0f px) na caixa de %.0f px; linha de %.0f px" % [roundi(real.y / linha), real.y, t._detalhe.size.y, linha])
	await _foto("pior_detalhe")
	t._aviso.text = "Não foi possível abrir este personagem."
	await _assentar()
	print("AVISO real: caixa %s, minimo %s; NOME minimo %s" % [t._aviso.size, t._aviso.get_minimum_size(), t._nome.get_minimum_size()])
	await _foto("aviso")
	t.queue_free()
	await get_tree().process_frame
	_limpar()
	print("personagens_fotos em ", _pasta, " janela ", get_window().size)
	get_tree().quit()


func _limpar() -> void:
	for c in [Personagens.caminho_indice, Personagens.caminho_antigo, Config.arquivo]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))
	for i in range(1, 12):
		var c := Personagens.caminho_do_save("p%d" % i)
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))


func _assentar(n := 6) -> void:
	for i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_pasta.path_join("%s_%s.png" % [_prefixo, nome]))
