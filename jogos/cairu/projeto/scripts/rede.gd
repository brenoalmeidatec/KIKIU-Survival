extends Node
## Jogar online (até 6 pessoas). Um jogador cria a sala (o anfitrião) e os outros entram
## digitando o endereço dele. Sem servidor: o jogo do anfitrião é o servidor (ENet, UDP).
## Pra amigos fora da casa dele, o anfitrião usa um túnel grátis (playit.gg, veja o LEIA-ME).
##
## Parte da engine: não sabe nada do jogo. Elenco, porta e limite vêm de capitulos/online.json;
## o mundo (mundo.gd) só precisa ter estado(), estado_rede(), estado_historia(),
## aplicar_estado_rede(), cena_da_rede() e em_cena.
##
## O que é sincronizado:
##   - quem está na sala e qual personagem cada um escolheu (sem repetir; "figurante" = aluno)
##   - onde cada um está (mapa, posição, direção, andando)
##   - as cenas: só o anfitrião puxa conversa; quando ele começa uma cena, todo mundo vai
##     pro lugar dele e vê a mesma cena. Escolhas e resultado de minijogo vêm do anfitrião.
##   - as marcas da história (flags), no fim de cada cena do anfitrião

signal mudou                                 # entrou/saiu alguém ou alguém escolheu personagem
signal conectou(ok: bool, msg: String)       # cliente: chegou na sala (ou não)
signal entrou_no_jogo(estado: Dictionary)    # cliente: anfitrião aceitou, pode abrir o mundo
signal caiu(msg: String)                     # a sala acabou (anfitrião saiu, internet caiu...)
signal decisao_chegou

const ENVIO := 1.0 / 12.0    # posições por segundo
# direções aceitas de quem está online: as mesmas chaves de Personagem.LINHA (personagem.gd).
# Se o boneco ganhar direções novas (diagonais, por ex.), acrescente aqui também, senão viram "baixo".
const DIRECOES := ["baixo", "esquerda", "direita", "cima"]

# Tudo que é do jogo (e não da engine) vem de capitulos/online.json; sem ele, valem estes:
var PORTA := 7777
var MAX := 6
var ELENCO: Array = []       # sem lista: todos os personagens de Dados.NOMES
var FIGURANTE := "aluno"     # arte de quem entra como figurante: aluno1..alunoN
var FIGURANTES := 10
var NOME_FIGURANTE := "Figurante"

var modo := ""               # "", "anfitriao" ou "cliente"
var jogadores := {}          # peer -> {"personagem": "nicao"}
var meu_personagem := ""
var remotos := {}            # peer -> {mapa, x, y, dir, andando, cena}
var mundo: Node = null       # o mundo aberto agora (mundo.gd avisa quando abre e fecha)
var rodada := 0              # anfitrião: conta as cenas que ele puxou
var rodada_atual := 0        # cliente: de qual cena do anfitrião são as decisões que ele espera
var _rodada_de := {}         # cliente: cena -> rodada (pras cenas que chegaram na fila)
var _decisoes: Array = []    # cliente: [rodada, valor] na ordem em que o anfitrião decidiu
var _estado_pendente := {}   # cliente: marcas que chegaram durante uma cena
var _envio_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg = Dados.ler_json("online.json")
	if not cfg is Dictionary:
		cfg = {}
	ELENCO = cfg.get("elenco", Dados.NOMES.keys())
	MAX = int(cfg.get("max_jogadores", MAX))
	PORTA = int(cfg.get("porta", PORTA))
	FIGURANTE = str(cfg.get("figurante", FIGURANTE))
	FIGURANTES = maxi(1, int(cfg.get("figurantes", FIGURANTES)))
	NOME_FIGURANTE = str(cfg.get("nome_figurante", NOME_FIGURANTE))
	multiplayer.peer_connected.connect(_peer_entrou)
	multiplayer.peer_disconnected.connect(_peer_saiu)
	multiplayer.connected_to_server.connect(_cheguei)
	multiplayer.connection_failed.connect(_nao_cheguei)
	multiplayer.server_disconnected.connect(func(): _acabou("O anfitrião fechou a sala (ou a internet caiu)."))


