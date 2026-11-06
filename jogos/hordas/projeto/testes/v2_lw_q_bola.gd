extends "res://testes/isolamento_v2.gd"
# Teste do RITMO da bola da explosão do Q do LightWolf (rodada 6, pedido do Alisson: "a animação está ótima no quadro a quadro mas no real time parece muito rápida"
# e a "fervura" da bola, que com Reduzir piscadas dava 3,5 Hz numa janela local de 16x16 px, limite 2 Hz). Medida numérica, sem vídeo: toca a bola de verdade no mundo
# (`w.avancar` em passos de 1/60 s de RELÓGIO = 1,25/60 s do mundo, porque o jogo roda a 1,25x), pega o quadro que ficou na tela em cada passo e mede
#  1. quanto a bola dura em segundos de relógio (normal e com Reduzir piscadas): de 2,0 a 2,6 vezes os 0,533 s de antes (10 quadros a 15 por s do mundo);
#  2. a piscada local: a luminância média de cada janela de 16x16 px (de 8 em 8 px; o que é transparente conta como chão médio) e, em cada janela, o menor período entre
#     dois picos de subida (um ciclo claro-escuro-claro com amplitude de pelo menos 20 de 255); o maior número de ciclos por segundo tem de ficar em 2 Hz ou menos;
#  3. o padrão interno: a bola só troca de padrão (`FASE_QUADROS` quadros seguidos com as mesmas cores) a cada 0,25 s de relógio ou mais.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_lw_q_bola.tscn  (imprime "v2_lw_q_bola falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Ex := preload("res://v2/explosao_mecha.gd")
const PASSO_REAL := 1.0 / 60.0
const VELOCIDADE := 1.25  # combate.velocidade da partida: o relógio anda 1,25x mais devagar que o mundo
const BOLA_ANTES := 0.5333  # s de relógio da bola antes da rodada 6 (10 quadros / 15 fps / 1,25)
const JANELA := 16
const CHAO := 70.0  # luminância (0 a 255) que o transparente conta: um chão médio

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func novo() -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	for i in 3:
		w.avancar(1.0 / 60.0)
	w.cam.cravar(w.heroi.centro())


func _ready() -> void:
	Config.temporario("reduzir_piscadas", false)
	Config.g_temporario("tremor_clarao", 100)
	Config.g_temporario("particulas_sim", "muitas")
	await _medir(false)
	await _medir(true)
	Config.temporario("reduzir_piscadas", false)
	Herois.forcado = ""
	print("v2_lw_q_bola falhas=%d" % falhas)
	get_tree().quit()


## Toca a bola e devolve {dur, hz, janela, troca} (s de relógio da bola, ciclos por segundo do pior janela de 16x16, onde ela fica, o menor intervalo entre trocas de padrão).
func _medir(reduzir: bool) -> void:
	Config.temporario("reduzir_piscadas", reduzir)
	await novo()
	var h = w.heroi
	var esp = w.combate.especial
	h.esp_carga = h.esp_carga_max
	h.especial()
	for f in 240:
		w.avancar(1.0 / 60.0)
		if esp.explosoes > 0:
			break
	var v = esp.get("explosao_visual")
	Config.temporario("reduzir_piscadas", false)
	ok(v != null and v.viva(), "a bola está viva depois do estouro")
	if v == null:
		return
	var nome := "Reduzir piscadas" if reduzir else "normal"
	# a luminância de cada janela, por quadro da bola (uma vez)
	var lado: int = v.bola[0].get_width()
	var n_j := (lado - JANELA) / 8 + 1
	var lum: Array = []  # [quadro] -> PackedFloat32Array(n_j * n_j)
	var imgs: Array = []
	for k in v.bola.size():
		var im: Image = v.bola[k].get_image()
		imgs.append(im)
		lum.append(_janelas(im, n_j))
	# toca no relógio: um passo = 1/60 s de relógio = 1,25/60 s do mundo
	var serie: Array = []  # o quadro da bola em cada passo
	var vistos: Array = []
	var f := 0
	while v.quadro_bola() >= 0 and f < 600:
		var k: int = v.quadro_bola()
		serie.append(k)
		if vistos.is_empty() or vistos[vistos.size() - 1] != k:
			vistos.append(k)
		w.avancar(PASSO_REAL * VELOCIDADE)
		f += 1
	var dur := float(serie.size()) * PASSO_REAL
	var hit: float = float(w.combate.especial.bloco_de("lightwolf").explosao.hit_stop) / VELOCIDADE
	var dur_sem_hit := dur - hit
	print("bola %s: %d quadros distintos, %.3f s de relógio (%.3f sem o hit-stop de %.2f s)" % [nome, vistos.size(), dur, dur_sem_hit, hit])
	ok(
		dur_sem_hit >= BOLA_ANTES * 2.0 - 0.02 and dur_sem_hit <= BOLA_ANTES * 2.6,
		"%s: a bola dura de 2,0 a 2,6 vezes os %.2f s de antes (%.2f s)" % [nome, BOLA_ANTES, dur_sem_hit]
	)
	# a piscada local de cada janela
	var pior_hz := 0.0
	var pior_j := -1
	for j in n_j * n_j:
		var s := PackedFloat32Array()
		for k in serie:
			s.append(lum[k][j])
		var hz := _ciclos_por_s(s)
		if hz > pior_hz:
			pior_hz = hz
			pior_j = j
	var onde := Vector2i((pior_j % n_j) * 8, (pior_j / n_j) * 8) if pior_j >= 0 else Vector2i(-1, -1)
	print("bola %s: pior janela de %dx%d px em %s, %.2f ciclos por s" % [nome, JANELA, JANELA, str(onde), pior_hz])
	ok(pior_hz <= 2.0, "%s: nenhuma janela de %dx%d px pisca acima de 2 Hz (%.2f Hz em %s)" % [nome, JANELA, JANELA, pior_hz, str(onde)])
	# o padrão interno: quantos quadros seguidos o miolo fica com as mesmas cores
	var menor := 1 << 30
	var ant_troca := -1
	for i in range(1, vistos.size()):
		if _trocou_padrao(imgs[vistos[i - 1]], imgs[vistos[i]]):
			if ant_troca >= 0:
				menor = mini(menor, i - ant_troca)
			ant_troca = i
	var seg: float = float(menor) / float(Ex.BOLA_FPS) / VELOCIDADE
	print("bola %s: o padrão interno troca no mínimo a cada %d quadros (%.3f s de relógio)" % [nome, menor, seg])
	ok(menor == (1 << 30) or seg >= 0.25 - 0.0001, "%s: o padrão interno troca no máximo a cada 0,25 s de relógio (%.3f s)" % [nome, seg])


