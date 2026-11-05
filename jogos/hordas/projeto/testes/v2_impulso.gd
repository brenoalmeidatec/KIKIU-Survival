extends "res://testes/isolamento_v2.gd"
# Teste automático do IMPULSO do mecha do LightWolf (o Shift dele; v2/impulso.gd, heroi.gd, colisao.gd, mundo.gd, hud_habilidades.gd, adagas.gd, estalos_visual.gd,
# dados/v2_herois.json > lightwolf > cfg > impulso). Confere: só o mecha tem (Hazaki e Lobo não, e para eles o Shift continua correndo); o aperto voa 3 s na
# direção do movimento ou da mira, a uns 220 px/s, soltar não para e a recarga de 5 s começa no fim (aperto na recarga é negado); o mecha não corre nem gasta
# fôlego; durante o voo o canhão atira, a Matriz não ergue e a esquiva não sai; o desenho sobe 14 px inteiros (boiando 1 px no topo; a sombra e a posição ficam no chão) e a boca
# do cano sobe junto; objeto baixo (largura <= 22 px) não segura o voo, objeto grande segura, e andando o baixo segura; o voo acabado em cima de um objeto baixo
# sai sem pulo; cada monstro atravessado leva dano a cada 0,5 s, nunca morre (para em 1 de vida, elite também), não é empurrado e não afasta o mecha;
# a HUD mostra o card do Shift só para o mecha (pronto, voando, recarga) e o nó não encosta na barra de XP.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_impulso.tscn  (imprime "v2_impulso falhas=0")

const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Colisao := preload("res://v2/colisao.gd")
const HudHabilidades := preload("res://v2/hud_habilidades.gd")
const PASSO := 1.0 / 60.0

var falhas := 0
var x0 := 0.0  # onde cada parte começa (zerar)
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Partida limpa: sem monstros, sem cenário sólido, mecha parado e imortal, mirando para a direita, nada apertado.
func zerar() -> void:
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
	h.ruptura_forcada = false
	h.m_vel_mov = 1.0
	h.m_dano = 1.0
	h.fonte = Heroi.Fonte.MOUSE
	x0 = w.limite_andavel.position.x + 100.0  # longe da borda da direita: o voo de 3 s anda ~660 px
	h.pos = Vector2(x0, w.limite_andavel.get_center().y)
	h.definir_pos(h.pos)
	w.mouse_forcado = h.centro() + Vector2(4000, 0)  # a mira longe à direita: o voo sem tecla vai para ela
	passos(3)


## Um aperto do Shift (um quadro apertado, depois solto).
func apertar() -> void:
	w.heroi.correr_forcado = true
	passos(1)
	w.heroi.correr_forcado = false


