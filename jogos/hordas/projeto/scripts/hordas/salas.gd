extends Node
## Lista de salas (#13): quem procura vê as salas abertas e entra sem digitar endereço. Tudo grátis, sem conta:
## - REDE LOCAL: o anfitrião grita (broadcast UDP) a cada 2 s na porta DESCOBERTA; quem procura ouve.
##   O endereço é o IP de quem gritou (o pacote diz) + a porta da sala.
## - INTERNET (só se o anfitrião ligar "lista pública"): o anúncio vai por HTTPS pro ntfy.sh, um serviço público de
##   mensagens, no tópico TOPICO, a cada 30 s; quem procura lê os anúncios dos últimos 2 min. A porta 443 passa em
##   qualquer rede (MQTT público, testado, é bloqueado em muitas). O endereço é o do túnel (playit) que o anfitrião colou.
## Qualquer um pode publicar no tópico: TODO anúncio é validado (formato, versão, tamanhos) e a lista tem teto.

const VERSAO := 1  # sobe quando o online mudar de jeito que não conversa com a versão anterior
const DESCOBERTA := 7778  # porta UDP dos anúncios na rede local
const TOPICO := "kikiu-survival-salas-v1"
const NTFY := "https://ntfy.sh/"
const LAN_CADA := 2.0
const NET_CADA := 30.0
const LER_CADA := 10.0
const LAN_VALE := 7.0  # sala de rede local some se ficar 7 s sem anunciar
const NET_VALE := 95.0
const MAX_SALAS := 30

var publica := false  # anfitrião: anunciar também na internet (opção na sala, tecla L)
var endereco_publico := ""  # anfitrião: endereço do túnel (playit) que vai no anúncio público
var salas := {}  # id -> {id, nome, anfitriao, jogadores, max, endereco, origem ("lan"/"net"), visto}
var topico := TOPICO  # os testes usam outro (--topico=) pra não sujar a lista de verdade
var erro_net := ""  # último problema com a internet (a tela mostra)

var _id := ""  # id desta sala (sorteado ao abrir)
var _lan_t := 0.0
var _net_t := 0.0
var _ler_t := 0.0
var _procurando := false
var _udp_envia := PacketPeerUDP.new()
var _udp_ouve := PacketPeerUDP.new()
var _http_publica := HTTPRequest.new()
var _http_le := HTTPRequest.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--topico="):
			topico = a.trim_prefix("--topico=")
	_http_publica.timeout = 8.0
	_http_le.timeout = 8.0
	add_child(_http_publica)
	add_child(_http_le)
	_http_le.request_completed.connect(_leu)
	_http_publica.request_completed.connect(
		func(r, cod, _h, _b): erro_net = "" if r == OK and cod < 300 else "Não deu pra publicar a sala na lista (internet?)."
	)


# ---------------------------------------------------------------- quem procura


## Começa a ouvir a rede local e a ler a lista da internet (tela "Entrar em sala").
func procurar() -> void:
	if _procurando:
		return
	_procurando = true
	salas.clear()
	erro_net = ""
	_ler_t = 0.0
	if _udp_ouve.bind(DESCOBERTA) != OK:
		erro_net = "A busca na rede local está ocupada por outro jogo aberto neste computador."


func parar_procura() -> void:
	_procurando = false
	_udp_ouve.close()


## Salas pra mostrar: rede local primeiro, depois as da internet, as mais novas no topo.
func lista() -> Array:
	var l := salas.values()
	l.sort_custom(
		func(a, b):
			if a.origem != b.origem:
				return a.origem == "lan"
			return a.visto > b.visto
	)
	return l


func _ouvir_lan() -> void:
	while _udp_ouve.get_available_packet_count() > 0:
		var pacote := _udp_ouve.get_packet()
		var ip := _udp_ouve.get_packet_ip()
		var s := validar(pacote.get_string_from_utf8(), ip)
		if not s.is_empty() and s.id != _id:
			s["origem"] = "lan"
			_guardar(s)


func _leu(r: int, cod: int, _h: PackedStringArray, corpo: PackedByteArray) -> void:
	if r != OK or cod >= 300:
		erro_net = "Sem lista da internet agora (sem conexão?). Salas da rede local continuam aparecendo."
		return
	erro_net = ""
	for linha in corpo.get_string_from_utf8().split("\n", false):
		var m = JSON.parse_string(linha)
		if not m is Dictionary or str(m.get("event", "")) != "message":
			continue
		var s := validar(str(m.get("message", "")), "")
		if s.is_empty() or s.id == _id:
			continue
		# se a mesma sala já apareceu na rede local, fica a da rede local (endereço direto, sem túnel)
		if salas.has(s.id) and salas[s.id].origem == "lan":
			continue
		s["origem"] = "net"
		_guardar(s)


