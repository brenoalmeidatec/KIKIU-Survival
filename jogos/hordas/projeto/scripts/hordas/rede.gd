extends Node
## Jogo online do K.I.K.I.U: até 6 pessoas, sem servidor (quem cria a sala vira o servidor; ENet, UDP 7777).
## A sala (criar, entrar, escolher herói sem repetir, validação) veio de jogos/cairu/projeto/scripts/rede.gd.
## Aqui só transporta e confere o que chega; as regras de cada mensagem ficam em online.gd, arena.gd e duelo.gd.
## Desenho completo em docs/ONLINE_KIKIU.md.

signal mudou                                 # entrou/saiu alguém ou alguém trocou de herói
signal conectou(ok: bool, msg: String)       # cliente: chegou na sala (ou foi recusado)
signal comecou(opcoes: Dictionary)           # todos: o anfitrião começou a partida
signal caiu(msg: String)                     # a sala acabou (anfitrião saiu, internet caiu...)

const Sorte := preload("res://scripts/hordas/sorte.gd")
const ENVIO := 1.0 / 15.0     # posições por segundo
# eventos que o anfitrião pode mandar (o resto é ignorado)
const EVENTOS := ["anuncio", "chefe_final", "fase_completa", "proxima_fase", "tela_azul_caiu", "fim_corrida",
	"duelo_iniciar", "luta", "eliminado", "duelo_fim"]

var PORTA := 7777
var MAX := 6
var ELENCO: Array = []

var modo := ""               # "", "anfitriao" ou "cliente"
var jogadores := {}          # peer -> {"heroi": "nicao"}
var em_partida := false
var remotos := {}            # peer -> {x, y, mx, my, hp, caido, lado}  (o pé do boneco, como jogador.position)
var online_no: Node = null   # online.gd da partida aberta (avisa quando abre e fecha)
var _envio_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ELENCO = Dados.json("pvp").get("elenco", Dados.json("herois").get("lista", []))
	multiplayer.peer_connected.connect(func(_id): pass)
	multiplayer.peer_disconnected.connect(_peer_saiu)
	multiplayer.connected_to_server.connect(func(): _pedir_lista.rpc_id(1))
	multiplayer.connection_failed.connect(func():
		sair()
		conectou.emit(false, "Não deu pra conectar. Confira o endereço e se a sala está aberta."))
	multiplayer.server_disconnected.connect(func(): _acabou("O anfitrião fechou a sala (ou a internet caiu)."))


func online() -> bool:
	return modo != ""


func anfitriao() -> bool:
	return modo == "anfitriao"


func cliente() -> bool:
	return modo == "cliente"


func eu() -> int:
	return multiplayer.get_unique_id() if online() else 1


func heroi_de(peer: int) -> String:
	return str(jogadores.get(peer, {}).get("heroi", ""))


func nome_de(peer: int) -> String:
	var h := heroi_de(peer)
	return str(Dados.json("herois").get(h, {}).get("nome", h))


func ocupados(menos := -1) -> Array:
	var l := []
	for p in jogadores:
		if p != menos and heroi_de(p) != "":
			l.append(heroi_de(p))
	return l


## Primeiro herói do elenco que ninguém pegou.
func heroi_livre(preferido := "") -> String:
	var tomados := ocupados(eu())
	if preferido in ELENCO and not preferido in tomados:
		return preferido
	for h in ELENCO:
		if not h in tomados:
			return h
	return ""


# ======================================================== abrir, entrar, sair

## Abre a sala neste computador. Devolve "" se deu certo, ou o motivo do erro.
func criar_sala(heroi: String, porta := PORTA) -> String:
	sair()
	var p := ENetMultiplayerPeer.new()
	if p.create_server(porta, MAX - 1) != OK:
		return "Não deu pra abrir a sala na porta %d. Outro programa (ou outro jogo aberto) já está usando ela?" % porta
	multiplayer.multiplayer_peer = p
	modo = "anfitriao"
	jogadores = {1: {"heroi": heroi}}
	mudou.emit()
	return ""


## Tenta entrar na sala de alguém. "endereco" = "ip:porta" ou "nome.do.tunel:porta".
func entrar(endereco: String) -> String:
	sair()
	var e := endereco.strip_edges().replace(" ", "")
	for prefixo in ["udp://", "http://", "https://"]:
		e = e.trim_prefix(prefixo)
	if e == "":
		return "Digite o endereço da sala."
	var host := e
	var porta := PORTA
	var dois := e.rfind(":")
	if dois > 0:
		host = e.substr(0, dois)
		if not e.substr(dois + 1).is_valid_int():
			return "A porta (depois dos dois pontos) tem que ser um número."
		porta = int(e.substr(dois + 1))
	var p := ENetMultiplayerPeer.new()
	if p.create_client(host, porta) != OK:
		return "Endereço inválido: " + endereco
	multiplayer.multiplayer_peer = p
	modo = "cliente"
	jogadores = {}
	return ""


