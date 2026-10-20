extends Node
## Teste dos eventos reais dos andantes/golem/fusões, orçamento separado e cancelamento de voz por geração do pool.
## Usa os módulos reais e efeitos sem desenho; sem inimigos/texturas. O teste das vozes usa um WAV silencioso em vez de som audível.
const AudioV2 := preload("res://v2/audio.gd")
const Andante := preload("res://v2/andante.gd")
const Golem := preload("res://v2/golem.gd")
var falhas := 0
var w: MundoTeste
var audio
var nv: NovasTeste


class MundoTeste:
	extends Node
	var combate := {"jogo": "jogando", "pausado": false, "pausado_mundo": false}
	var heroi := {"pos": Vector2(10000, 10000)}
	var cam := CameraTeste.new()


class CameraTeste:
	extends RefCounted

	func tremer(_v, _s):
		pass


class EfeitosTeste:
	extends RefCounted
	var fator_part := 0.25

	func onda(_p, _c, _r, _t):
		pass

	func faiscas(_p, _v, _n, _c, _vel):
		pass

	func luz_rapida(_p, _c, _f, _r, _t):
		pass

	func folha(_id, _p, _r, _c, _t):
		pass

	func particula(_p, _v, _t, _r, _c, _g, _brilho = false):
		pass


class ArmasTeste:
	extends RefCounted
	var fx := EfeitosTeste.new()
	var combate: Dictionary
	var mundo
	var danos := 0

	func _dano_area(_p, _r, _d, _emp, _at, _cor, _tipo):
		danos += 1


class NovasTeste:
	extends RefCounted
	var pai := ArmasTeste.new()

	func _dano(_st):
		return 1.0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func item(id: String) -> Dictionary:
	var it := {"a": {"id": id, "st": {"tique": 1.2, "vel": 0.0}, "cor": Color.WHITE}, "p": Vector2.ZERO, "vida": 4.0, "t": 0.0, "fase": 0.0, "r": 1.0}
	Golem.zerar(it)
	Andante.zerar(it)
	return it


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # o runner continua observando a árvore pausada
	w = MundoTeste.new()
	w.process_mode = Node.PROCESS_MODE_PAUSABLE  # como o mundo real; só o áudio tem sua própria exceção de processamento
	add_child(w)
	audio = AudioV2.new()
	w.add_child(audio)
	audio.set_process(false)  # o teste avança os relógios explicitamente
	w.combate.audio = audio
	nv = NovasTeste.new()
	nv.pai.combate = w.combate
	nv.pai.mundo = w
	_dados_e_eventos()
	_orcamento_e_volume()
	_cancelamentos()
	await _pausa_real()
	await get_tree().create_timer(0.15).timeout  # o mixer libera os playbacks interrompidos antes de encerrar o processo
	w.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout  # a remoção dos players também passa pela fila do mixer
	print("v2_som_invocacoes falhas=%d" % falhas)
	get_tree().quit()


