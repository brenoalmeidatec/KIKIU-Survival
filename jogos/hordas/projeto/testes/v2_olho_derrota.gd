extends "res://testes/isolamento_v2.gd"
# Teste do olho que se fecha na derrota (#446, UI-4): a curva das pálpebras (uma só, suave, sem piscada, de 0 a 1 em 1,2 s), a versão certa
# por perfil (Alto completa; Médio e Baixo simples) e por "Tremor e clarões", e o fluxo real: o herói morre, o olho fecha dentro da câmera
# lenta da morte (sem atrasar a tela de resultado), termina em preto sem reabrir, a tela de derrota abre e aceita Enter, e jogar de novo desfaz o olho.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_olho_derrota.tscn  (imprime "v2_olho_derrota falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Olho := preload("res://v2/olho_derrota.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.correr_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	passos(3)


## Mata o herói e anda até a tela de resultado abrir. Devolve {passos, max_fecha, antes_aberto, simples, reabriu} (passos = quadros de 1/60 s).
func morrer() -> Dictionary:
	var h = w.heroi
	h.imortal = false
	h.vida = 1.0
	var m = w.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(14, 0))
	m.atordoa_t = 0.0
	m.cacador = true
	var n := 0
	var max_fecha := 0.0
	var aberto_no_comeco := true
	var simples := false
	var anterior := 0.0
	var reabriu := false
	while not w.combate.telas.resultado_aberto and n < 600:
		w.avancar(PASSO)
		n += 1
		if w.olho.fecha < anterior - 0.0001:
			reabriu = true  # o olho nunca pode voltar a abrir no caminho até o preto
		anterior = w.olho.fecha
		if w.combate.jogo == "morrendo":
			simples = w.olho.simples
			max_fecha = maxf(max_fecha, w.olho.fecha)
			if w.combate.lento_t > Olho.DURACAO and w.olho.fecha > 0.0:
				aberto_no_comeco = false
	return {"passos": n, "max_fecha": max_fecha, "antes_aberto": aberto_no_comeco, "simples": simples, "reabriu": reabriu}


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true

	# 1. a curva das pálpebras: uma só, suave, sem piscada, 1,2 s
	var d := Olho.DURACAO
	ok(is_equal_approx(d, 1.2), "o olho dura 1,2 s (era %.1f s)" % d)
	ok(is_equal_approx(Olho.curva(0.0), 0.0), "curva: começa aberta")
	ok(is_equal_approx(Olho.curva(d), 1.0), "curva: termina fechada em %.1f s" % d)
	ok(is_equal_approx(Olho.curva(d + 5.0), 1.0), "curva: depois do fim segue fechada")
	ok(Olho.curva(0.72) < 0.7, "não fecha mais em 0,72 s como a completa antiga: %.2f" % Olho.curva(0.72))
	ok(is_equal_approx(Olho.curva(d * 0.5), 0.5), "meio caminho na metade do tempo: %.2f" % Olho.curva(d * 0.5))
	var ant := 0.0
	var sobe := true
	for i in 241:
		var v := Olho.curva(d * i / 240.0)
		sobe = sobe and v >= ant - 0.0001
		ant = v
	ok(sobe, "sem piscada: a curva só fecha, nunca reabre (amostrada de 1/240 do olho)")

	# 2. a versão certa por perfil e por "Tremor e clarões"
	Config.g_perfil_temporario("baixo")
	ok(Olho.versao_simples(), "perfil Baixo: versão simples")
	Config.g_perfil_temporario("medio")
	ok(Olho.versao_simples(), "perfil Médio: versão simples (o mipmap da tela pesa no Iris Xe)")
	Config.g_perfil_temporario("alto")
	ok(not Olho.versao_simples(), "perfil Alto: versão completa")
	Config.g_definir("tremor_clarao", 0)
	ok(Olho.versao_simples(), "Tremor e clarões em 0%%: versão simples (sem desfoque)")
	Config.g_perfil_temporario("alto")

	# 3. o fluxo real, versão completa (Alto)
	zerar()
	ok(not w.olho.visible and w.olho.fecha == 0.0, "o olho começa aberto e escondido")
	var r := morrer()
	var esperado: int = int(ceil(maxf(1.3, w.heroi.duracao_morte() + 0.25) / PASSO)) + 20  # a câmera lenta já existente, com folga
	ok(w.combate.jogo == "morte" and w.combate.pausado and w.combate.telas.resultado_aberto, "a tela de derrota abre depois do olho")
	ok(not r.simples, "Alto: o olho desta partida é o completo")
	ok(not r.reabriu, "o olho fecha sem piscar: nunca reabre no caminho até o preto")
	ok(r.antes_aberto, "o olho não mexe na tela antes dos últimos %.1f s" % Olho.DURACAO)
	ok(r.max_fecha > 0.95, "o olho chegou ao preto antes do resultado (%.2f)" % r.max_fecha)
	ok(w.olho.fecha >= 0.999 and w.olho.visible, "com o resultado aberto o olho está fechado (preto por trás)")
	ok(r.passos <= esperado, "o olho não atrasa a derrota: %d quadros (limite %d)" % [r.passos, esperado])
	ok(r.passos * PASSO <= 1.6 + w.heroi.duracao_morte(), "a espera até o resultado fica perto da câmera lenta que já existia (%.2f s)" % (r.passos * PASSO))
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	passos(60)
	w._input(enter)
	ok(not w.combate.telas.resultado_aberto and w.combate.jogo == "jogando" and not w.combate.pausado, "a tela de derrota aceita Enter depois do olho")
	ok(not w.olho.visible and w.olho.fecha == 0.0, "jogar de novo abre o olho de volta")

	# 4. o fluxo real, versão simples (Médio e Baixo)
	for perfil in ["medio", "baixo"]:
		Config.g_perfil_temporario(perfil)
		zerar()
		r = morrer()
		ok(r.simples, "%s: o olho desta partida é o simples" % perfil)
		ok(not r.reabriu, "%s: o olho não pisca" % perfil)
		ok(r.max_fecha > 0.95 and w.combate.telas.resultado_aberto, "%s: fecha em preto e abre a derrota" % perfil)
		ok(r.passos <= esperado, "%s: não atrasa a derrota (%d quadros)" % [perfil, r.passos])
		w._input(enter)
		passos(60)
		w._input(enter)
		ok(not w.combate.telas.resultado_aberto, "%s: a tela de derrota também aceita Enter" % perfil)

	# 5. a partida seguinte não herda o olho nem repete nó
	zerar()
	var nos := get_tree().get_node_count()
	r = morrer()
	passos(30)
	ok(get_tree().get_node_count() <= nos + 12, "mais uma morte não acumula nó (%d -> %d)" % [nos, get_tree().get_node_count()])

	Config.g_soltar_temporario()
	print("v2_olho_derrota falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)
