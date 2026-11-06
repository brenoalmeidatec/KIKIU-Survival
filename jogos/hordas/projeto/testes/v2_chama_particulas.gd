extends "res://testes/isolamento_v2.gd"
## As GOTAS DE FOGO de quem queima (v2/chama_gotas.gd; o corpo tingido é de v2/status_corpo.gd). Roda em qualquer modo (headless também): mede o estado das gotas.
## (1) Os dados: pool fixo de 616 (40 vagas x 14 + 4 vagas de elite x 14), classes por tamanho (10 / 14 / 14 / 12-14 gotas, estas em escala x2 e x3), vida de ~0,55 a 0,95 s, sobra de lado <= 3 e de cabeça <= 6 px.
## (2) A folha procedural (assets/v2/efeitos/chama_gotas.png, de fonte_arte/chama/gerar_gotas.py): 4 tamanhos x 2 variantes x 8 quadros, alfa 0/1, 5 cores, labaredas de 3 a 5 px de
##     largura e 4 a 8 de altura que NASCEM claras e gordas, esticam, encolhem e ESCURECEM até o vermelho escuro; cada quadro é diferente do anterior.
## (3) Os pontos de nascimento de TODO tipo de monstro e de todo quadro da folha: são pixels opacos, dentro da caixa opaca (num sprite com folga vazia embaixo a gota não nasce na folga).
## (4) Num lobo queimando por 4 s (parado): cobertura média de pixels de gota por quadro >= o piso (40 px; a config antiga, 2 a 4 gotas de 1 a 3 px, dava ~8 e falha), 10 a 16 gotas vivas,
##     a âncora de cada gota NASCE sobre pixel opaco do quadro, o quadro vem da IDADE da gota (cada uma numa fase), nascimento contínuo (sem onda), mais nascimentos na metade de baixo,
##     a gota INTEIRA nunca sai de lado além de 2 px da caixa opaca nem a ponta passa de 6 px acima dela, SOBE, vive no máximo 0,95 s.
## (5) Pool fixo: 60 monstros queimando não criam nó, as gotas vivas nunca passam do pool, e o elite queimando ganha vaga reservada mesmo com as comuns cheias.
## (6) "Reduzir piscadas": 3 a 4 gotas congeladas no quadro médio; nenhum pixel troca mais de 2 vezes em qualquer janela de 1 s (6 s). Perfil Baixo: nenhuma gota.
## (7) Custo: 40 monstros queimando, tempo médio do passo (atualizar) e do desenho por quadro, em ms (impresso; o teto aqui é folgado, o CI é lento).
## Roda: godot --path jogos/hordas/projeto res://testes/v2_chama_particulas.tscn  (imprime "v2_chama_particulas falhas=0")
const Anim := preload("res://v2/anim_golpes.gd")
const Mundo := preload("res://v2/mundo.tscn")
const Piscadas := preload("res://v2/piscadas.gd")
const PASSO := 1.0 / 60.0
const PISO_MIN := 40  # o piso de cobertura não pode ser afrouxado nos dados abaixo disso
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
	_parte_folha()
	var w = _mundo()
	_parte_pontos(w)
	_parte_lobo(w)
	_parte_elite(w)
	w.queue_free()
	var w2 = _mundo()
	_parte_pool(w2)
	w2.queue_free()
	var w3 = _mundo()
	_parte_calmo(w3)
	_parte_baixo(w3)
	w3.queue_free()
	var w4 = _mundo()
	await _parte_custo(w4)
	w4.queue_free()
	print("v2_chama_particulas falhas=", falhas)
	get_tree().quit(1 if falhas else 0)


