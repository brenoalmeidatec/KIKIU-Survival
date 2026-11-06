extends "res://testes/isolamento_v2.gd"
## STRAFE (pedido do Alisson, 05/11: "Faça animação do strafe (andar de lado) que não parece existir. Vale para todos os personagens").
## Antes, andando de lado com a mira no mouse, o v2/heroi.gd tocava o andar DE FRENTE da linha da mira e o herói deslizava. Agora cada
## folha tem o `strafe` (6 quadros de passo-junta, fonte_arte/blender_herois/*/anim_strafe.py) e o mecha também o `strafe_tiro`:
##  1. mira para a direita e andando para baixo ou para cima (perpendicular), todo quadro é do strafe, em todos os heróis;
##  2. os dois lados tocam o ciclo em sentidos opostos (um avança, o outro recua um quadro por vez: o passo-junta ao contrário);
##  3. a 30 graus da mira continua o andar de frente;
##  4. histerese: perto do limiar (|cos| 0,55) o andar não vira strafe e o strafe não vira andar; longe dele (0,7) volta ao andar;
##  5. o mecha andando de lado e atirando toca o strafe_tiro, e o desvio_boca lê a tabela do strafe_tiro.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const HEROIS := ["hazaki", "matheus", "joao", "beto", "lukako", "fabio", "lucas", "nicao", "lightwolf", "lightwolf_lobo"]
var falhas := 0
var w
var lobo := false  # o reiniciar volta o LightWolf ao mecha: com isto o zerar chama o Lobo de novo


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
	if lobo:
		w.combate.mecha.virar_lobo(w.heroi, 0.0)
		w.heroi.invenc = 0.0
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(4000, 0)
	for i in 3:
		w.avancar(PASSO)


## Anda em `entrada` por `n` quadros (sem zerar), com a mira no mouse à direita (o mouse "mexe" todo quadro, como o jogador mirando).
## Devolve as colunas da folha, quadro a quadro.
func rodar(entrada: Vector2, atira: bool, n: int) -> Array:
	var h = w.heroi
	h.entrada_forcada = entrada
	h.ataque_forcado = atira
	var r: Array = []
	for i in n:
		w.mouse_forcado = h.centro() + Vector2(4000, 0)
		h.fonte = Heroi.Fonte.MOUSE
		w.avancar(PASSO)
		r.append(h.coluna)
	return r


## Depois de 30 quadros de assentar, `n` quadros andando em `entrada`.
func colunas(entrada: Vector2, atira: bool, n: int) -> Array:
	zerar()
	rodar(entrada, atira, 30)
	var r := rodar(entrada, atira, n)
	w.heroi.ataque_forcado = false
	w.heroi.entrada_forcada = Vector2.ZERO
	return r


func ints(a: Array) -> Array:
	return a.map(func(x): return int(x))  # o JSON traz float; h.coluna é int


## Quantos quadros fora de `cols`, quantos distintos, e as trocas que avançam (+1) e recuam (-1) um quadro no ciclo; `outras` = saltos.
func ciclo(cs: Array, cols: Array) -> Dictionary:
	var r := {"fora": 0, "vistos": {}, "avanca": 0, "recua": 0, "outras": 0}
	for i in cs.size():
		if not cols.has(cs[i]):
			r.fora += 1
			continue
		r.vistos[cs[i]] = true
		if i == 0 or cs[i] == cs[i - 1] or not cols.has(cs[i - 1]):
			continue
		var de: int = cols.find(cs[i - 1])
		var para: int = cols.find(cs[i])
		if para == (de + 1) % cols.size():
			r.avanca += 1
		elif para == posmod(de - 1, cols.size()):
			r.recua += 1
		else:
			r.outras += 1
	return r


func dir_cos(c: float, para_baixo := true) -> Vector2:
	return Vector2(c, sqrt(1.0 - c * c) * (1.0 if para_baixo else -1.0))


