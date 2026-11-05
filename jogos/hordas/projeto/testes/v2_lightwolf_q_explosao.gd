extends "res://testes/isolamento_v2.gd"
# Teste da explosão do Q do mecha (a Autodestruição do LightWolf, pedido do Alisson de 05/11: "explosão bem maior, tremer um pouco a tela, sensação de impacto,
# cratera por alguns s"). Só o DESENHO e o peso: v2/explosao_mecha.gd (bola, onda no chão, cratera) chamada por v2/especial.gd `_explodir_mecha`, números em
# dados/v2_especial.json > autodestruicao > explosao. Confere: os dados; os quadros na grade de 1 px (alfa só 0 ou 1, tamanho inteiro); a bola na camada glow e a
# cratera no nó do mundo embaixo dos atores (z < 0); o estouro (bola no 1º quadro, tremor de câmera, hit-stop dos dados); a onda no chão na velocidade da limpeza
# até cobrir a câmera; a cratera que fica `cratera.dur` s e esfarela sem piscar (quadro só avança, cada esfarelar tira pixels e nenhum volta); "Reduzir piscadas"
# (a bola começa sem o miolo branco); "Tremor e clarões" em 0 (a câmera não treme); e o perfil Baixo (a bola, a onda e a cratera ficam).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_lightwolf_q_explosao.tscn  (imprime "v2_lightwolf_q_explosao falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Anim := preload("res://v2/anim_golpes.gd")
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
	passos(3)
	w.cam.cravar(w.heroi.centro())


## Aperta o Q e anda até o quadro da explosão. Devolve o visual da explosão (null se o especial não tem).
func explodir():
	var h = w.heroi
	var esp = w.combate.especial
	h.esp_carga = h.esp_carga_max
	ok(h.especial(), "o Q dispara")
	for f in 120:
		w.avancar(PASSO)
		if esp.explosoes > 0:
			break
	ok(esp.explosoes == 1, "o mecha explodiu")
	return esp.get("explosao_visual")


func _ready() -> void:
	Config.temporario("reduzir_piscadas", false)
	Config.g_temporario("tremor_clarao", 100)
	Config.g_temporario("particulas_sim", "muitas")
	await _t_normal()
	await _t_piscadas()
	await _t_sem_tremor()
	await _t_baixo()
	Config.temporario("reduzir_piscadas", false)
	Config.g_temporario("tremor_clarao", 100)
	Config.g_temporario("particulas_sim", "muitas")
	Herois.forcado = ""
	print("v2_lightwolf_q_explosao falhas=%d" % falhas)
	get_tree().quit()


## Alfa só 0 ou 1 em todos os pixels; devolve quantos pixels opacos.
func _opacos(tex: Texture2D, nome: String) -> int:
	var im := tex.get_image()
	var n := 0
	var meio := 0
	for y in im.get_height():
		for x in im.get_width():
			var a := im.get_pixel(x, y).a
			if a > 0.999:
				n += 1
			elif a > 0.001:
				meio += 1
	ok(meio == 0, "%s: alfa só 0 ou 1 (%d pixels no meio)" % [nome, meio])
	return n