func _parte_dados() -> void:
	var d := _dados
	ok(not d.is_empty(), "os dados têm status.fogo.gotas")
	var pool: int = int(d.get("vagas", 0)) * int(d.get("por_vaga", 0)) + int(d.get("vagas_elite", 0)) * int(d.get("por_vaga_elite", 0))
	ok(pool >= 600 and pool <= 680, "o pool é de ~616: 40 x 14 + 4 x 14 (%d)" % pool)
	var c: Dictionary = d.get("classes", {})
	ok(c.has("pequeno") and c.has("medio") and c.has("grande") and c.has("especial"), "classes pequeno, medio, grande e especial")
	if c.has("pequeno") and c.has("medio") and c.has("especial"):
		ok(int(c.pequeno.gotas[0]) >= 9 and int(c.pequeno.gotas[1]) <= 11, "monstro pequeno: ~10 gotas")
		ok(int(c.medio.gotas[0]) >= 13 and int(c.medio.gotas[1]) <= int(d.por_vaga), "monstro médio: ~14 gotas, no máximo o da vaga")
		ok(int(c.especial.gotas[0]) >= 12 and int(c.especial.gotas[1]) <= int(d.por_vaga_elite), "elite e chefe: 12 a 14 gotas (em escala x2 ou x3), no máximo o da vaga reservada")
	var vi: Array = d.get("vida_s", [0, 0])
	ok(float(vi[0]) >= 0.5 and float(vi[1]) <= 1.0 and float(vi[0]) < float(vi[1]), "vida de ~0,55 a 0,95 s")
	ok(int(d.get("sobra_lado", 99)) <= 3 and int(d.get("sobra_cabeca", 99)) <= 6, "sobra de lado <= 3 px e de cabeça <= 6 px")
	ok(float(d.get("cobertura_media_min_px", 0)) >= PISO_MIN, "o piso de cobertura é de pelo menos %d px (%s)" % [PISO_MIN, str(d.get("cobertura_media_min_px"))])
	var f: Dictionary = d.get("folha", {})
	ok(int(f.get("quadros", 0)) >= 6 and int(f.get("quadros", 0)) <= 8 and f.get("tamanhos", []).size() >= 3, "folha: 6 a 8 quadros e 3 ou 4 tamanhos")
	ok(not Dados.json("v2_pixelfx").get("status", {}).get("fogo", {}).has("corpo"), "o ramo antigo da chama no shader (status.fogo.corpo) saiu dos dados")


