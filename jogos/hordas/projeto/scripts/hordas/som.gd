extends Node
## Efeitos sonoros (com limite pra não virar barulho quando tem 500 vírus) e música.

const VOZES := 12
var _players: Array[AudioStreamPlayer] = []
var _musica := AudioStreamPlayer.new()
var _ultimo := {}
var _streams := {}
var volume_efeitos := 0.8
var volume_musica := 0.6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOZES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	add_child(_musica)
	for f in DirAccess.get_files_at("res://assets/audio/efeitos"):
		if f.ends_with(".wav.import") or f.ends_with(".wav"):
			_stream("res://assets/audio/efeitos/" + f.trim_suffix(".import"))


## intervalo = tempo mínimo entre dois sons iguais.
func tocar(nome: String, intervalo := 0.05, tom := 1.0, vol_db := 0.0) -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - float(_ultimo.get(nome, -10.0)) < intervalo:
		return
	_ultimo[nome] = agora
	var s := _stream("res://assets/audio/efeitos/%s.wav" % nome)
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = tom
			p.volume_db = linear_to_db(volume_efeitos) + vol_db
			p.play()
			return


## Sons de interface (#7, conjunto mínimo hover/click/buy/deny dos survivors): cursor, confirmar, voltar, erro, abrir.
## Os arquivos têm volume parecido (RMS ~0,2); o ajuste em dB só compensa o "abrir", que é mais forte. O cursor varia
## o tom em +-5% pra não cansar. Menus e cartas chamam Som.ui(...) em vez de escolher arquivo e tom um por um.
func ui(nome: String) -> void:
	match nome:
		"cursor":
			tocar("cursor", 0.03, randf_range(0.95, 1.05), -6.0)
		"confirmar":
			tocar("confirmar", 0.08, 1.0, -4.0)
		"voltar":
			tocar("blip", 0.08, 0.7, -2.0)
		"erro":
			tocar("erro", 0.12, 1.0, -4.0)
		"abrir":
			tocar("abrir", 0.1, 1.0, -4.0)


func musica(nome: String) -> void:
	var s := _stream("res://assets/audio/musica/%s.ogg" % nome)
	if s == null or (_musica.stream == s and _musica.playing):
		return
	if s is AudioStreamOggVorbis:
		s.loop = true
	_musica.stream = s
	_musica.volume_db = linear_to_db(volume_musica)
	_musica.play()


func parar_musica() -> void:
	_musica.stop()


## Volume mudou nas Opções: a música que já está tocando acompanha na hora.
func atualizar_volume() -> void:
	_musica.volume_db = linear_to_db(volume_musica)


func _stream(caminho: String) -> AudioStream:
	if not _streams.has(caminho):
		_streams[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _streams[caminho]
