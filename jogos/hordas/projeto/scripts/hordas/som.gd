extends Node
## Efeitos sonoros (com limite pra não virar barulho quando tem 500 vírus) e música.
## A música toca no bus "Musica" (criado aqui, filho do Master): o volume das Opções mora no bus, e o fade entre faixas, nos
## players. Os efeitos seguem no Master, direto.

const VOZES := 12
const BUS_MUSICA := &"Musica"
var _players: Array[AudioStreamPlayer] = []
var _atual := AudioStreamPlayer.new()  # a faixa que toca (ou que está entrando)
var _saida := AudioStreamPlayer.new()  # a faixa que está saindo no crossfade
var _g_atual := 1.0
var _g_saida := 0.0
var duracao_fade := 1.5
var _ultimo := {}
var _streams := {}
var volume_efeitos := 0.8
var volume_musica := 0.6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_garantir_bus()
	_atual.bus = BUS_MUSICA
	_saida.bus = BUS_MUSICA
	for i in VOZES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	add_child(_atual)
	add_child(_saida)
	for f in DirAccess.get_files_at("res://assets/audio/efeitos"):
		if f.ends_with(".wav.import") or f.ends_with(".wav"):
			_stream("res://assets/audio/efeitos/" + f.trim_suffix(".import"))
	atualizar_volume()


## Cria o bus "Musica" (saída no Master) se o projeto ainda não tem um. Sem arquivo de layout: o código é a fonte única.
func _garantir_bus() -> void:
	if AudioServer.get_bus_index(BUS_MUSICA) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS_MUSICA)
	AudioServer.set_bus_send(i, &"Master")


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


## Troca de faixa com crossfade (#63): a nova entra enquanto a velha sai, em potência igual (sem buraco e sem estouro),
## respeitando o volume das Opções. Mesma faixa já tocando: nada acontece. Sem nada tocando, entra direto.
func musica(nome: String) -> void:
	var s := _stream("res://assets/audio/musica/%s.ogg" % nome)
	if s == null or (_atual.stream == s and _atual.playing):
		return
	if s is AudioStreamOggVorbis:
		s.loop = true
	if not _atual.playing or duracao_fade <= 0.0:
		_saida.stop()
		_atual.stream = s
		_g_atual = 1.0
		_atual.play()
		_aplicar_ganhos()
		return
	# já tem música: a que toca vira "saída" e a outra entra. Se já havia uma saída no meio do fade, ela é cortada.
	var antiga := _saida
	_saida = _atual
	_g_saida = _g_atual
	_atual = antiga
	_atual.stop()
	_atual.stream = s
	_g_atual = 0.0
	_atual.play()
	_aplicar_ganhos()


## Carrega a faixa sem tocar (fica no cache do _stream), para a troca no meio da partida não ler o arquivo no quadro.
func preparar_musica(nome: String) -> void:
	_stream("res://assets/audio/musica/%s.ogg" % nome)


func parar_musica() -> void:
	_atual.stop()
	_saida.stop()
	_g_atual = 1.0
	_g_saida = 0.0


## Volume mudou nas Opções (o slider Música): vai direto para o bus, e a faixa que já está tocando acompanha na hora.
## Zero silencia o bus (mute) em vez de depender de -80 dB.
func atualizar_volume() -> void:
	var i := AudioServer.get_bus_index(BUS_MUSICA)
	if i != -1:
		var mudo := volume_musica <= 0.0001
		AudioServer.set_bus_mute(i, mudo)
		AudioServer.set_bus_volume_db(i, -80.0 if mudo else linear_to_db(minf(volume_musica, 1.0)))
	_aplicar_ganhos()


## Estado do crossfade (teste e depuração): se está rolando e o ganho 0..1 de quem entra e de quem sai.
func fade_estado() -> Dictionary:
	return {"ativo": _saida.playing or _g_atual < 1.0, "entra": _g_atual, "sai": _g_saida if _saida.playing else 0.0}


func _process(dt: float) -> void:
	if _g_atual >= 1.0 and not _saida.playing:
		return
	var passo := dt / maxf(duracao_fade, 0.01)
	_g_atual = minf(1.0, _g_atual + passo)
	if _saida.playing:
		_g_saida = maxf(0.0, _g_saida - passo)
		if _g_saida <= 0.0:
			_saida.stop()
	_aplicar_ganhos()


func _aplicar_ganhos() -> void:
	_atual.volume_db = _db(_g_atual)
	_saida.volume_db = _db(_g_saida)


## Ganho 0..1 do fade (curva de potência igual: seno) em dB (nunca -inf). O volume das Opções não entra aqui: é do bus.
func _db(g: float) -> float:
	var amp := sin(clampf(g, 0.0, 1.0) * PI * 0.5)
	return -80.0 if amp <= 0.0001 else linear_to_db(amp)


func _stream(caminho: String) -> AudioStream:
	if not _streams.has(caminho):
		_streams[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _streams[caminho]
