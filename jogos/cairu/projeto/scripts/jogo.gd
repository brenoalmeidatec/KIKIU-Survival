extends Node
## Estado global do jogo (autoload "Jogo"): opções, histórico de falas,
## música/efeitos sonoros, progresso dos capítulos e o arquivo de salvamento.

signal opcoes_mudaram

const ARQ_OPCOES := "user://opcoes.json"
const ARQ_SAVE := "user://save.json"            # formato antigo (1 save só): vira o Jogo 1
const ARQ_PROGRESSO := "user://progresso.json"  # formato antigo
const PASTA_SAVES := "user://saves"
const SLOTS := 3
const VELOCIDADES := [20.0, 40.0, 80.0, 100000.0]
const NOMES_VEL := ["Lenta", "Normal", "Rápida", "Na hora"]

var opcoes := {"musica": 0.6, "efeitos": 0.8, "tela_cheia": false, "vel_texto": 1, "arte": "nova", "visual": true,
	"qualidade": "alta", "voz": true}
const QUALIDADES := ["alta", "media", "baixa"]
const NOMES_QUALIDADE := {"alta": "Alta", "media": "Média", "baixa": "Baixa (PC fraco)"}
var progresso := {"liberados": [], "completos": []}   # do jogo salvo que está em uso
var slot := 1                      # jogo salvo em uso (1 a SLOTS)
var _dados_slot := {}              # {capitulos: {arquivo: estado}, atual, progresso, data}
var historico: Array = []          # [{quem, texto}] das últimas falas

var _musica_atual := ""
var _players_musica: Array[AudioStreamPlayer] = []
var _musica_ativa := 0
var _players_efeito: Array[AudioStreamPlayer] = []
var _proximo_efeito := 0
var _cache_som := {}
var _player_voz := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for nome in ["Musica", "Efeitos"]:
		if AudioServer.get_bus_index(nome) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, nome)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Musica"
		add_child(p)
		_players_musica.append(p)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Efeitos"
		add_child(p)
		_players_efeito.append(p)
	_player_voz.bus = "Efeitos"
	add_child(_player_voz)
	_carregar_opcoes()
	_carregar_progresso()
	aplicar_opcoes()


# ======================================================== opções

func _carregar_opcoes() -> void:
	var d = _ler(ARQ_OPCOES)
	if d is Dictionary:
		if not d.has("qualidade") and d.get("visual", true) == false:
			d["qualidade"] = "baixa"   # opção antiga "Efeitos tela: Não"
		opcoes.merge(d, true)


func salvar_opcoes() -> void:
	_gravar(ARQ_OPCOES, opcoes)


func aplicar_opcoes() -> void:
	if not opcoes.get("qualidade", "alta") in QUALIDADES:
		opcoes.qualidade = "alta"
	opcoes.visual = opcoes.qualidade != "baixa"   # Visual.ligado() lê isto
	Engine.max_fps = 0 if opcoes.qualidade == "alta" else 60
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Musica"), linear_to_db(max(opcoes.musica, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Efeitos"), linear_to_db(max(opcoes.efeitos, 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Musica"), opcoes.musica <= 0.001)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Efeitos"), opcoes.efeitos <= 0.001)
	if DisplayServer.get_name() != "headless":
		var cheia := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if cheia != bool(opcoes.tela_cheia):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if opcoes.tela_cheia else DisplayServer.WINDOW_MODE_WINDOWED)
	opcoes_mudaram.emit()


func vel_texto() -> float:
	return VELOCIDADES[clampi(int(opcoes.vel_texto), 0, VELOCIDADES.size() - 1)]


# ======================================================== histórico de falas

func registrar_fala(quem: String, texto: String) -> void:
	historico.append({"quem": quem, "texto": texto})
	while historico.size() > 100:
		historico.pop_front()


# ======================================================== som

## Música de fundo em loop, com troca suave. "" para silêncio.
func tocar_musica(nome: String, tempo := 0.8) -> void:
	if nome == _musica_atual:
		return
	_musica_atual = nome
	var velho := _players_musica[_musica_ativa]
	_musica_ativa = 1 - _musica_ativa
	var novo := _players_musica[_musica_ativa]
	if velho.playing:
		var tw := create_tween()
		tw.tween_property(velho, "volume_db", -40.0, tempo)
		tw.tween_callback(velho.stop)
	if nome != "":
		var s := _som("musica", nome)
		if s:
			_ligar_loop(s)
			novo.stream = s
			novo.volume_db = -40.0
			novo.play()
			create_tween().tween_property(novo, "volume_db", 0.0, tempo)


