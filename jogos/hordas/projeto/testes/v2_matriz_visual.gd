extends "res://testes/isolamento_v2.gd"
# O VISUAL da Matriz de Defesa do LightWolf (v2/matriz.gd, dados/v2_secundario.json > matriz > visual): o campo EM PÉ na frente do mecha, na direção da mira, feito de 3
# molduras hexagonais em degraus (a de trás menor e perto, a da frente maior e longe), em px inteiros. Confere: 3 molduras de 6 pontos inteiros; a altura do campo cobre boa
# parte do mecha (o corpo dele tem ~73 px); mirando para baixo o campo fica na frente do mecha (chave do y-sort abaixo dos pés) e largo; para cima, atrás (chave acima dos pés,
# o campo de costas não cobre o mecha); para a direita, estreito e todo à direita; as 8 direções dão hexágonos convexos de largura visível; a Matriz Ampla alarga; o clarão
# cai no plano da moldura da frente; no perfil Baixo não há varredura nem pulso; a varredura e o pulso ficam em até 2 Hz. Falha no código antigo (faixa deitada no chão na
# camada glow, sem `molduras`). O campo é grande e bem à frente (a da frente a 70 px ou mais no chão e com o dobro da largura do mecha) e a casca da regra acompanha
# a moldura da frente (colada por fora, até 8 px; a marca no chão no pé dela): falha na geometria de antes (a da frente a 30 px, 88 px de largura, casca 40). A REGRA (cobre, absorver, empurrar) é do v2_matriz e do v2_mare_matriz, que não mudam.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_matriz_visual.tscn  (imprime "v2_matriz_visual falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const PASSO := 1.0 / 60.0
const ALTURA_MECHA := 73.0  # o corpo opaco do mecha na folha (lightwolf_mecha_albedo.png, quadro 128x192: y 50 a 123)
const LARGURA_MECHA := 55.0  # idem na largura (x 36 a 91)
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)
		w.combate.efeitos(PASSO)


