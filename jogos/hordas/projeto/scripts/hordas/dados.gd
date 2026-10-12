extends Node
const Universais := preload("res://scripts/hordas/universais.gd")
## Lê os arquivos de conteúdo (dados/*.json) e guarda texturas.
## Uma pasta "dados" ao lado do .exe tem prioridade: dá pra editar armas, inimigos e a fase no Bloco de Notas.

var _cache := {}
var _tex := {}
var fonte: Font  # pixel legível (Press Start 2P): números, HUD, depuração e o texto da v1
var fonte_titulo: Font  # títulos em pixel (Jersey 10, OFL): títulos de tela, nomes das cartas, botões grandes. Ver v2/LEIA-ME.md
var fonte_texto: Font  # texto corrido e valores das telas da v2 (Spleen 8x16, BSD-2): descrições, ajuda, números do resultado. Só em 16 ou 32 px (grade da fonte)
var herois_extra := {}  # heróis montados em tempo de execução (criação de personagem, #72): entram na tabela "herois"


func _ready() -> void:
	fonte = load("res://assets/fonte/PressStart2P.ttf")
	# sem ligaduras: a ligadura "fi" da Press Start 2P desenha um "ñ" ("Afiadas" saía "Añadas", "final" saía "ñnal")
	var ts := TextServerManager.get_primary_interface()
	if fonte is FontFile:
		(fonte as FontFile).opentype_feature_overrides = {ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0}
	fonte_titulo = load("res://assets/fonte/jersey10/Jersey10-Regular.ttf")
	if fonte_titulo is FontFile:
		(fonte_titulo as FontFile).opentype_feature_overrides = {ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0}
	fonte_texto = load("res://assets/fonte/spleen/spleen-8x16.otf")
	if fonte_texto is FontFile:
		(fonte_texto as FontFile).opentype_feature_overrides = {ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0}
	ThemeDB.get_default_theme().default_font = fonte
	ThemeDB.get_default_theme().default_font_size = 8
	# carrega tudo antes pra não engasgar no meio da partida
	for f in DirAccess.get_files_at("res://assets/gerado"):
		if f.ends_with(".png.import") or f.ends_with(".png"):
			tex(f.get_basename().get_basename() if f.ends_with(".import") else f.get_basename())

	for pasta in DirAccess.get_directories_at("res://assets/personagens"):
		tex_personagem(pasta, "andando_8")
		tex_personagem(pasta, "rosto")


## Linha de versão (título, Opções e pausa): "Versão 0.1.0 · 07/10/2026 · 20bf57a". A versão é a de project.godot
## (application/config/version, à mão); data e commit vêm de dados/versao.json, que o addon kikiu_versao escreve a cada
## exportação (o gerar_versao.sh também). Sem o arquivo (rodando pelo editor, sem exportar) fica "· dev".
static func texto_versao() -> String:
	var v := "Versão " + str(ProjectSettings.get_setting("application/config/version", "?"))
	var f := FileAccess.open("res://dados/versao.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	if d is Dictionary and str(d.get("data", "")) != "" and str(d.get("commit", "")) != "":
		var p := str(d.data).split("-")  # "2026-10-07" vira 07/10/2026
		var data: String = "%s/%s/%s" % [p[2], p[1], p[0]] if p.size() == 3 else str(d.data)
		return "%s · %s · %s" % [v, data, d.commit]
	return v + " · dev"


func json(nome: String) -> Dictionary:
	if _cache.has(nome):
		return _cache[nome]
	var fora := OS.get_executable_path().get_base_dir().path_join("dados").path_join(nome + ".json")
	var caminho := fora if not OS.has_feature("editor") and FileAccess.file_exists(fora) else "res://dados/%s.json" % nome
	var d = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not d is Dictionary:
		push_error("Arquivo com erro: " + caminho)
		d = {}
	if nome == "armas":
		Universais.injetar(d)  # #115: armas universais e suas variações entram na mesma tabela
	if nome == "herois":
		d.merge(herois_extra, true)  # os criados continuam na tabela depois de recarregar()
	_cache[nome] = d
	return d


func recarregar() -> void:
	_cache.clear()


## Põe um herói montado em tempo de execução na tabela "herois" (mesmo formato do herois.json).
func registrar_heroi(id: String, h: Dictionary) -> void:
	herois_extra[id] = h
	if _cache.has("herois"):
		_cache["herois"][id] = h


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
