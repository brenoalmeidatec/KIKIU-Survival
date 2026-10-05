class_name Dados
## Carrega os capítulos (arquivos .json) e as imagens dos personagens.
## Se existir uma pasta "capitulos" ao lado do JOGO.exe, ela tem prioridade:
## assim dá pra editar as histórias no Bloco de Notas sem reabrir o Godot.

const NOMES := {
	"breno": "Breno", "nicao": "Nicão", "lucas": "Lucas", "joao": "João",
	"matheus": "Matheus", "beto": "Beto", "lukako": "Lukako", "fabio": "Fábio",
	"mauro": "Seu Mauro",
}

## Ordem dos quadros em assets/personagens/<id>/cena.png (cada um 100x140).
const QUADROS := ["idle_c", "idle_m", "idle_o", "talk1_c", "talk1_m", "talk1_o",
	"talk2_c", "talk2_m", "talk2_o", "point_c", "point_m", "point_o",
	"shrug_c", "shrug_m", "shrug_o", "think_c", "think_m", "think_o",
	"cross_c", "cross_m", "cross_o", "idle_b", "piscar", "laugh_a", "laugh_b",
	"wave_a", "wave_b"]

static var _texturas := {}


static func pasta_externa() -> String:
	if OS.has_feature("editor"):
		return ""
	var p := OS.get_executable_path().get_base_dir().path_join("capitulos")
	return p if DirAccess.dir_exists_absolute(p) else ""


static func ler_json(nome: String) -> Variant:
	var caminho := "res://capitulos/" + nome
	var ext := pasta_externa()
	if ext != "" and FileAccess.file_exists(ext.path_join(nome)):
		caminho = ext.path_join(nome)
	var txt := FileAccess.get_file_as_string(caminho)
	var json := JSON.new()
	if json.parse(txt) != OK:
		push_error("Erro em %s linha %d: %s" % [caminho, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Texto simples da pasta capitulos ("" se não existir).
static func ler_texto(nome: String) -> String:
	var caminho := "res://capitulos/" + nome
	var ext := pasta_externa()
	if ext != "" and FileAccess.file_exists(ext.path_join(nome)):
		caminho = ext.path_join(nome)
	if not FileAccess.file_exists(caminho):
		return ""
	return FileAccess.get_file_as_string(caminho)


## Pasta "audio" ao lado do JOGO.exe (musica/ e efeitos/): troca os sons sem reabrir o Godot.
static func pasta_audio_externa() -> String:
	if OS.has_feature("editor"):
		return ""
	var p := OS.get_executable_path().get_base_dir().path_join("audio")
	return p if DirAccess.dir_exists_absolute(p) else ""


static func capitulos() -> Array:
	var lista := []
	var indice = ler_json("indice.json")
	if indice == null:
		return lista
	for arquivo in indice.get("capitulos", []):
		var cap = ler_json(arquivo)
		if cap != null:
			cap["_arquivo"] = arquivo
			Historia.juntar(cap)   # cenas do <capitulo>.txt por cima das do .json
			lista.append(cap)
	return lista


## Arquivo do capítulo que vem depois deste no indice.json ("" se for o último).
static func proximo_capitulo(arquivo: String) -> String:
	var indice = ler_json("indice.json")
	if indice == null:
		return ""
	var lista: Array = indice.get("capitulos", [])
	var i := lista.find(arquivo)
	return lista[i + 1] if i >= 0 and i + 1 < lista.size() else ""


## Ids de todos os mapas (capitulos/mapas/*.json, dentro do jogo e na pasta ao lado do exe).
static func lista_mapas() -> Array:
	var ids := {}
	var pastas := ["res://capitulos/mapas"]
	var ext := pasta_externa()
	if ext != "":
		pastas.append(ext.path_join("mapas"))
	for p in pastas:
		for f in DirAccess.get_files_at(p):
			if f.ends_with(".json"):
				ids[f.get_basename()] = true
	var l := ids.keys()
	l.sort()
	return l


static func limpar_cache() -> void:
	_texturas.clear()


## Pasta da arte dos personagens. Quando existir "personagens_antigos", a opção
## "Personagens: arte antiga" usa ela (pra comparar com a arte nova).
static func pasta_personagens() -> String:
	var jogo := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Jogo")
	if jogo and jogo.opcoes.get("arte", "nova") == "antiga" and DirAccess.dir_exists_absolute("res://assets/personagens_antigos"):
		return "res://assets/personagens_antigos"
	return "res://assets/personagens"


static func tem_arte_antiga() -> bool:
	return DirAccess.dir_exists_absolute("res://assets/personagens_antigos")


## tipo: "andando", "andando_8", "cena" ou "rosto". Devolve null se o arquivo não existir.
static func textura(personagem: String, tipo: String) -> Texture2D:
	var caminho := "%s/%s/%s.png" % [pasta_personagens(), personagem, tipo]
	if not _texturas.has(caminho):
		_texturas[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _texturas[caminho]


static func nome(personagem: String) -> String:
	return NOMES.get(personagem, personagem.capitalize())


## Índice do quadro de pose; "boca" é c (fechada), m (meio) ou o (aberta).
static func quadro(pose: String, boca: String, alterna: bool) -> int:
	var i := QUADROS.find(pose + "_" + boca)
	if i < 0:
		i = QUADROS.find(pose + ("_b" if alterna else "_a"))
	if i < 0:
		i = QUADROS.find(pose)
	return max(i, 0)


static func mapa(id: String) -> Variant:
	return ler_json("mapas/%s.json" % id)


## Imagem de mapa: primeiro a pasta externa, depois a que veio dentro do jogo.
static var _imagens_ext := {}   # caminho -> [data de modificação, textura]


static func imagem_mapa(arquivo: String) -> Texture2D:
	var ext := pasta_externa()
	if ext != "":
		var p := ext.path_join("mapas").path_join(arquivo)
		if FileAccess.file_exists(p):
			# guardada: não abre o mesmo PNG de novo a cada mapa (24 carteiras = 1 leitura só);
			# se o arquivo mudar no disco, lê de novo
			var quando := FileAccess.get_modified_time(p)
			var c = _imagens_ext.get(p)
			if c != null and c[0] == quando:
				return c[1]
			var img := Image.load_from_file(p)
			if img:
				var t := ImageTexture.create_from_image(img)
				_imagens_ext[p] = [quando, t]
				return t
	var r := "res://capitulos/mapas/" + arquivo
	return load(r) if ResourceLoader.exists(r) else null
