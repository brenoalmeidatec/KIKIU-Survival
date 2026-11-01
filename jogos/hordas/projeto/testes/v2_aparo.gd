extends "res://testes/isolamento_v2.gd"
# Teste automático do APARO e do contrato do secundário (DEF-2: v2/escudo.gd, v2/heroi.gd, v2/hud_habilidades.gd, v2/ruptura.gd, dados/v2_secundario.json):
# o secundário é dado por herói (Nick = escudo, Hazaki e o padrão = aparo, LightWolf = nenhum); o aparo é por APERTO: abre uma janela de 0,30 s com arco de 140 graus,
# todo golpe de dentro do arco na janela vira bloqueio perfeito (empurra, atordoa, sem barra de defesa) e abre o contragolpe da katana; janela sem golpe é erro
# (recuperação parado e recarga longa); o herói publica os campos sec_* que o slot S da HUD lê. O mundo anda em passos fixos de 1/60 s.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_aparo.tscn  (imprime "v2_aparo falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const ACHATA := 0.62
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


## Passos do mundo com o relógio de parede do visual (o arco do aparo se desenha em `combate.efeitos`).
func fx_passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)
		w.combate.efeitos(PASSO)


## Começa de novo: mapa sem monstros, herói parado e mortal, de cara para a direita (mouse 100 px à direita), botão do secundário solto.
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
	h.aparo_recarga = 0.0
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


## Aperta o botão do secundário (a borda de subida abre o aparo) e solta no quadro seguinte.
func apertar() -> void:
	w.heroi.escudo_forcado = true
	passos(1)
	w.heroi.escudo_forcado = false


