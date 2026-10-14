extends Node
## Sala do coop da v2 (docs/ONLINE_V2_PLANO.md, etapa 1): ENet sobre UDP, porta 7777, até 4 pessoas, quem abre a sala é o servidor.
## Cada pessoa é dona do próprio herói e manda posição, direção, estado e contador de golpes a 20 Hz (16 bytes, unreliable_ordered); o
## anfitrião repassa a cada cliente as posições de todos os outros. Nesta etapa NÃO há monstros na rede: cada máquina tem a sua horda.
## Portado da v1 (scripts/hordas/rede.gd e online.gd) sem importá-la: a casca da sala (criar, entrar, endereço ip:porta, recusa de sala cheia
## pelo ENet, queda do anfitrião) e a ideia de mandar só o que muda de pouco em pouco. Nó, não autoload: o mundo cria um quando a linha de
## comando traz `--coop=host` ou `--coop=join --endereco=ip:porta` (outras opções: `--nome=`, `--bot`, `--sair=N`; ver v2/LEIA-ME.md).
## O nó precisa ter o mesmo caminho nas duas máquinas (o RPC do Godot usa o caminho): o mundo o cria com o nome "CoopRede".

const HeroiRemoto := preload("res://v2/heroi_remoto.gd")
const Heroi := preload("res://v2/heroi.gd")
const PORTA := 7777
const MAX := 4  # pessoas na sala, o anfitrião incluso
const ENVIO := 1.0 / 20.0  # pacotes de posição por segundo
const ESPERA_MAX := 30.0  # s esperando alguém entrar (só vale com --sair; sem ele a sala espera para sempre)

signal mudou  # entrou ou saiu alguém
signal caiu(msg: String)  # a sala acabou

var mundo
var modo := ""  # "host" ou "join"
var nome := ""
var nomes := {}  # peer -> nome (todos, inclusive eu)
var remotos := {}  # peer -> HeroiRemoto
var erro := ""
var conectado := false  # cliente: chegou na sala; anfitrião: sala aberta
var pacotes_env := 0
var _envio_t := 0.0
var _t := 0.0  # s desde que o nó nasceu
var _t_con := -1.0  # s (de _t) da primeira conexão: o bot e o --sair contam daqui
var _bot := false
var _sair := 0.0
var _banda_env := 0.0  # KB enviados desde o começo (estatística do ENet)
var _banda_rec := 0.0
var _banda_pop := 0.0
var _banda_t0 := -1.0
var _terminou := false


## Abre a sala (modo "host") ou entra numa ("join", com endereço "ip:porta"; sem porta vale 7777). Devolve "" ou o motivo do erro.
func montar(m, modo_: String, endereco: String, nome_: String) -> String:
	mundo = m
	modo = modo_
	name = "CoopRede"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var a: Dictionary = mundo.args
	_bot = a.has("bot")
	_sair = float(a.get("sair", 0.0))
	nome = limpar_nome(nome_)
	if nome == "":
		nome = "Anfitrião" if modo == "host" else "Amigo"
	multiplayer.peer_disconnected.connect(_peer_saiu)
	multiplayer.connected_to_server.connect(_conectou)
	multiplayer.connection_failed.connect(func(): _falhou("Não deu pra conectar. Confira o endereço e se a sala está aberta."))
	multiplayer.server_disconnected.connect(func(): _falhou("O anfitrião fechou a sala (ou a internet caiu)."))
	var p := ENetMultiplayerPeer.new()
	if modo == "host":
		if p.create_server(PORTA, MAX - 1) != OK:
			return _falhou("Não deu pra abrir a sala na porta %d. Outro programa (ou outro jogo aberto) já está usando ela?" % PORTA)
		multiplayer.multiplayer_peer = p
		nomes = {1: nome}
		conectado = true
		print("coop: sala aberta porta=%d nome=%s" % [PORTA, nome])
	elif modo == "join":
		var host := endereco.strip_edges()
		var porta := PORTA
		var dois := host.rfind(":")
		if dois > 0:
			if not host.substr(dois + 1).is_valid_int():
				return _falhou("A porta (depois dos dois pontos) tem que ser um número.")
			porta = int(host.substr(dois + 1))
			host = host.substr(0, dois)
		if host == "" or p.create_client(host, porta) != OK:
			return _falhou("Endereço inválido: " + endereco)
		multiplayer.multiplayer_peer = p
		print("coop: entrando em %s:%d" % [host, porta])
	else:
		return _falhou("--coop deve ser host ou join (veio '%s')." % modo)
	return ""