func online() -> bool:
	return modo != ""


func anfitriao() -> bool:
	return modo == "anfitriao"


func cliente() -> bool:
	return modo == "cliente"


func eu() -> int:
	return multiplayer.get_unique_id() if online() else 1


## Personagem que o anfitrião escolheu (quem "puxa" as cenas).
func personagem_anfitriao() -> String:
	return personagem_de(1)


func ocupados() -> Array:
	var l := []
	for p in jogadores:
		var q := str(jogadores[p].get("personagem", ""))
		if q != "" and q != "figurante":
			l.append(q)
	return l


# ======================================================== abrir e entrar

## Abre a sala neste computador. Devolve "" se deu certo, ou o motivo do erro.
func criar_sala(personagem: String, porta := PORTA) -> String:
	sair()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(porta, MAX - 1)
	if err != OK:
		return "Não deu pra abrir a sala na porta %d. Outro programa (ou outro jogo aberto) já está usando ela?" % porta
	multiplayer.multiplayer_peer = p
	modo = "anfitriao"
	meu_personagem = personagem
	jogadores = {1: {"personagem": personagem}}
	rodada = 0
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
	var err := p.create_client(host, porta)
	if err != OK:
		return "Endereço inválido: " + endereco
	multiplayer.multiplayer_peer = p
	modo = "cliente"
	jogadores = {}
	_decisoes.clear()
	_rodada_de.clear()
	return ""


## Sai da sala (e fecha ela, se for o anfitrião).
func sair() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	modo = ""
	jogadores = {}
	remotos = {}
	meu_personagem = ""
	_decisoes.clear()
	_rodada_de.clear()
	_estado_pendente = {}


func _acabou(msg: String) -> void:
	if not online():
		return
	sair()
	caiu.emit(msg)


func _cheguei() -> void:
	conectou.emit(true, "")
	_pedir_lista.rpc_id(1)


func _nao_cheguei() -> void:
	sair()
	conectou.emit(false, "Não achei a sala. Confira o endereço e se o anfitrião está com a sala aberta.")


func _peer_entrou(_id: int) -> void:
	pass   # o novo jogador pede a lista e escolhe o personagem antes de aparecer


func _peer_saiu(id: int) -> void:
	remotos.erase(id)
	if anfitriao() and jogadores.has(id):
		jogadores.erase(id)
		_lista.rpc(jogadores)
	mudou.emit()


@rpc("any_peer", "reliable")
func _pedir_lista() -> void:
	if anfitriao():
		_lista.rpc_id(multiplayer.get_remote_sender_id(), jogadores)


@rpc("authority", "reliable")
func _lista(j: Dictionary) -> void:
	jogadores = j
	mudou.emit()


## Cliente: escolhe o personagem (o anfitrião confere se está livre).
func escolher(personagem: String) -> void:
	if cliente():
		_escolher.rpc_id(1, personagem)


@rpc("any_peer", "reliable")
func _escolher(personagem: String) -> void:
	if not anfitriao():
		return
	var quem := multiplayer.get_remote_sender_id()
	if jogadores.size() >= MAX and not jogadores.has(quem):
		_recusado.rpc_id(quem, "A sala está cheia (%d pessoas)." % MAX)
		return
	if personagem != "figurante" and not personagem in ELENCO:
		_recusado.rpc_id(quem, "Esse personagem não existe nesta sala.")
		return
	if personagem != "figurante" and personagem in ocupados():
		_recusado.rpc_id(quem, "Alguém já pegou esse personagem. Escolha outro.")
		return
	jogadores[quem] = {"personagem": personagem}
	var estado: Dictionary = mundo.estado() if mundo and is_instance_valid(mundo) else {}
	_bem_vindo.rpc_id(quem, estado, jogadores, rodada)
	_lista.rpc(jogadores)
	mudou.emit()


@rpc("authority", "reliable")
func _recusado(msg: String) -> void:
	conectou.emit(false, msg)


