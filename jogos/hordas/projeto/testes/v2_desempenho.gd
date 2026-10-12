extends Node
# Teste automático da horda em lote e da física dos monstros (v2/horda.gd, v2/monstro.gd, v2/combate.gd): 100 monstros sobem como linhas de números
# (sem sprite, sem nó) e saem em poucas fatias de MultiMesh; a sombra e a mancha deles existem em lote (média e alta) e só a mancha na baixa; a ordem
# de desenho em relação ao herói, ao cenário e à elite (nó) é a do y-sort; nenhum monstro termina dentro do corpo do herói depois de 3 s de
# perseguição (o grande, de escala 2 ou 3, também não) e eles cercam em vez de empilhar; elite e chefe viram nós e voltam ao lote ao renascer; o
# orçamento de luzes do perfil Baixo; e o tempo de um passo do mundo com a horda (só impresso no CI, como em v2_colisao).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_desempenho.tscn  (imprime "v2_desempenho falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Sombras := preload("res://v2/sombras.gd")
const PASSO := 1.0 / 60.0
const META_MS := 8.0  # meta: um passo do mundo com 100 monstros em menos de 8 ms (em headless, sem desenho)
const MARGEM := 4.0  # o limite local é META_MS * MARGEM (a máquina oscila com a carga); no CI só avisa
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Mapa sem monstros, herói imortal e parado no meio do santuário (o terreno aberto de nascimento), sem diretor.
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	w.sombras.definir_modo(Sombras.MEDIA)
	passos(3)