## A folha procedural: lê o PNG e mede.
func _parte_folha() -> void:
	var f: Dictionary = _dados.get("folha", {})
	var im := Image.load_from_file(ProjectSettings.globalize_path("res://assets/v2/" + str(f.get("arquivo", "efeitos/chama_gotas.png"))))
	ok(im != null and not im.is_empty(), "a folha das gotas existe")
	if im == null or im.is_empty():
		return
	var cw: int = int(f.celula[0])
	var ch: int = int(f.celula[1])
	var ay: int = int(f.ancora[1])
	var nq: int = int(f.quadros)
	var nt: int = f.tamanhos.size()
	ok(im.get_width() == cw * nq and im.get_height() == ch * nt * 2, "a folha tem %d quadros x %d filas de células %dx%d (%dx%d)" % [nq, nt * 2, cw, ch, im.get_width(), im.get_height()])
	var cores := {}
	var meio_alfa := 0
	var ant := ""
	var iguais := 0
	var maior_w := 0
	var maior_h := 0
	var menor_w := 99
	var menor_h := 99
	var ok_forma := true
	var escurece := true
	var encolhe := true
	for fila in nt * 2:
		var lum_prev := 9.0
		var seq := [0, 2, 3, 5, 6, nq - 1]
		var area2 := 0
		var w_max := 0
		var h_max := 0
		ant = ""
		for q in nq:
			var n := 0
			var x0 := 99
			var x1 := -1
			var y0 := 99
			var y1 := -1
			var lum := 0.0
			var sig := ""
			for y in ch:
				for x in cw:
					var c := im.get_pixel(q * cw + x, fila * ch + y)
					if c.a > 0.0 and c.a < 1.0:
						meio_alfa += 1
					if c.a >= 0.5:
						n += 1
						cores[c.to_html(false)] = true
						x0 = mini(x0, x)
						x1 = maxi(x1, x)
						y0 = mini(y0, y)
						y1 = maxi(y1, y)
						lum += 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
						sig += "%d,%d,%s;" % [x, y, c.to_html(false)]
			if n == 0:
				ok_forma = false
				continue
			lum /= float(n)
			if q == 2:
				area2 = n
				w_max = x1 - x0 + 1
				h_max = ay - y0 + 1
			if q == nq - 1:
				encolhe = encolhe and n < area2
			if seq.has(q):  # a fagulha (brasa) do meio é um pouco mais clara que o corpo: compara só os quadros da sequência
				if lum > lum_prev + 0.001:
					escurece = false
				lum_prev = lum
			if sig == ant:
				iguais += 1
			ant = sig
			ok_forma = ok_forma and x0 >= 0 and x1 < cw and y1 <= ay
		maior_w = maxi(maior_w, w_max)
		maior_h = maxi(maior_h, h_max)
		menor_w = mini(menor_w, w_max)
		menor_h = mini(menor_h, h_max)
	print("folha: %dx%d px, %d cores, %d px com alfa fracionário; labaredas (quadro 2) de %dx%d a %dx%d px" % [im.get_width(), im.get_height(), cores.size(), meio_alfa, menor_w, menor_h, maior_w, maior_h])
	ok(meio_alfa == 0, "alfa só 0 ou 1 (%d px fracionários)" % meio_alfa)
	ok(cores.size() >= 4 and cores.size() <= 6, "paleta de 4 a 6 cores (%d)" % cores.size())
	ok(menor_w >= 3 and maior_w <= 5 and menor_h >= 4 and maior_h <= 8, "labaredas de 3 a 5 px de largura e 4 a 8 de altura (%dx%d a %dx%d)" % [menor_w, menor_h, maior_w, maior_h])
	ok(ok_forma, "todo quadro tem pixels e cabe na célula, acima da âncora")
	ok(iguais == 0, "nenhum quadro repete o anterior (%d repetidos)" % iguais)
	ok(escurece, "do quadro 0 ao último a cor só escurece (amarelo-claro, laranja, vermelho, vermelho escuro)")
	ok(encolhe, "o último quadro é menor que o quadro 2 (vira fagulha)")


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
	lobo.vida = 99999.0  # o fogo de 60 s não mata o lobo no meio da medição
	lobo.vida_max = 99999.0
	_quadros(w, 10)
	ok(g.vivas() == 0, "sem fogo, nenhuma gota")
	lobo.queimar(0.0, 60.0)
	_quadros(w, 60)  # deixa o regime firmar (as gotas nascem espalhadas)
	var v: int = g.vaga_de(lobo)
	ok(v >= 0 and g.monstros() == 1, "o lobo queimando ganha uma vaga (vaga %d, %d monstros)" % [v, g.monstros()])
	if v < 0:
		return
	var por: int = g.cap_da_vaga(v)
	var tex: Texture2D = lobo.tipo.alb
	var im: Image = tex.get_image()
	var tw := int(lobo.tipo.w)
	var th := int(lobo.tipo.h)
	var pe := int(lobo.tipo.pe)
	var s: int = g.escala_de(lobo)
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
	var soma_vivas := 0
	var pool_ok := true
	var quadro_ruim := 0
	var quadros_distintos := 0
	var nasc_baixo := 0
	var nasc_por_janela := {}  # janela de 6 quadros -> nascimentos
	for k in por:  # as gotas que já estão no ar no começo da medição não contam como nascimento
		var g0: Dictionary = g.gota(g._base[v] + k)
		if g0.ativa:
			viva_ant[g._base[v] + k] = {"y0": g0.y0, "ult": g0.y, "t": g0.idade}
	for q in quadros:
		w.avancar(PASSO)
		var dados: Dictionary = g.pontos_do_quadro(lobo)
		var lim: Dictionary = g._limites(lobo, dados, s)
		var vivas := 0
		var pxs: Dictionary = g.pixels(v)
		var px_x0 := 99999
		var px_x1 := -99999
		var px_y0 := 99999
		for pp in pxs:
			px_x0 = mini(px_x0, pp.x)
			px_x1 = maxi(px_x1, pp.x)
			px_y0 = mini(px_y0, pp.y)
		if not pxs.is_empty():
			if float(px_x0) < lim.x0 - 2.0 - 0.001 or float(px_x1) > lim.x1 + 2.0 + 0.001:
				fora_lado += 1
			if float(px_y0) < lim.y0 - 6.0 - 0.001:
				fora_topo += 1
		var vistos := {}
		for k in por:
			var i: int = g._base[v] + k
			var gt: Dictionary = g.gota(i)
			if gt.ativa:
				vivas += 1
				vistos[gt.quadro] = true
				if gt.quadro != mini(int(gt.idade / gt.vida * 8.0), 7):
					quadro_ruim += 1
				if not viva_ant.has(i) or gt.idade < viva_ant[i].t:
					if viva_ant.has(i):
						terminou += 1
						subiu += 1 if int(viva_ant[i].ult) < int(viva_ant[i].y0) else 0
						if viva_ant[i].t > 0.96:
							vida_ruim += 1
					# nasceu: o pixel de origem (a âncora) é opaco no quadro atual
					var lx := int(floorf(gt.x0)) + tw / 2
					var ly := int(floorf(gt.y0)) + pe
					if lobo.espelha:
						lx = tw - 1 - lx
					nasceu += 1
					nasc_por_janela[q / 6] = int(nasc_por_janela.get(q / 6, 0)) + 1
					if float(ly) >= (float(dados.y0) + float(dados.y1)) * 0.5:
						nasc_baixo += 1
					if lx < 0 or ly < 0 or lx >= tw or ly >= th or im.get_pixel(lobo.coluna * tw + lx, lobo.linha * th + ly).a < 0.5:
						nasc_fora += 1
					viva_ant[i] = {"y0": gt.y0, "ult": gt.y, "t": gt.idade}
				else:
					viva_ant[i].ult = gt.y
					viva_ant[i].t = gt.idade
		quadros_distintos += vistos.size()
		max_vivas = maxi(max_vivas, vivas)
		min_vivas = mini(min_vivas, vivas)
		soma_vivas += vivas
		soma += pxs.size()
		pool_ok = pool_ok and g.vivas() <= g.n_gotas()
	var media := float(soma) / float(quadros)
	var pior_janela := 0
	for k in nasc_por_janela:
		pior_janela = maxi(pior_janela, int(nasc_por_janela[k]))
	var media_dist := float(quadros_distintos) / float(quadros)
	print("lobo (classe %d): cobertura média %.1f px de gota por quadro, %d gotas nasceram (%.0f%% na metade de baixo), %d terminaram, %d sobem, vivas %d a %d (média %.1f), %.1f quadros distintos por instante, no máximo %d nascimentos em 0,1 s" % [g._classe[v], media, nasceu, 100.0 * nasc_baixo / maxf(nasceu, 1), terminou, subiu, min_vivas, max_vivas, float(soma_vivas) / quadros, media_dist, pior_janela])
	var piso := maxf(float(_dados.get("cobertura_media_min_px", 4)), float(PISO_MIN))
	ok(media >= piso, "cobertura média de gota por quadro: %.1f px (piso %.0f)" % [media, piso])
	ok(nasceu >= 60, "muitas gotas nasceram em 4 s (%d)" % nasceu)
	ok(nasc_fora == 0, "toda gota nasce (a âncora) sobre pixel opaco do quadro (%d de %d fora)" % [nasc_fora, nasceu])
	ok(float(nasc_baixo) / maxf(nasceu, 1) >= 0.6, "o nascimento se concentra na metade de baixo do corpo (%.0f%%)" % (100.0 * nasc_baixo / maxf(nasceu, 1)))
	ok(fora_lado == 0, "nenhuma gota passa de 2 px da caixa opaca de lado (%d)" % fora_lado)
	ok(fora_topo == 0, "nenhuma ponta passa de 6 px acima da caixa opaca (%d)" % fora_topo)
	ok(terminou >= 40 and subiu >= int(terminou * 0.85), "as gotas SOBEM: terminam acima de onde nasceram (%d de %d)" % [subiu, terminou])
	ok(vida_ruim == 0, "nenhuma gota vive mais de 0,95 s (%d)" % vida_ruim)
	ok(quadro_ruim == 0, "o quadro de cada gota vem da idade dela (%d fora)" % quadro_ruim)
	ok(media_dist >= 4.0, "as gotas vivas estão em fases diferentes: %.1f quadros distintos por instante" % media_dist)
	ok(pior_janela <= 5, "nascimento contínuo, sem onda: no máximo 5 gotas nascem na mesma janela de 0,1 s (%d)" % pior_janela)
	ok(float(soma_vivas) / quadros >= 10.0 and max_vivas <= 16, "10 a 16 gotas vivas no lobo (%d a %d, média %.1f)" % [min_vivas, max_vivas, float(soma_vivas) / quadros])
	ok(pool_ok, "as gotas vivas nunca passam do pool")
	ok(lobo._estado_corpo() == 1, "o lobo queimando segue com o tingimento do corpo (estado FOGO)")
	lobo.queima_t = 0.0
	_quadros(w, 3)
	ok(g.vivas() == 0 and g.monstros() == 0, "o fogo acabou: as gotas somem e a vaga volta")


