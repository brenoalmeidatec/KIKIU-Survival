extends "res://testes/isolamento_v2.gd"
## Contrato da fixture comum: arquivos e resíduos de gravação ficam no diretório desta cena.

const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var pasta := AmbienteTesteV2.raiz
	for arquivo in [Meta.caminho_save, Config.arquivo, Personagens.caminho_indice, Personagens.caminho_base, Personagens.caminho_antigo]:
		ok(arquivo.begins_with(pasta), "caminho dentro da fixture: " + arquivo)
	ok(Meta.saldo() == 0 and Meta.nivel("vida") == 0, "meta começa zerada")
	ok(Personagens.lista().is_empty() and Personagens.ativo() == "", "nenhum slot real é herdado")
	ok(Config.g_perfil() == "alto" and Config.v("tamanho_ui") == "auto", "opções conhecidas sem temporários herdados")
	Meta.creditar(37)
	ok(FileAccess.file_exists(Meta.caminho_save) and Meta.saldo() == 37, "gravação real no save da fixture")
	var nome := Personagens.criar("Breno")
	ok(Personagens.ativar(nome) and Meta.caminho_save.begins_with(pasta), "ativar personagem mantém a meta na fixture")
	Config.definir("musica", 0.1)
	Config.recarregar()
	ok(is_equal_approx(float(Config.v("musica")), 0.1), "opções gravam e releem no próprio diretório")
	# Limpeza inclui diretórios internos, backups e arquivos temporários de uma execução interrompida.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta + "residuos"))
	for sufixo in [".cfg", ".cfg.bak", ".cfg.tmp"]:
		var f := FileAccess.open(pasta + "residuos/antigo" + sufixo, FileAccess.WRITE)
		f.store_string("resíduo de teste")
		f.close()
	_residuos_ocultos(pasta)
	ok(AmbienteTesteV2._limpar_pasta("user://") == ERR_INVALID_PARAMETER, "recusa limpar a raiz user antes de acessar o disco")
	ok(AmbienteTesteV2._limpar_pasta(AmbienteTesteV2.PREFIXO) == ERR_INVALID_PARAMETER, "recusa limpar as fixtures das outras cenas")
	AmbienteTesteV2.finalizar()
	ok(not DirAccess.dir_exists_absolute(pasta), "limpa toda a fixture, incluindo .bak/.tmp e arquivos/pastas ocultos")
	print("v2_isolamento falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _residuos_ocultos(pasta: String) -> void:
	var sub := pasta.path_join(".ocultos")
	ok(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sub)) == OK, "cria subpasta oculta da fixture")
	var oculto := pasta.path_join("residuos/.oculto.cfg")
	for caminho in [sub.path_join("residuo.cfg"), oculto]:
		var f := FileAccess.open(caminho, FileAccess.WRITE)
		ok(f != null, "cria resíduo: " + caminho)
		if f == null:
			return
		f.store_string("resíduo oculto de teste")
		f.close()
	if OS.get_name() == "Windows":  # no Linux o ponto inicial já oculta; no Windows é um atributo do arquivo/pasta
		for caminho in [sub, oculto]:
			ok(FileAccess.set_hidden_attribute(ProjectSettings.globalize_path(caminho), true) == OK, "marca resíduo como oculto no Windows")
	var dir := DirAccess.open(pasta)
	dir.include_hidden = false
	ok(not dir.get_directories().has(".ocultos"), "a subpasta de teste está realmente oculta")
	dir = DirAccess.open(pasta.path_join("residuos"))
	dir.include_hidden = false
	ok(not dir.get_files().has(".oculto.cfg"), "o arquivo de teste está realmente oculto")
