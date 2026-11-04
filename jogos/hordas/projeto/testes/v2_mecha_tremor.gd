extends "res://testes/isolamento_v2.gd"
## O "mecha tremendo todo" (pedido do Alisson, 04/11): mede quadro a quadro, como o jogador vê, a posição do corpo NA TELA (raiz + sprite -
## câmera), a pose (coluna da folha) e o passo do herói no mundo, andando e atirando. Três defeitos travados:
##  1. câmera e herói arredondados cada um no seu meio pixel: andando a 90 px/s o herói dava passos 2,1,2,1 e a câmera 1,2,1,2, e o corpo
##     vibrava 1 px na tela a cada quadro (v2/camera_mundo.gd: o `resto` do herói). Vale para todo herói (o Hazaki também é medido);
##  2. andar atirando metia 1 quadro do andar entre duas rajadas (10 trocas de pose por segundo; v2/heroi.gd, _coluna_acao);
##  3. o quadro em que o tiro sai não andava: o mecha engasgava 1 quadro por rajada (v2/heroi.gd, _livre).
## E o controle: com a câmera presa na borda do mapa, o meio pixel do herói não entra (a câmera não pode tremer parada).
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const ASSENTAR := 60  # quadros para a câmera alcançar o passo do herói antes de medir
const MEDIR := 60
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


## A pose pela coluna da folha do mecha: P (parado), A (andar), C (tiro, combo); outra folha: a própria coluna.
func pose(h) -> String:
	if not bool(h.tipo.info.get("corpo_fixo_ao_atirar", false)):
		return str(h.coluna)
	var c: int = h.coluna
	if c >= 1 and c <= 6:
		return "A"
	return "C" if c >= 16 and c <= 27 else "P"


## Anda (e atira) `ASSENTAR + MEDIR` quadros e devolve, nos últimos MEDIR: as voltas do corpo na tela (o sinal do passo na tela que muda),
## a faixa (max - min) do x na tela, as trocas de pose, o menor passo do herói no mundo e se o tiro saiu.
func medir(entrada: Vector2, atira: bool) -> Dictionary:
	zerar()
	var h = w.heroi
	h.entrada_forcada = entrada
	h.ataque_forcado = atira
	var r := {"voltas": 0, "faixa": 0.0, "trocas_pose": 0, "passo_min": INF, "tiros": 0}
	var ant_tela := Vector2.INF
	var ant_mundo := 0.0
	var ult := 0.0
	var ult_pose := ""
	var x_min := INF
	var x_max := -INF
	for i in ASSENTAR + MEDIR:
		w.avancar(PASSO)
		var mundo_p: Vector2 = h.raiz.position + h.sprite.position
		var tela: Vector2 = mundo_p - w.cam.position
		var ps := pose(h)
		if i >= ASSENTAR:
			if h.estado == Heroi.Estado.GOLPE:
				r.tiros += 1
			x_min = minf(x_min, tela.x)
			x_max = maxf(x_max, tela.x)
			var d := tela.x - ant_tela.x
			if d != 0.0:
				if ult != 0.0 and signf(d) != signf(ult):
					r.voltas += 1
				ult = d
			if ps != ult_pose:
				r.trocas_pose += 1
			r.passo_min = minf(r.passo_min, mundo_p.x - ant_mundo)
		ant_tela = tela
		ant_mundo = mundo_p.x
		ult_pose = ps
	r.faixa = x_max - x_min
	return r


func checar_heroi(quem: String) -> void:
	Herois.forcado = quem
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var anda := medir(Vector2.RIGHT, false)
	print("[%s] andando: voltas na tela=%d faixa=%.0f px, menor passo=%.0f" % [quem, anda.voltas, anda.faixa, anda.passo_min])
	ok(anda.passo_min > 0.0, "%s: o herói andou para a direita o trecho todo" % quem)
	ok(anda.voltas == 0 and anda.faixa <= 1.0, "%s andando: o corpo não vibra na tela (voltas=%d, faixa=%.0f px)" % [quem, anda.voltas, anda.faixa])
	if quem == "lightwolf":
		var at := medir(Vector2.RIGHT, true)
		print(
			(
				"[%s] andando e atirando: voltas=%d faixa=%.0f trocas de pose=%d menor passo=%.0f tiros=%d"
				% [quem, at.voltas, at.faixa, at.trocas_pose, at.passo_min, at.tiros]
			)
		)
		ok(at.tiros > 30, "o mecha atirou no trecho medido (%d quadros de tiro)" % at.tiros)
		ok(at.trocas_pose == 0, "andando e atirando, o mecha não pisca o quadro do andar entre as rajadas (%d trocas de pose)" % at.trocas_pose)
		ok(at.passo_min >= 1.0, "andando e atirando, o mecha não engasga no quadro do tiro (menor passo %.0f px)" % at.passo_min)
		ok(at.voltas == 0 and at.faixa <= 1.0, "andando e atirando, o corpo não vibra na tela (voltas=%d, faixa=%.0f px)" % [at.voltas, at.faixa])
		var parado := medir(Vector2.ZERO, true)
		ok(parado.voltas == 0 and parado.faixa == 0.0, "parado atirando, o corpo fica no mesmo pixel da tela (faixa=%.0f px)" % parado.faixa)
		# controle: perto da borda esquerda a câmera fica presa e não pode tremer com o meio pixel do herói
		zerar()
		var h = w.heroi
		h.definir_pos(Vector2(w.limite_andavel.position.x + 40.0, h.pos.y))
		w.cam.cravar(h.pos + Heroi.CENTRO_CORPO)
		h.entrada_forcada = Vector2.RIGHT
		var cams := {}
		var andou: float = h.pos.x
		for i in 60:
			w.avancar(PASSO)
			cams[w.cam.position.x] = true
		ok(h.pos.x - andou > 60.0, "o herói andou perto da borda (%.0f px)" % (h.pos.x - andou))
		ok(cams.size() == 1, "presa na borda, a câmera não treme com o meio pixel do herói (%d posições)" % cams.size())
	Herois.forcado = ""
	w.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	await checar_heroi("lightwolf")
	await checar_heroi("hazaki")
	print("v2_mecha_tremor falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)
