extends "res://testes/isolamento_v2.gd"
# Teste da TEIA NO CHÃO (v2/teias.gd): a elipse (centro, borda, achatada em y), o teto de teias vivas (a mais velha desmancha; 3 no perfil Baixo), o pool fixo (nenhum nó novo
# em 50 disparos), a camada (z_index -60: acima do decalque -90, abaixo das sombras -51, a mesma do chão de efeitos.gd), o voo da bolota (pousa onde mirou em voo_s),
# a expiração sozinha (vida_s + sumir_s) e o sumiço curto.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_teia_chao.tscn  (imprime "v2_teia_chao falhas=0")

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
const Anim := preload("res://v2/anim_golpes.gd")
const Avisos := preload("res://v2/avisos.gd")
const PASSO := 1.0 / 60.0

var falhas := 0
var w
var h


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


func vivas(t) -> int:
	return t.contar(t.ABRINDO) + t.contar(t.PARADA)


func _ready() -> void:
	Herois.forcado = "hazaki"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	var t = w.combate.teias
	var c: Vector2 = h.pos + Vector2(0, 120)
	var raio: float = t.raio
	var ry: float = raio * Avisos.ACHATA  # a proporção dos avisos, não a do dado: o dado errado tem de reprovar

	# 1. a elipse: centro, borda em x, borda em y (achatada), fora
	t._est[0] = t.PARADA
	t._pos[0] = c
	ok(t.dentro(c), "o centro está dentro")
	ok(t.dentro(c + Vector2(raio - 1.0, 0)) and not t.dentro(c + Vector2(raio + 1.0, 0)), "a borda em x é o raio (%s)" % raio)
	ok(t.dentro(c + Vector2(0, ry - 1.0)) and not t.dentro(c + Vector2(0, ry + 1.0)), "a borda em y é o raio x 0,62 (%.1f): o chão é achatado" % ry)
	ok(not t.dentro(c + Vector2(raio * 0.8, ry * 0.8)), "o canto da caixa (0,8; 0,8) está fora da elipse")
	t._est[0] = t.LIVRE
	ok(not t.dentro(c), "teia livre não segura ninguém")

	# 2. a camada: z -60, entre o decalque do cenário e as sombras, a mesma do chão de efeitos
	ok(t.no != null and t.no.z_index == -60, "o nó da teia está em z_index -60")
	ok(t.no.z_index > -90 and t.no.z_index < -51, "acima do decalque (-90) e abaixo das sombras (-51)")
	ok(w.combate.fx.chao != null and t.no.z_index == w.combate.fx.chao.z_index, "a mesma camada do chão de efeitos")
	ok(t.no.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "filtro NEAREST (pixel art)")

	# 3. o voo: a bolota pousa onde mirou, em voo_s, e abre
	var alvo: Vector2 = c
	ok(t.lancar(c + Vector2(-100, 0), 10.0, alvo), "lançou a bolota")
	ok(t.contar(t.VOANDO) == 1 and t.lancadas == 1, "uma bolota no ar")
	var voo := float(t.aranha.voo_s)
	passos(int(voo * 60.0) + 2)
	ok(t.contar(t.VOANDO) == 0 and t.contar(t.ABRINDO) + t.contar(t.PARADA) == 1, "pousou (e está abrindo ou parada)")
	var i: int = t._est.find(t.ABRINDO) if t._est.find(t.ABRINDO) >= 0 else t._est.find(t.PARADA)
	ok(i >= 0 and t._pos[i].distance_to(alvo.round()) < 1.0, "pousou no ponto mirado")
	passos(40)
	ok(t.contar(t.PARADA) == 1, "depois de abrir fica PARADA")

	# 4. o teto de vivas: lança muitas; a mais velha desmancha; nunca passa do teto
	zerar()
	var teto: int = t.teto_vivas()
	ok(teto == int(Dados.json("v2_teia").teia.max_vivas), "o teto normal vem dos dados")
	var maximo := 0
	var sumiu := false
	for k in 14:
		t.lancar(h.pos + Vector2(-150 + 25 * k, 60 + 20 * (k % 3)), 8.0, h.pos + Vector2(-150 + 25 * k, 60 + 20 * (k % 3)))
		for q in 50:
			passos(1)
			maximo = maxi(maximo, vivas(t))
			sumiu = sumiu or t.contar(t.SUMINDO) > 0
	ok(maximo <= teto, "nunca mais que %d teias vivas (maximo %d)" % [teto, maximo])
	ok(sumiu, "acima do teto a mais velha desmancha (SUMINDO)")
	# perfil Baixo: teto menor
	Anim.suave = false
	var baixo: int = t.teto_vivas()
	ok(baixo == int(Dados.json("v2_teia").teia.max_vivas_baixo), "perfil Baixo: teto de %d" % baixo)
	Anim.suave = true

	# 5. pool fixo: nenhum nó novo em 50 disparos
	zerar()
	var nos0: int = get_tree().get_node_count()
	for k in 50:
		t.lancar(h.pos + Vector2(k % 7 * 20, 40), 8.0, h.pos + Vector2(k % 7 * 20, 40))
		passos(10)
	ok(get_tree().get_node_count() == nos0, "50 disparos não criam nó (%d -> %d)" % [nos0, get_tree().get_node_count()])
	ok(t._est.size() == 2 * t.max_vivas + t.max_voando, "o pool tem o tamanho fixo (2 x vivas + voando)")
	ok(t.contar(t.VOANDO) <= t.max_voando, "no máximo %d bolotas no ar" % t.max_voando)

	# 6. expira sozinha: vida_s parada, depois sumir_s e livre
	zerar()
	t.lancar(h.pos + Vector2(0, 80), 8.0, h.pos + Vector2(0, 80))
	var seg := 0.0
	var viu_sumindo := false
	while seg < t.vida_s + t.sumir_s + 3.0 and (t.contar(t.LIVRE) < t._est.size()):
		w.avancar(0.1)
		seg += 0.1
		viu_sumindo = viu_sumindo or t.contar(t.SUMINDO) > 0
	ok(viu_sumindo, "antes de sumir passa por SUMINDO")
	ok(t.contar(t.LIVRE) == t._est.size(), "a teia expira sozinha (livre depois de %.1f s)" % seg)
	var esperado: float = t.vida_s + t.sumir_s + float(t.aranha.voo_s)
	ok(absf(seg - esperado) < 0.8, "e leva ~ voo + vida + sumir (%.1f s, esperado %.1f)" % [seg, esperado])
	print("v2_teia_chao falhas=%d" % falhas)
	get_tree().quit()
