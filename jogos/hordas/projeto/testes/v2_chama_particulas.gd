extends "res://testes/isolamento_v2.gd"
## As GOTAS DE FOGO de quem queima (v2/chama_gotas.gd; o corpo tingido é de v2/status_corpo.gd). Roda em qualquer modo (headless também): mede o estado das gotas.
## (1) Os dados: pool de 160, 2 a 4 gotas por monstro, vida de 0,4 a 0,8 s, gotas de 1 a 3 px.
## (2) Os pontos de nascimento de TODO tipo de monstro e de todo quadro da folha: são pixels opacos, dentro da caixa opaca (num sprite com folga vazia embaixo a
##     gota não nasce na folga: a maior folga medida vem no relatório).
## (3) Num lobo queimando por 4 s (parado): cobertura média de pixels de gota por quadro >= o piso dos dados (a head 17d7b0a9 não tem gota nenhuma: 0), cada gota NASCE
##     sobre pixel opaco do quadro, nunca sai de lado além de 2 px da caixa opaca nem passa de 3 px acima dela, SOBE (termina acima de onde nasceu), vive de 0,4 a 0,8 s.
## (4) Pool fixo: 60 monstros queimando não criam nó, as gotas vivas nunca passam de 160, e o elite queimando ganha vaga mesmo com as comuns cheias.
## (5) "Reduzir piscadas": nenhum pixel das gotas troca mais de 2 vezes em qualquer janela de 1 s (medido quadro a quadro por 6 s). Perfil Baixo: nenhuma gota.
## Roda: godot --path jogos/hordas/projeto res://testes/v2_chama_particulas.tscn  (imprime "v2_chama_particulas falhas=0")
const Anim := preload("res://v2/anim_golpes.gd")
const Mundo := preload("res://v2/mundo.tscn")
const Piscadas := preload("res://v2/piscadas.gd")
const PASSO := 1.0 / 60.0
const TIPO := "inimigo_cao_ossos"
var falhas := 0
var _dados: Dictionary = {}


class Falso:
	var tipo: Dictionary
	var coluna := 0
	var linha := 0
	var espelha := false


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _nos_total(raiz: Node) -> int:
	var n := 1
	for c in raiz.get_children():
		n += _nos_total(c)
	return n


