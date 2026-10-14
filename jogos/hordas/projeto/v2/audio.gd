extends Node
## Efeitos sonoros da v2: um punhado de AudioStreamPlayer reaproveitados (nada de nó por som). Os WAV ficam em assets/audio/v2/
## (sons CC0 do Kenney, cortados e normalizados; registro em docs/LICENCAS_AUDIO.md). O gerador sintetizado
## (jogos/hordas/fonte_audio/gerar_v2_sfx.py) ficou como reserva. O volume segue o das Opções (Som.volume_efeitos, o autoload
## do jogo). Sem WAV, tocar() não faz nada.

const PASTA := "res://assets/audio/v2/"
const VOZES := 10

var mudo := false
var tocados := 0  # quantos sons saíram (testes)
var ultimo := ""  # o último som pedido (testes)
var _players: Array[AudioStreamPlayer] = []
var _streams := {}
var _ultimo_t := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOZES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## `intervalo` = tempo mínimo (s, relógio de parede) entre dois sons iguais, para a horda não virar ruído.
func tocar(nome: String, tom := 1.0, vol_db := 0.0, intervalo := 0.04) -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - float(_ultimo_t.get(nome, -10.0)) < intervalo:
		return
	_ultimo_t[nome] = agora
	ultimo = nome
	tocados += 1
	if mudo:
		return
	var s := _stream(nome)
	if s == null:
		return
	var vol := 0.8
	var som := get_node_or_null("/root/Som")
	if som != null:
		vol = float(som.get("volume_efeitos"))
	for p in _players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = tom
			p.volume_db = linear_to_db(maxf(vol, 0.0001)) + vol_db
			p.play()
			return


func _stream(nome: String) -> AudioStream:
	if not _streams.has(nome):
		var c := PASTA + nome + ".wav"
		_streams[nome] = load(c) if ResourceLoader.exists(c) else null
	return _streams[nome]