func caixa(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


func inteiros(pts: PackedVector2Array) -> bool:
	for p in pts:
		if not is_equal_approx(p.x, roundf(p.x)) or not is_equal_approx(p.y, roundf(p.y)):
			return false
	return true


## Convexo e sem se cruzar: todas as viradas para o mesmo lado (zero conta como reto).
func convexo(pts: PackedVector2Array) -> bool:
	var sinal := 0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var c := pts[(i + 2) % pts.size()]
		var x := (b - a).cross(c - b)
		if absf(x) < 0.001:
			continue
		var s := 1 if x > 0.0 else -1
		if sinal == 0:
			sinal = s
		elif s != sinal:
			return false
	return sinal != 0


func mirar(v: Vector2) -> void:
	w.heroi.fonte = Heroi.Fonte.STICK
	w.heroi.dir_olhar = v.normalized()
	passos(2)


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	var mat = w.combate.matriz
	h.imortal = false
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.escudo_forcado = true
	h.def = h.def_max
	mirar(Vector2.DOWN)
	passos(20)
	ok(mat.ativa(h), "a matriz está erguida")

	# 1. o desenho novo existe e mora no y-sort do mundo, aditivo e sem luz
	ok(mat.has_method("molduras") and mat.has_method("chave_ordem") and mat.has_method("varredura"), "o visual tem molduras, chave de ordem e varredura")
	if not mat.has_method("molduras"):
		print("v2_matriz_visual falhas=%d" % falhas)
		get_tree().quit()
		return
	ok(mat.no.get_parent() == w.no_mundo, "o campo é desenhado dentro do y-sort do mundo (na frente ou atrás do mecha)")
	var cm: CanvasItemMaterial = mat.no.material
	ok(
		cm != null and cm.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and cm.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED,
		"aditivo e sem luz (o escuro do mapa não apaga o campo)"
	)
	var vis: Dictionary = Dados.json("v2_secundario").matriz.visual
	ok(int(vis.molduras) == 3, "o dado pede 3 molduras")

	# 2. mirando para baixo: 3 molduras de 6 pontos inteiros, em degraus, na frente do mecha, cobrindo boa parte dele
	var baixo: Array = mat.molduras(h)
	ok(baixo.size() == 3, "3 molduras (%d)" % baixo.size())
	for m in baixo:
		ok(m.size() == 6 and inteiros(m) and convexo(m), "cada moldura é um hexágono convexo de 6 pontos em px inteiros (%s)" % str(m))
	var tras := caixa(baixo[0])
	var frente := caixa(baixo[2])
	print("baixo: trás %s, frente %s, pés %s, chave %s" % [tras, frente, h.pos, mat.chave_ordem(h)])
	ok(frente.size.y >= 0.75 * ALTURA_MECHA, "a moldura da frente cobre boa parte do mecha (%.0f px de %.0f)" % [frente.size.y, ALTURA_MECHA])
	ok(tras.size.x < frente.size.x and tras.size.y < frente.size.y, "a de trás é menor que a da frente (degraus)")
	ok(frente.end.y > tras.end.y and tras.end.y > h.pos.y, "mirando para baixo, a da frente fica mais longe (mais embaixo) e as duas à frente dos pés")
	ok(mat.chave_ordem(h).y > h.pos.y, "mirando para baixo, o campo é ordenado depois do mecha (na frente dele)")
	ok(frente.size.x >= 70.0, "de frente o campo é largo (%.0f px)" % frente.size.x)
	var larg_baixo := frente.size.x
	var alt_baixo := frente.size.y
	# os degraus se leem de frente: o TOPO de cada moldura sobe em relação à de trás (topos empatados viram um contorno só), e o pé e os lados também andam
	var meio := caixa(baixo[1])
	print("baixo: topos %d / %d / %d, pés %d / %d / %d" % [tras.position.y, meio.position.y, frente.position.y, tras.end.y, meio.end.y, frente.end.y])
	ok(
		meio.position.y <= tras.position.y - 6.0 and frente.position.y <= meio.position.y - 6.0,
		"de frente, cada topo fica pelo menos 6 px acima do de trás (3 molduras legíveis)"
	)
	ok(meio.end.y >= tras.end.y + 3.0 and frente.end.y >= meio.end.y + 3.0, "de frente, cada pé fica pelo menos 3 px abaixo do de trás")
	ok(tras.position.x >= meio.position.x + 4.0 and meio.position.x >= frente.position.x + 4.0, "de frente, cada lado sai pelo menos 4 px para fora do de trás")
	# o campo GRANDE e BEM À FRENTE (pedido do Alisson no #620, a ideia da Matriz de Defesa): a da frente passa a largura do mecha com folga e o pé dela fica a 70 px ou
	# mais do herói, no chão (a de antes ficava a 30 px, dentro do mecha, e media 88 px de largura: uma caixinha em volta dele)
	var d_frente := float(vis.distancia) + float(int(vis.molduras) - 1) * float(vis.recuo)
	ok(d_frente >= 70.0, "a moldura da frente fica bem à frente do mecha (%.0f px no chão)" % d_frente)
	ok(frente.size.x >= 2.0 * LARGURA_MECHA, "de frente a moldura da frente tem o dobro da largura do mecha (%.0f px de %.0f)" % [frente.size.x, LARGURA_MECHA])
	ok(frente.end.y >= h.pos.y + 35.0, "o pé da moldura da frente fica bem abaixo dos pés do mecha na tela (%.0f; pés %.0f)" % [frente.end.y, h.pos.y])
	# REGRA x VISUAL: a moldura da frente fica DENTRO da casca e colada nela (no máximo 8 px): o monstro que a casca segura fica logo na frente do campo e é desenhado
	# por cima dele, como deve; fora da casca ele pareceria atravessar a moldura, e longe demais para dentro o campo pareceria não segurar nada
	var casca := float(mat.cfg.casca)
	ok(d_frente <= casca and d_frente >= casca - 8.0, "a moldura da frente fica colada na casca, por dentro (%.0f px; casca %.0f)" % [d_frente, casca])
	# e a marca no chão (o alcance do empurrão) cai no pé da moldura da frente, a no máximo 2 px
	ok(absf(mat._raio() - d_frente) <= 2.0, "a marca no chão fica no pé da moldura da frente (%.0f; frente %.0f)" % [mat._raio(), d_frente])

	# 3. mirando para cima: atrás do mecha (ordenado antes dele) e todo acima dos pés
	mirar(Vector2.UP)
	var cima: Array = mat.molduras(h)
	ok(mat.chave_ordem(h).y < h.pos.y, "mirando para cima, o campo é ordenado antes do mecha (atrás: não o cobre)")
	var acima := true
	for m in cima:
		for p in m:
			acima = acima and p.y < h.pos.y
	ok(acima, "mirando para cima, todas as molduras ficam acima dos pés (atrás)")
	ok(caixa(cima[2]).size.y >= 0.75 * ALTURA_MECHA, "de costas o campo também é alto")

	# 4. mirando para a direita: painel de lado, estreito, todo à direita do meio do mecha
	mirar(Vector2.RIGHT)
	var dir: Array = mat.molduras(h)
	var fd := caixa(dir[2])
	print("direita: frente %s" % fd)
	ok(fd.size.x < 0.6 * larg_baixo and fd.size.x >= 10.0, "de lado as molduras são estreitas mas visíveis (%.0f px; de frente %.0f)" % [fd.size.x, larg_baixo])
	ok(fd.position.x > h.pos.x, "mirando para a direita, o campo fica à direita do mecha")
	ok(fd.size.y <= 1.2 * alt_baixo, "de lado a moldura não estica muito acima do mecha (%.0f px de altura; de frente %.0f)" % [fd.size.y, alt_baixo])

	# 5. as 8 direções: hexágonos convexos, inteiros, com largura visível
	for k in 8:
		mirar(Vector2.from_angle(TAU * float(k) / 8.0))
		for m in mat.molduras(h):
			ok(convexo(m) and inteiros(m) and caixa(m).size.x >= 10.0, "direção %d: moldura convexa, inteira e visível (%s)" % [k, str(m)])
		passos(1)  # e desenha de verdade nessa direção

	# 6. a Matriz Ampla alarga o campo junto com o arco
	mirar(Vector2.DOWN)
	var amp0: float = w.combate.armas.mods.get("ampla", 0.0)
	w.combate.armas.mods["ampla"] = 60.0
	var larg_ampla := caixa(mat.molduras(h)[2]).size.x
	ok(larg_ampla > larg_baixo + 20.0, "a Matriz Ampla (+60 graus) alarga o campo (%.0f -> %.0f px)" % [larg_baixo, larg_ampla])
	w.combate.armas.mods["ampla"] = amp0

	# 7. o clarão do golpe absorvido cai no plano da moldura da frente, do lado de quem bateu
	passos(40)
	ok(h.levar_dano(10.0, h.pos + Vector2(20, 30), null), "o golpe de baixo e à direita é absorvido")
	var f2 := caixa(mat.molduras(h)[2]).grow(1.0)
	ok(f2.has_point(mat._impacto), "o clarão fica na moldura da frente (%s em %s)" % [mat._impacto, f2])
	ok(mat._impacto.x > h.pos.x, "o golpe que vem da direita bate na metade direita do campo (%s, pés em %s)" % [mat._impacto, h.pos])
	passos(3)

	# 8. perfil Baixo: sem varredura nem pulso; normal: a varredura sobe, em até 2 Hz
	w.args["particulas"] = "poucas"
	passos(2)
	ok(mat.varredura() < 0.0 and mat._pulso() == 1.0, "Baixo: sem linha de varredura e sem pulso")
	w.args.erase("particulas")
	passos(2)
	var v0: float = mat.varredura()
	passos(6)
	ok(v0 >= 0.0 and mat.varredura() != v0, "normal: a linha de varredura corre (%.2f -> %.2f)" % [v0, mat.varredura()])
	var hz0 = mat.visual.get("varredura_hz")
	mat.visual["varredura_hz"] = 9.0
	ok(mat._hz_varredura() == 2.0, "um dado de 9 Hz na varredura vira 2 Hz")
	mat.visual["varredura_hz"] = hz0
	ok(float(vis.varredura_hz) <= 2.0 and float(vis.pulso_hz) <= 2.0, "os dados pedem no máximo 2 Hz")

	Herois.forcado = ""
	print("v2_matriz_visual falhas=%d" % falhas)
	get_tree().quit()
