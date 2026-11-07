extends "res://testes/isolamento_v2.gd"
# O pool de impactos e marcas (`MAX_FX` de v2/armas_novas.gd) tem de dar conta do pior caso real. Medida de 06/11 (LightWolf e os outros 9 heróis, horda no teto do
# Difícil + Pesadelo = 164 vivos, E e Q disparadas): com 48 vagas a Q de quase todo herói matava a tela inteira no mesmo quadro (164 pedidos de `fx_morte`) e
# 116 deles eram pisados ANTES de serem desenhados (o anel dá a volta e pisa os primeiros); o pico de pedidos vivos foi 128 a 174. Além da nuvem de morte
# sumir para a maior parte da horda, o pisão arrancava impactos e marcas de arma ainda tocando. A causa era o tamanho: uma morte tem um efeito por monstro
# (`combate.matar`), então o pool tem de ser dimensionado pelo teto de vivos (a lição do pool de inimigos), não por um número redondo.
#  1. MASSA: `teto` monstros morrem no mesmo quadro (a Q de um herói que limpa a tela): nenhum pedido pode ser pisado e todo monstro ganha o seu efeito.
#  2. DADOS: MAX_FX >= o maior teto de vivos possível (teto x maior densidade da dificuldade x Pesadelo) + MARGEM_FX para os impactos que tocam junto.
#  3. LONGA (só com --seg=N, sem ela roda uns 15 s): o herói luta contra a horda do diretor, atacando sempre, com a E e a Q disparadas assim que ficam prontas, com e
#     sem um golpe de cada tipo no nível 4. Imprime "PICO ..." (pico vivo, DEMANDA = o pico se o pool não tivesse teto, pedidos, descartados e quem ocupava o pool).
# A medida entra por uma subclasse só do teste (`Medida`), que troca o `armas.novas` do mundo: o código do jogo não ganha contador.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_fx_pico.tscn  (imprime "v2_fx_pico falhas=0")
#   longa: ... res://testes/v2_fx_pico.tscn ++ --herois=lightwolf,lucas --seg=60 --q=20   (q = s entre as Q, 0 = só a carga natural; --repor=1 repõe a horda sem parar)
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Novas := preload("res://v2/armas_novas.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const PASSO := 1.0 / 60.0
const TIPOS := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_lobo_sombrio", "inimigo_espantalho"]
const GOLPES := ["bola_fogo", "nuvem_veneno", "onda_choque", "cometa_gelado", "lobo_espirito", "raio_solar"]  # um de cada tipo do pool de golpes
const MARGEM_FX := 24  # vagas além de uma morte por monstro vivo: impactos de arma, marcas e acertos que tocam junto da limpeza

var falhas := 0
var w
var med
var q_seg := 20.0  # s entre uma Q e a próxima (0 = sem Q); a carga de verdade enche por dano e abate, mais devagar que isso
var repor := false  # true: repõe a horda até o teto a cada 0,25 s (mais abates por segundo do que o diretor do jogo traria)


class Medida:
	extends "res://v2/armas_novas.gd"
	var tocadas := 0
	var descartadas := 0
	var pico := 0
	var pico_quem := {}  # quem estava vivo no pico: nome da folha -> quantos
	var perdeu_quem := {}  # quem foi pisado: nome da folha -> quantos
	var soma_uso := 0
	var amostras := 0
	var demanda := 0  # o pico de efeitos que estariam vivos se o pool não tivesse teto (a conta pelo relógio e pela duração de cada pedido)
	var _fins: Array = []
	var _agora := 0.0

	func quadro(h, dt: float, perto: Array) -> void:
		super(h, dt, perto)
		_agora += dt

	func tocar_fx(f: Dictionary, p: Vector2, esc := 1.0, chao := false, flip := 1.0, cor := Color.WHITE) -> void:
		if f.is_empty():
			return
		tocadas += 1
		if x_t[_xi] < x_dur[_xi]:
			descartadas += 1
			var nome := _nome(x_folha[_xi])
			perdeu_quem[nome] = int(perdeu_quem.get(nome, 0)) + 1
		_fins.append(_agora + Anim.duracao(f))
		var k := 0
		while k < _fins.size():
			if _fins[k] <= _agora:
				_fins.remove_at(k)
			else:
				k += 1
		demanda = maxi(demanda, _fins.size())
		super(f, p, esc, chao, flip, cor)
		var vivos := 0
		for i in MAX_FX:
			if x_t[i] < x_dur[i]:
				vivos += 1
		if vivos > pico:
			pico = vivos
			pico_quem = {}
			for i in MAX_FX:
				if x_t[i] < x_dur[i]:
					var nome := _nome(x_folha[i])
					pico_quem[nome] = int(pico_quem.get(nome, 0)) + 1

	static func _nome(f) -> String:
		return (f.tex as Texture2D).resource_path.get_file().get_basename() if f is Dictionary and f.has("tex") else "?"

	## Chamado uma vez por quadro pelo teste: a média de efeitos vivos.
	func amostrar() -> void:
		var vivos := 0
		for i in MAX_FX:
			if x_t[i] < x_dur[i]:
				vivos += 1
		soma_uso += vivos
		amostras += 1


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _args() -> Dictionary:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var p := str(s).trim_prefix("--").split("=", true, 1)
		a[p[0]] = p[1] if p.size() > 1 else "1"
	return a


func _ready() -> void:
	var args := _args()
	Config.temporario("reduzir_piscadas", false)
	Config.g_temporario("particulas_sim", "muitas")
	_dados()
	await _massa()
	_custo()
	q_seg = float(args.get("q", 20))
	repor = bool(int(str(args.get("repor", "0"))))
	var seg := float(args.get("seg", 15))
	for id in str(args.get("herois", "lightwolf")).split(","):
		for armas in [false, true]:
			await _caso(id, armas, seg)
	Herois.forcado = ""
	print("v2_fx_pico falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


## O maior teto de vivos que uma partida pode ter: o teto dos dados x a maior densidade das dificuldades x a do Pesadelo (mesma conta de diretor.teto()).
func _teto_maximo() -> int:
	var dens := 1.0
	for d in Dificuldade.opcoes():
		dens = maxf(dens, float(d.get("densidade_mult", 1.0)))
	var pes := 1.0
	for m in Dados.json("v2_meta").modos:
		if str(m.id) == "pesadelo":
			pes = float(m.regras.get("densidade_mult", 1.0))
	return roundi(float(Dados.json("v2_combate").diretor.teto) * dens * pes)


func _dados() -> void:
	var teto := _teto_maximo()
	ok(teto >= 84, "a conta do teto máximo leu os dados (%d)" % teto)
	ok(Novas.MAX_FX >= teto + MARGEM_FX, "MAX_FX (%d) cobre uma morte por monstro no teto de vivos (%d) + %d vagas de folga" % [Novas.MAX_FX, teto, MARGEM_FX])


## A Q de um herói limpa a tela no mesmo quadro: `teto` monstros morrem de uma vez. Cada um ganha o seu efeito de morte e nenhum pedido pisa em outro.
func _massa() -> void:
	await _novo("lightwolf")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	w.combate.diretor.ligado = false
	var n: int = w.combate.diretor.teto()
	for i in n:
		var a := rng.randf() * TAU
		w.nascer_monstro(TIPOS[i % TIPOS.size()], w.heroi.pos + Vector2(cos(a), sin(a) * 0.62) * rng.randf_range(90.0, 260.0), true)
	ok(w.monstros.size() >= n, "a horda de %d está em campo (%d)" % [n, w.monstros.size()])
	var antes: int = med.tocadas
	var vivos: Array = w.monstros.duplicate()
	for m in vivos:
		w.combate.matar(m)
	var pedidos: int = med.tocadas - antes
	var vivos_fx := 0
	for i in med.MAX_FX:
		if med.x_t[i] < med.x_dur[i]:
			vivos_fx += 1
	print(
		(
			"MASSA: %d mortes no mesmo quadro, %d pedidos de efeito, %d efeitos vivos (pool de %d), %d pisados"
			% [vivos.size(), pedidos, vivos_fx, med.MAX_FX, med.descartadas]
		)
	)
	ok(pedidos >= vivos.size(), "cada morte pediu o seu efeito (%d pedidos para %d mortes)" % [pedidos, vivos.size()])
	ok(med.descartadas == 0, "a limpeza da tela não pisa em nenhum efeito (%d pisados)" % med.descartadas)
	ok(vivos_fx == pedidos, "todo efeito pedido está vivo no quadro (%d de %d)" % [vivos_fx, pedidos])


## Custo de varrer o pool inteiro (só informa): `_quadro_fx` com todos os slots tocando, por chamada.
func _custo() -> void:
	var n = Novas.new()
	n.montar(w.combate.armas)
	var f: Dictionary = preload("res://v2/anim_golpes.gd").de("fx_morte").get("impacto", {})
	for i in n.MAX_FX:
		n.tocar_fx(f, Vector2(i, i))
	var t0 := Time.get_ticks_usec()
	for i in 2000:
		n._quadro_fx(0.0)
	print("CUSTO: _quadro_fx com o pool cheio (%d slots) = %.2f us por chamada" % [n.MAX_FX, float(Time.get_ticks_usec() - t0) / 2000.0])


func _novo(heroi: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = heroi
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.meta_bonus["dificuldade"] = Dificuldade.regras("dificil")
	w.meta_bonus["pesadelo"] = {"densidade_mult": 1.3}
	w.heroi.imortal = true
	w.heroi.xp_proximo = 1.0e9  # sem subir de nível: a escolha de cartas pausaria a luta
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = true
	w.combate.diretor.ligado = true
	med = Medida.new()
	w.combate.armas.novas = med
	med.montar(w.combate.armas)
	for i in 3:
		w.avancar(PASSO)
	w.cam.cravar(w.heroi.centro())


func _repor(rng: RandomNumberGenerator) -> void:
	var dir = w.combate.diretor
	var falta: int = dir.teto() - w.monstros.size()
	for i in mini(maxi(falta, 0), 400 if w.tempo_partida < 1.0 else 12):
		var a := rng.randf() * TAU
		var d := rng.randf_range(90.0, 260.0)
		w.nascer_monstro(TIPOS[rng.randi() % TIPOS.size()], w.heroi.pos + Vector2(cos(a), sin(a) * 0.62) * d, true)


func _caso(heroi: String, com_golpes: bool, seg: float) -> void:
	await _novo(heroi)
	var c = w.combate
	var h = w.heroi
	var dir = c.diretor
	if com_golpes:
		for g in GOLPES:
			c.armas.definir_golpe(g, 4, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var e_disparos := 0
	var q_disparos := 0
	var vivos_max := 0
	var mortes0: int = c.mortes if "mortes" in c else 0
	for f in int(seg * 60.0):
		if f == 0 or (repor and f % 15 == 0):
			_repor(rng)
		var a := float(f) * 0.013  # o herói anda em círculo lento: os alvos giram em volta dele
		h.entrada_forcada = Vector2(cos(a), sin(a))
		if q_seg > 0.0 and f % int(q_seg * 60.0) == int(q_seg * 60.0) - 1:
			h.esp_carga = h.esp_carga_max
		if h.esp_carga >= h.esp_carga_max and h.especial():
			q_disparos += 1
		elif h.hab_recarga <= 0.0 and h.habilidade():
			e_disparos += 1
		w.avancar(PASSO)
		med.amostrar()
		vivos_max = maxi(vivos_max, w.monstros.size())
	var nome := "%s%s" % [heroi, "+golpes" if com_golpes else ""]
	var uso := float(med.pico) / float(med.MAX_FX)
	print(
		(
			"PICO %s: pico=%d/%d (%.0f%%) demanda=%d medio=%.1f pedidos=%d descartados=%d vivos_max=%d teto=%d E=%d Q=%d mortes=%d"
			% [
				nome,
				med.pico,
				med.MAX_FX,
				uso * 100.0,
				med.demanda,
				float(med.soma_uso) / maxf(float(med.amostras), 1.0),
				med.tocadas,
				med.descartadas,
				vivos_max,
				dir.teto(),
				e_disparos,
				q_disparos,
				(c.mortes if "mortes" in c else -1) - mortes0
			]
		)
	)
	print("   no pico: ", med.pico_quem, "  pisados: ", med.perdeu_quem)
	ok(med.tocadas > 20, "%s: o caso gerou efeitos de verdade (%d pedidos)" % [nome, med.tocadas])
	ok(med.descartadas == 0, "%s: nenhum efeito foi pisado por outro com o pool cheio (%d)" % [nome, med.descartadas])
	ok(med.demanda <= med.MAX_FX, "%s: a demanda (%d) cabe no pool (%d)" % [nome, med.demanda, med.MAX_FX])
