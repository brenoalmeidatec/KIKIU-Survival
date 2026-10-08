extends Node
## Som espacial para o Vita. A saída do Vita é só ESTÉREO (alto-falantes ou fone): não existe Dolby/surround de
## verdade. O que dá para fazer, e é feito aqui:
## - pan + atenuação pela posição de cada som em relação à câmera (AudioStreamPlayer2D, pool fixo, sem alocar);
## - reverb de sala no bus SFX (sensação de ambiente) e alargamento estéreo com atraso Haas no Master (no fone,
##   os sons laterais "saem" da cabeça);
## - limiter no Master (horda grande não estoura);
## - teto de sons novos por quadro e de vozes simultâneas (protege a CPU do mixer, que roda numa thread própria).

const POOL = 10
const POR_QUADRO = 3

var ligado = true
var players = []
var proximo = 0
var sons = {}
var musica: AudioStreamPlayer
var _neste_quadro = 0


func _ready() -> void:
	AudioServer.bus_count = 3
	AudioServer.set_bus_name(1, "SFX")
	AudioServer.set_bus_send(1, "Master")
	AudioServer.set_bus_name(2, "Musica")
	AudioServer.set_bus_send(2, "Master")
	AudioServer.set_bus_volume_db(2, -6.0)
	var rev = AudioEffectReverb.new()
	rev.room_size = 0.55
	rev.damping = 0.6
	rev.spread = 1.0
	rev.hipass = 0.2
	rev.dry = 1.0
	rev.wet = 0.18
	AudioServer.add_bus_effect(1, rev)
	var largo = AudioEffectStereoEnhance.new()
	largo.pan_pullout = 1.25
	largo.time_pullout_ms = 6.0
	AudioServer.add_bus_effect(0, largo)
	AudioServer.add_bus_effect(0, AudioEffectLimiter.new())
	for _k in POOL:
		var p = AudioStreamPlayer2D.new()
		p.bus = "SFX"
		p.max_distance = 700.0
		p.attenuation = 1.6
		add_child(p)
		players.append(p)
	for n in ["acerto", "soco", "whoosh", "tremor"]:
		sons[n] = load("res://audio/%s.wav" % n)
	musica = AudioStreamPlayer.new()
	musica.stream = load("res://audio/horror.ogg")
	musica.bus = "Musica"
	add_child(musica)
	definir(true)


func definir(lig: bool) -> void:
	ligado = lig
	if lig:
		if not musica.playing:
			musica.play()
	else:
		musica.stop()
		for p in players:
			p.stop()


## Toca `nome` na posição do mundo (o pan e o volume saem da distância até o centro da câmera).
func tocar(nome: String, pos: Vector2, vol_db: float = 0.0, tom: float = 1.0) -> void:
	if not ligado or _neste_quadro >= POR_QUADRO:
		return
	_neste_quadro += 1
	var p: AudioStreamPlayer2D = players[proximo]
	proximo = (proximo + 1) % POOL
	p.stream = sons[nome]
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = tom * rand_range(0.94, 1.06)
	p.play()


func _process(_dt: float) -> void:
	_neste_quadro = 0