## `n` monstros de todos os tipos num anel (elíptico, como a tela) em volta do herói, caçando.
func anel(n: int, rmin: float, rmax: float, semente: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var tipos: Array = w.TIPOS_MONSTRO
	var lista: Array = []
	for i in n:
		var a := rng.randf() * TAU
		var r := rng.randf_range(rmin, rmax)
		var p: Vector2 = w.heroi.pos + Vector2(cos(a) * r, sin(a) * r * 0.62)
		p = p.clamp(w.limite_andavel.position, w.limite_andavel.end)
		lista.append(w.nascer_monstro(tipos[i % tipos.size()], p, true))
	return lista


func contar_mmi(no: Node) -> int:
	var n := 1 if no is MultiMeshInstance2D else 0
	for f in no.get_children():
		n += contar_mmi(f)
	return n


# --- 1. 100 monstros em lote: sem nós, em fatias, com sombra e mancha
func teste_lote() -> void:
	zerar()
	var filhos0: int = w.no_mundo.get_child_count()
	var mmi0 := contar_mmi(w)
	var lista := anel(96, 60.0, 230.0, 11)
	for k in [2.0, 2.0, 2.0, 3.0]:  # os grandes (a aranha de escala 2 do roteiro de oclusão)
		var m = w.nascer_monstro("inimigo_aranha_tecela", w.heroi.pos + Vector2(randf_range(-150, 150), randf_range(-90, 90)), true)
		m.definir_escala(k)
		lista.append(m)
	passos(20)
	ok(w.monstros.size() == 100, "100 monstros vivos (%d)" % w.monstros.size())
	var em_lote := 0
	var com_no := 0
	for m in w.monstros:
		if m.lote:
			em_lote += 1
		if m.sprite != null or m.blob != null or m.sh1 != null or m.olho != null or m.raiz is Node:
			com_no += 1
	ok(em_lote == 100, "os 100 monstros comuns estão em lote (%d)" % em_lote)
	ok(com_no == 0, "nenhum monstro em lote tem nó (%d com sprite, sombra, olho ou raiz)" % com_no)
	var tela: Rect2 = w.cam.retangulo().grow(w.MARGEM_SOMBRA)
	var na_tela := 0
	for m in w.monstros:
		if tela.has_point(m.pos):
			na_tela += 1
	var h = w.horda
	ok(na_tela >= 60, "monstros na tela: %d" % na_tela)
	ok(h.n_lote == na_tela, "a horda desenha quem está na tela (%d de %d)" % [h.n_lote, na_tela])
	var soma := 0
	for j in h.usadas:
		soma += h.fatias[j].n
	ok(soma == na_tela, "as fatias somam os monstros da tela (%d de %d)" % [soma, na_tela])
	ok(h.usadas >= 1 and h.usadas <= na_tela / 2, "poucas fatias: %d para %d monstros" % [h.usadas, na_tela])
	ok(h.lote_olhos.n == na_tela, "um olho por monstro (%d)" % h.lote_olhos.n)
	ok(h.lote_blob.n == na_tela, "uma mancha de pés por monstro (%d)" % h.lote_blob.n)
	ok(h.lote_sombra.n > na_tela / 3, "a sombra em lote existe para eles (%d instâncias, média)" % h.lote_sombra.n)
	var nos: int = w.no_mundo.get_child_count() - filhos0
	ok(nos <= h.fatias.size(), "100 monstros não criaram nós além das fatias (%d nós, %d fatias)" % [nos, h.fatias.size()])
	ok(contar_mmi(w) - mmi0 <= h.fatias.size() + 3, "só MultiMeshInstance2D das fatias, sombras, manchas e olhos (%d)" % (contar_mmi(w) - mmi0))
	for m in lista:
		ok(m.vivo, "monstro vivo")
	# as 3 qualidades de sombra
	w.sombras.definir_modo(Sombras.BAIXA)
	passos(4)
	ok(h.lote_blob.n == h.n_lote and h.lote_sombra.n == 0, "baixa: só a mancha (%d manchas, %d sombras)" % [h.lote_blob.n, h.lote_sombra.n])
	w.sombras.definir_modo(Sombras.ALTA)
	passos(8)
	ok(h.lote_sombra.n > h.n_lote / 3 and h.lote_blob.n == h.n_lote, "alta: sombra e mancha (%d, %d)" % [h.lote_sombra.n, h.lote_blob.n])
	w.sombras.definir_modo(Sombras.NENHUMA)
	passos(3)
	ok(h.lote_blob.n == 0 and h.lote_sombra.n == 0, "sem sombra: nada de sombra nem mancha")
	w.sombras.definir_modo(Sombras.MEDIA)
	passos(4)


# --- 2. a ordem de desenho: a fatia de cada monstro cai do mesmo lado de cada nó (herói, cenário, elite) que o y-sort poria o monstro
func violacoes_de_ordem() -> int:
	var h = w.horda
	var ys: Array = [w.heroi.raiz.position.y]
	for a in w.cenario.ativos:
		ys.append(a.raiz.position.y)
	for m in w.monstros:
		if not m.lote:
			ys.append(m.raiz.position.y)
	var ruins := 0
	var ant := -1.0e9
	for m in h.ordem:
		var y: float = m.raiz.position.y
		if y < ant:
			ruins += 1  # dentro do lote, quem tem o pé mais alto na tela é desenhado antes
		ant = y
		for ny in ys:
			if (ny <= y) != (ny < m.chave_y):
				ruins += 1
	return ruins


func teste_ordem() -> void:
	zerar()
	anel(70, 50.0, 200.0, 21)
	# uma elite (nó) no meio da horda e dois monstros colados no herói, um atrás e um na frente (parados)
	var el = w.combate.elites.nascer("inimigo_cao_ossos", "veloz", w.heroi.pos + Vector2(40, 10))
	ok(el != null and not el.lote and el.sprite != null, "a elite é um nó (não está em lote)")
	passos(30)
	ok(violacoes_de_ordem() == 0, "ordem de desenho no santuário: %d violações" % violacoes_de_ordem())
	var h = w.heroi
	var atras = w.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(0, -22), false)
	var frente = w.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(0, 22), false)
	atras.atordoa_t = 99.0
	frente.atordoa_t = 99.0
	passos(6)
	ok(
		atras.chave_y < h.raiz.position.y and frente.chave_y > h.raiz.position.y,
		"atrás do herói desenha antes dele, na frente desenha depois (%.1f < %.1f < %.1f)" % [atras.chave_y, h.raiz.position.y, frente.chave_y]
	)
	# o mesmo no meio das árvores (muitos nós por perto)
	var arvore = null
	var n_arv := 0
	for o in w.cenario.objetos:
		if o.chave == "arvore" and o.pos.x > 600.0 and o.pos.x < 2200.0 and o.pos.y > 400.0 and o.pos.y < 1200.0:
			n_arv += 1
			if arvore == null or n_arv == 6:
				arvore = o
	ok(arvore != null, "achou uma árvore para o teste")
	if arvore != null:
		h.definir_pos(arvore.pos + Vector2(0, 40))
		w.cam.cravar(h.pos + Heroi.CENTRO_CORPO)
		var ms = anel(60, 40.0, 180.0, 31)
		passos(40)
		var ruins := violacoes_de_ordem()
		ok(
			ruins == 0,
			(
				"ordem de desenho entre as árvores: %d violações (%d objetos, %d fatias, %d monstros)"
				% [ruins, w.cenario.ativos.size(), w.horda.usadas, w.horda.n_lote]
			)
		)
		ok(ms.size() == 60, "monstros do teste das árvores")
		print(
			(
				"v2_desempenho ordem entre as árvores: %d monstros na tela em %d fatias, %d objetos do cenário, 0 violações esperadas (%d)"
				% [w.horda.n_lote, w.horda.usadas, w.cenario.ativos.size(), ruins]
			)
		)