func _guardar(s: Dictionary) -> void:
	s["visto"] = Time.get_ticks_msec() / 1000.0
	if salas.has(s.id) or salas.size() < MAX_SALAS:
		salas[s.id] = s


## Confere um anúncio que veio de fora. Devolve a sala limpa ou {} se estiver torto.
## ip_lan != "": veio da rede local, e o endereço é esse IP + a porta anunciada.
static func validar(txt: String, ip_lan: String) -> Dictionary:
	if txt.length() > 600:
		return {}
	var d = JSON.parse_string(txt)
	if not d is Dictionary or typeof(d.get("v")) != TYPE_FLOAT or int(d.v) != VERSAO:
		return {}
	var id := str(d.get("id", ""))
	if id.length() < 6 or id.length() > 24 or not id.is_valid_identifier():
		return {}
	var nj = d.get("jogadores")
	var mx = d.get("max")
	var porta = d.get("porta")
	if typeof(nj) != TYPE_FLOAT or typeof(mx) != TYPE_FLOAT or typeof(porta) != TYPE_FLOAT:
		return {}
	if nj < 1 or nj > 6 or mx < 1 or mx > 6 or porta < 1024 or porta > 65535:
		return {}
	var endereco := "%s:%d" % [ip_lan, int(porta)] if ip_lan != "" else str(d.get("endereco", ""))
	if not endereco_valido(endereco):
		return {}
	var nome := _limpar(str(d.get("nome", "")))
	return {
		"id": id,
		"nome": nome if nome != "" else "Sala",
		"anfitriao": _limpar(str(d.get("anfitriao", ""))),
		"jogadores": int(nj),
		"max": int(mx),
		"endereco": endereco
	}


## host:porta com host só de letras, números, ponto e hífen (IP ou nome de túnel).
static func endereco_valido(e: String) -> bool:
	var dois := e.rfind(":")
	if dois <= 0 or e.length() > 80:
		return false
	var host := e.substr(0, dois)
	var porta := e.substr(dois + 1)
	if not porta.is_valid_int() or int(porta) < 1 or int(porta) > 65535:
		return false
	for ch in host:
		if not (ch.is_valid_identifier() or ch.is_valid_int() or ch in [".", "-"]):
			return false
	return true


static func _limpar(s: String) -> String:
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		if (c >= 32 and c < 127) or "áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ".contains(ch):
			out += ch
	return out.strip_edges().left(20)


# ---------------------------------------------------------------- anfitrião


## Anúncio desta sala (o que vai pelo ar). publico = inclui o endereço do túnel.
func anuncio(publico: bool) -> String:
	var d := {
		"v": VERSAO,
		"id": _id,
		"nome": "Sala de " + Rede.apelido,
		"anfitriao": Rede.apelido,
		"jogadores": Rede.jogadores.size(),
		"max": Rede.MAX,
		"porta": Rede.porta_aberta
	}
	if publico:
		d["endereco"] = endereco_publico
	return JSON.stringify(d)


var _udp_pronto := false


func _anunciar_lan() -> void:
	if not _udp_pronto:
		_udp_pronto = true
		_udp_envia.set_broadcast_enabled(true)
		_udp_envia.set_dest_address("255.255.255.255", DESCOBERTA)
	_udp_envia.put_packet(anuncio(false).to_utf8_buffer())


func _anunciar_net() -> void:
	if not endereco_valido(endereco_publico):
		erro_net = "Cole o endereço do túnel (playit) pra sala aparecer na lista pública."
		return
	if _http_publica.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_http_publica.request(NTFY + topico, ["Content-Type: text/plain"], HTTPClient.METHOD_POST, anuncio(true))


func _process(dt: float) -> void:
	if _procurando:
		_ouvir_lan()
		_ler_t -= dt
		if _ler_t <= 0.0:
			_ler_t = LER_CADA
			if _http_le.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
				_http_le.request(NTFY + topico + "/json?poll=1&since=2m")
		var agora := Time.get_ticks_msec() / 1000.0
		for id in salas.keys():
			if agora - float(salas[id].visto) > (LAN_VALE if salas[id].origem == "lan" else NET_VALE):
				salas.erase(id)
	# anfitrião com sala aberta e esperando gente: anuncia
	if Rede.anfitriao() and not Rede.em_partida and Rede.jogadores.size() < Rede.MAX:
		if _id == "":
			_id = "s%d%d" % [randi() % 1000000, Time.get_ticks_msec() % 1000]
		_lan_t -= dt
		if _lan_t <= 0.0:
			_lan_t = LAN_CADA
			_anunciar_lan()
		if publica:
			_net_t -= dt
			if _net_t <= 0.0:
				_net_t = NET_CADA
				_anunciar_net()
	elif not Rede.anfitriao():
		_id = ""
		_net_t = 0.0
