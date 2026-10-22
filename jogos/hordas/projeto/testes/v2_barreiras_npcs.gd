extends "res://testes/isolamento_v2.gd"
## Teste automático: NENHUM npc atravessa uma barreira (caixa do cenário): nem inimigo (horda, perseguindo o herói, e puxado pela
## tempestade) nem aliado (andante, golem e o aliado simples de armas_novas). Uma caixa estreita e alta fica no meio do caminho entre
## o bicho e o alvo (desencontrada em y, para ele ter de deslizar pela face); a cada quadro o corpo tem de estar fora da caixa, e no fim
## tem de ter passado dela (contornou, não prendeu). Todo movimento deles passa por mundo.mover / mundo.mover_ponto (v2/mundo.gd).
## Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_barreiras_npcs.tscn  (imprime "v2_barreiras_npcs falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Colisao := preload("res://v2/colisao.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const MEIO := Vector2(14.0, 40.0)  # meia-largura e meia-profundidade da caixa (px)
const RAIO_ALIADO := 7.0
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		if falhas <= 40:
			print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Folga do corpo (elipse r x r/2) contra a caixa centrada em c, no espaço com y escalado por 2 (negativa = dentro).
func folga(c: Vector2, p: Vector2, raio: float) -> float:
	var q := (p - c) * Vector2(1.0, 2.0)
	var meio := MEIO * Vector2(1.0, 2.0)
	var d := q - Vector2(clampf(q.x, -meio.x, meio.x), clampf(q.y, -meio.y, meio.y))
	if d.length() > 0.0001:
		return d.length() - raio
	return -minf(meio.x - absf(q.x), meio.y - absf(q.y)) - raio


func caixa(c: Vector2) -> void:
	Colisao.limpar()
	Colisao.adicionar_objeto(Vector2.ZERO, [{"tipo": "caixa", "centro": [c.x, c.y], "meio": [MEIO.x, MEIO.y]}])


func preparar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	passos(3)


func alvo_parado(p: Vector2):
	var m = w.nascer_monstro("inimigo_cao_ossos", p)
	m.vida_max = 100000.0
	m.vida = 100000.0
	m.cacador = false
	m.raio_vaga = 0.0
	m.vel_mult = 0.0
	return m


## Inimigo comum perseguindo o herói com a caixa no meio.
func checar_inimigo() -> void:
	preparar()
	var h: Vector2 = w.heroi.pos
	var c := h + Vector2(70.0, -12.0) + Vector2(0.0, -MEIO.y + 6.0)  # a caixa termina 6 px abaixo da reta do monstro ao herói: ele desliza e dobra a quina
	caixa(c)
	var m = w.nascer_monstro("inimigo_cao_ossos", h + Vector2(150.0, -24.0), true)
	m.raio_vaga = 0.0
	var pior := 999.0
	for i in 60 * 5:
		passos(1)
		pior = minf(pior, folga(c, m.pos, m.raio))
	ok(pior >= -0.05, "inimigo: entrou na caixa (pior folga %.2f)" % pior)
	ok(
		m.pos.distance_to(h) < 40.0,
		"inimigo: perseguiu o herói e contornou a caixa (a %.0f px dele, preso em x=%.0f, caixa em %.0f)" % [m.pos.distance_to(h), m.pos.x, c.x]
	)


## A tempestade primordial puxa para dentro da caixa: o monstro para na face.
func checar_puxao() -> void:
	preparar()
	var h: Vector2 = w.heroi.pos
	var c := h + Vector2(0.0, 120.0)
	caixa(c)
	var m = alvo_parado(c + Vector2(MEIO.x + 40.0, 0.0))
	var pior := 999.0
	for i in 60:
		w.combate.armas.novas._puxar(c, 120.0, 12.0)
		pior = minf(pior, folga(c, m.pos, m.raio))
	ok(pior >= -0.05, "puxão: o monstro foi puxado para dentro da caixa (pior folga %.2f)" % pior)
	ok(m.pos.x - c.x < MEIO.x + 40.0, "puxão: o monstro foi puxado de verdade até a face (x=%.0f)" % (m.pos.x - c.x))


func aliado_vivo():
	for it in w.combate.armas.novas.itens:
		if float(it.vida) > 0.0 and it.has("a") and it.has("g"):
			return it
	return null


## Aliado `id` anda até um alvo parado do outro lado da caixa. Duas vezes: com o andar próprio dele (Andante/Golem, an/g) e com an/g
## zerados logo ao nascer, para o caminho do aliado simples (armas_novas._mover_aliado, que também passa por mundo.mover_ponto).
func checar_aliado(id: String, simples: bool) -> void:
	var rotulo := id + (" (simples)" if simples else "")
	preparar()
	w.combate.armas.definir_golpe(id, 1, 0.0)
	w.combate.armas.ativas[id].st.quantidade = 1
	var h: Vector2 = w.heroi.pos
	var alvo = alvo_parado(h + Vector2(85.0, 0.0))
	var it = null
	for i in 600:
		passos(1)
		it = aliado_vivo()
		if it != null:
			break
	ok(it != null, "%s: nasceu" % rotulo)
	if it == null:
		return
	if simples:
		it.an = false
		it.g = false
	else:
		ok(bool(it.an) or bool(it.g), "%s: não usou o próprio andar (an/g)" % rotulo)
	w.combate.armas.ativas[id].t = 999.0
	it.p = h + Vector2(-85.0, -24.0)  # parte de um ponto fixo, 24 px acima da linha do alvo
	var c: Vector2 = ((it.p as Vector2) + alvo.pos) / 2.0 + Vector2(0.0, -MEIO.y + 6.0)  # a caixa termina 6 px abaixo da reta: o aliado desliza e dobra a quina
	caixa(c)
	it.vida = 30.0
	var pior := 999.0
	var passou := false
	for i in 60 * 6:
		passos(1)
		if float(it.vida) <= 0.0:
			break
		pior = minf(pior, folga(c, it.p, RAIO_ALIADO))
		if (it.p as Vector2).x > c.x + MEIO.x:
			passou = true
	ok(pior >= -0.05, "%s: o aliado entrou na caixa (pior folga %.2f)" % [rotulo, pior])
	ok(passou, "%s: o aliado não contornou a caixa (preso em x=%.0f, caixa em %.0f)" % [rotulo, it.p.x, c.x])


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	checar_inimigo()
	checar_puxao()
	for id in ["espirito_urso", "lobo_espirito", "golem_barro", "dragao_filhote"]:
		checar_aliado(id, false)
		checar_aliado(id, true)
	remove_child(w)
	w.free()
	print("v2_barreiras_npcs falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