func monstro_em(p: Vector2, vida: float):
	var m = w.nascer_monstro("inimigo_cao_ossos", p)
	m.vida_max = maxf(vida, 100.0)
	m.vida = vida
	m.atordoa_t = 999.0  # parado: o teste olha só o que o impulso faz com ele
	m.recarga = 999.0
	m.emp = Vector2.ZERO
	return m


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var h = w.heroi
	var imp = w.combate.get("impulso")  # get: no código sem impulso o teste chega às asserções (e falha nelas) em vez de parar no parse
	var c: Dictionary = w.combate.cfg.get("impulso", {})

	# 1. dados e quem tem
	ok(not c.is_empty(), "o mecha tem o bloco cfg.impulso")
	ok(float(c.get("dur", 0)) == 3.0 and float(c.get("recarga", 0)) == 5.0, "voo de 3 s e recarga de 5 s (pedido do Alisson)")
	ok(int(c.get("larg_obstaculo", 0)) == 22 and int(c.get("alt_px", 0)) == 14, "objeto baixo até 22 px e o desenho sobe 14 px")
	ok(not Herois.cfg_para(Dados.json("v2_combate"), "lightwolf_lobo").has("impulso"), "o Lobo não tem impulso")
	for id in ["hazaki", "nicao", "lucas"]:
		ok(not Herois.cfg_para(Dados.json("v2_combate"), id).has("impulso"), "%s não tem impulso" % id)
	ok(imp != null, "o combate monta o impulso (v2/impulso.gd)")
	if falhas > 0:  # sem o impulso o resto não tem o que medir: fecha aqui com as falhas contadas
		print("v2_impulso falhas=%d" % falhas)
		get_tree().quit()
		return
	zerar()
	ok(h.imp_nome == "IMPULSO", "o mecha publica o impulso para a HUD (%s)" % h.imp_nome)

	# 2. o voo: aperto, direção da mira, 3 s, soltar não para, sem correr nem gastar fôlego
	var f0: float = h.folego
	var p0: Vector2 = h.pos
	apertar()
	ok(h.imp_t > 0.0 and imp.voos == 1, "o aperto do Shift dispara o voo")
	ok(not h.correndo, "o mecha não corre: o Shift dele é o impulso")
	passos(60)
	ok(h.imp_t > 1.5 and h.imp_t < 2.0, "soltar o Shift não para o voo (falta %.2f s)" % h.imp_t)
	var andou: float = h.pos.x - p0.x
	ok(andou > 200.0 and andou < 240.0, "em 1 s voa ~220 px na direção da mira (%.1f)" % andou)
	ok(absf(h.pos.y - p0.y) < 1.0, "sem tecla de andar o voo segue a mira (direita): dy %.2f" % (h.pos.y - p0.y))
	# onde o corpo é DESENHADO em relação aos pés (posição + offset do sprite): a posição do sprite agora também leva o y da ordem de desenho no ar
	var desenho_y: float = h.sprite.position.y + h.sprite.offset.y - h._off_base.y
	ok(
		absi(h.alt_px - 14) <= 1 and desenho_y == -float(h.alt_px),
		"voando o desenho sobe ~14 px inteiros, com 1 px de flutuação (alt %d, desenho y %.1f)" % [h.alt_px, desenho_y]
	)
	ok(is_equal_approx(fmod(desenho_y, 1.0), 0.0) and h.sprite.position == h.sprite.position.round(), "a subida é em px inteiros")
	ok(h.folego >= f0, "o voo não gasta fôlego (%.2f -> %.2f)" % [f0, h.folego])
	# a direção vira para o movimento (giro limitado: não vira na hora)
	h.entrada_forcada = Vector2.DOWN
	passos(1)
	ok(h.imp_dir.y > 0.0 and h.imp_dir.x > 0.5, "a direção vira para o movimento aos poucos (%s)" % h.imp_dir)
	passos(30)
	ok(h.imp_dir.y > 0.95, "depois de 0,5 s o voo já segue o movimento (%s)" % h.imp_dir)
	h.entrada_forcada = Vector2.ZERO
	var q := 0
	while h.imp_t > 0.0 and q < 400:
		passos(1)
		q += 1
	ok(q == 180 - 92 or q == 180 - 91, "o voo acaba sozinho em 3 s (%d quadros depois dos 92 já passados)" % q)
	passos(1)
	ok(h.imp_t == 0.0 and h.alt_px == 0, "o desenho desce no fim do voo")
	ok(h.imp_recarga > 4.0 and h.imp_recarga <= 5.0, "a recarga de 5 s começa quando o voo acaba (%.2f)" % h.imp_recarga)
	var x_parado: float = h.pos.x
	passos(10)
	ok(absf(h.pos.x - x_parado) < 0.01, "sem voo e sem tecla o mecha fica parado")
	apertar()
	ok(h.imp_t == 0.0 and h.imp_nega_t > 0.0, "aperto na recarga é negado")
	passos(300)
	ok(h.imp_recarga == 0.0, "a recarga acaba")
	apertar()
	ok(h.imp_t > 0.0, "pronto de novo, o aperto voa")
	# segurar o Shift não repete o voo (é por aperto)
	zerar()
	h.correr_forcado = true
	passos(200)
	passos(320)
	ok(imp.voos == 1, "segurar o Shift não dispara outro voo depois da recarga (%d voos)" % imp.voos)
	h.correr_forcado = false

	# 3. canhão sim, Matriz e esquiva não
	zerar()
	apertar()
	var golpes0: int = h.golpes
	h.ataque_forcado = true
	h.escudo_forcado = true
	passos(40)
	ok(h.golpes > golpes0, "o canhão atira durante o voo (%d disparos)" % (h.golpes - golpes0))
	ok(not h.escudo_ativo, "a Matriz não ergue durante o voo")
	h.ataque_forcado = false
	h.esq_pedido = 1.0
	passos(1)
	ok(h.estado != h.Estado.ESQUIVA and h.imp_t > 0.0, "a esquiva não sai durante o voo")
	h.esq_pedido = 0.0
	passos(200)
	ok(h.imp_t == 0.0, "o voo acabou")
	passos(30)
	ok(h.escudo_ativo, "depois do voo a Matriz volta a erguer")
	h.escudo_forcado = false
	passos(5)
	# a Matriz erguida cai no aperto
	zerar()
	h.escudo_forcado = true
	passos(10)
	ok(h.escudo_ativo, "Matriz erguida")
	apertar()
	ok(h.imp_t > 0.0 and not h.escudo_ativo, "o aperto do impulso derruba a Matriz e voa")
	h.escudo_forcado = false

	# 4. a boca do cano sobe com o desenho
	zerar()
	var est = w.combate.adagas.estalos
	h.ataque_forcado = true
	passos(30)
	var boca_chao := Vector2.INF
	for p in est.boca_pos:
		if p.is_finite():
			boca_chao = p - h.pr
	apertar()
	passos(20)
	var boca_voo := Vector2.INF
	for p in est.boca_pos:
		if p.is_finite():
			boca_voo = p - h.pr
	h.ataque_forcado = false
	if w.combate.adagas._fator_impactos() >= 0.5:
		ok(boca_chao.is_finite() and boca_voo.is_finite(), "o clarão do cano aparece no chão e no voo")
		ok(
			boca_voo.is_finite() and boca_chao.is_finite() and is_equal_approx(boca_voo.y - boca_chao.y, -float(h.alt_px)),
			"o clarão sobe alt_px com o mecha (%s -> %s)" % [boca_chao, boca_voo]
		)

	# 5. obstáculos: baixo passa voando, grande segura; andando o baixo segura
	# as formas do cenário (prototipos/objetos/cenario.json) com o centro na linha do herói: de frente, o corpo para em vez de deslizar em volta
	var baixo := [{"tipo": "elipse", "centro": [0.0, 0.0], "raio": [5.0, 2.5]}]  # as "pedras" (10 px)
	var lapide := [{"tipo": "elipse", "centro": [0.0, 0.0], "raio": [10.5, 5.2]}]  # a lápide (21 px)
	var grande := [{"tipo": "elipse", "centro": [0.0, 0.0], "raio": [30.0, 15.0]}]  # o muro (60 px)
	var col_s = load("res://v2/colisao.gd")  # carregado e sem tipo: a chamada resolve na hora de rodar (no código sem largura_objeto o teste falha na asserção, não no parse)
	ok(col_s.call("largura_objeto", baixo) == 10.0 and col_s.call("largura_objeto", grande) == 60.0, "a largura do objeto é a caixa em x das formas")
	for caso in [["pedras", baixo, true], ["lápide", lapide, true], ["muro", grande, false]]:
		zerar()
		Colisao.adicionar_objeto(h.pos + Vector2(80, 0), caso[1])
		apertar()
		passos(60)
		var passou: bool = h.pos.x > x0 + 120.0
		ok(passou == caso[2], "voando, %s %s" % [caso[0], "não segura" if caso[2] else "segura (x %.1f)" % h.pos.x])
	zerar()
	Colisao.adicionar_objeto(h.pos + Vector2(60, 0), baixo)
	h.entrada_forcada = Vector2.RIGHT
	passos(120)
	h.entrada_forcada = Vector2.ZERO
	ok(h.pos.x < x0 + 60.0, "andando, as pedras seguram o mecha (x %.1f)" % h.pos.x)
	# o voo acaba em cima de um objeto baixo: sai sem pulo e depois volta a colidir
	zerar()
	Colisao.adicionar_objeto(h.pos + Vector2(220.0 * 3.0 - 3.0, 0), lapide)
	apertar()
	var maior_salto := 0.0
	var antes: Vector2 = h.pos
	for i in 260:
		passos(1)
		if h.imp_t <= 0.0:
			maior_salto = maxf(maior_salto, (h.pos - antes).length())
		antes = h.pos
	ok(maior_salto < 1.0, "o voo que acaba em cima de uma lápide não dá pulo de empurrão (%.2f px)" % maior_salto)
	h.entrada_forcada = Vector2.LEFT
	passos(60)
	h.entrada_forcada = Vector2.ZERO
	ok(not h._imp_saindo, "andando para fora, o mecha sai de cima e a lápide volta a ser sólida")

	# 6. por cima dos monstros: dano sem matar, com intervalo, sem empurrar
	zerar()
	var fila := []
	for i in 6:
		fila.append(monstro_em(h.pos + Vector2(40.0 + 50.0 * float(i), 0.0), 100.0))
	var fraco = monstro_em(h.pos + Vector2(380, 0), 5.0)
	var quase = monstro_em(h.pos + Vector2(420, 0), 1.0)
	var pos_antes := []
	for m in fila:
		pos_antes.append(m.pos)
	var dano_q: float = float(c.get("dano", 0)) * h.m_dano
	apertar()
	passos(120)
	var feridos := 0
	for m in fila:
		if m.vida < 100.0:
			feridos += 1
	ok(feridos == 6, "os 6 monstros atravessados levam dano (%d)" % feridos)
	ok(fila[0].vida == 100.0 - dano_q, "um toque por monstro na passagem (%.1f de vida)" % fila[0].vida)
	var empurrados := 0
	for i in fila.size():
		if (fila[i].pos - pos_antes[i]).length() > 0.5 or fila[i].emp.length() > 0.5:
			empurrados += 1
	ok(empurrados == 0, "ninguém é empurrado nem afastado pelo mecha voando (%d)" % empurrados)
	ok(
		fraco.vivo and not fraco.morrendo and fraco.vida == 1.0,
		"o de 5 de vida para em 1 (%.1f; mecha em x %.1f, ele em %.1f, vivo %s)" % [fraco.vida, h.pos.x, fraco.pos.x, fraco.vivo]
	)
	ok(quase.vivo and quase.vida == 1.0, "o de 1 de vida não é ferido")
	ok(imp.poupados >= 1, "o toque no de 1 de vida é poupado")
	ok(float(w.combate.dano_por_fonte.get("impulso", 0.0)) > 0.0, "o dano conta como fonte impulso na tela de fim")
	# intervalo por monstro: um monstro grudado no mecha o voo inteiro leva um toque a cada 0,5 s
	zerar()
	var grudado = monstro_em(h.pos, 10000.0)
	grudado.vida_max = 10000.0
	apertar()
	for i in 200:
		grudado.pos = h.pos
		grudado.definir_pos(h.pos)
		passos(1)
	var toques := roundi((10000.0 - grudado.vida) / dano_q)
	ok(toques >= 6 and toques <= 7, "grudado no mecha 3 s: um toque a cada 0,5 s (%d)" % toques)
	# muitos toques nunca matam
	zerar()
	var teimoso = monstro_em(h.pos, 30.0)
	apertar()
	for i in 200:
		teimoso.pos = h.pos
		teimoso.definir_pos(h.pos)
		passos(1)
	ok(teimoso.vivo and teimoso.vida == 1.0, "toques seguidos param em 1 de vida (%.1f)" % teimoso.vida)
	# o corpo do mecha voando não afasta quem está nele (andando, afasta)
	zerar()
	var dentro = monstro_em(h.pos + Vector2(2, 0), 10000.0)
	dentro.atordoa_t = 0.0
	dentro.recarga = 999.0
	apertar()
	dentro.pos = h.pos + Vector2(2, 0)
	dentro.definir_pos(dentro.pos)
	var d0: float = (dentro.pos - h.pos).length()
	w.avancar(PASSO)
	ok((dentro.pos - h.pos).length() < d0 + 10.0, "voando, o corpo do mecha não empurra o monstro para fora")
	# o anel de cerco da IA segue com o raio real do mecha: a roda não fecha em cima dele e ele não pousa dentro dela
	ok(is_equal_approx(dentro.heroi_raio_atual, float(h.raio)), "voando, o cerco da IA usa o raio real (%.1f, raio %.1f)" % [dentro.heroi_raio_atual, h.raio])

	# 7. Lobo e outros heróis: o Shift continua correndo
	zerar()
	apertar()
	w.combate.mecha.virar_lobo(h, 20.0)
	passos(1)
	ok(h.forma_lobo and h.imp_t == 0.0 and h.imp_nome == "", "virar Lobo encerra o voo e esconde o impulso")
	h.entrada_forcada = Vector2.RIGHT
	h.correr_forcado = true
	passos(5)
	ok(h.correndo, "o Lobo corre com o Shift")
	h.correr_forcado = false
	h.entrada_forcada = Vector2.ZERO

	# 8. HUD: o card do Shift só para o mecha
	zerar()
	var slots = HudHabilidades.new()
	slots.sincronizar(h)
	ok(slots.imp_disponivel and slots.imp_pronta and not slots.imp_ativo, "HUD: o mecha tem o card do impulso, pronto")
	apertar()
	slots.sincronizar(h)
	ok(slots.imp_ativo and slots.imp_voo_px > 0 and slots.imp_recarga_px == 0, "HUD: voando, a barrinha do voo")
	passos(200)
	slots.sincronizar(h)
	ok(not slots.imp_pronta and slots.imp_recarga_px > 0 and slots.imp_recarga_s > 0.0, "HUD: na recarga, a cortina e os segundos")
	ok(slots.arte_imp() != null and slots.arte_imp().get_size() == Vector2(32, 32), "HUD: o ícone próprio do impulso (32x32)")
	var hud_s = load("res://v2/hud_habilidades.gd")  # carregado e sem tipo, como col_s
	var k_hud: Dictionary = hud_s.get_script_constant_map()
	ok(k_hud.get("X_E", -1.0) == k_hud.get("TAM_IMP", Vector2.ZERO).x + k_hud.get("ESPACO_CARD", 0.0), "HUD: o card E começa depois do card do impulso")
	w.combate.mecha.virar_lobo(h, 20.0)
	passos(1)
	slots.sincronizar(h)
	ok(not slots.imp_disponivel, "HUD: o Lobo não mostra o impulso")
	slots.free()
	var img: Image = load("res://assets/v2/habilidade_shift/lightwolf.png").get_image()
	var alfa_ok := true
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y).a
			if a > 0.0 and a < 1.0:
				alfa_ok = false
	ok(alfa_ok, "o ícone tem alfa 0 ou 1")

	print("v2_impulso falhas=%d" % falhas)
	get_tree().quit()
