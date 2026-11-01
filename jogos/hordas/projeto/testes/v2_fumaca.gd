extends "res://testes/isolamento_v2.gd"
# Teste automático da FUMAÇA DO LUKE (DEF-5: v2/fumaca.gd, v2/armas_novas.gd, v2/heroi.gd, v2/combate.gd, dados/v2_secundario.json > fumaca): o secundário do Luke é a fumaça (apertar,
# não escudo): a bomba cai no ponto da mira (até 180 px), abre uma nuvem de raio 64 por 4 s, os monstros dentro ficam lentos (sem dano), o Luke leva metade do dano dentro dela,
# recarga de 9 s; a nuvem usa um slot do pool de nuvens (liberado em 4 s) e nenhum nó novo nasce depois do 1º uso. O mundo anda em passos fixos de 1/60 s.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_fumaca.tscn  (imprime "v2_fumaca falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
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
		w.combate.efeitos(PASSO)


## Começa de novo: mapa sem monstros, Luke parado e mortal, mouse 100 px à direita, botão do secundário solto, fumaça pronta.
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
	h.invenc = 0.0
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.pos + Vector2(100, 0)
	passos(3)


func monstro_a(p: Vector2):
	var m = w.nascer_monstro("inimigo_cao_ossos", p)
	m.atordoa_t = 0.0
	m.vida = 5000.0
	m.vida_max = 5000.0
	m.emp = Vector2.ZERO
	m.recarga = 99.0  # não bate sozinho
	return m


## Aperta o botão do secundário (a borda de subida lança) e solta no quadro seguinte.
func apertar() -> void:
	w.heroi.escudo_forcado = true
	passos(1)
	w.heroi.escudo_forcado = false


## Quantas nuvens de fumaça estão vivas no pool agora.
func vivas() -> int:
	var n := 0
	for it in w.combate.armas.novas.itens:
		if float(it.vida) > 0.0 and str(it.k) == "nuvem" and str(it.a.get("id", "")) == "fumaca_luke":
			n += 1
	return n


