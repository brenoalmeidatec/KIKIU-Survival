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
	AmbienteTesteV2.finalizar()
	ok(not DirAccess.dir_exists_absolute(pasta), "limpa todos os arquivos da fixture, incluindo .bak/.tmp")
	print("v2_isolamento falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