func sair() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	modo = ""
	jogadores = {}
	remotos = {}
	em_partida = false


func _acabou(msg: String) -> void:
	var estava := online()
	sair()
	if estava:
		caiu.emit(msg)


func _peer_saiu(id: int) -> void:
	jogadores.erase(id)
	remotos.erase(id)
	if anfitriao():
		_lista.rpc(jogadores)
	if online_no and is_instance_valid(online_no):
		online_no.saiu(id)
	mudou.emit()


# ======================================================== sala

@rpc("any_peer", "reliable")
func _pedir_lista() -> void:
	if anfitriao():
		_lista.rpc_id(multiplayer.get_remote_sender_id(), jogadores)


@rpc("authority", "reliable")
func _lista(j: Dictionary) -> void:
	jogadores = j
	mudou.emit()


## Escolhe (ou troca) o herói. Cliente pede ao anfitrião; o anfitrião confere.
func escolher(heroi: String) -> void:
	if anfitriao():
		if heroi in ELENCO and not heroi in ocupados(1):
			jogadores[1] = {"heroi": heroi}
			_lista.rpc(jogadores)
			mudou.emit()
	elif cliente():
		_escolher.rpc_id(1, heroi)


@rpc("any_peer", "reliable")
func _escolher(heroi: String) -> void:
	if not anfitriao():
		return
	var quem := multiplayer.get_remote_sender_id()
	if em_partida:
		_recusado.rpc_id(quem, "A partida já começou. Espere a próxima.")
		return
	if jogadores.size() >= MAX and not jogadores.has(quem):
		_recusado.rpc_id(quem, "A sala está cheia (%d pessoas)." % MAX)
		return
	if not heroi in ELENCO:
		_recusado.rpc_id(quem, "Esse herói não existe nesta sala.")
		return
	if heroi in ocupados(quem):
		_recusado.rpc_id(quem, "Alguém já pegou esse herói. Escolha outro.")
		return
	var novo := not jogadores.has(quem)
	jogadores[quem] = {"heroi": heroi}
	_lista.rpc(jogadores)
	if novo:
		_bem_vindo.rpc_id(quem)
	mudou.emit()


@rpc("authority", "reliable")
func _recusado(msg: String) -> void:
	conectou.emit(false, msg)


@rpc("authority", "reliable")
func _bem_vindo() -> void:
	conectou.emit(true, "")


## Anfitrião: todo mundo na sala, começa a partida (opcoes vai igual pra todos, ex.: fase inicial de teste).
func comecar(opcoes := {}) -> void:
	if anfitriao() and not em_partida:
		# a semente da corrida é sorteada aqui e vai igual pra todos: santuários, eventos e drops saem das streams dela (sorte.gd)
		opcoes = opcoes.duplicate()
		opcoes["semente"] = Sorte.nova_semente()
		_comecar.rpc(jogadores, opcoes)


@rpc("authority", "call_local", "reliable")
func _comecar(j: Dictionary, opcoes: Dictionary) -> void:
	jogadores = j
	em_partida = true
	remotos = {}
	comecou.emit(opcoes)


# ======================================================== posições

func _process(delta: float) -> void:
	if not em_partida or online_no == null or not is_instance_valid(online_no):
		return
	_envio_t -= delta
	if _envio_t > 0.0:
		return
	_envio_t = ENVIO
	_pos.rpc(online_no.estado_rede())


@rpc("any_peer", "unreliable_ordered")
func _pos(d: Dictionary) -> void:
	# vem de qualquer peer: só guarda os campos esperados, com o tipo certo
	var quem := multiplayer.get_remote_sender_id()
	if not jogadores.has(quem):
		return
	var x = d.get("x", 0.0)
	var y = d.get("y", 0.0)
	if not _num(x) or not _num(y):
		return
	remotos[quem] = {
		"x": float(x), "y": float(y),
		"mx": clampf(float(d.get("mx", 0.0)) if _num(d.get("mx")) else 0.0, -1.0, 1.0),
		"my": clampf(float(d.get("my", 0.0)) if _num(d.get("my")) else 0.0, -1.0, 1.0),
		"hp": clampf(float(d.get("hp", 1.0)) if _num(d.get("hp")) else 1.0, 0.0, 1.0),
		"caido": typeof(d.get("caido")) == TYPE_BOOL and d.caido,
		"ajuda": typeof(d.get("ajuda")) == TYPE_BOOL and d.ajuda,
		"lado": -1.0 if _num(d.get("lado")) and float(d.lado) < 0 else 1.0,
	}