## (4b) O elite queimando (sprite em escala inteira >= 2): cada gota é desenhada na ESCALA do dono (retângulo = célula x escala, âncora em múltiplo da escala), o lobo comum
## segue em x1, e os limites (sobra de lado e de cabeça) valem na escala.
func _parte_elite(w) -> void:
	var g = w.combate.chama_gotas
	var p0: Vector2 = w.heroi.pos
	var el = w.combate.elites.nascer(TIPO, "", p0 + Vector2(-60, 70))
	ok(el != null, "o elite nasceu para a medição de escala")
	if el == null:
		return
	el.atordoa_t = 99.0
	el.vida = 99999.0
	el.vida_max = 99999.0
	el.queimar(0.0, 60.0)
	_quadros(w, 90)
	var v: int = g.vaga_de(el)
	ok(v >= int(_dados.get("vagas", 40)), "o elite tem vaga reservada (%d)" % v)
	if v < 0:
		return
	var sgeo: int = g.escala_de(el)  # a grade da folha do elite (esc = 1 com a folha _x2)
	var s: int = g.escala_gota(el)  # a escala lógica (x2): a que a gota herda
	ok(s >= 2, "o sprite do elite é desenhado em escala inteira >= 2 (x%d)" % s)
	var soma := 0
	var soma_vivas := 0
	var quadros := 240
	var fora_lado := 0
	var fora_topo := 0
	var tam_ruim := 0
	var grade_ruim := 0
	var max_vivas := 0
	var cel := Vector2(9, 12)
	for q in quadros:
		w.avancar(PASSO)
		var dados: Dictionary = g.pontos_do_quadro(el)
		var lim: Dictionary = g._limites(el, dados, sgeo)
		var pxs: Dictionary = g.pixels(v)
		soma += pxs.size()
		var x0 := 99999
		var x1 := -99999
		var y0 := 99999
		for pp in pxs:
			x0 = mini(x0, pp.x)
			x1 = maxi(x1, pp.x)
			y0 = mini(y0, pp.y)
		if not pxs.is_empty():
			if float(x0) < lim.x0 - 2.0 * s - 0.001 or float(x1) > lim.x1 + 2.0 * s + 0.001:
				fora_lado += 1
			if float(y0) < lim.y0 - 6.0 * s - 0.001:
				fora_topo += 1
		var vivas := 0
		for k in g.cap_da_vaga(v):
			var i: int = g._base[v] + k
			var gt: Dictionary = g.gota(i)
			if not gt.ativa:
				continue
			vivas += 1
			if g.has_method("retangulo"):
				var r: Rect2 = g.retangulo(i)
				if r.size != cel * float(s):
					tam_ruim += 1
				if posmod(int(gt.x), s) != 0 or posmod(int(gt.y), s) != 0:
					grade_ruim += 1
		max_vivas = maxi(max_vivas, vivas)
		soma_vivas += vivas
	var media := float(soma) / quadros
	print("elite (x%d): cobertura média %.1f px de gota por quadro, %.1f gotas vivas (máx %d), cap %d" % [s, media, float(soma_vivas) / quadros, max_vivas, g.cap_da_vaga(v)])
	ok(g.has_method("retangulo"), "a gota expõe o retângulo de desenho")
	ok(tam_ruim == 0, "toda gota do elite é desenhada em célula x escala = %dx%d (%d fora)" % [int(cel.x) * s, int(cel.y) * s, tam_ruim])
	ok(grade_ruim == 0, "posição (âncora) das gotas do elite em múltiplo da escala (%d fora)" % grade_ruim)
	ok(fora_lado == 0, "elite: nenhuma gota passa de 2 x escala px da caixa opaca de lado (%d)" % fora_lado)
	ok(fora_topo == 0, "elite: nenhuma ponta passa de 6 x escala px acima da caixa opaca (%d)" % fora_topo)
	ok(media >= float(_dados.get("cobertura_media_min_px", 4)), "elite: cobertura média %.1f px (piso do lobo %.0f)" % [media, float(_dados.get("cobertura_media_min_px", 4))])
	ok(float(soma_vivas) / quadros >= 9.0 and max_vivas <= g.cap_da_vaga(v), "elite: gotas vivas %.1f em média (máx %d)" % [float(soma_vivas) / quadros, max_vivas])
	# o comum segue em x1: um lobo ao lado desenha o retângulo 9 x 12
	var lobo = w.nascer_monstro(TIPO, p0 + Vector2(80, 70))
	lobo.atordoa_t = 99.0
	lobo.vida = 99999.0
	lobo.vida_max = 99999.0
	lobo.queimar(0.0, 60.0)
	_quadros(w, 90)
	var vl: int = g.vaga_de(lobo)
	var sl: int = g.escala_gota(lobo)
	ok(vl >= 0 and vl < int(_dados.get("vagas", 40)) and sl == 1, "o monstro comum usa vaga comum e escala 1 (vaga %d, x%d)" % [vl, sl])
	if vl >= 0 and g.has_method("retangulo"):
		var ruim := 0
		var n := 0
		for k in g.cap_da_vaga(vl):
			var gt2: Dictionary = g.gota(g._base[vl] + k)
			if gt2.ativa:
				n += 1
				if g.retangulo(g._base[vl] + k).size != cel * float(sl):
					ruim += 1
		ok(n > 0 and ruim == 0, "o comum desenha as gotas em x1 = 9x12 (%d de %d fora)" % [ruim, n])
	el.queima_t = 0.0
	lobo.queima_t = 0.0
	_quadros(w, 3)


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
	var teto: int = g.n_gotas()
	var dentro: int = int(_dados.get("vagas", 40)) * int(_dados.get("por_vaga", 14)) + int(_dados.get("vagas_elite", 4)) * int(_dados.get("por_vaga_elite", 14))
	print("pool: pico %d gotas vivas, %d monstros com vaga, de %d" % [pico, g.monstros(), teto])
	ok(teto == dentro and teto >= 600 and teto <= 680, "o pool tem tamanho fixo e é o dos dados (%d)" % teto)
	ok(pico <= teto and pico >= 300, "60 monstros queimando: gotas vivas no máximo %d (pico %d)" % [teto, pico])
	ok(g.monstros() <= int(_dados.get("vagas", 40)), "os comuns ocupam no máximo as vagas comuns (%d)" % g.monstros())
	ok(_nos_total(w.no_mundo) - nos0 <= 0, "nenhum nó nasceu por causa das gotas (+%d)" % (_nos_total(w.no_mundo) - nos0))
	var elite = c.elites.nascer(TIPO, "", p0 + Vector2(0, 80))
	if elite != null:
		elite.atordoa_t = 99.0
		elite.queimar(0.0, 60.0)
		_quadros(w, 90)
		var ve: int = g.vaga_de(elite)
		ok(ve >= int(_dados.get("vagas", 40)), "o elite queimando ganha vaga RESERVADA com as comuns cheias (vaga %d)" % ve)
		if ve >= 0:
			var vivas_e := 0
			for k in g.cap_da_vaga(ve):
				if g.gota(g._base[ve] + k).ativa:
					vivas_e += 1
			ok(g.cap_da_vaga(ve) == int(_dados.get("por_vaga_elite", 14)) and vivas_e >= 9, "o elite tem de 9 a 14 gotas vivas (%d de %d)" % [vivas_e, g.cap_da_vaga(ve)])
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
	lobo.vida = 99999.0
	lobo.vida_max = 99999.0
	lobo.queimar(0.0, 60.0)
	_quadros(w, 30)
	var v: int = g.vaga_de(lobo)
	ok(v >= 0, "com Reduzir piscadas o lobo queimando também ganha vaga")
	if v >= 0:
		var pior := _trocas(w, g, v, 720)
		var maximo := 0
		var vivas_max := 0
		var quadros_vistos := {}
		for q in 240:
			w.avancar(PASSO)
			maximo = maxi(maximo, g.pixels(v).size())
			var vivas := 0
			for k in g.cap_da_vaga(v):
				var gt: Dictionary = g.gota(g._base[v] + k)
				if gt.ativa:
					vivas += 1
					quadros_vistos[gt.quadro] = true
			vivas_max = maxi(vivas_max, vivas)
		print("calmo: pior pixel troca %d vezes em 1 s (12 s medidos); no máximo %d px de gota por quadro, %d gotas vivas, quadros vistos %s" % [pior, maximo, vivas_max, str(quadros_vistos.keys())])
		ok(pior <= 2, "Reduzir piscadas: nenhum pixel troca mais de 2 vezes em 1 s (pior %d)" % pior)
		ok(maximo >= 6, "Reduzir piscadas: ainda há gota (%d px)" % maximo)
		ok(vivas_max >= 2 and vivas_max <= 4, "Reduzir piscadas: 3 a 4 gotas por monstro, congeladas (%d vivas)" % vivas_max)
		ok(quadros_vistos.size() == 1, "Reduzir piscadas: as gotas ficam num quadro só, sem animar (%s)" % str(quadros_vistos.keys()))
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