## Apelido que vem pela rede ou do teclado: só o que a fonte desenha (ASCII e acentos do português), até 16 letras.
static func limpar_nome(s: String) -> String:
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		if (c >= 32 and c < 127) or "áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ".contains(ch):
			out += ch
	return out.strip_edges().left(16)


func eu() -> int:
	return multiplayer.get_unique_id()


func _falhou(msg: String) -> String:
	erro = msg
	print("coop: erro %s" % msg)
	caiu.emit(msg)
	sair()
	if mundo != null and (mundo.args.has("sair") or mundo.args.has("bot")):  # teste automático: não fica parado
		get_tree().quit(1)
	return msg


func sair() -> void:
	var p = multiplayer.multiplayer_peer
	if p != null and not p is OfflineMultiplayerPeer:
		p.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	conectado = false
	for id in remotos.keys().duplicate():
		_tirar_remoto(id)


# ------------------------------------------------------------------ sala


func _conectou() -> void:
	conectado = true
	nomes[eu()] = nome
	print("coop: conectado id=%d" % eu())
	_primeira_conexao()
	_ola.rpc_id(1, nome)


func _primeira_conexao() -> void:
	if _t_con < 0.0:
		_t_con = _t


## Cliente -> anfitrião: "cheguei, me chamo assim". O anfitrião guarda e manda a lista de nomes para todos.
@rpc("any_peer", "reliable")
func _ola(n) -> void:
	if modo != "host" or not n is String:
		return
	var quem := multiplayer.get_remote_sender_id()
	var limpo := limpar_nome(n)
	if limpo == "":
		limpo = "Amigo"
	var base := limpo
	var k := 2
	while limpo in nomes.values():  # nome repetido: ganha um número
		limpo = "%s %d" % [base.left(13), k]
		k += 1
	nomes[quem] = limpo
	print("coop: entrou id=%d nome=%s (%d na sala)" % [quem, limpo, nomes.size()])
	_primeira_conexao()
	_criar_remoto(quem)
	_lista.rpc(nomes)
	mudou.emit()


## Anfitrião -> todos: quem está na sala. Cada cliente cria os heróis que faltam e tira os que saíram.
@rpc("authority", "reliable")
func _lista(d) -> void:
	if not d is Dictionary:
		return
	var novos := {}
	for k in d:
		if (k is int) and (d[k] is String) and novos.size() < MAX:
			novos[k] = limpar_nome(d[k])
	nomes = novos
	for id in nomes:
		if id != eu():
			_criar_remoto(id)
	for id in remotos.keys().duplicate():
		if not nomes.has(id):
			_tirar_remoto(id)
	mudou.emit()


func _peer_saiu(id: int) -> void:
	if remotos.has(id):
		_relatar_remoto(remotos[id], "saiu")
	nomes.erase(id)
	_tirar_remoto(id)
	if modo == "host":
		_lista.rpc(nomes)
	mudou.emit()


func _criar_remoto(id: int) -> void:
	if remotos.has(id):
		remotos[id].definir_nome(str(nomes.get(id, "")))
		return
	var r := HeroiRemoto.new()
	var t: Dictionary = mundo.sprites.tipo("hazaki" if mundo.args.has("basico") else "hazaki_samurai")
	r.id = id
	r.criar(mundo, mundo.no_mundo, t, mundo.heroi.pos, str(nomes.get(id, "?")))
	remotos[id] = r
	mundo.herois.append(r)
	mundo.sombras.registrar_lote([r])


func _tirar_remoto(id: int) -> void:
	var r = remotos.get(id)
	if r == null:
		return
	remotos.erase(id)
	mundo.herois.erase(r)
	mundo.sombras.ativar(r, false)
	r.raiz.queue_free()


# ------------------------------------------------------------------ posições


