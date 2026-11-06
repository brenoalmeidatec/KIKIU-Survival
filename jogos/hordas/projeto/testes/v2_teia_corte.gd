extends "res://testes/isolamento_v2.gd"
# Teste do CORTE da teia (v2/teias.gd cortar_arco, cortar_elipse e cortar_faixa; ganchos em combate.gd golpear, ruptura.gd e especial.gd; lista em dados/v2_teia.json > corta).
# Confere: os golpes de corpo a corpo da lista (katana, kanabo com a pancada de 360, naginata, kusarigama com o giro, tessen) que cobrem a teia a cortam; o arco virado para o outro lado
# não corta; fora do alcance não corta; as adagas não cortam; a orientação diagonal sai do sinal de dir.x*dir.y; martelo e giro estilhaçam (QUEBRADA); cortar não dá dano nem carga do Q;
# a ruptura e os especiais (terremoto, investida) cortam quando a lista deixa.
# LEGIBILIDADE (pedido do Alisson, 06/11: "o cone do golpe domina e os pedaços são pequenos"): os pedaços da folha de corte e da de quebra ficam visíveis por pelo menos PEDACOS_MIN_S segundos
# (quadros com 70% ou mais dos pixels do quadro inicial, contados depois do risco de 3 quadros no corte e do 1º quadro na quebra) e os do corte ficam MAIORES que a teia inteira (fio de 2 px); o risco brilhante dura 3 quadros (v2_teia_folhas).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_teia_corte.tscn  (imprime "v2_teia_corte falhas=0")

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
const PASSO := 1.0 / 60.0
const PEDACOS_MIN_S := 0.35

var falhas := 0
var w
var h
var t


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	Colisao.limpar()
	h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.pos = w.limite_andavel.get_center()
	h.definir_pos(h.pos)
	passos(3)


func poe_teia(p: Vector2) -> int:
	var i: int = t._livre()
	t._est[i] = t.PARADA
	t._t[i] = 0.0
	t._idade[i] = 0.0
	t._pos[i] = p
	t._geo[i] = 0
	t._var[i] = 0
	return i


func golpe(passo: Dictionary, dir: Vector2) -> int:
	return w.combate.golpear(h, h.pos + Vector2(0, -10), dir, passo, 0)


