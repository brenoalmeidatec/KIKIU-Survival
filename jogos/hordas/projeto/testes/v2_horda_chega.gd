extends Node
# Teste automático: a horda CHEGA ao herói, nos três mapas (Floresta, Cidade e Laboratório). Dois casos que o jogador viu quebrados:
#  1) ABERTURA REAL (diretor ligado, herói parado): o cap de nascimento só conta quem o diretor pôs para caçar, não os 20 moradores do mapa.
#     Contando todos, o cap inicial (14) ficava abaixo dos 20 moradores e nada nascia por ~45 s: a partida abria vazia, sem ninguém vindo.
#     Aqui, em 12 s já nasceram monstros e alguns estão a menos de 300 px do herói.
#  2) EMPACAR NA QUINA: 60 caçadores nascem fora da tela e perseguem o herói parado por 30 s. A perseguição é em linha reta e a colisão só
#     empurra para fora, então numa quina côncava (duas formas encostadas) o monstro empacava para sempre; agora ele desvia (v2/monstro.gd,
#     _checar_bloqueio). Ao fim, quase nenhum ficou a mais de 100 px, e NENHUM corpo está dentro de uma forma sólida (desviar não atravessa).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_horda_chega.tscn  (imprime "v2_horda_chega falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Colisao := preload("res://v2/colisao.gd")
const PASSO := 1.0 / 60.0
const MAPAS := ["floresta", "cidade", "laboratorio"]
const N_CACADORES := 60
const MAX_PRESOS := 1  # tolerância: um corpo ainda atrás de uma quina não é falha; o bug deixava 2 a 7 para sempre
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for mapa in MAPAS:
		await _abertura(mapa)
		await _cacadores(mapa)
	print("v2_horda_chega falhas=", falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _mundo(mapa: String):
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = mapa
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.imortal = true
	return w


func _abertura(mapa: String) -> void:
	var w = _mundo(mapa)
	w.reiniciar()  # diretor ligado: é a partida de verdade
	var h: Vector2 = w.heroi.pos
	var moradores: int = w.monstros.size()
	for i in 60 * 12:
		w.avancar(PASSO)
	var perto := 0
	for m in w.monstros:
		if m.pos.distance_to(h) < 300.0:
			perto += 1
	var dir = w.combate.diretor
	ok(moradores > 14, "%s: a abertura tem mais moradores (%d) que o cap inicial, que é o caso do bug" % [mapa, moradores])
	ok(dir.nascidos >= 5, "%s: em 12 s o diretor devia ter feito nascer pelo menos 5 monstros (nasceram %d)" % [mapa, dir.nascidos])
	ok(perto >= 3, "%s: em 12 s pelo menos 3 monstros a menos de 300 px do herói (há %d)" % [mapa, perto])
	w.queue_free()
	await get_tree().process_frame


func _cacadores(mapa: String) -> void:
	var w = _mundo(mapa)
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var lista := []
	for i in N_CACADORES:
		if w.combate.diretor.nascer("inimigo_cao_ossos"):
			lista.append(w.monstros[w.monstros.size() - 1])
	ok(lista.size() == N_CACADORES, "%s: nasceram %d de %d caçadores" % [mapa, lista.size(), N_CACADORES])
	for i in 60 * 30:
		w.avancar(PASSO)
	var presos := 0
	var dentro := 0
	var h: Vector2 = w.heroi.pos
	for m in lista:
		if m.pos.distance_to(h) > 100.0:
			presos += 1
			print("  %s: preso em %s, a %.0f px do herói" % [mapa, m.pos, m.pos.distance_to(h)])
		if not Colisao.livre(m.pos, m.raio - 0.05):
			dentro += 1
	ok(presos <= MAX_PRESOS, "%s: %d de %d caçadores ficaram a mais de 100 px do herói depois de 30 s (empacaram numa quina)" % [mapa, presos, lista.size()])
	ok(dentro == 0, "%s: %d corpos dentro de uma forma sólida (o desvio atravessou parede)" % [mapa, dentro])
	w.queue_free()
	await get_tree().process_frame