func _process(delta: float) -> void:
	if mundo == null or _terminou:
		return
	_t += delta
	if conectado and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if _banda_t0 < 0.0:
			_banda_t0 = _t
			_banda_pop = _t
		_estatistica()
		_envio_t -= delta
		if _envio_t <= 0.0:
			_envio_t = ENVIO
			_enviar()
	if _bot and _t_con >= 0.0:
		_roteiro_bot(_t - _t_con)
	if _sair > 0.0:
		if _t_con >= 0.0 and _t - _t_con >= _sair + (4.0 if modo == "host" else 0.0):
			_encerrar()
		elif _t_con < 0.0 and _t > ESPERA_MAX:
			_falhou("Ninguém entrou em %.0f s." % ESPERA_MAX)


func _enviar() -> void:
	var meu := HeroiRemoto.codificar(mundo.heroi)
	if modo == "join":
		_pos_cliente.rpc_id(1, meu)
		pacotes_env += 1
		return
	# anfitrião: a cada cliente, as posições de todos menos a dele (eu primeiro)
	for para in remotos:
		var b := PackedByteArray()
		var n := 0
		var corpo := PackedByteArray()
		var itens := {1: meu}
		for id in remotos:
			if id != para and remotos[id].ultimo.size() == HeroiRemoto.TAM:
				itens[id] = remotos[id].ultimo
		for id in itens:
			var cab := PackedByteArray()
			cab.resize(4)
			cab.encode_u32(0, id)
			corpo.append_array(cab)
			corpo.append_array(itens[id])
			n += 1
		b.append(n)
		b.append_array(corpo)
		_pos_todos.rpc_id(para, b)
		pacotes_env += 1


@rpc("any_peer", "unreliable_ordered")
func _pos_cliente(b) -> void:
	if modo != "host" or not b is PackedByteArray or b.size() != HeroiRemoto.TAM:
		return
	var r = remotos.get(multiplayer.get_remote_sender_id())
	if r != null:
		r.aplicar(b)


@rpc("authority", "unreliable_ordered")
func _pos_todos(b) -> void:
	if not b is PackedByteArray or b.size() < 1:
		return
	var n := b.decode_u8(0)
	if n > MAX or b.size() != 1 + n * (4 + HeroiRemoto.TAM):
		return
	for i in n:
		var o := 1 + i * (4 + HeroiRemoto.TAM)
		var id := b.decode_u32(o)
		if id == eu():
			continue
		var r = remotos.get(id)
		if r != null:
			r.aplicar(b, o + 4)


# ------------------------------------------------------------------ medição, bot e fim


func _estatistica() -> void:
	if _t - _banda_pop < 1.0:
		return
	_banda_pop = _t
	var p = multiplayer.multiplayer_peer
	if p is ENetMultiplayerPeer and p.host != null:
		_banda_env += p.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / 1024.0
		_banda_rec += p.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / 1024.0


## Quem anda e golpeia sozinho, igual nas duas pontas (teste de duas instâncias): parado, anda, golpeia, anda de volta e para.
func _roteiro_bot(s: float) -> void:
	var h = mundo.heroi
	var v := Vector2.ZERO
	var bate := false
	if s >= 1.0 and s < 2.5:
		v = Vector2(1.0, 0.4)
	elif s >= 2.5 and s < 4.5:
		bate = true
	elif s >= 4.5 and s < 6.0:
		v = Vector2(-1.0, 0.0)
	h.imortal = true
	h.entrada_forcada = v
	h.ataque_forcado = bate


func _relatar_remoto(r, como: String) -> void:
	print(
		(
			"coop: remoto_final %s id=%d nome=%s x=%.2f y=%.2f golpes=%d golpes_vistos=%d pacotes=%d"
			% [como, r.id, r.nome, r.alvo.x, r.alvo.y, r.golpes, r.golpes_vistos, r.pacotes]
		)
	)


func _encerrar() -> void:
	if _terminou:
		return
	_estatistica()
	_terminou = true
	var h = mundo.heroi
	print("coop: local_final id=%d nome=%s x=%.2f y=%.2f golpes=%d" % [eu(), nome, h.pos.x, h.pos.y, h.golpes])
	for id in remotos:
		_relatar_remoto(remotos[id], "fim")
	var seg := maxf(_t - _banda_t0, 0.001)
	print("coop: banda env=%.2f KB/s rec=%.2f KB/s (em %.1f s, %d pacotes de posição enviados)" % [_banda_env / seg, _banda_rec / seg, seg, pacotes_env])
	sair()
	get_tree().quit()