func _ready() -> void:
	Herois.forcado = "hazaki"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	t = w.combate.teias
	var herois: Array = Dados.json("v2_herois").herois

	# 1. todo passo corpo a corpo da lista corta: perto, na frente
	var passos_testados := 0
	for he in herois:
		for passo in he.get("cfg", {}).get("golpe", {}).get("passos", []):
			if str(passo.get("tipo", "melee")) == "adagas":
				ok(
					t.tipo_do_passo(str(passo.nome)) == "" or ["corte", "quebra"].has(t.tipo_do_passo(str(passo.nome))),
					"passo de adaga '%s' tem entrada válida" % passo.nome
				)
				continue
			zerar()
			var alc: float = w.combate.alcance_do_passo(passo, h)
			var i := poe_teia(h.pos + Vector2(minf(alc * 0.6, 50.0), 0))
			var q0: float = h.esp_carga
			golpe(passo, Vector2.RIGHT)
			var tipo: String = t.tipo_do_passo(str(passo.nome))
			ok(tipo != "", "o passo '%s' (%s) está na lista de corte" % [passo.nome, he.id])
			var esperado: int = t.QUEBRADA if tipo == "quebra" else t.CORTADA
			ok(t._est[i] == esperado, "%s/%s: a teia à frente foi %s (estado %d)" % [he.id, passo.nome, tipo, t._est[i]])
			ok(h.esp_carga == q0, "%s/%s: cortar a teia não dá carga ao Q" % [he.id, passo.nome])
			passos_testados += 1
	ok(passos_testados >= 10, "testou os passos de corpo a corpo de todos os heróis (%d)" % passos_testados)

	# 2. a katana: arco virado para o outro lado não corta; fora do alcance não corta; perto atrás não corta
	zerar()
	var katana: Dictionary = herois[0].cfg.golpe.passos[0]
	var alc_k: float = w.combate.alcance_do_passo(katana, h)
	var atras := poe_teia(h.pos + Vector2(-(t.raio + 8.0), 0))  # a teia inteira atrás do herói (a borda mais perto fica a 8 px, mas fora do arco)
	var longe := poe_teia(h.pos + Vector2(0, alc_k + t.raio + 30.0))
	golpe(katana, Vector2.RIGHT)
	ok(t._est[atras] == t.PARADA, "o golpe para a direita não corta a teia que está atrás dele")
	ok(t._est[longe] == t.PARADA, "fora do alcance não corta")
	golpe(katana, Vector2.LEFT)
	ok(t._est[atras] == t.CORTADA, "virando o golpe para a teia, ela é cortada")

	# 3. a borda da teia basta (um ponto das 17 amostras dentro do arco): teia cujo centro está além do alcance, mas a borda perto
	zerar()
	var borda := poe_teia(h.pos + Vector2(alc_k + t.raio * 0.5, 0))
	golpe(katana, Vector2.RIGHT)
	ok(t._est[borda] == t.CORTADA, "a borda da teia dentro do alcance já corta (centro a %.0f px, alcance %.0f)" % [alc_k + t.raio * 0.5, alc_k])

	# 4. a orientação do risco sai do sinal de dir.x * dir.y
	zerar()
	var a1 := poe_teia(h.pos + Vector2(20, 0))
	golpe(katana, Vector2(1, 1).normalized())
	var v1: int = t._var[a1]
	zerar()
	var a2 := poe_teia(h.pos + Vector2(20, 0))
	golpe(katana, Vector2(1, -1).normalized())
	var v2: int = t._var[a2]
	ok(v1 == 1 and v2 == 0, "descendo à direita o risco é '\' (1), subindo à direita é '/' (0): %d e %d" % [v1, v2])

	# 5. cortar não dá dano: a teia não é monstro; um monstro no caminho apanha como sempre (o corte não soma nada)
	zerar()
	var vida0: float = h.vida
	poe_teia(h.pos + Vector2(20, 0))
	golpe(katana, Vector2.RIGHT)
	ok(h.vida == vida0, "o herói não perde vida ao cortar")
	ok(w.combate.acertos == 0, "cortar teia não conta como acerto em monstro")

	# 6. as adagas não cortam: nenhuma entrada de corte para os nomes de passo de adaga
	for he in herois:
		for passo in he.get("cfg", {}).get("golpe", {}).get("passos", []):
			if str(passo.get("tipo", "melee")) == "adagas":
				ok(t.tipo_do_passo(str(passo.nome)) == "", "o passo de adaga '%s' (%s) não corta teia" % [passo.nome, he.id])

	# 7. a ruptura (E do Hazaki) rasga a teia na elipse em volta
	zerar()
	var r1 := poe_teia(h.pos + Vector2(40, 0))
	var r2 := poe_teia(h.pos + Vector2(0, 300))
	w.combate.ruptura.disparar(h, 1.0, false)
	ok(t._est[r1] == t.CORTADA, "a ruptura corta a teia ao lado do herói")
	ok(t._est[r2] == t.PARADA, "e não a que está longe")

	# 8. o terremoto (Q do Nicão) estilhaça e a investida (Q do Hazaki) corta no caminho
	zerar()
	var e1 := poe_teia(h.pos + Vector2(30, 0))
	var n: int = t.cortar_elipse(h.pos, 60.0, t.tipo_especial("terremoto"))
	ok(n == 1 and t._est[e1] == t.QUEBRADA, "o terremoto estilhaça a teia (quebra)")
	zerar()
	var f1 := poe_teia(h.pos + Vector2(120, 0))
	var f2 := poe_teia(h.pos + Vector2(120, 200))
	var nf: int = t.cortar_faixa(h.pos, Vector2.RIGHT, 300.0, 20.0, t.tipo_especial("investida"))
	ok(nf == 1 and t._est[f1] == t.CORTADA and t._est[f2] == t.PARADA, "a investida corta a teia no caminho e só ela")

	# 9. a lista em dados desliga: sem a entrada, o passo não corta
	zerar()
	var cp: Dictionary = t.cfg.corta.passos
	var guardado = cp["corte"]
	cp.erase("corte")
	var g1 := poe_teia(h.pos + Vector2(20, 0))
	golpe(katana, Vector2.RIGHT)
	ok(t._est[g1] == t.PARADA, "tirando 'corte' da lista em dados, a katana não corta")
	cp["corte"] = guardado

	# 10. a teia cortada some sozinha (a animação termina)
	zerar()
	var s1 := poe_teia(h.pos + Vector2(20, 0))
	golpe(katana, Vector2.RIGHT)
	var dur: float = float(t._folhas.corte.quadros) / float(t._folhas.corte.fps)
	passos(int(dur * 60.0) + 3)
	ok(t._est[s1] == t.LIVRE, "a animação do corte acaba e o slot volta ao pool (%.2f s)" % dur)

	# 11. os pedaços ficam visíveis por mais tempo e maiores (medido na folha)
	for nome in ["corte", "quebra"]:
		var f: Dictionary = t._folhas[nome]
		var im: Image = (f.tex as Texture2D).get_image()
		var qw := int(f.quadro.x)
		var qh := int(f.quadro.y)
		for linha in int(f.linhas):
			var cont: Array = []
			for col in int(f.quadros):
				var n_px := 0
				for y in qh:
					for x in qw:
						if im.get_pixel(col * qw + x, linha * qh + y).a > 0.5:
							n_px += 1
				cont.append(n_px)
			var visiveis := 0
			for col in range(3 if nome == "corte" else 1, int(f.quadros)):
				if float(cont[col]) >= 0.7 * float(cont[0]):
					visiveis += 1
			var seg := float(visiveis) / float(f.fps)
			ok(
				seg >= PEDACOS_MIN_S,
				"%s, linha %d: os pedaços ficam visíveis por %.2f s (mínimo %.2f; pixels por quadro %s)" % [nome, linha, seg, PEDACOS_MIN_S, str(cont)]
			)
			if nome == "corte":
				var pico := 0
				for col in range(3, int(f.quadros)):
					pico = maxi(pico, int(cont[col]))
				ok(
					float(pico) >= 1.15 * float(cont[0]),
					"corte, linha %d: os pedaços (fio de 2 px) pesam mais que a teia inteira (%d contra %d px)" % [linha, pico, int(cont[0])]
				)
	ok(float(t._folhas.corte.quadros) / float(t._folhas.corte.fps) >= 0.7, "o corte dura 0,7 s ou mais")
	print("v2_teia_corte falhas=%d" % falhas)
	get_tree().quit()
