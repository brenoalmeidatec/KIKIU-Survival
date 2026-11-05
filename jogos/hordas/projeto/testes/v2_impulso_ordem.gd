extends "res://testes/isolamento_v2.gd"
# Teste automático da ORDEM DE DESENHO do mecha no IMPULSO (rodada 5; v2/impulso.gd > ordem, heroi.gd > _ordenar/y_ordem, horda.gd, oclusao.gd).
# O vídeo da rodada 4 mostrou o mecha voando "por cima" de uma fila e sendo desenhado ATRÁS dos monstros um pouco mais para baixo na tela (com a
# silhueta translúcida da oclusão por cima), e raspando numa árvore com a troca de ordem parecendo atravessar o tronco. Confere:
#  1. no ar, monstros com os pés até ordem_px abaixo dos pés do mecha (as fatias da horda) ficam ATRÁS dele no y-sort, e a oclusão não acende por eles;
#     no chão (antes e depois do voo) eles voltam para a frente e a silhueta volta;
#  2. a descida não salta de ordem: o y da ordem desce no máximo uns px por quadro, junto com o desenho;
#  3. árvore (objeto grande, segura o voo) na frente e cobrindo o mecha: a ordem contra ela fica a do chão (o mecha atrás do tronco);
#     objeto baixo (que o voo atravessa) no mesmo lugar fica atrás dele.
# O y-sort "de verdade" do herói é o do Godot: com raiz.y_sort_enabled o sprite entra pelo próprio y (raiz + sprite.position), senão pela raiz.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_impulso_ordem.tscn  (imprime "v2_impulso_ordem falhas=0")

const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
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


## O y com que o Godot ordena o corpo do herói no y-sort do mundo agora (independe do código novo: é a regra do motor).
func chave_heroi(h) -> float:
	return h.raiz.position.y + (h.sprite.position.y if h.raiz.y_sort_enabled else 0.0)


## Partida limpa, sem colisão do cenário (os objetos seguem desenhados) e o mecha PARADO no voo (m_vel_mov 0: o voo não sai do lugar).
func zerar(p: Vector2) -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	Colisao.limpar()
	var h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.correr_forcado = false
	h.escudo_forcado = false
	h.m_vel_mov = 0.0
	h.fonte = Heroi.Fonte.MOUSE
	h.pos = p
	h.definir_pos(p)
	w.mouse_forcado = h.centro() + Vector2(4000, 0)
	w.cam.cravar(p + Heroi.CENTRO_CORPO)
	passos(6)


func apertar() -> void:
	w.heroi.correr_forcado = true
	passos(1)
	w.heroi.correr_forcado = false


func monstro_em(p: Vector2):
	var m = w.nascer_monstro("inimigo_cao_ossos", p)
	m.vida_max = 99999.0
	m.vida = 99999.0
	m.atordoa_t = 999.0
	m.recarga = 999.0
	m.emp = Vector2.ZERO
	return m


