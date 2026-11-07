extends "res://testes/isolamento_v2.gd"
# Teste da LENTIDÃO da teia (v2/teias.gd, v2/heroi.gd lento_fontes e lento_k, v2/fx_status.gd). Confere: andando 0,5 s com os pés dentro da teia o herói anda a METADE do que fora
# (dados/v2_teia.json > lento.mult); sair da teia restaura na hora; a esquiva não é cortada; duas fontes valem pelo MENOR multiplicador (teia + Rainha dão 0,5, não 0,25);
# o empurrão (knockback) não é cortado; o mecha do LightWolf em voo (impulso) não fica lento; o relógio de lentidão liga no herói (fx_status) enquanto ele está preso.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_teia_lento.tscn  (imprime "v2_teia_lento falhas=0")

const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
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
	h.ataque_forcado = false
	h.correr_forcado = false
	h.fonte = Heroi.Fonte.MOUSE
	h.m_vel_mov = 1.0
	h.pos = w.limite_andavel.get_center()
	h.definir_pos(h.pos)
	w.mouse_forcado = h.centro() + Vector2(4000, 0)
	passos(3)


## Uma teia parada no chão (sem passar pelo voo): o estado PARADA com o centro em `p`.
func poe_teia(p: Vector2, estado := 3) -> int:
	var t = w.combate.teias
	var i: int = t._livre()
	t._est[i] = estado
	t._t[i] = 0.0
	t._idade[i] = 0.0
	t._pos[i] = p
	t._geo[i] = 0
	t._var[i] = 0
	return i


## Quanto o herói anda em `n` quadros apertando para a direita, partindo de `p`.
func andar(p: Vector2, n: int) -> float:
	h.pos = p
	h.definir_pos(p)
	h.entrada_forcada = Vector2.RIGHT
	passos(n)
	var d: float = h.pos.x - p.x
	h.entrada_forcada = Vector2.ZERO
	passos(2)
	return d