func _dados_e_eventos() -> void:
	audio.mudo = true
	for nome in AudioV2.INV_STREAMS:
		ok(audio._streams.get(nome) != null, "WAV existente pré-carregado: %s" % nome)
	for id in Andante.FICHAS:
		for base in Andante.bases(str(id)):
			var it := item(str(id))
			var nascer0: int = audio.inv_eventos.nascer
			Andante.nascer(nv, it)
			ok(str(audio._inv_fontes[it.som_inv_id].perfil) == str(Andante.ficha_de(it).get("rastro", "garras")), "%s nasce com o perfil da base sorteada" % id)
			# Exercita cada base dos alias, não apenas a que o rodízio escolheu neste nascimento.
			if Andante.eh_alias(str(id)):
				it.fid = "%s/%s" % [id, base]
				Golem.limpar_restos(it)
				audio.registrar_invocacao(it, str(Andante.ficha_de(it).get("rastro", "garras")))
			var f := Andante.ficha_de(it)
			var fonte: Dictionary = audio._inv_fontes[it.som_inv_id]
			ok(str(fonte.perfil) == str(f.get("rastro", "garras")), "%s/%s usa perfil da ficha resolvida" % [id, base])
			ok(int(audio.inv_eventos.nascer) > nascer0, "%s nasce com evento sonoro" % id)
			var atacar0: int = audio.inv_eventos.atacar
			it.e = Andante.ATACANDO
			it.et = Andante.tempo_impacto(f) - 0.001
			Andante._atacar(nv, it, f)
			ok(int(audio.inv_eventos.atacar) == atacar0, "%s não soa antes do impacto" % id)
			it.et = Andante.tempo_impacto(f) + 0.001
			Andante._atacar(nv, it, f)
			Andante._atacar(nv, it, f)
			ok(int(audio.inv_eventos.atacar) == atacar0 + 1, "%s soa uma vez no impacto" % id)
			var sumir0: int = audio.inv_eventos.sumir
			it.vida = 0.4
			Andante.mover(nv, it, w.heroi, 0.01, [])
			Andante.mover(nv, it, w.heroi, 0.01, [])
			ok(int(audio.inv_eventos.sumir) == sumir0 + 1, "%s soa uma vez ao sumir" % id)
			Golem.limpar_restos(it)
	for id in ["golem_barro", Golem.COLOSSO]:
		var it := item(id)
		var antes: int = audio.inv_eventos.nascer
		Golem.nascer(nv, it)
		ok(int(audio.inv_eventos.nascer) == antes + 1, "%s soa ao nascer" % id)
		ok(str(audio._inv_fontes[it.som_inv_id].perfil) == "golem", "%s usa perfil grave" % id)
		var atacar0: int = audio.inv_eventos.atacar
		it.e = Golem.ATACANDO
		it.et = Golem.tempo_impacto() + 0.001
		Golem._atacar(nv, it)
		Golem._atacar(nv, it)
		ok(int(audio.inv_eventos.atacar) == atacar0 + 1, "%s soa uma vez na pancada" % id)
		var sumir0: int = audio.inv_eventos.sumir
		it.vida = 0.4
		Golem.mover(nv, it, w.heroi, 0.01, [])
		Golem.mover(nv, it, w.heroi, 0.01, [])
		ok(int(audio.inv_eventos.sumir) == sumir0 + 1, "%s soa uma vez ao desmoronar" % id)
		Golem.limpar_restos(it)
	var interrompido := item("espirito_urso")
	Andante.nascer(nv, interrompido)
	interrompido.e = Andante.ATACANDO
	interrompido.et = 0.0
	interrompido.vida = 0.4
	var ataques0: int = audio.inv_eventos.atacar
	Andante.mover(nv, interrompido, w.heroi, 0.01, [])
	ok(int(audio.inv_eventos.atacar) == ataques0, "ataque interrompido pelo fim da vida não toca impacto")
	Golem.limpar_restos(interrompido)
	ok(audio._inv_fontes.is_empty(), "ciclo natural libera os registros")


func _orcamento_e_volume() -> void:
	audio.mudo = false
	audio._parar_invocacoes()
	# Um WAV silencioso longo só no teste permite medir vozes simultâneas sem esperar pelo relógio do áudio.
	var silencio := AudioStreamWAV.new()
	silencio.mix_rate = 8000
	silencio.format = AudioStreamWAV.FORMAT_8_BITS
	var bytes := PackedByteArray()
	bytes.resize(80000)
	bytes.fill(128)
	silencio.data = bytes
	for nome in AudioV2.INV_STREAMS:
		audio._streams[nome] = silencio
	var fontes: Array[Dictionary] = []
	for i in AudioV2.INV_VOZES:
		var it := item("espirito_urso")
		fontes.append(it)
		audio._process(0.2)
		audio.registrar_invocacao(it, "garras")
	var sons0: int = audio.inv_tocados
	var extra := item("espirito_urso")
	fontes.append(extra)
	audio._process(0.2)
	audio.registrar_invocacao(extra, "garras")
	ok(audio.inv_pico == AudioV2.INV_VOZES and audio.inv_tocados == sons0, "pool cheio nega sem cortar nenhuma das três vozes")
	ok(audio._players.size() == AudioV2.VOZES, "vozes de combate permanecem separadas")
	for p in audio._inv_players:
		ok(p.playing, "vozes anteriores continuam tocando quando o pool lota")
		ok(p.volume_db <= -16.0, "nascimento tem volume baixo e segue o volume de efeitos")
	for it in fontes:
		Golem.limpar_restos(it)
	audio._process(0.2)
	var it := item("espirito_urso")
	audio.registrar_invocacao(it, "garras")
	sons0 = audio.inv_tocados
	for i in 30:
		audio.invocacao(it, "atacar")
	ok(audio.inv_tocados == sons0, "intervalo global barra a rajada de trinta eventos no mesmo quadro")
	audio._process(0.2)
	audio.invocacao(it, "atacar")
	sons0 = audio.inv_tocados
	audio._process(0.07)
	audio.invocacao(it, "atacar")
	ok(audio.inv_tocados == sons0, "intervalo por evento limita ataques mesmo depois do intervalo global")
	for p in audio._inv_players:
		if p.playing:
			ok(p.volume_db <= -14.0, "ataque tem volume baixo")
	Golem.limpar_restos(it)