## Voz gravada de uma fala: audio/vozes/<quem>_<código>.ogg (ou .wav). O código vem do
## próprio texto (o mesmo texto = o mesmo arquivo; mudou a fala, precisa gravar de novo).
## A lista de falas com o nome de cada arquivo sai com  JOGO.exe --listar_vozes breno
static func chave_voz(quem: String, texto: String) -> String:
	var t := RegEx.create_from_string("\\[[^\\]]*\\]").sub(texto, "", true)
	t = t.replace("*", "").replace("~", "").strip_edges().to_lower()
	if t.begins_with("(") and t.ends_with(")"):
		t = t.substr(1, t.length() - 2).strip_edges()
	t = " ".join(Array(t.split(" ", false)))
	return "%s_%s" % [quem, t.md5_text().substr(0, 8)]


## Toca a voz da fala, se existir e a opção "Voz" estiver ligada. Devolve quantos
## segundos ela dura (0 = não tem voz, aí o jogo usa o "blip" de sempre).
func tocar_voz(quem: String, texto: String, arquivo := "") -> float:
	parar_voz()
	if not opcoes.get("voz", true) or quem == "*" or texto.strip_edges() == "":
		return 0.0
	var s := _som("vozes", arquivo if arquivo != "" else chave_voz(quem, texto))
	if s == null:
		return 0.0
	_player_voz.stream = s
	_player_voz.play()
	return s.get_length()


func parar_voz() -> void:
	if _player_voz.playing:
		_player_voz.stop()


func voz_tocando() -> bool:
	return _player_voz.playing


func musica_atual() -> String:
	return _musica_atual


## Efeito sonoro curto. "variar" muda um pouco o tom (bom pra passos e blips).
func som(nome: String, volume_db := 0.0, variar := 0.0, tom := 1.0) -> void:
	var s := _som("efeitos", nome)
	if s == null:
		return
	var p := _players_efeito[_proximo_efeito]
	_proximo_efeito = (_proximo_efeito + 1) % _players_efeito.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = tom * (1.0 + randf_range(-variar, variar))
	p.play()


func _som(pasta: String, nome: String) -> AudioStream:
	var chave := pasta + "/" + nome
	if _cache_som.has(chave):
		return _cache_som[chave]
	var s: AudioStream = null
	var ext := Dados.pasta_audio_externa()
	if ext != "":
		for e in ["ogg", "wav"]:
			var p := ext.path_join(pasta).path_join(nome + "." + e)
			if FileAccess.file_exists(p):
				s = AudioStreamOggVorbis.load_from_file(p) if e == "ogg" else AudioStreamWAV.load_from_file(p)
				break
	if s == null:
		for e in ["ogg", "wav"]:
			var r := "res://assets/audio/%s/%s.%s" % [pasta, nome, e]
			if ResourceLoader.exists(r):
				s = load(r)
				break
	_cache_som[chave] = s
	return s


func _ligar_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis:
		s.loop = true
	elif s is AudioStreamWAV and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)


# ======================================================== jogos salvos (3) e progresso
## Cada jogo salvo (user://saves/jogo1.json...) guarda onde parou em CADA capítulo
## ("capitulos": {arquivo: estado}), qual foi o último jogado ("atual") e o progresso
## (capítulos liberados e terminados). Dá pra continuar qualquer capítulo de onde parou.

func _carregar_progresso() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA_SAVES))
	_migrar_antigo()
	usar_slot(clampi(int(opcoes.get("ultimo_slot", 1)), 1, SLOTS))


func _arq_slot(n: int) -> String:
	return PASTA_SAVES + "/jogo%d.json" % n


## Save antigo (um só) vira o Jogo 1, uma vez.
func _migrar_antigo() -> void:
	if FileAccess.file_exists(_arq_slot(1)) or not (FileAccess.file_exists(ARQ_SAVE) or FileAccess.file_exists(ARQ_PROGRESSO)):
		return
	var d := {"capitulos": {}, "atual": "", "progresso": {"liberados": [], "completos": []}}
	var prog = _ler(ARQ_PROGRESSO)
	if prog is Dictionary:
		d.progresso.merge(prog, true)
	var antigo = _ler(ARQ_SAVE)
	if antigo is Dictionary and antigo.get("capitulo", "") != "":
		d.capitulos[antigo.capitulo] = antigo
		d.atual = antigo.capitulo
		d["data"] = antigo.get("data", "")
	_gravar(_arq_slot(1), d)