## O custo de 40 monstros queimando: o passo (atualizar) e o desenho (o nó desenha 1 chamada por gota), em ms por quadro. Espera quadros de verdade (await) para o nó desenhar.
func _parte_custo(w) -> void:
	var c = w.combate
	var g = c.chama_gotas
	var p0: Vector2 = w.heroi.pos
	for k in 40:
		var mk = w.nascer_monstro(TIPO, p0 + Vector2(-140 + 7 * k, 30 + 8 * (k % 5)))
		mk.atordoa_t = 99.0
		mk.queimar(0.0, 90.0)
	_quadros(w, 120)
	var desenho_us := 0
	var desenhos := 0
	var chamou := Callable(self, "_medir_desenho").bind(g)
	if g.no != null:
		g.no.draw.disconnect(g._desenhar)
		g.no.draw.connect(chamou)
	var passo_us := 0
	var n := 120
	for q in n:
		var t0 := Time.get_ticks_usec()
		g.atualizar(PASSO)
		passo_us += Time.get_ticks_usec() - t0
		await get_tree().process_frame
	desenho_us = _desenho_us
	desenhos = _desenhos
	var vivas: int = g.vivas()
	var px: int = g.pixels().size()
	print("custo: 40 monstros queimando (%d gotas vivas, %d px quentes): passo %.3f ms por quadro; desenho (_desenhar: %d chamadas) %.3f ms por quadro em %d desenhos" % [vivas, px, float(passo_us) / n / 1000.0, vivas, float(desenho_us) / maxf(desenhos, 1) / 1000.0, desenhos])
	ok(g.monstros() == 40 and vivas >= 300, "40 monstros queimando: %d monstros com vaga, %d gotas vivas" % [g.monstros(), vivas])
	ok(float(passo_us) / n / 1000.0 < 8.0, "o passo de 40 monstros queimando custa menos de 8 ms por quadro (folgado para o CI)")
	if g.no != null:
		g.no.draw.disconnect(chamou)
		g.no.draw.connect(g._desenhar)


var _desenho_us := 0
var _desenhos := 0


func _medir_desenho(g) -> void:
	var t0 := Time.get_ticks_usec()
	g._desenhar()
	_desenho_us += Time.get_ticks_usec() - t0
	_desenhos += 1
