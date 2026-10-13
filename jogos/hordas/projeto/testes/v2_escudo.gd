extends Node
# Teste automático do ESCUDO, o tiro secundário do botão direito (v2/escudo.gd, heroi.gd, combate.gd, entrada.gd, dados/v2_secundario.json):
# dados e entrada (botão direito e LT = escudo, E e LB = ruptura, Q = ultimate reservado), bloqueio da frente (sim) e das costas e lados (não),
# bloqueio perfeito (empurra e atordoa quem bateu, sem gasto), bloqueio comum (gasta um pouco de fôlego), fôlego que gasta por segundo,
# velocidade de ~60%, sem correr nem golpear, cansaço que derruba o escudo, ruptura (E) que troca o escudo, contato de verdade com um monstro,
# o secundário por herói (dados > herois) e soltar que volta ao fôlego normal. O mundo anda em passos fixos de 1/60 s.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_escudo.tscn  (imprime "v2_escudo falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func perto(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Começa de novo: mapa sem monstros, herói parado e mortal, de cara para a direita (mouse 100 px à direita), escudo baixo.
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = false
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = null
	h.correr_forcado = null
	h.ruptura_forcada = false
	h.escudo_forcado = false
	h.m_vel_mov = 1.0
	h.vida = h.vida_max
	h.folego = h.folego_max
	h.cansado = false
	h.invenc = 0.0
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)


func monstro_a(dx: float, dy := 0.0):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, dy))
	m.atordoa_t = 0.0
	m.vida = 5000.0
	m.vida_max = 5000.0
	m.emp = Vector2.ZERO
	return m