# --- 3. física: ninguém entra no corpo do herói, eles cercam e não empilham
func teste_cerco() -> void:
	zerar()
	var h = w.heroi
	var pos0: Vector2 = h.pos
	var lista := anel(70, 50.0, 190.0, 41)
	var grandes: Array = []
	for k in [2.0, 3.0]:
		var m = w.nascer_monstro("inimigo_aranha_tecela", h.pos + Vector2(120.0 * (k - 2.5), 40), true)
		m.definir_escala(k)
		grandes.append(m)
		lista.append(m)
	passos(180)  # 3 s de perseguição
	ok(h.pos.is_equal_approx(pos0), "o herói não saiu do lugar (%s)" % str(h.pos))
	var dentro := 0
	var perto := 0
	var oitavos := {}
	var pior := 1.0e9
	for m in lista:
		var d: Vector2 = m.pos - h.pos
		var lim: float = h.raio + m.raio
		pior = minf(pior, d.length() - lim)
		if d.length() < lim - 0.75:
			dentro += 1
		if d.length() < lim + 8.0:
			perto += 1
			oitavos[int(floor((d.angle() + PI) / (TAU / 8.0))) % 8] = true
	ok(dentro == 0, "nenhum monstro dentro do corpo do herói depois de 3 s (%d dentro; a menor folga %.2f px)" % [dentro, pior])
	for m in grandes:
		var d: float = (m.pos - h.pos).length()
		ok(d >= h.raio + m.raio - 0.75, "o monstro grande (escala %.0f, raio %.0f) fica fora do corpo do herói (%.1f px)" % [m.escala, m.raio, d])
	ok(perto >= 8, "eles chegam perto do herói: %d encostados" % perto)
	ok(oitavos.size() >= 5, "eles cercam: %d dos 8 lados ocupados" % oitavos.size())
	# sem bolo: quase nenhum par de monstros fica com os corpos um dentro do outro
	var pares := 0
	var colados := 0
	for i in lista.size():
		for j in range(i + 1, lista.size()):
			var a = lista[i]
			var b = lista[j]
			var d: float = (a.pos - b.pos).length()
			if d < (a.raio + b.raio) * 2.0:
				pares += 1
				if d < (a.raio + b.raio) * 0.4:
					colados += 1
	ok(colados <= maxi(2, pares / 12), "pouca pilha: %d pares quase em cima um do outro, de %d pares próximos" % [colados, pares])
	# o herói anda para dentro de um monstro parado: ele é empurrado para fora, não atravessado
	zerar()
	var m1 = w.nascer_monstro("inimigo_cavaleiro_oco", w.heroi.pos + Vector2(30, 0), false)
	m1.atordoa_t = 99.0
	w.heroi.entrada_forcada = Vector2(1, 0)
	w.heroi.fonte = Heroi.Fonte.ANDA
	passos(40)
	w.heroi.entrada_forcada = Vector2.ZERO
	var dd: float = (m1.pos - w.heroi.pos).length()
	ok(dd >= w.heroi.raio + m1.raio - 1.0, "o herói empurra o monstro parado em vez de atravessar (%.1f px, mínimo %.1f)" % [dd, w.heroi.raio + m1.raio])