func testar(id: String) -> void:
	Herois.forcado = "lightwolf" if id == "lightwolf_lobo" else id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	lobo = id == "lightwolf_lobo"
	zerar()
	ok(not lobo or w.heroi.forma_lobo, "virou o Lobo")
	var h = w.heroi
	var anims: Dictionary = h.tipo.info.get("animacoes", {})
	ok(anims.has("strafe"), "%s: a folha tem o strafe" % id)
	if not anims.has("strafe"):
		await _soltar()
		return
	var st := ints(anims.strafe.colunas)
	var andar := range(1, 7)
	ok(st.size() == 6, "%s: o strafe tem 6 quadros (%d)" % [id, st.size()])

	# 1 e 2. perpendicular à mira, os dois lados
	var baixo := ciclo(colunas(Vector2.DOWN, false, 120), st)
	var cima := ciclo(colunas(Vector2.UP, false, 120), st)
	print(
		(
			"%s: baixo fora=%d vistos=%d avanca=%d recua=%d outras=%d | cima fora=%d vistos=%d avanca=%d recua=%d outras=%d"
			% [
				id,
				baixo.fora,
				baixo.vistos.size(),
				baixo.avanca,
				baixo.recua,
				baixo.outras,
				cima.fora,
				cima.vistos.size(),
				cima.avanca,
				cima.recua,
				cima.outras
			]
		)
	)
	ok(baixo.fora == 0 and cima.fora == 0, "%s: de lado, todo quadro é do strafe (fora: %d baixo, %d cima)" % [id, baixo.fora, cima.fora])
	ok(baixo.vistos.size() == st.size() and cima.vistos.size() == st.size(), "%s: de lado, o ciclo inteiro toca" % id)
	ok(baixo.outras == 0 and cima.outras == 0, "%s: o strafe só troca um quadro por vez (%d/%d saltos)" % [id, baixo.outras, cima.outras])
	# mira à direita (+x da tela): andar para cima é o +x do rig (passo-junta para a frente), para baixo é o outro lado (ao contrário)
	ok(cima.avanca >= 6 and cima.recua == 0, "%s: para cima o ciclo avança (%d avanços, %d recuos)" % [id, cima.avanca, cima.recua])
	ok(baixo.recua >= 6 and baixo.avanca == 0, "%s: para baixo o ciclo recua (%d recuos, %d avanços)" % [id, baixo.recua, baixo.avanca])

	# 3. a 30 graus da mira é andar de frente
	var diag := ciclo(colunas(dir_cos(cos(deg_to_rad(30.0))), false, 90), andar)
	ok(diag.fora == 0, "%s: a 30 graus da mira continua o andar (%d quadros fora)" % [id, diag.fora])

	# 4. histerese
	var perto := ciclo(colunas(dir_cos(0.55), false, 60), andar)
	ok(perto.fora == 0, "%s: começando a 0,55 do limiar, fica no andar (%d fora)" % [id, perto.fora])
	zerar()
	rodar(Vector2.DOWN, false, 30)
	for i in 20:  # gira aos poucos até 0,55 (virar de uma vez faria o herói olhar para onde anda por um quadro: a fonte ANDA)
		rodar(Vector2.DOWN.slerp(dir_cos(0.55), (i + 1) / 20.0), false, 1)
	var fica := ciclo(rodar(dir_cos(0.55), false, 60), st)
	ok(fica.fora == 0, "%s: vindo do strafe, 0,55 continua strafe sem piscar (%d fora)" % [id, fica.fora])
	var volta := rodar(dir_cos(0.7), false, 60)
	var volta_c := ciclo(volta.slice(5), andar)
	ok(volta_c.fora == 0, "%s: a 0,7 volta ao andar (%d fora)" % [id, volta_c.fora])

	# 5. mecha: de lado atirando = strafe_tiro, e o desvio da boca segue a tabela dele
	if id == "lightwolf":
		ok(anims.has("strafe_tiro"), "o mecha tem o strafe_tiro")
		if anims.has("strafe_tiro"):
			var stt := ints(anims.strafe_tiro.colunas)
			var tiro := ciclo(colunas(Vector2.DOWN, true, 120), stt)
			print("mecha de lado atirando: fora=%d vistos=%d recua=%d outras=%d" % [tiro.fora, tiro.vistos.size(), tiro.recua, tiro.outras])
			ok(tiro.fora == 0 and tiro.vistos.size() == stt.size(), "mecha de lado atirando: só strafe_tiro, ciclo inteiro (%d fora)" % tiro.fora)
			ok(tiro.outras == 0 and tiro.recua >= 6, "mecha de lado atirando: recua um quadro por vez (%d, %d saltos)" % [tiro.recua, tiro.outras])
			var frente := ciclo(colunas(Vector2.RIGHT, true, 60), ints(anims.andar_tiro.colunas))
			ok(frente.fora == 0, "mecha andando para a mira e atirando continua no andar_tiro (%d fora)" % frente.fora)
			var tab: Array = anims.strafe_tiro.get("desvio_boca", [])
			var achou := -1
			for q in tab.size():
				if Vector2(tab[q][1][1][0], tab[q][1][1][1]) != Vector2.ZERO:
					achou = q
					break
			if achou >= 0:
				h.quadro(int(stt[achou]), 1)
				ok(h.desvio_boca(1) == Vector2(tab[achou][1][1][0], tab[achou][1][1][1]), "desvio_boca lê o strafe_tiro (%s)" % h.desvio_boca(1))
	await _soltar()


func _soltar() -> void:
	w.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	for id in HEROIS:
		await testar(id)
	Herois.forcado = ""
	print("v2_strafe falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)