func _cancelamentos() -> void:
	for estado in ["pausa", "escolha", "bau", "morte", "vitoria"]:
		var it := item("espirito_urso")
		audio._process(0.2)
		audio.registrar_invocacao(it, "garras")
		if estado == "pausa":
			get_tree().paused = true
		else:
			w.combate.jogo = estado
		audio._process(0.01)
		for p in audio._inv_players:
			ok(not p.playing, "%s interrompe áudio já em voo" % estado)
		var sons0: int = audio.inv_tocados
		audio.invocacao(it, "atacar")
		ok(audio.inv_tocados == sons0, "%s não inicia som" % estado)
		get_tree().paused = false
		w.combate.jogo = "jogando"
		audio._process(0.2)
		ok(audio.inv_tocados == sons0, "retomar %s não reproduz fila antiga" % estado)
		Golem.limpar_restos(it)
	var it := item("espirito_urso")
	audio._process(0.2)
	audio.registrar_invocacao(it, "garras")
	var id0: int = it.som_inv_id
	var sumir0: int = audio.inv_eventos.sumir
	it.vida = 0.0  # armas_novas.remover: retirada instantânea para a fusão
	audio._process(0.2)
	audio._process(0.2)
	ok(int(audio.inv_eventos.sumir) == sumir0 + 1 and audio._inv_fontes.is_empty(), "retirada por fusão emite saída única e libera fonte")
	Golem.zerar(it)  # _novo reutiliza o mesmo Dictionary
	it.vida = 4.0
	audio.registrar_invocacao(it, "arco")
	ok(int(it.som_inv_id) != id0 and audio._inv_fontes.size() == 1, "slot reutilizado recebe geração nova")
	for id in audio._inv_ids:
		ok(id != id0, "nenhuma voz da geração anterior sobrevive ao reaproveitamento")
	sumir0 = audio.inv_eventos.sumir
	it.vida = 0.0
	Golem.limpar_restos(it)  # armas_novas.limpar: restart, silencioso
	audio._process(0.2)
	ok(int(audio.inv_eventos.sumir) == sumir0 and audio._inv_fontes.is_empty(), "restart limpa silenciosamente, sem simular saída de fusão")
	for p in audio._inv_players:
		ok(not p.playing, "restart corta vozes das fontes removidas")
	ok(it.som_inv_audio == null, "limpeza solta o WeakRef do slot")
	ok(not audio.is_processing(), "sem fontes ou vozes o observador deixa de rodar")
	# Uma fusão pode retirar e reutilizar o slot no mesmo quadro, antes de Audio._process observar vida zero.
	it = item("espirito_urso")
	audio._process(0.2)
	audio.registrar_invocacao(it, "garras")
	sumir0 = audio.inv_eventos.sumir
	it.vida = 0.0
	it.a = {"id": "exercito_esquecido", "st": {"tique": 1.0}, "cor": Color.WHITE}
	it.vida = 4.0  # _novo preenche a nova vida antes de chamar zerar
	Golem.zerar(it)
	ok(int(audio.inv_eventos.sumir) == sumir0 + 1, "fusão e reutilização no mesmo quadro não perdem o evento de saída")
	audio.registrar_invocacao(it, "arco")
	Golem.limpar_restos(it)
	audio._process(0.2)
	for p in audio._inv_players:
		ok(not p.playing, "restart também corta a cauda da geração anterior")
	for fonte in audio._inv_itens:
		ok(fonte.is_empty(), "voz encerrada libera sua referência ao Dictionary do pool")
	it = item("espirito_urso")
	audio._process(0.2)
	audio.registrar_invocacao(it, "garras")
	audio._process(0.2)
	it.a = {"id": "projetil", "st": {}, "cor": Color.WHITE}
	Golem.zerar(it)  # slot reaproveitado por algo que não vai registrar nova invocação
	var caudas := 0
	for p in audio._inv_players:
		if p.playing:
			caudas += 1
	ok(caudas == 1, "reaproveitar como projétil deixa somente a saída curta anterior")
	Golem.limpar_restos(it)
	for p in audio._inv_players:
		ok(not p.playing, "restart corta a cauda mesmo se o slot virou projétil")
	ok(it.som_inv_audio == null, "restart solta WeakRef também de slot que virou projétil")


func _pausa_real() -> void:
	audio._parar_invocacoes()
	var it := item("espirito_urso")
	audio.registrar_invocacao(it, "garras")
	var tocando := 0
	for p in audio._inv_players:
		if p.playing:
			tocando += 1
	ok(tocando == 1, "cenário ESC começa com uma voz realmente tocando")
	var sons0: int = audio.inv_tocados
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	# Não chama Audio._process: o próprio nó deve receber os frames enquanto o mundo está pausado.
	for p in audio._inv_players:
		ok(not p.playing, "dois frames reais de ESC cortam a voz em andamento")
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame
	ok(int(audio.inv_tocados) == sons0, "fechar ESC não retoma nem dispara a cauda antiga")
	for p in audio._inv_players:
		ok(not p.playing, "a voz cortada não reaparece depois de retomar a árvore")
	Golem.limpar_restos(it)