func _quadros(w, n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _mundo():
	Anim.suave = true
	Config.temporario(Piscadas.OPCAO, false)
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	return w


func _ready() -> void:
	_dados = Dados.json("v2_pixelfx").get("status", {}).get("fogo", {}).get("gotas", {})
	_parte_dados()
	var w = _mundo()
	_parte_pontos(w)
	_parte_lobo(w)
	w.queue_free()
	var w2 = _mundo()
	_parte_pool(w2)
	w2.queue_free()
	var w3 = _mundo()
	_parte_calmo(w3)
	_parte_baixo(w3)
	w3.queue_free()
	print("v2_chama_particulas falhas=", falhas)
	get_tree().quit(1 if falhas else 0)


func _parte_dados() -> void:
	var d := _dados
	ok(not d.is_empty(), "os dados têm status.fogo.gotas")
	ok(int(d.get("pool", 0)) >= 120 and int(d.get("pool", 0)) <= 200, "o pool é de ~160 (%s)" % str(d.get("pool")))
	var pm: Array = d.get("por_monstro", [0, 0])
	ok(int(pm[0]) == 2 and int(pm[1]) == 4, "2 a 4 gotas vivas por monstro")
	var vi: Array = d.get("vida_s", [0, 0])
	ok(is_equal_approx(float(vi[0]), 0.4) and is_equal_approx(float(vi[1]), 0.8), "vida de 0,4 a 0,8 s")
	var maior := 0
	for k in d.get("formas", {}):
		var px := 0
		for l in d.formas[k].linhas:
			px += str(l).count("X")
		maior = maxi(maior, px)
	ok(maior >= 2 and maior <= 3, "as gotas têm de 1 a 3 px (a maior tem %d)" % maior)
	ok(d.get("formas", {}).size() >= 3 and d.get("formas", {}).size() <= 4, "3 a 4 formas")
	ok(d.get("cores", []).size() == 4, "4 cores: amarelo-claro, laranja, vermelho, vermelho escuro")
	ok(int(d.get("sobra_lado", 99)) <= 2 and int(d.get("sobra_cabeca", 99)) <= 4, "a sobra de lado é de até 2 px e a da cabeça de poucos px")
	ok(not Dados.json("v2_pixelfx").get("status", {}).get("fogo", {}).has("corpo"), "o ramo antigo da chama no shader (status.fogo.corpo) saiu dos dados")


## Todo tipo, todo quadro: a lista de nascimento só tem pixel opaco, dentro da caixa opaca; e mede a folga vazia embaixo.
func _parte_pontos(w) -> void:
	var g = w.combate.chama_gotas
	ok(g != null, "o combate monta as gotas de fogo")
	if g == null:
		return
	var tipos: Dictionary = w.sprites._tipos
	var fora := 0
	var vazios := 0
	var quadros := 0
	var maior_folga := 0
	for nome in tipos:
		var t: Dictionary = tipos[nome]
		if t.is_empty() or not t.has("alb"):
			continue
		var im: Image = (t.alb as Texture2D).get_image()
		var cols: int = int(im.get_width()) / int(t.w)
		var lins: int = int(im.get_height()) / int(t.h)
		for l in lins:
			for c in cols:
				var f := Falso.new()
				f.tipo = t
				f.coluna = c
				f.linha = l
				var d: Dictionary = g.pontos_do_quadro(f)
				quadros += 1
				var pts: PackedInt32Array = d.pts
				if pts.is_empty():
					vazios += 1
					continue
				maior_folga = maxi(maior_folga, int(t.h) - 1 - int(d.y1))
				for k in pts.size() / 2:
					var x := pts[k * 2]
					var y := pts[k * 2 + 1]
					if im.get_pixel(c * int(t.w) + x, l * int(t.h) + y).a < 0.5 or x < d.x0 or x > d.x1 or y < d.y0 or y > d.y1:
						fora += 1
	print("pontos: %d quadros de %d tipos, %d vazios, maior folga vazia embaixo da célula = %d px" % [quadros, tipos.size(), vazios, maior_folga])
	ok(quadros > 20, "o teste varreu os quadros de vários tipos (%d)" % quadros)
	ok(fora == 0, "nenhum ponto de nascimento fora de pixel opaco ou da caixa opaca (%d)" % fora)
	ok(maior_folga >= 4, "algum sprite tem folga vazia embaixo (%d px): é o caso em que a base da célula erraria" % maior_folga)


func _parte_lobo(w) -> void:
	var g = w.combate.chama_gotas
	var p0: Vector2 = w.heroi.pos
	var lobo = w.nascer_monstro(TIPO, p0 + Vector2(40, 30))
	lobo.atordoa_t = 99.0  # parado: as posições relativas ao pé são as da tela
	_quadros(w, 10)
	ok(g.vivas() == 0, "sem fogo, nenhuma gota")
	lobo.queimar(0.0, 60.0)
	_quadros(w, 20)
	var v: int = g.vaga_de(lobo)
	ok(v >= 0 and g.monstros() == 1, "o lobo queimando ganha uma vaga (vaga %d, %d monstros)" % [v, g.monstros()])
	if v < 0:
		return
	var por := 4
	var tex: Texture2D = lobo.tipo.alb
	var im: Image = tex.get_image()
	var tw := int(lobo.tipo.w)
	var th := int(lobo.tipo.h)
	var pe := int(lobo.tipo.pe)
	var s := 1
	var soma := 0
	var quadros := 240
	var fora_lado := 0
	var fora_topo := 0
	var nasc_fora := 0
	var nasceu := 0
	var viva_ant := {}  # gota -> {y0, ult, t}
	var subiu := 0
	var terminou := 0
	var vida_ruim := 0
	var max_vivas := 0
	var min_vivas := 99
	var pool_ok := true
	for q in quadros:
		w.avancar(PASSO)
		var dados: Dictionary = g.pontos_do_quadro(lobo)
		var lim: Dictionary = g._limites(lobo, dados, s)
		var vivas := 0
		for k in por:
			var i: int = v * por + k
			var gt: Dictionary = g.gota(i)
			if gt.ativa:
				vivas += 1
				if gt.x < lim.x0 - 2.0 - 0.001 or gt.x > lim.x1 + 2.0 + 0.001:
					fora_lado += 1
				if gt.y < lim.y0 - 3.0 - 1.0:
					fora_topo += 1
				if not viva_ant.has(i) or gt.idade < viva_ant[i].t:
					if viva_ant.has(i):
						terminou += 1
						subiu += 1 if int(viva_ant[i].ult) < int(viva_ant[i].y0) else 0
						if viva_ant[i].t < 0.35 or viva_ant[i].t > 0.85:
							vida_ruim += 1
					# nasceu: o pixel de origem é opaco no quadro atual
					var lx := int(floorf(gt.x0)) + tw / 2
					var ly := int(floorf(gt.y0)) + pe
					if lobo.espelha:
						lx = tw - 1 - lx
					nasceu += 1
					if lx < 0 or ly < 0 or lx >= tw or ly >= th or im.get_pixel(lobo.coluna * tw + lx, lobo.linha * th + ly).a < 0.5:
						nasc_fora += 1
					viva_ant[i] = {"y0": gt.y0, "ult": gt.y, "t": gt.idade}
				else:
					viva_ant[i].ult = gt.y
					viva_ant[i].t = gt.idade
			elif viva_ant.has(i) and viva_ant[i].t > 0.0:
				pass
		max_vivas = maxi(max_vivas, vivas)
		min_vivas = mini(min_vivas, vivas)
		soma += g.pixels(v).size()
		pool_ok = pool_ok and g.vivas() <= g.n_gotas()
	var media := float(soma) / float(quadros)
	print("lobo: cobertura média %.1f px de gota por quadro, %d gotas nasceram, %d terminaram, %d sobem, vivas %d a %d" % [media, nasceu, terminou, subiu, min_vivas, max_vivas])
	ok(media >= float(_dados.get("cobertura_media_min_px", 4)), "cobertura média de gota por quadro: %.1f px (piso %s)" % [media, str(_dados.get("cobertura_media_min_px"))])
	ok(nasceu >= 20, "muitas gotas nasceram em 4 s (%d)" % nasceu)
	ok(nasc_fora == 0, "toda gota nasce sobre pixel opaco do quadro (%d de %d fora)" % [nasc_fora, nasceu])
	ok(fora_lado == 0, "nenhuma gota passa de 2 px da caixa opaca de lado (%d)" % fora_lado)
	ok(fora_topo == 0, "nenhuma gota passa de 3 px acima da caixa opaca (%d)" % fora_topo)
	ok(terminou >= 10 and subiu >= int(terminou * 0.9), "as gotas SOBEM: terminam acima de onde nasceram (%d de %d)" % [subiu, terminou])
	ok(vida_ruim == 0, "toda gota vive de 0,4 a 0,8 s (%d fora)" % vida_ruim)
	ok(max_vivas <= 4 and max_vivas >= 2, "de 2 a 4 gotas vivas (%d a %d)" % [min_vivas, max_vivas])
	ok(pool_ok, "as gotas vivas nunca passam do pool")
	ok(lobo._estado_corpo() == 1, "o lobo queimando segue com o tingimento do corpo (estado FOGO)")
	lobo.queima_t = 0.0
	_quadros(w, 3)
	ok(g.vivas() == 0 and g.monstros() == 0, "o fogo acabou: as gotas somem e a vaga volta")


func _parte_pool(w) -> void:
	var c = w.combate
	var g = c.chama_gotas
	var p0: Vector2 = w.heroi.pos
	for k in 60:
		var mk = w.nascer_monstro(TIPO, p0 + Vector2(-150 + 5 * k, 40 + 6 * (k % 5)))
		mk.atordoa_t = 99.0
	_quadros(w, 30)
	var nos0 := _nos_total(w.no_mundo)
	for mk in w.monstros:
		mk.queimar(0.0, 60.0)
	_quadros(w, 120)
	var pico := 0
	for q in 120:
		w.avancar(PASSO)
		pico = maxi(pico, g.vivas())
	var teto := int(_dados.get("pool", 160))
	print("pool: pico %d gotas vivas, %d monstros com vaga, de %d" % [pico, g.monstros(), teto])
	ok(pico <= teto and pico >= 60, "60 monstros queimando: gotas vivas no máximo %d (pico %d)" % [teto, pico])
	ok(g.n_gotas() == teto, "o pool tem tamanho fixo (%d)" % g.n_gotas())
	ok(g.monstros() <= teto / 4 - int(_dados.get("vagas_elite", 4)), "os comuns ocupam no máximo as vagas comuns (%d)" % g.monstros())
	ok(_nos_total(w.no_mundo) - nos0 <= 0, "nenhum nó nasceu por causa das gotas (+%d)" % (_nos_total(w.no_mundo) - nos0))
	var elite = c.elites.nascer(TIPO, "", p0 + Vector2(0, 80))
	if elite != null:
		elite.atordoa_t = 99.0
		elite.queimar(0.0, 60.0)
		_quadros(w, 60)
		ok(g.vaga_de(elite) >= 0, "o elite queimando ganha vaga reservada com as comuns cheias")
	else:
		ok(false, "o elite nasceu")


func _trocas(w, g, v: int, quadros: int) -> int:
	var hist := {}  # Vector2i -> Array[int] quadros em que o pixel mudou
	var ant := {}
	var pior := 0
	for q in quadros:
		w.avancar(PASSO)
		var agora: Dictionary = g.pixels(v)
		for k in agora:
			if not ant.has(k) or ant[k] != agora[k]:
				if not hist.has(k):
					hist[k] = []
				hist[k].append(q)
		for k in ant:
			if not agora.has(k):
				if not hist.has(k):
					hist[k] = []
				hist[k].append(q)
		ant = agora
	for k in hist:
		var l: Array = hist[k]
		var j := 0
		for i in l.size():
			while l[i] - l[j] >= 60:
				j += 1
			pior = maxi(pior, i - j + 1)
	return pior


func _parte_calmo(w) -> void:
	var g = w.combate.chama_gotas
	var p0: Vector2 = w.heroi.pos
	Config.temporario(Piscadas.OPCAO, true)
	var lobo = w.nascer_monstro(TIPO, p0 + Vector2(40, 30))
	lobo.atordoa_t = 99.0
	lobo.queimar(0.0, 60.0)
	_quadros(w, 30)
	var v: int = g.vaga_de(lobo)
	ok(v >= 0, "com Reduzir piscadas o lobo queimando também ganha vaga")
	if v >= 0:
		var pior := _trocas(w, g, v, 360)
		var maximo := 0
		for q in 120:
			w.avancar(PASSO)
			maximo = maxi(maximo, g.pixels(v).size())
		print("calmo: pior pixel troca %d vezes em 1 s; no máximo %d px de gota por quadro" % [pior, maximo])
		ok(pior <= 2, "Reduzir piscadas: nenhum pixel troca mais de 2 vezes em 1 s (pior %d)" % pior)
		ok(maximo >= 1, "Reduzir piscadas: ainda há gota (%d px)" % maximo)
	Config.temporario(Piscadas.OPCAO, false)


func _parte_baixo(w) -> void:
	var g = w.combate.chama_gotas
	var p0: Vector2 = w.heroi.pos
	var lobo = w.nascer_monstro(TIPO, p0 + Vector2(-40, 30))
	lobo.atordoa_t = 99.0
	lobo.queimar(0.0, 60.0)
	Anim.suave = false
	_quadros(w, 60)
	ok(g.vivas() == 0 and g.monstros() == 0, "perfil Baixo: nenhuma gota")
	Anim.suave = true
