@tool
extends EditorPlugin
## Carimba a exportação: antes de empacotar, escreve dados/versao.json com a data e o commit (git rev-parse --short HEAD,
## "+" se houver mudança sem commit). Assim o título, as Opções e a pausa mostram de que build é o .exe mesmo quando a
## exportação sai pelo editor e ninguém rodou o gerar_versao.sh. Sem git no PATH, o arquivo atual fica como está.

var _exporta: EditorExportPlugin


func _enter_tree() -> void:
	_exporta = Carimbo.new()
	add_export_plugin(_exporta)


func _exit_tree() -> void:
	remove_export_plugin(_exporta)
	_exporta = null


class Carimbo extends EditorExportPlugin:
	func _get_name() -> String:
		return "KIKIU versão"

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		var pasta := ProjectSettings.globalize_path("res://")
		var commit := _git(pasta, ["rev-parse", "--short", "HEAD"])
		if commit == "":
			push_warning("KIKIU versão: sem git; dados/versao.json fica como estava.")
			return
		if _git(pasta, ["status", "--porcelain", "--untracked-files=no"]) != "":
			commit += "+"
		var f := FileAccess.open("res://dados/versao.json", FileAccess.WRITE)
		if f == null:
			push_warning("KIKIU versão: não consegui escrever dados/versao.json.")
			return
		f.store_string(JSON.stringify({"data": Time.get_date_string_from_system(), "commit": commit}) + "\n")

	func _git(pasta: String, args: PackedStringArray) -> String:
		var saida := []
		var codigo := OS.execute("git", PackedStringArray(["-C", pasta]) + args, saida, true)
		if codigo != 0 or saida.is_empty():
			return ""
		return str(saida[0]).strip_edges()