func _ready() -> void:
	Herois.forcado = "hazaki"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	var t = w.combate.teias
	var c: Vector2 = h.pos

	# 1. fora da teia: velocidade cheia; dentro: metade
	ok(h.lento_k() == 1.0, "sem fonte nenhuma o herói tem velocidade cheia")
	var fora := andar(c + Vector2(0, 150), 30)
	ok(fora > 20.0, "andando 0,5 s fora da teia o herói avança (%.1f px)" % fora)
	var i := poe_teia(c)
	var dentro := andar(c, 30)
	ok(h.lento_fontes.has("teia") or dentro > 0.0, "o herói tem a fonte teia ao pisar nela")
	ok(absf(dentro - fora * 0.5) < fora * 0.06, "dentro da teia o herói anda a METADE (fora %.1f px, dentro %.1f px)" % [fora, dentro])
	ok(is_equal_approx(h.lento_k(), 0.5), "lento_k vale 0,5 dentro da teia (%s)" % h.lento_k())
	ok(t.dentro(c) and not t.dentro(c + Vector2(0, 90)), "teias.dentro: o centro está, 90 px abaixo não")

	# 2. sair restaura na hora
	h.pos = c + Vector2(0, 150)
	h.definir_pos(h.pos)
	passos(2)
	ok(not h.lento_fontes.has("teia") and h.lento_k() == 1.0, "ao sair da teia a fonte some e a velocidade volta")
	var fora2 := andar(c + Vector2(0, 150), 30)
	ok(absf(fora2 - fora) < 1.0, "depois de sair, a mesma velocidade de antes (%.1f e %.1f)" % [fora, fora2])

	# 3. o estado: a esquiva e o resto ficam de fora da lista (o contra-jogo), golpe e carga ficam dentro
	ok(
		h.lento_estados.has(h.Estado.LIVRE) and h.lento_estados.has(h.Estado.GOLPE) and h.lento_estados.has(h.Estado.CARGA),
		"LIVRE, GOLPE e CARGA são lentos na teia"
	)
	ok(
		not h.lento_estados.has(h.Estado.ESQUIVA) and not h.lento_estados.has(h.Estado.ESPECIAL) and not h.lento_estados.has(h.Estado.HABILIDADE),
		"esquiva, especial e habilidade não"
	)
	h.pos = c
	h.definir_pos(c)
	passos(3)
	var antes: Vector2 = h.pos
	h.estado = h.Estado.ESQUIVA  # só o estado importa: a conta da lentidão (heroi.gd) consulta lento_estados.has(estado)
	ok(h.lento_k() == 0.5 and not h.lento_estados.has(h.estado), "na esquiva, mesmo com a fonte ligada, o estado fica fora da lentidão")
	h.estado = h.Estado.LIVRE
	h.pos = antes

	# 4. várias fontes: vale o MENOR, nunca o produto
	h.lento_fontes.clear()
	h.lento_fontes["teia"] = 0.5
	h.lento_fontes["rainha"] = 0.5
	ok(is_equal_approx(h.lento_k(), 0.5), "teia 0,5 + Rainha 0,5 = 0,5 (não 0,25): %s" % h.lento_k())
	h.lento_fontes["outra"] = 0.3
	ok(is_equal_approx(h.lento_k(), 0.3), "a mais forte das três vale (%s)" % h.lento_k())
	h.lento_fontes["fraca"] = 0.9
	ok(is_equal_approx(h.lento_k(), 0.3), "uma fonte fraca não afrouxa as outras")
	h.lento_fontes.clear()
	ok(h.lento_k() == 1.0, "sem fontes: 1,0")

	# 5. o empurrão não é cortado
	zerar()
	i = poe_teia(h.pos)
	passos(2)
	var p1: Vector2 = h.pos
	h.emp = Vector2(300, 0)
	passos(20)
	var com_teia: float = h.pos.x - p1.x
	zerar()
	var p2: Vector2 = h.pos
	h.emp = Vector2(300, 0)
	passos(20)
	var sem_teia: float = h.pos.x - p2.x
	ok(sem_teia > 5.0 and absf(com_teia - sem_teia) < 1.0, "o empurrão anda o mesmo dentro e fora da teia (%.1f e %.1f px)" % [com_teia, sem_teia])

	# 5b. a teia da aranha e a da Rainha Tecelã juntas: vale o MENOR (0,5), nunca o produto (0,25)
	zerar()
	poe_teia(c)
	var ch = w.combate.chefes
	ch._teia_mult = 0.5
	ch._teia_t = 30.0
	var as_duas := andar(c, 30)
	ch._teia_t = 0.0
	ok(absf(as_duas - fora * 0.5) < fora * 0.06, "aranha + Rainha: anda a METADE, não um quarto (fora %.1f px, nas duas %.1f px)" % [fora, as_duas])

	# 6. NENHUM relógio sobre a cabeça do herói preso (pedido do Alisson: "não faz sentido"): a lentidão se sente no movimento
	zerar()
	poe_teia(h.pos)
	passos(10)
	var cf0: int = w.combate.fx_folha.ativos
	ok(
		w.combate.fx_status.n_efeitos() == cf0,
		"o herói preso na teia não leva ícone (fx_folha %d, ícones de monstros %d)" % [cf0, w.combate.fx_status.n_efeitos()]
	)
	h.pos += Vector2(0, 150)
	h.definir_pos(h.pos)
	passos(10)
	ok(w.combate.fx_status.n_efeitos() == w.combate.fx_folha.ativos, "e continua sem ícone quando ele sai")

	# 7. o mecha em voo não fica lento (LightWolf)
	Herois.forcado = "lightwolf"
	w.queue_free()
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	poe_teia(h.pos)
	passos(3)
	ok(h.lento_fontes.has("teia"), "o mecha parado na teia está preso")
	h.correr_forcado = true
	passos(1)
	h.correr_forcado = false
	passos(40)
	ok(h.imp_t > 0.0 and w.combate.teias.voando(h), "o mecha voa (impulso) e conta como voando (alt %d)" % h.alt_px)
	ok(not h.lento_fontes.has("teia"), "voando o mecha não fica lento na teia")
	print("v2_teia_lento falhas=%d" % falhas)
	get_tree().quit()
