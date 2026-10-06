extends Node
## Chat de voz do online (#13). Microfone -> bus mudo com AudioEffectCapture -> 8 kHz mono -> mu-law (8 bits)
## -> pacotes de 60 ms pela rede do jogo (sem garantia de entrega, como telefone) -> cada um toca num
## AudioStreamGenerator por jogador. ~8 KB/s por quem está falando. Sem servidor novo e sem nada pago.
## Opção "Voz" (Config): desligada / apertar V pra falar (padrão) / sempre aberta (só manda quando tem som).
## O microfone só liga quando precisa: segurando V, ou na opção sempre aberta, e só online.

const TAXA := 8000                     # amostras por segundo da voz
const PACOTE := 480                    # amostras por pacote (60 ms)
const MU := 255.0
const LIMIAR := 0.012                  # "sempre aberta": abaixo disso (RMS) é silêncio e não manda
const FALANDO_T := 0.35                # quanto tempo depois do último pacote a pessoa ainda aparece "falando"

var silenciados := {}                  # peer -> true
var recebidos := 0                     # bytes de voz que chegaram (o teste lê)
var enviados := 0
var falando := {}                      # peer -> segundos desde o último pacote (o lobby e o chat mostram)
var _mic: AudioStreamPlayer
var _captura: AudioEffectCapture
var _bus := -1
var _fila := PackedByteArray()         # amostras mu-law esperando completar um pacote
var _acc := 0.0                        # reamostragem: soma e contagem do período atual
var _acc_n := 0
var _passo := 0.0
var _pos := 0.0
var _tocadores := {}                   # peer -> AudioStreamPlayer (gerador)
var _teste_t := -1.0                   # --voz_teste: manda um tom em vez do microfone
var _fase := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--voz_teste" in OS.get_cmdline_user_args():
		_teste_t = 3.0


func modo() -> String:
	return str(Config.v("voz"))


## O microfone deve estar aberto agora?
func _quer_mic() -> bool:
	if not Rede.online() or modo() == "desligada" or Chat.digitando:
		return false
	return modo() == "aberta" or Input.is_action_pressed("falar")


func _ligar_mic(sim: bool) -> void:
	if sim and _mic == null:
		_bus = AudioServer.bus_count
		AudioServer.add_bus(_bus)
		AudioServer.set_bus_name(_bus, "Microfone")
		AudioServer.set_bus_mute(_bus, true)   # a captura pega antes do mudo: a gente não se ouve no alto-falante
		_captura = AudioEffectCapture.new()
		_captura.buffer_length = 0.5
		AudioServer.add_bus_effect(_bus, _captura)
		_mic = AudioStreamPlayer.new()
		_mic.stream = AudioStreamMicrophone.new()
		_mic.bus = "Microfone"
		add_child(_mic)
		_mic.play()
		_passo = AudioServer.get_mix_rate() / TAXA
	elif not sim and _mic != null:
		_mic.stop()
		_mic.queue_free()
		_mic = null
		AudioServer.remove_bus(_bus)
		_bus = -1
		_captura = null
		_fila.clear()


func _process(dt: float) -> void:
	for p in falando.keys():
		falando[p] += dt
	if not Rede.online():
		if _mic != null:
			_ligar_mic(false)
		for p in _tocadores.keys():
			_tocadores[p].queue_free()
		_tocadores.clear()
		falando.clear()
		silenciados.clear()
		return
	if _teste_t > 0.0 and Rede.em_partida:
		_tom_teste(dt)
		return
	_ligar_mic(_quer_mic())
	if _captura == null:
		return
	var n := _captura.get_frames_available()
	if n <= 0:
		return
	var buf := _captura.get_buffer(n)
	var amostras := PackedFloat32Array()
	for f in buf:
		# reamostragem por média (filtro barato contra o chiado da redução de 48 kHz pra 8 kHz)
		_acc += (f.x + f.y) * 0.5
		_acc_n += 1
		_pos += 1.0
		if _pos >= _passo:
			_pos -= _passo
			amostras.append(_acc / _acc_n)
			_acc = 0.0
			_acc_n = 0
	_juntar(amostras)


## --voz_teste: 3 s de um tom de 440 Hz, como se fosse a voz (testa a rede sem microfone).
func _tom_teste(dt: float) -> void:
	_teste_t -= dt
	var amostras := PackedFloat32Array()
	for i in int(TAXA * dt):
		_fase += TAU * 440.0 / TAXA
		amostras.append(0.3 * sin(_fase))
	_juntar(amostras)


func _juntar(amostras: PackedFloat32Array) -> void:
	for s in amostras:
		_fila.append(comprimir(s))
	while _fila.size() >= PACOTE:
		var pacote := _fila.slice(0, PACOTE)
		_fila = _fila.slice(PACOTE)
		if modo() == "aberta" and _teste_t < 0.0 and _rms(pacote) < LIMIAR:
			continue   # microfone aberto em silêncio: não gasta rede
		enviados += pacote.size()
		falando[Rede.eu()] = 0.0
		Rede.voz_enviar(pacote)


static func _rms(pacote: PackedByteArray) -> float:
	var s := 0.0
	for b in pacote:
		var x := expandir(b)
		s += x * x
	return sqrt(s / maxf(1.0, pacote.size()))


## mu-law: 8 bits por amostra com mais detalhe nos sons baixos (como a voz no telefone).
static func comprimir(x: float) -> int:
	var m := log(1.0 + MU * minf(absf(x), 1.0)) / log(1.0 + MU)
	return (128 if x < 0.0 else 0) | roundi(m * 127.0)


static func expandir(b: int) -> float:
	var m := float(b & 127) / 127.0
	var x := (pow(1.0 + MU, m) - 1.0) / MU
	return -x if (b & 128) != 0 else x


## Chegou voz de alguém (já validado pela Rede).
func tocar(peer: int, pacote: PackedByteArray) -> void:
	recebidos += pacote.size()
	falando[peer] = 0.0
	if silenciados.has(peer):
		return
	var p: AudioStreamPlayer = _tocadores.get(peer)
	if p == null:
		p = AudioStreamPlayer.new()
		var g := AudioStreamGenerator.new()
		g.mix_rate = TAXA
		g.buffer_length = 0.4
		p.stream = g
		add_child(p)
		p.play()
		_tocadores[peer] = p
	p.volume_db = linear_to_db(maxf(0.001, float(Config.v("voz_volume"))))
	var pb := p.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null or pb.get_frames_available() < pacote.size():
		return   # atrasou demais: joga fora em vez de acumular atraso
	var quadros := PackedVector2Array()
	quadros.resize(pacote.size())
	for i in pacote.size():
		var x := expandir(pacote[i])
		quadros[i] = Vector2(x, x)
	pb.push_buffer(quadros)


func esta_falando(peer: int) -> bool:
	return falando.has(peer) and falando[peer] < FALANDO_T


func silenciar(peer: int) -> void:
	if silenciados.has(peer):
		silenciados.erase(peer)
	else:
		silenciados[peer] = true