func _ready() -> void:
	Herois.forcado = "lucas"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var h = w.heroi
	var esc = w.combate.escudo
	var fum = w.combate.fumaca
	var d: Dictionary = Dados.json("v2_secundario")
	var f: Dictionary = d.fumaca

	# 1. dados: quem tem o quê
	ok(h.chave == "lucas", "o herói da partida é o Luke")
	ok(esc.id_de("lucas") == "fumaca" and not esc.posse_para("lucas") and not esc.aparo_para("lucas"), "o Luke tem a fumaça: nem escudo nem aparo")
	ok(esc.id_de("nicao") == "escudo" and esc.id_de("hazaki") == "aparo" and esc.id_de("lightwolf") == "matriz", "os outros secundários não mudaram")
	ok(fum.para("lucas") and not fum.para("nicao") and not fum.para("hazaki") and not fum.para("lightwolf"), "só o Luke é da fumaça")
	ok(
		float(f.raio) == 64.0 and float(f.duracao) == 4.0 and float(f.alcance) == 180.0 and float(f.recarga) == 9.0 and float(f.dano_mult) == 0.5,
		"raio 64, 4 s, alcance 180, recarga 9 s, metade do dano"
	)
	ok(str(esc.rotulo_de("lucas").get("nome", "")) == "FUMAÇA", "o rótulo do slot S")

	# 2. o slot S da HUD: pronta, sem barra de defesa; segurar não ergue escudo e lança uma vez só
	zerar()
	ok(h.def_max == 0.0 and h.def == 0.0, "o Luke não tem barra de defesa")
	ok(h.sec_nome == "FUMAÇA" and h.sec_pronta and not h.sec_ativo and h.sec_recarga == 0.0 and h.sec_recarga_s == 0.0, "sec_*: a fumaça pronta")
	h.escudo_forcado = true
	passos(30)
	ok(not h.escudo_ativo and h.aparo_fase == 0 and fum.lancadas == 1, "segurar o botão não ergue escudo e lança UMA bomba (é por aperto)")
	h.escudo_forcado = false

	# 3. apertar: a nuvem cai no ponto da mira, a recarga começa
	zerar()
	var vida_h: float = h.vida
	apertar()
	ok(fum.lancadas == 1 and vivas() == 1, "apertar lança a bomba e abre a nuvem")
	ok(fum.ultimo.distance_to(w.mouse_forcado) < 1.0, "a nuvem cai no ponto da mira (%s)" % fum.ultimo)
	ok(perto(fum.recarga, 9.0, 0.1) and not h.sec_pronta and h.sec_recarga > 0.95, "recarga de 9 s: slot S sem pronto e cortina cheia")
	ok(h.estado == Heroi.Estado.LIVRE and h.vida == vida_h, "a bomba não prende o herói")
	apertar()
	ok(fum.lancadas == 1 and vivas() == 1, "apertar de novo na recarga não faz nada")

	# 4. alcance: mira longe fica presa a 180 px (na conta do chão)
	zerar()
	w.mouse_forcado = h.pos + Vector2(500, 0)
	apertar()
	ok(perto(fum.ultimo.x - h.pos.x, 180.0, 1.0) and absf(fum.ultimo.y - h.pos.y) < 1.0, "alcance 180 na horizontal (%s)" % (fum.ultimo - h.pos))
	zerar()
	w.mouse_forcado = h.pos + Vector2(0, 500)
	apertar()
	ok(perto(fum.ultimo.y - h.pos.y, 180.0 * 0.62, 1.0), "alcance 180 no chão na vertical: 0,62 em y (%s)" % (fum.ultimo - h.pos))

	# 5. monstros dentro ficam lentos, sem dano; fora, não
	zerar()
	w.mouse_forcado = h.pos + Vector2(150, 0)
	var dentro = monstro_a(h.pos + Vector2(150, 0))
	var borda = monstro_a(h.pos + Vector2(150 + 50, 0))
	var fora = monstro_a(h.pos + Vector2(150 + 90, 0))
	var vida_d: float = dentro.vida
	apertar()
	passos(20)
	ok(dentro.lento_t > 0.0 and borda.lento_t > 0.0, "quem está dentro da nuvem fica lento (%s, %s)" % [dentro.lento_t, borda.lento_t])
	ok(fora.lento_t <= 0.0, "quem está fora não fica lento (%s)" % fora.lento_t)
	ok(dentro.vida == vida_d, "a fumaça não fere: vida %s -> %s" % [vida_d, dentro.vida])
	ok(w.combate.fonte_dano != "fumaca_luke", "a fumaça não vira fonte de dano na tela de fim")

	# 6. o Luke leva metade do dano dentro da nuvem; fora, o dano inteiro
	zerar()
	w.mouse_forcado = h.pos
	apertar()
	passos(5)
	ok(fum.protege(h) and h.sec_ativo, "o Luke está dentro da nuvem (sec_ativo)")
	var v0: float = h.vida
	h.levar_dano(10.0, h.pos + Vector2(30, 0))
	ok(perto(v0 - h.vida, 5.0, 0.01), "dentro da fumaça o dano de 10 vira 5 (%s)" % (v0 - h.vida))
	h.invenc = 0.0
	v0 = h.vida
	h.levar_dano(10.0, h.pos + Vector2(30, 0), null, false)
	ok(perto(v0 - h.vida, 5.0, 0.01), "o dano de ambiente (espinhos) também cai pela metade")
	h.invenc = 0.0
	h.pos += Vector2(120, 0)
	passos(40)  # o golpe sofrido para o mundo um instante (hit-stop)
	ok(not fum.protege(h) and not h.sec_ativo, "fora da nuvem não protege (%s %s, hero %s, nuvem %s)" % [fum.protege(h), h.sec_ativo, h.pos, fum.ultimo])
	h.invenc = 0.0
	v0 = h.vida
	h.levar_dano(10.0, h.pos + Vector2(30, 0))
	ok(perto(v0 - h.vida, 10.0, 0.01), "fora da nuvem o dano é inteiro (%s)" % (v0 - h.vida))

	# 7. o slot do pool volta em 4 s e a recarga em 9 s; nada de nó novo depois do 1º uso
	zerar()
	apertar()
	ok(vivas() == 1, "uma nuvem viva logo depois do arremesso")
	passos(60 * 3)
	ok(vivas() == 1, "aos ~3 s a nuvem segue viva")
	passos(60 * 1 + 10)
	ok(vivas() == 0, "aos ~4 s o slot do pool foi liberado")
	ok(not w.combate.armas.novas.tem_ativos(), "o pool não guarda mais nada")
	ok(not h.sec_pronta and h.sec_recarga > 0.0, "a recarga de 9 s ainda corre depois de a nuvem acabar")
	passos(60 * 5 + 20)
	ok(fum.recarga <= 0.0 and h.sec_pronta and h.sec_recarga == 0.0, "aos 9 s o secundário volta a ficar pronto")
	var nos_pre := get_tree().get_node_count()
	apertar()
	ok(fum.lancadas == 2 and vivas() == 1, "o 2º arremesso sai depois da recarga")
	passos(60 * 4 + 10)
	ok(vivas() == 0, "o 2º slot também volta ao pool em 4 s")
	ok(get_tree().get_node_count() == nos_pre, "nada de nó novo no 2º uso (%d -> %d)" % [nos_pre, get_tree().get_node_count()])

	# 8. pool cheio: o arremesso falha sem gastar a recarga
	zerar()
	var presos: Array = []
	for it in w.combate.armas.novas.itens:
		if float(it.vida) <= 0.0:
			it.vida = 30.0
			presos.append(it)
	apertar()
	ok(fum.lancadas == 0 and fum.falhas_pool >= 1 and fum.recarga <= 0.0 and h.sec_pronta, "sem slot livre a bomba não sai e a recarga não é gasta")
	for it in presos:
		it.vida = 0.0
	passos(2)
	apertar()
	ok(fum.lancadas == 1, "com slot livre de novo, sai")

	# 9. pausado, o aperto não lança
	zerar()
	w.combate.pausado = true
	apertar()
	w.combate.pausado = false
	passos(20)
	ok(fum.lancadas == 0, "pausado, o aperto não lança")

	# 10. partida nova zera a recarga
	zerar()
	apertar()
	w.reiniciar()
	w.combate.limpar_partida()
	ok(fum.recarga == 0.0 and fum.lancadas == 0 and vivas() == 0, "partida nova: recarga zerada e nenhuma nuvem")

	Herois.forcado = ""
	print("v2_fumaca falhas=%d" % falhas)
	get_tree().quit()
