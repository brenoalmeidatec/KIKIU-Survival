extends Node
## Fotos da tela PERSONAGENS (v2/personagens_tela.gd) numa janela real (sem --headless). Só o viewport do jogo é salvo.
## Usa índice e saves TEMPORÁRIOS (user://teste_fotos_*): não toca nos personagens do jogador.
## Roda: godot --path jogos/hordas/projeto --resolution 1280x720 res://testes/fotos/personagens_fotos.tscn -- --fotos=PASTA --prefixo=X
## Grava PREFIXO_nomes.png (NOVO PERSONAGEM: os 7 nomes e VOLTAR), PREFIXO_nomes_fim.png (foco no VOLTAR) e PREFIXO_lista.png (2 salvos).
const Tela := preload("res://v2/personagens.tscn")
const Personagens := preload("res://v2/personagens.gd")

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
	t._lista.get_child(1).grab_focus()  # o 2º nome (Nicão) tem rosto: a tira de rostos vira o retrato
	await _assentar()
	await _foto("nomes_rosto")
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