# --- 4. elite e chefe são nós, e ao renascer voltam ao lote
func teste_elite() -> void:
	zerar()
	var el = w.combate.elites.nascer("inimigo_espantalho", "blindado", w.heroi.pos + Vector2(80, 0))
	passos(10)
	ok(el != null and not el.lote and el.sprite != null and el.sh1 != null and el.raiz is Node2D, "a elite é um nó com sprite e sombra")
	ok(el.ativo and el.sh1.visible or el.sh2.visible or el.blob.visible, "a sombra da elite aparece")
	w.combate.matar(el)
	el.reviver(w.heroi.pos + Vector2(60, 0))
	ok(el.lote and el.sprite != null and not el.sprite.visible and not (el.raiz is Node), "renasce como monstro comum: de volta ao lote e sem nós visíveis")
	var antes: int = w.monstros.size()
	w.monstros.append(el)
	passos(5)
	ok(w.horda.n_lote >= 1, "a horda desenha o renascido")
	w.monstros.erase(el)
	ok(w.monstros.size() == antes, "limpeza do teste")


# --- 5. orçamento de luzes
func teste_luzes() -> void:
	zerar()
	var livre: int = w.luzes.ligadas()
	ok(livre >= 8, "no santuário há luzes ligadas de sobra (%d)" % livre)
	w.luzes.orcamento = 6
	passos(4)
	ok(w.luzes.ligadas() <= 6 and w.luzes.ligadas() >= 3, "orçamento de 6: %d ligadas" % w.luzes.ligadas())
	var presas := 0
	for e in w.luzes.lista:
		if e.alvo != null and e.ativa:
			presas += 1
	ok(presas == 2, "as duas luzes do herói ficam ligadas (%d)" % presas)
	ok(w.luzes.dn == w.luzes.ligadas(), "as luzes das sombras são as ligadas (%d de %d)" % [w.luzes.dn, w.luzes.ligadas()])
	w.luzes.orcamento = 0
	passos(4)
	ok(w.luzes.ligadas() == livre, "sem orçamento voltam todas (%d de %d)" % [w.luzes.ligadas(), livre])
	Config.g_perfil_temporario("baixo")
	w._ler_graficos()
	ok(w.luzes.orcamento == 6, "perfil baixo: orçamento de 6 luzes (%d)" % w.luzes.orcamento)
	passos(4)
	ok(w.luzes.ligadas() <= 6, "perfil baixo: %d luzes ligadas" % w.luzes.ligadas())
	Config.g_perfil_temporario("medio")
	w._ler_graficos()
	ok(w.luzes.orcamento == 0, "perfil médio: sem orçamento")
	Config.g_perfil_temporario("alto")
	w._ler_graficos()
	ok(w.luzes.orcamento == 0, "perfil alto: sem orçamento")
	Config.g_perfil_temporario("medio")
	w._ler_graficos()
	passos(4)


# --- 6. tempo de um passo do mundo com a horda (só impresso no CI)
func teste_tempo() -> void:
	zerar()
	anel(100, 70.0, 230.0, 51)
	passos(60)
	var tempos: Array = []
	for _lote in 7:
		var t0 := Time.get_ticks_usec()
		passos(30)
		tempos.append((Time.get_ticks_usec() - t0) / 30.0)
	tempos.sort()
	var ms: float = tempos[3] / 1000.0
	print(
		(
			"v2_desempenho tempo: um passo do mundo com 100 monstros = %.2f ms (mediana de 7 lotes de 30; min %.2f, max %.2f; meta %.1f ms, limite %.1f ms)"
			% [ms, tempos[0] / 1000.0, tempos[6] / 1000.0, META_MS, META_MS * MARGEM]
		)
	)
	if OS.get_environment("CI") != "":
		if ms >= META_MS * MARGEM:
			print("AVISO v2_desempenho: %.2f ms por passo, acima do limite %.1f ms (só aviso no CI)" % [ms, META_MS * MARGEM])
	else:
		ok(ms < META_MS * MARGEM, "um passo do mundo com 100 monstros: %.2f ms, acima do limite %.1f ms" % [ms, META_MS * MARGEM])


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	teste_lote()
	teste_ordem()
	teste_cerco()
	teste_elite()
	teste_luzes()
	teste_tempo()
	print("v2_desempenho falhas=%d" % falhas)
	get_tree().quit()