## O maior y de fatia (a ordem de desenho) entre os monstros da fila: todos atrás do herói <=> este < chave do herói.
func chave_fila(fila: Array) -> float:
	var maior := -INF
	for m in fila:
		maior = maxf(maior, float(m.chave_y))
	return maior


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var h = w.heroi
	var imp = w.combate.get("impulso")
	var c: Dictionary = w.combate.cfg.get("impulso", {})
	var faixa := int(c.get("ordem_px", 0))
	ok(faixa >= 16, "cfg.impulso.ordem_px cobre a fila sobrevoada (%d px)" % faixa)
	ok(imp != null and imp.has_method("ordem"), "o impulso calcula a ordem de desenho no ar (v2/impulso.gd > ordem)")

	# 1. fila logo abaixo do mecha: no chão na frente (com silhueta); no ar atrás (sem silhueta); pousado, na frente de novo
	var centro: Vector2 = w.limite_andavel.get_center()
	zerar(centro)
	var fila := []
	for dx in [-14.0, 0.0, 14.0]:
		fila.append(monstro_em(h.pos + Vector2(dx, 14.0)))
	passos(8)
	ok(chave_fila(fila) > chave_heroi(h), "no chão a fila mais para baixo é desenhada na frente (fila %.1f, herói %.1f)" % [chave_fila(fila), chave_heroi(h)])
	ok(w.oclusao.coberto(), "no chão a fila na frente acende a silhueta (pré-condição do teste)")
	apertar()
	passos(20)
	ok(h.imp_t > 0.0 and h.alt_px == int(c.get("alt_px", 5)), "voando, lá em cima (imp_t %.2f, alt %d)" % [h.imp_t, h.alt_px])
	ok(h.pos.distance_to(centro) < 2.0, "o mecha ficou no lugar (m_vel_mov 0): %s" % h.pos)
	ok(chave_fila(fila) < chave_heroi(h), "no ar a fila que ele sobrevoa fica ATRÁS dele (fila %.1f, herói %.1f)" % [chave_fila(fila), chave_heroi(h)])
	passos(12)
	ok(not w.oclusao.coberto(), "no ar a silhueta não acende pela fila sobrevoada")
	ok(h.sprite.position == h.sprite.position.round() and h.sprite.offset == h.sprite.offset.round(), "posição e offset do sprite em px inteiros")
	var desenho_y: float = h.sprite.position.y + h.sprite.offset.y - h._off_base.y
	ok(desenho_y == -float(h.alt_px), "o desenho continua subindo só alt_px (%.1f)" % desenho_y)
	ok(h.foguinho.no == null or h.foguinho.no.position.y == h.sprite.position.y, "o foguinho empata com o corpo no y-sort (sai por cima dele)")
	# 2. a descida: a ordem volta aos poucos, junto com o desenho
	var maior_queda := 0.0
	var ant := chave_heroi(h)
	var quadros_desc := 0
	while h.imp_t > 0.0 and quadros_desc < 400:
		passos(1)
		quadros_desc += 1
		var k := chave_heroi(h)
		maior_queda = maxf(maior_queda, ant - k)
		ant = k
	var s := float(c.get("subida", 0.15))
	var lim := ceilf(float(faixa) * PASSO / s) + 1.0
	ok(maior_queda <= lim, "a ordem desce aos poucos no pouso (maior salto %.1f px/quadro, limite %.1f)" % [maior_queda, lim])
	passos(12)
	ok(chave_heroi(h) == h.raiz.position.y and not h.raiz.y_sort_enabled, "pousado, a ordem é a dos pés")
	ok(chave_fila(fila) > chave_heroi(h), "pousado, a fila volta a ser desenhada na frente")
	ok(w.oclusao.coberto(), "pousado, a silhueta volta")

	# 3. árvore na frente (objeto grande) x objeto baixo
	var arvore = null
	var baixo = null
	var larg := float(c.get("larg_obstaculo", 22))
	for o in w.cenario.objetos:
		var lc := float(o.get("larg_col")) if o.get("larg_col") != null else 0.0  # get: no código antigo o campo não existe (o teste falha, não para)
		if arvore == null and lc > larg and o.alt > 100.0:
			arvore = o
		if baixo == null and lc > 0.0 and lc <= larg:
			baixo = o
	ok(arvore != null and baixo != null, "o mapa tem árvore e objeto baixo")
	if arvore != null:
		var pe_a: Vector2 = arvore.raiz.position
		zerar(pe_a + Vector2(-6.0, -10.0))  # 10 px acima do pé da árvore e cobrindo o tronco: no chão o mecha fica atrás dela
		ok(arvore in w.cenario.ativos, "a árvore está nos objetos visíveis")
		ok(chave_heroi(h) < pe_a.y, "no chão, atrás da árvore")
		apertar()
		passos(20)
		ok(h.imp_t > 0.0 and h.alt_px > 0, "voando perto da árvore")
		ok(chave_heroi(h) < pe_a.y, "no ar a árvore NA FRENTE continua na frente (ordem do chão): herói %.1f, pé da árvore %.1f" % [chave_heroi(h), pe_a.y])
		passos(200)
	if baixo != null:
		var pe_b: Vector2 = baixo.raiz.position
		zerar(pe_b + Vector2(0.0, -10.0))
		ok(chave_heroi(h) < pe_b.y, "no chão, atrás do objeto baixo")
		apertar()
		passos(20)
		ok(chave_heroi(h) > pe_b.y, "no ar o objeto baixo que ele sobrevoa fica atrás dele: herói %.1f, pé %.1f" % [chave_heroi(h), pe_b.y])
		passos(200)

	print("v2_impulso_ordem falhas=%d" % falhas)
	get_tree().quit()
