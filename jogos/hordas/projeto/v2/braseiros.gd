extends RefCounted
## Braseiro Antigo da v2: os braseiros do mapa (objeto "braseiro" de dados/v2_floresta.json) começam APAGADOS (luz fraca, sem fogo). Quando o
## herói fica por perto (raio_acender) por tempo_acender segundos SEGUIDOS, o braseiro acende, avisa no HUD (sinal `anuncio` do mundo) e,
## durante duracao segundos, os monstros que estão dentro de raio_seguro andam mais devagar (Monstro.deixar_lento). Depois apaga e só
## pode acender de novo depois de recarga segundos. Os números vêm de "braseiro_antigo" em dados/v2_floresta.json.
## Custo: quem enxerga o herói é uma Area2D por braseiro (o sinal dispara só quando ele entra ou sai; um sensor minúsculo vai preso ao herói);
## a conta de cada quadro é só um contador por braseiro que está carregando, aceso ou recarregando. A lentidão varre a lista de monstros
## vivos 4 vezes por segundo e SÓ enquanto algum braseiro está aceso. O tempo é o do mundo (pausa e câmera lenta valem).

const APAGADO := 0
const CARREGANDO := 1
const ACESO := 2
const RECARGA := 3
const CAMADA_SENSOR := 1 << 19  # camada física só deste sistema (camada 20): o sensor do herói mora nela
const COR_AVISO := Color(1.0, 0.62, 0.26)
const PADRAO := {
	"raio_acender": 120.0,
	"tempo_acender": 3.0,
	"duracao": 20.0,
	"recarga": 60.0,
	"raio_seguro": 170.0,
	"lentidao": 0.6,
	"intervalo": 0.25,
	"energia_apagado": 0.12,
	"orbe_apagado": 0.0,
	"aviso": "BRASEIRO ANTIGO ACESO!",
}


## Um braseiro antigo do mapa.
class Braseiro:
	extends RefCounted
	var pos := Vector2.ZERO  # o pé do objeto no mapa
	var luz  # Entrada de luzes.gd (a luz que já existia)
	var area: Area2D
	var estado := APAGADO
	var t := 0.0  # estado CARREGANDO: s seguidos com o herói perto; ACESO: s que faltam; RECARGA: s que faltam
	var heroi_perto := false
	var energia_base := 1.0
	var particulas: Array[CPUParticles2D] = []  # o fogo (sai da lista da luz enquanto o braseiro está apagado)


var lista: Array[Braseiro] = []
var cfg: Dictionary = PADRAO.duplicate()
var acendeu := 0  # quantas vezes algum braseiro acendeu (testes)
var _mundo
var _t_varre := 0.0
var _sensor: Area2D


func montar(mundo) -> void:
	_mundo = mundo
	var d: Dictionary = mundo.dados.get("braseiro_antigo", {})
	for k in d:
		if not str(k).begins_with("_"):
			cfg[k] = d[k]
	var achou: Array = []
	for item in mundo.cenario.luz_dos_objetos:
		if item.nome == "braseiro":
			achou.append(item)
	if achou.is_empty():
		return
	_criar_sensor(mundo)
	for item in achou:
		lista.append(_novo(item))


func _criar_sensor(mundo) -> void:
	_sensor = Area2D.new()
	_sensor.collision_layer = CAMADA_SENSOR
	_sensor.collision_mask = 0
	_sensor.monitoring = false
	var f := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 3.0
	f.shape = c
	_sensor.add_child(f)
	mundo.heroi.raiz.add_child(_sensor)  # anda com o herói; o centro do círculo é o pé dele


func _novo(item: Dictionary) -> Braseiro:
	var b := Braseiro.new()
	b.pos = item.pos
	b.luz = item.luz
	b.energia_base = b.luz.energia
	b.area = Area2D.new()
	b.area.collision_layer = 0
	b.area.collision_mask = CAMADA_SENSOR
	b.area.monitorable = false
	var f := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = float(cfg.raio_acender)
	f.shape = c
	b.area.add_child(f)
	b.area.position = item.pos
	_mundo.no_mundo.add_child(b.area)
	b.area.area_entered.connect(_sensor_entrou.bind(b))
	b.area.area_exited.connect(_sensor_saiu.bind(b))
	b.particulas.assign(b.luz.particulas)
	_apagar(b)
	return b


func _sensor_entrou(_area: Area2D, b: Braseiro) -> void:
	heroi_chegou(b)


func _sensor_saiu(_area: Area2D, b: Braseiro) -> void:
	heroi_saiu(b)


## O herói entrou no raio do braseiro (a Area2D chama; os testes também).
func heroi_chegou(b: Braseiro) -> void:
	b.heroi_perto = true
	if b.estado == APAGADO:
		b.estado = CARREGANDO
		b.t = 0.0


## O herói saiu do raio: o tempo seguido zera.
func heroi_saiu(b: Braseiro) -> void:
	b.heroi_perto = false
	if b.estado == CARREGANDO:
		b.estado = APAGADO
		b.t = 0.0


## Um passo do mundo (dt já com pausa e câmera lenta). Só mexe nos braseiros que estão fora de APAGADO.
func atualizar(dt: float) -> void:
	var aceso := false
	for b in lista:
		match b.estado:
			CARREGANDO:
				b.t += dt
				if b.t >= float(cfg.tempo_acender):
					_acender(b)
			ACESO:
				aceso = true
				b.t -= dt
				if b.t <= 0.0:
					_apagar(b)
					b.estado = RECARGA
					b.t = float(cfg.recarga)
			RECARGA:
				b.t -= dt
				if b.t <= 0.0:
					b.estado = CARREGANDO if b.heroi_perto else APAGADO  # o herói que ficou parado ali já começa a carregar
					b.t = 0.0
	if not aceso:
		_t_varre = 0.0
		return
	_t_varre -= dt
	if _t_varre <= 0.0:
		_t_varre = float(cfg.intervalo)
		_deixar_lentos()


func _acender(b: Braseiro) -> void:
	b.estado = ACESO
	b.t = float(cfg.duracao)
	acendeu += 1
	b.luz.energia = b.energia_base
	if b.luz.orbe != null:
		b.luz.orbe.modulate.a = 1.0
	b.luz.particulas.assign(b.particulas)
	for p in b.particulas:
		_mundo.atm.ligar(p, b.luz.ativa)  # a luz só liga o fogo quando ela mesma liga ou desliga; aqui ele volta junto
	_mundo.combate.anunciar(str(cfg.aviso), COR_AVISO)
	_t_varre = 0.0


func _apagar(b: Braseiro) -> void:
	b.luz.energia = b.energia_base * float(cfg.energia_apagado)
	if b.luz.orbe != null:
		b.luz.orbe.modulate.a = float(cfg.orbe_apagado)
	b.luz.particulas.clear()  # luzes.gd não liga mais o fogo deste braseiro
	for p in b.particulas:
		_mundo.atm.ligar(p, false)


## Lentidão dos monstros vivos dentro do raio de algum braseiro aceso (conta por distância ao quadrado).
func _deixar_lentos() -> void:
	var r2 := float(cfg.raio_seguro) * float(cfg.raio_seguro)
	var dur := float(cfg.lentidao)
	for b in lista:
		if b.estado != ACESO:
			continue
		for mo in _mundo.monstros:
			if mo.pos.distance_squared_to(b.pos) <= r2:
				mo.deixar_lento(dur)


## Quantos braseiros estão acesos agora.
func acesos() -> int:
	var n := 0
	for b in lista:
		if b.estado == ACESO:
			n += 1
	return n
