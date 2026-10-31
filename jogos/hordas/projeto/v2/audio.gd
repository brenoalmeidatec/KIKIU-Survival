extends Node
## Efeitos sonoros da v2: um punhado de AudioStreamPlayer reaproveitados (nada de nó por som). Os WAV ficam em assets/audio/v2/
## (sons CC0 do Kenney, cortados e normalizados; registro em docs/LICENCAS_AUDIO.md). O gerador sintetizado
## (jogos/hordas/fonte_audio/gerar_v2_sfx.py) ficou como reserva. O volume segue o das Opções (Som.volume_efeitos, o autoload
## do jogo). Sem WAV, tocar() não faz nada.

const PASTA := "res://assets/audio/v2/"
const VOZES := 10
const INV_VOZES := 3  # orçamento separado: aliados nunca ocupam as vozes do herói e da interface
const INV_INTERVALO := 0.06
const INV_INTERVALOS := {"nascer": 0.16, "atacar": 0.12, "sumir": 0.16}
const INV_ATAQUES := {"garras": "corte2", "arco": "corte1", "fogo": "fogo", "pancada": "impacto", "nevoa": "corvo", "bote": "estocada", "golem": "impacto"}
const INV_STREAMS := ["runa_poe", "bau_cai", "esquiva", "morte", "corte2", "corte1", "fogo", "impacto", "corvo", "estocada"]

## Sons que não podem se perder no meio da horda: se as 10 vozes estiverem ocupadas, eles tomam a voz de um som comum (golpe, morte, orbe).
## Antes a voz ocupada descartava o som em silêncio, e o aviso e o estouro da Maré de Sangue sumiam justo quando 20 monstros morriam de uma vez.
const PRIORITARIOS := ["onda", "elite", "chefe", "evolucao", "nivel", "vitoria", "derrota", "aviso", "ruptura_pronta", "ruptura_carga", "ruptura_disparo"]

var mudo := false
var descartados := 0  # sons comuns que ficaram sem voz livre (testes e medição)
var roubados := 0  # vozes tomadas por um som prioritário
var tocados := 0  # quantos sons saíram (testes)
var ultimo := ""  # o último som pedido (testes)
var _players: Array[AudioStreamPlayer] = []
var _voz_nome: Array[String] = []  # o que cada voz de _players toca (para saber quem pode ser roubado)
var _voz_ini: Array[float] = []  # quando cada voz começou (s)
var _streams := {}
var _ultimo_t := {}
var inv_tocados := 0
var inv_negados := 0
var inv_pico := 0
var inv_eventos := {"nascer": 0, "atacar": 0, "sumir": 0}  # eventos reais, inclusive os silenciados pelo orçamento
var _inv_players: Array[AudioStreamPlayer] = []
var _inv_ids: Array[int] = []
var _inv_itens: Array[Dictionary] = []  # três referências, só enquanto a voz toca; permite cortar caudas no restart
var _inv_fontes := {}  # geração -> {it, perfil, tom, sumiu}; no máximo os aliados vivos do pool
var _inv_seq := 0
var _inv_t := 0.0
var _inv_proximo := 0.0
var _inv_evento_t := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOZES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
		_voz_nome.append("")
		_voz_ini.append(0.0)
	for i in INV_VOZES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_inv_players.append(p)
		_inv_ids.append(0)
		_inv_itens.append({})
	for nome in INV_STREAMS:
		_stream(nome)  # nada de load no nascimento, no ataque ou por quadro
	set_process(false)  # só observa o mundo enquanto há uma fonte ou uma voz de invocação


## Registra a geração do slot, sem referência forte de volta para o áudio. Fusões usam o perfil da ficha já resolvida.
func registrar_invocacao(it: Dictionary, perfil: String, tom := 1.0) -> void:
	cancelar_invocacao(int(it.get("som_inv_id", 0)))
	_inv_seq += 1
	it.som_inv_id = _inv_seq
	it.som_inv_audio = weakref(self)
	_inv_fontes[_inv_seq] = {"it": it, "perfil": perfil, "tom": tom, "sumiu": false}
	set_process(true)
	invocacao(it, "nascer")


## Os gatilhos chamam uma vez no impacto/começo do sumir, mesmo se o orçamento não deixar ouvir aquele evento.
func invocacao(it: Dictionary, evento: String) -> void:
	var id := int(it.get("som_inv_id", 0))
	if not _inv_fontes.has(id) or not INV_INTERVALOS.has(evento):
		return
	var fonte: Dictionary = _inv_fontes[id]
	if evento == "sumir":
		if bool(fonte.sumiu):
			return
		fonte.sumiu = true
		_parar_fonte(id)  # uma retirada/interrupção não deixa o ataque anterior tocando
	inv_eventos[evento] = int(inv_eventos[evento]) + 1
	_tocar_invocacao(id, evento, fonte)


## O restart cancela silenciosamente. Reaproveitar um slot retirado antes do observador pode completar sua saída uma vez.
func cancelar_invocacao(id: int, retirada := false) -> void:
	if id == 0:
		return
	_parar_fonte(id)
	if retirada and _inv_fontes.has(id):
		invocacao(_inv_fontes[id].it, "sumir")
		for i in _inv_players.size():
			if _inv_ids[i] == id:
				_inv_ids[i] = 0  # a cauda de saída não pertence à geração nova do slot
	_inv_fontes.erase(id)