@rpc("authority", "reliable")
func _bem_vindo(estado: Dictionary, j: Dictionary, r: int) -> void:
	jogadores = j
	meu_personagem = str(j.get(eu(), {}).get("personagem", "figurante"))
	rodada_atual = r
	entrou_no_jogo.emit(estado)


# ======================================================== posições

func _process(delta: float) -> void:
	if not online() or mundo == null or not is_instance_valid(mundo):
		return
	if cliente() and not jogadores.has(eu()):
		return
	_envio_t -= delta
	if _envio_t > 0.0:
		return
	_envio_t = ENVIO
	_pos.rpc(mundo.estado_rede())


@rpc("any_peer", "unreliable_ordered")
func _pos(d: Dictionary) -> void:
	# vem de qualquer peer: só guarda os campos esperados, com o tipo certo
	var x = d.get("x", 0.0)
	var y = d.get("y", 0.0)
	if not (x is float or x is int) or not (y is float or y is int) or not is_finite(x) or not is_finite(y):
		return
	var dir := str(d.get("dir", "baixo"))
	remotos[multiplayer.get_remote_sender_id()] = {
		"mapa": str(d.get("mapa", "")), "x": float(x), "y": float(y),
		"dir": dir if dir in DIRECOES else "baixo",
		"andando": _sim(d.get("andando")), "cena": _sim(d.get("cena")),
	}


func _sim(v) -> bool:
	return typeof(v) == TYPE_BOOL and v


func personagem_de(peer: int) -> String:
	var q := str(jogadores.get(peer, {}).get("personagem", ""))
	if q == "figurante" or q == "":
		return "%s%d" % [FIGURANTE, 1 + peer % FIGURANTES]
	return q


# ======================================================== cenas

## Anfitrião: começou uma cena (todo mundo vai pro lugar dele e vê junto).
func cena(id: String, npc: String, lugar: Dictionary) -> void:
	if not anfitriao():
		return
	rodada += 1
	_cena.rpc(id, npc, lugar, rodada)


@rpc("authority", "reliable")
func _cena(id: String, npc: String, lugar: Dictionary, r: int) -> void:
	_rodada_de[id] = r
	if mundo and is_instance_valid(mundo):
		mundo.cena_da_rede(id, npc, lugar)


## Cliente: a cena "id" vai começar a tocar aqui (decisões dela são da rodada dela).
func comecando(id: String) -> void:
	if _rodada_de.has(id):
		rodada_atual = _rodada_de[id]
		_rodada_de.erase(id)


## Anfitrião: uma escolha de diálogo ou o resultado de um minijogo.
func decidir(valor) -> void:
	if anfitriao():
		_decisao.rpc(rodada, valor)


@rpc("authority", "reliable")
func _decisao(r: int, valor) -> void:
	_decisoes.append([r, valor])
	decisao_chegou.emit()


## Cliente: espera a próxima decisão do anfitrião pra cena que está tocando.
func proxima_decisao():
	while true:
		while not _decisoes.is_empty() and int(_decisoes[0][0]) < rodada_atual:
			_decisoes.pop_front()   # sobrou de uma cena que este jogador não viu
		if not _decisoes.is_empty():
			return _decisoes.pop_front()[1]
		if not cliente():
			return null
		await decisao_chegou


## Anfitrião: a cena acabou; manda as marcas da história pra todo mundo.
func sincronizar(estado: Dictionary) -> void:
	if anfitriao():
		_estado.rpc(estado)


@rpc("authority", "reliable")
func _estado(e: Dictionary) -> void:
	if mundo and is_instance_valid(mundo) and not mundo.em_cena:
		mundo.aplicar_estado_rede(e)
	else:
		_estado_pendente = e


## Cliente: no fim da sua cena, aplica as marcas que chegaram enquanto ela tocava.
func aplicar_pendente() -> void:
	if not _estado_pendente.is_empty() and mundo and is_instance_valid(mundo):
		mundo.aplicar_estado_rede(_estado_pendente)
		_estado_pendente = {}