## A luminância média (0 a 255) de cada janela de JANELA x JANELA px (passo de 8); o transparente conta CHAO.
func _janelas(im: Image, n_j: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n_j * n_j)
	for jy in n_j:
		for jx in n_j:
			var soma := 0.0
			for y in JANELA:
				for x in JANELA:
					var c := im.get_pixel(jx * 8 + x, jy * 8 + y)
					soma += (255.0 * (0.299 * c.r + 0.587 * c.g + 0.114 * c.b)) if c.a > 0.5 else CHAO
			out[jy * n_j + jx] = soma / float(JANELA * JANELA)
	return out


## O maior número de ciclos claro-escuro-claro por segundo de relógio: o inverso do menor intervalo entre dois picos de subida seguidos (amplitude >= 20).
func _ciclos_por_s(s: PackedFloat32Array) -> float:
	var histerese := 20.0
	var dir := 0  # 1 subindo, -1 descendo
	var ref := s[0]
	var picos: Array = []  # os passos em que a luminância passa a subir (fundo de um vale)
	for i in range(1, s.size()):
		var x := s[i]
		if dir >= 0:
			if x > ref:
				ref = x
				dir = 1
			elif ref - x >= histerese:
				dir = -1
				ref = x
		if dir <= 0:
			if x < ref:
				ref = x
				dir = -1
			elif x - ref >= histerese:
				if dir == -1:
					picos.append(i)
				dir = 1
				ref = x
	var menor := 1e9
	for i in range(1, picos.size()):
		menor = minf(menor, float(picos[i] - picos[i - 1]) * PASSO_REAL)
	return 1.0 / menor if menor < 1e9 else 0.0


## Mais de 8% dos pixels do MIOLO (disco de 18 px em volta do centro) que estão opacos nos dois quadros mudaram de cor? Fora do miolo ficam os raios do estalo e a borda
## que cresce (pixel que vira corpo da bola), que são a silhueta e não o padrão. A fumaça sobe em px inteiros (a bola inteira anda junto, sem trocar de cor), então vale o
## melhor deslocamento vertical de 0 a 4 px. O miolo que abre e o esfarelar não contam: pixel novo ou que sumiu não entra.
func _trocou_padrao(a: Image, b: Image) -> bool:
	var c := a.get_width() / 2
	var melhor := 1.0
	var viu := false
	for desl in 5:
		var comuns := 0
		var mudou := 0
		for y in range(maxi(c - 18, desl), c + 19):
			for x in range(c - 18, c + 19):
				if (x - c) * (x - c) + (y - c) * (y - c) > 18 * 18:
					continue
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y - desl)
				if ca.a > 0.5 and cb.a > 0.5:
					comuns += 1
					if not ca.is_equal_approx(cb):
						mudou += 1
		if comuns >= 40:
			viu = true
			melhor = minf(melhor, float(mudou) / float(comuns))
	return viu and melhor > 0.08
