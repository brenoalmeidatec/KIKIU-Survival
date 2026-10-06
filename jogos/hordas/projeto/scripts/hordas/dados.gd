extends Node
## Lê os arquivos de conteúdo (dados/*.json) e guarda texturas.
## Uma pasta "dados" ao lado do .exe tem prioridade: dá pra editar armas, inimigos e a fase no Bloco de Notas.

var _cache := {}
var _tex := {}
var fonte: Font


func _ready() -> void:
	fonte = load("res://assets/fonte/PressStart2P.ttf")
	# sem ligaduras: a ligadura "fi" da Press Start 2P desenha um "ñ" ("Afiadas" saía "Añadas", "final" saía "ñnal")
	var ts := TextServerManager.get_primary_interface()
	if fonte is FontFile:
		(fonte as FontFile).opentype_feature_overrides = {ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0}
	ThemeDB.get_default_theme().default_font = fonte
	ThemeDB.get_default_theme().default_font_size = 8
	# carrega tudo antes pra não engasgar no meio da partida
	for f in DirAccess.get_files_at("res://assets/gerado"):
		if f.ends_with(".png.import") or f.ends_with(".png"):
			tex(f.get_basename().get_basename() if f.ends_with(".import") else f.get_basename())


	for pasta in DirAccess.get_directories_at("res://assets/personagens"):
		tex_personagem(pasta, "andando_8")
		tex_personagem(pasta, "rosto")


func json(nome: String) -> Dictionary:
	if _cache.has(nome):
		return _cache[nome]
	var fora := OS.get_executable_path().get_base_dir().path_join("dados").path_join(nome + ".json")
	var caminho := fora if not OS.has_feature("editor") and FileAccess.file_exists(fora) else "res://dados/%s.json" % nome
	var d = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not d is Dictionary:
		push_error("Arquivo com erro: " + caminho)
		d = {}
	_cache[nome] = d
	return d


func recarregar() -> void:
	_cache.clear()


func tex(nome: String) -> Texture2D:
	if _tex.has(nome):
		return _tex[nome]
	var caminho := "res://assets/gerado/%s.png" % nome
	var t: Texture2D = load(caminho) if ResourceLoader.exists(caminho) else null
	_tex[nome] = t
	return t


func tex_personagem(sprite: String, folha: String) -> Texture2D:
	var chave := sprite + "/" + folha
	if not _tex.has(chave):
		var caminho := "res://assets/personagens/%s/%s.png" % [sprite, folha]
		_tex[chave] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _tex[chave]


func icone(nome: String) -> Texture2D:
	return tex("icone_" + nome)


## Uma arma, passivo ou equipamento pelo id (procura nos três arquivos).
func item(id: String) -> Dictionary:
	var a := json("armas")
	if a.has(id):
		return a[id]
	var e := json("equipamentos")
	if e.has(id) and e[id] is Dictionary:
		return e[id]
	return json("passivos").get(id, {})


func eh_arma(id: String) -> bool:
	return json("armas").has(id)
