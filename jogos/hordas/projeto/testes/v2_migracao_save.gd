extends "res://testes/isolamento_v2.gd"
# Teste da migração do save da pasta padrão do Godot (app_userdata/K.I.K.I.U) para a pasta própria "kikiu" (scripts/hordas/migracao_save.gd).
# Cobre o cálculo da pasta antiga por sistema (Windows, Linux com e sem XDG_DATA_HOME, macOS), a cópia com pastas temporárias (nada da
# antiga muda, cache e lixo de teste ficam de fora, o marcador é gravado), o segundo boot (não faz nada), a pasta nova que já tem arquivos
# (nunca sobrescreve), a antiga que não existe (não cria nada) e as duas pastas iguais. Também confere que o project.godot liga a pasta própria.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_migracao_save.tscn  (imprime "v2_migracao_save falhas=0")

const Migracao := preload("res://scripts/hordas/migracao_save.gd")
const RAIZ := "user://testes_v2/v2_migracao_save/tmp/"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	_pastas_por_sistema()
	_projeto()
	_copia()
	_nova_com_arquivos()
	_sem_antiga()
	_iguais()
	print("v2_migracao_save falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path(RAIZ + rel)


func _gravar(caminho: String, texto: String) -> void:
	DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


func _ler(caminho: String) -> String:
	return FileAccess.get_file_as_string(caminho)


func _limpar(rel: String) -> void:
	var p := _abs(rel)
	if DirAccess.dir_exists_absolute(p):
		_remover(p)


func _remover(p: String) -> void:
	var d := DirAccess.open(p)
	for a in d.get_files():
		d.remove(a)
	for s in d.get_directories():
		_remover(p.path_join(s))
	DirAccess.remove_absolute(p)


func _pastas_por_sistema() -> void:
	ok(
		Migracao.pasta_antiga("Windows", "C:/Users/x/AppData/Roaming", "", "") == "C:/Users/x/AppData/Roaming/Godot/app_userdata/K.I.K.I.U",
		"Windows: %APPDATA%/Godot/app_userdata/K.I.K.I.U"
	)
	ok(Migracao.pasta_antiga("Windows", "", "", "C:/Users/x") == "", "Windows sem APPDATA: nada a calcular")
	ok(Migracao.pasta_antiga("Linux", "", "/dados", "/home/x") == "/dados/godot/app_userdata/K.I.K.I.U", "Linux com XDG_DATA_HOME")
	ok(Migracao.pasta_antiga("Linux", "", "", "/home/x") == "/home/x/.local/share/godot/app_userdata/K.I.K.I.U", "Linux sem XDG_DATA_HOME: ~/.local/share")
	ok(
		Migracao.pasta_antiga("macOS", "", "", "/Users/x") == "/Users/x/Library/Application Support/Godot/app_userdata/K.I.K.I.U",
		"macOS: Library/Application Support"
	)
	ok(Migracao.pasta_antiga("Linux", "", "", "") == "", "Linux sem HOME: nada a calcular")
	ok(Migracao.pasta_antiga("Android", "", "", "/x") == "", "sistema sem pasta de desktop: nada a calcular")


func _projeto() -> void:
	ok(bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)), "project.godot liga use_custom_user_dir")
	ok(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")) == "kikiu", "a pasta própria se chama kikiu")
	var autoloads: Array = []
	for p in ProjectSettings.get_property_list():
		if str(p.name).begins_with("autoload/"):
			autoloads.append(str(p.name))
	autoloads.sort_custom(func(a, b): return ProjectSettings.get_order(a) < ProjectSettings.get_order(b))
	ok(
		not autoloads.is_empty() and autoloads[0] == "autoload/MigracaoSave",
		"a migração é o primeiro autoload (antes de Config e Meta lerem user://): %s" % str(autoloads.slice(0, 2))
	)


func _copia() -> void:
	_limpar("")
	var antiga := _abs("c/antiga")
	var nova := _abs("c/nova")
	_gravar(antiga.path_join("opcoes.cfg"), "[opcoes]\nmusica=0.3\n")
	_gravar(antiga.path_join("v2_personagens.cfg"), '[geral]\nativo="p1"\n')
	_gravar(antiga.path_join("v2_personagem_p1.cfg"), "[moeda]\nalmas=4242\n")
	_gravar(antiga.path_join("backup/v2_personagem_p1.cfg.bak"), "[moeda]\nalmas=4000\n")
	_gravar(antiga.path_join("shader_cache/x.bin"), "cache")
	_gravar(antiga.path_join("testes_v2/lixo.txt"), "lixo")
	_gravar(antiga.path_join("playtest/meta_1.cfg"), "lixo")
	DirAccess.make_dir_recursive_absolute(nova.path_join("logs"))  # o motor cria logs/ antes de qualquer autoload: pasta vazia não conta
	_gravar(nova.path_join("logs/godot.log"), "log do boot")  # nem arquivo em subpasta
	var antes := {}
	for a in ["opcoes.cfg", "v2_personagens.cfg", "v2_personagem_p1.cfg", "backup/v2_personagem_p1.cfg.bak"]:
		antes[a] = FileAccess.get_md5(antiga.path_join(a))
	var n: int = Migracao.migrar(antiga, nova)
	ok(n == 4, "copiou os 4 arquivos de save (copiou %d)" % n)
	ok(Migracao.ultimo_resultado == "copiado", "resultado: copiado")
	for a in antes:
		ok(FileAccess.file_exists(nova.path_join(a)), "a nova tem " + a)
		ok(FileAccess.get_md5(nova.path_join(a)) == antes[a], "conteúdo igual em " + a)
		ok(FileAccess.get_md5(antiga.path_join(a)) == antes[a], "a antiga não mudou: " + a)
	ok(not DirAccess.dir_exists_absolute(nova.path_join("shader_cache")), "cache de shader não vai")
	ok(
		not DirAccess.dir_exists_absolute(nova.path_join("testes_v2")) and not DirAccess.dir_exists_absolute(nova.path_join("playtest")),
		"lixo de teste não vai"
	)
	ok(DirAccess.dir_exists_absolute(antiga.path_join("shader_cache")), "a antiga segue com o cache (nada apagado)")
	ok(FileAccess.file_exists(nova.path_join(Migracao.MARCADOR)), "marcador de migração gravado")
	# segundo boot: com o marcador não faz nada, mesmo que o jogador já tenha mudado a nova
	_gravar(nova.path_join("opcoes.cfg"), "[opcoes]\nmusica=0.9\n")
	ok(Migracao.migrar(antiga, nova) == 0 and Migracao.ultimo_resultado == "marcado", "segundo boot: marcado, não copia de novo")
	ok(_ler(nova.path_join("opcoes.cfg")) == "[opcoes]\nmusica=0.9\n", "segundo boot: não sobrescreveu o que o jogador mudou")
	_limpar("c")


func _nova_com_arquivos() -> void:
	var antiga := _abs("n/antiga")
	var nova := _abs("n/nova")
	_gravar(antiga.path_join("opcoes.cfg"), "antigo")
	_gravar(nova.path_join("opcoes.cfg"), "novo")
	ok(Migracao.migrar(antiga, nova) == 0, "nova com arquivos: não copia")
	ok(Migracao.ultimo_resultado == "nova_ja_tem_arquivos", "resultado: nova_ja_tem_arquivos")
	ok(_ler(nova.path_join("opcoes.cfg")) == "novo", "nova com arquivos: nada sobrescrito")
	ok(not FileAccess.file_exists(nova.path_join(Migracao.MARCADOR)), "nova com arquivos: sem marcador")
	_limpar("n")


func _sem_antiga() -> void:
	var nova := _abs("s/nova")
	ok(Migracao.migrar(_abs("s/nao_existe"), nova) == 0 and Migracao.ultimo_resultado == "", "sem pasta antiga: nada a fazer")
	ok(not DirAccess.dir_exists_absolute(nova), "sem pasta antiga: não cria a nova nem o marcador")
	_limpar("s")


func _iguais() -> void:
	var p := _abs("i/mesma")
	_gravar(p.path_join("opcoes.cfg"), "x")
	ok(Migracao.migrar(p, p) == 0 and not FileAccess.file_exists(p.path_join(Migracao.MARCADOR)), "pastas iguais: não faz nada")
	_limpar("i")