func ler_slot(n: int) -> Dictionary:
	var d = _ler(_arq_slot(n))
	if not d is Dictionary:
		d = {}
	if not d.get("capitulos") is Dictionary:
		d["capitulos"] = {}
	if not d.get("progresso") is Dictionary:
		d["progresso"] = {"liberados": [], "completos": []}
	for k in ["liberados", "completos"]:
		if not d.progresso.get(k) is Array:
			d.progresso[k] = []
	return d


func slot_vazio(n: int) -> bool:
	var d := ler_slot(n)
	return d.capitulos.is_empty() and d.progresso.completos.is_empty()


func usar_slot(n: int) -> void:
	slot = n
	_dados_slot = ler_slot(n)
	progresso = _dados_slot.progresso
	if int(opcoes.get("ultimo_slot", 1)) != n:
		opcoes["ultimo_slot"] = n
		salvar_opcoes()


func _gravar_slot() -> void:
	_dados_slot["data"] = Time.get_datetime_string_from_system(false, true)
	_gravar(_arq_slot(slot), _dados_slot)


func apagar_slot(n: int) -> void:
	if FileAccess.file_exists(_arq_slot(n)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_arq_slot(n)))
	if n == slot:
		usar_slot(n)


func liberado(arquivo: String, indice: int) -> bool:
	return indice == 0 or arquivo in progresso.liberados


func completar_capitulo(arquivo: String, proximo: String) -> void:
	if not arquivo in progresso.completos:
		progresso.completos.append(arquivo)
	if proximo != "" and not proximo in progresso.liberados:
		progresso.liberados.append(proximo)
	_gravar_slot()


## Tem como "Continuar" (o último capítulo jogado tem onde parou).
func tem_save() -> bool:
	return _dados_slot.capitulos.has(str(_dados_slot.get("atual", "")))


## Onde parou no último capítulo jogado ({} se não tiver).
func ler_save() -> Dictionary:
	var e = _dados_slot.capitulos.get(str(_dados_slot.get("atual", "")), {})
	return e if e is Dictionary else {}


## Onde parou num capítulo ({} se nunca jogou ou já terminou).
func save_do_capitulo(arquivo: String) -> Dictionary:
	var e = _dados_slot.capitulos.get(arquivo, {})
	return e if e is Dictionary else {}


func salvar_jogo(dados: Dictionary) -> void:
	dados["data"] = Time.get_datetime_string_from_system(false, true)
	var arq := str(dados.get("capitulo", ""))
	_dados_slot.capitulos[arq] = dados
	_dados_slot["atual"] = arq
	_gravar_slot()


## Esquece onde parou num capítulo (terminou ou vai começar do zero).
func apagar_capitulo(arquivo: String) -> void:
	_dados_slot.capitulos.erase(arquivo)
	if _dados_slot.get("atual", "") == arquivo:
		_dados_slot["atual"] = ""
	_gravar_slot()


## Zera o jogo salvo em uso (os testes usam isto).
func apagar_save() -> void:
	apagar_slot(slot)


## Resumo pra tela de jogos salvos: ["Capítulo 1 - Recepção", "04/10 21:30"] (["vazio", ""] se vazio).
func resumo_slot(n: int) -> Array:
	var d := ler_slot(n)
	if d.capitulos.is_empty() and d.progresso.completos.is_empty():
		return ["vazio", ""]
	var e = d.capitulos.get(str(d.get("atual", "")), {})
	var data := str(d.get("data", "")).replace("T", " ")
	var quando := (data.substr(8, 2) + "/" + data.substr(5, 2) + " às " + data.substr(11, 5)) if data.length() >= 16 else ""
	if e is Dictionary and not e.is_empty():
		return ["%s - %s" % [str(e.get("titulo", "")).split(":")[0], e.get("lugar", "")], quando]
	return ["%d capítulo(s) terminado(s)" % d.progresso.completos.size(), quando]


func _ler(caminho: String) -> Variant:
	if not FileAccess.file_exists(caminho):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(caminho))


func _gravar(caminho: String, dados: Variant) -> void:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dados, "  "))
