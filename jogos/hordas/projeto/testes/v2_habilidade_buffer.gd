extends "res://testes/isolamento_v2.gd"
## Buffer da E por tempo: execução única, recarga, cancelamentos e troca de forma real.
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, mensagem: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", mensagem)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func novo(id: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	preparar()


func preparar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.velocidade = 1.0
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = false
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.ruptura_forcada = false
	h.escudo_forcado = false
	h.invenc = 0.0
	h.folego = h.folego_max
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)


## O aperto dentro da janela deve ser aceito, sem o feedback de negação.
func pedir() -> void:
	var h = w.heroi
	h.hab_recarga = 0.08
	h.hab_nega_t = 0.0
	var negados: int = h.hab_negados
	h.habilidade()
	ok(h.hab_negados == negados and h.hab_nega_t == 0.0, "dentro da janela: pedido aceito sem negação")


func comportamento(id: String) -> void:
	preparar()
	var h = w.heroi
	var antes: int = h.hab_disparos
	pedir()
	h.habilidade()  # dois apertos guardam só um pedido
	ok(h.hab_negados == 0, "%s: dois apertos próximos não negam" % id)
	passos(4)
	ok(h.hab_disparos == antes and h.hab_recarga > 0.0, "%s: não dispara antes da recarga zerar" % id)
	passos(1)
	ok(h.hab_disparos == antes + 1 and h.estado == Heroi.Estado.HABILIDADE, "%s: dispara no quadro da recarga zerada" % id)
	passos(50)
	ok(h.hab_disparos == antes + 1, "%s: dois apertos produzem um disparo só" % id)
	preparar()
	antes = h.hab_disparos
	h.hab_recarga = 0.12
	h.habilidade()
	ok(h.hab_negados == 1 and h.hab_nega_t > 0.0, "%s: fora da janela nega normalmente" % id)
	passos(12)
	ok(h.hab_disparos == antes, "%s: pedido fora da janela nunca dispara" % id)


func limite_e_mira() -> void:
	preparar()
	var h = w.heroi
	var antes: int = h.hab_disparos
	h.hab_recarga = 0.10
	h.habilidade()
	ok(h.hab_negados == 0 and h.hab_nega_t == 0.0, "na fronteira de 0,10 s o pedido é aceito")
	for i in 7:
		var recarga_anterior: float = h.hab_recarga
		passos(1)
		if h.hab_disparos > antes:
			ok(recarga_anterior > 0.0, "a recarga só dispara ao chegar a zero")
			break
		ok(h.hab_recarga > 0.0, "se a recarga zerou, dispara no mesmo quadro")
	ok(h.hab_disparos == antes + 1, "a fronteira de 0,10 s dispara uma vez")
	preparar()
	antes = h.hab_disparos
	pedir()
	passos(4)
	w.mouse_forcado = h.centro() + Vector2(0, -100)
	passos(1)
	ok(h.hab_disparos == antes + 1, "pedido pendente dispara quando a recarga termina")
	ok(w.combate.habilidade._dir.dot(Vector2.UP) > 0.95, "E usa a mira atual no quadro do disparo")


func cancelar_menu(tipo: String) -> void:
	preparar()
	var h = w.heroi
	pedir()
	var antes: int = h.hab_disparos
	if tipo == "pausa":
		ok(w.pausa.pausar(), "a pausa realmente abriu")
		w.pausa.fechar()
	elif tipo == "carta":
		w.combate.telas.mostrar_escolha([], 1)
		ok(w.combate.telas.escolha_aberta, "a escolha realmente abriu")
		w.combate.telas.esconder()
	else:
		w.combate.telas.mostrar_bau([])
		ok(w.combate.telas.bau_aberto, "o baú realmente abriu")
		w.combate.telas.esconder()
	# Abriu e fechou sem avançar o mundo: guardar só em atualizar não basta.
	passos(12)
	ok(h.hab_disparos == antes, "%s descarta o pedido mesmo sem quadro intermediário" % tipo)


func apertar_no_menu(tipo: String) -> void:
	preparar()
	var h = w.heroi
	h.hab_recarga = 0.08
	var antes: int = h.hab_disparos
	if tipo == "carta":
		w.combate.telas.mostrar_escolha([], 1)
	else:
		w.combate.telas.mostrar_bau([])
	h.habilidade()
	w.combate.telas.esconder()
	passos(12)
	ok(h.hab_disparos == antes and h.hab_negados == 0, "E apertada em %s não vaza para a partida" % tipo)


func cancelar_morte_reinicio_estado() -> void:
	preparar()
	var h = w.heroi
	pedir()
	var antes: int = h.hab_disparos
	h.levar_dano(h.vida + 100.0, h.pos + Vector2(10, 0))
	ok(h.estado == Heroi.Estado.MORTO, "o dano matou o herói")
	# Ressuscitação sintética sem reset testa o cancelamento no evento da morte.
	h.estado = Heroi.Estado.LIVRE
	h.vida = h.vida_max
	w.combate.jogo = "jogando"
	passos(12)
	ok(h.hab_disparos == antes, "morte descarta o pedido")
	preparar()
	pedir()
	w.reiniciar()
	h.hab_recarga = 0.08
	antes = h.hab_disparos
	passos(12)
	ok(h.hab_disparos == antes, "reiniciar descarta o pedido")
	preparar()
	pedir()
	antes = h.hab_disparos
	h.esp_carga = h.esp_carga_max
	ok(h.especial(), "Q começou realmente")
	h.estado = Heroi.Estado.LIVRE
	passos(12)
	ok(h.hab_disparos == antes, "iniciar especial descarta o pedido sem tick intermediário")
	preparar()
	pedir()
	antes = h.hab_disparos
	h.estado = Heroi.Estado.HABILIDADE
	h._hab_relogios(PASSO)
	h.estado = Heroi.Estado.LIVRE
	passos(12)
	ok(h.hab_disparos == antes, "estado HABILIDADE descarta o pedido")


func cancelar_troca_forma() -> void:
	preparar()
	var h = w.heroi
	pedir()
	var antes: int = h.hab_disparos
	w.combate.mecha.virar_lobo(h, 20.0)
	ok(h.forma_lobo, "a troca real para lobo ocorreu")
	w.combate.mecha.chegar(h)
	ok(not h.forma_lobo, "a troca real de volta ocorreu")
	passos(12)
	ok(h.hab_disparos == antes, "trocar mecha-lobo-mecha descarta o pedido sem tick")


func _ready() -> void:
	var inicio := Time.get_ticks_msec()
	var dados: Dictionary = Dados.json("v2_habilidade")
	ok(is_equal_approx(float(dados.comum.get("buffer_s", -1.0)), 0.10), "janela de 0,10 s vem dos dados")
	for id in ["nicao", "lucas", "lightwolf"]:
		await novo(id)
		comportamento(id)
	await novo("nicao")
	limite_e_mira()
	for tipo in ["pausa", "carta", "bau"]:
		cancelar_menu(tipo)
	for tipo in ["carta", "bau"]:
		apertar_no_menu(tipo)
	cancelar_morte_reinicio_estado()
	await novo("lightwolf")
	cancelar_troca_forma()
	w.queue_free()
	await get_tree().process_frame
	Herois.forcado = ""
	print("v2_habilidade_buffer falhas=%d duracao_ms=%d" % [falhas, Time.get_ticks_msec() - inicio])
	get_tree().quit(1 if falhas else 0)