func _t_normal() -> void:
	await novo()
	var c = w.combate
	var e: Dictionary = c.especial.bloco_de("lightwolf").explosao
	ok(int(e.get("bola", 0)) >= 80, "a bola de fogo tem raio de pelo menos 80 px (%s)" % str(e.get("bola")))
	ok(e.has("cratera") and float(e.cratera.get("dur", 0.0)) >= 3.0, "a cratera fica alguns segundos (dados)")
	ok(float(e.hit_stop) >= 0.1, "hit-stop de pelo menos 0,1 s no estouro (%.2f)" % float(e.hit_stop))
	var v = explodir()
	ok(v != null, "o especial tem o visual da explosão do mecha (explosao_visual)")
	if v == null:
		return
	# os quadros: grade de 1 px
	for k in v.bola.size():
		_opacos(v.bola[k], "bola %d" % k)
	var ant := 1 << 30
	for k in v.cratera.size():
		var n := _opacos(v.cratera[k], "cratera %d" % k)
		if k >= 2:
			ok(n < ant, "cratera esfarelando: o quadro %d tem menos pixels que o anterior (%d < %d)" % [k, n, ant])
		ant = n
	ok(v.bola[0].get_width() == int(e.bola) * 2 + 1, "a bola tem 2 x raio + 1 px de lado (%d)" % v.bola[0].get_width())
	# o esfarelar nunca devolve um pixel que já sumiu
	var volta := 0
	for k in range(2, v.cratera.size()):
		var a: Image = v.cratera[k - 1].get_image()
		var b: Image = v.cratera[k].get_image()
		for y in a.get_height():
			for x in a.get_width():
				if a.get_pixel(x, y).a < 0.5 and b.get_pixel(x, y).a > 0.5:
					volta += 1
	ok(volta == 0, "nenhum pixel da cratera reaparece ao esfarelar (%d)" % volta)
	# as camadas
	ok(v.no_bola != null and v.no_bola.get_parent() == w.glow, "a bola é desenhada na camada glow (por cima dos atores)")
	ok(v.no_chao != null and v.no_chao.get_parent() == w.no_mundo and v.no_chao.z_index < 0, "a cratera é desenhada no chão, embaixo dos atores")
	ok(v.centro == v.centro.round(), "posição inteira")
	# o estouro
	ok(v.quadro_bola() == 0, "a bola começa no 1º quadro (o miolo branco) (%d)" % v.quadro_bola())
	ok(is_equal_approx(c.ultimo_hit_stop, float(e.hit_stop)), "o hit-stop do estouro é o dos dados (%.2f)" % c.ultimo_hit_stop)
	ok(w.cam.tremor_t > 0.0 and w.cam.tremor_amp >= float(e.tremor) - 0.01, "a câmera treme (%.1f px)" % w.cam.tremor_amp)
	ok(float(e.tremor) <= 5.0 and w.cam.tremor_dur <= 0.4, "o tremor é leve e curto (%.1f px, %.2f s)" % [float(e.tremor), w.cam.tremor_dur])
	# a onda no chão: na velocidade da limpeza, até cobrir a câmera
	var vel := float(c.especial.comum.limpa.vel)
	ok(is_equal_approx(v.vel_onda, vel), "a onda no chão anda na velocidade da frente de onda da limpeza (%.0f)" % v.vel_onda)
	var rect: Rect2 = w.cam.retangulo(float(c.especial.comum.limpa.margem))
	ok(v.onda_max >= rect.size.x * 0.5 - 1.0, "a onda vai até a borda da câmera (%.0f px)" % v.onda_max)
	# a cratera: fica, esfarela e some, sem piscar
	var t0: float = v.t
	var q_ant := -1
	var recuou := 0
	var trocas := 0
	var visto_esfarelar := false
	var dur := float(e.cratera.dur)
	var f := 0
	while v.cratera_viva() and f < 600:
		var q: int = v.quadro_cratera()
		if q < q_ant:
			recuou += 1
		if q != q_ant:
			trocas += 1
		if q >= 2:
			visto_esfarelar = true
		q_ant = q
		w.avancar(PASSO)
		f += 1
	var vida_s: float = float(f) * PASSO + t0
	ok(recuou == 0, "o quadro da cratera só avança (nada pisca)")
	ok(visto_esfarelar, "a cratera esfarela antes de sumir")
	ok(absf(vida_s - dur) < 0.25, "a cratera fica %.1f s (%.2f)" % [dur, vida_s])
	ok(trocas <= 2 + 4, "a cratera troca de quadro poucas vezes (%d)" % trocas)
	ok(not v.viva() or v.quadro_bola() < 0, "a bola já acabou quando a cratera some")


func _t_piscadas() -> void:
	Config.temporario("reduzir_piscadas", true)
	await novo()
	var v = explodir()
	Config.temporario("reduzir_piscadas", false)
	if v == null:
		ok(false, "sem o visual da explosão")
		return
	var k: int = v.quadro_bola()
	ok(k >= 2, "com Reduzir piscadas a bola começa sem o miolo branco (quadro %d)" % k)
	var minimo := k
	for f in 60:
		w.avancar(PASSO)
		var q: int = v.quadro_bola()
		if q >= 0:
			minimo = mini(minimo, q)
	ok(minimo >= 2, "e nunca mostra os quadros brancos (%d)" % minimo)


func _t_sem_tremor() -> void:
	Config.g_temporario("tremor_clarao", 0)
	await novo()
	explodir()
	ok(w.cam.tremor_t <= 0.0 or w.cam.tremor_amp <= 0.0, "Tremor e clarões em 0%: a câmera não treme")
	Config.g_temporario("tremor_clarao", 100)


func _t_baixo() -> void:
	Config.g_temporario("particulas_sim", "poucas")
	await novo()
	var v = explodir()
	if v == null:
		ok(false, "sem o visual da explosão")
	else:
		ok(v.quadro_bola() >= 0 and v.cratera_viva() and v.raio_onda() >= 0.0, "perfil Baixo: a bola, a onda e a cratera ficam (o essencial)")
	Config.g_temporario("particulas_sim", "muitas")