## Também corta uma cauda de saída que começou antes de o slot ganhar uma geração nova.
func cancelar_slot_invocacao(it: Dictionary) -> void:
	for i in _inv_players.size():
		if is_same(_inv_itens[i], it):
			_inv_players[i].stop()
			_inv_ids[i] = 0
			_inv_itens[i] = {}


func _parar_fonte(id: int) -> void:
	for i in _inv_players.size():
		if _inv_ids[i] == id:
			_inv_players[i].stop()
			_inv_ids[i] = 0
			_inv_itens[i] = {}


func _pode_invocacao() -> bool:
	if not is_inside_tree() or get_tree().paused:
		return false
	var mundo := get_parent()
	var c = mundo.get("combate") if mundo != null else null
	return c != null and c.jogo == "jogando" and not c.pausado and not c.pausado_mundo


func _process(dt: float) -> void:
	_inv_t += dt
	var pode := _pode_invocacao()
	if not pode or mudo:
		_parar_invocacoes()
	# Retirada instantânea (inclusive fusão) não passa por Andante/Golem.mover: o slot fica com vida zero.
	# No restart, limpar_restos já cancelou o registro; na pausa descarta a saída, sem enfileirar som para depois.
	for id in _inv_fontes.keys():
		var fonte: Dictionary = _inv_fontes[id]
		var it: Dictionary = fonte.it
		if int(it.get("som_inv_id", 0)) != int(id):
			cancelar_invocacao(int(id))
		elif float(it.vida) <= 0.0:
			if pode and not mudo:
				invocacao(it, "sumir")
			_inv_fontes.erase(id)
	var tocando := false
	for i in _inv_players.size():
		if _inv_players[i].playing:
			tocando = true
		else:
			_inv_ids[i] = 0
			_inv_itens[i] = {}
	if _inv_fontes.is_empty() and not tocando:
		set_process(false)


func _parar_invocacoes() -> void:
	for i in _inv_players.size():
		_inv_players[i].stop()
		_inv_ids[i] = 0
		_inv_itens[i] = {}
	_inv_proximo = _inv_t
	_inv_evento_t.clear()


func _tocar_invocacao(id: int, evento: String, fonte: Dictionary) -> void:
	if mudo or not _pode_invocacao():
		return
	if _inv_t < _inv_proximo or _inv_t < float(_inv_evento_t.get(evento, -1.0)):
		inv_negados += 1
		return
	var livre := -1
	var ativos := 0
	for i in _inv_players.size():
		if _inv_players[i].playing:
			ativos += 1
		elif livre < 0:
			livre = i
	if livre < 0:
		inv_negados += 1
		return
	var perfil := str(fonte.perfil)
	var nome := str(INV_ATAQUES.get(perfil, "corte2"))
	var tom := float(fonte.tom)
	var db := -14.0
	if evento == "nascer":
		nome = "bau_cai" if perfil == "golem" else "runa_poe"
		db = -16.0
	elif evento == "sumir":
		nome = "morte" if perfil == "golem" else "esquiva"
		db = -18.0
	var s: AudioStream = _streams.get(nome)
	if s == null:
		return
	var vol := 0.8
	var som := get_node_or_null("/root/Som")
	if som != null:
		vol = float(som.get("volume_efeitos"))
	var p := _inv_players[livre]
	p.stream = s
	p.pitch_scale = clampf(tom, 0.5, 2.0)
	p.volume_db = linear_to_db(maxf(vol, 0.0001)) + db
	p.play()
	_inv_ids[livre] = id
	_inv_itens[livre] = fonte.it
	_inv_proximo = _inv_t + INV_INTERVALO
	_inv_evento_t[evento] = _inv_t + float(INV_INTERVALOS[evento])
	inv_tocados += 1
	inv_pico = maxi(inv_pico, ativos + 1)


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
	var i := _voz_livre()
	if i < 0:
		if not PRIORITARIOS.has(nome):
			descartados += 1
			return
		i = _voz_para_roubar()
		if i < 0:
			descartados += 1
			return
		roubados += 1
	var p := _players[i]
	p.stream = s
	p.pitch_scale = tom
	p.volume_db = linear_to_db(maxf(vol, 0.0001)) + vol_db
	p.play()
	_voz_nome[i] = nome
	_voz_ini[i] = agora


func _voz_livre() -> int:
	for i in _players.size():
		if not _players[i].playing:
			return i
	return -1


## A voz com um som comum que começou há mais tempo (a mais perto de acabar); -1 se todas tocam sons prioritários.
func _voz_para_roubar() -> int:
	var melhor := -1
	for i in _players.size():
		if PRIORITARIOS.has(_voz_nome[i]):
			continue
		if melhor < 0 or _voz_ini[i] < _voz_ini[melhor]:
			melhor = i
	return melhor


func _stream(nome: String) -> AudioStream:
	if not _streams.has(nome):
		var c := PASTA + nome + ".wav"
		_streams[nome] = load(c) if ResourceLoader.exists(c) else null
	return _streams[nome]