static func _num(v) -> bool:
	return (v is float or v is int) and is_finite(v)


# ======================================================== partida: anfitrião -> clientes

## Foto dos vírus (e tiros deles) perto de um cliente.
func enviar_foto(peer: int, virus: PackedFloat32Array, tiros: PackedFloat32Array) -> void:
	_foto.rpc_id(peer, virus, tiros)


@rpc("authority", "unreliable_ordered")
func _foto(virus: PackedFloat32Array, tiros: PackedFloat32Array) -> void:
	if online_no and is_instance_valid(online_no):
		online_no.foto(virus, tiros)


## Vírus que morreram: [id, x, y, tipo_idx, elite] por vírus.
func enviar_mortes(m: PackedFloat32Array) -> void:
	_mortes.rpc(m)


@rpc("authority", "reliable")
func _mortes(m: PackedFloat32Array) -> void:
	if online_no and is_instance_valid(online_no):
		online_no.mortes(m)


## Dano de vírus num cliente (encostou ou tiro).
func enviar_dano(peer: int, valor: float, fonte: String) -> void:
	_dano.rpc_id(peer, valor, fonte)


@rpc("authority", "reliable")
func _dano(valor: float, fonte: String) -> void:
	if online_no and is_instance_valid(online_no) and _num(valor):
		online_no.dano(clampf(valor, 0.0, 100000.0), fonte.left(32))


## Eventos da partida (fase completa, duelo...). O anfitrião também recebe (call_local).
func evento(nome: String, d := {}) -> void:
	if anfitriao():
		_evento.rpc(nome, d)


@rpc("authority", "call_local", "reliable")
func _evento(nome: String, d: Dictionary) -> void:
	if nome in EVENTOS and online_no and is_instance_valid(online_no):
		online_no.evento(nome, d)


# ======================================================== partida: clientes -> anfitrião

## Acertos de um cliente nos vírus dele: [id, dano, kx, ky] por acerto.
func enviar_acertos(a: PackedFloat32Array) -> void:
	_acertos.rpc_id(1, a)


@rpc("any_peer", "reliable")
func _acertos(a: PackedFloat32Array) -> void:
	var quem := multiplayer.get_remote_sender_id()
	if anfitriao() and jogadores.has(quem) and a.size() % 4 == 0 and online_no and is_instance_valid(online_no):
		online_no.acertos(quem, a)


## Mensagem pequena de um cliente pro anfitrião: "pronto" (fim do descanso), "forca" (duelo),
## "caiu" (duelo; peer = quem derrubou, 0 = anel).
func avisar(nome: String, valor := 0.0, peer := 0) -> void:
	if anfitriao():
		if online_no and is_instance_valid(online_no):
			online_no.aviso(1, nome, valor, peer)
	elif cliente():
		_aviso.rpc_id(1, nome, valor, peer)


@rpc("any_peer", "reliable")
func _aviso(nome: String, valor: float, peer: int) -> void:
	var quem := multiplayer.get_remote_sender_id()
	if anfitriao() and jogadores.has(quem) and nome in ["voto", "pronto", "forca", "caiu"] and _num(valor) \
			and online_no and is_instance_valid(online_no):
		online_no.aviso(quem, nome, valor, peer)


# ======================================================== duelo: golpe direto de pessoa pra pessoa

## Quem ataca detecta o acerto e manda; quem apanha decide (vida, invencibilidade, dash).
func golpe(alvo: int, dano: float, empurrao: Vector2) -> void:
	if alvo == eu():
		return
	_golpe.rpc_id(alvo, dano, empurrao.x, empurrao.y)


@rpc("any_peer", "reliable")
func _golpe(dano: float, ex: float, ey: float) -> void:
	var quem := multiplayer.get_remote_sender_id()
	if jogadores.has(quem) and _num(dano) and _num(ex) and _num(ey) and online_no and is_instance_valid(online_no):
		online_no.golpe(quem, clampf(dano, 0.0, 100000.0), Vector2(ex, ey).limit_length(600.0))
