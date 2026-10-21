extends RefCounted
## Fixture compartilhada da v2 (#387). Nunca restaura os caminhos do jogador ao terminar: qualquer callback tardio continua no sandbox.
## Config pode chamar preparar_config antes de recarregar as opções; as bases chamam iniciar antes do _ready de cada teste.

const MetaTeste := preload("res://v2/meta.gd")
const SlotsTeste := preload("res://v2/personagens.gd")
const HeroisTeste := preload("res://v2/herois.gd")
const PREFIXO := "user://testes_v2/"
const ENV_CENA := "KIKIU_TESTE_V2_CENA"
const ENV_DONO := "KIKIU_TESTE_V2_DONO"
const ENV_PID := "KIKIU_TESTE_V2_PID_ARQUIVO"

static var raiz := ""
static var _iniciado := false


## CLI da cena de teste; o robô herda a identificação pelo ambiente do processo pai.
static func cena_da_execucao() -> String:
	for arg in OS.get_cmdline_args():
		var nome := str(arg).replace("\\", "/").get_file()
		if nome.begins_with("v2_") and nome.ends_with(".tscn"):
			return nome.get_basename()
	return OS.get_environment(ENV_CENA)


static func _nome_valido(cena: String) -> bool:
	return cena.begins_with("v2_") and cena.is_valid_identifier()


## Gancho ANTES do Config._ready: só aponta os arquivos, sem chamar recarregar recursivamente.
## False no jogo normal, no import e nas cenas da v1. Nenhum arquivo do jogador é lido.
static func preparar_config(config) -> bool:
	var cena := cena_da_execucao()
	if not _nome_valido(cena):
		return false
	return _preparar(cena, config)


static func iniciar(script: String) -> void:
	if _iniciado:
		return
	var cena := script.get_file().get_basename()
	assert(_nome_valido(cena), "Fixture da v2 exige uma cena v2_ identificável")
	var arv := Engine.get_main_loop() as SceneTree
	assert(arv != null, "Fixture da v2 exige SceneTree")
	var config = arv.root.get_node("Config")
	if not _preparar(cena, config):
		return
	# O autoload já pode ter lido as opções antes da base. Relê o arquivo limpo, incluindo temporários e volumes.
	config.recarregar()
	# recarregar detecta o hardware nas cenas com janela; a fixture usa sempre o mesmo perfil.
	config._perfil_padrao = "alto"
	config.aplicar(false)
	MetaTeste.erro_save = false
	HeroisTeste.forcado = ""
	_iniciado = true


static func _preparar(cena: String, config) -> bool:
	if raiz != "":
		return true
	raiz = PREFIXO + cena + "/"
	var dono := OS.get_environment(ENV_DONO)
	var herdado := OS.get_environment(ENV_CENA) == cena and dono != "" and dono != str(OS.get_process_id())
	if herdado:
		raiz += "processo_%d/" % OS.get_process_id()  # o filho não limpa os sentinelas/logs da fixture pai
	# Mesmo se a limpeza ou a criação falhar, nenhum chamador volta aos arquivos do jogador.
	MetaTeste.caminho_save = raiz + "v2_progresso.cfg"
	SlotsTeste.caminho_indice = raiz + "v2_personagens.cfg"
	SlotsTeste.caminho_base = raiz + "v2_personagem_"
	SlotsTeste.caminho_antigo = raiz + "v2_progresso.cfg"
	config.arquivo = raiz + "opcoes.cfg"
	if not _conferir(_limpar_pasta(raiz), "limpar a fixture anterior"):
		return false
	var erro := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(raiz))
	if not _conferir(erro, "criar a fixture"):
		return false
	# v2_playtest pode lançar o filho por um wrapper: seu PID não é o PID real do Godot.
	var pid_arquivo := OS.get_environment(ENV_PID)
	if herdado and pid_arquivo.begins_with(PREFIXO) and not pid_arquivo.contains(".."):
		var f := FileAccess.open(pid_arquivo, FileAccess.WRITE)
		if f == null:
			_conferir(FileAccess.get_open_error(), "identificar o processo filho")
			return false
		f.store_string(str(OS.get_process_id()))
		f.close()
	OS.set_environment(ENV_CENA, cena)
	OS.set_environment(ENV_DONO, str(OS.get_process_id()))
	return true


## Cada teste pode usar seus nomes de arquivos e testar migração/erro de gravação dentro desta pasta.
static func arquivo(nome: String) -> String:
	assert(raiz != "" and not nome.is_absolute_path() and not nome.contains(".."), "Arquivo fora da fixture da v2")
	return raiz.path_join(nome)


static func finalizar() -> void:
	if raiz != "":
		_conferir(_limpar_pasta(raiz), "remover a fixture ao terminar")


## Erros de FS precisam falhar o processo, mesmo se o teste já imprimiu falhas=0 antes do _exit_tree.
static func _conferir(erro: Error, operacao: String) -> bool:
	if erro == OK:
		return true
	var mensagem := "Fixture da v2: não foi possível %s (erro %d, %s)" % [operacao, erro, raiz]
	var arv := Engine.get_main_loop() as SceneTree
	if arv != null:
		arv.quit(1)
	assert(false, mensagem)
	return false


static func _limpar_pasta(pasta: String) -> Error:
	if not pasta.begins_with(PREFIXO) or pasta == PREFIXO or pasta.contains(".."):
		return ERR_INVALID_PARAMETER
	var absoluta := ProjectSettings.globalize_path(pasta)
	if not DirAccess.dir_exists_absolute(absoluta):
		return OK
	var dir := DirAccess.open(absoluta)
	if dir == null:
		return DirAccess.get_open_error()
	dir.include_hidden = true
	dir.include_navigational = false
	for nome in dir.get_directories():
		var erro := _limpar_pasta(pasta.path_join(nome) + "/")
		if erro != OK:
			return erro
	for nome in dir.get_files():
		var erro := DirAccess.remove_absolute(absoluta.path_join(nome))
		if erro != OK:
			return erro
	dir = null
	return DirAccess.remove_absolute(absoluta)
