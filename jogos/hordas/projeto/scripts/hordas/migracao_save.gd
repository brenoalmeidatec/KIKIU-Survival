extends Node
## Primeiro autoload do jogo: leva o save da pasta antiga do Godot para a pasta própria "kikiu" (application/config/use_custom_user_dir),
## ANTES de qualquer outro autoload ler user://. Roda no _init, então vem antes do _ready de Config, Meta etc.
##
## Pasta nova (user://):  Windows %APPDATA%\kikiu   Linux $XDG_DATA_HOME/kikiu (ou ~/.local/share/kikiu)   macOS ~/Library/Application Support/kikiu
## Pasta antiga:          Windows %APPDATA%\Godot\app_userdata\K.I.K.I.U   Linux $XDG_DATA_HOME/godot/app_userdata/K.I.K.I.U (ou ~/.local/share/...)
##                        macOS ~/Library/Application Support/Godot/app_userdata/K.I.K.I.U
## Regra: se a pasta nova ainda não tem nenhum arquivo (as subpastas que o motor cria, como logs/, não contam) e a antiga existe, COPIA
## tudo (menos caches e lixo de teste) e grava o marcador MARCADOR. A antiga fica intacta (é o backup). Se a nova já tem arquivos, não
## copia nada: nunca sobrescreve nem mistura. Com o marcador, não faz mais nada. Sem pasta antiga, não grava nada.

const MARCADOR := "migrado_da_pasta_godot.txt"
const NOME_ANTIGO := "K.I.K.I.U"
## Subpastas da antiga que não valem a cópia: cache de shader (o driver refaz) e as pastas de teste.
const IGNORAR := ["shader_cache", "testes_v2", "playtest"]

static var ultimo_resultado := ""  # "" (nada a fazer), "copiado", "nova_ja_tem_arquivos" ou "marcado": para os testes e o log


func _init() -> void:
	var antiga := pasta_antiga(OS.get_name(), OS.get_environment("APPDATA"), OS.get_environment("XDG_DATA_HOME"), OS.get_environment("HOME"))
	if antiga == "":
		return
	var n := migrar(antiga, OS.get_user_data_dir())
	if n > 0:
		print("MigracaoSave: %d arquivo(s) copiado(s) de %s para %s (a pasta antiga ficou como estava)." % [n, antiga, OS.get_user_data_dir()])


## A pasta de user:// do Godot padrão (antes de use_custom_user_dir) para o sistema `so` (OS.get_name()). "" se não dá para calcular.
static func pasta_antiga(so: String, appdata: String, xdg_data_home: String, home: String) -> String:
	match so:
		"Windows":
			return appdata.path_join("Godot").path_join("app_userdata").path_join(NOME_ANTIGO) if appdata != "" else ""
		"macOS":
			return home.path_join("Library/Application Support/Godot/app_userdata").path_join(NOME_ANTIGO) if home != "" else ""
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			var base := xdg_data_home if xdg_data_home != "" else (home.path_join(".local/share") if home != "" else "")
			return base.path_join("godot/app_userdata").path_join(NOME_ANTIGO) if base != "" else ""
	return ""


## Copia `antiga` para `nova` se couber (regra no topo). Devolve quantos arquivos copiou (0 = nada a fazer). Caminhos absolutos do sistema.
static func migrar(antiga: String, nova: String) -> int:
	ultimo_resultado = ""
	if antiga.simplify_path() == nova.simplify_path() or not DirAccess.dir_exists_absolute(antiga):
		return 0
	if FileAccess.file_exists(nova.path_join(MARCADOR)):
		ultimo_resultado = "marcado"
		return 0
	if _tem_arquivos(nova):
		ultimo_resultado = "nova_ja_tem_arquivos"
		return 0
	DirAccess.make_dir_recursive_absolute(nova)
	var n := _copiar(antiga, nova)
	var f := FileAccess.open(nova.path_join(MARCADOR), FileAccess.WRITE)
	if f != null:
		f.store_string(
			(
				"Copiado de %s em %s (%d arquivos). A pasta antiga continua lá como backup; pode apagá-la quando quiser.\n"
				% [antiga, Time.get_datetime_string_from_system(), n]
			)
		)
		f.close()
	ultimo_resultado = "copiado"
	return n


static func _tem_arquivos(pasta: String) -> bool:
	var d := DirAccess.open(pasta)
	return d != null and not d.get_files().is_empty()


## Copia os arquivos e as subpastas (menos IGNORAR na raiz). Devolve quantos arquivos copiou.
static func _copiar(de: String, para: String, raiz := true) -> int:
	var d := DirAccess.open(de)
	if d == null:
		return 0
	DirAccess.make_dir_recursive_absolute(para)
	var n := 0
	for arquivo in d.get_files():
		if DirAccess.copy_absolute(de.path_join(arquivo), para.path_join(arquivo)) == OK:
			n += 1
		else:
			push_warning("MigracaoSave: não copiou " + de.path_join(arquivo))
	for sub in d.get_directories():
		if raiz and sub in IGNORAR:
			continue
		n += _copiar(de.path_join(sub), para.path_join(sub), false)
	return n
