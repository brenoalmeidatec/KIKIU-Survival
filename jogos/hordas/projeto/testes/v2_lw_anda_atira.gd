extends "res://testes/isolamento_v2.gd"
## ANDAR ATIRANDO do mecha (pedido do Alisson, 05/11: "ainda falta animações enquanto anda e atira ao mesmo tempo"). Antes, andando e atirando,
## o v2/heroi.gd segurava o quadro de mira do combo (combo 0) e as pernas ficavam congeladas: o mecha deslizava. Agora a folha tem o
## `andar_tiro` (6 quadros: pernas do andar na mesma fase, braços na mira; fonte_arte/blender_herois/lightwolf_mecha/anim_andar_tiro.py) e:
##  1. andando e atirando, TODO quadro é do andar_tiro (golpe e intervalo entre rajadas juntos: nunca volta o pisca mira/andar de 04/11),
##     e as pernas percorrem o ciclo, sempre para a frente (o quadro só avança 1 na fase, nunca volta nem pula);
##  2. parado atirando continua no combo; andando sem atirar continua no andar;
##  3. o clarão de boca e a bolinha nascem no cano do quadro que a folha desenha (tabela + desvio_boca do andar_tiro), e esse desvio existe.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, mensagem: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", mensagem)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.escudo_forcado = false
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(4000, 0)
	for i in 3:
		w.avancar(PASSO)


## Anda em `entrada` (atirando ou não) por `n` quadros depois de 30 de assentar; devolve as colunas da folha quadro a quadro.
func colunas(entrada: Vector2, atira: bool, n: int) -> Array:
	zerar()
	var h = w.heroi
	h.entrada_forcada = entrada
	h.ataque_forcado = atira
	var r: Array = []
	for i in 30 + n:
		w.mouse_forcado = h.centro() + Vector2(4000, 0)
		w.avancar(PASSO)
		if i >= 30:
			r.append(h.coluna)
	h.ataque_forcado = false
	h.entrada_forcada = Vector2.ZERO
	return r


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	var h = w.heroi
	var anims: Dictionary = h.tipo.info.get("animacoes", {})
	ok(anims.has("andar_tiro"), "a folha do mecha tem o andar_tiro")
	if not anims.has("andar_tiro"):
		_fim()
		return
	var at: Array = Array(anims.andar_tiro.colunas).map(func(x): return int(x))  # o JSON traz float; h.coluna é int
	var desvio: Array = anims.andar_tiro.get("desvio_boca", [])
	ok(at.size() == (h.tipo.info.colunas as Array).size() - 1, "o andar_tiro tem um quadro por quadro do andar (a mesma fase)")
	ok(desvio.size() == at.size() and (desvio[0] as Array).size() == 8, "desvio_boca: quadro x 8 linhas x 2 braços")
	var algum := false
	for q in desvio:
		for li in q:
			for xy in li:
				algum = algum or Vector2(xy[0], xy[1]) != Vector2.ZERO
	ok(algum, "o passo sobe e desce o cano em algum quadro (o desvio medido não é todo zero)")

	# 1. andando para a direita e atirando para a direita: só andar_tiro, ciclo inteiro e sempre para a frente
	var cs := colunas(Vector2.RIGHT, true, 120)
	var fora := 0
	var vistos := {}
	var trocas := 0
	var tropecos := 0
	for i in cs.size():
		if not at.has(cs[i]):
			fora += 1
			continue
		vistos[cs[i]] = true
		if i > 0 and cs[i] != cs[i - 1] and at.has(cs[i - 1]):
			trocas += 1
			if at.find(cs[i]) != (at.find(cs[i - 1]) + 1) % at.size():
				tropecos += 1
	print("andando e atirando: %d quadros fora do andar_tiro, %d quadros distintos, %d trocas, %d tropeços" % [fora, vistos.size(), trocas, tropecos])
	ok(fora == 0, "andando e atirando, todo quadro é do andar_tiro (%d fora: pisca de mira/andar ou pernas paradas)" % fora)
	ok(vistos.size() == at.size(), "andando e atirando, as pernas percorrem o ciclo inteiro (%d de %d quadros)" % [vistos.size(), at.size()])
	ok(trocas >= 6 and trocas <= 20, "andando e atirando, o passo troca no ritmo do andar (%d trocas em 2 s)" % trocas)
	ok(tropecos == 0, "o ciclo só avança um quadro por vez (%d tropeços)" % tropecos)

	# 2. controles: parado atirando = combo; andando sem atirar = andar
	var combo: Array = Array(anims.combo.colunas).map(func(x): return int(x))
	var parado := colunas(Vector2.ZERO, true, 60)
	var no_combo := 0
	for c in parado:
		no_combo += 1 if combo.has(c) else 0
	ok(no_combo == parado.size(), "parado atirando continua no combo (%d de %d)" % [no_combo, parado.size()])
	var anda := colunas(Vector2.RIGHT, false, 60)
	var no_andar := 0
	for c in anda:
		no_andar += 1 if c >= 1 and c <= 6 else 0
	ok(no_andar == anda.size(), "andando sem atirar continua no andar (%d de %d)" % [no_andar, anda.size()])

	# 3. desvio_boca segue o quadro desenhado
	h.quadro(int(at[0]), 1)
	var esperado := Vector2(float(desvio[0][1][1][0]), float(desvio[0][1][1][1]))
	ok(h.desvio_boca(1) == esperado, "desvio_boca lê o quadro e a linha que a folha desenha (%s, esperado %s)" % [h.desvio_boca(1), esperado])
	h.quadro(int(combo[0]), 1)
	ok(h.desvio_boca(1) == Vector2.ZERO, "fora do andar_tiro o desvio é zero (a tabela do combo vale como era)")
	_fim()


func _fim() -> void:
	Herois.forcado = ""
	w.queue_free()
	await get_tree().process_frame
	print("v2_lw_anda_atira falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)
