extends Node
## Regressão do steering de borda do robô de playtest: a soma fuga+alvo não pode inverter ao cruzar a faixa; entrada final vai pelo herói real.
const Mundo := preload("res://v2/mundo.tscn")
const Roteiro := preload("res://v2/roteiro.gd")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const Herois := preload("res://v2/herois.gd")
const Ambiente := preload("res://testes/ambiente_v2.gd")
const PASSO := 1.0 / 60.0


class RoteiroCaptura:
	extends "res://v2/roteiro.gd"
	var travas: Array[String] = []

	func _pt_trava(onde: String) -> void:
		travas.append(onde)


class MonstroTeste:
	extends RefCounted
	var pos := Vector2.ZERO
	var chefe := true


var falhas := 0


func _init() -> void:
	Ambiente.iniciar(get_script().resource_path)


func _exit_tree() -> void:
	Ambiente.finalizar()


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Herois.forcado = "hazaki"
	ok(
		(
			Config.arquivo.begins_with(Ambiente.raiz)
			and Meta.caminho_save.begins_with(Ambiente.raiz)
			and Personagens.caminho_indice.begins_with(Ambiente.raiz)
			and Personagens.caminho_base.begins_with(Ambiente.raiz)
			and Personagens.caminho_antigo.begins_with(Ambiente.raiz)
		),
		"opções, meta e saves de personagens começam isolados antes do fluxo"
	)
	ok(Personagens.lista().is_empty() and Meta.saldo() == 0, "fixture começa sem dados herdados")
	_testar_projecao()
	await _testar_fluxo_real()
	Ambiente.finalizar()
	ok(not DirAccess.dir_exists_absolute(Ambiente.raiz), "fixture do robô removida antes do resumo")
	for caminho in [Config.arquivo, Meta.caminho_save, Personagens.caminho_indice, Personagens.caminho_base, Personagens.caminho_antigo]:
		ok(caminho.begins_with(Ambiente.raiz), "callback tardio continua no sandbox: " + caminho)
	print("v2_robo_borda falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _testar_projecao() -> void:
	var lim := Rect2(0.0, 0.0, 1000.0, 600.0)
	var casos := [
		{"nome": "esquerda", "pos": Vector2(20.0, 300.0), "fora": Vector2.LEFT},
		{"nome": "direita", "pos": Vector2(980.0, 300.0), "fora": Vector2.RIGHT},
		{"nome": "cima", "pos": Vector2(500.0, 20.0), "fora": Vector2.UP},
		{"nome": "baixo", "pos": Vector2(500.0, 580.0), "fora": Vector2.DOWN},
		{"nome": "canto superior esquerdo", "pos": Vector2(20.0, 20.0), "fora": Vector2(-1.0, -1.0)},
		{"nome": "canto superior direito", "pos": Vector2(980.0, 20.0), "fora": Vector2(1.0, -1.0)},
		{"nome": "canto inferior esquerdo", "pos": Vector2(20.0, 580.0), "fora": Vector2(-1.0, 1.0)},
		{"nome": "canto inferior direito", "pos": Vector2(980.0, 580.0), "fora": Vector2(1.0, 1.0)},
	]
	for caso in casos:
		var dir: Vector2 = Roteiro._pt_direcao_borda(caso.pos, lim, caso.fora, Vector2.ZERO)
		var repetida: Vector2 = Roteiro._pt_direcao_borda(caso.pos, lim, caso.fora, Vector2.ZERO)
		ok(dir.length_squared() > 0.99, "%s: projeção zero escolhe tangente cardinal" % caso.nome)
		ok(dir == repetida, "%s: fallback tangencial é determinístico" % caso.nome)
		ok(_sem_saida(caso.pos, lim, dir), "%s: tangente não aponta para fora em nenhuma borda" % caso.nome)
		if absf(caso.fora.x) > 0.5 and absf(caso.fora.y) < 0.5:
			ok(absf(dir.x) < 0.001, "%s: fallback é tangente à parede" % caso.nome)
		elif absf(caso.fora.y) > 0.5 and absf(caso.fora.x) < 0.5:
			ok(absf(dir.y) < 0.001, "%s: fallback é tangente à parede" % caso.nome)
	# Uma direção para dentro continua intacta; a projeção só remove o componente externo.
	for caso in [
		{"nome": "esquerda", "pos": Vector2(20.0, 300.0), "dir": Vector2(1.0, -0.3)},
		{"nome": "direita", "pos": Vector2(980.0, 300.0), "dir": Vector2(-1.0, 0.3)},
		{"nome": "cima", "pos": Vector2(500.0, 20.0), "dir": Vector2(0.3, 1.0)},
		{"nome": "baixo", "pos": Vector2(500.0, 580.0), "dir": Vector2(-0.3, -1.0)},
	]:
		var dir: Vector2 = Roteiro._pt_direcao_borda(caso.pos, lim, caso.dir, caso.dir)
		ok(dir == caso.dir, "%s: movimento para dentro preservado" % caso.nome)
	# No interior, fuga e alvo conservam a soma original.
	var combinado := Vector2(0.7, -0.2) * 0.7 + Vector2(-0.4, 0.6) * 1.4
	ok(Roteiro._pt_direcao_borda(Vector2(500.0, 300.0), lim, combinado, Vector2(1.0, 0.0)) == combinado, "interior: soma alvo+fuga preservada")
	# Quando a projeção e o alvo não têm componente viável, a direção perpendicular usa a tangente e nunca restaura a saída.
	var normal_externa := Roteiro._pt_direcao_borda(Vector2(500.0, 580.0), lim, Vector2.DOWN, Vector2.ZERO)
	ok(normal_externa == Vector2.RIGHT, "normal externa pura no sul usa tangente fixa +X")
	# Mesmo com alvo direto para dentro, o zero da projeção usa a tangente para não cruzar o limiar e reativar a fuga externa.
	var alvo_interno := Roteiro._pt_direcao_borda(Vector2(500.0, 580.0), lim, Vector2.DOWN, Vector2.UP)
	ok(alvo_interno == Vector2.RIGHT, "projeção zero não restaura vetor normal que cruzaria o limiar")
	var tangente_pequena := Roteiro._pt_direcao_final(Vector2(500.0, 580.0), lim, Vector2(0.02, 0.0), Vector2.UP)
	ok(tangente_pequena == Vector2(0.02, 0.0), "tangente pequena não é trocada pelo fallback normal do alvo")


func _sem_saida(pos: Vector2, lim: Rect2, dir: Vector2) -> bool:
	if pos.x <= lim.position.x + Roteiro.MARGEM_BORDA_ROBO and dir.x < -0.001:
		return false
	if pos.x >= lim.end.x - Roteiro.MARGEM_BORDA_ROBO and dir.x > 0.001:
		return false
	if pos.y <= lim.position.y + Roteiro.MARGEM_BORDA_ROBO and dir.y < -0.001:
		return false
	if pos.y >= lim.end.y - Roteiro.MARGEM_BORDA_ROBO and dir.y > 0.001:
		return false
	return true


func _testar_fluxo_real() -> void:
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	mundo.id_mapa = "floresta"
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	if mundo.combate == null or mundo.heroi == null or mundo.status == null:
		ok(false, "mundo real terminou a montagem antes do fluxo do robô")
		mundo.queue_free()
		await get_tree().process_frame
		return
	mundo.combate.audio.mudo = true
	mundo.combate.diretor.ligado = false
	var h = mundo.heroi
	var lim: Rect2 = mundo.limite_andavel
	var inicio := Vector2(1188.99, lim.end.y - Roteiro.MARGEM_BORDA_ROBO)
	h.definir_pos(inicio)
	mundo.monstros.clear()
	var inimigo := MonstroTeste.new()
	inimigo.pos = inicio + Vector2.UP * 100.0
	mundo.monstros.append(inimigo)
	var roteiro := RoteiroCaptura.new()
	roteiro.montar(mundo, {"playtest": "1", "semente": "1"})
	roteiro.pt.ponto = inicio + Vector2.UP * 120.0
	roteiro.pt.ponto_t = 0.0
	roteiro.pt.desvio_t = 0.0
	for i in 120:
		inimigo.pos = h.pos + Vector2.UP * 100.0
		roteiro.pt.ponto = h.pos + Vector2.UP * 120.0
		roteiro._pt_jogar(PASSO)
		var entrada: Vector2 = h.entrada_forcada
		ok(entrada.x > 0.99 and absf(entrada.y) < 0.001, "quadro %d: fuga normal externa mantém tangente estável" % i)
		h.atualizar(PASSO)
	ok(
		h.pos.x > inicio.x + 100.0 and absf(h.pos.y - inicio.y) < 6.0,
		(
			"herói real progride lateralmente por 120 quadros sem alternar no limiar (início=%s fim=%s estado=%s andando=%s)"
			% [str(inicio), str(h.pos), str(h.estado), str(h.andando)]
		)
	)
	# Ida e volta de 70 px dentro dos mesmos 30 s não pode ser confundida com imobilidade só porque os extremos coincidem.
	h.definir_pos(inicio)
	roteiro.pt.preso_pos = inicio
	roteiro.pt.preso_t = 0.0
	roteiro.travas.clear()
	var caminho := [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 60.0, 50.0, 40.0, 30.0, 0.0]
	for x in caminho:
		h.definir_pos(inicio + Vector2(x, 0.0))
		inimigo.pos = h.pos + Vector2.UP * 100.0
		roteiro.pt.ponto = h.pos + Vector2.UP * 120.0
		roteiro._pt_jogar(2.5)
	ok(roteiro.travas.is_empty(), "ida e volta de 70 px em 30 s não acusa herói preso")
	ok(roteiro.pt.preso_t < 0.01, "cada excursão de 6 px reinicia o relógio de imobilidade")
	# Uma parada real e um jitter de 2 px continuam abaixo do limiar de movimento e disparam após 30 s.
	for jitter in [false, true]:
		h.definir_pos(inicio)
		inimigo.pos = inicio + Vector2.UP * 100.0
		roteiro.pt.ponto = inicio + Vector2.UP * 120.0
		roteiro.pt.preso_pos = inicio
		roteiro.pt.preso_t = 0.0
		roteiro.travas.clear()
		for quadro in 60:
			if jitter:
				h.definir_pos(inicio + Vector2(2.0 if quadro % 2 == 0 else 0.0, 0.0))
			roteiro.pt.ponto = h.pos + Vector2.UP * 120.0
			inimigo.pos = h.pos + Vector2.UP * 100.0
			roteiro._pt_jogar(0.5)
			if quadro < 59:
				ok(roteiro.travas.is_empty(), "quadro %d: espera 30 s antes de acusar %s" % [quadro, "jitter" if jitter else "parada"])
		ok(
			roteiro.travas.size() == 1 and roteiro.travas[0].begins_with("heroi_preso"),
			"%s abaixo de 6 px continua detectado em 30 s" % ("jitter" if jitter else "parada")
		)
	mundo.queue_free()
	await get_tree().process_frame