## Ergue o escudo e anda o mínimo para ele estar de pé (escudo_t perto de zero).
func erguer(extra := 0) -> void:
	w.heroi.escudo_forcado = true
	passos(2 + extra)


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var h = w.heroi
	var esc = w.combate.escudo
	ok(esc != null and esc.no != null, "o combate tem o módulo do escudo")

	# 1. dados e entrada
	var d: Dictionary = Dados.json("v2_secundario")
	ok(str(d.get("_ajuda", "")) != "", "v2_secundario.json tem _ajuda")
	ok(d.has("padrao") and d.has("herois") and d.has("escudo"), "v2_secundario.json tem padrao, herois e escudo")
	var e: Dictionary = d.escudo
	ok(float(e.arco) == 120.0 and float(e.mov) == 0.6 and float(e.perfeito.janela) == 0.15, "arco 120, movimento 60% e janela perfeita de 0,15 s")
	ok(esc.ativo_para("hazaki") and esc.id_de("hazaki") == "escudo", "o herói de hoje tem o escudo como secundário")
	var tem_direito := false
	var tem_lt := false
	for ev in InputMap.action_get_events("escudo"):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT:
			tem_direito = true
		if ev is InputEventJoypadMotion and ev.axis == JOY_AXIS_TRIGGER_LEFT:
			tem_lt = true
	ok(tem_direito and tem_lt, "escudo: botão direito do mouse e gatilho esquerdo")
	var tem_e := false
	for ev in InputMap.action_get_events("ruptura"):
		if ev is InputEventKey and ev.physical_keycode == KEY_E:
			tem_e = true
	ok(tem_e, "ruptura: tecla E")
	var tem_q := false
	for ev in InputMap.action_get_events("ultimate"):
		if ev is InputEventKey and ev.physical_keycode == KEY_Q:
			tem_q = true
	ok(tem_q, "ultimate: tecla Q (reservada, sem efeito)")
	ok(
		ResourceLoader.exists("res://assets/audio/v2/impacto.wav") and ResourceLoader.exists("res://assets/audio/v2/ruptura_tique.wav"),
		"os sons do escudo existem"
	)

	# 2. erguer e baixar
	zerar()
	ok(not h.escudo_ativo, "sem segurar, o escudo está baixo")
	erguer()
	ok(h.escudo_ativo and h.estado == Heroi.Estado.LIVRE, "segurar ergue o escudo")
	h.escudo_forcado = false
	passos(2)
	ok(not h.escudo_ativo, "soltar baixa o escudo")

	# 3. a frente bloqueia: vida intacta, o golpe é consumido
	zerar()
	erguer()
	var m_f = monstro_a(12)
	var vida0: float = h.vida
	var r_f: bool = h.levar_dano(10.0, m_f.pos, m_f)
	ok(r_f and h.vida == vida0, "frente: o dano é barrado e consumido (vida %s de %s)" % [h.vida, vida0])
	ok(h.escudo_bloqueios == 1 and esc.bloqueios == 1, "frente: contou um bloqueio")
	ok(h.invenc == 0.0, "frente: o bloqueio não dá invencibilidade")

	# 4. as costas e os lados não
	zerar()
	erguer()
	var m_c = monstro_a(-12)
	var vida1: float = h.vida
	ok(h.levar_dano(10.0, m_c.pos, m_c) and h.vida < vida1, "costas: o dano entra (vida %s)" % h.vida)
	ok(h.escudo_bloqueios == 0, "costas: nenhum bloqueio contado")
	zerar()
	erguer()
	var m_l = monstro_a(0, 14)
	ok(h.levar_dano(10.0, m_l.pos, m_l) and h.vida < h.vida_max, "lado (90 graus): o dano entra")
	zerar()
	erguer()
	var m_d = monstro_a(10, 4)  # ~40 graus no chão: ainda dentro do arco de 120
	ok(h.levar_dano(10.0, m_d.pos, m_d) and h.vida == h.vida_max, "diagonal dentro do arco: bloqueia")
	# o arco vira com a mira
	zerar()
	w.mouse_forcado = h.centro() + Vector2(-100, 0)
	erguer(3)
	var m_e = monstro_a(-12)
	ok(h.levar_dano(10.0, m_e.pos, m_e) and h.vida == h.vida_max, "mirando para a esquerda, o monstro da esquerda é barrado")
	var m_e2 = monstro_a(12)
	ok(h.levar_dano(10.0, m_e2.pos, m_e2) and h.vida < h.vida_max, "e o da direita (agora as costas) acerta")
	# ataque de área sem monstro (aviso, chefe): vale a mesma conta
	zerar()
	erguer()
	ok(h.levar_dano(8.0, h.pos + Vector2(30, 0)) and h.vida == h.vida_max, "ataque de área vindo da frente: barrado")
	ok(h.levar_dano(8.0, h.pos + Vector2(-30, 0)) and h.vida < h.vida_max, "ataque de área vindo de trás: entra")
	# sem o escudo erguido, nada é barrado
	zerar()
	var m_s = monstro_a(12)
	ok(h.levar_dano(10.0, m_s.pos, m_s) and h.vida < h.vida_max and h.escudo_bloqueios == 0, "escudo baixo: o dano entra")

	# 5. bloqueio perfeito: empurra e atordoa quem bateu, sem gasto de fôlego
	zerar()
	erguer()
	ok(h.escudo_t <= float(e.perfeito.janela), "recém erguido: dentro da janela perfeita (%s s)" % h.escudo_t)
	var m_p = monstro_a(14)
	var fol0: float = h.folego
	h.levar_dano(10.0, m_p.pos, m_p)
	ok(esc.ultimo.get("perfeito", false) == true and h.escudo_perfeitos == 1, "perfeito: marcado como perfeito")
	ok(m_p.atordoa_t >= float(e.perfeito.atordoa) * 0.99, "perfeito: o monstro fica atordoado (%s s)" % m_p.atordoa_t)
	ok(m_p.emp.x > 100.0, "perfeito: o monstro é empurrado para longe (emp.x %s)" % m_p.emp.x)
	ok(h.folego >= fol0 - 0.001, "perfeito: não gasta fôlego")
	ok(h.vida == h.vida_max, "perfeito: nenhum dano")
	# comum: depois da janela. Gasta um pouco de fôlego e empurra de leve, sem atordoar
	zerar()
	erguer(30)  # 0,5 s depois
	ok(h.escudo_t > float(e.perfeito.janela), "depois de 0,5 s a janela perfeita acabou")
	var m_n = monstro_a(14)
	var fol1: float = h.folego
	h.levar_dano(10.0, m_n.pos, m_n)
	ok(esc.ultimo.get("perfeito", true) == false and h.escudo_perfeitos == 0, "comum: não é perfeito")
	ok(m_n.atordoa_t == 0.0 and m_n.emp.x > 0.0, "comum: empurra de leve e não atordoa")
	ok(h.folego < fol1 - float(e.gasto_golpe) * 0.9, "comum: cada golpe barrado gasta fôlego (%s para %s)" % [fol1, h.folego])
	# chefe não é atordoado (como em qualquer golpe)
	zerar()
	erguer()
	var m_b = monstro_a(14)
	m_b.stun_mult = 0.0
	m_b.emp_mult = 0.05
	h.levar_dano(10.0, m_b.pos, m_b)
	ok(m_b.atordoa_t == 0.0, "o monstro que não toma atordoamento (chefe) continua sem")

	# 6. o fôlego gasta por segundo
	zerar()
	erguer()
	var f0: float = h.folego
	passos(60)
	var gasto: float = f0 - h.folego
	ok(perto(gasto, float(e.gasto), 0.2), "segurar 1 s gasta ~%s de fôlego (gastou %s)" % [e.gasto, gasto])
	# e soltar volta ao fôlego normal: depois do atraso o fôlego sobe
	h.escudo_forcado = false
	passos(2)
	var f1: float = h.folego
	passos(150)
	ok(h.folego > f1 + 0.3, "soltar: o fôlego volta a subir (%s para %s)" % [f1, h.folego])
	ok(not h.escudo_ativo, "soltar: escudo baixo")

	# 7. velocidade de ~60%: anda com o escudo e sem ele, mesma distância de tempo
	zerar()
	h.entrada_forcada = Vector2(-1, 0)  # para a esquerda, mirando para a direita (o escudo não vira para onde anda)
	var p0: Vector2 = h.pos
	passos(30)
	var livre: float = (h.pos - p0).length()
	zerar()
	h.entrada_forcada = Vector2(-1, 0)
	h.escudo_forcado = true
	h.correr_forcado = true  # nem correndo
	p0 = h.pos
	passos(30)
	var com: float = (h.pos - p0).length()
	ok(livre > 20.0 and perto(com / livre, 0.6, 0.08), "com o escudo anda a ~60%% (%s px contra %s px)" % [com, livre])
	ok(h.dir_olhar.x > 0.9, "o escudo continua virado para a mira enquanto anda para trás (dir %s)" % h.dir_olhar)
	ok(not h.correndo, "com o escudo o herói não corre")

	# 8. não golpeia com o escudo
	zerar()
	erguer()
	h.ataque_forcado = true
	h.atacar()
	passos(10)
	ok(h.estado == Heroi.Estado.LIVRE and h.escudo_ativo, "com o escudo erguido o clique de golpe não golpeia")
	h.ataque_forcado = null

	# 9. fôlego zerado derruba o escudo e deixa cansado
	zerar()
	h.folego = 0.5
	erguer()
	passos(60)
	ok(h.cansado and not h.escudo_ativo, "o fôlego acabou: cansado e o escudo caiu")
	passos(10)
	ok(not h.escudo_ativo, "cansado, segurar o botão não ergue o escudo")

	# 10. a ruptura (E) tira o escudo e carrega
	zerar()
	erguer()
	h.ruptura_forcada = true
	h.ruptura()
	passos(3)
	ok(h.estado == Heroi.Estado.CARGA and not h.escudo_ativo, "a ruptura (E) com o escudo erguido: carrega e baixa o escudo")
	h.ruptura_forcada = false
	passos(2)
	h.cancelar_ruptura(false)

	# 11. contato de verdade: um monstro encostado na frente não tira vida e é consumido; atrás tira
	zerar()
	erguer()
	var m_x = monstro_a(11)
	m_x.dano = 12.0
	m_x.recarga = 0.0
	passos(40)
	ok(h.vida == h.vida_max and h.escudo_bloqueios >= 1, "contato pela frente: sem dano, bloqueou %d vez(es)" % h.escudo_bloqueios)
	ok(m_x.recarga > 0.0 or m_x.atordoa_t > 0.0 or (m_x.pos - h.pos).length() > 14.0, "contato pela frente: o golpe do monstro foi consumido")
	zerar()
	erguer()
	var m_y = monstro_a(-9)
	m_y.dano = 12.0
	m_y.recarga = 0.0
	m_y.atordoa_t = 0.0
	passos(12)
	ok(h.vida < h.vida_max, "contato por trás: o dano entra (vida %s)" % h.vida)

	# 12. o secundário por herói é dado: outro id no mapa e o botão direito não ergue o escudo
	zerar()
	var chave0: String = h.chave
	esc.herois["teste_outro"] = "outro_secundario"
	ok(
		esc.id_de("teste_outro") == "outro_secundario" and not esc.ativo_para("teste_outro") and esc.ativo_para(chave0),
		"id_de lê dados > herois; os outros ficam com o padrão"
	)
	h.chave = "teste_outro"
	erguer()
	ok(not h.escudo_ativo, "herói com outro secundário: o escudo não ergue")
	h.chave = chave0
	esc.herois.erase("teste_outro")
	passos(3)
	ok(h.escudo_ativo, "voltando ao herói do escudo, ergue de novo")

	# 13. morte, pausa e resultado derrubam o escudo
	zerar()
	erguer()
	h.vida = 1.0
	var m_k = monstro_a(-10)
	h.levar_dano(50.0, m_k.pos, m_k)
	ok(h.estado == Heroi.Estado.MORTO and not h.escudo_ativo, "morrer derruba o escudo")

	# 14. o visual existe e o painel de status lê os números
	zerar()
	erguer()
	w.combate.efeitos(PASSO)
	ok(esc.resumo().arco == 120.0 and esc.resumo().mov == 0.6, "resumo(): arco e movimento")
	zerar()
	ok(not h.escudo_ativo and esc.bloqueios == 0, "reiniciar zera o escudo e os contadores")

	print("v2_escudo falhas=%d" % falhas)
	get_tree().quit()