## Um ponto no chão a `graus` da mira (para a direita), `dist` px de distância (a conta do arco é no chão: y dividido pela achatada).
func ponto(graus: float, dist := 50.0) -> Vector2:
	var a := deg_to_rad(graus)
	return w.heroi.pos + Vector2(cos(a), sin(a) * ACHATA) * dist


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var h = w.heroi
	var esc = w.combate.escudo
	var a: Dictionary = Dados.json("v2_secundario").aparo
	var ruptura = w.combate.ruptura

	# 1. dados: quem tem o quê
	var d: Dictionary = Dados.json("v2_secundario")
	ok(str(d.padrao) == "aparo", "o padrão passa a ser o aparo")
	ok(esc.id_de("nicao") == "escudo" and esc.ativo_para("nicao") and not esc.aparo_para("nicao"), "o Nick tem o escudo")
	ok(esc.id_de("hazaki") == "aparo" and esc.aparo_para("hazaki") and not esc.ativo_para("hazaki"), "o Hazaki tem o aparo, não o escudo")
	ok(esc.aparo_para("heroi_novo_qualquer"), "quem não está em herois cai no padrão: aparo")
	ok(esc.id_de("lucas") == "fumaca" and not esc.ativo_para("lucas") and not esc.aparo_para("lucas"), "o Luke tem a fumaça (DEF-5), não o escudo nem o aparo")
	ok(
		not esc.aparo_para("lightwolf") and not esc.ativo_para("lightwolf") and esc.matriz_para("lightwolf") and esc.rotulo_de("lightwolf").nome == "MATRIZ",
		"o LightWolf tem a matriz (LW-3), não o aparo nem o escudo"
	)
	ok(esc.rotulo_de("lightwolf_lobo").is_empty() and not esc.posse_para("lightwolf_lobo"), "o Lobo continua sem secundário")
	ok(
		float(a.janela) == 0.30 and float(a.arco) == 140.0 and float(a.recuperacao) == 0.35 and float(a.recarga_erro) == 1.5,
		"janela 0,30 s, arco 140, recuperação 0,35 s, recarga do erro 1,5 s"
	)
	ok(float(a.empurrao) == 360.0 and float(a.atordoa) == 0.7, "o aparo empurra 360 e atordoa 0,7 como o bloqueio perfeito do escudo")
	ok(
		str(esc.rotulo_de("hazaki").get("nome", "")) == "APARO" and str(esc.rotulo_de("nicao").get("nome", "")) == "ESCUDO",
		"os rótulos do slot S por secundário"
	)
	ok(Dados.icone_carta(str(esc.rotulo_de("hazaki").get("icone", "x"))) != null, "o ícone de carta do aparo existe (até a arte própria do slot S)")

	# 2. o Hazaki não tem barra de defesa nem ergue escudo; publica o aparo para a HUD
	zerar()
	ok(h.def_max == 0.0 and h.def == 0.0, "o Hazaki não tem barra de defesa")
	ok(h.sec_nome == "APARO" and h.sec_pronta and not h.sec_ativo and h.sec_recarga == 0.0 and h.sec_recarga_s == 0.0, "sec_*: o aparo pronto")
	h.escudo_forcado = true
	passos(60)
	ok(not h.escudo_ativo, "segurar o botão não ergue escudo no Hazaki")
	ok(h.aparo_disparos == 1, "segurar o botão aparou UMA vez (o aparo é por aperto, não por posse): %d" % h.aparo_disparos)
	h.escudo_forcado = false

	# 3. apertar abre a janela de 0,30 s
	zerar()
	apertar()
	ok(h.aparo_fase == 1 and h.sec_ativo and h.sec_pronta and h.estado == Heroi.Estado.LIVRE, "apertar abre a janela do aparo")
	ok(not h.escudo_ativo, "o aparo não é o escudo")
	passos(14)  # ~0,25 s
	ok(h.aparo_fase == 1, "a janela segue aberta aos 0,25 s")
	passos(6)  # ~0,33 s
	ok(h.aparo_fase == 2, "a janela fecha aos 0,30 s")

	# 4. golpe dentro da janela: perfeito, empurra, atordoa, sem dano, abre o contragolpe
	zerar()
	apertar()
	var m_p = monstro_a(30)
	var vida0: float = h.vida
	ok(ruptura.fator_contragolpe(h) == 1.0, "antes do aparo não há contragolpe")
	var r: bool = h.levar_dano(10.0, m_p.pos, m_p)
	ok(r and h.vida == vida0 and h.invenc == 0.0, "golpe na janela: consumido, sem dano e sem invencibilidade")
	ok(esc.ultimo.get("perfeito", false) == true and esc.perfeitos == 1 and h.aparo_acertos == 1, "golpe na janela: bloqueio perfeito")
	ok(m_p.atordoa_t >= float(a.atordoa) * 0.99, "o monstro fica atordoado (%s s)" % m_p.atordoa_t)
	ok(m_p.emp.x > 100.0, "o monstro é empurrado (emp.x %s)" % m_p.emp.x)
	ok(
		h.contragolpe_t > 0.0 and perto(h.contragolpe_t, float(ruptura.cfg.contragolpe.tempo), 0.001),
		"abre o contragolpe da katana, o mesmo da ruptura (%s s)" % h.contragolpe_t
	)
	ok(ruptura.fator_contragolpe(h) > 1.0, "o golpe da katana ganha o bônus do contragolpe")
	ok(h.def_max == 0.0 and h.def == 0.0, "o aparo não mexe em barra de defesa")
	# a janela segue aberta: outro monstro em contato também é barrado; no fim acerto = recarga curta, sem recuperação
	var m_q = monstro_a(34, 6)
	ok(
		h.levar_dano(10.0, m_q.pos, m_q) and h.vida == vida0 and h.aparo_acertos == 2,
		"a janela segue aberta depois do acerto: o segundo monstro também é aparado"
	)
	passos(24)  # o hit-stop do bloqueio perfeito segura o relógio do mundo por uns quadros
	ok(h.aparo_fase == 0 and h.aparo_erros == 0, "janela que acertou termina sem erro e sem recuperação")
	ok(
		h.aparo_recarga > 0.0 and h.aparo_recarga <= float(a.recarga_acerto),
		"acerto: recarga curta de no máximo %s s (%s)" % [a.recarga_acerto, h.aparo_recarga]
	)
	ok(h.sec_recarga_s > 0.0 and not h.sec_pronta, "sec_*: na recarga o slot mostra o tempo e fica apagado")

	# 5. fora do arco de 140 graus (e a conta do arco)
	zerar()
	apertar()
	ok(esc.cobre_aparo(h, ponto(65.0)) and not esc.cobre_aparo(h, ponto(75.0)), "arco de 140: cobre a 65 graus e não a 75")
	ok(esc.cobre_aparo(h, ponto(-65.0)) and not esc.cobre_aparo(h, ponto(-75.0)), "arco de 140: simétrico")
	ok(not esc.cobre(h, ponto(65.0)) or esc.arco(h) >= 130.0, "(o arco do escudo é outro: 120 mais o nível)")
	var m_lado = monstro_a(0, 14)  # 90 graus
	ok(h.levar_dano(10.0, m_lado.pos, m_lado) and h.vida < h.vida_max and h.aparo_acertos == 0, "golpe pelo lado (90 graus) na janela: o dano entra")
	zerar()
	apertar()
	var m_costas = monstro_a(-14)
	ok(h.levar_dano(10.0, m_costas.pos, m_costas) and h.vida < h.vida_max and h.aparo_acertos == 0, "golpe pelas costas na janela: o dano entra")
	zerar()
	apertar()
	ok(h.levar_dano(8.0, h.pos + Vector2(30, 0)) and h.vida == h.vida_max and h.aparo_acertos == 1, "ataque de área de frente na janela: aparado")
	ok(h.levar_dano(8.0, h.pos, null, false) and h.vida < h.vida_max, "dano de ambiente (espinho) não é aparado")
	# o arco vira com a mira
	zerar()
	w.mouse_forcado = h.centro() + Vector2(-100, 0)
	passos(3)
	apertar()
	var m_e = monstro_a(-14)
	ok(h.levar_dano(10.0, m_e.pos, m_e) and h.vida == h.vida_max, "mirando para a esquerda, o golpe da esquerda é aparado")

	# 6. janela sem golpe é erro: recuperação parado, depois recarga de 1,5 s
	zerar()
	apertar()
	passos(20)  # ~0,33 s: passou a janela
	ok(h.aparo_fase == 2 and h.aparo_erros == 1 and h.contragolpe_t == 0.0, "sem golpe: erro, vai para a recuperação")
	ok(h.sec_recarga == 1.0 and h.sec_recarga_s > float(a.recarga_erro) and not h.sec_pronta, "sec_*: recuperando, cortina cheia e o tempo inclui a recarga")
	h.entrada_forcada = Vector2(1, 0)
	var x0: float = h.pos.x
	passos(3)
	ok(absf(h.pos.x - x0) < 0.01, "na recuperação o herói fica parado")
	h.entrada_forcada = Vector2.ZERO
	var m_r = monstro_a(30)
	ok(h.levar_dano(10.0, m_r.pos, m_r) and h.vida < h.vida_max and h.aparo_acertos == 0, "golpe na recuperação: o dano entra")
	h.emp = Vector2.ZERO
	h.invenc = 0.0
	passos(24)  # o resto da recuperação (0,35 s)
	ok(h.aparo_fase == 0 and h.aparo_recarga > 0.0, "a recuperação termina e a recarga começa (%s s)" % h.aparo_recarga)
	ok(perto(h.aparo_recarga, float(a.recarga_erro), 0.2), "recarga do erro: ~1,5 s (%s)" % h.aparo_recarga)
	ok(not h.sec_pronta and h.sec_recarga > 0.0 and h.sec_recarga <= 1.0 and perto(h.sec_recarga_s, h.aparo_recarga, 0.001), "sec_*: recarregando")
	var disp0: int = h.aparo_disparos
	apertar()
	ok(h.aparo_fase == 0 and h.aparo_disparos == disp0, "apertar na recarga não abre o aparo")
	passos(95)  # passa a recarga
	ok(h.aparo_recarga == 0.0 and h.sec_pronta, "a recarga acaba e o secundário volta pronto")
	apertar()
	ok(h.aparo_fase == 1 and h.aparo_disparos == disp0 + 1, "recarga cumprida: abre de novo")

	# 7. andar na janela é devagar; golpe do botão esquerdo não golpeia
	zerar()
	h.entrada_forcada = Vector2(1, 0)
	passos(2)
	var x1: float = h.pos.x
	passos(10)
	var livre: float = h.pos.x - x1
	zerar()
	h.entrada_forcada = Vector2(1, 0)
	apertar()
	var x2: float = h.pos.x
	passos(10)
	var aparando: float = h.pos.x - x2
	ok(livre > 0.0 and aparando > 0.0 and aparando < livre * 0.5, "na janela anda a ~30%% da velocidade (%s contra %s px)" % [aparando, livre])
	h.entrada_forcada = Vector2.ZERO
	zerar()
	apertar()
	h.ataque_forcado = true
	passos(3)
	ok(h.estado == Heroi.Estado.LIVRE and h.golpes == 0, "na janela do aparo o clique de golpe não golpeia")
	h.ataque_forcado = null

	# 8. outra ação corta o aparo: a esquiva (sem acerto conta como erro, com a recarga longa)
	zerar()
	apertar()
	h.entrada_forcada = Vector2(0, 1)
	h.esq_pedido = 0.2
	passos(2)
	ok(h.estado == Heroi.Estado.ESQUIVA and h.aparo_fase == 0, "a esquiva corta o aparo")
	ok(h.aparo_erros == 1 and h.aparo_recarga > float(a.recarga_acerto), "aparo cortado sem acerto: erro e recarga longa (%s s)" % h.aparo_recarga)
	h.entrada_forcada = Vector2.ZERO
	zerar()
	apertar()
	var m_c2 = monstro_a(30)
	h.levar_dano(10.0, m_c2.pos, m_c2)
	h.entrada_forcada = Vector2(0, 1)
	h.esq_pedido = 0.2
	passos(10)  # passa o hit-stop e a esquiva começa
	ok(
		h.aparo_fase == 0 and h.aparo_erros == 0 and h.aparo_recarga > 0.0 and h.aparo_recarga <= float(a.recarga_acerto),
		"aparo que acertou e foi cortado: sem erro, recarga curta (%s s)" % h.aparo_recarga
	)
	h.entrada_forcada = Vector2.ZERO

	# 9. o aperto guardado: apertar um instante antes de sair de uma esquiva ainda aparam
	zerar()
	h.entrada_forcada = Vector2(0, 1)
	h.esq_pedido = 0.2
	passos(2)
	ok(h.estado == Heroi.Estado.ESQUIVA, "esquivando")
	h.entrada_forcada = Vector2.ZERO
	apertar()  # durante a esquiva: o aperto fica guardado
	ok(h.aparo_fase == 0 and h.sec_pedido_t > 0.0, "apertar durante a esquiva fica guardado (%s s)" % h.sec_pedido_t)
	passos(40)
	ok(h.estado == Heroi.Estado.LIVRE, "a esquiva acabou")

	# 10. morte e reinício derrubam o aparo
	zerar()
	apertar()
	h.vida = 1.0
	h.invenc = 0.0
	var m_k = monstro_a(-14)
	h.levar_dano(50.0, m_k.pos, m_k)
	ok(h.estado == Heroi.Estado.MORTO and h.aparo_fase == 0, "morrer derruba o aparo")
	zerar()
	ok(h.aparo_fase == 0 and h.aparo_acertos == 0 and h.aparo_disparos == 0 and h.aparo_recarga == 0.0, "reiniciar zera o aparo e os contadores")

	# 11. o arco de lâmina se desenha só enquanto a janela está aberta
	zerar()
	fx_passos(2)
	ok(not esc._desenhou, "sem aparo não há arco desenhado")
	apertar()
	fx_passos(2)
	ok(esc._desenhou, "janela aberta: o arco é desenhado")
	fx_passos(30)
	fx_passos(2)
	ok(not esc._desenhou, "janela fechada: o arco some")

	# 12. o contrato sec_* de quem tem escudo (o dado devolve o escudo ao herói padrão só aqui) e de quem não tem secundário
	zerar()
	esc.herois["hazaki"] = "escudo"
	h._iniciar_defesa()
	passos(2)
	ok(
		h.sec_nome == "ESCUDO" and h.sec_icone == "escudo" and h.sec_pronta and not h.sec_ativo and h.sec_barra == 1.0 and h.sec_recarga == 0.0,
		"sec_*: o escudo pronto"
	)
	h.escudo_forcado = true
	passos(4)
	ok(h.escudo_ativo and h.sec_ativo and h.aparo_fase == 0, "sec_*: o escudo erguido (e nada de aparo)")
	passos(60)
	ok(h.sec_barra < 1.0 and perto(h.sec_barra, h.def / h.def_max, 0.001), "sec_barra segue a barra de defesa (%s)" % h.sec_barra)
	h.escudo_forcado = false
	passos(3)
	h.def = 0.0
	h.def_quebrado = true
	passos(2)
	ok(not h.sec_pronta and h.sec_recarga == 1.0 and h.sec_barra == 0.0, "sec_*: escudo quebrado, cortina cheia e barra vazia")
	h.def = h.def_max * 0.125  # metade do caminho até o retorno (25%)
	passos(2)
	ok(perto(h.sec_recarga, 0.5, 0.02), "sec_*: a cortina desce até o retorno (%s)" % h.sec_recarga)
	esc.herois["hazaki"] = "aparo"
	h._iniciar_defesa()
	zerar()
	ok(h.def_max == 0.0 and h.sec_nome == "APARO", "de volta ao aparo: sem barra")
	var chave0: String = h.chave
	h.chave = "lightwolf"
	passos(2)
	ok(h.sec_nome == "MATRIZ" and not h.sec_ativo, "sec_*: o LightWolf publica a matriz (sem barra de defesa aqui, não está pronta a erguer)")
	apertar()
	ok(h.aparo_fase == 0 and not h.escudo_ativo, "o LightWolf não aparo e, sem barra de defesa, a matriz não ergue (a matriz tem teste próprio)")
	h.chave = chave0

	print("v2_aparo falhas=%d" % falhas)
	get_tree().quit()
